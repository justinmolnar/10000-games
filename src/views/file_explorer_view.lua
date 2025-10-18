-- src/views/file_explorer_view.lua
-- View for rendering file explorer interface

local Object = require('class')
local UIComponents = require('src.views.ui_components')

local FileExplorerView = Object:extend('FileExplorerView')

function FileExplorerView:init(controller)
    self.controller = controller

    -- Layout constants
    self.toolbar_height = 35
    self.address_bar_height = 25
    self.status_bar_height = 20
    self.item_height = 25
    self.scroll_offset = 0

    -- Hover state
    self.hovered_item = nil
    self.hovered_button = nil

    -- Click tracking for double-click
    self.last_click_item = nil
    self.last_click_time = 0
end

function FileExplorerView:updateLayout(width, height)
    -- Layout adjusts automatically based on viewport
end

 function FileExplorerView:resetScroll()
    self.scroll_offset = 0
end

function FileExplorerView:update(dt, viewport_width, viewport_height)
    -- Update hover state based on local coordinates
    local mx, my = love.mouse.getPosition()
    local view_x = self.controller.viewport and self.controller.viewport.x or 0
    local view_y = self.controller.viewport and self.controller.viewport.y or 0
    local local_mx = mx - view_x
    local local_my = my - view_y

    self.hovered_item = nil
    self.hovered_button = nil

    -- Check if mouse is within viewport
    if local_mx < 0 or local_mx > viewport_width or local_my < 0 or local_my > viewport_height then
        return
    end

    -- Check toolbar buttons (pass is_recycle_bin context)
    local is_recycle_bin = (self.controller.current_path == "/Recycle Bin")
    self.hovered_button = self:getButtonAtPosition(local_mx, local_my, is_recycle_bin)

    -- Check item hover in the content area
    local content_y = self.toolbar_height + self.address_bar_height
    local content_h = viewport_height - content_y - self.status_bar_height
    local current_view_items = self.controller:getCurrentViewContents() -- Need content to check hover
    self.hovered_item = self:getItemAtPosition(local_mx, local_my, current_view_items, content_y, content_h, viewport_width)
end


