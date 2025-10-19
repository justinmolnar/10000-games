-- src/views/control_panel_general_view.lua
local Object = require('class')
local UI = require('src.views.ui_components')
local Form = require('src.views.ui_dynamic_form')
local Strings = require('src.utils.strings')
local Paths = require('src.paths')
local Config = require('src.config')

local View = Object:extend('ControlPanelGeneralView')

function View:init(controller)
    self.controller = controller
    self.dragging = nil
    -- set up dynamic form
    local V = (Config.ui and Config.ui.views and Config.ui.views.control_panel_general) or {}
    local F = (V.form or { label_x = 16, slider_x = 126, value_col_w = 60, start_y = 60 })
    self.form = Form:new({
        schema_path = Paths.data.control_panels .. 'general.json',
        on_event = function(ev) if self.controller and self.controller.handle_event then self.controller:handle_event(ev) end end,
        get = function(id)
            local p = self.controller.pending or {}
            local s = self.controller.settings or {}
            local v = p[id]
            if v == nil then v = s[id] end
            return v
        end,
        label_x = F.label_x,
        slider_x = F.slider_x,
        value_col_w = F.value_col_w,
        y = F.start_y,
    })
end

function View:updateLayout(w, h)
    self.w, self.h = w, h
end

function View:update(dt, settings, pending)
    -- nothing recurrent here
end

local function drawButton(x,y,w,h,text,enabled,hovered)
    UI.drawButton(x,y,w,h,text,enabled ~= false, hovered or false)
end

function View:drawWindowed(w, h, settings, pending)
    -- Background/frame
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle('line', 0, 0, w, h)
    love.graphics.setColor(0,0,0)

    -- Tab strip
    love.graphics.setColor(0.9,0.9,0.95)
    love.graphics.rectangle('fill', 8, 28, 90, 18)
    love.graphics.setColor(0.2,0.2,0.2)
    love.graphics.rectangle('line', 8, 28, 90, 18)
    love.graphics.print(Strings.get('control_panel.tabs.general', 'General'), 16, 31)

    -- Dynamic form area
    self.form.right_edge = w - 24
    self.form:draw()

    -- Buttons (deduped)
    self._ok_rect, self._cancel_rect, self._apply_rect = UI.drawDialogButtons(w, h, next(pending) ~= nil)
end

local function hit(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function View:mousepressed(x, y, button, settings, pending)
    if button ~= 1 then return nil end
    -- Delegate to form
    self.form:mousepressed(x, y, button)
    -- Buttons
    if hit(self._ok_rect, x, y) then return { name='ok' } end
    if hit(self._cancel_rect, x, y) then return { name='cancel' } end
    if hit(self._apply_rect, x, y) then return { name='apply' } end
    return nil
end

function View:mousemoved(x, y, dx, dy, settings, pending)
    local ev = self.form:mousemoved(x, y, dx, dy)
    return ev
end

function View:mousereleased(x, y, button, settings, pending)
    if button == 1 then self.dragging = nil end
    self.form:mousereleased(x, y, button)
end

return View
