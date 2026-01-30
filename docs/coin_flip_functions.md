# Coin Flip Function Reference

Comprehensive audit of all functions in `src/games/coin_flip.lua` with extraction potential analysis.

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
    self.time_per_flip = self.params.time_per_flip
    self.flip_speed = self.params.flip_animation_speed
    self.coin_bias = self.params.coin_bias
    self.lives = self.params.starting_lives
    -- ... 20 more copied fields
end
```

**RIGHT:**
```lua
function Game:setupGameState()
    local p = self.params
    -- Only initialize RUNTIME state that changes during gameplay
    self.current_streak = 0
    self.pattern_state = {index = 0, cluster_count = 0}
end

function Game:someMethod()
    local p = self.params
    if self.timer > p.time_per_flip then  -- Access directly
        self:flipCoin()
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
6. Delete the coin_flip functions after extraction - no wrappers.
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

## Phase 1: INITIALIZATION (5 functions)

### init
Initializes the game. Calls parent init. Gets runtime config from DI. Loads parameters from coin_flip_schema.json using SchemaLoader. Calls applyModifiers, setupGameState, setupComponents. Creates the view.

**Notes:** 14 lines. Standard init pattern matching other refactored games.

**Extraction Potential:** Low. Already follows the standard pattern.

**Plan after discussion:**
1. Delete `self.di = di` and `self.cheats = cheats or {}` - redundant, handled by super.init
2. Fix requires at file top - only 3 needed: BaseGame, CoinFlipView, and the extend line. All components (SchemaLoader, VisualEffects, AnimationSystem, HUDRenderer, VictoryCondition, LivesHealthSystem, PopupManager) accessed via `self.di.components.*`
3. Delete the `Config = rawget(_G, 'DI_CONFIG')` line - unused
4. Use `self.di.components.SchemaLoader.load()` instead of direct require
5. Replace `applyModifiers()` call with `self:applyCheats({...})` pattern

---

### applyModifiers
Copies mutable params from self.params (time_per_flip, flip_animation_speed, coin_bias, starting_lives). Applies difficulty modifier to timing. Applies CheatEngine modifications (speed, advantage, performance/bias).

**Notes:** 24 lines. Standard cheat/difficulty modifier setup.

**Extraction Potential:** Low. This is the standard pattern used in all games.

**Plan after discussion:**
1. Delete entire `applyModifiers()` function
2. In init, use standard pattern:
   ```lua
   self:applyCheats({
       speed_modifier = {"flip_animation_speed", "time_per_flip"},
       advantage_modifier = {"lives"},
       performance_modifier = {"coin_bias"}
   })
   ```
3. Delete copied self.* fields - access `self.params.*` directly throughout
4. Delete the overcomplicated `(0.5 - coin_bias) * modifier` formula - standard applyCheats just adds to the param
5. difficulty_modifier application - check if applyCheats handles or add one-liner after

---

### setupGameState
Creates RNG. Initializes game state (streaks, totals, game_over, victory). Initializes round state (waiting, guesses, results). Initializes pattern_state for flip generation. Initializes timers and history arrays. Initializes score and metrics.

**Notes:** 41 lines. Clean state initialization. Pattern_state is unique to this game.

**Extraction Potential:** Low. Most is simple state init. Pattern state is game-specific.

**Plan after discussion:**
1. Delete all redundant BaseGame inits (rng, game_over, victory, time_elapsed, score, metrics)
2. Timers → AnimationSystem.createTimer() in setupComponents
3. Streaks → ScoringSystem
4. Round/turn state (waiting_for_guess, show_result, result_display_time, current_guess, last_result, last_guess) → Extract to BaseGame helper. **Also update RPS to use same helper.**
5. Metrics → schema-defined
6. Keep only pattern_state init (~5 lines)

**Expected:** 41 lines → ~5-10 lines

---

### setupComponents
Creates PopupManager, VisualEffects, AnimationSystem flip animation, LivesHealthSystem, HUDRenderer. Calls setupVictoryCondition.

**Notes:** 33 lines. Clean component creation. Uses AnimationSystem.createFlipAnimation.

**Extraction Potential:** Low. Already follows the standard pattern.

**Plan after discussion:**
1. Use `createComponentsFromSchema()` - define ALL components in schema (PopupManager, VisualEffects, LivesHealthSystem, HUDRenderer, flip_animation)
2. Access via `self.di.components.*` not requires
3. setupVictoryCondition → `createVictoryConditionFromSchema()`
4. Nothing game-specific here

