# Snake Game Function Reference

## init
Initializes the game. Calls parent init with game_data, cheats, DI container, and variant_override. Gets runtime config from DI. Loads parameters from snake_schema.json using SchemaLoader. Sets GRID_SIZE from runtime config. Applies cheat modifiers to speed, advantage, and performance params. Calls setupArena, setupSnake, setupComponents. Creates the view. Calls loadAssets.

**Notes:** 19 lines. Standard init pattern matching breakout/space_shooter.

**Extraction Potential:** None.

---

## setupArena
Determines if arena is fixed (variant specifies arena_size). Calculates game_width and game_height from base dimensions and arena_size multiplier. Calculates grid_width and grid_height from game dimensions divided by tile size (accounting for camera zoom for non-fixed arenas). Sets lock_aspect_ratio if fixed arena with fixed camera mode. Prints debug info.

**Notes:** 18 lines including debug print. Fixed vs dynamic arena, camera zoom, and aspect ratio locking are universal concepts that apply to pixel games too, not just grid games.

**Extraction Potential:** High. Extract fixed-arena detection, game dimension calculation, camera zoom handling, and aspect ratio locking to BaseGame:setupArenaDimensions(). Snake's setupArena becomes ~5 lines that calls the base method then calculates grid_width/grid_height from game dimensions / cell_size. Future grid games do the same one-liner for grid dimensions.

---

## _getStartingDirection
Returns the starting direction as {x, y} table based on params.starting_direction ("right", "left", "up", "down"). Defaults to right if invalid.

**Notes:** 4 lines. Maps direction string to vector.

**Extraction Potential:** High. Add CARDINAL_DIRECTIONS constant table and getCardinalFromAngle(angle) helper to BaseGame. Delete this function entirely - replace with direct table lookup `BaseGame.CARDINAL_DIRECTIONS[self.params.starting_direction]`. Complements existing getCardinalDirection function for a complete direction utilities set.

---

## _initSmoothState
Creates initial state table for smooth movement mode. Returns table with smooth_x, smooth_y (centered in cell), smooth_angle, empty smooth_trail array, smooth_trail_length=0, smooth_target_length from param, and turn flags.

**Notes:** 8 lines. Breakout also has ball trails via PhysicsUtils.createTrailSystem().

**Extraction Potential:** Medium-High. Use PhysicsUtils.createTrailSystem() instead of manual trail array. smooth_target_length is redundant - just read params.smooth_initial_length directly. Remaining fields (position, angle, turn flags) can be initialized inline in _createSnakeEntity. Delete this function entirely.

---

## _createSnakeEntity
Creates a snake entity at given x,y position. Gets starting direction. Initializes body array with single segment, direction, next_direction, and alive=true. If smooth movement mode, merges in smooth state from _initSmoothState.

**Notes:** 13 lines. Player snake and AI snakes duplicate movement/collision/eating logic.

**Extraction Potential:** Medium-High. Define snake as entity type in schema. Use EntityController to spawn player + AI snakes. Add "follow_grid" movement pattern to PatternMovement or as EntityController behavior - segments follow leader position history. Player vs AI is just input source. Eliminates player/AI snake duplication.

---

## _checkSpawnSafety
Checks if a position would kill the snake. Returns true (unsafe) if position is outside shaped arenas (circle/hexagon). For smooth movement, calculates distance-based collision with obstacles. For grid movement, uses checkCollision. Returns false if position is safe.

**Notes:** 18 lines. Arena shape check is redundant with isInsideArena. Smooth vs grid branching mirrors the broader duplication problem.

**Extraction Potential:** High. Unified collision system in BaseGame or PhysicsUtils eliminates this function. One collision check that takes position + size, works for grid or continuous coords, checks obstacles/arena/entities. Delete this function - call unified collision inline or as simple wrapper.

---

## _repositionSnakeAt
Repositions the snake head to given spawn_x, spawn_y. Calculates direction toward arena center using BaseGame:getCardinalDirection. Updates snake direction. For smooth movement, updates smooth_x, smooth_y (centered), and smooth_angle. Reinitializes movement_controller grid state with new direction.

**Notes:** 11 lines. Already uses getCardinalDirection (good). Smooth vs grid branching appears again.

