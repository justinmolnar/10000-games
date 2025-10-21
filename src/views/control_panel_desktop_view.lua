-- src/views/control_panel_desktop_view.lua
local Object = require('class')
local UI = require('src.views.ui_components')
local Form = require('src.views.ui_dynamic_form')
local Strings = require('src.utils.strings')
local Paths = require('src.paths')
local Wallpapers = require('src.utils.wallpapers')

local View = Object:extend('ControlPanelDesktopView')

function View:init(controller, di)
    self.controller = controller
    self.di = di
    if di then UI.inject(di) end
    -- set up dynamic form
    local C = (self.di and self.di.config) or {}
    local V = (C.ui and C.ui.views and C.ui.views.control_panel_general) or {}
    local F = (V.form or { label_x = 16, slider_x = 126, value_col_w = 60, start_y = 60 })
    self.form = Form:new({
        schema_path = Paths.data.control_panels .. 'desktop.json',
        on_event = function(ev) if self.controller and self.controller.handle_event then self.controller:handle_event(ev) end end,
        get = function(id)
            local p = self.controller.pending or {}
            local s = self.controller.settings or {}
            local v = p[id]
            if v == nil then v = s[id] end
            return v
        end,
        di = di,
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

function View:drawWindowed(w, h, settings, pending)
    -- Background/frame
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle('line', 0, 0, w, h)
    love.graphics.setColor(0,0,0)

    -- Tab strip
    love.graphics.setColor(0.9,0.9,0.95)
    love.graphics.rectangle('fill', 8, 28, 120, 18)
    love.graphics.setColor(0.2,0.2,0.2)
    love.graphics.rectangle('line', 8, 28, 120, 18)
    love.graphics.print(Strings.get('control_panel.tabs.desktop', 'Desktop'), 16, 31)

    -- Layout: reserve a right column for preview and keep the form left of it
    local right_margin = 24
    local col_gap = 20
    local preview_w, preview_h = 260, 160
    local form_right = w - right_margin - preview_w - col_gap
    if form_right < (self.form.slider_x + 200) then form_right = self.form.slider_x + 200 end
    -- Dynamic form area (constrained)
    self.form.right_edge = form_right
    self.form:draw()

    -- Live preview area on the right
    local px = form_right + col_gap
    local py = 60
    love.graphics.setColor(0,0,0)
    love.graphics.print('Preview:', px, py - 18)
    -- Frame
    love.graphics.setColor(0.7,0.7,0.7)
    love.graphics.rectangle('line', px-2, py-2, preview_w+4, preview_h+4)
    -- Determine type and values (pending overrides settings)
    local function getVal(key, fallback)
        local p = pending or {}
        if p[key] ~= nil then return p[key] end
        local s = settings or {}
        if s[key] ~= nil then return s[key] end
        return fallback
    end
    local bg_type = getVal('desktop_bg_type', 'color')
    if bg_type == 'image' then
        local cur_id = getVal('desktop_bg_image', Wallpapers.getDefaultId())
        local mode = getVal('desktop_bg_scale_mode', 'fill')
        local ok = false
        -- Clear preview area to desktop color
        local br = getVal('desktop_bg_r', 0)
        local bgc = getVal('desktop_bg_g', 0.5)
        local bb = getVal('desktop_bg_b', 0.5)
        love.graphics.setColor(br, bgc, bb)
        love.graphics.rectangle('fill', px, py, preview_w, preview_h)
        -- Draw selected mode directly within the preview rect
        if mode == 'fill' then ok = cur_id and Wallpapers.drawCover(cur_id, px, py, preview_w, preview_h)
        elseif mode == 'fit' then ok = cur_id and Wallpapers.drawFit(cur_id, px, py, preview_w, preview_h)
        elseif mode == 'stretch' then ok = cur_id and Wallpapers.drawStretch(cur_id, px, py, preview_w, preview_h)
        elseif mode == 'center' then ok = cur_id and Wallpapers.drawCenter(cur_id, px, py, preview_w, preview_h)
        elseif mode == 'tile' then ok = cur_id and Wallpapers.drawTile(cur_id, px, py, preview_w, preview_h)
        end
        if not ok then
            love.graphics.setColor(0.9,0.9,0.95)
            love.graphics.rectangle('fill', px, py, preview_w, preview_h)
            love.graphics.setColor(0.2,0.2,0.2)
            love.graphics.print('No wallpapers found', px + 10, py + preview_h/2 - 6)
        end
        -- Choose button
        local bw, bh = 140, 24
        self._choose_rect = { x = px + preview_w - bw, y = py + preview_h + 8, w = bw, h = bh }
        UI.drawButton(self._choose_rect.x, self._choose_rect.y, bw, bh, 'Choose Image...', true, false)
    else
        local r = getVal('desktop_bg_r', 0)
        local g = getVal('desktop_bg_g', 0.5)
        local b = getVal('desktop_bg_b', 0.5)
        love.graphics.setColor(r, g, b)
        love.graphics.rectangle('fill', px, py, preview_w, preview_h)
        self._choose_rect = nil
    end

    -- Buttons
    self._ok_rect, self._cancel_rect, self._apply_rect = UI.drawDialogButtons(w, h, next(pending) ~= nil)
end

local function hit(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function View:mousepressed(x, y, button, settings, pending)
    if button ~= 1 then return nil end
    -- Delegate to form
    self.form:mousepressed(x, y, button)
    -- Choose image when in image mode
    if self._choose_rect and hit(self._choose_rect, x, y) then
        return { name = 'open_wallpaper_picker' }
    end
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
