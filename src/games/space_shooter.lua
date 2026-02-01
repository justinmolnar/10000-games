--[[
    Space Shooter - Vertical scrolling shooter

    Enemies descend from top, player shoots to destroy. Supports modes:
    - Continuous spawning (default)
    - Space Invaders mode (grid movement, descent)
    - Galaga mode (formations, entrance animations, dive attacks)

    Plus hazards (asteroids, meteors, gravity wells, blackout zones),
    powerups, and various bullet patterns.

    Most configuration comes from space_shooter_schema.json via SchemaLoader.
    Components are created from schema definitions in setupComponents().
]]

local BaseGame = require('src.games.base_game')
local SpaceShooterView = require('src.games.views.space_shooter_view')
local SpaceShooter = BaseGame:extend('SpaceShooter')

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function SpaceShooter:init(game_data, cheats, di, variant_override)
    SpaceShooter.super.init(self, game_data, cheats, di, variant_override)
    self.default_sprite_set = "fighter_1"

    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.space_shooter)
    self.params = self.di.components.SchemaLoader.load(self.variant, "space_shooter_schema", runtimeCfg)

    self:applyCheats({
        speed_modifier = {"movement_speed", "bullet_speed", "enemy_base_speed"},
        advantage_modifier = {"player_width", "player_height"}
    })
    local extra_deaths = (self.cheats.advantage_modifier or {}).deaths or 0
    self.params.lives_count = self.params.lives_count + extra_deaths

    local cfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.space_shooter) or {}
    self.game_width = (cfg.arena and cfg.arena.width) or 800
    self.game_height = (cfg.arena and cfg.arena.height) or 600

    self:setupComponents()
    self:setupEntities()

    self.view = SpaceShooterView:new(self, self.variant)
    self:loadAssets()
end

function SpaceShooter:setupComponents()
    local p = self.params
    local game = self

    -- Schema-driven components (movement_controller, hud, health_system, visual_effects, popup_manager)
    self:createComponentsFromSchema()
    self.lives = self.health_system.lives

    -- Apply runtime overrides to movement_controller
    if self.movement_controller then
        self.movement_controller.thrust_acceleration = self.params.movement_speed * 5
        self.movement_controller.jump_distance = self.game_width * self.params.jump_distance
    end

    -- Projectile system (minimal - game handles fire modes/patterns/collision)
    self:createProjectileSystemFromSchema({
        pooling = true, max_projectiles = 500, out_of_bounds_margin = 100
    })

    -- Entity controller from schema with callbacks
    self:createEntityControllerFromSchema({
        enemy = {
            on_death = function(enemy)
                game:onEnemyDestroyed(enemy)
            end
        }
    }, {spawning = {mode = "manual"}, pooling = true, max_entities = 1000})

    -- Victory condition from schema (loss target uses params.lives_count which includes cheat modifier)
    self:createVictoryConditionFromSchema()

    -- Effect system for timed powerup effects
    self:createEffectSystem(function(effect_type, data)
        self:onEffectExpire(effect_type, data)
    end)
    self.powerup_entities = {}
    self.powerup_spawn_timer = p.powerup_spawn_rate or 15.0
end

function SpaceShooter:setupEntities()
    local p = self.params

    -- Create player
    local y_offset = p.player_start_y_offset
    local player_y = p.reverse_gravity and y_offset or (self.game_height - y_offset)
    self:createPlayer({
        y = player_y,
        extra = {
            fire_cooldown = 0, auto_fire_timer = 0, charge_progress = 0, is_charging = false,
            burst_remaining = 0, burst_timer = 0, ammo = p.ammo_capacity,
            reload_timer = 0, is_reloading = false, heat = 0, is_overheated = false, overheat_timer = 0,
            angle = 0, vx = 0, vy = 0, jump_timer = 0, is_jumping = false, jump_progress = 0,
            jump_start_x = 0, jump_start_y = 0, jump_target_x = 0, jump_target_y = 0
        }
    })

    -- Game state
    self.survival_time, self.scroll_offset, self.difficulty_scale = 0, 0, 1.0
    self.spawn_timer, self.asteroid_spawn_timer = 0, 0
    self.meteor_timer = p.meteor_frequency > 0 and (60 / p.meteor_frequency) or 0
    self.kills, self.deaths = 0, 0
    self.enemies, self.asteroids, self.meteors, self.meteor_warnings = {}, {}, {}, {}

    -- Spawn environmental hazards via EntityController
    for i = 1, p.gravity_wells_count do
        self.entity_controller:spawn("gravity_well",
            math.random(50, self.game_width - 50),
            math.random(50, self.game_height - 50))
    end
    for i = 1, p.blackout_zones_count do
        local r = p.blackout_zone_radius
        self.entity_controller:spawn("blackout_zone",
            math.random(r, self.game_width - r),
            math.random(r, self.game_height - r), {
            vx = p.blackout_zones_move and (math.random() - 0.5) * 100 or 0,
            vy = p.blackout_zones_move and (math.random() - 0.5) * 100 or 0
        })
    end

    -- Mode-specific state (initialized upfront like breakout)
    self.wave_state = {active = false, enemies_remaining = 0, pause_timer = 0}
    self.grid_state = {initialized = false, wave_active = false, wave_pause_timer = 0, initial_enemy_count = 0, wave_number = 0}
    self.galaga_state = {formation_positions = {}, dive_timer = p.dive_frequency, diving_count = 0, wave_active = false, wave_pause_timer = 0, initial_enemy_count = 0, wave_number = 0, spawn_timer = 0, spawned_count = 0, wave_modifiers = {}}

    -- Build weighted configs for variant enemy spawning
    self.enemy_weighted_configs = {}
    if self.variant and self.variant.enemies then
        for _, ed in ipairs(self.variant.enemies) do
            local enemy_def = p.enemy_types[ed.type]
            if enemy_def then
                local health_config = p.use_health_range
                    and {range = {min = p.enemy_health_min, max = p.enemy_health_max}, multipliers = {enemy_def.health or 1}, bounds = {min = 1}}
                    or {variance = p.enemy_health_variance, multipliers = {enemy_def.health or 1}, bounds = {min = 1}}
                local health = math.floor(self:getScaledValue(p.enemy_health, health_config) + 0.5)
                local cfg = {
                    weight = ed.multiplier,
                    enemy_type = enemy_def.name, type = ed.type, health = health, max_health = health,
                    speed_multiplier = enemy_def.speed_multiplier or 1.0, shoot_rate_multiplier = enemy_def.shoot_rate_multiplier or 1.0,
                    use_direction = true
                }
                -- Convert movement_pattern to flags
                if enemy_def.movement_pattern == "zigzag" then
                    cfg.sine_amplitude = 50
                    cfg.sine_frequency = p.zigzag_frequency or 2
                end
                table.insert(self.enemy_weighted_configs, cfg)
            end
        end
    end
end

