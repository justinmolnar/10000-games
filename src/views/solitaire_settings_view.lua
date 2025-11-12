-- src/views/solitaire_settings_view.lua
local BaseView = require('src.views.base_view')
local UI = require('src.views.ui_components')
local Form = require('src.views.ui_dynamic_form')
local Paths = require('src.paths')
local Backs = require('src.utils.solitaire_backs')

local View = BaseView:extend('SolitaireSettingsView')

function View:init(controller, di)
    View.super.init(self, controller)
    self.controller = controller
    self.di = di
    if di then UI.inject(di) end
    -- Use dynamic form with solitaire schema (hidden from control panel)
    local C = (self.di and self.di.config) or {}
    local V = (C.ui and C.ui.views and C.ui.views.control_panel_general) or {}
    local F = (V.form or { label_x = 16, slider_x = 126, value_col_w = 60, start_y = 60 })
    self.form = Form:new({
        schema_path = Paths.data.control_panels .. 'solitaire.json',
        di = di,
        on_event = function(ev) if self.controller and self.controller.handle_event then self.controller:handle_event(ev) end end,
        get = function(id)
            return self.controller:get_value(id)
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

function View:update(dt)
end

-- Implements BaseView's abstract drawContent method
function View:drawContent(w, h)
    -- Background/frame
    love.graphics.setColor(0.9,0.9,0.9)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle('line', 0, 0, w, h)
    love.graphics.setColor(0,0,0)
    love.graphics.print('Solitaire Settings', 12, 32)

    -- Draw form
    self.form.right_edge = w - 24
    self.form:draw()

    -- Card back previewer (right side)
    local preview_w, preview_h = 100, 140
    local px = w - 24 - preview_w
    local py = 60
    love.graphics.setColor(0,0,0)
    love.graphics.print('Card Back:', px - 90, py + preview_h/2 - 8)
    local current = self.controller:get_value('solitaire_card_back') or Backs.getDefaultId()
    -- Frame
    love.graphics.setColor(0.7,0.7,0.7)
    love.graphics.rectangle('line', px-2, py-2, preview_w+4, preview_h+4)
    -- Image
    local ok = false
    if current then ok = Backs.drawBack(current, px, py, preview_w, preview_h) end
    if not ok then
        love.graphics.setColor(0.3,0.5,0.8)
        love.graphics.rectangle('fill', px, py, preview_w, preview_h, 6, 6)
        love.graphics.setColor(1,1,1)
        love.graphics.rectangle('line', px, py, preview_w, preview_h, 6, 6)
    end
    self._preview_rect = { x = px-2, y = py-2, w = preview_w+4, h = preview_h+4 }

    -- Buttons (OK/Cancel/Apply)
    self._ok_rect, self._cancel_rect, self._apply_rect = UI.drawDialogButtons(w, h, self.controller:has_pending())
end

local function hit(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function View:mousepressed(x, y, button)
    if button ~= 1 then return nil end
    -- Forward to form first
    self.form:mousepressed(x, y, button)
    -- Preview click opens picker dialog
    if hit(self._preview_rect, x, y) then
        return { name = 'open_back_picker' }
    end
    -- Buttons
    if hit(self._ok_rect, x, y) then return { name = 'ok' } end
    if hit(self._cancel_rect, x, y) then return { name = 'cancel' } end
    if hit(self._apply_rect, x, y) then return { name = 'apply' } end
    return nil
end

function View:mousereleased(x, y, button)
    if button ~= 1 then return nil end
    self.form:mousereleased(x, y, button)
    return nil
end

function View:mousemoved(x, y, dx, dy)
    self.form:mousemoved(x, y, dx, dy)
end

return View