**Extraction Potential:** Medium. Smooth vs grid branching eliminated when state is unified. If snake becomes entity type via EntityController, repositioning is just entity position update - movement system handles direction/state. Will shrink naturally with other extractions.

---

## _repositionAISnakesInArena
Only runs for circle/hexagon arenas. Loops through AI snakes. If alive and has body, checks if head is inside arena. If not, uses BaseGame:findSafePosition to find valid position that's inside arena and doesn't collide. Updates AI snake head position.

**Notes:**

**Extraction Potential:**

---

## _initializeObstacles
If obstacles haven't been created yet, calls createObstacles to get variant obstacles and inserts them into obstacles array. Sets _obstacles_created flag. Then calls createEdgeObstacles and adds all edge obstacles to the obstacles array.

**Notes:** 13 lines. Manual obstacle management with _obstacles_created flag for lifecycle tracking.

**Extraction Potential:** Medium-High. EntityController should handle this. Obstacles are entities - define in schema, spawn via EntityController. The flag is manual lifecycle management that EntityController handles automatically. Edge obstacles are a spawn pattern (perimeter spawn) that could be generic. Delete function - use EntityController:spawnLayout or spawnRandom.

---

## _spawnInitialFood
If foods array is empty and _foods_spawned flag not set, loops food_count times and inserts spawnFood results into foods array. Sets _foods_spawned flag.

**Notes:** 8 lines. Same manual entity management pattern with lifecycle flag.

**Extraction Potential:** High. Food is an entity type. EntityController:spawnRandom("food", count, bounds) for initial spawn, EntityController handles continuous respawn automatically. Delete this function entirely.

---

## _clampPositionsToSafe
Clamps all snake body segments to be within min_x, max_x, min_y, max_y bounds. Also clamps all food positions to same bounds.

**Notes:** 14 lines. Used during resize when grid dimensions change. Simple clamp math.

**Extraction Potential:** Medium. If entities use EntityController, becomes generic EntityController:clampAllToBounds(bounds) for any entity type. PhysicsUtils.handleBounds already does clamp/wrap/bounce. If snake segments are entities, body loop goes away.

---

## _regenerateEdgeObstacles
Filters obstacles array to keep only non-wall obstacles (removes "walls" and "bounce_wall" types). Then calls _initializeObstacles to recreate edge obstacles for new grid size.

**Notes:** 10 lines. Manual filter-and-rebuild pattern for edge walls on resize.

**Extraction Potential:** Medium-High. If EntityController manages obstacles: EntityController:removeByType("wall") then EntityController:spawnPerimeter("wall", bounds). Filter loop is manual entity management that EntityController's type system handles automatically.

---

## setupSnake
Calculates arena center. Creates player_snakes array with snake_count snakes, each offset by multi_snake_spacing. Sets self.snake to first player snake. Sets _snake_needs_spawn flag. Initializes girth tracking, pending_growth, timers. Creates empty foods, obstacles, ai_snakes arrays. Loops ai_snake_count times calling createAISnake.

**Notes:** 20 lines. Two spawn loops (player snakes, AI snakes) plus state initialization. Manual arrays and lifecycle flag.

**Extraction Potential:** Medium-High. If snakes use EntityController: spawn calls replace loops, getEntitiesByType replaces manual arrays, girth/growth tracking becomes entity state. The _snake_needs_spawn flag is manual lifecycle management that EntityController handles.

---

## setupComponents
Calls createComponentsFromSchema, createEntityControllerFromSchema, createVictoryConditionFromSchema. Sets arena_controller dimensions (base_width, base_height, current_width, current_height) to grid dimensions. Calculates min_width/min_height from min_arena_cells and min_arena_ratio. Sets arena_controller on_shrink callback. Initializes movement_controller grid state. Initializes metrics.

**Notes:** 17 lines. Schema-based creation (good). Manual arena_controller property setting is ugly.

**Extraction Potential:** Low-Medium. Schema-based creation is correct pattern. Arena_controller manual property setting should be arena_controller:setGridDimensions() or accept grid dimensions in schema config. If setupArena extraction happens, arena_controller gets dimensions from that.

---

