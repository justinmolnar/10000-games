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
    self.show_result = false

    -- AI history for patterns
    self.player_history = {}
    self.ai_history = {}

    -- Double hands mode state
    self.phase = "selection"

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

    -- Result display timer
    self.result_timer = AnimationSystem.createTimer(p.round_result_display_time, function()
        self.show_result = false
        self.waiting_for_input = true
        if not self.current_special_round then
            self.current_special_round = self:activateSpecialRound()
        end
    end)

    -- Double hands removal timer
    self.removal_timer = AnimationSystem.createTimer(p.time_per_removal, function()
        self:onRemovalTimeout()
    end)

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
    self.throw_animation:update(dt)
    self.visual_effects:update(dt)
    self.popup_manager:update(dt)
    self.result_timer:update(dt)
    self.removal_timer:update(dt)
end

function RPS:onRemovalTimeout()
    local player_final = (self.rng:random() < 0.5 and self.player_left_hand) or self.player_right_hand
    local ai_final = (self.rng:random() < 0.5 and self.ai_left_hand) or self.ai_right_hand

    if player_final and ai_final then
        self.ai_choice = ai_final
        self:playRound(player_final)
    end

    self:clearDoubleHandsState()
end

function RPS:clearDoubleHandsState()
    self.player_left_hand = nil
    self.player_right_hand = nil
    self.ai_left_hand = nil
    self.ai_right_hand = nil
    self.phase = "selection"
end


--------------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------------

function RPS:keypressed(key)
    if not self.waiting_for_input or self.game_over or self.victory then
        return
    end

    local p = self.params

    -- Double hands removal phase - number keys
    if p.hands_mode == "double" and self.phase == "removal" then
        local player_final = (key == '1' and self.player_left_hand) or (key == '2' and self.player_right_hand)
        if player_final then
            local ai_final = (self.rng:random() < 0.5 and self.ai_left_hand) or self.ai_right_hand
            self.ai_choice = ai_final
            self:playRound(player_final)
            self:clearDoubleHandsState()
            return
        end
    end

    -- Get choice from key mapping, validate against current game mode
    local choice = p.key_mappings[key]
    if not choice or not p.win_matrices[p.game_mode][choice] then
        return
    end

    if p.hands_mode == "double" and self.phase == "selection" then
        if not self.player_left_hand then
            self.player_left_hand = choice
        elseif not self.player_right_hand then
            self.player_right_hand = choice
            self.ai_left_hand = self:generateAIChoice()
            self.ai_right_hand = self:generateAIChoice()
            self.phase = "removal"
            if p.time_per_removal > 0 then
                self.removal_timer:start()
            end
        end
    else
        self:playRound(choice)
    end
end

--------------------------------------------------------------------------------
-- ROUND LOGIC
--------------------------------------------------------------------------------

function RPS:playRound(player_choice)
    local p = self.params
    self.player_choice = player_choice
    self.waiting_for_input = false
    self.throw_animation:start()
    self.rounds_played = self.rounds_played + 1

    if #self.opponents > 1 then
        self:resolveMultipleOpponents(player_choice)
    else
        self.ai_choice = self:generateAIChoice()
        self.round_result = self:determineWinner(player_choice, self.ai_choice)
        self:applySpecialRoundRules(player_choice)
        table.insert(self.ai_history, self.ai_choice)
    end

    -- Process round result
    if self.round_result == "win" then
        self:onRoundWin()
    elseif self.round_result == "lose" then
        self:onRoundLose()
    else
        self:onRoundTie()
    end

    table.insert(self.player_history, player_choice)
    self:updateThrowHistory(player_choice)
    self:syncMetrics({
        rounds_won = "player_wins", rounds_lost = "ai_wins", rounds_total = "rounds_played",
        max_win_streak = "max_win_streak", score = "score"
    })
    self.metrics.accuracy = (self.player_wins + self.ai_wins) > 0 and (self.player_wins / (self.player_wins + self.ai_wins)) or 0

    self.last_special_round = self.current_special_round
    self.current_special_round = nil
    self.show_result = true
    self.result_timer:start()
end

function RPS:applySpecialRoundRules(player_choice)
    if self.current_special_round == "reverse" then
        if self.round_result == "win" then self.round_result = "lose"
        elseif self.round_result == "lose" then self.round_result = "win" end
    elseif self.current_special_round == "mirror" then
        self.round_result = (player_choice == self.ai_choice) and "win" or "tie"
    end
end

function RPS:resolveMultipleOpponents(player_choice)
    local wins, losses = 0, 0
    for _, opp in ipairs(self.opponents) do
        if not opp.eliminated then
            opp.choice = self:generateAIChoice(opp.history, opp.pattern)
            local result = self:determineWinner(player_choice, opp.choice)
            if result == "win" then wins = wins + 1
            elseif result == "lose" then
                losses = losses + 1
                opp.wins = opp.wins + 1
                if self.params.elimination_mode and opp.wins >= self.params.rounds_to_win then
                    self.game_over = true
                end
            end
            table.insert(opp.history, opp.choice)
        end
    end
    self.round_result = (wins > losses) and "win" or (losses > wins) and "lose" or "tie"
