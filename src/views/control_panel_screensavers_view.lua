local Object = require('class')
local UI = require('src.views.ui_components')
local json = require('json')
local Strings = require('src.utils.strings')
local Paths = require('src.paths')
-- Config is accessed via self.di.config when available

local View = Object:extend('ControlPanelScreensaversView')

function View:init(controller, di)
    self.controller = controller
    self.di = di
    if di then UI.inject(di) end
    self.dragging = nil
    self.preview = { canvas = nil, saver = nil, last_key = nil }
    self.schema = self:_loadSchema(Paths.data.control_panels .. 'screensavers.json')
    self.layout_cache = {} -- id -> {rect, el}
    self.scroll = { offset = 0, dragging = false, drag_start_y = 0, drag_offset_start = 0, content_h = 0 }
end

function View:updateLayout(w, h)
    self.w, self.h = w, h
end

function View:_loadSchema(path)
    local ok, contents = pcall(love.filesystem.read, path)
    if not ok or not contents then return { elements = {}, preview = nil } end
    local ok2, data = pcall(json.decode, contents)
    if not ok2 or not data then return { elements = {}, preview = nil } end
    return data
end

-- Helpers
local function getVal(pending, settings, key, default)
    local v = pending[key]
    if v == nil then v = settings[key] end
    if v == nil then v = default end
    return v
end

function View:_previewKey(settings, pending)
    local t = getVal(pending, settings, 'screensaver_type', 'starfield')
    if t == 'pipes' then
        local fields = {
            'screensaver_pipes_fov','screensaver_pipes_near','screensaver_pipes_radius',
            'screensaver_pipes_grid_step','screensaver_pipes_max_segments','screensaver_pipes_turn_chance',
            'screensaver_pipes_speed','screensaver_pipes_spawn_min_z','screensaver_pipes_spawn_max_z',
            'screensaver_pipes_avoid_cells','screensaver_pipes_show_grid','screensaver_pipes_camera_drift',
            'screensaver_pipes_camera_roll','screensaver_pipes_pipe_count','screensaver_pipes_show_hud'
        }
        local parts = {t}
        for _,k in ipairs(fields) do table.insert(parts, tostring(getVal(pending, settings, k, 'nil'))) end
        return table.concat(parts, '|')
    elseif t == 'model3d' then
        local fields = {
            'screensaver_model_fov','screensaver_model_grid_lat','screensaver_model_grid_lon',
            'screensaver_model_morph_speed','screensaver_model_two_sided',
            'screensaver_model_shape1','screensaver_model_shape2','screensaver_model_shape3',
            'screensaver_model_scale','screensaver_model_tint_r','screensaver_model_tint_g','screensaver_model_tint_b',
            'screensaver_model_hold_time'
        }
        local parts = {t}
        for _,k in ipairs(fields) do table.insert(parts, tostring(getVal(pending, settings, k, 'nil'))) end
        return table.concat(parts, '|')
    elseif t == 'text3d' then
        local fields = {
            'screensaver_text3d_text','screensaver_text3d_use_time','screensaver_text3d_font_size','screensaver_text3d_extrude_layers','screensaver_text3d_fov','screensaver_text3d_distance',
            'screensaver_text3d_color_mode','screensaver_text3d_use_hsv','screensaver_text3d_color_r','screensaver_text3d_color_g','screensaver_text3d_color_b',
            'screensaver_text3d_color_h','screensaver_text3d_color_s','screensaver_text3d_color_v',
            'screensaver_text3d_spin_x','screensaver_text3d_spin_y','screensaver_text3d_spin_z',
            'screensaver_text3d_move_enabled','screensaver_text3d_move_mode','screensaver_text3d_move_radius','screensaver_text3d_move_speed','screensaver_text3d_bounce_speed_x','screensaver_text3d_bounce_speed_y',
            'screensaver_text3d_pulse_enabled','screensaver_text3d_pulse_amp','screensaver_text3d_pulse_speed','screensaver_text3d_wavy_baseline','screensaver_text3d_specular'
        }
        local parts = {t}
        for _,k in ipairs(fields) do table.insert(parts, tostring(getVal(pending, settings, k, 'nil'))) end
        return table.concat(parts, '|')
    else -- starfield
        local fields = { 'screensaver_starfield_count','screensaver_starfield_speed','screensaver_starfield_fov','screensaver_starfield_tail' }
        local parts = {t}
        for _,k in ipairs(fields) do table.insert(parts, tostring(getVal(pending, settings, k, 'nil'))) end
        return table.concat(parts, '|')
    end
