local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local RPSView = require('src.games.views.rps_view')
local RPS = BaseGame:extend('RPS')

-- Config-driven defaults with safe fallbacks
local DEFAULT_ROUNDS_TO_WIN = 3
local DEFAULT_GAME_MODE = "rps"
local DEFAULT_AI_PATTERN = "random"
local DEFAULT_AI_BIAS = 0.33  -- Equal probability for all choices
local DEFAULT_AI_BIAS_STRENGTH = 0.5  -- How much bias affects AI
local DEFAULT_TIME_PER_ROUND = 0  -- Unlimited
local DEFAULT_ROUND_RESULT_DISPLAY_TIME = 2.0
local DEFAULT_SHOW_AI_PATTERN_HINT = false
local DEFAULT_SHOW_PLAYER_HISTORY = true

-- Win matrices for different game modes
local WIN_MATRICES = {
    rps = {
        rock = { beats = {"scissors"}, loses_to = {"paper"} },
        paper = { beats = {"rock"}, loses_to = {"scissors"} },
        scissors = { beats = {"paper"}, loses_to = {"rock"} }
    },
    rpsls = {
        rock = { beats = {"scissors", "lizard"}, loses_to = {"paper", "spock"} },
        paper = { beats = {"rock", "spock"}, loses_to = {"scissors", "lizard"} },
        scissors = { beats = {"paper", "lizard"}, loses_to = {"rock", "spock"} },
        lizard = { beats = {"paper", "spock"}, loses_to = {"rock", "scissors"} },
        spock = { beats = {"rock", "scissors"}, loses_to = {"paper", "lizard"} }
    },
    rpsfb = {
        rock = { beats = {"scissors"}, loses_to = {"paper", "water"} },
        paper = { beats = {"rock"}, loses_to = {"scissors", "fire"} },
        scissors = { beats = {"paper"}, loses_to = {"rock", "water"} },
        fire = { beats = {"paper", "scissors"}, loses_to = {"water", "rock"} },
        water = { beats = {"fire", "rock"}, loses_to = {"paper", "scissors"} }
    }
}

