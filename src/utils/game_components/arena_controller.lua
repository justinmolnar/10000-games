-- ArenaController: Manages play area bounds, shapes, and dynamic behaviors
-- Handles arena shapes (rectangle, circle, hexagon), shrinking, pulsing, safe zones
--
-- Usage:
--   local ArenaController = require('src.utils.game_components.arena_controller')
--   local arena = ArenaController:new({
--       width = 800,
--       height = 600,
--       shape = "rectangle",           -- "rectangle", "circle", "hexagon"
--       -- Shrinking:
--       shrink = false,                -- Enable shrinking
--       shrink_interval = 5,           -- Seconds between shrink steps
--       shrink_amount = 1,             -- Amount to shrink per step (pixels or cells)
--       min_width = 200,               -- Minimum width
--       min_height = 200,              -- Minimum height
--       -- Safe zone (Dodge-style):
--       safe_zone = false,             -- Enable safe zone mode
--       safe_zone_radius = 100,        -- Initial radius
--       safe_zone_min_radius = 20,     -- Minimum radius
--       safe_zone_shrink_speed = 1,    -- Radius shrink per second
--       -- Pulsing:
--       pulse = false,                 -- Enable pulsing (radius oscillates)
--       pulse_speed = 1,               -- Pulses per second
--       pulse_amplitude = 20,          -- Radius change amount
--       -- Movement:
--       movement = "none",             -- "none", "drift", "cardinal", "follow"
--       movement_speed = 50,           -- Movement speed
--       friction = 0.95,               -- Movement friction
--   })
--
--   -- In update loop:
--   arena:update(dt)
--   local bounds = arena:getBounds()
--   if arena:isInside(x, y) then ... end

local Object = require('class')
local ArenaController = Object:extend('ArenaController')

