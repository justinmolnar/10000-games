# Game Components Function Reference

Master list of all functions in `src/utils/game_components/`. Use this before creating new code.

---

## AnimationSystem
Timer-based animation helpers.

- **createFlipAnimation(config)** - Rotation-based flip (coins, cards). Returns object with start/update/getRotation/isActive/reset.
- **createBounceAnimation(config)** - Sine-wave bounce (hand throws). Returns object with start/update/getOffset/isActive/reset.
- **createFadeAnimation(config)** - Alpha fade animation. Returns object with start/update/getAlpha/isActive/reset.
- **createTimer(duration, on_complete)** - Simple countdown timer with callback.

---

## FogOfWar
Visibility system with stencil or alpha modes.

- **new(params)** - Create fog. Params: enabled, mode ("stencil"/"alpha"), opacity, inner_radius_multiplier, outer_radius.
- **clearSources()** - Clear visibility sources each frame.
- **addVisibilitySource(x, y, radius)** - Add circular visible area.
- **render(arena_width, arena_height)** - Draw fog overlay with stencil cutouts.
- **calculateAlpha(entity_x, entity_y, fog_center_x, fog_center_y)** - Get alpha multiplier based on distance (for alpha mode).

---

## VariantLoader
Three-tier parameter loading (variant → runtime_config → default).

- **init(variant, runtime_config, defaults)** - Setup the loader with three config sources.
- **get(key, fallback)** - Get value with priority lookup. Supports nested keys like "player.speed".
- **getNumber(key, fallback)** - Get value ensuring it's a number.
- **getBoolean(key, fallback)** - Get boolean (handles nil vs false correctly).
- **getString(key, fallback)** - Get value ensuring it's a string.
- **getTable(key, fallback)** - Get value ensuring it's a table.
- **getMultiple(keys_and_defaults)** - Batch get multiple values at once.
- **has(key)** - Check if key exists in any tier.
- **getSource(key)** - Debug helper: returns which tier a value came from.

---

## VisualEffects
Camera shake, screen flash, and particles in one component.

- **new(params)** - Create effects system. Params: camera_shake_enabled, screen_flash_enabled, particle_effects_enabled, shake_mode, shake_decay.
- **shake(duration, intensity, mode)** - Trigger camera shake. Modes: "exponential" (smooth decay) or "timer" (linear fade).
- **getShakeOffset()** - Get current {x, y} shake offset.
- **applyCameraShake()** - Apply shake translation (call before drawing game).
- **flash(color, duration, mode)** - Trigger screen flash. Modes: "fade_out", "pulse", "instant".
- **drawScreenFlash(width, height)** - Draw flash overlay (call after game content).
- **emitBallTrail(x, y, vx, vy)** - Emit ball trail particles.
- **emitConfetti(x, y, count)** - Emit confetti particles.
- **emitBrickDestruction(x, y, color)** - Emit brick destruction particles.
- **drawParticles()** - Draw all particles.
- **update(dt)** - Update all effects (shake decay, flash timer, particles).

---

## HUDRenderer
Standardized HUD with consistent layout across games.

- **new(config)** - Create HUD. Config: primary, secondary, lives, timer, progress (each with label/key/format).
- **draw(viewport_width, viewport_height)** - Draw full HUD. Skips if vm_render_mode.
- **drawPrimary()** - Draw primary metric (top-left, prominent).
- **drawSecondary()** - Draw secondary metric (below primary).
- **drawLives()** - Draw lives/health (top-right). Styles: "hearts" or "number".
- **drawTimer()** - Draw timer (top-center). Modes: "elapsed" or "countdown".
- **drawProgress()** - Draw progress bar (bottom-center).
- **getValue(key)** - Get value from game state, supports nested keys like "metrics.score".
- **formatValue(value, format)** - Format value as "number", "float", "percent", "time", or "ratio".

---

## LivesHealthSystem
Unified lives/health/shield management. Modes: LIVES, SHIELD, BINARY, NONE.

