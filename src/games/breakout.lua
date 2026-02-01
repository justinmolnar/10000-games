--[[
    Breakout - Classic brick-breaking game

    Ball bounces off paddle to destroy bricks. Supports many variant parameters:
    - Movement modes (direct, velocity, rail, asteroids, jump)
    - Ball physics (gravity, homing, magnet, bounce randomness)
    - Brick layouts and behaviors (falling, moving, regenerating)
    - Powerups, obstacles, shooting paddle, sticky paddle, etc.

    Most configuration comes from breakout_schema.json via SchemaLoader.
    Components are created from schema definitions in setupComponents().
]]

local BaseGame = require('src.games.base_game')
local BreakoutView = require('src.games.views.breakout_view')
local Breakout = BaseGame:extend('Breakout')

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function Breakout:init(game_data, cheats, di, variant_override)
    Breakout.super.init(self, game_data, cheats, di, variant_override)

    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.breakout)
    self.params = self.di.components.SchemaLoader.load(self.variant, "breakout_schema", runtimeCfg)

    self:applyCheats({
        speed_modifier = {"paddle_speed", "ball_speed", "ball_max_speed"},
        advantage_modifier = {"paddle_width"},
        performance_modifier = {"ball_count"}
    })

    self.bricks_destroyed, self.bricks_left, self.balls_lost, self.last_extra_ball_threshold = 0, 0, 0, 0
    self:createPaddle({
        width = self.params.paddle_width,
        height = self.params.paddle_height
    })
    self:setupComponents()
    self:setupEntities()
    self.view = BreakoutView:new(self)
end

function Breakout:setupComponents()
    local p = self.params
    local game = self

    -- Schema-driven components (paddle_movement, popup_manager, health_system, hud, fog_controller, visual_effects)
    self:createComponentsFromSchema()
    self.lives = self.health_system.lives

    -- Projectile system (minimal - game handles ball physics/collision)
    self:createProjectileSystemFromSchema({pooling = false, max_projectiles = 50, out_of_bounds_margin = 100})

    -- Entity controller from schema with callbacks
    self:createEntityControllerFromSchema({
        brick = {
            on_hit = function(brick)
                if p.brick_flash_on_hit then game:flashEntity(brick, 0.1) end
            end,
            on_death = function(brick)
                brick.alive = false
                game:onBrickDestroyed(brick)
            end
        },
        obstacle = {
            health = p.obstacles_destructible and 3 or math.huge,
            max_health = p.obstacles_destructible and 3 or math.huge
        }
    }, {spawning = {mode = "manual"}, pooling = false, max_entities = 500})

    -- Victory condition from schema with bonuses
    self:createVictoryConditionFromSchema({
        {
            name = "perfect_clear",
            condition = function(g) return g.balls_lost == 0 and g.params.perfect_clear_bonus > 0 end,
            apply = function(g)
                g.score = g.score + g.params.perfect_clear_bonus
                if g.params.score_popup_enabled then
                    g.popup_manager:add(g.arena_width / 2, g.arena_height / 2,
                        "PERFECT CLEAR! +" .. g.params.perfect_clear_bonus, {0, 1, 0})
                end
            end
        }
    })

    -- Effect system for timed powerup effects
    self:createEffectSystem(function(effect_type, data)
        self:onEffectExpire(effect_type, data)
    end)
    self.powerup_entities = {}
end

function Breakout:setupEntities()
    self.balls = {}
    self.obstacles = {}
    self.shield_active = false
    for i = 1, self.params.ball_count do self:spawnBall() end
    self:generateObstacles()
    self:generateBricks()
    self.metrics = {bricks_destroyed = 0, balls_lost = 0, max_combo = 0, score = 0, time_elapsed = 0}
end

--------------------------------------------------------------------------------
-- Entity Spawning
--------------------------------------------------------------------------------

function Breakout:spawnBall()
    local p = self.params
    local angle = -math.pi / 2 + (self.rng:random() - 0.5) * p.ball_spawn_angle_variance
    local speed = p.ball_speed or 300

    self.projectile_system:spawn({
        x = self.paddle.x,
        y = self.paddle.y - p.ball_radius - 10,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        team = "player",
        lifetime = 9999,  -- Balls don't expire by time
        radius = p.ball_radius or 8,
        pierce_count = p.ball_phase_through_bricks,
        trail = {},
        active = true
    })
end

