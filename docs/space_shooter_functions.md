# Space Shooter Function Reference

## init
Initializes the game. Loads parameters from space_shooter_schema.json using SchemaLoader. Applies cheat modifiers to speed and size params. Adds extra lives from cheats. Gets arena size from config. Calls setupComponents and setupEntities. Creates the view. Loads sprite assets.

**Notes:** Follows breakout pattern exactly. 22 lines of setup calls.

**Extraction Potential:** None.

---

## setupComponents
Creates all the reusable components from schema definitions. Calls createComponentsFromSchema which makes health_system, hud, movement_controller, visual_effects. Overrides movement_controller thrust/jump settings. Creates projectile_system with ammo and heat configs. Creates entity_controller with enemy and asteroid types and an on_death callback. Creates victory_checker. Creates powerup_system with timer-based spawning.

**Notes:** 51 lines vs breakout's 46 lines. Uses identical createXxxFromSchema() patterns.

**Extraction Potential:** None.

---

## setupEntities
Creates the player entity at the correct Y position based on reverse_gravity. Sets up all the player state fields like fire_cooldown, ammo, heat, jump state. Initializes game counters like survival_time, spawn_timer, kills, deaths. Creates empty arrays for enemies, asteroids, meteors. Creates gravity well objects with random positions. Creates blackout zone objects with random positions and velocities. Builds the enemy_weighted_configs array from variant enemy definitions for use with spawnWeighted.

**Notes:** 62 lines vs breakout's 9 lines. Gravity wells and blackout zones loops add 15 lines.

**Extraction Potential:** Make gravity_well and blackout_zone entity types in schema, use entity_controller:spawnRandom(). 15 lines → 2 lines.

---

## getEnemySpeed
Multiplies the base enemy speed param by the difficulty modifier, cheat modifier, and variant difficulty modifier. Returns the final speed value.

**Notes:** 4 lines. Pattern is generic: base * difficulty * cheat * variant * optional_random.

**Extraction Potential:** Extract to BaseGame:getScaledValue(base). Reads variance from variant config. Any game with scaling enemies/hazards uses it. Could eliminate multiple functions that do similar calculations.

---

## loadAssets
Gets the sprite set name from the variant. Uses spriteSetLoader to load the player sprite. Loops through all enemy types and loads their sprites. Calls loadAudio to load sounds.

**Notes:** 18 lines. Breakout doesn't have sprites yet but will. Every game needs asset loading.

**Extraction Potential:** Extract to BaseGame:loadAssets(). Loads sprites for player + all entity types from schema. Loads audio from schema-defined sounds. One call handles everything. 18 lines → 1 line per game.

---

## setPlayArea
Called when the play area is resized. Updates game_width and game_height. Clamps the player X position to stay in bounds. Repositions the player Y based on reverse_gravity. If using galaga mode and formation exists, recalculates the formation positions for the new screen size while preserving which slots are occupied.

**Notes:** 33 lines. Basic resize handling is generic. Galaga formation recalc is mode-specific (15 lines).

**Extraction Potential:** Extract basic resize (update dimensions, clamp player) to BaseGame:setPlayArea(). Space shooter overrides, calls super, then does Galaga stuff. Galaga recalc could be renamed to separate function like recalculateGalagaFormation().

---

## updateGameLogic
The main game loop. Updates health_system and syncs lives. Updates entity_controller. Syncs the enemies/asteroids/meteors/meteor_warnings arrays from entity_controller. Updates projectile_system with bounds. Syncs player_bullets and enemy_bullets arrays. Calls updatePlayer. Tracks survival_time. Calls updateDifficulty. Checks which enemy behavior mode we're in and calls the appropriate update function (updateSpaceInvadersGrid, updateGalagaFormation, or default spawning). Calls updateEnemies and updateBullets. Updates powerup_system. Syncs powerup arrays. Calls updateHazards if asteroids or meteors enabled. Calls applyGravityWells if gravity wells exist. Calls updateScrolling if scroll enabled. Calls updateBlackoutZones if zones exist and move.

**Notes:** 99 lines vs breakout's 48 lines.

