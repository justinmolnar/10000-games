# Game Engine Architecture

**Date:** January 2026
**Goal:** Build a component library where new games are ~90% JSON configuration + ~50-100 lines of Lua wiring

---

## The Vision: Pac-Man in 30 Minutes

When adding a new Pac-Man clone, the process should be:

```
1. "Grid movement" → GridMovementController ✓
2. "Maze walls" → ArenaController (grid mode + wall data) ✓
3. "Ghosts route toward player" → AIBehaviorController (pathfinding mode) ✓
4. "Screen wrap tunnels" → ArenaController (wrap zones) ✓
5. "Collect dots" → EntityController + ScoringSystem ✓
6. "Power pellets" → PowerupSystem ✓
7. "Lives/death" → LivesHealthSystem ✓
8. "Victory when all dots eaten" → VictoryCondition ✓
```

**Result:** Write JSON config + ~50 lines of Lua = Pac-Man clone done.

---

## Component Library (What We're Building)

### Tier 1: Movement & Space

| Component | What It Does | Example Uses |
|-----------|--------------|--------------|
| **GridMovementController** | Discrete cell-based movement | Pac-Man, Snake, Sokoban, Chess |
| **ContinuousMovementController** | Smooth pixel movement | Asteroids, Dodge, Shooter |
| **ArenaController** | Play area bounds, walls, wrap zones | ALL games |

### Tier 2: Entities & Spawning

| Component | What It Does | Example Uses |
|-----------|--------------|--------------|
| **EntityController** | Spawn, pool, track game objects | Enemies, collectibles, obstacles |
| **SpawnPatternController** | WHERE and WHEN to spawn | Waves, formations, layouts, grids |
| **TrailSystem** | Position history (physical or visual) | Snake body, ghosting effects |

### Tier 3: AI & Behaviors

| Component | What It Does | Example Uses |
|-----------|--------------|--------------|
| **AIBehaviorController** | Movement AI (chase, flee, patrol, pathfind) | Ghosts, enemies, AI opponents |
| **AIDecisionController** | Choice AI (what action to take) | RPS opponent, card game AI |

### Tier 4: Combat & Interaction

| Component | What It Does | Example Uses |
|-----------|--------------|--------------|
| **ProjectileSystem** | Bullets, balls, thrown objects | Shooter, Breakout, throwing games |
| **CollisionSystem** | Detect and respond to overlaps | ALL games |
| **PowerupSystem** | Temporary/permanent buffs | Most action games |

### Tier 5: Game State

| Component | What It Does | Example Uses |
|-----------|--------------|--------------|
| **LivesHealthSystem** | Lives, HP, shields, invincibility | Most games |
| **ScoringSystem** | Points, combos, multipliers | Most games |
| **VictoryCondition** | Win/lose detection | ALL games |
| **TurnController** | Round-based state machine | Card games, RPS, puzzle games |

### Tier 6: Presentation

| Component | What It Does | Example Uses |
|-----------|--------------|--------------|
| **HUDRenderer** | Score, lives, timer display | ALL games |
| **VisualEffects** | Particles, shake, flash | ALL games |
| **AnimationSystem** | Sprite animation | ALL games |
| **FogOfWar** | Visibility masking | Memory Match, exploration |

### Tier 7: Configuration

| Component | What It Does | Example Uses |
|-----------|--------------|--------------|
| **SchemaLoader** | Auto-load all params from JSON | ALL games |
| **DifficultyController** | Scale parameters over time | ALL games |

---

## Game Definition Schema

A game is defined by JSON that specifies which components to use and how to configure them:

```json
{
    "id": "pacman_1",
    "game_class": "GridGame",
    "display_name": "Pac-Man Classic",

    "arena": {
        "type": "grid",
        "width": 28,
        "height": 31,
        "cell_size": 16,
        "walls": "pacman_maze_1.json",
        "wrap_zones": [
            { "from": [0, 14], "to": [27, 14] }
        ]
    },

    "player": {
        "movement": "grid",
        "speed": 8,
        "start_position": [14, 23]
    },

    "entities": {
        "dots": {
            "layout": "fill_empty",
            "exclude": ["ghost_house", "player_start"],
            "on_collect": { "score": 10, "sound": "chomp" }
        },
        "power_pellets": {
            "positions": [[1,3], [26,3], [1,23], [26,23]],
            "on_collect": {
                "score": 50,
                "trigger_powerup": "ghost_vulnerable",
                "duration": 8
            }
        },
        "ghosts": {
            "count": 4,
            "ai_behavior": "pathfind_to_player",
            "scatter_behavior": "patrol_corners",
            "vulnerable_behavior": "flee_player",
            "respawn_at": "ghost_house"
        }
    },

    "victory": {
        "type": "collect_all",
        "target": "dots"
    },

    "lives": {
        "starting": 3,
        "death_on": "ghost_collision"
    },

    "scoring": {
        "ghost_kill_base": 200,
        "ghost_kill_chain": [200, 400, 800, 1600]
    }
}
```

**The Lua file becomes:**

```lua
local GridGame = require('src.games.base_grid_game')
local PacMan = GridGame:extend('PacMan')

function PacMan:initCustom()
    -- Only truly unique logic goes here
    -- e.g., ghost house door timing, fruit spawning logic
end

function PacMan:onGhostCollision(ghost)
    if self.powerup_system:isActive("ghost_vulnerable") then
        self:killGhost(ghost)
    else
        self.lives:loseLife()
    end
end

return PacMan
```

**That's it. ~30 lines of Lua.**

---

## Validation: Classic Games → Component Mapping

