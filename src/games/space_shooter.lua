local BaseGame = require('src.games.base_game')
local SpaceShooterView = require('src.games.views.space_shooter_view')
local SpaceShooter = BaseGame:extend('SpaceShooter')

function SpaceShooter:init(game_data, cheats, di, variant_override)
    SpaceShooter.super.init(self, game_data, cheats, di, variant_override)

    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.space_shooter)
    self.params = self.di.components.SchemaLoader.load(self.variant, "space_shooter_schema", runtimeCfg)

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
    -- Apply cheat modifier to lives_count before components use it
    local extra_deaths = (self.cheats.advantage_modifier or {}).deaths or 0
    self.params.lives_count = self.params.lives_count + extra_deaths
    self.PLAYER_MAX_DEATHS = self.params.lives_count

    local y_offset = self.params.player_start_y_offset or 50
    local player_y = self.params.reverse_gravity and y_offset or (self.game_height - y_offset)

    -- Create player using BaseGame helper
    self:createPlayer({
        y = player_y,
        extra = {
            fire_cooldown = 0, auto_fire_timer = 0,
            charge_progress = 0, is_charging = false,
            burst_remaining = 0, burst_timer = 0,
            ammo = self.params.ammo_capacity, reload_timer = 0, is_reloading = false,
            heat = 0, is_overheated = false, overheat_timer = 0,
            shield_active = self.params.shield or false,
            shield_regen_timer = 0,
            shield_hits_remaining = self.params.shield_hits or 0
        }
    })

    -- Movement-specific state
    local mt = self.params.movement_type
    if mt == "asteroids" then
        self.player.angle, self.player.vx, self.player.vy = 0, 0, 0
    elseif mt == "jump" then
        self.player.jump_timer, self.player.is_jumping, self.player.jump_progress = 0, false, 0
        self.player.jump_start_x, self.player.jump_start_y = 0, 0
        self.player.jump_target_x, self.player.jump_target_y = 0, 0
    end
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

    -- Powerup system from schema
    self:createPowerupSystemFromSchema({reverse_gravity = p.reverse_gravity})
end

function SpaceShooter:setupGameState()
    local variant_difficulty = self.variant and self.variant.difficulty_modifier or 1.0
    local speed_modifier = self.cheats.speed_modifier or 1.0
    local base_speed = self.params.enemy_base_speed or 100
    local base_rate = self.params.spawn_base_rate or 1.0

    self.enemies = {}
    self.player_bullets = {}
    self.enemy_bullets = {}
    self.powerups = {}
    self.active_powerups = {}
    self.asteroids = {}
    self.asteroid_spawn_timer = 0
    self.meteors = {}
    self.meteor_warnings = {}
    self.meteor_timer = self.params.meteor_frequency > 0 and (60 / self.params.meteor_frequency) or 0
    self.scroll_offset = 0
    self.survival_time = 0
    self.difficulty_scale = 1.0

    self.enemy_speed = ((base_speed * self.difficulty_modifiers.speed) * speed_modifier) * variant_difficulty
    self.spawn_rate = (base_rate / self.difficulty_modifiers.count) / variant_difficulty
    self.spawn_timer = 0
    self.can_shoot_back = self.difficulty_modifiers.complexity > 2
    self.target_kills = self.params.victory_limit or 20

    self.enemy_composition = {}
    if self.variant and self.variant.enemies then
        for _, ed in ipairs(self.variant.enemies) do
            self.enemy_composition[ed.type] = ed.multiplier
        end
    end

    self.kills = 0
    self.deaths = 0

    self.wave_state = {
        active = false, enemies_remaining = 0, pause_timer = 0,
        enemies_per_wave = self.params.wave_enemies_per_wave,
        pause_duration = self.params.wave_pause_duration
    }

    self.grid_state = {
        x = 0, y = 50, direction = 1, speed_multiplier = 1.0,
        initialized = false, wave_active = false, wave_pause_timer = 0,
        initial_enemy_count = 0, wave_number = 0
    }

    self.galaga_state = {
        formation_positions = {}, dive_timer = self.params.dive_frequency,
        diving_count = 0, entrance_queue = {}, wave_active = false,
        wave_pause_timer = 0, initial_enemy_count = 0, wave_number = 0,
        spawn_timer = 0.0, spawned_count = 0, wave_modifiers = {}
    }
