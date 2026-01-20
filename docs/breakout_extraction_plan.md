# Breakout Extraction Plan

**Goal:** Extract reusable patterns from Breakout into generic components. Reduce Breakout-specific code to only truly game-specific logic.

**Problem Statement:** Breakout has ~580 lines where:
- Generic patterns are coded inline (attachment, trails, layout dispatch, bullets)
- Some components already exist but aren't being used (ProjectileSystem for bullets)
- BaseGame already has helpers Breakout duplicates (RNG init)
- Real-time combo/scoring is inline but could be a reusable pattern

**Target:** Remove ~100-150 lines of boilerplate from Breakout by using existing components properly and extracting generic patterns.

---

## Rules for AI

1. **Read this section before starting any phase.**
2. Complete ALL steps within a phase before stopping.
3. Do NOT skip steps. Do NOT combine phases.
4. After completing a phase, write notes in that phase's `### AI Notes` section.
5. If something cannot be completed, document it in notes and inform the user.
6. Do NOT proceed to the next phase without user approval.
7. Each phase ends with the code in a working state - no half-finished work.
8. Preserve existing game behavior exactly - this is a refactor, not a feature change.
9. Run NO tests yourself - the user will do manual testing.
10. After completing a phase, tell the user what to test and wait for confirmation.

### CRITICAL: Deletion Policy

**THE ENTIRE POINT OF THIS REFACTOR IS TO DELETE CODE.**

When you "migrate" or "replace" code, that means:
1. Add/use the generic solution
2. **DELETE the old inline code entirely** - not comment it out, DELETE IT
3. If something breaks, **fix the caller** - do NOT add backward compatibility shims

**FORBIDDEN:**
- Creating wrapper functions that just call the component
- Keeping duplicate code "for safety"
- Adding Breakout-specific parameters to generic functions
- Creating adapter functions for backward compatibility
- "Preserved for reference" comments

**REQUIRED:**
- Delete inline code immediately after switching to component
- Update all callers to use new function signatures
- If it breaks, fix it - that's how you find what needs updating
- Every extracted function must work for at least 2+ different game types

### Abstraction Philosophy

**Generic patterns don't know Breakout exists. Or any specific game.**

An attachment system doesn't know about "sticky balls" - it knows about parent/child entity relationships. A layout dispatcher doesn't know about "bricks" - it knows about entity types and layout names.

---

## What Already Exists (Use These!)

| Component | Already Has | Breakout Should Use For |
|-----------|-------------|-------------------------|
| **BaseGame** | `self.rng = love.math.newRandomGenerator(os.time())` | RNG - DELETE duplicate in setupGameState |
| **BaseGame** | `self.bullets = {}` | Already initialized - don't reinit |
| **ProjectileSystem** | `shoot()`, `update()`, `checkCollisions()` | Paddle bullets - DELETE inline bullet loop |
| **PhysicsUtils** | `createTrailSystem()` | Ball trails - DELETE inline trail code |
| **EntityController** | `spawnGrid/Pyramid/Circle/Random/Checkerboard` | Already using - but needs layout dispatch |

---

## Phase 1: Remove Duplicate RNG Init

**What this phase accomplishes:** Delete RNG initialization that duplicates BaseGame.

**What will be noticed in-game:** Nothing. RNG already works.

### Steps

1.1. In `Breakout:setupGameState()`, DELETE the RNG initialization line:
```lua
-- DELETE THIS LINE:
if self.seed then self.rng = love.math.newRandomGenerator(self.seed) end
```

1.2. Verify BaseGame already initializes `self.rng` (it does, line 20).

1.3. Note: If Breakout needs seeded RNG for demos, that's handled elsewhere (demo system seeds RNG).

### Testing (User)

- [ ] Breakout launches without errors
- [ ] Ball spawns with random angle variance
- [ ] Brick layouts generate correctly

### AI Notes

Completed. Deleted line 135: `if self.seed then self.rng = love.math.newRandomGenerator(self.seed) end`
BaseGame already initializes self.rng at line 20.

---

## Phase 2: Use ProjectileSystem for Paddle Bullets

**What this phase accomplishes:** Delete the inline bullet management code. Use ProjectileSystem.

**What will be noticed in-game:** Nothing. Bullets work identically.

**Current Problem:** Breakout has its own bullet array and update loop (lines 315-330) when ProjectileSystem already exists and can handle this.

### Steps

