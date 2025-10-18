local Object = require('class')
local UIComponents = require('src.views.ui_components')
local DesktopView = Object:extend('DesktopView')

-- Dependency injection: receive what we need to draw
function DesktopView:init(program_registry, player_data)
    self.program_registry = program_registry
    self.player_data = player_data
    
    self.taskbar_height = 40
    self.clock_update_timer = 0
    self.current_time = ""
    
    -- Hover state
    self.hovered_program_id = nil
    self.hovered_start_program_id = nil
    self.start_button_hovered = false
    
    -- Icon layout
    self.icon_width = 80
    self.icon_height = 100
    self.icon_padding = 20
    self.icon_start_x = 20
    self.icon_start_y = 20
    
    -- Calculate desktop icon positions
    self:calculateIconPositions()
    
    -- Start menu layout - position directly above start button
    self.start_menu_w = 200
    self.start_menu_h = 300
    self.start_menu_x = 0
    self.start_menu_y = love.graphics.getHeight() - self.taskbar_height - self.start_menu_h
    
    -- Run dialog layout
    self.run_dialog_w = 400
    self.run_dialog_h = 150
    self.run_dialog_x = (love.graphics.getWidth() - self.run_dialog_w) / 2
    self.run_dialog_y = (love.graphics.getHeight() - self.run_dialog_h) / 2
end

