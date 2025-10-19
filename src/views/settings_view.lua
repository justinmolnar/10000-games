-- src/views/settings_view.lua
local Object = require('class')
local UIComponents = require('src/views.ui_components')
local Config = require('src.config')
local SettingsView = Object:extend('SettingsView')

function SettingsView:init(controller)
    self.controller = controller

    self.title = "Settings"
    local V = (Config.ui and Config.ui.views and Config.ui.views.settings) or {}
    local base_x = V.base_x or 50
    local sx, sh = (V.slider and V.slider.w) or 300, (V.slider and V.slider.h) or 20
    local tx, ty = (V.toggle and V.toggle.w) or 30, (V.toggle and V.toggle.h) or 30
    local rg = V.row_gap or 50
    local sg = V.section_gap or 60
    self.options = {
        { id = "master_volume", label = "Master Volume", type = "slider", x = base_x, y = (V.title_y or 40) + rg*1 + 10, w = sx, h = sh },
        { id = "music_volume", label = "Music Volume (Not Implemented)", type = "slider", x = base_x, y = (V.title_y or 40) + rg*2 + 10, w = sx, h = sh },
        { id = "sfx_volume", label = "SFX Volume (Not Implemented)", type = "slider", x = base_x, y = (V.title_y or 40) + rg*3 + 10, w = sx, h = sh },
        { id = "tutorial_shown", label = "Show Tutorial on Next Launch", type = "toggle", x = base_x, y = (V.title_y or 40) + rg*4 + 10, w = tx, h = ty },
        { id = "fullscreen", label = "Fullscreen", type = "toggle", x = base_x, y = (V.title_y or 40) + rg*5 + 10, w = tx, h = ty },
        -- Screensaver section
        { id = "_sep_ss", label = "Screensaver", type = "label", x = base_x, y = (V.title_y or 40) + rg*6 + (sg - rg) },
        { id = "screensaver_enabled", label = "Enable Screensaver", type = "toggle", x = base_x, y = (V.title_y or 40) + rg*7 + (sg - rg), w = tx, h = ty },
        { id = "screensaver_timeout", label = "Timeout (seconds)", type = "slider_int", x = base_x, y = (V.title_y or 40) + rg*8 + (sg - rg), w = sx, h = sh },
        { id = "back", label = "Back to Desktop", type = "button", x = base_x, y = (V.title_y or 40) + rg*9 + (sg - rg), w = 200, h = 40 }
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
            if slider.type == 'slider_int' then
                -- Map 0..1 to a reasonable timeout range (5..600s)
                local R = (Config.ui and Config.ui.views and Config.ui.views.settings and Config.ui.views.settings.int_slider) or { min_seconds = 5, max_seconds = 600 }
                local t = math.max(0, math.min(1, (mx - slider.x) / slider.w))
                local seconds = math.floor((R.min_seconds or 5) + t * ((R.max_seconds or 600) - (R.min_seconds or 5)) + 0.5)
                self.controller:setSetting(self.dragging_slider, seconds)
            else
                local value = math.max(0, math.min(1, (mx - slider.x) / slider.w))
                self.controller:setSetting(self.dragging_slider, value)
            end
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

        if opt.type == "label" then
            -- Section heading already drawn
        elseif opt.type == "slider" then
            local value = current_settings[opt.id] or 0
            love.graphics.setColor(0.3, 0.3, 0.3); love.graphics.rectangle('fill', opt.x, opt.y, opt.w, opt.h)
            love.graphics.setColor(0, 0.8, 0); love.graphics.rectangle('fill', opt.x, opt.y, opt.w * value, opt.h)
            love.graphics.setColor(0.8, 0.8, 0.8); love.graphics.rectangle('fill', opt.x + opt.w * value - 5, opt.y - 2, 10, opt.h + 4)
            love.graphics.setColor(1, 1, 1); love.graphics.print(string.format("%d%%", math.floor(value * 100 + 0.5)), opt.x + opt.w + 15, opt.y + 2)
            if opt.id == "music_volume" or opt.id == "sfx_volume" then
                love.graphics.setColor(0.7, 0.7, 0.7); love.graphics.print("(Global setting only for MVP)", opt.x + 150, opt.y - 20, 0, 0.8, 0.8)
            end
        elseif opt.type == "slider_int" then
            local R = (Config.ui and Config.ui.views and Config.ui.views.settings and Config.ui.views.settings.int_slider) or { min_seconds = 5, max_seconds = 600 }
            local seconds = current_settings[opt.id] or 10
            local t = (seconds - (R.min_seconds or 5)) / ((R.max_seconds or 600) - (R.min_seconds or 5))
            t = math.max(0, math.min(1, t))
            love.graphics.setColor(0.3, 0.3, 0.3); love.graphics.rectangle('fill', opt.x, opt.y, opt.w, opt.h)
            love.graphics.setColor(0, 0.8, 0); love.graphics.rectangle('fill', opt.x, opt.y, opt.w * t, opt.h)
            love.graphics.setColor(0.8, 0.8, 0.8); love.graphics.rectangle('fill', opt.x + opt.w * t - 5, opt.y - 2, 10, opt.h + 4)
            love.graphics.setColor(1, 1, 1); love.graphics.print(string.format("%ds", seconds), opt.x + opt.w + 15, opt.y + 2)
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
    -- x, y are LOCAL coords relative to content area (0,0)
    if button ~= 1 then return nil end

    -- Check UI elements using local x, y
    for _, opt in ipairs(self.options) do
        -- Use RELATIVE positions defined in init/updateLayout
        local opt_x = opt.x -- Already relative
        local opt_y = opt.y -- Already relative
        local opt_w = opt.w
        local opt_h = opt.h

        if opt.type == "slider" or opt.type == "slider_int" then
            -- Check using LOCAL x, y against relative opt_x, opt_y
            if x >= opt_x and x <= opt_x + opt_w and y >= opt_y and y <= opt_y + opt_h then
                self.dragging_slider = opt.id
                if opt.type == 'slider_int' then
                    local R = (Config.ui and Config.ui.views and Config.ui.views.settings and Config.ui.views.settings.int_slider) or { min_seconds = 5, max_seconds = 600 }
                    local t = math.max(0, math.min(1, (x - opt_x) / opt_w))
                    local seconds = math.floor((R.min_seconds or 5) + t * ((R.max_seconds or 600) - (R.min_seconds or 5)) + 0.5)
                    return { name = "set_setting", id = opt.id, value = seconds }
                else
                    local value = math.max(0, math.min(1, (x - opt_x) / opt_w))
                    return { name = "set_setting", id = opt.id, value = value }
                end
            end
        elseif opt.type == "toggle" then
             -- Check using LOCAL x, y against relative opt_x, opt_y
             if x >= opt_x and x <= opt_x + opt_w and y >= opt_y and y <= opt_y + opt_h then
                 local current_value = self.controller:getSetting(opt.id)
                 local new_value = not current_value -- Basic toggle
                 -- Specific logic for tutorial_shown inversion handled by state/manager
                 return { name = "set_setting", id = opt.id, value = new_value }
             end
        elseif opt.type == "button" then
             -- Check using LOCAL x, y against relative opt_x, opt_y
             if x >= opt_x and x <= opt_x + opt_w and y >= opt_y and y <= opt_y + opt_h then
                return { name = "button_click", id = opt.id }
            end
        end
    end
    return nil -- Clicked empty space within the view
end

function SettingsView:mousereleased(x, y, button)
    if button == 1 then
        self.dragging_slider = nil
    end
end

return SettingsView