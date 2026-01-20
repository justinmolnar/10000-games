-- PatternMovement: Autonomous movement patterns for AI entities
-- Use for enemies, powerups, hazards - anything that moves without player input
--
-- Usage:
--   local PatternMovement = require('src.utils.game_components.pattern_movement')
--
--   -- Update an entity's position based on its pattern:
--   PatternMovement.update(dt, entity, bounds)
--
--   -- Entity should have:
--   --   x, y, width, height (or radius)
--   --   movement_pattern: "straight", "zigzag", "dive", "bezier", "orbit", "bounce"
--   --   speed (or vx/vy for bounce mode)
--   --   Pattern-specific fields (see below)

local PatternMovement = {}

-- Main update function - dispatches to pattern-specific updater
function PatternMovement.update(dt, entity, bounds)
    local pattern = entity.movement_pattern or "straight"

    if pattern == "straight" then
        PatternMovement.updateStraight(dt, entity, bounds)
    elseif pattern == "zigzag" then
        PatternMovement.updateZigzag(dt, entity, bounds)
    elseif pattern == "dive" then
        PatternMovement.updateDive(dt, entity, bounds)
    elseif pattern == "bezier" then
        PatternMovement.updateBezier(dt, entity, bounds)
    elseif pattern == "orbit" then
        PatternMovement.updateOrbit(dt, entity, bounds)
    elseif pattern == "bounce" then
        PatternMovement.updateBounce(dt, entity, bounds)
    elseif pattern == "wave" then
        PatternMovement.updateWave(dt, entity, bounds)
    end
end

-- Straight: Move in a constant direction
-- Entity needs: speed, direction (angle in radians, 0 = right, pi/2 = down)
-- Or: speed, dir_x, dir_y (normalized direction vector)
function PatternMovement.updateStraight(dt, entity, bounds)
    local speed = entity.speed or 100

    if entity.dir_x and entity.dir_y then
        entity.x = entity.x + entity.dir_x * speed * dt
        entity.y = entity.y + entity.dir_y * speed * dt
    elseif entity.direction then
        entity.x = entity.x + math.cos(entity.direction) * speed * dt
        entity.y = entity.y + math.sin(entity.direction) * speed * dt
    else
        -- Default: move down
        entity.y = entity.y + speed * dt
    end
end

-- Zigzag: Move in primary direction while oscillating perpendicular
-- Entity needs: speed, zigzag_frequency (oscillations/sec), zigzag_amplitude (pixels)
-- Optional: direction (angle), time (elapsed time for phase)
function PatternMovement.updateZigzag(dt, entity, bounds)
    local speed = entity.speed or 100
    local freq = entity.zigzag_frequency or 2
    local amp = entity.zigzag_amplitude or 50

    -- Track time for sine wave
    entity.pattern_time = (entity.pattern_time or 0) + dt

    -- Primary movement (default: down)
    local dir = entity.direction or (math.pi / 2)
    entity.x = entity.x + math.cos(dir) * speed * dt
    entity.y = entity.y + math.sin(dir) * speed * dt

    -- Perpendicular oscillation
    local perp = dir + math.pi / 2
    local offset = math.sin(entity.pattern_time * freq * math.pi * 2) * amp * dt * freq
    entity.x = entity.x + math.cos(perp) * offset
    entity.y = entity.y + math.sin(perp) * offset
end

-- Wave: Smooth sine wave path (different from zigzag - affects position directly)
-- Entity needs: speed, wave_frequency, wave_amplitude
function PatternMovement.updateWave(dt, entity, bounds)
    local speed = entity.speed or 100
    local freq = entity.wave_frequency or 1
    local amp = entity.wave_amplitude or 30

    entity.pattern_time = (entity.pattern_time or 0) + dt

    -- Move in primary direction
    local dir = entity.direction or (math.pi / 2)
    entity.x = entity.x + math.cos(dir) * speed * dt
    entity.y = entity.y + math.sin(dir) * speed * dt

    -- Apply wave offset to x position based on y progress
    if entity.start_x then
        local wave_offset = math.sin(entity.pattern_time * freq * math.pi * 2) * amp
        entity.x = entity.start_x + wave_offset
    else
        entity.start_x = entity.x
    end
end

-- Dive: Move toward a target point
-- Entity needs: speed, target_x, target_y
-- Optional: arrive_threshold (distance to consider "arrived")
function PatternMovement.updateDive(dt, entity, bounds)
    local speed = entity.speed or 100
    local threshold = entity.arrive_threshold or 5

    if not entity.target_x or not entity.target_y then
        -- No target, just move down
        entity.y = entity.y + speed * dt
        return
    end

    local dx = entity.target_x - entity.x
    local dy = entity.target_y - entity.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist <= threshold then
        -- Arrived at target
        entity.dive_complete = true
        -- Continue in same direction
        if entity.last_dir_x and entity.last_dir_y then
            entity.x = entity.x + entity.last_dir_x * speed * dt
            entity.y = entity.y + entity.last_dir_y * speed * dt
        end
    else
        -- Move toward target
        local dir_x = dx / dist
        local dir_y = dy / dist
        entity.x = entity.x + dir_x * speed * dt
        entity.y = entity.y + dir_y * speed * dt
        entity.last_dir_x = dir_x
        entity.last_dir_y = dir_y
    end
end

