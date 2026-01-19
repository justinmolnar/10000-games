# PhysicsUtils Function Audit

Every function in `physics_utils.lua`, what it does, and where it's called.

---

## FUNCTIONS CALLED BY GAMES (External Usage)

### 1. `createTrailSystem(config)`
**What it does:** Creates a trail effect object that stores position history and draws fading lines.
**Called from:**
- `dodge_game.lua:142` - Player trail

---

### 2. `wrapPosition(x, y, entity_width, entity_height, bounds_width, bounds_height)`
**What it does:** Wraps entity position to opposite side when exiting bounds (screen wrap).
**Called from:**
- `space_shooter.lua:2062` - Asteroid/ship screen wrapping

---

### 3. `bounceOffWalls(x, y, vx, vy, radius, bounds_width, bounds_height, restitution)`
**What it does:** Returns new velocity after bouncing off boundaries.
**Called from:**
- `dodge_game.lua:1030` - Obstacle bouncing off walls

---

### 4. `rectCollision(x1, y1, width1, height1, x2, y2, width2, height2)`
**What it does:** AABB rectangle collision detection.
**Called from:**
- `breakout.lua:241` - Brick collision check in updateBehaviors
- `breakout.lua:314` - Bullet vs brick collision

---

### 5. `updateTimerMap(map, dt)`
**What it does:** Decrements all timers in a table, removes expired entries.
**Called from:**
- `breakout.lua:277` - Brick flash effect timers

---

### 6. `countActive(entities, filter)`
**What it does:** Counts entities matching a filter function.
**Called from:**
- `breakout.lua:328` - Count active balls

---

### 7. `updateBallPhysics(ball, dt, config)`
**What it does:** Monolithic ball update with gravity, homing, magnet, sticky, walls, paddle collision.
**Called from:**
- `breakout.lua:365` - Ball physics update

---

### 8. `checkBallEntityCollisions(ball, entities, config)`
**What it does:** Checks ball against entity array with callbacks for hit/destroy.
**Called from:**
- `breakout.lua:383` - Ball vs bricks
- `breakout.lua:396` - Ball vs obstacles

---

### 9. `checkCollision(e1, e2, shape1, shape2, options)`
**What it does:** Shape-aware collision detection with explicit shape override.
**Called from:**
- `breakout.lua:387` - Ball vs brick (inside checkBallEntityCollisions callback)

---

### 10. `releaseStickyBall(ball, paddle_width, launch_speed, angle_range)`
**What it does:** Releases a stuck ball, calculating launch angle from position offset.
**Called from:**
- `breakout.lua:437` - Sticky paddle ball release

---

## FUNCTIONS ONLY CALLED INTERNALLY (within physics_utils.lua)

### 11. `clampToBounds(x, y, entity_width, entity_height, bounds_width, bounds_height)`
**What it does:** Constrains position to stay within bounds.
**Called from:** NOWHERE - Dead code

---

### 12. `applyGravity(entity, gravity, direction_degrees, dt)`
**What it does:** Applies directional gravity force to entity velocity.
**Called from:**
- `physics_utils.lua:738` - Inside updateBallPhysics

---

### 13. `applyHomingForce(entity, target_x, target_y, strength, dt)`
**What it does:** Applies force toward a target position.
**Called from:**
- `physics_utils.lua:745` - Inside updateBallPhysics

---

### 14. `applyMagnetForce(entity, target_x, target_y, range, strength, dt)`
**What it does:** Applies attraction force within a range.
**Called from:**
- `physics_utils.lua:759` - Inside updateBallPhysics

---

### 15. `clampSpeed(entity, max_speed)`
**What it does:** Limits entity speed to maximum value.
**Called from:**
- `physics_utils.lua:841` - Inside updateBallPhysics

---

### 16. `addBounceRandomness(entity, randomness, rng)`
**What it does:** Adds random angle variance to velocity.
**Called from:**
- `physics_utils.lua:466,470,478,493` - Inside updateBallWithBounds
- `physics_utils.lua:791,795,803,824,840` - Inside updateBallPhysics
- `physics_utils.lua:902` - Inside checkBallEntityCollisions

---

### 17. `bounceAxis(entity, axis, mode)`
**What it does:** Reverses velocity on one axis with optional damping.
**Called from:**
- `physics_utils.lua:465,469,477,492` - Inside updateBallWithBounds
- `physics_utils.lua:790,794,802,823` - Inside updateBallPhysics

---

### 18. `reflectOffNormal(entity, nx, ny)`
**What it does:** Reflects velocity off a surface normal.
**Called from:**
- `physics_utils.lua:436` - Inside resolveCircleCollision

---

### 19. `circleNormal(center_x, center_y, point_x, point_y)`
**What it does:** Gets outward normal from circle center to a point.
**Called from:**
- `physics_utils.lua:435` - Inside resolveCircleCollision

---

