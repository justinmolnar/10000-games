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
        entity.vx = entity.vx + (dx / dist) * strength * dt
        entity.vy = entity.vy + (dy / dist) * strength * dt
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
-- For entities with vx/vy: modifies velocity (bullets curve smoothly)
-- For entities without vx/vy: modifies position directly (player gets pulled)
function PhysicsUtils.applyGravityWell(entity, well, dt, strength_multiplier)
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
        if params.gravity_direction == nil then
            error("applyForces: gravity_direction required when gravity is set")
        end
        PhysicsUtils.applyGravity(entity, params.gravity, params.gravity_direction, dt)
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
        if not entity.stuck then
            if not params.magnet_strength then error("applyForces: magnet_strength required when magnet_range is set") end
            PhysicsUtils.applyMagnetForce(entity, magnetTarget.x, magnetTarget.y, params.magnet_range, params.magnet_strength, dt)
        end
    end
    -- Gravity wells: array of {x, y, radius, strength}
    if params.gravity_wells then
        if params.gravity_well_strength_multiplier == nil then error("applyForces: gravity_well_strength_multiplier required when gravity_wells is set") end
        for _, well in ipairs(params.gravity_wells) do
            PhysicsUtils.applyGravityWell(entity, well, dt, params.gravity_well_strength_multiplier)
        end
    end
end

-- Handle kill plane on any edge with optional shield
-- edge_info: {pos_field, vel_field, inside_dir, check_fn} - from caller
-- Returns true if entity was killed, false otherwise
function PhysicsUtils.handleKillPlane(entity, edge_info, boundary, config)
    local radius = entity.radius or 0
    if not edge_info.check_fn(entity, boundary, radius) then return false end

    if config.kill_enabled == false then
        if not config.restitution then error("handleKillPlane: restitution required when kill_enabled is false") end
        entity[edge_info.pos_field] = boundary + edge_info.inside_dir * radius
        entity[edge_info.vel_field] = edge_info.inside_dir * math.abs(entity[edge_info.vel_field]) * config.restitution
        if config.bounce_randomness and config.rng then
            PhysicsUtils.addBounceRandomness(entity, config.bounce_randomness, config.rng)
        end
        return false
    end

    if config.shield_active then
        if config.on_shield_use then config.on_shield_use() end
        entity[edge_info.pos_field] = boundary + edge_info.inside_dir * radius
        entity[edge_info.vel_field] = edge_info.inside_dir * math.abs(entity[edge_info.vel_field])
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
    if not y_offset then error("attachToEntity: y_offset required") end
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

