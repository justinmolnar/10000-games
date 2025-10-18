-- vm_manager.lua: Manages virtual machines for automated game playing

local Object = require('class')
local VMManager = Object:extend('VMManager')

function VMManager:init()
    self.vm_slots = {}
    self.total_tokens_per_minute = 0
    self.max_slots = 10  -- MVP limit
end

function VMManager:initialize(player_data)
    self.vm_slots = {}
    
    -- Create slots based on player's purchased VM count
    for i = 1, player_data.vm_slots do
        table.insert(self.vm_slots, {
            slot_index = i,
            active = false,
            assigned_game_id = nil,
            time_remaining = 0,
            cycle_time = 60,
            auto_play_power = 0,
            tokens_per_cycle = 0,
            is_auto_completed = false
        })
    end
    
    -- Ensure active_vms table exists
    if not player_data.active_vms then
        player_data.active_vms = {}
    end
    
    -- Restore any active VM assignments from player data
    for slot_index, vm_data in pairs(player_data.active_vms) do
        if self.vm_slots[slot_index] and vm_data.game_id then
            local slot = self.vm_slots[slot_index]
            slot.active = true
            slot.assigned_game_id = vm_data.game_id
            slot.time_remaining = vm_data.time_remaining or 60
            -- Power will be recalculated on first update
            print(string.format("Restored VM %d: %s (%.1fs remaining)", slot_index, vm_data.game_id, slot.time_remaining))
        end
    end
    
    print("VM Manager initialized with " .. #self.vm_slots .. " slots")
end

function VMManager:update(dt, player_data, game_data)
    local tokens_generated = 0
    
    for _, slot in ipairs(self.vm_slots) do
        if slot.active and slot.assigned_game_id then
            -- Recalculate power using best performance if it wasn't loaded
            if slot.auto_play_power == 0 then
                local perf = player_data:getGamePerformance(slot.assigned_game_id)
                if perf then
                    local cpu_bonus = 1 + (player_data.upgrades.cpu_speed * 0.1)
                    local overclock_bonus = 1 + (player_data.upgrades.overclock * 0.05)
                    slot.auto_play_power = perf.best_score * overclock_bonus
                    slot.tokens_per_cycle = slot.auto_play_power
                    slot.cycle_time = 60 / cpu_bonus
                end
            end
            
            -- Tick down timer
            slot.time_remaining = slot.time_remaining - dt
            
            -- Cycle complete
            if slot.time_remaining <= 0 then
                -- Award tokens
                tokens_generated = tokens_generated + slot.tokens_per_cycle
                print(string.format("VM %d completed cycle! +%.1f tokens", slot.slot_index, slot.tokens_per_cycle))
                
                -- Reset timer
                slot.time_remaining = slot.cycle_time
                
                -- Update save data
                player_data.active_vms[slot.slot_index] = {
                    game_id = slot.assigned_game_id,
                    time_remaining = slot.time_remaining
                }
            end
        end
    end
    
    -- Award tokens to player
    if tokens_generated > 0 then
        player_data:addTokens(tokens_generated)
        print(string.format("Total tokens generated this cycle: %.1f (Total tokens: %d)", tokens_generated, player_data.tokens))
    end
    
    -- Calculate total tokens per minute
    self:calculateTokensPerMinute()
end

function VMManager:assignGame(slot_index, game_id, game_data, player_data)
    if slot_index < 1 or slot_index > #self.vm_slots then
        return false, "Invalid slot index"
    end
    
    local slot = self.vm_slots[slot_index]
    local game = game_data:getGame(game_id)
    
    if not game then
        return false, "Game not found"
    end
    
    -- Check if game is already assigned to another VM
    if self:isGameAssigned(game_id) then
        return false, "Game already assigned to another VM"
    end
    
    -- Check if game is completed
    local perf = player_data:getGamePerformance(game_id)
    if not perf then
        return false, "Game not completed yet"
    end
    
    -- Use the player's actual best performance for VM power (for now)
    local vm_power = perf.best_score
    
    -- Apply CPU upgrade bonus to cycle time
    local cpu_bonus = 1 + (player_data.upgrades.cpu_speed * 0.1)
    local cycle_time = 60 / cpu_bonus
    
    -- Apply overclock bonus to power
    local overclock_bonus = 1 + (player_data.upgrades.overclock * 0.05)
    vm_power = vm_power * overclock_bonus
    
    -- Assign to slot
    slot.active = true
    slot.assigned_game_id = game_id
    slot.time_remaining = cycle_time
    slot.cycle_time = cycle_time
    slot.auto_play_power = vm_power
    slot.tokens_per_cycle = vm_power
    slot.is_auto_completed = perf.auto_completed or false
    
    -- Save to player data
    if not player_data.active_vms then
        player_data.active_vms = {}
    end
    
    player_data.active_vms[slot.slot_index] = {
        game_id = game_id,
        time_remaining = slot.time_remaining
    }
    
    print(string.format("Assigned %s to VM slot %d (Power: %.1f, Cycle: %.1fs)", 
        game.display_name, slot_index, vm_power, cycle_time))
    
    return true
end

function VMManager:removeGame(slot_index, player_data)
    if slot_index < 1 or slot_index > #self.vm_slots then
        return false
    end
    
    local slot = self.vm_slots[slot_index]
    slot.active = false
    slot.assigned_game_id = nil
    slot.time_remaining = 0
    slot.auto_play_power = 0
    slot.tokens_per_cycle = 0
    
    -- Remove from player data
    player_data.active_vms[slot_index] = nil
    
    return true
end

function VMManager:purchaseVM(player_data)
    if #self.vm_slots >= self.max_slots then
        return false, "Maximum VM slots reached"
    end
    
    local cost = self:getVMCost(#self.vm_slots)
    
    if not player_data:hasTokens(cost) then
        return false, "Not enough tokens"
    end
    
    if player_data:spendTokens(cost) then
        player_data.vm_slots = player_data.vm_slots + 1
        
        -- Add new slot
        table.insert(self.vm_slots, {
            slot_index = #self.vm_slots + 1,
            active = false,
            assigned_game_id = nil,
            time_remaining = 0,
            cycle_time = 60,
            auto_play_power = 0,
            tokens_per_cycle = 0,
            is_auto_completed = false
        })
        
        print("Purchased VM slot " .. #self.vm_slots)
        return true
    end
    
    return false, "Purchase failed"
end

function VMManager:getVMCost(current_count)
    -- Exponential cost scaling
    local base_cost = 1000
    return math.floor(base_cost * math.pow(2, current_count))
end

function VMManager:calculateTokensPerMinute()
    local total = 0
    
    for _, slot in ipairs(self.vm_slots) do
        if slot.active then
            -- Tokens per minute = tokens per cycle * cycles per minute
            local cycles_per_minute = 60 / slot.cycle_time
            total = total + (slot.tokens_per_cycle * cycles_per_minute)
        end
    end
    
    self.total_tokens_per_minute = total
    return total
end

function VMManager:getOptimalGameForVM(game_list, player_data)
    -- Helper function to suggest best game for automation
    local best_game = nil
    local best_rate = 0
    
    for _, game in ipairs(game_list) do
        local perf = player_data:getGamePerformance(game.id)
        if perf and not self:isGameAssigned(game.id) then
            local auto_power = game.formula_function(game.auto_play_performance)
            if auto_power > best_rate then
                best_rate = auto_power
                best_game = game
            end
        end
    end
    
    return best_game
end

function VMManager:isGameAssigned(game_id)
    for _, slot in ipairs(self.vm_slots) do
        if slot.active and slot.assigned_game_id == game_id then
            return true
        end
    end
    return false
end

function VMManager:getSlotCount()
    return #self.vm_slots
end

function VMManager:getActiveSlotCount()
    local count = 0
    for _, slot in ipairs(self.vm_slots) do
        if slot.active then
            count = count + 1
        end
    end
    return count
end

return VMManager