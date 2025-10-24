-- src/states/control_panel_desktop_state.lua
local Object = require('class')
local SettingsManager = require('src.utils.settings_manager')

local DesktopView = require('src.views.control_panel_desktop_view')

local ControlPanelDesktopState = Object:extend('ControlPanelDesktopState')

function ControlPanelDesktopState:init(window_controller, di)
    self.window_controller = window_controller
    self.di = di
    self.view = DesktopView:new(self, di)
    self.viewport = nil
    self.settings = {}
    self.pending = {}

    -- Subscribe to wallpaper changes to update preview live
    if di and di.eventBus then
        di.eventBus:subscribe('wallpaper_changed', function(new_wallpaper_id)
            -- Update settings to reflect the change
            self.settings = SettingsManager.getAll()
            -- ADD wallpaper to pending so it gets saved when user clicks OK/Apply
            self.pending['desktop_bg_image'] = new_wallpaper_id
            self.pending['desktop_bg_type'] = 'image'
            print("[ControlPanelDesktop] Added to pending: desktop_bg_image=" .. tostring(new_wallpaper_id))
        end)
    end
end

function ControlPanelDesktopState:setViewport(x, y, w, h)
    self.viewport = {x=x, y=y, width=w, height=h}
    if self.view.updateLayout then self.view:updateLayout(w, h) end
end

function ControlPanelDesktopState:enter()
    -- Refresh settings on enter to ensure we have latest values
    self.settings = SettingsManager.getAll()
    self.pending = {}
end

function ControlPanelDesktopState:update(dt)
    if not self.viewport then return end
    if self.view.update then self.view:update(dt, self.settings, self.pending) end
end

function ControlPanelDesktopState:draw()
    if not self.viewport then return end
    self.view:drawWindowed(self.viewport.width, self.viewport.height, self.settings, self.pending)
end

function ControlPanelDesktopState:keypressed(key)
    if key == 'escape' then return { type = 'close_window' } end
end

function ControlPanelDesktopState:mousepressed(x, y, button)
    if not self.viewport then return false end
    if x < 0 or y < 0 or x > self.viewport.width or y > self.viewport.height then return false end
    local ev = self.view:mousepressed(x, y, button, self.settings, self.pending)
    return self:_handleEvent(ev)
end

function ControlPanelDesktopState:mousemoved(x, y, dx, dy)
    if self.view.mousemoved then
        local ev = self.view:mousemoved(x, y, dx, dy, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelDesktopState:mousereleased(x, y, button)
    if self.view.mousereleased then
        local ev = self.view:mousereleased(x, y, button, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

-- Allow view's Form to push events (set_pending/apply/ok/cancel)
function ControlPanelDesktopState:handle_event(ev)
    return self:_handleEvent(ev)
end

function ControlPanelDesktopState:_handleEvent(ev)
    if not ev then return false end
    if ev.name == 'set_pending' then
        self.pending[ev.id] = ev.value
        return { type = 'content_interaction' }
    elseif ev.name == 'open_wallpaper_picker' then
        return { type = 'event', name = 'launch_program', program_id = 'wallpaper_picker' }
    elseif ev.name == 'apply' then
        -- Use batch mode to avoid multiple rapid saves
        SettingsManager.beginBatch()
        for k,v in pairs(self.pending) do
            SettingsManager.set(k, v)
            self.settings[k] = v
        end
        SettingsManager.endBatch()
        self.pending = {}
        return { type = 'content_interaction' }
    elseif ev.name == 'ok' then
        -- Use batch mode to avoid multiple rapid saves
        SettingsManager.beginBatch()
        for k,v in pairs(self.pending) do
            SettingsManager.set(k, v)
            self.settings[k] = v
        end
        SettingsManager.endBatch()
        self.pending = {}
        return { type = 'close_window' }
    elseif ev.name == 'cancel' then
        self.pending = {}
        return { type = 'close_window' }
    end
    return { type = 'content_interaction' }
end

return ControlPanelDesktopState
