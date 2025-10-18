-- space_defender_view.lua: All drawing functions for Space Defender

local SpaceDefenderView = {}

function SpaceDefenderView.drawPlayerShip(ship)
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle('fill', 
        ship.x - ship.width/2,
        ship.y - ship.height/2,
        ship.width, ship.height)
end

function SpaceDefenderView.drawEnemies(enemies)
    for _, enemy in ipairs(enemies) do
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle('fill', enemy.x - enemy.width/2, enemy.y - enemy.height/2,
            enemy.width, enemy.height)
        
        -- Draw HP bar above enemy if damaged
        if enemy.damaged then
            local bar_width = enemy.width
            local bar_height = 4
            local bar_x = enemy.x - bar_width/2
            local bar_y = enemy.y - enemy.height/2 - bar_height - 2
            
            -- Background (red)
            love.graphics.setColor(0.3, 0, 0)
            love.graphics.rectangle('fill', bar_x, bar_y, bar_width, bar_height)
            
            -- HP (green)
            love.graphics.setColor(0, 1, 0)
            local hp_percent = enemy.hp / enemy.max_hp
            love.graphics.rectangle('fill', bar_x, bar_y, bar_width * hp_percent, bar_height)
        end
    end
end

function SpaceDefenderView.drawBoss(boss)
    if not boss then return end
    
    love.graphics.setColor(0.5, 0, 0.5)
    love.graphics.rectangle('fill',
        boss.x - boss.width/2, boss.y - boss.height/2,
        boss.width, boss.height)
    
    -- Boss HP bar at top of screen
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle('fill', 50, 50, 700, 20)
    love.graphics.setColor(0, 1, 0)
    local hp_percent = boss.hp / boss.max_hp
    love.graphics.rectangle('fill', 50, 50, 700 * hp_percent, 20)
end

function SpaceDefenderView.drawHUD(player_ship, current_wave, total_waves, boss_active, bullet_count, current_level)
    love.graphics.setColor(1, 1, 1)
    
    -- HP
    love.graphics.print("HP: " .. player_ship.hp .. "/" .. player_ship.max_hp, 10, 10)
    
    -- Bombs
    love.graphics.print("Bombs: " .. player_ship.bombs, 10, 30)
    
    -- Wave/Boss
    if boss_active then
        love.graphics.print("BOSS FIGHT", love.graphics.getWidth()/2 - 40, 10)
    else
        love.graphics.print("Wave: " .. current_wave .. "/" .. total_waves, 
            love.graphics.getWidth()/2 - 40, 10)
    end
    
    -- Bullets active
    love.graphics.print("Bullets: " .. bullet_count, 
        love.graphics.getWidth() - 150, 10)
    
    -- Level
    love.graphics.print("Level: " .. current_level, love.graphics.getWidth() - 150, 30)
end

function SpaceDefenderView.drawVictoryScreen(tokens_earned)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(0, 1, 0)
    love.graphics.print("LEVEL COMPLETE!", love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2 - 60, 0, 2, 2)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Tokens Earned: " .. tokens_earned, love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2)
    love.graphics.print("Press ENTER to continue", love.graphics.getWidth()/2 - 100, love.graphics.getHeight()/2 + 40)
end

function SpaceDefenderView.drawGameOverScreen()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(1, 0, 0)
    love.graphics.print("GAME OVER", love.graphics.getWidth()/2 - 60, love.graphics.getHeight()/2 - 60, 0, 2, 2)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Press ENTER to return to launcher", love.graphics.getWidth()/2 - 140, love.graphics.getHeight()/2 + 40)
end

function SpaceDefenderView.drawPauseScreen()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("PAUSED", love.graphics.getWidth()/2 - 40, love.graphics.getHeight()/2, 0, 2, 2)
    love.graphics.print("Press P to resume", love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2 + 40)
end

return SpaceDefenderView