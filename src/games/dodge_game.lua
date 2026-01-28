--[[
    Dodge Game - Survival dodging game with extensive variants

    Avoid obstacles that spawn from screen edges. Supports multiple movement modes,
    arena shapes, enemy types, safe zones, and difficulty scaling.

    Configuration from dodge_schema.json via SchemaLoader.
    Components created from schema in setupComponents().
]]

local BaseGame = require('src.games.base_game')
local DodgeView = require('src.games.views.dodge_view')
local PhysicsUtils = require('src.utils.game_components.physics_utils')
local PatternMovement = require('src.utils.game_components.pattern_movement')
local DodgeGame = BaseGame:extend('DodgeGame')

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function DodgeGame:init(game_data, cheats, di, variant_override)
    DodgeGame.super.init(self, game_data, cheats, di, variant_override)

    self.runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.dodge) or {}
    self.params = self.di.components.SchemaLoader.load(self.variant, "dodge_schema", self.runtimeCfg)
    self:applyCheats({
        speed_modifier = {"movement_speed", "base_object_speed"},
        advantage_modifier = {"lives", "max_collisions", "safe_zone_size"},
        performance_modifier = {"obstacle_spawn_rate"}
    })

    self:setupArenaDimensions()
    local p = self.params
    self:createPlayer({
        x = self.game_width / 2,
        y = self.game_height / 2,
        radius = (p.player_base_size or 20) * (p.player_size or 1),
        extra = {
            size = (p.player_base_size or 20) * (p.player_size or 1),
            angle = 0, rotation_speed = p.rotation_speed, movement_speed = p.movement_speed,
            max_speed = p.max_speed, movement_type = p.movement_type,
            accel_friction = p.accel_friction, decel_friction = p.decel_friction,
            bounce_damping = p.bounce_damping, reverse_mode = p.reverse_mode,
            jump_distance = p.jump_distance, jump_cooldown = p.jump_cooldown,
            jump_speed = p.jump_speed, last_jump_time = -999,
            is_jumping = false, jump_target_x = 0, jump_target_y = 0,
            jump_dir_x = 0, jump_dir_y = 0, time_elapsed = 0
        }
    })
    self:setupComponents()
    self:setupEntities()

    self.default_sprite_set = "dodge_base"
    self.view = DodgeView:new(self, self.variant)
    self:loadAssets()
end

