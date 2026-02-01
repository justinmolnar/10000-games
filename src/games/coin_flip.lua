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

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function CoinFlip:init(game_data, cheats, di, variant_override)
    CoinFlip.super.init(self, game_data, cheats, di, variant_override)
    self.di = di
    self.cheats = cheats or {}

    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.coin_flip)
    self.params = SchemaLoader.load(self.variant, "coin_flip_schema", runtimeCfg)

    self:applyModifiers()
    self:setupGameState()
    self:setupComponents()

    self.view = CoinFlipView:new(self)
end

function CoinFlip:applyModifiers()
    local p = self.params

    self.time_per_flip = p.time_per_flip
    self.flip_animation_speed = p.flip_animation_speed
    self.coin_bias = p.coin_bias
    self.starting_lives = p.lives

    if p.difficulty_modifier ~= 1.0 then
        self.time_per_flip = self.time_per_flip * p.difficulty_modifier
    end

    if self.cheats.speed_modifier then
        self.flip_animation_speed = self.flip_animation_speed * self.cheats.speed_modifier
        self.time_per_flip = self.time_per_flip * self.cheats.speed_modifier
    end
    if self.cheats.advantage_modifier then
        self.starting_lives = self.starting_lives + (self.cheats.advantage_modifier or 0)
    end
    if self.cheats.performance_modifier then
        local bias_adjustment = (0.5 - self.coin_bias) * (self.cheats.performance_modifier or 0)
        self.coin_bias = self.coin_bias + bias_adjustment
    end
end

function CoinFlip:setupGameState()
    self.rng = love.math.newRandomGenerator(self.seed or os.time())

    self.current_streak = 0
    self.max_streak = 0
    self.correct_total = 0
    self.incorrect_total = 0
    self.flips_total = 0
    self.game_over = false
    self.victory = false

    self.waiting_for_guess = true
    self.current_guess = nil
    self.last_result = nil
    self.last_guess = nil
    self.result_display_time = 0
    self.show_result = false

    self.pattern_state = {
        last_result = nil,
        cluster_remaining = 0,
        cluster_value = nil
    }

    self.time_elapsed = 0
    self.flip_history = {}
    self.pattern_history = {}
    self.auto_flip_timer = 0
    self.time_per_flip_timer = 0

    self.score = 0
    self.perfect_streak = true

    self.metrics = {
        max_streak = 0,
        correct_total = 0,
        flips_total = 0,
        accuracy = 0,
        score = 0
    }
end

function CoinFlip:setupComponents()
    local p = self.params

    self.popup_manager = PopupManager:new()

    self.visual_effects = VisualEffects:new({
        camera_shake_enabled = false,
        screen_flash_enabled = p.screen_flash_enabled,
        particle_effects_enabled = true
    })

    self.flip_animation = AnimationSystem.createFlipAnimation({
        duration = 0.5,
        speed_multiplier = self.flip_animation_speed,
        on_complete = nil
    })

    self.health_system = LivesHealthSystem:new({
        mode = "lives",
        starting_lives = self.starting_lives,
        max_lives = 10
    })
    self.lives = self.health_system.lives

    self.hud = HUDRenderer:new({
        primary = {label = "Score", key = "score"},
        secondary = {label = "Streak", key = "current_streak"},
        lives = {key = "lives", max = self.starting_lives, style = "hearts"}
    })
    self.hud.game = self

    self:setupVictoryCondition()
end

function CoinFlip:setupVictoryCondition()
    local p = self.params
    local victory_config = {}

    if p.victory_condition == "streak" then
        victory_config.victory = {type = "streak", metric = "current_streak", target = p.streak_target}
    elseif p.victory_condition == "total" then
        victory_config.victory = {type = "threshold", metric = "correct_total", target = p.total_correct_target}
    elseif p.victory_condition == "ratio" then
        victory_config.victory = {type = "ratio", metric = "flip_history", target = p.ratio_target, count = p.ratio_flip_count}
    elseif p.victory_condition == "time" then
        victory_config.victory = {type = "time_survival", metric = "time_elapsed", target = p.time_limit}
    end

    victory_config.loss = {type = "lives_depleted", metric = "lives"}
    victory_config.check_loss_first = true

    self.victory_checker = VictoryCondition:new(victory_config)
    self.victory_checker.game = self
end

--------------------------------------------------------------------------------
-- ASSETS
--------------------------------------------------------------------------------

function CoinFlip:setPlayArea(width, height)
    self.viewport_width = width
    self.viewport_height = height
end

