local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local Collision = require('src.utils.collision')
local BreakoutView = require('src.games.views.breakout_view')
local popup_module = require('src.games.score_popup')
local PopupManager = popup_module.PopupManager
local PNGCollision = require('src.utils.png_collision')
local MovementController = require('src.utils.game_components.movement_controller')
local FogOfWar = require('src.utils.game_components.fog_of_war')
local VisualEffects = require('src.utils.game_components.visual_effects')
local SchemaLoader = require('src.utils.game_components.schema_loader')
local HUDRenderer = require('src.utils.game_components.hud_renderer')
local VictoryCondition = require('src.utils.game_components.victory_condition')
local LivesHealthSystem = require('src.utils.game_components.lives_health_system')
local EntityController = require('src.utils.game_components.entity_controller')
local ProjectileSystem = require('src.utils.game_components.projectile_system')
local PowerupSystem = require('src.utils.game_components.powerup_system')
local Breakout = BaseGame:extend('Breakout')

function Breakout:setupComponents()
    local p = self.params

    self.paddle_movement = MovementController:new({
        mode = "direct", speed = p.paddle_speed,
        friction = p.paddle_friction, rail_axis = "horizontal"
    })

    self.projectile_system = ProjectileSystem:new({
        projectile_types = {
            ["ball"] = {
                speed = p.ball_speed, radius = p.ball_radius,
                movement_type = "bounce", lifetime = 999, team = "player",
                bounce_top = true, bounce_left = true, bounce_right = true, bounce_bottom = false
            }
        },
        pooling = false, max_projectiles = 50
    })

    self.entity_controller = EntityController:new({
        entity_types = {
            ["brick"] = {
                width = p.brick_width, height = p.brick_height,
                alive = true, vx = 0, vy = 0, regen_timer = 0,
                on_hit = function(brick, ball) self:onBrickHit(brick, ball) end
            }
        },
        spawning = {mode = "manual"}, pooling = false, max_entities = 500
    })

    self.powerup_system = PowerupSystem:new({
        enabled = p.powerup_enabled, spawn_mode = "event",
        spawn_drop_chance = p.brick_powerup_drop_chance, powerup_size = p.powerup_size,
        drop_speed = p.powerup_fall_speed, reverse_gravity = false,
        default_duration = p.powerup_duration, powerup_types = p.powerup_types,
        powerup_configs = p.powerup_config, color_map = {},
        on_collect = function(powerup) self:onPowerupCollect(powerup) end,
        on_apply = function(powerup_type, effect, config) self:applyPowerupEffect(powerup_type, effect, config) end,
        on_remove = function(powerup_type, effect) self:removePowerupEffect(powerup_type, effect) end
    })

    self.popup_manager = PopupManager:new()

    local starting_lives = p.lives
    if self.cheats.advantage_modifier then
        starting_lives = starting_lives + math.floor(self.cheats.advantage_modifier or 0)
    end

    self.health_system = LivesHealthSystem:new({
        mode = "lives", starting_lives = starting_lives, max_lives = 10,
        extra_life_enabled = true, extra_life_threshold = p.extra_ball_score_threshold
    })
    self.lives = self.health_system.lives

    self.hud = HUDRenderer:new({
        primary = {label = "Score", key = "score"},
        secondary = {label = "Bricks", key = "bricks_left"},
        lives = {key = "lives", max = starting_lives, style = "hearts"}
    })
    self.hud.game = self

    self.fog_controller = FogOfWar:new({enabled = p.fog_of_war_enabled, mode = "stencil", opacity = 0.8})
    self.visual_effects = VisualEffects:new({
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
    self.victory_checker = VictoryCondition:new(vc)
    self.victory_checker.game = self
end

function Breakout:init(game_data, cheats, di, variant_override)
    Breakout.super.init(self, game_data, cheats, di, variant_override)
    self.di = di
    self.cheats = cheats or {}

    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.breakout)
    self.params = SchemaLoader.load(self.variant, "breakout_schema", runtimeCfg)

    self:applyModifiers()
    self:setupGameState()
    self:setupPaddle()
    self:setupComponents()
    self:setupEntities()

    self.view = BreakoutView:new(self)
end

function Breakout:setupGameState()
    self.rng = love.math.newRandomGenerator(self.seed or os.time())
    self.arena_width = 800
    self.arena_height = 600
    self.game_over = false
    self.victory = false
    self.score = 0
    self.combo = 0
    self.max_combo = 0
    self.bricks_destroyed = 0
    self.bricks_left = 0
    self.balls_lost = 0
    self.last_extra_ball_threshold = 0
    self.time_elapsed = 0
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
    for i = 1, self.ball_count do
        self:spawnBall()
    end
    self.bullets = {}
    self.obstacles = {}
    self:generateObstacles()
    self:generateBricks()
    self.powerups = {}
    self.active_powerups = {}
    self.shield_active = false
    self.metrics = {
        bricks_destroyed = 0, balls_lost = 0,
        max_combo = 0, score = 0, time_elapsed = 0
    }
end

function Breakout:applyModifiers()
    -- Initialize mutable values from params (these get modified by cheats/powerups)
    self.ball_speed = self.params.ball_speed
    self.ball_max_speed = self.params.ball_max_speed
    self.paddle_speed = self.params.paddle_speed
    self.paddle_width = self.params.paddle_width
    self.ball_count = self.params.ball_count
    self.paddle_can_shoot = self.params.paddle_can_shoot
    self.paddle_sticky = self.params.paddle_sticky
    self.ball_phase_through_bricks = self.params.ball_phase_through_bricks
    self.paddle_magnet_range = self.params.paddle_magnet_range
    self.paddle_shoot_cooldown = self.params.paddle_shoot_cooldown

    -- Apply difficulty_modifier from variant
    if self.variant and self.variant.difficulty_modifier then
        self.ball_speed = self.ball_speed * self.variant.difficulty_modifier
        self.ball_max_speed = self.ball_max_speed * self.variant.difficulty_modifier
        self.paddle_speed = self.paddle_speed * self.variant.difficulty_modifier
    end

    -- Apply CheatEngine modifications
    if self.cheats.speed_modifier then
        self.paddle_speed = self.paddle_speed * self.cheats.speed_modifier
        self.ball_speed = self.ball_speed * self.cheats.speed_modifier
        self.ball_max_speed = self.ball_max_speed * self.cheats.speed_modifier
    end
    if self.cheats.advantage_modifier then
        self.paddle_width = self.paddle_width * (1 + (self.cheats.advantage_modifier or 0) * 0.1)
    end
    if self.cheats.performance_modifier then
        self.ball_count = self.ball_count + math.floor((self.cheats.performance_modifier or 0) / 3)
    end
end

function Breakout:setPlayArea(width, height)
    local old_width = self.arena_width
    local old_height = self.arena_height

    self.arena_width = width
    self.arena_height = height

    -- Calculate offset to center bricks (don't scale, just reposition)
    local offset_x = (width - old_width) / 2
    local offset_y = 0  -- Keep bricks at top

    -- Offset brick positions to center them
    if self.bricks then
        for _, brick in ipairs(self.bricks) do
            brick.x = brick.x + offset_x
        end
    end

    -- Keep paddle at bottom center
    if self.paddle then
        self.paddle.y = self.arena_height - 50
        -- Clamp paddle to new bounds
        self.paddle.x = math.max(self.paddle.width / 2, math.min(self.paddle.x, self.arena_width - self.paddle.width / 2))
    end

    -- Offset ball positions
    if self.balls then
        for _, ball in ipairs(self.balls) do
            ball.x = ball.x + offset_x
            -- Clamp to new bounds
            ball.x = math.max(ball.radius, math.min(self.arena_width - ball.radius, ball.x))
            ball.y = math.max(ball.radius, math.min(self.arena_height - ball.radius, ball.y))
        end
    end

    -- Offset obstacle positions
    if self.obstacles then
        for _, obstacle in ipairs(self.obstacles) do
            obstacle.x = obstacle.x + offset_x
        end
    end

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
            pierce_count = self.ball_phase_through_bricks,  -- For phase-through bricks
            trail = {}  -- Position history for trail rendering
        }
    )
