-- src/models/recycle_bin.lua
-- Model managing deleted desktop icons and their restoration

local Object = require('class')
local RecycleBin = Object:extend('RecycleBin')

function RecycleBin:init(desktop_icons_model)
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
        original_position = original_position, -- {x, y} or nil
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
            
            -- Restore to original position if available
            if item.original_position then
                self.desktop_icons:setPosition(program_id, item.original_position.x, item.original_position.y)
            end
            
            -- Unmark as deleted
            self.desktop_icons:restoreIcon(program_id)
            
            return true
        end
    end
    return false
end

-- Empty recycle bin (permanent deletion)
function RecycleBin:empty()
    local count = #self.items
    
    -- Icons remain marked as deleted in desktop_icons model
    -- Just clear the recycle bin list
    self.items = {}
    
    -- Save desktop layout to persist deletion
    self.desktop_icons:save()
    
    return count
end

-- Get all items in recycle bin
function RecycleBin:getItems()
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
            return true
        end
    end
    return false
end

return RecycleBin