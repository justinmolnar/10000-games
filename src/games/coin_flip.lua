local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local CoinFlipView = require('src.games.views.coin_flip_view')
local CoinFlip = BaseGame:extend('CoinFlip')

-- Config-driven defaults with safe fallbacks
local DEFAULT_STREAK_TARGET = 10
local DEFAULT_COIN_BIAS = 0.5  -- Fair coin
local DEFAULT_LIVES = 3
local DEFAULT_TIME_PER_FLIP = 0  -- Unlimited
local DEFAULT_FLIP_ANIMATION_SPEED = 0.5
local DEFAULT_SHOW_BIAS_HINT = false
local DEFAULT_PATTERN_MODE = "random"
local DEFAULT_VICTORY_CONDITION = "streak"  -- "streak", "total", "ratio", "time"
local DEFAULT_TOTAL_CORRECT_TARGET = 50
local DEFAULT_RATIO_TARGET = 0.75  -- 75% accuracy
local DEFAULT_RATIO_FLIP_COUNT = 20  -- Over last 20 flips
local DEFAULT_TIME_LIMIT = 120  -- 2 minutes

function CoinFlip:init(game_data, cheats, di, variant_override)
    CoinFlip.super.init(self, game_data, cheats, di, variant_override)
    self.di = di
    self.cheats = cheats or {}

    -- Three-tier fallback: runtimeCfg → variant → DEFAULT
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.coin_flip)

    -- Core Mechanics Parameters
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

    -- Timing Parameters
    self.time_per_flip = (runtimeCfg and runtimeCfg.time_per_flip) or DEFAULT_TIME_PER_FLIP
    if self.variant and self.variant.time_per_flip ~= nil then
        self.time_per_flip = self.variant.time_per_flip
    end

    self.flip_animation_speed = (runtimeCfg and runtimeCfg.flip_animation_speed) or DEFAULT_FLIP_ANIMATION_SPEED
    if self.variant and self.variant.flip_animation_speed ~= nil then
        self.flip_animation_speed = self.variant.flip_animation_speed
    end

    -- Display Parameters
    self.show_bias_hint = (runtimeCfg and runtimeCfg.show_bias_hint) or DEFAULT_SHOW_BIAS_HINT
    if self.variant and self.variant.show_bias_hint ~= nil then
        self.show_bias_hint = self.variant.show_bias_hint
    end

    -- Pattern Mode
    self.pattern_mode = (runtimeCfg and runtimeCfg.pattern_mode) or DEFAULT_PATTERN_MODE
    if self.variant and self.variant.pattern_mode ~= nil then
        self.pattern_mode = self.variant.pattern_mode
    end

    -- Flip mode: "auto" = heads advance streak (default), "guess" = player calls it
    self.flip_mode = (runtimeCfg and runtimeCfg.flip_mode) or "auto"
    if self.variant and self.variant.flip_mode ~= nil then
        self.flip_mode = self.variant.flip_mode
    end

    -- Victory Condition Parameters
    self.victory_condition = (runtimeCfg and runtimeCfg.victory_condition) or DEFAULT_VICTORY_CONDITION
    if self.variant and self.variant.victory_condition ~= nil then
        self.victory_condition = self.variant.victory_condition
    end

    self.total_correct_target = (runtimeCfg and runtimeCfg.total_correct_target) or DEFAULT_TOTAL_CORRECT_TARGET
    if self.variant and self.variant.total_correct_target ~= nil then
        self.total_correct_target = self.variant.total_correct_target
    end

    self.ratio_target = (runtimeCfg and runtimeCfg.ratio_target) or DEFAULT_RATIO_TARGET
    if self.variant and self.variant.ratio_target ~= nil then
        self.ratio_target = self.variant.ratio_target
    end

    self.ratio_flip_count = (runtimeCfg and runtimeCfg.ratio_flip_count) or DEFAULT_RATIO_FLIP_COUNT
    if self.variant and self.variant.ratio_flip_count ~= nil then
        self.ratio_flip_count = self.variant.ratio_flip_count
    end

    self.time_limit = (runtimeCfg and runtimeCfg.time_limit) or DEFAULT_TIME_LIMIT
    if self.variant and self.variant.time_limit ~= nil then
        self.time_limit = self.variant.time_limit
    end

    -- Apply difficulty_modifier from variant
    if self.variant and self.variant.difficulty_modifier then
        self.time_per_flip = self.time_per_flip * self.variant.difficulty_modifier
    end

    -- Apply CheatEngine modifications
    if self.cheats.speed_modifier then
        self.flip_animation_speed = self.flip_animation_speed * self.cheats.speed_modifier
        self.time_per_flip = self.time_per_flip * self.cheats.speed_modifier
    end
    if self.cheats.advantage_modifier then
        self.lives = self.lives + (self.cheats.advantage_modifier or 0)
    end
    if self.cheats.performance_modifier then
        -- Adjust bias toward 0.5 (fairer) based on modifier
        local bias_adjustment = (0.5 - self.coin_bias) * (self.cheats.performance_modifier or 0)
        self.coin_bias = self.coin_bias + bias_adjustment
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

    -- Pattern mode state
    self.pattern_state = {
        last_result = nil,
        cluster_remaining = 0,
        cluster_value = nil
    }

    -- Victory condition tracking
    self.time_elapsed = 0  -- For "time" victory condition
    self.flip_history = {}  -- For "ratio" victory condition (stores 1 for correct, 0 for incorrect)

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
    -- Track time for "time" victory condition
    if not self.game_over and not self.victory then
        self.time_elapsed = self.time_elapsed + dt

        -- Check time limit for "time" victory condition
        if self.victory_condition == "time" and self.time_elapsed >= self.time_limit then
            self.victory = true
        end
    end

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