end

function Breakout:generateObstacles()
    self.obstacles = {}

    for i = 1, self.params.obstacles_count do
        local size = 40
        local obstacle = {
            x = 100 + self.rng:random() * (self.arena_width - 200),
            y = 150 + self.rng:random() * (self.arena_height * 0.4),
            size = size,
            shape = self.params.obstacles_shape,
            health = self.params.obstacles_destructible and 3 or math.huge,
            max_health = self.params.obstacles_destructible and 3 or math.huge,
            alive = true
        }
        table.insert(self.obstacles, obstacle)
    end
end

function Breakout:addBrick(brick_data)
    local brick = self.entity_controller:spawn("brick", brick_data.x, brick_data.y, {
        health = brick_data.health or self.params.brick_health,
        max_health = brick_data.max_health or self.params.brick_health,
        shape = brick_data.shape or self.params.brick_shape,
        radius = brick_data.radius or self.params.brick_radius,
        collision_image = brick_data.collision_image or self.shared_collision_image_data,
        display_image = brick_data.display_image or self.shared_display_image,
        alpha_threshold = brick_data.alpha_threshold or self.params.brick_alpha_threshold
    })

    if brick and not self:canPlaceBrick(brick) then
        self.entity_controller:removeEntity(brick)
        return nil
    end

    return brick
end

function Breakout:generateBricks()
    self.entity_controller:clear()
    self.bricks = {}  -- Keep legacy array for backward compatibility

    -- Load collision/display images once for all bricks (shared)
    self.shared_collision_image_data = nil
    self.shared_display_image = nil
    if self.params.brick_collision_image and self.params.brick_collision_image ~= "" then
        self.shared_collision_image_data = PNGCollision.loadCollisionImage(self.params.brick_collision_image)
        local success, img = pcall(love.graphics.newImage, self.params.brick_collision_image)
        if success and img then
            self.shared_display_image = img
        end
    end

    if self.params.brick_layout == "grid" then
        self:generateGridLayout()
    elseif self.params.brick_layout == "pyramid" then
        self:generatePyramidLayout()
    elseif self.params.brick_layout == "circle" then
        self:generateCircleLayout()
    elseif self.params.brick_layout == "random" then
        self:generateRandomLayout()
    elseif self.params.brick_layout == "checkerboard" then
        self:generateCheckerboardLayout()
    else
        -- Default to grid
        self:generateGridLayout()
    end

    self.bricks = self.entity_controller:getEntities()

    self.bricks_left = #self.bricks
end

function Breakout:generateGridLayout()
    local total_width = self.params.brick_columns * (self.params.brick_width + self.params.brick_padding)
    local start_x = (self.arena_width - total_width) / 2
    local start_y = 60

    for row = 1, self.params.brick_rows do
        for col = 1, self.params.brick_columns do
            self:addBrick({
                x = start_x + (col - 1) * (self.params.brick_width + self.params.brick_padding),
                y = start_y + (row - 1) * (self.params.brick_height + self.params.brick_padding)
            })
        end
    end
end

function Breakout:generatePyramidLayout()
    -- Triangle formation - more bricks at top, fewer at bottom (inverted pyramid)
    local start_y = 60
    local max_cols = self.params.brick_columns or 10

    for row = 1, self.params.brick_rows do
        local cols_this_row = max_cols - (row - 1)
        if cols_this_row < 1 then break end

        local total_width = cols_this_row * (self.params.brick_width + self.params.brick_padding)
        local start_x = (self.arena_width - total_width) / 2

        for col = 1, cols_this_row do
            self:addBrick({
                x = start_x + (col - 1) * (self.params.brick_width + self.params.brick_padding),
                y = start_y + (row - 1) * (self.params.brick_height + self.params.brick_padding)
            })
        end
    end
