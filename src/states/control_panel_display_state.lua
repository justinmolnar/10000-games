local Object = require('class')
local SettingsManager = require('src.utils.settings_manager')
local DisplayView = require('src.views.control_panel_display_view')
local MessageBox = require('src.utils.message_box')

local ControlPanelDisplayState = Object:extend('ControlPanelDisplayState')

function ControlPanelDisplayState:init(window_controller, di)
    self.window_controller = window_controller
    self.di = di
    self.view = DisplayView:new(self, di)
    self.viewport = nil
    self.settings = {}
    self.pending = {}
    self.pre_change_snapshot = nil -- saved before applying display change
end

function ControlPanelDisplayState:setViewport(x, y, w, h)
    self.viewport = {x=x, y=y, width=w, height=h}
    if self.view.updateLayout then self.view:updateLayout(w, h) end
end

function ControlPanelDisplayState:enter()
    self.settings = SettingsManager.getAll()
    self.pending = {}
end

function ControlPanelDisplayState:update(dt)
    if not self.viewport then return end
    if self.view.update then self.view:update(dt, self.settings, self.pending) end
end

function ControlPanelDisplayState:draw()
    if not self.viewport then return end
    self.view:drawWindowed(self.viewport.width, self.viewport.height, self.settings, self.pending)
end

function ControlPanelDisplayState:keypressed(key)
    if key == 'escape' then return { type = 'close_window' } end
end

function ControlPanelDisplayState:mousepressed(x, y, button)
    if not self.viewport then return false end
    if x < 0 or y < 0 or x > self.viewport.width or y > self.viewport.height then return false end
    local ev = self.view:mousepressed(x, y, button, self.settings, self.pending)
    return self:_handleEvent(ev)
end

function ControlPanelDisplayState:mousemoved(x, y, dx, dy)
    if self.view.mousemoved then
        local ev = self.view:mousemoved(x, y, dx, dy, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelDisplayState:mousereleased(x, y, button)
    if self.view.mousereleased then
        local ev = self.view:mousereleased(x, y, button, self.settings, self.pending)
        return self:_handleEvent(ev)
    end
end

function ControlPanelDisplayState:handle_event(ev)
    return self:_handleEvent(ev)
end

function ControlPanelDisplayState:_handleEvent(ev)
    if not ev then return false end
    if ev.name == 'set_pending' then
        self.pending[ev.id] = ev.value
        -- When monitor changes, reset resolution to avoid invalid combos
        if ev.id == 'display_monitor' then
            self.pending['display_resolution'] = nil
        end
        return { type = 'content_interaction' }
    elseif ev.name == 'apply' or ev.name == 'ok' then
        -- Snapshot current state before applying (for revert)
        local desktop_icons = self.di and self.di.desktopIcons
        local icon_positions_backup = {}
        if desktop_icons then
            for pid, pos in pairs(desktop_icons.positions) do
                icon_positions_backup[pid] = {x = pos.x, y = pos.y}
            end
        end
        self.pre_change_snapshot = {
            display_monitor = SettingsManager.get('display_monitor'),
            display_resolution = SettingsManager.get('display_resolution'),
            display_mode = SettingsManager.get('display_mode'),
            icon_positions = icon_positions_backup,
        }

        -- Apply the new settings
        SettingsManager.beginBatch()
        for k,v in pairs(self.pending) do
            SettingsManager.set(k, v)
            self.settings[k] = v
        end
        SettingsManager.endBatch()
        local close_after = (ev.name == 'ok')
        self.pending = {}
        SettingsManager.applyDisplay()

        -- Show keep/revert confirmation with 15s timeout
        local snapshot = self.pre_change_snapshot
        local this = self
        MessageBox.show({
            title = "Display Settings",
            message = "Do you want to keep these display settings?",
            icon_type = "warning",
            buttons = {"Keep Changes", "Revert"},
            timeout = 15,
            on_button = function(index, label)
                if index == 2 then
                    this:_revertDisplay(snapshot)
                end
                this.pre_change_snapshot = nil
            end,
        })

        return { type = 'content_interaction' }
    elseif ev.name == 'cancel' then
        self.pending = {}
        return { type = 'close_window' }
    end
    return { type = 'content_interaction' }
end

function ControlPanelDisplayState:_revertDisplay(snapshot)
    if not snapshot then return end

    -- Restore display settings
    SettingsManager.beginBatch()
    SettingsManager.set('display_monitor', snapshot.display_monitor)
    SettingsManager.set('display_resolution', snapshot.display_resolution)
    SettingsManager.set('display_mode', snapshot.display_mode)
    SettingsManager.endBatch()

    -- Restore icon positions
    local desktop_icons = self.di and self.di.desktopIcons
    if desktop_icons and snapshot.icon_positions then
        desktop_icons.positions = {}
        for pid, pos in pairs(snapshot.icon_positions) do
            desktop_icons.positions[pid] = {x = pos.x, y = pos.y}
        end
        desktop_icons:save()
    end

    -- Re-apply the old display mode
    SettingsManager.applyDisplay()

    -- Refresh local settings copy
    self.settings = SettingsManager.getAll()
    self.pending = {}
end

return ControlPanelDisplayState
