local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local Collision = require('src.utils.collision')
local BreakoutView = require('src.games.views.breakout_view')
local Breakout = BaseGame:extend('Breakout')

-- Config-driven defaults with safe fallbacks
local BCfg = (Config and Config.games and Config.games.breakout) or {}

-- Paddle defaults
local DEFAULT_PADDLE_WIDTH = 100
local DEFAULT_PADDLE_HEIGHT = 20
local DEFAULT_PADDLE_SPEED = 600  -- Increased from 400 for smoother feel
local DEFAULT_PADDLE_FRICTION = 1.0  -- Changed to match DodgeGame (1.0 = instant response, no drift)
local DEFAULT_MOVEMENT_TYPE = "direct"  -- "direct", "velocity", "rail", "asteroids", "jump"
local DEFAULT_ROTATION_SPEED = 5.0  -- For asteroids mode
local DEFAULT_JUMP_DISTANCE = 150  -- For jump mode
local DEFAULT_JUMP_COOLDOWN = 0.5  -- For jump mode

-- Ball defaults
local DEFAULT_BALL_RADIUS = 8
local DEFAULT_BALL_SPEED = 300
local DEFAULT_BALL_MAX_SPEED = 600
local DEFAULT_BALL_COUNT = 1
local DEFAULT_BALL_GRAVITY = 0  -- 0 = no gravity
local DEFAULT_BALL_GRAVITY_DIRECTION = 270  -- 270 = down, 90 = up, 0 = right, 180 = left
local DEFAULT_BALL_SPEED_INCREASE_PER_BOUNCE = 0  -- Speed increase per brick hit
local DEFAULT_BALL_HOMING_STRENGTH = 0.0  -- 0.0 = none, 1.0 = strong
local DEFAULT_BALL_PHASE_THROUGH_BRICKS = 0  -- Number of bricks to pierce before bouncing

-- Brick defaults
local DEFAULT_BRICK_WIDTH = 60
local DEFAULT_BRICK_HEIGHT = 20
local DEFAULT_BRICK_ROWS = 5
local DEFAULT_BRICK_COLUMNS = 10
local DEFAULT_BRICK_HEALTH = 1
local DEFAULT_BRICK_PADDING = 5
local DEFAULT_BRICK_LAYOUT = "grid"

-- Game defaults
local DEFAULT_LIVES = 3
local DEFAULT_VICTORY_CONDITION = "clear_bricks"

-- Legacy compatibility
local PADDLE_WIDTH = (BCfg.paddle and BCfg.paddle.width) or DEFAULT_PADDLE_WIDTH
local PADDLE_HEIGHT = (BCfg.paddle and BCfg.paddle.height) or DEFAULT_PADDLE_HEIGHT
local PADDLE_SPEED = (BCfg.paddle and BCfg.paddle.speed) or DEFAULT_PADDLE_SPEED
local PADDLE_FRICTION = (BCfg.paddle and BCfg.paddle.friction) or DEFAULT_PADDLE_FRICTION

local BALL_RADIUS = (BCfg.ball and BCfg.ball.radius) or DEFAULT_BALL_RADIUS
local BALL_SPEED = (BCfg.ball and BCfg.ball.speed) or DEFAULT_BALL_SPEED
local BALL_MAX_SPEED = (BCfg.ball and BCfg.ball.max_speed) or DEFAULT_BALL_MAX_SPEED

local BRICK_WIDTH = (BCfg.brick and BCfg.brick.width) or DEFAULT_BRICK_WIDTH
local BRICK_HEIGHT = (BCfg.brick and BCfg.brick.height) or DEFAULT_BRICK_HEIGHT
local BRICK_ROWS = (BCfg.brick and BCfg.brick.rows) or DEFAULT_BRICK_ROWS
local BRICK_COLUMNS = (BCfg.brick and BCfg.brick.columns) or DEFAULT_BRICK_COLUMNS
local BRICK_HEALTH = (BCfg.brick and BCfg.brick.health) or DEFAULT_BRICK_HEALTH
local BRICK_PADDING = (BCfg.brick and BCfg.brick.padding) or DEFAULT_BRICK_PADDING

