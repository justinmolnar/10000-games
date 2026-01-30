# RPS Function Reference

Comprehensive audit of all functions in `src/games/rps.lua` with extraction potential analysis.

---

## READ THIS FIRST - CRITICAL RULES FOR AI

Before making any changes, read the "Rules for Extraction" section below. Key points:
- **Refactor means MOVE code to components and DELETE from game file**
- **"Component doesn't support X" is NOT an excuse - ADD the feature**
- **Use existing patterns from other games (dodge, breakout, etc.)**
- **Deviation from plan should say "None"**

---

## Rules for Extraction

**Follow the "Plan after discussion" for each function.** The Notes and Extraction Potential sections are just context - the Plan is the actual instruction on what to do. Each plan was discussed and agreed upon.

### What "Refactor" Means

Refactoring means MOVING existing code to where it belongs - into reusable components - then DELETING it from the game file. The functionality stays identical, but the code lives in the component, not the game.

**Refactoring is NOT:**
- Keeping "helper functions" in the game file because it's easier
- Leaving code inline because it's "small" or "minimal" or "tightly coupled"
- Creating new abstractions that still live in the game file
- Partial extraction where some logic stays behind

**Refactoring IS:**
- Moving code to ScoringSystem, VictoryCondition, LivesHealthSystem, etc.
- Adding new features to components if they don't exist yet
- Configuring components via schema/callbacks instead of inline code
- Deleting the game code entirely after extraction

### "Component Doesn't Support X" Is NOT An Excuse

If the plan says "use ScoringSystem for X" and ScoringSystem doesn't support X, that means **ADD the feature to ScoringSystem**. That's the work. The whole point of this refactoring is to build out the component library so future games are easier to create.

### Use Existing Patterns

Other games already solved similar problems. Use their patterns:
- **Scoring** → ScoringSystem handles combos, streaks, bonuses
- **Victory conditions** → VictoryCondition handles all win/loss logic
- **Lives/damage** → LivesHealthSystem handles all health tracking
- **Visual feedback** → VisualEffects handles flashes, particles

Don't reinvent. Don't keep inline versions. Use what exists, extend if needed.

### Follow the `self.params` Pattern (dodge_game style)

**DO NOT copy params to self.* fields.** Access params directly via `local p = self.params`.

**WRONG:**
```lua
function Game:setupGameState()
    self.rounds_to_win = self.params.rounds_to_win
    self.time_per_round = self.params.time_per_round
    self.ai_pattern = self.params.ai_pattern
    self.num_opponents = self.params.num_opponents
    -- ... 30 more copied fields
end
```

**RIGHT:**
```lua
function Game:setupGameState()
    local p = self.params
    -- Only initialize RUNTIME state that changes during gameplay
    self.player_wins = 0
    self.ai_wins = 0
    self.ties = 0
    self.current_win_streak = 0
    self.ai_history = {}
    self.player_history = {}
end

function Game:playRound()
    local p = self.params
    if self.player_wins >= p.rounds_to_win then  -- Access directly
        self:checkComplete()
    end
end
```

**Rules:**
1. Use `local p = self.params` at the start of methods that need params
2. Only initialize runtime state (counters, flags, arrays that change during play)
3. Never copy params that don't change - access them directly when needed
4. Delete nil initializations (`self.foo = nil` is pointless)

### The Goal

When a phase says "50 lines → 0 lines", that means 0 lines. Not "20 lines of helper functions." Zero. The game file configures components via schema and callbacks. The logic lives in components.

---

### Procedural Rules

1. Complete ALL functions within a phase before stopping.
2. After completing a phase, fill in AI Notes with **exact line count change**.
3. Do NOT proceed to the next phase without user approval.
4. Run NO tests yourself - the user will do manual testing.
5. When adding to BaseGame/components, ensure other games still work.
6. Delete the rps functions after extraction - no wrappers.
7. If a function is deleted, update all callers immediately.
8. Update game_components_reference.md when components are added or changed.
9. "Deviation from plan" should ideally read "None" for every phase.

**FORBIDDEN:**
- Wrapper functions that just call the extracted version
- "Preserved for reference" comments
- Backward compatibility shims
- Partial deletions (finish what you start)
- Proceeding without documenting line count changes
- Keeping "helper functions" in the game file
- "Component doesn't support it" as a deviation excuse
- Inline code because it's "minimal" or "tightly coupled"

---

