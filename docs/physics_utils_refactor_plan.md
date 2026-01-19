# PhysicsUtils Refactor Plan

**Goal:** Transform PhysicsUtils from a Breakout-specific utility into truly generic physics primitives usable by ALL games.

**Problem Statement:** Current PhysicsUtils is 917 lines where:
- 8 of 10 external calls come from Breakout alone
- Functions like `releaseStickyBall`, `paddleBounce`, `updateBallPhysics` are Breakout-specific
- Names say "ball" when they mean "circle"
- Generic primitives (`applyGravity`, `applyForce`) are buried inside monolithic functions
- 4 functions are dead code
- Future games can't reuse these functions without inheriting Breakout's assumptions

**Target:** ~200-300 lines of composable primitives that work for Snake, Dodge, Breakout, Space Shooter, racing games, pool games, platformers - anything with physics.

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
1. Add the new generic primitive
2. **DELETE the old Breakout-specific code entirely** - not comment it out, DELETE IT
3. If something breaks, **fix the caller** - do NOT add backward compatibility shims
4. If a game called `releaseStickyBall()`, update it to call `launchAtAngle()` with the right params

**FORBIDDEN:**
- ❌ Creating `releaseStickyBall` that wraps `launchAtAngle` - just use `launchAtAngle`
- ❌ Keeping "ball" in names when you mean "circle" or "entity"
- ❌ Adding Breakout-specific parameters to generic functions
- ❌ Creating adapter functions for backward compatibility
- ❌ Functions that only make sense for one game
- ❌ "Preserved for reference" comments

**REQUIRED:**
- ✓ Delete game-specific code immediately after creating generic replacement
- ✓ Rename "ball" functions to what they actually do (circle collision, entity launch)
- ✓ Update all callers to use new function signatures
- ✓ If it breaks, fix it - that's how you find what needs updating
- ✓ Every function must work for at least 2+ different game types conceptually

### Abstraction Philosophy

**The primitives don't know Breakout exists. Or Snake. Or any game.**

A collision resolution function doesn't know about "paddles" - it knows about rectangles and circles. A launch function doesn't know about "sticky balls" - it knows about angles and speeds.

**Ask these questions for every function:**
- Could a racing game use this? A pool game? A platformer? Snake?
- Does the function name mention a game-specific concept (paddle, brick, ball)?
- Does the config require game-specific knowledge?
- If someone reads just this function, would they know what game it's from?

**The right level of abstraction:**

| Wrong (Game-Specific) | Right (Generic Primitive) |
|----------------------|---------------------------|
| `releaseStickyBall(ball, paddle_width, launch_speed)` | `launchAtAngle(entity, angle, speed)` or `launchFromOffset(entity, offset, angle_range, speed)` |
| `paddleBounce(ball, paddle_x, paddle_width)` | `bounceOffSurface(entity, surface, config)` |
| `updateBallPhysics(ball, dt, breakout_config)` | Compose: `applyForce()`, `move()`, `checkBounds()` |
| `checkBallEntityCollisions(ball, bricks, ...)` | `checkCollisions(entity, targets, config)` |

### Composable Behaviors

Physics behaviors should be attachable to ANY entity:

```lua
-- Instead of hardcoded inside updateBallPhysics:
PhysicsUtils.applyGravity(entity, strength, direction, dt)
PhysicsUtils.applyHoming(entity, target_x, target_y, strength, dt)
PhysicsUtils.applyMagnet(entity, target_x, target_y, range, strength, dt)
PhysicsUtils.applyDrag(entity, drag_coefficient, dt)

-- Games compose them:
function MyGame:updateEnemy(enemy, dt)
    PhysicsUtils.applyGravity(enemy, self.gravity, 90, dt)
    PhysicsUtils.applyHoming(enemy, player.x, player.y, 50, dt)
    PhysicsUtils.clampSpeed(enemy, self.max_speed)
    PhysicsUtils.move(enemy, dt)
    PhysicsUtils.checkBounds(enemy, self.bounds, {mode = "bounce"})
end
```

### Line Changes Tracking

**REQUIRED:** After each phase, document actual line changes:

Format:
```
#### Line Changes
physics_utils.lua        -200 lines (917 → 717)
breakout.lua             +5 lines (calls updated)
```