end

function Breakout:generateCircleLayout()
    -- Concentric circles of bricks
    local center_x = self.arena_width / 2
    local center_y = 200
    local rings = self.params.brick_rows or 5
    local bricks_per_ring = 12

    for ring = 1, rings do
        local radius = ring * 40
        local bricks_this_ring = bricks_per_ring + (ring - 1) * 2  -- More bricks in outer rings

        for i = 1, bricks_this_ring do
            local angle = (i / bricks_this_ring) * math.pi * 2
            self:addBrick({
                x = center_x + math.cos(angle) * radius - self.params.brick_width / 2,
                y = center_y + math.sin(angle) * radius - self.params.brick_height / 2
            })
        end
    end
end

function Breakout:generateRandomLayout()
    -- Scattered random placement
    local brick_count = (self.params.brick_rows or 5) * (self.params.brick_columns or 10)
    local margin = 40
    local max_attempts = brick_count * 10  -- Prevent infinite loops
    local placed = 0

    for attempt = 1, max_attempts do
        if placed >= brick_count then break end

        local added = self:addBrick({
            x = margin + self.rng:random() * (self.arena_width - self.params.brick_width - margin * 2),
            y = margin + self.rng:random() * (self.arena_height * 0.4)  -- Top 40% of arena
        })

        if added then
            placed = placed + 1
        end
    end
end

function Breakout:generateCheckerboardLayout()
    -- Checkerboard pattern with gaps
    local total_width = self.params.brick_columns * (self.params.brick_width + self.params.brick_padding)
    local start_x = (self.arena_width - total_width) / 2
    local start_y = 60

    for row = 1, self.params.brick_rows do
        for col = 1, self.params.brick_columns do
            -- Skip every other brick in checkerboard pattern
            if (row + col) % 2 == 0 then
                self:addBrick({
                    x = start_x + (col - 1) * (self.params.brick_width + self.params.brick_padding),
                    y = start_y + (row - 1) * (self.params.brick_height + self.params.brick_padding)
                })
            end
        end
    end
end

function Breakout:canPlaceBrick(new_brick)
    -- If overlap is allowed, always allow placement
    if self.params.bricks_can_overlap then
        return true
    end

    local existing_bricks = self.entity_controller:getEntities()
    for _, existing in ipairs(existing_bricks) do
        if existing ~= new_brick and existing.alive then
            if self:checkBrickBrickCollision(new_brick, existing, new_brick.x, new_brick.y) then
                return false
            end
        end
    end

    return true
end

function Breakout:updateBricks(dt)
    self.bricks = self.entity_controller:getEntities()

    for _, brick in ipairs(self.bricks) do
        -- Falling bricks
        if self.params.brick_fall_enabled and brick.alive then
            local new_y = brick.y + self.params.brick_fall_speed * dt

            -- Check collision with other bricks if overlap is disabled
            if not self.params.bricks_can_overlap then
                local collides = false
                for _, other in ipairs(self.bricks) do
                    if other ~= brick and other.alive then
                        if self:checkBrickBrickCollision(brick, other, brick.x, new_y) then
                            collides = true
                            break
                        end
                    end
                end
                if not collides then
                    brick.y = new_y
                end
            else
                brick.y = new_y
            end

            -- Check if bricks reached paddle (game over condition)
            if brick.y > self.paddle.y - 30 then
                self.game_over = true
            end
        end

        -- Moving bricks (horizontal drift)
        if self.params.brick_movement_enabled and brick.alive then
            -- Initialize velocity if not set
            if brick.vx == 0 then
                brick.vx = self.params.brick_movement_speed * (self.rng:random() < 0.5 and 1 or -1)
            end

            local new_x = brick.x + brick.vx * dt

            -- Check collision with other bricks if overlap is disabled
            if not self.params.bricks_can_overlap then
                local collides = false
                for _, other in ipairs(self.bricks) do
                    if other ~= brick and other.alive then
                        if self:checkBrickBrickCollision(brick, other, new_x, brick.y) then
                            collides = true
                            -- Reverse direction on collision with other brick
                            brick.vx = -brick.vx
                            break
                        end
                    end
                end
                if not collides then
                    brick.x = new_x
                end
            else
                brick.x = new_x
            end

            -- Bounce off walls
            if brick.x < 0 or brick.x + brick.width > self.arena_width then
                brick.vx = -brick.vx
                brick.x = math.max(0, math.min(brick.x, self.arena_width - brick.width))
            end
        end

        -- Regenerating bricks
        if self.params.brick_regeneration_enabled and not brick.alive then
            brick.regen_timer = brick.regen_timer + dt

            if brick.regen_timer >= self.params.brick_regeneration_time then
                -- Check if regeneration position is clear if overlap is disabled
                if not self.params.bricks_can_overlap then
                    local space_clear = true
                    for _, other in ipairs(self.bricks) do
                        if other ~= brick and other.alive then
                            if self:checkBrickBrickCollision(brick, other, brick.x, brick.y) then
                                space_clear = false
                                break
                            end
                        end
                    end
                    if space_clear then
                        brick.alive = true
                        brick.health = brick.max_health
                        brick.regen_timer = 0
                    end
                    -- If not clear, keep waiting (timer continues)
                else
                    brick.alive = true
                    brick.health = brick.max_health
                    brick.regen_timer = 0
                end
            end
        end
    end
end

function Breakout:checkBrickBrickCollision(brick1, brick2, test_x, test_y)
    -- Check AABB collision between two bricks at test position
    local b1_left = test_x
    local b1_right = test_x + brick1.width
    local b1_top = test_y
    local b1_bottom = test_y + brick1.height

    local b2_left = brick2.x
    local b2_right = brick2.x + brick2.width
    local b2_top = brick2.y
    local b2_bottom = brick2.y + brick2.height

    return b1_right > b2_left and
           b1_left < b2_right and
           b1_bottom > b2_top and
           b1_top < b2_bottom
