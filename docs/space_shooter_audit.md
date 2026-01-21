# Space Shooter Function Audit

**Current size:** 1412 lines (42 functions)
**Target size:** 200-300 lines
**Comparison:** Breakout went from 2000 → 300 lines

---

## Part 1: What Each Function Does

### Setup Functions (lines 5-170)

- **init** (5-26): Loads schema params, applies cheats, calls 4 setup functions, creates view
- **setupArena** (28-53): Sets arena size, spawns N gravity wells at random positions, spawns N blackout zones at random positions
- **setupPlayer** (55-70): Creates player at bottom (or top if reverse gravity), initializes 15+ extra properties for firing modes
- **setupComponents** (72-109): Creates 7 components from schema + manual overrides for movement/projectiles/entities
- **setupGameState** (111-135): Initializes 10+ game counters (timers, kills, deaths, enemy composition)
- **getWaveState** (138-147): Lazy-creates wave spawning state object
- **getGridState** (149-158): Lazy-creates Space Invaders grid state object
- **getGalagaState** (160-170): Lazy-creates Galaga formation state object
- **loadAssets** (173-190): Loads sprites for player and enemy types via spriteSetLoader
- **setPlayArea** (192-224): Resizes arena, repositions player, recalculates Galaga formation

### Main Update Loop (lines 226-446)

- **updateGameLogic** (226-331): Master update - calls 15+ sub-updates, syncs entity arrays, handles spawning modes
- **updatePlayer** (333-378): Movement via MovementController, firing via ProjectileSystem, ammo reload, overheat cooldown
- **updateEnemies** (381-421): Updates enemy movement patterns, handles player-enemy collision, triggers enemy shooting
- **updateBullets** (423-446): Sets homing targets, checks bullet-enemy and bullet-player collisions, screen wrap

### Drawing (lines 448-454)

- **draw** (448-454): Delegates to view

### Shooting (lines 456-562)

- **playerShoot** (456-519): Checks ammo/overheat, calculates spawn position, fires bullet pattern via ProjectileSystem
- **getBulletSpawnPosition** (521-536): Calculates where bullets spawn based on movement type (asteroids vs normal)
- **convertToStandardAngle** (538-542): Converts angle for bullet direction based on reverse gravity
- **enemyShoot** (544-562): Enemy fires bullet pattern via ProjectileSystem

### Enemy Spawning (lines 565-805)

- **calculateEnemyHealth** (565-589): Calculates enemy health with variance/range and type multiplier
- **spawnEnemy** (591-633): Main enemy spawn - checks for variant enemies, formations, or spawns basic enemy
- **hasVariantEnemies** (636-638): Returns true if variant has enemy composition defined
- **spawnVariantEnemy** (641-700): Weighted random selection from variant enemy composition, spawns with type-specific properties
- **spawnFormation** (764-805): Spawns V, wall, or spiral formation of enemies

### Damage & Victory (lines 702-761)

- **handlePlayerDamage** (702-716): Shield absorption via health_system, updates deaths counter
- **onEnemyDestroyed** (718-725): Updates kills counter via handleEntityDestroyed, plays sound
- **checkComplete** (727-736): Delegates to VictoryCondition component
- **onComplete** (739-755): Plays victory/death sound, stops music, calls parent
- **keypressed** (757-761): Passes key to parent for demo tracking

### Space Invaders Mode (lines 808-938)

- **initSpaceInvadersGrid** (808-840): Creates grid of enemies with wave-scaled difficulty
- **updateSpaceInvadersGrid** (843-938): Updates grid movement via EntityController behavior, handles grid shooting

### Galaga Mode (lines 941-1165)

- **initGalagaFormation** (941-983): Creates formation slot positions with automatic row wrapping
- **spawnGalagaEnemy** (986-1031): Spawns enemy with bezier entrance path to formation slot
- **updateGalagaFormation** (1034-1165): Manages formation spawning, dive attacks, bezier movement

### Wave Spawning (lines 1168-1214)

- **updateWaveSpawning** (1168-1194): Timer-based wave spawning with pause between waves
- **updateDifficulty** (1197-1214): Linear/exponential/wave difficulty scaling

### Environmental Hazards (lines 1217-1410)