function Breakout:generateObstacles()
    if self.params.obstacles_count > 0 then
        local bounds = {x = 100, y = 150, width = self.arena_width - 200, height = self.arena_height * 0.4}
        local positions = {}
        for i = 1, self.params.obstacles_count do
            positions[i] = {
                x = bounds.x + math.random() * bounds.width,
                y = bounds.y + math.random() * bounds.height
            }
        end
        self.entity_controller:spawnAtPositions("obstacle", positions)
    end
    self.obstacles = self.entity_controller:getEntitiesByType("obstacle")
end

function Breakout:generateBricks()
    self.entity_controller:clear()

    if self.params.brick_collision_image and self.params.brick_collision_image ~= "" then
        self.entity_controller:loadCollisionImage("brick", self.params.brick_collision_image, self.params.brick_alpha_threshold, self.di)
    end

    local p = self.params
    local positions = self:generateBrickPositions()
    self.entity_controller:spawnAtPositions("brick", positions)

    self.bricks = self.entity_controller:getEntities()
    self.bricks_left = #self.bricks
end

function Breakout:generateBrickPositions()
    local p = self.params
    local layout = p.brick_layout or "grid"
    local rows, cols = p.brick_rows, p.brick_columns
    local spacing_x = p.brick_width + p.brick_padding
    local spacing_y = p.brick_height + p.brick_padding
    local total_width = cols * spacing_x
    local start_x = (self.arena_width - total_width) / 2
    local start_y = 60
    local positions = {}

    if layout == "pyramid" then
        for row = 1, rows do
            local cols_in_row = math.min(row, cols)
            local row_width = (cols_in_row - 1) * spacing_x
            local row_start_x = (self.arena_width - row_width) / 2
            for col = 1, cols_in_row do
                table.insert(positions, {
                    x = row_start_x + (col - 1) * spacing_x,
                    y = start_y + (row - 1) * spacing_y,
                    row = row, col = col
                })
            end
        end
    elseif layout == "circle" then
        local center_x, center_y = self.arena_width / 2, 200
        local ring_spacing = 40
        for ring = 1, rows do
            local radius = ring * ring_spacing
            local count = 8 + (ring - 1) * 4
            for i = 1, count do
                local angle = (i - 1) / count * math.pi * 2
                table.insert(positions, {
                    x = center_x + math.cos(angle) * radius,
                    y = center_y + math.sin(angle) * radius,
                    ring = ring, index = i
                })
            end
        end
    elseif layout == "random" then
        local bounds = {x = 40, y = 40, width = self.arena_width - 80, height = self.arena_height * 0.4}
        for i = 1, rows * cols do
            table.insert(positions, {
                x = bounds.x + math.random() * bounds.width,
                y = bounds.y + math.random() * bounds.height,
                index = i
            })
        end
    elseif layout == "checkerboard" then
        for row = 1, rows do
            for col = 1, cols do
                if (row + col) % 2 == 0 then
                    table.insert(positions, {
                        x = start_x + (col - 1) * spacing_x,
                        y = start_y + (row - 1) * spacing_y,
                        row = row, col = col
                    })
                end
            end
        end
    else -- grid (default)
        for row = 1, rows do
            for col = 1, cols do
                table.insert(positions, {
                    x = start_x + (col - 1) * spacing_x,
                    y = start_y + (row - 1) * spacing_y,
                    row = row, col = col
                })
            end
        end
    end

    return positions
end

--------------------------------------------------------------------------------
-- Update Loop
--------------------------------------------------------------------------------

