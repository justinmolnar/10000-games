-- src/models/recycle_bin.lua
-- Model managing deleted desktop icons and their restoration

local Object = require('class')
local RecycleBin = Object:extend('RecycleBin')

function RecycleBin:init(desktop_icons_model)
    if not desktop_icons_model then
        error("RecycleBin requires DesktopIcons model instance.")
    end
    self.desktop_icons = desktop_icons_model -- Dependency injection
    self.items = {} -- Array of {program_id, original_position, deleted_at}
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

    return true
end

-- Restore item from recycle bin
function RecycleBin:restoreItem(program_id)
    for i = #self.items, 1, -1 do
        if self.items[i].program_id == program_id then
            local item = table.remove(self.items, i)

            -- Unmark as deleted *before* setting position
            self.desktop_icons:restoreIcon(program_id)

            -- Restore to original position if available and valid
            if item.original_position then
                -- Pass screen dimensions for validation
                local screen_w, screen_h = love.graphics.getDimensions()
                self.desktop_icons:setPosition(program_id, item.original_position.x, item.original_position.y, screen_w, screen_h)
            end
            -- If no original position, it will appear in default grid on next view calc

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
            return true
        end
    end
    return false
end

return RecycleBin