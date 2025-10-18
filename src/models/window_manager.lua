-- src/models/window_manager.lua
-- Model managing all open windows, z-order, focus, and window state

local Object = require('class')
local json = require('json')
local WindowManager = Object:extend('WindowManager')

local SAVE_FILE = "window_positions.json"
local SAVE_VERSION = "1.0" -- Increment if structure changes significantly

function WindowManager:init()
    self.windows = {} -- Array for z-order (index 1 = bottom, last = top)
    self.focused_window_id = nil
    self.next_window_id = 1
    self.minimized_windows = {} -- {window_id = true} - Tracks minimized state separately for taskbar
    self.window_positions = {} -- {program_type = {x, y, w, h}} - Stores last known non-maximized position/size
    self.cascade_offset_x = 25 -- Added for cascading new windows
    self.cascade_offset_y = 25 -- Added for cascading new windows
    self.last_base_pos = { x = -1, y = -1 } -- Track base position for cascading

    self:loadWindowPositions()
end

-- Create a new window
function WindowManager:createWindow(program, title, content_state, default_w, default_h)
    -- *** CHANGE: Accept 'program' definition instead of 'program_type' ***
    if not program or not program.id then
        print("ERROR: createWindow called without valid program definition.")
        return nil
    end
    local program_type = program.id -- Use program.id as the type identifier
    local defaults = program.window_defaults or {}
    local is_resizable = defaults.resizable ~= false -- Default to true if not specified
    -- *** END CHANGE ***

    local window_id = self.next_window_id
    self.next_window_id = self.next_window_id + 1

    local x, y, w, h
    local remembered = self.window_positions[program_type]

    -- *** CHANGE: Check resizable flag before using remembered size ***
    if not is_resizable then
        print("Program", program_type, "is not resizable. Forcing default size.")
        w = default_w or 600 -- Use passed defaults
        h = default_h or 400
        -- Use remembered position if available, otherwise calculate cascade/center
        if remembered and remembered.x and remembered.y then
             x, y = remembered.x, remembered.y
             print("Using remembered position but default size:", x, y, w, h)
        else
            -- Calculate initial position (Cascade/Center logic remains the same)
             local screen_w, screen_h = love.graphics.getDimensions()
             local taskbar_h = 40
             local center_x = math.floor((screen_w - w) / 2)
             local center_y = math.floor((screen_h - taskbar_h - h) / 2)
             if self.last_base_pos.x >= 0 then
                 x = self.last_base_pos.x + self.cascade_offset_x
                 y = self.last_base_pos.y + self.cascade_offset_y
                 if (x + w / 2 > screen_w - 50) or (y + h / 2 > screen_h - taskbar_h - 50) then
                     x, y = 50, 50; self.last_base_pos = { x = x, y = y }
                 else self.last_base_pos = { x = x, y = y } end
             else
                 x, y = center_x, center_y; self.last_base_pos = { x = x, y = y }
             end
             print("Calculated initial position and default size:", x, y, w, h)
        end
    -- If RESIZABLE, use original logic (prioritize remembered dimensions)
    elseif remembered and remembered.w and remembered.h and remembered.x and remembered.y then
        x, y, w, h = remembered.x, remembered.y, remembered.w, remembered.h
        print("Using remembered position and size for", program_type, ":", x, y, w, h)
    else
        -- Resizable but no remembered data, use defaults and calculate position
        w = default_w or 600
        h = default_h or 400
        local screen_w, screen_h = love.graphics.getDimensions()
        local taskbar_h = 40
        local center_x = math.floor((screen_w - w) / 2)
        local center_y = math.floor((screen_h - taskbar_h - h) / 2)
        if self.last_base_pos.x >= 0 then
            x = self.last_base_pos.x + self.cascade_offset_x
            y = self.last_base_pos.y + self.cascade_offset_y
            if (x + w / 2 > screen_w - 50) or (y + h / 2 > screen_h - taskbar_h - 50) then
                x, y = 50, 50; self.last_base_pos = { x = x, y = y }
            else self.last_base_pos = { x = x, y = y } end
        else
            x, y = center_x, center_y; self.last_base_pos = { x = x, y = y }
        end
        print("Calculated initial position for resizable", program_type, ":", x, y, w, h)
    end
    -- *** END CHANGE ***

    -- Clamp initial position robustly (logic remains the same)
    local screen_w, screen_h = love.graphics.getDimensions()
    local taskbar_h = 40
    -- Ensure w and h are valid numbers before clamping
    w = tonumber(w) or default_w or 600
    h = tonumber(h) or default_h or 400
    w = math.max(self.min_window_width or 200, w) -- Apply min width
    h = math.max(self.min_window_height or 150, h) -- Apply min height

    x = math.max(0, math.min(x or 0, screen_w - w))
    y = math.max(0, math.min(y or 0, screen_h - taskbar_h - h))
    x = tonumber(x) or 0; y = tonumber(y) or 0

    local window = {
        id = window_id, program_type = program_type, title = title, content_state = content_state,
        x = x, y = y, width = w, height = h,
        is_maximized = false, pre_maximize_bounds = nil, is_minimized = false
    }

    table.insert(self.windows, window)
    self:focusWindow(window_id)

    return window_id