**Extraction Potential:**
1. Entity syncing loop (12 lines) → use getEntitiesByType() which already exists. 12 lines → 4 lines.
2. Spawn pattern logic (continuous/clusters ~15 lines) → EntityController already has spawn modes (continuous, wave). Use those instead of inline timer logic.

---

## updatePlayer
Increments player time_elapsed. Calls movement_controller:update with WASD input and arena bounds with wrap settings. Calls projectile_system:updateFireMode with the current fire mode config and a callback that calls playerShoot. Calls projectile_system:updateResources to handle reload and heat dissipation. Checks if R pressed to trigger manual reload. Syncs ammo/reload/heat state from projectile_system to player fields for HUD display.

**Notes:** 36 lines. Uses existing components properly for movement and firing.

**Extraction Potential:** State syncing (6 lines) is redundant. HUD should read directly from projectile_system instead of copying to player fields. Delete the sync, update HUD to access projectile_system directly.

---

## updateEnemies
Gets PatternMovement component. Loops through enemies that aren't grid/bezier/formation pattern. For each, calculates speed from getEnemySpeed with multipliers, sets direction based on reverse_gravity, sets zigzag params, calls PatternMovement.update. Marks grid/formation enemies to skip offscreen removal. Checks collision between player and enemies, calls takeDamage and removes enemy on hit. Calls updateBehaviors with shooting and offscreen removal config.

**Notes:** 41 lines. Movement loop sets params then calls PatternMovement. Collision checks all entities then filters by type.

**Extraction Potential:**
1. Enemy movement loop (14 lines) - set final speed/direction/zigzag at spawn time instead. Behavior just uses entity.speed directly. No per-frame recalculation.
2. Collision filtering - use getEntitiesByType("enemy") as collision targets instead of checking type_name in callback.

---

## updateBullets
Sets homing targets on projectile_system for homing bullets. Checks collisions between player bullets and enemies, calls entity_controller:hitEntity on hit. Checks collisions between enemy bullets and player, calls takeDamage on hit. If screen_wrap_bullets enabled, loops player bullets and calls applyScreenWrap, removes bullet if exceeded max wraps.

**Notes:** 24 lines. Uses existing setHomingTargets() and checkCollisions() properly.

**Extraction Potential:** Screen wrap loop (7 lines) - projectile_system doesn't support wrap yet. Add wrap support to projectile_system (bounds mode with max_wraps config), then delete manual loop entirely.

---

## draw
Calls view:draw if view exists, otherwise prints error.

**Notes:** 7 lines vs breakout's 3 lines. Error check is unnecessary defensive code.

**Extraction Potential:** Remove error check. Just `self.view:draw()`. 7 lines → 3 lines.

---

## playerShoot
Returns early if projectile_system:canShoot returns false. Calculates the base angle from player angle or 0. Gets spawn position from getBulletSpawnPosition. Converts angle to standard angle. Builds pattern config with speed multiplier, bullet count, arc, spread, and custom fields like size/piercing/homing. Calls projectile_system:shootPattern. Calls projectile_system:onShoot to consume ammo/add heat. Plays shoot sound.

**Notes:** 33 lines. All behavior is param-driven (movement_type, reverse_gravity, bullet_* params).

**Extraction Potential:** Fully extractable to BaseGame:playerShoot(). Spawn position from params.movement_type, angle from movement_type/reverse_gravity, config auto-built from params.bullet_* fields. Powerup overrides passed in or read from active effects. Space shooter's version becomes one line.

---

## getBulletSpawnPosition
Calculates where bullets spawn. Gets player center position. If asteroids movement mode, offsets from center in the direction player is facing. Otherwise spawns at player top (or bottom if reverse_gravity).

**Notes:** 16 lines. Helper for playerShoot.

**Extraction Potential:** Delete entirely. Logic becomes part of BaseGame:playerShoot() generic spawn position calculation.

---

## convertToStandardAngle
Converts the player's facing angle to the angle bullets should travel. Accounts for reverse_gravity by flipping the direction.

**Notes:** 5 lines. Helper for playerShoot.

**Extraction Potential:** Delete entirely. Logic becomes part of BaseGame:playerShoot() angle calculation.

---

## enemyShoot
Gets enemy center position. Calculates base angle (down, or up if reverse_gravity). Builds pattern config from enemy bullet params. Calls projectile_system:shootPattern for enemy bullets.