function ArenaController:new(params)
    params = params or {}

    -- Base dimensions
    self.base_width = params.width or 800
    self.base_height = params.height or 600
    self.current_width = self.base_width
    self.current_height = self.base_height

    -- Center position (for movable arenas)
    self.x = params.x or (self.base_width / 2)
    self.y = params.y or (self.base_height / 2)

    -- Velocity (for movement)
    self.vx = params.vx or 0
    self.vy = params.vy or 0
    self.target_vx = params.target_vx or 0
    self.target_vy = params.target_vy or 0

    -- Shape
    self.shape = params.shape or "rectangle"  -- "rectangle", "circle", "hexagon"

    -- Shrinking configuration
    self.shrink_enabled = params.shrink or false
    self.shrink_interval = params.shrink_interval or 5  -- seconds between shrinks
    self.shrink_amount = params.shrink_amount or 1      -- amount per shrink
    self.min_width = params.min_width or math.floor(self.base_width * 0.3)
    self.min_height = params.min_height or math.floor(self.base_height * 0.3)
    self.shrink_timer = 0

    -- Safe zone mode (circular arena with radius, like Dodge)
    self.safe_zone_mode = params.safe_zone or false
    self.radius = params.safe_zone_radius or params.radius or math.min(self.base_width, self.base_height) / 2
    self.initial_radius = self.radius
    self.min_radius = params.safe_zone_min_radius or params.min_radius or 20
    self.shrink_speed = params.safe_zone_shrink_speed or params.shrink_speed or 0

    -- Pulsing configuration
    self.pulse_enabled = params.pulse or false
    self.pulse_speed = params.pulse_speed or 1          -- pulses per second
    self.pulse_amplitude = params.pulse_amplitude or 20 -- radius change
    self.pulse_timer = 0
    self.pulse_offset = 0  -- Current pulse offset to radius

    -- Morph configuration (Dodge-style: shrink, pulsing, shape_shifting, deformation, none)
    self.morph_type = params.morph_type or "none"  -- "none", "shrink", "pulsing", "shape_shifting", "deformation"
    self.morph_speed = params.morph_speed or 1.0
    self.morph_timer = 0
    self.shape_shift_interval = params.shape_shift_interval or 3.0
    self.shape_cycle = params.shape_cycle or {"circle", "square", "hex"}
    self.shape_index = 1
    self.deformation_offset = 0  -- Visual wobble for deformation morph type

    -- Movement configuration
    self.movement_type = params.movement or "none"  -- "none", "drift", "cardinal", "follow", "orbit"
    self.movement_speed = params.movement_speed or 50
    self.friction = params.friction or 0.95
    self.direction_timer = 0
    self.direction_change_interval = params.direction_change_interval or 2.0

    -- Boundaries for movement (arena can't move outside these)
    self.bounds_padding = params.bounds_padding or 50
    self.container_width = params.container_width or self.base_width
    self.container_height = params.container_height or self.base_height

    -- Moving walls offset (Snake-specific feature)
    self.wall_offset_x = 0
    self.wall_offset_y = 0
    self.moving_walls = params.moving_walls or false
    self.wall_move_interval = params.wall_move_interval or 3
    self.wall_move_timer = 0

    -- Compute radius/shrink from raw schema params if area_size provided
    if params.area_size then
        local min_dim = math.min(self.container_width, self.container_height)
        local area_size = params.area_size
        self.radius = min_dim * (params.initial_radius_fraction or 0.48) * area_size
        self.initial_radius = self.radius
        self.min_radius = min_dim * (params.min_radius_fraction or 0.35) * area_size
        if params.shrink_seconds and params.shrink_seconds > 0 then
            local complexity = params.complexity_modifier or 1.0
            self.shrink_speed = (self.radius - self.min_radius) / (params.shrink_seconds / complexity)
        end
    end

    -- Compute initial velocity from movement params
    if params.movement ~= "none" and params.movement_speed and params.movement_speed > 0 then
        local speed = params.movement_speed
        if params.movement == "drift" then
            local angle = math.random() * math.pi * 2
            self.vx = math.cos(angle) * speed
            self.vy = math.sin(angle) * speed
            self.target_vx = self.vx
            self.target_vy = self.vy
        elseif params.movement == "cardinal" then
            local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
            local d = dirs[math.random(1,4)]
            self.vx = d[1] * speed
            self.vy = d[2] * speed
            self.target_vx = self.vx
            self.target_vy = self.vy
        end
    end

    -- Callback for shrink events (to spawn obstacles)
    self.on_shrink = params.on_shrink or nil

    -- Grid mode (for Snake-style grid-based arenas)
    self.grid_mode = params.grid_mode or false
    self.cell_size = params.cell_size or 20

    return self
end

-- Main update function
function ArenaController:update(dt)
    -- Update shrinking (rectangular mode)
    if self.shrink_enabled then
        self:updateShrink(dt)
    end

    -- Update morph (Dodge-style: handles shrink, pulsing, shape_shifting for safe_zone_mode)
    if self.safe_zone_mode and self.morph_type ~= "none" then
        self:updateMorph(dt)
    elseif self.safe_zone_mode and self.shrink_speed > 0 then
        -- Legacy: simple radius shrinking without morph_type
        self:updateRadiusShrink(dt)
    end

    -- Update pulsing (standalone, separate from morph)
    if self.pulse_enabled and self.morph_type == "none" then
        self:updatePulse(dt)
    end

    -- Update movement
    if self.movement_type ~= "none" then
        self:updateMovement(dt)
    end

    -- Update moving walls
    if self.moving_walls then
        self:updateMovingWalls(dt)
    end
end

-- Shrinking update (rectangular shrinking by adding walls)
function ArenaController:updateShrink(dt)
    self.shrink_timer = self.shrink_timer + dt
    if self.shrink_timer >= self.shrink_interval then
        self.shrink_timer = self.shrink_timer - self.shrink_interval

        local did_shrink = false
        if self.current_width > self.min_width then
            self.current_width = self.current_width - self.shrink_amount
            did_shrink = true
        end
        if self.current_height > self.min_height then
            self.current_height = self.current_height - self.shrink_amount
            did_shrink = true
        end

        -- Trigger callback if shrinking occurred
        if did_shrink and self.on_shrink then
            self.on_shrink(self:getShrinkMargins())
        end
    end
end

-- Radius shrinking update (for safe zone mode)
function ArenaController:updateRadiusShrink(dt)
    if self.radius > self.min_radius then
        self.radius = math.max(self.min_radius, self.radius - self.shrink_speed * dt)
    end
end

-- Pulse update
function ArenaController:updatePulse(dt)
    self.pulse_timer = self.pulse_timer + dt * self.pulse_speed * math.pi * 2
    self.pulse_offset = math.sin(self.pulse_timer) * self.pulse_amplitude
end

-- Morph update (Dodge-style: shrink, pulsing, shape_shifting, deformation)
function ArenaController:updateMorph(dt)
    self.morph_timer = self.morph_timer + dt * self.morph_speed

    if self.morph_type == "shrink" then
        -- Linear shrink toward min_radius
        if self.radius > self.min_radius then
            self.radius = math.max(self.min_radius, self.radius - self.shrink_speed * dt)
        end

    elseif self.morph_type == "pulsing" then
        -- Oscillate between initial_radius and min_radius using sine wave
        local pulse = (math.sin(self.morph_timer * 2) + 1) / 2  -- 0 to 1
        self.radius = self.min_radius + (self.initial_radius - self.min_radius) * pulse

    elseif self.morph_type == "shape_shifting" then
        -- Cycle through shapes at intervals
        if self.morph_timer >= self.shape_shift_interval then
            self.morph_timer = 0
            self.shape_index = (self.shape_index % #self.shape_cycle) + 1
            self.shape = self.shape_cycle[self.shape_index]
        end
        -- Also shrink while shape shifting
        if self.radius > self.min_radius then
            self.radius = math.max(self.min_radius, self.radius - self.shrink_speed * dt)
        end

    elseif self.morph_type == "deformation" then
        -- Wobble/deformation (visual effect stored for rendering)
        self.deformation_offset = math.sin(self.morph_timer * 3) * 0.1  -- 10% wobble
        -- Also shrink
        if self.radius > self.min_radius then
            self.radius = math.max(self.min_radius, self.radius - self.shrink_speed * dt)
        end
    end
end

-- Movement update
function ArenaController:updateMovement(dt)
    if self.movement_type == "drift" then
        -- Random drift with friction
        self.vx = self.vx + (math.random() - 0.5) * self.movement_speed * dt
        self.vy = self.vy + (math.random() - 0.5) * self.movement_speed * dt

    elseif self.movement_type == "cardinal" then
        -- Change direction periodically
        self.direction_timer = self.direction_timer + dt
        if self.direction_timer >= self.direction_change_interval then
            self.direction_timer = 0
            local dir = math.random(1, 4)
            if dir == 1 then self.target_vx, self.target_vy = self.movement_speed, 0
            elseif dir == 2 then self.target_vx, self.target_vy = -self.movement_speed, 0
            elseif dir == 3 then self.target_vx, self.target_vy = 0, self.movement_speed
            else self.target_vx, self.target_vy = 0, -self.movement_speed end
        end
        -- Interpolate toward target velocity
        self.vx = self.vx + (self.target_vx - self.vx) * (1 - self.friction)
        self.vy = self.vy + (self.target_vy - self.vy) * (1 - self.friction)

    elseif self.movement_type == "orbit" then
        -- Circular orbit around center
        local orbit_radius = 50
        local orbit_speed = self.movement_speed / orbit_radius
        self.direction_timer = self.direction_timer + dt * orbit_speed
        local center_x = self.container_width / 2
        local center_y = self.container_height / 2
        self.x = center_x + math.cos(self.direction_timer) * orbit_radius
        self.y = center_y + math.sin(self.direction_timer) * orbit_radius
        return  -- Skip velocity-based position update
    end

    -- Apply friction
    self.vx = self.vx * self.friction
    self.vy = self.vy * self.friction

    -- Update position
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Bounce off container boundaries (keep entire shape on screen)
    local effective_radius = self:getEffectiveRadius()
    local min_x = self.bounds_padding + effective_radius
    local max_x = self.container_width - self.bounds_padding - effective_radius
    local min_y = self.bounds_padding + effective_radius
    local max_y = self.container_height - self.bounds_padding - effective_radius

    if self.x < min_x then self.x = min_x; self.vx = math.abs(self.vx) end
    if self.x > max_x then self.x = max_x; self.vx = -math.abs(self.vx) end
    if self.y < min_y then self.y = min_y; self.vy = math.abs(self.vy) end
    if self.y > max_y then self.y = max_y; self.vy = -math.abs(self.vy) end
end

-- Moving walls update (Snake-specific)
function ArenaController:updateMovingWalls(dt)
    self.wall_move_timer = self.wall_move_timer + dt
    if self.wall_move_timer >= self.wall_move_interval then
        self.wall_move_timer = self.wall_move_timer - self.wall_move_interval

        -- Random offset
        local max_offset = math.floor(self.base_width * 0.2)
        self.wall_offset_x = math.random(-max_offset, max_offset)
        self.wall_offset_y = math.random(-max_offset, max_offset)
    end
end

-- Get point on shape boundary at given angle (for spawns, etc.)
function ArenaController:getPointOnShapeBoundary(angle, radius)
    radius = radius or self:getEffectiveRadius()

    if self.shape == "circle" then
        return self.x + math.cos(angle) * radius, self.y + math.sin(angle) * radius

    elseif self.shape == "square" then
        -- Find intersection of ray from center at angle with square boundary
        local dx = math.cos(angle)
        local dy = math.sin(angle)
        local abs_dx = math.abs(dx)
        local abs_dy = math.abs(dy)

        local t
        if abs_dx > abs_dy then
            t = radius / abs_dx
        else
            t = radius / abs_dy
        end
        return self.x + dx * t, self.y + dy * t

    elseif self.shape == "hex" then
        -- Pointy-top hexagon: find intersection with hex boundary
        local dx = math.cos(angle)
        local dy = math.sin(angle)
        local abs_dx = math.abs(dx)
        local abs_dy = math.abs(dy)
        local hex_width = radius * 0.866  -- sqrt(3)/2

        -- Check which edge the ray hits first
        local t = radius  -- default

        -- Vertical extent (top/bottom points)
        if abs_dy > 0.001 then
            local t_vert = radius / abs_dy
            local hit_x = abs_dx * t_vert
            if hit_x <= hex_width then
                t = t_vert
            end
        end

        -- Horizontal extent (left/right flat edges)
        if abs_dx > 0.001 then
            local t_horiz = hex_width / abs_dx
            local hit_y = abs_dy * t_horiz
            if hit_y <= radius * 0.5 then
                t = math.min(t, t_horiz)
            end
        end

        -- Angled edges: 0.577 * |x| + |y| = radius
        local angled_denom = 0.577 * abs_dx + abs_dy
        if angled_denom > 0.001 then
            local t_angled = radius / angled_denom
            t = math.min(t, t_angled)
        end

        return self.x + dx * t, self.y + dy * t

    else
        -- Default to circle
        return self.x + math.cos(angle) * radius, self.y + math.sin(angle) * radius
    end
end

function ArenaController:getRandomBoundaryPoint(radius)
    radius = radius or self:getEffectiveRadius()
    if self.shape == "circle" then
        local a = math.random() * math.pi * 2
        return self.x + math.cos(a) * radius, self.y + math.sin(a) * radius, a
    elseif self.shape == "square" then
        local side = math.random(4)
        local t = math.random() * 2 - 1
        if side == 1 then return self.x + radius, self.y + t * radius, 0
        elseif side == 2 then return self.x - radius, self.y + t * radius, math.pi
        elseif side == 3 then return self.x + t * radius, self.y + radius, math.pi / 2
        else return self.x + t * radius, self.y - radius, -math.pi / 2 end
    elseif self.shape == "hex" then
        local hw = radius * 0.866
        local edge = math.random(6)
        local t = math.random()
        if edge == 1 then return self.x + hw * t, self.y - radius + radius * 0.5 * t, math.atan2(0.5, 0.866)
        elseif edge == 2 then return self.x + hw, self.y - radius * 0.5 + radius * t, 0
        elseif edge == 3 then return self.x + hw * (1-t), self.y + radius * 0.5 + radius * 0.5 * (1-t), math.atan2(0.5, -0.866)
        elseif edge == 4 then return self.x - hw * t, self.y + radius - radius * 0.5 * t, math.atan2(-0.5, -0.866)
        elseif edge == 5 then return self.x - hw, self.y + radius * 0.5 - radius * t, math.pi
        else return self.x - hw * (1-t), self.y - radius * 0.5 - radius * 0.5 * (1-t), math.atan2(-0.5, 0.866) end
    else
        local a = math.random() * math.pi * 2
        return self.x + math.cos(a) * radius, self.y + math.sin(a) * radius, a
    end
end

-- Get effective radius (base + pulse offset)
function ArenaController:getEffectiveRadius()
    return self.radius + self.pulse_offset
end

-- Get shrink margins (for rectangular shrinking)
function ArenaController:getShrinkMargins()
    return {
        left = math.floor((self.base_width - self.current_width) / 2),
        right = math.floor((self.base_width - self.current_width) / 2),
        top = math.floor((self.base_height - self.current_height) / 2),
        bottom = math.floor((self.base_height - self.current_height) / 2)
    }
end

-- Get shrink progress (0 = full size, 1 = minimum size)
function ArenaController:getShrinkProgress()
    if self.safe_zone_mode then
        local range = self.initial_radius - self.min_radius
        if range <= 0 then return 0 end
        return 1 - ((self.radius - self.min_radius) / range)
    else
        local width_range = self.base_width - self.min_width
        local height_range = self.base_height - self.min_height
        if width_range <= 0 and height_range <= 0 then return 0 end

        local width_progress = width_range > 0 and (1 - (self.current_width - self.min_width) / width_range) or 0
        local height_progress = height_range > 0 and (1 - (self.current_height - self.min_height) / height_range) or 0
        return math.max(width_progress, height_progress)
    end
end

-- Get bounds for rendering/collision
function ArenaController:getBounds()
    local effective_radius = self:getEffectiveRadius()

    if self.safe_zone_mode then
        return {
            x = self.x,
            y = self.y,
            radius = effective_radius,
            shape = self.shape
        }
    else
        local margins = self:getShrinkMargins()
        return {
            x = margins.left + self.wall_offset_x,
            y = margins.top + self.wall_offset_y,
            width = self.current_width,
            height = self.current_height,
            shape = self.shape,
            -- Grid-specific bounds
            grid_width = self.grid_mode and math.floor(self.current_width / self.cell_size) or nil,
            grid_height = self.grid_mode and math.floor(self.current_height / self.cell_size) or nil
        }
    end
end

-- Check if a position is inside the arena
-- margin: optional entity radius to shrink effective bounds (for edge collision)
function ArenaController:isInside(x, y, margin)
    margin = margin or 0
    -- Apply moving walls offset
    local offset_x = self.wall_offset_x
    local offset_y = self.wall_offset_y

    if self.safe_zone_mode then
        -- Shape-aware safe zone collision
        local dx = x - self.x
        local dy = y - self.y
        local effective_radius = self:getEffectiveRadius() - margin
        local inside_shape = false

        if self.shape == "circle" then
            -- Circle: simple distance check
            local dist_sq = dx * dx + dy * dy
            inside_shape = dist_sq <= effective_radius * effective_radius

        elseif self.shape == "square" then
            -- Square: check if within bounding box
            local half = effective_radius
            inside_shape = math.abs(dx) <= half and math.abs(dy) <= half

        elseif self.shape == "hex" or self.shape == "hexagon" then
            -- Hexagon: pointy-top hexagon math
            local abs_dx = math.abs(dx)
            local abs_dy = math.abs(dy)
            -- Hexagon bounds: vertical extent is radius, horizontal is radius * sqrt(3)/2
            local hex_width = effective_radius * 0.866  -- sqrt(3)/2
            if abs_dx <= hex_width and abs_dy <= effective_radius then
                -- Check slanted edges: dx * 0.577 + dy <= radius (where 0.577 = 1/sqrt(3))
                inside_shape = abs_dx * 0.577 + abs_dy <= effective_radius
            end

        else
            -- Default to circle for unknown shapes
            local dist_sq = dx * dx + dy * dy
            inside_shape = dist_sq <= effective_radius * effective_radius
        end

        return inside_shape
    end

    -- Non-safe-zone shapes
    if self.shape == "circle" then
        local center_x = (self.current_width / 2) + offset_x
        local center_y = (self.current_height / 2) + offset_y
        local radius = math.min(self.current_width, self.current_height) / 2
        local dx = x - center_x
        local dy = y - center_y
        return (dx * dx + dy * dy) <= (radius * radius)

    elseif self.shape == "hexagon" then
        local center_x = (self.current_width / 2) + offset_x
        local center_y = (self.current_height / 2) + offset_y
        local size = math.min(self.current_width, self.current_height) / 2

        local dx = math.abs(x - center_x)
        local dy = math.abs(y - center_y)

        -- Hexagon approximation
        if dx > size * 0.866 then return false end  -- sqrt(3)/2
        if dy > size then return false end
        if dx * 0.577 + dy > size then return false end  -- 1/sqrt(3)

        return true

    else
        -- Rectangle (default)
        local margins = self:getShrinkMargins()
        local min_x = margins.left + math.max(0, offset_x)
        local max_x = self.base_width - margins.right + math.min(0, offset_x)
        local min_y = margins.top + math.max(0, offset_y)
        local max_y = self.base_height - margins.bottom + math.min(0, offset_y)

        return x >= min_x and x <= max_x and y >= min_y and y <= max_y
    end
end

-- Check if a grid position is inside (for grid-based games like Snake)
-- margin: optional entity radius to shrink effective arena (for edge collision)
function ArenaController:isInsideGrid(grid_x, grid_y, margin)
    if self.grid_mode then
        local px = grid_x * self.cell_size + self.cell_size / 2
        local py = grid_y * self.cell_size + self.cell_size / 2
        return self:isInside(px, py, margin)
    else
        return self:isInside(grid_x, grid_y, margin)
    end
end

-- Set position directly (useful for "follow" movement type)
function ArenaController:setPosition(x, y)
    self.x = x
    self.y = y
end

-- Set velocity directly
function ArenaController:setVelocity(vx, vy)
    self.vx = vx
    self.vy = vy
    self.target_vx = vx
    self.target_vy = vy
end

-- Reset arena to initial state
function ArenaController:reset()
    self.current_width = self.base_width
    self.current_height = self.base_height
    self.radius = self.initial_radius
    self.x = self.base_width / 2
    self.y = self.base_height / 2
    self.vx = 0
    self.vy = 0
    self.shrink_timer = 0
    self.pulse_timer = 0
    self.pulse_offset = 0
    self.wall_offset_x = 0
    self.wall_offset_y = 0
    self.wall_move_timer = 0
    self.direction_timer = 0
end

-- Update container dimensions (call when viewport changes)
function ArenaController:setContainerSize(width, height)
    self.container_width = width
    self.container_height = height
    -- Recenter the arena if it's in safe_zone mode
    if self.safe_zone_mode then
        self.x = width / 2
        self.y = height / 2
    end
end

-- Get current state for rendering
function ArenaController:getState()
    return {
        x = self.x,
        y = self.y,
        vx = self.vx,
        vy = self.vy,
        width = self.current_width,
        height = self.current_height,
        radius = self:getEffectiveRadius(),
        initial_radius = self.initial_radius,
        min_radius = self.min_radius,
        shape = self.shape,
        morph_type = self.morph_type,
        morph_timer = self.morph_timer,
        deformation_offset = self.deformation_offset,
        shrink_progress = self:getShrinkProgress(),
        wall_offset_x = self.wall_offset_x,
        wall_offset_y = self.wall_offset_y
    }
end

-- Draw arena boundary (for non-rectangle shapes)
-- scale: pixels per unit (e.g., GRID_SIZE for grid-based games)
function ArenaController:drawBoundary(scale, color)
    scale = scale or 1
    color = color or {0.5, 0.5, 0.5, 0.8}

    love.graphics.setColor(color)
    love.graphics.setLineWidth(3)

    -- Use same center and radius as collision detection (isInside)
    local cx = self.x * scale
    local cy = self.y * scale
    local radius = self:getEffectiveRadius() * scale

    if self.shape == "circle" then
        love.graphics.circle("line", cx, cy, radius)
    elseif self.shape == "hexagon" or self.shape == "hex" then
        local vertices = {}
        for i = 0, 5 do
            local angle = math.pi / 6 + i * math.pi / 3
            table.insert(vertices, cx + math.cos(angle) * radius)
            table.insert(vertices, cy + math.sin(angle) * radius)
        end
        love.graphics.polygon("line", vertices)
    end
    -- Rectangle uses edge walls, no boundary line needed

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Get grid cells outside the playable area (for rendering walls)
-- Returns array of {x, y} grid positions
function ArenaController:getBoundaryCells(grid_width, grid_height)
    local cells = {}
    local margins = self:getShrinkMargins()

    for y = 0, grid_height - 1 do
        for x = 0, grid_width - 1 do
            local outside = false

            if self.safe_zone_mode then
                -- Shaped arenas: check if outside shape
                outside = not self:isInsideGrid(x, y)
            else
                -- Rectangle: edge cells (0 and grid_width-1) are walls, plus shrink margins
                outside = x <= margins.left or x >= grid_width - 1 - margins.right or
                          y <= margins.top or y >= grid_height - 1 - margins.bottom
            end

            if outside then
                table.insert(cells, {x = x, y = y})
            end
        end
    end
    return cells
end

-- Clamp entity to stay inside arena bounds with optional bounce
-- entity: {x, y, vx, vy, radius, bounce_damping}
function ArenaController:clampEntity(entity)
    if not self.safe_zone_mode then return end

    local radius = entity.radius or 0
    local dx = entity.x - self.x
    local dy = entity.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local bounce = entity.bounce_damping or 0

    if self.shape == "circle" then
        local max_dist = math.max(0, self:getEffectiveRadius() - radius)
        if dist > max_dist and dist > 0 then
            local scale = max_dist / dist
            entity.x = self.x + dx * scale
            entity.y = self.y + dy * scale

            if entity.vx and entity.vy then
                local nx, ny = dx / dist, dy / dist
                local dot = entity.vx * nx + entity.vy * ny
                if dot > 0 then
                    local factor = 1.0 + bounce
                    entity.vx = entity.vx - nx * dot * factor
                    entity.vy = entity.vy - ny * dot * factor
                end
            end
        end

    elseif self.shape == "square" then
        local half = self:getEffectiveRadius() - radius
        local clamped_x = math.max(self.x - half, math.min(self.x + half, entity.x))
        local clamped_y = math.max(self.y - half, math.min(self.y + half, entity.y))

        if clamped_x ~= entity.x or clamped_y ~= entity.y then
            if entity.vx and clamped_x ~= entity.x then
                entity.vx = -entity.vx * bounce
            end
            if entity.vy and clamped_y ~= entity.y then
                entity.vy = -entity.vy * bounce
            end
            entity.x = clamped_x
            entity.y = clamped_y
        end

    elseif self.shape == "hex" or self.shape == "hexagon" then
        local r = self:getEffectiveRadius() - radius
        local abs_dx, abs_dy = math.abs(dx), math.abs(dy)
        local hex_width = r * 0.866
        local clamped = false
        local nx, ny = 0, 0

        if abs_dy > r then
            entity.y = self.y + (dy > 0 and r or -r)
            ny = dy > 0 and 1 or -1
            clamped = true
        end

        if abs_dx > hex_width then
            entity.x = self.x + (dx > 0 and hex_width or -hex_width)
            nx = dx > 0 and 1 or -1
            clamped = true
        end

        -- Check angled edges
        local check_dx = math.abs(entity.x - self.x)
        local check_dy = math.abs(entity.y - self.y)
        if check_dx * 0.577 + check_dy > r then
            local t = r / (check_dx * 0.577 + check_dy)
            entity.x = self.x + (entity.x - self.x) * t
            entity.y = self.y + (entity.y - self.y) * t
            nx = dx > 0 and 0.5 or -0.5
            ny = dy > 0 and 0.866 or -0.866
            clamped = true
        end

        if clamped and entity.vx and entity.vy then
            local dot = entity.vx * nx + entity.vy * ny
            if dot > 0 then
                local factor = 1.0 + bounce
                entity.vx = entity.vx - nx * dot * factor
                entity.vy = entity.vy - ny * dot * factor
            end
        end
    end
end

return ArenaController