### Pac-Man
| Need | Component | Config |
|------|-----------|--------|
| Grid movement | GridMovementController | `speed: 8, queued_turns: true` |
| Maze walls | ArenaController | `type: "grid", walls: "maze.json"` |
| Side tunnels | ArenaController | `wrap_zones: [{from, to}]` |
| Dots | EntityController | `layout: "fill_empty"` |
| Ghosts chase | AIBehaviorController | `behavior: "pathfind", target: "player"` |
| Ghosts scatter | AIBehaviorController | `behavior: "patrol", waypoints: [...]` |
| Power pellets | PowerupSystem | `effect: "ghost_vulnerable", duration: 8` |
| Lives | LivesHealthSystem | `starting: 3` |
| Win condition | VictoryCondition | `type: "collect_all", target: "dots"` |

**Lua needed:** ~30 lines (ghost house logic, chain scoring)

### Tetris
| Need | Component | Config |
|------|-----------|--------|
| Falling pieces | GridMovementController | `gravity: true, gravity_speed: 1` |
| Piece rotation | GridMovementController | `rotation: true, wall_kicks: true` |
| Line clearing | EntityController | `on_row_full: "clear"` |
| Piece preview | EntityController | `preview_count: 3` |
| Hard/soft drop | GridMovementController | `soft_drop: 20x, hard_drop: instant` |
| Level speedup | DifficultyController | `gravity_speed: level * 0.1` |
| Game over | VictoryCondition | `type: "fail_on", condition: "spawn_blocked"` |

**Lua needed:** ~50 lines (rotation logic, piece shapes)

### Pong
| Need | Component | Config |
|------|-----------|--------|
| Paddle movement | ContinuousMovementController | `axis: "vertical", speed: 300` |
| Ball physics | ProjectileSystem | `bounce: true, speed_increase: 1.05` |
| AI paddle | AIBehaviorController | `behavior: "track", target: "ball.y"` |
| Score to win | VictoryCondition | `type: "score", target: 11` |
| Serve system | TurnController | `states: ["serve", "play", "point"]` |

**Lua needed:** ~20 lines (serve direction, paddle collision angles)

### Frogger
| Need | Component | Config |
|------|-----------|--------|
| Grid hop movement | GridMovementController | `discrete: true, hop_cooldown: 0.2` |
| Scrolling lanes | EntityController | `lanes: [...], scroll_speed: [...]` |
| Safe zones | ArenaController | `zones: [{type: "safe"}, {type: "water"}]` |
| Riding logs | CollisionSystem | `ride_on: ["log", "turtle"]` |
| Timer | VictoryCondition | `time_limit: 30, fail_on_timeout: true` |
| Fill homes | VictoryCondition | `type: "fill_all", target: "homes"` |

**Lua needed:** ~40 lines (lane definitions, turtle diving)

### Asteroids
| Need | Component | Config |
|------|-----------|--------|
| Thrust movement | ContinuousMovementController | `thrust: true, drag: 0.98, rotation: true` |
| Screen wrap | ArenaController | `wrap: "all_entities"` |
| Shooting | ProjectileSystem | `fire_rate: 0.2, bullet_speed: 500` |
| Asteroid splitting | EntityController | `on_death: "split", split_count: 2` |
| UFO spawning | SpawnPatternController | `timer: 30, type: "ufo"` |
| Wave progression | DifficultyController | `asteroid_count: wave + 3` |

**Lua needed:** ~30 lines (split sizes, UFO targeting)

### Sokoban
| Need | Component | Config |
|------|-----------|--------|
| Grid push | GridMovementController | `push: true, push_limit: 1` |
| Box entities | EntityController | `pushable: true` |
| Target zones | ArenaController | `goal_zones: [...]` |
| Win condition | VictoryCondition | `type: "all_on_goals", entity: "box"` |
| Undo system | *NEW: HistoryController* | `max_undo: 100` |
| Level loading | SchemaLoader | `level: "sokoban_levels.json"` |

**Lua needed:** ~20 lines (push validation)
**Gap identified:** HistoryController for undo/redo

### Match-3 (Bejeweled)
| Need | Component | Config |
|------|-----------|--------|
| Grid swap | GridMovementController | `swap_adjacent: true` |
| Match detection | *NEW: PatternMatcher* | `match_length: 3, directions: ["h", "v"]` |
| Cascade/gravity | EntityController | `gravity: true, fill_from_top: true` |
| Scoring | ScoringSystem | `chain_multiplier: 1.5` |
| No moves = lose | VictoryCondition | `fail_on: "no_valid_moves"` |

**Lua needed:** ~40 lines (special gem effects)
**Gap identified:** PatternMatcher for line detection

---

## Component Gaps Identified

From the classic game analysis, we need to add:

| Component | Purpose | Games Needing It |
|-----------|---------|------------------|
| **HistoryController** | Undo/redo state snapshots | Sokoban, Chess, any puzzle |
| **PatternMatcher** | Detect lines/shapes in grid | Match-3, Tetris line clear |
| **LevelLoader** | Load level layouts from JSON | Pac-Man mazes, Sokoban levels |

These are small (~50-80 lines each) but enable entire game genres.

---

## What This Means for Current Games

| Current Game | Lines Now | Lines After | Reduction |
|--------------|-----------|-------------|-----------|
| Snake | 2,693 | ~80 | 97% |
| Space Shooter | 2,551 | ~120 | 95% |
| Dodge | 1,980 | ~60 | 97% |
| Breakout | 1,766 | ~100 | 94% |
| Memory Match | 1,069 | ~50 | 95% |
| RPS | 963 | ~40 | 96% |
| Coin Flip | 661 | ~30 | 95% |

---

## Games Analyzed (Reference)

| Game | Current Lines | Target Lines | Complexity | Type |
|------|---------------|--------------|------------|------|
| Snake | 2,693 | ~150-200 | Simple rules, complex variants | Continuous |
| Space Shooter | 2,551 | ~200-250 | Complex systems, many modes | Continuous |
| Dodge | 1,980 | ~150-200 | Safe zone mechanics, enemy variety | Continuous |
| Breakout | 1,766 | ~150-200 | Best componentized, brick layouts | Continuous |
| Memory Match | 1,069 | ~100-150 | Grid layouts, card mechanics | Turn-based |
| RPS | 963 | ~80-120 | AI patterns, special rounds | Turn-based |
| Coin Flip | 661 | ~60-100 | Streak tracking, probability | Turn-based |

