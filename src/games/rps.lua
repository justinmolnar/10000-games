local BaseGame = require('src.games.base_game')
local RPSView = require('src.games.views.rps_view')
local RPS = BaseGame:extend('RPS')

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function RPS:init(game_data, cheats, di, variant_override)
    RPS.super.init(self, game_data, cheats, di, variant_override)

    local SchemaLoader = self.di.components.SchemaLoader
    local runtimeCfg = self.di.config and self.di.config.games and self.di.config.games.rps
    self.params = SchemaLoader.load(self.variant, "rps_schema", runtimeCfg)

    self:setupGameState()
    self:setupComponents()

    self.view = RPSView:new(self)
end

function RPS:setupGameState()
    local p = self.params

    -- Game state counters
    self.player_wins = 0
    self.ai_wins = 0
    self.ties = 0
    self.rounds_played = 0
    self.current_win_streak = 0
    self.max_win_streak = 0
    self.score = 0

    -- Round state
    self.waiting_for_input = true
    self.result_display_time = 0
    self.show_result = false

    -- AI history for patterns
    self.player_history = {}
    self.ai_history = {}

    -- Double hands mode state
    self.phase = "selection"
    self.removal_timer = 0

    -- Multiple opponents state
    local num_opponents = math.max(1, math.min(5, p.num_opponents))
    self.opponents = {}
    for i = 1, num_opponents do
        table.insert(self.opponents, {
            id = i,
            wins = 0,
            eliminated = false,
            pattern = p.ai_pattern,
            history = {}
        })
    end

    -- History display state
    self.throw_history = {}

    -- Metrics
    self.metrics = {
        rounds_won = 0,
        rounds_lost = 0,
        rounds_total = 0,
        max_win_streak = 0,
        accuracy = 0,
        score = 0
    }

    -- RNG for deterministic AI
    self.rng = love.math.newRandomGenerator(self.seed or os.time())
end

function RPS:setupComponents()
    local p = self.params
    local AnimationSystem = self.di.components.AnimationSystem
    local LivesHealthSystem = self.di.components.LivesHealthSystem
    local PopupManager = self.di.components.PopupManager

    -- Score popups
    self.popup_manager = PopupManager:new()

    -- Create visual_effects and hud from schema
    self:createComponentsFromSchema()

    -- Throw animation
    self.throw_animation = AnimationSystem.createBounceAnimation({
        duration = 0.5,
        height = 20,
        speed_multiplier = p.animation_speed
    })

    -- Lives/Health System
    self.health_system = LivesHealthSystem:new({
        mode = "lives",
        starting_lives = p.lives,
        max_lives = 999,
        lose_life_on = p.lose_life_on
    })
    self.lives = self.health_system.lives

    -- Victory Condition - configure loss based on lives
    local loss_config
    if p.lives < 999 then
        loss_config = {type = "lives_depleted", metric = "lives"}
    else
        loss_config = {type = "threshold", metric = "ai_wins", target = p.rounds_to_win}
    end
    self:createVictoryConditionFromSchema()
    if self.victory_checker then
        self.victory_checker.loss = loss_config
    end

    -- Try to activate special round for first throw
    self.current_special_round = self:activateSpecialRound()
end

--------------------------------------------------------------------------------
-- MAIN GAME LOOP
--------------------------------------------------------------------------------

function RPS:updateGameLogic(dt)
    -- Check time limit (for "time" victory condition)
    if not self.game_over and not self.victory and self.params.victory_condition == "time" then
        if self.time_elapsed >= self.params.time_limit then
            if self.player_wins > self.ai_wins then
                self.victory = true
            else
                self.game_over = true
            end
        end
    end

    -- Double hands removal timer
    if self.params.hands_mode == "double" and self.phase == "removal" and self.params.time_per_removal > 0 then
        self.removal_timer = self.removal_timer - dt
        if self.removal_timer <= 0 then
            -- Time's up - randomly choose one hand to keep for both players
            local player_final = (self.rng:random() < 0.5 and self.player_left_hand) or self.player_right_hand
            local ai_final = (self.rng:random() < 0.5 and self.ai_left_hand) or self.ai_right_hand

            if player_final and ai_final then
                self.ai_choice = ai_final
                self:playRound(player_final)
            end

            self.player_left_hand = nil
            self.player_right_hand = nil
            self.ai_left_hand = nil
            self.ai_right_hand = nil
            self.phase = "selection"
        end
    end

    self.throw_animation:update(dt)
    self.visual_effects:update(dt)
    self.popup_manager:update(dt)

    -- Handle result display timer
    if self.show_result and not self.game_over and not self.victory then
        self.result_display_time = self.result_display_time + dt
        if self.result_display_time >= self.params.round_result_display_time then
            self.show_result = false
            self.result_display_time = 0
            self.waiting_for_input = true

            -- Activate special round for next round
            if not self.current_special_round then
                self.current_special_round = self:activateSpecialRound()
            end
        end
    end