- **updateAsteroids** (1217-1271): Spawns asteroids on timer, moves them, handles all collision types
- **spawnAsteroid** (1273-1282): Creates single asteroid with random size/rotation
- **updateMeteors** (1285-1330): Meteor shower system - warnings then spawn
- **spawnMeteorWave** (1332-1340): Spawns 3-5 meteor warnings
- **applyGravityWells** (1343-1359): Applies gravity well force to player and bullets
- **updateScrolling** (1362-1367): Increments scroll_offset
- **applyScreenWrap** (1371-1392): Screen wrap helper with max wrap limit
- **updateBlackoutZones** (1395-1410): Moves blackout zones, bounces off walls

---

## Part 2: Functions Replaceable with EXISTING Components

### Already using components well:
- **setupComponents** - Uses createComponentsFromSchema, createProjectileSystemFromSchema, etc.
- **updatePlayer movement** - Uses MovementController
- **updatePlayer firing** - Uses ProjectileSystem.updateFireMode
- **updateBullets** - Uses ProjectileSystem.checkCollisions
- **checkComplete** - Uses VictoryCondition
- **handlePlayerDamage** - Uses LivesHealthSystem

### Can be replaced NOW with existing components:

| Function | Replacement | Savings |
|----------|-------------|---------|
| **applyGravityWells** | PhysicsUtils.applyGravityWell already used - but inline bounds check should use MovementController.clampToBounds | ~5 lines |
| **applyScreenWrap** | PhysicsUtils.wrapPosition already used - function is just a wrapper, inline it | ~15 lines |
| **updateScrolling** | Trivial 2-line function - inline into updateGameLogic | ~5 lines |
| **calculateEnemyHealth** | EntityController should handle health variance via schema config | ~20 lines |
| **hasVariantEnemies** | Inline the one-liner | ~3 lines |

### Can be heavily simplified with existing components:

| Function | Current | With Components |
|----------|---------|-----------------|
| **updateAsteroids** (55 lines) | Manual spawn timer, movement, 3 collision types | EntityController with behaviors: `spawn_timer`, `linear_movement`, `remove_offscreen`, collision callback |
| **updateMeteors** (46 lines) | Manual timer, warnings, spawn, movement, collision | Same as asteroids + warning system as behavior |
| **updateBlackoutZones** (16 lines) | Manual movement with bounce | PhysicsUtils.bounceOffWalls or MovementController with bounds bounce mode |
| **spawnAsteroid** (10 lines) | Manual spawn | EntityController.spawn with size variance in schema |
| **spawnMeteorWave** (9 lines) | Manual loop | EntityController batch spawn |

---

## Part 3: Functions to ABSTRACT into Game Components

### HIGH PRIORITY - Use/Enhance EXISTING Components

#### 1. **Layouts** → Enhance EntityController.spawnLayout
Already exists with: grid, pyramid, circle, random, checkerboard
**Add:** v_shape, wall, spiral, line

Space Shooter's "formations" are just LAYOUTS. No game-specific logic needed.
Galaga entrance animations = PatternMovement.updateBezier (already exists)
Galaga dive attacks = game logic, stays in game
Galaga respawning = game logic, stays in game

```lua
-- Space Shooter USES existing:
self.entity_controller:spawnLayout("enemy", "v_shape", {
    count = 5, spacing = 60, x = 400, y = -30
})
```

**Savings:** ~40 lines of spawnFormation code

#### 2. **Grouped Movement** → Add behavior to EntityController
Entities with same group_id move together. Bounce on bounds optional.
NOT "Space Invaders grid" - generic grouped movement.

```lua
-- In entity_controller behaviors:
group_movement = {
    group_id = "formation_1",
    bounce_on_bounds = true,
    descent_on_bounce = 20
}
```

Use cases: Space Invaders grid, ASCII art ship in Dodge, convoy, flock, anything.

**Savings:** ~100 lines of grid movement code

#### 3. **Wave/Spawn System** → Enhance EntityController
Used by: updateWaveSpawning, spawn timer logic in updateGameLogic
**Current:** 40+ lines scattered
**Pattern:** Timer-based spawning, wave pause, difficulty scaling

```lua
-- Already have spawn_mode="timer" in PowerupSystem
-- EntityController needs same pattern:
spawn_timer = {
    mode = "continuous" | "waves" | "clusters",
    rate = 1.0,
    wave_size = 10,
    wave_pause = 3.0,
    cluster_size = {3, 5}
}
```

