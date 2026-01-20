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

function Breakout:setupComponents()
    local p = self.params
    local game = self

    -- Schema-driven components (paddle_movement, popup_manager, health_system, hud, fog_controller, visual_effects)
    self:createComponentsFromSchema()
    self.lives = self.health_system.lives

    -- Projectile system from schema
    self:createProjectileSystemFromSchema({pooling = false, max_projectiles = 50})

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

    -- Powerup system from schema
    self:createPowerupSystemFromSchema({reverse_gravity = false})
end

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
    self:createPaddle()
    self:setupComponents()
    self:setupEntities()
    self.view = BreakoutView:new(self)
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

function Breakout:spawnBall()
    local angle = -math.pi / 2 + (self.rng:random() - 0.5) * self.params.ball_spawn_angle_variance

    self.projectile_system:shoot(
        "ball",
        self.paddle.x,
        self.paddle.y - self.params.ball_radius - 10,
        angle,
        1.0,  -- speed_multiplier
        {
            pierce_count = self.params.ball_phase_through_bricks,  -- For phase-through bricks
            trail = {}  -- Position history for trail rendering
        }
    )
end

function Breakout:generateObstacles()
    if self.params.obstacles_count > 0 then
        self.entity_controller:spawnRandom("obstacle", self.params.obstacles_count,
            {x = 100, y = 150, width = self.arena_width - 200, height = self.arena_height * 0.4},
            self.rng, true)
    end
    self.obstacles = self.entity_controller:getEntitiesByType("obstacle")
end

function Breakout:generateBricks()
    self.entity_controller:clear()

    if self.params.brick_collision_image and self.params.brick_collision_image ~= "" then
        self.entity_controller:loadCollisionImage("brick", self.params.brick_collision_image, self.params.brick_alpha_threshold, self.di)
    end

    local p = self.params
    local total_width = p.brick_columns * (p.brick_width + p.brick_padding)
    local start_x = (self.arena_width - total_width) / 2

    self.entity_controller:spawnLayout("brick", p.brick_layout, {
        rows = p.brick_rows,
        cols = p.brick_columns,
        x = start_x,
        y = 60,
        spacing_x = p.brick_padding,
        spacing_y = p.brick_padding,
        arena_width = self.arena_width,
        center_x = self.arena_width / 2,
        center_y = 200,
        bounds = {x = 40, y = 40, width = self.arena_width - 80, height = self.arena_height * 0.4},
        rng = self.rng,
        can_overlap = p.bricks_can_overlap
    })

    self.bricks = self.entity_controller:getEntities()
    self.bricks_left = #self.bricks
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

