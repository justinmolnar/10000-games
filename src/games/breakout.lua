local BaseGame = require('src.games.base_game')
local BreakoutView = require('src.games.views.breakout_view')
local Breakout = BaseGame:extend('Breakout')

function Breakout:setupComponents()
    local p = self.params
    local C = self.di.components

    self.paddle_movement = C.MovementController:new({
        mode = "direct", speed = p.paddle_speed,
        friction = p.paddle_friction, rail_axis = "horizontal"
    })

    self.projectile_system = C.ProjectileSystem:new({
        projectile_types = {
            ["ball"] = {
                speed = p.ball_speed, radius = p.ball_radius,
                movement_type = "bounce", lifetime = 999, team = "player",
                bounce_top = true, bounce_left = true, bounce_right = true, bounce_bottom = false
            }
        },
        pooling = false, max_projectiles = 50
    })

    self.entity_controller = C.EntityController:new({
        entity_types = {
            ["brick"] = {
                width = p.brick_width, height = p.brick_height,
                health = p.brick_health, max_health = p.brick_health,
                shape = p.brick_shape, radius = p.brick_radius,
                alive = true, vx = 0, vy = 0, regen_timer = 0
            },
            ["obstacle"] = {
                size = 40, shape = p.obstacles_shape,
                health = p.obstacles_destructible and 3 or math.huge,
                max_health = p.obstacles_destructible and 3 or math.huge,
                alive = true
            }
        },
        spawning = {mode = "manual"}, pooling = false, max_entities = 500
    })

    self.powerup_system = C.PowerupSystem:new({
        enabled = p.powerup_enabled, spawn_mode = "event",
        spawn_drop_chance = p.brick_powerup_drop_chance, powerup_size = p.powerup_size,
        drop_speed = p.powerup_fall_speed, reverse_gravity = false,
        default_duration = p.powerup_duration, powerup_types = p.powerup_types,
        powerup_configs = {
            multi_ball = {effects = {{type = "spawn_projectiles", source = "balls", count = 2, angle_spread = math.pi/6}}},
            paddle_extend = {effects = {{type = "multiply_entity_field", entity = "paddle", field = "width", multiplier = 1.5}}},
            paddle_shrink = {effects = {{type = "multiply_entity_field", entity = "paddle", field = "width", multiplier = 0.5}}},
            slow_motion = {effects = {{type = "multiply_param", param = "ball_speed", multiplier = 0.5}, {type = "multiply_entity_speed", entities = "balls", multiplier = 0.5}}},
            fast_ball = {effects = {{type = "multiply_param", param = "ball_speed", multiplier = 1.5}, {type = "multiply_entity_speed", entities = "balls", multiplier = 1.5}}},
            laser = {effects = {{type = "enable_param", param = "paddle_can_shoot"}}},
            sticky_paddle = {effects = {{type = "enable_param", param = "paddle_sticky"}}},
            extra_life = {effects = {{type = "add_lives", count = 1}}},
            shield = {effects = {{type = "set_flag", flag = "shield_active", value = true}}},
            penetrating_ball = {effects = {{type = "set_param", param = "ball_phase_through_bricks", value = 5}, {type = "set_entity_field", entities = "balls", field = "pierce_count", value = 5}}},
            fireball = {effects = {{type = "set_param", param = "ball_phase_through_bricks", value = 5}, {type = "set_entity_field", entities = "balls", field = "pierce_count", value = 5}}},
            magnet = {effects = {{type = "set_param", param = "paddle_magnet_range", value = 150}}}
        }
    })
    self.powerup_system.game = self

    self.popup_manager = C.PopupManager:new()

    self.health_system = C.LivesHealthSystem:new({
        mode = "lives", starting_lives = p.lives, max_lives = 10,
        extra_life_enabled = true, extra_life_threshold = p.extra_ball_score_threshold
    })
    self.lives = self.health_system.lives

    self.hud = C.HUDRenderer:new({
        primary = {label = "Score", key = "score"},
        secondary = {label = "Bricks", key = "bricks_left"},
        lives = {key = "lives", max = p.lives, style = "hearts"}
    })
    self.hud.game = self

    self.fog_controller = C.FogOfWar:new({enabled = p.fog_of_war_enabled, mode = "stencil", opacity = 0.8})
    self.visual_effects = C.VisualEffects:new({
        camera_shake_enabled = p.camera_shake_enabled,
        particle_effects_enabled = p.particle_effects_enabled,
        screen_flash_enabled = false, shake_mode = "timer", shake_decay = 0.9
    })
    self.brick_flash_map = {}

    local vc = {}
    if p.victory_condition == "clear_bricks" or p.victory_condition == "clear_all" then
        vc.victory = {type = "clear_all", metric = "bricks_left"}
    elseif p.victory_condition == "destroy_count" then
        vc.victory = {type = "threshold", metric = "bricks_destroyed", target = p.destroy_count_target}
    elseif p.victory_condition == "score" then
        vc.victory = {type = "threshold", metric = "score", target = p.score_target}
    elseif p.victory_condition == "time" then
        vc.victory = {type = "time_survival", metric = "time_elapsed", target = p.time_target}
    elseif p.victory_condition == "survival" then
        vc.victory = {type = "endless"}
    end
    vc.loss = {type = "lives_depleted", metric = "lives"}
    vc.check_loss_first = true
    self.victory_checker = C.VictoryCondition:new(vc)
    self.victory_checker.game = self
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

    self:setupGameState()
    self:setupPaddle()
    self:setupComponents()
    self:setupEntities()

    self.view = BreakoutView:new(self)
