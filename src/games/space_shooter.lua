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
    -- Extra lives from advantage cheat
    local extra_deaths = (self.cheats.advantage_modifier or {}).deaths or 0
    self.params.lives_count = self.params.lives_count + extra_deaths

    self:setupArena()
    self:setupPlayer()
    self:setupComponents()
    self:setupGameState()

    self.view = SpaceShooterView:new(self, self.variant)
    self:loadAssets()
end

function SpaceShooter:setupArena()
    local cfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.space_shooter) or {}
    self.game_width = (cfg.arena and cfg.arena.width) or 800
    self.game_height = (cfg.arena and cfg.arena.height) or 600
    self.gravity_wells = {}
    self.blackout_zones = {}

    for i = 1, self.params.gravity_wells_count do
        table.insert(self.gravity_wells, {
            x = math.random(50, self.game_width - 50),
            y = math.random(50, self.game_height - 50),
            radius = self.params.gravity_well_radius,
            strength = self.params.gravity_well_strength
        })
    end

    for i = 1, self.params.blackout_zones_count do
        table.insert(self.blackout_zones, {
            x = math.random(self.params.blackout_zone_radius, self.game_width - self.params.blackout_zone_radius),
            y = math.random(self.params.blackout_zone_radius, self.game_height - self.params.blackout_zone_radius),
            radius = self.params.blackout_zone_radius,
            vx = self.params.blackout_zones_move and (math.random() - 0.5) * 50 or 0,
            vy = self.params.blackout_zones_move and (math.random() - 0.5) * 50 or 0
        })
    end
end

function SpaceShooter:setupPlayer()
    self.PLAYER_MAX_DEATHS = self.params.lives_count
    local y_offset = self.params.player_start_y_offset or 50
    local player_y = self.params.reverse_gravity and y_offset or (self.game_height - y_offset)

    self:createPlayer({
        y = player_y,
        extra = {
            fire_cooldown = 0, auto_fire_timer = 0, charge_progress = 0, is_charging = false,
            burst_remaining = 0, burst_timer = 0, ammo = self.params.ammo_capacity,
            reload_timer = 0, is_reloading = false, heat = 0, is_overheated = false, overheat_timer = 0,
            angle = 0, vx = 0, vy = 0, jump_timer = 0, is_jumping = false, jump_progress = 0,
            jump_start_x = 0, jump_start_y = 0, jump_target_x = 0, jump_target_y = 0
        }
    })
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
    self:createProjectileSystemFromSchema({pooling = true, max_projectiles = 500})

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

function SpaceShooter:setupGameState()
    local variant_difficulty = self.variant and self.variant.difficulty_modifier or 1.0
    local speed_modifier = self.cheats.speed_modifier or 1.0
    local base_speed = self.params.enemy_base_speed or 100
    local base_rate = self.params.spawn_base_rate or 1.0

    -- Entity collections are synced from components every frame in updateGameLogic
    self.survival_time, self.scroll_offset, self.difficulty_scale = 0, 0, 1.0
    self.spawn_timer, self.asteroid_spawn_timer = 0, 0
    self.meteor_timer = self.params.meteor_frequency > 0 and (60 / self.params.meteor_frequency) or 0
    self.kills, self.deaths = 0, 0

    self.enemy_speed = ((base_speed * self.difficulty_modifiers.speed) * speed_modifier) * variant_difficulty
    self.spawn_rate = (base_rate / self.difficulty_modifiers.count) / variant_difficulty
    self.can_shoot_back = self.difficulty_modifiers.complexity > 2
    self.target_kills = self.params.victory_limit or 20

    -- Build enemy composition from variant
    self.enemy_composition = {}
    if self.variant and self.variant.enemies then
        for _, ed in ipairs(self.variant.enemies) do
            self.enemy_composition[ed.type] = ed.multiplier
        end
    end
end

-- Lazy initialization for mode-specific state
function SpaceShooter:getWaveState()
    if not self.wave_state then
        self.wave_state = {
            active = false, enemies_remaining = 0, pause_timer = 0,
            enemies_per_wave = self.params.wave_enemies_per_wave,
            pause_duration = self.params.wave_pause_duration
        }
    end
    return self.wave_state
