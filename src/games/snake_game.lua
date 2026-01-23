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
local SnakeGame = BaseGame:extend('SnakeGame')

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function SnakeGame:init(game_data, cheats, di, variant_override)
    SnakeGame.super.init(self, game_data, cheats, di, variant_override)
    self.runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.snake) or {}
    self.params = self.di.components.SchemaLoader.load(self.variant, "snake_schema", self.runtimeCfg)
    self.GRID_SIZE = self.runtimeCfg.grid_size or 20

    self:applyCheats({
        speed_modifier = {"snake_speed", "ai_speed", "food_speed"},
        advantage_modifier = {"victory_limit", "food_count"},
        performance_modifier = {"obstacle_count", "ai_snake_count"}
    })

    self:setupArena()
    self:createEntityControllerFromSchema()
    self:createComponentsFromSchema()  -- Creates arena_controller early, needed by setupSnake
    self:setupSnake()
    self:setupComponents()  -- Configures arena_controller and movement_controller (needs self.snakes)

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
        smooth_trail = PhysicsUtils.createTrailSystem({track_distance = true}),
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
        self.entity_controller:spawnMultiple(count, function() self:spawnObstacleEntity() end)
        self._obstacles_created = true
    end
end

function SnakeGame:_spawnInitialFood()
    if #self:getFoods() == 0 and not self._foods_spawned then
        self.entity_controller:spawnMultiple(self.params.food_count, function() self:spawnFoodEntity() end)
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

    -- Set computed arena values (must set base_width/current_width, not just width)
    self.arena_controller.base_width = self.grid_width
    self.arena_controller.base_height = self.grid_height
    self.arena_controller.current_width = self.grid_width
    self.arena_controller.current_height = self.grid_height
    self.arena_controller.min_width = math.max(self.params.min_arena_cells, math.floor(self.grid_width * self.params.min_arena_ratio))
    self.arena_controller.min_height = math.max(self.params.min_arena_cells, math.floor(self.grid_height * self.params.min_arena_ratio))
    -- Set center and radius for shaped arenas (used by isInside and drawBoundary)
    self.arena_controller.x = self.grid_width / 2
    self.arena_controller.y = self.grid_height / 2
    self.arena_controller.radius = math.min(self.grid_width, self.grid_height) / 2 - 1
    self.arena_controller.initial_radius = self.arena_controller.radius
    self.arena_controller.safe_zone_mode = (self.params.arena_shape ~= "rectangle")
    self.arena_controller.on_shrink = function(margins) self:onArenaShrink(margins) end

    for i, psnake in ipairs(self.snakes) do
        local entity_id = (i == 1) and "snake" or ("snake_" .. i)
        self.movement_controller:initState(entity_id, psnake.direction)
    end
    self.metrics.snake_length, self.metrics.survival_time = 1, 0
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
        self.entity_controller:spawnMultiple(self.params.food_count, function() self:spawnFoodEntity() end)
    end
end

function SnakeGame:_getFoodType()
    if math.random() < self.params.golden_food_spawn_rate then return "food_golden" end
    if math.random() < self.params.bad_food_chance then return "food_bad" end
    return "food_normal"
end

function SnakeGame:spawnFoodEntity()
    -- Safeguard: ensure valid grid dimensions
    if not self.grid_width or not self.grid_height or self.grid_width < 3 or self.grid_height < 3 then
        return nil
    end
    -- Spawn inside the playable area (avoid boundary cells where walls exist)
    local margin = (self.params.wall_mode == "wrap") and 0 or 1
    local bounds = {
        min_x = margin,
        max_x = self.grid_width - 1 - margin,
        min_y = margin,
        max_y = self.grid_height - 1 - margin,
        is_grid = true
    }
    return self.entity_controller:spawnWithPattern(self:_getFoodType(), self.params.food_spawn_pattern or "random", {
        bounds = bounds,
        is_valid_fn = function(x, y) return not self:checkCollision({x = x, y = y}) end,
        category = "food",
        position = math.floor(self.grid_height / 2)  -- for line pattern
    }, {lifetime = 0, category = "food"})
end

