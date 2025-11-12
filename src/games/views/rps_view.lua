local Class = require('lib.class')
local RPSView = Class:extend('RPSView')

function RPSView:init(game)
    self.game = game
end

function RPSView:draw()
    -- Use viewport dimensions if available (for demo playback), otherwise full screen
    local w = self.game.viewport_width or love.graphics.getWidth()
    local h = self.game.viewport_height or love.graphics.getHeight()

    -- Background
    love.graphics.setColor(0.15, 0.1, 0.15)
    love.graphics.rectangle('fill', 0, 0, w, h)

    -- Visual effects: screen flash + particles (Phase 3 - VisualEffects component)
    self.game.visual_effects:drawScreenFlash(w, h)

    -- Phase 6: Draw score popups via PopupManager
    self.game.popup_manager:draw()

    -- Draw particles (Phase 3 - VisualEffects component)
    self.game.visual_effects:drawParticles()

    -- Standard HUD (Phase 8)
    self.game.hud:draw(w, h)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("RPS TOURNAMENT", 20, 50, 0, 2, 2)

    -- Additional game info
    love.graphics.print("First to " .. self.game.rounds_to_win .. " wins", 20, 90)
    love.graphics.setColor(0.5, 1, 0.5)
    love.graphics.print("Player: " .. self.game.player_wins, 20, 110)

    -- Phase 6 completion: Multiple opponents display
    if self.game.num_opponents > 1 then
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.print("Opponents:", 20, 130)
        local active_count = 0
        for i, opp in ipairs(self.game.opponents) do
            if not opp.eliminated then
                active_count = active_count + 1
                love.graphics.setColor(0.8, 0.5, 0.5)
                love.graphics.print("  #" .. i .. ": " .. opp.wins .. " wins", 20, 130 + (active_count * 18), 0, 0.8, 0.8)
            end
        end
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Ties: " .. self.game.ties, 20, 150 + (active_count * 18))
    else
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.print("AI: " .. self.game.ai_wins, 20, 130)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Ties: " .. self.game.ties, 20, 150)
    end

    -- Stats
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Rounds: " .. self.game.rounds_played, 20, 180)
    love.graphics.print("Max Streak: " .. self.game.max_win_streak, 20, 200)

    -- Phase 6 completion: Lives display
    local y_offset = 260
    if self.game.lives < 999 then
        love.graphics.print("Lives: " .. self.game.lives, 20, y_offset)
        y_offset = y_offset + 20
    end

    -- Phase 6 completion: Time limit display
    if self.game.victory_condition == "time" then
        local time_left = math.max(0, self.game.time_limit - self.game.time_elapsed)
        love.graphics.setColor(time_left < 10 and {1, 0, 0} or {1, 1, 1})
        love.graphics.print("Time: " .. math.floor(time_left) .. "s", 20, y_offset)
        y_offset = y_offset + 20
        love.graphics.setColor(1, 1, 1)
    end

    -- Phase 6 completion: Statistics display
    if self.game.show_statistics then
        local total = self.game.player_wins + self.game.ai_wins + self.game.ties
        if total > 0 then
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print("Win%: " .. math.floor((self.game.player_wins / total) * 100) .. "%", 20, y_offset)
            y_offset = y_offset + 20
        end
    end

    -- Phase 6 completion: Special round indicator
    -- Show current_special_round during waiting, last_special_round during result display
    local special_to_show = nil
    if self.game.waiting_for_input and self.game.current_special_round then
        special_to_show = self.game.current_special_round
    elseif self.game.show_result and self.game.last_special_round then
        special_to_show = self.game.last_special_round
    end

    if special_to_show then
        love.graphics.setColor(1, 1, 0)
        local special_text = special_to_show:upper():gsub("_", " ")
        love.graphics.print("SPECIAL ROUND: " .. special_text, 20, y_offset, 0, 1.2, 1.2)
        y_offset = y_offset + 20

        -- Explain what the special round does
        love.graphics.setColor(1, 1, 0.5)
        local explanation = ""
        if special_to_show == "double_or_nothing" then
            explanation = "Win = 2x points | Lose = -1x points"
        elseif special_to_show == "sudden_death" then
            explanation = "Win = Victory! | Lose = Game Over!"
        elseif special_to_show == "reverse" then
            explanation = "Win/Lose conditions REVERSED!"
        elseif special_to_show == "mirror" then
            explanation = "Both must throw SAME to win!"
        end
        love.graphics.print(explanation, 20, y_offset, 0, 0.9, 0.9)
        y_offset = y_offset + 25
        love.graphics.setColor(1, 1, 1)
    end

    -- Phase 6 completion: AI pattern hint
    if self.game.show_ai_pattern_hint then
        love.graphics.setColor(1, 0.7, 0.3)
        love.graphics.print("AI Pattern: " .. self.game.ai_pattern, 20, y_offset)
        y_offset = y_offset + 20
        love.graphics.setColor(1, 1, 1)
    end

    -- Phase 6 completion: History display
    if self.game.show_history_display and #self.game.throw_history > 0 then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("History:", w - 200, 20)
        for i, throw in ipairs(self.game.throw_history) do
            local y = 40 + (i * 18)
            local result_color = {0.7, 0.7, 0.7}
            if throw.result == "win" then
                result_color = {0.5, 1, 0.5}
            elseif throw.result == "lose" then
                result_color = {1, 0.5, 0.5}
            end
            love.graphics.setColor(result_color)
            love.graphics.print(throw.player:sub(1,1):upper() .. " vs " .. throw.ai:sub(1,1):upper(), w - 200, y, 0, 0.8, 0.8)
        end
        love.graphics.setColor(1, 1, 1)
    end

    -- Phase 6 completion: Double hands mode UI
    if self.game.hands_mode == "double" then
        local center_x = w / 2
        if self.game.phase == "selection" then
            love.graphics.setColor(1, 1, 0)
            local text = "SELECT TWO HANDS"
            if self.game.player_left_hand then
                text = "Left: " .. self.game.player_left_hand:upper() .. " | Select Right"
            end
            love.graphics.print(text, center_x - 150, h - 100, 0, 1.3, 1.3)
        elseif self.game.phase == "removal" then
            love.graphics.setColor(1, 0.5, 0)
            love.graphics.print("REMOVE ONE HAND: [1] or [2]", center_x - 180, h - 100, 0, 1.3, 1.3)
            love.graphics.setColor(0.8, 0.8, 1)
            love.graphics.print("[1] Keep: " .. (self.game.player_left_hand or ""):upper(), center_x - 150, h - 70)
            love.graphics.print("[2] Keep: " .. (self.game.player_right_hand or ""):upper(), center_x + 20, h - 70)

            -- Phase 6 completion: Show opponent's hands if enabled
            if self.game.show_opponent_hands and self.game.ai_left_hand and self.game.ai_right_hand then
                love.graphics.setColor(1, 0.7, 0.7)
                love.graphics.print("AI Hands: " .. self.game.ai_left_hand:upper() .. " | " .. self.game.ai_right_hand:upper(), center_x - 100, h - 45, 0, 0.9, 0.9)
            end

            if self.game.time_per_removal > 0 then
                local time_left = math.ceil(self.game.removal_timer)
                love.graphics.setColor(time_left <= 3 and {1, 0, 0} or {1, 1, 1})
                love.graphics.print("Time: " .. time_left .. "s", center_x - 40, h - 20)
            end
        end
        love.graphics.setColor(1, 1, 1)
    end

    -- Display area (center)
    local center_x = w / 2
    local center_y = h / 2

    -- Throw animation bounce effect (Phase 4 - AnimationSystem component)
    local bounce_offset = 0
    if self.game.throw_animation:isActive() then
        bounce_offset = -self.game.throw_animation:getOffset()  -- Negative for upward bounce
    end

    -- Show throws
    if self.game.show_result then
        -- Phase 6 completion: Multiple opponents mode - show differently
        if self.game.num_opponents > 1 then
            -- Show player throw in center
            love.graphics.push()
            love.graphics.translate(0, bounce_offset)
            love.graphics.setColor(0.5, 0.5, 1)
            love.graphics.circle('fill', center_x, center_y, 60)
            love.graphics.setColor(0, 0, 0)
            local player_text = self.game.player_choice and self.game.player_choice:upper() or "?"
            love.graphics.printf(player_text, center_x - 50, center_y - 10, 100, 'center')
            love.graphics.pop()

            -- Show opponents in circle around player
            local angle_step = (2 * math.pi) / #self.game.opponents
            for i, opp in ipairs(self.game.opponents) do
                if not opp.eliminated and opp.choice then
                    local angle = (i - 1) * angle_step
                    local opp_x = center_x + math.cos(angle) * 150
                    local opp_y = center_y + math.sin(angle) * 150

                    love.graphics.push()
                    love.graphics.translate(0, bounce_offset)
                    love.graphics.setColor(1, 0.5, 0.5)
                    love.graphics.circle('fill', opp_x, opp_y, 40)
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.printf(opp.choice:sub(1,1):upper(), opp_x - 20, opp_y - 8, 40, 'center', 0, 0.8, 0.8)
                    love.graphics.pop()
                end
            end
        else
            -- Single opponent mode - original display
            -- Player throw (left)
            love.graphics.push()
            love.graphics.translate(0, bounce_offset)
            love.graphics.setColor(0.5, 0.5, 1)
            love.graphics.circle('fill', center_x - 150, center_y, 60)
            love.graphics.setColor(0, 0, 0)
            local player_text = self.game.player_choice and self.game.player_choice:upper() or "?"
            love.graphics.printf(player_text, center_x - 200, center_y - 10, 100, 'center')
            love.graphics.pop()

            -- VS text
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("VS", center_x - 20, center_y - 10, 40, 'center')

            -- AI throw (right)
            love.graphics.push()
            love.graphics.translate(0, bounce_offset)
            love.graphics.setColor(1, 0.5, 0.5)
            love.graphics.circle('fill', center_x + 150, center_y, 60)
            love.graphics.setColor(0, 0, 0)
            local ai_text = self.game.ai_choice and self.game.ai_choice:upper() or "?"
            love.graphics.printf(ai_text, center_x + 100, center_y - 10, 100, 'center')
            love.graphics.pop()
        end

        -- Result - centered properly
        local result_y = center_y + 120
        if self.game.round_result == "win" then
            love.graphics.setColor(0, 1, 0)
            love.graphics.printf("YOU WIN!", center_x - 200, result_y, 400, 'center', 0, 2, 2)
        elseif self.game.round_result == "lose" then
            love.graphics.setColor(1, 0, 0)
            love.graphics.printf("AI WINS!", center_x - 200, result_y, 400, 'center', 0, 2, 2)
        else
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("TIE!", center_x - 200, result_y, 400, 'center', 0, 2, 2)
        end

    else
        -- Waiting for input
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.circle('fill', center_x - 150, center_y, 60)
        love.graphics.circle('fill', center_x + 150, center_y, 60)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("?", center_x - 200, center_y - 10, 100, 'center', 0, 2, 2)
        love.graphics.printf("?", center_x + 100, center_y - 10, 100, 'center', 0, 2, 2)
    end

    -- Instructions
    if self.game.waiting_for_input and not self.game.game_over and not self.game.victory then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.printf("[R] Rock  |  [P] Paper  |  [S] Scissors", 0, h - 60, w, 'center', 0, 1.5, 1.5)
    end

    -- Victory message
    if self.game.victory then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(0, 1, 0)
        love.graphics.printf("VICTORY!", 0, h / 2 - 40, w, 'center', 0, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("First to " .. self.game.rounds_to_win .. " wins!", 0, h / 2 + 20, w, 'center', 0, 1.5, 1.5)
    end

    -- Game Over message
    if self.game.game_over then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("GAME OVER", 0, h / 2 - 40, w, 'center', 0, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("AI wins " .. self.game.ai_wins .. " - " .. self.game.player_wins, 0, h / 2 + 20, w, 'center', 0, 1.5, 1.5)
    end
end

return RPSView