function DodgeGame:setupComponents()
    local p = self.params

    -- Schema-driven components (health_system, hud, fog_controller, visual_effects)
    local game = self
    self:createComponentsFromSchema()
    self.fog_controller.enabled = p.fog_of_war_origin ~= "none" and p.fog_of_war_radius < 9999
    self.lives = self.health_system.lives

    -- Progress bar based on victory condition
    if p.victory_condition == "time" then
        self.hud.progress = {label = "Survive", current_key = "time_elapsed", total_key = "params.victory_limit", show_bar = true}
    else
        self.hud.progress = {label = "Dodge", current_key = "metrics.objects_dodged", total_key = "dodge_target", show_bar = true}
    end

    -- Damage callbacks
    self.health_system.on_shield_break = function()
        game.visual_effects:shake(nil, p.camera_shake_intensity * 0.5, "exponential")
    end
    self.health_system.on_damage = function()
        game.visual_effects:shake(nil, p.camera_shake_intensity, "exponential")
    end

    -- Movement controller
    local mode_map = {asteroids = "asteroids", jump = "jump"}
    local MovementController = self.di.components.MovementController
    self.movement_controller = MovementController:new({
        mode = mode_map[p.movement_type] or "direct",
        speed = p.movement_speed, friction = 1.0,
        accel_friction = p.accel_friction, decel_friction = p.decel_friction,
        rotation_speed = p.rotation_speed, bounce_damping = p.bounce_damping,
        thrust_acceleration = (self.runtimeCfg.player and self.runtimeCfg.player.thrust_acceleration) or 600,
        reverse_mode = p.reverse_mode,
        jump_distance = p.jump_distance, jump_cooldown = p.jump_cooldown, jump_speed = p.jump_speed
    })

    -- Arena controller (safe zone)
    local min_dim = math.min(self.game_width, self.game_height)
    local level_scale = 1 + ((self.runtimeCfg.drift and self.runtimeCfg.drift.level_scale_add_per_level) or 0.15) * math.max(0, (self.difficulty_level or 1) - 1)
    local drift_speed = ((self.runtimeCfg.drift and self.runtimeCfg.drift.base_speed) or 45) * level_scale

    local target_vx, target_vy = 0, 0
    if p.area_movement_type == "random" then
        local angle = math.random() * math.pi * 2
        target_vx = math.cos(angle) * drift_speed * p.area_movement_speed
        target_vy = math.sin(angle) * drift_speed * p.area_movement_speed
    elseif p.area_movement_type == "cardinal" then
        local dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
        local dir = dirs[math.random(1, 4)]
        target_vx = dir[1] * drift_speed * p.area_movement_speed
        target_vy = dir[2] * drift_speed * p.area_movement_speed
    end

    local initial_radius = min_dim * (p.initial_safe_radius_fraction or 0.48) * p.area_size
    local min_radius = min_dim * (p.min_safe_radius_fraction or 0.35) * p.area_size
    local shrink_speed = (initial_radius - min_radius) / ((p.safe_zone_shrink_sec or 45) / self.difficulty_modifiers.complexity)

    local ArenaController = self.di.components.ArenaController
    self.arena_controller = ArenaController:new({
        safe_zone = true, x = self.game_width/2, y = self.game_height/2,
        radius = initial_radius, safe_zone_radius = initial_radius,
        safe_zone_min_radius = min_radius, safe_zone_shrink_speed = shrink_speed,
        shape = p.area_shape or "circle", morph_type = p.area_morph_type or "shrink",
        morph_speed = p.area_morph_speed or 1.0, shrink_speed = shrink_speed,
        movement = (p.area_movement_type == "random") and "drift" or p.area_movement_type,
        movement_speed = drift_speed * p.area_movement_speed, friction = p.area_friction or 0.95,
        direction_change_interval = 2.0, container_width = self.game_width,
        container_height = self.game_height, bounds_padding = 0,
        vx = target_vx, vy = target_vy, target_vx = target_vx, target_vy = target_vy
    })

    if p.holes_count > 0 and p.holes_type ~= "none" then
        for i = 1, p.holes_count do
            local hole = {radius = 8}
            if p.holes_type == "circle" then
                local angle = math.random() * math.pi * 2
                hole.angle = angle
                hole.x, hole.y = self.arena_controller:getPointOnShapeBoundary(angle, initial_radius)
                hole.on_boundary = true
            else
                hole.x = math.random(hole.radius, self.game_width - hole.radius)
                hole.y = math.random(hole.radius, self.game_height - hole.radius)
                hole.on_boundary = false
            end
            self.arena_controller:addHole(hole)
        end
    end
    self.holes = self.arena_controller.holes  -- Alias for view
    self.leaving_area_ends_game = p.leaving_area_ends_game

    -- Player trail
    self.player_trail = PhysicsUtils.createTrailSystem({
        max_length = p.player_trail_length, color = {0.5, 0.7, 1.0, 0.3}, line_width = 3
    })

    -- Alias for createEntityControllerFromSchema (expects entity_types)
    self.params.entity_types = self.params.enemy_types

    -- Entity controller from schema with pattern-based spawning
    local pattern = p.obstacle_spawn_pattern or "random"
    local spawn_func = function(ec)
        local sx, sy, forced_angle
        local margin = (p.object_radius or 15) - ((game.runtimeCfg.arena and game.runtimeCfg.arena.spawn_inset) or 2)
        local bounds = {min_x = 0, max_x = game.game_width, min_y = 0, max_y = game.game_height}
        if pattern == "spiral" then
            sx, sy = ec:calculateSpawnPosition({region = "edge", angle = game.spawn_state.spiral_angle, margin = margin, bounds = bounds})
            game.spawn_state.spiral_angle = game.spawn_state.spiral_angle + math.rad(30)
        elseif pattern == "pulse_with_arena" and game.arena_controller then
            sx, sy, forced_angle = game.arena_controller:getRandomBoundaryPoint()
        elseif pattern == "clusters" then
            for i = 1, math.random(2, 4) do
                game:spawnNext()
            end
            return
        else
            sx, sy = ec:calculateSpawnPosition({region = "edge", margin = margin, bounds = bounds})
        end
        game:spawnNext(sx, sy, forced_angle)
    end

    local spawn_config
    if pattern == "waves" then
        spawn_config = {mode = "burst", burst_count = 6, burst_interval = 0.15, burst_pause = 2.5, spawn_func = spawn_func}
    else
        spawn_config = {mode = "continuous", rate = 1.0, spawn_func = spawn_func, max_concurrent = 500}
    end
    self:createEntityControllerFromSchema({}, {spawning = spawn_config, pooling = true, max_entities = 500})

    -- Global on_remove callback for dodge counting
    self.entity_controller.on_remove = function(entity, reason)
        if reason == "offscreen" and (entity.entered_play or entity.was_dodged) then
            game:onObjectDodged()
        end
    end

    -- Configure entity behaviors for updateBehaviors
    self.entity_behaviors_config = {
        shooting_enabled = true,
        on_shoot = function(entity)
            game:onEntityShoot(entity)
        end,
        bounce_movement = {
            width = self.game_width,
            height = self.game_height,
            max_bounces = (self.runtimeCfg.objects and self.runtimeCfg.objects.bouncer and self.runtimeCfg.objects.bouncer.max_bounces) or 3
        },
        pattern_movement = {
            PatternMovement = PatternMovement,
            bounds = {x = 0, y = 0, width = self.game_width, height = self.game_height},
            tracking_target = self.player,
            get_difficulty_scaler = function(entity)
                local te = game.time_elapsed or 0
                local max_scaler = (game.runtimeCfg.seeker and game.runtimeCfg.seeker.difficulty and game.runtimeCfg.seeker.difficulty.max) or 2.0
                local scale_time = (game.runtimeCfg.seeker and game.runtimeCfg.seeker.difficulty and game.runtimeCfg.seeker.difficulty.time) or 90
                return 1 + math.min(max_scaler, te / scale_time)
            end
        },
        sprite_rotation = true,
        trails = {max_length = p.obstacle_trails or 0},
        track_entered_play = {x = 0, y = 0, width = self.game_width, height = self.game_height},
        remove_offscreen = {
            width = self.game_width, height = self.game_height,
            left = -50, right = self.game_width + 50,
            top = -50, bottom = self.game_height + 50
        },
        collision = {
            target = self.player,
            check_trails = true,
            on_collision = function(entity, target, collision_type)
                game.metrics.collisions = game.metrics.collisions + 1
                game.current_combo = 0
                game:takeDamage(1, "hit")
                if not game.health_system:isAlive() then
                    game:playSound("death", 1.0)
                    game:onComplete()
                end
                return true  -- remove entity
            end
        },
        enter_zone = {
            check_fn = function(entity)
                if entity.type ~= 'splitter' then return false end
                return game.arena_controller:isInside(entity.x, entity.y, -(entity.radius or 10))
            end,
            on_enter = function(entity)
                if entity.type == 'splitter' then
                    local def = game.params.enemy_types.splitter or {}
                    local n = (game.runtimeCfg.objects and game.runtimeCfg.objects.splitter and game.runtimeCfg.objects.splitter.shards_count) or def.shards_count or 3
                    local spread = math.rad(def.spread_deg or 35)
                    for i = 1, n do
                        local a = entity.angle + (math.random() * 2 - 1) * spread
                        game:spawnEntity("obstacle", entity.x, entity.y, a, false, {
                            radius = math.max(def.shard_radius_min or 6, math.floor(entity.radius * (def.shard_radius_factor or 0.6))),
                            speed = game.object_speed * (def.shard_speed_factor or 0.36),
                            movement_pattern = 'straight', type = 'linear'
                        })
                    end
                    return true  -- remove entity
                end
                return false
            end
        },
        delayed_spawn = {
            on_spawn = function(warning_entity, ds)
                local type_name = warning_entity.spawn_type_name or game.entity_controller:pickWeightedType(game.spawn_composition, game.time_elapsed)
                game:spawnEntity(type_name, warning_entity.x, warning_entity.y, warning_entity.spawn_angle or 0, true)
            end
        }
    }

    -- Calculate object_speed for projectile system
    local variant_diff = self.variant and self.variant.difficulty_modifier or 1.0
    local speed_mod = self.cheats.speed_modifier or 1.0
    self.object_speed = ((p.base_object_speed or 200) * self.difficulty_modifiers.speed * speed_mod) * variant_diff

    -- Projectile system
    self:createProjectileSystemFromSchema({pooling = true, max_projectiles = 200})

    -- Victory condition from schema
    self:createVictoryConditionFromSchema()
