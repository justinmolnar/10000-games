local Object = require('class')
local ProgressionManager = require('models.progression_manager')
local MinigameState = Object:extend('MinigameState')

function MinigameState:init(player_data, game_data_model, state_machine, save_manager, cheat_system)
    print("[MinigameState] init() called")
    self.player_data = player_data
    self.game_data_model = game_data_model
    self.state_machine = state_machine
    self.save_manager = save_manager
    self.cheat_system = cheat_system

    self.current_game = nil
    self.game_data = nil
    self.completion_screen_visible = false
    self.previous_best = 0
    self.current_performance = 0
    self.base_performance = 0
    self.auto_completed_games = {}
    self.auto_complete_power = 0
    self.active_cheats = {}

    self.viewport = nil
    self.window_id = nil
    self.window_manager = nil
    
    print("[MinigameState] init() completed")
end

function MinigameState:setViewport(x, y, width, height)
    print(string.format("[MinigameState] setViewport CALLED with x=%.1f, y=%.1f, w=%.1f, h=%.1f", x, y, width, height))
    self.viewport = { x = x, y = y, width = width, height = height }
    
    if self.current_game and self.current_game.setPlayArea then
        self.current_game:setPlayArea(width, height)
    end
end

function MinigameState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

function MinigameState:enter(game_data)
    print("[MinigameState] enter() called for game:", game_data and game_data.id or "UNKNOWN")
    if not game_data then
        print("[MinigameState] ERROR: No game_data provided to enter()")
        self.current_game = nil
        return { type = "close_window" }
    end

    self.game_data = game_data
    self.active_cheats = self.cheat_system:getActiveCheats(game_data.id) or {}
    
    local class_name = game_data.game_class
    local logic_file_name = class_name:gsub("(%u)", function(c) return "_" .. c:lower() end):match("^_?(.*)")
    local require_path = 'src.games.' .. logic_file_name
    print("[MinigameState] Attempting to require game class:", require_path)

    local require_ok, GameClass = pcall(require, require_path)
    if not require_ok or not GameClass then
        print("[MinigameState] ERROR: Failed to load game class '".. require_path .."': " .. tostring(GameClass))
        self.current_game = nil
        love.window.showMessageBox("Error", "Failed to load game logic for: " .. (game_data.display_name or class_name), "error")
        return { type = "close_window" }
    end

    local instance_ok, game_instance = pcall(GameClass.new, GameClass, game_data, self.active_cheats)
    if not instance_ok or not game_instance then
        print("[MinigameState] ERROR: Failed to instantiate game class '".. class_name .."': " .. tostring(game_instance))
        self.current_game = nil
        love.window.showMessageBox("Error", "Failed to initialize game: " .. (game_data.display_name or class_name), "error")
        return { type = "close_window" }
    end
    self.current_game = game_instance

    if self.viewport and self.current_game.setPlayArea then
        print("[MinigameState] Setting initial play area from existing viewport:", self.viewport.width, self.viewport.height)
        self.current_game:setPlayArea(self.viewport.width, self.viewport.height)
    end

    self.cheat_system:consumeCheats(game_data.id)

    local perf = self.player_data:getGamePerformance(game_data.id)
    self.previous_best = perf and perf.best_score or 0
    self.completion_screen_visible = false
    self.current_performance = 0
    self.base_performance = 0
    self.auto_completed_games = {}
    self.auto_complete_power = 0
    print("[MinigameState] enter() completed successfully for", game_data.id)
end

function MinigameState:update(dt)
    if not self.current_game then return end

    if not self.completion_screen_visible then
        -- Call updateBase which handles time and checks for completion
        local update_base_ok, base_err = pcall(self.current_game.updateBase, self.current_game, dt)
        if not update_base_ok then
            print("Error during game updateBase:", base_err)
            return
        end

        -- Only update game logic if not completed
        if not self.current_game.completed then
            local update_logic_ok, logic_err = pcall(self.current_game.updateGameLogic, self.current_game, dt)
            if not update_logic_ok then
                print("Error during game updateGameLogic:", logic_err)
                return
            end
        end
        
        -- Check if game just completed and trigger our completion handler
        if self.current_game.completed and not self.completion_screen_visible then
            local complete_ok, complete_err = pcall(self.onGameComplete, self)
            if not complete_ok then
                print("Error during onGameComplete:", complete_err)
            end
        end
    end
