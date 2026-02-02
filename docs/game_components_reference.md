# Game Components Function Reference

Master list of all functions in `src/utils/game_components/`. Use this before creating new code.

---

## AnimationSystem
Timer-based animation helpers.

- **createFlipAnimation(config)** - Rotation-based flip (coins). Returns object with start/update/getRotation/isActive/reset.
- **createBounceAnimation(config)** - Sine-wave bounce (hand throws). Returns object with start/update/getOffset/isActive/reset.
- **createFadeAnimation(config)** - Alpha fade animation. Returns object with start/update/getAlpha/isActive/reset.
- **createProgressAnimation(config)** - Bidirectional 0-1 progress (card flips). Config: duration, direction (1/-1), initial. Returns object with start(dir)/update/getProgress/isActive/reset.
- **createTimer(duration, on_complete)** - Simple countdown timer with callback. Returns object with start/update/getRemaining/getProgress/isActive/reset.

---

## ArenaController
Manages play area bounds with polygon-based shapes, shrinking, pulsing, morphing, and movement.

### Constructor
- **new(params)** - Create arena. Params:
  - Base: width, height, x, y
  - Shape: vertices (explicit), OR sides + shape_rotation (generates regular polygon)
  - Shrinking: shrink, shrink_interval, shrink_amount, min_width, min_height
  - Safe zone: safe_zone, safe_zone_radius, min_radius, shrink_speed
  - Pulsing: pulse, pulse_speed, pulse_amplitude
  - Morphing: morph_type ("shrink"/"pulsing"/"shape_shifting"/"deformation"), morph_speed, shape_shift_interval, sides_cycle
  - Movement: vx, vy, ax, ay, friction, bounds_padding, container_width, container_height
  - Moving walls: moving_walls, wall_move_interval
  - Raw schema: area_size, initial_radius_fraction, min_radius_fraction, shrink_seconds, complexity_modifier
  - Grid: grid_mode, cell_size
  - Callback: on_shrink

### Core Methods
- **update(dt)** - Update shrinking, morphing, pulsing, movement, moving walls.
- **generateRegularPolygon(sides, rotation)** - Generate normalized vertices for regular polygon.
- **getScaledVertices()** - Get vertices scaled to current radius and translated to position.

### Bounds & Collision
- **isInside(x, y, margin)** - Point-in-polygon check with optional entity radius margin.
- **isInsideGrid(grid_x, grid_y, margin)** - Check if grid position is inside (for grid-based games).
- **getBounds()** - Get current bounds. Returns {x, y, width, height, radius, sides, grid_width, grid_height}.
- **getEffectiveRadius()** - Get radius + pulse offset.
- **clampEntity(entity)** - Clamp entity to stay inside arena with optional bounce. Entity: {x, y, vx, vy, radius, bounce_damping}.

### Shape Boundary
- **getPointOnShapeBoundary(angle, radius)** - Get point on shape boundary at angle (ray-polygon intersection).
- **getRandomBoundaryPoint(radius)** - Get random point + outward normal angle on boundary (weighted by edge length).
- **getBoundaryCells(grid_width, grid_height)** - Get array of {x, y} cells outside playable area.
- **drawBoundary(scale, color)** - Draw arena boundary polygon.

### Shrinking
- **getShrinkProgress()** - Get shrink progress 0-1 (0=full, 1=min size).
- **getShrinkMargins()** - Get {left, right, top, bottom} margins for rectangular shrinking.

### Movement & Position
- **setPosition(x, y)** - Set position directly.
- **setVelocity(vx, vy)** - Set velocity directly.
- **setAcceleration(ax, ay)** - Set acceleration (game sets each frame for behavior).
- **setContainerSize(width, height)** - Update container dimensions.
- **reset()** - Reset to initial state.
- **getState()** - Get full state for rendering.

---

## EffectSystem
Minimal timed effect tracker. Games handle what effects DO via on_expire callback.

### Constructor
- **new(config)** - Create system. Config: {on_expire} (required callback when effect expires).

### Methods
- **activate(effect_type, duration, data)** - Start/extend an effect. data passed to on_expire.
- **deactivate(effect_type)** - End effect early (triggers on_expire).
- **update(dt)** - Tick all effect timers, call on_expire when they run out.
- **isActive(effect_type)** - Returns true if effect is active.
- **getTimeRemaining(effect_type)** - Returns seconds remaining (0 if inactive).
- **getActiveEffects()** - Returns table of {effect_type = {timer, data}}.
- **clear()** - Clear all effects (triggers on_expire for each).
- **getActiveCount()** - Returns number of active effects.

---

## EntityController
Generic enemy/obstacle spawning and management with pooling.

