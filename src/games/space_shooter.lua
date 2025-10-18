local BaseGame = require('src/games/base_game')
local Collision = require('src/utils/collision') 
local SpaceShooterView = require('src/games.views.space_shooter_view') -- Added view require
local SpaceShooter = BaseGame:extend('SpaceShooter')

-- Constants remain here as they define game logic/balance
local PLAYER_WIDTH = 30
local PLAYER_HEIGHT = 30
local PLAYER_SPEED = 200
local PLAYER_START_Y_OFFSET = 50
local PLAYER_MAX_DEATHS_BASE = 5 -- Renamed to BASE

local BULLET_WIDTH = 4
local BULLET_HEIGHT = 8
local BULLET_SPEED = 400
local FIRE_COOLDOWN = 0.2 

local ENEMY_WIDTH = 30
local ENEMY_HEIGHT = 30
local ENEMY_BASE_SPEED = 100
local ENEMY_START_Y = -30
local ENEMY_OFFSCREEN_Y = love.graphics.getHeight() + 20
local ENEMY_BASE_SHOOT_RATE_MIN = 1.0
local ENEMY_BASE_SHOOT_RATE_MAX = 3.0
local ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR = 0.5 

local SPAWN_BASE_RATE = 1.0 
local BASE_TARGET_KILLS = 20 
local ZIGZAG_FREQUENCY = 2 

function SpaceShooter:init(game_data, cheats)
    SpaceShooter.super.init(self, game_data, cheats) -- Pass cheats to base
    
    -- Apply Cheats
    -- self.cheats.speed_modifier is now a value like 0.85 (for 15% slow)
    local speed_modifier = self.cheats.speed_modifier or 1.0 
    
    -- self.cheats.advantage_modifier is now a table like { deaths = 3 }
    local advantage_modifier = self.cheats.advantage_modifier or {}
    local extra_deaths = advantage_modifier.deaths or 0
    
    -- Make constant accessible to view via self, applying cheat
    self.PLAYER_MAX_DEATHS = PLAYER_MAX_DEATHS_BASE + extra_deaths 

    self.player = {
        x = love.graphics.getWidth() / 2,
        y = love.graphics.getHeight() - PLAYER_START_Y_OFFSET,
        width = PLAYER_WIDTH,
        height = PLAYER_HEIGHT,
        fire_cooldown = 0
    }

    self.enemies = {}
    self.player_bullets = {}
    self.enemy_bullets = {}

    self.metrics.kills = 0
    self.metrics.deaths = 0

    -- Apply speed cheat to enemy speed
    self.enemy_speed = (ENEMY_BASE_SPEED * self.difficulty_modifiers.speed) * speed_modifier
    self.spawn_rate = SPAWN_BASE_RATE / self.difficulty_modifiers.count
    self.spawn_timer = 0
    self.can_shoot_back = self.difficulty_modifiers.complexity > 2

    self.target_kills = math.floor(BASE_TARGET_KILLS * self.difficulty_modifiers.complexity)
    
    -- Create the view instance
    self.view = SpaceShooterView:new(self) 
end

function SpaceShooter:updateGameLogic(dt)
    self:updatePlayer(dt)
    self.spawn_timer = self.spawn_timer - dt
    if self.spawn_timer <= 0 then
        self:spawnEnemy()
        self.spawn_timer = self.spawn_rate
    end
    self:updateEnemies(dt)
    self:updateBullets(dt)
end


function SpaceShooter:updatePlayer(dt)
    if love.keyboard.isDown('left', 'a') then self.player.x = self.player.x - PLAYER_SPEED * dt end
    if love.keyboard.isDown('right', 'd') then self.player.x = self.player.x + PLAYER_SPEED * dt end
    self.player.x = math.max(0, math.min(love.graphics.getWidth() - self.player.width, self.player.x))
    if self.player.fire_cooldown > 0 then self.player.fire_cooldown = self.player.fire_cooldown - dt end
    if love.keyboard.isDown('space') and self.player.fire_cooldown <= 0 then self:playerShoot() end
end

