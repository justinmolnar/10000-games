local GameBaseView = require('src.games.views.game_base_view')
local CoinFlipView = GameBaseView:extend('CoinFlipView')

function CoinFlipView:init(game)
    CoinFlipView.super.init(self, game, nil)
end

function CoinFlipView:drawContent()
    local w = self.game.viewport_width or love.graphics.getWidth()
    local h = self.game.viewport_height or love.graphics.getHeight()

    -- Background
    self:drawBackgroundSolid(w, h)

    self.game.visual_effects:drawScreenFlash(w, h)
    self.game.visual_effects:drawParticles()
    self.game.hud:draw(w, h)

    -- Extra stats
    local y = 90
    y = self.game.hud:drawStat("Target Streak", self.game.params.streak_target, y)
    y = self.game.hud:drawStat("Max Streak", self.game.max_streak, y)
    y = self.game.hud:drawStat("Total Flips", self.game.flips_total, y)
    y = self.game.hud:drawStat("Correct", self.game.correct_total, y)
    y = self.game.hud:drawStat("Wrong", self.game.incorrect_total, y)
    if self.game.flips_total > 0 then
        y = self.game.hud:drawStat("Accuracy", math.floor(self.game.metrics.accuracy * 100) .. "%", y)
    end

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("COIN FLIP CHALLENGE", 20, 50, 0, 2, 2)

    -- Pattern history
    if self.game.params.show_pattern_history and #self.game.pattern_history > 0 then
        local history_str = table.concat(self.game.pattern_history, " ")
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("History: " .. history_str, 20, 270)
    end

    -- Auto-flip countdown
    if self.game.params.auto_flip_interval > 0 and self.game.waiting_for_guess and not self.game.game_over and not self.game.victory then
        love.graphics.setColor(1, 1, 0.3)
        love.graphics.print("Auto-flip in: " .. math.ceil(self.game.auto_flip_timer) .. "s", w - 150, 10)
    end

    -- Time per flip countdown
    if self.game.time_per_flip > 0 and self.game.waiting_for_guess and not self.game.game_over and not self.game.victory then
        local time_left = math.ceil(self.game.time_per_flip_timer)
        love.graphics.setColor(time_left <= 3 and {1, 0, 0} or {1, 1, 1})
        love.graphics.print("Time Left: " .. time_left .. "s", w - 150, 30, 0, 1.2, 1.2)
    end

    -- Water round indicator
    if self.game.water_round then
        if not self._water_sprite then
            local ok, img = pcall(love.graphics.newImage, "assets/sprites/shared/y2k_bunker/water_jug.png")
            self._water_sprite = ok and img or false
        end
        local wx, wy = w / 2 + 120, h / 2 - 100
        if self._water_sprite then
            local sw, sh = self._water_sprite:getWidth(), self._water_sprite:getHeight()
            local scale = 32 / math.max(sw, sh)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.draw(self._water_sprite, wx, wy, 0, scale, scale)
        else
            love.graphics.setColor(0.3, 0.7, 1.0)
            love.graphics.circle('fill', wx + 16, wy + 16, 12)
        end
        love.graphics.setColor(0.3, 0.7, 1.0)
        love.graphics.print("+WATER", wx - 8, wy + 34, 0, 0.8, 0.8)
    end

    -- Coin rendering (physics-driven)
    self:drawCoin(w, h)

    -- Result message
    local coin_rest_y = h / 2 + 40
    local coin_radius = 80
    local result_y = coin_rest_y + coin_radius + 20
    if self.game.show_result then
        if self.game.params.flip_mode == "auto" then
            if self.game.last_result == 'heads' then
                love.graphics.setColor(0, 1, 0)
                love.graphics.printf("HEADS!", w / 2 - 100, result_y, 200, 'center', 0, 2, 2)
            else
                love.graphics.setColor(1, 0, 0)
                love.graphics.printf("TAILS!", w / 2 - 100, result_y, 200, 'center', 0, 2, 2)
            end
        else
            local is_correct = self.game.last_guess == self.game.last_result
            if is_correct then
                love.graphics.setColor(0, 1, 0)
                love.graphics.printf("CORRECT!", w / 2 - 100, result_y, 200, 'center', 0, 2, 2)
            else
                love.graphics.setColor(1, 0, 0)
                love.graphics.printf("WRONG!", w / 2 - 100, result_y, 200, 'center', 0, 2, 2)
            end
        end
    end

    -- Instructions
    if self.game.waiting_for_guess and not self.game.game_over and not self.game.victory then
        love.graphics.setColor(1, 1, 1, 0.8)
        if self.game.params.flip_mode == "auto" then
            love.graphics.printf("[SPACE] Flip Coin", 0, h - 60, w, 'center', 0, 1.5, 1.5)
            love.graphics.setColor(0.7, 0.7, 0.7, 0.6)
            love.graphics.printf("Heads = Advance Streak | Tails = Reset", 0, h - 30, w, 'center')
        else
            love.graphics.printf("[H] Heads  |  [T] Tails", 0, h - 60, w, 'center', 0, 1.5, 1.5)
        end
    end
