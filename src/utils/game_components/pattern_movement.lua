-- PatternMovement: Math primitives for autonomous entity movement
-- Games compose these to create movement behaviors.
--
-- Usage:
--   local PM = require('src.utils.game_components.pattern_movement')
--
--   -- In game update:
--   PM.applyVelocity(entity, dt)
--   PM.applySineOffset(entity, "x", dt, frequency, amplitude)
--   PM.applyBounce(entity, bounds)

local PatternMovement = {}

-- ============================================================================
-- VELOCITY PRIMITIVES
-- ============================================================================

-- Apply velocity to position
function PatternMovement.applyVelocity(entity, dt)
    entity.x = entity.x + (entity.vx or 0) * dt
    entity.y = entity.y + (entity.vy or 0) * dt
end

-- Set velocity from angle and speed
function PatternMovement.setVelocityFromAngle(entity, angle, speed)
    entity.vx = math.cos(angle) * speed
    entity.vy = math.sin(angle) * speed
end

-- Set velocity toward a target point
function PatternMovement.setVelocityToward(entity, target_x, target_y, speed)
    local dx = target_x - entity.x
    local dy = target_y - entity.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 0 then
        entity.vx = (dx / dist) * speed
        entity.vy = (dy / dist) * speed
    end
end

-- Apply directional movement (using dir_x/dir_y, angle, or direction)
function PatternMovement.applyDirection(entity, dt)
    local speed = entity.speed or 100
    if entity.dir_x and entity.dir_y then
        entity.x = entity.x + entity.dir_x * speed * dt
        entity.y = entity.y + entity.dir_y * speed * dt
    else
        local angle = entity.angle or entity.direction
        if angle then
            entity.x = entity.x + math.cos(angle) * speed * dt
            entity.y = entity.y + math.sin(angle) * speed * dt
        else
            entity.y = entity.y + speed * dt  -- default: down
        end
    end
end

-- ============================================================================
-- STEERING PRIMITIVES
-- ============================================================================

-- Steer toward target (smooth turning)
-- Returns new angle, also updates entity.angle if present
function PatternMovement.steerToward(entity, target_x, target_y, turn_rate, dt)
    local desired = math.atan2(target_y - entity.y, target_x - entity.x)
    local current = entity.angle or 0
    local diff = (desired - current + math.pi) % (2 * math.pi) - math.pi

    local max_turn = turn_rate * dt
    if diff > max_turn then diff = max_turn
    elseif diff < -max_turn then diff = -max_turn end

    local new_angle = current + diff
    entity.angle = new_angle
    return new_angle
end

-- Move toward target point, returns true if arrived
function PatternMovement.moveToward(entity, target_x, target_y, speed, dt, threshold)
    threshold = threshold or 5
    local dx = target_x - entity.x
    local dy = target_y - entity.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist <= threshold then
        return true  -- arrived
    end

    local move = speed * dt
    if move >= dist then
        entity.x = target_x
        entity.y = target_y
        return true
    end

    entity.x = entity.x + (dx / dist) * move
    entity.y = entity.y + (dy / dist) * move
    return false
end

-- ============================================================================
-- OSCILLATION PRIMITIVES
-- ============================================================================

-- Apply sine wave offset to position
-- axis: "x" or "y", freq: oscillations per second, amp: max offset in pixels
function PatternMovement.applySineOffset(entity, axis, dt, frequency, amplitude)
    entity.pattern_time = (entity.pattern_time or 0) + dt
    local offset = math.sin(entity.pattern_time * frequency * math.pi * 2) * amplitude * dt * frequency
    if axis == "x" then
        entity.x = entity.x + offset
    else
        entity.y = entity.y + offset
    end
end

-- Apply sine wave to position (absolute, not delta)
-- Requires entity.start_x or entity.start_y as baseline
function PatternMovement.setSinePosition(entity, axis, frequency, amplitude)
    entity.pattern_time = entity.pattern_time or 0
    local offset = math.sin(entity.pattern_time * frequency * math.pi * 2) * amplitude
    if axis == "x" and entity.start_x then
        entity.x = entity.start_x + offset
    elseif axis == "y" and entity.start_y then
        entity.y = entity.start_y + offset
    end
end

-- ============================================================================
-- ORBIT / CIRCULAR PRIMITIVES
-- ============================================================================

-- Set position on circle around center point
function PatternMovement.setPositionOnCircle(entity, center_x, center_y, radius, angle)
    entity.x = center_x + math.cos(angle) * radius
    entity.y = center_y + math.sin(angle) * radius
end

-- Update orbit angle and set position
function PatternMovement.updateOrbit(entity, center_x, center_y, radius, angular_speed, dt)
    entity.orbit_angle = (entity.orbit_angle or 0) + angular_speed * dt
    PatternMovement.setPositionOnCircle(entity, center_x, center_y, radius, entity.orbit_angle)
end

-- ============================================================================
-- BEZIER PRIMITIVES
-- ============================================================================

-- Quadratic bezier interpolation: returns x, y at parameter t (0-1)
-- p0, p1, p2 are control points: {x, y}
function PatternMovement.bezierQuadratic(t, p0, p1, p2)
    local mt = 1 - t
    local x = mt * mt * p0.x + 2 * mt * t * p1.x + t * t * p2.x
    local y = mt * mt * p0.y + 2 * mt * t * p1.y + t * t * p2.y
    return x, y
end

