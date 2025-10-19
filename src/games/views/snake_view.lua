local Object = require('class')
local SnakeView = Object:extend('SnakeView')

function SnakeView:init(game_state)
    self.game = game_state
    self.GRID_SIZE = game_state.GRID_SIZE or 20
    self.sprite_loader = nil
    self.sprite_manager = nil
end

function SnakeView:ensureLoaded()
    if not self.sprite_loader then
        local SpriteLoader = require('src.utils.sprite_loader')
        self.sprite_loader = SpriteLoader.getInstance()
    end
    
    if not self.sprite_manager then
        local SpriteManager = require('src.utils.sprite_manager')
        self.sprite_manager = SpriteManager.getInstance()
    end
end

function SnakeView:draw()
    self:ensureLoaded()
    
    local game = self.game
    local GRID_SIZE = self.GRID_SIZE

    love.graphics.setColor(0.05, 0.1, 0.05)
    love.graphics.rectangle('fill', 0, 0, game.game_width, game.game_height)

    local palette_id = self.sprite_manager:getPaletteId(game.data)
    local snake_sprite = game.data.icon_sprite or "game_spider-0"
    
    for i, segment in ipairs(game.snake) do
        self.sprite_loader:drawSprite(
            snake_sprite,
            segment.x * GRID_SIZE,
            segment.y * GRID_SIZE,
            GRID_SIZE - 1,
            GRID_SIZE - 1,
            {1, 1, 1},
            palette_id
        )
    end
    
    local food_sprite = "check-0"
    self.sprite_loader:drawSprite(
        food_sprite,
        game.food.x * GRID_SIZE,
        game.food.y * GRID_SIZE,
        GRID_SIZE - 1,
        GRID_SIZE - 1,
        {1, 1, 1},
        palette_id
    )
    
    local obstacle_sprite = "msg_error-0"
    for _, obstacle in ipairs(game.obstacles) do
        self.sprite_loader:drawSprite(
            obstacle_sprite,
            obstacle.x * GRID_SIZE,
            obstacle.y * GRID_SIZE,
            GRID_SIZE - 1,
            GRID_SIZE - 1,
            {1, 1, 1},
            palette_id
        )
    end
    
    local hud_icon_size = 16
    love.graphics.setColor(1, 1, 1)
    
    local length_sprite = self.sprite_manager:getMetricSprite(game.data, "snake_length") or snake_sprite
    love.graphics.print("Length: ", 10, 10, 0, 0.85, 0.85)
    self.sprite_loader:drawSprite(length_sprite, 60, 10, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    love.graphics.print(game.metrics.snake_length .. "/" .. game.target_length, 80, 10, 0, 0.85, 0.85)
    
    local time_sprite = self.sprite_manager:getMetricSprite(game.data, "survival_time") or "clock-0"
    love.graphics.print("Time: ", 10, 30, 0, 0.85, 0.85)
    self.sprite_loader:drawSprite(time_sprite, 60, 30, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    love.graphics.print(string.format("%.1f", game.metrics.survival_time), 80, 30, 0, 0.85, 0.85)
    
    love.graphics.print("Difficulty: " .. game.difficulty_level, 10, 50)
end

return SnakeView