### 20. `increaseSpeed(entity, amount, max_speed)`
**What it does:** Increases entity speed by fixed amount, capped at max.
**Called from:**
- `physics_utils.lua:897` - Inside checkBallEntityCollisions

---

### 21. `circleCollision(x1, y1, radius1, x2, y2, radius2)`
**What it does:** Circle vs circle collision detection.
**Called from:**
- `physics_utils.lua:569` - Inside checkEntityCollision
- `physics_utils.lua:611` - Inside checkCollision

---

### 22. `pointInRect(px, py, rx, ry, rw, rh)`
**What it does:** Point inside rectangle check.
**Called from:** NOWHERE - Dead code

---

### 23. `ballVsRect(bx, by, br, rx, ry, rw, rh)`
**What it does:** Circle vs axis-aligned rectangle collision.
**Called from:**
- `physics_utils.lua:574,579` - Inside checkEntityCollision
- `physics_utils.lua:618,627` - Inside checkCollision

---

### 24. `ballVsCenteredRect(bx, by, br, cx, cy, hw, hh)`
**What it does:** Circle vs center-positioned rectangle collision.
**Called from:**
- `physics_utils.lua:831` - Inside updateBallPhysics

---

### 25. `resolveRectCollision(entity, rx, ry, rw, rh)`
**What it does:** Determines which side was hit and resolves position/velocity.
**Called from:**
- `physics_utils.lua:657` - Inside resolveBounceOffEntity

---

### 26. `resolveCircleCollision(ball, cx, cy, cr)`
**What it does:** Reflects ball off circular obstacle and separates them.
**Called from:**
- `physics_utils.lua:653` - Inside resolveBounceOffEntity

---

### 27. `updateBallWithBounds(ball, dt, bounds, config, rng)`
**What it does:** Ball movement with wall collisions (simpler than updateBallPhysics).
**Called from:** NOWHERE - Dead code (superseded by updateBallPhysics)

---

### 28. `paddleBounce(ball, paddle_x, paddle_width, mode)`
**What it does:** Calculates ball velocity after hitting paddle based on hit position.
**Called from:**
- `physics_utils.lua:839` - Inside updateBallPhysics

---

### 29. `checkEntityCollision(e1, e2, options)`
**What it does:** Auto-detects shapes and checks collision.
**Called from:** NOWHERE - Dead code (checkCollision used instead)

---

### 30. `resolveBounceOffEntity(ball, target)`
**What it does:** Bounces ball off entity based on target shape.
**Called from:**
- `physics_utils.lua:889` - Inside checkBallEntityCollisions

---

## SUMMARY

### Actually used by games (external):
1. `createTrailSystem` - dodge_game (1 call)
2. `wrapPosition` - space_shooter (1 call)
3. `bounceOffWalls` - dodge_game (1 call)
4. `rectCollision` - breakout (2 calls)
5. `updateTimerMap` - breakout (1 call)
6. `countActive` - breakout (1 call)
7. `updateBallPhysics` - breakout (1 call)
8. `checkBallEntityCollisions` - breakout (2 calls)
9. `checkCollision` - breakout (1 call)
10. `releaseStickyBall` - breakout (1 call)

### Only called internally (from other PhysicsUtils functions):
- `applyGravity`, `applyHomingForce`, `applyMagnetForce`, `clampSpeed`
- `addBounceRandomness`, `bounceAxis`, `reflectOffNormal`, `circleNormal`
- `increaseSpeed`, `circleCollision`, `ballVsRect`, `ballVsCenteredRect`
- `resolveRectCollision`, `resolveCircleCollision`, `paddleBounce`, `resolveBounceOffEntity`

### Dead code (never called):
- `clampToBounds`
- `pointInRect`
- `updateBallWithBounds`
- `checkEntityCollision`

---

## PROBLEMS IDENTIFIED

### 1. Breakout-specific monoliths
- `updateBallPhysics` - 113 lines, 20+ config options, only used by Breakout
- `checkBallEntityCollisions` - 54 lines, specific callback structure, only used by Breakout
- `releaseStickyBall` - Breakout-specific naming and logic

### 2. Naming says "ball" when it means "circle"
- `ballVsRect` → should be `circleVsRect`
- `ballVsCenteredRect` → should be `circleVsCenteredRect`
- `checkBallEntityCollisions` → should be `checkCircleEntityCollisions` or generic

### 3. Paddle-specific functions
- `paddleBounce` - Only used inside updateBallPhysics

### 4. Dead code
- 4 functions never called anywhere

### 5. Useful generic primitives buried inside monoliths
- `applyGravity`, `applyHomingForce`, `applyMagnetForce` - Generic but only called internally
- `bounceAxis`, `reflectOffNormal` - Generic but only called internally
- `circleCollision`, `rectCollision` - Generic, rectCollision used externally

### 6. Low external usage
- Only 3 games use PhysicsUtils at all (breakout, dodge_game, space_shooter)
- 8 of 10 external calls are from Breakout alone
- Most functions exist to serve the Breakout monoliths
