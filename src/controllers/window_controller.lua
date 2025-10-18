-- src/controllers/window_controller.lua
-- Manages window input, dragging, resizing, and focus

local Object = require('class')
local WindowController = Object:extend('WindowController')

function WindowController:init(window_manager, program_registry)
    self.window_manager = window_manager
    self.program_registry = program_registry -- Injected dependency

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

    -- Check window control buttons FIRST
    local button_hit = self:checkButtonClick(window, x, y, window_chrome)
    if button_hit then return button_hit end

    -- Check resize edges SECOND (pass program_registry and program_type)
    local edge = window_chrome:getResizeEdge(window, x, y, self.program_registry, window.program_type)
    if edge then
        self:startResize(window.id, edge, x, y)
        return {type = "window_resize_start", window_id = window.id, edge = edge}
    end

    -- Check if in title bar (start drag) THIRD
    if window_chrome:isInTitleBar(window, x, y) then
        self:startDrag(window.id, x, y)
        return {type = "window_drag_start", window_id = window.id}
    end

    -- If not on chrome elements, assume click is potentially in content area
    -- Calculate coordinates relative to the content area's top-left
    local content_bounds = window_chrome:getContentBounds(window)
    local content_x = x - content_bounds.x
    local content_y = y - content_bounds.y

    -- Check if the click is actually within the content bounds before sending event
    if content_x >= 0 and content_x <= content_bounds.width and
       content_y >= 0 and content_y <= content_bounds.height then
        -- It's inside the content area
        return {type = "window_content_click", window_id = window.id,
                content_x = content_x, content_y = content_y} -- Pass content-relative coords
    else
        -- Click was on border or outside content area but inside window bounds
        -- Treat as handled to focus window but don't pass to content
        return { type = "window_chrome_click", window_id = window.id }
    end
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
    -- Check if program allows resizing before enabling maximize/restore button action
    local program = self.program_registry:getProgram(window.program_type)
    local defaults = program and program.window_defaults or {}
    local is_resizable = defaults.resizable ~= false

    if is_resizable then
        bx, by, bw, bh = window_chrome:getButtonBounds(window, max_type)
        if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
            if window.is_maximized then
                return {type = "window_restore", window_id = window.id}
            else
                return {type = "window_maximize", window_id = window.id}
            end
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
    if not window or window.is_maximized then return end -- Cannot drag maximized windows

    self.dragging_window_id = window_id
    self.drag_offset_x = mouse_x - window.x
    self.drag_offset_y = mouse_y - window.y
end

-- Start resizing a window
function WindowController:startResize(window_id, edge, mouse_x, mouse_y)
    local window = self.window_manager:getWindowById(window_id)
    -- Double check resizable and not maximized here too
    local program = self.program_registry:getProgram(window.program_type)
    local defaults = program and program.window_defaults or {}
    local is_resizable = defaults.resizable ~= false
    if not window or window.is_maximized or not is_resizable then return end

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
    print("Start resize", window_id, edge)
end

-- Handle mouse movement
function WindowController:mousemoved(x, y, dx, dy, window_chrome) -- Added window_chrome param
    -- Handle dragging (WITHOUT CLAMPING)
    if self.dragging_window_id then
        local new_x = x - self.drag_offset_x
        local new_y = y - self.drag_offset_y

        -- Update bounds directly without clamping here
        self.window_manager:updateWindowBounds(self.dragging_window_id, new_x, new_y, nil, nil)

        return true -- Indicate mouse move was handled
    end

    -- Handle resizing
    if self.resizing_window_id then
        self:handleResize(x, y)
        return true -- Indicate mouse move was handled
    end

    return false -- Mouse move not handled by dragging or resizing
end

