local Object = require('class')
local UI = require('src.views.ui_components')
local json = require('json')

local View = Object:extend('ControlPanelScreensaversView')

function View:init(controller)
    self.controller = controller
    self.dragging = nil
    self.preview = { canvas = nil, saver = nil, last_key = nil }
    self.schema = self:_loadSchema('assets/data/control_panels/screensavers.json')
    self.layout_cache = {} -- id -> {rect, el}
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
            'screensaver_model_morph_speed','screensaver_model_two_sided'
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
            local PipesView = require('src.views.screensaver_pipes_view')
            self.preview.saver = PipesView:new({
                fov = getVal(pending, settings, 'screensaver_pipes_fov', 420),
                near = getVal(pending, settings, 'screensaver_pipes_near', 80),
                radius = getVal(pending, settings, 'screensaver_pipes_radius', 4.5),
                grid_step = getVal(pending, settings, 'screensaver_pipes_grid_step', 24),
                max_segments = getVal(pending, settings, 'screensaver_pipes_max_segments', 800),
                turn_chance = getVal(pending, settings, 'screensaver_pipes_turn_chance', 0.45),
                speed = getVal(pending, settings, 'screensaver_pipes_speed', 60),
                spawn_min_z = getVal(pending, settings, 'screensaver_pipes_spawn_min_z', 200),
                spawn_max_z = getVal(pending, settings, 'screensaver_pipes_spawn_max_z', 600),
                avoid_cells = getVal(pending, settings, 'screensaver_pipes_avoid_cells', true),
                show_grid = getVal(pending, settings, 'screensaver_pipes_show_grid', false),
                camera_drift = getVal(pending, settings, 'screensaver_pipes_camera_drift', 40),
                camera_roll = getVal(pending, settings, 'screensaver_pipes_camera_roll', 0.05),
                pipe_count = getVal(pending, settings, 'screensaver_pipes_pipe_count', 5),
                show_hud = getVal(pending, settings, 'screensaver_pipes_show_hud', true),
            })
        elseif t == 'model3d' then
            local ModelView = require('src.views.screensaver_model_view')
            self.preview.saver = ModelView:new({
                fov = getVal(pending, settings, 'screensaver_model_fov', 350),
                grid_lat = getVal(pending, settings, 'screensaver_model_grid_lat', 24),
                grid_lon = getVal(pending, settings, 'screensaver_model_grid_lon', 48),
                morph_speed = getVal(pending, settings, 'screensaver_model_morph_speed', 0.3),
                two_sided = getVal(pending, settings, 'screensaver_model_two_sided', false),
            })
        else
            local StarView = require('src.views.screensaver_view')
            self.preview.saver = StarView:new({
                count = getVal(pending, settings, 'screensaver_starfield_count', 500),
                speed = getVal(pending, settings, 'screensaver_starfield_speed', 120),
                fov = getVal(pending, settings, 'screensaver_starfield_fov', 300),
                tail = getVal(pending, settings, 'screensaver_starfield_tail', 12),
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
    -- Background
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle('line', 0, 0, w, h)
    love.graphics.setColor(0,0,0)

    -- Tab strip
    love.graphics.setColor(0.9,0.9,0.95)
    love.graphics.rectangle('fill', 8, 28, 110, 18)
    love.graphics.setColor(0.2,0.2,0.2)
    love.graphics.rectangle('line', 8, 28, 110, 18)
    love.graphics.print('Screen Saver', 16, 31)

    -- Reset interaction cache
    self.layout_cache = {}
    self._type_rect, self._enable_rect = nil, nil

    local px, py = 16, 60
    local current_type = pending.screensaver_type or settings.screensaver_type or 'starfield'

    -- Preview (from schema)
    local prev_w = (self.schema.preview and self.schema.preview.width) or 320
    local prev_h = (self.schema.preview and self.schema.preview.height) or 200
    local dropdown_w, dropdown_h = 160, 22
    local frame_x, frame_y = px + 110 + dropdown_w + 24, py - 10
    love.graphics.setColor(0.9,0.9,0.95); love.graphics.rectangle('fill', frame_x-4, frame_y-4, prev_w+8, prev_h+8)
    love.graphics.setColor(0.2,0.2,0.2); love.graphics.rectangle('line', frame_x-4, frame_y-4, prev_w+8, prev_h+8)
    self:drawPreview(frame_x, frame_y, prev_w, prev_h)

    -- Layout metrics
    local right_edge = frame_x - 16
    local value_col_w = 60
    local function printValueRightAligned(text, slider_x, slider_w, y)
        local x = slider_x + slider_w + 8
        love.graphics.setColor(0,0,0)
        love.graphics.print(text, x, y)
    end

    local row_space = 22
    local label_x = px
    local slider_x = px + 110
    local get_slider_w = function() return math.max(120, right_edge - slider_x - value_col_w - 8) end

    local function printLabel(text, x, y)
        love.graphics.setColor(0,0,0)
        love.graphics.print(text, x, y)
    end

    local function passesWhen(cond)
        if not cond then return true end
        for k,v in pairs(cond) do
            local cur = pending[k]
            if cur == nil then cur = settings[k] end
            if cur ~= v then return false end
        end
        return true
    end

    local cy = py
    local dropdown_to_draw = nil
    for _,el in ipairs(self.schema.elements or {}) do
        if passesWhen(el.when) then
            if el.type == 'dropdown' then
                printLabel(el.label .. ':', label_x, cy)
                local tp_x, tp_y = slider_x, cy-4
                -- Compute display label from schema choices
                local display = current_type
                if el.choices and type(el.choices[1]) == 'table' then
                    for _,c in ipairs(el.choices) do if c.value == current_type then display = c.label break end end
                end
                UI.drawDropdown(tp_x, tp_y, dropdown_w, dropdown_h, display, true, false)
                -- If open, schedule list to draw on top after all content
                if self.dropdown_open_id == el.id then
                    local item_h = dropdown_h
                    local labels = {}
                    if el.choices and type(el.choices[1]) == 'table' then
                        for _,c in ipairs(el.choices) do table.insert(labels, c.label) end
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
                self._type_rect = {x=tp_x, y=tp_y, w=dropdown_w, h=dropdown_h}
                cy = cy + 34
            elseif el.type == 'checkbox' then
                local cb_x, cb_y, cb_w, cb_h = label_x, cy, 18, 18
                love.graphics.setColor(1,1,1); love.graphics.rectangle('fill', cb_x, cb_y, cb_w, cb_h)
                love.graphics.setColor(0,0,0); love.graphics.rectangle('line', cb_x, cb_y, cb_w, cb_h)
                local checked = pending[el.id]
                if checked == nil then checked = settings[el.id] end
                if checked then
                    love.graphics.setColor(0, 0.7, 0)
                    love.graphics.setLineWidth(3)
                    love.graphics.line(cb_x + 3, cb_y + cb_h/2, cb_x + cb_w/2, cb_y + cb_h - 4, cb_x + cb_w - 3, cb_y + 3)
                    love.graphics.setLineWidth(1)
                end
                printLabel(el.label, cb_x + cb_w + 10, cb_y - 2)
                self.layout_cache[el.id] = {rect={x=cb_x, y=cb_y, w=cb_w, h=cb_h}, el=el}
                if el.id == 'screensaver_enabled' then self._enable_rect = {x=cb_x, y=cb_y, w=cb_w, h=cb_h} end
                cy = cy + 34
            elseif el.type == 'section' then
                printLabel(el.label .. ':', label_x, cy)
                love.graphics.setColor(0.8,0.8,0.8)
                love.graphics.rectangle('fill', label_x, cy+14, right_edge - label_x, 2)
                love.graphics.setColor(0,0,0)
                cy = cy + 20
            elseif el.type == 'slider' then
                printLabel(el.label, label_x, cy)
                local sw = get_slider_w()
                local v = pending[el.id]; if v == nil then v = settings[el.id] end
                if v == nil then v = el.min end
                local norm = (v - el.min) / (el.max - el.min)
                self:drawSlider(slider_x, cy-2, sw, 12, math.max(0, math.min(1, norm)))
                local display_v = v
                if el.display_as_percent then display_v = math.floor((v * 100) + 0.5) end
                local fmt = el.format or (el.display_as_percent and "%d%%" or "%s")
                printValueRightAligned(string.format(fmt, display_v), slider_x, sw, cy-4)
                self.layout_cache[el.id] = {rect={x=slider_x, y=cy-2, w=sw, h=12}, el=el}
                cy = cy + row_space
            end
        end
    end

    -- Bottom buttons (deduped helper)
    self._ok_rect, self._cancel_rect, self._apply_rect = UI.drawDialogButtons(w, h, next(pending) ~= nil)

    -- Draw dropdown list last so it appears on top of everything
    if dropdown_to_draw then
        UI.drawDropdownList(
            dropdown_to_draw.x,
            dropdown_to_draw.y,
            dropdown_to_draw.w,
            dropdown_to_draw.item_h,
            dropdown_to_draw.labels,
            nil
        )
        -- update hit area
        self._dropdown_list = {
            id = dropdown_to_draw.id,
            x = dropdown_to_draw.x,
            y = dropdown_to_draw.y,
            w = dropdown_to_draw.w,
            h = #dropdown_to_draw.labels * dropdown_to_draw.item_h,
            item_h = dropdown_to_draw.item_h,
            items = dropdown_to_draw.items
        }
    else
        self._dropdown_list = nil
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
    if hit(self._type_rect, x, y) then
        -- toggle open/close
        self.dropdown_open_id = (self.dropdown_open_id == 'screensaver_type') and nil or 'screensaver_type'
        return nil
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
end

function View:mousereleased(x, y, button, settings, pending)
    if button == 1 then self.dragging = nil end
end

return View