function Breakout:updateGameLogic(dt)
    if self.game_over or self.victory then return end

    local Physics, TableUtils = self.di.components.PhysicsUtils, self.di.components.TableUtils
    local bounds = {x = 0, y = 0, width = self.arena_width, height = self.arena_height}

    -- Update systems
    self.projectile_system:update(dt, bounds)
    self.balls = self.projectile_system:getByTeam("player")
    self:updatePowerups(dt, bounds)
    self.effect_system:update(dt)
    self.powerups, self.active_powerups = self.powerup_entities, self.effect_system:getActiveEffects()
    self.visual_effects:update(dt)
    self:updateFlashMap(dt)
    self.popup_manager:update(dt)

    -- Update paddle
    local left = self:isKeyDown('a', 'left')
    local right = self:isKeyDown('d', 'right')
    local dx = (right and 1 or 0) - (left and 1 or 0)
    if dx ~= 0 then
        self.paddle_movement:applyDirectionalMove(self.paddle, dx, 0, self.params.paddle_speed, dt)
    end
    self.paddle_movement:applyBounds(self.paddle, bounds)
    if self.params.paddle_sticky then
        local aim_delta = (self:isKeyDown('d', 'right') and 2 or 0) - (self:isKeyDown('a', 'left') and 2 or 0)
        self.paddle.sticky_aim_angle = math.max(-math.pi * 0.95, math.min(-math.pi * 0.05, self.paddle.sticky_aim_angle + aim_delta * dt))
    end
    if self.paddle.shoot_cooldown_timer > 0 then self.paddle.shoot_cooldown_timer = self.paddle.shoot_cooldown_timer - dt end

    -- Update balls
    for _, ball in ipairs(self.balls) do
        if ball.active then
            if self.visual_effects.particles then
                self.visual_effects.particles:emitBallTrail(ball.x, ball.y, ball.vx, ball.vy)
            end
            self:updateBall(ball, dt)
        end
    end

    -- Paddle bullets hitting bricks (using physics_utils)
    local paddle_bullets = self.projectile_system:getByTeam("paddle_bullet")
    for _, bullet in ipairs(paddle_bullets) do
        for _, brick in ipairs(self.bricks) do
            if brick.alive and Physics.circleVsRect(
                bullet.x, bullet.y, bullet.radius or 3,
                brick.x, brick.y, brick.width, brick.height
            ) then
                self.entity_controller:hitEntity(brick, self.params.paddle_shoot_damage, bullet)
                self.projectile_system:remove(bullet)
                break
            end
        end
    end

    -- Update bricks and check for ball loss
    self:updateBricks(dt)
    self:handleEntityDepleted(function() return TableUtils.countActive(self.balls) end, {
        loss_counter = "balls_lost", combo_reset = true, damage = 1, damage_reason = "ball_lost",
        on_respawn = function(g) g:spawnBall() end
    })

    -- Check victory/loss
    local result = self.victory_checker:check()
    if result then self.victory, self.game_over = result == "victory", result == "loss" end
    self:syncMetrics({bricks_destroyed = "bricks_destroyed", balls_lost = "balls_lost", max_combo = "max_combo", score = "score", time_elapsed = "time_elapsed"})
end

