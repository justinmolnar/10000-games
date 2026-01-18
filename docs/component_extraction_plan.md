# Component Extraction Plan

**Goal:** Reduce games to nearly nothing but JSON + minimal Lua glue code. Target: ~90-95% reduction.

**Vision:** Each game file should be ~50-150 lines of component wiring + a JSON schema defining all parameters. The game "code" IS the JSON. Lua files become thin orchestration layers.

---

## Rules for AI

1. **Read this section before starting any phase.**
2. Complete ALL steps within a phase before stopping.
3. Do NOT skip steps. Do NOT combine phases.
4. After completing a phase, write notes in that phase's `### AI Notes` section.
5. If something cannot be completed, document it in notes and inform the user.
6. Do NOT proceed to the next phase without user approval.
7. Each phase ends with the code in a working state - no half-finished work.
8. Preserve existing game behavior exactly - this is a refactor, not a feature change.
9. Run NO tests yourself - the user will do manual testing.
10. After completing a phase, tell the user what to test and wait for confirmation.

### Aggressive Reduction Philosophy

**The goal is to make game files TINY.** When migrating a game:
- Move ALL parameters to JSON schema - no hardcoded values in Lua
- Move ALL reusable logic to components - games should only wire things together
- If you find yourself writing game logic, stop and ask: should this be a component?
- The Lua file should be so thin that creating a new game variant is just editing JSON
- Target: each game file ~50-150 lines of pure orchestration code

### Line Changes Tracking

**REQUIRED:** After each phase, document actual line changes in the AI Notes section under `#### Line Changes`:

Format:
```
#### Line Changes
schema_loader.lua        +300 lines (new)
snake_game.lua           -38 lines
snake_schema.json        +270 lines (new)
```

Rules:
- Use `+` for lines added, `-` for lines removed
- Mark new files with `(new)`
- This tracks progress toward the 90-95% reduction goal
- Be accurate - use `wc -l` to count actual lines

---

## Existing Components Reference

Before creating new components, check what already exists:

| Component | Key Features | Use Instead Of |
|-----------|--------------|----------------|
| **EntityController** | spawn modes (continuous, wave, grid), spawnGrid(), pooling | Creating new spawner |
| **MovementController** | modes (direct, asteroids, rail, jump), bounds handling | Creating new movement |
| **PhysicsUtils** | **TrailSystem**, wrap, bounce, clamp, collision | Creating trail system |
| **ProjectileSystem** | linear, homing, sine_wave, bounce, arc projectiles | Creating bullet system |
| **VictoryCondition** | threshold, time_survival, streak, clear_all, rounds | Creating win/loss checker |
| **LivesHealthSystem** | lives, shields, invincibility, respawn | Creating health system |
| **ScoringSystem** | formula and declarative scoring | Creating score calculator |
| **PowerupSystem** | spawn, collect, duration tracking | Creating powerup system |
| **AnimationSystem** | flip, bounce, fade, timers | Creating animation helpers |
| **VisualEffects** | shake, flash, particles | Creating visual effects |
| **FogOfWar** | stencil and alpha modes | Creating visibility system |
| **HUDRenderer** | standardized layout | Creating HUD |

---

## Phase 1: SchemaLoader Component

**What this phase accomplishes:** Creates the SchemaLoader utility that auto-populates game parameters from a JSON schema, eliminating repetitive `loader:get()` calls.

**What will be noticed in-game:** Nothing. This phase only creates the component, no games use it yet.

### Steps

1.1. Create `src/utils/game_components/schema_loader.lua`:
   - Accept a schema definition (JSON or Lua table)
   - Accept variant data from VariantLoader
   - Return a params table with all values populated (variant → schema default)
   - Support types: number, integer, boolean, string, enum, table
   - Support nested parameter groups (e.g., `arena.width`, `arena.height`)

1.2. Create `assets/data/schemas/` directory for game schemas.

1.3. Create a simple test schema `assets/data/schemas/test_schema.json` with a few parameters of different types.

1.4. Add SchemaLoader to the game components documentation if it exists.