### Constructor
- **new(config)** - Create controller. Config: entity_types, spawning {mode, rate, max_concurrent}, pooling, max_entities, grid_cell_size.

### Spawning
- **spawn(type_name, x, y, custom_params)** - Spawn single entity. Returns entity.
- **spawnAtPositions(type_name, positions, custom_params)** - Spawn at array of {x, y, ...} positions.
- **calculateSpawnPosition(config)** - Calculate spawn position without spawning. Config: bounds, center, region ("random"/"center"/"edge"), index, spacing, angle, margin, min_distance_from_center, max_attempts, is_valid_fn. Returns x, y, direction.
- **calculateSpawnDirection(mode, x, y, center, fixed_direction)** - Calculate direction. Modes: "toward_center", "from_center", or table {x, y}. Returns {x, y}.
- **resolveSpawnPosition(config)** - Resolve position using named patterns. Patterns: "random_edge", "spiral", "boundary", "clusters". Returns sx, sy, angle or nil if handled internally.
- **ensureInboundAngle(x, y, angle, bounds)** - Flip angle if pointing away from bounds.
- **calculateGridLayout(config)** - Pure calculation for fitting items in container. Config: {cols, rows, container_width, container_height, item_width, item_height, spacing, padding, reserved_top}. Returns: {cols, rows, item_width, item_height, start_x, start_y, scale, spacing}.
- **pickWeightedType(configs, time)** - Pick type from weighted configs. Each: {name, weight} or {name, weight = {base, growth}}.

### Entity Access
- **getEntityAtPoint(x, y, type_name)** - Point hit test. Returns first entity or nil.
- **getActiveCount()** / **getTotalCount()** - Get counts.
- **getEntities()** - Get all active entities.
- **getEntitiesByType(type_name)** - Get entities of specific type.
- **getEntitiesByCategory(category)** - Get entities where entity.category matches.
- **getEntitiesByFilter(filter_fn)** - Get entities where filter_fn(entity) returns true.
- **forEachByType(type_name, fn)** - Apply function to each entity of type.
- **findNearest(x, y, filter)** - Find nearest entity. Returns entity, distance.

### Grid Shuffling
- **repositionGridEntities(type_name, layout)** - Reposition entities by grid_index.
- **shuffleGridIndices(type_name)** - Fisher-Yates shuffle grid_index values.
- **animateGridShuffle(entities, count, layout, duration)** - Start animated shuffle.
- **updateGridShuffle(dt)** - Update animation. Returns true when complete.
- **isGridShuffling()** - Check if shuffle is active.
- **getShuffleProgress()** - Get animation progress 0-1.
- **getShuffleStartPosition(entity)** - Get entity's start position for interpolation.
- **completeGridShuffle()** - Finalize positions and clear state.

### Entity Lifecycle
- **hitEntity(entity, damage, by_what)** - Deal damage, trigger callbacks. Returns true if killed.
- **killEntity(entity)** - Trigger death callback, mark for removal.
- **removeEntity(entity, removal_reason)** - Remove from list, return to pool. Calls on_remove callbacks.
- **removeByTypes(types)** - Remove all entities matching type array.
- **regenerate(types, init_fn)** - Remove types and call init_fn to respawn.
- **clear()** - Remove all entities.
- **draw(render_callback)** - Draw all via callback.

### Chain Movement (Snake-style)
- **moveChain(chain, new_x, new_y)** - Move chain of entities. Each takes previous position. Returns old_tail_x, old_tail_y.

### Collision
- **checkCollision(obj, handlers)** - Check collision with obj. handlers: function(entity) or table {action_name = fn}. Returns colliding entities.
- **loadCollisionImage(type_name, image_path, alpha_threshold, di)** - Load PNG for pixel collision.
- **getRectCollisionCheck(PhysicsUtils)** - Get rect-rect collision check function.