**Savings:** ~40 lines

#### 4. **Difficulty Scaling** → Utility function, NOT a component
18 lines. Just a math function. Add to PhysicsUtils or inline.

```lua
-- PhysicsUtils.scaleDifficulty(time, curve, rate, max)
-- Returns multiplier. Games apply it themselves.
```

**Savings:** ~10 lines (move function, use it)

#### 5. **Zones with Effects** → Already exists, just USE it
- PhysicsUtils.applyGravityWell already exists
- PhysicsUtils.bounceInBounds for moving zones
- Blackout = visual only, stays in view
- Just need to store zone data and loop over it

**Savings:** ~20 lines (remove redundant code, use existing functions)

#### 6. **Ammo/Reload/Overheat** → Enhance ProjectileSystem
Generic shooter mechanics. Any game could use ammo limits or weapon heat.

```lua
-- In ProjectileSystem config:
ammo = {enabled = true, capacity = 30, reload_time = 2.0},
heat = {enabled = true, max = 10, cooldown = 3.0, dissipation = 1.0}
```

**Savings:** ~40 lines

### MEDIUM PRIORITY

#### 7. **Weighted Random Spawn** → Enhance EntityController
Generic pattern: pick from weighted list of types.
Not "enemy composition" - just weighted random from any type list.

```lua
-- EntityController.spawnWeightedRandom(types_with_weights)
entity_controller:spawnWeightedRandom({
    {type = "enemy", subtype = "basic", weight = 1.0},
    {type = "enemy", subtype = "fast", weight = 0.3, speed_mult = 2.0}
}, x, y)
```

**Savings:** ~50 lines

#### 8. **Direction Multiplier** → Components respect direction flag
Instead of `if reverse_gravity then` everywhere, components check `params.direction` or `params.y_direction = -1`.
PatternMovement, EntityController spawn positions, etc. all multiply by direction.

**Savings:** ~20 lines, much cleaner code

---

## Part 4: Extraction Priority

### Phase 1: USE Existing Components (~200 lines saved)
- EntityController.spawnLayout already exists - USE IT for formations
- EntityController wave/continuous spawn modes exist - USE THEM
- PatternMovement.updateBezier exists - USE IT for entrance paths
- PhysicsUtils.applyGravityWell exists - loop over zones, call it
- DELETE the 400+ lines of redundant code

### Phase 2: Add Missing Layouts (~40 lines of component code)
- Add to EntityController.spawnLayout: v_shape, wall, spiral, line
- These are just position math, ~10 lines each

### Phase 3: Add group_movement Behavior (~30 lines of component code)
- Entities with same group_id share velocity
- Bounce on bounds, optional descent
- DELETE 100+ lines of Space Invaders grid code

### Phase 4: Add Ammo/Heat to ProjectileSystem (~40 lines of component code)
- Generic shooter mechanics
- DELETE 40+ lines from Space Shooter

### Phase 5: Add Weighted Random Spawn (~20 lines of component code)
- Generic pattern for entity type selection
- DELETE 60+ lines from Space Shooter

---

## Summary

**Key insight:** Most of Space Shooter's code is REINVENTING what components already do.

| What | Current | After |
|------|---------|-------|
| Formations (v, wall, spiral) | ~40 lines | `spawnLayout("v_shape", ...)` - 1 line |
| Galaga entrance paths | ~60 lines | `PatternMovement.updateBezier()` - already exists |
| Space Invaders grid init | ~40 lines | `spawnLayout("grid", ...)` - 1 line |
| Space Invaders grid movement | ~100 lines | `group_movement` behavior - 1 line config |
| Wave spawning | ~30 lines | EntityController wave mode - already exists |
| Continuous spawning | ~20 lines | EntityController continuous mode - already exists |
| Gravity wells | ~20 lines | `PhysicsUtils.applyGravityWell()` loop - 5 lines |
| Ammo/reload | ~25 lines | ProjectileSystem handles it - 0 lines |
| Overheat | ~20 lines | ProjectileSystem handles it - 0 lines |
| Weighted enemy types | ~60 lines | `spawnWeightedRandom()` - 1 line |

**Game-specific logic that stays (~200 lines):**
- init, view setup
- Galaga dive attack logic (when to dive, target selection)
- Galaga respawn logic
- Game-specific sounds
- Victory/loss handling
- Anything truly unique (there's not much)
