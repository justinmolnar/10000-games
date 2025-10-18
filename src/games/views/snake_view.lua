-- src/games/views/snake_view.lua
local Object = require('class')
local SnakeView = Object:extend('SnakeView')

function SnakeView:init(game_state)
    self.game = game_state
    -- Store constants needed for drawing if they aren't on game state
    self.GRID_SIZE = game_state.GRID_SIZE or 20 
end

function SnakeView:draw()
    local game = self.game
    local GRID_SIZE = self.GRID_SIZE -- Use local copy

    -- Draw snake
    love.graphics.setColor(0, 1, 0)
    for i, segment in ipairs(game.snake) do
        love.graphics.rectangle('fill', 
            segment.x * GRID_SIZE, segment.y * GRID_SIZE, 
            GRID_SIZE - 1, GRID_SIZE - 1) 
    end
    
    -- Draw food
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle('fill',
        game.food.x * GRID_SIZE, game.food.y * GRID_SIZE,
        GRID_SIZE - 1, GRID_SIZE - 1)
    
    -- Draw obstacles
    love.graphics.setColor(0.5, 0.5, 0.5)
    for _, obstacle in ipairs(game.obstacles) do
        love.graphics.rectangle('fill',
            obstacle.x * GRID_SIZE, obstacle.y * GRID_SIZE,
            GRID_SIZE - 1, GRID_SIZE - 1)
    end
    
    -- Draw HUD
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Length: " .. game.metrics.snake_length .. "/" .. game.target_length, 10, 10)
    love.graphics.print("Time: " .. string.format("%.1f", game.metrics.survival_time), 10, 30)
    love.graphics.print("Difficulty: " .. game.difficulty_level, 10, 50)
end

return SnakeView