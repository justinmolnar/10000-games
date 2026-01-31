-- MovementController: Reusable movement primitives for game entities
-- Provides building blocks that games compose based on their needs.
-- All movement is deterministic for demo playback compatibility.
--
-- Games call primitives directly based on input:
--   if input.up then mc:applyThrust(entity, entity.angle, force, dt) end
--   if input.down then mc:applyFriction(entity, 0.92, dt) end
--   mc:applyVelocity(entity, dt)
--   mc:applyBounds(entity, bounds)

local Object = require('class')
local MovementController = Object:extend('MovementController')

function MovementController:new(params)
    params = params or {}

    -- Common parameters (games can override per-call)
    self.speed = params.speed or 300
    self.rotation_speed = params.rotation_speed or 5.0
    self.bounce_damping = params.bounce_damping or 0.8
    self.thrust_acceleration = params.thrust_acceleration or 600

    -- Friction defaults
    self.accel_friction = params.accel_friction or 1.0
    self.decel_friction = params.decel_friction or 1.0

    -- Jump/dash parameters
    self.jump_distance = params.jump_distance or 150
    self.jump_cooldown = params.jump_cooldown or 0.5
    self.jump_speed = params.jump_speed or 500

    -- Grid parameters
    self.cell_size = params.cell_size or 20
    self.cells_per_second = params.cells_per_second or 10
    self.allow_reverse = params.allow_reverse or false

    -- State storage (keyed by entity ID)
    self.jump_state = {}
    self.grid_state = {}
    self.smooth_state = {}

    return self
end

-- ============================================================================
-- VELOCITY PRIMITIVES
-- ============================================================================

-- Apply thrust in a direction (angle in radians, 0 = right, sprite faces up)
function MovementController:applyThrust(entity, angle, force, dt)
    force = force or self.thrust_acceleration
    local thrust_angle = angle - math.pi / 2  -- Convert from sprite-up to math angle
    entity.vx = (entity.vx or 0) + math.cos(thrust_angle) * force * dt
    entity.vy = (entity.vy or 0) + math.sin(thrust_angle) * force * dt
end

-- Apply directional movement (dx, dy should be -1, 0, or 1)
function MovementController:applyDirectionalVelocity(entity, dx, dy, speed, dt)
    speed = speed or self.speed
    -- Normalize diagonal
    if dx ~= 0 and dy ~= 0 then
        local inv_sqrt2 = 0.70710678118
        dx, dy = dx * inv_sqrt2, dy * inv_sqrt2
    end
    entity.vx = (entity.vx or 0) + dx * speed * dt
    entity.vy = (entity.vy or 0) + dy * speed * dt
end

-- Apply directional movement directly to position (no velocity)
function MovementController:applyDirectionalMove(entity, dx, dy, speed, dt)
    speed = speed or self.speed
    -- Normalize diagonal
    if dx ~= 0 and dy ~= 0 then
        local inv_sqrt2 = 0.70710678118
        dx, dy = dx * inv_sqrt2, dy * inv_sqrt2
    end
    entity.x = entity.x + dx * speed * dt
    entity.y = entity.y + dy * speed * dt
end

-- Apply friction to velocity
function MovementController:applyFriction(entity, friction, dt)
    friction = friction or self.decel_friction
    if friction < 1.0 then
        local factor = math.pow(friction, dt * 60)
        entity.vx = (entity.vx or 0) * factor
        entity.vy = (entity.vy or 0) * factor
    end
end

-- Stop all velocity
function MovementController:stopVelocity(entity)
    entity.vx = 0
    entity.vy = 0
end

-- Update position from velocity
function MovementController:applyVelocity(entity, dt)
    entity.x = entity.x + (entity.vx or 0) * dt
    entity.y = entity.y + (entity.vy or 0) * dt
end

-- ============================================================================
-- ROTATION PRIMITIVES
-- ============================================================================

-- Rotate entity by amount
function MovementController:applyRotation(entity, direction, speed, dt)
    speed = speed or self.rotation_speed
    entity.angle = ((entity.angle or 0) + direction * speed * dt) % (2 * math.pi)
end

-- Rotate towards movement direction
function MovementController:rotateTowardsMovement(entity, dx, dy, dt)
    if entity.angle == nil or (dx == 0 and dy == 0) then return end
    local target = math.atan2(dy, dx) + math.pi / 2
    local diff = self:angleDiff(target, entity.angle)
    local max_turn = self.rotation_speed * dt
    diff = math.max(-max_turn, math.min(max_turn, diff))
    entity.angle = (entity.angle + diff) % (2 * math.pi)
end