end

function CoinFlipView:drawCoin(w, h)
    local coin_x = w / 2
    local coin_rest_y = h / 2 + 40
    local coin_radius = 80
    local edge_thickness = 10

    local c = self.game.coin
    local spin = c.spin
    local coin_y = coin_rest_y + c.y

    -- Tumble axis: coin spins around horizontal axis (top-over-bottom)
    -- sin(spin) gives vertical foreshortening: ±1 = face-on, 0 = edge-on
    local face_amount = math.sin(spin)
    local face_scale = math.abs(face_amount)
    local showing_heads = (face_amount >= 0)

    -- Shadow on the "table" surface — shrinks as coin rises
    local height_ratio = math.max(0, 1 + c.y / 300) -- 1 at rest, 0 when 300px up
    local shadow_alpha = 0.25 * height_ratio
    love.graphics.setColor(0, 0, 0, shadow_alpha)
    love.graphics.ellipse('fill', coin_x, coin_rest_y + coin_radius * 0.6,
        coin_radius * 0.9 * height_ratio, coin_radius * 0.18 * height_ratio)

    love.graphics.push()
    love.graphics.translate(coin_x, coin_y)

    if face_scale < 0.12 then
        -- Edge-on: draw as a horizontal bar
        love.graphics.setColor(0.55, 0.42, 0.08)
        love.graphics.rectangle('fill', -coin_radius, -edge_thickness / 2, coin_radius * 2, edge_thickness)
        love.graphics.setColor(0.45, 0.34, 0.06)
        love.graphics.rectangle('line', -coin_radius, -edge_thickness / 2, coin_radius * 2, edge_thickness)
        -- Ridges
        love.graphics.setColor(0.65, 0.52, 0.12)
        for i = 0, 6 do
            local rx = -coin_radius + 10 + i * ((coin_radius * 2 - 20) / 6)
            love.graphics.line(rx, -edge_thickness / 2 + 1, rx, edge_thickness / 2 - 1)
        end
    else
        -- Face visible — draw as Y-squashed ellipse

        -- Edge band behind the face (depth cue)
        if face_scale < 0.85 then
            local edge_dir = showing_heads and 1 or -1
            local band_offset = edge_thickness * (1 - face_scale) * edge_dir * 0.5
            love.graphics.setColor(0.55, 0.42, 0.08)
            love.graphics.ellipse('fill', 0, band_offset, coin_radius, coin_radius * face_scale)
        end

        -- Coin face
        if showing_heads then
            love.graphics.setColor(0.85, 0.72, 0.2)
        else
            love.graphics.setColor(0.78, 0.65, 0.18)
        end
        love.graphics.ellipse('fill', 0, 0, coin_radius, coin_radius * face_scale)

        -- Inner ring
        if face_scale > 0.3 then
            love.graphics.setColor(0.7, 0.58, 0.15, 0.4 * face_scale)
            love.graphics.ellipse('line', 0, 0, coin_radius * 0.8, coin_radius * 0.8 * face_scale)
        end

        -- Border
        love.graphics.setColor(0.6, 0.5, 0.1)
        love.graphics.setLineWidth(2)
        love.graphics.ellipse('line', 0, 0, coin_radius, coin_radius * face_scale)
        love.graphics.setLineWidth(1)

        -- Text on face (only when mostly face-on)
        if face_scale > 0.4 then
            local text_alpha = math.min(1, (face_scale - 0.4) / 0.3)
            love.graphics.setColor(0.2, 0.15, 0.05, text_alpha)
            local display_text = "?"
            if self.game.last_result and c.landed then
                display_text = self.game.last_result:upper()
            elseif self.game.last_result and c.spin_speed ~= 0 then
                display_text = showing_heads and "H" or "T"
            end
            love.graphics.printf(display_text, -60, -10 * face_scale, 120, 'center')
        end
    end

    love.graphics.pop()
end

function CoinFlipView:getVictorySubtitle()
    return "Streak of " .. self.game.params.streak_target .. " reached!"
end

function CoinFlipView:getGameOverSubtitle()
    return "Max Streak: " .. self.game.max_streak
end

return CoinFlipView
