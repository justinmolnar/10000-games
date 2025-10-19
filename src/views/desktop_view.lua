-- src/views/desktop_view.lua
local Object = require('class')
local UIComponents = require('src.views.ui_components')
local Strings = require('src.utils.strings')
local Config = require('src.config')
local DesktopView = Object:extend('DesktopView')

function DesktopView:init(program_registry, player_data, window_manager, desktop_icons, recycle_bin)
    self.program_registry = program_registry
    self.player_data = player_data
    self.window_manager = window_manager
    self.desktop_icons = desktop_icons -- Injected
    self.recycle_bin = recycle_bin -- Injected

    local taskbar_cfg = (Config and Config.ui and Config.ui.taskbar) or {}
    self.taskbar_height = taskbar_cfg.height or 40
    self.clock_update_timer = 0
    self.current_time = ""

    -- Hover state
    self.hovered_program_id = nil
    self.hovered_start_program_id = nil
    self.start_button_hovered = false
    self.hovered_taskbar_button_id = nil

    -- Icon layout defaults (dimensions from model now)
    self.icon_width, self.icon_height = self.desktop_icons:getIconDimensions()
    local desktop_cfg = (Config and Config.ui and Config.ui.desktop) or {}
    local grid_cfg = desktop_cfg.grid or {}
    self.icon_padding = grid_cfg.icon_padding or 20
    self.icon_start_x = grid_cfg.start_x or 20
    self.icon_start_y = grid_cfg.start_y or 20
    self.default_icon_positions = {} -- Cache default grid positions

    self:calculateDefaultIconPositionsIfNeeded() -- Calculate defaults once

    -- Start menu layout
    local start_cfg = (desktop_cfg.start_menu or {})
    self.start_menu_w = start_cfg.width or 200
    self.start_menu_h = start_cfg.height or 300
    self.start_menu_x = 0
    self.start_menu_y = love.graphics.getHeight() - self.taskbar_height - self.start_menu_h

    -- Run dialog layout
    local run_cfg = desktop_cfg.run_dialog or {}
    self.run_dialog_w = run_cfg.width or 400
    self.run_dialog_h = run_cfg.height or 150
    self.run_dialog_x = (love.graphics.getWidth() - self.run_dialog_w) / 2
    self.run_dialog_y = (love.graphics.getHeight() - self.run_dialog_h) / 2

     -- Taskbar layout
    self.taskbar_start_button_width = taskbar_cfg.start_button_width or 60
    self.taskbar_sys_tray_width = taskbar_cfg.sys_tray_width or 150
    self.taskbar_button_max_width = taskbar_cfg.button_max_width or 160
    self.taskbar_button_min_width = taskbar_cfg.button_min_width or 80
    self.taskbar_button_padding = taskbar_cfg.button_padding or 4
    self.taskbar_button_start_x = (taskbar_cfg.left_margin or 10) + self.taskbar_start_button_width + (taskbar_cfg.button_area_gap or 10)
end

-- Calculate default grid positions if needed
function DesktopView:calculateDefaultIconPositionsIfNeeded()
    local desktop_programs = self.program_registry:getDesktopPrograms()
    if #desktop_programs == #self.default_icon_positions then return end -- Assume up to date

    self.default_icon_positions = {} -- Recalculate

    local available_height = love.graphics.getHeight() - self.taskbar_height - self.icon_start_y
    local icons_per_column = math.max(1, math.floor(available_height / (self.icon_height + self.icon_padding)))

    local col = 0
    local row = 0

    for _, program in ipairs(desktop_programs) do
        -- Store default position associated with program ID
        self.default_icon_positions[program.id] = {
            x = self.icon_start_x + col * (self.icon_width + self.icon_padding),
            y = self.icon_start_y + row * (self.icon_height + self.icon_padding)
        }

        row = row + 1
        if row >= icons_per_column then
            row = 0
            col = col + 1
        end
    end
end

-- Get the default position for an icon
function DesktopView:getDefaultIconPosition(program_id)
    return self.default_icon_positions[program_id] or { x = self.icon_start_x, y = self.icon_start_y } -- Fallback
end