end

function RPS:updateThrowHistory(player_choice)
    if not self.params.show_history_display then return end
    table.insert(self.throw_history, {player = player_choice, ai = self.ai_choice, result = self.round_result})
    while #self.throw_history > self.params.history_length do
        table.remove(self.throw_history, 1)
    end
end

function RPS:onRoundWin()
    local p = self.params
    self.player_wins = self.player_wins + 1
    self.current_win_streak = self.current_win_streak + 1
    if self.current_win_streak > self.max_win_streak then
        self.max_win_streak = self.current_win_streak
    end

    -- Score calculation
    local multiplier = (self.current_special_round == "double_or_nothing") and 2 or 1
    local round_points = p.score_per_round_win * multiplier
    local streak_points = (self.current_win_streak > 1) and (p.streak_bonus * self.current_win_streak) or 0
    self.score = self.score + round_points + streak_points

    self:showScorePopup(round_points + streak_points)
    self.visual_effects:flash({0, 1, 0, 0.3}, 0.2, "fade_out")

    if self.current_special_round == "sudden_death" then
        self.victory = true
    elseif self:checkComplete() and self.victory and self.ai_wins == 0 then
        self:onPerfectGame()
    end
end

function RPS:showScorePopup(points)
    if not self.params.score_popup_enabled then return end
    local w, h = self.viewport_width or love.graphics.getWidth(), self.viewport_height or love.graphics.getHeight()
    local color = (self.current_win_streak == 3 or self.current_win_streak == 5) and {1, 1, 0} or {1, 1, 1}
    self.popup_manager:add(w / 2, h / 2 - 50, "+" .. math.floor(points), color)
end

function RPS:onPerfectGame()
    local p = self.params
    self.score = self.score + p.perfect_game_bonus
    if p.score_popup_enabled then
        local w, h = self.viewport_width or love.graphics.getWidth(), self.viewport_height or love.graphics.getHeight()
        self.popup_manager:add(w / 2, h / 2 - 100, "PERFECT GAME! +" .. p.perfect_game_bonus, {0, 1, 0})
    end
    if p.celebration_on_perfect then
        local w, h = self.viewport_width or love.graphics.getWidth(), self.viewport_height or love.graphics.getHeight()
        self.visual_effects:emitConfetti(w / 2, h / 2, 30)
    end
end

function RPS:onRoundLose()
    local p = self.params
    self.ai_wins = self.ai_wins + 1
    self.current_win_streak = 0

    if self.current_special_round == "double_or_nothing" then
        self.score = math.max(0, self.score - p.score_per_round_win)
    end

    self.visual_effects:flash({1, 0, 0, 0.3}, 0.2, "fade_out")

    if self.current_special_round == "sudden_death" then
        self.game_over = true
    else
        self:handleLifeLoss("loss")
        self:checkComplete()
    end
end

function RPS:onRoundTie()
    self.ties = self.ties + 1
    self:handleLifeLoss("tie")
end

function RPS:handleLifeLoss(reason)
    local p = self.params
    if self.lives >= 999 then return end
    if p.lose_life_on ~= reason and p.lose_life_on ~= "both" then return end

    self.health_system:takeDamage(1, "round_" .. reason)
    self.lives = self.health_system.lives
    if not self.health_system:isAlive() then
        self.game_over = true
    end
end


--------------------------------------------------------------------------------
-- AI SYSTEM
--------------------------------------------------------------------------------

function RPS:generateAIChoice(history, pattern)
    local p = self.params
    history = history or self.ai_history
    pattern = pattern or p.ai_pattern
    local choices = self:getAvailableChoices()

    if p.ai_pattern_delay > 0 and self.rounds_played < p.ai_pattern_delay then
        return choices[self.rng:random(1, #choices)]
    end

    if pattern == "repeat_last" and #history > 0 then
        return history[#history]
    elseif pattern == "counter_player" and #self.player_history > 0 then
        local last_player = self.player_history[#self.player_history]
        local win_matrix = p.win_matrices[p.game_mode]
        if win_matrix and win_matrix[last_player] and win_matrix[last_player].loses_to then
            local counters = win_matrix[last_player].loses_to
            return counters[self.rng:random(1, #counters)]
        end
    elseif pattern == "pattern_cycle" then
        return choices[(#history % #choices) + 1]
    elseif pattern == "mimic_player" and #self.player_history > 0 then
        return self.player_history[#self.player_history]
    elseif pattern == "anti_player" and #self.player_history >= 2 then
        return self.player_history[#self.player_history - 1]
    end
    return choices[self.rng:random(1, #choices)]
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
