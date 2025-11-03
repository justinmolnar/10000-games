-- src/utils/html_renderer.lua
-- Draw layout tree to LÖVE canvas

local Object = require('lib.class')
local HTMLRenderer = Object:extend('HTMLRenderer')

function HTMLRenderer:init()
    self.visited_links = {} -- Track visited links for color change
    self.hovered_link = nil -- Current hovered link
    self.fonts = {} -- Font cache
end

-- Update animated GIFs
function HTMLRenderer:update(dt, layout_tree)
    if not layout_tree then
        return
    end

    self:updateGIFs(dt, layout_tree)
end

-- Recursively update all GIF animations in layout tree
function HTMLRenderer:updateGIFs(dt, node)
    if not node then
        return
    end

    -- Update this node's GIF if it has one
    if node.gif_data then
        local gif_data = node.gif_data
        gif_data.time_accumulated = gif_data.time_accumulated + dt

        local current_frame = gif_data.frames[gif_data.current_frame]
        if current_frame then
            local frame_delay = current_frame.delay

            -- Advance to next frame if delay exceeded
            if gif_data.time_accumulated >= frame_delay then
                gif_data.time_accumulated = gif_data.time_accumulated - frame_delay
                gif_data.current_frame = gif_data.current_frame + 1

                -- Loop back to first frame if at end
                if gif_data.current_frame > #gif_data.frames then
                    gif_data.current_frame = 1
                end
            end
        end
    end

    -- Update children
    if node.children then
        for _, child in ipairs(node.children) do
            self:updateGIFs(dt, child)
        end
    end
end

-- Main render function
function HTMLRenderer:render(layout_tree, scroll_y, viewport_x, viewport_y, viewport_width, viewport_height, loaded_elements, image_load_progress)
    if not layout_tree then
        return
    end

    scroll_y = scroll_y or 0
    viewport_x = viewport_x or 0
    viewport_y = viewport_y or 0

    -- Store for renderNode to access
    -- nil = render everything (loading system not active)
    -- table = only render loaded elements (check each node)
    self.loaded_elements = loaded_elements
    self.image_load_progress = image_load_progress or {}

    local g = love.graphics

    -- Save original font
    local original_font = g.getFont()

    -- Set scissor for content area (use screen coordinates)
    if viewport_width and viewport_height then
        g.setScissor(viewport_x, viewport_y, viewport_width, viewport_height)
    end

    -- Draw body background BEFORE translate (fixed, fills viewport)
    if layout_tree.element and layout_tree.element.tag == "body" and layout_tree.styles then
        if layout_tree.styles["background-color"] then
            g.setColor(layout_tree.styles["background-color"])
            g.rectangle("fill", 0, 0, viewport_width, viewport_height or 10000)
        end

        -- Draw body background-image (tiled, 1999 style)
        if layout_tree.styles["background-image"] then
            local ImageResolver = require('src.utils.image_resolver')
            local bg_image = ImageResolver.loadImage(layout_tree.styles["background-image"])

            if bg_image then
                local repeat_mode = layout_tree.styles["background-repeat"] or "repeat"

                g.setColor(1, 1, 1)

                if repeat_mode == "no-repeat" then
                    -- Draw once at top-left (WITH scroll offset applied later)
                    -- We'll handle this inside the push/translate
                else
                    -- Tile the image across entire viewport
                    local img_w = bg_image:getWidth()
                    local img_h = bg_image:getHeight()

                    for tile_y = 0, (viewport_height or 10000) - 1, img_h do
                        for tile_x = 0, viewport_width - 1, img_w do
                            g.draw(bg_image, tile_x, tile_y)
                        end
                    end
                end
            end
        end
    end

    -- Render with scroll offset
    g.push()
    g.translate(0, -scroll_y)

    -- Start rendering with no list context
    self:renderNode(layout_tree, nil, 0, viewport_width, viewport_height)

    g.pop()

    -- Clear scissor
    g.setScissor()

    -- Restore original font
    g.setFont(original_font)
end