local LIVES = (BCfg.game and BCfg.game.lives) or DEFAULT_LIVES

function Breakout:init(game_data, cheats, di, variant_override)
    Breakout.super.init(self, game_data, cheats, di, variant_override)
    self.di = di
    self.cheats = cheats or {}

    -- Three-tier fallback: runtimeCfg → variant → DEFAULT
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.breakout)

    -- Paddle Parameters
    self.movement_type = (runtimeCfg and runtimeCfg.movement_type) or DEFAULT_MOVEMENT_TYPE
    if self.variant and self.variant.movement_type ~= nil then
        self.movement_type = self.variant.movement_type
    end

    self.paddle_width = (runtimeCfg and runtimeCfg.paddle_width) or DEFAULT_PADDLE_WIDTH
    if self.variant and self.variant.paddle_width ~= nil then
        self.paddle_width = self.variant.paddle_width
    end

    self.paddle_speed = (runtimeCfg and runtimeCfg.paddle_speed) or DEFAULT_PADDLE_SPEED
    if self.variant and self.variant.paddle_speed ~= nil then
        self.paddle_speed = self.variant.paddle_speed
    end

    self.paddle_friction = (runtimeCfg and runtimeCfg.paddle_friction) or DEFAULT_PADDLE_FRICTION
    if self.variant and self.variant.paddle_friction ~= nil then
        self.paddle_friction = self.variant.paddle_friction
    end

    self.rotation_speed = (runtimeCfg and runtimeCfg.rotation_speed) or DEFAULT_ROTATION_SPEED
    if self.variant and self.variant.rotation_speed ~= nil then
        self.rotation_speed = self.variant.rotation_speed
    end

    self.jump_distance = (runtimeCfg and runtimeCfg.jump_distance) or DEFAULT_JUMP_DISTANCE
    if self.variant and self.variant.jump_distance ~= nil then
        self.jump_distance = self.variant.jump_distance
    end

    self.jump_cooldown = (runtimeCfg and runtimeCfg.jump_cooldown) or DEFAULT_JUMP_COOLDOWN
    if self.variant and self.variant.jump_cooldown ~= nil then
        self.jump_cooldown = self.variant.jump_cooldown
    end

    -- Ball Parameters
    self.ball_count = (runtimeCfg and runtimeCfg.ball_count) or DEFAULT_BALL_COUNT
    if self.variant and self.variant.ball_count ~= nil then
        self.ball_count = self.variant.ball_count
    end

    self.ball_speed = (runtimeCfg and runtimeCfg.ball_speed) or DEFAULT_BALL_SPEED
    if self.variant and self.variant.ball_speed ~= nil then
        self.ball_speed = self.variant.ball_speed
    end

    self.ball_max_speed = (runtimeCfg and runtimeCfg.ball_max_speed) or DEFAULT_BALL_MAX_SPEED
    if self.variant and self.variant.ball_max_speed ~= nil then
        self.ball_max_speed = self.variant.ball_max_speed
    end

    self.ball_gravity = (runtimeCfg and runtimeCfg.ball_gravity) or DEFAULT_BALL_GRAVITY
    if self.variant and self.variant.ball_gravity ~= nil then
        self.ball_gravity = self.variant.ball_gravity
    end

    self.ball_gravity_direction = (runtimeCfg and runtimeCfg.ball_gravity_direction) or DEFAULT_BALL_GRAVITY_DIRECTION
    if self.variant and self.variant.ball_gravity_direction ~= nil then
        self.ball_gravity_direction = self.variant.ball_gravity_direction
    end

    self.ball_speed_increase_per_bounce = (runtimeCfg and runtimeCfg.ball_speed_increase_per_bounce) or DEFAULT_BALL_SPEED_INCREASE_PER_BOUNCE
    if self.variant and self.variant.ball_speed_increase_per_bounce ~= nil then
        self.ball_speed_increase_per_bounce = self.variant.ball_speed_increase_per_bounce
    end

    self.ball_homing_strength = (runtimeCfg and runtimeCfg.ball_homing_strength) or DEFAULT_BALL_HOMING_STRENGTH
    if self.variant and self.variant.ball_homing_strength ~= nil then
        self.ball_homing_strength = self.variant.ball_homing_strength
    end

    self.ball_phase_through_bricks = (runtimeCfg and runtimeCfg.ball_phase_through_bricks) or DEFAULT_BALL_PHASE_THROUGH_BRICKS
    if self.variant and self.variant.ball_phase_through_bricks ~= nil then
        self.ball_phase_through_bricks = self.variant.ball_phase_through_bricks
    end

    -- Brick Parameters
    self.brick_rows = (runtimeCfg and runtimeCfg.brick_rows) or DEFAULT_BRICK_ROWS
    if self.variant and self.variant.brick_rows ~= nil then
        self.brick_rows = self.variant.brick_rows
    end

    self.brick_columns = (runtimeCfg and runtimeCfg.brick_columns) or DEFAULT_BRICK_COLUMNS
    if self.variant and self.variant.brick_columns ~= nil then
        self.brick_columns = self.variant.brick_columns
    end

    self.brick_layout = (runtimeCfg and runtimeCfg.brick_layout) or DEFAULT_BRICK_LAYOUT
    if self.variant and self.variant.brick_layout ~= nil then
        self.brick_layout = self.variant.brick_layout
    end

    self.brick_health = (runtimeCfg and runtimeCfg.brick_health) or DEFAULT_BRICK_HEALTH
    if self.variant and self.variant.brick_health ~= nil then
        self.brick_health = self.variant.brick_health
    end

    -- Game Parameters
    self.lives = (runtimeCfg and runtimeCfg.lives) or DEFAULT_LIVES
    if self.variant and self.variant.lives ~= nil then
        self.lives = self.variant.lives
    end

    self.victory_condition = (runtimeCfg and runtimeCfg.victory_condition) or DEFAULT_VICTORY_CONDITION
    if self.variant and self.variant.victory_condition ~= nil then
        self.victory_condition = self.variant.victory_condition
    end

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
        self.lives = self.lives + math.floor(self.cheats.advantage_modifier or 0)
        self.paddle_width = self.paddle_width * (1 + (self.cheats.advantage_modifier or 0) * 0.1)
    end
    if self.cheats.performance_modifier then
        -- Increase ball count for better performance
        self.ball_count = self.ball_count + math.floor((self.cheats.performance_modifier or 0) / 3)
    end

    -- Initialize RNG with seed
    self.rng = love.math.newRandomGenerator(self.seed or os.time())

    -- Initialize game state
    self.arena_width = 800
    self.arena_height = 600
    self.game_over = false
    self.victory = false
    self.score = 0
    self.combo = 0
    self.max_combo = 0
    self.bricks_destroyed = 0
    self.balls_lost = 0

    -- Initialize paddle
    self.paddle = {
        x = self.arena_width / 2,
        y = self.arena_height - 50,
        width = self.paddle_width,
        height = PADDLE_HEIGHT,
        vx = 0,
        vy = 0,  -- For asteroids mode
        angle = 0,  -- For asteroids mode
        jump_cooldown_timer = 0  -- For jump mode
    }

    print("DEBUG BREAKOUT INIT: paddle_friction=" .. tostring(self.paddle_friction) .. ", paddle_speed=" .. tostring(self.paddle_speed) .. ", movement_type=" .. tostring(self.movement_type))

    -- Initialize ball(s)
    self.balls = {}
    for i = 1, self.ball_count do
        self:spawnBall()
    end

    -- Initialize bricks
    self.bricks = {}
    self:generateBricks()

    -- Metrics tracking
    self.metrics = {
        bricks_destroyed = 0,
        balls_lost = 0,
        max_combo = 0,
        score = 0
    }

    -- Create view
    self.view = BreakoutView:new(self)