function Breakout:updateBall(ball, dt)
    local Physics = self.di.components.PhysicsUtils
    local p = self.params
    local game = self

    -- Apply forces (gravity, homing, magnet)
    Physics.applyForces(ball, {
        gravity = p.ball_gravity, gravity_direction = p.ball_gravity_direction,
        homing_strength = p.ball_homing_strength,
        magnet_range = p.paddle_magnet_range, magnet_strength = p.paddle_magnet_strength
    }, dt,
        function() return self.entity_controller:findNearest(ball.x, ball.y, function(e) return e.alive end) end,
        self.paddle
    )
    if p.ball_max_speed then Physics.clampSpeed(ball, p.ball_max_speed) end

    -- Handle sticky ball
    if Physics.handleAttachment(ball, self.paddle, "stuck_offset_x", "stuck_offset_y") then return end

    Physics.move(ball, dt)
    Physics.updateTrail(ball, p.ball_trail_length)

    -- Wall collisions
    local restitution = ({normal = 1.0, damped = 0.9, sticky = 0.6})[p.wall_bounce_mode] or 1.0
    Physics.handleBounds(ball, {width = self.arena_width, height = self.arena_height}, {w = ball.radius, h = ball.radius}, function(e, info)
        if info.edge == "bottom" then return end  -- handled by kill plane
        if info.edge == "top" and not p.ceiling_enabled then
            e.active = false
            return
        end
        Physics.bounceEdge(e, info, restitution)
        if p.ball_bounce_randomness > 0 then
            Physics.addBounceRandomness(e, p.ball_bounce_randomness, self.rng)
        end
    end)
    if not ball.active then return end

    -- Bottom boundary with shield
    if Physics.handleKillPlane(ball, {
        pos_field = "y", vel_field = "vy", inside_dir = -1,
        check_fn = function(e, boundary, r) return e.y - r > boundary end
    }, self.arena_height, {
        kill_enabled = p.bottom_kill_enabled,
        shield_active = self.shield_active,
        on_shield_use = function() game.shield_active = false end,
        restitution = restitution, bounce_randomness = p.ball_bounce_randomness, rng = self.rng
    }) then return end

    -- Paddle collision
    Physics.handleCenteredRectCollision(ball, self.paddle, {
        sticky = p.paddle_sticky, sticky_dir = -1,
        use_angle_mode = p.paddle_aim_mode == "position",
        base_angle = -math.pi / 2, angle_range = math.pi / 4, bounce_direction = -1,
        spin_influence = 100, restitution = 1.0, separation = 1,
        bounce_randomness = p.ball_bounce_randomness, max_speed = p.ball_max_speed, rng = self.rng,
        on_hit = function() game.combo = 0 end
    })

    -- Brick collisions
    local PNGCollision = self.di.components.PNGCollision
    local brick_hit = false
    Physics.checkCollisions(ball, self.bricks, {
        filter = function(brick) return brick.alive end,
        check_func = function(b, brick)
            return brick.collision_image and PNGCollision.checkBall(brick.collision_image, brick.x, brick.y, b.x, b.y, b.radius, brick.alpha_threshold or 0.5)
                or Physics.circleVsRect(b.x, b.y, b.radius, brick.x, brick.y, brick.width, brick.height)
        end,
        on_hit = function(b, brick)
            self.entity_controller:hitEntity(brick, 1, b)
            if not brick_hit then
                brick_hit = true
                -- Simple bounce: determine axis by overlap depth (corner-based coords)
                local brick_cx, brick_cy = brick.x + brick.width / 2, brick.y + brick.height / 2
                local dx, dy = b.x - brick_cx, b.y - brick_cy
                local half_w, half_h = brick.width / 2, brick.height / 2
                local overlap_x = half_w + b.radius - math.abs(dx)
                local overlap_y = half_h + b.radius - math.abs(dy)
                if overlap_x < overlap_y then
                    b.vx = -b.vx
                    b.x = brick_cx + (dx > 0 and (half_w + b.radius + 1) or -(half_w + b.radius + 1))
                else
                    b.vy = -b.vy
                    b.y = brick_cy + (dy > 0 and (half_h + b.radius + 1) or -(half_h + b.radius + 1))
                end
            end
        end,
        stop_on_first = false
    })
    if brick_hit then
        Physics.applyBounceEffects(ball, {speed_increase = p.ball_speed_increase_per_bounce, max_speed = p.ball_max_speed, bounce_randomness = p.ball_bounce_randomness}, self.rng)
    end

    -- Obstacle collisions
    local obs_hit = false
    Physics.checkCollisions(ball, self.obstacles, {
        filter = function(obs) return obs.alive end,
        check_func = function(b, obs) return Physics.circleVsRect(b.x, b.y, b.radius, obs.x, obs.y, obs.width, obs.height) end,
        on_hit = function(b, obs)
            if not obs_hit then
                obs_hit = true
                local obs_cx, obs_cy = obs.x + obs.width / 2, obs.y + obs.height / 2
                local dx, dy = b.x - obs_cx, b.y - obs_cy
                local half_w, half_h = obs.width / 2, obs.height / 2
                local overlap_x = half_w + b.radius - math.abs(dx)
                local overlap_y = half_h + b.radius - math.abs(dy)
                if overlap_x < overlap_y then
                    b.vx = -b.vx
                    b.x = obs_cx + (dx > 0 and (half_w + b.radius + 1) or -(half_w + b.radius + 1))
                else
                    b.vy = -b.vy
                    b.y = obs_cy + (dy > 0 and (half_h + b.radius + 1) or -(half_h + b.radius + 1))
                end
            end
        end,
        stop_on_first = false
    })
    if obs_hit then
        Physics.applyBounceEffects(ball, {bounce_randomness = p.ball_bounce_randomness}, self.rng)
    end

    if p.ball_max_speed then Physics.clampSpeed(ball, p.ball_max_speed) end
end

function Breakout:updateBricks(dt)
    self.bricks = self.entity_controller:getEntities()
    local p = self.params
    self.entity_controller:updateBehaviors(dt, {
        fall_enabled = p.brick_fall_enabled, fall_speed = p.brick_fall_speed,
        fall_death_y = self.paddle.y - 30, on_fall_death = function() self.game_over = true end,
        move_enabled = p.brick_movement_enabled, move_speed = p.brick_movement_speed,
        bounds = {x_min = 0, x_max = self.arena_width},
        regen_enabled = p.brick_regeneration_enabled, regen_time = p.brick_regeneration_time,
        can_overlap = p.bricks_can_overlap
    }, self.entity_controller:getRectCollisionCheck(self.di.components.PhysicsUtils))
end

--------------------------------------------------------------------------------
-- Event Callbacks
--------------------------------------------------------------------------------

