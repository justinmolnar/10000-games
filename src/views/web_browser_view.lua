-- src/views/web_browser_view.lua
-- Web browser view - toolbar, address bar, content rendering

local Object = require('lib.class')
local UIComponents = require('src.views.ui_components')
local HTMLRenderer = require('src.utils.html_renderer')
local SyntaxHighlighter = require('src.utils.syntax_highlighter')
local TextInputView = require('src.views.text_input_view')

local WebBrowserView = Object:extend('WebBrowserView')

function WebBrowserView:init(controller, di)
    self.controller = controller
    self.di = di

    -- Layout constants
    self.toolbar_height = 35
    self.address_bar_height = 25
    self.button_size = 25
    self.button_padding = 5

    -- Hover state
    self.hovered_button = nil

    -- HTML renderer
    self.html_renderer = HTMLRenderer:new()
end

-- Update (hover detection)
function WebBrowserView:update(dt, viewport_width, viewport_height)
    local mx, my = love.mouse.getPosition()
    local view_x = self.controller.viewport and self.controller.viewport.x or 0
    local view_y = self.controller.viewport and self.controller.viewport.y or 0
    local local_mx = mx - view_x
    local local_my = my - view_y

    self.hovered_button = nil

    -- Check if mouse is within viewport
    if local_mx < 0 or local_mx > viewport_width or local_my < 0 or local_my > viewport_height then
        return
    end

    -- Check toolbar buttons
    self.hovered_button = self:getButtonAtPosition(local_mx, local_my)

    -- Check for link hover (only in normal mode)
    if not self.controller.view_source_mode and self.controller.current_layout then
        local content_y = self.toolbar_height + self.address_bar_height
        local content_local_y = local_my - content_y

        local link = self.html_renderer:getLinkAtPosition(
            self.controller.current_layout,
            local_mx,
            content_local_y,
            self.controller.scroll_y
        )

        self.html_renderer:setHoveredLink(link)

        -- Cursor is managed by WebBrowserState:getCursorType(), not here
    end
end

-- Draw windowed view
function WebBrowserView:drawWindowed(current_url, current_html, current_layout, view_source_mode, scroll_y, max_scroll, can_go_back, can_go_forward, viewport_width, viewport_height, image_load_progress)
    local g = love.graphics

    -- Background
    g.setColor(1, 1, 1)
    g.rectangle('fill', 0, 0, viewport_width, viewport_height)

    -- Toolbar
    self:drawToolbar(0, 0, viewport_width, can_go_back, can_go_forward, view_source_mode)

    -- Address bar
    self:drawAddressBar(0, self.toolbar_height, viewport_width, current_url)

    -- Content area
    local content_y = self.toolbar_height + self.address_bar_height
    local content_height = viewport_height - content_y

    if view_source_mode then
        self:drawSourceView(0, content_y, viewport_width, content_height, current_html, scroll_y)
    else
        self:drawHTMLContent(0, content_y, viewport_width, content_height, current_layout, scroll_y, image_load_progress)
    end

    -- Scrollbar (always visible)
    local doc_height = content_height + max_scroll
    local scrollbar = self.controller.scrollbar

    if scrollbar then
        scrollbar:setPosition(0, content_y)
        local geom = scrollbar:compute(viewport_width, content_height, doc_height, scroll_y, max_scroll)

        if geom then
            love.graphics.push()
            love.graphics.translate(0, content_y)
            UIComponents.drawScrollbar(geom)
            love.graphics.pop()
        end
    end
end

-- Draw toolbar
function WebBrowserView:drawToolbar(x, y, width, can_go_back, can_go_forward, view_source_mode)
    local g = love.graphics

    -- Toolbar background
    g.setColor(0.9, 0.9, 0.9)
    g.rectangle('fill', x, y, width, self.toolbar_height)

    -- Separator line
    g.setColor(0.7, 0.7, 0.7)
    g.line(x, y + self.toolbar_height, x + width, y + self.toolbar_height)

    local btn_x = x + self.button_padding
    local btn_y = y + self.button_padding

    -- Back button
    self:drawButton(btn_x, btn_y, self.button_size, self.button_size, "<", can_go_back, self.hovered_button == "back")
    btn_x = btn_x + self.button_size + self.button_padding

    -- Forward button
    self:drawButton(btn_x, btn_y, self.button_size, self.button_size, ">", can_go_forward, self.hovered_button == "forward")
    btn_x = btn_x + self.button_size + self.button_padding

    -- Refresh button
    self:drawButton(btn_x, btn_y, self.button_size, self.button_size, "R", true, self.hovered_button == "refresh")
    btn_x = btn_x + self.button_size + self.button_padding * 2

    -- View Source button
    local vs_label = view_source_mode and "HTML" or "SRC"
    self:drawButton(btn_x, btn_y, self.button_size * 2, self.button_size, vs_label, true, self.hovered_button == "view_source")
end

