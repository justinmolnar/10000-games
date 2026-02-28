local Object = require('class')
local SettingsManager = require('src.utils.settings_manager')
local SoundsView = require('src.views.control_panel_sounds_view')

local ControlPanelSoundsState = Object:extend('ControlPanelSoundsState')

function ControlPanelSoundsState:init(window_controller, di)
    self.window_controller = window_controller
    self.di = di
    self.view = SoundsView:new(self, di)
    self.viewport = nil
    self.settings = {}
    self.pending = {}
end

function ControlPanelSoundsState:setViewport(x, y, w, h)
    self.viewport = {x=x, y=y, width=w, height=h}
    if self.view.updateLayout then self.view:updateLayout(w, h) end
end

function ControlPanelSoundsState:enter()
    self.settings = SettingsManager.getAll()
    self.pending = {}
end

function ControlPanelSoundsState:update(dt)
    if not self.viewport then return end
    if self.view.update then self.view:update(dt, self.settings, self.pending) end
end

function ControlPanelSoundsState:draw()
    if not self.viewport then return end
    self.view:drawWindowed(self.viewport.width, self.viewport.height, self.settings, self.pending)
end

function ControlPanelSoundsState:keypressed(key)
    if key == 'escape' then return { type = 'close_window' } end
end

function ControlPanelSoundsState:mousepressed(x, y, button)
    if not self.viewport then return false end
    if x < 0 or y < 0 or x > self.viewport.width or y > self.viewport.height then return false end
    local ev = self.view:mousepressed(x, y, button, self.settings, self.pending)
    return self:_handleEvent(ev)
end

function ControlPanelSoundsState:mousemoved(x, y, dx, dy)
    if self.view.mousemoved then
        local ev = self.view:mousemoved(x, y, dx, dy, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelSoundsState:mousereleased(x, y, button)
    if self.view.mousereleased then
        local ev = self.view:mousereleased(x, y, button, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelSoundsState:handle_event(ev)
    return self:_handleEvent(ev)
end

function ControlPanelSoundsState:_handleEvent(ev)
    if not ev then return false end
    if ev.name == 'set_pending' then
        self.pending[ev.id] = ev.value
        -- Live-apply sound scheme changes so you hear the new theme immediately
        if ev.id == 'sound_scheme' and self.di.systemSounds then
            self.di.systemSounds:setScheme(ev.value)
        end
        return { type = 'content_interaction' }
    elseif ev.name == 'apply' then
        SettingsManager.beginBatch()
        for k,v in pairs(self.pending) do SettingsManager.set(k, v); self.settings[k] = v end
        SettingsManager.endBatch()
        self.pending = {}
        return { type = 'content_interaction' }
    elseif ev.name == 'ok' then
        SettingsManager.beginBatch()
        for k,v in pairs(self.pending) do SettingsManager.set(k, v); self.settings[k] = v end
        SettingsManager.endBatch()
        self.pending = {}
        return { type = 'close_window' }
    elseif ev.name == 'cancel' then
        -- Revert live preview if scheme was changed
        if self.di.systemSounds then
            local saved = SettingsManager.get('sound_scheme') or 'default'
            self.di.systemSounds:setScheme(saved)
        end
        self.pending = {}
        return { type = 'close_window' }
    end
    return { type = 'content_interaction' }
end

return ControlPanelSoundsState
