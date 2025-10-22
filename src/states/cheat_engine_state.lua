-- src/states/cheat_engine_state.lua
local Object = require('class')
local Strings = require('src.utils.strings')
local CheatEngineView = require('src.views.cheat_engine_view')
local CheatEngineState = Object:extend('CheatEngineState')

function CheatEngineState:init(player_data, game_data, state_machine, save_manager, cheat_system, di)
    self.player_data = player_data
    self.game_data = game_data
    self.state_machine = state_machine -- Keep for launching minigame state
    self.save_manager = save_manager
    self.cheat_system = cheat_system -- Injected dependency
    self.di = di
    self.event_bus = di and di.eventBus -- Store event bus from DI

    self.view = CheatEngineView:new(self, di)

    self.all_games = {} -- Will hold all games, including locked
    self.scroll_offset = 1
    self.selected_game_id = nil
    self.selected_game = nil

    -- This now holds the *dynamic cheat data* for the selected game
    -- e.g. { id="speed", name="Speed", current_level=1, max_level=5, cost=1200, value=0.15 }
    self.available_cheats = {}
    self.cheat_scroll_offset = 0 -- Scroll position for cheat list

    self.viewport = nil -- Initialize viewport
end

function CheatEngineState:setViewport(x, y, width, height)
    self.viewport = {x = x, y = y, width = width, height = height}
    self.view:updateLayout(width, height) -- Tell view to adjust layout
end


