-- space_defender_view.lua: View Class for Space Defender

local Object = require('class')
local SpaceDefenderView = Object:extend('SpaceDefenderView')

function SpaceDefenderView:init(controller)
    self.controller = controller -- Reference to the space_defender_state
end

-- Main draw function called by the state
function SpaceDefenderView:draw(player_ship, enemies, boss, boss_active, bullet_system, current_wave, total_waves, current_level, tokens_earned, level_complete, game_over, paused)
    -- Draw player ship
    self:drawPlayerShip(player_ship)
    
    -- Draw enemies
    self:drawEnemies(enemies)
    
    -- Draw boss
    if boss_active and boss then
        self:drawBoss(boss)
    end
    
    -- Draw bullets (delegated to bullet_system)
    bullet_system:draw()
    
    -- Draw HUD
    self:drawHUD(
        player_ship,
        current_wave,
        total_waves,
        boss_active,
        bullet_system:getBulletCount(),
        current_level
    )
    
    -- Draw overlays
    if level_complete then
        self:drawVictoryScreen(tokens_earned)
    elseif game_over then
        self:drawGameOverScreen()
    elseif paused then
        self:drawPauseScreen()
    end
end

-- Drawing methods (previously static functions)
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
        
        if enemy.damaged then
            local bar_width = enemy.width
            local bar_height = 4
            local bar_x = enemy.x - bar_width/2
            local bar_y = enemy.y - enemy.height/2 - bar_height - 2
            
            love.graphics.setColor(0.3, 0, 0)
            love.graphics.rectangle('fill', bar_x, bar_y, bar_width, bar_height)
            love.graphics.setColor(0, 1, 0)
            local hp_percent = enemy.hp / enemy.max_hp
            love.graphics.rectangle('fill', bar_x, bar_y, bar_width * hp_percent, bar_height)
        end
    end
end

function SpaceDefenderView:drawBoss(boss)
    if not boss then return end
    
    love.graphics.setColor(0.5, 0, 0.5)
    love.graphics.rectangle('fill',
        boss.x - boss.width/2, boss.y - boss.height/2,
        boss.width, boss.height)
    
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle('fill', 50, 50, 700, 20)
    love.graphics.setColor(0, 1, 0)
    local hp_percent = boss.hp / boss.max_hp
    love.graphics.rectangle('fill', 50, 50, 700 * hp_percent, 20)
end

function SpaceDefenderView:drawHUD(player_ship, current_wave, total_waves, boss_active, bullet_count, current_level)
    if not player_ship then return end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. player_ship.hp .. "/" .. player_ship.max_hp, 10, 10)
    love.graphics.print("Bombs: " .. player_ship.bombs, 10, 30)
    
    if boss_active then
        love.graphics.print("BOSS FIGHT", love.graphics.getWidth()/2 - 40, 10)
    else
        love.graphics.print("Wave: " .. current_wave .. "/" .. total_waves, 
            love.graphics.getWidth()/2 - 40, 10)
    end
    
    love.graphics.print("Bullets: " .. bullet_count, love.graphics.getWidth() - 150, 10)
    love.graphics.print("Level: " .. current_level, love.graphics.getWidth() - 150, 30)
end

function SpaceDefenderView:drawVictoryScreen(tokens_earned)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(0, 1, 0)
    love.graphics.printf("LEVEL COMPLETE!", 0, love.graphics.getHeight()/2 - 60, love.graphics.getWidth(), "center")
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Tokens Earned: " .. (tokens_earned or 0), 0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
    love.graphics.printf("Press ENTER to continue", 0, love.graphics.getHeight()/2 + 40, love.graphics.getWidth(), "center")
end

function SpaceDefenderView:drawGameOverScreen()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 0, 0)
    love.graphics.printf("GAME OVER", 0, love.graphics.getHeight()/2 - 60, love.graphics.getWidth(), "center")
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press ENTER to return to desktop", 0, love.graphics.getHeight()/2 + 40, love.graphics.getWidth(), "center")
end

function SpaceDefenderView:drawPauseScreen()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("PAUSED", 0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
    love.graphics.printf("Press P to resume", 0, love.graphics.getHeight()/2 + 40, love.graphics.getWidth(), "center")
end

function SpaceDefenderView:update(dt)
    -- Currently no view-specific update logic needed here.
    -- Could be used later for HUD animations, etc.
end

return SpaceDefenderView