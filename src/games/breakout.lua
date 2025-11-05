local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local Collision = require('src.utils.collision')
local BreakoutView = require('src.games.views.breakout_view')
local Breakout = BaseGame:extend('Breakout')

-- Config-driven defaults with safe fallbacks
local BCfg = (Config and Config.games and Config.games.breakout) or {}

-- Paddle defaults
local PADDLE_WIDTH = (BCfg.paddle and BCfg.paddle.width) or 100
local PADDLE_HEIGHT = (BCfg.paddle and BCfg.paddle.height) or 20
local PADDLE_SPEED = (BCfg.paddle and BCfg.paddle.speed) or 400
local PADDLE_FRICTION = (BCfg.paddle and BCfg.paddle.friction) or 0.92

-- Ball defaults
local BALL_RADIUS = (BCfg.ball and BCfg.ball.radius) or 8
local BALL_SPEED = (BCfg.ball and BCfg.ball.speed) or 300
local BALL_MAX_SPEED = (BCfg.ball and BCfg.ball.max_speed) or 600

-- Brick defaults
local BRICK_WIDTH = (BCfg.brick and BCfg.brick.width) or 60
local BRICK_HEIGHT = (BCfg.brick and BCfg.brick.height) or 20
local BRICK_ROWS = (BCfg.brick and BCfg.brick.rows) or 5
local BRICK_COLUMNS = (BCfg.brick and BCfg.brick.columns) or 10
local BRICK_HEALTH = (BCfg.brick and BCfg.brick.health) or 1
local BRICK_PADDING = (BCfg.brick and BCfg.brick.padding) or 5

-- Game defaults
local LIVES = (BCfg.game and BCfg.game.lives) or 3

function Breakout:init(game_data, cheats, di, variant_override)
    Breakout.super.init(self, game_data, cheats, di, variant_override)
    self.di = di
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.breakout) or BCfg

    -- Apply variant difficulty modifier
    local variant_difficulty = self.variant and self.variant.difficulty_modifier or 1.0

    -- Override file-scope constants with DI values when present
    PADDLE_WIDTH = (runtimeCfg.paddle and runtimeCfg.paddle.width) or PADDLE_WIDTH
    PADDLE_HEIGHT = (runtimeCfg.paddle and runtimeCfg.paddle.height) or PADDLE_HEIGHT
    PADDLE_SPEED = (runtimeCfg.paddle and runtimeCfg.paddle.speed) or PADDLE_SPEED
    PADDLE_FRICTION = (runtimeCfg.paddle and runtimeCfg.paddle.friction) or PADDLE_FRICTION

    BALL_RADIUS = (runtimeCfg.ball and runtimeCfg.ball.radius) or BALL_RADIUS
    BALL_SPEED = (runtimeCfg.ball and runtimeCfg.ball.speed) or BALL_SPEED
    BALL_MAX_SPEED = (runtimeCfg.ball and runtimeCfg.ball.max_speed) or BALL_MAX_SPEED

    BRICK_WIDTH = (runtimeCfg.brick and runtimeCfg.brick.width) or BRICK_WIDTH
    BRICK_HEIGHT = (runtimeCfg.brick and runtimeCfg.brick.height) or BRICK_HEIGHT
    BRICK_ROWS = (runtimeCfg.brick and runtimeCfg.brick.rows) or BRICK_ROWS
    BRICK_COLUMNS = (runtimeCfg.brick and runtimeCfg.brick.columns) or BRICK_COLUMNS
    BRICK_HEALTH = (runtimeCfg.brick and runtimeCfg.brick.health) or BRICK_HEALTH
    BRICK_PADDING = (runtimeCfg.brick and runtimeCfg.brick.padding) or BRICK_PADDING

    LIVES = (runtimeCfg.game and runtimeCfg.game.lives) or LIVES

    -- Load variant parameters with three-tier fallback
    -- Paddle parameters
    self.paddle_width = PADDLE_WIDTH
    if self.variant and self.variant.paddle_width ~= nil then
        self.paddle_width = self.variant.paddle_width
    end

    self.paddle_speed = PADDLE_SPEED
    if self.variant and self.variant.paddle_speed ~= nil then
        self.paddle_speed = self.variant.paddle_speed
    end

    self.paddle_friction = PADDLE_FRICTION
    if self.variant and self.variant.paddle_friction ~= nil then
        self.paddle_friction = self.variant.paddle_friction
    end

    -- Ball parameters
    self.ball_speed = BALL_SPEED
    if self.variant and self.variant.ball_speed ~= nil then
        self.ball_speed = self.variant.ball_speed
    end

    self.ball_max_speed = BALL_MAX_SPEED
    if self.variant and self.variant.ball_max_speed ~= nil then
        self.ball_max_speed = self.variant.ball_max_speed
    end

    self.ball_count = 1
    if self.variant and self.variant.ball_count ~= nil then
        self.ball_count = self.variant.ball_count
    end

    -- Brick parameters
    self.brick_rows = BRICK_ROWS
    if self.variant and self.variant.brick_rows ~= nil then
        self.brick_rows = self.variant.brick_rows
    end

    self.brick_columns = BRICK_COLUMNS
    if self.variant and self.variant.brick_columns ~= nil then
        self.brick_columns = self.variant.brick_columns
    end

    self.brick_health = BRICK_HEALTH
    if self.variant and self.variant.brick_health ~= nil then
        self.brick_health = self.variant.brick_health
    end

    self.brick_layout = "grid"
    if self.variant and self.variant.brick_layout ~= nil then
        self.brick_layout = self.variant.brick_layout
    end

    -- Lives
    self.lives = LIVES
    if self.variant and self.variant.lives ~= nil then
        self.lives = self.variant.lives
    end

    -- Apply CheatEngine modifications
    local speed_modifier = self.cheats.speed_modifier or 1.0
    local advantage_modifier = self.cheats.advantage_modifier or {}
    local extra_lives = advantage_modifier.lives or 0

    self.paddle_speed = self.paddle_speed * speed_modifier
    self.lives = self.lives + extra_lives

    -- Victory condition
    self.victory_condition = "clear_bricks"
    if self.variant and self.variant.victory_condition ~= nil then
        self.victory_condition = self.variant.victory_condition
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
        vx = 0
    }

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
        active = true
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
    -- Apply friction
    self.paddle.vx = self.paddle.vx * self.paddle_friction

    -- Clamp to arena bounds
    if self.paddle.x - self.paddle.width / 2 < 0 then
        self.paddle.x = self.paddle.width / 2
        self.paddle.vx = 0
    elseif self.paddle.x + self.paddle.width / 2 > self.arena_width then
        self.paddle.x = self.arena_width - self.paddle.width / 2
        self.paddle.vx = 0
    end

    -- Update position
    self.paddle.x = self.paddle.x + self.paddle.vx * dt
end

function Breakout:updateBall(ball, dt)
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

            -- Bounce ball
            -- Simple bounce (reverse y velocity)
            ball.vy = -ball.vy

            -- Move ball out of brick
            if ball.vy < 0 then
                ball.y = brick.y - ball.radius - brick.height / 2
            else
                ball.y = brick.y + ball.radius + brick.height / 2
            end

            break
        end
    end
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