-- Update entity position along bezier curve
-- Returns true when complete (t >= 1)
function PatternMovement.updateBezier(entity, dt)
    if not entity.bezier_path or #entity.bezier_path < 3 then
        return true
    end

    local duration = entity.bezier_duration or 2
    entity.bezier_t = (entity.bezier_t or 0) + dt / duration

    if entity.bezier_t >= 1 then
        entity.bezier_t = 1
        entity.bezier_complete = true
    end

    local p0 = entity.bezier_path[1]
    local p1 = entity.bezier_path[2]
    local p2 = entity.bezier_path[3]
    entity.x, entity.y = PatternMovement.bezierQuadratic(entity.bezier_t, p0, p1, p2)

    return entity.bezier_complete
end

-- Build a bezier path from 3 points
function PatternMovement.buildBezierPath(start_x, start_y, control_x, control_y, end_x, end_y)
    return {
        {x = start_x, y = start_y},
        {x = control_x, y = control_y},
        {x = end_x, y = end_y}
    }
end

-- ============================================================================
-- BOUNCE PRIMITIVES
-- ============================================================================

-- Bounce off rectangular bounds, returns true if bounced
function PatternMovement.applyBounce(entity, bounds, damping)
    damping = damping or 1.0
    local bounced = false

    local w = entity.width or (entity.radius and entity.radius * 2) or 0
    local h = entity.height or (entity.radius and entity.radius * 2) or 0

    if entity.x < bounds.x then
        entity.x = bounds.x
        entity.vx = -(entity.vx or 0) * damping
        bounced = true
    elseif entity.x + w > bounds.x + bounds.width then
        entity.x = bounds.x + bounds.width - w
        entity.vx = -(entity.vx or 0) * damping
        bounced = true
    end

    if entity.y < bounds.y then
        entity.y = bounds.y
        entity.vy = -(entity.vy or 0) * damping
        bounced = true
    elseif entity.y + h > bounds.y + bounds.height then
        entity.y = bounds.y + bounds.height - h
        entity.vy = -(entity.vy or 0) * damping
        bounced = true
    end

    return bounced
end

-- Clamp position to bounds
function PatternMovement.clampToBounds(entity, bounds)
    local r = entity.radius or 0
    entity.x = math.max(bounds.x + r, math.min(bounds.x + bounds.width - r, entity.x))
    entity.y = math.max(bounds.y + r, math.min(bounds.y + bounds.height - r, entity.y))
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Check if entity is off screen
function PatternMovement.isOffScreen(entity, bounds, margin)
    margin = margin or 0
    local w = entity.width or (entity.radius and entity.radius * 2) or 0
    local h = entity.height or (entity.radius and entity.radius * 2) or 0

    return entity.x + w < bounds.x - margin
        or entity.x > bounds.x + bounds.width + margin
        or entity.y + h < bounds.y - margin
        or entity.y > bounds.y + bounds.height + margin
end

-- Distance between two points
function PatternMovement.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Angle from one point to another
function PatternMovement.angleTo(x1, y1, x2, y2)
    return math.atan2(y2 - y1, x2 - x1)
end

-- Normalize angle to -pi to pi
function PatternMovement.normalizeAngle(angle)
    while angle > math.pi do angle = angle - 2 * math.pi end
    while angle < -math.pi do angle = angle + 2 * math.pi end
    return angle
end

-- Update pattern time (for oscillations)
function PatternMovement.updateTime(entity, dt)
    entity.pattern_time = (entity.pattern_time or 0) + dt
end

-- Generic update: applies movement based on entity flags
-- Entity flags: use_steering, use_direction, use_velocity, sine_amplitude, use_bounce, etc.
function PatternMovement.update(dt, entity, bounds)
    if not entity then return end

    -- Steering toward target
    if entity.use_steering and entity.target_x and entity.target_y then
        local turn_rate = entity.turn_rate or math.rad(90)
        PatternMovement.steerToward(entity, entity.target_x, entity.target_y, turn_rate, dt)
        PatternMovement.setVelocityFromAngle(entity, entity.angle, entity.speed or 100)
    end

    -- Directional movement (uses dir_x/dir_y or angle)
    if entity.use_direction then
        PatternMovement.applyDirection(entity, dt)
    end

    -- Velocity-based movement (steering also uses velocity)
    if entity.use_velocity or entity.use_steering then
        PatternMovement.applyVelocity(entity, dt)
    end

    -- Sine wave oscillation
    if entity.sine_amplitude then
        PatternMovement.updateTime(entity, dt)
        local axis = entity.sine_axis or "x"
        local freq = entity.wave_speed or entity.sine_frequency or 5
        local amp = entity.wave_amp or entity.sine_amplitude
        PatternMovement.applySineOffset(entity, axis, dt, freq, amp)
    end

    -- Orbit movement
    if entity.orbit_radius then
        PatternMovement.updateOrbit(entity,
            entity.orbit_center_x or (bounds and bounds.width/2) or 0,
            entity.orbit_center_y or (bounds and bounds.height/2) or 0,
            entity.orbit_radius, entity.orbit_speed or 1, dt)
    end

    -- Bezier path
    if entity.use_bezier and entity.bezier_path then
        PatternMovement.updateBezier(entity, dt)
    end

    -- Bouncing off walls
    if entity.use_bounce and bounds then
        PatternMovement.applyBounce(entity, bounds, entity.bounce_damping)
    end
end

-- Sprite rotation (visual only, doesn't affect movement)
function PatternMovement.updateSpriteRotation(entity, dt)
    if not entity.sprite_rotation_speed or entity.sprite_rotation_speed == 0 then return end
    entity.sprite_rotation_angle = (entity.sprite_rotation_angle or 0) + (entity.sprite_rotation_speed * dt)
    entity.sprite_rotation_angle = entity.sprite_rotation_angle % 360
end

return PatternMovement
