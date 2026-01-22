local BaseGame = require('src.games.base_game')
local SnakeView = require('src.games.views.snake_view')
local PhysicsUtils = require('src.utils.game_components.physics_utils')
local SnakeGame = BaseGame:extend('SnakeGame')

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
    self:createEntityControllerFromSchema()  -- Create entity_controller before setupSnake (AI uses it)
    self:setupSnake()
    self:setupComponents()

    self.view = SnakeView:new(self, self.variant)
    self:loadAssets()
end

function SnakeGame:setupArena()
    self:setupArenaDimensions()
    self.grid_width = math.floor(self.game_width / (self.GRID_SIZE * self.camera_zoom))
    self.grid_height = math.floor(self.game_height / (self.GRID_SIZE * self.camera_zoom))
    print(string.format("[setupArena] game=%dx%d grid=%dx%d GRID_SIZE=%d fixed=%s zoom=%s wall_mode=%s",
        self.game_width, self.game_height, self.grid_width, self.grid_height,
        self.GRID_SIZE, tostring(self.is_fixed_arena), tostring(self.camera_zoom), tostring(self.params.wall_mode)))
end

function SnakeGame:_initSmoothState(x, y)
    return {
        smooth_x = x + 0.5, smooth_y = y + 0.5, smooth_angle = 0,
        smooth_trail = PhysicsUtils.createTrailSystem({track_distance = true}),
        smooth_target_length = self.params.smooth_initial_length
    }
end

function SnakeGame:_checkSpawnSafety(pos)
    -- Returns true if position would kill the snake
    if self.params.arena_shape == "circle" or self.params.arena_shape == "hexagon" then
        if not self:isInsideArena(pos) then return true end
    end
    if self.params.movement_type == "smooth" then
        local smooth_x, smooth_y = pos.x + 0.5, pos.y + 0.5
        local girth_scale = self.params.girth or 1
        local collision_dist = 0.3 + (girth_scale * 0.5)
        for _, obs in ipairs(self:getObstacles()) do
            local dx, dy = smooth_x - (obs.x + 0.5), smooth_y - (obs.y + 0.5)
            if math.sqrt(dx*dx + dy*dy) < collision_dist then return true end
        end
    else
        if self:checkCollision(pos, false) then return true end
    end
    return false
end

function SnakeGame:_repositionSnakeAt(spawn_x, spawn_y)
    self.snake.body[1].x, self.snake.body[1].y = spawn_x, spawn_y
    local dir_x, dir_y = self:getCardinalDirection(spawn_x, spawn_y,
        math.floor(self.grid_width / 2), math.floor(self.grid_height / 2))
    self.snake.direction = {x = dir_x, y = dir_y}
    if self.params.movement_type == "smooth" then
        self.snake.smooth_x, self.snake.smooth_y = spawn_x + 0.5, spawn_y + 0.5
        self.snake.smooth_angle = math.atan2(dir_y, dir_x)
    end
    self.movement_controller:initGridState("snake", dir_x, dir_y)
end

function SnakeGame:_repositionAISnakesInArena(min_x, max_x, min_y, max_y)
    if not (self.params.arena_shape == "circle" or self.params.arena_shape == "hexagon") then return end
    if not self.ai_snakes then return end
    for _, ai_snake in ipairs(self.ai_snakes) do
        if ai_snake.alive and ai_snake.body and #ai_snake.body > 0 then
            if not self:isInsideArena(ai_snake.body[1]) then
                local x, y = self:findSafePosition(min_x, max_x, min_y, max_y, function(x, y)
                    return self:isInsideArena({x = x, y = y}) and not self:checkCollision({x = x, y = y}, false)
                end, 100)
                ai_snake.body[1].x, ai_snake.body[1].y = x, y
            end
        end
    end
end

function SnakeGame:_initializeObstacles()
    if not self._obstacles_created then
        local count = math.floor(self.params.obstacle_count * self.difficulty_modifiers.complexity)
        for _ = 1, count do
            self:spawnObstacleEntity()
        end
        self._obstacles_created = true
    end
    self:createEdgeObstacles()
end

function SnakeGame:_spawnInitialFood()
    if #self:getFoods() == 0 and not self._foods_spawned then
        for _ = 1, self.params.food_count do
            self:spawnFoodEntity()
        end
        self._foods_spawned = true
    end
end

function SnakeGame:_clampPositionsToSafe(min_x, max_x, min_y, max_y)
    -- Clamp snake body
    if self.snake and self.snake.body then
        for _, segment in ipairs(self.snake.body) do
            segment.x = math.max(min_x, math.min(max_x, segment.x))
            segment.y = math.max(min_y, math.min(max_y, segment.y))
        end
    end
    -- Clamp food
    for _, food in ipairs(self:getFoods()) do
        food.x = math.max(min_x, math.min(max_x, food.x))
        food.y = math.max(min_y, math.min(max_y, food.y))
    end
end

function SnakeGame:_regenerateEdgeObstacles()
    -- Remove wall entities
    for _, obs in ipairs(self:getObstacles()) do
        if obs.type == "walls" or obs.type == "bounce_wall" then
            self:removeObstacle(obs)
        end
    end
    self:_initializeObstacles()
end