end

--Asset loading with fallback
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
    for enemy_type, _ in pairs(self.params.enemy_types) do
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

    --Load audio - using BaseGame helper
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
        local y_offset = self.params.player_start_y_offset or 50
        self.player.y = self.params.reverse_gravity and y_offset or (self.game_height - y_offset)
        print("[SpaceShooter] Play area updated to:", width, height)
    else
        print("[SpaceShooter] setPlayArea called before init completed")
    end

    -- Recalculate Galaga formation if using Galaga behavior
    if self.params.enemy_behavior == "galaga" and #self.galaga_state.formation_positions > 0 then
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
    --Movement type system (using MovementController)
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
        wrap_x = self.params.screen_wrap,
        wrap_y = self.params.screen_wrap
    }

    -- Add time_elapsed for jump mode cooldown tracking
    if not self.player.time_elapsed then
        self.player.time_elapsed = 0
    end
    self.player.time_elapsed = self.player.time_elapsed + dt

    -- Update movement via MovementController
    self.movement_controller:update(dt, self.player, input, bounds)

    -- Shield regeneration
    if self.params.shield and self.player.shield_hits_remaining < self.params.shield_hits then
        self.player.shield_regen_timer = self.player.shield_regen_timer + dt
        if self.player.shield_regen_timer >= self.params.shield_regen_time then
            self.player.shield_hits_remaining = self.player.shield_hits_remaining + 1
            self.player.shield_regen_timer = 0
            -- Reactivate shield if it was down
            if not self.player.shield_active then
                self.player.shield_active = true
            end
        end
    end

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

    --Ammo reload system
    if self.params.ammo_enabled then
        if self.player.is_reloading then
            self.player.reload_timer = self.player.reload_timer - dt
            if self.player.reload_timer <= 0 then
                self.player.is_reloading = false
                self.player.ammo = self.params.ammo_capacity
            end
        end

        -- Check for manual reload (R key)
        if self:isKeyDown('r') and not self.player.is_reloading and self.player.ammo < self.params.ammo_capacity then
            self.player.is_reloading = true
            self.player.reload_timer = self.params.ammo_reload_time
        end
    end

    --Overheat cooldown system
    if self.params.overheat_enabled then
        if self.player.is_overheated then
            self.player.overheat_timer = self.player.overheat_timer - dt
            if self.player.overheat_timer <= 0 then
                self.player.is_overheated = false
                self.player.heat = 0
            end
        else
            -- Passive heat dissipation when not shooting
            if self.player.heat > 0 then
                self.player.heat = math.max(0, self.player.heat - dt * self.params.overheat_heat_dissipation)
            end
        end
    end
end


function SpaceShooter:updateEnemies(dt)
    local PatternMovement = self.di.components.PatternMovement
    local bounds = {x = 0, y = 0, width = self.game_width, height = self.game_height}

    for _, enemy in ipairs(self.enemies) do
        -- Handle movement (skip special behaviors managed elsewhere)
        if enemy.movement_pattern ~= 'grid' and enemy.movement_pattern ~= 'galaga_entering' and enemy.movement_pattern ~= 'formation' then
            -- Calculate effective speed
            local speed = enemy.speed_override or self.enemy_speed
            if enemy.is_variant_enemy and enemy.speed_multiplier then
                speed = speed * enemy.speed_multiplier
            end
            speed = speed * self.params.enemy_speed_multiplier

            -- Set up pattern properties
            enemy.speed = speed
            enemy.direction = self.params.reverse_gravity and (-math.pi / 2) or (math.pi / 2)
            enemy.zigzag_frequency = self.params.zigzag_frequency or 2
            enemy.zigzag_amplitude = speed * 0.5

            -- Use PatternMovement for standard patterns
            PatternMovement.update(dt, enemy, bounds)
        end

        -- Check collision with player
        if self:checkCollision(enemy, self.player) then
            self:handlePlayerDamage()
            self.entity_controller:removeEntity(enemy)
        elseif self.params.enemy_bullets_enabled or (self.can_shoot_back and (enemy.shoot_rate_multiplier or 1.0) > 0) then
            enemy.shoot_timer = enemy.shoot_timer - dt
            if enemy.shoot_timer <= 0 then
                self:enemyShoot(enemy)
                enemy.shoot_timer = enemy.shoot_rate
            end
        end

        -- Remove off-screen enemies (skip special behaviors)
        if enemy.movement_pattern ~= 'grid' and enemy.movement_pattern ~= 'galaga_entering' and enemy.movement_pattern ~= 'formation' then
            local off_screen = self.params.reverse_gravity and (enemy.y + enemy.height < 0) or (enemy.y > self.game_height)
            if off_screen then
                self.entity_controller:removeEntity(enemy)
            end
        end
    end
