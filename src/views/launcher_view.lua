-- launcher_view.lua: View components for the game launcher

local LauncherView = {}

function LauncherView.drawWindow(x, y, w, h, title)
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0, 0, 0.5)
    love.graphics.rectangle('fill', x, y, w, 30)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(title, x + 10, y + 8, 0, 1.2, 1.2)
end

function LauncherView.drawTokenCounter(x, y, tokens)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Tokens: ", x, y, 0, 1.5, 1.5)
    if tokens < 100 then
        love.graphics.setColor(1, 0, 0)
    elseif tokens < 500 then
        love.graphics.setColor(1, 1, 0)
    else
        love.graphics.setColor(0, 1, 0)
    end
    love.graphics.print(tokens, x + 90, y, 0, 1.5, 1.5)
end

function LauncherView.drawCategoryButtons(x, y, selected_category, launcher_state)
    local categories = {
        {id = "all", name = "All"}, {id = "action", name = "Action"}, {id = "puzzle", name = "Puzzle"},
        {id = "arcade", name = "Arcade"}, {id = "locked", name = "Locked"}, {id = "unlocked", name = "Unlocked"},
        {id = "completed", name = "Completed"}, {id = "easy", name = "Easy"}, {id = "medium", name = "Medium"},
        {id = "hard", name = "Hard"}
    }
    local button_width = 75
    local button_height = launcher_state.category_button_height
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

function LauncherView.drawGameList(x, y, w, h, games, selected_index, hovered_game, launcher_state)
    local button_height = launcher_state.button_height
    local button_padding = launcher_state.button_padding
    local visible_games = math.floor(h / (button_height + button_padding))
    
    -- Use scroll offset, don't auto-adjust it
    local start_index = launcher_state.scroll_offset or 1
    
    -- Clamp start_index to valid range
    start_index = math.max(1, math.min(start_index, math.max(1, #games - visible_games + 1)))
    
    -- Store it back (but don't modify based on selection)
    launcher_state.scroll_offset = start_index
    
    local end_index = math.min(#games, start_index + visible_games - 1)
    
    for i = start_index, end_index do
        local game_data = games[i]
        if game_data then
            local by = y + (i - start_index) * (button_height + button_padding)
            LauncherView.drawGameIcon(x, by, w, button_height, game_data, i == selected_index, 
                hovered_game == game_data.id, launcher_state.context.player_data, launcher_state.context.game_data)
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

function LauncherView.drawGameIcon(x, y, w, h, game_data, selected, hovered, player_data, game_data_obj)
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
        love.graphics.setColor(0.5, 0.5, 1)
        love.graphics.rectangle('fill', badge_x, badge_y, 15, 15)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("A", badge_x + 3, badge_y + 2, 0, 0.8, 0.8)
    elseif is_completed then
        love.graphics.setColor(0, 1, 0)
        love.graphics.rectangle('fill', badge_x, badge_y, 15, 15)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("C", badge_x + 3, badge_y + 2, 0, 0.8, 0.8)
    elseif not is_unlocked then
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle('fill', badge_x, badge_y, 15, 15)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("L", badge_x + 3, badge_y + 2, 0, 0.8, 0.8)
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

function LauncherView.drawGameDetailPanel(x, y, w, h, game_data, launcher_state)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
    
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
    
    local is_unlocked = launcher_state.context.player_data:isGameUnlocked(game_data.id)
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
    
    local perf = launcher_state.context.player_data:getGamePerformance(game_data.id)
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
            love.graphics.setColor(0.5, 0.5, 1)
            love.graphics.print("[Auto-Completed]", x + 10, line_y, 0, 0.9, 0.9)
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
    
    local button_y = y + h - 45
    local button_text = is_unlocked and "PLAY GAME" or "UNLOCK & PLAY"
    love.graphics.setColor(0, 0.5, 0)
    love.graphics.rectangle('fill', x + 10, button_y, w - 20, 35)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.rectangle('line', x + 10, button_y, w - 20, 35)
    love.graphics.setColor(1, 1, 1)
    local text_width = love.graphics.getFont():getWidth(button_text)
    love.graphics.print(button_text, x + (w - text_width) / 2, button_y + 10)
end

return LauncherView