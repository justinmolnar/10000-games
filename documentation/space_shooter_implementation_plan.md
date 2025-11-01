# Space Shooter Implementation Plan
**Comprehensive Phased Action Plan for Complete Variant System**

---

## Executive Summary

This plan implements **50+ variant parameters** for Space Shooter, transforming it from a 504-line skeleton into a fully-featured game comparable to Snake (2,783 lines) and Dodge (2,152 lines).

**Scope**: Player movement systems, weapon systems, enemy AI, environmental hazards, power-ups, difficulty scaling, and victory conditions.

**Architecture Alignment**: Follows DI pattern, MVC separation, variant override pattern, config fallbacks, CheatEngine integration, and scaling_constant usage.

**Estimated Final Size**: ~2,000-2,500 lines (4-5x current size)

---

## Architecture Foundations (Critical Reading)

### Existing Pattern Analysis

From studying Snake/Dodge/Memory implementations:

1. **Parameter Loading Pattern** (Lines 13-200 of snake_game.lua):
```lua
-- Three-tier fallback system:
self.parameter_name = (runtimeCfg and runtimeCfg.parameter_name) or DEFAULT_CONSTANT
if self.variant and self.variant.parameter_name ~= nil then
    self.parameter_name = self.variant.parameter_name
end
```

2. **Scaling Constant Integration**:
   - Used in formulas: `base_value * scaling_constant`
   - Lives in config.lua, upgradeable globally
   - Applied to token generation formulas in base_game_definitions.json

3. **CheatEngine Integration**:
   - Parameter ranges defined in `config.lua` → `cheat_engine.parameter_ranges`
   - Locked parameters listed in `cheat_engine.hidden_parameters`
   - Each game in base_game_definitions.json defines `available_cheats` with costs/max_levels

4. **Variant JSON Structure**:
   - Stored in assets/data/variants/{game}_variants.json
   - Each variant has difficulty_modifier, enemies array, palette, sprite_set
   - Parameters override defaults for that specific clone

### Space Shooter Current State

**Existing Code** (504 lines):
- ✅ BaseGame inheritance
- ✅ Basic movement (left/right WASD)
- ✅ Basic shooting (space bar, single bullets)
- ✅ Enemy spawning (basic types: basic, weaver, bomber, kamikaze)
- ✅ Enemy types defined in ENEMY_TYPES table
- ✅ Lives system (PLAYER_MAX_DEATHS_BASE)
- ✅ Collision detection
- ✅ Victory condition (target kills)
- ✅ Asset loading scaffolding
- ✅ View separation (space_shooter_view.lua)

**Missing** (what this plan adds):
- ❌ Movement type variations (rail, asteroids, jump)
- ❌ Advanced weapon systems (patterns, homing, piercing, etc.)
- ❌ Power-up system
- ❌ Environmental hazards (asteroids, gravity wells, etc.)
- ❌ Shield mechanics
- ❌ Ammo/overheat systems
- ❌ Bullet variations (speed, pattern, gravity, etc.)
- ❌ Victory condition variations (time-based, survival, etc.)
- ❌ Screen wrap, reverse gravity, blackout zones
- ❌ Difficulty curves
- ❌ 95% of the variant parameters

---

## Phase Breakdown

### Phase 1: Foundation & Architecture (Days 1-2)
**Goal**: Set up config structure, constants, parameter loading skeleton

### Phase 2: Player Movement Systems (Days 3-4)
**Goal**: Implement movement_type variations (default, jump, rail, asteroids)

### Phase 3: Weapon Systems - Core (Days 5-7)
**Goal**: Fire modes, bullet patterns, bullet behavior modifiers

### Phase 4: Weapon Systems - Advanced (Days 8-9)
**Goal**: Ammo, overheat, gravity, special mechanics

### Phase 5: Enemy Systems (Days 10-11)
**Goal**: Spawn patterns, formations, bullet behavior, scaling

### Phase 6: Power-Up System (Days 12-13)
**Goal**: Power-up spawning, types, duration, stacking

### Phase 7: Environmental Hazards (Days 14-15)
**Goal**: Asteroids, meteors, gravity wells, scroll speed

### Phase 8: Special Mechanics & Victory (Days 16-17)
**Goal**: Screen wrap, reverse gravity, blackout zones, victory conditions

### Phase 9: Shield & Lives Systems (Day 18)
**Goal**: Shield mechanics, regeneration, lives management

### Phase 10: Arena & Visuals (Day 19)
**Goal**: Arena width/aspect ratio locking, visual modifiers

### Phase 11: CheatEngine Integration (Days 20-21)
**Goal**: Parameter ranges, available_cheats definitions

### Phase 12: Variant JSON Creation (Days 22-24)
**Goal**: Create 15-20 unique variants with interesting parameter combinations

### Phase 13: Testing & Balancing (Days 25-27)
**Goal**: Test all variants, balance formulas, fix edge cases

### Phase 14: Documentation (Day 28)
**Goal**: Document all parameters, create variant guide

---

## PHASE 1: Foundation & Architecture

### Duration: 2 days

### 1.1: Config Constants Setup

**File**: `src/config.lua`