### Update & Behaviors
- **update(dt, game_state)** - Update spawning and all entities.
- **tickTimer(entity, field, speed, dt)** - Increment timer field. Returns true when interval reached.
- **updateBurstSpawning(dt, game_state)** - Burst spawning mode.
- **updateBehaviors(dt, config, collision_check)** - Per-entity behaviors:
  - boundary_anchor: {get_boundary_point} - Anchor to boundary point
  - fall_enabled, fall_speed, fall_death_y, on_fall_death - Falling
  - move_enabled, move_speed, bounds, can_overlap - Horizontal movement
  - regen_enabled, regen_time, can_overlap - Regeneration
  - shooting_enabled, on_shoot - Entity shooting
  - pattern_movement: {PatternMovement, bounds, tracking_target, get_difficulty_scaler, speed, direction}
  - sprite_rotation - Visual spinning
  - trails: {max_length} - Trail positions
  - track_entered_play: {x, y, width, height} - Track when enters play area
  - rotation - Rotate by rotation_speed
  - bounce_movement: {width, height, max_bounces} - Wall bouncing
  - delayed_spawn: {on_spawn(entity, ds)} - Timer-based conversion
  - remove_offscreen: {top, bottom, left, right} - Remove when off-screen
  - collision: {target, check_trails, on_collision(entity, target, type)}
  - enter_zone: {check_fn or bounds, on_enter(entity)}
  - timer_spawn: {type_name = {interval, on_spawn}}
  - gradual_spawn: {slots, on_spawn, interval, max_count, timer, spawned_count}

**Spawn modes:** "continuous", "wave", "burst", "grid", "manual"

---

## FogOfWar
Visibility system with stencil or alpha modes.

- **new(params)** - Create fog. Params: enabled, mode ("stencil"/"alpha"), opacity, inner_radius_multiplier, outer_radius.
- **clearSources()** - Clear visibility sources each frame.
- **addVisibilitySource(x, y, radius)** - Add circular visible area.
- **render(arena_width, arena_height)** - Draw fog overlay with stencil cutouts.
- **calculateAlpha(entity_x, entity_y, fog_center_x, fog_center_y)** - Get alpha multiplier (alpha mode).
- **updateMousePosition(x, y)** - Store mouse position.
- **getMousePosition()** - Retrieve stored mouse position.
- **update(dt)** - Update fog state.

---

## HUDRenderer
Standardized HUD with consistent layout.

- **new(config)** - Create HUD. Config: primary, secondary, lives, timer, progress, extra_stats (each with label/key/format).
- **draw(viewport_width, viewport_height)** - Draw full HUD. Skips if vm_render_mode.
- **drawPrimary()** - Draw primary metric (top-left).
- **drawSecondary()** - Draw secondary metric (below primary).
- **drawLives()** - Draw lives/health (top-right). Styles: "hearts" or "number".
- **drawTimer()** - Draw timer (top-center). Modes: "elapsed" or "countdown".
- **drawProgress()** - Draw progress bar (bottom-center).
- **drawExtraStats()** - Draw extra stats row at bottom.
- **getValue(key)** - Get value from game state, supports nested keys.
- **formatValue(value, format)** - Format as "number", "float", "percent", "time", or "ratio".
- **getHeight()** - Returns total height consumed by HUD.

---

## LivesHealthSystem
Unified lives/health/shield management.

- **new(config)** - Create system. Config: mode ("lives"/"shield"/"binary"/"none"), starting_lives, max_lives, shield_enabled, shield_max_hits, shield_regen_time, invincibility_on_hit, respawn_enabled, callbacks.
- **update(dt)** - Update invincibility, respawn, shield regen timers.
- **takeDamage(amount, source)** - Apply damage. Returns true if damage taken.
- **die()** - Trigger death.
- **respawn()** - Respawn after death.
- **addLife(count)** - Add lives (capped). Returns true if increased.
- **checkExtraLifeAward(score)** - Check/award extra life at score threshold.
- **heal(amount)** - Restore shield hits.
- **isAlive()** - Returns true if not dead.
- **isInvincible()** - Returns true if invincible.
- **getShieldStrength()** - Returns 0-1 ratio.
- **getShieldHitsRemaining()** - Returns shield hit count.
- **isShieldActive()** - Returns true if shield active.
- **getLives()** / **setLives(count)** - Get/set lives.
- **reset()** - Reset to initial state.

---

## MovementController
Reusable movement primitives. All deterministic for demo playback.

### Constructor
- **new(params)** - Create controller. Params: speed, rotation_speed, bounce_damping, thrust_acceleration, accel_friction, decel_friction, jump_distance, jump_cooldown, jump_speed, cell_size, cells_per_second, allow_reverse.

### Velocity Primitives
- **applyThrust(entity, angle, force, dt)** - Apply thrust in direction.
- **applyDirectionalVelocity(entity, dx, dy, speed, dt)** - Apply directional velocity (dx, dy = -1/0/1).
- **applyDirectionalMove(entity, dx, dy, speed, dt)** - Apply directional move directly to position.
- **applyFriction(entity, friction, dt)** - Apply friction to velocity.
- **stopVelocity(entity)** - Zero velocity.
- **applyVelocity(entity, dt)** - Update position from velocity.

### Rotation Primitives
- **applyRotation(entity, direction, speed, dt)** - Rotate by amount.
- **rotateTowardsMovement(entity, dx, dy, dt)** - Rotate toward movement direction.
- **rotateTowardsVelocity(entity, dt, min_speed)** - Rotate toward velocity direction.

