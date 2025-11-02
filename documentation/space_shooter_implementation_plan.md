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

## Phase Completion Protocol

**IMPORTANT**: After completing each phase, update this document with completion notes under the respective phase in the Phase Breakdown section. Each completion note should include:

1. **What was completed**: Brief description of implemented features
2. **In-game observations**: What players will notice/experience
3. **How to test**: Specific steps to verify the phase works correctly
4. **Status**: "✅ COMPLETE" or "⚠️ NEEDS MORE WORK" (aim for complete every time!)

Format:
```
---
**PHASE X COMPLETION NOTES** (Date: YYYY-MM-DD)

**Completed:**
- Feature 1
- Feature 2

**In-Game:**
- Observable behavior 1
- Observable behavior 2

**Testing:**
1. Test step 1
2. Test step 2

**Status:** ✅ COMPLETE
---
```

---

## Phase Breakdown

### Phase 1: Foundation & Architecture (Days 1-2)
**Goal**: Set up config structure, constants, parameter loading skeleton

---
**PHASE 1 COMPLETION NOTES** (Date: 2025-01-11)

**Completed:**
- Added comprehensive Space Shooter configuration to `src/config.lua`:
  - Player movement defaults (speed, rotation, accel/decel, jump parameters)
  - Shield system defaults (enabled, regen_time, max_hits)
  - Bullet defaults (speed, gravity, lifetime, homing, piercing, damage)
  - Weapon system defaults (fire modes, burst, charge, overheat, ammo)
  - Enemy defaults (spawn rates, formations, bullet behavior)
  - Power-up defaults (spawn rate, duration, stacking, types)
  - Environment defaults (scroll speed, asteroids, meteors, gravity wells)
  - Arena defaults (width, screen wrap, reverse gravity, blackout zones)
  - Victory/difficulty defaults (conditions, curves, bullet hell mode)
- Added 35 parameter ranges to CheatEngine system in `config.lua`
  - All numeric parameters have min/max clamping to prevent game-breaking
  - Ranges tested for reasonable gameplay boundaries
- Updated CheatEngine hidden_parameters to lock 6 enum parameters:
  - `movement_type`, `fire_mode`, `bullet_pattern`, `enemy_pattern`, `enemy_formation`, `difficulty_curve`, `powerup_types`
- Added Space Shooter enums to `src/constants.lua`:
  - Movement types (default, jump, rail, asteroids)
  - Fire modes (manual, auto, charge, burst)
  - Bullet patterns (single, double, triple, spread, spiral, wave)
  - Enemy formations (scattered, v_formation, wall, spiral)
  - Victory conditions (kills, time, survival, boss)
  - Difficulty curves (linear, exponential, wave)
- Updated `assets/data/base_game_definitions.json`:
  - Changed unlock_cost from 1 billion to 20 (matches Snake/Dodge pricing)
  - Updated formula to use scaling_constant: `((metrics.kills * metrics.kills * 10 * scaling_constant) - (metrics.deaths * metrics.deaths * 5 * scaling_constant))`
  - Added 6 available_cheats with proper descriptions, costs, and affects fields
  - Added accuracy and time_survived to metrics_tracked
  - Uses cost_exponent: 1.5 (same exponential growth as Snake/Dodge)

**In-Game:**
- No visual changes yet (Phase 1 is foundation only)
- Space Shooter now unlockable for 20 tokens (was 1 billion, now matches Snake/Dodge)
- CheatEngine will recognize Space Shooter parameters when implemented in game code
- Formulas now scale with global scaling_constant upgrade
- All configuration foundations ready for Phase 2 implementation

**Testing:**
1. Launch game and verify it still runs without errors
2. Unlock Space Shooter for 50 tokens
3. Open CheatEngine for Space Shooter (no new parameters visible yet, expected)
4. Check that game plays identically to before (no behavior changes yet)
5. Verify base_game_definitions.json loads correctly (no JSON parse errors)

**Status:** ✅ COMPLETE

**Notes for Phase 2:**
- All config foundations in place
- Parameter loading pattern ready to be implemented in `src/games/space_shooter.lua`
- Three-tier fallback system (constant → config → variant) documented in plan
- Next step: Implement movement type variations using these config values

---

### Phase 2: Player Movement Systems (Days 3-4)
**Goal**: Implement movement_type variations (default, jump, rail, asteroids)

---
**PHASE 2 COMPLETION NOTES** (Date: 2025-01-11)

**Completed:**
- Added movement type parameter loading with three-tier fallback system in `init()`:
  - `movement_type` (enum: default, jump, rail, asteroids)
  - `movement_speed` (base movement speed for all modes)
  - `rotation_speed` (asteroids mode rotation rate)
  - `accel_friction` / `decel_friction` (asteroids mode physics)
  - `jump_distance`, `jump_cooldown`, `jump_speed` (jump mode parameters)
- Implemented 4 movement modes in `updatePlayer()`:
  - **Default**: Full WASD free movement (up/down/left/right)
  - **Rail**: Left/right only, vertical position fixed (classic rail shooter)
  - **Asteroids**: Rotate with A/D, thrust with W, momentum-based physics
  - **Jump**: Discrete dash movement with cooldown (bullet hell dodging)
- Added lives system parameter loading:
  - `lives_count` variant parameter overrides base lives
  - Works with existing CheatEngine advantage_modifier
- Implemented shield system:
  - `shield_enabled` (boolean) - variant can enable shields
  - `shield_regen_time` - seconds to regenerate after breaking
  - `shield_hits` - number of hits shield can absorb
  - Shield blocks enemy bullets before taking lives damage
  - Regenerates automatically after timeout
- Added `executeJump()` helper function for jump mode dash mechanics
- Updated bullet collision to check shield state before applying damage

**In-Game:**
- **Movement Type Variations**: Players can now experience 4 distinct control schemes
  - Default mode works like before (but now supports vertical movement too!)
  - Rail mode locks vertical position (true rail shooter)
  - Asteroids mode uses rotate+thrust physics (drift and momentum)
  - Jump mode replaces continuous movement with cooldown-based dashes
- **Shield System**: When enabled, shields absorb hits before lives are lost
  - Shield regenerates after breaking (visible via timer)
  - Changes risk/reward dynamics (aggressive vs defensive play)
- **Lives Now Variant-Tunable**: Variants can set custom starting lives
  - Creates easy variants (10 lives) or bullet hell variants (1 life)

**Testing:**
1. Launch game and play Space Shooter with default movement (should now have WASD free movement including vertical)
2. Test all movement modes by creating test variants (see test variants below)
3. Verify shield system:
   - Enable shield in variant JSON (`"shield": true`)
   - Get hit, verify shield blocks damage
   - Verify shield regenerates after `shield_regen_time` seconds