function CheatEngineState:enter()
    -- Load ALL games from game_data
    self.all_games = self.game_data:getAllGames()

    -- Sort by ID with natural number sorting
    table.sort(self.all_games, function(a, b)
        local a_base, a_num = a.id:match("^(.-)_(%d+)$")
        local b_base, b_num = b.id:match("^(.-)_(%d+)$")
        if a_base and b_base and a_num and b_num then
            if a_base == b_base then
                return tonumber(a_num) < tonumber(b_num)
            else
                return a_base < b_base
            end
        end
        return a.id < b.id
    end)

    -- Select the first game by default if list is not empty
    if #self.all_games > 0 then
        self.selected_game_id = self.all_games[1].id
        self.selected_game = self.all_games[1]
        self:buildAvailableCheats()
        self.scroll_offset = 1
        self.cheat_scroll_offset = 0
    else
        self:resetSelection()
    end

    print("CheatEngine loaded " .. #self.all_games .. " games")
end

function CheatEngineState:updateGameList()
    self.all_games = self.game_data:getAllGames()
    -- Sort by id with natural number sorting
    table.sort(self.all_games, function(a, b)
        local a_base, a_num = a.id:match("^(.-)_(%d+)$")
        local b_base, b_num = b.id:match("^(.-)_(%d+)$")
        if a_base and b_base and a_num and b_num then
            if a_base == b_base then return tonumber(a_num) < tonumber(b_num)
            else return a_base < b_base end
        end
        return a.id < b.id
    end)
end

function CheatEngineState:resetSelection()
    self.selected_game_id = nil
    self.selected_game = nil
    self.available_cheats = {} -- Clear the available cheats
    self.cheat_scroll_offset = 0
end

function CheatEngineState:update(dt)
    if not self.viewport then return end

    -- Delegate to view with properly translated coordinates
    self.view:update(dt, self.all_games, self.selected_game_id, self.available_cheats, self.viewport.width, self.viewport.height)
end

function CheatEngineState:draw()
    if not self.viewport then return end
    -- REMOVED push/translate/scissor/pop
    self.view:drawWindowed(
        self.all_games,
        self.selected_game_id,
        self.available_cheats,
        self.player_data,
        self.viewport.width,
        self.viewport.height,
        self.scroll_offset,
        self.cheat_scroll_offset
    )
    -- REMOVED setScissor/pop
end


function CheatEngineState:keypressed(key)
    local result_event = nil
    local handled = true -- Assume handled

    if key == 'escape' then
        result_event = { type = "close_window" }
    elseif key == 'up' then
        local current_idx = -1
        for i, g in ipairs(self.all_games) do if g.id == self.selected_game_id then current_idx = i; break end end
        if current_idx > 1 then
            local prev_game = self.all_games[current_idx - 1]
            self.selected_game_id = prev_game.id
            self.selected_game = prev_game
            self:buildAvailableCheats()
            if current_idx - 1 < self.scroll_offset then self.scroll_offset = current_idx - 1 end
        end
    elseif key == 'down' then
        local current_idx = -1
        for i, g in ipairs(self.all_games) do if g.id == self.selected_game_id then current_idx = i; break end end
        if current_idx > 0 and current_idx < #self.all_games then
            local next_game = self.all_games[current_idx + 1]
            self.selected_game_id = next_game.id
            self.selected_game = next_game
            self:buildAvailableCheats()
            local visible_items = self.view:getVisibleGameCount(self.viewport and self.viewport.height or 600)
            if current_idx + 1 >= self.scroll_offset + visible_items then
                 self.scroll_offset = current_idx + 1 - visible_items + 1
            end
        elseif current_idx == -1 and #self.all_games > 0 then
             self.selected_game_id = self.all_games[1].id
             self.selected_game = self.all_games[1]
             self:buildAvailableCheats()
        end
    elseif key == 'return' then -- Launch selected game
        result_event = self:launchGame() -- launchGame now returns the event object or nil
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


function CheatEngineState:mousepressed(x, y, button)
    -- x, y are ALREADY LOCAL content coordinates from DesktopState
    if not self.viewport then return false end

    -- Check if click is outside the logical content bounds (0,0 to width, height)
    if x < 0 or x > self.viewport.width or y < 0 or y > self.viewport.height then
        return false
    end

    -- Delegate directly to view with the LOCAL coordinates
    local event = self.view:mousepressed(x, y, button, self.all_games, self.selected_game_id, self.available_cheats, self.viewport.width, self.viewport.height)
    if not event then return false end

    local result_event = nil -- To store event to bubble up

    -- Handle view events as before...
    if event.name == "select_game" then
        self.selected_game_id = event.id
        self.selected_game = self.game_data:getGame(event.id)
        self:buildAvailableCheats()
        self.cheat_scroll_offset = 0
        result_event = { type = "content_interaction" }

    elseif event.name == "unlock_cheat_engine" then
        self:unlockCheatEngine()
        result_event = { type = "content_interaction" }

    elseif event.name == "purchase_cheat" then
        self:purchaseCheat(event.id)
        result_event = { type = "content_interaction" }

    elseif event.name == "launch_game" then
        result_event = self:launchGame() -- launchGame now returns the event object or nil
    end

    return result_event -- Return the event object or generic interaction signal
end

function CheatEngineState:mousemoved(x, y, dx, dy)
    if not self.viewport then return end
    -- x, y are already local content coordinates from DesktopState
    if self.view and self.view.mousemoved then
        local ok, ev = pcall(self.view.mousemoved, self.view, x, y, dx, dy)
        if ok and ev and ev.name == 'content_interaction' then
            return { type = 'content_interaction' }
        end
    end
end

function CheatEngineState:mousereleased(x, y, button)
    if not self.viewport then return end
    if self.view and self.view.mousereleased then
        pcall(self.view.mousereleased, self.view, x, y, button)
        return { type = 'content_interaction' }
    end
end

-- Calculates the scaled cost for a base cost and game
function CheatEngineState:getScaledCost(base_cost)
    if not self.selected_game then return 999999 end

    local exponent = self.selected_game.cheat_cost_exponent or 1.15
    local diff_level = self.selected_game.difficulty_level or 1

    -- Cost = Base * (Exponent ^ (Difficulty - 1))
    return math.floor(base_cost * (exponent ^ (diff_level - 1)))
end

-- Calculates the cost for the *next level* of a cheat
function CheatEngineState:getCheatLevelCost(cheat_def, current_level)
    -- Use exponential scaling for cheat levels: Cost = ScaledBaseCost * (2 ^ CurrentLevel)
    local scaled_base_cost = self:getScaledCost(cheat_def.base_cost)
    return math.floor(scaled_base_cost * (2 ^ current_level))
end

function CheatEngineState:buildAvailableCheats()
    self.available_cheats = {}
    if not self.selected_game or not self.selected_game.available_cheats then
        return
    end

    local all_defs = self.cheat_system:getCheatDefinitions()

    -- Using ipairs to maintain order from JSON if it matters
    for _, cheat_def_ref in ipairs(self.selected_game.available_cheats) do
        local static_def = all_defs[cheat_def_ref.id]
        if static_def then
            local current_level = self.player_data:getCheatLevel(self.selected_game_id, cheat_def_ref.id)
            local cost_for_next_level = self:getCheatLevelCost(cheat_def_ref, current_level)

            table.insert(self.available_cheats, {
                id = cheat_def_ref.id,
                name = static_def.name,
                description = static_def.description,
                is_fake = static_def.is_fake or false, -- Ensure boolean

                current_level = current_level,
                max_level = cheat_def_ref.max_level,
                cost_for_next = cost_for_next_level,
                value_per_level = cheat_def_ref.value_per_level
            })
        else
            print("Warning: Game " .. self.selected_game.id .. " listed unknown cheat_id: " .. cheat_def_ref.id)
        end
    end
end

function CheatEngineState:wheelmoved(x, y)
    if not self.viewport then return end

    local mx, my = love.mouse.getPosition()
    local view_x = self.viewport.x
    local view_y = self.viewport.y
     -- Check if mouse is within this window's viewport before delegating
     if mx >= view_x and mx <= view_x + self.viewport.width and
        my >= view_y and my <= view_y + self.viewport.height then
        -- Delegate scrolling to the view and update state scroll offsets
        local new_list_offset, new_cheat_offset = self.view:wheelmoved(x, y, #self.all_games, self.viewport.width, self.viewport.height)
        if new_list_offset then self.scroll_offset = new_list_offset end
        if new_cheat_offset then self.cheat_scroll_offset = new_cheat_offset end
     end
end

function CheatEngineState:unlockCheatEngine()
    if not self.selected_game then return end

    local cost = self:getScaledCost(self.selected_game.cheat_engine_base_cost or 999999) -- Add default cost

    if self.player_data:spendTokens(cost) then
        self.player_data:unlockCheatEngineForGame(self.selected_game_id)
        self.save_manager.save(self.player_data)
        self:buildAvailableCheats() -- Refresh cheat list

        -- Publish cheat_engine_unlocked event
        if self.event_bus then
            pcall(self.event_bus.publish, self.event_bus, 'cheat_engine_unlocked', self.selected_game_id, cost)
        end
    else
        print("Not enough tokens to unlock CE for " .. self.selected_game_id)
        love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), "Not enough tokens! Need " .. cost, "warning")
    end
