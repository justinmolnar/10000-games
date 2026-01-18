local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local CoinFlipView = require('src.games.views.coin_flip_view')
local popup_module = require('src.games.score_popup')
local PopupManager = popup_module.PopupManager
local VisualEffects = require('src.utils.game_components.visual_effects')
local AnimationSystem = require('src.utils.game_components.animation_system')
local SchemaLoader = require('src.utils.game_components.schema_loader')
local HUDRenderer = require('src.utils.game_components.hud_renderer')
local VictoryCondition = require('src.utils.game_components.victory_condition')
local LivesHealthSystem = require('src.utils.game_components.lives_health_system')
local CoinFlip = BaseGame:extend('CoinFlip')

function CoinFlip:init(game_data, cheats, di, variant_override)
    CoinFlip.super.init(self, game_data, cheats, di, variant_override)
    self.di = di
    self.cheats = cheats or {}

    -- Load all parameters via SchemaLoader (variant → runtime_config → schema defaults)
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.coin_flip)
    local p = SchemaLoader.load(self.variant, "coin_flip_schema", runtimeCfg)

    -- Core Mechanics Parameters
    self.streak_target = p.streak_target
    self.coin_bias = p.coin_bias

    -- Lives handled by LivesHealthSystem
    local starting_lives = p.lives

    -- Timing Parameters
    self.time_per_flip = p.time_per_flip
    self.flip_animation_speed = p.flip_animation_speed

    -- Display Parameters
    self.show_bias_hint = p.show_bias_hint
    self.show_pattern_history = p.show_pattern_history
    self.pattern_history_length = p.pattern_history_length
    self.auto_flip_interval = p.auto_flip_interval
    self.result_announce_mode = p.result_announce_mode

    -- Pattern Mode
    self.pattern_mode = p.pattern_mode
    self.flip_mode = p.flip_mode

    -- Victory Condition Parameters
    self.victory_condition = p.victory_condition
    self.total_correct_target = p.total_correct_target
    self.ratio_target = p.ratio_target
    self.ratio_flip_count = p.ratio_flip_count
    self.time_limit = p.time_limit

    -- Apply difficulty_modifier
    if p.difficulty_modifier ~= 1.0 then
        self.time_per_flip = self.time_per_flip * p.difficulty_modifier
    end

    -- Apply CheatEngine modifications
    if self.cheats.speed_modifier then
        self.flip_animation_speed = self.flip_animation_speed * self.cheats.speed_modifier
        self.time_per_flip = self.time_per_flip * self.cheats.speed_modifier
    end
    if self.cheats.advantage_modifier then
        starting_lives = starting_lives + (self.cheats.advantage_modifier or 0)
    end
    if self.cheats.performance_modifier then
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

    -- Pattern history tracking (Phase 5 completion)
    self.pattern_history = {}  -- Stores last N flip results ('H' or 'T') for display

    -- Auto-flip timer (Phase 5 completion)
    self.auto_flip_timer = 0  -- Countdown to next auto flip
    self.time_per_flip_timer = 0  -- Countdown for time pressure mode

    -- Scoring parameters
    self.score_per_correct = p.score_per_correct
    self.streak_multiplier = p.streak_multiplier
    self.perfect_streak_bonus = p.perfect_streak_bonus
    self.score_popup_enabled = p.score_popup_enabled

    -- Scoring state
    self.score = 0
    self.perfect_streak = true  -- Track if player has maintained streak without any mistakes

    -- Initialize metrics table for formula
    self.metrics = {
        max_streak = 0,
        correct_total = 0,
        flips_total = 0,
        accuracy = 0,
        score = 0
    }

    -- Score popups
    -- Phase 6: Score popups managed by PopupManager
    self.popup_manager = PopupManager:new()

    -- Visual effects parameters
    self.celebration_on_streak = p.celebration_on_streak
    local screen_flash_enabled = p.screen_flash_enabled

    -- Phase 3: Initialize VisualEffects component (screen flash + particles)
    self.visual_effects = VisualEffects:new({
        camera_shake_enabled = false,  -- Coin Flip doesn't use camera shake
        screen_flash_enabled = screen_flash_enabled,
        particle_effects_enabled = true
    })

    -- Phase 4: Initialize AnimationSystem for coin flip
    self.flip_animation = AnimationSystem.createFlipAnimation({
        duration = 0.5,
        speed_multiplier = self.flip_animation_speed,
        on_complete = nil  -- No callback needed
    })

    -- Lives/Health System (Phase 10)
    self.health_system = LivesHealthSystem:new({
        mode = "lives",
        starting_lives = starting_lives,
        max_lives = 10
    })
    self.lives = self.health_system.lives

    -- Initialize HUD (Phase 8: Standard HUD layout)
    self.hud = HUDRenderer:new({
        primary = {label = "Score", key = "score"},
        secondary = {label = "Streak", key = "current_streak"},
        lives = {key = "lives", max = starting_lives, style = "hearts"}
    })
    self.hud.game = self  -- Link game reference

    -- Create view
    self.view = CoinFlipView:new(self)

    -- Initialize RNG with seed for deterministic flips
    self.rng = love.math.newRandomGenerator(self.seed or os.time())

    -- Victory Condition System (Phase 9)
    local victory_config = {}

    if self.victory_condition == "streak" then
        victory_config.victory = {type = "streak", metric = "current_streak", target = self.streak_target}
    elseif self.victory_condition == "total" then
        victory_config.victory = {type = "threshold", metric = "correct_total", target = self.total_correct_target}
    elseif self.victory_condition == "ratio" then
        -- Note: ratio checking uses flip_history in checkVictoryCondition (kept as is)
        victory_config.victory = {type = "ratio", metric = "flip_history", target = self.ratio_target, count = self.ratio_flip_count}
    elseif self.victory_condition == "time" then
        victory_config.victory = {type = "time_survival", metric = "time_elapsed", target = self.time_limit}
    end

    victory_config.loss = {type = "lives_depleted", metric = "lives"}
    victory_config.check_loss_first = true

    self.victory_checker = VictoryCondition:new(victory_config)
    self.victory_checker.game = self