function FileExplorerView:drawWindowed(current_path, contents, selected_item, view_mode, sort_by, sort_order, can_go_back, can_go_forward, is_recycle_bin, viewport_width, viewport_height)
    -- Background
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)

    -- Toolbar (pass is_recycle_bin)
    self:drawToolbar(0, 0, viewport_width, can_go_back, can_go_forward, is_recycle_bin)

    -- Address bar
    self:drawAddressBar(0, self.toolbar_height, viewport_width, current_path)

    -- Content area
    local content_y = self.toolbar_height + self.address_bar_height
    local content_h = viewport_height - content_y - self.status_bar_height

    -- Draw items or messages
    if contents and type(contents) == "table" and #contents > 0 then
        self:drawItemList(0, content_y, viewport_width, content_h, contents, selected_item, view_mode)
    elseif is_recycle_bin and (not contents or #contents == 0) then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("The Recycle Bin is empty", 10, content_y + 10, viewport_width - 20, "center")
    elseif contents and contents.type == "special" then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("Special folder view", 10, content_y + 10, viewport_width - 20, "center")
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("This folder is empty", 10, content_y + 10, viewport_width - 20, "center")
    end

    -- Status bar
    self:drawStatusBar(0, viewport_height - self.status_bar_height, viewport_width, contents)
end

function FileExplorerView:drawToolbar(x, y, width, can_go_back, can_go_forward, is_recycle_bin)
    -- Toolbar background
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle('fill', x, y, width, self.toolbar_height)

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.line(x, y + self.toolbar_height, x + width, y + self.toolbar_height)

    local btn_x = x + 5
    local btn_y = y + 5
    local btn_w = 25
    local btn_h = 25
    local btn_spacing = 5

    -- Back button
    local back_enabled = can_go_back
    local back_hovered = (self.hovered_button == "back")
    self:drawToolbarButton(btn_x, btn_y, btn_w, btn_h, "<", back_enabled, back_hovered)
    btn_x = btn_x + btn_w + btn_spacing

    -- Forward button
    local forward_enabled = can_go_forward
    local forward_hovered = (self.hovered_button == "forward")
    self:drawToolbarButton(btn_x, btn_y, btn_w, btn_h, ">", forward_enabled, forward_hovered)
    btn_x = btn_x + btn_w + btn_spacing

    -- Up button
    local up_enabled = self.controller.current_path ~= "/" -- Disable at root
    local up_hovered = (self.hovered_button == "up")
    self:drawToolbarButton(btn_x, btn_y, btn_w, btn_h, "^", up_enabled, up_hovered)
    btn_x = btn_x + btn_w + btn_spacing + 10

    -- Refresh button
    local refresh_hovered = (self.hovered_button == "refresh")
    self:drawToolbarButton(btn_x, btn_y, btn_w, btn_h, "R", true, refresh_hovered)
    btn_x = btn_x + btn_w + btn_spacing

    -- Empty Recycle Bin button (only if in recycle bin)
    if is_recycle_bin then
        local empty_w = 120
        local empty_hovered = (self.hovered_button == "empty_recycle_bin")
        self:drawToolbarButton(btn_x, btn_y, empty_w, btn_h, "Empty Recycle Bin", true, empty_hovered)
    end
end

function FileExplorerView:drawToolbarButton(x, y, w, h, text, enabled, hovered)
    -- Background
    if not enabled then
        love.graphics.setColor(0.7, 0.7, 0.7)
    elseif hovered then
        love.graphics.setColor(0.8, 0.8, 0.95)
    else
        love.graphics.setColor(0.85, 0.85, 0.85)
    end
    love.graphics.rectangle('fill', x, y, w, h)

    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)

    -- Text
    if enabled then
        love.graphics.setColor(0, 0, 0)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
    end

    local font = love.graphics.getFont()
    local text_width = font:getWidth(text)
    local text_height = font:getHeight()
    love.graphics.print(text, x + (w - text_width) / 2, y + (h - text_height) / 2)
end

function FileExplorerView:drawAddressBar(x, y, width, current_path)
    -- Address bar background
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', x + 5, y + 2, width - 10, self.address_bar_height - 4)

    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x + 5, y + 2, width - 10, self.address_bar_height - 4)

    -- Path text
    love.graphics.setColor(0, 0, 0)
    -- Clip text rendering to address bar bounds
    love.graphics.push()
    love.graphics.setScissor(x + 10, y + 2, width - 20, self.address_bar_height - 4)
    love.graphics.print(current_path, x + 10, y + 6, 0, 0.9, 0.9)
    love.graphics.setScissor()
    love.graphics.pop()
end

