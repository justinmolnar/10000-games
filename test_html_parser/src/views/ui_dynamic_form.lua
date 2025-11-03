local Object = require('class')
local UI = require('src.views.ui_components')
local json = require('json')

local Form = Object:extend('UIDynamicForm')

function Form:init(opts)
    self.schema_path = opts.schema_path
    self.on_event = opts.on_event -- function(event)
    self.get = opts.get           -- function(id) -> current/pending value
    if opts.di then UI.inject(opts.di) end
    self.label_x = opts.label_x or 16
    self.slider_x = opts.slider_x or 126
    self.dropdown_w = opts.dropdown_w or 160
    self.dropdown_h = opts.dropdown_h or 22
    self.value_col_w = opts.value_col_w or 60
    self.right_edge = opts.right_edge or (self.slider_x + 240)
    self.row_space = opts.row_space or 22
    self.y = opts.y or 60
    self.layout_cache = {}
    self.schema = self:_loadSchema(self.schema_path)
end

function Form:_loadSchema(path)
    local ok, contents = pcall(love.filesystem.read, path)
    if not ok or not contents then return { elements = {} } end
    local ok2, data = pcall(json.decode, contents)
    if not ok2 or not data then return { elements = {} } end
    return data
end

function Form:_print(text, x, y)
    love.graphics.setColor(0,0,0)
    love.graphics.print(text, x, y)
end

function Form:_drawSlider(x, y, w, h, t)
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

local function hit(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function Form:passesWhen(cond)
    if not cond then return true end
    for k,v in pairs(cond) do
        if self.get(k) ~= v then return false end
    end
    return true
end

function Form:getSliderWidth()
    return math.max(120, self.right_edge - self.slider_x - self.value_col_w - 8)
end

function Form:draw()
    local cy = self.y
    self.layout_cache = {}
    for _,el in ipairs(self.schema.elements or {}) do
        if self:passesWhen(el.when) then
            if el.type == 'section' then
                self:_print(el.label .. ':', self.label_x, cy)
                love.graphics.setColor(0.8,0.8,0.8)
                love.graphics.rectangle('fill', self.label_x, cy+14, self.right_edge - self.label_x, 2)
                love.graphics.setColor(0,0,0)
                cy = cy + 20
            elseif el.type == 'dropdown' then
                self:_print((el.label or '') .. ':', self.label_x, cy)
                local tp_x, tp_y = self.slider_x, cy-4
                local cur = self.get(el.id)
                local label = tostring(cur or '')
                if el.choices and type(el.choices[1]) == 'table' then
                    -- find label for current value
                    local found = false
                    for _,c in ipairs(el.choices) do
                        if c.value == cur then label = c.label; found = true; break end
                    end
                    -- If current value is nil and not found, use first choice label
                    if not found and cur == nil and el.choices[1] then
                        label = el.choices[1].label
                    end
                end
                UI.drawDropdown(tp_x, tp_y, self.dropdown_w, self.dropdown_h, label, true, false)
                self.layout_cache[el.id] = {rect={x=tp_x, y=tp_y, w=self.dropdown_w, h=self.dropdown_h}, el=el}
                cy = cy + 34
            elseif el.type == 'checkbox' then
                local cb_x, cb_y, cb_w, cb_h = self.label_x, cy, 18, 18
                love.graphics.setColor(1,1,1); love.graphics.rectangle('fill', cb_x, cb_y, cb_w, cb_h)
                love.graphics.setColor(0,0,0); love.graphics.rectangle('line', cb_x, cb_y, cb_w, cb_h)
                local checked = self.get(el.id)
                if checked then
                    love.graphics.setColor(0, 0.7, 0)
                    love.graphics.setLineWidth(3)
                    love.graphics.line(cb_x + 3, cb_y + cb_h/2, cb_x + cb_w/2, cb_y + cb_h - 4, cb_x + cb_w - 3, cb_y + 3)
                    love.graphics.setLineWidth(1)
                end
                self:_print(el.label, cb_x + cb_w + 10, cb_y - 2)
                self.layout_cache[el.id] = {rect={x=cb_x, y=cb_y, w=cb_w, h=cb_h}, el=el}
                cy = cy + 34
            elseif el.type == 'slider' then
                self:_print(el.label, self.label_x, cy)
                local sw = self:getSliderWidth()
                local v = self.get(el.id)
                if v == nil then v = el.min end
                local norm = (v - el.min) / (el.max - el.min)
                self:_drawSlider(self.slider_x, cy-2, sw, 12, math.max(0, math.min(1, norm)))
                local display_v = v
                if el.display_as_percent then display_v = math.floor((v * 100) + 0.5) end
                local fmt = el.format or (el.display_as_percent and "%d%%" or "%s")
                self:_print(string.format(fmt, display_v), self.slider_x + sw + 8, cy-4)
                self.layout_cache[el.id] = {rect={x=self.slider_x, y=cy-2, w=sw, h=12}, el=el}
                cy = cy + self.row_space
            end
        end
    end
end

function Form:mousepressed(x, y, button)
    if button ~= 1 then return end
    for id,entry in pairs(self.layout_cache) do
        local rect, el = entry.rect, entry.el
        if rect and el then
            if el.type == 'dropdown' and hit(rect, x, y) then
                local cur = self.get(el.id)
                local idx = 1
                if el.choices then
                    if type(el.choices[1]) == 'table' then
                        for i,c in ipairs(el.choices) do if c.value == cur then idx = i break end end
                        idx = idx % #el.choices + 1
                        if self.on_event then self.on_event({ name='set_pending', id=el.id, value=el.choices[idx].value }) end
                        return
                    else
                        local curS = tostring(cur)
                        for i,c in ipairs(el.choices) do if tostring(c) == curS then idx = i break end end
                        idx = idx % #el.choices + 1
                        if self.on_event then self.on_event({ name='set_pending', id=el.id, value=el.choices[idx] }) end
                        return
                    end
                end
            elseif el.type == 'checkbox' and hit(rect, x, y) then
                local cur = self.get(el.id)
                if self.on_event then self.on_event({ name='set_pending', id=el.id, value=not cur }) end
                return
            elseif el.type == 'slider' and hit(rect, x, y) then
                self.dragging = id
                local t = math.max(0, math.min(1, (x - rect.x) / rect.w))
                local val = el.min + t * (el.max - el.min)
                if el.step and el.step > 0 then
                    val = math.floor((val / el.step) + 0.5) * el.step
                    if el.step < 1 then val = tonumber(string.format('%.2f', val)) end
                end
                if self.on_event then self.on_event({ name='set_pending', id=id, value=val }) end
                return
            end
        end
    end
end

function Form:mousemoved(x, y, dx, dy)
    if self.dragging and self.layout_cache[self.dragging] then
        local rect = self.layout_cache[self.dragging].rect
        local el = self.layout_cache[self.dragging].el
        local t = math.max(0, math.min(1, (x - rect.x) / rect.w))
        local val = el.min + t * (el.max - el.min)
        if el.step and el.step > 0 then
            val = math.floor((val / el.step) + 0.5) * el.step
            if el.step < 1 then val = tonumber(string.format('%.2f', val)) end
        end
        if self.on_event then self.on_event({ name='set_pending', id=self.dragging, value=val }) end
    end
end

function Form:mousereleased(x, y, button)
    if button == 1 then self.dragging = nil end
end

return Form