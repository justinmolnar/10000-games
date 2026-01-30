local GameBaseView = require('src.games.views.game_base_view')
local HiddenObjectView = GameBaseView:extend('HiddenObjectView')

function HiddenObjectView:init(game_state, variant)
    HiddenObjectView.super.init(self, game_state, variant)

    -- Game-specific view config
    local cfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.hidden_object and self.di.config.games.hidden_object.view) or {})
    self.bg_color = cfg.bg_color or {0.12, 0.1, 0.08}
end

function HiddenObjectView:drawContent()

    local game = self.game

    -- Procedural background
    if game.sprites and game.sprites.background then
        self:drawBackgroundSprite(game.game_width, game.game_height)
    else
        self:drawBackgroundProcedural(game.game_width, game.game_height)
    end

    local object_sprite_fallback = game.data.icon_sprite or "magnifying_glass-0"

    game.entity_controller:draw(function(obj)
        if not obj.found then
            local angle = (obj.id * 13) % 360
            local sprite_key = "object_" .. obj.sprite_variant

            self:drawEntityCentered(obj.x, obj.y, obj.size, obj.size, sprite_key, object_sprite_fallback, {
                rotation = math.rad(angle)
            })
        end
    end)

    game.hud:draw(game.game_width, game.game_height)

    -- Extra stats
    if game.completed and game.metrics.time_bonus > 0 then
        game.hud:drawStat("Time Bonus", game.metrics.time_bonus, 90, {0.5, 1, 0.5})
    end
end

return HiddenObjectView
