-- src/models/bullet_system.lua
local Object = require('class')
local Collision = require('utils.collision')
local BulletSystem = Object:extend('BulletSystem')

-- Accept statistics instance
function BulletSystem:init(statistics_instance)
    self.statistics = statistics_instance -- Store injected instance

    self.bullet_types = {}
    self.active_bullets = {}
    self.inactive_bullets = {}
    self.fire_timers = {}
    self.global_fire_rate_multiplier = 1.0
    self.global_damage_multiplier = 1.0
    self.bullets_fired_this_frame = 0 -- Stat tracking
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
    self.bullets_fired_this_frame = 0 -- Reset counter each frame

    -- Update fire timers and spawn bullets
    if player_pos then
        for _, bullet_type in ipairs(self.bullet_types) do
            self.fire_timers[bullet_type.id] = self.fire_timers[bullet_type.id] - dt
            if self.fire_timers[bullet_type.id] <= 0 then
                self:spawnBullet(bullet_type, player_pos)
                local cooldown = 1 / bullet_type.fire_rate
                self.fire_timers[bullet_type.id] = cooldown + self.fire_timers[bullet_type.id]
            end
        end
    end

    -- Update active bullets
    for i = #self.active_bullets, 1, -1 do
        local bullet = self.active_bullets[i]
        bullet.y = bullet.y + bullet.vy * dt

        if bullet.y < -bullet.height then
            table.insert(self.inactive_bullets, bullet)
            table.remove(self.active_bullets, i)
        else
            local hit = false
            -- Check enemies
            for j = #enemies, 1, -1 do
                local enemy = enemies[j]
                local bullet_x1 = bullet.x - bullet.width/2
                local bullet_y1 = bullet.y - bullet.height/2
                local enemy_x1 = enemy.x - enemy.width/2
                local enemy_y1 = enemy.y - enemy.height/2
                if Collision.checkAABB(bullet_x1, bullet_y1, bullet.width, bullet.height,
                                      enemy_x1, enemy_y1, enemy.width, enemy.height) then
                    local damage_dealt = bullet.damage
                    enemy.hp = enemy.hp - damage_dealt
                    enemy.damaged = true
                    -- Update statistics using self.statistics
                    if self.statistics and self.statistics.recordDamageDealt then
                        self.statistics:recordDamageDealt(damage_dealt)
                        -- print("Debug BulletSys: Called recordDamageDealt (Enemy)") -- Optional
                    else
                        -- print("Debug BulletSys: Statistics object not found (Enemy Hit)") -- Optional
                    end
                    if enemy.hp <= 0 then
                        table.remove(enemies, j)
                    end
                    hit = true
                    break
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
                    local damage_dealt = bullet.damage
                    boss.hp = boss.hp - damage_dealt
                    -- Update statistics using self.statistics
                    if self.statistics and self.statistics.recordDamageDealt then
                        self.statistics:recordDamageDealt(damage_dealt)
                        -- print("Debug BulletSys: Called recordDamageDealt (Boss)") -- Optional
                    else
                        -- print("Debug BulletSys: Statistics object not found (Boss Hit)") -- Optional
                    end
                    hit = true
                end
            end

            if hit then
                table.insert(self.inactive_bullets, bullet)
                table.remove(self.active_bullets, i)
            end
        end
    end

    -- Update total bullets fired statistic at end of frame using self.statistics
    if self.bullets_fired_this_frame > 0 then
        if self.statistics and self.statistics.addBulletsFired then
            self.statistics:addBulletsFired(self.bullets_fired_this_frame)
            -- print("Debug BulletSys: Called addBulletsFired") -- Optional
        else
            -- print("Debug BulletSys: Statistics object not found (End Frame)") -- Optional
        end
    end
end


function BulletSystem:spawnBullet(bullet_type, player_pos)
    local bullet = nil
    if #self.inactive_bullets > 0 then
        bullet = table.remove(self.inactive_bullets)
    else
        bullet = {}
    end

    bullet.x = player_pos.x
    bullet.y = player_pos.y - player_pos.height/2
    bullet.width = 4
    bullet.height = 8
    bullet.vy = -400
    bullet.damage = bullet_type.damage
    bullet.color = bullet_type.color
    bullet.special = bullet_type.special

    table.insert(self.active_bullets, bullet)
    self.bullets_fired_this_frame = self.bullets_fired_this_frame + 1 -- Increment counter
end


function BulletSystem:draw()
    for _, bullet in ipairs(self.active_bullets) do
        love.graphics.setColor(bullet.color)
        love.graphics.rectangle('fill', bullet.x - bullet.width/2, bullet.y - bullet.height/2,
            bullet.width, bullet.height)
    end
end

function BulletSystem:clear()
    for i = #self.active_bullets, 1, -1 do
        local bullet = table.remove(self.active_bullets, i)
        table.insert(self.inactive_bullets, bullet)
    end
end


function BulletSystem:setGlobalMultipliers(fire_rate_mult, damage_mult)
    self.global_fire_rate_multiplier = fire_rate_mult or 1.0
    self.global_damage_multiplier = damage_mult or 1.0
end

function BulletSystem:getBulletCount()
    return #self.active_bullets
end

return BulletSystem