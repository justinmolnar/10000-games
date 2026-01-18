# Game Components Refactor Documentation

This document chronicles the 16-phase refactoring effort that created a reusable game components system. The goal was to extract duplicated code from individual games into standardized, composable components.

---

## Phase 1: Component Extraction & View Standardization

**Commit:** `e848b1a053eb0d4ed22004b4ada42c9092a7f5ed`
**Date:** November 11, 2025

### Overview

Phase 1 focused on two major architectural improvements:
1. **BaseView Pattern** - Standardized windowed view rendering to fix recurring coordinate bugs
2. **MovementController Component** - Extracted reusable movement logic from games

### Files Added
- `src/views/base_view.lua` - New base class for windowed views
- `src/utils/game_components/movement_controller.lua` - Reusable movement system

### BaseView (`src/views/base_view.lua`)

**Purpose:** Eliminate recurring viewport vs screen coordinate bugs in windowed views.

**Problem Solved:** Views were inconsistently handling coordinate transformations, leading to bugs where:
- `love.graphics.setScissor()` was called with viewport coords instead of screen coords
- `love.graphics.origin()` was incorrectly called, breaking the transformation matrix
- Content rendered correctly only when window was at screen position (0,0)

**Pattern:**
```lua
-- Before: Each view handled coordinates differently
function MyView:drawWindowed(viewport_width, viewport_height)
    love.graphics.origin()  -- BUG: Breaks transformation matrix
    love.graphics.setScissor(0, 0, w, h)  -- BUG: Uses viewport coords
end

-- After: Extend BaseView and implement drawContent()
local BaseView = require('src.views.base_view')
local MyView = BaseView:extend('MyView')

function MyView:drawContent(viewport_width, viewport_height)
    -- Coordinates are already local to viewport (0,0 = top-left of window)
    self:setScissor(0, 0, w, h)  -- Automatically converts to screen coords
    -- ... render ...
    self:clearScissor()
end
```

**Helper Methods:**
- `self:setScissor(x, y, w, h)` - Converts viewport → screen coordinates
- `self:clearScissor()` - Safely clears scissor region
- `self:getViewportPosition()` - Returns viewport offset for debugging
- `self:isPointInViewport(x, y, w, h)` - Hit testing helper

### MovementController (`src/utils/game_components/movement_controller.lua`)

**Purpose:** Extract and reuse player/entity movement logic across games.

**Problem Solved:** Each game (Dodge, Space Shooter, Breakout) had its own copy of movement code with slight variations. This led to:
- Duplicated code (~400+ lines per game)
- Inconsistent behavior across games
- Harder to maintain and fix bugs

**Supported Movement Modes:**
1. **`direct`** - WASD/arrow keys with optional friction/momentum
2. **`asteroids`** - Thrust-based with rotation (like Asteroids)
3. **`rail`** - Locked to horizontal or vertical axis
4. **`jump`** - Teleport/dash movement with cooldown

**Usage:**
```lua
local MovementController = require('src.utils.game_components.movement_controller')

self.movement_controller = MovementController:new({
    mode = "direct",
    speed = 300,
    friction = 0.95,
    rotation_speed = 5.0
})

local input = {
    left = self:isKeyDown('a'),
    right = self:isKeyDown('d'),
    up = self:isKeyDown('w'),
    down = self:isKeyDown('s'),
    jump = self:isKeyDown('space')
}
local bounds = {x = 0, y = 0, width = 800, height = 600, wrap_x = false}
self.movement_controller:update(dt, self.player, input, bounds)
```

**Games Refactored:**
- `src/games/dodge_game.lua` (-421 lines of movement code)
- `src/games/breakout.lua`
- `src/games/space_shooter.lua`

---

## Phase 2: FogOfWar Component

**Commit:** `bf7890fa6276adbed1d9d87ba9c9d9764e22c418`
**Date:** November 12, 2025
**Note:** Phase 1 snake movement deferred to later phase

### Overview

Added a reusable fog of war system that creates visibility zones around entities.

### Files Added
- `src/utils/game_components/fog_of_war.lua` - Visibility management component

### FogOfWar (`src/utils/game_components/fog_of_war.lua`)

**Purpose:** Add visibility restrictions to games for increased difficulty or atmosphere.

