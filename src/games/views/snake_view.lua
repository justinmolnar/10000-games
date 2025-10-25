local Object = require('class')
local Config = rawget(_G, 'DI_CONFIG') or {}
local SnakeView = Object:extend('SnakeView')

function SnakeView:init(game_state, variant)
    self.game = game_state
    self.variant = variant -- Store variant data for future use (Phase 1.3)
    -- NOTE: In Phase 2, snake sprites and grid will use variant.sprite_set and variant.background
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

    -- Draw background
    self:drawBackground()

    -- Phase 1.6 & 2.3: Use variant palette if available
    local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
    local snake_sprite_fallback = game.data.icon_sprite or "game_spider-0"
    local paletteManager = self.di and self.di.paletteManager

    -- Phase 2.3: Draw snake (sprite or fallback)
    for i, segment in ipairs(game.snake) do
        local sprite_key = nil

        if i == 1 then
            -- Head - determine direction
            local dir = game.direction
            if dir.y == -1 then sprite_key = "head_up"
            elseif dir.y == 1 then sprite_key = "head_down"
            elseif dir.x == -1 then sprite_key = "head_left"
            elseif dir.x == 1 then sprite_key = "head_right"
            end
        elseif i == #game.snake then
            -- Tail - determine direction from previous segment
            local prev = game.snake[i-1]
            local dx = segment.x - prev.x
            local dy = segment.y - prev.y
            if dy == -1 or dy > 1 then sprite_key = "tail_up"
            elseif dy == 1 or dy < -1 then sprite_key = "tail_down"
            elseif dx == -1 or dx > 1 then sprite_key = "tail_left"
            elseif dx == 1 or dx < -1 then sprite_key = "tail_right"
            end
        else
            -- Body - horizontal or vertical
            local prev = game.snake[i-1]
            local next_seg = game.snake[i+1]
            local dx_prev = segment.x - prev.x
            local dx_next = next_seg.x - segment.x

            -- If movement is mostly horizontal
            if math.abs(dx_prev) > math.abs(segment.y - prev.y) or math.abs(dx_next) > math.abs(next_seg.y - segment.y) then
                sprite_key = "body_horizontal"
            else
                sprite_key = "body_vertical"
            end
        end

        -- Draw sprite or fallback
        if sprite_key and game.sprites and game.sprites[sprite_key] then
            local sprite = game.sprites[sprite_key]
            if paletteManager and palette_id then
                paletteManager:drawSpriteWithPalette(
                    sprite,
                    segment.x * GRID_SIZE,
                    segment.y * GRID_SIZE,
                    GRID_SIZE - 1,
                    GRID_SIZE - 1,
                    palette_id,
                    {1, 1, 1}
                )
            else
                -- No palette, just draw normally
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(sprite, segment.x * GRID_SIZE, segment.y * GRID_SIZE, 0,
                    (GRID_SIZE - 1) / sprite:getWidth(), (GRID_SIZE - 1) / sprite:getHeight())
            end
        else
            -- Fallback to icon system
            self.sprite_loader:drawSprite(
                snake_sprite_fallback,
                segment.x * GRID_SIZE,
                segment.y * GRID_SIZE,
                GRID_SIZE - 1,
                GRID_SIZE - 1,
                {1, 1, 1},
                palette_id
            )
        end
    end

    -- Draw food (sprite or fallback)
    if game.sprites and game.sprites.food then
        local sprite = game.sprites.food
        if paletteManager and palette_id then
            paletteManager:drawSpriteWithPalette(
                sprite,
                game.food.x * GRID_SIZE,
                game.food.y * GRID_SIZE,
                GRID_SIZE - 1,
                GRID_SIZE - 1,
                palette_id,
                {1, 1, 1}
            )
        else
            -- No palette, just draw normally
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(sprite, game.food.x * GRID_SIZE, game.food.y * GRID_SIZE, 0,
                (GRID_SIZE - 1) / sprite:getWidth(), (GRID_SIZE - 1) / sprite:getHeight())
        end
    else
        -- Fallback to icon
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
    end

    -- Draw obstacles (always use fallback for now)
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

function SnakeView:drawBackground()
    local game = self.game

    -- Phase 2.3: Use loaded background sprite if available
    if game and game.sprites and game.sprites.background then
        local bg = game.sprites.background
        local bg_width = bg:getWidth()
        local bg_height = bg:getHeight()

        -- Apply palette swap
        local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
        local paletteManager = self.di and self.di.paletteManager

        -- Scale or tile background to fit game area
        local scale_x = game.game_width / bg_width
        local scale_y = game.game_height / bg_height

        if paletteManager and palette_id then
            paletteManager:drawSpriteWithPalette(
                bg,
                0,
                0,
                game.game_width,
                game.game_height,
                palette_id,
                {1, 1, 1}
            )
        else
            -- No palette, just draw normally
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(bg, 0, 0, 0, scale_x, scale_y)
        end

        return -- Don't draw solid background if we have a sprite
    end

    -- Fallback: Draw solid color background
    love.graphics.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3])
    love.graphics.rectangle('fill', 0, 0, game.game_width, game.game_height)
end

return SnakeView