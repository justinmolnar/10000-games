-- src/views/control_panel_view.lua
local Object = require('class')
local SettingsManager = require('src.utils.settings_manager')

local ControlPanelView = Object:extend('ControlPanelView')

function ControlPanelView:init(controller)
    self.controller = controller
    self.item_height = 28
    self.scroll_offset = 0
    self.hovered_control = nil
    self.dragging_slider = nil
end

function ControlPanelView:update(dt, viewport_width, viewport_height)
    local mx, my = love.mouse.getPosition()
    local view_x = self.controller.viewport and self.controller.viewport.x or 0
    local view_y = self.controller.viewport and self.controller.viewport.y or 0
    self.local_mx = mx - view_x
    self.local_my = my - view_y
end

-- General applet: just a placeholder for now
local function draw_general(self, viewport_width, viewport_height)
    local s = SettingsManager.getAll()
    local y = 10
    love.graphics.setColor(0,0,0)
    love.graphics.print("General", 0, y)
    y = y + 26

    -- Master Volume slider
    love.graphics.setColor(0,0,0)
    love.graphics.print("Master Volume", 0, y)
    y = y + 16
    local sl1_x, sl1_y, sl1_w, sl1_h = 0, y, 280, 14
    local v = s.master_volume or 0
    love.graphics.setColor(0.85,0.85,0.85); love.graphics.rectangle('fill', sl1_x, sl1_y, sl1_w, sl1_h)
    love.graphics.setColor(0.1,0.7,0.1); love.graphics.rectangle('fill', sl1_x, sl1_y, sl1_w * v, sl1_h)
    love.graphics.setColor(0.9,0.9,0.9); love.graphics.rectangle('fill', sl1_x + sl1_w * v - 6, sl1_y - 2, 12, sl1_h + 4)
    love.graphics.setColor(0,0,0); love.graphics.print(string.format("%d%%", math.floor(v * 100 + 0.5)), sl1_x + sl1_w + 12, sl1_y - 2)
    y = y + 36

    -- Fullscreen toggle
    local cb_x, cb_y, cb_w, cb_h = 0, y, 20, 20
    love.graphics.setColor(1,1,1); love.graphics.rectangle('fill', cb_x, cb_y, cb_w, cb_h)
    love.graphics.setColor(0,0,0); love.graphics.rectangle('line', cb_x, cb_y, cb_w, cb_h)
    if s.fullscreen then
        love.graphics.setColor(0, 0.7, 0)
        love.graphics.setLineWidth(3)
        love.graphics.line(cb_x + 3, cb_y + cb_h/2, cb_x + cb_w/2, cb_y + cb_h - 4, cb_x + cb_w - 3, cb_y + 3)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setColor(0,0,0); love.graphics.print("Fullscreen", cb_x + cb_w + 10, cb_y - 2)
end

-- Screensavers applet: shows enable toggle and timeout slider
local function draw_screensavers(self, viewport_width, viewport_height)
    local s = SettingsManager.getAll()
    local y = 20
    love.graphics.setColor(0,0,0)
    love.graphics.print("Screensaver", 10, y)
    y = y + 30

    -- Enable checkbox
    local cb_x, cb_y, cb_w, cb_h = 20, y, 22, 22
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle('fill', cb_x, cb_y, cb_w, cb_h)
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle('line', cb_x, cb_y, cb_w, cb_h)
    if s.screensaver_enabled then
        love.graphics.setColor(0, 0.7, 0)
        love.graphics.setLineWidth(3)
        love.graphics.line(cb_x + 4, cb_y + cb_h/2, cb_x + cb_w/2, cb_y + cb_h - 5, cb_x + cb_w - 4, cb_y + 5)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setColor(0,0,0)
    love.graphics.print("Enable screensaver", cb_x + cb_w + 10, cb_y + 2)

    -- Timeout slider
    y = y + 50
    love.graphics.setColor(0,0,0)
    love.graphics.print("Timeout (seconds)", 20, y)
    y = y + 20
    local sl_x, sl_y, sl_w, sl_h = 20, y, 300, 14
    local seconds = s.screensaver_timeout or 10
    local t = (seconds - 5) / (600 - 5)
    t = math.max(0, math.min(1, t))

    love.graphics.setColor(0.85,0.85,0.85)
    love.graphics.rectangle('fill', sl_x, sl_y, sl_w, sl_h)
    love.graphics.setColor(0.1,0.7,0.1)
    love.graphics.rectangle('fill', sl_x, sl_y, sl_w * t, sl_h)
    love.graphics.setColor(0.9,0.9,0.9)
    love.graphics.rectangle('fill', sl_x + sl_w * t - 6, sl_y - 2, 12, sl_h + 4)

    love.graphics.setColor(0,0,0)
    love.graphics.print(string.format("%ds", seconds), sl_x + sl_w + 12, sl_y - 2)

    -- Note: type chooser could be added later
