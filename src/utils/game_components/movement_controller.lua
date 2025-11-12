-- MovementController: Reusable movement system for game entities
-- Supports multiple movement types: direct, asteroids, rail, jump/dash
-- All movement is deterministic for demo playback compatibility
--
-- Usage:
--   local MovementController = require('src.utils.game_components.movement_controller')
--   local mc = MovementController:new({
--       mode = "direct",           -- "direct", "asteroids", "rail", "jump"
--       speed = 300,               -- Movement speed (pixels/sec for direct, accel for asteroids)
--       friction = 1.0,            -- Friction factor (1.0 = instant, 0.95 = drift)
--       rotation_speed = 5.0,      -- Rotation speed (radians/sec)
--       -- Jump/dash specific:
--       jump_distance = 150,       -- Distance per jump
--       jump_cooldown = 0.5        -- Cooldown between jumps
--   })
--
--   -- In update loop:
--   local input = {left = false, right = true, up = false, down = false, jump = false}
--   local bounds = {x = 0, y = 0, width = 800, height = 600, wrap_x = false, wrap_y = false}
--   mc:update(dt, entity, input, bounds)
--
--   -- Entity table must have: {x, y, vx, vy, angle, width, height, radius}
--   -- After update(), entity.x, entity.y, entity.vx, entity.vy, entity.angle are modified

local Object = require('class')
local MovementController = Object:extend('MovementController')

function MovementController:new(params)
    params = params or {}

    -- Movement mode
    self.mode = params.mode or "direct"  -- "direct", "asteroids", "rail", "jump"

    -- Common parameters
    self.speed = params.speed or 300  -- Movement speed (pixels/sec for direct/rail, acceleration for asteroids)
    self.friction = params.friction or 1.0  -- Friction factor: 1.0 = instant response, <1.0 = momentum/drift
    self.accel_friction = params.accel_friction or self.friction  -- Friction during acceleration
    self.decel_friction = params.decel_friction or self.friction  -- Friction during deceleration
    self.rotation_speed = params.rotation_speed or 5.0  -- Rotation speed (radians/sec)
    self.bounce_damping = params.bounce_damping or 0.8  -- Velocity damping on boundary bounce

    -- Rail mode parameters
    self.rail_axis = params.rail_axis or "horizontal"  -- "horizontal" or "vertical"

    -- Asteroids mode parameters
    self.thrust_acceleration = params.thrust_acceleration or 600  -- Thrust force
    self.reverse_mode = params.reverse_mode or "brake"  -- "thrust", "brake", or "none"

    -- Jump/dash mode parameters
    self.jump_distance = params.jump_distance or 150  -- Distance per jump
    self.jump_cooldown = params.jump_cooldown or 0.5  -- Cooldown between jumps (seconds)
    self.jump_speed = params.jump_speed or 500  -- Speed during jump travel

    -- Internal jump state (stored per entity, but initialized here)
    self.jump_state = {}  -- Keyed by entity ID if multiple entities use same controller

    return self
end

-- Main update function - call this every frame
-- entity: {x, y, vx, vy, angle, width, height, radius, [optional: id, time_elapsed]}
-- input: {left, right, up, down, jump}
-- bounds: {x, y, width, height, wrap_x, wrap_y}
function MovementController:update(dt, entity, input, bounds)
    if self.mode == "direct" then
        self:updateDirect(dt, entity, input, bounds)
    elseif self.mode == "asteroids" then
        self:updateAsteroids(dt, entity, input, bounds)
    elseif self.mode == "rail" then
        self:updateRail(dt, entity, input, bounds)
    elseif self.mode == "jump" then
        self:updateJump(dt, entity, input, bounds)
    end
end

