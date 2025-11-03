-- src/controllers/scrollbar_controller.lua
-- Self-contained scrollbar controller with built-in state management
-- Handles drag state, coordinate conversion, and mouse interaction internally

local Object = require('lib.class')
local UIComponents = require('src.views.ui_components')

local ScrollbarController = Object:extend('ScrollbarController')

function ScrollbarController:init(params)
    params = params or {}

    -- Configuration
    self.unit_size = params.unit_size or 1 -- Size of one scrollable unit in pixels (e.g., item height)
    self.step_units = params.step_units or 1 -- How many units to scroll per arrow click
    self.always_visible = params.always_visible or false -- Show scrollbar even when content doesn't scroll

    -- State
    self.geometry = nil
    self.dragging = false
    self.drag_state = nil

    -- Position tracking (in local coordinates relative to scrollbar)
    self.offset_x = params.offset_x or 0 -- X offset where scrollbar is drawn
    self.offset_y = params.offset_y or 0 -- Y offset where scrollbar is drawn
end

-- Compute geometry and return it for drawing
-- offset: Current scroll position in YOUR units (items, lines, pixels, etc.)
-- max_offset: Maximum scroll position in YOUR units
-- Returns: geometry table for UIComponents.drawScrollbar, or nil if no scrollbar needed
function ScrollbarController:compute(viewport_w, viewport_h, content_height_px, offset, max_offset)
    -- Convert offset from units to pixels
    local offset_px = offset * self.unit_size
    local max_offset_px = max_offset * self.unit_size

    -- Compute content height if not provided
    if not content_height_px then
        content_height_px = viewport_h + max_offset_px
    end

    self.geometry = UIComponents.computeScrollbar({
        viewport_w = viewport_w,
        viewport_h = viewport_h,
        content_h = content_height_px,
        offset = offset_px,
        alwaysVisible = self.always_visible
    })

    return self.geometry
end

-- Handle mouse press
-- offset: Current scroll position in YOUR units
-- Returns: { scrolled = true, new_offset = N } if scroll changed, or nil if not consumed
function ScrollbarController:mousepressed(x, y, button, offset)
    if not self.geometry or button ~= 1 then
        return nil
    end

    -- Convert to local coordinates relative to scrollbar position
    local lx = x - self.offset_x
    local ly = y - self.offset_y

    -- Convert offset from units to pixels
    local current_offset_px = (offset or 0) * self.unit_size

    -- Calculate step size in pixels
    local step_px = self.step_units * self.unit_size

    local result = UIComponents.scrollbarHandlePress(lx, ly, button, self.geometry, current_offset_px, step_px)

    if result and result.consumed then
        if result.drag then
            self.dragging = true
            self.drag_state = result.drag
        end

        if result.new_offset_px ~= nil then
            -- Convert back to units
            local new_offset = result.new_offset_px / self.unit_size
            return { scrolled = true, new_offset = new_offset }
        end

        -- Consumed but no scroll change (e.g., started dragging)
        return { scrolled = false }
    end

    return nil
end

-- Handle mouse move (for dragging)
-- Returns: { scrolled = true, new_offset = N } if scroll changed, or nil if not dragging
function ScrollbarController:mousemoved(x, y, dx, dy)
    if not self.dragging or not self.drag_state or not self.geometry then
        return nil
    end

    -- Convert to local coordinates
    local ly = y - self.offset_y

    local result = UIComponents.scrollbarHandleMove(ly, self.drag_state, self.geometry)

    if result and result.new_offset_px ~= nil then
        -- Convert back to units
        local new_offset = result.new_offset_px / self.unit_size
        return { scrolled = true, new_offset = new_offset }
    end

    return nil
end

-- Handle mouse release (end dragging)
function ScrollbarController:mousereleased(x, y, button)
    if button == 1 and self.dragging then
        self.dragging = false
        self.drag_state = nil
        return true
    end
    return false
end

-- Set the position offset where this scrollbar is drawn
-- Useful when scrollbar is in a translated coordinate space
function ScrollbarController:setPosition(x, y)
    self.offset_x = x or 0
    self.offset_y = y or 0
end

-- Check if currently dragging
function ScrollbarController:isDragging()
    return self.dragging
end

return ScrollbarController
