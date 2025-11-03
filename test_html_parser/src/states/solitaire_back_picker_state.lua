-- src/states/solitaire_back_picker_state.lua
local Object = require('class')
local SettingsManager = require('src.utils.settings_manager')
local Backs = require('src.utils.solitaire_backs')
local UI = require('src.views.ui_components')

local State = Object:extend('SolitaireBackPickerState')

function State:init(window_controller, di)
    self.window_controller = window_controller
    self.di = di
    if di then UI.inject(di) end
    self.viewport = nil
    self.items = Backs.list()
    self.hover_index = nil
    self.cols = 4
    self.cell_w, self.cell_h = 120, 170
    self.margin = 16
    self.top_y = 40
    self.scroll = { offset_px = 0, drag = nil, geom_local = nil }
end

function State:setViewport(x, y, w, h)
    self.viewport = {x=x, y=y, width=w, height=h}
    self:_recomputeLayout()
end

function State:enter()
end

function State:update(dt) end

function State:draw()
    local w, h = self.viewport.width, self.viewport.height
    love.graphics.setColor(0.92,0.92,0.95)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(0,0,0)
    love.graphics.print('Choose a Card Back', 12, 12, 0, 1.2, 1.2)
    -- Ensure layout/geom
    self:_recomputeLayout()
    -- draw grid without scissor to avoid any visual clipping
    local x0, y0 = self.grid.x, self.grid.y - math.floor(self.scroll.offset_px)
    local frame_pad = 2
    local frame_w = self.cell_w + frame_pad*2
    local frame_h = self.cell_h + 24
    self._rects = {}
    for i, item in ipairs(self.items) do
        local col = ((i-1) % self.cols)
        local row = math.floor((i-1) / self.cols)
        local cx = x0 + col * (frame_w + self.margin)
        local cy = y0 + row * (frame_h + self.margin)
        -- Only draw if within grid Y range
        if cy < (self.grid.y + self.grid.h) and (cy + frame_h) > self.grid.y then
            local hovered = (self.hover_index == i)
            love.graphics.setColor(hovered and {0.2,0.5,0.9} or {0.7,0.7,0.7})
            love.graphics.rectangle('line', cx, cy, frame_w, frame_h)
            -- image
            local ok = Backs.drawBack(item.id, cx + frame_pad, cy + frame_pad, self.cell_w, self.cell_h)
            if not ok then
                love.graphics.setColor(0.3,0.5,0.8)
                love.graphics.rectangle('fill', cx + frame_pad, cy + frame_pad, self.cell_w, self.cell_h, 6, 6)
                love.graphics.setColor(1,1,1)
                love.graphics.rectangle('line', cx + frame_pad, cy + frame_pad, self.cell_w, self.cell_h, 6, 6)
            end
            -- label
            love.graphics.setColor(0,0,0)
            love.graphics.print(item.name or item.id, cx + frame_pad, cy + self.cell_h + frame_pad*2)
        end
        -- cache absolute hit rects
        self._rects[i] = { x=cx, y=cy, w=frame_w, h=frame_h }
    end
    -- no scissor
    -- Scrollbar
    self:_drawScrollbar()
    -- Close button
    local bw, bh = 70, 24
    self._close_rect = { x = w - (bw + 16), y = h - (bh + 16), w = bw, h = bh }
    UI.drawButton(self._close_rect.x, self._close_rect.y, bw, bh, 'Close', true, false)
end

local function hit(r, x, y)
    return r and x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h
end

function State:mousemoved(x, y, dx, dy)
    self:_recomputeLayout()
    -- Scrollbar drag
    if self.scroll and self.scroll.drag and self.scroll.geom_local then
        local ly = y - self.grid.y
        local ret = UI.scrollbarHandleMove(ly, self.scroll.drag, self.scroll.geom_local)
        if ret and ret.new_offset_px then self.scroll.offset_px = ret.new_offset_px end
    end
    -- Hover over items
    self.hover_index = nil
    if not self._rects then return end
    for i,r in ipairs(self._rects) do
        if hit(r,x,y) then
            -- ensure within grid scissor too
            if y >= self.grid.y and y <= self.grid.y + self.grid.h then
                self.hover_index = i
                break
            end
        end
    end
end

