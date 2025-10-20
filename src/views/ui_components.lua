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

return UIComponents