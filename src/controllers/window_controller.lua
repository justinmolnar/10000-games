-- src/controllers/window_controller.lua
-- Manages window input, dragging, resizing, and focus

local Object = require('class')
local Config = rawget(_G, 'DI_CONFIG') or {}
local WindowController = Object:extend('WindowController')

function WindowController:init(window_manager, program_registry, window_states_map)
    self.window_manager = window_manager
    self.program_registry = program_registry -- Injected dependency
    self.window_states = window_states_map -- Store reference to DesktopState's map

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

    -- Minimum window size from config
    local min_size = (Config and Config.window and Config.window.min_size) or { w = 200, h = 150 }
    self.min_window_width = min_size.w or 200
    self.min_window_height = min_size.h or 150

    -- Interaction thresholds
    local inter = (Config and Config.ui and Config.ui.window and Config.ui.window.interaction) or {}
    self.drag_deadzone = (inter.drag_deadzone ~= nil) and inter.drag_deadzone or 4
    self.drag_pending = nil -- { window_id, start_x, start_y, offset_x, offset_y }
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
        -- Begin pending drag (apply deadzone before moving window)
        self:startDragPending(window.id, x, y)
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
    local Config = rawget(_G, 'DI_CONFIG') or {}
    local wd = (Config and Config.window and Config.window.defaults) or {}
    local fallback_resizable = (wd.resizable ~= nil) and wd.resizable or true
    local is_resizable = (defaults.resizable ~= nil) and defaults.resizable or fallback_resizable

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

