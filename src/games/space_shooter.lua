local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local Collision = require('src.utils.collision') 
local SpaceShooterView = require('src.games.views.space_shooter_view')
local SpaceShooter = BaseGame:extend('SpaceShooter')

-- Enemy type definitions (Phase 1.4)
-- These define the behaviors that variants can compose from
SpaceShooter.ENEMY_TYPES = {
    basic = {
        name = "basic",
        movement_pattern = "straight",
        speed_multiplier = 1.0,
        shoot_rate_multiplier = 1.0,
        health = 1,
        description = "Standard enemy ship"
    },
    weaver = {
        name = "weaver",
        movement_pattern = "zigzag",
        speed_multiplier = 0.8,
        shoot_rate_multiplier = 1.2,
        health = 1,
        description = "Weaves through space while shooting"
    },
    bomber = {
        name = "bomber",
        movement_pattern = "straight",
        speed_multiplier = 0.6,
        shoot_rate_multiplier = 2.0,
        health = 2,
        description = "Slow but fires rapidly"
    },
    kamikaze = {
        name = "kamikaze",
        movement_pattern = "dive",
        speed_multiplier = 1.5,
        shoot_rate_multiplier = 0.0,
        health = 1,
        description = "Dives directly at player without shooting"
    }
}

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

function SpaceShooter:init(game_data, cheats, di, variant_override)
    SpaceShooter.super.init(self, game_data, cheats, di, variant_override)
    self.di = di
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.space_shooter) or SCfg

    -- Apply variant difficulty modifier (from Phase 1.1-1.2)
    local variant_difficulty = self.variant and self.variant.difficulty_modifier or 1.0

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

    -- Phase 2: Movement Type System
    self.movement_type = "default"
    if self.variant and self.variant.movement_type then
        self.movement_type = self.variant.movement_type
    end

    -- Phase 2: Movement parameters with three-tier fallback
    self.movement_speed = (runtimeCfg.player and runtimeCfg.player.speed) or PLAYER_SPEED
    if self.variant and self.variant.movement_speed ~= nil then
        self.movement_speed = self.variant.movement_speed
    end

    -- Asteroids mode physics
    self.rotation_speed = (runtimeCfg.player and runtimeCfg.player.rotation_speed) or 5.0
    if self.variant and self.variant.rotation_speed ~= nil then
        self.rotation_speed = self.variant.rotation_speed
    end

    self.accel_friction = (runtimeCfg.player and runtimeCfg.player.accel_friction) or 1.0
    if self.variant and self.variant.accel_friction ~= nil then
        self.accel_friction = self.variant.accel_friction
    end

    self.decel_friction = (runtimeCfg.player and runtimeCfg.player.decel_friction) or 1.0
    if self.variant and self.variant.decel_friction ~= nil then
        self.decel_friction = self.variant.decel_friction
    end

    -- Jump mode parameters (distance as % of screen width)
    self.jump_distance_percent = (runtimeCfg.player and runtimeCfg.player.jump_distance) or 0.08
    if self.variant and self.variant.jump_distance ~= nil then
        self.jump_distance_percent = self.variant.jump_distance
    end

    self.jump_cooldown = (runtimeCfg.player and runtimeCfg.player.jump_cooldown) or 0.5
    if self.variant and self.variant.jump_cooldown ~= nil then
        self.jump_cooldown = self.variant.jump_cooldown
    end

    self.jump_speed = (runtimeCfg.player and runtimeCfg.player.jump_speed) or 400
    if self.variant and self.variant.jump_speed ~= nil then
        self.jump_speed = self.variant.jump_speed
    end

    -- Phase 2: Lives system (already partially implemented, making explicit)
    local base_lives = PLAYER_MAX_DEATHS_BASE
    if self.variant and self.variant.lives_count ~= nil then
        base_lives = self.variant.lives_count
    end
    self.PLAYER_MAX_DEATHS = base_lives + extra_deaths

    -- Phase 2: Shield system
    self.shield_enabled = (runtimeCfg.shield and runtimeCfg.shield.enabled) or false
    if self.variant and self.variant.shield ~= nil then
        self.shield_enabled = self.variant.shield
    end

    self.shield_regen_time = (runtimeCfg.shield and runtimeCfg.shield.regen_time) or 5.0
    if self.variant and self.variant.shield_regen_time ~= nil then
        self.shield_regen_time = self.variant.shield_regen_time
    end

    self.shield_max_hits = (runtimeCfg.shield and runtimeCfg.shield.max_hits) or 1
    if self.variant and self.variant.shield_hits ~= nil then
        self.shield_max_hits = self.variant.shield_hits
    end 

    self.game_width = (SCfg.arena and SCfg.arena.width) or 800
    self.game_height = (SCfg.arena and SCfg.arena.height) or 600

    self.player = {
        x = self.game_width / 2,
        y = self.game_height - PLAYER_START_Y_OFFSET,
        width = PLAYER_WIDTH,
        height = PLAYER_HEIGHT,
        fire_cooldown = 0
    }

    -- Phase 2: Initialize movement-specific state
    if self.movement_type == "asteroids" then
        self.player.angle = 0  -- Sprite faces UP, so 0 = up, 90 = right, 180 = down, 270 = left
        self.player.vx = 0
        self.player.vy = 0
    elseif self.movement_type == "jump" then
        self.player.jump_timer = 0
        self.player.is_jumping = false
        self.player.jump_progress = 0
        self.player.jump_start_x = 0
        self.player.jump_start_y = 0
        self.player.jump_target_x = 0
        self.player.jump_target_y = 0
    end

    -- Phase 2: Initialize shield state
    if self.shield_enabled then
        self.player.shield_active = true
        self.player.shield_regen_timer = 0
        self.player.shield_hits_remaining = self.shield_max_hits
    end

    self.enemies = {}
    self.player_bullets = {}
    self.enemy_bullets = {}

    self.metrics.kills = 0
    self.metrics.deaths = 0
    self.metrics.combo = 0  -- Phase 2: Track combo (kills without deaths)

    self.enemy_speed = ((ENEMY_BASE_SPEED * self.difficulty_modifiers.speed) * speed_modifier) * variant_difficulty
    self.spawn_rate = (SPAWN_BASE_RATE / self.difficulty_modifiers.count) / variant_difficulty
    self.spawn_timer = 0
    self.can_shoot_back = self.difficulty_modifiers.complexity > 2

    -- Target kills should NOT scale with clone index - stays constant for consistent game length
    self.target_kills = BASE_TARGET_KILLS
    if self.variant and self.variant.victory_limit ~= nil then
        self.target_kills = self.variant.victory_limit
    end

    -- Enemy composition from variant (Phase 1.3)
    -- NOTE: Enemy spawning will be implemented when assets are ready (Phase 2+)
    self.enemy_composition = {}
    if self.variant and self.variant.enemies then
        for _, enemy_def in ipairs(self.variant.enemies) do
            self.enemy_composition[enemy_def.type] = enemy_def.multiplier
        end
    end

    -- Audio/visual variant data (Phase 1.3)
    -- NOTE: Asset loading will be implemented in Phase 2-3
    -- Ship sprites will be loaded from variant.sprite_set
    -- e.g., "fighter_1" (blue squadron), "fighter_2" (gold squadron)

    self.view = SpaceShooterView:new(self, self.variant)
    print("[SpaceShooter:init] Initialized with default game dimensions:", self.game_width, self.game_height)
    print("[SpaceShooter:init] Variant:", self.variant and self.variant.name or "Default")

    -- Phase 2.3: Load sprite assets with graceful fallback
    self:loadAssets()
