-- src/states/message_box_state.lua
-- Generic Win98 message box dialog (modal-like window)

local Object = require('class')
local UI = require('src.views.ui_components')
local MessageBoxView = require('src.views.message_box_view')

local MessageBoxState = Object:extend('MessageBoxState')

function MessageBoxState:init(di)
    self.di = di
    if di then UI.inject(di) end
    self.view = MessageBoxView:new(di)
    self.window_id = nil
    self.window_manager = nil
    self.viewport = { x = 0, y = 0, width = 360, height = 180 }
    self.params = nil
end

function MessageBoxState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

function MessageBoxState:setViewport(x, y, w, h)
    self.viewport = { x = x, y = y, width = w, height = h }
    if self.view and self.view.updateLayout then
        self.view:updateLayout(w, h)
    end
end

function MessageBoxState:enter(params)
    params = params or {}
    self.params = params
    self.view:configure(params)
    self.timeout = params.timeout or nil
    self.timeout_remaining = self.timeout

    -- Update the window title bar
    if self.window_manager and self.window_id and params.title then
        self.window_manager:updateWindowTitle(self.window_id, params.title)
    end
end

function MessageBoxState:update(dt)
    if self.timeout_remaining then
        self.timeout_remaining = self.timeout_remaining - dt
        -- Update countdown in view
        if self.view then
            self.view.countdown = math.ceil(self.timeout_remaining)
        end
        if self.timeout_remaining <= 0 then
            self.timeout_remaining = nil
            -- Timeout: trigger last button (cancel convention)
            local labels = self.view.button_labels or {}
            if self.params and self.params.on_button and #labels > 0 then
                self.params.on_button(#labels, labels[#labels])
            end
            -- Close window via window manager
            if self.window_manager and self.window_id then
                self.window_manager:closeWindow(self.window_id)
            end
        end
    end
end

function MessageBoxState:draw()
    self.view:drawWindowed(self.viewport.width, self.viewport.height)
end

function MessageBoxState:mousemoved(x, y, dx, dy)
    if self.view and self.view.mousemoved then
        self.view:mousemoved(x, y, self.viewport.width, self.viewport.height)
    end
    return { type = 'content_interaction' }
end

function MessageBoxState:mousepressed(x, y, button)
    local ev = self.view:mousepressed(x, y, button, self.viewport.width, self.viewport.height)
    if not ev then return { type = 'content_interaction' } end

    if ev.name == 'button_clicked' then
        if self.params and self.params.on_button then
            self.params.on_button(ev.index, ev.label)
        end
        return { type = 'close_window' }
    end
    return { type = 'content_interaction' }
end

function MessageBoxState:keypressed(key)
    if key == 'return' or key == 'kpenter' then
        -- Enter triggers first button
        if self.params and self.params.on_button and #self.view.button_labels > 0 then
            self.params.on_button(1, self.view.button_labels[1])
        end
        return { type = 'close_window' }
    end
    if key == 'escape' then
        -- Escape triggers last button (cancel convention)
        local labels = self.view.button_labels
        if self.params and self.params.on_button and #labels > 0 then
            self.params.on_button(#labels, labels[#labels])
        end
        return { type = 'close_window' }
    end
end

return MessageBoxState
