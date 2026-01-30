local GameBaseView = require('src.games.views.game_base_view')
local HiddenObjectView = GameBaseView:extend('HiddenObjectView')

function HiddenObjectView:init(game_state, variant)
    HiddenObjectView.super.init(self, game_state, variant, {
        background_procedural = true,
        procedural_alt_color = {0.25, 0.22, 0.18}
    })

    -- Game-specific view config
    local cfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.hidden_object and self.di.config.games.hidden_object.view) or {})
    self.bg_color = cfg.bg_color or {0.12, 0.1, 0.08}
end

function HiddenObjectView:drawContent()

    local game = self.game

    self:drawBackground()

    local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
    local object_sprite_fallback = game.data.icon_sprite or "magnifying_glass-0"
    local paletteManager = self.di and self.di.paletteManager

    game.entity_controller:draw(function(obj)
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
    end)

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

return HiddenObjectView