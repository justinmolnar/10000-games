-- src/controllers/text_input_controller.lua
-- Reusable text input controller with cursor, selection, and editing

local Object = require('lib.class')
local TextInputController = Object:extend('TextInputController')

function TextInputController:init(options)
    options = options or {}

    self.text = options.text or ""
    self.cursor = 0  -- Position between characters (0 = before first char)
    self.selection_start = nil  -- nil = no selection, otherwise start of selection

    -- Options
    self.unfocus_on_enter = options.unfocus_on_enter or false  -- Unfocus when Enter is pressed

    -- State
    self.focused = false
    self.cursor_blink_timer = 0
    self.first_click_since_focus = false  -- Track if next click should position cursor
    self.dragging = false  -- Track if we're click-dragging to select
    self.drag_start = nil  -- Cursor position where drag started

    -- Double-click detection
    self.last_click_time = 0
    self.double_click_threshold = 0.3  -- 300ms for double-click
end

-- Focus the input (does NOT select all - call selectAll separately if needed)
function TextInputController:focus()
    self.focused = true
    self.first_click_since_focus = false
    self.cursor_blink_timer = 0
end

-- Unfocus the input
function TextInputController:unfocus()
    self.focused = false
    self.selection_start = nil
    self.dragging = false
    self.drag_start = nil
    self.first_click_since_focus = false
end

-- Select all text
function TextInputController:selectAll()
    if #self.text > 0 then
        self.cursor = #self.text
        self.selection_start = 0
    else
        self.cursor = 0
        self.selection_start = nil
    end
    self.cursor_blink_timer = 0
end

-- Clear selection
function TextInputController:clearSelection()
    self.selection_start = nil
end

-- Get selected text
function TextInputController:getSelection()
    if not self.selection_start then
        return nil
    end

    local start = math.min(self.cursor, self.selection_start)
    local finish = math.max(self.cursor, self.selection_start)
    return self.text:sub(start + 1, finish), start, finish
end