**Total current:** 11,683 lines
**Total target:** ~750-1,020 lines
**Potential reduction:** ~90%

---

## Cross-Game Pattern Analysis

### The Problem: Bloated `init` Functions

ALL FOUR games suffer from massive initialization functions that are 90% repetitive parameter loading:

| Game | init Lines | Pattern |
|------|------------|---------|
| Snake | ~290 | `self.X = loader:get('X', default)` × 50+ |
| Space Shooter | ~570 | `self.X = loader:get('X', default)` × 100+ |
| Dodge | ~430 | `self.X = loader:get('X', default)` × 80+ |
| Breakout | ~115 | Helper methods, but still `loader:get()` × 40+ |

**Combined: ~1,405 lines of near-identical parameter loading code.**

Note: Breakout organizes into helper methods (`initPaddleParameters`, `initBallParameters`, etc.) which is better but still verbose.

### The Problem: Arena/Boundary Systems

| Game | Arena Code | Features |
|------|------------|----------|
| Snake | ~500 lines | Shapes (rect/circle/hex), shrinking, moving walls |
| Space Shooter | ~100 lines | Screen wrap, reverse gravity, blackout zones |
| Dodge | ~200 lines | Safe zone shapes, shrinking, pulsing, movement, holes |
| Breakout | ~50 lines | Ceiling toggle, bottom kill, wall bounce modes |

**All four have "play area" concepts with dynamic boundaries and special behaviors.**

### The Problem: Entity Spawning Patterns

| Game | Spawning Code | Patterns |
|------|---------------|----------|
| Snake | ~100 lines | Random, edges, corners, spiral, near_player |
| Space Shooter | ~400 lines | Continuous, waves, clusters, formations |
| Dodge | ~200 lines | Random, waves, clusters, spiral, pulse_with_arena |
| Breakout | ~120 lines | Grid, pyramid, circle, random, checkerboard LAYOUTS |

**All need pattern-based spawning. Breakout adds LAYOUT patterns (static initial placement).**

### The Problem: Enemy/AI Behaviors

| Game | AI Code | Behaviors |
|------|---------|-----------|
| Snake | ~170 lines | Chase, flee, food-focused |
| Space Shooter | ~130 lines | Straight, zigzag, dive, formation |
| Dodge | ~200 lines | Seeker, bouncer, teleporter, shooter, zigzag, splitter |
| Breakout | ~100 lines | Brick falling, brick moving, brick regenerating |

**Breakout extends this to ENTITY behaviors, not just enemy AI.**

### The Pattern: Trail Systems (NEW - unified across games)

| Game | Trail Code | Purpose |
|------|------------|---------|
| Snake | ~400 lines | Body trail - PHYSICAL (collision, grows) |
| Dodge | ~20 lines | Player trail - VISUAL (ghosting effect) |
| Breakout | ~10 lines | Ball trail - VISUAL (position history) |

**Same underlying mechanic: store position history, render fading segments.**
- Snake: Trail IS the gameplay (collision, growth)
- Dodge/Breakout: Trail is visual effect (no collision, fixed length)

---

## Turn-Based Game Analysis (Coin Flip, Memory Match, RPS)

These three games differ fundamentally from the continuous action games above - they operate on **discrete turns/rounds** rather than continuous time.

### Shared Turn-Based Patterns

| Pattern | Coin Flip | Memory Match | RPS |
|---------|-----------|--------------|-----|
| Round state machine | ✓ | ✓ | ✓ |
| Streak/combo tracking | ✓ | ✓ | ✓ |
| Special round modes | - | ✓ (gravity, fog) | ✓ (double/sudden/reverse) |
| Time pressure | ✓ (optional) | ✓ (time limit) | ✓ (optional) |
| AI opponent patterns | ✓ (bias modes) | - | ✓ (6 patterns) |
| Grid layout | - | ✓ | - |

### The Problem: Bloated `init` Functions (Turn-Based Games)

Same problem as continuous games - massive parameter loading:

| Game | init Lines | Pattern |
|------|------------|---------|
| Coin Flip | ~180 | `self.X = loader:get('X', default)` × 35+ |
| Memory Match | ~200 | `self.X = loader:get('X', default)` × 40+ |
| RPS | ~180 | `self.X = loader:get('X', default)` × 35+ |

**Combined: ~560 additional lines of parameter loading code.**
**Total across ALL 7 games: ~1,965 lines of near-identical parameter loading.**

### New Pattern: Turn/Round Management

All three turn-based games have similar round state machines:

```lua
-- Coin Flip
WAITING_FOR_INPUT → FLIPPING (animation) → SHOWING_RESULT → NEXT_ROUND

-- Memory Match
WAITING_FOR_FIRST → SHOWING_FIRST → WAITING_FOR_SECOND → CHECKING_MATCH → NEXT_ROUND

-- RPS
WAITING_FOR_CHOICE → OPPONENT_CHOOSING → REVEALING → RESULT → NEXT_ROUND
```

**~150 lines of similar state machine code across 3 games.**

### New Pattern: AI Decision Patterns (RPS)

RPS has sophisticated AI opponent patterns:
- `random` - Pure random
- `repeat_last` - Repeat previous choice
- `counter_player` - Beat player's last move
- `pattern_cycle` - Fixed R→P→S cycle
- `mimic_player` - Copy player's last move
- `anti_player` - Lose to player (special rounds)

**~100 lines of AI decision code in RPS alone.**

This is different from AIBehaviorController (movement AI) - it's **decision-making AI**.

### New Pattern: Grid Layouts (Memory Match)

