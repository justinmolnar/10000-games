local Object = require('class')
local SpaceShooterView = Object:extend('SpaceShooterView')

function SpaceShooterView:init(game_state)
    self.game = game_state
end

function SpaceShooterView:draw()
    local game = self.game
    local g = love.graphics

    g.setColor(0.1, 0.1, 0.1)
    g.rectangle('fill', 0, 0, game.game_width, game.game_height)

    g.setColor(0, 1, 0)
    g.rectangle('fill', game.player.x, game.player.y, game.player.width, game.player.height)

    g.setColor(1, 0, 0)
    for _, enemy in ipairs(game.enemies) do
        g.rectangle('fill', enemy.x, enemy.y, enemy.width, enemy.height)
    end

    g.setColor(0, 1, 1)
    for _, bullet in ipairs(game.player_bullets) do
        g.rectangle('fill', bullet.x, bullet.y, bullet.width, bullet.height)
    end

    g.setColor(1, 1, 0)
    for _, bullet in ipairs(game.enemy_bullets) do
        g.rectangle('fill', bullet.x, bullet.y, bullet.width, bullet.height)
    end

    g.setColor(1, 1, 1)
    g.print("Kills: " .. game.metrics.kills .. "/" .. game.target_kills, 10, 10)
    g.print("Deaths: " .. game.metrics.deaths .. "/" .. game.PLAYER_MAX_DEATHS, 10, 30)
    g.print("Difficulty: " .. game.difficulty_level, 10, 50)
end

return SpaceShooterView