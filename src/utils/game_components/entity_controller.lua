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

-- Spawn multiple entities using a spawner function
function EntityController:spawnMultiple(count, spawner_fn)
    for _ = 1, count do
        spawner_fn()
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

        -- Remove marked entities
        if entity.marked_for_removal then
            self:removeEntity(entity)
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

        -- Spawn new entity (game must provide spawn_func in config)
        if self.spawning.spawn_func then
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
function EntityController:checkCollision(obj, callback)
    local collisions = {}

    for _, entity in ipairs(self.entities) do
        if entity.active and not entity.marked_for_removal then
            local collided = false

            -- Circle-circle collision
            if obj.radius and entity.radius then
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
            end

            if collided then
                table.insert(collisions, entity)
                if callback then
                    callback(entity)
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
function EntityController:removeEntity(entity)
    for i, e in ipairs(self.entities) do
        if e == entity then
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
        if config.shooting_enabled and entity.shoot_rate and entity.shoot_rate > 0 then
            entity.shoot_timer = (entity.shoot_timer or entity.shoot_rate) - dt
            if entity.shoot_timer <= 0 then
                if config.on_shoot then
                    config.on_shoot(entity)
                end
                entity.shoot_timer = entity.shoot_rate
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
                if pm.PatternMovement then
                    pm.PatternMovement.update(dt, entity, pm.bounds)
                end
            end
        end

        -- Rotation behavior (entities spin based on rotation_speed)
        if config.rotation and entity.rotation_speed then
            entity.rotation = (entity.rotation or 0) + entity.rotation_speed * dt
        end

        -- Bounce movement (uses PatternMovement-compatible fields: vx, vy, radius)
        if config.bounce_movement and entity.movement_pattern == 'bounce' then
            local bm = config.bounce_movement
            entity.x = entity.x + (entity.vx or 0) * dt
            entity.y = entity.y + (entity.vy or 0) * dt
            local r = entity.radius or 0
            if entity.x < r or entity.x > (bm.width or 800) - r then
                entity.vx = -(entity.vx or 0)
                entity.x = math.max(r, math.min((bm.width or 800) - r, entity.x))
            end
            if entity.y < r or entity.y > (bm.height or 600) - r then
                entity.vy = -(entity.vy or 0)
                entity.y = math.max(r, math.min((bm.height or 600) - r, entity.y))
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
                self:removeEntity(entity)
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
                self:removeEntity(entity)
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

        -- Remove grid entities that go off the bottom
        if gum.bounds_bottom then
            for _, e in ipairs(self.entities) do
                if e.active and e.movement_pattern == 'grid' and e.y > gum.bounds_bottom then
                    self:removeEntity(e)
                end
            end
        end
    end

end

return EntityController