### Testing (User)

- [ ] Game launches without errors
- [ ] No console errors related to SchemaLoader

### AI Notes

**Completed:** 2026-01-18

**Implementation details:**
- SchemaLoader uses static methods (no instantiation needed): `SchemaLoader.load(variant, schema_name, runtime_config)`
- Supports types: number, integer, boolean, string, enum, table/array
- Supports nested parameter groups via `schema.groups`
- Supports constraints: min, max, enum values
- Priority order: variant → runtime_config → schema default
- Includes utility methods: `getSchemaInfo()`, `validateVariant()`

**Documentation:** No existing game components documentation found. CLAUDE.md references documentation/GAME_COMPONENTS_API.md but it hasn't been created yet. Skipped per step 1.4 "if it exists".

#### Line Changes
```
schema_loader.lua        +300 lines (new)
test_schema.json         +55 lines (new)
```

---

## Phase 2: Snake Schema + Migration

**What this phase accomplishes:** Creates the Snake game schema and migrates Snake's init function to use SchemaLoader. ALL parameters move to JSON - no hardcoded values remain.

**What will be noticed in-game:** Nothing. Snake should play identically.

**Target:** Move every `loader:get()` and hardcoded parameter to `snake_schema.json`.

### Steps

2.1. Analyze `src/games/snake_game.lua` init function to catalog ALL parameters currently loaded via `loader:get()`.

2.2. Create `assets/data/schemas/snake_schema.json` with all Snake parameters:
   - Include type, default value, and any constraints (min/max)
   - Organize into logical groups (movement, arena, food, obstacles, ai, etc.)

2.3. Modify Snake's init to use SchemaLoader:
   - Replace all `self.X = loader:get('X', default)` lines with single SchemaLoader call
   - Access params via `self.params.X` or destructure as needed
   - Ensure VariantLoader data still overrides schema defaults

2.4. Verify all existing variant JSON files still work (their keys should match schema keys).

### Testing (User)

- [ ] Launch Snake base game - plays normally
- [ ] Launch a Snake variant (e.g., snake_2) - plays with variant parameters
- [ ] Snake movement, food collection, collision all work
- [ ] Victory/defeat conditions trigger correctly
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-18

**Summary:**
- Replaced `VariantLoader` require with `SchemaLoader` require
- Replaced ~90 lines of `loader:get()` calls with single `SchemaLoader.load()` call
- Parameters now accessed via `p.parameter_name` pattern
- All 47 variant keys in `snake_variants.json` match schema parameter names exactly

#### Line Changes
```
snake_schema.json        +270 lines (new)
snake_game.lua           -38 lines (2693 → 2655)
```

---

## Phase 3: Dodge Schema + Migration

**What this phase accomplishes:** Migrates Dodge game to use SchemaLoader, removing ~350 lines of parameter loading.

**What will be noticed in-game:** Nothing. Dodge should play identically.

### Steps

3.1. Analyze `src/games/dodge_game.lua` init function to catalog ALL parameters.

3.2. Create `assets/data/schemas/dodge_schema.json` with all Dodge parameters.

3.3. Modify Dodge's init to use SchemaLoader.

3.4. Verify existing Dodge variant JSON files still work.

### Testing (User)

- [ ] Launch Dodge base game - plays normally
- [ ] Launch a Dodge variant - plays with variant parameters
- [ ] Player movement, obstacle spawning, safe zone all work
- [ ] Enemy types (seeker, bouncer, etc.) behave correctly
- [ ] Victory/defeat conditions trigger correctly
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-18

**Summary:**
- Replaced `VariantLoader` require with `SchemaLoader` require
- Replaced ~80 lines of `loader:get()` calls with single `SchemaLoader.load()` call
- 44 parameters covering: movement, physics, obstacles, environment, visuals, victory, safe zone
- All variant keys in `dodge_variants.json` match schema parameter names

#### Line Changes
```
dodge_schema.json        +299 lines (new)
dodge_game.lua           -46 lines (1980 → 1934)
```

---

## Phase 4: Space Shooter Schema + Migration

