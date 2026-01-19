local PhysicsUtils = {}

-- ===================================================================
-- TRAIL SYSTEM
-- ===================================================================
-- Creates a trail effect that follows a moving object
-- Used by: Dodge (player trail), Breakout (ball trail)
--
-- Usage:
--   self.trail = PhysicsUtils.createTrailSystem({
--       max_length = 10,
--       color = {0.5, 0.8, 1, 1}
--   })
--   self.trail:addPoint(x, y)  -- Call each frame to add position
--   self.trail:draw()          -- Render the trail

function PhysicsUtils.createTrailSystem(config)
    local trail = {
        max_length = config.max_length or 10,
        color = config.color or {1, 1, 1, 1},
        line_width = config.line_width or 2,
        buffer = {}
    }

    function trail:addPoint(x, y)
        table.insert(self.buffer, {x = x, y = y})
        while #self.buffer > self.max_length do
            table.remove(self.buffer, 1)
        end
    end

    function trail:clear()
        self.buffer = {}
    end

    function trail:draw()
        if #self.buffer < 2 then return end

        love.graphics.push()
        love.graphics.setLineWidth(self.line_width)

        for i = 1, #self.buffer - 1 do
            local p1 = self.buffer[i]
            local p2 = self.buffer[i + 1]
            local alpha = (i / #self.buffer) * self.color[4]
            love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end

        love.graphics.setLineWidth(1)
        love.graphics.pop()
    end

    function trail:getLength()
        return #self.buffer
    end

    return trail
end

-- ===================================================================
-- SCREEN WRAP
-- ===================================================================
-- Wraps an entity's position to opposite side when it exits bounds
-- Used by: Space Shooter (player ship, asteroids, bullets)
--
-- Usage:
--   local new_x, new_y = PhysicsUtils.wrapPosition(x, y, width, height, bounds_w, bounds_h)

function PhysicsUtils.wrapPosition(x, y, entity_width, entity_height, bounds_width, bounds_height)
    local new_x = x
    local new_y = y
    local half_w = entity_width / 2
    local half_h = entity_height / 2

    -- Wrap horizontally
    if x + half_w < 0 then
        new_x = bounds_width + half_w
    elseif x - half_w > bounds_width then
        new_x = -half_w
    end

    -- Wrap vertically
    if y + half_h < 0 then
        new_y = bounds_height + half_h
    elseif y - half_h > bounds_height then
        new_y = -half_h
    end

    return new_x, new_y
end

-- ===================================================================
-- BOUNCE PHYSICS
-- ===================================================================
-- Reflects velocity when colliding with boundaries
-- Used by: Dodge (wall bounce), Breakout (ball bounce)
--
-- Usage:
--   local new_vx, new_vy = PhysicsUtils.bounceOffWalls(x, y, vx, vy, radius, bounds_w, bounds_h, restitution)

function PhysicsUtils.bounceOffWalls(x, y, vx, vy, radius, bounds_width, bounds_height, restitution)
    restitution = restitution or 1.0  -- Default: perfect elastic collision
    local new_vx = vx
    local new_vy = vy

    -- Left/right walls
    if x - radius < 0 then
        new_vx = math.abs(vx) * restitution
    elseif x + radius > bounds_width then
        new_vx = -math.abs(vx) * restitution
    end

    -- Top/bottom walls
    if y - radius < 0 then
        new_vy = math.abs(vy) * restitution
    elseif y + radius > bounds_height then
        new_vy = -math.abs(vy) * restitution
    end

    return new_vx, new_vy
end

-- ===================================================================
-- CLAMP TO BOUNDS
-- ===================================================================
-- Constrains entity position to stay within bounds (no wrap, no bounce)
-- Used by: Most games for player movement constraints
--
-- Usage:
--   local new_x, new_y = PhysicsUtils.clampToBounds(x, y, width, height, bounds_w, bounds_h)

function PhysicsUtils.clampToBounds(x, y, entity_width, entity_height, bounds_width, bounds_height)
    local half_w = entity_width / 2
    local half_h = entity_height / 2

    local new_x = math.max(half_w, math.min(x, bounds_width - half_w))
    local new_y = math.max(half_h, math.min(y, bounds_height - half_h))

    return new_x, new_y
end

-- ===================================================================
-- DIRECTIONAL GRAVITY
-- ===================================================================
-- Applies gravity force in any direction (not just down)
-- Used by: Breakout (ball gravity), any physics game
--
-- Usage:
--   PhysicsUtils.applyGravity(ball, 200, 270, dt)  -- 270 = downward

function PhysicsUtils.applyGravity(entity, gravity, direction_degrees, dt)
    if gravity == 0 then return end
    local rad = math.rad(direction_degrees)
    entity.vx = entity.vx + math.cos(rad) * gravity * dt
    entity.vy = entity.vy + math.sin(rad) * gravity * dt
end

-- ===================================================================
-- HOMING FORCE
-- ===================================================================
-- Applies force toward a target position
-- Used by: Homing missiles, seeking projectiles, Breakout ball homing
--
-- Usage:
--   PhysicsUtils.applyHomingForce(projectile, target.x, target.y, 0.5, dt)

function PhysicsUtils.applyHomingForce(entity, target_x, target_y, strength, dt)
    if strength <= 0 then return end
    local dx = target_x - entity.x
    local dy = target_y - entity.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 0 then
        local force = strength * 50
        entity.vx = entity.vx + (dx / dist) * force * dt
        entity.vy = entity.vy + (dy / dist) * force * dt
    end
end

-- ===================================================================
-- MAGNET FORCE
-- ===================================================================
-- Applies attraction force within a range (stronger when closer)
-- Used by: Magnet powerups, attraction mechanics
--
-- Usage:
--   PhysicsUtils.applyMagnetForce(ball, paddle.x, paddle.y, 150, 800, dt)

function PhysicsUtils.applyMagnetForce(entity, target_x, target_y, range, strength, dt)
    if range <= 0 then return end
    local dx = target_x - entity.x
    local dy = target_y - entity.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < range and dist > 0 then
        local force = (1 - dist / range) * strength
        entity.vx = entity.vx + (dx / dist) * force * dt
        entity.vy = entity.vy + (dy / dist) * force * dt
    end
end

-- ===================================================================
-- SPEED CLAMPING
-- ===================================================================
-- Limits entity speed to a maximum value
-- Used by: Any game with speed limits
--
-- Usage:
--   PhysicsUtils.clampSpeed(ball, 600)

function PhysicsUtils.clampSpeed(entity, max_speed)
    local speed = math.sqrt(entity.vx * entity.vx + entity.vy * entity.vy)
    if speed > max_speed and speed > 0 then
        local scale = max_speed / speed
        entity.vx = entity.vx * scale
        entity.vy = entity.vy * scale
    end
end

-- ===================================================================
-- BOUNCE RANDOMNESS
-- ===================================================================
-- Adds random angle variance to velocity (keeps speed constant)
-- Used by: Breakout, any game wanting unpredictable bounces
--
-- Usage:
--   PhysicsUtils.addBounceRandomness(ball, 0.2, rng)  -- 0.2 = 20% of pi radians max

function PhysicsUtils.addBounceRandomness(entity, randomness, rng)
    if randomness <= 0 then return end
    local speed = math.sqrt(entity.vx * entity.vx + entity.vy * entity.vy)
    local angle = math.atan2(entity.vy, entity.vx)
    local variance = (rng:random() - 0.5) * randomness * math.pi
    local new_angle = angle + variance
    entity.vx = math.cos(new_angle) * speed
    entity.vy = math.sin(new_angle) * speed
end

-- ===================================================================
-- BOUNCE WITH MODES
-- ===================================================================
-- Enhanced wall bounce with different physics modes
-- Modes: "normal" (elastic), "damped" (loses energy), "sticky" (high friction)
-- Used by: Breakout, Pong variants, pinball
--
-- Usage:
--   PhysicsUtils.bounceAxis(ball, 'vx', "damped")

function PhysicsUtils.bounceAxis(entity, axis, mode)
    mode = mode or "normal"
    if mode == "damped" then
        entity[axis] = -entity[axis] * 0.9
    elseif mode == "sticky" then
        entity[axis] = -entity[axis] * 0.6
    else
        entity[axis] = -entity[axis]
    end
end

-- ===================================================================
-- REFLECT OFF SURFACE
-- ===================================================================
-- Reflects velocity off a surface given a normal vector (preserves speed)
-- Used by: Circle brick collision, angled surfaces, PNG collision
--
-- Usage:
--   PhysicsUtils.reflectOffNormal(ball, nx, ny)

function PhysicsUtils.reflectOffNormal(entity, nx, ny)
    local speed_before = math.sqrt(entity.vx * entity.vx + entity.vy * entity.vy)
    local dot = entity.vx * nx + entity.vy * ny
    entity.vx = entity.vx - 2 * dot * nx
    entity.vy = entity.vy - 2 * dot * ny
    -- Preserve speed (prevent energy loss from numerical errors)
    local speed_after = math.sqrt(entity.vx * entity.vx + entity.vy * entity.vy)
    if speed_after > 0 then
        local scale = speed_before / speed_after
        entity.vx = entity.vx * scale
        entity.vy = entity.vy * scale
    end
end

-- ===================================================================
-- CALCULATE CIRCLE NORMAL
-- ===================================================================
-- Gets the outward normal from a circle center to a point
-- Used by: Circle collision response
--
-- Usage:
--   local nx, ny = PhysicsUtils.circleNormal(circle_x, circle_y, point_x, point_y)

function PhysicsUtils.circleNormal(center_x, center_y, point_x, point_y)
    local dx = point_x - center_x
    local dy = point_y - center_y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        return dx / len, dy / len
    end
    return 0, -1  -- Default upward if coincident
end

-- ===================================================================
-- INCREASE SPEED
-- ===================================================================
-- Increases entity speed by a fixed amount, capped at max
-- Used by: Breakout ball speed increase on brick hit
--
-- Usage:
--   PhysicsUtils.increaseSpeed(ball, 5, 600)

function PhysicsUtils.increaseSpeed(entity, amount, max_speed)
    if amount <= 0 then return end
    local current = math.sqrt(entity.vx * entity.vx + entity.vy * entity.vy)
    local new_speed = math.min(current + amount, max_speed)
    if current > 0 then
        local scale = new_speed / current
        entity.vx = entity.vx * scale
        entity.vy = entity.vy * scale
    end
end

-- ===================================================================
-- CIRCULAR COLLISION
-- ===================================================================
-- Detects collision between two circular entities
-- Used by: Most games for collision detection
--
-- Usage:
--   local colliding = PhysicsUtils.circleCollision(x1, y1, r1, x2, y2, r2)

function PhysicsUtils.circleCollision(x1, y1, radius1, x2, y2, radius2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)
    return distance < (radius1 + radius2)
end

-- ===================================================================
-- RECTANGULAR COLLISION (AABB)
-- ===================================================================
-- Detects collision between two axis-aligned rectangular entities
-- Used by: Games with rectangular hitboxes
--
-- Usage:
--   local colliding = PhysicsUtils.rectCollision(x1, y1, w1, h1, x2, y2, w2, h2)

function PhysicsUtils.rectCollision(x1, y1, width1, height1, x2, y2, width2, height2)
    return x1 < x2 + width2 and
           x2 < x1 + width1 and
           y1 < y2 + height2 and
           y2 < y1 + height1
end

-- ===================================================================
-- POINT IN RECTANGLE
-- ===================================================================
-- Checks if a point is inside a rectangle
-- Used by: UI interactions, hitbox checks
--
-- Usage:
--   local inside = PhysicsUtils.pointInRect(px, py, rx, ry, rw, rh)

function PhysicsUtils.pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- ===================================================================
-- BALL VS RECTANGLE COLLISION
-- ===================================================================
-- Checks if a ball (circle) collides with an axis-aligned rectangle
-- Used by: Breakout (ball vs brick/paddle), any ball game
--
-- Usage:
--   local hit = PhysicsUtils.ballVsRect(ball.x, ball.y, ball.radius, rect.x, rect.y, rect.width, rect.height)

function PhysicsUtils.ballVsRect(bx, by, br, rx, ry, rw, rh)
    return bx + br > rx and bx - br < rx + rw and
           by + br > ry and by - br < ry + rh
end

-- ===================================================================
-- BALL VS CENTERED RECT COLLISION
-- ===================================================================
-- Checks ball vs rectangle where rect position is center (not top-left)
-- Used by: Paddle collision (center-based positioning)

function PhysicsUtils.ballVsCenteredRect(bx, by, br, cx, cy, hw, hh)
    return bx + br > cx - hw and bx - br < cx + hw and
           by + br > cy - hh and by - br < cy + hh
end

-- ===================================================================
-- RESOLVE BALL VS RECT COLLISION
-- ===================================================================
-- Determines which side of rectangle was hit and resolves position/velocity
-- Returns: side ("top", "bottom", "left", "right"), new_x, new_y
-- Used by: Breakout brick collision response
--
-- Usage:
--   local side = PhysicsUtils.resolveRectCollision(ball, brick.x, brick.y, brick.width, brick.height)

function PhysicsUtils.resolveRectCollision(entity, rx, ry, rw, rh)
    local pen_left = (entity.x + entity.radius) - rx
    local pen_right = (rx + rw) - (entity.x - entity.radius)
    local pen_top = (entity.y + entity.radius) - ry
    local pen_bottom = (ry + rh) - (entity.y - entity.radius)

    local min_pen = math.min(pen_left, pen_right, pen_top, pen_bottom)

    if min_pen == pen_top then
        entity.y = ry - entity.radius - 1
        entity.vy = -math.abs(entity.vy)
        return "top"
    elseif min_pen == pen_bottom then
        entity.y = ry + rh + entity.radius + 1
        entity.vy = math.abs(entity.vy)
        return "bottom"
    elseif min_pen == pen_left then
        entity.x = rx - entity.radius - 1
        entity.vx = -math.abs(entity.vx)
        return "left"
    else
        entity.x = rx + rw + entity.radius + 1
        entity.vx = math.abs(entity.vx)
        return "right"
    end
end

-- ===================================================================
-- RESOLVE BALL VS CIRCLE COLLISION
-- ===================================================================
-- Reflects ball off a circular obstacle and separates them
-- Used by: Circle brick collision, circular obstacles

function PhysicsUtils.resolveCircleCollision(ball, cx, cy, cr)
    local nx, ny = PhysicsUtils.circleNormal(cx, cy, ball.x, ball.y)
    PhysicsUtils.reflectOffNormal(ball, nx, ny)
    local separation = cr + ball.radius
    ball.x = cx + nx * separation
    ball.y = cy + ny * separation
end

-- ===================================================================
-- UPDATE BALL WITH WALL BOUNDS
-- ===================================================================
-- Handles ball movement and wall collisions with configurable boundaries
-- Used by: Any game with bouncing balls
--
-- Usage:
--   PhysicsUtils.updateBallWithBounds(ball, dt, bounds, config, rng)

function PhysicsUtils.updateBallWithBounds(ball, dt, bounds, config, rng)
    config = config or {}
    local bounce_mode = config.bounce_mode or "normal"
    local randomness = config.randomness or 0
    local ceiling = config.ceiling ~= false
    local floor_kill = config.floor_kill ~= false

    -- Update position
    ball.x = ball.x + ball.vx * dt
    ball.y = ball.y + ball.vy * dt

    -- Left/right walls
    if ball.x - ball.radius < bounds.x_min then
        ball.x = bounds.x_min + ball.radius
        PhysicsUtils.bounceAxis(ball, 'vx', bounce_mode)
        if randomness > 0 and rng then PhysicsUtils.addBounceRandomness(ball, randomness, rng) end
    elseif ball.x + ball.radius > bounds.x_max then
        ball.x = bounds.x_max - ball.radius
        PhysicsUtils.bounceAxis(ball, 'vx', bounce_mode)
        if randomness > 0 and rng then PhysicsUtils.addBounceRandomness(ball, randomness, rng) end
    end

    -- Top (ceiling)
    if ball.y - ball.radius < bounds.y_min then
        if ceiling then
            ball.y = bounds.y_min + ball.radius
            PhysicsUtils.bounceAxis(ball, 'vy', bounce_mode)
            if randomness > 0 and rng then PhysicsUtils.addBounceRandomness(ball, randomness, rng) end
        else
            ball.active = false
            return false
        end
    end

    -- Bottom (floor)
    if ball.y + ball.radius > bounds.y_max then
        if floor_kill then
            ball.active = false
            return false
        else
            ball.y = bounds.y_max - ball.radius
            PhysicsUtils.bounceAxis(ball, 'vy', bounce_mode)
            if randomness > 0 and rng then PhysicsUtils.addBounceRandomness(ball, randomness, rng) end
        end
    end

    return true
end

-- ===================================================================
-- PADDLE BOUNCE RESPONSE
-- ===================================================================
-- Calculates ball velocity after hitting a paddle based on hit position
-- Modes: "spin" (add horizontal based on position), "angle" (set angle based on position)

function PhysicsUtils.paddleBounce(ball, paddle_x, paddle_width, mode)
    mode = mode or "spin"
    local offset = ball.x - paddle_x
    local normalized = offset / (paddle_width / 2)
    normalized = math.max(-1, math.min(1, normalized))

    if mode == "angle" or mode == "position" then
        local speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
        local angle = -math.pi / 2 + normalized * (math.pi / 4)
        ball.vx = math.cos(angle) * speed
        ball.vy = math.sin(angle) * speed
    else
        ball.vy = -math.abs(ball.vy)
        ball.vx = ball.vx + normalized * 100
    end
end

-- ===================================================================
-- GENERIC ENTITY COLLISION
-- ===================================================================
-- Checks collision between any two entities based on their shape properties
-- Automatically detects: circle (has radius), rect (has width/height), centered rect (has width/height and centered=true)
-- Used by: Any game needing collision between varied entity shapes
--
-- Usage:
--   local hit = PhysicsUtils.checkEntityCollision(ball, brick)
--   local hit = PhysicsUtils.checkEntityCollision(ball, paddle, {paddle_centered = true})

function PhysicsUtils.checkEntityCollision(e1, e2, options)
    options = options or {}

    -- Determine shapes
    local e1_circle = e1.radius and not e1.width
    local e2_circle = e2.radius and not e2.width

    -- Get effective positions and sizes
    local x1, y1, r1, w1, h1
    local x2, y2, r2, w2, h2

    if e1_circle then
        x1, y1, r1 = e1.x, e1.y, e1.radius
    else
        w1, h1 = e1.width or e1.size or 0, e1.height or e1.size or 0
        if options.e1_centered then
            x1, y1 = e1.x - w1/2, e1.y - h1/2
        else
            x1, y1 = e1.x, e1.y
        end
    end

    if e2_circle then
        x2, y2, r2 = e2.x, e2.y, e2.radius
    else
        w2, h2 = e2.width or e2.size or 0, e2.height or e2.size or 0
        if options.e2_centered then
            x2, y2 = e2.x - w2/2, e2.y - h2/2
        else
            x2, y2 = e2.x, e2.y
        end
    end

    -- Circle vs Circle
    if e1_circle and e2_circle then
        return PhysicsUtils.circleCollision(x1, y1, r1, x2, y2, r2)
    end

    -- Circle vs Rect
    if e1_circle and not e2_circle then
        return PhysicsUtils.ballVsRect(x1, y1, r1, x2, y2, w2, h2)
    end

    -- Rect vs Circle
    if not e1_circle and e2_circle then
        return PhysicsUtils.ballVsRect(x2, y2, r2, x1, y1, w1, h1)
    end

    -- Rect vs Rect
    return PhysicsUtils.rectCollision(x1, y1, w1, h1, x2, y2, w2, h2)
end

-- ===================================================================
-- ENTITY COLLISION WITH SHAPE OVERRIDE
-- ===================================================================
-- Like checkEntityCollision but allows explicit shape specification
-- Useful when entity has both radius and width (e.g., circle brick with size)
--
-- Usage:
--   local hit = PhysicsUtils.checkCollision(ball, brick, "circle", brick.shape)

function PhysicsUtils.checkCollision(e1, e2, shape1, shape2, options)
    options = options or {}
    shape1 = shape1 or (e1.shape or (e1.radius and "circle") or "rect")
    shape2 = shape2 or (e2.shape or (e2.radius and "circle") or "rect")

    local x1, y1 = e1.x, e1.y
    local x2, y2 = e2.x, e2.y

    -- Circle vs Circle
    if shape1 == "circle" and shape2 == "circle" then
        local r1 = e1.radius or (e1.width or e1.size or 0) / 2
        local r2 = e2.radius or (e2.width or e2.size or 0) / 2
        local cx1 = x1 + (e1.width and e1.width/2 or 0)
        local cy1 = y1 + (e1.height and e1.height/2 or 0)
        local cx2 = x2 + (e2.width and e2.width/2 or 0)
        local cy2 = y2 + (e2.height and e2.height/2 or 0)
        return PhysicsUtils.circleCollision(cx1, cy1, r1, cx2, cy2, r2)
    end

    -- Circle vs Rect
    if shape1 == "circle" and shape2 ~= "circle" then
        local r1 = e1.radius or (e1.width or e1.size or 0) / 2
        local w2, h2 = e2.width or e2.size or 0, e2.height or e2.size or 0
        return PhysicsUtils.ballVsRect(x1, y1, r1, x2, y2, w2, h2)
    end

    -- Rect vs Circle
    if shape1 ~= "circle" and shape2 == "circle" then
        local r2 = e2.radius or (e2.width or e2.size or 0) / 2
        local w1, h1 = e1.width or e1.size or 0, e1.height or e1.size or 0
        local cx2 = x2 + (e2.width and e2.width/2 or 0)
        local cy2 = y2 + (e2.height and e2.height/2 or 0)
        return PhysicsUtils.ballVsRect(cx2, cy2, r2, x1, y1, w1, h1)
    end

    -- Rect vs Rect
    local w1, h1 = e1.width or e1.size or 0, e1.height or e1.size or 0
    local w2, h2 = e2.width or e2.size or 0, e2.height or e2.size or 0
    return PhysicsUtils.rectCollision(x1, y1, w1, h1, x2, y2, w2, h2)
end

-- ===================================================================
-- RESOLVE BOUNCE OFF ENTITY
-- ===================================================================
-- Reflects a ball off another entity based on shape (circle or rect)
-- Handles position separation to prevent overlap
-- Used by: Ball vs brick, ball vs obstacle
--
-- Usage:
--   PhysicsUtils.resolveBounceOffEntity(ball, brick)

function PhysicsUtils.resolveBounceOffEntity(ball, target)
    local shape = target.shape or "rect"

    if shape == "circle" then
        local cx = target.x + (target.radius or target.width / 2)
        local cy = target.y + (target.radius or target.height / 2)
        local radius = target.radius or target.width / 2
        PhysicsUtils.resolveCircleCollision(ball, cx, cy, radius)
    else
        local w = target.width or target.size or 0
        local h = target.height or target.size or 0
        PhysicsUtils.resolveRectCollision(ball, target.x, target.y, w, h)
    end
end

-- ===================================================================
-- COUNT ACTIVE ENTITIES
-- ===================================================================
-- Counts entities matching a filter in an array
-- Used by: Checking active balls, alive enemies, etc.
--
-- Usage:
--   local count = PhysicsUtils.countActive(balls, function(b) return b.active end)

function PhysicsUtils.countActive(entities, filter)
    local count = 0
    filter = filter or function(e) return e.active end
    for _, e in ipairs(entities) do
        if filter(e) then count = count + 1 end
    end
    return count
end

-- ===================================================================
-- RELEASE STICKY BALL
-- ===================================================================
-- Releases a ball stuck to a paddle, calculating launch angle from position
--
-- Usage:
--   PhysicsUtils.releaseStickyBall(ball, paddle_width, launch_speed, angle_range)

function PhysicsUtils.releaseStickyBall(ball, paddle_width, launch_speed, angle_range)
    if not ball.stuck then return false end

    ball.stuck = false
    local offset_x = ball.stuck_offset_x or 0
    local max_offset = paddle_width / 2
    local normalized = math.max(-1, math.min(1, offset_x / max_offset))
    local angle = -math.pi / 2 + normalized * (angle_range or math.pi / 6)

    ball.vx = math.cos(angle) * (launch_speed or 300)
    ball.vy = math.sin(angle) * (launch_speed or 300)
    ball.magnet_immunity_timer = 0.3  -- Prevent magnet from pulling back

    return true
end

-- ===================================================================
-- UPDATE TIMER MAP
-- ===================================================================
-- Decrements timers in a table and removes expired entries
-- Used for: flash effects, cooldowns, etc.
--
-- Usage:
--   PhysicsUtils.updateTimerMap(self.brick_flash_map, dt)

function PhysicsUtils.updateTimerMap(map, dt)
    for key, timer in pairs(map) do
        map[key] = timer - dt
        if map[key] <= 0 then map[key] = nil end
    end
end

-- ===================================================================
-- BALL PHYSICS UPDATE
-- ===================================================================
-- Generic ball physics: gravity, homing, magnet, sticky, walls, paddle
-- Returns false if ball became inactive
--
-- config: {
--   gravity, gravity_direction, homing_strength, homing_target_func,
--   magnet_target, magnet_range, magnet_strength,
--   sticky_enabled, sticky_entity,
--   bounds = {width, height}, ceiling_enabled, bottom_kill_enabled,
--   shield_flag, wall_bounce_mode, bounce_randomness, rng,
--   paddle, paddle_sticky, paddle_aim_mode, max_speed,
--   trail_length, on_paddle_hit
-- }

function PhysicsUtils.updateBallPhysics(ball, dt, config)
    -- Apply gravity
    if config.gravity and config.gravity > 0 then
        PhysicsUtils.applyGravity(ball, config.gravity, config.gravity_direction or 270, dt)
    end

    -- Apply homing
    if config.homing_strength and config.homing_strength > 0 and config.homing_target_func then
        local target = config.homing_target_func()
        if target then
            PhysicsUtils.applyHomingForce(ball, target.x, target.y, config.homing_strength, dt)
        end
    end

    -- Update magnet immunity timer
    if ball.magnet_immunity_timer and ball.magnet_immunity_timer > 0 then
        ball.magnet_immunity_timer = ball.magnet_immunity_timer - dt
    end

    -- Apply magnet force
    local magnet_immune = ball.magnet_immunity_timer and ball.magnet_immunity_timer > 0
    if config.magnet_range and config.magnet_range > 0 and not magnet_immune and ball.vy > 0 then
        local mt = config.magnet_target or config.paddle
        if mt and not (ball.stuck and config.sticky_enabled) then
            PhysicsUtils.applyMagnetForce(ball, mt.x, mt.y, config.magnet_range, config.magnet_strength or 800, dt)
        end
    end

    -- Handle sticky
    if ball.stuck and config.sticky_enabled then
        local se = config.sticky_entity or config.paddle
        if se then
            ball.x = se.x + (ball.stuck_offset_x or 0)
            ball.y = se.y + (ball.stuck_offset_y or 0)
        end
        return true  -- Still active but stuck
    end

    -- Update position
    ball.x = ball.x + ball.vx * dt
    ball.y = ball.y + ball.vy * dt

    -- Update trail
    if config.trail_length and config.trail_length > 0 and ball.trail then
        table.insert(ball.trail, 1, {x = ball.x, y = ball.y})
        while #ball.trail > config.trail_length do table.remove(ball.trail) end
    end

    local bounds = config.bounds or {width = 800, height = 600}
    local mode = config.wall_bounce_mode or "normal"
    local rng = config.rng

    -- Wall collisions (left, right)
    if ball.x - ball.radius < 0 then
        ball.x = ball.radius
        PhysicsUtils.bounceAxis(ball, 'vx', mode)
        if config.bounce_randomness then PhysicsUtils.addBounceRandomness(ball, config.bounce_randomness, rng) end
    elseif ball.x + ball.radius > bounds.width then
        ball.x = bounds.width - ball.radius
        PhysicsUtils.bounceAxis(ball, 'vx', mode)
        if config.bounce_randomness then PhysicsUtils.addBounceRandomness(ball, config.bounce_randomness, rng) end
    end

    -- Top boundary
    if ball.y - ball.radius < 0 then
        if config.ceiling_enabled then
            ball.y = ball.radius
            PhysicsUtils.bounceAxis(ball, 'vy', mode)
            if config.bounce_randomness then PhysicsUtils.addBounceRandomness(ball, config.bounce_randomness, rng) end
        else
            ball.active = false
            return false
        end
    end

    -- Bottom boundary
    if ball.y - ball.radius > bounds.height then
        if config.bottom_kill_enabled ~= false then
            if config.shield_active then
                config.shield_active = false
                ball.y = bounds.height - ball.radius
                ball.vy = -math.abs(ball.vy)
            else
                ball.active = false
                return false
            end
        else
            ball.y = bounds.height - ball.radius
            PhysicsUtils.bounceAxis(ball, 'vy', mode)
            if config.bounce_randomness then PhysicsUtils.addBounceRandomness(ball, config.bounce_randomness, rng) end
        end
    end

    -- Paddle collision
    local paddle = config.paddle
    if paddle then
        if PhysicsUtils.ballVsCenteredRect(ball.x, ball.y, ball.radius, paddle.x, paddle.y, paddle.width / 2, paddle.height / 2) then
            if config.paddle_sticky and not ball.stuck then
                ball.stuck = true
                ball.stuck_offset_x = ball.x - paddle.x
                ball.stuck_offset_y = ball.y - paddle.y
                ball.vx, ball.vy = 0, 0
            else
                ball.y = paddle.y - ball.radius - paddle.height / 2
                PhysicsUtils.paddleBounce(ball, paddle.x, paddle.width, config.paddle_aim_mode)
                if config.bounce_randomness then PhysicsUtils.addBounceRandomness(ball, config.bounce_randomness, rng) end
                if config.max_speed then PhysicsUtils.clampSpeed(ball, config.max_speed) end
            end
            if config.on_paddle_hit then config.on_paddle_hit(ball) end
        end
    end

    return true
end

-- ===================================================================
-- BALL VS ENTITIES COLLISION
-- ===================================================================
-- Check ball against array of entities and call callbacks
-- Returns true if collision occurred
--
-- config: {
--   check_func, on_hit, on_destroy, bounce_randomness, speed_increase, max_speed, rng,
--   pierce_enabled, resolve_bounce
-- }

function PhysicsUtils.checkBallEntityCollisions(ball, entities, config)
    config = config or {}
    local hit_any = false

    for _, entity in ipairs(entities) do
        if entity.alive then
            local hit = config.check_func and config.check_func(ball, entity) or PhysicsUtils.checkCollision(ball, entity, "circle", entity.shape)

            if hit then
                hit_any = true

                -- Call hit callback
                if config.on_hit then
                    config.on_hit(entity, ball)
                end

                -- Check if destroyed
                if entity.health then
                    entity.health = entity.health - 1
                    if entity.health <= 0 then
                        entity.alive = false
                        if config.on_destroy then config.on_destroy(entity, ball) end
                    end
                end

                -- Resolve bounce
                if not (ball.pierce_count and ball.pierce_count > 0) then
                    if config.resolve_bounce ~= false then
                        PhysicsUtils.resolveBounceOffEntity(ball, entity)
                    end
                else
                    ball.pierce_count = ball.pierce_count - 1
                end

                -- Speed increase
                if config.speed_increase and config.max_speed then
                    PhysicsUtils.increaseSpeed(ball, config.speed_increase, config.max_speed)
                end

                -- Bounce randomness
                if config.bounce_randomness and not (ball.pierce_count and ball.pierce_count > 0) then
                    PhysicsUtils.addBounceRandomness(ball, config.bounce_randomness, config.rng)
                end

                -- Break unless piercing
                if not (ball.pierce_count and ball.pierce_count > 0) then
                    break
                end
            end
        end
    end

    return hit_any
end

return PhysicsUtils
