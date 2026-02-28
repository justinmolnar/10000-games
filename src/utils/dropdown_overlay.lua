-- src/utils/dropdown_overlay.lua
-- Reusable dropdown overlay service. Renders above windows (outside scissor).
-- Any component can open a dropdown via di.dropdownOverlay:open(...)

local Object = require('class')
local UI = require('src.views.ui_components')

local DropdownOverlay = Object:extend('DropdownOverlay')

function DropdownOverlay:init()
    self._open = false
    self._x = 0
    self._y = 0
    self._w = 160
    self._item_h = 22
    self._labels = {}
    self._selected_idx = nil
    self._on_select = nil
    self._on_close = nil
end

function DropdownOverlay:isOpen()
    return self._open
end

--- Open a dropdown list at screen coordinates.
-- @param opts table { x, y, w, item_h, choices, current, on_select, on_close }
--   choices: array of {label, value} tables or plain strings
--   current: current value (for highlighting)
--   on_select: function(value) called when an item is picked
--   on_close: function() called when dismissed without selection (optional)
function DropdownOverlay:open(opts)
    self._x = opts.x or 0
    self._y = opts.y or 0
    self._w = opts.w or 160
    self._item_h = opts.item_h or 22
    self._on_select = opts.on_select
    self._on_close = opts.on_close
    self._choices = opts.choices or {}

    self._labels = {}
    self._selected_idx = nil
    for i, c in ipairs(self._choices) do
        if type(c) == 'table' then
            table.insert(self._labels, c.label)
            if c.value == opts.current then self._selected_idx = i end
        else
            table.insert(self._labels, tostring(c))
            if tostring(c) == tostring(opts.current) then self._selected_idx = i end
        end
    end

    -- Clamp to screen bounds
    local screen_w, screen_h = love.graphics.getDimensions()
    local list_h = #self._labels * self._item_h
    if self._x + self._w > screen_w then self._x = screen_w - self._w end
    if self._y + list_h > screen_h then self._y = screen_h - list_h end
    self._x = math.max(0, self._x)
    self._y = math.max(0, self._y)

    self._open = true
end

function DropdownOverlay:close()
    if not self._open then return end
    self._open = false
    if self._on_close then self._on_close() end
    self._on_select = nil
    self._on_close = nil
    self._choices = nil
end

function DropdownOverlay:draw()
    if not self._open then return end
    UI.drawDropdownList(self._x, self._y, self._w, self._item_h, self._labels, self._selected_idx)
end

--- Handle mouse press. Returns true if the click was consumed.
function DropdownOverlay:mousepressed(x, y, button)
    if not self._open then return false end

    local list_h = #self._labels * self._item_h
    if button == 1 and x >= self._x and x <= self._x + self._w and y >= self._y and y <= self._y + list_h then
        local idx = math.floor((y - self._y) / self._item_h) + 1
        if idx >= 1 and idx <= #self._labels then
            local c = self._choices[idx]
            local value = type(c) == 'table' and c.value or c
            local cb = self._on_select
            self._open = false
            self._on_select = nil
            self._on_close = nil
            self._choices = nil
            if cb then cb(value) end
        end
        return true
    end

    -- Click outside — close and consume
    self:close()
    return true
end

return DropdownOverlay
