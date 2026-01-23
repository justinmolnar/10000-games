# Snake Extraction Audit - Post-Mortem

## Summary

| Metric | Plan | Actual | Delta |
|--------|------|--------|-------|
| Starting lines | 1960 | 1960 | - |
| Target lines | 100-150 | 1170 | +1020 |
| Lines removed | ~1800 | ~790 | -1010 |
| Completion | 100% | 44% | -56% |

**Root cause:** The plan assumed aggressive extraction that didn't happen. Grid vs smooth movement was NOT unified. AI snakes were NOT converted to entities. Most "delete function" items became "simplify function" instead.

---

## Function-by-Function Audit

### init
Initializes the game. Calls parent init, gets runtime config from DI, loads parameters from snake_schema.json using SchemaLoader. Sets GRID_SIZE from runtime config. Applies cheat modifiers. Calls setupArena, creates entity controller, setupSnake, setupComponents. Creates view. Loads assets.

- **Original:** 19 lines
- **Current:** 20 lines
- **Plan:** None (keep as-is)
- **Status:** CORRECT - No extraction needed
- **Action Taken:** None needed
- **Final Lines:** 20

---

### setupArena
Determines if arena is fixed or dynamic. Calculates game_width/height from base dimensions and arena_size multiplier. Calculates grid_width/height from game dimensions divided by tile size. Sets aspect ratio locking for fixed arenas.

- **Original:** 18 lines
- **Current:** 5 lines
- **Plan:** Extract to BaseGame:setupArenaDimensions(), keep ~5 lines
- **Status:** CORRECT - Uses setupArenaDimensions(), calculates grid dimensions
- **Action Taken:** None needed
- **Final Lines:** 5

---

### _getStartingDirection
Returns starting direction as {x, y} table based on params.starting_direction ("right", "left", "up", "down"). Maps direction string to vector.

- **Original:** 4 lines
- **Current:** DELETED
- **Plan:** Delete, use CARDINAL_DIRECTIONS constant
- **Status:** CORRECT - Uses `BaseGame.CARDINAL_DIRECTIONS[self.params.starting_direction]`
- **Action Taken:** None needed
- **Final Lines:** 0 (DELETED)

---

### _initSmoothState
Creates initial state for smooth movement mode. Returns table with smooth_x, smooth_y (centered in cell), smooth_angle, trail system via PhysicsUtils.createTrailSystem(), and smooth_target_length from params.

- **Original:** 8 lines
- **Current:** 7 lines
- **Plan:** Delete, use PhysicsUtils.createTrailSystem() inline
- **Status:** PARTIAL - Uses createTrailSystem but function still exists
- **Action:** Inline into _createSnakeEntity, saves ~5 lines
- **Action Taken:** Now uses schema param `use_trail` instead of checking movement_type. Returns empty table for grid mode.
- **Final Lines:** 8

---

### _createSnakeEntity
Creates a snake entity at given x,y position. Gets starting direction from CARDINAL_DIRECTIONS. Initializes body array with single segment, direction, next_direction, alive=true. For smooth movement mode, merges in smooth state from _initSmoothState.

- **Original:** 13 lines
- **Current:** 13 lines
- **Plan:** Delete, use EntityController:spawn with snake entity type
- **Status:** NOT DONE - Still manual snake creation
- **Action:** Keep - snake body management is genuinely complex (segments follow leader, not independent entities)
- **Action Taken:** Removed mode branch - just merges _initSmoothState result (empty for grid, smooth fields for trail).
- **Final Lines:** 12

---

### _checkSpawnSafety
Checks if a position would kill the snake. Returns true (unsafe) if position is outside shaped arenas (circle/hexagon). For smooth movement, calculates distance-based collision with obstacles. For grid movement, uses checkCollision.

- **Original:** 18 lines
- **Current:** 18 lines
- **Plan:** Delete, use unified collision system
- **Status:** NOT DONE - Still has grid/smooth branching that should be encapsulated
- **Action:** checkCollision() should handle both modes internally based on movement_type
- **Action Taken:** Skip - depends on checkCollision refactor
- **Final Lines:** (REVISIT after checkCollision)