end

function RPS:draw()
    self.view:draw()
end

--------------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------------

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
    if self.params.game_mode == "rpsls" then
        if key == 'l' then
            choice = 'lizard'
        elseif key == 'v' then
            choice = 'spock'
        end
    end

    -- Extended RPSFB keys
    if self.params.game_mode == "rpsfb" then
        if key == 'f' then
            choice = 'fire'
        elseif key == 'w' then
            choice = 'water'
        end
    end

    -- Double hands mode - handle removal phase number keys first
    if self.params.hands_mode == "double" and self.phase == "removal" then
        local player_final = nil
        if key == '1' and self.player_left_hand then
            player_final = self.player_left_hand
        elseif key == '2' and self.player_right_hand then
            player_final = self.player_right_hand
        end

        if player_final then
            local ai_final = (self.rng:random() < 0.5 and self.ai_left_hand) or self.ai_right_hand
            print("[RPS] AI keeps:", ai_final)

            self.ai_choice = ai_final
            self:playRound(player_final)

            self.player_left_hand = nil
            self.player_right_hand = nil
            self.ai_left_hand = nil
            self.ai_right_hand = nil
            self.phase = "selection"
            return
        end
    end

    if choice then
        if self.params.hands_mode == "double" then
            if self.phase == "selection" then
                if not self.player_left_hand then
                    self.player_left_hand = choice
                elseif not self.player_right_hand then
                    self.player_right_hand = choice
                    self.ai_left_hand = self:generateAIChoice()
                    self.ai_right_hand = self:generateAIChoice()
                    self.phase = "removal"
                    self.waiting_for_input = true
                    self.removal_timer = self.params.time_per_removal
                end
            end
        else
            self:playRound(choice)
        end
    end
end

--------------------------------------------------------------------------------
-- ROUND LOGIC
--------------------------------------------------------------------------------

function RPS:playRound(player_choice)
    self.player_choice = player_choice
    self.waiting_for_input = false
    self.throw_animation:start()

    if #self.opponents > 1 then
        self:playRoundMultipleOpponents(player_choice)
        return
    end

    self.ai_choice = self:generateAIChoice()
    self.round_result = self:determineWinner(player_choice, self.ai_choice)

    -- Apply special round rules
    if self.current_special_round == "reverse" then
        if self.round_result == "win" then
            self.round_result = "lose"
        elseif self.round_result == "lose" then
            self.round_result = "win"
        end
    elseif self.current_special_round == "mirror" then
        if player_choice == self.ai_choice then
            self.round_result = "win"
        else
            self.round_result = "tie"
        end
    end

    -- Update stats
    self.rounds_played = self.rounds_played + 1

    if self.round_result == "win" then
        self:onRoundWin()
    elseif self.round_result == "lose" then
        self:onRoundLose()
    else
        self:onRoundTie()
    end

    table.insert(self.player_history, player_choice)
    table.insert(self.ai_history, self.ai_choice)

    if self.params.show_history_display then
        table.insert(self.throw_history, {
            player = player_choice,
            ai = self.ai_choice,
            result = self.round_result
        })
        while #self.throw_history > self.params.history_length do
            table.remove(self.throw_history, 1)
        end
    end

    self:updateMetrics()

    self.last_special_round = self.current_special_round
    self.current_special_round = nil

    self.show_result = true
    self.result_display_time = 0
end

