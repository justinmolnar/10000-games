local Object = require('class')
local Strings = require('src.utils.strings')

local MinigameView = Object:extend('MinigameView')

function MinigameView:init(di)
    self.di = di
end

function MinigameView:drawOverlay(viewport, snapshot)
    if not viewport then return end
    local vpW, vpH = viewport.width, viewport.height

    love.graphics.push()

    -- Full-screen dim
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle('fill', 0, 0, vpW, vpH)

    if snapshot.won then
        self:drawVictoryScreen(vpW, vpH, snapshot)
    else
        self:drawGameOverScreen(vpW, vpH, snapshot)
    end

    -- Bottom instructions (shared)
    self:drawInstructions(vpW, vpH, snapshot)

    love.graphics.pop()
end

function MinigameView:drawVictoryScreen(vpW, vpH, snapshot)
    local cx = vpW / 2
    local scale = math.min(vpW / 600, vpH / 500)
    local lh = math.max(14, 18 * scale)
    local y = math.max(10, vpH * 0.05)

    -- Title
    love.graphics.setColor(0.2, 1, 0.3)
    local title = "VICTORY!"
    local font = love.graphics.getFont()
    local ts = math.min(2.5 * scale, 3.0)
    local tw = font:getWidth(title) * ts
    love.graphics.print(title, cx - tw / 2, y, 0, ts, ts)
    y = y + lh * 3

    -- Tokens earned
    local tokens = math.floor(snapshot.current_performance or 0)
    love.graphics.setColor(1, 1, 0)
    local tok_text = "+" .. tokens .. " Tokens"
    local tok_s = math.min(1.8 * scale, 2.2)
    local tok_w = font:getWidth(tok_text) * tok_s
    love.graphics.print(tok_text, cx - tok_w / 2, y, 0, tok_s, tok_s)
    y = y + lh * 2.5

    -- New record or previous best
    if (snapshot.current_performance or 0) > (snapshot.previous_best or 0) then
        love.graphics.setColor(1, 0.85, 0)
        local nr = "NEW RECORD!"
        local nr_s = math.min(1.5 * scale, 2.0)
        local nr_w = font:getWidth(nr) * nr_s
        love.graphics.print(nr, cx - nr_w / 2, y, 0, nr_s, nr_s)
        y = y + lh * 1.5

        love.graphics.setColor(0.7, 0.7, 0.7)
        local prev = "Previous best: " .. math.floor(snapshot.previous_best or 0)
        local ps = scale * 0.9
        love.graphics.print(prev, cx - font:getWidth(prev) * ps / 2, y, 0, ps, ps)
        y = y + lh * 1.8

        -- Auto-completion
        if snapshot.auto_completed_games and #snapshot.auto_completed_games > 0 then
            love.graphics.setColor(0.5, 0.8, 1)
            local ac = "Auto-completed " .. #snapshot.auto_completed_games .. " easier variants! (+" .. math.floor(snapshot.auto_complete_power or 0) .. " power)"
            local ac_s = scale * 0.85
            love.graphics.print(ac, cx - font:getWidth(ac) * ac_s / 2, y, 0, ac_s, ac_s)
            y = y + lh * 1.5
        end
    else
        love.graphics.setColor(0.8, 0.8, 0.8)
        local best = "Best: " .. math.floor(snapshot.previous_best or 0)
        local bs = scale
        love.graphics.print(best, cx - font:getWidth(best) * bs / 2, y, 0, bs, bs)
        y = y + lh * 1.8
    end

    -- Divider
    love.graphics.setColor(0.4, 0.4, 0.4)
    local div_w = math.min(vpW * 0.6, 350)
    love.graphics.rectangle('fill', cx - div_w / 2, y, div_w, 1)
    y = y + lh * 0.8

    -- Performance breakdown (compact)
    y = self:drawPerformanceSection(vpW, y, scale, lh, snapshot)
end

function MinigameView:drawGameOverScreen(vpW, vpH, snapshot)
    local cx = vpW / 2
    local scale = math.min(vpW / 600, vpH / 500)
    local lh = math.max(14, 18 * scale)
    local y = math.max(10, vpH * 0.05)
    local font = love.graphics.getFont()

    -- Title
    love.graphics.setColor(1, 0.2, 0.2)
    local title = "GAME OVER"
    local ts = math.min(2.5 * scale, 3.0)
    local tw = font:getWidth(title) * ts
    love.graphics.print(title, cx - tw / 2, y, 0, ts, ts)
    y = y + lh * 3

    -- Fail message
    love.graphics.setColor(1, 0.5, 0.4)
    local fail_msg = "Below 75% goal -- no tokens awarded"
    local fs = math.min(1.1 * scale, 1.4)
    local fw = font:getWidth(fail_msg) * fs
    love.graphics.print(fail_msg, cx - fw / 2, y, 0, fs, fs)
    y = y + lh * 2

    -- Show what they got vs what was needed
    local game_data = snapshot.game_data
    if game_data then
        love.graphics.setColor(0.7, 0.7, 0.7)
        local goal_text = game_data.display_name or "Unknown"
        local gs = scale * 0.9
        love.graphics.print(goal_text, cx - font:getWidth(goal_text) * gs / 2, y, 0, gs, gs)
        y = y + lh * 1.5
    end

    -- Previous best reminder
    if (snapshot.previous_best or 0) > 0 then
        love.graphics.setColor(0.6, 0.6, 0.3)
        local best = "Your best: " .. math.floor(snapshot.previous_best)
        local bs = scale * 0.9
        love.graphics.print(best, cx - font:getWidth(best) * bs / 2, y, 0, bs, bs)
        y = y + lh * 1.5
    end

    -- Divider
    love.graphics.setColor(0.4, 0.4, 0.4)
    local div_w = math.min(vpW * 0.6, 350)
    love.graphics.rectangle('fill', cx - div_w / 2, y, div_w, 1)
    y = y + lh * 0.8

    -- Performance breakdown
    y = self:drawPerformanceSection(vpW, y, scale, lh, snapshot)