end

function CoinFlip:setPlayArea(width, height)
    -- Store viewport dimensions for demo playback
    self.viewport_width = width
    self.viewport_height = height
    print("[CoinFlip] Play area updated to:", width, height)
end

function CoinFlip:updateGameLogic(dt)
    -- Check time limit for "time" victory condition
    -- NOTE: time_elapsed is already incremented in BaseGame:updateBase, don't double-increment!
    if not self.game_over and not self.victory then
        if self.victory_condition == "time" and self.time_elapsed >= self.time_limit then
            self.victory = true
        end
    end

    -- Update flip animation (Phase 4 - AnimationSystem component)
    self.flip_animation:update(dt)

    -- Update visual effects (Phase 3 - VisualEffects component)
    self.visual_effects:update(dt)

    -- Update score popups
    -- Phase 6: Update score popups via PopupManager
    self.popup_manager:update(dt)

    -- Handle result display timer
    if self.show_result and not self.game_over and not self.victory then
        self.result_display_time = self.result_display_time + dt
        if self.result_display_time >= 1.5 then
            self.show_result = false
            self.result_display_time = 0
            self.waiting_for_guess = true

            -- Reset auto-flip timer when ready for next flip
            if self.auto_flip_interval > 0 then
                self.auto_flip_timer = self.auto_flip_interval
            end

            -- Reset time per flip timer
            if self.time_per_flip > 0 then
                self.time_per_flip_timer = self.time_per_flip
            end
        end
    end

    -- Auto-flip countdown (Phase 5 completion)
    if self.waiting_for_guess and not self.game_over and not self.victory and self.auto_flip_interval > 0 then
        self.auto_flip_timer = self.auto_flip_timer - dt
        if self.auto_flip_timer <= 0 then
            -- Auto flip (default to heads in auto mode)
            if self.flip_mode == "auto" then
                self:flipCoin()
            else
                -- In guess mode, auto-guess heads if no input
                self:makeGuess('heads')
            end
        end
    end

    -- Time per flip countdown (Phase 5 completion)
    if self.waiting_for_guess and not self.game_over and not self.victory and self.time_per_flip > 0 then
        self.time_per_flip_timer = self.time_per_flip_timer - dt
        if self.time_per_flip_timer <= 0 then
            -- Time ran out, count as incorrect
            if self.flip_mode == "auto" then
                self:flipCoin()  -- Still flip, but streak resets if tails
            else
                self:makeGuess('heads')  -- Default to heads
            end
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

    -- Start flip animation (Phase 11)
    self.flip_animation:start()
    self.flip_timer = 0

    -- Generate result based on pattern mode
    local result = self:generateFlipResult()
    self.last_result = result

    -- Update pattern history (Phase 5 completion)
    table.insert(self.pattern_history, result == 'heads' and 'H' or 'T')
    while #self.pattern_history > self.pattern_history_length do
        table.remove(self.pattern_history, 1)  -- Remove oldest
    end

    -- Update stats
    self.flips_total = self.flips_total + 1

    -- Heads = success (advance streak), Tails = miss (reset)
    if result == 'heads' then
        self.correct_total = self.correct_total + 1
        self.current_streak = self.current_streak + 1
        table.insert(self.flip_history, 1)  -- Track for ratio victory condition

        -- Award score with streak multiplier
        local base_score = self.score_per_correct
        local multiplier = 1 + (self.current_streak * self.streak_multiplier)
        local points = math.floor(base_score * multiplier)
        self.score = self.score + points

        -- Spawn score popup
        if self.score_popup_enabled then
            local w, h = love.graphics.getDimensions()
            local popup_color = {1, 1, 1}  -- White for correct guess
            -- Yellow for streak milestones at 5/10
            if self.current_streak == 5 or self.current_streak == 10 then
                popup_color = {1, 1, 0}
            end
            self.popup_manager:add(w / 2, h / 2 - 50, "+" .. points, popup_color)
        end

        -- Update max streak
        if self.current_streak > self.max_streak then
            self.max_streak = self.current_streak
        end

        -- Visual effects: screen flash + confetti (Phase 3 - VisualEffects component)
        self.visual_effects:flash({0, 1, 0, 0.3}, 0.2, "fade_out")  -- Green flash
        if self.celebration_on_streak and (self.current_streak % 5 == 0) then
            local w, h = love.graphics.getDimensions()
            self.visual_effects:emitConfetti(w / 2, h / 2, 15)
        end

        -- TTS announcement (Phase 5 completion)
        if (self.result_announce_mode == "voice" or self.result_announce_mode == "both") and self.di and self.di.ttsManager then
            local tts = self.di.ttsManager
            local weirdness = (self.di.config and self.di.config.tts and self.di.config.tts.weirdness) or 1
            tts:speakWeird("correct", weirdness)
        end

        -- Check victory condition
        if self:checkVictoryCondition() then
            self.victory = true
            -- Award perfect streak bonus if no mistakes
            if self.perfect_streak and self.incorrect_total == 0 then
                self.score = self.score + self.perfect_streak_bonus
                -- Spawn green popup for perfect streak
                if self.score_popup_enabled then
                    local w, h = love.graphics.getDimensions()
                    self.popup_manager:add(w / 2, h / 2 - 100, "PERFECT! +" .. self.perfect_streak_bonus, {0, 1, 0})
                end
            end
        end
    else
        -- Tails = miss
        self.incorrect_total = self.incorrect_total + 1
        self.perfect_streak = false  -- Mark that we've made a mistake
        self.current_streak = 0  -- Reset streak

        -- Visual effects: screen flash (Phase 3 - VisualEffects component)
        self.visual_effects:flash({1, 0, 0, 0.3}, 0.2, "fade_out")  -- Red flash

        -- TTS announcement (Phase 5 completion)
        if (self.result_announce_mode == "voice" or self.result_announce_mode == "both") and self.di and self.di.ttsManager then
            local tts = self.di.ttsManager
            local weirdness = (self.di.config and self.di.config.tts and self.di.config.tts.weirdness) or 1
            tts:speakWeird("wrong", weirdness)
        end

        table.insert(self.flip_history, 0)  -- Track for ratio victory condition

        -- Phase 10: Use LivesHealthSystem
        if self.lives < 999 then
            self.health_system:takeDamage(1, "wrong_guess")
            self.lives = self.health_system.lives
            if not self.health_system:isAlive() then
                self.game_over = true
            end
        end
    end

    -- Update metrics for formula
    self.metrics.max_streak = self.max_streak
    self.metrics.correct_total = self.correct_total
    self.metrics.flips_total = self.flips_total
    self.metrics.accuracy = self.flips_total > 0 and (self.correct_total / self.flips_total) or 0
    self.metrics.score = self.score

    -- Show result
    self.show_result = true
    self.result_display_time = 0