### Bounds Primitives
- **applyBounds(entity, bounds)** - Clamp or wrap entity. Bounds: {x, y, width, height, wrap_x, wrap_y}.
- **applyBounce(entity, bounds, damping)** - Bounce velocity on collision. Returns hit boolean.

### Jump/Dash System
- **canJump(entity_id, current_time)** - Check if jump available.
- **startJump(entity, entity_id, dx, dy, current_time, bounds)** - Start jump in direction.
- **updateJump(entity, entity_id, dt, bounds, current_time)** - Update jump. Returns is_still_jumping.
- **isJumping(entity_id)** - Check if currently jumping.
- **getJumpDirection(entity_id)** - Get jump direction.

### Grid Movement System
- **tickGrid(dt, entity_id)** - Returns true when time to move to next cell.
- **queueGridDirection(entity_id, dir_x, dir_y, current_dir)** - Queue direction change. Returns false if reverse blocked.
- **applyQueuedDirection(entity_id)** - Apply queued direction. Returns {x, y}.
- **getGridDirection(entity_id)** - Get current direction.
- **initGridState(entity_id, dir_x, dir_y)** - Initialize grid state.
- **resetGridState(entity_id)** - Clear grid state.
- **setSpeed(speed)** - Change cells_per_second.
- **findGridBounceDirection(head, current_dir, is_blocked_fn)** - Find perpendicular bounce direction.

### Smooth Movement System
- **initSmoothState(entity_id, angle)** - Initialize with starting angle.
- **setSmoothTurn(entity_id, left, right)** - Set turn flags.
- **getSmoothState(entity_id)** - Get smooth state.
- **getSmoothAngle(entity_id)** / **setSmoothAngle(entity_id, angle)** - Angle accessors.
- **updateSmooth(dt, entity_id, entity, bounds, speed, turn_speed_deg)** - Update angle and position. Returns dx, dy, wrapped, out_of_bounds.
- **initState(entity_id, direction)** - Initialize both grid and smooth state.

### Helpers
- **angleDiff(target, current)** - Shortest angular difference.

---

## PatternMovement
Math primitives for autonomous entity movement.

### Velocity Primitives
- **applyVelocity(entity, dt)** - Apply velocity to position.
- **setVelocityFromAngle(entity, angle, speed)** - Set velocity from angle.
- **setVelocityToward(entity, target_x, target_y, speed)** - Set velocity toward target.
- **applyDirection(entity, dt)** - Apply directional movement using dir_x/dir_y or angle.

### Steering Primitives
- **steerToward(entity, target_x, target_y, turn_rate, dt)** - Smooth turning toward target. Returns new angle.
- **moveToward(entity, target_x, target_y, speed, dt, threshold)** - Move toward target. Returns true if arrived.

### Oscillation Primitives
- **applySineOffset(entity, axis, dt, frequency, amplitude)** - Apply sine wave delta to position.
- **setSinePosition(entity, axis, frequency, amplitude)** - Set absolute sine position from start_x/start_y.
- **updateTime(entity, dt)** - Update entity.pattern_time.

### Orbit / Circular
- **setPositionOnCircle(entity, center_x, center_y, radius, angle)** - Set position on circle.
- **updateOrbit(entity, center_x, center_y, radius, angular_speed, dt)** - Update orbit angle and position.

### Bezier
- **bezierQuadratic(t, p0, p1, p2)** - Quadratic bezier at t (0-1). Returns x, y.
- **updateBezier(entity, dt)** - Update position along bezier. Returns true when complete.
- **buildBezierPath(start_x, start_y, control_x, control_y, end_x, end_y)** - Build 3-point path.

### Bounce
- **applyBounce(entity, bounds, damping)** - Bounce off bounds. Returns bounced boolean.
- **clampToBounds(entity, bounds)** - Clamp position to bounds.

### Utilities
- **isOffScreen(entity, bounds, margin)** - Check if entity is outside bounds.
- **distance(x1, y1, x2, y2)** - Distance between points.
- **angleTo(x1, y1, x2, y2)** - Angle from point 1 to point 2.
- **normalizeAngle(angle)** - Normalize to -pi to pi.

### Generic Update
- **update(dt, entity, bounds)** - Dispatch based on entity flags:
  - use_steering + target_x/target_y: Steer toward target
  - use_direction: Apply direction
  - use_velocity or use_steering: Apply velocity
  - sine_amplitude: Apply sine oscillation
  - orbit_radius: Orbit around center
  - use_bezier + bezier_path: Follow bezier
  - use_bounce: Bounce off bounds
