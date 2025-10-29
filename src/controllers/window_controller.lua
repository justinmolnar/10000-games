-- src/controllers/window_controller.lua
-- Manages window input, dragging, resizing, and focus

local Object = require('class')
local WindowController = Object:extend('WindowController')

function WindowController:init(window_manager, program_registry, window_states_map, di)
    self.window_manager = window_manager
    self.program_registry = program_registry -- Injected dependency
    self.window_states = window_states_map -- Store reference to DesktopState's map
    self.event_bus = di and di.eventBus

    -- Optional DI for config
    local Config = (di and di.config) or require('src.config')

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

    -- Deprecated: per-window minima are resolved per program during resize; kept for legacy fallback
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
        if self.event_bus then
            self.event_bus:publish('request_window_focus', window.id)
        end
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
    if self.event_bus then
        self.event_bus:publish('window_resize_started', window_id)
    end
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

            if self.event_bus then
                self.event_bus:publish('window_drag_started', self.dragging_window_id)
            end
        end
    end

    -- Handle dragging (WITHOUT CLAMPING)
    if self.dragging_window_id then
        local new_x = x - self.drag_offset_x
        local new_y = y - self.drag_offset_y

        -- Update bounds directly without clamping here
        if self.event_bus then
            self.event_bus:publish('request_window_move', self.dragging_window_id, new_x, new_y)
        end

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
    local program = self.program_registry:getProgram(window.program_type)
    local defaults = program and program.window_defaults or {}
    local Config = rawget(_G, 'DI_CONFIG') or {}
    local global_min = (Config and Config.window and Config.window.min_size) or { w = 200, h = 150 }
    -- Prefer the window's stored minima (set on creation) then program defaults, then global
    local min_w = tonumber(window.min_w) or tonumber(defaults.min_w) or global_min.w or self.min_window_width or 200
    local min_h = tonumber(window.min_h) or tonumber(defaults.min_h) or global_min.h or self.min_window_height or 150

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
        if potential_w >= min_w then new_w = potential_w; new_x = bounds.x + dx
        else new_w = min_w; new_x = bounds.x + bounds.width - min_w end
    elseif edge:find("right") then new_w = math.max(min_w, bounds.width + dx) end

    -- Vertical resize logic (adjust y, h)
    if edge:find("top") then
        local potential_h = bounds.height - dy
        if potential_h >= min_h then new_h = potential_h; new_y = bounds.y + dy
        else new_h = min_h; new_y = bounds.y + bounds.height - min_h end
    elseif edge:find("bottom") then new_h = math.max(min_h, bounds.height + dy) end

    -- Aspect ratio locking (for fixed arena + fixed camera)
    local window_data = self.window_states[self.resizing_window_id]
    local window_state = window_data and window_data.state
    -- Check game first (for MinigameState), then state itself (for other windows)
    local aspect_obj = (window_state and window_state.current_game) or window_state

    if aspect_obj and aspect_obj.lock_aspect_ratio then
        -- Calculate target aspect ratio from ARENA dimensions (not current window bounds)
        local arena_width = aspect_obj.game_width
        local arena_height = aspect_obj.game_height

        if not arena_width or not arena_height then
            print("[WindowController] WARNING: game_width/game_height not available:", arena_width, arena_height)
        else
            local target_aspect = arena_width / arena_height
            local title_bar_height = (Config and Config.ui and Config.ui.window and Config.ui.window.chrome and Config.ui.window.chrome.title_bar_height) or 25
            local border_width = (Config and Config.ui and Config.ui.window and Config.ui.window.chrome and Config.ui.window.chrome.border_width) or 2

            local is_horizontal = edge:find("left") or edge:find("right")
            local is_vertical = edge:find("top") or edge:find("bottom")
            local is_corner = is_horizontal and is_vertical

            -- IMPORTANT: The aspect ratio applies to the VIEWPORT (content area), not the window
            -- Viewport width = window.width - (border * 2)
            -- Viewport height = window.height - title_bar_height - (border * 2)

            if is_corner then
                -- Corner drag: determine which dimension changed more
                local width_change = math.abs(new_w - bounds.width)
                local height_change = math.abs(new_h - bounds.height)

                if width_change > height_change then
                    -- Width changed more, adjust height to match viewport aspect ratio
                    -- Round viewport dimensions to integers first
                    local viewport_width = math.floor(new_w - (border_width * 2))
                    local viewport_height = math.floor(viewport_width / target_aspect)
                    new_h = viewport_height + title_bar_height + (border_width * 2)
                    if edge:find("top") then
                        new_y = bounds.y + bounds.height - new_h
                    end
                else
                    -- Height changed more, adjust width to match viewport aspect ratio
                    -- Round viewport dimensions to integers first
                    local viewport_height = math.floor(new_h - title_bar_height - (border_width * 2))
                    local viewport_width = math.floor(viewport_height * target_aspect)
                    new_w = viewport_width + (border_width * 2)
                    if edge:find("left") then
                        new_x = bounds.x + bounds.width - new_w
                    end
                end
            elseif is_horizontal then
                -- Dragging left or right edge: adjust window height to maintain viewport aspect ratio
                -- Round viewport dimensions to integers first
                local viewport_width = math.floor(new_w - (border_width * 2))
                local viewport_height = math.floor(viewport_width / target_aspect)
                new_h = viewport_height + title_bar_height + (border_width * 2)
            elseif is_vertical then
                -- Dragging top or bottom edge: adjust window width to maintain viewport aspect ratio
                -- Round viewport dimensions to integers first
                local viewport_height = math.floor(new_h - title_bar_height - (border_width * 2))
                local viewport_width = math.floor(viewport_height * target_aspect)
                new_w = viewport_width + (border_width * 2)
            end
        end
    end

    -- Screen bounds clamping logic
    local screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()
    local taskbar_h = (Config and Config.ui and Config.ui.taskbar and Config.ui.taskbar.height) or 40

    -- If aspect ratio is locked, we need to clamp BOTH dimensions proportionally
    if aspect_obj and aspect_obj.lock_aspect_ratio and aspect_obj.game_width and aspect_obj.game_height then
        local target_aspect = aspect_obj.game_width / aspect_obj.game_height
        local title_bar_height = (Config and Config.ui and Config.ui.window and Config.ui.window.chrome and Config.ui.window.chrome.title_bar_height) or 25
        local border_width = (Config and Config.ui and Config.ui.window and Config.ui.window.chrome and Config.ui.window.chrome.border_width) or 2

        -- Calculate maximum allowed dimensions
        local max_w = screen_w - new_x
        local max_h = screen_h - taskbar_h - new_y

        -- If either dimension exceeds max, recalculate both to maintain aspect ratio
        if new_w > max_w or new_h > max_h then
            -- Calculate what dimensions would fit for each constraint
            local viewport_w_for_h = math.floor((max_h - title_bar_height - (border_width * 2)) * target_aspect)
            local w_if_h_constrained = viewport_w_for_h + (border_width * 2)

            local viewport_h_for_w = math.floor((max_w - (border_width * 2)) / target_aspect)
            local h_if_w_constrained = viewport_h_for_w + title_bar_height + (border_width * 2)

            -- Use the smaller of the two options to ensure both fit
            if w_if_h_constrained <= max_w then
                new_w = w_if_h_constrained
                new_h = max_h
            else
                new_w = max_w
                new_h = h_if_w_constrained
            end
        end
    end

    new_x = math.max(0, math.min(new_x, screen_w - new_w))
    new_y = math.max(0, math.min(new_y, screen_h - taskbar_h - new_h))
    new_w = math.min(new_w, screen_w - new_x)
    new_h = math.min(new_h, screen_h - taskbar_h - new_y)
    new_w = math.max(min_w, new_w); new_h = math.max(min_h, new_h)
    if edge:find('top') and new_h == min_h then new_y = math.max(0, math.min(new_y, screen_h - taskbar_h - min_h)) end

    -- Update window model
    if self.event_bus then
        self.event_bus:publish('request_window_resize', self.resizing_window_id, new_x, new_y, new_w, new_h)
    end

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
                                        if self.event_bus then
                                            self.event_bus:publish('request_window_maximize', window_id, screen_w, screen_h)
                                        end
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
                        if self.event_bus then
                            self.event_bus:publish('request_window_move', window_id, final_x, final_y)
                        end
                                print("Dropped window", window_id, "at validated position", final_x, final_y)
                        
                                if self.event_bus then
                                    self.event_bus:publish('window_drag_ended', window_id)
                                end
                            end
                        
                            -- Clear drag state AFTER applying final position
                            self.dragging_window_id = nil
                            self.drag_offset_x = 0
                            self.drag_offset_y = 0
    end

    if was_resizing then
        if self.event_bus then
            self.event_bus:publish('window_resize_ended', self.resizing_window_id)
        end
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