-- Draw button
function WebBrowserView:drawButton(x, y, w, h, label, enabled, hovered)
    local g = love.graphics

    -- Button background
    if enabled then
        if hovered then
            g.setColor(0.8, 0.8, 1.0)
        else
            g.setColor(0.95, 0.95, 0.95)
        end
    else
        g.setColor(0.85, 0.85, 0.85)
    end
    g.rectangle('fill', x, y, w, h)

    -- Button border
    g.setColor(0.5, 0.5, 0.5)
    g.rectangle('line', x, y, w, h)

    -- Button label
    if enabled then
        g.setColor(0, 0, 0)
    else
        g.setColor(0.5, 0.5, 0.5)
    end

    local font = g.getFont()
    local text_width = font:getWidth(label)
    local text_height = font:getHeight()
    g.print(label, x + (w - text_width) / 2, y + (h - text_height) / 2)
end

-- Draw address bar
function WebBrowserView:drawAddressBar(x, y, width, current_url)
    -- Use TextInputView component to draw the address bar
    local viewport = self.controller.viewport
    TextInputView.draw(
        self.controller.address_bar,
        x + 5,
        y + 2,
        width - 10,
        self.address_bar_height - 4,
        {
            bg_color = {1, 1, 1},
            bg_focused_color = {1, 1, 0.9},
            border_color = {0.5, 0.5, 0.5},
            border_focused_color = {0.0, 0.0, 0.8},
            focused_border_width = 2,
            padding_x = 5,
            padding_y = 3
        },
        viewport  -- Pass viewport for screen coordinate conversion
    )
end

-- Draw HTML content
function WebBrowserView:drawHTMLContent(x, y, width, height, layout, scroll_y, image_load_progress)
    if not layout then
        return
    end

    local g = love.graphics
    local viewport = self.controller.viewport

    -- Set scissor for content area (SCREEN COORDINATES)
    local screen_x = viewport.x + x
    local screen_y = viewport.y + y
    g.setScissor(screen_x, screen_y, width, height)

    -- Render HTML
    g.push()
    g.translate(x, y)

    -- Pass loaded elements for progressive rendering
    -- nil = loading complete (render everything)
    -- table = loading in progress (only render loaded elements)
    local loaded_elements = nil
    if not self.controller.loading_complete then
        loaded_elements = self.controller.loaded_elements
    end
    self.html_renderer:render(layout, scroll_y, screen_x, screen_y, width, height, loaded_elements, image_load_progress)

    g.pop()

    -- Clear scissor
    g.setScissor()
end

-- Draw source view
function WebBrowserView:drawSourceView(x, y, width, height, html, scroll_y)
    if not html then
        return
    end

    local g = love.graphics
    local viewport = self.controller.viewport

    -- Background
    g.setColor(0.95, 0.95, 0.95)
    g.rectangle('fill', x, y, width, height)

    -- Set scissor for content area (SCREEN COORDINATES)
    local screen_x = viewport.x + x
    local screen_y = viewport.y + y
    g.setScissor(screen_x, screen_y, width, height)

    -- Draw source text with syntax highlighting
    g.push()
    g.translate(x + 10, y + 10 - scroll_y)

    local font = g.getFont()
    local line_height = font:getHeight() * 1.2

    -- Highlight HTML and cache result
    if not self.highlighted_source or self.highlighted_source_html ~= html then
        self.highlighted_source = SyntaxHighlighter.highlightHTML(html)
        self.highlighted_source_html = html
    end

    -- Draw each line with colored segments
    for line_num, segments in ipairs(self.highlighted_source) do
        local x_offset = 0

        for _, segment in ipairs(segments) do
            g.setColor(segment.color)
            g.print(segment.text, x_offset, (line_num - 1) * line_height)
            x_offset = x_offset + font:getWidth(segment.text)
        end
    end

    g.pop()

    -- Clear scissor
    g.setScissor()
end

-- Get button at position
function WebBrowserView:getButtonAtPosition(mx, my)
    if my < 0 or my > self.toolbar_height then
        return nil
    end

    local btn_x = self.button_padding
    local btn_y = self.button_padding

    -- Back button
    if mx >= btn_x and mx <= btn_x + self.button_size and my >= btn_y and my <= btn_y + self.button_size then
        return "back"
    end
    btn_x = btn_x + self.button_size + self.button_padding

    -- Forward button
    if mx >= btn_x and mx <= btn_x + self.button_size and my >= btn_y and my <= btn_y + self.button_size then
        return "forward"
    end
    btn_x = btn_x + self.button_size + self.button_padding

    -- Refresh button
    if mx >= btn_x and mx <= btn_x + self.button_size and my >= btn_y and my <= btn_y + self.button_size then
        return "refresh"
    end
    btn_x = btn_x + self.button_size + self.button_padding * 2

    -- View Source button
    if mx >= btn_x and mx <= btn_x + self.button_size * 2 and my >= btn_y and my <= btn_y + self.button_size then
        return "view_source"
    end

    return nil
end

return WebBrowserView