**Two Rendering Modes:**

1. **Stencil Mode** - Dark overlay with circular visibility cutouts
   - Uses LÖVE2D stencil buffer for efficient rendering
   - Best for: Dodge, Breakout, Snake (player-centered visibility)

2. **Alpha Mode** - Per-entity alpha calculation with gradient
   - Calculates alpha based on distance from center
   - Best for: Memory Match (card visibility fade)

**Usage:**
```lua
local FogOfWar = require('src.utils.game_components.fog_of_war')

-- Stencil mode (common)
self.fog = FogOfWar:new({
    enabled = true,
    mode = "stencil",
    opacity = 0.8
})

-- In update:
self.fog:clearSources()
self.fog:addVisibilitySource(player.x, player.y, 100)

-- In draw (after game content, before HUD):
self.fog:render(arena_width, arena_height)

-- Alpha mode (Memory Match)
self.fog = FogOfWar:new({
    enabled = true,
    mode = "alpha",
    outer_radius = 200,
    inner_radius_multiplier = 0.4
})

-- When drawing cards:
local alpha = self.fog:calculateAlpha(card.x, card.y, center_x, center_y)
love.graphics.setColor(1, 1, 1, alpha)
```

**Games Integrated:**
- `src/games/breakout.lua`
- `src/games/dodge_game.lua`
- `src/games/memory_match.lua`
- `src/games/snake_game.lua`

---

## Phase 3: VisualEffects Component

**Commit:** `92dd15af54ae1febf80707e9bbf89462d1721279`
**Date:** November 12, 2025

### Overview

Unified visual effects system combining camera shake, screen flash, and particle effects into a single component.

### Files Added
- `src/utils/game_components/visual_effects.lua` - Combined effects system

### VisualEffects (`src/utils/game_components/visual_effects.lua`)

**Purpose:** Provide game juice (camera shake, flashes, particles) without affecting game logic or demo playback.

**Three Effect Systems:**

1. **Camera Shake**
   - Exponential decay mode (smooth)
   - Timer mode (linear fade)

2. **Screen Flash**
   - Fade out mode
   - Pulse mode (fade in then out)
   - Instant mode (hold then disappear)

3. **Particle Effects**
   - Ball trails (Breakout)
   - Confetti (Coin Flip, RPS)
   - Brick destruction particles

**Usage:**
```lua
local VisualEffects = require('src.utils.game_components.visual_effects')

self.effects = VisualEffects:new({
    camera_shake_enabled = true,
    screen_flash_enabled = true,
    particle_effects_enabled = true
})

-- Camera shake on hit
self.effects:shake(0.15, 5.0, "exponential")

-- Screen flash on victory
self.effects:flash({1, 1, 0, 0.5}, 0.2, "fade_out")

-- Particles
self.effects:emitConfetti(x, y, 20)
self.effects:emitBrickDestruction(brick.x, brick.y, brick.color)

-- In update:
self.effects:update(dt)

-- In draw:
self.effects:applyCameraShake()
-- ... draw game content ...
self.effects:drawScreenFlash(width, height)
self.effects:drawParticles()
```

**Games Integrated:**
- `src/games/breakout.lua`
- `src/games/coin_flip.lua`
- `src/games/dodge_game.lua`
- `src/games/rps.lua`

---

## Phase 4: AnimationSystem Component

**Commit:** `c9e45f009f34f8f28013d5600d130d6e550a87c6`
**Date:** November 12, 2025

### Overview

Created reusable animation helpers for common patterns: flip, bounce, and fade animations.

### Files Added
- `src/utils/game_components/animation_system.lua` - Animation factory functions

### AnimationSystem (`src/utils/game_components/animation_system.lua`)

**Purpose:** Standardize timer-based animations across games.

**Available Animation Types:**

1. **Flip Animation** - Rotation-based flip (coins, cards)
2. **Bounce Animation** - Sin wave offset (RPS hand throws)
3. **Fade Animation** - Alpha lerp (cards, UI elements)
4. **Timer** - Simple delay helper (auto-flip, delays)