end

function Breakout:setupGameState()
    if self.seed then self.rng = love.math.newRandomGenerator(self.seed) end
    self.bricks_destroyed = 0
    self.bricks_left = 0
    self.balls_lost = 0
    self.last_extra_ball_threshold = 0
end

function Breakout:setupPaddle()
    self.paddle = {
        x = self.arena_width / 2,
        y = self.arena_height - 50,
        width = self.params.paddle_width,
        height = self.params.paddle_height,
        radius = self.params.paddle_width / 2,
        vx = 0, vy = 0, angle = 0,
        jump_cooldown_timer = 0,
        shoot_cooldown_timer = 0,
        sticky_aim_angle = -math.pi / 2
    }
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

    -- Load collision/display images and update entity type
    if self.params.brick_collision_image and self.params.brick_collision_image ~= "" then
        local brick_type = self.entity_controller.entity_types["brick"]
        brick_type.collision_image = self.di.components.PNGCollision.loadCollisionImage(self.params.brick_collision_image)
        local success, img = pcall(love.graphics.newImage, self.params.brick_collision_image)
        if success then brick_type.display_image = img end
        brick_type.alpha_threshold = self.params.brick_alpha_threshold
    end

    local p = self.params
    local ec = self.entity_controller
    local total_width = p.brick_columns * (p.brick_width + p.brick_padding)
    local start_x = (self.arena_width - total_width) / 2

    if p.brick_layout == "pyramid" then
        ec:spawnPyramid("brick", p.brick_rows, p.brick_columns, start_x, 60, p.brick_padding, p.brick_padding, self.arena_width)
    elseif p.brick_layout == "circle" then
        ec:spawnCircle("brick", p.brick_rows, self.arena_width / 2, 200, 12, 40)
    elseif p.brick_layout == "random" then
        ec:spawnRandom("brick", p.brick_rows * p.brick_columns,
            {x = 40, y = 40, width = self.arena_width - 80, height = self.arena_height * 0.4},
            self.rng, p.bricks_can_overlap)
    elseif p.brick_layout == "checkerboard" then
        ec:spawnCheckerboard("brick", p.brick_rows, p.brick_columns, start_x, 60, p.brick_padding, p.brick_padding)
    else -- grid (default)
        ec:spawnGrid("brick", p.brick_rows, p.brick_columns, start_x, 60, p.brick_padding, p.brick_padding)
    end

    self.bricks = ec:getEntities()
    self.bricks_left = #self.bricks
end

function Breakout:updateBricks(dt)
    self.bricks = self.entity_controller:getEntities()

    local Physics = self.di.components.PhysicsUtils
    self.entity_controller:updateBehaviors(dt, {
        fall_enabled = self.params.brick_fall_enabled,
        fall_speed = self.params.brick_fall_speed,
        fall_death_y = self.paddle.y - 30,
        on_fall_death = function() self.game_over = true end,

        move_enabled = self.params.brick_movement_enabled,
        move_speed = self.params.brick_movement_speed,
        bounds = {x_min = 0, x_max = self.arena_width},

        regen_enabled = self.params.brick_regeneration_enabled,
        regen_time = self.params.brick_regeneration_time,

        can_overlap = self.params.bricks_can_overlap
    }, function(entity, x, y)
        -- Collision check for behavior system
        for _, other in ipairs(self.bricks) do
            if other ~= entity and other.alive then
                if Physics.rectCollision(x, y, entity.width, entity.height,
                    other.x, other.y, other.width, other.height) then
                    return true
                end
            end
        end
        return false
    end)
