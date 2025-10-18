-- vm_manager.lua: Manages virtual machines for automated game playing

local Object = require('class')
local Config = require('src.config') -- Moved require to file scope
local VMManager = Object:extend('VMManager')

function VMManager:init()
    self.vm_slots = {}
    self.total_tokens_per_minute = 0
    self.max_slots = Config.vm_max_slots
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
            cycle_time = Config.vm_base_cycle_time, -- Use config
            auto_play_power = 0,
            tokens_per_cycle = 0,
            is_auto_completed = false
        })
    end

    if not player_data.active_vms then player_data.active_vms = {} end

    -- Restore active VM assignments
    for slot_index_str, vm_data in pairs(player_data.active_vms) do
         local slot_index = tonumber(slot_index_str) -- Keys from JSON might be strings
         if slot_index and self.vm_slots[slot_index] and vm_data.game_id then
            local slot = self.vm_slots[slot_index]
            slot.active = true
            slot.assigned_game_id = vm_data.game_id
            -- Ensure loaded time remaining isn't longer than current cycle time
            slot.cycle_time = Config.vm_base_cycle_time / (1 + (player_data.upgrades.cpu_speed * Config.vm_cpu_speed_bonus_per_level))
            slot.time_remaining = math.min(vm_data.time_remaining or slot.cycle_time, slot.cycle_time)
            -- Power will be recalculated on first update
            print(string.format("Restored VM %d: %s (%.1fs remaining / %.1fs cycle)", slot_index, vm_data.game_id, slot.time_remaining, slot.cycle_time))
        elseif slot_index then
             print("Warning: Could not restore VM slot " .. slot_index .. ", data missing or invalid.")
             -- Ensure invalid save data is cleared
             player_data.active_vms[slot_index_str] = nil
        end
    end

    print("VM Manager initialized with " .. #self.vm_slots .. " slots")
end


function VMManager:update(dt, player_data, game_data)
    local tokens_generated = 0

    for _, slot in ipairs(self.vm_slots) do
        if slot.active and slot.assigned_game_id then
            -- Recalculate power and cycle time using config values if they haven't been set
            local needs_recalculation = (slot.auto_play_power == 0 or slot.cycle_time == Config.vm_base_cycle_time)
             -- Also recalculate if upgrades changed
             local current_cpu_bonus = 1 + (player_data.upgrades.cpu_speed * Config.vm_cpu_speed_bonus_per_level)
             local current_oc_bonus = 1 + (player_data.upgrades.overclock * Config.vm_overclock_bonus_per_level)
             local calculated_cycle_time = Config.vm_base_cycle_time / current_cpu_bonus

             if math.abs(slot.cycle_time - calculated_cycle_time) > 0.01 then -- Check if cycle time needs update due to upgrades
                 needs_recalculation = true
             end

            if needs_recalculation then
                local perf = player_data:getGamePerformance(slot.assigned_game_id)
                if perf then
                    local overclock_bonus = 1 + (player_data.upgrades.overclock * Config.vm_overclock_bonus_per_level)
                    local cpu_bonus = 1 + (player_data.upgrades.cpu_speed * Config.vm_cpu_speed_bonus_per_level) -- Recalculate here too

                    slot.auto_play_power = perf.best_score * overclock_bonus -- Using best score for now
                    slot.tokens_per_cycle = slot.auto_play_power
                    slot.cycle_time = Config.vm_base_cycle_time / cpu_bonus
                    -- Adjust remaining time proportionally if cycle time changed significantly
                    -- Example: if old cycle was 60, new is 30, and 15s remained, new remaining should be 7.5s
                    -- slot.time_remaining = (slot.time_remaining / old_cycle_time) * slot.cycle_time
                    -- Simpler: just clamp remaining time to new cycle time
                    slot.time_remaining = math.min(slot.time_remaining, slot.cycle_time)
                else
                    print("Warning: Performance data missing for VM game " .. slot.assigned_game_id .. ". Deactivating slot.")
                    slot.active = false
                    player_data.active_vms[tostring(slot.slot_index)] = nil -- Clear from save (use string key)
                    goto next_slot -- Skip update for this slot
                end
            end

            -- Tick down timer
            slot.time_remaining = slot.time_remaining - dt

            -- Cycle complete
            if slot.time_remaining <= 0 then
                tokens_generated = tokens_generated + slot.tokens_per_cycle
                -- print(string.format("VM %d completed cycle! +%.1f tokens", slot.slot_index, slot.tokens_per_cycle))

                local time_over = -slot.time_remaining
                slot.time_remaining = slot.cycle_time - time_over

                -- Update save data immediately after cycle completion
                player_data.active_vms[tostring(slot.slot_index)] = { -- Use string key for JSON compatibility
                    game_id = slot.assigned_game_id,
                    time_remaining = slot.time_remaining
                }
            end
        end
        ::next_slot::
    end

    if tokens_generated > 0 then
        player_data:addTokens(tokens_generated)
        -- print(string.format("Total tokens generated this update: %.1f (Total tokens: %d)", tokens_generated, player_data.tokens))
    end

    self:calculateTokensPerMinute()
end


function VMManager:assignGame(slot_index, game_id, game_data, player_data)
    if slot_index < 1 or slot_index > #self.vm_slots then return false, "Invalid slot index" end

    local slot = self.vm_slots[slot_index]
    local game = game_data:getGame(game_id)

    if not game then return false, "Game not found" end
    if self:isGameAssigned(game_id) then return false, "Game already assigned" end
    local perf = player_data:getGamePerformance(game_id)
    if not perf then return false, "Game not completed yet" end

    local vm_power = perf.best_score
    local cpu_bonus = 1 + (player_data.upgrades.cpu_speed * Config.vm_cpu_speed_bonus_per_level)
    local cycle_time = Config.vm_base_cycle_time / cpu_bonus
    local overclock_bonus = 1 + (player_data.upgrades.overclock * Config.vm_overclock_bonus_per_level)
    vm_power = vm_power * overclock_bonus

    slot.active = true
    slot.assigned_game_id = game_id
    slot.time_remaining = cycle_time
    slot.cycle_time = cycle_time
    slot.auto_play_power = vm_power
    slot.tokens_per_cycle = vm_power
    slot.is_auto_completed = perf.auto_completed or false

    if not player_data.active_vms then player_data.active_vms = {} end
    player_data.active_vms[tostring(slot.slot_index)] = { game_id = game_id, time_remaining = slot.time_remaining } -- Use string key

    print(string.format("Assigned %s to VM slot %d (Power: %.1f, Cycle: %.1fs)",
        game.display_name, slot_index, vm_power, cycle_time))

    return true
end


function VMManager:removeGame(slot_index, player_data)
    if slot_index < 1 or slot_index > #self.vm_slots then return false end

    local slot = self.vm_slots[slot_index]
    slot.active = false
    slot.assigned_game_id = nil
    slot.time_remaining = 0
    slot.auto_play_power = 0
    slot.tokens_per_cycle = 0

    -- Remove from player data using string key
    if player_data.active_vms then
       player_data.active_vms[tostring(slot_index)] = nil
    end


    print("Removed game from VM slot " .. slot_index)
    -- Recalculate TPM after removal
    self:calculateTokensPerMinute()
    return true
end


function VMManager:purchaseVM(player_data)
    if #self.vm_slots >= self.max_slots then return false, "Maximum VM slots reached" end

    local cost = self:getVMCost(#self.vm_slots)

    if not player_data:hasTokens(cost) then return false, "Not enough tokens (" .. cost .. " needed)" end

    if player_data:spendTokens(cost) then
        -- Increment player data count *before* adding the slot
        player_data.vm_slots = player_data.vm_slots + 1
        local new_slot_index = player_data.vm_slots -- Should match the new count

        table.insert(self.vm_slots, {
            slot_index = new_slot_index,
            active = false,
            assigned_game_id = nil,
            time_remaining = 0,
            cycle_time = Config.vm_base_cycle_time,
            auto_play_power = 0,
            tokens_per_cycle = 0,
            is_auto_completed = false
        })

        print("Purchased VM slot " .. new_slot_index .. " for " .. cost .. " tokens")
        return true
    end

    return false, "Purchase failed (unknown reason)"
end


function VMManager:getVMCost(current_count)
    -- Cost applies to the *next* slot purchase. If count is 1 (base slot), cost is for slot #2.
    local effective_count = math.max(0, current_count - 1)
    return math.floor(Config.vm_base_cost * math.pow(Config.vm_cost_exponent, effective_count))
end


function VMManager:calculateTokensPerMinute()
    local total = 0
    for _, slot in ipairs(self.vm_slots) do
        if slot.active and slot.cycle_time > 0 then -- Prevent division by zero
            local cycles_per_minute = 60 / slot.cycle_time
            total = total + (slot.tokens_per_cycle * cycles_per_minute)
        end
    end
    self.total_tokens_per_minute = total
    return total
end


function VMManager:getOptimalGameForVM(game_list, player_data)
    -- Helper to suggest best *unassigned* completed game for automation
    local best_game = nil
    local best_rate = -1 -- Start below 0 in case all games have 0 power

    for _, game in ipairs(game_list) do
        local perf = player_data:getGamePerformance(game.id)
        if perf and not self:isGameAssigned(game.id) then
            -- Calculate potential auto-play power *with* overclock bonus
            local overclock_bonus = 1 + (player_data.upgrades.overclock * Config.vm_overclock_bonus_per_level)
            local potential_power = perf.best_score * overclock_bonus
            -- Calculate potential rate (power / cycle_time * 60)
             local cpu_bonus = 1 + (player_data.upgrades.cpu_speed * Config.vm_cpu_speed_bonus_per_level)
             local potential_cycle_time = Config.vm_base_cycle_time / cpu_bonus
             local potential_rate = potential_power * (60 / potential_cycle_time)

            if potential_rate > best_rate then
                best_rate = potential_rate
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
        if slot.active then count = count + 1 end
    end
    return count
end

return VMManager