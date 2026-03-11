local BaseView = require('src.views.base_view')
local UI = require('src.views.ui_components')
local Form = require('src.views.ui_dynamic_form')
local ThemeManager = require('src.utils.theme_manager')
local Paths = require('src.paths')

local View = BaseView:extend('ControlPanelThemesView')

function View:init(controller, di)
    View.super.init(self, controller)
    self.controller = controller
    self.di = di
    if di then UI.inject(di) end

    self.form = Form:new({
        schema_path = Paths.data.control_panels .. 'themes.json',
        on_event = function(ev) if self.controller and self.controller.handle_event then self.controller:handle_event(ev) end end,
        get = function(id)
            local p = self.controller.pending or {}
            local s = self.controller.settings or {}
            local v = p[id]
            if v == nil then v = s[id] end
            return v
        end,
        choices_provider = function(key)
            if key == 'available_themes' then
                return self:getThemeChoices()
            end
            return nil
        end,
        di = di,
        label_x = 16,
        slider_x = 140,
        value_col_w = 60,
        y = 60,
    })
end

function View:getThemeChoices()
    local themes = ThemeManager.getAvailableThemes()
    local choices = {}
    for _, t in ipairs(themes) do
        table.insert(choices, { label = t.name, value = t.id })
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

    -- Tab strip
    love.graphics.setColor(0.9, 0.9, 0.95)
    love.graphics.rectangle('fill', 8, 28, 70, 18)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle('line', 8, 28, 70, 18)
    love.graphics.print("Themes", 16, 31)

    self.form.right_edge = w - 24
    self.form.viewport_h = h
    self.form:draw()

    -- Color preview
    self:drawPreview(w)

    local pending = self.draw_params.pending
    self._ok_rect, self._cancel_rect, self._apply_rect = UI.drawDialogButtons(w, h, next(pending) ~= nil)

    -- Dropdown list overlay draws last (on top of buttons)
    self.form:drawOverlay()
end

function View:drawPreview(w)
    local px = 16
    local py = 110
    local pw = w - 32
    local ph = 120
    local theme = ThemeManager.getActiveTheme()
    if not theme or not theme.colors then return end
    local c = theme.colors

    -- Preview frame
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.rectangle('line', px - 1, py - 1, pw + 2, ph + 2)

    -- Desktop wallpaper
    love.graphics.setColor(c.desktop and c.desktop.wallpaper or {0, 0.5, 0.5})
    love.graphics.rectangle('fill', px, py, pw, ph)

    -- Mini window
    local wx, wy, ww, wh = px + 20, py + 10, pw - 40, ph - 40
    local win = c.window or {}
    love.graphics.setColor(win.border_outer or {1, 1, 1})
    love.graphics.rectangle('line', wx, wy, ww, wh)
    love.graphics.setColor(win.content_bg or {0.9, 0.9, 0.9})
    love.graphics.rectangle('fill', wx + 1, wy + 13, ww - 2, wh - 14)
    love.graphics.setColor(win.titlebar_focused or {0, 0, 0.5})
    love.graphics.rectangle('fill', wx + 1, wy + 1, ww - 2, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Window", wx + 3, wy + 1, 0, 0.7, 0.7)

    -- Mini taskbar
    local ty = py + ph - 14
    local tb = c.taskbar or {}
    love.graphics.setColor(tb.bg or {0.75, 0.75, 0.75})
    love.graphics.rectangle('fill', px, ty, pw, 14)
    love.graphics.setColor(tb.top_line or {1, 1, 1})
    love.graphics.line(px, ty, px + pw, ty)

    -- Button swatches
    local btn = c.button or {}
    local sx = px + 4
    local sy = py + ph + 4
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Buttons:", sx, sy, 0, 0.8, 0.8)
    sx = sx + 55
    local swatch_w = 40
    local roles = {"confirm", "cancel", "neutral"}
    for _, role in ipairs(roles) do
        local rc = btn[role] or {}
        love.graphics.setColor(rc.bg or {0.5, 0.5, 0.5})
        love.graphics.rectangle('fill', sx, sy, swatch_w, 12)
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle('line', sx, sy, swatch_w, 12)
        love.graphics.setColor(rc.text or {1, 1, 1})
        love.graphics.print(role, sx + 2, sy + 1, 0, 0.65, 0.65)
        sx = sx + swatch_w + 6
    end
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
