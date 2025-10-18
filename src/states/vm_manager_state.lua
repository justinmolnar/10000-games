-- vm_manager_state.lua: UI for managing virtual machines

local Object = require('class')
local VMManagerView = require('views.vm_manager_view')
local VMManagerState = Object:extend('VMManagerState')

function VMManagerState:init(vm_manager, player_data, game_data, state_machine, save_manager)
    self.vm_manager = vm_manager
    self.player_data = player_data
    self.game_data = game_data
    self.state_machine = state_machine
    self.save_manager = save_manager

    -- Create the view instance
    self.view = VMManagerView:new(self, vm_manager, player_data, game_data)

    self.filtered_games = {}
end

function VMManagerState:enter()
    -- Reset view state
    self.view.selected_slot = nil
    self.view.game_selection_open = false
    self.view.scroll_offset = 0
    
    -- Get all completed games for assignment (state still manages this list)
    self:updateGameList()
end

function VMManagerState:updateGameList()
    self.filtered_games = {}
    
    -- Only show completed games
    for game_id, perf in pairs(self.player_data.game_performance) do
        local game_data = self.game_data:getGame(game_id)
        if game_data then
            table.insert(self.filtered_games, game_data)
        end
    end
    
    -- Sort by power (descending)
    table.sort(self.filtered_games, function(a, b)
        local perf_a = self.player_data:getGamePerformance(a.id)
        local perf_b = self.player_data:getGamePerformance(b.id)
        -- Handle case where performance might be nil briefly during loading
        return (perf_a and perf_a.best_score or 0) > (perf_b and perf_b.best_score or 0)
    end)
end

function VMManagerState:update(dt)
    -- Update VM manager (generates tokens)
    self.vm_manager:update(dt, self.player_data, self.game_data)
    
    -- Update view (handles hover states)
    self.view:update(dt)
end

function VMManagerState:draw()
    -- Delegate drawing to the view
    self.view:draw(self.filtered_games)
end

function VMManagerState:keypressed(key)
    if key == 'escape' then
        if self.view.game_selection_open then
            self.view.game_selection_open = false
            self.view.selected_slot = nil
        else
            self.state_machine:switch('desktop')
        end
    end
end

function VMManagerState:mousepressed(x, y, button)
    -- Delegate input handling to the view
    local event = self.view:mousepressed(x, y, button, self.filtered_games)

    if not event then return end

    -- Handle events returned by the view
    if event.name == "assign_game" then
        self:assignGameToSlot(event.game_id, event.slot_index)
    elseif event.name == "remove_game" then
        self:removeGameFromSlot(event.slot_index)
    elseif event.name == "purchase_vm" then
        self:purchaseNewVM()
    elseif event.name == "modal_opened" then
        -- Optional: Logic when modal opens (e.g., pause something)
        print("Game selection opened for slot " .. event.slot_index)
    elseif event.name == "modal_closed" then
        -- Optional: Logic when modal closes
        print("Game selection closed")
    end
end

function VMManagerState:wheelmoved(x, y)
    -- Delegate scrolling to the view
    self.view:wheelmoved(x, y)
end

-- Action handlers called by mousepressed based on view events
function VMManagerState:assignGameToSlot(game_id, slot_index)
    -- Slot index now comes from the event, not self.selected_slot
    local success, err = self.vm_manager:assignGame(
        slot_index, 
        game_id, 
        self.game_data, 
        self.player_data
    )
    
    if success then
        self.save_manager.save(self.player_data)
    else
        print("Failed to assign game: " .. (err or "unknown error"))
    end
end

function VMManagerState:removeGameFromSlot(slot_index)
    local success = self.vm_manager:removeGame(slot_index, self.player_data)
    if success then
        self.save_manager.save(self.player_data)
        print("Removed game from VM slot " .. slot_index)
    end
end

function VMManagerState:purchaseNewVM()
    local success, err = self.vm_manager:purchaseVM(self.player_data)
    
    if success then
        self.save_manager.save(self.player_data)
        print("Purchased new VM!")
    else
        print("Failed to purchase VM: " .. (err or "unknown error"))
        -- Optional: Show error message to user via the view
        -- self.view:showError("Purchase failed: " .. (err or "unknown error"))
    end
end

return VMManagerState