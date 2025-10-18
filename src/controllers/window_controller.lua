-- src/controllers/window_controller.lua
-- Manages window input, dragging, resizing, and focus

local Object = require('class')
local WindowController = Object:extend('WindowController')

function WindowController:init(window_manager, program_registry)
    self.window_manager = window_manager
    self.program_registry = program_registry
    
    -- Drag state
    self.dragging_window_id = nil
    self.drag_offset_x = 0
    self.drag_offset_y = 0
    
    -- Resize state
    self.resizing_window_id = nil
    self.resize_edge = nil
    self.resize_start_x = 0
    self.resize_start_y = 0
    self.resize_start_bounds = nil
    
    -- Minimum window size
    self.min_window_width = 200
    self.min_window_height = 150
end

-- Update window controller
function WindowController:update(dt)
    -- Could handle window animations here in future
end

-- Handle mouse press
function WindowController:mousepressed(x, y, button, window_chrome)
    if button ~= 1 then return nil end
    
    -- Get top window
    local top_window = self.window_manager:getTopWindow()
    if not top_window then return nil end
    
    -- Check if clicked on a window (iterate from top to bottom)
    local windows = self.window_manager:getAllWindows()
    for i = #windows, 1, -1 do
        local window = windows[i]
        if not window.is_minimized then
            local clicked = self:checkWindowClick(window, x, y, window_chrome)
            if clicked then
                return clicked
            end
        end
    end
    
    return nil
end

-- Check if click is on a specific window
function WindowController:checkWindowClick(window, x, y, window_chrome)
    -- Check if in window bounds
    if x < window.x or x > window.x + window.width then return nil end
    if y < window.y or y > window.y + window.height then return nil end
    
    -- Focus this window if not already focused
    if self.window_manager:getFocusedWindowId() ~= window.id then
        self.window_manager:focusWindow(window.id)
    end
    
    -- Check window control buttons
    local button_hit = self:checkButtonClick(window, x, y, window_chrome)
    if button_hit then return button_hit end
    
    -- Check if in title bar (start drag)
    if window_chrome:isInTitleBar(window, x, y) then
        self:startDrag(window.id, x, y)
        return {type = "window_drag_start", window_id = window.id}
    end
    
    -- Check resize edges
    local edge = window_chrome:getResizeEdge(window, x, y, self.program_registry, window.program_type)
    if edge then
        self:startResize(window.id, edge, x, y)
        return {type = "window_resize_start", window_id = window.id, edge = edge}
    end
    
    -- Click is in content area
    return {type = "window_content_click", window_id = window.id, 
            content_x = x - window.x, content_y = y - window.y}
end

-- Check button clicks
function WindowController:checkButtonClick(window, x, y, window_chrome)
    -- Check close button
    local bx, by, bw, bh = window_chrome:getButtonBounds(window, "close")
    if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
        return {type = "window_close", window_id = window.id}
    end
    
    -- Check maximize/restore button
    local max_type = window.is_maximized and "restore" or "maximize"
    bx, by, bw, bh = window_chrome:getButtonBounds(window, max_type)
    if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
        if window.is_maximized then
            return {type = "window_restore", window_id = window.id}
        else
            return {type = "window_maximize", window_id = window.id}
        end
    end
    
    -- Check minimize button
    bx, by, bw, bh = window_chrome:getButtonBounds(window, "minimize")
    if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
        return {type = "window_minimize", window_id = window.id}
    end
    
    return nil
end

-- Start dragging a window
function WindowController:startDrag(window_id, mouse_x, mouse_y)
    local window = self.window_manager:getWindowById(window_id)
    if not window or window.is_maximized then return end
    
    self.dragging_window_id = window_id
    self.drag_offset_x = mouse_x - window.x
    self.drag_offset_y = mouse_y - window.y
end

-- Start resizing a window
function WindowController:startResize(window_id, edge, mouse_x, mouse_y)
    local window = self.window_manager:getWindowById(window_id)
    if not window or window.is_maximized then return end
    
    self.resizing_window_id = window_id
    self.resize_edge = edge
    self.resize_start_x = mouse_x
    self.resize_start_y = mouse_y
    self.resize_start_bounds = {
        x = window.x,
        y = window.y,
        width = window.width,
        height = window.height
    }
