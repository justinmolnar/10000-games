local BaseGame = require('src.games.base_game')
local SpaceShooter = BaseGame:extend('SpaceShooter')

-- Constants for game settings
local PLAYER_SPEED = 200
local BULLET_SPEED = 400
local ENEMY_BASE_SPEED = 100
local FIRE_COOLDOWN = 0.2
local SPAWN_BASE_RATE = 1.0

function SpaceShooter:init(game_data)
    SpaceShooter.super.init(self, game_data)
    
    -- Game state
    self.player = {
        x = love.graphics.getWidth() / 2,
        y = love.graphics.getHeight() - 50,
        width = 30,
        height = 30,
        fire_cooldown = 0
    }
    
    self.enemies = {}
    self.player_bullets = {}
    self.enemy_bullets = {}
    
    -- Metrics
    self.kills = 0
    self.deaths = 0
    
    -- Apply difficulty scaling
    self.enemy_speed = ENEMY_BASE_SPEED * self.difficulty_modifiers.speed
    self.spawn_rate = SPAWN_BASE_RATE / self.difficulty_modifiers.count
    self.spawn_timer = 0
    self.can_shoot_back = self.difficulty_modifiers.complexity > 2
end

function SpaceShooter:update(dt)
    if self.completed then return end
    SpaceShooter.super.update(self, dt)
    
    -- Update player
    self:updatePlayer(dt)
    
    -- Update spawn timer
    self.spawn_timer = self.spawn_timer - dt
    if self.spawn_timer <= 0 then
        self:spawnEnemy()
        self.spawn_timer = self.spawn_rate
    end
    
    -- Update enemies
    self:updateEnemies(dt)
    
    -- Update bullets
    self:updateBullets(dt)
    
    -- Update metrics
    self.metrics.kills = self.kills
    self.metrics.deaths = self.deaths
end

function SpaceShooter:updatePlayer(dt)
    -- Move player
    if love.keyboard.isDown('left', 'a') then
        self.player.x = self.player.x - PLAYER_SPEED * dt
    end
    if love.keyboard.isDown('right', 'd') then
        self.player.x = self.player.x + PLAYER_SPEED * dt
    end
    
    -- Clamp to screen
    self.player.x = math.max(0, math.min(love.graphics.getWidth() - self.player.width, self.player.x))
    
    -- Update fire cooldown
    if self.player.fire_cooldown > 0 then
        self.player.fire_cooldown = self.player.fire_cooldown - dt
    end
    
    -- Auto-fire
    if love.keyboard.isDown('space') and self.player.fire_cooldown <= 0 then
        self:playerShoot()
    end
end

function SpaceShooter:updateEnemies(dt)
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        
        -- Move enemy
        enemy.y = enemy.y + self.enemy_speed * dt
        if enemy.movement_pattern == 'zigzag' then
            enemy.x = enemy.x + math.sin(self.time_elapsed * 2) * self.enemy_speed * dt
        end
        
        -- Enemy shooting
        if self.can_shoot_back then
            enemy.shoot_timer = enemy.shoot_timer - dt
            if enemy.shoot_timer <= 0 then
                self:enemyShoot(enemy)
                enemy.shoot_timer = enemy.shoot_rate
            end
        end
        
        -- Remove if offscreen
        if enemy.y > love.graphics.getHeight() + 20 then
            table.remove(self.enemies, i)
        end
    end
end

function SpaceShooter:updateBullets(dt)
    -- Update player bullets
    for i = #self.player_bullets, 1, -1 do
        local bullet = self.player_bullets[i]
        bullet.y = bullet.y - BULLET_SPEED * dt
        
        -- Check enemy collisions
        for j = #self.enemies, 1, -1 do
            local enemy = self.enemies[j]
            if self:checkCollision(bullet, enemy) then
                table.remove(self.player_bullets, i)
                table.remove(self.enemies, j)
                self.kills = self.kills + 1
                break
            end
        end
        
        -- Remove if offscreen
        if bullet.y < -10 then
            table.remove(self.player_bullets, i)
        end
    end
    
    -- Update enemy bullets
    for i = #self.enemy_bullets, 1, -1 do
        local bullet = self.enemy_bullets[i]
        bullet.y = bullet.y + BULLET_SPEED * dt
        
        -- Check player collision
        if self:checkCollision(bullet, self.player) then
            table.remove(self.enemy_bullets, i)
            self.deaths = self.deaths + 1
            -- Game over if too many deaths
            if self.deaths >= 5 then
                self:onComplete()
            end
        end
        
        -- Remove if offscreen
        if bullet.y > love.graphics.getHeight() + 10 then
            table.remove(self.enemy_bullets, i)
        end
    end
end

function SpaceShooter:draw()
    -- Draw player
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle('fill', self.player.x, self.player.y, self.player.width, self.player.height)
    
    -- Draw enemies
    love.graphics.setColor(1, 0, 0)
    for _, enemy in ipairs(self.enemies) do
        love.graphics.rectangle('fill', enemy.x, enemy.y, enemy.width, enemy.height)
    end
    
    -- Draw player bullets
    love.graphics.setColor(0, 1, 1)
    for _, bullet in ipairs(self.player_bullets) do
        love.graphics.rectangle('fill', bullet.x, bullet.y, bullet.width, bullet.height)
    end
    
    -- Draw enemy bullets
    love.graphics.setColor(1, 1, 0)
    for _, bullet in ipairs(self.enemy_bullets) do
        love.graphics.rectangle('fill', bullet.x, bullet.y, bullet.width, bullet.height)
    end
    
    -- Draw HUD
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Kills: " .. self.kills, 10, 10)
    love.graphics.print("Deaths: " .. self.deaths, 10, 30)
end

function SpaceShooter:playerShoot()
    table.insert(self.player_bullets, {
        x = self.player.x + self.player.width/2 - 2,
        y = self.player.y,
        width = 4,
        height = 8
    })
    self.player.fire_cooldown = FIRE_COOLDOWN
end

function SpaceShooter:enemyShoot(enemy)
    table.insert(self.enemy_bullets, {
        x = enemy.x + enemy.width/2 - 2,
        y = enemy.y + enemy.height,
        width = 4,
        height = 8
    })
end

function SpaceShooter:spawnEnemy()
    -- Different patterns based on difficulty
    local movement = 'straight'
    if self.difficulty_modifiers.complexity >= 2 then
        movement = math.random() > 0.5 and 'zigzag' or 'straight'
    end
    
    local enemy = {
        x = math.random(0, love.graphics.getWidth() - 30),
        y = -30,
        width = 30,
        height = 30,
        movement_pattern = movement,
        shoot_timer = math.random(1, 3),
        shoot_rate = 3 - math.min(2, self.difficulty_modifiers.complexity)
    }
    
    table.insert(self.enemies, enemy)
end

function SpaceShooter:checkCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

function SpaceShooter:checkComplete()
    -- Complete if player died too many times or got enough kills
    return self.deaths >= 5 or self.kills >= 20 * self.difficulty_modifiers.complexity
end

return SpaceShooter