Memory Match has grid layout code identical to Breakout's brick layouts:
- Calculate rows/columns based on card count
- Position cards with padding
- Support different grid patterns

**~80 lines duplicated between Breakout and Memory Match.**

SpawnPatternController's layout mode should handle this.

### Existing Components Usage (Turn-Based Games)

All three already use existing components well:

| Component | Coin Flip | Memory Match | RPS |
|-----------|-----------|--------------|-----|
| VariantLoader | ✓ | ✓ | ✓ |
| VisualEffects | ✓ | ✓ | ✓ |
| AnimationSystem | ✓ | ✓ | ✓ |
| HUDRenderer | ✓ | ✓ | ✓ |
| VictoryCondition | ✓ | ✓ | ✓ |
| LivesHealthSystem | ✓ | - | ✓ |
| FogOfWar | - | ✓ | - |
| EntityController | - | ✓ | - |

**Validates existing components work for turn-based games too.**

---

### Breakout: Best Component Usage

Breakout already uses many existing components well:
- ✅ MovementController (paddle)
- ✅ ProjectileSystem (balls)
- ✅ EntityController (bricks)
- ✅ PowerupSystem (12 powerup types!)
- ✅ VictoryCondition
- ✅ LivesHealthSystem
- ✅ HUDRenderer
- ✅ VisualEffects
- ✅ FogOfWar

**Breakout is the template for how games SHOULD look after full componentization.**

---

## Unified Component Proposals

### 1. SchemaLoader (HIGHEST PRIORITY)

**Problem it solves:** All seven games have 115-570 lines of init that's just parameter loading.

**Lines affected:** ~1,965 combined (all 7 games)

**Current pattern (repeated 270+ times across all games):**
```lua
self.movement_speed = loader:get('movement_speed', 200)
self.fire_rate = loader:get('fire_rate', 1.0)
self.ball_trail_length = loader:get('ball_trail_length', 0)
-- ... 270 more lines
```

**Proposed solution:**
```lua
-- schema.json defines all parameters with types and defaults
-- One line replaces 300+ lines:
self.params = SchemaLoader:loadAll(variant, "breakout_schema")
```

**What the schema contains:**
```json
{
    "parameters": {
        "ball_speed": { "type": "number", "default": 300, "min": 100, "max": 800 },
        "ball_trail_length": { "type": "integer", "default": 0, "min": 0, "max": 50 },
        "brick_layout": { "type": "enum", "values": ["grid", "pyramid", "circle", "random", "checkerboard"], "default": "grid" },
        "wall_bounce_mode": { "type": "enum", "values": ["normal", "damped", "sticky", "wrap"], "default": "normal" }
    }
}
```

**Estimated size:** ~80 lines
**Lines saved:** ~1,760 combined (all 7 games)

---

### 2. ArenaController (HIGH PRIORITY)

**Used by:** All four games

**Snake needs:**
- Shaped arenas (rectangle, circle, hexagon)
- Shrinking boundaries over time
- Moving walls
- Wall modes: wrap, death, bounce
- Grid-based bounds

**Space Shooter needs:**
- Screen boundaries
- Screen wrap (player, bullets, enemies independently)
- Reverse gravity (flip spawn/movement directions)
- Blackout zones (visibility)

**Dodge needs:**
- Safe zone shapes (circle, square, hex)
- Shrinking, pulsing, shape-shifting morphs
- Moving safe zone with friction
- Holes in safe zone boundary
- Area gravity toward/away from center

**Breakout needs:**
- Ceiling on/off
- Bottom kill on/off
- Wall bounce modes: normal, damped, sticky, wrap

**Unified ArenaController:**
```lua
ArenaController:new({
    -- Shape system (All games)
    shape = "rectangle",  -- "circle", "hexagon", "custom"

    -- Boundary behavior (All games)
    wall_mode = "bounce",  -- "wrap", "death", "clamp"
    wall_bounce_damping = 1.0,  -- Breakout's damped/sticky modes
    wrap_entities = {"player"},  -- Selective wrap

    -- Boundary toggles (Breakout)
    ceiling_enabled = true,
    floor_enabled = true,  -- false = bottom kill

    -- Dynamic boundaries (Snake, Dodge)
    morph_type = "none",  -- "shrink", "pulse", "shape_shift"
    morph_speed = 1.0,
    shrink_min = 0.3,

    -- Movement (Dodge)
    movement_type = "none",  -- "random", "cardinal"
    movement_speed = 1.0,
    movement_friction = 1.0,

    -- Environment forces (Dodge)
    gravity = 0,
    gravity_target = "center",

    -- Hazard zones (Space Shooter, Dodge)
    holes = {},
    blackout_zones = {},

    -- Grid support (Snake)
    grid_mode = false,
    cell_size = 20
})
```

**Estimated size:** ~350 lines
**Lines saved:** ~850 combined

---

### 3. SpawnPatternController (HIGH PRIORITY)

**Used by:** All four games

**Consolidates:**
- Snake's food spawn patterns (random, edges, corners, spiral, center, near_player)
- Space Shooter's enemy spawn patterns (continuous, waves, clusters)
- Space Shooter's formation spawning (V, wall, spiral, Space Invaders grid, Galaga)
- Dodge's obstacle patterns (random, waves, clusters, spiral, pulse_with_arena)
- Breakout's brick LAYOUTS (grid, pyramid, circle, random, checkerboard)

**Proposed API:**
```lua
SpawnPatternController:new({
    -- Spawn mode
    mode = "continuous",  -- "batch", "waves", "formation", "layout"

    -- Position patterns (runtime spawning)
    patterns = {"random", "edges", "corners", "spiral", "near_target"},

    -- Layout patterns (initial placement - Breakout)
    layout = "grid",  -- "pyramid", "circle", "random", "checkerboard"
    layout_rows = 5,
    layout_columns = 10,
    layout_padding = 5,

    -- Wave system (Space Shooter, Dodge)
    wave_size = 5,
    wave_pause = 3.0,
    wave_difficulty_increase = 0.1,

    -- Cluster system (Space Shooter, Dodge)
    cluster_size_min = 3,
    cluster_size_max = 5,

    -- Formation system (Space Shooter)
    formation_type = "scattered",
    formation_size = 8,

    -- Timing (runtime)
    spawn_rate = 1.0,
    spawn_rate_acceleration = 0,

    -- Callbacks
    on_spawn = function(entity) end
})
```