function Breakout:updateGameLogic(dt)
    if self.game_over or self.victory then return end

    local Physics, TableUtils = self.di.components.PhysicsUtils, self.di.components.TableUtils
    local bounds = {x = 0, y = 0, width = self.arena_width, height = self.arena_height}

    self.projectile_system:update(dt, bounds)
    self.balls = self.projectile_system:getProjectilesByTeam("player")
    self.powerup_system:update(dt, self.paddle, bounds)

    self.powerups, self.active_powerups = self.powerup_system:getPowerupsForRendering(), self.powerup_system:getActivePowerupsForHUD()
    self.visual_effects:update(dt)
    self:updateFlashMap(dt)
    self.popup_manager:update(dt)

    self.paddle_movement:update(dt, self.paddle, {left = self:isKeyDown('a', 'left'), right = self:isKeyDown('d', 'right')}, bounds)
    -- Sticky paddle: player can aim the launch angle while ball is stuck
    if self.params.paddle_sticky then
        local aim_delta = (self:isKeyDown('d', 'right') and 2 or 0) - (self:isKeyDown('a', 'left') and 2 or 0)
        self.paddle.sticky_aim_angle = math.max(-math.pi * 0.95, math.min(-math.pi * 0.05, self.paddle.sticky_aim_angle + aim_delta * dt))
    end
    if self.paddle.shoot_cooldown_timer > 0 then self.paddle.shoot_cooldown_timer = self.paddle.shoot_cooldown_timer - dt end

    for _, ball in ipairs(self.balls) do
        if ball.active then
            self.visual_effects:emitBallTrail(ball.x, ball.y, ball.vx, ball.vy)
            self:updateBall(ball, dt)
        end
    end

    -- Paddle bullets hitting bricks (when paddle_can_shoot is enabled)
    self.projectile_system:checkCollisions(self.bricks, function(_, brick)
        if brick.alive then self.entity_controller:hitEntity(brick, self.params.paddle_shoot_damage, _) end
    end, "paddle_bullet")
    self:updateBricks(dt)

    -- Ball lost: take damage, reset combo, respawn or game over
    self:handleEntityDepleted(function() return TableUtils.countActive(self.balls) end, {
        loss_counter = "balls_lost", combo_reset = true, damage_reason = "ball_lost",
        on_respawn = function(g) g:spawnBall() end
    })

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
        magnet_range = p.paddle_magnet_range
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
    Physics.handleBounds(ball, {width = self.arena_width, height = self.arena_height}, {
        mode = "bounce", restitution = restitution,
        per_edge = {top = p.ceiling_enabled and "bounce" or "none", bottom = "none"},
        bounce_randomness = p.ball_bounce_randomness, rng = self.rng,
        on_exit = function(e, edge) if edge == "top" and not p.ceiling_enabled then e.active = false end end
    })
    if not ball.active then return end

    -- Bottom boundary with shield
    if Physics.handleKillPlane(ball, "bottom", self.arena_height, {
        kill_enabled = p.bottom_kill_enabled,
        shield_active = self.shield_active,
        on_shield_use = function() game.shield_active = false end,
        restitution = restitution, bounce_randomness = p.ball_bounce_randomness, rng = self.rng
    }) then return end

    -- Paddle collision
    Physics.handlePaddleCollision(ball, self.paddle, {
        sticky = p.paddle_sticky, aim_mode = p.paddle_aim_mode,
        bounce_randomness = p.ball_bounce_randomness, max_speed = p.ball_max_speed, rng = self.rng,
        on_hit = function() game.combo = 0 end
    })

    -- Brick collisions (supports PNG collision masks for irregular shapes)
    local PNGCollision = self.di.components.PNGCollision
    Physics.checkCollisions(ball, self.bricks, {
        filter = function(brick) return brick.alive end,
        check_func = function(b, brick)
            return brick.collision_image and PNGCollision.checkBall(brick.collision_image, brick.x, brick.y, b.x, b.y, b.radius, brick.alpha_threshold or 0.5)
                or Physics.checkCollision(b, brick, "circle", brick.shape)
        end,
        on_hit = function(b, brick)
            self.entity_controller:hitEntity(brick, 1, b)
            Physics.applyBounceEffects(b, {speed_increase = p.ball_speed_increase_per_bounce, max_speed = p.ball_max_speed, bounce_randomness = p.ball_bounce_randomness}, self.rng)
        end
    })

    -- Obstacle collisions
    Physics.checkCollisions(ball, self.obstacles, {
        filter = function(obs) return obs.alive end,
        on_hit = function(b) Physics.applyBounceEffects(b, {bounce_randomness = p.ball_bounce_randomness}, self.rng) end
    })

    if p.ball_max_speed then Physics.clampSpeed(ball, p.ball_max_speed) end
end

function Breakout:onBrickDestroyed(brick)
    self:handleEntityDestroyed(brick, {
        destroyed_counter = "bricks_destroyed",
        remaining_counter = "bricks_left",
        spawn_powerup = true,
        effects = {particles = true, shake = 0.15},
        scoring = {base = "brick_score_multiplier", combo_mult = "combo_multiplier"},
        popup = {enabled = "score_popup_enabled", milestone_combos = {5, 10, 15}},
        color_func = function(b) return {1, 0.5 + (b.max_health - 1) * 0.1, 0} end,
        extra_life_check = true
    })
end

function Breakout:keypressed(key)
    if key == "space" then
        -- Shooting
        if self.params.paddle_can_shoot and self.paddle.shoot_cooldown_timer <= 0 then
            self.projectile_system:shoot("paddle_bullet", self.paddle.x, self.paddle.y - self.paddle.height / 2 - 5, -math.pi / 2)
            self.paddle.shoot_cooldown_timer = self.params.paddle_shoot_cooldown
        end

        -- Release any stuck balls
        self.di.components.PhysicsUtils.releaseStuckEntities(self.balls, self.paddle, {launch_speed = 300})
    end
end

function Breakout:draw()
    self.view:draw()
end

return Breakout
