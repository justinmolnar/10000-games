local Object = require('class')
local Config = rawget(_G, 'DI_CONFIG') or {}
local HiddenObjectView = Object:extend('HiddenObjectView')

function HiddenObjectView:init(game_state, variant)
    self.game = game_state
    self.variant = variant -- Store variant data for future use (Phase 1.3)
    self.BACKGROUND_GRID_BASE = game_state.BACKGROUND_GRID_BASE or 10
    self.BACKGROUND_HASH_1 = game_state.BACKGROUND_HASH_1 or 17
    self.BACKGROUND_HASH_2 = game_state.BACKGROUND_HASH_2 or 3
    self.di = game_state and game_state.di
    local cfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.hidden_object and self.di.config.games.hidden_object.view) or
                 (Config and Config.games and Config.games.hidden_object and Config.games.hidden_object.view) or {})
    self.bg_color = cfg.bg_color or {0.12, 0.1, 0.08}

    -- NOTE: In Phase 2, scene background will be loaded from variant.sprite_set
    -- e.g., "forest", "mansion", "beach", "space_station", "library"
    self.hud = cfg.hud or { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 60, text_x = 80, row_y = {10, 30, 50, 70} }
    self.sprite_loader = nil
    self.sprite_manager = nil
end

function HiddenObjectView:ensureLoaded()
    if not self.sprite_loader then
        self.sprite_loader = (self.di and self.di.spriteLoader) or error("HiddenObjectView: spriteLoader not available in DI")
    end

    if not self.sprite_manager then
        self.sprite_manager = (self.di and self.di.spriteManager) or error("HiddenObjectView: spriteManager not available in DI")
    end
end

function HiddenObjectView:draw()
    self:ensureLoaded()

    local game = self.game

    self:drawBackground()

    -- Phase 1.6 & 2.3: Use variant palette if available
    local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
    local object_sprite_fallback = game.data.icon_sprite or "magnifying_glass-0"
    local paletteManager = self.di and self.di.paletteManager

    -- Phase 2.3: Draw objects (sprite or fallback to icon)
    for _, obj in ipairs(game.objects) do
        if not obj.found then
            local angle = (obj.id * 13) % 360

            love.graphics.push()
            love.graphics.translate(obj.x, obj.y)
            love.graphics.rotate(math.rad(angle))

            -- Try to use loaded sprite for this object
            local sprite_key = "object_" .. obj.sprite_variant
            if game.sprites and game.sprites[sprite_key] then
                -- Use loaded object sprite with palette swapping
                local sprite = game.sprites[sprite_key]
                if paletteManager and palette_id then
                    paletteManager:drawSpriteWithPalette(
                        sprite,
                        -obj.size/2,
                        -obj.size/2,
                        obj.size,
                        obj.size,
                        palette_id,
                        {1, 1, 1}
                    )
                else
                    -- No palette, just draw normally
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.draw(sprite, -obj.size/2, -obj.size/2, 0,
                        obj.size / sprite:getWidth(), obj.size / sprite:getHeight())
                end
            else
                -- Fallback to icon system
                self.sprite_loader:drawSprite(
                    object_sprite_fallback,
                    -obj.size/2,
                    -obj.size/2,
                    obj.size,
                    obj.size,
                    {1, 1, 1},
                    palette_id
                )
            end

            love.graphics.pop()
        end
    end

    -- Standard HUD (Phase 8)
    game.hud:draw(game.game_width, game.game_height)

    -- Additional game-specific stats (below standard HUD)
    if not game.vm_render_mode then
        love.graphics.setColor(1, 1, 1)

        -- Time bonus (if completed)
        if game.completed and game.metrics.time_bonus > 0 then
            love.graphics.setColor(0.5, 1, 0.5)
            love.graphics.print("Time Bonus: " .. game.metrics.time_bonus, 10, 90, 0, 0.85, 0.85)
        end
    end
end

function HiddenObjectView:drawBackground()
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

        return -- Don't draw procedural background if we have a sprite
    end

    -- Fallback: Draw procedural background
    love.graphics.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3])
    love.graphics.rectangle('fill', 0, 0, game.game_width, game.game_height)

    local complexity = game.difficulty_modifiers.complexity
    local grid_density = math.floor(self.BACKGROUND_GRID_BASE * complexity)
    local cell_w = game.game_width / grid_density
    local cell_h = game.game_height / grid_density

    local complexity_mod = math.max(1, self.BACKGROUND_HASH_2 + complexity)

    for i = 0, grid_density do
        for j = 0, grid_density do
            if ((i + j) * self.BACKGROUND_HASH_1) % complexity_mod == 0 then
                love.graphics.setColor(0.25, 0.22, 0.18)
                love.graphics.rectangle('fill', i * cell_w, j * cell_h, cell_w, cell_h)
            end
        end
    end
end

return HiddenObjectView