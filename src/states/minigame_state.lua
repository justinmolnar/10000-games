-- src/states/minigame_state.lua
local Object = require('class')
local ProgressionManager = require('models.progression_manager')
local MinigameState = Object:extend('MinigameState')

function MinigameState:init(player_data, game_data, state_machine, save_manager, cheat_system)
    self.player_data = player_data
    self.game_data_model = game_data -- Store the main game data model
    self.state_machine = state_machine
    self.save_manager = save_manager
    self.cheat_system = cheat_system -- Injected dependency

    self.current_game = nil
    self.game_data = nil -- This will hold the specific game's data
    self.completion_screen_visible = false
    self.previous_best = 0
    self.current_performance = 0 -- Will hold the final calculated performance
    self.base_performance = 0 -- Will hold performance before cheat multiplier
    self.auto_completed_games = {}
    self.auto_complete_power = 0
    self.active_cheats = {} -- Store cheats for this run
end

function MinigameState:enter(game_data)
    self.game_data = game_data -- This is the specific game's data

    -- Get active cheats *before* instantiating the game
    self.active_cheats = self.cheat_system:getActiveCheats(game_data.id) or {}

    -- Load the game logic class dynamically
    local class_name = game_data.game_class
    local logic_file_name = class_name:gsub("(%u)", function(c) return "_" .. c:lower() end):sub(2)

    print("Loading game logic class: " .. logic_file_name)
    -- Use pcall for safer require
    local require_ok, GameClass = pcall(require, 'src.games.' .. logic_file_name)
    if not require_ok or not GameClass then
        print("ERROR: Could not load game logic class: " .. logic_file_name .. " - " .. tostring(GameClass))
        self.state_machine:switch('launcher') -- Go back if load fails
        return
    end
    -- Instantiate the game logic class, passing active cheats
    self.current_game = GameClass:new(game_data, self.active_cheats)

    -- Consume the cheats now that they've been applied
    self.cheat_system:consumeCheats(game_data.id)

    -- Corrected View Loading Logic:
    -- Derive base name (e.g., "dodge_game" -> "dodge")
    local base_name = logic_file_name:match("(.+)_game$") or logic_file_name
    -- Handle space_shooter specifically if needed, otherwise general pattern
    if logic_file_name == "space_shooter" then base_name = "space_shooter" end
    local view_file_name = base_name .. "_view" -- e.g., "dodge_view", "snake_view", "space_shooter_view"
    local view_path = 'src.games.views.' .. view_file_name

    -- Use pcall for safety in case a view file doesn't exist
    local view_load_ok, GameView = pcall(require, view_path)
    if view_load_ok and GameView and type(GameView.new) == 'function' then
         -- The game's init method should handle view creation internally
         print("Verified game view should load: " .. view_path)
    else
        print("Warning: Could not load or instantiate view for " .. class_name .. " at " .. view_path .. ". Drawing might fail. Error: " .. tostring(GameView))
        -- Ensure the game object knows its view load failed if applicable
        if self.current_game then self.current_game.view = nil end
    end

    -- Get previous best performance
    local perf = self.player_data:getGamePerformance(game_data.id)
    self.previous_best = perf and perf.best_score or 0

    -- Reset completion screen state
    self.completion_screen_visible = false
    self.current_performance = 0 -- Reset performance calculation holders
    self.base_performance = 0
    self.auto_completed_games = {}
    self.auto_complete_power = 0
end

function MinigameState:update(dt)
    if self.current_game and not self.completion_screen_visible then
        self.current_game:updateBase(dt) -- Handles timer, base completion check
        -- Only run game logic if base update didn't complete it
        if not self.current_game.completed then
            self.current_game:updateGameLogic(dt) -- Game-specific logic
        end
        -- Check again if game logic completed it
        if self.current_game.completed then
            self:onGameComplete() -- Trigger state's completion logic
        end
    end
end

function MinigameState:draw()
    -- Draw the active game (game handles nil view internally if needed)
    if self.current_game then
        self.current_game:draw()
    end

    -- Draw completion screen if visible
    if self.completion_screen_visible then
        self:drawCompletionScreen()
    end
end