2.1. In `setupComponents()`, add a "paddle_bullet" type to the existing projectile_system:
```lua
self.projectile_system = C.ProjectileSystem:new({
    projectile_types = {
        ["ball"] = { ... existing ... },
        ["paddle_bullet"] = {
            speed = 400,
            radius = 2,
            width = 4,
            height = 10,
            lifetime = 5,
            team = "player",
            movement_type = "linear"
        }
    },
    ...
})
```

2.2. In `keypressed()`, change bullet spawn to use projectile_system:
```lua
-- OLD:
table.insert(self.bullets, {x = self.paddle.x, y = self.paddle.y - self.paddle.height / 2 - 5, vy = -400, width = 4, height = 10})
-- NEW:
self.projectile_system:shoot("paddle_bullet", self.paddle.x, self.paddle.y - self.paddle.height / 2 - 5, -math.pi/2)
```

2.3. DELETE the entire inline bullet update loop from `updateGameLogic()` (lines 315-330).

2.4. Add bullet-brick collision via projectile_system:checkCollisions():
```lua
self.projectile_system:checkCollisions(self.bricks, function(bullet, brick)
    if brick.alive then
        self.entity_controller:hitEntity(brick, self.params.paddle_shoot_damage, bullet)
    end
end, "player")
```

2.5. Update view to render paddle_bullet type if needed.

2.6. DELETE `self.bullets = {}` from BaseGame if it's now unused (check other games first).

### Testing (User)

- [ ] Paddle shooting works (space key with laser powerup)
- [ ] Bullets travel upward
- [ ] Bullets destroy bricks
- [ ] Bullets disappear when hitting bricks or leaving screen
- [ ] No console errors

### AI Notes

Completed. Changes made:
1. Added "paddle_bullet" type to projectile_system with team "paddle_bullet" (to avoid double-processing with balls)
2. Changed keypressed() to use `self.projectile_system:shoot("paddle_bullet", ...)`
3. Deleted 16-line inline bullet update loop from updateGameLogic()
4. Added `self.projectile_system:checkCollisions(self.bricks, ..., "paddle_bullet")` for bullet-brick collision
5. Updated breakout_view.lua to get bullets from `projectile_system:getProjectilesByTeam("paddle_bullet")`

Lines removed from breakout.lua: ~15 lines

---

## Phase 3: Add spawnLayout() to EntityController

**What this phase accomplishes:** Move layout dispatch logic from Breakout to EntityController.

**What will be noticed in-game:** Nothing. Same layouts.

**Current Problem:** Breakout has a 15-line if/elseif chain to dispatch layouts (lines 209-221). Every game with layouts would duplicate this.

### Steps

3.1. Add `spawnLayout()` method to EntityController:
```lua
function EntityController:spawnLayout(type_name, layout, config)
    config = config or {}
    local rows = config.rows or 5
    local cols = config.cols or 10
    local start_x = config.x or 0
    local start_y = config.y or 60
    local spacing_x = config.spacing_x or 2
    local spacing_y = config.spacing_y or 2
    local arena_width = config.arena_width or 800
    local rng = config.rng
    local can_overlap = config.can_overlap or false

    if layout == "pyramid" then
        self:spawnPyramid(type_name, rows, cols, start_x, start_y, spacing_x, spacing_y, arena_width)
    elseif layout == "circle" then
        self:spawnCircle(type_name, rows, arena_width / 2, config.center_y or 200, config.base_count or 12, config.ring_spacing or 40)
    elseif layout == "random" then
        self:spawnRandom(type_name, rows * cols, config.bounds or {x = 40, y = 40, width = arena_width - 80, height = 200}, rng, can_overlap)
    elseif layout == "checkerboard" then
        self:spawnCheckerboard(type_name, rows, cols, start_x, start_y, spacing_x, spacing_y)
    else -- "grid" is default
        self:spawnGrid(type_name, rows, cols, start_x, start_y, spacing_x, spacing_y)
    end
end
```

3.2. Update Breakout's `generateBricks()` to use it:
```lua
-- OLD: 15-line if/elseif chain
-- NEW:
local total_width = p.brick_columns * (p.brick_width + p.brick_padding)
local start_x = (self.arena_width - total_width) / 2

ec:spawnLayout("brick", p.brick_layout, {
    rows = p.brick_rows,
    cols = p.brick_columns,
    x = start_x,
    y = 60,
    spacing_x = p.brick_padding,
    spacing_y = p.brick_padding,
    arena_width = self.arena_width,
    rng = self.rng,
    can_overlap = p.bricks_can_overlap,
    bounds = {x = 40, y = 40, width = self.arena_width - 80, height = self.arena_height * 0.4},
    center_y = 200,
    base_count = 12,
    ring_spacing = 40
})
```