- **updateSpriteRotation(entity, dt)** - Visual sprite spinning via sprite_rotation_speed.

---

## PhysicsUtils
Physics helpers: forces, movement, collision detection/response.

### Forces
- **applyGravity(entity, gravity, direction_degrees, dt)** - Apply gravity force.
- **applyHomingForce(entity, target_x, target_y, strength, dt)** - Steer toward target.
- **applyMagnetForce(entity, target_x, target_y, range, strength, dt)** - Pull toward target within range.
- **applyGravityWell(entity, well, dt, strength_multiplier)** - Gravity well pull (modifies vx/vy or position).
- **applyForces(entity, params, dt, findTarget, magnetTarget)** - Apply multiple forces. Requires gravity_direction when gravity set, magnet_strength when magnet_range set, gravity_well_strength_multiplier when gravity_wells set.
- **handleKillPlane(entity, edge_info, boundary, config)** - Kill plane with optional shield. edge_info: {pos_field, vel_field, inside_dir, check_fn}. config: {kill_enabled, restitution, bounce_randomness, rng, shield_active, on_shield_use}. Returns true if killed.

### Movement
- **move(entity, dt)** - Update position from velocity.
- **clampSpeed(entity, max_speed)** - Limit velocity magnitude.
- **increaseSpeed(entity, amount, max_speed)** - Increase speed preserving direction.
- **addBounceRandomness(entity, randomness, rng)** - Add random angle variance.
- **applyBounceEffects(entity, params, rng)** - Apply speed_increase, max_speed, bounce_randomness.
- **handleAttachment(entity, parent, offset_x_key, offset_y_key)** - Update attached entity position. Returns true if attached.
- **attachToEntity(entity, parent, y_offset)** - Attach entity to parent. Requires y_offset.

### Collision Detection
- **circleCollision(x1, y1, r1, x2, y2, r2)** - Circle vs circle.
- **rectCollision(x1, y1, w1, h1, x2, y2, w2, h2)** - AABB vs AABB.
- **circleVsRect(cx, cy, cr, rx, ry, rw, rh)** - Circle vs AABB.
- **circleVsCenteredRect(cx, cy, cr, rect_cx, rect_cy, half_w, half_h)** - Circle vs centered rect.
- **circleLineCollision(cx, cy, cr, x1, y1, x2, y2)** - Circle vs line segment.
- **checkCollision(e1, e2, shape1, shape2)** - Shape-aware collision. Requires shape1, shape2.
- **checkCollisions(entity, targets, config)** - Batch check. Requires filter, check_func.

### Collision Response
- **resolveCollision(moving, solid, config)** - Bounce off rects/circles. Requires shape, restitution. Optional: centered, bounce_direction, use_angle_mode, base_angle, angle_range, spin_influence, surface_width, separation, on_collide. Returns {edge, nx, ny}.
- **handleBounds(entity, bounds, entity_half_size, on_edge)** - Generic bounds handling. Requires bounds.width, bounds.height, entity_half_size. on_edge(entity, info) called per edge. Returns {hit, edges}.
- **bounceEdge(entity, info, restitution)** - Edge handler: bounce.
- **wrapEdge(entity, info)** - Edge handler: wrap.
- **clampEdge(entity, info)** - Edge handler: clamp and stop.

### Centered Rect Collision (Paddle)
- **handleCenteredRectCollision(entity, rect, config)** - Sticky/bounce paddle. Requires restitution, separation (or sticky + sticky_dir). Returns true if hit.
- **releaseStuckEntities(entities, anchor, config)** - Launch stuck entities. Requires base_angle, release_dir_y, launch_speed, angle_range.

### Launching
- **launchAtAngle(entity, angle_radians, speed)** - Set velocity from angle.
- **launchFromOffset(entity, offset_x, anchor_width, speed, base_angle, angle_range)** - Launch based on offset. Requires base_angle, angle_range.

### Utilities
- **updateTrail(entity, max_length)** - Add position to trail array.
- **wrapPosition(x, y, ew, eh, bw, bh)** - Screen wrap position.
- **createTrailSystem(config)** - Create trail object. Requires max_length, track_distance, color, line_width, angle_offset.
  - Methods: addPoint, updateFromEntity, trimToDistance, clear, draw, getPointCount, getDistance, getPoints
  - **checkSelfCollision(head_x, head_y, girth, config)** - Check trail self-collision. Requires skip_multiplier, collision_base, collision_multiplier.
- **updateDirectionalForce(state, dt)** - Update directional force. Requires state.angle, state.strength, state.timer. For rotating: change_interval, change_amount. For turbulent: turbulence_range. Returns fx, fy.