end

function Breakout:spawnBall()
    local angle = -math.pi / 2 + (self.rng:random() - 0.5) * 0.5
    local ball = {
        x = self.paddle.x,
        y = self.paddle.y - BALL_RADIUS - 10,
        radius = BALL_RADIUS,
        vx = math.cos(angle) * self.ball_speed,
        vy = math.sin(angle) * self.ball_speed,
        active = true,
        pierce_count = self.ball_phase_through_bricks  -- For phase-through bricks
    }
    table.insert(self.balls, ball)
end

function Breakout:generateBricks()
    self.bricks = {}

    if self.brick_layout == "grid" then
        local total_width = self.brick_columns * (BRICK_WIDTH + BRICK_PADDING)
        local start_x = (self.arena_width - total_width) / 2
        local start_y = 60

        for row = 1, self.brick_rows do
            for col = 1, self.brick_columns do
                local brick = {
                    x = start_x + (col - 1) * (BRICK_WIDTH + BRICK_PADDING),
                    y = start_y + (row - 1) * (BRICK_HEIGHT + BRICK_PADDING),
                    width = BRICK_WIDTH,
                    height = BRICK_HEIGHT,
                    health = self.brick_health,
                    max_health = self.brick_health,
                    alive = true
                }
                table.insert(self.bricks, brick)
            end
        end
    end
