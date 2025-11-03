-- src/utils/syntax_highlighter.lua
-- Simple syntax highlighter for HTML source code (View Source mode)

local SyntaxHighlighter = {}

-- Color scheme (90s code editor aesthetic)
SyntaxHighlighter.colors = {
    tag = {0.0, 0.0, 0.8},           -- Blue for tag names (<html>, </div>)
    attribute = {0.8, 0.0, 0.0},     -- Red for attribute names (href, class)
    string = {0.0, 0.6, 0.0},        -- Green for attribute values ("value")
    comment = {0.5, 0.5, 0.5},       -- Gray for comments (<!-- -->)
    text = {0.0, 0.0, 0.0},          -- Black for plain text
    bracket = {0.0, 0.0, 0.8},       -- Blue for < > brackets

    -- CSS-specific colors
    css_selector = {0.5, 0.0, 0.5},  -- Purple for CSS selectors (p, .class, #id)
    css_property = {0.8, 0.0, 0.0},  -- Red for CSS property names (color, margin)
    css_value = {0.0, 0.6, 0.0},     -- Green for CSS values (red, 10px)
    css_punctuation = {0.0, 0.0, 0.0}, -- Black for { } : ;
}

-- Main function: Highlight HTML source code
-- Returns array of lines, each line is array of {text, color} segments
function SyntaxHighlighter.highlightHTML(html_string)
    if not html_string then return {} end

    local lines = {}
    local current_line = {}
    local pos = 1
    local len = #html_string
    local in_style_tag = false -- Track if we're inside <style> tags

    while pos <= len do
        local char = html_string:sub(pos, pos)

        -- Check for newline
        if char == '\n' then
            table.insert(lines, current_line)
            current_line = {}
            pos = pos + 1

        -- Check for HTML comment
        elseif html_string:sub(pos, pos + 3) == '<!--' then
            local comment_end = html_string:find('%-%->', pos + 4)
            if comment_end then
                local comment_text = html_string:sub(pos, comment_end + 2)
                table.insert(current_line, {
                    text = comment_text,
                    color = SyntaxHighlighter.colors.comment
                })
                pos = comment_end + 3
            else
                -- Unclosed comment - treat rest as comment
                table.insert(current_line, {
                    text = html_string:sub(pos),
                    color = SyntaxHighlighter.colors.comment
                })
                pos = len + 1
            end

        -- Check for opening tag
        elseif char == '<' then
            local tag_end = html_string:find('>', pos + 1)
            if tag_end then
                local tag_content = html_string:sub(pos + 1, tag_end - 1)
                local segments = SyntaxHighlighter.parseTag(tag_content)

                -- Check if this is a <style> or </style> tag
                local tag_name = tag_content:match('^/?(%w+)')
                if tag_name and tag_name:lower() == 'style' then
                    if tag_content:sub(1, 1) == '/' then
                        in_style_tag = false -- Closing </style>
                    else
                        in_style_tag = true -- Opening <style>
                    end
                end

                -- Add opening bracket
                table.insert(current_line, {
                    text = '<',
                    color = SyntaxHighlighter.colors.bracket
                })

                -- Add tag content segments
                for _, seg in ipairs(segments) do
                    table.insert(current_line, seg)
                end

                -- Add closing bracket
                table.insert(current_line, {
                    text = '>',
                    color = SyntaxHighlighter.colors.bracket
                })

                pos = tag_end + 1
            else
                -- No closing bracket - treat as plain text
                table.insert(current_line, {
                    text = char,
                    color = SyntaxHighlighter.colors.text
                })
                pos = pos + 1
            end

        -- Plain text (outside tags) or CSS content (inside <style> tags)
        else
            -- Find next special character or newline
            local next_special = html_string:find('[<\n]', pos + 1)
            local text_end = next_special and (next_special - 1) or len

            -- Don't create empty segments
            if text_end >= pos then
                local text_content = html_string:sub(pos, text_end)

                -- If we're inside a <style> tag, highlight as CSS
                if in_style_tag then
                    local css_segments = SyntaxHighlighter.parseCSS(text_content)
                    for _, seg in ipairs(css_segments) do
                        table.insert(current_line, seg)
                    end
                else
                    table.insert(current_line, {
                        text = text_content,
                        color = SyntaxHighlighter.colors.text
                    })
                end

                pos = text_end + 1
            else
                pos = pos + 1
            end
        end
    end

    -- Add final line if not empty
    if #current_line > 0 then
        table.insert(lines, current_line)
    end

    return lines
end

-- Parse tag content (between < and >)
-- Returns array of {text, color} segments
function SyntaxHighlighter.parseTag(tag_content)
    local segments = {}
    local pos = 1
    local len = #tag_content

    if len == 0 then return segments end

    -- Skip whitespace at start
    while pos <= len and tag_content:sub(pos, pos):match('%s') do
        pos = pos + 1
    end

    if pos > len then return segments end

    -- Handle closing tag (</div>)
    if tag_content:sub(pos, pos) == '/' then
        segments[1] = {
            text = '/',
            color = SyntaxHighlighter.colors.tag
        }
        pos = pos + 1
    end

    -- Extract tag name (first word)
    local tag_name_end = tag_content:find('[%s/>]', pos)
    if not tag_name_end then
        -- Entire content is tag name
        table.insert(segments, {
            text = tag_content:sub(pos),
            color = SyntaxHighlighter.colors.tag
        })
        return segments
    end

    -- Tag name
    table.insert(segments, {
        text = tag_content:sub(pos, tag_name_end - 1),
        color = SyntaxHighlighter.colors.tag
    })
    pos = tag_name_end

    -- Parse attributes
    while pos <= len do
        local char = tag_content:sub(pos, pos)

        -- Skip whitespace
        if char:match('%s') then
            table.insert(segments, {
                text = char,
                color = SyntaxHighlighter.colors.text
            })
            pos = pos + 1

        -- Self-closing tag marker
        elseif char == '/' then
            table.insert(segments, {
                text = char,
                color = SyntaxHighlighter.colors.tag
            })
            pos = pos + 1

        -- Attribute name
        else
            -- Find = or whitespace
            local attr_end = tag_content:find('[=%s/>]', pos + 1)
            if not attr_end then
                -- Rest is attribute name
                table.insert(segments, {
                    text = tag_content:sub(pos),
                    color = SyntaxHighlighter.colors.attribute
                })
                break
            end

            -- Attribute name
            table.insert(segments, {
                text = tag_content:sub(pos, attr_end - 1),
                color = SyntaxHighlighter.colors.attribute
            })
            pos = attr_end

            -- Check for =
            if tag_content:sub(pos, pos) == '=' then
                table.insert(segments, {
                    text = '=',
                    color = SyntaxHighlighter.colors.text
                })
                pos = pos + 1

                -- Skip whitespace after =
                while pos <= len and tag_content:sub(pos, pos):match('%s') do
                    table.insert(segments, {
                        text = tag_content:sub(pos, pos),
                        color = SyntaxHighlighter.colors.text
                    })
                    pos = pos + 1
                end

                -- Parse attribute value
                if pos <= len then
                    local quote = tag_content:sub(pos, pos)
                    if quote == '"' or quote == "'" then
                        -- Quoted value
                        local value_end = tag_content:find(quote, pos + 1)
                        if value_end then
                            table.insert(segments, {
                                text = tag_content:sub(pos, value_end),
                                color = SyntaxHighlighter.colors.string
                            })
                            pos = value_end + 1
                        else
                            -- Unclosed quote - rest is string
                            table.insert(segments, {
                                text = tag_content:sub(pos),
                                color = SyntaxHighlighter.colors.string
                            })
                            break
                        end
                    else
                        -- Unquoted value
                        local value_end = tag_content:find('[%s/>]', pos + 1)
                        if value_end then
                            table.insert(segments, {
                                text = tag_content:sub(pos, value_end - 1),
                                color = SyntaxHighlighter.colors.string
                            })
                            pos = value_end
                        else
                            table.insert(segments, {
                                text = tag_content:sub(pos),
                                color = SyntaxHighlighter.colors.string
                            })
                            break
                        end
                    end
                end
            end
        end
    end

    return segments
end

-- Parse CSS content (inside <style> tags)
-- Returns array of {text, color} segments
function SyntaxHighlighter.parseCSS(css_text)
    local segments = {}
    if not css_text or css_text == "" then return segments end

    local pos = 1
    local len = #css_text

    while pos <= len do
        local char = css_text:sub(pos, pos)

        -- Check for CSS comment
        if css_text:sub(pos, pos + 1) == '/*' then
            local comment_end = css_text:find('*/', pos + 2)
            if comment_end then
                table.insert(segments, {
                    text = css_text:sub(pos, comment_end + 1),
                    color = SyntaxHighlighter.colors.comment
                })
                pos = comment_end + 2
            else
                -- Unclosed comment
                table.insert(segments, {
                    text = css_text:sub(pos),
                    color = SyntaxHighlighter.colors.comment
                })
                break
            end

        -- Check for opening brace (selector before it)
        elseif char == '{' then
            table.insert(segments, {
                text = char,
                color = SyntaxHighlighter.colors.css_punctuation
            })
            pos = pos + 1

        -- Check for closing brace
        elseif char == '}' then
            table.insert(segments, {
                text = char,
                color = SyntaxHighlighter.colors.css_punctuation
            })
            pos = pos + 1

        -- Check for colon (property:value separator)
        elseif char == ':' then
            table.insert(segments, {
                text = char,
                color = SyntaxHighlighter.colors.css_punctuation
            })
            pos = pos + 1

        -- Check for semicolon
        elseif char == ';' then
            table.insert(segments, {
                text = char,
                color = SyntaxHighlighter.colors.css_punctuation
            })
            pos = pos + 1

        -- Whitespace
        elseif char:match('%s') then
            table.insert(segments, {
                text = char,
                color = SyntaxHighlighter.colors.text
            })
            pos = pos + 1

        -- CSS content (selector, property, or value)
        else
            -- Find next special character
            local next_special = css_text:find('[{}:;%s/]', pos + 1)
            local text_end = next_special and (next_special - 1) or len
            local content = css_text:sub(pos, text_end)

            -- Determine context by looking ahead/behind
            -- If we find a '{' before any ':', it's a selector
            -- If we find a ':' before any ';' or '}', we need to determine if before or after ':'
            local ahead = css_text:sub(text_end + 1, text_end + 200)
            local behind = css_text:sub(math.max(1, pos - 200), pos - 1)

            -- Check if we're inside a rule block (between { and })
            local open_braces = 0
            for i = 1, #behind do
                local c = behind:sub(i, i)
                if c == '{' then open_braces = open_braces + 1
                elseif c == '}' then open_braces = open_braces - 1
                end
            end

            local color
            if open_braces > 0 then
                -- Inside a rule block - could be property or value
                -- Check if there's a ':' immediately ahead or behind
                if ahead:match('^%s*:') or behind:match(':%s*$') then
                    -- Before or after colon - determine which
                    local last_colon = behind:match('.*():')
                    local last_semicolon = behind:match('.*();')

                    if last_colon and (not last_semicolon or last_colon > last_semicolon) then
                        -- After colon, before semicolon = value
                        color = SyntaxHighlighter.colors.css_value
                    else
                        -- Before colon = property
                        color = SyntaxHighlighter.colors.css_property
                    end
                else
                    -- Default to property if unclear
                    color = SyntaxHighlighter.colors.css_property
                end
            else
                -- Outside rule block = selector
                color = SyntaxHighlighter.colors.css_selector
            end

            table.insert(segments, {
                text = content,
                color = color
            })
            pos = text_end + 1
        end
    end

    return segments
end

return SyntaxHighlighter
