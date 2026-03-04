--[[
    Snake Game - Classic snake with extensive variants

    Supports grid-based and smooth (analog) movement modes.
    Features: multiple snakes, AI snakes, food types, obstacles,
    arena shapes, wall modes, girth expansion.

    Configuration from snake_schema.json via SchemaLoader.
    Components created from schema in setupComponents().

    Snake-specific: girth system (width expansion perpendicular to movement)
]]

local BaseGame = require('src.games.base_game')
local SnakeView = require('src.games.views.snake_view')
local PhysicsUtils = require('src.utils.game_components.physics_utils')
local EntityController = require('src.utils.game_components.entity_controller')
local PopupManager = require('src.games.score_popup').PopupManager
local SnakeGame = BaseGame:extend('SnakeGame')

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function SnakeGame:init(game_data, cheats, di, variant_override, original_variant)
    SnakeGame.super.init(self, game_data, cheats, di, variant_override, original_variant)
    self.runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.snake) or {}
    self.params = self.di.components.SchemaLoader.load(self.variant, "snake_schema", self.runtimeCfg)
    self.GRID_SIZE = self.runtimeCfg.grid_size or 20

    self:applyCheats({
        speed_modifier = {"snake_speed", "ai_speed", "food_speed"},
        advantage_modifier = {"victory_limit", "food_count"},
        performance_modifier = {"obstacle_count", "ai_snake_count"}
    })
    self:applySkillTreeBonuses()

    self:setupArena()
    -- Large arenas (arena_size 1.5+) can have 200+ border wall entities alone
    local border_estimate = 2 * (self.grid_width + self.grid_height)
    self:createEntityControllerFromSchema(nil, {max_entities = border_estimate + 100})
    self:createComponentsFromSchema()  -- Creates arena_controller early, needed by setupSnake
    self:setupSnake()
    self:setupComponents()  -- Configures arena_controller and movement_controller (needs self.snakes)

    self.popup_manager = PopupManager:new()
    self.view = SnakeView:new(self, self.variant)
    self:loadAssets()
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function SnakeGame:setupArena()
    self:setupArenaDimensions()
    self.grid_width = math.floor(self.game_width / (self.GRID_SIZE * self.camera_zoom))
    self.grid_height = math.floor(self.game_height / (self.GRID_SIZE * self.camera_zoom))
end

function SnakeGame:_initSmoothState(x, y)
    if not self.params.use_trail then return {} end
    return {
        smooth_x = x + 0.5, smooth_y = y + 0.5, smooth_angle = 0,
        smooth_trail = PhysicsUtils.createTrailSystem({
            max_length = 0, track_distance = true, color = {1,1,1,1}, line_width = 1, angle_offset = 0
        }),
        smooth_target_length = self.params.smooth_initial_length
    }
end

function SnakeGame:_createSnakeEntity(x, y, direction, behavior)
    local head_entity = self.entity_controller:spawn("snake_body", x, y, {is_head = true, distance_from_head = 0})
    local snake = {
        body = {head_entity},
        direction = direction,
        next_direction = {x = direction.x, y = direction.y},
        alive = true,
        behavior = behavior,
        move_timer = 0
    }
    head_entity.owner = snake  -- Set after snake exists for collision filtering
    for k, v in pairs(self:_initSmoothState(x, y)) do snake[k] = v end
    return snake
end

function SnakeGame:_initializeObstacles()
    self:createEdgeObstacles()
    if not self._obstacles_created then
        local count = math.floor(self.params.obstacle_count * self.difficulty_modifiers.complexity)
        for _ = 1, count do self:spawnObstacleEntity() end
        self._obstacles_created = true
    end
end

function SnakeGame:_spawnInitialFood()
    if #self:getFoods() == 0 and not self._foods_spawned then
        for _ = 1, self.params.food_count do self:spawnFoodEntity() end
        self._foods_spawned = true
    end
end

function SnakeGame:_regenerateEdgeObstacles()
    -- Calculate safe interior bounds (avoid boundary cells where walls will be)
    local margin = (self.params.wall_mode == "wrap") and 0 or 1
    local min_x, max_x = margin, self.grid_width - 1 - margin
    local min_y, max_y = margin, self.grid_height - 1 - margin

    -- Get non-wall obstacles to clamp
    local obstacles_to_clamp = {}
    for _, obs in ipairs(self:getObstacles()) do
        if obs.type ~= "walls" and obs.type ~= "bounce_wall" then
            table.insert(obstacles_to_clamp, obs)
        end
    end

    -- Clamp all entities to safe interior before regenerating walls
    self:clampEntitiesToBounds({self.snake.body, self:getFoods(), obstacles_to_clamp}, min_x, max_x, min_y, max_y)

    -- Remove old walls and reinitialize
    self.entity_controller:regenerate({"walls", "bounce_wall"}, function() self:_initializeObstacles() end)
end

function SnakeGame:setupSnake()
    local cx, cy = math.floor(self.grid_width / 2), math.floor(self.grid_height / 2)
    local default_dir = BaseGame.CARDINAL_DIRECTIONS[self.params.starting_direction] or {x = 1, y = 0}

    self.snakes = {}
    local snake_index = 1

    -- Get spawn configs: first is player config, second is AI config
    local player_config = self.params.snake_spawns[1] or {region = "random", direction = "toward_center"}
    local ai_config = self.params.snake_spawns[2] or {region = "random", direction = "starting_direction", behavior = "food_focused", min_distance_from_center = 10}

    -- Spawn player snakes using snake_count param
    for _ = 1, self.params.snake_count do
        local x, y, direction = self:_spawnSnakePosition(player_config, snake_index, cx, cy, default_dir)
        local snake = self:_createSnakeEntity(x, y, direction, nil)
        snake.spawn_config = player_config
        table.insert(self.snakes, snake)
        snake_index = snake_index + 1
    end

    -- Spawn AI snakes using ai_snake_count param
    for _ = 1, self.params.ai_snake_count do
        local x, y, direction = self:_spawnSnakePosition(ai_config, snake_index, cx, cy, default_dir)
        local snake = self:_createSnakeEntity(x, y, direction, self.params.ai_behavior or "food_focused")
        snake.spawn_config = ai_config
        table.insert(self.snakes, snake)
        snake_index = snake_index + 1
    end

    self.snake = self.snakes[1]
    self._snakes_need_positioning = true

    self.segments_for_next_girth = self.params.girth_growth
    self.pending_growth = 0
    self.shrink_timer, self.obstacle_spawn_timer = 0, 0