-- Rotate towards velocity direction
function MovementController:rotateTowardsVelocity(entity, dt, min_speed)
    min_speed = min_speed or 10
    local speed = math.sqrt((entity.vx or 0)^2 + (entity.vy or 0)^2)
    if speed > min_speed then
        self:rotateTowardsMovement(entity, entity.vx, entity.vy, dt)
    end
end

-- ============================================================================
-- BOUNDS PRIMITIVES
-- ============================================================================

-- Clamp or wrap entity within bounds
function MovementController:applyBounds(entity, bounds)
    if bounds.wrap_x then
        if entity.radius then
            if entity.x - entity.radius > bounds.x + bounds.width then
                entity.x = bounds.x - entity.radius
            elseif entity.x + entity.radius < bounds.x then
                entity.x = bounds.x + bounds.width + entity.radius
            end
        elseif entity.width then
            if entity.x > bounds.x + bounds.width then
                entity.x = bounds.x - entity.width
            elseif entity.x + entity.width < bounds.x then
                entity.x = bounds.x + bounds.width
            end
        end
    else
        if entity.radius then
            entity.x = math.max(bounds.x + entity.radius, math.min(bounds.x + bounds.width - entity.radius, entity.x))
        elseif entity.width then
            entity.x = math.max(bounds.x, math.min(bounds.x + bounds.width - entity.width, entity.x))
        end
    end

    if bounds.wrap_y then
        if entity.radius then
            if entity.y - entity.radius > bounds.y + bounds.height then
                entity.y = bounds.y - entity.radius
            elseif entity.y + entity.radius < bounds.y then
                entity.y = bounds.y + bounds.height + entity.radius
            end
        elseif entity.height then
            if entity.y > bounds.y + bounds.height then
                entity.y = bounds.y - entity.height
            elseif entity.y + entity.height < bounds.y then
                entity.y = bounds.y + bounds.height
            end
        end
    else
        if entity.radius then
            entity.y = math.max(bounds.y + entity.radius, math.min(bounds.y + bounds.height - entity.radius, entity.y))
        elseif entity.height then
            entity.y = math.max(bounds.y, math.min(bounds.y + bounds.height - entity.height, entity.y))
        end
    end
end

-- Bounce velocity on boundary collision
function MovementController:applyBounce(entity, bounds, damping)
    damping = damping or self.bounce_damping
    local hit = false

    if entity.radius then
        if entity.x <= bounds.x + entity.radius or entity.x >= bounds.x + bounds.width - entity.radius then
            entity.vx = -(entity.vx or 0) * damping
            hit = true
        end
        if entity.y <= bounds.y + entity.radius or entity.y >= bounds.y + bounds.height - entity.radius then
            entity.vy = -(entity.vy or 0) * damping
            hit = true
        end
    elseif entity.width and entity.height then
        if entity.x <= bounds.x or entity.x >= bounds.x + bounds.width - entity.width then
            entity.vx = -(entity.vx or 0) * damping
            hit = true
        end
        if entity.y <= bounds.y or entity.y >= bounds.y + bounds.height - entity.height then
            entity.vy = -(entity.vy or 0) * damping
            hit = true
        end
    end

    if hit then
        self:applyBounds(entity, bounds)
    end
    return hit
end

-- ============================================================================
-- JUMP/DASH SYSTEM
-- ============================================================================

-- Check if jump is available
function MovementController:canJump(entity_id, current_time)
    entity_id = entity_id or "default"
    local state = self.jump_state[entity_id]
    if not state then return true end
    return (current_time - state.last_jump_time) >= self.jump_cooldown
end

-- Start a jump in direction
function MovementController:startJump(entity, entity_id, dx, dy, current_time, bounds)
    entity_id = entity_id or "default"
    if not self.jump_state[entity_id] then
        self.jump_state[entity_id] = {
            is_jumping = false,
            last_jump_time = -(self.jump_cooldown * 2),
            jump_target_x = 0, jump_target_y = 0,
            jump_dir_x = 0, jump_dir_y = 0
        }
    end
    local state = self.jump_state[entity_id]

    state.jump_target_x = entity.x + dx * self.jump_distance
    state.jump_target_y = entity.y + dy * self.jump_distance

    -- Clamp target to bounds
    if bounds then
        if entity.radius then
            state.jump_target_x = math.max(bounds.x + entity.radius, math.min(bounds.x + bounds.width - entity.radius, state.jump_target_x))
            state.jump_target_y = math.max(bounds.y + entity.radius, math.min(bounds.y + bounds.height - entity.radius, state.jump_target_y))
        elseif entity.width and entity.height then
            state.jump_target_x = math.max(bounds.x, math.min(bounds.x + bounds.width - entity.width, state.jump_target_x))
            state.jump_target_y = math.max(bounds.y, math.min(bounds.y + bounds.height - entity.height, state.jump_target_y))
        end
    end

    state.jump_dir_x = dx
    state.jump_dir_y = dy
    state.is_jumping = true
    state.last_jump_time = current_time
