-- debug_view.lua: View class for the Debug Menu

local Object = require('class')
local UIComponents = require('src.views.ui_components')
local DebugView = Object:extend('DebugView')

function DebugView:init(controller)
    self.controller = controller -- The debug_state
    
    self.buttons = {
        { id = "add_tokens", text = "Add 10,000 Tokens", x = 50, y = 100, w = 250, h = 40 },
        { id = "unlock_all", text = "Unlock All Games", x = 50, y = 150, w = 250, h = 40 },
        { id = "complete_all", text = "Auto-Complete All Games", x = 50, y = 200, w = 250, h = 40 },
        { id = "wipe_save", text = "Wipe Save & Reset", x = 50, y = 250, w = 250, h = 40, color = {0.8, 0, 0} },
        { id = "close", text = "Close Debug Menu (F5)", x = 50, y = 350, w = 250, h = 40 },
        -- Add more buttons later (e.g., Go to Level)
    }
    self.hovered_button_id = nil
end

function DebugView:update(dt)
    -- Update hovered button
    local mx, my = love.mouse.getPosition()
    self.hovered_button_id = nil
    for _, btn in ipairs(self.buttons) do
        if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
            self.hovered_button_id = btn.id
            break
        end
    end
end

function DebugView:draw()
    -- Semi-transparent background overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Title
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("DEBUG MENU", 0, 40, love.graphics.getWidth(), "center")
    
    -- Draw buttons
    for _, btn in ipairs(self.buttons) do
        local is_hovered = (btn.id == self.hovered_button_id)
        local bg_color = btn.color or (is_hovered and {0.35, 0.6, 0.35} or {0, 0.5, 0})
        
        -- Use UIComponents button (needs slight modification or custom draw here)
        -- Custom draw for now:
        love.graphics.setColor(bg_color)
        love.graphics.rectangle('fill', btn.x, btn.y, btn.w, btn.h)
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle('line', btn.x, btn.y, btn.w, btn.h)
        love.graphics.setColor(1, 1, 1)
        local font = love.graphics.getFont()
        local text_width = font:getWidth(btn.text)
        love.graphics.print(btn.text, btn.x + (btn.w - text_width) / 2, btn.y + (btn.h - font:getHeight()) / 2)
    end
    
    -- Instructions
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Press F5 or ESC to close.", 10, love.graphics.getHeight() - 30)
end

function DebugView:mousepressed(x, y, button)
    if button ~= 1 then return nil end
    
    for _, btn in ipairs(self.buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            return { name = "button_click", id = btn.id } -- Return event for state to handle
        end
    end
    return nil
end

return DebugView