---

### _repositionSnakeAt
Repositions snake head to given spawn_x, spawn_y. Calculates direction toward arena center using getCardinalDirection. Updates snake direction. For smooth movement, updates smooth_x, smooth_y and smooth_angle. Reinitializes movement_controller grid state.

- **Original:** 11 lines
- **Current:** 11 lines
- **Plan:** Shrink naturally with unified movement
- **Status:** NOT DONE - Still has grid/smooth branching that should be in controller
- **Action:** MovementController:reposition() handles mode internally
- **Action Taken:** Skip - depends on MovementController refactor
- **Final Lines:** (REVISIT after updateSmoothMovement)

---

### _repositionAISnakesInArena
Only runs for circle/hexagon arenas. Loops through AI snakes. If alive and has body, checks if head is inside arena. If not, uses findSafePosition to find valid position that's inside arena and doesn't collide. Updates AI snake head position.

- **Original:** ~14 lines
- **Current:** 14 lines
- **Plan:** Not specified
- **Status:** DONE - Renamed to _repositionSnakesInArena, works for all snakes
- **Action Taken:** AI SNAKE UNIFICATION. Renamed to _repositionSnakesInArena. All snakes now in self.snakes array. Touched functions: _createSnakeEntity (+3 lines: behavior param, move_timer), setupSnake (rewrote AI creation using _createSnakeEntity + findSafePosition), updateGameLogic (unified movement loop for all snakes ~100 lines rewritten), checkSnakeCollisions (updated for unified array). Deleted: createAISnake (41 lines), updateAISnakes (7 lines), updateAISnake (65 lines). Removed ai_snakes array and all references.
- **Final Lines:** 12

---

### _initializeObstacles
Creates edge obstacles via createEdgeObstacles. If obstacles haven't been created yet, loops obstacle_count times calling spawnObstacleEntity. Sets _obstacles_created flag.

- **Original:** 13 lines
- **Current:** 10 lines
- **Plan:** Delete, use EntityController
- **Status:** DONE
- **Action:** Replace loop with EntityController batch spawn
- **Action Taken:** Added EntityController:spawnMultiple(count, spawner_fn) method (5 lines in entity_controller.lua). Replaced manual loop with spawnMultiple call. Also updated _spawnInitialFood (same pattern).
- **Final Lines:** 7

---

### _spawnInitialFood
If foods array is empty and _foods_spawned flag not set, loops food_count times calling spawnFoodEntity. Sets _foods_spawned flag.

- **Original:** 8 lines
- **Current:** 4 lines
- **Plan:** Delete, use EntityController
- **Status:** DONE
- **Action:** Replace loop with EntityController batch spawn, delete wrapper
- **Action Taken:** Done during _initializeObstacles - replaced loop with spawnMultiple call.
- **Final Lines:** 4

---

### _clampPositionsToSafe
Clamps all snake body segments to be within min_x, max_x, min_y, max_y bounds. Also clamps all food positions to same bounds. Used during resize when grid dimensions change.

- **Original:** 14 lines
- **Current:** DELETED
- **Plan:** Delete, EntityController handles
- **Status:** DONE - Moved to BaseGame as generic function
- **Action Taken:** Added BaseGame:clampEntitiesToBounds(entity_arrays, min_x, max_x, min_y, max_y). Deleted snake-specific function. Call site passes {self.snake.body, self:getFoods()}.
- **Final Lines:** 0 (8 lines in BaseGame, reusable)

---

### _regenerateEdgeObstacles
Removes all wall entities ("walls" and "bounce_wall" types) from obstacles. Then calls _initializeObstacles to recreate edge obstacles for new grid size. Used on resize.

- **Original:** 10 lines
- **Current:** 3 lines
- **Plan:** Delete, ArenaController handles
- **Status:** DONE - Simplified using EntityController
- **Action Taken:** Added EntityController:removeByTypes(types) (15 lines) and EntityController:regenerate(types, init_fn) (8 lines). Function now handles full resize: calculates safe interior bounds, clamps snake/food/obstacles to interior, then removes walls and reinitializes. Removed redundant clamp call from setPlayArea.
- **Final Lines:** 18