-- Render a single layout node
function HTMLRenderer:renderNode(node, list_type, list_index, viewport_width, viewport_height)
    if not node then
        return
    end

    local element = node.element
    if not element then
        return
    end

    -- Skip comments
    if element.type == "comment" then
        return
    end

    -- Check if element is loaded (progressive rendering)
    -- If loaded_elements is nil, render everything (loading system not active)
    -- If loaded_elements is a table, only render if this node is marked as loaded
    if self.loaded_elements then
        local is_loaded = self.loaded_elements[node]
        if not is_loaded then
            -- Element not yet loaded - skip rendering entirely
            return
        end
    end

    local g = love.graphics
    local styles = node.styles or {}

    -- Render background (skip body - handled in render() before translate)
    if styles["background-color"] and element.tag ~= "body" then
        g.setColor(styles["background-color"])
        g.rectangle("fill", node.x, node.y, node.width, node.height)
    end

    -- Render background-image (tiling or no-repeat, 1999 style)
    if styles["background-image"] and element.tag ~= "body" then
        local ImageResolver = require('src.utils.image_resolver')
        local bg_image = ImageResolver.loadImage(styles["background-image"])

        if bg_image then
            local repeat_mode = styles["background-repeat"] or "repeat"

            g.setColor(1, 1, 1)

            if repeat_mode == "no-repeat" then
                -- Draw once at top-left
                g.draw(bg_image, node.x, node.y)
            else
                -- Tile the image (1999 default behavior)
                local img_w = bg_image:getWidth()
                local img_h = bg_image:getHeight()

                for tile_y = node.y, node.y + node.height - 1, img_h do
                    for tile_x = node.x, node.x + node.width - 1, img_w do
                        g.draw(bg_image, tile_x, tile_y)
                    end
                end
            end
        end
    end

    -- Render border (if specified)
    if styles.border then
        g.setColor(0.5, 0.5, 0.5)
        g.rectangle("line", node.x, node.y, node.width, node.height)
    end

    -- Track list context
    local current_list_type = list_type
    local current_list_index = list_index

    -- Render specific elements
    if element.type == "text" then
        self:renderText(node)
    elseif element.tag == "hr" then
        self:renderHR(node)
    elseif element.tag == "img" then
        self:renderImage(node)
    elseif element.tag == "table" then
        self:renderTable(node)
    elseif element.tag == "a" then
        self:renderLink(node, list_type, list_index)
    elseif element.tag == "li" then
        self:renderListItem(node, list_type, list_index)
        current_list_index = (list_index or 0) + 1
    elseif element.tag == "ul" then
        current_list_type = "ul"
        current_list_index = 0
    elseif element.tag == "ol" then
        current_list_type = "ol"
        current_list_index = 0
    end

    -- Render children (unless handled by specific render function)
    if element.tag ~= "li" and element.tag ~= "a" and element.tag ~= "table" then
        local child_index = current_list_index
        for _, child in ipairs(node.children) do
            self:renderNode(child, current_list_type, child_index, viewport_width, viewport_height)
            -- Increment index for each list item
            if child.element and child.element.tag == "li" then
                child_index = child_index + 1
            end
        end
    end

    -- Reset color
    g.setColor(1, 1, 1)
end

-- Render text node
function HTMLRenderer:renderText(node)
    if not node.element or node.element.type ~= "text" then
        return
    end

    local g = love.graphics
    local styles = node.styles or {}

    -- Get text color
    local color = styles.color or {0, 0, 0}
    g.setColor(color)

    -- Get font
    local font_size = styles["font-size"] or 14
    local font = self:getFont(font_size, styles)
    g.setFont(font)

    -- Render lines or single text
    if node.lines then
        -- Multi-line text (from text wrapping)
        local y = node.content_y
        for _, line in ipairs(node.lines) do
            -- Apply text alignment
            local x = node.content_x
            if styles["text-align"] == "center" then
                local line_width = font:getWidth(line)
                x = node.content_x + (node.content_width - line_width) / 2
            elseif styles["text-align"] == "right" then
                local line_width = font:getWidth(line)
                x = node.content_x + node.content_width - line_width
            end

            g.print(line, x, y)

            -- Render underline if needed
            if styles["text-decoration"] == "underline" then
                local line_width = font:getWidth(line)
                local underline_y = y + font:getHeight()
                g.setColor(color)
                g.line(x, underline_y, x + line_width, underline_y)
            end

            y = y + node.line_height
        end
    else
        -- Single text (inline)
        local text = node.element.content
        local x = node.x

        -- Apply text alignment for inline text (approximation)
        -- Note: Proper centering requires line-based layout, this is a simple fallback
        if styles["text-align"] == "center" and node.width then
            local text_width = font:getWidth(text)
            if text_width < node.width then
                x = node.x + (node.width - text_width) / 2
            end
        elseif styles["text-align"] == "right" and node.width then
            local text_width = font:getWidth(text)
            x = node.x + node.width - text_width
        end

        g.print(text, x, node.y)

        -- Render underline if needed
        if styles["text-decoration"] == "underline" then
            local text_width = font:getWidth(text)
            local underline_y = node.y + font:getHeight()
            g.setColor(color)
            g.line(x, underline_y, x + text_width, underline_y)
        end
    end

    -- Reset color
    g.setColor(1, 1, 1)
end

-- Render horizontal rule
function HTMLRenderer:renderHR(node)
    local g = love.graphics
    local styles = node.styles or {}

    local color = styles["background-color"] or {0.5, 0.5, 0.5}
    g.setColor(color)

    local hr_y = node.content_y
    local hr_height = node.content_height or styles.height or 2

    g.rectangle("fill", node.content_x, hr_y, node.content_width, hr_height)

    g.setColor(1, 1, 1)