function SpaceShooter:setPlayArea(width, height)
    self.game_width = width
    self.game_height = height

    -- Update player position if player exists
    if self.player then
        self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
        local y_offset = self.params.player_start_y_offset
        self.player.y = self.params.reverse_gravity and y_offset or (self.game_height - y_offset)
    end

    -- Recalculate Galaga formation if using Galaga behavior
    if self.params.enemy_behavior == "galaga" and self.galaga_state and #self.galaga_state.formation_positions > 0 then
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

--------------------------------------------------------------------------------
-- Update Loop
--------------------------------------------------------------------------------

function SpaceShooter:updateGameLogic(dt)
    self.health_system:update(dt)
    self.lives = self.health_system.lives

    --Update EntityController
    self.entity_controller:update(dt)

    --Sync arrays with EntityController (using getEntitiesByType for clarity)
    self.enemies = self.entity_controller:getEntitiesByType("enemy")
    self.asteroids = self.entity_controller:getEntitiesByType("asteroid")
    self.meteors = self.entity_controller:getEntitiesByType("meteor")
    self.meteor_warnings = self.entity_controller:getEntitiesByType("meteor_warning")

    --Update ProjectileSystem (bullets)
    local game_bounds = {
        x_min = 0,
        x_max = self.game_width,
        y_min = 0,
        y_max = self.game_height
    }
    self.projectile_system:update(dt, game_bounds)

    --Sync bullets with ProjectileSystem
    self.player_bullets = self.projectile_system:getByTeam("player")
    self.enemy_bullets = self.projectile_system:getByTeam("enemy")

    self:updatePlayer(dt)

    --Track survival time for victory conditions
    self.survival_time = self.survival_time + dt

    --Update difficulty scaling
    self:updateDifficulty(dt)

    -- Enemy behavior: Space Invaders, Galaga, or Default
    if self.params.enemy_behavior == "space_invaders" then
        self:updateSpaceInvadersGrid(dt)
    elseif self.params.enemy_behavior == "galaga" then
        self:updateGalagaFormation(dt)
    else
        -- Default enemy spawning based on pattern
        if self.params.enemy_spawn_pattern == "waves" then
            local result = self:updateWaveState(self.wave_state, {
                count_func = function() return self.wave_state.enemies_remaining end,
                on_start = function() self.wave_state.enemies_remaining = math.floor(self.params.wave_enemies_per_wave * self.difficulty_scale); self.spawn_timer = 0 end
            }, dt)
            if result == "active" and self.wave_state.enemies_remaining > 0 then
                self.spawn_timer = self.spawn_timer - dt
                if self.spawn_timer <= 0 then self:spawnEnemy(); self.wave_state.enemies_remaining = self.wave_state.enemies_remaining - 1; self.spawn_timer = 0.3 end
            end
        elseif self.params.enemy_spawn_pattern == "continuous" then
            self.spawn_timer = self.spawn_timer - dt
            if self.spawn_timer <= 0 then
                self:spawnEnemy()
                local variant_diff = self.variant and self.variant.difficulty_modifier or 1.0
                self.spawn_timer = self.params.spawn_base_rate / (self.difficulty_modifiers.count * variant_diff * self.params.enemy_spawn_rate_multiplier * self.difficulty_scale)
            end
        elseif self.params.enemy_spawn_pattern == "clusters" then
            self.spawn_timer = self.spawn_timer - dt
            if self.spawn_timer <= 0 then
                for i = 1, math.random(3, 5) do self:spawnEnemy() end
                local variant_diff = self.variant and self.variant.difficulty_modifier or 1.0
                self.spawn_timer = (self.params.spawn_base_rate * 2) / (self.difficulty_modifiers.count * variant_diff * self.params.enemy_spawn_rate_multiplier)
            end
        end
    end

    self:updateEnemies(dt)
    self:updateBullets(dt)

    -- Update powerups
    local game_bounds = {width = self.game_width, height = self.game_height}
    self:updatePowerups(dt, game_bounds)
    self.effect_system:update(dt)

    -- Sync arrays for view compatibility
    self.powerups = self.powerup_entities
    self.active_powerups = self.effect_system:getActiveEffects()

    --Environmental hazards (asteroids, meteors via generic behaviors)
    if self.params.asteroid_density > 0 or self.params.meteor_frequency > 0 then
        self:updateHazards(dt)
    end

    -- Gravity wells affect player and bullets (sync for view)
    self.gravity_wells = self.entity_controller:getEntitiesByType("gravity_well")
    self.blackout_zones = self.entity_controller:getEntitiesByType("blackout_zone")
    if #self.gravity_wells > 0 then
        local PhysicsUtils = self.di.components.PhysicsUtils
        PhysicsUtils.applyForces(self.player, {gravity_wells = self.gravity_wells, gravity_well_strength_multiplier = 1.0}, dt)
        for _, bullet in ipairs(self.player_bullets) do
            PhysicsUtils.applyForces(bullet, {gravity_wells = self.gravity_wells, gravity_well_strength_multiplier = 0.7}, dt)
        end
        self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
        self.player.y = math.max(0, math.min(self.game_height - self.player.height, self.player.y))
    end

    -- Blackout zones bounce off walls
    if self.params.blackout_zones_move then
        self.entity_controller:updateBehaviors(dt, {
            bounce_movement = {width = self.game_width, height = self.game_height}
        })
    end

    if self.params.scroll_speed > 0 then
        self:updateScrolling(dt)
    end
end

function SpaceShooter:updatePlayer(dt)
    -- Movement via MovementController primitives (schema flags drive behavior)
    local p = self.params
    local mc = self.movement_controller
    local player = self.player
    local bounds = {x = 0, y = 0, width = self.game_width, height = self.game_height,
                    wrap_x = p.screen_wrap, wrap_y = p.screen_wrap}

    player.time_elapsed = (player.time_elapsed or 0) + dt

    local left = self:isKeyDown('left', 'a')
    local right = self:isKeyDown('right', 'd')
    local up = self:isKeyDown('up', 'w')
    local down = self:isKeyDown('down', 's')

    local dx, dy = 0, 0
    if left then dx = dx - 1 end
    if right then dx = dx + 1 end
    if up then dy = dy - 1 end
    if down then dy = dy + 1 end

    local dominated_by_jump = p.use_jump and mc:isJumping("player")

    -- Jump system
    if p.use_jump then
        if mc:isJumping("player") then
            mc:updateJump(player, "player", dt, bounds, player.time_elapsed)
        elseif (dx ~= 0 or dy ~= 0) and mc:canJump("player", player.time_elapsed) then
            mc:startJump(player, "player", dx, dy, player.time_elapsed, bounds)
        end
    end

    if not dominated_by_jump then
        -- Rail: horizontal only
        if p.use_rail then
            if left then player.x = player.x - p.movement_speed * dt end
            if right then player.x = player.x + p.movement_speed * dt end
        end

        -- Rotation
        if p.use_rotation then
            if left then mc:applyRotation(player, -1, nil, dt) end
            if right then mc:applyRotation(player, 1, nil, dt) end
        end

        -- Thrust
        if p.use_thrust and up then
            mc:applyThrust(player, player.angle, nil, dt)
            mc:applyFriction(player, p.accel_friction, dt)
        end

        -- Directional movement
        if p.use_directional and (dx ~= 0 or dy ~= 0) then
            if p.use_velocity then
                mc:applyDirectionalVelocity(player, dx, dy, p.movement_speed, dt)
                mc:applyFriction(player, p.accel_friction, dt)
            else
                mc:applyDirectionalMove(player, dx, dy, p.movement_speed, dt)
            end
        end

        -- Decel friction when not actively moving
        local is_moving = (p.use_thrust and up) or (p.use_directional and (dx ~= 0 or dy ~= 0))
        if not is_moving and p.decel_friction < 1.0 then
            mc:applyFriction(player, p.decel_friction, dt)
        end
    end

    -- Always apply these
    if p.use_velocity then mc:applyVelocity(player, dt) end
    mc:applyBounds(player, bounds)
    if p.use_bounce then mc:applyBounce(player, bounds) end

    -- Shield regeneration handled by health_system (updated in updateGameLogic)

    -- Fire mode handling (game-side)
    self:updateFireMode(dt, self:isKeyDown('space'))

    -- Ammo/heat resource management (game-side)
    self:updateResources(dt)
    if self:isKeyDown('r') then self:reload() end