## Phase 1: INITIALIZATION + ASSETS (6 functions + WIN_MATRICES)

### Data Structures

### WIN_MATRICES (module-level constant)
Data-driven win/lose relationships for three game modes: rps, rpsls, rpsfb. Each choice maps to what it beats and what it loses to.

**Notes:** 21 lines. Clean data structure at module level. Used by determineWinner and generateAIChoice.

**Extraction Potential:** Low. This is game-specific data that defines the rules. Could move to schema but adds complexity for no real benefit.

**Plan after discussion:**
Move to schema (rps_schema.json). Delete module-level constant. `determineWinner` and `generateAIChoice` read from `self.params.win_matrix` instead.

---

### Section: INITIALIZATION

### init
Initializes the game. Calls parent init. Gets runtime config from DI. Loads parameters from rps_schema.json using SchemaLoader. Calls applyModifiers, setupGameState, setupComponents. Creates the view.

**Notes:** 14 lines. Standard init pattern matching other refactored games.

**Extraction Potential:** Low. Already follows the standard pattern.

**Plan after discussion:**
1. Fix requires - only 3 needed: BaseGame, RPSView, extend line. Access components via `self.di.components.*`
2. Delete `self.di = di` and `self.cheats = cheats or {}` - redundant, handled by super.init
3. Use `self.di.components.SchemaLoader` instead of require
4. Replace `applyModifiers()` with `self:applyCheats({...})`

---

### applyModifiers
Copies mutable params from self.params. Applies difficulty modifier to timing. Applies CheatEngine modifications (speed, advantage, performance). Clamps num_opponents.

**Notes:** 29 lines. Standard cheat/difficulty modifier setup.

**Extraction Potential:** High. Manual cheat application should use applyCheats().

**Plan after discussion:**
1. Delete function
2. Use `applyCheats()` in init:
   - speed_modifier: ["round_result_display_time", "time_per_round"]
   - advantage_modifier: ["rounds_to_win"] (extend applyCheats for custom formula or one-line special case)
   - performance_modifier: ["show_ai_pattern_hint", "show_player_history"] (set to true)
3. Access `self.params.*` directly instead of copying to self.rounds_to_win, self.time_per_round, etc.
4. `num_opponents` clamping: one line after applyCheats or schema constraint
5. difficulty_modifier application handled by applyCheats or schema defaults

**Expected result:** 29 lines → 0 lines (applyCheats call in init ~5 lines)

---

### setupGameState
Initializes game state (wins, ties, rounds, streaks, score). Initializes round state (waiting, choices, result). Initializes AI history arrays. Initializes double hands mode state. Creates opponents array for multiple opponents mode. Initializes time limit state, history display, special rounds state, metrics. Creates RNG.

**Notes:** 69 lines. Lots of state initialization for various game modes. Opponents array creation has a loop.

**Extraction Potential:** High. Manual state tracking duplicates component functionality.

**Plan after discussion:**
1. Use ScoringSystem for score/streak tracking - delete `self.score`, `self.current_win_streak`, `self.max_win_streak`
2. Schema defines metrics structure: `metrics_keys: ["rounds_won", "rounds_lost", ...]`
3. Schema defines opponent template: `opponent_template: {pattern: "$ai_pattern"}`
4. Use `BaseGame:syncMetrics()` pattern instead of manual metrics object init
5. Keep only actual runtime state: counters (player_wins, ai_wins, ties, rounds_played), round state (choices, result), AI history arrays, double hands mode state, RNG

**Expected result:** 69 lines → ~30 lines

---

### setupComponents
Creates PopupManager, VisualEffects, AnimationSystem bounce animation, LivesHealthSystem, HUDRenderer. Activates first special round. Calls setupVictoryCondition.

**Notes:** 41 lines. Clean component creation. Uses AnimationSystem for throw animation.

**Extraction Potential:** High. All component configs should be schema-driven.

**Plan after discussion:**
1. Move all component configs to schema under "components" key
2. Use `createComponentsFromSchema()` - handles PopupManager, VisualEffects, throw_animation, health_system, hud creation
3. Delete manual `self.hud.game = self` - handled by createComponentsFromSchema
4. Delete `self.lives = self.health_system.lives` - access `health_system.lives` directly throughout code
5. Special round activation stays (game-specific logic)
6. setupVictoryCondition call stays

**Note:** "Simple enough" is wrong thinking. Point is building component library for future games, not just reducing lines.

**Expected result:** 41 lines → ~5 lines