end

function DodgeGame:setupEntities()
    local p = self.params
    local variant_diff = self.variant and self.variant.difficulty_modifier or 1.0

    -- Entity arrays
    self.objects = {}

    -- Game state
    self.time_elapsed = 0
    self.game_over = false
    self.spawn_rate = ((p.base_spawn_rate or 1.0) / self.difficulty_modifiers.count / variant_diff) / p.obstacle_spawn_rate
    if self.entity_controller.spawning.mode ~= "burst" then
        self.entity_controller.spawn_rate = self.spawn_rate
    end
    self.warning_enabled = self.difficulty_modifiers.complexity <= ((self.runtimeCfg.warnings and self.runtimeCfg.warnings.complexity_threshold) or 2)
    self.dodge_target = p.victory_condition == "dodge_count" and math.floor(p.victory_limit) or 9999

    -- Spawn composition for weighted type selection
    self.spawn_composition = {}
    if self.variant and self.variant.enemies and #self.variant.enemies > 0 then
        for _, ed in ipairs(self.variant.enemies) do
            table.insert(self.spawn_composition, {name = ed.type, weight = ed.multiplier})
        end
    else
        self.spawn_composition = {{name = "obstacle", weight = 1}}
    end

    -- Metrics
    self.metrics.objects_dodged = 0
    self.metrics.collisions = 0
    self.metrics.combo = 0
    self.current_combo = 0

    -- Wind state (uses PhysicsUtils.updateDirectionalForce)
    local wind_type_map = {steady = "constant", turbulent = "turbulent", changing_steady = "rotating", changing_turbulent = "rotating_turbulent"}
    self.wind_state = {
        angle = type(p.wind_direction) == "number" and math.rad(p.wind_direction) or math.random() * math.pi * 2,
        strength = p.wind_strength or 0,
        type = wind_type_map[p.wind_type] or "constant",
        timer = 0,
        change_interval = 3.0,
        change_amount = math.rad(30),
        turbulence_range = math.pi * 0.5
    }

    -- Spawn pattern state
    self.spawn_state = {spiral_angle = 0}
