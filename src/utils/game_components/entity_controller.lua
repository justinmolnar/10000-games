--[[
EntityController - Phase 11: Generic enemy/obstacle spawning and management system

Handles:
- Entity type definitions with inheritance
- Spawning modes: wave, continuous, grid, manual
- Movement integration with MovementController
- Object pooling for performance
- Spatial partitioning for collision optimization
- Entity lifecycle callbacks (spawn, hit, death)

Usage:
    local EntityController = require('src.utils.game_components.entity_controller')

    self.entity_controller = EntityController:new({
        entity_types = {
            ["basic_obstacle"] = {
                health = 1,
                radius = 10,
                speed = 100,
                movement_type = "linear",
                on_hit = function(entity, by_what) ... end,
                on_death = function(entity) ... end,
                score_value = 10
            },
            ["brick"] = {
                health = 3,
                width = 32,
                height = 16,
                movement_type = "static",
                on_hit = function(brick, ball) ... end
            }
        },
        spawning = {
            mode = "continuous",  -- or "wave", "grid", "manual"
            rate = 2.0,  -- For continuous mode
            max_concurrent = 10
        },
        pooling = true,
        max_entities = 200
    })

    -- Update & collision checking:
    self.entity_controller:update(dt, game_state)
    self.entity_controller:checkCollision(player, function(entity)
        -- Handle collision
    end)

    -- Rendering:
    self.entity_controller:draw(function(entity)
        -- Custom draw logic per entity
    end)
]]

local Object = require('class')
local EntityController = Object:extend('EntityController')

-- Spawning modes
EntityController.SPAWN_MODES = {
    CONTINUOUS = "continuous",  -- Spawn at regular rate
    WAVE = "wave",              -- Spawn in waves
    GRID = "grid",              -- Spawn in grid layout (Breakout bricks)
    BURST = "burst",            -- Rapid bursts with pauses between
    MANUAL = "manual"           -- No auto-spawning, manual spawn() calls only
}

function EntityController:new(config)
    local instance = EntityController.super.new(self)

    -- Core configuration
    instance.entity_types = config.entity_types or {}
    instance.spawning = config.spawning or {mode = EntityController.SPAWN_MODES.MANUAL}
    instance.pooling = config.pooling ~= false  -- Default true
    instance.max_entities = config.max_entities or 200

    -- Active entities
    instance.entities = {}
    instance.entity_count = 0

    -- Object pool (if enabled)
    instance.entity_pool = {}

    -- Spawning state
    instance.spawn_timer = 0
    instance.spawn_rate = instance.spawning.rate or 1.0
    instance.max_concurrent = instance.spawning.max_concurrent or 10

    -- Grid spawning state (for Breakout-style games)
    instance.grid_spawned = false

    -- Wave spawning state
    instance.current_wave = 0
    instance.wave_complete = true

    -- Spatial partitioning (optional - for performance with many entities)
    instance.spatial_grid = nil
    instance.grid_cell_size = config.grid_cell_size or 64

    return instance
end

-- Load collision image for an entity type (for PNG-based collision detection)
-- Requires di.components.PNGCollision to be available
function EntityController:loadCollisionImage(type_name, image_path, alpha_threshold, di)
    local entity_type = self.entity_types[type_name]
    if not entity_type then return false end

    if di and di.components and di.components.PNGCollision then
        entity_type.collision_image = di.components.PNGCollision.loadCollisionImage(image_path)
    end

    local success, img = pcall(love.graphics.newImage, image_path)
    if success then entity_type.display_image = img end

    entity_type.alpha_threshold = alpha_threshold or 0.5
    return true
end

--[[
    Spawn a new entity of given type

    @param type_name string - Key from entity_types config
    @param x number
    @param y number
    @param custom_params table (optional) - Override default entity params
    @return table - The spawned entity
]]
function EntityController:spawn(type_name, x, y, custom_params)
    if self.entity_count >= self.max_entities then
        return nil  -- At capacity
    end

    local entity_type = self.entity_types[type_name]
    if not entity_type then
        error("Unknown entity type: " .. tostring(type_name))
    end

    -- Get entity from pool or create new
    local entity = nil
    if self.pooling and #self.entity_pool > 0 then
        entity = table.remove(self.entity_pool)
        -- CRITICAL: Clear all properties from pooled entity to prevent stale data
        -- (e.g., warning properties bleeding into obstacles)
        for k in pairs(entity) do
            entity[k] = nil
        end
    else
        entity = {}
    end

    -- Initialize entity with type defaults
    entity.type_name = type_name
    entity.x = x
    entity.y = y
    entity.active = true
    entity.marked_for_removal = false

    -- Copy type properties
    for k, v in pairs(entity_type) do
        if type(v) ~= "function" then
            entity[k] = v
        end
    end

    -- Apply custom overrides
    if custom_params then
        for k, v in pairs(custom_params) do
            entity[k] = v
        end
    end

    -- Initialize movement controller if entity has movement
    if entity.movement_type and entity.movement_type ~= "static" then
        -- Movement will be handled by game's MovementController or local velocity
        entity.vx = entity.vx or 0
        entity.vy = entity.vy or 0
        entity.angle = entity.angle or 0
    end

    -- Add to entities list
    table.insert(self.entities, entity)
    self.entity_count = self.entity_count + 1

    -- Call on_spawn callback if exists
    if entity_type.on_spawn then
        entity_type.on_spawn(entity)
    end

    return entity
end

--[[
    Spawn entities in a grid layout (Breakout bricks, puzzle games)

    @param type_name string
    @param rows number
    @param cols number
    @param x_offset number - Starting x position
    @param y_offset number - Starting y position
    @param spacing_x number - Horizontal spacing between entities
    @param spacing_y number - Vertical spacing between entities
]]
function EntityController:spawnGrid(type_name, rows, cols, x_offset, y_offset, spacing_x, spacing_y)
    local entity_type = self.entity_types[type_name]
    if not entity_type then
        error("Unknown entity type: " .. tostring(type_name))
    end

    local width = entity_type.width or (entity_type.radius and entity_type.radius * 2) or 32
    local height = entity_type.height or (entity_type.radius and entity_type.radius * 2) or 16

    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local x = x_offset + col * (width + spacing_x)
            local y = y_offset + row * (height + spacing_y)
            self:spawn(type_name, x, y)
        end
    end

    self.grid_spawned = true
end

--[[
    Spawn entities in a pyramid/triangle layout

    @param type_name string
    @param rows number
    @param max_cols number - Columns in first row (decreases each row)
    @param x_offset number
    @param y_offset number
    @param spacing_x number
    @param spacing_y number
    @param arena_width number - For centering
]]
function EntityController:spawnPyramid(type_name, rows, max_cols, x_offset, y_offset, spacing_x, spacing_y, arena_width)
    local entity_type = self.entity_types[type_name]
    if not entity_type then return end

    local width = entity_type.width or (entity_type.radius and entity_type.radius * 2) or 32
    local height = entity_type.height or (entity_type.radius and entity_type.radius * 2) or 16

    for row = 0, rows - 1 do
        local cols_this_row = max_cols - row
        if cols_this_row < 1 then break end

        local total_width = cols_this_row * (width + spacing_x)
        local start_x = (arena_width - total_width) / 2

        for col = 0, cols_this_row - 1 do
            local x = start_x + col * (width + spacing_x)
            local y = y_offset + row * (height + spacing_y)
            self:spawn(type_name, x, y)
        end
    end
end

--[[
    Spawn entities in concentric circles

    @param type_name string
    @param rings number
    @param center_x number
    @param center_y number
    @param base_count number - Entities in innermost ring
    @param ring_spacing number - Distance between rings
]]
function EntityController:spawnCircle(type_name, rings, center_x, center_y, base_count, ring_spacing)
    base_count = base_count or 12
    ring_spacing = ring_spacing or 40

    for ring = 1, rings do
        local radius = ring * ring_spacing
        local count = base_count + (ring - 1) * 2

        for i = 1, count do
            local angle = (i / count) * math.pi * 2
            local x = center_x + math.cos(angle) * radius
            local y = center_y + math.sin(angle) * radius
            self:spawn(type_name, x, y)
        end
    end
end

