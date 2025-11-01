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

    -- Phase 3: Weapon System - Fire Mode
    self.fire_mode = (runtimeCfg.weapon and runtimeCfg.weapon.fire_mode) or "manual"
    if self.variant and self.variant.fire_mode then
        self.fire_mode = self.variant.fire_mode
    end

    self.fire_rate = (runtimeCfg.weapon and runtimeCfg.weapon.fire_rate) or 1.0
    if self.variant and self.variant.fire_rate ~= nil then
        self.fire_rate = self.variant.fire_rate
    end

    self.burst_count = (runtimeCfg.weapon and runtimeCfg.weapon.burst_count) or 3
    if self.variant and self.variant.burst_count ~= nil then
        self.burst_count = self.variant.burst_count
    end

    self.burst_delay = (runtimeCfg.weapon and runtimeCfg.weapon.burst_delay) or 0.1
    if self.variant and self.variant.burst_delay ~= nil then
        self.burst_delay = self.variant.burst_delay
    end

    self.charge_time = (runtimeCfg.weapon and runtimeCfg.weapon.charge_time) or 1.0
    if self.variant and self.variant.charge_time ~= nil then
        self.charge_time = self.variant.charge_time
    end

    -- Phase 3: Bullet Pattern
    self.bullet_pattern = (runtimeCfg.weapon and runtimeCfg.weapon.pattern) or "single"
    if self.variant and self.variant.bullet_pattern then
        self.bullet_pattern = self.variant.bullet_pattern
    end

    self.spread_angle = (runtimeCfg.weapon and runtimeCfg.weapon.spread_angle) or 30
    if self.variant and self.variant.spread_angle ~= nil then
        self.spread_angle = self.variant.spread_angle
    end

    -- Phase 3: Bullet Arc and Count
    self.bullet_arc = (runtimeCfg.weapon and runtimeCfg.weapon.bullet_arc) or 30
    if self.variant and self.variant.bullet_arc ~= nil then
        self.bullet_arc = self.variant.bullet_arc
    end

    self.bullets_per_shot = (runtimeCfg.weapon and runtimeCfg.weapon.bullets_per_shot) or 1
    if self.variant and self.variant.bullets_per_shot ~= nil then
        self.bullets_per_shot = self.variant.bullets_per_shot
    end

    -- Phase 3: Bullet Behavior
    self.bullet_speed = (runtimeCfg.bullet and runtimeCfg.bullet.speed) or BULLET_SPEED
    if self.variant and self.variant.bullet_speed ~= nil then
        self.bullet_speed = self.variant.bullet_speed
    end

    self.bullet_homing = (runtimeCfg.bullet and runtimeCfg.bullet.homing) or false
    if self.variant and self.variant.bullet_homing ~= nil then
        self.bullet_homing = self.variant.bullet_homing
    end

    self.homing_strength = (runtimeCfg.bullet and runtimeCfg.bullet.homing_strength) or 0.0
    if self.variant and self.variant.homing_strength ~= nil then
        self.homing_strength = self.variant.homing_strength
    end

    self.bullet_piercing = (runtimeCfg.bullet and runtimeCfg.bullet.piercing) or false
    if self.variant and self.variant.bullet_piercing ~= nil then
        self.bullet_piercing = self.variant.bullet_piercing
    end

    -- Phase 2: Bullet Gravity
    self.bullet_gravity = (runtimeCfg.bullet and runtimeCfg.bullet.gravity) or 0
    if self.variant and self.variant.bullet_gravity ~= nil then
        self.bullet_gravity = self.variant.bullet_gravity
    end

    -- Phase 4: Ammo System
    self.ammo_enabled = (runtimeCfg.weapon and runtimeCfg.weapon.ammo_enabled) or false
    if self.variant and self.variant.ammo_enabled ~= nil then
        self.ammo_enabled = self.variant.ammo_enabled
    end

    self.ammo_capacity = (runtimeCfg.weapon and runtimeCfg.weapon.ammo_capacity) or 50
    if self.variant and self.variant.ammo_capacity ~= nil then
        self.ammo_capacity = self.variant.ammo_capacity
    end

    self.ammo_reload_time = (runtimeCfg.weapon and runtimeCfg.weapon.ammo_reload_time) or 2.0
    if self.variant and self.variant.ammo_reload_time ~= nil then
        self.ammo_reload_time = self.variant.ammo_reload_time
    end

    -- Phase 4: Overheat System
    self.overheat_enabled = (runtimeCfg.weapon and runtimeCfg.weapon.overheat_enabled) or false
    if self.variant and self.variant.overheat_enabled ~= nil then
        self.overheat_enabled = self.variant.overheat_enabled
    end

    self.overheat_threshold = (runtimeCfg.weapon and runtimeCfg.weapon.overheat_threshold) or 10
    if self.variant and self.variant.overheat_threshold ~= nil then
        self.overheat_threshold = self.variant.overheat_threshold
    end

    self.overheat_cooldown = (runtimeCfg.weapon and runtimeCfg.weapon.overheat_cooldown) or 3.0
    if self.variant and self.variant.overheat_cooldown ~= nil then
        self.overheat_cooldown = self.variant.overheat_cooldown
    end

    self.overheat_heat_dissipation = (runtimeCfg.weapon and runtimeCfg.weapon.overheat_heat_dissipation) or 2.0
    if self.variant and self.variant.overheat_heat_dissipation ~= nil then
        self.overheat_heat_dissipation = self.variant.overheat_heat_dissipation
    end

    self.game_width = (SCfg.arena and SCfg.arena.width) or 800
    self.game_height = (SCfg.arena and SCfg.arena.height) or 600

    self.player = {
        x = self.game_width / 2,
        y = self.game_height - PLAYER_START_Y_OFFSET,
        width = PLAYER_WIDTH,
        height = PLAYER_HEIGHT,
        fire_cooldown = 0,
        -- Phase 3: Weapon state
        auto_fire_timer = 0,
        charge_progress = 0,
        is_charging = false,
        burst_remaining = 0,
        burst_timer = 0,
        -- Phase 4: Ammo & Overheat state
        ammo = self.ammo_capacity,
        reload_timer = 0,
        is_reloading = false,
        heat = 0,
        is_overheated = false,
        overheat_timer = 0
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
    local fallback_sprite_set = "fighter_1"  -- Config default
    local fallback_path = "assets/sprites/games/" .. game_type .. "/" .. fallback_sprite_set .. "/"

    local function tryLoad(filename, sprite_key)
        -- Try variant sprite_set first
        local filepath = base_path .. filename
        local success, result = pcall(function()
            return love.graphics.newImage(filepath)
        end)

        if success then
            self.sprites[sprite_key] = result
            print("[SpaceShooter:loadAssets] Loaded: " .. filepath)
            return
        end

        -- Fall back to default sprite_set (fighter_1)
        if self.variant.sprite_set ~= fallback_sprite_set then
            local fallback_filepath = fallback_path .. filename
            local fallback_success, fallback_result = pcall(function()
                return love.graphics.newImage(fallback_filepath)
            end)

            if fallback_success then
                self.sprites[sprite_key] = fallback_result
                print("[SpaceShooter:loadAssets] Loaded fallback: " .. fallback_filepath)
                return
            end
        end

        print("[SpaceShooter:loadAssets] Missing: " .. filepath .. " (no fallback available)")
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

    -- Phase 3: Fire Mode Handling
    if self.fire_mode == "manual" then
        -- Manual: Press space to fire with cooldown
        if self.player.fire_cooldown > 0 then
            self.player.fire_cooldown = self.player.fire_cooldown - dt
        end

        if self:isKeyDown('space') and self.player.fire_cooldown <= 0 then
            self:playerShoot()
            self.player.fire_cooldown = FIRE_COOLDOWN
        end

    elseif self.fire_mode == "auto" then
        -- Auto: Hold space, fires automatically at fire_rate
        if self.player.auto_fire_timer > 0 then
            self.player.auto_fire_timer = self.player.auto_fire_timer - dt
        end

        if self:isKeyDown('space') and self.player.auto_fire_timer <= 0 then
            self:playerShoot()
            self.player.auto_fire_timer = 1.0 / self.fire_rate
        end

    elseif self.fire_mode == "charge" then
        -- Charge: Hold space to charge, release to fire
        if self:isKeyDown('space') then
            if not self.player.is_charging then
                self.player.is_charging = true
                self.player.charge_progress = 0
            end
            self.player.charge_progress = math.min(self.player.charge_progress + dt, self.charge_time)
        else
            if self.player.is_charging then
                -- Released - fire charged shot
                local charge_multiplier = self.player.charge_progress / self.charge_time
                self:playerShoot(charge_multiplier)
                self.player.is_charging = false
                self.player.charge_progress = 0
            end
        end

    elseif self.fire_mode == "burst" then
        -- Burst: Press space to fire burst_count bullets rapidly
        if self.player.burst_remaining > 0 then
            self.player.burst_timer = self.player.burst_timer + dt
            if self.player.burst_timer >= self.burst_delay then
                self:playerShoot()
                self.player.burst_remaining = self.player.burst_remaining - 1
                self.player.burst_timer = 0
            end
        else
            if self.player.fire_cooldown > 0 then
                self.player.fire_cooldown = self.player.fire_cooldown - dt
            end

            if self:isKeyDown('space') and self.player.fire_cooldown <= 0 then
                self.player.burst_remaining = self.burst_count
                self.player.burst_timer = 0
                self.player.fire_cooldown = FIRE_COOLDOWN
            end
        end
    end

    -- Phase 4: Ammo reload system
    if self.ammo_enabled then
        if self.player.is_reloading then
            self.player.reload_timer = self.player.reload_timer - dt
            if self.player.reload_timer <= 0 then
                self.player.is_reloading = false
                self.player.ammo = self.ammo_capacity
            end
        end

        -- Check for manual reload (R key)
        if self:isKeyDown('r') and not self.player.is_reloading and self.player.ammo < self.ammo_capacity then
            self.player.is_reloading = true
            self.player.reload_timer = self.ammo_reload_time
        end
    end

    -- Phase 4: Overheat cooldown system
    if self.overheat_enabled then
        if self.player.is_overheated then
            self.player.overheat_timer = self.player.overheat_timer - dt
            if self.player.overheat_timer <= 0 then
                self.player.is_overheated = false
                self.player.heat = 0
            end
        else
            -- Passive heat dissipation when not shooting
            if self.player.heat > 0 then
                self.player.heat = math.max(0, self.player.heat - dt * self.overheat_heat_dissipation)
            end
        end
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

        -- Phase 3: Homing behavior
        if bullet.homing and bullet.homing_strength > 0 then
            local closest_enemy = nil
            local closest_dist = math.huge

            for _, enemy in ipairs(self.enemies) do
                local dx = enemy.x - bullet.x
                local dy = enemy.y - bullet.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < closest_dist then
                    closest_dist = dist
                    closest_enemy = enemy
                end
            end

            if closest_enemy then
                local dx = closest_enemy.x - bullet.x
                local dy = closest_enemy.y - bullet.y
                local target_angle = math.atan2(dx, -dy)
                local current_angle = math.atan2(bullet.vx, -bullet.vy)

                -- Gradually turn toward target
                local angle_diff = target_angle - current_angle
                -- Normalize angle difference to -pi to pi
                while angle_diff > math.pi do angle_diff = angle_diff - 2 * math.pi end
                while angle_diff < -math.pi do angle_diff = angle_diff + 2 * math.pi end

                local turn_amount = angle_diff * bullet.homing_strength * dt * 5
                local new_angle = current_angle + turn_amount

                -- Update velocity direction (maintain speed)
                local speed = math.sqrt(bullet.vx * bullet.vx + bullet.vy * bullet.vy)
                bullet.vx = math.sin(new_angle) * speed
                bullet.vy = -math.cos(new_angle) * speed
            end
        end

        -- Phase 3: Wave pattern movement
        if bullet.wave_type then
            bullet.wave_time = bullet.wave_time + dt
            local wave_amplitude = 30
            local wave_frequency = 3

            if bullet.wave_type == "wave_left" then
                bullet.x = bullet.x + math.sin(bullet.wave_time * wave_frequency) * wave_amplitude * dt
            elseif bullet.wave_type == "wave_right" then
                bullet.x = bullet.x - math.sin(bullet.wave_time * wave_frequency) * wave_amplitude * dt
            end
            -- wave_center stays straight
        end

        -- Phase 2: Apply gravity to bullets (if enabled)
        if self.bullet_gravity and self.bullet_gravity ~= 0 then
            if bullet.directional then
                -- Apply gravity to vy for directional bullets
                bullet.vy = bullet.vy + self.bullet_gravity * dt
            else
                -- For non-directional bullets, need to convert to directional with gravity
                -- This makes straight-up bullets start arcing
                if not bullet.vx then
                    bullet.vx = 0
                    bullet.vy = -BULLET_SPEED
                    bullet.directional = true
                end
                bullet.vy = bullet.vy + self.bullet_gravity * dt
            end
        end

        -- Update bullet position (directional or straight up)
        if bullet.directional then
            bullet.x = bullet.x + bullet.vx * dt
            bullet.y = bullet.y + bullet.vy * dt
        else
            bullet.y = bullet.y - BULLET_SPEED * dt
        end

        local bullet_hit = false
        for j = #self.enemies, 1, -1 do
            local enemy = self.enemies[j]
            if enemy and self:checkCollision(bullet, enemy) then
                bullet_hit = true

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

                -- Phase 3: Piercing bullets don't get removed on hit
                if not bullet.piercing then
                    table.remove(self.player_bullets, i)
                    goto next_player_bullet
                end
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

function SpaceShooter:playerShoot(charge_multiplier)
    charge_multiplier = charge_multiplier or 1.0

    -- Phase 4: Ammo system check
    if self.ammo_enabled then
        if self.player.is_reloading then
            return -- Can't shoot while reloading
        end

        if self.player.ammo <= 0 then
            -- Auto-reload when empty
            self.player.is_reloading = true
            self.player.reload_timer = self.ammo_reload_time
            return
        end

        -- Consume ammo
        self.player.ammo = self.player.ammo - 1
    end

    -- Phase 4: Overheat system check
    if self.overheat_enabled then
        if self.player.is_overheated then
            return -- Can't shoot while overheated
        end

        -- Increase heat
        self.player.heat = self.player.heat + 1

        -- Check for overheat
        if self.player.heat >= self.overheat_threshold then
            self.player.is_overheated = true
            self.player.overheat_timer = self.overheat_cooldown
            self.player.heat = self.overheat_threshold
        end
    end

    -- Phase 3: Bullet Pattern Implementation
    local base_angle = 0  -- Straight up for most modes

    -- For asteroids mode, shoot in direction player is facing
    if self.movement_type == "asteroids" then
        base_angle = self.player.angle
    end

    -- Phase 3: Create bullets based on pattern
    if self.bullet_pattern == "single" then
        self:createBullet(base_angle, charge_multiplier)

    elseif self.bullet_pattern == "double" then
        -- Two bullets parallel, slightly offset left and right
        local offset = 5
        self:createBullet(base_angle, charge_multiplier, -offset)
        self:createBullet(base_angle, charge_multiplier, offset)

    elseif self.bullet_pattern == "triple" then
        -- Three bullets: center + slight angles
        self:createBullet(base_angle, charge_multiplier)
        self:createBullet(base_angle - 10, charge_multiplier)
        self:createBullet(base_angle + 10, charge_multiplier)

    elseif self.bullet_pattern == "spread" then
        -- Spread pattern using bullet_arc and bullets_per_shot
        local num_bullets = self.bullets_per_shot
        if num_bullets == 1 then num_bullets = 5 end  -- Default to 5 if not specified

        local start_angle = base_angle - self.bullet_arc / 2
        local angle_step = num_bullets > 1 and (self.bullet_arc / (num_bullets - 1)) or 0

        for i = 0, num_bullets - 1 do
            self:createBullet(start_angle + angle_step * i, charge_multiplier)
        end

    elseif self.bullet_pattern == "spiral" then
        -- Create bullets in a rotating pattern (spiral effect when repeated)
        local num_bullets = self.bullets_per_shot
        if num_bullets == 1 then num_bullets = 6 end  -- Default to 6 if not specified

        local angle_step = 360 / num_bullets
        local spiral_offset = (love.timer.getTime() * 200) % 360  -- Rotating over time

        for i = 0, num_bullets - 1 do
            self:createBullet(base_angle + (i * angle_step) + spiral_offset, charge_multiplier)
        end

    elseif self.bullet_pattern == "wave" then
        -- Three bullets that will move in wave pattern
        self:createBullet(base_angle, charge_multiplier, 0, "wave_center")
        self:createBullet(base_angle, charge_multiplier, 0, "wave_left")
        self:createBullet(base_angle, charge_multiplier, 0, "wave_right")
    end

    -- Phase 3.3: Play shoot sound
    self:playSound("shoot", 0.6)
end

-- Phase 3: Helper to create individual bullets with pattern support
function SpaceShooter:createBullet(angle, charge_multiplier, x_offset, wave_type)
    angle = angle or 0
    charge_multiplier = charge_multiplier or 1.0
    x_offset = x_offset or 0
    wave_type = wave_type or nil

    local bullet = {
        width = BULLET_WIDTH,
        height = BULLET_HEIGHT,
        charge_multiplier = charge_multiplier,
        homing = self.bullet_homing,
        homing_strength = self.homing_strength,
        piercing = self.bullet_piercing,
        wave_type = wave_type,
        wave_time = 0
    }

    local rad = math.rad(angle)

    -- Calculate spawn position
    if self.movement_type == "asteroids" then
        -- Offset bullet spawn to front of ship
        local offset_distance = self.player.height / 2
        local offset_x = math.sin(rad) * offset_distance
        local offset_y = -math.cos(rad) * offset_distance

        bullet.x = self.player.x + offset_x + x_offset - BULLET_WIDTH/2
        bullet.y = self.player.y + offset_y - BULLET_HEIGHT/2
    else
        -- All other modes: spawn from top-center
        bullet.x = self.player.x + x_offset - BULLET_WIDTH/2
        bullet.y = self.player.y - self.player.height/2
    end

    -- Calculate velocity
    local speed = self.bullet_speed * charge_multiplier
    bullet.vx = math.sin(rad) * speed
    bullet.vy = -math.cos(rad) * speed
    bullet.directional = true

    table.insert(self.player_bullets, bullet)
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