local BaseGame = require('src.games.base_game')
local SnakeView = require('src.games.views.snake_view')
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
        smooth_trail = {}, smooth_trail_length = 0,
        smooth_target_length = self.params.smooth_initial_length,
        smooth_turn_left = false, smooth_turn_right = false
    }
end

function SnakeGame:_createSnakeEntity(x, y)
    local dir = BaseGame.CARDINAL_DIRECTIONS[self.params.starting_direction] or BaseGame.CARDINAL_DIRECTIONS.right
    local snake = {
        body = {{x = x, y = y}},
        direction = dir,
        next_direction = {x = dir.x, y = dir.y},
        alive = true
    }
    if self.params.movement_type == "smooth" then
        for k, v in pairs(self:_initSmoothState(x, y)) do snake[k] = v end
    end
    return snake
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
        for _, obs in ipairs(self.obstacles) do
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
        local variant_obstacles = self:createObstacles()
        for _, obs in ipairs(variant_obstacles) do
            table.insert(self.obstacles, obs)
        end
        self._obstacles_created = true
    end
    local edge_obstacles = self:createEdgeObstacles()
    for _, edge in ipairs(edge_obstacles) do
        table.insert(self.obstacles, edge)
    end
end

function SnakeGame:_spawnInitialFood()
    if #self.foods == 0 and not self._foods_spawned then
        for i = 1, self.params.food_count do
            table.insert(self.foods, self:spawnFood())
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
    for _, food in ipairs(self.foods or {}) do
        food.x = math.max(min_x, math.min(max_x, food.x))
        food.y = math.max(min_y, math.min(max_y, food.y))
    end
end

function SnakeGame:_regenerateEdgeObstacles()
    local non_edge_obstacles = {}
    for _, obs in ipairs(self.obstacles or {}) do
        if obs.type ~= "walls" and obs.type ~= "bounce_wall" then
            table.insert(non_edge_obstacles, obs)
        end
    end
    self.obstacles = non_edge_obstacles
    self:_initializeObstacles()
end

function SnakeGame:setupSnake()
    local cx, cy = math.floor(self.grid_width / 2), math.floor(self.grid_height / 2)

    self.player_snakes = {}
    for i = 1, self.params.snake_count do
        local sx, sy = cx + (i - 1) * self.params.multi_snake_spacing, cy
        table.insert(self.player_snakes, self:_createSnakeEntity(sx, sy))
    end
    self.snake = self.player_snakes[1]
    self._snake_needs_spawn = true

    self.segments_for_next_girth = self.params.girth_growth
    self.pending_growth = 0
    self.shrink_timer, self.obstacle_spawn_timer = 0, 0
    self.foods, self.obstacles, self.ai_snakes = {}, {}, {}

    for i = 1, self.params.ai_snake_count do
        table.insert(self.ai_snakes, self:createAISnake(i))
    end
end

function SnakeGame:setupComponents()
    self:createComponentsFromSchema()
    self:createEntityControllerFromSchema()
    self:createVictoryConditionFromSchema()

    -- Set computed arena values (must set base_width/current_width, not just width)
    self.arena_controller.base_width = self.grid_width
    self.arena_controller.base_height = self.grid_height
    self.arena_controller.current_width = self.grid_width
    self.arena_controller.current_height = self.grid_height
    self.arena_controller.min_width = math.max(self.params.min_arena_cells, math.floor(self.grid_width * self.params.min_arena_ratio))
    self.arena_controller.min_height = math.max(self.params.min_arena_cells, math.floor(self.grid_height * self.params.min_arena_ratio))
    self.arena_controller.on_shrink = function(margins) self:onArenaShrink(margins) end

    self.movement_controller:initGridState("snake", self.snake.direction.x, self.snake.direction.y)
    self.metrics.snake_length, self.metrics.survival_time = 1, 0
end


