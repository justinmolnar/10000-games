local Object = require('class')
local SettingsManager = require('src.utils.settings_manager')
local ThemeManager = require('src.utils.theme_manager')
local ThemesView = require('src.views.control_panel_themes_view')

local ControlPanelThemesState = Object:extend('ControlPanelThemesState')

function ControlPanelThemesState:init(window_controller, di)
    self.window_controller = window_controller
    self.di = di
    self.view = ThemesView:new(self, di)
    self.viewport = nil
    self.settings = {}
    self.pending = {}
    self._original_theme = nil
end

function ControlPanelThemesState:setViewport(x, y, w, h)
    self.viewport = {x=x, y=y, width=w, height=h}
    if self.view.updateLayout then self.view:updateLayout(w, h) end
end

function ControlPanelThemesState:enter()
    self.settings = SettingsManager.getAll()
    self.pending = {}
    self._original_theme = ThemeManager.getActiveThemeName()
end

function ControlPanelThemesState:update(dt)
    if not self.viewport then return end
    if self.view.update then self.view:update(dt, self.settings, self.pending) end
end

function ControlPanelThemesState:draw()
    if not self.viewport then return end
    self.view:drawWindowed(self.viewport.width, self.viewport.height, self.settings, self.pending)
end

function ControlPanelThemesState:keypressed(key)
    if key == 'escape' then return { type = 'close_window' } end
end

function ControlPanelThemesState:mousepressed(x, y, button)
    if not self.viewport then return false end
    if x < 0 or y < 0 or x > self.viewport.width or y > self.viewport.height then return false end
    local ev = self.view:mousepressed(x, y, button, self.settings, self.pending)
    return self:_handleEvent(ev)
end

function ControlPanelThemesState:mousemoved(x, y, dx, dy)
    if self.view.mousemoved then
        local ev = self.view:mousemoved(x, y, dx, dy, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelThemesState:mousereleased(x, y, button)
    if self.view.mousereleased then
        local ev = self.view:mousereleased(x, y, button, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelThemesState:handle_event(ev)
    return self:_handleEvent(ev)
end

function ControlPanelThemesState:_handleEvent(ev)
    if not ev then return false end
    if ev.name == 'set_pending' then
        self.pending[ev.id] = ev.value
        -- Live-preview theme changes
        if ev.id == 'theme' then
            ThemeManager.setTheme(ev.value)
        end
        return { type = 'content_interaction' }
    elseif ev.name == 'apply' then
        SettingsManager.beginBatch()
        for k,v in pairs(self.pending) do SettingsManager.set(k, v); self.settings[k] = v end
        SettingsManager.endBatch()
        self._original_theme = ThemeManager.getActiveThemeName()
        self.pending = {}
        return { type = 'content_interaction' }
    elseif ev.name == 'ok' then
        SettingsManager.beginBatch()
        for k,v in pairs(self.pending) do SettingsManager.set(k, v); self.settings[k] = v end
        SettingsManager.endBatch()
        self._original_theme = ThemeManager.getActiveThemeName()
        self.pending = {}
        return { type = 'close_window' }
    elseif ev.name == 'cancel' then
        -- Revert live preview
        if self._original_theme then
            ThemeManager.setTheme(self._original_theme)
        end
        self.pending = {}
        return { type = 'close_window' }
    end
    return { type = 'content_interaction' }
end

return ControlPanelThemesState
