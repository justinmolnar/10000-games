local PhysicsUtils = {}

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║                           FORCES                                   ║
-- ╚═══════════════════════════════════════════════════════════════════╝

function PhysicsUtils.applyGravity(entity, gravity, direction_degrees, dt)
    if gravity == 0 then return end
    local rad = math.rad(direction_degrees)
    entity.vx = entity.vx + math.cos(rad) * gravity * dt
    entity.vy = entity.vy + math.sin(rad) * gravity * dt
end

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

-- Apply gravity well pull (modifies velocity like homing - entities curve toward well)
-- strength_multiplier: optional multiplier (default 1.0)
-- For entities with vx/vy: modifies velocity (bullets curve smoothly)
-- For entities without vx/vy: modifies position directly (player gets pulled)
function PhysicsUtils.applyGravityWell(entity, well, dt, strength_multiplier)
    strength_multiplier = strength_multiplier or 1.0
    local entity_cx = entity.x + (entity.width or 0) / 2
    local entity_cy = entity.y + (entity.height or 0) / 2
    local dx = well.x - entity_cx
    local dy = well.y - entity_cy
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < well.radius and dist > 0 then
        -- Stronger pull when closer (inverse distance)
        local pull_factor = math.min(1.0, well.radius / dist)
        local force = well.strength * pull_factor * strength_multiplier * dt
        local dir_x, dir_y = dx / dist, dy / dist

        -- If entity has velocity, modify it (bullets) - they'll curve
        if entity.vx ~= nil then
            entity.vx = entity.vx + dir_x * force
            entity.vy = entity.vy + dir_y * force
        else
            -- No velocity, modify position directly (player)
            entity.x = entity.x + dir_x * force * dt
            entity.y = entity.y + dir_y * force * dt
        end
    end
end

-- Apply multiple forces from params config
-- params: {gravity, gravity_direction, homing_strength, magnet_range, gravity_wells}
-- findTarget: optional function() returning {x, y} or nil for homing
-- magnetTarget: optional {x, y} for magnet force
function PhysicsUtils.applyForces(entity, params, dt, findTarget, magnetTarget)
    if params.gravity and params.gravity > 0 then
        PhysicsUtils.applyGravity(entity, params.gravity, params.gravity_direction or 270, dt)
    end
    if params.homing_strength and params.homing_strength > 0 and findTarget then
        local target = findTarget()
        if target then
            PhysicsUtils.applyHomingForce(entity, target.x, target.y, params.homing_strength, dt)
        end
    end
    -- Magnet with immunity timer
    if entity.magnet_immunity_timer and entity.magnet_immunity_timer > 0 then
        entity.magnet_immunity_timer = entity.magnet_immunity_timer - dt
    end
    local magnet_immune = entity.magnet_immunity_timer and entity.magnet_immunity_timer > 0
    if params.magnet_range and params.magnet_range > 0 and not magnet_immune and magnetTarget then
        if not entity.stuck and entity.vy > 0 then
            PhysicsUtils.applyMagnetForce(entity, magnetTarget.x, magnetTarget.y, params.magnet_range, 800, dt)
        end
    end
    -- Gravity wells: array of {x, y, radius, strength}
    if params.gravity_wells then
        local strength_mult = params.gravity_well_strength_multiplier or 1.0
        for _, well in ipairs(params.gravity_wells) do
            PhysicsUtils.applyGravityWell(entity, well, dt, strength_mult)
        end
    end
end