function DesktopView:update(dt, start_menu_open, dragging_icon_id)
    -- Update clock
    self.clock_update_timer = self.clock_update_timer + dt
    if self.clock_update_timer >= 1.0 then
        self.current_time = os.date("%H:%M")
        self.clock_update_timer = 0
    end

    -- Update hover states (mouse position relative to screen)
    local mx, my = love.mouse.getPosition()
    self.hovered_program_id = self:getProgramAtPosition(mx, my)
    self.start_button_hovered = self:isStartButtonHovered(mx, my)
    self.hovered_taskbar_button_id = self:getTaskbarButtonAtPosition(mx, my) -- Update taskbar hover

    if start_menu_open then
        self.hovered_start_program_id = self:getStartMenuProgramAtPosition(mx, my)
    else
        self.hovered_start_program_id = nil
    end
end

function DesktopView:draw(wallpaper_color, tokens, start_menu_open, run_dialog_open, run_text, dragging_icon_id)
    -- Draw wallpaper
    love.graphics.setColor(wallpaper_color)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Draw desktop icons based on model data
    local desktop_programs = self.program_registry:getDesktopPrograms()
    for _, program in ipairs(desktop_programs) do
        -- Check if deleted
        if not self.desktop_icons:isDeleted(program.id) then
            -- Check if currently being dragged
            if program.id ~= dragging_icon_id then
                local pos = self.desktop_icons:getPosition(program.id) or self:getDefaultIconPosition(program.id)
                self:drawIcon(program, program.id == self.hovered_program_id, pos)
            end
             -- The dragged icon itself is drawn separately in DesktopState:draw
        end
    end

    -- Draw taskbar
    self:drawTaskbar(tokens)

    -- Draw start menu
    if start_menu_open then
        self:drawStartMenu()
    end

    -- Draw run dialog
    if run_dialog_open then
        self:drawRunDialog(run_text)
    end
end

function DesktopView:drawIcon(program, hovered, position_override, is_dragging)
    local SpriteLoader = require('src.utils.sprite_loader')
    local sprite_loader = SpriteLoader.getInstance()
    
    local pos = position_override or self.desktop_icons:getPosition(program.id) or self:getDefaultIconPosition(program.id)
    local px = pos.x
    local py = pos.y
    local pw, ph = self.desktop_icons:getIconDimensions()

    local desktop_cfg = (Config and Config.ui and Config.ui.desktop) or {}
    local icons_cfg = desktop_cfg.icons or {}
    local base_alpha = is_dragging and 0.6 or 1.0

    -- Icon area
    local icon_size = icons_cfg.sprite_size or 48
    local icon_x = px + (pw - icon_size) / 2
    local icon_y = py + (icons_cfg.sprite_offset_y or 10)
    
    -- Draw icon sprite or fallback
    local sprite_name = program.icon_sprite
    local tint = {1, 1, 1, base_alpha}
    
    if hovered then
        tint = {icons_cfg.hover_tint or 1.2, icons_cfg.hover_tint or 1.2, icons_cfg.hover_tint or 1.2, base_alpha}
    end
    
    -- Special handling for Recycle Bin state
    if program.id == "recycle_bin" then
        local isEmpty = self.recycle_bin:isEmpty()
        sprite_name = isEmpty and "recycle_bin_empty-0" or "recycle_bin_full-0"
    end
    
    sprite_loader:drawSprite(sprite_name, icon_x, icon_y, icon_size, icon_size, tint)
    
    -- Recycle bin fullness indicator
    if program.id == "recycle_bin" and not self.recycle_bin:isEmpty() then
        local ind = icons_cfg.recycle_indicator or {}
        love.graphics.setColor(1, 1, 0, base_alpha)
        love.graphics.circle('fill', icon_x + icon_size - (ind.offset_x or 5), icon_y + (ind.offset_y or 5), ind.radius or 4)
    end

    -- Label background and text
    love.graphics.setColor(1, 1, 1, base_alpha)
    local label_y = icon_y + icon_size + (icons_cfg.label_margin_top or 5)
    local font = love.graphics.getFont()
    local text_width = font:getWidth(program.name)
    local label_x = px + (pw - text_width) / 2

    love.graphics.setColor(0, 0, 0, 0.5 * base_alpha)
    love.graphics.rectangle('fill', label_x - (icons_cfg.label_padding_x or 2), label_y - (icons_cfg.label_padding_y or 1), text_width + 2 * (icons_cfg.label_padding_x or 2), font:getHeight() + 2 * (icons_cfg.label_padding_y or 1))
    love.graphics.setColor(1, 1, 1, base_alpha)
    love.graphics.print(program.name, label_x, label_y)

    -- Disabled overlay
    if program.disabled then
        love.graphics.setColor(0, 0, 0, (icons_cfg.disabled_overlay_alpha or 0.5) * base_alpha)
        love.graphics.rectangle('fill', px, py, pw, ph)
    end