**What this phase accomplishes:** Migrates Space Shooter to use SchemaLoader, removing ~400 lines of parameter loading.

**What will be noticed in-game:** Nothing. Space Shooter should play identically.

### Steps

4.1. Analyze `src/games/space_shooter.lua` init function to catalog ALL parameters.

4.2. Create `assets/data/schemas/space_shooter_schema.json` with all parameters.

4.3. Modify Space Shooter's init to use SchemaLoader.

4.4. Verify existing Space Shooter variant JSON files still work.

### Testing (User)

- [ ] Launch Space Shooter base game - plays normally
- [ ] Launch a Space Shooter variant - plays with variant parameters
- [ ] Player movement, shooting, enemy spawning all work
- [ ] Enemy behaviors (zigzag, dive, etc.) work correctly
- [ ] Victory/defeat conditions trigger correctly
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-18

**Summary:**
- Replaced `VariantLoader` require with `SchemaLoader` require
- Replaced ~100 lines of `loader:get()` calls with single `SchemaLoader.load()` call
- ~90 parameters covering: movement, weapons/bullets, enemies, powerups, hazards, victory conditions
- Complex enums for fire_mode, bullet_pattern, enemy_formation, enemy_behavior
- All variant keys in `space_shooter_variants.json` match schema parameter names

#### Line Changes
```
space_shooter_schema.json   +643 lines (new)
space_shooter.lua           -119 lines (2550 → 2431)
```

---

## Phase 5: Breakout Schema + Migration

**What this phase accomplishes:** Migrates Breakout to use SchemaLoader, removing ~100 lines of parameter loading.

**What will be noticed in-game:** Nothing. Breakout should play identically.

### Steps

5.1. Analyze `src/games/breakout.lua` init function to catalog ALL parameters.

5.2. Create `assets/data/schemas/breakout_schema.json` with all parameters.

5.3. Modify Breakout's init to use SchemaLoader.

5.4. Verify existing Breakout variant JSON files still work.

### Testing (User)

- [ ] Launch Breakout base game - plays normally
- [ ] Launch a Breakout variant - plays with variant parameters
- [ ] Paddle movement, ball physics, brick destruction all work
- [ ] Powerups spawn and function correctly
- [ ] Victory/defeat conditions trigger correctly
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-18

**Summary:**
- Replaced `VariantLoader` require with `SchemaLoader` require
- Removed ~100 lines of DEFAULT_* constants and BCfg legacy fallback code
- Consolidated ~120 lines of loader:get() calls across 8 init helper functions into single SchemaLoader.load() call
- 67 parameters covering: paddle, ball, powerups, bricks, arena, scoring, visuals
- All variant keys in `breakout_variants.json` match schema parameter names

#### Line Changes
```
breakout_schema.json        +441 lines (new)
breakout.lua                -93 lines (1766 → 1673)
```

---

## Phase 6a: Memory Match Schema + Migration

**What this phase accomplishes:** Migrates Memory Match to use SchemaLoader.

**What will be noticed in-game:** Nothing. Memory Match should play identically.

### Steps

6a.1. Analyze `src/games/memory_match.lua` init function to catalog ALL parameters.

6a.2. Create `assets/data/schemas/memory_match_schema.json` with all parameters.

6a.3. Modify Memory Match's init to use SchemaLoader.

6a.4. Verify existing Memory Match variant JSON files still work.

### Testing (User)

- [ ] Launch Memory Match - card flipping, matching, victory all work
- [ ] Launch a Memory Match variant - variant parameters apply
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-18

**Summary:**
- Replaced `VariantLoader` require with `SchemaLoader` require
- Removed ~55 lines of MMCfg defaults and VariantLoader initialization
- Replaced ~25 lines of loader:get/getNumber/getBoolean calls with p.xxx access
- 24 parameters covering: grid, timing, scoring, constraints, visuals, fog, difficulty

#### Line Changes
```
memory_match_schema.json    +164 lines (new)
memory_match.lua            -42 lines (1068 → 1026)
```

---

## Phase 6b: RPS Schema + Migration

