# Plan: Space Shooter Phase 3 - AGGRESSIVE DELETION

## Goal

**DELETE ~1000 lines from Space Shooter** by adopting the EXACT patterns used in breakout.lua.

- **Current:** ~1329 lines
- **Target:** ~300-400 lines (same as breakout)
- **Template:** breakout.lua (335 lines)

This is NOT incremental. This is a COMPLETE rewrite using existing patterns.

## Reference: Breakout Structure (335 lines)

```
init()                  ~18 lines  - SchemaLoader.load(), applyCheats(), create entities
setupComponents()       ~45 lines  - createXxxFromSchema() calls with callbacks
setupEntities()         ~10 lines  - spawn balls, obstacles, bricks
spawnBall()             ~15 lines  - projectile_system:shoot()
generateObstacles()     ~7 lines   - entity_controller:spawnRandom()
generateBricks()        ~28 lines  - entity_controller:spawnLayout()
updateGameLogic()       ~48 lines  - update systems, handleEntityDepleted()
updateBall()            ~70 lines  - Physics.applyForces/handleBounds/checkCollisions
updateBricks()          ~12 lines  - entity_controller:updateBehaviors()
onBrickDestroyed()      ~12 lines  - handleEntityDestroyed() with config
keypressed()            ~12 lines  - shoot, release stuck
draw()                  ~3 lines   - view:draw()
```

Space Shooter should have the SAME structure. Different entity types, same patterns.

---

## Rules for AI

1. **THE GOAL IS TO DELETE ~1000 LINES FROM SPACE SHOOTER.**
2. **USE BREAKOUT AS THE TEMPLATE.** If breakout does it one way, space shooter does it that way.
3. Complete ALL steps within a phase before stopping.
4. After completing a phase, write notes including **exact line count deleted**.
5. Do NOT proceed to the next phase without user approval.
6. Run NO tests yourself - the user will do manual testing.

### CRITICAL: This is NOT a Refactor, This is a REPLACEMENT

You are not "improving" the existing code. You are REPLACING it with breakout-style patterns.

**THE OLD CODE GETS DELETED. ALL OF IT.**

When a phase says "DELETE updateEnemies()", you:
1. Write the new version using breakout patterns
2. DELETE the old function ENTIRELY
3. If something breaks, FIX THE CALLER

**ABSOLUTELY FORBIDDEN:**
- Keeping ANY inline logic that breakout handles via components
- "But this is different because..." - NO. Use the same pattern.
- Preserving backward compatibility
- Wrapper functions
- "Preserved for reference" comments
- Partial deletions - DELETE THE WHOLE FUNCTION
- Adding game-specific code to components
- Being "careful" or "conservative" - BE AGGRESSIVE

**REQUIRED:**
- DELETE entire functions, not lines within functions
- Use the EXACT same patterns as breakout
- If breakout uses handleEntityDestroyed(), space_shooter uses handleEntityDestroyed()
- If breakout uses Physics.checkCollisions(), space_shooter uses Physics.checkCollisions()
- Count lines deleted HONESTLY - should be ~200+ per phase

### Why Previous Refactors Failed

Previous phases deleted 5-30 lines at a time. That's NOT refactoring, that's editing.

Breakout went from 1400 lines to 335 lines. That's 1065 lines deleted. ~75% reduction.

Space shooter at 1329 lines should become ~300-400 lines. That's ~1000 lines to delete.

5 phases = 200 lines deleted per phase MINIMUM.

If you complete a phase and deleted less than 100 lines, YOU DID IT WRONG.

---

## Phase 1: DELETE All Parameter Initialization (~200 lines deleted)

**What we're deleting:**
- setupGameState() parameter calculations (~50 lines)
- All inline self.params.xxx fallbacks throughout the file
- Difficulty modifier calculations
- Enemy composition building (now in schema)

**What breakout does:**
```lua
self.params = self.di.components.SchemaLoader.load(self.variant, "space_shooter_schema", runtimeCfg)
self:applyCheats({...})
```

**What space_shooter should become:**
```lua
function SpaceShooter:init(game_data, cheats, di, variant_override)
    SpaceShooter.super.init(self, game_data, cheats, di, variant_override)

    self.params = self.di.components.SchemaLoader.load(self.variant, "space_shooter_schema", runtimeCfg)
    self:applyCheats({
        speed_modifier = {"movement_speed", "bullet_speed"},
        advantage_modifier = {"lives_count"},
        performance_modifier = {}
    })

    self:setupComponents()
    self:setupEntities()
    self.view = SpaceShooterView:new(self)
end
```

