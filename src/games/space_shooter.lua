local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local Collision = require('src.utils.collision') 
local SpaceShooterView = require('src.games.views.space_shooter_view')
local SpaceShooter = BaseGame:extend('SpaceShooter')

-- Config-driven defaults with safe fallbacks
local SCfg = (Config and Config.games and Config.games.space_shooter) or {}
local PLAYER_WIDTH = (SCfg.player and SCfg.player.width) or 30
local PLAYER_HEIGHT = (SCfg.player and SCfg.player.height) or 30
local PLAYER_SPEED = (SCfg.player and SCfg.player.speed) or 200
local PLAYER_START_Y_OFFSET = (SCfg.player and SCfg.player.start_y_offset) or 50
local PLAYER_MAX_DEATHS_BASE = (SCfg.player and SCfg.player.max_deaths_base) or 5

local BULLET_WIDTH = (SCfg.bullet and SCfg.bullet.width) or 4
local BULLET_HEIGHT = (SCfg.bullet and SCfg.bullet.height) or 8
local BULLET_SPEED = (SCfg.bullet and SCfg.bullet.speed) or 400
local FIRE_COOLDOWN = (SCfg.player and SCfg.player.fire_cooldown) or 0.2

local ENEMY_WIDTH = (SCfg.enemy and SCfg.enemy.width) or 30
local ENEMY_HEIGHT = (SCfg.enemy and SCfg.enemy.height) or 30
local ENEMY_BASE_SPEED = (SCfg.enemy and SCfg.enemy.base_speed) or 100
local ENEMY_START_Y_OFFSET = (SCfg.enemy and SCfg.enemy.start_y_offset) or -30
local ENEMY_BASE_SHOOT_RATE_MIN = (SCfg.enemy and SCfg.enemy.base_shoot_rate_min) or 1.0
local ENEMY_BASE_SHOOT_RATE_MAX = (SCfg.enemy and SCfg.enemy.base_shoot_rate_max) or 3.0
local ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR = (SCfg.enemy and SCfg.enemy.shoot_rate_complexity_factor) or 0.5

local SPAWN_BASE_RATE = (SCfg.spawn and SCfg.spawn.base_rate) or 1.0
local BASE_TARGET_KILLS = (SCfg.goals and SCfg.goals.base_target_kills) or 20
local ZIGZAG_FREQUENCY = (SCfg.movement and SCfg.movement.zigzag_frequency) or 2