end

function ControlPanelView:draw(applet, viewport_width, viewport_height)
    -- white background
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)

    if applet == 'control_panel_general' then
        draw_general(self, viewport_width, viewport_height)
    elseif applet == 'control_panel_screensavers' then
        draw_screensavers(self, viewport_width, viewport_height)
    else
        love.graphics.setColor(0,0,0)
        love.graphics.print("Unknown applet", 10, 10)
    end
end

function ControlPanelView:mousepressed(x, y, button, applet, viewport_width, viewport_height)
    if button ~= 1 then return nil end

    if applet == 'control_panel_screensavers' then
        -- Checkbox bounds
        local cb_x, cb_y, cb_w, cb_h = 20, 50, 22, 22
        if x >= cb_x and x <= cb_x + cb_w and y >= cb_y and y <= cb_y + cb_h then
            local new_value = not SettingsManager.get('screensaver_enabled')
            return { name = 'set_setting', id = 'screensaver_enabled', value = new_value }
        end
        -- Slider bounds
        local sl_x, sl_y, sl_w, sl_h = 20, 100, 300, 14
        if x >= sl_x and x <= sl_x + sl_w and y >= sl_y and y <= sl_y + sl_h then
            local t = math.max(0, math.min(1, (x - sl_x) / sl_w))
            local seconds = math.floor(5 + t * (600 - 5) + 0.5)
            self.dragging_slider = 'screensaver_timeout'
            return { name = 'set_setting', id = 'screensaver_timeout', value = seconds }
        end
    elseif applet == 'control_panel_general' then
        -- Master volume slider
        local sl1_x, sl1_y, sl1_w, sl1_h = 0, 26 + 16, 280, 14
        if x >= sl1_x and x <= sl1_x + sl1_w and y >= sl1_y and y <= sl1_y + sl1_h then
            local t = math.max(0, math.min(1, (x - sl1_x) / sl1_w))
            self.dragging_slider = 'master_volume'
            return { name = 'set_setting', id = 'master_volume', value = t }
        end
        -- Fullscreen checkbox
        local cb_x, cb_y, cb_w, cb_h = 0, 26 + 16 + 14 + 36, 20, 20
        if x >= cb_x and x <= cb_x + cb_w and y >= cb_y and y <= cb_y + cb_h then
            local new_value = not SettingsManager.get('fullscreen')
            return { name = 'set_setting', id = 'fullscreen', value = new_value }
        end
    end
    return nil
end

function ControlPanelView:mousereleased(x, y, button)
    if button == 1 then self.dragging_slider = nil end
end

function ControlPanelView:mousemoved(x, y, dx, dy, applet)
    if not self.dragging_slider then return nil end
    if applet == 'control_panel_screensavers' and self.dragging_slider == 'screensaver_timeout' then
        local sl_x, sl_w = 20, 300
        local t = math.max(0, math.min(1, (x - sl_x) / sl_w))
        local seconds = math.floor(5 + t * (600 - 5) + 0.5)
        return { name = 'set_setting', id = 'screensaver_timeout', value = seconds }
    elseif applet == 'control_panel_general' and self.dragging_slider == 'master_volume' then
        local sl1_x, sl1_w = 0, 280
        local t = math.max(0, math.min(1, (x - sl1_x) / sl1_w))
        return { name = 'set_setting', id = 'master_volume', value = t }
    end
    return nil
end

return ControlPanelView