function RPS:init(game_data, cheats, di, variant_override)
    RPS.super.init(self, game_data, cheats, di, variant_override)
    self.di = di

    -- Three-tier fallback: runtimeCfg → variant → DEFAULT
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.rps)

    -- Load parameters with three-tier fallback
    self.rounds_to_win = (runtimeCfg and runtimeCfg.rounds_to_win) or DEFAULT_ROUNDS_TO_WIN
    if self.variant and self.variant.rounds_to_win ~= nil then
        self.rounds_to_win = self.variant.rounds_to_win
    end

    self.game_mode = (runtimeCfg and runtimeCfg.game_mode) or DEFAULT_GAME_MODE
    if self.variant and self.variant.game_mode ~= nil then
        self.game_mode = self.variant.game_mode
    end

    self.ai_pattern = (runtimeCfg and runtimeCfg.ai_pattern) or DEFAULT_AI_PATTERN
    if self.variant and self.variant.ai_pattern ~= nil then
        self.ai_pattern = self.variant.ai_pattern
    end

    -- AI Behavior Parameters
    self.ai_bias = (runtimeCfg and runtimeCfg.ai_bias) or DEFAULT_AI_BIAS
    if self.variant and self.variant.ai_bias ~= nil then
        self.ai_bias = self.variant.ai_bias
    end

    self.ai_bias_strength = (runtimeCfg and runtimeCfg.ai_bias_strength) or DEFAULT_AI_BIAS_STRENGTH
    if self.variant and self.variant.ai_bias_strength ~= nil then
        self.ai_bias_strength = self.variant.ai_bias_strength
    end

    -- Timing Parameters
    self.time_per_round = (runtimeCfg and runtimeCfg.time_per_round) or DEFAULT_TIME_PER_ROUND
    if self.variant and self.variant.time_per_round ~= nil then
        self.time_per_round = self.variant.time_per_round
    end

    self.round_result_display_time = (runtimeCfg and runtimeCfg.round_result_display_time) or DEFAULT_ROUND_RESULT_DISPLAY_TIME
    if self.variant and self.variant.round_result_display_time ~= nil then
        self.round_result_display_time = self.variant.round_result_display_time
    end

    -- Display Parameters
    self.show_ai_pattern_hint = (runtimeCfg and runtimeCfg.show_ai_pattern_hint) or DEFAULT_SHOW_AI_PATTERN_HINT
    if self.variant and self.variant.show_ai_pattern_hint ~= nil then
        self.show_ai_pattern_hint = self.variant.show_ai_pattern_hint
    end

    self.show_player_history = (runtimeCfg and runtimeCfg.show_player_history) or DEFAULT_SHOW_PLAYER_HISTORY
    if self.variant and self.variant.show_player_history ~= nil then
        self.show_player_history = self.variant.show_player_history
    end

    -- Apply difficulty_modifier from variant
    if self.variant and self.variant.difficulty_modifier then
        self.time_per_round = self.time_per_round * self.variant.difficulty_modifier
        self.round_result_display_time = self.round_result_display_time * self.variant.difficulty_modifier
    end

    -- Apply CheatEngine modifications
    if self.cheats.speed_modifier then
        self.round_result_display_time = self.round_result_display_time * self.cheats.speed_modifier
        self.time_per_round = self.time_per_round * self.cheats.speed_modifier
    end
    if self.cheats.advantage_modifier then
        self.rounds_to_win = math.max(1, self.rounds_to_win - math.floor((self.cheats.advantage_modifier or 0) / 2))
    end
    if self.cheats.performance_modifier then
        -- Show hints when performance modifier is active
        self.show_ai_pattern_hint = true
        self.show_player_history = true
    end

    -- Initialize game state
    self.player_wins = 0
    self.ai_wins = 0
    self.ties = 0
    self.rounds_played = 0
    self.current_win_streak = 0
    self.max_win_streak = 0
    self.game_over = false
    self.victory = false

    -- Round state
    self.waiting_for_input = true
    self.player_choice = nil
    self.ai_choice = nil
    self.round_result = nil  -- "win", "lose", "tie"
    self.result_display_time = 0
    self.show_result = false

    -- AI history for patterns
    self.player_history = {}
    self.ai_history = {}

    -- Initialize metrics table for formula
    self.metrics = {
        rounds_won = 0,
        rounds_lost = 0,
        rounds_total = 0,
        max_win_streak = 0,
        accuracy = 0
    }

    -- Create view
    self.view = RPSView:new(self)

    -- Initialize RNG with seed for deterministic AI
    self.rng = love.math.newRandomGenerator(self.seed or os.time())
end

function RPS:updateGameLogic(dt)
    -- Handle result display timer
    if self.show_result and not self.game_over and not self.victory then
        self.result_display_time = self.result_display_time + dt
        if self.result_display_time >= self.round_result_display_time then
            self.show_result = false
            self.result_display_time = 0
            self.waiting_for_input = true
        end
    end
end

function RPS:keypressed(key)
    if not self.waiting_for_input or self.game_over or self.victory then
        return
    end

    -- Handle throw input based on game_mode
    local choice = nil

    -- Basic RPS keys (all modes)
    if key == 'r' then
        choice = 'rock'
    elseif key == 'p' then
        choice = 'paper'
    elseif key == 's' then
        choice = 'scissors'
    end

    -- Extended RPSLS keys
    if self.game_mode == "rpsls" then
        if key == 'l' then
            choice = 'lizard'
        elseif key == 'v' then
            choice = 'spock'
        end
    end

    -- Extended RPSFB keys
    if self.game_mode == "rpsfb" then
        if key == 'f' then
            choice = 'fire'
        elseif key == 'w' then
            choice = 'water'
        end
    end

    if choice then
        self:playRound(choice)
    end
end

