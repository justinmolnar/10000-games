-- src/states/settings_state_windowed.lua
-- Windowed version of settings state (proof of concept)

local Object = require('class')
local SettingsView = require('src.views.settings_view')
local SettingsManager = require('src.utils.settings_manager')

local SettingsStateWindowed = Object:extend('SettingsStateWindowed')

function SettingsStateWindowed:init(window_controller)
    self.window_controller = window_controller
    self.view = SettingsView:new(self)
    self.current_settings = {}
    
    -- Viewport bounds (set by window system)
    self.viewport = {x = 0, y = 0, width = 800, height = 600}
end

-- Set viewport for rendering within window
function SettingsStateWindowed:setViewport(x, y, width, height)
    self.viewport.x = x
    self.viewport.y = y
    self.viewport.width = width
    self.viewport.height = height
end

function SettingsStateWindowed:enter()
    self.current_settings = SettingsManager.getAll()
end

function SettingsStateWindowed:update(dt)
    self.view:update(dt, self.current_settings)
end

function SettingsStateWindowed:draw()
    -- Set scissor to clip rendering to window bounds
    love.graphics.setScissor(self.viewport.x, self.viewport.y, 
                            self.viewport.width, self.viewport.height)
    
    -- Translate drawing to window position
    love.graphics.push()
    love.graphics.translate(self.viewport.x, self.viewport.y)
    
    -- Draw with adjusted coordinates
    self:drawWindowed()
    
    love.graphics.pop()
    love.graphics.setScissor()
end

function SettingsStateWindowed:drawWindowed()
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
    love.graphics.print("Back to Desktop", 20, self.viewport.height - 43)
end

function SettingsStateWindowed:keypressed(key)
    -- No ESC handling - window close button handles this
    return false
end

function SettingsStateWindowed:mousepressed(x, y, button)
    -- Translate coordinates to viewport space
    local local_x = x - self.viewport.x
    local local_y = y - self.viewport.y
    
    -- Check if click is within viewport
    if local_x < 0 or local_x > self.viewport.width then return false end
    if local_y < 0 or local_y > self.viewport.height then return false end
    
    -- Check back button
    if local_x >= 10 and local_x <= 160 and 
       local_y >= self.viewport.height - 50 and local_y <= self.viewport.height - 15 then
        return {type = "close_window"}
    end
    
    -- Check sliders and toggles
    local y_pos = 50
    local line_height = 40
    
    for _, opt in ipairs(self.view.options) do
        if opt.type == "slider" then
            local slider_x = 200
            local slider_w = 200
            
            if local_x >= slider_x and local_x <= slider_x + slider_w and
               local_y >= y_pos and local_y <= y_pos + 20 then
                local value = math.max(0, math.min(1, (local_x - slider_x) / slider_w))
                return {type = "set_setting", id = opt.id, value = value}
            end
        elseif opt.type == "toggle" then
            if local_x >= 200 and local_x <= 220 and
               local_y >= y_pos and local_y <= y_pos + 20 then
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

function SettingsStateWindowed:setSetting(key, value)
    SettingsManager.set(key, value)
    self.current_settings = SettingsManager.getAll()
end

function SettingsStateWindowed:getSetting(key)
    return SettingsManager.get(key)
end

return SettingsStateWindowed