-- Set text
function TextInputController:setText(text)
    self.text = text or ""

    -- Clamp cursor and selection to valid positions
    if #self.text == 0 then
        self.cursor = 0
        self.selection_start = nil
    else
        self.cursor = math.min(self.cursor, #self.text)
        if self.selection_start then
            self.selection_start = math.min(self.selection_start, #self.text)
        end
    end
end

-- Get cursor position from X coordinate (for click-to-position)
function TextInputController:getCursorFromX(x, text_start_x, font)
    -- Handle empty text
    if not self.text or self.text == "" then
        return 0
    end

    local click_x = x - text_start_x

    -- Check if clicked before text
    if click_x <= 0 then
        return 0
    end

    -- Check if clicked after text
    local total_width = font:getWidth(self.text)
    if click_x >= total_width then
        return #self.text
    end

    -- Find best position by checking width of each substring
    local best_pos = 0
    local best_dist = math.abs(click_x)

    for i = 1, #self.text do
        local substr = self.text:sub(1, i)
        local text_width = font:getWidth(substr)
        local dist = math.abs(click_x - text_width)

        if dist < best_dist then
            best_dist = dist
            best_pos = i
        end
    end

    return best_pos
end

-- Handle mouse press
-- Returns true if input handled the event
function TextInputController:mousepressed(x, y, button, bounds, font)
    if button ~= 1 then return false end

    local time = love.timer.getTime()
    local is_double_click = (time - self.last_click_time) < self.double_click_threshold
    self.last_click_time = time

    -- Check if clicked inside bounds
    local inside = x >= bounds.x and x <= bounds.x + bounds.width and
                   y >= bounds.y and y <= bounds.y + bounds.height

    if inside then
        local is_empty = (not self.text or self.text == "")

        -- Double-click: select all (regardless of focus state)
        if is_double_click then
            if not self.focused then
                self:focus()
            end
            if not is_empty then
                self:selectAll()
            else
                -- Empty text - just place cursor at start
                self.cursor = 0
                self:clearSelection()
            end
            self.first_click_since_focus = false
            return true
        end

        -- First click when unfocused
        if not self.focused then
            self:focus()
            if not is_empty then
                -- Select all if there's text
                self:selectAll()
                self.first_click_since_focus = true
            else
                -- Empty text - just place cursor at start
                self.cursor = 0
                self:clearSelection()
                self.first_click_since_focus = false  -- No need for second-click behavior
            end
            return true
        end

        -- Second click after focus (first_click_since_focus): position cursor
        if self.first_click_since_focus then
            self.first_click_since_focus = false
            local cursor_pos = self:getCursorFromX(x, bounds.x, font)
            self.cursor = cursor_pos
            self:clearSelection()
            self.cursor_blink_timer = 0

            -- Start drag from this position
            self.dragging = true
            self.drag_start = cursor_pos
            return true
        end

        -- Subsequent clicks: position cursor and start drag
        local cursor_pos = self:getCursorFromX(x, bounds.x, font)
        self.cursor = cursor_pos
        self:clearSelection()
        self.cursor_blink_timer = 0

        self.dragging = true
        self.drag_start = cursor_pos
        return true
    else
        -- Clicked outside: unfocus
        self:unfocus()
        return false
    end
end

-- Handle mouse move (for drag selection)
-- Can be called even when mouse is outside bounds
function TextInputController:mousemoved(x, y, dx, dy, bounds, font)
    if not self.dragging or not self.focused then
        return false
    end

    -- Update cursor position based on mouse X
    local cursor_pos = self:getCursorFromX(x, bounds.x, font)

    -- If cursor moved, create/update selection
    if cursor_pos ~= self.drag_start then
        self.cursor = cursor_pos
        self.selection_start = self.drag_start
        self.cursor_blink_timer = 0
    else
        -- Cursor at drag start - no selection
        self.cursor = cursor_pos
        self:clearSelection()
    end

    return true
end

-- Handle mouse release (stops dragging)
function TextInputController:mousereleased(x, y, button)
    if button == 1 and self.dragging then
        self.dragging = false
        self.drag_start = nil
        return true
    end
    return false
end

-- Update (for cursor blink)
function TextInputController:update(dt)
    if self.focused then
        self.cursor_blink_timer = self.cursor_blink_timer + dt
        if self.cursor_blink_timer > 1.0 then
            self.cursor_blink_timer = 0
        end
    end
end

-- Handle key press
-- Returns: false if not handled, true if handled, or {enter = true} if enter was pressed
function TextInputController:keypressed(key)
    if not self.focused then return false end

    if key == "return" or key == "kpenter" then
        -- Return special signal for enter
        if self.unfocus_on_enter then
            self:unfocus()
        end
        return {enter = true}
    end

    if key == "backspace" then
        if self.selection_start then
            -- Delete selection
            local start = math.min(self.cursor, self.selection_start)
            local finish = math.max(self.cursor, self.selection_start)
            self.text = self.text:sub(1, start) .. self.text:sub(finish + 1)
            self.cursor = start
            self:clearSelection()
        elseif self.cursor > 0 then
            -- Delete character before cursor
            self.text = self.text:sub(1, self.cursor - 1) .. self.text:sub(self.cursor + 1)
            self.cursor = self.cursor - 1
        end
        self.cursor_blink_timer = 0
        return true

    elseif key == "delete" then
        if self.selection_start then
            -- Delete selection
            local start = math.min(self.cursor, self.selection_start)
            local finish = math.max(self.cursor, self.selection_start)
            self.text = self.text:sub(1, start) .. self.text:sub(finish + 1)
            self.cursor = start
            self:clearSelection()
        elseif self.cursor < #self.text then
            -- Delete character after cursor
            self.text = self.text:sub(1, self.cursor) .. self.text:sub(self.cursor + 2)
        end
        self.cursor_blink_timer = 0
        return true

    elseif key == "left" then
        if self.cursor > 0 then
            self.cursor = self.cursor - 1
        end
        self:clearSelection()
        self.cursor_blink_timer = 0
        return true

    elseif key == "right" then
        if self.cursor < #self.text then
            self.cursor = self.cursor + 1
        end
        self:clearSelection()
        self.cursor_blink_timer = 0
        return true

    elseif key == "home" then
        self.cursor = 0
        self:clearSelection()
        self.cursor_blink_timer = 0
        return true

    elseif key == "end" then
        self.cursor = #self.text
        self:clearSelection()
        self.cursor_blink_timer = 0
        return true

    elseif key == "a" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        -- Ctrl+A: Select all
        self:selectAll()
        return true
    end

    return false
end

-- Handle text input
function TextInputController:textinput(text)
    if not self.focused then return false end

    -- If there's a selection, replace it
    if self.selection_start then
        local start = math.min(self.cursor, self.selection_start)
        local finish = math.max(self.cursor, self.selection_start)
        self.text = self.text:sub(1, start) .. text .. self.text:sub(finish + 1)
        self.cursor = start + #text
        self:clearSelection()
    else
        -- Insert at cursor
        self.text = self.text:sub(1, self.cursor) .. text .. self.text:sub(self.cursor + 1)
        self.cursor = self.cursor + #text
    end

    self.cursor_blink_timer = 0
    return true
end

return TextInputController