function RPS:onRoundWin()
    self.player_wins = self.player_wins + 1
    self.current_win_streak = self.current_win_streak + 1

    local round_points = self.params.score_per_round_win
    if self.current_special_round == "double_or_nothing" then
        round_points = round_points * 2
    end
    self.score = self.score + round_points

    local total_points = round_points
    if self.current_win_streak > 1 then
        local streak_points = self.params.streak_bonus * self.current_win_streak
        self.score = self.score + streak_points
        total_points = total_points + streak_points
    end

    if self.params.score_popup_enabled then
        local w, h = love.graphics.getDimensions()
        local popup_color = (self.current_win_streak == 3 or self.current_win_streak == 5) and {1, 1, 0} or {1, 1, 1}
        self.popup_manager:add(w / 2, h / 2 - 50, "+" .. math.floor(total_points), popup_color)
    end

    if self.current_win_streak > self.max_win_streak then
        self.max_win_streak = self.current_win_streak
    end

    self.visual_effects:flash({0, 1, 0, 0.3}, 0.2, "fade_out")

    if self.current_special_round == "sudden_death" then
        self.victory = true
    end

    if self:checkVictoryCondition() then
        self.victory = true
        if self.ai_wins == 0 then
            self.score = self.score + self.params.perfect_game_bonus
            if self.params.score_popup_enabled then
                local w, h = love.graphics.getDimensions()
                self.popup_manager:add(w / 2, h / 2 - 100, "PERFECT GAME! +" .. self.params.perfect_game_bonus, {0, 1, 0})
            end
            if self.params.celebration_on_perfect then
                local w, h = love.graphics.getDimensions()
                self.visual_effects:emitConfetti(w / 2, h / 2, 30)
            end
        end
    end
end

function RPS:onRoundLose()
    self.ai_wins = self.ai_wins + 1
    self.current_win_streak = 0

    if self.current_special_round == "double_or_nothing" then
        self.score = math.max(0, self.score - self.params.score_per_round_win)
    end

    if self.current_special_round == "sudden_death" then
        self.game_over = true
    end

    self.visual_effects:flash({1, 0, 0, 0.3}, 0.2, "fade_out")

    if self.lives < 999 and (self.params.lose_life_on == "loss" or self.params.lose_life_on == "both") then
        self.health_system:takeDamage(1, "round_loss")
        self.lives = self.health_system.lives
        if not self.health_system:isAlive() then
            self.game_over = true
        end
    end

    if self.ai_wins >= self.params.rounds_to_win then
        self.game_over = true
    end
end

function RPS:onRoundTie()
    self.ties = self.ties + 1

    if self.lives < 999 and (self.params.lose_life_on == "tie" or self.params.lose_life_on == "both") then
        self.health_system:takeDamage(1, "round_tie")
        self.lives = self.health_system.lives
        if not self.health_system:isAlive() then
            self.game_over = true
        end
    end
end

function RPS:updateMetrics()
    self.metrics.rounds_won = self.player_wins
    self.metrics.rounds_lost = self.ai_wins
    self.metrics.rounds_total = self.rounds_played
    self.metrics.max_win_streak = self.max_win_streak
    local total_decided = self.player_wins + self.ai_wins
    self.metrics.accuracy = total_decided > 0 and (self.player_wins / total_decided) or 0
    self.metrics.score = self.score
end

function RPS:playRoundMultipleOpponents(player_choice)
    self.rounds_played = self.rounds_played + 1
    local player_wins_this_round = 0
    local player_losses_this_round = 0
    local player_ties_this_round = 0

    for _, opponent in ipairs(self.opponents) do
        if not opponent.eliminated then
            opponent.choice = self:generateAIChoiceForOpponent(opponent)
            local result = self:determineWinner(player_choice, opponent.choice)

            if result == "win" then
                player_wins_this_round = player_wins_this_round + 1
            elseif result == "lose" then
                player_losses_this_round = player_losses_this_round + 1
                opponent.wins = opponent.wins + 1
                if self.params.elimination_mode and opponent.wins >= self.params.rounds_to_win then
                    self.game_over = true
                end
            else
                player_ties_this_round = player_ties_this_round + 1
            end
            table.insert(opponent.history, opponent.choice)
        end
    end

    -- Update player stats based on majority result
    if player_wins_this_round > player_losses_this_round then
        self.player_wins = self.player_wins + 1
        self.current_win_streak = self.current_win_streak + 1
        self.round_result = "win"
    elseif player_losses_this_round > player_wins_this_round then
        self.ai_wins = self.ai_wins + 1
        self.current_win_streak = 0
        self.round_result = "lose"
    else
        self.ties = self.ties + 1
        self.round_result = "tie"
    end

    if self.current_win_streak > self.max_win_streak then
        self.max_win_streak = self.current_win_streak
    end

    if self:checkVictoryCondition() then
        self.victory = true
    end

    self:updateMetrics()
    table.insert(self.player_history, player_choice)

    self.show_result = true
    self.result_display_time = 0
end

--------------------------------------------------------------------------------
-- AI SYSTEM
--------------------------------------------------------------------------------

