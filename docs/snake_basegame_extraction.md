# Snake BaseGame Extraction Plan

## Goal

**Extract generic patterns from snake_game.lua to BaseGame and components.**

The key insight: snake has two parallel implementations (grid mode and smooth mode) that should be unified, and most entity management reimplements what EntityController already does.

- **Current:** 1960 lines
- **Target:** ~100-150 lines (girth-specific code stays)
- **Lines to extract/delete:** ~1800 lines

## What Gets Extracted

**New BaseGame functions/constants:**
- `CARDINAL_DIRECTIONS` - constant table {right={x=1,y=0}, left={x=-1,y=0}, ...}
- `getCardinalFromAngle(angle)` - returns nearest cardinal direction from angle
- `setupArenaDimensions()` - fixed vs dynamic arena, camera zoom, aspect ratio

**Component additions:**
- MovementController: `follow_grid` pattern for snake body segments
- MovementController: unified input handling (press/release for discrete/continuous modes)
- ArenaController: `getBoundaryCells()` for wall visualization
- EntityController: `spawnCluster`, `spawnLine`, `spawnSpiral` patterns
- EntityController: `min_distance_from` spawn constraint
- PhysicsUtils.createTrailSystem: self-intersection check

**Entity types (schema-defined):**
- snake: player and AI unified, with behavior config
- food: types (normal/bad/golden) as entity variants
- obstacle: static and moving types

---

## Rules for AI

1. Complete ALL steps within a phase before stopping.
2. After completing a phase, write notes including **exact line count change**.
3. Do NOT proceed to the next phase without user approval.
4. Run NO tests yourself - the user will do manual testing.
5. When adding to BaseGame/components, ensure breakout and space_shooter still work.
6. Delete the snake_game functions after extraction - no wrappers.
7. If a function is deleted, update all callers immediately.
8. Update game_components_reference.md when components are added or changed.

**FORBIDDEN:**
- Wrapper functions that just call the extracted version
- "Preserved for reference" comments
- Backward compatibility shims
- Partial deletions
- Separate code paths for grid vs smooth (must be unified)

---

## Phase 1: Direction & Arena Utilities

Add direction constants and arena setup to BaseGame.

### Steps

1.1. **Add BaseGame.CARDINAL_DIRECTIONS constant**
     - `{right={x=1,y=0}, left={x=-1,y=0}, up={x=0,y=-1}, down={x=0,y=1}}`
     - Complements existing getCardinalDirection function

1.2. **Add BaseGame:getCardinalFromAngle(angle)**
     - Takes angle in radians
     - Returns nearest cardinal direction {x, y}
     - Uses CARDINAL_DIRECTIONS

1.3. **Add BaseGame:setupArenaDimensions()**
     - Determines is_fixed_arena from variant.arena_size
     - Calculates game_width/height from base dimensions × arena_size
     - Handles camera_zoom for non-fixed arenas
     - Sets lock_aspect_ratio for fixed + fixed camera

1.4. **Update snake_game.lua:**
     - Delete _getStartingDirection() (4 lines) - use `BaseGame.CARDINAL_DIRECTIONS[self.params.starting_direction]`
     - Simplify setupArena() to call `self:setupArenaDimensions()` then calculate grid dimensions

### Lines Changed
- base_game.lua: +~40 lines
- snake_game.lua: -~15 lines

### Testing (User)
- [ ] Snake starts moving in correct direction
- [ ] Fixed arena variants work
- [ ] Dynamic arena (fills viewport) works
- [ ] Camera zoom works

### AI Notes
**Completed.**

Changes made:
- Added `BaseGame.CARDINAL_DIRECTIONS` constant (8 lines)
- Added `BaseGame:getCardinalFromAngle(angle)` function (15 lines)
- Added `BaseGame:setupArenaDimensions()` function (15 lines)
- Deleted `SnakeGame:_getStartingDirection()` (4 lines)
- Simplified `SnakeGame:setupArena()` to use `setupArenaDimensions()` (-12 lines)

**Line count change:**
- snake_game.lua: 1960 → 1944 (-16 lines)
- base_game.lua: +38 lines

---

## Phase 2: Entity System Foundation

Define entities in schema, use EntityController for food and obstacles.

### Steps

2.1. **Update snake_schema.json entity_types:**
     - Add food entity type with variants (normal, bad, golden)
     - Add obstacle entity type with variants (static_blocks, moving_blocks)
     - Define spawn patterns in schema

2.2. **Add EntityController spawn patterns:**
     - `spawnCluster(type, count, ref_entity, radius)` - spawn near existing entity
     - `spawnLine(type, count, axis, position, variance)` - spawn along axis
     - `spawnSpiral(type, state)` - spawn in expanding/contracting spiral
     - `min_distance_from` constraint for spawn position

2.3. **Update snake_game.lua:**
     - Delete _initializeObstacles() (13 lines) - use EntityController
     - Delete _spawnInitialFood() (8 lines) - use EntityController
     - Delete spawnFood() (98 lines) - use EntityController spawn patterns
     - Delete createObstacles() (32 lines) - use EntityController:spawnRandom
     - Delete manual foods/obstacles arrays - use getEntitiesByType()

