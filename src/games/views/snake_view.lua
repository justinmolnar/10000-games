local Object = require('class')
local Config = rawget(_G, 'DI_CONFIG') or {}
local SnakeView = Object:extend('SnakeView')

function SnakeView:init(game_state)
    self.game = game_state
    self.GRID_SIZE = game_state.GRID_SIZE or 20
    self.di = game_state and game_state.di
    local cfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.snake and self.di.config.games.snake.view) or
                 (Config and Config.games and Config.games.snake and Config.games.snake.view) or {})
    self.bg_color = cfg.bg_color or {0.05, 0.1, 0.05}
    self.hud = cfg.hud or { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 60, text_x = 80, row_y = {10, 30, 50} }
    self.sprite_loader = nil
    self.sprite_manager = nil
end

function SnakeView:ensureLoaded()
    if not self.sprite_loader then
        self.sprite_loader = (self.di and self.di.spriteLoader) or error("SnakeView: spriteLoader not available in DI")
    end

    if not self.sprite_manager then
        self.sprite_manager = (self.di and self.di.spriteManager) or error("SnakeView: spriteManager not available in DI")
    end
end

function SnakeView:draw()
    self:ensureLoaded()
    
    local game = self.game
    local GRID_SIZE = self.GRID_SIZE

    love.graphics.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3])
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
    
    local hud_icon_size = self.hud.icon_size or 16
    local s = self.hud.text_scale or 0.85
    local lx, ix, tx = self.hud.label_x or 10, self.hud.icon_x or 60, self.hud.text_x or 80
    local ry = self.hud.row_y or {10, 30, 50}
    love.graphics.setColor(1, 1, 1)

    local length_sprite = self.sprite_manager:getMetricSprite(game.data, "snake_length") or snake_sprite
    love.graphics.print("Length: ", lx, ry[1], 0, s, s)
    self.sprite_loader:drawSprite(length_sprite, ix, ry[1], hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    love.graphics.print(game.metrics.snake_length .. "/" .. game.target_length, tx, ry[1], 0, s, s)
    
    local time_sprite = self.sprite_manager:getMetricSprite(game.data, "survival_time") or "clock-0"
    love.graphics.print("Time: ", lx, ry[2], 0, s, s)
    self.sprite_loader:drawSprite(time_sprite, ix, ry[2], hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    love.graphics.print(string.format("%.1f", game.metrics.survival_time), tx, ry[2], 0, s, s)

    love.graphics.print("Difficulty: " .. game.difficulty_level, lx, ry[3])
end

return SnakeView