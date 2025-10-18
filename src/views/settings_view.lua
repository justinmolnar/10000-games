-- src/views/settings_view.lua
local Object = require('class')
local UIComponents = require('src/views.ui_components')
local SettingsView = Object:extend('SettingsView')

function SettingsView:init(controller)
    self.controller = controller

    self.title = "Settings"
    self.options = {
        { id = "master_volume", label = "Master Volume", type = "slider", x = 50, y = 100, w = 300, h = 20 },
        { id = "music_volume", label = "Music Volume (Not Implemented)", type = "slider", x = 50, y = 150, w = 300, h = 20 },
        { id = "sfx_volume", label = "SFX Volume (Not Implemented)", type = "slider", x = 50, y = 200, w = 300, h = 20 },
        { id = "tutorial_shown", label = "Show Tutorial on Next Launch", type = "toggle", x = 50, y = 250, w = 30, h = 30 },
        { id = "fullscreen", label = "Fullscreen", type = "toggle", x = 50, y = 300, w = 30, h = 30 },
        { id = "back", label = "Back to Desktop", type = "button", x = 50, y = 400, w = 200, h = 40 }
    }
    self.dragging_slider = nil
    self.hovered_button_id = nil
end

function SettingsView:update(dt, current_settings)
    local mx, my = love.mouse.getPosition()
    self.hovered_button_id = nil

    if self.dragging_slider then
        local slider = nil
        for _, opt in ipairs(self.options) do
            if opt.id == self.dragging_slider then slider = opt; break end
        end
        if slider then
            local value = math.max(0, math.min(1, (mx - slider.x) / slider.w))
            self.controller:setSetting(self.dragging_slider, value)
        end
    else
         for _, opt in ipairs(self.options) do
             if opt.type == "button" then
                 if mx >= opt.x and mx <= opt.x + opt.w and my >= opt.y and my <= opt.y + opt.h then
                     self.hovered_button_id = opt.id
                     break
                 end
             end
         end
    end
end

function SettingsView:draw(current_settings)
    UIComponents.drawWindow(0, 0, love.graphics.getWidth(), love.graphics.getHeight(), self.title)

    for _, opt in ipairs(self.options) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(opt.label, opt.x, opt.y - 20)

        if opt.type == "slider" then
            local value = current_settings[opt.id] or 0
            love.graphics.setColor(0.3, 0.3, 0.3); love.graphics.rectangle('fill', opt.x, opt.y, opt.w, opt.h)
            love.graphics.setColor(0, 0.8, 0); love.graphics.rectangle('fill', opt.x, opt.y, opt.w * value, opt.h)
            love.graphics.setColor(0.8, 0.8, 0.8); love.graphics.rectangle('fill', opt.x + opt.w * value - 5, opt.y - 2, 10, opt.h + 4)
            love.graphics.setColor(1, 1, 1); love.graphics.print(string.format("%d%%", math.floor(value * 100 + 0.5)), opt.x + opt.w + 15, opt.y + 2)
            if opt.id == "music_volume" or opt.id == "sfx_volume" then
                love.graphics.setColor(0.7, 0.7, 0.7); love.graphics.print("(Global setting only for MVP)", opt.x + 150, opt.y - 20, 0, 0.8, 0.8)
            end
        elseif opt.type == "toggle" then
             -- Draw checkbox
             love.graphics.setColor(0.8, 0.8, 0.8)
             love.graphics.rectangle('line', opt.x, opt.y, opt.w, opt.h)
             
             -- Determine checked state based on the setting
             local is_checked = false
             if opt.id == "tutorial_shown" then
                 -- Tutorial: Checked means 'show next time' (tutorial_shown = false)
                 is_checked = current_settings[opt.id] == false
             elseif opt.id == "fullscreen" then
                 -- Fullscreen: Checked means fullscreen is on
                 is_checked = current_settings[opt.id] == true
             end
             
             -- Draw checkmark if checked
             if is_checked then
                 love.graphics.setColor(0, 1, 0)
                 love.graphics.setLineWidth(3)
                 love.graphics.line(opt.x + 5, opt.y + opt.h/2, opt.x + opt.w/2, opt.y + opt.h - 5, opt.x + opt.w - 5, opt.y + 5)
                 love.graphics.setLineWidth(1)
             end
        elseif opt.type == "button" then
            local is_hovered = (opt.id == self.hovered_button_id)
            UIComponents.drawButton(opt.x, opt.y, opt.w, opt.h, opt.label, true, is_hovered)
        end
    end
end

function SettingsView:mousepressed(x, y, button)
    if button ~= 1 then return nil end

    for _, opt in ipairs(self.options) do
        if opt.type == "slider" then
            if x >= opt.x and x <= opt.x + opt.w and y >= opt.y and y <= opt.y + opt.h then
                self.dragging_slider = opt.id
                local value = math.max(0, math.min(1, (x - opt.x) / opt.w))
                return { name = "set_setting", id = opt.id, value = value }
            end
        elseif opt.type == "toggle" then
             if x >= opt.x and x <= opt.x + opt.w and y >= opt.y and y <= opt.y + opt.h then
                 local current_value = self.controller:getSetting(opt.id)
                 
                 -- Handle different toggle logic
                 if opt.id == "tutorial_shown" then
                     -- Tutorial: toggle means opposite of what's shown
                     return { name = "set_setting", id = opt.id, value = not current_value }
                 elseif opt.id == "fullscreen" then
                     -- Fullscreen: toggle normally
                     return { name = "set_setting", id = opt.id, value = not current_value }
                 end
             end
        elseif opt.type == "button" then
            if x >= opt.x and x <= opt.x + opt.w and y >= opt.y and y <= opt.y + opt.h then
                return { name = "button_click", id = opt.id }
            end
        end
    end
    return nil
end

function SettingsView:mousereleased(x, y, button)
    if button == 1 then
        self.dragging_slider = nil
    end
end

return SettingsView