---

### setupSnake
Calculates arena center. Creates player_snakes array with snake_count snakes, each offset by multi_snake_spacing. Sets self.snake to first player snake. Sets _snake_needs_spawn flag. Initializes girth tracking, pending_growth, timers. Creates empty ai_snakes array. Loops ai_snake_count times calling createAISnake.

- **Original:** 20 lines
- **Current:** 20 lines
- **Plan:** Use EntityController for snake spawning
- **Status:** NOT DONE - Still manual snake array management
- **Action:** Keep - snake body is genuinely different from simple entities (segments follow leader)
- **Action Taken:** Moved spawn position/direction logic to EntityController:calculateSpawnPosition() and calculateSpawnDirection(). Added _spawnSnakePosition helper. Removed _findSpawnPosition, _getSpawnDirection from snake_game.
- **Final Lines:** 49

---

### setupComponents
Calls createComponentsFromSchema and createVictoryConditionFromSchema. Sets arena_controller dimensions (base_width/height, current_width/height) to grid dimensions. Calculates min_width/height from params. Sets arena_controller center, radius, safe_zone_mode for shaped arenas. Sets on_shrink callback. Initializes movement_controller state for all player snakes (smooth or grid). Initializes metrics.

- **Original:** 17 lines
- **Current:** 30 lines (GREW)
- **Plan:** Low extraction potential
- **Status:** WORSE - Added more arena_controller manual setup
- **Action:** Extract arena_controller:setGridDimensions() helper, or accept grid dims in schema config
- **Action Taken:** None - kept as-is
- **Final Lines:** 30

---

### Entity Helpers (NEW)
Wrapper functions for EntityController integration:
- `getFoods()` - returns entities with category "food" via getEntitiesByCategory
- `getObstacles()` - returns entities with category "obstacle" via getEntitiesByCategory
- `removeFood(food)` / `removeObstacle(obstacle)` - calls entity_controller:removeEntity
- `_getFoodType()` - determines food type based on golden_food_spawn_rate and bad_food_chance
- `spawnFoodEntity()` - spawns food with pattern, bounds, collision check, category
- `spawnObstacleEntity()` - spawns obstacle (static or moving) with bounds and collision check

- **Current:** 48 lines
- **Plan:** These are the EntityController integration
- **Status:** CORRECT - Good abstraction layer
- **Action Taken:** None - kept as-is
- **Final Lines:** 48

---

### setPlayArea
Called when viewport resizes. Stores viewport dimensions. For non-fixed arena: updates game/grid dimensions, updates arena_controller, clamps positions, regenerates edge obstacles. Initializes obstacles. Spawns snake if needed. Repositions snake if unsafe using findSafePosition. Repositions AI snakes in shaped arenas. Spawns initial food.

- **Original:** 49 lines
- **Current:** 33 lines
- **Plan:** Shrink to ~10 lines
- **Status:** PARTIAL - Reduced but not to target
- **Action:** Extract common spawn/reposition pattern to helper
- **Action Taken:** Now uses _regenerateEdgeObstacles (handles clamping + wall regen), _positionAllSnakes (uses EntityController:calculateSpawnPosition), _spawnInitialFood
- **Final Lines:** 28

---

### updateGameLogic
Main game loop. Updates survival_time. Updates food movement (drift/flee/chase) with timer-based movement, wrap, collision with snakes. Handles food lifetime expiration. Handles snake shrinking over time. Updates moving obstacles with bounce. Handles obstacle spawning over time. Updates AI snakes via updateAISnakesGrid. Checks snake collisions. Updates arena_controller. For smooth movement: calls updateSmoothMovement and returns. For grid movement: caps speed, uses movement_controller tick, determines direction from input, calls _moveGridSnake for each player snake.

