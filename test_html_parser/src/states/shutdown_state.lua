-- src/states/shutdown_state.lua
-- Simple shutdown dialog (modal-like window) with Shut down / Restart / Cancel

local Object = require('class')
local UI = require('src.views.ui_components')
local Strings = require('src.utils.strings')
local ShutdownView = require('src.views.shutdown_view')

local ShutdownState = Object:extend('ShutdownState')

function ShutdownState:init(di)
    self.di = di
    if di then UI.inject(di) end
    self.view = ShutdownView:new(di)
    self.window_id = nil
    self.window_manager = nil
    self.viewport = { x = 0, y = 0, width = 300, height = 180 }
end

function ShutdownState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

function ShutdownState:setViewport(x, y, w, h)
    self.viewport = { x = x, y = y, width = w, height = h }
    if self.view and self.view.updateLayout then
        self.view:updateLayout(w, h)
    end
end

function ShutdownState:enter()
    -- no-op
end

function ShutdownState:update(dt)
    if self.view and self.view.update then self.view:update(dt, self.viewport.width, self.viewport.height) end
end

function ShutdownState:draw()
    self.view:drawWindowed(self.viewport.width, self.viewport.height)
end

function ShutdownState:mousepressed(x, y, button)
    local ev = self.view:mousepressed(x, y, button, self.viewport.width, self.viewport.height)
    if not ev then return { type = 'content_interaction' } end
    if ev.name == 'shutdown_now' then
        return { type = 'event', name = 'shutdown_now' }
    elseif ev.name == 'restart_now' then
        return { type = 'event', name = 'restart_now' }
    elseif ev.name == 'cancel' then
        return { type = 'close_window' }
    end
    return { type = 'content_interaction' }
end

function ShutdownState:keypressed(key)
    if key == 'escape' then
        return { type = 'close_window' }
    end
end

return ShutdownState