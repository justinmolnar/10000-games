local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local Collision = require('src.utils.collision')
local MovementController = require('src.utils.game_components.movement_controller')
local PhysicsUtils = require('src.utils.game_components.physics_utils')
local VariantLoader = require('src.utils.game_components.variant_loader')
local HUDRenderer = require('src.utils.game_components.hud_renderer')
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

    -- Phase 7: Initialize VariantLoader for simplified parameter loading
    local loader = VariantLoader:new(self.variant, runtimeCfg, {})

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
    self.movement_speed = loader:get('movement_speed', PLAYER_SPEED)

    -- Asteroids mode physics
    self.rotation_speed = loader:get('rotation_speed', 5.0)

    self.accel_friction = loader:get('accel_friction', 1.0)

    self.decel_friction = loader:get('decel_friction', 1.0)

    -- Jump mode parameters (distance as % of screen width)
    self.jump_distance_percent = (runtimeCfg.player and runtimeCfg.player.jump_distance) or 0.08
    if self.variant and self.variant.jump_distance ~= nil then
        self.jump_distance_percent = self.variant.jump_distance
    end

    self.jump_cooldown = loader:get('jump_cooldown', 0.5)

    self.jump_speed = loader:get('jump_speed', 400)

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

    self.shield_regen_time = loader:get('shield_regen_time', 5.0)

    self.shield_max_hits = (runtimeCfg.shield and runtimeCfg.shield.max_hits) or 1
    if self.variant and self.variant.shield_hits ~= nil then
        self.shield_max_hits = self.variant.shield_hits
    end

    -- Phase 3: Weapon System - Fire Mode
    self.fire_mode = (runtimeCfg.weapon and runtimeCfg.weapon.fire_mode) or "manual"
    if self.variant and self.variant.fire_mode then
        self.fire_mode = self.variant.fire_mode
    end

    self.fire_rate = loader:get('fire_rate', 1.0)

    self.burst_count = loader:get('burst_count', 3)

    self.burst_delay = loader:get('burst_delay', 0.1)

    self.charge_time = loader:get('charge_time', 1.0)

    -- Phase 3: Bullet Pattern
    self.bullet_pattern = (runtimeCfg.weapon and runtimeCfg.weapon.pattern) or "single"
    if self.variant and self.variant.bullet_pattern then
        self.bullet_pattern = self.variant.bullet_pattern
    end

    self.spread_angle = loader:get('spread_angle', 30)

    -- Phase 3: Bullet Arc and Count
    self.bullet_arc = loader:get('bullet_arc', 30)

    self.bullets_per_shot = loader:get('bullets_per_shot', 1)

    -- Phase 3: Bullet Behavior
    self.bullet_speed = loader:get('bullet_speed', BULLET_SPEED)

    self.bullet_homing = loader:get('bullet_homing', false)

    self.homing_strength = loader:get('homing_strength', 0.0)

    self.bullet_piercing = loader:get('bullet_piercing', false)

    -- Phase 2: Bullet Gravity
    self.bullet_gravity = loader:get('bullet_gravity', 0)

    -- Phase 4: Ammo System
    self.ammo_enabled = loader:get('ammo_enabled', false)

    self.ammo_capacity = loader:get('ammo_capacity', 50)

    self.ammo_reload_time = loader:get('ammo_reload_time', 2.0)

    -- Phase 4: Overheat System
    self.overheat_enabled = loader:get('overheat_enabled', false)

    self.overheat_threshold = loader:get('overheat_threshold', 10)

    self.overheat_cooldown = loader:get('overheat_cooldown', 3.0)

    self.overheat_heat_dissipation = loader:get('overheat_heat_dissipation', 2.0)

    -- Phase 5: Enemy spawn patterns
    self.enemy_spawn_pattern = loader:get('enemy_spawn_pattern', "continuous")

    self.enemy_spawn_rate_multiplier = loader:get('enemy_spawn_rate_multiplier', 1.0)

    self.enemy_speed_multiplier = loader:get('enemy_speed_multiplier', 1.0)

    -- Phase 5: Enemy formations
    self.enemy_formation = loader:get('enemy_formation', "scattered")

    -- Phase 5: Enemy bullet system
    self.enemy_bullets_enabled = loader:get('enemy_bullets_enabled', false)

    self.enemy_bullet_speed = loader:get('enemy_bullet_speed', 200)

    self.enemy_fire_rate = loader:get('enemy_fire_rate', 2.0)

    -- Enemy health system
    self.enemy_health = loader:get('enemy_health', 1)

    self.enemy_health_variance = loader:get('enemy_health_variance', 0.0)

    self.enemy_health_min = loader:get('enemy_health_min', 1)

    self.enemy_health_max = loader:get('enemy_health_max', 1)

    self.use_health_range = loader:get('use_health_range', false)

    -- Enemy behavior system (default, space_invaders, galaga)
    self.enemy_behavior = loader:get('enemy_behavior', "default")

    -- Wave system for special behaviors
    self.waves_enabled = loader:get('waves_enabled', false)

    -- Wave progression parameters
    self.wave_difficulty_increase = loader:get('wave_difficulty_increase', 0.1)

    self.wave_random_variance = loader:get('wave_random_variance', 0.0)

    -- Enemy density (spacing multiplier)
    self.enemy_density = loader:get('enemy_density', 1.0)

    -- Space Invaders grid parameters
    self.grid_rows = loader:get('grid_rows', 4)

    self.grid_columns = loader:get('grid_columns', 8)

    self.grid_speed = loader:get('grid_speed', 50)

    self.grid_descent = loader:get('grid_descent', 20)

    -- Galaga dive parameters
    self.dive_frequency = loader:get('dive_frequency', 3.0)

    self.max_diving_enemies = loader:get('max_diving_enemies', 1)

    self.entrance_pattern = loader:get('entrance_pattern', "swoop")

    self.formation_size = loader:get('formation_size', 24)

    self.initial_spawn_count = loader:get('initial_spawn_count', 8)

    self.galaga_spawn_interval = (runtimeCfg.enemy and runtimeCfg.enemy.spawn_interval) or 0.5
    if self.variant and self.variant.spawn_interval ~= nil then
        self.galaga_spawn_interval = self.variant.spawn_interval
    end

    -- Phase 5: Enemy bullet patterns (for bullet hell)
    self.enemy_bullet_pattern = loader:get('enemy_bullet_pattern', "single")

    self.enemy_bullets_per_shot = loader:get('enemy_bullets_per_shot', 1)

    self.enemy_bullet_spread_angle = loader:get('enemy_bullet_spread_angle', 30)

    -- Phase 5: Wave spawn parameters
    self.wave_enemies_per_wave = loader:get('wave_enemies_per_wave', 5)

    self.wave_pause_duration = loader:get('wave_pause_duration', 3.0)

    -- Phase 5: Difficulty scaling
    self.difficulty_curve = loader:get('difficulty_curve', "linear")

    self.difficulty_scaling_rate = loader:get('difficulty_scaling_rate', 0.1)

    -- Phase 6: Power-up system
    self.powerup_enabled = loader:get('powerup_enabled', false)

    self.powerup_spawn_rate = loader:get('powerup_spawn_rate', 15.0)

    self.powerup_duration = loader:get('powerup_duration', 8.0)

    self.powerup_types = loader:get('powerup_types', {"speed", "rapid_fire", "pierce", "shield"})

    self.powerup_drop_speed = loader:get('powerup_drop_speed', 150)

    self.powerup_size = loader:get('powerup_size', 20)

    self.powerup_speed_multiplier = loader:get('powerup_speed_multiplier', 1.5)

    self.powerup_rapid_fire_multiplier = loader:get('powerup_rapid_fire_multiplier', 0.5)

    -- Phase 7: Environmental hazards
    self.asteroid_density = loader:get('asteroid_density', 0)

    self.asteroid_speed = loader:get('asteroid_speed', 100)

    self.asteroid_size_min = loader:get('asteroid_size_min', 20)

    self.asteroid_size_max = loader:get('asteroid_size_max', 50)

    self.asteroids_can_be_destroyed = loader:get('asteroids_can_be_destroyed', true)

    self.meteor_frequency = loader:get('meteor_frequency', 0)

    self.meteor_speed = loader:get('meteor_speed', 400)

    self.meteor_warning_time = loader:get('meteor_warning_time', 1.0)

    self.gravity_wells_count = loader:get('gravity_wells_count', 0)

    self.gravity_well_strength = loader:get('gravity_well_strength', 400)

    self.gravity_well_radius = loader:get('gravity_well_radius', 150)

    self.scroll_speed = loader:get('scroll_speed', 0)

    -- Phase 8: Special mechanics
    self.screen_wrap = loader:get('screen_wrap', false)

    self.screen_wrap_bullets = loader:get('screen_wrap_bullets', false)

    self.screen_wrap_enemies = loader:get('screen_wrap_enemies', false)

    self.bullet_max_wraps = loader:get('bullet_max_wraps', 2)

    self.reverse_gravity = loader:get('reverse_gravity', false)

    self.blackout_zones_count = loader:get('blackout_zones_count', 0)

    self.blackout_zone_radius = loader:get('blackout_zone_radius', 100)

    self.blackout_zones_move = loader:get('blackout_zones_move', false)

    -- Phase 8: Victory conditions
    self.victory_condition = loader:get('victory_condition', "kills")

    self.victory_limit = loader:get('victory_limit', 20)

    self.game_width = (SCfg.arena and SCfg.arena.width) or 800
    self.game_height = (SCfg.arena and SCfg.arena.height) or 600

    -- Phase 8: Adjust player spawn based on reverse gravity
    -- Normal: player at bottom (game_height - offset)
    -- Reverse: player at top (offset)
    local player_y = self.reverse_gravity and PLAYER_START_Y_OFFSET or (self.game_height - PLAYER_START_Y_OFFSET)

    self.player = {
        x = self.game_width / 2,
        y = player_y,
        width = PLAYER_WIDTH,  -- Keep for collision
        height = PLAYER_HEIGHT,
        radius = math.max(PLAYER_WIDTH, PLAYER_HEIGHT) / 2,  -- For center-based bounds
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
    elseif self.movement_type == "default" or self.movement_type == "rail" then
        -- Initialize velocity for default/rail modes (required by MovementController)
        self.player.vx = 0
        self.player.vy = 0
        self.player.angle = 0
    end

    -- Initialize MovementController based on movement_type
    local movement_mode = "direct"
    if self.movement_type == "asteroids" then
        movement_mode = "asteroids"
    elseif self.movement_type == "rail" then
        movement_mode = "rail"
    elseif self.movement_type == "jump" then
        movement_mode = "jump"
    end

    self.movement_controller = MovementController:new({
        mode = movement_mode,
        speed = self.movement_speed,
        friction = 1.0,
        accel_friction = self.accel_friction,
        decel_friction = self.decel_friction,
        rotation_speed = self.rotation_speed,
        rail_axis = "horizontal",
        thrust_acceleration = self.movement_speed * 5,
        reverse_mode = "none",
        jump_distance = self.game_width * self.jump_distance_percent,
        jump_cooldown = self.jump_cooldown,
        jump_speed = self.jump_speed
    })

    -- Phase 2: Initialize shield state
    if self.shield_enabled then
        self.player.shield_active = true
        self.player.shield_regen_timer = 0
        self.player.shield_hits_remaining = self.shield_max_hits
    end

    self.enemies = {}
    self.player_bullets = {}
    self.enemy_bullets = {}

    -- Phase 6: Power-up system
    self.powerups = {}  -- Power-ups on screen
    self.active_powerups = {}  -- Active effects on player
    self.powerup_spawn_timer = self.powerup_spawn_rate  -- Countdown to next spawn

    -- Phase 7: Environmental hazards
    self.asteroids = {}  -- Asteroids on screen
    self.asteroid_spawn_timer = 0  -- Countdown to next asteroid spawn
    self.meteors = {}  -- Active meteors
    self.meteor_warnings = {}  -- Meteor warnings before impact
    self.meteor_timer = self.meteor_frequency > 0 and (60 / self.meteor_frequency) or 0  -- Countdown to next meteor wave
    self.gravity_wells = {}  -- Gravity well positions
    self.scroll_offset = 0  -- Current scroll offset for vertical scrolling

    -- Phase 8: Special mechanics state
    self.blackout_zones = {}  -- Blackout zone positions
    self.survival_time = 0  -- Time survived for time/survival victory conditions

    -- Phase 5: Wave spawn state
    self.wave_state = {
        active = false,  -- Is a wave currently spawning
        enemies_remaining = 0,  -- Enemies left to spawn in current wave
        pause_timer = 0,  -- Time before next wave
        enemies_per_wave = self.wave_enemies_per_wave,
        pause_duration = self.wave_pause_duration
    }

    -- Phase 5: Difficulty scaling state
    self.difficulty_scale = 1.0  -- Current difficulty multiplier

    -- Space Invaders grid state
    self.grid_state = {
        x = 0,  -- Current grid x position
        y = 50,  -- Current grid y position
        direction = 1,  -- 1 = right, -1 = left
        speed_multiplier = 1.0,  -- Increases as enemies die
        initialized = false,  -- Has grid been spawned
        wave_active = false,  -- Is wave currently active
        wave_pause_timer = 0,  -- Time before next wave
        initial_enemy_count = 0,  -- Enemies spawned in current wave
        wave_number = 0  -- Current wave number (for progression)
    }

    -- Galaga formation state
    self.galaga_state = {
        formation_positions = {},  -- Array of formation slots
        dive_timer = self.dive_frequency,  -- Countdown to next dive
        diving_count = 0,  -- Current number of enemies diving
        entrance_queue = {},  -- Enemies waiting to enter formation
        wave_active = false,  -- Is wave currently active
        wave_pause_timer = 0,  -- Time before next wave
        initial_enemy_count = 0,  -- Enemies spawned in current wave
        wave_number = 0,  -- Current wave number (for progression)
        spawn_timer = 0.0,  -- Timer for gradual enemy spawning
        spawned_count = 0,  -- How many enemies have been spawned so far
        wave_modifiers = {}  -- Store modifiers for current wave
    }

    self.metrics.kills = 0
    self.metrics.deaths = 0
    self.metrics.combo = 0  -- Phase 2: Track combo (kills without deaths)

    -- Phase 7: Initialize gravity wells
    for i = 1, self.gravity_wells_count do
        table.insert(self.gravity_wells, {
            x = math.random(50, self.game_width - 50),
            y = math.random(50, self.game_height - 50),
            radius = self.gravity_well_radius,
            strength = self.gravity_well_strength
        })
    end

    -- Phase 8: Initialize blackout zones
    for i = 1, self.blackout_zones_count do
        table.insert(self.blackout_zones, {
            x = math.random(self.blackout_zone_radius, self.game_width - self.blackout_zone_radius),
            y = math.random(self.blackout_zone_radius, self.game_height - self.blackout_zone_radius),
            radius = self.blackout_zone_radius,
            vx = self.blackout_zones_move and (math.random() - 0.5) * 50 or 0,  -- Random velocity if moving
            vy = self.blackout_zones_move and (math.random() - 0.5) * 50 or 0
        })
    end

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

    -- Standard HUD (Phase 8)
    self.hud = HUDRenderer:new({
        primary = {label = "Score", key = "score"},
        secondary = {label = "Wave", key = "wave"},
        lives = {key = "lives", max = self.lives, style = "hearts"}
    })
    self.hud.game = self

    self.view = SpaceShooterView:new(self, self.variant)
    print("[SpaceShooter:init] Initialized with default game dimensions:", self.game_width, self.game_height)
    print("[SpaceShooter:init] Variant:", self.variant and self.variant.name or "Default")

    -- Phase 2.3: Load sprite assets with graceful fallback
    self:loadAssets()
end

-- Phase 2.3: Asset loading with fallback
function SpaceShooter:loadAssets()
    self.sprites = {}

    local game_type = "space_shooter"
    local fallback_sprite_set = "fighter_1"  -- Config default

    -- Use variant sprite_set or fall back to config default
    local sprite_set = (self.variant and self.variant.sprite_set) or fallback_sprite_set

    local base_path = "assets/sprites/games/" .. game_type .. "/" .. sprite_set .. "/"
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

        -- Fall back to default sprite_set (fighter_1) if not already using it
        if sprite_set ~= fallback_sprite_set then
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
        -- Phase 8: Respect reverse gravity when resetting player position
        self.player.y = self.reverse_gravity and PLAYER_START_Y_OFFSET or (self.game_height - PLAYER_START_Y_OFFSET)
        print("[SpaceShooter] Play area updated to:", width, height)
    else
        print("[SpaceShooter] setPlayArea called before init completed")
    end

    -- Recalculate Galaga formation if using Galaga behavior
    if self.enemy_behavior == "galaga" and #self.galaga_state.formation_positions > 0 then
        -- Store which slots were occupied
        local occupied_slots = {}
        for i, slot in ipairs(self.galaga_state.formation_positions) do
            occupied_slots[i] = slot.occupied
        end

        -- Recalculate formation positions with new screen size
        self:initGalagaFormation()

        -- Restore occupied status (existing enemies stay where they are)
        for i, slot in ipairs(self.galaga_state.formation_positions) do
            if occupied_slots[i] then
                slot.occupied = occupied_slots[i]
            end
        end
    end
end

function SpaceShooter:updateGameLogic(dt)
    self:updatePlayer(dt)

    -- Phase 8: Track survival time for victory conditions
    self.survival_time = self.survival_time + dt

    -- Phase 5: Update difficulty scaling
    self:updateDifficulty(dt)

    -- Enemy behavior: Space Invaders, Galaga, or Default
    if self.enemy_behavior == "space_invaders" then
        self:updateSpaceInvadersGrid(dt)
    elseif self.enemy_behavior == "galaga" then
        self:updateGalagaFormation(dt)
    else
        -- Default behavior: Phase 5 enemy spawning based on pattern
        if self.enemy_spawn_pattern == "waves" then
            self:updateWaveSpawning(dt)
        elseif self.enemy_spawn_pattern == "continuous" then
            -- Apply spawn rate multiplier and difficulty scaling
            local adjusted_spawn_rate = self.spawn_rate / (self.enemy_spawn_rate_multiplier * self.difficulty_scale)
            self.spawn_timer = self.spawn_timer - dt
            if self.spawn_timer <= 0 then
                self:spawnEnemy()
                self.spawn_timer = adjusted_spawn_rate
            end
        elseif self.enemy_spawn_pattern == "clusters" then
            self.spawn_timer = self.spawn_timer - dt
            if self.spawn_timer <= 0 then
                -- Spawn a cluster of 3-5 enemies
                local cluster_size = math.random(3, 5)
                for i = 1, cluster_size do
                    self:spawnEnemy()
                end
                self.spawn_timer = (self.spawn_rate * 2) / self.enemy_spawn_rate_multiplier  -- Longer delay between clusters
            end
        end
    end

    self:updateEnemies(dt)
    self:updateBullets(dt)

    -- Phase 6: Power-up spawning and updates
    if self.powerup_enabled then
        self:updatePowerups(dt)
    end

    -- Phase 7: Environmental hazards
    if self.asteroid_density > 0 then
        self:updateAsteroids(dt)
    end
    if self.meteor_frequency > 0 then
        self:updateMeteors(dt)
    end
    if #self.gravity_wells > 0 then
        self:applyGravityWells(dt)
    end
    if self.scroll_speed > 0 then
        self:updateScrolling(dt)
    end

    -- Phase 8: Update blackout zones
    if #self.blackout_zones > 0 and self.blackout_zones_move then
        self:updateBlackoutZones(dt)
    end
end

function SpaceShooter:updatePlayer(dt)
    -- Phase 2: Movement type system (using MovementController)
    -- Build input table from keyboard state
    local input = {
        left = self:isKeyDown('left', 'a'),
        right = self:isKeyDown('right', 'd'),
        up = self:isKeyDown('up', 'w'),
        down = self:isKeyDown('down', 's'),
        jump = false  -- Not used in space shooter
    }

    -- Build bounds table
    local bounds = {
        x = 0,
        y = 0,
        width = self.game_width,
        height = self.game_height,
        wrap_x = self.screen_wrap,
        wrap_y = self.screen_wrap
    }

    -- Add time_elapsed for jump mode cooldown tracking
    if not self.player.time_elapsed then
        self.player.time_elapsed = 0
    end
    self.player.time_elapsed = self.player.time_elapsed + dt

    -- Update movement via MovementController
    self.movement_controller:update(dt, self.player, input, bounds)

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


function SpaceShooter:updateEnemies(dt)
     for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        if not enemy then goto continue_enemy_loop end

        -- Handle default movement (skip for special behavior patterns)
        if enemy.movement_pattern ~= 'grid' and enemy.movement_pattern ~= 'galaga_entering' and enemy.movement_pattern ~= 'formation' then
            -- Phase 1.4 & 5: Apply speed multiplier for variant enemies and speed_override
            local speed = enemy.speed_override or self.enemy_speed
            if enemy.is_variant_enemy and enemy.speed_multiplier then
                speed = speed * enemy.speed_multiplier
            end
            -- Phase 5: Apply variant's global enemy speed multiplier
            speed = speed * self.enemy_speed_multiplier

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

        -- Phase 5: Enemy bullets
        if self.enemy_bullets_enabled or (self.can_shoot_back and (enemy.shoot_rate_multiplier or 1.0) > 0) then
            enemy.shoot_timer = enemy.shoot_timer - dt
            if enemy.shoot_timer <= 0 then
                self:enemyShoot(enemy)
                enemy.shoot_timer = enemy.shoot_rate
            end
        end

        -- Remove enemies that are fully off screen
        -- Skip off-screen removal for special behaviors (they manage their own lifecycle)
        if enemy.movement_pattern ~= 'grid' and enemy.movement_pattern ~= 'galaga_entering' and enemy.movement_pattern ~= 'formation' then
            -- Phase 8: In reverse gravity, remove when going off top; otherwise remove when going off bottom
            local off_screen = self.reverse_gravity and (enemy.y + enemy.height < 0) or (enemy.y > self.game_height)
            if off_screen then
                table.remove(self.enemies, i)
            end
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

                -- All enemies now have health (default 1, configurable via enemy_health parameter)
                enemy.health = enemy.health - 1
                if enemy.health <= 0 then
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

        -- Phase 8: Screen wrap or remove bullets that go off screen
        if self.screen_wrap_bullets then
            local should_destroy = self:applyScreenWrap(bullet, self.bullet_max_wraps)
            if should_destroy then
                table.remove(self.player_bullets, i)
            end
        else
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
        end
        ::next_player_bullet::
    end

    for i = #self.enemy_bullets, 1, -1 do
        local bullet = self.enemy_bullets[i]
        if not bullet then goto next_enemy_bullet end
        -- Phase 5: Use bullet's custom speed or default
        local speed = bullet.speed or BULLET_SPEED

        -- Phase 5: Directional bullets (for patterns)
        if bullet.directional and bullet.vx and bullet.vy then
            bullet.x = bullet.x + bullet.vx * dt
            bullet.y = bullet.y + bullet.vy * dt
        else
            bullet.y = bullet.y + speed * dt
        end

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

        -- Remove bullets off screen (any direction for directional bullets)
        if bullet.directional then
            if bullet.x < -BULLET_WIDTH or bullet.x > self.game_width or
               bullet.y < -BULLET_HEIGHT or bullet.y > self.game_height then
                table.remove(self.enemy_bullets, i)
            end
        else
            if bullet.y > self.game_height + BULLET_HEIGHT then
                table.remove(self.enemy_bullets, i)
            end
        end
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
        wave_time = 0,
        wrap_count = 0  -- Phase 8: Track how many times bullet has wrapped
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
        -- All other modes: spawn from top-center (or bottom-center if reverse gravity)
        bullet.x = self.player.x + x_offset - BULLET_WIDTH/2
        if self.reverse_gravity then
            bullet.y = self.player.y + self.player.height/2  -- Spawn from bottom
        else
            bullet.y = self.player.y - self.player.height/2  -- Spawn from top
        end
    end

    -- Calculate velocity (Phase 8: reverse if reverse_gravity)
    local speed = self.bullet_speed * charge_multiplier
    local direction_multiplier = self.reverse_gravity and 1 or -1  -- Reverse Y direction
    bullet.vx = math.sin(rad) * speed
    bullet.vy = math.cos(rad) * speed * direction_multiplier
    bullet.directional = true

    table.insert(self.player_bullets, bullet)
end

function SpaceShooter:enemyShoot(enemy)
    -- Phase 5: Enemy bullet patterns for bullet hell
    local center_x = enemy.x + enemy.width/2
    local center_y = enemy.y + enemy.height

    -- Phase 8: In reverse gravity, bullets shoot upward (negative direction)
    local direction_multiplier = self.reverse_gravity and -1 or 1

    -- Enemy bullets are larger and more visible (8x8 instead of 4x8)
    local enemy_bullet_size = 8

    if self.enemy_bullet_pattern == "spread" then
        -- Spread pattern: multiple bullets in arc
        local count = self.enemy_bullets_per_shot
        local angle_step = self.enemy_bullet_spread_angle / (count - 1)
        local start_angle = -self.enemy_bullet_spread_angle / 2

        for i = 1, count do
            local angle = math.rad(start_angle + (i - 1) * angle_step)
            table.insert(self.enemy_bullets, {
                x = center_x - enemy_bullet_size/2,
                y = center_y,
                width = enemy_bullet_size,
                height = enemy_bullet_size,
                speed = self.enemy_bullet_speed,
                vx = math.sin(angle) * self.enemy_bullet_speed,
                vy = math.cos(angle) * self.enemy_bullet_speed * direction_multiplier,
                directional = true
            })
        end
    elseif self.enemy_bullet_pattern == "spray" then
        -- Spray: many bullets in wide arc (true bullet hell)
        for i = 1, self.enemy_bullets_per_shot do
            local angle = math.rad(math.random(-self.enemy_bullet_spread_angle, self.enemy_bullet_spread_angle))
            table.insert(self.enemy_bullets, {
                x = center_x - enemy_bullet_size/2,
                y = center_y,
                width = enemy_bullet_size,
                height = enemy_bullet_size,
                speed = self.enemy_bullet_speed,
                vx = math.sin(angle) * self.enemy_bullet_speed,
                vy = math.cos(angle) * self.enemy_bullet_speed * direction_multiplier,
                directional = true
            })
        end
    elseif self.enemy_bullet_pattern == "ring" then
        -- Ring: bullets in all directions (360 spray)
        local count = self.enemy_bullets_per_shot
        local angle_step = 360 / count
        for i = 1, count do
            local angle = math.rad(i * angle_step)
            table.insert(self.enemy_bullets, {
                x = center_x - enemy_bullet_size/2,
                y = center_y,
                width = enemy_bullet_size,
                height = enemy_bullet_size,
                speed = self.enemy_bullet_speed,
                vx = math.cos(angle) * self.enemy_bullet_speed,
                vy = math.sin(angle) * self.enemy_bullet_speed * direction_multiplier,
                directional = true
            })
        end
    else
        -- Single bullet (default)
        table.insert(self.enemy_bullets, {
            x = center_x - enemy_bullet_size/2,
            y = center_y,
            width = enemy_bullet_size,
            height = enemy_bullet_size,
            speed = self.enemy_bullet_speed * direction_multiplier
        })
    end
end

-- Calculate enemy health with variance/range support
function SpaceShooter:calculateEnemyHealth(base_health, enemy_type_health_multiplier)
    base_health = base_health or self.enemy_health
    enemy_type_health_multiplier = enemy_type_health_multiplier or 1

    local final_health

    if self.use_health_range then
        -- Use random range (min to max)
        final_health = math.random(self.enemy_health_min, self.enemy_health_max)
    else
        -- Use base health with optional variance
        if self.enemy_health_variance > 0 then
            local variance_factor = 1.0 + ((math.random() - 0.5) * 2 * self.enemy_health_variance)
            final_health = base_health * variance_factor
        else
            final_health = base_health
        end
    end

    -- Apply enemy type multiplier (e.g., bomber has 2x health)
    final_health = final_health * enemy_type_health_multiplier

    -- Ensure at least 1 health
    return math.max(1, math.floor(final_health + 0.5))
end

function SpaceShooter:spawnEnemy()
    -- Phase 1.4: Check if variant has enemy composition
    if self:hasVariantEnemies() and math.random() < 0.5 then
        -- 50% chance to spawn variant-specific enemy
        return self:spawnVariantEnemy()
    end

    -- Phase 5: Formation-based spawning
    if self.enemy_formation == "v_formation" then
        return self:spawnFormation("v")
    elseif self.enemy_formation == "wall" then
        return self:spawnFormation("wall")
    elseif self.enemy_formation == "spiral" then
        return self:spawnFormation("spiral")
    end

    -- Default enemy spawning (scattered)
    local movement = 'straight'
    if self.difficulty_modifiers.complexity >= 2 then
        movement = math.random() > 0.5 and 'zigzag' or 'straight'
    end

    -- Phase 5: Apply speed multiplier and difficulty scaling
    local adjusted_speed = self.enemy_speed * self.enemy_speed_multiplier * math.sqrt(self.difficulty_scale)

    -- Phase 8: Reverse gravity - spawn at bottom, move up
    local spawn_y = self.reverse_gravity and self.game_height or ENEMY_START_Y_OFFSET
    local speed_direction = self.reverse_gravity and -1 or 1

    local enemy = {
        x = math.random(0, self.game_width - ENEMY_WIDTH),
        y = spawn_y,
        width = ENEMY_WIDTH, height = ENEMY_HEIGHT,
        movement_pattern = movement,
        speed_override = adjusted_speed * speed_direction,  -- Phase 8: Reverse direction if needed
        shoot_timer = math.random() * (ENEMY_BASE_SHOOT_RATE_MAX - ENEMY_BASE_SHOOT_RATE_MIN) + ENEMY_BASE_SHOOT_RATE_MIN,
        shoot_rate = math.max(0.5, (ENEMY_BASE_SHOOT_RATE_MAX - self.difficulty_modifiers.complexity * ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR)) / self.enemy_fire_rate,
        health = self:calculateEnemyHealth()
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
    -- Phase 8: Respect reverse gravity
    local spawn_y = self.reverse_gravity and self.game_height or ENEMY_START_Y_OFFSET
    local speed_multiplier = self.reverse_gravity and -1 or 1

    -- Calculate health using enemy type's base health multiplier
    local enemy_type_multiplier = enemy_def.health or 1
    local final_health = self:calculateEnemyHealth(nil, enemy_type_multiplier)

    local enemy = {
        x = math.random(0, self.game_width - ENEMY_WIDTH),
        y = spawn_y,
        width = ENEMY_WIDTH,
        height = ENEMY_HEIGHT,
        movement_pattern = enemy_def.movement_pattern,
        enemy_type = enemy_def.name,
        is_variant_enemy = true,
        health = final_health,
        max_health = final_health,
        speed_multiplier = (enemy_def.speed_multiplier or 1.0) * speed_multiplier,  -- Phase 8: Apply reverse gravity
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
    -- Check death condition first (always applies)
    if self.metrics.deaths >= self.PLAYER_MAX_DEATHS then
        return true
    end

    -- Phase 8: Check victory condition
    if self.victory_condition == "kills" then
        return self.metrics.kills >= self.victory_limit
    elseif self.victory_condition == "time" then
        return self.survival_time >= self.victory_limit
    elseif self.victory_condition == "survival" then
        return false  -- Never complete (endless mode)
    end

    -- Default fallback
    return self.metrics.kills >= self.target_kills
end

-- Phase 3.3: Override onComplete to play success sound and stop music
function SpaceShooter:onComplete()
    -- Phase 8: Determine if win based on victory condition
    local is_win = false
    if self.metrics.deaths >= self.PLAYER_MAX_DEATHS then
        is_win = false  -- Lost due to deaths
    elseif self.victory_condition == "kills" then
        is_win = self.metrics.kills >= self.victory_limit
    elseif self.victory_condition == "time" then
        is_win = self.survival_time >= self.victory_limit
    else
        is_win = self.metrics.kills >= self.target_kills  -- Default
    end

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

-- Phase 6: Power-up system
function SpaceShooter:updatePowerups(dt)
    -- Spawn power-ups at intervals
    self.powerup_spawn_timer = self.powerup_spawn_timer - dt
    if self.powerup_spawn_timer <= 0 then
        self:spawnPowerup()
        self.powerup_spawn_timer = self.powerup_spawn_rate
    end

    -- Update power-ups on screen
    for i = #self.powerups, 1, -1 do
        local powerup = self.powerups[i]
        -- Phase 8: Respect reverse gravity for powerup movement
        local speed_direction = self.reverse_gravity and -1 or 1
        powerup.y = powerup.y + self.powerup_drop_speed * speed_direction * dt

        -- Check collection
        if self:checkCollision(powerup, self.player) then
            self:collectPowerup(powerup)
            table.remove(self.powerups, i)
        -- Remove if off screen
        elseif (self.reverse_gravity and powerup.y + powerup.height < 0) or (not self.reverse_gravity and powerup.y > self.game_height) then
            table.remove(self.powerups, i)
        end
    end

    -- Update active power-up durations
    for powerup_type, effect in pairs(self.active_powerups) do
        effect.duration_remaining = effect.duration_remaining - dt
        if effect.duration_remaining <= 0 then
            self:removePowerupEffect(powerup_type)
        end
    end
end

function SpaceShooter:spawnPowerup()
    -- Pick random type from available types
    local powerup_type = self.powerup_types[math.random(#self.powerup_types)]

    -- Phase 8: Respect reverse gravity for powerup spawning
    local spawn_y = self.reverse_gravity and self.game_height or -self.powerup_size

    table.insert(self.powerups, {
        x = math.random(0, self.game_width - self.powerup_size),
        y = spawn_y,
        width = self.powerup_size,
        height = self.powerup_size,
        type = powerup_type
    })
end

function SpaceShooter:collectPowerup(powerup)
    local powerup_type = powerup.type

    -- Remove existing effect of same type (refresh duration)
    if self.active_powerups[powerup_type] then
        self:removePowerupEffect(powerup_type)
    end

    -- Apply new effect
    local effect = {
        duration_remaining = self.powerup_duration
    }

    if powerup_type == "speed" then
        effect.original_speed = PLAYER_SPEED
        PLAYER_SPEED = PLAYER_SPEED * self.powerup_speed_multiplier
    elseif powerup_type == "rapid_fire" then
        effect.original_cooldown = FIRE_COOLDOWN
        FIRE_COOLDOWN = FIRE_COOLDOWN * self.powerup_rapid_fire_multiplier
    elseif powerup_type == "pierce" then
        effect.original_piercing = self.bullet_piercing
        self.bullet_piercing = true
    elseif powerup_type == "shield" then
        if self.shield_enabled then
            self.player.shield_active = true
            self.player.shield_hits_remaining = self.shield_max_hits
        end
    elseif powerup_type == "triple_shot" then
        effect.original_pattern = self.bullet_pattern
        self.bullet_pattern = "triple"
    elseif powerup_type == "spread_shot" then
        effect.original_pattern = self.bullet_pattern
        self.bullet_pattern = "spread"
    end

    self.active_powerups[powerup_type] = effect
    self:playSound("powerup", 1.0)  -- Play collection sound
end

function SpaceShooter:removePowerupEffect(powerup_type)
    local effect = self.active_powerups[powerup_type]
    if not effect then return end

    -- Restore original values
    if powerup_type == "speed" and effect.original_speed then
        PLAYER_SPEED = effect.original_speed
    elseif powerup_type == "rapid_fire" and effect.original_cooldown then
        FIRE_COOLDOWN = effect.original_cooldown
    elseif powerup_type == "pierce" and effect.original_piercing ~= nil then
        self.bullet_piercing = effect.original_piercing
    elseif powerup_type == "triple_shot" and effect.original_pattern then
        self.bullet_pattern = effect.original_pattern
    elseif powerup_type == "spread_shot" and effect.original_pattern then
        self.bullet_pattern = effect.original_pattern
    end

    self.active_powerups[powerup_type] = nil
end

-- Phase 5: Formation spawning
function SpaceShooter:spawnFormation(formation_type)
    local adjusted_speed = self.enemy_speed * self.enemy_speed_multiplier * math.sqrt(self.difficulty_scale)
    local base_shoot_rate = math.max(0.5, (ENEMY_BASE_SHOOT_RATE_MAX - self.difficulty_modifiers.complexity * ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR)) / self.enemy_fire_rate

    -- Phase 8: Respect reverse gravity
    local spawn_y_base = self.reverse_gravity and self.game_height or ENEMY_START_Y_OFFSET
    local speed_multiplier = self.reverse_gravity and -1 or 1

    if formation_type == "v" then
        -- V-formation: 5 enemies in V shape
        local center_x = self.game_width / 2
        local spacing = 60
        for i = 1, 5 do
            local offset = (i - 3) * spacing  -- -2, -1, 0, 1, 2
            local y_offset = math.abs(offset) * 0.5
            local enemy = {
                x = center_x + offset - ENEMY_WIDTH/2,
                y = self.reverse_gravity and (spawn_y_base + y_offset) or (spawn_y_base - y_offset),  -- V shape
                width = ENEMY_WIDTH, height = ENEMY_HEIGHT,
                movement_pattern = 'straight',
                speed_override = adjusted_speed * speed_multiplier,
                shoot_timer = math.random() * 2.0,
                shoot_rate = base_shoot_rate,
                health = self.enemy_health
            }
            table.insert(self.enemies, enemy)
        end
    elseif formation_type == "wall" then
        -- Wall: 6 enemies in a horizontal line
        local num_enemies = 6
        local spacing = self.game_width / (num_enemies + 1)
        for i = 1, num_enemies do
            local enemy = {
                x = spacing * i - ENEMY_WIDTH/2,
                y = spawn_y_base,
                width = ENEMY_WIDTH, height = ENEMY_HEIGHT,
                movement_pattern = 'straight',
                speed_override = adjusted_speed * speed_multiplier,
                shoot_timer = i * 0.2,  -- Staggered shooting
                shoot_rate = base_shoot_rate,
                health = self.enemy_health
            }
            table.insert(self.enemies, enemy)
        end
    elseif formation_type == "spiral" then
        -- Spiral: 8 enemies in circular pattern
        local num_enemies = 8
        local center_x = self.game_width / 2
        local radius = 100
        for i = 1, num_enemies do
            local angle = (i / num_enemies) * math.pi * 2
            local y_offset = math.sin(angle) * radius * 0.3
            local enemy = {
                x = center_x + math.cos(angle) * radius - ENEMY_WIDTH/2,
                y = self.reverse_gravity and (spawn_y_base + y_offset) or (spawn_y_base + y_offset),
                width = ENEMY_WIDTH, height = ENEMY_HEIGHT,
                movement_pattern = 'straight',
                speed_override = adjusted_speed * speed_multiplier,
                shoot_timer = i * 0.15,
                shoot_rate = base_shoot_rate,
                health = self.enemy_health
            }
            table.insert(self.enemies, enemy)
        end
    end
end

-- Space Invaders: Initialize grid
function SpaceShooter:initSpaceInvadersGrid()
    -- Calculate wave modifiers
    local wave_multiplier = 1.0 + (self.grid_state.wave_number * self.wave_difficulty_increase)

    -- Apply random variance if enabled
    local variance = self.wave_random_variance
    local random_factor = 1.0
    if variance > 0 then
        random_factor = 1.0 + ((math.random() - 0.5) * 2 * variance)  -- ±variance
    end

    -- Calculate modified parameters
    local wave_rows = math.max(1, math.floor(self.grid_rows * wave_multiplier * random_factor + 0.5))
    local wave_columns = math.max(2, math.floor(self.grid_columns * wave_multiplier * random_factor + 0.5))
    local wave_speed = self.grid_speed * wave_multiplier * random_factor
    local wave_health = math.max(1, math.floor(self.enemy_health * wave_multiplier + 0.5))

    local spacing_x = (self.game_width / (wave_columns + 1)) * self.enemy_density
    local spacing_y = 50 * self.enemy_density
    local start_y = 80

    for row = 1, wave_rows do
        for col = 1, wave_columns do
            local enemy = {
                x = spacing_x * col,
                y = start_y + (row - 1) * spacing_y,
                width = ENEMY_WIDTH,
                height = ENEMY_HEIGHT,
                movement_pattern = 'grid',  -- Special pattern for grid movement
                grid_row = row,
                grid_col = col,
                shoot_timer = math.random() * 3.0,
                shoot_rate = 2.0,
                health = wave_health,
                wave_speed = wave_speed  -- Store wave-specific speed
            }
            table.insert(self.enemies, enemy)
        end
    end

    self.grid_state.initialized = true
    self.grid_state.initial_enemy_count = wave_rows * wave_columns
    self.grid_state.wave_active = true
    self.grid_state.wave_number = self.grid_state.wave_number + 1
end

-- Space Invaders: Update grid movement
function SpaceShooter:updateSpaceInvadersGrid(dt)
    -- Wave system: Check if we need to start a new wave
    if self.waves_enabled then
        if self.grid_state.wave_active then
            -- Check if all grid enemies are dead
            local grid_enemies_alive = false
            for _, enemy in ipairs(self.enemies) do
                if enemy.movement_pattern == 'grid' then
                    grid_enemies_alive = true
                    break
                end
            end

            if not grid_enemies_alive and self.grid_state.initialized then
                -- Wave complete, start pause
                self.grid_state.wave_active = false
                self.grid_state.wave_pause_timer = self.wave_pause_duration
                self.grid_state.initialized = false  -- Reset for next wave
            end
        else
            -- In pause between waves
            self.grid_state.wave_pause_timer = self.grid_state.wave_pause_timer - dt
            if self.grid_state.wave_pause_timer <= 0 then
                -- Start new wave
                self:initSpaceInvadersGrid()
            end
            return  -- Don't update grid during pause
        end
    end

    -- Initialize grid if not yet done (first spawn or new wave)
    if not self.grid_state.initialized then
        self:initSpaceInvadersGrid()
    end

    -- Calculate speed multiplier based on remaining enemies
    local initial_count = self.grid_state.initial_enemy_count
    local current_count = 0
    for _, enemy in ipairs(self.enemies) do
        if enemy.movement_pattern == 'grid' then
            current_count = current_count + 1
        end
    end

    if current_count > 0 and initial_count > 0 then
        -- Speed increases as enemies die (fewer enemies = faster movement)
        self.grid_state.speed_multiplier = 1 + (1 - (current_count / initial_count)) * 2
    end

    -- Move the entire grid (use wave-specific speed if available)
    local base_speed = self.grid_speed
    -- Check if any enemy has wave_speed (they all should if from same wave)
    for _, enemy in ipairs(self.enemies) do
        if enemy.movement_pattern == 'grid' and enemy.wave_speed then
            base_speed = enemy.wave_speed
            break
        end
    end

    local move_speed = base_speed * self.grid_state.speed_multiplier * dt
    local grid_moved = false

    for _, enemy in ipairs(self.enemies) do
        if enemy.movement_pattern == 'grid' then
            enemy.x = enemy.x + (move_speed * self.grid_state.direction)
            grid_moved = true
        end
    end

    if not grid_moved then return end

    -- Check if grid hit edge
    local hit_edge = false
    for _, enemy in ipairs(self.enemies) do
        if enemy.movement_pattern == 'grid' then
            if self.grid_state.direction > 0 and enemy.x + ENEMY_WIDTH >= self.game_width then
                hit_edge = true
                break
            elseif self.grid_state.direction < 0 and enemy.x <= 0 then
                hit_edge = true
                break
            end
        end
    end

    -- Reverse direction and descend if hit edge
    if hit_edge then
        self.grid_state.direction = -self.grid_state.direction
        for _, enemy in ipairs(self.enemies) do
            if enemy.movement_pattern == 'grid' then
                enemy.y = enemy.y + self.grid_descent
            end
        end
    end
end

-- Galaga: Initialize formation positions
function SpaceShooter:initGalagaFormation()
    -- Create formation grid at top of screen with proper wrapping
    local base_spacing_x = 60  -- Base horizontal spacing between enemies
    local spacing_x = base_spacing_x * self.enemy_density
    local spacing_y = 40 * self.enemy_density
    local start_x = 50  -- Left margin
    local start_y = 60
    local margin_right = 50  -- Right margin

    self.galaga_state.formation_positions = {}  -- Clear existing positions

    -- Calculate how many columns fit on screen
    local available_width = self.game_width - start_x - margin_right
    local max_cols_per_row = math.floor(available_width / spacing_x)
    if max_cols_per_row < 1 then max_cols_per_row = 1 end

    -- Create formation with automatic row wrapping
    local total_slots = self.formation_size
    local current_row = 0
    local current_col = 0

    for i = 1, total_slots do
        -- Wrap to next row if we've filled this row
        if current_col >= max_cols_per_row then
            current_col = 0
            current_row = current_row + 1
        end

        table.insert(self.galaga_state.formation_positions, {
            x = start_x + (current_col * spacing_x),
            y = start_y + (current_row * spacing_y),
            occupied = false,
            enemy_id = nil
        })

        current_col = current_col + 1
    end

    self.galaga_state.initial_enemy_count = total_slots
    self.galaga_state.wave_active = true
end

-- Galaga: Spawn enemy with entrance pattern
function SpaceShooter:spawnGalagaEnemy(formation_slot, wave_modifiers)
    wave_modifiers = wave_modifiers or {}
    local wave_health = wave_modifiers.health or self.enemy_health
    local wave_dive_frequency = wave_modifiers.dive_frequency or self.dive_frequency

    -- Find entrance point off-screen
    local entrance_side = math.random() > 0.5 and "left" or "right"
    local start_x = entrance_side == "left" and -50 or (self.game_width + 50)
    local start_y = -50

    local enemy = {
        x = start_x,
        y = start_y,
        width = ENEMY_WIDTH,
        height = ENEMY_HEIGHT,
        movement_pattern = 'galaga_entering',
        galaga_state = 'entering',  -- entering, in_formation, diving
        formation_slot = formation_slot,
        formation_x = formation_slot.x,
        formation_y = formation_slot.y,
        entrance_t = 0,  -- Progress along entrance path (0-1)
        entrance_duration = 2.0,  -- Seconds to complete entrance
        shoot_timer = math.random() * 3.0,
        shoot_rate = 2.5,
        health = wave_health,
        wave_dive_frequency = wave_dive_frequency  -- Store wave-specific dive frequency
    }

    -- Create entrance path using bezier curve
    if self.entrance_pattern == "swoop" then
        -- Swoop down then up to formation
        enemy.entrance_path = {
            {x = start_x, y = start_y},
            {x = self.game_width / 2, y = self.game_height * 0.6},  -- Control point (swoop down)
            {x = formation_slot.x, y = formation_slot.y}
        }
    elseif self.entrance_pattern == "loop" then
        -- Loop around to formation
        local mid_x = entrance_side == "left" and self.game_width * 0.3 or self.game_width * 0.7
        enemy.entrance_path = {
            {x = start_x, y = start_y},
            {x = mid_x, y = self.game_height * 0.5},  -- Control point (loop)
            {x = formation_slot.x, y = formation_slot.y}
        }
    else -- "arc"
        -- Simple arc to formation
        enemy.entrance_path = {
            {x = start_x, y = start_y},
            {x = (start_x + formation_slot.x) / 2, y = self.game_height * 0.3},  -- Control point
            {x = formation_slot.x, y = formation_slot.y}
        }
    end

    formation_slot.occupied = true
    formation_slot.enemy_id = #self.enemies + 1

    table.insert(self.enemies, enemy)
end

-- Galaga: Update formation and dive mechanics
function SpaceShooter:updateGalagaFormation(dt)
    -- Wave system: Check if we need to start a new wave
    if self.waves_enabled then
        if self.galaga_state.wave_active then
            -- Check if all galaga enemies are dead
            local galaga_enemies_alive = false
            for _, enemy in ipairs(self.enemies) do
                if enemy.galaga_state then
                    galaga_enemies_alive = true
                    break
                end
            end

            if not galaga_enemies_alive and #self.galaga_state.formation_positions > 0 then
                -- Wave complete, start pause
                self.galaga_state.wave_active = false
                self.galaga_state.wave_pause_timer = self.wave_pause_duration
                -- Clear formation for next wave
                self.galaga_state.formation_positions = {}
            end
        else
            -- In pause between waves
            self.galaga_state.wave_pause_timer = self.galaga_state.wave_pause_timer - dt
            if self.galaga_state.wave_pause_timer <= 0 then
                -- Calculate wave modifiers for new wave
                local wave_multiplier = 1.0 + (self.galaga_state.wave_number * self.wave_difficulty_increase)
                local variance = self.wave_random_variance
                local random_factor = 1.0
                if variance > 0 then
                    random_factor = 1.0 + ((math.random() - 0.5) * 2 * variance)
                end

                local wave_modifiers = {
                    health = math.max(1, math.floor(self.enemy_health * wave_multiplier + 0.5)),
                    dive_frequency = self.dive_frequency / (wave_multiplier * random_factor)  -- Faster dives = harder
                }

                -- Start new wave
                self:initGalagaFormation()
                self.galaga_state.wave_number = self.galaga_state.wave_number + 1
                self.galaga_state.spawned_count = 0
                self.galaga_state.spawn_timer = 0
                self.galaga_state.wave_modifiers = wave_modifiers  -- Store for gradual spawning

                -- Spawn initial batch of enemies with modifiers
                local initial_count = math.min(self.initial_spawn_count, #self.galaga_state.formation_positions)
                for i = 1, initial_count do
                    local slot = self.galaga_state.formation_positions[i]
                    self:spawnGalagaEnemy(slot, wave_modifiers)
                    self.galaga_state.spawned_count = self.galaga_state.spawned_count + 1
                end
            end
            return  -- Don't update formation during pause
        end
    end

    -- Initialize formation if needed (first spawn)
    if #self.galaga_state.formation_positions == 0 then
        self:initGalagaFormation()
        self.galaga_state.spawned_count = 0
        self.galaga_state.spawn_timer = 0
        self.galaga_state.wave_modifiers = {}  -- No modifiers for first wave

        -- Spawn initial batch of enemies
        local initial_count = math.min(self.initial_spawn_count, #self.galaga_state.formation_positions)
        for i = 1, initial_count do
            local slot = self.galaga_state.formation_positions[i]
            self:spawnGalagaEnemy(slot, self.galaga_state.wave_modifiers)
            self.galaga_state.spawned_count = self.galaga_state.spawned_count + 1
        end
    end

    -- Gradual enemy spawning until formation is full
    local unoccupied_slots = {}
    for _, slot in ipairs(self.galaga_state.formation_positions) do
        if not slot.occupied then
            table.insert(unoccupied_slots, slot)
        end
    end

    if #unoccupied_slots > 0 and self.galaga_state.spawned_count < self.formation_size then
        self.galaga_state.spawn_timer = self.galaga_state.spawn_timer - dt
        if self.galaga_state.spawn_timer <= 0 then
            -- Spawn one enemy into a random unoccupied slot
            local slot = unoccupied_slots[math.random(1, #unoccupied_slots)]
            self:spawnGalagaEnemy(slot, self.galaga_state.wave_modifiers)
            self.galaga_state.spawned_count = self.galaga_state.spawned_count + 1
            self.galaga_state.spawn_timer = self.galaga_spawn_interval
        end
    end

    -- Update dive timer
    self.galaga_state.dive_timer = self.galaga_state.dive_timer - dt
    if self.galaga_state.dive_timer <= 0 and self.galaga_state.diving_count < self.max_diving_enemies then
        -- Pick a random enemy in formation to dive
        local candidates = {}
        for _, enemy in ipairs(self.enemies) do
            if enemy.galaga_state == 'in_formation' then
                table.insert(candidates, enemy)
            end
        end

        if #candidates > 0 then
            local diver = candidates[math.random(1, #candidates)]
            diver.galaga_state = 'diving'
            diver.dive_t = 0
            diver.dive_duration = 3.0
            -- Create dive path (swoop down toward player, then off-screen)
            diver.dive_path = {
                {x = diver.x, y = diver.y},
                {x = self.player.x, y = self.player.y},  -- Dive toward player
                {x = diver.x, y = self.game_height + 50}  -- Exit off bottom
            }
            self.galaga_state.diving_count = self.galaga_state.diving_count + 1
        end

        self.galaga_state.dive_timer = self.dive_frequency
    end

    -- Update enemy positions based on state
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]

        if enemy.galaga_state == 'entering' then
            -- Move along entrance path
            enemy.entrance_t = enemy.entrance_t + (dt / enemy.entrance_duration)
            if enemy.entrance_t >= 1.0 then
                -- Reached formation
                enemy.galaga_state = 'in_formation'
                enemy.x = enemy.formation_x
                enemy.y = enemy.formation_y
                enemy.movement_pattern = 'formation'
            else
                -- Quadratic bezier interpolation
                local t = enemy.entrance_t
                local p0 = enemy.entrance_path[1]
                local p1 = enemy.entrance_path[2]
                local p2 = enemy.entrance_path[3]
                enemy.x = (1-t)*(1-t)*p0.x + 2*(1-t)*t*p1.x + t*t*p2.x
                enemy.y = (1-t)*(1-t)*p0.y + 2*(1-t)*t*p1.y + t*t*p2.y
            end

        elseif enemy.galaga_state == 'in_formation' then
            -- Stay at formation position
            enemy.x = enemy.formation_x
            enemy.y = enemy.formation_y

        elseif enemy.galaga_state == 'diving' then
            -- Move along dive path
            enemy.dive_t = enemy.dive_t + (dt / enemy.dive_duration)
            if enemy.dive_t >= 1.0 then
                -- Dive complete - respawn with new entrance
                table.remove(self.enemies, i)
                self.galaga_state.diving_count = self.galaga_state.diving_count - 1
                -- Mark formation slot as unoccupied
                if enemy.formation_slot then
                    enemy.formation_slot.occupied = false
                    -- Respawn enemy after a delay (handled by checking unoccupied slots)
                    self:spawnGalagaEnemy(enemy.formation_slot, self.galaga_state.wave_modifiers)
                end
            else
                -- Quadratic bezier interpolation
                local t = enemy.dive_t
                local p0 = enemy.dive_path[1]
                local p1 = enemy.dive_path[2]
                local p2 = enemy.dive_path[3]
                enemy.x = (1-t)*(1-t)*p0.x + 2*(1-t)*t*p1.x + t*t*p2.x
                enemy.y = (1-t)*(1-t)*p0.y + 2*(1-t)*t*p1.y + t*t*p2.y
            end
        end
    end
end

-- Phase 5: Wave spawning logic
function SpaceShooter:updateWaveSpawning(dt)
    if self.wave_state.active then
        -- Spawn enemies in current wave
        self.spawn_timer = self.spawn_timer - dt
        if self.spawn_timer <= 0 and self.wave_state.enemies_remaining > 0 then
            self:spawnEnemy()
            self.wave_state.enemies_remaining = self.wave_state.enemies_remaining - 1
            self.spawn_timer = 0.3  -- Quick spawn within wave

            if self.wave_state.enemies_remaining <= 0 then
                -- Wave complete, start pause
                self.wave_state.active = false
                self.wave_state.pause_timer = self.wave_state.pause_duration
            end
        end
    else
        -- In pause between waves
        self.wave_state.pause_timer = self.wave_state.pause_timer - dt
        if self.wave_state.pause_timer <= 0 then
            -- Start new wave
            self.wave_state.active = true
            self.wave_state.enemies_remaining = math.floor(self.wave_state.enemies_per_wave * self.difficulty_scale)
            self.spawn_timer = 0  -- Spawn immediately
        end
    end
end

-- Phase 5: Difficulty scaling
function SpaceShooter:updateDifficulty(dt)
    local scaling_factor = self.difficulty_scaling_rate * dt

    if self.difficulty_curve == "linear" then
        -- Steady linear increase
        self.difficulty_scale = self.difficulty_scale + scaling_factor
    elseif self.difficulty_curve == "exponential" then
        -- Exponential growth (multiplicative)
        self.difficulty_scale = self.difficulty_scale * (1 + scaling_factor)
    elseif self.difficulty_curve == "wave" then
        -- Sine wave difficulty (alternating hard/easy)
        local time_factor = self.time_elapsed * 0.5
        self.difficulty_scale = 1.0 + math.sin(time_factor) * 0.5
    end

    -- Cap difficulty scale to reasonable values
    self.difficulty_scale = math.min(self.difficulty_scale, 5.0)
end

-- Phase 7: Asteroid system
function SpaceShooter:updateAsteroids(dt)
    -- Spawn asteroids based on density
    self.asteroid_spawn_timer = self.asteroid_spawn_timer - dt
    local spawn_interval = 1.0 / self.asteroid_density  -- Higher density = more frequent spawns
    if self.asteroid_spawn_timer <= 0 then
        self:spawnAsteroid()
        self.asteroid_spawn_timer = spawn_interval
    end

    -- Update existing asteroids
    for i = #self.asteroids, 1, -1 do
        local asteroid = self.asteroids[i]
        -- Phase 8: Respect reverse gravity for asteroid movement
        local speed_direction = self.reverse_gravity and -1 or 1
        asteroid.y = asteroid.y + (self.asteroid_speed + self.scroll_speed) * speed_direction * dt
        asteroid.rotation = asteroid.rotation + asteroid.rotation_speed * dt

        -- Check collision with player
        if self:checkCollision(asteroid, self.player) then
            self:handlePlayerDamage()
            table.remove(self.asteroids, i)
            goto continue_asteroid
        end

        -- Check collision with player bullets (if destructible)
        if self.asteroids_can_be_destroyed then
            for j = #self.player_bullets, 1, -1 do
                local bullet = self.player_bullets[j]
                if self:checkCollision(asteroid, bullet) then
                    table.remove(self.asteroids, i)
                    if not self.bullet_piercing then
                        table.remove(self.player_bullets, j)
                    end
                    goto continue_asteroid
                end
            end
        end

        -- Check collision with enemies
        for j = #self.enemies, 1, -1 do
            local enemy = self.enemies[j]
            if self:checkCollision(asteroid, enemy) then
                table.remove(self.enemies, j)
                table.remove(self.asteroids, i)
                goto continue_asteroid
            end
        end

        -- Remove if off screen
        -- Phase 8: In reverse gravity, remove when going off top; otherwise remove when going off bottom
        local off_screen = self.reverse_gravity and (asteroid.y + asteroid.height < 0) or (asteroid.y > self.game_height + asteroid.height)
        if off_screen then
            table.remove(self.asteroids, i)
        end

        ::continue_asteroid::
    end
end

function SpaceShooter:spawnAsteroid()
    local size = math.random(self.asteroid_size_min, self.asteroid_size_max)
    -- Phase 8: Respect reverse gravity for asteroid spawning
    local spawn_y = self.reverse_gravity and self.game_height or -size
    table.insert(self.asteroids, {
        x = math.random(0, self.game_width - size),
        y = spawn_y,
        width = size,
        height = size,
        rotation = math.random() * math.pi * 2,
        rotation_speed = (math.random() - 0.5) * 2  -- Random spin
    })
end

-- Phase 7: Meteor shower system
function SpaceShooter:updateMeteors(dt)
    -- Countdown to next meteor wave
    self.meteor_timer = self.meteor_timer - dt
    if self.meteor_timer <= 0 then
        self:spawnMeteorWave()
        self.meteor_timer = 60 / self.meteor_frequency  -- Convert frequency to interval
    end

    -- Update meteor warnings
    for i = #self.meteor_warnings, 1, -1 do
        local warning = self.meteor_warnings[i]
        warning.time_remaining = warning.time_remaining - dt
        if warning.time_remaining <= 0 then
            -- Phase 8: Respect reverse gravity for meteor spawning
            local spawn_y = self.reverse_gravity and self.game_height or -30
            -- Spawn actual meteor
            table.insert(self.meteors, {
                x = warning.x,
                y = spawn_y,
                width = 30,
                height = 30,
                speed = self.meteor_speed
            })
            table.remove(self.meteor_warnings, i)
        end
    end

    -- Update active meteors
    for i = #self.meteors, 1, -1 do
        local meteor = self.meteors[i]
        -- Phase 8: Respect reverse gravity for meteor movement
        local speed_direction = self.reverse_gravity and -1 or 1
        meteor.y = meteor.y + (meteor.speed + self.scroll_speed) * speed_direction * dt

        -- Check collision with player
        if self:checkCollision(meteor, self.player) then
            self:handlePlayerDamage()
            table.remove(self.meteors, i)
            goto continue_meteor
        end

        -- Check collision with player bullets
        for j = #self.player_bullets, 1, -1 do
            local bullet = self.player_bullets[j]
            if self:checkCollision(meteor, bullet) then
                table.remove(self.meteors, i)
                if not self.bullet_piercing then
                    table.remove(self.player_bullets, j)
                end
                goto continue_meteor
            end
        end

        -- Remove if off screen
        -- Phase 8: In reverse gravity, remove when going off top; otherwise remove when going off bottom
        local off_screen = self.reverse_gravity and (meteor.y + meteor.height < 0) or (meteor.y > self.game_height + meteor.height)
        if off_screen then
            table.remove(self.meteors, i)
        end

        ::continue_meteor::
    end
end

function SpaceShooter:spawnMeteorWave()
    -- Spawn 3-5 meteor warnings
    local count = math.random(3, 5)
    for i = 1, count do
        table.insert(self.meteor_warnings, {
            x = math.random(0, self.game_width - 30),
            time_remaining = self.meteor_warning_time
        })
    end
end

-- Phase 7: Gravity well system
function SpaceShooter:applyGravityWells(dt)
    -- Apply gravity to player
    for _, well in ipairs(self.gravity_wells) do
        local dx = well.x - (self.player.x + self.player.width / 2)
        local dy = well.y - (self.player.y + self.player.height / 2)
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance < well.radius and distance > 0 then
            -- Calculate pull strength (inverse square law, clamped)
            local pull_factor = math.min(1.0, well.radius / distance)
            local pull = well.strength * pull_factor * dt

            -- Apply pull to player position
            local angle = math.atan2(dy, dx)
            self.player.x = self.player.x + math.cos(angle) * pull * dt
            self.player.y = self.player.y + math.sin(angle) * pull * dt

            -- Keep player in bounds
            self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
            self.player.y = math.max(0, math.min(self.game_height - self.player.height, self.player.y))
        end
    end

    -- Apply gravity to player bullets
    for _, bullet in ipairs(self.player_bullets) do
        for _, well in ipairs(self.gravity_wells) do
            local dx = well.x - bullet.x
            local dy = well.y - bullet.y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance < well.radius and distance > 0 then
                local pull_factor = math.min(1.0, well.radius / distance)
                local pull = well.strength * pull_factor * dt * 0.7  -- Slightly weaker effect on bullets

                local angle = math.atan2(dy, dx)
                bullet.x = bullet.x + math.cos(angle) * pull
                bullet.y = bullet.y + math.sin(angle) * pull
            end
        end
    end
end

-- Phase 7: Vertical scrolling
function SpaceShooter:updateScrolling(dt)
    self.scroll_offset = self.scroll_offset + self.scroll_speed * dt

    -- Scroll effect already applied in enemy/asteroid movement
    -- This function can be extended for visual background scrolling
end

-- Phase 8: Screen wrap helper
-- Returns true if object should be destroyed (exceeded max wraps)
function SpaceShooter:applyScreenWrap(obj, max_wraps)
    -- Phase 5: Use PhysicsUtils for screen wrap
    max_wraps = max_wraps or 999  -- Default to effectively unlimited

    local old_x, old_y = obj.x, obj.y
    obj.x, obj.y = PhysicsUtils.wrapPosition(
        obj.x, obj.y, obj.width, obj.height,
        self.game_width, self.game_height
    )

    local wrapped = (obj.x ~= old_x or obj.y ~= old_y)

    -- Increment wrap count if object wrapped
    if wrapped and obj.wrap_count ~= nil then
        obj.wrap_count = obj.wrap_count + 1
        if obj.wrap_count > max_wraps then
            return true  -- Should be destroyed
        end
    end

    return false  -- Keep alive
end

-- Phase 8: Blackout zones movement
function SpaceShooter:updateBlackoutZones(dt)
    for _, zone in ipairs(self.blackout_zones) do
        zone.x = zone.x + zone.vx * dt
        zone.y = zone.y + zone.vy * dt

        -- Bounce off walls
        if zone.x < zone.radius or zone.x > self.game_width - zone.radius then
            zone.vx = -zone.vx
            zone.x = math.max(zone.radius, math.min(self.game_width - zone.radius, zone.x))
        end
        if zone.y < zone.radius or zone.y > self.game_height - zone.radius then
            zone.vy = -zone.vy
            zone.y = math.max(zone.radius, math.min(self.game_height - zone.radius, zone.y))
        end
    end
end

return SpaceShooter