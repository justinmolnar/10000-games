# Memory Match Function Reference

Comprehensive audit of all functions in `src/games/memory_match.lua` with extraction potential analysis.

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
- Moving code to EntityController, AnimationSystem, PhysicsUtils, etc.
- Adding new features to components if they don't exist yet
- Configuring components via schema/callbacks instead of inline code
- Deleting the game code entirely after extraction

### "Component Doesn't Support X" Is NOT An Excuse

If the plan says "use EntityController for X" and EntityController doesn't support X, that means **ADD the feature to EntityController**. That's the work. The whole point of this refactoring is to build out the component library so future games are easier to create.

Examples of WRONG thinking:
- "EntityController doesn't have flip animation" → ADD flip animation support
- "AnimationSystem doesn't handle card flips" → ADD card flip animation
- "FogOfWar doesn't track mouse position" → ADD mouse tracking

The component not having a feature is literally WHY we're doing this extraction. We're moving game-specific code into generic components.

### Use Existing Patterns

Other games already solved similar problems. Use their patterns:
- **Grid layouts** → EntityController has grid spawning patterns
- **Collision callbacks** → EntityController has on_hit. Use it.
- **Timers** → AnimationSystem has timer-based animations
- **Physics** → PhysicsUtils has gravity, bounce, collision

Don't reinvent. Don't keep inline versions. Use what exists, extend if needed.

### The Goal

When a phase says "100 lines → 0 lines", that means 0 lines. Not "50 lines of helper functions." Not "we kept checkMatch for complex stuff." Zero. The game file configures components via schema and callbacks. The logic lives in components.

---

### Procedural Rules

1. Complete ALL functions within a section (phase) before stopping.
2. After completing a section, fill in AI Notes with **exact line count change**.
3. Do NOT proceed to the next section without user approval.
4. Run NO tests yourself - the user will do manual testing.
5. When adding to BaseGame/components, ensure other games still work.
6. Delete the memory_match functions after extraction - no wrappers.
7. If a function is deleted, update all callers immediately.
8. Update game_components_reference.md when components are added or changed.
9. "Deviation from plan" should ideally read "None" for every phase. The plans were discussed and agreed upon - follow them. If you MUST deviate, explain WHY in detail. Do not deviate just because you think you know better. Do not lie and write "None" if you changed something.

**FORBIDDEN:**
- Wrapper functions that just call the extracted version
- "Preserved for reference" comments
- Backward compatibility shims
- Partial deletions (finish what you start)
- Proceeding without documenting line count changes
- Including AI as co-author on commits
- Keeping "helper functions" in the game file
- "Component doesn't support it" as a deviation excuse
- Inline code because it's "minimal" or "tightly coupled"

---

## Phase 1: INITIALIZATION

### init
Initializes the game. Calls parent init with game_data, cheats, DI container, and variant_override. Gets runtime config from DI. Loads parameters from memory_match_schema.json using SchemaLoader. Sets display_name from variant. Calls applyModifiers, setupGameState, setupComponents. Creates the view.

**Notes:** 18 lines. Standard init pattern matching other refactored games. Three setup functions is reasonable.

**Extraction Potential:** Low for init itself. Structure already matches refactored games.

**Plan after discussion:**
1. Delete display_name override (lines 23-25) - redundant, callers already prefer variant.name
2. Fix requires - only 3 needed: BaseGame, MemoryMatchView, extend line. Access components via `self.di.components.*`
3. Use `self.di.components.SchemaLoader` instead of require
4. Replace `applyModifiers()` with `applyCheats()` pattern
5. Move `loadAssets()` call from setupGameState to end of init

---

### applyModifiers
Calculates speed_modifier_value from cheats. Calculates time_bonus_multiplier from speed modifier. Gets variant_difficulty from params.

**Notes:** 5 lines. Simple cheat/difficulty modifier setup.

**Extraction Potential:** Low. This is the standard pattern used in all games.

**Plan after discussion:**
Delete function. Access `self.cheats.speed_modifier` and `self.params.difficulty_modifier` directly where needed. Compute `time_bonus_multiplier` on-demand where used.

---

### setupGameState
Massive function (127 lines). Initializes card dimensions, game dimensions, calculates pairs from card_count or complexity, calculates grid layout, initializes selection state, timing state (memorize phase, shuffle timers), constraint state (time limit, moves), combo state, challenge mode state, distraction particles, metrics, match announcement state, mouse tracking, physics constants for gravity mode. Calls loadAssets mid-function. Sets default card dimensions. Calls calculateGridPosition. Creates EntityController. Creates cards array and calls createCards.

**Notes:** 127 lines. This is a monster. Mixes state initialization with asset loading with component creation with card creation. loadAssets called in the middle. EntityController created here instead of setupComponents.