function FileExplorerView:drawItemList(x, y, width, height, contents, selected_item, view_mode)
    -- Calculate visible items
    local visible_items = math.max(1, math.floor(height / self.item_height))
    local start_index = self.scroll_offset + 1
    local end_index = math.min(#contents, start_index + visible_items - 1)

    for i = start_index, end_index do
        local item = contents[i]
        local item_y = y + (i - start_index) * self.item_height

        local is_selected = selected_item and selected_item.path == item.path
        local is_hovered = self.hovered_item and self.hovered_item.path == item.path

        self:drawItem(x, item_y, width, self.item_height, item, is_selected, is_hovered)
    end

    -- Draw scrollbar if needed
    if #contents > visible_items then
        self:drawScrollbar(x + width - 15, y, 15, height, #contents, visible_items)
    end
end

function FileExplorerView:drawItem(x, y, width, height, item, is_selected, is_hovered)
    -- Background
    if is_selected then
        love.graphics.setColor(0.6, 0.6, 0.9)
    elseif is_hovered then
        love.graphics.setColor(0.9, 0.9, 0.95)
    else
        love.graphics.setColor(1, 1, 1)
    end
    love.graphics.rectangle('fill', x, y, width - 15, height) -- Exclude scrollbar area

    -- Icon
    local icon_x = x + 5
    local icon_y = y + 2
    local icon_size = height - 4

    self:drawItemIcon(icon_x, icon_y, icon_size, item)

    -- Name
    love.graphics.setColor(item.type == "deleted" and {0.4, 0.4, 0.4} or {0, 0, 0})
    love.graphics.print(item.name, icon_x + icon_size + 5, y + 5, 0, 0.9, 0.9)

    -- Type indicator (align right)
    local type_text = ""
    local type_color = {0.5, 0.5, 0.5}
    if item.type == "folder" then type_text = "Folder"
    elseif item.type == "executable" then type_text = "Program"; type_color = {0, 0.5, 0}
    elseif item.type == "file" then type_text = "File"
    elseif item.type == "deleted" then type_text = "Deleted Item"; type_color = {0.7, 0.0, 0.0}
    end

    if type_text ~= "" then
        love.graphics.setColor(type_color)
        local font = love.graphics.getFont()
        local text_width = font:getWidth(type_text) * 0.8
        love.graphics.print(type_text, x + width - 15 - text_width - 10, y + 5, 0, 0.8, 0.8)
    end
end

function FileExplorerView:drawItemIcon(x, y, size, item)
    -- Base rectangle
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', x, y, size, size)

    local color = {0.8, 0.8, 0.8} -- Default grey
    if item.type == "folder" then color = {1, 1, 0}
    elseif item.type == "executable" then color = item.icon or {0, 0.5, 0}
    elseif item.type == "file" then color = {1, 1, 1}
    elseif item.type == "deleted" then color = item.icon or {0.7, 0.7, 0.7}
    end

    -- Draw icon color square
    love.graphics.setColor(color)
    love.graphics.rectangle('fill', x + 1, y + 1, size - 2, size - 2)

    -- Border
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', x, y, size, size)

    -- Special overlay for deleted
    if item.type == "deleted" then
        love.graphics.setColor(1, 0, 0, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 2, y + 2, x + size - 2, y + size - 2)
        love.graphics.line(x + size - 2, y + 2, x + 2, y + size - 2)
        love.graphics.setLineWidth(1)
    end
end


function FileExplorerView:drawScrollbar(x, y, width, height, total_items, visible_items)
    -- Track
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle('fill', x, y, width, height)

    -- Thumb
    if total_items > visible_items then
         local thumb_height = math.max(20, (visible_items / total_items) * height)
         local scroll_range = math.max(1, total_items - visible_items)
         local thumb_y = y + (self.scroll_offset / scroll_range) * (height - thumb_height)
         -- Clamp thumb position
         thumb_y = math.max(y, math.min(thumb_y, y + height - thumb_height))

         love.graphics.setColor(0.6, 0.6, 0.6)
         love.graphics.rectangle('fill', x, thumb_y, width, thumb_height)
    end
end

function FileExplorerView:drawStatusBar(x, y, width, contents)
    -- Status bar background
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle('fill', x, y, width, self.status_bar_height)

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.line(x, y, x + width, y)

    -- Item count
    love.graphics.setColor(0, 0, 0)
    local count_text = "0 items"
    if contents and type(contents) == "table" then
        count_text = #contents .. " item" .. (#contents == 1 and "" or "s")
    elseif contents and contents.type == "special" then
        -- Could add logic for special folder counts if needed later
         count_text = ""
    end
    love.graphics.print(count_text, x + 10, y + 2, 0, 0.85, 0.85)
end

function FileExplorerView:mousepressed(x, y, button, contents, viewport_width, viewport_height)
    -- Check toolbar buttons first
    local is_recycle_bin = (self.controller.current_path == "/Recycle Bin")
    local toolbar_button = self:getButtonAtPosition(x, y, is_recycle_bin)
    if toolbar_button then
        if toolbar_button == "back" then return { name = "navigate_back" }
        elseif toolbar_button == "forward" then return { name = "navigate_forward" }
        elseif toolbar_button == "up" then return { name = "navigate_up" }
        elseif toolbar_button == "refresh" then return { name = "refresh" }
        elseif toolbar_button == "empty_recycle_bin" then return { name = "empty_recycle_bin" }
        end
    end

    -- Check item list
    if contents and type(contents) == "table" and #contents > 0 then
        local content_y = self.toolbar_height + self.address_bar_height
        local content_h = viewport_height - content_y - self.status_bar_height

        local clicked_item = self:getItemAtPosition(x, y, contents, content_y, content_h, viewport_width)

        if clicked_item then
            if button == 1 then -- Left click
                local is_double_click = (self.last_click_item and
                                        self.last_click_item.path == clicked_item.path and
                                        love.timer.getTime() - self.last_click_time < 0.5)

                if is_double_click then
                    self.last_click_item = nil
                    self.last_click_time = 0
                    return { name = "item_double_click", item = clicked_item }
                else
                    self.last_click_item = clicked_item
                    self.last_click_time = love.timer.getTime()
                    return { name = "item_click", item = clicked_item }
                end
            elseif button == 2 then -- Right click detected
                -- Emit a specific right-click event for the state
                return { name = "item_right_click", item = clicked_item }
            end
        end
    end

    return nil -- Clicked on empty space, scrollbar, or unhandled button
end

function FileExplorerView:wheelmoved(x, y, viewport_width, viewport_height)
    -- Get current contents from controller to know max scroll
    local contents = self.controller:getCurrentViewContents()

    if not contents or type(contents) ~= "table" or #contents == 0 then
        return
    end

    local content_h = viewport_height - self.toolbar_height - self.address_bar_height - self.status_bar_height
    local visible_items = math.max(1, math.floor(content_h / self.item_height))
    local max_scroll = math.max(0, #contents - visible_items)

    if y > 0 then -- Scroll up
        self.scroll_offset = math.max(0, self.scroll_offset - 1)
    elseif y < 0 then -- Scroll down
        self.scroll_offset = math.min(max_scroll, self.scroll_offset + 1)
    end
end

function FileExplorerView:getButtonAtPosition(x, y, is_recycle_bin)
    local btn_y = 5
    local btn_h = 25
    local btn_spacing = 5

    if y < btn_y or y > btn_y + btn_h then
        return nil
    end

    local btn_x = 5
    local btn_w = 25 -- Standard button width

    -- Back button
    if x >= btn_x and x <= btn_x + btn_w then return "back" end
    btn_x = btn_x + btn_w + btn_spacing

    -- Forward button
    if x >= btn_x and x <= btn_x + btn_w then return "forward" end
    btn_x = btn_x + btn_w + btn_spacing

    -- Up button
    if x >= btn_x and x <= btn_x + btn_w then return "up" end
    btn_x = btn_x + btn_w + btn_spacing + 10

    -- Refresh button
    if x >= btn_x and x <= btn_x + btn_w then return "refresh" end
    btn_x = btn_x + btn_w + btn_spacing

    -- Empty Recycle Bin button
    if is_recycle_bin then
        local empty_w = 120
        if x >= btn_x and x <= btn_x + empty_w then return "empty_recycle_bin" end
    end

    return nil
end

function FileExplorerView:getItemAtPosition(x, y, contents, content_y, content_h, viewport_width)
    if y < content_y or y > content_y + content_h then
        return nil
    end

    local visible_items = math.max(1, math.floor(content_h / self.item_height))
    local start_index = self.scroll_offset + 1

    local relative_y = y - content_y
    local item_index_in_view = math.floor(relative_y / self.item_height)
    local item_index = start_index + item_index_in_view

    if item_index >= 1 and item_index <= #contents then
        -- Check x bounds (excluding scrollbar)
        if x >= 0 and x <= viewport_width - 15 then
            return contents[item_index]
        end
    end

    return nil
end

return FileExplorerView