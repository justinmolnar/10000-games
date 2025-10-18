-- space_defender_view.lua: View Class for Space Defender

local Object = require('class')
local SpaceDefenderView = Object:extend('SpaceDefenderView')

function SpaceDefenderView:init(controller)
    self.controller = controller -- Reference to the space_defender_state
end

-- Main draw function called by the state (Fullscreen version)
function SpaceDefenderView:draw(player_ship, enemies, boss, boss_active, bullet_system, current_wave, total_waves, current_level, tokens_earned, level_complete, game_over, paused)
     -- This function remains for potential future use or if called unexpectedly
     -- For windowed mode, drawWindowed should be called
     self:drawWindowed(player_ship, enemies, boss, boss_active, bullet_system, current_wave, total_waves, current_level, tokens_earned, level_complete, game_over, paused, love.graphics.getWidth(), love.graphics.getHeight())
end

-- NEW Windowed Draw Function
function SpaceDefenderView:drawWindowed(player_ship, enemies, boss, boss_active, bullet_system, current_wave, total_waves, current_level, tokens_earned, level_complete, game_over, paused, viewport_width, viewport_height)
    -- IMPORTANT: Gameplay object positions (player, enemies, bullets) still use global coordinates.
    -- Rendering them without transformation/scaling within a smaller viewport will clip them.
    -- Phase 4 accepts this clipping. Full solution requires scaling graphics.

    -- Draw player ship (clips if outside viewport)
    self:drawPlayerShip(player_ship)

    -- Draw enemies (clips if outside viewport)
    self:drawEnemies(enemies)

    -- Draw boss (clips if outside viewport, HP bar adjusted)
    if boss_active and boss then
        self:drawBossWindowed(boss, viewport_width)
    end

    -- Draw bullets (clips if outside viewport)
    bullet_system:draw()

    -- Draw HUD (positioned relative to viewport)
    self:drawHUDWindowed(
        player_ship, current_wave, total_waves, boss_active,
        bullet_system:getBulletCount(), current_level, viewport_width
    )

    -- Draw overlays (positioned relative to viewport)
    if level_complete then
        self:drawVictoryScreenWindowed(tokens_earned, viewport_width, viewport_height)
    elseif game_over then
        self:drawGameOverScreenWindowed(viewport_width, viewport_height)
    elseif paused then
        self:drawPauseScreenWindowed(viewport_width, viewport_height)
    end
end


-- Drawing methods (unmodified unless specified)
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

        -- Draw HP bar only if enemy has taken damage
        if enemy.damaged and enemy.hp < enemy.max_hp then
            local bar_width = enemy.width
            local bar_height = 4
            local bar_x = enemy.x - bar_width/2
            local bar_y = enemy.y - enemy.height/2 - bar_height - 2

            love.graphics.setColor(0.3, 0, 0)
            love.graphics.rectangle('fill', bar_x, bar_y, bar_width, bar_height)
            love.graphics.setColor(1, 0, 0) -- Red background for damage taken
            local hp_percent = math.max(0, enemy.hp / enemy.max_hp)
            love.graphics.setColor(0, 1, 0)
            love.graphics.rectangle('fill', bar_x, bar_y, bar_width * hp_percent, bar_height)
        end
    end
end

-- Original drawBoss (kept for reference, not used in windowed)
function SpaceDefenderView:drawBoss(boss)
    if not boss then return end

    love.graphics.setColor(0.5, 0, 0.5)
    love.graphics.rectangle('fill',
        boss.x - boss.width/2, boss.y - boss.height/2,
        boss.width, boss.height)

    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle('fill', 50, 50, 700, 20)
    love.graphics.setColor(0, 1, 0)
    local hp_percent = math.max(0, boss.hp / boss.max_hp)
    love.graphics.rectangle('fill', 50, 50, 700 * hp_percent, 20)
end

