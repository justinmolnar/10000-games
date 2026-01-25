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
            jump_dir_x = 0, jump_dir_y = 0, time_elapsed = 0,
            shield_charges = p.shield, shield_max = p.shield,
            shield_recharge_timer = p.shield_recharge_time,
            shield_recharge_time = p.shield_recharge_time
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
    self:createComponentsFromSchema()
    self.fog_controller.enabled = p.fog_of_war_origin ~= "none" and p.fog_of_war_radius < 9999
    self.lives = self.health_system.lives

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

    local holes = {}
    if p.holes_count > 0 and p.holes_type ~= "none" then
        for i = 1, p.holes_count do
            local hole = {radius = 8}
            if p.holes_type == "circle" then
                local angle = math.random() * math.pi * 2
                hole.angle = angle
                hole.x, hole.y = self:getPointOnShapeBoundary(self.game_width/2, self.game_height/2, initial_radius, p.area_shape, angle)
                hole.on_boundary = true
            else
                hole.x = math.random(hole.radius, self.game_width - hole.radius)
                hole.y = math.random(hole.radius, self.game_height - hole.radius)
                hole.on_boundary = false
            end
            table.insert(holes, hole)
        end
    end

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
        vx = target_vx, vy = target_vy, target_vx = target_vx, target_vy = target_vy,
        holes = holes
    })
    self.safe_zone = self.arena_controller:getState()
    self.holes = self.arena_controller.holes
    self.leaving_area_ends_game = p.leaving_area_ends_game

    -- Player trail
    self.player_trail = PhysicsUtils.createTrailSystem({
        max_length = p.player_trail_length, color = {0.5, 0.7, 1.0, 0.3}, line_width = 3
    })

    -- Alias for createEntityControllerFromSchema (expects entity_types)
    self.params.entity_types = self.params.enemy_types

    -- Entity controller from schema
    self:createEntityControllerFromSchema({}, {spawning = {mode = "manual"}, pooling = true, max_entities = 500})

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
    self.warnings = {}

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

    -- Wind state
    self.wind_timer = 0
    self.wind_current_angle = type(p.wind_direction) == "number" and math.rad(p.wind_direction) or math.random() * math.pi * 2

    -- Spawn pattern state
    self.spawn_pattern_state = {wave_timer = 0, wave_active = false, spiral_angle = 0, cluster_pending = 0}

    -- Score trackers
    self.avg_speed_tracker = {sum = 0, count = 0}
    self.center_time_tracker = {total_weighted = 0, total_time = 0}
    self.edge_time_tracker = {total_weighted = 0, total_time = 0}
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
end

--------------------------------------------------------------------------------
-- MAIN GAME LOOP
--------------------------------------------------------------------------------

function DodgeGame:updateGameLogic(dt)
    self:checkGameOver()

    if self.game_over then
        return
    end

    self.entity_controller:update(dt)

    local game_bounds = {
        x_min = 0,
        x_max = self.game_width,
        y_min = 0,
        y_max = self.game_height
    }
    self.projectile_system:update(dt, game_bounds)

    self.objects = self.entity_controller:getEntities()
    local projectiles = self.projectile_system:getProjectiles()
    for _, proj in ipairs(projectiles) do
        table.insert(self.objects, proj)
    end

    self.arena_controller:update(dt)
    self:syncSafeZoneFromArena()
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
        self.view:draw()
    else
        love.graphics.setColor(1,0,0)
        love.graphics.print("Error: DodgeView not loaded or has no draw function.", 10, 100)
    end
end

--------------------------------------------------------------------------------
-- PLAYER MOVEMENT & PHYSICS
--------------------------------------------------------------------------------