end

function Breakout:updateGameLogic(dt)
    if self.game_over or self.victory then
        return
    end

    local Physics = self.di.components.PhysicsUtils
    local TableUtils = self.di.components.TableUtils

    local game_bounds = {
        x_min = 0,
        x_max = self.arena_width,
        y_min = 0,
        y_max = self.arena_height
    }
    self.projectile_system:update(dt, game_bounds)

    self.balls = self.projectile_system:getProjectiles()

    local game_bounds = {width = self.arena_width, height = self.arena_height}
    self.powerup_system:update(dt, self.paddle, game_bounds)

    self.powerups = self.powerup_system:getPowerupsForRendering()
    self.active_powerups = self.powerup_system:getActivePowerupsForHUD()

    -- Update visual effects
    self.visual_effects:update(dt)

    TableUtils.updateTimerMap(self.brick_flash_map, dt)

    self.popup_manager:update(dt)

    -- Update paddle
    self:updatePaddle(dt)

    -- Update sticky paddle aim
    if self.params.paddle_sticky then
        local aim_delta = (self:isKeyDown('d', 'right') and 2 or 0) - (self:isKeyDown('a', 'left') and 2 or 0)
        self.paddle.sticky_aim_angle = math.max(-math.pi * 0.95, math.min(-math.pi * 0.05, self.paddle.sticky_aim_angle + aim_delta * dt))
    end

    -- Update shoot cooldown
    if self.paddle.shoot_cooldown_timer > 0 then
        self.paddle.shoot_cooldown_timer = self.paddle.shoot_cooldown_timer - dt
    end

    -- Update balls
    for i = #self.balls, 1, -1 do
        local ball = self.balls[i]
        if ball.active then
            -- Emit ball trail particles
            self.visual_effects:emitBallTrail(ball.x, ball.y, ball.vx, ball.vy)

            self:updateBall(ball, dt)
        end
    end

    -- Update bullets
    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet.y = bullet.y + bullet.vy * dt
        if bullet.y < 0 then
            table.remove(self.bullets, i)
        else
            for _, brick in ipairs(self.bricks) do
                if brick.alive and Physics.rectCollision(bullet.x - bullet.width / 2, bullet.y - bullet.height / 2, bullet.width, bullet.height, brick.x, brick.y, brick.width, brick.height) then
                    brick.health = brick.health - self.params.paddle_shoot_damage
                    if brick.health <= 0 then self:onBrickDestroyed(brick, nil) end
                    table.remove(self.bullets, i)
                    break
                end
            end
        end
    end

    -- Update bricks (falling, moving, regenerating)
    self:updateBricks(dt)

    -- Check if all balls are lost
    if TableUtils.countActive(self.balls) == 0 then
        self.balls_lost = self.balls_lost + 1
        self.combo = 0  -- Reset combo on ball lost

        self.health_system:takeDamage(1, "ball_lost")
        self.lives = self.health_system.lives  -- Sync for HUD/VictoryCondition

        if not self.health_system:isAlive() then
            self.game_over = true
        else
            -- Respawn ball
            self:spawnBall()
        end
    end

    -- Check victory conditions
    self:checkVictoryConditions()

    -- Update metrics
    self.metrics.bricks_destroyed = self.bricks_destroyed
    self.metrics.balls_lost = self.balls_lost
    self.metrics.max_combo = self.max_combo
    self.metrics.score = self.score
    self.metrics.time_elapsed = self.time_elapsed
end

function Breakout:updatePaddle(dt)
    self.paddle_movement:update(dt, self.paddle, {
        left = self:isKeyDown('a', 'left'), right = self:isKeyDown('d', 'right')
    }, {x = 0, y = 0, width = self.arena_width, height = self.arena_height})
end