**Estimated size:** ~400 lines
**Lines saved:** ~820 combined

---

### 4. AIBehaviorController (HIGH PRIORITY)

**Used by:** All four games

Expanded to include ENTITY behaviors (not just enemy AI).

**All games need:**
| Behavior | Snake | Space Shooter | Dodge | Breakout |
|----------|-------|---------------|-------|----------|
| Linear/straight | - | Yes | Yes | - |
| Zigzag/sine | - | Yes | Yes | - |
| Seeker/chaser | AI snake | Dive | Yes | Ball homing |
| Flee | AI snake | - | - | - |
| Bouncer | - | - | Yes | - |
| Teleporter | - | - | Yes | - |
| Shooter | - | Enemies | Yes | - |
| Splitter | - | - | Yes | - |
| Formation | - | Galaga | - | - |
| **Falling** | - | - | - | Bricks |
| **Drifting** | - | - | - | Bricks |
| **Regenerating** | - | - | - | Bricks |

**Unified API:**
```lua
AIBehaviorController:new({
    -- Movement behaviors
    behaviors = {
        linear = { speed_mult = 1.0 },
        zigzag = { wave_speed = 6, wave_amp = 30 },
        seeker = { turn_rate = 54, target = "player" },
        flee = { turn_rate = 90, target = "player" },
        bouncer = { max_bounces = 3, damping = 1.0 },
        teleporter = { interval = 3.0, range = 100 },
        shooter = { interval = 2.0, projectile_speed = 0.8 },
        splitter = { shards = 3, on_trigger = "enter_zone" }
    },

    -- Entity behaviors (Breakout bricks)
    entity_behaviors = {
        falling = { speed = 20 },
        drifting = { speed = 50, bounce_on_walls = true },
        regenerating = { delay = 5.0 }
    },

    -- Movement modifiers
    tracking_strength = 0,

    -- Formation support (Space Shooter)
    formation_slot = nil,
    return_to_formation = true
})
```

**Estimated size:** ~300 lines
**Lines saved:** ~600 combined

---

### 5. TrailSystem (MEDIUM PRIORITY - UNIFIED)

**Used by:** Snake (physical), Dodge (visual), Breakout (visual)

**Replaces the Snake-only TrailMovementSystem with a unified component.**

**All three games use the same pattern:**
```lua
-- Store position
table.insert(trail, 1, {x = entity.x, y = entity.y})
-- Trim to length
while #trail > max_length do
    table.remove(trail)
end
```

**Unified API:**
```lua
TrailSystem:new({
    -- Trail type
    mode = "visual",  -- "physical" (Snake body), "visual" (ghosting effect)

    -- Length
    max_length = 10,       -- Fixed length for visual trails
    grows = false,         -- true for Snake (grows on collect)

    -- Physics (physical mode only)
    has_collision = false, -- true for Snake self-collision
    segment_spacing = 5,   -- Pixels between segments

    -- Rendering (visual mode)
    fade_alpha = true,     -- Fade older segments
    fade_start = 1.0,      -- Starting alpha
    fade_end = 0.0,        -- Ending alpha

    -- Movement (physical mode - Snake smooth movement)
    turn_rate = 180,       -- Degrees per second
    speed = 8              -- Units per second
})

-- Methods
trail:update(dt, entity)
trail:grow(amount)           -- Physical mode: increase length
trail:getSegments()          -- For rendering
trail:checkSelfCollision()   -- Physical mode only
```

**Estimated size:** ~180 lines
**Lines saved:** ~430 combined (400 Snake + 20 Dodge + 10 Breakout)

---

### 6. EnvironmentController (MEDIUM PRIORITY)

**Used by:** Dodge, Breakout (ball gravity)

**Proposed API:**
```lua
EnvironmentController:new({
    -- Gravity
    gravity_strength = 0,
    gravity_direction = 270,  -- Degrees (270 = down)
    gravity_target = nil,     -- nil = directional, {x,y} = point gravity

    -- Wind
    wind_type = "none",
    wind_strength = 0,
    wind_direction = 0,
    wind_change_interval = 3.0
})
```

**Estimated size:** ~100 lines
**Lines saved:** ~80 combined

---

### 7. WeaponSystem (MEDIUM PRIORITY)

**Used by:** Space Shooter, Breakout (paddle shooting)

**Estimated size:** ~200 lines
**Lines saved:** ~400 from Space Shooter

---

### 8. DifficultyController (MEDIUM PRIORITY)

**Used by:** All games

**Estimated size:** ~80 lines
**Lines saved:** ~100 combined

---

### 9. EnvironmentalHazardSystem (LOW PRIORITY)

**Used by:** Space Shooter (asteroids, meteors, gravity wells)

**Estimated size:** ~150 lines
**Lines saved:** ~250 from Space Shooter

---

### 10. TurnController (MEDIUM-HIGH PRIORITY) - NEW

**Problem it solves:** Turn-based games (Coin Flip, Memory Match, RPS) all implement similar round state machines.

**Used by:** Coin Flip, Memory Match, RPS

**Lines affected:** ~450 combined (150 per game)

**Current pattern (duplicated across 3 games):**
```lua
-- Each game implements its own round state machine
self.round_state = "WAITING_FOR_INPUT"
if self.round_state == "WAITING_FOR_INPUT" then
    -- handle input
    self.round_state = "ANIMATING"
elseif self.round_state == "ANIMATING" then
    -- wait for animation
    self.round_state = "SHOWING_RESULT"
-- ... etc
```