**What this phase accomplishes:** Migrates RPS to use SchemaLoader.

**What will be noticed in-game:** Nothing. RPS should play identically.

### Steps

6b.1. Analyze `src/games/rps.lua` init function to catalog ALL parameters.

6b.2. Create `assets/data/schemas/rps_schema.json` with all parameters.

6b.3. Modify RPS's init to use SchemaLoader.

6b.4. Verify existing RPS variant JSON files still work.

### Testing (User)

- [ ] Launch RPS - choices, AI opponent, scoring all work
- [ ] Launch an RPS variant - variant parameters apply
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-18

**Summary:**
- Replaced `VariantLoader` require with `SchemaLoader` require
- Removed ~50 lines of DEFAULT_* constants
- Replaced ~35 lines of loader:get calls with p.xxx access
- 43 parameters covering: AI, timing, display, scoring, special rounds, victory conditions, visual effects

#### Line Changes
```
rps_schema.json             +252 lines (new)
rps.lua                     -94 lines (962 → 868)
```

---

## Phase 6c: Coin Flip Schema + Migration

**What this phase accomplishes:** Migrates Coin Flip to use SchemaLoader.

**What will be noticed in-game:** Nothing. Coin Flip should play identically.

### Steps

6c.1. Analyze `src/games/coin_flip.lua` init function to catalog ALL parameters.

6c.2. Create `assets/data/schemas/coin_flip_schema.json` with all parameters.

6c.3. Modify Coin Flip's init to use SchemaLoader.

6c.4. Verify existing Coin Flip variant JSON files still work.

### Testing (User)

- [ ] Launch Coin Flip - flipping, streaks, victory all work
- [ ] Launch a Coin Flip variant - variant parameters apply
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-18

**Summary:**
- Replaced `VariantLoader` require with `SchemaLoader` require
- Removed ~25 lines of DEFAULT_* constants
- Replaced ~25 lines of loader:get calls with p.xxx access
- 26 parameters covering: streaks, coin bias, timing, patterns, victory conditions, scoring, visual effects

#### Line Changes
```
coin_flip_schema.json       +160 lines (new)
coin_flip.lua               -49 lines (660 → 611)
```

---

## Phase 7: Extend MovementController with Grid Mode

**What this phase accomplishes:** Adds a "grid" movement mode to the existing MovementController for discrete cell-based movement (Snake uses this).

**What will be noticed in-game:** Nothing. This phase only extends the component.

### Steps

7.1. Read `src/utils/game_components/movement_controller.lua` to understand existing patterns.

7.2. Add "grid" mode to MovementController:
   - Discrete cell-based positioning
   - Direction queuing (queue next turn while moving)
   - Speed as cells-per-second
   - Grid wrap support (already exists in applyBounds)
   - Configurable cell size

7.3. Update MovementController documentation/comments.

### Testing (User)

- [ ] Game launches without errors
- [ ] Existing games using MovementController still work (Dodge uses it)
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 8: Snake Movement Migration

**What this phase accomplishes:** Migrates Snake's movement code to use MovementController's new grid mode.

**What will be noticed in-game:** Nothing. Snake movement should feel identical.

### Steps

8.1. Identify Snake's grid movement code:
   - Cell-based positioning
   - Direction handling
   - Movement speed/timing

8.2. Configure MovementController (grid mode) in Snake's init using schema params.

8.3. Replace Snake's movement update code with MovementController.

8.4. Remove now-unused movement methods from Snake.

### Testing (User)

- [ ] Snake moves correctly on grid
- [ ] Direction changes work (arrow keys/WASD)
- [ ] Movement speed matches variants
- [ ] Wall wrap mode works
- [ ] Wall death mode works
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 9: ArenaController Component

**What this phase accomplishes:** Creates ArenaController for play area bounds, shapes, and dynamic behaviors that MovementController doesn't handle.

**What will be noticed in-game:** Nothing. This phase only creates the component.

### Steps

