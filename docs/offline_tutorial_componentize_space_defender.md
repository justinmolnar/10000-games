# Offline Tutorial: Componentize Space Defender

## Goal
Refactor Space Defender from legacy code to use the game components system. This is the most challenging tutorial but teaches the architecture deeply.

## Difficulty: Hard (4-6 hours)

## Files to Study First

**The target (what you're refactoring):**
- `src/states/space_defender_state.lua` - Legacy game (~700 lines)

**The pattern to follow:**
- `src/games/space_shooter.lua` - Similar game using components
- `src/games/base_game.lua` - Base class all minigames extend

**The components you'll use:**
- `src/utils/game_components/entity_controller.lua` - Enemy spawning
- `src/utils/game_components/projectile_system.lua` - Bullets
- `src/utils/game_components/lives_health_system.lua` - Player health
- `src/utils/game_components/scoring_system.lua` - Score/tokens
- `src/utils/game_components/hud_renderer.lua` - UI display

---

## Understanding the Current Structure

Space Defender is a **standalone state**, not a minigame. It:
- Has its own state file (not using BaseGame)
- Manages its own enemy spawning
- Has custom bullet handling
- Loads levels from JSON
- Has boss fights

The minigames:
- Extend BaseGame
- Use EntityController for enemies
- Use ProjectileSystem for bullets
- Use SchemaLoader for variants
- Have separate view files

---

## Strategy: Incremental Refactoring

Don't rewrite everything at once. Replace one system at a time:

1. **Phase 1:** Extract player handling → LivesHealthSystem
2. **Phase 2:** Extract bullets → ProjectileSystem
3. **Phase 3:** Extract enemies → EntityController
4. **Phase 4:** Extract scoring → ScoringSystem
5. **Phase 5:** Extract HUD → HUDRenderer
6. **Phase 6:** Consider converting to BaseGame minigame (optional)

---

## Phase 1: LivesHealthSystem

### Step 1.1: Find Current Lives Handling

Search `space_defender_state.lua` for:
- `self.lives`
- `self.health`
- `self.invincible`
- Where damage is taken
- Where lives are displayed

### Step 1.2: Add the Component

At the top of the file, add:
```lua
local LivesHealthSystem = require('src.utils.game_components.lives_health_system')
```

In the init/setup function, create the component:
```lua
self.health_system = LivesHealthSystem:new({
    mode = "lives",  -- or "health" if it uses HP
    starting_lives = 3,
    max_lives = 5,
    invincibility_duration = 2.0,
    on_death = function()
        self:onPlayerDeath()
    end,
    on_damage = function(amount, source)
        self:onPlayerDamaged(amount, source)
    end
})
```

### Step 1.3: Replace Direct Access

Find all `self.lives` references and replace:

**Before:**
```lua
self.lives = self.lives - 1
if self.lives <= 0 then
    self:gameOver()
end
```

**After:**
```lua
self.health_system:takeDamage(1, "enemy_collision")
-- Death handling happens in on_death callback
```

**Before:**
```lua
if self.invincible then return end
```

**After:**
```lua
if self.health_system:isInvincible() then return end
```

### Step 1.4: Update the Draw

**Before:**
```lua
love.graphics.print("Lives: " .. self.lives, 10, 10)
```

**After:**
```lua
love.graphics.print("Lives: " .. self.health_system.lives, 10, 10)
```

### Step 1.5: Test

Run the game, play Space Defender, verify:
- Lives display correctly
- Taking damage works
- Invincibility after hit works
- Game over triggers correctly

---

## Phase 2: ProjectileSystem

### Step 2.1: Find Current Bullet Handling

Search for:
- `self.bullets` or `self.player_bullets`
- `self.enemy_bullets`
- Bullet creation code
- Bullet update loop
- Bullet collision checks
- Bullet rendering

### Step 2.2: Add the Component

```lua
local ProjectileSystem = require('src.utils.game_components.projectile_system')
```

Create for player bullets:
```lua
self.player_projectiles = ProjectileSystem:new({
    max_projectiles = 50,
    projectile_speed = 500,
    projectile_size = {width = 4, height = 10},
    fire_rate = 0.15,  -- seconds between shots
    direction = -1,    -- up
    on_hit = function(projectile, target)
        self:onPlayerBulletHit(projectile, target)
    end
})
```

Create for enemy bullets:
```lua
self.enemy_projectiles = ProjectileSystem:new({
    max_projectiles = 100,
    projectile_speed = 300,
    projectile_size = {width = 6, height = 6},
    direction = 1,  -- down
    on_hit = function(projectile, target)
        self:onEnemyBulletHit(projectile, target)
    end
})
```

### Step 2.3: Replace Firing Code

**Before:**
```lua
function SpaceDefender:playerShoot()
    table.insert(self.bullets, {
        x = self.player.x,
        y = self.player.y - 10,
        speed = 500
    })
end
```

**After:**
```lua
function SpaceDefender:playerShoot()
    self.player_projectiles:fire(self.player.x, self.player.y - 10)
end
```

### Step 2.4: Replace Update Loop

**Before:**
```lua
for i = #self.bullets, 1, -1 do
    local b = self.bullets[i]
    b.y = b.y - b.speed * dt
    if b.y < 0 then
        table.remove(self.bullets, i)
    end
end
```

**After:**
```lua
self.player_projectiles:update(dt)
self.enemy_projectiles:update(dt)
```

### Step 2.5: Handle Collision

The component can check collisions for you:
```lua
-- Check player bullets against enemies
local hits = self.player_projectiles:checkCollisions(self.enemies)
for _, hit in ipairs(hits) do
    self:damageEnemy(hit.target, hit.projectile)
end

-- Check enemy bullets against player
if self.enemy_projectiles:checkPoint(self.player.x, self.player.y, self.player.width) then
    self.health_system:takeDamage(1, "enemy_bullet")
end
```

---

## Phase 3: EntityController

This is the most complex component. Study `space_shooter.lua` carefully.

### Step 3.1: Understand Entity Types

EntityController manages multiple entity types. Define them:

```lua
self.entity_controller = EntityController:new({
    entity_types = {
        basic_enemy = {
            speed = 100,
            health = 1,
            score = 100,
            sprite = "enemy_basic"
        },
        fast_enemy = {
            speed = 200,
            health = 1,
            score = 150,
            sprite = "enemy_fast"
        },
        tank_enemy = {
            speed = 50,
            health = 3,
            score = 300,
            sprite = "enemy_tank"
        }
    },
    spawning = {
        mode = "wave",  -- or "continuous"
        spawn_area = {x = 0, y = -50, width = screen_width, height = 1}
    },
    bounds = {
        x = 0, y = 0,
        width = screen_width,
        height = screen_height
    },
    on_spawn = function(entity) end,
    on_destroy = function(entity, reason)
        if reason == "killed" then
            self.score = self.score + entity.score
        end
    end
})
```

### Step 3.2: Define Waves

If Space Defender uses waves, configure them:

```lua
local waves = {
    {
        enemies = {
            {type = "basic_enemy", count = 5, delay = 0.5}
        },
        delay_after = 3
    },
    {
        enemies = {
            {type = "basic_enemy", count = 3, delay = 0.3},
            {type = "fast_enemy", count = 2, delay = 0.5}
        },
        delay_after = 3
    }
}
self.entity_controller:setWaves(waves)
```

### Step 3.3: Replace Enemy Loops

**Before:**
```lua
for i, enemy in ipairs(self.enemies) do
    enemy.y = enemy.y + enemy.speed * dt
    -- collision checks, etc.
end
```

**After:**
```lua
self.entity_controller:update(dt)
local enemies = self.entity_controller:getActiveEntities()
-- Collision checks use enemies list
```

---

## Phase 4: ScoringSystem

```lua
local ScoringSystem = require('src.utils.game_components.scoring_system')

self.scoring = ScoringSystem:new({
    base_score = 0,
    multiplier = 1.0,
    combo_enabled = true,
    combo_timeout = 2.0,
    token_formula = function(score, time, metrics)
        return math.floor(score / 100)
    end
})
```

**Replace:**
```lua
self.score = self.score + 100
```

**With:**
```lua
self.scoring:addScore(100, "enemy_kill")
```

---

## Phase 5: HUDRenderer

```lua
local HUDRenderer = require('src.utils.game_components.hud_renderer')

self.hud = HUDRenderer:new({
    primary = {label = "Score", key = "score"},
    secondary = {label = "Wave", key = "current_wave"},
    lives = {key = "lives", max = 5, style = "ships"}
})
self.hud.game = self  -- HUD reads from game object
```

Replace manual HUD drawing with:
```lua
self.hud:draw(viewport_width, viewport_height)
```

---

## Phase 6: Convert to BaseGame (Optional, Advanced)

If you want Space Defender to be a minigame in the launcher:

### Step 6.1: Create New Files

- `src/games/space_defender.lua` - Game logic
- `src/games/views/space_defender_view.lua` - Rendering
- `assets/data/schemas/space_defender_schema.json` - Parameters
- `assets/data/variants/space_defender_variants.json` - Variants

### Step 6.2: Extend BaseGame

```lua
local BaseGame = require('src.games.base_game')
local SpaceDefender = BaseGame:extend('SpaceDefender')

function SpaceDefender:init(game_data, cheats, di, variant_override)
    SpaceDefender.super.init(self, game_data, cheats, di, variant_override)

    self.params = SchemaLoader.load(self.variant, "space_defender_schema", runtimeCfg)
    self:applyModifiers()
    self:setupGameState()
    self:setupComponents()

    self.view = SpaceDefenderView:new(self)
end
```

### Step 6.3: Register in Game Registry

Add to `src/models/game_registry.lua`:
```lua
space_defender = {
    class = require('src.games.space_defender'),
    name = "Space Defender",
    -- ...
}
```

---

## Testing Strategy

After each phase:

1. **Run the game**
2. **Play Space Defender**
3. **Verify the refactored system works:**
   - Phase 1: Lives/damage/invincibility
   - Phase 2: Shooting/bullet collision
   - Phase 3: Enemy spawning/waves
   - Phase 4: Score accumulation
   - Phase 5: HUD display

4. **Check for regressions** - did anything break?

---

## Debugging Tips

### Component not working?
```lua
-- Add debug prints in component callbacks
on_spawn = function(entity)
    print("Spawned:", entity.type, "at", entity.x, entity.y)
end
```

### Entities not appearing?
Check:
- Spawn area bounds
- Entity speed/direction
- Bounds for removal

### Bullets not hitting?
Check:
- Collision detection bounds
- Whether checkCollisions is called
- Target list format

---

## Reference: Component API Quick Reference

### LivesHealthSystem
```lua
:takeDamage(amount, source)
:heal(amount)
:addLife()
:isAlive()
:isInvincible()
.lives, .health, .max_health
```

### ProjectileSystem
```lua
:fire(x, y, [direction], [speed])
:update(dt)
:checkCollisions(targets) -> hits[]
:checkPoint(x, y, radius) -> bool
:draw()
.active_projectiles
```

### EntityController
```lua
:update(dt)
:spawn(type, x, y)
:getActiveEntities()
:destroyEntity(entity, reason)
:startWave(wave_number)
```

### ScoringSystem
```lua
:addScore(amount, source)
:getScore()
:getTokens()
:resetCombo()
```

### HUDRenderer
```lua
:draw(width, height)
:setVMMode(bool)
```

---

## Common Issues

| Problem | Solution |
|---------|----------|
| "attempt to index nil" | Component not initialized - check :new() call |
| Enemies spawn off-screen | Check spawn_area bounds |
| Bullets don't collide | Check collision bounds match visual size |
| Score not updating | Verify scoring:addScore is called |
| HUD shows nil | Ensure hud.game is set and keys match properties |

## Key Patterns Learned

- **Incremental refactoring:** Replace one system at a time
- **Component composition:** Build complex behavior from simple parts
- **Callback pattern:** Components call your functions for game-specific logic
- **Separation of concerns:** Components handle mechanics, game handles rules