**Proposed TurnController:**
```lua
TurnController:new({
    -- Round structure
    states = {"waiting", "animating", "resolving", "result", "next_round"},
    initial_state = "waiting",

    -- Timing
    animation_duration = 0.5,
    result_display_time = 1.0,
    auto_advance = true,  -- Automatically go to next round

    -- Time pressure (optional)
    time_limit = 0,  -- 0 = unlimited
    time_penalty = "skip",  -- "skip", "random", "lose"

    -- Streak tracking
    track_streaks = true,
    streak_multiplier = 0.1,  -- Bonus per streak

    -- Special rounds
    special_round_chance = 0,
    special_round_types = {"double_or_nothing", "sudden_death", "reverse"},

    -- Callbacks
    on_round_start = function(round_num) end,
    on_round_end = function(result) end,
    on_streak = function(streak_count) end,
    on_special_round = function(type) end
})

-- Methods
turn:startRound()
turn:advanceState()
turn:getCurrentState()
turn:getRoundNumber()
turn:getStreak()
turn:isSpecialRound()
turn:getTimeRemaining()
```

**Estimated size:** ~150 lines
**Lines saved:** ~350 combined

---

### 11. AIDecisionController (MEDIUM PRIORITY) - NEW

**Problem it solves:** Decision-making AI patterns distinct from movement AI.

**Used by:** RPS (6 patterns), Coin Flip (bias patterns)

**Lines affected:** ~150 combined

**Different from AIBehaviorController:**
- AIBehaviorController = movement/physics behaviors (seeker, zigzag, bouncer)
- AIDecisionController = choice/decision behaviors (counter-player, pattern-cycle)

**Proposed AIDecisionController:**
```lua
AIDecisionController:new({
    -- Pattern type
    pattern = "random",  -- "counter_player", "repeat_last", "pattern_cycle", "mimic_player", "biased"

    -- Biased random (Coin Flip)
    bias = 0.5,  -- 0.0-1.0, probability toward one choice
    bias_target = nil,  -- Which choice to bias toward

    -- Pattern cycle (RPS)
    cycle = {"rock", "paper", "scissors"},
    cycle_index = 1,

    -- Learning/adaptation (future)
    track_player_history = false,
    adaptation_rate = 0,

    -- Available choices
    choices = {"heads", "tails"},  -- or {"rock", "paper", "scissors", "lizard", "spock"}

    -- Callbacks
    on_decision = function(choice) end
})

-- Methods
ai:makeDecision(player_last_move, player_history)
ai:setPattern(pattern_name)
ai:getDifficulty()  -- Based on pattern effectiveness
```

**Estimated size:** ~100 lines
**Lines saved:** ~100 combined

---

### 12. GridLayoutController (LOW-MEDIUM PRIORITY) - NEW

**Problem it solves:** Memory Match and Breakout both have grid layout code.

**Used by:** Memory Match, Breakout

**Lines affected:** ~160 combined (80 per game)

**Note:** Could be merged into SpawnPatternController's layout mode, but card grids have specific features (shuffling, flip animations) that brick grids don't need.

**Proposed GridLayoutController:**
```lua
GridLayoutController:new({
    -- Grid dimensions
    item_count = 12,  -- Auto-calculate rows/cols
    rows = 0,  -- 0 = auto
    columns = 0,  -- 0 = auto

    -- Spacing
    cell_width = 80,
    cell_height = 80,
    padding_x = 10,
    padding_y = 10,

    -- Layout patterns (same as SpawnPatternController)
    pattern = "grid",  -- "grid", "pyramid", "random", "spiral"

    -- Card-specific features
    shuffle = false,
    shuffle_animation = true,
    shuffle_duration = 0.5,

    -- Item tracking
    items = {},  -- Grid contents

    -- Callbacks
    on_item_click = function(item, row, col) end
})

-- Methods
grid:getItemAt(row, col)
grid:getItemAtPosition(x, y)
grid:shuffle()
grid:removeItem(row, col)
grid:getAllPositions()  -- For rendering
```

**Estimated size:** ~120 lines
**Lines saved:** ~80 combined (SpawnPatternController handles most cases)

**Alternative:** Merge into SpawnPatternController with `layout_type = "card_grid"` option.

---

## Target: Games After Component Library

### Snake (~150-200 lines)

```lua
function Snake:init(game_data, cheats, di, variant)
    Snake.super.init(self, game_data, cheats, di, variant)
    self.params = SchemaLoader:loadAll(variant, "snake_schema")

    self.arena = ArenaController:new(self.params.arena)
    self.spawner = SpawnPatternController:new(self.params.collectibles)
    self.trail = TrailSystem:new({
        mode = "physical",
        grows = true,
        has_collision = true,
        turn_rate = self.params.turn_rate,
        speed = self.params.speed
    })

    if self.params.ai_snakes > 0 then
        self.ai = AIBehaviorController:new(self.params.ai)
    end

    self.view = SnakeView:new(self)
end

function Snake:updateGameLogic(dt)
    self.arena:update(dt)
    self.trail:update(dt, self.player)
    self.spawner:update(dt)

    local food = self.spawner:checkCollision(self.trail:getHead())
    if food then
        self.trail:grow(food.value)
        self.metrics.snake_length = self.trail:getLength()
    end

    if self.trail:checkSelfCollision() then
        self.metrics.deaths = self.metrics.deaths + 1
    end
end
```

### Space Shooter (~200-250 lines)