end

function DesktopView:mousepressed(x, y, button)
     -- Only needed for initial click detection before state takes over
     if button ~= 1 then return nil end

    -- Check start button
    if self:isStartButtonHovered(x, y) then
        return {name = "start_button_click"} -- Let state handle toggling menu
    end

    -- Check desktop icons (return ID for state to handle drag/launch)
    local program_id = self:getProgramAtPosition(x, y)
    if program_id then
        return {name = "icon_click", program_id = program_id}
    end

    -- Taskbar button clicks are handled directly in DesktopState using getTaskbarButtonAtPosition

    return nil -- Clicked on empty space
end

function DesktopView:mousepressedStartMenu(x, y, button)
    if button ~= 1 then return nil end

     if x >= self.start_menu_x and x <= self.start_menu_x + self.start_menu_w and
         y >= self.start_menu_y and y <= self.start_menu_y + self.start_menu_h then

        local result = self:getStartMenuProgramAtPosition(x, y)
        if result then
            if result == "run" then return {name = "open_run"}
            else return {name = "launch_program", program_id = result} end
        end
        return nil -- Click inside menu but not on item
    else
        return {name = "close_start_menu"} -- Clicked outside
    end
end

function DesktopView:mousepressedRunDialog(x, y, button)
    if button ~= 1 then return nil end

    local run_cfg = ((Config and Config.ui and Config.ui.desktop) or {}).run_dialog or {}
    local buttons = run_cfg.buttons or {}
    local ok_x = self.run_dialog_x + self.run_dialog_w - (buttons.ok_offset_x or 180)
    local ok_y = self.run_dialog_y + self.run_dialog_h - (buttons.bottom_margin or 40)
    if x >= ok_x and x <= ok_x + (buttons.ok_w or 80) and y >= ok_y and y <= ok_y + (buttons.ok_h or 30) then return {name = "run_execute"} end

    local cancel_x = self.run_dialog_x + self.run_dialog_w - (buttons.cancel_offset_x or 90)
    local cancel_y = self.run_dialog_y + self.run_dialog_h - (buttons.bottom_margin or 40)
    if x >= cancel_x and x <= cancel_x + (buttons.cancel_w or 80) and y >= cancel_y and y <= cancel_y + (buttons.cancel_h or 30) then return {name = "run_cancel"} end

    return nil
end

-- Get program at position using model data
function DesktopView:getProgramAtPosition(x, y)
    local desktop_programs = self.program_registry:getDesktopPrograms()
    local icon_w, icon_h = self.desktop_icons:getIconDimensions()

    for _, program in ipairs(desktop_programs) do
        if not self.desktop_icons:isDeleted(program.id) then
            local pos = self.desktop_icons:getPosition(program.id) or self:getDefaultIconPosition(program.id)
            if x >= pos.x and x <= pos.x + icon_w and y >= pos.y and y <= pos.y + icon_h then
                return program.id
            end
        end
    end
    return nil
end


function DesktopView:getStartMenuProgramAtPosition(x, y)
    local start_programs = self.program_registry:getStartMenuPrograms()
    local start_cfg = (((Config and Config.ui and Config.ui.desktop) or {}).start_menu) or {}
    local item_y = self.start_menu_y + (start_cfg.padding or 10)
    local item_h = start_cfg.item_height or 25

    for _, program in ipairs(start_programs) do
        if x >= self.start_menu_x and x <= self.start_menu_x + self.start_menu_w and
           y >= item_y and y <= item_y + item_h then
            return program.id
        end
        item_y = item_y + item_h
    end

    item_y = item_y + (start_cfg.separator_space or 10) -- Separator space
    if x >= self.start_menu_x and x <= self.start_menu_x + self.start_menu_w and
       y >= item_y and y <= item_y + item_h then
        return "run"
    end

    return nil
