-- src/models/desktop_icons.lua
-- Model managing desktop icon positions, deletion state, and persistence

local Object = require('class')
local json = require('json')
local DesktopIcons = Object:extend('DesktopIcons')

local SAVE_FILE = "desktop_layout.json"
local SAVE_VERSION = "1.0"

-- Define icon dimensions centrally
local ICON_WIDTH = 80
local ICON_HEIGHT = 100
local TASKBAR_HEIGHT = 40 -- Assumed taskbar height for validation

function DesktopIcons:init(di)
    self.positions = {} -- {program_id = {x, y}}
    self.deleted = {} -- {program_id = true}
    self.layout_version = SAVE_VERSION
    self.event_bus = (di and di.eventBus) or (rawget(_G, 'DI') and rawget(_G, 'DI').eventBus)

    self:load()

    if self.event_bus then
        self:subscribeToEvents()
    end
end

function DesktopIcons:subscribeToEvents()
    self._subscriptions = {}
    self._subscriptions[#self._subscriptions + 1] = self.event_bus:subscribe('request_icon_move', function(prog_id, x, y, w, h) self:setPosition(prog_id, x, y, w, h) end)
    self._subscriptions[#self._subscriptions + 1] = self.event_bus:subscribe('request_icon_delete', function(prog_id) self:deleteIcon(prog_id) end)
    self._subscriptions[#self._subscriptions + 1] = self.event_bus:subscribe('request_icon_restore', function(prog_id) self:restoreIcon(prog_id) end)
    self._subscriptions[#self._subscriptions + 1] = self.event_bus:subscribe('request_icon_create', function(prog_id, x, y, w, h)
        self:restoreIcon(prog_id)
        self:setPosition(prog_id, x, y, w, h)
    end)
    self._subscriptions[#self._subscriptions + 1] = self.event_bus:subscribe('display_resolution_changed', function(w, h)
        self:revalidatePositions(w, h)
    end)
end

function DesktopIcons:destroy()
    if self.event_bus and self._subscriptions then
        for _, id in ipairs(self._subscriptions) do
            self.event_bus:unsubscribe(id)
        end
    end
    self._subscriptions = nil
end

-- Helper to get standard icon dimensions
function DesktopIcons:getIconDimensions()
    return ICON_WIDTH, ICON_HEIGHT
end

-- Set icon position after validation
function DesktopIcons:setPosition(program_id, x, y, desktop_width, desktop_height)
    if not program_id then return false end

    local valid_x, valid_y = self:validatePosition(x, y, desktop_width, desktop_height)
    local old_pos = self.positions[program_id]

    self.positions[program_id] = {x = valid_x, y = valid_y}

    if self.event_bus then
        local old_x = old_pos and old_pos.x or valid_x
        local old_y = old_pos and old_pos.y or valid_y
        self.event_bus:publish('icon_moved', program_id, old_x, old_y, valid_x, valid_y)
    end

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

    if self.event_bus then
        self.event_bus:publish('icon_deleted', program_id)
    end

    return true
end

-- Restore deleted icon
function DesktopIcons:restoreIcon(program_id)
    if not program_id then return false end

    self.deleted[program_id] = nil

    if self.event_bus then
        self.event_bus:publish('icon_restored', program_id)
    end

    return true
end

-- Check if icon is deleted
function DesktopIcons:isDeleted(program_id)
    return self.deleted[program_id] == true
end

-- Get all deleted icon IDs (used by Recycle Bin model logic, maybe not directly needed)
function DesktopIcons:getDeletedIcons()
    local deleted_list = {}
    for program_id, deleted in pairs(self.deleted) do
        if deleted then -- Ensure it's explicitly true
            table.insert(deleted_list, program_id)
        end
    end
    return deleted_list
end

-- Validate position within desktop bounds
function DesktopIcons:validatePosition(x, y, desktop_width, desktop_height)
    -- Use constants for dimensions
    local icon_w, icon_h = self:getIconDimensions()

    -- Clamp to keep icon fully on screen, accounting for taskbar
    -- Require desktop dimensions from caller to avoid coupling to graphics API
    x = math.max(0, math.min(x or 0, (desktop_width or 0) - icon_w))
    y = math.max(0, math.min(y or 0, (desktop_height or 0) - icon_h - TASKBAR_HEIGHT))

    return x, y
end


-- Revalidate all icon positions against current screen dimensions
-- Called when resolution changes to pull off-screen icons back into view
function DesktopIcons:revalidatePositions(desktop_width, desktop_height)
    if not desktop_width or not desktop_height then return end
    local icon_w, icon_h = self:getIconDimensions()
    local changed = false

    for program_id, pos in pairs(self.positions) do
        local old_x, old_y = pos.x, pos.y
        local new_x, new_y = self:validatePosition(old_x, old_y, desktop_width, desktop_height)
        if new_x ~= old_x or new_y ~= old_y then
            pos.x = new_x
            pos.y = new_y
            changed = true
        end
    end

    if changed then
        self:resolveOverlaps(desktop_width, desktop_height)
        self:save()
    end
end

-- Nudge overlapping icons to nearby free grid cells
function DesktopIcons:resolveOverlaps(desktop_width, desktop_height)
    local icon_w, icon_h = self:getIconDimensions()
    local cell_w = icon_w + 20
    local cell_h = icon_h + 20

    -- Build occupancy set from current positions
    local occupied = {}
    local id_order = {}
    for pid, pos in pairs(self.positions) do
        table.insert(id_order, pid)
    end
    table.sort(id_order)

    for _, pid in ipairs(id_order) do
        local pos = self.positions[pid]
        -- Snap to nearest grid cell
        local gx = math.floor((pos.x + cell_w / 2) / cell_w)
        local gy = math.floor((pos.y + cell_h / 2) / cell_h)
        local key = gx .. "," .. gy

        if occupied[key] then
            -- Find nearest free cell
            local found = false
            for radius = 1, 20 do
                for dy = -radius, radius do
                    for dx = -radius, radius do
                        if math.abs(dx) == radius or math.abs(dy) == radius then
                            local nx, ny = gx + dx, gy + dy
                            local nk = nx .. "," .. ny
                            local px = nx * cell_w
                            local py = ny * cell_h
                            if not occupied[nk] and px >= 0 and py >= 0 and
                               px + icon_w <= desktop_width and
                               py + icon_h <= (desktop_height - TASKBAR_HEIGHT) then
                                pos.x = px
                                pos.y = py
                                occupied[nk] = pid
                                found = true
                                break
                            end
                        end
                    end
                    if found then break end
                end
                if found then break end
            end
            if not found then
                occupied[key] = pid
            end
        else
            occupied[key] = pid
        end
    end
end

-- Clear all custom positions (reset to defaults)
function DesktopIcons:resetPositions()
    self.positions = {}
end

-- Permanently delete icons (used by Recycle Bin empty)
function DesktopIcons:permanentlyDelete(program_id)
    if self.deleted[program_id] then
        self.positions[program_id] = nil -- Clear position for permanently deleted icon
        -- Keep self.deleted[program_id] = true
        return true
    end
    return false
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
        print("Invalid desktop layout file format, using defaults")
        -- Attempt to delete corrupted file? Risky. Better to just use defaults.
        return false
    end

    if save_data.version == SAVE_VERSION then
        self.positions = save_data.positions or {}
        self.deleted = save_data.deleted or {}
        print("Loaded desktop layout successfully")
        return true
    else
        -- Handle potential version mismatch (e.g., migration logic)
        print("Desktop layout version mismatch (" .. tostring(save_data.version) .. " vs " .. SAVE_VERSION .. "), using defaults")
        -- Optionally try to migrate data here if needed in the future
        return false
    end
end

-- Check if icon is currently visible (not deleted)
function DesktopIcons:isIconVisible(program_id)
    if not program_id then return false end
    -- Visible if it's not explicitly marked as deleted
    return self.deleted[program_id] ~= true
end

return DesktopIcons