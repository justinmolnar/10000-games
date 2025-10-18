-- bullet_system.lua: Manages all bullets from completed games using object pooling

local Object = require('class')
local Collision = require('utils.collision')
local BulletSystem = Object:extend('BulletSystem')

function BulletSystem:init()
    self.bullet_types = {}
    self.active_bullets = {}
    self.inactive_bullets = {} -- Pool for reusable bullet tables
    self.fire_timers = {}
    self.global_fire_rate_multiplier = 1.0
    self.global_damage_multiplier = 1.0
end

function BulletSystem:loadBulletTypes(player_data, game_data)
    self.bullet_types = {}
    self.fire_timers = {}

    for game_id, perf_data in pairs(player_data.game_performance) do
        local game = game_data:getGame(game_id)
        if game and perf_data.best_score > 0 then
            local bullet_type = {
                id = game_id,
                name = game.display_name,
                damage = perf_data.best_score * self.global_damage_multiplier,
                fire_rate = (game.bullet_fire_rate or 1) * self.global_fire_rate_multiplier,
                sprite = game.bullet_sprite or "bullet_basic",
                special = game.bullet_special,
                color = self:getColorForGame(game)
            }

            if bullet_type.fire_rate > 0 then
                table.insert(self.bullet_types, bullet_type)
                local cooldown = 1 / bullet_type.fire_rate
                self.fire_timers[game_id] = math.random() * cooldown
            else
                print("Warning: Bullet type " .. game_id .. " has zero or negative fire rate, skipping.")
            end
        end
    end

    print(string.format("Loaded %d bullet types", #self.bullet_types))
end

function BulletSystem:getColorForGame(game)
    if game.category == "action" then return {1, 0, 0}
    elseif game.category == "puzzle" then return {0, 0, 1}
    elseif game.category == "arcade" then return {0, 1, 0}
    else return {1, 1, 1} end
end

function BulletSystem:update(dt, player_pos, enemies, boss)
    -- Update fire timers and spawn bullets
    if player_pos then -- Only spawn if player exists
        for _, bullet_type in ipairs(self.bullet_types) do
            self.fire_timers[bullet_type.id] = self.fire_timers[bullet_type.id] - dt
            if self.fire_timers[bullet_type.id] <= 0 then
                self:spawnBullet(bullet_type, player_pos)
                -- Reset timer, adding the overshoot
                local cooldown = 1 / bullet_type.fire_rate
                self.fire_timers[bullet_type.id] = cooldown + self.fire_timers[bullet_type.id] 
            end
        end
    end

    -- Update active bullets
    for i = #self.active_bullets, 1, -1 do
        local bullet = self.active_bullets[i]
        bullet.y = bullet.y + bullet.vy * dt

        -- Check if off screen
        if bullet.y < -bullet.height then -- Check top edge
            -- Recycle bullet
            table.insert(self.inactive_bullets, bullet)
            table.remove(self.active_bullets, i)
        else
            -- Check collisions
            local hit = false
            -- Check enemies
            for j = #enemies, 1, -1 do -- Iterate backwards for safe removal
                local enemy = enemies[j]
                 -- Use checkBulletCollision which assumes target has width/height centered at x,y
                 -- Need consistency: are enemy x,y top-left or center? Assuming center based on view draw.
                 -- Bullet x,y is top-left in spawnBullet, center it for collision check?
                 -- Let's stick to AABB based on current implementation
                 local bullet_x1 = bullet.x - bullet.width/2
                 local bullet_y1 = bullet.y - bullet.height/2
                 local enemy_x1 = enemy.x - enemy.width/2
                 local enemy_y1 = enemy.y - enemy.height/2
                if Collision.checkAABB(bullet_x1, bullet_y1, bullet.width, bullet.height,
                                      enemy_x1, enemy_y1, enemy.width, enemy.height) then
                    enemy.hp = enemy.hp - bullet.damage
                    enemy.damaged = true
                    if enemy.hp <= 0 then
                        table.remove(enemies, j)
                    end
                    hit = true
                    break -- Bullet hits one enemy max
                end
            end

            -- Check boss if no enemy hit
            if not hit and boss and boss.hp > 0 then
                local bullet_x1 = bullet.x - bullet.width/2
                local bullet_y1 = bullet.y - bullet.height/2
                local boss_x1 = boss.x - boss.width/2
                local boss_y1 = boss.y - boss.height/2
                if Collision.checkAABB(bullet_x1, bullet_y1, bullet.width, bullet.height,
                                      boss_x1, boss_y1, boss.width, boss.height) then
                    boss.hp = boss.hp - bullet.damage
                    hit = true
                end
            end

            -- Recycle bullet if it hit something
            if hit then
                table.insert(self.inactive_bullets, bullet)
                table.remove(self.active_bullets, i)
            end
        end
    end
end


function BulletSystem:spawnBullet(bullet_type, player_pos)
    local bullet = nil
    -- Try to reuse from pool first
    if #self.inactive_bullets > 0 then
        bullet = table.remove(self.inactive_bullets)
    else -- Create new if pool is empty
        bullet = {}
    end

    -- Initialize/Reset bullet properties
    bullet.x = player_pos.x -- Spawn at player center
    bullet.y = player_pos.y - player_pos.height/2 -- Spawn slightly above center
    bullet.width = 4
    bullet.height = 8
    bullet.vy = -400  -- Move upward
    bullet.damage = bullet_type.damage
    bullet.color = bullet_type.color
    bullet.special = bullet_type.special
    -- Add any other properties bullets might have

    table.insert(self.active_bullets, bullet)
end


function BulletSystem:draw()
    for _, bullet in ipairs(self.active_bullets) do
        love.graphics.setColor(bullet.color)
        -- Draw centered
        love.graphics.rectangle('fill', bullet.x - bullet.width/2, bullet.y - bullet.height/2,
            bullet.width, bullet.height)
    end
    -- Optional: Draw pool size for debugging
    -- love.graphics.setColor(1,1,1)
    -- love.graphics.print("Active Bullets: " .. #self.active_bullets, 10, love.graphics.getHeight() - 40)
    -- love.graphics.print("Inactive Pool: " .. #self.inactive_bullets, 10, love.graphics.getHeight() - 20)
end

-- Clear now recycles bullets
function BulletSystem:clear()
    -- Move all active bullets to the inactive pool
    for i = #self.active_bullets, 1, -1 do
        local bullet = table.remove(self.active_bullets, i)
        table.insert(self.inactive_bullets, bullet)
    end
    -- self.active_bullets should now be empty
end


function BulletSystem:setGlobalMultipliers(fire_rate_mult, damage_mult)
    self.global_fire_rate_multiplier = fire_rate_mult or 1.0
    self.global_damage_multiplier = damage_mult or 1.0
end

function BulletSystem:getBulletCount()
    return #self.active_bullets
end

return BulletSystem