function State:mousepressed(x, y, button)
    if button ~= 1 then return false end
    -- Scrollbar interactions if inside grid area or its lane
    local lane_w = (UI.getScrollbarLaneWidth and UI.getScrollbarLaneWidth()) or 12
    if x >= self.grid.x and x <= self.grid.x + self.grid.w + lane_w and y >= self.grid.y and y <= self.grid.y + self.grid.h then
        if self.scroll and self.scroll.geom_local then
            local lx = x - self.grid.x
            local ly = y - self.grid.y
            local ret = UI.scrollbarHandlePress(lx, ly, button, self.scroll.geom_local, self.scroll.offset_px)
            if ret and ret.consumed then
                if ret.new_offset_px ~= nil then self.scroll.offset_px = ret.new_offset_px end
                self.scroll.drag = ret.drag
                return { type = 'content_interaction' }
            end
        end
    end
    if self._rects then
        for i,r in ipairs(self._rects) do
            if hit(r,x,y) then
                local chosen = self.items[i]
                if chosen then
                    SettingsManager.set('solitaire_card_back', chosen.id)
                    SettingsManager.save()
                    -- Also write a Solitaire snapshot so the back persists with game state
                    local okV, SolitaireState = pcall(require, 'src.states.solitaire_state')
                    if okV and SolitaireState then
                        -- best-effort: if a solitaire view exists, ask it for a snapshot
                        local s_ok, desktop = pcall(function() return self.window_controller and self.window_controller.desktop_state end)
                        if s_ok and desktop and desktop.findWindowByProgramId then
                            local win = desktop:findWindowByProgramId('solitaire')
                            if win and win.state and win.state.view and win.state.view.getSnapshot then
                                local okSnap, snap = pcall(win.state.view.getSnapshot, win.state.view)
                                if okSnap and snap then pcall(require('src.utils.solitaire_save').save, snap) end
                            end
                        end
                    end
                    return { type = 'close_window' }
                end
            end
        end
    end
    if hit(self._close_rect, x, y) then
        return { type = 'close_window' }
    end
    return { type = 'content_interaction' }
end

function State:keypressed(key)
    if key == 'escape' then return { type = 'close_window' } end
    return false
end

function State:mousereleased(x, y, button)
    if button ~= 1 then return false end
    if self.scroll and self.scroll.drag then
        UI.scrollbarHandleRelease()
        self.scroll.drag = nil
        return { type = 'content_interaction' }
    end
    return false
end

function State:wheelmoved(x, y)
    -- y > 0 scrolls up, y < 0 scrolls down
    if not (self.grid and self.content_h) then return end
    local step = (self.cell_h + self.margin) * 2
    local new_off = (self.scroll.offset_px or 0) - y * step
    local max_off = math.max(0, (self.content_h or 0) - (self.grid.h or 0))
    if new_off < 0 then new_off = 0 end
    if new_off > max_off then new_off = max_off end
    self.scroll.offset_px = new_off
end

-- Internal helpers
function State:_recomputeLayout()
    if not self.viewport then return end
    local w, h = self.viewport.width, self.viewport.height
    local bw, bh = 70, 24
    local bottom_reserved = 16 + bh + 16
    local lane_w = (UI.getScrollbarLaneWidth and UI.getScrollbarLaneWidth()) or 12
    self.grid = {
        x = self.margin,
        y = self.top_y,
        w = math.max(0, w - self.margin*2 - lane_w),
        h = math.max(0, h - self.top_y - bottom_reserved)
    }
    -- compute columns/rows based on frame size
    local frame_pad = 2
    local frame_w = self.cell_w + frame_pad*2
    local frame_h = self.cell_h + 24
    local full_w = frame_w + self.margin
    local full_h = frame_h + self.margin
    self.cols = math.max(1, math.floor((self.grid.w + self.margin) / full_w))
    local rows = math.ceil(#self.items / self.cols)
    self.content_h = rows * full_h
    -- clamp scroll offset
    local max_off = math.max(0, self.content_h - self.grid.h)
    if self.scroll.offset_px > max_off then self.scroll.offset_px = max_off end
    if self.scroll.offset_px < 0 then self.scroll.offset_px = 0 end
    -- compute local scrollbar geom for the grid area
    local geom = UI.computeScrollbar({
        viewport_w = self.grid.w + lane_w,
        viewport_h = self.grid.h,
        content_h = self.content_h,
        offset = self.scroll.offset_px
    })
    self.scroll.geom_local = geom
    self._sb_draw_offset = { dx = self.grid.x, dy = self.grid.y }
end

function State:_drawScrollbar()
    local geom = self.scroll.geom_local
    if not geom then return end
    -- Offset geom for drawing in absolute coords
    local dx, dy = self._sb_draw_offset.dx, self._sb_draw_offset.dy
    local function off(r)
        if not r then return nil end
        return { x = r.x + dx, y = r.y + dy, w = r.w, h = r.h }
    end
    local g2 = {
        bounds = off(geom.bounds), track = off(geom.track), thumb = off(geom.thumb), thumb_draw = off(geom.thumb_draw),
        arrow_up = off(geom.arrow_up), arrow_down = off(geom.arrow_down), max_offset = geom.max_offset
    }
    UI.drawScrollbar(g2)
end

return State