### Lines Changed
- entity_controller.lua: +~60 lines
- snake_schema.json: +~30 lines
- snake_game.lua: -~150 lines

### Testing (User)
- [ ] Food spawns correctly (random, cluster, line, spiral patterns)
- [ ] Food types work (normal, bad, golden)
- [ ] Obstacles spawn correctly
- [ ] Moving obstacles bounce

### AI Notes
(To be filled after completion)

---

## Phase 3: Trail System & Smooth State

Use existing trail system, simplify smooth state.

### Steps

3.1. **Enhance PhysicsUtils.createTrailSystem:**
     - Add `checkSelfIntersection(skip_length)` method
     - Returns true if trail intersects itself (for self-collision)

3.2. **Update snake_game.lua:**
     - Delete _initSmoothState() (8 lines) - use createTrailSystem + inline init
     - Replace manual smooth_trail array with trail system
     - Read smooth_target_length directly from params.smooth_initial_length
     - Simplify smooth movement trail management

### Lines Changed
- physics_utils.lua: +~15 lines
- snake_game.lua: -~30 lines

### Testing (User)
- [ ] Smooth movement trail renders correctly
- [ ] Trail length grows when eating food
- [ ] Self-collision detection works in smooth mode

### AI Notes
(To be filled after completion)

---

## Phase 4: Unified Movement

Unify grid and smooth movement - no separate code paths.

### Steps

4.1. **Add MovementController follow_grid pattern:**
     - Segments follow leader's position history
     - Works for both discrete (integer) and continuous (float) coordinates
     - Handles growth (spawn segment at tail when vacated)

4.2. **Unify grid/smooth in MovementController:**
     - Grid mode: discrete positions, direction queuing
     - Smooth mode: continuous positions, rotation-based turning
     - Same movement functions, different mode config

4.3. **Add MovementController input handling:**
     - `handleInput(key, event_type, entity)` - handles press/release
     - Knows if mode is discrete (queue direction) or continuous (set turn flags)

4.4. **Update snake_game.lua:**
     - Delete updateSmoothMovement() (409 lines) - unified with grid
     - Simplify updateGameLogic() movement section - single code path
     - Delete smooth vs grid branching throughout
     - Simplify keypressed/keyreleased - use MovementController:handleInput

### Lines Changed
- movement_controller.lua: +~80 lines
- snake_game.lua: -~500 lines

### Testing (User)
- [ ] Grid movement works
- [ ] Smooth movement works
- [ ] Wall modes work (wrap, death, bounce) in both modes
- [ ] Input handling works for both modes

### AI Notes
(To be filled after completion)

---

## Phase 5: Snake Entity Unification

Player and AI snakes as unified entity type.

### Steps

5.1. **Define snake entity type:**
     - body array (or uses follow_grid segments)
     - direction source: player input or AI behavior
     - AI behaviors: chase(target), flee(target), food_focused

5.2. **Add AI behaviors to PatternMovement or EntityController:**
     - chase: move toward target (player or food)
     - flee: move away from target
     - food_focused: chase nearest food entity

5.3. **Update snake_game.lua:**
     - Delete _createSnakeEntity() (13 lines) - EntityController:spawn
     - Delete createAISnake() (41 lines) - EntityController:spawn with AI config
     - Delete updateAISnakes() (7 lines) - EntityController iteration
     - Delete updateAISnake() (116 lines) - unified movement handles it
     - Delete checkSnakeCollisions() (47 lines) - EntityController collision
     - Delete setupSnake() spawn loops - EntityController:spawn

### Lines Changed
- entity_controller.lua or pattern_movement.lua: +~40 lines
- snake_game.lua: -~230 lines

### Testing (User)
- [ ] Player snake works
- [ ] AI snakes spawn and move
- [ ] AI behaviors work (aggressive, defensive, food_focused)
- [ ] Snake collisions work (both_die, big_eats_small)

### AI Notes
(To be filled after completion)

---

## Phase 6: Collision & Bounds

Unified collision, wall visualization via ArenaController.

### Steps

6.1. **Add ArenaController:getBoundaryCells()**
     - Returns cells to render as walls based on shape and wall_mode
     - Rectangle: perimeter cells
     - Circle/hexagon: cells outside shape boundary
     - View renders these, no wall entities needed

6.2. **Unify collision checking:**
     - Single collision function for grid and smooth
     - Takes position + size (girth for snake)
     - Checks arena bounds, obstacles, entities

6.3. **Update snake_game.lua:**
     - Delete createEdgeObstacles() (52 lines) - ArenaController handles
     - Delete onArenaShrink() (23 lines) - ArenaController state + view
     - Delete syncArenaState() (4 lines) - read from ArenaController directly
     - Delete _checkSpawnSafety() (18 lines) - unified collision
     - Simplify checkCollision() - use unified system + girth

6.4. **Update snake_view.lua:**
     - Get boundary cells from ArenaController:getBoundaryCells()
     - Render them as walls

### Lines Changed
- arena_controller.lua: +~30 lines
- snake_game.lua: -~100 lines
- snake_view.lua: ~0 (changed, not added)