-- Handle kill plane on any edge with optional shield
-- edge: "bottom", "top", "left", "right"
-- boundary: the coordinate of the kill plane
-- Returns true if entity was killed, false otherwise
function PhysicsUtils.handleKillPlane(entity, edge, boundary, config)
    config = config or {}
    local radius = entity.radius or 0
    local pos, vel, inside_dir

    if edge == "bottom" then
        if entity.y - radius <= boundary then return false end
        pos, vel, inside_dir = "y", "vy", -1
    elseif edge == "top" then
        if entity.y + radius >= boundary then return false end
        pos, vel, inside_dir = "y", "vy", 1
    elseif edge == "right" then
        if entity.x - radius <= boundary then return false end
        pos, vel, inside_dir = "x", "vx", -1
    elseif edge == "left" then
        if entity.x + radius >= boundary then return false end
        pos, vel, inside_dir = "x", "vx", 1
    else
        return false
    end

    if config.kill_enabled == false then
        entity[pos] = boundary + inside_dir * radius
        entity[vel] = inside_dir * math.abs(entity[vel]) * (config.restitution or 1.0)
        if config.bounce_randomness and config.rng then
            PhysicsUtils.addBounceRandomness(entity, config.bounce_randomness, config.rng)
        end
        return false
    end

    if config.shield_active then
        if config.on_shield_use then config.on_shield_use() end
        entity[pos] = boundary + inside_dir * radius
        entity[vel] = inside_dir * math.abs(entity[vel])
        return false
    end

    entity.active = false
    return true
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║                          MOVEMENT                                  ║
-- ╚═══════════════════════════════════════════════════════════════════╝

function PhysicsUtils.move(entity, dt)
    entity.x = entity.x + entity.vx * dt
    entity.y = entity.y + entity.vy * dt
end

function PhysicsUtils.clampSpeed(entity, max_speed)
    local speed = math.sqrt(entity.vx * entity.vx + entity.vy * entity.vy)
    if speed > max_speed and speed > 0 then
        local scale = max_speed / speed
        entity.vx = entity.vx * scale
        entity.vy = entity.vy * scale
    end
end

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

function PhysicsUtils.addBounceRandomness(entity, randomness, rng)
    if randomness <= 0 then return end
    local speed = math.sqrt(entity.vx * entity.vx + entity.vy * entity.vy)
    local angle = math.atan2(entity.vy, entity.vx)
    local variance = (rng:random() - 0.5) * randomness * math.pi
    local new_angle = angle + variance
    entity.vx = math.cos(new_angle) * speed
    entity.vy = math.sin(new_angle) * speed
end

-- Apply common bounce effects (speed increase, randomness)
-- params: {speed_increase, max_speed, bounce_randomness}
function PhysicsUtils.applyBounceEffects(entity, params, rng)
    if params.speed_increase and params.max_speed then
        PhysicsUtils.increaseSpeed(entity, params.speed_increase, params.max_speed)
    end
    if params.bounce_randomness and rng then
        PhysicsUtils.addBounceRandomness(entity, params.bounce_randomness, rng)
    end
end

-- Returns true if entity is attached and position was updated, false otherwise
function PhysicsUtils.handleAttachment(entity, parent, offset_x_key, offset_y_key)
    if not entity.stuck then return false end
    entity.x = parent.x + (entity[offset_x_key] or 0)
    entity.y = parent.y + (entity[offset_y_key] or 0)
    return true
end

-- Attach an entity to a parent, storing position offsets and zeroing velocity
function PhysicsUtils.attachToEntity(entity, parent, y_offset)
    y_offset = y_offset or 0
    entity.stuck = true
    entity.stuck_offset_x = entity.x - parent.x
    entity.y = parent.y + y_offset
    entity.stuck_offset_y = entity.y - parent.y
    entity.vx, entity.vy = 0, 0
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║                      COLLISION DETECTION                           ║
-- ╚═══════════════════════════════════════════════════════════════════╝

function PhysicsUtils.circleCollision(x1, y1, radius1, x2, y2, radius2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)
    return distance < (radius1 + radius2)
end

function PhysicsUtils.rectCollision(x1, y1, width1, height1, x2, y2, width2, height2)
    return x1 < x2 + width2 and
           x2 < x1 + width1 and
           y1 < y2 + height2 and
           y2 < y1 + height1
end

function PhysicsUtils.circleVsRect(cx, cy, cr, rx, ry, rw, rh)
    return cx + cr > rx and cx - cr < rx + rw and
           cy + cr > ry and cy - cr < ry + rh