end

function View:destroyPreview()
    if self.preview and self.preview.saver and self.preview.saver.destroy then
        pcall(function() self.preview.saver:destroy() end)
    end
    self.preview.saver = nil
    if self.preview and self.preview.canvas then
        self.preview.canvas:release()
        self.preview.canvas = nil
    end
end

-- View-level helpers to simplify drawWindowed
function View:_getViewConfig()
    local C = (self.di and self.di.config) or {}
    local V = (C.ui and C.ui.views and C.ui.views.control_panel_screensavers) or {}
    local colors = V.colors or {}
    return V, colors
end

function View:_drawBackgroundAndBorder(w, h, colors)
    love.graphics.setColor(colors.panel_bg or {0.9, 0.9, 0.9})
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(colors.panel_border or {0.6, 0.6, 0.6})
    love.graphics.rectangle('line', 0, 0, w, h)
end

function View:_drawTab(tab, colors)
    love.graphics.setColor(colors.tab_bg or {0,0,0})
    love.graphics.rectangle('fill', tab.x, tab.y, tab.w, tab.h)
    love.graphics.setColor(colors.panel_border or {0.2,0.2,0.2})
    love.graphics.rectangle('line', tab.x, tab.y, tab.w, tab.h)
    love.graphics.setColor(colors.text or {0,0,0})
    love.graphics.print(Strings.get('control_panel.tabs.screensaver', 'Screen Saver'), tab.x + 8, tab.y + 3)
end

function View:_drawPreviewFrame(frame_x, frame_y, prev_w, prev_h, frame_pad, colors)
    love.graphics.setColor(colors.frame_fill or {0.9,0.9,0.95})
    love.graphics.rectangle('fill', frame_x - frame_pad, frame_y - frame_pad, prev_w + 2*frame_pad, prev_h + 2*frame_pad)
    love.graphics.setColor(colors.frame_line or {0.2,0.2,0.2})
    love.graphics.rectangle('line', frame_x - frame_pad, frame_y - frame_pad, prev_w + 2*frame_pad, prev_h + 2*frame_pad)
end

function View:_drawDropdownList(dropdown_to_draw)
    UI.drawDropdownList(
        dropdown_to_draw.x,
        dropdown_to_draw.y,
        dropdown_to_draw.w,
        dropdown_to_draw.item_h,
        dropdown_to_draw.labels,
        nil
    )
    self._dropdown_list = {
        id = dropdown_to_draw.id,
        x = dropdown_to_draw.x,
        y = dropdown_to_draw.y,
        w = dropdown_to_draw.w,
        h = #dropdown_to_draw.labels * dropdown_to_draw.item_h,
        item_h = dropdown_to_draw.item_h,
        items = dropdown_to_draw.items
    }
end

-- Simple slider renderer: t in [0,1]
function View:drawSlider(x, y, w, h, t)
    t = math.max(0, math.min(1, t or 0))
    love.graphics.setColor(0.85,0.85,0.85)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0.1,0.7,0.1)
    love.graphics.rectangle('fill', x, y, w * t, h)
    love.graphics.setColor(0.9,0.9,0.9)
    local handle_x = x + w * t - 6
    if handle_x < x then handle_x = x end
    if handle_x > x + w - 12 then handle_x = x + w - 12 end
    love.graphics.rectangle('fill', handle_x, y - 2, 12, h + 4)
    love.graphics.setColor(0,0,0)
end

local function drawButton(x,y,w,h,text,enabled,hovered)
    UI.drawButton(x,y,w,h,text,enabled ~= false, hovered or false)
end

