-- src/views/context_menu_view.lua
local Object = require('class')
local ContextMenuView = Object:extend('ContextMenuView')

function ContextMenuView:init()
    self.menu_x = 0
    self.menu_y = 0
    self.menu_w = 180 -- Default width
    self.menu_h = 0 -- Calculated based on options
    self.options = {} -- { id = "action_id", label = "Display Text", enabled = true }
    self.item_height = 22
    self.padding = 4
    self.hovered_option_index = nil
end

-- Update hover state based on global mouse position
function ContextMenuView:update(dt, options, x, y)
    self.options = options or {}
    self.menu_x = x
    self.menu_y = y
    self.menu_h = #self.options * self.item_height + self.padding * 2
    self.menu_w = 180 -- Keep width fixed for now

    local mx, my = love.mouse.getPosition()
    self.hovered_option_index = nil

    if mx >= self.menu_x and mx <= self.menu_x + self.menu_w and
       my >= self.menu_y and my <= self.menu_y + self.menu_h then
        local relative_y = my - (self.menu_y + self.padding)
        if relative_y >= 0 then
            local index = math.floor(relative_y / self.item_height) + 1
            if index >= 1 and index <= #self.options then
                 -- Check if the option is enabled before highlighting
                 if self.options[index].enabled ~= false then
                    self.hovered_option_index = index
                 end
            end
        end
    end
end

-- Draw the menu
function ContextMenuView:draw()
    if #self.options == 0 then return end -- Don't draw if no options

    -- Background
    love.graphics.setColor(0.85, 0.85, 0.85) -- Light grey background
    love.graphics.rectangle('fill', self.menu_x, self.menu_y, self.menu_w, self.menu_h)

    -- Border (Win98 style)
    love.graphics.setColor(1, 1, 1); love.graphics.line(self.menu_x, self.menu_y, self.menu_x + self.menu_w, self.menu_y); love.graphics.line(self.menu_x, self.menu_y, self.menu_x, self.menu_y + self.menu_h)
    love.graphics.setColor(0.5, 0.5, 0.5); love.graphics.line(self.menu_x + self.menu_w, self.menu_y + 1, self.menu_x + self.menu_w, self.menu_y + self.menu_h); love.graphics.line(self.menu_x + 1, self.menu_y + self.menu_h, self.menu_x + self.menu_w, self.menu_y + self.menu_h)
    love.graphics.setColor(0.1, 0.1, 0.1); love.graphics.rectangle('line', self.menu_x + 1, self.menu_y + 1, self.menu_w - 2, self.menu_h - 2)

    -- Draw Options
    local current_y = self.menu_y + self.padding
    for i, option in ipairs(self.options) do
        local is_hovered = (i == self.hovered_option_index)
        local is_enabled = (option.enabled ~= false) -- Default to true if nil
        local is_separator = option.is_separator

        if is_separator then
            -- Draw separator line
            love.graphics.setColor(0.5, 0.5, 0.5) -- Dark grey shadow
            love.graphics.line(self.menu_x + self.padding, current_y + self.item_height / 2, self.menu_x + self.menu_w - self.padding, current_y + self.item_height / 2)
            love.graphics.setColor(1, 1, 1) -- White highlight
            love.graphics.line(self.menu_x + self.padding, current_y + self.item_height / 2 + 1, self.menu_x + self.menu_w - self.padding, current_y + self.item_height / 2 + 1)
        else
            -- Highlight background if hovered
            if is_hovered and is_enabled then
                love.graphics.setColor(0, 0, 0.5) -- Dark blue highlight
                love.graphics.rectangle('fill', self.menu_x + self.padding, current_y, self.menu_w - self.padding * 2, self.item_height)
            end

            -- Text color
            if not is_enabled then love.graphics.setColor(0.5, 0.5, 0.5) -- Grey out disabled text
            elseif is_hovered then love.graphics.setColor(1, 1, 1) -- White text on highlight
            else love.graphics.setColor(0, 0, 0) end -- Black text

            love.graphics.print(option.label, self.menu_x + self.padding + 5, current_y + 3)
        end
        current_y = current_y + self.item_height
    end
end

-- Check if a click occurred on an option, returns the option index or nil
function ContextMenuView:getClickedOptionIndex(click_x, click_y)
    if click_x >= self.menu_x and click_x <= self.menu_x + self.menu_w and
       click_y >= self.menu_y and click_y <= self.menu_y + self.menu_h then
        local relative_y = click_y - (self.menu_y + self.padding)
        if relative_y >= 0 then
            local index = math.floor(relative_y / self.item_height) + 1
            if index >= 1 and index <= #self.options then
                 -- Only return index if the option is enabled
                 if self.options[index].enabled ~= false then
                    return index
                 end
            end
        end
        -- Clicked inside menu bounds but not on an enabled item (or padding)
        return -1 -- Indicate click was inside but invalid target
    end
    return nil -- Click was outside menu bounds
end

return ContextMenuView