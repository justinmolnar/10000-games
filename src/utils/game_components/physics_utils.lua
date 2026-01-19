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
-- UNIFIED BOUNDS HANDLING
-- ===================================================================
-- ONE function for all boundary behavior: bounce, wrap, clamp, callbacks
--
-- entity: has x, y, vx, vy, and radius or width/height
-- bounds: {left, right, top, bottom} or {width, height} (assumes 0,0 origin)
-- config:
--   mode: "bounce" | "wrap" | "clamp" | "none" (default for all edges)
--   restitution: for bounce mode (default 1.0)
--   per_edge: {left="bounce", right="wrap", top="bounce", bottom="none"} overrides
--   on_exit: callback(entity, edge) when entity exits/hits boundary
--   bounce_randomness: optional randomness to add after bounce
--   rng: random generator for bounce_randomness
--
-- Returns: {hit=bool, edges={left=bool, right=bool, top=bool, bottom=bool}}

function PhysicsUtils.handleBounds(entity, bounds, config)
    config = config or {}
    local mode = config.mode or "bounce"
    local restitution = config.restitution or 1.0
    local per_edge = config.per_edge or {}

    -- Normalize bounds format
    local left = bounds.left or bounds.x or 0
    local top = bounds.top or bounds.y or 0
    local right = bounds.right or (left + (bounds.width or 800))
    local bottom = bounds.bottom or (top + (bounds.height or 600))

    -- Get entity size
    local radius = entity.radius or 0
    local half_w = radius > 0 and radius or (entity.width or 0) / 2
    local half_h = radius > 0 and radius or (entity.height or 0) / 2

    local result = {hit = false, edges = {left = false, right = false, top = false, bottom = false}}

    local function handleEdge(edge, axis, pos_field, vel_field, boundary, inside_dir)
        local edge_mode = per_edge[edge] or mode
        if edge_mode == "none" then
            -- Just report the exit, don't modify anything
            result.hit = true
            result.edges[edge] = true
            if config.on_exit then config.on_exit(entity, edge) end
            return
        end

        result.hit = true
        result.edges[edge] = true

        if edge_mode == "bounce" then
            entity[pos_field] = boundary + inside_dir * half_w
            entity[vel_field] = inside_dir * math.abs(entity[vel_field]) * restitution
            if config.bounce_randomness and config.rng then
                PhysicsUtils.addBounceRandomness(entity, config.bounce_randomness, config.rng)
            end
        elseif edge_mode == "wrap" then
            if inside_dir > 0 then
                -- Exited left/top, wrap to right/bottom
                entity[pos_field] = (edge == "left" or edge == "right") and (right - half_w) or (bottom - half_h)
            else
                -- Exited right/bottom, wrap to left/top
                entity[pos_field] = (edge == "left" or edge == "right") and (left + half_w) or (top + half_h)
            end
        elseif edge_mode == "clamp" then
            entity[pos_field] = boundary + inside_dir * half_w
            entity[vel_field] = 0
        end

        if config.on_exit then config.on_exit(entity, edge) end
    end

    -- Check each edge
    if entity.x - half_w < left then
        handleEdge("left", "x", "x", "vx", left, 1)
    elseif entity.x + half_w > right then
        handleEdge("right", "x", "x", "vx", right, -1)
    end

    if entity.y - half_h < top then
        handleEdge("top", "y", "y", "vy", top, 1)
    elseif entity.y + half_h > bottom then
        handleEdge("bottom", "y", "y", "vy", bottom, -1)
    end

    return result
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
-- CIRCLE VS RECTANGLE COLLISION
-- ===================================================================
-- Checks if a circle collides with an axis-aligned rectangle
-- Used by: Any game with circular entities vs rectangular ones
--
-- Usage:
--   local hit = PhysicsUtils.circleVsRect(circle.x, circle.y, circle.radius, rect.x, rect.y, rect.width, rect.height)

function PhysicsUtils.circleVsRect(cx, cy, cr, rx, ry, rw, rh)
    return cx + cr > rx and cx - cr < rx + rw and
           cy + cr > ry and cy - cr < ry + rh
end

-- ===================================================================
-- CIRCLE VS CENTERED RECT COLLISION
-- ===================================================================
-- Checks circle vs rectangle where rect position is center (not top-left)
-- Used by: Entities with center-based positioning

function PhysicsUtils.circleVsCenteredRect(circle_x, circle_y, circle_r, rect_cx, rect_cy, half_w, half_h)
    return circle_x + circle_r > rect_cx - half_w and circle_x - circle_r < rect_cx + half_w and
           circle_y + circle_r > rect_cy - half_h and circle_y - circle_r < rect_cy + half_h
