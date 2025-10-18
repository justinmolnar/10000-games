-- src/states/settings_state.lua
local Object = require('class')
local SettingsView = require('src.views.settings_view')
local SettingsManager = require('src.utils.settings_manager')

local SettingsState = Object:extend('SettingsState')

function SettingsState:init(window_controller)
    self.window_controller = window_controller
    self.view = SettingsView:new(self)
    self.current_settings = {}
    self.viewport = nil
end

function SettingsState:setViewport(x, y, width, height)
    self.viewport = {x = x, y = y, width = width, height = height}
end

function SettingsState:enter()
    print("Entered Settings Menu")
    self.current_settings = SettingsManager.getAll()
end

function SettingsState:update(dt)
    if not self.viewport then return end
    self.view:update(dt, self.current_settings)
end

function SettingsState:draw()
    if not self.viewport then return end
    
    love.graphics.push()
    love.graphics.translate(self.viewport.x, self.viewport.y)
    love.graphics.setScissor(self.viewport.x, self.viewport.y, self.viewport.width, self.viewport.height)
    
    self:drawWindowed()
    
    love.graphics.setScissor()
    love.graphics.pop()
end

function SettingsState:drawWindowed()
    -- Background
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', 0, 0, self.viewport.width, self.viewport.height)
    
    -- Title
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Settings", 10, 10, 0, 1.2, 1.2)
    
    -- Draw settings options
    local y_pos = 50
    local line_height = 40
    
    for _, opt in ipairs(self.view.options) do
        if opt.type ~= "button" then
            love.graphics.setColor(0, 0, 0)
            love.graphics.print(opt.label, 10, y_pos)
            
            if opt.type == "slider" then
                local value = self.current_settings[opt.id] or 0
                local slider_x = 200
                local slider_w = 200
                
                -- Slider background
                love.graphics.setColor(0.3, 0.3, 0.3)
                love.graphics.rectangle('fill', slider_x, y_pos + 5, slider_w, 10)
                
                -- Slider fill
                love.graphics.setColor(0, 0.8, 0)
                love.graphics.rectangle('fill', slider_x, y_pos + 5, slider_w * value, 10)
                
                -- Slider handle
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.rectangle('fill', slider_x + slider_w * value - 5, y_pos, 10, 20)
                
                -- Value label
                love.graphics.setColor(0, 0, 0)
                love.graphics.print(string.format("%d%%", math.floor(value * 100 + 0.5)), 
                                  slider_x + slider_w + 15, y_pos + 2)
            elseif opt.type == "toggle" then
                local is_checked = false
                if opt.id == "tutorial_shown" then
                    is_checked = self.current_settings[opt.id] == false
                elseif opt.id == "fullscreen" then
                    is_checked = self.current_settings[opt.id] == true
                end
                
                -- Checkbox
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.rectangle('line', 200, y_pos, 20, 20)
                
                if is_checked then
                    love.graphics.setColor(0, 1, 0)
                    love.graphics.setLineWidth(3)
                    love.graphics.line(205, y_pos + 10, 210, y_pos + 15, 215, y_pos + 5)
                    love.graphics.setLineWidth(1)
                end
            end
            
            y_pos = y_pos + line_height
        end
    end
    
    -- Back button
    love.graphics.setColor(0, 0.5, 0)
    love.graphics.rectangle('fill', 10, self.viewport.height - 50, 150, 35)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Close", 50, self.viewport.height - 43)
end

function SettingsState:keypressed(key)
    if key == 'escape' then
        return { type = "close_window" }
    end
    return false
end

function SettingsState:mousepressed(x, y, button)
    if not self.viewport then return false end
    
    -- x, y are already local coordinates from DesktopState
    if x < 0 or x > self.viewport.width or y < 0 or y > self.viewport.height then
        return false
    end
    
    -- Check back button
    if x >= 10 and x <= 160 and 
       y >= self.viewport.height - 50 and y <= self.viewport.height - 15 then
        return {type = "close_window"}
    end
    
    -- Check sliders and toggles
    local y_pos = 50
    local line_height = 40
    
    for _, opt in ipairs(self.view.options) do
        if opt.type == "slider" then
            local slider_x = 200
            local slider_w = 200
            
            if x >= slider_x and x <= slider_x + slider_w and
               y >= y_pos and y <= y_pos + 20 then
                local value = math.max(0, math.min(1, (x - slider_x) / slider_w))
                return {type = "set_setting", id = opt.id, value = value}
            end
        elseif opt.type == "toggle" then
            if x >= 200 and x <= 220 and
               y >= y_pos and y <= y_pos + 20 then
                local current_value = self:getSetting(opt.id)
                return {type = "set_setting", id = opt.id, value = not current_value}
            end
        end
        
        if opt.type ~= "button" then
            y_pos = y_pos + line_height
        end
    end
    
    return false
end

function SettingsState:mousereleased(x, y, button)
    -- Forward to view to handle stopping slider drag
    if self.view.mousereleased then
        self.view:mousereleased(x, y, button)
    end
end

function SettingsState:setSetting(key, value)
    SettingsManager.set(key, value)
    self.current_settings = SettingsManager.getAll()
end

function SettingsState:getSetting(key)
    return SettingsManager.get(key)
end

return SettingsState