end

function Breakout:updateGameLogic(dt)
    if self.game_over or self.victory then
        return
    end

    -- NOTE: time_elapsed is already incremented in BaseGame:updateBase, don't double-increment!

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

    -- Update brick flash map
    for brick, flash_timer in pairs(self.brick_flash_map) do
        self.brick_flash_map[brick] = flash_timer - dt
        if self.brick_flash_map[brick] <= 0 then
            self.brick_flash_map[brick] = nil
        end
    end

    self.popup_manager:update(dt)

    -- Update paddle
    self:updatePaddle(dt)

    -- Update sticky paddle aim
    if self.paddle_sticky then
        if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
            self.paddle.sticky_aim_angle = self.paddle.sticky_aim_angle - 2.0 * dt
        end
        if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
            self.paddle.sticky_aim_angle = self.paddle.sticky_aim_angle + 2.0 * dt
        end
        -- Clamp aim angle to upward hemisphere
        self.paddle.sticky_aim_angle = math.max(-math.pi * 0.95, math.min(-math.pi * 0.05, self.paddle.sticky_aim_angle))
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

        -- Remove bullets that go off screen
        if bullet.y < 0 then
            table.remove(self.bullets, i)
        else
            -- Check bullet-brick collision
            for _, brick in ipairs(self.bricks) do
                if brick.alive and self:checkBulletBrickCollision(bullet, brick) then
                    brick.health = brick.health - self.params.paddle_shoot_damage
                    if brick.health <= 0 then
                        brick.alive = false
                        self.bricks_destroyed = self.bricks_destroyed + 1
                        self.bricks_left = self.bricks_left - 1

                        self.powerup_system:spawn(brick.x + brick.width / 2, brick.y + brick.height / 2)

                        -- Award score for bullet kill (no combo bonus for bullets)
                        local points = self.params.brick_score_multiplier
                        self.score = self.score + points

                        -- Spawn score popup (white for normal scoring)
                        if self.params.score_popup_enabled then
                            self.popup_manager:add(brick.x + brick.width / 2, brick.y, "+" .. math.floor(points), {1, 1, 1})
                        end

                        -- Check for extra ball threshold
                        self:checkExtraBallThreshold()
                    end
                    table.remove(self.bullets, i)
                    break
                end
            end
        end
    end

    -- Update bricks (falling, moving, regenerating)
    self:updateBricks(dt)

    -- Check if all balls are lost
    local active_balls = 0
    for _, ball in ipairs(self.balls) do
        if ball.active then
            active_balls = active_balls + 1
        end
    end

    if active_balls == 0 then
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
    -- Build input table from keyboard state
    local input = {
        left = love.keyboard.isDown('a') or love.keyboard.isDown('left'),
        right = love.keyboard.isDown('d') or love.keyboard.isDown('right'),
        up = false,
        down = false,
        jump = false
    }

    -- Build bounds table for arena
    -- Paddle uses center-based positioning with radius
    local bounds = {
        x = 0,
        y = 0,
        width = self.arena_width,
        height = self.arena_height,
        wrap_x = false,
        wrap_y = false
    }

    -- Use MovementController to update paddle
    self.paddle_movement:update(dt, self.paddle, input, bounds)
end