--------------------------------------------------------------------------------
-- MAIN GAME LOOP
--------------------------------------------------------------------------------

function CoinFlip:updateGameLogic(dt)
    if not self.game_over and not self.victory then
        if self.params.victory_condition == "time" and self.time_elapsed >= self.params.time_limit then
            self.victory = true
        end
    end

    self.flip_animation:update(dt)
    self.visual_effects:update(dt)
    self.popup_manager:update(dt)

    if self.show_result and not self.game_over and not self.victory then
        self.result_display_time = self.result_display_time + dt
        if self.result_display_time >= 1.5 then
            self.show_result = false
            self.result_display_time = 0
            self.waiting_for_guess = true

            if self.params.auto_flip_interval > 0 then
                self.auto_flip_timer = self.params.auto_flip_interval
            end

            if self.time_per_flip > 0 then
                self.time_per_flip_timer = self.time_per_flip
            end
        end
    end

    if self.waiting_for_guess and not self.game_over and not self.victory and self.params.auto_flip_interval > 0 then
        self.auto_flip_timer = self.auto_flip_timer - dt
        if self.auto_flip_timer <= 0 then
            if self.params.flip_mode == "auto" then
                self:flipCoin()
            else
                self:makeGuess('heads')
            end
        end
    end

    if self.waiting_for_guess and not self.game_over and not self.victory and self.time_per_flip > 0 then
        self.time_per_flip_timer = self.time_per_flip_timer - dt
        if self.time_per_flip_timer <= 0 then
            if self.params.flip_mode == "auto" then
                self:flipCoin()
            else
                self:makeGuess('heads')
            end
        end
    end
end

function CoinFlip:draw()
    self.view:draw()
end

--------------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------------

function CoinFlip:keypressed(key)
    if not self.waiting_for_guess or self.game_over or self.victory then
        return
    end

    if self.params.flip_mode == "auto" then
        if key == 'space' then
            self:flipCoin()
        end
    else
        if key == 'h' then
            self:makeGuess('heads')
        elseif key == 't' then
            self:makeGuess('tails')
        end
    end
end

--------------------------------------------------------------------------------
-- FLIP LOGIC
--------------------------------------------------------------------------------

function CoinFlip:generateFlipResult()
    local result

    if self.params.pattern_mode == "alternating" then
        if self.pattern_state.last_result == nil then
            local flip_value = self.rng:random()
            result = flip_value < self.coin_bias and 'heads' or 'tails'
        else
            result = self.pattern_state.last_result == 'heads' and 'tails' or 'heads'
        end

    elseif self.params.pattern_mode == "clusters" then
        if self.pattern_state.cluster_remaining > 0 then
            result = self.pattern_state.cluster_value
            self.pattern_state.cluster_remaining = self.pattern_state.cluster_remaining - 1
        else
            local flip_value = self.rng:random()
            result = flip_value < self.coin_bias and 'heads' or 'tails'
            self.pattern_state.cluster_value = result
            self.pattern_state.cluster_remaining = self.rng:random(2, 5) - 1
        end

    elseif self.params.pattern_mode == "biased_random" then
        local adjusted_bias = self.coin_bias
        if self.current_streak > 0 then
            adjusted_bias = math.min(0.95, adjusted_bias + 0.05)
        end
        local flip_value = self.rng:random()
        result = flip_value < adjusted_bias and 'heads' or 'tails'

    else
        local flip_value = self.rng:random()
        result = flip_value < self.coin_bias and 'heads' or 'tails'
    end

    self.pattern_state.last_result = result
    return result
end

function CoinFlip:flipCoin()
    self.waiting_for_guess = false
    self.flip_animation:start()
    self.flip_timer = 0

    local result = self:generateFlipResult()
    self.last_result = result

    table.insert(self.pattern_history, result == 'heads' and 'H' or 'T')
    while #self.pattern_history > self.params.pattern_history_length do
        table.remove(self.pattern_history, 1)
    end

    self.flips_total = self.flips_total + 1

    -- In auto mode, heads = success
    local is_correct = (result == 'heads')
    self:processFlipResult(is_correct, result)
end

function CoinFlip:makeGuess(guess)
    self.current_guess = guess
    self.last_guess = guess
    self.waiting_for_guess = false
    self.flip_animation:start()
    self.flip_timer = 0

    local result = self:generateFlipResult()
    self.last_result = result

    table.insert(self.pattern_history, result == 'heads' and 'H' or 'T')
    while #self.pattern_history > self.params.pattern_history_length do
        table.remove(self.pattern_history, 1)
    end

    self.flips_total = self.flips_total + 1

    -- In guess mode, correct = guess matches result
    local is_correct = (guess == result)
    self:processFlipResult(is_correct, result)