end

function Breakout:updateGameLogic(dt)
    if self.game_over or self.victory then
        return
    end

    -- Update paddle
    self:updatePaddle(dt)

    -- Update balls
    for i = #self.balls, 1, -1 do
        local ball = self.balls[i]
        if ball.active then
            self:updateBall(ball, dt)
        end
    end

    -- Check if all balls are lost
    local active_balls = 0
    for _, ball in ipairs(self.balls) do
        if ball.active then
            active_balls = active_balls + 1
        end
    end

    if active_balls == 0 then
        self.balls_lost = self.balls_lost + 1
        self.lives = self.lives - 1
        self.combo = 0

        if self.lives <= 0 then
            self.game_over = true
        else
            -- Respawn ball
            self:spawnBall()
        end
    end

    -- Check victory
    if self.victory_condition == "clear_bricks" then
        local remaining = 0
        for _, brick in ipairs(self.bricks) do
            if brick.alive then
                remaining = remaining + 1
            end
        end
        if remaining == 0 then
            self.victory = true
        end
    end

    -- Update metrics
    self.metrics.bricks_destroyed = self.bricks_destroyed
    self.metrics.balls_lost = self.balls_lost
    self.metrics.max_combo = self.max_combo
    self.metrics.score = self.score
end

function Breakout:updatePaddle(dt)
    local move_dir = 0
    if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
        move_dir = -1
    end
    if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
        move_dir = move_dir + 1
    end

    -- Target velocity based on input
    local target_velocity = move_dir * self.paddle_speed

    -- Simple exponential smoothing toward target
    -- Lower friction = slower response (more "slip")
    local smoothing = 1 - self.paddle_friction
    self.paddle.vx = self.paddle.vx * smoothing + target_velocity * (1 - smoothing)

    -- Update position
    self.paddle.x = self.paddle.x + self.paddle.vx * dt

    -- Clamp to arena bounds
    if self.paddle.x - self.paddle.width / 2 < 0 then
        self.paddle.x = self.paddle.width / 2
        self.paddle.vx = 0
    elseif self.paddle.x + self.paddle.width / 2 > self.arena_width then
        self.paddle.x = self.arena_width - self.paddle.width / 2
        self.paddle.vx = 0
    end
end

