local Object = require('class')
local SpaceDefenderView = Object:extend('SpaceDefenderView')

function SpaceDefenderView:init(controller)
    self.controller = controller
end

function SpaceDefenderView:draw(player_ship, enemies, boss, boss_active, bullet_system, current_wave, total_waves, current_level, tokens_earned, level_complete, game_over, paused, viewport_width, viewport_height)
    self:drawPlayerShip(player_ship)
    self:drawEnemies(enemies)
    
    if boss_active and boss then
        self:drawBoss(boss, viewport_width)
    end

    bullet_system:draw()

    self:drawHUD(
        player_ship, current_wave, total_waves, boss_active,
        bullet_system:getBulletCount(), current_level, viewport_width, viewport_height
    )

    if level_complete then
        self:drawVictoryScreen(tokens_earned, viewport_width, viewport_height)
    elseif game_over then
        self:drawGameOverScreen(viewport_width, viewport_height)
    elseif paused then
        self:drawPauseScreen(viewport_width, viewport_height)
    end
end

function SpaceDefenderView:drawPlayerShip(ship)
    if not ship then return end
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle('fill',
        ship.x - ship.width/2,
        ship.y - ship.height/2,
        ship.width, ship.height)
end

function SpaceDefenderView:drawEnemies(enemies)
    for _, enemy in ipairs(enemies) do
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle('fill', enemy.x - enemy.width/2, enemy.y - enemy.height/2,
            enemy.width, enemy.height)

        if enemy.damaged and enemy.hp < enemy.max_hp then
            local bar_width = enemy.width
            local bar_height = 4
            local bar_x = enemy.x - bar_width/2
            local bar_y = enemy.y - enemy.height/2 - bar_height - 2

            love.graphics.setColor(0.3, 0, 0)
            love.graphics.rectangle('fill', bar_x, bar_y, bar_width, bar_height)
            love.graphics.setColor(1, 0, 0)
            local hp_percent = math.max(0, enemy.hp / enemy.max_hp)
            love.graphics.setColor(0, 1, 0)
            love.graphics.rectangle('fill', bar_x, bar_y, bar_width * hp_percent, bar_height)
        end
    end
end

function SpaceDefenderView:drawBoss(boss, viewport_width)
    if not boss then return end

    love.graphics.setColor(0.5, 0, 0.5)
    love.graphics.rectangle('fill',
        boss.x - boss.width/2, boss.y - boss.height/2,
        boss.width, boss.height)

    local bar_margin = 50
    local bar_width = math.max(100, viewport_width - (bar_margin * 2))
    local bar_height = 20
    local bar_x = (viewport_width - bar_width) / 2
    local bar_y = 10

    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_width, bar_height)
    love.graphics.setColor(0, 1, 0)
    local hp_percent = math.max(0, boss.hp / boss.max_hp)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_width * hp_percent, bar_height)
end

function SpaceDefenderView:drawHUD(player_ship, current_wave, total_waves, boss_active, bullet_count, current_level, viewport_width, viewport_height)
    if not player_ship then return end
    love.graphics.setColor(1, 1, 1)
    
    local hud_y = boss_active and 40 or 10
    love.graphics.print("HP: " .. player_ship.hp .. "/" .. player_ship.max_hp, 10, hud_y)
    love.graphics.print("Bombs: " .. player_ship.bombs, 10, hud_y + 20)

    if not boss_active then
        love.graphics.printf("Wave: " .. current_wave .. "/" .. total_waves, 0, hud_y, viewport_width, "center")
    end

    local right_x = math.max(viewport_width - 150, viewport_width / 2 + 50)
    love.graphics.print("Bullets: " .. bullet_count, right_x, hud_y)
    love.graphics.print("Level: " .. current_level, right_x, hud_y + 20)
end

function SpaceDefenderView:drawVictoryScreen(tokens_earned, viewport_width, viewport_height)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)
    love.graphics.setColor(0, 1, 0)
    love.graphics.printf("LEVEL COMPLETE!", 0, viewport_height/2 - 60, viewport_width, "center", 0, 1.5, 1.5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Tokens Earned: " .. (tokens_earned or 0), 0, viewport_height/2, viewport_width, "center")
    love.graphics.printf("Press ENTER for Next Level", 0, viewport_height/2 + 40, viewport_width, "center")
    love.graphics.printf("Press ESC to Close", 0, viewport_height/2 + 60, viewport_width, "center")
end

function SpaceDefenderView:drawGameOverScreen(viewport_width, viewport_height)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)
    love.graphics.setColor(1, 0, 0)
    love.graphics.printf("GAME OVER", 0, viewport_height/2 - 60, viewport_width, "center", 0, 1.5, 1.5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press ENTER to Close", 0, viewport_height/2 + 40, viewport_width, "center")
end

function SpaceDefenderView:drawPauseScreen(viewport_width, viewport_height)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("PAUSED", 0, viewport_height/2, viewport_width, "center", 0, 1.5, 1.5)
    love.graphics.printf("Press P to resume", 0, viewport_height/2 + 40, viewport_width, "center")
end

function SpaceDefenderView:update(dt)
end

return SpaceDefenderView