end

-- Update jump movement (call every frame during jump)
-- Returns: is_still_jumping
-- current_time: optional, used for timeout detection (pass entity.time_elapsed)
function MovementController:updateJump(entity, entity_id, dt, bounds, current_time)
    entity_id = entity_id or "default"
    local state = self.jump_state[entity_id]
    if not state or not state.is_jumping then return false end

    -- Safety timeout: if jump takes way too long, cancel it (prevents softlock)
    if current_time then
        local expected_jump_time = self.jump_distance / self.jump_speed
        local actual_jump_time = current_time - state.last_jump_time
        if actual_jump_time > expected_jump_time * 2.5 then
            state.is_jumping = false
            return false
        end
    end

    local dx = state.jump_target_x - entity.x
    local dy = state.jump_target_y - entity.y
    local dist = math.sqrt(dx*dx + dy*dy)

    -- Instant teleport for very high speeds
    if self.jump_speed >= 9999 then
        entity.x = state.jump_target_x
        entity.y = state.jump_target_y
        state.is_jumping = false
        return false
    end

    if dist > 1 then
        local move_dist = self.jump_speed * dt
        if move_dist >= dist then
            entity.x = state.jump_target_x
            entity.y = state.jump_target_y
            state.is_jumping = false
        else
            local old_x, old_y = entity.x, entity.y
            entity.x = entity.x + (dx / dist) * move_dist
            entity.y = entity.y + (dy / dist) * move_dist

            if bounds then
                self:applyBounds(entity, bounds)
            end

            -- Check if stuck on wall
            if math.abs(entity.x - old_x) < 0.5 and math.abs(entity.y - old_y) < 0.5 then
                state.is_jumping = false
                return false
            end
        end
    else
        entity.x = state.jump_target_x
        entity.y = state.jump_target_y
        state.is_jumping = false
    end

    return state.is_jumping
end

-- Check if currently jumping
function MovementController:isJumping(entity_id)
    entity_id = entity_id or "default"
    local state = self.jump_state[entity_id]
    return state and state.is_jumping
end

-- Get jump direction (for applying post-jump velocity)
function MovementController:getJumpDirection(entity_id)
    entity_id = entity_id or "default"
    local state = self.jump_state[entity_id]
    if state then
        return state.jump_dir_x, state.jump_dir_y
    end
    return 0, 0
end

-- ============================================================================
-- GRID MOVEMENT SYSTEM (timing + direction without position management)
-- ============================================================================

-- Check if it's time to move to next cell
function MovementController:tickGrid(dt, entity_id)
    entity_id = entity_id or "default"
    if not self.grid_state[entity_id] then
        self.grid_state[entity_id] = {
            move_timer = 0,
            direction = {x = 0, y = 0},
            next_direction = {x = 0, y = 0}
        }
    end
    local state = self.grid_state[entity_id]

    local move_interval = 1.0 / self.cells_per_second
    state.move_timer = state.move_timer + dt

    if state.move_timer >= move_interval then
        state.move_timer = state.move_timer - move_interval
        return true
    end
    return false
end

-- Queue direction change
function MovementController:queueGridDirection(entity_id, dir_x, dir_y, current_dir)
    entity_id = entity_id or "default"
    if not self.grid_state[entity_id] then
        self.grid_state[entity_id] = {
            move_timer = 0,
            direction = {x = 0, y = 0},
            next_direction = {x = 0, y = 0}
        }
    end
    local state = self.grid_state[entity_id]

    -- Check reverse
    if not self.allow_reverse and current_dir then
        local is_reverse = (dir_x == -current_dir.x and dir_y == -current_dir.y)
                           and (current_dir.x ~= 0 or current_dir.y ~= 0)
        if is_reverse then return false end
    end

    state.next_direction.x = dir_x
    state.next_direction.y = dir_y
    return true
end

-- Apply queued direction (call when tickGrid returns true)
function MovementController:applyQueuedDirection(entity_id)
    entity_id = entity_id or "default"
    local state = self.grid_state[entity_id]
    if not state then return {x = 0, y = 0} end

    if state.next_direction.x ~= 0 or state.next_direction.y ~= 0 then
        state.direction.x = state.next_direction.x
        state.direction.y = state.next_direction.y
    end

    return {x = state.direction.x, y = state.direction.y}
end

-- Get current direction
function MovementController:getGridDirection(entity_id)
    entity_id = entity_id or "default"
    local state = self.grid_state[entity_id]
    if not state then return {x = 0, y = 0} end
    return {x = state.direction.x, y = state.direction.y}
