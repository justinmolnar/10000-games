-- src/models/bullet_system.lua
local Object = require('class')
local Collision = require('utils.collision')
local Config = require('src.config')
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
                sprite = self:resolveBulletSprite(game),
                special = game.bullet_special,
                -- Phase 7.3: Use game's actual palette color
                color = self:getBulletColorFromPalette(game)
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

-- Pick a valid sprite for bullets, with graceful fallbacks
function BulletSystem:resolveBulletSprite(game)
    local SpriteManager = require('src.utils.sprite_manager').getInstance()
    SpriteManager:ensureLoaded()
    local candidates = {}
    if game.bullet_sprite and game.bullet_sprite ~= '' then
        table.insert(candidates, game.bullet_sprite)
    end
    -- Category-themed suggestions
    if game.category == "action" then
        table.insert(candidates, "windows_slanted-1")
        table.insert(candidates, "computer_explorer-3")
    elseif game.category == "arcade" then
        table.insert(candidates, "world_star-0")
        table.insert(candidates, "wm-3")
    elseif game.category == "puzzle" then
        table.insert(candidates, "wm_file-0")
        table.insert(candidates, "xml_gear-0")
    else
        table.insert(candidates, "world_star-1")
    end
    -- Final generic fallbacks
    table.insert(candidates, "world_star-0")
    table.insert(candidates, "joystick_alt-1")
    for _, name in ipairs(candidates) do
        if SpriteManager.sprite_loader:hasSprite(name) then
            return name
        end
    end
    return nil
end

function BulletSystem:getBulletColorFromPalette(game)
    local SpriteManager = require('src.utils.sprite_manager').getInstance()
    SpriteManager:ensureLoaded()
    local palette_id = SpriteManager:getPaletteId(game)
    local palette = SpriteManager.palette_manager:getPalette(palette_id)
    
    if palette and palette.colors then
        -- Use accent color if available, otherwise primary
        return palette.colors.accent or palette.colors.primary or {1, 1, 1}
    end

    -- Fallback to category color
    return self:getColorForGame(game)
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

        local B = (Config.systems and Config.systems.bullets) or {}
        local despawn_margin = B.despawn_margin or 0
        if bullet.y < -bullet.height - despawn_margin then
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

    local B = (Config.systems and Config.systems.bullets) or {}
    bullet.x = player_pos.x
    bullet.y = player_pos.y - player_pos.height/2 - (B.spawn_offset_y or 0)
    bullet.width = B.width or 4
    bullet.height = B.height or 8
    bullet.vy = B.speed_y or -400
    bullet.damage = bullet_type.damage
    bullet.color = bullet_type.color
    bullet.special = bullet_type.special
    -- Phase 7.3: Assign sprite to bullet
    bullet.sprite = bullet_type.sprite
    bullet.id = bullet_type.id -- Pass game_id to bullet for lookup

    table.insert(self.active_bullets, bullet)
    self.bullets_fired_this_frame = self.bullets_fired_this_frame + 1 -- Increment counter
end


function BulletSystem:draw(game_data)
    local SpriteManager = require('src.utils.sprite_manager').getInstance()
    SpriteManager:ensureLoaded()

    for _, bullet in ipairs(self.active_bullets) do
        -- Phase 7.3: Draw bullet sprite instead of rectangle
        if bullet.sprite and bullet.sprite ~= "bullet_basic" then
            local game = game_data:getGame(bullet.id)
            local palette_id = "default"
            if game then palette_id = SpriteManager:getPaletteId(game) end
            
            local B = (Config.systems and Config.systems.bullets) or {}
            local s = B.sprite_scale or 2.0
            SpriteManager.sprite_loader:drawSprite(
                bullet.sprite, 
                bullet.x - bullet.width/2, 
                bullet.y - bullet.height/2, 
                bullet.width * s,
                bullet.height * s,
                nil, 
                palette_id
            )
        else
            -- Fallback to colored rectangle
            love.graphics.setColor(bullet.color)
            love.graphics.rectangle('fill', bullet.x - bullet.width/2, bullet.y - bullet.height/2,
                bullet.width, bullet.height)
        end
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