end

-- Fire mode handling (moved from ProjectileSystem to game)
function SpaceShooter:updateFireMode(dt, is_fire_pressed)
    local p = self.params
    local player = self.player
    local mode = p.fire_mode or "manual"

    if mode == "manual" then
        player.fire_cooldown = (player.fire_cooldown or 0) - dt
        if is_fire_pressed and player.fire_cooldown <= 0 and self:canShoot() then
            self:playerShoot(1.0)
            player.fire_cooldown = p.fire_cooldown or 0.2
        end
    elseif mode == "auto" then
        player.auto_fire_timer = (player.auto_fire_timer or 0) - dt
        if is_fire_pressed and player.auto_fire_timer <= 0 and self:canShoot() then
            self:playerShoot(1.0)
            player.auto_fire_timer = 1.0 / (p.fire_rate or 5)
        end
    elseif mode == "charge" then
        if is_fire_pressed then
            if not player.is_charging then
                player.is_charging = true
                player.charge_progress = 0
            end
            player.charge_progress = math.min((player.charge_progress or 0) + dt, p.charge_time or 1)
        else
            if player.is_charging and self:canShoot() then
                local charge_mult = player.charge_progress / (p.charge_time or 1)
                self:playerShoot(charge_mult)
                player.is_charging = false
                player.charge_progress = 0
            end
        end
    elseif mode == "burst" then
        if (player.burst_remaining or 0) > 0 then
            player.burst_timer = (player.burst_timer or 0) + dt
            if player.burst_timer >= (p.burst_delay or 0.05) and self:canShoot() then
                self:playerShoot(1.0)
                player.burst_remaining = player.burst_remaining - 1
                player.burst_timer = 0
            end
        else
            player.fire_cooldown = (player.fire_cooldown or 0) - dt
            if is_fire_pressed and player.fire_cooldown <= 0 then
                player.burst_remaining = p.burst_count or 3
                player.burst_timer = 0
                player.fire_cooldown = p.fire_cooldown or 0.5
            end
        end
    end
end

-- Ammo/heat resource system (moved from ProjectileSystem to game)
function SpaceShooter:canShoot()
    local p = self.params
    local player = self.player
    if p.ammo_enabled and player.is_reloading then return false end
    if p.ammo_enabled and (player.ammo or 0) <= 0 then
        player.is_reloading = true
        player.reload_timer = p.ammo_reload_time or 2.0
        return false
    end
    if p.overheat_enabled and player.is_overheated then return false end
    return true
end

function SpaceShooter:onShoot()
    local p = self.params
    local player = self.player
    if p.ammo_enabled then
        player.ammo = (player.ammo or p.ammo_capacity) - 1
    end
    if p.overheat_enabled then
        player.heat = (player.heat or 0) + 1
        if player.heat >= (p.overheat_threshold or 10) then
            player.is_overheated = true
            player.overheat_timer = p.overheat_cooldown or 2.0
            player.heat = p.overheat_threshold or 10
        end
    end
end

function SpaceShooter:updateResources(dt)
    local p = self.params
    local player = self.player
    if p.ammo_enabled and player.is_reloading then
        player.reload_timer = (player.reload_timer or 0) - dt
        if player.reload_timer <= 0 then
            player.is_reloading = false
            player.ammo = p.ammo_capacity
        end
    end
    if p.overheat_enabled then
        if player.is_overheated then
            player.overheat_timer = (player.overheat_timer or 0) - dt
            if player.overheat_timer <= 0 then
                player.is_overheated = false
                player.heat = 0
            end
        elseif (player.heat or 0) > 0 then
            player.heat = math.max(0, player.heat - dt * (p.overheat_heat_dissipation or 1))
        end
    end
end

function SpaceShooter:reload()
    local p = self.params
    local player = self.player
    if p.ammo_enabled and not player.is_reloading and (player.ammo or 0) < p.ammo_capacity then
        player.is_reloading = true
        player.reload_timer = p.ammo_reload_time or 2.0
    end
end

-- Player shooting with pattern support
function SpaceShooter:playerShoot(charge_multiplier)
    charge_multiplier = charge_multiplier or 1.0
    local p = self.params
    local spawn_x, spawn_y, base_angle = self:getPlayerShootParams()
    local speed = (p.bullet_speed or 400) * charge_multiplier
    local pattern = p.bullet_pattern or "single"

    if pattern == "single" then
        self:spawnBullet(spawn_x, spawn_y, base_angle, speed, "player")
    elseif pattern == "double" then
        local offset = 5
        local perp_x = -math.sin(base_angle) * offset
        local perp_y = math.cos(base_angle) * offset
        self:spawnBullet(spawn_x - perp_x, spawn_y - perp_y, base_angle, speed, "player")
        self:spawnBullet(spawn_x + perp_x, spawn_y + perp_y, base_angle, speed, "player")
    elseif pattern == "triple" then
        local spread = math.rad(15)
        self:spawnBullet(spawn_x, spawn_y, base_angle, speed, "player")
        self:spawnBullet(spawn_x, spawn_y, base_angle - spread, speed, "player")
        self:spawnBullet(spawn_x, spawn_y, base_angle + spread, speed, "player")
    elseif pattern == "spread" then
        local count = p.bullets_per_shot or 5
        local arc = math.rad(p.bullet_arc or 60)
        local start_angle = base_angle - arc / 2
        local step = count > 1 and (arc / (count - 1)) or 0
        for i = 0, count - 1 do
            self:spawnBullet(spawn_x, spawn_y, start_angle + step * i, speed, "player")
        end
    elseif pattern == "spiral" then
        local count = 6
        local angle_step = (math.pi * 2) / count
        local spiral_offset = math.rad((love.timer.getTime() * 200) % 360)
        for i = 0, count - 1 do
            self:spawnBullet(spawn_x, spawn_y, base_angle + (i * angle_step) + spiral_offset, speed, "player")
        end
    elseif pattern == "wave" then
        -- Wave pattern: three bullets with sine wave offset
        self:spawnBullet(spawn_x, spawn_y, base_angle, speed, "player")
        self:spawnBullet(spawn_x - 10, spawn_y, base_angle, speed, "player")
        self:spawnBullet(spawn_x + 10, spawn_y, base_angle, speed, "player")
    elseif pattern == "ring" then
        local count = 8
        local angle_step = (math.pi * 2) / count
        for i = 0, count - 1 do
            self:spawnBullet(spawn_x, spawn_y, base_angle + (i * angle_step), speed, "player")
        end
    end

    self:onShoot()
    self:playSound("shoot", 0.6)
