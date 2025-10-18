-- desktop_view.lua: View class for the Desktop

local Object = require('class')
local UIComponents = require('src.views.ui_components') -- Added require
local DesktopView = Object:extend('DesktopView')

function DesktopView:init(controller, player_data)
    self.controller = controller
    self.player_data = player_data
    
    self.taskbar_height = 40
    self.clock_update_timer = 0
    self.current_time = ""
    self.hovered_icon_index = nil
end

function DesktopView:update(dt, icons)
    -- Update clock every second
    self.clock_update_timer = self.clock_update_timer + dt
    if self.clock_update_timer >= 1.0 then
        self.current_time = os.date("%H:%M")
        self.clock_update_timer = 0
    end
    
    -- Update hovered icon
    local mx, my = love.mouse.getPosition()
    self.hovered_icon_index = self:getIconAtPosition(mx, my, icons)
end

function DesktopView:draw(icons, wallpaper_color, tokens)
    -- Draw wallpaper
    self:drawWallpaper(wallpaper_color)
    
    -- Draw desktop icons
    for i, icon in ipairs(icons) do
        self:drawIcon(icon, i == self.hovered_icon_index)
    end
    
    -- Draw taskbar, passing tokens needed for the tray
    self:drawTaskbar(self.taskbar_height, self.current_time, tokens)
end

function DesktopView:mousepressed(x, y, button, icons)
    if button ~= 1 then return end
    
    -- Check if clicking taskbar (ignore for MVP)
    if y >= love.graphics.getHeight() - self.taskbar_height then
        return {name = "taskbar_click"}
    end
    
    -- Check desktop icons
    local clicked_icon_index = self:getIconAtPosition(x, y, icons)
    if clicked_icon_index then
        return {name = "icon_click", icon_index = clicked_icon_index}
    end
    
    return nil
end

function DesktopView:getIconAtPosition(x, y, icons)
    for i, icon in ipairs(icons) do
        if x >= icon.x and x <= icon.x + icon.width and
           y >= icon.y and y <= icon.y + icon.height then
            return i
        end
    end
    return nil
end

-- All draw functions are now methods
function DesktopView:drawWallpaper(color)
    love.graphics.setColor(color)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
end

function DesktopView:drawIcon(icon, hovered)
    if hovered then
        love.graphics.setColor(icon.icon_color[1] * 1.2, icon.icon_color[2] * 1.2, icon.icon_color[3] * 1.2)
    else
        love.graphics.setColor(icon.icon_color)
    end
    
    local icon_size = 48
    local icon_x = icon.x + (icon.width - icon_size) / 2
    local icon_y = icon.y + 10
    
    love.graphics.rectangle('fill', icon_x, icon_y, icon_size, icon_size)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', icon_x, icon_y, icon_size, icon_size)
    
    love.graphics.setColor(1, 1, 1)
    local label_y = icon_y + icon_size + 5
    
    local font = love.graphics.getFont()
    local text_width = font:getWidth(icon.name)
    local text_height = font:getHeight()
    
    local max_width = icon.width - 10
    local wrapped_text = icon.name
    if text_width > max_width then
        local words = {}
        for word in icon.name:gmatch("%S+") do table.insert(words, word) end
        
        local lines = {}
        local current_line = ""
        for _, word in ipairs(words) do
            local test_line = current_line == "" and word or (current_line .. " " .. word)
            if font:getWidth(test_line) <= max_width then
                current_line = test_line
            else
                if current_line ~= "" then table.insert(lines, current_line) end
                current_line = word
            end
        end
        if current_line ~= "" then table.insert(lines, current_line) end
        
        for i, line in ipairs(lines) do
            local line_width = font:getWidth(line)
            local line_x = icon.x + (icon.width - line_width) / 2
            local line_y = label_y + (i - 1) * text_height
            
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle('fill', line_x - 2, line_y - 1, line_width + 4, text_height + 2)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(line, line_x, line_y)
        end
    else
        local label_x = icon.x + (icon.width - text_width) / 2
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', label_x - 2, label_y - 1, text_width + 4, text_height + 2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(icon.name, label_x, label_y)
    end
    
    if icon.disabled then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', icon.x, icon.y, icon.width, icon.height)
    end
end

function DesktopView:drawTaskbar(height, time, tokens)
    local y = love.graphics.getHeight() - height
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', 0, y, love.graphics.getWidth(), height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(0, y, love.graphics.getWidth(), y)
    
    self:drawStartButton(10, y + 5, height - 10)
    -- Pass tokens to drawSystemTray
    self:drawSystemTray(love.graphics.getWidth() - 150, y + 5, 140, height - 10, time, tokens)
end

function DesktopView:drawStartButton(x, y, size)
    -- Use UIComponents.drawButton? Maybe too specific. Keep as is for now.
    love.graphics.setColor(0.5, 0.5, 0.5)
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

function DesktopView:drawSystemTray(x, y, w, h, time, tokens)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.line(x, y, x + w, y)
    love.graphics.line(x, y, x, y + h)
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(x + w, y, x + w, y + h)
    love.graphics.line(x, y + h, x + w, y + h)
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(time, x + w - 50, y + 5, 0, 1.2, 1.2)
    
    -- Use UIComponents.drawTokenCounter for the token part
    -- Need to adjust position slightly
    UIComponents.drawTokenCounter(x + 5, y + 3, tokens) 
    -- We might need a smaller version or just draw icon + text here.
    -- Reverting to simple icon+text for consistency for now:
    -- love.graphics.setColor(1, 1, 0)
    -- love.graphics.circle('fill', x + 15, y + h/2, 8)
    -- love.graphics.setColor(0, 0, 0)
    -- love.graphics.print(tokens, x + 25, y + 5, 0, 0.8, 0.8)
end

return DesktopView