function PhysicsUtils.circleLineCollision(cx, cy, cr, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local len_sq = dx*dx + dy*dy
    if len_sq == 0 then
        local dist_sq = (cx - x1)*(cx - x1) + (cy - y1)*(cy - y1)
        return dist_sq <= cr*cr
    end
    local t = math.max(0, math.min(1, ((cx - x1)*dx + (cy - y1)*dy) / len_sq))
    local px = x1 + t * dx
    local py = y1 + t * dy
    local dist_sq = (cx - px)*(cx - px) + (cy - py)*(cy - py)
    return dist_sq <= cr*cr
end

-- Shape-aware collision check between two entities
-- shape1, shape2: "circle" or "rect" (required)
-- circle entities must have: x, y, radius
-- rect entities must have: x, y, width, height
function PhysicsUtils.checkCollision(e1, e2, shape1, shape2)
    if not shape1 then error("checkCollision: shape1 required") end
    if not shape2 then error("checkCollision: shape2 required") end

    if shape1 == "circle" and shape2 == "circle" then
        return PhysicsUtils.circleCollision(e1.x, e1.y, e1.radius, e2.x, e2.y, e2.radius)
    end

    if shape1 == "circle" and shape2 == "rect" then
        return PhysicsUtils.circleVsRect(e1.x, e1.y, e1.radius, e2.x, e2.y, e2.width, e2.height)
    end

    if shape1 == "rect" and shape2 == "circle" then
        return PhysicsUtils.circleVsRect(e2.x, e2.y, e2.radius, e1.x, e1.y, e1.width, e1.height)
    end

    return PhysicsUtils.rectCollision(e1.x, e1.y, e1.width, e1.height, e2.x, e2.y, e2.width, e2.height)
end

-- Batch collision check against array of targets
-- config.filter: function(target) returning whether to check target (required)
-- config.check_func: function(entity, target) returning hit boolean (required)
-- config.on_hit: function(entity, target) called when hit (optional)
-- config.stop_on_first: stop after first hit (default true)
function PhysicsUtils.checkCollisions(entity, targets, config)
    if not config.filter then error("checkCollisions: filter required") end
    if not config.check_func then error("checkCollisions: check_func required") end
    local hit_any = false
    local stop_on_first = config.stop_on_first ~= false

    for _, target in ipairs(targets) do
        if config.filter(target) then
            if config.check_func(entity, target) then
                hit_any = true
                if config.on_hit then config.on_hit(entity, target) end
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
    return 1, 0  -- default to right if exactly on center (arbitrary but consistent)
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

-- Unified collision response: bounce off rects or circles
-- config.shape: "rect" or "circle" (required)
-- config.restitution: velocity multiplier after bounce (required)
function PhysicsUtils.resolveCollision(moving, solid, config)
    if not config.shape then error("resolveCollision: shape required") end
    if not config.restitution then error("resolveCollision: restitution required") end
    local result = {edge = nil, nx = 0, ny = 0}

    if config.shape == "circle" then
        local nx, ny = circleNormal(solid.x, solid.y, moving.x, moving.y)
        reflectOffNormal(moving, nx, ny)
        moving.vx = moving.vx * config.restitution
        moving.vy = moving.vy * config.restitution

        local separation = solid.radius + moving.radius + 1
        moving.x = solid.x + nx * separation
        moving.y = solid.y + ny * separation
        result.edge = "circle"
        result.nx, result.ny = nx, ny
    else
        local rx, ry = solid.x, solid.y
        local rw, rh = solid.width, solid.height

        if config.centered then
            rx = rx - rw / 2
            ry = ry - rh / 2
        end

        local pen_left = (moving.x + moving.radius) - rx
        local pen_right = (rx + rw) - (moving.x - moving.radius)
        local pen_top = (moving.y + moving.radius) - ry
        local pen_bottom = (ry + rh) - (moving.y - moving.radius)
        local min_pen = math.min(pen_left, pen_right, pen_top, pen_bottom)

        if config.bounce_direction then
            local surface_center = rx + rw / 2
            local surface_width = config.surface_width
            local offset = moving.x - surface_center
            local normalized = math.max(-1, math.min(1, offset / (surface_width / 2)))

            local bounce_dir = config.bounce_direction
            if config.use_angle_mode then
                local speed = math.sqrt(moving.vx * moving.vx + moving.vy * moving.vy) * config.restitution
                if not config.base_angle then error("resolveCollision: base_angle required for use_angle_mode") end
                if not config.angle_range then error("resolveCollision: angle_range required for use_angle_mode") end
                local angle = config.base_angle + normalized * config.angle_range
                moving.vx = math.cos(angle) * speed
                moving.vy = math.sin(angle) * speed
            else
                if not config.spin_influence then error("resolveCollision: spin_influence required when use_angle_mode is false") end
                moving.vy = bounce_dir * math.abs(moving.vy) * config.restitution
                moving.vx = moving.vx * config.restitution + normalized * config.spin_influence
            end
            if not config.separation then error("resolveCollision: separation required when bounce_direction is set") end
            local separation = config.separation
            if bounce_dir < 0 then
                moving.y = ry - moving.radius - separation
                result.edge = "top"
                result.ny = -1
            else
                moving.y = ry + rh + moving.radius + separation
                result.edge = "bottom"
                result.ny = 1
            end
        else
            if min_pen == pen_top then
                moving.y = ry - moving.radius - 1
                moving.vy = -math.abs(moving.vy) * config.restitution
                moving.vx = moving.vx * config.restitution
                result.edge = "top"
                result.ny = -1
            elseif min_pen == pen_bottom then
                moving.y = ry + rh + moving.radius + 1
                moving.vy = math.abs(moving.vy) * config.restitution
                moving.vx = moving.vx * config.restitution
                result.edge = "bottom"
                result.ny = 1
            elseif min_pen == pen_left then
                moving.x = rx - moving.radius - 1
                moving.vx = -math.abs(moving.vx) * config.restitution
                moving.vy = moving.vy * config.restitution
                result.edge = "left"
                result.nx = -1
            else
                moving.x = rx + rw + moving.radius + 1
                moving.vx = math.abs(moving.vx) * config.restitution
                moving.vy = moving.vy * config.restitution
                result.edge = "right"
                result.nx = 1
            end
        end
    end

    if config.on_collide then config.on_collide(moving, solid, result.edge) end
    return result
end

-- Generic bounds handling - calls on_edge callback when entity crosses boundary
-- bounds: {width, height} (required) - uses 0,0 as origin
-- entity_half_size: {w, h} (required) - half width/height of entity for collision
-- on_edge(entity, edge_info) where edge_info = {edge, pos_field, vel_field, boundary, inside_dir, half_size, bounds}
-- Returns {hit = bool, edges = {left, right, top, bottom}}
function PhysicsUtils.handleBounds(entity, bounds, entity_half_size, on_edge)
    if not bounds.width then error("handleBounds: bounds.width required") end
    if not bounds.height then error("handleBounds: bounds.height required") end
    if not entity_half_size then error("handleBounds: entity_half_size required") end

    local left, top = 0, 0
    local right, bottom = bounds.width, bounds.height
    local half_w, half_h = entity_half_size.w, entity_half_size.h

    local result = {hit = false, edges = {left = false, right = false, top = false, bottom = false}}
    local bounds_info = {left = left, right = right, top = top, bottom = bottom}

    if entity.x - half_w < left then
        result.hit, result.edges.left = true, true
        on_edge(entity, {edge = "left", pos_field = "x", vel_field = "vx", boundary = left, inside_dir = 1, half_size = half_w, bounds = bounds_info})
    elseif entity.x + half_w > right then
        result.hit, result.edges.right = true, true
        on_edge(entity, {edge = "right", pos_field = "x", vel_field = "vx", boundary = right, inside_dir = -1, half_size = half_w, bounds = bounds_info})
    end

    if entity.y - half_h < top then
        result.hit, result.edges.top = true, true
        on_edge(entity, {edge = "top", pos_field = "y", vel_field = "vy", boundary = top, inside_dir = 1, half_size = half_h, bounds = bounds_info})
    elseif entity.y + half_h > bottom then
        result.hit, result.edges.bottom = true, true
        on_edge(entity, {edge = "bottom", pos_field = "y", vel_field = "vy", boundary = bottom, inside_dir = -1, half_size = half_h, bounds = bounds_info})
    end

    return result
end

-- Edge handler: bounce off boundary
function PhysicsUtils.bounceEdge(entity, info, restitution)
    entity[info.pos_field] = info.boundary + info.inside_dir * info.half_size
    entity[info.vel_field] = info.inside_dir * math.abs(entity[info.vel_field]) * (restitution or 1)
end

-- Edge handler: wrap to opposite side
function PhysicsUtils.wrapEdge(entity, info)
    local b = info.bounds
    if info.inside_dir > 0 then
        entity[info.pos_field] = (info.edge == "left" or info.edge == "right") and (b.right - info.half_size) or (b.bottom - info.half_size)
    else
        entity[info.pos_field] = (info.edge == "left" or info.edge == "right") and (b.left + info.half_size) or (b.top + info.half_size)
    end
end

-- Edge handler: clamp to boundary and stop
function PhysicsUtils.clampEdge(entity, info)
    entity[info.pos_field] = info.boundary + info.inside_dir * info.half_size
    entity[info.vel_field] = 0
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║                   CENTERED RECT COLLISION                          ║
-- ╚═══════════════════════════════════════════════════════════════════╝

-- Handle collision with centered rect (paddle, platform, etc.) with sticky/bounce/randomness
-- config: {sticky, sticky_dir, use_angle_mode, base_angle, angle_range, bounce_direction, spin_influence, bounce_randomness, max_speed, rng, on_hit}
-- sticky_dir: -1 = above rect, 1 = below rect (required when sticky=true)
-- Returns true if collision occurred
function PhysicsUtils.handleCenteredRectCollision(entity, rect, config)
    local half_w = rect.width / 2
    local half_h = rect.height / 2

    if not PhysicsUtils.circleVsCenteredRect(entity.x, entity.y, entity.radius, rect.x, rect.y, half_w, half_h) then
        return false
    end

    if config.sticky and not entity.stuck then
        if not config.sticky_dir then error("handleCenteredRectCollision: sticky_dir required when sticky is true") end
        local sticky_offset = config.sticky_dir * (entity.radius + half_h)
        PhysicsUtils.attachToEntity(entity, rect, sticky_offset)
    else
        if not config.restitution then error("handleCenteredRectCollision: restitution required") end
        if not config.separation then error("handleCenteredRectCollision: separation required") end
        PhysicsUtils.resolveCollision(entity, rect, {
            shape = "rect",
            centered = true,
            restitution = config.restitution,
            use_angle_mode = config.use_angle_mode,
            base_angle = config.base_angle,
            angle_range = config.angle_range,
            bounce_direction = config.bounce_direction,
            spin_influence = config.spin_influence,
            surface_width = rect.width,
            separation = config.separation
        })
        if config.bounce_randomness and config.rng then
            PhysicsUtils.addBounceRandomness(entity, config.bounce_randomness, config.rng)
        end
        if config.max_speed then
            PhysicsUtils.clampSpeed(entity, config.max_speed)
        end
    end

    if config.on_hit then config.on_hit(entity, rect) end
    return true
end

-- Release all stuck entities from anchor, launching them
-- config: {launch_speed, magnet_immunity_timer, base_angle, angle_range, release_dir_y}
function PhysicsUtils.releaseStuckEntities(entities, anchor, config)
    if not config.base_angle then error("releaseStuckEntities: base_angle required") end
    if not config.release_dir_y then error("releaseStuckEntities: release_dir_y required") end
    if not config.launch_speed then error("releaseStuckEntities: launch_speed required") end
    if not config.angle_range then error("releaseStuckEntities: angle_range required") end

    for _, entity in ipairs(entities) do
        if entity.stuck then
            entity.stuck = false
            local separation = entity.radius + (anchor.height or 0) / 2 + 1
            entity.x = anchor.x + (entity.stuck_offset_x or 0)
            entity.y = anchor.y + config.release_dir_y * separation
            PhysicsUtils.launchFromOffset(entity, entity.stuck_offset_x or 0, anchor.width, config.launch_speed, config.base_angle, config.angle_range)
            if config.magnet_immunity_timer then
                entity.magnet_immunity_timer = config.magnet_immunity_timer
            end
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
    if not base_angle then error("launchFromOffset: base_angle required") end
    if not angle_range then error("launchFromOffset: angle_range required") end
    local max_offset = anchor_width / 2
    local normalized = max_offset > 0 and math.max(-1, math.min(1, offset_x / max_offset)) or 0
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
    if config.max_length == nil then error("createTrailSystem: max_length required (use 0 for unlimited)") end
    if config.track_distance == nil then error("createTrailSystem: track_distance required") end
    if config.color == nil then error("createTrailSystem: color required") end
    if config.line_width == nil then error("createTrailSystem: line_width required") end
    if config.angle_offset == nil then error("createTrailSystem: angle_offset required") end
    local trail = {
        max_length = config.max_length,
        track_distance = config.track_distance,
        color = config.color,
        line_width = config.line_width,
        angle_offset = config.angle_offset,
        buffer = {},
        distance = 0
    }

    function trail:addPoint(x, y, dist)
        table.insert(self.buffer, {x = x, y = y})
        if self.track_distance and dist then
            self.distance = self.distance + dist
        end
        if self.max_length > 0 then
            while #self.buffer > self.max_length do
                table.remove(self.buffer, 1)
            end
        end
    end

    function trail:updateFromEntity(entity, angle_offset)
        if not self.max_length or self.max_length <= 0 then return end
        local offset = angle_offset or self.angle_offset
        local angle = (entity.angle or 0) + offset
        local radius = entity.radius or 0
        local x = entity.x + math.cos(angle) * radius
        local y = entity.y + math.sin(angle) * radius
        self:addPoint(x, y)
    end

    function trail:trimToDistance(target)
        while self.distance > target and #self.buffer > 1 do
            local removed = table.remove(self.buffer, 1)
            if #self.buffer > 0 then
                local next_pt = self.buffer[1]
                local dx, dy = next_pt.x - removed.x, next_pt.y - removed.y
                self.distance = self.distance - math.sqrt(dx*dx + dy*dy)
            end
        end
    end

    function trail:clear()
        self.buffer = {}
        self.distance = 0
    end

    function trail:draw()
        if #self.buffer < 2 then return end
        love.graphics.push()
        love.graphics.setLineWidth(self.line_width)
        for i = 1, #self.buffer - 1 do
            local p1, p2 = self.buffer[i], self.buffer[i + 1]
            local alpha = (i / #self.buffer) * self.color[4]
            love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end
        love.graphics.setLineWidth(1)
        love.graphics.pop()
    end

    function trail:getPointCount() return #self.buffer end
    function trail:getDistance() return self.distance end
    function trail:getPoints() return self.buffer end

    function trail:checkSelfCollision(head_x, head_y, girth, config)
        if not config.skip_multiplier then error("checkSelfCollision: skip_multiplier required") end
        if not config.collision_base then error("checkSelfCollision: collision_base required") end
        if not config.collision_multiplier then error("checkSelfCollision: collision_multiplier required") end
        local skip_dist = config.skip_multiplier * girth
        local coll_dist = config.collision_base + (girth * config.collision_multiplier)
        local checked = 0
        for i = #self.buffer, 1, -1 do
            if i < #self.buffer then
                local curr, next_pt = self.buffer[i], self.buffer[i + 1]
                checked = checked + math.sqrt((next_pt.x - curr.x)^2 + (next_pt.y - curr.y)^2)
            end
            if checked > skip_dist then
                local dx, dy = head_x - self.buffer[i].x, head_y - self.buffer[i].y
                if dx*dx + dy*dy < coll_dist*coll_dist then
                    return true
                end
            end
        end
        return false
    end

    return trail
end

-- Update a directional force that can change over time
-- state = {angle, strength, timer, is_rotating, is_turbulent, change_interval, change_amount, turbulence_range}
-- Returns fx, fy force components
function PhysicsUtils.updateDirectionalForce(state, dt)
    if state.angle == nil then error("updateDirectionalForce: state.angle required") end
    if state.strength == nil then error("updateDirectionalForce: state.strength required") end
    if state.timer == nil then error("updateDirectionalForce: state.timer required") end

    if state.is_rotating then
        if state.change_interval == nil then error("updateDirectionalForce: state.change_interval required for rotating") end
        if state.change_amount == nil then error("updateDirectionalForce: state.change_amount required for rotating") end
        state.timer = state.timer + dt
        if state.timer >= state.change_interval then
            state.timer = state.timer - state.change_interval
            state.angle = state.angle + state.change_amount
        end
    end

    local angle = state.angle
    if state.is_turbulent then
        if state.turbulence_range == nil then error("updateDirectionalForce: state.turbulence_range required for turbulent") end
        angle = angle + (math.random() - 0.5) * state.turbulence_range
    end

    return math.cos(angle) * state.strength, math.sin(angle) * state.strength
end

return PhysicsUtils