**Usage:**
```lua
local AnimationSystem = require('src.utils.game_components.animation_system')

-- Flip animation (Coin Flip)
self.flip_anim = AnimationSystem.createFlipAnimation({
    duration = 0.5,
    speed_multiplier = 1.0,
    on_complete = function()
        self:revealResult()
    end
})
self.flip_anim:start()
self.flip_anim:update(dt)
local rotation = self.flip_anim:getRotation()

-- Bounce animation (RPS throws)
self.throw_anim = AnimationSystem.createBounceAnimation({
    duration = 0.5,
    height = 20
})
local y_offset = self.throw_anim:getOffset()

-- Fade animation
self.fade = AnimationSystem.createFadeAnimation({
    duration = 0.3,
    from = 0,
    to = 1
})
local alpha = self.fade:getAlpha()

-- Simple timer
self.delay = AnimationSystem.createTimer(2.0, function()
    self:autoFlip()
end)
```

**Games Integrated:**
- `src/games/coin_flip.lua`
- `src/games/rps.lua`

---

## Phase 5: PhysicsUtils Component

**Commit:** `446f172073706e403ad3d6a61bc3e5270448338f`
**Date:** November 12, 2025

### Overview

Extracted physics-related utilities: trails, screen wrapping, bouncing, and collision detection.

### Files Added
- `src/utils/game_components/physics_utils.lua` - Physics helper functions

### PhysicsUtils (`src/utils/game_components/physics_utils.lua`)

**Purpose:** Provide common physics operations as standalone functions.

**Available Utilities:**

1. **Trail System** - Creates trail effect following moving objects
2. **Screen Wrap** - Wraps position to opposite side when exiting bounds
3. **Bounce Physics** - Reflects velocity on boundary collision
4. **Clamp to Bounds** - Constrains position within bounds
5. **Collision Detection** - Circle and rectangle collision helpers

**Usage:**
```lua
local PhysicsUtils = require('src.utils.game_components.physics_utils')

-- Trail system (Dodge player, Breakout ball)
self.trail = PhysicsUtils.createTrailSystem({
    max_length = 10,
    color = {0.5, 0.8, 1, 1},
    line_width = 2
})
self.trail:addPoint(player.x, player.y)
self.trail:draw()

-- Screen wrap (Space Shooter)
player.x, player.y = PhysicsUtils.wrapPosition(
    player.x, player.y,
    player.width, player.height,
    arena_width, arena_height
)

-- Bounce off walls (Dodge, Breakout)
local new_vx, new_vy = PhysicsUtils.bounceOffWalls(
    ball.x, ball.y,
    ball.vx, ball.vy,
    ball.radius,
    arena_width, arena_height,
    0.9  -- restitution
)

-- Clamp to bounds (player movement)
player.x, player.y = PhysicsUtils.clampToBounds(
    player.x, player.y,
    player.width, player.height,
    arena_width, arena_height
)

-- Collision detection
local hit = PhysicsUtils.circleCollision(
    player.x, player.y, player.radius,
    enemy.x, enemy.y, enemy.radius
)
```

**Games Integrated:**
- `src/games/dodge_game.lua`
- `src/games/space_shooter.lua`

---

## Phase 6: ScoringSystem Standardization

**Commit:** `0974863108922d1b1cd3af98b29c5e26c08d06e6`
**Date:** November 12, 2025

### Overview

Standardized scoring logic across games. Integrated existing ScoringSystem component with games that weren't using it.

### Games Integrated
- `src/games/breakout.lua`
- `src/games/coin_flip.lua`
- `src/games/rps.lua`
- `src/games/score_popup.lua`

### ScoringSystem Integration

All games now use the standardized ScoringSystem component for:
- Score tracking
- Combo multipliers
- Token calculations
- Metrics recording

This ensures consistent scoring behavior and easier balancing across all games.

---

## Phase 7: VariantLoader Component

**Commit:** `70a60c27814eabfa49da840cb4180fcb385afff3`
**Date:** November 12, 2025

### Overview

Created VariantLoader to simplify three-tier parameter loading, reducing boilerplate in game initialization.

### Files Added
- `src/utils/game_components/variant_loader.lua` - Parameter loading utility
- `scripts/migrate_to_variant_loader.py` - Migration helper script
- `scripts/migrate_dodge_to_variant_loader.py` - Dodge-specific migration

