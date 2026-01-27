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

    -- Entity controller from schema
    self:createEntityControllerFromSchema({}, {spawning = {mode = "manual"}, pooling = true, max_entities = 500})

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
                    local shards = (game.runtimeCfg.objects and game.runtimeCfg.objects.splitter and game.runtimeCfg.objects.splitter.shards_count) or 3
                    game:spawnShards(entity, shards)
                    return true  -- remove entity
                end
                return false
            end
        },
        delayed_spawn = {
            on_spawn = function(warning_entity, ds)
                -- Spawn the actual obstacle when warning timer expires
                game:spawnFromWarning(warning_entity)
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
    self.spawn_timer = 0
    self.game_over = false
    self.spawn_rate = ((p.base_spawn_rate or 1.0) / self.difficulty_modifiers.count / variant_diff) / p.obstacle_spawn_rate
    self.warning_enabled = self.difficulty_modifiers.complexity <= ((self.runtimeCfg.warnings and self.runtimeCfg.warnings.complexity_threshold) or 2)
    self.dodge_target = p.victory_condition == "dodge_count" and math.floor(p.victory_limit) or 9999

    -- Enemy composition from variant
    self.enemy_composition = {}
    if self.variant and self.variant.enemies then
        for _, ed in ipairs(self.variant.enemies) do
            self.enemy_composition[ed.type] = ed.multiplier
        end
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
    self.spawn_pattern_state = {wave_timer = 0, wave_active = false, spiral_angle = 0, cluster_pending = 0}
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

    -- Spawning
    self.spawn_timer = self.spawn_timer - dt
    if self.spawn_timer <= 0 then
        self:spawnObjectOrWarning()
        self.spawn_timer = self.spawn_rate + self.spawn_timer
    end
end

--------------------------------------------------------------------------------
-- CALLBACKS (EntityController behaviors handle most logic)
--------------------------------------------------------------------------------

-- Called by EntityController shooting behavior
function DodgeGame:onEntityShoot(entity)
    if entity.type ~= 'shooter' or not entity.is_enemy then return end

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
-- SPAWNING
--------------------------------------------------------------------------------

function DodgeGame:spawnObjectOrWarning()
    local accel = 1 + math.min(((self.runtimeCfg.spawn and self.runtimeCfg.spawn.accel and self.runtimeCfg.spawn.accel.max) or 2.0), self.time_elapsed / ((self.runtimeCfg.spawn and self.runtimeCfg.spawn.accel and self.runtimeCfg.spawn.accel.time) or 60))
    self.spawn_rate = ((self.params.base_spawn_rate or 1.0) / self.difficulty_modifiers.count) / accel

    if self.params.obstacle_spawn_pattern == "waves" then
        self.spawn_pattern_state.wave_timer = self.spawn_pattern_state.wave_timer + self.spawn_rate
        if self.spawn_pattern_state.wave_active then
            if self.spawn_pattern_state.wave_timer >= 0.15 then
                self.spawn_pattern_state.wave_timer = 0
                self:spawnSingleObject()
                self.spawn_pattern_state.wave_count = (self.spawn_pattern_state.wave_count or 0) + 1
                if self.spawn_pattern_state.wave_count >= 6 then
                    self.spawn_pattern_state.wave_active = false
                    self.spawn_pattern_state.wave_count = 0
                end
            end
        else
            if self.spawn_pattern_state.wave_timer >= 2.5 then
                self.spawn_pattern_state.wave_active = true
                self.spawn_pattern_state.wave_timer = 0
            end
        end
    elseif self.params.obstacle_spawn_pattern == "clusters" then
        if self.spawn_pattern_state.cluster_pending > 0 then
            self:spawnSingleObject()
            self.spawn_pattern_state.cluster_pending = self.spawn_pattern_state.cluster_pending - 1
        else
            self.spawn_pattern_state.cluster_pending = math.random(2, 4)
            self:spawnSingleObject()
        end
    elseif self.params.obstacle_spawn_pattern == "spiral" then
        local sx, sy = self:pickSpawnPointAtAngle(self.spawn_pattern_state.spiral_angle)
        local tx, ty = self:pickTargetPointOnRing()
        local angle = math.atan2(ty - sy, tx - sx)
        angle = self:ensureInboundAngle(sx, sy, angle)
        self:createObject(sx, sy, angle, false)
        self.spawn_pattern_state.spiral_angle = self.spawn_pattern_state.spiral_angle + math.rad(30)
    elseif self.params.obstacle_spawn_pattern == "pulse_with_arena" then
        if self.arena_controller then
            local sx, sy, angle = self:pickPointOnSafeZoneBoundary()
            self:createObject(sx, sy, angle, false)
        else
            self:spawnSingleObject()
        end
    else
        self:spawnSingleObject()
    end
end

function DodgeGame:spawnSingleObject()
    if self:hasVariantEnemies() and math.random() < 0.7 then
        self:spawnVariantEnemy(false)
    elseif self.warning_enabled and math.random() < ((self.runtimeCfg.spawn and self.runtimeCfg.spawn.warning_chance) or 0.7) then
        self:spawnWarning()
    else
        if not self.params.disable_obstacle_fallback then
            self:spawnVariantEnemy(false, "obstacle")
        else
            self:spawnVariantEnemy(false)
        end
    end
end

function DodgeGame:hasVariantEnemies()
    return self.enemy_composition and next(self.enemy_composition) ~= nil
end

function DodgeGame:spawnVariantEnemy(warned_status, force_type)
    local chosen_type = force_type

    if not chosen_type then
        if not self:hasVariantEnemies() then
            chosen_type = "obstacle"
        else
            local enemy_types = {}
            local total_weight = 0
            for enemy_type, multiplier in pairs(self.enemy_composition) do
                table.insert(enemy_types, {type = enemy_type, weight = multiplier})
                total_weight = total_weight + multiplier
            end

            local r = math.random() * total_weight
            chosen_type = enemy_types[1].type
            for _, entry in ipairs(enemy_types) do
                r = r - entry.weight
                if r <= 0 then
                    chosen_type = entry.type
                    break
                end
            end
        end
    end

    local sx, sy = self:pickSpawnPoint()
    local tx, ty = self:pickTargetPointOnRing()
    local angle = math.atan2(ty - sy, tx - sx)
    angle = self:ensureInboundAngle(sx, sy, angle)

    local enemy_def = self.params.enemy_types[chosen_type]
    if enemy_def then
        self:createEnemyObject(sx, sy, angle, warned_status, enemy_def)
    else
        print("[DodgeGame] ERROR: Unknown enemy type: " .. tostring(chosen_type))
        self:createObject(sx, sy, angle, warned_status, 'linear')
    end
end

function DodgeGame:createEnemyObject(spawn_x, spawn_y, angle, was_warned, enemy_def)
    local base_type = enemy_def.type or 'linear'
    local speed_mult = enemy_def.speed_multiplier or 1.0

    local size_range = nil

    if self.variant and self.variant.enemy_sizes and self.variant.enemy_sizes[enemy_def.name] then
        size_range = self.variant.enemy_sizes[enemy_def.name]
    end

    if not size_range and self.variant and self.variant.size_range then
        size_range = self.variant.size_range
    end

    if not size_range and self.runtimeCfg.objects and self.runtimeCfg.objects.enemy_sizes then
        size_range = self.runtimeCfg.objects.enemy_sizes[enemy_def.name]
    end

    if not size_range and self.runtimeCfg.objects then
        size_range = self.runtimeCfg.objects.size_range or {(self.params.object_radius or 15), (self.params.object_radius or 15)}
    end

    size_range = size_range or {(self.params.object_radius or 15), (self.params.object_radius or 15)}

    local final_radius = size_range[1] + math.random() * (size_range[2] - size_range[1])

    local speed_range = nil

    if self.variant and self.variant.enemy_speeds and self.variant.enemy_speeds[enemy_def.name] then
        speed_range = self.variant.enemy_speeds[enemy_def.name]
    end

    if not speed_range and self.variant and self.variant.speed_range then
        speed_range = self.variant.speed_range
    end

    if not speed_range and self.runtimeCfg.objects and self.runtimeCfg.objects.enemy_speeds then
        speed_range = self.runtimeCfg.objects.enemy_speeds[enemy_def.name]
    end

    if not speed_range and self.runtimeCfg.objects then
        speed_range = self.runtimeCfg.objects.speed_range or {self.object_speed, self.object_speed}
    end

    speed_range = speed_range or {self.object_speed, self.object_speed}

    local base_speed = speed_range[1] + math.random() * (speed_range[2] - speed_range[1])
    local final_speed = base_speed * speed_mult

    local sprite_settings = nil
    if self.variant and self.variant.enemy_sprite_settings and self.variant.enemy_sprite_settings[enemy_def.name] then
        sprite_settings = self.variant.enemy_sprite_settings[enemy_def.name]
    elseif self.runtimeCfg.objects and self.runtimeCfg.objects.enemy_sprite_settings then
        sprite_settings = self.runtimeCfg.objects.enemy_sprite_settings[enemy_def.name]
    end

    local sprite_rotation = (sprite_settings and sprite_settings.rotation) or 0
    local sprite_direction = (sprite_settings and sprite_settings.direction) or "movement_based"

    -- Map entity type to movement pattern for EntityController behaviors
    local movement_pattern_map = {
        zigzag = 'zigzag', sine = 'wave',
        seeker = 'tracking', chaser = 'tracking',
        teleporter = 'teleporter', bouncer = 'bounce'
    }

    local custom_params = {
        warned = was_warned,
        radius = final_radius,
        type = base_type,
        enemy_type = enemy_def.name,
        speed = final_speed,
        is_enemy = true,
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

    if base_type == 'zigzag' or base_type == 'sine' then
        local zig = (self.runtimeCfg.objects and self.runtimeCfg.objects.zigzag) or { wave_speed_min = 6, wave_speed_range = 4, wave_amp = 30 }
        custom_params.wave_speed = (zig.wave_speed_min or 6) + math.random() * (zig.wave_speed_range or 4)
        custom_params.wave_amp = zig.wave_amp or 30
        custom_params.wave_phase = math.random()*math.pi*2
    elseif base_type == 'shooter' then
        local shoot_interval = 2.0
        if self.variant and self.variant.shooter and self.variant.shooter.shoot_interval then
            shoot_interval = self.variant.shooter.shoot_interval
        elseif self.runtimeCfg.objects and self.runtimeCfg.objects.shooter and self.runtimeCfg.objects.shooter.shoot_interval then
            shoot_interval = self.runtimeCfg.objects.shooter.shoot_interval
        end
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

    -- Initialize trail positions if trails are enabled
    if self.params.obstacle_trails and self.params.obstacle_trails > 0 then
        custom_params.trail_positions = {}
    end

    local obj = self.entity_controller:spawn("obstacle", spawn_x, spawn_y, custom_params)

    if obj and (not self._last_enemy_debug or (love.timer.getTime() - self._last_enemy_debug) > 1.0) then
        print(string.format("[DodgeGame] Created enemy: type=%s, enemy_type=%s, is_enemy=%s",
            obj.type or "nil", obj.enemy_type or "nil", tostring(obj.is_enemy)))
        self._last_enemy_debug = love.timer.getTime()
    end

    return obj
end

-- Spawn a warning entity that becomes an obstacle after delay (uses delayed_spawn behavior)
function DodgeGame:spawnWarning()
    local sx, sy = self:pickSpawnPoint()
    local tx, ty = self:pickTargetPointOnRing()
    local angle = math.atan2(ty - sy, tx - sx)
    angle = self:ensureInboundAngle(sx, sy, angle)
    local warning_duration = (self.params.warning_time or 0.5) / self.difficulty_modifiers.speed

    -- Spawn warning entity with delayed_spawn
    self.entity_controller:spawn("warning", sx, sy, {
        type = 'warning',
        warning_type = 'radial',
        spawn_angle = angle,
        skip_offscreen_removal = true,
        delayed_spawn = {
            timer = warning_duration,
            spawn_type = "obstacle"
        }
    })
end

-- Called by delayed_spawn when warning timer expires
function DodgeGame:spawnFromWarning(warning_entity)
    local sx, sy = warning_entity.x, warning_entity.y
    local angle = warning_entity.spawn_angle or 0

    if self:hasVariantEnemies() then
        local enemy_types = {}
        local total_weight = 0
        for enemy_type, multiplier in pairs(self.enemy_composition) do
            table.insert(enemy_types, {type = enemy_type, weight = multiplier})
            total_weight = total_weight + multiplier
        end
        local r = math.random() * total_weight
        local chosen_type = enemy_types[1].type
        for _, entry in ipairs(enemy_types) do
            r = r - entry.weight
            if r <= 0 then
                chosen_type = entry.type
                break
            end
        end
        local enemy_def = self.params.enemy_types[chosen_type]
        if enemy_def then
            self:createEnemyObject(sx, sy, angle, true, enemy_def)
            return
        end
    end
    local enemy_def = self.params.enemy_types.obstacle
    if enemy_def then
        self:createEnemyObject(sx, sy, angle, true, enemy_def)
    else
        self:createObject(sx, sy, angle, true)
    end
end

function DodgeGame:createRandomObject(warned_status)
    local sx, sy = self:pickSpawnPoint()
    local tx, ty = self:pickTargetPointOnRing()
    local angle = math.atan2(ty - sy, tx - sx)
    angle = self:ensureInboundAngle(sx, sy, angle)
    local t = self.time_elapsed
    local weights = (self.runtimeCfg.objects and self.runtimeCfg.objects.weights) or {
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
    local base_radius = (self.params.object_radius or 15)
    if self.params.obstacle_size_variance > 0 then
        local size_mult = 0.5 + math.random() * self.params.obstacle_size_variance
        base_radius = (self.params.object_radius or 15) * size_mult
    end

    local type_mult = ((self.runtimeCfg.objects and self.runtimeCfg.objects.type_speed_multipliers and self.runtimeCfg.objects.type_speed_multipliers[kind or 'linear']) or (kind == 'seeker' and 0.9 or kind == 'splitter' and 0.8 or kind == 'zigzag' and 1.1 or kind == 'sine' and 1.0 or 1.0))
    local base_speed = self.object_speed * type_mult

    if self.params.obstacle_speed_variance > 0 then
        local speed_var = 1.0 + (math.random() - 0.5) * 2 * self.params.obstacle_speed_variance
        base_speed = base_speed * speed_var
    end

    local movement_pattern_map = {
        zigzag = 'zigzag', sine = 'wave',
        seeker = 'tracking', chaser = 'tracking',
        teleporter = 'teleporter', bouncer = 'bounce'
    }

    local custom_params = {
        warned = was_warned,
        radius = base_radius,
        type = kind or 'linear',
        speed = base_speed,
        tracking_strength = self.params.obstacle_tracking or 0,
        angle = angle or 0,
        direction = angle or 0,
        movement_pattern = movement_pattern_map[kind or 'linear'] or 'straight',
        vx = math.cos(angle or 0) * base_speed,
        vy = math.sin(angle or 0) * base_speed
    }

    if self.params.obstacle_trails > 0 then
        custom_params.trail_positions = {}
    end

    if (kind or 'linear') == 'zigzag' or (kind or 'linear') == 'sine' then
        local zig = (self.runtimeCfg.objects and self.runtimeCfg.objects.zigzag) or { wave_speed_min = 6, wave_speed_range = 4, wave_amp = 30 }
        custom_params.wave_speed = (zig.wave_speed_min or 6) + math.random() * (zig.wave_speed_range or 4)
        custom_params.wave_amp = zig.wave_amp or 30
        custom_params.wave_phase = math.random()*math.pi*2
    end

    return self.entity_controller:spawn("obstacle", spawn_x, spawn_y, custom_params)
end

function DodgeGame:spawnShards(parent, count)
    local def = self.params.enemy_types.splitter or {}
    local n = count or def.shards_count or 3
    local spread = math.rad(def.spread_deg or 35)
    local shard_speed_factor = def.shard_speed_factor or 0.36
    local shard_radius_factor = def.shard_radius_factor or 0.6
    local shard_radius_min = def.shard_radius_min or 6

    for i = 1, n do
        local a = parent.angle + (math.random() * 2 - 1) * spread
        local shard_speed = self.object_speed * shard_speed_factor
        local shard_radius = math.max(shard_radius_min, math.floor(parent.radius * shard_radius_factor))

        self.entity_controller:spawn("obstacle", parent.x, parent.y, {
            radius = shard_radius,
            type = 'linear',
            speed = shard_speed,
            warned = false,
            angle = a,
            direction = a,
            movement_pattern = 'straight',
            vx = math.cos(a) * shard_speed,
            vy = math.sin(a) * shard_speed
        })
    end
end

--------------------------------------------------------------------------------
-- SPAWN POSITION HELPERS
--------------------------------------------------------------------------------

function DodgeGame:pickSpawnPoint()
    local inset = ((self.runtimeCfg.arena and self.runtimeCfg.arena.spawn_inset) or 2)
    local r = (self.params.object_radius or 15)
    local edge = math.random(4)
    if edge == 1 then return -r + inset, math.random(0, self.game_height)
    elseif edge == 2 then return self.game_width + r - inset, math.random(0, self.game_height)
    elseif edge == 3 then return math.random(0, self.game_width), -r + inset
    else return math.random(0, self.game_width), self.game_height + r - inset end
end

function DodgeGame:pickSpawnPointAtAngle(angle)
    local inset = ((self.runtimeCfg.arena and self.runtimeCfg.arena.spawn_inset) or 2)
    local r = (self.params.object_radius or 15)
    local center_x = self.game_width / 2
    local center_y = self.game_height / 2
    local dist = math.max(self.game_width, self.game_height)
    local sx = center_x + math.cos(angle) * dist
    local sy = center_y + math.sin(angle) * dist
    if sx < 0 then sx = -r + inset end
    if sx > self.game_width then sx = self.game_width + r - inset end
    if sy < 0 then sy = -r + inset end
    if sy > self.game_height then sy = self.game_height + r - inset end
    return sx, sy
end

function DodgeGame:pickTargetPointOnRing()
    local ac = self.arena_controller
    local scale = (self.params.target_ring_min_scale or 1.2) + math.random() * ((self.params.target_ring_max_scale or 1.5) - (self.params.target_ring_min_scale or 1.2))
    local r = (ac and ac:getEffectiveRadius() or math.min(self.game_width, self.game_height) * 0.4) * scale
    local a = math.random() * math.pi * 2
    local cx = ac and ac.x or self.game_width/2
    local cy = ac and ac.y or self.game_height/2
    local shape = ac and ac.shape or "circle"

    if shape == "circle" then
        return cx + math.cos(a) * r, cy + math.sin(a) * r
    elseif shape == "square" then
        local side = math.random(4)
        local t = math.random() * 2 - 1
        if side == 1 then return cx + r, cy + t * r
        elseif side == 2 then return cx - r, cy + t * r
        elseif side == 3 then return cx + t * r, cy + r
        else return cx + t * r, cy - r end
    elseif shape == "hex" then
        local hex_width = r * 0.866
        local edge = math.random(6)
        local t = math.random()
        if edge == 1 then
            return cx + hex_width * t, cy - r + r * 0.5 * t
        elseif edge == 2 then
            return cx + hex_width, cy - r * 0.5 + r * t
        elseif edge == 3 then
            return cx + hex_width * (1-t), cy + r * 0.5 + r * 0.5 * (1-t)
        elseif edge == 4 then
            return cx - hex_width * t, cy + r - r * 0.5 * t
        elseif edge == 5 then
            return cx - hex_width, cy + r * 0.5 - r * t
        else
            return cx - hex_width * (1-t), cy - r * 0.5 - r * 0.5 * (1-t)
        end
    else
        return cx + math.cos(a) * r, cy + math.sin(a) * r
    end
end

function DodgeGame:pickPointOnSafeZoneBoundary()
    local ac = self.arena_controller
    local r = ac:getEffectiveRadius()
    local cx, cy = ac.x, ac.y
    local shape = ac.shape or "circle"
    local spawn_angle = math.random() * math.pi * 2

    if shape == "circle" then
        local sx = cx + math.cos(spawn_angle) * r
        local sy = cy + math.sin(spawn_angle) * r
        return sx, sy, spawn_angle
    elseif shape == "square" then
        local side = math.random(4)
        local t = math.random() * 2 - 1
        local sx, sy, angle
        if side == 1 then sx, sy = cx + r, cy + t * r; angle = 0
        elseif side == 2 then sx, sy = cx - r, cy + t * r; angle = math.pi
        elseif side == 3 then sx, sy = cx + t * r, cy + r; angle = math.pi / 2
        else sx, sy = cx + t * r, cy - r; angle = -math.pi / 2 end
        return sx, sy, angle
    elseif shape == "hex" then
        local hex_width = r * 0.866
        local edge = math.random(6)
        local t = math.random()
        local sx, sy, angle
        if edge == 1 then
            sx, sy = cx + hex_width * t, cy - r + r * 0.5 * t
            angle = math.atan2(0.5, 0.866)
        elseif edge == 2 then
            sx, sy = cx + hex_width, cy - r * 0.5 + r * t
            angle = 0
        elseif edge == 3 then
            sx, sy = cx + hex_width * (1-t), cy + r * 0.5 + r * 0.5 * (1-t)
            angle = math.atan2(0.5, -0.866)
        elseif edge == 4 then
            sx, sy = cx - hex_width * t, cy + r - r * 0.5 * t
            angle = math.atan2(-0.5, -0.866)
        elseif edge == 5 then
            sx, sy = cx - hex_width, cy + r * 0.5 - r * t
            angle = math.pi
        else
            sx, sy = cx - hex_width * (1-t), cy - r * 0.5 - r * 0.5 * (1-t)
            angle = math.atan2(-0.5, 0.866)
        end
        return sx, sy, angle
    else
        local sx = cx + math.cos(spawn_angle) * r
        local sy = cy + math.sin(spawn_angle) * r
        return sx, sy, spawn_angle
    end
end

function DodgeGame:ensureInboundAngle(sx, sy, angle)
    local vx, vy = math.cos(angle), math.sin(angle)
    if sx <= 0 then
        if vx <= 0 then angle = math.atan2(vy, math.abs(vx)) end
    elseif sx >= self.game_width then
        if vx >= 0 then angle = math.atan2(vy, -math.abs(vx)) end
    elseif sy <= 0 then
        if vy <= 0 then angle = math.atan2(math.abs(vy), vx) end
    elseif sy >= self.game_height then
        if vy >= 0 then angle = math.atan2(-math.abs(vy), vx) end
    end
    return angle
end

--------------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------------

function DodgeGame:keypressed(key)
    DodgeGame.super.keypressed(self, key)
    return false
end

return DodgeGame
