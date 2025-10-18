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

function VMManagerState:purchaseUpgrade(upgrade_type)
    local Config = require('src.config')
    local base_costs = Config.upgrade_costs
    
    if not base_costs[upgrade_type] then
        print("Error: Unknown upgrade type '" .. upgrade_type .. "'")
        return false
    end
    
    local current_level = self.player_data.upgrades[upgrade_type] or 0
    local cost = base_costs[upgrade_type] * (current_level + 1)
    
    if self.player_data:spendTokens(cost) then
        self.player_data.upgrades[upgrade_type] = current_level + 1
        print("Purchased upgrade: " .. upgrade_type .. " level " .. self.player_data.upgrades[upgrade_type] .. " for " .. cost .. " tokens")
        
        -- Recalculate VM values without resetting timers
        local cpu_bonus = 1 + (self.player_data.upgrades.cpu_speed * Config.vm_cpu_speed_bonus_per_level)
        local overclock_bonus = 1 + (self.player_data.upgrades.overclock * Config.vm_overclock_bonus_per_level)
        
        for _, slot in ipairs(self.vm_manager.vm_slots) do
            if slot.active and slot.assigned_game_id then
                local perf = self.player_data:getGamePerformance(slot.assigned_game_id)
                if perf then
                    -- Recalculate power with new overclock bonus
                    slot.auto_play_power = perf.best_score * overclock_bonus
                    slot.tokens_per_cycle = slot.auto_play_power
                    
                    -- Recalculate cycle time with new CPU bonus
                    local new_cycle_time = Config.vm_base_cycle_time / cpu_bonus
                    
                    -- Adjust remaining time proportionally to maintain progress
                    if slot.cycle_time > 0 then
                        local progress_ratio = (slot.cycle_time - slot.time_remaining) / slot.cycle_time
                        slot.time_remaining = new_cycle_time * (1 - progress_ratio)
                    else
                        slot.time_remaining = new_cycle_time
                    end
                    
                    slot.cycle_time = new_cycle_time
                end
            end
        end
        
        self.vm_manager:calculateTokensPerMinute()
        self.save_manager.save(self.player_data)
        return true
    end
    
    print("Failed to purchase upgrade: " .. upgrade_type .. ". Needed " .. cost .. ", had " .. self.player_data.tokens)
    return false
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
            -- Close modal first
            self.view.game_selection_open = false
            self.view.selected_slot = nil
            return true
        else
            -- Return to desktop
            self.state_machine:switch('desktop')
            return true
        end
    end
    return false
end

function VMManagerState:mousepressed(x, y, button)
    -- Delegate input handling to the view, ALWAYS pass filtered_games
    local event = self.view:mousepressed(x, y, button, self.filtered_games)
    
    if not event then return end
    
    -- Handle events returned by the view
    if event.name == "assign_game" then
        self:assignGameToSlot(event.game_id, event.slot_index)
    
    elseif event.name == "remove_game" then
        self:removeGameFromSlot(event.slot_index)
    
    elseif event.name == "purchase_vm" then
        self:purchaseNewVM()
    
    elseif event.name == "purchase_upgrade" then
        self:purchaseUpgrade(event.upgrade_type)
    
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