function SnakeGame:setupSnake()
    local cx, cy = math.floor(self.grid_width / 2), math.floor(self.grid_height / 2)
    local dir = BaseGame.CARDINAL_DIRECTIONS[self.params.starting_direction] or BaseGame.CARDINAL_DIRECTIONS.right

    self.player_snakes = {}
    for i = 1, self.params.snake_count do
        local sx, sy = cx + (i - 1) * self.params.multi_snake_spacing, cy
        local snake = {
            body = {{x = sx, y = sy}},
            direction = {x = dir.x, y = dir.y},
            next_direction = {x = dir.x, y = dir.y},
            alive = true
        }
        if self.params.movement_type == "smooth" then
            for k, v in pairs(self:_initSmoothState(sx, sy)) do snake[k] = v end
        end
        table.insert(self.player_snakes, snake)
    end
    self.snake = self.player_snakes[1]
    self._snake_needs_spawn = true

    self.segments_for_next_girth = self.params.girth_growth
    self.pending_growth = 0
    self.shrink_timer, self.obstacle_spawn_timer = 0, 0
    self.ai_snakes = {}
    self.foods, self.obstacles = {}, {}
end

function SnakeGame:setupComponents()
    self:createComponentsFromSchema()
    -- Note: entity_controller already created in init before setupSnake
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

    for i, psnake in ipairs(self.player_snakes) do
        local entity_id = (i == 1) and "snake" or ("snake_" .. i)
        if self.params.movement_type == "smooth" then
            self.movement_controller:initSmoothState(entity_id, psnake.smooth_angle or 0)
        else
            self.movement_controller:initGridState(entity_id, psnake.direction.x, psnake.direction.y)
        end
    end
    self.metrics.snake_length, self.metrics.survival_time = 1, 0

    -- Create AI snakes (after arena_controller exists for isInsideArena)
    for i = 1, self.params.ai_snake_count do
        table.insert(self.ai_snakes, self:createAISnake(i))
    end
end

-- Entity helpers - delegate to EntityController
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

function SnakeGame:_getFoodType()
    if math.random() < self.params.golden_food_spawn_rate then return "food_golden" end
    if math.random() < self.params.bad_food_chance then return "food_bad" end
    return "food_normal"
end

function SnakeGame:spawnFoodEntity()
    local bounds = {min_x = 0, max_x = self.grid_width - 1, min_y = 0, max_y = self.grid_height - 1, is_grid = true}
    return self.entity_controller:spawnWithPattern(self:_getFoodType(), self.params.food_spawn_pattern or "random", {
        bounds = bounds,
        is_valid_fn = function(x, y) return not self:checkCollision({x = x, y = y}, true) end,
        category = "food",
        position = math.floor(self.grid_height / 2)  -- for line pattern
    }, {lifetime = 0, category = "food"})
end

function SnakeGame:spawnObstacleEntity()
    local type_name = self.params.obstacle_type == "moving_blocks" and "obstacle_moving" or "obstacle_static"
    local bounds = {min_x = 0, max_x = self.grid_width - 1, min_y = 0, max_y = self.grid_height - 1, is_grid = true}
    local custom = {category = "obstacle", type = self.params.obstacle_type}
    if self.params.obstacle_type == "moving_blocks" then
        custom.move_dir_x, custom.move_dir_y, custom.move_timer = math.random() < 0.5 and 1 or -1, 0, 0
    end
    return self.entity_controller:spawnWithPattern(type_name, "random", {
        bounds = bounds,
        is_valid_fn = function(x, y)
            for _, seg in ipairs(self.snake.body) do
                if x == seg.x and y == seg.y then return false end
            end
            return true
        end
    }, custom)
end

