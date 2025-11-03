-- src/views/taskbar_view.lua
-- View for rendering the taskbar

local Object = require('class')
local Strings = require('src.utils.strings')
local UIComponents = require('src.views.ui_components')

local TaskbarView = Object:extend('TaskbarView')

function TaskbarView:init(di)
    self.di = di or {}
    self.config = di.config or {}

    -- Taskbar dimensions from config
    local taskbar_cfg = (self.config.ui and self.config.ui.taskbar) or {}
    self.taskbar_height = taskbar_cfg.height or 30
    self.taskbar_start_button_width = taskbar_cfg.start_button_width or 60
    self.taskbar_sys_tray_width = taskbar_cfg.system_tray_width or 120
    self.taskbar_button_start_x = taskbar_cfg.button_start_x or 75
    self.taskbar_button_padding = taskbar_cfg.button_padding or 2
    self.taskbar_button_min_width = taskbar_cfg.button_min_width or 80
    self.taskbar_button_max_width = taskbar_cfg.button_max_width or 200

    -- Hover state
    self.start_button_hovered = false
    self.hovered_taskbar_button_id = nil

    -- Current time
    self.current_time = "12:00 PM"
end

function TaskbarView:update(dt, mouse_x, mouse_y, start_button_hovered, hovered_taskbar_button_id, current_time)
    self.start_button_hovered = start_button_hovered
    self.hovered_taskbar_button_id = hovered_taskbar_button_id
    self.current_time = current_time or self.current_time
end

function TaskbarView:draw(tokens, windows, focused_window_id, start_menu_open)
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()
    local y = screen_height - self.taskbar_height

    -- Draw taskbar background
    local colors = (self.config.ui and self.config.ui.colors) or {}
    local taskbar_colors = colors.taskbar or {}
    love.graphics.setColor(taskbar_colors.bg or {0.75, 0.75, 0.75})
    love.graphics.rectangle('fill', 0, y, screen_width, self.taskbar_height)
    love.graphics.setColor(taskbar_colors.top_line or {1, 1, 1})
    love.graphics.line(0, y, screen_width, y)

    -- Draw components
    local taskbar_cfg = (self.config.ui and self.config.ui.taskbar) or {}
    local left_margin = taskbar_cfg.left_margin or 10
    local vpad = taskbar_cfg.vertical_padding or 5

    self:drawStartButton(left_margin, y + vpad, self.taskbar_height - 2 * vpad)
    self:drawSystemTray(screen_width - self.taskbar_sys_tray_width, y + vpad, self.taskbar_sys_tray_width - 2 * vpad, self.taskbar_height - 2 * vpad, tokens)

    -- Draw window buttons
    self:drawWindowButtons(y, windows, focused_window_id)
end

function TaskbarView:drawWindowButtons(taskbar_y, windows, focused_window_id)
    local screen_width = love.graphics.getWidth()
    local button_area_start_x = self.taskbar_button_start_x
    local button_area_end_x = screen_width - self.taskbar_sys_tray_width
    local button_area_width = button_area_end_x - button_area_start_x

    local num_windows = #windows
    if num_windows == 0 then return end

    local total_padding = (num_windows - 1) * self.taskbar_button_padding
    local available_width_for_buttons = button_area_width - total_padding
    local button_width = available_width_for_buttons / num_windows
    button_width = math.max(self.taskbar_button_min_width, math.min(self.taskbar_button_max_width, button_width))

    local font = love.graphics.getFont()
    local sprite_loader = self.di.spriteLoader

    for i, window in ipairs(windows) do
        local button_x = button_area_start_x + (i - 1) * (button_width + self.taskbar_button_padding)
        local button_y = taskbar_y + 3
        local button_h = self.taskbar_height - 6
        local is_focused = (window.id == focused_window_id)
        local is_minimized = window.is_minimized
        local is_hovered = (window.id == self.hovered_taskbar_button_id)

        -- Button appearance
        local top_left_color, bottom_right_color, bg_color
        if is_focused and not is_minimized then
            bg_color = {0.6, 0.6, 0.6}
            top_left_color = {0.2, 0.2, 0.2}
            bottom_right_color = {1, 1, 1}
        elseif is_hovered then
            bg_color = {0.85, 0.85, 0.85}
            top_left_color = {1, 1, 1}
            bottom_right_color = {0.2, 0.2, 0.2}
        else
            bg_color = {0.75, 0.75, 0.75}
            top_left_color = {1, 1, 1}
            bottom_right_color = {0.2, 0.2, 0.2}
        end

        -- Draw button background
        love.graphics.setColor(bg_color)
        love.graphics.rectangle('fill', button_x, button_y, button_width, button_h)

        -- Draw button borders
        love.graphics.setColor(top_left_color)
        love.graphics.line(button_x, button_y, button_x + button_width, button_y)
        love.graphics.line(button_x, button_y, button_x, button_y + button_h)
        love.graphics.setColor(bottom_right_color)
        love.graphics.line(button_x + button_width, button_y, button_x + button_width, button_y + button_h)
        love.graphics.line(button_x, button_y + button_h, button_x + button_width, button_y + button_h)

        -- Draw icon
        local icon_size = 16
        local icon_x = button_x + 3
        local icon_y = button_y + (button_h - icon_size) / 2

        if window.icon_sprite and sprite_loader then
            sprite_loader:drawSprite(window.icon_sprite, icon_x, icon_y, icon_size, icon_size, {1, 1, 1})
        end

        -- Draw title text
        love.graphics.setColor(0, 0, 0)
        local text_start_x = window.icon_sprite and (icon_x + icon_size + 3) or (button_x + 5)
        local max_text_width = button_width - (text_start_x - button_x) - 5
        local truncated_title = window.title or "Untitled"

        if font:getWidth(truncated_title) > max_text_width then
            local ellipsis_width = font:getWidth("...")
            while font:getWidth(truncated_title) + ellipsis_width > max_text_width and #truncated_title > 0 do
                truncated_title = truncated_title:sub(1, -2)
            end
            truncated_title = truncated_title .. "..."
        end

        local text_y = button_y + (button_h - font:getHeight()) / 2
        love.graphics.print(truncated_title, text_start_x, text_y)

        -- Draw minimized overlay
        if is_minimized then
            love.graphics.setColor(0.4, 0.4, 0.4, 0.5)
            love.graphics.rectangle('fill', button_x, button_y, button_width, button_h)
        end
    end