function DodgeGame:updatePlayer(dt)
    local input = {
        left = self:isKeyDown('left', 'a'),
        right = self:isKeyDown('right', 'd'),
        up = self:isKeyDown('up', 'w'),
        down = self:isKeyDown('down', 's'),
        jump = false
    }

    local bounds = {
        x = 0,
        y = 0,
        width = self.game_width,
        height = self.game_height,
        wrap_x = false,
        wrap_y = false
    }

    self.player.time_elapsed = self.time_elapsed
    if self.player.rotation then
        self.player.angle = self.player.rotation
    end

    self.movement_controller:update(dt, self.player, input, bounds)

    self.player.rotation = self.player.angle

    self:applyEnvironmentForces(dt)
    self:clampPlayerPosition()
end

function DodgeGame:applyEnvironmentForces(dt)
    if not self.player or not self.safe_zone then
        return
    end

    if self.params.area_gravity ~= 0 then
        local dx = self.safe_zone.x - self.player.x
        local dy = self.safe_zone.y - self.player.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > 0 then
            local gx = (dx / dist) * self.params.area_gravity * dt
            local gy = (dy / dist) * self.params.area_gravity * dt
            self.player.vx = self.player.vx + gx
            self.player.vy = self.player.vy + gy
        end
    end

    if self.params.wind_strength > 0 and self.params.wind_type ~= "none" then
        local wx, wy = self:getWindForce(dt)
        self.player.vx = self.player.vx + wx * dt
        self.player.vy = self.player.vy + wy * dt
    end

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
    if self.params.wind_type == "changing_steady" or self.params.wind_type == "changing_turbulent" then
        self.wind_timer = self.wind_timer + dt
        if self.wind_timer >= 3.0 then
            self.wind_timer = 0
            self.wind_current_angle = self.wind_current_angle + math.rad(30)
        end
    end

    local base_angle = self.wind_current_angle
    local wx, wy

    if self.params.wind_type == "steady" or self.params.wind_type == "changing_steady" then
        wx = math.cos(base_angle) * self.params.wind_strength
        wy = math.sin(base_angle) * self.params.wind_strength
    elseif self.params.wind_type == "turbulent" or self.params.wind_type == "changing_turbulent" then
        local turbulence_angle = base_angle + (math.random() - 0.5) * math.pi * 0.5
        wx = math.cos(turbulence_angle) * self.params.wind_strength
        wy = math.sin(turbulence_angle) * self.params.wind_strength
    else
        wx, wy = 0, 0
    end

    return wx, wy
end

function DodgeGame:clampPlayerPosition()
    local sz = self.safe_zone
    if sz then
        local shape = sz.area_shape or "circle"
        local dxp = self.player.x - sz.x
        local dyp = self.player.y - sz.y
        local dist = math.sqrt(dxp*dxp + dyp*dyp)

        if shape == "circle" then
            local max_dist = math.max(0, sz.radius - self.player.radius)
            if dist > max_dist and dist > 0 then
                local scale = max_dist / dist
                self.player.x = sz.x + dxp * scale
                self.player.y = sz.y + dyp * scale

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
            local half_size = sz.radius - self.player.radius
            local clamped_x = math.max(sz.x - half_size, math.min(sz.x + half_size, self.player.x))
            local clamped_y = math.max(sz.y - half_size, math.min(sz.y + half_size, self.player.y))

            if clamped_x ~= self.player.x or clamped_y ~= self.player.y then
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
            local r = sz.radius - self.player.radius
            local abs_dx = math.abs(dxp)
            local abs_dy = math.abs(dyp)
            local hex_width = r * 0.866
            local clamped = false
            local nx, ny = 0, 0

            if abs_dy > r then
                self.player.y = sz.y + (dyp > 0 and r or -r)
                clamped = true
                ny = dyp > 0 and 1 or -1
            elseif abs_dx > hex_width then
                self.player.x = sz.x + (dxp > 0 and hex_width or -hex_width)
                clamped = true
                nx = dxp > 0 and 1 or -1
            elseif abs_dx * 0.577 + abs_dy > r then
                local sign_x = dxp > 0 and 1 or -1
                local sign_y = dyp > 0 and 1 or -1

                nx = sign_x * 0.5
                ny = sign_y * 0.866

                local v1x, v1y = 0, sign_y * r
                local v2x, v2y = sign_x * hex_width, sign_y * r * 0.5
                local edx, edy = v2x - v1x, v2y - v1y

                local t = ((dxp - v1x) * edx + (dyp - v1y) * edy) / (edx * edx + edy * edy)
                t = math.max(0, math.min(1, t))

                self.player.x = sz.x + v1x + t * edx
                self.player.y = sz.y + v1y + t * edy
                clamped = true
            end

            if clamped then
                local len = math.sqrt(nx*nx + ny*ny)
                if len > 0 then
                    nx, ny = nx/len, ny/len
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
end