function Breakout:updateBall(ball, dt)
    -- Apply directional gravity if enabled
    if self.params.ball_gravity ~= 0 then
        local gravity_rad = math.rad(self.params.ball_gravity_direction)
        ball.vx = ball.vx + math.cos(gravity_rad) * self.params.ball_gravity * dt
        ball.vy = ball.vy + math.sin(gravity_rad) * self.params.ball_gravity * dt
    end

    -- Apply homing toward nearest brick
    if self.params.ball_homing_strength > 0 then
        local nearest_brick = self:findNearestBrick(ball.x, ball.y)
        if nearest_brick then
            local dx = nearest_brick.x - ball.x
            local dy = nearest_brick.y - ball.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                -- Apply homing force
                local homing_force = self.params.ball_homing_strength * 50
                ball.vx = ball.vx + (dx / dist) * homing_force * dt
                ball.vy = ball.vy + (dy / dist) * homing_force * dt
            end
        end
    end

    -- Update magnet immunity timer
    if ball.magnet_immunity_timer and ball.magnet_immunity_timer > 0 then
        ball.magnet_immunity_timer = ball.magnet_immunity_timer - dt
    end

    -- Apply magnet paddle force
    -- Only attract when ball is moving downward (vy > 0) and not immune
    local magnet_immune = ball.magnet_immunity_timer and ball.magnet_immunity_timer > 0
    if self.paddle_magnet_range > 0 and not (ball.stuck and self.paddle_sticky) and ball.vy > 0 and not magnet_immune then
        local dx = self.paddle.x - ball.x
        local dy = self.paddle.y - ball.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < self.paddle_magnet_range and dist > 0 then
            -- Force increases as ball gets closer (stronger force since we only apply when moving down)
            local force_strength = (1 - dist / self.paddle_magnet_range) * 800
            ball.vx = ball.vx + (dx / dist) * force_strength * dt
            ball.vy = ball.vy + (dy / dist) * force_strength * dt
        end
    end

    -- Handle sticky paddle
    if ball.stuck and self.paddle_sticky then
        -- Ball moves with paddle
        ball.x = self.paddle.x + ball.stuck_offset_x
        ball.y = self.paddle.y + ball.stuck_offset_y
        return  -- Don't update physics while stuck
    end

    -- Update position
    ball.x = ball.x + ball.vx * dt
    ball.y = ball.y + ball.vy * dt

    -- Update trail (store position history)
    if self.params.ball_trail_length > 0 then
        table.insert(ball.trail, 1, {x = ball.x, y = ball.y})
        -- Keep trail at max length
        while #ball.trail > self.params.ball_trail_length do
            table.remove(ball.trail)
        end
    end

    -- Wall collisions (left, right)
    if ball.x - ball.radius < 0 then
        ball.x = ball.radius
        self:applyWallBounce(ball, 'vx')
    elseif ball.x + ball.radius > self.arena_width then
        ball.x = self.arena_width - ball.radius
        self:applyWallBounce(ball, 'vx')
    end

    -- Top boundary
    if ball.y - ball.radius < 0 then
        if self.params.ceiling_enabled then
            ball.y = ball.radius
            self:applyWallBounce(ball, 'vy')
        else
            -- No ceiling - ball escapes upward (game over)
            ball.active = false
            return
        end
    end

    -- Bottom boundary
    if ball.y - ball.radius > self.arena_height then
        if self.params.bottom_kill_enabled then
            -- Check shield power-up
            if self.shield_active then
                -- Shield blocks one miss
                self.shield_active = false
                ball.y = self.arena_height - ball.radius
                ball.vy = -math.abs(ball.vy)  -- Bounce up
            else
                ball.active = false
                return
            end
        else
            -- Bottom bounce instead of kill
            ball.y = self.arena_height - ball.radius
            self:applyWallBounce(ball, 'vy')
        end
    end

    -- Paddle collision
    if self:checkBallPaddleCollision(ball) then
        if self.paddle_sticky and not ball.stuck then
            -- Sticky paddle - catch the ball
            ball.stuck = true
            ball.stuck_offset_x = ball.x - self.paddle.x
            ball.stuck_offset_y = ball.y - self.paddle.y
            ball.vx = 0
            ball.vy = 0

            -- Reset combo when ball touches paddle
            self.combo = 0
        else
            -- Position ball above paddle
            ball.y = self.paddle.y - ball.radius - self.paddle.height / 2

            if self.params.paddle_aim_mode == "position" then
                -- Position mode: Calculate angle based purely on hit position (like sticky paddle launch)
                local offset_x = ball.x - self.paddle.x
                local max_offset = self.paddle.width / 2
                local normalized_offset = math.max(-1, math.min(1, offset_x / max_offset))

                -- Map offset to angle: -1 (left) = 225°, 0 (center) = 270°, +1 (right) = 315°
                local angle = -math.pi / 2 + normalized_offset * (math.pi / 4)  -- ±45° range

                -- Set velocity based on calculated angle, preserving speed
                local current_speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
                ball.vx = math.cos(angle) * current_speed
                ball.vy = math.sin(angle) * current_speed
            else
                -- Default mode: Preserve momentum, add spin based on hit position
                ball.vy = -math.abs(ball.vy)
                local hit_pos = (ball.x - self.paddle.x) / (self.paddle.width / 2)
                ball.vx = ball.vx + hit_pos * 100
            end

            -- Reset combo when ball touches paddle
            self.combo = 0

            -- Apply bounce randomness after paddle hit
            if self.params.ball_bounce_randomness > 0 then
                local current_speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
                local current_angle = math.atan2(ball.vy, ball.vx)
                local angle_variance = (self.rng:random() - 0.5) * self.params.ball_bounce_randomness * math.pi
                local new_angle = current_angle + angle_variance
                ball.vx = math.cos(new_angle) * current_speed
                ball.vy = math.sin(new_angle) * current_speed
            end

            -- Clamp speed
            local speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
            if speed > self.ball_max_speed then
                local scale = self.ball_max_speed / speed
                ball.vx = ball.vx * scale
                ball.vy = ball.vy * scale
            end
        end
    end

    -- Brick collisions
    for _, brick in ipairs(self.bricks) do
        if brick.alive and self:checkBallBrickCollision(ball, brick) then
            -- Damage brick
            brick.health = brick.health - 1
            if brick.health <= 0 then
                brick.alive = false
                self.bricks_destroyed = self.bricks_destroyed + 1
                self.bricks_left = self.bricks_left - 1

                self.powerup_system:spawn(brick.x + brick.width / 2, brick.y + brick.height / 2)

                -- Visual effects: brick destruction particles + camera shake
                local brick_color = {1, 0.5 + (brick.max_health - 1) * 0.1, 0}
                self.visual_effects:emitBrickDestruction(brick.x + brick.width / 2, brick.y + brick.height / 2, brick_color)
                self.visual_effects:shake(0.15, self.params.camera_shake_intensity, "timer")

                -- Award score with combo multiplier
                self.combo = self.combo + 1
                if self.combo > self.max_combo then
                    self.max_combo = self.combo
                end

                -- Calculate points: base * (1 + combo * combo_multiplier)
                -- Example: combo=5, combo_multiplier=0.5 -> 1 + 5*0.5 = 3.5x multiplier
                local combo_bonus = 1 + (self.combo * self.params.combo_multiplier)
                local points = self.params.brick_score_multiplier * combo_bonus
                self.score = self.score + points

                -- Spawn score popup
                if self.params.score_popup_enabled then
                    local popup_color = {1, 1, 1}  -- White for normal scoring
                    -- Yellow for combo milestones at 5/10/15
                    if self.combo == 5 or self.combo == 10 or self.combo == 15 then
                        popup_color = {1, 1, 0}
                    end
                    self.popup_manager:add(brick.x + brick.width / 2, brick.y, "+" .. math.floor(points), popup_color)
                end

                -- Check for extra ball threshold
                self:checkExtraBallThreshold()
            else
                -- Brick damaged but not destroyed: flash effect
                if self.params.brick_flash_on_hit then
                    self.brick_flash_map[brick] = 0.1  -- Flash for 100ms
                end
            end

            -- Check if ball should phase through or bounce
            if ball.pierce_count and ball.pierce_count > 0 then
                -- Reduce pierce count but don't bounce
                ball.pierce_count = ball.pierce_count - 1
            else
                -- Bounce based on brick shape
                if brick.collision_image then
                    -- PNG collision - estimate surface normal at collision point
                    local nx, ny = PNGCollision.estimateNormal(
                        brick.collision_image,
                        brick.x,
                        brick.y,
                        ball.x,
                        ball.y,
                        ball.radius,
                        brick.alpha_threshold or 0.5
                    )

                    -- Preserve speed before reflection
                    local speed_before = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)

                    -- Reflect velocity: v' = v - 2(v·n)n
                    local dot = ball.vx * nx + ball.vy * ny
                    ball.vx = ball.vx - 2 * dot * nx
                    ball.vy = ball.vy - 2 * dot * ny

                    -- Restore original speed (prevent energy loss from numerical errors)
                    local speed_after = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
                    if speed_after > 0 then
                        local speed_scale = speed_before / speed_after
                        ball.vx = ball.vx * speed_scale
                        ball.vy = ball.vy * speed_scale
                    end

                    -- Push ball out along normal (more aggressive to prevent re-collision)
                    ball.x = ball.x + nx * (ball.radius + 5)
                    ball.y = ball.y + ny * (ball.radius + 5)

                elseif brick.shape == "circle" then
                    -- Circle collision - reflect off surface normal
                    local brick_center_x = brick.x + (brick.radius or brick.width / 2)
                    local brick_center_y = brick.y + (brick.radius or brick.height / 2)

                    -- Calculate normal vector from brick center to ball
                    local nx = ball.x - brick_center_x
                    local ny = ball.y - brick_center_y
                    local normal_length = math.sqrt(nx * nx + ny * ny)

                    if normal_length > 0 then
                        -- Normalize
                        nx = nx / normal_length
                        ny = ny / normal_length

                        -- Preserve speed before reflection
                        local speed_before = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)

                        -- Reflect velocity: v' = v - 2(v·n)n
                        local dot = ball.vx * nx + ball.vy * ny
                        ball.vx = ball.vx - 2 * dot * nx
                        ball.vy = ball.vy - 2 * dot * ny

                        -- Restore original speed
                        local speed_after = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
                        if speed_after > 0 then
                            local speed_scale = speed_before / speed_after
                            ball.vx = ball.vx * speed_scale
                            ball.vy = ball.vy * speed_scale
                        end

                        -- Push ball out of circle
                        local brick_radius = brick.radius or brick.width / 2
                        local separation = brick_radius + ball.radius
                        ball.x = brick_center_x + nx * separation
                        ball.y = brick_center_y + ny * separation
                    end
                else
                    -- Rectangle collision - determine which side was hit
                    local brick_left = brick.x
                    local brick_right = brick.x + brick.width
                    local brick_top = brick.y
                    local brick_bottom = brick.y + brick.height
                    local brick_center_x = brick.x + brick.width / 2
                    local brick_center_y = brick.y + brick.height / 2

                    -- Calculate penetration depth from each side
                    local pen_left = (ball.x + ball.radius) - brick_left
                    local pen_right = brick_right - (ball.x - ball.radius)
                    local pen_top = (ball.y + ball.radius) - brick_top
                    local pen_bottom = brick_bottom - (ball.y - ball.radius)

                    -- Find minimum penetration (side that was hit)
                    local min_pen = math.min(pen_left, pen_right, pen_top, pen_bottom)

                    if min_pen == pen_top then
                        -- Hit from top
                        ball.y = brick_top - ball.radius - 1
                        ball.vy = -math.abs(ball.vy)
                    elseif min_pen == pen_bottom then
                        -- Hit from bottom
                        ball.y = brick_bottom + ball.radius + 1
                        ball.vy = math.abs(ball.vy)
                    elseif min_pen == pen_left then
                        -- Hit from left
                        ball.x = brick_left - ball.radius - 1
                        ball.vx = -math.abs(ball.vx)
                    else
                        -- Hit from right
                        ball.x = brick_right + ball.radius + 1
                        ball.vx = math.abs(ball.vx)
                    end
                end
            end

            -- Increase ball speed if enabled
            if self.params.ball_speed_increase_per_bounce > 0 then
                local current_speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
                local new_speed = math.min(current_speed + self.params.ball_speed_increase_per_bounce, self.ball_max_speed)
                if current_speed > 0 then
                    local scale = new_speed / current_speed
                    ball.vx = ball.vx * scale
                    ball.vy = ball.vy * scale
                end
            end

            -- Apply bounce randomness after brick hit
            if self.params.ball_bounce_randomness > 0 and not (ball.pierce_count and ball.pierce_count > 0) then
                local current_speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
                local current_angle = math.atan2(ball.vy, ball.vx)
                local angle_variance = (self.rng:random() - 0.5) * self.params.ball_bounce_randomness * math.pi
                local new_angle = current_angle + angle_variance
                ball.vx = math.cos(new_angle) * current_speed
                ball.vy = math.sin(new_angle) * current_speed
            end

            -- Only process one brick collision per frame
            if not (ball.pierce_count and ball.pierce_count > 0) then
                break
            end
        end
    end

    -- Obstacle collisions
    for _, obstacle in ipairs(self.obstacles) do
        if obstacle.alive and self:checkBallObstacleCollision(ball, obstacle) then
            -- Bounce ball off obstacle
            ball.vy = -ball.vy

            -- Damage obstacle if destructible
            if self.params.obstacles_destructible then
                obstacle.health = obstacle.health - 1
                if obstacle.health <= 0 then
                    obstacle.alive = false
                end
            end

            break  -- Only one obstacle collision per frame
        end
    end
