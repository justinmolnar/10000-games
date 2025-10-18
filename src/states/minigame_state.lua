local Object = require('class')
local MinigameState = Object:extend('MinigameState')

function MinigameState:init()
    self.current_game = nil
    self.game_data = nil
    self.completion_screen_visible = false
    self.previous_best = 0
    self.current_performance = 0
    self.auto_completed_games = {}
    self.auto_complete_power = 0
end

function MinigameState:enter(game_data)
    self.game_data = game_data
    
    -- Load the game class dynamically
    local class_name = game_data.game_class
    local file_name = class_name:gsub("(%u)", function(c) return "_" .. c:lower() end):sub(2)
    
    print("Loading game class: " .. file_name)
    local GameClass = require('src.games.' .. file_name)
    self.current_game = GameClass:new(game_data)
    
    -- Get previous best performance
    local perf = game.player_data:getGamePerformance(game_data.id)
    self.previous_best = perf and perf.best_score or 0
    
    -- Reset completion screen
    self.completion_screen_visible = false
    self.auto_completed_games = {}
    self.auto_complete_power = 0
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
    love.graphics.print("Result: " .. math.floor(self.current_performance), x + 20, y, 0, 1.2, 1.2)
    
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
    self.current_performance = self.current_game:calculatePerformance()
    
    -- Award tokens based on performance
    local tokens_earned = math.floor(self.current_performance)
    game.player_data:addTokens(tokens_earned)
    print("Awarded " .. tokens_earned .. " tokens for completing " .. self.game_data.display_name)
    
    -- Update player performance
    local is_new_best = game.player_data:updateGamePerformance(
        self.game_data.id,
        self.current_game:getMetrics(),
        self.current_performance
    )
    
    -- Check for auto-completion trigger
    if is_new_best then
        self:checkAutoCompletion()
    end
    
    -- Save game
    game.save_manager.save(game.player_data)
end

function MinigameState:checkAutoCompletion()
    -- Only trigger if this is a variant (not base game)
    if not self.game_data.variant_of then return end
    
    -- Get the variant number from the ID
    local variant_num = tonumber(self.game_data.id:match("_(%d+)$"))
    if not variant_num or variant_num <= 1 then return end
    
    self.auto_completed_games = {}
    self.auto_complete_power = 0
    
    -- Auto-complete all easier variants of the same base game
    local base_id = self.game_data.variant_of
    
    for i = 1, variant_num - 1 do
        local variant_id = base_id:gsub("_1$", "_" .. i)
        if variant_id == base_id and i > 1 then
            -- Handle base game pattern
            variant_id = base_id:gsub("_1$", "") .. "_" .. i
        end
        
        local variant = game.game_data:getGame(variant_id)
        if variant then
            -- Check if not already completed manually
            local existing_perf = game.player_data:getGamePerformance(variant_id)
            if not existing_perf then
                -- Calculate baseline performance (70% of auto-play baseline)
                local auto_metrics = variant.auto_play_performance
                local auto_power = variant.formula_function(auto_metrics)
                
                -- Store as completed with auto-completion flag
                game.player_data:updateGamePerformance(
                    variant_id,
                    auto_metrics,
                    auto_power
                )
                
                self.auto_complete_power = self.auto_complete_power + auto_power
                table.insert(self.auto_completed_games, {
                    id = variant_id,
                    name = variant.display_name,
                    power = auto_power
                })
            end
        end
    end
end

function MinigameState:keypressed(key)
    if self.completion_screen_visible then
        if key == 'return' then
            -- Replay the game
            self:enter(self.game_data)
        elseif key == 'escape' then
            -- Return to launcher
            game.state_machine:switch('launcher')
        end
    else
        if key == 'escape' then
            -- Return to launcher (with confirmation would be better)
            game.state_machine:switch('launcher')
        else
            -- Forward to game
            if self.current_game and self.current_game.keypressed then
                self.current_game:keypressed(key)
            end
        end
    end
end

function MinigameState:mousepressed(x, y, button)
    if not self.completion_screen_visible then
        if self.current_game and self.current_game.mousepressed then
            self.current_game:mousepressed(x, y, button)
        end
    end
end

return MinigameState