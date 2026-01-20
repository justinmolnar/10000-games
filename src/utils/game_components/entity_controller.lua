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
    else -- "grid" is default
        self:spawnGrid(type_name, rows, cols, start_x, start_y, spacing_x, spacing_y)
    end
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