## setPlayArea
Called when viewport resizes. Stores viewport dimensions. Prints debug info. If fixed arena: initializes obstacles, spawns snake if needed, repositions snake if in unsafe position using findSafePosition, repositions AI snakes, spawns initial food. If non-fixed arena: updates game dimensions to viewport size, recalculates grid dimensions, updates arena_controller dimensions, clamps positions, regenerates edge obstacles, spawns snake/AI/food as needed.

**Notes:** 49 lines. Major duplication between fixed/non-fixed branches. Lots of debug prints.

**Extraction Potential:** High. Both branches do spawn snake, reposition snake, reposition AI, spawn food - only difference is dimension recalculation. If BaseGame handles dimensions and EntityController manages entities, shrinks to ~10 lines.

---

## updateGameLogic
Main game loop (510 lines). Updates survival_time metric. Handles moving food (drift, flee_from_snake, chase_snake) with timer-based movement, wrap support, collision with snakes. Handles food lifetime expiration. Handles snake shrinking over time. Updates moving obstacles with bounce. Handles obstacle spawning over time. Updates AI snakes. Checks snake collisions. Updates arena_controller and syncs state. For smooth movement, calls updateSmoothMovement and returns. For grid movement: caps speed, uses movement_controller tick timing, applies queued direction, calculates new head based on wall_mode (wrap/death/bounce), handles bounce mode wall detection with perpendicular direction finding, checks collision, inserts new head, checks food collision with girth support and food types (bad/golden/normal), handles growth/tail removal, updates length metric, moves additional player snakes.

**Notes:** 510 lines - the elephant. Two parallel implementations (grid vs smooth). Massive bounce logic. Manual entity management throughout.

**Detailed breakdown:**
- Lines 258-366: Food movement (drift/flee/chase) ~108 lines - manual timer, manual collision with all snakes
- Lines 368-379: Food lifetime expiration ~12 lines - manual timer, manual removal/respawn
- Lines 381-396: Snake shrinking over time ~16 lines - manual timer
- Lines 398-420: Moving obstacles ~23 lines - manual timer, manual bounce
- Lines 422-443: Obstacle spawning over time ~22 lines - manual timer, manual spawn loop
- Lines 445-452: AI/arena updates ~8 lines - calls to other functions
- Lines 454-458: Smooth mode branch - early return to separate 409-line function
- Lines 460-466: Speed cap ~7 lines
- Lines 468-606: Wall mode handling ~138 lines - wrap is 6 lines, death is 12 lines, bounce is 100+ lines of perpendicular direction finding
- Lines 608-612: Collision check ~5 lines
- Lines 614-701: Food collision ~87 lines - girth checks, food types (bad/golden/normal), growth tracking, spawn modes
- Lines 703-765: Multi-snake loop ~62 lines - duplicates main snake logic for additional player snakes

**Extraction Potential:** Very High.
1. **Food movement** (~108 lines → 0): Food is entity type, use PatternMovement. "drift" = random walk pattern, "flee_from_snake" = flee pattern with target, "chase_snake" = chase pattern. EntityController:updateBehaviors handles it.
2. **Food lifetime** (~12 lines → 0): EntityController handles entity lifetime automatically.
3. **Shrink over time** (~16 lines → ~3): Could be entity behavior or one-liner timer check.
4. **Moving obstacles** (~23 lines → 0): EntityController updateBehaviors with bounce_movement.
5. **Obstacle spawning** (~22 lines → 0): EntityController continuous spawn mode.
6. **Smooth mode branch** (eliminates 409-line function): Unify grid/smooth - continuous vs discrete is movement mode, not separate code path.
7. **Bounce logic** (~100 lines → 0): PhysicsUtils.handleBounds already does bounce. Not extraction - deletion.
8. **Food collision** (~87 lines → ~10): EntityController collision callback. Food types handled by entity properties.
9. **Growth tracking** (deleted): Segments are entities. Eat food → queue segment spawn at tail when tail vacates. No pending_growth counter.
10. **Multi-snake loop** (~62 lines → 0): All snakes are entities. EntityController iterates them. Same movement logic, different input source.
11. **Girth** (stays ~15 lines): Snake-specific, can extract later if needed.

**After extraction:** ~20-30 lines: update arena, process input to direction queue, let EntityController/MovementController/PhysicsUtils handle the rest. Girth handling stays.

---