---

### setupVictoryCondition
Builds victory_config based on params.victory_condition type (rounds, first_to, streak, total, time). Builds loss_config based on lives or ai_wins threshold. Creates VictoryCondition.

**Notes:** 26 lines. Complex conditional config building. Five victory condition types.

**Extraction Potential:** High. If/elseif config building should be direct schema config.

**Plan after discussion:**
1. Delete function entirely
2. Schema defines victory_condition config directly per variant - no type selector, just the actual config
3. Use `createVictoryConditionFromSchema()` in setupComponents
4. Delete manual `self.victory_checker.game = self` - handled by schema creation

**Expected result:** 26 lines → 0 lines

---

### Section: ASSETS

### setPlayArea
Stores viewport dimensions. Prints debug message.

**Notes:** 5 lines. Minimal - just stores dimensions.

**Extraction Potential:** High. Redundant with BaseGame.

**Plan after discussion:**
1. Delete function entirely
2. Inherit from BaseGame:setPlayArea()
3. Remove debug print

**Expected result:** 5 lines → 0 lines

---

## Phase 1 Summary

**Functions:** 6 (init, applyModifiers, setupGameState, setupComponents, setupVictoryCondition, setPlayArea) + WIN_MATRICES
**Current lines:** ~205
**Expected after refactor:** ~50 lines (~75% reduction)

**Sections covered:** INITIALIZATION, ASSETS

**Key changes:**
- WIN_MATRICES → schema
- applyModifiers → delete, use applyCheats()
- setupGameState → ScoringSystem for score/streaks, schema for metrics/opponent template
- setupComponents → createComponentsFromSchema()
- setupVictoryCondition → delete, schema defines config directly
- setPlayArea → delete, inherit from BaseGame

**Schema additions needed:**
- win_matrix per game mode
- components config (popup, visual_effects, animation, health, hud)
- victory_condition config (direct, not type selector)
- metrics_keys, opponent_template

### Testing (User)


### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Phase 2: MAIN LOOP + INPUT + ROUND LOGIC (9 functions)

### Section: MAIN GAME LOOP

### updateGameLogic
Checks time limit for "time" victory condition. Handles double hands removal timer timeout. Updates throw_animation, visual_effects, popup_manager. Handles result display timer and transitions back to waiting_for_input. Activates special round after result display.

**Notes:** 52 lines. Multiple timers and state transitions. Clean component updates.

**Extraction Potential:** High. Timer management should use AnimationSystem, time limit check duplicates VictoryCondition.

**Plan after discussion:**
1. Delete time limit check - VictoryCondition `time_survival` type handles this
2. Double hands timer → `AnimationSystem.createTimer(time_per_removal, callback)` set up when entering removal phase
3. Result display timer → `AnimationSystem.createTimer(round_result_display_time, callback)` that sets waiting_for_input=true and activates special round
4. Component updates handled by component system or BaseGame update pattern
5. What remains: call component updates if not automatic

**Expected result:** 52 lines → ~10 lines

---

### draw
Calls view:draw().

**Notes:** 3 lines. Pure wrapper.

**Extraction Potential:** Very High. Delete entirely. Inherit from BaseGame:draw().

**Plan after discussion:**
1. Delete function entirely
2. Inherit from BaseGame:draw()

**Expected result:** 3 lines → 0 lines

---

### Section: INPUT

### keypressed
Guards against invalid input state. Maps keys to choices based on game_mode (r/p/s, l/v for rpsls, f/w for rpsfb). Handles double hands removal phase (1/2 keys). Handles double hands selection phase. Calls playRound for normal mode.

**Notes:** 78 lines. Complex input handling with multiple game modes and phases. Key mapping is straightforward but verbose.

**Extraction Potential:** High. Key mapping should be schema, game logic doesn't belong in keypressed.

**Plan after discussion:**
1. Key mappings → schema (derive from win_matrix keys or explicit mapping)
2. keypressed becomes: validate state, lookup key in schema, call `self:handleChoice(choice)`
3. All double hands logic (phases, timers, AI generation, hand state) moves to `handleChoice()` or `playRound()`
4. Remove debug print (line 346)

**Expected result:** 78 lines → ~15 lines

---

### Section: ROUND LOGIC

### playRound
Main round execution for single opponent. Sets player choice, starts animation. Branches to playRoundMultipleOpponents if needed. Generates AI choice, determines winner. Applies special round rules (reverse, mirror). Increments rounds_played. Calls onRoundWin/onRoundLose/onRoundTie based on result. Updates history arrays. Updates throw_history for display. Calls updateMetrics. Clears special round. Sets show_result.

