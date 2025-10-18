-- src/views/desktop_view.lua
local Object = require('class')
local UIComponents = require('src.views.ui_components')
local DesktopView = Object:extend('DesktopView')

function DesktopView:init(program_registry, player_data, window_manager, desktop_icons, recycle_bin)
    self.program_registry = program_registry
    self.player_data = player_data
    self.window_manager = window_manager
    self.desktop_icons = desktop_icons -- Injected
    self.recycle_bin = recycle_bin -- Injected

    self.taskbar_height = 40
    self.clock_update_timer = 0
    self.current_time = ""

    -- Hover state
    self.hovered_program_id = nil
    self.hovered_start_program_id = nil
    self.start_button_hovered = false
    self.hovered_taskbar_button_id = nil

    -- Icon layout defaults (dimensions from model now)
    self.icon_width, self.icon_height = self.desktop_icons:getIconDimensions()
    self.icon_padding = 20
    self.icon_start_x = 20
    self.icon_start_y = 20
    self.default_icon_positions = {} -- Cache default grid positions

    self:calculateDefaultIconPositionsIfNeeded() -- Calculate defaults once

    -- Start menu layout
    self.start_menu_w = 200
    self.start_menu_h = 300
    self.start_menu_x = 0
    self.start_menu_y = love.graphics.getHeight() - self.taskbar_height - self.start_menu_h

    -- Run dialog layout
    self.run_dialog_w = 400
    self.run_dialog_h = 150
    self.run_dialog_x = (love.graphics.getWidth() - self.run_dialog_w) / 2
    self.run_dialog_y = (love.graphics.getHeight() - self.run_dialog_h) / 2

     -- Taskbar layout
    self.taskbar_start_button_width = 60
    self.taskbar_sys_tray_width = 150
    self.taskbar_button_max_width = 160
    self.taskbar_button_min_width = 80
    self.taskbar_button_padding = 4
    self.taskbar_button_start_x = self.taskbar_start_button_width + 10
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

    local ok_x = self.run_dialog_x + self.run_dialog_w - 180
    local ok_y = self.run_dialog_y + self.run_dialog_h - 40
    if x >= ok_x and x <= ok_x + 80 and y >= ok_y and y <= ok_y + 30 then return {name = "run_execute"} end

    local cancel_x = self.run_dialog_x + self.run_dialog_w - 90
    local cancel_y = self.run_dialog_y + self.run_dialog_h - 40
    if x >= cancel_x and x <= cancel_x + 80 and y >= cancel_y and y <= cancel_y + 30 then return {name = "run_cancel"} end

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
    local item_y = self.start_menu_y + 10
    local item_h = 25

    for _, program in ipairs(start_programs) do
        if x >= self.start_menu_x and x <= self.start_menu_x + self.start_menu_w and
           y >= item_y and y <= item_y + item_h then
            return program.id
        end
        item_y = item_y + item_h
    end

    item_y = item_y + 10 -- Separator space
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
    return x >= 10 and x <= 10 + self.taskbar_start_button_width and y >= taskbar_y + 5 and y <= taskbar_y + self.taskbar_height - 5
end

-- Get Recycle Bin icon position (needed for drop detection)
function DesktopView:getRecycleBinPosition()
    local program = self.program_registry:getProgram("recycle_bin")
    if not program or self.desktop_icons:isDeleted("recycle_bin") then return nil end

    local pos = self.desktop_icons:getPosition("recycle_bin") or self:getDefaultIconPosition("recycle_bin")
    local w, h = self.desktop_icons:getIconDimensions()
    return { x = pos.x, y = pos.y, w = w, h = h }
end

-- Drawing methods
function DesktopView:drawIcon(program, hovered, position_override, is_dragging)
    local pos = position_override or self.desktop_icons:getPosition(program.id) or self:getDefaultIconPosition(program.id)
    local px = pos.x
    local py = pos.y
    local pw, ph = self.desktop_icons:getIconDimensions()

    local base_alpha = is_dragging and 0.6 or 1.0 -- Make dragged icon semi-transparent

    -- Special handling for Recycle Bin state
    local icon_color = program.icon_color
    if program.id == "recycle_bin" then
         local isEmpty = self.recycle_bin:isEmpty()
         -- Use different colors/visuals based on isEmpty, e.g.:
         -- icon_color = isEmpty and {0.6, 0.6, 0.6} or {0.9, 0.9, 0.9} -- Simple color change
         -- Or load different sprites later
         -- For now, just add a small indicator
    end

    if hovered then love.graphics.setColor(icon_color[1] * 1.2, icon_color[2] * 1.2, icon_color[3] * 1.2, base_alpha)
    else love.graphics.setColor(icon_color[1], icon_color[2], icon_color[3], base_alpha) end

    local icon_size = 48
    local icon_x = px + (pw - icon_size) / 2
    local icon_y = py + 10
    love.graphics.rectangle('fill', icon_x, icon_y, icon_size, icon_size)

    -- Recycle bin fullness indicator (simple example)
    if program.id == "recycle_bin" and not self.recycle_bin:isEmpty() then
         love.graphics.setColor(1,1,0, base_alpha) -- Yellow dot when full
         love.graphics.circle('fill', icon_x + icon_size - 5, icon_y + 5, 4)
    end

    love.graphics.setColor(0, 0, 0, base_alpha)
    love.graphics.rectangle('line', icon_x, icon_y, icon_size, icon_size)

    love.graphics.setColor(1, 1, 1, base_alpha)
    local label_y = icon_y + icon_size + 5
    local font = love.graphics.getFont()
    local text_width = font:getWidth(program.name)
    local label_x = px + (pw - text_width) / 2

    love.graphics.setColor(0, 0, 0, 0.5 * base_alpha)
    love.graphics.rectangle('fill', label_x - 2, label_y - 1, text_width + 4, font:getHeight() + 2)
    love.graphics.setColor(1, 1, 1, base_alpha)
    love.graphics.print(program.name, label_x, label_y)

    if program.disabled then
        love.graphics.setColor(0, 0, 0, 0.5 * base_alpha)
        love.graphics.rectangle('fill', px, py, pw, ph)
    end