end

function SpaceShooter:updateBullets(dt)
    -- Set homing targets for HOMING_NEAREST bullets
    self.projectile_system:setHomingTargets(self.enemies)

    -- Player bullets vs enemies
    local game = self
    self.projectile_system:checkCollisions(self.enemies, function(bullet, enemy)
        game.entity_controller:hitEntity(enemy, 1, bullet)
    end, "player")

    -- Enemy bullets vs player
    for _, bullet in ipairs(self.enemy_bullets) do
        if self:checkCollision(bullet, self.player) then
            self.projectile_system:removeProjectile(bullet)
            self:handlePlayerDamage()
        end
    end

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
    local rad = math.rad(angle)
    if self.params.movement_type == "asteroids" then
        local offset_distance = self.player.height / 2
        return self.player.x + math.sin(rad) * offset_distance,
               self.player.y - math.cos(rad) * offset_distance
    else
        local spawn_y = self.params.reverse_gravity
            and (self.player.y + self.player.height/2)
            or (self.player.y - self.player.height/2)
        return self.player.x, spawn_y
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

    --Reverse gravity - spawn at bottom, move up
    local spawn_y = self.params.reverse_gravity and self.game_height or (self.params.enemy_start_y_offset or -30)
    local speed_direction = self.params.reverse_gravity and -1 or 1

    --Spawn via EntityController
    self.entity_controller:spawn("enemy",
        math.random(0, self.game_width - (self.params.enemy_width or 30)),
        spawn_y,
        {
            width = (self.params.enemy_width or 30),
            height = (self.params.enemy_height or 30),
            movement_pattern = movement,
            speed_override = adjusted_speed * speed_direction,  --Reverse direction if needed
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
    local speed_multiplier = self.params.reverse_gravity and -1 or 1
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
        speed_multiplier = (enemy_def.speed_multiplier or 1.0) * speed_multiplier,
        shoot_rate_multiplier = enemy_def.shoot_rate_multiplier or 1.0,
        shoot_timer = base_rate,
        shoot_rate = shoot_rate
    }

    -- Special initialization for dive pattern (kamikaze)
    if enemy_def.movement_pattern == 'dive' then
        extra.target_x = self.player.x
        extra.target_y = self.player.y
    end

    self.entity_controller:spawn("enemy",
        math.random(0, self.game_width - (self.params.enemy_width or 30)),
        spawn_y,
        extra
    )
end

function SpaceShooter:checkCollision(a, b)
    if not a or not b then return false end
    return self.di.components.Collision.checkAABB(a.x, a.y, a.width or 0, a.height or 0, b.x, b.y, b.width or 0, b.height or 0)
end

function SpaceShooter:handlePlayerDamage()
    if self.params.shield and self.player.shield_active then
        self.player.shield_hits_remaining = self.player.shield_hits_remaining - 1
        if self.player.shield_hits_remaining <= 0 then
            self.player.shield_active = false
            self.player.shield_regen_timer = 0
        end
        self:playSound("hit", 1.0)
        return true  -- Damage absorbed by shield
    else
        self.deaths = self.deaths + 1
        self.combo = 0
        self:playSound("hit", 1.0)
        return false  -- Took real damage
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
    local speed_multiplier = self.params.reverse_gravity and -1 or 1

    local function spawnEnemy(x, y, shoot_timer)
        self.entity_controller:spawn("enemy", x, y, {
            movement_pattern = 'straight',
            speed_override = adjusted_speed * speed_multiplier,
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
                shoot_timer = math.random() * 3.0,
                shoot_rate = 2.0,
                health = wave_health,
                wave_speed = wave_speed
            })
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
                -- Wave complete, start pause
                self.grid_state.wave_active = false
                self.grid_state.wave_pause_timer = self.params.wave_pause_duration
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
    local base_speed = self.params.grid_speed
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
            if self.grid_state.direction > 0 and enemy.x + (self.params.enemy_width or 30) >= self.game_width then
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
                enemy.y = enemy.y + self.params.grid_descent
            end
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

-- Galaga: Spawn enemy with entrance pattern
function SpaceShooter:spawnGalagaEnemy(formation_slot, wave_modifiers)
    wave_modifiers = wave_modifiers or {}
    local wave_health = wave_modifiers.health or self.params.enemy_health
    local wave_dive_frequency = wave_modifiers.dive_frequency or self.params.dive_frequency

    local entrance_side = math.random() > 0.5 and "left" or "right"
    local start_x = entrance_side == "left" and -50 or (self.game_width + 50)
    local start_y = -50

    -- Build entrance path
    local entrance_path
    if self.params.entrance_pattern == "swoop" then
        entrance_path = {
            {x = start_x, y = start_y},
            {x = self.game_width / 2, y = self.game_height * 0.6},
            {x = formation_slot.x, y = formation_slot.y}
        }
    elseif self.params.entrance_pattern == "loop" then
        local mid_x = entrance_side == "left" and self.game_width * 0.3 or self.game_width * 0.7
        entrance_path = {
            {x = start_x, y = start_y},
            {x = mid_x, y = self.game_height * 0.5},
            {x = formation_slot.x, y = formation_slot.y}
        }
    else
        entrance_path = {
            {x = start_x, y = start_y},
            {x = (start_x + formation_slot.x) / 2, y = self.game_height * 0.3},
            {x = formation_slot.x, y = formation_slot.y}
        }
    end

    formation_slot.occupied = true

    self.entity_controller:spawn("enemy", start_x, start_y, {
        movement_pattern = 'galaga_entering',
        galaga_state = 'entering',
        formation_slot = formation_slot,
        formation_x = formation_slot.x,
        formation_y = formation_slot.y,
        entrance_t = 0,
        entrance_duration = 2.0,
        entrance_path = entrance_path,
        shoot_timer = math.random() * 3.0,
        shoot_rate = 2.5,
        health = wave_health,
        wave_dive_frequency = wave_dive_frequency
    })
end

-- Galaga: Update formation and dive mechanics
function SpaceShooter:updateGalagaFormation(dt)
    -- Wave system: Check if we need to start a new wave
    if self.params.waves_enabled then
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
                self.galaga_state.wave_pause_timer = self.params.wave_pause_duration
                -- Clear formation for next wave
                self.galaga_state.formation_positions = {}
            end
        else
            -- In pause between waves
            self.galaga_state.wave_pause_timer = self.galaga_state.wave_pause_timer - dt
            if self.galaga_state.wave_pause_timer <= 0 then
                -- Calculate wave modifiers for new wave
                local wave_multiplier = 1.0 + (self.galaga_state.wave_number * self.params.wave_difficulty_increase)
                local variance = self.params.wave_random_variance
                local random_factor = 1.0
                if variance > 0 then
                    random_factor = 1.0 + ((math.random() - 0.5) * 2 * variance)
                end

                local wave_modifiers = {
                    health = math.max(1, math.floor(self.params.enemy_health * wave_multiplier + 0.5)),
                    dive_frequency = self.params.dive_frequency / (wave_multiplier * random_factor)  -- Faster dives = harder
                }

                -- Start new wave
                self:initGalagaFormation()
                self.galaga_state.wave_number = self.galaga_state.wave_number + 1
                self.galaga_state.spawned_count = 0
                self.galaga_state.spawn_timer = 0
                self.galaga_state.wave_modifiers = wave_modifiers  -- Store for gradual spawning

                -- Spawn initial batch of enemies with modifiers
                local initial_count = math.min(self.params.initial_spawn_count, #self.galaga_state.formation_positions)
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
        local initial_count = math.min(self.params.initial_spawn_count, #self.galaga_state.formation_positions)
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

    if #unoccupied_slots > 0 and self.galaga_state.spawned_count < self.params.formation_size then
        self.galaga_state.spawn_timer = self.galaga_state.spawn_timer - dt
        if self.galaga_state.spawn_timer <= 0 then
            -- Spawn one enemy into a random unoccupied slot
            local slot = unoccupied_slots[math.random(1, #unoccupied_slots)]
            self:spawnGalagaEnemy(slot, self.galaga_state.wave_modifiers)
            self.galaga_state.spawned_count = self.galaga_state.spawned_count + 1
            self.galaga_state.spawn_timer = self.params.spawn_interval
        end
    end

    -- Update dive timer
    self.galaga_state.dive_timer = self.galaga_state.dive_timer - dt
    if self.galaga_state.dive_timer <= 0 and self.galaga_state.diving_count < self.params.max_diving_enemies then
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

        self.galaga_state.dive_timer = self.params.dive_frequency
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
                self.entity_controller:removeEntity(enemy)
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

--Wave spawning logic
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

    for _, asteroid in ipairs(self.asteroids) do
        asteroid.y = asteroid.y + speed * dt
        asteroid.rotation = asteroid.rotation + asteroid.rotation_speed * dt

        if self:checkCollision(asteroid, self.player) then
            self:handlePlayerDamage()
            self.entity_controller:removeEntity(asteroid)
        elseif self.params.asteroids_can_be_destroyed then
            for _, bullet in ipairs(self.player_bullets) do
                if self:checkCollision(asteroid, bullet) then
                    self.entity_controller:removeEntity(asteroid)
                    if not self.params.bullet_piercing then
                        self.projectile_system:removeProjectile(bullet)
                    end
                    break
                end
            end
        end

        -- Check collision with enemies
        for _, enemy in ipairs(self.enemies) do
            if self:checkCollision(asteroid, enemy) then
                self.entity_controller:removeEntity(enemy)
                self.entity_controller:removeEntity(asteroid)
                break
            end
        end

        -- Remove if off screen
        local off_screen = self.params.reverse_gravity and (asteroid.y + asteroid.height < 0) or (asteroid.y > self.game_height + asteroid.height)
        if off_screen then
            self.entity_controller:removeEntity(asteroid)
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
    for _, meteor in ipairs(self.meteors) do
        meteor.y = meteor.y + (meteor.speed + self.params.scroll_speed) * speed_direction * dt

        if self:checkCollision(meteor, self.player) then
            self:handlePlayerDamage()
            self.entity_controller:removeEntity(meteor)
        else
            for _, bullet in ipairs(self.player_bullets) do
                if self:checkCollision(meteor, bullet) then
                    self.entity_controller:removeEntity(meteor)
                    if not self.params.bullet_piercing then
                        self.projectile_system:removeProjectile(bullet)
                    end
                    break
                end
            end
        end

        local off_screen = self.params.reverse_gravity and (meteor.y + meteor.height < 0) or (meteor.y > self.game_height + meteor.height)
        if off_screen then
            self.entity_controller:removeEntity(meteor)
        end
    end
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

--Powerup hooks (separate methods to avoid 60-upvalue limit)
function SpaceShooter:onPowerupCollect(powerup)
    self:playSound("powerup", 1.0)
end

function SpaceShooter:applyPowerupEffect(powerup_type, effect, config)
    if powerup_type == "speed" then
        effect.original = self:multiplyParam("player_speed", self.params.powerup_speed_multiplier)
    elseif powerup_type == "rapid_fire" then
        effect.original = self:multiplyParam("fire_cooldown", self.params.powerup_rapid_fire_multiplier)
    elseif powerup_type == "pierce" then
        effect.original = self:enableParam("bullet_piercing")
    elseif powerup_type == "shield" then
        if self.params.shield then
            self.player.shield_active = true
            self.player.shield_hits_remaining = self.params.shield_hits
        end
    elseif powerup_type == "triple_shot" then
        effect.original = self:setParam("bullet_pattern", "triple")
    elseif powerup_type == "spread_shot" then
        effect.original = self:setParam("bullet_pattern", "spread")
    end
end

function SpaceShooter:removePowerupEffect(powerup_type, effect)
    if effect.original == nil then return end
    if powerup_type == "speed" then
        self:restoreParam("player_speed", effect.original)
    elseif powerup_type == "rapid_fire" then
        self:restoreParam("fire_cooldown", effect.original)
    elseif powerup_type == "pierce" then
        self:restoreParam("bullet_piercing", effect.original)
    elseif powerup_type == "triple_shot" or powerup_type == "spread_shot" then
        self:restoreParam("bullet_pattern", effect.original)
    end
end

return SpaceShooter