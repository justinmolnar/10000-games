-- ui_components.lua: Reusable UI drawing components
--
-- Scope and design notes (Phase 3.3):
-- - This module provides draw-only primitives (buttons, dropdowns, panels, badges, etc.).
-- - It is DI-aware via UIComponents.inject(di) for config and strings; it should not own business logic.
-- - Input/hit-testing is owned by calling views; complex behaviors should be implemented in the state/controller.
-- - If any component starts to accumulate business rules or multi-step flows, promote it into its own mini MVP triad
--   (ComponentController + ComponentView and optional model), keeping this module as light draw helpers.
-- - Current review: components remain presentational; no split required.

local UIComponents = {}
-- Config provided via UIComponents.inject; avoid direct require
local Strings = require('src.utils.strings')

-- Optional DI injection for config/strings
UIComponents._config = nil
UIComponents._strings = nil
function UIComponents.inject(di)
    if di then
        UIComponents._config = di.config or UIComponents._config
        UIComponents._strings = di.strings or UIComponents._strings
    end
end

function UIComponents.drawButton(x, y, w, h, text, enabled, hovered)
    -- Background
    if not enabled then
        love.graphics.setColor(0.3, 0.3, 0.3)
    elseif hovered then
        love.graphics.setColor(0.35, 0.6, 0.35)
    else
        love.graphics.setColor(0, 0.5, 0)
    end
    love.graphics.rectangle('fill', x, y, w, h)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
    
    -- Text
    if enabled then
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
    end
    
    local font = love.graphics.getFont()
    local text_width = font:getWidth(text)
    local text_height = font:getHeight()
    love.graphics.print(text, x + (w - text_width) / 2, y + (h - text_height) / 2)
end

-- Draw a dropdown (collapsed) with a caret indicator
function UIComponents.drawDropdown(x, y, w, h, text, enabled, hovered)
    -- Background similar to button but neutral
    if not enabled then
        love.graphics.setColor(0.85, 0.85, 0.85)
    elseif hovered then
        love.graphics.setColor(0.92, 0.92, 0.98)
    else
        love.graphics.setColor(0.95, 0.95, 0.98)
    end
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
    -- Text
    love.graphics.setColor(0, 0, 0)
    local font = love.graphics.getFont()
    local text_width = font:getWidth(text)
    local text_height = font:getHeight()
    love.graphics.print(text, x + 8, y + (h - text_height) / 2)
    -- Caret (triangle) on the right
    local cx = x + w - 12
    local cy = y + h / 2
    love.graphics.polygon('fill', cx-5, cy-2, cx+5, cy-2, cx, cy+4)
end

-- Draw the expanded dropdown list; items is an array of strings.
-- Returns nothing; caller manages hit rects.
function UIComponents.drawDropdownList(x, y, w, item_h, items, selected_index)
    local count = #items
    local h = count * item_h
    -- Panel
    love.graphics.setColor(0.97, 0.97, 1.0)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
    -- Items
    for i, label in ipairs(items) do
        local iy = y + (i-1) * item_h
        if selected_index == i then
            love.graphics.setColor(0.85, 0.9, 1.0)
            love.graphics.rectangle('fill', x+1, iy+1, w-2, item_h-2)
        end
        love.graphics.setColor(0, 0, 0)
        love.graphics.print(tostring(label), x + 8, iy + 3)
    end
end

function UIComponents.drawTokenCounter(x, y, tokens)
    local Strings_ = UIComponents._strings or Strings
    local Config_ = UIComponents._config or {}
    love.graphics.setColor(1, 1, 1)
    local tokens_label = Strings_.get('tokens.label', 'Tokens: ')
    love.graphics.print(tokens_label, x, y, 0, 1.5, 1.5)
    
    local tok_cfg = (Config_ and Config_.tokens) or {}
    local th = tok_cfg.thresholds or { low = 100, medium = 500 }
    local colors = tok_cfg.colors or { low = {1,0,0}, medium = {1,1,0}, high = {0,1,0} }
    local token_color = colors.high or {0,1,0}
    if type(tokens) == 'number' then
        if tokens < (th.low or 100) then
            token_color = colors.low or {1,0,0}
        elseif tokens < (th.medium or 500) then
            token_color = colors.medium or {1,1,0}
        end
    end
    
    love.graphics.setColor(token_color)
    -- Calculate width of "Tokens: " to position the number correctly
    local font = love.graphics.getFont()
    local text_width = font:getWidth(tokens_label) * 1.5 -- Match scale
    love.graphics.print(tokens, x + text_width, y, 0, 1.5, 1.5)
end