### Testing (User)
- [ ] Walls render correctly for rectangle arena
- [ ] Walls render correctly for circle/hexagon arena
- [ ] Shrinking arena walls appear correctly
- [ ] Collision detection works

### AI Notes
(To be filled after completion)

---

## Phase 7: Completion & Lifecycle

Use VictoryCondition auto-handling, delete overrides.

### Steps

7.1. **Verify BaseGame handles:**
     - checkComplete() via VictoryCondition (already done in space_shooter)
     - onComplete() with win/lose sounds (already done)
     - draw() calling view:draw() (already done)

7.2. **Update snake_game.lua:**
     - Delete checkComplete() (9 lines) - BaseGame handles
     - Delete onComplete() (19 lines) - BaseGame handles
     - Delete draw() (5 lines) - BaseGame handles

### Lines Changed
- snake_game.lua: -~33 lines

### Testing (User)
- [ ] Victory triggers on reaching length/time goal
- [ ] Loss triggers on death
- [ ] Win/lose sounds play
- [ ] Game renders correctly

### AI Notes
(To be filled after completion)

---

## Phase 8: Final Cleanup

Delete remaining redundant code, simplify helpers.

### Steps

8.1. **Simplify remaining functions:**
     - _repositionSnakeAt() - use getCardinalDirection (already does)
     - _repositionAISnakesInArena() - use EntityController reposition
     - _clampPositionsToSafe() - EntityController handles
     - _regenerateEdgeObstacles() - ArenaController handles
     - _spawnSnakeSafe() - use findSafePosition + reposition helper

8.2. **Delete redundant helpers:**
     - Delete _clampPositionsToSafe() (14 lines)
     - Delete _regenerateEdgeObstacles() (10 lines)
     - Delete _repositionAISnakesInArena() (14 lines)
     - Simplify _spawnSnakeSafe() (97 lines → ~10 lines)

8.3. **Simplify setPlayArea:**
     - BaseGame handles dimension calculation
     - EntityController handles entity repositioning
     - Delete duplicate fixed/non-fixed branches

8.4. **Clean up updateGameLogic:**
     - Food movement handled by PatternMovement
     - Food lifetime handled by EntityController
     - Shrink over time: simple timer
     - Moving obstacles: EntityController bounce behavior
     - Obstacle spawning: EntityController continuous mode
     - Most logic deleted, ~20-30 lines remain

8.5. **Remove debug prints**

### Lines Changed
- snake_game.lua: -~600 lines

### Testing (User)
- [ ] All snake variants work
- [ ] Multi-snake mode works
- [ ] All food patterns work
- [ ] All arena shapes work
- [ ] No console errors or debug output

### AI Notes
(To be filled after completion)

---

## Phase 9: Code Organization

Organize remaining code with section headers.

### Steps

9.1. **Add module docblock:**
```lua
--[[
    Snake Game - Classic snake with extensive variants

    Supports grid-based and smooth (analog) movement modes.
    Features: multiple snakes, AI snakes, food types, obstacles,
    arena shapes, wall modes, girth expansion.

    Most configuration from snake_schema.json via SchemaLoader.
    Components created from schema in setupComponents().

    Snake-specific: girth system (width expansion perpendicular to movement)
]]
```

9.2. **Add section headers:**
```
--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Girth System (Snake-Specific)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Event Callbacks
--------------------------------------------------------------------------------
```

9.3. **Keep snake-specific code:**
     - getGirthCells() (40 lines)
     - checkGirthCollision() (14 lines)
     - Girth tracking in collectFood callback (~8 lines)
     - isInsideArena() wrapper (3 lines)

### Lines Changed
- snake_game.lua: +~15 lines (headers, docblock)

### Testing (User)
- [ ] Code compiles and runs
- [ ] No behavior changes

### AI Notes
(To be filled after completion)

---

## Summary

| Phase | Focus | Snake Game | BaseGame/Components |
|-------|-------|------------|---------------------|
| 1 | Direction & arena | -15 | +40 |
| 2 | Entity foundation | -150 | +90 |
| 3 | Trail system | -30 | +15 |
| 4 | Unified movement | -500 | +80 |
| 5 | Snake entities | -230 | +40 |
| 6 | Collision & bounds | -100 | +30 |
| 7 | Completion | -33 | +0 |
| 8 | Final cleanup | -600 | +0 |
| 9 | Organization | +15 | +0 |
| **Total** | | **-1643 lines** | **+295 lines** |

### Result

- **snake_game.lua:** 1960 → ~100-150 lines
- **New reusable code:** ~295 lines in BaseGame/components
- **Every future game** gets unified movement, entity spawning patterns, arena utilities
- **Snake-specific:** Only girth system (~65 lines) remains

---

## Verification

After ALL phases complete:
- [ ] snake_game.lua under 200 lines
- [ ] All snake variants work (grid, smooth, multi-snake, AI)
- [ ] All arena shapes work (rectangle, circle, hexagon)
- [ ] All wall modes work (wrap, death, bounce)
- [ ] breakout.lua still works
- [ ] space_shooter.lua still works
- [ ] No wrapper functions
- [ ] No grid vs smooth code branching