Add to `Config.games.space_shooter` section (create if doesn't exist):

```lua
space_shooter = {
    -- Player Movement Defaults
    player = {
        width = 30,
        height = 30,
        speed = 200,                -- base_movement_speed (rail/default modes)
        rotation_speed = 5.0,       -- asteroids mode rotation
        accel_friction = 1.0,       -- asteroids mode acceleration
        decel_friction = 1.0,       -- asteroids mode deceleration
        start_y_offset = 50,        -- spawn position from bottom
        max_deaths_base = 5,        -- base lives
        fire_cooldown = 0.2,        -- seconds between shots
        jump_distance = 100,        -- jump mode dash distance
        jump_cooldown = 0.5,        -- jump mode cooldown
        jump_speed = 400,           -- jump mode dash speed
    },

    -- Shield Defaults
    shield = {
        enabled = false,
        regen_time = 5.0,           -- seconds to regenerate
        max_hits = 1,               -- hits before shield breaks
    },

    -- Bullet Defaults
    bullet = {
        width = 4,
        height = 8,
        speed = 400,
        gravity = 0,                -- pixels/sec^2 downward pull
        lifetime = 10,              -- seconds before despawn
        piercing = false,
        homing = false,
        homing_strength = 0.0,      -- 0-1, how aggressively bullets home
    },

    -- Weapon System Defaults
    weapon = {
        fire_mode = "manual",       -- manual, auto, charge, burst
        fire_rate = 1.0,            -- shots per second (auto mode)
        burst_count = 3,            -- bullets per burst (burst mode)
        burst_delay = 0.1,          -- seconds between burst shots
        charge_time = 1.0,          -- seconds to full charge
        pattern = "single",         -- single, double, triple, spread, spiral, wave
        spread_angle = 30,          -- degrees for spread pattern
        overheat_enabled = false,
        overheat_threshold = 10,    -- shots before overheat
        overheat_cooldown = 3.0,    -- seconds to cool down
        ammo_enabled = false,
        ammo_capacity = 50,
        ammo_reload_time = 2.0,
    },

    -- Enemy Defaults
    enemy = {
        width = 30,
        height = 30,
        base_speed = 100,
        start_y_offset = -30,
        base_shoot_rate_min = 1.0,
        base_shoot_rate_max = 3.0,
        shoot_rate_complexity_factor = 0.5,
        spawn_base_rate = 1.0,      -- seconds between spawns
        speed_multiplier = 1.0,
        bullets_enabled = true,
        bullet_speed = 200,
        formation = "scattered",    -- scattered, v_formation, wall, spiral
    },

    -- Power-up Defaults
    powerup = {
        spawn_rate = 10.0,          -- seconds between spawns
        duration = 5.0,             -- seconds power-up lasts
        stacking = false,           -- can stack multiples
        from_enemies = 0.1,         -- 10% chance on enemy kill
        types = {                   -- available types
            "weapon_upgrade",
            "shield",
            "speed",
        }
    },

    -- Environment Defaults
    environment = {
        scroll_speed = 0,           -- pixels/sec background scroll
        asteroid_density = 0,       -- asteroids per second
        meteor_frequency = 0,       -- meteor showers per minute
        gravity_wells = 0,          -- number of gravity wells
        gravity_well_strength = 200, -- pixels/sec^2 pull
    },

    -- Arena Defaults
    arena = {
        width = 800,                -- default play area width
        height = 600,
        aspect_ratio_locked = false, -- locks window aspect ratio
        screen_wrap = false,
        reverse_gravity = false,    -- player at top, enemies at bottom
        blackout_zones = 0,         -- number of vision-blocking zones
    },

    -- Victory/Difficulty Defaults
    goals = {
        base_target_kills = 20,
        victory_condition = "kills", -- kills, time, survival, boss
        victory_limit = 20,         -- varies by condition type
        difficulty_curve = "linear", -- linear, exponential, wave
        bullet_hell_mode = false,   -- tiny hitbox, massive bullet count
    },
},
```

### 1.2: Update CheatEngine Parameter Ranges

**File**: `src/config.lua` → `cheat_engine.parameter_ranges`

Add Space Shooter parameters:

```lua
-- Space Shooter Parameters
-- Player Movement
movement_speed = { min = 50, max = 600 },
rotation_speed = { min = 0.5, max = 20.0 },
accel_friction = { min = 0.0, max = 1.0 },
decel_friction = { min = 0.0, max = 1.0 },
jump_distance = { min = 20, max = 300 },
jump_cooldown = { min = 0.1, max = 3.0 },
jump_speed = { min = 100, max = 1000 },

-- Lives & Shield
lives_count = { min = 1, max = 50 },
shield_hits = { min = 0, max = 10 },
shield_regen_time = { min = 0, max = 60 },

-- Weapon System
fire_rate = { min = 0.1, max = 20.0 },
bullet_speed = { min = 50, max = 1000 },
bullet_gravity = { min = -500, max = 500 },
bullet_lifetime = { min = 1, max = 30 },
homing_strength = { min = 0.0, max = 1.0 },
burst_count = { min = 1, max = 10 },
burst_delay = { min = 0.05, max = 1.0 },
charge_time = { min = 0.1, max = 5.0 },
spread_angle = { min = 5, max = 180 },
overheat_threshold = { min = 3, max = 100 },
overheat_cooldown = { min = 0.5, max = 10.0 },
ammo_capacity = { min = 5, max = 500 },
ammo_reload_time = { min = 0.5, max = 10.0 },

-- Enemy System
enemy_spawn_rate = { min = 0.1, max = 10.0 },
enemy_speed_multiplier = { min = 0.1, max = 5.0 },
enemy_bullet_speed = { min = 50, max = 800 },
powerup_spawn_rate = { min = 1, max = 60 },
powerup_duration = { min = 1, max = 30 },

-- Environment
scroll_speed = { min = 0, max = 500 },
asteroid_density = { min = 0, max = 10 },
meteor_frequency = { min = 0, max = 10 },
gravity_wells = { min = 0, max = 10 },
gravity_well_strength = { min = 50, max = 1000 },

-- Arena
arena_width = { min = 400, max = 1200 },
blackout_zones = { min = 0, max = 5 },

-- Victory
victory_limit = { min = 1, max = 200 },
```

### 1.3: Update Hidden Parameters

**File**: `src/config.lua` → `cheat_engine.hidden_parameters`

Add Space Shooter locked parameters:

```lua
-- Space Shooter locked params
"movement_type",        -- String enum
"fire_mode",            -- String enum
"bullet_pattern",       -- String enum
"enemy_pattern",        -- String enum
"enemy_formation",      -- String enum
"victory_condition",    -- String enum
"difficulty_curve",     -- String enum
```

### 1.4: Constants File

**File**: `src/constants.lua`

Add Space Shooter enums (if not using strings directly):

```lua
-- Space Shooter Movement Types
MOVEMENT_TYPE = {
    DEFAULT = 'default',
    JUMP = 'jump',
    RAIL = 'rail',
    ASTEROIDS = 'asteroids',
}

-- Fire Modes
FIRE_MODE = {
    MANUAL = 'manual',
    AUTO = 'auto',
    CHARGE = 'charge',
    BURST = 'burst',
}

-- Bullet Patterns
BULLET_PATTERN = {
    SINGLE = 'single',
    DOUBLE = 'double',
    TRIPLE = 'triple',
    SPREAD = 'spread',
    SPIRAL = 'spiral',
    WAVE = 'wave',
}

-- Victory Conditions
VICTORY_CONDITION = {
    KILLS = 'kills',
    TIME = 'time',
    SURVIVAL = 'survival',
    BOSS = 'boss',
}
```

### 1.5: Base Game Definitions Update

**File**: `assets/data/base_game_definitions.json`

Update space_shooter_1 entry:

```json
{
  "id": "space_shooter_1",
  "display_name": "Space Shooter Alpha",
  "game_class": "SpaceShooter",
  "tier": "trash",
  "category": "action",
  "unlock_cost": 50,
  "cost_exponent": 1.5,
  "base_formula_string": "((metrics.kills * metrics.kills * 10 * scaling_constant) - (metrics.deaths * metrics.deaths * 5 * scaling_constant))",
  "metrics_tracked": ["kills", "deaths", "accuracy", "time_survived"],
  "icon_sprite": "game_mine_1-0",
  "token_threshold": 0.75,

  "cheat_engine_base_cost": 1000,
  "cheat_cost_exponent": 1.15,
  "available_cheats": [
    {
      "id": "speed_modifier",
      "display_name": "Cooldown Reduction",
      "description": "Reduce fire cooldown",
      "base_cost": 500,
      "max_level": 5,
      "value_per_level": 0.1,
      "affects": ["player.fire_cooldown"]
    },
    {
      "id": "advantage_modifier",
      "display_name": "Extra Lives",
      "description": "Increase starting lives",
      "base_cost": 1000,
      "max_level": 10,
      "value_per_level": { "deaths": 1 },
      "affects": ["lives_count"]
    },
    {
      "id": "performance_modifier",
      "display_name": "Damage Boost",
      "description": "Increase bullet damage",
      "base_cost": 2000,
      "max_level": 5,
      "value_per_level": 0.2,
      "affects": ["bullet_damage_multiplier"]
    },
    {
      "id": "bullet_speed_boost",
      "display_name": "Faster Bullets",
      "description": "Increase bullet speed",
      "base_cost": 800,
      "max_level": 5,
      "value_per_level": 100,
      "affects": ["bullet_speed"]
    },
    {
      "id": "shield_upgrade",
      "display_name": "Shield Generator",
      "description": "Enable regenerating shield",
      "base_cost": 5000,
      "max_level": 1,
      "value_per_level": 0,
      "affects": ["shield_enabled"]
    },
    {
      "id": "piercing_rounds",
      "display_name": "Piercing Bullets",
      "description": "Bullets pass through enemies",
      "base_cost": 3000,
      "max_level": 1,
      "value_per_level": 0,
      "affects": ["bullet_piercing"]
    }
  ]
}
```

---

## PHASE 2: Player Movement Systems

### Duration: 2 days

### 2.1: Movement Type Infrastructure

**File**: `src/games/space_shooter.lua` → init()

Add parameter loading (following Snake pattern):

```lua
-- Movement type system
self.movement_type = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.movement_type) or "default"
if self.variant and self.variant.movement_type then
    self.movement_type = self.variant.movement_type
end

-- Movement speed (unified for all modes)
local base_speed = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.speed) or PLAYER_SPEED
self.movement_speed = base_speed
if self.variant and self.variant.movement_speed ~= nil then
    self.movement_speed = self.variant.movement_speed
end

-- Asteroids mode physics
self.rotation_speed = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.rotation_speed) or 5.0
if self.variant and self.variant.rotation_speed ~= nil then
    self.rotation_speed = self.variant.rotation_speed
end

self.accel_friction = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.accel_friction) or 1.0
if self.variant and self.variant.accel_friction ~= nil then
    self.accel_friction = self.variant.accel_friction
end

self.decel_friction = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.decel_friction) or 1.0
if self.variant and self.variant.decel_friction ~= nil then
    self.decel_friction = self.variant.decel_friction
end

-- Jump mode parameters
self.jump_distance = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.jump_distance) or 100
if self.variant and self.variant.jump_distance ~= nil then
    self.jump_distance = self.variant.jump_distance
end

self.jump_cooldown = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.jump_cooldown) or 0.5
if self.variant and self.variant.jump_cooldown ~= nil then
    self.jump_cooldown = self.variant.jump_cooldown
end

self.jump_speed = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.jump_speed) or 400
if self.variant and self.variant.jump_speed ~= nil then
    self.jump_speed = self.variant.jump_speed
end

-- Initialize movement state
if self.movement_type == "asteroids" then
    self.player.angle = 270  -- Facing up
    self.player.vx = 0
    self.player.vy = 0
elseif self.movement_type == "jump" then
    self.player.jump_timer = 0
    self.player.is_jumping = false
end
```

### 2.2: Update Player Movement Logic

**File**: `src/games/space_shooter.lua` → updatePlayer(dt)

Replace current simple left/right with mode-based movement:

```lua
function SpaceShooter:updatePlayer(dt)
    if self.movement_type == "default" or self.movement_type == "rail" then
        -- Default: WASD free movement (default) or left/right only (rail)
        if self.movement_type == "default" then
            if self:isKeyDown('up', 'w') then self.player.y = self.player.y - self.movement_speed * dt end
            if self:isKeyDown('down', 's') then self.player.y = self.player.y + self.movement_speed * dt end
        end

        if self:isKeyDown('left', 'a') then self.player.x = self.player.x - self.movement_speed * dt end
        if self:isKeyDown('right', 'd') then self.player.x = self.player.x + self.movement_speed * dt end

        -- Clamp to screen
        self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
        if self.movement_type == "default" then
            self.player.y = math.max(0, math.min(self.game_height - self.player.height, self.player.y))
        end

    elseif self.movement_type == "asteroids" then
        -- Asteroids: Rotate + thrust physics
        if self:isKeyDown('left', 'a') then
            self.player.angle = self.player.angle - self.rotation_speed * dt * 60
        end
        if self:isKeyDown('right', 'd') then
            self.player.angle = self.player.angle + self.rotation_speed * dt * 60
        end

        -- Thrust
        if self:isKeyDown('up', 'w') then
            local rad = math.rad(self.player.angle)
            local thrust = self.movement_speed * 5 * dt  -- Thrust acceleration
            self.player.vx = self.player.vx + math.cos(rad) * thrust * self.accel_friction
            self.player.vy = self.player.vy + math.sin(rad) * thrust * self.accel_friction
        end

        -- Apply deceleration
        self.player.vx = self.player.vx * (1.0 - (1.0 - self.decel_friction) * dt * 5)
        self.player.vy = self.player.vy * (1.0 - (1.0 - self.decel_friction) * dt * 5)

        -- Update position
        self.player.x = self.player.x + self.player.vx * dt
        self.player.y = self.player.y + self.player.vy * dt

        -- Clamp or wrap
        self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
        self.player.y = math.max(0, math.min(self.game_height - self.player.height, self.player.y))

    elseif self.movement_type == "jump" then
        -- Jump/Dash mode: Discrete dashes instead of continuous movement
        if self.player.jump_timer > 0 then
            self.player.jump_timer = self.player.jump_timer - dt
        end

        if not self.player.is_jumping and self.player.jump_timer <= 0 then
            local jump_dir = nil
            if self:isKeyDown('left', 'a') then jump_dir = 'left' end
            if self:isKeyDown('right', 'd') then jump_dir = 'right' end
            if self:isKeyDown('up', 'w') then jump_dir = 'up' end
            if self:isKeyDown('down', 's') then jump_dir = 'down' end

            if jump_dir then
                self:executeJump(jump_dir)
                self.player.jump_timer = self.jump_cooldown
            end
        end

        -- Update jump animation
        if self.player.is_jumping then
            self.player.jump_progress = self.player.jump_progress + dt / (self.jump_distance / self.jump_speed)

            if self.player.jump_progress >= 1.0 then
                self.player.x = self.player.jump_target_x
                self.player.y = self.player.jump_target_y
                self.player.is_jumping = false
            else
                -- Lerp to target
                local t = self.player.jump_progress
                self.player.x = self.player.jump_start_x + (self.player.jump_target_x - self.player.jump_start_x) * t
                self.player.y = self.player.jump_start_y + (self.player.jump_target_y - self.player.jump_start_y) * t
            end
        end
    end

    -- Fire cooldown (all modes)
    if self.player.fire_cooldown > 0 then
        self.player.fire_cooldown = self.player.fire_cooldown - dt
    end

    -- Shooting (handled in next phase)
    if self:isKeyDown('space') and self.player.fire_cooldown <= 0 then
        self:playerShoot()
    end
end

function SpaceShooter:executeJump(direction)
    self.player.is_jumping = true
    self.player.jump_progress = 0
    self.player.jump_start_x = self.player.x
    self.player.jump_start_y = self.player.y

    -- Calculate target based on direction
    local target_x = self.player.x
    local target_y = self.player.y

    if direction == 'left' then target_x = target_x - self.jump_distance end
    if direction == 'right' then target_x = target_x + self.jump_distance end
    if direction == 'up' then target_y = target_y - self.jump_distance end
    if direction == 'down' then target_y = target_y + self.jump_distance end

    -- Clamp to bounds
    target_x = math.max(0, math.min(self.game_width - self.player.width, target_x))
    target_y = math.max(0, math.min(self.game_height - self.player.height, target_y))

    self.player.jump_target_x = target_x
    self.player.jump_target_y = target_y
end
```

### 2.3: Lives & Shield Parameters

**File**: `src/games/space_shooter.lua` → init()

```lua
-- Lives system
local base_lives = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.max_deaths_base) or PLAYER_MAX_DEATHS_BASE
local advantage_modifier = self.cheats.advantage_modifier or {}
local extra_deaths = advantage_modifier.deaths or 0
self.PLAYER_MAX_DEATHS = base_lives + extra_deaths
if self.variant and self.variant.lives_count ~= nil then
    self.PLAYER_MAX_DEATHS = self.variant.lives_count + extra_deaths
end

-- Shield system
self.shield_enabled = (runtimeCfg and runtimeCfg.shield and runtimeCfg.shield.enabled) or false
if self.variant and self.variant.shield ~= nil then
    self.shield_enabled = self.variant.shield
end

self.shield_regen_time = (runtimeCfg and runtimeCfg.shield and runtimeCfg.shield.regen_time) or 5.0
if self.variant and self.variant.shield_regen_time ~= nil then
    self.shield_regen_time = self.variant.shield_regen_time
end

self.shield_max_hits = (runtimeCfg and runtimeCfg.shield and runtimeCfg.shield.max_hits) or 1
if self.variant and self.variant.shield_hits ~= nil then
    self.shield_max_hits = self.variant.shield_hits
end

-- Initialize shield state
if self.shield_enabled then
    self.player.shield_active = true
    self.player.shield_regen_timer = 0
end
```

---

## PHASE 3: Weapon Systems - Core

### Duration: 3 days

*[Continue with detailed weapon system implementation including fire_mode, fire_rate, bullet patterns, etc. - Following same pattern as Phase 2]*

---

## PHASE 4-14: [Detailed plans for remaining phases]

*Due to length constraints, I'll provide the structure. Each phase follows the same pattern:*
1. Parameter loading with three-tier fallback
2. Game logic implementation
3. View integration where needed
4. CheatEngine compatibility
5. Variant JSON examples

---

## Key Implementation Rules

### 1. Parameter Loading Pattern (ALWAYS USE THIS)

```lua
-- Step 1: File-scope constant with safe fallback
local DEFAULT_VALUE = (SCfg.category and SCfg.category.param) or hardcoded_fallback

-- Step 2: Runtime config override
self.parameter = (runtimeCfg and runtimeCfg.category and runtimeCfg.category.param) or DEFAULT_VALUE

-- Step 3: Variant override (MUST check ~= nil for numeric 0 and false values!)
if self.variant and self.variant.parameter ~= nil then
    self.parameter = self.variant.parameter
end

-- Step 4: Cheat modifier (if applicable)
if self.cheats.parameter_modifier then
    self.parameter = self.parameter + self.cheats.parameter_modifier
end
```

### 2. Scaling Constant Usage

Use `scaling_constant` in formulas that should benefit from global upgrades:

```lua
-- In base_game_definitions.json formula:
"((metrics.kills * metrics.kills * 10 * scaling_constant) - (metrics.deaths * 5))"

-- NOT just difficulty scaling (that's difficulty_modifier)
-- This is GLOBAL progression multiplier
```

### 3. CheatEngine Min/Max Ranges

**CRITICAL**: Every tunable numeric parameter needs min/max:

```lua
-- config.lua → cheat_engine.parameter_ranges
parameter_name = { min = safe_minimum, max = reasonable_maximum },
```

Ranges should prevent game-breaking (e.g., `movement_speed = 0` breaks game).

### 4. Enum Parameters (Hidden from CheatEngine)

String parameters like `movement_type`, `fire_mode` must be:
- Added to `cheat_engine.hidden_parameters`
- Handled with proper validation in game code
- Defined in variants JSON, NOT cheat-able

### 5. Boolean Parameters

```lua
-- Use ~= nil check to allow explicit false
if self.variant and self.variant.boolean_param ~= nil then
    self.boolean_param = self.variant.boolean_param
end
```

### 6. Array Parameters (enemies, powerup_types)

```lua
-- Load from variant
self.powerup_types = {}
if self.variant and self.variant.powerup_types then
    for _, ptype in ipairs(self.variant.powerup_types) do
        table.insert(self.powerup_types, ptype)
    end
else
    -- Default set
    self.powerup_types = {"weapon_upgrade", "shield"}
end
```

---

## Variant JSON Structure

**File**: `assets/data/variants/space_shooter_variants.json`

### Example Variant: "Space Shooter: Rail Gunner"

```json
{
  "clone_index": 0,
  "name": "Space Shooter: Rail Gunner",
  "sprite_set": "fighter_1",
  "palette": "blue",
  "music_track": "space_theme_1",
  "sfx_pack": "retro_beeps",
  "background": "stars_blue",
  "difficulty_modifier": 1.0,
  "flavor_text": "Fixed lateral movement with rapid-fire cannon!",

  "_comment_movement": "Rail shooter - left/right only",
  "movement_type": "rail",
  "movement_speed": 300,

  "_comment_weapon": "Rapid fire, straight shots",
  "fire_mode": "auto",
  "fire_rate": 5.0,
  "bullet_pattern": "single",
  "bullet_speed": 600,

  "_comment_enemies": "Basic waves with occasional weavers",
  "enemies": [
    { "type": "basic", "multiplier": 1.5 },
    { "type": "weaver", "multiplier": 0.3 }
  ],
  "enemy_spawn_rate": 0.8,
  "enemy_bullets": true,
  "enemy_bullet_speed": 250,

  "_comment_victory": "Kill 30 enemies to win",
  "victory_condition": "kills",
  "victory_limit": 30,

  "intro_cutscene": null
}
```

### Example Variant: "Space Shooter: Bullet Hell"

```json
{
  "clone_index": 5,
  "name": "Space Shooter: Bullet Hell Nightmare",
  "sprite_set": "fighter_2",
  "palette": "red",
  "music_track": "space_theme_intense",
  "sfx_pack": "8bit_arcade",
  "background": "stars_red",
  "difficulty_modifier": 2.5,
  "flavor_text": "Extreme difficulty! Tiny hitbox, massive enemy firepower!",

  "_comment_movement": "Jump/dash movement for dodging",
  "movement_type": "jump",
  "movement_speed": 400,
  "jump_distance": 150,
  "jump_cooldown": 0.3,

  "_comment_weapon": "Spread shot for coverage",
  "fire_mode": "auto",
  "fire_rate": 3.0,
  "bullet_pattern": "spread",
  "spread_angle": 45,
  "bullet_speed": 500,

  "_comment_enemies": "Many enemies, heavy bullet spam",
  "enemies": [
    { "type": "basic", "multiplier": 3.0 },
    { "type": "bomber", "multiplier": 2.0 },
    { "type": "weaver", "multiplier": 1.5 }
  ],
  "enemy_spawn_rate": 0.3,
  "enemy_bullets": true,
  "enemy_bullet_speed": 400,
  "enemy_formation": "wall",

  "_comment_special": "Bullet hell modifiers",
  "bullet_hell_mode": true,
  "player_size": 0.5,
  "lives_count": 1,

  "_comment_victory": "Survive 90 seconds",
  "victory_condition": "time",
  "victory_limit": 90,

  "powerup_spawn_rate": 5.0,
  "powerup_types": ["shield", "bomb"],
  "powerups_from_enemies": 0.05,

  "intro_cutscene": null
}
```

### Example Variant: "Space Shooter: Asteroid Field"

```json
{
  "clone_index": 10,
  "name": "Space Shooter: Asteroid Field Runner",
  "sprite_set": "fighter_1",
  "palette": "green",
  "music_track": "space_theme_ambient",
  "sfx_pack": "modern_ui",
  "background": "stars_green",
  "difficulty_modifier": 1.4,
  "flavor_text": "Navigate dense asteroid field while fighting enemies!",

  "_comment_movement": "Asteroids-style physics",
  "movement_type": "asteroids",
  "movement_speed": 200,
  "rotation_speed": 8.0,
  "accel_friction": 0.95,
  "decel_friction": 0.98,

  "_comment_weapon": "Homing missiles for maneuvering",
  "fire_mode": "manual",
  "bullet_pattern": "single",
  "bullet_speed": 300,
  "bullet_homing": true,
  "homing_strength": 0.7,

  "_comment_enemies": "Fewer enemies, more environmental danger",
  "enemies": [
    { "type": "basic", "multiplier": 0.5 },
    { "type": "kamikaze", "multiplier": 0.8 }
  ],
  "enemy_spawn_rate": 2.0,
  "enemy_bullets": false,

  "_comment_environment": "Dense asteroid field",
  "asteroid_field_density": 5,
  "meteor_shower_frequency": 2,
  "scroll_speed": 50,
  "screen_wrap": true,

  "_comment_victory": "Survive AND kill 15",
  "victory_condition": "kills",
  "victory_limit": 15,

  "intro_cutscene": null
}
```

---

## Testing Checklist (Phase 13)

### Per Movement Type
- [ ] Default: WASD free movement works, stays in bounds
- [ ] Rail: Left/right only, vertical fixed
- [ ] Jump: Dash movement with cooldown, can't jump during animation
- [ ] Asteroids: Rotation + thrust physics, momentum feels right

### Per Fire Mode
- [ ] Manual: Space bar fires single shot with cooldown
- [ ] Auto: Holds space, fires continuously at fire_rate
- [ ] Charge: Hold to charge, release to fire stronger shot
- [ ] Burst: Fires burst_count bullets rapidly

### Per Bullet Pattern
- [ ] Single: One bullet straight ahead
- [ ] Double: Two parallel bullets
- [ ] Triple: Three bullets (center + slight angles)
- [ ] Spread: Fan of bullets at spread_angle
- [ ] Spiral: Rotating pattern
- [ ] Wave: Sine wave motion

### Bullet Modifiers
- [ ] Homing: Bullets curve toward enemies
- [ ] Piercing: Bullets pass through multiple enemies
- [ ] Gravity: Bullets arc downward/upward
- [ ] Lifetime: Bullets despawn after time

### Shield System
- [ ] Shield blocks 1 hit (or shield_hits)
- [ ] Shield regenerates after shield_regen_time
- [ ] Visual feedback when shield active/broken

### Environmental Hazards
- [ ] Asteroids spawn at asteroid_density rate
- [ ] Meteors rain down at meteor_frequency
- [ ] Gravity wells pull player/bullets
- [ ] Scroll speed moves background

### Special Mechanics
- [ ] Screen wrap: Player/bullets wrap at edges
- [ ] Reverse gravity: Player at top, gameplay inverted
- [ ] Blackout zones: Vision obscured in zones
- [ ] Bullet hell mode: Tiny hitbox, massive challenge

### Victory Conditions
- [ ] Kills: Reach victory_limit kills
- [ ] Time: Survive victory_limit seconds
- [ ] Survival: Don't die for duration
- [ ] Boss: (if implemented) Defeat boss

### CheatEngine
- [ ] All numeric parameters appear in CheatEngine UI
- [ ] Min/max clamping prevents breaking game
- [ ] Enum parameters (movement_type, etc.) hidden
- [ ] Cost scaling feels balanced

### Variants
- [ ] Each variant feels unique and distinct
- [ ] No game-breaking combinations (e.g., 0 movement_speed)
- [ ] Difficulty modifiers scale appropriately
- [ ] All variant parameters load correctly

### Formula & Scaling
- [ ] Token formula uses scaling_constant
- [ ] Formula rewards skill (high kills, low deaths)
- [ ] Formula scales appropriately with difficulty_modifier
- [ ] VMs can run variants (if demo-recordable)

---

## Documentation Requirements (Phase 14)

### 1. Parameter Reference Doc

Create `documentation/space_shooter_parameters.md`:

```markdown
# Space Shooter Parameters Reference

## Movement System
- **movement_type**: (enum) "default", "jump", "rail", "asteroids"
  - default: WASD free movement
  - jump: Dash-based movement with cooldown
  - rail: Left/right only, vertical fixed
  - asteroids: Rotate + thrust physics

- **movement_speed**: (number, 50-600) Base movement speed
  - Lower = slower, harder to dodge
  - Higher = faster, easier to dodge
  - Default: 200

[... continue for all 50+ parameters ...]
```

### 2. Variant Design Guide

Create `documentation/space_shooter_variant_guide.md`:

```markdown
# Space Shooter Variant Design Guide

## Design Philosophy
Variants should create distinctly different playstyles, not just harder versions.

## Variant Archetypes

### 1. Rail Shooter
- movement_type: rail
- fire_mode: auto
- Focus: Aim accuracy while dodging
- Example: "Rail Gunner"

### 2. Bullet Hell
- bullet_hell_mode: true
- player_size: 0.5
- enemy_bullets: high density
- Focus: Precision dodging
- Example: "Bullet Hell Nightmare"

[... continue for 8-10 archetypes ...]
```

### 3. Implementation Notes

Add to `CLAUDE.md` or create `documentation/space_shooter_implementation_notes.md`:

```markdown
# Space Shooter Implementation Notes

## Architecture
- Follows Snake/Dodge pattern for parameter loading
- Uses three-tier fallback: constant → config → variant
- All numeric params have CheatEngine min/max ranges
- Enum params hidden from CheatEngine

## Key Systems
- Movement: 4 modes (default, jump, rail, asteroids)
- Weapons: 4 fire modes × 6 bullet patterns = 24 combinations
- Enemies: 4 base types with multiplier system
- Environment: Asteroids, meteors, gravity wells
- Power-ups: 8 types, spawnable from enemies or timer

## Formula
`((metrics.kills * metrics.kills * 10 * scaling_constant) - (metrics.deaths * metrics.deaths * 5 * scaling_constant))`

Rewards: High kills, low deaths
Scales with: scaling_constant (global upgrade)
```

---

## Estimated Timeline

| Phase | Focus | Days | Running Total |
|-------|-------|------|---------------|
| 1 | Foundation & Architecture | 2 | 2 |
| 2 | Player Movement Systems | 2 | 4 |
| 3 | Weapon Systems - Core | 3 | 7 |
| 4 | Weapon Systems - Advanced | 2 | 9 |
| 5 | Enemy Systems | 2 | 11 |
| 6 | Power-Up System | 2 | 13 |
| 7 | Environmental Hazards | 2 | 15 |
| 8 | Special Mechanics & Victory | 2 | 17 |
| 9 | Shield & Lives Systems | 1 | 18 |
| 10 | Arena & Visuals | 1 | 19 |
| 11 | CheatEngine Integration | 2 | 21 |
| 12 | Variant JSON Creation | 3 | 24 |
| 13 | Testing & Balancing | 3 | 27 |
| 14 | Documentation | 1 | 28 |

**Total: 28 days (4 weeks)**

With parallel work on some phases, could compress to 21-24 days.

---

## Success Criteria

### Code Quality
- [ ] Follows DI pattern (no global reads)
- [ ] MVC separation maintained
- [ ] All requires at file scope
- [ ] Error handling with pcall where needed
- [ ] No magic numbers (all in config.lua)

### Feature Completeness
- [ ] All 50+ parameters implemented
- [ ] All 4 movement types working
- [ ] All weapon systems functional
- [ ] Environmental hazards spawning correctly
- [ ] Victory conditions all working

### CheatEngine Integration
- [ ] All numeric params have ranges
- [ ] Enum params properly hidden
- [ ] Cost scaling feels balanced
- [ ] No game-breaking combinations possible

### Variant Quality
- [ ] 15-20 unique variants created
- [ ] Each variant feels distinct
- [ ] Good variety of playstyles represented
- [ ] Difficulty progression makes sense

### Documentation
- [ ] All parameters documented
- [ ] Variant design guide complete
- [ ] Implementation notes added to CLAUDE.md
- [ ] Code comments explain complex systems

### Balance & Polish
- [ ] Token formula rewards skill
- [ ] scaling_constant integrated properly
- [ ] No exploits or degenerate strategies
- [ ] Game runs at 60 FPS with all systems active

---

## Risk Mitigation

### Risk: Scope Creep
**Mitigation**: Strict phase discipline. Don't add "just one more" feature mid-phase.

### Risk: Parameter Overload
**Mitigation**: Test each parameter individually before combining. Document interactions.

### Risk: CheatEngine Exploits
**Mitigation**: Min/max ranges tested rigorously. Playtest with extreme values.

### Risk: Performance Issues
**Mitigation**: Profile early (Phase 7+). Use object pooling for bullets/enemies.

### Risk: Variant Fatigue
**Mitigation**: Focus on 10 great variants, not 20 mediocre ones. Quality over quantity.

---

## Next Steps After Plan Approval

1. **Phase 1 Kickoff**: Start with config.lua additions (half day)
2. **Create Feature Branch**: `feature/space-shooter-variants`
3. **Daily Standup Pattern**: Review each phase completion before moving forward
4. **Test After Each Phase**: Don't accumulate tech debt
5. **Document As You Go**: Don't leave docs for the end

---

## Appendix: Complete Parameter List

### Player Movement (10 parameters)
1. movement_type (enum)
2. movement_speed
3. rotation_speed
4. accel_friction
5. decel_friction
6. jump_distance
7. jump_cooldown
8. jump_speed
9. lives_count
10. player_size (if implemented)

### Shield System (3 parameters)
11. shield (boolean)
12. shield_regen_time
13. shield_hits

### Weapon - Fire System (8 parameters)
14. fire_mode (enum)
15. fire_rate
16. burst_count
17. burst_delay
18. charge_time
19. overheat_enabled (boolean)
20. overheat_threshold
21. overheat_cooldown

### Weapon - Ammo (3 parameters)
22. ammo_enabled (boolean)
23. ammo_capacity
24. ammo_reload_time

### Weapon - Bullet Behavior (8 parameters)
25. bullet_speed
26. bullet_pattern (enum)
27. spread_angle
28. bullet_homing (boolean)
29. homing_strength
30. bullet_piercing (boolean)
31. bullet_gravity
32. bullet_lifetime

### Enemy System (7 parameters)
33. enemy_spawn_rate
34. enemy_speed_multiplier
35. enemy_pattern (enum)
36. enemy_types_enabled (array)
37. enemy_formation (enum)
38. enemy_bullets (boolean)
39. enemy_bullet_speed

### Power-Up System (5 parameters)
40. powerup_spawn_rate
41. powerup_types (array)
42. powerup_duration
43. powerup_stacking (boolean)
44. powerups_from_enemies (percentage)

### Environment (5 parameters)
45. scroll_speed
46. asteroid_field_density
47. meteor_shower_frequency
48. gravity_wells
49. gravity_well_strength

### Arena (4 parameters)
50. arena_width
51. screen_wrap (boolean)
52. reverse_gravity (boolean)
53. blackout_zones

### Victory/Difficulty (4 parameters)
54. difficulty_curve (enum)
55. victory_condition (enum)
56. victory_limit
57. bullet_hell_mode (boolean)

**TOTAL: 57 parameters**

---

**END OF PLAN**

This plan provides a complete roadmap for transforming Space Shooter from a 504-line skeleton into a 2000+ line fully-featured game with 57 tunable parameters, 15-20 unique variants, full CheatEngine integration, and scaling_constant support.

Ready to begin Phase 1?
