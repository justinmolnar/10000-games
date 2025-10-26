local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local Collision = require('src.utils.collision')
local DodgeView = require('src.games.views.dodge_view')
local DodgeGame = BaseGame:extend('DodgeGame')

-- Enemy type definitions (Phase 1.4)
-- These define the behaviors that variants can compose from
DodgeGame.ENEMY_TYPES = {
    chaser = {
        name = "chaser",
        base_type = "seeker",  -- Maps to existing seeker behavior
        speed_multiplier = 0.9,
        description = "Homes in on player position"
    },
    shooter = {
        name = "shooter",
        base_type = "shooter",  -- New behavior (fires projectiles)
        speed_multiplier = 0.7,
        shoot_interval = 2.0,
        description = "Fires projectiles at player"
    },
    bouncer = {
        name = "bouncer",
        base_type = "bouncer",  -- New behavior (bounces off walls)
        speed_multiplier = 1.0,
        description = "Bounces off walls in predictable patterns"
    },
    zigzag = {
        name = "zigzag",
        base_type = "zigzag",  -- Maps to existing zigzag behavior
        speed_multiplier = 1.1,
        description = "Moves in zigzag pattern across screen"
    },
    teleporter = {
        name = "teleporter",
        base_type = "teleporter",  -- New behavior (teleports)
        speed_multiplier = 0.8,
        teleport_interval = 3.0,
        teleport_range = 100,
        description = "Disappears and reappears near player"
    }
}

-- Config-driven tunables with safe fallbacks (preserve previous behavior)
local DodgeCfg = (Config and Config.games and Config.games.dodge) or {}
local PLAYER_SIZE = (DodgeCfg.player and DodgeCfg.player.size) or 20
local PLAYER_RADIUS = PLAYER_SIZE
local PLAYER_SPEED = (DodgeCfg.player and DodgeCfg.player.speed) or 300
local PLAYER_ROTATION_SPEED = (DodgeCfg.player and DodgeCfg.player.rotation_speed) or 8.0
local OBJECT_SIZE = (DodgeCfg.objects and DodgeCfg.objects.size) or 15
local OBJECT_RADIUS = OBJECT_SIZE
local BASE_SPAWN_RATE = (DodgeCfg.objects and DodgeCfg.objects.base_spawn_rate) or 1.0
local BASE_OBJECT_SPEED = (DodgeCfg.objects and DodgeCfg.objects.base_speed) or 200
local WARNING_TIME = (DodgeCfg.objects and DodgeCfg.objects.warning_time) or 0.5
local MAX_COLLISIONS = (DodgeCfg.collisions and DodgeCfg.collisions.max) or 10
local BASE_DODGE_TARGET = DodgeCfg.base_target or 30
local MIN_SAFE_RADIUS_FRACTION = (DodgeCfg.arena and DodgeCfg.arena.min_safe_radius_fraction) or 0.35 -- of min(width,height)
local SAFE_ZONE_SHRINK_SEC = (DodgeCfg.arena and DodgeCfg.arena.safe_zone_shrink_sec) or 45 -- time to reach min radius at base difficulty
local INITIAL_SAFE_RADIUS_FRACTION = (DodgeCfg.arena and DodgeCfg.arena.initial_safe_radius_fraction) or 0.48
local TARGET_RING_MIN_SCALE = (DodgeCfg.arena and DodgeCfg.arena.target_ring and DodgeCfg.arena.target_ring.min_scale) or 1.2
local TARGET_RING_MAX_SCALE = (DodgeCfg.arena and DodgeCfg.arena.target_ring and DodgeCfg.arena.target_ring.max_scale) or 1.5