9.1. Create `src/utils/game_components/arena_controller.lua`:
   - Shapes: rectangle, circle, hexagon
   - Dynamic behaviors: shrink, pulse, morph (not in MovementController)
   - Safe zones (Dodge-specific)
   - Holes/gaps in boundaries
   - Methods: `update(dt)`, `getBounds()`, `isInside(x, y)`, `getShrinkProgress()`

9.2. Note: MovementController already handles wrap/clamp/bounce - ArenaController handles SHAPE and DYNAMIC changes.

### Testing (User)

- [ ] Game launches without errors
- [ ] No console errors related to ArenaController

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 10: Snake Arena Migration

**What this phase accomplishes:** Migrates Snake's arena shape/shrinking code to ArenaController.

**What will be noticed in-game:** Nothing. Snake arena should behave identically.

### Steps

10.1. Identify Snake's arena code:
   - Arena shapes (rect, circle, hex)
   - Shrinking boundaries

10.2. Configure ArenaController in Snake's init using schema params.

10.3. Replace Snake's arena code with ArenaController calls.

10.4. Remove now-unused arena methods from Snake.

### Testing (User)

- [ ] Snake with rectangular arena works
- [ ] Snake with circular arena works (if variant exists)
- [ ] Snake with shrinking arena works (if variant exists)
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 11: Dodge Arena Migration

**What this phase accomplishes:** Migrates Dodge's safe zone/arena code to ArenaController.

**What will be noticed in-game:** Nothing. Dodge safe zone should behave identically.

### Steps

11.1. Identify Dodge's arena/safe zone code:
   - Safe zone shapes
   - Shrinking, pulsing, morphing
   - Moving safe zone
   - Holes in boundary

11.2. Configure ArenaController in Dodge's init.

11.3. Replace Dodge's safe zone code with ArenaController calls.

### Testing (User)

- [ ] Dodge safe zone appears correctly
- [ ] Safe zone shrinking works (if variant exists)
- [ ] Safe zone movement works (if variant exists)
- [ ] Player death when outside safe zone works
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 12: Extend EntityController with Spawn Patterns

**What this phase accomplishes:** Extends EntityController with more spawn patterns instead of creating new SpawnPatternController.

**What will be noticed in-game:** Nothing. This phase only extends the component.

### Steps

12.1. Read `src/utils/game_components/entity_controller.lua` to understand existing spawn system.

12.2. Add spawn position patterns to EntityController:
   - `spawnAtPosition(type, pattern, bounds)` where pattern is:
     - "random" (existing)
     - "edges" (spawn at screen edges)
     - "corners" (spawn at corners)
     - "top", "bottom", "left", "right" (spawn at specific edge)
   - Add pattern parameter to continuous spawning config

12.3. Add layout patterns to spawnGrid():
   - "grid" (existing)
   - "pyramid"
   - "diamond"
   - "circle"
   - "random_scatter"

12.4. Update EntityController documentation/comments.

### Testing (User)

- [ ] Game launches without errors
- [ ] Existing games using EntityController still work
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 13: Dodge Spawning Migration

**What this phase accomplishes:** Migrates Dodge's obstacle spawning to use EntityController's enhanced patterns.

**What will be noticed in-game:** Nothing. Dodge obstacle spawning should be identical.

### Steps

13.1. Identify Dodge's spawning code:
   - Spawn positions (edges, random)
   - Spawn timing
   - Wave patterns

13.2. Configure EntityController spawning in Dodge using schema params.

13.3. Replace Dodge's spawn code with EntityController.

### Testing (User)

- [ ] Dodge obstacles spawn from correct positions
- [ ] Spawn rates match variant parameters
- [ ] Wave patterns work (if variant exists)
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 14: Breakout Layout Migration

**What this phase accomplishes:** Migrates Breakout's brick layouts to use EntityController's enhanced spawnGrid patterns.

**What will be noticed in-game:** Nothing. Breakout brick layouts should be identical.

### Steps

14.1. Identify Breakout's brick layout code:
   - Grid patterns
   - Pyramid patterns
   - Custom layouts

14.2. Configure EntityController layout in Breakout using schema params.

14.3. Replace Breakout's brick setup code with EntityController.

