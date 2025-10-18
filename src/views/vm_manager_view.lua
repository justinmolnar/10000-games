-- vm_manager_view.lua: View class for VM Manager UI

local Object = require('class')
local VMManagerView = Object:extend('VMManagerView')

function VMManagerView:init(controller, vm_manager, player_data, game_data)
    self.controller = controller -- This is the vm_manager_state
    self.vm_manager = vm_manager
    self.player_data = player_data
    self.game_data = game_data
    
    self.selected_slot = nil
    self.game_selection_open = false
    self.scroll_offset = 0
    self.hovered_slot = nil
    self.hovered_upgrade = nil -- Add this
    
    -- Layout constants (can be adjusted)
    self.slot_width = 180
    self.slot_height = 120
    self.slot_padding = 10
    self.slot_cols = 5
    self.purchase_button_x = 10
    self.purchase_button_y = love.graphics.getHeight() - 60
    self.purchase_button_w = 200
    self.purchase_button_h = 40
    
    -- Upgrade button positions
    self.upgrade_x = 230
    self.upgrade_y = love.graphics.getHeight() - 60
    self.upgrade_w = 180
    self.upgrade_h = 40
    self.upgrade_spacing = 10
    
    self.modal_x = love.graphics.getWidth() / 2 - 200
    self.modal_y = 100
    self.modal_w = 400
    self.modal_h = love.graphics.getHeight() - 200
    self.modal_item_height = 40
end

function VMManagerView:update(dt)
    -- Update hovered slot based on mouse position
    local mx, my = love.mouse.getPosition()
    self.hovered_slot = self:getSlotAtPosition(mx, my)
    
    -- Update hovered upgrade
    self.hovered_upgrade = nil
    local upgrades = {"cpu_speed", "overclock"}
    for i, upgrade_type in ipairs(upgrades) do
        local bx = self.upgrade_x + (i - 1) * (self.upgrade_w + self.upgrade_spacing)
        local by = self.upgrade_y
        if mx >= bx and mx <= bx + self.upgrade_w and my >= by and my <= by + self.upgrade_h then
            self.hovered_upgrade = upgrade_type
            break
        end
    end
end

function VMManagerView:drawUpgradeButton(x, y, w, h, label, desc, level, cost, can_afford, hovered)
    -- Background
    if not can_afford then
        love.graphics.setColor(0.3, 0.3, 0.3)
    elseif hovered then
        love.graphics.setColor(0.35, 0.6, 0.35)
    else
        love.graphics.setColor(0, 0.5, 0)
    end
    love.graphics.rectangle('fill', x, y, w, h)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
    
    -- Text
    love.graphics.setColor(can_afford and {1, 1, 1} or {0.5, 0.5, 0.5})
    love.graphics.print(label .. " Lv." .. level, x + 5, y + 5, 0, 0.9, 0.9)
    love.graphics.print(desc, x + 5, y + 20, 0, 0.75, 0.75)
    
    -- Cost
    love.graphics.setColor(can_afford and {1, 1, 0} or {0.5, 0.5, 0})
    love.graphics.print(cost .. " tokens", x + w - 80, y + h - 18, 0, 0.8, 0.8)
end