**Extraction Potential:** Very High.
1. **Card dimensions** - should come from sprites or schema, not hardcoded/calculated inline
2. **Grid layout calculation** - could be a utility function or EntityController grid spawning
3. **loadAssets call** - belongs in init, not mid-function
4. **EntityController creation** - belongs in setupComponents
5. **createCards call** - belongs in setupEntities pattern (like dodge)
6. **Physics constants** - should be in schema or PhysicsUtils config
7. **Multiple concerns mixed** - split into logical setup functions

**Plan after discussion:**

**Rename to `setupEntities`** (match dodge pattern)

**Move to schema (memory_match_schema.json):**
- CARD_SPACING (currently hardcoded 10)
- CARD_ICON_PADDING (currently hardcoded 10)
- grid_padding (currently hardcoded 10)
- game_width/game_height defaults (currently hardcoded 800x600)
- GRAVITY_ACCEL (currently hardcoded 600)
- FLOOR_BOUNCE (currently hardcoded 0.3)
- CARD_MASS (currently hardcoded 1.0)

**Move to init:**
- loadAssets() call (line 137)

**Move to setupComponents:**
- EntityController creation (lines 150-161)

**Keep in setupEntities (~40-50 lines):**
- Card dimension variables init (CARD_WIDTH, CARD_HEIGHT set after loadAssets)
- Pairs calculation from card_count or complexity (lines 53-66)
- Grid layout calculation cols/rows (lines 68-79)
- Selection state init: selected_indices, matched_pairs (lines 81-83)
- Timing state: memorize_phase, memorize_timer, match_check_timer, shuffle timers (lines 85-95)
- Constraint state: time_remaining, moves_made (lines 97-99)
- Combo state: current_combo (lines 101-102)
- Challenge mode: chain_target, chain_progress, selectNextChainTarget call (lines 104-109)
- Metrics init (lines 114-120)
- Match announcement state (lines 122-125)
- Mouse tracking: mouse_x, mouse_y (lines 127-129)
- cards array init and createCards() call (lines 163-165)
- calculateGridPosition() call (line 148)

**Delete entirely:**
- distraction_particles init (line 112) - unused, empty array
- icon_filenames init (line 125) - move to loadAssets where it's populated

**Expected result:** 127 lines → ~45 lines

---

### setupComponents
Creates FogOfWar component. Creates HUDRenderer. Creates VictoryCondition with time_expired or move_limit loss conditions.

**Notes:** 34 lines. Clean component creation. EntityController created in setupGameState instead of here (inconsistent).

**Extraction Potential:** Medium. EntityController creation should move here. Could use createComponentsFromSchema pattern like dodge.

**Plan after discussion:**
1. Use `createComponentsFromSchema()` for fog_controller, hud, victory_checker
2. Move EntityController creation here from setupGameState
3. Add components config to memory_match_schema.json (fog_of_war, hud, victory_condition definitions)
4. Use DI for component classes instead of require at file top
5. Remove manual `self.hud.game = self` / `self.victory_checker.game = self` - handled by createComponentsFromSchema

**Expected result:** 34 lines → ~15 lines (schema config + EC creation)

---

## Phase 1 Summary

**Functions reviewed:** 4 (init, applyModifiers, setupGameState, setupComponents)

**Total current lines:** ~184 lines
**Expected after refactor:** ~75 lines (~60% reduction)

**Key changes:**
- Delete applyModifiers entirely
- Rename setupGameState → setupEntities, gut from 127 → ~45 lines
- Use createComponentsFromSchema() pattern
- Move constants to schema
- Move loadAssets to init
- Move EntityController to setupComponents

**Schema additions needed:**
- Card spacing/padding defaults
- Game dimension defaults
- Gravity physics constants
- Components config (fog, hud, victory)

### Testing (User)
- [ ] Game initializes without errors
- [ ] Cards render at correct positions
- [ ] Grid scales properly to window size
- [ ] FogOfWar works if enabled
- [ ] HUD displays matches/moves/time
- [ ] Victory/loss conditions trigger correctly
- [ ] Memorize phase works (cards face up, then flip down)

### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Phase 2: ASSETS

### loadAssets
Loads sprites from variant sprite_set or "flags" default. Loads card_back.png. Scans directory for all .png icon files. Falls back to memory/flags if no icons found. Shuffles icon files for randomness. Loads needed icons up to total_pairs. Sets base card dimensions from first loaded sprite. Calls loadAudio.

**Notes:** 114 lines. Very long. Shuffles available icons to pick random subset. Lots of print statements. Directory scanning with fallback paths. First sprite sets card dimensions.