- **new(config)** - Create system. Config: mode, starting_lives, max_lives, shield_enabled, shield_max_hits, shield_regen_time, invincibility_on_hit, respawn_enabled, callbacks.
- **update(dt)** - Update invincibility timer, respawn timer, and shield regeneration.
- **takeDamage(amount, source)** - Apply damage. Returns true if damage was taken. Handles shield absorption, lives loss, invincibility.
- **die()** - Trigger death. Calls on_death callback, starts respawn timer if enabled.
- **respawn()** - Respawn after death. Grants brief invincibility.
- **addLife(count)** - Add lives (capped at max_lives). Returns true if lives increased.
- **checkExtraLifeAward(score)** - Check if score crossed extra life threshold, auto-awards life.
- **heal(amount)** - Restore shield hits (shield mode only).
- **isAlive()** - Returns true if not dead.
- **isInvincible()** - Returns true if currently invincible.
- **getShieldStrength()** - Returns shield hits remaining as 0-1 ratio.
- **getShieldHitsRemaining()** - Returns current shield hit count.
- **isShieldActive()** - Returns true if shield is active.
- **getLives()** / **setLives(count)** - Get/set current lives.
- **reset()** - Reset to initial state (lives, shield, timers).

---

## ScoringSystem
Formula-based token calculation with curves and multipliers.