function SnakeGame:spawnObstacleEntity()
    local type_name = self.params.obstacle_type == "moving_blocks" and "obstacle_moving" or "obstacle_static"
    local bounds = {min_x = 0, max_x = self.grid_width - 1, min_y = 0, max_y = self.grid_height - 1, is_grid = true}
    local custom = {category = "obstacle", type = self.params.obstacle_type}
    if self.params.obstacle_type == "moving_blocks" then
        custom.vx, custom.vy = math.random() < 0.5 and 1 or -1, 0
    end
    return self.entity_controller:spawnWithPattern(type_name, "random", {
        bounds = bounds,
        is_valid_fn = function(x, y) return not self:checkCollision({x = x, y = y}) end
    }, custom)
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
            self.grid_width = math.floor(self.game_width / effective_tile_size)
            self.grid_height = math.floor(self.game_height / effective_tile_size)

            self.arena_controller.base_width = self.grid_width
            self.arena_controller.base_height = self.grid_height
            self.arena_controller.current_width = self.grid_width
            self.arena_controller.current_height = self.grid_height

            self:_regenerateEdgeObstacles()
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

function SnakeGame:updateGameLogic(dt)
    self.metrics.survival_time = self.time_elapsed

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

    -- Shrinking over time
    if self.params.shrink_over_time > 0 and #self.snake.body > 1 and self.entity_controller:tickTimer(self, "shrink_timer", self.params.shrink_over_time, dt) then
        table.remove(self.snake.body)
        self.metrics.snake_length = #self.snake.body
        if #self.snake.body == 0 then self:onComplete(); return end
    end

    -- Update moving obstacles
    for _, obs in ipairs(self:getObstacles()) do
        if obs.vx and self.entity_controller:tickTimer(obs, "move_timer", 2, dt) then
            obs.x, obs.y = obs.x + obs.vx, obs.y + (obs.vy or 0)
            PhysicsUtils.handleBounds(obs, {width = self.grid_width, height = self.grid_height}, {mode = "bounce"})
        end
    end

    -- Obstacle spawning over time
    if self.params.obstacle_spawn_over_time > 0 and self.entity_controller:tickTimer(self, "obstacle_spawn_timer", self.params.obstacle_spawn_over_time, dt) then
        self:spawnObstacleEntity()
    end

    -- Check collisions between snakes
    self:checkSnakeCollisions()

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

    -- Check collisions at proposed position (walls/obstacles before moving)
    local died = false
    self.entity_controller:checkCollision({x = new_head.x, y = new_head.y, grid = true}, {
        bounce = function()
            snake.direction = self.movement_controller:findGridBounceDirection(
                head, snake.direction, function(x, y)
                    for _, e in ipairs(self.entity_controller:checkCollision({x = x, y = y, grid = true})) do
                        if e.category == "obstacle" then return true end
                    end
                    return false
                end)
            if is_primary then self.movement_controller:initGridState("snake", snake.direction.x, snake.direction.y) end
            new_head = {x = head.x + snake.direction.x, y = head.y + snake.direction.y}
        end,
        death = function(entity)
            -- Skip food (has its own collect handler)
            if entity.category == "food" then return end
            -- Snake body: check phase_through_tail
            if entity.category == "snake_body" then
                if self.params.phase_through_tail then return end
            end
            if is_primary then self:onComplete() else snake.alive = false end
            died = true
        end
    })
    if died then return end

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
    return self.movement_controller:handleInput(key, self.snakes, self.snake.direction)
end

function SnakeGame:keyreleased(key)
    SnakeGame.super.keyreleased(self, key)
    self.movement_controller:handleInputRelease(key, self.snakes)
end

--------------------------------------------------------------------------------
-- Smooth Movement
--------------------------------------------------------------------------------

function SnakeGame:updateSmoothMovement(dt)
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
    -- Movement via MovementController
    local entity = {x = snake.smooth_x, y = snake.smooth_y}
    local bounds = {
        width = self.grid_width, height = self.grid_height,
        wrap_x = (self.params.wall_mode == "wrap"), wrap_y = (self.params.wall_mode == "wrap")
    }
    local speed = (self.params.snake_speed or 8) * 0.5

    local dx, dy, wrapped, out_of_bounds = self.movement_controller:updateSmooth(
        dt, entity_id, entity, bounds, speed, self.params.turn_speed)
    snake.smooth_x, snake.smooth_y = entity.x, entity.y
    snake.smooth_angle = self.movement_controller:getSmoothAngle(entity_id)

    -- Trail management
    if wrapped then snake.smooth_trail:clear() end
    snake.smooth_trail:addPoint(snake.smooth_x, snake.smooth_y, math.sqrt(dx*dx + dy*dy))
    snake.smooth_trail:trimToDistance(snake.smooth_target_length)

    -- Arena bounds check
    if self.params.wall_mode == "death" and out_of_bounds then
        if is_primary then self:onComplete() else snake.alive = false end
        return
    end

    -- Self-collision (trail-specific)
    if is_primary and not self.params.phase_through_tail then
        if snake.smooth_trail:checkSelfCollision(snake.smooth_x, snake.smooth_y, self.params.girth or 1) then
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
            if self.params.arena_shape ~= "rectangle" and not self:isInsideArena({x = cx - 0.5, y = cy - 0.5}) then
                return step - 1
            end
        end
        return 10
    end
    return checkSpace(angle1) >= checkSpace(angle2) and angle1 or angle2
