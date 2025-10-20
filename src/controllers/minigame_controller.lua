local Object = require('class')
local Strings = require('src.utils.strings')
local ProgressionManager = require('src.models.progression_manager')

local DEFAULT_COMPLETION_THRESHOLD = 0.75

local MinigameController = Object:extend('MinigameController')

function MinigameController:init(player_data, game_data_model, save_manager, cheat_system, di)
    self.player_data = player_data
    self.game_data_model = game_data_model
    self.save_manager = save_manager
    self.cheat_system = cheat_system
    self.di = di

    self.game_instance = nil
    self.game_data = nil

    self.active_cheats = {}
    self.previous_best = 0
    self.base_performance = 0
    self.current_performance = 0
    self.performance_mult = 1.0
    self.fail_gate_triggered = false
    self.auto_completed_games = {}
    self.auto_complete_power = 0
    self.overlay_visible = false
end

function MinigameController:begin(game_instance, game_data)
    self.game_instance = game_instance
    self.game_data = game_data
    self.active_cheats = self.cheat_system:getActiveCheats(game_data.id) or {}
    self.cheat_system:consumeCheats(game_data.id)

    local perf = self.player_data:getGamePerformance(game_data.id)
    self.previous_best = perf and perf.best_score or 0
    self.base_performance = 0
    self.current_performance = 0
    self.performance_mult = (self.active_cheats and self.active_cheats.performance_modifier) or 1.0
    self.fail_gate_triggered = false
    self.auto_completed_games = {}
    self.auto_complete_power = 0
    self.overlay_visible = false
end

function MinigameController:isOverlayVisible()
    return self.overlay_visible
end

function MinigameController:update(dt)
    if not self.game_instance or self.overlay_visible then return end

    local ok_base, err_base = pcall(self.game_instance.updateBase, self.game_instance, dt)
    if not ok_base then
        print("Error during game updateBase:", err_base)
        return
    end

    if not self.game_instance.completed then
        local ok_logic, err_logic = pcall(self.game_instance.updateGameLogic, self.game_instance, dt)
        if not ok_logic then
            print("Error during game updateGameLogic:", err_logic)
            return
        end
    end

    if self.game_instance.completed and not self.overlay_visible then
        self:processCompletion()
    end
end

function MinigameController:_safeCall(method_name)
    if not self.game_instance or not self.game_instance[method_name] then return true, nil end
    return pcall(self.game_instance[method_name], self.game_instance)
end

function MinigameController:processCompletion()
    self.overlay_visible = true

    local ok_perf, base_perf = self:_safeCall('calculatePerformance')
    self.base_performance = ok_perf and (base_perf or 0) or 0

    local ok_ratio, ratio = self:_safeCall('getCompletionRatio')
    ratio = ok_ratio and (ratio or 1.0) or 1.0
    local threshold = (self.game_data and self.game_data.token_threshold) or DEFAULT_COMPLETION_THRESHOLD
    self.fail_gate_triggered = (ratio < threshold)

    self.current_performance = self.base_performance * (self.performance_mult or 1.0)
    if self.fail_gate_triggered then self.current_performance = 0 end

    local tokens_earned = math.floor(self.current_performance)
    pcall(self.player_data.addTokens, self.player_data, tokens_earned)

    local ok_metrics, metrics = self:_safeCall('getMetrics')
    local metrics_to_save = ok_metrics and (metrics or {}) or {}

    local is_new_best = false
    local ok_update, update_result = pcall(self.player_data.updateGamePerformance, self.player_data,
        self.game_data.id, metrics_to_save, self.current_performance)
    if ok_update then is_new_best = update_result else print("Error updating player performance:", update_result) end

    if is_new_best and not self.fail_gate_triggered then
        local progression = ProgressionManager:new()
        local ok_ac, res = pcall(progression.checkAutoCompletion, progression,
            self.game_data.id, self.game_data, self.game_data_model, self.player_data)
        if ok_ac and type(res) == 'table' then
            self.auto_completed_games = res[1] or {}
            self.auto_complete_power = res[2] or 0
        else
            if not ok_ac then print("Error checking auto-completion:", res) end
            self.auto_completed_games = {}
            self.auto_complete_power = 0
        end
    else
        self.auto_completed_games = {}
        self.auto_complete_power = 0
    end

    local ok_save, err_save = pcall(self.save_manager.save, self.player_data)
    if not ok_save then print("Error saving game data:", err_save) end
end

function MinigameController:getMetrics()
    local ok, metrics = self:_safeCall('getMetrics')
    return ok and (metrics or {}) or {}
end

function MinigameController:getSnapshot()
    return {
        game_data = self.game_data,
        previous_best = self.previous_best,
        base_performance = self.base_performance,
        current_performance = self.current_performance,
        performance_mult = self.performance_mult or 1.0,
        fail_gate_triggered = self.fail_gate_triggered,
        auto_completed_games = self.auto_completed_games,
        auto_complete_power = self.auto_complete_power,
        metrics = self:getMetrics(),
    }
end

return MinigameController