end

-- Helper to check if a point is within the Start Menu bounds
function DesktopView:isPointInStartMenu(x, y)
    -- Check if start menu is even relevant (open is handled by state)
    -- Just check bounds based on view layout variables
    return x >= self.start_menu_x and x <= self.start_menu_x + self.start_menu_w and
           y >= self.start_menu_y and y <= self.start_menu_y + self.start_menu_h
end

-- Helper to check if a point is within the Run Dialog bounds
function DesktopView:isPointInRunDialog(x, y)
    -- Check if run dialog is relevant (open is handled by state)
    -- Just check bounds based on view layout variables
    return x >= self.run_dialog_x and x <= self.run_dialog_x + self.run_dialog_w and
           y >= self.run_dialog_y and y <= self.run_dialog_y + self.run_dialog_h
end

function DesktopView:isStartButtonHovered(x, y)
    local taskbar_y = love.graphics.getHeight() - self.taskbar_height
    local taskbar_cfg = (Config and Config.ui and Config.ui.taskbar) or {}
    local left_margin = taskbar_cfg.left_margin or 10
    local vpad = taskbar_cfg.vertical_padding or 5
    return x >= left_margin and x <= left_margin + self.taskbar_start_button_width and y >= taskbar_y + vpad and y <= taskbar_y + self.taskbar_height - vpad
end

-- Get Recycle Bin icon position (needed for drop detection)
function DesktopView:getRecycleBinPosition()
    local program = self.program_registry:getProgram("recycle_bin")
    if not program or self.desktop_icons:isDeleted("recycle_bin") then return nil end

    local pos = self.desktop_icons:getPosition("recycle_bin") or self:getDefaultIconPosition("recycle_bin")
    local w, h = self.desktop_icons:getIconDimensions()
    return { x = pos.x, y = pos.y, w = w, h = h }
end