end

function MinigameView:drawPerformanceSection(vpW, y, scale, lh, snapshot)
    local font = love.graphics.getFont()
    local x = math.max(20, vpW * 0.08)
    local max_w = vpW - x * 2
    local ts = math.min(scale * 0.85, 1.1)

    -- Metrics
    local game_data = snapshot.game_data
    local metrics = snapshot.metrics or {}
    if game_data and game_data.metrics_tracked then
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Performance:", x, y, 0, ts, ts)
        y = y + lh

        local MetricLegend = require('src.views.metric_legend')
        local metric_legend = MetricLegend:new(self.di)
        love.graphics.push()
        y = metric_legend:draw(game_data, metrics, x + 10, y, max_w - 10, true)
        love.graphics.pop()
        y = y + lh * 0.3
    end

    -- Formula
    if game_data and game_data.base_formula_string then
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Formula:", x, y, 0, ts, ts)
        y = y + lh

        local FormulaRenderer = require('src.views.formula_renderer')
        local formula_renderer = FormulaRenderer:new(self.di)
        love.graphics.push()
        local fy = formula_renderer:draw(game_data, x + 10, y, max_w * 0.8, 18, snapshot.game_instance)
        love.graphics.pop()
        y = fy + lh * 0.3
    end

    -- Cheat bonus
    if (snapshot.performance_mult or 1.0) ~= 1.0 then
        love.graphics.setColor(0, 1, 1)
        love.graphics.print("Cheat Bonus: x" .. string.format("%.1f", snapshot.performance_mult), x + 10, y, 0, ts, ts)
        y = y + lh
    end

    -- Final result
    love.graphics.setColor(1, 1, 1)
    local result = "Result: " .. math.floor(snapshot.current_performance or 0)
    local rs = math.min(scale * 1.1, 1.4)
    love.graphics.print(result, x, y, 0, rs, rs)
    y = y + lh * 1.5

    return y
end

function MinigameView:drawInstructions(vpW, vpH, snapshot)
    local font = love.graphics.getFont()
    local scale = math.min(vpW / 600, vpH / 500)
    local lh = math.max(14, 18 * scale)
    local ts = math.min(scale * 0.9, 1.1)
    local y = vpH - lh * 4.5

    -- Demo save prompt
    if snapshot.show_save_demo_prompt and snapshot.recorded_demo then
        y = y - lh * 2.5
        love.graphics.setColor(0.5, 1, 1)
        local demo_text = "Demo recorded! Save it for VM use?"
        local dw = font:getWidth(demo_text) * ts
        love.graphics.print(demo_text, vpW / 2 - dw / 2, y, 0, ts, ts)
        y = y + lh * 1.2

        local btn_s = ts
        love.graphics.setColor(0, 1, 0)
        local save_text = "[S] Save Demo"
        local sw = font:getWidth(save_text) * btn_s
        love.graphics.print(save_text, vpW / 2 - sw - 10, y, 0, btn_s, btn_s)

        love.graphics.setColor(1, 0.5, 0.5)
        local disc_text = "[D] Discard"
        love.graphics.print(disc_text, vpW / 2 + 10, y, 0, btn_s, btn_s)
        y = y + lh * 1.5
    end

    -- Action prompts
    love.graphics.setColor(0.8, 0.8, 0.8)
    local enter_text = "ENTER - Play Again"
    local esc_text = "ESC - Close"
    local ew = font:getWidth(enter_text) * ts
    local xw = font:getWidth(esc_text) * ts
    local gap = 30
    local total = ew + gap + xw
    local start_x = vpW / 2 - total / 2

    love.graphics.print(enter_text, start_x, vpH - lh * 2.5, 0, ts, ts)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print(esc_text, start_x + ew + gap, vpH - lh * 2.5, 0, ts, ts)

    love.graphics.setColor(0.4, 0.6, 0.4)
    local f_text = "[F] Save balance stats"
    local fw = font:getWidth(f_text) * ts
    love.graphics.print(f_text, vpW / 2 - fw / 2, vpH - lh * 1.2, 0, ts * 0.85, ts * 0.85)
end

return MinigameView