### Tile Map Collision
For grid-based games (maze, dungeon crawlers, raycasters).

- **isTileWalkable(map, tile_x, tile_y, map_w, map_h)** - Check if tile is walkable. Returns true if tile is 0 or nil (floor).
- **moveWithTileCollision(x, y, dx, dy, map, map_w, map_h, wrap_x, wrap_y)** - Move with wall sliding. Tests X/Y separately. Optional wrap_x/wrap_y for Pac-Man style edge wrapping. Returns new_x, new_y.
- **worldToTile(world_x, world_y)** - Convert world coords to tile coords (floors to integers).
- **tileToWorld(tile_x, tile_y)** - Convert tile coords to world center (adds 0.5 offset).

---

## ProjectileSystem
Minimal projectile/bullet system with pooling.

### Constructor
- **new(config)** - Create system. Requires: max_projectiles, out_of_bounds_margin. Optional: pooling.

### Methods
- **spawn(config)** - Spawn projectile. Requires: x, y, vx, vy, lifetime. Optional: radius, team, damage, type, color, trail, custom fields.
- **remove(projectile)** - Remove projectile, return to pool.
- **update(dt, bounds)** - Update all projectiles (movement, lifetime, bounds removal).
- **getAll()** - Get all active projectiles.
- **getByTeam(team)** - Get projectiles filtered by team.
- **clear()** - Remove all projectiles.
- **getCount()** - Get active projectile count.

---

## SchemaLoader
Auto-populates game parameters from JSON schema. Priority: variant -> runtime_config -> default.

- **SchemaLoader.load(variant, schema_name, runtime_config)** - Load all params from schema file. Returns params table.
- **SchemaLoader.loadFromTable(variant, schema, runtime_config)** - Load from Lua table.
- **SchemaLoader.getSchemaInfo(schema_name)** - Get schema metadata.
- **SchemaLoader.validateVariant(variant, schema_name)** - Validate variant against schema.
- **SchemaLoader.resolveChain(type_name, generic_key, typed_key, sources)** - Cascade through sources for per-type resolution.

---

## ScoringSystem
Formula-based token calculation.

- **new(config)** - Create scorer. Config: formula_string (legacy) OR declarative: base_value, metrics (weight/curve/scale), multipliers.
- **calculate(metrics, multipliers)** - Calculate token value.
- **getBreakdown(metrics, multipliers)** - Get detailed breakdown.
- **getFormulaString()** - Get formula for UI.
- **CURVE_FUNCTIONS** - Available curves: linear, sqrt, log, exponential, binary, power.

---

## VictoryCondition
Unified victory/loss checking.

- **new(config)** - Create checker. Config: victory {type, metric, target}, loss {type, metric}, check_loss_first, bonuses.
- **check()** - Returns "victory", "loss", or nil. Auto-applies bonuses.
- **checkVictory()** / **checkLoss()** - Check individual conditions.
- **getProgress()** - Returns 0-1 progress toward victory.
- **getValue(key)** - Get value from game state (nested keys supported).
- **applyBonuses()** - Apply victory bonuses.

**Victory types:** threshold, time_survival, time_limit, streak, ratio, clear_all, endless, rounds, multi
**Loss types:** lives_depleted, time_expired, move_limit, death_event, threshold, penalty, none

---

## VisualEffects
Camera shake, screen flash, and particles. Uses config object API.

### Constructor
- **new(config)** - Create effects. Requires: camera_shake_enabled, screen_flash_enabled, particle_effects_enabled.

### Methods
- **update(dt)** - Update all effects.
- **shake(config)** - Trigger camera shake. Requires: intensity, mode ("exponential"/"timer"). For "exponential": decay. For "timer": duration.
- **getShakeOffset()** - Get current {x, y} shake offset.
- **applyCameraShake()** - Apply shake translation.
- **flash(config)** - Trigger screen flash. Requires: color, duration, mode ("fade_out"/"pulse"/"instant").
- **drawScreenFlash(width, height)** - Draw flash overlay.
- **drawParticles()** - Draw all particles.

### Particles (accessed via self.visual_effects.particles)
- **emitBallTrail(x, y, vx, vy)** - Ball trail particles.
- **emitConfetti(x, y, count)** - Confetti particles.
- **emitBrickDestruction(x, y, color)** - Brick destruction particles.

---

## BaseGame
Base class for all minigames.

### Initialization
- **init(game_data, cheats, di, variant_override)** - Initialize game.
- **setupArenaDimensions()** - Calculate dimensions from params. Requires: params.arena_base_width, params.arena_base_height. Sets: is_fixed_arena, game_width, game_height, camera_zoom, lock_aspect_ratio.