function DesktopView:drawTaskbar(tokens)
    local y = love.graphics.getHeight() - self.taskbar_height
    local screen_width = love.graphics.getWidth()

    local colors = (((Config and Config.ui and Config.ui.colors) or {}))
    local taskbar_colors = colors.taskbar or {}
    love.graphics.setColor(taskbar_colors.bg or {0.75, 0.75, 0.75}); love.graphics.rectangle('fill', 0, y, screen_width, self.taskbar_height)
    love.graphics.setColor(taskbar_colors.top_line or {1, 1, 1}); love.graphics.line(0, y, screen_width, y)

    local taskbar_cfg = (Config and Config.ui and Config.ui.taskbar) or {}
    local left_margin = taskbar_cfg.left_margin or 10
    local vpad = taskbar_cfg.vertical_padding or 5
    self:drawStartButton(left_margin, y + vpad, self.taskbar_height - 2 * vpad)
    self:drawSystemTray(screen_width - self.taskbar_sys_tray_width, y + vpad, self.taskbar_sys_tray_width - 2 * vpad, self.taskbar_height - 2 * vpad, tokens)

    local button_area_start_x = self.taskbar_button_start_x
    local button_area_end_x = screen_width - self.taskbar_sys_tray_width
    local button_area_width = button_area_end_x - button_area_start_x
    local windows = self.window_manager:getWindowsInCreationOrder()
    local num_windows = #windows
    if num_windows == 0 then return end

    local total_padding = (num_windows - 1) * self.taskbar_button_padding
    local available_width_for_buttons = button_area_width - total_padding
    local button_width = available_width_for_buttons / num_windows
    button_width = math.max(self.taskbar_button_min_width, math.min(self.taskbar_button_max_width, button_width))

    local focused_window_id = self.window_manager:getFocusedWindowId()
    local font = love.graphics.getFont()
    local SpriteLoader = require('src.utils.sprite_loader')
    local sprite_loader = SpriteLoader.getInstance()

    for i, window in ipairs(windows) do
        local button_x = button_area_start_x + (i - 1) * (button_width + self.taskbar_button_padding)
        local button_y = y + 3
        local button_h = self.taskbar_height - 6
        local is_focused = (window.id == focused_window_id)
        local is_minimized = window.is_minimized
        local is_hovered = (window.id == self.hovered_taskbar_button_id)

        local top_left_color, bottom_right_color, bg_color
        if is_focused and not is_minimized then
             bg_color = {0.6, 0.6, 0.6}; top_left_color = {0.2, 0.2, 0.2}; bottom_right_color = {1, 1, 1}
        elseif is_hovered then
             bg_color = {0.85, 0.85, 0.85}; top_left_color = {1, 1, 1}; bottom_right_color = {0.2, 0.2, 0.2}
        else
             bg_color = {0.75, 0.75, 0.75}; top_left_color = {1, 1, 1}; bottom_right_color = {0.2, 0.2, 0.2}
        end

        love.graphics.setColor(bg_color)
        love.graphics.rectangle('fill', button_x, button_y, button_width, button_h)
        love.graphics.setColor(top_left_color)
        love.graphics.line(button_x, button_y, button_x + button_width, button_y)
        love.graphics.line(button_x, button_y, button_x, button_y + button_h)
        love.graphics.setColor(bottom_right_color)
        love.graphics.line(button_x + button_width, button_y, button_x + button_width, button_y + button_h)
        love.graphics.line(button_x, button_y + button_h, button_x + button_width, button_y + button_h)

        local icon_size = 16
        local icon_x = button_x + 3
        local icon_y = button_y + (button_h - icon_size) / 2
        
        if window.icon_sprite then
            sprite_loader:drawSprite(window.icon_sprite, icon_x, icon_y, icon_size, icon_size, {1, 1, 1})
        end

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

        if is_minimized then
            love.graphics.setColor(0.4, 0.4, 0.4, 0.5)
            love.graphics.rectangle('fill', button_x, button_y, button_width, button_h)
        end
    end
end

function DesktopView:getTaskbarButtonAtPosition(x, y)
    local taskbar_y = love.graphics.getHeight() - self.taskbar_height
    if y < taskbar_y or y > love.graphics.getHeight() then return nil end

    local screen_width = love.graphics.getWidth()
    local button_area_start_x = self.taskbar_button_start_x
    local button_area_end_x = screen_width - self.taskbar_sys_tray_width
    local button_area_width = button_area_end_x - button_area_start_x
    if x < button_area_start_x or x > button_area_end_x then return nil end

    local windows = self.window_manager:getAllWindows()
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
        if button_index >= 1 and button_index <= num_windows then return windows[button_index].id end
    end
    return nil
end

function DesktopView:drawStartButton(x, y, size)
    local w = self.taskbar_start_button_width
    local h = size
    local hovered = self.start_button_hovered
    local colors = (Config and Config.ui and Config.ui.colors and Config.ui.colors.start_button) or {}
    love.graphics.setColor(hovered and (colors.bg_hover or {0.85, 0.85, 0.85}) or (colors.bg or {0.75, 0.75, 0.75}))
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor((colors.border_light or {1, 1, 1})); love.graphics.line(x, y, x + w, y); love.graphics.line(x, y, x, y + h)
    love.graphics.setColor((colors.border_dark or {0.2, 0.2, 0.2})); love.graphics.line(x + w, y, x + w, y + h); love.graphics.line(x, y + h, x + w, y + h)
    love.graphics.setColor(colors.text or {0, 0, 0})
    local tb_text = (Config and Config.ui and Config.ui.taskbar_text) or {}
    local start_off = tb_text.start_text_offset or { x = 5, y = 5 }
    local start_scale = tb_text.start_text_scale or 0.9
    love.graphics.print(Strings.get('start.title','Start'), x + start_off.x, y + start_off.y, 0, start_scale, start_scale)
end