end

--------------------------------------------------------------------------------
-- ASSETS
--------------------------------------------------------------------------------

function DodgeGame:setPlayArea(width, height)
    self.game_width = width
    self.game_height = height
    if self.arena_controller then
        self.arena_controller:setContainerSize(width, height)
    end
    -- Recenter player to match arena
    if self.player then
        self.player.x = width / 2
        self.player.y = height / 2
    end
    -- Update entity behaviors config with new dimensions
    if self.entity_behaviors_config then
        self.entity_behaviors_config.bounce_movement.width = width
        self.entity_behaviors_config.bounce_movement.height = height
        self.entity_behaviors_config.pattern_movement.bounds.width = width
        self.entity_behaviors_config.pattern_movement.bounds.height = height
        self.entity_behaviors_config.remove_offscreen.width = width
        self.entity_behaviors_config.remove_offscreen.height = height
        self.entity_behaviors_config.remove_offscreen.right = width + 50
        self.entity_behaviors_config.remove_offscreen.bottom = height + 50
        self.entity_behaviors_config.track_entered_play.width = width
        self.entity_behaviors_config.track_entered_play.height = height
    end
end

--------------------------------------------------------------------------------
-- MAIN GAME LOOP
--------------------------------------------------------------------------------

function DodgeGame:updateGameLogic(dt)
    if self.game_over or self.completed then return end

    -- Check if player left safe zone (instant death mode)
    if self.leaving_area_ends_game and self.arena_controller then
        if not self.arena_controller:isInside(self.player.x, self.player.y, self.player.radius) then
            self.game_over = true
            self:onComplete()
            return
        end
    end

    -- Check hole collision (instant death)
    for _, hole in ipairs(self.arena_controller.holes) do
        if PhysicsUtils.circleCollision(self.player.x, self.player.y, self.player.radius, hole.x, hole.y, hole.radius) then
            self.game_over = true
            self:onComplete()
            return
        end
    end

    -- Spawn rate acceleration
    if self.entity_controller.spawning.mode ~= "burst" then
        local accel_cfg = (self.runtimeCfg.spawn and self.runtimeCfg.spawn.accel) or {}
        local accel = 1 + math.min(accel_cfg.max or 2.0, self.time_elapsed / (accel_cfg.time or 60))
        self.entity_controller.spawn_rate = self.spawn_rate / accel
    end

    -- Entity controller handles spawning, basic movement, lifetime
    self.entity_controller:update(dt)

    -- Update all entity behaviors (movement patterns, collision, shooting, etc)
    self.entity_controller:updateBehaviors(dt, self.entity_behaviors_config)

    -- Projectile system (separate from entities)
    local game_bounds = {x_min = 0, x_max = self.game_width, y_min = 0, y_max = self.game_height}
    self.projectile_system:update(dt, game_bounds)

    -- Check projectile collision with player
    if self:checkProjectileCollisions() then
        return  -- Game over
    end

    -- Build combined objects list for view
    self.objects = self.entity_controller:getEntities()
    local projectiles = self.projectile_system:getProjectiles()
    for _, proj in ipairs(projectiles) do
        table.insert(self.objects, proj)
    end

    self.arena_controller:update(dt)
    self.health_system:update(dt)
    self.lives = self.health_system.lives
    if self.player_trail then
        self.player_trail:updateFromEntity(self.player)
    end
    self.visual_effects:update(dt)

    -- Player movement
    local input = self:buildInput()
    local bounds = {x = 0, y = 0, width = self.game_width, height = self.game_height, wrap_x = false, wrap_y = false}
    self.player.time_elapsed = self.time_elapsed
    if self.player.rotation then self.player.angle = self.player.rotation end
    self.movement_controller:update(dt, self.player, input, bounds)
    self.player.rotation = self.player.angle

    -- Environment forces
    if self.params.area_gravity ~= 0 and self.arena_controller then
        local dx = self.arena_controller.x - self.player.x
        local dy = self.arena_controller.y - self.player.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
            local force = self.params.area_gravity * dt
            self.player.x = self.player.x + (dx / dist) * force
            self.player.y = self.player.y + (dy / dist) * force
        end
    end
    if self.wind_state.strength > 0 and self.params.wind_type ~= "none" then
        local fx, fy = PhysicsUtils.updateDirectionalForce(self.wind_state, dt)
        self.player.x = self.player.x + fx * dt
        self.player.y = self.player.y + fy * dt
    end

    if self.player.max_speed > 0 then
        PhysicsUtils.clampSpeed(self.player, self.player.max_speed)
    end
    self.arena_controller:clampEntity(self.player)