function DodgeGame:init(game_data, cheats, di)
    DodgeGame.super.init(self, game_data, cheats, di)
    self.di = di
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.dodge) or DodgeCfg

    -- Apply variant difficulty modifier (from Phase 1.1-1.2)
    local variant_difficulty = self.variant and self.variant.difficulty_modifier or 1.0

    local speed_modifier = self.cheats.speed_modifier or 1.0
    local advantage_modifier = self.cheats.advantage_modifier or {}
    local extra_collisions = advantage_modifier.collisions or 0

    self.OBJECT_SIZE = (runtimeCfg and runtimeCfg.objects and runtimeCfg.objects.size) or OBJECT_SIZE
    self.MAX_COLLISIONS = ((runtimeCfg and runtimeCfg.collisions and runtimeCfg.collisions.max) or MAX_COLLISIONS) + extra_collisions

    self.game_width = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.width) or (DodgeCfg.arena and DodgeCfg.arena.width) or 400
    self.game_height = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.height) or (DodgeCfg.arena and DodgeCfg.arena.height) or 400

    -- Per-variant rotation speed (fallback to runtime config, then file constant)
    local rotation_speed = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.rotation_speed) or PLAYER_ROTATION_SPEED
    if self.variant and self.variant.rotation_speed then
        rotation_speed = self.variant.rotation_speed
    end

    -- Per-variant movement speed (fallback to runtime config, then file constant)
    local movement_speed = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.speed) or PLAYER_SPEED
    if self.variant and self.variant.movement_speed then
        movement_speed = self.variant.movement_speed
    end

    -- Per-variant movement type (default or asteroids)
    local movement_type = "default"
    if self.variant and self.variant.movement_type then
        movement_type = self.variant.movement_type
    end

    -- Universal physics properties (apply to all movement types)
    -- Separate friction for acceleration (start-up) and deceleration (stopping)
    local accel_friction = 1.0  -- Default: no friction when accelerating
    if self.variant and self.variant.accel_friction ~= nil then
        accel_friction = self.variant.accel_friction
    end

    local decel_friction = 1.0  -- Default: no friction when decelerating
    if self.variant and self.variant.decel_friction ~= nil then
        decel_friction = self.variant.decel_friction
    end

    local bounce_damping = 0.5  -- Default: 50% bounce
    if self.variant and self.variant.bounce_damping ~= nil then
        bounce_damping = self.variant.bounce_damping
    end

    -- Asteroids-specific: reverse mode (down key behavior)
    local reverse_mode = "none"  -- "none", "brake", or "thrust"
    if self.variant and self.variant.reverse_mode then
        reverse_mode = self.variant.reverse_mode
    end

    -- Jump-specific: jump distance and cooldown
    local jump_distance = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.jump_distance) or 80
    if self.variant and self.variant.jump_distance ~= nil then
        jump_distance = self.variant.jump_distance
    end

    local jump_cooldown = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.jump_cooldown) or 0.5
    if self.variant and self.variant.jump_cooldown ~= nil then
        jump_cooldown = self.variant.jump_cooldown
    end

    local jump_speed = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.jump_speed) or 800
    if self.variant and self.variant.jump_speed ~= nil then
        jump_speed = self.variant.jump_speed
    end

    -- New player parameters
    local player_size = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.player_size) or 1.0
    if self.variant and self.variant.player_size ~= nil then
        player_size = self.variant.player_size
    end

    local max_speed = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.max_speed) or 600
    if self.variant and self.variant.max_speed ~= nil then
        max_speed = self.variant.max_speed
    end

    local lives = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.lives) or 10
    if self.variant and self.variant.lives ~= nil then
        lives = self.variant.lives
    end

    local shield = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.shield) or 0
    if self.variant and self.variant.shield ~= nil then
        shield = self.variant.shield
    end

    local shield_recharge_time = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.shield_recharge_time) or 0
    if self.variant and self.variant.shield_recharge_time ~= nil then
        shield_recharge_time = self.variant.shield_recharge_time
    end

    -- New obstacle parameters
    local obstacle_tracking = (runtimeCfg and runtimeCfg.objects and runtimeCfg.objects.tracking) or 0.0
    if self.variant and self.variant.obstacle_tracking ~= nil then
        obstacle_tracking = self.variant.obstacle_tracking
    end

    local obstacle_speed_variance = (runtimeCfg and runtimeCfg.objects and runtimeCfg.objects.speed_variance) or 0.0
    if self.variant and self.variant.obstacle_speed_variance ~= nil then
        obstacle_speed_variance = self.variant.obstacle_speed_variance
    end

    local obstacle_spawn_rate = (runtimeCfg and runtimeCfg.objects and runtimeCfg.objects.spawn_rate_multiplier) or 1.0
    if self.variant and self.variant.obstacle_spawn_rate ~= nil then
        obstacle_spawn_rate = self.variant.obstacle_spawn_rate
    end

    local obstacle_spawn_pattern = (runtimeCfg and runtimeCfg.objects and runtimeCfg.objects.spawn_pattern) or "random"
    if self.variant and self.variant.obstacle_spawn_pattern then
        obstacle_spawn_pattern = self.variant.obstacle_spawn_pattern
    end

    local obstacle_size_variance = (runtimeCfg and runtimeCfg.objects and runtimeCfg.objects.size_variance) or 0.0
    if self.variant and self.variant.obstacle_size_variance ~= nil then
        obstacle_size_variance = self.variant.obstacle_size_variance
    end

    local obstacle_trails = (runtimeCfg and runtimeCfg.objects and runtimeCfg.objects.trails) or 0
    if self.variant and self.variant.obstacle_trails ~= nil then
        obstacle_trails = self.variant.obstacle_trails
    end

    -- New environment parameters
    local area_gravity = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.gravity) or 0.0
    if self.variant and self.variant.area_gravity ~= nil then
        area_gravity = self.variant.area_gravity
    end

    local wind_direction = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.wind_direction) or 0
    if self.variant and self.variant.wind_direction ~= nil then
        wind_direction = self.variant.wind_direction
    end

    local wind_strength = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.wind_strength) or 0
    if self.variant and self.variant.wind_strength ~= nil then
        wind_strength = self.variant.wind_strength
    end

    local wind_type = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.wind_type) or "none"
    if self.variant and self.variant.wind_type then
        wind_type = self.variant.wind_type
    end

    -- New visual parameters
    local fog_origin = (runtimeCfg and runtimeCfg.view and runtimeCfg.view.fog_origin) or "none"
    if self.variant and self.variant.fog_of_war_origin then
        fog_origin = self.variant.fog_of_war_origin
    end

    local fog_radius = (runtimeCfg and runtimeCfg.view and runtimeCfg.view.fog_radius) or 9999
    if self.variant and self.variant.fog_of_war_radius ~= nil then
        fog_radius = self.variant.fog_of_war_radius
    end

    local camera_shake = (runtimeCfg and runtimeCfg.view and runtimeCfg.view.camera_shake) or 0.0
    if self.variant and self.variant.camera_shake_intensity ~= nil then
        camera_shake = self.variant.camera_shake_intensity
    end

    local player_trail = (runtimeCfg and runtimeCfg.view and runtimeCfg.view.player_trail) or 0
    if self.variant and self.variant.player_trail_length ~= nil then
        player_trail = self.variant.player_trail_length
    end

    local score_mode = (runtimeCfg and runtimeCfg.view and runtimeCfg.view.score_mode) or "none"
    if self.variant and self.variant.score_multiplier_mode then
        score_mode = self.variant.score_multiplier_mode
    end

    -- New victory parameters
    local victory_condition = (runtimeCfg and runtimeCfg.victory and runtimeCfg.victory.condition) or "dodge_count"
    if self.variant and self.variant.victory_condition then
        victory_condition = self.variant.victory_condition
    end

    local victory_limit = (runtimeCfg and runtimeCfg.victory and runtimeCfg.victory.limit) or BASE_DODGE_TARGET
    if self.variant and self.variant.victory_limit ~= nil then
        victory_limit = self.variant.victory_limit
    end

    -- Store new parameters as instance variables for access throughout the game
    self.lives = lives
    self.obstacle_tracking = obstacle_tracking
    self.obstacle_speed_variance = obstacle_speed_variance
    self.obstacle_spawn_rate = obstacle_spawn_rate
    self.obstacle_spawn_pattern = obstacle_spawn_pattern
    self.obstacle_size_variance = obstacle_size_variance
    self.obstacle_trails = obstacle_trails
    self.area_gravity = area_gravity
    self.wind_direction = wind_direction
    self.wind_strength = wind_strength
    self.wind_type = wind_type
    self.fog_origin = fog_origin
    self.fog_radius = fog_radius
    self.camera_shake = camera_shake
    self.player_trail_length = player_trail
    self.score_mode = score_mode
    self.victory_condition = victory_condition
    self.victory_limit = victory_limit

    -- Initialize wind state
    self.wind_timer = 0
    self.wind_current_angle = type(wind_direction) == "number" and math.rad(wind_direction) or math.random() * math.pi * 2

    -- Initialize spawn pattern state
    self.spawn_pattern_state = {
        wave_timer = 0,
        wave_active = false,
        spiral_angle = 0,
        cluster_pending = 0
    }

    -- Initialize player trail buffer
    self.player_trail_buffer = {}

    -- Initialize camera shake state
    self.camera_shake_active = 0  -- Current shake intensity
    self.camera_shake_decay = 0.9  -- Decay rate per frame

    -- Initialize score tracking for multiplier modes
    self.avg_speed_tracker = { sum = 0, count = 0 }
    self.center_time_tracker = { total_weighted = 0, total_time = 0 }
    self.edge_time_tracker = { total_weighted = 0, total_time = 0 }

    self.player = {
        x = self.game_width / 2,
        y = self.game_height / 2,
        size = PLAYER_SIZE * player_size,  -- Apply size multiplier
        radius = PLAYER_RADIUS * player_size,  -- Apply size multiplier to radius
        rotation = 0,  -- Current rotation angle in radians (0 = facing right)
        rotation_speed = rotation_speed,  -- Store per-variant rotation speed
        movement_speed = movement_speed,  -- Store per-variant movement speed
        max_speed = max_speed,  -- Store max speed cap
        movement_type = movement_type,    -- Store per-variant movement type
        accel_friction = accel_friction,  -- Friction when accelerating (1.0 = none, <1.0 = resistance)
        decel_friction = decel_friction,  -- Friction when decelerating/stopping (1.0 = instant stop, <1.0 = drift)
        bounce_damping = bounce_damping,  -- Universal bounce damping
        reverse_mode = reverse_mode,      -- Asteroids reverse mode
        jump_distance = jump_distance,    -- Jump mode: how far each jump goes
        jump_cooldown = jump_cooldown,    -- Jump mode: time between jumps
        jump_speed = jump_speed,          -- Jump mode: speed of the jump movement (px/sec)
        last_jump_time = -999,            -- Jump mode: timestamp of last jump (start ready to jump)
        is_jumping = false,               -- Jump mode: currently mid-jump
        jump_target_x = 0,                -- Jump mode: target x position
        jump_target_y = 0,                -- Jump mode: target y position
        jump_dir_x = 0,                   -- Jump mode: normalized direction x
        jump_dir_y = 0,                   -- Jump mode: normalized direction y
        vx = 0,  -- Velocity (used in asteroids mode, and optionally in default mode if friction < 1.0)
        vy = 0,   -- Velocity
        -- Shield system
        shield_charges = shield,  -- Current shield count
        shield_max = shield,  -- Maximum shield charges
        shield_recharge_timer = shield_recharge_time,  -- Countdown to next recharge
        shield_recharge_time = shield_recharge_time  -- Time between recharges
    }

    self.objects = {}
    self.warnings = {}
    self.time_elapsed = 0

    self.spawn_rate = ((BASE_SPAWN_RATE / self.difficulty_modifiers.count) / variant_difficulty) / self.obstacle_spawn_rate
    self.object_speed = ((BASE_OBJECT_SPEED * self.difficulty_modifiers.speed) * speed_modifier) * variant_difficulty
    self.warning_enabled = self.difficulty_modifiers.complexity <= ((DodgeCfg.warnings and DodgeCfg.warnings.complexity_threshold) or 2)

    -- Use victory_limit if condition is dodge_count, otherwise calculate from base_target
    if self.victory_condition == "dodge_count" then
        self.dodge_target = math.floor(self.victory_limit)
    else
        -- For time-based victory, still track dodges for metrics but no specific target
        self.dodge_target = 9999
    end

    -- Enemy composition from variant (Phase 1.3)
    -- NOTE: Enemy spawning will be implemented when assets are ready (Phase 2+)
    self.enemy_composition = {}
    if self.variant and self.variant.enemies then
        for _, enemy_def in ipairs(self.variant.enemies) do
            self.enemy_composition[enemy_def.type] = enemy_def.multiplier
        end
    end

    self.spawn_timer = 0

    self.metrics.objects_dodged = 0
    self.metrics.collisions = 0
    self.metrics.perfect_dodges = 0

    -- Phase 2.3: Load variant assets (with fallback to icons)
    self:loadAssets()

    self.view = DodgeView:new(self, self.variant)
    print("[DodgeGame:init] Initialized with default game dimensions:", self.game_width, self.game_height)
    print("[DodgeGame:init] Variant:", self.variant and self.variant.name or "Default")

    -- Load per-variant safe zone customization properties
    local area_size = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.area_size) or 1.0
    if self.variant and self.variant.area_size ~= nil then
        area_size = self.variant.area_size
    end

    local area_morph_type = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.area_morph_type) or "shrink"
    if self.variant and self.variant.area_morph_type then
        area_morph_type = self.variant.area_morph_type
    end

    local area_morph_speed = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.area_morph_speed) or 1.0
    if self.variant and self.variant.area_morph_speed ~= nil then
        area_morph_speed = self.variant.area_morph_speed
    end

    local area_movement_speed = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.area_movement_speed) or 1.0
    if self.variant and self.variant.area_movement_speed ~= nil then
        area_movement_speed = self.variant.area_movement_speed
    end

    local area_movement_type = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.area_movement_type) or "random"
    if self.variant and self.variant.area_movement_type then
        area_movement_type = self.variant.area_movement_type
    end

    local area_friction = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.area_friction) or 1.0
    if self.variant and self.variant.area_friction ~= nil then
        area_friction = self.variant.area_friction
    end

    local area_shape = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.area_shape) or "circle"
    if self.variant and self.variant.area_shape then
        area_shape = self.variant.area_shape
    end

    -- Load per-variant game over properties
    local leaving_area_ends_game = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.leaving_area_ends_game) or false
    if self.variant and self.variant.leaving_area_ends_game ~= nil then
        leaving_area_ends_game = self.variant.leaving_area_ends_game
    end

    local holes_type = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.holes_type) or "none"
    if self.variant and self.variant.holes_type then
        holes_type = self.variant.holes_type
    end

    local holes_count = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.holes_count) or 0
    if self.variant and self.variant.holes_count ~= nil then
        holes_count = self.variant.holes_count
    end

    -- Safe zone (Undertale-like arena)
    local min_dim = math.min(self.game_width, self.game_height)
    local level_scale = 1 + ((DodgeCfg.drift and DodgeCfg.drift.level_scale_add_per_level) or 0.15) * math.max(0, (self.difficulty_level or 1) - 1)
    local drift_speed = ((DodgeCfg.drift and DodgeCfg.drift.base_speed) or 45) * level_scale

    -- Calculate initial target velocity based on area_movement_type
    local target_vx, target_vy = 0, 0
    if area_movement_type == "random" then
        -- Random drift (current default behavior)
        local drift_angle = math.random() * math.pi * 2
        target_vx = math.cos(drift_angle) * drift_speed * area_movement_speed
        target_vy = math.sin(drift_angle) * drift_speed * area_movement_speed
    elseif area_movement_type == "cardinal" then
        -- Start with random cardinal direction
        local cardinal_dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
        local dir = cardinal_dirs[math.random(1, 4)]
        target_vx = dir[1] * drift_speed * area_movement_speed
        target_vy = dir[2] * drift_speed * area_movement_speed
    elseif area_movement_type == "none" then
        -- No movement
        target_vx, target_vy = 0, 0
    end

    -- Apply area_size multiplier to initial and min radius
    local initial_radius = min_dim * INITIAL_SAFE_RADIUS_FRACTION * area_size
    local min_radius = min_dim * MIN_SAFE_RADIUS_FRACTION * area_size

    self.safe_zone = {
        x = self.game_width / 2,
        y = self.game_height / 2,
        radius = initial_radius,
        initial_radius = initial_radius,  -- Store for pulsing
        min_radius = min_radius,
        shrink_speed = (initial_radius - min_radius) / (SAFE_ZONE_SHRINK_SEC / self.difficulty_modifiers.complexity),
        -- Velocity system with friction
        vx = target_vx,  -- Current velocity
        vy = target_vy,
        target_vx = target_vx,  -- Target velocity for friction interpolation
        target_vy = target_vy,
        -- Area customization properties
        area_size = area_size,
        area_morph_type = area_morph_type,
        area_morph_speed = area_morph_speed,
        area_movement_speed = area_movement_speed,
        area_movement_type = area_movement_type,
        area_friction = area_friction,
        area_shape = area_shape,
        -- Morph state
        morph_time = 0,  -- Timer for pulsing/shape shifting
        shape_index = 1,  -- Current shape index for shape shifting
        -- Movement state
        direction_timer = 0,  -- Timer for changing cardinal/random direction
        direction_change_interval = 2.0  -- Change direction every 2 seconds
    }

    -- Initialize holes
    self.holes = {}
    if holes_count > 0 and holes_type ~= "none" then
        for i = 1, holes_count do
            local hole = { radius = 8 }  -- Simple circle holes for now

            if holes_type == "circle" then
                -- Position on safe zone boundary (clustered randomly)
                local angle = math.random() * math.pi * 2
                hole.angle = angle  -- Store angle for updating position
                hole.x = self.safe_zone.x + math.cos(angle) * self.safe_zone.radius
                hole.y = self.safe_zone.y + math.sin(angle) * self.safe_zone.radius
                hole.on_boundary = true
            elseif holes_type == "background" then
                -- Random static position in arena
                hole.x = math.random(hole.radius, self.game_width - hole.radius)
                hole.y = math.random(hole.radius, self.game_height - hole.radius)
                hole.on_boundary = false
            end

            table.insert(self.holes, hole)
        end
    end

    -- Game over state
    self.game_over = false
    self.leaving_area_ends_game = leaving_area_ends_game
