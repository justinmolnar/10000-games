-- launcher_view.lua: View class for the game launcher

local Object = require('class')
local UIComponents = require('src.views.ui_components') -- Added require
local LauncherView = Object:extend('LauncherView')

function LauncherView:init(controller, player_data, game_data)
    self.controller = controller -- This is the launcher_state
    self.player_data = player_data
    self.game_data = game_data
    
    self.selected_category = "all"
    self.selected_index = 1
    self.scroll_offset = 1
    self.hovered_game_id = nil
    self.selected_game = nil
    self.detail_panel_open = false
    
    -- UI layout constants
    self.button_height = 60
    self.button_padding = 5
    self.detail_panel_width = 350
    self.category_button_height = 30
    
    -- Double-click tracking
    self.last_click_time = 0
    self.last_click_game = nil
end

function LauncherView:update(dt)
    -- Update hovered game based on mouse position
    local mx, my = love.mouse.getPosition()
    self.hovered_game_id = self:getGameAtPosition(mx, my)
end

function LauncherView:draw(filtered_games, tokens)
    -- Use UIComponents.drawWindow
    UIComponents.drawWindow(0, 0, love.graphics.getWidth(), love.graphics.getHeight(), "Game Collection - MVP")
    
    -- Draw category buttons
    self:drawCategoryButtons(10, 50, self.selected_category)
    
    -- Use UIComponents.drawTokenCounter
    UIComponents.drawTokenCounter(love.graphics.getWidth() - 200, 10, tokens)
    
    -- Draw game list
    local list_width = self.detail_panel_open and (love.graphics.getWidth() - self.detail_panel_width - 20) or (love.graphics.getWidth() - 20)
    self:drawGameList(10, 90, list_width, love.graphics.getHeight() - 100, 
        filtered_games, self.selected_index, self.hovered_game_id)
    
    -- Draw detail panel if open
    if self.detail_panel_open and self.selected_game then
        local panel_x = love.graphics.getWidth() - self.detail_panel_width - 5
        self:drawGameDetailPanel(panel_x, 90, self.detail_panel_width, 
            love.graphics.getHeight() - 100, self.selected_game)
    end
end

function LauncherView:mousepressed(x, y, button, filtered_games)
    if button ~= 1 then return end
    
    -- 1. Check category buttons
    local categories = {"all", "action", "puzzle", "arcade", "locked", "unlocked", "completed", "easy", "medium", "hard"}
    local button_width = 75
    local button_x = 10
    
    for i, category in ipairs(categories) do
        local bx = button_x + (i - 1) * (button_width + 5)
        local by = 50
        
        if x >= bx and x <= bx + button_width and y >= by and y <= by + self.category_button_height then
            self.selected_category = category
            return {name = "filter_changed", category = category}
        end
    end
    
    -- 2. Check game list
    local clicked_game_id = self:getGameAtPosition(x, y, filtered_games)
    if clicked_game_id then
        for i, g in ipairs(filtered_games) do
            if g.id == clicked_game_id then
                local is_double_click = (self.last_click_game == clicked_game_id and 
                                        love.timer.getTime() - self.last_click_time < 0.5)
                
                if is_double_click then
                    -- Double-click detected - launch immediately
                    return {name = "launch_game", id = clicked_game_id}
                end
                
                -- Single click - just select
                self.selected_index = i
                self.selected_game = g
                
                -- Update double-click tracking
                self.last_click_game = clicked_game_id
                self.last_click_time = love.timer.getTime()
                return {name = "game_selected", game = g}
            end
        end
    end
    
    -- 3. Check detail panel buttons if open
    if self.detail_panel_open and self.selected_game then
        local panel_x = love.graphics.getWidth() - self.detail_panel_width - 5
        local button_y = love.graphics.getHeight() - 50
        
        -- Launch button
        if x >= panel_x + 10 and x <= panel_x + self.detail_panel_width - 10 and
           y >= button_y and y <= button_y + 35 then
            return {name = "launch_game", id = self.selected_game.id}
        end
    end
    
    return nil -- No UI element clicked
end

