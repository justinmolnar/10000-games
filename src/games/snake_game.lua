local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local SnakeView = require('src.games.views.snake_view')
local SnakeGame = BaseGame:extend('SnakeGame')

-- Config-driven defaults with safe fallbacks
local SCfg = (Config and Config.games and Config.games.snake) or {}
local GRID_SIZE = SCfg.grid_size or 20
local BASE_SPEED = SCfg.base_speed or 8
local BASE_TARGET_LENGTH = SCfg.base_target_length or 20
local BASE_OBSTACLE_COUNT = SCfg.base_obstacle_count or 5

function SnakeGame:init(game_data, cheats, di, variant_override)
    SnakeGame.super.init(self, game_data, cheats, di, variant_override)
    self.di = di
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.snake) or SCfg
    self.GRID_SIZE = (runtimeCfg and runtimeCfg.grid_size) or GRID_SIZE

    -- Apply variant difficulty modifier (from Phase 1.1-1.2)
    local variant_difficulty = self.variant and self.variant.difficulty_modifier or 1.0

    local speed_modifier = self.cheats.speed_modifier or 1.0

    -- Load all variant properties (following Dodge pattern)
    -- Movement properties
    self.movement_type = (runtimeCfg and runtimeCfg.movement_type) or "grid"
    if self.variant and self.variant.movement_type then
        self.movement_type = self.variant.movement_type
    end

    self.snake_speed = (runtimeCfg and runtimeCfg.snake_speed) or BASE_SPEED
    if self.variant and self.variant.snake_speed ~= nil then
        self.snake_speed = self.variant.snake_speed
    end

    self.speed_increase_per_food = (runtimeCfg and runtimeCfg.speed_increase_per_food) or 0
    if self.variant and self.variant.speed_increase_per_food ~= nil then
        self.speed_increase_per_food = self.variant.speed_increase_per_food
    end

    self.max_speed_cap = (runtimeCfg and runtimeCfg.max_speed_cap) or 20
    if self.variant and self.variant.max_speed_cap ~= nil then
        self.max_speed_cap = self.variant.max_speed_cap
    end

    -- Growth & Body properties
    self.growth_per_food = (runtimeCfg and runtimeCfg.growth_per_food) or 1
    if self.variant and self.variant.growth_per_food ~= nil then
        self.growth_per_food = self.variant.growth_per_food
    end

    self.shrink_over_time = (runtimeCfg and runtimeCfg.shrink_over_time) or 0
    if self.variant and self.variant.shrink_over_time ~= nil then
        self.shrink_over_time = self.variant.shrink_over_time
    end

    self.phase_through_tail = (runtimeCfg and runtimeCfg.phase_through_tail) or false
    if self.variant and self.variant.phase_through_tail ~= nil then
        self.phase_through_tail = self.variant.phase_through_tail
    end

    self.max_length_cap = (runtimeCfg and runtimeCfg.max_length_cap) or 9999
    if self.variant and self.variant.max_length_cap ~= nil then
        self.max_length_cap = self.variant.max_length_cap
    end

    self.girth = (runtimeCfg and runtimeCfg.girth) or 1
    if self.variant and self.variant.girth ~= nil then
        self.girth = self.variant.girth
    end

    self.girth_growth = (runtimeCfg and runtimeCfg.girth_growth) or 0
    if self.variant and self.variant.girth_growth ~= nil then
        self.girth_growth = self.variant.girth_growth
    end

    -- Arena properties
    self.wall_mode = (runtimeCfg and runtimeCfg.wall_mode) or "wrap"
    if self.variant and self.variant.wall_mode then
        self.wall_mode = self.variant.wall_mode
    end

    self.arena_size = (runtimeCfg and runtimeCfg.arena_size) or 1.0
    if self.variant and self.variant.arena_size ~= nil then
        self.arena_size = self.variant.arena_size
    end

    self.arena_shape = (runtimeCfg and runtimeCfg.arena_shape) or "rectangle"
    if self.variant and self.variant.arena_shape then
        self.arena_shape = self.variant.arena_shape
    end

    self.shrinking_arena = (runtimeCfg and runtimeCfg.shrinking_arena) or false
    if self.variant and self.variant.shrinking_arena ~= nil then
        self.shrinking_arena = self.variant.shrinking_arena
    end

    self.moving_walls = (runtimeCfg and runtimeCfg.moving_walls) or false
    if self.variant and self.variant.moving_walls ~= nil then
        self.moving_walls = self.variant.moving_walls
    end

    -- Food properties
    self.food_count = (runtimeCfg and runtimeCfg.food_count) or 1
    if self.variant and self.variant.food_count ~= nil then
        self.food_count = self.variant.food_count
    end

    self.food_spawn_pattern = (runtimeCfg and runtimeCfg.food_spawn_pattern) or "random"
    if self.variant and self.variant.food_spawn_pattern then
        self.food_spawn_pattern = self.variant.food_spawn_pattern
    end

    self.food_lifetime = (runtimeCfg and runtimeCfg.food_lifetime) or 0
    if self.variant and self.variant.food_lifetime ~= nil then
        self.food_lifetime = self.variant.food_lifetime
    end

    self.food_movement = (runtimeCfg and runtimeCfg.food_movement) or "static"
    if self.variant and self.variant.food_movement then
        self.food_movement = self.variant.food_movement
    end

    self.food_size_variance = (runtimeCfg and runtimeCfg.food_size_variance) or 0
    if self.variant and self.variant.food_size_variance ~= nil then
        self.food_size_variance = self.variant.food_size_variance
    end

    self.bad_food_chance = (runtimeCfg and runtimeCfg.bad_food_chance) or 0
    if self.variant and self.variant.bad_food_chance ~= nil then
        self.bad_food_chance = self.variant.bad_food_chance
    end

    self.golden_food_spawn_rate = (runtimeCfg and runtimeCfg.golden_food_spawn_rate) or 0
    if self.variant and self.variant.golden_food_spawn_rate ~= nil then
        self.golden_food_spawn_rate = self.variant.golden_food_spawn_rate
    end

    -- Obstacle properties
    self.obstacle_count_variant = (runtimeCfg and runtimeCfg.obstacle_count) or BASE_OBSTACLE_COUNT
    if self.variant and self.variant.obstacle_count ~= nil then
        self.obstacle_count_variant = self.variant.obstacle_count
    end

    self.obstacle_type = (runtimeCfg and runtimeCfg.obstacle_type) or "walls"
    if self.variant and self.variant.obstacle_type then
        self.obstacle_type = self.variant.obstacle_type
    end

    self.obstacle_spawn_over_time = (runtimeCfg and runtimeCfg.obstacle_spawn_over_time) or 0
    if self.variant and self.variant.obstacle_spawn_over_time ~= nil then
        self.obstacle_spawn_over_time = self.variant.obstacle_spawn_over_time
    end

    -- AI properties
    self.ai_snake_count = (runtimeCfg and runtimeCfg.ai_snake_count) or 0
    if self.variant and self.variant.ai_snake_count ~= nil then
        self.ai_snake_count = self.variant.ai_snake_count
    end

    self.ai_behavior = (runtimeCfg and runtimeCfg.ai_behavior) or "food_focused"
    if self.variant and self.variant.ai_behavior then
        self.ai_behavior = self.variant.ai_behavior
    end

    self.ai_speed = (runtimeCfg and runtimeCfg.ai_speed) or self.snake_speed
    if self.variant and self.variant.ai_speed ~= nil then
        self.ai_speed = self.variant.ai_speed
    end

    self.snake_collision_mode = (runtimeCfg and runtimeCfg.snake_collision_mode) or "both_die"
    if self.variant and self.variant.snake_collision_mode then
        self.snake_collision_mode = self.variant.snake_collision_mode
    end

    self.snake_count = (runtimeCfg and runtimeCfg.snake_count) or 1
    if self.variant and self.variant.snake_count ~= nil then
        self.snake_count = self.variant.snake_count
    end

    -- Victory properties
    self.victory_condition = (runtimeCfg and runtimeCfg.victory_condition) or "length"
    if self.variant and self.variant.victory_condition then
        self.victory_condition = self.variant.victory_condition
    end

    self.victory_limit = (runtimeCfg and runtimeCfg.victory_limit) or BASE_TARGET_LENGTH
    if self.variant and self.variant.victory_limit ~= nil then
        self.victory_limit = self.variant.victory_limit
    end

    -- Visual properties
    self.fog_of_war = (runtimeCfg and runtimeCfg.fog_of_war) or "none"
    if self.variant and self.variant.fog_of_war then
        self.fog_of_war = self.variant.fog_of_war
    end

    self.invisible_tail = (runtimeCfg and runtimeCfg.invisible_tail) or false
    if self.variant and self.variant.invisible_tail ~= nil then
        self.invisible_tail = self.variant.invisible_tail
    end

    self.camera_mode = (runtimeCfg and runtimeCfg.camera_mode) or "follow_head"
    if self.variant and self.variant.camera_mode then
        self.camera_mode = self.variant.camera_mode
    end

    self.camera_zoom = (runtimeCfg and runtimeCfg.camera_zoom) or 1.0
    if self.variant and self.variant.camera_zoom ~= nil then
        self.camera_zoom = self.variant.camera_zoom
    end

    self.sprite_style = (runtimeCfg and runtimeCfg.sprite_style) or "uniform"
    if self.variant and self.variant.sprite_style then
        self.sprite_style = self.variant.sprite_style
    end

    -- Sprite set defaults to classic/snake if not specified
    if not self.variant then
        self.variant = {}
    end
    if not self.variant.sprite_set then
        self.variant.sprite_set = (runtimeCfg and runtimeCfg.sprite_set) or "classic/snake"
    end

    -- Arena size setup (apply arena_size multiplier)
    local base_width = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.width) or (SCfg.arena and SCfg.arena.width) or 800
    local base_height = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.height) or (SCfg.arena and SCfg.arena.height) or 600
    self.game_width = math.floor(base_width * self.arena_size)
    self.game_height = math.floor(base_height * self.arena_size)
    
    self.grid_width = math.floor(self.game_width / GRID_SIZE)
    self.grid_height = math.floor(self.game_height / GRID_SIZE)
    
    -- Create main snake
    self.snake = { {x = math.floor(self.grid_width/2), y = math.floor(self.grid_height/2)} }
    self.direction = {x = 1, y = 0}
    self.next_direction = {x = 1, y = 0}

    -- Create additional player snakes (for multi-snake control)
    self.player_snakes = {self.snake}  -- Always include main snake
    if self.snake_count > 1 then
        for i = 2, self.snake_count do
            local offset = i * 3
            local extra_snake = {
                body = { {x = math.floor(self.grid_width/2) + offset, y = math.floor(self.grid_height/2)} },
                direction = {x = 1, y = 0},
                next_direction = {x = 1, y = 0},
                alive = true
            }
            table.insert(self.player_snakes, extra_snake)
        end
    end

    self.move_timer = 0
    -- Use variant snake_speed directly (already configured per-variant)
    self.speed = self.snake_speed * speed_modifier
    -- Use variant victory_limit as target length (for length-based victory)
    self.target_length = self.victory_limit

    -- Use variant obstacle_count_variant instead of BASE_OBSTACLE_COUNT
    self.obstacles = self:createObstacles()

    -- Spawn initial food (respects food_count)
    self.foods = {}  -- Changed from single food to array
    for i = 1, self.food_count do
        table.insert(self.foods, self:spawnFood())
    end

    -- Track girth progression
    self.current_girth = self.girth
    self.segments_for_next_girth = self.girth_growth  -- Segments needed before next girth increase

    -- Initialize AI snakes
    self.ai_snakes = {}
    for i = 1, self.ai_snake_count do
        local ai_snake = self:createAISnake(i)
        table.insert(self.ai_snakes, ai_snake)
    end

    -- Track shrinking timer
    self.shrink_timer = 0

    -- Track obstacle spawning timer
    self.obstacle_spawn_timer = 0

    -- Shrinking arena state
    self.arena_shrink_timer = 0
    self.arena_shrink_interval = 5  -- Shrink every 5 seconds
    self.arena_current_width = self.grid_width
    self.arena_current_height = self.grid_height
    self.arena_min_width = math.max(10, math.floor(self.grid_width * 0.3))
    self.arena_min_height = math.max(10, math.floor(self.grid_height * 0.3))

    -- Moving walls state
    self.wall_move_timer = 0
    self.wall_move_interval = 3  -- Move walls every 3 seconds
    self.wall_offset_x = 0
    self.wall_offset_y = 0

    self.metrics.snake_length = 1
    self.metrics.survival_time = 0

    self.died = false -- Track death state
    self.pending_growth = 0 -- Track segments to add from eating food

    -- Audio/visual variant data (Phase 1.3)
    -- NOTE: Asset loading will be implemented in Phase 2-3
    -- Snake sprites will be loaded from variant.sprite_set
    -- e.g., "classic" (retro green), "modern" (sleek), grid patterns from variant.background

    self.view = SnakeView:new(self, self.variant)
    print("[SnakeGame:init] Variant:", self.variant and self.variant.name or "Default")

    -- Phase 2.3: Load sprite assets with graceful fallback
    self:loadAssets()