### VariantLoader (`src/utils/game_components/variant_loader.lua`)

**Purpose:** Simplify the common pattern of loading parameters from variant → runtime config → defaults.

**Problem Solved:** Every game had verbose, repetitive code like:
```lua
-- Before: 10+ lines per parameter
local speed = (variant and variant.player_speed)
    or (runtime_config and runtime_config.player and runtime_config.player.speed)
    or DEFAULT_SPEED
```

**Three-Tier Lookup:**
1. **Variant** (highest priority) - Game clone-specific overrides
2. **Runtime Config** - DI-injected configuration
3. **Defaults** (lowest priority) - Hardcoded fallbacks

**Usage:**
```lua
local VariantLoader = require('src.utils.game_components.variant_loader')

local loader = VariantLoader:new(self.variant, runtime_config, {
    player_speed = 300,
    enemy_count = 10,
    arena_width = 800
})

-- Single value lookup
local speed = loader:get("player_speed", 300)

-- Typed getters
local count = loader:getNumber("enemy_count", 10)
local enabled = loader:getBoolean("fog_enabled", false)
local name = loader:getString("player_name", "Player 1")

-- Nested key access
local arena_w = loader:get("arena.width", 800)

-- Batch loading
local params = loader:getMultiple({
    player_speed = 300,
    enemy_count = 10,
    arena_width = 800
})
```

**Games Refactored:**
- `src/games/breakout.lua` (~70 lines reduced)
- `src/games/coin_flip.lua`
- `src/games/dodge_game.lua`
- `src/games/memory_match.lua`
- `src/games/rps.lua`
- `src/games/snake_game.lua`
- `src/games/space_shooter.lua` (~160 lines reduced)

**Impact:** Reduced parameter loading code by 40-60% across all games.

---

## Phase 8: HUDRenderer Component

**Commit:** `efdac6a563fa8638cbaeec96841954295a71ebf6`
**Date:** November 12, 2025

### Overview

Created HUDRenderer to standardize HUD layout across all games, eliminating duplicated HUD drawing code.

### Files Added
- `src/utils/game_components/hud_renderer.lua` - Standardized HUD component

### HUDRenderer (`src/utils/game_components/hud_renderer.lua`)

**Purpose:** Enforce consistent HUD layout across all games:
- **Top-Left:** Primary metric (score/progress)
- **Top-Right:** Lives/Health
- **Top-Center:** Timer (optional)
- **Bottom:** Progress bar (optional)

**Problem Solved:** Each game had its own HUD drawing code with inconsistent positioning, styling, and formatting.

**Features:**
- Automatic VM mode handling (hides HUD, exposes metrics)
- Nested key path support (`metrics.score`, `time_remaining`)
- Multiple format types: number, float, percent, time, ratio
- Hearts or number style for lives display
- Optional progress bar with fill animation

**Usage:**
```lua
local HUDRenderer = require('src.utils.game_components.hud_renderer')

self.hud = HUDRenderer:new({
    primary = {label = "Score", key = "metrics.score"},
    secondary = {label = "Dodged", key = "metrics.objects_dodged"},
    lives = {key = "lives", max = 3, style = "hearts"},
    timer = {key = "time_remaining", label = "Time", format = "time"},
    progress = {
        label = "Wave",
        current_key = "wave",
        total_key = "max_waves",
        show_bar = true
    }
})
self.hud.game = self  -- Required: link to game instance

-- In view draw():
self.game.hud:draw(viewport_width, viewport_height)
```

**Key Path Examples:**
- `"score"` → `game.score`
- `"metrics.kills"` → `game.metrics.kills`
- `"time_remaining"` → `game.time_remaining`

**Games Integrated:**
- `src/games/breakout.lua`
- `src/games/coin_flip.lua`
- `src/games/dodge_game.lua`
- `src/games/hidden_object.lua`
- `src/games/memory_match.lua`
- `src/games/rps.lua`
- `src/games/snake_game.lua`
- `src/games/space_shooter.lua`

**Impact:** Removed 200-300 lines of duplicated HUD code from view files.

---

## Phase 9: VictoryCondition Component

**Commit:** `5791b4a51a4f44e63aaa44797b6751daf2716f44`
**Date:** November 12, 2025