end

function PhysicsUtils.circleVsCenteredRect(circle_x, circle_y, circle_r, rect_cx, rect_cy, half_w, half_h)
    return circle_x + circle_r > rect_cx - half_w and circle_x - circle_r < rect_cx + half_w and
           circle_y + circle_r > rect_cy - half_h and circle_y - circle_r < rect_cy + half_h
end

-- Shape-aware collision check between two entities
function PhysicsUtils.checkCollision(e1, e2, shape1, shape2)
    shape1 = shape1 or (e1.shape or (e1.radius and "circle") or "rect")
    shape2 = shape2 or (e2.shape or (e2.radius and "circle") or "rect")

    local x1, y1 = e1.x, e1.y
    local x2, y2 = e2.x, e2.y

    if shape1 == "circle" and shape2 == "circle" then
        local r1 = e1.radius or (e1.width or e1.size or 0) / 2
        local r2 = e2.radius or (e2.width or e2.size or 0) / 2
        local cx1 = x1 + (e1.width and e1.width/2 or 0)
        local cy1 = y1 + (e1.height and e1.height/2 or 0)
        local cx2 = x2 + (e2.width and e2.width/2 or 0)
        local cy2 = y2 + (e2.height and e2.height/2 or 0)
        return PhysicsUtils.circleCollision(cx1, cy1, r1, cx2, cy2, r2)
    end

    if shape1 == "circle" and shape2 ~= "circle" then
        local r1 = e1.radius or (e1.width or e1.size or 0) / 2
        local w2, h2 = e2.width or e2.size or 0, e2.height or e2.size or 0
        return PhysicsUtils.circleVsRect(x1, y1, r1, x2, y2, w2, h2)
    end

    if shape1 ~= "circle" and shape2 == "circle" then
        local r2 = e2.radius or (e2.width or e2.size or 0) / 2
        local w1, h1 = e1.width or e1.size or 0, e1.height or e1.size or 0
        local cx2 = x2 + (e2.width and e2.width/2 or 0)
        local cy2 = y2 + (e2.height and e2.height/2 or 0)
        return PhysicsUtils.circleVsRect(cx2, cy2, r2, x1, y1, w1, h1)
    end

    local w1, h1 = e1.width or e1.size or 0, e1.height or e1.size or 0
    local w2, h2 = e2.width or e2.size or 0, e2.height or e2.size or 0
    return PhysicsUtils.rectCollision(x1, y1, w1, h1, x2, y2, w2, h2)
end

-- Batch collision check against array of targets
function PhysicsUtils.checkCollisions(entity, targets, config)
    config = config or {}
    local hit_any = false
    local stop_on_first = config.stop_on_first ~= false

    for _, target in ipairs(targets) do
        local include = config.filter and config.filter(target) or target.alive
        if include then
            local hit = config.check_func and config.check_func(entity, target) or PhysicsUtils.checkCollision(entity, target)

            if hit then
                hit_any = true
                if config.on_hit then config.on_hit(entity, target) end
                if config.resolve ~= false then
                    PhysicsUtils.resolveCollision(entity, target, config.resolve_config)
                end
                if stop_on_first then break end
            end
        end
    end

    return hit_any
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║                      COLLISION RESPONSE                            ║
-- ╚═══════════════════════════════════════════════════════════════════╝

-- Internal: get outward normal from circle center to point
local function circleNormal(center_x, center_y, point_x, point_y)
    local dx = point_x - center_x
    local dy = point_y - center_y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then return dx / len, dy / len end
    return 0, -1
end

-- Internal: reflect velocity off surface normal (preserves speed)
local function reflectOffNormal(entity, nx, ny)
    local speed_before = math.sqrt(entity.vx * entity.vx + entity.vy * entity.vy)
    local dot = entity.vx * nx + entity.vy * ny
    entity.vx = entity.vx - 2 * dot * nx
    entity.vy = entity.vy - 2 * dot * ny
    local speed_after = math.sqrt(entity.vx * entity.vx + entity.vy * entity.vy)
    if speed_after > 0 then
        local scale = speed_before / speed_after
        entity.vx = entity.vx * scale
        entity.vy = entity.vy * scale
    end