### Update Loop
- **updateBase(dt)** - Variable timestep update.
- **updateWithFixedTimestep(dt)** - Accumulator-based fixed timestep wrapper.
- **fixedUpdate(dt)** - Deterministic update at fixed_dt (1/60).
- **updateGameLogic(dt)** - Override in subclasses.
- **setPlayArea(width, height)** - Set arena dimensions. Override for entity repositioning.

### Completion
- **checkComplete()** - Check victory/loss conditions. Uses victory_checker if available.
- **onComplete()** - Called when game completes.
- **getCompletionRatio()** - Returns 0-1 progress using VictoryCondition:getProgress().
- **getMetrics()** / **calculatePerformance()** / **getResults()** - Metrics and token calculation.

### Schema-Based Component Creation
- **createComponentsFromSchema()** - Create from params.components definitions.
- **createProjectileSystemFromSchema(config)** - Create ProjectileSystem. Requires: max_projectiles, out_of_bounds_margin.
- **createEntityControllerFromSchema(callbacks, extra_config)** - Create EntityController from params.entity_types.
- **createEffectSystem(on_expire)** - Create EffectSystem. Requires: on_expire callback.
- **createVictoryConditionFromSchema(bonuses)** - Create from params.victory_conditions. Requires: params.victory_condition.
- **resolveConfig(config)** - Resolve "$param_name" references.

### Cheat Application
- **applyCheats(mappings)** - Apply cheats to params. Mappings: {speed_modifier = [...], advantage_modifier = [...], performance_modifier = [...]}.

### Entity Helpers
- **createPlayer(config)** - Create player. Config: entity_name, x, y. Requires: width+height OR radius (or params.player_width/player_height).
- **createPaddle(config)** - Alias for createPlayer with entity_name = "paddle".
- **syncMetrics(mapping)** - Sync game fields to metrics.
- **handleEntityDepleted(count_func, config)** - Handle depletion. Requires: config.damage, config.damage_reason. Returns true if game over.
- **handleEntityDestroyed(entity, config)** - Handle destruction with effects, scoring, popups.

### Flash System
- **flashEntity(entity, duration)** - Start flash. Requires: duration.
- **updateFlashMap(dt)** - Update flash timers.
- **isFlashing(entity)** - Check if flashing.

### Param Manipulation (for powerups)
- **multiplyParam(param_name, multiplier)** - Multiply param, return original.
- **restoreParam(param_name, original_value)** - Restore param.
- **enableParam(param_name)** - Set to true, return original.
- **setParam(param_name, value)** - Set value, return original.

### Position & Direction
- **CARDINAL_DIRECTIONS** - Constant: {right, left, up, down} = {x, y}.
- **getCardinalDirection(from_x, from_y, to_x, to_y)** - Returns dir_x, dir_y (-1/0/1).
- **wrapPosition(x, y, width, height)** - Wrap within bounds.
- **clampEntitiesToBounds(entity_arrays, min_x, max_x, min_y, max_y)** - Clamp all entities.
- **getRandomCardinalDirection()** - Returns random dir_x, dir_y.

### Scaling & Difficulty
- **getScaledValue(base, config)** - Scale with multipliers, variance, range, bounds.
- **updateDifficulty(dt)** - Update difficulty_scale. Requires: params.difficulty_scaling_rate, difficulty_curve, difficulty_max.
- **updateScrolling(dt)** - Update scroll_offset from params.scroll_speed.

### Wave Management
- **updateWaveState(state, config, dt)** - Generic wave state. Requires: config.pause_duration. Returns: "active"/"paused"/"started".

### Shooting Helpers
- **getPlayerShootParams()** - Get spawn_x, spawn_y, angle based on movement mode.
- **getEntityShootParams(entity)** - Get entity shoot position and angle.

### Spawning
- **spawnEntity(type_name, config)** - Spawn with optional weighted configs and entrance animation.

### Damage
- **takeDamage(amount, sound)** - Take damage with sound.

### Input & Demo Playback
- **setPlaybackMode(enabled)** / **isInPlaybackMode()** - Playback mode control.
- **isKeyDown(...)** - Check key state (virtual during playback).
- **buildInput()** - Returns {left, right, up, down, space} input table.
- **setVMRenderMode(enabled)** / **isVMRenderMode()** - VM render mode.

### Audio & Assets
- **loadAssets()** - Load sprites and audio. Supports scan_directory mode.
- **loadAudio()** - Load music and SFX from variant.
- **playMusic()** / **stopMusic()** - Music control.
- **playSound(action, volume)** - Play SFX.
- **speak(text)** - TTS speak with weirdness.