end

-- Phase 2.3: Asset loading with fallback
function SpaceShooter:loadAssets()
    self.sprites = {}

    if not self.variant or not self.variant.sprite_set then
        print("[SpaceShooter:loadAssets] No variant sprite_set, using fallback rendering")
        return
    end

    local game_type = "space_shooter"
    local base_path = "assets/sprites/games/" .. game_type .. "/" .. self.variant.sprite_set .. "/"

    local function tryLoad(filename, sprite_key)
        local filepath = base_path .. filename
        local success, result = pcall(function()
            return love.graphics.newImage(filepath)
        end)

        if success then
            self.sprites[sprite_key] = result
            print("[SpaceShooter:loadAssets] Loaded: " .. filepath)
        else
            print("[SpaceShooter:loadAssets] Missing: " .. filepath .. " (using fallback)")
        end
    end

    -- Load player ship sprite
    tryLoad("player.png", "player")

    -- Load enemy type sprites
    for enemy_type, _ in pairs(SpaceShooter.ENEMY_TYPES) do
        local filename = "enemy_" .. enemy_type .. ".png"
        local sprite_key = "enemy_" .. enemy_type
        tryLoad(filename, sprite_key)
    end

    -- Load bullet sprites
    tryLoad("bullet_player.png", "bullet_player")
    tryLoad("bullet_enemy.png", "bullet_enemy")

    -- Load power-up sprite
    tryLoad("power_up.png", "power_up")

    -- Load background
    tryLoad("background.png", "background")

    print(string.format("[SpaceShooter:loadAssets] Loaded %d sprites for variant: %s",
        self:countLoadedSprites(), self.variant.name or "Unknown"))

    -- Phase 3.3: Load audio - using BaseGame helper
    self:loadAudio()