function Breakout:updateBall(ball, dt)
    -- Apply directional gravity if enabled
    if self.ball_gravity ~= 0 then
        local gravity_rad = math.rad(self.ball_gravity_direction)
        ball.vx = ball.vx + math.cos(gravity_rad) * self.ball_gravity * dt
        ball.vy = ball.vy + math.sin(gravity_rad) * self.ball_gravity * dt
    end

    -- Apply homing toward nearest brick
    if self.ball_homing_strength > 0 then
        local nearest_brick = self:findNearestBrick(ball.x, ball.y)
        if nearest_brick then
            local dx = nearest_brick.x - ball.x
            local dy = nearest_brick.y - ball.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                -- Apply homing force
                local homing_force = self.ball_homing_strength * 50
                ball.vx = ball.vx + (dx / dist) * homing_force * dt
                ball.vy = ball.vy + (dy / dist) * homing_force * dt
            end
        end
    end

    -- Update position
    ball.x = ball.x + ball.vx * dt
    ball.y = ball.y + ball.vy * dt

    -- Wall collisions (left, right, top)
    if ball.x - ball.radius < 0 then
        ball.x = ball.radius
        ball.vx = -ball.vx
    elseif ball.x + ball.radius > self.arena_width then
        ball.x = self.arena_width - ball.radius
        ball.vx = -ball.vx
    end

    if ball.y - ball.radius < 0 then
        ball.y = ball.radius
        ball.vy = -ball.vy
    end

    -- Bottom boundary (lose ball)
    if ball.y - ball.radius > self.arena_height then
        ball.active = false
        return
    end

    -- Paddle collision
    if self:checkBallPaddleCollision(ball) then
        -- Bounce ball off paddle
        ball.y = self.paddle.y - ball.radius - self.paddle.height / 2
        ball.vy = -math.abs(ball.vy)

        -- Add spin based on hit position
        local hit_pos = (ball.x - self.paddle.x) / (self.paddle.width / 2)
        ball.vx = ball.vx + hit_pos * 100

        -- Reset combo (ball touched paddle)
        self.combo = 0

        -- Clamp speed
        local speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
        if speed > self.ball_max_speed then
            local scale = self.ball_max_speed / speed
            ball.vx = ball.vx * scale
            ball.vy = ball.vy * scale
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
                self.combo = self.combo + 1
                if self.combo > self.max_combo then
                    self.max_combo = self.combo
                end
                self.score = self.score + 100 * (1 + self.combo * 0.1)
            end

            -- Check if ball should phase through or bounce
            if ball.pierce_count and ball.pierce_count > 0 then
                -- Phase through - reduce pierce count but don't bounce
                ball.pierce_count = ball.pierce_count - 1
            else
                -- Normal bounce
                ball.vy = -ball.vy

                -- Move ball out of brick
                if ball.vy < 0 then
                    ball.y = brick.y - ball.radius - brick.height / 2
                else
                    ball.y = brick.y + ball.radius + brick.height / 2
                end
            end

            -- Increase ball speed if enabled
            if self.ball_speed_increase_per_bounce > 0 then
                local current_speed = math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
                local new_speed = math.min(current_speed + self.ball_speed_increase_per_bounce, self.ball_max_speed)
                if current_speed > 0 then
                    local scale = new_speed / current_speed
                    ball.vx = ball.vx * scale
                    ball.vy = ball.vy * scale
                end
            end

            -- Only process one brick collision per frame
            if not (ball.pierce_count and ball.pierce_count > 0) then
                break
            end
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
    local brick_left = brick.x
    local brick_right = brick.x + brick.width
    local brick_top = brick.y
    local brick_bottom = brick.y + brick.height

    return ball.x + ball.radius > brick_left and
           ball.x - ball.radius < brick_right and
           ball.y + ball.radius > brick_top and
           ball.y - ball.radius < brick_bottom
end


function Breakout:keypressed(key)
    if self.game_over or self.victory then
        return
    end

    -- Paddle movement (WASD or Arrow keys)
    if key == 'a' or key == 'left' then
        self.paddle.vx = -self.paddle_speed
    elseif key == 'd' or key == 'right' then
        self.paddle.vx = self.paddle_speed
    end
end

function Breakout:keyreleased(key)
    if key == 'a' or key == 'left' then
        if self.paddle.vx < 0 then
            self.paddle.vx = 0
        end
    elseif key == 'd' or key == 'right' then
        if self.paddle.vx > 0 then
            self.paddle.vx = 0
        end
    end
end

function Breakout:checkComplete()
    return self.victory or self.game_over
end

function Breakout:draw()
    self.view:draw()
end

return Breakout