end

-- Spawn a single bullet
function SpaceShooter:spawnBullet(x, y, angle, speed, team)
    local p = self.params
    self.projectile_system:spawn({
        x = x, y = y,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        team = team,
        lifetime = p.bullet_lifetime or 5,
        width = p.bullet_width or 6,
        height = p.bullet_height or 12,
        radius = (p.bullet_width or 6) / 2,
        angle = angle,
        piercing = p.bullet_piercing,
        homing = p.bullet_homing and (p.homing_strength or 0) > 0,
        homing_turn_rate = p.homing_strength or 3
    })
end

-- Enemy shooting (override base_game helper)
function SpaceShooter:entityShoot(entity)
    local p = self.params
    local spawn_x, spawn_y, base_angle = self:getEntityShootParams(entity)
    local speed = p.enemy_bullet_speed or 200
    local pattern = p.enemy_bullet_pattern or "single"

    if pattern == "single" then
        self:spawnEnemyBullet(spawn_x, spawn_y, base_angle, speed)
    elseif pattern == "spread" then
        local count = p.enemy_bullets_per_shot or 3
        local arc = math.rad(p.enemy_bullet_spread_angle or 30)
        local start_angle = base_angle - arc / 2
        local step = count > 1 and (arc / (count - 1)) or 0
        for i = 0, count - 1 do
            self:spawnEnemyBullet(spawn_x, spawn_y, start_angle + step * i, speed)
        end
    else
        self:spawnEnemyBullet(spawn_x, spawn_y, base_angle, speed)
    end
end

function SpaceShooter:spawnEnemyBullet(x, y, angle, speed)
    local p = self.params
    self.projectile_system:spawn({
        x = x, y = y,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        team = "enemy",
        lifetime = 5,
        width = p.enemy_bullet_size or 8,
        height = p.enemy_bullet_size or 8,
        radius = (p.enemy_bullet_size or 8) / 2,
        angle = angle
    })
end


function SpaceShooter:updateEnemies(dt)
    local PM = self.di.components.PatternMovement
    local bounds = {x = 0, y = 0, width = self.game_width, height = self.game_height}
    local game = self

    -- Update movement using primitives (entity flags drive behavior)
    for _, enemy in ipairs(self.enemies) do
        -- Skip special modes handled elsewhere
        if enemy.use_grid or enemy.use_bezier or enemy.use_formation then
            enemy.skip_offscreen_removal = true
        else
            enemy.skip_offscreen_removal = false

            -- Apply behaviors based on entity flags
            if enemy.use_steering then
                PM.steerToward(enemy, enemy.target_x or self.player.x, enemy.target_y or self.player.y,
                    enemy.turn_rate or math.rad(180), dt)
                PM.setVelocityFromAngle(enemy, enemy.angle, enemy.speed or 100)
            end

            if enemy.use_direction then
                PM.applyDirection(enemy, dt)
            end

            if enemy.use_velocity then
                PM.applyVelocity(enemy, dt)
            end

            if enemy.sine_amplitude then
                PM.updateTime(enemy, dt)
                PM.applySineOffset(enemy, enemy.sine_axis or "x", dt,
                    enemy.sine_frequency or 2, enemy.sine_amplitude)
            end

            if enemy.orbit_radius then
                PM.updateOrbit(enemy, enemy.orbit_center_x or bounds.width/2,
                    enemy.orbit_center_y or bounds.height/2, enemy.orbit_radius,
                    enemy.orbit_speed or 1, dt)
            end

            if enemy.use_bounce then
                PM.applyBounce(enemy, bounds, enemy.bounce_damping)
            end

            if enemy.move_toward_target and not enemy.dive_complete then
                if PM.moveToward(enemy, enemy.target_x, enemy.target_y, enemy.speed or 100, dt, enemy.arrive_threshold) then
                    enemy.dive_complete = true
                end
            end
        end
    end

    -- Player collision via EntityController
    self.entity_controller:checkCollision(self.player, function(entity)
        if entity.type_name == "enemy" then
            game:takeDamage()
            game.entity_controller:removeEntity(entity)
        end
    end)

    -- Shooting and off-screen removal via behaviors
    -- Normal: spawn at top (y=-30), move down, remove when y > game_height
    -- Reverse: spawn at bottom (y=game_height), move up, remove when y < -100
    local offscreen_bounds = self.params.reverse_gravity
        and {top = -100, bottom = self.game_height + 500}  -- only top removal matters
        or {top = -100, bottom = self.game_height}
    self.entity_controller:updateBehaviors(dt, {
        shooting_enabled = self.params.enemy_bullets_enabled or (self.difficulty_modifiers.complexity > 2),
        on_shoot = function(enemy) game:entityShoot(enemy) end,
        remove_offscreen = offscreen_bounds
    })
end

function SpaceShooter:updateBullets(dt)
    local Physics = self.di.components.PhysicsUtils
    local PM = self.di.components.PatternMovement

    -- Update homing bullets (player bullets only)
    for _, bullet in ipairs(self.player_bullets) do
        if bullet.homing and bullet.homing_turn_rate then
            -- Find nearest enemy
            local closest, closest_dist = nil, math.huge
            for _, enemy in ipairs(self.enemies) do
                if enemy.active ~= false then
                    local dx, dy = enemy.x - bullet.x, enemy.y - bullet.y
                    local dist = dx * dx + dy * dy
                    if dist < closest_dist then closest, closest_dist = enemy, dist end
                end
            end
            if closest then
                PM.steerToward(bullet, closest.x, closest.y, bullet.homing_turn_rate, dt)
                local speed = math.sqrt(bullet.vx * bullet.vx + bullet.vy * bullet.vy)
                PM.setVelocityFromAngle(bullet, bullet.angle, speed)
            end
        end
    end

    -- Player bullets vs enemies (using physics_utils)
    for _, bullet in ipairs(self.player_bullets) do
        for _, enemy in ipairs(self.enemies) do
            if enemy.active ~= false and Physics.circleCollision(
                bullet.x, bullet.y, bullet.radius or 3,
                enemy.x + enemy.width / 2, enemy.y + enemy.height / 2,
                math.max(enemy.width, enemy.height) / 2
            ) then
                self.entity_controller:hitEntity(enemy, 1, bullet)
                if not bullet.piercing then
                    self.projectile_system:remove(bullet)
                    break
                end
            end
        end
    end

    -- Enemy bullets vs player (using physics_utils)
    for _, bullet in ipairs(self.enemy_bullets) do
        if Physics.circleCollision(
            bullet.x, bullet.y, bullet.radius or 4,
            self.player.x + self.player.width / 2, self.player.y + self.player.height / 2,
            math.max(self.player.width, self.player.height) / 2
        ) then
            self:takeDamage()
            self.projectile_system:remove(bullet)
        end
    end
