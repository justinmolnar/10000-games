-- src/states/web_browser_state.lua
-- Web browser state - navigation, history, HTML rendering

local Object = require('lib.class')
local WebBrowserView = require('src.views.web_browser_view')
local HTMLParser = require('src.utils.html_parser')
local CSSParser = require('src.utils.css_parser')
local HTMLLayout = require('src.utils.html_layout')
local HTMLRenderer = require('src.utils.html_renderer')
local ScrollbarController = require('src.controllers.scrollbar_controller')
local URLResolver = require('src.utils.url_resolver')
local TextInputController = require('src.controllers.text_input_controller')

local WebBrowserState = Object:extend('WebBrowserState')

function WebBrowserState:init(file_system, di)
    self.file_system = file_system
    self.di = di

    self.view = WebBrowserView:new(self, di)

    -- Create scrollbar controller (unit_size = 1 pixel)
    self.scrollbar = ScrollbarController:new({
        unit_size = 1,
        step_units = 30,
        always_visible = true
    })

    -- Homepage setting (can be changed by user or game progression)
    self.homepage = "www.home.com"

    -- Current state
    self.current_url = nil
    self.current_html = nil
    self.current_dom = nil
    self.current_layout = nil
    self.stylesheet_rules = {}

    -- Navigation history
    self.history = {}
    self.history_index = 0

    -- View mode
    self.view_source_mode = false

    -- Scroll state
    self.scroll_y = 0
    self.max_scroll = 0

    -- Viewport
    self.viewport = nil

    -- Window context
    self.window_id = nil
    self.window_manager = nil

    -- Parser/layout/renderer
    self.html_parser = HTMLParser:new()
    self.css_parser = CSSParser:new()
    self.html_layout = HTMLLayout:new()
    self.html_renderer = HTMLRenderer:new()

    -- Address bar (text input) - unfocus after pressing Enter
    self.address_bar = TextInputController:new({
        unfocus_on_enter = true
    })

    -- Progressive loading state
    self.loading_queue = {}        -- Elements to load in order
    self.loading_index = 0         -- Current element being loaded
    self.loading_timer = 0         -- Time accumulator for current element
    self.loading_complete = true   -- Is page fully loaded?
    self.loaded_elements = {}      -- Set of loaded element IDs
    self.image_load_progress = {}  -- Scanline progress for images: [node] = scanlines_loaded

    -- Leaf elements definition (used during loading)
    self.leaf_elements = {
        p = true, h1 = true, h2 = true, h3 = true, h4 = true, h5 = true, h6 = true,
        li = true, tr = true, td = true, th = true, hr = true, img = true, a = true
    }
end

-- Set window context
function WebBrowserState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

-- Set viewport
function WebBrowserState:setViewport(x, y, width, height)
    local old_width = self.viewport and self.viewport.width or nil
    self.viewport = {x = x, y = y, width = width, height = height}

    -- Re-layout only if width changed (height changes only affect scrolling)
    if self.current_dom and old_width ~= width then
        self:relayout()
    elseif self.viewport then
        -- Width didn't change, but height might have - update max scroll
        self:updateMaxScroll()
    end
end

-- Enter state with initial URL
function WebBrowserState:enter(initial_url)
    -- If no initial URL, use homepage
    if not initial_url then
        initial_url = self.homepage
    end

    self.current_url = initial_url
    self.address_bar:setText(self.current_url)
    self:navigateTo(self.current_url, false)  -- Add to history so back button works
    self:updateTitle()
end

-- Set homepage
function WebBrowserState:setHomepage(url)
    self.homepage = url
end

-- Get homepage
function WebBrowserState:getHomepage()
    return self.homepage
end

-- Navigate to homepage
function WebBrowserState:goHome()
    self:navigateTo(self.homepage, false)
end