function DodgeGame:updatePlayerTrail(dt)
    if self.params.player_trail_length <= 0 or not self.player then
        return
    end

    local rotation = self.player.rotation or 0
    local back_angle = rotation + math.pi / 2
    local trail_x = self.player.x + math.cos(back_angle) * self.player.radius
    local trail_y = self.player.y + math.sin(back_angle) * self.player.radius

    self.player_trail:addPoint(trail_x, trail_y)
end

--------------------------------------------------------------------------------
-- SHIELD SYSTEM
--------------------------------------------------------------------------------

function DodgeGame:updateShield(dt)
    if not self.player or self.player.shield_recharge_time <= 0 then
        return
    end

    if self.player.shield_charges < self.player.shield_max then
        self.player.shield_recharge_timer = self.player.shield_recharge_timer - dt
        if self.player.shield_recharge_timer <= 0 then
            self.player.shield_charges = self.player.shield_charges + 1
            self.player.shield_recharge_timer = self.player.shield_recharge_time
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
        self:triggerCameraShake(self.params.camera_shake_intensity * 0.5)
    end
end

--------------------------------------------------------------------------------
-- VISUAL EFFECTS
--------------------------------------------------------------------------------

function DodgeGame:updateCameraShake(dt)
    self.visual_effects:update(dt)
end

function DodgeGame:triggerCameraShake(intensity)
    self.visual_effects:shake(nil, intensity or self.params.camera_shake_intensity, "exponential")
end

--------------------------------------------------------------------------------
-- SCORING & TRACKING
--------------------------------------------------------------------------------

function DodgeGame:updateScoreTracking(dt)
    if not self.player or not self.safe_zone then
        return
    end

    if self.params.score_multiplier_mode == "speed" then
        local speed = math.sqrt(self.player.vx * self.player.vx + self.player.vy * self.player.vy)
        self.avg_speed_tracker.sum = self.avg_speed_tracker.sum + speed
        self.avg_speed_tracker.count = self.avg_speed_tracker.count + 1
    end

    if self.params.score_multiplier_mode == "center" or self.params.score_multiplier_mode == "edge" then
        local dx = self.player.x - self.safe_zone.x
        local dy = self.player.y - self.safe_zone.y
        local dist = math.sqrt(dx*dx + dy*dy)
        local normalized_dist = dist / math.max(1, self.safe_zone.radius)

        if self.params.score_multiplier_mode == "center" then
            local center_weight = 1.0 - normalized_dist
            self.center_time_tracker.total_weighted = self.center_time_tracker.total_weighted + center_weight * dt
            self.center_time_tracker.total_time = self.center_time_tracker.total_time + dt
        elseif self.params.score_multiplier_mode == "edge" then
            local edge_weight = normalized_dist
            self.edge_time_tracker.total_weighted = self.edge_time_tracker.total_weighted + edge_weight * dt
            self.edge_time_tracker.total_time = self.edge_time_tracker.total_time + dt
        end
    end
end