end

function SpaceShooter:getGridState()
    if not self.grid_state then
        self.grid_state = {
            x = 0, y = 50, direction = 1, speed_multiplier = 1.0,
            initialized = false, wave_active = false, wave_pause_timer = 0,
            initial_enemy_count = 0, wave_number = 0
        }
    end
    return self.grid_state
end

function SpaceShooter:getGalagaState()
    if not self.galaga_state then
        self.galaga_state = {
            formation_positions = {}, dive_timer = self.params.dive_frequency,
            diving_count = 0, entrance_queue = {}, wave_active = false,
            wave_pause_timer = 0, initial_enemy_count = 0, wave_number = 0,
            spawn_timer = 0.0, spawned_count = 0, wave_modifiers = {}
        }
    end
    return self.galaga_state
end

--Asset loading using spriteSetLoader
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
        local y_offset = self.params.player_start_y_offset or 50
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
    --Update health system (shield regeneration)
    self.health_system:update(dt)

    --Update EntityController (enemies, asteroids, powerups)
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
            -- Apply spawn rate multiplier and difficulty scaling
            local adjusted_spawn_rate = self.spawn_rate / (self.params.enemy_spawn_rate_multiplier * self.difficulty_scale)
            self.spawn_timer = self.spawn_timer - dt
            if self.spawn_timer <= 0 then
                self:spawnEnemy()
                self.spawn_timer = adjusted_spawn_rate
            end
        elseif self.params.enemy_spawn_pattern == "clusters" then
            self.spawn_timer = self.spawn_timer - dt
            if self.spawn_timer <= 0 then
                -- Spawn a cluster of 3-5 enemies
                local cluster_size = math.random(3, 5)
                for i = 1, cluster_size do
                    self:spawnEnemy()
                end
                self.spawn_timer = (self.spawn_rate * 2) / self.params.enemy_spawn_rate_multiplier  -- Longer delay between clusters
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

    --Environmental hazards
    if self.params.asteroid_density > 0 then
        self:updateAsteroids(dt)
    end
    if self.params.meteor_frequency > 0 then
        self:updateMeteors(dt)
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

    -- Ammo reload system
    if self.params.ammo_enabled then
        if self.player.is_reloading and (self.player.reload_timer - dt) <= 0 then
            self.player.is_reloading, self.player.ammo = false, self.params.ammo_capacity
        elseif self.player.is_reloading then
            self.player.reload_timer = self.player.reload_timer - dt
        elseif self:isKeyDown('r') and self.player.ammo < self.params.ammo_capacity then
            self.player.is_reloading, self.player.reload_timer = true, self.params.ammo_reload_time
        end
    end

    -- Overheat cooldown system
    if self.params.overheat_enabled then
        if self.player.is_overheated and (self.player.overheat_timer - dt) <= 0 then
            self.player.is_overheated, self.player.heat = false, 0
        elseif self.player.is_overheated then
            self.player.overheat_timer = self.player.overheat_timer - dt
        elseif self.player.heat > 0 then
            self.player.heat = math.max(0, self.player.heat - dt * self.params.overheat_heat_dissipation)
        end
    end
end


function SpaceShooter:updateEnemies(dt)
    local PatternMovement = self.di.components.PatternMovement
    local bounds = {x = 0, y = 0, width = self.game_width, height = self.game_height}
    local game = self

    -- Update movement for standard patterns (grid/formation managed elsewhere)
    for _, enemy in ipairs(self.enemies) do
        if enemy.movement_pattern ~= 'grid' and enemy.movement_pattern ~= 'bezier' and enemy.movement_pattern ~= 'formation' then
            local speed = (enemy.speed_override or self.enemy_speed) * self.params.enemy_speed_multiplier
            if enemy.is_variant_enemy and enemy.speed_multiplier then speed = speed * enemy.speed_multiplier end
            enemy.speed = speed
            enemy.direction = self.params.reverse_gravity and (-math.pi / 2) or (math.pi / 2)
            enemy.zigzag_frequency = self.params.zigzag_frequency or 2
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
            game:handlePlayerDamage()
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
        shooting_enabled = self.params.enemy_bullets_enabled or self.can_shoot_back,
        on_shoot = function(enemy) game:enemyShoot(enemy) end,
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
        game:handlePlayerDamage()
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