end

function CheatEngineState:purchaseCheat(cheat_id)
    if not self.selected_game then return end

    -- Find the cheat def in the *current* available_cheats list
    local cheat_to_buy
    for _, cheat in ipairs(self.available_cheats) do
        if cheat.id == cheat_id then
            cheat_to_buy = cheat
            break
        end
    end

    if not cheat_to_buy then
        print("Error: Could not find cheat definition for " .. cheat_id)
        return
    end

    if cheat_to_buy.current_level >= cheat_to_buy.max_level then
        print("Cheat at max level")
        return
    end

    local cost = cheat_to_buy.cost_for_next
    local old_level = cheat_to_buy.current_level
    local new_level = old_level + 1

    if self.player_data:spendTokens(cost) then
        self.player_data:purchaseCheatLevel(self.selected_game_id, cheat_id)
        self.save_manager.save(self.player_data)
        self:buildAvailableCheats() -- Refresh list to show new level and cost

        -- Publish cheat_level_purchased event
        if self.event_bus then
            pcall(self.event_bus.publish, self.event_bus, 'cheat_level_purchased', self.selected_game_id, cheat_id, new_level, cost)
        end
    else
        print("Not enough tokens to buy cheat level")
        love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), "Not enough tokens! Need " .. cost, "warning")
    end
end

function CheatEngineState:launchGame()
    if not self.selected_game_id then
        love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), "No game selected.", "warning")
        return nil -- Return nil on failure
    end
    if not self.player_data:isGameUnlocked(self.selected_game_id) then
        print("Cannot launch a locked game via Cheat Engine")
        love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), "Game is locked. Unlock it in the Game Collection first.", "warning")
        return nil -- Return nil on failure
    end

    -- Prepare the final cheat values to be activated
    local cheats_to_activate = {}
    for _, cheat in ipairs(self.available_cheats) do
        if cheat.current_level > 0 and not cheat.is_fake then
            local total_value
            if type(cheat.value_per_level) == "number" then
                if cheat.id == "speed_modifier" then
                    total_value = math.max(0.1, 1.0 - (cheat.value_per_level * cheat.current_level)) -- Min 10% speed
                else -- performance_modifier
                    total_value = 1.0 + (cheat.value_per_level * cheat.current_level)
                end
            elseif type(cheat.value_per_level) == "table" then
                total_value = {}
                for key, val in pairs(cheat.value_per_level) do
                    total_value[key] = val * cheat.current_level
                end
            end
            if total_value ~= nil then cheats_to_activate[cheat.id] = total_value end
        end
    end

    -- Activate cheats in the system
    self.cheat_system:activateCheats(self.selected_game_id, cheats_to_activate)

    -- Publish cheats_applied_to_launch event
    if self.event_bus and next(cheats_to_activate) ~= nil then -- Only publish if cheats were actually applied
        pcall(self.event_bus.publish, self.event_bus, 'cheats_applied_to_launch', self.selected_game_id, cheats_to_activate)
    end

    -- Get the game data for the selected game
    local game_data = self.game_data:getGame(self.selected_game_id)
    if not game_data then
        love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), "Could not find game data to launch.", "error")
        return nil -- Return nil on failure
    end

    -- Return an event for DesktopState to handle
    return { type = "event", name = "launch_minigame", game_data = game_data }
end

return CheatEngineState