end

function DesktopView:drawTaskbar(tokens)
    local y = love.graphics.getHeight() - self.taskbar_height
    local screen_width = love.graphics.getWidth()

    love.graphics.setColor(0.75, 0.75, 0.75); love.graphics.rectangle('fill', 0, y, screen_width, self.taskbar_height)
    love.graphics.setColor(1, 1, 1); love.graphics.line(0, y, screen_width, y)

    self:drawStartButton(10, y + 5, self.taskbar_height - 10)
    self:drawSystemTray(screen_width - self.taskbar_sys_tray_width, y + 5, self.taskbar_sys_tray_width - 10, self.taskbar_height - 10, tokens)

    local button_area_start_x = self.taskbar_button_start_x
    local button_area_end_x = screen_width - self.taskbar_sys_tray_width
    local button_area_width = button_area_end_x - button_area_start_x
    local windows = self.window_manager:getAllWindows()
    local num_windows = #windows
    if num_windows == 0 then return end

    local total_padding = (num_windows - 1) * self.taskbar_button_padding
    local available_width_for_buttons = button_area_width - total_padding
    local button_width = available_width_for_buttons / num_windows
    button_width = math.max(self.taskbar_button_min_width, math.min(self.taskbar_button_max_width, button_width))

    local focused_window_id = self.window_manager:getFocusedWindowId()
    local font = love.graphics.getFont()

    for i, window in ipairs(windows) do
        local button_x = button_area_start_x + (i - 1) * (button_width + self.taskbar_button_padding)
        local button_y = y + 3
        local button_h = self.taskbar_height - 6
        local is_focused = (window.id == focused_window_id)
        local is_minimized = window.is_minimized
        local is_hovered = (window.id == self.hovered_taskbar_button_id) -- Check hover state

        -- Button Appearance (Raised/Pressed/Hover)
        local top_left_color, bottom_right_color, bg_color
        if is_focused and not is_minimized then
             bg_color = {0.6, 0.6, 0.6}; top_left_color = {0.2, 0.2, 0.2}; bottom_right_color = {1, 1, 1} -- Pressed
        elseif is_hovered then
             bg_color = {0.85, 0.85, 0.85}; top_left_color = {1, 1, 1}; bottom_right_color = {0.2, 0.2, 0.2} -- Hover
        else
             bg_color = {0.75, 0.75, 0.75}; top_left_color = {1, 1, 1}; bottom_right_color = {0.2, 0.2, 0.2} -- Raised
        end

        love.graphics.setColor(bg_color); love.graphics.rectangle('fill', button_x, button_y, button_width, button_h)
        love.graphics.setColor(top_left_color); love.graphics.line(button_x, button_y, button_x + button_width, button_y); love.graphics.line(button_x, button_y, button_x, button_y + button_h)
        love.graphics.setColor(bottom_right_color); love.graphics.line(button_x + button_width, button_y, button_x + button_width, button_y + button_h); love.graphics.line(button_x, button_y + button_h, button_x + button_width, button_y + button_h)


        -- Title Text (Truncated)
        love.graphics.setColor(0, 0, 0)
        local max_text_width = button_width - 10
        local truncated_title = window.title or "Untitled"
        if font:getWidth(truncated_title) > max_text_width then
            local ellipsis_width = font:getWidth("...")
            while font:getWidth(truncated_title) + ellipsis_width > max_text_width and #truncated_title > 0 do
                truncated_title = truncated_title:sub(1, -2)
            end
            truncated_title = truncated_title .. "..."
        end
        local text_y = button_y + (button_h - font:getHeight()) / 2
        love.graphics.print(truncated_title, button_x + 5, text_y)

        if is_minimized then love.graphics.setColor(0.4, 0.4, 0.4, 0.5); love.graphics.rectangle('fill', button_x, button_y, button_width, button_h) end
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
    love.graphics.setColor(hovered and {0.85, 0.85, 0.85} or {0.75, 0.75, 0.75})
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(1, 1, 1); love.graphics.line(x, y, x + w, y); love.graphics.line(x, y, x, y + h)
    love.graphics.setColor(0.2, 0.2, 0.2); love.graphics.line(x + w, y, x + w, y + h); love.graphics.line(x, y + h, x + w, y + h)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Start", x + 5, y + 5, 0, 0.9, 0.9)