**Extraction Potential:** High.
1. **BaseGame:loadAssets()** - other games use this pattern
2. **Directory scanning** - could be utility function
3. **Sprite dimension detection** - could be automatic in sprite loading
4. **Debug prints** - remove in production
5. **114 lines is too long** - split into helpers or use base methods

**Plan after discussion:**
1. Delete entirely. Use `BaseGame:loadAssets()`
2. Add directory scanning feature to BaseGame:loadAssets() - scan sprite_set folder, shuffle available icons, load N random icons
3. Add sprite dimension detection to BaseGame:loadAssets() - set base dimensions from first loaded sprite
4. Add icon_filenames storage to BaseGame (for TTS/announcements)
5. Remove RNG re-seeding - use proper shuffle utility or game's existing RNG
6. Remove all debug prints

**Features to add to BaseGame:loadAssets():**
- `scan_directory: true` - scan folder for all .png files
- `shuffle_icons: true` - randomize which icons are loaded
- `max_icons: N` - limit how many to load
- `detect_dimensions: true` - set card/sprite dimensions from first loaded
- `icon_filenames: true` - store filename-to-index mapping for announcements

**Expected result:** 114 lines → 0 lines (functionality in BaseGame)

---

### countLoadedSprites
Counts entries in self.sprites table.

**Notes:** 6 lines. Simple table count. Only called once in a debug print.

**Extraction Potential:** Very High. Delete entirely. Only used in debug print which should be removed.

**Plan after discussion:**
Delete entirely. Dead code - only caller is debug print being removed with loadAssets extraction. 6 lines → 0 lines.

---

### hasSprite
Returns whether sprite_key exists in self.sprites.

**Notes:** 3 lines. Simple nil check. Dead code - defined but never called.

**Extraction Potential:** Very High. Delete entirely. Dead code.

**Plan after discussion:**
Delete entirely. Dead code - defined but never called. 3 lines → 0 lines.

---

### setPlayArea
Updates game_width and game_height. Recalculates grid position. Updates card positions for non-gravity mode.

**Notes:** 24 lines. Has safety check for required constants. Updates all card positions in a loop.

**Extraction Potential:** High. BaseGame:setPlayArea() pattern exists. Card position update could be EntityController method or handled automatically.

**Plan after discussion:**
1. Use `BaseGame:setPlayArea()` - just set dimensions and call calculateGridPosition()
2. Add `EntityController:repositionGridEntities(start_x, start_y, cols, width, height, spacing)` - reposition all entities with grid_row/grid_col to calculated positions
3. Call EC repositioning from calculateGridPosition() instead of inline loop
4. Remove debug prints

**Expected result:** 24 lines → ~5 lines (dimension set + calculateGridPosition call, card repositioning handled by EC)

---

### calculateGridPosition
Calculates HUD height based on active features. Calculates available space. Calculates card scaling to fit grid. Centers grid in available space.

**Notes:** 75 lines. Very long. Manual HUD height calculation with many conditionals. Complex scaling math. Three concerns: HUD space, card scaling, grid positioning.

**Extraction Potential:** Very High.
1. **HUD height calculation** - HUDRenderer should report its height
2. **Card scaling** - could be EntityController grid layout feature
3. **Grid centering** - common layout pattern, could be utility
4. **75 lines is too long** - split or extract to components

**Plan after discussion:**
1. Add `HUDRenderer:getHeight()` - returns actual rendered height based on config, no more magic numbers
2. Add grid layout utility to EntityController: `calculateGridLayout(config)` where config = `{item_count, container_width, container_height, item_aspect_ratio, spacing, reserved_top}` → returns `{cols, rows, item_width, item_height, start_x, start_y}`
3. Memory match calls utility, stores results in self.grid_layout
4. Remove all hardcoded HUD height calculations (lines 369-379)

**Expected result:** 75 lines → ~10 lines

---

## Phase 2 Summary

**Functions reviewed:** 5 (loadAssets, countLoadedSprites, hasSprite, setPlayArea, calculateGridPosition)

**Total current lines:** ~222 lines
**Expected after refactor:** ~15 lines (~93% reduction)

**Key changes:**
- Delete loadAssets entirely - use BaseGame:loadAssets() with new features
- Delete countLoadedSprites - dead code (debug print removed)
- Delete hasSprite - dead code (never called)
- Simplify setPlayArea - use BaseGame pattern + EC repositioning
- Simplify calculateGridPosition - use HUDRenderer:getHeight() + EC grid layout utility

**Features to add to components:**
- BaseGame:loadAssets() - directory scanning, icon shuffling, dimension detection, filename storage
- HUDRenderer:getHeight() - return actual rendered height
- EntityController:calculateGridLayout() - grid layout calculation utility
- EntityController:repositionGridEntities() - reposition entities with grid_row/grid_col

