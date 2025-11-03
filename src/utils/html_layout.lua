-- src/utils/html_layout.lua
-- Calculate positions and sizes for DOM elements (layout engine)

local Object = require('lib.class')
local CSSParser = require('src.utils.css_parser')

local HTMLLayout = Object:extend('HTMLLayout')

-- Block-level elements (stack vertically, take full width)
local BLOCK_ELEMENTS = {
    html = true, body = true, div = true, p = true,
    h1 = true, h2 = true, h3 = true, h4 = true, h5 = true, h6 = true,
    ul = true, ol = true, li = true, hr = true,
    table = true, tr = true, td = true, th = true,
    head = true, title = true
}

-- Inline elements (flow left-to-right, wrap at line end)
local INLINE_ELEMENTS = {
    span = true, a = true, b = true, i = true, u = true,
    strong = true, em = true, img = true
}

-- Elements that don't render
local NON_RENDERING = {
    head = true, title = true, style = true, script = true
}

-- Default styles (90s aesthetic)
local DEFAULT_STYLES = {
    body = {
        ["font-size"] = 14,
        ["font-family"] = "Arial",
        ["color"] = {0, 0, 0},
        ["background-color"] = {1, 1, 1},
        ["margin"] = {10, 10, 10, 10},
        ["padding"] = {0, 0, 0, 0}
    },
    p = {
        ["margin"] = {0, 0, 10, 0},
        ["font-size"] = 14
    },
    h1 = {
        ["font-size"] = 24,
        ["font-weight"] = "bold",
        ["margin"] = {10, 0, 10, 0}
    },
    h2 = {
        ["font-size"] = 20,
        ["font-weight"] = "bold",
        ["margin"] = {10, 0, 8, 0}
    },
    h3 = {
        ["font-size"] = 18,
        ["font-weight"] = "bold",
        ["margin"] = {8, 0, 6, 0}
    },
    h4 = {
        ["font-size"] = 16,
        ["font-weight"] = "bold",
        ["margin"] = {8, 0, 6, 0}
    },
    h5 = {
        ["font-size"] = 14,
        ["font-weight"] = "bold",
        ["margin"] = {6, 0, 4, 0}
    },
    h6 = {
        ["font-size"] = 12,
        ["font-weight"] = "bold",
        ["margin"] = {6, 0, 4, 0}
    },
    a = {
        ["color"] = {0, 0, 1}, -- blue
        ["text-decoration"] = "underline"
    },
    u = {
        ["text-decoration"] = "underline"
    },
    ul = {
        ["margin"] = {10, 0, 10, 20}
    },
    ol = {
        ["margin"] = {10, 0, 10, 20}
    },
    li = {
        ["margin"] = {2, 0, 2, 0}
    },
    hr = {
        ["margin"] = {10, 0, 10, 0},
        ["height"] = 2,
        ["background-color"] = {0.5, 0.5, 0.5}
    }
}

function HTMLLayout:init()
    self.css_parser = CSSParser:new()
    self.stylesheet_rules = {} -- Rules from <style> tags
    self.viewport_width = 800
    self.default_font = love.graphics.getFont()
    self.fonts = {} -- Cache for different font sizes
end

-- Main layout function
function HTMLLayout:layout(dom_tree, viewport_width, stylesheet_rules)
    self.viewport_width = viewport_width or 800
    self.stylesheet_rules = stylesheet_rules or {}

    -- Start layout from body (or html if no body)
    local body = self:findBody(dom_tree)
    if not body then
        body = dom_tree
    end

    -- Layout body element
    local layout_tree = self:layoutElement(body, 0, 0, self.viewport_width, {})

    return layout_tree
end

-- Find <body> element in DOM tree
function HTMLLayout:findBody(node)
    if node.tag == "body" then
        return node
    end

    if node.children then
        for _, child in ipairs(node.children) do
            local body = self:findBody(child)
            if body then
                return body
            end
        end
    end

    return nil
