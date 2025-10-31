-- src/controllers/minigame_controller.lua
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
    self.event_bus = di and di.eventBus -- Store event bus from DI
    self.demo_recorder = di and di.demoRecorder -- Demo recording system

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

    -- Demo recording state
    self.is_recording = false
    self.recorded_demo = nil
    self.show_save_demo_prompt = false
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

    -- Reset demo recording state
    self.is_recording = false
    self.recorded_demo = nil
    self.show_save_demo_prompt = false

    -- Start demo recording if DemoRecorder is available
    if self.demo_recorder then
        local variant_config = game_instance.variant or {}
        self.demo_recorder:startRecording(game_data.id, variant_config)
        self.is_recording = true
    end

    -- Phase 3.3: Start music
    if game_instance.playMusic then
        game_instance:playMusic()
    end

    -- Publish game_started event
    if self.event_bus then
        -- Assuming window_id context might be needed later, passing nil for now
        -- MinigameState holds the window_id if needed: self.game_instance.window_id (requires passing context)
        pcall(self.event_bus.publish, self.event_bus, 'game_started', self.game_data.id, nil)
    end
end

function MinigameController:isOverlayVisible()
    return self.overlay_visible
end

function MinigameController:update(dt)
    if not self.game_instance or self.overlay_visible then return end

    -- Call fixedUpdate on demo recorder if recording
    if self.is_recording and self.demo_recorder then
        pcall(self.demo_recorder.fixedUpdate, self.demo_recorder)
    end

    local ok_base, err_base = pcall(self.game_instance.updateBase, self.game_instance, dt)
    if not ok_base then
        print("Error during game updateBase:", err_base)
        -- Publish game_failed event on error
        if self.event_bus then
            pcall(self.event_bus.publish, self.event_bus, 'game_failed', self.game_data.id, 'updateBase_error')
        end
        self:processCompletion() -- Show overlay even on error
        return
    end

    if not self.game_instance.completed then
        local ok_logic, err_logic = pcall(self.game_instance.updateGameLogic, self.game_instance, dt)
        if not ok_logic then
            print("Error during game updateGameLogic:", err_logic)
            -- Publish game_failed event on error
            if self.event_bus then
                pcall(self.event_bus.publish, self.event_bus, 'game_failed', self.game_data.id, 'updateLogic_error')
            end
            self:processCompletion() -- Show overlay even on error
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
        -- Publish high_score event only if it's a new best and not fail-gated
        if self.event_bus then
            pcall(self.event_bus.publish, self.event_bus, 'high_score', self.game_data.id, self.current_performance, metrics_to_save)
        end
    else
        self.auto_completed_games = {}
        self.auto_complete_power = 0
    end

    local ok_save, err_save = pcall(self.save_manager.save, self.player_data)
    if not ok_save then print("Error saving game data:", err_save) end

    -- Stop demo recording if active
    if self.is_recording and self.demo_recorder then
        print("[MinigameController] Stopping demo recording for " .. self.game_data.display_name)
        local auto_name = self.game_data.display_name .. " Demo"
        local success, demo_or_error = pcall(self.demo_recorder.stopRecording, self.demo_recorder, auto_name, "Auto-recorded gameplay")
        if success and demo_or_error then
            self.recorded_demo = demo_or_error
            self.show_save_demo_prompt = true
            print("[MinigameController] Demo recorded successfully, showing save prompt")
        else
            print("[MinigameController] Demo recording FAILED: " .. tostring(demo_or_error))
        end
        self.is_recording = false
    else
        print("[MinigameController] NOT recording demo (is_recording=" .. tostring(self.is_recording) .. ", demo_recorder=" .. tostring(self.demo_recorder ~= nil) .. ")")
    end

    -- Publish game_completed event regardless of new best score (unless it failed earlier)
    if self.event_bus then
        local completion_data = {
            score = self.current_performance,
            base_score = self.base_performance,
            metrics = metrics_to_save,
            cheats_used = self.active_cheats,
            is_new_best = is_new_best,
            fail_gate_triggered = self.fail_gate_triggered,
            auto_completed = self.auto_completed_games
        }
        pcall(self.event_bus.publish, self.event_bus, 'game_completed', self.game_data.id, completion_data)
    end
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
        show_save_demo_prompt = self.show_save_demo_prompt,
        recorded_demo = self.recorded_demo,
    }
end

function MinigameController:saveDemo()
    if not self.recorded_demo then
        return false
    end

    local demo_id = self.player_data:saveDemo(self.recorded_demo)
    if demo_id then
        self.recorded_demo = nil
        self.show_save_demo_prompt = false
        return true
    else
        return false
    end
end

function MinigameController:discardDemo()
    self.recorded_demo = nil
    self.show_save_demo_prompt = false
end

return MinigameController