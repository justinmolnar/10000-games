-- vm_manager_view.lua: Drawing functions for VM Manager UI

local VMManagerView = {}

function VMManagerView.drawTokensPerMinute(x, y, rate)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Total Generation Rate:", x, y)
    
    if rate > 0 then
        love.graphics.setColor(0, 1, 0)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
    end
    
    love.graphics.print(string.format("%.1f tokens/minute", rate), x + 200, y, 0, 1.2, 1.2)
end

function VMManagerView.drawVMSlot(x, y, w, h, slot, selected, hovered, context)
    -- Background
    if selected then
        love.graphics.setColor(0.3, 0.3, 0.7)
    elseif hovered then
        love.graphics.setColor(0.35, 0.35, 0.35)
    else
        love.graphics.setColor(0.25, 0.25, 0.25)
    end
    love.graphics.rectangle('fill', x, y, w, h)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
    
    -- Slot number
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("VM " .. slot.slot_index, x + 5, y + 5, 0, 0.8, 0.8)
    
    if slot.active and slot.assigned_game_id then
        local game_data = context.game_data:getGame(slot.assigned_game_id)
        
        if game_data then
            -- Game name
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(game_data.display_name, x + 5, y + 25, 0, 0.85, 0.85)
            
            -- Power
            love.graphics.setColor(0, 1, 1)
            love.graphics.print("Power: " .. math.floor(slot.auto_play_power), x + 5, y + 45, 0, 0.8, 0.8)
            
            -- Tokens per cycle
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("+" .. math.floor(slot.tokens_per_cycle) .. " tokens", x + 5, y + 60, 0, 0.8, 0.8)
            
            -- Progress bar
            local progress = 1 - (slot.time_remaining / slot.cycle_time)
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle('fill', x + 5, y + h - 25, w - 10, 15)
            love.graphics.setColor(0, 1, 0)
            love.graphics.rectangle('fill', x + 5, y + h - 25, (w - 10) * progress, 15)
            
            -- Time remaining
            love.graphics.setColor(1, 1, 1)
            local time_text = string.format("%.1fs", slot.time_remaining)
            love.graphics.print(time_text, x + w/2 - 15, y + h - 23, 0, 0.8, 0.8)
            
            -- Auto-completed badge
            if slot.is_auto_completed then
                love.graphics.setColor(0.5, 0.5, 1)
                love.graphics.print("[AUTO]", x + w - 45, y + 5, 0, 0.7, 0.7)
            end
        end
    else
        -- Empty slot
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("Empty", x + w/2 - 20, y + h/2 - 10)
        love.graphics.print("Click to assign", x + w/2 - 45, y + h/2 + 10, 0, 0.8, 0.8)
    end
end

function VMManagerView.drawGameSelectionModal(games, scroll_offset, state, context)
    -- Modal background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Modal window
    local modal_x = love.graphics.getWidth() / 2 - 200
    local modal_y = 100
    local modal_w = 400
    local modal_h = love.graphics.getHeight() - 200
    
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle('fill', modal_x, modal_y, modal_w, modal_h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', modal_x, modal_y, modal_w, modal_h)
    
    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Select Game to Assign", modal_x + 10, modal_y + 10, 0, 1.2, 1.2)
    
    -- Game list
    local item_height = 40
    local visible_items = math.floor((modal_h - 50) / item_height)
    local start_index = scroll_offset + 1
    local end_index = math.min(#games, start_index + visible_items - 1)
    
    for i = start_index, end_index do
        local game_data = games[i]
        local item_y = modal_y + 50 + (i - start_index) * item_height
        
        -- Check if already assigned
        local is_assigned = context.vm_manager:isGameAssigned(game_data.id)
        
        -- Background
        if is_assigned then
            love.graphics.setColor(0.15, 0.15, 0.15)
        else
            love.graphics.setColor(0.25, 0.25, 0.25)
        end
        love.graphics.rectangle('fill', modal_x + 10, item_y, modal_w - 20, item_height - 2)
        
        -- Game info
        if is_assigned then
            love.graphics.setColor(0.5, 0.5, 0.5)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.print(game_data.display_name, modal_x + 15, item_y + 5)
        
        local perf = context.player_data:getGamePerformance(game_data.id)
        if perf then
            if is_assigned then
                love.graphics.setColor(0.4, 0.4, 0.4)
            else
                love.graphics.setColor(0, 1, 1)
            end
            love.graphics.print("Power: " .. math.floor(perf.best_score), modal_x + 15, item_y + 20, 0, 0.8, 0.8)
            
            -- Show "IN USE" marker or tokens/min
            if is_assigned then
                love.graphics.setColor(1, 0, 0)
                love.graphics.print("[IN USE]", modal_x + modal_w - 80, item_y + 20, 0, 0.8, 0.8)
            else
                love.graphics.setColor(0.7, 0.7, 0.7)
                love.graphics.print(math.floor(perf.best_score) .. "/min", modal_x + modal_w - 80, item_y + 20, 0, 0.8, 0.8)
            end
        end
    end
    
    -- Instructions
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Click game to assign | ESC to cancel", modal_x + 10, modal_y + modal_h - 25, 0, 0.8, 0.8)
end

function VMManagerView.drawPurchaseVMButton(x, y, cost, can_afford)
    local button_w = 200
    local button_h = 40
    
    -- Button background
    if can_afford then
        love.graphics.setColor(0, 0.5, 0)
    else
        love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.rectangle('fill', x, y, button_w, button_h)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, button_w, button_h)
    
    -- Text
    if can_afford then
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
    end
    love.graphics.print("Purchase VM", x + 10, y + 5)
    love.graphics.print(cost .. " tokens", x + 10, y + 22, 0, 0.9, 0.9)
end

return VMManagerView