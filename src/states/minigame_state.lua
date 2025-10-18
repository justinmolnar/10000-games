local Object = require('class')
local MinigameState = Object:extend('MinigameState')

function MinigameState:init()
    self.current_game = nil
    self.completion_screen_visible = false
    self.previous_best = 0
    self.current_performance = 0
end

function MinigameState:enter(game_data)
    -- Load the game class dynamically based on game_data.game_class
    -- Convert PascalCase class name to snake_case file name
    local file_name = game_data.game_class:gsub("(%u)", function(c) return "_" .. c:lower() end):sub(2)
    local GameClass = require('games.' .. file_name)
    self.current_game = GameClass:new(game_data)
    
    -- Get previous best performance
    if game.player_data then
        local perf = game.player_data:getGamePerformance(game_data.id)
        self.previous_best = perf and perf.best_score or 0
    end
end

function MinigameState:update(dt)
    if self.current_game and not self.completion_screen_visible then
        self.current_game:update(dt)
        
        -- Check for game completion
        if self.current_game.completed then
            self:onGameComplete()
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
    -- Set up background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(1, 1, 1)
    local metrics = self.current_game:getMetrics()
    local game_data = self.current_game.data
    
    -- Position for drawing text
    local x = love.graphics.getWidth() * 0.3
    local y = love.graphics.getHeight() * 0.2
    local line_height = 30
    
    -- Draw metrics
    love.graphics.print("GAME COMPLETE!", x, y)
    y = y + line_height * 2
    
    love.graphics.print("Your Performance:", x, y)
    y = y + line_height
    
    -- Show each tracked metric
    for _, metric_name in ipairs(game_data.metrics_tracked) do
        love.graphics.print(metric_name .. ": " .. metrics[metric_name], x + 20, y)
        y = y + line_height
    end
    
    -- Show formula calculation
    y = y + line_height
    love.graphics.print("Formula Result:", x, y)
    y = y + line_height
    love.graphics.print(game_data.formula_string .. " = " .. self.current_performance, x + 20, y)
    
    -- Compare with previous best
    y = y + line_height * 2
    if self.current_performance > self.previous_best then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("NEW RECORD! Previous: " .. self.previous_best, x, y)
        
        -- Show auto-completion if triggered
        if self.auto_completed_games and #self.auto_completed_games > 0 then
            y = y + line_height * 2
            love.graphics.print("Auto-completed " .. #self.auto_completed_games .. " easier variants!", x, y)
            y = y + line_height
            love.graphics.print("Total power gained: +" .. self.auto_complete_power, x + 20, y)
        end
    else
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Best: " .. self.previous_best, x, y)
    end
    
    -- Instructions to continue
    love.graphics.setColor(1, 1, 1)
    y = love.graphics.getHeight() * 0.8
    love.graphics.print("Press ENTER to continue", x, y)
    love.graphics.print("Press ESC to return to launcher", x, y + line_height)
end

function MinigameState:onGameComplete()
    self.completion_screen_visible = true
    self.current_performance = self.current_game:calculatePerformance()
    
    if game.player_data then
        -- Update player performance
        local is_new_best = game.player_data:updateGamePerformance(
            self.current_game.data.id,
            self.current_game:getMetrics(),
            self.current_performance
        )
        
        -- Check for auto-completion trigger
        if is_new_best and self.current_game.data.variant_multiplier > 1 then
            self.auto_completed_games = {}
            self.auto_complete_power = 0
            
            -- Auto-complete all easier variants
            local base_id = self.current_game.data.variant_of or self.current_game.data.id:gsub("_%d+", "_1")
            for i = 1, tonumber(self.current_game.data.id:match("%d+")) - 1 do
                local variant_id = base_id:gsub("_1", "_" .. i)
                local variant = game.game_data:getGame(variant_id)
                if variant then
                    -- Calculate baseline performance (70% of typical best)
                    local auto_power = variant.formula_function(variant.auto_play_performance)
                    self.auto_complete_power = self.auto_complete_power + auto_power
                    table.insert(self.auto_completed_games, {
                        id = variant_id,
                        power = auto_power
                    })
                end
            end
        end
        
        game.save_manager.save(game.player_data)
    end
end

function MinigameState:keypressed(key)
    if self.completion_screen_visible then
        if key == 'return' then
            -- Reset state for another play
            local game_data = self.current_game.data
            self:enter(game_data)
            self.completion_screen_visible = false
        elseif key == 'escape' then
            -- Return to launcher
            game.state_machine:switch('launcher')
        end
    else
        if key == 'escape' then
            -- Confirm exit
            if love.window.showMessageBox("Exit Game", "Are you sure you want to exit? Progress will be lost.", 
                {"Yes", "No"}, "warning") == 1 then
                game.state_machine:switch('launcher')
            end
        else
            -- Forward to game
            self.current_game:keypressed(key)
        end
    end
end

function MinigameState:mousepressed(x, y, button)
    if not self.completion_screen_visible then
        self.current_game:mousepressed(x, y, button)
    end
end

return MinigameState