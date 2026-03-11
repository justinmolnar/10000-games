local BaseView = require('src.views.base_view')
local UI = require('src.views.ui_components')
local Form = require('src.views.ui_dynamic_form')
local Paths = require('src.paths')

local View = BaseView:extend('ControlPanelDisplayView')

function View:init(controller, di)
    View.super.init(self, controller)
    self.controller = controller
    self.di = di
    if di then UI.inject(di) end

    self.form = Form:new({
        schema_path = Paths.data.control_panels .. 'display.json',
        on_event = function(ev) if self.controller and self.controller.handle_event then self.controller:handle_event(ev) end end,
        get = function(id)
            local p = self.controller.pending or {}
            local s = self.controller.settings or {}
            local v = p[id]
            if v == nil then v = s[id] end
            -- Provide sensible defaults from current state
            if v == nil then
                if id == 'display_monitor' then
                    local _, _, flags = love.window.getMode()
                    v = flags and flags.display or 1
                elseif id == 'display_resolution' then
                    local w, h = love.window.getMode()
                    v = w .. "x" .. h
                elseif id == 'display_mode' then
                    local _, _, flags = love.window.getMode()
                    if flags and flags.fullscreen then
                        v = (flags.fullscreentype == 'desktop') and 'borderless' or 'fullscreen'
                    else
                        v = 'windowed'
                    end
                end
            end
            return v
        end,
        choices_provider = function(key)
            if key == 'monitors' then
                return self:getMonitorChoices()
            elseif key == 'resolutions' then
                return self:getResolutionChoices()
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

function View:getMonitorChoices()
    local count = love.window.getDisplayCount()
    local choices = {}
    for i = 1, count do
        local ok, name = pcall(love.window.getDisplayName, i)
        local label = "Monitor " .. i
        if ok and name and name ~= "" then
            label = label .. " (" .. name .. ")"
        end
        table.insert(choices, { label = label, value = i })
    end
    if #choices == 0 then
        table.insert(choices, { label = "Monitor 1", value = 1 })
    end
    return choices
end

function View:getResolutionChoices()
    -- Get the currently selected monitor
    local p = self.controller.pending or {}
    local s = self.controller.settings or {}
    local display = p.display_monitor or s.display_monitor
    if not display then
        local _, _, flags = love.window.getMode()
        display = flags and flags.display or 1
    end

    local modes = love.window.getFullscreenModes(display)
    -- Sort by width descending
    table.sort(modes, function(a, b)
        if a.width == b.width then return a.height > b.height end
        return a.width > b.width
    end)

    local choices = {}
    local seen = {}
    for _, m in ipairs(modes) do
        local key = m.width .. "x" .. m.height
        if not seen[key] then
            seen[key] = true
            table.insert(choices, { label = m.width .. " x " .. m.height, value = key })
        end
    end

    if #choices == 0 then
        table.insert(choices, { label = "1920 x 1080", value = "1920x1080" })
        table.insert(choices, { label = "1280 x 720", value = "1280x720" })
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
    love.graphics.print("Display", 16, 31)

    self.form.right_edge = w - 24
    self.form.viewport_h = h
    self.form:draw()

    -- Current display info
    local info_y = 180
    love.graphics.setColor(0.3, 0.3, 0.3)
    local cur_w, cur_h, flags = love.window.getMode()
    local mode_str = "Windowed"
    if flags.fullscreen then
        mode_str = (flags.fullscreentype == 'desktop') and "Borderless" or "Fullscreen"
    end
    love.graphics.print(string.format("Current: %dx%d %s (Monitor %d)", cur_w, cur_h, mode_str, flags.display or 1), 16, info_y)

    local pending = self.draw_params.pending
    self._ok_rect, self._cancel_rect, self._apply_rect = UI.drawDialogButtons(w, h, next(pending) ~= nil)

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
