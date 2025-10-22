local Object = require('class')
local Strings = require('src.utils.strings')

local MinigameView = Object:extend('MinigameView')

function MinigameView:init(di)
    self.di = di
end

function MinigameView:drawOverlay(viewport, snapshot)
    if not viewport then return end
    local vpWidth, vpHeight = viewport.width, viewport.height

    love.graphics.push()
    love.graphics.origin()

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, vpWidth, vpHeight)

    love.graphics.setColor(1, 1, 1)
    local game_data = snapshot.game_data
    local metrics = snapshot.metrics or {}

    local x = vpWidth * 0.1
    local y = vpHeight * 0.1
    local line_height = math.max(16, vpHeight * 0.04)
    local title_scale = math.max(0.8, vpWidth / 700)
    local text_scale = math.max(0.7, vpWidth / 800)

    love.graphics.printf("GAME COMPLETE!", x, y, vpWidth * 0.8, "center", 0, title_scale, title_scale)
    y = y + line_height * 2.5

    local tokens_earned = math.floor(snapshot.current_performance or 0)
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("Tokens Earned: +" .. tokens_earned, x, y, vpWidth * 0.8, "center", 0, text_scale * 1.2, text_scale * 1.2)
    y = y + line_height * 1.5

    if snapshot.fail_gate_triggered then
        love.graphics.setColor(1, 0.4, 0.4)
        love.graphics.printf("Below 75% goal — no tokens awarded", x, y, vpWidth * 0.8, "center", 0, text_scale, text_scale)
        y = y + line_height * 1.2
        love.graphics.setColor(1, 1, 1)
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Your Performance:", x, y, 0, text_scale, text_scale)
    y = y + line_height

    if game_data and game_data.metrics_tracked then
        local MetricLegend = require('src.views.metric_legend')
        local metric_legend = MetricLegend:new(self.di)
        love.graphics.push()
        love.graphics.origin()
        y = metric_legend:draw(game_data, metrics, x + 20, y, vpWidth - x - 40, true)
        love.graphics.pop()
    else
        love.graphics.print("  (Metrics unavailable)", x + 20, y, 0, text_scale * 0.9, text_scale * 0.9)
        y = y + line_height
    end

    y = y + line_height * 0.5
    love.graphics.print("Formula Calculation:", x, y, 0, text_scale, text_scale)
    y = y + line_height

    if game_data and game_data.base_formula_string then
        local FormulaRenderer = require('src.views.formula_renderer')
        local formula_renderer = FormulaRenderer:new(self.di)
        love.graphics.push()
        love.graphics.origin()
        local formula_end_y = formula_renderer:draw(game_data, x + 20, y, vpWidth * 0.7, 20)
        love.graphics.pop()
        y = formula_end_y + line_height * 0.5
    end

    if (snapshot.performance_mult or 1.0) ~= 1.0 then
        love.graphics.print("Base Result: " .. math.floor(snapshot.base_performance or 0), x + 20, y, 0, text_scale, text_scale)
        y = y + line_height
        love.graphics.setColor(0, 1, 1)
        love.graphics.print("Cheat Bonus: x" .. string.format("%.1f", snapshot.performance_mult or 1.0), x + 20, y, 0, text_scale, text_scale)
        y = y + line_height
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Final Result: " .. math.floor(snapshot.current_performance or 0), x + 20, y, 0, text_scale * 1.2, text_scale * 1.2)
    y = y + line_height * 1.5

    if (snapshot.current_performance or 0) > (snapshot.previous_best or 0) then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("NEW RECORD!", x, y, 0, text_scale * 1.3, text_scale * 1.3)
        y = y + line_height
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Previous: " .. math.floor(snapshot.previous_best or 0), x, y, 0, text_scale, text_scale)
        love.graphics.print("Improvement: +" .. math.floor((snapshot.current_performance or 0) - (snapshot.previous_best or 0)), x, y + line_height, 0, text_scale, text_scale)
        y = y + line_height

        if (snapshot.auto_completed_games and #snapshot.auto_completed_games > 0) then
            y = y + line_height
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("AUTO-COMPLETION TRIGGERED!", x, y, 0, text_scale * 1.1, text_scale * 1.1)
            y = y + line_height
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Completed " .. #snapshot.auto_completed_games .. " easier variants!", x, y, 0, text_scale, text_scale)
            y = y + line_height
            love.graphics.print("Total power gained: +" .. math.floor(snapshot.auto_complete_power or 0), x, y, 0, text_scale, text_scale)
        end
    else
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Best: " .. math.floor(snapshot.previous_best or 0), x, y, 0, text_scale, text_scale)
        y = y + line_height
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Try again to improve your score!", x, y, 0, text_scale, text_scale)
    end

    love.graphics.setColor(1, 1, 1)
    local instruction_y = vpHeight - line_height * 2.5
    love.graphics.printf("Press ENTER to play again", 0, instruction_y, vpWidth, "center", 0, text_scale, text_scale)
    love.graphics.printf("Press ESC to close window", 0, instruction_y + line_height, vpWidth, "center", 0, text_scale, text_scale)

    love.graphics.pop()
end

return MinigameView