--[[
    Spawn entities in random positions (with optional overlap checking)

    @param type_name string
    @param count number
    @param bounds table - {x, y, width, height}
    @param rng RandomGenerator
    @param allow_overlap boolean (default false)
]]
function EntityController:spawnRandom(type_name, count, bounds, rng, allow_overlap)
    local entity_type = self.entity_types[type_name]
    if not entity_type then return end

    local width = entity_type.width or (entity_type.radius and entity_type.radius * 2) or 32
    local height = entity_type.height or (entity_type.radius and entity_type.radius * 2) or 16
    local max_attempts = count * 10
    local placed = 0

    for _ = 1, max_attempts do
        if placed >= count then break end

        local x = bounds.x + rng:random() * (bounds.width - width)
        local y = bounds.y + rng:random() * (bounds.height - height)

        local can_place = true
        if not allow_overlap then
            for _, entity in ipairs(self.entities) do
                if entity.active then
                    local overlap = x < entity.x + (entity.width or 0) and
                                   x + width > entity.x and
                                   y < entity.y + (entity.height or 0) and
                                   y + height > entity.y
                    if overlap then
                        can_place = false
                        break
                    end
                end
            end
        end

        if can_place then
            self:spawn(type_name, x, y)
            placed = placed + 1
        end
    end
end

--[[
    Spawn entities in deterministic hash-based positions (scatter pattern)
    Positions are reproducible given the same parameters.

    @param type_name string
    @param count number - Number of entities to spawn
    @param config table:
        - bounds: {x, y, width, height}
        - padding: number (default from entity size)
        - hash_x1, hash_x2, hash_y1, hash_y2: hash constants for positioning
        - extra_fn: function(i) returns extra fields for entity i
]]
function EntityController:spawnScatter(type_name, count, config)
    local entity_type = self.entity_types[type_name]
    if not entity_type then return end

    config = config or {}
    local bounds = config.bounds or {x = 0, y = 0, width = 800, height = 600}
    local size = entity_type.size or entity_type.width or (entity_type.radius and entity_type.radius * 2) or 20
    local padding = config.padding or size

    local hash_x1 = config.hash_x1 or 17
    local hash_x2 = config.hash_x2 or 47
    local hash_y1 = config.hash_y1 or 23
    local hash_y2 = config.hash_y2 or 53

    for i = 1, count do
        local hx = (i * hash_x1) % hash_x2
        local hy = (i * hash_y1) % hash_y2
        local x = bounds.x + padding + (hx / hash_x2) * (bounds.width - 2 * padding)
        local y = bounds.y + padding + (hy / hash_y2) * (bounds.height - 2 * padding)

        local extra = config.extra_fn and config.extra_fn(i) or {id = i}
        self:spawn(type_name, x, y, extra)
    end
end

-- Spawn multiple entities using a spawner function
function EntityController:spawnMultiple(count, spawner_fn)
    for _ = 1, count do
        spawner_fn()
    end
end

function EntityController:spawnAtCells(type_name, cells, is_valid_fn)
    for _, cell in ipairs(cells) do
        if not is_valid_fn or is_valid_fn(cell.x, cell.y) then
            self:spawn(type_name, cell.x, cell.y)
        end
    end
end

