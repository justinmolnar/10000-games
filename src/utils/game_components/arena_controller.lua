-- ArenaController: Manages play area bounds and dynamic behaviors
-- Shape-agnostic: accepts sides count or explicit vertices, all operations use generic polygon math
--
-- Usage:
--   local ArenaController = require('src.utils.game_components.arena_controller')
--   local arena = ArenaController:new({
--       width = 800,
--       height = 600,
--       -- Shape (polygon-based):
--       sides = 6,                     -- Regular polygon with N sides
--       shape_rotation = 0,            -- Rotation offset in radians
--       -- OR explicit vertices (normalized, radius=1):
--       vertices = {{x=0,y=-1}, {x=0.866,y=0.5}, {x=-0.866,y=0.5}},
--       -- Shrinking:
--       shrink = false,
--       shrink_interval = 5,
--       shrink_amount = 1,
--       -- Safe zone mode (polygon-based collision):
--       safe_zone = false,
--       safe_zone_radius = 100,
--       -- Movement (pure physics):
--       friction = 0.95,
--       ax = 0, ay = 0,
--   })
--
--   -- In update loop:
--   arena:update(dt)
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

    -- Velocity and acceleration (for movement)
    self.vx = params.vx or 0
    self.vy = params.vy or 0
    self.ax = params.ax or 0
    self.ay = params.ay or 0

    -- Shape (polygon-based: vertices normalized to radius=1)
    self.vertices = params.vertices or self:generateRegularPolygon(
        params.sides or 32,
        params.shape_rotation or 0
    )

    -- Shrinking configuration
    self.shrink_enabled = params.shrink or false
    self.shrink_interval = params.shrink_interval or 5  -- seconds between shrinks
    self.shrink_amount = params.shrink_amount or 1      -- amount per shrink
    self.min_width = params.min_width or math.floor(self.base_width * 0.3)
    self.min_height = params.min_height or math.floor(self.base_height * 0.3)
    self.shrink_timer = 0

    -- Safe zone mode (polygon-based collision using vertices and radius)
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

    -- Morph configuration (dynamic arena transformations)
    self.morph_type = params.morph_type or "none"
    self.morph_speed = params.morph_speed or 1.0
    self.morph_timer = 0
    self.shape_shift_interval = params.shape_shift_interval or 3.0
    -- Shape cycle as side counts for shape_shifting morph (game provides values)
    self.sides_cycle = params.sides_cycle or {}
    self.sides_index = 1
    self.deformation_offset = 0  -- Visual wobble for deformation morph type

    -- Movement configuration (pure physics - game sets ax/ay)
    self.friction = params.friction or 0.95

    -- Boundaries for movement (arena can't move outside these)
    self.bounds_padding = params.bounds_padding or 50
    self.container_width = params.container_width or self.base_width
    self.container_height = params.container_height or self.base_height

    -- Moving walls offset
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

    -- Callback for shrink events (to spawn obstacles)
    self.on_shrink = params.on_shrink or nil

    -- Grid mode (for grid-based arenas)
    self.grid_mode = params.grid_mode or false
    self.cell_size = params.cell_size or 20

    return self
end

-- Generate regular polygon vertices (normalized to radius=1)
function ArenaController:generateRegularPolygon(sides, rotation)
    rotation = rotation or 0
    local verts = {}
    for i = 0, sides - 1 do
        local angle = rotation + (i / sides) * math.pi * 2
        table.insert(verts, {x = math.cos(angle), y = math.sin(angle)})
    end
    return verts
end

-- Get vertices scaled to current radius and translated to position
function ArenaController:getScaledVertices()
    local r = self:getEffectiveRadius()
    local scaled = {}
    for _, v in ipairs(self.vertices) do
        table.insert(scaled, self.x + v.x * r)
        table.insert(scaled, self.y + v.y * r)
    end
    return scaled
end

-- Main update function
function ArenaController:update(dt)
    -- Update shrinking (rectangular mode)
    if self.shrink_enabled then
        self:updateShrink(dt)
    end

    -- Update morph (handles shrink, pulsing, shape_shifting for safe_zone_mode)
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

    -- Update movement (pure physics - game sets ax/ay for behavior)
    self:updateMovement(dt)

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

-- Morph update (shrink, pulsing, shape_shifting, deformation)
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
        -- Cycle through side counts at intervals
        if self.morph_timer >= self.shape_shift_interval then
            self.morph_timer = 0
            self.sides_index = (self.sides_index % #self.sides_cycle) + 1
            self.vertices = self:generateRegularPolygon(self.sides_cycle[self.sides_index], 0)
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

-- Movement update (pure physics - game sets ax/ay for behavior)
function ArenaController:updateMovement(dt)
    -- Apply acceleration
    self.vx = self.vx + self.ax * dt
    self.vy = self.vy + self.ay * dt

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

-- Set acceleration (called by game each frame to control movement behavior)
function ArenaController:setAcceleration(ax, ay)
    self.ax = ax
    self.ay = ay
end

-- Moving walls update
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

-- Get point on shape boundary at given angle (ray-polygon intersection)
function ArenaController:getPointOnShapeBoundary(angle, radius)
    radius = radius or self:getEffectiveRadius()
    local dx = math.cos(angle)
    local dy = math.sin(angle)

    -- Ray from center in direction (dx, dy), find intersection with polygon edges
    local best_t = math.huge
    local verts = self.vertices
    local n = #verts

    for i = 1, n do
        local v1 = verts[i]
        local v2 = verts[i % n + 1]

        -- Edge from v1 to v2 (scaled by radius)
        local x1, y1 = v1.x * radius, v1.y * radius
        local x2, y2 = v2.x * radius, v2.y * radius

        -- Ray-segment intersection
        local ex, ey = x2 - x1, y2 - y1
        local denom = dx * ey - dy * ex

        if math.abs(denom) > 0.0001 then
            local t = (x1 * ey - y1 * ex) / denom
            local s = (x1 * dy - y1 * dx) / denom

            if t > 0 and s >= 0 and s <= 1 then
                if t < best_t then
                    best_t = t
                end
            end
        end
    end

    if best_t == math.huge then best_t = radius end
    return self.x + dx * best_t, self.y + dy * best_t
end

-- Get random point on boundary (weighted by edge length)
function ArenaController:getRandomBoundaryPoint(radius)
    radius = radius or self:getEffectiveRadius()
    local verts = self.vertices
    local n = #verts

    -- Calculate edge lengths for weighted selection
    local lengths = {}
    local total_length = 0
    for i = 1, n do
        local v1 = verts[i]
        local v2 = verts[i % n + 1]
        local dx = (v2.x - v1.x) * radius
        local dy = (v2.y - v1.y) * radius
        local len = math.sqrt(dx * dx + dy * dy)
        lengths[i] = len
        total_length = total_length + len
    end

    -- Pick random edge weighted by length
    local r = math.random() * total_length
    local accum = 0
    local edge_idx = 1
    for i = 1, n do
        accum = accum + lengths[i]
        if r <= accum then
            edge_idx = i
            break
        end
    end

    -- Random position on selected edge
    local v1 = verts[edge_idx]
    local v2 = verts[edge_idx % n + 1]
    local t = math.random()
    local px = self.x + (v1.x + (v2.x - v1.x) * t) * radius
    local py = self.y + (v1.y + (v2.y - v1.y) * t) * radius

    -- Calculate outward normal angle
    local ex = (v2.x - v1.x)
    local ey = (v2.y - v1.y)
    local normal_angle = math.atan2(-ex, ey)  -- perpendicular, pointing outward

    return px, py, normal_angle
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
            sides = #self.vertices
        }
    else
        local margins = self:getShrinkMargins()
        return {
            x = margins.left + self.wall_offset_x,
            y = margins.top + self.wall_offset_y,
            width = self.current_width,
            height = self.current_height,
            sides = #self.vertices,
            -- Grid-specific bounds
            grid_width = self.grid_mode and math.floor(self.current_width / self.cell_size) or nil,
            grid_height = self.grid_mode and math.floor(self.current_height / self.cell_size) or nil
        }
    end
end

-- Check if a position is inside the arena (point-in-polygon)
-- margin: optional entity radius to shrink effective bounds (for edge collision)
function ArenaController:isInside(x, y, margin)
    margin = margin or 0

    if self.safe_zone_mode then
        -- Generic point-in-polygon using ray casting
        local dx = x - self.x
        local dy = y - self.y
        local effective_radius = self:getEffectiveRadius() - margin

        -- Scale point to normalized space
        local px = dx / effective_radius
        local py = dy / effective_radius

        -- Ray casting algorithm
        local inside = false
        local verts = self.vertices
        local n = #verts
        local j = n

        for i = 1, n do
            local xi, yi = verts[i].x, verts[i].y
            local xj, yj = verts[j].x, verts[j].y

            if ((yi > py) ~= (yj > py)) and
               (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
                inside = not inside
            end
            j = i
        end

        return inside
    end

    -- Non-safe-zone: axis-aligned bounds with moving walls
    local offset_x = self.wall_offset_x
    local offset_y = self.wall_offset_y
    local margins = self:getShrinkMargins()
    local min_x = margins.left + math.max(0, offset_x)
    local max_x = self.base_width - margins.right + math.min(0, offset_x)
    local min_y = margins.top + math.max(0, offset_y)
    local max_y = self.base_height - margins.bottom + math.min(0, offset_y)

    return x >= min_x and x <= max_x and y >= min_y and y <= max_y
end

-- Check if a grid position is inside (for grid-based games)
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
    self.ax = 0
    self.ay = 0
    self.shrink_timer = 0
    self.pulse_timer = 0
    self.pulse_offset = 0
    self.wall_offset_x = 0
    self.wall_offset_y = 0
    self.wall_move_timer = 0
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
        sides = #self.vertices,
        morph_type = self.morph_type,
        morph_timer = self.morph_timer,
        deformation_offset = self.deformation_offset,
        shrink_progress = self:getShrinkProgress(),
        wall_offset_x = self.wall_offset_x,
        wall_offset_y = self.wall_offset_y
    }
end

-- Draw arena boundary (generic polygon)
-- scale: pixels per unit (e.g., GRID_SIZE for grid-based games)
function ArenaController:drawBoundary(scale, color)
    scale = scale or 1
    color = color or {0.5, 0.5, 0.5, 0.8}

    love.graphics.setColor(color)
    love.graphics.setLineWidth(3)

    -- Build scaled vertices (scale applied to center and radius)
    local r = self:getEffectiveRadius() * scale
    local cx = self.x * scale
    local cy = self.y * scale
    local scaled = {}
    for _, v in ipairs(self.vertices) do
        table.insert(scaled, cx + v.x * r)
        table.insert(scaled, cy + v.y * r)
    end
    love.graphics.polygon("line", scaled)

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
                -- Polygon mode: check if outside shape
                outside = not self:isInsideGrid(x, y)
            else
                -- Axis-aligned mode: edge cells are walls, plus shrink margins
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

-- Clamp entity to stay inside arena bounds with optional bounce (generic polygon)
-- entity: {x, y, vx, vy, radius, bounce_damping}
function ArenaController:clampEntity(entity)
    if not self.safe_zone_mode then return end

    local ent_radius = entity.radius or 0
    local effective_radius = self:getEffectiveRadius() - ent_radius
    local bounce = entity.bounce_damping or 0

    -- Check if entity is inside
    if self:isInside(entity.x, entity.y, ent_radius) then
        return  -- Already inside, no clamping needed
    end

    -- Find closest edge and project onto it
    local dx = entity.x - self.x
    local dy = entity.y - self.y
    local verts = self.vertices
    local n = #verts

    local best_dist = math.huge
    local best_px, best_py = entity.x, entity.y
    local best_nx, best_ny = 0, 0

    for i = 1, n do
        local v1 = verts[i]
        local v2 = verts[i % n + 1]

        -- Edge scaled to effective radius
        local x1, y1 = self.x + v1.x * effective_radius, self.y + v1.y * effective_radius
        local x2, y2 = self.x + v2.x * effective_radius, self.y + v2.y * effective_radius

        -- Project point onto edge segment
        local ex, ey = x2 - x1, y2 - y1
        local edge_len_sq = ex * ex + ey * ey

        if edge_len_sq > 0.0001 then
            local t = math.max(0, math.min(1, ((entity.x - x1) * ex + (entity.y - y1) * ey) / edge_len_sq))
            local proj_x = x1 + t * ex
            local proj_y = y1 + t * ey

            local dist_sq = (entity.x - proj_x)^2 + (entity.y - proj_y)^2
            if dist_sq < best_dist then
                best_dist = dist_sq
                best_px, best_py = proj_x, proj_y

                -- Outward normal (perpendicular to edge, pointing outward from center)
                local nx, ny = -ey, ex
                local len = math.sqrt(nx * nx + ny * ny)
                if len > 0 then
                    nx, ny = nx / len, ny / len
                    -- Ensure normal points outward (away from center)
                    local mid_x, mid_y = (x1 + x2) / 2 - self.x, (y1 + y2) / 2 - self.y
                    if nx * mid_x + ny * mid_y < 0 then
                        nx, ny = -nx, -ny
                    end
                    best_nx, best_ny = nx, ny
                end
            end
        end
    end

    -- Clamp to closest edge point
    entity.x = best_px
    entity.y = best_py

    -- Apply bounce reflection
    if entity.vx and entity.vy and (best_nx ~= 0 or best_ny ~= 0) then
        local dot = entity.vx * best_nx + entity.vy * best_ny
        if dot > 0 then
            local factor = 1.0 + bounce
            entity.vx = entity.vx - best_nx * dot * factor
            entity.vy = entity.vy - best_ny * dot * factor
        end
    end
end

return ArenaController