- **Original:** 510 lines
- **Current:** 183 lines
- **Plan:** Shrink to ~20-30 lines
- **Status:** PARTIAL - Reduced from 300 to 183 via _moveGridSnake unification
- **Breakdown:**
  - Food movement: 93 lines (plan: 0) - NOT EXTRACTED to PatternMovement
  - Food lifetime: 10 lines (plan: 0) - NOT EXTRACTED to EntityController auto-expiry
  - Shrink over time: 15 lines (plan: 3) - NOT EXTRACTED
  - Moving obstacles: 23 lines (plan: 0) - NOT EXTRACTED to EntityController bounce
  - Obstacle spawning: 8 lines (plan: 0) - NOT EXTRACTED to EntityController continuous spawn
  - Grid movement: ~20 lines (was 120) - refactored to use _moveGridSnake
  - Multi-snake loop: UNIFIED via _moveGridSnake
- **Action:** Extract entity behaviors to components
- **Action Taken:** Refactored player snake grid movement loop (was ~110 lines inline) to call _moveGridSnake (~17 lines). Now both player and AI snakes use same _moveGridSnake helper. Also added initGridState call to _moveGridSnake for bounce sync. Further simplified: food movement uses tickTimer + getCardinalDirection (12 lines), food lifetime uses tickTimer (8 lines), shrink over time uses tickTimer (5 lines), moving obstacles use tickTimer + PhysicsUtils.handleBounds with vx/vy (6 lines), obstacle spawning uses tickTimer (3 lines).
- **Final Lines:** 93

---

### checkComplete
Calls victory_checker:check(). If result exists, sets victory or game_over flags. Returns true if complete.

- **Original:** 9 lines
- **Current:** DELETED
- **Plan:** Delete, BaseGame handles via VictoryCondition component
- **Status:** CORRECT
- **Action Taken:** None - already deleted, BaseGame handles
- **Final Lines:** 0 (DELETED)

---

### onComplete
Determines win/loss based on victory_condition and whether threshold was reached. Plays success sound if win. Stops music. Calls parent onComplete.

- **Original:** 19 lines
- **Current:** DELETED
- **Plan:** Delete, BaseGame handles via VictoryCondition
- **Status:** CORRECT
- **Action Taken:** None - already deleted, BaseGame handles
- **Final Lines:** 0 (DELETED)

---

### draw
Calls view:draw() if view exists.

- **Original:** 5 lines
- **Current:** DELETED
- **Plan:** Delete, BaseGame handles
- **Status:** CORRECT
- **Action Taken:** None - already deleted, BaseGame handles
- **Final Lines:** 0 (DELETED)

---

### keypressed
Calls parent keypressed for demo tracking. For smooth movement: tracks turn key presses (left/right) on all player snakes via getSmoothState. For grid movement: maps WASD/arrows to direction, queues via movement_controller:queueGridDirection, applies to additional player snakes. Returns whether input was handled.

- **Original:** 45 lines
- **Current:** 33 lines
- **Plan:** Use MovementController:handleInput()
- **Status:** PARTIAL - Has grid/smooth branching that should be in MovementController
- **Action:** MovementController:handleInput() encapsulates mode - snake_game just calls it
- **Action Taken:** Added MovementController:handleInput(). Keypressed now 1 line calling controller.
- **Final Lines:** 4

---

### keyreleased
Calls parent keyreleased for demo tracking. For smooth movement: clears turn key states (left/right) on all player snakes when released.

- **Original:** 13 lines
- **Current:** 16 lines (GREW)
- **Plan:** Use MovementController:handleInput()
- **Status:** NOT DONE - Still manual turn flag management
- **Action:** MovementController:handleInput() handles release for smooth mode internally
- **Action Taken:** Added MovementController:handleInputRelease(). Keyreleased now 1 line calling controller.
- **Final Lines:** 4

---

### updateSmoothMovement
Dispatches smooth movement update to all player snakes. Calculates head_radius and food_radius based on girth. Calls _updateSmoothSnake for main snake and additional player snakes.

- **Original:** 409 lines
- **Current:** 16 lines (dispatch) + 61 lines (_updateSmoothSnake)
- **Plan:** DELETE ENTIRELY - unified with grid
- **Status:** KEPT - Trail system is snake-specific, not worth unifying
- **Action Taken:** None - dispatch function unchanged
- **Final Lines:** 16