function SnakeGame:setPlayArea(width, height)
    self.viewport_width, self.viewport_height = width, height
    print(string.format("[setPlayArea] viewport=%dx%d game=%dx%d grid=%dx%d fixed=%s",
        width, height, self.game_width or 0, self.game_height or 0, self.grid_width or 0, self.grid_height or 0, tostring(self.is_fixed_arena)))

    if self.is_fixed_arena then
        self:_initializeObstacles()
        print(string.format("[setPlayArea fixed] total obstacles=%d", #self:getObstacles()))
        if self._snake_needs_spawn then
            self:_spawnSnakeSafe()
            self._snake_needs_spawn = false
        end
        if self.snake and #self.snake.body > 0 and self:_checkSpawnSafety(self.snake.body[1]) then
            local x, y = self:findSafePosition(0, self.grid_width - 1, 0, self.grid_height - 1,
                function(x, y) return not self:_checkSpawnSafety({x = x, y = y}) end)
            self:_repositionSnakeAt(x, y)
        end
        self:_repositionAISnakesInArena(0, self.grid_width - 1, 0, self.grid_height - 1)
        self:_spawnInitialFood()
    else
        self.game_width, self.game_height = width, height
        if self.GRID_SIZE then
            local effective_tile_size = self.GRID_SIZE * (self.params.camera_zoom or 1.0)
            self.grid_width = math.floor(self.game_width / effective_tile_size)
            self.grid_height = math.floor(self.game_height / effective_tile_size)

            -- Update arena_controller with new grid dimensions
            self.arena_controller.base_width = self.grid_width
            self.arena_controller.base_height = self.grid_height
            self.arena_controller.current_width = self.grid_width
            self.arena_controller.current_height = self.grid_height

            self:_clampPositionsToSafe(0, self.grid_width - 1, 0, self.grid_height - 1)
            self:_regenerateEdgeObstacles()
            if self._snake_needs_spawn then
                self:_spawnSnakeSafe()
                self._snake_needs_spawn = false
            end
            if self.snake and #self.snake.body > 0 and self:_checkSpawnSafety(self.snake.body[1]) then
                local x, y = self:findSafePosition(0, self.grid_width - 1, 0, self.grid_height - 1,
                    function(x, y) return not self:_checkSpawnSafety({x = x, y = y}) end)
                self:_repositionSnakeAt(x, y)
            end
            self:_repositionAISnakesInArena(0, self.grid_width - 1, 0, self.grid_height - 1)
            self:_spawnInitialFood()
            print(string.format("[setPlayArea END] game=%dx%d grid=%dx%d", self.game_width, self.game_height, self.grid_width, self.grid_height))
        end
    end
end

function SnakeGame:updateGameLogic(dt)
    self.metrics.survival_time = self.time_elapsed

    -- Update food movement
    if self.params.food_movement ~= "static" then
        for _, food in ipairs(self:getFoods()) do
            -- Add movement timer if not exists
            food.move_timer = (food.move_timer or 0) + dt
            local move_interval = 1 / self.params.food_speed  -- Food moves N times per second based on food_speed

            if food.move_timer >= move_interval then
                food.move_timer = food.move_timer - move_interval

                local new_x, new_y = food.x, food.y

                if self.params.food_movement == "drift" then
                    -- Random wandering
                    local dir = math.random(1, 4)
                    if dir == 1 then new_x = new_x + 1
                    elseif dir == 2 then new_x = new_x - 1
                    elseif dir == 3 then new_y = new_y + 1
                    else new_y = new_y - 1 end

                elseif self.params.food_movement == "flee_from_snake" then
                    -- Move away from snake head
                    local head = self.snake.body[1]
                    if head.x < food.x then new_x = food.x + 1
                    elseif head.x > food.x then new_x = food.x - 1 end
                    if head.y < food.y then new_y = food.y + 1
                    elseif head.y > food.y then new_y = food.y - 1 end

                elseif self.params.food_movement == "chase_snake" then
                    -- Move toward snake head
                    local head = self.snake.body[1]
                    if head.x > food.x then new_x = food.x + 1
                    elseif head.x < food.x then new_x = food.x - 1 end
                    if head.y > food.y then new_y = food.y + 1
                    elseif head.y < food.y then new_y = food.y - 1 end
                end

                -- Wrap coordinates
                new_x, new_y = self:wrapPosition(new_x, new_y, self.grid_width, self.grid_height)

                -- Only move if not colliding with obstacles or snake
                if not self:checkCollision({x = new_x, y = new_y}, true) then
                    food.x = new_x
                    food.y = new_y

                    -- Check if food moved into any snake (player or AI)
                    local collected = false

                    -- Check all player snakes
                    for _, player_snake in ipairs(self.player_snakes or {self.snake}) do
                        if player_snake.alive ~= false then
                            local snake_body = player_snake.body or player_snake
                            for _, segment in ipairs(snake_body) do
                                if segment.x == food.x and segment.y == food.y then
                                    -- Food moved into this snake - collect it
                                    self:collectFood(food, player_snake)
                                    collected = true
                                    break
                                end
                            end
                            if collected then break end
                        end
                    end

                    -- Check AI snakes
                    if not collected and self.ai_snakes then
                        for _, ai_snake in ipairs(self.ai_snakes) do
                            if ai_snake.alive and ai_snake.body then
                                for _, segment in ipairs(ai_snake.body) do
                                    if segment.x == food.x and segment.y == food.y then
                                        -- Food moved into AI snake
                                        ai_snake.length = ai_snake.length + 1
                                        collected = true
                                        break
                                    end
                                end
                                if collected then break end
                            end
                        end
                    end

                    -- If collected, remove and respawn based on spawn mode
                    if collected then
                        self:removeFood(food)
                        if self.params.food_spawn_mode == "continuous" then
                            self:spawnFoodEntity()
                        elseif self.params.food_spawn_mode == "batch" and #self:getFoods() == 0 then
                            for _ = 1, self.params.food_count do self:spawnFoodEntity() end
                        end
                    end
                end
            end
        end
    end

    -- Update food lifetime (despawn expired foods)
    if self.params.food_lifetime > 0 then
        for _, food in ipairs(self:getFoods()) do
            food.lifetime = (food.lifetime or 0) + dt
            if food.lifetime >= self.params.food_lifetime then
                self:removeFood(food)
                self:spawnFoodEntity()
            end
        end
    end

    -- Shrinking over time
    if self.params.shrink_over_time > 0 and #self.snake.body > 1 then
        self.shrink_timer = self.shrink_timer + dt
        local shrink_interval = 1 / self.params.shrink_over_time  -- segments per second
        if self.shrink_timer >= shrink_interval then
            self.shrink_timer = self.shrink_timer - shrink_interval
            table.remove(self.snake.body)  -- Remove tail segment
            self.metrics.snake_length = #self.snake.body
            -- Die if shrunk to nothing
            if #self.snake.body == 0 then
                self:playSound("death", 1.0)
                self:onComplete()
                return
            end
        end
    end

    -- Update moving obstacles
    for _, obstacle in ipairs(self:getObstacles()) do
        if obstacle.type == "moving_blocks" then
            obstacle.move_timer = obstacle.move_timer + dt
            if obstacle.move_timer >= 0.5 then  -- Move every 0.5 seconds
                obstacle.move_timer = 0

                local new_x = obstacle.x + obstacle.move_dir_x
                local new_y = obstacle.y + obstacle.move_dir_y

                -- Bounce off walls
                if new_x < 0 or new_x >= self.grid_width then
                    obstacle.move_dir_x = -obstacle.move_dir_x
                end
                if new_y < 0 or new_y >= self.grid_height then
                    obstacle.move_dir_y = -obstacle.move_dir_y
                end

                obstacle.x = math.max(0, math.min(self.grid_width - 1, obstacle.x + obstacle.move_dir_x))
                obstacle.y = math.max(0, math.min(self.grid_height - 1, obstacle.y + obstacle.move_dir_y))
            end
        end
    end

    -- Obstacle spawning over time
    if self.params.obstacle_spawn_over_time > 0 then
        self.obstacle_spawn_timer = self.obstacle_spawn_timer + dt
        if self.obstacle_spawn_timer >= 1 / self.params.obstacle_spawn_over_time then
            self.obstacle_spawn_timer = 0
            self:spawnObstacleEntity()
        end
    end

    -- Update AI snakes
    for _, ai_snake in ipairs(self.ai_snakes) do
        if ai_snake.alive then self:updateAISnake(ai_snake, dt) end
    end

    -- Check collisions between snakes
    self:checkSnakeCollisions()

    self.arena_controller:update(dt)
    self:syncArenaState()  -- Sync wall offsets and dimensions back to game object for view

    -- Handle smooth movement separately
    if self.params.movement_type == "smooth" then
        self:updateSmoothMovement(dt)
        return  -- Skip grid-based movement
    end

    -- Apply max speed cap
    local capped_speed = self.params.snake_speed
    if self.params.max_speed_cap > 0 and self.params.snake_speed > self.params.max_speed_cap then
        capped_speed = self.params.max_speed_cap
    end
    self.movement_controller:setSpeed(capped_speed)

    -- Check if it's time to move using MovementController's timing
    if self.movement_controller:tickGrid(dt, "snake") then
        self.snake.direction = self.movement_controller:applyQueuedDirection("snake")
        local head = self.snake.body[1]

        -- Calculate new head position based on wall_mode
        local new_head = {x = head.x + self.snake.direction.x, y = head.y + self.snake.direction.y}

        if self.params.wall_mode == "wrap" then
            new_head.x, new_head.y = self:wrapPosition(new_head.x, new_head.y, self.grid_width, self.grid_height)
        elseif self.params.wall_mode == "death" then
            if not self:isInsideArena(new_head) then
                self:playSound("death", 1.0)
                self:onComplete()
                return
            end
        elseif self.params.wall_mode == "bounce" then
            if self:_isWallAt(new_head.x, new_head.y) then
                self.snake.direction = self.movement_controller:findGridBounceDirection(
                    head, self.snake.direction, function(x, y) return self:_isWallAt(x, y) end)
                self.movement_controller:initGridState("snake", self.snake.direction.x, self.snake.direction.y)
                new_head = {x = head.x + self.snake.direction.x, y = head.y + self.snake.direction.y}
            end
        end

        -- Check collision (with phase_through_tail support)
        if self:checkCollision(new_head, true) then
            self:playSound("death", 1.0)
            self:onComplete()
            return
        end

        table.insert(self.snake.body, 1, new_head)

        -- Check food collision (girth-aware)
        for _, food in ipairs(self:getFoods()) do
            if self:checkGirthCollision(new_head, self.params.girth, self.snake.direction, food, food.size or 1, nil) then
                self:collectFood(food, self.snake)
                self:removeFood(food)
                if self.params.food_spawn_mode == "continuous" then
                    self:spawnFoodEntity()
                elseif self.params.food_spawn_mode == "batch" and #self:getFoods() == 0 then
                    for _ = 1, self.params.food_count do self:spawnFoodEntity() end
                end
                break
            end
        end

        -- Handle tail growth/removal
        if self.pending_growth > 0 then
            -- Don't remove tail - we're growing
            self.pending_growth = self.pending_growth - 1
        elseif #self.snake.body < self.params.max_length_cap then
            -- Remove tail if we're not at max length and not growing
            table.remove(self.snake.body)
        else
            -- At max length cap - maintain current length
            table.remove(self.snake.body)
        end

        -- Update snake length metric to match actual snake
        self.metrics.snake_length = #self.snake.body

        -- Move additional player snakes (for multi-snake control)
        for i = 2, #self.player_snakes do
            local psnake = self.player_snakes[i]
            if psnake.alive then
                -- Update direction
                psnake.direction = psnake.next_direction

                local phead = psnake.body[1]

                -- Calculate new head position
                local wrap_x, wrap_y = self:wrapPosition(
                    phead.x + psnake.direction.x,
                    phead.y + psnake.direction.y,
                    self.grid_width, self.grid_height)
                local new_phead = {x = wrap_x, y = wrap_y}

                -- Check collision with obstacles
                if self:checkCollision(new_phead, false) then
                    psnake.alive = false
                    goto continue
                end

                -- Check collision with own body
                for j = 2, #psnake.body do
                    if new_phead.x == psnake.body[j].x and new_phead.y == psnake.body[j].y then
                        psnake.alive = false
                        goto continue
                    end
                end

                -- Add new head
                table.insert(psnake.body, 1, new_phead)

                -- Check food collision
                local ate_food = false
                for _, food in ipairs(self:getFoods()) do
                    if new_phead.x == food.x and new_phead.y == food.y then
                        ate_food = true
                        self:collectFood(food, psnake)
                        self:removeFood(food)
                        if self.params.food_spawn_mode == "continuous" then
                            self:spawnFoodEntity()
                        elseif self.params.food_spawn_mode == "batch" and #self:getFoods() == 0 then
                            for _ = 1, self.params.food_count do self:spawnFoodEntity() end
                        end
                        break
                    end
                end

                -- Remove tail if not growing
                if not ate_food then
                    table.remove(psnake.body)
                end
            end

            ::continue::
        end
    end
end

function SnakeGame:checkComplete()
    local result = self.victory_checker:check()
    if result then
        self.victory = (result == "victory")
        self.game_over = (result == "loss")
        return true
    end
    return false
end

function SnakeGame:onComplete()
    -- Determine if win based on victory condition
    local is_win = false
    if self.params.victory_condition == "length" then
        is_win = self.metrics.snake_length >= self.params.victory_limit
    elseif self.params.victory_condition == "time" then
        is_win = self.time_elapsed >= self.params.victory_limit
    end

    if is_win then
        self:playSound("success", 1.0)
    end
    -- Note: death sound already played inline at collision detection

    -- Stop music
    self:stopMusic()

    -- Call parent onComplete
    SnakeGame.super.onComplete(self)
end

function SnakeGame:draw()
   if self.view then
       self.view:draw()
   end
end

function SnakeGame:keypressed(key)
    SnakeGame.super.keypressed(self, key)

    if self.params.movement_type == "smooth" then
        local left = (key == 'left' or key == 'a')
        local right = (key == 'right' or key == 'd')
        if left or right then
            for i, psnake in ipairs(self.player_snakes) do
                local state = self.movement_controller:getSmoothState((i == 1) and "snake" or ("snake_" .. i))
                if state then
                    if left then state.turn_left = true end
                    if right then state.turn_right = true end
                end
            end
            return true
        end
    else
        local dir = nil
        if key == 'left' or key == 'a' then dir = {x = -1, y = 0}
        elseif key == 'right' or key == 'd' then dir = {x = 1, y = 0}
        elseif key == 'up' or key == 'w' then dir = {x = 0, y = -1}
        elseif key == 'down' or key == 's' then dir = {x = 0, y = 1}
        end
        if dir and self.movement_controller:queueGridDirection("snake", dir.x, dir.y, self.snake.direction) then
            for i = 2, #self.player_snakes do
                if self.player_snakes[i].alive then
                    self.player_snakes[i].next_direction = {x = dir.x, y = dir.y}
                end
            end
            return true
        end
    end
    return false
end

function SnakeGame:keyreleased(key)
    SnakeGame.super.keyreleased(self, key)

    if self.params.movement_type == "smooth" then
        local left = (key == 'left' or key == 'a')
        local right = (key == 'right' or key == 'd')
        if left or right then
            for i = 1, #self.player_snakes do
                local state = self.movement_controller:getSmoothState((i == 1) and "snake" or ("snake_" .. i))
                if state then
                    if left then state.turn_left = false end
                    if right then state.turn_right = false end
                end
            end
        end
    end
end

function SnakeGame:updateSmoothMovement(dt)
    local girth = self.params.girth or 1
    local head_radius = 0.3 + (girth * 0.5)
    local food_radius = 0.35 + (girth * 0.5)

    -- Update main snake
    self:_updateSmoothSnake(self.snake, "snake", dt, head_radius, food_radius, true)

    -- Update additional player snakes
    for i = 2, #self.player_snakes do
        local psnake = self.player_snakes[i]
        if psnake.alive and psnake.smooth_x then
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

    -- Shaped arena death check (MC only handles rectangle)
    if self.params.wall_mode == "death" then
        if self.params.arena_shape ~= "rectangle" then
            if not self:isInsideArena({x = snake.smooth_x - 0.5, y = snake.smooth_y - 0.5}, head_radius) then
                out_of_bounds = true
            end
        end
        if out_of_bounds then
            if is_primary then
                self:playSound("death", 1.0)
                self:onComplete()
            else
                snake.alive = false
            end
            return
        end
    end

    -- Obstacle collision
    for _, obs in ipairs(self:getObstacles()) do
        if PhysicsUtils.circleCollision(snake.smooth_x, snake.smooth_y, head_radius, obs.x + 0.5, obs.y + 0.5, 0.5) then
            local is_wall = (obs.type == "walls" or obs.type == "bounce_wall")
            local should_bounce = (is_wall and self.params.wall_mode == "bounce") or (not is_wall and self.params.obstacle_bounce)

            if should_bounce then
                snake.smooth_angle = self:_findBounceAngle(snake.smooth_x, snake.smooth_y, snake.smooth_angle)
                self.movement_controller:setSmoothAngle(entity_id, snake.smooth_angle)
                snake.smooth_x = snake.smooth_x + math.cos(snake.smooth_angle) * 0.2
                snake.smooth_y = snake.smooth_y + math.sin(snake.smooth_angle) * 0.2
                break
            else
                if is_primary then
                    self:playSound("death", 1.0)
                    self:onComplete()
                else
                    snake.alive = false
                end
                return
            end
        end
    end

    -- Self-collision (trail)
    if is_primary and not self.params.phase_through_tail then
        local skip_dist = 1.0 * (self.params.girth or 1)
        local coll_dist = 0.1 + ((self.params.girth or 1) * 0.3)
        local points = snake.smooth_trail:getPoints()
        local checked = 0
        for i = #points, 1, -1 do
            if i < #points then
                local curr, next_pt = points[i], points[i + 1]
                checked = checked + math.sqrt((next_pt.x - curr.x)^2 + (next_pt.y - curr.y)^2)
            end
            if checked > skip_dist then
                if PhysicsUtils.circleCollision(snake.smooth_x, snake.smooth_y, coll_dist, points[i].x, points[i].y, 0) then
                    self:playSound("death", 1.0)
                    self:onComplete()
                    return
                end
            end
        end
    end

    -- Food collision
    for _, food in ipairs(self:getFoods()) do
        if PhysicsUtils.circleCollision(snake.smooth_x, snake.smooth_y, food_radius, food.x + 0.5, food.y + 0.5, 0.5) then
            self:collectFood(food, snake)
            if is_primary then self.metrics.snake_length = math.floor(snake.smooth_target_length) end
            self:removeFood(food)
            if self.params.food_spawn_mode == "continuous" then
                self:spawnFoodEntity()
            elseif self.params.food_spawn_mode == "batch" and #self:getFoods() == 0 then
                for _ = 1, self.params.food_count do self:spawnFoodEntity() end
            end
            break
        end
    end

    -- Update body[1] for camera/fog tracking
    snake.body[1] = {x = math.floor(snake.smooth_x), y = math.floor(snake.smooth_y)}
end

function SnakeGame:_isWallAt(x, y)
    for _, obs in ipairs(self:getObstacles()) do
        if (obs.type == "bounce_wall" or obs.type == "walls") and obs.x == x and obs.y == y then
            return true
        end
    end
    return false
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

function SnakeGame:createAISnake(index)
    local player_head = self.snake.body[1]
    local spawn_x, spawn_y, found = self:findSafePosition(0, self.grid_width - 1, 0, self.grid_height - 1,
        function(x, y)
            local dist = math.abs(x - player_head.x) + math.abs(y - player_head.y)
            return dist > 10 and self:isInsideArena({x = x, y = y}) and not self:checkCollision({x = x, y = y}, true)
        end, 200)

    if not found then
        spawn_x = math.floor(self.grid_width / 2) + (index * 2)
        spawn_y = math.floor(self.grid_height / 2)
    end

    return {
        body = {{x = spawn_x, y = spawn_y}},
        direction = {x = 1, y = 0},
        move_timer = 0,
        length = 1,
        alive = true,
        behavior = self.params.ai_behavior
    }
end

function SnakeGame:updateAISnake(ai_snake, dt)
    ai_snake.move_timer = ai_snake.move_timer + dt
    if ai_snake.move_timer < 1 / self.params.ai_speed then return end
    ai_snake.move_timer = ai_snake.move_timer - (1 / self.params.ai_speed)

    local head = ai_snake.body[1]

    -- AI direction based on behavior
    local target_x, target_y
    if ai_snake.behavior == "aggressive" then
        target_x, target_y = self.snake.body[1].x, self.snake.body[1].y
    elseif ai_snake.behavior == "defensive" then
        local dx, dy = self:getCardinalDirection(head.x, head.y, self.snake.body[1].x, self.snake.body[1].y)
        ai_snake.direction = {x = -dx, y = -dy}
        target_x, target_y = nil, nil
    else -- food_focused
        local nearest = self.entity_controller:findNearest(head.x, head.y, function(e) return e.category == "food" end)
        if nearest then target_x, target_y = nearest.x, nearest.y end
    end
    if target_x then
        local dx, dy = self:getCardinalDirection(head.x, head.y, target_x, target_y)
        ai_snake.direction = {x = dx, y = dy}
    end

    -- Calculate new position
    local new_head = {x = head.x + ai_snake.direction.x, y = head.y + ai_snake.direction.y}

    -- Wall handling
    if self.params.wall_mode == "wrap" then
        new_head.x, new_head.y = self:wrapPosition(new_head.x, new_head.y, self.grid_width, self.grid_height)
    elseif self.params.wall_mode == "death" then
        if not self:isInsideArena(new_head) then ai_snake.alive = false; return end
    elseif self.params.wall_mode == "bounce" then
        if new_head.x < 0 or new_head.x >= self.grid_width then
            ai_snake.direction.x = -ai_snake.direction.x
            new_head.x = head.x + ai_snake.direction.x
        end
        if new_head.y < 0 or new_head.y >= self.grid_height then
            ai_snake.direction.y = -ai_snake.direction.y
            new_head.y = head.y + ai_snake.direction.y
        end
    end

    -- Collision checks
    if self:checkCollision(new_head, false) then ai_snake.alive = false; return end
    for _, seg in ipairs(ai_snake.body) do
        if new_head.x == seg.x and new_head.y == seg.y then ai_snake.alive = false; return end
    end

    -- Move and eat
    table.insert(ai_snake.body, 1, new_head)
    local ate = false
    for _, food in ipairs(self:getFoods()) do
        if new_head.x == food.x and new_head.y == food.y then
            ate = true
            ai_snake.length = ai_snake.length + 1
            self:removeFood(food)
            if self.params.food_spawn_mode == "continuous" then self:spawnFoodEntity()
            elseif self.params.food_spawn_mode == "batch" and #self:getFoods() == 0 then
                for _ = 1, self.params.food_count do self:spawnFoodEntity() end
            end
            break
        end
    end
    if not ate then table.remove(ai_snake.body) end
end

function SnakeGame:checkSnakeCollisions()
    -- Check collisions between player and AI snakes
    local player_head = self.snake.body[1]

    for i, ai_snake in ipairs(self.ai_snakes) do
        if ai_snake.alive then
            local ai_head = ai_snake.body[1]

            -- Check head-to-head collision
            if player_head.x == ai_head.x and player_head.y == ai_head.y then
                if self.params.snake_collision_mode == "both_die" then
                    self.snake.alive = false
                    ai_snake.alive = false
                    self:playSound("death", 1.0)
                    self:onComplete()
                elseif self.params.snake_collision_mode == "big_eats_small" then
                    if #self.snake.body > #ai_snake.body then
                        -- Player wins, absorb AI snake
                        for _ = 1, #ai_snake.body do
                            self.metrics.snake_length = self.metrics.snake_length + 1
                        end
                        ai_snake.alive = false
                        self:playSound("success", 0.8)
                    else
                        -- AI wins, player dies
                        self.snake.alive = false
                        self:playSound("death", 1.0)
                        self:onComplete()
                    end
                end
                -- phase_through: do nothing
            end

            -- Check if player head hits AI body
            for _, segment in ipairs(ai_snake.body) do
                if player_head.x == segment.x and player_head.y == segment.y then
                    if self.params.snake_collision_mode ~= "phase_through" then
                        self.snake.alive = false
                        self:playSound("death", 1.0)
                        self:onComplete()
                    end
                    break
                end
            end
        end
    end
end

function SnakeGame:createEdgeObstacles()
    -- Create edge obstacles based on wall_mode and arena_shape
    local edges = {}

    -- Build set of snake positions to avoid placing walls there
    local snake_positions = {}
    for _, segment in ipairs(self.snake.body or {}) do
        local key = segment.x .. "," .. segment.y
        snake_positions[key] = true
    end

    local wall_type = (self.params.wall_mode == "bounce") and "bounce_wall" or "walls"

    if self.params.wall_mode == "death" or self.params.wall_mode == "bounce" then
        if self.params.arena_shape == "circle" or self.params.arena_shape == "hexagon" then
            -- For shaped arenas, fill ALL positions outside the shape with walls
            for y = 0, self.grid_height - 1 do
                for x = 0, self.grid_width - 1 do
                    local pos = {x = x, y = y}
                    if not self:isInsideArena(pos) and not snake_positions[x .. "," .. y] then
                        table.insert(edges, {x = x, y = y, type = wall_type})
                    end
                end
            end
        else
            -- Rectangle arena - just create perimeter walls
            -- Top and bottom edges
            for x = 0, self.grid_width - 1 do
                if not snake_positions[x .. ",0"] then
                    table.insert(edges, {x = x, y = 0, type = wall_type})
                end
                if not snake_positions[x .. "," .. (self.grid_height - 1)] then
                    table.insert(edges, {x = x, y = self.grid_height - 1, type = wall_type})
                end
            end
            -- Left and right edges (excluding corners already added)
            for y = 1, self.grid_height - 2 do
                if not snake_positions["0," .. y] then
                    table.insert(edges, {x = 0, y = y, type = wall_type})
                end
                if not snake_positions[(self.grid_width - 1) .. "," .. y] then
                    table.insert(edges, {x = self.grid_width - 1, y = y, type = wall_type})
                end
            end
        end
    end
    -- For "wrap" mode, return empty array (no edge obstacles)
    print(string.format("[createEdgeObstacles] wall_mode=%s shape=%s grid=%dx%d created=%d edges",
        tostring(self.params.wall_mode), tostring(self.params.arena_shape), self.grid_width, self.grid_height, #edges))

    return edges
end

function SnakeGame:onArenaShrink(margins)
    -- Spawn wall entities for shrinking arena
    for y = 0, self.grid_height - 1 do
        self.entity_controller:spawn("obstacle_static", margins.left - 1, y, {type = "walls", category = "obstacle"})
        self.entity_controller:spawn("obstacle_static", self.grid_width - margins.right, y, {type = "walls", category = "obstacle"})
    end
    for x = 0, self.grid_width - 1 do
        self.entity_controller:spawn("obstacle_static", x, margins.top - 1, {type = "walls", category = "obstacle"})
        self.entity_controller:spawn("obstacle_static", x, self.grid_height - margins.bottom, {type = "walls", category = "obstacle"})
    end
end

function SnakeGame:syncArenaState()
    self.grid_width = self.arena_controller.current_width
    self.grid_height = self.arena_controller.current_height
end

function SnakeGame:isInsideArena(pos, margin)
    return self.arena_controller:isInsideGrid(pos.x, pos.y, margin)
end

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

function SnakeGame:checkGirthCollision(pos1, girth1, dir1, pos2, girth2, dir2)
    -- Check if two girth-expanded positions collide
    local cells1 = self:getGirthCells(pos1, girth1, dir1)
    local cells2 = self:getGirthCells(pos2, girth2 or 1, dir2)

    for _, c1 in ipairs(cells1) do
        for _, c2 in ipairs(cells2) do
            if c1.x == c2.x and c1.y == c2.y then
                return true
            end
        end
    end
    return false
end

function SnakeGame:collectFood(food, snake)
    local is_smooth = (self.params.movement_type == "smooth")
    local growth = (food.size or 1) * self.params.growth_per_food
    local speed_mult = (food.type == "golden") and 2 or 1

    if food.type == "bad" then
        if is_smooth then
            snake.smooth_target_length = math.max(0.1, snake.smooth_target_length - 3)
        else
            local body = snake.body or self.snake.body
            for _ = 1, math.min(3, #body - 1) do
                if #body > 1 then table.remove(body) end
            end
        end
        self:playSound("death", 0.5)
    else
        if is_smooth then
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

function SnakeGame:checkCollision(pos, check_snake_body)
    if not pos then return false end

    -- Get all cells occupied by this position with current girth
    local pos_cells = self:getGirthCells(pos, self.params.girth, self.snake.direction)

    -- Always check obstacle collision
    for _, obstacle in ipairs(self:getObstacles()) do
        for _, cell in ipairs(pos_cells) do
            if cell.x == obstacle.x and cell.y == obstacle.y then
                return true
            end
        end
    end

    -- Check snake body collision (unless phase_through_tail is enabled)
    if check_snake_body and not self.params.phase_through_tail then
        -- Skip checking segments near the head to prevent false collision on turns
        -- Need to skip at least (girth) segments to avoid overlap at turn corners
        local girth = self.params.girth or 1
        local skip_segments = math.max(2, girth)
        local start_index = skip_segments + 1

        for i = start_index, #self.snake.body do
            -- Get direction for this segment
            local seg_dir = self.snake.direction
            if i < #self.snake.body then
                local next_seg = self.snake.body[i + 1]
                seg_dir = {
                    x = self.snake.body[i].x - next_seg.x,
                    y = self.snake.body[i].y - next_seg.y
                }
            end

            -- Check if any cell of the new position collides with this snake segment
            if self:checkGirthCollision(pos, self.params.girth, self.snake.direction, self.snake.body[i], self.params.girth, seg_dir) then
                return true
            end
        end
    end

    return false
end

function SnakeGame:_spawnSnakeSafe()
    local center_x = math.floor(self.grid_width / 2)
    local center_y = math.floor(self.grid_height / 2)

    local safe_min = (not self.is_fixed_arena and (self.params.wall_mode == "death" or self.params.wall_mode == "bounce")) and 2 or 1
    local safe_max_x = self.grid_width - safe_min - 1
    local safe_max_y = self.grid_height - safe_min - 1

    local spawn_x, spawn_y
    local max_attempts = 500
    local found_safe_spawn = false

    for attempt = 1, max_attempts do
        spawn_x = math.random(safe_min, safe_max_x)
        spawn_y = math.random(safe_min, safe_max_y)

        local safe = true

        -- Check arena bounds
        if self.params.arena_shape == "circle" or self.params.arena_shape == "hexagon" then
            if not self:isInsideArena({x = spawn_x, y = spawn_y}) then
                safe = false
            end
        end

        -- Check obstacles using proper collision detection based on movement type
        if safe then
            if self.params.movement_type == "smooth" then
                -- For smooth movement, check distance-based collision
                local smooth_x = spawn_x + 0.5
                local smooth_y = spawn_y + 0.5
                local girth_scale = self.params.girth or 1
                local obstacle_collision_distance = 0.3 + (girth_scale * 0.5)

                for _, obs in ipairs(self:getObstacles()) do
                    local obs_center_x = obs.x + 0.5
                    local obs_center_y = obs.y + 0.5
                    local dx = smooth_x - obs_center_x
                    local dy = smooth_y - obs_center_y
                    local distance = math.sqrt(dx*dx + dy*dy)

                    if distance < obstacle_collision_distance then
                        safe = false
                        break
                    end
                end
            else
                -- For grid-based movement, check collision
                local old_x, old_y = self.snake.body[1].x, self.snake.body[1].y
                self.snake.body[1].x, self.snake.body[1].y = spawn_x, spawn_y

                if self:checkCollision({x = spawn_x, y = spawn_y}, false) then
                    safe = false
                end

                self.snake.body[1].x, self.snake.body[1].y = old_x, old_y
            end
        end

        if safe then
            found_safe_spawn = true
            break
        end
    end

    if not found_safe_spawn then
        spawn_x = center_x
        spawn_y = center_y
    end

    -- Update snake position
    self.snake.body[1].x = spawn_x
    self.snake.body[1].y = spawn_y

    -- Calculate direction toward center
    local dx = center_x - spawn_x
    local dy = center_y - spawn_y

    if dx == 0 and dy == 0 then
        local dirs = {{x=1,y=0}, {x=-1,y=0}, {x=0,y=1}, {x=0,y=-1}}
        self.snake.direction = dirs[math.random(#dirs)]
    elseif math.abs(dx) > math.abs(dy) then
        self.snake.direction = {x = dx > 0 and 1 or -1, y = 0}
    else
        self.snake.direction = {x = 0, y = dy > 0 and 1 or -1}
    end

    -- Sync MovementController's direction after spawning
    self.movement_controller:initGridState("snake", self.snake.direction.x, self.snake.direction.y)

    -- Update smooth movement positions
    if self.params.movement_type == "smooth" then
        self.snake.smooth_x = spawn_x + 0.5
        self.snake.smooth_y = spawn_y + 0.5
        self.snake.smooth_angle = math.atan2(self.snake.direction.y, self.snake.direction.x)
    end
end

return SnakeGame