function Breakout:onBrickDestroyed(brick)
    self:handleEntityDestroyed(brick, {
        destroyed_counter = "bricks_destroyed",
        remaining_counter = "bricks_left",
        on_spawn_powerup = function(x, y) self:spawnPowerup(x, y) end,
        effects = {particles = true, shake = 0.15},
        scoring = {base = "brick_score_multiplier", combo_mult = "combo_multiplier"},
        popup = {enabled = "score_popup_enabled", milestone_combos = {5, 10, 15}},
        color_func = function(b) return {1, 0.5 + (b.max_health - 1) * 0.1, 0} end,
        extra_life_check = true
    })
end

--------------------------------------------------------------------------------
-- Powerups
--------------------------------------------------------------------------------

Breakout.POWERUP_COLORS = {
    multi_ball = {0, 1, 1},
    paddle_extend = {0, 1, 0},
    paddle_shrink = {1, 0, 0},
    slow_motion = {0.5, 0.5, 1},
    fast_ball = {1, 0.5, 0},
    laser = {1, 0, 1},
    sticky_paddle = {1, 1, 0},
    extra_life = {0, 1, 0.5},
    shield = {0.3, 0.7, 1},
    penetrating_ball = {1, 0.3, 0},
    fireball = {1, 0.2, 0},
    magnet = {0.7, 0.7, 0.7}
}

