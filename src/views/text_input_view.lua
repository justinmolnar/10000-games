-- src/views/text_input_view.lua
-- Reusable text input view component

local TextInputView = {}

-- Draw text input
-- controller: TextInputController instance
-- x, y, width, height: Bounds for the input (viewport-relative)
-- style: Optional style table with colors/fonts
-- viewport: Optional {x, y} for screen coordinate conversion (for scissor)
function TextInputView.draw(controller, x, y, width, height, style, viewport)
    local g = love.graphics
    style = style or {}

    -- Default colors
    local bg_color = style.bg_color or {1, 1, 1}
    local bg_focused_color = style.bg_focused_color or {1, 1, 0.9}
    local border_color = style.border_color or {0.5, 0.5, 0.5}
    local border_focused_color = style.border_focused_color or {0.0, 0.0, 0.8}
    local text_color = style.text_color or {0, 0, 0}
    local selection_color = style.selection_color or {0.3, 0.5, 1.0}
    local cursor_color = style.cursor_color or {0, 0, 0}

    local font = g.getFont()
    local padding_x = style.padding_x or 5
    local padding_y = style.padding_y or math.floor((height - font:getHeight()) / 2)

    -- Background
    if controller.focused then
        g.setColor(bg_focused_color)
    else
        g.setColor(bg_color)
    end
    g.rectangle('fill', x, y, width, height)

    -- Border
    if controller.focused then
        g.setColor(border_focused_color)
        if style.focused_border_width then
            g.setLineWidth(style.focused_border_width)
        end
    else
        g.setColor(border_color)
    end
    g.rectangle('line', x, y, width, height)
    if style.focused_border_width then
        g.setLineWidth(1)  -- Reset
    end

    -- Set scissor to clip text to input bounds (SCREEN COORDINATES)
    local text_x = x + padding_x
    local text_y = y + padding_y
    local text_width = width - padding_x * 2

    -- Convert to screen coordinates for scissor
    local screen_x = x
    local screen_y = y
    if viewport then
        screen_x = viewport.x + x
        screen_y = viewport.y + y
    end

    g.setScissor(screen_x, screen_y, width, height)

    -- Calculate text offset for scrolling (if text is wider than input)
    local full_text_width = font:getWidth(controller.text)
    local cursor_text = controller.text:sub(1, controller.cursor)
    local cursor_x_in_text = font:getWidth(cursor_text)

    local text_offset = 0
    if cursor_x_in_text > text_width then
        -- Scroll text left so cursor is visible
        text_offset = -(cursor_x_in_text - text_width + 10)
    end

    -- Draw selection (if any)
    if controller.focused and controller.selection_start then
        local start = math.min(controller.cursor, controller.selection_start)
        local finish = math.max(controller.cursor, controller.selection_start)

        local pre_text = controller.text:sub(1, start)
        local sel_text = controller.text:sub(start + 1, finish)

        local pre_width = font:getWidth(pre_text)
        local sel_width = font:getWidth(sel_text)

        g.setColor(selection_color)
        g.rectangle('fill', text_x + text_offset + pre_width, text_y, sel_width, font:getHeight())
    end

    -- Draw cursor (if focused and blinking, and no selection)
    if controller.focused and not controller.selection_start then
        if controller.cursor_blink_timer < 0.5 then
            local pre_text = controller.text:sub(1, controller.cursor)
            local cursor_x = text_x + text_offset + font:getWidth(pre_text)

            g.setColor(cursor_color)
            g.rectangle('fill', cursor_x, text_y, 1, font:getHeight())
        end
    end

    -- Draw text
    g.setColor(text_color)
    g.print(controller.text, text_x + text_offset, text_y)

    -- Clear scissor
    g.setScissor()
end

return TextInputView