**Notes:** 19 lines. Same pattern as playerShoot but for enemies.

**Extraction Potential:** Extract to BaseGame:entityShoot(entity, bullet_type). Reads params for bullet config, calculates spawn position and angle. EntityController handles WHEN (timer), BaseGame handles HOW (generic).

---

## calculateEnemyHealth
Takes base health and multiplier. If use_health_range enabled, picks random value in range. Otherwise applies variance to base health. Returns the final integer health value, minimum 1.

**Notes:** 6 lines. Same pattern as getEnemySpeed - scaling with variance.

**Extraction Potential:** Use generic BaseGame:getScaledValue(base, config). One function handles speed, health, spawn rate, damage - any scaled value with range/variance/multipliers/bounds. DRY, consistent.

---

## spawnEnemy
If variant enemies exist and 50% chance, calls spawnVariantEnemy instead. Gets spawn Y position based on reverse_gravity. Calculates speed and shoot rate from params and difficulty. If enemy_formation is v_formation/wall/spiral, calls spawnLayout with that layout. Otherwise picks movement pattern based on difficulty and spawns single enemy with calculated health.

**Notes:** 24 lines. Uses entity_controller:spawnLayout for formations. All logic is param-driven.

**Extraction Potential:** Extract to BaseGame:spawnEntity(type, config). Handles edge spawning, formation choice, stat calculation via getScaledValue. EntityController does actual spawn, BaseGame handles decision logic.

---

## hasVariantEnemies
Returns true if enemy_weighted_configs array has entries.

**Notes:** 3 lines. Tiny helper, only used in spawnEnemy.

**Extraction Potential:** Delete entirely. BaseGame:spawnEntity handles weighted config check internally - if weighted configs exist, use spawnWeighted, else regular spawn. No separate function needed.

---

## spawnVariantEnemy
Returns to spawnEnemy if no weighted configs. Calculates spawn position and shoot rate. Calls entity_controller:spawnWeighted with the weighted configs. Sets shoot_rate on spawned enemy. If movement pattern is dive, sets target to player position.

**Notes:** 15 lines. Same pattern as spawnEnemy but uses weighted configs.

**Extraction Potential:** Delete entirely. Merges into BaseGame:spawnEntity which handles weighted configs internally.

---

## takeDamage
Calls health_system:takeDamage. Plays hit sound. If damage wasn't absorbed by shield, increments deaths, syncs lives from health_system, resets combo to 0.

**Notes:** 5 lines. Matches documented "Common Patterns" but pattern isn't extracted yet.

**Extraction Potential:** Extract to BaseGame:takeDamage(amount, sound). Handles health_system call, sound, counter updates. Every game needs this. Games override only for custom behavior.

---

## onEnemyDestroyed
Calls handleEntityDestroyed with config that increments kills counter, gives 10 points base score, no particles.

**Notes:** 8 lines. Callback wrapper with game-specific config.

**Extraction Potential:** None. Already uses BaseGame:handleEntityDestroyed() correctly. This is proper component usage.

---

## checkComplete
Calls victory_checker:check. If result, sets victory or game_over flag based on result. Returns true if complete.

**Notes:** 10 lines. Every game does this identically. Breakout has same logic inline in updateGameLogic.

**Extraction Potential:** Extract to BaseGame:checkComplete() or handle in updateBase automatically. Once extracted, also clean up breakout's inline version to use the same function.

---

## onComplete
Plays success sound if victory, death sound if loss. Stops music. Calls parent onComplete.

**Notes:** 18 lines. Every game plays sounds on win/loss and stops music.

**Extraction Potential:** Extract to BaseGame:onComplete(). Check victory flag, play params.win_sound or params.lose_sound, stop music. Games only override for custom behavior beyond sounds.

---

## keypressed
Calls parent keypressed for demo playback tracking.

**Notes:** 5 lines. Only calls parent and returns false.

**Extraction Potential:** Delete entirely. BaseGame:keypressed already handles demo tracking. Parent called through inheritance automatically. Override is unnecessary.

---

