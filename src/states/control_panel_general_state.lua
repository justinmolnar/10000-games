-- src/states/control_panel_general_state.lua
local Object = require('class')
local SettingsManager = require('src.utils.settings_manager')

local GeneralView = require('src.views.control_panel_general_view')

local ControlPanelGeneralState = Object:extend('ControlPanelGeneralState')

function ControlPanelGeneralState:init(window_controller, di)
    self.window_controller = window_controller
    self.di = di
    self.view = GeneralView:new(self, di)
    self.viewport = nil
    self.settings = {}
    self.pending = {}
end

function ControlPanelGeneralState:setViewport(x, y, w, h)
    self.viewport = {x=x, y=y, width=w, height=h}
    if self.view.updateLayout then self.view:updateLayout(w, h) end
end

function ControlPanelGeneralState:enter()
    self.settings = SettingsManager.getAll()
    self.pending = {}
end

function ControlPanelGeneralState:update(dt)
    if not self.viewport then return end
    if self.view.update then self.view:update(dt, self.settings, self.pending) end
end

function ControlPanelGeneralState:draw()
    if not self.viewport then return end
    self.view:drawWindowed(self.viewport.width, self.viewport.height, self.settings, self.pending)
end

function ControlPanelGeneralState:keypressed(key)
    if key == 'escape' then return { type = 'close_window' } end
end

function ControlPanelGeneralState:mousepressed(x, y, button)
    if not self.viewport then return false end
    if x < 0 or y < 0 or x > self.viewport.width or y > self.viewport.height then return false end
    local ev = self.view:mousepressed(x, y, button, self.settings, self.pending)
    return self:_handleEvent(ev)
end

function ControlPanelGeneralState:mousemoved(x, y, dx, dy)
    if self.view.mousemoved then
        local ev = self.view:mousemoved(x, y, dx, dy, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelGeneralState:mousereleased(x, y, button)
    if self.view.mousereleased then
        local ev = self.view:mousereleased(x, y, button, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

-- Allow view's Form to push events (set_pending/apply/ok/cancel)
function ControlPanelGeneralState:handle_event(ev)
    return self:_handleEvent(ev)
end

function ControlPanelGeneralState:_handleEvent(ev)
    if not ev then return false end
    if ev.name == 'set_pending' then
        self.pending[ev.id] = ev.value
        return { type = 'content_interaction' }
    elseif ev.name == 'apply' then
        for k,v in pairs(self.pending) do SettingsManager.set(k, v); self.settings[k] = v end
        self.pending = {}
        return { type = 'content_interaction' }
    elseif ev.name == 'ok' then
        for k,v in pairs(self.pending) do SettingsManager.set(k, v); self.settings[k] = v end
        self.pending = {}
        return { type = 'close_window' }
    elseif ev.name == 'cancel' then
        self.pending = {}
        return { type = 'close_window' }
    end
    return { type = 'content_interaction' }
end

return ControlPanelGeneralState