end

function CoinFlip:makeGuess(guess)
    -- Guess mode: player calls heads or tails
    self.current_guess = guess
    self.last_guess = guess
    self.waiting_for_guess = false

    -- Start flip animation (Phase 11)
    self.flip_animation:start()
    self.flip_timer = 0

    -- Generate result based on pattern mode
    local result = self:generateFlipResult()
    self.last_result = result

    -- Update pattern history (Phase 5 completion)
    table.insert(self.pattern_history, result == 'heads' and 'H' or 'T')
    while #self.pattern_history > self.pattern_history_length do
        table.remove(self.pattern_history, 1)  -- Remove oldest
    end

    -- Update stats
    self.flips_total = self.flips_total + 1

    -- Check if guess was correct
    if guess == result then
        -- Correct guess
        self.correct_total = self.correct_total + 1
        self.current_streak = self.current_streak + 1
        table.insert(self.flip_history, 1)  -- Track for ratio victory condition

        -- Award score with streak multiplier
        local base_score = self.score_per_correct
        local multiplier = 1 + (self.current_streak * self.streak_multiplier)
        local points = math.floor(base_score * multiplier)
        self.score = self.score + points

        -- Spawn score popup
        if self.score_popup_enabled then
            local w, h = love.graphics.getDimensions()
            local popup_color = {1, 1, 1}  -- White for correct guess
            -- Yellow for streak milestones at 5/10
            if self.current_streak == 5 or self.current_streak == 10 then
                popup_color = {1, 1, 0}
            end
            self.popup_manager:add(w / 2, h / 2 - 50, "+" .. points, popup_color)
        end

        -- Update max streak
        if self.current_streak > self.max_streak then
            self.max_streak = self.current_streak
        end

        -- Visual effects: screen flash + confetti (Phase 3 - VisualEffects component)
        self.visual_effects:flash({0, 1, 0, 0.3}, 0.2, "fade_out")  -- Green flash
        if self.celebration_on_streak and (self.current_streak % 5 == 0) then
            local w, h = love.graphics.getDimensions()
            self.visual_effects:emitConfetti(w / 2, h / 2, 15)
        end

        -- TTS announcement (Phase 5 completion)
        if (self.result_announce_mode == "voice" or self.result_announce_mode == "both") and self.di and self.di.ttsManager then
            local tts = self.di.ttsManager
            local weirdness = (self.di.config and self.di.config.tts and self.di.config.tts.weirdness) or 1
            tts:speakWeird("correct", weirdness)
        end

        -- Check victory condition
        if self:checkVictoryCondition() then
            self.victory = true
            -- Award perfect streak bonus if no mistakes
            if self.perfect_streak and self.incorrect_total == 0 then
                self.score = self.score + self.perfect_streak_bonus
                -- Spawn green popup for perfect streak
                if self.score_popup_enabled then
                    local w, h = love.graphics.getDimensions()
                    self.popup_manager:add(w / 2, h / 2 - 100, "PERFECT! +" .. self.perfect_streak_bonus, {0, 1, 0})
                end
            end
        end
    else
        -- Wrong guess
        self.incorrect_total = self.incorrect_total + 1
        self.perfect_streak = false  -- Mark that we've made a mistake
        self.current_streak = 0  -- Reset streak
        table.insert(self.flip_history, 0)  -- Track for ratio victory condition

        -- Visual effects: screen flash (Phase 3 - VisualEffects component)
        self.visual_effects:flash({1, 0, 0, 0.3}, 0.2, "fade_out")  -- Red flash

        -- TTS announcement (Phase 5 completion)
        if (self.result_announce_mode == "voice" or self.result_announce_mode == "both") and self.di and self.di.ttsManager then
            local tts = self.di.ttsManager
            local weirdness = (self.di.config and self.di.config.tts and self.di.config.tts.weirdness) or 1
            tts:speakWeird("wrong", weirdness)
        end

        -- Phase 10: Use LivesHealthSystem
        if self.lives < 999 then
            self.health_system:takeDamage(1, "wrong_guess")
            self.lives = self.health_system.lives
            if not self.health_system:isAlive() then
                self.game_over = true
            end
        end
    end

    -- Update metrics for formula
    self.metrics.max_streak = self.max_streak
    self.metrics.correct_total = self.correct_total
    self.metrics.flips_total = self.flips_total
    self.metrics.accuracy = self.flips_total > 0 and (self.correct_total / self.flips_total) or 0
    self.metrics.score = self.score

    -- Show result
    self.show_result = true
    self.result_display_time = 0
end

function CoinFlip:checkVictoryCondition()
    -- Phase 9: Keep ratio calculation for now (special case), use VictoryCondition for others
    if self.victory_condition == "ratio" then
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
    end

    -- For all other victory types, use VictoryCondition
    local result = self.victory_checker:check()
    if result then
        return result == "victory"
    end
    return false
end

function CoinFlip:checkComplete()
    -- Phase 9: Use VictoryCondition component
    local result = self.victory_checker:check()
    if result then
        self.victory = (result == "victory")
        self.game_over = (result == "loss")
        return true
    end
    return false
end

function CoinFlip:draw()
    self.view:draw()
end

return CoinFlip