function LauncherView:wheelmoved(x, y, filtered_games)
    local visible_games = math.floor((love.graphics.getHeight() - 100) / (self.button_height + self.button_padding))
    local max_scroll = math.max(1, #filtered_games - visible_games + 1)
    
    if y > 0 then
        -- Scroll up (show earlier games)
        self.scroll_offset = math.max(1, (self.scroll_offset or 1) - 1)
    elseif y < 0 then
        -- Scroll down (show later games)
        self.scroll_offset = math.min(max_scroll, (self.scroll_offset or 1) + 1)
    end
end

-- This function is now internal to the view
function LauncherView:getGameAtPosition(x, y, filtered_games)
    -- This function now needs the filtered_games list passed to it
    -- Or, better, the state passes filtered_games to self.view:update()
    -- For now, let's assume the controller passes it to mousepressed
    local games = filtered_games or self.controller.filtered_games

    if not games or #games == 0 then
        return nil
    end
    
    local list_width = self.detail_panel_open and (love.graphics.getWidth() - self.detail_panel_width - 20) or (love.graphics.getWidth() - 20)
    
    if x < 10 or x > 10 + list_width or y < 90 then
        return nil
    end
    
    local visible_games = math.floor((love.graphics.getHeight() - 100) / (self.button_height + self.button_padding))
    local start_index = self.scroll_offset or 1
    
    for i = 0, visible_games - 1 do
        local game_index = start_index + i
        if game_index <= #games then
            local button_y = 90 + i * (self.button_height + self.button_padding)
            
            if y >= button_y and y <= button_y + self.button_height then
                return games[game_index].id
            end
        end
    end
    
    return nil
end

-- Removed drawWindow method
-- Removed drawTokenCounter method

function LauncherView:drawCategoryButtons(x, y, selected_category)
    local categories = {
        {id = "all", name = "All"}, {id = "action", name = "Action"}, {id = "puzzle", name = "Puzzle"},
        {id = "arcade", name = "Arcade"}, {id = "locked", name = "Locked"}, {id = "unlocked", name = "Unlocked"},
        {id = "completed", name = "Completed"}, {id = "easy", name = "Easy"}, {id = "medium", name = "Medium"},
        {id = "hard", name = "Hard"}
    }
    local button_width = 75
    local button_height = self.category_button_height
    for i, category in ipairs(categories) do
        local bx = x + (i - 1) * (button_width + 5)
        local by = y
        if category.id == selected_category then
            love.graphics.setColor(0.2, 0.2, 0.6)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle('fill', bx, by, button_width, button_height)
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle('line', bx, by, button_width, button_height)
        love.graphics.setColor(1, 1, 1)
        local text_width = love.graphics.getFont():getWidth(category.name)
        love.graphics.print(category.name, bx + (button_width - text_width) / 2, by + 8, 0, 0.8, 0.8)
    end
end

function LauncherView:drawGameList(x, y, w, h, games, selected_index, hovered_game_id)
    local button_height = self.button_height
    local button_padding = self.button_padding
    local visible_games = math.floor(h / (button_height + button_padding))
    
    local start_index = self.scroll_offset or 1
    start_index = math.max(1, math.min(start_index, math.max(1, #games - visible_games + 1)))
    self.scroll_offset = start_index
    
    local end_index = math.min(#games, start_index + visible_games - 1)
    
    for i = start_index, end_index do
        local game_data = games[i]
        if game_data then
            local by = y + (i - start_index) * (button_height + button_padding)
            self:drawGameIcon(x, by, w, button_height, game_data, i == selected_index, 
                hovered_game_id == game_data.id, self.player_data, self.game_data)
        end
    end
    
    if #games > visible_games then
        love.graphics.setColor(0.5, 0.5, 0.5)
        local scroll_height = math.max(20, (visible_games / #games) * h)
        local scroll_y = y + ((start_index - 1) / #games) * h
        love.graphics.rectangle('fill', x + w - 10, scroll_y, 8, scroll_height)
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("Showing %d-%d of %d games", start_index, end_index, #games), x, y + h + 5, 0, 0.9, 0.9)
end

function LauncherView:drawGameIcon(x, y, w, h, game_data, selected, hovered, player_data, game_data_obj)
    local is_unlocked = player_data:isGameUnlocked(game_data.id)
    local perf = player_data:getGamePerformance(game_data.id)
    local is_completed = perf ~= nil
    local is_auto_completed = is_completed and perf.auto_completed
    
    if selected then
        love.graphics.setColor(0.3, 0.3, 0.7)
    elseif hovered then
        love.graphics.setColor(0.35, 0.35, 0.35)
    else
        love.graphics.setColor(0.25, 0.25, 0.25)
    end
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
    
    local badge_x, badge_y = x + 5, y + 5
    if is_auto_completed then
        UIComponents.drawBadge(badge_x, badge_y, 15, "A", {0.5, 0.5, 1}) -- Use Badge
    elseif is_completed then
         UIComponents.drawBadge(badge_x, badge_y, 15, "C", {0, 1, 0}) -- Use Badge
    elseif not is_unlocked then
         UIComponents.drawBadge(badge_x, badge_y, 15, "L", {1, 0, 0}) -- Use Badge
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(game_data.display_name, x + 25, y + 5, 0, 1.0, 1.0)
    
    local difficulty = game_data.difficulty_level or 1
    local diff_text, diff_color = "Easy", {0, 1, 0}
    if difficulty > 6 then diff_text, diff_color = "Hard", {1, 0, 0}
    elseif difficulty > 3 then diff_text, diff_color = "Medium", {1, 1, 0} end
    love.graphics.setColor(diff_color)
    love.graphics.print("Difficulty: " .. diff_text .. " (" .. difficulty .. ")", x + 25, y + 25, 0, 0.8, 0.8)
    
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print(game_data.formula_string, x + 25, y + 40, 0, 0.7, 0.7)
    
    if is_completed and perf then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("Power: " .. math.floor(perf.best_score), x + w - 150, y + 5)
    elseif not is_unlocked then
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.print("Cost: " .. game_data.unlock_cost .. " tokens", x + w - 150, y + 5)
    end
    
    love.graphics.setColor(1, 1, 0)
    love.graphics.print(string.format("x%.1f", game_data.variant_multiplier), x + w - 50, y + h / 2 - 8, 0, 1.2, 1.2)
end

function LauncherView:drawGameDetailPanel(x, y, w, h, game_data)
    -- Use UIComponents.drawPanel for background
    UIComponents.drawPanel(x, y, w, h, {0.2, 0.2, 0.2})
    
    local line_y, line_height = y + 10, 20
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(game_data.display_name, x + 10, line_y, 0, 1.2, 1.2)
    line_y = line_y + line_height * 1.5
    
    local difficulty = game_data.difficulty_level or 1
    local diff_text, diff_color = "Easy", {0, 1, 0}
    if difficulty > 6 then diff_text, diff_color = "HARD", {1, 0, 0}
    elseif difficulty > 3 then diff_text, diff_color = "Medium", {1, 1, 0} end
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Difficulty: ", x + 10, line_y)
    love.graphics.setColor(diff_color)
    love.graphics.print(diff_text .. " (" .. difficulty .. ")", x + 90, line_y)
    line_y = line_y + line_height
    
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Tier: " .. game_data.tier, x + 10, line_y)
    line_y = line_y + line_height
    
    local is_unlocked = self.player_data:isGameUnlocked(game_data.id)
    if not is_unlocked then
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.print("Unlock Cost: " .. game_data.unlock_cost .. " tokens", x + 10, line_y)
        line_y = line_y + line_height
    end
    
    line_y = line_y + 10
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("POWER FORMULA:", x + 10, line_y, 0, 1.1, 1.1)
    line_y = line_y + line_height
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(game_data.formula_string, x + 10, line_y, 0, 0.9, 0.9)
    line_y = line_y + line_height * 1.5
    
    local perf = self.player_data:getGamePerformance(game_data.id)
    if perf then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("Your Best Performance:", x + 10, line_y)
        line_y = line_y + line_height
        love.graphics.setColor(1, 1, 1)
        for _, metric_name in ipairs(game_data.metrics_tracked) do
            local value = perf.metrics[metric_name]
            if value then
                if type(value) == "number" then value = string.format("%.1f", value) end
                love.graphics.print("  " .. metric_name .. ": " .. value, x + 10, line_y, 0, 0.8, 0.8)
                line_y = line_y + line_height * 0.9
            end
        end
        line_y = line_y + 5
        love.graphics.setColor(0, 1, 1)
        love.graphics.print("Power: " .. math.floor(perf.best_score), x + 10, line_y, 0, 1.2, 1.2)
        line_y = line_y + line_height
        if perf.auto_completed then
            -- Use Badge component
            UIComponents.drawBadge(x + 10, line_y, 15, "AUTO", {0.5, 0.5, 1})
            love.graphics.print("[Auto-Completed]", x + 30, line_y, 0, 0.9, 0.9)
            line_y = line_y + line_height
        end
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("Not yet played", x + 10, line_y)
        line_y = line_y + line_height
    end
    
    line_y = line_y + 10
    love.graphics.setColor(0.8, 0.8, 1)
    love.graphics.print("Auto-Play Estimate:", x + 10, line_y)
    line_y = line_y + line_height
    local auto_power = game_data.formula_function(game_data.auto_play_performance)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Power: ~" .. math.floor(auto_power), x + 10, line_y, 0, 0.9, 0.9)
    line_y = line_y + line_height
    love.graphics.print("Token Rate: ~" .. math.floor(auto_power) .. "/min", x + 10, line_y, 0, 0.9, 0.9)
    line_y = line_y + line_height
    
    if difficulty > 8 then
        line_y = line_y + 10
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("WARNING: HIGH RISK!", x + 10, line_y, 0, 0.9, 0.9)
    end
    
    -- Use Button component
    local button_y = y + h - 45
    local button_text = is_unlocked and "PLAY GAME" or "UNLOCK & PLAY"
    UIComponents.drawButton(x + 10, button_y, w - 20, 35, button_text, true, false) -- Need hover state from update
end

return LauncherView