---

## Current State Summary (from audit)

### Functions Called Externally (10):
1. `createTrailSystem` - dodge_game (generic, KEEP)
2. `wrapPosition` - space_shooter (generic, KEEP)
3. `bounceOffWalls` - dodge_game (generic, KEEP)
4. `rectCollision` - breakout (generic, KEEP but rename)
5. `updateTimerMap` - breakout (utility, MOVE to different utils)
6. `countActive` - breakout (utility, MOVE to different utils)
7. `updateBallPhysics` - breakout (113 lines, DECOMPOSE)
8. `checkBallEntityCollisions` - breakout (54 lines, GENERALIZE)
9. `checkCollision` - breakout (generic collision, KEEP)
10. `releaseStickyBall` - breakout (REPLACE with launchFromOffset)

### Functions Only Called Internally (16):
- Most are generic primitives that should be EXPOSED
- `applyGravity`, `applyHomingForce`, `applyMagnetForce` - EXPOSE
- `clampSpeed`, `bounceAxis`, `reflectOffNormal` - EXPOSE
- `circleCollision`, `ballVsRect` (rename to circleVsRect) - EXPOSE

### Dead Code (4):
- `clampToBounds` - DELETE
- `pointInRect` - DELETE
- `updateBallWithBounds` - DELETE
- `checkEntityCollision` - DELETE

---

## Phase 1: Delete Dead Code

**What this phase accomplishes:** Removes 4 unused functions, reducing noise and line count.

**What will be noticed in-game:** Nothing. Dead code removal.

### Steps

1.1. Delete `clampToBounds` function entirely.

1.2. Delete `pointInRect` function entirely.

1.3. Delete `updateBallWithBounds` function entirely.

1.4. Delete `checkEntityCollision` function entirely.

1.5. Verify no code references these functions (grep/search).

### Testing (User)

- [ ] Game launches without errors
- [ ] Breakout plays normally
- [ ] Dodge plays normally
- [ ] Space Shooter plays normally
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-19

Deleted 4 dead code functions:
- `clampToBounds` (lines 133-141)
- `pointInRect` (lines 362-364)
- `updateBallWithBounds` (lines 451-498)
- `checkEntityCollision` (lines 534-584)

#### Line Changes
```
physics_utils.lua        -87 lines
```

---

## Phase 2: Rename "ball" Functions to Generic Names

**What this phase accomplishes:** Renames functions that say "ball" to what they actually do (circle collision). No behavior change.

**What will be noticed in-game:** Nothing. Pure rename refactor.

### Steps

2.1. Rename functions:
- `ballVsRect` → `circleVsRect`
- `ballVsCenteredRect` → `circleVsCenteredRect`
- `updateBallPhysics` → (keep for now, will decompose in Phase 4)
- `checkBallEntityCollisions` → `checkCircleEntityCollisions`

2.2. Update all internal callers in physics_utils.lua.

2.3. Update all external callers (breakout.lua uses checkBallEntityCollisions).

2.4. Search for any other "ball" references that should be "circle" or "entity".

### Testing (User)

- [ ] Breakout plays normally (ball physics unchanged)
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-19

Renamed functions:
- `ballVsRect` → `circleVsRect` (updated params from bx,by,br to cx,cy,cr)
- `ballVsCenteredRect` → `circleVsCenteredRect` (clearer param names)
- `checkBallEntityCollisions` → `checkCircleEntityCollisions` (updated internal `ball` refs to `circle`)

Updated internal callers in physics_utils.lua (2 calls to circleVsRect, 1 to circleVsCenteredRect).
Updated breakout.lua external callers (2 calls to checkCircleEntityCollisions).

#### Line Changes
```
physics_utils.lua        ~0 lines (renames only)
breakout.lua             ~0 lines (renames only)
```

---

## Phase 3: Move Non-Physics Utilities Out

**What this phase accomplishes:** Moves `updateTimerMap` and `countActive` to a more appropriate utility file. These aren't physics.

**What will be noticed in-game:** Nothing.

### Steps

3.1. Identify or create appropriate utility file (e.g., `table_utils.lua` or add to existing utils).

3.2. Move `updateTimerMap` function.