function SpaceShooter:playerShoot(charge_multiplier)
    charge_multiplier = charge_multiplier or 1.0

    --Ammo system check
    if self.params.ammo_enabled then
        if self.player.is_reloading then
            return -- Can't shoot while reloading
        end

        if self.player.ammo <= 0 then
            -- Auto-reload when empty
            self.player.is_reloading = true
            self.player.reload_timer = self.params.ammo_reload_time
            return
        end

        -- Consume ammo
        self.player.ammo = self.player.ammo - 1
    end

    --Overheat system check
    if self.params.overheat_enabled then
        if self.player.is_overheated then
            return -- Can't shoot while overheated
        end

        -- Increase heat
        self.player.heat = self.player.heat + 1

        -- Check for overheat
        if self.player.heat >= self.params.overheat_threshold then
            self.player.is_overheated = true
            self.player.overheat_timer = self.params.overheat_cooldown
            self.player.heat = self.params.overheat_threshold
        end
    end

    --Bullet pattern - calculate base angle and spawn position, then use shootPattern
    local base_angle = self.params.movement_type == "asteroids" and self.player.angle or 0
    local spawn_x, spawn_y = self:getBulletSpawnPosition(base_angle)
    local standard_angle = self:convertToStandardAngle(base_angle)

    local pattern = self.params.bullet_pattern or "single"
    local config = {
        speed_multiplier = charge_multiplier,
        count = self.params.bullets_per_shot or 5,
        arc = self.params.bullet_arc or 60,
        spread = 15,
        offset = 5,
        time = love.timer.getTime(),
        custom = {
            width = self.params.bullet_width or 4,
            height = self.params.bullet_height or 8,
            piercing = self.params.bullet_piercing,
            movement_type = (self.params.bullet_homing and self.params.homing_strength > 0) and "homing_nearest" or nil,
            homing_turn_rate = self.params.homing_strength
        }
    }

    self.projectile_system:shootPattern("player_bullet", spawn_x, spawn_y, standard_angle, pattern, config)

    --Play shoot sound
    self:playSound("shoot", 0.6)
end

function SpaceShooter:getBulletSpawnPosition(angle)
    -- Player uses corner-based coords, calculate center
    local center_x = self.player.x + self.player.width / 2
    local center_y = self.player.y + self.player.height / 2
    local rad = math.rad(angle)
    if self.params.movement_type == "asteroids" then
        local offset_distance = self.player.height / 2
        return center_x + math.sin(rad) * offset_distance,
               center_y - math.cos(rad) * offset_distance
    else
        local spawn_y = self.params.reverse_gravity
            and (self.player.y + self.player.height)
            or self.player.y
        return center_x, spawn_y
    end
end

function SpaceShooter:convertToStandardAngle(angle)
    local rad = math.rad(angle)
    local direction_multiplier = self.params.reverse_gravity and 1 or -1
    return math.atan2(math.cos(rad) * direction_multiplier, math.sin(rad))
end

function SpaceShooter:enemyShoot(enemy)
    local center_x = enemy.x + enemy.width/2
    local center_y = enemy.y + enemy.height
    local base_angle = self.params.reverse_gravity and (-math.pi / 2) or (math.pi / 2)
    local enemy_bullet_size = 8

    local pattern = self.params.enemy_bullet_pattern or "single"
    local config = {
        count = self.params.enemy_bullets_per_shot or 3,
        arc = self.params.enemy_bullet_spread_angle or 45,
        custom = {
            width = enemy_bullet_size,
            height = enemy_bullet_size,
            speed = self.params.enemy_bullet_speed
        }
    }

    self.projectile_system:shootPattern("enemy_bullet", center_x, center_y, base_angle, pattern, config)
end

