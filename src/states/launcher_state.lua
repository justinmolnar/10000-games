local Object = require('class')
local Strings = require('src.utils.strings')
local LauncherView = require('src.views.launcher_view')
local LauncherState = Object:extend('LauncherState')

function LauncherState:init(player_data, game_data, state_machine, save_manager, di)
    self.player_data = player_data
    self.game_data = game_data
    self.state_machine = state_machine
    self.save_manager = save_manager
    self.di = di
    self.event_bus = di and di.eventBus

    -- Create the view instance, passing a reference to this state (as controller)
    self.view = LauncherView:new(self, player_data, game_data)

    self.all_games = {}
    self.filtered_games = {}

    -- Subscribe to token changes to refresh affordability
    if self.event_bus then
        self.event_bus:subscribe('tokens_changed', function()
            -- Re-apply current filter to update affordability
            if self.view and self.view.selected_category then
                self:updateFilter(self.view.selected_category)
            end
        end)
    end
end

function LauncherState:loadVariantData(game_id)
    -- Parse game_id to determine which variant file and clone_index
    -- Format: "dodge_1" -> "dodge", clone 0 (0-indexed)
    local ok_paths, Paths = pcall(require, 'src.paths')
    if not ok_paths then
        print("[LauncherState] ERROR: Could not require src.paths")
        return nil
    end

    local ok_json, json = pcall(require, 'lib.json')
    if not ok_json then
        print("[LauncherState] ERROR: Could not require lib.json")
        return nil
    end

    local base_name, clone_number = game_id:match("^(.-)_(%d+)$")
    if not base_name or not clone_number then
        return nil
    end

    local clone_index = tonumber(clone_number) - 1 -- Convert to 0-indexed
    local variant_file = "variants/" .. base_name .. "_variants.json"
    local file_path = Paths.assets.data .. variant_file

    -- Read variant file
    local read_ok, contents = pcall(love.filesystem.read, file_path)
    if not read_ok or not contents then
        -- Silently return nil for missing variant files (some games might not have variants yet)
        return nil
    end

    -- Parse JSON
    local decode_ok, variants = pcall(json.decode, contents)
    if not decode_ok or not variants then
        print("[LauncherState] ERROR: Failed to decode " .. file_path)
        return nil
    end

    -- Find variant with matching clone_index
    for _, variant in ipairs(variants) do
        if variant.clone_index == clone_index then
            return variant
        end
    end

    return nil
end

function LauncherState:enter()
    -- Publish shop_opened event
    if self.event_bus then
        self.event_bus:publish('shop_opened')
    end

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
    if self.view and self.view.updateLayout then
         self.view:updateLayout(width, height) -- Pass dimensions to view
    end
end

function LauncherState:updateFilter(category)
    self.view.selected_category = category -- Update view's state
    self.filtered_games = {}

    -- Publish shop_category_changed event
    if self.event_bus then
        self.event_bus:publish('shop_category_changed', category)
    end

    local filters = {
        all = function(_) return true end,
        action = function(g) return g.category == 'action' end,
        puzzle = function(g) return g.category == 'puzzle' end,
        arcade = function(g) return g.category == 'arcade' end,
        locked = function(g) return not self.player_data:isGameUnlocked(g.id) end,
        unlocked = function(g) return self.player_data:isGameUnlocked(g.id) end,
        affordable = function(g)
            return self.player_data:isGameUnlocked(g.id) or
                   (g.unlock_cost and self.player_data.tokens >= g.unlock_cost)
        end,
        completed = function(g) return self.player_data:getGamePerformance(g.id) ~= nil end,
        easy = function(g) return (g.difficulty_level or 1) <= 3 end,
        medium = function(g) local d = g.difficulty_level or 1; return d > 3 and d <= 6 end,
        hard = function(g) return (g.difficulty_level or 1) > 6 end,
    }

    local predicate = filters[category] or filters.all
    for _, g in ipairs(self.all_games) do
        if predicate(g) then table.insert(self.filtered_games, g) end
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
    if not self.viewport then return end
    -- REMOVED push/translate/scissor/pop
    self.view:drawWindowed(self.filtered_games, self.player_data.tokens, self.viewport.width, self.viewport.height)
    -- REMOVED setScissor/pop
end