function RPS:playRound(player_choice)
    self.player_choice = player_choice
    self.waiting_for_input = false

    -- Generate AI choice based on pattern
    self.ai_choice = self:generateAIChoice()

    -- Determine winner
    self.round_result = self:determineWinner(player_choice, self.ai_choice)

    -- Update stats
    self.rounds_played = self.rounds_played + 1

    if self.round_result == "win" then
        self.player_wins = self.player_wins + 1
        self.current_win_streak = self.current_win_streak + 1

        if self.current_win_streak > self.max_win_streak then
            self.max_win_streak = self.current_win_streak
        end

        -- Check victory
        if self.player_wins >= self.rounds_to_win then
            self.victory = true
        end
    elseif self.round_result == "lose" then
        self.ai_wins = self.ai_wins + 1
        self.current_win_streak = 0

        -- Check game over
        if self.ai_wins >= self.rounds_to_win then
            self.game_over = true
        end
    else
        -- Tie
        self.ties = self.ties + 1
    end

    -- Update history
    table.insert(self.player_history, player_choice)
    table.insert(self.ai_history, self.ai_choice)

    -- Update metrics
    self.metrics.rounds_won = self.player_wins
    self.metrics.rounds_lost = self.ai_wins
    self.metrics.rounds_total = self.rounds_played
    self.metrics.max_win_streak = self.max_win_streak
    local total_decided = self.player_wins + self.ai_wins
    self.metrics.accuracy = total_decided > 0 and (self.player_wins / total_decided) or 0

    -- Show result
    self.show_result = true
    self.result_display_time = 0
end

function RPS:generateAIChoice()
    -- Get available choices for current game mode
    local choices = self:getAvailableChoices()

    if self.ai_pattern == "random" then
        return choices[self.rng:random(1, #choices)]

    elseif self.ai_pattern == "repeat_last" and #self.ai_history > 0 then
        return self.ai_history[#self.ai_history]

    elseif self.ai_pattern == "counter_player" and #self.player_history > 0 then
        -- Throw what beats player's last choice
        local last_player = self.player_history[#self.player_history]
        local win_matrix = WIN_MATRICES[self.game_mode]
        if win_matrix and win_matrix[last_player] and win_matrix[last_player].loses_to then
            -- Pick randomly from options that beat the player's last choice
            local counters = win_matrix[last_player].loses_to
            return counters[self.rng:random(1, #counters)]
        end
        return choices[self.rng:random(1, #choices)]

    elseif self.ai_pattern == "pattern_cycle" then
        -- Cycle through choices in order
        local cycle_index = (#self.ai_history % #choices) + 1
        return choices[cycle_index]

    elseif self.ai_pattern == "mimic_player" and #self.player_history > 0 then
        -- Copy player's previous choice
        return self.player_history[#self.player_history]

    elseif self.ai_pattern == "anti_player" and #self.player_history >= 2 then
        -- Throw what player threw 2 rounds ago
        return self.player_history[#self.player_history - 1]

    else
        -- Default to random
        return choices[self.rng:random(1, #choices)]
    end
end

function RPS:getAvailableChoices()
    -- Return available choices based on game mode
    if self.game_mode == "rpsls" then
        return {"rock", "paper", "scissors", "lizard", "spock"}
    elseif self.game_mode == "rpsfb" then
        return {"rock", "paper", "scissors", "fire", "water"}
    else
        -- Default RPS
        return {"rock", "paper", "scissors"}
    end
end

function RPS:determineWinner(player, ai)
    if player == ai then
        return "tie"
    end

    -- Get win matrix for current game mode
    local win_matrix = WIN_MATRICES[self.game_mode]
    if not win_matrix or not win_matrix[player] then
        return "tie"  -- Safety fallback
    end

    -- Check if player's choice beats AI's choice
    local beats_list = win_matrix[player].beats
    for _, beaten in ipairs(beats_list) do
        if beaten == ai then
            return "win"
        end
    end

    return "lose"
end

function RPS:checkComplete()
    return self.victory or self.game_over
end

function RPS:draw()
    self.view:draw()
end

return RPS