function MinigameState:drawCompletionScreen()
    -- Semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(1, 1, 1)
    -- Safety check for current_game before getting metrics
    local metrics = self.current_game and self.current_game:getMetrics() or {}

    -- Position for drawing text
    local x = love.graphics.getWidth() * 0.3
    local y = love.graphics.getHeight() * 0.2
    local line_height = 30

    -- Title
    love.graphics.print("GAME COMPLETE!", x, y, 0, 1.5, 1.5); y = y + line_height * 2

    -- Use the calculated values from onGameComplete
    local tokens_earned = math.floor(self.current_performance)
    -- Check active_cheats exists before indexing
    local performance_mult = (self.active_cheats and self.active_cheats.performance_modifier) or 1.0

    -- Tokens earned
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("Tokens Earned: +" .. tokens_earned, x, y, 0, 1.2, 1.2); y = y + line_height * 1.5

    -- Metrics
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Your Performance:", x, y); y = y + line_height

    -- Safety check for game_data before accessing metrics_tracked
    if self.game_data and self.game_data.metrics_tracked then
        for _, metric_name in ipairs(self.game_data.metrics_tracked) do
            local value = metrics[metric_name]
            if value ~= nil then -- Only print if metric exists
                if type(value) == "number" then value = string.format("%.1f", value) end
                love.graphics.print("  " .. metric_name .. ": " .. value, x + 20, y); y = y + line_height
            end
        end
    end

    -- Formula calculation
    y = y + line_height
    love.graphics.print("Formula Calculation:", x, y); y = y + line_height
    -- Safety check for game_data
    if self.game_data and self.game_data.formula_string then
        love.graphics.print(self.game_data.formula_string, x + 20, y, 0, 0.9, 0.9); y = y + line_height
    end

    if performance_mult ~= 1.0 then
        love.graphics.print("Base Result: " .. math.floor(self.base_performance), x + 20, y, 0, 1.0, 1.0); y = y + line_height
        love.graphics.setColor(0, 1, 1)
        love.graphics.print("Cheat Bonus: x" .. string.format("%.1f", performance_mult), x + 20, y, 0, 1.0, 1.0); y = y + line_height
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Final Result: " .. math.floor(self.current_performance), x + 20, y, 0, 1.2, 1.2)

    -- Compare with previous best
    y = y + line_height * 2
    if self.current_performance > self.previous_best then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("NEW RECORD!", x, y, 0, 1.3, 1.3); y = y + line_height
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Previous best: " .. math.floor(self.previous_best), x, y)
        love.graphics.print("Improvement: +" .. math.floor(self.current_performance - self.previous_best), x, y + line_height)

        -- Show auto-completion if triggered
        if #self.auto_completed_games > 0 then
            y = y + line_height * 3
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("AUTO-COMPLETION TRIGGERED!", x, y, 0, 1.2, 1.2); y = y + line_height
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Completed " .. #self.auto_completed_games .. " easier variants automatically!", x, y); y = y + line_height
            love.graphics.print("Total power gained: +" .. math.floor(self.auto_complete_power), x, y)
        end
    else
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Best: " .. math.floor(self.previous_best), x, y); y = y + line_height
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Try again to beat your record!", x, y)
    end

    -- Instructions
    love.graphics.setColor(1, 1, 1)
    y = love.graphics.getHeight() * 0.8
    love.graphics.print("Press ENTER to play again", x, y)
    love.graphics.print("Press ESC to return to launcher", x, y + line_height) -- Changed target to launcher for consistency
end

function MinigameState:onGameComplete()
    -- Safety check: ensure game exists before proceeding
    if not self.current_game then return end

    self.completion_screen_visible = true

    -- Corrected Performance Calculation: Calculate here, store for draw and use
    self.base_performance = self.current_game:calculatePerformance()
    local performance_mult = (self.active_cheats and self.active_cheats.performance_modifier) or 1.0
    self.current_performance = self.base_performance * performance_mult

    -- Award tokens based on the final calculated performance
    local tokens_earned = math.floor(self.current_performance)
    self.player_data:addTokens(tokens_earned) -- This calls statistics:addTokensEarned
    -- Use the correct value in the print statement
    print("Awarded " .. tokens_earned .. " tokens for completing " .. (self.game_data and self.game_data.display_name or "Unknown Game"))

    -- Update player performance using the final calculated performance
    local is_new_best = self.player_data:updateGamePerformance(
        self.game_data.id,
        self.current_game:getMetrics(),
        self.current_performance -- Pass final performance
    )

    -- Check for auto-completion trigger using progression manager
    if is_new_best then
        local progression = ProgressionManager:new()
        self.auto_completed_games, self.auto_complete_power =
            progression:checkAutoCompletion(
                self.game_data.id,
                self.game_data,
                self.game_data_model,
                self.player_data
            )
    end

    -- Save game
    self.save_manager.save(self.player_data)
end

function MinigameState:keypressed(key)
    if self.completion_screen_visible then
        if key == 'return' then
            -- Replay the game - safety check game_data
            if self.game_data then self:enter(self.game_data) end
            return true
        elseif key == 'escape' then
            -- Return to desktop (or launcher?) - let's stick to desktop for now
            self.state_machine:switch('desktop')
            return true
        end
    else
        if key == 'escape' then
            self.state_machine:switch('desktop')
            return true
        else
            -- Forward to game if the method exists
            if self.current_game and self.current_game.keypressed then
                -- Let the game decide if it handled it
                return self.current_game:keypressed(key)
            end
        end
    end
    -- If no other handling occurred, signify it wasn't handled by this state layer
    return false
end

function MinigameState:mousepressed(x, y, button)
    if not self.completion_screen_visible then
        if self.current_game and self.current_game.mousepressed then
            self.current_game:mousepressed(x, y, button)
            -- Assume mouse input is consumed by the game if it has the method
            return true
        end
    end
    -- Mouse clicks on completion screen or if game doesn't handle mouse
    -- aren't handled here (no interactive elements currently)
    return false
end

return MinigameState