end

-- Layout a single element
function HTMLLayout:layoutElement(element, x, y, available_width, parent_styles)
    if not element then
        return nil
    end

    -- Skip comments
    if element.type == "comment" then
        return nil
    end

    -- Text nodes
    if element.type == "text" then
        return self:layoutText(element, x, y, available_width, parent_styles)
    end

    -- Skip non-rendering elements
    if element.tag and NON_RENDERING[element.tag] then
        return nil
    end

    -- Calculate styles for this element
    local styles = self:calculateStyles(element, parent_styles)

    -- Check for display: none
    if styles.display == "none" then
        return nil
    end

    -- Extract box model values
    local margin = styles.margin or {0, 0, 0, 0}
    local padding = styles.padding or {0, 0, 0, 0}

    -- Inline elements (b, i, u, span) don't add box model offsets
    local is_inline_formatting = INLINE_ELEMENTS[element.tag]
    if is_inline_formatting then
        margin = {0, 0, 0, 0}
        padding = {0, 0, 0, 0}
    end

    -- Apply margin to position
    x = x + margin[4] -- left margin
    y = y + margin[1] -- top margin

    if element.tag == "body" then
        print(string.format("[BODY LAYOUT] available_width=%d, margin L=%d R=%d, padding L=%d R=%d",
            available_width, margin[4], margin[2], padding[4], padding[2]))
    end

    -- Calculate content width
    local content_width = available_width - margin[2] - margin[4] - padding[2] - padding[4]

    if element.tag == "body" then
        print(string.format("[BODY LAYOUT] content_width=%d, final x=%d, final width=%d",
            content_width, x, content_width + padding[2] + padding[4]))
    end
    if styles.width then
        content_width = math.min(styles.width, content_width)
    end

    -- Create layout node
    local layout = {
        element = element,
        x = x,
        y = y,
        width = content_width + padding[2] + padding[4],
        height = 0, -- Will be calculated
        content_x = x + padding[4],
        content_y = y + padding[1],
        content_width = content_width,
        content_height = 0,
        styles = styles,
        children = {}
    }

    -- Handle special elements
    if element.tag == "br" then
        layout.height = styles["font-size"] or 14
        return layout
    end

    if element.tag == "hr" then
        layout.height = (styles.height or 2) + padding[1] + padding[3]
        layout.content_height = styles.height or 2
        return layout
    end

    if element.tag == "img" then
        -- Load image to get dimensions
        local ImageResolver = require('src.utils.image_resolver')
        local src = element.attributes and element.attributes.src

        if src then
            local image_or_gif = ImageResolver.loadImage(src)

            if image_or_gif then
                -- Check if it's a GIF or static image
                if type(image_or_gif) == "table" and image_or_gif.is_gif then
                    -- Animated GIF
                    local width = element.attributes.width and tonumber(element.attributes.width) or image_or_gif.width
                    local height = element.attributes.height and tonumber(element.attributes.height) or image_or_gif.height

                    layout.gif_data = image_or_gif  -- Store entire GIF structure
                    layout.image_width = width
                    layout.image_height = height
                    layout.width = width + padding[2] + padding[4]
                    layout.height = height + padding[1] + padding[3]
                    layout.content_width = width
                    layout.content_height = height
                else
                    -- Static image (image, width, height tuple)
                    local image, img_width, img_height = image_or_gif, nil, nil

                    -- Unpack if returned as tuple
                    if type(image_or_gif) == "userdata" then
                        image = image_or_gif
                        img_width = image:getWidth()
                        img_height = image:getHeight()
                    end

                    local width = element.attributes.width and tonumber(element.attributes.width) or img_width
                    local height = element.attributes.height and tonumber(element.attributes.height) or img_height

                    layout.image = image
                    layout.image_width = width
                    layout.image_height = height
                    layout.width = width + padding[2] + padding[4]
                    layout.height = height + padding[1] + padding[3]
                    layout.content_width = width
                    layout.content_height = height
                end
            else
                -- Image failed to load - render as empty box
                layout.width = 100 + padding[2] + padding[4]
                layout.height = 20 + padding[1] + padding[3]
                layout.content_width = 100
                layout.content_height = 20
            end
        end

        return layout
    end

    -- Handle table elements
    if element.tag == "table" then
        return self:layoutTable(element, layout, styles)
    end

    -- Layout children - simple approach
    if element.children and #element.children > 0 then
        -- Treat paragraphs, headings, and list items as having inline children
        -- Also treat elements with text-align (center/right) as inline containers
        local has_inline_children = element.tag == "p" or element.tag == "h1" or element.tag == "h2" or
                                     element.tag == "h3" or element.tag == "h4" or element.tag == "h5" or element.tag == "h6" or
                                     element.tag == "li"

        -- Check if this element has text-align style (indicates inline content)
        if not has_inline_children and (styles["text-align"] == "center" or styles["text-align"] == "right") then
            -- Check if children contain inline elements or text
            for _, child in ipairs(element.children) do
                if child.type == "text" or (child.tag and INLINE_ELEMENTS[child.tag]) then
                    has_inline_children = true
                    break
                end
            end
        end

        if has_inline_children then
            -- Use inline layout for paragraph/heading content
            layout.children, layout.content_height = self:layoutInlineChildren(element.children, layout.content_x, layout.content_y, layout.content_width, styles)
            layout.height = layout.content_height + padding[1] + padding[3]
        else
            -- Block layout: stack children vertically
            local child_y = layout.content_y

            for i, child in ipairs(element.children) do
                local child_layout = self:layoutElement(child, layout.content_x, child_y, layout.content_width, styles)
                if child_layout then
                    if child.tag == "hr" or (child.tag == "p" and i > 1 and element.children[i-1].tag == "hr") then
                        print(string.format("[LAYOUT] %s at Y=%d, height=%d, next child_y=%d",
                            child.tag or "text", child_layout.y, child_layout.height, child_layout.y + child_layout.height))
                    end
                    table.insert(layout.children, child_layout)
                    -- Use the child's actual Y position (which includes its top margin) plus its height
                    child_y = child_layout.y + child_layout.height
                end
            end

            layout.content_height = child_y - layout.content_y
            layout.height = layout.content_height + padding[1] + padding[3]
        end
    end

    -- Add bottom margin to height
    layout.height = layout.height + margin[3]

    -- Add border height if border is present (2px for top + bottom border)
    if styles.border then
        layout.height = layout.height + 4  -- Assume 2px border = 4px total
    end

    -- Apply explicit height if specified
    if styles.height then
        layout.content_height = styles.height
        layout.height = styles.height + padding[1] + padding[3] + margin[3]
        -- Add border to explicit height too
        if styles.border then
            layout.height = layout.height + 2
        end
    end

    return layout