-- Calculate enemy health with variance/range support
function SpaceShooter:calculateEnemyHealth(base_health, enemy_type_health_multiplier)
    base_health = base_health or self.params.enemy_health
    enemy_type_health_multiplier = enemy_type_health_multiplier or 1

    local final_health

    if self.use_health_range then
        -- Use random range (min to max)
        final_health = math.random(self.params.enemy_health_min, self.params.enemy_health_max)
    else
        -- Use base health with optional variance
        if self.params.enemy_health_variance > 0 then
            local variance_factor = 1.0 + ((math.random() - 0.5) * 2 * self.params.enemy_health_variance)
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
    --Check if variant has enemy composition
    if self:hasVariantEnemies() and math.random() < 0.5 then
        -- 50% chance to spawn variant-specific enemy
        return self:spawnVariantEnemy()
    end

    --Formation-based spawning
    if self.params.enemy_formation == "v_formation" then
        return self:spawnFormation("v")
    elseif self.params.enemy_formation == "wall" then
        return self:spawnFormation("wall")
    elseif self.params.enemy_formation == "spiral" then
        return self:spawnFormation("spiral")
    end

    -- Default enemy spawning (scattered)
    local movement = 'straight'
    if self.difficulty_modifiers.complexity >= 2 then
        movement = math.random() > 0.5 and 'zigzag' or 'straight'
    end

    --Apply speed multiplier and difficulty scaling
    local adjusted_speed = self.enemy_speed * self.params.enemy_speed_multiplier * math.sqrt(self.difficulty_scale)

    --Reverse gravity - spawn at bottom, move up (direction change in updateEnemies handles movement)
    local spawn_y = self.params.reverse_gravity and self.game_height or (self.params.enemy_start_y_offset or -30)

    --Spawn via EntityController
    self.entity_controller:spawn("enemy",
        math.random(0, self.game_width - (self.params.enemy_width or 30)),
        spawn_y,
        {
            width = (self.params.enemy_width or 30),
            height = (self.params.enemy_height or 30),
            movement_pattern = movement,
            speed_override = adjusted_speed,  -- Direction handled by enemy.direction in updateEnemies
            shoot_timer = math.random() * ((self.params.enemy_shoot_rate_max or 3.0) - (self.params.enemy_shoot_rate_min or 1.0)) + (self.params.enemy_shoot_rate_min or 1.0),
            shoot_rate = math.max(0.5, ((self.params.enemy_shoot_rate_max or 3.0) - self.difficulty_modifiers.complexity * (self.params.enemy_shoot_rate_complexity or 0.5))) / self.params.enemy_fire_rate,
            health = self:calculateEnemyHealth()
        }
    )
end

--Check if variant has enemies defined
function SpaceShooter:hasVariantEnemies()
    return self.enemy_composition and next(self.enemy_composition) ~= nil
end

--Spawn an enemy from variant composition
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

    local enemy_def = self.params.enemy_types[chosen_type]
    if not enemy_def then
        return self:spawnEnemy()
    end

    local spawn_y = self.params.reverse_gravity and self.game_height or (self.params.enemy_start_y_offset or -30)
    local enemy_type_multiplier = enemy_def.health or 1
    local final_health = self:calculateEnemyHealth(nil, enemy_type_multiplier)

    local base_rate = math.random() * ((self.params.enemy_shoot_rate_max or 3.0) - (self.params.enemy_shoot_rate_min or 1.0)) + (self.params.enemy_shoot_rate_min or 1.0)
    local shoot_rate = (math.max(0.5, ((self.params.enemy_shoot_rate_max or 3.0) - self.difficulty_modifiers.complexity * (self.params.enemy_shoot_rate_complexity or 0.5)))) / (enemy_def.shoot_rate_multiplier or 1.0)

    local extra = {
        movement_pattern = enemy_def.movement_pattern,
        enemy_type = enemy_def.name,
        type = chosen_type,
        is_variant_enemy = true,
        health = final_health,
        max_health = final_health,
        speed_multiplier = enemy_def.speed_multiplier or 1.0,  -- Direction handled by enemy.direction
        shoot_rate_multiplier = enemy_def.shoot_rate_multiplier or 1.0,
        shoot_timer = base_rate,
        shoot_rate = shoot_rate
    }

    -- Special initialization for dive pattern (kamikaze)
    if enemy_def.movement_pattern == 'dive' then
        extra.target_x = self.player.x + self.player.width / 2
        extra.target_y = self.player.y + self.player.height / 2
    end

    self.entity_controller:spawn("enemy",
        math.random(0, self.game_width - (self.params.enemy_width or 30)),
        spawn_y,
        extra
    )