**Notes:** 61 lines. Orchestrates round flow. Clean after extracting onRound* functions.

**Extraction Potential:** High. Special rounds should be schema, unify with multiple opponents.

**Plan after discussion:**
1. Special round effects → schema-driven effect configs
2. History management → utility or automatic with max length config
3. Unify with playRoundMultipleOpponents (single opponent = array of 1)
4. Result timer → AnimationSystem.createTimer()

**Expected result:** 61 lines → ~30 lines

---

### onRoundWin
Increments player_wins and streak. Calculates points with double_or_nothing multiplier. Calculates streak bonus. Shows score popup. Updates max_win_streak. Triggers green flash. Handles sudden_death victory. Checks victory condition. Handles perfect game bonus and confetti.

**Notes:** 48 lines. Many scoring concerns mixed with visual feedback and victory checking.

**Extraction Potential:** High. All scoring logic should be ScoringSystem.

**Plan after discussion:**
1. ScoringSystem handles: player_wins, streak, max_streak, points, streak_bonus, perfect_game_bonus
2. Schema configures: score_per_round_win, streak_bonus multiplier, perfect_game_bonus
3. Callbacks/events for: popup display, green flash, confetti
4. Sudden death victory → schema special round effect
5. Delete manual victory check - VictoryCondition auto-checks

**Expected result:** 48 lines → ~10 lines

---

### onRoundLose
Increments ai_wins. Resets streak. Handles double_or_nothing score loss. Handles sudden_death game over. Triggers red flash. Handles life loss via health_system. Checks ai_wins threshold for game over.

**Notes:** 26 lines. Cleaner than onRoundWin. Still mixes scoring with life system.

**Extraction Potential:** High. Scoring and victory checks should use components.

**Plan after discussion:**
1. ScoringSystem handles: streak reset, score penalty (double_or_nothing)
2. Sudden death → schema special round effect
3. Red flash → callback
4. Life loss stays (already uses health_system)
5. Delete manual ai_wins threshold check - VictoryCondition handles

**Expected result:** 26 lines → ~8 lines

---

### onRoundTie
Increments ties. Handles life loss on tie via health_system.

**Notes:** 11 lines. Simple, focused.

**Extraction Potential:** Low-Medium. Already uses health_system correctly.

**Plan after discussion:**
1. Keep mostly as-is
2. ties counter could be ScoringSystem for unified stats tracking
3. health_system usage is correct

**Expected result:** 11 lines → ~8 lines

---

### updateMetrics
Syncs metrics object from game state (rounds_won, rounds_lost, rounds_total, max_win_streak, accuracy, score).

**Notes:** 9 lines. Simple sync function.

**Extraction Potential:** High. Manual sync redundant when using ScoringSystem.

**Plan after discussion:**
1. Delete function
2. ScoringSystem provides: score, max_win_streak
3. Use `BaseGame:syncMetrics()` pattern with mapping, or metrics pulled directly from components
4. Accuracy calculation → ScoringSystem computed property

**Expected result:** 9 lines → 0 lines

---

### playRoundMultipleOpponents
Handles round with multiple AI opponents. Iterates opponents, generates choices, determines results. Counts wins/losses/ties against all opponents. Updates player stats based on majority result. Updates opponent histories. Checks victory condition. Updates metrics. Shows result.

**Notes:** 54 lines. Similar to playRound but for multiple opponents. Duplicates some logic.

**Extraction Potential:** Very High. ~90% duplicate of playRound.

**Plan after discussion:**
1. Delete this function
2. Unify into playRound - single opponent is opponents array of length 1
3. playRound iterates opponents (even if just 1), determines majority result
4. Same flow, no duplication

**Expected result:** 54 lines → 0 lines (merged into playRound)

---

## Phase 2 Summary

**Functions:** 9 (updateGameLogic, draw, keypressed, playRound, onRoundWin, onRoundLose, onRoundTie, updateMetrics, playRoundMultipleOpponents)
**Current lines:** ~342
**Expected after refactor:** ~80 lines (~77% reduction)

**Sections covered:** MAIN GAME LOOP, INPUT, ROUND LOGIC