function View:_ensurePreview(prev_w, prev_h, settings, pending)
    local key = self:_previewKey(settings, pending)
    local needNewSaver = (self.preview.last_key ~= key) or (self.preview.saver == nil)
    if needNewSaver then
        -- destroy old
        if self.preview.saver and self.preview.saver.destroy then pcall(function() self.preview.saver:destroy() end) end
        self.preview.saver = nil
        self.preview.last_key = key
        -- Build saver by type
        local t = getVal(pending, settings, 'screensaver_type', 'starfield')
    if t == 'pipes' then
            local C = (self.di and self.di.config) or {}
            local d = (C and C.screensavers and C.screensavers.defaults and C.screensavers.defaults.pipes) or {}
            local PipesView = require('src.views.screensaver_pipes_view')
            self.preview.saver = PipesView:new({
                fov = getVal(pending, settings, 'screensaver_pipes_fov', d.fov),
                near = getVal(pending, settings, 'screensaver_pipes_near', d.near),
                radius = getVal(pending, settings, 'screensaver_pipes_radius', d.radius),
                grid_step = getVal(pending, settings, 'screensaver_pipes_grid_step', d.grid_step),
                max_segments = getVal(pending, settings, 'screensaver_pipes_max_segments', d.max_segments),
                turn_chance = getVal(pending, settings, 'screensaver_pipes_turn_chance', d.turn_chance),
                speed = getVal(pending, settings, 'screensaver_pipes_speed', d.speed),
                spawn_min_z = getVal(pending, settings, 'screensaver_pipes_spawn_min_z', d.spawn_min_z),
                spawn_max_z = getVal(pending, settings, 'screensaver_pipes_spawn_max_z', d.spawn_max_z),
                avoid_cells = getVal(pending, settings, 'screensaver_pipes_avoid_cells', d.avoid_cells),
                show_grid = getVal(pending, settings, 'screensaver_pipes_show_grid', d.show_grid),
                camera_drift = getVal(pending, settings, 'screensaver_pipes_camera_drift', d.camera_drift),
                camera_roll = getVal(pending, settings, 'screensaver_pipes_camera_roll', d.camera_roll),
                pipe_count = getVal(pending, settings, 'screensaver_pipes_pipe_count', d.pipe_count),
                show_hud = getVal(pending, settings, 'screensaver_pipes_show_hud', d.show_hud),
            })
        elseif t == 'model3d' then
            local C = (self.di and self.di.config) or {}
            local d = (C and C.screensavers and C.screensavers.defaults and C.screensavers.defaults.model3d) or {}
            local ModelView = require('src.views.screensaver_model_view')
            -- build shapes array from up to three dropdowns, ignoring 'none'
            local s1 = getVal(pending, settings, 'screensaver_model_shape1', nil)
            local s2 = getVal(pending, settings, 'screensaver_model_shape2', nil)
            local s3 = getVal(pending, settings, 'screensaver_model_shape3', nil)
            local shapes = {}
            local function addShape(v)
                if v and v ~= '' and v ~= 'none' then table.insert(shapes, v) end
            end
            addShape(s1); addShape(s2); addShape(s3)
            if #shapes == 0 then shapes = d.shapes or {'cube','sphere'} end
            self.preview.saver = ModelView:new({
                fov = getVal(pending, settings, 'screensaver_model_fov', d.fov),
                grid_lat = getVal(pending, settings, 'screensaver_model_grid_lat', d.grid_lat),
                grid_lon = getVal(pending, settings, 'screensaver_model_grid_lon', d.grid_lon),
                morph_speed = getVal(pending, settings, 'screensaver_model_morph_speed', d.morph_speed),
                two_sided = getVal(pending, settings, 'screensaver_model_two_sided', d.two_sided),
                shapes = shapes,
                hold_time = getVal(pending, settings, 'screensaver_model_hold_time', d.hold_time),
                scale = getVal(pending, settings, 'screensaver_model_scale', d.scale or 1.0),
                tint = {
                    getVal(pending, settings, 'screensaver_model_tint_r', (d.tint and d.tint[1]) or 1.0),
                    getVal(pending, settings, 'screensaver_model_tint_g', (d.tint and d.tint[2]) or 1.0),
                    getVal(pending, settings, 'screensaver_model_tint_b', (d.tint and d.tint[3]) or 1.0),
                },
            })
        elseif t == 'text3d' then
            local C = (self.di and self.di.config) or {}
            local d = (C and C.screensavers and C.screensavers.defaults and C.screensavers.defaults.text3d) or {}
            local Text3DView = require('src.views.screensaver_text3d_view')
            self.preview.saver = Text3DView:new({
                fov = getVal(pending, settings, 'screensaver_text3d_fov', d and d.fov),
                distance = getVal(pending, settings, 'screensaver_text3d_distance', d and d.distance or 10),
                color = {
                    getVal(pending, settings, 'screensaver_text3d_color_r', d and d.color_r or 1.0),
                    getVal(pending, settings, 'screensaver_text3d_color_g', d and d.color_g or 1.0),
                    getVal(pending, settings, 'screensaver_text3d_color_b', d and d.color_b or 1.0),
                },
                color_mode = getVal(pending, settings, 'screensaver_text3d_color_mode', d and d.color_mode or 'solid'),
                use_hsv = getVal(pending, settings, 'screensaver_text3d_use_hsv', d and d.use_hsv or false),
                color_h = getVal(pending, settings, 'screensaver_text3d_color_h', d and d.color_h or 0.15),
                color_s = getVal(pending, settings, 'screensaver_text3d_color_s', d and d.color_s or 1.0),
                color_v = getVal(pending, settings, 'screensaver_text3d_color_v', d and d.color_v or 1.0),
                font_size = getVal(pending, settings, 'screensaver_text3d_font_size', d and d.font_size or 96),
                extrude_layers = getVal(pending, settings, 'screensaver_text3d_extrude_layers', d and d.extrude_layers or 12),
                spin_x = getVal(pending, settings, 'screensaver_text3d_spin_x', d and d.spin_x or 0.0),
                spin_y = getVal(pending, settings, 'screensaver_text3d_spin_y', d and d.spin_y or 0.8),
                spin_z = getVal(pending, settings, 'screensaver_text3d_spin_z', d and d.spin_z or 0.1),
                move_enabled = getVal(pending, settings, 'screensaver_text3d_move_enabled', d and d.move_enabled ~= false),
                move_mode = getVal(pending, settings, 'screensaver_text3d_move_mode', d and d.move_mode or 'orbit'),
                move_speed = getVal(pending, settings, 'screensaver_text3d_move_speed', d and d.move_speed or 0.25),
                move_radius = getVal(pending, settings, 'screensaver_text3d_move_radius', d and d.move_radius or 120),
                bounce_speed_x = getVal(pending, settings, 'screensaver_text3d_bounce_speed_x', d and d.bounce_speed_x or 100),
                bounce_speed_y = getVal(pending, settings, 'screensaver_text3d_bounce_speed_y', d and d.bounce_speed_y or 80),
                pulse_enabled = getVal(pending, settings, 'screensaver_text3d_pulse_enabled', d and d.pulse_enabled or false),
                pulse_amp = getVal(pending, settings, 'screensaver_text3d_pulse_amp', d and d.pulse_amp or 0.25),
                pulse_speed = getVal(pending, settings, 'screensaver_text3d_pulse_speed', d and d.pulse_speed or 0.8),
                wavy_baseline = getVal(pending, settings, 'screensaver_text3d_wavy_baseline', d and d.wavy_baseline or false),
                specular = getVal(pending, settings, 'screensaver_text3d_specular', d and d.specular or 0.0),
                use_time = getVal(pending, settings, 'screensaver_text3d_use_time', d and d.use_time or false),
                text = getVal(pending, settings, 'screensaver_text3d_text', d and d.text or 'good?'),
            })
        else
            local C = (self.di and self.di.config) or {}
            local d = (C and C.screensavers and C.screensavers.defaults and C.screensavers.defaults.starfield) or {}
            local StarView = require('src.views.screensaver_view')
            self.preview.saver = StarView:new({
                count = getVal(pending, settings, 'screensaver_starfield_count', d.count),
                speed = getVal(pending, settings, 'screensaver_starfield_speed', d.speed),
                fov = getVal(pending, settings, 'screensaver_starfield_fov', d.fov),
                tail = getVal(pending, settings, 'screensaver_starfield_tail', d.tail),
            })
        end
    end
    -- Ensure canvas exists and size matches
    local needCanvas = (not self.preview.canvas) or (self.preview.canvas:getWidth() ~= prev_w) or (self.preview.canvas:getHeight() ~= prev_h)
    if needCanvas then
        if self.preview.canvas then self.preview.canvas:release() end
        self.preview.canvas = love.graphics.newCanvas(prev_w, prev_h)
    end