-- Handle resize logic
function WindowController:handleResize(mouse_x, mouse_y)
    local window = self.window_manager:getWindowById(self.resizing_window_id)
    if not window or not self.resize_start_bounds then return end -- Safety check

    local dx = mouse_x - self.resize_start_x
    local dy = mouse_y - self.resize_start_y
    local bounds = self.resize_start_bounds

    local new_x = bounds.x
    local new_y = bounds.y
    local new_w = bounds.width
    local new_h = bounds.height

    local edge = self.resize_edge

    -- Handle horizontal resize first, potentially adjusting x and w
    if edge:find("left") then
        local potential_w = bounds.width - dx
        if potential_w >= self.min_window_width then
            new_w = potential_w
            new_x = bounds.x + dx
        else
            new_w = self.min_window_width
            new_x = bounds.x + bounds.width - self.min_window_width
        end
    elseif edge:find("right") then
        local potential_w = bounds.width + dx
        new_w = math.max(self.min_window_width, potential_w)
    end

    -- Handle vertical resize second, potentially adjusting y and h
    if edge:find("top") then
        local potential_h = bounds.height - dy
        if potential_h >= self.min_window_height then
            new_h = potential_h
            new_y = bounds.y + dy
        else
            new_h = self.min_window_height
            new_y = bounds.y + bounds.height - self.min_window_height
        end
    elseif edge:find("bottom") then
        local potential_h = bounds.height + dy
        new_h = math.max(self.min_window_height, potential_h)
    end

    -- Enforce maximum size (screen bounds, consider taskbar)
    local screen_w = love.graphics.getWidth()
    local screen_h = love.graphics.getHeight()
    local taskbar_h = 40 -- Assume taskbar height

    -- Clamp position first
    new_x = math.max(0, math.min(new_x, screen_w - new_w))
    new_y = math.max(0, math.min(new_y, screen_h - taskbar_h - new_h))

    -- Clamp size based on clamped position
    new_w = math.min(new_w, screen_w - new_x)
    new_h = math.min(new_h, screen_h - taskbar_h - new_y)

    -- Final re-check of minimums after all clamping
    new_w = math.max(self.min_window_width, new_w)
    new_h = math.max(self.min_window_height, new_h)

    -- Adjust position again if minimum clamping changed size significantly when resizing left/top
    if edge:find("left") and new_w == self.min_window_width then
        new_x = math.min(new_x, screen_w - self.min_window_width)
    end
     if edge:find("top") and new_h == self.min_window_height then
        new_y = math.min(new_y, screen_h - taskbar_h - self.min_window_height)
    end

    -- Update the window model
    self.window_manager:updateWindowBounds(self.resizing_window_id, new_x, new_y, new_w, new_h)

    -- *** Notify the state about the new viewport ***
    local window_state = nil
    -- Need DesktopState's window_states map. This is awkward access.
    -- TODO: Refactor later to pass DesktopState or use events. For now, assume global access (bad practice).
    if _G.state_machine and _G.state_machine.states['desktop'] then
        local desktop_state = _G.state_machine.states['desktop']
        local window_data = desktop_state.window_states[self.resizing_window_id]
        window_state = window_data and window_data.state
    end

    if window_state and window_state.setViewport then
        -- Need WindowChrome to calculate content bounds based on NEW window size
        -- Use pcall for safety, ensure chrome is available
        local chrome_ok, chrome = pcall(require, 'src.views.window_chrome')
        if chrome_ok and chrome then
            local chrome_instance = chrome:new()
            -- We need the updated window object after updateWindowBounds
            local updated_window = self.window_manager:getWindowById(self.resizing_window_id)
            if updated_window then
                local new_content_bounds = chrome_instance:getContentBounds(updated_window)
                -- Call setViewport with absolute screen coordinates + dimensions
                local success, err = pcall(window_state.setViewport, window_state,
                      new_content_bounds.x, new_content_bounds.y,
                      new_content_bounds.width, new_content_bounds.height)
                if not success then
                     print("Error calling setViewport during resize for window " .. self.resizing_window_id .. ": " .. tostring(err))
                end
            end
        else
            print("Error: Could not require window_chrome during resize.")
        end
    end