### Steps

1.1. Ensure space_shooter_schema.json has ALL parameters with defaults
1.2. DELETE setupGameState() - replace with SchemaLoader.load()
1.3. DELETE all self.params.xxx or DEFAULT_xxx fallback patterns
1.4. DELETE difficulty_modifiers calculations - put in schema
1.5. DELETE enemy_composition building - put in schema
1.6. Use applyCheats() like breakout does

### Lines Deleted
- setupGameState(): **~60 lines DELETED**
- Inline parameter fallbacks: **~100 lines DELETED**
- difficulty_modifiers: **~20 lines DELETED**
- enemy_composition: **~20 lines DELETED**
- **Total: ~200 lines DELETED**

### Testing (User)
- [ ] Game loads with correct parameters
- [ ] Cheats apply correctly
- [ ] Variants work

### AI Notes
(To be filled after completion)

---

## Phase 2: DELETE Component Setup (~150 lines deleted)

**What we're deleting:**
- Manual projectile_system creation
- Manual entity_controller creation
- Manual health_system/hud/visual_effects creation
- Player state initialization

**What breakout does:**
```lua
function Breakout:setupComponents()
    self:createComponentsFromSchema()
    self:createProjectileSystemFromSchema({...})
    self:createEntityControllerFromSchema({
        brick = { on_death = function(brick) game:onBrickDestroyed(brick) end }
    }, {...})
    self:createVictoryConditionFromSchema({...})
    self:createPowerupSystemFromSchema({...})
end
```

### Steps

2.1. DELETE manual projectile_system creation - use createProjectileSystemFromSchema()
2.2. DELETE manual entity_controller creation - use createEntityControllerFromSchema()
2.3. DELETE manual health_system/hud/victory_checker creation - use createComponentsFromSchema()
2.4. DELETE player state object building - use createPaddle() equivalent
2.5. Move all callbacks to createEntityControllerFromSchema()

### Lines Deleted
- Manual component creation: **~80 lines DELETED**
- Player state building: **~40 lines DELETED**
- Callback definitions: **~30 lines DELETED**
- **Total: ~150 lines DELETED**

### Testing (User)
- [x] Player spawns correctly
- [x] Enemies spawn correctly
- [x] Health/lives work
- [x] Victory/loss conditions work

### AI Notes

**Already completed in phase2_plan.md refactor.**

The current space_shooter.lua already uses all the schema-based patterns:

- Line 34: `self:createComponentsFromSchema()` - creates health_system, hud, visual_effects, movement_controller
- Lines 44-57: `self:createProjectileSystemFromSchema()` - with ammo/heat config
- Lines 60-67: `self:createEntityControllerFromSchema()` - with enemy on_death callback
- Line 70: `self:createVictoryConditionFromSchema()`
- Lines 73-78: `self:createPowerupSystemFromSchema()`
- Line 87: `self:createPlayer()` - uses BaseGame helper

setupComponents() is 51 lines, matching breakout's 46 lines. No additional deletions possible.

**Lines deleted from space_shooter.lua: 0** (already done in previous refactor)

**Line count: 1184 (unchanged from Phase 1)**

---

## Phase 3: DELETE updateEnemies() (~200 lines deleted)

**What we're deleting:**
- The ENTIRE updateEnemies() function
- updateSpaceInvadersGrid()
- updateGalagaFormation()
- All inline enemy movement logic

**What breakout does:**
```lua
function Breakout:updateBricks(dt)
    self.bricks = self.entity_controller:getEntities()
    self.entity_controller:updateBehaviors(dt, {
        fall_enabled = p.brick_fall_enabled, fall_speed = p.brick_fall_speed,
        move_enabled = p.brick_movement_enabled, move_speed = p.brick_movement_speed,
        regen_enabled = p.brick_regeneration_enabled, regen_time = p.brick_regeneration_time,
        ...
    }, collision_check)
end
```