3.3. Move `countActive` function.

3.4. Update breakout.lua to require from new location.

3.5. DELETE the functions from physics_utils.lua.

### Testing (User)

- [ ] Breakout plays normally
- [ ] Timer-based effects work (brick flash)
- [ ] Ball counting works
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-19

Created `src/utils/table_utils.lua` with:
- `updateTimerMap(map, dt)` - decrements timers, removes expired
- `countActive(entities, filter)` - counts matching entities

Added `TableUtils` to `di.components` in main.lua.

Updated breakout.lua:
- Added `local TableUtils = self.di.components.TableUtils` in updateGameLogic
- Changed `Physics.updateTimerMap` → `TableUtils.updateTimerMap`
- Changed `Physics.countActive` → `TableUtils.countActive`

Deleted both functions from physics_utils.lua.

#### Line Changes
```
table_utils.lua          +21 lines (new)
main.lua                 +1 line
breakout.lua             +1 line (TableUtils local)
physics_utils.lua        -32 lines
```

---

## Phase 4: Expose Internal Primitives

**What this phase accomplishes:** Makes currently-internal generic functions available for external use.

**What will be noticed in-game:** Nothing. Just exposing functions.

### Steps

4.1. Ensure these functions are in the PhysicsUtils return table:
- `applyGravity(entity, strength, direction_degrees, dt)`
- `applyHomingForce(entity, target_x, target_y, strength, dt)`
- `applyMagnetForce(entity, target_x, target_y, range, strength, dt)`
- `clampSpeed(entity, max_speed)`
- `bounceAxis(entity, axis, mode)` - consider renaming to `reverseAxis`
- `reflectOffNormal(entity, nx, ny)`
- `circleNormal(center_x, center_y, point_x, point_y)`
- `increaseSpeed(entity, amount, max_speed)`
- `circleCollision(x1, y1, r1, x2, y2, r2)`

4.2. Review function signatures for consistency:
- All should use (entity, ...) pattern where entity has x, y, vx, vy
- All should be self-contained, not requiring game-specific context

4.3. Add brief header comments for each exposed function (what it does, parameters).

### Testing (User)

- [ ] All games still work
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-19

All primitives are already exposed - PhysicsUtils uses module-level function definitions (`PhysicsUtils.X`) and returns the table at the end, so all functions are accessible externally.

Verified exposed primitives (22 functions total):
- Forces: applyGravity, applyHomingForce, applyMagnetForce
- Speed: clampSpeed, increaseSpeed
- Bounce: bounceAxis, addBounceRandomness, reflectOffNormal
- Collision detection: circleCollision, rectCollision, circleVsRect, circleVsCenteredRect, checkCollision
- Collision response: resolveRectCollision, resolveCircleCollision, resolveBounceOffEntity
- Utilities: circleNormal, wrapPosition, bounceOffWalls, createTrailSystem
- Breakout-specific (to be decomposed): updateBallPhysics, checkCircleEntityCollisions, paddleBounce, releaseStickyBall

All functions have header comments explaining purpose and usage.

#### Line Changes
```
physics_utils.lua        917 → 729 lines (total -188 lines from phases 1-4)
```

---

## Phase 5: Create Generic Launch Function

**What this phase accomplishes:** Replaces `releaseStickyBall` with generic `launchFromOffset` that works for any game.

**What will be noticed in-game:** Nothing. Same behavior, generic function.

### Steps

5.1. Create `launchFromOffset(entity, anchor_x, anchor_width, speed, angle_range)`:
- Calculates angle based on entity position relative to anchor center
- Sets entity velocity at calculated angle with given speed
- Works for: sticky paddles, Bust-a-Move launchers, cannons, turrets

5.2. Create simpler `launchAtAngle(entity, angle_degrees, speed)`:
- Sets entity velocity at exact angle with given speed
- Building block for more complex launch behaviors

5.3. Update breakout.lua to use `launchFromOffset` instead of `releaseStickyBall`.

5.4. DELETE `releaseStickyBall` entirely.

### Testing (User)

- [ ] Breakout sticky ball release works identically
- [ ] Ball launches at correct angles based on paddle position
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-19

