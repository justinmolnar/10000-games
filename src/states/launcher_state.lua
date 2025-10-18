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
    
    -- Sort by ID with natural number sorting
    table.sort(self.all_games, function(a, b)
        -- Extract base name and number from id
        local a_base, a_num = a.id:match("^(.-)_(%d+)$")
        local b_base, b_num = b.id:match("^(.-)_(%d+)$")
        
        -- If both have numbers, compare base first, then number
        if a_base and b_base and a_num and b_num then
            if a_base == b_base then
                return tonumber(a_num) < tonumber(b_num)
            else
                return a_base < b_base
            end
        end
        
        -- Fallback to regular string comparison
        return a.id < b.id
    end)
    
    -- Apply default filter (which is now stored in the view)
    self:updateFilter(self.view.selected_category)
end

function LauncherState:setViewport(x, y, width, height)
    self.viewport = {x = x, y = y, width = width, height = height}
    -- Recalculate view layout if necessary based on new viewport size
    self.view.detail_panel_width = math.min(350, width * 0.4) -- Example adjustment
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
    if not self.viewport then return end -- Don't draw if viewport isn't set

    love.graphics.push()
    love.graphics.translate(self.viewport.x, self.viewport.y)
    love.graphics.setScissor(self.viewport.x, self.viewport.y, self.viewport.width, self.viewport.height)

    -- Delegate drawing to the view, passing viewport dimensions for layout
    self.view:drawWindowed(self.filtered_games, self.player_data.tokens, self.viewport.width, self.viewport.height)

    love.graphics.setScissor()
    love.graphics.pop()
end

function LauncherState:keypressed(key)
    -- Key events are not relative to viewport, handle normally
    local handled = true -- Assume handled unless proven otherwise
    if key == 'up' or key == 'w' then
        local old_index = self.view.selected_index
        self.view.selected_index = math.max(1, self.view.selected_index - 1)
        if self.view.selected_index ~= old_index and self.view.selected_index <= #self.filtered_games then
            self.view.selected_game = self.filtered_games[self.view.selected_index]
        end
        -- Adjust scroll if selection goes out of view
        if self.view.selected_index < self.view.scroll_offset then
            self.view.scroll_offset = self.view.selected_index
        end
    elseif key == 'down' or key == 's' then
        local old_index = self.view.selected_index
        self.view.selected_index = math.min(#self.filtered_games, self.view.selected_index + 1)
         if self.view.selected_index ~= old_index and self.view.selected_index <= #self.filtered_games then
            self.view.selected_game = self.filtered_games[self.view.selected_index]
        end
         -- Adjust scroll if selection goes out of view
        local visible_games = self.view:getVisibleGameCount(self.viewport and self.viewport.height or 600)
        if self.view.selected_index >= self.view.scroll_offset + visible_games then
             self.view.scroll_offset = self.view.selected_index - visible_games + 1
        end
    elseif key == 'return' or key == 'space' then
        self:selectGame()
    elseif key == 'tab' then
        self.view.detail_panel_open = not self.view.detail_panel_open
        if self.view.detail_panel_open and self.view.selected_index <= #self.filtered_games then
            self.view.selected_game = self.filtered_games[self.view.selected_index]
        end
    elseif key == 'escape' then
        -- Only close detail panel, don't switch state
        if self.view.detail_panel_open then
            self.view.detail_panel_open = false
        else
            -- If view/state had other modals, handle closing them here
            -- Otherwise, do nothing (window close button handles closing)
            handled = false -- Let window manager handle close if desired via Alt+F4 later
        end
    elseif key >= '1' and key <= '9' or key == '0' then
        local filters = {"all", "action", "puzzle", "arcade", "locked", "unlocked", "completed", "easy", "medium", "hard"}
        local index = key == '0' and 10 or tonumber(key)
        if filters[index] then
            self:updateFilter(filters[index])
        else
            handled = false
        end
    else
        handled = false
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
    if not self.viewport then return false end

    -- Translate coordinates
    local local_x = x - self.viewport.x
    local local_y = y - self.viewport.y

    -- Check if click is outside viewport bounds (relative to window)
    if local_x < 0 or local_x > self.viewport.width or local_y < 0 or local_y > self.viewport.height then
        return false -- Click was outside this window's content area
    end

    -- Delegate input handling to the view using local coordinates
    local event = self.view:mousepressed(local_x, local_y, button, self.filtered_games, self.viewport.width, self.viewport.height)

    if not event then return false end -- View didn't handle it

    -- Handle the event returned by the view
    if event.name == "filter_changed" then
        self:updateFilter(event.category)
    elseif event.name == "launch_game" then
        self:launchGame(event.id) -- This still switches state machine, which is correct
    elseif event.name == "game_selected" then
        print("Selected game: " .. event.game.display_name)
    end

    -- Return event object for DesktopState (or nil if view didn't handle)
    -- Add a type for window closing if needed, e.g., if a back button exists
    return { type = "content_interaction" } -- Signify content was interacted with
end

function LauncherState:launchSpaceDefender()
    self.state_machine:switch('space_defender', 1)
end

function LauncherState:wheelmoved(x, y)
     if not self.viewport then return end

     -- Get mouse position relative to screen
     local mx, my = love.mouse.getPosition()

     -- Check if mouse is within this window's viewport
     if mx >= self.viewport.x and mx <= self.viewport.x + self.viewport.width and
        my >= self.viewport.y and my <= self.viewport.y + self.viewport.height then
         -- Delegate scrolling to the view
         self.view:wheelmoved(x, y, self.filtered_games, self.viewport.width, self.viewport.height)
     end
end

return LauncherState