end

-- Close a window by ID
function WindowManager:closeWindow(window_id)
    for i = #self.windows, 1, -1 do
        if self.windows[i].id == window_id then
            local window = table.remove(self.windows, i)

            -- Remember position for this program type if not maximized
            if not window.is_maximized then
                self:rememberWindowPosition(window)
            end

            -- Clear minimized state
            self.minimized_windows[window_id] = nil

            -- If this was focused, focus next highest non-minimized window
            if self.focused_window_id == window_id then
                self.focused_window_id = nil -- Clear focus first
                for j = #self.windows, 1, -1 do -- Iterate from top down
                     if not self.windows[j].is_minimized then
                         self.focused_window_id = self.windows[j].id
                         break
                     end
                end
            end

            return true
        end
    end
    return false
end

-- Focus a window (brings to front)
function WindowManager:focusWindow(window_id)
    local window_index = self:getWindowIndexById(window_id)
    if not window_index then return false end
    local window = self.windows[window_index]

    -- If minimized, restore it first (which also brings to front and sets focus)
    if window.is_minimized then
        self:restoreWindow(window_id)
        -- RestoreWindow now handles focus setting
        return true
    end

    -- If already focused, do nothing
    if self.focused_window_id == window_id then return true end

    -- Bring to front and set focus
    self:bringToFront(window_id) -- bringToFront handles the array move
    self.focused_window_id = window_id
    return true
end

-- Minimize a window
function WindowManager:minimizeWindow(window_id)
    local window_index = self:getWindowIndexById(window_id)
    if not window_index then return false end
    local window = self.windows[window_index]

    if window.is_minimized then return false end -- Already minimized

    window.is_minimized = true
    self.minimized_windows[window_id] = true -- Update separate tracking

    -- If this was focused, find the next highest non-minimized window to focus
    if self.focused_window_id == window_id then
        self.focused_window_id = nil
        for i = #self.windows, 1, -1 do
            local potential_focus = self.windows[i]
            if potential_focus.id ~= window_id and not potential_focus.is_minimized then
                 self.focused_window_id = potential_focus.id
                 break -- Found the next focus target
            end
        end
    end

    return true
end

-- Maximize a window
function WindowManager:maximizeWindow(window_id, screen_width, screen_height)
    local window_index = self:getWindowIndexById(window_id)
    if not window_index then return false end
    local window = self.windows[window_index]

    if window.is_maximized then return false end -- Already maximized

    -- Save current bounds for restore
    window.pre_maximize_bounds = {
        x = window.x,
        y = window.y,
        w = window.width,
        h = window.height
    }
    self:rememberWindowPosition(window) -- Also save to persistent memory

    -- Maximize to full screen (accounting for taskbar)
    window.x = 0
    window.y = 0
    window.width = screen_width
    window.height = screen_height - 40 -- Reserve space for taskbar
    window.is_maximized = true

    -- Ensure it's not marked as minimized and gets focus
    window.is_minimized = false
    self.minimized_windows[window_id] = nil
    self:focusWindow(window_id) -- Maximizing brings focus

    return true
end

-- Restore a window from maximized or minimized state
function WindowManager:restoreWindow(window_id)
    local window_index = self:getWindowIndexById(window_id)
    if not window_index then return false end
    local window = self.windows[window_index]

    local needs_focus = false

    -- Restore from maximized
    if window.is_maximized then
        local bounds_to_restore = window.pre_maximize_bounds or self.window_positions[window.program_type]
        if bounds_to_restore then
            window.x = bounds_to_restore.x
            window.y = bounds_to_restore.y
            window.width = bounds_to_restore.w
            window.height = bounds_to_restore.h
            window.is_maximized = false
            window.pre_maximize_bounds = nil
            needs_focus = true -- Restoring size implies bringing focus
        else
             -- Fallback if no restore bounds found (shouldn't happen often)
             window.width = 800; window.height = 600; window.x = 50; window.y = 50;
             window.is_maximized = false
             needs_focus = true
        end
    end

    -- Restore from minimized
    if window.is_minimized then
        window.is_minimized = false
        self.minimized_windows[window_id] = nil
        needs_focus = true -- Restoring visibility implies bringing focus
    end

    -- If restored, ensure it has focus and is at the front
    if needs_focus then
        self:bringToFront(window_id) -- Ensure z-order
        self.focused_window_id = window_id -- Set focus
    end

    return needs_focus -- Return true if a restore action occurred
end


-- Bring window to front (change z-order)
function WindowManager:bringToFront(window_id)
    local window_index = self:getWindowIndexById(window_id)
    if not window_index or window_index == #self.windows then return false end -- Not found or already at front

    local window = table.remove(self.windows, window_index)
    table.insert(self.windows, window) -- Insert at the end (top)
    return true
end

-- Get the topmost (focused) window that is NOT minimized
function WindowManager:getTopWindow()
    if self.focused_window_id then
        local window = self:getWindowById(self.focused_window_id)
        -- Ensure the focused window isn't actually minimized (shouldn't happen with current logic, but safe check)
        if window and not window.is_minimized then
            return window
        end
    end
    -- If no valid focused window, return the highest non-minimized window
    for i = #self.windows, 1, -1 do
         if not self.windows[i].is_minimized then
             return self.windows[i]
         end
    end
    return nil -- No visible windows