end

-- Handle mouse release
function WindowController:mousereleased(x, y, button)
    if button ~= 1 then return false end

    local was_dragging = self.dragging_window_id ~= nil
    local was_resizing = self.resizing_window_id ~= nil

    -- Handle window drop validation if dragging occurred
    if was_dragging then
        local window_id = self.dragging_window_id
        local window = self.window_manager:getWindowById(window_id)
        if window then
            -- Calculate final dropped position based on current mouse and initial offset
            local final_x = x - self.drag_offset_x
            local final_y = y - self.drag_offset_y

            -- Validate and clamp the final position
            local screen_w = love.graphics.getWidth()
            local screen_h = love.graphics.getHeight()
            local taskbar_h = 40 -- Assume taskbar height
            local title_bar_height = 25 -- Assume default title bar height

            -- Clamp X: Ensure left edge is >= 0 and right edge is <= screen_w
            final_x = math.max(0, math.min(final_x, screen_w - window.width))

            -- Clamp Y: Ensure top edge is >= 0 and bottom edge is <= screen_h - taskbar_h
            -- Also ensure top edge doesn't go below the taskbar level (keeps title bar accessible)
            final_y = math.max(0, math.min(final_y, screen_h - taskbar_h - window.height))
            final_y = math.min(final_y, screen_h - taskbar_h - title_bar_height) -- Extra check for title bar visibility

            -- Ensure final position is valid numbers (safety check)
            final_x = tonumber(final_x) or 0
            final_y = tonumber(final_y) or 0

            -- Update the window bounds to the final clamped position
            self.window_manager:updateWindowBounds(window_id, final_x, final_y, nil, nil)
            print("Dropped window", window_id, "at validated position", final_x, final_y)
        end

        -- Clear drag state AFTER applying final position
        self.dragging_window_id = nil
        self.drag_offset_x = 0
        self.drag_offset_y = 0
    end

    if was_resizing then
        print("End resize", self.resizing_window_id)
        self.resizing_window_id = nil
        self.resize_edge = nil
        self.resize_start_bounds = nil -- Clear start bounds
    end

    return was_dragging or was_resizing
end

-- Get cursor type for current mouse position
function WindowController:getCursorType(x, y, window_chrome)
    -- If currently resizing, keep resize cursor (or maybe normal during drag?)
    if self.resizing_window_id then
        local edge = self.resize_edge
        if edge == "left" or edge == "right" then return "sizewe" end
        if edge == "top" or edge == "bottom" then return "sizens" end
        if edge == "top_left" or edge == "bottom_right" then return "sizenwse" end
        if edge == "top_right" or edge == "bottom_left" then return "sizenesw" end
    end
    -- If currently dragging, use normal cursor
    if self.dragging_window_id then return "arrow" end -- Use 'arrow' for standard

    -- Check if hovering over resize edge of the top-most window under cursor
    -- Iterate windows from top to bottom
    local windows = self.window_manager:getAllWindows()
    for i = #windows, 1, -1 do
        local window = windows[i]
        if not window.is_minimized then
            -- Check bounds first
            if x >= window.x and x <= window.x + window.width and y >= window.y and y <= window.y + window.height then
                local edge = window_chrome:getResizeEdge(window, x, y, self.program_registry, window.program_type)
                if edge then
                    -- Found resize edge on this window, return cursor type
                    if edge == "left" or edge == "right" then return "sizewe" end
                    if edge == "top" or edge == "bottom" then return "sizens" end
                    if edge == "top_left" or edge == "bottom_right" then return "sizenwse" end
                    if edge == "top_right" or edge == "bottom_left" then return "sizenesw" end
                end
                -- If inside window but not on edge, stop checking lower windows and return arrow
                return "arrow"
            end
        end
    end

    -- If not over any window, return default arrow
    return "arrow"
end

return WindowController