end

-- Render image (static or animated GIF)
function HTMLRenderer:renderImage(node)
    if not node.image and not node.gif_data then
        return
    end

    local g = love.graphics
    g.setColor(1, 1, 1)

    -- Draw width/height (1999 behavior - stretches/squashes to fit)
    local draw_width = node.image_width or node.content_width
    local draw_height = node.image_height or node.content_height

    -- Check for scanline loading progress
    local scanlines_loaded = self.image_load_progress and self.image_load_progress[node]
    local clip_height = nil
    if scanlines_loaded and scanlines_loaded < draw_height then
        clip_height = scanlines_loaded
    end

    -- Check if animated GIF
    if node.gif_data then
        local gif_data = node.gif_data
        local current_frame = gif_data.frames[gif_data.current_frame]

        if current_frame then
            local frame_image = current_frame.image

            -- Calculate scale to fit draw dimensions
            local scale_x = draw_width / frame_image:getWidth()
            local scale_y = draw_height / frame_image:getHeight()

            -- Draw current frame with offsets (GIFs can have per-frame offsets)
            local offset_x = current_frame.x_offset or 0
            local offset_y = current_frame.y_offset or 0

            if clip_height then
                -- Use stencil for scanline clipping
                local function clipStencil()
                    g.rectangle("fill", node.content_x, node.content_y, draw_width, clip_height)
                end
                g.stencil(clipStencil, "replace", 1)
                g.setStencilTest("greater", 0)
            end

            g.draw(frame_image, node.content_x + offset_x, node.content_y + offset_y, 0, scale_x, scale_y)

            if clip_height then
                g.setStencilTest()
            end
        end
    else
        -- Static image
        local scale_x = draw_width / node.image:getWidth()
        local scale_y = draw_height / node.image:getHeight()

        if clip_height then
            -- Use stencil for scanline clipping
            local function clipStencil()
                g.rectangle("fill", node.content_x, node.content_y, draw_width, clip_height)
            end
            g.stencil(clipStencil, "replace", 1)
            g.setStencilTest("greater", 0)
        end

        g.draw(node.image, node.content_x, node.content_y, 0, scale_x, scale_y)

        if clip_height then
            g.setStencilTest()
        end
    end
end

-- Render list item (with bullet or number)
function HTMLRenderer:renderListItem(node, list_type, list_index)
    local g = love.graphics
    local styles = node.styles or {}

    g.setColor(0, 0, 0)

    if list_type == "ol" then
        -- Ordered list - render number
        local number = tostring((list_index or 0) + 1) .. "."

        -- Use the same font size as the list item content
        local font_size = styles["font-size"] or 14
        local font = self:getFont(font_size, styles)
        g.setFont(font)

        g.print(number, node.content_x - 25, node.content_y)
    else
        -- Unordered list - render bullet
        -- Use a simple filled circle
        g.circle("fill", node.content_x - 10, node.content_y + 8, 4)
    end

    -- Render children
    for _, child in ipairs(node.children) do
        self:renderNode(child, list_type, list_index, nil, nil)
    end

    g.setColor(1, 1, 1)
end

-- Render table with borders (1999 style)
function HTMLRenderer:renderTable(node)
    if not node.is_table then
        return
    end

    local g = love.graphics
    local styles = node.styles or {}
    local border_color = {0, 0, 0}  -- Default black borders
    local border_width = node.table_border_width or 1

    -- Draw table background (if CSS specified)
    if styles["background-color"] then
        g.setColor(styles["background-color"])
        g.rectangle("fill", node.x, node.y, node.width, node.height)
    end

    -- Draw table outer border
    g.setColor(border_color)
    g.setLineWidth(border_width)
    g.rectangle("line", node.x, node.y, node.width, node.height)

    -- Draw cell borders and render cell content
    for _, cell in ipairs(node.children) do
        local cell_styles = cell.styles or {}

        -- Render cell background (respect CSS background-color)
        if cell_styles["background-color"] then
            g.setColor(cell_styles["background-color"])
            g.rectangle("fill", cell.x, cell.y, cell.width, cell.height)
        elseif cell.element.tag == "th" then
            -- Default light gray for headers if no CSS specified
            g.setColor(0.9, 0.9, 0.9)
            g.rectangle("fill", cell.x, cell.y, cell.width, cell.height)
        end

        -- Draw cell border
        g.setColor(border_color)
        g.rectangle("line", cell.x, cell.y, cell.width, cell.height)

        -- Render cell content (text)
        for _, child in ipairs(cell.children) do
            self:renderNode(child, nil, 0, nil, nil)
        end
    end

    g.setColor(1, 1, 1)
    g.setLineWidth(1)