end

function Breakout:findNearestBrick(x, y)
    local nearest = nil
    local min_dist = math.huge

    for _, brick in ipairs(self.bricks) do
        if brick.alive then
            local dx = brick.x - x
            local dy = brick.y - y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < min_dist then
                min_dist = dist
                nearest = brick
            end
        end
    end

    return nearest
end

function Breakout:checkBallPaddleCollision(ball)
    local paddle_left = self.paddle.x - self.paddle.width / 2
    local paddle_right = self.paddle.x + self.paddle.width / 2
    local paddle_top = self.paddle.y - self.paddle.height / 2
    local paddle_bottom = self.paddle.y + self.paddle.height / 2

    return ball.x + ball.radius > paddle_left and
           ball.x - ball.radius < paddle_right and
           ball.y + ball.radius > paddle_top and
           ball.y - ball.radius < paddle_bottom
end

function Breakout:checkBallBrickCollision(ball, brick)
    -- PNG pixel-perfect collision (highest priority)
    if brick.collision_image then
        return PNGCollision.checkBall(
            brick.collision_image,
            brick.x,
            brick.y,
            ball.x,
            ball.y,
            ball.radius,
            brick.alpha_threshold or 0.5
        )
    elseif brick.shape == "circle" then
        -- Circle-circle collision (ball vs circle brick)
        -- For circle bricks, x and y are top-left corner, so center is x + radius, y + radius
        local brick_center_x = brick.x + (brick.radius or brick.width / 2)
        local brick_center_y = brick.y + (brick.radius or brick.height / 2)
        local dx = ball.x - brick_center_x
        local dy = ball.y - brick_center_y
        local dist = math.sqrt(dx * dx + dy * dy)
        return dist < (ball.radius + (brick.radius or brick.width / 2))
    else
        -- Rectangle collision (ball vs rectangle brick - default)
        local brick_left = brick.x
        local brick_right = brick.x + brick.width
        local brick_top = brick.y
        local brick_bottom = brick.y + brick.height

        return ball.x + ball.radius > brick_left and
               ball.x - ball.radius < brick_right and
               ball.y + ball.radius > brick_top and
               ball.y - ball.radius < brick_bottom
    end