end

-- ===================================================================
-- UNIFIED COLLISION RESPONSE
-- ===================================================================
-- ONE function that handles ALL collision response: bouncing off rects, circles, paddles, etc.
--
-- moving: entity with x, y, vx, vy, radius (the thing that bounces)
-- solid: what it hit - entity with shape info, or explicit {type="rect/circle", ...}
-- config (all optional):
--   restitution: 0.0-1.0 bounciness (default 1.0, >1.0 for boost like pinball bumpers)
--   position_angle: "spin" or "angle" for paddle-style position-based angle
--   surface_width: width of surface for position_angle calculation
--   on_collide: callback(moving, solid, edge)
--
-- Returns: {edge="top/bottom/left/right/circle", nx, ny}

function PhysicsUtils.resolveCollision(moving, solid, config)
    config = config or {}
    local restitution = config.restitution or 1.0

    -- Determine solid's shape and dimensions
    -- Prioritize width/height over radius (paddle has both but is a rect)
    local shape = solid.type or solid.shape or ((solid.width and solid.height) and "rect") or (solid.radius and "circle") or "rect"
    local result = {edge = nil, nx = 0, ny = 0}

    if shape == "circle" then
        -- Circle collision: reflect off radial normal
        local cx = solid.cx or solid.x + (solid.radius or (solid.width or 0) / 2)
        local cy = solid.cy or solid.y + (solid.radius or (solid.height or 0) / 2)
        local cr = solid.radius or (solid.width or solid.size or 0) / 2

        local nx, ny = PhysicsUtils.circleNormal(cx, cy, moving.x, moving.y)
        PhysicsUtils.reflectOffNormal(moving, nx, ny)

        -- Apply restitution
        moving.vx = moving.vx * restitution
        moving.vy = moving.vy * restitution

        -- Separate
        local separation = cr + moving.radius + 1
        moving.x = cx + nx * separation
        moving.y = cy + ny * separation

        result.edge = "circle"
        result.nx, result.ny = nx, ny
    else
        -- Rect collision: determine edge and bounce
        local rx = solid.x or 0
        local ry = solid.y or 0
        local rw = solid.width or solid.size or 0
        local rh = solid.height or solid.size or 0

        -- Handle centered rects (like paddles with x at center)
        if solid.centered or config.centered then
            rx = rx - rw / 2
            ry = ry - rh / 2
        end

        local pen_left = (moving.x + moving.radius) - rx
        local pen_right = (rx + rw) - (moving.x - moving.radius)
        local pen_top = (moving.y + moving.radius) - ry
        local pen_bottom = (ry + rh) - (moving.y - moving.radius)

        local min_pen = math.min(pen_left, pen_right, pen_top, pen_bottom)

        -- Position-based angle (for paddles) - always treat as top collision
        if config.position_angle then
            local surface_center = rx + rw / 2
            local surface_width = config.surface_width or rw
            local offset = moving.x - surface_center
            local normalized = math.max(-1, math.min(1, offset / (surface_width / 2)))

            if config.position_angle == "angle" or config.position_angle == "position" then
                local speed = math.sqrt(moving.vx * moving.vx + moving.vy * moving.vy) * restitution
                local angle = -math.pi / 2 + normalized * (math.pi / 4)
                moving.vx = math.cos(angle) * speed
                moving.vy = math.sin(angle) * speed
            else -- "spin" mode
                moving.vy = -math.abs(moving.vy) * restitution
                moving.vx = moving.vx * restitution + normalized * 100
            end

            -- Separate (always above for paddles)
            moving.y = ry - moving.radius - 1
            result.edge = "top"
            result.ny = -1
        else
            -- Standard rect bounce
            if min_pen == pen_top then
                moving.y = ry - moving.radius - 1
                moving.vy = -math.abs(moving.vy) * restitution
                moving.vx = moving.vx * restitution
                result.edge = "top"
                result.ny = -1
            elseif min_pen == pen_bottom then
                moving.y = ry + rh + moving.radius + 1
                moving.vy = math.abs(moving.vy) * restitution
                moving.vx = moving.vx * restitution
                result.edge = "bottom"
                result.ny = 1
            elseif min_pen == pen_left then
                moving.x = rx - moving.radius - 1
                moving.vx = -math.abs(moving.vx) * restitution
                moving.vy = moving.vy * restitution
                result.edge = "left"
                result.nx = -1
            else
                moving.x = rx + rw + moving.radius + 1
                moving.vx = math.abs(moving.vx) * restitution
                moving.vy = moving.vy * restitution
                result.edge = "right"
                result.nx = 1
            end
        end
    end

    if config.on_collide then
        config.on_collide(moving, solid, result.edge)
    end

    return result
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
        return PhysicsUtils.circleVsRect(x1, y1, r1, x2, y2, w2, h2)
    end

    -- Rect vs Circle
    if shape1 ~= "circle" and shape2 == "circle" then
        local r2 = e2.radius or (e2.width or e2.size or 0) / 2
        local w1, h1 = e1.width or e1.size or 0, e1.height or e1.size or 0
        local cx2 = x2 + (e2.width and e2.width/2 or 0)
        local cy2 = y2 + (e2.height and e2.height/2 or 0)
        return PhysicsUtils.circleVsRect(cx2, cy2, r2, x1, y1, w1, h1)
    end

    -- Rect vs Rect
    local w1, h1 = e1.width or e1.size or 0, e1.height or e1.size or 0
    local w2, h2 = e2.width or e2.size or 0, e2.height or e2.size or 0
    return PhysicsUtils.rectCollision(x1, y1, w1, h1, x2, y2, w2, h2)