end

-- Phase 2.3: Load sprite assets from variant.sprite_set
function DodgeGame:loadAssets()
    self.sprites = {}  -- Store loaded sprites

    if not self.variant or not self.variant.sprite_set then
        print("[DodgeGame:loadAssets] No variant sprite_set, using icon fallback")
        return
    end

    local base_path = "assets/sprites/games/dodge/" .. self.variant.sprite_set .. "/"

    -- Try to load each sprite with fallback
    local function tryLoad(filename, sprite_key)
        local filepath = base_path .. filename
        local success, result = pcall(function()
            return love.graphics.newImage(filepath)
        end)

        if success then
            self.sprites[sprite_key] = result
            print("[DodgeGame:loadAssets] Loaded: " .. filepath)
        else
            print("[DodgeGame:loadAssets] Missing: " .. filepath .. " (using fallback)")
        end
    end

    -- Load player sprite
    tryLoad("player.png", "player")

    -- Load obstacle sprite
    tryLoad("obstacle.png", "obstacle")

    -- Load enemy sprites based on variant composition
    if self.enemy_composition then
        for enemy_type, _ in pairs(self.enemy_composition) do
            tryLoad("enemy_" .. enemy_type .. ".png", "enemy_" .. enemy_type)
        end
    end

    -- Load background
    tryLoad("background.png", "background")

    print("[DodgeGame:loadAssets] Loaded " .. self:countLoadedSprites() .. " sprites for variant: " .. (self.variant.name or "Unknown"))

    -- Phase 3.3: Load audio (music + SFX pack) - using BaseGame helper
    self:loadAudio()
end

-- Helper: Count how many sprites were successfully loaded
function DodgeGame:countLoadedSprites()
    local count = 0
    for _ in pairs(self.sprites) do
        count = count + 1
    end
    return count
end

-- Helper: Check if a specific sprite is loaded
function DodgeGame:hasSprite(sprite_key)
    return self.sprites and self.sprites[sprite_key] ~= nil
end

function DodgeGame:setPlayArea(width, height)
    self.game_width = width
    self.game_height = height
    
    -- Only clamp player if player exists
    if self.player then
        self.player.x = math.max(self.player.radius, math.min(self.game_width - self.player.radius, self.player.x))
        self.player.y = math.max(self.player.radius, math.min(self.game_height - self.player.radius, self.player.y))
        print("[DodgeGame] Play area updated to:", width, height)
    else
        print("[DodgeGame] setPlayArea called before init completed")
    end
end

function DodgeGame:updateGameLogic(dt)
    -- Check for game over conditions first
    self:checkGameOver()

    -- If game is over, freeze game state
    if self.game_over then
        return
    end

    self.time_elapsed = self.time_elapsed + dt
    self:updateSafeZone(dt)
    self:updateSafeMorph(dt)
    self:updateShield(dt)
    self:updatePlayerTrail(dt)
    self:updateCameraShake(dt)
    self:updateScoreTracking(dt)
    self:updatePlayer(dt)

    self.spawn_timer = self.spawn_timer - dt
    if self.spawn_timer <= 0 then
        self:spawnObjectOrWarning()
        self.spawn_timer = self.spawn_rate + self.spawn_timer
    end

    self:updateWarnings(dt)
    self:updateObjects(dt)
end

function DodgeGame:draw()
    if self.view and self.view.draw then
        love.graphics.push()
        self.view:draw()
        love.graphics.pop()
    else
        love.graphics.setColor(1,0,0)
        love.graphics.print("Error: DodgeView not loaded or has no draw function.", 10, 100)
    end
end

-- New system methods

function DodgeGame:updateShield(dt)
    if not self.player or self.player.shield_recharge_time <= 0 then
        return
    end

    -- Only recharge if below max
    if self.player.shield_charges < self.player.shield_max then
        self.player.shield_recharge_timer = self.player.shield_recharge_timer - dt
        if self.player.shield_recharge_timer <= 0 then
            self.player.shield_charges = self.player.shield_charges + 1
            self.player.shield_recharge_timer = self.player.shield_recharge_time
            -- Play shield recharge sound
            self:playSound("pickup", 0.7)
        end
    end
end

function DodgeGame:hasActiveShield()
    return self.player and self.player.shield_charges > 0
end

function DodgeGame:consumeShield()
    if self:hasActiveShield() then
        self.player.shield_charges = self.player.shield_charges - 1
        self.player.shield_recharge_timer = self.player.shield_recharge_time
        -- Trigger shake on shield hit
        self:triggerCameraShake(self.camera_shake * 0.5)
    end
end

function DodgeGame:updatePlayerTrail(dt)
    if self.player_trail_length <= 0 or not self.player then
        return
    end

    -- Calculate trail origin from the back of the player sprite
    -- Sprite faces UP by default, so back is at BOTTOM
    -- When rotated, the back rotates with it
    -- Back direction = rotation + 90° (π/2 radians)
    local rotation = self.player.rotation or 0
    local back_angle = rotation + math.pi / 2
    local trail_x = self.player.x + math.cos(back_angle) * self.player.radius
    local trail_y = self.player.y + math.sin(back_angle) * self.player.radius

    -- Add back position to trail buffer
    table.insert(self.player_trail_buffer, 1, {x = trail_x, y = trail_y})

    -- Limit trail length
    while #self.player_trail_buffer > self.player_trail_length do
        table.remove(self.player_trail_buffer)
    end
end

function DodgeGame:updateCameraShake(dt)
    if self.camera_shake_active > 0 then
        -- Exponential decay
        self.camera_shake_active = self.camera_shake_active * self.camera_shake_decay
        -- Stop shaking when very small
        if self.camera_shake_active < 0.1 then
            self.camera_shake_active = 0
        end
    end
end

function DodgeGame:triggerCameraShake(intensity)
    self.camera_shake_active = math.max(self.camera_shake_active, intensity or self.camera_shake)
end

function DodgeGame:updateScoreTracking(dt)
    if not self.player or not self.safe_zone then
        return
    end

    -- Track average speed for "speed" mode
    if self.score_mode == "speed" then
        local speed = math.sqrt(self.player.vx * self.player.vx + self.player.vy * self.player.vy)
        self.avg_speed_tracker.sum = self.avg_speed_tracker.sum + speed
        self.avg_speed_tracker.count = self.avg_speed_tracker.count + 1
    end

    -- Track position for "center" and "edge" modes
    if self.score_mode == "center" or self.score_mode == "edge" then
        local dx = self.player.x - self.safe_zone.x
        local dy = self.player.y - self.safe_zone.y
        local dist = math.sqrt(dx*dx + dy*dy)
        local normalized_dist = dist / math.max(1, self.safe_zone.radius)

        if self.score_mode == "center" then
            -- Reward being near center (1.0 at center, 0.0 at edge)
            local center_weight = 1.0 - normalized_dist
            self.center_time_tracker.total_weighted = self.center_time_tracker.total_weighted + center_weight * dt
            self.center_time_tracker.total_time = self.center_time_tracker.total_time + dt
        elseif self.score_mode == "edge" then
            -- Reward being near edge (0.0 at center, 1.0 at edge)
            local edge_weight = normalized_dist
            self.edge_time_tracker.total_weighted = self.edge_time_tracker.total_weighted + edge_weight * dt
            self.edge_time_tracker.total_time = self.edge_time_tracker.total_time + dt
        end
    end
end

function DodgeGame:getScoreMultiplier()
    if self.score_mode == "speed" then
        if self.avg_speed_tracker.count > 0 then
            local avg_speed = self.avg_speed_tracker.sum / self.avg_speed_tracker.count
            local speed_ratio = avg_speed / (self.player.max_speed or 600)
            return 1.0 + speed_ratio * 0.5  -- Up to 1.5x at max speed
        end
    elseif self.score_mode == "center" then
        if self.center_time_tracker.total_time > 0 then
            local avg_center = self.center_time_tracker.total_weighted / self.center_time_tracker.total_time
            return 1.0 + avg_center * 0.5  -- Up to 1.5x at perfect center
        end
    elseif self.score_mode == "edge" then
        if self.edge_time_tracker.total_time > 0 then
            local avg_edge = self.edge_time_tracker.total_weighted / self.edge_time_tracker.total_time
            return 1.0 + avg_edge * 0.5  -- Up to 1.5x at perfect edge
        end
    end
    return 1.0  -- No multiplier
end

function DodgeGame:applyEnvironmentForces(dt)
    if not self.player or not self.safe_zone then
        return
    end

    -- Apply gravity (toward or away from center)
    if self.area_gravity ~= 0 then
        local dx = self.safe_zone.x - self.player.x
        local dy = self.safe_zone.y - self.player.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > 0 then
            local gx = (dx / dist) * self.area_gravity * dt
            local gy = (dy / dist) * self.area_gravity * dt
            self.player.vx = self.player.vx + gx
            self.player.vy = self.player.vy + gy
        end
    end

    -- Apply wind
    if self.wind_strength > 0 and self.wind_type ~= "none" then
        local wx, wy = self:getWindForce(dt)
        self.player.vx = self.player.vx + wx * dt
        self.player.vy = self.player.vy + wy * dt
    end

    -- Apply max speed cap
    if self.player.max_speed > 0 then
        local speed = math.sqrt(self.player.vx * self.player.vx + self.player.vy * self.player.vy)
        if speed > self.player.max_speed then
            local scale = self.player.max_speed / speed
            self.player.vx = self.player.vx * scale
            self.player.vy = self.player.vy * scale
        end
    end
end

function DodgeGame:getWindForce(dt)
    -- Update wind direction based on type
    if self.wind_type == "changing_steady" or self.wind_type == "changing_turbulent" then
        self.wind_timer = self.wind_timer + dt
        if self.wind_timer >= 3.0 then  -- Change direction every 3 seconds
            self.wind_timer = 0
            self.wind_current_angle = self.wind_current_angle + math.rad(30)
        end
    end

    local base_angle = self.wind_current_angle
    local wx, wy

    if self.wind_type == "steady" or self.wind_type == "changing_steady" then
        -- Constant wind in current direction
        wx = math.cos(base_angle) * self.wind_strength
        wy = math.sin(base_angle) * self.wind_strength
    elseif self.wind_type == "turbulent" or self.wind_type == "changing_turbulent" then
        -- Add random turbulence to base direction
        local turbulence_angle = base_angle + (math.random() - 0.5) * math.pi * 0.5
        wx = math.cos(turbulence_angle) * self.wind_strength
        wy = math.sin(turbulence_angle) * self.wind_strength
    else
        wx, wy = 0, 0
    end

    return wx, wy
end

function DodgeGame:updatePlayer(dt)
    if self.player.movement_type == "asteroids" then
        self:updatePlayerAsteroids(dt)
    elseif self.player.movement_type == "jump" then
        self:updatePlayerJump(dt)
    else
        self:updatePlayerDefault(dt)
    end