3.3. DELETE the old if/elseif chain from Breakout.

### Testing (User)

- [ ] Grid layout works (default)
- [ ] Pyramid layout works
- [ ] Circle layout works
- [ ] Random layout works
- [ ] Checkerboard layout works

### AI Notes

*(To be filled after completion)*

---

## Phase 4: Add updateTrail() to PhysicsUtils

**What this phase accomplishes:** Extract inline trail update to PhysicsUtils.

**What will be noticed in-game:** Nothing. Same trails.

**Current Problem:** Breakout has inline trail update code (lines 407-411). PhysicsUtils has createTrailSystem() but it's for a standalone trail object, not updating entity.trail arrays.

### Steps

4.1. Add `updateTrail()` to PhysicsUtils:
```lua
function PhysicsUtils.updateTrail(entity, max_length)
    if not entity.trail or max_length <= 0 then return end
    table.insert(entity.trail, 1, {x = entity.x, y = entity.y})
    while #entity.trail > max_length do
        table.remove(entity.trail)
    end
end
```

4.2. Update Breakout's `updateBall()`:
```lua
-- OLD (lines 407-411):
if p.ball_trail_length and p.ball_trail_length > 0 and ball.trail then
    table.insert(ball.trail, 1, {x = ball.x, y = ball.y})
    while #ball.trail > p.ball_trail_length do table.remove(ball.trail) end
end

-- NEW:
Physics.updateTrail(ball, p.ball_trail_length or 0)
```

4.3. DELETE the old inline trail code from Breakout.

### Testing (User)

- [ ] Ball trails render correctly
- [ ] Trail follows ball movement
- [ ] Trail length respects parameter

### AI Notes

*(To be filled after completion)*

---

## Phase 5: Add handleAttachment() to PhysicsUtils

**What this phase accomplishes:** Extract sticky ball attachment logic to generic helper.

**What will be noticed in-game:** Nothing. Sticky balls work identically.

**Current Problem:** Breakout has inline "entity follows parent with offset" logic (lines 397-402) that's generic.

### Steps

5.1. Add `handleAttachment()` to PhysicsUtils:
```lua
-- Returns true if entity is attached and was updated, false otherwise
function PhysicsUtils.handleAttachment(entity, parent, offset_x_field, offset_y_field)
    if not entity.stuck then return false end
    entity.x = parent.x + (entity[offset_x_field] or 0)
    entity.y = parent.y + (entity[offset_y_field] or 0)
    return true
end
```

5.2. Update Breakout's `updateBall()`:
```lua
-- OLD (lines 397-402):
if ball.stuck then
    ball.x = self.paddle.x + (ball.stuck_offset_x or 0)
    ball.y = self.paddle.y + (ball.stuck_offset_y or 0)
    return
end

-- NEW:
if Physics.handleAttachment(ball, self.paddle, "stuck_offset_x", "stuck_offset_y") then
    return
end
```

5.3. DELETE the old inline attachment code from Breakout.

### Testing (User)

- [ ] Sticky paddle catches ball
- [ ] Ball follows paddle while stuck
- [ ] Space releases ball correctly
- [ ] Ball launches at correct angle based on position

### AI Notes

*(To be filled after completion)*

---

## Phase 6: Add attachToEntity() to PhysicsUtils

**What this phase accomplishes:** Extract the "catch and attach" logic (lines 455-460).

**What will be noticed in-game:** Nothing. Sticky catching works identically.

### Steps

6.1. Add `attachToEntity()` to PhysicsUtils:
```lua
-- Attach an entity to a parent, storing position offsets
function PhysicsUtils.attachToEntity(entity, parent, offset_y_adjust)
    offset_y_adjust = offset_y_adjust or 0
    entity.stuck = true
    entity.stuck_offset_x = entity.x - parent.x
    entity.y = parent.y + offset_y_adjust
    entity.stuck_offset_y = entity.y - parent.y
    entity.vx, entity.vy = 0, 0
end
```

