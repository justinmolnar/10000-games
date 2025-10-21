-- src/views/file_explorer_view.lua
-- View for rendering file explorer interface

local Object = require('class')
local UIComponents = require('src.views.ui_components')
local Strings = require('src.utils.strings')
-- Fallback config for non-DI usage
local Config = rawget(_G, 'DI_CONFIG') or {}

local FileExplorerView = Object:extend('FileExplorerView')

function FileExplorerView:init(controller, di)
    self.controller = controller
    self.di = di
    if di then UIComponents.inject(di) end
    local Config_ = (di and di.config) or Config
    local Strings_ = (di and di.strings) or Strings

    -- Layout constants
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.file_explorer) or {}
    self.toolbar_height = V.toolbar_height or 35
    self.address_bar_height = V.address_bar_height or 25
    self.status_bar_height = V.status_bar_height or 20
    self.item_height = V.item_height or 25
    -- Scrollbar lane width from config (track + margin)
    self.scrollbar_width = UIComponents.getScrollbarLaneWidth()
    self.scroll_offset = 0

    -- Hover state
    self.hovered_item = nil
    self.hovered_button = nil

    -- Click tracking for double-click
    self.last_click_item = nil
    self.last_click_time = 0

    -- No modal rendering here; Control Panel applets launch as separate windows
    -- Scrollbar interaction state
    self._sb = { list = { dragging = false, geom = nil, drag = nil } }
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

    -- Check toolbar buttons (pass is_recycle_bin context). If modal open, toolbar is disabled.
    if self.controller.modal_applet then return end
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
    local Config_ = (self.di and self.di.config) or Config
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.file_explorer) or {}
    local C = V.colors or {}
    love.graphics.setColor(C.bg or {1,1,1})
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
        love.graphics.setColor(C.text_muted or {0.5,0.5,0.5})
        love.graphics.printf(Strings.get('file_explorer.empty_recycle_bin_message','The Recycle Bin is empty'), 10, content_y + 10, viewport_width - 20, "center")
    elseif contents and contents.type == "special" then
    love.graphics.setColor(C.text_muted or {0.5,0.5,0.5})
        love.graphics.printf(Strings.get('file_explorer.special_folder_message','Special folder view'), 10, content_y + 10, viewport_width - 20, "center")
    else
    love.graphics.setColor(C.text_muted or {0.5,0.5,0.5})
        love.graphics.printf(Strings.get('file_explorer.empty_folder_message','This folder is empty'), 10, content_y + 10, viewport_width - 20, "center")
    end

    -- Status bar
    self:drawStatusBar(0, viewport_height - self.status_bar_height, viewport_width, contents)

end

function FileExplorerView:drawToolbar(x, y, width, can_go_back, can_go_forward, is_recycle_bin)
    -- Toolbar background
    local Config_ = (self.di and self.di.config) or Config
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.file_explorer) or {}
    local C = V.colors or {}
    love.graphics.setColor(C.toolbar_bg or {0.9,0.9,0.9})
    love.graphics.rectangle('fill', x, y, width, self.toolbar_height)

    love.graphics.setColor(C.toolbar_sep or {0.7,0.7,0.7})
    love.graphics.line(x, y + self.toolbar_height, x + width, y + self.toolbar_height)

    local T = V.toolbar or {}
    local btn_x = x + (T.margin or 5)
    local btn_y = y + (T.margin or 5)
    local btn_w = T.button_w or 25
    local btn_h = T.button_h or 25
    local btn_spacing = T.spacing or 5

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
    btn_x = btn_x + btn_w + btn_spacing + (T.gap_after_nav or 10)

    -- Refresh button
    local refresh_hovered = (self.hovered_button == "refresh")
    self:drawToolbarButton(btn_x, btn_y, btn_w, btn_h, "R", true, refresh_hovered)
    btn_x = btn_x + btn_w + btn_spacing

    -- Empty Recycle Bin button (only if in recycle bin)
    if is_recycle_bin then
        local empty_w = T.empty_bin_w or 120
        local empty_hovered = (self.hovered_button == "empty_recycle_bin")
    self:drawToolbarButton(btn_x, btn_y, empty_w, btn_h, Strings.get('file_explorer.empty_recycle_bin_button','Empty Recycle Bin'), true, empty_hovered)
    end