Created two generic launch functions:
- `launchAtAngle(entity, angle_radians, speed)` - direct angle launch
- `launchFromOffset(entity, offset_x, anchor_width, speed, base_angle, angle_range)` - position-based angle

Updated breakout.lua to use `launchFromOffset` instead of `releaseStickyBall`:
- Game now handles `ball.stuck = false` and `ball.magnet_immunity_timer` directly (game-specific state)
- Physics function is now purely about velocity calculation

Deleted `releaseStickyBall` entirely.

#### Line Changes
```
physics_utils.lua        ~+3 lines (replaced 22-line function with 26-line section including comments)
breakout.lua             ~+3 lines (expanded logic that was hidden in physics call)
```

---

## Phase 6: Create Unified Collision Response

**What this phase accomplishes:** Creates ONE smart `resolveCollision` function that handles ALL bouncing - paddles, walls, obstacles, bounds, circular bumpers, everything.

**What will be noticed in-game:** Nothing. Same behavior, one unified function.

**Philosophy:** Bouncing is bouncing. Whether it's:
- Ball hitting paddle
- Ball hitting wall
- Snake hitting boundary in smooth mode
- Obstacle bouncing off arena edge
- Pool ball hitting table cushion
- Pinball hitting bumper

They ALL do the same thing: detect surface, get normal, reflect velocity, apply restitution.

### Steps

6.1. Create `resolveCollision(moving, solid, config)`:
```lua
-- moving: entity with x, y, vx, vy, and shape info (radius or width/height)
-- solid: the thing being hit - can be:
--   - {type="rect", x, y, width, height}
--   - {type="circle", x, y, radius}
--   - {type="bounds", left, right, top, bottom}
--   - {type="line", x1, y1, x2, y2}
--   - or just an entity with shape info (auto-detect)
-- config (all optional):
--   - restitution: 0.0-1.0, bounciness (default 1.0)
--   - position_angle: {min, max} for paddle-style angle variance
--   - separate: true to push entities apart (default true)
--   - on_collide: callback(moving, solid, normal, edge)
-- returns: {hit=bool, normal={x,y}, edge="left"|"right"|"top"|"bottom"|nil}
```

6.2. Internal helper: `getNormal(moving, solid)`:
- For rect: determine which edge was hit, return axis-aligned normal
- For circle: return radial normal from circle center to collision point
- For bounds: return inward-facing normal for the edge hit
- For line: return perpendicular to line

6.3. Internal helper: `reflect(entity, normal, restitution)`:
- Standard reflection formula: v' = v - 2(v·n)n
- Apply restitution: v' = v' * restitution

6.4. Internal helper: `separate(moving, solid)`:
- Push moving entity out of solid so they don't overlap
- Uses minimum translation vector

6.5. DELETE these functions (absorbed into resolveCollision):
- `paddleBounce`
- `bounceAxis`
- `resolveRectCollision`
- `resolveCircleCollision`
- `resolveBounceOffEntity`

6.6. Update all callers to use `resolveCollision`:
- Breakout paddle collision
- Breakout obstacle collision
- Dodge obstacle bouncing

### Testing (User)

- [ ] Breakout paddle bounce works (angle varies by hit position)
- [ ] Breakout ball bounces off circular obstacles
- [ ] Dodge obstacles bounce off walls
- [ ] No console errors

### AI Notes

**Completed:** 2026-01-19

Created unified `resolveCollision(moving, solid, config)` that handles:
- Circle vs circle (radial normal reflection)
- Circle vs rect (edge detection, separation)
- Position-based angle bouncing (paddle-style, "spin" or "angle" modes)
- Restitution (bounciness, can be >1 for bumper boost)
- Centered rect support (for paddles where x is center)
- on_collide callback

Deleted:
- `resolveRectCollision` (absorbed into resolveCollision)
- `resolveCircleCollision` (absorbed into resolveCollision)
- `paddleBounce` (absorbed into resolveCollision with position_angle config)
- `resolveBounceOffEntity` (absorbed into resolveCollision)

Updated internal callers:
- updateBallPhysics paddle collision now uses resolveCollision with centered + position_angle
- checkCircleEntityCollisions now uses resolveCollision

Note: `bounceAxis` kept for now - used for wall bouncing, will be replaced in Phase 7.