### Testing (User)
- [ ] Sprites load correctly from variant sprite_set
- [ ] Fallback to "flags" sprite set works
- [ ] Card dimensions detected from sprites
- [ ] Grid scales properly on window resize
- [ ] Cards reposition correctly on resize
- [ ] HUD doesn't overlap with cards

### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Phase 3: CARD MANAGEMENT

### createCards
Creates card entities via EntityController:spawn. Calculates initial positions based on grid or gravity mode. Sets flip state based on memorize phase. Adds to local cards array. Calls shuffleCards.

**Notes:** 50 lines. Dual tracking (EntityController AND self.cards array). Gravity mode has random physics initialization.

**Extraction Potential:** High.
1. **Dual tracking** - should use EntityController only, or explain why both needed
2. **Grid position calculation** - duplicated from other places
3. **Physics initialization** - PhysicsUtils could handle random gravity spawn
4. **Initial flip state** - could be entity type config

**Plan after discussion:**
1. Eliminate dual tracking - use EntityController only with `grid_index` on each entity
2. Cards store `grid_index` (0 to N-1) which determines their grid position
3. Shuffle by reassigning `grid_index` values, not by reordering arrays
4. Use `EntityController:repositionGridEntities()` to place cards based on grid_index
5. Delete `self.cards` array - use `self.entity_controller:getEntitiesByType("card")` where needed
6. Gravity mode physics init stays inline (game-specific random spawn pattern)

**Expected result:** 50 lines → ~25 lines (cleaner spawn loop, no dual tracking)

---

### shuffleCards
Fisher-Yates shuffle on self.cards array. Updates grid positions after shuffle. Resets physics positions for non-gravity mode.

**Notes:** 23 lines. Standard shuffle algorithm. Position updates duplicate grid calculation logic.

**Extraction Potential:** Medium-High.
1. **Shuffle algorithm** - could be utility function
2. **Grid position calculation** - duplicated 4+ times in this file
3. **Position sync after shuffle** - should be one method that handles this

**Plan after discussion:**
1. Add `EntityController:shuffleGridIndices(type_name)` - shuffles grid_index values among entities of given type (Fisher-Yates on the values, reassigns to entities)
2. Memory match calls `self.entity_controller:shuffleGridIndices("card")`
3. Then calls `repositionGridEntities()` to update physical positions
4. Reusable for any grid-based game needing position shuffles (memory, sliding puzzles, tile games)

**Expected result:** 23 lines → 1 line

---

### isSelected
Checks if card index is in selected_indices array.

**Notes:** 6 lines. Simple array search.

**Extraction Potential:** Low-Medium. Small utility. Could use table.contains if it existed, or inline where used.

**Plan after discussion:**
1. Delete function entirely
2. Move selection state to entity: set `card.is_selected = true/false` when selected/deselected
3. Check `card.is_selected` directly where needed (mousepressed, startShuffle)
4. Delete `self.selected_indices` array - use `entity_controller:getEntitiesByFilter(function(e) return e.is_selected end)` if needed

**Expected result:** 6 lines → 0 lines

---

## Phase 3 Summary

**Functions reviewed:** 3 (createCards, shuffleCards, isSelected)

**Total current lines:** ~79 lines
**Expected after refactor:** ~25 lines (~68% reduction)

**Key changes:**
- Eliminate dual tracking (self.cards array + EntityController)
- Cards use grid_index for position, not array order
- Shuffle by reassigning grid_index values via EntityController
- Selection state on entity (is_selected flag) not separate array

**Features to add to EntityController:**
- `shuffleGridIndices(type_name)` - shuffle grid_index values among entities of type
- `repositionGridEntities(type_name, start_x, start_y, cols, width, height, spacing)` - reposition based on grid_index

### Testing (User)
- [ ] Cards spawn at correct grid positions
- [ ] Initial shuffle randomizes card positions
- [ ] Cards can be selected (click highlights them)
- [ ] Already-selected cards can't be re-selected
- [ ] Gravity mode spawns cards at top with physics

### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Phase 4: INPUT

### keypressed
Calls parent keypressed for demo playback tracking. Returns false.

**Notes:** 5 lines. Only calls parent.

**Extraction Potential:** Very High. Delete entirely. Inherit from BaseGame:keypressed().

**Plan after discussion:**
Delete entirely. Inherit from BaseGame:keypressed(). 5 lines → 0 lines.

---

### mousemoved
Tracks mouse position for fog of war.

**Notes:** 5 lines. Simple position tracking.

**Extraction Potential:** Medium. FogOfWar could track mouse internally, or this stays as minimal input handler.

**Plan after discussion:**
1. FogOfWar reads mouse position internally via `love.mouse.getPosition()` when needed
2. Delete this function entirely
3. Delete `self.mouse_x`, `self.mouse_y` state

**Expected result:** 5 lines → 0 lines