end

-- ===================================================================
-- LAUNCHING
-- ===================================================================

-- Launch entity at exact angle with given speed
-- angle_radians: direction (0 = right, -pi/2 = up, pi/2 = down)
-- Works for: projectiles, balls, launched enemies, cannons
function PhysicsUtils.launchAtAngle(entity, angle_radians, speed)
    entity.vx = math.cos(angle_radians) * speed
    entity.vy = math.sin(angle_radians) * speed
end

-- Launch entity with angle based on offset from anchor center
-- offset_x: entity's horizontal offset from anchor center
-- anchor_width: width of anchor (for normalizing offset)
-- base_angle: center angle in radians (default -pi/2 = straight up)
-- angle_range: max deviation from base_angle (default pi/6 = 30 degrees)
-- Works for: sticky paddles, Bust-a-Move launchers, aimed turrets
function PhysicsUtils.launchFromOffset(entity, offset_x, anchor_width, speed, base_angle, angle_range)
    base_angle = base_angle or -math.pi / 2
    angle_range = angle_range or math.pi / 6
    local max_offset = anchor_width / 2
    local normalized = math.max(-1, math.min(1, offset_x / max_offset))
    local angle = base_angle + normalized * angle_range
    entity.vx = math.cos(angle) * speed
    entity.vy = math.sin(angle) * speed
end

-- ===================================================================
-- MOVEMENT
-- ===================================================================
-- Simple position update from velocity
-- Used by: Any entity with velocity-based movement

function PhysicsUtils.move(entity, dt)
    entity.x = entity.x + entity.vx * dt
    entity.y = entity.y + entity.vy * dt
end

-- ===================================================================
-- CIRCLE VS ENTITIES COLLISION
-- ===================================================================
-- Check circle entity against array of entities and call callbacks
-- Returns true if collision occurred
--
-- config: {
--   check_func, on_hit, on_destroy, bounce_randomness, speed_increase, max_speed, rng,
--   pierce_enabled, resolve_bounce
-- }

function PhysicsUtils.checkCircleEntityCollisions(circle, entities, config)
    config = config or {}
    local hit_any = false

    for _, entity in ipairs(entities) do
        if entity.alive then
            local hit = config.check_func and config.check_func(circle, entity) or PhysicsUtils.checkCollision(circle, entity, "circle", entity.shape)

            if hit then
                hit_any = true

                -- Call hit callback
                if config.on_hit then
                    config.on_hit(entity, circle)
                end

                -- Check if destroyed
                if entity.health then
                    entity.health = entity.health - 1
                    if entity.health <= 0 then
                        entity.alive = false
                        if config.on_destroy then config.on_destroy(entity, circle) end
                    end
                end

                -- Resolve bounce
                if not (circle.pierce_count and circle.pierce_count > 0) then
                    if config.resolve_bounce ~= false then
                        PhysicsUtils.resolveCollision(circle, entity)
                    end
                else
                    circle.pierce_count = circle.pierce_count - 1
                end

                -- Speed increase
                if config.speed_increase and config.max_speed then
                    PhysicsUtils.increaseSpeed(circle, config.speed_increase, config.max_speed)
                end

                -- Bounce randomness
                if config.bounce_randomness and not (circle.pierce_count and circle.pierce_count > 0) then
                    PhysicsUtils.addBounceRandomness(circle, config.bounce_randomness, config.rng)
                end

                -- Break unless piercing
                if not (circle.pierce_count and circle.pierce_count > 0) then
                    break
                end
            end
        end
    end

    return hit_any
end

return PhysicsUtils
