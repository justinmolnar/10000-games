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

    local width = entity_type.width or entity_type.radius * 2 or 32
    local height = entity_type.height or entity_type.radius * 2 or 16

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

return EntityController
