local Class = require('lib.class')
local BreakoutView = Class:extend('BreakoutView')

function BreakoutView:init(game)
    self.game = game
end

function BreakoutView:draw()
    love.graphics.push()
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle('fill', 0, 0, self.game.arena_width, self.game.arena_height)
    love.graphics.pop()

    -- Draw bricks
    for _, brick in ipairs(self.game.bricks) do
        if brick.alive then
            love.graphics.push()

            -- Color based on health
            local health_percent = brick.health / brick.max_health
            if health_percent > 0.66 then
                love.graphics.setColor(0.3, 0.8, 0.3)
            elseif health_percent > 0.33 then
                love.graphics.setColor(0.9, 0.9, 0.3)
            else
                love.graphics.setColor(0.9, 0.3, 0.3)
            end

            love.graphics.rectangle('fill', brick.x, brick.y, brick.width, brick.height)

            -- Brick outline
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle('line', brick.x, brick.y, brick.width, brick.height)

            love.graphics.pop()
        end
    end

    -- Draw paddle
    love.graphics.push()
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle('fill',
        self.game.paddle.x - self.game.paddle.width / 2,
        self.game.paddle.y - self.game.paddle.height / 2,
        self.game.paddle.width,
        self.game.paddle.height)
    love.graphics.pop()

    -- Draw ball(s)
    for _, ball in ipairs(self.game.balls) do
        if ball.active then
            love.graphics.push()
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle('fill', ball.x, ball.y, ball.radius)
            love.graphics.pop()
        end
    end

    -- Draw HUD
    love.graphics.push()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Lives: " .. self.game.lives, 10, 10)
    love.graphics.print("Score: " .. math.floor(self.game.score), 10, 30)
    love.graphics.print("Combo: " .. self.game.combo, 10, 50)
    love.graphics.print("Bricks: " .. self.game.bricks_destroyed, self.game.arena_width - 120, 10)
    love.graphics.pop()

    -- Victory/Game Over overlay
    if self.game.victory then
        love.graphics.push()
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, self.game.arena_width, self.game.arena_height)

        love.graphics.setColor(0.3, 1, 0.3)
        local text = "VICTORY!"
        local font = love.graphics.getFont()
        local text_width = font:getWidth(text)
        love.graphics.print(text, (self.game.arena_width - text_width) / 2, self.game.arena_height / 2 - 40)

        love.graphics.setColor(1, 1, 1)
        local score_text = "Final Score: " .. math.floor(self.game.score)
        local score_width = font:getWidth(score_text)
        love.graphics.print(score_text, (self.game.arena_width - score_width) / 2, self.game.arena_height / 2)
        love.graphics.pop()
    elseif self.game.game_over then
        love.graphics.push()
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, self.game.arena_width, self.game.arena_height)

        love.graphics.setColor(1, 0.3, 0.3)
        local text = "GAME OVER"
        local font = love.graphics.getFont()
        local text_width = font:getWidth(text)
        love.graphics.print(text, (self.game.arena_width - text_width) / 2, self.game.arena_height / 2 - 40)

        love.graphics.setColor(1, 1, 1)
        local score_text = "Final Score: " .. math.floor(self.game.score)
        local score_width = font:getWidth(score_text)
        love.graphics.print(score_text, (self.game.arena_width - score_width) / 2, self.game.arena_height / 2)
        love.graphics.pop()
    end
end

return BreakoutView