function DesktopView:drawSystemTray(x, y, w, h, tokens)
    local colors = (Config and Config.ui and Config.ui.colors and Config.ui.colors.system_tray) or {}
    love.graphics.setColor(colors.bg or {0.6, 0.6, 0.6}); love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(colors.border_dark or {0.2, 0.2, 0.2}); love.graphics.line(x, y, x + w, y); love.graphics.line(x, y, x, y + h)
    love.graphics.setColor(colors.border_light or {1, 1, 1}); love.graphics.line(x + w, y, x + w, y + h); love.graphics.line(x, y + h, x + w, y + h)
    love.graphics.setColor(colors.text or {0, 0, 0})
    local tray_cfg = (((Config and Config.ui and Config.ui.desktop) or {}).system_tray) or {}
    local clock_off = tray_cfg.clock_right_offset or 50
    local clock_scale = tray_cfg.clock_text_scale or 1.2
    love.graphics.print(self.current_time, x + w - clock_off, y + 5, 0, clock_scale, clock_scale)
    local token_off = tray_cfg.token_offset or { x = 5, y = 3 }
    UIComponents.drawTokenCounter(x + token_off.x, y + token_off.y, tokens)
end

function DesktopView:drawStartMenu()
    local SpriteLoader = require('src.utils.sprite_loader')
    local sprite_loader = SpriteLoader.getInstance()
    local theme = (Config and Config.ui and Config.ui.colors and Config.ui.colors.start_menu) or {}
    love.graphics.setColor(theme.bg or {0.75, 0.75, 0.75})
    love.graphics.rectangle('fill', self.start_menu_x, self.start_menu_y, self.start_menu_w, self.start_menu_h)
    love.graphics.setColor(theme.border_light or {1, 1, 1})
    love.graphics.line(self.start_menu_x, self.start_menu_y, self.start_menu_x + self.start_menu_w, self.start_menu_y)
    love.graphics.line(self.start_menu_x, self.start_menu_y, self.start_menu_x, self.start_menu_y + self.start_menu_h)
    love.graphics.setColor(theme.border_dark or {0.2, 0.2, 0.2})
    love.graphics.line(self.start_menu_x + self.start_menu_w, self.start_menu_y, self.start_menu_x + self.start_menu_w, self.start_menu_y + self.start_menu_h)
    love.graphics.line(self.start_menu_x, self.start_menu_y + self.start_menu_h, self.start_menu_x + self.start_menu_w, self.start_menu_y + self.start_menu_h)

    local start_programs = self.program_registry:getStartMenuPrograms()
    local start_cfg = (((Config and Config.ui and Config.ui.desktop) or {}).start_menu) or {}
    local item_y = self.start_menu_y + (start_cfg.padding or 10)
    local item_h = start_cfg.item_height or 25
    local icon_size = start_cfg.icon_size or 20
    
    for _, program in ipairs(start_programs) do
        local is_hovered = self.hovered_start_program_id == program.id
        
        -- Highlight
        if is_hovered then
            local start_cfg = (((Config and Config.ui and Config.ui.desktop) or {}).start_menu) or {}
            local inset = start_cfg.highlight_inset or 2
            love.graphics.setColor(theme.highlight or {0, 0, 0.5})
            love.graphics.rectangle('fill', self.start_menu_x + inset, item_y, self.start_menu_w - 2 * inset, item_h)
        end
        
        -- Icon
    local icon_x = self.start_menu_x + 5
        local icon_y_centered = item_y + (item_h - icon_size) / 2
        
        local sprite_name = program.icon_sprite or "executable-0"
    local tint = program.disabled and {0.5, 0.5, 0.5} or (is_hovered and {1.2, 1.2, 1.2} or {1, 1, 1})
        sprite_loader:drawSprite(sprite_name, icon_x, icon_y_centered, icon_size, icon_size, tint)
        
    -- Text
    love.graphics.setColor(program.disabled and (theme.text_disabled or {0.5, 0.5, 0.5}) or (is_hovered and (theme.text_hover or {1,1,1}) or (theme.text or {0, 0, 0})))
        love.graphics.print(program.name, self.start_menu_x + icon_size + 10, item_y + 5)
        
        item_y = item_y + item_h
    end

    -- Separator
    item_y = item_y + 5
    love.graphics.setColor(theme.separator or {0.5, 0.5, 0.5})
    love.graphics.line(self.start_menu_x + 5, item_y, self.start_menu_x + self.start_menu_w - 5, item_y)
    item_y = item_y + 5
    
    -- Run option with icon
    local run_hovered = self.hovered_start_program_id == "run"
    if run_hovered then
        local start_cfg = (((Config and Config.ui and Config.ui.desktop) or {}).start_menu) or {}
        local inset = start_cfg.highlight_inset or 2
        love.graphics.setColor(theme.highlight or {0, 0, 0.5})
        love.graphics.rectangle('fill', self.start_menu_x + inset, item_y, self.start_menu_w - 2 * inset, item_h)
    end
    
    -- Run icon
    local icon_x = self.start_menu_x + 5
    local icon_y_centered = item_y + (item_h - icon_size) / 2
    sprite_loader:drawSprite("console_prompt-0", icon_x, icon_y_centered, icon_size, icon_size, run_hovered and {1.2, 1.2, 1.2} or {1, 1, 1})
    
    love.graphics.setColor(run_hovered and (theme.text_hover or {1,1,1}) or (theme.text or {0, 0, 0}))
    love.graphics.print(Strings.get('start.run','Run...'), self.start_menu_x + icon_size + 10, item_y + 5)
    love.graphics.setColor(theme.shortcut or {0.4, 0.4, 0.4})
    love.graphics.print("Ctrl+R", self.start_menu_x + self.start_menu_w - (start_cfg.run_shortcut_offset or 60), item_y + 5, 0, 0.8, 0.8)