### Overview

Created VictoryCondition to unify win/loss checking logic across all games.

### Files Added
- `src/utils/game_components/victory_condition.lua` - Win/loss state manager

### VictoryCondition (`src/utils/game_components/victory_condition.lua`)

**Purpose:** Standardize victory/loss condition checking across all games.

**Problem Solved:** Each game had custom victory/loss logic with different patterns:
- Some checked lives first, some checked objectives first
- Inconsistent handling of edge cases (time expiring vs lives depleted)
- Hard to add new condition types

**Victory Types:**
- `threshold` - Reach target value (kills, dodges, matches)
- `time_survival` - Survive until time expires
- `time_limit` - Complete before time expires
- `streak` - Consecutive successes
- `ratio` - Maintain accuracy percentage
- `clear_all` - Eliminate all targets
- `rounds` - Win X rounds (turn-based games)
- `endless` - Never completes (survival mode)
- `multi` - Multiple conditions (OR logic)

**Loss Types:**
- `lives_depleted` - Lives/health reach 0
- `time_expired` - Countdown reaches 0
- `move_limit` - Attempts exhausted
- `death_event` - Instant failure flag
- `threshold` - Enemy reaches target
- `penalty` - Special failure condition
- `none` - No loss condition

**Usage:**
```lua
local VictoryCondition = require('src.utils.game_components.victory_condition')

self.victory_checker = VictoryCondition:new({
    victory = {
        type = "threshold",
        metric = "objects_found",
        target = self.total_objects
    },
    loss = {
        type = "time_expired",
        metric = "time_remaining"
    },
    check_loss_first = true
})
self.victory_checker.game = self

-- In checkComplete():
local result = self.victory_checker:check()
if result then
    self.victory = (result == "victory")
    self.game_over = (result == "loss")
    return true
end
```

**Games Integrated:**
- All 8 minigames now use VictoryCondition

---

## Phase 10: LivesHealthSystem Component

**Commit:** `e3307ef2e8c09c685611b52d9e31e572637565a0`
**Date:** November 12, 2025
**Note:** Space Shooter shields deferred to powerup phase

### Overview

Created unified lives/health/shield management component.

### Files Added
- `src/utils/game_components/lives_health_system.lua` - Health management

### LivesHealthSystem (`src/utils/game_components/lives_health_system.lua`)

**Purpose:** Handle damage, death, respawning, shields, and invincibility uniformly.

**Modes:**
- `lives` - Standard lives counter (Breakout, Coin Flip, RPS)
- `shield` - Regenerating shield hits (Space Shooter)
- `binary` - Instant death on failure (Dodge, Snake)
- `none` - No health system (Memory Match, Hidden Object)

**Features:**
- Invincibility frames after damage
- Shield regeneration with delay
- Extra life awards at score thresholds
- Respawn timers
- Damage/death/respawn callbacks

**Usage:**
```lua
local LivesHealthSystem = require('src.utils.game_components.lives_health_system')

self.health_system = LivesHealthSystem:new({
    mode = "lives",
    starting_lives = 3,
    max_lives = 10,
    invincibility_on_hit = true,
    invincibility_duration = 2.0,
    on_death = function()
        self:handlePlayerDeath()
    end
})

-- In update:
self.health_system:update(dt)

-- When player is hit:
self.health_system:takeDamage(1, "enemy")

-- Get current lives:
local lives = self.health_system:getLives()
```

**Games Integrated:**
- `src/games/breakout.lua`
- `src/games/coin_flip.lua`
- `src/games/dodge_game.lua`
- `src/games/rps.lua`

---

## Phase 11: EntityController Component

**Commit:** `4eda407026568d1e44779aad95d95021f3c6b03c`
**Date:** November 14, 2025

### Overview

Created generic enemy/obstacle spawning and management system with object pooling.

### Files Added
- `src/utils/game_components/entity_controller.lua` - Entity management (500 lines)

### EntityController (`src/utils/game_components/entity_controller.lua`)

**Purpose:** Handle entity lifecycle: spawning, movement, collision, pooling.

**Spawning Modes:**
- `continuous` - Spawn at regular rate
- `wave` - Spawn in waves
- `grid` - Spawn in grid layout (Breakout bricks)
- `manual` - No auto-spawning

