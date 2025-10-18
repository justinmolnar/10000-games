local Object = require('class')
local LauncherState = Object:extend('LauncherState')

function LauncherState:init(context)
    self.context = context
    self.all_games = {}
    self.filtered_games = {}
    self.selected_category = "all"
    self.selected_index = 1
    self.scroll_offset = 0
    self.hovered_game = nil
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

function LauncherState:enter()
    -- Initialize filtered_games immediately to prevent nil errors
    self.filtered_games = {}
    
    -- Load games from GameData
    self.all_games = self.context.game_data:getAllGames()
    
    -- Sort by ID for consistent ordering
    table.sort(self.all_games, function(a, b)
        return a.id < b.id
    end)
    
    -- Apply default filter
    self:updateFilter("all")
    self.selected_index = 1
    self.detail_panel_open = false
    self.scroll_offset = 0
    
    -- Initialize double-click tracking
    self.last_click_time = 0
    self.last_click_game = nil
end

function LauncherState:updateFilter(category)
    self.selected_category = category
    self.filtered_games = {}
    
    for _, game_data in ipairs(self.all_games) do
        local include = false
        
        if category == "all" then
            include = true
        elseif category == "action" or category == "puzzle" or category == "arcade" then
            include = (game_data.category == category)
        elseif category == "locked" then
            include = not self.context.player_data:isGameUnlocked(game_data.id)
        elseif category == "unlocked" then
            include = self.context.player_data:isGameUnlocked(game_data.id)
        elseif category == "completed" then
            include = self.context.player_data:getGamePerformance(game_data.id) ~= nil
        elseif category == "easy" then
            include = (game_data.difficulty_level or 1) <= 3
        elseif category == "medium" then
            local diff = game_data.difficulty_level or 1
            include = (diff > 3 and diff <= 6)
        elseif category == "hard" then
            include = (game_data.difficulty_level or 1) > 6
        end
        
        if include then
            table.insert(self.filtered_games, game_data)
        end
    end
    
    -- Reset selection
    self.selected_index = math.min(self.selected_index, #self.filtered_games)
    if self.selected_index < 1 then self.selected_index = 1 end
    self.scroll_offset = 0
end

function LauncherState:update(dt)
    -- Safety check - only update if we have games loaded
    if not self.filtered_games or #self.filtered_games == 0 then
        return
    end
    
    -- Update hovered game based on mouse position
    local mx, my = love.mouse.getPosition()
    self.hovered_game = self:getGameAtPosition(mx, my)
end

function LauncherState:draw()
    local LauncherView = require('src.views.launcher_view')
    
    -- Draw main window
    LauncherView.drawWindow(0, 0, love.graphics.getWidth(), love.graphics.getHeight(), "Game Collection - MVP")
    
    -- Draw category buttons
    LauncherView.drawCategoryButtons(10, 50, self.selected_category, self)
    
    -- Draw token counter
    LauncherView.drawTokenCounter(love.graphics.getWidth() - 200, 10, self.context.player_data.tokens)
    
    -- Draw game list
    local list_width = self.detail_panel_open and (love.graphics.getWidth() - self.detail_panel_width - 20) or (love.graphics.getWidth() - 20)
    LauncherView.drawGameList(10, 90, list_width, love.graphics.getHeight() - 100, 
        self.filtered_games, self.selected_index, self.hovered_game, self)
    
    -- Draw detail panel if open
    if self.detail_panel_open and self.selected_game then
        local panel_x = love.graphics.getWidth() - self.detail_panel_width - 5
        LauncherView.drawGameDetailPanel(panel_x, 90, self.detail_panel_width, 
            love.graphics.getHeight() - 100, self.selected_game, self)
    end
end

function LauncherState:keypressed(key)
    if key == 'up' or key == 'w' then
        self.selected_index = math.max(1, self.selected_index - 1)
        if self.selected_index <= #self.filtered_games then
            self.selected_game = self.filtered_games[self.selected_index]
        end
    elseif key == 'down' or key == 's' then
        self.selected_index = math.min(#self.filtered_games, self.selected_index + 1)
        if self.selected_index <= #self.filtered_games then
            self.selected_game = self.filtered_games[self.selected_index]
        end
    elseif key == 'return' or key == 'space' then
        self:selectGame()
    elseif key == 'tab' then
        self.detail_panel_open = not self.detail_panel_open
        if self.detail_panel_open and self.selected_index <= #self.filtered_games then
            self.selected_game = self.filtered_games[self.selected_index]
        end
    elseif key == 'escape' then
        if self.detail_panel_open then
            self.detail_panel_open = false
        else
            self.context.state_machine:switch('desktop')
        end
    elseif key >= '1' and key <= '9' or key == '0' then
        -- Quick filter shortcuts (1-0 for 10 categories)
        local filters = {"all", "action", "puzzle", "arcade", "locked", "unlocked", "completed", "easy", "medium", "hard"}
        local index = key == '0' and 10 or tonumber(key)
        if filters[index] then
            self:updateFilter(filters[index])
        end
    end
end

function LauncherState:selectGame()
    if self.selected_index > #self.filtered_games then return end
    
    local selected_game = self.filtered_games[self.selected_index]
    if not selected_game then return end
    
    self:launchGame(selected_game.id)
end

function LauncherState:launchGame(game_id)
    local game_data = self.context.game_data:getGame(game_id)
    if not game_data then return end
    
    local is_unlocked = self.context.player_data:isGameUnlocked(game_id)
    
    if not is_unlocked then
        -- Show unlock prompt
        self:showUnlockPrompt(game_data)
    else
        -- Launch game
        self.context.state_machine:switch('minigame', game_data)
    end
end

function LauncherState:showUnlockPrompt(game_data)
    local cost = game_data.unlock_cost
    local has_tokens = self.context.player_data:hasTokens(cost)
    local difficulty = game_data.difficulty_level or 1
    
    -- Build prompt message
    local difficulty_text = "Easy"
    if difficulty > 6 then
        difficulty_text = "Hard"
    elseif difficulty > 3 then
        difficulty_text = "Medium"
    end
    
    local warning = ""
    if difficulty > 8 then
        warning = "\n\nWARNING: This is a very difficult variant!"
    end
    
    local message = string.format(
        "Unlock %s?\n\nCost: %d tokens (You have: %d)\nDifficulty: %s\nMultiplier: %.1fx%s",
        game_data.display_name,
        cost,
        self.context.player_data.tokens,
        difficulty_text,
        game_data.variant_multiplier,
        warning
    )
    
    if not has_tokens then
        message = "Not enough tokens!\n\n" .. message
        love.window.showMessageBox("Cannot Unlock", message, "error")
        return
    end
    
    -- Show confirmation
    local buttons = {"Unlock", "Cancel"}
    local pressed = love.window.showMessageBox("Unlock Game", message, buttons, "info")
    
    if pressed == 1 then
        -- User confirmed
        if self.context.player_data:spendTokens(cost) then
            self.context.player_data:unlockGame(game_data.id)
            self.context.save_manager.save(self.context.player_data)
            print("Unlocked: " .. game_data.display_name)
            
            -- Launch immediately
            self.context.state_machine:switch('minigame', game_data)
        end
    end
end

function LauncherState:showGameDetails(game_id)
    self.selected_game = self.context.game_data:getGame(game_id)
    self.detail_panel_open = true
end

function LauncherState:getGameAtPosition(x, y)
    -- Safety check for filtered_games
    if not self.filtered_games or #self.filtered_games == 0 then
        return nil
    end
    
    -- Check if mouse is over any game in the list
    local list_width = self.detail_panel_open and (love.graphics.getWidth() - self.detail_panel_width - 20) or (love.graphics.getWidth() - 20)
    
    if x < 10 or x > 10 + list_width or y < 90 then
        return nil
    end
    
    local visible_games = math.floor((love.graphics.getHeight() - 100) / (self.button_height + self.button_padding))
    local start_index = self.scroll_offset or 1
    
    for i = 0, visible_games - 1 do
        local game_index = start_index + i
        if game_index <= #self.filtered_games then
            local button_y = 90 + i * (self.button_height + self.button_padding)
            
            if y >= button_y and y <= button_y + self.button_height then
                return self.filtered_games[game_index].id
            end
        end
    end
    
    return nil
end

function LauncherState:mousepressed(x, y, button)
    if button ~= 1 then return end
    
    -- Check category buttons
    local categories = {"all", "action", "puzzle", "arcade", "locked", "unlocked", "completed", "easy", "medium", "hard"}
    local button_width = 75
    local button_x = 10
    
    for i, category in ipairs(categories) do
        local bx = button_x + (i - 1) * (button_width + 5)
        local by = 50
        
        if x >= bx and x <= bx + button_width and y >= by and y <= by + self.category_button_height then
            self:updateFilter(category)
            return
        end
    end
    
    -- Check game list
    local clicked_game = self:getGameAtPosition(x, y)
    if clicked_game then
        -- Find the index WITHOUT auto-centering
        for i, g in ipairs(self.filtered_games) do
            if g.id == clicked_game then
                -- Check for double-click BEFORE updating selection
                local is_double_click = (self.last_click_game == clicked_game and 
                                        love.timer.getTime() - self.last_click_time < 0.5)
                
                if is_double_click then
                    -- Double-click detected - launch immediately
                    self:launchGame(clicked_game)
                    return
                end
                
                -- Single click - just select, list won't auto-center
                self.selected_index = i
                self.selected_game = g
                
                -- Update double-click tracking
                self.last_click_game = clicked_game
                self.last_click_time = love.timer.getTime()
                return
            end
        end
    end
    
    -- Check detail panel buttons if open
    if self.detail_panel_open and self.selected_game then
        local panel_x = love.graphics.getWidth() - self.detail_panel_width - 5
        local button_y = love.graphics.getHeight() - 50
        
        -- Launch button
        if x >= panel_x + 10 and x <= panel_x + self.detail_panel_width - 10 and
           y >= button_y and y <= button_y + 35 then
            self:launchGame(self.selected_game.id)
        end
    end
end

function LauncherState:launchSpaceDefender()
    -- Launch Space Defender level 1 by default
    self.context.state_machine:switch('space_defender', 1)
end

function LauncherState:wheelmoved(x, y)
    -- Scroll the list view, not the selection
    local visible_games = math.floor((love.graphics.getHeight() - 100) / (self.button_height + self.button_padding))
    local max_scroll = math.max(1, #self.filtered_games - visible_games + 1)
    
    if y > 0 then
        -- Scroll up (show earlier games)
        self.scroll_offset = math.max(1, (self.scroll_offset or 1) - 1)
    elseif y < 0 then
        -- Scroll down (show later games)
        self.scroll_offset = math.min(max_scroll, (self.scroll_offset or 1) + 1)
    end
end

return LauncherState