function UIComponents.drawWindow(x, y, w, h, title)
    -- Window background
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', x, y, w, h)
    
    -- Title bar
    love.graphics.setColor(0, 0, 0.5)
    love.graphics.rectangle('fill', x, y, w, 30)
    
    -- Title text
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(title, x + 10, y + 8, 0, 1.2, 1.2)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
end

-- Draw standard dialog buttons aligned to the right; returns rects for hit testing
function UIComponents.drawDialogButtons(w, h, applyEnabled)
    local bw, bh = 70, 24
    local spacing = 10
    local right_margin, bottom_margin = 16, 16
    local ok_x = w - right_margin - (bw*3 + spacing*2)
    local cancel_x = ok_x + bw + spacing
    local apply_x = cancel_x + bw + spacing
    local by = h - bottom_margin - bh
    local Strings_ = UIComponents._strings or Strings
    UIComponents.drawButton(ok_x, by, bw, bh, Strings_.get('buttons.ok','OK'), true, false)
    UIComponents.drawButton(cancel_x, by, bw, bh, Strings_.get('buttons.cancel','Cancel'), true, false)
    UIComponents.drawButton(apply_x, by, bw, bh, Strings_.get('buttons.apply','Apply'), applyEnabled ~= false, false)
    return {x=ok_x,y=by,w=bw,h=bh}, {x=cancel_x,y=by,w=bw,h=bh}, {x=apply_x,y=by,w=bw,h=bh}
end

function UIComponents.drawProgressBar(x, y, w, h, progress, bg_color, fill_color)
    bg_color = bg_color or {0.3, 0.3, 0.3}
    fill_color = fill_color or {0, 1, 0}
    
    -- Background
    love.graphics.setColor(bg_color)
    love.graphics.rectangle('fill', x, y, w, h)
    
    -- Fill
    love.graphics.setColor(fill_color)
    love.graphics.rectangle('fill', x, y, w * math.max(0, math.min(1, progress)), h)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
end

function UIComponents.drawPanel(x, y, w, h, bg_color)
    bg_color = bg_color or {0.2, 0.2, 0.2}
    
    -- Background
    love.graphics.setColor(bg_color)
    love.graphics.rectangle('fill', x, y, w, h)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
end

function UIComponents.drawBadge(x, y, size, text, bg_color, text_color)
    bg_color = bg_color or {1, 0, 0}
    text_color = text_color or {1, 1, 1}
    
    -- Background
    love.graphics.setColor(bg_color)
    love.graphics.rectangle('fill', x, y, size, size)
    
    -- Text
    love.graphics.setColor(text_color)
    local font = love.graphics.getFont()
    local text_width = font:getWidth(text) * 0.8
    love.graphics.print(text, x + (size - text_width) / 2, y + 2, 0, 0.8, 0.8)
end

