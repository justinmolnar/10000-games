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
local SchemaLoader = require('src.utils.game_components.schema_loader')
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
            bounce_damping = p.bounce_damping,
            jump_distance = p.jump_distance, jump_cooldown = p.jump_cooldown,
            jump_speed = p.jump_speed, time_elapsed = 0
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

    -- Movement controller (primitives-based, game handles input mapping)
    local MovementController = self.di.components.MovementController
    self.movement_controller = MovementController:new({
        speed = p.movement_speed,
        accel_friction = p.accel_friction, decel_friction = p.decel_friction,
        rotation_speed = p.rotation_speed, bounce_damping = p.bounce_damping,
        thrust_acceleration = (self.runtimeCfg.player and self.runtimeCfg.player.thrust_acceleration) or 600,
        jump_distance = p.jump_distance, jump_cooldown = p.jump_cooldown, jump_speed = p.jump_speed
    })

    -- Arena controller (safe zone) — pure physics, game controls movement via setAcceleration
    local level_scale = 1 + ((self.runtimeCfg.drift and self.runtimeCfg.drift.level_scale_add_per_level) or 0.15) * math.max(0, (self.difficulty_level or 1) - 1)
    local arena_speed = ((self.runtimeCfg.drift and self.runtimeCfg.drift.base_speed) or 45) * level_scale * p.area_movement_speed

    -- Get shape definition: custom vertices or translate shape name to sides
    local arena_vertices = self.variant and self.variant.area_vertices
    local sides, shape_rotation = self:getShapeSides(p.area_shape or "circle")

    local ArenaController = self.di.components.ArenaController
    self.arena_controller = ArenaController:new({
        safe_zone = true, x = self.game_width/2, y = self.game_height/2,
        vertices = arena_vertices,  -- nil if not provided, AC will use sides
        sides = sides, shape_rotation = shape_rotation,
        sides_cycle = {32, 4, 6},  -- circle, square, hex for shape_shifting
        morph_type = p.area_morph_type or "shrink", morph_speed = p.area_morph_speed or 1.0,
        -- Raw params: AC computes radius, min_radius, shrink_speed internally
        area_size = p.area_size, initial_radius_fraction = p.initial_safe_radius_fraction or 0.48,
        min_radius_fraction = p.min_safe_radius_fraction or 0.35,
        shrink_seconds = p.safe_zone_shrink_sec or 45, complexity_modifier = self.difficulty_modifiers.complexity,
        -- Movement: pure physics, friction only
        friction = p.area_friction or 0.95,
        container_width = self.game_width, container_height = self.game_height, bounds_padding = 0
    })

    -- Arena movement behavior state (game-side, not component)
    self.arena_movement = {
        type = p.area_movement_type or "random",
        speed = arena_speed,
        direction_timer = 0,
        direction_change_interval = 2.0,
        target_vx = 0,
        target_vy = 0
    }

    self.leaving_area_ends_game = p.leaving_area_ends_game

    -- Player trail
    self.player_trail = PhysicsUtils.createTrailSystem({
        max_length = p.player_trail_length, track_distance = false,
        color = {0.5, 0.7, 1.0, 0.3}, line_width = 3, angle_offset = 0
    })

    -- Alias for createEntityControllerFromSchema (expects entity_types)
    self.params.entity_types = self.params.enemy_types

    -- Entity controller from schema with pattern-based spawning
    local pattern = p.obstacle_spawn_pattern or "random"
    local spawn_func = function(ec, sx, sy, angle)
        game:spawnNext(sx, sy, angle)
    end

    local margin = (p.object_radius or 15) - ((self.runtimeCfg.arena and self.runtimeCfg.arena.spawn_inset) or 2)
    self.spawn_bounds = {min_x = 0, max_x = self.game_width, min_y = 0, max_y = self.game_height}
    local position_pattern = "random_edge"
    local position_config = {margin = margin, bounds = self.spawn_bounds}
    if pattern == "spiral" then
        position_pattern = "spiral"
        position_config.angle_step = math.rad(30)
    elseif pattern == "pulse_with_arena" then
        position_pattern = "boundary"
        position_config.get_boundary_point = function() return game.arena_controller:getRandomBoundaryPoint() end
    elseif pattern == "clusters" then
        position_pattern = "clusters"
        position_config.cluster_min = 2
        position_config.cluster_max = 4
    end

    local spawn_config
    if pattern == "waves" then
        spawn_config = {mode = "burst", burst_count = 6, burst_interval = 0.15, burst_pause = 2.5,
            position_pattern = position_pattern, position_config = position_config, spawn_func = spawn_func}
    else
        spawn_config = {mode = "continuous", rate = 1.0, max_concurrent = 500,
            position_pattern = position_pattern, position_config = position_config, spawn_func = spawn_func}
    end
    self:createEntityControllerFromSchema({}, {spawning = spawn_config, pooling = true, max_entities = 500})

    -- Global on_remove callback for dodge counting
    self.entity_controller.on_remove = function(entity, reason)
        if reason == "offscreen" and (entity.entered_play or entity.was_dodged) then
            game:onObjectDodged()
        end
    end

    -- Spawn hole entities
    if p.holes_count > 0 and p.holes_type ~= "none" then
        local ac = self.arena_controller
        for _ = 1, p.holes_count do
            if p.holes_type == "circle" then
                local angle = math.random() * math.pi * 2
                local hx, hy = ac:getPointOnShapeBoundary(angle)
                self.entity_controller:spawn("hole", hx, hy, {boundary_angle = angle})
            else
                self.entity_controller:spawn("hole", math.random(8, self.game_width - 8), math.random(8, self.game_height - 8))
            end
        end
    end

    -- Configure entity behaviors for updateBehaviors
    self.entity_behaviors_config = {
        boundary_anchor = (p.holes_count > 0 and p.holes_type == "circle") and {
            get_boundary_point = function(angle)
                return game.arena_controller:getPointOnShapeBoundary(angle, game.arena_controller:getEffectiveRadius())
            end
        } or nil,
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
                if entity.type_name == "hole" then
                    game.metrics.collisions = game.metrics.collisions + 1
                    game.current_combo = 0
                    game:takeDamage(1, "hit")
                    if not game.health_system:isAlive() then
                        game:playSound("death", 1.0)
                        game:onComplete()
                    end
                    return false  -- don't remove hole
                end
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
                            use_direction = true, type = 'linear'
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

    -- Pre-resolve per-type params (size, speed, sprite settings) via SchemaLoader.resolveChain
    local sources = {self.variant, self.runtimeCfg.objects}
    local default_radius = p.object_radius or 15
    for type_name, def in pairs(p.enemy_types) do
        if not def.resolved then
            def.resolved_size_range = def.size_range
                or SchemaLoader.resolveChain(def.name or type_name, "size_range", "enemy_sizes", sources)
                or {default_radius, default_radius}
            def.resolved_speed_range = def.speed_range
                or SchemaLoader.resolveChain(def.name or type_name, "speed_range", "enemy_speeds", sources)
                or {self.object_speed, self.object_speed}
            def.resolved_sprite_settings = def.sprite_settings
                or SchemaLoader.resolveChain(def.name or type_name, "sprite_settings", "enemy_sprite_settings", sources)
            def.resolved = true
        end
    end

    -- Metrics
    self.metrics.objects_dodged = 0
    self.metrics.collisions = 0
    self.metrics.combo = 0
    self.current_combo = 0

    -- Wind state (uses PhysicsUtils.updateDirectionalForce)
    local is_rotating = p.wind_type == "changing_steady" or p.wind_type == "changing_turbulent"
    local is_turbulent = p.wind_type == "turbulent" or p.wind_type == "changing_turbulent"
    self.wind_state = {
        angle = type(p.wind_direction) == "number" and math.rad(p.wind_direction) or math.random() * math.pi * 2,
        strength = p.wind_strength or 0,
        is_rotating = is_rotating,
        is_turbulent = is_turbulent,
        timer = 0,
        change_interval = 3.0,
        change_amount = math.rad(30),
        turbulence_range = math.pi * 0.5
    }

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
    if self.spawn_bounds then
        self.spawn_bounds.max_x = width
        self.spawn_bounds.max_y = height
    end
end

--------------------------------------------------------------------------------
-- MAIN GAME LOOP
--------------------------------------------------------------------------------

function DodgeGame:updateGameLogic(dt)
    if self.game_over or self.completed then return end

    -- Lethal zone check
    if self.leaving_area_ends_game and not self.arena_controller:isInside(self.player.x, self.player.y, self.player.radius) then
        self.game_over = true; self:onComplete(); return
    end

    -- Spawn rate acceleration
    if self.entity_controller.spawning.mode ~= "burst" then
        local accel_cfg = (self.runtimeCfg.spawn and self.runtimeCfg.spawn.accel) or {}
        local accel = 1 + math.min(accel_cfg.max or 2.0, self.time_elapsed / (accel_cfg.time or 60))
        self.entity_controller.spawn_rate = self.spawn_rate / accel
    end

    -- Systems
    self.entity_controller:update(dt)
    self.entity_controller:updateBehaviors(dt, self.entity_behaviors_config)
    self.projectile_system:update(dt, {x_min = 0, x_max = self.game_width, y_min = 0, y_max = self.game_height})
    if self:checkProjectileCollisions() then return end

    -- Calculate arena movement acceleration (game-side behavior)
    self:updateArenaMovement(dt)
    self.arena_controller:update(dt)
    self.health_system:update(dt)
    self.visual_effects:update(dt)

    -- View state
    self.lives = self.health_system.lives
    self.objects = self.entity_controller:getEntities()
    for _, proj in ipairs(self.projectile_system:getProjectiles()) do
        table.insert(self.objects, proj)
    end
    if self.player_trail then self.player_trail:updateFromEntity(self.player) end

    -- Player
    self:updatePlayer(dt)
end

function DodgeGame:updatePlayer(dt)
    local input = self:buildInput()
    local bounds = {x = 0, y = 0, width = self.game_width, height = self.game_height, wrap_x = false, wrap_y = false}
    local p = self.params
    local mc = self.movement_controller
    local player = self.player

    player.time_elapsed = self.time_elapsed
    if player.rotation then player.angle = player.rotation end

    -- Build input direction
    local dx, dy = 0, 0
    if input.left then dx = dx - 1 end
    if input.right then dx = dx + 1 end
    if input.up then dy = dy - 1 end
    if input.down then dy = dy + 1 end

    -- Apply movement behaviors based on schema flags
    local dominated_by_jump = p.use_jump and mc:isJumping("player")

    if p.use_jump then
        if mc:isJumping("player") then
            mc:updateJump(player, "player", dt, bounds, player.time_elapsed)
        elseif (dx ~= 0 or dy ~= 0) and mc:canJump("player", player.time_elapsed) then
            mc:startJump(player, "player", dx, dy, player.time_elapsed, bounds)
        end
    end

    if not dominated_by_jump then
        if p.use_rotation then
            if input.left then mc:applyRotation(player, -1, nil, dt) end
            if input.right then mc:applyRotation(player, 1, nil, dt) end
        end

        if p.use_thrust and input.up then
            mc:applyThrust(player, player.angle, nil, dt)
            mc:applyFriction(player, p.accel_friction, dt)
        end

        if p.use_reverse_thrust and input.down then
            mc:applyThrust(player, player.angle + math.pi, nil, dt)
            mc:applyFriction(player, p.accel_friction, dt)
        end

        if p.use_brake and input.down then
            mc:applyFriction(player, 0.92, dt)
        end

        if p.use_directional and (dx ~= 0 or dy ~= 0) then
            if p.use_velocity then
                mc:applyDirectionalVelocity(player, dx, dy, nil, dt)
                mc:applyFriction(player, p.accel_friction, dt)
            else
                mc:applyDirectionalMove(player, dx, dy, nil, dt)
            end
            mc:rotateTowardsMovement(player, dx, dy, dt)
        end

        -- Apply decel friction when not actively moving
        local is_moving = (p.use_thrust and input.up) or (p.use_reverse_thrust and input.down) or
                          (p.use_directional and (dx ~= 0 or dy ~= 0))
        if not is_moving and p.decel_friction < 1.0 then
            mc:applyFriction(player, p.decel_friction, dt)
        end
    end

    if p.use_velocity then mc:applyVelocity(player, dt) end
    mc:applyBounds(player, bounds)
    if p.use_bounce then mc:applyBounce(player, bounds) end

    player.rotation = player.angle

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

-- Calculate arena movement acceleration based on movement type
function DodgeGame:updateArenaMovement(dt)
    local am = self.arena_movement
    if not am or am.type == "none" then
        self.arena_controller:setAcceleration(0, 0)
        return
    end

    local ac = self.arena_controller
    local ax, ay = 0, 0

    if am.type == "random" or am.type == "drift" then
        -- Random drift: random acceleration each frame
        ax = (math.random() - 0.5) * am.speed
        ay = (math.random() - 0.5) * am.speed

    elseif am.type == "cardinal" then
        -- Cardinal: pick a direction periodically, interpolate velocity toward target
        am.direction_timer = am.direction_timer + dt
        if am.direction_timer >= am.direction_change_interval then
            am.direction_timer = 0
            local dir = math.random(1, 4)
            if dir == 1 then am.target_vx, am.target_vy = am.speed, 0
            elseif dir == 2 then am.target_vx, am.target_vy = -am.speed, 0
            elseif dir == 3 then am.target_vx, am.target_vy = 0, am.speed
            else am.target_vx, am.target_vy = 0, -am.speed end
        end
        -- Acceleration toward target velocity
        ax = (am.target_vx - ac.vx) * 2
        ay = (am.target_vy - ac.vy) * 2
    end

    ac:setAcceleration(ax, ay)
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

    -- Pre-resolved params from setupEntities
    local size_range = enemy_def.resolved_size_range or {(self.params.object_radius or 15), (self.params.object_radius or 15)}
    local final_radius = size_range[1] + math.random() * (size_range[2] - size_range[1])

    local speed_range = enemy_def.resolved_speed_range or {self.object_speed, self.object_speed}
    local base_speed = speed_range[1] + math.random() * (speed_range[2] - speed_range[1])
    local final_speed = base_speed * speed_mult

    local sprite_settings = enemy_def.resolved_sprite_settings
    local sprite_rotation = (sprite_settings and sprite_settings.rotation) or 0
    local sprite_direction = (sprite_settings and sprite_settings.direction) or "movement_based"

    -- Base movement params
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
        turn_rate = math.rad(self.params.seeker_turn_rate or 54)
    }

    -- Movement flags based on enemy type (from schema enemy_def or defaults)
    if base_type == 'seeker' or base_type == 'chaser' then
        custom_params.use_steering = true
    elseif base_type == 'bouncer' then
        -- Bouncers use velocity-based movement
        custom_params.use_velocity = true
        custom_params.use_bounce = true
        custom_params.vx = math.cos(angle or 0) * final_speed
        custom_params.vy = math.sin(angle or 0) * final_speed
        custom_params.bounce_count = 0
        custom_params.has_entered = false
    elseif base_type == 'zigzag' or base_type == 'sine' then
        custom_params.use_direction = true
        local zig_cfg = (self.runtimeCfg.objects and self.runtimeCfg.objects.zigzag) or {}
        local wave_speed_min = enemy_def.wave_speed_min or zig_cfg.wave_speed_min or 6
        local wave_speed_range = enemy_def.wave_speed_range or zig_cfg.wave_speed_range or 4
        custom_params.wave_speed = wave_speed_min + math.random() * wave_speed_range
        custom_params.wave_amp = enemy_def.wave_amp or zig_cfg.wave_amp or 30
        custom_params.sine_amplitude = custom_params.wave_amp
        custom_params.wave_phase = math.random() * math.pi * 2
    elseif base_type == 'shooter' then
        custom_params.use_direction = true
        local shoot_interval = enemy_def.shoot_interval
            or (self.variant and self.variant.shooter and self.variant.shooter.shoot_interval)
            or (self.runtimeCfg.objects and self.runtimeCfg.objects.shooter and self.runtimeCfg.objects.shooter.shoot_interval)
            or 2.0
        custom_params.shoot_timer = shoot_interval
        custom_params.shoot_interval = shoot_interval
    elseif base_type == 'teleporter' then
        custom_params.use_direction = true
        custom_params.teleport_timer = enemy_def.teleport_interval or 3.0
        custom_params.teleport_interval = enemy_def.teleport_interval or 3.0
        custom_params.teleport_range = enemy_def.teleport_range or 100
    else
        -- Default: basic obstacle, splitter, etc. - just move in direction
        custom_params.use_direction = true
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

-- Translate schema shape name to polygon sides and rotation
function DodgeGame:getShapeSides(shape_name)
    if shape_name == "square" then
        return 4, math.pi / 4  -- 4 sides, rotated 45° for axis-aligned square
    elseif shape_name == "hex" or shape_name == "hexagon" then
        return 6, -math.pi / 2  -- 6 sides, rotated to pointy-top
    elseif shape_name == "triangle" then
        return 3, -math.pi / 2  -- 3 sides, point at top
    elseif type(shape_name) == "number" then
        return shape_name, 0  -- Direct side count
    else
        return 32, 0  -- Default: circle (32-gon)
    end
end


return DodgeGame
