local BaseGame = require('src.games.base_game')
local SpaceShooterView = require('src.games.views.space_shooter_view')
local SpaceShooter = BaseGame:extend('SpaceShooter')

function SpaceShooter:init(game_data, cheats, di, variant_override)
    SpaceShooter.super.init(self, game_data, cheats, di, variant_override)

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

    -- Projectile system from schema
    self:createProjectileSystemFromSchema({
        pooling = true, max_projectiles = 500,
        ammo = self.params.ammo_enabled and {
            enabled = true,
            capacity = self.params.ammo_capacity,
            reload_time = self.params.ammo_reload_time
        } or nil,
        heat = self.params.overheat_enabled and {
            enabled = true,
            max = self.params.overheat_threshold,
            cooldown = self.params.overheat_cooldown,
            dissipation = self.params.overheat_heat_dissipation
        } or nil
    })

    -- Entity controller from schema with callbacks
    self:createEntityControllerFromSchema({
        enemy = {
            on_death = function(enemy)
                game:onEnemyDestroyed(enemy)
            end
        },
        asteroid = {}
    }, {spawning = {mode = "manual"}, pooling = true, max_entities = 1000})

    -- Victory condition from schema (loss target uses params.lives_count which includes cheat modifier)
    self:createVictoryConditionFromSchema()

    -- Powerup system from schema (timer-based spawning)
    self:createPowerupSystemFromSchema({
        spawn_mode = "timer",
        spawn_drop_chance = 1.0,  -- Timer mode always spawns (rate controls frequency)
        reverse_gravity = p.reverse_gravity,
        on_collect = function(powerup) self:playSound("powerup", 1.0) end
    })
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

    -- Environmental hazards
    self.gravity_wells, self.blackout_zones = {}, {}
    for i = 1, p.gravity_wells_count do
        table.insert(self.gravity_wells, {
            x = math.random(50, self.game_width - 50), y = math.random(50, self.game_height - 50),
            radius = p.gravity_well_radius, strength = p.gravity_well_strength
        })
    end
    for i = 1, p.blackout_zones_count do
        table.insert(self.blackout_zones, {
            x = math.random(p.blackout_zone_radius, self.game_width - p.blackout_zone_radius),
            y = math.random(p.blackout_zone_radius, self.game_height - p.blackout_zone_radius),
            radius = p.blackout_zone_radius,
            vx = p.blackout_zones_move and (math.random() - 0.5) * 50 or 0,
            vy = p.blackout_zones_move and (math.random() - 0.5) * 50 or 0
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
                table.insert(self.enemy_weighted_configs, {
                    weight = ed.multiplier, movement_pattern = enemy_def.movement_pattern,
                    enemy_type = enemy_def.name, type = ed.type, health = health, max_health = health,
                    speed_multiplier = enemy_def.speed_multiplier or 1.0, shoot_rate_multiplier = enemy_def.shoot_rate_multiplier or 1.0
                })
            end
        end
    end
end

function SpaceShooter:loadAssets()
    self.sprites = {}
    local sprite_set = (self.variant and self.variant.sprite_set) or "fighter_1"
    local fallback = "fighter_1"
    local loader = self.di and self.di.spriteSetLoader

    if loader then
        self.sprites.player = loader:getSprite(sprite_set, "player", fallback)
        -- bullets, background, power_up - leave nil for view fallbacks

        for enemy_type in pairs(self.params.enemy_types) do
            local key = "enemy_" .. enemy_type
            self.sprites[key] = loader:getSprite(sprite_set, key, fallback)
        end
    end

    self:loadAudio()
end

function SpaceShooter:setPlayArea(width, height)
    self.game_width = width
    self.game_height = height

    -- Only update player position if player exists
    if self.player then
        self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
        local y_offset = self.params.player_start_y_offset
        self.player.y = self.params.reverse_gravity and y_offset or (self.game_height - y_offset)
        print("[SpaceShooter] Play area updated to:", width, height)
    else
        print("[SpaceShooter] setPlayArea called before init completed")
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

function SpaceShooter:updateGameLogic(dt)
    self.health_system:update(dt)
    self.lives = self.health_system.lives

    --Update EntityController
    self.entity_controller:update(dt)

    --Sync arrays with EntityController
    local entities = self.entity_controller:getEntities()
    self.enemies = {}
    self.asteroids = {}
    self.meteors = {}
    self.meteor_warnings = {}
    for _, entity in ipairs(entities) do
        if entity.type_name == "enemy" then
            table.insert(self.enemies, entity)
        elseif entity.type_name == "asteroid" then
            table.insert(self.asteroids, entity)
        elseif entity.type_name == "meteor" then
            table.insert(self.meteors, entity)
        elseif entity.type_name == "meteor_warning" then
            table.insert(self.meteor_warnings, entity)
        end
    end

    --Update ProjectileSystem (bullets)
    local game_bounds = {
        x_min = 0,
        x_max = self.game_width,
        y_min = 0,
        y_max = self.game_height
    }
    self.projectile_system:update(dt, game_bounds)

    --Sync bullets with ProjectileSystem
    self.player_bullets = self.projectile_system:getProjectilesByTeam("player")
    self.enemy_bullets = self.projectile_system:getProjectilesByTeam("enemy")

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
            self:updateWaveSpawning(dt)
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

    --Update PowerupSystem
    local game_bounds = {width = self.game_width, height = self.game_height}
    self.powerup_system:update(dt, self.player, game_bounds)

    --Sync arrays for view compatibility
    self.powerups = self.powerup_system:getPowerupsForRendering()
    self.active_powerups = self.powerup_system:getActivePowerupsForHUD()

    --Environmental hazards (asteroids, meteors via generic behaviors)
    if self.params.asteroid_density > 0 or self.params.meteor_frequency > 0 then
        self:updateHazards(dt)
    end
    if #self.gravity_wells > 0 then
        self:applyGravityWells(dt)
    end
    if self.params.scroll_speed > 0 then
        self:updateScrolling(dt)
    end

    --Update blackout zones
    if #self.blackout_zones > 0 and self.params.blackout_zones_move then
        self:updateBlackoutZones(dt)
    end
end

function SpaceShooter:updatePlayer(dt)
    -- Movement via MovementController
    self.player.time_elapsed = (self.player.time_elapsed or 0) + dt
    self.movement_controller:update(dt, self.player, {
        left = self:isKeyDown('left', 'a'), right = self:isKeyDown('right', 'd'),
        up = self:isKeyDown('up', 'w'), down = self:isKeyDown('down', 's')
    }, {
        x = 0, y = 0, width = self.game_width, height = self.game_height,
        wrap_x = self.params.screen_wrap, wrap_y = self.params.screen_wrap
    })

    -- Shield regeneration handled by health_system (updated in updateGameLogic)

    --Fire Mode Handling
    self.projectile_system:updateFireMode(dt, self.player, self.params.fire_mode, {
        cooldown = self.params.fire_cooldown,
        fire_rate = self.params.fire_rate,
        charge_time = self.params.charge_time,
        burst_count = self.params.burst_count,
        burst_delay = self.params.burst_delay
    }, self:isKeyDown('space'), function(charge_mult)
        self:playerShoot(charge_mult)
    end)

    -- Ammo/heat via ProjectileSystem
    self.projectile_system:updateResources(dt)
    if self:isKeyDown('r') then self.projectile_system:reload() end

    -- Sync state to player for HUD
    self.player.ammo = self.projectile_system.ammo_current
    self.player.is_reloading = self.projectile_system.is_reloading
    self.player.reload_timer = self.projectile_system.reload_timer
    self.player.heat = self.projectile_system.heat_current
    self.player.is_overheated = self.projectile_system.is_overheated
    self.player.overheat_timer = self.projectile_system.overheat_timer
end


function SpaceShooter:updateEnemies(dt)
    local PatternMovement = self.di.components.PatternMovement
    local bounds = {x = 0, y = 0, width = self.game_width, height = self.game_height}
    local game = self

    -- Update movement for standard patterns (grid/formation managed elsewhere)
    local variant_diff = self.variant and self.variant.difficulty_modifier or 1.0
    for _, enemy in ipairs(self.enemies) do
        if enemy.movement_pattern ~= 'grid' and enemy.movement_pattern ~= 'bezier' and enemy.movement_pattern ~= 'formation' then
            local base_speed = enemy.speed_override or self:getScaledValue(self.params.enemy_base_speed, {
                multipliers = {self.difficulty_modifiers.speed, self.cheats.speed_modifier or 1.0, variant_diff}
            })
            local speed = base_speed * self.params.enemy_speed_multiplier
            if enemy.is_variant_enemy and enemy.speed_multiplier then speed = speed * enemy.speed_multiplier end
            enemy.speed = speed
            enemy.direction = self.params.reverse_gravity and (-math.pi / 2) or (math.pi / 2)
            enemy.zigzag_frequency = self.params.zigzag_frequency
            enemy.zigzag_amplitude = speed * 0.5
            enemy.skip_offscreen_removal = false
            PatternMovement.update(dt, enemy, bounds)
        else
            enemy.skip_offscreen_removal = true  -- Grid/galaga manage their own removal
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
    -- Set homing targets for HOMING_NEAREST bullets
    self.projectile_system:setHomingTargets(self.enemies)

    -- Player bullets vs enemies
    local game = self
    self.projectile_system:checkCollisions(self.enemies, function(bullet, enemy)
        game.entity_controller:hitEntity(enemy, 1, bullet)
    end, "player")

    -- Enemy bullets vs player (ProjectileSystem handles bullet removal)
    self.projectile_system:checkCollisions({self.player}, function(bullet, player)
        game:takeDamage()
    end, "enemy")

    -- Screen wrap for player bullets if enabled
    if self.params.screen_wrap_bullets then
        for _, bullet in ipairs(self.player_bullets) do
            if self:applyScreenWrap(bullet, self.params.bullet_max_wraps) then
                self.projectile_system:removeProjectile(bullet)
            end
        end
    end
end

function SpaceShooter:draw()
    if self.view then
        self.view:draw()
    else
         love.graphics.print("Error: View not loaded!", 10, 100)
    end
end

function SpaceShooter:spawnEnemy()
    local p = self.params
    local spawn_y = p.reverse_gravity and self.game_height or p.enemy_start_y_offset
    local variant_diff = self.variant and self.variant.difficulty_modifier or 1.0
    local base_speed = self:getScaledValue(p.enemy_base_speed, {
        multipliers = {self.difficulty_modifiers.speed, self.cheats.speed_modifier or 1.0, variant_diff}
    })
    local speed = base_speed * p.enemy_speed_multiplier * math.sqrt(self.difficulty_scale)
    local shoot_rate = math.max(0.5, (p.enemy_shoot_rate_max - self.difficulty_modifiers.complexity * p.enemy_shoot_rate_complexity)) / p.enemy_fire_rate
    local extra = {movement_pattern = 'straight', speed_override = speed, shoot_rate = shoot_rate, health = p.enemy_health}

    -- Formation spawning
    if p.enemy_formation == "v_formation" then
        self.entity_controller:spawnLayout("enemy", "v_shape", {count = 5, center_x = self.game_width / 2, y = spawn_y, spacing_x = 60, extra = extra})
    elseif p.enemy_formation == "wall" then
        self.entity_controller:spawnLayout("enemy", "line", {count = 6, x = self.game_width / 7, y = spawn_y, spacing_x = self.game_width / 7, extra = extra})
    elseif p.enemy_formation == "spiral" then
        self.entity_controller:spawnLayout("enemy", "spiral", {count = 8, center_x = self.game_width / 2, center_y = spawn_y, radius = 100, extra = extra})
    else
        -- Single enemy spawn - use weighted configs if available (50% chance)
        local use_weighted = #self.enemy_weighted_configs > 0 and math.random() < 0.5
        local movement = self.difficulty_modifiers.complexity >= 2 and (math.random() > 0.5 and 'zigzag' or 'straight') or 'straight'
        local health_config = p.use_health_range
            and {range = {min = p.enemy_health_min, max = p.enemy_health_max}, bounds = {min = 1}}
            or {variance = p.enemy_health_variance, bounds = {min = 1}}
        local health = math.floor(self:getScaledValue(p.enemy_health, health_config) + 0.5)

        local spawn_extra = {
            width = p.enemy_width, height = p.enemy_height, movement_pattern = movement, speed_override = speed,
            shoot_timer = math.random() * (p.enemy_shoot_rate_max - p.enemy_shoot_rate_min) + p.enemy_shoot_rate_min,
            shoot_rate = shoot_rate, health = health, is_variant_enemy = use_weighted
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

function SpaceShooter:onEnemyDestroyed(enemy)
    self:handleEntityDestroyed(enemy, {
        destroyed_counter = "kills",
        scoring = {base = 10, combo_mult = 0},
        effects = {particles = false}
    })
    self:playSound("enemy_explode", 1.0)
end

function SpaceShooter:checkComplete()
    --Use VictoryCondition component
    local result = self.victory_checker:check()
    if result then
        self.victory = (result == "victory")
        self.game_over = (result == "loss")
        return true
    end
    return false
end

--Override onComplete to play success sound and stop music
function SpaceShooter:onComplete()
    --Victory determined by VictoryCondition component
    local is_win = self.victory

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

--Formation spawning
-- Space Invaders: Initialize grid
function SpaceShooter:initSpaceInvadersGrid()
    local wave_multiplier = 1.0 + (self.grid_state.wave_number * self.params.wave_difficulty_increase)
    local variance = self.params.wave_random_variance
    local random_factor = variance > 0 and (1.0 + ((math.random() - 0.5) * 2 * variance)) or 1.0

    local wave_rows = math.max(1, math.floor(self.params.grid_rows * wave_multiplier * random_factor + 0.5))
    local wave_columns = math.max(2, math.floor(self.params.grid_columns * wave_multiplier * random_factor + 0.5))
    local wave_speed = self.params.grid_speed * wave_multiplier * random_factor
    local wave_health = math.max(1, math.floor(self.params.enemy_health * wave_multiplier + 0.5))

    local spacing_x = (self.game_width / (wave_columns + 1)) * self.params.enemy_density
    local spacing_y = 50 * self.params.enemy_density

    self.entity_controller:spawnLayout("enemy", "grid", {
        rows = wave_rows, cols = wave_columns,
        x = spacing_x, y = 80,
        spacing_x = spacing_x, spacing_y = spacing_y,
        extra = {movement_pattern = 'grid', health = wave_health, wave_speed = wave_speed}
    })

    self.grid_state.initialized = true
    self.grid_state.initial_enemy_count = wave_rows * wave_columns
    self.grid_state.wave_active = true
    self.grid_state.wave_number = self.grid_state.wave_number + 1
    self.grid_state.shoot_timer = 1.0  -- Initial delay before first shot
end

-- Space Invaders: Update grid movement
function SpaceShooter:updateSpaceInvadersGrid(dt)
    -- Wave system: Check if we need to start a new wave
    if self.params.waves_enabled then
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
                self.grid_state.wave_active = false
                self.grid_state.wave_pause_timer = self.params.wave_pause_duration
                self.grid_state.initialized = false
                self.entity_controller.grid_movement_state = nil  -- Reset for next wave
            end
        else
            self.grid_state.wave_pause_timer = self.grid_state.wave_pause_timer - dt
            if self.grid_state.wave_pause_timer <= 0 then
                self:initSpaceInvadersGrid()
            end
            return
        end
    end

    -- Initialize grid if not yet done
    if not self.grid_state.initialized then
        self:initSpaceInvadersGrid()
    end

    -- Get wave-specific speed
    local base_speed = self.params.grid_speed
    for _, enemy in ipairs(self.enemies) do
        if enemy.movement_pattern == 'grid' and enemy.wave_speed then
            base_speed = enemy.wave_speed
            break
        end
    end

    -- Use EntityController behavior for grid movement
    self.entity_controller:updateBehaviors(dt, {
        grid_unit_movement = {
            speed = base_speed,
            speed_scaling = true,
            speed_scale_factor = 2,
            initial_count = self.grid_state.initial_enemy_count,
            bounds_left = 0,
            bounds_right = self.game_width,
            bounds_bottom = self.game_height + 50,
            descent = self.params.grid_descent
        }
    })

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

-- Galaga: Initialize formation positions
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

-- Galaga: Spawn enemy with entrance pattern (uses BaseGame:spawnEntity)
function SpaceShooter:spawnGalagaEnemy(formation_slot, wave_modifiers)
    wave_modifiers = wave_modifiers or {}
    local entrance_side = math.random() > 0.5 and "left" or "right"
    local start_x = entrance_side == "left" and -50 or (self.game_width + 50)

    formation_slot.occupied = true

    self:spawnEntity("enemy", {
        x = formation_slot.x,
        y = formation_slot.y,
        entrance = {
            pattern = self.params.entrance_pattern or "swoop",
            start = {x = start_x, y = -50}
        },
        extra = {
            formation_state = 'entering',
            formation_slot = formation_slot,
            health = wave_modifiers.health or self.params.enemy_health
        }
    })
end

-- Galaga: Update formation and dive mechanics
function SpaceShooter:updateGalagaFormation(dt)
    local PatternMovement = self.di.components.PatternMovement

    -- Wave system: Check if we need to start a new wave
    if self.params.waves_enabled then
        if self.galaga_state.wave_active then
            local galaga_enemies_alive = false
            for _, enemy in ipairs(self.enemies) do
                if enemy.formation_state then
                    galaga_enemies_alive = true
                    break
                end
            end

            if not galaga_enemies_alive and #self.galaga_state.formation_positions > 0 then
                self.galaga_state.wave_active = false
                self.galaga_state.wave_pause_timer = self.params.wave_pause_duration
                self.galaga_state.formation_positions = {}
            end
        else
            self.galaga_state.wave_pause_timer = self.galaga_state.wave_pause_timer - dt
            if self.galaga_state.wave_pause_timer <= 0 then
                local wave_multiplier = 1.0 + (self.galaga_state.wave_number * self.params.wave_difficulty_increase)
                local variance = self.params.wave_random_variance
                local random_factor = variance > 0 and (1.0 + ((math.random() - 0.5) * 2 * variance)) or 1.0

                self.galaga_state.wave_modifiers = {
                    health = math.max(1, math.floor(self.params.enemy_health * wave_multiplier + 0.5)),
                    dive_frequency = self.params.dive_frequency / (wave_multiplier * random_factor)
                }

                self:initGalagaFormation()
                self.galaga_state.wave_number = self.galaga_state.wave_number + 1
                self.galaga_state.spawned_count = 0
                self.galaga_state.spawn_timer = 0
                self.galaga_state.diving_count = 0
                self.galaga_state.dive_timer = 0

                local initial_count = math.min(self.params.initial_spawn_count, #self.galaga_state.formation_positions)
                for i = 1, initial_count do
                    self:spawnGalagaEnemy(self.galaga_state.formation_positions[i], self.galaga_state.wave_modifiers)
                    self.galaga_state.spawned_count = self.galaga_state.spawned_count + 1
                end
            end
            return
        end
    end

    -- Initialize formation if needed (first spawn)
    if #self.galaga_state.formation_positions == 0 then
        self:initGalagaFormation()
        self.galaga_state.spawned_count = 0
        self.galaga_state.spawn_timer = 0
        self.galaga_state.wave_modifiers = {}

        local initial_count = math.min(self.params.initial_spawn_count, #self.galaga_state.formation_positions)
        for i = 1, initial_count do
            self:spawnGalagaEnemy(self.galaga_state.formation_positions[i], self.galaga_state.wave_modifiers)
            self.galaga_state.spawned_count = self.galaga_state.spawned_count + 1
        end
    end

    -- Gradual enemy spawning
    local unoccupied_slots = {}
    for _, slot in ipairs(self.galaga_state.formation_positions) do
        if not slot.occupied then table.insert(unoccupied_slots, slot) end
    end

    if #unoccupied_slots > 0 and self.galaga_state.spawned_count < self.params.formation_size then
        self.galaga_state.spawn_timer = self.galaga_state.spawn_timer - dt
        if self.galaga_state.spawn_timer <= 0 then
            local slot = unoccupied_slots[math.random(1, #unoccupied_slots)]
            self:spawnGalagaEnemy(slot, self.galaga_state.wave_modifiers)
            self.galaga_state.spawned_count = self.galaga_state.spawned_count + 1
            self.galaga_state.spawn_timer = self.params.spawn_interval
        end
    end

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
            diver.bezier_path = PatternMovement.buildPath("dive", {
                start_x = diver.x, start_y = diver.y,
                target_x = self.player.x + self.player.width / 2,
                target_y = self.player.y + self.player.height / 2,
                exit_x = diver.x, exit_y = self.game_height + 50
            })
            self.galaga_state.diving_count = self.galaga_state.diving_count + 1
        end
        self.galaga_state.dive_timer = dive_freq
    end

    -- Update enemy states (use PatternMovement.updateBezier instead of inline math)
    for _, enemy in ipairs(self.enemies) do
        if enemy.formation_state == 'entering' then
            PatternMovement.updateBezier(dt, enemy, nil)
            if enemy.bezier_complete then
                enemy.formation_state = 'in_formation'
                enemy.x, enemy.y = enemy.home_x, enemy.home_y
                enemy.movement_pattern = 'formation'
            end

        elseif enemy.formation_state == 'in_formation' then
            enemy.x, enemy.y = enemy.home_x, enemy.home_y

        elseif enemy.formation_state == 'diving' then
            PatternMovement.updateBezier(dt, enemy, nil)
            if enemy.bezier_complete then
                self.entity_controller:removeEntity(enemy)
                self.galaga_state.diving_count = self.galaga_state.diving_count - 1
                if enemy.formation_slot then
                    enemy.formation_slot.occupied = false
                    -- Respawn with new entrance animation
                    self:spawnGalagaEnemy(enemy.formation_slot, self.galaga_state.wave_modifiers)
                end
            end
        end
    end
end

function SpaceShooter:updateWaveSpawning(dt)
    if self.wave_state.active then
        self.spawn_timer = self.spawn_timer - dt
        if self.spawn_timer <= 0 and self.wave_state.enemies_remaining > 0 then
            self:spawnEnemy()
            self.wave_state.enemies_remaining = self.wave_state.enemies_remaining - 1
            self.spawn_timer = 0.3
            if self.wave_state.enemies_remaining <= 0 then
                self.wave_state.active = false
                self.wave_state.pause_timer = self.params.wave_pause_duration
            end
        end
    else
        self.wave_state.pause_timer = self.wave_state.pause_timer - dt
        if self.wave_state.pause_timer <= 0 then
            self.wave_state.active = true
            self.wave_state.enemies_remaining = math.floor(self.params.wave_enemies_per_wave * self.difficulty_scale)
            self.spawn_timer = 0
        end
    end
end

--Hazards: Asteroids and Meteors use generic behaviors
function SpaceShooter:updateHazards(dt)
    local p = self.params
    local game = self
    local direction = p.reverse_gravity and (-math.pi / 2) or (math.pi / 2)
    local offscreen = p.reverse_gravity and {top = -100} or {bottom = self.game_height + 50}

    -- Spawn asteroids on timer
    if p.asteroid_density > 0 then
        self.asteroid_spawn_timer = self.asteroid_spawn_timer - dt
        if self.asteroid_spawn_timer <= 0 then
            local size = math.random(p.asteroid_size_min, p.asteroid_size_max)
            local spawn_y = p.reverse_gravity and self.game_height or -size
            self.entity_controller:spawn("asteroid", math.random(0, self.game_width - size), spawn_y, {
                width = size, height = size,
                movement_pattern = 'straight', speed = p.asteroid_speed, direction = direction,
                rotation = math.random() * math.pi * 2, rotation_speed = (math.random() - 0.5) * 2
            })
            self.asteroid_spawn_timer = 1.0 / p.asteroid_density
        end
    end

    -- Spawn meteor warnings on timer, convert to meteors when expired
    if p.meteor_frequency > 0 then
        self.meteor_timer = self.meteor_timer - dt
        if self.meteor_timer <= 0 then
            for i = 1, math.random(3, 5) do
                self.entity_controller:spawn("meteor_warning", math.random(0, self.game_width - 30), 0, {
                    time_remaining = p.meteor_warning_time, spawned = false
                })
            end
            self.meteor_timer = 60 / p.meteor_frequency
        end
        for _, w in ipairs(self.meteor_warnings) do
            w.time_remaining = w.time_remaining - dt
            if w.time_remaining <= 0 and not w.spawned then
                local spawn_y = p.reverse_gravity and self.game_height or -30
                self.entity_controller:spawn("meteor", w.x, spawn_y, {
                    movement_pattern = 'straight', speed = p.meteor_speed, direction = direction
                })
                w.spawned = true
                self.entity_controller:removeEntity(w)
            end
        end
    end

    -- Movement, rotation, offscreen via behaviors (works for asteroids + meteors)
    self.entity_controller:updateBehaviors(dt, {
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
    if p.asteroids_can_be_destroyed then
        self.projectile_system:checkCollisions(self.asteroids, function(_, a) game.entity_controller:removeEntity(a) end, "player")
    end
    self.projectile_system:checkCollisions(self.meteors, function(_, m) game.entity_controller:removeEntity(m) end, "player")
end

--Gravity well system
function SpaceShooter:applyGravityWells(dt)
    local PhysicsUtils = self.di.components.PhysicsUtils

    for _, well in ipairs(self.gravity_wells) do
        -- Apply to player
        PhysicsUtils.applyGravityWell(self.player, well, dt)

        -- Apply to player bullets (weaker effect)
        for _, bullet in ipairs(self.player_bullets) do
            PhysicsUtils.applyGravityWell(bullet, well, dt, 0.7)
        end
    end

    -- Keep player in bounds
    self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
    self.player.y = math.max(0, math.min(self.game_height - self.player.height, self.player.y))
end

--Screen wrap helper
-- Returns true if object should be destroyed (exceeded max wraps)
function SpaceShooter:applyScreenWrap(obj, max_wraps)
    local PhysicsUtils = self.di.components.PhysicsUtils
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

--Blackout zones movement
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