**What space_shooter should become:**
```lua
function SpaceShooter:updateEnemies(dt)
    self.enemies = self.entity_controller:getEntities()
    self.entity_controller:updateBehaviors(dt, {
        -- Standard movement patterns handled by PatternMovement
        pattern_movement = true,
        -- Grid movement for Space Invaders mode
        grid_unit_movement = self.params.spawn_mode == "grid" and {...} or nil,
        -- Shooting behavior
        shooting_enabled = self.params.enemy_bullets_enabled,
        shoot_rate = self.params.enemy_shoot_rate,
        on_shoot = function(enemy) self:enemyShoot(enemy) end,
        -- Remove when off screen
        remove_offscreen = {bottom = self.game_height + 50}
    })
end
```

12 lines instead of 200.

### Steps

3.1. Add ALL enemy movement patterns to EntityController.updateBehaviors():
     - pattern_movement (dispatches to PatternMovement based on entity.movement_pattern)
     - formation_movement (Galaga in-formation behavior)
     - diving behavior (Galaga dive attacks)
3.2. DELETE updateEnemies() - replace with 12-line version above
3.3. DELETE updateSpaceInvadersGrid() - grid_unit_movement behavior already exists
3.4. DELETE updateGalagaFormation() - use formation_movement + diving behaviors
3.5. DELETE all inline movement calculations

### Lines Deleted
- updateEnemies(): **~100 lines DELETED**
- updateSpaceInvadersGrid(): **~50 lines DELETED**
- updateGalagaFormation(): **~50 lines DELETED**
- **Total: ~200 lines DELETED**

### Testing (User)
- [ ] Enemies move with correct patterns
- [ ] Space Invaders grid works
- [ ] Galaga formation works
- [ ] Galaga diving works
- [ ] Enemy shooting works

### AI Notes
(To be filled after completion)

---

## Phase 4: DELETE Collision/Damage Handling (~150 lines deleted)

**What we're deleting:**
- Inline collision detection in fixedUpdate()
- handlePlayerDamage()
- onEnemyDestroyed() complexity
- All bullet/enemy collision code

**What breakout does:**
```lua
-- In updateGameLogic:
self.projectile_system:checkCollisions(self.bricks, function(_, brick)
    if brick.alive then self.entity_controller:hitEntity(brick, damage, _) end
end, "player")

self:handleEntityDepleted(function() return TableUtils.countActive(self.balls) end, {
    loss_counter = "balls_lost", combo_reset = true, damage_reason = "ball_lost",
    on_respawn = function(g) g:spawnBall() end
})

-- Callback:
function Breakout:onBrickDestroyed(brick)
    self:handleEntityDestroyed(brick, {
        destroyed_counter = "bricks_destroyed",
        remaining_counter = "bricks_left",
        spawn_powerup = true,
        effects = {particles = true, shake = 0.15},
        scoring = {base = "brick_score_multiplier", combo_mult = "combo_multiplier"},
        ...
    })
end
```

### Steps

4.1. DELETE inline collision code - use projectile_system:checkCollisions()
4.2. DELETE handlePlayerDamage() - use handleEntityDepleted()
4.3. DELETE onEnemyDestroyed() complexity - use handleEntityDestroyed()
4.4. DELETE scoring/combo inline code - handled by handleEntityDestroyed()
4.5. Move all collision to updateGameLogic() using breakout pattern

### Lines Deleted
- Inline collision: **~60 lines DELETED**
- handlePlayerDamage(): **~20 lines DELETED**
- onEnemyDestroyed(): **~40 lines DELETED**
- Scoring/combo: **~30 lines DELETED**
- **Total: ~150 lines DELETED**

### Testing (User)
- [ ] Player bullets hit enemies
- [ ] Enemy bullets hit player
- [ ] Player death works
- [ ] Score/combo works
- [ ] Effects trigger

### AI Notes
(To be filled after completion)

---

## Phase 5: DELETE Spawning Functions (~150 lines deleted)

**What we're deleting:**
- spawnEnemy() complexity
- spawnVariantEnemy()
- spawnGalagaEnemy()
- initSpaceInvadersGrid()
- initGalagaFormation()
- All inline spawn logic

**What breakout does:**
```lua
function Breakout:generateBricks()
    self.entity_controller:clear()
    self.entity_controller:spawnLayout("brick", p.brick_layout, {...})
    self.bricks = self.entity_controller:getEntities()
    self.bricks_left = #self.bricks
end
```