---

### _updateSmoothSnake (NEW)
Handles single snake smooth movement. Uses MovementController:updateSmooth for rotation and movement. Manages trail via PhysicsUtils. Checks arena bounds, self-collision via trail, entity collisions (food/obstacles/walls).

- **Current:** 61 lines
- **Plan:** Should not exist - unified with grid
- **Status:** KEPT - Trail collision is snake-specific, entity collision uses schema on_collision handlers
- **Action Taken:** Uses entity_controller:checkCollision with on_collision handlers (collect/bounce/death). Death handler skips own snake_body entities (trail handles self-collision separately).
- **Final Lines:** 61

---

### _isWallAt
- **Current:** DELETED
- **Action Taken:** Removed - collision now uses entity_controller:checkCollision with on_collision handlers
- **Final Lines:** 0

---

### _moveGridSnake
Handles single snake grid movement. Calculates new head position with wrap. Checks collisions via entity_controller with on_collision handlers (bounce/death). Uses moveChain for body cascade. Checks food collision (collect handler). Spawns new segment on growth.

- **Current:** 65 lines
- **Action Taken:** Body segments now entities with chain movement defined in schema. Self-collision via entity system (snake_body on_collision: "death"). Added EntityController:moveChain() for position cascade. Removed manual self-collision loop from checkCollision().
- **Final Lines:** 65

---

### _findBounceAngle (NEW)
Finds best bounce angle for smooth movement. Tests +45° and -45° from current angle. Raycasts each direction checking for obstacle collision and arena bounds. Returns angle with more clear space.

- **Current:** 16 lines
- **Plan:** PhysicsUtils should handle bounce
- **Status:** CORRECT - smooth-specific bounce raycast
- **Action Taken:** None
- **Final Lines:**

---

### spawnFood
Spawns food at position based on food_spawn_pattern (cluster/line/spiral/random). Loops until position doesn't collide. Determines food type (golden/bad/normal) with weighted probability. Applies size variance. Returns food table.

- **Original:** 98 lines
- **Current:** DELETED
- **Plan:** Delete, use EntityController patterns
- **Status:** CORRECT - Replaced with spawnFoodEntity() using EntityController
- **Action Taken:**
- **Final Lines:**

---

### createAISnake
Spawns AI snake at random position far from player. Loops up to 200 attempts finding position that's: >10 Manhattan distance from player, not colliding, inside arena for shaped arenas. Falls back to center+offset. Returns AI snake table with body, direction, move_timer, length, alive, behavior, target_food.

- **Original:** 41 lines
- **Current:** DELETED
- **Plan:** Delete, use EntityController:spawn with AI config
- **Status:** DONE - Deleted during AI snake unification
- **Action Taken:** DELETED during _repositionAISnakesInArena unification. See that entry for full details.
- **Final Lines:** 0

---

### updateAISnakes
Loops through ai_snakes array. For each alive snake, calls updateAISnake.

- **Original:** 7 lines
- **Current:** DELETED
- **Plan:** Delete, EntityController iteration
- **Status:** DONE - Replaced with updateAISnakesGrid during AI snake unification
- **Action Taken:** DELETED during AI snake unification. See _repositionAISnakesInArena entry.
- **Final Lines:** 0

---

### updateAISnake
Handles single AI snake update. Increments move_timer. On move interval: determines direction based on behavior ("aggressive" chases player, "defensive" flees, "food_focused" chases nearest food via findNearest). Handles wall_mode (wrap/death/bounce). Checks collision. Inserts new head. Checks food, removes tail if didn't eat.

- **Original:** 116 lines
- **Current:** DELETED
- **Plan:** Delete, unified with player snake via entities
- **Status:** DONE - Replaced with updateAISnakesGrid (27 lines) + _moveGridSnake (67 lines shared)
- **Action Taken:** DELETED during AI snake unification. Replaced with updateAISnakesGrid which computes direction from behavior then calls shared _moveGridSnake. Movement logic unified - player and AI use same helper.
- **Final Lines:** 0 (replaced by updateAISnakesGrid 27 lines + shared _moveGridSnake)