### Testing (User)

- [ ] Breakout grid layout works
- [ ] Breakout pyramid layout works (if variant exists)
- [ ] Brick positions match expected layouts
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 15: AIBehaviorController Component

**What this phase accomplishes:** Creates AIBehaviorController for enemy movement behaviors (seeker, zigzag, bouncer, etc.).

**What will be noticed in-game:** Nothing. This phase only creates the component.

### Steps

15.1. Create `src/utils/game_components/ai_behavior_controller.lua`:
   - Behaviors: linear, zigzag, seeker, flee, bouncer, teleporter, patrol
   - Per-entity or per-type configuration
   - Integration pattern with EntityController entities
   - Methods: `updateEntity(entity, dt, target)`, `setBehavior(entity, behavior)`

15.2. Design to work WITH EntityController, not replace it:
   - EntityController spawns and manages entities
   - AIBehaviorController updates their movement

### Testing (User)

- [ ] Game launches without errors
- [ ] No console errors related to AIBehaviorController

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 16: Dodge AI Migration

**What this phase accomplishes:** Migrates Dodge's enemy behavior code to AIBehaviorController.

**What will be noticed in-game:** Nothing. Enemy behaviors should be identical.

### Steps

16.1. Identify Dodge's enemy behavior code:
   - Seeker, bouncer, teleporter, shooter, zigzag, splitter
   - Per-enemy behavior assignment
   - Behavior parameters (turn rate, speed, etc.)

16.2. Configure AIBehaviorController in Dodge's init.

16.3. Replace Dodge's enemy update code with AIBehaviorController.

### Testing (User)

- [ ] Seeker enemies chase player
- [ ] Bouncer enemies bounce off walls
- [ ] Zigzag enemies move in sine wave
- [ ] All enemy types behave as expected
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 17: Space Shooter AI Migration

**What this phase accomplishes:** Migrates Space Shooter's enemy behaviors to AIBehaviorController.

**What will be noticed in-game:** Nothing. Enemy behaviors should be identical.

### Steps

17.1. Identify Space Shooter's enemy behavior code.

17.2. Configure AIBehaviorController in Space Shooter.

17.3. Replace Space Shooter's enemy update code.

### Testing (User)

- [ ] Space Shooter enemies move correctly (straight, zigzag, dive)
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 18: TurnController Component

**What this phase accomplishes:** Creates TurnController for round-based game state management.

**What will be noticed in-game:** Nothing. This phase only creates the component.

### Steps

18.1. Create `src/utils/game_components/turn_controller.lua`:
   - Configurable state sequence (e.g., "waiting" → "animating" → "result")
   - State timing (animation duration, result display time)
   - Auto-advance option
   - Streak tracking
   - Time pressure (optional time limit per turn)
   - Callbacks: on_round_start, on_round_end, on_state_change

### Testing (User)

- [ ] Game launches without errors
- [ ] No console errors related to TurnController

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 19a: Coin Flip Turn Migration

**What this phase accomplishes:** Migrates Coin Flip's round state machine to TurnController.

**What will be noticed in-game:** Nothing. Turn flow should be identical.

### Steps

19a.1. Identify Coin Flip's round state machine.

19a.2. Configure TurnController in Coin Flip's init.

19a.3. Replace Coin Flip's state management with TurnController.

### Testing (User)

- [ ] Coin Flip round flow works (wait → flip → result → next)
- [ ] Streaks tracked correctly
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 19b: RPS Turn Migration

**What this phase accomplishes:** Migrates RPS's round state machine to TurnController.

**What will be noticed in-game:** Nothing. Turn flow should be identical.

### Steps

19b.1. Identify RPS's round state machine.

19b.2. Configure TurnController in RPS's init.

19b.3. Replace RPS's state management with TurnController.

### Testing (User)

- [ ] RPS round flow works (wait → opponent → reveal → result)
- [ ] Special rounds work (if variant exists)
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 19c: Memory Match Turn Migration

**What this phase accomplishes:** Migrates Memory Match's turn state machine to TurnController.

