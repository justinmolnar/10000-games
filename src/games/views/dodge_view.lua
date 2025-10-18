-- src/games/views/dodge_view.lua
local Object = require('class')
local DodgeView = Object:extend('DodgeView')

function DodgeView:init(game_state)
    self.game = game_state
    -- Store constants needed for drawing
    self.OBJECT_SIZE = game_state.OBJECT_SIZE or 15
end

function DodgeView:draw()
    local game = self.game
    local OBJECT_SIZE = self.OBJECT_SIZE

    -- Draw Player
    love.graphics.setColor(0, 1, 0)
    love.graphics.circle('fill', game.player.x, game.player.y, game.player.radius)

    -- Draw Warnings
    love.graphics.setColor(1, 1, 0, 0.3) 
    for _, warning in ipairs(game.warnings) do
        local w_size = OBJECT_SIZE * 2 
        if warning.type == 'horizontal' then
            love.graphics.rectangle('fill', 0, warning.pos - w_size/2, love.graphics.getWidth(), w_size)
        else 
            love.graphics.rectangle('fill', warning.pos - w_size/2, 0, w_size, love.graphics.getHeight())
        end
    end

    -- Draw Objects
    love.graphics.setColor(1, 0, 0) 
    for _, obj in ipairs(game.objects) do
        love.graphics.circle('fill', obj.x, obj.y, obj.radius)
    end

    -- Draw HUD
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Dodged: " .. game.metrics.objects_dodged .. "/" .. game.dodge_target, 10, 10)
    love.graphics.print("Collisions: " .. game.metrics.collisions .. "/" .. game.MAX_COLLISIONS, 10, 30) -- Need MAX_COLLISIONS
    love.graphics.print("Perfect: " .. game.metrics.perfect_dodges, 10, 50)
    love.graphics.print("Difficulty: " .. game.difficulty_level, 10, 70)
end

return DodgeView