function SpaceShooter:updateEnemies(dt)
     for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        if not enemy then goto continue_enemy_loop end -- Safety check

        enemy.y = enemy.y + self.enemy_speed * dt
        if enemy.movement_pattern == 'zigzag' then
            enemy.x = enemy.x + math.sin(self.time_elapsed * ZIGZAG_FREQUENCY) * self.enemy_speed * dt
        end

        if self.can_shoot_back then
            enemy.shoot_timer = enemy.shoot_timer - dt
            if enemy.shoot_timer <= 0 then
                self:enemyShoot(enemy)
                enemy.shoot_timer = enemy.shoot_rate
            end
        end

        if enemy.y > ENEMY_OFFSCREEN_Y then
            table.remove(self.enemies, i)
        end
        ::continue_enemy_loop::
    end
end


function SpaceShooter:updateBullets(dt)
    for i = #self.player_bullets, 1, -1 do
        local bullet = self.player_bullets[i]
        if not bullet then goto next_player_bullet end
        bullet.y = bullet.y - BULLET_SPEED * dt

        for j = #self.enemies, 1, -1 do
            local enemy = self.enemies[j]
            if enemy and self:checkCollision(bullet, enemy) then
                table.remove(self.player_bullets, i)
                table.remove(self.enemies, j)
                self.metrics.kills = self.metrics.kills + 1
                goto next_player_bullet
            end
        end

        if bullet.y < -BULLET_HEIGHT then table.remove(self.player_bullets, i) end
        ::next_player_bullet::
    end

    for i = #self.enemy_bullets, 1, -1 do
        local bullet = self.enemy_bullets[i]
         if not bullet then goto next_enemy_bullet end
        bullet.y = bullet.y + BULLET_SPEED * dt

        if self:checkCollision(bullet, self.player) then
            table.remove(self.enemy_bullets, i)
            self.metrics.deaths = self.metrics.deaths + 1
            if self.metrics.deaths >= self.PLAYER_MAX_DEATHS then
                self:onComplete()
                return
            end
             goto next_enemy_bullet
        end

        if bullet.y > love.graphics.getHeight() + BULLET_HEIGHT then table.remove(self.enemy_bullets, i) end
        ::next_enemy_bullet::
    end
end

-- Draw method now delegates to the view
function SpaceShooter:draw()
    if self.view then
        self.view:draw()
    else
         love.graphics.print("Error: View not loaded!", 10, 100)
    end
end


function SpaceShooter:playerShoot()
    table.insert(self.player_bullets, {
        x = self.player.x + self.player.width/2 - BULLET_WIDTH/2,
        y = self.player.y,
        width = BULLET_WIDTH, height = BULLET_HEIGHT
    })
    self.player.fire_cooldown = FIRE_COOLDOWN
end

function SpaceShooter:enemyShoot(enemy)
    table.insert(self.enemy_bullets, {
        x = enemy.x + enemy.width/2 - BULLET_WIDTH/2,
        y = enemy.y + enemy.height,
        width = BULLET_WIDTH, height = BULLET_HEIGHT
    })
end

function SpaceShooter:spawnEnemy()
    local movement = 'straight'
    if self.difficulty_modifiers.complexity >= 2 then
        movement = math.random() > 0.5 and 'zigzag' or 'straight'
    end
    local enemy = {
        x = math.random(0, love.graphics.getWidth() - ENEMY_WIDTH), y = ENEMY_START_Y,
        width = ENEMY_WIDTH, height = ENEMY_HEIGHT,
        movement_pattern = movement,
        shoot_timer = math.random() * (ENEMY_BASE_SHOOT_RATE_MAX - ENEMY_BASE_SHOOT_RATE_MIN) + ENEMY_BASE_SHOOT_RATE_MIN,
        shoot_rate = math.max(0.5, (ENEMY_BASE_SHOOT_RATE_MAX - self.difficulty_modifiers.complexity * ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR))
    }
    table.insert(self.enemies, enemy)
end

function SpaceShooter:checkCollision(a, b)
    -- Check for nil objects before accessing properties
    if not a or not b then return false end
    -- Assuming x,y is top-left
    return Collision.checkAABB(a.x, a.y, a.width or 0, a.height or 0, b.x, b.y, b.width or 0, b.height or 0)
end


function SpaceShooter:checkComplete()
    return self.metrics.deaths >= self.PLAYER_MAX_DEATHS or self.metrics.kills >= self.target_kills
end

function SpaceShooter:keypressed(key)
    return false
end

return SpaceShooter