```lua
function SpaceShooter:init(game_data, cheats, di, variant)
    SpaceShooter.super.init(self, game_data, cheats, di, variant)
    self.params = SchemaLoader:loadAll(variant, "space_shooter_schema")

    self.arena = ArenaController:new(self.params.arena)
    self.spawner = SpawnPatternController:new(self.params.enemies)
    self.weapon = WeaponSystem:new(self.params.weapon)
    self.difficulty = DifficultyController:new(self.params.difficulty)
    self.ai = AIBehaviorController:new(self.params.enemy_ai)

    self.player = { x = self.params.game_width / 2, y = self.params.game_height - 50 }
    self.view = SpaceShooterView:new(self)
end
```

### Dodge (~150-200 lines)

```lua
function Dodge:init(game_data, cheats, di, variant)
    Dodge.super.init(self, game_data, cheats, di, variant)
    self.params = SchemaLoader:loadAll(variant, "dodge_schema")

    self.arena = ArenaController:new(self.params.arena)
    self.spawner = SpawnPatternController:new(self.params.obstacles)
    self.ai = AIBehaviorController:new(self.params.enemy_behaviors)
    self.environment = EnvironmentController:new(self.params.environment)
    self.trail = TrailSystem:new({ mode = "visual", max_length = 10 })

    self.player = { x = self.params.game_width / 2, y = self.params.game_height / 2 }
    self.view = DodgeView:new(self)
end
```

### Breakout (~150-200 lines)

```lua
function Breakout:init(game_data, cheats, di, variant)
    Breakout.super.init(self, game_data, cheats, di, variant)
    self.params = SchemaLoader:loadAll(variant, "breakout_schema")

    self.arena = ArenaController:new(self.params.arena)
    self.spawner = SpawnPatternController:new({
        mode = "layout",
        layout = self.params.brick_layout,
        layout_rows = self.params.brick_rows,
        layout_columns = self.params.brick_columns
    })
    self.ai = AIBehaviorController:new(self.params.brick_behaviors)
    self.environment = EnvironmentController:new(self.params.ball_physics)

    -- Already using these components:
    self.projectile_system = ProjectileSystem:new(self.params.ball)
    self.powerup_system = PowerupSystem:new(self.params.powerups)
    self.health_system = LivesHealthSystem:new(self.params.lives)
    self.victory_checker = VictoryCondition:new(self.params.victory)

    self.paddle = { x = self.params.game_width / 2, y = self.params.game_height - 50 }
    self.view = BreakoutView:new(self)
end

function Breakout:updateGameLogic(dt)
    self.arena:update(dt)
    self.projectile_system:update(dt, self.arena:getBounds())
    self.powerup_system:update(dt, self.paddle, self.arena:getBounds())

    -- Brick behaviors (falling, moving, regenerating)
    for _, brick in ipairs(self.spawner:getEntities()) do
        self.ai:updateEntity(brick, dt)
    end

    -- Ball behaviors (gravity, homing)
    for _, ball in ipairs(self.projectile_system:getProjectiles()) do
        self.environment:applyForces(ball, dt)
    end
end
```

### Coin Flip (~60-100 lines)

```lua
function CoinFlip:init(game_data, cheats, di, variant)
    CoinFlip.super.init(self, game_data, cheats, di, variant)
    self.params = SchemaLoader:loadAll(variant, "coin_flip_schema")

    self.turn = TurnController:new({
        states = {"waiting", "flipping", "result"},
        animation_duration = self.params.flip_duration,
        time_limit = self.params.time_limit,
        track_streaks = true
    })

    self.ai = AIDecisionController:new({
        pattern = self.params.pattern_mode,  -- "random", "alternating", "biased"
        bias = self.params.bias,
        choices = {"heads", "tails"}
    })

    self.victory = VictoryCondition:new(self.params.victory)
    self.lives = LivesHealthSystem:new(self.params.lives)
    self.view = CoinFlipView:new(self)
end

function CoinFlip:handleInput(key)
    if self.turn:getCurrentState() ~= "waiting" then return end

    local player_choice = nil
    if key == "left" or key == "a" then player_choice = "heads"
    elseif key == "right" or key == "d" then player_choice = "tails" end

    if player_choice then
        local result = self.ai:makeDecision()  -- Coin outcome
        self.turn:startRound()
        -- Animation plays, then resolve in update
    end
end
```

### Memory Match (~100-150 lines)

```lua
function MemoryMatch:init(game_data, cheats, di, variant)
    MemoryMatch.super.init(self, game_data, cheats, di, variant)
    self.params = SchemaLoader:loadAll(variant, "memory_match_schema")

    self.turn = TurnController:new({
        states = {"waiting_first", "waiting_second", "checking", "matched", "mismatched"},
        time_limit = self.params.time_limit,
        track_streaks = true
    })

    self.grid = SpawnPatternController:new({
        mode = "layout",
        layout = "grid",
        item_count = self.params.card_count,
        cell_width = self.params.card_width,
        cell_height = self.params.card_height
    })

    self.fog = FogOfWar:new(self.params.fog)  -- Already using
    self.victory = VictoryCondition:new(self.params.victory)
    self.view = MemoryMatchView:new(self)

    -- Shuffle and place cards
    self.cards = self:generatePairs(self.params.card_count / 2)
    self.grid:shuffle()
end

function MemoryMatch:handleCardClick(x, y)
    local card = self.grid:getItemAtPosition(x, y)
    if not card or card.matched or card.flipped then return end

    card.flipped = true
    self.turn:advanceState()
end
```

### RPS (~80-120 lines)

```lua
function RPS:init(game_data, cheats, di, variant)
    RPS.super.init(self, game_data, cheats, di, variant)
    self.params = SchemaLoader:loadAll(variant, "rps_schema")

    self.turn = TurnController:new({
        states = {"waiting", "opponent_choosing", "revealing", "result"},
        special_round_chance = self.params.special_round_chance,
        special_round_types = {"double_or_nothing", "sudden_death", "reverse"}
    })

    self.ai = AIDecisionController:new({
        pattern = self.params.ai_pattern,  -- "random", "counter_player", "pattern_cycle"
        choices = self.params.choices,  -- {"rock", "paper", "scissors"} or RPSLS
        track_player_history = self.params.adaptive_ai
    })

    self.victory = VictoryCondition:new(self.params.victory)
    self.lives = LivesHealthSystem:new(self.params.lives)
    self.view = RPSView:new(self)
end

function RPS:handleInput(key)
    if self.turn:getCurrentState() ~= "waiting" then return end

    local choice = self:keyToChoice(key)
    if choice then
        self.player_choice = choice
        self.opponent_choice = self.ai:makeDecision(self.player_choice, self.player_history)
        self.turn:startRound()
    end
end
```