end

--------------------------------------------------------------------------------
-- Entity Spawning
--------------------------------------------------------------------------------

function SpaceShooter:spawnEnemy()
    local p = self.params
    local spawn_y = p.reverse_gravity and self.game_height or p.enemy_start_y_offset
    local variant_diff = self.variant and self.variant.difficulty_modifier or 1.0
    local base_speed = self:getScaledValue(p.enemy_base_speed, {
        multipliers = {self.difficulty_modifiers.speed, self.cheats.speed_modifier or 1.0, variant_diff}
    })
    local speed = base_speed * p.enemy_speed_multiplier * math.sqrt(self.difficulty_scale)
    local shoot_rate = math.max(0.5, (p.enemy_shoot_rate_max - self.difficulty_modifiers.complexity * p.enemy_shoot_rate_complexity)) / p.enemy_fire_rate
    local direction = p.reverse_gravity and (-math.pi / 2) or (math.pi / 2)
    local extra = {use_direction = true, speed = speed, direction = direction, zigzag_frequency = p.zigzag_frequency, zigzag_amplitude = speed * 0.5, shoot_interval = shoot_rate, health = p.enemy_health}

    -- Formation spawning
    if p.enemy_formation == "v_formation" then
        local positions = {}
        local count, center_x, spacing = 5, self.game_width / 2, 60
        for i = 1, count do
            local offset = (i - math.ceil(count / 2)) * spacing
            positions[i] = {x = center_x + offset, y = spawn_y - math.abs(offset) * 0.5}
        end
        self.entity_controller:spawnAtPositions("enemy", positions, extra)
    elseif p.enemy_formation == "wall" then
        local positions = {}
        local count, spacing = 6, self.game_width / 7
        for i = 1, count do
            positions[i] = {x = spacing * i, y = spawn_y}
        end
        self.entity_controller:spawnAtPositions("enemy", positions, extra)
    elseif p.enemy_formation == "spiral" then
        local positions = {}
        local count, center_x, radius = 8, self.game_width / 2, 100
        for i = 1, count do
            local angle = (i / count) * math.pi * 2
            positions[i] = {x = center_x + math.cos(angle) * radius, y = spawn_y + math.sin(angle) * radius * 0.3}
        end
        self.entity_controller:spawnAtPositions("enemy", positions, extra)
    else
        -- Single enemy spawn - use weighted configs if available (50% chance)
        local use_weighted = #self.enemy_weighted_configs > 0 and math.random() < 0.5
        local movement = self.difficulty_modifiers.complexity >= 2 and (math.random() > 0.5 and 'zigzag' or 'straight') or 'straight'
        local health_config = p.use_health_range
            and {range = {min = p.enemy_health_min, max = p.enemy_health_max}, bounds = {min = 1}}
            or {variance = p.enemy_health_variance, bounds = {min = 1}}
        local health = math.floor(self:getScaledValue(p.enemy_health, health_config) + 0.5)

        local spawn_extra = {
            width = p.enemy_width, height = p.enemy_height,
            use_direction = true,
            sine_amplitude = (movement == 'zigzag') and (speed * 0.5) or nil,
            sine_frequency = (movement == 'zigzag') and p.zigzag_frequency or nil,
            speed = speed, direction = p.reverse_gravity and (-math.pi / 2) or (math.pi / 2),
            shoot_timer = math.random() * (p.enemy_shoot_rate_max - p.enemy_shoot_rate_min) + p.enemy_shoot_rate_min,
            shoot_interval = shoot_rate, health = health, is_variant_enemy = use_weighted
        }

        local enemy = self:spawnEntity("enemy", {
            x = math.random(0, self.game_width - p.enemy_width),
            y = spawn_y,
            weighted_configs = use_weighted and self.enemy_weighted_configs or nil,
            extra = spawn_extra
        })

        -- Post-spawn setup for variant enemies
        if enemy and use_weighted then
            enemy.shoot_rate = shoot_rate / (enemy.shoot_rate_multiplier or 1.0)
            if enemy.movement_pattern == 'dive' then
                enemy.target_x = self.player.x + self.player.width / 2
                enemy.target_y = self.player.y + self.player.height / 2
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Event Callbacks
--------------------------------------------------------------------------------

function SpaceShooter:onEnemyDestroyed(enemy)
    self:handleEntityDestroyed(enemy, {
        destroyed_counter = "kills",
        scoring = {base = 10, combo_mult = 0},
        effects = {particles = false}
    })
    self:playSound("enemy_explode", 1.0)
end

--------------------------------------------------------------------------------
-- Space Invaders Mode
--------------------------------------------------------------------------------

function SpaceShooter:initSpaceInvadersGrid()
    local wave_mult = 1.0 + (math.max(0, self.grid_state.wave_number - 1) * self.params.wave_difficulty_increase)
    local cfg = {multipliers = {wave_mult}, variance = self.params.wave_random_variance}
    local wave_rows = math.floor(self:getScaledValue(self.params.grid_rows, {multipliers = {wave_mult}, variance = self.params.wave_random_variance, bounds = {min = 1}}) + 0.5)
    local wave_columns = math.floor(self:getScaledValue(self.params.grid_columns, {multipliers = {wave_mult}, variance = self.params.wave_random_variance, bounds = {min = 2}}) + 0.5)
    local wave_speed = self:getScaledValue(self.params.grid_speed, cfg)
    local wave_health = math.floor(self:getScaledValue(self.params.enemy_health, {multipliers = {wave_mult}, bounds = {min = 1}}) + 0.5)

    local spacing_x = (self.game_width / (wave_columns + 1)) * self.params.enemy_density
    local spacing_y = 50 * self.params.enemy_density
    local start_x = spacing_x

    local positions = {}
    for row = 1, wave_rows do
        for col = 1, wave_columns do
            table.insert(positions, {
                x = start_x + (col - 1) * spacing_x,
                y = 80 + (row - 1) * spacing_y,
                grid_row = row, grid_col = col
            })
        end
    end
    self.entity_controller:spawnAtPositions("enemy", positions, {
        movement_pattern = 'grid', health = wave_health, wave_speed = wave_speed
    })

    self.grid_state.initialized = true
    self.grid_state.initial_enemy_count = wave_rows * wave_columns
    self.grid_state.wave_active = true
    -- Note: wave_number is incremented by updateWaveState, not here
    self.grid_state.shoot_timer = 1.0  -- Initial delay before first shot
end