-- Direct movement: WASD controls with optional friction/momentum
function MovementController:updateDirect(dt, entity, input, bounds)
    local dx, dy = 0, 0
    if input.left then dx = dx - 1 end
    if input.right then dx = dx + 1 end
    if input.up then dy = dy - 1 end
    if input.down then dy = dy + 1 end

    -- Normalize diagonal movement
    if dx ~= 0 and dy ~= 0 then
        local inv_sqrt2 = 0.70710678118
        dx = dx * inv_sqrt2
        dy = dy * inv_sqrt2
    end

    -- Update rotation towards movement direction (optional visual feedback)
    if entity.angle ~= nil and (dx ~= 0 or dy ~= 0) then
        local target_rotation = math.atan2(dy, dx) + math.pi / 2  -- +π/2 for sprite facing up
        local diff = self:angleDiff(target_rotation, entity.angle)
        local max_turn = self.rotation_speed * dt
        diff = math.max(-max_turn, math.min(max_turn, diff))
        entity.angle = (entity.angle + diff) % (2 * math.pi)
    end

    -- Check if momentum/drift is enabled
    local has_momentum = self.accel_friction < 1.0 or self.decel_friction < 1.0

    if has_momentum then
        -- Velocity-based movement with friction
        if dx ~= 0 or dy ~= 0 then
            -- Apply input as acceleration
            entity.vx = entity.vx + dx * self.speed * dt
            entity.vy = entity.vy + dy * self.speed * dt

            -- Apply acceleration friction
            if self.accel_friction < 1.0 then
                local accel_factor = math.pow(self.accel_friction, dt * 60)
                entity.vx = entity.vx * accel_factor
                entity.vy = entity.vy * accel_factor
            end
        else
            -- Coasting - apply deceleration friction
            if self.decel_friction < 1.0 then
                local decel_factor = math.pow(self.decel_friction, dt * 60)
                entity.vx = entity.vx * decel_factor
                entity.vy = entity.vy * decel_factor
            else
                -- Instant stop
                entity.vx = 0
                entity.vy = 0
            end
        end

        -- Update position from velocity
        entity.x = entity.x + entity.vx * dt
        entity.y = entity.y + entity.vy * dt
    else
        -- Direct positional movement (no momentum)
        entity.x = entity.x + dx * self.speed * dt
        entity.y = entity.y + dy * self.speed * dt
    end

    -- Apply bounds clamping
    self:applyBounds(entity, bounds)

    -- Apply bounce if using velocity-based movement
    if has_momentum then
        self:applyBounce(entity, bounds)
    end
end

-- Asteroids movement: Rotation + thrust physics
function MovementController:updateAsteroids(dt, entity, input, bounds)
    -- Rotation controls
    if input.left then
        entity.angle = entity.angle - self.rotation_speed * dt
    end
    if input.right then
        entity.angle = entity.angle + self.rotation_speed * dt
    end

    -- Normalize rotation
    entity.angle = entity.angle % (2 * math.pi)

    -- Thrust controls
    local is_thrusting = false
    if input.up then
        is_thrusting = true
        -- Calculate thrust direction (sprite faces up by default, so angle 0 = up)
        local thrust_angle = entity.angle - math.pi / 2
        local thrust_x = math.cos(thrust_angle) * self.thrust_acceleration * dt
        local thrust_y = math.sin(thrust_angle) * self.thrust_acceleration * dt

        entity.vx = entity.vx + thrust_x
        entity.vy = entity.vy + thrust_y

        -- Apply acceleration friction
        if self.accel_friction < 1.0 then
            local accel_factor = math.pow(self.accel_friction, dt * 60)
            entity.vx = entity.vx * accel_factor
            entity.vy = entity.vy * accel_factor
        end
    end

    -- Reverse/brake controls
    if input.down then
        if self.reverse_mode == "thrust" then
            is_thrusting = true
            -- Reverse thrust
            local thrust_angle = entity.angle - math.pi / 2
            local thrust_x = math.cos(thrust_angle) * self.thrust_acceleration * dt
            local thrust_y = math.sin(thrust_angle) * self.thrust_acceleration * dt

            entity.vx = entity.vx - thrust_x
            entity.vy = entity.vy - thrust_y

            if self.accel_friction < 1.0 then
                local accel_factor = math.pow(self.accel_friction, dt * 60)
                entity.vx = entity.vx * accel_factor
                entity.vy = entity.vy * accel_factor
            end
        elseif self.reverse_mode == "brake" then
            -- Active braking
            local brake_strength = 0.92
            local brake_factor = math.pow(brake_strength, dt * 60)
            entity.vx = entity.vx * brake_factor
            entity.vy = entity.vy * brake_factor
        end
    end

    -- Apply deceleration friction when coasting
    if not is_thrusting and self.decel_friction < 1.0 then
        local decel_factor = math.pow(self.decel_friction, dt * 60)
        entity.vx = entity.vx * decel_factor
        entity.vy = entity.vy * decel_factor
    end

    -- Update position
    entity.x = entity.x + entity.vx * dt
    entity.y = entity.y + entity.vy * dt

    -- Apply bounds clamping
    self:applyBounds(entity, bounds)

    -- Apply bounce
    self:applyBounce(entity, bounds)
