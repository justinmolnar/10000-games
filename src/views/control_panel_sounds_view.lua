local BaseView = require('src.views.base_view')
local UI = require('src.views.ui_components')
local Form = require('src.views.ui_dynamic_form')
local Paths = require('src.paths')

local View = BaseView:extend('ControlPanelSoundsView')

function View:init(controller, di)
    View.super.init(self, controller)
    self.controller = controller
    self.di = di
    if di then UI.inject(di) end

    local C = (self.di and self.di.config) or {}
    local V = (C.ui and C.ui.views and C.ui.views.control_panel_sounds) or {}
    local F = (V.form or { label_x = 16, slider_x = 140, value_col_w = 60, start_y = 60 })
    self.form = Form:new({
        schema_path = Paths.data.control_panels .. 'sounds.json',
        on_event = function(ev) if self.controller and self.controller.handle_event then self.controller:handle_event(ev) end end,
        get = function(id)
            local p = self.controller.pending or {}
            local s = self.controller.settings or {}
            local v = p[id]
            if v == nil then v = s[id] end
            return v
        end,
        choices_provider = function(key)
            if key == 'sound_schemes' then
                return self:getSoundSchemeChoices()
            end
            return nil
        end,
        di = di,
        label_x = F.label_x,
        slider_x = F.slider_x,
        value_col_w = F.value_col_w,
        y = F.start_y,
    })
end

function View:getSoundSchemeChoices()
    local ss = self.di and self.di.systemSounds
    if not ss then return {{ label = "Default", value = "default" }} end
    local schemes = ss:getAvailableSchemes()
    local choices = {}
    for _, s in ipairs(schemes) do
        table.insert(choices, { label = s.name, value = s.id })
    end
    if #choices == 0 then
        table.insert(choices, { label = "Default", value = "default" })
    end
    return choices
end

function View:updateLayout(w, h)
    self.w, self.h = w, h
end

function View:update(dt, settings, pending)
end

function View:drawWindowed(w, h, settings, pending)
    self.draw_params = { settings = settings, pending = pending }
    View.super.drawWindowed(self, w, h)
end

function View:drawContent(w, h)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle('line', 0, 0, w, h)
    love.graphics.setColor(0, 0, 0)

    -- Tab strip
    love.graphics.setColor(0.9, 0.9, 0.95)
    love.graphics.rectangle('fill', 8, 28, 70, 18)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle('line', 8, 28, 70, 18)
    love.graphics.print("Sounds", 16, 31)

    self.form.right_edge = w - 24
    self.form.viewport_h = h
    self.form:draw()

    local pending = self.draw_params.pending
    self._ok_rect, self._cancel_rect, self._apply_rect = UI.drawDialogButtons(w, h, next(pending) ~= nil)

    -- Dropdown list overlay draws last (on top of buttons)
    self.form:drawOverlay()
end

local function hit(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function View:mousepressed(x, y, button, settings, pending)
    if button ~= 1 then return nil end
    self.form:mousepressed(x, y, button)
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