function Breakout:updateBall(ball, dt)
    local Physics = self.di.components.PhysicsUtils
    local p = self.params

    -- Core ball physics (gravity, homing, magnet, sticky, walls, paddle)
    local still_active = Physics.updateBallPhysics(ball, dt, {
        gravity = p.ball_gravity, gravity_direction = p.ball_gravity_direction,
        homing_strength = p.ball_homing_strength,
        homing_target_func = function() return self.entity_controller:findNearest(ball.x, ball.y, function(e) return e.alive end) end,
        magnet_range = p.paddle_magnet_range, magnet_strength = 800,
        sticky_enabled = p.paddle_sticky, paddle = self.paddle, paddle_sticky = p.paddle_sticky,
        paddle_aim_mode = p.paddle_aim_mode, max_speed = p.ball_max_speed,
        bounds = {width = self.arena_width, height = self.arena_height},
        ceiling_enabled = p.ceiling_enabled, bottom_kill_enabled = p.bottom_kill_enabled,
        shield_active = self.shield_active,
        wall_bounce_mode = p.wall_bounce_mode, bounce_randomness = p.ball_bounce_randomness, rng = self.rng,
        trail_length = p.ball_trail_length,
        on_paddle_hit = function() self.combo = 0 end
    })
    if not still_active then return end

    -- Brick collisions with game-specific scoring
    local PNGCollision = self.di.components.PNGCollision
    Physics.checkCircleEntityCollisions(ball, self.bricks, {
        check_func = function(b, brick)
            return brick.collision_image
                and PNGCollision.checkBall(brick.collision_image, brick.x, brick.y, b.x, b.y, b.radius, brick.alpha_threshold or 0.5)
                or Physics.checkCollision(b, brick, "circle", brick.shape)
        end,
        on_destroy = function(brick) self:onBrickDestroyed(brick, ball) end,
        on_hit = function(brick) if p.brick_flash_on_hit then self.brick_flash_map[brick] = 0.1 end end,
        speed_increase = p.ball_speed_increase_per_bounce, max_speed = p.ball_max_speed,
        bounce_randomness = p.ball_bounce_randomness, rng = self.rng
    })

    -- Obstacle collisions
    Physics.checkCircleEntityCollisions(ball, self.obstacles, {
        bounce_randomness = p.ball_bounce_randomness, rng = self.rng
    })
end

function Breakout:onBrickDestroyed(brick, ball)
    self.bricks_destroyed = self.bricks_destroyed + 1
    self.bricks_left = self.bricks_left - 1
    self.powerup_system:spawn(brick.x + brick.width / 2, brick.y + brick.height / 2)

    -- Visual effects
    self.visual_effects:emitBrickDestruction(brick.x + brick.width / 2, brick.y + brick.height / 2, {1, 0.5 + (brick.max_health - 1) * 0.1, 0})
    self.visual_effects:shake(0.15, self.params.camera_shake_intensity, "timer")

    -- Combo scoring
    self.combo = self.combo + 1
    self.max_combo = math.max(self.max_combo, self.combo)
    local points = self.params.brick_score_multiplier * (1 + self.combo * self.params.combo_multiplier)
    self.score = self.score + points

    -- Score popup
    if self.params.score_popup_enabled then
        local color = (self.combo == 5 or self.combo == 10 or self.combo == 15) and {1, 1, 0} or {1, 1, 1}
        self.popup_manager:add(brick.x + brick.width / 2, brick.y, "+" .. math.floor(points), color)
    end

    self:checkExtraBallThreshold()
end

function Breakout:keypressed(key)
    if key == "space" then
        -- Shooting
        if self.params.paddle_can_shoot and self.paddle.shoot_cooldown_timer <= 0 then
            table.insert(self.bullets, {x = self.paddle.x, y = self.paddle.y - self.paddle.height / 2 - 5, vy = -400, width = 4, height = 10})
            self.paddle.shoot_cooldown_timer = self.params.paddle_shoot_cooldown
        end

        -- Release sticky balls
        if self.params.paddle_sticky then
            local Physics = self.di.components.PhysicsUtils
            for _, ball in ipairs(self.balls) do
                Physics.releaseStickyBall(ball, self.paddle.width, 300, math.pi / 6)
            end
        end
    end
end

function Breakout:checkExtraBallThreshold()
    if self.health_system:checkExtraLifeAward(self.score) then
        self.lives = self.health_system.lives
        if self.params.score_popup_enabled then self.popup_manager:add(self.arena_width / 2, self.arena_height / 2, "EXTRA LIFE!", {0, 1, 0}) end
    end
end

function Breakout:checkVictoryConditions()
    local result = self.victory_checker:check()
    if not result then return end

    if result == "victory" and self.balls_lost == 0 and self.params.perfect_clear_bonus > 0 then
        self.score = self.score + self.params.perfect_clear_bonus
        if self.params.score_popup_enabled then self.popup_manager:add(self.arena_width / 2, self.arena_height / 2, "PERFECT CLEAR! +" .. self.params.perfect_clear_bonus, {0, 1, 0}) end
    end
    self.victory, self.game_over = result == "victory", result == "loss"
end

function Breakout:draw()
    self.view:draw()
end

return Breakout