function RPS:generateAIChoice()
    local choices = self:getAvailableChoices()

    if self.params.ai_pattern_delay > 0 and self.rounds_played < self.params.ai_pattern_delay then
        return choices[self.rng:random(1, #choices)]
    end

    local pattern = self.params.ai_pattern
    if pattern == "random" then
        return choices[self.rng:random(1, #choices)]
    elseif pattern == "repeat_last" and #self.ai_history > 0 then
        return self.ai_history[#self.ai_history]
    elseif pattern == "counter_player" and #self.player_history > 0 then
        local last_player = self.player_history[#self.player_history]
        local win_matrix = self.params.win_matrices[self.params.game_mode]
        if win_matrix and win_matrix[last_player] and win_matrix[last_player].loses_to then
            local counters = win_matrix[last_player].loses_to
            return counters[self.rng:random(1, #counters)]
        end
        return choices[self.rng:random(1, #choices)]
    elseif pattern == "pattern_cycle" then
        local cycle_index = (#self.ai_history % #choices) + 1
        return choices[cycle_index]
    elseif pattern == "mimic_player" and #self.player_history > 0 then
        return self.player_history[#self.player_history]
    elseif pattern == "anti_player" and #self.player_history >= 2 then
        return self.player_history[#self.player_history - 1]
    else
        return choices[self.rng:random(1, #choices)]
    end
end

function RPS:generateAIChoiceForOpponent(opponent)
    local choices = self:getAvailableChoices()

    if self.params.ai_pattern_delay > 0 and self.rounds_played < self.params.ai_pattern_delay then
        return choices[self.rng:random(1, #choices)]
    end

    if opponent.pattern == "random" then
        return choices[self.rng:random(1, #choices)]
    elseif opponent.pattern == "repeat_last" and #opponent.history > 0 then
        return opponent.history[#opponent.history]
    elseif opponent.pattern == "counter_player" and #self.player_history > 0 then
        local last_player = self.player_history[#self.player_history]
        local win_matrix = self.params.win_matrices[self.params.game_mode]
        if win_matrix and win_matrix[last_player] and win_matrix[last_player].loses_to then
            local counters = win_matrix[last_player].loses_to
            return counters[self.rng:random(1, #counters)]
        end
        return choices[self.rng:random(1, #choices)]
    elseif opponent.pattern == "pattern_cycle" then
        local cycle_index = (#opponent.history % #choices) + 1
        return choices[cycle_index]
    elseif opponent.pattern == "mimic_player" and #self.player_history > 0 then
        return self.player_history[#self.player_history]
    elseif opponent.pattern == "anti_player" and #self.player_history >= 2 then
        return self.player_history[#self.player_history - 1]
    else
        return choices[self.rng:random(1, #choices)]
    end
end

function RPS:getAvailableChoices()
    if self.params.game_mode == "rpsls" then
        return {"rock", "paper", "scissors", "lizard", "spock"}
    elseif self.params.game_mode == "rpsfb" then
        return {"rock", "paper", "scissors", "fire", "water"}
    else
        return {"rock", "paper", "scissors"}
    end
end

function RPS:determineWinner(player, ai)
    if player == ai then
        return "tie"
    end

    local win_matrix = self.params.win_matrices[self.params.game_mode]
    if not win_matrix or not win_matrix[player] then
        return "tie"
    end

    local beats_list = win_matrix[player].beats
    for _, beaten in ipairs(beats_list) do
        if beaten == ai then
            return "win"
        end
    end
    return "lose"
end

--------------------------------------------------------------------------------
-- GAME STATE / VICTORY
--------------------------------------------------------------------------------

function RPS:checkVictoryCondition()
    local result = self.victory_checker:check()
    if result then
        return result == "victory"
    end
    return false
end

function RPS:checkComplete()
    local result = self.victory_checker:check()
    if result then
        self.victory = (result == "victory")
        self.game_over = (result == "loss")
        return true
    end
    return false
end

function RPS:setPlayArea(width, height)
    RPS.super.setPlayArea(self, width, height)
    self.viewport_width = width
    self.viewport_height = height
end

--------------------------------------------------------------------------------
-- SPECIAL ROUNDS
--------------------------------------------------------------------------------

function RPS:activateSpecialRound()
    if not self.params.special_rounds_enabled then
        return nil
    end

    local available_specials = {}
    if self.params.double_or_nothing_enabled then table.insert(available_specials, "double_or_nothing") end
    if self.params.sudden_death_enabled then table.insert(available_specials, "sudden_death") end
    if self.params.reverse_mode_enabled then table.insert(available_specials, "reverse") end
    if self.params.mirror_mode_enabled then table.insert(available_specials, "mirror") end

    if #available_specials == 0 then
        return nil
    end

    if self.rng:random() < 0.5 then
        return available_specials[self.rng:random(1, #available_specials)]
    end
    return nil
end

return RPS