end

function FileExplorerView:drawToolbarButton(x, y, w, h, text, enabled, hovered)
    -- Background
    local Config_ = (self.di and self.di.config) or Config
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.file_explorer) or {}
    local C = V.colors or {}
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
        love.graphics.setColor(C.text or {0,0,0})
    else
        love.graphics.setColor(C.text_muted or {0.5,0.5,0.5})
    end

    local font = love.graphics.getFont()
    local text_width = font:getWidth(text)
    local text_height = font:getHeight()
    love.graphics.print(text, x + (w - text_width) / 2, y + (h - text_height) / 2)
end

function FileExplorerView:drawAddressBar(x, y, width, current_path)
    -- Address bar background
    local Config_ = (self.di and self.di.config) or Config
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.file_explorer) or {}
    local A = V.address_bar or {}
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', x + (A.inset_x or 5), y + (A.inset_y or 2), width - 2*(A.inset_x or 5), self.address_bar_height - 2*(A.inset_y or 2))

    love.graphics.setColor((A.border or {0.5,0.5,0.5}))
    love.graphics.rectangle('line', x + (A.inset_x or 5), y + (A.inset_y or 2), width - 2*(A.inset_x or 5), self.address_bar_height - 2*(A.inset_y or 2))

    -- Path text
    love.graphics.setColor(0, 0, 0)
    -- Clip text rendering to address bar bounds
    love.graphics.push()
    love.graphics.setScissor(x + (A.text_pad_x or 10), y + (A.inset_y or 2), width - 2*(A.text_pad_x or 10), self.address_bar_height - 2*(A.inset_y or 2))
    local ts = A.text_scale or 0.9
    love.graphics.print(current_path, x + (A.text_pad_x or 10), y + ((A.inset_y or 2) + 4), 0, ts, ts)
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

    -- Draw scrollbar if needed (using shared UI helper)
    if #contents > visible_items then
        local UI = UIComponents
        local item_h = self.item_height
        -- Translate to the list's local origin so helper can compute at (0,0)
        love.graphics.push()
        love.graphics.translate(x, y)
        local sb_geom = UI.computeScrollbar({
            viewport_w = width,
            viewport_h = height,
            content_h = (#contents) * item_h,
            offset = (self.scroll_offset or 0) * item_h,
            -- width/margin/arrow heights/min thumb from config defaults
        })
        UI.drawScrollbar(sb_geom)
        self._sb.list.geom = sb_geom
        love.graphics.pop()
    end
end

function FileExplorerView:drawItem(x, y, width, height, item, is_selected, is_hovered)
    -- Background
    local Config_ = (self.di and self.di.config) or Config
    local V = (Config_.ui and Config_.ui.views and Config_.ui.views.file_explorer) or {}
    local C = V.colors or {}
    if is_selected then
        love.graphics.setColor(C.item_selected or {0.6,0.6,0.9})
    elseif is_hovered then
        love.graphics.setColor(C.item_hover or {0.9,0.9,0.95})
    else
        love.graphics.setColor(C.item_bg or {1,1,1})
    end
    local sbw = UIComponents.getScrollbarLaneWidth()
    love.graphics.rectangle('fill', x, y, width - sbw, height) -- Exclude standardized lane

    -- Icon
    local I = (V.item or {})
    local icon_x = x + (I.icon_pad_x or 5)
    local icon_y = y + (I.icon_pad_y or 2)
    local icon_size = height - 4

    self:drawItemIcon(icon_x, icon_y, icon_size, item)

    -- Name
    love.graphics.setColor(item.type == "deleted" and (C.text_muted or {0.4,0.4,0.4}) or (C.text or {0,0,0}))
    local ns = I.name_scale or 0.9
    love.graphics.print(item.name, icon_x + icon_size + (I.name_pad_x or 5), y + (I.name_pad_y or 5), 0, ns, ns)

    -- Type indicator (align right)
    local type_text = ""
    local type_color = C.type_file or {0.5,0.5,0.5}
    if item.type == "folder" then type_text = Strings.get('file_explorer.types.folder','Folder')
    elseif item.type == "executable" then type_text = Strings.get('file_explorer.types.program','Program'); type_color = C.type_exec or {0, 0.5, 0}
    elseif item.type == "file" then type_text = Strings.get('file_explorer.types.file','File')
    elseif item.type == "deleted" then type_text = Strings.get('file_explorer.types.deleted','Deleted Item'); type_color = C.type_deleted or {0.7, 0.0, 0.0}
    end

    if type_text ~= "" then
        love.graphics.setColor(type_color)
        local font = love.graphics.getFont()
        local ts = (I.type_scale or 0.8)
        local text_width = font:getWidth(type_text) * ts
    love.graphics.print(type_text, x + width - UIComponents.getScrollbarLaneWidth() - text_width - 10, y + 5, 0, ts, ts)
    end
end

function FileExplorerView:drawItemIcon(x, y, size, item)
    local SpriteLoader = require('src.utils.sprite_loader')
    local sprite_loader = SpriteLoader.getInstance()

    local sprite_name = self:resolveItemSprite(item)
    local tint = {1,1,1}
    -- Draw sprite or fallback box via sprite_loader
    sprite_loader:drawSprite(sprite_name, x, y, size, size, tint)

    -- Special overlay for deleted
    if item.type == "deleted" then
        local di = self.controller and self.controller.di
        local C = di and di.config or {}
        local V = (C.ui and C.ui.views and C.ui.views.file_explorer) or {}
        local del = V.deleted_overlay or { color = {1,0,0,0.7}, line_width = 2 }
        love.graphics.setColor(del.color or {1,0,0,0.7})
        love.graphics.setLineWidth(del.line_width or 2)
        love.graphics.line(x + 2, y + 2, x + size - 2, y + size - 2)
        love.graphics.line(x + size - 2, y + 2, x + 2, y + size - 2)
        love.graphics.setLineWidth(1)
    end
end

function FileExplorerView:resolveItemSprite(item)
    -- Prefer program-specific icon for executables and deleted items
    -- Special-case the Control Panel root folder
    if item.type == 'folder' and (item.path == '/Control Panel' or item.name == 'Control Panel') then
        return 'directory_control_panel-0'
    end

    -- Control Panel applets listed inside the Control Panel folder
    if item.path and item.path:match('^/Control Panel/') then
        local panel_key = item.name and item.name:lower():gsub('%s+', '') or nil
        local sprite = panel_key and self:getControlPanelIconSprite(panel_key) or nil
        if sprite then return sprite end
        -- Fallbacks: try program icon, then a default control-panel gear
        if item.program_id then
            local program = self.controller.program_registry:getProgram(item.program_id)
            if program and program.icon_sprite then return program.icon_sprite end
        end
        return 'settings_gear-0'
    end

    if item.type == 'deleted' and item.icon_sprite then
        return item.icon_sprite
    end
    if item.type == 'executable' then
        -- If coming from desktop or folder with a program_id, try that program's icon
        if item.program_id then
            local program = self.controller.program_registry:getProgram(item.program_id)
            if program and program.icon_sprite then return program.icon_sprite end
        end
        return 'executable-0'
    end
    if item.type == 'folder' then
        -- Use a generic folder icon
        return 'directory_open_file_mydocs_small-0'
    end
    if item.type == 'file' then
        -- Extension-based defaults
        if item.name and item.name:match('%.txt$') then
            return 'notepad_file-0'
        elseif item.name and item.name:match('%.json$') then
            return 'file_lines-0'
        elseif item.name and item.name:match('%.exe$') then
            return 'executable-0'
        else
            return 'document-0'
        end
    end
    if item.type == 'special' then
        if item.special_type == 'desktop_view' then return 'computer_explorer-0' end
        if item.special_type == 'recycle_bin' then return 'recycle_bin_empty-0' end
        if item.special_type == 'my_documents' then return 'directory_open_file_mydocs_small-0' end
        if item.special_type == 'control_panel_general' or item.special_type == 'control_panel_desktop' or item.special_type == 'control_panel_screensavers' then
            return 'settings_gear-0'
        end
        return 'gears_tweakui_a-0'
    end
    return 'document-0'
end

-- Cached fetch of per-panel icon from control_panel JSON
function FileExplorerView:getControlPanelIconSprite(panel_key)
    self._cp_icons_cache = self._cp_icons_cache or {}
    if self._cp_icons_cache[panel_key] ~= nil then
        return self._cp_icons_cache[panel_key]
    end
    local ok, sprite = pcall(function()
        local Paths = require('src.paths')
        local json = require('json')
        local file_path = Paths.assets.data .. 'control_panels/' .. panel_key .. '.json'
        local read_ok, contents = pcall(love.filesystem.read, file_path)
        if not read_ok or not contents then return nil end
        local decode_ok, data = pcall(json.decode, contents)
        if not decode_ok or type(data) ~= 'table' then return nil end
        return data.icon_sprite
    end)
    local result = (ok and sprite) or nil
    self._cp_icons_cache[panel_key] = result -- cache even nil to avoid repeated IO
    return result
end


-- Removed old drawScrollbar; now using UIComponents.drawScrollbar

function FileExplorerView:drawStatusBar(x, y, width, contents)
    -- Status bar background
    local di = self.controller and self.controller.di
    local C = di and di.config or {}
    local V = (C.ui and C.ui.views and C.ui.views.file_explorer) or {}
    local C = V.colors or {}
    love.graphics.setColor(C.status_bg or {0.9,0.9,0.9})
    love.graphics.rectangle('fill', x, y, width, self.status_bar_height)

    love.graphics.setColor(C.status_sep or {0.7,0.7,0.7})
    love.graphics.line(x, y, x + width, y)

    -- Item count
    love.graphics.setColor(C.text or {0,0,0})
    local count_text = Strings.get('file_explorer.status.items_zero','0 items')
    if contents and type(contents) == "table" then
        if #contents == 1 then
            count_text = string.format(Strings.get('file_explorer.status.item_singular','%d item'), #contents)
        else
            count_text = string.format(Strings.get('file_explorer.status.items_plural','%d items'), #contents)
        end
    elseif contents and contents.type == "special" then
        -- Could add logic for special folder counts if needed later
         count_text = ""
    end
    love.graphics.print(count_text, x + 10, y + 2, 0, 0.85, 0.85)
end

function FileExplorerView:mousepressed(x, y, button, contents, viewport_width, viewport_height, is_modal)
    -- x, y are LOCAL coords relative to content area (0,0)

    -- Check toolbar buttons first (using local coords)
    local is_recycle_bin = (self.controller.current_path == "/Recycle Bin")
    local toolbar_button = self:getButtonAtPosition(x, y, is_recycle_bin) -- Pass local coords
    if toolbar_button then
        -- Return events based on button ID (logic unchanged)
        if toolbar_button == "back" and self.controller:canGoBack() then return { name = "navigate_back" } end
        if toolbar_button == "forward" and self.controller:canGoForward() then return { name = "navigate_forward" } end
        if toolbar_button == "up" and self.controller.current_path ~= "/" then return { name = "navigate_up" } end
        if toolbar_button == "refresh" then return { name = "refresh" } end
        if toolbar_button == "empty_recycle_bin" then return { name = "empty_recycle_bin" } end
        -- If button check returned an ID but it's disabled, consume the click
        return nil
    end

    -- Special handling for Control Panel applets input
    local current_item = self.controller.file_system:getItem(self.controller.current_path)
    if current_item and current_item.type == 'special' and (current_item.special_type == 'control_panel_general' or current_item.special_type == 'control_panel_desktop' or current_item.special_type == 'control_panel_screensavers') then
        local content_y = self.toolbar_height + self.address_bar_height
        local content_h = viewport_height - content_y - self.status_bar_height
        if y >= content_y and y <= content_y + content_h then
            local local_y = y - content_y
            local ev = self.control_panel_view:mousepressed(x, local_y, button, current_item.special_type, viewport_width, content_h)
            if ev then
                return ev
            else
                return { name = 'noop' } -- consume click in applet area
            end
        end
    end

    -- Check item list (using local coords)
    if contents and type(contents) == "table" and #contents > 0 then
        local content_y = self.toolbar_height + self.address_bar_height -- Relative y start
        local content_h = viewport_height - content_y - self.status_bar_height

        -- Scrollbar interactions (compute local coords relative to list origin)
        if self._sb and self._sb.list and self._sb.list.geom then
            local g = self._sb.list.geom
            local lx, ly = x - 0, y - content_y
            if ly >= 0 and ly <= content_h then
                local UI = UIComponents
                local off_px = (self.scroll_offset or 0) * self.item_height
                local res = UI.scrollbarHandlePress(lx, ly, button, g, off_px, nil)
                if res and res.consumed then
                    if res.new_offset_px ~= nil then
                        local contents_count = #contents
                        local visible_items = math.max(1, math.floor(content_h / self.item_height))
                        local max_off = math.max(0, contents_count - visible_items)
                        local new_idx = math.floor((res.new_offset_px / self.item_height) + 0.0001)
                        self.scroll_offset = math.max(0, math.min(max_off, new_idx))
                    end
                    if res.drag then
                        self._sb.list.dragging = true
                        self._sb.list.drag = { start_y = res.drag.start_y, offset_start_px = res.drag.offset_start_px }
                    end
                    return { name = 'noop' }
                end
            end
        end

        local clicked_item = self:getItemAtPosition(x, y, contents, content_y, content_h, viewport_width) -- Pass local coords

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
                return { name = "item_right_click", item = clicked_item }
            end
        end
    end

    -- If click wasn't on toolbar or item list, it's considered empty space within the view
    return nil
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

function FileExplorerView:mousemoved(x, y, dx, dy, viewport_width, viewport_height, is_modal)
    local content_y = self.toolbar_height + self.address_bar_height
    local content_h = viewport_height - content_y - self.status_bar_height
    if self._sb and self._sb.list and self._sb.list.dragging and self._sb.list.geom then
        local g = self._sb.list.geom
        local lx, ly = x - 0, y - content_y
        if ly >= -50 and ly <= content_h + 50 then -- allow slight out-of-bounds drags
            local UI = UIComponents
            local res = UI.scrollbarHandleMove(ly, self._sb.list.drag, g)
            if res and res.consumed and res.new_offset_px ~= nil then
                local contents = self.controller:getCurrentViewContents()
                local contents_count = (type(contents) == 'table') and #contents or 0
                local visible_items = math.max(1, math.floor(content_h / self.item_height))
                local max_off = math.max(0, contents_count - visible_items)
                local new_idx = math.floor((res.new_offset_px / self.item_height) + 0.0001)
                self.scroll_offset = math.max(0, math.min(max_off, new_idx))
                return { name = 'noop' }
            end
        end
    end
end

function FileExplorerView:mousereleased(x, y, button)
    if button == 1 and self._sb and self._sb.list then
        if self._sb.list.dragging then
            self._sb.list.dragging = false
            self._sb.list.drag = nil
            return { name = 'noop' }
        end
    end
end

function FileExplorerView:getButtonAtPosition(x, y, is_recycle_bin)
    local di = self.controller and self.controller.di
    local C = di and di.config or {}
    local V = (C.ui and C.ui.views and C.ui.views.file_explorer) or {}
    local T = V.toolbar or {}
    local btn_y = (T.margin or 5)
    local btn_h = T.button_h or 25
    local btn_spacing = T.spacing or 5

    if y < btn_y or y > btn_y + btn_h then
        return nil
    end

    local btn_x = (T.margin or 5)
    local btn_w = T.button_w or 25 -- Standard button width

    -- Back button
    if x >= btn_x and x <= btn_x + btn_w then return "back" end
    btn_x = btn_x + btn_w + btn_spacing

    -- Forward button
    if x >= btn_x and x <= btn_x + btn_w then return "forward" end
    btn_x = btn_x + btn_w + btn_spacing

    -- Up button
    if x >= btn_x and x <= btn_x + btn_w then return "up" end
    btn_x = btn_x + btn_w + btn_spacing + (T.gap_after_nav or 10)

    -- Refresh button
    if x >= btn_x and x <= btn_x + btn_w then return "refresh" end
    btn_x = btn_x + btn_w + btn_spacing

    -- Empty Recycle Bin button
    if is_recycle_bin then
        local empty_w = T.empty_bin_w or 120
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
        -- Check x bounds (excluding scrollbar lane)
        if x >= 0 and x <= viewport_width - UIComponents.getScrollbarLaneWidth() then
            return contents[item_index]
        end
    end

    return nil
end

return FileExplorerView