end

function View:drawPreview(x, y, w, h)
    self:_ensurePreview(w, h, self.controller.settings, self.controller.pending)
    if not self.preview.canvas or not self.preview.saver then return end
    -- Draw into canvas
    local old_canvas = love.graphics.getCanvas()
    local old_scissor = { love.graphics.getScissor() }
    love.graphics.setCanvas(self.preview.canvas)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.clear(0,0,0,1)
    pcall(function()
        self.preview.saver:setViewport(0, 0, w, h)
        self.preview.saver:update(0.016)
        self.preview.saver:draw()
    end)
    love.graphics.pop()
    love.graphics.setCanvas(old_canvas)
    if old_scissor[1] then love.graphics.setScissor(old_scissor[1], old_scissor[2], old_scissor[3], old_scissor[4]) else love.graphics.setScissor() end
    -- Blit to screen
    love.graphics.setColor(1,1,1)
    love.graphics.draw(self.preview.canvas, x, y)
    love.graphics.setColor(0,0,0)
end

-- Main draw
function View:drawWindowed(w, h, settings, pending)
    -- reset per-frame layout cache so hit-tests match what's drawn
    self.layout_cache = {}
    -- Background and border
    local V, Colors = self:_getViewConfig()
    self:_drawBackgroundAndBorder(w, h, Colors)

    -- Layout metrics
    local tab = V.tab or {x=8, y=28, w=110, h=18}
    local pad = V.padding or {x=16, y=60}
    local px, py = pad.x, pad.y
    local dropdown_w, dropdown_h = (V.dropdown and V.dropdown.w) or 160, (V.dropdown and V.dropdown.h) or 22
    local prev_w = (self.schema.preview and self.schema.preview.width) or (V.preview and V.preview.w) or 320
    local prev_h = (self.schema.preview and self.schema.preview.height) or (V.preview and V.preview.h) or 200
    local frame_pad = (V.preview and V.preview.frame_pad) or 4
    local label_col_w = V.label_col_w or 110

    -- Tab strip
    self:_drawTab(tab, Colors)

    -- Preview frame to the right of dropdown area
    local frame_x = px + label_col_w + dropdown_w + 24
    local frame_y = py - 10
    self:_drawPreviewFrame(frame_x, frame_y, prev_w, prev_h, frame_pad, Colors)

    -- Compute form columns
    local right_edge = frame_x - 16
    local row_space = (V.row_gap or 22)
    local label_x = px
    local slider_x = px + label_col_w
    local value_col_w = 60
    local function get_slider_w()
        return math.max(120, right_edge - slider_x - value_col_w - 8)
    end
    local function printLabel(text, x, y)
        love.graphics.setColor(0,0,0)
        love.graphics.print(text, x, y)
    end
    local function printValueRightAligned(text, x, w, y)
        love.graphics.setColor(0,0,0)
        love.graphics.printf(text, x, y, w, 'right')
    end
    local function passesWhen(cond)
        if not cond then return true end
        for k, v in pairs(cond) do
            -- Prefer pending override, then fall back to current settings
            local cur = pending[k]
            if cur == nil then cur = settings[k] end
            if cur ~= v then return false end
        end
        return true
    end

    -- Draw preview
    self:drawPreview(frame_x, frame_y, prev_w, prev_h)

    local current_type = pending.screensaver_type or settings.screensaver_type or 'starfield'
    local cy = py - (self.scroll.offset or 0)
    local dropdown_to_draw = nil
    local content_bottom = cy
    for _, el in ipairs(self.schema.elements or {}) do
        if passesWhen(el.when) then
            if el.type == 'dropdown' then
                printLabel(el.label .. ':', label_x, cy)
                local tp_x, tp_y = slider_x, cy - 4
                -- resolve current value (special-case screensaver_type default)
                local cur = pending[el.id]; if cur == nil then cur = settings[el.id] end
                if el.id == 'screensaver_type' and cur == nil then cur = 'starfield' end
                local display = tostring(cur or '')
                if el.choices and type(el.choices[1]) == 'table' then
                    for _, c in ipairs(el.choices) do if c.value == cur then display = c.label break end end
                end
                UI.drawDropdown(tp_x, tp_y, dropdown_w, dropdown_h, display, true, (self.dropdown_open_id == el.id))
                -- If open, schedule list
                if self.dropdown_open_id == el.id then
                    local item_h = dropdown_h
                    local labels = {}
                    if el.choices and type(el.choices[1]) == 'table' then
                        for _, c in ipairs(el.choices) do table.insert(labels, c.label) end
                    else
                        labels = el.choices or {}
                    end
                    dropdown_to_draw = {
                        id = el.id,
                        x = tp_x,
                        y = tp_y + dropdown_h + 2,
                        w = dropdown_w,
                        item_h = item_h,
                        labels = labels,
                        items = el.choices or labels
                    }
                end
                self.layout_cache[el.id] = {rect={x=tp_x, y=tp_y, w=dropdown_w, h=dropdown_h}, el=el}
                cy = cy + 34
            elseif el.type == 'checkbox' then
                local cb_cfg = V.checkbox or {w=18, h=18}
                local cb_x, cb_y, cb_w, cb_h = label_x, cy, cb_cfg.w, cb_cfg.h
                love.graphics.setColor((V.colors and V.colors.checkbox_fill) or {1,1,1}); love.graphics.rectangle('fill', cb_x, cb_y, cb_w, cb_h)
                love.graphics.setColor((V.colors and V.colors.checkbox_border) or {0,0,0}); love.graphics.rectangle('line', cb_x, cb_y, cb_w, cb_h)
                local checked = pending[el.id]
                if checked == nil then checked = settings[el.id] end
                if checked then
                    love.graphics.setColor((V.colors and V.colors.checkbox_check) or {0,0.7,0})
                    local C = (self.di and self.di.config) or {}
                    local d = (C and C.screensavers and C.screensavers.defaults and C.screensavers.defaults.pipes) or {}
                    love.graphics.line(cb_x + 3, cb_y + cb_h/2, cb_x + cb_w/2, cb_y + cb_h - 4, cb_x + cb_w - 3, cb_y + 3)
                    love.graphics.setLineWidth(1)
                end
                printLabel(el.label, cb_x + cb_w + 10, cb_y - 2)
                self.layout_cache[el.id] = {rect={x=cb_x, y=cb_y, w=cb_w, h=cb_h}, el=el}
                if el.id == 'screensaver_enabled' then self._enable_rect = {x=cb_x, y=cb_y, w=cb_w, h=cb_h} end
                cy = cy + 34
            elseif el.type == 'section' then
                printLabel(el.label .. ':', label_x, cy)
                love.graphics.setColor((V.colors and V.colors.section_rule) or {0.8,0.8,0.8})
                love.graphics.rectangle('fill', label_x, cy+14, right_edge - label_x, (V.section_rule_h or 2))
                love.graphics.setColor(0,0,0)
                cy = cy + 20
            elseif el.type == 'slider' then
                printLabel(el.label, label_x, cy)
                local sw = get_slider_w()
                local v = pending[el.id]; if v == nil then v = settings[el.id] end
                if v == nil then v = el.min end
                local norm = (v - el.min) / (el.max - el.min)
                -- Draw the slider track and handle so it's visible
                self:drawSlider(slider_x, cy - 2, sw, (V.slider_h or 12), norm)
                local display_v = v
                if el.display_as_percent then display_v = math.floor((v * 100) + 0.5) end
                local fmt = el.format or (el.display_as_percent and "%d%%" or "%s")
                printValueRightAligned(string.format(fmt, display_v), slider_x, sw, cy-4)
                self.layout_cache[el.id] = {rect={x=slider_x, y=cy-2, w=sw, h=(V.slider_h or 12)}, el=el}
                cy = cy + row_space
            elseif el.type == 'text' then
                -- Simple one-line text input
                printLabel(el.label .. ':', label_x, cy)
                local box_x, box_y = slider_x, cy - 4
                local box_w, box_h = right_edge - slider_x, dropdown_h
                love.graphics.setColor(1,1,1)
                love.graphics.rectangle('fill', box_x, box_y, box_w, box_h)
                love.graphics.setColor(0,0,0)
                love.graphics.rectangle('line', box_x, box_y, box_w, box_h)
                local cur = pending[el.id]; if cur == nil then cur = settings[el.id] end
                love.graphics.setColor(0,0,0)
                local text = tostring(cur or '')
                love.graphics.print(text, box_x + 6, box_y + 3)
                self.layout_cache[el.id] = {rect={x=box_x, y=box_y, w=box_w, h=box_h}, el=el}
                cy = cy + 34
            end
        end
        content_bottom = cy
    end
    -- Bottom buttons (stick to bottom of panel area)
    self._ok_rect, self._cancel_rect, self._apply_rect = UI.drawDialogButtons(w, h, next(pending) ~= nil)

    -- Draw dropdown list last
    if dropdown_to_draw then
        self:_drawDropdownList(dropdown_to_draw)
    else
        self._dropdown_list = nil
    end

    -- Update content height and clamp scroll
    self.scroll.content_h = math.max(h, content_bottom + 16)
    local max_offset = math.max(0, self.scroll.content_h - h)
    if (self.scroll.offset or 0) > max_offset then self.scroll.offset = max_offset end
    if self.scroll.offset < 0 then self.scroll.offset = 0 end

    -- Draw scrollbar if needed
    if max_offset > 0 then
        local sb_w = 10
        local sb_x = w - sb_w - 4
        local sb_h = h - 40
        local track_y = 20
        local track_h = sb_h
        love.graphics.setColor(0.9,0.9,0.95)
        love.graphics.rectangle('fill', sb_x, track_y, sb_w, track_h)
        love.graphics.setColor(0.6,0.6,0.7)
        love.graphics.rectangle('line', sb_x, track_y, sb_w, track_h)
        local ratio = h / self.scroll.content_h
        local thumb_h = math.max(24, track_h * ratio)
        local thumb_y = track_y + (track_h - thumb_h) * ((self.scroll.offset or 0) / max_offset)
        love.graphics.setColor(0.5,0.5,0.7)
        love.graphics.rectangle('fill', sb_x+1, thumb_y, sb_w-2, thumb_h)
        love.graphics.setColor(0.2,0.2,0.4)
        love.graphics.rectangle('line', sb_x+1, thumb_y, sb_w-2, thumb_h)
        self._scrollbar = { x=sb_x, y=thumb_y, w=sb_w, h=thumb_h, track_y=track_y, track_h=track_h, max_offset=max_offset }
    else
        self._scrollbar = nil
    end