end

function SnakeGame:checkSnakeCollisions()
    -- Check collisions between primary player snake and other snakes
    local player_head = self.snake.body[1]

    for _, other in ipairs(self.snakes) do
        if other ~= self.snake and other.alive then
            local other_head = other.body[1]

            -- Check head-to-head collision
            if player_head.x == other_head.x and player_head.y == other_head.y then
                if self.params.snake_collision_mode == "both_die" then
                    self.snake.alive = false
                    other.alive = false
                    self:onComplete()
                elseif self.params.snake_collision_mode == "big_eats_small" then
                    if #self.snake.body > #other.body then
                        self.metrics.snake_length = self.metrics.snake_length + #other.body
                        other.alive = false
                        self:playSound("success", 0.8)
                    else
                        self.snake.alive = false
                        self:onComplete()
                    end
                end
            end

            -- Check if player head hits other snake's body
            for _, segment in ipairs(other.body) do
                if player_head.x == segment.x and player_head.y == segment.y then
                    if self.params.snake_collision_mode ~= "phase_through" then
                        self.snake.alive = false
                        self:onComplete()
                    end
                    break
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Arena & Walls
--------------------------------------------------------------------------------

function SnakeGame:createEdgeObstacles()
    -- No walls for wrap mode or shaped arenas (shaped use bounds check, not entities)
    if self.params.wall_mode == "wrap" or self.params.arena_shape ~= "rectangle" then return end

    local wall_entity_type = (self.params.wall_mode == "bounce") and "wall_bounce" or "wall_death"
    local boundary_cells = self.arena_controller:getBoundaryCells(self.grid_width, self.grid_height)

    -- Build set of snake positions to avoid
    local snake_positions = {}
    for _, segment in ipairs(self.snake.body or {}) do
        snake_positions[segment.x .. "," .. segment.y] = true
    end

    for _, cell in ipairs(boundary_cells) do
        if not snake_positions[cell.x .. "," .. cell.y] then
            self.entity_controller:spawn(wall_entity_type, cell.x, cell.y)
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

function SnakeGame:isInsideArena(pos, margin)
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
    local growth = (food.size or 1) * self.params.growth_per_food
    local speed_mult = (food.type == "golden") and 2 or 1

    if food.type == "bad" then
        if self.params.use_trail then
            snake.smooth_target_length = math.max(0.1, snake.smooth_target_length - 3)
        else
            local body = snake.body or self.snake.body
            for _ = 1, math.min(3, #body - 1) do
                if #body > 1 then table.remove(body) end
            end
        end
    else
        if self.params.use_trail then
            snake.smooth_target_length = snake.smooth_target_length + growth
        else
            self.pending_growth = self.pending_growth + growth
        end
        if self.params.speed_increase_per_food > 0 then
            self.params.snake_speed = self.params.snake_speed + (self.params.speed_increase_per_food * speed_mult)
        end
        self:playSound(food.type == "golden" and "success" or "eat", food.type == "golden" and 0.6 or 0.8)
    end

    if self.params.girth_growth > 0 and food.type ~= "bad" then
        self.segments_for_next_girth = self.segments_for_next_girth - 1
        if self.segments_for_next_girth <= 0 then
            self.params.girth = self.params.girth + 1
            self.segments_for_next_girth = self.params.girth_growth
        end
    end
end

--------------------------------------------------------------------------------
-- Collision & Spawning
--------------------------------------------------------------------------------

function SnakeGame:checkCollision(pos)
    if not pos then return false end

    -- Check arena bounds for shaped arenas (no wall entities)
    if self.params.arena_shape ~= "rectangle" and not self:isInsideArena(pos) then
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

return SnakeGame