## checkComplete
Calls victory_checker:check(). If result exists, sets victory or game_over flags based on result. Returns true if complete.

**Notes:** 9 lines. Identical in every game. VictoryCondition component already handles this.

**Extraction Potential:** Very High. Delete from snake. BaseGame uses VictoryCondition component - auto-check in updateBase, sets flags automatically. Games only override for custom behavior.

---

## onComplete
Determines win/loss based on victory_condition (length or time) and whether threshold was reached. Plays success sound if win (death sound played inline at collision). Stops music. Calls parent onComplete.

**Notes:** 19 lines. Manual win check is redundant - victory flag already set by checkComplete. Sound/music pattern identical across games.

**Extraction Potential:** Very High. Delete from snake. BaseGame:onComplete() checks victory flag (already set), plays params.win_sound or params.lose_sound, stops music. VictoryCondition component + BaseGame handles everything.

---

## draw
Calls view:draw() if view exists.

**Notes:** 5 lines. Nil check is unnecessary - view always created in init.

**Extraction Potential:** High. Every game does self.view:draw(). Move to BaseGame. Delete from snake entirely.

---

## keypressed
Calls parent keypressed for demo playback tracking. For smooth movement mode, tracks turn key presses (smooth_turn_left, smooth_turn_right). For grid movement, maps WASD/arrows to direction, queues direction via movement_controller:queueGridDirection, applies to additional player snakes. Returns whether input was handled.

**Notes:** 45 lines. Smooth vs grid branching. Multi-snake loop duplicates direction application.

**Extraction Potential:** Medium-High. MovementController could handle input mapping based on mode - key → MovementController:handleInput(key, entity). Multi-snake loop becomes entity iteration if snakes are entities via EntityController.

---

## keyreleased
Calls parent keyreleased for demo playback tracking. For smooth movement mode, clears turn key states when released.

**Notes:** 13 lines. Only needed for smooth mode turn flags.

**Extraction Potential:** Medium-High. Same as keypressed - MovementController handles both press and release. MovementController:handleInput(key, "pressed"/"released", entity) handles turn flags internally for continuous modes.

---

## updateSmoothMovement
Handles smooth (analog) movement mode (409 lines). Applies rotation based on turn key states at turn_speed rate. Normalizes angle. Calculates movement distance and delta from angle and speed. Updates smooth_x, smooth_y. Handles wall modes: wrap (clears trail on wrap), death (checks arena bounds and shaped arenas). Adds position to trail, trims trail to target length. Checks obstacle collision with distance-based check, handles bounce mode (raycasts to find best 45° direction) or death. Checks trail self-collision (skipping neck region). Checks food collection. Updates additional player snakes with same logic. Updates snake body[1] position for camera tracking.

**Notes:** 409 lines - the second elephant. Parallel implementation of grid mode. Should not exist as separate function.

**Detailed breakdown:**
- Lines 867-884: Rotation application ~18 lines - turn flags → angle change, normalize angle
- Lines 886-894: Movement calculation ~9 lines - angle + speed → dx/dy, update position
- Lines 896-927: Wall mode handling ~32 lines - wrap (clears trail), death (bounds + shaped arenas)
- Lines 929-943: Trail management ~15 lines - add point, trim to target length
- Lines 945-1038: Obstacle collision ~94 lines - distance check, bounce raycasting (50+ lines for finding best 45° angle), death on hit
- Lines 1040-1073: Self-collision ~34 lines - check trail intersection, skip neck region based on girth
- Lines 1075-1108: Food collection ~34 lines - distance check, collect, respawn
- Lines 1111-1272: Multi-snake loop ~162 lines - duplicates ALL above logic for additional player snakes
- Lines 1274-1276: Camera sync ~3 lines - update body[1] for camera tracking

**Extraction Potential:** Very High. Delete entire function when grid/smooth unified.
1. **Rotation/movement** (~27 lines → 0): MovementController continuous mode. Asteroids mode already does rotation + thrust.
2. **Wall modes** (~32 lines → 0): PhysicsUtils.handleBounds does wrap/death/bounce.
3. **Trail management** (~15 lines → 0): PhysicsUtils.createTrailSystem already exists.
4. **Obstacle collision** (~94 lines → 0): Unified collision system + PhysicsUtils bounce. The 50-line raycast for best angle is reinventing bounce logic.
5. **Self-collision** (~34 lines → ~5): Trail system could have self-intersection check, or simple helper.
6. **Food collection** (~34 lines → 0): EntityController collision callback.
7. **Multi-snake loop** (~162 lines → 0): Snakes are entities, EntityController iterates them with same movement logic.

