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

function SnakeGame:init(game_data, cheats, di)
    SnakeGame.super.init(self, game_data, cheats)
    self.di = di
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.snake) or SCfg
    self.GRID_SIZE = (runtimeCfg and runtimeCfg.grid_size) or GRID_SIZE
    
    local speed_modifier = self.cheats.speed_modifier or 1.0
    
    self.game_width = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.width) or (SCfg.arena and SCfg.arena.width) or 800
    self.game_height = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.height) or (SCfg.arena and SCfg.arena.height) or 600
    
    self.grid_width = math.floor(self.game_width / GRID_SIZE)
    self.grid_height = math.floor(self.game_height / GRID_SIZE)
    
    self.snake = { {x = math.floor(self.grid_width/2), y = math.floor(self.grid_height/2)} }
    self.direction = {x = 1, y = 0} 
    self.next_direction = {x = 1, y = 0}
    
    self.move_timer = 0
    self.speed = (BASE_SPEED * self.difficulty_modifiers.speed) * speed_modifier
    self.target_length = math.floor(BASE_TARGET_LENGTH * self.difficulty_modifiers.complexity)
    
    self.obstacles = self:createObstacles()
    self.food = self:spawnFood()
    
    self.metrics.snake_length = 1
    self.metrics.survival_time = 0
    
    self.died = false -- Track death state
    
    self.view = SnakeView:new(self)
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

    self.move_timer = self.move_timer + dt
    local move_interval = 1 / self.speed
    if self.move_timer >= move_interval then
        self.move_timer = self.move_timer - move_interval 
        
        self.direction = self.next_direction 
        
        local head = self.snake[1]
        local new_head = {
            x = (head.x + self.direction.x + self.grid_width) % self.grid_width,
            y = (head.y + self.direction.y + self.grid_height) % self.grid_height
        }
        
        -- Check collision and trigger game over
        if self:checkCollision(new_head, true) then 
            self:onComplete() -- Mark game as completed
            return
        end
        
        table.insert(self.snake, 1, new_head)
        
        if new_head.x == self.food.x and new_head.y == self.food.y then
            self.metrics.snake_length = self.metrics.snake_length + 1
            self.food = self:spawnFood()
        else
            table.remove(self.snake)
        end
    end
end

function SnakeGame:checkComplete()
    -- Win condition: reached target length
    if self.metrics.snake_length >= self.target_length then
        return true
    end
    -- Lose condition: game marked completed (collision)
    if self.completed then
        return true
    end
    return false
end

function SnakeGame:draw()
   if self.view then
       self.view:draw()
   end
end

function SnakeGame:keypressed(key)
    local handled = false
    if (key == 'left' or key == 'a') and self.direction.x == 0 then
        self.next_direction = {x = -1, y = 0}
        handled = true
    elseif (key == 'right' or key == 'd') and self.direction.x == 0 then
        self.next_direction = {x = 1, y = 0}
        handled = true
    elseif (key == 'up' or key == 'w') and self.direction.y == 0 then
        self.next_direction = {x = 0, y = -1}
        handled = true
    elseif (key == 'down' or key == 's') and self.direction.y == 0 then
        self.next_direction = {x = 0, y = 1}
        handled = true
    end
    return handled
end

function SnakeGame:spawnFood()
    local food_pos
    repeat
        food_pos = {
            x = math.random(0, self.grid_width - 1),
            y = math.random(0, self.grid_height - 1)
        }
    until not self:checkCollision(food_pos, true) 
    return food_pos
end

function SnakeGame:createObstacles()
    local obstacles = {}
    local obstacle_count = math.floor(BASE_OBSTACLE_COUNT * self.difficulty_modifiers.complexity)
    
    for i = 1, obstacle_count do
        local obs_pos, collision
        repeat
            collision = false
            obs_pos = { x = math.random(0, self.grid_width - 1), y = math.random(0, self.grid_height - 1) }
            for _, segment in ipairs(self.snake) do if obs_pos.x == segment.x and obs_pos.y == segment.y then collision = true; break end end
            if not collision then for _, existing_obs in ipairs(obstacles) do if obs_pos.x == existing_obs.x and obs_pos.y == existing_obs.y then collision = true; break end end end
        until not collision
        table.insert(obstacles, obs_pos)
    end
    return obstacles
end

function SnakeGame:checkCollision(pos, check_snake_body)
    if not pos then return false end
    for _, obstacle in ipairs(self.obstacles or {}) do if pos.x == obstacle.x and pos.y == obstacle.y then return true end end
    if check_snake_body then
        local start_index = (pos == self.snake[1]) and 2 or 1
        for i = start_index, #self.snake do if pos.x == self.snake[i].x and pos.y == self.snake[i].y then return true end end
    end
    return false
end

function SnakeGame:checkComplete()
    -- Win condition: reached target length
    if self.metrics.snake_length >= self.target_length then
        return true
    end
    
    -- Lose condition: snake hit itself or obstacle
    local head = self.snake[1]
    if head and self:checkCollision(head, false) then
        return true
    end
    
    return false
end

return SnakeGame