function DodgeGame:getScoreMultiplier()
    if self.params.score_multiplier_mode == "speed" then
        if self.avg_speed_tracker.count > 0 then
            local avg_speed = self.avg_speed_tracker.sum / self.avg_speed_tracker.count
            local speed_ratio = avg_speed / (self.player.max_speed or 600)
            return 1.0 + speed_ratio * 0.5
        end
    elseif self.params.score_multiplier_mode == "center" then
        if self.center_time_tracker.total_time > 0 then
            local avg_center = self.center_time_tracker.total_weighted / self.center_time_tracker.total_time
            return 1.0 + avg_center * 0.5
        end
    elseif self.params.score_multiplier_mode == "edge" then
        if self.edge_time_tracker.total_time > 0 then
            local avg_edge = self.edge_time_tracker.total_weighted / self.edge_time_tracker.total_time
            return 1.0 + avg_edge * 0.5
        end
    end
    return 1.0
end

--------------------------------------------------------------------------------
-- GEOMETRY HELPERS
--------------------------------------------------------------------------------

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
    local dx = px - cx
    local dy = py - cy
    local abs_dx = math.abs(dx)
    local abs_dy = math.abs(dy)

    if abs_dy > radius then return false end

    local hex_half_width = radius * 0.866025
    if abs_dx > hex_half_width then return false end

    if abs_dx * 0.577 + abs_dy > radius then return false end

    return true
end

function DodgeGame:getPointOnShapeBoundary(cx, cy, radius, shape, angle)
    shape = shape or "circle"

    if shape == "circle" then
        return cx + math.cos(angle) * radius, cy + math.sin(angle) * radius

    elseif shape == "square" then
        local dx = math.cos(angle)
        local dy = math.sin(angle)
        local abs_dx = math.abs(dx)
        local abs_dy = math.abs(dy)

        local t
        if abs_dx > abs_dy then
            t = radius / abs_dx
        else
            t = radius / abs_dy
        end
        return cx + dx * t, cy + dy * t

    elseif shape == "hex" then
        local dx = math.cos(angle)
        local dy = math.sin(angle)
        local abs_dx = math.abs(dx)
        local abs_dy = math.abs(dy)
        local hex_width = radius * 0.866

        local t = radius

        if abs_dy > 0.001 then
            local t_vert = radius / abs_dy
            local hit_x = abs_dx * t_vert
            if hit_x <= hex_width then
                t = t_vert
            end
        end

        if abs_dx > 0.001 then
            local t_horiz = hex_width / abs_dx
            local hit_y = abs_dy * t_horiz
            if hit_y <= radius * 0.5 then
                t = math.min(t, t_horiz)
            end
        end

        local angled_denom = 0.577 * abs_dx + abs_dy
        if angled_denom > 0.001 then
            local t_angled = radius / angled_denom
            t = math.min(t, t_angled)
        end

        return cx + dx * t, cy + dy * t

    else
        return cx + math.cos(angle) * radius, cy + math.sin(angle) * radius
    end
end