end

--------------------------------------------------------------------------------
-- CALLBACKS (EntityController behaviors handle most logic)
--------------------------------------------------------------------------------

-- Called by EntityController shooting behavior
function DodgeGame:onEntityShoot(entity)
    if entity.type ~= 'shooter' then return end

    local dx = self.player.x - entity.x
    local dy = self.player.y - entity.y
    local proj_angle = math.atan2(dy, dx)

    local shooter_cfg = (self.variant and self.variant.shooter) or
                       (self.runtimeCfg.objects and self.runtimeCfg.objects.shooter) or
                       {projectile_size = 0.5, projectile_speed = 0.8}

    local projectile_speed = self.object_speed * (shooter_cfg.projectile_speed or 0.8)
    self.projectile_system:shoot(
        "enemy_projectile", entity.x, entity.y, proj_angle,
        projectile_speed / (self.object_speed * 0.8),
        {
            radius = (self.params.object_radius or 15) * (shooter_cfg.projectile_size or 0.5),
            is_projectile = true, warned = false
        }
    )
end

-- Check projectile collision with player (entities handled by EntityController)
function DodgeGame:checkProjectileCollisions()
    for _, proj in ipairs(self.projectile_system:getProjectiles()) do
        if PhysicsUtils.circleCollision(self.player.x, self.player.y, self.player.radius, proj.x, proj.y, proj.radius or 10) then
            self.projectile_system:removeProjectile(proj)
            self.metrics.collisions = self.metrics.collisions + 1
            self.current_combo = 0
            self:takeDamage(1, "hit")

            if not self.health_system:isAlive() then
                self:playSound("death", 1.0)
                self:onComplete()
                return true
            end
        end
    end
    return false