end


function DesktopView:drawSystemTray(x, y, w, h, tokens)
    love.graphics.setColor(0.6, 0.6, 0.6); love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0.2, 0.2, 0.2); love.graphics.line(x, y, x + w, y); love.graphics.line(x, y, x, y + h)
    love.graphics.setColor(1, 1, 1); love.graphics.line(x + w, y, x + w, y + h); love.graphics.line(x, y + h, x + w, y + h)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(self.current_time, x + w - 50, y + 5, 0, 1.2, 1.2)
    UIComponents.drawTokenCounter(x + 5, y + 3, tokens)
end

function DesktopView:drawStartMenu()
    love.graphics.setColor(0.75, 0.75, 0.75); love.graphics.rectangle('fill', self.start_menu_x, self.start_menu_y, self.start_menu_w, self.start_menu_h)
    love.graphics.setColor(1, 1, 1); love.graphics.line(self.start_menu_x, self.start_menu_y, self.start_menu_x + self.start_menu_w, self.start_menu_y); love.graphics.line(self.start_menu_x, self.start_menu_y, self.start_menu_x, self.start_menu_y + self.start_menu_h)
    love.graphics.setColor(0.2, 0.2, 0.2); love.graphics.line(self.start_menu_x + self.start_menu_w, self.start_menu_y, self.start_menu_x + self.start_menu_w, self.start_menu_y + self.start_menu_h); love.graphics.line(self.start_menu_x, self.start_menu_y + self.start_menu_h, self.start_menu_x + self.start_menu_w, self.start_menu_y + self.start_menu_h)

    local start_programs = self.program_registry:getStartMenuPrograms()
    local item_y = self.start_menu_y + 10
    local item_h = 25
    for _, program in ipairs(start_programs) do
        local is_hovered = self.hovered_start_program_id == program.id
        if is_hovered then love.graphics.setColor(0, 0, 0.5); love.graphics.rectangle('fill', self.start_menu_x + 2, item_y, self.start_menu_w - 4, item_h) end
        love.graphics.setColor(program.disabled and {0.5, 0.5, 0.5} or (is_hovered and {1,1,1} or {0, 0, 0}))
        love.graphics.print(program.name, self.start_menu_x + 10, item_y + 5)
        item_y = item_y + item_h
    end

    item_y = item_y + 5; love.graphics.setColor(0.5, 0.5, 0.5); love.graphics.line(self.start_menu_x + 5, item_y, self.start_menu_x + self.start_menu_w - 5, item_y); item_y = item_y + 5
    local run_hovered = self.hovered_start_program_id == "run"
    if run_hovered then love.graphics.setColor(0, 0, 0.5); love.graphics.rectangle('fill', self.start_menu_x + 2, item_y, self.start_menu_w - 4, item_h) end
    love.graphics.setColor(run_hovered and {1,1,1} or {0, 0, 0})
    love.graphics.print("Run...", self.start_menu_x + 10, item_y + 5)
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.print("Ctrl+R", self.start_menu_x + self.start_menu_w - 60, item_y + 5, 0, 0.8, 0.8)
end

function DesktopView:drawRunDialog(run_text)
    love.graphics.setColor(0.75, 0.75, 0.75); love.graphics.rectangle('fill', self.run_dialog_x, self.run_dialog_y, self.run_dialog_w, self.run_dialog_h)
    love.graphics.setColor(0, 0, 0.5); love.graphics.rectangle('fill', self.run_dialog_x, self.run_dialog_y, self.run_dialog_w, 25)
    love.graphics.setColor(1, 1, 1); love.graphics.print("Run", self.run_dialog_x + 5, self.run_dialog_y + 5)
    love.graphics.setColor(0, 0, 0); love.graphics.print("Type the name of a program:", self.run_dialog_x + 10, self.run_dialog_y + 40)
    love.graphics.setColor(1, 1, 1); love.graphics.rectangle('fill', self.run_dialog_x + 10, self.run_dialog_y + 65, self.run_dialog_w - 20, 25)
    love.graphics.setColor(0, 0, 0); love.graphics.rectangle('line', self.run_dialog_x + 10, self.run_dialog_y + 65, self.run_dialog_w - 20, 25)
    love.graphics.print(run_text, self.run_dialog_x + 15, self.run_dialog_y + 70)
    UIComponents.drawButton(self.run_dialog_x + self.run_dialog_w - 180, self.run_dialog_y + self.run_dialog_h - 40, 80, 30, "OK", true, false)
    UIComponents.drawButton(self.run_dialog_x + self.run_dialog_w - 90, self.run_dialog_y + self.run_dialog_h - 40, 80, 30, "Cancel", true, false)
end


return DesktopView