local Object = require('class')
local LauncherView = require('src.views.launcher_view')
local LauncherState = Object:extend('LauncherState')

function LauncherState:init(player_data, game_data, state_machine, save_manager)
    self.player_data = player_data
    self.game_data = game_data
    self.state_machine = state_machine
    self.save_manager = save_manager

    -- Create the view instance, passing a reference to this state (as controller)
    self.view = LauncherView:new(self, player_data, game_data)

    self.all_games = {}
    self.filtered_games = {}
end

function LauncherState:enter()
    -- Load games from GameData
    self.all_games = self.game_data:getAllGames()
    
    -- Sort by ID for consistent ordering
    table.sort(self.all_games, function(a, b)
        return a.id < b.id
    end)
    
    -- Apply default filter (which is now stored in the view)
    self:updateFilter(self.view.selected_category)
end

function LauncherState:updateFilter(category)
    self.view.selected_category = category -- Update view's state
    self.filtered_games = {}
    
    for _, game_data in ipairs(self.all_games) do
        local include = false
        
        if category == "all" then
            include = true
        elseif category == "action" or category == "puzzle" or category == "arcade" then
            include = (game_data.category == category)
        elseif category == "locked" then
            include = not self.player_data:isGameUnlocked(game_data.id)
        elseif category == "unlocked" then
            include = self.player_data:isGameUnlocked(game_data.id)
        elseif category == "completed" then
            include = self.player_data:getGamePerformance(game_data.id) ~= nil
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
    
    -- Reset selection in view
    self.view.selected_index = math.min(self.view.selected_index, #self.filtered_games)
    if self.view.selected_index < 1 then self.view.selected_index = 1 end
    self.view.scroll_offset = 1
end

function LauncherState:update(dt)
    -- Delegate update logic (like hover checks) to the view
    self.view:update(dt)
end

function LauncherState:draw()
    -- Delegate all drawing to the view
    self.view:draw(self.filtered_games, self.player_data.tokens)
end

function LauncherState:keypressed(key)
    local handled = true -- Assume handled unless proven otherwise
    if key == 'up' or key == 'w' then
        self.view.selected_index = math.max(1, self.view.selected_index - 1)
        if self.view.selected_index <= #self.filtered_games then
            self.view.selected_game = self.filtered_games[self.view.selected_index]
        end
    elseif key == 'down' or key == 's' then
        self.view.selected_index = math.min(#self.filtered_games, self.view.selected_index + 1)
        if self.view.selected_index <= #self.filtered_games then
            self.view.selected_game = self.filtered_games[self.view.selected_index]
        end
    elseif key == 'return' or key == 'space' then
        self:selectGame()
    elseif key == 'tab' then
        self.view.detail_panel_open = not self.view.detail_panel_open
        if self.view.detail_panel_open and self.view.selected_index <= #self.filtered_games then
            self.view.selected_game = self.filtered_games[self.view.selected_index]
        end
    elseif key == 'escape' then
        if self.view.detail_panel_open then
            self.view.detail_panel_open = false
        else
            self.state_machine:switch('desktop')
        end
    elseif key >= '1' and key <= '9' or key == '0' then
        local filters = {"all", "action", "puzzle", "arcade", "locked", "unlocked", "completed", "easy", "medium", "hard"}
        local index = key == '0' and 10 or tonumber(key)
        if filters[index] then
            self:updateFilter(filters[index])
        else
            handled = false -- Key wasn't a valid filter shortcut
        end
    else
        handled = false -- Key wasn't used by this state
    end
    return handled
end

function LauncherState:selectGame()
    if self.view.selected_index > #self.filtered_games then return end
    
    local selected_game = self.filtered_games[self.view.selected_index]
    if not selected_game then return end
    
    self:launchGame(selected_game.id)
end

function LauncherState:launchGame(game_id)
    local game_data = self.game_data:getGame(game_id)
    if not game_data then return end
    
    local is_unlocked = self.player_data:isGameUnlocked(game_id)
    
    if not is_unlocked then
        self:showUnlockPrompt(game_data)
    else
        self.state_machine:switch('minigame', game_data)
    end
end

function LauncherState:showUnlockPrompt(game_data)
    local cost = game_data.unlock_cost
    local has_tokens = self.player_data:hasTokens(cost)
    local difficulty = game_data.difficulty_level or 1
    
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
        self.player_data.tokens,
        difficulty_text,
        game_data.variant_multiplier,
        warning
    )
    
    if not has_tokens then
        message = "Not enough tokens!\n\n" .. message
        love.window.showMessageBox("Cannot Unlock", message, "error")
        return
    end
    
    local buttons = {"Unlock", "Cancel"}
    local pressed = love.window.showMessageBox("Unlock Game", message, buttons, "info")
    
    if pressed == 1 then
        if self.player_data:spendTokens(cost) then
            self.player_data:unlockGame(game_data.id)
            self.save_manager.save(self.player_data)
            print("Unlocked: " .. game_data.display_name)
            
            self.state_machine:switch('minigame', game_data)
        end
    end
end

function LauncherState:showGameDetails(game_id)
    self.view.selected_game = self.game_data:getGame(game_id)
    self.view.detail_panel_open = true
end

function LauncherState:mousepressed(x, y, button)
    -- Delegate input handling to the view
    local event = self.view:mousepressed(x, y, button, self.filtered_games)
    
    if not event then return end
    
    -- Handle the event returned by the view
    if event.name == "filter_changed" then
        self:updateFilter(event.category)
    
    elseif event.name == "launch_game" then
        self:launchGame(event.id)
    
    elseif event.name == "game_selected" then
        -- This logic is now handled inside the view,
        -- but we could add controller logic here if needed.
        print("Selected game: " .. event.game.display_name)
    end
end

function LauncherState:launchSpaceDefender()
    self.state_machine:switch('space_defender', 1)
end

function LauncherState:wheelmoved(x, y)
    -- Delegate scrolling to the view
    self.view:wheelmoved(x, y, self.filtered_games)
end

return LauncherState