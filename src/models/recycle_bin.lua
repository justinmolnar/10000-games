-- src/models/recycle_bin.lua
-- Model managing deleted desktop icons and their restoration

local Object = require('class')
local json = require('json')
local RecycleBin = Object:extend('RecycleBin')

function RecycleBin:init(desktop_icons_model)
    if not desktop_icons_model then
        error("RecycleBin requires DesktopIcons model instance.")
    end
    self.desktop_icons = desktop_icons_model -- Dependency injection
    self.items = {} -- Array of {program_id, original_position, deleted_at}
    self._SAVE_FILE = 'recycle_bin.json'
    self:_load()
end

-- Add item to recycle bin
function RecycleBin:addItem(program_id, original_position)
    if not program_id then return false end

    -- Check if already in bin
    for _, item in ipairs(self.items) do
        if item.program_id == program_id then
            return false -- Already in bin
        end
    end

    table.insert(self.items, {
        program_id = program_id,
        original_position = original_position, -- Store {x, y} or nil
        deleted_at = os.time()
    })

    -- Mark as deleted in desktop icons model
    self.desktop_icons:deleteIcon(program_id)

    self:_save()
    return true
end

-- Restore item from recycle bin
function RecycleBin:restoreItem(program_id, screen_w, screen_h)
    for i = #self.items, 1, -1 do
        if self.items[i].program_id == program_id then
            local item = table.remove(self.items, i)

            -- Unmark as deleted *before* setting position
            self.desktop_icons:restoreIcon(program_id)

            -- Restore to original position if available and valid
            if item.original_position then
                -- Use provided screen dimensions for validation
                self.desktop_icons:setPosition(program_id, item.original_position.x, item.original_position.y, screen_w, screen_h)
            end
            -- If no original position, it will appear in default grid on next view calc

            self:_save()
            return true
        end
    end
    return false
end

-- Empty recycle bin (permanent deletion)
function RecycleBin:empty()
    local count = #self.items

    for _, item in ipairs(self.items) do
        self.desktop_icons:permanentlyDelete(item.program_id)
    end
    self.items = {}

    -- Save desktop layout to persist permanent deletion
    self.desktop_icons:save()
    self:_save()

    return count
end

-- Get all items in recycle bin
function RecycleBin:getItems()
    -- Return a copy to prevent external modification? For now, return direct reference.
    return self.items
end

-- Get count of items in bin
function RecycleBin:getCount()
    return #self.items
end

-- Check if bin is empty
function RecycleBin:isEmpty()
    return #self.items == 0
end

-- Remove specific item without restoring (permanent delete)
function RecycleBin:permanentlyDelete(program_id)
    for i = #self.items, 1, -1 do
        if self.items[i].program_id == program_id then
            table.remove(self.items, i)
            -- Also mark in desktop_icons model
            self.desktop_icons:permanentlyDelete(program_id)
            self.desktop_icons:save() -- Persist change
            self:_save()
            return true
        end
    end
    return false
end

-- Persistence helpers
function RecycleBin:_load()
    local ok, contents = pcall(love.filesystem.read, self._SAVE_FILE)
    if not ok or not contents or contents == '' then return end
    local dec_ok, data = pcall(json.decode, contents)
    if not dec_ok or type(data) ~= 'table' then return end
    -- Validate minimal structure
    if type(data.items) == 'table' then self.items = data.items end
    -- Ensure desktop icons model reflects deleted state for loaded items
    for _, it in ipairs(self.items or {}) do
        if it.program_id then pcall(self.desktop_icons.deleteIcon, self.desktop_icons, it.program_id) end
    end
end

function RecycleBin:_save()
    local data = { items = self.items }
    local enc_ok, out = pcall(json.encode, data)
    if not enc_ok then return false end
    local ok, err = pcall(love.filesystem.write, self._SAVE_FILE, out)
    if not ok then print('ERROR writing recycle_bin.json: '..tostring(err)); return false end
    return true
end

return RecycleBin