## initSpaceInvadersGrid
Calculates wave multiplier from wave number and difficulty increase param. Applies random variance. Calculates wave-specific rows, columns, speed, health. Calculates spacing from game width. Calls spawnLayout with grid layout and movement_pattern='grid'. Sets grid_state initialized/initial_count/wave_active/wave_number/shoot_timer.

**Notes:** 28 lines. Space Invaders-specific wave initialization.

**Extraction Potential:**
1. Wave multiplier/variance calculations - use getScaledValue
2. Whole pattern could be generic BaseGame:initWave() that works for any spawn layout, not just grids. Track wave state generically.

---

## updateSpaceInvadersGrid
If waves enabled and wave active, checks if any grid enemies still alive. If none alive, sets wave inactive and starts pause timer, resets grid state. If wave not active, decrements pause timer and calls initSpaceInvadersGrid when done, then returns. If grid not initialized, calls initSpaceInvadersGrid. Gets wave speed from first grid enemy. Calls updateBehaviors with grid_unit_movement config for Space Invaders style movement. If enemy bullets enabled, decrements shoot timer. When timer hits 0, finds the bottom-most enemy in each column, picks one randomly to shoot, resets timer based on how many enemies remain.

**Notes:** 97 lines. Wave management is generic. Grid shooting is Space Invaders-specific.

**Extraction Potential:**
1. Wave management (check depleted, pause, start new) → extract to BaseGame:updateWaveState(). Used by Space Invaders, Galaga, any wave-based game.
2. Grid shooting logic (bottom-row shoots) → stays in space_shooter, mode-specific. Maybe rename to updateGridShooting() or similar for clarity.

---

## initGalagaFormation
Calculates spacing from enemy_density. Calculates how many columns fit on screen. Loops through formation_size, wrapping to next row when column full. Creates formation_positions array with x, y, occupied, enemy_id for each slot. Sets initial_enemy_count and wave_active.

**Notes:** 41 lines. Similar pattern to initSpaceInvadersGrid.

**Extraction Potential:**
1. Wave init pattern → use generic BaseGame:initWave() once extracted.
2. Grid-with-wrap-to-rows layout could be a generic layout helper. Formation slot tracking is Galaga-specific.

---

## spawnGalagaEnemy
Takes a formation slot and optional wave modifiers. Gets PatternMovement component. Picks random entrance side. Sets start position off-screen. Gets entrance pattern (loop or swoop). Calls PatternMovement.buildPath to create bezier path from start to formation slot. Marks slot as occupied. Spawns enemy with bezier movement pattern, formation state, slot reference, home position, bezier path.

**Notes:** 42 lines. Uses PatternMovement.buildPath correctly.

**Extraction Potential:** Delete entirely. Entrance animation becomes spawn config. Flexible options:
- Named presets: `{entrance = "swoop_left"}`
- Custom start: `{entrance = "swoop", start = {x, y}, target = slot}`
- Full control: `{entrance = "bezier", path = {{x,y}, {x,y}, {x,y}}}`
BaseGame:spawnEntity() checks for entrance config and auto-builds bezier path. Schema defines defaults, spawn config overrides.

---

## updateGalagaFormation
If waves enabled and wave active, checks if any galaga enemies alive. If none, sets wave inactive, starts pause timer, clears formation positions. If wave not active, decrements pause timer. When done, calculates wave modifiers for health and dive frequency, calls initGalagaFormation, increments wave number, resets spawn/dive timers, spawns initial batch of enemies with entrance animations, then returns. If formation empty, initializes it and spawns initial batch. Finds unoccupied slots. If slots available and haven't spawned all, decrements spawn timer and spawns enemy to random slot when done. Decrements dive timer. When dive timer hits 0 and not at max divers, finds enemies in formation, picks random one, sets it to diving state with bezier path targeting player then exiting bottom. Loops all enemies updating their state: entering enemies follow bezier until complete then switch to in_formation, in_formation enemies stay at home position, diving enemies follow bezier until complete then get removed and respawned with new entrance.

**Notes:** 133 lines. Wave management is generic. Dive attacks and formation state machine are Galaga-specific.

**Extraction Potential:**
1. Wave management (check depleted, pause, start new) → use generic BaseGame:updateWaveState()
2. Gradual spawn timer → generic "spawn over time to slots"
3. Dive attacks and formation state machine → stays in space_shooter, Galaga-specific