**Features:**
- Entity type definitions with inheritance
- Object pooling for performance
- Spatial partitioning (optional)
- Lifecycle callbacks (spawn, hit, death)
- Multiple collision detection methods

**Usage:**
```lua
local EntityController = require('src.utils.game_components.entity_controller')

self.entity_controller = EntityController:new({
    entity_types = {
        ["hidden_object"] = {
            size = 20,
            radius = 10,
            found = false,
            on_hit = function(entity)
                entity.found = true
                self.objects_found = self.objects_found + 1
            end
        }
    },
    spawning = {mode = "manual"},
    pooling = true,
    max_entities = 50
})

-- Spawn entities:
self.entity_controller:spawn("hidden_object", x, y, {id = 1})

-- Grid spawning (Breakout):
self.entity_controller:spawnGrid("brick", rows, cols, x_offset, y_offset, spacing_x, spacing_y)

-- Check collisions:
local collisions = self.entity_controller:checkCollision(player, function(entity)
    -- Handle collision
end)

-- In draw:
self.entity_controller:draw(function(entity)
    -- Custom draw logic
end)
```

**Games Fully Migrated:**
- `src/games/hidden_object.lua` (~60-80 lines eliminated)
- `src/games/breakout.lua` (~150-200 lines eliminated)

**Games Deferred (too complex):**
- Dodge, Snake, Space Shooter - marked for incremental migration

---

## Phase 12: ProjectileSystem Component

**Commit:** `b8596b1fadcf0355914b6ad8026ad892375e3f00`
**Date:** November 14, 2025

### Overview

Created generic projectile/bullet system with movement patterns and pooling.

### Files Added
- `src/utils/game_components/projectile_system.lua` - Projectile management (419 lines)

### ProjectileSystem (`src/utils/game_components/projectile_system.lua`)

**Purpose:** Handle projectile spawning, movement, collision, and lifetime.

**Movement Types:**
- `linear` - Straight line movement
- `homing` - Track and follow target
- `sine_wave` - Oscillating movement
- `bounce` - Bounce off walls (Breakout ball)
- `arc` - Gravity-affected arc

**Features:**
- Team-based friendly fire logic
- Piercing projectiles
- Object pooling (500+ bullets)
- Lifetime tracking
- Collision callbacks

**Usage:**
```lua
local ProjectileSystem = require('src.utils.game_components.projectile_system')

self.projectile_system = ProjectileSystem:new({
    projectile_types = {
        ["player_bullet"] = {
            speed = 400,
            damage = 1,
            radius = 3,
            lifetime = 5.0,
            team = "player",
            piercing = false
        },
        ["ball"] = {
            speed = 300,
            radius = 8,
            movement_type = "bounce",
            bounce_bottom = false  -- Die at bottom
        }
    },
    pooling = true,
    max_projectiles = 500
})

-- Fire projectile:
self.projectile_system:shoot("player_bullet", x, y, angle)

-- Update with bounds:
local bounds = {x_min = 0, x_max = 800, y_min = 0, y_max = 600}
self.projectile_system:update(dt, bounds)

-- Check collisions:
self.projectile_system:checkCollisions(enemies, function(proj, enemy)
    -- Handle hit
end, "player")

-- Draw:
self.projectile_system:draw(function(proj)
    love.graphics.circle("fill", proj.x, proj.y, proj.radius)
end)
```

**Games Integrated:**
- `src/games/breakout.lua` (ball as bouncing projectile)
- `src/games/dodge_game.lua`
- `src/games/space_shooter.lua`

---

## Phase 13: (Skipped)

Phase 13 does not exist in the commit history. It was either:
- Merged into another phase
- Planned but not implemented
- Skipped during numbering

---

## Phase 14: ScoringSystem Component (Enhanced)

**Commit:** `bcbc1a3c87399db91a82d146b854a1ede51d4c65`
**Date:** November 14, 2025

### Overview

Created data-driven scoring/formula component supporting both legacy formulas and declarative configuration.

### Files Added
- `src/utils/game_components/scoring_system.lua` - Formula-based scoring (318 lines)

### ScoringSystem (`src/utils/game_components/scoring_system.lua`)