end

function SnakeGame:_spawnSnakePosition(config, index, cx, cy, default_dir)
    local margin = (self.params.wall_mode == "wrap") and 0 or 1
    margin = margin + (self.params.spawn_margin or 0)

    return self.entity_controller:calculateSpawnPosition({
        region = config.region or "random",
        bounds = {min_x = margin, max_x = self.grid_width - 1 - margin, min_y = margin, max_y = self.grid_height - 1 - margin, is_grid = true},
        center = {x = cx, y = cy},
        direction = config.direction or "starting_direction",
        fixed_direction = default_dir,
        min_distance_from_center = config.min_distance_from_center or 0,
        spacing = config.spacing or self.params.multi_snake_spacing or 3,
        index = index,
        is_valid_fn = function(px, py)
            if config.inside_arena ~= false and not self:isInsideArena({x = px, y = py}) then return false end
            if self:checkCollision({x = px, y = py}) then return false end
            return true
        end
    })
end

function SnakeGame:_positionAllSnakes()
    local cx, cy = math.floor(self.grid_width / 2), math.floor(self.grid_height / 2)
    local default_dir = BaseGame.CARDINAL_DIRECTIONS[self.params.starting_direction] or {x = 1, y = 0}

    for i, snake in ipairs(self.snakes) do
        local config = snake.spawn_config or self.params.snake_spawns[1] or {}
        local x, y, direction = self:_spawnSnakePosition(config, i, cx, cy, default_dir)

        snake.body[1].x, snake.body[1].y = x, y
        snake.direction = direction

        local entity_id = (i == 1) and "snake" or ("snake_" .. i)
        if self.params.use_trail then
            snake.smooth_x, snake.smooth_y = x + 0.5, y + 0.5
            snake.smooth_angle = math.atan2(direction.y, direction.x)
        end
        self.movement_controller:initState(entity_id, direction)
    end
end

function SnakeGame:setupComponents()
    -- Note: createComponentsFromSchema called earlier in init (arena_controller needed by setupSnake)
    self:createVictoryConditionFromSchema()

    -- Manual visual_effects init (no schema section for snake)
    local VisualEffects = self.di.components.VisualEffects
    self.visual_effects = VisualEffects:new({
        camera_shake_enabled = true,
        screen_flash_enabled = true,
        particle_effects_enabled = true
    })

    -- Set computed arena values (must set base_width/current_width, not just width)
    self.arena_controller.base_width = self.grid_width
    self.arena_controller.base_height = self.grid_height
    self.arena_controller.current_width = self.grid_width
    self.arena_controller.current_height = self.grid_height
    self.arena_controller.min_width = math.max(self.params.min_arena_cells, math.floor(self.grid_width * self.params.min_arena_ratio))
    self.arena_controller.min_height = math.max(self.params.min_arena_cells, math.floor(self.grid_height * self.params.min_arena_ratio))
    -- Set grid mode and container dimensions (prevents pixel-based recentering)
    self.arena_controller.grid_mode = true  -- Snake uses grid coordinates
    self.arena_controller.cell_size = 1     -- 1 grid cell = 1 unit in arena_controller
    self.arena_controller.container_width = self.grid_width
    self.arena_controller.container_height = self.grid_height
    self.arena_controller.bounds_padding = 0  -- Disable movement clamping
    self.arena_controller.vx = 0  -- No arena movement
    self.arena_controller.vy = 0
    self.arena_controller.on_shrink = function(margins) self:onArenaShrink(margins) end

    -- Set center and radius for shaped arenas (MUST be set AFTER container)
    -- Enable safe_zone_mode for non-rectangle shapes OR custom vertices
    local has_custom_vertices = self.variant and self.variant.arena_vertices
    self.arena_controller.safe_zone_mode = (self.params.arena_shape ~= "rectangle") or has_custom_vertices
    self.arena_controller.x = self.grid_width / 2
    self.arena_controller.y = self.grid_height / 2
    self.arena_controller.radius = math.min(self.grid_width, self.grid_height) / 2 - 1
    self.arena_controller.initial_radius = self.arena_controller.radius

    -- Set polygon vertices based on arena_shape or custom arena_vertices
    if self.variant and self.variant.arena_vertices then
        -- Custom vertices from variant (normalized to radius=1)
        self.arena_controller.vertices = self.variant.arena_vertices
    else
        local sides, rotation = self:getShapeSides(self.params.arena_shape)
        self.arena_controller.vertices = self.arena_controller:generateRegularPolygon(sides, rotation)
    end

    for i, psnake in ipairs(self.snakes) do
        local entity_id = (i == 1) and "snake" or ("snake_" .. i)
        self.movement_controller:initState(entity_id, psnake.direction)
    end
    self.metrics.snake_length, self.metrics.survival_time = 1, 0
end