end

function SpaceShooter:countLoadedSprites()
    local count = 0
    for _ in pairs(self.sprites) do
        count = count + 1
    end
    return count
end

function SpaceShooter:hasSprite(sprite_key)
    return self.sprites and self.sprites[sprite_key] ~= nil
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
    -- Phase 2: Movement type system
    if self.movement_type == "default" then
        -- Default: WASD free movement
        if self:isKeyDown('up', 'w') then self.player.y = self.player.y - self.movement_speed * dt end
        if self:isKeyDown('down', 's') then self.player.y = self.player.y + self.movement_speed * dt end
        if self:isKeyDown('left', 'a') then self.player.x = self.player.x - self.movement_speed * dt end
        if self:isKeyDown('right', 'd') then self.player.x = self.player.x + self.movement_speed * dt end

        -- Clamp to screen
        self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
        self.player.y = math.max(0, math.min(self.game_height - self.player.height, self.player.y))

    elseif self.movement_type == "rail" then
        -- Rail: Left/right only, vertical fixed
        if self:isKeyDown('left', 'a') then self.player.x = self.player.x - self.movement_speed * dt end
        if self:isKeyDown('right', 'd') then self.player.x = self.player.x + self.movement_speed * dt end

        -- Clamp horizontal only
        self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))

    elseif self.movement_type == "asteroids" then
        -- Asteroids: Rotate + thrust physics
        if self:isKeyDown('left', 'a') then
            self.player.angle = self.player.angle - self.rotation_speed * dt * 60
        end
        if self:isKeyDown('right', 'd') then
            self.player.angle = self.player.angle + self.rotation_speed * dt * 60
        end

        -- Thrust (sprite faces UP, angle 0 = UP, 90 = RIGHT, etc.)
        if self:isKeyDown('up', 'w') then
            -- Convert from "UP = 0" to radians (need to rotate coordinate system)
            -- Angle 0 = UP means we need sin for X (sideways) and -cos for Y (vertical)
            local rad = math.rad(self.player.angle)
            local thrust = self.movement_speed * 5 * dt  -- Thrust acceleration
            self.player.vx = self.player.vx + math.sin(rad) * thrust * self.accel_friction
            self.player.vy = self.player.vy + (-math.cos(rad)) * thrust * self.accel_friction
        end

        -- Apply deceleration
        self.player.vx = self.player.vx * (1.0 - (1.0 - self.decel_friction) * dt * 5)
        self.player.vy = self.player.vy * (1.0 - (1.0 - self.decel_friction) * dt * 5)

        -- Update position
        self.player.x = self.player.x + self.player.vx * dt
        self.player.y = self.player.y + self.player.vy * dt

        -- Clamp to bounds
        self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
        self.player.y = math.max(0, math.min(self.game_height - self.player.height, self.player.y))

    elseif self.movement_type == "jump" then
        -- Jump/Dash mode: Discrete dashes instead of continuous movement
        if self.player.jump_timer > 0 then
            self.player.jump_timer = self.player.jump_timer - dt
        end

        if not self.player.is_jumping and self.player.jump_timer <= 0 then
            local jump_dir = nil
            if self:isKeyDown('left', 'a') then jump_dir = 'left' end
            if self:isKeyDown('right', 'd') then jump_dir = 'right' end
            if self:isKeyDown('up', 'w') then jump_dir = 'up' end
            if self:isKeyDown('down', 's') then jump_dir = 'down' end

            if jump_dir then
                self:executeJump(jump_dir)
                self.player.jump_timer = self.jump_cooldown
            end
        end

        -- Update jump animation
        if self.player.is_jumping then
            local jump_distance = self.game_width * self.jump_distance_percent
            self.player.jump_progress = self.player.jump_progress + dt / (jump_distance / self.jump_speed)

            if self.player.jump_progress >= 1.0 then
                self.player.x = self.player.jump_target_x
                self.player.y = self.player.jump_target_y
                self.player.is_jumping = false
            else
                -- Lerp to target
                local t = self.player.jump_progress
                self.player.x = self.player.jump_start_x + (self.player.jump_target_x - self.player.jump_start_x) * t
                self.player.y = self.player.jump_start_y + (self.player.jump_target_y - self.player.jump_start_y) * t
            end
        end
    end

    -- Phase 2: Shield regeneration (regenerates ONE shield at a time)
    if self.shield_enabled and self.player.shield_hits_remaining < self.shield_max_hits then
        self.player.shield_regen_timer = self.player.shield_regen_timer + dt
        if self.player.shield_regen_timer >= self.shield_regen_time then
            self.player.shield_hits_remaining = self.player.shield_hits_remaining + 1
            self.player.shield_regen_timer = 0
            -- Reactivate shield if it was down
            if not self.player.shield_active then
                self.player.shield_active = true
            end
        end
    end

    -- Fire cooldown (all modes)
    if self.player.fire_cooldown > 0 then
        self.player.fire_cooldown = self.player.fire_cooldown - dt
    end

    -- Shooting (handled in all modes)
    if self:isKeyDown('space') and self.player.fire_cooldown <= 0 then
        self:playerShoot()
    end