end

local function hit(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function View:mousepressed(x, y, button, settings, pending)
    if button ~= 1 then return nil end
    -- Dropdown handling for screensaver_type
    if self._dropdown_list then
        -- If list is open, test items first
        local dl = self._dropdown_list
        if x >= dl.x and x <= dl.x + dl.w and y >= dl.y and y <= dl.y + dl.h then
            local idx = math.floor((y - dl.y) / dl.item_h) + 1
            local choice = dl.items[idx]
            self.dropdown_open_id = nil
            if choice then
                local value = choice
                if type(choice) == 'table' then value = choice.value end
                return { name='set_pending', id=dl.id, value=value }
            end
        else
            -- Click outside closes list
            self.dropdown_open_id = nil
        end
    end
    -- Toggle any dropdown hit
    for id,entry in pairs(self.layout_cache) do
        local rect = entry.rect
        local el = entry.el
        if el and el.type == 'dropdown' and hit(rect, x, y) then
            self.dropdown_open_id = (self.dropdown_open_id == id) and nil or id
            return nil
        end
    end
    -- Scrollbar thumb drag
    if self._scrollbar and x >= self._scrollbar.x and x <= self._scrollbar.x + self._scrollbar.w and y >= self._scrollbar.y and y <= self._scrollbar.y + self._scrollbar.h then
        self.scroll.dragging = true
        self.scroll.drag_start_y = y
        self.scroll.drag_offset_start = self.scroll.offset or 0
        return { name='content_interaction' }
    end
    -- Schema-driven sliders and checkboxes
    for id,entry in pairs(self.layout_cache) do
        local rect = entry.rect
        local el = entry.el
        if rect and el then
            if el.type == 'slider' and hit(rect, x, y) then
            self.dragging = id
            local t = math.max(0, math.min(1, (x - rect.x) / rect.w))
            local val = el.min + t * (el.max - el.min)
            -- step snapping
            if el.step and el.step > 0 then val = math.floor((val / el.step) + 0.5) * el.step end
            if el.step and el.step < 1 then val = tonumber(string.format('%.2f', val)) end
            return { name='set_pending', id=id, value=val }
            elseif el.type == 'checkbox' and hit(rect, x, y) then
                local cur = pending[id]
                if cur == nil then cur = settings[id] end
                return { name='set_pending', id=id, value=not cur }
            elseif el.type == 'text' and hit(rect, x, y) then
                -- Focus text input: mark focused id
                self.focus_text_id = id
                return nil
            end
        end
    end
    if hit(self._ok_rect, x, y) then return { name='ok' } end
    if hit(self._cancel_rect, x, y) then return { name='cancel' } end
    if hit(self._apply_rect, x, y) then return { name='apply' } end
    return nil
end

function View:mousemoved(x, y, dx, dy, settings, pending)
    if self.dragging and self.layout_cache[self.dragging] then
        local entry = self.layout_cache[self.dragging]
        local rect = entry.rect
        local el = entry.el
        local t = math.max(0, math.min(1, (x - rect.x) / rect.w))
        local val = el.min + t * (el.max - el.min)
        if el.step and el.step > 0 then val = math.floor((val / el.step) + 0.5) * el.step end
        if el.step and el.step < 1 then val = tonumber(string.format('%.2f', val)) end
        return { name='set_pending', id=self.dragging, value=val }
    end
    if self.scroll.dragging and self._scrollbar then
        local sb = self._scrollbar
        local track_span = sb.track_h - sb.h
        if track_span < 1 then track_span = 1 end
        local dy_pixels = (y - self.scroll.drag_start_y)
        local ratio = dy_pixels / track_span
        local new_offset = (self.scroll.drag_offset_start or 0) + (sb.max_offset * ratio)
        if new_offset < 0 then new_offset = 0 end
        if new_offset > sb.max_offset then new_offset = sb.max_offset end
        self.scroll.offset = new_offset
        return { name='content_interaction' }
    end
end

function View:mousereleased(x, y, button, settings, pending)
    if button == 1 then self.dragging = nil; self.scroll.dragging = false end
end

function View:wheelmoved(x, y, settings, pending)
    -- y>0 scrolls up (negative offset change)
    local step = 40
    self.scroll.offset = math.max(0, math.min((self.scroll.offset or 0) - y*step, math.max(0, (self.scroll.content_h or 0) - (self.h or 0))))
    return { name='content_interaction' }
end

function View:keypressed(key, scancode, isrepeat, settings, pending)
    if self.focus_text_id then
        if key == 'backspace' then
            local cur = pending[self.focus_text_id]
            if cur == nil then cur = settings[self.focus_text_id] or '' end
            cur = tostring(cur)
            cur = string.sub(cur, 1, math.max(0, #cur - 1))
            return { name='set_pending', id=self.focus_text_id, value=cur }
        elseif key == 'return' or key == 'kpenter' then
            self.focus_text_id = nil
            return nil
        end
    end
end

function View:textinput(text, settings, pending)
    if self.focus_text_id and text and text ~= '' then
        local cur = pending[self.focus_text_id]
        if cur == nil then cur = settings[self.focus_text_id] or '' end
        cur = tostring(cur) .. text
        -- Optional max length clamp from schema
        local el = self.layout_cache[self.focus_text_id] and self.layout_cache[self.focus_text_id].el
        local maxlen = el and el.max or nil
        if maxlen and #cur > maxlen then cur = string.sub(cur, 1, maxlen) end
        return { name='set_pending', id=self.focus_text_id, value=cur }
    end
end

return View