end

function SpaceShooter:handlePlayerDamage()
    -- Use health_system for shield absorption
    local absorbed = self.health_system:takeDamage(1)
    self:playSound("hit", 1.0)

    if absorbed then
        return true  -- Shield absorbed damage
    else
        -- Shield was down or disabled, take real damage
        self.deaths = self.deaths + 1
        self.lives = self.lives - 1  -- Update for HUD display
        self.combo = 0
        return false
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
function SpaceShooter:spawnFormation(formation_type)
    local adjusted_speed = self.enemy_speed * self.params.enemy_speed_multiplier * math.sqrt(self.difficulty_scale)
    local base_shoot_rate = math.max(0.5, ((self.params.enemy_shoot_rate_max or 3.0) - self.difficulty_modifiers.complexity * (self.params.enemy_shoot_rate_complexity or 0.5))) / self.params.enemy_fire_rate

    local spawn_y_base = self.params.reverse_gravity and self.game_height or (self.params.enemy_start_y_offset or -30)

    local function spawnEnemy(x, y, shoot_timer)
        self.entity_controller:spawn("enemy", x, y, {
            movement_pattern = 'straight',
            speed_override = adjusted_speed,  -- Direction handled by enemy.direction in updateEnemies
            shoot_timer = shoot_timer,
            shoot_rate = base_shoot_rate,
            health = self.params.enemy_health
        })
    end

    if formation_type == "v" then
        local center_x = self.game_width / 2
        local spacing = 60
        for i = 1, 5 do
            local offset = (i - 3) * spacing
            local y_offset = math.abs(offset) * 0.5
            local spawn_y = self.params.reverse_gravity and (spawn_y_base + y_offset) or (spawn_y_base - y_offset)
            spawnEnemy(center_x + offset - (self.params.enemy_width or 30)/2, spawn_y, math.random() * 2.0)
        end
    elseif formation_type == "wall" then
        local num_enemies = 6
        local spacing = self.game_width / (num_enemies + 1)
        for i = 1, num_enemies do
            spawnEnemy(spacing * i - (self.params.enemy_width or 30)/2, spawn_y_base, i * 0.2)
        end
    elseif formation_type == "spiral" then
        local num_enemies = 8
        local center_x = self.game_width / 2
        local radius = 100
        for i = 1, num_enemies do
            local angle = (i / num_enemies) * math.pi * 2
            local y_offset = math.sin(angle) * radius * 0.3
            spawnEnemy(center_x + math.cos(angle) * radius - (self.params.enemy_width or 30)/2, spawn_y_base + y_offset, i * 0.15)
        end
    end
end

-- Space Invaders: Initialize grid
function SpaceShooter:initSpaceInvadersGrid()
    self:getGridState()  -- Lazy init
    local wave_multiplier = 1.0 + (self.grid_state.wave_number * self.params.wave_difficulty_increase)
    local variance = self.params.wave_random_variance
    local random_factor = variance > 0 and (1.0 + ((math.random() - 0.5) * 2 * variance)) or 1.0

    local wave_rows = math.max(1, math.floor(self.params.grid_rows * wave_multiplier * random_factor + 0.5))
    local wave_columns = math.max(2, math.floor(self.params.grid_columns * wave_multiplier * random_factor + 0.5))
    local wave_speed = self.params.grid_speed * wave_multiplier * random_factor
    local wave_health = math.max(1, math.floor(self.params.enemy_health * wave_multiplier + 0.5))

    local spacing_x = (self.game_width / (wave_columns + 1)) * self.params.enemy_density
    local spacing_y = 50 * self.params.enemy_density
    local start_y = 80

    for row = 1, wave_rows do
        for col = 1, wave_columns do
            self.entity_controller:spawn("enemy", spacing_x * col, start_y + (row - 1) * spacing_y, {
                movement_pattern = 'grid',
                grid_row = row,
                grid_col = col,
                health = wave_health,
                wave_speed = wave_speed
            })
        end
    end

    self.grid_state.initialized = true
    self.grid_state.initial_enemy_count = wave_rows * wave_columns
    self.grid_state.wave_active = true
    self.grid_state.wave_number = self.grid_state.wave_number + 1
    self.grid_state.shoot_timer = 1.0  -- Initial delay before first shot