end

-- Unified collision response: bounce off rects, circles, paddles
function PhysicsUtils.resolveCollision(moving, solid, config)
    config = config or {}
    local restitution = config.restitution or 1.0
    local shape = solid.type or solid.shape or ((solid.width and solid.height) and "rect") or (solid.radius and "circle") or "rect"
    local result = {edge = nil, nx = 0, ny = 0}

    if shape == "circle" then
        local cx = solid.cx or solid.x + (solid.width or solid.radius * 2 or 0) / 2
        local cy = solid.cy or solid.y + (solid.height or solid.radius * 2 or 0) / 2
        local cr = solid.radius or (solid.width or solid.size or 0) / 2

        local nx, ny = circleNormal(cx, cy, moving.x, moving.y)
        reflectOffNormal(moving, nx, ny)
        moving.vx = moving.vx * restitution
        moving.vy = moving.vy * restitution

        local separation = cr + moving.radius + 1
        moving.x = cx + nx * separation
        moving.y = cy + ny * separation
        result.edge = "circle"
        result.nx, result.ny = nx, ny
    else
        local rx = solid.x or 0
        local ry = solid.y or 0
        local rw = solid.width or solid.size or 0
        local rh = solid.height or solid.size or 0

        if solid.centered or config.centered then
            rx = rx - rw / 2
            ry = ry - rh / 2
        end

        local pen_left = (moving.x + moving.radius) - rx
        local pen_right = (rx + rw) - (moving.x - moving.radius)
        local pen_top = (moving.y + moving.radius) - ry
        local pen_bottom = (ry + rh) - (moving.y - moving.radius)
        local min_pen = math.min(pen_left, pen_right, pen_top, pen_bottom)

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
            else
                moving.vy = -math.abs(moving.vy) * restitution
                moving.vx = moving.vx * restitution + normalized * 100
            end
            moving.y = ry - moving.radius - 1
            result.edge = "top"
            result.ny = -1
        else
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

    if config.on_collide then config.on_collide(moving, solid, result.edge) end
    return result
end

-- Unified bounds handling: bounce, wrap, clamp, or callback per edge
function PhysicsUtils.handleBounds(entity, bounds, config)
    config = config or {}
    local mode = config.mode or "bounce"
    local restitution = config.restitution or 1.0
    local per_edge = config.per_edge or {}

    local left = bounds.left or bounds.x or 0
    local top = bounds.top or bounds.y or 0
    local right = bounds.right or (left + (bounds.width or 800))
    local bottom = bounds.bottom or (top + (bounds.height or 600))

    local radius = entity.radius or 0
    local half_w = radius > 0 and radius or (entity.width or 0) / 2
    local half_h = radius > 0 and radius or (entity.height or 0) / 2

    local result = {hit = false, edges = {left = false, right = false, top = false, bottom = false}}

    local function handleEdge(edge, pos_field, vel_field, boundary, inside_dir)
        local edge_mode = per_edge[edge] or mode
        if edge_mode == "none" then
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
                entity[pos_field] = (edge == "left" or edge == "right") and (right - half_w) or (bottom - half_h)
            else
                entity[pos_field] = (edge == "left" or edge == "right") and (left + half_w) or (top + half_h)
            end
        elseif edge_mode == "clamp" then
            entity[pos_field] = boundary + inside_dir * half_w
            entity[vel_field] = 0
        end

        if config.on_exit then config.on_exit(entity, edge) end
    end

    if entity.x - half_w < left then
        handleEdge("left", "x", "vx", left, 1)
    elseif entity.x + half_w > right then
        handleEdge("right", "x", "vx", right, -1)
    end

    if entity.y - half_h < top then
        handleEdge("top", "y", "vy", top, 1)
    elseif entity.y + half_h > bottom then
        handleEdge("bottom", "y", "vy", bottom, -1)
    end

    return result
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║                      PADDLE COLLISION                              ║
-- ╚═══════════════════════════════════════════════════════════════════╝

