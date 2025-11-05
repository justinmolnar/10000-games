local Class = require('lib.class')
local CoinFlipView = Class:extend('CoinFlipView')

function CoinFlipView:init(game)
    self.game = game
end

function CoinFlipView:draw()
    local w, h = love.graphics.getDimensions()

    -- Background
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle('fill', 0, 0, w, h)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("COIN FLIP CHALLENGE", 20, 20, 0, 2, 2)

    -- HUD - Target and Progress
    love.graphics.print("Target Streak: " .. self.game.streak_target, 20, 60)
    love.graphics.print("Current Streak: " .. self.game.current_streak, 20, 80)
    love.graphics.print("Max Streak: " .. self.game.max_streak, 20, 100)

    -- Lives (if not unlimited)
    if self.game.lives < 999 then
        love.graphics.print("Lives: " .. self.game.lives, 20, 120)
    end

    -- Stats
    love.graphics.print("Total Flips: " .. self.game.flips_total, 20, 150)
    love.graphics.print("Correct: " .. self.game.correct_total, 20, 170)
    love.graphics.print("Wrong: " .. self.game.incorrect_total, 20, 190)

    if self.game.flips_total > 0 then
        local accuracy = math.floor(self.game.metrics.accuracy * 100)
        love.graphics.print("Accuracy: " .. accuracy .. "%", 20, 210)
    end

    -- Coin display area (center)
    local coin_x = w / 2
    local coin_y = h / 2
    local coin_radius = 80

    -- Draw coin
    love.graphics.setColor(0.8, 0.7, 0.2)  -- Gold color
    love.graphics.circle('fill', coin_x, coin_y, coin_radius)
    love.graphics.setColor(0.6, 0.5, 0.1)
    love.graphics.circle('line', coin_x, coin_y, coin_radius)

    -- Show last result on coin
    love.graphics.setColor(0.2, 0.2, 0.2)
    if self.game.last_result then
        local result_text = self.game.last_result:upper()
        love.graphics.printf(result_text, coin_x - 60, coin_y - 10, 120, 'center')
    else
        love.graphics.printf("?", coin_x - 60, coin_y - 10, 120, 'center')
    end

    -- Show result message
    if self.game.show_result then
        if self.game.flip_mode == "auto" then
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
        if self.game.flip_mode == "auto" then
            love.graphics.printf("[SPACE] Flip Coin", 0, h - 60, w, 'center', 0, 1.5, 1.5)
            love.graphics.setColor(0.7, 0.7, 0.7, 0.6)
            love.graphics.printf("Heads = Advance Streak | Tails = Reset", 0, h - 30, w, 'center')
        else
            love.graphics.printf("[H] Heads  |  [T] Tails", 0, h - 60, w, 'center', 0, 1.5, 1.5)
        end
    end

    -- Victory message
    if self.game.victory then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(0, 1, 0)
        love.graphics.printf("VICTORY!", 0, h / 2 - 40, w, 'center', 0, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Streak of " .. self.game.streak_target .. " reached!", 0, h / 2 + 20, w, 'center', 0, 1.5, 1.5)
    end

    -- Game Over message
    if self.game.game_over then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, w, h)
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("GAME OVER", 0, h / 2 - 40, w, 'center', 0, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Max Streak: " .. self.game.max_streak, 0, h / 2 + 20, w, 'center', 0, 1.5, 1.5)
    end
end

return CoinFlipView