**Expected:** 33 lines → ~3 lines

---

### setupVictoryCondition
Builds victory_config based on params.victory_condition type (streak, total, ratio, time). Sets loss condition to lives_depleted. Creates VictoryCondition.

**Notes:** 20 lines. Four victory condition types. Ratio type has custom parameters.

**Extraction Potential:** Low-Medium. VictoryCondition handles the logic. Could be schema-driven.

**Plan after discussion:**
1. Delete entire function
2. Use `createVictoryConditionFromSchema()` like other refactored games
3. Define victory conditions mapping in schema, not code
4. Ratio type already supported by VictoryCondition

**Expected:** 20 lines → 0 lines

---

## Phase 1 Summary

**Functions:** 5 (init, applyModifiers, setupGameState, setupComponents, setupVictoryCondition)
**Current lines:** ~132
**Expected after refactor:** ~15-20 lines

**Key changes:**
- Fix requires (only 3 needed)
- Delete applyModifiers, use applyCheats()
- Delete setupVictoryCondition, use createVictoryConditionFromSchema()
- setupGameState gutted - only pattern_state remains
- setupComponents → createComponentsFromSchema()
- Turn state helper added to BaseGame (also update RPS)

### Testing (User)


### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Phase 2: ASSETS + INPUT + GAME STATE + MAIN LOOP (6 functions)

### Section: ASSETS

### setPlayArea
Stores viewport dimensions.

**Notes:** 4 lines. Minimal.

**Extraction Potential:** Low. Could inherit from BaseGame but trivial.

**Plan after discussion:**
1. Delete function - inherit from BaseGame
2. Update view to use `arena_width`/`arena_height` instead of `viewport_width`/`viewport_height`

**Expected:** 4 lines → 0 lines

---

### Section: INPUT

### keypressed
Guards against invalid input state. Auto mode: space triggers flipCoin. Guess mode: h/t triggers makeGuess.

**Notes:** 17 lines. Simple key mapping based on flip_mode.

**Extraction Potential:** Low. Clean, minimal input handling.

**Plan after discussion:**
1. Extend BaseGame:keypressed to read key mappings from schema
2. Move key definitions to schema (h = heads, t = tails, space = flip)
3. BaseGame:keypressed checks generic state (`can_accept_input`, `game_over`, `victory`) before processing
4. Delete function entirely - schema-driven

**Expected:** 17 lines → 0 lines

---

### Section: GAME STATE / VICTORY

### checkVictoryCondition
Custom ratio calculation for ratio victory type. For other types, uses victory_checker:check().

**Notes:** 22 lines. Ratio type has inline calculation because VictoryCondition may not support it properly.

**Extraction Potential:** High. VictoryCondition should handle ratio type properly. This custom logic shouldn't exist.

**Plan after discussion:**
1. Delete function entirely
2. VictoryCondition already supports ratio type
3. If ratio calculation is wrong in VictoryCondition, fix it there
4. All games use victory_checker:check() directly

**Expected:** 22 lines → 0 lines

---

### checkComplete
Calls victory_checker:check(). Sets victory and game_over flags. Returns true if complete.

**Notes:** 9 lines. Standard pattern matching other games.

**Extraction Potential:** Medium. Could inherit from BaseGame:checkComplete().

**Plan after discussion:**
1. Delete function - inherit from BaseGame:checkComplete()

**Expected:** 9 lines → 0 lines

---

### Section: MAIN GAME LOOP

### updateGameLogic
Checks time limit victory. Updates flip_animation, visual_effects, popup_manager. Handles result display timer and transitions to waiting_for_guess. Handles auto_flip_timer countdown. Handles time_per_flip_timer countdown.

**Notes:** 50 lines. Multiple timers with similar structure. Two auto-trigger paths that duplicate logic.

**Extraction Potential:** Medium. Timer management could be unified. Auto-flip and time-per-flip timers have identical behavior.

**Plan after discussion:**
1. Time limit victory check → Delete, VictoryCondition handles automatically
2. Component updates → 3 lines, keep inline
3. Result display timer → AnimationSystem.createTimer()
4. auto_flip_timer and time_per_flip_timer → Consolidate into single decision timer using AnimationSystem.createTimer(), calls `triggerFlip()` helper when expired