end

function MinigameState:draw()
    if not self.viewport then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("Viewport not set", 5, 5, 200)
        return
    end

    if self.current_game and self.current_game.draw then
        self.current_game:draw()
    else
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("Error: Game instance not loaded", 0, self.viewport.height/2 - 10, self.viewport.width, "center")
    end

    if self.completion_screen_visible then
        self:drawCompletionScreen()
    end
end

function MinigameState:drawCompletionScreen()
    local vpWidth = self.viewport.width
    local vpHeight = self.viewport.height

    love.graphics.push()
    love.graphics.origin()

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, vpWidth, vpHeight)

    love.graphics.setColor(1, 1, 1)
    local metrics = (self.current_game and pcall(self.current_game.getMetrics, self.current_game)) and self.current_game:getMetrics() or {}

    local x = vpWidth * 0.1
    local y = vpHeight * 0.1
    local line_height = math.max(16, vpHeight * 0.04)
    local title_scale = math.max(0.8, vpWidth / 700)
    local text_scale = math.max(0.7, vpWidth / 800)

    love.graphics.printf("GAME COMPLETE!", x, y, vpWidth * 0.8, "center", 0, title_scale, title_scale)
    y = y + line_height * 2.5

    -- Fix: Show actual tokens earned (minimum 1)
    local tokens_earned = math.max(1, math.floor(self.current_performance))
    local performance_mult = (self.active_cheats and self.active_cheats.performance_modifier) or 1.0

    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("Tokens Earned: +" .. tokens_earned, x, y, vpWidth * 0.8, "center", 0, text_scale * 1.2, text_scale * 1.2)
    y = y + line_height * 1.5

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Your Performance:", x, y, 0, text_scale, text_scale)
    y = y + line_height

    if self.game_data and self.game_data.metrics_tracked then
        for _, metric_name in ipairs(self.game_data.metrics_tracked) do
            local value = metrics[metric_name]
            if value ~= nil then
                if type(value) == "number" then value = string.format("%.1f", value) end
                love.graphics.print("  " .. metric_name .. ": " .. value, x + 20, y, 0, text_scale * 0.9, text_scale * 0.9)
                y = y + line_height
            end
        end
    else
        love.graphics.print("  (Metrics unavailable)", x + 20, y, 0, text_scale * 0.9, text_scale * 0.9)
        y = y + line_height
    end

    y = y + line_height * 0.5
    love.graphics.print("Formula Calculation:", x, y, 0, text_scale, text_scale)
    y = y + line_height
    if self.game_data and self.game_data.formula_string then
        love.graphics.printf(self.game_data.formula_string, x + 20, y, vpWidth * 0.7, "left", 0, text_scale * 0.8, text_scale * 0.8)
        y = y + line_height
    end

    if performance_mult ~= 1.0 then
        love.graphics.print("Base Result: " .. math.floor(self.base_performance), x + 20, y, 0, text_scale, text_scale)
        y = y + line_height
        love.graphics.setColor(0, 1, 1)
        love.graphics.print("Cheat Bonus: x" .. string.format("%.1f", performance_mult), x + 20, y, 0, text_scale, text_scale)
        y = y + line_height
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Final Result: " .. math.floor(self.current_performance), x + 20, y, 0, text_scale * 1.2, text_scale * 1.2)
    y = y + line_height * 1.5

    if self.current_performance > self.previous_best then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("NEW RECORD!", x, y, 0, text_scale * 1.3, text_scale * 1.3)
        y = y + line_height
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Previous: " .. math.floor(self.previous_best), x, y, 0, text_scale, text_scale)
        love.graphics.print("Improvement: +" .. math.floor(self.current_performance - self.previous_best), x, y + line_height, 0, text_scale, text_scale)
        y = y + line_height

        if #self.auto_completed_games > 0 then
            y = y + line_height
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("AUTO-COMPLETION TRIGGERED!", x, y, 0, text_scale * 1.1, text_scale * 1.1)
            y = y + line_height
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Completed " .. #self.auto_completed_games .. " easier variants!", x, y, 0, text_scale, text_scale)
            y = y + line_height
            love.graphics.print("Total power gained: +" .. math.floor(self.auto_complete_power), x, y, 0, text_scale, text_scale)
        end
    else
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Best: " .. math.floor(self.previous_best), x, y, 0, text_scale, text_scale)
        y = y + line_height
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Try again to improve your score!", x, y, 0, text_scale, text_scale)
    end

    love.graphics.setColor(1, 1, 1)
    local instruction_y = vpHeight - line_height * 2.5
    love.graphics.printf("Press ENTER to play again", 0, instruction_y, vpWidth, "center", 0, text_scale, text_scale)
    love.graphics.printf("Press ESC to close window", 0, instruction_y + line_height, vpWidth, "center", 0, text_scale, text_scale)

    love.graphics.pop()