end

-- Layout text node
function HTMLLayout:layoutText(text_node, x, y, available_width, parent_styles)
    local text = text_node.content

    -- Skip empty/whitespace-only text
    if text:match("^%s*$") then
        return nil
    end

    -- Get font for this text
    local font_size = parent_styles["font-size"] or 14
    local font = self:getFont(font_size)

    -- Wrap text into lines
    local lines = self:wrapText(text, available_width, font)

    if #lines == 0 then
        return nil
    end

    local line_height = font:getHeight() * 1.2

    return {
        element = text_node,
        x = x,
        y = y,
        width = available_width,
        height = #lines * line_height,
        content_x = x,
        content_y = y,
        content_width = available_width,
        content_height = #lines * line_height,
        styles = parent_styles,
        lines = lines,
        line_height = line_height,
        children = {}
    }
end

-- Layout inline children (flow left-to-right, wrap)
function HTMLLayout:layoutInlineChildren(children, start_x, start_y, available_width, parent_styles, left_margin)
    if not children or #children == 0 then
        return {}, 0
    end

    -- left_margin is where we return to after wrapping (defaults to start_x for first call)
    left_margin = left_margin or start_x

    local layouts = {}
    local current_x = start_x
    local current_y = start_y
    local line_height = (parent_styles["font-size"] or 14) * 1.2
    local max_height = 0

    for _, child in ipairs(children) do
        if child.type == "text" then
            -- Layout text inline
            local text = child.content
            if not text:match("^%s*$") then
                local font_size = parent_styles["font-size"] or 14
                local font = self:getFont(font_size)
                local words = {}
                for word in text:gmatch("%S+") do
                    table.insert(words, word)
                end

                for _, word in ipairs(words) do
                    local word_width = font:getWidth(word .. " ")

                    -- Wrap to next line if word doesn't fit
                    if current_x > left_margin and current_x + word_width > left_margin + available_width then
                        current_x = left_margin
                        current_y = current_y + line_height
                    end

                    -- Create text-only styles (no box model properties)
                    local text_styles = {}
                    for k, v in pairs(parent_styles) do
                        -- Only inherit text-related properties
                        if k ~= "border" and k ~= "margin" and k ~= "padding" and
                           k ~= "width" and k ~= "height" and k ~= "background-color" then
                            text_styles[k] = v
                        end
                    end

                    -- Create layout for word
                    table.insert(layouts, {
                        element = { type = "text", content = word .. " " },
                        x = current_x,
                        y = current_y,
                        width = word_width,
                        height = line_height,
                        styles = text_styles,
                        children = {}
                    })

                    current_x = current_x + word_width
                end
            end
        elseif child.tag == "br" then
            -- Line break
            current_x = left_margin
            current_y = current_y + line_height
        elseif child.tag == "img" then
            -- Inline image
            local ImageResolver = require('src.utils.image_resolver')
            local src = child.attributes and child.attributes.src

            if src then
                local image_or_gif = ImageResolver.loadImage(src)

                if image_or_gif then
                    local img_width, img_height

                    -- Check if it's a GIF or static image
                    if type(image_or_gif) == "table" and image_or_gif.is_gif then
                        -- Animated GIF
                        img_width = child.attributes.width and tonumber(child.attributes.width) or image_or_gif.width
                        img_height = child.attributes.height and tonumber(child.attributes.height) or image_or_gif.height

                        -- Wrap to next line if doesn't fit
                        if current_x > left_margin and current_x + img_width > left_margin + available_width then
                            current_x = left_margin
                            current_y = current_y + line_height
                        end

                        local img_layout = {
                            element = child,
                            x = current_x,
                            y = current_y,
                            width = img_width,
                            height = img_height,
                            content_x = current_x,
                            content_y = current_y,
                            content_width = img_width,
                            content_height = img_height,
                            gif_data = image_or_gif,  -- Store entire GIF structure
                            image_width = img_width,
                            image_height = img_height,
                            styles = self:calculateStyles(child, parent_styles),
                            children = {}
                        }

                        table.insert(layouts, img_layout)
                        current_x = current_x + img_width
                        max_height = math.max(max_height, img_height)
                    else
                        -- Static image
                        local image = image_or_gif
                        img_width = child.attributes.width and tonumber(child.attributes.width) or image:getWidth()
                        img_height = child.attributes.height and tonumber(child.attributes.height) or image:getHeight()

                        -- Wrap to next line if doesn't fit
                        if current_x > left_margin and current_x + img_width > left_margin + available_width then
                            current_x = left_margin
                            current_y = current_y + line_height
                        end

                        local img_layout = {
                            element = child,
                            x = current_x,
                            y = current_y,
                            width = img_width,
                            height = img_height,
                            content_x = current_x,
                            content_y = current_y,
                            content_width = img_width,
                            content_height = img_height,
                            image = image,
                            image_width = img_width,
                            image_height = img_height,
                            styles = self:calculateStyles(child, parent_styles),
                            children = {}
                        }

                        table.insert(layouts, img_layout)
                        current_x = current_x + img_width
                        max_height = math.max(max_height, img_height)
                    end
                end
            end
        else
            -- Inline formatting element (b, i, u, span, a, etc.)
            -- Calculate styles for this element
            local child_styles = self:calculateStyles(child, parent_styles)

            -- For links, layout the text content inline (don't create sub-layout)
            if child.tag == "a" and child.children and #child.children > 0 then
                -- Get the link text (assuming simple text content for now)
                local link_text = ""
                for _, text_child in ipairs(child.children) do
                    if text_child.type == "text" then
                        link_text = link_text .. text_child.content
                    end
                end

                -- Layout the link text as words
                if link_text and not link_text:match("^%s*$") then
                    local font_size = child_styles["font-size"] or 14
                    local font = self:getFont(font_size)
                    local words = {}
                    for word in link_text:gmatch("%S+") do
                        table.insert(words, word)
                    end

                    -- Track where link starts
                    local link_start_x = current_x
                    local link_start_y = current_y
                    local link_layouts = {}

                    for _, word in ipairs(words) do
                        local word_width = font:getWidth(word .. " ")

                        -- Wrap to next line if word doesn't fit
                        if current_x > left_margin and current_x + word_width > left_margin + available_width then
                            current_x = left_margin
                            current_y = current_y + line_height
                        end

                        -- Create text-only styles (no box model properties)
                        local text_styles = {}
                        for k, v in pairs(child_styles) do
                            -- Only inherit text-related properties
                            if k ~= "border" and k ~= "margin" and k ~= "padding" and
                               k ~= "width" and k ~= "height" and k ~= "background-color" then
                                text_styles[k] = v
                            end
                        end

                        -- Create layout for word
                        local word_layout = {
                            element = { type = "text", content = word .. " " },
                            x = current_x,
                            y = current_y,
                            width = word_width,
                            height = line_height,
                            styles = text_styles,
                            children = {}
                        }

                        table.insert(layouts, word_layout)
                        table.insert(link_layouts, word_layout)

                        current_x = current_x + word_width
                    end

                    -- Create link wrapper for hit detection (single line)
                    if #link_layouts > 0 then
                        local first = link_layouts[1]
                        local last = link_layouts[#link_layouts]

                        local link_layout = {
                            element = child,
                            x = first.x,
                            y = first.y,
                            width = (last.x + last.width) - first.x,
                            height = first.height,
                            content_x = first.x,
                            content_y = first.y,
                            content_width = (last.x + last.width) - first.x,
                            content_height = first.height,
                            styles = child_styles,
                            children = link_layouts
                        }

                        table.insert(layouts, link_layout)
                    end
                end
            else
                -- Other inline formatting (b, i, u, span)
                -- Recursively layout children and flatten into parent
                if child.children and #child.children > 0 then
                    local child_layouts, child_height = self:layoutInlineChildren(child.children, current_x, current_y, available_width, child_styles, left_margin)

                    -- Add the child layouts to our list
                    for _, child_layout in ipairs(child_layouts) do
                        table.insert(layouts, child_layout)
                    end

                    -- Update current position based on last child position
                    if #child_layouts > 0 then
                        local last_child = child_layouts[#child_layouts]
                        current_x = last_child.x + last_child.width
                        current_y = last_child.y
                    end
                end
            end
        end
    end

    local total_height = (current_y - start_y) + line_height

    -- Post-process for text alignment (center/right)
    if parent_styles["text-align"] == "center" or parent_styles["text-align"] == "right" then
        -- Group layouts by line (same y position)
        local lines = {}
        for _, layout in ipairs(layouts) do
            local y = layout.y
            if not lines[y] then
                lines[y] = {}
            end
            table.insert(lines[y], layout)
        end

        -- Center or right-align each line
        for y, line_layouts in pairs(lines) do
            if #line_layouts > 0 then
                -- Calculate line width
                local first = line_layouts[1]
                local last = line_layouts[#line_layouts]
                local line_width = (last.x + last.width) - first.x

                -- Calculate offset
                local offset = 0
                if parent_styles["text-align"] == "center" then
                    offset = (available_width - line_width) / 2
                elseif parent_styles["text-align"] == "right" then
                    offset = available_width - line_width
                end

                -- Apply offset to all layouts on this line
                if offset > 0 then
                    for _, layout in ipairs(line_layouts) do
                        layout.x = layout.x + offset

                        -- Also update content_x for all nodes
                        if layout.content_x then
                            layout.content_x = layout.content_x + offset
                        end

                        -- Note: Link children are separate nodes in line_layouts and will be shifted
                        -- when we iterate over them. We don't need to recursively shift here.
                    end
                end
            end
        end
    end

    return layouts, total_height
end

-- Wrap text into lines based on available width
function HTMLLayout:wrapText(text, width, font)
    local lines = {}
    local words = {}

    -- Split text into words
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    if #words == 0 then
        return lines
    end

    local current_line = ""
    for i, word in ipairs(words) do
        local test_line = current_line == "" and word or (current_line .. " " .. word)
        local test_width = font:getWidth(test_line)

        if test_width <= width then
            current_line = test_line
        else
            -- Word doesn't fit, start new line
            if current_line ~= "" then
                table.insert(lines, current_line)
            end
            current_line = word
        end
    end

    -- Add last line
    if current_line ~= "" then
        table.insert(lines, current_line)
    end

    return lines
end

-- Calculate styles for element (merge default, stylesheet, inline)
function HTMLLayout:calculateStyles(element, parent_styles)
    local styles = {}

    -- Non-inheritable properties (should not be passed to children)
    local non_inheritable = {
        border = true,
        margin = true,
        padding = true,
        width = true,
        height = true,
        ["background-color"] = true,
        ["background-image"] = true,
        ["background-repeat"] = true,
        display = true
    }

    -- Start with parent styles (inheritance), but skip non-inheritable properties
    for k, v in pairs(parent_styles) do
        if not non_inheritable[k] then
            styles[k] = v
        end
    end

    -- Apply default styles for this tag
    if element.tag and DEFAULT_STYLES[element.tag] then
        for k, v in pairs(DEFAULT_STYLES[element.tag]) do
            styles[k] = v
        end
    end

    -- Apply stylesheet rules
    for _, rule in ipairs(self.stylesheet_rules) do
        if self:selectorMatches(rule.selector, element) then
            local resolved = self.css_parser:resolveProperties(rule.properties)
            for k, v in pairs(resolved) do
                styles[k] = v
            end
        end
    end

    -- Apply inline styles (highest priority)
    if element.attributes and element.attributes.style then
        local inline_props = self.css_parser:parseInlineStyle(element.attributes.style)
        local resolved = self.css_parser:resolveProperties(inline_props)
        for k, v in pairs(resolved) do
            styles[k] = v
        end
    end

    return styles
end

-- Check if CSS selector matches element
function HTMLLayout:selectorMatches(selector, element)
    if not selector or not element.tag then
        return false
    end

    selector = selector:match("^%s*(.-)%s*$") -- trim

    -- ID selector (#id)
    if selector:sub(1, 1) == "#" then
        local id = selector:sub(2)
        return element.attributes and element.attributes.id == id
    end

    -- Class selector (.class)
    if selector:sub(1, 1) == "." then
        local class = selector:sub(2)
        if element.attributes and element.attributes.class then
            -- Check if class attribute contains this class
            for cls in element.attributes.class:gmatch("%S+") do
                if cls == class then
                    return true
                end
            end
        end
        return false
    end

    -- Element selector (tag)
    return element.tag == selector
end

-- Get or create font for size
function HTMLLayout:getFont(size)
    size = math.floor(size)
    if not self.fonts[size] then
        local success, font = pcall(love.graphics.newFont, size)
        if success then
            self.fonts[size] = font
        else
            self.fonts[size] = love.graphics.getFont()
        end
    end
    return self.fonts[size]
end

-- Layout table element (1999 style: fixed-width columns, simple borders)
function HTMLLayout:layoutTable(element, layout, styles)
    if not element.children or #element.children == 0 then
        layout.height = 0
        return layout
    end

    -- Extract rows (<tr> elements)
    local rows = {}
    for _, child in ipairs(element.children) do
        if child.tag == "tr" then
            table.insert(rows, child)
        end
    end

    if #rows == 0 then
        layout.height = 0
        return layout
    end

    -- Calculate number of columns (max cells in any row)
    local num_cols = 0
    for _, row in ipairs(rows) do
        local cell_count = 0
        if row.children then
            for _, cell in ipairs(row.children) do
                if cell.tag == "td" or cell.tag == "th" then
                    cell_count = cell_count + 1
                end
            end
        end
        num_cols = math.max(num_cols, cell_count)
    end

    if num_cols == 0 then
        layout.height = 0
        return layout
    end

    -- Calculate column width (equal distribution, 1999 style)
    local border_width = 1
    local cell_padding = 5
    local total_border_width = (num_cols + 1) * border_width
    local available_width = layout.content_width - total_border_width
    local col_width = math.floor(available_width / num_cols)

    -- Layout rows and cells
    local current_y = layout.content_y
    local table_children = {}

    for row_idx, row in ipairs(rows) do
        local row_height = 0
        local cell_layouts = {}

        -- First pass: layout all cells to determine row height
        if row.children then
            local col_idx = 0
            for _, cell in ipairs(row.children) do
                if cell.tag == "td" or cell.tag == "th" then
                    col_idx = col_idx + 1

                    -- Calculate cell position
                    local cell_x = layout.content_x + (col_idx - 1) * (col_width + border_width) + border_width
                    local cell_y = current_y + border_width

                    -- Create cell layout node
                    local cell_layout = {
                        element = cell,
                        x = cell_x,
                        y = cell_y,
                        width = col_width,
                        content_x = cell_x + cell_padding,
                        content_y = cell_y + cell_padding,
                        content_width = col_width - cell_padding * 2,
                        content_height = 0,
                        styles = self:calculateStyles(cell, styles),
                        children = {}
                    }

                    -- Layout cell content (text or block children)
                    if cell.children and #cell.children > 0 then
                        cell_layout.children, cell_layout.content_height = self:layoutInlineChildren(
                            cell.children,
                            cell_layout.content_x,
                            cell_layout.content_y,
                            cell_layout.content_width,
                            cell_layout.styles
                        )
                    end

                    cell_layout.height = cell_layout.content_height + cell_padding * 2
                    row_height = math.max(row_height, cell_layout.height)

                    table.insert(cell_layouts, cell_layout)
                end
            end
        end

        -- Second pass: adjust all cells in row to same height
        for _, cell_layout in ipairs(cell_layouts) do
            cell_layout.height = row_height
            table.insert(table_children, cell_layout)
        end

        current_y = current_y + row_height + border_width
    end

    -- Set final table dimensions
    layout.children = table_children
    layout.content_height = current_y - layout.content_y
    layout.height = layout.content_height + (styles.padding and (styles.padding[1] + styles.padding[3]) or 0)

    -- Mark table for special rendering (borders)
    layout.is_table = true
    layout.table_rows = #rows
    layout.table_cols = num_cols
    layout.table_col_width = col_width
    layout.table_border_width = border_width

    return layout
end

return HTMLLayout
