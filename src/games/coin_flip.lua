local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local CoinFlipView = require('src.games.views.coin_flip_view')
local CoinFlip = BaseGame:extend('CoinFlip')

-- Config-driven defaults with safe fallbacks
local DEFAULT_STREAK_TARGET = 10
local DEFAULT_COIN_BIAS = 0.5  -- Fair coin
local DEFAULT_LIVES = 3

function CoinFlip:init(game_data, cheats, di, variant_override)
    CoinFlip.super.init(self, game_data, cheats, di, variant_override)
    self.di = di

    -- Three-tier fallback: runtimeCfg → variant → DEFAULT
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.coin_flip)

    -- Load parameters with three-tier fallback
    self.streak_target = (runtimeCfg and runtimeCfg.streak_target) or DEFAULT_STREAK_TARGET
    if self.variant and self.variant.streak_target ~= nil then
        self.streak_target = self.variant.streak_target
    end

    self.coin_bias = (runtimeCfg and runtimeCfg.coin_bias) or DEFAULT_COIN_BIAS
    if self.variant and self.variant.coin_bias ~= nil then
        self.coin_bias = self.variant.coin_bias
    end

    self.lives = (runtimeCfg and runtimeCfg.lives) or DEFAULT_LIVES
    if self.variant and self.variant.lives ~= nil then
        self.lives = self.variant.lives
    end

    -- Flip mode: "auto" = heads advance streak (default), "guess" = player calls it
    self.flip_mode = (runtimeCfg and runtimeCfg.flip_mode) or "auto"
    if self.variant and self.variant.flip_mode ~= nil then
        self.flip_mode = self.variant.flip_mode
    end

    -- Initialize game state
    self.current_streak = 0
    self.max_streak = 0
    self.correct_total = 0
    self.incorrect_total = 0
    self.flips_total = 0
    self.game_over = false
    self.victory = false

    -- Flip state
    self.waiting_for_guess = true
    self.current_guess = nil  -- 'heads' or 'tails'
    self.last_result = nil
    self.last_guess = nil
    self.result_display_time = 0
    self.show_result = false

    -- Initialize metrics table for formula
    self.metrics = {
        max_streak = 0,
        correct_total = 0,
        flips_total = 0,
        accuracy = 0
    }

    -- Create view
    self.view = CoinFlipView:new(self)

    -- Initialize RNG with seed for deterministic flips
    self.rng = love.math.newRandomGenerator(self.seed or os.time())
end

function CoinFlip:updateGameLogic(dt)
    -- Handle result display timer
    if self.show_result and not self.game_over and not self.victory then
        self.result_display_time = self.result_display_time + dt
        if self.result_display_time >= 1.5 then
            self.show_result = false
            self.result_display_time = 0
            self.waiting_for_guess = true
        end
    end
end

function CoinFlip:keypressed(key)
    if not self.waiting_for_guess or self.game_over or self.victory then
        return
    end

    if self.flip_mode == "auto" then
        -- Auto mode: space to flip, heads = success
        if key == 'space' then
            self:flipCoin()
        end
    else
        -- Guess mode: H/T to call it
        if key == 'h' then
            self:makeGuess('heads')
        elseif key == 't' then
            self:makeGuess('tails')
        end
    end
end

function CoinFlip:flipCoin()
    -- Auto mode: just flip, heads = advance streak
    self.waiting_for_guess = false

    -- Flip coin based on bias
    local flip_value = self.rng:random()
    local result = flip_value < self.coin_bias and 'heads' or 'tails'
    self.last_result = result

    -- Update stats
    self.flips_total = self.flips_total + 1

    -- Heads = success (advance streak), Tails = miss (reset)
    if result == 'heads' then
        self.correct_total = self.correct_total + 1
        self.current_streak = self.current_streak + 1

        -- Update max streak
        if self.current_streak > self.max_streak then
            self.max_streak = self.current_streak
        end

        -- Check victory condition
        if self.current_streak >= self.streak_target then
            self.victory = true
        end
    else
        -- Tails = miss
        self.incorrect_total = self.incorrect_total + 1
        self.current_streak = 0  -- Reset streak

        -- Lose a life (if not unlimited)
        if self.lives < 999 then
            self.lives = self.lives - 1
            if self.lives <= 0 then
                self.game_over = true
            end
        end
    end

    -- Update metrics for formula
    self.metrics.max_streak = self.max_streak
    self.metrics.correct_total = self.correct_total
    self.metrics.flips_total = self.flips_total
    self.metrics.accuracy = self.flips_total > 0 and (self.correct_total / self.flips_total) or 0

    -- Show result
    self.show_result = true
    self.result_display_time = 0
end

function CoinFlip:makeGuess(guess)
    -- Guess mode: player calls heads or tails
    self.current_guess = guess
    self.last_guess = guess
    self.waiting_for_guess = false

    -- Flip coin based on bias
    local flip_value = self.rng:random()
    local result = flip_value < self.coin_bias and 'heads' or 'tails'
    self.last_result = result

    -- Update stats
    self.flips_total = self.flips_total + 1

    -- Check if guess was correct
    if guess == result then
        -- Correct guess
        self.correct_total = self.correct_total + 1
        self.current_streak = self.current_streak + 1

        -- Update max streak
        if self.current_streak > self.max_streak then
            self.max_streak = self.current_streak
        end

        -- Check victory condition
        if self.current_streak >= self.streak_target then
            self.victory = true
        end
    else
        -- Wrong guess
        self.incorrect_total = self.incorrect_total + 1
        self.current_streak = 0  -- Reset streak

        -- Lose a life (if not unlimited)
        if self.lives < 999 then
            self.lives = self.lives - 1
            if self.lives <= 0 then
                self.game_over = true
            end
        end
    end

    -- Update metrics for formula
    self.metrics.max_streak = self.max_streak
    self.metrics.correct_total = self.correct_total
    self.metrics.flips_total = self.flips_total
    self.metrics.accuracy = self.flips_total > 0 and (self.correct_total / self.flips_total) or 0

    -- Show result
    self.show_result = true
    self.result_display_time = 0
end

function CoinFlip:checkComplete()
    return self.victory or self.game_over
end

function CoinFlip:draw()
    self.view:draw()
end

return CoinFlip