#### Line Changes
```
physics_utils.lua        ~-30 lines (4 functions → 1 unified function)
```

---

## Phase 7: Create Unified Bounds Handling

**What this phase accomplishes:** Creates ONE `handleBounds` function for all boundary behavior - bouncing, wrapping, clamping, callbacks.

**What will be noticed in-game:** Nothing. Same behavior.

**Philosophy:** Bounds handling is the same whether it's:
- Breakout ball bouncing off walls
- Snake wrapping around screen
- Space shooter asteroids wrapping
- Dodge player clamped to arena
- Anything hitting arena edges

### Steps

7.1. Create `handleBounds(entity, bounds, config)`:
```lua
-- entity: has x, y, vx, vy, and optionally radius or width/height
-- bounds: {left, right, top, bottom} or {x, y, width, height}
-- config:
--   - mode: "bounce" | "wrap" | "clamp" | "none"
--   - restitution: for bounce mode (default 1.0)
--   - padding: inset from edges (default 0)
--   - per_edge: {left="wrap", right="wrap", top="bounce", bottom="callback"}
--   - on_exit: callback(entity, edge) when entity exits
-- returns: {hit=bool, edges={left=bool, right=bool, top=bool, bottom=bool}}
```

7.2. This replaces:
- Wall collision logic inside updateBallPhysics
- `bounceOffWalls` function (or absorb it)
- `wrapPosition` function (or keep as simple wrapper)

7.3. Key feature: per-edge behavior
```lua
-- Breakout: bounce on sides/top, callback on bottom (lose life)
PhysicsUtils.handleBounds(ball, arena, {
    per_edge = {left="bounce", right="bounce", top="bounce", bottom="none"},
    on_exit = function(entity, edge) if edge == "bottom" then loseLife() end end
})
```

7.4. DELETE redundant bound-handling code from updateBallPhysics.

### Testing (User)

- [ ] Breakout ball bounces off walls correctly
- [ ] Ball doesn't escape arena
- [ ] No console errors

### AI Notes

_(To be filled after completion)_

---

## Phase 8: Delete updateBallPhysics, Games Compose Primitives

**What this phase accomplishes:** Deletes the 113-line monolith. Games now compose the primitives we've created.

**What will be noticed in-game:** Nothing. Same behavior.

### Steps

8.1. Create simple `move(entity, dt)`:
```lua
entity.x = entity.x + entity.vx * dt
entity.y = entity.y + entity.vy * dt
```

8.2. Update breakout.lua to compose primitives:
```lua
function Breakout:updateBallPhysics(ball, dt)
    local p = self.params

    -- Forces (all optional based on variant)
    if p.gravity_enabled then
        PhysicsUtils.applyGravity(ball, p.gravity_strength, p.gravity_direction, dt)
    end
    if p.homing_enabled and self.homing_target then
        PhysicsUtils.applyHoming(ball, self.homing_target.x, self.homing_target.y, p.homing_strength, dt)
    end
    if p.magnet_enabled then
        PhysicsUtils.applyMagnet(ball, self.paddle.x, self.paddle.y, p.magnet_range, p.magnet_strength, dt)
    end

    -- Speed limit and movement
    PhysicsUtils.clampSpeed(ball, p.ball_max_speed)
    PhysicsUtils.move(ball, dt)

    -- Bounds
    local hit = PhysicsUtils.handleBounds(ball, self.arena, {
        per_edge = {left="bounce", right="bounce", top="bounce", bottom="none"},
        restitution = p.wall_restitution,
        on_exit = function(e, edge)
            if edge == "bottom" then self:onBallLost(ball) end
        end
    })

    -- Paddle collision (game-specific: uses resolveCollision with position-based angle)
    if PhysicsUtils.checkCollision(ball, self.paddle, {shape1="circle", shape2="rect"}) then
        PhysicsUtils.resolveCollision(ball, self.paddle, {
            position_angle = {min = p.paddle_angle_min, max = p.paddle_angle_max},
            restitution = 1.0
        })
    end
end
```

8.3. DELETE `updateBallPhysics` from physics_utils.lua entirely.

8.4. DELETE internal helpers that were only used by updateBallPhysics:
- Any Breakout-specific logic that was embedded