function VMManagerView:draw(filtered_games)
    -- Draw main window background
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Title bar
    love.graphics.setColor(0, 0, 0.5)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), 30)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("VM Manager", 10, 8, 0, 1.2, 1.2)
    
    -- Token counter
    love.graphics.print("Tokens: " .. self.player_data.tokens, love.graphics.getWidth() - 200, 8, 0, 1.2, 1.2)
    
    -- Tokens per minute display
    self:drawTokensPerMinute(10, 50, self.vm_manager.total_tokens_per_minute)
    
    -- VM slots grid
    local slots = self.vm_manager.vm_slots
    for i, slot in ipairs(slots) do
        local col = (i - 1) % self.slot_cols
        local row = math.floor((i - 1) / self.slot_cols)
        local x = 10 + col * (self.slot_width + self.slot_padding)
        local y = 100 + row * (self.slot_height + self.slot_padding)
        
        -- Create context for view function (unchanged)
        local view_context = {
            game_data = self.game_data,
            player_data = self.player_data,
            vm_manager = self.vm_manager
        }
        
        self:drawVMSlot(x, y, self.slot_width, self.slot_height, slot, 
            i == self.selected_slot, i == self.hovered_slot, view_context)
    end
    
    -- Purchase VM button
    if #slots < self.vm_manager.max_slots then
        local cost = self.vm_manager:getVMCost(#slots)
        local can_afford = self.player_data:hasTokens(cost)
        self:drawPurchaseVMButton(self.purchase_button_x, self.purchase_button_y, cost, can_afford)
    end
    
    -- Upgrade buttons
    local Config = require('src.config')
    local upgrades = {
        {type = "cpu_speed", label = "CPU Speed", desc = "Faster cycles"},
        {type = "overclock", label = "Overclock", desc = "More power"}
    }
    
    for i, upgrade in ipairs(upgrades) do
        local bx = self.upgrade_x + (i - 1) * (self.upgrade_w + self.upgrade_spacing)
        local by = self.upgrade_y
        local current_level = self.player_data.upgrades[upgrade.type] or 0
        local cost = Config.upgrade_costs[upgrade.type] * (current_level + 1)
        local can_afford = self.player_data:hasTokens(cost)
        local is_hovered = (self.hovered_upgrade == upgrade.type)
        
        self:drawUpgradeButton(bx, by, self.upgrade_w, self.upgrade_h, 
            upgrade.label, upgrade.desc, current_level, cost, can_afford, is_hovered)
    end
    
    -- Game selection modal
    if self.game_selection_open then
        -- Create context for view function (unchanged)
        local view_context = {
            game_data = self.game_data,
            player_data = self.player_data,
            vm_manager = self.vm_manager
        }
        self:drawGameSelectionModal(filtered_games, self.scroll_offset, view_context)
    end
    
    -- Instructions
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Click empty slot to assign game | Click assigned game to remove | ESC to return", 
        10, love.graphics.getHeight() - 25, 0, 0.8, 0.8)
end

function VMManagerView:mousepressed(x, y, button, filtered_games)
    if button ~= 1 then return end
    
    -- Check game selection modal first
    if self.game_selection_open then
        -- Only check for game clicks if filtered_games exists
        if filtered_games and #filtered_games > 0 then
            local clicked_game = self:getGameAtPosition(x, y, filtered_games)
            if clicked_game then
                -- Check if game is already assigned (using vm_manager directly)
                if self.vm_manager:isGameAssigned(clicked_game.id) then
                    print("Game already in use by another VM!")
                    return nil
                end
                
                -- Close modal and return event
                self.game_selection_open = false
                local slot_to_assign = self.selected_slot
                self.selected_slot = nil
                return {name = "assign_game", slot_index = slot_to_assign, game_id = clicked_game.id}
            end
        end
        
        -- Check if click was outside the modal content area to close it
        if not (x >= self.modal_x and x <= self.modal_x + self.modal_w and y >= self.modal_y and y <= self.modal_y + self.modal_h) then
            self.game_selection_open = false
            self.selected_slot = nil
            return {name="modal_closed"}
        end
        
        return nil -- Clicked inside modal but not on a game
    end
    
    -- Check VM slots
    local clicked_slot_index = self:getSlotAtPosition(x, y)
    if clicked_slot_index then
        local slot = self.vm_manager.vm_slots[clicked_slot_index]
        if slot.active then
            -- Return remove event
            return {name = "remove_game", slot_index = clicked_slot_index}
        else
            -- Open game selection modal
            self.selected_slot = clicked_slot_index
            self.game_selection_open = true
            return {name = "modal_opened", slot_index = clicked_slot_index}
        end
    end
    
    -- Check upgrade buttons
    local Config = require('src.config')
    local upgrades = {"cpu_speed", "overclock"}
    for i, upgrade_type in ipairs(upgrades) do
        local bx = self.upgrade_x + (i - 1) * (self.upgrade_w + self.upgrade_spacing)
        local by = self.upgrade_y
        if x >= bx and x <= bx + self.upgrade_w and y >= by and y <= by + self.upgrade_h then
            local current_level = self.player_data.upgrades[upgrade_type] or 0
            local cost = Config.upgrade_costs[upgrade_type] * (current_level + 1)
            if self.player_data:hasTokens(cost) then
                return {name = "purchase_upgrade", upgrade_type = upgrade_type}
            end
        end
    end
    
    -- Check purchase button
    if self:isPurchaseButtonClicked(x, y) then
        return {name = "purchase_vm"}
    end
    
    return nil -- Clicked nothing