end

function TaskbarView:drawStartButton(x, y, size)
    local w = self.taskbar_start_button_width
    local h = size
    local hovered = self.start_button_hovered

    local colors = (self.config.ui and self.config.ui.colors and self.config.ui.colors.start_button) or {}
    love.graphics.setColor(hovered and (colors.bg_hover or {0.85, 0.85, 0.85}) or (colors.bg or {0.75, 0.75, 0.75}))
    love.graphics.rectangle('fill', x, y, w, h)

    love.graphics.setColor((colors.border_light or {1, 1, 1}))
    love.graphics.line(x, y, x + w, y)
    love.graphics.line(x, y, x, y + h)

    love.graphics.setColor((colors.border_dark or {0.2, 0.2, 0.2}))
    love.graphics.line(x + w, y, x + w, y + h)
    love.graphics.line(x, y + h, x + w, y + h)

    love.graphics.setColor(colors.text or {0, 0, 0})
    local tb_text = (self.config.ui and self.config.ui.taskbar_text) or {}
    local start_off = tb_text.start_text_offset or { x = 5, y = 5 }
    local start_scale = tb_text.start_text_scale or 0.9
    love.graphics.print(Strings.get('start.title','Start'), x + start_off.x, y + start_off.y, 0, start_scale, start_scale)
end

function TaskbarView:drawSystemTray(x, y, w, h, tokens)
    local colors = (self.config.ui and self.config.ui.colors and self.config.ui.colors.system_tray) or {}

    love.graphics.setColor(colors.bg or {0.6, 0.6, 0.6})
    love.graphics.rectangle('fill', x, y, w, h)

    love.graphics.setColor(colors.border_dark or {0.2, 0.2, 0.2})
    love.graphics.line(x, y, x + w, y)
    love.graphics.line(x, y, x, y + h)

    love.graphics.setColor(colors.border_light or {1, 1, 1})
    love.graphics.line(x + w, y, x + w, y + h)
    love.graphics.line(x, y + h, x + w, y + h)

    love.graphics.setColor(colors.text or {0, 0, 0})
    local tray_cfg = ((self.config.ui and self.config.ui.desktop) or {}).system_tray or {}
    local clock_off = tray_cfg.clock_right_offset or 50
    local clock_scale = tray_cfg.clock_text_scale or 1.2
    love.graphics.print(self.current_time, x + w - clock_off, y + 5, 0, clock_scale, clock_scale)

    local token_off = tray_cfg.token_offset or { x = 5, y = 3 }
    UIComponents.drawTokenCounter(x + token_off.x, y + token_off.y, tokens)
end

function TaskbarView:isStartButtonHovered(x, y)
    local taskbar_cfg = (self.config.ui and self.config.ui.taskbar) or {}
    local left_margin = taskbar_cfg.left_margin or 10
    local vpad = taskbar_cfg.vertical_padding or 5
    local btn_x = left_margin
    local btn_y = love.graphics.getHeight() - self.taskbar_height + vpad
    local btn_w = self.taskbar_start_button_width
    local btn_h = self.taskbar_height - 2 * vpad
    return x >= btn_x and x <= btn_x + btn_w and y >= btn_y and y <= btn_y + btn_h
end

function TaskbarView:getTaskbarButtonAtPosition(x, y)
    local taskbar_y = love.graphics.getHeight() - self.taskbar_height
    if y < taskbar_y or y > love.graphics.getHeight() then return nil end

    local screen_width = love.graphics.getWidth()
    local button_area_start_x = self.taskbar_button_start_x
    local button_area_end_x = screen_width - self.taskbar_sys_tray_width
    local button_area_width = button_area_end_x - button_area_start_x
    if x < button_area_start_x or x > button_area_end_x then return nil end

    -- IMPORTANT: Must use same window order as drawing (getWindowsInCreationOrder)
    local windows = (self.di.windowManager and self.di.windowManager:getWindowsInCreationOrder()) or {}
    local num_windows = #windows
    if num_windows == 0 then return nil end

    local total_padding = (num_windows - 1) * self.taskbar_button_padding
    local available_width_for_buttons = button_area_width - total_padding
    local button_width = available_width_for_buttons / num_windows
    button_width = math.max(self.taskbar_button_min_width, math.min(self.taskbar_button_max_width, button_width))

    local relative_x = x - button_area_start_x
    local button_index = math.floor(relative_x / (button_width + self.taskbar_button_padding)) + 1

    local button_start_x = button_area_start_x + (button_index - 1) * (button_width + self.taskbar_button_padding)
    if x >= button_start_x and x <= button_start_x + button_width then
        if button_index >= 1 and button_index <= num_windows then
            return windows[button_index].id
        end
    end
    return nil
end

return TaskbarView