end

function DodgeGame:updatePlayerDefault(dt)
    local dx, dy = 0, 0
    if love.keyboard.isDown('left', 'a') then dx = dx - 1 end
    if love.keyboard.isDown('right', 'd') then dx = dx + 1 end
    if love.keyboard.isDown('up', 'w') then dy = dy - 1 end
    if love.keyboard.isDown('down', 's') then dy = dy + 1 end

    -- Update rotation towards movement direction
    if dx ~= 0 or dy ~= 0 then
        -- Add π/2 offset because sprite's default orientation is facing up (not right)
        local target_rotation = math.atan2(dy, dx) + math.pi / 2

        -- Calculate shortest path to target rotation
        local function angdiff(a, b)
            local d = (a - b + math.pi) % (2 * math.pi) - math.pi
            return d
        end

        local diff = angdiff(target_rotation, self.player.rotation)
        local max_turn = self.player.rotation_speed * dt

        -- Clamp rotation delta to max turn speed
        if diff > max_turn then
            diff = max_turn
        elseif diff < -max_turn then
            diff = -max_turn
        end

        self.player.rotation = self.player.rotation + diff

        -- Normalize rotation to [0, 2π] range for consistency
        self.player.rotation = self.player.rotation % (2 * math.pi)
    end

    if dx ~= 0 and dy ~= 0 then
        local inv_sqrt2 = 0.70710678118
        dx = dx * inv_sqrt2; dy = dy * inv_sqrt2
    end

    -- If friction is enabled, use velocity-based movement (momentum)
    local has_momentum = self.player.accel_friction < 1.0 or self.player.decel_friction < 1.0
    if has_momentum then
        -- Apply input as acceleration/force
        if dx ~= 0 or dy ~= 0 then
            -- Player is accelerating - apply accel_friction
            self.player.vx = self.player.vx + dx * self.player.movement_speed * dt
            self.player.vy = self.player.vy + dy * self.player.movement_speed * dt

            if self.player.accel_friction < 1.0 then
                local accel_factor = math.pow(self.player.accel_friction, dt * 60)
                self.player.vx = self.player.vx * accel_factor
                self.player.vy = self.player.vy * accel_factor
            end
        else
            -- Player is coasting - apply decel_friction (stopping)
            if self.player.decel_friction < 1.0 then
                local decel_factor = math.pow(self.player.decel_friction, dt * 60)
                self.player.vx = self.player.vx * decel_factor
                self.player.vy = self.player.vy * decel_factor
            else
                -- Instant stop if decel_friction = 1.0
                self.player.vx = 0
                self.player.vy = 0
            end
        end

        -- Update position from velocity
        self.player.x = self.player.x + self.player.vx * dt
        self.player.y = self.player.y + self.player.vy * dt
    else
        -- Direct positional movement (classic, no momentum)
        self.player.x = self.player.x + dx * self.player.movement_speed * dt
        self.player.y = self.player.y + dy * self.player.movement_speed * dt
    end

    -- Apply environment forces (gravity, wind) and max speed cap
    self:applyEnvironmentForces(dt)

    self:clampPlayerPosition()

    -- Apply bounce if friction is enabled (has velocity)
    if has_momentum then
        local hit_boundary = false
        if self.player.x <= self.player.radius or self.player.x >= self.game_width - self.player.radius then
            self.player.vx = -self.player.vx * self.player.bounce_damping
            hit_boundary = true
        end
        if self.player.y <= self.player.radius or self.player.y >= self.game_height - self.player.radius then
            self.player.vy = -self.player.vy * self.player.bounce_damping
            hit_boundary = true
        end

        if hit_boundary then
            self.player.x = math.max(self.player.radius, math.min(self.game_width - self.player.radius, self.player.x))
            self.player.y = math.max(self.player.radius, math.min(self.game_height - self.player.radius, self.player.y))
        end
    end
end

function DodgeGame:updatePlayerAsteroids(dt)
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.dodge) or {}
    local thrust_accel = (runtimeCfg.player and runtimeCfg.player.thrust_acceleration) or 600

    -- Rotation controls (left/right turn the ship)
    if love.keyboard.isDown('left', 'a') then
        self.player.rotation = self.player.rotation - self.player.rotation_speed * dt
    end
    if love.keyboard.isDown('right', 'd') then
        self.player.rotation = self.player.rotation + self.player.rotation_speed * dt
    end

    -- Normalize rotation
    self.player.rotation = self.player.rotation % (2 * math.pi)

    -- Thrust controls (forward accelerates in facing direction)
    local is_thrusting = false
    if love.keyboard.isDown('up', 'w') then
        is_thrusting = true
        -- Calculate thrust direction (sprite faces up by default, so rotation 0 = up)
        local thrust_angle = self.player.rotation - math.pi / 2  -- Subtract π/2 to convert from sprite space to world space
        local thrust_x = math.cos(thrust_angle) * thrust_accel * dt
        local thrust_y = math.sin(thrust_angle) * thrust_accel * dt

        self.player.vx = self.player.vx + thrust_x
        self.player.vy = self.player.vy + thrust_y

        -- Apply acceleration friction (resistance when starting up)
        if self.player.accel_friction < 1.0 then
            local accel_factor = math.pow(self.player.accel_friction, dt * 60)
            self.player.vx = self.player.vx * accel_factor
            self.player.vy = self.player.vy * accel_factor
        end
    end

    -- Reverse/brake controls (down key behavior)
    if love.keyboard.isDown('down', 's') then
        if self.player.reverse_mode == "thrust" then
            is_thrusting = true
            -- Reverse thrust (accelerate backwards)
            local thrust_angle = self.player.rotation - math.pi / 2
            local thrust_x = math.cos(thrust_angle) * thrust_accel * dt
            local thrust_y = math.sin(thrust_angle) * thrust_accel * dt

            self.player.vx = self.player.vx - thrust_x  -- Opposite direction
            self.player.vy = self.player.vy - thrust_y

            -- Apply acceleration friction
            if self.player.accel_friction < 1.0 then
                local accel_factor = math.pow(self.player.accel_friction, dt * 60)
                self.player.vx = self.player.vx * accel_factor
                self.player.vy = self.player.vy * accel_factor
            end
        elseif self.player.reverse_mode == "brake" then
            -- Active braking (reduce velocity toward zero)
            local brake_strength = 0.92  -- Aggressive decay when braking
            local brake_factor = math.pow(brake_strength, dt * 60)  -- Normalized to 60fps
            self.player.vx = self.player.vx * brake_factor
            self.player.vy = self.player.vy * brake_factor
        end
        -- "none" = down does nothing
    end

    -- Apply deceleration friction when coasting (not actively thrusting)
    if not is_thrusting and self.player.decel_friction < 1.0 then
        local decel_factor = math.pow(self.player.decel_friction, dt * 60)  -- Normalize to 60fps
        self.player.vx = self.player.vx * decel_factor
        self.player.vy = self.player.vy * decel_factor
    end

    -- Update position based on velocity
    self.player.x = self.player.x + self.player.vx * dt
    self.player.y = self.player.y + self.player.vy * dt

    -- Apply environment forces (gravity, wind) and max speed cap
    self:applyEnvironmentForces(dt)

    self:clampPlayerPosition()

    -- When hitting boundaries, bounce/dampen velocity
    local hit_boundary = false
    if self.player.x <= self.player.radius or self.player.x >= self.game_width - self.player.radius then
        self.player.vx = -self.player.vx * self.player.bounce_damping  -- Reverse and dampen
        hit_boundary = true
    end
    if self.player.y <= self.player.radius or self.player.y >= self.game_height - self.player.radius then
        self.player.vy = -self.player.vy * self.player.bounce_damping  -- Reverse and dampen
        hit_boundary = true
    end

    -- Clamp position again after potential bounce
    if hit_boundary then
        self.player.x = math.max(self.player.radius, math.min(self.game_width - self.player.radius, self.player.x))
        self.player.y = math.max(self.player.radius, math.min(self.game_height - self.player.radius, self.player.y))
    end
end