**What space_shooter should become:**
```lua
function SpaceShooter:spawnWave()
    if self.params.spawn_mode == "grid" then
        self.entity_controller:spawnLayout("enemy", "grid", {...})
    elseif self.params.spawn_mode == "formation" then
        self.entity_controller:spawnLayout("enemy", "formation", {...})
    else
        self.entity_controller:spawn("enemy", x, y, {...})
    end
    self.enemies = self.entity_controller:getEntities()
end
```

### Steps

5.1. DELETE spawnEnemy() - inline into continuous spawn timer
5.2. DELETE spawnVariantEnemy() - use spawnWeighted() directly
5.3. DELETE spawnGalagaEnemy() - use spawnLayout("formation") + buildPath()
5.4. DELETE initSpaceInvadersGrid() - use spawnLayout("grid")
5.5. DELETE initGalagaFormation() - use spawnLayout("formation")
5.6. Consolidate to ONE spawnWave() function

### Lines Deleted
- spawnEnemy(): **~40 lines DELETED**
- spawnVariantEnemy(): **~25 lines DELETED**
- spawnGalagaEnemy(): **~50 lines DELETED**
- initSpaceInvadersGrid(): **~15 lines DELETED**
- initGalagaFormation(): **~20 lines DELETED**
- **Total: ~150 lines DELETED**

### Testing (User)
- [ ] Continuous spawn mode works
- [ ] Wave spawn mode works
- [ ] Grid (Space Invaders) spawn works
- [ ] Formation (Galaga) spawn works
- [ ] Variant enemies spawn correctly

### AI Notes
(To be filled after completion)

---

## Phase 6: DELETE Remaining Cruft (~150 lines deleted)

**What we're deleting:**
- Asteroid/meteor specific functions
- Mode-specific helper functions
- Unused state variables
- Legacy compatibility code
- Anything not in breakout pattern

### Steps

6.1. DELETE updateAsteroids() - use updateBehaviors() with asteroid pattern
6.2. DELETE spawnMeteor()/updateMeteors() - use entity_controller
6.3. DELETE all getXxxState() lazy init functions - init in setupEntities()
6.4. DELETE helper functions that wrap single component calls
6.5. DELETE any remaining inline logic

### Lines Deleted
- Asteroid functions: **~50 lines DELETED**
- Meteor functions: **~30 lines DELETED**
- State getters: **~30 lines DELETED**
- Helper wrappers: **~20 lines DELETED**
- Misc cruft: **~20 lines DELETED**
- **Total: ~150 lines DELETED**

### Testing (User)
- [ ] Asteroids mode works
- [ ] All game modes playable
- [ ] No console errors

### AI Notes
(To be filled after completion)

---

## Summary

### Total Lines DELETED From Space Shooter

| Phase | What | Lines Deleted |
|-------|------|---------------|
| 1 | Parameter initialization | ~200 |
| 2 | Component setup | ~150 |
| 3 | updateEnemies/grid/formation | ~200 |
| 4 | Collision/damage handling | ~150 |
| 5 | Spawning functions | ~150 |
| 6 | Remaining cruft | ~150 |
| **Total** | | **~1000 lines** |

### Result

- **Before:** ~1329 lines
- **After:** ~300-400 lines
- **Same as breakout:** YES

### Target File Structure (like breakout)

```lua
-- space_shooter.lua (~300-400 lines)

init()                  ~20 lines
setupComponents()       ~50 lines
setupEntities()         ~15 lines
createPlayer()          ~15 lines
spawnWave()             ~20 lines
updateGameLogic()       ~50 lines
updatePlayer()          ~30 lines
updateEnemies()         ~15 lines
onEnemyDestroyed()      ~15 lines
keypressed()            ~15 lines
draw()                  ~5 lines
-- Mode-specific helpers ~50 lines (Galaga entrance paths, etc.)
```

---

## Verification

After ALL phases complete:
- [ ] File is under 400 lines
- [ ] Uses SchemaLoader.load()
- [ ] Uses createXxxFromSchema() for all components
- [ ] Uses handleEntityDestroyed() / handleEntityDepleted()
- [ ] Uses Physics.checkCollisions() for all collision
- [ ] Uses entity_controller:updateBehaviors() for entity logic
- [ ] NO inline collision code
- [ ] NO inline scoring code
- [ ] NO inline movement calculations
- [ ] Matches breakout.lua patterns exactly
