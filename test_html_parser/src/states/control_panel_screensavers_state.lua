-- src/states/control_panel_screensavers_state.lua
local Object = require('class')
local SettingsManager = require('src.utils.settings_manager')

local ScreensaverView = require('src.views.control_panel_screensavers_view')

local ControlPanelScreensaversState = Object:extend('ControlPanelScreensaversState')

function ControlPanelScreensaversState:init(window_controller, di)
    self.window_controller = window_controller
    self.di = di
    self.view = ScreensaverView:new(self, di)
    self.viewport = nil
    self.settings = {}
    self.pending = {}
end

function ControlPanelScreensaversState:setViewport(x, y, w, h)
    self.viewport = {x=x, y=y, width=w, height=h}
    if self.view.updateLayout then self.view:updateLayout(w, h) end
end

function ControlPanelScreensaversState:enter()
    self.settings = SettingsManager.getAll()
    self.pending = {}
end

function ControlPanelScreensaversState:update(dt)
    if not self.viewport then return end
    if self.view.update then self.view:update(dt, self.settings, self.pending) end
end

function ControlPanelScreensaversState:draw()
    if not self.viewport then return end
    self.view:drawWindowed(self.viewport.width, self.viewport.height, self.settings, self.pending)
end

function ControlPanelScreensaversState:keypressed(key)
    if key == 'escape' then return { type = 'close_window' } end
    if self.view.keypressed then
        local ev = self.view:keypressed(key, nil, false, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelScreensaversState:mousepressed(x, y, button)
    if not self.viewport then return false end
    if x < 0 or y < 0 or x > self.viewport.width or y > self.viewport.height then return false end
    local ev = self.view:mousepressed(x, y, button, self.settings, self.pending)
    return self:_handleEvent(ev)
end

function ControlPanelScreensaversState:mousemoved(x, y, dx, dy)
    if self.view.mousemoved then
        local ev = self.view:mousemoved(x, y, dx, dy, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelScreensaversState:mousereleased(x, y, button)
    if self.view.mousereleased then
        local ev = self.view:mousereleased(x, y, button, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelScreensaversState:textinput(text)
    if self.view.textinput then
        local ev = self.view:textinput(text, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelScreensaversState:wheelmoved(x, y)
    if self.view.wheelmoved then
        local ev = self.view:wheelmoved(x, y, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelScreensaversState:_handleEvent(ev)
    if not ev then return false end
    if ev.name == 'set_pending' then
        self.pending[ev.id] = ev.value
        return { type = 'content_interaction' }
    elseif ev.name == 'apply' then
        for k,v in pairs(self.pending) do SettingsManager.set(k, v); self.settings[k] = v end
        SettingsManager.save()
        self.pending = {}
        return { type = 'content_interaction' }
    elseif ev.name == 'ok' then
        for k,v in pairs(self.pending) do SettingsManager.set(k, v); self.settings[k] = v end
        SettingsManager.save()
        self.pending = {}
        return { type = 'close_window' }
    elseif ev.name == 'cancel' then
        self.pending = {}
        return { type = 'close_window' }
    end
    return { type = 'content_interaction' }
end

return ControlPanelScreensaversState