end

function VMManagerView:wheelmoved(x, y)
    if self.game_selection_open then
        -- Adjust scroll offset, ensuring it stays within bounds
        local items_in_list = #self.controller.filtered_games -- Need access to the state's filtered list
        local visible_items = math.floor((self.modal_h - 50) / self.modal_item_height)
        local max_scroll = math.max(0, items_in_list - visible_items)
        
        self.scroll_offset = math.max(0, math.min(max_scroll, self.scroll_offset - y))
    end
end

-- Helper functions moved from state
function VMManagerView:getSlotAtPosition(x, y)
    for i = 1, #self.vm_manager.vm_slots do
        local col = (i - 1) % self.slot_cols
        local row = math.floor((i - 1) / self.slot_cols)
        local sx = 10 + col * (self.slot_width + self.slot_padding)
        local sy = 100 + row * (self.slot_height + self.slot_padding)
        
        if x >= sx and x <= sx + self.slot_width and y >= sy and y <= sy + self.slot_height then
            return i
        end
    end
    return nil
end

function VMManagerView:getGameAtPosition(x, y, filtered_games)
    -- Check bounding box of the modal list area
    if x < self.modal_x + 10 or x > self.modal_x + self.modal_w - 10 or y < self.modal_y + 50 or y > self.modal_y + self.modal_h - 30 then
        return nil
    end
    
    local relative_y = y - (self.modal_y + 50)
    local index_in_view = math.floor(relative_y / self.modal_item_height)
    local actual_index = index_in_view + 1 + self.scroll_offset
    
    if actual_index >= 1 and actual_index <= #filtered_games then
        return filtered_games[actual_index]
    end
    
    return nil
end

function VMManagerView:isPurchaseButtonClicked(x, y)
    if #self.vm_manager.vm_slots >= self.vm_manager.max_slots then
        return false
    end
    
    return x >= self.purchase_button_x and x <= self.purchase_button_x + self.purchase_button_w and 
           y >= self.purchase_button_y and y <= self.purchase_button_y + self.purchase_button_h
end

-- Draw methods (previously static functions)
function VMManagerView:drawTokensPerMinute(x, y, rate)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Total Generation Rate:", x, y)
    love.graphics.setColor(rate > 0 and {0, 1, 0} or {0.5, 0.5, 0.5})
    love.graphics.print(string.format("%.1f tokens/minute", rate), x + 200, y, 0, 1.2, 1.2)
end