end

-- Handle mouse movement
function WindowController:mousemoved(x, y, dx, dy)
    -- Handle dragging
    if self.dragging_window_id then
        local new_x = x - self.drag_offset_x
        local new_y = y - self.drag_offset_y
        
        -- Clamp to screen bounds (keep at least 50px visible)
        local screen_w = love.graphics.getWidth()
        local screen_h = love.graphics.getHeight()
        
        local window = self.window_manager:getWindowById(self.dragging_window_id)
        if window then
            new_x = math.max(-window.width + 50, math.min(new_x, screen_w - 50))
            new_y = math.max(0, math.min(new_y, screen_h - 40 - 25)) -- Keep title bar accessible
            
            self.window_manager:updateWindowBounds(self.dragging_window_id, new_x, new_y, nil, nil)
        end
        
        return true
    end
    
    -- Handle resizing
    if self.resizing_window_id then
        self:handleResize(x, y)
        return true
    end
    
    return false
end

-- Handle resize logic
function WindowController:handleResize(mouse_x, mouse_y)
    local window = self.window_manager:getWindowById(self.resizing_window_id)
    if not window then return end
    
    local dx = mouse_x - self.resize_start_x
    local dy = mouse_y - self.resize_start_y
    local bounds = self.resize_start_bounds
    
    local new_x = bounds.x
    local new_y = bounds.y
    local new_w = bounds.width
    local new_h = bounds.height
    
    local edge = self.resize_edge
    
    -- Handle horizontal resize
    if edge:find("left") then
        new_x = bounds.x + dx
        new_w = bounds.width - dx
    elseif edge:find("right") then
        new_w = bounds.width + dx
    end
    
    -- Handle vertical resize
    if edge:find("top") then
        new_y = bounds.y + dy
        new_h = bounds.height - dy
    elseif edge:find("bottom") then
        new_h = bounds.height + dy
    end
    
    -- Enforce minimum size
    if new_w < self.min_window_width then
        if edge:find("left") then
            new_x = bounds.x + bounds.width - self.min_window_width
        end
        new_w = self.min_window_width
    end
    
    if new_h < self.min_window_height then
        if edge:find("top") then
            new_y = bounds.y + bounds.height - self.min_window_height
        end
        new_h = self.min_window_height
    end
    
    -- Enforce maximum size (screen bounds)
    local screen_w = love.graphics.getWidth()
    local screen_h = love.graphics.getHeight() - 40 -- Reserve taskbar
    
    new_w = math.min(new_w, screen_w)
    new_h = math.min(new_h, screen_h)
    
    self.window_manager:updateWindowBounds(self.resizing_window_id, new_x, new_y, new_w, new_h)
end

-- Handle mouse release
function WindowController:mousereleased(x, y, button)
    if button ~= 1 then return false end
    
    local was_dragging = self.dragging_window_id ~= nil
    local was_resizing = self.resizing_window_id ~= nil
    
    self.dragging_window_id = nil
    self.resizing_window_id = nil
    self.resize_edge = nil
    
    return was_dragging or was_resizing
end

-- Get cursor type for current mouse position
function WindowController:getCursorType(x, y, window_chrome)
    if self.dragging_window_id or self.resizing_window_id then
        return "normal"
    end
    
    -- Check if hovering over resize edge
    local top_window = self.window_manager:getTopWindow()
    if top_window then
        local edge = window_chrome:getResizeEdge(top_window, x, y, self.program_registry, top_window.program_type)
        if edge then
            if edge == "left" or edge == "right" then return "sizewe" end
            if edge == "top" or edge == "bottom" then return "sizens" end
            if edge == "top_left" or edge == "bottom_right" then return "sizenwse" end
            if edge == "top_right" or edge == "bottom_left" then return "sizenesw" end
        end
    end
    
    return "normal"
end

return WindowController