end

function DodgeGame:onObjectDodged()
    self.metrics.objects_dodged = self.metrics.objects_dodged + 1
    self:playSound("dodge", 0.3)
    self.current_combo = self.current_combo + 1
    if self.current_combo > self.metrics.combo then
        self.metrics.combo = self.current_combo
    end
end


--------------------------------------------------------------------------------
-- SPAWNING (Unified Entity System)
--------------------------------------------------------------------------------

function DodgeGame:spawnEntity(type_name, x, y, angle, warned, overrides)
    local enemy_def = self.params.enemy_types[type_name]
    if not enemy_def then
        enemy_def = self.params.enemy_types.obstacle
        type_name = "obstacle"
    end

    local base_type = enemy_def.type or 'linear'
    local speed_mult = enemy_def.speed_multiplier or 1.0
    local name = enemy_def.name or type_name

    -- Size resolution chain
    local size_range = enemy_def.size_range
        or (self.variant and self.variant.enemy_sizes and self.variant.enemy_sizes[name])
        or (self.variant and self.variant.size_range)
        or (self.runtimeCfg.objects and self.runtimeCfg.objects.enemy_sizes and self.runtimeCfg.objects.enemy_sizes[name])
        or (self.runtimeCfg.objects and self.runtimeCfg.objects.size_range)
        or {(self.params.object_radius or 15), (self.params.object_radius or 15)}
    local final_radius = size_range[1] + math.random() * (size_range[2] - size_range[1])

    -- Speed resolution chain
    local speed_range = enemy_def.speed_range
        or (self.variant and self.variant.enemy_speeds and self.variant.enemy_speeds[name])
        or (self.variant and self.variant.speed_range)
        or (self.runtimeCfg.objects and self.runtimeCfg.objects.enemy_speeds and self.runtimeCfg.objects.enemy_speeds[name])
        or (self.runtimeCfg.objects and self.runtimeCfg.objects.speed_range)
        or {self.object_speed, self.object_speed}
    local base_speed = speed_range[1] + math.random() * (speed_range[2] - speed_range[1])
    local final_speed = base_speed * speed_mult

    -- Sprite settings resolution
    local sprite_settings = enemy_def.sprite_settings
        or (self.variant and self.variant.enemy_sprite_settings and self.variant.enemy_sprite_settings[name])
        or (self.runtimeCfg.objects and self.runtimeCfg.objects.enemy_sprite_settings and self.runtimeCfg.objects.enemy_sprite_settings[name])
    local sprite_rotation = (sprite_settings and sprite_settings.rotation) or 0
    local sprite_direction = (sprite_settings and sprite_settings.direction) or "movement_based"

    -- Movement pattern mapping
    local movement_pattern_map = {
        zigzag = 'zigzag', sine = 'wave',
        seeker = 'tracking', chaser = 'tracking',
        teleporter = 'teleporter', bouncer = 'bounce'
    }

    local custom_params = {
        warned = warned,
        radius = final_radius,
        type = base_type,
        enemy_type = name,
        speed = final_speed,
        sprite_rotation_angle = 0,
        sprite_rotation_speed = sprite_rotation,
        sprite_direction_mode = sprite_direction,
        angle = angle or 0,
        direction = angle or 0,
        vx = math.cos(angle or 0) * final_speed,
        vy = math.sin(angle or 0) * final_speed,
        movement_pattern = movement_pattern_map[base_type] or 'straight',
        turn_rate = math.rad(self.params.seeker_turn_rate or 54)
    }

    -- Type-specific params (read from enemy_def first, runtimeCfg fallback)
    if base_type == 'zigzag' or base_type == 'sine' then
        local zig_cfg = (self.runtimeCfg.objects and self.runtimeCfg.objects.zigzag) or {}
        local wave_speed_min = enemy_def.wave_speed_min or zig_cfg.wave_speed_min or 6
        local wave_speed_range = enemy_def.wave_speed_range or zig_cfg.wave_speed_range or 4
        custom_params.wave_speed = wave_speed_min + math.random() * wave_speed_range
        custom_params.wave_amp = enemy_def.wave_amp or zig_cfg.wave_amp or 30
        custom_params.wave_phase = math.random() * math.pi * 2
    elseif base_type == 'shooter' then
        local shoot_interval = enemy_def.shoot_interval
            or (self.variant and self.variant.shooter and self.variant.shooter.shoot_interval)
            or (self.runtimeCfg.objects and self.runtimeCfg.objects.shooter and self.runtimeCfg.objects.shooter.shoot_interval)
            or 2.0
        custom_params.shoot_timer = shoot_interval
        custom_params.shoot_interval = shoot_interval
    elseif base_type == 'teleporter' then
        custom_params.teleport_timer = enemy_def.teleport_interval or 3.0
        custom_params.teleport_interval = enemy_def.teleport_interval or 3.0
        custom_params.teleport_range = enemy_def.teleport_range or 100
    elseif base_type == 'bouncer' then
        custom_params.bounce_count = 0
        custom_params.has_entered = false
    end

    if self.params.obstacle_trails and self.params.obstacle_trails > 0 then
        custom_params.trail_positions = {}
    end

    -- Apply overrides last
    if overrides then
        for k, v in pairs(overrides) do custom_params[k] = v end
    end

    return self.entity_controller:spawn(type_name, x, y, custom_params)