function VMManagerView:drawVMSlot(x, y, w, h, slot, selected, hovered, context)
    if selected then love.graphics.setColor(0.3, 0.3, 0.7)
    elseif hovered then love.graphics.setColor(0.35, 0.35, 0.35)
    else love.graphics.setColor(0.25, 0.25, 0.25) end
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
    
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("VM " .. slot.slot_index, x + 5, y + 5, 0, 0.8, 0.8)
    
    if slot.active and slot.assigned_game_id then
        local game_data = context.game_data:getGame(slot.assigned_game_id)
        if game_data then
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(game_data.display_name, x + 5, y + 25, 0, 0.85, 0.85)
            love.graphics.setColor(0, 1, 1)
            love.graphics.print("Power: " .. math.floor(slot.auto_play_power), x + 5, y + 45, 0, 0.8, 0.8)
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("+" .. math.floor(slot.tokens_per_cycle) .. " tokens", x + 5, y + 60, 0, 0.8, 0.8)
            
            local progress = 1 - (slot.time_remaining / slot.cycle_time)
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle('fill', x + 5, y + h - 25, w - 10, 15)
            love.graphics.setColor(0, 1, 0)
            love.graphics.rectangle('fill', x + 5, y + h - 25, (w - 10) * progress, 15)
            love.graphics.setColor(1, 1, 1)
            local time_text = string.format("%.1fs", slot.time_remaining)
            love.graphics.print(time_text, x + w/2 - 15, y + h - 23, 0, 0.8, 0.8)
            
            if slot.is_auto_completed then
                love.graphics.setColor(0.5, 0.5, 1)
                love.graphics.print("[AUTO]", x + w - 45, y + 5, 0, 0.7, 0.7)
            end
        end
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("Empty", x + w/2 - 20, y + h/2 - 10)
        love.graphics.print("Click to assign", x + w/2 - 45, y + h/2 + 10, 0, 0.8, 0.8)
    end
end

function VMManagerView:drawGameSelectionModal(games, scroll_offset, context)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle('fill', self.modal_x, self.modal_y, self.modal_w, self.modal_h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', self.modal_x, self.modal_y, self.modal_w, self.modal_h)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Select Game to Assign", self.modal_x + 10, self.modal_y + 10, 0, 1.2, 1.2)
    
    local visible_items = math.floor((self.modal_h - 50) / self.modal_item_height)
    local start_index = scroll_offset + 1
    local end_index = math.min(#games, start_index + visible_items - 1)
    
    for i = start_index, end_index do
        local game_data = games[i]
        local item_y = self.modal_y + 50 + (i - start_index) * self.modal_item_height
        local is_assigned = context.vm_manager:isGameAssigned(game_data.id)
        
        love.graphics.setColor(is_assigned and {0.15, 0.15, 0.15} or {0.25, 0.25, 0.25})
        love.graphics.rectangle('fill', self.modal_x + 10, item_y, self.modal_w - 20, self.modal_item_height - 2)
        
        love.graphics.setColor(is_assigned and {0.5, 0.5, 0.5} or {1, 1, 1})
        love.graphics.print(game_data.display_name, self.modal_x + 15, item_y + 5)
        
        local perf = context.player_data:getGamePerformance(game_data.id)
        if perf then
            love.graphics.setColor(is_assigned and {0.4, 0.4, 0.4} or {0, 1, 1})
            love.graphics.print("Power: " .. math.floor(perf.best_score), self.modal_x + 15, item_y + 20, 0, 0.8, 0.8)
            
            if is_assigned then
                love.graphics.setColor(1, 0, 0)
                love.graphics.print("[IN USE]", self.modal_x + self.modal_w - 80, item_y + 20, 0, 0.8, 0.8)
            else
                love.graphics.setColor(0.7, 0.7, 0.7)
                love.graphics.print(math.floor(perf.best_score) .. "/min", self.modal_x + self.modal_w - 80, item_y + 20, 0, 0.8, 0.8)
            end
        end
    end
    
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Click game to assign | Click outside or ESC to cancel", self.modal_x + 10, self.modal_y + self.modal_h - 25, 0, 0.8, 0.8)
end

function VMManagerView:drawPurchaseVMButton(x, y, cost, can_afford)
    love.graphics.setColor(can_afford and {0, 0.5, 0} or {0.3, 0.3, 0.3})
    love.graphics.rectangle('fill', x, y, self.purchase_button_w, self.purchase_button_h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, self.purchase_button_w, self.purchase_button_h)
    
    love.graphics.setColor(can_afford and {1, 1, 1} or {0.5, 0.5, 0.5})
    love.graphics.print("Purchase VM", x + 10, y + 5)
    love.graphics.print(cost .. " tokens", x + 10, y + 22, 0, 0.9, 0.9)
end

return VMManagerView