-- Navigate to URL
function WebBrowserState:navigateTo(url, skip_history)
    -- Resolve URL to filesystem path
    local filesystem_path = URLResolver.resolve(url, self.current_url)

    if not filesystem_path then
        -- Ensure we show a clean URL in error page
        local display_url = URLResolver.getDisplayURL(url) or url
        self:showErrorPage(display_url, "Invalid URL")
        return
    end

    -- Load HTML file
    local success, html = pcall(love.filesystem.read, filesystem_path)

    if not success or not html then
        -- Show error page with clean URL (convert filesystem path back to display URL)
        local display_url = URLResolver.getDisplayURL(filesystem_path) or url
        self:showErrorPage(display_url, "File not found")
        return
    end

    -- Parse HTML
    local parse_success, dom = pcall(self.html_parser.parse, self.html_parser, html)
    if not parse_success then
        self:showErrorPage(url, "Parse error: " .. tostring(dom))
        return
    end

    -- Store current state BEFORE extracting stylesheets (stylesheet loading needs current_filesystem_path)
    self.current_url = url
    self.current_filesystem_path = filesystem_path
    self.current_html = html
    self.current_dom = dom

    -- Extract stylesheet rules from <style> and <link> tags
    self.stylesheet_rules = self:extractStylesheets(dom)
    self.view_source_mode = false
    self.scroll_y = 0

    -- Update address bar and unfocus it
    self.address_bar:setText(url)
    self.address_bar:unfocus()

    -- Layout
    self:relayout()

    -- Build loading queue for progressive rendering
    self:buildLoadingQueue()

    -- Add to history
    if not skip_history then
        -- Remove forward history if we're not at the end
        while #self.history > self.history_index do
            table.remove(self.history)
        end

        table.insert(self.history, url)
        self.history_index = #self.history
    end

    self:updateTitle()
end

-- Show blank page
function WebBrowserState:showBlankPage()
    local blank_html = [[
<html>
<head><title>about:blank</title></head>
<body style="margin: 0; background-color: white;">
</body>
</html>
]]

    self.current_url = "about:blank"
    self.current_html = blank_html
    self.current_dom = self.html_parser:parse(blank_html)
    self.stylesheet_rules = {}
    self.view_source_mode = false
    self.scroll_y = 0

    self:relayout()
end

-- Show error page
function WebBrowserState:showErrorPage(url, error_msg)
    error_msg = error_msg or "File not found"

    local error_html = [[
<html>
<head><title>Error</title></head>
<body style="margin: 20px; font-family: Arial;">
    <h1 style="color: red;">404 Not Found</h1>
    <p>The requested page could not be loaded:</p>
    <p><b>]] .. url .. [[</b></p>
    <p style="color: gray;">]] .. error_msg .. [[</p>
    <hr>
    <p><a href="]] .. self.homepage .. [[">Go to homepage</a></p>
</body>
</html>
]]

    self.current_url = url
    self.current_html = error_html
    self.current_dom = self.html_parser:parse(error_html)
    self.stylesheet_rules = {}
    self.view_source_mode = false
    self.scroll_y = 0

    self:relayout()
    self:updateTitle()
end

-- Load external CSS file referenced in <link> tag
function WebBrowserState:loadExternalCSS(href)
    if not href or href == "" then
        return nil
    end

    -- Resolve CSS file path relative to current page
    local URLResolver = require('src.utils.url_resolver')
    local css_path = URLResolver.resolve(href, self.current_filesystem_path)

    if not css_path then
        print("Failed to resolve CSS path: " .. href)
        return nil
    end

    -- Load CSS file from filesystem
    local success, content = pcall(love.filesystem.read, css_path)
    if not success or not content then
        print("Failed to load CSS file: " .. css_path)
        return nil
    end

    return content
end

-- Extract stylesheets from <style> and <link> tags
function WebBrowserState:extractStylesheets(dom)
    local rules = {}
    self:findStyleTags(dom, rules)
    return rules
end