function DesktopView:calculateIconPositions()
    local desktop_programs = self.program_registry:getDesktopPrograms()
    
    -- Calculate how many icons fit vertically (accounting for taskbar)
    local available_height = love.graphics.getHeight() - self.taskbar_height - self.icon_start_y
    local icons_per_column = math.floor(available_height / (self.icon_height + self.icon_padding))
    
    -- Position icons in columns
    local col = 0
    local row = 0
    
    for _, program in ipairs(desktop_programs) do
        program.desktop_position = {
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

function DesktopView:update(dt, start_menu_open)
    -- Update clock
    self.clock_update_timer = self.clock_update_timer + dt
    if self.clock_update_timer >= 1.0 then
        self.current_time = os.date("%H:%M")
        self.clock_update_timer = 0
    end
    
    -- Update hover states
    local mx, my = love.mouse.getPosition()
    self.hovered_program_id = self:getProgramAtPosition(mx, my)
    self.start_button_hovered = self:isStartButtonHovered(mx, my)
    
    if start_menu_open then
        self.hovered_start_program_id = self:getStartMenuProgramAtPosition(mx, my)
    else
        self.hovered_start_program_id = nil
    end
end

function DesktopView:draw(wallpaper_color, tokens, start_menu_open, run_dialog_open, run_text)
    -- Draw wallpaper
    love.graphics.setColor(wallpaper_color)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw desktop icons
    local desktop_programs = self.program_registry:getDesktopPrograms()
    for _, program in ipairs(desktop_programs) do
        self:drawIcon(program, program.id == self.hovered_program_id)
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
    if button ~= 1 then return nil end
    
    -- Check start button
    if self:isStartButtonHovered(x, y) then
        return {name = "start_button_click"}
    end
    
    -- Check desktop icons
    local program_id = self:getProgramAtPosition(x, y)
    if program_id then
        return {name = "icon_click", program_id = program_id}
    end
    
    return nil
end

function DesktopView:mousepressedStartMenu(x, y, button)
    if button ~= 1 then return nil end
    
    -- Check if inside menu bounds
    if x >= self.start_menu_x and x <= self.start_menu_x + self.start_menu_w and
       y >= self.start_menu_y and y <= self.start_menu_y + self.start_menu_h then
        
        local result = self:getStartMenuProgramAtPosition(x, y)
        if result then
            if result == "run" then
                return {name = "open_run"}
            else
                return {name = "launch_program", program_id = result}
            end
        end
        return nil
    else
        -- Clicked outside
        return {name = "close_start_menu"}
    end
end

function DesktopView:mousepressedRunDialog(x, y, button)
    if button ~= 1 then return nil end
    
    -- Check OK button
    local ok_x = self.run_dialog_x + self.run_dialog_w - 180
    local ok_y = self.run_dialog_y + self.run_dialog_h - 40
    if x >= ok_x and x <= ok_x + 80 and y >= ok_y and y <= ok_y + 30 then
        return {name = "run_execute"}
    end
    
    -- Check Cancel button
    local cancel_x = self.run_dialog_x + self.run_dialog_w - 90
    local cancel_y = self.run_dialog_y + self.run_dialog_h - 40
    if x >= cancel_x and x <= cancel_x + 80 and y >= cancel_y and y <= cancel_y + 30 then
        return {name = "run_cancel"}
    end
    
    return nil
end

-- Helper: Get program at position (desktop icons)
function DesktopView:getProgramAtPosition(x, y)
    local desktop_programs = self.program_registry:getDesktopPrograms()
    for _, program in ipairs(desktop_programs) do
        local px = program.desktop_position.x
        local py = program.desktop_position.y
        local pw = self.icon_width
        local ph = self.icon_height
        
        if x >= px and x <= px + pw and y >= py and y <= py + ph then
            return program.id
        end
    end
    return nil
end

-- Helper: Get program at position (start menu)
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
    
    -- Check "Run..." (after separator)
    item_y = item_y + 10
    if x >= self.start_menu_x and x <= self.start_menu_x + self.start_menu_w and
       y >= item_y and y <= item_y + item_h then
        return "run"
    end
    
    return nil
end

function DesktopView:isStartButtonHovered(x, y)
    local taskbar_y = love.graphics.getHeight() - self.taskbar_height
    return x >= 10 and x <= 70 and y >= taskbar_y + 5 and y <= taskbar_y + self.taskbar_height - 5
end

-- Drawing methods
function DesktopView:drawIcon(program, hovered)
    local px = program.desktop_position.x
    local py = program.desktop_position.y
    local pw = self.icon_width
    local ph = self.icon_height
    
    local color = program.icon_color
    if hovered then
        love.graphics.setColor(color[1] * 1.2, color[2] * 1.2, color[3] * 1.2)
    else
        love.graphics.setColor(color)
    end
    
    -- Icon square
    local icon_size = 48
    local icon_x = px + (pw - icon_size) / 2
    local icon_y = py + 10
    
    love.graphics.rectangle('fill', icon_x, icon_y, icon_size, icon_size)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', icon_x, icon_y, icon_size, icon_size)
    
    -- Label
    love.graphics.setColor(1, 1, 1)
    local label_y = icon_y + icon_size + 5
    local font = love.graphics.getFont()
    local text_width = font:getWidth(program.name)
    local label_x = px + (pw - text_width) / 2
    
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle('fill', label_x - 2, label_y - 1, text_width + 4, font:getHeight() + 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(program.name, label_x, label_y)
    
    -- Disabled overlay
    if program.disabled then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', px, py, pw, ph)
    end
end

function DesktopView:drawTaskbar(tokens)
    local y = love.graphics.getHeight() - self.taskbar_height
    
    -- Background
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', 0, y, love.graphics.getWidth(), self.taskbar_height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(0, y, love.graphics.getWidth(), y)
    
    -- Start button
    self:drawStartButton(10, y + 5, self.taskbar_height - 10)
    
    -- System tray
    self:drawSystemTray(love.graphics.getWidth() - 150, y + 5, 140, self.taskbar_height - 10, tokens)
end

function DesktopView:drawStartButton(x, y, size)
    love.graphics.setColor(self.start_button_hovered and {0.6, 0.6, 0.6} or {0.5, 0.5, 0.5})
    love.graphics.rectangle('fill', x, y, size * 2, size)
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(x, y, x + size * 2, y)
    love.graphics.line(x, y, x, y + size)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.line(x + size * 2, y, x + size * 2, y + size)
    love.graphics.line(x, y + size, x + size * 2, y + size)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Start", x + 5, y + 5, 0, 0.9, 0.9)
end

function DesktopView:drawSystemTray(x, y, w, h, tokens)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.line(x, y, x + w, y)
    love.graphics.line(x, y, x, y + h)
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(x + w, y, x + w, y + h)
    love.graphics.line(x, y + h, x + w, y + h)
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(self.current_time, x + w - 50, y + 5, 0, 1.2, 1.2)
    
    UIComponents.drawTokenCounter(x + 5, y + 3, tokens)
end

function DesktopView:drawStartMenu()
    -- Background
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', self.start_menu_x, self.start_menu_y, self.start_menu_w, self.start_menu_h)
    
    -- Border
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(self.start_menu_x, self.start_menu_y, self.start_menu_x + self.start_menu_w, self.start_menu_y)
    love.graphics.line(self.start_menu_x, self.start_menu_y, self.start_menu_x, self.start_menu_y + self.start_menu_h)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.line(self.start_menu_x + self.start_menu_w, self.start_menu_y, self.start_menu_x + self.start_menu_w, self.start_menu_y + self.start_menu_h)
    love.graphics.line(self.start_menu_x, self.start_menu_y + self.start_menu_h, self.start_menu_x + self.start_menu_w, self.start_menu_y + self.start_menu_h)
    
    -- Menu items
    local start_programs = self.program_registry:getStartMenuPrograms()
    local item_y = self.start_menu_y + 10
    local item_h = 25
    
    for _, program in ipairs(start_programs) do
        local is_hovered = self.hovered_start_program_id == program.id
        
        if is_hovered then
            love.graphics.setColor(0, 0, 0.5)
            love.graphics.rectangle('fill', self.start_menu_x + 2, item_y, self.start_menu_w - 4, item_h)
        end
        
        love.graphics.setColor(program.disabled and {0.5, 0.5, 0.5} or {0, 0, 0})
        love.graphics.print(program.name, self.start_menu_x + 10, item_y + 5)
        
        item_y = item_y + item_h
    end
    
    -- Separator
    item_y = item_y + 5
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.line(self.start_menu_x + 5, item_y, self.start_menu_x + self.start_menu_w - 5, item_y)
    item_y = item_y + 5
    
    -- Run... option with Ctrl+R shortcut display
    local run_hovered = self.hovered_start_program_id == "run"
    if run_hovered then
        love.graphics.setColor(0, 0, 0.5)
        love.graphics.rectangle('fill', self.start_menu_x + 2, item_y, self.start_menu_w - 4, item_h)
    end
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Run...", self.start_menu_x + 10, item_y + 5)
    
    -- Draw shortcut hint
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.print("Ctrl+R", self.start_menu_x + self.start_menu_w - 60, item_y + 5, 0, 0.8, 0.8)
end

function DesktopView:drawRunDialog(run_text)
    -- Background
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', self.run_dialog_x, self.run_dialog_y, self.run_dialog_w, self.run_dialog_h)
    
    -- Title bar
    love.graphics.setColor(0, 0, 0.5)
    love.graphics.rectangle('fill', self.run_dialog_x, self.run_dialog_y, self.run_dialog_w, 25)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Run", self.run_dialog_x + 5, self.run_dialog_y + 5)
    
    -- Instructions
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Type the name of a program:", self.run_dialog_x + 10, self.run_dialog_y + 40)
    
    -- Input box
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', self.run_dialog_x + 10, self.run_dialog_y + 65, self.run_dialog_w - 20, 25)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', self.run_dialog_x + 10, self.run_dialog_y + 65, self.run_dialog_w - 20, 25)
    love.graphics.print(run_text, self.run_dialog_x + 15, self.run_dialog_y + 70)
    
    -- Buttons
    UIComponents.drawButton(self.run_dialog_x + self.run_dialog_w - 180, self.run_dialog_y + self.run_dialog_h - 40, 80, 30, "OK", true, false)
    UIComponents.drawButton(self.run_dialog_x + self.run_dialog_w - 90, self.run_dialog_y + self.run_dialog_h - 40, 80, 30, "Cancel", true, false)
end

return DesktopView