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

return PhysicsUtils