---

## RotloveDungeon
Procedural dungeon/maze generation using rotLove library.

### Constructor
- **new(config)** - Create generator. Config:
  - Base: width, height, generator_type ("uniform"/"digger"/"rogue"/"cellular"/"divided_maze"/"icey_maze"/"eller_maze"/"arena")
  - Rooms: room_width {min, max}, room_height {min, max}, room_dug_percentage, time_limit
  - Rogue: cell_width, cell_height (grid of rooms)
  - Cellular: cellular_iterations, cellular_prob, cellular_connected, cellular_born, cellular_survive
  - seed (optional, for reproducible maps)

### Methods
- **generate(rng)** - Generate map. Returns {map, width, height, start, goal, rooms, floor_tiles}.
- **getFloorTiles()** - Get array of {x, y} floor positions.
- **isWalkable(x, y)** - Check if world position is walkable.

---

## StaticMapLoader
Load predefined maps from JSON files.

### Constructor
- **new(config)** - Create loader. Config: map_name (file in assets/data/maps/ without .json).

### Methods
- **generate(rng)** - Load map. Returns {map, width, height, start, goal, dots, power_pills}.

### Map File Format
```json
{
  "rows": ["#####", "#...#", "#.O.#", "#...#", "#####"],
  "start": {"x": 2.5, "y": 2.5, "angle": 0},
  "goal": {"x": 4, "y": 4}
}
```
Characters: `#`/`W`=wall, `.`/`o`=dot, `O`=power pill, space=floor.

---

## RaycastRenderer
DDA raycasting for 3D wall rendering (Wolfenstein-style).

### Constructor
- **new(config)** - Create renderer. Config: fov, ray_count, render_distance, wall_height, ceiling_color, floor_color, wall_color_ns, wall_color_ew, goal_color.

### Methods
- **draw(w, h, player, map, map_w, map_h, goal)** - Draw ceiling, floor, and walls.
- **drawCeilingAndFloor(w, h)** - Draw sky/ground split.
- **drawWalls(w, h, player, map, map_w, map_h, goal)** - Cast rays and draw wall slices.
- **castRay(start_x, start_y, angle, max_dist, map, map_w, map_h)** - DDA algorithm. Returns dist, side, hit_x, hit_y.

---

## MinimapRenderer
Tile-based minimap with player/goal markers.

### Constructor
- **new(config)** - Create minimap. Config: size, padding, position ("top_right"/"top_left"/"bottom_right"/"bottom_left"), wall_color, floor_color, player_color, goal_color, direction_color, background_color.

### Methods
- **draw(viewport_w, viewport_h, map, map_w, map_h, player, goal)** - Draw minimap at configured position.
- **setPosition(position)** - Change corner position.
- **setSize(size)** - Change minimap size.

---

## BillboardRenderer
Sprites in 3D space for raycaster games (enemies, items, pickups).

### Constructor
- **new(config)** - Create renderer. Config: fov, render_distance.

### Methods
- **setDepthBuffer(depth_buffer)** - Set depth buffer from RaycastRenderer for occlusion.
- **draw(w, h, player, billboards)** - Draw all billboards with depth sorting and occlusion.

### Factory Methods
- **BillboardRenderer.createDiamond(x, y, config)** - Create diamond shape. Config: height, aspect, y_offset, color.
- **BillboardRenderer.createSprite(x, y, config)** - Create sprite billboard. Config: height, aspect, y_offset, sprite, quad, color.
- **BillboardRenderer.createEnemy(x, y, config)** - Create enemy billboard. Config: height, aspect, y_offset, color, enemy_type, health, state.

### Billboard Properties
- **x, y** - World position
- **height** - Sprite height in world units
- **aspect** - Width/height ratio
- **y_offset** - Vertical offset (for floating animation)
- **color** - RGB color {r, g, b}
- **draw_column(col, screen_y, height, col_ratio, shade)** - Custom column draw function

---

## Common Patterns

### Config Object API
Components now use config objects with required parameters:
```lua
-- Good: explicit config object
self.visual_effects:shake({intensity = 0.5, duration = 0.2, mode = "timer"})

-- Bad: positional parameters (old API)
self.visual_effects:shake(0.2, 0.5, "timer")
```

### Required Parameters with error()
Functions now error on missing required params instead of falling back:
```lua
-- Component enforces required params
if not config.on_expire then error("EffectSystem: on_expire callback required") end
```

### Direct Param Access in Views
Views access params directly:
```lua
-- Good: Use params directly
g.print("Target: " .. game.params.victory_limit)
```

---