end

function DesktopView:drawRunDialog(run_text)
    local desktop_cfg = (Config and Config.ui and Config.ui.desktop) or {}
    local run_cfg = desktop_cfg.run_dialog or {}
    local title_bar_h = run_cfg.title_bar_height or 25
    local pad = run_cfg.padding or 10
    local input_y = run_cfg.input_y or 65
    local input_h = run_cfg.input_h or 25
    local btns = run_cfg.buttons or {}
    local colors = (Config and Config.ui and Config.ui.colors and Config.ui.colors.run_dialog) or {}

    love.graphics.setColor(colors.bg or {0.75, 0.75, 0.75}); love.graphics.rectangle('fill', self.run_dialog_x, self.run_dialog_y, self.run_dialog_w, self.run_dialog_h)
    love.graphics.setColor(colors.title_bg or {0, 0, 0.5}); love.graphics.rectangle('fill', self.run_dialog_x, self.run_dialog_y, self.run_dialog_w, title_bar_h)
    love.graphics.setColor(colors.title_text or {1, 1, 1}); love.graphics.print(Strings.get('start.run','Run'), self.run_dialog_x + 5, self.run_dialog_y + 5)
    love.graphics.setColor(colors.label_text or {0, 0, 0}); love.graphics.print(Strings.get('start.type_prompt','Type the name of a program:'), self.run_dialog_x + pad, self.run_dialog_y + 40)
    love.graphics.setColor(colors.input_bg or {1, 1, 1}); love.graphics.rectangle('fill', self.run_dialog_x + pad, self.run_dialog_y + input_y, self.run_dialog_w - 2 * pad, input_h)
    love.graphics.setColor(colors.input_border or {0, 0, 0}); love.graphics.rectangle('line', self.run_dialog_x + pad, self.run_dialog_y + input_y, self.run_dialog_w - 2 * pad, input_h)
    love.graphics.setColor(colors.input_text or {0, 0, 0}); love.graphics.print(run_text, self.run_dialog_x + pad + 5, self.run_dialog_y + input_y + 5)
    UIComponents.drawButton(self.run_dialog_x + self.run_dialog_w - (btns.ok_offset_x or 180), self.run_dialog_y + self.run_dialog_h - (btns.bottom_margin or 40), btns.ok_w or 80, btns.ok_h or 30, Strings.get('buttons.ok','OK'), true, false)
    UIComponents.drawButton(self.run_dialog_x + self.run_dialog_w - (btns.cancel_offset_x or 90), self.run_dialog_y + self.run_dialog_h - (btns.bottom_margin or 40), btns.cancel_w or 80, btns.cancel_h or 30, Strings.get('buttons.cancel','Cancel'), true, false)
end


return DesktopView