function SpaceShooter:init(game_data, cheats)
    SpaceShooter.super.init(self, game_data, cheats)
    -- Optional DI container passed by MinigameState
    self.di = select(3, ...)
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.space_shooter) or SCfg

    -- Override file-scope constants with DI values when present
    PLAYER_WIDTH = (runtimeCfg.player and runtimeCfg.player.width) or PLAYER_WIDTH
    PLAYER_HEIGHT = (runtimeCfg.player and runtimeCfg.player.height) or PLAYER_HEIGHT
    PLAYER_SPEED = (runtimeCfg.player and runtimeCfg.player.speed) or PLAYER_SPEED
    PLAYER_START_Y_OFFSET = (runtimeCfg.player and runtimeCfg.player.start_y_offset) or PLAYER_START_Y_OFFSET
    PLAYER_MAX_DEATHS_BASE = (runtimeCfg.player and runtimeCfg.player.max_deaths_base) or PLAYER_MAX_DEATHS_BASE

    BULLET_WIDTH = (runtimeCfg.bullet and runtimeCfg.bullet.width) or BULLET_WIDTH
    BULLET_HEIGHT = (runtimeCfg.bullet and runtimeCfg.bullet.height) or BULLET_HEIGHT
    BULLET_SPEED = (runtimeCfg.bullet and runtimeCfg.bullet.speed) or BULLET_SPEED
    FIRE_COOLDOWN = (runtimeCfg.player and runtimeCfg.player.fire_cooldown) or FIRE_COOLDOWN

    ENEMY_WIDTH = (runtimeCfg.enemy and runtimeCfg.enemy.width) or ENEMY_WIDTH
    ENEMY_HEIGHT = (runtimeCfg.enemy and runtimeCfg.enemy.height) or ENEMY_HEIGHT
    ENEMY_BASE_SPEED = (runtimeCfg.enemy and runtimeCfg.enemy.base_speed) or ENEMY_BASE_SPEED
    ENEMY_START_Y_OFFSET = (runtimeCfg.enemy and runtimeCfg.enemy.start_y_offset) or ENEMY_START_Y_OFFSET
    ENEMY_BASE_SHOOT_RATE_MIN = (runtimeCfg.enemy and runtimeCfg.enemy.base_shoot_rate_min) or ENEMY_BASE_SHOOT_RATE_MIN
    ENEMY_BASE_SHOOT_RATE_MAX = (runtimeCfg.enemy and runtimeCfg.enemy.base_shoot_rate_max) or ENEMY_BASE_SHOOT_RATE_MAX
    ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR = (runtimeCfg.enemy and runtimeCfg.enemy.shoot_rate_complexity_factor) or ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR

    SPAWN_BASE_RATE = (runtimeCfg.spawn and runtimeCfg.spawn.base_rate) or SPAWN_BASE_RATE
    BASE_TARGET_KILLS = (runtimeCfg.goals and runtimeCfg.goals.base_target_kills) or BASE_TARGET_KILLS
    ZIGZAG_FREQUENCY = (runtimeCfg.movement and runtimeCfg.movement.zigzag_frequency) or ZIGZAG_FREQUENCY
    
    local speed_modifier = self.cheats.speed_modifier or 1.0 
    local advantage_modifier = self.cheats.advantage_modifier or {}
    local extra_deaths = advantage_modifier.deaths or 0
    
    self.PLAYER_MAX_DEATHS = PLAYER_MAX_DEATHS_BASE + extra_deaths 

    self.game_width = (SCfg.arena and SCfg.arena.width) or 800
    self.game_height = (SCfg.arena and SCfg.arena.height) or 600

    self.player = {
        x = self.game_width / 2,
        y = self.game_height - PLAYER_START_Y_OFFSET,
        width = PLAYER_WIDTH,
        height = PLAYER_HEIGHT,
        fire_cooldown = 0
    }

    self.enemies = {}
    self.player_bullets = {}
    self.enemy_bullets = {}

    self.metrics.kills = 0
    self.metrics.deaths = 0

    self.enemy_speed = (ENEMY_BASE_SPEED * self.difficulty_modifiers.speed) * speed_modifier
    self.spawn_rate = SPAWN_BASE_RATE / self.difficulty_modifiers.count
    self.spawn_timer = 0
    self.can_shoot_back = self.difficulty_modifiers.complexity > 2

    self.target_kills = math.floor(BASE_TARGET_KILLS * self.difficulty_modifiers.complexity)
    
    self.view = SpaceShooterView:new(self) 
    print("[SpaceShooter:init] Initialized with default game dimensions:", self.game_width, self.game_height)
end

function SpaceShooter:setPlayArea(width, height)
    self.game_width = width
    self.game_height = height
    
    -- Only update player position if player exists
    if self.player then
        self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
        self.player.y = self.game_height - PLAYER_START_Y_OFFSET
        print("[SpaceShooter] Play area updated to:", width, height)
    else
        print("[SpaceShooter] setPlayArea called before init completed")
    end
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
    self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
    if self.player.fire_cooldown > 0 then self.player.fire_cooldown = self.player.fire_cooldown - dt end
    if love.keyboard.isDown('space') and self.player.fire_cooldown <= 0 then self:playerShoot() end
end

function SpaceShooter:updateEnemies(dt)
     for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        if not enemy then goto continue_enemy_loop end

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

        if enemy.y > self.game_height + 20 then
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
            -- Let checkComplete handle game over
        end

        if bullet.y > self.game_height + BULLET_HEIGHT then table.remove(self.enemy_bullets, i) end
        ::next_enemy_bullet::
    end
end

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
        x = math.random(0, self.game_width - ENEMY_WIDTH), 
        y = ENEMY_START_Y_OFFSET,
        width = ENEMY_WIDTH, height = ENEMY_HEIGHT,
        movement_pattern = movement,
        shoot_timer = math.random() * (ENEMY_BASE_SHOOT_RATE_MAX - ENEMY_BASE_SHOOT_RATE_MIN) + ENEMY_BASE_SHOOT_RATE_MIN,
        shoot_rate = math.max(0.5, (ENEMY_BASE_SHOOT_RATE_MAX - self.difficulty_modifiers.complexity * ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR))
    }
    table.insert(self.enemies, enemy)
end

function SpaceShooter:checkCollision(a, b)
    if not a or not b then return false end
    return Collision.checkAABB(a.x, a.y, a.width or 0, a.height or 0, b.x, b.y, b.width or 0, b.height or 0)
end

function SpaceShooter:checkComplete()
    return self.metrics.deaths >= self.PLAYER_MAX_DEATHS or self.metrics.kills >= self.target_kills
end

function SpaceShooter:keypressed(key)
    return false
end

return SpaceShooter