---

## Component Status: What Exists vs What's Needed

### ✅ Already Built (Phase 1-16)
| Component | Status | Notes |
|-----------|--------|-------|
| MovementController | ✅ Done | Continuous movement only |
| EntityController | ✅ Done | Spawning, pooling |
| ProjectileSystem | ✅ Done | Bullets, balls |
| PowerupSystem | ✅ Done | 12+ powerup types |
| LivesHealthSystem | ✅ Done | Lives, HP, shields |
| ScoringSystem | ✅ Done | Points, combos |
| VictoryCondition | ✅ Done | Multiple win types |
| HUDRenderer | ✅ Done | Configurable |
| VisualEffects | ✅ Done | Particles, shake |
| AnimationSystem | ✅ Done | Sprite animation |
| FogOfWar | ✅ Done | Visibility masking |
| VariantLoader | ✅ Done | 3-tier param loading |

### 🔨 Needs Extraction (from existing games)
| Component | Source Games | Priority | Est. Effort |
|-----------|-------------|----------|-------------|
| SchemaLoader | All 7 | **HIGHEST** | 2-3 hours |
| ArenaController | Snake, Dodge, Shooter, Breakout | HIGH | 4-6 hours |
| GridMovementController | Snake | HIGH | 3-4 hours |
| AIBehaviorController | Dodge, Shooter, Snake | HIGH | 4-6 hours |
| SpawnPatternController | All action games | HIGH | 3-4 hours |
| TrailSystem | Snake, Dodge, Breakout | MEDIUM | 2-3 hours |
| TurnController | Coin Flip, RPS, Memory | MEDIUM | 2-3 hours |
| AIDecisionController | RPS, Coin Flip | LOW | 1-2 hours |

### 🆕 Needs to Be Built (new)
| Component | Enables | Priority | Est. Effort |
|-----------|---------|----------|-------------|
| Pathfinding (add to AIBehavior) | Pac-Man ghosts, RTS, roguelikes | HIGH | 3-4 hours |
| LevelLoader | Mazes, Sokoban, any level-based | MEDIUM | 2-3 hours |
| HistoryController | Undo/redo for puzzles | LOW | 1-2 hours |
| PatternMatcher | Match-3, Tetris | LOW | 2-3 hours |

---

## Implementation Order (Recommended)

### Phase 17: SchemaLoader (Foundation)
**Impact:** Enables all future components to be configured via JSON
- Define JSON schema format with types, defaults, validation
- Auto-populate game params from schema
- Remove 1,760+ lines of `loader:get()` calls

### Phase 18: GridMovementController (Unlocks Genre)
**Impact:** Enables Pac-Man, Snake, Sokoban, Tetris, Match-3, Chess, etc.
- Extract from Snake's grid movement
- Add: queued turns, push mechanics, gravity mode
- Configure via JSON: cell_size, wrap, collision_mode

### Phase 19: ArenaController (Unified Play Space)
**Impact:** Every game needs bounded space with rules
- Shapes: rect, circle, hex, grid-with-walls
- Behaviors: wrap, bounce, kill, clamp
- Dynamic: shrink, morph, move
- Load walls from JSON level data

### Phase 20: AIBehaviorController + Pathfinding
**Impact:** Enemies that actually work like enemies
- Movement behaviors: chase, flee, patrol, wander, formation
- **Add A* pathfinding** for grid-based routing
- Configure via JSON: behavior, target, speed, etc.

### Phase 21: SpawnPatternController
**Impact:** Where and when things appear
- Modes: continuous, waves, layout, formation
- Patterns: random, edges, grid, fill_empty
- Layouts from JSON level data

### Phase 22-25: Remaining Components
- TrailSystem, TurnController, AIDecisionController
- LevelLoader, HistoryController, PatternMatcher

---

## The 10,000 Games Reality Check

With this component library:

| Game Type | Components Needed | JSON Config | Lua Code |
|-----------|-------------------|-------------|----------|
| Snake variant | Grid + Trail + Arena + Victory | ~50 lines | ~20 lines |
| Shooter variant | Continuous + Projectile + Entity + AI | ~80 lines | ~40 lines |
| Pac-Man clone | Grid + Arena + AI(pathfind) + Entity | ~100 lines | ~30 lines |
| Match-3 clone | Grid + Pattern + Entity + Score | ~70 lines | ~40 lines |
| Card game | Turn + Entity + AI(decision) | ~60 lines | ~30 lines |
| Breakout variant | Continuous + Projectile + Entity + Arena | ~80 lines | ~30 lines |

**Creating a new game variant:**
1. Pick base game type (grid, continuous, turn-based)
2. Copy similar game's JSON
3. Tweak parameters
4. Done

**Creating a new game genre:**
1. Check component library for what exists
2. Write JSON config composing components
3. Write ~30-50 lines of Lua for unique logic
4. Done

---

## Key Insights

1. **SchemaLoader is the keystone** - Makes everything else cleaner
2. **GridMovementController unlocks half of classic games** - Huge genre coverage
3. **Pathfinding is the missing AI piece** - Simple behaviors aren't enough for Pac-Man-style enemies
4. **Most games are 3-5 components** - Library doesn't need to be huge
5. **JSON drives variants** - Same code, different params = different game
6. **Lua is for edge cases only** - Ghost house timing, chain scoring, special rules