end

function CoinFlip:processFlipResult(is_correct, result)
    if is_correct then
        self:onCorrectFlip()
    else
        self:onIncorrectFlip()
    end

    self:updateMetrics()

    self.show_result = true
    self.result_display_time = 0
end

function CoinFlip:onCorrectFlip()
    self.correct_total = self.correct_total + 1
    self.current_streak = self.current_streak + 1
    table.insert(self.flip_history, 1)

    local base_score = self.params.score_per_correct
    local multiplier = 1 + (self.current_streak * self.params.streak_multiplier)
    local points = math.floor(base_score * multiplier)
    self.score = self.score + points

    if self.params.score_popup_enabled then
        local w, h = love.graphics.getDimensions()
        local popup_color = {1, 1, 1}
        if self.current_streak == 5 or self.current_streak == 10 then
            popup_color = {1, 1, 0}
        end
        self.popup_manager:add(w / 2, h / 2 - 50, "+" .. points, popup_color)
    end

    if self.current_streak > self.max_streak then
        self.max_streak = self.current_streak
    end

    self.visual_effects:flash({color = {0, 1, 0, 0.3}, duration = 0.2, mode = "fade_out"})
    if self.params.celebration_on_streak and (self.current_streak % 5 == 0) and self.visual_effects.particles then
        local w, h = love.graphics.getDimensions()
        self.visual_effects.particles:emitConfetti(w / 2, h / 2, 15)
    end

    if (self.params.result_announce_mode == "voice" or self.params.result_announce_mode == "both") and self.di and self.di.ttsManager then
        local tts = self.di.ttsManager
        local weirdness = (self.di.config and self.di.config.tts and self.di.config.tts.weirdness) or 1
        tts:speakWeird("correct", weirdness)
    end

    if self:checkVictoryCondition() then
        self.victory = true
        if self.perfect_streak and self.incorrect_total == 0 then
            self.score = self.score + self.params.perfect_streak_bonus
            if self.params.score_popup_enabled then
                local w, h = love.graphics.getDimensions()
                self.popup_manager:add(w / 2, h / 2 - 100, "PERFECT! +" .. self.params.perfect_streak_bonus, {0, 1, 0})
            end
        end
    end
end

function CoinFlip:onIncorrectFlip()
    self.incorrect_total = self.incorrect_total + 1
    self.perfect_streak = false
    self.current_streak = 0
    table.insert(self.flip_history, 0)

    self.visual_effects:flash({color = {1, 0, 0, 0.3}, duration = 0.2, mode = "fade_out"})

    if (self.params.result_announce_mode == "voice" or self.params.result_announce_mode == "both") and self.di and self.di.ttsManager then
        local tts = self.di.ttsManager
        local weirdness = (self.di.config and self.di.config.tts and self.di.config.tts.weirdness) or 1
        tts:speakWeird("wrong", weirdness)
    end

    if self.lives < 999 then
        self.health_system:takeDamage(1, "wrong_guess")
        self.lives = self.health_system.lives
        if not self.health_system:isAlive() then
            self.game_over = true
        end
    end
end

function CoinFlip:updateMetrics()
    self.metrics.max_streak = self.max_streak
    self.metrics.correct_total = self.correct_total
    self.metrics.flips_total = self.flips_total
    self.metrics.accuracy = self.flips_total > 0 and (self.correct_total / self.flips_total) or 0
    self.metrics.score = self.score
end

--------------------------------------------------------------------------------
-- GAME STATE / VICTORY
--------------------------------------------------------------------------------

function CoinFlip:checkVictoryCondition()
    if self.params.victory_condition == "ratio" then
        if #self.flip_history >= self.params.ratio_flip_count then
            local recent_correct = 0
            local start_index = math.max(1, #self.flip_history - self.params.ratio_flip_count + 1)
            for i = start_index, #self.flip_history do
                if self.flip_history[i] == 1 then
                    recent_correct = recent_correct + 1
                end
            end
            local recent_accuracy = recent_correct / math.min(#self.flip_history, self.params.ratio_flip_count)
            return recent_accuracy >= self.params.ratio_target
        end
        return false
    end

    local result = self.victory_checker:check()
    if result then
        return result == "victory"
    end
    return false
end

function CoinFlip:checkComplete()
    local result = self.victory_checker:check()
    if result then
        self.victory = (result == "victory")
        self.game_over = (result == "loss")
        return true
    end
    return false
end

return CoinFlip