---

## updateWaveSpawning
Simple wave spawner for default mode. If wave active, decrements spawn timer and spawns enemies until wave count reached, then starts pause. If not active, decrements pause timer then starts new wave with scaled enemy count.

**Notes:** 21 lines. Same wave pattern as Space Invaders and Galaga, just simpler.

**Extraction Potential:** Delete entirely. Uses generic BaseGame:updateWaveState() once extracted. All three wave modes (grid, formation, default) use the same pattern.

---

## updateDifficulty
Updates difficulty_scale based on difficulty_curve param. Linear adds constant. Exponential multiplies. Wave uses sine function. Caps at 5.0.

**Notes:** 19 lines. Completely generic difficulty scaling.

**Extraction Potential:** Extract to BaseGame:updateDifficulty(). Any game could use difficulty curves. Params define curve type and scaling rate.

---

## updateHazards
Gets params and direction based on reverse_gravity. If asteroid_density > 0, decrements spawn timer and spawns asteroid with straight movement pattern when timer hits 0. If meteor_frequency > 0, decrements timer and spawns meteor_warnings when done. Loops warnings decrementing time_remaining, spawns meteor when warning expires. Calls updateBehaviors with pattern_movement, rotation, and remove_offscreen. Checks collision with player for asteroids and meteors, calls takeDamage. Checks bullet collisions with asteroids (if destroyable) and meteors.

**Notes:** 66 lines. Asteroid spawning is timer-based edge spawn. Meteor uses warning→meteor delayed spawn pattern. updateBehaviors and collision checks use components correctly.

**Extraction Potential:**
1. Asteroid timer spawn (12 lines) - EntityController already has "continuous" spawn mode with rate. Use that instead of manual timer.
2. Meteor warning→meteor (21 lines) - "delayed spawn" pattern. Could be generic: spawn warning entity, when timer expires auto-convert to real entity. EntityController behavior or separate helper.
3. Collision filtering - uses getEntitiesByType() internally via type arrays, but could be cleaner. Already acceptable.
4. updateBehaviors call - correct usage, no change needed.

---

## applyGravityWells
Loops through gravity_wells array. For each well, calls PhysicsUtils.applyGravityWell on player. Loops player_bullets and calls applyGravityWell with 0.7 strength multiplier. Clamps player position to arena bounds.

**Notes:** 17 lines. Duplicates what applyForces already does. Bounds clamping is redundant with MovementController.

**Extraction Potential:** Delete entirely.
1. Add `gravity_wells` as config option to PhysicsUtils.applyForces() - loops wells internally
2. Call applyForces in updatePlayer with gravity_wells config
3. Delete redundant bounds clamping (MovementController handles it)
4. Delete this function - 17 lines → 0 lines

---

## updateScrolling
Adds scroll_speed * dt to scroll_offset.

**Notes:** 6 lines. 1 line of actual logic. Common pattern for scrolling backgrounds.

**Extraction Potential:** Extract to BaseGame:updateScrolling(). Any game with scrolling backgrounds uses this. Reads params.scroll_speed, updates self.scroll_offset. Space shooter just calls it or it's called automatically in updateBase if scroll_speed > 0.

---

## applyScreenWrap
Calls PhysicsUtils.wrapPosition to wrap object position. If position changed and object has wrap_count, increments it. Returns true if wrap_count exceeded max_wraps.

**Notes:** 22 lines. Only used by manual bullet wrap loop in updateBullets.

**Extraction Potential:** Delete entirely. Once projectile_system supports wrap with max_wraps config (per updateBullets notes), the manual loop goes away and this function has no callers. 22 lines → 0 lines.

---

## updateBlackoutZones
Loops blackout_zones. Adds velocity * dt to position. Bounces off walls by reversing velocity and clamping position when hitting edges.

**Notes:** 16 lines. This is the "bounce" movement pattern. PatternMovement.updateBounce already does this.

**Extraction Potential:** Delete entirely. Make blackout_zone an entity type (per setupEntities notes), spawn via spawnRandom, set movement_pattern = 'bounce'. updateBehaviors with pattern_movement handles movement. 16 lines → 0 lines.

---