end

function DodgeGame:spawnNext(sx, sy, forced_angle)
    local bounds = {min_x = 0, max_x = self.game_width, min_y = 0, max_y = self.game_height}
    if not sx then
        local margin = (self.params.object_radius or 15) - ((self.runtimeCfg.arena and self.runtimeCfg.arena.spawn_inset) or 2)
        sx, sy = self.entity_controller:calculateSpawnPosition({region = "edge", margin = margin, bounds = bounds})
    end
    local ac = self.arena_controller
    local scale = (self.params.target_ring_min_scale or 1.2) + math.random() * ((self.params.target_ring_max_scale or 1.5) - (self.params.target_ring_min_scale or 1.2))
    local tx, ty = ac:getPointOnShapeBoundary(math.random() * math.pi * 2, ac:getEffectiveRadius() * scale)
    local angle = forced_angle or math.atan2(ty - sy, tx - sx)
    angle = self.entity_controller:ensureInboundAngle(sx, sy, angle, bounds)
    local type_name = self.entity_controller:pickWeightedType(self.spawn_composition, self.time_elapsed)
    local warning_chance = (self.runtimeCfg.spawn and self.runtimeCfg.spawn.warning_chance) or 0.7
    if self.warning_enabled and math.random() < warning_chance then
        local warning_duration = (self.params.warning_time or 0.5) / self.difficulty_modifiers.speed
        self.entity_controller:spawn("warning", sx, sy, {
            type = 'warning', warning_type = 'radial',
            spawn_type_name = type_name, spawn_angle = angle,
            skip_offscreen_removal = true,
            delayed_spawn = {timer = warning_duration, spawn_type = "warning"}
        })
    else
        self:spawnEntity(type_name, sx, sy, angle, false)
    end
end


return DodgeGame