6.2. Update Breakout's paddle collision in `updateBall()`:
```lua
-- OLD (lines 455-460):
if p.paddle_sticky and not ball.stuck then
    ball.stuck = true
    ball.stuck_offset_x = ball.x - self.paddle.x
    ball.y = self.paddle.y - ball.radius - self.paddle.height / 2
    ball.stuck_offset_y = ball.y - self.paddle.y
    ball.vx, ball.vy = 0, 0
else ...

-- NEW:
if p.paddle_sticky and not ball.stuck then
    Physics.attachToEntity(ball, self.paddle, -ball.radius - self.paddle.height / 2)
else ...
```

6.3. DELETE the old inline attach code from Breakout.

### Testing (User)

- [ ] Sticky paddle catches ball on collision
- [ ] Ball position is correct when caught
- [ ] Ball has zero velocity when stuck

### AI Notes

*(To be filled after completion)*

---

## Phase 7: Move Perfect Clear Bonus to VictoryCondition

**What this phase accomplishes:** Extract perfect clear bonus logic.

**What will be noticed in-game:** Nothing. Same bonus.

**Current Problem:** Perfect clear bonus is inline in checkVictoryConditions (lines 568-571).

### Steps

7.1. Add bonus support to VictoryCondition component:
```lua
-- In VictoryCondition:check(), after determining result:
if result == "victory" and self.config.bonuses then
    for _, bonus in ipairs(self.config.bonuses) do
        if bonus.condition(self.game) then
            bonus.apply(self.game)
        end
    end
end
```

7.2. Update Breakout's victory_checker config in setupComponents():
```lua
self.victory_checker = C.VictoryCondition:new({
    victory = vc.victory,
    loss = vc.loss,
    check_loss_first = true,
    bonuses = {
        {
            name = "perfect_clear",
            condition = function(game)
                return game.balls_lost == 0 and game.params.perfect_clear_bonus > 0
            end,
            apply = function(game)
                game.score = game.score + game.params.perfect_clear_bonus
                if game.params.score_popup_enabled then
                    game.popup_manager:add(game.arena_width / 2, game.arena_height / 2,
                        "PERFECT CLEAR! +" .. game.params.perfect_clear_bonus, {0, 1, 0})
                end
            end
        }
    }
})
```

7.3. Simplify Breakout's `checkVictoryConditions()`:
```lua
function Breakout:checkVictoryConditions()
    local result = self.victory_checker:check()
    if result then
        self.victory, self.game_over = result == "victory", result == "loss"
    end
end
```

7.4. DELETE the inline perfect clear logic from Breakout.

### Testing (User)

- [ ] Normal victory works
- [ ] Perfect clear bonus awarded when no balls lost
- [ ] Popup shows for perfect clear
- [ ] No bonus when balls were lost

### AI Notes

*(To be filled after completion)*

---

## Expected Final State

### Lines Removed from Breakout:
- Phase 1: ~1 line (RNG init)
- Phase 2: ~20 lines (bullet loop + spawn)
- Phase 3: ~12 lines (layout dispatch)
- Phase 4: ~4 lines (trail update)
- Phase 5: ~5 lines (attachment follow)
- Phase 6: ~5 lines (attachment catch)
- Phase 7: ~5 lines (perfect clear)

**Total: ~52 lines removed from Breakout**

### New Generic Functions Available:
- `EntityController:spawnLayout(type, layout, config)` - Generic layout dispatch
- `PhysicsUtils.updateTrail(entity, max_length)` - Trail position history
- `PhysicsUtils.handleAttachment(entity, parent, offset_x_field, offset_y_field)` - Entity follows parent
- `PhysicsUtils.attachToEntity(entity, parent, offset_y)` - Catch and attach
- `VictoryCondition` bonus support - Conditional end-game bonuses

### What Other Games Can Now Use:
- **Space shooter**: Use `spawnLayout()` for asteroid patterns
- **Puzzle games**: Use `spawnLayout()` for piece grids
- **Pinball**: Use `handleAttachment()` for ball-on-flipper
- **Platformer**: Use `attachToEntity()` for player-on-platform
- **Any game with trails**: Use `updateTrail()`
- **Any game with conditional bonuses**: Use VictoryCondition bonuses

---

## Verification Checklist

After all phases complete:

- [ ] Breakout plays identically to before
- [ ] All 5 layout types work
- [ ] Paddle bullets work
- [ ] Sticky ball works (catch, follow, release)
- [ ] Ball trails work
- [ ] Perfect clear bonus works
- [ ] No console errors
- [ ] New functions could be used by other game types