**Key changes:**
- updateGameLogic: timers → AnimationSystem, delete duplicate time limit check
- draw: delete, inherit from BaseGame
- keypressed: key mappings → schema, double hands logic moves out
- playRound: unify with multiple opponents, special rounds → schema
- onRoundWin: ScoringSystem handles all scoring, callbacks for visuals
- onRoundLose: ScoringSystem + health_system, delete manual checks
- onRoundTie: minor cleanup
- updateMetrics: delete, use ScoringSystem/syncMetrics pattern
- playRoundMultipleOpponents: delete, merge into playRound

### Testing (User)


### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Phase 3: AI SYSTEM + GAME STATE + SPECIAL ROUNDS (7 functions)

### Section: AI SYSTEM

### generateAIChoice
Gets available choices. Handles ai_pattern_delay (random during delay). Implements six AI patterns: random, repeat_last, counter_player, pattern_cycle, mimic_player, anti_player. Uses WIN_MATRICES for counter_player.

**Notes:** 31 lines. Clean pattern implementation. Uses game RNG for determinism.

**Extraction Potential:** Medium. AI patterns are game-specific but the pattern system could be generic. Could be data-driven with pattern configs.

**Plan after discussion:**
1. Merge with generateAIChoiceForOpponent - pass context (history, pattern) as parameters
2. WIN_MATRICES → self.params.win_matrix
3. Pattern implementation logic stays (game-specific), just no longer duplicated

**Expected result:** 31 lines → ~25 lines

---

### generateAIChoiceForOpponent
Nearly identical to generateAIChoice but uses opponent.history instead of self.ai_history, and opponent.pattern instead of self.params.ai_pattern.

**Notes:** 30 lines. ~90% duplicate of generateAIChoice.

**Extraction Potential:** Very High. Should merge with generateAIChoice by passing context (history, pattern) as parameters. 30 lines of duplication.

**Plan after discussion:**
1. Delete function entirely
2. generateAIChoice takes context: `generateAIChoice(history, pattern)`
3. Callers pass appropriate context

**Expected result:** 30 lines → 0 lines

---

### getAvailableChoices
Returns choice array based on game_mode (rps, rpsls, rpsfb).

**Notes:** 9 lines. Simple mode-based lookup.

**Extraction Potential:** Low-Medium. Could be data in schema or WIN_MATRICES keys. Small function, low priority.

**Plan after discussion:**
1. Delete function
2. Derive choices from win_matrix keys
3. Or schema defines `choices` array explicitly

**Expected result:** 9 lines → 0 lines

---

### determineWinner
Checks for tie. Looks up win_matrix for game_mode. Checks if AI choice is in player's beats list. Returns "win", "lose", or "tie".

**Notes:** 18 lines. Clean, data-driven winner determination.

**Extraction Potential:** Low. Already well-structured, uses WIN_MATRICES data.

**Plan after discussion:**
1. Change `WIN_MATRICES[self.params.game_mode]` → `self.params.win_matrix`
2. Keep logic as-is - clean and game-specific

**Expected result:** 18 lines → ~15 lines

---

### Section: GAME STATE / VICTORY

### checkVictoryCondition
Calls victory_checker:check(). Returns true if result is "victory".

**Notes:** 7 lines. Wrapper around VictoryCondition.

**Extraction Potential:** High. Redundant with checkComplete. Only returns boolean for victory, ignores loss. Called from playRound and playRoundMultipleOpponents.

**Plan after discussion:**
1. Delete function entirely
2. Callers use `self:checkComplete()` or `self.victory_checker:check() == "victory"` directly

**Expected result:** 7 lines → 0 lines

---

### checkComplete
Calls victory_checker:check(). Sets victory and game_over flags. Returns true if complete.

**Notes:** 9 lines. Standard pattern matching other games.

**Extraction Potential:** High. Could inherit from BaseGame:checkComplete().

**Plan after discussion:**
1. Delete function entirely
2. Inherit from `BaseGame:checkComplete()`

**Expected result:** 9 lines → 0 lines

---

### Section: SPECIAL ROUNDS

### activateSpecialRound
Returns nil if special_rounds_enabled is false. Builds array of enabled special types. Returns nil if none enabled. 50% chance to activate, random selection from available.

**Notes:** 20 lines. Simple random activation system.

**Extraction Potential:** Low-Medium. Game-specific feature. Could be more data-driven but works fine.