function DodgeGame:updatePlayerJump(dt)
    -- Jump/dash movement: discrete jumps with cooldown
    -- Press a direction key → player dashes a fixed distance at jump_speed
    -- Must wait for cooldown before next jump
    --
    -- Supports optional momentum/drift:
    -- - If accel_friction or decel_friction < 1.0, uses velocity-based movement (can drift after jump)
    -- - Otherwise, uses direct positional movement (instant stop after jump)

    local time_since_jump = self.time_elapsed - self.player.last_jump_time
    local can_jump = time_since_jump >= self.player.jump_cooldown

    -- Check if momentum/drift is enabled
    local has_momentum = self.player.accel_friction < 1.0 or self.player.decel_friction < 1.0

    -- If currently mid-jump, continue moving towards target
    if self.player.is_jumping then
        -- Safety check: if jump has been going too long, end it (prevents getting stuck)
        local expected_jump_time = self.player.jump_distance / self.player.jump_speed
        local actual_jump_time = self.time_elapsed - self.player.last_jump_time
        if actual_jump_time > expected_jump_time * 2.5 then
            -- Jump took way too long, probably stuck on wall - end it
            self.player.is_jumping = false
        end

        if self.player.is_jumping then
            local dx = self.player.jump_target_x - self.player.x
            local dy = self.player.jump_target_y - self.player.y
            local dist_to_target = math.sqrt(dx*dx + dy*dy)

            -- If very high speed (9999+), teleport instantly
            if self.player.jump_speed >= 9999 then
                self.player.x = self.player.jump_target_x
                self.player.y = self.player.jump_target_y
                self.player.is_jumping = false
                -- If using momentum mode, set velocity to jump direction for drift
                if has_momentum then
                    self.player.vx = self.player.jump_dir_x * self.player.jump_speed * 0.3
                    self.player.vy = self.player.jump_dir_y * self.player.jump_speed * 0.3
                end
            -- Otherwise, move smoothly towards target
            elseif dist_to_target > 1 then
                -- Recalculate direction to target (in case clamping pushed us off course)
                local dir_x = dx / dist_to_target
                local dir_y = dy / dist_to_target

                -- Move at jump_speed towards target
                local move_dist = self.player.jump_speed * dt

                if move_dist >= dist_to_target then
                    -- Reached target
                    self.player.x = self.player.jump_target_x
                    self.player.y = self.player.jump_target_y
                    self.player.is_jumping = false
                    -- If using momentum mode, set velocity to jump direction for drift
                    if has_momentum then
                        self.player.vx = self.player.jump_dir_x * self.player.jump_speed * 0.3
                        self.player.vy = self.player.jump_dir_y * self.player.jump_speed * 0.3
                    end
                else
                    -- Store position before moving
                    local old_x, old_y = self.player.x, self.player.y

                    -- Move towards target using recalculated direction
                    self.player.x = self.player.x + dir_x * move_dist
                    self.player.y = self.player.y + dir_y * move_dist

                    -- Apply clamping
                    self:clampPlayerPosition()

                    -- After clamping, check if we actually moved
                    -- (if not, we're stuck on a wall and should end jump)
                    local moved_x = math.abs(self.player.x - old_x)
                    local moved_y = math.abs(self.player.y - old_y)
                    if moved_x < 0.5 and moved_y < 0.5 then
                        -- Barely moved, stuck on wall - end jump
                        self.player.is_jumping = false
                        -- If using momentum mode, preserve some velocity for bounce
                        if has_momentum then
                            self.player.vx = dir_x * self.player.jump_speed * 0.2
                            self.player.vy = dir_y * self.player.jump_speed * 0.2
                        end
                    end
                end

                -- Rotate sprite towards current movement direction
                if self.player.is_jumping then
                    local target_rotation = math.atan2(dir_y, dir_x) + math.pi / 2
                    local function angdiff(a, b)
                        local d = (a - b + math.pi) % (2 * math.pi) - math.pi
                        return d
                    end
                    local diff = angdiff(target_rotation, self.player.rotation)
                    local max_turn = self.player.rotation_speed * dt
                    if diff > max_turn then diff = max_turn
                    elseif diff < -max_turn then diff = -max_turn end
                    self.player.rotation = (self.player.rotation + diff) % (2 * math.pi)
                end
            else
                -- Close enough, snap to target
                self.player.x = self.player.jump_target_x
                self.player.y = self.player.jump_target_y
                self.player.is_jumping = false
                -- If using momentum mode, set velocity to jump direction for drift
                if has_momentum then
                    self.player.vx = self.player.jump_dir_x * self.player.jump_speed * 0.3
                    self.player.vy = self.player.jump_dir_y * self.player.jump_speed * 0.3
                end
            end
        end

    -- Not jumping, check if we can start a new jump
    elseif can_jump and not self.player.is_jumping then
        -- Check for directional input (only register one direction per jump)
        local jump_dx, jump_dy = 0, 0

        if love.keyboard.isDown('left', 'a') then
            jump_dx = -1
        elseif love.keyboard.isDown('right', 'd') then
            jump_dx = 1
        elseif love.keyboard.isDown('up', 'w') then
            jump_dy = -1
        elseif love.keyboard.isDown('down', 's') then
            jump_dy = 1
        end

        -- If a direction was pressed, start jump
        if jump_dx ~= 0 or jump_dy ~= 0 then
            -- Calculate target position
            self.player.jump_target_x = self.player.x + jump_dx * self.player.jump_distance
            self.player.jump_target_y = self.player.y + jump_dy * self.player.jump_distance

            -- Clamp target to bounds
            self.player.jump_target_x = math.max(self.player.radius, math.min(self.game_width - self.player.radius, self.player.jump_target_x))
            self.player.jump_target_y = math.max(self.player.radius, math.min(self.game_height - self.player.radius, self.player.jump_target_y))

            -- Store normalized direction
            self.player.jump_dir_x = jump_dx
            self.player.jump_dir_y = jump_dy

            -- Start jump
            self.player.is_jumping = true
            self.player.last_jump_time = self.time_elapsed

            -- Play a jump sound (if available)
            self:playSound("jump", 0.5)
        end
    end

    -- If not jumping and momentum mode is enabled, apply drift/friction
    if not self.player.is_jumping and has_momentum then
        -- Apply deceleration friction (drift after jump)
        if self.player.decel_friction < 1.0 then
            local decel_factor = math.pow(self.player.decel_friction, dt * 60)
            self.player.vx = self.player.vx * decel_factor
            self.player.vy = self.player.vy * decel_factor
        else
            -- Instant stop if decel_friction = 1.0
            self.player.vx = 0
            self.player.vy = 0
        end

        -- Update position from velocity (drift)
        self.player.x = self.player.x + self.player.vx * dt
        self.player.y = self.player.y + self.player.vy * dt

        -- Rotate sprite towards drift direction (if moving)
        local speed = math.sqrt(self.player.vx * self.player.vx + self.player.vy * self.player.vy)
        if speed > 10 then
            local target_rotation = math.atan2(self.player.vy, self.player.vx) + math.pi / 2
            local function angdiff(a, b)
                local d = (a - b + math.pi) % (2 * math.pi) - math.pi
                return d
            end
            local diff = angdiff(target_rotation, self.player.rotation)
            local max_turn = self.player.rotation_speed * dt
            if diff > max_turn then diff = max_turn
            elseif diff < -max_turn then diff = -max_turn end
            self.player.rotation = (self.player.rotation + diff) % (2 * math.pi)
        end
    end

    -- Apply environment forces (gravity, wind) and max speed cap
    self:applyEnvironmentForces(dt)

    -- Clamp to safe zone
    self:clampPlayerPosition()

    -- Apply bounce if momentum mode is enabled and hit boundaries
    if has_momentum then
        local hit_boundary = false
        if self.player.x <= self.player.radius or self.player.x >= self.game_width - self.player.radius then
            self.player.vx = -self.player.vx * self.player.bounce_damping
            hit_boundary = true
        end
        if self.player.y <= self.player.radius or self.player.y >= self.game_height - self.player.radius then
            self.player.vy = -self.player.vy * self.player.bounce_damping
            hit_boundary = true
        end

        if hit_boundary then
            self.player.x = math.max(self.player.radius, math.min(self.game_width - self.player.radius, self.player.x))
            self.player.y = math.max(self.player.radius, math.min(self.game_height - self.player.radius, self.player.y))
        end
    end
end

-- Shape-specific collision helpers
function DodgeGame:isPointInCircle(px, py, cx, cy, radius)
    local dx = px - cx
    local dy = py - cy
    return (dx*dx + dy*dy) <= (radius * radius)
end

function DodgeGame:isPointInSquare(px, py, cx, cy, half_size)
    return px >= (cx - half_size) and px <= (cx + half_size) and
           py >= (cy - half_size) and py <= (cy + half_size)
end

function DodgeGame:isPointInHex(px, py, cx, cy, radius)
    -- Hexagon is approximated as 6 sides
    -- For simplicity, use distance check with adjusted radius (inscribed hex)
    local dx = px - cx
    local dy = py - cy
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist > radius then return false end

    -- Hex-specific check: use 6-sided polygon
    local angle = math.atan2(dy, dx)
    local sector_angle = math.pi / 3  -- 60 degrees
    local sector = math.floor((angle + math.pi) / sector_angle)
    local sector_mid_angle = -math.pi + (sector + 0.5) * sector_angle
    local dx_rot = dx * math.cos(-sector_mid_angle) - dy * math.sin(-sector_mid_angle)

    -- Check against flat edge of hexagon
    local hex_flat_radius = radius * math.cos(math.pi / 6)
    return math.abs(dx_rot) <= hex_flat_radius
end

function DodgeGame:checkCircleLineCollision(cx, cy, cr, x1, y1, x2, y2)
    -- Check if circle (cx, cy, cr) collides with line segment (x1,y1)-(x2,y2)
    -- Find closest point on line segment to circle center
    local dx = x2 - x1
    local dy = y2 - y1
    local len_sq = dx*dx + dy*dy
    if len_sq == 0 then
        -- Degenerate segment (point)
        local dist_sq = (cx - x1)*(cx - x1) + (cy - y1)*(cy - y1)
        return dist_sq <= cr*cr
    end

    -- Project circle center onto line, clamped to segment
    local t = math.max(0, math.min(1, ((cx - x1)*dx + (cy - y1)*dy) / len_sq))
    local px = x1 + t * dx
    local py = y1 + t * dy

    -- Check distance from circle center to closest point
    local dist_sq = (cx - px)*(cx - px) + (cy - py)*(cy - py)
    return dist_sq <= cr*cr
end

function DodgeGame:clampPlayerPosition()
    -- Clamp to rectangular bounds first
    self.player.x = math.max(self.player.radius, math.min(self.game_width - self.player.radius, self.player.x))
    self.player.y = math.max(self.player.radius, math.min(self.game_height - self.player.radius, self.player.y))

    -- Clamp to safe zone based on shape
    local sz = self.safe_zone
    if sz then
        local shape = sz.area_shape or "circle"
        local dxp = self.player.x - sz.x
        local dyp = self.player.y - sz.y
        local dist = math.sqrt(dxp*dxp + dyp*dyp)

        if shape == "circle" then
            -- Circle clamping (original behavior)
            local max_dist = math.max(0, sz.radius - self.player.radius)
            if dist > max_dist and dist > 0 then
                local scale = max_dist / dist
                self.player.x = sz.x + dxp * scale
                self.player.y = sz.y + dyp * scale

                -- Bounce velocity
                local nx = dxp / dist
                local ny = dyp / dist
                local dot = self.player.vx * nx + self.player.vy * ny
                if dot > 0 then
                    local bounce_factor = 1.0 + self.player.bounce_damping
                    self.player.vx = self.player.vx - nx * dot * bounce_factor
                    self.player.vy = self.player.vy - ny * dot * bounce_factor
                end
            end

        elseif shape == "square" then
            -- Square clamping (AABB)
            local half_size = sz.radius - self.player.radius
            local clamped_x = math.max(sz.x - half_size, math.min(sz.x + half_size, self.player.x))
            local clamped_y = math.max(sz.y - half_size, math.min(sz.y + half_size, self.player.y))

            if clamped_x ~= self.player.x or clamped_y ~= self.player.y then
                -- Hit boundary
                if clamped_x ~= self.player.x then
                    self.player.vx = -self.player.vx * self.player.bounce_damping
                end
                if clamped_y ~= self.player.y then
                    self.player.vy = -self.player.vy * self.player.bounce_damping
                end
                self.player.x = clamped_x
                self.player.y = clamped_y
            end

        elseif shape == "hex" then
            -- Hexagon clamping (approximate with circle for now, refined check for edges)
            local max_dist = math.max(0, sz.radius - self.player.radius)
            if dist > max_dist and dist > 0 then
                local scale = max_dist / dist
                self.player.x = sz.x + dxp * scale
                self.player.y = sz.y + dyp * scale

                -- Bounce velocity
                local nx = dxp / dist
                local ny = dyp / dist
                local dot = self.player.vx * nx + self.player.vy * ny
                if dot > 0 then
                    local bounce_factor = 1.0 + self.player.bounce_damping
                    self.player.vx = self.player.vx - nx * dot * bounce_factor
                    self.player.vy = self.player.vy - ny * dot * bounce_factor
                end
            end
        end
    end
end

function DodgeGame:checkGameOver()
    if self.game_over then return end  -- Already game over

    local sz = self.safe_zone
    if not sz then return end

    -- Check if player left safe zone (if enabled)
    if self.leaving_area_ends_game then
        local shape = sz.area_shape or "circle"
        local is_inside = false

        if shape == "circle" then
            is_inside = self:isPointInCircle(self.player.x, self.player.y, sz.x, sz.y, sz.radius - self.player.radius)
        elseif shape == "square" then
            is_inside = self:isPointInSquare(self.player.x, self.player.y, sz.x, sz.y, sz.radius - self.player.radius)
        elseif shape == "hex" then
            is_inside = self:isPointInHex(self.player.x, self.player.y, sz.x, sz.y, sz.radius - self.player.radius)
        end

        if not is_inside then
            self.game_over = true
            print("[DodgeGame] Game Over: Player left safe zone")
            return
        end
    end

    -- Check if player touched any hole
    if self.holes then
        for _, hole in ipairs(self.holes) do
            local dx = self.player.x - hole.x
            local dy = self.player.y - hole.y
            local dist_sq = dx*dx + dy*dy
            local collision_dist = self.player.radius + hole.radius

            if dist_sq <= (collision_dist * collision_dist) then
                self.game_over = true
                print("[DodgeGame] Game Over: Player touched hole")
                return
            end
        end
    end
end

function DodgeGame:updateObjects(dt)
    for i = #self.objects, 1, -1 do
        local obj = self.objects[i]
        if not obj then goto continue_obj_loop end

        -- Behavior by type (all use persistent heading/velocity)
        obj.angle = obj.angle or 0
        obj.vx = obj.vx or math.cos(obj.angle) * obj.speed
        obj.vy = obj.vy or math.sin(obj.angle) * obj.speed

        -- Phase 1.4: Handle variant enemy special behaviors
        if obj.type == 'shooter' and obj.is_enemy then
            -- Shooter: Fire projectiles at player
            obj.shoot_timer = obj.shoot_timer - dt
            if obj.shoot_timer <= 0 then
                obj.shoot_timer = obj.shoot_interval
                -- Spawn projectile toward player
                local dx = self.player.x - obj.x
                local dy = self.player.y - obj.y
                local proj_angle = math.atan2(dy, dx)
                local projectile = {
                    x = obj.x,
                    y = obj.y,
                    radius = OBJECT_RADIUS * 0.5,
                    type = 'linear',
                    speed = self.object_speed * 0.8,
                    angle = proj_angle,
                    is_projectile = true,
                    warned = false
                }
                projectile.vx = math.cos(proj_angle) * projectile.speed
                projectile.vy = math.sin(proj_angle) * projectile.speed
                table.insert(self.objects, projectile)
            end
        elseif obj.type == 'bouncer' and obj.is_enemy then
            -- Bouncer: Bounce off walls
            local next_x = obj.x + obj.vx * dt
            local next_y = obj.y + obj.vy * dt
            if next_x <= obj.radius or next_x >= self.game_width - obj.radius then
                obj.vx = -obj.vx
                obj.bounce_count = obj.bounce_count + 1
            end
            if next_y <= obj.radius or next_y >= self.game_height - obj.radius then
                obj.vy = -obj.vy
                obj.bounce_count = obj.bounce_count + 1
            end
        elseif obj.type == 'teleporter' and obj.is_enemy then
            -- Teleporter: Disappear and reappear near player
            obj.teleport_timer = obj.teleport_timer - dt
            if obj.teleport_timer <= 0 then
                obj.teleport_timer = obj.teleport_interval
                -- Teleport near player
                local angle = math.random() * math.pi * 2
                local dist = obj.teleport_range
                obj.x = self.player.x + math.cos(angle) * dist
                obj.y = self.player.y + math.sin(angle) * dist
                -- Clamp to bounds
                obj.x = math.max(obj.radius, math.min(self.game_width - obj.radius, obj.x))
                obj.y = math.max(obj.radius, math.min(self.game_height - obj.radius, obj.y))
                -- Update velocity toward player
                local dx = self.player.x - obj.x
                local dy = self.player.y - obj.y
                local new_angle = math.atan2(dy, dx)
                obj.angle = new_angle
                obj.vx = math.cos(new_angle) * obj.speed
                obj.vy = math.sin(new_angle) * obj.speed
            end
        end

        -- Apply general tracking (if tracking_strength > 0)
        if obj.tracking_strength and obj.tracking_strength > 0 and self.player then
            local tx, ty = self.player.x, self.player.y
            local desired = math.atan2(ty - obj.y, tx - obj.x)
            local function angdiff(a,b)
                local d = (a - b + math.pi) % (2*math.pi) - math.pi
                return d
            end
            local diff = angdiff(desired, obj.angle)
            -- Tracking strength controls turn rate: 1.0 = very aggressive, 0.5 = moderate
            local max_turn = math.rad(180) * obj.tracking_strength * dt  -- Up to 180 deg/sec at strength 1.0
            if diff > max_turn then diff = max_turn elseif diff < -max_turn then diff = -max_turn end
            obj.angle = obj.angle + diff
            obj.vx = math.cos(obj.angle) * obj.speed
            obj.vy = math.sin(obj.angle) * obj.speed
        end

        if obj.type == 'seeker' then
            -- Subtle steering toward player: small max turn rate so they still fly past
            local tx, ty = self.player.x, self.player.y
            local desired = math.atan2(ty - obj.y, tx - obj.x)
            local function angdiff(a,b)
                local d = (a - b + math.pi) % (2*math.pi) - math.pi
                return d
            end
            local diff = angdiff(desired, obj.angle)
            local base_turn = math.rad(((DodgeCfg.seeker and DodgeCfg.seeker.base_turn_deg) or 6)) -- degrees/sec at baseline
            local te = self.time_elapsed or 0
            local difficulty_scaler = 1 + math.min(((DodgeCfg.seeker and DodgeCfg.seeker.difficulty and DodgeCfg.seeker.difficulty.max) or 2.0), te / ((DodgeCfg.seeker and DodgeCfg.seeker.difficulty and DodgeCfg.seeker.difficulty.time) or 90))
            local max_turn = base_turn * difficulty_scaler * dt
            if diff > max_turn then diff = max_turn elseif diff < -max_turn then diff = -max_turn end
            obj.angle = obj.angle + diff
            obj.vx = math.cos(obj.angle) * obj.speed
            obj.vy = math.sin(obj.angle) * obj.speed
        elseif obj.type == 'zigzag' or obj.type == 'sine' then
            -- Base velocity along heading with a perpendicular wobble
            local perp_x = -math.sin(obj.angle)
            local perp_y =  math.cos(obj.angle)
            local t = love.timer.getTime() * obj.wave_speed
            local wobble = math.sin(t + obj.wave_phase) * obj.wave_amp
            -- wobble is positional; convert to velocity by differentiating approx -> reduce magnitude
            local wobble_v = wobble * (((DodgeCfg.objects and DodgeCfg.objects.zigzag and DodgeCfg.objects.zigzag.wave_velocity_factor) or 2.0))
            local vx = obj.vx + perp_x * wobble_v
            local vy = obj.vy + perp_y * wobble_v
            obj.x = obj.x + vx * dt
            obj.y = obj.y + vy * dt
            goto post_move
        else
            obj.x = obj.x + obj.vx * dt
            obj.y = obj.y + obj.vy * dt
            goto post_move
        end

        -- Common position update for seeker after velocity update
        obj.x = obj.x + obj.vx * dt
        obj.y = obj.y + obj.vy * dt
        ::post_move::

        -- Update trail positions
        if obj.trail_positions then
            table.insert(obj.trail_positions, 1, {x = obj.x, y = obj.y})
            -- Limit trail length
            while #obj.trail_positions > self.obstacle_trails do
                table.remove(obj.trail_positions)
            end
        end

        -- Mark when an object has actually entered the playable rectangle
        if not obj.entered_play then
            if obj.x > 0 and obj.x < self.game_width and obj.y > 0 and obj.y < self.game_height then
                obj.entered_play = true
            end
        end

        -- Splitter: split when entering safe zone circle (not only on hit)
        if obj.type == 'splitter' and self.safe_zone then
            local dxs = obj.x - self.safe_zone.x
            local dys = obj.y - self.safe_zone.y
            local inside = (dxs*dxs + dys*dys) <= (self.safe_zone.radius + obj.radius)^2
            if inside and not obj.was_inside then
                local shards = (DodgeCfg.objects and DodgeCfg.objects.splitter and DodgeCfg.objects.splitter.shards_count) or 3
                self:spawnShards(obj, shards)
                obj.did_split = true
                table.remove(self.objects, i)
                goto continue_obj_loop
            end
            obj.was_inside = inside
        end

        if Collision.checkCircles(self.player.x, self.player.y, self.player.radius, obj.x, obj.y, obj.radius) then
            -- Remove object first
            table.remove(self.objects, i)

            -- Check shield first
            if self:hasActiveShield() then
                -- Shield absorbs hit
                self:consumeShield()
                self:playSound("hit", 0.7)  -- Softer hit sound for shield
            else
                -- No shield, take damage
                self.metrics.collisions = self.metrics.collisions + 1
                self:playSound("hit", 1.0)
                self:triggerCameraShake()  -- Trigger shake on hit

                -- Check if out of lives
                if self.metrics.collisions >= self.lives then
                    self:playSound("death", 1.0)
                    self:onComplete()
                    return
                end
            end
        -- Check trail collision (if object has trails and player hasn't been hit)
        elseif obj.trail_positions and #obj.trail_positions > 1 then
            local hit_trail = false
            for j = 1, #obj.trail_positions - 1 do
                local p1 = obj.trail_positions[j]
                local p2 = obj.trail_positions[j + 1]
                -- Check if player circle intersects line segment
                if self:checkCircleLineCollision(self.player.x, self.player.y, self.player.radius, p1.x, p1.y, p2.x, p2.y) then
                    hit_trail = true
                    break
                end
            end

            if hit_trail then
                -- Hit trail, treat like object collision
                table.remove(self.objects, i)
                if self:hasActiveShield() then
                    self:consumeShield()
                    self:playSound("hit", 0.5)
                else
                    self.metrics.collisions = self.metrics.collisions + 1
                    self:playSound("hit", 0.8)
                    self:triggerCameraShake(self.camera_shake * 0.7)
                    if self.metrics.collisions >= self.lives then
                        self:playSound("death", 1.0)
                        self:onComplete()
                        return
                    end
                end
            end
        elseif self:isObjectOffscreen(obj) then
            table.remove(self.objects, i)
            if obj.entered_play then
                self.metrics.objects_dodged = self.metrics.objects_dodged + 1

                -- Phase 3.3: Play dodge sound (subtle)
                self:playSound("dodge", 0.3)
            end
            if obj.warned then self.metrics.perfect_dodges = self.metrics.perfect_dodges + 1 end
        end
        ::continue_obj_loop::
    end
end

function DodgeGame:updateWarnings(dt)
    for i = #self.warnings, 1, -1 do
        local warning = self.warnings[i]
        if not warning then goto continue_warn_loop end
        warning.time = warning.time - dt
        if warning.time <= 0 then
            self:createObjectFromWarning(warning)
            table.remove(self.warnings, i)
        end
         ::continue_warn_loop::
    end
end

function DodgeGame:spawnObjectOrWarning()
    -- Dynamic spawn rate scaling
    local accel = 1 + math.min(((DodgeCfg.spawn and DodgeCfg.spawn.accel and DodgeCfg.spawn.accel.max) or 2.0), self.time_elapsed / ((DodgeCfg.spawn and DodgeCfg.spawn.accel and DodgeCfg.spawn.accel.time) or 60))
    self.spawn_rate = (BASE_SPAWN_RATE / self.difficulty_modifiers.count) / accel

    -- Handle spawn patterns
    if self.obstacle_spawn_pattern == "waves" then
        self.spawn_pattern_state.wave_timer = self.spawn_pattern_state.wave_timer + self.spawn_rate
        if self.spawn_pattern_state.wave_active then
            -- In active wave, spawn burst
            if self.spawn_pattern_state.wave_timer >= 0.15 then  -- Spawn every 0.15s during wave
                self.spawn_pattern_state.wave_timer = 0
                self:spawnSingleObject()
                self.spawn_pattern_state.wave_count = (self.spawn_pattern_state.wave_count or 0) + 1
                if self.spawn_pattern_state.wave_count >= 6 then  -- 6 objects per wave
                    self.spawn_pattern_state.wave_active = false
                    self.spawn_pattern_state.wave_count = 0
                end
            end
        else
            -- Between waves, wait
            if self.spawn_pattern_state.wave_timer >= 2.5 then  -- 2.5s pause
                self.spawn_pattern_state.wave_active = true
                self.spawn_pattern_state.wave_timer = 0
            end
        end
    elseif self.obstacle_spawn_pattern == "clusters" then
        -- Spawn 3-5 objects at similar angles
        if self.spawn_pattern_state.cluster_pending > 0 then
            self:spawnSingleObject()
            self.spawn_pattern_state.cluster_pending = self.spawn_pattern_state.cluster_pending - 1
        else
            -- Normal spawn, but trigger cluster
            self.spawn_pattern_state.cluster_pending = math.random(2, 4)  -- Spawn 3-5 total (including this one)
            self:spawnSingleObject()
        end
    elseif self.obstacle_spawn_pattern == "spiral" then
        -- Spawn in rotating pattern
        local sx, sy = self:pickSpawnPointAtAngle(self.spawn_pattern_state.spiral_angle)
        local tx, ty = self:pickTargetPointOnRing()
        local angle = math.atan2(ty - sy, tx - sx)
        angle = self:ensureInboundAngle(sx, sy, angle)
        self:createObject(sx, sy, angle, false)
        self.spawn_pattern_state.spiral_angle = self.spawn_pattern_state.spiral_angle + math.rad(30)
    elseif self.obstacle_spawn_pattern == "pulse_with_arena" then
        -- Spawn from safe zone boundary outward
        if self.safe_zone then
            local spawn_angle = math.random() * math.pi * 2
            local sx = self.safe_zone.x + math.cos(spawn_angle) * self.safe_zone.radius
            local sy = self.safe_zone.y + math.sin(spawn_angle) * self.safe_zone.radius
            local angle = spawn_angle  -- Continue outward
            self:createObject(sx, sy, angle, false)
        else
            self:spawnSingleObject()
        end
    else
        -- Default: random
        self:spawnSingleObject()
    end
end

function DodgeGame:spawnSingleObject()
    -- Phase 1.4: Spawn variant-specific enemies if defined
    if self:hasVariantEnemies() and math.random() < 0.3 then
        -- 30% chance to spawn a variant-specific enemy
        self:spawnVariantEnemy(false)
    elseif self.warning_enabled and math.random() < ((DodgeCfg.spawn and DodgeCfg.spawn.warning_chance) or 0.7) then
        table.insert(self.warnings, self:createWarning())
    else
        -- createRandomObject already inserts into self.objects
        self:createRandomObject(false)
    end
end

-- Phase 1.4: Check if variant has enemies defined
function DodgeGame:hasVariantEnemies()
    return self.enemy_composition and next(self.enemy_composition) ~= nil
end

-- Phase 1.4: Spawn an enemy from variant composition
function DodgeGame:spawnVariantEnemy(warned_status)
    if not self:hasVariantEnemies() then
        return self:createRandomObject(warned_status)
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

    -- Spawn the enemy
    local sx, sy = self:pickSpawnPoint()
    local tx, ty = self:pickTargetPointOnRing()
    local angle = math.atan2(ty - sy, tx - sx)
    angle = self:ensureInboundAngle(sx, sy, angle)

    local enemy_def = self.ENEMY_TYPES[chosen_type]
    if enemy_def then
        self:createEnemyObject(sx, sy, angle, warned_status, enemy_def)
    else
        -- Fallback to regular object if enemy type not found
        self:createObject(sx, sy, angle, warned_status, 'linear')
    end
end

-- Phase 1.4: Create enemy object based on enemy definition
function DodgeGame:createEnemyObject(spawn_x, spawn_y, angle, was_warned, enemy_def)
    -- Map enemy type to base behavior
    local base_type = enemy_def.base_type or 'linear'
    local speed_mult = enemy_def.speed_multiplier or 1.0

    local obj = {
        warned = was_warned,
        radius = OBJECT_RADIUS,
        type = base_type,
        enemy_type = enemy_def.name,  -- Store enemy type for identification
        speed = self.object_speed * speed_mult,
        is_enemy = true  -- Mark as variant enemy (not regular obstacle)
    }

    obj.x = spawn_x
    obj.y = spawn_y
    obj.angle = angle or 0
    obj.vx = math.cos(obj.angle) * obj.speed
    obj.vy = math.sin(obj.angle) * obj.speed

    -- Special initialization for specific enemy types
    if base_type == 'zigzag' or base_type == 'sine' then
        local zig = (DodgeCfg.objects and DodgeCfg.objects.zigzag) or { wave_speed_min = 6, wave_speed_range = 4, wave_amp = 30 }
        obj.wave_speed = (zig.wave_speed_min or 6) + math.random() * (zig.wave_speed_range or 4)
        obj.wave_amp = zig.wave_amp or 30
        obj.wave_phase = math.random()*math.pi*2
    elseif base_type == 'shooter' then
        obj.shoot_timer = enemy_def.shoot_interval or 2.0
        obj.shoot_interval = enemy_def.shoot_interval or 2.0
    elseif base_type == 'teleporter' then
        obj.teleport_timer = enemy_def.teleport_interval or 3.0
        obj.teleport_interval = enemy_def.teleport_interval or 3.0
        obj.teleport_range = enemy_def.teleport_range or 100
    elseif base_type == 'bouncer' then
        obj.bounce_count = 0
    end

    table.insert(self.objects, obj)
    return obj
end

-- Choose a spawn point just outside the play bounds on a random edge
function DodgeGame:pickSpawnPoint()
    -- Spawn just inside the offscreen threshold so first update doesn't cull them
    local inset = ((DodgeCfg.arena and DodgeCfg.arena.spawn_inset) or 2)
    local r = OBJECT_RADIUS
    local edge = math.random(4) -- 1=left,2=right,3=top,4=bottom
    if edge == 1 then return -r + inset, math.random(0, self.game_height)
    elseif edge == 2 then return self.game_width + r - inset, math.random(0, self.game_height)
    elseif edge == 3 then return math.random(0, self.game_width), -r + inset
    else return math.random(0, self.game_width), self.game_height + r - inset end
end

function DodgeGame:pickSpawnPointAtAngle(angle)
    -- Spawn at a specific angle around the edges
    -- Map angle to edge position
    local inset = ((DodgeCfg.arena and DodgeCfg.arena.spawn_inset) or 2)
    local r = OBJECT_RADIUS
    local center_x = self.game_width / 2
    local center_y = self.game_height / 2
    local dist = math.max(self.game_width, self.game_height)
    local sx = center_x + math.cos(angle) * dist
    local sy = center_y + math.sin(angle) * dist
    -- Clamp to edges
    if sx < 0 then sx = -r + inset end
    if sx > self.game_width then sx = self.game_width + r - inset end
    if sy < 0 then sy = -r + inset end
    if sy > self.game_height then sy = self.game_height + r - inset end
    return sx, sy
end

-- Pick a point on a larger target ring around the safe zone
function DodgeGame:pickTargetPointOnRing()
    local sz = self.safe_zone
    local scale = TARGET_RING_MIN_SCALE + math.random() * (TARGET_RING_MAX_SCALE - TARGET_RING_MIN_SCALE)
    local r = (sz and sz.radius or math.min(self.game_width, self.game_height) * 0.4) * scale
    local a = math.random() * math.pi * 2
    local cx = sz and sz.x or self.game_width/2
    local cy = sz and sz.y or self.game_height/2
    return cx + math.cos(a) * r, cy + math.sin(a) * r
end

-- Ensure the initial heading points into the play area from the chosen edge
function DodgeGame:ensureInboundAngle(sx, sy, angle)
    local vx, vy = math.cos(angle), math.sin(angle)
    if sx <= 0 then -- left edge
        if vx <= 0 then angle = math.atan2(vy, math.abs(vx)) end
    elseif sx >= self.game_width then -- right edge
        if vx >= 0 then angle = math.atan2(vy, -math.abs(vx)) end
    elseif sy <= 0 then -- top edge
        if vy <= 0 then angle = math.atan2(math.abs(vy), vx) end
    elseif sy >= self.game_height then -- bottom edge
        if vy >= 0 then angle = math.atan2(-math.abs(vy), vx) end
    end
    return angle
end

function DodgeGame:createWarning()
    local sx, sy = self:pickSpawnPoint()
    local tx, ty = self:pickTargetPointOnRing()
    local angle = math.atan2(ty - sy, tx - sx)
    angle = self:ensureInboundAngle(sx, sy, angle)
    local warning_duration = WARNING_TIME / self.difficulty_modifiers.speed
    return { type = 'radial', sx = sx, sy = sy, angle = angle, time = warning_duration }
end

function DodgeGame:createObjectFromWarning(warning)
    self:createObject(warning.sx, warning.sy, warning.angle, true)
end

function DodgeGame:createRandomObject(warned_status)
    local sx, sy = self:pickSpawnPoint()
    local tx, ty = self:pickTargetPointOnRing()
    local angle = math.atan2(ty - sy, tx - sx)
    angle = self:ensureInboundAngle(sx, sy, angle)
    -- Choose type by weighted randomness scaling with time (Config-driven)
    local t = self.time_elapsed
    local weights = (DodgeCfg.objects and DodgeCfg.objects.weights) or {
        linear  = { base = 50, growth = 0.0 },
        zigzag  = { base = 22, growth = 0.30 },
        sine    = { base = 18, growth = 0.22 },
        seeker  = { base = 4,  growth = 0.08 },
        splitter= { base = 7,  growth = 0.18 }
    }
    local function pick(weights_cfg)
        local sum = 0
        for _, cfg in pairs(weights_cfg) do
            sum = sum + ((cfg.base or 0) + t * (cfg.growth or 0))
        end
        local r = math.random() * sum
        for k, cfg in pairs(weights_cfg) do
            r = r - ((cfg.base or 0) + t * (cfg.growth or 0))
            if r <= 0 then return k end
        end
        return 'linear'
    end
    local kind = pick(weights)
    self:createObject(sx, sy, angle, warned_status, kind)
end

function DodgeGame:createObject(spawn_x, spawn_y, angle, was_warned, kind)
    -- Base radius with size variance applied
    local base_radius = OBJECT_RADIUS
    if self.obstacle_size_variance > 0 then
        -- Variance creates mix: 0.5x to 1.5x base size
        local size_mult = 0.5 + math.random() * self.obstacle_size_variance
        base_radius = OBJECT_RADIUS * size_mult
    end

    -- Base speed with type multiplier
    local type_mult = ((DodgeCfg.objects and DodgeCfg.objects.type_speed_multipliers and DodgeCfg.objects.type_speed_multipliers[kind or 'linear']) or (kind == 'seeker' and 0.9 or kind == 'splitter' and 0.8 or kind == 'zigzag' and 1.1 or kind == 'sine' and 1.0 or 1.0))
    local base_speed = self.object_speed * type_mult

    -- Apply speed variance
    if self.obstacle_speed_variance > 0 then
        local speed_var = 1.0 + (math.random() - 0.5) * 2 * self.obstacle_speed_variance
        base_speed = base_speed * speed_var
    end

    local obj = {
        warned = was_warned,
        radius = base_radius,
        type = kind or 'linear',
        speed = base_speed,
        tracking_strength = self.obstacle_tracking or 0  -- Store tracking strength
    }
    obj.x = spawn_x
    obj.y = spawn_y
    -- Heading toward chosen target angle
    obj.angle = angle or 0
    obj.vx = math.cos(obj.angle) * obj.speed
    obj.vy = math.sin(obj.angle) * obj.speed

    -- Initialize trail if enabled
    if self.obstacle_trails > 0 then
        obj.trail_positions = {}
    end

    if obj.type == 'zigzag' or obj.type == 'sine' then
        local zig = (DodgeCfg.objects and DodgeCfg.objects.zigzag) or { wave_speed_min = 6, wave_speed_range = 4, wave_amp = 30 }
        obj.wave_speed = (zig.wave_speed_min or 6) + math.random() * (zig.wave_speed_range or 4)
        obj.wave_amp = zig.wave_amp or 30
        obj.wave_phase = math.random()*math.pi*2
    end
    table.insert(self.objects, obj)
    return obj
end

function DodgeGame:spawnShards(parent, count)
    local n = count or (((DodgeCfg.objects and DodgeCfg.objects.splitter and DodgeCfg.objects.splitter.shards_count) or 2))
    for i=1,n do
        -- Emit shards around parent's current heading with some spread
        local spread = math.rad(((DodgeCfg.objects and DodgeCfg.objects.splitter and DodgeCfg.objects.splitter.spread_deg) or 35))
        local a = parent.angle + (math.random()*2 - 1) * spread
        local shard = {
            x = parent.x,
            y = parent.y,
            radius = math.max(((DodgeCfg.objects and DodgeCfg.objects.splitter and DodgeCfg.objects.splitter.shard_radius_min) or 6), math.floor(parent.radius * (((DodgeCfg.objects and DodgeCfg.objects.splitter and DodgeCfg.objects.splitter.shard_radius_factor) or 0.6)))) ,
            type = 'linear',
            -- about 70% slower than previous 1.2x => ~0.36x base speed
            speed = self.object_speed * (((DodgeCfg.objects and DodgeCfg.objects.splitter and DodgeCfg.objects.splitter.shard_speed_factor) or 0.36)),
            warned = false
        }
        shard.angle = a
        shard.vx = math.cos(shard.angle) * shard.speed
        shard.vy = math.sin(shard.angle) * shard.speed
        table.insert(self.objects, shard)
    end
end

function DodgeGame:isObjectOffscreen(obj)
    if not obj then return true end
    return obj.x < -obj.radius or obj.x > self.game_width + obj.radius or
           obj.y < -obj.radius or obj.y > self.game_height + obj.radius
end

function DodgeGame:updateSafeZone(dt)
    local sz = self.safe_zone
    if not sz then return end

    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.dodge) or {}
    local drift_speed = ((runtimeCfg.drift and runtimeCfg.drift.base_speed) or 45)
    local level_scale = 1 + ((runtimeCfg.drift and runtimeCfg.drift.level_scale_add_per_level) or 0.15) * math.max(0, (self.difficulty_level or 1) - 1)
    drift_speed = drift_speed * level_scale

    -- Update direction timer and change target velocity periodically
    sz.direction_timer = sz.direction_timer + dt
    if sz.direction_timer >= sz.direction_change_interval then
        sz.direction_timer = 0

        if sz.area_movement_type == "random" then
            -- Pick new random direction
            local drift_angle = math.random() * math.pi * 2
            sz.target_vx = math.cos(drift_angle) * drift_speed * sz.area_movement_speed
            sz.target_vy = math.sin(drift_angle) * drift_speed * sz.area_movement_speed
        elseif sz.area_movement_type == "cardinal" then
            -- Pick new random cardinal direction
            local cardinal_dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
            local dir = cardinal_dirs[math.random(1, 4)]
            sz.target_vx = dir[1] * drift_speed * sz.area_movement_speed
            sz.target_vy = dir[2] * drift_speed * sz.area_movement_speed
        end
    end

    -- Apply friction to interpolate actual velocity toward target velocity
    if sz.area_friction < 1.0 then
        -- Smooth momentum-based transition
        local friction_factor = math.pow(sz.area_friction, dt * 60)
        sz.vx = sz.vx + (sz.target_vx - sz.vx) * (1 - friction_factor)
        sz.vy = sz.vy + (sz.target_vy - sz.vy) * (1 - friction_factor)
    else
        -- Instant direction changes
        sz.vx = sz.target_vx
        sz.vy = sz.target_vy
    end

    -- Movement and bounce
    local accel = 1 + math.min(((runtimeCfg.drift and runtimeCfg.drift.accel and runtimeCfg.drift.accel.max) or 1.0), (self.time_elapsed or 0) / ((runtimeCfg.drift and runtimeCfg.drift.accel and runtimeCfg.drift.accel.time) or 90))
    sz.x = sz.x + sz.vx * accel * dt
    sz.y = sz.y + sz.vy * accel * dt

    -- Bounce at arena bounds (and reverse target velocity too for consistency)
    if sz.x - sz.radius < 0 or sz.x + sz.radius > self.game_width then
        sz.vx = -sz.vx
        sz.target_vx = -sz.target_vx
        sz.x = math.max(sz.radius, math.min(self.game_width - sz.radius, sz.x))
    end
    if sz.y - sz.radius < 0 or sz.y + sz.radius > self.game_height then
        sz.vy = -sz.vy
        sz.target_vy = -sz.target_vy
        sz.y = math.max(sz.radius, math.min(self.game_height - sz.radius, sz.y))
    end

    -- Update holes that are attached to the safe zone boundary
    if self.holes then
        for _, hole in ipairs(self.holes) do
            if hole.on_boundary then
                -- Reposition hole on the boundary at its stored angle
                hole.x = sz.x + math.cos(hole.angle) * sz.radius
                hole.y = sz.y + math.sin(hole.angle) * sz.radius
            end
        end
    end
end

function DodgeGame:updateSafeMorph(dt)
    local sz = self.safe_zone
    if not sz then return end

    sz.morph_time = sz.morph_time + dt * sz.area_morph_speed

    if sz.area_morph_type == "shrink" then
        -- Shrink toward min radius over time
        if sz.radius > sz.min_radius then
            sz.radius = math.max(sz.min_radius, sz.radius - sz.shrink_speed * dt)
        end

    elseif sz.area_morph_type == "pulsing" then
        -- Oscillate between initial_radius and min_radius using sine wave
        local pulse = (math.sin(sz.morph_time * 2) + 1) / 2  -- 0 to 1
        sz.radius = sz.min_radius + (sz.initial_radius - sz.min_radius) * pulse

    elseif sz.area_morph_type == "shape_shifting" then
        -- Cycle through shapes at intervals
        local shape_shift_interval = 3.0  -- seconds per shape
        if sz.morph_time >= shape_shift_interval then
            sz.morph_time = 0
            -- Cycle: circle -> square -> hex -> circle
            local shapes = {"circle", "square", "hex"}
            sz.shape_index = (sz.shape_index % 3) + 1
            sz.area_shape = shapes[sz.shape_index]
        end

        -- Still shrink even while shape shifting
        if sz.radius > sz.min_radius then
            sz.radius = math.max(sz.min_radius, sz.radius - sz.shrink_speed * dt)
        end

    elseif sz.area_morph_type == "deformation" then
        -- Wobble/deformation (visual effect, handled in rendering)
        -- Still shrink the base radius
        if sz.radius > sz.min_radius then
            sz.radius = math.max(sz.min_radius, sz.radius - sz.shrink_speed * dt)
        end

    elseif sz.area_morph_type == "none" then
        -- No morphing, static size
        -- Do nothing
    end
end

function DodgeGame:checkComplete()
    -- Check loss conditions
    if self.game_over or self.metrics.collisions >= self.lives then
        return true
    end

    -- Check victory conditions
    if self.victory_condition == "time" then
        return self.time_elapsed >= self.victory_limit
    elseif self.victory_condition == "dodge_count" then
        return self.metrics.objects_dodged >= self.dodge_target
    end

    return false
end

-- Phase 3.3: Override onComplete to play appropriate sound
function DodgeGame:onComplete()
    -- Determine if win or loss based on victory condition
    local is_win = false
    if self.victory_condition == "time" then
        is_win = self.time_elapsed >= self.victory_limit
    elseif self.victory_condition == "dodge_count" then
        is_win = self.metrics.objects_dodged >= self.dodge_target
    end

    -- Apply score multiplier to metrics if won
    if is_win and self.score_mode ~= "none" then
        local multiplier = self:getScoreMultiplier()
        if multiplier > 1.0 then
            print(string.format("[DodgeGame] Score multiplier applied: %.2fx (%s mode)", multiplier, self.score_mode))
            -- Apply multiplier to key metrics
            self.metrics.objects_dodged = math.floor(self.metrics.objects_dodged * multiplier)
            self.metrics.perfect_dodges = math.floor(self.metrics.perfect_dodges * multiplier)
        end
    end

    -- Play appropriate sound (death sound already played inline at collision)
    if is_win then
        self:playSound("success", 1.0)
    end

    -- Stop music
    self:stopMusic()

    -- Call parent onComplete
    DodgeGame.super.onComplete(self)
end

-- Report progress toward goal for token gating (0..1)
function DodgeGame:getCompletionRatio()
    if self.victory_condition == "time" then
        if self.victory_limit and self.victory_limit > 0 then
            return math.min(1.0, self.time_elapsed / self.victory_limit)
        end
    elseif self.victory_condition == "dodge_count" then
        if self.dodge_target and self.dodge_target > 0 then
            return math.min(1.0, (self.metrics.objects_dodged or 0) / self.dodge_target)
        end
    end
    return 1.0
end

function DodgeGame:keypressed(key)
    return false
end

return DodgeGame