end

-- Space Invaders: Update grid movement
function SpaceShooter:updateSpaceInvadersGrid(dt)
    self:getGridState()  -- Lazy init
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
                self:enemyShoot(shooter)
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
    self:getGalagaState()  -- Lazy init
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

-- Galaga: Spawn enemy with entrance pattern
function SpaceShooter:spawnGalagaEnemy(formation_slot, wave_modifiers)
    wave_modifiers = wave_modifiers or {}
    local wave_health = wave_modifiers.health or self.params.enemy_health

    local entrance_side = math.random() > 0.5 and "left" or "right"
    local start_x = entrance_side == "left" and -50 or (self.game_width + 50)
    local start_y = -50

    -- Build entrance path based on entrance_pattern param
    local bezier_path
    if self.params.entrance_pattern == "swoop" then
        bezier_path = {
            {x = start_x, y = start_y},
            {x = self.game_width / 2, y = self.game_height * 0.6},
            {x = formation_slot.x, y = formation_slot.y}
        }
    elseif self.params.entrance_pattern == "loop" then
        local mid_x = entrance_side == "left" and self.game_width * 0.3 or self.game_width * 0.7
        bezier_path = {
            {x = start_x, y = start_y},
            {x = mid_x, y = self.game_height * 0.5},
            {x = formation_slot.x, y = formation_slot.y}
        }
    else
        bezier_path = {
            {x = start_x, y = start_y},
            {x = (start_x + formation_slot.x) / 2, y = self.game_height * 0.3},
            {x = formation_slot.x, y = formation_slot.y}
        }
    end

    formation_slot.occupied = true

    self.entity_controller:spawn("enemy", start_x, start_y, {
        movement_pattern = 'bezier',
        formation_state = 'entering',
        formation_slot = formation_slot,
        home_x = formation_slot.x,
        home_y = formation_slot.y,
        bezier_path = bezier_path,
        bezier_t = 0,
        bezier_duration = 2.0,
        bezier_complete = false,
        health = wave_health
    })
end

-- Galaga: Update formation and dive mechanics
function SpaceShooter:updateGalagaFormation(dt)
    self:getGalagaState()  -- Lazy init
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
            diver.bezier_path = {
                {x = diver.x, y = diver.y},
                {x = self.player.x + self.player.width / 2, y = self.player.y + self.player.height / 2},
                {x = diver.x, y = self.game_height + 50}
            }
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

--Wave spawning logic
function SpaceShooter:updateWaveSpawning(dt)
    self:getWaveState()  -- Lazy init
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

--Difficulty scaling
function SpaceShooter:updateDifficulty(dt)
    local scaling_factor = self.params.difficulty_scaling_rate * dt

    if self.params.difficulty_curve == "linear" then
        -- Steady linear increase
        self.difficulty_scale = self.difficulty_scale + scaling_factor
    elseif self.params.difficulty_curve == "exponential" then
        -- Exponential growth (multiplicative)
        self.difficulty_scale = self.difficulty_scale * (1 + scaling_factor)
    elseif self.params.difficulty_curve == "wave" then
        -- Sine wave difficulty (alternating hard/easy)
        local time_factor = self.time_elapsed * 0.5
        self.difficulty_scale = 1.0 + math.sin(time_factor) * 0.5
    end

    -- Cap difficulty scale to reasonable values
    self.difficulty_scale = math.min(self.difficulty_scale, 5.0)
end