function Breakout:spawnPowerup(x, y)
    local p = self.params
    if not p.powerup_enabled then return end
    if self.rng:random() > (p.brick_powerup_drop_chance or 0.2) then return end

    local types = p.powerup_types or {}
    if #types == 0 then return end

    local powerup_type = types[self.rng:random(1, #types)]
    local size = p.powerup_size or 20
    table.insert(self.powerup_entities, {
        x = x - size / 2,
        y = y - size / 2,
        width = size,
        height = size,
        type = powerup_type,
        color = Breakout.POWERUP_COLORS[powerup_type] or {1, 1, 1},
        vy = p.powerup_fall_speed or 100
    })
end

function Breakout:updatePowerups(dt, bounds)
    local Physics = self.di.components.PhysicsUtils
    for i = #self.powerup_entities, 1, -1 do
        local powerup = self.powerup_entities[i]
        powerup.y = powerup.y + powerup.vy * dt

        -- Check collection with paddle
        local px, py = self.paddle.x - self.paddle.width / 2, self.paddle.y - self.paddle.height / 2
        if Physics.rectCollision(powerup.x, powerup.y, powerup.width, powerup.height,
                                  px, py, self.paddle.width, self.paddle.height) then
            self:collectPowerup(powerup)
            table.remove(self.powerup_entities, i)
        elseif powerup.y > bounds.height then
            table.remove(self.powerup_entities, i)
        end
    end
end

function Breakout:collectPowerup(powerup)
    local p = self.params
    local effect_type = powerup.type
    local duration = p.powerup_duration or 10.0
    local data = {}

    -- Apply effect and store original values for reversion
    if effect_type == "paddle_extend" then
        data.orig_width = self.paddle.width
        self.paddle.width = self.paddle.width * 1.5
    elseif effect_type == "paddle_shrink" then
        data.orig_width = self.paddle.width
        self.paddle.width = self.paddle.width * 0.5
    elseif effect_type == "slow_motion" then
        data.orig_ball_speed = p.ball_speed
        p.ball_speed = p.ball_speed * 0.5
        for _, ball in ipairs(self.balls) do
            ball.vx, ball.vy = ball.vx * 0.5, ball.vy * 0.5
        end
    elseif effect_type == "fast_ball" then
        data.orig_ball_speed = p.ball_speed
        p.ball_speed = p.ball_speed * 1.5
        for _, ball in ipairs(self.balls) do
            ball.vx, ball.vy = ball.vx * 1.5, ball.vy * 1.5
        end
    elseif effect_type == "laser" then
        data.orig_can_shoot = p.paddle_can_shoot
        p.paddle_can_shoot = true
    elseif effect_type == "sticky_paddle" then
        data.orig_sticky = p.paddle_sticky
        p.paddle_sticky = true
    elseif effect_type == "extra_life" then
        self.health_system:addLife(1)
        self.lives = self.health_system.lives
        return  -- No duration tracking needed
    elseif effect_type == "shield" then
        self.shield_active = true
    elseif effect_type == "penetrating_ball" or effect_type == "fireball" then
        data.orig_pierce = p.ball_phase_through_bricks
        p.ball_phase_through_bricks = 5
        for _, ball in ipairs(self.balls) do
            ball.pierce_count = 5
        end
    elseif effect_type == "magnet" then
        data.orig_magnet_range = p.paddle_magnet_range
        p.paddle_magnet_range = 150
    elseif effect_type == "multi_ball" then
        -- Spawn extra balls from existing balls
        for _, ball in ipairs(self.balls) do
            if ball.active then
                local speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
                local angle = math.atan2(ball.vy, ball.vx)
                for j = 1, 2 do
                    local offset = (j - 1.5) * 0.5
                    local new_angle = angle + offset
                    self.projectile_system:spawn({
                        x = ball.x,
                        y = ball.y,
                        vx = math.cos(new_angle) * speed,
                        vy = math.sin(new_angle) * speed,
                        team = "player",
                        lifetime = 9999,
                        radius = ball.radius,
                        trail = {},
                        active = true
                    })
                end
                break  -- Only from first active ball
            end
        end
        return  -- No duration tracking needed
    end

    self.effect_system:activate(effect_type, duration, data)
end

function Breakout:onEffectExpire(effect_type, data)
    local p = self.params
    if effect_type == "paddle_extend" or effect_type == "paddle_shrink" then
        self.paddle.width = data.orig_width
    elseif effect_type == "slow_motion" or effect_type == "fast_ball" then
        local ratio = data.orig_ball_speed / p.ball_speed
        p.ball_speed = data.orig_ball_speed
        for _, ball in ipairs(self.balls) do
            ball.vx, ball.vy = ball.vx * ratio, ball.vy * ratio
        end
    elseif effect_type == "laser" then
        p.paddle_can_shoot = data.orig_can_shoot
    elseif effect_type == "sticky_paddle" then
        p.paddle_sticky = data.orig_sticky
    elseif effect_type == "shield" then
        self.shield_active = false
    elseif effect_type == "penetrating_ball" or effect_type == "fireball" then
        p.ball_phase_through_bricks = data.orig_pierce
        for _, ball in ipairs(self.balls) do
            ball.pierce_count = 0
        end
    elseif effect_type == "magnet" then
        p.paddle_magnet_range = data.orig_magnet_range
    end
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function Breakout:keypressed(key)
    if key == "space" then
        -- Shooting
        if self.params.paddle_can_shoot and self.paddle.shoot_cooldown_timer <= 0 then
            local bullet_speed = self.params.paddle_bullet_speed or 500
            self.projectile_system:spawn({
                x = self.paddle.x,
                y = self.paddle.y - self.paddle.height / 2 - 5,
                vx = 0,
                vy = -bullet_speed,
                team = "paddle_bullet",
                lifetime = 5,
                width = 6,
                height = 12,
                radius = 3
            })
            self.paddle.shoot_cooldown_timer = self.params.paddle_shoot_cooldown
        end

        -- Release any stuck balls
        self.di.components.PhysicsUtils.releaseStuckEntities(self.balls, self.paddle, {
            launch_speed = 300,
            base_angle = -math.pi / 2,
            angle_range = math.pi / 6,
            release_dir_y = -1
        })
    end
end

--------------------------------------------------------------------------------
-- Play Area
--------------------------------------------------------------------------------

function Breakout:setPlayArea(width, height)
    local old_width = self.arena_width or width
    local offset_x = (width - old_width) / 2

    -- Call parent to set dimensions
    Breakout.super.setPlayArea(self, width, height)

    -- Reposition paddle (clamp to bounds, don't shift)
    if self.paddle then
        self.paddle.y = height - 50
        self.paddle.x = math.max(self.paddle.width / 2, math.min(self.paddle.x, width - self.paddle.width / 2))
    end

    -- Reposition balls
    if self.balls then
        for _, ball in ipairs(self.balls) do
            ball.x = math.max(ball.radius, math.min(width - ball.radius, ball.x + offset_x))
            ball.y = math.max(ball.radius, math.min(height - ball.radius, ball.y))
        end
    end

    -- Reposition bricks
    if self.entity_controller then
        for _, entity in ipairs(self.entity_controller:getEntities()) do
            entity.x = entity.x + offset_x
        end
    end

    -- Reposition obstacles
    if self.obstacles then
        for _, obstacle in ipairs(self.obstacles) do
            obstacle.x = obstacle.x + offset_x
        end
    end
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

function Breakout:draw()
    self.view:draw()
end

return Breakout
