local Class = require('lib.class')
local RPSView = Class:extend('RPSView')

function RPSView:init(game)
    self.game = game
end

function RPSView:draw()
    local w, h = love.graphics.getDimensions()

    -- Background
    love.graphics.setColor(0.15, 0.1, 0.15)
    love.graphics.rectangle('fill', 0, 0, w, h)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("RPS TOURNAMENT", 20, 20, 0, 2, 2)

    -- Score
    love.graphics.print("First to " .. self.game.rounds_to_win .. " wins", 20, 60)
    love.graphics.setColor(0.5, 1, 0.5)
    love.graphics.print("Player: " .. self.game.player_wins, 20, 90)
    love.graphics.setColor(1, 0.5, 0.5)
    love.graphics.print("AI: " .. self.game.ai_wins, 20, 110)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Ties: " .. self.game.ties, 20, 130)

    -- Stats
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Rounds: " .. self.game.rounds_played, 20, 160)
    love.graphics.print("Win Streak: " .. self.game.current_win_streak, 20, 180)
    love.graphics.print("Max Streak: " .. self.game.max_win_streak, 20, 200)

    -- Display area (center)
    local center_x = w / 2
    local center_y = h / 2

    -- Show throws
    if self.game.show_result then
        -- Player throw (left)
        love.graphics.setColor(0.5, 0.5, 1)
        love.graphics.circle('fill', center_x - 150, center_y, 60)
        love.graphics.setColor(0, 0, 0)
        local player_text = self.game.player_choice:upper()
        love.graphics.printf(player_text, center_x - 200, center_y - 10, 100, 'center')

        -- VS text
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("VS", center_x - 20, center_y - 10, 40, 'center')

        -- AI throw (right)
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.circle('fill', center_x + 150, center_y, 60)
        love.graphics.setColor(0, 0, 0)
        local ai_text = self.game.ai_choice:upper()
        love.graphics.printf(ai_text, center_x + 100, center_y - 10, 100, 'center')

        -- Result
        if self.game.round_result == "win" then
            love.graphics.setColor(0, 1, 0)
            love.graphics.printf("YOU WIN!", 0, center_y + 100, w, 'center', 0, 2, 2)
        elseif self.game.round_result == "lose" then
            love.graphics.setColor(1, 0, 0)
            love.graphics.printf("AI WINS!", 0, center_y + 100, w, 'center', 0, 2, 2)
        else
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf("TIE!", 0, center_y + 100, w, 'center', 0, 2, 2)
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