end

-- Phase 2.3: Asset loading with fallback
function SnakeGame:loadAssets()
    self.sprites = {}

    if not self.variant or not self.variant.sprite_set then
        print("[SnakeGame:loadAssets] No variant sprite_set, using fallback rendering")
        return
    end

    local game_type = "snake"
    local base_path = "assets/sprites/games/" .. game_type .. "/" .. self.variant.sprite_set .. "/"

    local function tryLoad(filename, sprite_key)
        local filepath = base_path .. filename
        local success, result = pcall(function()
            return love.graphics.newImage(filepath)
        end)

        if success then
            self.sprites[sprite_key] = result
            print("[SnakeGame:loadAssets] Loaded: " .. filepath)
        else
            print("[SnakeGame:loadAssets] Missing: " .. filepath .. " (using fallback)")
        end
    end

    -- Load snake sprites (rotation-based, facing RIGHT)
    tryLoad("segment.png", "segment")  -- Uniform style - same sprite for all parts
    tryLoad("seg_head.png", "seg_head")  -- Segmented style - head
    tryLoad("seg_body.png", "seg_body")  -- Segmented style - body
    tryLoad("seg_tail.png", "seg_tail")  -- Segmented style - tail

    -- Load food sprite (palette swapped for bad/golden)
    tryLoad("food.png", "food")

    -- Load obstacle sprite (used for all obstacle types)
    tryLoad("obstacle.png", "obstacle")

    -- Load background (optional)
    tryLoad("background.png", "background")

    print(string.format("[SnakeGame:loadAssets] Loaded %d sprites for variant: %s",
        self:countLoadedSprites(), self.variant.name or "Unknown"))

    -- Phase 3.3: Load audio - using BaseGame helper
    self:loadAudio()
