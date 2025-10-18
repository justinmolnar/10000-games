-- src/games/views/dodge_view.lua
local Object = require('class')
local DodgeView = Object:extend('DodgeView')

function DodgeView:init(game_state)
    self.game = game_state
    -- Store fixed size, logic uses radius now
    self.OBJECT_DRAW_SIZE = game_state.OBJECT_SIZE or 15
end

function DodgeView:draw()
    local game = self.game
    local g = love.graphics -- Alias for brevity

    -- These dimensions are now primarily for warnings, objects use radius
    local canvas_width = game.canvas_width
    local canvas_height = game.canvas_height

    -- ** IMPORTANT: Assume g.origin() was called by MinigameState before this **
    -- ** All coordinates (game.player.x, obj.x etc.) are relative to canvas 0,0 **

    -- Draw Player (uses radius)
    g.setColor(0, 1, 0)
    g.circle('fill', game.player.x, game.player.y, game.player.radius)

    -- Draw Warnings (based on canvas dimensions)
    g.setColor(1, 1, 0, 0.3)
    local warning_draw_thickness = self.OBJECT_DRAW_SIZE * 1.5 -- Make warnings slightly thicker than objects visually
    for _, warning in ipairs(game.warnings) do
        if warning.type == 'horizontal' then
            g.rectangle('fill', 0, warning.pos - warning_draw_thickness/2, canvas_width, warning_draw_thickness)
        else -- vertical
            g.rectangle('fill', warning.pos - warning_draw_thickness/2, 0, warning_draw_thickness, canvas_height)
        end
    end

    -- Draw Objects (uses radius)
    g.setColor(1, 0, 0)
    for _, obj in ipairs(game.objects) do
        g.circle('fill', obj.x, obj.y, obj.radius)
    end

    -- Draw HUD (fixed position relative to canvas 0,0)
    g.setColor(1, 1, 1)
    g.print("Dodged: " .. game.metrics.objects_dodged .. "/" .. game.dodge_target, 10, 10)
    g.print("Collisions: " .. game.metrics.collisions .. "/" .. game.MAX_COLLISIONS, 10, 30)
    g.print("Perfect: " .. game.metrics.perfect_dodges, 10, 50)
    g.print("Difficulty: " .. game.difficulty_level, 10, 70)
end

return DodgeView