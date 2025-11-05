local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local RPSView = require('src.games.views.rps_view')
local RPS = BaseGame:extend('RPS')

-- Config-driven defaults with safe fallbacks
local DEFAULT_ROUNDS_TO_WIN = 3
local DEFAULT_GAME_MODE = "rps"
local DEFAULT_AI_PATTERN = "random"

-- Win matrix for RPS
local WIN_MATRIX = {
    rock = { beats = "scissors", loses_to = "paper" },
    paper = { beats = "rock", loses_to = "scissors" },
    scissors = { beats = "paper", loses_to = "rock" }
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
        if self.result_display_time >= 2.0 then
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

    -- Handle throw input (only basic RPS for now)
    local choice = nil
    if key == 'r' then
        choice = 'rock'
    elseif key == 'p' then
        choice = 'paper'
    elseif key == 's' then
        choice = 'scissors'
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
    -- For now, implement basic patterns
    if self.ai_pattern == "random" then
        local choices = {"rock", "paper", "scissors"}
        return choices[self.rng:random(1, 3)]
    elseif self.ai_pattern == "repeat_last" and #self.ai_history > 0 then
        return self.ai_history[#self.ai_history]
    elseif self.ai_pattern == "counter_player" and #self.player_history > 0 then
        -- Throw what beats player's last choice
        local last_player = self.player_history[#self.player_history]
        local counters = { rock = "paper", paper = "scissors", scissors = "rock" }
        return counters[last_player] or "rock"
    else
        -- Default to random
        local choices = {"rock", "paper", "scissors"}
        return choices[self.rng:random(1, 3)]
    end
end

function RPS:determineWinner(player, ai)
    if player == ai then
        return "tie"
    end

    if WIN_MATRIX[player] and WIN_MATRIX[player].beats == ai then
        return "win"
    else
        return "lose"
    end
end

function RPS:checkComplete()
    return self.victory or self.game_over
end

function RPS:draw()
    self.view:draw()
end

return RPS