---

### checkSnakeCollisions
Checks collisions between player and AI snakes. For head-to-head: handles based on snake_collision_mode ("both_die" kills both, "big_eats_small" absorbs smaller, "phase_through" ignores). Also checks player head hitting AI body segments.

- **Original:** 47 lines
- **Current:** 43 lines
- **Plan:** Delete, EntityController collision callbacks
- **Status:** NOT DONE - Still manual collision modes
- **Action:** Use EntityController collision callbacks with mode config
- **Action Taken:** DELETED. Logic moved to _moveGridSnake death handler. Uses entity.owner to distinguish own vs other snake. Reads snake_collision_mode from schema. Added "phase_through" to schema enum.
- **Final Lines:** 0

---

### createEdgeObstacles
Creates wall obstacles at arena edges. Skips for wrap mode or shaped arenas (those use bounds check). Sets wall_type based on bounce mode. Gets boundary cells from arena_controller:getBoundaryCells(). Builds snake position set to avoid. Spawns obstacle entities for each boundary cell not occupied by snake.

- **Original:** 52 lines
- **Current:** 18 lines
- **Plan:** Delete, ArenaController + view handles
- **Status:** PARTIAL - Uses getBoundaryCells but still spawns wall entities
- **Action:** View should render walls directly from ArenaController bounds, no wall entities needed
- **Action Taken:** Added EntityController:spawnAtCells(type, cells, is_valid_fn). Simplified to use spawnAtCells with occupied position check.
- **Final Lines:** 11**

---

### createObstacles
Creates variant obstacles. Calculates count from param × difficulty modifier. Loops creating obstacles at random positions that don't collide. For moving_blocks, initializes random movement direction. Returns obstacles array.

- **Original:** 32 lines
- **Current:** DELETED
- **Plan:** Delete, use EntityController
- **Status:** CORRECT - Replaced with spawnObstacleEntity() using EntityController
- **Action Taken:**
- **Final Lines:**

---

### onArenaShrink
Callback for arena shrinking. Spawns wall obstacle entities at the new margins on all four sides (left, right, top, bottom).

- **Original:** 23 lines
- **Current:** 11 lines
- **Plan:** Delete, ArenaController handles
- **Status:** PARTIAL - Simplified but still spawns wall entities
- **Action:** ArenaController + view should handle boundary visualization, no callback needed
- **Action Taken:** None - kept as-is. Wall entities needed for collision.
- **Final Lines:** 11**

---

### syncArenaState
Syncs grid_width and grid_height from arena_controller's current dimensions.

- **Original:** 4 lines
- **Current:** DELETED (inlined)
- **Plan:** Delete, read from arena_controller directly
- **Status:** CORRECT
- **Action Taken:**
- **Final Lines:**

---

### isInsideArena
Wrapper that calls arena_controller:isInsideGrid(pos.x, pos.y, margin). Thin wrapper for readability.

- **Original:** 3 lines
- **Current:** 3 lines
- **Plan:** Keep as-is
- **Status:** CORRECT
- **Action Taken:** None - kept as-is.
- **Final Lines:** 3**

---

### getGirthCells
Returns all grid cells occupied by a position with given girth. Girth expands perpendicular to movement direction. Without direction, returns single cell. Calculates perpendicular direction based on movement axis. Returns array of cell positions centered around input.

- **Original:** 40 lines
- **Current:** 40 lines
- **Plan:** Keep (snake-specific girth mechanic)
- **Status:** CORRECT
- **Action Taken:** None - kept as-is.
- **Final Lines:** 40**

---

### checkGirthCollision
Checks if two girth-expanded positions collide. Gets cells for both positions via getGirthCells. Compares all cell pairs for overlap. Returns true if any cells overlap.

- **Original:** 14 lines
- **Current:** 14 lines
- **Plan:** Keep (snake-specific girth mechanic)
- **Status:** CORRECT
- **Action Taken:**
- **Final Lines:**

---