-- Recursively find <style> and <link> tags
function WebBrowserState:findStyleTags(node, rules)
    if not node then return end

    -- Handle <style> tags (inline CSS)
    if node.tag == "style" and node.children then
        -- Extract text content from style tag
        local css_text = ""
        for _, child in ipairs(node.children) do
            if child.type == "text" then
                css_text = css_text .. child.content
            end
        end

        -- Parse stylesheet
        if css_text ~= "" then
            local stylesheet = self.css_parser:parseStylesheet(css_text)
            for _, rule in ipairs(stylesheet) do
                table.insert(rules, rule)
            end
        end
    end

    -- Handle <link rel="stylesheet" href="..."> tags (external CSS)
    if node.tag == "link" and node.attributes then
        local rel = node.attributes.rel
        local href = node.attributes.href

        if rel and rel:lower() == "stylesheet" and href then
            -- Load external CSS file
            local css_content = self:loadExternalCSS(href)
            if css_content then
                local stylesheet = self.css_parser:parseStylesheet(css_content)
                for _, rule in ipairs(stylesheet) do
                    table.insert(rules, rule)
                end
            end
        end
    end

    if node.children then
        for _, child in ipairs(node.children) do
            self:findStyleTags(child, rules)
        end
    end
end

-- Re-layout content (on resize or load)
function WebBrowserState:relayout()
    if not self.current_dom or not self.viewport then
        return
    end

    -- Calculate available content width (always reserve space for scrollbar)
    local scrollbar_width = 15
    local content_width = self.viewport.width - scrollbar_width

    self.current_layout = self.html_layout:layout(self.current_dom, content_width, self.stylesheet_rules)

    -- Calculate max scroll based on view mode
    self:updateMaxScroll()
end

-- Update max scroll based on current view mode
function WebBrowserState:updateMaxScroll()
    if not self.viewport then
        self.max_scroll = 0
        return
    end

    local toolbar_height = 60 -- Toolbar + address bar
    local viewport_height = self.viewport.height - toolbar_height

    if self.view_source_mode then
        -- Source view mode: Calculate height based on number of source lines
        if self.current_html then
            local font = love.graphics.getFont()
            local line_height = font:getHeight() * 1.2

            -- Count lines in source
            local line_count = 1
            for _ in self.current_html:gmatch('\n') do
                line_count = line_count + 1
            end

            local source_height = line_count * line_height + 20 -- 20px padding
            self.max_scroll = math.max(0, source_height - viewport_height)
        else
            self.max_scroll = 0
        end
    else
        -- Normal view mode: Use rendered HTML height
        if self.current_layout then
            local doc_height = self.html_renderer:getDocumentHeight(self.current_layout)
            self.max_scroll = math.max(0, doc_height - viewport_height)
        else
            self.max_scroll = 0
        end
    end
end