---

### mousepressed
Handles card click/selection. Checks if in valid game state. Checks move limit. Iterates cards to find clicked card. Handles card position (grid vs gravity). Validates card is clickable. Records attempt, adds to selection, increments moves. Starts flip animation. Triggers match check if selection complete.

**Notes:** 47 lines. Complex click handling. Grid position recalculated inline. Multiple validation checks.

**Extraction Potential:** High.
1. **Click-to-card mapping** - EntityController could handle point-in-entity checks
2. **Grid position calculation** - duplicated again
3. **Card validation** - could be entity state check
4. **Flip trigger** - could be entity method

**Plan after discussion:**
1. Add `EntityController:getEntityAtPoint(x, y, type_name)` - returns entity at click position (rect/circle hit testing)
2. Use entity state directly: `card.is_selected`, `card.is_matched`, `card.flip_state`
3. Card positions stored on entity (no grid recalc needed with repositionGridEntities)
4. Keep validation and selection logic inline (game-specific)

**Expected result:** 47 lines → ~25 lines

---

## Phase 4 Summary

**Functions reviewed:** 3 (keypressed, mousemoved, mousepressed)

**Total current lines:** ~57 lines
**Expected after refactor:** ~25 lines (~56% reduction)

**Key changes:**
- keypressed deleted (inherit from BaseGame)
- mousemoved deleted (FogOfWar tracks mouse internally)
- mousepressed simplified with EntityController hit testing

**Features to add:**
- FogOfWar: read mouse position via love.mouse.getPosition() internally
- EntityController:getEntityAtPoint(x, y, type_name) - point-in-entity hit testing

### Testing (User)
- [ ] Clicking cards selects them
- [ ] Can't select already-matched cards
- [ ] Can't select already-selected cards
- [ ] Can't select while cards are flipping
- [ ] Move counter increments on selection
- [ ] Fog of war follows mouse (if enabled)

### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Phase 5: GAME STATE / VICTORY

### checkComplete
Skips during memorize phase. Checks is_failed flag. Calls victory_checker:check(). Sets victory/game_over flags.

**Notes:** 17 lines. Similar pattern to other games but with memorize phase guard and is_failed check.

**Extraction Potential:** High. BaseGame:checkComplete() pattern exists. The is_failed check is game-specific but could be VictoryCondition loss type.