function SpaceShooter:updateSpaceInvadersGrid(dt)
    local game = self

    -- Wave system using BaseGame helper
    if self.params.waves_enabled then
        -- Map grid_state to wave state format (active field)
        self.grid_state.active = self.grid_state.wave_active
        self.grid_state.pause_timer = self.grid_state.wave_pause_timer

        local result = self:updateWaveState(self.grid_state, {
            count_func = function()
                for _, enemy in ipairs(game.enemies) do
                    if enemy.movement_pattern == 'grid' then return 1 end
                end
                return 0
            end,
            on_depleted = function()
                game.grid_state.initialized = false
                game.grid_state.direction = nil
            end,
            on_start = function() game:initSpaceInvadersGrid() end
        }, dt)

        -- Sync back to grid_state fields
        self.grid_state.wave_active = self.grid_state.active
        self.grid_state.wave_pause_timer = self.grid_state.pause_timer
        if result == "paused" then return end
    end

    -- Initialize grid if not yet done
    if not self.grid_state.initialized then
        self:initSpaceInvadersGrid()
    end

    -- Grid movement: all grid enemies move together as a unit
    local base_speed = self.params.grid_speed
    for _, enemy in ipairs(self.enemies) do
        if enemy.movement_pattern == 'grid' and enemy.wave_speed then
            base_speed = enemy.wave_speed
            break
        end
    end

    -- Count grid enemies and calculate speed
    local grid_count = 0
    for _, enemy in ipairs(self.enemies) do
        if enemy.movement_pattern == 'grid' and enemy.active and not enemy.marked_for_removal then
            grid_count = grid_count + 1
        end
    end

    -- Initialize direction if needed
    self.grid_state.direction = self.grid_state.direction or 1

    -- Speed increases as enemies die
    local speed_mult = 1.0
    local initial_count = self.grid_state.initial_enemy_count or 1
    if initial_count > 0 and grid_count > 0 then
        speed_mult = 1 + (1 - grid_count / initial_count) * 2
    end

    local move = base_speed * speed_mult * dt * self.grid_state.direction
    local hit_edge = false

    -- Move all grid enemies and check for edge collision
    for _, enemy in ipairs(self.enemies) do
        if enemy.movement_pattern == 'grid' and enemy.active and not enemy.marked_for_removal then
            enemy.x = enemy.x + move
            if enemy.x <= 0 or enemy.x + (enemy.width or 0) >= self.game_width then
                hit_edge = true
            end
        end
    end

    -- Bounce and descend when hitting edge
    if hit_edge then
        self.grid_state.direction = -self.grid_state.direction
        for _, enemy in ipairs(self.enemies) do
            if enemy.movement_pattern == 'grid' and enemy.active then
                -- Clamp back inside bounds
                local w = enemy.width or 0
                if enemy.x <= 0 then
                    enemy.x = 1
                elseif enemy.x + w >= self.game_width then
                    enemy.x = self.game_width - w - 1
                end
                -- Descend
                enemy.y = enemy.y + (self.params.grid_descent or 20)
            end
        end
    end

    -- Mark enemies for removal when below screen
    local bounds_bottom = self.game_height + 50
    for _, enemy in ipairs(self.enemies) do
        if enemy.movement_pattern == 'grid' and enemy.active and enemy.y > bounds_bottom then
            enemy.removal_reason = "out_of_bounds"
            enemy.marked_for_removal = true
        end
    end

    -- Grid shooting: global timer, one random bottom-row enemy shoots
    if self.params.enemy_bullets_enabled then
        self.grid_state.shoot_timer = (self.grid_state.shoot_timer or 2.0) - dt
        if self.grid_state.shoot_timer <= 0 then
            -- Find bottom-most enemy in each column, pick one randomly to shoot
            local columns = {}
            for _, enemy in ipairs(self.enemies) do
                if enemy.movement_pattern == 'grid' and enemy.active then
                    local col = enemy.grid_col
                    if not columns[col] or enemy.grid_row > columns[col].grid_row then
                        columns[col] = enemy
                    end
                end
            end

            -- Collect shooters and pick one
            local shooters = {}
            for _, enemy in pairs(columns) do
                table.insert(shooters, enemy)
            end

            if #shooters > 0 then
                local shooter = shooters[math.random(#shooters)]
                self:entityShoot(shooter)
            end

            -- Reset timer - shoots faster as fewer enemies remain (count ALL grid enemies)
            local total_grid_enemies = 0
            for _, enemy in ipairs(self.enemies) do
                if enemy.movement_pattern == 'grid' and enemy.active then
                    total_grid_enemies = total_grid_enemies + 1
                end
            end
            local base_interval = 2.5  -- Base seconds between shots
            local min_interval = 0.5   -- Minimum interval when few enemies left
            local ratio = total_grid_enemies / math.max(1, self.grid_state.initial_enemy_count)
            self.grid_state.shoot_timer = min_interval + (base_interval - min_interval) * ratio
        end
    end
end

--------------------------------------------------------------------------------
-- Galaga Mode
--------------------------------------------------------------------------------

function SpaceShooter:initGalagaFormation()
    -- Create formation grid at top of screen with proper wrapping
    local base_spacing_x = 60  -- Base horizontal spacing between enemies
    local spacing_x = base_spacing_x * self.params.enemy_density
    local spacing_y = 40 * self.params.enemy_density
    local start_x = 50  -- Left margin
    local start_y = 60
    local margin_right = 50  -- Right margin

    self.galaga_state.formation_positions = {}  -- Clear existing positions

    -- Calculate how many columns fit on screen
    local available_width = self.game_width - start_x - margin_right
    local max_cols_per_row = math.floor(available_width / spacing_x)
    if max_cols_per_row < 1 then max_cols_per_row = 1 end

    -- Create formation with automatic row wrapping
    local total_slots = self.params.formation_size
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

function SpaceShooter:updateGalagaFormation(dt)
    local PatternMovement = self.di.components.PatternMovement
    local game = self

    -- Wave system using BaseGame helper
    if self.params.waves_enabled then
        -- Map galaga_state to wave state format
        self.galaga_state.active = self.galaga_state.wave_active
        self.galaga_state.pause_timer = self.galaga_state.wave_pause_timer

        local result = self:updateWaveState(self.galaga_state, {
            count_func = function()
                for _, enemy in ipairs(game.enemies) do
                    if enemy.formation_state then return 1 end
                end
                return 0
            end,
            on_depleted = function()
                game.galaga_state.formation_positions = {}
            end,
            on_start = function(wave_num)
                local wave_mult = 1.0 + ((wave_num - 1) * game.params.wave_difficulty_increase)
                game.galaga_state.wave_modifiers = {
                    health = math.floor(game:getScaledValue(game.params.enemy_health, {multipliers = {wave_mult}, bounds = {min = 1}}) + 0.5),
                    dive_frequency = game.params.dive_frequency / game:getScaledValue(1, {multipliers = {wave_mult}, variance = game.params.wave_random_variance})
                }

                game:initGalagaFormation()
                game.galaga_state.spawned_count = 0
                game.galaga_state.spawn_timer = 0
                game.galaga_state.diving_count = 0
                game.galaga_state.dive_timer = 0

                local initial_count = math.min(game.params.initial_spawn_count, #game.galaga_state.formation_positions)
                for i = 1, initial_count do
                    local slot = game.galaga_state.formation_positions[i]
                    local side = math.random() > 0.5 and "left" or "right"
                    game:spawnEntity("enemy", {x = slot.x, y = slot.y, formation_slot = slot,
                        entrance = (game.params.entrance_pattern or "swoop") .. "_" .. side,
                        extra = {formation_state = 'entering', health = game.galaga_state.wave_modifiers.health or game.params.enemy_health}})
                    game.galaga_state.spawned_count = game.galaga_state.spawned_count + 1
                end
            end
        }, dt)

        -- Sync back
        self.galaga_state.wave_active = self.galaga_state.active
        self.galaga_state.wave_pause_timer = self.galaga_state.pause_timer
        if result == "paused" then return end
    end

    -- Initialize formation if needed (first spawn, non-wave mode)
    if #self.galaga_state.formation_positions == 0 then
        self:initGalagaFormation()
        self.galaga_state.spawned_count = 0
        self.galaga_state.spawn_timer = 0
        self.galaga_state.wave_modifiers = {}

        local initial_count = math.min(self.params.initial_spawn_count, #self.galaga_state.formation_positions)
        for i = 1, initial_count do
            local slot = self.galaga_state.formation_positions[i]
            local side = math.random() > 0.5 and "left" or "right"
            self:spawnEntity("enemy", {x = slot.x, y = slot.y, formation_slot = slot,
                entrance = (self.params.entrance_pattern or "swoop") .. "_" .. side,
                extra = {formation_state = 'entering', health = self.galaga_state.wave_modifiers.health or self.params.enemy_health}})
            self.galaga_state.spawned_count = self.galaga_state.spawned_count + 1
        end
    end

    -- Gradual enemy spawning via EntityController behavior
    local game = self
    self.galaga_state.gradual_spawn = self.galaga_state.gradual_spawn or {timer = 0, spawned_count = self.galaga_state.spawned_count}
    self.galaga_state.gradual_spawn.slots = self.galaga_state.formation_positions
    self.galaga_state.gradual_spawn.max_count = self.params.formation_size
    self.galaga_state.gradual_spawn.interval = self.params.spawn_interval
    self.galaga_state.gradual_spawn.on_spawn = function(slot)
        local side = math.random() > 0.5 and "left" or "right"
        game:spawnEntity("enemy", {x = slot.x, y = slot.y, formation_slot = slot,
            entrance = (game.params.entrance_pattern or "swoop") .. "_" .. side,
            extra = {formation_state = 'entering', health = game.galaga_state.wave_modifiers.health or game.params.enemy_health}})
        game.galaga_state.spawned_count = game.galaga_state.spawned_count + 1
    end
    self.entity_controller:updateBehaviors(dt, {gradual_spawn = self.galaga_state.gradual_spawn})

    -- Dive attack timer
    local dive_freq = (self.galaga_state.wave_modifiers and self.galaga_state.wave_modifiers.dive_frequency) or self.params.dive_frequency
    self.galaga_state.dive_timer = self.galaga_state.dive_timer - dt
    if self.galaga_state.dive_timer <= 0 and self.galaga_state.diving_count < self.params.max_diving_enemies then
        local candidates = {}
        for _, enemy in ipairs(self.enemies) do
            if enemy.formation_state == 'in_formation' then table.insert(candidates, enemy) end
        end

        if #candidates > 0 then
            local diver = candidates[math.random(#candidates)]
            diver.formation_state = 'diving'
            diver.movement_pattern = 'bezier'
            diver.bezier_t = 0
            diver.bezier_complete = false
            diver.bezier_duration = 3.0
            diver.bezier_path = PatternMovement.buildBezierPath(
                diver.x, diver.y,  -- start
                self.player.x + self.player.width / 2, self.player.y + self.player.height / 2,  -- control (dive target)
                diver.x, self.game_height + 50  -- end (exit)
            )
            self.galaga_state.diving_count = self.galaga_state.diving_count + 1
        end
        self.galaga_state.dive_timer = dive_freq
    end

    -- Update enemy states (use PatternMovement.updateBezier instead of inline math)
    for _, enemy in ipairs(self.enemies) do
        if enemy.formation_state == 'entering' then
            PatternMovement.updateBezier(enemy, dt)
            if enemy.bezier_complete then
                enemy.formation_state = 'in_formation'
                enemy.x, enemy.y = enemy.home_x, enemy.home_y
                enemy.movement_pattern = 'formation'
            end

        elseif enemy.formation_state == 'in_formation' then
            enemy.x, enemy.y = enemy.home_x, enemy.home_y

        elseif enemy.formation_state == 'diving' then
            PatternMovement.updateBezier(enemy, dt)
            if enemy.bezier_complete then
                self.entity_controller:removeEntity(enemy)
                self.galaga_state.diving_count = self.galaga_state.diving_count - 1
                if enemy.formation_slot then
                    enemy.formation_slot.occupied = false
                    local slot = enemy.formation_slot
                    local side = math.random() > 0.5 and "left" or "right"
                    self:spawnEntity("enemy", {x = slot.x, y = slot.y, formation_slot = slot,
                        entrance = (self.params.entrance_pattern or "swoop") .. "_" .. side,
                        extra = {formation_state = 'entering', health = self.galaga_state.wave_modifiers.health or self.params.enemy_health}})
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Hazards
--------------------------------------------------------------------------------

function SpaceShooter:updateHazards(dt)
    local p = self.params
    local game = self
    local direction = p.reverse_gravity and (-math.pi / 2) or (math.pi / 2)
    local offscreen = p.reverse_gravity and {top = -100} or {bottom = self.game_height + 50}

    -- Spawn meteor warnings on timer (delayed_spawn converts to meteors)
    if p.meteor_frequency > 0 then
        self.meteor_timer = self.meteor_timer - dt
        if self.meteor_timer <= 0 then
            for i = 1, math.random(3, 5) do
                self.entity_controller:spawn("meteor_warning", math.random(0, self.game_width - 30), 0, {
                    delayed_spawn = {timer = p.meteor_warning_time, spawn_type = "meteor"}
                })
            end
            self.meteor_timer = 60 / p.meteor_frequency
        end
    end

    -- Behaviors: asteroid spawning, meteor delayed_spawn, movement, rotation, offscreen
    self.entity_controller:updateBehaviors(dt, {
        timer_spawn = p.asteroid_density > 0 and {
            asteroid = {
                interval = 1.0 / p.asteroid_density,
                on_spawn = function(ec, type_name)
                    local size = math.random(p.asteroid_size_min, p.asteroid_size_max)
                    local spawn_y = p.reverse_gravity and game.game_height or -size
                    ec:spawn("asteroid", math.random(0, game.game_width - size), spawn_y, {
                        width = size, height = size,
                        use_direction = true, speed = p.asteroid_speed, direction = direction,
                        rotation = math.random() * math.pi * 2, rotation_speed = (math.random() - 0.5) * 2
                    })
                end
            }
        } or nil,
        delayed_spawn = {
            on_spawn = function(warning, ds)
                local spawn_y = p.reverse_gravity and game.game_height or -30
                game.entity_controller:spawn("meteor", warning.x, spawn_y, {
                    use_direction = true, speed = p.meteor_speed, direction = direction
                })
            end
        },
        pattern_movement = {
            PatternMovement = self.di.components.PatternMovement,
            bounds = {x = 0, y = 0, width = self.game_width, height = self.game_height}
        },
        rotation = true,
        remove_offscreen = offscreen
    })

    -- Collisions: hazards vs player, hazards vs bullets
    self.entity_controller:checkCollision(self.player, function(entity)
        if entity.type_name == "asteroid" or entity.type_name == "meteor" then
            game:takeDamage()
            game.entity_controller:removeEntity(entity)
        end
    end)
    -- Player bullets vs asteroids (using physics_utils)
    if p.asteroids_can_be_destroyed then
        local Physics = self.di.components.PhysicsUtils
        for _, bullet in ipairs(self.player_bullets) do
            for _, asteroid in ipairs(self.asteroids) do
                if asteroid.active ~= false and Physics.circleCollision(
                    bullet.x, bullet.y, bullet.radius or 3,
                    asteroid.x + asteroid.width / 2, asteroid.y + asteroid.height / 2,
                    asteroid.width / 2
                ) then
                    game.entity_controller:removeEntity(asteroid)
                    if not bullet.piercing then
                        self.projectile_system:remove(bullet)
                        break
                    end
                end
            end
        end
    end

    -- Player bullets vs meteors (using physics_utils)
    local Physics = self.di.components.PhysicsUtils
    for _, bullet in ipairs(self.player_bullets) do
        for _, meteor in ipairs(self.meteors) do
            if meteor.active ~= false and Physics.circleCollision(
                bullet.x, bullet.y, bullet.radius or 3,
                meteor.x + meteor.width / 2, meteor.y + meteor.height / 2,
                meteor.width / 2
            ) then
                game.entity_controller:removeEntity(meteor)
                if not bullet.piercing then
                    self.projectile_system:remove(bullet)
                    break
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Powerups
--------------------------------------------------------------------------------

SpaceShooter.POWERUP_COLORS = {
    speed = {0, 1, 1},
    rapid_fire = {1, 0.5, 0},
    pierce = {1, 0, 1},
    shield = {0.3, 0.7, 1},
    triple_shot = {0, 1, 0},
    spread_shot = {1, 1, 0}
}

function SpaceShooter:spawnPowerup(x, y)
    local p = self.params
    local types = p.powerup_types or {}
    if #types == 0 then return end

    local powerup_type = types[self.rng:random(1, #types)]
    local size = p.powerup_size or 20
    local vy = (p.powerup_drop_speed or 150) * (p.reverse_gravity and -1 or 1)
    table.insert(self.powerup_entities, {
        x = x,
        y = y,
        width = size,
        height = size,
        type = powerup_type,
        color = SpaceShooter.POWERUP_COLORS[powerup_type] or {1, 1, 1},
        vy = vy
    })
end

function SpaceShooter:updatePowerups(dt, bounds)
    local p = self.params
    if not p.powerup_enabled then return end

    -- Timer-based spawning
    self.powerup_spawn_timer = self.powerup_spawn_timer - dt
    if self.powerup_spawn_timer <= 0 then
        local x = self.rng:random(0, bounds.width - (p.powerup_size or 20))
        local y = p.reverse_gravity and bounds.height or 0
        self:spawnPowerup(x, y)
        self.powerup_spawn_timer = p.powerup_spawn_rate or 15.0
    end

    -- Move and check collection
    local Physics = self.di.components.PhysicsUtils
    for i = #self.powerup_entities, 1, -1 do
        local powerup = self.powerup_entities[i]
        powerup.y = powerup.y + powerup.vy * dt

        -- Check collection with player (circle collision)
        if Physics.circleCollision(powerup.x + powerup.width/2, powerup.y + powerup.height/2, powerup.width/2,
                                    self.player.x, self.player.y, self.player.radius or 15) then
            self:collectPowerup(powerup)
            table.remove(self.powerup_entities, i)
        elseif (not p.reverse_gravity and powerup.y > bounds.height) or
               (p.reverse_gravity and powerup.y + powerup.height < 0) then
            table.remove(self.powerup_entities, i)
        end
    end
end

function SpaceShooter:collectPowerup(powerup)
    local p = self.params
    local effect_type = powerup.type
    local duration = p.powerup_duration or 8.0
    local data = {}

    self:playSound("powerup", 1.0)

    -- Apply effect and store original values
    if effect_type == "speed" then
        data.orig_speed = p.movement_speed
        p.movement_speed = p.movement_speed * (p.powerup_speed_multiplier or 1.5)
    elseif effect_type == "rapid_fire" then
        data.orig_cooldown = p.fire_cooldown
        p.fire_cooldown = p.fire_cooldown * (p.powerup_rapid_fire_multiplier or 0.5)
    elseif effect_type == "pierce" then
        data.orig_pierce = p.bullet_piercing
        p.bullet_piercing = true
    elseif effect_type == "shield" then
        data.orig_shield = p.shield
        data.orig_shield_enabled = self.health_system and self.health_system.shield_enabled
        p.shield = true
        if self.health_system then
            self.health_system.shield_enabled = true
            self.health_system.shield_active = true
            self.health_system.shield_hits_remaining = self.health_system.shield_max_hits or 3
        end
    elseif effect_type == "triple_shot" then
        data.orig_pattern = p.bullet_pattern
        p.bullet_pattern = "triple"
    elseif effect_type == "spread_shot" then
        data.orig_pattern = p.bullet_pattern
        data.orig_bullets = p.bullets_per_shot
        p.bullet_pattern = "spread"
        p.bullets_per_shot = 5
    end

    self.effect_system:activate(effect_type, duration, data)
end

function SpaceShooter:onEffectExpire(effect_type, data)
    local p = self.params
    if effect_type == "speed" then
        p.movement_speed = data.orig_speed
    elseif effect_type == "rapid_fire" then
        p.fire_cooldown = data.orig_cooldown
    elseif effect_type == "pierce" then
        p.bullet_piercing = data.orig_pierce
    elseif effect_type == "shield" then
        p.shield = data.orig_shield
        if self.health_system then
            self.health_system.shield_enabled = data.orig_shield_enabled
            self.health_system.shield_active = false
            self.health_system.shield_hits_remaining = 0
        end
    elseif effect_type == "triple_shot" then
        p.bullet_pattern = data.orig_pattern
    elseif effect_type == "spread_shot" then
        p.bullet_pattern = data.orig_pattern
        p.bullets_per_shot = data.orig_bullets
    end
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

function SpaceShooter:draw()
    self.view:draw()
end

return SpaceShooter