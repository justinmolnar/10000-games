-- src/views/window_chrome.lua
-- Reusable component for rendering window chrome (title bar, borders, buttons)

local Object = require('class')
local WindowChrome = Object:extend('WindowChrome')

-- Window chrome dimensions
WindowChrome.TITLE_BAR_HEIGHT = 25
WindowChrome.BORDER_WIDTH = 2
WindowChrome.BUTTON_WIDTH = 16
WindowChrome.BUTTON_HEIGHT = 14
WindowChrome.BUTTON_PADDING = 2

function WindowChrome:init()
    -- No state needed, pure rendering component
end

-- Draw complete window chrome
function WindowChrome:draw(window, is_focused)
    self:drawBorder(window, is_focused)
    self:drawTitleBar(window, is_focused)
    self:drawButtons(window, is_focused)
end

-- Draw window border
function WindowChrome:drawBorder(window, is_focused)
    local color = is_focused and {0.8, 0.8, 0.8} or {0.5, 0.5, 0.5}
    
    -- Outer border (raised effect)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('line', window.x, window.y, window.width, window.height)
    
    -- Inner border
    love.graphics.setColor(color)
    love.graphics.rectangle('line', 
        window.x + 1, window.y + 1, 
        window.width - 2, window.height - 2)
end

-- Draw title bar
function WindowChrome:drawTitleBar(window, is_focused)
    local bar_height = self.TITLE_BAR_HEIGHT
    
    -- Title bar background (gradient effect)
    if is_focused then
        love.graphics.setColor(0, 0, 0.5)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
    end
    love.graphics.rectangle('fill', 
        window.x + 2, window.y + 2, 
        window.width - 4, bar_height)
    
    -- Title text
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(window.title, 
        window.x + 5, window.y + 6, 
        0, 0.9, 0.9)
end

-- Draw window control buttons
function WindowChrome:drawButtons(window, is_focused)
    local bar_height = self.TITLE_BAR_HEIGHT
    local btn_w = self.BUTTON_WIDTH
    local btn_h = self.BUTTON_HEIGHT
    local btn_padding = self.BUTTON_PADDING
    
    -- Calculate button positions (right-aligned)
    local close_x = window.x + window.width - btn_w - 4
    local max_x = close_x - btn_w - btn_padding
    local min_x = max_x - btn_w - btn_padding
    local btn_y = window.y + 4
    
    -- Minimize button
    self:drawButton(min_x, btn_y, btn_w, btn_h, "minimize", is_focused)
    
    -- Maximize/Restore button
    local max_type = window.is_maximized and "restore" or "maximize"
    self:drawButton(max_x, btn_y, btn_w, btn_h, max_type, is_focused)
    
    -- Close button
    self:drawButton(close_x, btn_y, btn_w, btn_h, "close", is_focused)
end

-- Draw individual button
function WindowChrome:drawButton(x, y, w, h, button_type, is_focused)
    -- Button background
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', x, y, w, h)
    
    -- Button border (raised effect)
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(x, y, x + w, y)
    love.graphics.line(x, y, x, y + h)
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.line(x + w, y, x + w, y + h)
    love.graphics.line(x, y + h, x + w, y + h)
    
    -- Button icon
    love.graphics.setColor(0, 0, 0)
    local center_x = x + w / 2
    local center_y = y + h / 2
    
    if button_type == "minimize" then
        -- Horizontal line at bottom
        love.graphics.rectangle('fill', x + 3, y + h - 4, w - 6, 2)
    elseif button_type == "maximize" then
        -- Rectangle
        love.graphics.rectangle('line', x + 3, y + 2, w - 6, h - 4)
    elseif button_type == "restore" then
        -- Two overlapping rectangles
        love.graphics.rectangle('line', x + 4, y + 2, w - 7, h - 5)
        love.graphics.rectangle('line', x + 2, y + 4, w - 7, h - 5)
    elseif button_type == "close" then
        -- X shape
        love.graphics.line(x + 3, y + 3, x + w - 3, y + h - 3)
        love.graphics.line(x + w - 3, y + 3, x + 3, y + h - 3)
    end
end

-- Get button bounds for hit testing
function WindowChrome:getButtonBounds(window, button_type)
    local btn_w = self.BUTTON_WIDTH
    local btn_h = self.BUTTON_HEIGHT
    local btn_padding = self.BUTTON_PADDING
    
    local close_x = window.x + window.width - btn_w - 4
    local max_x = close_x - btn_w - btn_padding
    local min_x = max_x - btn_w - btn_padding
    local btn_y = window.y + 4
    
    if button_type == "minimize" then
        return min_x, btn_y, btn_w, btn_h
    elseif button_type == "maximize" or button_type == "restore" then
        return max_x, btn_y, btn_w, btn_h
    elseif button_type == "close" then
        return close_x, btn_y, btn_w, btn_h
    end
    
    return 0, 0, 0, 0
end

-- Check if point is in title bar (for dragging)
function WindowChrome:isInTitleBar(window, x, y)
    local bar_height = self.TITLE_BAR_HEIGHT
    
    -- Check if in title bar area
    if x < window.x + 2 or x > window.x + window.width - 2 then
        return false
    end
    if y < window.y + 2 or y > window.y + 2 + bar_height then
        return false
    end
    
    -- Exclude button area
    local btn_w = self.BUTTON_WIDTH
    local btn_padding = self.BUTTON_PADDING
    local buttons_width = (btn_w * 3) + (btn_padding * 2) + 8
    
    if x > window.x + window.width - buttons_width then
        return false
    end
    
    return true
end

-- Check if point is on window edge for resizing
function WindowChrome:getResizeEdge(window, x, y, program_registry, program_id)
    -- Check if window is resizable
    local program = program_registry:getProgram(program_id)
    if program and program.window_resizable == false then
        return nil
    end
    
    local edge_size = 8
    local on_left = x >= window.x and x <= window.x + edge_size
    local on_right = x >= window.x + window.width - edge_size and x <= window.x + window.width
    local on_top = y >= window.y and y <= window.y + edge_size
    local on_bottom = y >= window.y + window.height - edge_size and y <= window.y + window.height
    
    -- Corner detection (prioritize corners)
    if on_top and on_left then return "top_left" end
    if on_top and on_right then return "top_right" end
    if on_bottom and on_left then return "bottom_left" end
    if on_bottom and on_right then return "bottom_right" end
    
    -- Edge detection
    if on_left then return "left" end
    if on_right then return "right" end
    if on_top then return "top" end
    if on_bottom then return "bottom" end
    
    return nil
end

-- Get content area bounds (where state renders)
function WindowChrome:getContentBounds(window)
    local bar_height = self.TITLE_BAR_HEIGHT
    local border = self.BORDER_WIDTH
    
    return {
        x = window.x + border,
        y = window.y + bar_height + border,
        width = window.width - (border * 2),
        height = window.height - bar_height - (border * 2)
    }
end

return WindowChrome