end

-- Initialize grid state
function MovementController:initGridState(entity_id, dir_x, dir_y)
    entity_id = entity_id or "default"
    self.grid_state[entity_id] = {
        move_timer = 0,
        direction = {x = dir_x or 0, y = dir_y or 0},
        next_direction = {x = dir_x or 0, y = dir_y or 0}
    }
end

-- Reset grid state
function MovementController:resetGridState(entity_id)
    entity_id = entity_id or "default"
    self.grid_state[entity_id] = nil
end

-- Set speed dynamically
function MovementController:setSpeed(speed)
    self.cells_per_second = speed
end

-- Find perpendicular bounce direction for grid movement
function MovementController:findGridBounceDirection(head, current_dir, is_blocked_fn)
    local dirs = current_dir.x ~= 0
        and {{x = 0, y = -1}, {x = 0, y = 1}}
        or {{x = -1, y = 0}, {x = 1, y = 0}}
    local possible = {}
    for _, d in ipairs(dirs) do
        if not is_blocked_fn(head.x + d.x, head.y + d.y) then
            table.insert(possible, d)
        end
    end
    if #possible > 0 then
        return possible[math.random(#possible)]
    end
    return {x = -current_dir.x, y = -current_dir.y}
end

-- ============================================================================
-- SMOOTH MOVEMENT SYSTEM (continuous angle-based)
-- ============================================================================

-- Initialize smooth state
function MovementController:initSmoothState(entity_id, angle)
    entity_id = entity_id or "default"
    self.smooth_state[entity_id] = {
        angle = angle or 0,
        turn_left = false,
        turn_right = false
    }
end

-- Set turn flags
function MovementController:setSmoothTurn(entity_id, left, right)
    entity_id = entity_id or "default"
    local state = self.smooth_state[entity_id]
    if state then
        state.turn_left = left
        state.turn_right = right
    end
end

-- Get smooth state
function MovementController:getSmoothState(entity_id)
    entity_id = entity_id or "default"
    return self.smooth_state[entity_id]
end

-- Get/set angle
function MovementController:getSmoothAngle(entity_id)
    entity_id = entity_id or "default"
    local state = self.smooth_state[entity_id]
    return state and state.angle or 0
end

function MovementController:setSmoothAngle(entity_id, angle)
    entity_id = entity_id or "default"
    local state = self.smooth_state[entity_id]
    if state then state.angle = angle end
end

-- Update smooth movement
function MovementController:updateSmooth(dt, entity_id, entity, bounds, speed, turn_speed_deg)
    entity_id = entity_id or "default"
    local state = self.smooth_state[entity_id]
    if not state then return 0, 0, false, false end

    local turn_rate = math.rad(turn_speed_deg or 180) * dt
    if state.turn_left then state.angle = state.angle - turn_rate end
    if state.turn_right then state.angle = state.angle + turn_rate end

    while state.angle > math.pi do state.angle = state.angle - 2 * math.pi end
    while state.angle < -math.pi do state.angle = state.angle + 2 * math.pi end

    local move_speed = (speed or 8) * dt
    local dx = math.cos(state.angle) * move_speed
    local dy = math.sin(state.angle) * move_speed

    entity.x = entity.x + dx
    entity.y = entity.y + dy

    local wrapped, out_of_bounds = false, false

    if bounds.wrap_x then
        if entity.x < 0 then entity.x = entity.x + bounds.width; wrapped = true end
        if entity.x >= bounds.width then entity.x = entity.x - bounds.width; wrapped = true end
    else
        if entity.x < 0 or entity.x >= bounds.width then out_of_bounds = true end
    end

    if bounds.wrap_y then
        if entity.y < 0 then entity.y = entity.y + bounds.height; wrapped = true end
        if entity.y >= bounds.height then entity.y = entity.y - bounds.height; wrapped = true end
    else
        if entity.y < 0 or entity.y >= bounds.height then out_of_bounds = true end
    end

    return dx, dy, wrapped, out_of_bounds
end

-- Initialize both grid and smooth state
function MovementController:initState(entity_id, direction)
    entity_id = entity_id or "default"
    local dir_x, dir_y = direction and direction.x or 1, direction and direction.y or 0
    local angle = math.atan2(dir_y, dir_x)
    self:initGridState(entity_id, dir_x, dir_y)
    self:initSmoothState(entity_id, angle)
end

-- ============================================================================
-- HELPERS
-- ============================================================================

-- Shortest angular difference
function MovementController:angleDiff(target, current)
    local diff = (target - current + math.pi) % (2 * math.pi) - math.pi
    return diff
end

return MovementController