end

function SnakeGame:countLoadedSprites()
    local count = 0
    for _ in pairs(self.sprites) do
        count = count + 1
    end
    return count
end

function SnakeGame:hasSprite(sprite_key)
    return self.sprites and self.sprites[sprite_key] ~= nil
end

function SnakeGame:setPlayArea(width, height)
    self.game_width = width
    self.game_height = height

    -- Only recalculate grid if GRID_SIZE is set
    if self.GRID_SIZE then
        self.grid_width = math.floor(self.game_width / self.GRID_SIZE)
        self.grid_height = math.floor(self.game_height / self.GRID_SIZE)

        -- Clamp existing positions
        for _, segment in ipairs(self.snake or {}) do
            segment.x = math.max(0, math.min(self.grid_width - 1, segment.x))
            segment.y = math.max(0, math.min(self.grid_height - 1, segment.y))
        end

        if self.food then
            self.food.x = math.max(0, math.min(self.grid_width - 1, self.food.x))
            self.food.y = math.max(0, math.min(self.grid_height - 1, self.food.y))
        end

        print("[SnakeGame] Play area updated to:", width, height, "Grid:", self.grid_width, self.grid_height)
    else
        print("[SnakeGame] setPlayArea called before init completed")
    end
end

function SnakeGame:updateGameLogic(dt)
    self.metrics.survival_time = self.time_elapsed

    -- Update food movement
    if self.food_movement ~= "static" then
        for _, food in ipairs(self.foods) do
            -- Add movement timer if not exists
            food.move_timer = (food.move_timer or 0) + dt
            local move_interval = 1 / 3  -- Food moves 3 times per second

            if food.move_timer >= move_interval then
                food.move_timer = food.move_timer - move_interval

                local new_x, new_y = food.x, food.y

                if self.food_movement == "drift" then
                    -- Random wandering
                    local dir = math.random(1, 4)
                    if dir == 1 then new_x = new_x + 1
                    elseif dir == 2 then new_x = new_x - 1
                    elseif dir == 3 then new_y = new_y + 1
                    else new_y = new_y - 1 end

                elseif self.food_movement == "flee_from_snake" then
                    -- Move away from snake head
                    local head = self.snake[1]
                    if head.x < food.x then new_x = food.x + 1
                    elseif head.x > food.x then new_x = food.x - 1 end
                    if head.y < food.y then new_y = food.y + 1
                    elseif head.y > food.y then new_y = food.y - 1 end

                elseif self.food_movement == "chase_snake" then
                    -- Move toward snake head
                    local head = self.snake[1]
                    if head.x > food.x then new_x = food.x + 1
                    elseif head.x < food.x then new_x = food.x - 1 end
                    if head.y > food.y then new_y = food.y + 1
                    elseif head.y < food.y then new_y = food.y - 1 end
                end

                -- Wrap coordinates
                new_x = (new_x + self.grid_width) % self.grid_width
                new_y = (new_y + self.grid_height) % self.grid_height

                -- Only move if not colliding with obstacles or snake
                if not self:checkCollision({x = new_x, y = new_y}, true) then
                    food.x = new_x
                    food.y = new_y
                end
            end
        end
    end

    -- Update food lifetime (despawn expired foods)
    if self.food_lifetime > 0 then
        for i = #self.foods, 1, -1 do
            local food = self.foods[i]
            food.lifetime = (food.lifetime or 0) + dt
            if food.lifetime >= self.food_lifetime then
                table.remove(self.foods, i)
                -- Spawn new food to replace it
                table.insert(self.foods, self:spawnFood())
            end
        end
    end

    -- Shrinking over time
    if self.shrink_over_time > 0 and #self.snake > 1 then
        self.shrink_timer = self.shrink_timer + dt
        local shrink_interval = 1 / self.shrink_over_time  -- segments per second
        if self.shrink_timer >= shrink_interval then
            self.shrink_timer = self.shrink_timer - shrink_interval
            table.remove(self.snake)  -- Remove tail segment
            self.metrics.snake_length = #self.snake
            -- Die if shrunk to nothing
            if #self.snake == 0 then
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
    if self.obstacle_spawn_over_time > 0 then
        self.obstacle_spawn_timer = self.obstacle_spawn_timer + dt
        local spawn_interval = 1 / self.obstacle_spawn_over_time
        if self.obstacle_spawn_timer >= spawn_interval then
            self.obstacle_spawn_timer = self.obstacle_spawn_timer - spawn_interval
            -- Spawn new obstacle at random free position
            local new_obs
            local attempts = 0
            repeat
                new_obs = {
                    x = math.random(0, self.grid_width - 1),
                    y = math.random(0, self.grid_height - 1),
                    type = self.obstacle_type or "walls"
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

    -- Moving walls
    if self.moving_walls then
        self.wall_move_timer = self.wall_move_timer + dt
        if self.wall_move_timer >= self.wall_move_interval then
            self.wall_move_timer = self.wall_move_timer - self.wall_move_interval

            -- Move walls randomly
            local max_offset = math.floor(self.grid_width * 0.2)  -- 20% max offset
            self.wall_offset_x = math.random(-max_offset, max_offset)
            self.wall_offset_y = math.random(-max_offset, max_offset)
        end
    end

    -- Shrinking arena
    if self.shrinking_arena then
        self.arena_shrink_timer = self.arena_shrink_timer + dt
        if self.arena_shrink_timer >= self.arena_shrink_interval then
            self.arena_shrink_timer = self.arena_shrink_timer - self.arena_shrink_interval

            -- Shrink from all sides
            if self.arena_current_width > self.arena_min_width then
                self.arena_current_width = self.arena_current_width - 1
            end
            if self.arena_current_height > self.arena_min_height then
                self.arena_current_height = self.arena_current_height - 1
            end

            -- Kill snake if it's outside shrunk arena
            local head = self.snake[1]
            local margin_x = math.floor((self.grid_width - self.arena_current_width) / 2)
            local margin_y = math.floor((self.grid_height - self.arena_current_height) / 2)

            if head.x < margin_x or head.x >= (self.grid_width - margin_x) or
               head.y < margin_y or head.y >= (self.grid_height - margin_y) then
                self:playSound("death", 1.0)
                self:onComplete()
                return
            end
        end
    end

    self.move_timer = self.move_timer + dt
    -- Apply max speed cap
    local capped_speed = self.speed
    if self.max_speed_cap > 0 and self.speed > self.max_speed_cap then
        capped_speed = self.max_speed_cap
    end
    local move_interval = 1 / capped_speed

    if self.move_timer >= move_interval then
        self.move_timer = self.move_timer - move_interval

        self.direction = self.next_direction

        local head = self.snake[1]

        -- Calculate new head position based on wall_mode
        local new_head = nil
        if self.wall_mode == "wrap" then
            -- Pac-Man style wrapping (default)
            new_head = {
                x = (head.x + self.direction.x + self.grid_width) % self.grid_width,
                y = (head.y + self.direction.y + self.grid_height) % self.grid_height
            }
        elseif self.wall_mode == "death" then
            -- Hit wall = game over (respects arena shape)
            new_head = {
                x = head.x + self.direction.x,
                y = head.y + self.direction.y
            }
            -- Check if hit wall (arena shape aware)
            if not self:isInsideArena(new_head) then
                self:playSound("death", 1.0)
                self:onComplete()
                return
            end
        elseif self.wall_mode == "bounce" then
            -- Bounce off walls (random perpendicular direction)
            new_head = {
                x = head.x + self.direction.x,
                y = head.y + self.direction.y
            }
            -- Check if hit arena boundary
            if not self:isInsideArena(new_head) then
                -- Check which axis hit the wall
                local hit_x_wall = false
                local hit_y_wall = false

                -- Try moving in X direction only
                local try_x = {x = head.x + self.direction.x, y = head.y}
                if not self:isInsideArena(try_x) then
                    hit_x_wall = true
                end

                -- Try moving in Y direction only
                local try_y = {x = head.x, y = head.y + self.direction.y}
                if not self:isInsideArena(try_y) then
                    hit_y_wall = true
                end

                -- Bounce perpendicular to wall with random direction
                if hit_x_wall then
                    -- Hit vertical wall - bounce to random vertical direction
                    self.direction.x = 0
                    self.direction.y = (math.random() < 0.5) and 1 or -1
                elseif hit_y_wall then
                    -- Hit horizontal wall - bounce to random horizontal direction
                    self.direction.y = 0
                    self.direction.x = (math.random() < 0.5) and 1 or -1
                end

                -- Move in the new bounced direction
                new_head.x = head.x + self.direction.x
                new_head.y = head.y + self.direction.y

                -- If still out of bounds (corner case), clamp to arena
                if not self:isInsideArena(new_head) then
                    new_head.x = math.max(0, math.min(self.grid_width - 1, new_head.x))
                    new_head.y = math.max(0, math.min(self.grid_height - 1, new_head.y))
                end
            end
            self.next_direction = self.direction  -- Update next direction
        elseif self.wall_mode == "phase" then
            -- Pass through walls (wrapping but could add visual effect)
            new_head = {
                x = (head.x + self.direction.x + self.grid_width) % self.grid_width,
                y = (head.y + self.direction.y + self.grid_height) % self.grid_height
            }
        else
            -- Default to wrap
            new_head = {
                x = (head.x + self.direction.x + self.grid_width) % self.grid_width,
                y = (head.y + self.direction.y + self.grid_height) % self.grid_height
            }
        end

        -- Check collision (with phase_through_tail support)
        if self:checkCollision(new_head, true) then
            self:playSound("death", 1.0)
            self:onComplete()
            return
        end

        table.insert(self.snake, 1, new_head)

        -- Check food collision (multiple foods support, girth-aware)
        for i = #self.foods, 1, -1 do
            local food = self.foods[i]
            -- Check if any cell of the snake's girth touches the food
            if self:checkGirthCollision(new_head, self.current_girth, self.direction, food, food.size or 1, nil) then
                -- Handle different food types
                if food.type == "bad" then
                    -- Bad food: shrink snake by removing tail segments
                    local shrink_amount = math.min(3, #self.snake - 1)  -- Remove up to 3, but keep at least head
                    for s = 1, shrink_amount do
                        if #self.snake > 1 then
                            table.remove(self.snake)
                        end
                    end
                    self:playSound("death", 0.5)  -- Negative sound

                elseif food.type == "golden" then
                    -- Golden food: bonus effects (bigger growth, speed boost)
                    local growth = food.size * self.growth_per_food
                    self.pending_growth = self.pending_growth + growth

                    -- Extra speed boost
                    if self.speed_increase_per_food > 0 then
                        self.speed = self.speed + (self.speed_increase_per_food * 2)
                    end
                    self:playSound("success", 0.6)  -- Special sound

                else
                    -- Normal food: standard behavior
                    -- Add pending growth segments based on food size and growth_per_food
                    local growth = food.size * self.growth_per_food
                    self.pending_growth = self.pending_growth + growth

                    -- Increase speed (if speed_increase_per_food is set)
                    if self.speed_increase_per_food > 0 then
                        self.speed = self.speed + self.speed_increase_per_food
                    end

                    self:playSound("eat", 0.8)
                end

                -- Track girth growth (for all food types)
                if self.girth_growth > 0 and food.type ~= "bad" then
                    self.segments_for_next_girth = self.segments_for_next_girth - 1
                    if self.segments_for_next_girth <= 0 then
                        self.current_girth = self.current_girth + 1
                        self.segments_for_next_girth = self.girth_growth
                        print("[SnakeGame] Girth increased to " .. self.current_girth)
                    end
                end

                -- Remove eaten food and spawn new one
                table.remove(self.foods, i)
                table.insert(self.foods, self:spawnFood())

                break
            end
        end

        -- Handle tail growth/removal
        if self.pending_growth > 0 then
            -- Don't remove tail - we're growing
            self.pending_growth = self.pending_growth - 1
        elseif #self.snake < self.max_length_cap then
            -- Remove tail if we're not at max length and not growing
            table.remove(self.snake)
        else
            -- At max length cap - maintain current length
            table.remove(self.snake)
        end

        -- Update snake length metric to match actual snake
        self.metrics.snake_length = #self.snake
    end
end

function SnakeGame:checkComplete()
    -- Check victory conditions based on victory_condition type
    if self.victory_condition == "length" then
        -- Win by reaching target length
        if self.metrics.snake_length >= self.victory_limit then
            return true
        end
    elseif self.victory_condition == "time" then
        -- Win by surviving time limit
        if self.time_elapsed >= self.victory_limit then
            return true
        end
    end

    -- Lose condition: game marked completed (collision/death)
    if self.completed then
        return true
    end

    return false
end

-- Phase 3.3: Override onComplete to play success sound
function SnakeGame:onComplete()
    -- Determine if win based on victory condition
    local is_win = false
    if self.victory_condition == "length" then
        is_win = self.metrics.snake_length >= self.victory_limit
    elseif self.victory_condition == "time" then
        is_win = self.time_elapsed >= self.victory_limit
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
    local handled = false
    local new_dir = nil

    if (key == 'left' or key == 'a') and self.direction.x == 0 then
        new_dir = {x = -1, y = 0}
        handled = true
    elseif (key == 'right' or key == 'd') and self.direction.x == 0 then
        new_dir = {x = 1, y = 0}
        handled = true
    elseif (key == 'up' or key == 'w') and self.direction.y == 0 then
        new_dir = {x = 0, y = -1}
        handled = true
    elseif (key == 'down' or key == 's') and self.direction.y == 0 then
        new_dir = {x = 0, y = 1}
        handled = true
    end

    if new_dir then
        -- Apply to all player snakes (multi-snake control)
        self.next_direction = new_dir
        for i = 2, #self.player_snakes do
            local psnake = self.player_snakes[i]
            if psnake.alive then
                psnake.next_direction = {x = new_dir.x, y = new_dir.y}
            end
        end
    end

    return handled
end

function SnakeGame:spawnFood()
    local food_pos
    local pattern = self.food_spawn_pattern or "random"

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
        -- Spawn in spiral pattern
        self.spiral_angle = (self.spiral_angle or 0) + 0.5
        local radius = 5 + math.sin(self.spiral_angle) * 3
        local center_x = self.grid_width / 2
        local center_y = self.grid_height / 2
        repeat
            food_pos = {
                x = math.floor(center_x + math.cos(self.spiral_angle) * radius),
                y = math.floor(center_y + math.sin(self.spiral_angle) * radius)
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
    if math.random() < self.golden_food_spawn_rate then
        food_pos.type = "golden"
        food_pos.size = 3  -- Golden food gives more segments
    -- Check for bad food
    elseif math.random() < self.bad_food_chance then
        food_pos.type = "bad"
    -- Apply size variance to normal food
    elseif self.food_size_variance > 0 then
        -- Size variance: 0 = all size 1, 1.0 = sizes 1-5
        local max_size = 1 + math.floor(self.food_size_variance * 4)
        food_pos.size = math.random(1, max_size)
    end

    food_pos.lifetime = 0  -- Track lifetime

    return food_pos
end

function SnakeGame:createAISnake(index)
    -- Spawn AI snake at random position away from player
    local spawn_x, spawn_y
    repeat
        spawn_x = math.random(0, self.grid_width - 1)
        spawn_y = math.random(0, self.grid_height - 1)
        -- Ensure spawn is far enough from player
        local player_head = self.snake[1]
        local dist = math.abs(spawn_x - player_head.x) + math.abs(spawn_y - player_head.y)
    until dist > 10 and not self:checkCollision({x = spawn_x, y = spawn_y}, true)

    return {
        body = {{x = spawn_x, y = spawn_y}},
        direction = {x = 1, y = 0},
        move_timer = 0,
        length = 1,
        alive = true,
        behavior = self.ai_behavior,
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

    local move_interval = 1 / self.ai_speed
    if ai_snake.move_timer >= move_interval then
        ai_snake.move_timer = ai_snake.move_timer - move_interval

        -- AI decision making based on behavior
        local head = ai_snake.body[1]
        local player_head = self.snake[1]

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
        if self.wall_mode == "wrap" then
            new_head.x = new_head.x % self.grid_width
            new_head.y = new_head.y % self.grid_height
        elseif self.wall_mode == "death" then
            if new_head.x < 0 or new_head.x >= self.grid_width or new_head.y < 0 or new_head.y >= self.grid_height then
                ai_snake.alive = false
                return
            end
        elseif self.wall_mode == "bounce" then
            if new_head.x < 0 or new_head.x >= self.grid_width then
                ai_snake.direction.x = -ai_snake.direction.x
                new_head.x = head.x + ai_snake.direction.x
            end
            if new_head.y < 0 or new_head.y >= self.grid_height then
                ai_snake.direction.y = -ai_snake.direction.y
                new_head.y = head.y + ai_snake.direction.y
            end
        elseif self.wall_mode == "phase" then
            if new_head.x < 0 then new_head.x = self.grid_width - 1 end
            if new_head.x >= self.grid_width then new_head.x = 0 end
            if new_head.y < 0 then new_head.y = self.grid_height - 1 end
            if new_head.y >= self.grid_height then new_head.y = 0 end
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
                table.insert(self.foods, self:spawnFood())
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
    local player_head = self.snake[1]

    for i, ai_snake in ipairs(self.ai_snakes) do
        if ai_snake.alive then
            local ai_head = ai_snake.body[1]

            -- Check head-to-head collision
            if player_head.x == ai_head.x and player_head.y == ai_head.y then
                if self.snake_collision_mode == "both_die" then
                    self.died = true
                    ai_snake.alive = false
                    self:playSound("death", 1.0)
                    self:onComplete()
                elseif self.snake_collision_mode == "big_eats_small" then
                    if #self.snake > #ai_snake.body then
                        -- Player wins, absorb AI snake
                        for _ = 1, #ai_snake.body do
                            self.metrics.snake_length = self.metrics.snake_length + 1
                        end
                        ai_snake.alive = false
                        self:playSound("success", 0.8)
                    else
                        -- AI wins, player dies
                        self.died = true
                        self:playSound("death", 1.0)
                        self:onComplete()
                    end
                end
                -- phase_through: do nothing
            end

            -- Check if player head hits AI body
            for _, segment in ipairs(ai_snake.body) do
                if player_head.x == segment.x and player_head.y == segment.y then
                    if self.snake_collision_mode ~= "phase_through" then
                        self.died = true
                        self:playSound("death", 1.0)
                        self:onComplete()
                    end
                    break
                end
            end
        end
    end
end

function SnakeGame:createObstacles()
    local obstacles = {}
    -- Use variant obstacle_count_variant
    local obstacle_count = math.floor(self.obstacle_count_variant * self.difficulty_modifiers.complexity)
    local obstacle_type = self.obstacle_type or "walls"

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

            for _, segment in ipairs(self.snake) do if obs_pos.x == segment.x and obs_pos.y == segment.y then collision = true; break end end
            if not collision then for _, existing_obs in ipairs(obstacles) do if obs_pos.x == existing_obs.x and obs_pos.y == existing_obs.y then collision = true; break end end end
        until not collision
        table.insert(obstacles, obs_pos)
    end
    return obstacles
end

function SnakeGame:isInsideArena(pos)
    -- Check if position is inside the arena based on arena_shape
    if self.arena_shape == "circle" then
        local center_x = self.grid_width / 2
        local center_y = self.grid_height / 2
        local radius = math.min(self.grid_width, self.grid_height) / 2
        local dx = pos.x - center_x
        local dy = pos.y - center_y
        return (dx * dx + dy * dy) <= (radius * radius)
    elseif self.arena_shape == "hexagon" then
        -- Hexagon: check if within hexagonal boundary
        local center_x = self.grid_width / 2
        local center_y = self.grid_height / 2
        local size = math.min(self.grid_width, self.grid_height) / 2

        local dx = math.abs(pos.x - center_x)
        local dy = math.abs(pos.y - center_y)

        -- Hexagon approximation using distance checks
        if dx > size * 0.866 then return false end  -- 0.866 ≈ sqrt(3)/2
        if dy > size then return false end
        if dx * 0.577 + dy > size then return false end  -- 0.577 ≈ 1/sqrt(3)

        return true
    else
        -- Rectangle (default)
        return pos.x >= 0 and pos.x < self.grid_width and
               pos.y >= 0 and pos.y < self.grid_height
    end
end

function SnakeGame:getGirthCells(center_pos, girth_value, direction)
    -- Returns all grid cells occupied by a segment with given girth
    -- Girth creates width perpendicular to movement direction
    -- Girth 1 = 1 cell, Girth 2 = 2 cells side-by-side, Girth 3 = 3 cells, etc.
    local cells = {}
    local girth = girth_value or self.current_girth or 1

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

function SnakeGame:checkCollision(pos, check_snake_body)
    if not pos then return false end

    -- Get all cells occupied by this position with current girth
    local pos_cells = self:getGirthCells(pos, self.current_girth, self.direction)

    -- Always check obstacle collision
    for _, obstacle in ipairs(self.obstacles or {}) do
        for _, cell in ipairs(pos_cells) do
            if cell.x == obstacle.x and cell.y == obstacle.y then
                return true
            end
        end
    end

    -- Check snake body collision (unless phase_through_tail is enabled)
    if check_snake_body and not self.phase_through_tail then
        -- Skip checking segments near the head to prevent false collision on turns
        -- Need to skip at least (girth) segments to avoid overlap at turn corners
        local girth = self.current_girth or self.girth or 1
        local skip_segments = math.max(2, girth)
        local start_index = skip_segments + 1

        for i = start_index, #self.snake do
            -- Get direction for this segment
            local seg_dir = self.direction
            if i < #self.snake then
                local next_seg = self.snake[i + 1]
                seg_dir = {
                    x = self.snake[i].x - next_seg.x,
                    y = self.snake[i].y - next_seg.y
                }
            end

            -- Check if any cell of the new position collides with this snake segment
            if self:checkGirthCollision(pos, self.current_girth, self.direction, self.snake[i], self.current_girth, seg_dir) then
                return true
            end
        end
    end

    return false
end

return SnakeGame