-- Begin a pending drag (deadzone)
function WindowController:startDragPending(window_id, mouse_x, mouse_y)
    local window = self.window_manager:getWindowById(window_id)
    if not window or window.is_maximized then return end
    self.drag_pending = {
        window_id = window_id,
        start_x = mouse_x,
        start_y = mouse_y,
        offset_x = mouse_x - window.x,
        offset_y = mouse_y - window.y
    }
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
    local Config = rawget(_G, 'DI_CONFIG') or {}
    local wd = (Config and Config.window and Config.window.defaults) or {}
    local fallback_resizable = (wd.resizable ~= nil) and wd.resizable or true
    local is_resizable = (defaults.resizable ~= nil) and defaults.resizable or fallback_resizable
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
    -- Promote pending drag if moved beyond deadzone
    if self.drag_pending and not self.dragging_window_id then
        local dpx = math.abs(x - self.drag_pending.start_x)
        local dpy = math.abs(y - self.drag_pending.start_y)
        if dpx >= self.drag_deadzone or dpy >= self.drag_deadzone then
            -- Start real drag
            self.dragging_window_id = self.drag_pending.window_id
            self.drag_offset_x = self.drag_pending.offset_x
            self.drag_offset_y = self.drag_pending.offset_y
            self.drag_pending = nil
        end
    end

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

    -- Horizontal resize logic (adjust x, w)
    if edge:find("left") then
        local potential_w = bounds.width - dx
        if potential_w >= self.min_window_width then new_w = potential_w; new_x = bounds.x + dx
        else new_w = self.min_window_width; new_x = bounds.x + bounds.width - self.min_window_width end
    elseif edge:find("right") then new_w = math.max(self.min_window_width, bounds.width + dx) end

    -- Vertical resize logic (adjust y, h)
    if edge:find("top") then
        local potential_h = bounds.height - dy
        if potential_h >= self.min_window_height then new_h = potential_h; new_y = bounds.y + dy
        else new_h = self.min_window_height; new_y = bounds.y + bounds.height - self.min_window_height end
    elseif edge:find("bottom") then new_h = math.max(self.min_window_height, bounds.height + dy) end

    -- Screen bounds clamping logic
    local screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()
    local taskbar_h = (Config and Config.ui and Config.ui.taskbar and Config.ui.taskbar.height) or 40
    new_x = math.max(0, math.min(new_x, screen_w - new_w))
    new_y = math.max(0, math.min(new_y, screen_h - taskbar_h - new_h))
    new_w = math.min(new_w, screen_w - new_x)
    new_h = math.min(new_h, screen_h - taskbar_h - new_y)
    new_w = math.max(self.min_window_width, new_w); new_h = math.max(self.min_window_height, new_h)
    if edge:find("left") and new_w == self.min_window_width then new_x = math.max(0, math.min(new_x, screen_w - self.min_window_width)) end
    if edge:find("top") and new_h == self.min_window_height then new_y = math.max(0, math.min(new_y, screen_h - taskbar_h - self.min_window_height)) end

    -- Update window model
    self.window_manager:updateWindowBounds(self.resizing_window_id, new_x, new_y, new_w, new_h)

    -- Notify state about new viewport bounds (x, y, width, height)
    local window_data = self.window_states[self.resizing_window_id]
    local window_state = window_data and window_data.state
    if window_state and window_state.setViewport then
        local chrome_ok, chrome = pcall(require, 'src.views.window_chrome')
        if chrome_ok and chrome then
            local chrome_instance = chrome:new()
            local updated_window = self.window_manager:getWindowById(self.resizing_window_id)
            if updated_window then
                local new_content_bounds = chrome_instance:getContentBounds(updated_window)
                print(string.format("Resizing Window %d: Notifying state with ABSOLUTE x:%.1f, y:%.1f, w:%.1f, h:%.1f",
                      self.resizing_window_id, new_content_bounds.x, new_content_bounds.y, new_content_bounds.width, new_content_bounds.height))
                -- *** CHANGE: Pass all four values ***
                local success, err = pcall(window_state.setViewport, window_state,
                      new_content_bounds.x, new_content_bounds.y,
                      new_content_bounds.width, new_content_bounds.height)
                -- *** END CHANGE ***
                if not success then print("Error calling setViewport during resize: " .. tostring(err)) end
            end
        else print("Error: Could not require window_chrome during resize.") end
    else print(string.format("Resizing Window %d: State not found or no setViewport method.", self.resizing_window_id)) end
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
            local taskbar_h = (Config and Config.ui and Config.ui.taskbar and Config.ui.taskbar.height) or 40
            local title_bar_height = ((Config and Config.ui and Config.ui.window and Config.ui.window.chrome and Config.ui.window.chrome.title_bar_height) or 25)

            -- Clamp X: Ensure left edge is >= 0 and right edge is <= screen_w
            final_x = math.max(0, math.min(final_x, screen_w - window.width))

            -- Clamp Y: Ensure top edge is >= 0 and bottom edge is <= screen_h - taskbar_h
            -- Also ensure top edge doesn't go below the taskbar level (keeps title bar accessible)
            final_y = math.max(0, math.min(final_y, screen_h - taskbar_h - window.height))
            final_y = math.min(final_y, screen_h - taskbar_h - title_bar_height) -- Extra check for title bar visibility

            -- Ensure final position is valid numbers (safety check)
            final_x = tonumber(final_x) or 0
            final_y = tonumber(final_y) or 0

            -- Optional snapping to edges
            local inter = (Config and Config.ui and Config.ui.window and Config.ui.window.interaction) or {}
            local snap = inter.snap or {}
            if snap.enabled then
                local pad = snap.padding or 10
                if snap.to_edges ~= false then
                    if final_x <= pad then final_x = 0 end
                    if final_x + window.width >= screen_w - pad then final_x = screen_w - window.width end
                    if final_y <= pad then
                        if snap.top_maximize then
                            -- Maximize instead of snapping to top
                            self.window_manager:maximizeWindow(window_id, screen_w, screen_h)
                            -- Clear drag state and pending; skip normal update
                            self.dragging_window_id = nil
                            self.drag_offset_x = 0
                            self.drag_offset_y = 0
                            self.drag_pending = nil
                            return true
                        else
                            final_y = 0
                        end
                    end
                    if final_y + window.height >= (screen_h - taskbar_h - pad) then
                        final_y = (screen_h - taskbar_h - window.height)
                    end
                end
            end

            -- Update the window bounds to the final clamped/snapped position
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

    -- Clear pending drag if click released without exceeding deadzone
    if self.drag_pending and button == 1 then
        self.drag_pending = nil
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