### Testing (User)

- [ ] Breakout ball physics works identically:
  - [ ] Gravity pulls ball correctly
  - [ ] Homing works if enabled
  - [ ] Magnet works if enabled
  - [ ] Speed limits enforced
  - [ ] Wall bounces work
  - [ ] Paddle bounces work
  - [ ] Ball loss at bottom works
- [ ] No console errors

### AI Notes

_(To be filled after completion)_

---

## Phase 9: Simplify Collision Group Checking

**What this phase accomplishes:** Makes batch collision checking generic - check one entity against many targets.

**What will be noticed in-game:** Nothing. Same behavior.

### Steps

9.1. Create `checkCollisions(entity, targets, config)`:
```lua
-- entity: the moving thing
-- targets: array of things to check against
-- config:
--   - filter: function(target) return true to include
--   - on_hit: callback(entity, target, collision_info)
--   - resolve: true to auto-resolve collisions (uses resolveCollision)
--   - stop_on_first: true to stop after first hit
-- returns: array of {target, collision_info} for all hits
```

9.2. This replaces `checkBallEntityCollisions` / `checkCircleEntityCollisions`.

9.3. Update breakout.lua brick/obstacle collision:
```lua
PhysicsUtils.checkCollisions(ball, self.bricks, {
    filter = function(brick) return brick.active end,
    on_hit = function(ball, brick, info)
        self:onBrickHit(brick, ball)
        PhysicsUtils.resolveCollision(ball, brick, {restitution = 1.0})
    end,
    stop_on_first = true  -- one brick per frame
})
```

9.4. DELETE `checkBallEntityCollisions` / `checkCircleEntityCollisions`.

### Testing (User)

- [ ] Breakout brick collisions work
- [ ] Breakout obstacle collisions work
- [ ] Multi-ball scenarios work
- [ ] No console errors

### AI Notes

_(To be filled after completion)_

---

## Phase 10: Final Cleanup and Documentation

**What this phase accomplishes:** Final organization, delete any remaining cruft, verify line count.

### Steps

10.1. Organize PhysicsUtils into logical sections:
```lua
-- === FORCES ===
-- applyGravity, applyHoming, applyMagnet, applyDrag

-- === MOVEMENT ===
-- move, clampSpeed, increaseSpeed

-- === COLLISION DETECTION ===
-- checkCollision (single pair, shape-aware)
-- checkCollisions (batch, with callbacks)
-- circleVsCircle, circleVsRect, rectVsRect (low-level)

-- === COLLISION RESPONSE ===
-- resolveCollision (THE bounce function - handles everything)
-- handleBounds (walls/arena edges)

-- === LAUNCHING ===
-- launchAtAngle, launchFromOffset

-- === UTILITIES ===
-- getNormal, wrapPosition, createTrailSystem
```

10.2. DELETE any remaining dead code or redundant functions:
- `bounceAxis` (absorbed into resolveCollision)
- `reflectOffNormal` (internal to resolveCollision)
- `bounceOffWalls` (replaced by handleBounds)
- Any other single-use helpers

10.3. Verify final line count is ~150-250 lines (down from 917).

10.4. Update the audit document with final state.

### Testing (User)

- [ ] All physics-using games work correctly
- [ ] Breakout, Dodge, Space Shooter all play identically
- [ ] Line count target achieved
- [ ] No console errors

### AI Notes

_(To be filled after completion)_

---

## Expected Final State

### PhysicsUtils API (~150-250 lines):

**Forces** (apply to entity.vx/vy):
- `applyGravity(entity, strength, direction_deg, dt)`
- `applyHoming(entity, target_x, target_y, strength, dt)`
- `applyMagnet(entity, target_x, target_y, range, strength, dt)`
- `applyDrag(entity, coefficient, dt)`

**Movement:**
- `move(entity, dt)` - Apply velocity to position
- `clampSpeed(entity, max)` - Limit speed
- `increaseSpeed(entity, amount, max)` - Boost speed

**Collision Detection:**
- `checkCollision(e1, e2, config)` - Single pair, returns bool + info
- `checkCollisions(entity, targets, config)` - Batch with callbacks