-- Bezier: Follow a quadratic bezier curve
-- Entity needs: bezier_path = {{x,y}, {x,y}, {x,y}}, bezier_duration, bezier_t (0-1 progress)
function PatternMovement.updateBezier(dt, entity, bounds)
    if not entity.bezier_path or #entity.bezier_path < 3 then
        return
    end

    local duration = entity.bezier_duration or 2
    entity.bezier_t = (entity.bezier_t or 0) + dt / duration

    if entity.bezier_t >= 1 then
        entity.bezier_t = 1
        entity.bezier_complete = true
    end

    -- Quadratic bezier: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
    local t = entity.bezier_t
    local p0 = entity.bezier_path[1]
    local p1 = entity.bezier_path[2]
    local p2 = entity.bezier_path[3]

    local mt = 1 - t
    entity.x = mt * mt * p0.x + 2 * mt * t * p1.x + t * t * p2.x
    entity.y = mt * mt * p0.y + 2 * mt * t * p1.y + t * t * p2.y
end

-- Orbit: Circle around a center point
-- Entity needs: orbit_center_x, orbit_center_y, orbit_radius, orbit_speed (radians/sec)
-- Optional: orbit_angle (current angle)
function PatternMovement.updateOrbit(dt, entity, bounds)
    local cx = entity.orbit_center_x or (bounds and bounds.width / 2) or 400
    local cy = entity.orbit_center_y or (bounds and bounds.height / 2) or 300
    local radius = entity.orbit_radius or 100
    local speed = entity.orbit_speed or 1

    entity.orbit_angle = (entity.orbit_angle or 0) + speed * dt

    entity.x = cx + math.cos(entity.orbit_angle) * radius
    entity.y = cy + math.sin(entity.orbit_angle) * radius
end

-- Bounce: Move with velocity, bounce off bounds
-- Entity needs: vx, vy (velocity)
-- Optional: bounce_damping (0-1, velocity retained on bounce)
function PatternMovement.updateBounce(dt, entity, bounds)
    if not entity.vx then entity.vx = entity.speed or 100 end
    if not entity.vy then entity.vy = entity.speed or 100 end

    local damping = entity.bounce_damping or 1.0

    entity.x = entity.x + entity.vx * dt
    entity.y = entity.y + entity.vy * dt

    if bounds then
        local w = entity.width or (entity.radius and entity.radius * 2) or 0
        local h = entity.height or (entity.radius and entity.radius * 2) or 0

        -- Bounce off walls
        if entity.x < bounds.x then
            entity.x = bounds.x
            entity.vx = -entity.vx * damping
        elseif entity.x + w > bounds.x + bounds.width then
            entity.x = bounds.x + bounds.width - w
            entity.vx = -entity.vx * damping
        end

        if entity.y < bounds.y then
            entity.y = bounds.y
            entity.vy = -entity.vy * damping
        elseif entity.y + h > bounds.y + bounds.height then
            entity.y = bounds.y + bounds.height - h
            entity.vy = -entity.vy * damping
        end
    end
end

-- Utility: Check if entity is off screen
function PatternMovement.isOffScreen(entity, bounds, margin)
    margin = margin or 0
    local w = entity.width or (entity.radius and entity.radius * 2) or 0
    local h = entity.height or (entity.radius and entity.radius * 2) or 0

    return entity.x + w < bounds.x - margin
        or entity.x > bounds.x + bounds.width + margin
        or entity.y + h < bounds.y - margin
        or entity.y > bounds.y + bounds.height + margin
end

-- Utility: Initialize pattern-specific fields with defaults
function PatternMovement.initPattern(entity, pattern, config)
    config = config or {}
    entity.movement_pattern = pattern
    entity.pattern_time = 0

    if pattern == "zigzag" then
        entity.zigzag_frequency = config.frequency or 2
        entity.zigzag_amplitude = config.amplitude or 50
        entity.direction = config.direction or (math.pi / 2)
        entity.speed = config.speed or 100

    elseif pattern == "wave" then
        entity.wave_frequency = config.frequency or 1
        entity.wave_amplitude = config.amplitude or 30
        entity.direction = config.direction or (math.pi / 2)
        entity.speed = config.speed or 100
        entity.start_x = entity.x

    elseif pattern == "dive" then
        entity.target_x = config.target_x
        entity.target_y = config.target_y
        entity.speed = config.speed or 100
        entity.arrive_threshold = config.threshold or 5

    elseif pattern == "bezier" then
        entity.bezier_path = config.path
        entity.bezier_duration = config.duration or 2
        entity.bezier_t = 0

    elseif pattern == "orbit" then
        entity.orbit_center_x = config.center_x
        entity.orbit_center_y = config.center_y
        entity.orbit_radius = config.radius or 100
        entity.orbit_speed = config.speed or 1
        entity.orbit_angle = config.start_angle or 0

    elseif pattern == "bounce" then
        entity.vx = config.vx or config.speed or 100
        entity.vy = config.vy or config.speed or 100
        entity.bounce_damping = config.damping or 1.0

    elseif pattern == "straight" then
        entity.speed = config.speed or 100
        entity.direction = config.direction or (math.pi / 2)
        if config.dir_x and config.dir_y then
            entity.dir_x = config.dir_x
            entity.dir_y = config.dir_y
        end
    end

    return entity
end

return PatternMovement
