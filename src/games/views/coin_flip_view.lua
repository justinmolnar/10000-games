local GameBaseView = require('src.games.views.game_base_view')
local CoinFlipView = GameBaseView:extend('CoinFlipView')

function CoinFlipView:init(game)
    CoinFlipView.super.init(self, game, nil)

    -- Configure extra stats
    game.hud:setExtraStats({
        {label = "Target Streak", key = "params.streak_target"},
        {label = "Max Streak", key = "max_streak"},
        {label = "Total Flips", key = "flips_total"},
        {label = "Correct", key = "correct_total"},
        {label = "Wrong", key = "incorrect_total"},
        {label = "Accuracy", value_fn = function(g) return math.floor(g.metrics.accuracy * 100) .. "%" end,
            show_fn = function(g) return g.flips_total > 0 end},
    })
end

function CoinFlipView:drawContent()
    -- Use viewport dimensions if available (for demo playback), otherwise full screen
    local w = self.game.viewport_width or love.graphics.getWidth()
    local h = self.game.viewport_height or love.graphics.getHeight()

    -- Background
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle('fill', 0, 0, w, h)

    self.game.visual_effects:drawScreenFlash(w, h)
    self.game.popup_manager:draw()
    self.game.visual_effects:drawParticles()
    self.game.hud:draw(w, h)
    local extra_height = self.game.hud:drawExtraStats(w, h)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("COIN FLIP CHALLENGE", 20, 50, 0, 2, 2)

    -- Pattern history display (complex - uses table.concat)
    if self.game.params.show_pattern_history and #self.game.pattern_history > 0 then
        local history_str = table.concat(self.game.pattern_history, " ")
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("History: " .. history_str, 20, 270)
    end

    -- Auto-flip countdown
    if self.game.params.auto_flip_interval > 0 and self.game.waiting_for_guess and not self.game.game_over and not self.game.victory then
        love.graphics.setColor(1, 1, 0.3)
        local countdown = math.ceil(self.game.auto_flip_timer)
        love.graphics.print("Auto-flip in: " .. countdown .. "s", w - 150, 10)
    end

    -- Time per flip countdown
    if self.game.time_per_flip > 0 and self.game.waiting_for_guess and not self.game.game_over and not self.game.victory then
        local time_left = math.ceil(self.game.time_per_flip_timer)
        local color = time_left <= 3 and {1, 0, 0} or {1, 1, 1}  -- Red if low
        love.graphics.setColor(color)
        love.graphics.print("Time Left: " .. time_left .. "s", w - 150, 30, 0, 1.2, 1.2)
    end

    -- Coin display area (center)
    local coin_x = w / 2
    local coin_y = h / 2
    local coin_radius = 80

    -- Flip animation
    love.graphics.push()
    love.graphics.translate(coin_x, coin_y)

    if self.game.flip_animation:isActive() then
        -- Rotate around Y-axis (create 3D flip illusion by scaling X)
        local rotation_progress = self.game.flip_animation:getRotation() % (math.pi * 2)
        local scale_x = math.abs(math.cos(rotation_progress))
        love.graphics.scale(scale_x, 1)
    end

    -- Draw coin
    love.graphics.setColor(0.8, 0.7, 0.2)  -- Gold color
    love.graphics.circle('fill', 0, 0, coin_radius)
    love.graphics.setColor(0.6, 0.5, 0.1)
    love.graphics.circle('line', 0, 0, coin_radius)

    -- Show last result on coin
    love.graphics.setColor(0.2, 0.2, 0.2)
    if self.game.last_result then
        local result_text = self.game.last_result:upper()
        love.graphics.printf(result_text, -60, -10, 120, 'center')
    else
        love.graphics.printf("?", -60, -10, 120, 'center')
    end

    love.graphics.pop()

    -- Show result message
    if self.game.show_result then
        if self.game.params.flip_mode == "auto" then
            -- Auto mode: HEADS = success, TAILS = miss
            if self.game.last_result == 'heads' then
                love.graphics.setColor(0, 1, 0)
                love.graphics.printf("HEADS!", coin_x - 100, coin_y + 100, 200, 'center', 0, 2, 2)
            else
                love.graphics.setColor(1, 0, 0)
                love.graphics.printf("TAILS!", coin_x - 100, coin_y + 100, 200, 'center', 0, 2, 2)
            end
        else
            -- Guess mode: show CORRECT/WRONG
            local is_correct = self.game.last_guess == self.game.last_result
            if is_correct then
                love.graphics.setColor(0, 1, 0)
                love.graphics.printf("CORRECT!", coin_x - 100, coin_y + 100, 200, 'center', 0, 2, 2)
            else
                love.graphics.setColor(1, 0, 0)
                love.graphics.printf("WRONG!", coin_x - 100, coin_y + 100, 200, 'center', 0, 2, 2)
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

function CoinFlipView:getVictorySubtitle()
    return "Streak of " .. self.game.params.streak_target .. " reached!"
end

function CoinFlipView:getGameOverSubtitle()
    return "Max Streak: " .. self.game.max_streak
end

return CoinFlipView