function DodgeGame:checkCircleLineCollision(cx, cy, cr, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local len_sq = dx*dx + dy*dy
    if len_sq == 0 then
        local dist_sq = (cx - x1)*(cx - x1) + (cy - y1)*(cy - y1)
        return dist_sq <= cr*cr
    end

    local t = math.max(0, math.min(1, ((cx - x1)*dx + (cy - y1)*dy) / len_sq))
    local px = x1 + t * dx
    local py = y1 + t * dy

    local dist_sq = (cx - px)*(cx - px) + (cy - py)*(cy - py)
    return dist_sq <= cr*cr
end

--------------------------------------------------------------------------------
-- GAME STATE / VICTORY
--------------------------------------------------------------------------------

function DodgeGame:checkGameOver()
    if self.game_over then return end

    local sz = self.safe_zone
    if not sz then return end

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

function DodgeGame:checkComplete()
    local result = self.victory_checker:check()
    if result then
        self.victory = (result == "victory")
        self.game_over = (result == "loss")
        return true
    end
    return false
end

function DodgeGame:onComplete()
    local is_win = self.victory

    if is_win and self.params.score_multiplier_mode ~= "none" then
        local multiplier = self:getScoreMultiplier()
        if multiplier > 1.0 then
            print(string.format("[DodgeGame] Score multiplier applied: %.2fx (%s mode)", multiplier, self.params.score_multiplier_mode))
            self.metrics.objects_dodged = math.floor(self.metrics.objects_dodged * multiplier)
            self.metrics.combo = math.floor(self.metrics.combo * multiplier)
        end
    end

    if is_win then
    end

    self:stopMusic()
    DodgeGame.super.onComplete(self)
end

function DodgeGame:getCompletionRatio()
    if self.params.victory_condition == "time" then
        if self.params.victory_limit and self.params.victory_limit > 0 then
            return math.min(1.0, self.time_elapsed / self.params.victory_limit)
        end
    elseif self.params.victory_condition == "dodge_count" then
        if self.dodge_target and self.dodge_target > 0 then
            return math.min(1.0, (self.metrics.objects_dodged or 0) / self.dodge_target)
        end
    end
    return 1.0
end

--------------------------------------------------------------------------------
-- ARENA / SAFE ZONE
--------------------------------------------------------------------------------

function DodgeGame:syncSafeZoneFromArena()
    if not self.arena_controller then return end
    self.safe_zone = self.arena_controller:getState()
    self.holes = self.arena_controller.holes
end

--------------------------------------------------------------------------------
-- OBJECT UPDATE & COLLISION
--------------------------------------------------------------------------------

function DodgeGame:updateObjects(dt)
    for i = #self.objects, 1, -1 do
        local obj = self.objects[i]
        if not obj then goto continue_obj_loop end

        obj.angle = obj.angle or 0
        obj.vx = obj.vx or math.cos(obj.angle) * obj.speed
        obj.vy = obj.vy or math.sin(obj.angle) * obj.speed

        if obj.sprite_rotation_speed and obj.sprite_rotation_speed ~= 0 then
            obj.sprite_rotation_angle = (obj.sprite_rotation_angle or 0) + (obj.sprite_rotation_speed * dt)
            obj.sprite_rotation_angle = obj.sprite_rotation_angle % 360
        end

        if obj.type == 'shooter' and obj.is_enemy then
            obj.shoot_timer = obj.shoot_timer - dt
            if obj.shoot_timer <= 0 then
                obj.shoot_timer = obj.shoot_interval
                local dx = self.player.x - obj.x
                local dy = self.player.y - obj.y
                local proj_angle = math.atan2(dy, dx)

                local shooter_cfg = (self.variant and self.variant.shooter) or
                                   (self.runtimeCfg.objects and self.runtimeCfg.objects.shooter) or
                                   { projectile_size = 0.5, projectile_speed = 0.8 }

                local projectile_speed = self.object_speed * (shooter_cfg.projectile_speed or 0.8)
                self.projectile_system:shoot(
                    "enemy_projectile",
                    obj.x,
                    obj.y,
                    proj_angle,
                    projectile_speed / (self.object_speed * 0.8),
                    {
                        radius = (self.params.object_radius or 15) * (shooter_cfg.projectile_size or 0.5),
                        is_projectile = true,
                        warned = false
                    }
                )
            end
        elseif obj.type == 'bouncer' and obj.is_enemy then
            if not obj.has_entered then
                if obj.x >= obj.radius and obj.x <= self.game_width - obj.radius and
                   obj.y >= obj.radius and obj.y <= self.game_height - obj.radius then
                    obj.has_entered = true
                end
            end

            if obj.has_entered then
                local next_x = obj.x + obj.vx * dt
                local next_y = obj.y + obj.vy * dt
                local temp = {x = next_x, y = next_y, vx = obj.vx, vy = obj.vy, radius = obj.radius}
                local bounds_result = PhysicsUtils.handleBounds(temp, {width = self.game_width, height = self.game_height})
                if bounds_result.hit then
                    obj.vx = temp.vx
                    obj.vy = temp.vy
                    obj.bounce_count = obj.bounce_count + 1
                end

                local max_bounces = (self.runtimeCfg.objects and self.runtimeCfg.objects.bouncer and self.runtimeCfg.objects.bouncer.max_bounces) or 3
                if obj.bounce_count >= max_bounces then
                    obj.should_remove = true
                    obj.was_dodged = true
                end
            end
        elseif obj.type == 'teleporter' and obj.is_enemy then
            obj.teleport_timer = obj.teleport_timer - dt
            if obj.teleport_timer <= 0 then
                obj.teleport_timer = obj.teleport_interval
                local angle = math.random() * math.pi * 2
                local dist = obj.teleport_range
                obj.x = self.player.x + math.cos(angle) * dist
                obj.y = self.player.y + math.sin(angle) * dist
                obj.x = math.max(obj.radius, math.min(self.game_width - obj.radius, obj.x))
                obj.y = math.max(obj.radius, math.min(self.game_height - obj.radius, obj.y))
                local dx = self.player.x - obj.x
                local dy = self.player.y - obj.y
                local new_angle = math.atan2(dy, dx)
                obj.angle = new_angle
                obj.vx = math.cos(new_angle) * obj.speed
                obj.vy = math.sin(new_angle) * obj.speed
            end
        end

        if obj.tracking_strength and obj.tracking_strength > 0 and self.player then
            local tx, ty = self.player.x, self.player.y
            local desired = math.atan2(ty - obj.y, tx - obj.x)
            local function angdiff(a,b)
                local d = (a - b + math.pi) % (2*math.pi) - math.pi
                return d
            end
            local diff = angdiff(desired, obj.angle)
            local max_turn = math.rad(180) * obj.tracking_strength * dt
            if diff > max_turn then diff = max_turn elseif diff < -max_turn then diff = -max_turn end
            obj.angle = obj.angle + diff
            obj.vx = math.cos(obj.angle) * obj.speed
            obj.vy = math.sin(obj.angle) * obj.speed
        end

        if obj.type == 'seeker' then
            local tx, ty = self.player.x, self.player.y
            local desired = math.atan2(ty - obj.y, tx - obj.x)
            local function angdiff(a,b)
                local d = (a - b + math.pi) % (2*math.pi) - math.pi
                return d
            end
            local diff = angdiff(desired, obj.angle)
            local base_turn = math.rad(self.params.seeker_turn_rate)

            if not self._seeker_debug_printed then
                print(string.format("[DodgeGame] SEEKER BEHAVIOR ACTIVE - seeker_turn_rate: %d, base_turn_rad: %.4f",
                    self.params.seeker_turn_rate, base_turn))
                self._seeker_debug_printed = true
            end
            local te = self.time_elapsed or 0
            local difficulty_scaler = 1 + math.min(((self.runtimeCfg.seeker and self.runtimeCfg.seeker.difficulty and self.runtimeCfg.seeker.difficulty.max) or 2.0), te / ((self.runtimeCfg.seeker and self.runtimeCfg.seeker.difficulty and self.runtimeCfg.seeker.difficulty.time) or 90))
            local max_turn = base_turn * difficulty_scaler * dt
            if diff > max_turn then diff = max_turn elseif diff < -max_turn then diff = -max_turn end
            obj.angle = obj.angle + diff
            obj.vx = math.cos(obj.angle) * obj.speed
            obj.vy = math.sin(obj.angle) * obj.speed
        elseif obj.type == 'zigzag' or obj.type == 'sine' then
            local perp_x = -math.sin(obj.angle)
            local perp_y =  math.cos(obj.angle)
            local t = love.timer.getTime() * obj.wave_speed
            local wobble = math.sin(t + obj.wave_phase) * obj.wave_amp
            local wobble_v = wobble * (((self.runtimeCfg.objects and self.runtimeCfg.objects.zigzag and self.runtimeCfg.objects.zigzag.wave_velocity_factor) or 2.0))
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

        obj.x = obj.x + obj.vx * dt
        obj.y = obj.y + obj.vy * dt
        ::post_move::

        if obj.trail_positions then
            table.insert(obj.trail_positions, 1, {x = obj.x, y = obj.y})
            while #obj.trail_positions > self.params.obstacle_trails do
                table.remove(obj.trail_positions)
            end
        end

        if not obj.entered_play then
            if obj.x > 0 and obj.x < self.game_width and obj.y > 0 and obj.y < self.game_height then
                obj.entered_play = true
            end
        end

        if obj.type == 'splitter' and self.safe_zone then
            local sz = self.safe_zone
            local shape = sz.area_shape or "circle"
            local check_radius = sz.radius + obj.radius
            local inside = false
            if shape == "circle" then
                local dxs = obj.x - sz.x
                local dys = obj.y - sz.y
                inside = (dxs*dxs + dys*dys) <= (check_radius * check_radius)
            else
                inside = self:isPointInCircle(obj.x, obj.y, sz.x, sz.y, check_radius) or
                         (shape == "square" and self:isPointInSquare(obj.x, obj.y, sz.x, sz.y, check_radius)) or
                         (shape == "hex" and self:isPointInHex(obj.x, obj.y, sz.x, sz.y, check_radius))
            end
            if inside and not obj.was_inside then
                local shards = (self.runtimeCfg.objects and self.runtimeCfg.objects.splitter and self.runtimeCfg.objects.splitter.shards_count) or 3
                self:spawnShards(obj, shards)
                obj.did_split = true
                if obj.is_projectile then
                    self.projectile_system:removeProjectile(obj)
                else
                    self.entity_controller:removeEntity(obj)
                end
                goto continue_obj_loop
            end
            obj.was_inside = inside
        end

        if PhysicsUtils.circleCollision(self.player.x, self.player.y, self.player.radius, obj.x, obj.y, obj.radius) then
            if obj.is_projectile then
                self.projectile_system:removeProjectile(obj)
            else
                self.entity_controller:removeEntity(obj)
            end

            if self:hasActiveShield() then
                self:consumeShield()
                self:playSound("hit", 0.7)
            else
                self.metrics.collisions = self.metrics.collisions + 1
                self.current_combo = 0
                self:playSound("hit", 1.0)
                self:triggerCameraShake()

                self.health_system:takeDamage(1, "obstacle_collision")
                self.lives = self.health_system.lives

                if not self.health_system:isAlive() then
                    self:playSound("death", 1.0)
                    self:onComplete()
                    return
                end
            end
        elseif obj.trail_positions and #obj.trail_positions > 1 then
            local hit_trail = false
            for j = 1, #obj.trail_positions - 1 do
                local p1 = obj.trail_positions[j]
                local p2 = obj.trail_positions[j + 1]
                if self:checkCircleLineCollision(self.player.x, self.player.y, self.player.radius, p1.x, p1.y, p2.x, p2.y) then
                    hit_trail = true
                    break
                end
            end

            if hit_trail then
                if obj.is_projectile then
                    self.projectile_system:removeProjectile(obj)
                else
                    self.entity_controller:removeEntity(obj)
                end
                if self:hasActiveShield() then
                    self:consumeShield()
                    self:playSound("hit", 0.5)
                else
                    self.metrics.collisions = self.metrics.collisions + 1
                    self.current_combo = 0
                    self:playSound("hit", 0.8)
                    self:triggerCameraShake(self.params.camera_shake_intensity * 0.7)
                    if self.metrics.collisions >= self.lives then
                        self:playSound("death", 1.0)
                        self:onComplete()
                        return
                    end
                end
            end
        elseif self:isObjectOffscreen(obj) or obj.should_remove then
            if obj.is_projectile then
                self.projectile_system:removeProjectile(obj)
            else
                self.entity_controller:removeEntity(obj)
            end
            if obj.entered_play or obj.was_dodged then
                self.metrics.objects_dodged = self.metrics.objects_dodged + 1

                self:playSound("dodge", 0.3)

                self.current_combo = self.current_combo + 1
                if self.current_combo > self.metrics.combo then
                    self.metrics.combo = self.current_combo
                end
            end
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

function DodgeGame:isObjectOffscreen(obj)
    if not obj then return true end
    return obj.x < -obj.radius or obj.x > self.game_width + obj.radius or
           obj.y < -obj.radius or obj.y > self.game_height + obj.radius
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
        if self.safe_zone then
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
        table.insert(self.warnings, self:createWarning())
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
        vx = math.cos(angle or 0) * final_speed,
        vy = math.sin(angle or 0) * final_speed
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

    local obj = self.entity_controller:spawn("obstacle", spawn_x, spawn_y, custom_params)

    if obj and (not self._last_enemy_debug or (love.timer.getTime() - self._last_enemy_debug) > 1.0) then
        print(string.format("[DodgeGame] Created enemy: type=%s, enemy_type=%s, is_enemy=%s",
            obj.type or "nil", obj.enemy_type or "nil", tostring(obj.is_enemy)))
        self._last_enemy_debug = love.timer.getTime()
    end

    return obj
end

function DodgeGame:createWarning()
    local sx, sy = self:pickSpawnPoint()
    local tx, ty = self:pickTargetPointOnRing()
    local angle = math.atan2(ty - sy, tx - sx)
    angle = self:ensureInboundAngle(sx, sy, angle)
    local warning_duration = (self.params.warning_time or 0.5) / self.difficulty_modifiers.speed
    return { type = 'radial', sx = sx, sy = sy, angle = angle, time = warning_duration }
end

function DodgeGame:createObjectFromWarning(warning)
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
            self:createEnemyObject(warning.sx, warning.sy, warning.angle, true, enemy_def)
            return
        end
    end
    local enemy_def = self.params.enemy_types.obstacle
    if enemy_def then
        self:createEnemyObject(warning.sx, warning.sy, warning.angle, true, enemy_def)
    else
        self:createObject(warning.sx, warning.sy, warning.angle, true)
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

    local custom_params = {
        warned = was_warned,
        radius = base_radius,
        type = kind or 'linear',
        speed = base_speed,
        tracking_strength = self.params.obstacle_tracking or 0,
        angle = angle or 0,
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
    local n = count or (((self.runtimeCfg.objects and self.runtimeCfg.objects.splitter and self.runtimeCfg.objects.splitter.shards_count) or 2))
    for i=1,n do
        local spread = math.rad(((self.runtimeCfg.objects and self.runtimeCfg.objects.splitter and self.runtimeCfg.objects.splitter.spread_deg) or 35))
        local a = parent.angle + (math.random()*2 - 1) * spread
        local shard_speed = self.object_speed * (((self.runtimeCfg.objects and self.runtimeCfg.objects.splitter and self.runtimeCfg.objects.splitter.shard_speed_factor) or 0.36))

        local custom_params = {
            radius = math.max(((self.runtimeCfg.objects and self.runtimeCfg.objects.splitter and self.runtimeCfg.objects.splitter.shard_radius_min) or 6), math.floor(parent.radius * (((self.runtimeCfg.objects and self.runtimeCfg.objects.splitter and self.runtimeCfg.objects.splitter.shard_radius_factor) or 0.6)))),
            type = 'linear',
            speed = shard_speed,
            warned = false,
            angle = a,
            vx = math.cos(a) * shard_speed,
            vy = math.sin(a) * shard_speed
        }

        self.entity_controller:spawn("obstacle", parent.x, parent.y, custom_params)
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
    local sz = self.safe_zone
    local scale = (self.params.target_ring_min_scale or 1.2) + math.random() * ((self.params.target_ring_max_scale or 1.5) - (self.params.target_ring_min_scale or 1.2))
    local r = (sz and sz.radius or math.min(self.game_width, self.game_height) * 0.4) * scale
    local a = math.random() * math.pi * 2
    local cx = sz and sz.x or self.game_width/2
    local cy = sz and sz.y or self.game_height/2
    local shape = sz and sz.area_shape or "circle"

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
    local sz = self.safe_zone
    local r = sz.radius
    local cx, cy = sz.x, sz.y
    local shape = sz.area_shape or "circle"
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
