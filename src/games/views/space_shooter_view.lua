-- src/games/views/space_shooter_view.lua
local Object = require('class')
local SpaceShooterView = Object:extend('SpaceShooterView')

function SpaceShooterView:init(game_state)
    self.game = game_state -- Reference to the SpaceShooter game instance
end

function SpaceShooterView:draw()
    local game = self.game -- Use local variable for easier access

    -- Draw player
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle('fill', game.player.x, game.player.y, game.player.width, game.player.height)

    -- Draw enemies
    love.graphics.setColor(1, 0, 0)
    for _, enemy in ipairs(game.enemies) do
        love.graphics.rectangle('fill', enemy.x, enemy.y, enemy.width, enemy.height)
    end

    -- Draw player bullets
    love.graphics.setColor(0, 1, 1)
    for _, bullet in ipairs(game.player_bullets) do
        love.graphics.rectangle('fill', bullet.x, bullet.y, bullet.width, bullet.height)
    end

    -- Draw enemy bullets
    love.graphics.setColor(1, 1, 0)
    for _, bullet in ipairs(game.enemy_bullets) do
        love.graphics.rectangle('fill', bullet.x, bullet.y, bullet.width, bullet.height)
    end

    -- Draw HUD
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Kills: " .. game.metrics.kills .. "/" .. game.target_kills, 10, 10)
    love.graphics.print("Deaths: " .. game.metrics.deaths .. "/" .. game.PLAYER_MAX_DEATHS, 10, 30) -- Need PLAYER_MAX_DEATHS, maybe pass it or get from game
    love.graphics.print("Difficulty: " .. game.difficulty_level, 10, 50)
end

return SpaceShooterView