**Expected:** 50 lines → ~10 lines

---

### draw
Calls view:draw().

**Notes:** 3 lines. Pure wrapper.

**Extraction Potential:** Very High. Delete entirely. Inherit from BaseGame:draw().

**Plan after discussion:**
1. Delete entirely - inherit from BaseGame:draw()

**Expected:** 3 lines → 0 lines

---

## Phase 2 Summary

**Functions:** 6 (setPlayArea, keypressed, checkVictoryCondition, checkComplete, updateGameLogic, draw)
**Current lines:** ~105
**Expected after refactor:** ~10 lines

**Sections covered:** ASSETS, INPUT, GAME STATE / VICTORY, MAIN GAME LOOP

### Testing (User)


### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Phase 3: FLIP LOGIC (7 functions)

### generateFlipResult
Generates flip result based on pattern_mode. Four modes: alternating, clusters, biased_random, random. Updates pattern_state.

**Notes:** 38 lines. Core game mechanic - pattern-based random generation. Uses game RNG.

**Extraction Potential:** Low. This is the core game-specific logic. Patterns are unique to coin flip.

**Plan after discussion:**
1. Create PatternGenerator component for outcome generation based on history/state
2. Pattern definitions in schema
3. Delete function - use component
4. **Also update RPS to use same PatternGenerator component** (AI patterns)

**Expected:** 38 lines → 0 lines

---

### flipCoin
Auto mode flip. Sets waiting state, starts animation. Generates result, updates pattern history. Increments flips_total. Determines success (heads = correct). Calls processFlipResult.

**Notes:** 19 lines. Clean after extraction. Just setup + delegate.

**Extraction Potential:** Low. Already well-structured after refactoring.

**Plan after discussion:**
1. Turn state → BaseGame helper
2. Animation → Component call
3. Result generation → PatternGenerator component
4. Pattern history → PatternGenerator handles internally
5. Metrics → Auto-tracking
6. Keep processFlipResult call

**Expected:** 19 lines → ~5 lines

---

### makeGuess
Guess mode flip. Sets guess state, starts animation. Generates result, updates pattern history. Increments flips_total. Determines success (guess matches result). Calls processFlipResult.

**Notes:** 21 lines. Very similar to flipCoin but tracks guess.

**Extraction Potential:** Medium. Could potentially merge with flipCoin by passing mode/guess as parameter, but they're already clean and short.

**Plan after discussion:**
1. Merge with flipCoin into single `triggerFlip(guess)` method
2. guess=nil for auto mode, guess='heads'/'tails' for guess mode
3. Same extractions as flipCoin

**Expected:** 21 lines → 0 lines (merged into triggerFlip)

---

### processFlipResult
Routes to onCorrectFlip or onIncorrectFlip based on is_correct. Calls updateMetrics. Sets show_result state.

**Notes:** 12 lines. Clean orchestration function.

**Extraction Potential:** Low. Already well-structured.

**Plan after discussion:**
1. Routing logic → Turn state helper callback pattern in BaseGame
2. updateMetrics → Auto-tracking via schema
3. show_result state → Turn state helper
4. Delete function - handled by BaseGame turn state system

**Expected:** 12 lines → 0 lines

---

### onCorrectFlip
Increments correct_total and current_streak. Tracks in flip_history. Calculates score with streak multiplier. Shows score popup with milestone colors. Updates max_streak. Triggers green flash and confetti on streak milestones. TTS announcement. Checks victory condition. Awards perfect streak bonus if applicable.

**Notes:** 46 lines. Many concerns: scoring, visual feedback, TTS, victory checking, perfect bonus.

**Extraction Potential:** High. ScoringSystem could handle points + streak multiplier + perfect bonus. Popups/flashes/confetti could be callbacks. Very similar to RPS onRoundWin.

**Plan after discussion:**
1. Streak tracking → ScoringSystem
2. Score calculation with multiplier → ScoringSystem
3. Score popup → Schema-configured
4. max_streak tracking → ScoringSystem
5. Visual effects (flash, confetti) → Schema-configured on streak milestones
6. TTS → BaseGame:speak() helper
7. Victory check → VictoryCondition handles automatically
8. Perfect bonus → ScoringSystem
9. **Also update RPS onRoundWin to use same patterns**

**Expected:** 46 lines → ~5 lines

---

