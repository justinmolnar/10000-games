-- src/views/credits_view.lua
local BaseView = require('src.views.base_view')
local UIComponents = require('src.views.ui_components')

local CreditsView = BaseView:extend('CreditsView')

function CreditsView:init(controller)
    CreditsView.super.init(self, controller)
    self.controller = controller
    self.title = "Credits & Attributions"

    self.scroll_offset = 0
    self.max_scroll = 0
    self.content_height = 0

    self.close_button = { x = 50, y = 330, w = 200, h = 40, label = "Close" }
    self.hovered = false
end

function CreditsView:updateLayout(viewport_width, viewport_height)
    -- Update close button position (centered in button area at bottom)
    local button_height = 50
    self.close_button.y = viewport_height - button_height + 10  -- 10px padding from top of button area
    self.close_button.x = (viewport_width - self.close_button.w) / 2
end

function CreditsView:update(dt)
    local mx, my = love.mouse.getPosition()
    local view_x = self.controller.viewport and self.controller.viewport.x or 0
    local view_y = self.controller.viewport and self.controller.viewport.y or 0
    local local_mx = mx - view_x
    local local_my = my - view_y

    self.hovered = local_mx >= self.close_button.x and
                   local_mx <= self.close_button.x + self.close_button.w and
                   local_my >= self.close_button.y and
                   local_my <= self.close_button.y + self.close_button.h
end

-- Implements BaseView's abstract drawContent method
function CreditsView:drawContent(viewport_width, viewport_height)
    -- Draw background
    love.graphics.setColor(0.15, 0.15, 0.15)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(self.title, 0, 10, viewport_width, "center")

    -- Define areas
    local title_height = 30
    local button_height = 50
    local content_area_y = title_height
    local content_area_height = viewport_height - title_height - button_height

    -- Enable scissor for scrollable content area ONLY
    love.graphics.push()
    self:setScissor(0, content_area_y, viewport_width, content_area_height)
    love.graphics.translate(0, -self.scroll_offset)

    local y_pos = content_area_y
    local x_pos = 20
    local line_height = 20
    local section_gap = 20

    local attributionManager = self.controller.attributionManager

    if not attributionManager:isLoaded() then
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.print("Attribution system failed to load.", x_pos, y_pos)
        y_pos = y_pos + line_height
    elseif attributionManager:getCount() == 0 then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("No external assets attributed yet.", x_pos, y_pos)
        y_pos = y_pos + line_height
        y_pos = y_pos + line_height
        love.graphics.print("Assets will be added during Phase 2-3 of the Game Improvement Plan.", x_pos, y_pos)
    else
        -- Get attributions grouped by type
        local grouped = attributionManager:getAllGrouped()
        local type_order = {"code", "sprite", "music", "sfx", "font", "shader", "other"}
        local type_names = {
            code = "Code Libraries",
            sprite = "Graphics & Sprites",
            music = "Music",
            sfx = "Sound Effects",
            font = "Fonts",
            shader = "Shaders",
            other = "Other Assets"
        }

        for _, asset_type in ipairs(type_order) do
            local attrs = grouped[asset_type]
            if attrs and #attrs > 0 then
                -- Section header
                love.graphics.setColor(0.5, 0.8, 1)
                love.graphics.print(string.format("=== %s ===", type_names[asset_type]), x_pos, y_pos)
                y_pos = y_pos + line_height + 5

                -- List attributions in this category
                for i, attr in ipairs(attrs) do
                    love.graphics.setColor(1, 1, 1)

                    -- Asset path/name
                    local display_name = attr.asset_path
                    -- Shorten wildcard paths for display
                    if display_name:find("*") then
                        display_name = display_name:gsub("/%*", " (all files)")
                    end
                    love.graphics.print(display_name, x_pos + 10, y_pos)
                    y_pos = y_pos + line_height

                    -- Author and license
                    love.graphics.setColor(0.8, 0.8, 0.8)
                    local credit_line = string.format("  by %s  |  License: %s", attr.author, attr.license)
                    love.graphics.print(credit_line, x_pos + 20, y_pos)
                    y_pos = y_pos + line_height

                    -- Source URL (if available)
                    if attr.source_url and attr.source_url ~= "" then
                        love.graphics.setColor(0.6, 0.6, 0.6)
                        love.graphics.print("  " .. attr.source_url, x_pos + 20, y_pos)
                        y_pos = y_pos + line_height
                    end

                    -- Notes (if available)
                    if attr.notes and attr.notes ~= "" then
                        love.graphics.setColor(0.7, 0.7, 0.7)
                        love.graphics.print("  " .. attr.notes, x_pos + 20, y_pos)
                        y_pos = y_pos + line_height
                    end

                    y_pos = y_pos + 5 -- Small gap between entries
                end

                y_pos = y_pos + section_gap - 5 -- Gap between sections
            end
        end
    end

    -- Calculate content height for scroll bounds
    self.content_height = y_pos - content_area_y
    self.max_scroll = math.max(0, self.content_height - content_area_height)

    self:clearScissor()
    love.graphics.pop()

    -- Draw scrollbar if content is scrollable
    if self.max_scroll > 0 then
        self:drawScrollbar(viewport_width, content_area_y, content_area_height)
    end

    -- Close button (drawn AFTER scissor is cleared, in button area)
    love.graphics.setColor(1, 1, 1)
    UIComponents.drawButton(self.close_button.x, self.close_button.y,
                           self.close_button.w, self.close_button.h,
                           self.close_button.label, true, self.hovered)
end

function CreditsView:drawScrollbar(viewport_width, content_y, content_height)
    local scrollbar_width = 12
    local scrollbar_x = viewport_width - scrollbar_width - 5
    local scrollbar_y = content_y
    local scrollbar_height = content_height

    -- Track background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle('fill', scrollbar_x, scrollbar_y, scrollbar_width, scrollbar_height)

    -- Calculate thumb size and position
    local visible_ratio = content_height / (self.content_height + 0.01)
    local thumb_height = math.max(30, scrollbar_height * visible_ratio)
    local scroll_ratio = self.scroll_offset / self.max_scroll
    local thumb_y = scrollbar_y + (scrollbar_height - thumb_height) * scroll_ratio

    -- Thumb
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('fill', scrollbar_x, thumb_y, scrollbar_width, thumb_height)
end

function CreditsView:wheelmoved(x, y)
    local scroll_speed = 30
    self.scroll_offset = self.scroll_offset - (y * scroll_speed)
    self.scroll_offset = math.max(0, math.min(self.scroll_offset, self.max_scroll))
end

function CreditsView:mousepressed(x, y, button)
    if button ~= 1 then return nil end

    -- Check close button
    if x >= self.close_button.x and x <= self.close_button.x + self.close_button.w and
       y >= self.close_button.y and y <= self.close_button.y + self.close_button.h then
        return { name = "close" }
    end

    return nil
end

return CreditsView
