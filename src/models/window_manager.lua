-- src/models/window_manager.lua
-- Model managing all open windows, z-order, focus, and window state

local Object = require('class')
local json = require('json')
local WindowManager = Object:extend('WindowManager')

local SAVE_FILE = "window_positions.json"
local SAVE_VERSION = "1.0"

function WindowManager:init()
    self.windows = {} -- Array for z-order (index 1 = bottom, last = top)
    self.focused_window_id = nil
    self.next_window_id = 1
    self.minimized_windows = {} -- {window_id = true}
    self.window_positions = {} -- {program_type = {x, y, w, h}}
    
    self:loadWindowPositions()
end

-- Create a new window
function WindowManager:createWindow(program_type, title, content_state, x, y, w, h)
    local window_id = self.next_window_id
    self.next_window_id = self.next_window_id + 1
    
    -- Use remembered position if available
    local remembered = self.window_positions[program_type]
    if remembered then
        x = remembered.x or x
        y = remembered.y or y
        w = remembered.w or w
        h = remembered.h or h
    end
    
    local window = {
        id = window_id,
        program_type = program_type,
        title = title,
        content_state = content_state,
        x = x,
        y = y,
        width = w,
        height = h,
        is_maximized = false,
        pre_maximize_bounds = nil, -- {x, y, w, h}
        is_minimized = false
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
            
            -- Remember position for this program type
            if not window.is_maximized then
                self:rememberWindowPosition(window)
            end
            
            -- Clear minimized state
            self.minimized_windows[window_id] = nil
            
            -- If this was focused, focus next window
            if self.focused_window_id == window_id then
                if #self.windows > 0 then
                    self.focused_window_id = self.windows[#self.windows].id
                else
                    self.focused_window_id = nil
                end
            end
            
            return true
        end
    end
    return false
end

-- Focus a window (brings to front)
function WindowManager:focusWindow(window_id)
    local window = self:getWindowById(window_id)
    if not window then return false end
    
    -- If minimized, restore it first
    if window.is_minimized then
        self:restoreWindow(window_id)
    end
    
    self:bringToFront(window_id)
    self.focused_window_id = window_id
    return true
end

-- Minimize a window
function WindowManager:minimizeWindow(window_id)
    local window = self:getWindowById(window_id)
    if not window then return false end
    
    window.is_minimized = true
    self.minimized_windows[window_id] = true
    
    -- If this was focused, focus next non-minimized window
    if self.focused_window_id == window_id then
        self.focused_window_id = nil
        for i = #self.windows, 1, -1 do
            if not self.windows[i].is_minimized then
                self.focused_window_id = self.windows[i].id
                break
            end
        end
    end
    
    return true
end

-- Maximize a window
function WindowManager:maximizeWindow(window_id, screen_width, screen_height)
    local window = self:getWindowById(window_id)
    if not window or window.is_maximized then return false end
    
    -- Save current bounds for restore
    window.pre_maximize_bounds = {
        x = window.x,
        y = window.y,
        w = window.width,
        h = window.height
    }
    
    -- Maximize to full screen (accounting for taskbar)
    window.x = 0
    window.y = 0
    window.width = screen_width
    window.height = screen_height - 40 -- Reserve space for taskbar
    window.is_maximized = true
    
    return true
end

-- Restore a window from maximized or minimized
function WindowManager:restoreWindow(window_id)
    local window = self:getWindowById(window_id)
    if not window then return false end
    
    -- Restore from maximized
    if window.is_maximized and window.pre_maximize_bounds then
        window.x = window.pre_maximize_bounds.x
        window.y = window.pre_maximize_bounds.y
        window.width = window.pre_maximize_bounds.w
        window.height = window.pre_maximize_bounds.h
        window.is_maximized = false
        window.pre_maximize_bounds = nil
    end
    
    -- Restore from minimized
    if window.is_minimized then
        window.is_minimized = false
        self.minimized_windows[window_id] = nil
    end
    
    return true
end

-- Bring window to front (change z-order)
function WindowManager:bringToFront(window_id)
    for i = 1, #self.windows do
        if self.windows[i].id == window_id then
            local window = table.remove(self.windows, i)
            table.insert(self.windows, window)
            return true
        end
    end
    return false
end

-- Get the topmost (focused) window
function WindowManager:getTopWindow()
    if #self.windows == 0 then return nil end
    
    -- Return topmost non-minimized window
    for i = #self.windows, 1, -1 do
        if not self.windows[i].is_minimized then
            return self.windows[i]
        end
    end
    
    return nil
end

-- Get window by ID
function WindowManager:getWindowById(window_id)
    for _, window in ipairs(self.windows) do
        if window.id == window_id then
            return window
        end
    end
    return nil
end

-- Get all windows (for taskbar display)
function WindowManager:getAllWindows()
    return self.windows
end

-- Get focused window ID
function WindowManager:getFocusedWindowId()
    return self.focused_window_id
end

-- Update window position/size
function WindowManager:updateWindowBounds(window_id, x, y, w, h)
    local window = self:getWindowById(window_id)
    if not window then return false end
    
    if x then window.x = x end
    if y then window.y = y end
    if w then window.width = w end
    if h then window.height = h end
    
    return true
end

-- Check if a program is already open (for single-instance programs)
function WindowManager:isProgramOpen(program_type)
    for _, window in ipairs(self.windows) do
        if window.program_type == program_type then
            return window.id
        end
    end
    return nil
end

-- Remember window position for program type
function WindowManager:rememberWindowPosition(window)
    self.window_positions[window.program_type] = {
        x = window.x,
        y = window.y,
        w = window.width,
        h = window.height
    }
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
    
    return true
end

-- Load window positions from file
function WindowManager:loadWindowPositions()
    local read_ok, contents = pcall(love.filesystem.read, SAVE_FILE)
    if not read_ok or not contents then
        print("No window positions file found, using defaults")
        return false
    end
    
    local decode_ok, save_data = pcall(json.decode, contents)
    if not decode_ok or type(save_data) ~= 'table' then
        print("Invalid window positions file format")
        return false
    end
    
    if save_data.version == SAVE_VERSION and save_data.positions then
        self.window_positions = save_data.positions
        print("Loaded window positions successfully")
        return true
    end
    
    return false
end

return WindowManager