**Collision Response (ONE smart function):**
- `resolveCollision(moving, solid, config)` - THE bounce function
  - Works for: paddles, walls, obstacles, bumpers, anything
  - Handles: circles, rects, auto-detect shapes
  - Config: restitution, position_angle, separate, on_collide
- `handleBounds(entity, bounds, config)` - Arena edges
  - Modes: bounce, wrap, clamp, per-edge config
  - Callbacks for exit events

**Launching:**
- `launchAtAngle(entity, angle_deg, speed)`
- `launchFromOffset(entity, anchor_x, anchor_width, speed, angle_range)`

**Utilities:**
- `wrapPosition(x, y, entity_w, entity_h, bounds_w, bounds_h)`
- `createTrailSystem(config)`

**TOTAL: ~15 functions instead of 30**

### What Games Do Now:

**Breakout:**
```lua
function Breakout:updateBall(ball, dt)
    -- Forces
    if p.gravity_enabled then PhysicsUtils.applyGravity(ball, p.gravity, 90, dt) end
    if p.homing_enabled then PhysicsUtils.applyHoming(ball, target.x, target.y, p.homing_strength, dt) end

    -- Move
    PhysicsUtils.clampSpeed(ball, p.ball_max_speed)
    PhysicsUtils.move(ball, dt)

    -- Bounds (bounce sides/top, callback on bottom)
    PhysicsUtils.handleBounds(ball, self.arena, {
        per_edge = {left="bounce", right="bounce", top="bounce", bottom="none"},
        on_exit = function(e, edge) if edge == "bottom" then self:loseLife() end end
    })

    -- Paddle
    if PhysicsUtils.checkCollision(ball, self.paddle) then
        PhysicsUtils.resolveCollision(ball, self.paddle, {
            position_angle = {min=210, max=330}
        })
    end

    -- Bricks
    PhysicsUtils.checkCollisions(ball, self.bricks, {
        filter = function(b) return b.active end,
        on_hit = function(ball, brick) self:onBrickHit(brick, ball) end,
        resolve = true
    })
end
```

**Snake (smooth mode wall bounce):**
```lua
PhysicsUtils.handleBounds(snake_head, arena, {mode = "bounce", restitution = 0.8})
```

**Dodge (obstacle bouncing):**
```lua
PhysicsUtils.move(obstacle, dt)
PhysicsUtils.handleBounds(obstacle, arena, {mode = "bounce"})
```

**Space Shooter (homing missiles):**
```lua
PhysicsUtils.applyHoming(missile, target.x, target.y, 100, dt)
PhysicsUtils.move(missile, dt)
```

**Future Pool Game:**
```lua
PhysicsUtils.applyDrag(ball, 0.98, dt)
PhysicsUtils.move(ball, dt)
PhysicsUtils.handleBounds(ball, table, {mode = "bounce", restitution = 0.95})
-- Ball-to-ball
if PhysicsUtils.checkCollision(ball1, ball2) then
    PhysicsUtils.resolveCollision(ball1, ball2, {restitution = 0.9})
end
```

**Future Pinball:**
```lua
PhysicsUtils.applyGravity(ball, 500, 90, dt)
PhysicsUtils.move(ball, dt)
-- Bumper collision
if PhysicsUtils.checkCollision(ball, bumper) then
    PhysicsUtils.resolveCollision(ball, bumper, {restitution = 1.5})  -- >1 = boost
end
```

---

## Verification Checklist

After all phases complete:

- [ ] PhysicsUtils is ~150-250 lines (down from 917)
- [ ] ~15 functions instead of 30
- [ ] No function names contain "ball" (unless it's actually about balls)
- [ ] No function requires Breakout-specific knowledge
- [ ] ONE bounce function (`resolveCollision`) handles all collision response
- [ ] ONE bounds function (`handleBounds`) handles all edge behavior
- [ ] Every function could theoretically be used by 2+ different game types
- [ ] All 3 current physics games work: Breakout, Dodge, Space Shooter
- [ ] Dead code is gone (4 functions deleted)
- [ ] Non-physics utilities moved out (updateTimerMap, countActive)
- [ ] Games compose primitives instead of calling monoliths
- [ ] New games (pool, pinball, platformer) could use these primitives without modification