**Plan after discussion:**
1. Schema defines `special_rounds: [{type: "reverse", weight: 1}, {type: "mirror", weight: 1}, ...]` - only enabled ones with weights
2. Schema defines `special_round_chance: 0.5`
3. Use `EntityController.pickWeightedType()` pattern for selection
4. Function becomes: check enabled, roll chance, pick from weighted array

**Expected result:** 20 lines → ~5 lines

---

## Phase 3 Summary

**Functions:** 7 (generateAIChoice, generateAIChoiceForOpponent, getAvailableChoices, determineWinner, checkVictoryCondition, checkComplete, activateSpecialRound)
**Current lines:** ~124
**Expected after refactor:** ~45 lines (~64% reduction)

**Sections covered:** AI SYSTEM, GAME STATE / VICTORY, SPECIAL ROUNDS

**Key changes:**
- generateAIChoice: merge with generateAIChoiceForOpponent by passing context (history, pattern) as params
- generateAIChoiceForOpponent: delete, merged into generateAIChoice
- getAvailableChoices: delete, derive from win_matrix keys or schema `choices` array
- determineWinner: update to use self.params.win_matrix instead of WIN_MATRICES
- checkVictoryCondition: delete, callers use checkComplete or victory_checker directly
- checkComplete: delete, inherit from BaseGame
- activateSpecialRound: schema-driven special round config with weights

### Testing (User)


### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Summary Statistics

| Phase | Sections | Functions | Lines | Expected |
|-------|----------|-----------|-------|----------|
| Phase 1 | Initialization + Assets | 6 + WIN_MATRICES | 205 | ~50 |
| Phase 2 | Main Loop + Input + Round Logic | 9 | 342 | ~80 |
| Phase 3 | AI System + Game State + Special Rounds | 7 | 124 | ~45 |
| **TOTAL** | | **22 + WIN_MATRICES** | **671** | **~175** |

---

## Key Observations

### Duplicated Code

1. **generateAIChoice / generateAIChoiceForOpponent** - ~90% identical, 30 lines duplicated
2. **checkVictoryCondition / checkComplete** - both call victory_checker:check(), serve different purposes but could unify
3. **Metrics update** - same updateMetrics() called from playRound and playRoundMultipleOpponents
4. **playRound / playRoundMultipleOpponents** - similar structure, could share more

### Missing Component Usage

1. **ScoringSystem** - Not used. Points, streaks, bonuses all calculated inline.
2. **BaseGame:draw()** - Not inherited, wrapper exists
3. **BaseGame:checkComplete()** - Not inherited, custom version exists

### Good Patterns Already Present

1. **WIN_MATRICES** - Data-driven game rules
2. **LivesHealthSystem** - Properly used for life management
3. **VictoryCondition** - Used (though with redundant wrapper)
4. **VisualEffects** - Used for flashes
5. **AnimationSystem** - Used for throw animation
6. **Game RNG** - Uses love.math.newRandomGenerator for determinism

### Complexity Hotspots

1. **keypressed** (78 lines) - Multiple game modes, double hands phases
2. **setupGameState** (69 lines) - Many state variables for various modes
3. **playRound** (61 lines) - Main game orchestration
4. **playRoundMultipleOpponents** (54 lines) - Parallel logic to playRound

---

## Priority Extraction Targets

### Immediate Wins (Delete entirely)
1. `draw` - inherit from BaseGame
2. `checkComplete` - inherit from BaseGame (or keep if different)

### High Impact (Reduce duplication)
1. **Merge generateAIChoice/generateAIChoiceForOpponent** - Pass context as param, eliminate 30 lines
2. **Remove checkVictoryCondition** - Use checkComplete or victory_checker directly
3. **Use ScoringSystem** - Move points, streaks, bonuses to component

### Medium Impact (Cleaner architecture)
1. **Data-driven key mapping** - Key-to-choice in schema or constant
2. **Merge playRound flows** - Single opponent as special case of multiple

---

## Estimated Reduction

Current: 671 lines

After full refactoring by phase:
- Phase 1 (Initialization + Assets): 205 → ~50 lines
- Phase 2 (Main Loop + Input + Round Logic): 342 → ~80 lines
- Phase 3 (AI System + Game State + Special Rounds): 124 → ~45 lines

**Estimated final size:** ~175 lines
**Estimated reduction:** ~74%

**New components/features to create:**
- PatternGenerator component (shared with coin_flip)
- BaseGame turn state helper (shared with coin_flip)

**Games to update alongside:**
- Coin Flip (turn state, PatternGenerator, onCorrect/onIncorrect patterns)