end

function Breakout:checkBallObstacleCollision(ball, obstacle)
    if obstacle.shape == "circle" then
        -- Circle-circle collision
        local dx = ball.x - (obstacle.x + obstacle.size / 2)
        local dy = ball.y - (obstacle.y + obstacle.size / 2)
        local dist = math.sqrt(dx * dx + dy * dy)
        return dist < (ball.radius + obstacle.size / 2)
    else
        -- Rectangle collision (default)
        return ball.x + ball.radius > obstacle.x and
               ball.x - ball.radius < obstacle.x + obstacle.size and
               ball.y + ball.radius > obstacle.y and
               ball.y - ball.radius < obstacle.y + obstacle.size
    end
end

function Breakout:applyWallBounce(ball, axis)
    if self.params.wall_bounce_mode == "damped" then
        -- Damped bounce - lose 10% energy per wall bounce (not compound, stays playable)
        ball[axis] = -ball[axis] * 0.9
    elseif self.params.wall_bounce_mode == "sticky" then
        -- Sticky wall - ball loses significant energy but doesn't crawl
        ball[axis] = -ball[axis] * 0.6
    elseif self.params.wall_bounce_mode == "wrap" then
        -- Asteroids-style wrap (not implemented for simplicity - would need repositioning logic)
        ball[axis] = -ball[axis]
    else
        -- Normal elastic bounce
        ball[axis] = -ball[axis]
    end

    -- Apply bounce randomness (rotate velocity by random angle)
    if self.params.ball_bounce_randomness > 0 then
        -- Get current angle and speed
        local current_speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
        local current_angle = math.atan2(ball.vy, ball.vx)

        -- Add random angle variance (randomness is in radians)
        local angle_variance = (self.rng:random() - 0.5) * self.params.ball_bounce_randomness * math.pi
        local new_angle = current_angle + angle_variance

        -- Set velocity to new angle with SAME speed
        ball.vx = math.cos(new_angle) * current_speed
        ball.vy = math.sin(new_angle) * current_speed
    end
end

function Breakout:keypressed(key)
    if key == "space" then
        -- Shooting
        if self.paddle_can_shoot and self.paddle.shoot_cooldown_timer <= 0 then
            local bullet = {
                x = self.paddle.x,
                y = self.paddle.y - self.paddle.height / 2 - 5,
                vy = -400,  -- Upward velocity
                width = 4,
                height = 10
            }
            table.insert(self.bullets, bullet)
            self.paddle.shoot_cooldown_timer = self.paddle_shoot_cooldown
        end

        -- Release sticky ball
        if self.paddle_sticky then
            for _, ball in ipairs(self.balls) do
                if ball.stuck then
                    ball.stuck = false
                    -- Calculate launch angle based on ball position relative to paddle center
                    local offset_x = ball.stuck_offset_x  -- Horizontal offset from paddle center
                    local max_offset = self.paddle.width / 2  -- Maximum horizontal offset
                    local normalized_offset = math.max(-1, math.min(1, offset_x / max_offset))  -- -1 to 1

                    -- Map offset to angle: -1 (left edge) = -75°, 0 (center) = -90°, +1 (right edge) = -105°
                    local angle = -math.pi / 2 + normalized_offset * (math.pi / 6)  -- ±30° range

                    -- Launch ball
                    local launch_speed = 300
                    ball.vx = math.cos(angle) * launch_speed
                    ball.vy = math.sin(angle) * launch_speed

                    -- Prevent magnet from immediately pulling ball back down after release
                    ball.magnet_immunity_timer = 0.3  -- 300ms immunity
                end
            end
        end
    end
end

function Breakout:checkBulletBrickCollision(bullet, brick)
    return bullet.x + bullet.width / 2 > brick.x and
           bullet.x - bullet.width / 2 < brick.x + brick.width and
           bullet.y + bullet.height / 2 > brick.y and
           bullet.y - bullet.height / 2 < brick.y + brick.height
end

