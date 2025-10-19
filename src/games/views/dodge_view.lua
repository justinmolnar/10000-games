local Object = require('class')
local DodgeView = Object:extend('DodgeView')

function DodgeView:init(game_state)
    self.game = game_state
    self.OBJECT_DRAW_SIZE = game_state.OBJECT_SIZE or 15
    self.sprite_loader = nil
    self.sprite_manager = nil
end

function DodgeView:ensureLoaded()
    if not self.sprite_loader then
        local SpriteLoader = require('src.utils.sprite_loader')
        self.sprite_loader = SpriteLoader.getInstance()
    end
    
    if not self.sprite_manager then
        local SpriteManager = require('src.utils.sprite_manager')
        self.sprite_manager = SpriteManager.getInstance()
    end
end

function DodgeView:draw()
    self:ensureLoaded()
    
    local game = self.game
    local g = love.graphics

    local game_width = game.game_width
    local game_height = game.game_height

    g.setColor(0.08, 0.05, 0.1)
    g.rectangle('fill', 0, 0, game_width, game_height)

    local palette_id = self.sprite_manager:getPaletteId(game.data)
    local player_sprite = game.data.icon_sprite or "game_solitaire-0"
    
    self.sprite_loader:drawSprite(
        player_sprite,
        game.player.x - game.player.radius,
        game.player.y - game.player.radius,
        game.player.radius * 2,
        game.player.radius * 2,
        {1, 1, 1},
        palette_id
    )

    g.setColor(0.9, 0.9, 0.3, 0.4)
    local warning_draw_thickness = self.OBJECT_DRAW_SIZE * 1.5
    for _, warning in ipairs(game.warnings) do
        if warning.type == 'horizontal' then
            g.rectangle('fill', 0, warning.pos - warning_draw_thickness/2, game_width, warning_draw_thickness)
        else
            g.rectangle('fill', warning.pos - warning_draw_thickness/2, 0, warning_draw_thickness, game_height)
        end
    end

    local object_sprite = "msg_error-0"
    for _, obj in ipairs(game.objects) do
        self.sprite_loader:drawSprite(
            object_sprite,
            obj.x - obj.radius,
            obj.y - obj.radius,
            obj.radius * 2,
            obj.radius * 2,
            {1, 1, 1},
            palette_id
        )
    end

    local hud_icon_size = 16
    g.setColor(1, 1, 1)
    
    local dodged_sprite = self.sprite_manager:getMetricSprite(game.data, "objects_dodged") or player_sprite
    g.print("Dodged: ", 10, 10, 0, 0.85, 0.85)
    self.sprite_loader:drawSprite(dodged_sprite, 70, 10, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.objects_dodged .. "/" .. game.dodge_target, 90, 10, 0, 0.85, 0.85)
    
    local collision_sprite = self.sprite_manager:getMetricSprite(game.data, "collisions") or "msg_error-0"
    g.print("Hits: ", 10, 30, 0, 0.85, 0.85)
    self.sprite_loader:drawSprite(collision_sprite, 70, 30, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.collisions .. "/" .. game.MAX_COLLISIONS, 90, 30, 0, 0.85, 0.85)
    
    local perfect_sprite = self.sprite_manager:getMetricSprite(game.data, "perfect_dodges") or "check-0"
    g.print("Perfect: ", 10, 50, 0, 0.85, 0.85)
    self.sprite_loader:drawSprite(perfect_sprite, 70, 50, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.perfect_dodges, 90, 50, 0, 0.85, 0.85)
    
    g.print("Difficulty: " .. game.difficulty_level, 10, 70)
end

return DodgeView