-- src/models/desktop_icons.lua
-- Model managing desktop icon positions, deletion state, and persistence

local Object = require('class')
local json = require('json')
local DesktopIcons = Object:extend('DesktopIcons')

local SAVE_FILE = "desktop_layout.json"
local SAVE_VERSION = "1.0"

function DesktopIcons:init()
    self.positions = {} -- {program_id = {x, y}}
    self.deleted = {} -- {program_id = true}
    self.layout_version = SAVE_VERSION
    
    self:load()
end

-- Set icon position
function DesktopIcons:setPosition(program_id, x, y)
    if not program_id then return false end
    
    self.positions[program_id] = {x = x, y = y}
    return true
end

-- Get icon position (returns nil if not set, caller should use default)
function DesktopIcons:getPosition(program_id)
    return self.positions[program_id]
end

-- Mark icon as deleted
function DesktopIcons:deleteIcon(program_id)
    if not program_id then return false end
    
    self.deleted[program_id] = true
    return true
end

-- Restore deleted icon
function DesktopIcons:restoreIcon(program_id)
    if not program_id then return false end
    
    self.deleted[program_id] = nil
    return true
end

-- Check if icon is deleted
function DesktopIcons:isDeleted(program_id)
    return self.deleted[program_id] == true
end

-- Get all deleted icon IDs
function DesktopIcons:getDeletedIcons()
    local deleted_list = {}
    for program_id, _ in pairs(self.deleted) do
        table.insert(deleted_list, program_id)
    end
    return deleted_list
end

-- Validate position within desktop bounds
function DesktopIcons:validatePosition(x, y, desktop_width, desktop_height, icon_width, icon_height)
    icon_width = icon_width or 80
    icon_height = icon_height or 100
    
    -- Clamp to keep icon on screen
    x = math.max(0, math.min(x, desktop_width - icon_width))
    y = math.max(0, math.min(y, desktop_height - icon_height - 40)) -- Reserve taskbar space
    
    return x, y
end

-- Clear all custom positions (reset to defaults)
function DesktopIcons:resetPositions()
    self.positions = {}
end

-- Clear deleted icons (empties recycle bin)
function DesktopIcons:permanentlyDeleteAll()
    -- Keep deleted state but clear positions
    for program_id, _ in pairs(self.deleted) do
        self.positions[program_id] = nil
    end
end

-- Save layout to file
function DesktopIcons:save()
    local save_data = {
        version = self.layout_version,
        positions = self.positions,
        deleted = self.deleted
    }
    
    local encode_ok, json_str = pcall(json.encode, save_data)
    if not encode_ok then
        print("Error encoding desktop layout: " .. tostring(json_str))
        return false
    end
    
    local write_ok, message = pcall(love.filesystem.write, SAVE_FILE, json_str)
    if not write_ok then
        print("Failed to write desktop layout file: " .. tostring(message))
        return false
    end
    
    return true
end

-- Load layout from file
function DesktopIcons:load()
    local read_ok, contents = pcall(love.filesystem.read, SAVE_FILE)
    if not read_ok or not contents then
        print("No desktop layout file found, using defaults")
        return false
    end
    
    local decode_ok, save_data = pcall(json.decode, contents)
    if not decode_ok or type(save_data) ~= 'table' then
        print("Invalid desktop layout file format")
        return false
    end
    
    if save_data.version == SAVE_VERSION then
        self.positions = save_data.positions or {}
        self.deleted = save_data.deleted or {}
        print("Loaded desktop layout successfully")
        return true
    end
    
    print("Desktop layout version mismatch, using defaults")
    return false
end

return DesktopIcons