**After extraction:** 409 lines → 0. Movement mode is MovementController config, not code branch. This function deleted entirely.

---

## spawnFood
Spawns food at position based on food_spawn_pattern. "cluster" spawns near existing food. "line" spawns along horizontal center. "spiral" spawns in expanding/contracting spiral pattern with angle/radius state. "random" (default) picks random position. Loops until position doesn't collide. Determines food type: golden (rarest, size 3), bad, or normal. Applies size variance to normal food. Sets lifetime=0. Returns food position table.

**Notes:** 98 lines. Pattern-based spawning with type probability. Spiral maintains state across calls.

**Extraction Potential:** High. Food is entity type. EntityController handles spawn patterns (add spawnCluster, spawnLine, spawnSpiral as generic patterns), weighted type selection (spawnWeighted exists), collision avoidance. Delete function, use EntityController spawn with pattern config.

---

## createAISnake
Spawns AI snake at random position. Loops up to 200 attempts finding position that's: far from player (>10 Manhattan distance), not colliding, inside arena for shaped arenas. Falls back to center + offset if no valid position found. Returns AI snake table with body, direction, move_timer, length, alive, behavior, target_food fields.

**Notes:** 41 lines. AI snake is just snake entity with AI control. Hard-coded entity structure.

**Extraction Potential:** High. If snakes use EntityController: spawn with distance constraint. Generic constraint: `{min_distance_from = {x,y}}` or `{min_distance_from_entity = entity}` - works for any "far from point/entity" spawning. Delete function, use EntityController spawn.

---

## updateAISnakes
Loops through ai_snakes array. For each alive snake, calls updateAISnake.

**Notes:** 7 lines. Manual iteration over entities.

**Extraction Potential:** High. EntityController handles iteration automatically via updateBehaviors() or getEntitiesByType(). Delete function.

---

## updateAISnake
Handles single AI snake update. Increments move_timer. On move interval: determines direction based on behavior ("aggressive" chases player, "defensive" flees player, "food_focused" finds nearest food). Calculates new head position. Handles wall_mode (wrap/death/bounce). Checks obstacle and self collision (dies if collides). Inserts new head. Checks food collision, removes and respawns food. Removes tail if didn't eat.

**Notes:** 116 lines. Duplicates player snake movement completely - same wall handling, collision, food eating, growth.

**Extraction Potential:** Very High. AI behaviors are PatternMovement patterns: aggressive=chase(player), defensive=flee(player), food_focused=chase(nearest food). If snakes unified as entities: movement code shared, direction is player input OR AI behavior. Delete function - AI snakes just config: `{ai: true, behavior: "chase", target: "player"}`.

---

## checkSnakeCollisions
Checks collisions between player snake and AI snakes. For head-to-head collision, handles based on snake_collision_mode: "both_die" kills both, "big_eats_small" absorbs smaller snake. Also checks player head hitting AI body segments.

**Notes:** 47 lines. Snake-vs-snake collision with configurable modes.

**Extraction Potential:** High. EntityController already has collision callbacks. Collision modes become entity config: `{collision_mode: "big_eats_small"}`. Delete function - EntityController handles it.

---

## createEdgeObstacles
Creates wall obstacles at arena edges based on wall_mode and arena_shape. Builds set of snake positions to avoid. Sets wall_type based on bounce mode. For death/bounce modes: shaped arenas (circle/hexagon) fill ALL outside positions with walls; rectangle arenas create perimeter walls on all four edges. Returns empty array for wrap mode. Prints debug info.

**Notes:** 52 lines. Double loops filling boundary cells. Wall collision could be handled by ArenaController/PhysicsUtils instead.

**Extraction Potential:** Medium-High. Best practice: ArenaController provides `getBoundaryCells(shape, wall_mode)` method, view renders them directly. No wall entities needed - collision handled by ArenaController bounds checking, visuals handled by view asking for boundary cells. Delete function - ArenaController + view handle it.