end

function SpaceShooter:executeJump(direction)
    self.player.is_jumping = true
    self.player.jump_progress = 0
    self.player.jump_start_x = self.player.x
    self.player.jump_start_y = self.player.y

    -- Calculate jump distance as % of game window width
    local jump_distance = self.game_width * self.jump_distance_percent

    -- Calculate target based on direction
    local target_x = self.player.x
    local target_y = self.player.y

    if direction == 'left' then target_x = target_x - jump_distance end
    if direction == 'right' then target_x = target_x + jump_distance end
    if direction == 'up' then target_y = target_y - jump_distance end
    if direction == 'down' then target_y = target_y + jump_distance end

    -- Clamp to bounds
    target_x = math.max(0, math.min(self.game_width - self.player.width, target_x))
    target_y = math.max(0, math.min(self.game_height - self.player.height, target_y))

    self.player.jump_target_x = target_x
    self.player.jump_target_y = target_y
end

function SpaceShooter:updateEnemies(dt)
     for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        if not enemy then goto continue_enemy_loop end

        -- Phase 1.4: Apply speed multiplier for variant enemies
        local speed = self.enemy_speed
        if enemy.is_variant_enemy and enemy.speed_multiplier then
            speed = speed * enemy.speed_multiplier
        end

        if enemy.movement_pattern == 'zigzag' then
            enemy.y = enemy.y + speed * dt
            enemy.x = enemy.x + math.sin(self.time_elapsed * ZIGZAG_FREQUENCY) * speed * dt
        elseif enemy.movement_pattern == 'dive' then
            -- Phase 1.4: Kamikaze dive toward target
            -- Once at or past target Y, just continue downward to prevent getting stuck
            if enemy.y >= enemy.target_y then
                enemy.y = enemy.y + speed * dt
            else
                local dx = enemy.target_x - enemy.x
                local dy = enemy.target_y - enemy.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist > 0 then
                    enemy.x = enemy.x + (dx / dist) * speed * dt
                    enemy.y = enemy.y + (dy / dist) * speed * dt
                else
                    -- Reached target, continue downward
                    enemy.y = enemy.y + speed * dt
                end
            end
        else
            enemy.y = enemy.y + speed * dt
        end

        -- Check collision with player
        if self:checkCollision(enemy, self.player) then
            -- Phase 2: Check shield first
            if self.shield_enabled and self.player.shield_active then
                self.player.shield_hits_remaining = self.player.shield_hits_remaining - 1
                if self.player.shield_hits_remaining <= 0 then
                    self.player.shield_active = false
                    self.player.shield_regen_timer = 0
                end
                self:playSound("hit", 1.0)
            else
                -- No shield or shield is down, take damage
                self.metrics.deaths = self.metrics.deaths + 1
                self.metrics.combo = 0  -- Phase 2: Reset combo on death
                self:playSound("hit", 1.0)
            end
            -- Remove enemy on collision
            table.remove(self.enemies, i)
            goto continue_enemy_loop
        end

        if self.can_shoot_back then
            -- Phase 1.4: Don't shoot if shoot_rate_multiplier is 0 (kamikaze)
            local shoot_multiplier = enemy.shoot_rate_multiplier or 1.0
            if shoot_multiplier > 0 then
                enemy.shoot_timer = enemy.shoot_timer - dt
                if enemy.shoot_timer <= 0 then
                    self:enemyShoot(enemy)
                    enemy.shoot_timer = enemy.shoot_rate
                end
            end
        end

        -- Remove enemies that are fully off screen (bottom of enemy past bottom edge)
        if enemy.y + enemy.height/2 > self.game_height then
            table.remove(self.enemies, i)
        end
        ::continue_enemy_loop::
    end