-- NEW Windowed Boss Draw
function SpaceDefenderView:drawBossWindowed(boss, viewport_width)
    if not boss then return end

    -- Draw boss sprite (same as before)
    love.graphics.setColor(0.5, 0, 0.5)
    love.graphics.rectangle('fill',
        boss.x - boss.width/2, boss.y - boss.height/2,
        boss.width, boss.height)

    -- Draw HP bar adjusted for viewport width
    local bar_margin = 50
    local bar_width = math.max(100, viewport_width - (bar_margin * 2)) -- Ensure minimum width
    local bar_height = 20
    local bar_x = (viewport_width - bar_width) / 2 -- Center the bar
    local bar_y = 10 -- Position near top of viewport

    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_width, bar_height)
    love.graphics.setColor(0, 1, 0)
    local hp_percent = math.max(0, boss.hp / boss.max_hp)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_width * hp_percent, bar_height)
end

-- Original HUD (kept for reference)
function SpaceDefenderView:drawHUD(player_ship, current_wave, total_waves, boss_active, bullet_count, current_level)
    if not player_ship then return end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. player_ship.hp .. "/" .. player_ship.max_hp, 10, 10)
    love.graphics.print("Bombs: " .. player_ship.bombs, 10, 30)

    if boss_active then
        love.graphics.printf("BOSS FIGHT", 0, 10, love.graphics.getWidth(), "center")
    else
        love.graphics.printf("Wave: " .. current_wave .. "/" .. total_waves, 0, 10, love.graphics.getWidth(), "center")
    end

    love.graphics.print("Bullets: " .. bullet_count, love.graphics.getWidth() - 150, 10)
    love.graphics.print("Level: " .. current_level, love.graphics.getWidth() - 150, 30)
end

-- NEW Windowed HUD
function SpaceDefenderView:drawHUDWindowed(player_ship, current_wave, total_waves, boss_active, bullet_count, current_level, viewport_width)
    if not player_ship then return end
    love.graphics.setColor(1, 1, 1)
    -- Top Left (adjust y if boss bar is present)
    local hud_y = boss_active and 40 or 10
    love.graphics.print("HP: " .. player_ship.hp .. "/" .. player_ship.max_hp, 10, hud_y)
    love.graphics.print("Bombs: " .. player_ship.bombs, 10, hud_y + 20)

    -- Top Center (adjust y if boss bar is present)
    if not boss_active then
        love.graphics.printf("Wave: " .. current_wave .. "/" .. total_waves, 0, hud_y, viewport_width, "center")
    end

    -- Top Right (adjust y if boss bar is present)
    local right_x = math.max(viewport_width - 150, viewport_width / 2 + 50) -- Ensure doesn't overlap center text
    love.graphics.print("Bullets: " .. bullet_count, right_x, hud_y)
    love.graphics.print("Level: " .. current_level, right_x, hud_y + 20)
end


-- Original Overlays (kept for reference)
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


-- NEW Windowed Overlays
function SpaceDefenderView:drawVictoryScreenWindowed(tokens_earned, viewport_width, viewport_height)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)
    love.graphics.setColor(0, 1, 0)
    love.graphics.printf("LEVEL COMPLETE!", 0, viewport_height/2 - 60, viewport_width, "center", 0, 1.5, 1.5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Tokens Earned: " .. (tokens_earned or 0), 0, viewport_height/2, viewport_width, "center")
    love.graphics.printf("Press ENTER for Next Level", 0, viewport_height/2 + 40, viewport_width, "center")
    love.graphics.printf("Press ESC to Close", 0, viewport_height/2 + 60, viewport_width, "center")
end

function SpaceDefenderView:drawGameOverScreenWindowed(viewport_width, viewport_height)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)
    love.graphics.setColor(1, 0, 0)
    love.graphics.printf("GAME OVER", 0, viewport_height/2 - 60, viewport_width, "center", 0, 1.5, 1.5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press ENTER to Close", 0, viewport_height/2 + 40, viewport_width, "center")
end

function SpaceDefenderView:drawPauseScreenWindowed(viewport_width, viewport_height)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("PAUSED", 0, viewport_height/2, viewport_width, "center", 0, 1.5, 1.5)
    love.graphics.printf("Press P to resume", 0, viewport_height/2 + 40, viewport_width, "center")
end


function SpaceDefenderView:update(dt)
    -- Currently no view-specific update logic needed here.
    -- Could be used later for HUD animations, etc.
end

return SpaceDefenderView