function Breakout:checkExtraBallThreshold()
    if self.health_system:checkExtraLifeAward(self.score) then
        self.lives = self.health_system.lives  -- Sync for HUD/VictoryCondition

        -- Spawn green popup for extra life
        if self.params.score_popup_enabled then
            self.popup_manager:add(self.arena_width / 2, self.arena_height / 2, "EXTRA LIFE!", {0, 1, 0})
        end
    end
end

function Breakout:checkVictoryConditions()
    local result = self.victory_checker:check()
    if result then
        -- Award perfect clear bonus if all bricks cleared with no balls lost
        if result == "victory" and (self.params.victory_condition == "clear_bricks" or self.params.victory_condition == "clear_all") then
            if self.balls_lost == 0 and self.params.perfect_clear_bonus > 0 then
                self.score = self.score + self.params.perfect_clear_bonus
                if self.params.score_popup_enabled then
                    self.popup_manager:add(self.arena_width / 2, self.arena_height / 2, "PERFECT CLEAR! +" .. self.params.perfect_clear_bonus, {0, 1, 0})
                end
            end
        end

        self.victory = (result == "victory")
        self.game_over = (result == "loss")
    end
end

function Breakout:checkComplete()
    return self.victory or self.game_over
end

function Breakout:onBrickHit(brick, ball)
    brick.health = brick.health - 1
    if brick.health <= 0 then
        brick.alive = false
        self.bricks_destroyed = self.bricks_destroyed + 1
        self.bricks_left = self.bricks_left - 1
    end
end

function Breakout:onPowerupCollect(powerup)
end

function Breakout:applyPowerupEffect(powerup_type, effect, config)
    if powerup_type == "multi_ball" then
        local count = config.count or 2
        local angle_spread = config.angle_spread or (math.pi/6)

        for _, ball in ipairs(self.balls) do
            if ball.active then
                for i = 1, count do
                    local angle_offset = ((i - (count + 1) / 2) / count) * angle_spread * 2
                    local speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
                    local current_angle = math.atan2(ball.vy, ball.vx)
                    local new_angle = current_angle + angle_offset

                    self.projectile_system:shoot(
                        "ball",
                        ball.x,
                        ball.y,
                        new_angle,
                        speed / self.ball_speed,
                        {
                            radius = ball.radius,
                            trail = {}
                        }
                    )
                end
                break
            end
        end

    elseif powerup_type == "paddle_extend" then
        local multiplier = config.multiplier or 1.5
        effect.original_width = self.paddle.width
        self.paddle.width = self.paddle.width * multiplier

    elseif powerup_type == "paddle_shrink" then
        local multiplier = config.multiplier or 0.5
        effect.original_width = self.paddle.width
        self.paddle.width = self.paddle.width * multiplier

    elseif powerup_type == "slow_motion" then
        local multiplier = config.multiplier or 0.5
        effect.original_speed = self.ball_speed
        for _, ball in ipairs(self.balls) do
            if ball.active then
                ball.vx = ball.vx * multiplier
                ball.vy = ball.vy * multiplier
            end
        end
        self.ball_speed = self.ball_speed * multiplier

    elseif powerup_type == "fast_ball" then
        local multiplier = config.multiplier or 1.5
        effect.original_speed = self.ball_speed
        for _, ball in ipairs(self.balls) do
            if ball.active then
                ball.vx = ball.vx * multiplier
                ball.vy = ball.vy * multiplier
            end
        end
        self.ball_speed = self.ball_speed * multiplier

    elseif powerup_type == "laser" then
        effect.original_can_shoot = self.paddle_can_shoot
        self.paddle_can_shoot = true

    elseif powerup_type == "sticky_paddle" then
        effect.original_sticky = self.paddle_sticky
        self.paddle_sticky = true

    elseif powerup_type == "extra_life" then
        local count = config.count or 1
        self.health_system:addLife(count)
        self.lives = self.health_system.lives

    elseif powerup_type == "shield" then
        self.shield_active = true

    elseif powerup_type == "penetrating_ball" then
        local pierce_count = config.pierce_count or 5
        effect.original_phase = self.ball_phase_through_bricks
        for _, ball in ipairs(self.balls) do
            if ball.active then
                ball.pierce_count = pierce_count
            end
        end
        self.ball_phase_through_bricks = pierce_count

    elseif powerup_type == "fireball" then
        local pierce_count = config.pierce_count or 5
        effect.original_phase = self.ball_phase_through_bricks
        for _, ball in ipairs(self.balls) do
            if ball.active then
                ball.pierce_count = pierce_count
            end
        end
        self.ball_phase_through_bricks = pierce_count

    elseif powerup_type == "magnet" then
        local range = config.range or 150
        effect.original_magnet_range = self.paddle_magnet_range
        self.paddle_magnet_range = range
    end
end

function Breakout:removePowerupEffect(powerup_type, effect)

    if powerup_type == "paddle_extend" or powerup_type == "paddle_shrink" then
        self.paddle.width = effect.original_width

    elseif powerup_type == "slow_motion" or powerup_type == "fast_ball" then
        local speed_ratio = self.ball_speed / effect.original_speed
        for _, ball in ipairs(self.balls) do
            if ball.active then
                ball.vx = ball.vx / speed_ratio
                ball.vy = ball.vy / speed_ratio
            end
        end
        self.ball_speed = effect.original_speed

    elseif powerup_type == "laser" then
        self.paddle_can_shoot = effect.original_can_shoot

    elseif powerup_type == "sticky_paddle" then
        self.paddle_sticky = effect.original_sticky

    elseif powerup_type == "penetrating_ball" or powerup_type == "fireball" then
        self.ball_phase_through_bricks = effect.original_phase

    elseif powerup_type == "magnet" then
        self.paddle_magnet_range = effect.original_magnet_range
    end
end

function Breakout:draw()
    self.view:draw()
end

return Breakout