end

function SpaceShooter:updateBullets(dt)
    for i = #self.player_bullets, 1, -1 do
        local bullet = self.player_bullets[i]
        if not bullet then goto next_player_bullet end

        -- Update bullet position (directional or straight up)
        if bullet.directional then
            bullet.x = bullet.x + bullet.vx * dt
            bullet.y = bullet.y + bullet.vy * dt
        else
            bullet.y = bullet.y - BULLET_SPEED * dt
        end

        for j = #self.enemies, 1, -1 do
            local enemy = self.enemies[j]
            if enemy and self:checkCollision(bullet, enemy) then
                table.remove(self.player_bullets, i)
                -- Phase 1.4: Handle health for variant enemies
                if enemy.is_variant_enemy and enemy.health then
                    enemy.health = enemy.health - 1
                    if enemy.health <= 0 then
                        table.remove(self.enemies, j)
                        self.metrics.kills = self.metrics.kills + 1
                        self.metrics.combo = self.metrics.combo + 1  -- Phase 2: Increment combo

                        -- Phase 3.3: Play enemy explode sound
                        self:playSound("enemy_explode", 1.0)
                    end
                else
                    table.remove(self.enemies, j)
                    self.metrics.kills = self.metrics.kills + 1
                    self.metrics.combo = self.metrics.combo + 1  -- Phase 2: Increment combo

                    -- Phase 3.3: Play enemy explode sound
                    self:playSound("enemy_explode", 1.0)
                end
                goto next_player_bullet
            end
        end

        -- Remove bullets that go off screen (any direction)
        if bullet.directional then
            if bullet.x < -BULLET_WIDTH or bullet.x > self.game_width or
               bullet.y < -BULLET_HEIGHT or bullet.y > self.game_height then
                table.remove(self.player_bullets, i)
            end
        else
            if bullet.y < -BULLET_HEIGHT then
                table.remove(self.player_bullets, i)
            end
        end
        ::next_player_bullet::
    end

    for i = #self.enemy_bullets, 1, -1 do
        local bullet = self.enemy_bullets[i]
        if not bullet then goto next_enemy_bullet end
        bullet.y = bullet.y + BULLET_SPEED * dt

        if self:checkCollision(bullet, self.player) then
            table.remove(self.enemy_bullets, i)

            -- Phase 2: Check shield first
            if self.shield_enabled and self.player.shield_active then
                self.player.shield_hits_remaining = self.player.shield_hits_remaining - 1
                if self.player.shield_hits_remaining <= 0 then
                    self.player.shield_active = false
                    self.player.shield_regen_timer = 0
                end
                -- Play shield hit sound (or regular hit)
                self:playSound("hit", 1.0)
            else
                -- No shield or shield is down, take damage
                self.metrics.deaths = self.metrics.deaths + 1
                self.metrics.combo = 0  -- Phase 2: Reset combo on death

                -- Phase 3.3: Play hit sound
                self:playSound("hit", 1.0)
                -- Let checkComplete handle game over
            end
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
    local bullet = {
        width = BULLET_WIDTH,
        height = BULLET_HEIGHT
    }

    -- For asteroid mode, shoot in direction player is facing from front of ship
    if self.movement_type == "asteroids" then
        local rad = math.rad(self.player.angle)
        -- Offset bullet spawn to front of ship (angle 0 = UP, so front is -height/2 in Y)
        local offset_distance = self.player.height / 2
        local offset_x = math.sin(rad) * offset_distance
        local offset_y = -math.cos(rad) * offset_distance

        bullet.x = self.player.x + offset_x - BULLET_WIDTH/2
        bullet.y = self.player.y + offset_y - BULLET_HEIGHT/2
        bullet.vx = math.sin(rad) * 400  -- Bullet speed (angle 0 = UP)
        bullet.vy = (-math.cos(rad)) * 400
        bullet.directional = true
    else
        -- All other modes: shoot straight up from top-center of sprite
        bullet.x = self.player.x - BULLET_WIDTH/2
        bullet.y = self.player.y - self.player.height/2
    end

    table.insert(self.player_bullets, bullet)
    self.player.fire_cooldown = FIRE_COOLDOWN

    -- Phase 3.3: Play shoot sound
    self:playSound("shoot", 0.6)