--[[
    Spawn entity near an existing entity (cluster spawning)

    @param type_name string - Entity type to spawn
    @param ref_entity table - Reference entity to spawn near (or nil to pick random existing)
    @param radius number - Max distance from reference (default 3)
    @param bounds table - {min_x, max_x, min_y, max_y} to clamp position
    @param is_valid_fn function(x, y) - Optional validation function
    @param custom_params table - Optional params to pass to spawn
    @return entity or nil
]]
function EntityController:spawnCluster(type_name, ref_entity, radius, bounds, is_valid_fn, custom_params)
    radius = radius or 3

    -- If no reference provided, pick random existing entity of same type
    if not ref_entity then
        local existing = self:getEntitiesByType(type_name)
        if #existing == 0 then return nil end
        ref_entity = existing[math.random(#existing)]
    end

    local max_attempts = 50
    for _ = 1, max_attempts do
        local offset_x = math.random(-radius, radius)
        local offset_y = math.random(-radius, radius)
        local x = ref_entity.x + offset_x
        local y = ref_entity.y + offset_y

        -- Clamp to bounds if provided
        if bounds then
            x = math.max(bounds.min_x or 0, math.min(bounds.max_x or 9999, x))
            y = math.max(bounds.min_y or 0, math.min(bounds.max_y or 9999, y))
        end

        -- Check validation function
        local valid = true
        if is_valid_fn then
            valid = is_valid_fn(x, y)
        end

        if valid then
            return self:spawn(type_name, x, y, custom_params)
        end
    end

    return nil
end

-- Spawn pattern functions: each returns x, y given bounds, config, and state
EntityController.SPAWN_PATTERNS = {
    random = function(bounds)
        if bounds.is_grid then
            return math.random(bounds.min_x, bounds.max_x), math.random(bounds.min_y, bounds.max_y)
        end
        return bounds.min_x + math.random() * (bounds.max_x - bounds.min_x),
               bounds.min_y + math.random() * (bounds.max_y - bounds.min_y)
    end,

    cluster = function(bounds, config, state, controller)
        local ref = config.ref_entity
        if not ref then
            local existing = controller:getEntitiesByCategory(config.category)
            if #existing > 0 then ref = existing[math.random(#existing)] end
        end
        if not ref then return EntityController.SPAWN_PATTERNS.random(bounds) end
        local r = config.radius or 3
        return ref.x + math.random(-r, r), ref.y + math.random(-r, r)
    end,

    line = function(bounds, config)
        local pos = config.position or math.floor((bounds.min_y + bounds.max_y) / 2)
        local variance = config.variance or 2
        if config.axis == "x" then
            return pos + math.random(-variance, variance), math.random(bounds.min_y, bounds.max_y)
        end
        return math.random(bounds.min_x, bounds.max_x), pos + math.random(-variance, variance)
    end,

    spiral = function(bounds, config, state)
        state.spiral = state.spiral or {angle = 0, radius = 2, expanding = true}
        local s = state.spiral
        local cx = config.center_x or (bounds.min_x + bounds.max_x) / 2
        local cy = config.center_y or (bounds.min_y + bounds.max_y) / 2
        local min_r, max_r = config.min_radius or 2, config.max_radius or math.min(bounds.max_x - bounds.min_x, bounds.max_y - bounds.min_y) * 0.4
        s.angle = s.angle + 0.5
        s.radius = s.radius + (s.expanding and 0.5 or -0.5)
        if s.radius >= max_r then s.expanding = false elseif s.radius <= min_r then s.expanding = true end
        return math.floor(cx + math.cos(s.angle) * s.radius), math.floor(cy + math.sin(s.angle) * s.radius)
    end,
}

function EntityController:spawnWithPattern(type_name, pattern, config, custom_params)
    config = config or {}
    local bounds = config.bounds or {min_x = 0, max_x = 100, min_y = 0, max_y = 100}
    local pattern_fn = EntityController.SPAWN_PATTERNS[pattern] or EntityController.SPAWN_PATTERNS.random
    self.pattern_state = self.pattern_state or {}

    for _ = 1, config.max_attempts or 50 do
        local x, y = pattern_fn(bounds, config, self.pattern_state, self)
        x = math.max(bounds.min_x, math.min(bounds.max_x, x))
        y = math.max(bounds.min_y, math.min(bounds.max_y, y))
        if not config.is_valid_fn or config.is_valid_fn(x, y) then
            return self:spawn(type_name, x, y, custom_params)
        end
    end
    return nil
end

--[[
    Spawn entity in a region with optional direction facing

    @param type_name string
    @param config table - Spawn configuration (see calculateSpawnPosition)
    @param custom_params table - Optional params to pass to spawn
    @return entity, direction - spawned entity and calculated direction
]]
function EntityController:spawnInRegion(type_name, config, custom_params)
    local x, y, direction = self:calculateSpawnPosition(config)

    local entity = self:spawn(type_name, x, y, custom_params)
    if entity then
        entity.spawn_direction = direction
    end

    return entity, direction
end

--[[
    Calculate spawn position without creating an entity
    Same logic as spawnInRegion but returns x, y, direction instead of spawning

    @param config table - Same as spawnInRegion config
    @return x, y, direction
]]
function EntityController:calculateSpawnPosition(config)
    config = config or {}
    local bounds = config.bounds or {min_x = 0, max_x = 100, min_y = 0, max_y = 100}
    local center = config.center or {x = (bounds.min_x + bounds.max_x) / 2, y = (bounds.min_y + bounds.max_y) / 2}
    local region = config.region or "random"
    local index = config.index or 1
    local spacing = config.spacing or 3

    local x, y

    if region == "center" then
        x = center.x + (index - 1) * spacing
        y = center.y
    elseif region == "edge" then
        local margin = config.margin or 0
        if config.angle then
            local dist = math.max(bounds.max_x - bounds.min_x, bounds.max_y - bounds.min_y)
            x = center.x + math.cos(config.angle) * dist
            y = center.y + math.sin(config.angle) * dist
            if x < bounds.min_x then x = bounds.min_x - margin end
            if x > bounds.max_x then x = bounds.max_x + margin end
            if y < bounds.min_y then y = bounds.min_y - margin end
            if y > bounds.max_y then y = bounds.max_y + margin end
        else
            local edge_side = math.random(4)
            if edge_side == 1 then x = bounds.min_x - margin; y = bounds.min_y + math.random() * (bounds.max_y - bounds.min_y)
            elseif edge_side == 2 then x = bounds.max_x + margin; y = bounds.min_y + math.random() * (bounds.max_y - bounds.min_y)
            elseif edge_side == 3 then x = bounds.min_x + math.random() * (bounds.max_x - bounds.min_x); y = bounds.min_y - margin
            else x = bounds.min_x + math.random() * (bounds.max_x - bounds.min_x); y = bounds.max_y + margin end
        end
    else
        local min_dist = config.min_distance_from_center or 0
        local max_attempts = config.max_attempts or 200

        for _ = 1, max_attempts do
            if bounds.is_grid then
                x = math.random(bounds.min_x, bounds.max_x)
                y = math.random(bounds.min_y, bounds.max_y)
            else
                x = bounds.min_x + math.random() * (bounds.max_x - bounds.min_x)
                y = bounds.min_y + math.random() * (bounds.max_y - bounds.min_y)
            end

            local valid = true
            if min_dist > 0 then
                local dist = math.abs(x - center.x) + math.abs(y - center.y)
                if dist < min_dist then valid = false end
            end
            if valid and config.is_valid_fn then
                valid = config.is_valid_fn(x, y)
            end
            if valid then break end
            x, y = nil, nil
        end

        if not x then
            x = center.x + (index * 2)
            y = center.y
        end
    end

    local direction = self:calculateSpawnDirection(config.direction, x, y, center, config.fixed_direction)
    return x, y, direction
end

--[[
    Calculate spawn direction based on mode

    @param mode string|table - "toward_center", "from_center", "fixed", or {x, y}
    @param x, y number - entity position
    @param center table - {x, y} center point
    @param fixed_direction table - {x, y} for "fixed" mode
    @return table - {x, y} direction vector
]]
function EntityController:calculateSpawnDirection(mode, x, y, center, fixed_direction)
    if type(mode) == "table" then
        return {x = mode.x or 0, y = mode.y or 0}
    end

    if mode == "toward_center" then
        local dx, dy = center.x - x, center.y - y
        if dx == 0 and dy == 0 then
            return fixed_direction or {x = 1, y = 0}
        elseif math.abs(dx) > math.abs(dy) then
            return {x = dx > 0 and 1 or -1, y = 0}
        else
            return {x = 0, y = dy > 0 and 1 or -1}
        end
    elseif mode == "from_center" then
        local dx, dy = x - center.x, y - center.y
        if dx == 0 and dy == 0 then
            return fixed_direction or {x = 1, y = 0}
        elseif math.abs(dx) > math.abs(dy) then
            return {x = dx > 0 and 1 or -1, y = 0}
        else
            return {x = 0, y = dy > 0 and 1 or -1}
        end
    end

    -- Default: use fixed_direction or right
    return fixed_direction or {x = 1, y = 0}
end

function EntityController:ensureInboundAngle(x, y, angle, bounds)
    local vx, vy = math.cos(angle), math.sin(angle)
    if x <= bounds.min_x then
        if vx <= 0 then angle = math.atan2(vy, math.abs(vx)) end
    elseif x >= bounds.max_x then
        if vx >= 0 then angle = math.atan2(vy, -math.abs(vx)) end
    elseif y <= bounds.min_y then
        if vy <= 0 then angle = math.atan2(math.abs(vy), vx) end
    elseif y >= bounds.max_y then
        if vy >= 0 then angle = math.atan2(-math.abs(vy), vx) end
    end
    return angle
end

--[[
    Spawn entity with min_distance_from constraint

    @param type_name string
    @param bounds table - {min_x, max_x, min_y, max_y}
    @param constraints table - {min_distance_from = {x, y, distance}, is_valid_fn = function}
    @param custom_params table - Optional params to pass to spawn
    @return entity or nil
]]
function EntityController:spawnWithConstraints(type_name, bounds, constraints, custom_params)
    constraints = constraints or {}
    local max_attempts = constraints.max_attempts or 100
    local is_grid = bounds.is_grid

    for _ = 1, max_attempts do
        local x, y
        if is_grid then
            x = math.random(bounds.min_x, bounds.max_x)
            y = math.random(bounds.min_y, bounds.max_y)
        else
            x = bounds.min_x + math.random() * (bounds.max_x - bounds.min_x)
            y = bounds.min_y + math.random() * (bounds.max_y - bounds.min_y)
        end

        local valid = true

        -- Check min_distance_from constraint
        if constraints.min_distance_from and valid then
            local mdf = constraints.min_distance_from
            local dx = x - mdf.x
            local dy = y - mdf.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < mdf.distance then
                valid = false
            end
        end

        -- Check custom validation function
        if constraints.is_valid_fn and valid then
            valid = constraints.is_valid_fn(x, y)
        end

        if valid then
            return self:spawn(type_name, x, y, custom_params)
        end
    end

    return nil
end

--[[
    Spawn entities in a checkerboard pattern

    @param type_name string
    @param rows number
    @param cols number
    @param x_offset number
    @param y_offset number
    @param spacing_x number
    @param spacing_y number
]]
function EntityController:spawnCheckerboard(type_name, rows, cols, x_offset, y_offset, spacing_x, spacing_y)
    local entity_type = self.entity_types[type_name]
    if not entity_type then return end

    local width = entity_type.width or (entity_type.radius and entity_type.radius * 2) or 32
    local height = entity_type.height or (entity_type.radius and entity_type.radius * 2) or 16

    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            if (row + col) % 2 == 0 then
                local x = x_offset + col * (width + spacing_x)
                local y = y_offset + row * (height + spacing_y)
                self:spawn(type_name, x, y)
            end
        end
    end
end

--[[
    Spawn entities using a named layout pattern
    Dispatches to spawnGrid, spawnPyramid, spawnCircle, spawnRandom, or spawnCheckerboard

    @param type_name string - Entity type to spawn
    @param layout string - "grid", "pyramid", "circle", "random", "checkerboard"
    @param config table - Layout configuration:
        - rows, cols: Grid dimensions
        - x, y: Starting position offset
        - spacing_x, spacing_y: Spacing between entities
        - arena_width: For centering (pyramid)
        - bounds: {x, y, width, height} for random spawning
        - rng: Random generator for random spawning
        - can_overlap: Allow overlapping (random)
        - center_x, center_y: Center point (circle)
        - base_count, ring_spacing: Circle parameters
]]

--[[
    Calculate grid layout dimensions for fitting items in a container.
    Pure calculation - does not spawn anything.

    @param config table:
        - cols: number of columns
        - rows: number of rows
        - container_width: available width
        - container_height: available height
        - item_width: base item width (before scaling)
        - item_height: base item height (before scaling)
        - spacing: gap between items (default 10)
        - padding: margin around grid (default 10)
        - reserved_top: space reserved at top for HUD (default 0)

    @return table: {cols, rows, item_width, item_height, start_x, start_y, scale}
]]
function EntityController:calculateGridLayout(config)
    local cols = config.cols or 4
    local rows = config.rows or 4
    local container_w = config.container_width or 800
    local container_h = config.container_height or 600
    local base_w = config.item_width or 60
    local base_h = config.item_height or 80
    local spacing = config.spacing or 10
    local padding = config.padding or 10
    local reserved_top = config.reserved_top or 0

    -- Available space after padding and reserved areas
    local available_w = container_w - (padding * 2)
    local available_h = container_h - reserved_top - (padding * 2)

    -- Space taken by gaps between items
    local total_spacing_w = spacing * (cols - 1)
    local total_spacing_h = spacing * (rows - 1)

    -- Max item size that would fit
    local max_item_w = (available_w - total_spacing_w) / cols
    local max_item_h = (available_h - total_spacing_h) / rows

    -- Scale to fit while maintaining aspect ratio
    local scale = math.min(max_item_w / base_w, max_item_h / base_h)
    local item_w = base_w * scale
    local item_h = base_h * scale

    -- Total grid size
    local grid_w = (item_w + spacing) * cols - spacing
    local grid_h = (item_h + spacing) * rows - spacing

    -- Center horizontally, position below reserved area
    local start_x = (container_w - grid_w) / 2
    local start_y
    if grid_h <= available_h then
        start_y = reserved_top + padding + (available_h - grid_h) / 2
    else
        start_y = reserved_top + padding
    end

    return {
        cols = cols,
        rows = rows,
        item_width = item_w,
        item_height = item_h,
        start_x = start_x,
        start_y = start_y,
        scale = scale,
        spacing = spacing
    }
end

--[[
    Get entity at a specific point (hit testing)

    @param x number - X coordinate to test
    @param y number - Y coordinate to test
    @param type_name string|nil - Optional type filter
    @return entity|nil - First entity at point, or nil
]]
function EntityController:getEntityAtPoint(x, y, type_name)
    for _, entity in ipairs(self.entities) do
        if entity.active and (not type_name or entity.type_name == type_name) then
            local ex, ey = entity.x, entity.y
            local ew = entity.width or (entity.radius and entity.radius * 2) or 0
            local eh = entity.height or (entity.radius and entity.radius * 2) or 0

            if entity.radius then
                -- Circle hit test (centered = x,y is center, else x,y is top-left)
                local cx, cy = entity.centered and ex or (ex + entity.radius), entity.centered and ey or (ey + entity.radius)
                local dx, dy = x - cx, y - cy
                if dx * dx + dy * dy <= entity.radius * entity.radius then
                    return entity
                end
            else
                -- Rectangle hit test
                if x >= ex and x <= ex + ew and y >= ey and y <= ey + eh then
                    return entity
                end
            end
        end
    end
    return nil
end

--[[
    Reposition entities based on their grid_index

    @param type_name string - Entity type to reposition
    @param layout table - {start_x, start_y, cols, item_width, item_height, spacing}
]]
function EntityController:repositionGridEntities(type_name, layout)
    local start_x = layout.start_x or 0
    local start_y = layout.start_y or 0
    local cols = layout.cols or 4
    local item_w = layout.item_width or 60
    local item_h = layout.item_height or 80
    local spacing = layout.spacing or 10

    for _, entity in ipairs(self.entities) do
        if entity.active and entity.type_name == type_name and entity.grid_index then
            local row = math.floor(entity.grid_index / cols)
            local col = entity.grid_index % cols
            entity.x = start_x + col * (item_w + spacing)
            entity.y = start_y + row * (item_h + spacing)
        end
    end
end

--[[
    Shuffle grid_index values among entities of a given type (Fisher-Yates)

    @param type_name string - Entity type to shuffle
]]
function EntityController:shuffleGridIndices(type_name)
    -- Collect entities with grid_index
    local entities_with_index = {}
    for _, entity in ipairs(self.entities) do
        if entity.active and entity.type_name == type_name and entity.grid_index then
            table.insert(entities_with_index, entity)
        end
    end

    if #entities_with_index < 2 then return end

    -- Collect all grid_index values
    local indices = {}
    for _, entity in ipairs(entities_with_index) do
        table.insert(indices, entity.grid_index)
    end

    -- Fisher-Yates shuffle on indices
    for i = #indices, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    -- Reassign shuffled indices to entities
    for i, entity in ipairs(entities_with_index) do
        entity.grid_index = indices[i]
    end
end

--[[
    Get entities matching a filter function

    @param filter_fn function(entity) -> boolean
    @return table - Array of matching entities
]]
--[[
    Start animated grid shuffle

    @param entities table - Array of entities to shuffle (game filters these)
    @param count number - How many to shuffle (0 = all)
    @param layout table - {start_x, start_y, cols, item_width, item_height, spacing}
    @param duration number - Animation duration in seconds
]]
function EntityController:animateGridShuffle(entities, count, layout, duration)
    if #entities < 2 then return end

    -- Limit to count if specified
    local to_shuffle = entities
    if count > 0 and count < #entities then
        to_shuffle = {}
        local available = {unpack(entities)}
        for i = 1, count do
            local pick = math.random(#available)
            table.insert(to_shuffle, available[pick])
            table.remove(available, pick)
        end
    end

    if #to_shuffle < 2 then return end

    -- Store start positions for all entities being shuffled
    self.grid_shuffle = {
        start_positions = {},
        duration = duration,
        timer = 0,
        layout = layout
    }

    local cols = layout.cols or 4
    local start_x = layout.start_x or 0
    local start_y = layout.start_y or 0
    local item_w = layout.item_width or 60
    local item_h = layout.item_height or 80
    local spacing = layout.spacing or 10

    for _, entity in ipairs(to_shuffle) do
        local row = math.floor(entity.grid_index / cols)
        local col = entity.grid_index % cols
        self.grid_shuffle.start_positions[entity] = {
            x = start_x + col * (item_w + spacing),
            y = start_y + row * (item_h + spacing)
        }
    end

    -- Shuffle grid_index values among selected entities
    local indices = {}
    for _, entity in ipairs(to_shuffle) do
        table.insert(indices, entity.grid_index)
    end
    for i = #indices, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    for i, entity in ipairs(to_shuffle) do
        entity.grid_index = indices[i]
    end
end

--[[
    Update grid shuffle animation

    @param dt number - Delta time
    @return boolean - True if shuffle just completed
]]
function EntityController:updateGridShuffle(dt)
    if not self.grid_shuffle then return false end

    self.grid_shuffle.timer = self.grid_shuffle.timer + dt
    if self.grid_shuffle.timer >= self.grid_shuffle.duration then
        return true
    end
    return false
end

--[[
    Check if grid shuffle is active
]]
function EntityController:isGridShuffling()
    return self.grid_shuffle ~= nil
end

--[[
    Get shuffle animation progress (0-1)
]]
function EntityController:getShuffleProgress()
    if not self.grid_shuffle then return 1 end
    return math.min(1, self.grid_shuffle.timer / self.grid_shuffle.duration)
end

--[[
    Get shuffle start position for an entity (for animation interpolation)
]]
function EntityController:getShuffleStartPosition(entity)
    if not self.grid_shuffle or not self.grid_shuffle.start_positions then return nil end
    return self.grid_shuffle.start_positions[entity]
end

--[[
    Complete grid shuffle - finalize positions and clear state
]]
function EntityController:completeGridShuffle()
    if not self.grid_shuffle then return end

    local layout = self.grid_shuffle.layout
    if layout then
        local cols = layout.cols or 4
        local start_x = layout.start_x or 0
        local start_y = layout.start_y or 0
        local item_w = layout.item_width or 60
        local item_h = layout.item_height or 80
        local spacing = layout.spacing or 10

        -- Update positions for entities that were shuffled
        for entity, _ in pairs(self.grid_shuffle.start_positions) do
            local row = math.floor(entity.grid_index / cols)
            local col = entity.grid_index % cols
            entity.x = start_x + col * (item_w + spacing)
            entity.y = start_y + row * (item_h + spacing)
        end
    end

    self.grid_shuffle = nil
end

function EntityController:spawnLayout(type_name, layout, config)
    config = config or {}
    local rows = config.rows or 5
    local cols = config.cols or 10
    local start_x = config.x or 0
    local start_y = config.y or 60
    local spacing_x = config.spacing_x or 2
    local spacing_y = config.spacing_y or 2

    if layout == "pyramid" then
        self:spawnPyramid(type_name, rows, cols, start_x, start_y, spacing_x, spacing_y, config.arena_width or 800)
    elseif layout == "circle" then
        self:spawnCircle(type_name, rows, config.center_x or 400, config.center_y or 200, config.base_count or 12, config.ring_spacing or 40)
    elseif layout == "random" then
        local bounds = config.bounds or {x = 40, y = 40, width = 720, height = 200}
        self:spawnRandom(type_name, rows * cols, bounds, config.rng, config.can_overlap or false)
    elseif layout == "checkerboard" then
        self:spawnCheckerboard(type_name, rows, cols, start_x, start_y, spacing_x, spacing_y)
    elseif layout == "v_shape" then
        local count = config.count or 5
        local center_x = config.center_x or 400
        local y = config.y or 0
        local spacing = config.spacing_x or 60
        for i = 1, count do
            local offset = (i - math.ceil(count / 2)) * spacing
            local y_offset = math.abs(offset) * 0.5
            self:spawn(type_name, center_x + offset, y - y_offset, config.extra)
        end
    elseif layout == "line" then
        local count = config.count or 6
        local x = config.x or 0
        local y = config.y or 0
        local spacing = config.spacing_x or 100
        for i = 1, count do
            self:spawn(type_name, x + (i - 1) * spacing, y, config.extra)
        end
    elseif layout == "spiral" then
        local count = config.count or 8
        local center_x = config.center_x or 400
        local center_y = config.center_y or 100
        local radius = config.radius or 100
        for i = 1, count do
            local angle = (i / count) * math.pi * 2
            self:spawn(type_name, center_x + math.cos(angle) * radius, center_y + math.sin(angle) * radius * 0.3, config.extra)
        end
    elseif layout == "scatter" then
        self:spawnScatter(type_name, config.count or (rows * cols), config)
    else -- "grid" is default
        for row = 1, rows do
            for col = 1, cols do
                local x = start_x + (col - 1) * spacing_x
                local y = start_y + (row - 1) * spacing_y
                local extra = {}
                if config.extra then
                    for k, v in pairs(config.extra) do extra[k] = v end
                end
                extra.grid_row = row
                extra.grid_col = col
                self:spawn(type_name, x, y, extra)
            end
        end
    end
end

--[[
    Spawn entity using weighted random selection from configs

    @param type_name string - Entity type to spawn
    @param weighted_configs table - Array of {weight, ...properties}
    @param x number - Spawn X position
    @param y number - Spawn Y position
    @param base_extra table - Base properties merged into chosen config
]]
function EntityController:spawnWeighted(type_name, weighted_configs, x, y, base_extra)
    local total = 0
    for _, cfg in ipairs(weighted_configs) do total = total + (cfg.weight or 1) end

    local r = math.random() * total
    local chosen = weighted_configs[1]
    for _, cfg in ipairs(weighted_configs) do
        r = r - (cfg.weight or 1)
        if r <= 0 then chosen = cfg; break end
    end

    local extra = {}
    for k, v in pairs(base_extra or {}) do extra[k] = v end
    for k, v in pairs(chosen) do if k ~= "weight" then extra[k] = v end end

    return self:spawn(type_name, x, y, extra)
end

--[[
    Pick a type name from weighted configs with optional time-based growth.
    Configs: array of {name = "type_name", weight = N} or {name = "type_name", weight = {base = N, growth = N}}
    Time: elapsed time for growth calculation (nil = no growth)
]]
function EntityController:pickWeightedType(configs, time)
    time = time or 0
    local function getWeight(cfg)
        local w = cfg.weight
        if type(w) == "table" then
            return (w.base or 0) + time * (w.growth or 0)
        end
        return w or 1
    end
    local total = 0
    for _, cfg in ipairs(configs) do total = total + getWeight(cfg) end
    if total <= 0 then return configs[1].name end
    local r = math.random() * total
    for _, cfg in ipairs(configs) do
        r = r - getWeight(cfg)
        if r <= 0 then return cfg.name end
    end
    return configs[1].name
end

--[[
    Resolve spawn position using named patterns.
    Returns sx, sy, angle or nil if pattern handled spawning internally (e.g., clusters).

    Spawning config fields:
      position_pattern: "random_edge", "spiral", "boundary", "clusters"
      position_config: {margin, bounds, angle_step, get_boundary_point, cluster_min, cluster_max}
]]
function EntityController:resolveSpawnPosition(config)
    local pp = config.position_pattern or "random_edge"
    local pc = config.position_config or {}
    local margin = pc.margin or 0
    local bounds = pc.bounds or {min_x = 0, max_x = 800, min_y = 0, max_y = 600}

    if pp == "spiral" then
        self.spawn_position_state = self.spawn_position_state or {spiral_angle = 0}
        local sx, sy = self:calculateSpawnPosition({region = "edge", angle = self.spawn_position_state.spiral_angle, margin = margin, bounds = bounds})
        self.spawn_position_state.spiral_angle = self.spawn_position_state.spiral_angle + (pc.angle_step or math.rad(30))
        return sx, sy

    elseif pp == "boundary" then
        if pc.get_boundary_point then
            return pc.get_boundary_point()
        end
        local sx, sy = self:calculateSpawnPosition({region = "edge", margin = margin, bounds = bounds})
        return sx, sy

    elseif pp == "clusters" then
        local count = math.random(pc.cluster_min or 2, pc.cluster_max or 4)
        for _ = 1, count do
            local sx, sy = self:calculateSpawnPosition({region = "edge", margin = margin, bounds = bounds})
            if config.spawn_func then
                config.spawn_func(self, sx, sy, nil)
            end
        end
        return nil  -- already handled

    else -- "random_edge"
        local sx, sy = self:calculateSpawnPosition({region = "edge", margin = margin, bounds = bounds})
        return sx, sy
    end
end

--[[
    Burst spawning mode - rapid bursts with pauses between.
    Config: burst_count, burst_interval (between spawns), burst_pause (between bursts)
]]
function EntityController:updateBurstSpawning(dt, game_state)
    if not self.burst_state then
        self.burst_state = {bursting = false, timer = 0, spawned = 0}
    end
    local bs = self.burst_state

    if bs.bursting then
        bs.timer = bs.timer + dt
        if bs.timer >= (self.spawning.burst_interval or 0.15) then
            bs.timer = 0
            if self.spawning.position_pattern and self.spawning.spawn_func then
                local sx, sy, angle = self:resolveSpawnPosition(self.spawning)
                if sx then
                    self.spawning.spawn_func(self, sx, sy, angle)
                end
            elseif self.spawning.spawn_func then
                self.spawning.spawn_func(self, game_state)
            end
            bs.spawned = bs.spawned + 1
            if bs.spawned >= (self.spawning.burst_count or 6) then
                bs.bursting = false
                bs.spawned = 0
                bs.timer = 0
            end
        end
    else
        bs.timer = bs.timer + dt
        if bs.timer >= (self.spawning.burst_pause or 2.5) then
            bs.timer = 0
            bs.bursting = true
        end
    end
end

-- Tick entity timer - returns true when interval reached
function EntityController:tickTimer(entity, field, speed, dt)
    entity[field] = (entity[field] or 0) + dt
    local interval = 1 / speed
    if entity[field] >= interval then
        entity[field] = entity[field] - interval
        return true
    end
    return false
end

--[[
    Update all entities (movement, timers, spawning logic)
]]
function EntityController:update(dt, game_state)
    -- Handle spawning based on mode
    if self.spawning.mode == EntityController.SPAWN_MODES.CONTINUOUS then
        self:updateContinuousSpawning(dt, game_state)
    elseif self.spawning.mode == EntityController.SPAWN_MODES.WAVE then
        self:updateWaveSpawning(dt, game_state)
    elseif self.spawning.mode == EntityController.SPAWN_MODES.BURST then
        self:updateBurstSpawning(dt, game_state)
    elseif self.spawning.mode == EntityController.SPAWN_MODES.GRID and not self.grid_spawned then
        -- Grid spawns once at start
        if self.spawning.grid_config then
            local cfg = self.spawning.grid_config
            self:spawnGrid(
                cfg.type_name,
                cfg.rows,
                cfg.cols,
                cfg.x_offset or 0,
                cfg.y_offset or 0,
                cfg.spacing_x or 2,
                cfg.spacing_y or 2
            )
        end
    end

    -- Update all active entities
    for i = #self.entities, 1, -1 do
        local entity = self.entities[i]

        if entity.active and not entity.marked_for_removal then
            -- Update entity-specific logic
            if entity.update then
                entity.update(entity, dt, game_state)
            end

            -- Update basic movement (if linear)
            if entity.movement_type == "linear" then
                entity.x = entity.x + (entity.vx or 0) * dt
                entity.y = entity.y + (entity.vy or 0) * dt
            end

            -- Update timers
            if entity.lifetime then
                entity.lifetime = entity.lifetime - dt
                if entity.lifetime <= 0 then
                    self:removeEntity(entity)
                end
            end
        end

        -- Remove marked entities (use stored removal_reason if set)
        if entity.marked_for_removal then
            self:removeEntity(entity, entity.removal_reason)
        end
    end
end

--[[
    Continuous spawning mode - spawn entities at regular rate
]]
function EntityController:updateContinuousSpawning(dt, game_state)
    self.spawn_timer = self.spawn_timer + dt

    local active_count = self:getActiveCount()

    if self.spawn_timer >= self.spawn_rate and active_count < self.max_concurrent then
        self.spawn_timer = 0

        if self.spawning.position_pattern and self.spawning.spawn_func then
            local sx, sy, angle = self:resolveSpawnPosition(self.spawning)
            if sx then
                self.spawning.spawn_func(self, sx, sy, angle)
            end
        elseif self.spawning.spawn_func then
            self.spawning.spawn_func(self, game_state)
        end
    end
end

--[[
    Wave spawning mode - spawn entities in waves
]]
function EntityController:updateWaveSpawning(dt, game_state)
    if self.wave_complete and self:getActiveCount() == 0 then
        -- Start next wave
        self.current_wave = self.current_wave + 1

        if self.spawning.wave_func then
            self.spawning.wave_func(self, self.current_wave, game_state)
            self.wave_complete = false
        end
    end

    -- Check if wave is complete
    if not self.wave_complete and self:getActiveCount() == 0 then
        self.wave_complete = true
    end
end

--[[
    Check collision between a point/circle and all entities

    @param obj table - Object with x, y, radius (or width/height)
    @param callback function(entity) - Called for each collision
    @return table - List of colliding entities
]]
function EntityController:checkCollision(obj, handlers)
    local collisions = {}

    for _, entity in ipairs(self.entities) do
        if entity.active and not entity.marked_for_removal then
            local collided = false

            -- Grid-based collision (cell match)
            if obj.grid then
                collided = math.floor(obj.x) == math.floor(entity.x) and math.floor(obj.y) == math.floor(entity.y)

            -- Circle-circle collision
            elseif obj.radius and entity.radius then
                local dx = obj.x - entity.x
                local dy = obj.y - entity.y
                local dist_sq = dx * dx + dy * dy
                local radius_sum = obj.radius + entity.radius
                collided = dist_sq < radius_sum * radius_sum

            -- Circle-rect collision
            elseif obj.radius and entity.width and entity.height then
                local closest_x = math.max(entity.x, math.min(obj.x, entity.x + entity.width))
                local closest_y = math.max(entity.y, math.min(obj.y, entity.y + entity.height))
                local dx = obj.x - closest_x
                local dy = obj.y - closest_y
                collided = (dx * dx + dy * dy) < (obj.radius * obj.radius)

            -- Rect-rect collision
            elseif obj.width and obj.height and entity.width and entity.height then
                collided = obj.x < entity.x + entity.width and
                           obj.x + obj.width > entity.x and
                           obj.y < entity.y + entity.height and
                           obj.y + obj.height > entity.y

            -- Default: grid cell match
            else
                collided = math.floor(obj.x) == math.floor(entity.x) and math.floor(obj.y) == math.floor(entity.y)
            end

            if collided then
                table.insert(collisions, entity)
                if type(handlers) == "function" then
                    handlers(entity)
                elseif type(handlers) == "table" then
                    local action = entity.on_collision
                    if action and handlers[action] then
                        handlers[action](entity)
                    end
                end
            end
        end
    end

    return collisions
end

--[[
    Hit an entity (deal damage, trigger callbacks)

    @param entity table
    @param damage number (default: 1)
    @param by_what table (optional) - What hit this entity (player, bullet, etc)
    @return boolean - true if entity died from this hit
]]
function EntityController:hitEntity(entity, damage, by_what)
    damage = damage or 1

    if not entity.active then
        return false
    end

    -- Apply damage
    if entity.health then
        entity.health = entity.health - damage

        -- Trigger on_hit callback
        local entity_type = self.entity_types[entity.type_name]
        if entity_type and entity_type.on_hit then
            entity_type.on_hit(entity, by_what)
        end

        -- Check if entity died
        if entity.health <= 0 then
            self:killEntity(entity)
            return true
        end
    else
        -- No health system, instant death
        self:killEntity(entity)
        return true
    end

    return false
end

--[[
    Kill an entity (trigger death callback, mark for removal)
]]
function EntityController:killEntity(entity)
    if not entity.active then
        return
    end

    -- Trigger on_death callback
    local entity_type = self.entity_types[entity.type_name]
    if entity_type and entity_type.on_death then
        entity_type.on_death(entity)
    end

    -- Mark for removal
    entity.marked_for_removal = true
end

--[[
    Remove entity from active list (return to pool if pooling enabled)
]]
function EntityController:removeEntity(entity, removal_reason)
    for i, e in ipairs(self.entities) do
        if e == entity then
            -- Call on_remove callback if exists (entity-level or type-level)
            local on_remove = entity.on_remove or (self.entity_types[entity.type_name] and self.entity_types[entity.type_name].on_remove)
            if on_remove then
                on_remove(entity, removal_reason or "unknown")
            end

            -- Call global on_remove if set
            if self.on_remove then
                self.on_remove(entity, removal_reason or "unknown")
            end

            table.remove(self.entities, i)
            self.entity_count = self.entity_count - 1

            -- Return to pool
            if self.pooling then
                entity.active = false
                entity.marked_for_removal = false
                table.insert(self.entity_pool, entity)
            end

            break
        end
    end
end

--[[
    Remove all entities matching any of the given types
    @param types table - array of type strings to remove
]]
function EntityController:removeByTypes(types)
    local type_set = {}
    for _, t in ipairs(types) do type_set[t] = true end

    local to_remove = {}
    for _, entity in ipairs(self.entities) do
        if type_set[entity.type] then
            table.insert(to_remove, entity)
        end
    end
    for _, entity in ipairs(to_remove) do
        self:removeEntity(entity)
    end
end

--[[
    Remove entities by type and reinitialize (common resize pattern)
    @param types table - array of type strings to remove
    @param init_fn function - callback to reinitialize entities
]]
function EntityController:regenerate(types, init_fn)
    self:removeByTypes(types)
    if init_fn then init_fn() end
end

--[[
    Move a chain of entities based on schema-defined movement behavior.
    Reads movement config from entity type: { type: "chain", follow: "previous", on_leader_move: "take_leader_position" }
    @param chain table - ordered array of entities (index 1 = head/leader)
    @param new_x number - new x position for head
    @param new_y number - new y position for head
    @return old_tail_x, old_tail_y - position where tail was (for growth)
]]
function EntityController:moveChain(chain, new_x, new_y)
    if not chain or #chain == 0 then return end

    local head = chain[1]
    local movement = head.movement or (self.entity_types[head.type_name] or {}).movement

    -- Default behavior or explicit "take_leader_position"
    if not movement or movement.on_leader_move == "take_leader_position" then
        -- Cascade positions: each segment takes position of the one before it
        local old_tail_x, old_tail_y = chain[#chain].x, chain[#chain].y

        for i = #chain, 2, -1 do
            chain[i].x = chain[i-1].x
            chain[i].y = chain[i-1].y
        end

        -- Move head to new position
        head.x = new_x
        head.y = new_y

        return old_tail_x, old_tail_y
    end
end

--[[
    Clear all entities
]]
function EntityController:clear()
    if self.pooling then
        -- Return all to pool
        for _, entity in ipairs(self.entities) do
            entity.active = false
            entity.marked_for_removal = false
            table.insert(self.entity_pool, entity)
        end
    end

    self.entities = {}
    self.entity_count = 0
    self.grid_spawned = false
end

--[[
    Draw all entities using provided render callback

    @param render_callback function(entity) - Custom rendering for each entity
]]
function EntityController:draw(render_callback)
    for _, entity in ipairs(self.entities) do
        if entity.active and not entity.marked_for_removal then
            render_callback(entity)
        end
    end
end

--[[
    Get count of active entities
]]
function EntityController:getActiveCount()
    local count = 0
    for _, entity in ipairs(self.entities) do
        if entity.active and not entity.marked_for_removal then
            count = count + 1
        end
    end
    return count
end

--[[
    Get all entities of a specific type
]]
function EntityController:getEntitiesByType(type_name)
    local result = {}
    for _, entity in ipairs(self.entities) do
        if entity.active and entity.type_name == type_name and not entity.marked_for_removal then
            table.insert(result, entity)
        end
    end
    return result
end

--[[
    Apply function to each entity of a type
]]
function EntityController:forEachByType(type_name, fn)
    for _, entity in ipairs(self.entities) do
        if entity.active and entity.type_name == type_name and not entity.marked_for_removal then
            fn(entity)
        end
    end
end

--[[
    Get all entities matching a category (entities with entity.category == category)
    Useful when multiple entity types share a category (e.g., food_normal, food_bad, food_golden all have category "food")
]]
function EntityController:getEntitiesByCategory(category)
    local result = {}
    for _, entity in ipairs(self.entities) do
        if entity.active and entity.category == category and not entity.marked_for_removal then
            table.insert(result, entity)
        end
    end
    return result
end

--[[
    Get all entities matching a filter function
]]
function EntityController:getEntitiesByFilter(filter_fn)
    local result = {}
    for _, entity in ipairs(self.entities) do
        if entity.active and not entity.marked_for_removal and filter_fn(entity) then
            table.insert(result, entity)
        end
    end
    return result
end

--[[
    Get all active entities
]]
function EntityController:getEntities()
    local result = {}
    for _, entity in ipairs(self.entities) do
        if entity.active and not entity.marked_for_removal then
            table.insert(result, entity)
        end
    end
    return result
end

--[[
    Get total count (including pooled)
]]
function EntityController:getTotalCount()
    return self.entity_count
end

--[[
    Find nearest entity to a point (optionally filtered)

    @param x number
    @param y number
    @param filter function(entity) - optional, return true to include
    @return entity, distance
]]
function EntityController:findNearest(x, y, filter)
    local nearest = nil
    local min_dist = math.huge

    for _, entity in ipairs(self.entities) do
        if entity.active and not entity.marked_for_removal then
            if not filter or filter(entity) then
                local ex = entity.x + (entity.width or 0) / 2
                local ey = entity.y + (entity.height or 0) / 2
                local dx = ex - x
                local dy = ey - y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < min_dist then
                    min_dist = dist
                    nearest = entity
                end
            end
        end
    end

    return nearest, min_dist
end

-- Get a collision check function for entity-to-entity rect collision
function EntityController:getRectCollisionCheck(PhysicsUtils)
    return function(entity, x, y)
        for _, other in ipairs(self.entities) do
            if other ~= entity and other.alive then
                if PhysicsUtils.rectCollision(x, y, entity.width, entity.height, other.x, other.y, other.width, other.height) then
                    return true
                end
            end
        end
        return false
    end
end

--[[
    Update entity behaviors (falling, moving, regenerating)
    Call this in game update loop for entities that need these behaviors

    @param dt number
    @param config table - {fall_speed, move_speed, regen_time, bounds, can_overlap}
    @param collision_check function(entity, x, y) - returns true if position collides
]]
function EntityController:updateBehaviors(dt, config, collision_check)
    config = config or {}

    for _, entity in ipairs(self.entities) do
        if not entity.active or entity.marked_for_removal then
            goto continue
        end

        -- Boundary anchor behavior (entity stays attached to a boundary point)
        if config.boundary_anchor and entity.boundary_angle ~= nil then
            local ba = config.boundary_anchor
            if ba.get_boundary_point then
                entity.x, entity.y = ba.get_boundary_point(entity.boundary_angle)
            end
        end

        -- Falling behavior
        if config.fall_enabled and entity.alive then
            local new_y = entity.y + (config.fall_speed or 50) * dt
            local can_move = true

            if not config.can_overlap and collision_check then
                can_move = not collision_check(entity, entity.x, new_y)
            end

            if can_move then
                entity.y = new_y
            end

            -- Check if reached bottom threshold
            if config.fall_death_y and entity.y > config.fall_death_y then
                if config.on_fall_death then
                    config.on_fall_death(entity)
                end
            end
        end

        -- Horizontal movement behavior
        if config.move_enabled and entity.alive then
            if entity.vx == 0 then
                entity.vx = (config.move_speed or 50) * (math.random() < 0.5 and 1 or -1)
            end

            local new_x = entity.x + entity.vx * dt
            local can_move = true

            if not config.can_overlap and collision_check then
                can_move = not collision_check(entity, new_x, entity.y)
                if not can_move then
                    entity.vx = -entity.vx
                end
            end

            if can_move then
                entity.x = new_x
            end

            -- Bounce off walls
            if config.bounds then
                if entity.x < config.bounds.x_min then
                    entity.vx = math.abs(entity.vx)
                    entity.x = config.bounds.x_min
                elseif entity.x + (entity.width or 0) > config.bounds.x_max then
                    entity.vx = -math.abs(entity.vx)
                    entity.x = config.bounds.x_max - (entity.width or 0)
                end
            end
        end

        -- Regeneration behavior
        if config.regen_enabled and not entity.alive then
            entity.regen_timer = (entity.regen_timer or 0) + dt

            if entity.regen_timer >= (config.regen_time or 5) then
                local can_regen = true

                if not config.can_overlap and collision_check then
                    can_regen = not collision_check(entity, entity.x, entity.y)
                end

                if can_regen then
                    entity.alive = true
                    entity.health = entity.max_health or 1
                    entity.regen_timer = 0
                end
            end
        end

        -- Shooting behavior
        if config.shooting_enabled and entity.shoot_interval and entity.shoot_interval > 0 then
            entity.shoot_timer = (entity.shoot_timer or entity.shoot_interval) - dt
            if entity.shoot_timer <= 0 then
                if config.on_shoot then
                    config.on_shoot(entity)
                end
                entity.shoot_timer = entity.shoot_interval
            end
        end

        -- Pattern movement behavior (calls PatternMovement.update for non-dominated patterns)
        if config.pattern_movement then
            local dominated = entity.movement_pattern == 'grid' or
                             entity.movement_pattern == 'formation'
            if not dominated and entity.movement_pattern then
                local pm = config.pattern_movement
                if pm.speed then entity.speed = entity.speed or pm.speed end
                if pm.direction then entity.direction = entity.direction or pm.direction end

                -- Update target for tracking/teleporter patterns
                if pm.tracking_target and (entity.movement_pattern == 'tracking' or entity.movement_pattern == 'teleporter') then
                    entity.target_x = pm.tracking_target.x
                    entity.target_y = pm.tracking_target.y
                end

                -- Update difficulty scaler from game state if provided
                if pm.get_difficulty_scaler then
                    entity.difficulty_scaler = pm.get_difficulty_scaler(entity)
                end

                if pm.PatternMovement then
                    pm.PatternMovement.update(dt, entity, pm.bounds)
                end
            end
        end

        -- Sprite rotation behavior (visual only)
        if config.sprite_rotation then
            local pm = config.pattern_movement and config.pattern_movement.PatternMovement
            if pm and pm.updateSpriteRotation then
                pm.updateSpriteRotation(dt, entity)
            end
        end

        -- Trail update behavior
        if config.trails and entity.trail_positions then
            table.insert(entity.trail_positions, 1, {x = entity.x, y = entity.y})
            while #entity.trail_positions > (config.trails.max_length or 10) do
                table.remove(entity.trail_positions)
            end
        end

        -- Track when entity enters play area (for dodge counting)
        if config.track_entered_play and not entity.entered_play then
            local b = config.track_entered_play
            if entity.x > (b.x or 0) and entity.x < (b.width or 800) and
               entity.y > (b.y or 0) and entity.y < (b.height or 600) then
                entity.entered_play = true
            end
        end

        -- Rotation behavior (entities spin based on rotation_speed)
        if config.rotation and entity.rotation_speed then
            entity.rotation = (entity.rotation or 0) + entity.rotation_speed * dt
        end

        -- Bounce movement (uses PatternMovement-compatible fields: vx, vy, radius)
        if config.bounce_movement and entity.movement_pattern == 'bounce' then
            local bm = config.bounce_movement
            local r = entity.radius or 0
            local w, h = bm.width or 800, bm.height or 600

            -- Track when bouncer enters play area
            if not entity.has_entered then
                if entity.x >= r and entity.x <= w - r and entity.y >= r and entity.y <= h - r then
                    entity.has_entered = true
                end
            end

            -- Only bounce after entering
            if entity.has_entered then
                entity.x = entity.x + (entity.vx or 0) * dt
                entity.y = entity.y + (entity.vy or 0) * dt

                local bounced = false
                if entity.x < r or entity.x > w - r then
                    entity.vx = -(entity.vx or 0)
                    entity.x = math.max(r, math.min(w - r, entity.x))
                    bounced = true
                end
                if entity.y < r or entity.y > h - r then
                    entity.vy = -(entity.vy or 0)
                    entity.y = math.max(r, math.min(h - r, entity.y))
                    bounced = true
                end

                -- Count bounces and check max
                if bounced then
                    entity.bounce_count = (entity.bounce_count or 0) + 1
                    if bm.max_bounces and entity.bounce_count >= bm.max_bounces then
                        entity.was_dodged = true
                        entity.removal_reason = "max_bounces"
                        entity.marked_for_removal = true
                    end
                end
            else
                -- Move toward play area before entering
                entity.x = entity.x + (entity.vx or 0) * dt
                entity.y = entity.y + (entity.vy or 0) * dt
            end
        end

        -- Delayed spawn behavior (e.g., meteor warning → meteor)
        if config.delayed_spawn and entity.delayed_spawn then
            entity.delayed_spawn.timer = (entity.delayed_spawn.timer or 0) - dt
            if entity.delayed_spawn.timer <= 0 and not entity.delayed_spawn.spawned then
                local ds = entity.delayed_spawn
                if ds.spawn_type and config.delayed_spawn.on_spawn then
                    config.delayed_spawn.on_spawn(entity, ds)
                end
                entity.delayed_spawn.spawned = true
                -- Mark for removal instead of removing during iteration
                entity.marked_for_removal = true
            end
        end

        -- Off-screen removal behavior
        if config.remove_offscreen and not entity.skip_offscreen_removal then
            local bounds = config.remove_offscreen
            local off_bottom = entity.y > (bounds.bottom or bounds.height or 600)
            local off_top = entity.y + (entity.height or 0) < (bounds.top or 0)
            local off_left = entity.x + (entity.width or 0) < (bounds.left or 0)
            local off_right = entity.x > (bounds.right or bounds.width or 800)

            if off_bottom or off_top or off_left or off_right then
                entity.removal_reason = "offscreen"
                entity.marked_for_removal = true
            end
        end

        -- Collision behavior (check against a target like player)
        if config.collision and config.collision.target then
            local target = config.collision.target
            local tr = target.radius or 10
            local er = entity.radius or 10
            local dx = target.x - entity.x
            local dy = target.y - entity.y
            local dist_sq = dx * dx + dy * dy
            local radii = tr + er

            if dist_sq < radii * radii then
                if config.collision.on_collision then
                    local should_remove = config.collision.on_collision(entity, target)
                    if should_remove ~= false then
                        entity.removal_reason = "collision"
                        entity.marked_for_removal = true
                    end
                else
                    entity.removal_reason = "collision"
                    entity.marked_for_removal = true
                end
            end

            -- Trail collision (if entity has trail_positions)
            if entity.trail_positions and #entity.trail_positions > 1 and config.collision.check_trails then
                for j = 1, #entity.trail_positions - 1 do
                    local p1 = entity.trail_positions[j]
                    local p2 = entity.trail_positions[j + 1]
                    -- Circle vs line segment collision
                    local lx, ly = p2.x - p1.x, p2.y - p1.y
                    local fx, fy = p1.x - target.x, p1.y - target.y
                    local a = lx * lx + ly * ly
                    local b = 2 * (fx * lx + fy * ly)
                    local c = fx * fx + fy * fy - tr * tr
                    local disc = b * b - 4 * a * c
                    if disc >= 0 and a > 0 then
                        disc = math.sqrt(disc)
                        local t1 = (-b - disc) / (2 * a)
                        local t2 = (-b + disc) / (2 * a)
                        if (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1) then
                            if config.collision.on_collision then
                                local should_remove = config.collision.on_collision(entity, target, "trail")
                                if should_remove ~= false then
                                    entity.removal_reason = "trail_collision"
                                    entity.marked_for_removal = true
                                end
                            else
                                entity.removal_reason = "trail_collision"
                                entity.marked_for_removal = true
                            end
                            break
                        end
                    end
                end
            end
        end

        -- Enter zone behavior (trigger callback when entity enters a zone)
        if config.enter_zone and not entity.has_entered_zone then
            local zone = config.enter_zone
            local inside = false
            if zone.check_fn then
                inside = zone.check_fn(entity)
            elseif zone.bounds then
                inside = entity.x > zone.bounds.x and entity.x < zone.bounds.x + zone.bounds.width and
                         entity.y > zone.bounds.y and entity.y < zone.bounds.y + zone.bounds.height
            end
            if inside then
                entity.has_entered_zone = true
                if zone.on_enter then
                    local should_remove = zone.on_enter(entity)
                    if should_remove then
                        entity.removal_reason = "entered_zone"
                        entity.marked_for_removal = true
                    end
                end
            end
        end

        ::continue::
    end

    -- Timer-based spawning (for hazards like asteroids)
    if config.timer_spawn then
        local ts = config.timer_spawn
        self.spawn_timers = self.spawn_timers or {}
        for type_name, spawn_cfg in pairs(ts) do
            self.spawn_timers[type_name] = (self.spawn_timers[type_name] or 0) - dt
            if self.spawn_timers[type_name] <= 0 then
                if spawn_cfg.on_spawn then
                    spawn_cfg.on_spawn(self, type_name)
                end
                self.spawn_timers[type_name] = spawn_cfg.interval or 1.0
            end
        end
    end

    -- Gradual spawn to slots (for formations)
    if config.gradual_spawn then
        local gs = config.gradual_spawn
        gs.timer = (gs.timer or 0) - dt
        if gs.timer <= 0 and gs.slots and gs.on_spawn then
            local unoccupied = {}
            for _, slot in ipairs(gs.slots) do
                if not slot.occupied then table.insert(unoccupied, slot) end
            end
            if #unoccupied > 0 and (not gs.max_count or gs.spawned_count < gs.max_count) then
                local slot = unoccupied[math.random(#unoccupied)]
                gs.on_spawn(slot)
                gs.spawned_count = (gs.spawned_count or 0) + 1
                gs.timer = gs.interval or 0.5
            end
        end
    end

    -- Grid unit movement (all entities move as one unit, Space Invaders style)
    if config.grid_unit_movement then
        local gum = config.grid_unit_movement

        -- Count only grid entities
        local grid_count = 0
        for _, e in ipairs(self.entities) do
            if e.active and not e.marked_for_removal and e.movement_pattern == 'grid' then
                grid_count = grid_count + 1
            end
        end

        self.grid_movement_state = self.grid_movement_state or {
            direction = 1,
            initial_count = gum.initial_count or grid_count
        }
        local state = self.grid_movement_state

        -- Speed increases as entities die
        local speed_mult = 1.0
        if gum.speed_scaling and state.initial_count > 0 and grid_count > 0 then
            speed_mult = 1 + (1 - grid_count / state.initial_count) * (gum.speed_scale_factor or 2)
        end

        local base_speed = gum.speed or 50
        local move = base_speed * speed_mult * dt * state.direction
        local hit_edge = false

        for _, e in ipairs(self.entities) do
            if e.active and not e.marked_for_removal and e.movement_pattern == 'grid' then
                e.x = e.x + move
                if e.x <= (gum.bounds_left or 0) or
                   e.x + (e.width or 0) >= (gum.bounds_right or 800) then
                    hit_edge = true
                end
            end
        end

        if hit_edge then
            state.direction = -state.direction
            -- Clamp all grid entities back inside bounds to prevent repeated edge triggers
            for _, e in ipairs(self.entities) do
                if e.active and e.movement_pattern == 'grid' then
                    local w = e.width or 0
                    if e.x <= (gum.bounds_left or 0) then
                        e.x = (gum.bounds_left or 0) + 1
                    elseif e.x + w >= (gum.bounds_right or 800) then
                        e.x = (gum.bounds_right or 800) - w - 1
                    end
                end
            end
            if gum.descent then
                for _, e in ipairs(self.entities) do
                    if e.active and e.movement_pattern == 'grid' then
                        e.y = e.y + gum.descent
                    end
                end
            end
        end

        -- Mark grid entities for removal when they go off the bottom
        if gum.bounds_bottom then
            for _, e in ipairs(self.entities) do
                if e.active and e.movement_pattern == 'grid' and e.y > gum.bounds_bottom then
                    e.removal_reason = "out_of_bounds"
                    e.marked_for_removal = true
                end
            end
        end
    end

end

return EntityController