### onIncorrectFlip
Increments incorrect_total. Clears perfect_streak and current_streak. Tracks in flip_history. Triggers red flash. TTS announcement. Handles life loss via health_system.

**Notes:** 22 lines. Similar to RPS onRoundLose.

**Extraction Potential:** Medium. Already uses health_system. Flash and TTS could be callbacks.

**Plan after discussion:**
1. Streak reset → ScoringSystem
2. perfect_streak reset → ScoringSystem
3. flip_history → PatternGenerator handles internally
4. Visual effects (red flash) → Schema-configured on failure
5. TTS → BaseGame:speak() helper
6. Life loss → Already uses health_system, keep
7. **Also update RPS onRoundLose to use same patterns**

**Expected:** 22 lines → ~3 lines

---

### updateMetrics
Syncs metrics object from game state (max_streak, correct_total, flips_total, accuracy, score).

**Notes:** 7 lines. Simple sync function.

**Extraction Potential:** Medium. Metrics tracking could be automatic.

**Plan after discussion:**
1. Delete function - BaseGame:syncMetrics() already exists
2. Define metric mappings in schema
3. Auto-sync handled by BaseGame

**Expected:** 7 lines → 0 lines

---

## Phase 3 Summary

**Functions:** 7 (generateFlipResult, flipCoin, makeGuess, processFlipResult, onCorrectFlip, onIncorrectFlip, updateMetrics)
**Current lines:** ~165
**Expected after refactor:** ~15 lines

**Key changes:**
- PatternGenerator component created (also update RPS)
- flipCoin/makeGuess merged into triggerFlip()
- Scoring/streaks → ScoringSystem
- Visual feedback → Schema-configured
- Metrics → Auto-tracked

### Testing (User)


### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Summary Statistics

| Phase | Sections | Functions | Lines | Expected |
|-------|----------|-----------|-------|----------|
| Phase 1 | Initialization | 5 | 132 | ~15 |
| Phase 2 | Assets + Input + Game State + Main Loop | 6 | 105 | ~10 |
| Phase 3 | Flip Logic | 7 | 165 | ~15 |
| **TOTAL** | | **18** | **402** | **~40** |

---

## Key Observations

### Good Patterns Already Present

1. **LivesHealthSystem** - Properly used for life management
2. **VictoryCondition** - Used (with partial custom override for ratio)
3. **VisualEffects** - Used for flashes and confetti
4. **AnimationSystem** - Used for flip animation
5. **Game RNG** - Uses love.math.newRandomGenerator for determinism
6. **Clean separation** - flipCoin/makeGuess → processFlipResult → onCorrectFlip/onIncorrectFlip

### Issues

1. **checkVictoryCondition** has custom ratio calculation - VictoryCondition should handle this
2. **draw()** is a wrapper that should be inherited
3. **Scoring inline** - points, streak multiplier, perfect bonus all calculated in game

### Complexity Hotspots

1. **onCorrectFlip** (46 lines) - Many concerns mixed together
2. **updateGameLogic** (50 lines) - Multiple timer systems
3. **generateFlipResult** (38 lines) - Pattern modes (but this is core game logic)

---

## Priority Extraction Targets

### Immediate Wins (Delete entirely)
1. `draw` - inherit from BaseGame

### High Impact
1. **VictoryCondition ratio support** - Move ratio calculation into component
2. **ScoringSystem** - Move streak scoring + perfect bonus to component (if not already there)

### Already Clean
Most of this game is already well-structured after the flipCoin/makeGuess refactoring. The main remaining extractions are:
- Ratio victory condition logic (should be in VictoryCondition)
- Potential ScoringSystem usage for streaks

---

## Estimated Reduction

Current: 402 lines

After full refactoring by phase:
- Phase 1 (Initialization): 132 → ~15 lines
- Phase 2 (Assets + Input + Game State + Main Loop): 105 → ~10 lines
- Phase 3 (Flip Logic): 165 → ~15 lines

**Estimated final size:** ~40 lines
**Estimated reduction:** ~90%

**New components/features to create:**
- PatternGenerator component (also used by RPS)
- BaseGame turn state helper (also used by RPS)
- BaseGame:speak() TTS helper
- BaseGame:keypressed schema-driven input
- Schema: key mappings, pattern definitions, visual feedback config

**Games to update alongside:**
- RPS (turn state, PatternGenerator, onRoundWin/onRoundLose patterns)