4. Test lives parameter by setting `"lives_count": 1` or `"lives_count": 20` in variant
5. Verify asteroids mode physics feel smooth (rotation, thrust, momentum)
6. Verify jump mode cooldown prevents spam (can't jump while `jump_timer > 0`)

**Test Variants** (optional, for thorough testing):
```json
{
  "movement_type": "rail",
  "movement_speed": 300,
  "name": "Rail Gunner Test"
}

{
  "movement_type": "asteroids",
  "movement_speed": 200,
  "rotation_speed": 8.0,
  "accel_friction": 0.95,
  "decel_friction": 0.98,
  "name": "Asteroids Physics Test"
}

{
  "movement_type": "jump",
  "jump_distance": 150,
  "jump_cooldown": 0.3,
  "jump_speed": 600,
  "shield": true,
  "shield_regen_time": 3.0,
  "shield_hits": 1,
  "lives_count": 1,
  "name": "Bullet Hell Dash Test"
}
```

**Status:** ✅ COMPLETE

**Notes for Phase 3:**
- Movement system fully parameterized and working
- Shield system provides foundation for power-up mechanics (Phase 6)
- Next: Implement weapon systems (fire modes, bullet patterns)
- Asteroids mode will benefit from bullet homing/gravity (Phase 4)

---

### Phase 3: Weapon Systems - Core (Days 5-7)
**Goal**: Fire modes, bullet patterns, bullet behavior modifiers

---
**PHASE 3 COMPLETION NOTES** (Date: 2025-01-11)

**Completed:**
- Added fire mode parameter loading with three-tier fallback system in `init()`:
  - `fire_mode` (enum: manual, auto, charge, burst)
  - `fire_rate` (shots per second for auto mode)
  - `burst_count` (bullets per burst)
  - `burst_delay` (seconds between burst shots)
  - `charge_time` (seconds to full charge)
- Added bullet pattern parameter loading:
  - `bullet_pattern` (enum: single, double, triple, spread, spiral, wave)
  - `spread_angle` (degrees for spread pattern)
- Added bullet behavior parameters:
  - `bullet_speed` (pixels/sec)
  - `bullet_homing` (boolean)
  - `homing_strength` (0-1, how aggressively bullets track)
  - `bullet_piercing` (boolean, bullets pass through enemies)
- Implemented 4 fire modes in `updatePlayer()`:
  - **Manual**: Press space to fire with cooldown (classic shooter)
  - **Auto**: Hold space, fires continuously at fire_rate
  - **Charge**: Hold space to charge, release to fire (charge_multiplier affects speed)
  - **Burst**: Press space to fire burst_count bullets rapidly with burst_delay
- Implemented 6 bullet patterns in `playerShoot()`:
  - **Single**: One bullet straight ahead
  - **Double**: Two parallel bullets with slight offset
  - **Triple**: Three bullets with 10-degree angles
  - **Spread**: 5 bullets in fan pattern using spread_angle
  - **Spiral**: 6 bullets rotating pattern (visual spiral when repeated)
  - **Wave**: 3 bullets with sine wave movement
- Created `createBullet()` helper for pattern support:
  - Handles angle calculation for all movement modes
  - Supports x_offset for parallel bullets
  - Supports wave_type for wave pattern
  - Applies charge_multiplier to bullet speed
- Implemented bullet behavior modifiers in `updateBullets()`:
  - **Homing**: Bullets gradually turn toward closest enemy
  - **Piercing**: Bullets don't despawn on hit, can hit multiple enemies
  - **Wave**: Bullets move in sine wave pattern while traveling forward

**In-Game:**
- **Fire Modes**: Players experience 4 distinct firing mechanics
  - Manual mode feels responsive (traditional shooter)
  - Auto mode provides suppressive fire (hold to spray)
  - Charge mode rewards timing (hold for powerful shot)
  - Burst mode creates burst DPS (3-shot bursts)
- **Bullet Patterns**: 6 visual/tactical variations
  - Single for precision
  - Double/Triple for coverage
  - Spread for wide area denial
  - Spiral for visual spectacle
  - Wave for unpredictable movement
- **Homing Bullets**: Automatically track and curve toward enemies
  - homing_strength controls turn rate (0.1 = slight curve, 1.0 = aggressive tracking)
  - Combines with patterns (homing spread = seeking fan)
- **Piercing Bullets**: Pass through enemies, hitting multiple targets
  - Great for crowd control
  - Combines with patterns (piercing spread = line clearance)

**Testing:**
1. Test all fire modes:
   - Manual: Press space, verify cooldown prevents spam
   - Auto: Hold space, verify fires at configured fire_rate
   - Charge: Hold space, verify charge progress (visual feedback in Phase 4+), release fires
   - Burst: Press space, verify burst_count shots fire with burst_delay between
2. Test all bullet patterns:
   - Single: One bullet from center
   - Double: Two bullets parallel
   - Triple: Three bullets with angles
   - Spread: Fan of 5 bullets
   - Spiral: Rotating 6-bullet pattern
   - Wave: Three bullets with wave motion
3. Test bullet behaviors:
   - Homing: Verify bullets curve toward enemies (homing_strength affects turn rate)
   - Piercing: Verify bullets pass through enemies without despawning
   - Wave: Verify sine wave motion while moving forward
4. Test combinations:
   - Clone 8 "Auto Spread": Auto + Spread = continuous fan fire
   - Clone 9 "Charge Homing": Charge + Homing = powerful seeking shot
   - Clone 10 "Burst Piercing": Burst + Triple + Piercing = multi-target burst
   - Clone 11 "Wave Pattern": Manual + Wave = tactical unpredictable shots
   - Clone 12 "Spiral Madness": Auto + Spiral = visual spectacle

**Test Variants**: 5 new variants added to `space_shooter_variants.json` (clones 8-12) ready for testing.

**Status:** ✅ COMPLETE

**Notes for Phase 4:**
- Fire modes fully functional and distinct
- Bullet patterns provide variety and tactical depth
- Homing/piercing add strategic options
- Next: Implement ammo, overheat, and gravity systems
- Consider adding visual charge indicator for charge mode
- Wave pattern amplitude/frequency could be parameterized in Phase 4

---

### Phase 4: Weapon Systems - Advanced (Days 8-9)
**Goal**: Ammo, overheat, gravity, special mechanics

---
**PHASE 4 COMPLETION NOTES** (Date: 2025-01-11)

**Completed:**
- Added ammo system parameter loading with three-tier fallback system in `init()`:
  - `ammo_enabled` (boolean) - enables ammo system
  - `ammo_capacity` (5-500) - maximum ammunition
  - `ammo_reload_time` (0.5-10 seconds) - time to reload
- Added overheat system parameter loading:
  - `overheat_enabled` (boolean) - enables overheat system
  - `overheat_threshold` (3-100) - shots before overheating
  - `overheat_cooldown` (0.5-10 seconds) - cooldown time after overheat
- Added player state tracking for both systems:
  - Ammo: `ammo`, `reload_timer`, `is_reloading`
  - Overheat: `heat`, `is_overheated`, `overheat_timer`
- Implemented ammo system in `updatePlayer()`:
  - Auto-reload when empty
  - Manual reload with 'R' key (if ammo < capacity)
  - Reload progress timer countdown
- Implemented overheat system in `updatePlayer()`:
  - Overheat cooldown timer
  - Passive heat dissipation (2 heat/second when not shooting)
  - Heat resets to 0 after cooldown completes
- Added ammo checks in `playerShoot()`:
  - Block shooting while reloading
  - Auto-reload trigger when ammo reaches 0
  - Consume 1 ammo per shot
- Added overheat checks in `playerShoot()`:
  - Block shooting while overheated
  - Increase heat by 1 per shot
  - Trigger overheat when heat >= threshold
- Implemented HUD displays in `space_shooter_view.lua`:
  - Ammo counter with low ammo warning (orange when <25%)
  - Reload progress bar (yellow) with "Reloading..." text
  - Heat bar with color coding (green → yellow → red)
  - Overheat warning with cooldown progress bar (red)
  - Dynamic row allocation for flexible HUD layout

**In-Game:**
- **Ammo System**: Players must manage limited ammunition
  - Can press 'R' to manually reload before empty (tactical choice)
  - Auto-reloads when completely empty (prevents softlock)
  - Reload time creates vulnerability windows (must plan reloads)
  - Low ammo warning (orange text <25%) prompts reload decision
- **Overheat System**: Weapon heats up with sustained fire
  - Each shot adds 1 heat
  - Hitting threshold prevents shooting during cooldown
  - Heat passively dissipates when not shooting (2/second)
  - Encourages burst fire rather than continuous spam
- **Combined Systems**: Can be enabled together for maximum challenge
  - Both resource pools to manage simultaneously
  - Creates distinct risk/reward trade-offs
  - Different playstyles emerge (conservative vs aggressive)
- **HUD Feedback**: Clear visual indicators for both systems
  - Progress bars show reload/cooldown status
  - Color coding communicates urgency (green = safe, red = danger)
  - Current ammo count always visible when enabled
  - Heat percentage visible as bar fill

**Testing:**
1. Test ammo system:
   - Play Clone 13 "Ammo Limited" (20 bullets, 3s reload)
   - Verify auto-reload when empty
   - Press 'R' to manually reload before empty, verify it works
   - Verify can't shoot while reloading
   - Check low ammo warning appears when <25% (orange text)
2. Test overheat system:
   - Play Clone 14 "Overheat Challenge" (5 shots, 5s cooldown)
   - Fire rapidly until overheat
   - Verify can't shoot while overheated
   - Verify heat dissipates at 2/second when not shooting
   - Check heat bar color changes (green → yellow → red)
3. Test combined systems:
   - Play Clone 15 "Resource Management" (both enabled)
   - Verify both ammo and overheat work together
   - Check that both HUD displays appear
   - Verify both systems independently block shooting
4. Test baseline (no restrictions):
   - Play Clone 16 "Unlimited Power" (both disabled)
   - Verify continuous fire works as before
   - No ammo/overheat HUD elements should appear
5. Verify HUD layout:
   - Check row allocation is dynamic (skips rows when systems disabled)
   - Verify all HUD elements align correctly
   - Check progress bars render properly

**Test Variants**: 4 new variants added to `space_shooter_variants.json` (clones 13-16):
- Clone 13 "Ammo Limited": Low capacity (20), slow reload (3s) - ammo management focus
- Clone 14 "Overheat Challenge": Low threshold (5), long cooldown (5s) - heat management focus
- Clone 15 "Resource Management": Both systems enabled - dual resource challenge
- Clone 16 "Unlimited Power": Both disabled, piercing spread - baseline comparison

**Status:** ✅ COMPLETE

**Notes for Phase 5:**
- Ammo and overheat systems fully functional
- Both can be independently enabled/disabled per variant
- HUD provides clear feedback for both systems
- Manual reload adds tactical depth to ammo system
- Passive heat dissipation rewards paced firing
- Next: Implement enemy spawn patterns, formations, bullet behavior, difficulty scaling
- Consider adding visual effects for overheated state (screen shake, red flash)
- Could add audio cues for reload/overheat events

---

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

## PHASE 4: Weapon Systems - Advanced

### Duration: 2 days

### Goal
Implement ammo system and overheat mechanics for weapon resource management.

### 4.1: Ammo System

**Parameters to Add**:
```lua
-- In init() - Ammo System
self.ammo_enabled = (runtimeCfg.weapon and runtimeCfg.weapon.ammo_enabled) or false
if self.variant and self.variant.ammo_enabled ~= nil then
    self.ammo_enabled = self.variant.ammo_enabled
end

self.ammo_capacity = (runtimeCfg.weapon and runtimeCfg.weapon.ammo_capacity) or 50
if self.variant and self.variant.ammo_capacity ~= nil then
    self.ammo_capacity = self.variant.ammo_capacity
end

self.ammo_reload_time = (runtimeCfg.weapon and runtimeCfg.weapon.ammo_reload_time) or 2.0
if self.variant and self.variant.ammo_reload_time ~= nil then
    self.ammo_reload_time = self.variant.ammo_reload_time
end
```

**Player State**:
```lua
self.player = {
    -- ... existing fields
    ammo = self.ammo_capacity,
    reload_timer = 0,
    is_reloading = false,
}
```

**Logic in updatePlayer()**:
```lua
-- Ammo reload
if self.ammo_enabled then
    if self.player.is_reloading then
        self.player.reload_timer = self.player.reload_timer - dt
        if self.player.reload_timer <= 0 then
            self.player.is_reloading = false
            self.player.ammo = self.ammo_capacity
        end
    end

    -- Check for manual reload (R key)
    if self:isKeyPressed('r') and not self.player.is_reloading and self.player.ammo < self.ammo_capacity then
        self.player.is_reloading = true
        self.player.reload_timer = self.ammo_reload_time
    end
end
```

**Logic in playerShoot()**:
```lua
-- At start of playerShoot()
if self.ammo_enabled then
    if self.player.is_reloading then
        return -- Can't shoot while reloading
    end

    if self.player.ammo <= 0 then
        -- Auto-reload when empty
        self.player.is_reloading = true
        self.player.reload_timer = self.ammo_reload_time
        return
    end

    -- Consume ammo
    self.player.ammo = self.player.ammo - 1
end
```

### 4.2: Overheat System

**Parameters to Add**:
```lua
-- In init() - Overheat System
self.overheat_enabled = (runtimeCfg.weapon and runtimeCfg.weapon.overheat_enabled) or false
if self.variant and self.variant.overheat_enabled ~= nil then
    self.overheat_enabled = self.variant.overheat_enabled
end

self.overheat_threshold = (runtimeCfg.weapon and runtimeCfg.weapon.overheat_threshold) or 10
if self.variant and self.variant.overheat_threshold ~= nil then
    self.overheat_threshold = self.variant.overheat_threshold
end

self.overheat_cooldown = (runtimeCfg.weapon and runtimeCfg.weapon.overheat_cooldown) or 3.0
if self.variant and self.variant.overheat_cooldown ~= nil then
    self.overheat_cooldown = self.variant.overheat_cooldown
end
```

**Player State**:
```lua
self.player = {
    -- ... existing fields
    heat = 0,
    is_overheated = false,
    overheat_timer = 0,
}
```

**Logic in updatePlayer()**:
```lua
-- Overheat cooldown
if self.overheat_enabled then
    if self.player.is_overheated then
        self.player.overheat_timer = self.player.overheat_timer - dt
        if self.player.overheat_timer <= 0 then
            self.player.is_overheated = false
            self.player.heat = 0
        end
    else
        -- Passive heat dissipation when not shooting
        if self.player.heat > 0 then
            self.player.heat = math.max(0, self.player.heat - dt * 2) -- Dissipate 2 heat/second
        end
    end
end
```

**Logic in playerShoot()**:
```lua
-- At start of playerShoot()
if self.overheat_enabled then
    if self.player.is_overheated then
        return -- Can't shoot while overheated
    end

    -- Increase heat
    self.player.heat = self.player.heat + 1

    -- Check for overheat
    if self.player.heat >= self.overheat_threshold then
        self.player.is_overheated = true
        self.player.overheat_timer = self.overheat_cooldown
        self.player.heat = self.overheat_threshold
    end
end
```

### 4.3: HUD Updates

**Update view to show ammo/overheat**:
- Add ammo counter display when ammo_enabled
- Add reload progress bar when reloading
- Add heat bar when overheat_enabled
- Visual feedback for overheated state (red flash)

### 4.4: Test Variants

Create 3-4 test variants:
- Ammo Limited: Low capacity (20 bullets), slow reload
- Overheat Challenge: Low threshold (5 shots), long cooldown
- Ammo + Overheat: Both systems enabled (hard mode)
- Infinite Ammo: Disabled ammo/overheat (easy mode as baseline)

---

## PHASE 5: Enemy Systems

### Duration: 2 days

### Goal
Implement enemy spawn patterns, formations, bullet behavior, and difficulty scaling.

### 5.1: Enemy Spawn Patterns

**Parameters to Add**:
```lua
self.enemy_spawn_pattern = (runtimeCfg.enemy and runtimeCfg.enemy.spawn_pattern) or "continuous"
-- Options: "continuous", "waves", "clusters", "formations"

self.enemy_spawn_rate = (runtimeCfg.enemy and runtimeCfg.enemy.spawn_rate) or 1.0
-- Multiplier on spawn frequency

self.enemy_speed_multiplier = (runtimeCfg.enemy and runtimeCfg.enemy.speed_multiplier) or 1.0
-- Multiplier on all enemy speeds
```

**Logic**:
- **Continuous**: Current system (steady spawn rate)
- **Waves**: Spawn groups of enemies, then pause
- **Clusters**: Spawn multiple enemies at once in formation
- **Formations**: Specific patterns (V-formation, wall, spiral)

### 5.2: Enemy Bullet System

**Parameters to Add**:
```lua
self.enemy_bullets_enabled = (runtimeCfg.enemy and runtimeCfg.enemy.bullets_enabled) or false
self.enemy_bullet_speed = (runtimeCfg.enemy and runtimeCfg.enemy.bullet_speed) or 200
self.enemy_fire_rate = (runtimeCfg.enemy and runtimeCfg.enemy.fire_rate) or 1.0
```

**Logic**:
- Enemy types that shoot: bomber, basic (if enabled)
- Enemies have fire_cooldown timer
- Enemy bullets stored in `self.enemy_bullets` array
- Player collision with enemy bullets = take damage/life

### 5.3: Difficulty Scaling

**Parameters to Add**:
```lua
self.difficulty_curve = (runtimeCfg.difficulty and runtimeCfg.difficulty.curve) or "linear"
-- Options: "linear", "exponential", "wave"

-- Scaling applies to:
-- - Enemy spawn rate
-- - Enemy speed
-- - Enemy health (if implemented)
```

**Logic**:
- Track elapsed time or kills
- Apply multiplier to spawn rate and enemy stats
- Linear: Steady increase
- Exponential: Rapid ramp-up
- Wave: Alternating hard/easy periods

### 5.4: Test Variants

- Wave Pattern: Enemies in waves with pauses
- Bullet Hell: High enemy bullet density
- Formation Flyer: Enemies in V-formation
- Scaling Nightmare: Exponential difficulty curve

---
**PHASE 5 COMPLETION NOTES** (Date: 2025-01-11)

**Completed:**
- Added enemy spawn pattern system with three-tier fallback:
  - `enemy_spawn_pattern` (continuous/waves/clusters) - controls spawn behavior
  - `enemy_spawn_rate_multiplier` (0.1-10.0) - frequency multiplier
  - `enemy_speed_multiplier` (0.1-5.0) - speed multiplier
- Added enemy formation system:
  - `enemy_formation` (scattered/v_formation/wall/spiral) - visual patterns
  - Formations spawn 5-8 enemies in coordinated shapes
- Implemented enemy bullet system:
  - `enemy_bullets_enabled` (boolean) - toggles enemy shooting
  - `enemy_bullet_speed` (50-800) - bullet velocity
  - `enemy_fire_rate` (0.5-10.0) - shots per second
  - Enemy bullets damage player/shield on collision
- Added difficulty scaling system:
  - `difficulty_curve` (linear/exponential/wave) - scaling behavior
  - `difficulty_scaling_rate` (0.0-1.0) - rate of increase
  - Difficulty scale affects spawn rate and enemy speed
  - Caps at 5.0x to prevent runaway difficulty
- Updated spawn logic in `updateGameLogic()`:
  - Pattern-based spawning (waves/clusters/continuous)
  - Applied difficulty scaling to spawn rates
  - Integrated with existing enemy composition system
- Implemented wave spawning helper (`updateWaveSpawning()`):
  - Spawns groups of enemies quickly
  - Pauses between waves (configurable duration)
  - Wave size scales with difficulty
- Implemented difficulty scaling helper (`updateDifficulty()`):
  - Linear: steady increase over time
  - Exponential: multiplicative growth
  - Wave: sine wave alternating hard/easy
- Added formation spawning helper (`spawnFormation()`):
  - V-formation: 5 enemies in V shape
  - Wall: 6 enemies in horizontal line
  - Spiral: 8 enemies in circular pattern
  - Formations use staggered shooting for visual variety
- Updated `spawnEnemy()`:
  - Checks for formation before scattered spawn
  - Applies speed_override from formations/difficulty
  - Adjusts fire rate based on enemy_fire_rate parameter
- Updated `updateEnemies()`:
  - Uses speed_override if present
  - Enemy bullet system triggers based on enemy_bullets_enabled
  - Maintains compatibility with variant enemy composition
- Updated `enemyShoot()`:
  - Bullets store custom speed parameter
  - Speed applied during bullet update
- Updated `updateBullets()`:
  - Enemy bullets use custom speed from bullet.speed
  - Fallback to BULLET_SPEED if not specified

**In-Game:**
- **Spawn Patterns**:
  - Continuous: Steady flow with difficulty scaling
  - Waves: 5+ enemies spawn quickly, then 3s pause
  - Clusters: 3-5 enemies at once, longer delays
- **Formations**:
  - V-formation: Coordinated attack from center
  - Wall: Horizontal barrier moving down
  - Spiral: Circular pattern surrounds player
  - Scattered: Random positioning (default)
- **Enemy Bullets**:
  - Enemies shoot downward at player
  - Configurable speed and fire rate
  - Adds bullet hell gameplay when enabled
  - Works with shield system from Phase 2
- **Difficulty Scaling**:
  - Linear: Gradual ramp-up over time
  - Exponential: Starts slow, becomes chaotic
  - Wave: Rhythm of hard/easy periods
  - Visible in enemy speed and spawn frequency
- **Speed Multipliers**:
  - Spawn rate affects enemy density
  - Speed multiplier makes enemies faster/slower
  - Both interact with difficulty scaling

**Testing:**
1. Test wave spawning:
   - Play Clone 17 "Wave Assault"
   - Verify enemies spawn in groups
   - Check for pauses between waves
   - Confirm wave size increases with difficulty
2. Test enemy bullets:
   - Play Clone 18 "Bullet Hell"
   - Verify enemies shoot at player
   - Check bullet speed and fire rate
   - Confirm shield blocks enemy bullets
   - Verify deaths increment when hit
3. Test formations:
   - Play Clone 19 "V-Formation"
   - Verify 5 enemies spawn in V shape
   - Check formation appears at top-center
   - Test other formation types (wall, spiral) if added to variants
4. Test difficulty scaling:
   - Play Clone 20 "Exponential Chaos"
   - Verify difficulty increases over time
   - Check spawn rate acceleration
   - Confirm enemy speed increases
   - Verify difficulty caps at 5.0x
5. Test clusters:
   - Play Clone 20 "Exponential Chaos" (uses clusters)
   - Verify 3-5 enemies spawn together
   - Check longer delays between spawns

**Test Variants**: 4 new variants added to `space_shooter_variants.json` (clones 17-20):
- Clone 17 "Wave Assault": Wave spawning with 1.5x spawn rate
- Clone 18 "Bullet Hell": Enemy bullets enabled, 2x spawn rate, 10 lives
- Clone 19 "V-Formation": V-formation enemies with burst fire
- Clone 20 "Exponential Chaos": Exponential scaling with clusters

**Status:** ✅ COMPLETE

**Notes for Phase 6:**
- Enemy systems fully functional with multiple patterns
- Difficulty scaling creates dynamic gameplay
- Enemy bullets add challenge without being unfair
- Formations create visual variety
- Next: Implement power-up spawning, types, duration, collection
- Consider adding visual effects for formation spawns
- Could add audio cues for wave start/end
- Enemy bullet patterns could be expanded (spread, aimed, etc.)

---

## PHASE 6: Power-Up System

### Duration: 2 days

### Goal
Implement collectible power-ups that modify player abilities temporarily.

### 6.1: Power-Up Spawning

**Parameters to Add**:
```lua
self.powerup_enabled = (runtimeCfg.powerup and runtimeCfg.powerup.enabled) or false
self.powerup_spawn_rate = (runtimeCfg.powerup and runtimeCfg.powerup.spawn_rate) or 10
-- Seconds between power-up spawns
self.powerup_types = (runtimeCfg.powerup and runtimeCfg.powerup.types) or {"speed", "shield", "weapon_upgrade"}
-- Available power-up types
```

**Power-Up Table**:
```lua
self.powerups = {} -- Active power-ups on screen
self.active_effects = {} -- Player's active power-up effects
```

### 6.2: Power-Up Types

**Implement these types**:
1. **Speed Boost**: Increase movement_speed by 50% for duration
2. **Shield**: Temporary invincibility
3. **Weapon Upgrade**: Multi-shot or spread pattern temporarily
4. **Rapid Fire**: Reduce fire cooldown by 50%
5. **Pierce**: Temporary bullet piercing
6. **Homing**: Temporary bullet homing

**Duration System**:
```lua
-- Each active effect has:
{
    type = "speed_boost",
    duration_remaining = 5.0,
    original_value = self.movement_speed,
}

-- In update(), decrement duration_remaining
-- When expired, restore original value
```

### 6.3: Collection and Display

**Logic**:
- Spawn power-ups at random x position
- Power-up drifts downward slowly
- Player collision = collect
- Show active effects in HUD
- Visual indicator on player (glow, particle effect)

### 6.4: Test Variants

- Power-Up Heaven: Frequent spawns, long duration
- Speed Demon: Only speed boosts
- Shield Tank: Only shield power-ups
- Weapon Festival: Only weapon upgrades

---
**PHASE 6 COMPLETION NOTES** (Date: 2025-01-11)

**Completed:**
- Added power-up system parameters with three-tier fallback:
  - `powerup_enabled` (boolean) - toggles power-up spawning
  - `powerup_spawn_rate` (1.0-60.0 seconds) - time between spawns
  - `powerup_duration` (1.0-30.0 seconds) - effect duration
  - `powerup_types` (array) - available power-up types
- Implemented six power-up types:
  - `speed`: Movement speed boost (1.5x multiplier)
  - `rapid_fire`: Fire rate boost (0.5x cooldown)
  - `pierce`: Temporary bullet piercing
  - `shield`: Instant shield refresh (if shield enabled)
  - `triple_shot`: Temporary triple shot pattern
  - `spread_shot`: Temporary spread shot pattern
- Added power-up spawning system in `updatePowerups()`:
  - Spawn timer countdown with configurable rate
  - Random type selection from available types
  - Power-ups drift downward at 50 px/sec
  - Removed when off-screen
- Implemented collection system:
  - Collision detection with player
  - Auto-apply effects on collection
  - Play sound on collection
  - Remove existing effect if collecting same type (refresh duration)
- Added duration tracking system:
  - Each active effect stored in `active_powerups` table
  - Duration countdown in update loop
  - Auto-restore original values when expired
  - Safely stores original values (PLAYER_SPEED, FIRE_COOLDOWN, etc.)
- Implemented power-up rendering in `space_shooter_view.lua`:
  - Colored circles for each type (cyan, yellow, magenta, blue, orange, green)
  - Filled circle with white outline
  - Type identified by color
- Added active power-up HUD display:
  - Shows powerup name and time remaining
  - Green text for active effects
  - Countdown timer in seconds
  - Dynamic row allocation

**In-Game:**
- **Power-Up Spawning**: Colored orbs drift down from top of screen
- **Collection**: Touch orb to activate effect
- **Visual Feedback**:
  - Speed: Cyan orb - player moves faster
  - Rapid Fire: Yellow orb - shoot faster
  - Pierce: Magenta orb - bullets go through enemies
  - Shield: Blue orb - shield instantly recharged
  - Triple Shot: Orange orb - fire 3 bullets
  - Spread Shot: Green orb - fire spread pattern
- **HUD Display**: Active effects shown with countdown timers
- **Duration System**: Effects expire after set duration
- **Stacking**: Same type refreshes duration (no multi-stack)

**Testing:**
1. Test power-up spawning:
   - Play Clone 21 "Power-Up Heaven" (5s spawn rate)
   - Verify power-ups spawn regularly
   - Check multiple types appear
   - Confirm they drift downward
2. Test power-up collection:
   - Touch different colored orbs
   - Verify effects activate immediately
   - Check HUD shows active effects
   - Confirm sound plays on collection
3. Test power-up effects:
   - Speed (cyan): Verify movement is faster
   - Rapid Fire (yellow): Verify faster shooting
   - Pierce (magenta): Bullets go through enemies
   - Shield (blue): Shield meter refills
   - Triple Shot (orange): Fires 3 bullets
   - Spread Shot (green): Fires spread pattern
4. Test duration system:
   - Collect power-up and wait
   - Verify countdown timer decreases
   - Confirm effect expires after duration
   - Check original values restored
5. Test single-type variants:
   - Clone 22 "Speed Demon": Only speed boosts
   - Clone 23 "Weapon Festival": Only weapon types
   - Verify only specified types spawn

**Test Variants**: 3 new variants added to `space_shooter_variants.json` (clones 21-23):
- Clone 21 "Power-Up Heaven": All types, 5s spawn, 10s duration
- Clone 22 "Speed Demon": Speed only, 8s spawn, 6s duration
- Clone 23 "Weapon Festival": Weapon types only, 7s spawn, 8s duration

**Status:** ✅ COMPLETE

**Notes for Phase 7:**
- Power-up system fully functional with 6 types
- Duration system works cleanly with save/restore
- Visual feedback clear with color coding
- Next: Implement environmental hazards (asteroids, meteors, gravity wells)
- Consider adding visual particle effects for active power-ups
- Could add power-up preview icons in HUD
- Shield power-up could grant temporary shield if not enabled

---

## PHASE 7: Environmental Hazards

### Duration: 2 days

### Goal
Add asteroids, meteors, gravity wells, and environmental obstacles.

### 7.1: Asteroid Field

**Parameters to Add**:
```lua
self.asteroid_density = (runtimeCfg.environment and runtimeCfg.environment.asteroid_density) or 0
-- 0 = none, 5 = moderate, 10 = dense field
self.asteroid_speed = (runtimeCfg.environment and runtimeCfg.environment.asteroid_speed) or 100
```

**Logic**:
- Spawn asteroids at top, drift downward
- Player collision = damage/life lost
- Shooting asteroids destroys them (optional)
- Asteroids can collide with enemies

### 7.2: Meteor Showers

**Parameters to Add**:
```lua
self.meteor_frequency = (runtimeCfg.environment and runtimeCfg.environment.meteor_frequency) or 0
-- Seconds between meteor waves, 0 = disabled
```

**Logic**:
- Spawn fast-moving meteors in waves
- Warning indicators before meteors appear
- Higher damage than regular asteroids

### 7.3: Gravity Wells

**Parameters to Add**:
```lua
self.gravity_wells_count = (runtimeCfg.environment and runtimeCfg.environment.gravity_wells) or 0
self.gravity_well_strength = (runtimeCfg.environment and runtimeCfg.environment.gravity_well_strength) or 200
```

**Logic**:
- Spawn stationary gravity wells
- Pull player and bullets toward center
- Visual: swirling vortex effect
- Can pull bullets into curved paths

### 7.4: Scroll Speed

**Parameters to Add**:
```lua
self.scroll_speed = (runtimeCfg.environment and runtimeCfg.environment.scroll_speed) or 0
-- Background/enemy vertical scrolling speed
```

**Logic**:
- Offset all enemy/hazard positions by scroll_speed * dt
- Creates vertical scrolling shooter feel
- Higher scroll = faster-paced gameplay

### 7.5: Test Variants

- Asteroid Belt: Dense asteroid field
- Meteor Storm: Frequent meteor waves
- Gravity Chaos: Multiple gravity wells
- Speed Scroller: High scroll speed

---
**PHASE 7 COMPLETION NOTES** (Date: 2025-01-11)

**Completed:**
- Added environmental hazard parameters with three-tier fallback:
  - `asteroid_density` (0-10) - asteroids spawned per second
  - `asteroid_speed` (20-400) - fall speed in pixels/second
  - `asteroid_size_min` (10-40) and `asteroid_size_max` (30-100) - size range
  - `asteroids_can_be_destroyed` (boolean) - can bullets destroy them
  - `meteor_frequency` (0-10) - meteor waves per minute
  - `meteor_speed` (100-800) - meteor fall speed
  - `meteor_warning_time` (0.1-3.0) - warning duration before meteor
  - `gravity_wells_count` (0-10) - number of gravity wells
  - `gravity_well_strength` (50-500) - pull strength
  - `gravity_well_radius` (50-300) - effect radius
  - `scroll_speed` (0-500) - vertical scrolling speed
- Implemented asteroid field system:
  - Spawn rate based on density parameter
  - Asteroids drift downward with rotation
  - Player collision causes damage
  - Optional bullet destruction (configurable)
  - Asteroids can destroy enemies on collision
- Implemented meteor shower system:
  - Countdown timer spawns meteor waves
  - Warning indicators show where meteors will appear
  - Configurable warning time before impact
  - Meteors are faster and more dangerous than asteroids
  - 3-5 meteors per wave
- Implemented gravity well system:
  - Spawned at initialization with random positions
  - Pulls player toward center (inverse square law)
  - Pulls bullets toward center (weaker effect)
  - Visual swirling vortex effect
  - Configurable strength and radius
- Implemented vertical scrolling:
  - Scroll speed affects asteroid and meteor movement
  - Creates vertical scrolling shooter feel
  - Higher scroll = faster-paced gameplay
- Updated rendering in `space_shooter_view.lua`:
  - Gray rotating asteroids with polygonal shapes
  - Red meteor warnings with "!" indicator at top
  - Orange/yellow meteors with glowing outline
  - Purple translucent gravity wells with radius visualization
- Updated hazard collision handling:
  - Asteroids check collision with player, bullets, enemies
  - Meteors check collision with player and bullets
  - Gravity wells apply force to player and bullets
  - All hazards removed when off-screen

**In-Game:**
- **Asteroid Field**:
  - Gray rotating rocks fall from top
  - Density controls spawn frequency
  - Can be shot (if enabled) or must be dodged
  - Asteroids destroy enemies on contact
- **Meteor Showers**:
  - Red warning circles appear at top
  - After warning time, meteors drop quickly
  - Waves of 3-5 meteors
  - Frequency controls waves per minute
- **Gravity Wells**:
  - Purple swirling zones
  - Pull player and bullets toward center
  - Creates curved bullet trajectories
  - Strategic positioning required
- **Vertical Scrolling**:
  - All hazards and enemies scroll faster
  - Classic vertical shooter feel
  - Increased pace and difficulty

**Testing:**
1. Test asteroid field:
   - Play Clone 24 "Asteroid Belt"
   - Verify asteroids spawn at density = 5
   - Check rotation and falling motion
   - Confirm bullets can destroy asteroids
   - Verify player damage on collision
2. Test meteor showers:
   - Play Clone 25 "Meteor Storm"
   - Verify warning indicators appear first
   - Check meteors spawn after warning time
   - Confirm fast falling speed
   - Test collision damage
3. Test gravity wells:
   - Play Clone 26 "Gravity Chaos"
   - Verify 3 gravity wells spawn
   - Check player is pulled toward wells
   - Confirm bullets curve toward wells
   - Test radius and strength effects
4. Test vertical scrolling:
   - Play Clone 27 "Speed Scroller"
   - Verify scroll speed = 150
   - Check asteroids/enemies fall faster
   - Confirm faster-paced gameplay

**Test Variants**: 4 new variants added to `space_shooter_variants.json` (clones 24-27):
- Clone 24 "Asteroid Belt": Density 5, destructible asteroids
- Clone 25 "Meteor Storm": Frequency 6, fast meteors with warnings
- Clone 26 "Gravity Chaos": 3 gravity wells, strong pull
- Clone 27 "Speed Scroller": Scroll speed 150, fast enemies

**Status:** ✅ COMPLETE

**Notes for Phase 8:**
- All environmental hazards fully functional
- Gravity wells create interesting bullet trajectories
- Meteor warnings give fair chance to dodge
- Vertical scrolling adds classic shooter feel
- Next: Special mechanics (screen wrap, reverse gravity, blackout zones) and victory conditions
- Consider adding particle effects for meteor impacts
- Could add visual trail for gravity well pull effect
- Asteroid explosions could spawn debris

---

## PHASE 8: Special Mechanics & Victory Conditions

### Duration: 2 days

### Goal
Implement screen wrap, reverse gravity, blackout zones, and victory condition variations.

### 8.1: Screen Wrap

**Parameters to Add**:
```lua
self.screen_wrap = (runtimeCfg.arena and runtimeCfg.arena.screen_wrap) or false
```

**Logic**:
- Player reaching edge wraps to opposite side (Asteroids-style)
- Bullets can also wrap if enabled
- Enemies can wrap (optional)

### 8.2: Reverse Gravity

**Parameters to Add**:
```lua
self.reverse_gravity = (runtimeCfg.arena and runtimeCfg.arena.reverse_gravity) or false
```

**Logic**:
- Player spawns at top instead of bottom
- Enemies spawn at bottom, move upward
- Bullets travel downward instead of up
- Inverts entire play space

### 8.3: Blackout Zones

**Parameters to Add**:
```lua
self.blackout_zones = (runtimeCfg.arena and runtimeCfg.arena.blackout_zones) or 0
-- Number of dark zones with limited visibility
```

**Logic**:
- Create circular zones where visibility is reduced
- Zones can move or stay static
- Player/bullets/enemies still interact normally
- Only visual obstruction

### 8.4: Victory Conditions

**Parameters to Add**:
```lua
self.victory_condition = (runtimeCfg.victory and runtimeCfg.victory.condition) or "kills"
-- Options: "kills", "time", "survival", "score"
self.victory_limit = (runtimeCfg.victory and runtimeCfg.victory.limit) or 50
```

**Conditions**:
- **Kills**: Destroy X enemies (current system)
- **Time**: Survive for X seconds
- **Survival**: Survive as long as possible (endless)
- **Score**: Reach X score points

**Logic**:
- Check victory condition in update()
- Display progress in HUD
- Game over when condition met

### 8.5: Test Variants

- Wraparound: Screen wrap enabled
- Upside Down: Reverse gravity
- Fog of War: Multiple blackout zones
- Speed Run: Time-based victory (30 seconds)

---
**PHASE 8 COMPLETION NOTES** (Date: 2025-01-11)

**Completed:**
- Screen wrap system (player, bullets, enemies independently controllable)
- Reverse gravity (flips entire play space upside down)
- Blackout zones (dark areas with optional movement)
- Victory conditions (kills, time, survival, score)
- 4 test variants (clones 28-31)

**Status:** ✅ COMPLETE

---

## PHASE 9: CheatEngine Integration

### Duration: 2 days

### Goal
Define CheatEngine parameter ranges and integrate with existing systems.

### 9.1: Parameter Ranges

**Add to config.lua**:
```lua
cheat_engine = {
    parameter_ranges = {
        -- Movement
        movement_speed = { min = 50, max = 500 },
        rotation_speed = { min = 1, max = 15 },

        -- Weapon
        fire_rate = { min = 0.5, max = 10 },
        bullet_speed = { min = 100, max = 1000 },
        ammo_capacity = { min = 10, max = 200 },
        overheat_threshold = { min = 3, max = 30 },

        -- Defense
        lives_count = { min = 1, max = 50 },
        shield_hits = { min = 1, max = 10 },

        -- Enemy
        enemy_spawn_rate = { min = 0.1, max = 5.0 },
        enemy_speed_multiplier = { min = 0.1, max = 3.0 },

        -- Power-ups
        powerup_spawn_rate = { min = 5, max = 60 },

        -- Environment
        asteroid_density = { min = 0, max = 20 },
        scroll_speed = { min = 0, max = 500 },
    },

    hidden_parameters = {
        "movement_type",
        "fire_mode",
        "bullet_pattern",
        "victory_condition",
        "enemy_spawn_pattern",
    },
}
```

### 9.2: Available Cheats

**Add to base_game_definitions.json**:
```json
"available_cheats": [
    {
        "id": "fire_rate_boost",
        "display_name": "Rapid Fire",
        "description": "Increase fire rate",
        "base_cost": 500,
        "max_level": 5,
        "value_per_level": 1.0,
        "affects": ["fire_rate"]
    },
    {
        "id": "extra_lives",
        "display_name": "Extra Lives",
        "description": "Increase starting lives",
        "base_cost": 1000,
        "max_level": 10,
        "value_per_level": 1,
        "affects": ["lives_count"]
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
        "id": "ammo_upgrade",
        "display_name": "Ammo Capacity",
        "description": "Increase ammo capacity",
        "base_cost": 600,
        "max_level": 5,
        "value_per_level": 20,
        "affects": ["ammo_capacity"]
    },
    {
        "id": "enemy_slowdown",
        "display_name": "Slow Enemies",
        "description": "Reduce enemy speed",
        "base_cost": 1500,
        "max_level": 3,
        "value_per_level": -0.2,
        "affects": ["enemy_speed_multiplier"]
    }
]
```

---

## PHASE 10: Variant JSON Creation

### Duration: 3 days

### Goal
Create 15-20 unique and interesting variant combinations.

### 10.1: Design Philosophy

**Variant Categories**:
1. **Easy Mode** variants (forgiving, for token farming)
2. **Hard Mode** variants (challenge runs)
3. **Gimmick** variants (unique mechanics)
4. **Balanced** variants (standard difficulty)

### 10.2: Example Variants

**Easy Variants**:
- Cruise Control: High lives, shield, slow enemies
- Ammo Heaven: Infinite ammo, no overheat
- Power Trip: Frequent power-ups, long duration

**Hard Variants**:
- One Life Wonder: 1 life, no shield, fast enemies
- Bullet Hell: Enemy bullets enabled, high fire rate
- Resource Scarcity: Low ammo, long reload, overheat enabled

**Gimmick Variants**:
- Gravity Madness: Multiple gravity wells, curved bullets
- Wraparound Chaos: Screen wrap, reverse gravity
- Speed Demon: Rail movement, high scroll speed, time limit

**Balanced Variants**:
- Classic Shooter: Default settings, slight difficulty scaling
- Formation Fighter: Enemy formations, moderate difficulty

### 10.3: JSON Structure

Each variant should have:
```json
{
    "clone_index": X,
    "name": "Descriptive Name",
    "sprite_set": "fighter_X",
    "palette": "color",
    "difficulty_modifier": 1.0,

    // Movement
    "movement_type": "default",
    "movement_speed": 200,

    // Weapon
    "fire_mode": "manual",
    "bullet_pattern": "single",
    "ammo_enabled": false,

    // Enemy
    "enemies": [...],
    "enemy_spawn_pattern": "continuous",

    // Environment
    "asteroid_density": 0,
    "scroll_speed": 0,

    // Victory
    "victory_condition": "kills",
    "victory_limit": 50,

    "flavor_text": "Description"
}
```

---

## PHASE 11: Testing & Balancing

### Duration: 3 days

### Goal
Test all variants, balance formulas, fix edge cases and bugs.

### 11.1: Testing Checklist

**For Each Variant**:
- [ ] Loads without errors
- [ ] All parameters apply correctly
- [ ] Victory condition works
- [ ] Token formula produces reasonable values
- [ ] No game-breaking bugs
- [ ] Performance is acceptable (60fps)
- [ ] Sprites/palette load correctly
- [ ] CheatEngine parameters work

### 11.2: Balance Formula

**Review and adjust token formulas**:
```lua
base_formula_string = "((metrics.kills * metrics.kills * 10 * scaling_constant) - (metrics.deaths * metrics.deaths * 5 * scaling_constant) + (metrics.accuracy * 100 * scaling_constant))"
```

**Considerations**:
- Easy variants should give lower tokens
- Hard variants should give higher tokens
- Accuracy bonus for skilled play
- Time survived bonus for survival modes

### 11.3: Bug Fixes

Common issues to check:
- Bullet/enemy collision edge cases
- Power-up stacking issues
- Ammo/overheat state conflicts
- Movement type edge transitions
- Victory condition edge cases

---

## PHASE 12: Documentation

### Duration: 1 day

### Goal
Complete all documentation for Space Shooter variants.

### 12.1: Update Modifier Docs

Complete `documentation/definitions/space_shooter_modifiers.md` with all implemented parameters.

### 12.2: Variant Guide

Create guide showing:
- Best variants for token farming
- Hardest variants for challenge
- Recommended CheatEngine builds per variant
- Interesting variant combinations

### 12.3: Implementation Notes

Document:
- Architecture patterns used
- Known limitations
- Future enhancement ideas
- Performance considerations

---

## Summary

**Total Duration**: ~28 days
**Total Phases**: 12 (Phases 1-3 complete, 4-12 planned)
**Estimated Final Code Size**: ~2,000-2,500 lines
**Parameter Count**: 50+ variant parameters
**Test Variants**: 15-20 unique variants
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