end

function MinigameState:onGameComplete()
    if self.completion_screen_visible or not self.current_game then return end

    print("[MinigameState] onGameComplete triggered for:", self.game_data and self.game_data.id)
    self.completion_screen_visible = true

    local base_perf_ok, base_perf_result = pcall(self.current_game.calculatePerformance, self.current_game)
    if base_perf_ok then
        self.base_performance = base_perf_result
    else
        print("Error calculating base performance:", base_perf_result)
        self.base_performance = 0
    end

    local performance_mult = (self.active_cheats and self.active_cheats.performance_modifier) or 1.0
    self.current_performance = self.base_performance * performance_mult
    local tokens_earned = math.floor(self.current_performance)

    pcall(self.player_data.addTokens, self.player_data, tokens_earned)
    local metrics_ok, metrics_data = pcall(self.current_game.getMetrics, self.current_game)
    local metrics_to_save = metrics_ok and metrics_data or {}

    local is_new_best = false
    local update_ok, update_result = pcall(self.player_data.updateGamePerformance, self.player_data,
                                            self.game_data.id,
                                            metrics_to_save,
                                            self.current_performance)
    if update_ok then
        is_new_best = update_result
    else
        print("Error updating player performance:", update_result)
    end

    if is_new_best then
        local progression = ProgressionManager:new()
        local check_ok, ac_result = pcall(progression.checkAutoCompletion, progression,
                                            self.game_data.id,
                                            self.game_data,
                                            self.game_data_model,
                                            self.player_data)
        if check_ok and type(ac_result) == 'table' then
            self.auto_completed_games = ac_result[1] or {}
            self.auto_complete_power = ac_result[2] or 0
        elseif not check_ok then
             print("Error checking auto-completion:", ac_result)
             self.auto_completed_games = {}
             self.auto_complete_power = 0
        end
    else
        self.auto_completed_games = {}
        self.auto_complete_power = 0
    end

    -- Fix: SaveManager.save is a static function, call it correctly
    local save_ok, save_err = pcall(self.save_manager.save, self.player_data)
    if not save_ok then
        print("Error saving game data:", save_err)
    end
    
    print("[MinigameState] Game complete processing finished. New best:", is_new_best, "Auto-completed:", #self.auto_completed_games)
end

function MinigameState:keypressed(key)
    if not self.window_manager or self.window_id ~= self.window_manager:getFocusedWindowId() then
        return false
    end

    if self.completion_screen_visible then
        if key == 'return' then
            if self.game_data then
                local restart_event = self:enter(self.game_data)
                if type(restart_event) == 'table' and restart_event.type == "close_window" then
                     return restart_event
                end
            end
            return { type = "content_interaction" }
        elseif key == 'escape' then
            return { type = "close_window" }
        end
    else
        if key == 'escape' then
            return { type = "close_window" }
        else
            if self.current_game and self.current_game.keypressed then
                local success, result = pcall(self.current_game.keypressed, self.current_game, key)
                if success then
                    return result and { type = "content_interaction" } or false
                else
                    print("Error in game keypressed handler:", tostring(result))
                    return false
                end
            end
        end
    end

    return false
end

function MinigameState:mousepressed(x, y, button)
    if not self.window_manager or self.window_id ~= self.window_manager:getFocusedWindowId() then
        return false
    end

    if self.completion_screen_visible then
        return false
    end

    if self.current_game and self.current_game.mousepressed then
        local success, result = pcall(self.current_game.mousepressed, self.current_game, x, y, button)
        if not success then
             print("Error in game mousepressed handler:", tostring(result))
             return { type = "content_interaction" }
        end
        return { type = "content_interaction" }
    end

    return { type = "content_interaction" }
end

function MinigameState:leave()
    print("[MinigameState] leave() called for window ID:", self.window_id)
    self.current_game = nil
    print("MinigameState left, resources cleaned up.")
end

return MinigameState