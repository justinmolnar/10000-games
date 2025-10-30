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
    self.filtered_demos = {}
    self.viewport = nil -- Initialize viewport
end

function VMManagerState:enter()
    -- Reset view state
    self.view.selected_slot = nil
    self.view.game_selection_open = false
    self.view.demo_selection_open = false
    self.view.scroll_offset = 0

    -- Get all completed games for assignment (state still manages this list)
    self:updateGameList()
    self:updateDemoList()
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

        -- No need to recalculate cycle times anymore - VMs use demo playback
        -- Just save and recalculate TPM
        self.vm_manager:calculateTokensPerMinute()
        self.save_manager.save(self.player_data)
        return true
    end

    print("Failed to purchase upgrade: " .. upgrade_type .. ". Needed " .. cost .. ", had " .. self.player_data.tokens)
    return false
end

function VMManagerState:updateGameList()
    self.filtered_games = {}

    -- Only show completed games (games with at least one demo)
    local game_ids_with_demos = {}
    for demo_id, demo in pairs(self.player_data.demos or {}) do
        game_ids_with_demos[demo.game_id] = true
    end

    for game_id, _ in pairs(game_ids_with_demos) do
        local game_data = self.game_data:getGame(game_id)
        if game_data then
            table.insert(self.filtered_games, game_data)
        end
    end

    -- Sort by name (alphabetical)
    table.sort(self.filtered_games, function(a, b)
        return a.display_name < b.display_name
    end)
end

function VMManagerState:updateDemoList(game_id)
    self.filtered_demos = {}

    -- Use provided game_id or try to get from selected slot
    local target_game_id = game_id
    if not target_game_id and self.view.selected_slot then
        local slot = self.vm_manager:getSlot(self.view.selected_slot)
        if slot and slot.assigned_game_id then
            target_game_id = slot.assigned_game_id
        end
    end

    if not target_game_id then
        return
    end

    -- Get all demos for this game
    local demos = self.player_data:getDemosForGame(target_game_id)
    self.filtered_demos = demos or {}
    print("[VMManagerState] updateDemoList for " .. target_game_id .. ": found " .. #self.filtered_demos .. " demos")
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
        if self.view.demo_selection_open then
            -- Close demo selection modal first
            self.view.demo_selection_open = false
            self.view.game_selection_open = true
            return true -- Handled
        elseif self.view.game_selection_open then
            -- Close game selection modal
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
        -- Game selected - now show demo selection
        self.view.game_selection_open = false
        self.view.demo_selection_open = true
        self.view.selected_game_id = event.game_id
        self:updateDemoList(event.game_id)  -- Pass the game_id explicitly
    elseif event.name == "assign_demo" then
        self:assignDemoToSlot(event.demo_id, event.slot_index)
    elseif event.name == "remove_game" then
        self:removeGameFromSlot(event.slot_index)
    elseif event.name == "stop_vm" then
        self:stopVM(event.slot_index)
    elseif event.name == "start_vm" then
        self:startVM(event.slot_index)
    elseif event.name == "upgrade_speed" then
        self:upgradeVMSpeed(event.slot_index)
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
function VMManagerState:assignDemoToSlot(demo_id, slot_index)
    local demo = self.player_data:getDemo(demo_id)
    if not demo then
        print("Failed to assign demo: demo not found")
        return
    end

    local success, err = self.vm_manager:assignDemo(
        slot_index,
        demo.game_id,
        demo_id,
        self.game_data,
        self.player_data
    )

    if success then
        self.save_manager.save(self.player_data)
        self.vm_manager:calculateTokensPerMinute()
        -- Close modals
        self.view.demo_selection_open = false
        self.view.game_selection_open = false
        self.view.selected_slot = nil
        self.view.selected_game_id = nil
    else
        print("Failed to assign demo: " .. (err or "unknown error"))
        love.window.showMessageBox("Error", "Failed to assign demo: " .. (err or "unknown error"), "error")
    end
end

function VMManagerState:removeGameFromSlot(slot_index)
    local success = self.vm_manager:removeDemo(slot_index, self.player_data)
    if success then
        self.save_manager.save(self.player_data)
        print("Removed demo from VM slot " .. slot_index)
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

function VMManagerState:stopVM(slot_index)
    local success = self.vm_manager:stopVM(slot_index, self.player_data)
    if success then
        self.save_manager.save(self.player_data)
        print("Stopped VM slot " .. slot_index)
    end
end

function VMManagerState:startVM(slot_index)
    local success = self.vm_manager:startVM(slot_index, self.player_data, self.game_data)
    if success then
        self.save_manager.save(self.player_data)
        print("Started VM slot " .. slot_index)
    end
end

function VMManagerState:upgradeVMSpeed(slot_index)
    local success, new_speed = self.vm_manager:upgradeSpeed(slot_index, self.player_data)
    if success then
        self.save_manager.save(self.player_data)
        print("Upgraded VM " .. slot_index .. " speed to " .. new_speed .. "x")
    else
        print("Failed to upgrade VM speed (max level reached)")
    end
end

return VMManagerState