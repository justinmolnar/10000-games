local Object = require('class')
local DodgeView = Object:extend('DodgeView')

function DodgeView:init(game_state)
    self.game = game_state
    self.OBJECT_DRAW_SIZE = game_state.OBJECT_SIZE or 15
end

function DodgeView:draw()
    local game = self.game
    local g = love.graphics

    local game_width = game.game_width
    local game_height = game.game_height

    g.setColor(0.1, 0.1, 0.1)
    g.rectangle('fill', 0, 0, game_width, game_height)

    g.setColor(0, 1, 0)
    g.circle('fill', game.player.x, game.player.y, game.player.radius)

    g.setColor(1, 1, 0, 0.3)
    local warning_draw_thickness = self.OBJECT_DRAW_SIZE * 1.5
    for _, warning in ipairs(game.warnings) do
        if warning.type == 'horizontal' then
            g.rectangle('fill', 0, warning.pos - warning_draw_thickness/2, game_width, warning_draw_thickness)
        else
            g.rectangle('fill', warning.pos - warning_draw_thickness/2, 0, warning_draw_thickness, game_height)
        end
    end

    g.setColor(1, 0, 0)
    for _, obj in ipairs(game.objects) do
        g.circle('fill', obj.x, obj.y, obj.radius)
    end

    g.setColor(1, 1, 1)
    g.print("Dodged: " .. game.metrics.objects_dodged .. "/" .. game.dodge_target, 10, 10)
    g.print("Collisions: " .. game.metrics.collisions .. "/" .. game.MAX_COLLISIONS, 10, 30)
    g.print("Perfect: " .. game.metrics.perfect_dodges, 10, 50)
    g.print("Difficulty: " .. game.difficulty_level, 10, 70)
end

return DodgeView