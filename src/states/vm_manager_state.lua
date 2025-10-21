-- vm_manager_state.lua: UI for managing virtual machines

local Object = require('class')
local VMManagerView = require('views.vm_manager_view')
local VMManagerState = Object:extend('VMManagerState')

function VMManagerState:init(vm_manager, player_data, game_data, state_machine, save_manager, di)
    self.vm_manager = vm_manager
    self.player_data = player_data
    self.game_data = game_data
    self.state_machine = state_machine
    self.save_manager = save_manager
    self.di = di

    -- Create the view instance
    self.view = VMManagerView:new(self, vm_manager, player_data, game_data, di)

    self.filtered_games = {}
    self.viewport = nil -- Initialize viewport
end

function VMManagerState:enter()
    -- Reset view state
    self.view.selected_slot = nil
    self.view.game_selection_open = false
    self.view.scroll_offset = 0

    -- Get all completed games for assignment (state still manages this list)
    self:updateGameList()
end

function VMManagerState:setViewport(x, y, width, height)
    self.viewport = {x = x, y = y, width = width, height = height}
    -- Adjust view layout constants if needed based on size
    self.view:updateLayout(width, height)
end


function VMManagerState:purchaseUpgrade(upgrade_type)
    local Config_ = (self.di and self.di.config) or {}
    local base_costs = Config_.upgrade_costs

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
    local cpu_bonus = 1 + (self.player_data.upgrades.cpu_speed * Config_.vm_cpu_speed_bonus_per_level)
    local overclock_bonus = 1 + (self.player_data.upgrades.overclock * Config_.vm_overclock_bonus_per_level)

        for _, slot in ipairs(self.vm_manager.vm_slots) do
            if slot.active and slot.assigned_game_id then
                local perf = self.player_data:getGamePerformance(slot.assigned_game_id)
                if perf then
                    -- Recalculate power with new overclock bonus
                    slot.auto_play_power = perf.best_score * overclock_bonus
                    slot.tokens_per_cycle = slot.auto_play_power

                    -- Recalculate cycle time with new CPU bonus
                    local old_cycle_time = slot.cycle_time -- Store old time for ratio calc
                    local new_cycle_time = Config_.vm_base_cycle_time / cpu_bonus

                    -- Adjust remaining time proportionally to maintain progress
                    if old_cycle_time > 0 then
                        local progress_ratio = (old_cycle_time - slot.time_remaining) / old_cycle_time
                        slot.time_remaining = new_cycle_time * (1 - progress_ratio)
                    else
                        slot.time_remaining = new_cycle_time -- Start fresh if old time was 0
                    end
                    -- Clamp remaining time just in case
                    slot.time_remaining = math.max(0, math.min(slot.time_remaining, new_cycle_time))

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

    -- Update view (handles hover states) - view handles coordinate translation internally
    if self.viewport then
       self.view:update(dt, self.viewport.width, self.viewport.height)
    end
end

function VMManagerState:draw()
    if not self.viewport then return end
    -- REMOVED push/translate/scissor/pop
    self.view:drawWindowed(self.filtered_games, self.viewport.width, self.viewport.height)
    -- REMOVED setScissor/pop
end

function VMManagerState:keypressed(key)
    if key == 'escape' then
        if self.view.game_selection_open then
            -- Close modal first
            self.view.game_selection_open = false
            self.view.selected_slot = nil
            return true -- Handled
        else
            -- Don't switch state, signal close instead
             return { type = "close_window" }
        end
    end
    -- Add keyboard navigation? (Up/Down in list, Enter to select, etc.) - Future enhancement
    return false
end


function VMManagerState:mousepressed(x, y, button)
     -- x, y are ALREADY LOCAL content coordinates from DesktopState
     if not self.viewport then return false end

    -- Check if click is outside the logical content bounds (0,0 to width, height)
    if x < 0 or x > self.viewport.width or y < 0 or y > self.viewport.height then
        return false
    end

    -- Delegate directly to view with the LOCAL coordinates
    local event = self.view:mousepressed(x, y, button, self.filtered_games, self.viewport.width, self.viewport.height)

    if not event then return false end

    -- Handle view events as before...
    if event.name == "assign_game" then
        self:assignGameToSlot(event.game_id, event.slot_index)
    elseif event.name == "remove_game" then
        self:removeGameFromSlot(event.slot_index)
    elseif event.name == "purchase_vm" then
        self:purchaseNewVM()
    elseif event.name == "purchase_upgrade" then
        self:purchaseUpgrade(event.upgrade_type)
    elseif event.name == "modal_opened" then
        self:updateGameList()
        print("Game selection opened for slot " .. event.slot_index)
    elseif event.name == "modal_closed" then
        print("Game selection closed")
    end

    -- Return generic interaction signal if view handled it
    return { type = "content_interaction" }
end

function VMManagerState:wheelmoved(x, y)
    if not self.viewport then return end

    local mx, my = love.mouse.getPosition()
    -- Check if mouse is within this window's viewport before delegating
    if mx >= self.viewport.x and mx <= self.viewport.x + self.viewport.width and
       my >= self.viewport.y and my <= self.viewport.y + self.viewport.height then
        -- Delegate scrolling to the view
        self.view:wheelmoved(x, y, #self.filtered_games, self.viewport.width, self.viewport.height)
    end
end

function VMManagerState:mousemoved(x, y, dx, dy)
    if not self.viewport then return end
    if x < 0 or y < 0 or x > self.viewport.width or y > self.viewport.height then return end
    if self.view and self.view.mousemoved then
        return self.view:mousemoved(x, y, dx, dy, self.filtered_games, self.viewport.width, self.viewport.height)
    end
end

function VMManagerState:mousereleased(x, y, button)
    if not self.viewport then return end
    if self.view and self.view.mousereleased then
        return self.view:mousereleased(x, y, button)
    end
end

-- Action handlers called by mousepressed based on view events
function VMManagerState:assignGameToSlot(game_id, slot_index)
    local success, err = self.vm_manager:assignGame(
        slot_index,
        game_id,
        self.game_data,
        self.player_data
    )

    if success then
        self.save_manager.save(self.player_data)
        -- Recalculate TPM might be needed if assignGame doesn't do it
        self.vm_manager:calculateTokensPerMinute()
    else
        print("Failed to assign game: " .. (err or "unknown error"))
        -- Maybe show message box? love.window.showMessageBox("Error", "Failed to assign: " .. err, "error")
    end
end

function VMManagerState:removeGameFromSlot(slot_index)
    local success = self.vm_manager:removeGame(slot_index, self.player_data)
    if success then
        self.save_manager.save(self.player_data)
        -- TPM recalculation happens in removeGame
        print("Removed game from VM slot " .. slot_index)
    end
end

function VMManagerState:purchaseNewVM()
    local success, err = self.vm_manager:purchaseVM(self.player_data)

    if success then
        self.save_manager.save(self.player_data)
        -- No TPM change needed yet
        print("Purchased new VM!")
        -- Force view layout update if needed
        if self.viewport then self.view:updateLayout(self.viewport.width, self.viewport.height) end
    else
        print("Failed to purchase VM: " .. (err or "unknown error"))
        love.window.showMessageBox("Purchase Failed", "Could not purchase VM: " .. (err or "Not enough tokens?"), "warning")
    end
end

return VMManagerState