**Purpose:** Calculate token values from game metrics using configurable formulas.

**Curve Types:**
- `linear` - Direct multiplication
- `sqrt` - Square root scaling (diminishing returns)
- `log` - Logarithmic scaling (heavy diminishing returns)
- `exponential` - Exponential growth
- `binary` - Boolean (on/off) contribution
- `power` - Custom exponent

**Two Modes:**

1. **Formula String Mode** (legacy compatibility):
```lua
self.scoring = ScoringSystem:new({
    formula_string = "((metrics.dodges - metrics.deaths * 3) * 10 * scaling_constant)",
    scaling_constant = 1.0
})
```

2. **Declarative Mode** (recommended):
```lua
self.scoring = ScoringSystem:new({
    base_value = 100,
    metrics = {
        dodges = {weight = 1.0, curve = "sqrt", scale = 10},
        time = {weight = 2.0, curve = "linear", scale = 5}
    },
    multipliers = {
        difficulty = {easy = 0.8, normal = 1.0, hard = 1.5}
    }
})

-- Calculate tokens:
local tokens = self.scoring:calculate(self.metrics, {difficulty = "normal"})

-- Get detailed breakdown (for debugging):
local breakdown = self.scoring:getBreakdown(self.metrics, {difficulty = "normal"})
-- Returns: {base, metrics = {}, multipliers = {}, subtotal, total}
```

**Benefits:**
- Balancing without code changes
- Detailed breakdowns for debugging
- Support for complex scoring curves
- Per-metric weight and transformation

---

## Phase 15: PowerupSystem Component

**Commit:** `09f2313d964ecbcaec8496cdf710274deba1d20e`
**Date:** November 15, 2025

### Overview

Created generic powerup/pickup system with spawning, collection, and timed effects.

### Files Added
- `src/utils/game_components/powerup_system.lua` - Powerup management (374 lines)

### PowerupSystem (`src/utils/game_components/powerup_system.lua`)

**Purpose:** Handle powerup spawning, movement, collection, and active effect duration.

**Spawn Modes:**
- `timer` - Automatic spawning at intervals
- `event` - Manual spawning (e.g., from brick destruction)
- `both` - Combined timer and event
- `manual` - Alias for event

**Features:**
- Falling powerups with gravity
- Collision detection and collection
- Active effect duration tracking
- Effect stacking/refreshing
- Game-specific hooks for application/removal

**Usage:**
```lua
local PowerupSystem = require('src.utils.game_components.powerup_system')

self.powerup_system = PowerupSystem:new({
    enabled = true,
    spawn_mode = "event",
    spawn_drop_chance = 0.2,  -- 20% drop rate
    powerup_size = 20,
    drop_speed = 150,
    default_duration = 10.0,
    powerup_types = {"speed", "shield", "multiball"},
    powerup_configs = {
        speed = {duration = 8.0, multiplier = 1.5},
        shield = {duration = 15.0},
        multiball = {duration = 0, count = 2}  -- Instant effect
    },
    color_map = {
        speed = {0, 1, 1},
        shield = {1, 1, 0},
        multiball = {1, 0, 1}
    },

    -- Game-specific hooks
    on_apply = function(powerup_type, effect, config)
        if powerup_type == "speed" then
            self.paddle_speed = self.paddle_speed * config.multiplier
        end
    end,
    on_remove = function(powerup_type, effect)
        if powerup_type == "speed" then
            self.paddle_speed = self.base_paddle_speed
        end
    end
})

-- Spawn from brick destruction:
self.powerup_system:spawn(brick.x, brick.y)

-- Update:
self.powerup_system:update(dt, self.paddle, {width = 800, height = 600})

-- Check active effects:
if self.powerup_system:hasActiveEffect("shield") then
    -- Player is shielded
end

-- Render:
for _, powerup in ipairs(self.powerup_system:getPowerupsForRendering()) do
    local color = self.powerup_system:getColorForType(powerup.type)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", powerup.x, powerup.y, powerup.width, powerup.height)
end
```

**Games Integrated:**
- `src/games/breakout.lua` (speed, multiball, etc.)
- `src/games/space_shooter.lua` (shields, rapid fire, etc.)

---

## Phase 16: Documentation