- **new(config)** - Create scorer. Config: formula_string (legacy) OR declarative metrics with base_value, metrics (weight/curve/scale), multipliers.
- **calculate(metrics, multipliers)** - Calculate token value from metrics table. Applies curves and multipliers.
- **getBreakdown(metrics, multipliers)** - Get detailed breakdown of calculation (base, each metric's contribution, multipliers, total).
- **getFormulaString()** - Get formula string for UI display.
- **CURVE_FUNCTIONS** - Available curves: linear, sqrt, log, exponential, binary, power.

---

## MovementController
Reusable movement for multiple modes. All deterministic for demo playback.

- **new(params)** - Create controller. Params: mode, speed, friction, rotation_speed, jump_distance, cell_size, cells_per_second, etc.
- **update(dt, entity, input, bounds)** - Main update. Entity needs {x, y, vx, vy, angle, width/height/radius}. Input is {left, right, up, down, jump}. Bounds is {x, y, width, height, wrap_x, wrap_y}.

**Movement Modes:**
- **updateDirect()** - WASD with optional friction/momentum. Diagonal normalized.
- **updateAsteroids()** - Rotation + thrust physics. Reverse modes: "thrust", "brake", "none".
- **updateRail()** - Constrained to one axis (horizontal or vertical paddle).
- **updateJump()** - Discrete teleport-style jumps with cooldown.
- **updateGrid()** - Cell-based movement (Snake-style). Direction queuing, no reverse by default.

**Grid helpers (for Snake-style games):**
- **tickGrid(dt, entity_id)** - Returns true when it's time to move to next cell.
- **queueGridDirection(entity_id, dir_x, dir_y, current_dir)** - Queue direction change.
- **applyQueuedDirection(entity_id)** - Apply queued direction, returns {x, y}.
- **getGridDirection(entity_id)** - Get current direction without modifying state.
- **initGridState(entity_id, dir_x, dir_y)** - Initialize grid state with starting direction.
- **setSpeed(speed)** - Dynamically change cells_per_second.
- **getGridState(entity)** / **setGridDirection()** / **resetGridState()** - Grid state management.

**Helpers:**
- **applyBounds(entity, bounds)** - Clamp or wrap entity to bounds.
- **applyBounce(entity, bounds)** - Bounce velocity on boundary collision.
- **angleDiff(target, current)** - Shortest angular difference.

---

## ArenaController
Manages play area bounds, shapes, shrinking, pulsing, movement, holes.

- **new(params)** - Create arena. Params: width, height, shape ("rectangle"/"circle"/"hexagon"), shrink, safe_zone, pulse, movement, holes, grid_mode, etc.
- **update(dt)** - Update shrinking, morphing, pulsing, movement, holes.
- **getBounds()** - Get current bounds for collision/rendering. Returns {x, y, width, height, radius, shape}.
- **isInside(x, y)** - Check if position is inside arena (handles all shapes + holes).
- **isInsideGrid(grid_x, grid_y)** - Check if grid position is inside (for Snake-style games).
- **getEffectiveRadius()** - Get radius including pulse offset.
- **getShrinkProgress()** - Get shrink progress 0-1 (0=full, 1=min size).
- **getShrinkMargins()** - Get {left, right, top, bottom} margin pixels for rectangular shrinking.
- **getPointOnShapeBoundary(angle, radius)** - Get {x, y} on shape boundary at angle (works for circle/square/hex).
- **setPosition(x, y)** / **setVelocity(vx, vy)** - Direct position/velocity control.
- **addHole(hole)** / **clearHoles()** - Manage arena holes.
- **reset()** - Reset to initial state.
- **setContainerSize(w, h)** - Update container dimensions.
- **getState()** - Get full state for rendering.

**Morph types:** "none", "shrink", "pulsing", "shape_shifting", "deformation"
**Movement types:** "none", "drift", "cardinal", "follow", "orbit"

---

## VictoryCondition
Unified victory/loss checking for all games.

- **new(config)** - Create checker. Config: victory {type, metric, target}, loss {type, metric}, check_loss_first, bonuses.
- **check()** - Returns "victory", "loss", or nil. Auto-applies bonuses on victory.
- **checkVictory()** / **checkLoss()** - Check individual conditions.
- **getValue(key)** - Get value from game state (supports nested keys like "metrics.kills").
- **applyBonuses()** - Apply configured victory bonuses.

**Victory types:** threshold, time_survival, time_limit, streak, ratio, clear_all, endless, rounds, multi
**Loss types:** lives_depleted, time_expired, move_limit, death_event, threshold, penalty, none

---

## SchemaLoader
Auto-populates game parameters from JSON schema. Priority: variant → runtime_config → default.

- **SchemaLoader.load(variant, schema_name, runtime_config)** - Load all params from schema file. Returns params table.
- **SchemaLoader.loadFromTable(variant, schema, runtime_config)** - Load from Lua table (for testing/inline).
- **SchemaLoader.getSchemaInfo(schema_name)** - Get schema metadata (name, description, parameter list).
- **SchemaLoader.validateVariant(variant, schema_name)** - Validate variant against schema, returns warnings list.

Internal: _loadSchema, _populateParams, _resolveValue, _coerceType, _validateConstraints, _getNestedValue

---

## PatternMovement
Autonomous movement patterns for enemies, powerups, hazards.

- **update(dt, entity, bounds)** - Main update. Dispatches to pattern-specific updater based on entity.movement_pattern.
- **updateStraight(dt, entity, bounds)** - Move in constant direction. Entity needs: speed, direction (radians) or dir_x/dir_y.
- **updateZigzag(dt, entity, bounds)** - Primary direction + perpendicular oscillation. Entity needs: speed, zigzag_frequency, zigzag_amplitude.
- **updateWave(dt, entity, bounds)** - Sine wave path. Entity needs: speed, wave_frequency, wave_amplitude, start_x.
- **updateDive(dt, entity, bounds)** - Move toward target point. Entity needs: speed, target_x, target_y. Sets entity.dive_complete when arrived.
- **updateBezier(dt, entity, bounds)** - Follow quadratic bezier curve. Entity needs: bezier_path [{x,y},{x,y},{x,y}], bezier_duration. Sets entity.bezier_complete.
- **updateOrbit(dt, entity, bounds)** - Circle around center. Entity needs: orbit_center_x/y, orbit_radius, orbit_speed.
- **updateBounce(dt, entity, bounds)** - Move with velocity, bounce off bounds. Entity needs: vx, vy.
- **isOffScreen(entity, bounds, margin)** - Check if entity is outside bounds.
- **initPattern(entity, pattern, config)** - Initialize pattern-specific fields with defaults.
- **buildPath(pattern, params)** - Build bezier path for common patterns. Returns array of {x,y} control points. Params: start_x, start_y, end_x, end_y, curve_y, target_x, target_y, exit_x, exit_y, mid_x, mid_y.

**Patterns:** "straight", "zigzag", "wave", "dive", "bezier", "orbit", "bounce"
**Path patterns (buildPath):** "swoop", "dive", "loop", "arc"

---

## PhysicsUtils
Physics helpers: forces, movement, collision detection/response.

**Forces:**
- **applyGravity(entity, gravity, direction_degrees, dt)** - Apply gravity force to velocity.
- **applyHomingForce(entity, target_x, target_y, strength, dt)** - Steer toward target.
- **applyMagnetForce(entity, target_x, target_y, range, strength, dt)** - Pull toward target within range.
- **applyGravityWell(entity, well, dt, strength_multiplier)** - Gravity well pull (modifies vx/vy or position).
- **applyForces(entity, params, dt, findTarget, magnetTarget)** - Apply multiple forces from config.

**Movement:**
- **move(entity, dt)** - Update position from velocity.
- **clampSpeed(entity, max_speed)** - Limit velocity magnitude.
- **increaseSpeed(entity, amount, max_speed)** - Increase speed while preserving direction.
- **addBounceRandomness(entity, randomness, rng)** - Add random angle variance to velocity.
- **applyBounceEffects(entity, params, rng)** - Apply speed increase and randomness.
- **handleAttachment(entity, parent, offset_x_key, offset_y_key)** - Update attached entity position.
- **attachToEntity(entity, parent, y_offset)** - Attach entity to parent, store offsets.

**Collision Detection:**
- **circleCollision(x1, y1, r1, x2, y2, r2)** - Circle vs circle.
- **rectCollision(x1, y1, w1, h1, x2, y2, w2, h2)** - AABB vs AABB.
- **circleVsRect(cx, cy, cr, rx, ry, rw, rh)** - Circle vs AABB.
- **circleVsCenteredRect(cx, cy, cr, rect_cx, rect_cy, half_w, half_h)** - Circle vs centered rect.
- **checkCollision(e1, e2, shape1, shape2)** - Shape-aware collision between entities.
- **checkCollisions(entity, targets, config)** - Batch collision check with callbacks.

**Collision Response:**
- **resolveCollision(moving, solid, config)** - Bounce off rects/circles/paddles. Returns {edge, nx, ny}.
- **handleBounds(entity, bounds, config)** - Per-edge bounce/wrap/clamp. Returns {hit, edges}.
- **handleKillPlane(entity, edge, boundary, config)** - Kill plane with optional shield.

**Paddle:**
- **handlePaddleCollision(entity, paddle, config)** - Sticky/bounce paddle collision.
- **releaseStuckEntities(entities, anchor, config)** - Launch all stuck entities.

**Launching:**
- **launchAtAngle(entity, angle_radians, speed)** - Set velocity from angle.
- **launchFromOffset(entity, offset_x, anchor_width, speed, base_angle, angle_range)** - Launch based on position offset.

**Utilities:**
- **updateTrail(entity, max_length)** - Add current position to trail array.
- **wrapPosition(x, y, ew, eh, bw, bh)** - Screen wrap position.
- **createTrailSystem(config)** - Create trail object with addPoint/clear/draw methods.

---

## ProjectileSystem
Generic projectile/bullet system with pooling and patterns.

- **new(config)** - Create system. Config: projectile_types (definitions), pooling, max_projectiles, ammo, heat.
- **shoot(type_name, x, y, angle, speed_multiplier, custom_params)** - Spawn single projectile. Returns projectile.
- **shootPattern(type_name, x, y, base_angle, pattern, config)** - Spawn pattern. Returns array of projectiles.
- **update(dt, game_bounds)** - Update all projectiles (movement, lifetime, bounds).
- **checkCollisions(targets, callback, team_filter)** - Check collisions with targets, call callback(proj, target).
- **removeProjectile(projectile)** - Remove projectile, return to pool.
- **clear()** - Remove all projectiles.
- **draw(render_callback)** - Draw all active projectiles via callback.
- **getCount()** / **getProjectiles()** - Get count or array of active projectiles.
- **getProjectilesByTeam(team)** - Get projectiles filtered by team.
- **setHomingTargets(targets)** - Set target list for HOMING_NEAREST projectiles.
- **updateFireMode(dt, entity, mode, config, is_fire_pressed, on_fire)** - Handle fire modes (manual/auto/charge/burst).
- **canShoot()** - Check if shooting is allowed (ammo/heat restrictions). Auto-triggers reload if empty.
- **onShoot()** - Call after shooting to consume ammo and add heat.
- **updateResources(dt)** - Update reload timer and heat dissipation. Call each frame.
- **reload()** - Manually trigger reload if not full.

**Ammo config:** {enabled, capacity, reload_time}
**Heat config:** {enabled, max, cooldown, dissipation}
**State fields:** ammo_current, is_reloading, reload_timer, heat_current, is_overheated, overheat_timer

**Patterns:** "single", "double", "triple", "spread", "spiral", "wave", "ring"
**Movement types:** LINEAR, HOMING, HOMING_NEAREST, SINE_WAVE, BOUNCE, ARC

---

## PowerupSystem
Powerup spawning, collection, and effect management.

- **new(config)** - Create system. Config: enabled, spawn_mode, spawn_rate, powerup_types, powerup_configs, color_map, hooks.
- **spawn(x, y, powerup_type)** - Spawn powerup at position. Random type if nil.
- **update(dt, collector_entity, game_bounds)** - Update movement, collection, effect timers.
- **collect(powerup)** - Trigger collection and apply effects.
- **removeEffect(powerup_type)** - End effect early, restore original values.
- **clear(clear_active)** - Clear all powerups and optionally active effects.
- **getPowerupsForRendering()** - Get falling powerups array.
- **getActivePowerupsForHUD()** - Get active effects {type = {duration_remaining, ...}}.
- **getColorForType(powerup_type)** - Get {r,g,b} color for type.
- **getPowerupCount()** / **getActiveEffectCount()** - Get counts.
- **hasActiveEffect(powerup_type)** - Check if effect is active.
- **getTimeRemaining(powerup_type)** - Get seconds remaining for effect.
- **checkCollision(powerup, entity)** - AABB collision check.

**Spawn modes:** "timer", "event", "both", "manual"
**Declarative effects:** multiply_param, enable_param, set_param, set_flag, add_lives, heal_shield, multiply_entity_speed, multiply_entity_field, set_entity_field, spawn_projectiles

---

## EntityController
Generic enemy/obstacle spawning and management with pooling.

- **new(config)** - Create controller. Config: entity_types (definitions), spawning {mode, rate, max_concurrent}, pooling, max_entities.
- **spawn(type_name, x, y, custom_params)** - Spawn single entity. Returns entity.
- **spawnGrid(type_name, rows, cols, x, y, spacing_x, spacing_y)** - Spawn rectangular grid.
- **spawnPyramid(type_name, rows, max_cols, x, y, spacing_x, spacing_y, arena_width)** - Spawn centered pyramid/triangle.
- **spawnCircle(type_name, rings, center_x, center_y, base_count, ring_spacing)** - Spawn concentric circles.
- **spawnRandom(type_name, count, bounds, rng, allow_overlap)** - Spawn randomly in bounds.
- **spawnCheckerboard(type_name, rows, cols, x, y, spacing_x, spacing_y)** - Spawn checkerboard pattern.
- **spawnLayout(type_name, layout, config)** - Dispatch to layout spawner. Layouts: "grid", "pyramid", "circle", "random", "checkerboard", "v_shape", "line", "spiral". Grid layout auto-adds grid_row/grid_col to each entity. Config.extra merged into spawned entities.
- **spawnWeighted(type_name, weighted_configs, x, y, base_extra)** - Spawn using weighted random selection. Each config in array has `weight` plus properties to merge. Returns spawned entity.
- **update(dt, game_state)** - Update spawning and all entities.
- **checkCollision(obj, callback)** - Check collision with circle/rect object. Returns colliding entities.
- **hitEntity(entity, damage, by_what)** - Deal damage, trigger callbacks. Returns true if killed.
- **killEntity(entity)** - Trigger death callback, mark for removal.
- **removeEntity(entity)** - Remove from list, return to pool.
- **clear()** - Remove all entities.
- **draw(render_callback)** - Draw all via callback.
- **getActiveCount()** / **getTotalCount()** - Get counts.
- **getEntities()** - Get all active entities.
- **getEntitiesByType(type_name)** - Get entities of specific type.
- **findNearest(x, y, filter)** - Find nearest entity. Returns entity, distance.
- **loadCollisionImage(type_name, image_path, alpha_threshold, di)** - Load PNG for pixel collision.
- **getRectCollisionCheck(PhysicsUtils)** - Get collision check function for rect-rect.

**updateBehaviors(dt, config, collision_check)** - Per-entity behaviors:
- `fall_enabled` - Entities fall at fall_speed
- `move_enabled` - Entities move horizontally, bounce off walls
- `regen_enabled` - Dead entities regenerate after regen_time
- `shooting_enabled` - Entities fire at shoot_rate, calls on_shoot
- `rotation` - Entities rotate based on rotation_speed
- `bounce_movement` - Entities with movement_pattern='bounce' bounce off {width, height} bounds
- `delayed_spawn` - Entities with delayed_spawn={timer, spawn_type} convert after timer expires, calls on_spawn(entity, config)
- `timer_spawn` - Spawn entities on timers: {type_name = {interval, on_spawn(ec, type_name)}}
- `remove_offscreen` - Remove entities outside bounds {top, bottom, left, right}
- `grid_unit_movement` - Space Invaders style: all grid entities move as unit, speed up as count drops

**Spawn modes:** "continuous", "wave", "grid", "manual"

---

## BaseGame
Base class for all minigames. Provides common state, fixed timestep, demo playback, and schema-based component creation.

### Initialization & State
- **init(game_data, cheats, di, variant_override)** - Initialize game with data, cheats, DI container, optional variant override.
- **updateBase(dt)** - Variable timestep update (for normal gameplay). Tracks time_elapsed, checks completion.
- **updateWithFixedTimestep(dt)** - Accumulator-based fixed timestep wrapper. Calls fixedUpdate() at fixed_dt intervals.
- **fixedUpdate(dt)** - Deterministic update at fixed_dt (default 1/60). Calls updateGameLogic(dt).
- **updateGameLogic(dt)** - Override in subclasses for game-specific logic.
- **setPlayArea(width, height)** - Resize arena and reposition entities.
- **checkComplete()** - Default: returns victory or game_over.
- **onComplete()** - Called when game completes. Sets completed = true.
- **getCompletionRatio()** - Override to report progress 0..1 toward goal.
- **getMetrics()** / **calculatePerformance()** / **getResults()** - Get metrics and token calculation.

### Schema-Based Component Creation
- **createComponentsFromSchema()** - Create components from params.components definitions. Each entry has {type, config}.
- **createProjectileSystemFromSchema(extra_config)** - Create ProjectileSystem from params.projectile_types.
- **createEntityControllerFromSchema(callbacks, extra_config)** - Create EntityController from params.entity_types. Callbacks = {type_name = {on_hit = fn, on_death = fn}}.
- **createPowerupSystemFromSchema(extra_config)** - Create PowerupSystem from params.powerup_effect_configs.
- **createVictoryConditionFromSchema(bonuses)** - Create VictoryCondition from params.victory_conditions mapping.
- **resolveConfig(config)** - Resolve "$param_name" references to actual param values.

### Cheat Application
- **applyCheats(mappings)** - Apply cheats to params. Mappings = {speed_modifier = {"param1", "param2"}, advantage_modifier = {...}, performance_modifier = {...}}.

### Entity Management Helpers
- **createPlayer(config)** - Create player entity from params. Config: {entity_name, x, y, width, height, radius, extra}.
- **createPaddle(extra_fields)** - Alias for createPlayer with entity_name = "paddle".
- **syncMetrics(mapping)** - Sync game fields to metrics. Mapping = {metric_name = "field_name"}.
- **handleEntityDepleted(count_func, config)** - Handle depletion (no balls, etc.). Config: {loss_counter, damage, combo_reset, damage_reason, on_respawn, on_game_over}. Returns true if game over.
- **handleEntityDestroyed(entity, config)** - Handle destruction with effects. Config: {destroyed_counter, remaining_counter, spawn_powerup, effects = {particles, shake}, scoring = {base, combo_mult}, popup = {enabled, milestone_combos}, color_func, extra_life_check}.

### Param Manipulation (for powerups)
- **multiplyParam(param_name, multiplier)** - Multiply param, return original value.
- **restoreParam(param_name, original_value)** - Restore param to original.
- **enableParam(param_name)** - Set param to true, return original.
- **setParam(param_name, value)** - Set param to value, return original.
- **multiplyEntitySpeed(entities, multiplier)** - Multiply vx/vy of all entities.

### Flash Feedback System
- **flashEntity(entity, duration)** - Start flash timer for entity (default 0.1s).
- **updateFlashMap(dt)** - Update flash timers. Call in updateGameLogic().
- **isFlashing(entity)** - Check if entity is currently flashing.

### Input & Demo Playback
- **setPlaybackMode(enabled)** - Enable/disable demo playback mode.
- **isInPlaybackMode()** - Check if in playback mode.
- **isKeyDown(...)** - Check key state (virtual during playback, real otherwise).
- **setVMRenderMode(enabled)** / **isVMRenderMode()** - VM render mode (hides HUD).

### Audio
- **loadAudio()** - Load music and SFX from variant.
- **playMusic()** / **stopMusic()** - Music control.
- **playSound(action, volume)** - Play SFX from loaded pack.

---

## Common Patterns

### Damage/Lives Pattern (from Phase 3)
Games should use LivesHealthSystem for damage handling:
```lua
function MyGame:takeDamage()
    local absorbed = self.health_system:takeDamage(1)
    self:playSound("hit", 1.0)
    if not absorbed then
        self.deaths = self.deaths + 1
        self.lives = self.health_system.lives
        self.combo = 0
    end
end
```

### Compute-on-Demand Pattern
Instead of pre-calculating values in init, compute them when needed:
```lua
function MyGame:getEnemySpeed()
    local base = self.params.enemy_speed
    local difficulty = self.difficulty_modifiers.speed or 1
    return base * difficulty
end
```

### Direct Param Access in Views
Views should access params directly, not via shim fields:
```lua
-- Good: Use params directly
g.print("Target: " .. game.params.victory_limit)
-- Bad: Don't create shim fields
g.print("Target: " .. game.target_kills)
```

---

