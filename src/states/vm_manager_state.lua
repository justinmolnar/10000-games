-- vm_manager_state.lua: UI for managing virtual machines

local Object = require('class')
local VMManagerState = Object:extend('VMManagerState')

function VMManagerState:init(context)
    self.context = context
    self.selected_slot = nil
    self.game_selection_open = false
    self.filtered_games = {}
    self.scroll_offset = 0
    self.hovered_slot = nil
end

function VMManagerState:enter()
    self.selected_slot = nil
    self.game_selection_open = false
    self.filtered_games = {}
    
    -- Get all completed games for assignment
    self:updateGameList()
end

function VMManagerState:updateGameList()
    self.filtered_games = {}
    
    -- Only show completed games
    for game_id, perf in pairs(self.context.player_data.game_performance) do
        local game_data = self.context.game_data:getGame(game_id)
        if game_data then
            table.insert(self.filtered_games, game_data)
        end
    end
    
    -- Sort by power (descending)
    table.sort(self.filtered_games, function(a, b)
        local perf_a = self.context.player_data:getGamePerformance(a.id)
        local perf_b = self.context.player_data:getGamePerformance(b.id)
        return perf_a.best_score > perf_b.best_score
    end)
end

function VMManagerState:update(dt)
    -- Update VM manager (generates tokens)
    self.context.vm_manager:update(dt, self.context.player_data, self.context.game_data)
    
    -- Update hovered slot
    local mx, my = love.mouse.getPosition()
    self.hovered_slot = self:getSlotAtPosition(mx, my)
end

function VMManagerState:draw()
    local VMManagerView = require('views.vm_manager_view')
    
    -- Draw main window
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Title bar
    love.graphics.setColor(0, 0, 0.5)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), 30)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("VM Manager", 10, 8, 0, 1.2, 1.2)
    
    -- Token counter
    love.graphics.print("Tokens: " .. self.context.player_data.tokens, love.graphics.getWidth() - 200, 8, 0, 1.2, 1.2)
    
    -- Tokens per minute display
    VMManagerView.drawTokensPerMinute(10, 50, self.context.vm_manager.total_tokens_per_minute)
    
    -- VM slots grid
    local slots = self.context.vm_manager.vm_slots
    local slot_width = 180
    local slot_height = 120
    local padding = 10
    local cols = 5
    
    for i, slot in ipairs(slots) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = 10 + col * (slot_width + padding)
        local y = 100 + row * (slot_height + padding)
        
        VMManagerView.drawVMSlot(x, y, slot_width, slot_height, slot, 
            i == self.selected_slot, i == self.hovered_slot, self.context)
    end
    
    -- Purchase VM button
    if #slots < self.context.vm_manager.max_slots then
        local cost = self.context.vm_manager:getVMCost(#slots)
        local can_afford = self.context.player_data:hasTokens(cost)
        VMManagerView.drawPurchaseVMButton(10, love.graphics.getHeight() - 60, cost, can_afford)
    end
    
    -- Game selection modal
    if self.game_selection_open then
        VMManagerView.drawGameSelectionModal(self.filtered_games, self.scroll_offset, self, self.context)
    end
    
    -- Instructions
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Click empty slot to assign game | Click assigned game to remove | ESC to return", 
        10, love.graphics.getHeight() - 25, 0, 0.8, 0.8)
end

function VMManagerState:keypressed(key)
    if key == 'escape' then
        if self.game_selection_open then
            self.game_selection_open = false
            self.selected_slot = nil
        else
            self.context.state_machine:switch('desktop')
        end
    end
end

function VMManagerState:mousepressed(x, y, button)
    if button ~= 1 then return end
    
    -- Check game selection modal
    if self.game_selection_open then
        local clicked_game = self:getGameAtPosition(x, y)
        if clicked_game then
            -- Check if game is already assigned
            if self.context.vm_manager:isGameAssigned(clicked_game.id) then
                print("Game already in use by another VM!")
                return
            end
            
            self:assignGameToSlot(clicked_game.id)
            self.game_selection_open = false
            self.selected_slot = nil
        end
        return
    end
    
    -- Check VM slots
    local clicked_slot = self:getSlotAtPosition(x, y)
    if clicked_slot then
        local slot = self.context.vm_manager.vm_slots[clicked_slot]
        
        if slot.active then
            -- Remove game
            self.context.vm_manager:removeGame(clicked_slot, self.context.player_data)
            self.context.save_manager.save(self.context.player_data)
        else
            -- Open game selection
            self.selected_slot = clicked_slot
            self.game_selection_open = true
        end
        return
    end
    
    -- Check purchase button
    if self:isPurchaseButtonClicked(x, y) then
        self:purchaseNewVM()
    end
end

function VMManagerState:wheelmoved(x, y)
    if self.game_selection_open then
        self.scroll_offset = math.max(0, self.scroll_offset - y)
    end
end

function VMManagerState:getSlotAtPosition(x, y)
    local slot_width = 180
    local slot_height = 120
    local padding = 10
    local cols = 5
    
    for i = 1, #self.context.vm_manager.vm_slots do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local sx = 10 + col * (slot_width + padding)
        local sy = 100 + row * (slot_height + padding)
        
        if x >= sx and x <= sx + slot_width and y >= sy and y <= sy + slot_height then
            return i
        end
    end
    
    return nil
end

function VMManagerState:getGameAtPosition(x, y)
    -- Check if clicking on game in selection modal
    local modal_x = love.graphics.getWidth() / 2 - 200
    local modal_y = 100
    local modal_w = 400
    local item_height = 40
    
    if x < modal_x or x > modal_x + modal_w or y < modal_y + 50 then
        return nil
    end
    
    local relative_y = y - (modal_y + 50)
    local index = math.floor(relative_y / item_height) + 1 + self.scroll_offset
    
    if index >= 1 and index <= #self.filtered_games then
        return self.filtered_games[index]
    end
    
    return nil
end

function VMManagerState:isPurchaseButtonClicked(x, y)
    if #self.context.vm_manager.vm_slots >= self.context.vm_manager.max_slots then
        return false
    end
    
    local button_x = 10
    local button_y = love.graphics.getHeight() - 60
    local button_w = 200
    local button_h = 40
    
    return x >= button_x and x <= button_x + button_w and 
           y >= button_y and y <= button_y + button_h
end

function VMManagerState:assignGameToSlot(game_id)
    if not self.selected_slot then return end
    
    local success, err = self.context.vm_manager:assignGame(
        self.selected_slot, 
        game_id, 
        self.context.game_data, 
        self.context.player_data
    )
    
    if success then
        self.context.save_manager.save(self.context.player_data)
    else
        print("Failed to assign game: " .. (err or "unknown error"))
    end
end

function VMManagerState:purchaseNewVM()
    local success, err = self.context.vm_manager:purchaseVM(self.context.player_data)
    
    if success then
        self.context.save_manager.save(self.context.player_data)
        print("Purchased new VM!")
    else
        print("Failed to purchase VM: " .. (err or "unknown error"))
    end
end

return VMManagerState