function SnakeGame:setPlayArea(width, height)
    self.viewport_width, self.viewport_height = width, height
    print(string.format("[setPlayArea] viewport=%dx%d game=%dx%d grid=%dx%d fixed=%s",
        width, height, self.game_width or 0, self.game_height or 0, self.grid_width or 0, self.grid_height or 0, tostring(self.is_fixed_arena)))

    if self.is_fixed_arena then
        self:_initializeObstacles()
        print(string.format("[setPlayArea fixed] total obstacles=%d", #self.obstacles))
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
        for _, food in ipairs(self.foods) do
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
                        -- Find and remove this food from the foods array
                        for i = #self.foods, 1, -1 do
                            if self.foods[i] == food then
                                table.remove(self.foods, i)

                                -- Spawn new food based on spawn mode
                                if self.params.food_spawn_mode == "continuous" then
                                    table.insert(self.foods, self:spawnFood())
                                elseif self.params.food_spawn_mode == "batch" then
                                    if #self.foods == 0 then
                                        for j = 1, self.params.food_count do
                                            table.insert(self.foods, self:spawnFood())
                                        end
                                    end
                                end

                                break
                            end
                        end
                    end
                end
            end
        end
    end

    -- Update food lifetime (despawn expired foods)
    if self.params.food_lifetime > 0 then
        for i = #self.foods, 1, -1 do
            local food = self.foods[i]
            food.lifetime = (food.lifetime or 0) + dt
            if food.lifetime >= self.params.food_lifetime then
                table.remove(self.foods, i)
                -- Spawn new food to replace it
                table.insert(self.foods, self:spawnFood())
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
    for _, obstacle in ipairs(self.obstacles) do
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
        local spawn_interval = 1 / self.params.obstacle_spawn_over_time
        if self.obstacle_spawn_timer >= spawn_interval then
            self.obstacle_spawn_timer = self.obstacle_spawn_timer - spawn_interval
            -- Spawn new obstacle at random free position
            local new_obs
            local attempts = 0
            repeat
                new_obs = {
                    x = math.random(0, self.grid_width - 1),
                    y = math.random(0, self.grid_height - 1),
                    type = self.params.obstacle_type or "walls"
                }
                attempts = attempts + 1
            until not self:checkCollision(new_obs, true) or attempts > 100
            if attempts <= 100 then
                table.insert(self.obstacles, new_obs)
            end
        end
    end

    -- Update AI snakes
    self:updateAISnakes(dt)

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
        -- Apply queued direction from MovementController
        self.snake.direction = self.movement_controller:applyQueuedDirection("snake")

        local head = self.snake.body[1]
        print(string.format("[MOVE] head=%d,%d dir=%d,%d wall_mode=%s grid=%dx%d",
            head.x, head.y, self.snake.direction.x, self.snake.direction.y,
            tostring(self.params.wall_mode), self.grid_width, self.grid_height))

        -- Calculate new head position based on wall_mode
        local new_head = nil
        if self.params.wall_mode == "wrap" then
            local raw_x, raw_y = head.x + self.snake.direction.x, head.y + self.snake.direction.y
            local wrap_x, wrap_y = self:wrapPosition(raw_x, raw_y, self.grid_width, self.grid_height)
            if raw_x ~= wrap_x or raw_y ~= wrap_y then
                print(string.format("[WRAP] raw=%d,%d wrapped=%d,%d grid=%dx%d", raw_x, raw_y, wrap_x, wrap_y, self.grid_width, self.grid_height))
            end
            new_head = {x = wrap_x, y = wrap_y}
        elseif self.params.wall_mode == "death" then
            -- Hit wall = game over (respects arena shape)
            new_head = {
                x = head.x + self.snake.direction.x,
                y = head.y + self.snake.direction.y
            }
            -- Check if hit wall (arena shape aware)
            if not self:isInsideArena(new_head) then
                self:playSound("death", 1.0)
                self:onComplete()
                return
            end
        elseif self.params.wall_mode == "bounce" then
            -- Bounce off walls - change to perpendicular direction
            new_head = {
                x = head.x + self.snake.direction.x,
                y = head.y + self.snake.direction.y
            }

            -- Check if about to hit a bounce wall
            local will_hit_wall = false
            for _, obs in ipairs(self.obstacles or {}) do
                if (obs.type == "bounce_wall" or obs.type == "walls") and
                   obs.x == new_head.x and obs.y == new_head.y then
                    will_hit_wall = true
                    break
                end
            end

            -- If hitting wall, bounce perpendicular - check which directions are clear
            if will_hit_wall then
                local old_dir_x, old_dir_y = self.snake.direction.x, self.snake.direction.y
                local possible_dirs = {}

                if self.snake.direction.x ~= 0 then
                    -- Moving horizontally - try vertical directions
                    -- Try up
                    local try_up = {x = head.x, y = head.y - 1}
                    local up_blocked = false
                    for _, obs in ipairs(self.obstacles or {}) do
                        if (obs.type == "bounce_wall" or obs.type == "walls") and
                           obs.x == try_up.x and obs.y == try_up.y then
                            up_blocked = true
                            break
                        end
                    end
                    if not up_blocked then
                        table.insert(possible_dirs, {x = 0, y = -1})
                    end

                    -- Try down
                    local try_down = {x = head.x, y = head.y + 1}
                    local down_blocked = false
                    for _, obs in ipairs(self.obstacles or {}) do
                        if (obs.type == "bounce_wall" or obs.type == "walls") and
                           obs.x == try_down.x and obs.y == try_down.y then
                            down_blocked = true
                            break
                        end
                    end
                    if not down_blocked then
                        table.insert(possible_dirs, {x = 0, y = 1})
                    end
                else
                    -- Moving vertically - try horizontal directions
                    -- Try left
                    local try_left = {x = head.x - 1, y = head.y}
                    local left_blocked = false
                    for _, obs in ipairs(self.obstacles or {}) do
                        if (obs.type == "bounce_wall" or obs.type == "walls") and
                           obs.x == try_left.x and obs.y == try_left.y then
                            left_blocked = true
                            break
                        end
                    end
                    if not left_blocked then
                        table.insert(possible_dirs, {x = -1, y = 0})
                    end

                    -- Try right
                    local try_right = {x = head.x + 1, y = head.y}
                    local right_blocked = false
                    for _, obs in ipairs(self.obstacles or {}) do
                        if (obs.type == "bounce_wall" or obs.type == "walls") and
                           obs.x == try_right.x and obs.y == try_right.y then
                            right_blocked = true
                            break
                        end
                    end
                    if not right_blocked then
                        table.insert(possible_dirs, {x = 1, y = 0})
                    end
                end

                -- Pick a random open direction
                if #possible_dirs > 0 then
                    local chosen = possible_dirs[math.random(#possible_dirs)]
                    self.snake.direction.x = chosen.x
                    self.snake.direction.y = chosen.y
                else
                    -- No open direction - reverse (shouldn't happen but safe fallback)
                    self.snake.direction.x = -old_dir_x
                    self.snake.direction.y = -old_dir_y
                end

                -- Recalculate new position with new direction
                new_head.x = head.x + self.snake.direction.x
                new_head.y = head.y + self.snake.direction.y
            end

            -- Sync MovementController's direction after bounce
            self.movement_controller:initGridState("snake", self.snake.direction.x, self.snake.direction.y)
        else
            -- Default to wrap (Pac-Man style)
            local wrap_x, wrap_y = self:wrapPosition(
                head.x + self.snake.direction.x,
                head.y + self.snake.direction.y,
                self.grid_width, self.grid_height)
            new_head = {x = wrap_x, y = wrap_y}
        end

        -- Check collision (with phase_through_tail support)
        if self:checkCollision(new_head, true) then
            self:playSound("death", 1.0)
            self:onComplete()
            return
        end

        table.insert(self.snake.body, 1, new_head)

        -- Check food collision (multiple foods support, girth-aware)
        for i = #self.foods, 1, -1 do
            local food = self.foods[i]
            -- Check if any cell of the snake's girth touches the food
            if self:checkGirthCollision(new_head, self.params.girth, self.snake.direction, food, food.size or 1, nil) then
                -- Handle different food types
                if food.type == "bad" then
                    -- Bad food: shrink snake by removing tail segments
                    local shrink_amount = math.min(3, #self.snake.body - 1)  -- Remove up to 3, but keep at least head
                    for s = 1, shrink_amount do
                        if #self.snake.body > 1 then
                            table.remove(self.snake.body)
                        end
                    end
                    self:playSound("death", 0.5)  -- Negative sound

                elseif food.type == "golden" then
                    -- Golden food: bonus effects (bigger growth, speed boost)
                    local growth = food.size * self.params.growth_per_food
                    self.pending_growth = self.pending_growth + growth

                    -- Extra speed boost
                    if self.params.speed_increase_per_food > 0 then
                        self.params.snake_speed = self.params.snake_speed + (self.params.speed_increase_per_food * 2)
                    end
                    self:playSound("success", 0.6)  -- Special sound

                else
                    -- Normal food: standard behavior
                    -- Add pending growth segments based on food size and growth_per_food
                    local growth = food.size * self.params.growth_per_food
                    self.pending_growth = self.pending_growth + growth

                    -- Increase speed (if speed_increase_per_food is set)
                    if self.params.speed_increase_per_food > 0 then
                        self.params.snake_speed = self.params.snake_speed + self.params.speed_increase_per_food
                    end

                    self:playSound("eat", 0.8)
                end

                -- Track girth growth (for all food types)
                if self.params.girth_growth > 0 and food.type ~= "bad" then
                    self.segments_for_next_girth = self.segments_for_next_girth - 1
                    if self.segments_for_next_girth <= 0 then
                        self.params.girth = self.params.girth + 1
                        self.segments_for_next_girth = self.params.girth_growth
                    end
                end

                -- Remove eaten food
                table.remove(self.foods, i)

                -- Spawn new food based on spawn mode
                if self.params.food_spawn_mode == "continuous" then
                    -- Continuous mode: spawn immediately
                    table.insert(self.foods, self:spawnFood())
                elseif self.params.food_spawn_mode == "batch" then
                    -- Batch mode: only spawn new batch when all food collected
                    if #self.foods == 0 then
                        -- All food collected, spawn new batch
                        for j = 1, self.params.food_count do
                            table.insert(self.foods, self:spawnFood())
                        end
                    end
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
                for f = #self.foods, 1, -1 do
                    local food = self.foods[f]
                    if new_phead.x == food.x and new_phead.y == food.y then
                        ate_food = true
                        self:collectFood(food, psnake)
                        table.remove(self.foods, f)

                        -- Spawn new food based on spawn mode
                        if self.params.food_spawn_mode == "continuous" then
                            table.insert(self.foods, self:spawnFood())
                        elseif self.params.food_spawn_mode == "batch" then
                            if #self.foods == 0 then
                                for j = 1, self.params.food_count do
                                    table.insert(self.foods, self:spawnFood())
                                end
                            end
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
    -- Call parent to handle virtual key tracking for demo playback
    SnakeGame.super.keypressed(self, key)

    local handled = false

    if self.params.movement_type == "smooth" then
        -- Smooth movement: track key states for analog turning
        if key == 'left' or key == 'a' then
            self.snake.smooth_turn_left = true
            handled = true
        elseif key == 'right' or key == 'd' then
            self.snake.smooth_turn_right = true
            handled = true
        end
    else
        local new_dir = nil

        if key == 'left' or key == 'a' then
            new_dir = {x = -1, y = 0}
        elseif key == 'right' or key == 'd' then
            new_dir = {x = 1, y = 0}
        elseif key == 'up' or key == 'w' then
            new_dir = {x = 0, y = -1}
        elseif key == 'down' or key == 's' then
            new_dir = {x = 0, y = 1}
        end

        if new_dir then
            -- Queue direction via MovementController (handles reverse check internally)
            local queued = self.movement_controller:queueGridDirection("snake", new_dir.x, new_dir.y, self.snake.direction)
            if queued then
                handled = true
                -- Also apply to additional player snakes (multi-snake control)
                for i = 2, #self.player_snakes do
                    local psnake = self.player_snakes[i]
                    if psnake.alive then
                        psnake.next_direction = {x = new_dir.x, y = new_dir.y}
                    end
                end
            end
        end
    end

    return handled
end

function SnakeGame:keyreleased(key)
    -- Call parent to handle virtual key tracking for demo playback
    SnakeGame.super.keyreleased(self, key)

    if self.params.movement_type == "smooth" then
        -- Track key release for smooth turning
        if key == 'left' or key == 'a' then
            self.snake.smooth_turn_left = false
        elseif key == 'right' or key == 'd' then
            self.snake.smooth_turn_right = false
        end
    end
end

function SnakeGame:updateSmoothMovement(dt)
    -- Apply rotation based on key states
    local turn_rate_radians = math.rad(self.params.turn_speed) * dt

    if self.snake.smooth_turn_left then
        self.snake.smooth_angle = self.snake.smooth_angle - turn_rate_radians
    end
    if self.snake.smooth_turn_right then
        self.snake.smooth_angle = self.snake.smooth_angle + turn_rate_radians
    end

    -- Normalize angle to -pi to pi
    while self.snake.smooth_angle > math.pi do
        self.snake.smooth_angle = self.snake.smooth_angle - 2 * math.pi
    end
    while self.snake.smooth_angle < -math.pi do
        self.snake.smooth_angle = self.snake.smooth_angle + 2 * math.pi
    end

    -- Move forward in current direction
    -- smooth_x and smooth_y are in GRID coordinates, so move in grid units
    local cells_per_second = (self.params.snake_speed or 8) * 0.5
    local distance_per_frame = cells_per_second * dt  -- Grid cells, not pixels
    local dx = math.cos(self.snake.smooth_angle) * distance_per_frame
    local dy = math.sin(self.snake.smooth_angle) * distance_per_frame

    self.snake.smooth_x = self.snake.smooth_x + dx
    self.snake.smooth_y = self.snake.smooth_y + dy

    -- Handle wall modes
    if self.params.wall_mode == "wrap" then
        local old_x, old_y = self.snake.smooth_x, self.snake.smooth_y
        self.snake.smooth_x, self.snake.smooth_y = self:wrapPosition(
            self.snake.smooth_x, self.snake.smooth_y, self.grid_width, self.grid_height)
        -- Clear trail on wrap to avoid line across screen
        if old_x ~= self.snake.smooth_x or old_y ~= self.snake.smooth_y then
            self.snake.smooth_trail = {}
            self.snake.smooth_trail_length = 0
        end
    elseif self.params.wall_mode == "death" then
        -- Check boundaries and shaped arenas
        local out_of_bounds = false
        if self.params.arena_shape == "circle" or self.params.arena_shape == "hexagon" then
            local current_pos = {x = self.snake.smooth_x - 0.5, y = self.snake.smooth_y - 0.5}
            if not self:isInsideArena(current_pos) then
                out_of_bounds = true
            end
        else
            if self.snake.smooth_x < 0 or self.snake.smooth_x >= self.grid_width or
               self.snake.smooth_y < 0 or self.snake.smooth_y >= self.grid_height then
                out_of_bounds = true
            end
        end

        if out_of_bounds then
            self:playSound("death", 1.0)
            self:onComplete()
            return
        end
    end
    -- Note: Bounce mode handled by obstacle collision below

    -- Add current position to trail
    table.insert(self.snake.smooth_trail, {x = self.snake.smooth_x, y = self.snake.smooth_y})
    self.snake.smooth_trail_length = self.snake.smooth_trail_length + math.sqrt(dx*dx + dy*dy)  -- dx/dy already in grid units

    -- Trim trail to target length
    while self.snake.smooth_trail_length > self.snake.smooth_target_length and #self.snake.smooth_trail > 1 do
        local removed = table.remove(self.snake.smooth_trail, 1)
        if #self.snake.smooth_trail > 0 then
            local next_point = self.snake.smooth_trail[1]
            local segment_dx = next_point.x - removed.x
            local segment_dy = next_point.y - removed.y
            local segment_length = math.sqrt(segment_dx*segment_dx + segment_dy*segment_dy)  -- Already in grid units
            self.snake.smooth_trail_length = self.snake.smooth_trail_length - segment_length
        end
    end

    -- Check collision with obstacles (radius-based for smooth movement)
    local head_grid_x = math.floor(self.snake.smooth_x)
    local head_grid_y = math.floor(self.snake.smooth_y)

    -- Define girth scale for collision checks
    local girth_scale = self.params.girth or 1

    -- Obstacle collision - scales proportionally with girth to maintain consistent difficulty
    -- Formula: base + (girth * scale) keeps collision tight relative to visual size at all girth levels
    local obstacle_collision_distance = 0.3 + (girth_scale * 0.5)

    for _, obstacle in ipairs(self.obstacles or {}) do
        -- Obstacle center is at grid position + 0.5
        local obstacle_center_x = obstacle.x + 0.5
        local obstacle_center_y = obstacle.y + 0.5

        -- Check distance from head center to obstacle center
        local dx_to_obs = self.snake.smooth_x - obstacle_center_x
        local dy_to_obs = self.snake.smooth_y - obstacle_center_y
        local distance = math.sqrt(dx_to_obs*dx_to_obs + dy_to_obs*dy_to_obs)

        if distance < obstacle_collision_distance then
            -- Check if this is a wall or regular obstacle
            local is_wall = (obstacle.type == "walls" or obstacle.type == "bounce_wall")

            -- Determine if we should bounce or die
            local should_bounce = false
            if is_wall and self.params.wall_mode == "bounce" then
                should_bounce = true
            elseif not is_wall and self.params.obstacle_bounce then
                should_bounce = true
            end

            if should_bounce then
                -- Bounce at ±45° in direction with more open space
                local angle_option1 = self.snake.smooth_angle + math.rad(45)
                local angle_option2 = self.snake.smooth_angle - math.rad(45)

                -- Cast ray in each direction to see which has more open space
                local ray_length = 5  -- Check 5 grid cells ahead
                local function checkOpenSpace(angle)
                    local steps = 10
                    for step = 1, steps do
                        local check_dist = (step / steps) * ray_length
                        local check_x = self.snake.smooth_x + math.cos(angle) * check_dist
                        local check_y = self.snake.smooth_y + math.sin(angle) * check_dist

                        -- Check if this point hits an obstacle
                        for _, obs in ipairs(self.obstacles or {}) do
                            local obs_cx = obs.x + 0.5
                            local obs_cy = obs.y + 0.5
                            local dx_check = check_x - obs_cx
                            local dy_check = check_y - obs_cy
                            if math.sqrt(dx_check*dx_check + dy_check*dy_check) < 0.5 then
                                return step - 1  -- Return how far we got
                            end
                        end

                        -- Check arena bounds for shaped arenas
                        if self.params.arena_shape == "circle" or self.params.arena_shape == "hexagon" then
                            if not self:isInsideArena({x = check_x - 0.5, y = check_y - 0.5}) then
                                return step - 1
                            end
                        end
                    end
                    return steps  -- Made it all the way
                end

                local space1 = checkOpenSpace(angle_option1)
                local space2 = checkOpenSpace(angle_option2)

                -- Pick the angle with more space
                self.snake.smooth_angle = (space1 >= space2) and angle_option1 or angle_option2

                -- Move back slightly to get away from obstacle
                self.snake.smooth_x = self.snake.smooth_x - math.cos(self.snake.smooth_angle - math.pi) * 0.2
                self.snake.smooth_y = self.snake.smooth_y - math.sin(self.snake.smooth_angle - math.pi) * 0.2

                -- Clear some trail
                if #self.snake.smooth_trail > 5 then
                    for i = 1, 3 do
                        table.remove(self.snake.smooth_trail)
                    end
                end

                break  -- Only bounce once per frame
            else
                -- Death mode or other modes - die on obstacle hit
                self:playSound("death", 1.0)
                self:onComplete()
                return
            end
        end
    end

    -- Check collision with own trail (self-collision)
    -- Skip trail collision if phase_through_tail is enabled
    if not self.params.phase_through_tail then
        -- Skip the trail section close to the head to avoid false collision with neck
        -- Calculate how much trail length to skip (in grid units) - girth_scale defined above
        local skip_trail_length = 1.0 * girth_scale  -- Skip more trail for girthier snakes
        local trail_collision_distance = 0.1 + (girth_scale * 0.3)  -- Scales with girth (0.4 at girth 1, 1.6 at girth 5)

        local checked_length = 0
        for i = #self.snake.smooth_trail, 1, -1 do
            -- Accumulate length from newest to oldest trail point
            if i < #self.snake.smooth_trail then
                local curr = self.snake.smooth_trail[i]
                local next_pt = self.snake.smooth_trail[i + 1]
                local seg_dx = next_pt.x - curr.x
                local seg_dy = next_pt.y - curr.y
                checked_length = checked_length + math.sqrt(seg_dx*seg_dx + seg_dy*seg_dy)
            end

            -- Only check collision once we're past the skip zone
            if checked_length > skip_trail_length then
                local trail_point = self.snake.smooth_trail[i]
                local dx = self.snake.smooth_x - trail_point.x
                local dy = self.snake.smooth_y - trail_point.y
                local distance = math.sqrt(dx*dx + dy*dy)

                if distance < trail_collision_distance then
                    self:playSound("death", 1.0)
                    self:onComplete()
                    return
                end
            end
        end
    end

    -- Check food collision (radius-based for smooth movement)
    -- Food collection - scales with girth, slightly more forgiving than obstacles
    local food_collection_distance = 0.35 + (girth_scale * 0.5)  -- At girth 1: 0.85, girth 5: 2.85

    for i = #self.foods, 1, -1 do
        local food = self.foods[i]
        -- Food center is at grid position + 0.5
        local food_center_x = food.x + 0.5
        local food_center_y = food.y + 0.5

        -- Check distance from head center to food center
        local dx = self.snake.smooth_x - food_center_x
        local dy = self.snake.smooth_y - food_center_y
        local distance = math.sqrt(dx*dx + dy*dy)

        if distance < food_collection_distance then
            -- Collect food
            self.snake.smooth_target_length = self.snake.smooth_target_length + self.params.growth_per_food
            self.metrics.snake_length = math.floor(self.snake.smooth_target_length)

            -- Remove and respawn food
            table.remove(self.foods, i)
            if self.params.food_spawn_mode == "continuous" then
                table.insert(self.foods, self:spawnFood())
            elseif self.params.food_spawn_mode == "batch" then
                if #self.foods == 0 then
                    for j = 1, self.params.food_count do
                        table.insert(self.foods, self:spawnFood())
                    end
                end
            end

            self:playSound("eat", 0.8)
        end
    end

    -- Update additional player snakes (multi-snake control)
    for i = 2, #self.player_snakes do
        local psnake = self.player_snakes[i]
        if psnake.alive and psnake.smooth_x then
            -- Apply same rotation as main snake
            psnake.smooth_angle = psnake.smooth_angle or 0
            if self.snake.smooth_turn_left then
                psnake.smooth_angle = psnake.smooth_angle - turn_rate_radians
            end
            if self.snake.smooth_turn_right then
                psnake.smooth_angle = psnake.smooth_angle + turn_rate_radians
            end

            -- Normalize angle
            while psnake.smooth_angle > math.pi do
                psnake.smooth_angle = psnake.smooth_angle - 2 * math.pi
            end
            while psnake.smooth_angle < -math.pi do
                psnake.smooth_angle = psnake.smooth_angle + 2 * math.pi
            end

            -- Move forward
            local dx = math.cos(psnake.smooth_angle) * distance_per_frame
            local dy = math.sin(psnake.smooth_angle) * distance_per_frame
            psnake.smooth_x = psnake.smooth_x + dx
            psnake.smooth_y = psnake.smooth_y + dy

            -- Handle walls
            if self.params.wall_mode == "wrap" then
                if psnake.smooth_x < 0 then psnake.smooth_x = psnake.smooth_x + self.grid_width end
                if psnake.smooth_x >= self.grid_width then psnake.smooth_x = psnake.smooth_x - self.grid_width end
                if psnake.smooth_y < 0 then psnake.smooth_y = psnake.smooth_y + self.grid_height end
                if psnake.smooth_y >= self.grid_height then psnake.smooth_y = psnake.smooth_y - self.grid_height end
            elseif self.params.wall_mode == "death" then
                local out_of_bounds = false
                if self.params.arena_shape == "circle" or self.params.arena_shape == "hexagon" then
                    local current_pos = {x = psnake.smooth_x - 0.5, y = psnake.smooth_y - 0.5}
                    if not self:isInsideArena(current_pos) then
                        out_of_bounds = true
                    end
                else
                    if psnake.smooth_x < 0 or psnake.smooth_x >= self.grid_width or
                       psnake.smooth_y < 0 or psnake.smooth_y >= self.grid_height then
                        out_of_bounds = true
                    end
                end
                if out_of_bounds then
                    psnake.alive = false
                end
            end
            -- Bounce mode handled by obstacle collision below

            -- Check obstacle collision
            for _, obstacle in ipairs(self.obstacles or {}) do
                local obstacle_center_x = obstacle.x + 0.5
                local obstacle_center_y = obstacle.y + 0.5
                local dx_obs = psnake.smooth_x - obstacle_center_x
                local dy_obs = psnake.smooth_y - obstacle_center_y
                local distance = math.sqrt(dx_obs*dx_obs + dy_obs*dy_obs)

                if distance < obstacle_collision_distance then
                    if self.params.wall_mode == "bounce" then
                        -- Bounce at ±45° in direction with more open space
                        local angle_option1 = psnake.smooth_angle + math.rad(45)
                        local angle_option2 = psnake.smooth_angle - math.rad(45)

                        -- Simple open space check
                        local function checkOpenSpace(angle)
                            local ray_length = 5
                            local steps = 10
                            for step = 1, steps do
                                local check_dist = (step / steps) * ray_length
                                local check_x = psnake.smooth_x + math.cos(angle) * check_dist
                                local check_y = psnake.smooth_y + math.sin(angle) * check_dist

                                for _, obs in ipairs(self.obstacles or {}) do
                                    local obs_cx = obs.x + 0.5
                                    local obs_cy = obs.y + 0.5
                                    local dx_check = check_x - obs_cx
                                    local dy_check = check_y - obs_cy
                                    if math.sqrt(dx_check*dx_check + dy_check*dy_check) < 0.5 then
                                        return step - 1
                                    end
                                end

                                if self.params.arena_shape == "circle" or self.params.arena_shape == "hexagon" then
                                    if not self:isInsideArena({x = check_x - 0.5, y = check_y - 0.5}) then
                                        return step - 1
                                    end
                                end
                            end
                            return steps
                        end

                        local space1 = checkOpenSpace(angle_option1)
                        local space2 = checkOpenSpace(angle_option2)
                        psnake.smooth_angle = (space1 >= space2) and angle_option1 or angle_option2

                        -- Move back slightly
                        psnake.smooth_x = psnake.smooth_x - math.cos(psnake.smooth_angle - math.pi) * 0.2
                        psnake.smooth_y = psnake.smooth_y - math.sin(psnake.smooth_angle - math.pi) * 0.2

                        break
                    else
                        psnake.alive = false
                        break
                    end
                end
            end

            -- Check food collision
            if psnake.alive then
                for i = #self.foods, 1, -1 do
                    local food = self.foods[i]
                    local food_center_x = food.x + 0.5
                    local food_center_y = food.y + 0.5
                    local dx_food = psnake.smooth_x - food_center_x
                    local dy_food = psnake.smooth_y - food_center_y
                    local distance = math.sqrt(dx_food*dx_food + dy_food*dy_food)
                    if distance < food_collection_distance then
                        -- Collect food
                        psnake.smooth_target_length = psnake.smooth_target_length + self.params.growth_per_food
                        table.remove(self.foods, i)
                        if self.params.food_spawn_mode == "continuous" then
                            table.insert(self.foods, self:spawnFood())
                        elseif self.params.food_spawn_mode == "batch" then
                            if #self.foods == 0 then
                                for j = 1, self.params.food_count do
                                    table.insert(self.foods, self:spawnFood())
                                end
                            end
                        end
                        self:playSound("eat", 0.8)
                        break
                    end
                end
            end

            -- Update trail
            if psnake.alive then
                table.insert(psnake.smooth_trail, {x = psnake.smooth_x, y = psnake.smooth_y})
                psnake.smooth_trail_length = psnake.smooth_trail_length + math.sqrt(dx*dx + dy*dy)

                -- Trim trail
                while psnake.smooth_trail_length > psnake.smooth_target_length and #psnake.smooth_trail > 1 do
                    local removed = table.remove(psnake.smooth_trail, 1)
                    if #psnake.smooth_trail > 0 then
                        local next_point = psnake.smooth_trail[1]
                        local segment_dx = next_point.x - removed.x
                        local segment_dy = next_point.y - removed.y
                        local segment_length = math.sqrt(segment_dx*segment_dx + segment_dy*segment_dy)
                        psnake.smooth_trail_length = psnake.smooth_trail_length - segment_length
                    end
                end

                -- Update body position for camera
                if psnake.body and #psnake.body > 0 then
                    psnake.body[1] = {x = math.floor(psnake.smooth_x), y = math.floor(psnake.smooth_y)}
                end
            end
        end
    end

    -- Update "snake" position for camera/fog tracking
    self.snake.body[1] = {x = head_grid_x, y = head_grid_y}
end

function SnakeGame:spawnFood()
    local food_pos
    local pattern = self.params.food_spawn_pattern or "random"

    if pattern == "cluster" and #self.foods > 0 then
        -- Spawn near existing food
        local ref_food = self.foods[math.random(#self.foods)]
        repeat
            food_pos = {
                x = ref_food.x + math.random(-3, 3),
                y = ref_food.y + math.random(-3, 3)
            }
            food_pos.x = math.max(0, math.min(self.grid_width - 1, food_pos.x))
            food_pos.y = math.max(0, math.min(self.grid_height - 1, food_pos.y))
        until not self:checkCollision(food_pos, true)

    elseif pattern == "line" then
        -- Spawn in a line
        local line_y = math.floor(self.grid_height / 2)
        repeat
            food_pos = {
                x = math.random(0, self.grid_width - 1),
                y = line_y + math.random(-2, 2)
            }
        until not self:checkCollision(food_pos, true)

    elseif pattern == "spiral" then
        -- Spawn in spiral pattern that expands and contracts
        self.spiral_angle = (self.spiral_angle or 0) + 0.5

        -- Initialize spiral state
        if not self.spiral_radius then
            self.spiral_radius = 2  -- Start tight
            self.spiral_expanding = true
        end

        -- Update radius (expand out to max, then contract back to min)
        local min_radius = 2
        local max_radius = math.min(self.grid_width, self.grid_height) * 0.4  -- 40% of smallest dimension
        local radius_step = 0.5  -- How much radius changes per food spawn

        if self.spiral_expanding then
            self.spiral_radius = self.spiral_radius + radius_step
            if self.spiral_radius >= max_radius then
                self.spiral_expanding = false
            end
        else
            self.spiral_radius = self.spiral_radius - radius_step
            if self.spiral_radius <= min_radius then
                self.spiral_expanding = true
            end
        end

        local center_x = self.grid_width / 2
        local center_y = self.grid_height / 2
        repeat
            food_pos = {
                x = math.floor(center_x + math.cos(self.spiral_angle) * self.spiral_radius),
                y = math.floor(center_y + math.sin(self.spiral_angle) * self.spiral_radius)
            }
            food_pos.x = math.max(0, math.min(self.grid_width - 1, food_pos.x))
            food_pos.y = math.max(0, math.min(self.grid_height - 1, food_pos.y))
        until not self:checkCollision(food_pos, true)

    else
        -- Random (default)
        repeat
            food_pos = {
                x = math.random(0, self.grid_width - 1),
                y = math.random(0, self.grid_height - 1)
            }
        until not self:checkCollision(food_pos, true)
    end

    -- Determine food type based on probabilities
    food_pos.type = "normal"  -- default
    food_pos.size = 1  -- default size

    -- Check for golden food first (rarest)
    if math.random() < self.params.golden_food_spawn_rate then
        food_pos.type = "golden"
        food_pos.size = 3  -- Golden food gives more segments (growth only, visual is still 1 tile)
    -- Check for bad food
    elseif math.random() < self.params.bad_food_chance then
        food_pos.type = "bad"
        food_pos.size = 1  -- Standard size
    -- Apply size variance to normal food (affects growth amount, NOT visual size)
    elseif self.params.food_size_variance > 0 then
        -- Size variance: 0 = all size 1, 1.0 = sizes 1-5
        -- NOTE: This only affects growth amount, visual size is always 1 tile
        local max_size = 1 + math.floor(self.params.food_size_variance * 4)
        food_pos.size = math.random(1, max_size)
    end

    food_pos.lifetime = 0  -- Track lifetime

    return food_pos
end

function SnakeGame:createAISnake(index)
    -- Spawn AI snake at random position away from player
    local spawn_x, spawn_y
    local max_attempts = 200
    local attempt = 0
    repeat
        attempt = attempt + 1
        spawn_x = math.random(0, self.grid_width - 1)
        spawn_y = math.random(0, self.grid_height - 1)

        -- Ensure spawn is far enough from player
        local player_head = self.snake.body[1]
        local dist = math.abs(spawn_x - player_head.x) + math.abs(spawn_y - player_head.y)

        -- Check if position is inside shaped arenas
        local inside_arena = true
        if self.params.arena_shape == "circle" or self.params.arena_shape == "hexagon" then
            inside_arena = self:isInsideArena({x = spawn_x, y = spawn_y})
        end

        if dist > 10 and not self:checkCollision({x = spawn_x, y = spawn_y}, true) and inside_arena then
            break
        end
    until attempt >= max_attempts

    -- Fallback: spawn near center if no valid position found
    if attempt >= max_attempts then
        spawn_x = math.floor(self.grid_width / 2) + (index * 2)
        spawn_y = math.floor(self.grid_height / 2)
    end

    return {
        body = {{x = spawn_x, y = spawn_y}},
        direction = {x = 1, y = 0},
        move_timer = 0,
        length = 1,
        alive = true,
        behavior = self.params.ai_behavior,
        target_food = nil  -- Cached food target
    }
end

function SnakeGame:updateAISnakes(dt)
    for _, ai_snake in ipairs(self.ai_snakes) do
        if ai_snake.alive then
            self:updateAISnake(ai_snake, dt)
        end
    end
end

function SnakeGame:updateAISnake(ai_snake, dt)
    ai_snake.move_timer = ai_snake.move_timer + dt

    local move_interval = 1 / self.params.ai_speed
    if ai_snake.move_timer >= move_interval then
        ai_snake.move_timer = ai_snake.move_timer - move_interval

        -- AI decision making based on behavior
        local head = ai_snake.body[1]
        local player_head = self.snake.body[1]

        if ai_snake.behavior == "aggressive" then
            -- Chase player
            if math.abs(head.x - player_head.x) > math.abs(head.y - player_head.y) then
                ai_snake.direction = {x = head.x < player_head.x and 1 or -1, y = 0}
            else
                ai_snake.direction = {x = 0, y = head.y < player_head.y and 1 or -1}
            end
        elseif ai_snake.behavior == "defensive" then
            -- Move away from player
            if math.abs(head.x - player_head.x) > math.abs(head.y - player_head.y) then
                ai_snake.direction = {x = head.x < player_head.x and -1 or 1, y = 0}
            else
                ai_snake.direction = {x = 0, y = head.y < player_head.y and -1 or 1}
            end
        else  -- "food_focused"
            -- Find nearest food
            local nearest_food = nil
            local nearest_dist = math.huge
            for _, food in ipairs(self.foods) do
                local dist = math.abs(head.x - food.x) + math.abs(head.y - food.y)
                if dist < nearest_dist then
                    nearest_dist = dist
                    nearest_food = food
                end
            end

            if nearest_food then
                if math.abs(head.x - nearest_food.x) > math.abs(head.y - nearest_food.y) then
                    ai_snake.direction = {x = head.x < nearest_food.x and 1 or -1, y = 0}
                else
                    ai_snake.direction = {x = 0, y = head.y < nearest_food.y and 1 or -1}
                end
            end
        end

        -- Move AI snake
        local new_head = {
            x = head.x + ai_snake.direction.x,
            y = head.y + ai_snake.direction.y
        }

        -- Handle wall collision based on wall_mode
        if self.params.wall_mode == "wrap" then
            new_head.x, new_head.y = self:wrapPosition(new_head.x, new_head.y, self.grid_width, self.grid_height)
        elseif self.params.wall_mode == "death" then
            if new_head.x < 0 or new_head.x >= self.grid_width or new_head.y < 0 or new_head.y >= self.grid_height then
                ai_snake.alive = false
                return
            end
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

        -- Check collision with obstacles or self
        if self:checkCollision(new_head, false) then
            ai_snake.alive = false
            return
        end

        -- Check self collision
        for _, segment in ipairs(ai_snake.body) do
            if new_head.x == segment.x and new_head.y == segment.y then
                ai_snake.alive = false
                return
            end
        end

        table.insert(ai_snake.body, 1, new_head)

        -- Check food collision
        local ate_food = false
        for i = #self.foods, 1, -1 do
            local food = self.foods[i]
            if new_head.x == food.x and new_head.y == food.y then
                ate_food = true
                ai_snake.length = ai_snake.length + 1
                table.remove(self.foods, i)

                -- Spawn new food based on spawn mode
                if self.params.food_spawn_mode == "continuous" then
                    table.insert(self.foods, self:spawnFood())
                elseif self.params.food_spawn_mode == "batch" then
                    if #self.foods == 0 then
                        for j = 1, self.params.food_count do
                            table.insert(self.foods, self:spawnFood())
                        end
                    end
                end

                break
            end
        end

        if not ate_food then
            table.remove(ai_snake.body)
        end
    end
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

function SnakeGame:createObstacles()
    local obstacles = {}
    -- Use variant obstacle_count
    local obstacle_count = math.floor(self.params.obstacle_count * self.difficulty_modifiers.complexity)
    local obstacle_type = self.params.obstacle_type or "static_blocks"

    for i = 1, obstacle_count do
        local obs_pos, collision
        repeat
            collision = false
            obs_pos = {
                x = math.random(0, self.grid_width - 1),
                y = math.random(0, self.grid_height - 1),
                type = obstacle_type,
                move_timer = 0,
                move_dir_x = 0,
                move_dir_y = 0
            }

            -- Initialize moving blocks
            if obstacle_type == "moving_blocks" then
                obs_pos.move_dir_x = (math.random() < 0.5) and 1 or -1
                obs_pos.move_dir_y = 0
            end

            for _, segment in ipairs(self.snake.body) do if obs_pos.x == segment.x and obs_pos.y == segment.y then collision = true; break end end
            if not collision then for _, existing_obs in ipairs(obstacles) do if obs_pos.x == existing_obs.x and obs_pos.y == existing_obs.y then collision = true; break end end end
        until not collision
        table.insert(obstacles, obs_pos)
    end
    return obstacles
end

function SnakeGame:onArenaShrink(margins)
    local bounds = self.arena_controller:getBounds()

    -- Add left wall
    for y = 0, self.grid_height - 1 do
        table.insert(self.obstacles, {x = margins.left - 1, y = y, type = "walls"})
    end

    -- Add right wall
    for y = 0, self.grid_height - 1 do
        table.insert(self.obstacles, {x = self.grid_width - margins.right, y = y, type = "walls"})
    end

    -- Add top wall
    for x = 0, self.grid_width - 1 do
        table.insert(self.obstacles, {x = x, y = margins.top - 1, type = "walls"})
    end

    -- Add bottom wall
    for x = 0, self.grid_width - 1 do
        table.insert(self.obstacles, {x = x, y = self.grid_height - margins.bottom, type = "walls"})
    end
end

function SnakeGame:syncArenaState()
    self.grid_width = self.arena_controller.current_width
    self.grid_height = self.arena_controller.current_height
end

function SnakeGame:isInsideArena(pos)
    return self.arena_controller:isInsideGrid(pos.x, pos.y)
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
    -- Helper function to handle food collection for any snake
    -- 'snake' can be player snake (from player_snakes array) or main self.snake

    -- Handle different food types
    if food.type == "bad" then
        -- Bad food: shrink snake by removing tail segments
        local snake_body = snake.body or snake or self.snake
        local shrink_amount = math.min(3, #snake_body - 1)  -- Remove up to 3, but keep at least head
        for s = 1, shrink_amount do
            if #snake_body > 1 then
                table.remove(snake_body)
            end
        end
        self:playSound("death", 0.5)  -- Negative sound

    elseif food.type == "golden" then
        -- Golden food: bonus effects (bigger growth, speed boost)
        local growth = food.size * self.params.growth_per_food
        self.pending_growth = self.pending_growth + growth

        -- Extra speed boost
        if self.params.speed_increase_per_food > 0 then
            self.params.snake_speed = self.params.snake_speed + (self.params.speed_increase_per_food * 2)
        end
        self:playSound("success", 0.6)  -- Special sound

    else
        -- Normal food: standard behavior
        -- Add pending growth segments based on food size and growth_per_food
        local growth = food.size * self.params.growth_per_food
        self.pending_growth = self.pending_growth + growth

        -- Increase speed (if speed_increase_per_food is set)
        if self.params.speed_increase_per_food > 0 then
            self.params.snake_speed = self.params.snake_speed + self.params.speed_increase_per_food
        end

        self:playSound("eat", 0.8)
    end

    -- Track girth growth (for all food types)
    if self.params.girth_growth > 0 and #self.snake.body > 0 then
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
    for _, obstacle in ipairs(self.obstacles or {}) do
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

                for _, obs in ipairs(self.obstacles) do
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