**Plan after discussion:**
1. Move `is_failed` triggers to VictoryCondition loss conditions (time_expired, move_limit already supported)
2. Delete `is_failed` flag - VictoryCondition handles all loss checks
3. Keep minimal override for memorize phase guard (don't check completion during memorize)
4. Rest inherits from BaseGame:checkComplete()

**Expected result:** 17 lines → ~5 lines

---

### onComplete
Calculates speed bonus if time limit exists. Plays success sound. Stops music. Calls parent onComplete.

**Notes:** 16 lines. Standard completion handling with time bonus.

**Extraction Potential:** Medium. ScoringSystem could handle time bonus calculation. BaseGame:onComplete() handles sound and music.

**Plan after discussion:**
1. Speed bonus → extract to ScoringSystem or VictoryCondition: `{type: "time_bonus", metric: "time_remaining", multiplier: "$speed_bonus"}`
2. Generic pattern: bonus for completing quickly, reusable across games
3. Sound/music handled by BaseGame:onComplete()
4. Delete function entirely - bonus in VictoryCondition config, rest inherited

**Expected result:** 16 lines → 0 lines

---

## Phase 5 Summary

**Functions reviewed:** 2 (checkComplete, onComplete)

**Total current lines:** ~33 lines
**Expected after refactor:** ~5 lines (~85% reduction)

**Key changes:**
- checkComplete: delete is_failed flag, use VictoryCondition loss types, keep memorize guard
- onComplete: delete entirely, time bonus in VictoryCondition config

**Features to add:**
- VictoryCondition: time_bonus config `{type: "time_bonus", metric: "time_remaining", multiplier: N}`
- Reusable speed bonus pattern for any timed game

### Testing (User)
- [ ] Victory triggers when all pairs matched
- [ ] Loss triggers on time expiry (if time_limit set)
- [ ] Loss triggers on move limit exceeded (if move_limit set)
- [ ] Speed bonus awarded based on time remaining
- [ ] Success sound plays on completion
- [ ] Music stops on completion

### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Phase 6: CHALLENGE MODE

### selectNextChainTarget
Finds unmatched card values. Randomly selects one as chain target.

**Notes:** 17 lines. Simple random selection from remaining values.

**Extraction Potential:** Low-Medium. Small, focused function. Could be part of challenge mode system if one existed.

**Plan after discussion:**
1. Move to schema-driven match_constraint system (discussed in onMatchSuccess)
2. Constraint tracks unmatched values internally using entity state (`card.is_matched`)
3. Delete this function - constraint handles target selection via `entity_controller:getEntitiesByFilter()`
4. Target picked automatically on match via constraint callback

**Expected result:** 17 lines → 0 lines (handled by match_constraint system)

---

### applyMismatchPenalty
Applies time penalty or sets is_failed based on config.

**Notes:** 10 lines. Two penalty modes: time reduction or instant fail.

**Extraction Potential:** Low-Medium. Could be VictoryCondition or ScoringSystem method.

**Plan after discussion:**
1. Delete function
2. Inline in onMatchFailure:
   - Time penalty: `self.time_remaining = self.time_remaining - self.params.mismatch_penalty`
   - Instant fail: `self:onComplete()`
3. VictoryCondition already checks time_remaining for loss

**Expected result:** 10 lines → 0 lines (2 lines inline in onMatchFailure)

---

## Phase 6 Summary

**Functions reviewed:** 2 (selectNextChainTarget, applyMismatchPenalty)

**Total current lines:** ~27 lines
**Expected after refactor:** ~2 lines (~93% reduction)

**Key changes:**
- selectNextChainTarget: delete, handled by schema-driven match_constraint system
- applyMismatchPenalty: delete, inline 2 lines in onMatchFailure

**Features to add:**
- Schema: match_constraint config for chain mode (discussed in Phase 8)

### Testing (User)
- [ ] Chain mode shows required target (if enabled)
- [ ] Wrong chain target = failure
- [ ] Correct chain target = success + new target selected
- [ ] Time penalty subtracts from time_remaining
- [ ] Instant fail mode ends game on mismatch

### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Phase 7: SHUFFLE ANIMATION

### startShuffle
Finds all face-down cards eligible for shuffle. Validates enough cards to shuffle. Randomly selects cards to shuffle. Stores start positions for animation. Swaps card objects in array. Starts animation timer.

**Notes:** 92 lines. Very long. Complex eligibility checking with debug counts. Manual position tracking for animation. Fisher-Yates partial shuffle.

**Extraction Potential:** High.
1. **Eligibility filtering** - EntityController could filter by state
2. **Position animation** - AnimationSystem could handle position tweening
3. **Shuffle logic** - could be EntityController method for grid entities
4. **Debug counting** - remove in production
5. **92 lines is too long** - split or extract

**Plan after discussion:**
1. Use `entity_controller:getEntitiesByFilter()` for eligible cards (face_down, not matched, not selected)
2. Use `entity_controller:shuffleGridIndices(type_name, filter_fn)` - shuffle only filtered entities
3. Add `AnimationSystem.createPositionTween(entity, from, to, duration, on_complete)` for smooth position animation
4. Remove all debug counts/prints
5. `completeShuffle` becomes the animation on_complete callback

**Expected result:** 92 lines → ~15 lines

---

### completeShuffle
Clears is_shuffling flag. Clears shuffle_start_positions.

**Notes:** 5 lines. Simple cleanup.

**Extraction Potential:** Medium. Could be callback from AnimationSystem when shuffle animation completes.

**Plan after discussion:**
1. Delete as separate function
2. Inline as position tween callback: `on_complete = function() self.is_shuffling = false end`
3. Remove debug print
4. `shuffle_start_positions` not needed (AnimationSystem stores tween state internally)

**Expected result:** 5 lines → 0 lines (inline callback)

---

## Phase 7 Summary

**Functions reviewed:** 2 (startShuffle, completeShuffle)

**Total current lines:** ~97 lines
**Expected after refactor:** ~15 lines (~85% reduction)

**Key changes:**
- startShuffle: use EC filtering + shuffleGridIndices, AnimationSystem position tweens
- completeShuffle: delete, inline as animation callback

**Features to add:**
- EntityController:shuffleGridIndices(type_name, filter_fn) - shuffle only filtered entities
- AnimationSystem.createPositionTween(entity, from, to, duration, on_complete)

### Testing (User)
- [ ] Auto-shuffle triggers after interval (if configured)
- [ ] Only face-down, unmatched, unselected cards shuffle
- [ ] Cards animate smoothly to new positions
- [ ] Shuffle completes and cards are clickable again
- [ ] Partial shuffle works (shuffle_count < total eligible)

### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Phase 8: MAIN GAME LOOP (FINAL - depends on all other phases)

### updateGameLogic
Main game loop (113 lines). Handles memorize phase countdown and card flip when phase ends. Updates match announcement timer. Updates time limit countdown. Updates auto-shuffle timer. Updates shuffle animation. Updates flip animations for all cards. Updates gravity physics for all cards. Updates match check timer and calls checkMatch.

**Notes:** 113 lines. Many concerns mixed: phase transitions, timers, animations, physics, match checking. Flip animation is manual interpolation. Gravity physics is manual with floor/wall collision.

**Extraction Potential:** Very High.
1. **Memorize phase** - could be game state with timer callback
2. **Flip animations** - AnimationSystem could handle card flips
3. **Gravity physics** - PhysicsUtils has gravity, this should use it
4. **Floor/wall collision** - PhysicsUtils or ArenaController bounds
5. **Timer management** - multiple timers could use unified timer system
6. **113 lines is too long** - split into logical update functions

**Plan after discussion:**
1. All timers (memorize, match_check, shuffle, announcement) → `AnimationSystem.createTimer(duration, callback)` set up at init
2. Memorize phase becomes: timer callback that sets flag, resets time_elapsed, flips all cards via EC
3. Flip animations → `AnimationSystem.createFlipAnimation()` stored on each card entity, updated by AnimationSystem
4. Gravity physics → `PhysicsUtils.applyGravity(entity, gravity, dt)` + `PhysicsUtils.handleBounds(entity, bounds, {bounce: true})`
5. Add `EntityController:forEachByType(type_name, fn)` for batch operations
6. updateGameLogic becomes: call component updates, check timers fire automatically

**Expected result:** 113 lines → ~15-20 lines

---

### checkMatch
Checks if all selected cards match. Validates chain requirement. Calls onMatchSuccess or onMatchFailure. Clears selected_indices.

**Notes:** 28 lines. Extracted from updateGameLogic. Clean logic flow.

**Extraction Potential:** Low-Medium. Already extracted. Could potentially be VictoryCondition callback or match system.

**Plan after discussion:**
1. Update to use `entity_controller:getEntitiesByFilter(function(e) return e.is_selected end)` for selected cards
2. Clear selection via `entity_controller:forEachByType("card", function(c) c.is_selected = false end)`
3. Keep match logic inline - game-specific

**Expected result:** 28 lines → ~20 lines

---

### onMatchSuccess
Handles successful match. Marks pair as matched. Shows announcement. TTS speaks match. Checks perfect match bonus. Updates combo. Awards points. Updates chain progress. Plays sound.

**Notes:** 58 lines. Many scoring and feedback concerns. TTS integration. Combo system.

**Extraction Potential:** Medium-High.
1. **Scoring** - ScoringSystem could handle combo, perfect bonus, base points
2. **TTS** - could be callback or event
3. **Announcements** - could be visual effect or HUD feature
4. **Sound** - already uses playSound

**Plan after discussion:**
1. Scoring → ScoringSystem: configure base_match_points, combo_multiplier, perfect_bonus in schema
2. Chain logic → schema-driven with callbacks: `validateMatch(value)` checks constraint, `onMatchComplete(value)` updates chain
3. TTS → add `BaseGame:speak(text)` helper that handles DI lookup, ttsManager, weirdness config internally
4. Mark matched → entity state `card.is_matched = true` instead of `matched_pairs[value]`
5. Keep announcement inline (UI feedback, ~3 lines)

**Features to add:**
- ScoringSystem: combo tracking, perfect bonus, base points config
- BaseGame:speak(text) - app-wide TTS helper
- Schema: match_constraint config for chain mode

**Expected result:** 58 lines → ~15 lines

---

### onMatchFailure
Handles failed match. Resets combo. Applies mismatch penalty. Starts flip down animation. Plays sound.

**Notes:** 11 lines. Clean, focused function.

**Extraction Potential:** Low-Medium. Already small. Penalty application could be ScoringSystem.

**Plan after discussion:**
1. Combo reset stays inline (one line)
2. Penalty already delegated to `applyMismatchPenalty()`
3. Flip down → `entity_controller:forEachByFilter(function(e) return e.is_selected end, function(c) c.flip_state = "flipping_down"; c.is_selected = false end)`
4. Keep sound inline

**Expected result:** 11 lines → ~8 lines

---

### draw
Calls view:draw() if view exists.

**Notes:** 5 lines. Pure wrapper.

**Extraction Potential:** Very High. Delete entirely. Inherit from BaseGame:draw().

**Plan after discussion:**
Delete entirely. Inherit from BaseGame:draw(). 5 lines → 0 lines.

---

## Phase 8 Summary

**Functions reviewed:** 5 (updateGameLogic, checkMatch, onMatchSuccess, onMatchFailure, draw)

**Total current lines:** ~215 lines
**Expected after refactor:** ~50 lines (~77% reduction)

**Key changes:**
- updateGameLogic gutted: timers → AnimationSystem, physics → PhysicsUtils, flip animations → AnimationSystem
- checkMatch updated to use entity-based selection (is_selected flag)
- onMatchSuccess: scoring → ScoringSystem, chain → schema callbacks, TTS → BaseGame:speak()
- onMatchFailure: updated entity access
- draw deleted (inherit from BaseGame)

**Features to add:**
- AnimationSystem.createTimer() with callbacks
- AnimationSystem.createFlipAnimation() for card entities
- PhysicsUtils gravity + handleBounds for gravity mode
- EntityController:forEachByType() and forEachByFilter()
- ScoringSystem: combo, perfect bonus, base points
- BaseGame:speak(text) - TTS helper
- Schema: match_constraint config for chain mode

### Testing (User)
- [ ] Memorize phase shows cards, then flips down after timer
- [ ] Cards flip up when clicked
- [ ] Match detection works (same values match)
- [ ] Combo increments on consecutive matches
- [ ] Perfect bonus awarded for first-attempt matches
- [ ] Chain mode validates target (if enabled)
- [ ] TTS speaks matched item name
- [ ] Mismatch flips cards back down
- [ ] Gravity mode physics work (cards fall, bounce)

### AI Notes


### Status


### Line Count Change


### Deviation from Plan


---

## Summary Statistics

| Section | Functions | Lines | Notes |
|---------|-----------|-------|-------|
| Initialization | 4 | 184 | setupGameState is 127 lines alone |
| Assets | 5 | 222 | loadAssets is 114 lines, calculateGridPosition is 75 lines |
| Card Management | 3 | 79 | Dual tracking issue, duplicated grid calculations |
| Main Game Loop | 5 | 215 | updateGameLogic is 113 lines, inline physics/animations |
| Input | 3 | 57 | mousepressed has duplicated grid logic |
| Game State | 2 | 33 | Standard patterns |
| Shuffle Animation | 2 | 97 | startShuffle is 92 lines |
| Challenge Mode | 2 | 27 | Small, focused |
| **TOTAL** | **26** | **914** | |

---

## Key Observations

### Duplicated Code Patterns

1. **Grid position calculation** appears in: setupGameState, calculateGridPosition, setPlayArea, createCards, shuffleCards, mousepressed, startShuffle (~7 places)
2. **Card iteration with physics check** appears in: updateGameLogic, mousepressed
3. **Flip animation logic** duplicated for up and down directions

### Missing Component Usage

1. **PhysicsUtils** - Gravity physics done inline instead of using component
2. **AnimationSystem** - Flip animations done manually instead of using component
3. **EntityController** - Not used for card state management, dual tracking with self.cards

### Large Functions

1. setupGameState: 127 lines
2. loadAssets: 114 lines
3. updateGameLogic: 113 lines
4. startShuffle: 92 lines
5. calculateGridPosition: 75 lines

### Dead Code

1. hasSprite - defined but never called
2. countLoadedSprites - only used in debug print


---

## Priority Extraction Targets

### Immediate Wins (Delete entirely)
1. `hasSprite` - dead code
2. `countLoadedSprites` - only used in debug print
3. `draw` - inherit from BaseGame
4. `keypressed` - inherit from BaseGame

### High Impact (Large functions)
1. `setupGameState` (127 lines) - split into logical functions
2. `loadAssets` (114 lines) - use BaseGame pattern
3. `updateGameLogic` (113 lines) - extract physics, animations, timers
4. `startShuffle` (92 lines) - use AnimationSystem
5. `calculateGridPosition` (75 lines) - HUD height from HUDRenderer, grid layout utility

### Component Features Needed

| Component | Feature | Used For |
|-----------|---------|----------|
| AnimationSystem | Card flip animation | Flip up/down with progress |
| AnimationSystem | Position tween | Shuffle animation |
| PhysicsUtils | Gravity with floor/wall bounds | Gravity mode cards |
| EntityController | Grid layout spawning | Card positioning |
| EntityController | State-based filtering | Find face-down cards |
| HUDRenderer | getHeight() | Calculate available play area |
| FogOfWar | Mouse position tracking | Auto-track from input |

---

## Estimated Reduction

Current: 914 lines (after organization/extraction of checkMatch etc.)

After full refactoring:
- Delete dead code: -15 lines
- Inherit from BaseGame: -15 lines
- Physics to PhysicsUtils: -40 lines
- Animations to AnimationSystem: -60 lines
- Grid layout to utility/EC: -80 lines
- loadAssets to BaseGame pattern: -80 lines
- Shuffle to AnimationSystem: -70 lines

**Estimated final size:** ~300-400 lines
**Estimated reduction:** ~55-65%

Note: Memory match is already more structured than dodge was. The reduction won't be as dramatic because:
1. It's a simpler game mechanically
2. It already uses some components correctly
3. Card-specific logic (matching, flipping) is genuinely game-specific

The main wins are in eliminating duplicated grid calculations, using PhysicsUtils for gravity, and using AnimationSystem for animations.