**What will be noticed in-game:** Nothing. Turn flow should be identical.

### Steps

19c.1. Identify Memory Match's turn state machine.

19c.2. Configure TurnController in Memory Match's init.

19c.3. Replace Memory Match's state management with TurnController.

### Testing (User)

- [ ] Memory Match turn flow works (first card → second card → check → next)
- [ ] Time limits work (if variant exists)
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 20: AIDecisionController Component + Migration

**What this phase accomplishes:** Creates AIDecisionController for choice-based AI (RPS opponent, coin bias) and migrates RPS + Coin Flip.

**What will be noticed in-game:** Nothing. AI decisions should be identical.

### Steps

20.1. Create `src/utils/game_components/ai_decision_controller.lua`:
   - Patterns: random, counter_player, repeat_last, pattern_cycle, mimic_player, biased
   - Player history tracking (for adaptive AI)
   - Configurable choices
   - Methods: `makeDecision(player_last, player_history)`, `setPattern()`

20.2. Configure in RPS for opponent AI.

20.3. Configure in Coin Flip for outcome bias patterns.

20.4. Remove now-unused AI code from both games.

### Testing (User)

- [ ] RPS opponent makes decisions correctly
- [ ] RPS AI patterns work (random, counter, cycle, etc.)
- [ ] Coin Flip outcomes follow pattern (random, biased, etc.)
- [ ] No console errors

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Phase 21: Final Cleanup + Line Count Verification

**What this phase accomplishes:** Removes any remaining dead code, verifies line count reductions, updates documentation.

**What will be noticed in-game:** Nothing.

### Steps

21.1. Audit each game file for any remaining code that should have been extracted.

21.2. Remove any dead/unused code.

21.3. Count lines in each game file and document reduction.

21.4. Update `docs/game_abstraction_analysis.md` with actual results.

21.5. Update CLAUDE.md with new component documentation.

### Testing (User)

- [ ] Run through ALL games one more time
- [ ] All games play correctly
- [ ] No console errors anywhere

### AI Notes

*[To be filled after phase completion]*

#### Line Changes
```
[filename]               +/- [n] lines
```

---

## Summary: Expected Results

### Line Reductions (Aggressive Targets)

**Target:** Games become JSON schemas + thin Lua wiring (~50-150 lines per game).

| Game | Before | After (Target) | Reduction |
|------|--------|----------------|-----------|
| Snake | 2,693 | ~120 | 96% |
| Space Shooter | 2,551 | ~150 | 94% |
| Dodge | 1,980 | ~130 | 93% |
| Breakout | 1,766 | ~120 | 93% |
| Memory Match | 1,069 | ~80 | 93% |
| RPS | 963 | ~60 | 94% |
| Coin Flip | 661 | ~50 | 92% |
| **Total** | **11,683** | **~710** | **94%** |

**What remains in each Lua file:**
- `require` statements (~10 lines)
- `init()`: SchemaLoader call + component instantiation (~20-40 lines)
- `update()`: Component update calls (~10-20 lines)
- `draw()`: Component draw calls (~10-20 lines)
- Game-specific glue (unique interactions between components) (~10-30 lines)

### Components Extended

| Component | What's Added |
|-----------|--------------|
| MovementController | Grid mode for discrete cell movement |
| EntityController | Spawn position patterns, layout patterns |

### New Components Created

| Component | Lines | Purpose |
|-----------|-------|---------|
| SchemaLoader | ~200 | Auto-load params from JSON schema |
| ArenaController | ~250 | Play area shapes, shrinking, safe zones |
| AIBehaviorController | ~300 | Enemy movement behaviors |
| TurnController | ~150 | Round-based state machine |
| AIDecisionController | ~100 | Choice-based AI decisions |
| **Total New** | **~1,000** | Reusable across all games |

### Components NOT Created (Already Exist)

| Planned | Existing Alternative |
|---------|---------------------|
| TrailSystem | PhysicsUtils.createTrailSystem() |
| SpawnPatternController | EntityController (extended) |
| GridMovementController | MovementController (extended) |
