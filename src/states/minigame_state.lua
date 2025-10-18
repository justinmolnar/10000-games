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
    self.current_performance = 0
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
    local GameClass = require('src.games.' .. logic_file_name)
    if not GameClass then 
        print("ERROR: Could not load game logic class: " .. logic_file_name)
        self.state_machine:switch('launcher') -- Go back if load fails
        return 
    end
    -- Instantiate the game logic class, passing active cheats
    self.current_game = GameClass:new(game_data, self.active_cheats)
    
    -- Consume the cheats now that they've been applied
    self.cheat_system:consumeCheats(game_data.id)
    
    -- Load the corresponding view class dynamically (assuming view file exists)
    -- View file name is assumed to be the same as logic, but in games/views/
    local view_file_name = logic_file_name:gsub(".lua$", "") .. "_view" -- e.g., snake_game_view
    local view_path = 'src.games.views.' .. view_file_name
    
    -- Use pcall for safety in case a view file doesn't exist
    local view_load_ok, GameView = pcall(require, view_path)
    if view_load_ok and GameView and type(GameView.new) == 'function' then
         -- Instantiate the view inside the game object (as done in the game init methods)
         -- self.current_game.view = GameView:new(self.current_game) 
         -- Or handle view creation directly in the game's init, which we did.
         print("Loaded game view: " .. view_file_name)
    else
        print("Warning: Could not load or instantiate view for " .. class_name .. " at " .. view_path .. ". Drawing might fail. Error: " .. tostring(GameView))
        -- self.current_game.view = nil -- Ensure view is nil if load failed
    end

    -- Get previous best performance
    local perf = self.player_data:getGamePerformance(game_data.id)
    self.previous_best = perf and perf.best_score or 0
    
    -- Reset completion screen state
    self.completion_screen_visible = false
    self.auto_completed_games = {}
    self.auto_complete_power = 0
end

function MinigameState:update(dt)
    -- Call view update (placeholder for future refactor)
    -- if self.view and self.view.update then self.view:update(dt) end

    if self.current_game and not self.completion_screen_visible then
        -- Run base game update logic (timer, completion check which sets self.current_game.completed)
        self.current_game:updateBase(dt) 
        -- Run specific game logic (movement, spawning, etc.)
        -- Only run game logic if base update didn't already complete it
        if not self.current_game.completed then
            self.current_game:updateGameLogic(dt) 
        end

        -- Check if updateBase or updateGameLogic set the completed flag
        if self.current_game.completed then
            self:onGameComplete() -- Trigger the state's completion logic (show screen, save)
        end
    end
end