function SnakeGame:setupWaterPickup()
    if not self.water_pickup or self._water_setup_done then return end
    if not self.entity_controller then
        self.entity_controller = EntityController:new({
            spawning = {mode = "manual"},
            max_entities = 5,
        })
    end
    self.entity_controller.entity_types["water"] = {
        category = "water",
        on_collision = "collect_water",
        collision_response = {damage = 0, remove = false},
        radius = self.water_pickup.collection_radius,
        movement_type = "static",
        max_alive = self.water_pickup.max_active,
    }
    self.entity_controller.universal_handlers = self.entity_controller.universal_handlers or {}
    self.entity_controller.universal_handlers.collect_water = function(entity)
        self:onWaterCollected(entity)
        self.entity_controller:removeEntity(entity, "collected")
    end
    -- Spawn water on grid cells like food, not at random floats
    self.water_timer_spawning = false
    self._water_setup_done = true
end

function SnakeGame:spawnWaterEntity()
    if not self.water_pickup then return nil end
    local ec = self.game and self.game.entity_controller or self.entity_controller
    if #ec:getEntitiesByCategory("water") >= self.water_pickup.max_active then return nil end
    local margin = (self.params.wall_mode == "wrap") and 0 or 1
    local bounds = {
        min_x = margin, max_x = self.grid_width - 1 - margin,
        min_y = margin, max_y = self.grid_height - 1 - margin
    }
    local x, y = self:getPatternSpawnPosition("random", bounds)
    if x then
        return ec:spawn("water", x, y, {
            age = 0,
            water_lifetime = self.water_pickup.lifetime,
            value = self.water_pickup.value,
        })
    end
    return nil
end

--------------------------------------------------------------------------------
-- Entity Helpers
--------------------------------------------------------------------------------

function SnakeGame:getFoods()
    return self.entity_controller:getEntitiesByCategory("food")
end

function SnakeGame:getObstacles()
    return self.entity_controller:getEntitiesByCategory("obstacle")
end

function SnakeGame:removeFood(food)
    self.entity_controller:removeEntity(food)
end

function SnakeGame:removeObstacle(obstacle)
    self.entity_controller:removeEntity(obstacle)
end

function SnakeGame:removeEntity(entity)
    self.entity_controller:removeEntity(entity)
end

function SnakeGame:_respawnFood()
    if self.params.food_spawn_mode == "continuous" then
        self:spawnFoodEntity()
    elseif self.params.food_spawn_mode == "batch" and #self:getFoods() == 0 then
        for _ = 1, self.params.food_count do self:spawnFoodEntity() end
    end
end

function SnakeGame:_getFoodType()
    if math.random() < self.params.golden_food_spawn_rate then return "food_golden" end
    if math.random() < self.params.bad_food_chance then return "food_bad" end
    return "food_normal"
end

function SnakeGame:spawnFoodEntity()
    if not self.grid_width or not self.grid_height or self.grid_width < 3 or self.grid_height < 3 then
        return nil
    end
    local margin = (self.params.wall_mode == "wrap") and 0 or 1
    local bounds = {
        min_x = margin, max_x = self.grid_width - 1 - margin,
        min_y = margin, max_y = self.grid_height - 1 - margin
    }
    local pattern = self.params.food_spawn_pattern or "random"
    local x, y = self:getPatternSpawnPosition(pattern, bounds)
    if x then
        return self.entity_controller:spawn(self:_getFoodType(), x, y, {lifetime = 0, category = "food"})
    end
    return nil
end

function SnakeGame:spawnObstacleEntity()
    local type_name = self.params.obstacle_type == "moving_blocks" and "obstacle_moving" or "obstacle_static"
    local bounds = {min_x = 0, max_x = self.grid_width - 1, min_y = 0, max_y = self.grid_height - 1}
    local x, y = self:getPatternSpawnPosition("random", bounds)
    if x then
        local custom = {category = "obstacle", type = self.params.obstacle_type}
        if self.params.obstacle_type == "moving_blocks" then
            custom.vx, custom.vy = math.random() < 0.5 and 1 or -1, 0
        end
        return self.entity_controller:spawn(type_name, x, y, custom)
    end
    return nil
end