function CoinFlip:generateFlipResult()
    -- Generate flip result based on pattern_mode
    local result

    if self.pattern_mode == "alternating" then
        -- Alternate between heads and tails
        if self.pattern_state.last_result == nil then
            -- First flip uses bias
            local flip_value = self.rng:random()
            result = flip_value < self.coin_bias and 'heads' or 'tails'
        else
            -- Alternate
            result = self.pattern_state.last_result == 'heads' and 'tails' or 'heads'
        end

    elseif self.pattern_mode == "clusters" then
        -- Generate runs of same result (HHHTTTHHH)
        if self.pattern_state.cluster_remaining > 0 then
            -- Continue current cluster
            result = self.pattern_state.cluster_value
            self.pattern_state.cluster_remaining = self.pattern_state.cluster_remaining - 1
        else
            -- Start new cluster
            local flip_value = self.rng:random()
            result = flip_value < self.coin_bias and 'heads' or 'tails'
            self.pattern_state.cluster_value = result
            -- Cluster length between 2 and 5
            self.pattern_state.cluster_remaining = self.rng:random(2, 5) - 1
        end

    elseif self.pattern_mode == "biased_random" then
        -- Use coin_bias with streak-based adjustment
        local adjusted_bias = self.coin_bias
        -- Increase heads probability slightly when on a streak (helps maintain streaks)
        if self.current_streak > 0 then
            adjusted_bias = math.min(0.95, adjusted_bias + 0.05)
        end
        local flip_value = self.rng:random()
        result = flip_value < adjusted_bias and 'heads' or 'tails'

    else
        -- Default "random" mode - use coin_bias
        local flip_value = self.rng:random()
        result = flip_value < self.coin_bias and 'heads' or 'tails'
    end

    -- Update pattern state
    self.pattern_state.last_result = result

    return result
end

function CoinFlip:flipCoin()
    -- Auto mode: just flip, heads = advance streak
    self.waiting_for_guess = false

    -- Generate result based on pattern mode
    local result = self:generateFlipResult()
    self.last_result = result

    -- Update stats
    self.flips_total = self.flips_total + 1

    -- Heads = success (advance streak), Tails = miss (reset)
    if result == 'heads' then
        self.correct_total = self.correct_total + 1
        self.current_streak = self.current_streak + 1
        table.insert(self.flip_history, 1)  -- Track for ratio victory condition

        -- Update max streak
        if self.current_streak > self.max_streak then
            self.max_streak = self.current_streak
        end

        -- Check victory condition
        if self:checkVictoryCondition() then
            self.victory = true
        end
    else
        -- Tails = miss
        self.incorrect_total = self.incorrect_total + 1
        self.current_streak = 0  -- Reset streak
        table.insert(self.flip_history, 0)  -- Track for ratio victory condition

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

    -- Generate result based on pattern mode
    local result = self:generateFlipResult()
    self.last_result = result

    -- Update stats
    self.flips_total = self.flips_total + 1

    -- Check if guess was correct
    if guess == result then
        -- Correct guess
        self.correct_total = self.correct_total + 1
        self.current_streak = self.current_streak + 1
        table.insert(self.flip_history, 1)  -- Track for ratio victory condition

        -- Update max streak
        if self.current_streak > self.max_streak then
            self.max_streak = self.current_streak
        end

        -- Check victory condition
        if self:checkVictoryCondition() then
            self.victory = true
        end
    else
        -- Wrong guess
        self.incorrect_total = self.incorrect_total + 1
        self.current_streak = 0  -- Reset streak
        table.insert(self.flip_history, 0)  -- Track for ratio victory condition

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

function CoinFlip:checkVictoryCondition()
    -- Check victory based on victory_condition type
    if self.victory_condition == "streak" then
        -- Default: reach streak_target consecutive correct
        return self.current_streak >= self.streak_target

    elseif self.victory_condition == "total" then
        -- Reach total_correct_target total correct guesses
        return self.correct_total >= self.total_correct_target

    elseif self.victory_condition == "ratio" then
        -- Maintain ratio_target accuracy over ratio_flip_count flips
        if #self.flip_history >= self.ratio_flip_count then
            -- Calculate accuracy over last N flips
            local recent_correct = 0
            local start_index = math.max(1, #self.flip_history - self.ratio_flip_count + 1)
            for i = start_index, #self.flip_history do
                if self.flip_history[i] == 1 then
                    recent_correct = recent_correct + 1
                end
            end
            local recent_accuracy = recent_correct / math.min(#self.flip_history, self.ratio_flip_count)
            return recent_accuracy >= self.ratio_target
        end
        return false

    elseif self.victory_condition == "time" then
        -- Get highest streak within time_limit seconds (checked in updateGameLogic)
        -- Victory triggered when time runs out
        return false  -- Handled in updateGameLogic

    end

    return false
end

function CoinFlip:checkComplete()
    return self.victory or self.game_over
end

function CoinFlip:draw()
    self.view:draw()
end

return CoinFlip