function LauncherState:keypressed(key)
    local result_event = nil -- To store the event to be returned
    local handled = true -- Assume handled unless proven otherwise

    if key == 'up' or key == 'w' then
        local old_index = self.view.selected_index
        self.view.selected_index = math.max(1, self.view.selected_index - 1)
        if self.view.selected_index ~= old_index and self.view.selected_index <= #self.filtered_games then
            self.view.selected_game = self.filtered_games[self.view.selected_index]
        end
        if self.view.selected_index < self.view.scroll_offset then
            self.view.scroll_offset = self.view.selected_index
        end
    elseif key == 'down' or key == 's' then
        local old_index = self.view.selected_index
        self.view.selected_index = math.min(#self.filtered_games, self.view.selected_index + 1)
        if self.view.selected_index ~= old_index and self.view.selected_index <= #self.filtered_games then
            self.view.selected_game = self.filtered_games[self.view.selected_index]
        end
        local visible_games = self.view:getVisibleGameCount(self.viewport and self.viewport.height or 600)
        if self.view.selected_index >= self.view.scroll_offset + visible_games then
            self.view.scroll_offset = self.view.selected_index - visible_games + 1
        end
    elseif key == 'return' or key == 'space' then
        result_event = self:selectGame() -- selectGame now returns the event
    elseif key == 'tab' then
        self.view.detail_panel_open = not self.view.detail_panel_open
        if self.view.detail_panel_open and self.view.selected_index <= #self.filtered_games then
            self.view.selected_game = self.filtered_games[self.view.selected_index]
        end
    elseif key == 'escape' then
        if self.view.detail_panel_open then
            self.view.detail_panel_open = false
        else
            result_event = { type = "close_window" } -- Signal window close
        end
    elseif key >= '1' and key <= '9' or key == '0' then
        local filters = {"all", "action", "puzzle", "arcade", "locked", "unlocked", "affordable", "completed", "easy", "medium", "hard"}
        local index = key == '0' and 10 or tonumber(key)
        if index <= #filters and filters[index] then
            self:updateFilter(filters[index])
        else
            handled = false
        end
    else
        handled = false
    end

    -- Determine what to return
    if result_event then
        return result_event -- Return the specific event (launch or close)
    elseif handled then
        return { type = "content_interaction" } -- Return generic interaction if handled
    else
        return false -- Return false if not handled
    end
end

function LauncherState:selectGame()
    if self.view.selected_index > #self.filtered_games then return nil end

    local selected_game = self.filtered_games[self.view.selected_index]
    if not selected_game then return nil end

    return self:launchGame(selected_game.id) -- Return the event from launchGame
end

function LauncherState:launchGame(game_id)
    local game_data = self.game_data:getGame(game_id)
    if not game_data then return nil end -- Return nil if game not found

    -- Publish game_launch_requested event
    if self.event_bus then
        self.event_bus:publish('game_launch_requested', game_id)
    end

    local is_unlocked = self.player_data:isGameUnlocked(game_id)

    if not is_unlocked then
        -- showUnlockPrompt might internally call launchGame again after unlock,
        -- or we can handle the return value here. Let's assume it handles it
        -- and might return a launch event if successful.
        return self:showUnlockPrompt(game_data) -- showUnlockPrompt needs modification
    else
        -- Load variant data for the game (to get actual variant name)
        local variant_data = self:loadVariantData(game_id)

        -- Return an event for DesktopState to handle, including variant
        return { type = "event", name = "launch_minigame", game_data = game_data, variant = variant_data }
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
    love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), message, "error")
        return nil -- Indicate failure or no action needed
    end

    local buttons = {"Unlock", "Cancel"}
    local pressed = love.window.showMessageBox(Strings.get('messages.info_title', 'Information'), message, buttons, "info")

    if pressed == 1 then
        if self.player_data:spendTokens(cost) then
            self.player_data:unlockGame(game_data.id)
            self.save_manager.save(self.player_data)
            print("Unlocked: " .. game_data.display_name)

            -- Publish game_purchased event
            if self.event_bus then
                self.event_bus:publish('game_purchased', game_data.id, cost)
            end

            -- Publish game_unlocked event
            if self.event_bus then
                self.event_bus:publish('game_unlocked', game_data.id)
            end

            -- Load variant data for the game (to get actual variant name)
            local variant_data = self:loadVariantData(game_data.id)

            -- Return the launch event instead of switching state
            return { type = "event", name = "launch_minigame", game_data = game_data, variant = variant_data }
        else
            -- Publish purchase_failed event
            if self.event_bus then
                self.event_bus:publish('purchase_failed', game_data.id, 'insufficient_tokens')
            end
        end
    end
    return nil -- Indicate cancellation or failure
end

function LauncherState:showGameDetails(game_id)
    self.view.selected_game = self.game_data:getGame(game_id)
    self.view.detail_panel_open = true

    -- Publish game_details_viewed event
    if self.event_bus then
        self.event_bus:publish('game_details_viewed', game_id)
    end
end

function LauncherState:mousepressed(x, y, button)
    -- x, y are ALREADY LOCAL content coordinates from DesktopState
    if not self.viewport then return false end

    -- Check if click is outside the logical content bounds (0,0 to width, height)
    -- This check might be redundant if DesktopState already clips, but adds safety.
    if x < 0 or x > self.viewport.width or y < 0 or y > self.viewport.height then
        return false
    end

    -- Delegate directly to view with the LOCAL coordinates
    local view_event = self.view:mousepressed(x, y, button, self.filtered_games, self.viewport.width, self.viewport.height)

    -- Handle the view event as before...
    if view_event then
        if view_event.name == "filter_changed" then
            self:updateFilter(view_event.category)
            return { type = "content_interaction" } -- Indicate interaction
        elseif view_event.name == "launch_game" then
            return self:launchGame(view_event.id) -- Bubble up the event object
        elseif view_event.name == "game_selected" then
            print("Selected game: " .. view_event.game.display_name)
            return { type = "content_interaction" } -- Indicate interaction
        end
    end

    return false -- No specific view element handled it
end

function LauncherState:mousemoved(x, y, dx, dy)
    if not self.viewport then return end
    if self.view and self.view.mousemoved then
        return self.view:mousemoved(x, y, dx, dy)
    end
end

function LauncherState:mousereleased(x, y, button)
    if not self.viewport then return end
    if self.view and self.view.mousereleased then
        return self.view:mousereleased(x, y, button)
    end
end

function LauncherState:mousemoved(x, y, dx, dy)
    if not self.viewport then return end
    if self.view and self.view.mousemoved then
        local ok = pcall(self.view.mousemoved, self.view, x, y, dx, dy)
        if not ok then return end
    end
end

function LauncherState:mousereleased(x, y, button)
    if not self.viewport then return end
    if self.view and self.view.mousereleased then
        pcall(self.view.mousereleased, self.view, x, y, button)
        return { type = 'content_interaction' }
    end
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