--Asteroid system
function SpaceShooter:updateAsteroids(dt)
    -- Spawn asteroids based on density
    self.asteroid_spawn_timer = self.asteroid_spawn_timer - dt
    local spawn_interval = 1.0 / self.params.asteroid_density
    if self.asteroid_spawn_timer <= 0 then
        self:spawnAsteroid()
        self.asteroid_spawn_timer = spawn_interval
    end

    local speed_direction = self.params.reverse_gravity and -1 or 1
    local speed = (self.params.asteroid_speed + self.params.scroll_speed) * speed_direction
    local game = self

    -- Update movement and check off-screen
    for _, asteroid in ipairs(self.asteroids) do
        asteroid.y = asteroid.y + speed * dt
        asteroid.rotation = asteroid.rotation + asteroid.rotation_speed * dt

        local off_screen = self.params.reverse_gravity and (asteroid.y + asteroid.height < 0) or (asteroid.y > self.game_height + asteroid.height)
        if off_screen then
            self.entity_controller:removeEntity(asteroid)
        end
    end

    -- Asteroid vs player collision
    self.entity_controller:checkCollision(self.player, function(entity)
        if entity.type_name == "asteroid" then
            game:handlePlayerDamage()
            game.entity_controller:removeEntity(entity)
        end
    end)

    -- Asteroid vs player bullets (if destroyable)
    if self.params.asteroids_can_be_destroyed then
        self.projectile_system:checkCollisions(self.asteroids, function(bullet, asteroid)
            game.entity_controller:removeEntity(asteroid)
        end, "player")
    end

    -- Asteroid vs enemies
    for _, asteroid in ipairs(self.asteroids) do
        if asteroid.active then
            for _, enemy in ipairs(self.enemies) do
                if enemy.active and self.di.components.Collision.checkAABB(
                    asteroid.x, asteroid.y, asteroid.width, asteroid.height,
                    enemy.x, enemy.y, enemy.width, enemy.height
                ) then
                    self.entity_controller:removeEntity(enemy)
                    self.entity_controller:removeEntity(asteroid)
                    break
                end
            end
        end
    end
end

function SpaceShooter:spawnAsteroid()
    local size = math.random(self.params.asteroid_size_min, self.params.asteroid_size_max)
    local spawn_y = self.params.reverse_gravity and self.game_height or -size
    self.entity_controller:spawn("asteroid", math.random(0, self.game_width - size), spawn_y, {
        width = size,
        height = size,
        rotation = math.random() * math.pi * 2,
        rotation_speed = (math.random() - 0.5) * 2
    })
end

--Meteor shower system
function SpaceShooter:updateMeteors(dt)
    self.meteor_timer = self.meteor_timer - dt
    if self.meteor_timer <= 0 then
        self:spawnMeteorWave()
        self.meteor_timer = 60 / self.params.meteor_frequency
    end

    -- Update warnings and spawn meteors when ready
    for _, warning in ipairs(self.meteor_warnings) do
        warning.time_remaining = warning.time_remaining - dt
        if warning.time_remaining <= 0 and not warning.spawned then
            local spawn_y = self.params.reverse_gravity and self.game_height or -30
            self.entity_controller:spawn("meteor", warning.x, spawn_y, {
                speed = self.params.meteor_speed
            })
            warning.spawned = true
            self.entity_controller:removeEntity(warning)
        end
    end

    local speed_direction = self.params.reverse_gravity and -1 or 1
    local game = self

    -- Update movement and check off-screen
    for _, meteor in ipairs(self.meteors) do
        meteor.y = meteor.y + (meteor.speed + self.params.scroll_speed) * speed_direction * dt

        local off_screen = self.params.reverse_gravity and (meteor.y + meteor.height < 0) or (meteor.y > self.game_height + meteor.height)
        if off_screen then
            self.entity_controller:removeEntity(meteor)
        end
    end

    -- Meteor vs player collision
    self.entity_controller:checkCollision(self.player, function(entity)
        if entity.type_name == "meteor" then
            game:handlePlayerDamage()
            game.entity_controller:removeEntity(entity)
        end
    end)

    -- Meteor vs player bullets
    self.projectile_system:checkCollisions(self.meteors, function(bullet, meteor)
        game.entity_controller:removeEntity(meteor)
    end, "player")
end

function SpaceShooter:spawnMeteorWave()
    local count = math.random(3, 5)
    for i = 1, count do
        self.entity_controller:spawn("meteor_warning", math.random(0, self.game_width - 30), 0, {
            time_remaining = self.params.meteor_warning_time,
            spawned = false
        })
    end
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

--Vertical scrolling
function SpaceShooter:updateScrolling(dt)
    self.scroll_offset = self.scroll_offset + self.params.scroll_speed * dt

    -- Scroll effect already applied in enemy/asteroid movement
    -- This function can be extended for visual background scrolling
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