end

function SpaceShooter:enemyShoot(enemy)
    table.insert(self.enemy_bullets, {
        x = enemy.x + enemy.width/2 - BULLET_WIDTH/2,
        y = enemy.y + enemy.height,
        width = BULLET_WIDTH, height = BULLET_HEIGHT
    })
end

function SpaceShooter:spawnEnemy()
    -- Phase 1.4: Check if variant has enemy composition
    if self:hasVariantEnemies() and math.random() < 0.5 then
        -- 50% chance to spawn variant-specific enemy
        return self:spawnVariantEnemy()
    end

    -- Default enemy spawning (for base game)
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
        shoot_rate = math.max(0.5, (ENEMY_BASE_SHOOT_RATE_MAX - self.difficulty_modifiers.complexity * ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR)),
        health = 1
    }
    table.insert(self.enemies, enemy)
end

-- Phase 1.4: Check if variant has enemies defined
function SpaceShooter:hasVariantEnemies()
    return self.enemy_composition and next(self.enemy_composition) ~= nil
end

-- Phase 1.4: Spawn an enemy from variant composition
function SpaceShooter:spawnVariantEnemy()
    if not self:hasVariantEnemies() then
        return self:spawnEnemy()
    end

    -- Pick a random enemy type from composition
    local enemy_types = {}
    local total_weight = 0
    for enemy_type, multiplier in pairs(self.enemy_composition) do
        table.insert(enemy_types, {type = enemy_type, weight = multiplier})
        total_weight = total_weight + multiplier
    end

    local r = math.random() * total_weight
    local chosen_type = enemy_types[1].type -- fallback
    for _, entry in ipairs(enemy_types) do
        r = r - entry.weight
        if r <= 0 then
            chosen_type = entry.type
            break
        end
    end

    local enemy_def = self.ENEMY_TYPES[chosen_type]
    if not enemy_def then
        -- Fallback to default spawning
        return self:spawnEnemy()
    end

    -- Create enemy based on definition
    local enemy = {
        x = math.random(0, self.game_width - ENEMY_WIDTH),
        y = ENEMY_START_Y_OFFSET,
        width = ENEMY_WIDTH,
        height = ENEMY_HEIGHT,
        movement_pattern = enemy_def.movement_pattern,
        enemy_type = enemy_def.name,
        is_variant_enemy = true,
        health = enemy_def.health or 1,
        max_health = enemy_def.health or 1,
        speed_multiplier = enemy_def.speed_multiplier or 1.0,
        shoot_rate_multiplier = enemy_def.shoot_rate_multiplier or 1.0
    }

    -- Set shoot timer and rate
    local base_rate = math.random() * (ENEMY_BASE_SHOOT_RATE_MAX - ENEMY_BASE_SHOOT_RATE_MIN) + ENEMY_BASE_SHOOT_RATE_MIN
    enemy.shoot_timer = base_rate
    enemy.shoot_rate = (math.max(0.5, (ENEMY_BASE_SHOOT_RATE_MAX - self.difficulty_modifiers.complexity * ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR))) / enemy.shoot_rate_multiplier

    -- Special initialization for dive pattern (kamikaze)
    if enemy.movement_pattern == 'dive' then
        enemy.target_x = self.player.x
        enemy.target_y = self.player.y
    end

    table.insert(self.enemies, enemy)
end

function SpaceShooter:checkCollision(a, b)
    if not a or not b then return false end
    return Collision.checkAABB(a.x, a.y, a.width or 0, a.height or 0, b.x, b.y, b.width or 0, b.height or 0)
end

function SpaceShooter:checkComplete()
    return self.metrics.deaths >= self.PLAYER_MAX_DEATHS or self.metrics.kills >= self.target_kills
end

-- Phase 3.3: Override onComplete to play success sound and stop music
function SpaceShooter:onComplete()
    -- Determine if win (reached target kills) or loss (max deaths)
    local is_win = self.metrics.kills >= self.target_kills

    if is_win then
        self:playSound("success", 1.0)
    else
        -- Lost due to too many deaths
        self:playSound("death", 1.0)
    end

    -- Stop music
    self:stopMusic()

    -- Call parent onComplete
    SpaceShooter.super.onComplete(self)
end

function SpaceShooter:keypressed(key)
    -- Call parent to handle virtual key tracking for demo playback
    SpaceShooter.super.keypressed(self, key)
    return false
end

return SpaceShooter