---

## createObstacles
Creates variant obstacles. Calculates obstacle_count from param * difficulty complexity modifier. Gets obstacle_type from param. Loops creating obstacles at random positions that don't collide with snake or existing obstacles. For moving_blocks type, initializes random horizontal movement direction. Returns obstacles array.

**Notes:** 32 lines. Manual spawn loop with collision avoidance.

**Extraction Potential:** High. Already have it. EntityController:spawnRandom("obstacle", count, bounds, collision_check). Moving blocks get `{movement_pattern: "bounce"}`. Delete function.

---

## onArenaShrink
Callback for arena shrinking. Gets bounds from arena_controller. Adds wall obstacles at the new margins on all four sides.

**Notes:** 23 lines. Manually creates wall entities when arena shrinks.

**Extraction Potential:** Medium-High. If ArenaController + view handle boundary visualization, callback is unnecessary. ArenaController knows its bounds, view asks for boundary cells each frame. Delete callback.

---

## syncArenaState
Syncs grid_width and grid_height from arena_controller's current_width and current_height.

**Notes:** 4 lines. Copies state that arena_controller already has.

**Extraction Potential:** High. Redundant state sync. Read directly from arena_controller when needed. Delete function.

---

## isInsideArena
Wrapper that calls arena_controller:isInsideGrid(pos.x, pos.y).

**Notes:** 3 lines. Thin wrapper for readability.

**Extraction Potential:** Low. Keep as-is. Not worth changing.

---

## getGirthCells
Returns all grid cells occupied by a position with given girth. Girth expands perpendicular to movement direction. Without direction, returns single cell. Calculates perpendicular direction (horizontal movement expands vertically, vertical expands horizontally). Returns array of cell positions centered around the input position.

**Notes:** 40 lines. Snake-specific width expansion mechanic.

**Extraction Potential:** Low. Keep snake-specific for now. Extract if another game needs width expansion later.

---

## checkGirthCollision
Checks if two girth-expanded positions collide. Gets cells for both positions using getGirthCells. Compares all cell pairs for overlap. Returns true if any cells overlap.

**Notes:** 14 lines. Companion to getGirthCells.

**Extraction Potential:** Low. Snake-specific girth mechanic. Keep as-is.

---

## collectFood
Helper for food collection by any snake. Handles food types: bad (shrinks snake up to 3 segments, plays death sound), golden (bonus growth, double speed increase, plays success sound), normal (standard growth/speed increase, plays eat sound). Tracks girth growth progress if enabled.

**Notes:** 50 lines. Food type effects with sounds. Girth tracking at end.

**Extraction Potential:** Medium-High. Food as entity type, collection via EntityController collision callback. Food effects become entity config: `{on_collect: "shrink"}` or `{on_collect: "grow", amount: 3}`. Sound part of effect config. Girth tracking (~8 lines) stays snake-specific. Rest deleted - data-driven.

---

## checkCollision
Checks if position collides with obstacles or snake body. Gets all cells for position with current girth. Checks each cell against all obstacles. If check_snake_body and not phase_through_tail: skips segments near head (at least girth count), checks girth collision against remaining body segments. Returns true if collision found.

**Notes:** 43 lines. Girth-aware collision with obstacles and self.

**Extraction Potential:** Medium. Obstacle collision → EntityController collision check. Self-collision → follow_grid movement pattern (trail self-intersection). Girth logic stays but integrates with unified collision. Simplifies significantly with entities.

---

## _spawnSnakeSafe
Finds safe spawn position for snake. Calculates safe bounds (margin 2 for death/bounce walls, 1 otherwise). Loops up to 500 attempts finding position that: is inside arena for shaped arenas, doesn't collide with obstacles (distance-based for smooth, grid-based otherwise). Falls back to center if no safe position found. Updates snake position. Calculates direction toward center. Syncs movement_controller. Updates smooth position if smooth mode.

**Notes:** 97 lines. Duplicates findSafePosition, getCardinalDirection, and _repositionSnakeAt logic.

**Extraction Potential:** High. Use existing helpers: `local x, y = self:findSafePosition(bounds, is_safe_fn)` then `self:_repositionSnakeAt(x, y)`. 97 lines → ~5-10 lines.

---
