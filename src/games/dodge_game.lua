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

    self.player = {
        x = self.game_width / 2,
        y = self.game_height / 2,
        size = PLAYER_SIZE,
        radius = PLAYER_RADIUS,
        rotation = 0,  -- Current rotation angle in radians (0 = facing right)
        rotation_speed = rotation_speed,  -- Store per-variant rotation speed
        movement_speed = movement_speed,  -- Store per-variant movement speed
        movement_type = movement_type,    -- Store per-variant movement type
        accel_friction = accel_friction,  -- Friction when accelerating (1.0 = none, <1.0 = resistance)
        decel_friction = decel_friction,  -- Friction when decelerating/stopping (1.0 = instant stop, <1.0 = drift)
        bounce_damping = bounce_damping,  -- Universal bounce damping
        reverse_mode = reverse_mode,      -- Asteroids reverse mode
        vx = 0,  -- Velocity (used in asteroids mode, and optionally in default mode if friction < 1.0)
        vy = 0   -- Velocity
    }

    self.objects = {}
    self.warnings = {}
    self.time_elapsed = 0

    self.spawn_rate = (BASE_SPAWN_RATE / self.difficulty_modifiers.count) / variant_difficulty
    self.object_speed = ((BASE_OBJECT_SPEED * self.difficulty_modifiers.speed) * speed_modifier) * variant_difficulty
    self.warning_enabled = self.difficulty_modifiers.complexity <= ((DodgeCfg.warnings and DodgeCfg.warnings.complexity_threshold) or 2)
    self.dodge_target = math.floor(BASE_DODGE_TARGET * self.difficulty_modifiers.complexity * variant_difficulty)

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

    -- Safe zone (Undertale-like arena)
    local min_dim = math.min(self.game_width, self.game_height)
    local level_scale = 1 + ((DodgeCfg.drift and DodgeCfg.drift.level_scale_add_per_level) or 0.15) * math.max(0, (self.difficulty_level or 1) - 1) -- faster with clone iteration
    local drift_speed = ((DodgeCfg.drift and DodgeCfg.drift.base_speed) or 45) * level_scale -- px/sec base
    local drift_angle = math.random() * math.pi * 2
    local drift_vx = math.cos(drift_angle) * drift_speed
    local drift_vy = math.sin(drift_angle) * drift_speed
    self.safe_zone = {
        x = self.game_width / 2,
        y = self.game_height / 2,
    radius = min_dim * ((DodgeCfg.arena and DodgeCfg.arena.initial_safe_radius_fraction) or 0.48),
        min_radius = min_dim * MIN_SAFE_RADIUS_FRACTION,
    shrink_speed = (min_dim * (((DodgeCfg.arena and DodgeCfg.arena.initial_safe_radius_fraction) or 0.48) - MIN_SAFE_RADIUS_FRACTION)) / (SAFE_ZONE_SHRINK_SEC / self.difficulty_modifiers.complexity),
        vx = drift_vx,
        vy = drift_vy
    }
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
    self.time_elapsed = self.time_elapsed + dt
    self:updateSafeZone(dt)
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

function DodgeGame:updatePlayer(dt)
    if self.player.movement_type == "asteroids" then
        self:updatePlayerAsteroids(dt)
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

function DodgeGame:clampPlayerPosition()
    -- Clamp to rectangular bounds first
    self.player.x = math.max(self.player.radius, math.min(self.game_width - self.player.radius, self.player.x))
    self.player.y = math.max(self.player.radius, math.min(self.game_height - self.player.radius, self.player.y))

    -- Clamp to circular safe zone
    local sz = self.safe_zone
    if sz then
        local dxp = self.player.x - sz.x
        local dyp = self.player.y - sz.y
        local dist = math.sqrt(dxp*dxp + dyp*dyp)
        local max_dist = math.max(0, sz.radius - self.player.radius)
        if dist > max_dist and dist > 0 then
            local scale = max_dist / dist
            self.player.x = sz.x + dxp * scale
            self.player.y = sz.y + dyp * scale

            -- If using velocity-based movement, dampen velocity when hitting safe zone boundary
            if self.player.friction < 1.0 then
                -- Project velocity onto boundary normal and dampen
                local nx = dxp / dist
                local ny = dyp / dist
                local dot = self.player.vx * nx + self.player.vy * ny
                if dot > 0 then  -- Moving outward
                    local bounce_factor = 1.0 + self.player.bounce_damping
                    self.player.vx = self.player.vx - nx * dot * bounce_factor  -- Bounce inward
                    self.player.vy = self.player.vy - ny * dot * bounce_factor
                end
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
            -- Count hit, remove (splitter no longer splits here)
            table.remove(self.objects, i)
            self.metrics.collisions = self.metrics.collisions + 1

            -- Phase 3.3: Play hit sound
            self:playSound("hit", 1.0)

            if self.metrics.collisions >= self.MAX_COLLISIONS then
                -- Phase 3.3: Play death sound
                self:playSound("death", 1.0)
                self:onComplete()
                return
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
    local obj = {
        warned = was_warned,
        radius = OBJECT_RADIUS,
        type = kind or 'linear',
        speed = self.object_speed * (((DodgeCfg.objects and DodgeCfg.objects.type_speed_multipliers and DodgeCfg.objects.type_speed_multipliers[kind or 'linear']) or (kind == 'seeker' and 0.9 or kind == 'splitter' and 0.8 or kind == 'zigzag' and 1.1 or kind == 'sine' and 1.0 or 1.0)))
    }
    obj.x = spawn_x
    obj.y = spawn_y
    -- Heading toward chosen target angle
    obj.angle = angle or 0
    obj.vx = math.cos(obj.angle) * obj.speed
    obj.vy = math.sin(obj.angle) * obj.speed

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
    -- Shrink toward min radius
    if sz.radius > sz.min_radius then
        sz.radius = math.max(sz.min_radius, sz.radius - sz.shrink_speed * dt)
    end
    -- Drift and bounce (slight acceleration over time)
    local accel = 1 + math.min(((DodgeCfg.drift and DodgeCfg.drift.accel and DodgeCfg.drift.accel.max) or 1.0), (self.time_elapsed or 0) / ((DodgeCfg.drift and DodgeCfg.drift.accel and DodgeCfg.drift.accel.time) or 90))
    sz.x = sz.x + sz.vx * accel * dt
    sz.y = sz.y + sz.vy * accel * dt
    local margin = sz.radius
    if sz.x - sz.radius < 0 or sz.x + sz.radius > self.game_width then sz.vx = -sz.vx; sz.x = math.max(sz.radius, math.min(self.game_width - sz.radius, sz.x)) end
    if sz.y - sz.radius < 0 or sz.y + sz.radius > self.game_height then sz.vy = -sz.vy; sz.y = math.max(sz.radius, math.min(self.game_height - sz.radius, sz.y)) end
end

function DodgeGame:checkComplete()
    return self.metrics.collisions >= self.MAX_COLLISIONS or self.metrics.objects_dodged >= self.dodge_target
end

-- Phase 3.3: Override onComplete to play appropriate sound
function DodgeGame:onComplete()
    -- Determine if win or loss
    local is_win = self.metrics.objects_dodged >= self.dodge_target

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
    if self.dodge_target and self.dodge_target > 0 then
        return math.min(1.0, (self.metrics.objects_dodged or 0) / self.dodge_target)
    end
    return 1.0
end

function DodgeGame:keypressed(key)
    return false
end

return DodgeGame