end

-- Render link (with hover effect)
function HTMLRenderer:renderLink(node, list_type, list_index)
    local g = love.graphics
    local styles = node.styles or {}

    -- Get href
    local href = node.element.attributes and node.element.attributes.href

    -- Determine link color
    local link_color = styles.color or {0, 0, 1} -- default blue
    if href and self.visited_links[href] then
        link_color = {0.5, 0, 0.5} -- purple for visited
    end

    -- Check if hovered
    local is_hovered = (self.hovered_link == node)
    if is_hovered then
        -- Lighter color on hover
        link_color = {link_color[1] * 1.2, link_color[2] * 1.2, link_color[3] * 1.2}
    end

    -- Override styles for link rendering
    local link_styles = {}
    for k, v in pairs(styles) do
        link_styles[k] = v
    end
    link_styles.color = link_color
    link_styles["text-decoration"] = "underline"

    -- Create temporary node with link styles
    local temp_node = {
        element = node.element,
        x = node.x,
        y = node.y,
        width = node.width,
        height = node.height,
        content_x = node.content_x,
        content_y = node.content_y,
        content_width = node.content_width,
        content_height = node.content_height,
        styles = link_styles,
        children = node.children,
        lines = node.lines,
        line_height = node.line_height
    }

    -- Render children with link styles
    -- Temporarily disable loaded_elements check for child nodes since we already checked the parent <a>
    local saved_loaded_elements = self.loaded_elements
    self.loaded_elements = nil

    if node.children and #node.children > 0 then
        for _, child in ipairs(node.children) do
            -- Apply link styles to children
            local child_with_link_styles = self:applyStylesToNode(child, link_styles)
            self:renderNode(child_with_link_styles, list_type, list_index, nil, nil)
        end
    end

    -- Restore loaded_elements check
    self.loaded_elements = saved_loaded_elements

    g.setColor(1, 1, 1)
end

-- Apply styles to node (for link children)
function HTMLRenderer:applyStylesToNode(node, styles)
    local new_node = {}
    for k, v in pairs(node) do
        new_node[k] = v
    end

    -- Merge styles
    local merged_styles = {}
    if node.styles then
        for k, v in pairs(node.styles) do
            merged_styles[k] = v
        end
    end
    for k, v in pairs(styles) do
        merged_styles[k] = v
    end

    new_node.styles = merged_styles
    return new_node
end

-- Get or create font
function HTMLRenderer:getFont(size, styles)
    size = math.floor(size)

    local weight = styles["font-weight"] or "normal"
    local style = styles["font-style"] or "normal"

    local font_key = size .. "_" .. weight .. "_" .. style

    if not self.fonts[font_key] then
        -- LÖVE doesn't support font weights/styles easily, so just use size
        local success, font = pcall(love.graphics.newFont, size)
        if success then
            self.fonts[font_key] = font
        else
            self.fonts[font_key] = love.graphics.getFont()
        end
    end

    return self.fonts[font_key]
end

-- Mark link as visited
function HTMLRenderer:markLinkVisited(href)
    if href then
        self.visited_links[href] = true
    end
end

-- Set hovered link (for hover effect)
function HTMLRenderer:setHoveredLink(link_node)
    self.hovered_link = link_node
end

-- Get link at position (for hover detection)
function HTMLRenderer:getLinkAtPosition(layout_tree, mx, my, scroll_y)
    if not layout_tree then
        return nil
    end

    my = my + scroll_y -- Adjust for scroll

    return self:findLinkAtPosition(layout_tree, mx, my)
end

-- Recursive link search
function HTMLRenderer:findLinkAtPosition(node, mx, my)
    if not node then
        return nil
    end

    -- Check if position is within this node
    if mx >= node.x and mx <= node.x + node.width and
       my >= node.y and my <= node.y + node.height then

        -- If this is a link, return it
        if node.element and node.element.tag == "a" then
            return node
        end

        -- Check children
        if node.children then
            for _, child in ipairs(node.children) do
                local link = self:findLinkAtPosition(child, mx, my)
                if link then
                    return link
                end
            end
        end
    end

    return nil
end

-- Calculate total document height (for scrollbar)
function HTMLRenderer:getDocumentHeight(layout_tree)
    if not layout_tree then
        return 0
    end

    return self:getMaxHeight(layout_tree)
end

-- Get max height of layout tree
function HTMLRenderer:getMaxHeight(node)
    if not node then
        return 0
    end

    local max_h = node.y + node.height

    if node.children then
        for _, child in ipairs(node.children) do
            local child_max = self:getMaxHeight(child)
            max_h = math.max(max_h, child_max)
        end
    end

    return max_h
end

return HTMLRenderer