### collectFood
Handles food collection by any snake. For bad food: shrinks snake (removes segments or reduces smooth_target_length). For golden/normal: grows snake, increases speed if speed_increase_per_food > 0, plays sound. Tracks girth growth progress if enabled.

- **Original:** 50 lines
- **Current:** 34 lines
- **Plan:** Shrink, food effects via entity config
- **Status:** PARTIAL - Has grid/smooth branch that should be encapsulated
- **Action:** Growth logic could be in snake entity or helper - snake_game passes growth amount, entity handles mode
- **Action Taken:** Simplified to use food.growth from schema directly. Mode branching reduced from 14 to 4 lines.
- **Final Lines:** 27**

---

### checkCollision
Checks if position collides with obstacles. For shaped arenas, checks arena bounds first. Gets all cells for position with current girth. Checks each cell against all obstacles.

- **Original:** 43 lines
- **Current:** 21 lines
- **Plan:** Simplify with unified collision
- **Status:** DONE - Removed manual self-collision code (now via entity system)
- **Action Taken:** Removed check_snake_body parameter and manual snake body collision loop (~25 lines). Self-collision now handled via entity system - grid segments are snake_body entities with on_collision: "death", smooth uses PhysicsUtils trail checkSelfCollision.
- **Final Lines:** 21

---

### checkGirthCollision
- **Current:** DELETED
- **Action Taken:** Removed - was only used by manual self-collision code
- **Final Lines:**

---

### _spawnSnakeSafe
Finds safe spawn position for snake using findSafePosition with collision check. Falls back to center if none found. Updates snake body position. Calculates direction toward center. Syncs movement_controller. Updates smooth position/angle if smooth mode.

- **Original:** 97 lines
- **Current:** DELETED (replaced by _spawnSnakePosition)
- **Plan:** Shrink to ~5-10 lines using helpers
- **Status:** DONE - Replaced with _spawnSnakePosition which delegates to EntityController:calculateSpawnPosition
- **Action:** Reduce to findSafePosition + _repositionSnakeAt (which handles mode internally)
- **Action Taken:** Replaced with _spawnSnakePosition (19 lines). Uses entity_controller:calculateSpawnPosition for all spawn logic.
- **Final Lines:** 0 (replaced by 19-line _spawnSnakePosition)**

---

## Key Issues

### 1. Grid/Smooth Branching Scattered Throughout (Critical)
Grid and smooth are separate movement systems - that's correct. But the BRANCHING logic is scattered throughout snake_game.lua instead of encapsulated in MovementController.

**Current problem:** `if movement_type == "smooth" then X else Y` appears in:
- updateGameLogic (line 475)
- _checkSpawnSafety
- _repositionSnakeAt
- keypressed
- keyreleased
- collectFood
- _spawnSnakeSafe

**Should be:** Snake_game calls `movement_controller:update()` and the controller handles the mode internally based on schema config. The game shouldn't need branching - MovementController knows its mode.

**Impact:** ~200 lines of scattered branching that should be 0 in snake_game

### 2. Food/Obstacle Behaviors NOT Extracted
Food movement (drift/flee/chase), food lifetime, moving obstacles, obstacle spawning - all still manual loops in updateGameLogic.

**Impact:** ~150 lines that could be 0 with PatternMovement/EntityController

### 3. Multi-Snake Loop NOT Unified - RESOLVED
~~Player snake and additional player snakes still have separate update loops.~~

**FIXED:** All snakes (player primary, player additional, AI) now in unified self.snakes array and use _moveGridSnake. Single loop handles all snakes - only direction determination differs.

**Impact:** Saved ~60 lines

### 4. AI Snake Movement Duplicates Player - RESOLVED
~~AI snakes duplicate player movement logic (wall handling, collision, eating). Only difference is direction source (AI behavior vs input).~~

**FIXED:** Created _moveGridSnake helper (67 lines) used by both:
- updateAISnakesGrid: computes direction from behavior, calls _moveGridSnake
- Player loop in updateGameLogic: gets direction from input, calls _moveGridSnake

**Impact:** Saved ~90 lines of duplicated code

