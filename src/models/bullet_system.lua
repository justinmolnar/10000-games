-- bullet_system.lua: Manages all bullets from completed games

local Object = require('class')
local BulletSystem = Object:extend('BulletSystem')

function BulletSystem:init()
    self.bullet_types = {}
    self.active_bullets = {}
    self.fire_timers = {}
    self.global_fire_rate_multiplier = 1.0
    self.global_damage_multiplier = 1.0
end

function BulletSystem:loadBulletTypes(player_data, game_data)
    self.bullet_types = {}
    self.fire_timers = {}
    
    -- Load all completed games as bullet types
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
            
            table.insert(self.bullet_types, bullet_type)
            self.fire_timers[game_id] = 0
        end
    end
    
    print(string.format("Loaded %d bullet types", #self.bullet_types))
end

function BulletSystem:getColorForGame(game)
    -- Assign color based on game category
    if game.category == "action" then
        return {1, 0, 0}  -- Red
    elseif game.category == "puzzle" then
        return {0, 0, 1}  -- Blue
    elseif game.category == "arcade" then
        return {0, 1, 0}  -- Green
    else
        return {1, 1, 1}  -- White
    end
end

function BulletSystem:update(dt, player_pos, enemies, boss)
    -- Update fire timers and spawn bullets
    for _, bullet_type in ipairs(self.bullet_types) do
        self.fire_timers[bullet_type.id] = self.fire_timers[bullet_type.id] - dt
        
        if self.fire_timers[bullet_type.id] <= 0 then
            self:spawnBullet(bullet_type, player_pos)
            self.fire_timers[bullet_type.id] = 1 / bullet_type.fire_rate
        end
    end
    
    -- Update active bullets
    for i = #self.active_bullets, 1, -1 do
        local bullet = self.active_bullets[i]
        
        -- Move bullet
        bullet.y = bullet.y + bullet.vy * dt
        
        -- Remove if off screen
        if bullet.y < -10 then
            table.remove(self.active_bullets, i)
        else
            -- Check collisions with enemies
            local hit = false
            
            for j, enemy in ipairs(enemies) do
                if self:checkBulletCollision(bullet, enemy) then
                    enemy.hp = enemy.hp - bullet.damage
                    enemy.damaged = true  -- Mark enemy as damaged
                    if enemy.hp <= 0 then
                        table.remove(enemies, j)
                    end
                    hit = true
                    break
                end
            end
            
            -- Check collision with boss
            if not hit and boss and self:checkBulletCollision(bullet, boss) then
                boss.hp = boss.hp - bullet.damage
                hit = true
            end
            
            -- Remove bullet if it hit something
            if hit then
                table.remove(self.active_bullets, i)
            end
        end
    end
end

function BulletSystem:checkBulletCollision(bullet, target)
    local Collision = require('utils.collision')
    return Collision.checkAABB(
        bullet.x - bullet.width/2, bullet.y - bullet.height/2, bullet.width, bullet.height,
        target.x, target.y, target.width, target.height
    )
end

function BulletSystem:spawnBullet(bullet_type, player_pos)
    local bullet = {
        x = player_pos.x,
        y = player_pos.y,
        width = 4,
        height = 8,
        vy = -400,  -- Move upward
        damage = bullet_type.damage,
        color = bullet_type.color,
        special = bullet_type.special
    }
    
    table.insert(self.active_bullets, bullet)
end

function BulletSystem:draw()
    for _, bullet in ipairs(self.active_bullets) do
        love.graphics.setColor(bullet.color)
        love.graphics.rectangle('fill', bullet.x - bullet.width/2, bullet.y - bullet.height/2, 
            bullet.width, bullet.height)
    end
end

function BulletSystem:clear()
    self.active_bullets = {}
end

function BulletSystem:setGlobalMultipliers(fire_rate_mult, damage_mult)
    self.global_fire_rate_multiplier = fire_rate_mult
    self.global_damage_multiplier = damage_mult
end

function BulletSystem:getBulletCount()
    return #self.active_bullets
end

return BulletSystem