end

-- Helper to get window index by ID
function WindowManager:getWindowIndexById(window_id)
     for i, window in ipairs(self.windows) do
        if window.id == window_id then
            return i
        end
    end
    return nil
end

-- Get window by ID
function WindowManager:getWindowById(window_id)
    local index = self:getWindowIndexById(window_id)
    return index and self.windows[index] or nil
end

-- Get all windows (for taskbar display - returns in z-order, bottom to top)
function WindowManager:getAllWindows()
    return self.windows
end

-- Get focused window ID
function WindowManager:getFocusedWindowId()
    -- Ensure the focused window still exists and isn't minimized
    local window = self:getWindowById(self.focused_window_id)
    if window and not window.is_minimized then
        return self.focused_window_id
    end
    -- If current focus is invalid, try to find a new one (e.g., highest visible)
    local top_visible = self:getTopWindow()
    self.focused_window_id = top_visible and top_visible.id or nil
    return self.focused_window_id
end

-- Update window position/size
function WindowManager:updateWindowBounds(window_id, x, y, w, h)
    local window = self:getWindowById(window_id)
    if not window then return false end

    -- Only update if not maximized (unless forcing bounds, which we aren't here)
    if not window.is_maximized then
        if x then window.x = x end
        if y then window.y = y end
        if w then window.width = w end
        if h then window.height = h end
    end

    return true
end

-- Update window title
function WindowManager:updateWindowTitle(window_id, new_title)
    local window = self:getWindowById(window_id)
    if window then
        window.title = new_title
        return true
    end
    return false
end

-- Check if a program is already open (for single-instance programs)
function WindowManager:isProgramOpen(program_type)
    for _, window in ipairs(self.windows) do
        if window.program_type == program_type then
            return window.id -- Return ID of existing window
        end
    end
    return nil -- Not open
end

-- Remember window position for program type (only non-maximized)
function WindowManager:rememberWindowPosition(window)
    if not window or window.is_maximized then return end -- Don't save maximized state as default position
    self.window_positions[window.program_type] = {
        x = window.x,
        y = window.y,
        w = window.width,
        h = window.height
    }
    -- print("Remembered position for", window.program_type, ":", window.x, window.y, window.width, window.height)
end

-- Save window positions to file
function WindowManager:saveWindowPositions()
    local save_data = {
        version = SAVE_VERSION,
        positions = self.window_positions
    }

    local encode_ok, json_str = pcall(json.encode, save_data)
    if not encode_ok then
        print("Error encoding window positions: " .. tostring(json_str))
        return false
    end

    local write_ok, message = pcall(love.filesystem.write, SAVE_FILE, json_str)
    if not write_ok then
        print("Failed to write window positions file: " .. tostring(message))
        return false
    end
    print("Window positions saved.") -- Confirmation
    return true
end

-- Load window positions from file
function WindowManager:loadWindowPositions()
    local read_ok, contents = pcall(love.filesystem.read, SAVE_FILE)
    if not read_ok or not contents then
        print("No window positions file found, using defaults.")
        self.window_positions = {} -- Ensure it's empty
        return false
    end

    local decode_ok, save_data = pcall(json.decode, contents)
    if not decode_ok or type(save_data) ~= 'table' then
        print("Invalid window positions file format, using defaults.")
        self.window_positions = {}
        pcall(love.filesystem.remove, SAVE_FILE) -- Attempt to remove corrupted file
        return false
    end

    if save_data.version == SAVE_VERSION and save_data.positions then
        self.window_positions = save_data.positions
        print("Loaded window positions successfully (" .. SAVE_FILE .. ")")
        return true
    else
        print("Window positions version mismatch or data missing, using defaults.")
        self.window_positions = {}
        return false
    end
end

return WindowManager