-- Handle paddle collision with sticky/bounce/randomness
-- config: {sticky, aim_mode, bounce_randomness, max_speed, rng, on_hit}
-- Returns true if collision occurred
function PhysicsUtils.handlePaddleCollision(entity, paddle, config)
    config = config or {}
    local half_w = paddle.width / 2
    local half_h = paddle.height / 2

    if not PhysicsUtils.circleVsCenteredRect(entity.x, entity.y, entity.radius, paddle.x, paddle.y, half_w, half_h) then
        return false
    end

    if config.sticky and not entity.stuck then
        PhysicsUtils.attachToEntity(entity, paddle, -entity.radius - half_h)
    else
        PhysicsUtils.resolveCollision(entity, paddle, {
            centered = true,
            position_angle = config.aim_mode or "spin",
            surface_width = paddle.width
        })
        if config.bounce_randomness and config.rng then
            PhysicsUtils.addBounceRandomness(entity, config.bounce_randomness, config.rng)
        end
        if config.max_speed then
            PhysicsUtils.clampSpeed(entity, config.max_speed)
        end
    end

    if config.on_hit then config.on_hit(entity, paddle) end
    return true
end

-- Release all stuck entities from anchor, launching them
-- config: {launch_speed, immunity_timer, base_angle, angle_range}
function PhysicsUtils.releaseStuckEntities(entities, anchor, config)
    config = config or {}
    local launch_speed = config.launch_speed or 300
    local immunity_timer = config.immunity_timer or 0.3

    for _, entity in ipairs(entities) do
        if entity.stuck then
            entity.stuck = false
            entity.y = anchor.y - entity.radius - (anchor.height or 0) / 2 - 1
            PhysicsUtils.launchFromOffset(entity, entity.stuck_offset_x or 0, anchor.width, launch_speed, config.base_angle, config.angle_range)
            entity.magnet_immunity_timer = immunity_timer
        end
    end
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║                          LAUNCHING                                 ║
-- ╚═══════════════════════════════════════════════════════════════════╝

function PhysicsUtils.launchAtAngle(entity, angle_radians, speed)
    entity.vx = math.cos(angle_radians) * speed
    entity.vy = math.sin(angle_radians) * speed
end

function PhysicsUtils.launchFromOffset(entity, offset_x, anchor_width, speed, base_angle, angle_range)
    base_angle = base_angle or -math.pi / 2
    angle_range = angle_range or math.pi / 6
    local max_offset = anchor_width / 2
    local normalized = math.max(-1, math.min(1, offset_x / max_offset))
    local angle = base_angle + normalized * angle_range
    entity.vx = math.cos(angle) * speed
    entity.vy = math.sin(angle) * speed
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║                          UTILITIES                                 ║
-- ╚═══════════════════════════════════════════════════════════════════╝

function PhysicsUtils.updateTrail(entity, max_length)
    if not entity.trail or not max_length or max_length <= 0 then return end
    table.insert(entity.trail, 1, {x = entity.x, y = entity.y})
    while #entity.trail > max_length do
        table.remove(entity.trail)
    end
end

function PhysicsUtils.wrapPosition(x, y, entity_width, entity_height, bounds_width, bounds_height)
    local new_x = x
    local new_y = y
    local half_w = entity_width / 2
    local half_h = entity_height / 2

    if x + half_w < 0 then
        new_x = bounds_width + half_w
    elseif x - half_w > bounds_width then
        new_x = -half_w
    end

    if y + half_h < 0 then
        new_y = bounds_height + half_h
    elseif y - half_h > bounds_height then
        new_y = -half_h
    end

    return new_x, new_y
end

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

return PhysicsUtils
