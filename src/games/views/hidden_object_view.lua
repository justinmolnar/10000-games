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

    -- Configure extra stats for HUD
    game_state.hud:setExtraStats({
        {label = "Time Bonus", key = "metrics.time_bonus",
            show_fn = function(g) return g.completed and g.metrics.time_bonus > 0 end,
            color = {0.5, 1, 0.5}},
    })
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
            local sprite_key = "object_" .. obj.sprite_variant

            self:drawEntityCentered(obj.x, obj.y, obj.size, obj.size, sprite_key, object_sprite_fallback, {
                rotation = math.rad(angle),
                use_palette = true,
                palette_id = palette_id
            })
        end
    end)

    game.hud:draw(game.game_width, game.game_height)
    game.hud:drawExtraStats(game.game_width, game.game_height)
end

return HiddenObjectView