-- Build loading queue from layout tree (top-to-bottom order)
function WebBrowserState:buildLoadingQueue()
    self.loading_queue = {}
    self.loading_index = 0
    self.loading_timer = 0
    self.loading_complete = false
    self.loaded_elements = {}
    self.image_load_progress = {}

    if not self.current_layout then
        self.loading_complete = true
        return
    end

    -- Container elements that should contain other loadable elements
    local container_elements = {
        body = true, div = true, ul = true, ol = true, table = true
    }

    -- Use instance leaf_elements (defined in init)
    local leaf_elements = self.leaf_elements

    -- Recursively collect loadable elements
    local function collectElements(node)
        if not node or not node.element then return end

        local tag = node.element.tag

        -- If this is a leaf element, add it and stop recursing
        if tag and leaf_elements[tag] then
            table.insert(self.loading_queue, node)
            return
        end

        -- If this is a container, recurse into children but don't add the container itself
        if tag and container_elements[tag] then
            if node.children then
                for _, child in ipairs(node.children) do
                    collectElements(child)
                end
            end
            return
        end

        -- For other elements (head, html, text nodes, etc.), keep recursing
        if node.children then
            for _, child in ipairs(node.children) do
                collectElements(child)
            end
        end
    end

    collectElements(self.current_layout)

    -- Mark all container elements as loaded immediately (they're just structure, not content)
    local function markContainers(node)
        if not node or not node.element then return end
        local tag = node.element.tag
        if tag and container_elements[tag] then
            self.loaded_elements[node] = true
        end
        if node.children then
            for _, child in ipairs(node.children) do
                markContainers(child)
            end
        end
    end
    markContainers(self.current_layout)
end

-- Toggle view source
function WebBrowserState:toggleViewSource()
    self.view_source_mode = not self.view_source_mode
    self.scroll_y = 0

    -- Clear syntax highlighting cache in view
    if self.view then
        self.view.highlighted_source = nil
        self.view.highlighted_source_html = nil
    end

    -- Recalculate max scroll for new view mode
    self:updateMaxScroll()

    self:updateTitle()
end

-- Go back in history
function WebBrowserState:goBack()
    if not self:canGoBack() then
        return
    end

    self.history_index = self.history_index - 1
    local url = self.history[self.history_index]
    self:navigateTo(url, true)
end

-- Go forward in history
function WebBrowserState:goForward()
    if not self:canGoForward() then
        return
    end

    self.history_index = self.history_index + 1
    local url = self.history[self.history_index]
    self:navigateTo(url, true)
end

-- Can go back?
function WebBrowserState:canGoBack()
    return self.history_index > 1
end

-- Can go forward?
function WebBrowserState:canGoForward()
    return self.history_index < #self.history
end

-- Refresh page
function WebBrowserState:refresh()
    if self.current_url then
        self:navigateTo(self.current_url, true)
    end
end

-- Handle link click
function WebBrowserState:handleLinkClick(href)
    if not href then
        return
    end

    -- Check if it's an anchor link (starts with #)
    if href:sub(1, 1) == "#" then
        -- Scroll to top for #top or any anchor
        self.scroll_y = 0
        return
    end

    -- Mark link as visited
    self.html_renderer:markLinkVisited(href)

    -- Resolve the href to a proper URL (not filesystem path)
    -- For relative links like "products.html", resolve against current URL
    local parsed = URLResolver.parseURL(href)
    local url = href

    if parsed and parsed.type == "relative" then
        -- Relative link - need to construct full URL
        -- Get current domain from current_url
        local current_parsed = URLResolver.parseURL(self.current_url)

        if current_parsed and current_parsed.domain then
            -- Build full URL with current domain
            local current_dir = current_parsed.path:match("(.*/)")
            if current_dir then
                url = current_parsed.domain .. current_dir .. href
            else
                url = current_parsed.domain .. "/" .. href
            end
        else
            -- No current domain (e.g., on about:blank) - use default domain
            url = URLResolver.default_domain .. "/" .. href
        end
    end

    -- Navigate (navigateTo will resolve URL to filesystem path)
    self:navigateTo(url, false)
end

-- Resolve relative URL
function WebBrowserState:resolveURL(href)
    -- Use URLResolver for proper URL resolution
    return URLResolver.resolve(href, self.current_url)
end

-- Update window title
function WebBrowserState:updateTitle()
    if self.window_manager and self.window_id then
        local page_title = self:extractPageTitle() or "Untitled"
        local title = page_title .. " - Browser"

        if self.view_source_mode then
            title = "View Source: " .. page_title .. " - Browser"
        end

        self.window_manager:updateWindowTitle(self.window_id, title)
    end
end

-- Extract <title> from DOM
function WebBrowserState:extractPageTitle()
    if not self.current_dom then
        return nil
    end

    local title_text = self:findTitleTag(self.current_dom)
    return title_text
end

-- Recursively find <title> tag
function WebBrowserState:findTitleTag(node)
    if not node then return nil end

    if node.tag == "title" and node.children then
        -- Extract text from title tag
        for _, child in ipairs(node.children) do
            if child.type == "text" then
                return child.content:match("^%s*(.-)%s*$") -- trim
            end
        end
    end

    if node.children then
        for _, child in ipairs(node.children) do
            local title = self:findTitleTag(child)
            if title then
                return title
            end
        end
    end

    return nil
end

-- Update
function WebBrowserState:update(dt)
    if not self.viewport then return end

    -- Update address bar (cursor blink, etc.)
    self.address_bar:update(dt)

    -- Update animated GIFs
    if self.current_layout then
        self.html_renderer:update(dt, self.current_layout)
    end

    -- Progressive loading
    if not self.loading_complete then
        self:updateLoading(dt)
    end

    self.view:update(dt, self.viewport.width, self.viewport.height)
end

-- Process progressive loading
function WebBrowserState:updateLoading(dt)
    if self.loading_complete or self.loading_index >= #self.loading_queue then
        self.loading_complete = true
        return
    end

    -- Get CPU speed from player data
    local cpu_speed = 1.0
    if self.di and self.di.playerData then
        cpu_speed = self.di.playerData:getCPUSpeed()
    end

    -- Get current element
    local current_element = self.loading_queue[self.loading_index + 1]
    if not current_element then
        self.loading_complete = true
        return
    end

    local is_image = current_element.element and current_element.element.tag == "img"

    if is_image and (current_element.image or current_element.gif_data) then
        -- Image scanline loading
        local image_height = current_element.image_height or current_element.content_height or 0

        -- Initialize progress if first time
        if not self.image_load_progress[current_element] then
            self.image_load_progress[current_element] = 0
        end

        -- Scanline speed based on CPU
        local config = self.di and self.di.config or require('src.config')
        local scanline_speed = (config.cpu and config.cpu.page_load and config.cpu.page_load.image_scanline_height) or 3
        local scanlines_per_frame = math.max(1, math.floor(scanline_speed * cpu_speed))

        -- Increment scanline progress
        self.image_load_progress[current_element] = self.image_load_progress[current_element] + scanlines_per_frame

        -- Check if image fully loaded
        if self.image_load_progress[current_element] >= image_height then
            -- Mark as fully loaded
            self.loaded_elements[current_element] = true

            -- Move to next element
            self.loading_index = self.loading_index + 1
            self.loading_timer = 0

            -- Check if done
            if self.loading_index >= #self.loading_queue then
                self.loading_complete = true
            end
        else
            -- Image still loading - show in progress
            self.loaded_elements[current_element] = true  -- Mark as visible (partial render)
        end

    else
        -- Non-image element: time-based loading
        self.loading_timer = self.loading_timer + (dt * 1000) -- Convert to ms

        -- Calculate load time for this element
        local load_time = self:calculateLoadTime(current_element, cpu_speed)

        -- Check if element has finished loading
        if self.loading_timer >= load_time then
            -- Mark this node AND all its descendants as loaded
            -- (Leaf elements contain text/inline content that should appear together)
            -- BUT: Don't recursively mark other leaf elements (they load separately)
            local function markLoaded(n, is_root)
                if not n then return end
                self.loaded_elements[n] = true

                -- Only recurse into children if this isn't another leaf element
                if n.children then
                    local tag = n.element and n.element.tag
                    local is_leaf = tag and self.leaf_elements[tag]

                    -- Don't recurse into other leaf elements (unless this is the root call)
                    if is_root or not is_leaf then
                        for _, child in ipairs(n.children) do
                            markLoaded(child, false)
                        end
                    end
                end
            end
            markLoaded(current_element, true)

            -- Move to next element
            self.loading_index = self.loading_index + 1
            self.loading_timer = 0

            -- Check if done
            if self.loading_index >= #self.loading_queue then
                self.loading_complete = true
            end
        end
    end
end

-- Calculate load time for an element based on type and CPU speed
function WebBrowserState:calculateLoadTime(node, cpu_speed)
    local config = self.di and self.di.config or require('src.config')
    local page_load_config = config.cpu and config.cpu.page_load or {}

    local base_time = page_load_config.element_base or 80

    -- Check element type
    if node.element then
        local tag = node.element.tag

        -- Images
        if tag == "img" and node.image then
            base_time = page_load_config.image_base or 200
            local pixel_cost = page_load_config.image_per_pixel or 0.0008
            local pixels = (node.image_width or 0) * (node.image_height or 0)
            base_time = base_time + (pixels * pixel_cost)

        -- GIFs
        elseif tag == "img" and node.gif_data then
            base_time = page_load_config.gif_base or 300
            local frame_cost = page_load_config.gif_per_frame or 15
            local frames = node.gif_data.frames and #node.gif_data.frames or 1
            base_time = base_time + (frames * frame_cost)

        -- Tables
        elseif tag == "table" then
            base_time = page_load_config.table_base or 100
            local cell_cost = page_load_config.table_per_cell or 20
            local cells = (node.table_rows or 1) * (node.table_cols or 1)
            base_time = base_time + (cells * cell_cost)

        -- Block elements - calculate based on ALL text content inside
        else
            -- Recursively count all text characters in this block
            local function countTextChars(n)
                local total = 0
                if n.element then
                    if n.element.type == "text" and n.element.content then
                        total = total + #n.element.content
                    end
                end
                if n.children then
                    for _, child in ipairs(n.children) do
                        total = total + countTextChars(child)
                    end
                end
                return total
            end

            local char_count = countTextChars(node)
            local char_cost = page_load_config.text_per_char or 2
            base_time = base_time + (char_count * char_cost)
        end
    end

    -- Divide by CPU speed (higher CPU = faster loading)
    return base_time / cpu_speed
end

-- Get cursor type for this window (called by DesktopState)
function WebBrowserState:getCursorType(local_x, local_y)
    -- Check if mouse is over a link
    if not self.view_source_mode and self.current_layout and self.viewport then
        -- Check if mouse is in content area
        local content_y = 60
        if local_y >= content_y and local_x >= 0 and local_x <= self.viewport.width then
            local content_local_y = local_y - content_y
            local link = self.html_renderer:getLinkAtPosition(self.current_layout, local_x, content_local_y, self.scroll_y)

            if link then
                return "hand"
            end
        end
    end

    return nil -- Let window controller decide
end

-- Draw
function WebBrowserState:draw()
    if not self.viewport then return end

    self.view:drawWindowed(
        self.current_url,
        self.current_html,
        self.current_layout,
        self.view_source_mode,
        self.scroll_y,
        self.max_scroll,
        self:canGoBack(),
        self:canGoForward(),
        self.viewport.width,
        self.viewport.height,
        self.image_load_progress
    )
end

-- Mouse pressed
function WebBrowserState:mousepressed(x, y, button)
    -- x, y are ALREADY LOCAL content coordinates from DesktopState
    if not self.viewport or button ~= 1 then
        return false
    end

    -- Check if click is outside the logical content bounds
    if x < 0 or x > self.viewport.width or y < 0 or y > self.viewport.height then
        return false
    end

    -- Check if clicked on address bar
    local toolbar_height = 35
    local address_bar_y = toolbar_height
    local address_bar_height = 25
    local address_bar_bounds = {
        x = 10,
        y = address_bar_y + 2,
        width = self.viewport.width - 20,
        height = address_bar_height - 4
    }

    local font = love.graphics.getFont()
    if self.address_bar:mousepressed(x, y, button, address_bar_bounds, font) then
        return true
    end

    -- Handle scrollbar first
    local scroll_event = self.scrollbar:mousepressed(x, y, button, self.scroll_y)
    if scroll_event then
        if scroll_event.scrolled then
            self.scroll_y = math.max(0, math.min(scroll_event.new_offset, self.max_scroll))
        end
        return true
    end

    -- Check toolbar buttons
    local action = self.view:getButtonAtPosition(x, y)
    if action then
        if action == "back" then
            self:goBack()
        elseif action == "forward" then
            self:goForward()
        elseif action == "refresh" then
            self:refresh()
        elseif action == "view_source" then
            self:toggleViewSource()
        end
        return true
    end

    -- Check if clicked on link (only in normal mode and when page is fully loaded)
    if not self.view_source_mode and self.current_layout and self.loading_complete then
        local content_y = 60 -- Toolbar + address bar
        local content_local_y = y - content_y

        local link = self.html_renderer:getLinkAtPosition(self.current_layout, x, content_local_y, self.scroll_y)
        if link and link.element.attributes then
            local href = link.element.attributes.href
            if href then
                self:handleLinkClick(href)
                return true
            end
        end
    end

    return false
end

-- Mouse moved (for scrollbar dragging and address bar selection)
function WebBrowserState:mousemoved(x, y, dx, dy)
    -- Address bar drag selection
    local toolbar_height = 35
    local address_bar_y = toolbar_height
    local address_bar_height = 25
    local address_bar_bounds = {
        x = 10,
        y = address_bar_y + 2,
        width = self.viewport.width - 20,
        height = address_bar_height - 4
    }

    local font = love.graphics.getFont()
    if self.address_bar:mousemoved(x, y, dx, dy, address_bar_bounds, font) then
        return true
    end

    -- Scrollbar dragging
    local scroll_event = self.scrollbar:mousemoved(x, y, dx, dy)
    if scroll_event then
        if scroll_event.scrolled then
            self.scroll_y = math.max(0, math.min(scroll_event.new_offset, self.max_scroll))
        end
        return true
    end
    return false
end

-- Mouse released (end scrollbar dragging and address bar dragging)
function WebBrowserState:mousereleased(x, y, button)
    -- Address bar drag end
    if self.address_bar:mousereleased(x, y, button) then
        return true
    end

    -- Scrollbar drag end
    if self.scrollbar:mousereleased(x, y, button) then
        return true
    end
    return false
end

-- Mouse wheel (scrolling)
function WebBrowserState:wheelmoved(x, y)
    local scroll_amount = 30
    self.scroll_y = self.scroll_y - (y * scroll_amount)
    self.scroll_y = math.max(0, math.min(self.scroll_y, self.max_scroll))
end

-- Key pressed
function WebBrowserState:keypressed(key)
    -- Address bar text input
    if self.address_bar.focused then
        -- Special handling for Escape
        if key == "escape" then
            -- Unfocus address bar and restore current URL
            self.address_bar:setText(self.current_url or "")
            self.address_bar:unfocus()
            return true
        end

        -- Let TextInputController handle the key
        local result = self.address_bar:keypressed(key)

        -- Check if Enter was pressed
        if type(result) == "table" and result.enter then
            -- Navigate to typed URL
            if self.address_bar.text ~= "" then
                self:navigateTo(self.address_bar.text, false)
            end
            return true
        end

        return result
    end

    -- Scrolling with arrow keys (only when address bar not focused)
    if key == "up" then
        self.scroll_y = math.max(0, self.scroll_y - 30)
        return true
    elseif key == "down" then
        self.scroll_y = math.min(self.max_scroll, self.scroll_y + 30)
        return true
    elseif key == "pageup" then
        self.scroll_y = math.max(0, self.scroll_y - 200)
        return true
    elseif key == "pagedown" then
        self.scroll_y = math.min(self.max_scroll, self.scroll_y + 200)
        return true
    elseif key == "home" then
        self.scroll_y = 0
        return true
    elseif key == "end" then
        self.scroll_y = self.max_scroll
        return true
    end

    return false
end

-- Text input
function WebBrowserState:textinput(text)
    return self.address_bar:textinput(text)
end

return WebBrowserState