**Commit:** `78380a33f5cde909dfdc7066944a792a1861255f`
**Date:** November 15, 2025

### Overview

Added comprehensive documentation of the Game Components System to CLAUDE.md.

### Changes
- Added 72 lines to `CLAUDE.md` documenting all 13 components
- Documented development impact metrics
- Added quick start example
- Listed best practices

### Documentation Added

The "Game Components System" section in CLAUDE.md now includes:
- List of all 13 components organized by category
- Development impact statistics (-50% new game creation time)
- Quick start code example
- References to detailed documentation files
- Best practices for component usage

This phase marked the completion of the component extraction refactor.

---

## Summary

### Components Created (13 Total)

| Phase | Component | Purpose |
|-------|-----------|---------|
| 1 | BaseView | Standardized windowed view rendering |
| 1 | MovementController | Reusable player/entity movement |
| 2 | FogOfWar | Visibility zones and darkness overlays |
| 3 | VisualEffects | Camera shake, screen flash, particles |
| 4 | AnimationSystem | Flip, bounce, fade animations |
| 5 | PhysicsUtils | Trails, wrapping, bouncing, collision |
| 6 | (Integration) | ScoringSystem standardization |
| 7 | VariantLoader | Three-tier parameter loading |
| 8 | HUDRenderer | Standardized HUD display |
| 9 | VictoryCondition | Win/loss state management |
| 10 | LivesHealthSystem | Lives, health, shields, invincibility |
| 11 | EntityController | Enemy/obstacle spawning, pooling, waves |
| 12 | ProjectileSystem | Bullet firing, movement patterns, pooling |
| 13 | (Skipped) | — |
| 14 | ScoringSystem | Data-driven formula-based scoring |
| 15 | PowerupSystem | Powerup spawning, collection, timed effects |
| 16 | (Documentation) | CLAUDE.md component documentation |

### Code Reduction Estimates

- **Movement code:** ~1,200 lines removed (3 games × 400 lines)
- **Parameter loading:** ~500 lines removed (7 games × 70 lines avg)
- **HUD rendering:** ~300 lines removed (8 games × 40 lines avg)
- **Victory/loss logic:** ~200 lines removed (8 games × 25 lines avg)
- **Lives/health logic:** ~300 lines removed (4 games × 75 lines avg)
- **Entity management:** ~250 lines removed (2 games migrated)
- **Projectile logic:** ~400 lines removed (3 games × 130 lines avg)
- **Powerup logic:** ~300 lines removed (2 games × 150 lines avg)
- **Total:** ~3,500-5,000+ lines of duplicated code eliminated

### Timeline

| Date | Phases |
|------|--------|
| Nov 11, 2025 | Phase 1 |
| Nov 12, 2025 | Phases 2-10 |
| Nov 14, 2025 | Phases 11-14 |
| Nov 15, 2025 | Phases 15-16 |

### Benefits

1. **Consistency:** All games behave the same way for common operations
2. **Maintainability:** Fix bugs in one place, affects all games
3. **Development Speed:** New game creation reduced by ~50% (3-4 hours → 1.5-2 hours)
4. **Demo Compatibility:** All components designed to work with fixed timestep
5. **Variant Support:** Components integrate with variant system for game clones
6. **Performance:** Object pooling in EntityController and ProjectileSystem
7. **Debugging:** Detailed breakdowns available (ScoringSystem, VictoryCondition)

### Component Dependencies

```
VariantLoader (load parameters)
     ↓
MovementController, LivesHealthSystem, ScoringSystem (core systems)
     ↓
EntityController, ProjectileSystem, PowerupSystem (entity management)
     ↓
VictoryCondition (win/loss checking)
     ↓
HUDRenderer (display)
     ↓
VisualEffects, AnimationSystem, FogOfWar (visual polish)
```

### Files Location

All components are in `src/utils/game_components/`:
- `movement_controller.lua`
- `fog_of_war.lua`
- `visual_effects.lua`
- `animation_system.lua`
- `physics_utils.lua`
- `variant_loader.lua`
- `hud_renderer.lua`
- `victory_condition.lua`
- `lives_health_system.lua`
- `entity_controller.lua`
- `projectile_system.lua`
- `scoring_system.lua`
- `powerup_system.lua`