function MinigameState:draw()
    -- Draw the active game
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
    local metrics = self.current_game:getMetrics()
    
    -- Position for drawing text
    local x = love.graphics.getWidth() * 0.3
    local y = love.graphics.getHeight() * 0.2
    local line_height = 30
    
    -- Title
    love.graphics.print("GAME COMPLETE!", x, y, 0, 1.5, 1.5)
    y = y + line_height * 2
    
    -- Performance calculation *before* applying cheat multiplier
    local base_performance = self.current_game:calculatePerformance()
    -- Get the performance multiplier (e.g., 1.2) or default to 1.0
    local performance_mult = self.active_cheats.performance_modifier or 1.0
    self.current_performance = base_performance * performance_mult

    -- Tokens earned
    local tokens_earned = math.floor(self.current_performance)
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("Tokens Earned: +" .. tokens_earned, x, y, 0, 1.2, 1.2)
    y = y + line_height * 1.5
    
    -- Metrics
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Your Performance:", x, y)
    y = y + line_height
    
    for _, metric_name in ipairs(self.game_data.metrics_tracked) do
        local value = metrics[metric_name]
        if type(value) == "number" then
            value = string.format("%.1f", value)
        end
        love.graphics.print("  " .. metric_name .. ": " .. value, x + 20, y)
        y = y + line_height
    end
    
    -- Formula calculation
    y = y + line_height
    love.graphics.print("Formula Calculation:", x, y)
    y = y + line_height
    love.graphics.print(self.game_data.formula_string, x + 20, y, 0, 0.9, 0.9)
    y = y + line_height
    if performance_mult ~= 1.0 then
        love.graphics.print("Base Result: " .. math.floor(base_performance), x + 20, y, 0, 1.0, 1.0)
        y = y + line_height
        love.graphics.setColor(0, 1, 1)
        love.graphics.print("Cheat Bonus: x" .. string.format("%.1f", performance_mult), x + 20, y, 0, 1.0, 1.0)
        y = y + line_height
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Final Result: " .. math.floor(self.current_performance), x + 20, y, 0, 1.2, 1.2)
    
    -- Compare with previous best
    y = y + line_height * 2
    if self.current_performance > self.previous_best then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("NEW RECORD!", x, y, 0, 1.3, 1.3)
        y = y + line_height
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Previous best: " .. math.floor(self.previous_best), x, y)
        love.graphics.print("Improvement: +" .. math.floor(self.current_performance - self.previous_best), x, y + line_height)
        
        -- Show auto-completion if triggered
        if #self.auto_completed_games > 0 then
            y = y + line_height * 3
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("AUTO-COMPLETION TRIGGERED!", x, y, 0, 1.2, 1.2)
            y = y + line_height
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Completed " .. #self.auto_completed_games .. " easier variants automatically!", x, y)
            y = y + line_height
            love.graphics.print("Total power gained: +" .. math.floor(self.auto_complete_power), x, y)
        end
    else
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Best: " .. math.floor(self.previous_best), x, y)
        y = y + line_height
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Try again to beat your record!", x, y)
    end
    
    -- Instructions
    love.graphics.setColor(1, 1, 1)
    y = love.graphics.getHeight() * 0.8
    love.graphics.print("Press ENTER to play again", x, y)
    love.graphics.print("Press ESC to return to launcher", x, y + line_height)
end

function MinigameState:onGameComplete()
    self.completion_screen_visible = true
    
    -- Performance is now calculated in drawCompletionScreen to show pre-cheat results
    -- self.current_performance = self.current_game:calculatePerformance() * (self.active_cheats.performance_modifier or 1)
    
    -- Award tokens based on final performance
    local tokens_earned = math.floor(self.current_performance)
    self.player_data:addTokens(tokens_earned)
    print("Awarded " .. tokens_earned .. " tokens for completing " .. self.game_data.display_name)
    
    -- Update player performance
    local is_new_best = self.player_data:updateGamePerformance(
        self.game_data.id,
        self.current_game:getMetrics(),
        self.current_performance
    )
    
    -- Check for auto-completion trigger using progression manager
    if is_new_best then
        local progression = ProgressionManager:new()
        
        -- Pass the specific game data (self.game_data)
        -- AND the main game data model (self.game_data_model)
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
            -- Replay the game
            self:enter(self.game_data)
            return true -- Handled
        elseif key == 'escape' then
            -- Return to desktop
            self.state_machine:switch('desktop')
            return true -- Handled
        end
    else
        if key == 'escape' then
            -- Return to desktop
            self.state_machine:switch('desktop')
            return true -- Handled
        else
            -- Forward to game if the method exists
            if self.current_game and self.current_game.keypressed then
                self.current_game:keypressed(key) 
                -- We always return true here now, regardless of what the game did.
                -- This signifies that the MinigameState itself handled the input
                -- by deciding to forward it, thus blocking global keys.
                return true 
            end
        end
    end
    
    -- If the key wasn't escape/return and wasn't forwarded (e.g., game has no keypressed),
    -- still consider it handled by this state to block globals.
    return true 
end

function MinigameState:mousepressed(x, y, button)
    if not self.completion_screen_visible then
        if self.current_game and self.current_game.mousepressed then
            self.current_game:mousepressed(x, y, button)
        end
    end
end

return MinigameState