end

-- Rail movement: Constrained to one axis (horizontal or vertical)
function MovementController:updateRail(dt, entity, input, bounds)
    if self.rail_axis == "horizontal" then
        -- Horizontal rail: left/right only
        if input.left then
            entity.x = entity.x - self.speed * dt
        end
        if input.right then
            entity.x = entity.x + self.speed * dt
        end

        -- Clamp horizontal only
        if entity.width then
            entity.x = math.max(bounds.x, math.min(bounds.x + bounds.width - entity.width, entity.x))
        elseif entity.radius then
            entity.x = math.max(bounds.x + entity.radius, math.min(bounds.x + bounds.width - entity.radius, entity.x))
        end
    else
        -- Vertical rail: up/down only
        if input.up then
            entity.y = entity.y - self.speed * dt
        end
        if input.down then
            entity.y = entity.y + self.speed * dt
        end

        -- Clamp vertical only
        if entity.height then
            entity.y = math.max(bounds.y, math.min(bounds.y + bounds.height - entity.height, entity.y))
        elseif entity.radius then
            entity.y = math.max(bounds.y + entity.radius, math.min(bounds.y + bounds.height - entity.radius, entity.y))
        end
    end
end

-- Jump/Dash movement: Discrete teleport-style jumps with cooldown
function MovementController:updateJump(dt, entity, input, bounds)
    -- Get or initialize jump state for this entity
    local entity_id = entity.id or "default"
    if not self.jump_state[entity_id] then
        self.jump_state[entity_id] = {
            is_jumping = false,
            last_jump_time = -(self.jump_cooldown * 2),  -- Allow immediate first jump
            jump_target_x = 0,
            jump_target_y = 0,
            jump_dir_x = 0,
            jump_dir_y = 0
        }
    end
    local jump_state = self.jump_state[entity_id]

    -- Calculate time since last jump (use entity.time_elapsed if available, otherwise estimate)
    local current_time = entity.time_elapsed or 0
    local time_since_jump = current_time - jump_state.last_jump_time
    local can_jump = time_since_jump >= self.jump_cooldown

    -- Check if momentum/drift is enabled
    local has_momentum = self.accel_friction < 1.0 or self.decel_friction < 1.0

    -- If currently mid-jump, continue moving towards target
    if jump_state.is_jumping then
        -- Safety check: if jump has been going too long, end it (prevents getting stuck)
        local expected_jump_time = self.jump_distance / self.jump_speed
        local actual_jump_time = current_time - jump_state.last_jump_time
        if actual_jump_time > expected_jump_time * 2.5 then
            -- Jump took way too long, probably stuck on wall - end it
            jump_state.is_jumping = false
        end

        if jump_state.is_jumping then
            local dx = jump_state.jump_target_x - entity.x
            local dy = jump_state.jump_target_y - entity.y
            local dist_to_target = math.sqrt(dx*dx + dy*dy)

            -- If very high speed (9999+), teleport instantly
            if self.jump_speed >= 9999 then
            entity.x = jump_state.jump_target_x
            entity.y = jump_state.jump_target_y
            jump_state.is_jumping = false

            -- Set velocity for drift
            if has_momentum then
                entity.vx = jump_state.jump_dir_x * self.jump_speed * 0.3
                entity.vy = jump_state.jump_dir_y * self.jump_speed * 0.3
            end
        -- Move smoothly towards target
        elseif dist_to_target > 1 then
            local dir_x = dx / dist_to_target
            local dir_y = dy / dist_to_target
            local move_dist = self.jump_speed * dt

            if move_dist >= dist_to_target then
                -- Reached target
                entity.x = jump_state.jump_target_x
                entity.y = jump_state.jump_target_y
                jump_state.is_jumping = false

                if has_momentum then
                    entity.vx = jump_state.jump_dir_x * self.jump_speed * 0.3
                    entity.vy = jump_state.jump_dir_y * self.jump_speed * 0.3
                end
            else
                -- Store position before moving
                local old_x, old_y = entity.x, entity.y

                -- Move towards target
                entity.x = entity.x + dir_x * move_dist
                entity.y = entity.y + dir_y * move_dist

                -- Apply bounds clamping early for jump movement
                self:applyBounds(entity, bounds)

                -- After clamping, check if we actually moved
                -- (if not, we're stuck on a wall and should end jump)
                local moved_x = math.abs(entity.x - old_x)
                local moved_y = math.abs(entity.y - old_y)
                if moved_x < 0.5 and moved_y < 0.5 then
                    -- Barely moved, stuck on wall - end jump
                    jump_state.is_jumping = false
                    -- If using momentum mode, preserve some velocity for bounce
                    if has_momentum then
                        entity.vx = dir_x * self.jump_speed * 0.2
                        entity.vy = dir_y * self.jump_speed * 0.2
                    end
                end
            end

            -- Update rotation to face movement direction
            if entity.angle ~= nil then
                local target_rotation = math.atan2(dir_y, dir_x) + math.pi / 2
                local diff = self:angleDiff(target_rotation, entity.angle)
                local max_turn = self.rotation_speed * dt
                diff = math.max(-max_turn, math.min(max_turn, diff))
                entity.angle = (entity.angle + diff) % (2 * math.pi)
            end
        else
            -- Close enough, snap to target
            entity.x = jump_state.jump_target_x
            entity.y = jump_state.jump_target_y
            jump_state.is_jumping = false

            if has_momentum then
                entity.vx = jump_state.jump_dir_x * self.jump_speed * 0.3
                entity.vy = jump_state.jump_dir_y * self.jump_speed * 0.3
            end
        end
        end  -- Close the nested if jump_state.is_jumping check

    -- Not jumping, check if we can start a new jump
    elseif can_jump then
        -- Check for directional input (only one direction per jump)
        local jump_dx, jump_dy = 0, 0

        if input.left then
            jump_dx = -1
        elseif input.right then
            jump_dx = 1
        elseif input.up then
            jump_dy = -1
        elseif input.down then
            jump_dy = 1
        end

        -- If a direction was pressed, start jump
        if jump_dx ~= 0 or jump_dy ~= 0 then
            -- Calculate target position
            jump_state.jump_target_x = entity.x + jump_dx * self.jump_distance
            jump_state.jump_target_y = entity.y + jump_dy * self.jump_distance

            -- Clamp target to bounds
            if entity.radius then
                jump_state.jump_target_x = math.max(bounds.x + entity.radius, math.min(bounds.x + bounds.width - entity.radius, jump_state.jump_target_x))
                jump_state.jump_target_y = math.max(bounds.y + entity.radius, math.min(bounds.y + bounds.height - entity.radius, jump_state.jump_target_y))
            elseif entity.width and entity.height then
                jump_state.jump_target_x = math.max(bounds.x, math.min(bounds.x + bounds.width - entity.width, jump_state.jump_target_x))
                jump_state.jump_target_y = math.max(bounds.y, math.min(bounds.y + bounds.height - entity.height, jump_state.jump_target_y))
            end

            -- Store normalized direction
            jump_state.jump_dir_x = jump_dx
            jump_state.jump_dir_y = jump_dy

            -- Start jump
            jump_state.is_jumping = true
            jump_state.last_jump_time = current_time
        end
    end

    -- If not jumping and momentum mode is enabled, apply drift/friction
    if not jump_state.is_jumping and has_momentum then
        if self.decel_friction < 1.0 then
            local decel_factor = math.pow(self.decel_friction, dt * 60)
            entity.vx = entity.vx * decel_factor
            entity.vy = entity.vy * decel_factor
        else
            entity.vx = 0
            entity.vy = 0
        end

        -- Update position from velocity (drift)
        entity.x = entity.x + entity.vx * dt
        entity.y = entity.y + entity.vy * dt

        -- Update rotation to face drift direction
        if entity.angle ~= nil then
            local speed = math.sqrt(entity.vx * entity.vx + entity.vy * entity.vy)
            if speed > 10 then
                local target_rotation = math.atan2(entity.vy, entity.vx) + math.pi / 2
                local diff = self:angleDiff(target_rotation, entity.angle)
                local max_turn = self.rotation_speed * dt
                diff = math.max(-max_turn, math.min(max_turn, diff))
                entity.angle = (entity.angle + diff) % (2 * math.pi)
            end
        end
    end

    -- Apply bounds clamping (skip if we already did it during jump movement)
    self:applyBounds(entity, bounds)

    -- Apply bounce if using momentum
    if has_momentum then
        self:applyBounce(entity, bounds)
    end
end

-- Helper: Apply bounds clamping with optional wrapping
function MovementController:applyBounds(entity, bounds)
    if bounds.wrap_x then
        -- Wrap horizontal
        if entity.radius then
            -- Center-based positioning (check radius FIRST)
            if entity.x - entity.radius > bounds.x + bounds.width then
                entity.x = bounds.x - entity.radius
            elseif entity.x + entity.radius < bounds.x then
                entity.x = bounds.x + bounds.width + entity.radius
            end
        elseif entity.width then
            -- Top-left positioning
            if entity.x > bounds.x + bounds.width then
                entity.x = bounds.x - entity.width
            elseif entity.x + entity.width < bounds.x then
                entity.x = bounds.x + bounds.width
            end
        end
    else
        -- Clamp horizontal
        if entity.radius then
            -- Center-based positioning (check radius FIRST)
            entity.x = math.max(bounds.x + entity.radius, math.min(bounds.x + bounds.width - entity.radius, entity.x))
        elseif entity.width then
            -- Top-left positioning
            entity.x = math.max(bounds.x, math.min(bounds.x + bounds.width - entity.width, entity.x))
        end
    end

    if bounds.wrap_y then
        -- Wrap vertical
        if entity.radius then
            -- Center-based positioning (check radius FIRST)
            if entity.y - entity.radius > bounds.y + bounds.height then
                entity.y = bounds.y - entity.radius
            elseif entity.y + entity.radius < bounds.y then
                entity.y = bounds.y + bounds.height + entity.radius
            end
        elseif entity.height then
            -- Top-left positioning
            if entity.y > bounds.y + bounds.height then
                entity.y = bounds.y - entity.height
            elseif entity.y + entity.height < bounds.y then
                entity.y = bounds.y + bounds.height
            end
        end
    else
        -- Clamp vertical
        if entity.radius then
            -- Center-based positioning (check radius FIRST)
            entity.y = math.max(bounds.y + entity.radius, math.min(bounds.y + bounds.height - entity.radius, entity.y))
        elseif entity.height then
            -- Top-left positioning
            entity.y = math.max(bounds.y, math.min(bounds.y + bounds.height - entity.height, entity.y))
        end
    end
end

-- Helper: Apply bounce on boundary collision (velocity-based movement only)
function MovementController:applyBounce(entity, bounds)
    local hit_boundary = false

    -- Check horizontal boundaries
    if entity.radius then
        if entity.x <= bounds.x + entity.radius or entity.x >= bounds.x + bounds.width - entity.radius then
            entity.vx = -entity.vx * self.bounce_damping
            hit_boundary = true
        end
    elseif entity.width then
        if entity.x <= bounds.x or entity.x >= bounds.x + bounds.width - entity.width then
            entity.vx = -entity.vx * self.bounce_damping
            hit_boundary = true
        end
    end

    -- Check vertical boundaries
    if entity.radius then
        if entity.y <= bounds.y + entity.radius or entity.y >= bounds.y + bounds.height - entity.radius then
            entity.vy = -entity.vy * self.bounce_damping
            hit_boundary = true
        end
    elseif entity.height then
        if entity.y <= bounds.y or entity.y >= bounds.y + bounds.height - entity.height then
            entity.vy = -entity.vy * self.bounce_damping
            hit_boundary = true
        end
    end

    -- Re-clamp position after bounce to prevent sticking outside bounds
    if hit_boundary then
        if entity.radius then
            entity.x = math.max(bounds.x + entity.radius, math.min(bounds.x + bounds.width - entity.radius, entity.x))
            entity.y = math.max(bounds.y + entity.radius, math.min(bounds.y + bounds.height - entity.radius, entity.y))
        elseif entity.width and entity.height then
            entity.x = math.max(bounds.x, math.min(bounds.x + bounds.width - entity.width, entity.x))
            entity.y = math.max(bounds.y, math.min(bounds.y + bounds.height - entity.height, entity.y))
        end
    end
end

-- Helper: Calculate shortest angular difference between two angles
function MovementController:angleDiff(target, current)
    local diff = (target - current + math.pi) % (2 * math.pi) - math.pi
    return diff
end

return MovementController
