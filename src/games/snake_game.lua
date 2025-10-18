local BaseGame = require('src.games.base_game')
local SnakeGame = BaseGame:extend('SnakeGame')

local GRID_SIZE = 20
local BASE_SPEED = 8  -- Grid cells per second

function SnakeGame:init(game_data)
    SnakeGame.super.init(self, game_data)
    
    -- Calculate grid dimensions
    self.grid_width = math.floor(love.graphics.getWidth() / GRID_SIZE)
    self.grid_height = math.floor(love.graphics.getHeight() / GRID_SIZE)
    
    -- Initialize snake
    self.snake = {
        {x = math.floor(self.grid_width/2), y = math.floor(self.grid_height/2)}
    }
    self.direction = {x = 1, y = 0}
    self.next_direction = {x = 1, y = 0}
    
    -- Game state
    self.move_timer = 0
    self.speed = BASE_SPEED * self.difficulty_modifiers.speed
    self.food = self:spawnFood()
    self.obstacles = self:createObstacles()
    
    -- Metrics
    self.metrics.snake_length = 1
    self.metrics.survival_time = 0
end

function SnakeGame:update(dt)
    if self.completed then return end
    SnakeGame.super.update(self, dt)
    
    -- Update metrics
    self.metrics.survival_time = self.time_elapsed
    
    -- Move snake
    self.move_timer = self.move_timer + dt
    if self.move_timer >= 1/self.speed then
        self.move_timer = 0
        
        -- Update direction
        self.direction = self.next_direction
        
        -- Calculate new head position
        local head = self.snake[1]
        local new_head = {
            x = (head.x + self.direction.x) % self.grid_width,
            y = (head.y + self.direction.y) % self.grid_height
        }
        
        -- Check collisions
        if self:checkCollision(new_head) then
            self:onComplete()
            return
        end
        
        -- Move snake
        table.insert(self.snake, 1, new_head)
        
        -- Check if food eaten
        if new_head.x == self.food.x and new_head.y == self.food.y then
            self.metrics.snake_length = self.metrics.snake_length + 1
            self.food = self:spawnFood()
        else
            table.remove(self.snake)
        end
    end
end

function SnakeGame:draw()
    -- Draw grid (optional)
    love.graphics.setColor(0.2, 0.2, 0.2)
    for x = 0, self.grid_width do
        love.graphics.line(x * GRID_SIZE, 0, x * GRID_SIZE, self.grid_height * GRID_SIZE)
    end
    for y = 0, self.grid_height do
        love.graphics.line(0, y * GRID_SIZE, self.grid_width * GRID_SIZE, y * GRID_SIZE)
    end
    
    -- Draw snake
    love.graphics.setColor(0, 1, 0)
    for _, segment in ipairs(self.snake) do
        love.graphics.rectangle('fill', 
            segment.x * GRID_SIZE, 
            segment.y * GRID_SIZE, 
            GRID_SIZE - 1, 
            GRID_SIZE - 1)
    end
    
    -- Draw food
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle('fill',
        self.food.x * GRID_SIZE,
        self.food.y * GRID_SIZE,
        GRID_SIZE - 1,
        GRID_SIZE - 1)
    
    -- Draw obstacles
    love.graphics.setColor(0.5, 0.5, 0.5)
    for _, obstacle in ipairs(self.obstacles) do
        love.graphics.rectangle('fill',
            obstacle.x * GRID_SIZE,
            obstacle.y * GRID_SIZE,
            GRID_SIZE - 1,
            GRID_SIZE - 1)
    end
    
    -- Draw HUD
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Length: " .. self.metrics.snake_length, 10, 10)
    love.graphics.print("Time: " .. string.format("%.1f", self.metrics.survival_time), 10, 30)
end

function SnakeGame:keypressed(key)
    -- Handle direction changes
    if key == 'left' and self.direction.x == 0 then
        self.next_direction = {x = -1, y = 0}
    elseif key == 'right' and self.direction.x == 0 then
        self.next_direction = {x = 1, y = 0}
    elseif key == 'up' and self.direction.y == 0 then
        self.next_direction = {x = 0, y = -1}
    elseif key == 'down' and self.direction.y == 0 then
        self.next_direction = {x = 0, y = 1}
    end
end

function SnakeGame:spawnFood()
    local food
    repeat
        food = {
            x = math.random(0, self.grid_width - 1),
            y = math.random(0, self.grid_height - 1)
        }
    until not self:checkCollision(food)
    return food
end

function SnakeGame:createObstacles()
    local obstacles = {}
    
    -- Add more obstacles based on difficulty
    local obstacle_count = math.floor(5 * self.difficulty_modifiers.complexity)
    
    for i = 1, obstacle_count do
        local obstacle
        repeat
            obstacle = {
                x = math.random(0, self.grid_width - 1),
                y = math.random(0, self.grid_height - 1)
            }
        until not self:checkCollision(obstacle)
        table.insert(obstacles, obstacle)
    end
    
    return obstacles
end

function SnakeGame:checkCollision(pos)
    -- Check snake collision
    for _, segment in ipairs(self.snake) do
        if pos.x == segment.x and pos.y == segment.y then
            return true
        end
    end
    
    -- Check obstacle collision
    for _, obstacle in ipairs(self.obstacles) do
        if pos.x == obstacle.x and pos.y == obstacle.y then
            return true
        end
    end
    
    return false
end

function SnakeGame:checkComplete()
    -- Game is complete when snake collides or reaches target length
    return self.completed or self.metrics.snake_length >= 20 * self.difficulty_modifiers.complexity
end

return SnakeGame