function SnakeGame:getPatternSpawnPosition(pattern, bounds)
    self.spawn_pattern_state = self.spawn_pattern_state or {}

    for _ = 1, 50 do
        local x, y

        if pattern == "cluster" then
            -- Spawn near existing food
            local foods = self:getFoods()
            if #foods > 0 then
                local ref = foods[math.random(#foods)]
                local r = 3
                x = ref.x + math.random(-r, r)
                y = ref.y + math.random(-r, r)
            else
                x = math.random(bounds.min_x, bounds.max_x)
                y = math.random(bounds.min_y, bounds.max_y)
            end

        elseif pattern == "line" then
            -- Spawn along horizontal center line with variance
            local center_y = math.floor((bounds.min_y + bounds.max_y) / 2)
            local variance = 2
            x = math.random(bounds.min_x, bounds.max_x)
            y = center_y + math.random(-variance, variance)

        elseif pattern == "spiral" then
            -- Expanding spiral from center
            local state = self.spawn_pattern_state.spiral or {angle = 0, radius = 2, expanding = true}
            local cx = (bounds.min_x + bounds.max_x) / 2
            local cy = (bounds.min_y + bounds.max_y) / 2
            local min_r, max_r = 2, math.min(bounds.max_x - bounds.min_x, bounds.max_y - bounds.min_y) * 0.4

            state.angle = state.angle + 0.5
            state.radius = state.radius + (state.expanding and 0.5 or -0.5)
            if state.radius >= max_r then state.expanding = false
            elseif state.radius <= min_r then state.expanding = true end

            x = math.floor(cx + math.cos(state.angle) * state.radius)
            y = math.floor(cy + math.sin(state.angle) * state.radius)
            self.spawn_pattern_state.spiral = state

        else -- random (default)
            x = math.random(bounds.min_x, bounds.max_x)
            y = math.random(bounds.min_y, bounds.max_y)
        end

        -- Clamp to bounds
        x = math.max(bounds.min_x, math.min(bounds.max_x, x))
        y = math.max(bounds.min_y, math.min(bounds.max_y, y))

        if not self:checkCollision({x = x, y = y}) then
            return x, y
        end
    end
    return nil, nil
end

--------------------------------------------------------------------------------
-- Game Loop
--------------------------------------------------------------------------------

function SnakeGame:setPlayArea(width, height)
    self.viewport_width, self.viewport_height = width, height

    if not self.is_fixed_arena then
        self.game_width, self.game_height = width, height
        if self.GRID_SIZE then
            local effective_tile_size = self.GRID_SIZE * (self.params.camera_zoom or 1.0)
            local new_gw = math.floor(self.game_width / effective_tile_size)
            local new_gh = math.floor(self.game_height / effective_tile_size)

            -- Only rebuild if grid dimensions actually changed
            local grid_changed = (new_gw ~= self.grid_width or new_gh ~= self.grid_height)
            self.grid_width = new_gw
            self.grid_height = new_gh

            self.arena_controller.base_width = self.grid_width
            self.arena_controller.base_height = self.grid_height
            self.arena_controller.current_width = self.grid_width
            self.arena_controller.current_height = self.grid_height

            -- Ensure grid mode is set for Snake
            self.arena_controller.grid_mode = true
            self.arena_controller.cell_size = 1
            -- Set container dimensions to grid dimensions (prevents pixel-based recentering)
            self.arena_controller.container_width = self.grid_width
            self.arena_controller.container_height = self.grid_height
            self.arena_controller.bounds_padding = 0  -- Disable movement clamping
            self.arena_controller.vx = 0  -- No arena movement
            self.arena_controller.vy = 0

            -- Update arena center and radius for shaped/custom arenas (MUST be set AFTER container)
            local has_custom_vertices = self.variant and self.variant.arena_vertices
            if self.params.arena_shape ~= "rectangle" or has_custom_vertices then
                self.arena_controller.safe_zone_mode = true
                self.arena_controller.x = self.grid_width / 2
                self.arena_controller.y = self.grid_height / 2
                self.arena_controller.radius = math.min(self.grid_width, self.grid_height) / 2 - 1
                self.arena_controller.initial_radius = self.arena_controller.radius
            end

            if grid_changed then
                self:_regenerateEdgeObstacles()
            end
        end
    else
        -- Fixed arena: initialize obstacles once (non-fixed already did via _regenerateEdgeObstacles)
        self:_initializeObstacles()
    end

    if self._snakes_need_positioning then
        self:_positionAllSnakes()
        self._snakes_need_positioning = false
    end
    self:_spawnInitialFood()
end

function SnakeGame:onWaterCollected(entity)
    local px = entity.x * self.GRID_SIZE
    local py = entity.y * self.GRID_SIZE
    if self.di and self.di.playerData then
        self.di.playerData:addWater(entity.value or 1)
    end
    if self.popup_manager then
        self.popup_manager:add(px, py, "+" .. (entity.value or 1) .. " WATER", {0.3, 0.7, 1.0})
    end
    if self.visual_effects then
        self.visual_effects:flash({color = {0.3, 0.7, 1.0, 0.3}, duration = 0.3, mode = "fade_out"})
    end
end

function SnakeGame:updateGameLogic(dt)
    self.metrics.survival_time = self.time_elapsed
    if self.popup_manager then self.popup_manager:update(dt) end
    if self.visual_effects then self.visual_effects:update(dt) end

    -- Update food movement
    if self.params.food_movement ~= "static" then
        local head = self.snake.body[1]
        for _, food in ipairs(self:getFoods()) do
            if self.entity_controller:tickTimer(food, "move_timer", self.params.food_speed, dt) then
                local dx, dy
                if self.params.food_movement == "drift" then
                    dx, dy = self:getRandomCardinalDirection()
                else
                    dx, dy = self:getCardinalDirection(food.x, food.y, head.x, head.y)
                    if self.params.food_movement == "flee_from_snake" then dx, dy = -dx, -dy end
                end
                food.x, food.y = self:wrapPosition(food.x + dx, food.y + dy, self.grid_width, self.grid_height)
            end
        end
    end

    -- Update food lifetime (despawn expired foods)
    if self.params.food_lifetime > 0 then
        for _, food in ipairs(self:getFoods()) do
            if self.entity_controller:tickTimer(food, "lifetime", 1 / self.params.food_lifetime, dt) then
                self:removeFood(food)
                self:spawnFoodEntity()
            end
        end
    end

    -- Water spawning (on grid, like food)
    if self.water_pickup and self.entity_controller:tickTimer(self, "water_spawn_timer", 1 / self.water_pickup.spawn_interval, dt) then
        if self.water_pickup:rollChance() then
            self:spawnWaterEntity()
        end
    end

    -- Shrinking over time
    if self.params.shrink_over_time > 0 and #self.snake.body > 1 and self.entity_controller:tickTimer(self, "shrink_timer", self.params.shrink_over_time, dt) then
        local removed = table.remove(self.snake.body)
        if removed then self.entity_controller:removeEntity(removed) end
        self.metrics.snake_length = #self.snake.body
        if #self.snake.body == 0 then self:onComplete(); return end
    end

    -- Update moving obstacles
    for _, obs in ipairs(self:getObstacles()) do
        if obs.vx and self.entity_controller:tickTimer(obs, "move_timer", 2, dt) then
            obs.x, obs.y = obs.x + obs.vx, obs.y + (obs.vy or 0)
            PhysicsUtils.handleBounds(obs, {width = self.grid_width, height = self.grid_height}, {w = 0.5, h = 0.5}, function(e, info)
                PhysicsUtils.bounceEdge(e, info, 1.0)
            end)
        end
    end

    -- Obstacle spawning over time
    if self.params.obstacle_spawn_over_time > 0 and self.entity_controller:tickTimer(self, "obstacle_spawn_timer", self.params.obstacle_spawn_over_time, dt) then
        self:spawnObstacleEntity()
    end

    self.arena_controller:update(dt)
    self.grid_width = self.arena_controller.current_width
    self.grid_height = self.arena_controller.current_height

    -- Update AI snakes (always use grid movement regardless of movement_type)
    self:updateAISnakesGrid(dt)

    -- Handle trail-based movement for player snakes
    if self.params.use_trail then
        self:updateSmoothMovement(dt)
        return  -- Skip grid-based player movement
    end

    -- Apply max speed cap
    local capped_speed = self.params.snake_speed
    if self.params.max_speed_cap > 0 and self.params.snake_speed > self.params.max_speed_cap then
        capped_speed = self.params.max_speed_cap
    end
    self.movement_controller:setSpeed(capped_speed)

    -- Check if it's time to move using MovementController's timing
    if self.movement_controller:tickGrid(dt, "snake") then
        -- Update player snakes (AI snakes handled by updateAISnakesGrid)
        for _, snake in ipairs(self.snakes) do
            if not snake.alive or snake.behavior then goto continue end

            -- Determine direction from input
            if snake == self.snake then
                snake.direction = self.movement_controller:applyQueuedDirection("snake")
            else
                snake.direction = snake.next_direction
            end

            -- Use shared movement logic
            self:_moveGridSnake(snake)

            ::continue::
        end
    end
end

function SnakeGame:updateAISnakesGrid(dt)
    for _, snake in ipairs(self.snakes) do
        if not snake.behavior or not snake.alive then goto continue end

        snake.move_timer = snake.move_timer + dt
        if snake.move_timer < 1 / self.params.ai_speed then goto continue end
        snake.move_timer = snake.move_timer - (1 / self.params.ai_speed)

        -- Compute direction from behavior
        local head = snake.body[1]
        if snake.behavior == "aggressive" then
            snake.direction.x, snake.direction.y = self:getCardinalDirection(head.x, head.y, self.snake.body[1].x, self.snake.body[1].y)
        elseif snake.behavior == "defensive" then
            local dx, dy = self:getCardinalDirection(head.x, head.y, self.snake.body[1].x, self.snake.body[1].y)
            snake.direction.x, snake.direction.y = -dx, -dy
        else -- food_focused
            local nearest = self.entity_controller:findNearest(head.x, head.y, function(e) return e.category == "food" end)
            if nearest then
                snake.direction.x, snake.direction.y = self:getCardinalDirection(head.x, head.y, nearest.x, nearest.y)
            end
        end

        -- Use shared movement logic
        self:_moveGridSnake(snake)

        ::continue::
    end
end

function SnakeGame:_moveGridSnake(snake)
    local head = snake.body[1]
    local new_head = {x = head.x + snake.direction.x, y = head.y + snake.direction.y}
    local is_primary = (snake == self.snake)

    -- Wrap mode
    if self.params.wall_mode == "wrap" then
        new_head.x, new_head.y = self:wrapPosition(new_head.x, new_head.y, self.grid_width, self.grid_height)
    end

    -- Check shaped arena bounds (no wall entities for circle/hex/custom shapes)
    if self.arena_controller.safe_zone_mode and self.arena_controller.vertices and #self.arena_controller.vertices > 0 then
        if not self:isInsideArena(new_head) then
            if is_primary then self:onComplete() else snake.alive = false end
            return
        end
    end

    -- Check collisions at proposed position (walls/obstacles before moving)
    local died = false
    local skip_move = false
    self.entity_controller:checkCollision({x = new_head.x, y = new_head.y, grid = true}, {
        bounce = function()
            local is_blocked_fn = function(x, y)
                -- Check arena bounds for shaped arenas
                if self.arena_controller.safe_zone_mode then
                    if not self:isInsideArena({x = x, y = y}) then return true end
                end
                -- Check all blocking entities (obstacles and other snake bodies)
                for _, e in ipairs(self.entity_controller:checkCollision({x = x, y = y, grid = true})) do
                    if e.category == "obstacle" then return true end
                    -- Check snake body (but allow own tail if phase_through_tail)
                    if e.category == "snake_body" then
                        if e.owner ~= snake or not self.params.phase_through_tail then
                            return true
                        end
                    end
                end
                return false
            end
            snake.direction = self.movement_controller:findGridBounceDirection(head, snake.direction, is_blocked_fn)
            local candidate = {x = head.x + snake.direction.x, y = head.y + snake.direction.y}
            -- Safety: if bounce destination is also blocked, skip movement entirely
            if is_blocked_fn(candidate.x, candidate.y) then
                skip_move = true
            else
                new_head = candidate
            end
            if is_primary then self.movement_controller:initGridState("snake", snake.direction.x, snake.direction.y) end
        end,
        death = function(entity)
            if entity.category == "food" then return end
            if entity.category == "snake_body" then
                -- Own body: check phase_through_tail
                if entity.owner == snake then
                    if self.params.phase_through_tail then return end
                    -- Skip head and neck - they can never be at new_head in grid mode
                    if entity == snake.body[1] or entity == snake.body[2] then return end
                    -- Skip orphaned entities (removed from body but still in entity_controller)
                    local in_body = false
                    for _, seg in ipairs(snake.body) do
                        if seg == entity then in_body = true; break end
                    end
                    if not in_body then
                        entity.marked_for_removal = true
                        return
                    end
                else
                    -- Other snake's body: apply snake_collision_mode
                    local other = entity.owner
                    local mode = self.params.snake_collision_mode
                    if mode == "phase_through" then return end
                    if mode == "big_eats_small" and entity.is_head and #snake.body > #other.body then
                        self.metrics.snake_length = self.metrics.snake_length + #other.body
                        other.alive = false
                        self:playSound("success", 0.8)
                        return
                    end
                    -- both_die or lost big_eats_small
                    if mode == "both_die" and entity.is_head then other.alive = false end
                end
            end
            if is_primary then self:onComplete() else snake.alive = false end
            died = true
        end
    })
    if died then return end
    if skip_move then return end  -- Trapped: wait for space to open

    -- Move chain - cascade positions, head moves to new position
    local old_tail_x, old_tail_y = self.entity_controller:moveChain(snake.body, new_head.x, new_head.y)

    -- Food collision (after move)
    local ate = false
    self.entity_controller:checkCollision({x = new_head.x, y = new_head.y, grid = true}, {
        collect = function(entity)
            ate = true
            self:collectFood(entity, snake)
            self:removeEntity(entity)
            self:_respawnFood()
        end
    })

    -- Growth: spawn new segment at old tail position
    if is_primary then
        if self.pending_growth > 0 then
            self.pending_growth = self.pending_growth - 1
            local new_segment = self.entity_controller:spawn("snake_body", old_tail_x, old_tail_y, {owner = snake})
            table.insert(snake.body, new_segment)
        end
        self.metrics.snake_length = #snake.body
    else
        if ate then
            local new_segment = self.entity_controller:spawn("snake_body", old_tail_x, old_tail_y, {owner = snake})
            table.insert(snake.body, new_segment)
        end
    end
end

--------------------------------------------------------------------------------
-- Input Handling
--------------------------------------------------------------------------------

function SnakeGame:keypressed(key)
    SnakeGame.super.keypressed(self, key)

    -- Determine direction from key
    local dir = nil
    if key == 'left' or key == 'a' then dir = {x = -1, y = 0}
    elseif key == 'right' or key == 'd' then dir = {x = 1, y = 0}
    elseif key == 'up' or key == 'w' then dir = {x = 0, y = -1}
    elseif key == 'down' or key == 's' then dir = {x = 0, y = 1}
    end
    if not dir then return false end

    -- Queue direction for each player snake
    for i, snake in ipairs(self.snakes) do
        if snake.behavior then goto continue end  -- skip AI

        local entity_id = (i == 1) and "snake" or ("snake_" .. i)
        local current_dir = (i == 1) and self.snake.direction or snake.direction

        -- Grid mode: queue direction
        if self.movement_controller:queueGridDirection(entity_id, dir.x, dir.y, current_dir) then
            if i > 1 then snake.next_direction = {x = dir.x, y = dir.y} end
        end

        -- Smooth mode: set turn flags
        local smooth_state = self.movement_controller:getSmoothState(entity_id)
        if smooth_state then
            if key == 'left' or key == 'a' then smooth_state.turn_left = true end
            if key == 'right' or key == 'd' then smooth_state.turn_right = true end
        end

        ::continue::
    end
    return true
end

function SnakeGame:keyreleased(key)
    SnakeGame.super.keyreleased(self, key)

    -- Update smooth turn flags on key release
    for i, snake in ipairs(self.snakes) do
        local entity_id = (i == 1) and "snake" or ("snake_" .. i)
        local smooth_state = self.movement_controller:getSmoothState(entity_id)
        if smooth_state then
            if key == 'left' or key == 'a' then smooth_state.turn_left = false end
            if key == 'right' or key == 'd' then smooth_state.turn_right = false end
        end
    end
end

--------------------------------------------------------------------------------
-- Smooth Movement
--------------------------------------------------------------------------------

function SnakeGame:updateSmoothMovement(dt)
    -- Safety: ensure movement controller exists and has valid state
    if not self.movement_controller then return end

    local girth = self.params.girth or 1
    local head_radius = 0.3 + (girth * 0.5)
    local food_radius = 0.35 + (girth * 0.5)

    -- Update main snake
    self:_updateSmoothSnake(self.snake, "snake", dt, head_radius, food_radius, true)

    -- Update additional player snakes (skip AI - they use grid via updateAISnakesGrid)
    for i = 2, #self.snakes do
        local psnake = self.snakes[i]
        if psnake.alive and psnake.smooth_x and not psnake.behavior then
            self:_updateSmoothSnake(psnake, "snake_" .. i, dt, head_radius, food_radius, false)
        end
    end
end

function SnakeGame:_updateSmoothSnake(snake, entity_id, dt, head_radius, food_radius, is_primary)
    -- Safety: ensure smooth state exists
    if not snake.smooth_x or not snake.smooth_y then
        snake.smooth_x = snake.body[1].x + 0.5
        snake.smooth_y = snake.body[1].y + 0.5
    end
    if not snake.smooth_trail then
        local PhysicsUtils = require('src.utils.game_components.physics_utils')
        snake.smooth_trail = PhysicsUtils.createTrailSystem({
            max_length = 0, track_distance = true, color = {1,1,1,1}, line_width = 1, angle_offset = 0
        })
        snake.smooth_target_length = self.params.smooth_initial_length or 3
    end

    -- Ensure smooth state exists (recover with current angle if missing)
    if not self.movement_controller:getSmoothState(entity_id) then
        self.movement_controller:initSmoothState(entity_id, snake.smooth_angle or 0)
    end

    -- Set auto-forward movement (snake always moves forward)
    self.movement_controller:setSmoothMovement(entity_id, true, false, false, false)

    -- Get movement delta from MovementController
    local speed = (self.params.snake_speed or 8) * 0.5
    local dx, dy = self.movement_controller:updateSmooth(dt, entity_id, speed, self.params.turn_speed)

    -- Safety: ensure we have valid movement (NaN check)
    if dx ~= dx then dx = 0 end
    if dy ~= dy then dy = 0 end

    -- Apply movement
    snake.smooth_x = snake.smooth_x + dx
    snake.smooth_y = snake.smooth_y + dy

    -- Safety: if position became NaN, reset to center
    if snake.smooth_x ~= snake.smooth_x or snake.smooth_y ~= snake.smooth_y then
        snake.smooth_x = self.grid_width / 2
        snake.smooth_y = self.grid_height / 2
    end

    snake.smooth_angle = self.movement_controller:getSmoothAngle(entity_id)

    -- Handle wrap/bounds
    local wrapped, out_of_bounds = false, false
    local wrap = (self.params.wall_mode == "wrap")
    if wrap then
        if snake.smooth_x < 0 then snake.smooth_x = snake.smooth_x + self.grid_width; wrapped = true end
        if snake.smooth_x >= self.grid_width then snake.smooth_x = snake.smooth_x - self.grid_width; wrapped = true end
        if snake.smooth_y < 0 then snake.smooth_y = snake.smooth_y + self.grid_height; wrapped = true end
        if snake.smooth_y >= self.grid_height then snake.smooth_y = snake.smooth_y - self.grid_height; wrapped = true end
    else
        if snake.smooth_x < 0 or snake.smooth_x >= self.grid_width or
           snake.smooth_y < 0 or snake.smooth_y >= self.grid_height then
            out_of_bounds = true
        end
    end

    -- Trail management
    if wrapped then snake.smooth_trail:clear() end
    snake.smooth_trail:addPoint(snake.smooth_x, snake.smooth_y, math.sqrt(dx*dx + dy*dy))
    snake.smooth_trail:trimToDistance(snake.smooth_target_length)

    -- Arena bounds check (shaped arenas use polygon, rectangular uses out_of_bounds)
    if self.params.wall_mode == "death" then
        local outside = false
        if self.arena_controller.safe_zone_mode and self.arena_controller.vertices and #self.arena_controller.vertices > 0 then
            -- Shaped/custom arena: use polygon collision
            outside = not self:isInsideArena({x = snake.smooth_x, y = snake.smooth_y}, nil, true)
        else
            -- Rectangle: use simple bounds check
            outside = out_of_bounds
        end
        if outside then
            if is_primary then self:onComplete() else snake.alive = false end
            return
        end
    end

    -- Self-collision (trail-specific)
    if is_primary and not self.params.phase_through_tail then
        if snake.smooth_trail:checkSelfCollision(snake.smooth_x, snake.smooth_y, self.params.girth or 1, {
            skip_multiplier = 1.0, collision_base = 0.1, collision_multiplier = 0.3
        }) then
            self:onComplete()
            return
        end
    end

    -- Entity collisions (food, obstacles, walls)
    local died = false
    self.entity_controller:checkCollision(
        {x = snake.smooth_x, y = snake.smooth_y, radius = head_radius},
        {
            collect = function(entity)
                self:collectFood(entity, snake)
                if is_primary then self.metrics.snake_length = math.floor(snake.smooth_target_length) end
                self:removeEntity(entity)
                self:_respawnFood()
            end,
            bounce = function()
                snake.smooth_angle = self:_findBounceAngle(snake.smooth_x, snake.smooth_y, snake.smooth_angle)
                self.movement_controller:setSmoothAngle(entity_id, snake.smooth_angle)
                snake.smooth_x = snake.smooth_x + math.cos(snake.smooth_angle) * 0.2
                snake.smooth_y = snake.smooth_y + math.sin(snake.smooth_angle) * 0.2
            end,
            death = function(entity)
                -- Skip own body segments (grid head entity)
                if entity.category == "snake_body" and entity.owner == snake then return end
                if is_primary then self:onComplete() else snake.alive = false end
                died = true
            end
        }
    )
    if died then return end

    -- Update body[1] position for camera/fog tracking
    snake.body[1].x = math.floor(snake.smooth_x)
    snake.body[1].y = math.floor(snake.smooth_y)
end

function SnakeGame:_findBounceAngle(x, y, current_angle)
    local angle1, angle2 = current_angle + math.rad(45), current_angle - math.rad(45)
    local function checkSpace(angle)
        for step = 1, 10 do
            local dist = step * 0.5
            local cx, cy = x + math.cos(angle) * dist, y + math.sin(angle) * dist
            for _, obs in ipairs(self:getObstacles()) do
                if PhysicsUtils.circleCollision(cx, cy, 0.1, obs.x + 0.5, obs.y + 0.5, 0.5) then return step - 1 end
            end
            if self.arena_controller.safe_zone_mode and not self:isInsideArena({x = cx, y = cy}, nil, true) then
                return step - 1
            end
        end
        return 10
    end
    return checkSpace(angle1) >= checkSpace(angle2) and angle1 or angle2
end

--------------------------------------------------------------------------------
-- Arena & Walls
--------------------------------------------------------------------------------

function SnakeGame:createEdgeObstacles()
    -- Skip edge walls for wrap mode or shaped/custom arenas (they use polygon collision)
    if self.params.wall_mode == "wrap" or self.arena_controller.safe_zone_mode then return end

    local wall_type = (self.params.wall_mode == "bounce") and "wall_bounce" or "wall_death"
    local cells = self.arena_controller:getBoundaryCells(self.grid_width, self.grid_height)
    local occupied = {}
    for _, seg in ipairs(self.snake.body or {}) do occupied[seg.x .. "," .. seg.y] = true end

    for _, cell in ipairs(cells) do
        if not occupied[cell.x .. "," .. cell.y] then
            self.entity_controller:spawn(wall_type, cell.x, cell.y)
        end
    end
end

function SnakeGame:onArenaShrink(margins)
    -- Spawn wall entities for shrinking arena
    for y = 0, self.grid_height - 1 do
        self.entity_controller:spawn("wall_death", margins.left - 1, y)
        self.entity_controller:spawn("wall_death", self.grid_width - margins.right, y)
    end
    for x = 0, self.grid_width - 1 do
        self.entity_controller:spawn("obstacle_static", x, margins.top - 1, {type = "walls", category = "obstacle"})
        self.entity_controller:spawn("obstacle_static", x, self.grid_height - margins.bottom, {type = "walls", category = "obstacle"})
    end
end

function SnakeGame:isInsideArena(pos, margin, is_smooth)
    if is_smooth then
        -- Smooth mode: position is already a precise float, check directly
        return self.arena_controller:isInside(pos.x, pos.y, margin)
    end
    return self.arena_controller:isInsideGrid(pos.x, pos.y, margin)
end

--------------------------------------------------------------------------------
-- Girth System (Snake-Specific)
--------------------------------------------------------------------------------

function SnakeGame:getGirthCells(center_pos, girth_value, direction)
    -- Returns all grid cells occupied by a segment with given girth
    -- Girth creates width perpendicular to movement direction
    -- Girth 1 = 1 cell, Girth 2 = 2 cells side-by-side, Girth 3 = 3 cells, etc.
    local cells = {}
    local girth = girth_value or self.params.girth or 1

    -- If no direction provided, just return center cell (for food/obstacles)
    if not direction then
        table.insert(cells, {x = center_pos.x, y = center_pos.y})
        return cells
    end

    -- Determine perpendicular offset direction
    -- If moving horizontally (dx != 0), add cells vertically
    -- If moving vertically (dy != 0), add cells horizontally
    local perp_dx, perp_dy
    if direction.x ~= 0 then
        -- Moving horizontally, expand vertically
        perp_dx = 0
        perp_dy = 1
    else
        -- Moving vertically (or stationary), expand horizontally
        perp_dx = 1
        perp_dy = 0
    end

    -- Calculate offset from center
    local offset = math.floor((girth - 1) / 2)

    -- Add cells perpendicular to movement
    for i = -offset, girth - 1 - offset do
        table.insert(cells, {
            x = center_pos.x + (i * perp_dx),
            y = center_pos.y + (i * perp_dy)
        })
    end

    return cells
end

function SnakeGame:collectFood(food, snake)
    local growth = (food.growth or 1) * self.params.growth_per_food

    -- Apply growth (negative for bad food)
    if self.params.use_trail then
        snake.smooth_target_length = math.max(0.1, snake.smooth_target_length + growth)
    elseif growth > 0 then
        self.pending_growth = self.pending_growth + growth
    else
        for _ = 1, math.min(-growth, #snake.body - 1) do
            local removed = table.remove(snake.body)
            if removed then self.entity_controller:removeEntity(removed) end
        end
    end

    -- Speed/sound/girth only for good food
    if growth > 0 then
        if self.params.speed_increase_per_food > 0 then
            self.params.snake_speed = self.params.snake_speed + self.params.speed_increase_per_food
        end
        self:playSound(food.type == "golden" and "success" or "eat", 0.7)

        if self.visual_effects and self.visual_effects.particles then
            local GRID_SIZE = self.GRID_SIZE or 20
            local fx = food.x * GRID_SIZE + GRID_SIZE / 2
            local fy = food.y * GRID_SIZE + GRID_SIZE / 2
            local color = food.type == "golden" and {1, 0.85, 0.2} or {0.2, 1, 0.2}
            self.visual_effects.particles:emit(fx, fy, 8, "sparkle", {
                color = color, speed = 60, lifetime = 0.5, size = 3, friction = 0.93
            })
        end
        if self.params.girth_growth > 0 then
            self.segments_for_next_girth = self.segments_for_next_girth - 1
            if self.segments_for_next_girth <= 0 then
                self.params.girth = self.params.girth + 1
                self.segments_for_next_girth = self.params.girth_growth
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Collision & Spawning
--------------------------------------------------------------------------------

function SnakeGame:checkCollision(pos)
    if not pos then return false end

    -- Check arena bounds for shaped/custom arenas (no wall entities)
    if self.arena_controller.safe_zone_mode and not self:isInsideArena(pos) then
        return true
    end

    -- Get all cells occupied by this position with current girth
    local direction = self.snake and self.snake.direction or {x = 1, y = 0}
    local pos_cells = self:getGirthCells(pos, self.params.girth, direction)

    -- Check obstacle collision (self-collision handled via entity system)
    for _, obstacle in ipairs(self:getObstacles()) do
        for _, cell in ipairs(pos_cells) do
            if cell.x == obstacle.x and cell.y == obstacle.y then
                return true
            end
        end
    end

    return false
end

-- Translate schema shape name to polygon sides and rotation
function SnakeGame:getShapeSides(shape_name)
    if shape_name == "circle" then
        return 32, 0
    elseif shape_name == "hexagon" or shape_name == "hex" then
        return 6, math.pi / 6  -- flat-top hex for grid alignment
    elseif shape_name == "square" then
        return 4, math.pi / 4
    elseif type(shape_name) == "number" then
        return shape_name, 0
    else
        return 4, 0  -- rectangle default (4 sides)
    end
end

return SnakeGame