-- Compute scrollbar geometry for a vertical scrollbar
-- params: {
--   viewport_w, viewport_h, content_h, offset,
--   width=10, margin_right=4, track_top=20, track_bottom=20, min_thumb_h=24,
--   alwaysVisible=false (show scrollbar even when content doesn't require scrolling)
-- }
function UIComponents.computeScrollbar(params)
    local Config_ = UIComponents._config or {}
    local S = (Config_.ui and Config_.ui.scrollbar) or {}
    local vw = params.viewport_w
    local vh = params.viewport_h
    local ch = params.content_h or vh
    local off = math.max(0, params.offset or 0)
    local sb_w = (params.width ~= nil) and params.width or (S.width or 10)
    local margin_r = (params.margin_right ~= nil) and params.margin_right or (S.margin_right or 2)
    local track_top = (params.track_top ~= nil) and params.track_top or (S.arrow_height or 12)
    local track_bottom = (params.track_bottom ~= nil) and params.track_bottom or (S.arrow_height or 12)
    local min_thumb_h = (params.min_thumb_h ~= nil) and params.min_thumb_h or (S.min_thumb_h or 20)
    local always_visible = params.alwaysVisible or false

    local max_offset = math.max(0, ch - vh)
    if max_offset <= 0 and not always_visible then return nil end -- No scrollbar needed

    local sb_x = vw - sb_w - margin_r
    local track_y = track_top
    local track_h = math.max(0, vh - (track_top + track_bottom))

    local ratio = vh / ch
    local thumb_h = math.max(min_thumb_h, track_h * ratio)
    -- Prevent division by zero when max_offset is 0 (always visible but no scroll)
    local thumb_y = track_y
    if max_offset > 0 then
        thumb_y = track_y + (track_h - thumb_h) * (off / max_offset)
    end

    return {
        -- Overall scrollbar bounds
        bounds = { x = sb_x, y = 0, w = sb_w, h = vh },
        track = { x = sb_x, y = track_y, w = sb_w, h = track_h },
        -- Hit rect for thumb matches prior behavior (full width)
        thumb = { x = sb_x, y = thumb_y, w = sb_w, h = thumb_h },
        -- Draw rect for thumb has 1px inset and 2px narrower fill like prior code
        thumb_draw = { x = sb_x + 1, y = thumb_y, w = sb_w - 2, h = thumb_h },
        arrow_up = (track_top > 0) and { x = sb_x, y = 0, w = sb_w, h = track_top } or nil,
        arrow_down = (track_bottom > 0) and { x = sb_x, y = vh - track_bottom, w = sb_w, h = track_bottom } or nil,
        max_offset = max_offset
    }
end

-- Draw scrollbar using geometry from computeScrollbar and optional theme colors
-- theme: { trackFill, trackBorder, thumbFill, thumbBorder }
function UIComponents.drawScrollbar(geom, theme)
    if not geom then return end
    theme = theme or {}
    local trackFill = theme.trackFill or {0.9, 0.9, 0.95}
    local trackBorder = theme.trackBorder or {0.6, 0.6, 0.7}
    local thumbFill = theme.thumbFill or {0.5, 0.5, 0.7}
    local thumbBorder = theme.thumbBorder or {0.2, 0.2, 0.4}

    -- Track
    love.graphics.setColor(trackFill)
    love.graphics.rectangle('fill', geom.track.x, geom.track.y, geom.track.w, geom.track.h)
    love.graphics.setColor(trackBorder)
    love.graphics.rectangle('line', geom.track.x, geom.track.y, geom.track.w, geom.track.h)

    -- Arrows (optional if provided by compute via track_top/bottom)
    if geom.arrow_up then
        love.graphics.setColor(trackFill)
        love.graphics.rectangle('fill', geom.arrow_up.x, geom.arrow_up.y, geom.arrow_up.w, geom.arrow_up.h)
        love.graphics.setColor(trackBorder)
        love.graphics.rectangle('line', geom.arrow_up.x, geom.arrow_up.y, geom.arrow_up.w, geom.arrow_up.h)
        -- Draw up triangle
        local cx = geom.arrow_up.x + geom.arrow_up.w/2
        local cy = geom.arrow_up.y + geom.arrow_up.h/2
        love.graphics.setColor(thumbBorder)
        love.graphics.polygon('fill', cx, cy-3, cx-4, cy+2, cx+4, cy+2)
    end
    if geom.arrow_down then
        love.graphics.setColor(trackFill)
        love.graphics.rectangle('fill', geom.arrow_down.x, geom.arrow_down.y, geom.arrow_down.w, geom.arrow_down.h)
        love.graphics.setColor(trackBorder)
        love.graphics.rectangle('line', geom.arrow_down.x, geom.arrow_down.y, geom.arrow_down.w, geom.arrow_down.h)
        -- Draw down triangle
        local cx = geom.arrow_down.x + geom.arrow_down.w/2
        local cy = geom.arrow_down.y + geom.arrow_down.h/2
        love.graphics.setColor(thumbBorder)
        love.graphics.polygon('fill', cx, cy+3, cx-4, cy-2, cx+4, cy-2)
    end

    -- Thumb
    love.graphics.setColor(thumbFill)
    love.graphics.rectangle('fill', geom.thumb_draw.x, geom.thumb_draw.y, geom.thumb_draw.w, geom.thumb_draw.h)
    love.graphics.setColor(thumbBorder)
    love.graphics.rectangle('line', geom.thumb_draw.x, geom.thumb_draw.y, geom.thumb_draw.w, geom.thumb_draw.h)
end

-- Compute new scroll offset from a drag gesture on the scrollbar thumb.
-- drag_start_y: screen Y when drag began
-- current_y: current screen Y during drag
-- offset_start: scroll offset when drag began
-- geom_like: { track_h, thumb_h, max_offset }
function UIComponents.scrollbarDragToOffset(drag_start_y, current_y, offset_start, geom_like)
    local track_h = geom_like.track_h or 0
    local thumb_h = geom_like.thumb_h or 0
    local max_offset = math.max(0, geom_like.max_offset or 0)
    local track_span = math.max(1, track_h - thumb_h)
    local dy_pixels = (current_y - drag_start_y)
    local ratio = dy_pixels / track_span
    local new_offset = (offset_start or 0) + (max_offset * ratio)
    if new_offset < 0 then new_offset = 0 end
    if new_offset > max_offset then new_offset = max_offset end
    return new_offset
end

-- Map a click on the track to a pixel offset (snap behavior).
-- click_y: Y in the same coordinate space as geom.track.y
-- Returns new_offset_px clamped to [0, max_offset]
function UIComponents.scrollbarClickToOffset(click_y, geom)
    local track_y = geom.track.y
    local track_h = geom.track.h
    local thumb_h = geom.thumb.h
    local max_offset = math.max(0, geom.max_offset or 0)
    if track_h <= 0 then return 0 end
    -- Position inside track [0..track_h]
    local rel = math.max(0, math.min(track_h, (click_y - track_y)))
    -- Align thumb center to click position
    local span = math.max(1, track_h - thumb_h)
    local ratio = math.max(0, math.min(1, (rel - thumb_h/2) / span))
    return ratio * max_offset
end

-- Step offset by a small pixel amount (e.g., arrows)
function UIComponents.scrollbarStepBy(offset_px, step_px, geom)
    local max_offset = math.max(0, geom.max_offset or 0)
    local new_off = (offset_px or 0) + (step_px or 0)
    if new_off < 0 then new_off = 0 end
    if new_off > max_offset then new_off = max_offset end
    return new_off
end

-- Universal interactive handlers for vertical scrollbar (local coordinates)
-- Usage contract:
-- - Pass mouse coords (lx, ly) in the SAME local space used when computing/drawing geom
-- - Maintain a per-scrollbar drag object in your view (store the returned drag from press)
-- - Convert between pixels and item indices in the view as needed
function UIComponents.scrollbarHandlePress(lx, ly, button, geom, offset_px, step_px)
    local Config_ = UIComponents._config or {}
    local S = (Config_.ui and Config_.ui.scrollbar) or {}
    local step = step_px or (S.arrow_step_px or 20)
    if button ~= 1 or not geom then return { consumed = false } end
    -- Hit arrow buttons first
    if geom.arrow_up and lx >= geom.arrow_up.x and lx <= geom.arrow_up.x + geom.arrow_up.w and ly >= geom.arrow_up.y and ly <= geom.arrow_up.y + geom.arrow_up.h then
        local new_px = UIComponents.scrollbarStepBy(offset_px or 0, -step, geom)
        return { consumed = true, new_offset_px = new_px }
    end
    if geom.arrow_down and lx >= geom.arrow_down.x and lx <= geom.arrow_down.x + geom.arrow_down.w and ly >= geom.arrow_down.y and ly <= geom.arrow_down.y + geom.arrow_down.h then
        local new_px = UIComponents.scrollbarStepBy(offset_px or 0, step, geom)
        return { consumed = true, new_offset_px = new_px }
    end
    -- Thumb drag start
    if lx >= geom.thumb.x and lx <= geom.thumb.x + geom.thumb.w and ly >= geom.thumb.y and ly <= geom.thumb.y + geom.thumb.h then
        return { consumed = true, drag = { start_y = ly, offset_start_px = offset_px or 0 } }
    end
    -- Track click snap + begin drag
    if lx >= geom.track.x and lx <= geom.track.x + geom.track.w and ly >= geom.track.y and ly <= geom.track.y + geom.track.h then
        local new_px = UIComponents.scrollbarClickToOffset(ly, geom)
        return { consumed = true, new_offset_px = new_px, drag = { start_y = ly, offset_start_px = new_px } }
    end
    return { consumed = false }
end

function UIComponents.scrollbarHandleMove(current_ly, drag, geom)
    if not drag or not geom then return { consumed = false } end
    local new_px = UIComponents.scrollbarDragToOffset(drag.start_y, current_ly, drag.offset_start_px, { track_h = geom.track.h, thumb_h = geom.thumb.h, max_offset = geom.max_offset })
    return { consumed = true, new_offset_px = new_px }
end

function UIComponents.scrollbarHandleRelease()
    return { consumed = true }
end

-- Helpers to expose config-driven sizes
function UIComponents.getScrollbarConfig()
    local Config_ = UIComponents._config or {}
    local S = (Config_.ui and Config_.ui.scrollbar) or {}
    return {
        width = S.width or 10,
        margin_right = S.margin_right or 2,
        arrow_height = S.arrow_height or 12,
        arrow_step_px = S.arrow_step_px or 20,
        min_thumb_h = S.min_thumb_h or 20,
    }
end

function UIComponents.getScrollbarLaneWidth()
    local s = UIComponents.getScrollbarConfig()
    return (s.width or 10) + (s.margin_right or 2)
end

return UIComponents