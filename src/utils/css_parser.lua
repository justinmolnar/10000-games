-- src/utils/css_parser.lua
-- Parse basic CSS (colors, fonts, box model) into rule objects

local Object = require('lib.class')
local CSSParser = Object:extend('CSSParser')

-- Named color map (basic 90s colors)
local NAMED_COLORS = {
    -- Basic colors
    black = "#000000",
    white = "#FFFFFF",
    red = "#FF0000",
    green = "#008000",
    blue = "#0000FF",
    yellow = "#FFFF00",
    cyan = "#00FFFF",
    magenta = "#FF00FF",
    gray = "#808080",
    grey = "#808080",
    silver = "#C0C0C0",
    maroon = "#800000",
    olive = "#808000",
    lime = "#00FF00",
    aqua = "#00FFFF",
    teal = "#008080",
    navy = "#000080",
    fuchsia = "#FF00FF",
    purple = "#800080",
    orange = "#FFA500"
}

function CSSParser:init()
    self.css = ""
    self.pos = 1
    self.length = 0
end

-- Parse stylesheet (from <style> tag)
function CSSParser:parseStylesheet(css_string)
    if not css_string or css_string == "" then
        return {}
    end

    self.css = css_string
    self.pos = 1
    self.length = #css_string

    local rules = {}

    while self.pos <= self.length do
        self:skipWhitespace()
        self:skipComments()
        self:skipWhitespace()

        if self.pos > self.length then
            break
        end

        local rule = self:parseRule()
        if rule then
            table.insert(rules, rule)
        else
            -- Skip to next rule (find next '}' or end)
            self:skipToNext()
        end
    end

    return rules
end

-- Parse single CSS rule: selector { properties }
function CSSParser:parseRule()
    self:skipWhitespace()

    -- Parse selector
    local selector = self:parseSelector()
    if not selector then
        return nil
    end

    self:skipWhitespace()

    -- Expect '{'
    if self:peek() ~= '{' then
        return nil
    end
    self:advance()

    -- Parse properties
    local properties = self:parseProperties()

    -- Expect '}'
    self:skipWhitespace()
    if self:peek() == '}' then
        self:advance()
    end

    return {
        selector = selector,
        properties = properties
    }
end

-- Parse selector (element, .class, #id)
function CSSParser:parseSelector()
    local start_pos = self.pos

    while self.pos <= self.length do
        local char = self:peek()
        if char == '{' or char == '' then
            break
        else
            self:advance()
        end
    end

    if self.pos == start_pos then
        return nil
    end

    local selector = self.css:sub(start_pos, self.pos - 1)
    return selector:match("^%s*(.-)%s*$") -- trim
end

-- Parse properties inside { }
function CSSParser:parseProperties()
    local properties = {}

    while self.pos <= self.length do
        self:skipWhitespace()

        if self:peek() == '}' or self:peek() == '' then
            break
        end

        local prop_name, prop_value = self:parseProperty()
        if prop_name and prop_value then
            properties[prop_name] = prop_value
        end

        -- Skip semicolon
        self:skipWhitespace()
        if self:peek() == ';' then
            self:advance()
        end
    end

    return properties
end

-- Parse single property: name: value
function CSSParser:parseProperty()
    self:skipWhitespace()

    -- Parse property name
    local name_start = self.pos
    while self.pos <= self.length do
        local char = self:peek()
        if char == ':' or char:match("%s") then
            break
        else
            self:advance()
        end
    end

    if self.pos == name_start then
        return nil
    end

    local prop_name = self.css:sub(name_start, self.pos - 1):lower()

    self:skipWhitespace()

    -- Expect ':'
    if self:peek() ~= ':' then
        return nil
    end
    self:advance()

    self:skipWhitespace()

    -- Parse property value (stop at ';' or '}')
    local value_start = self.pos
    while self.pos <= self.length do
        local char = self:peek()
        if char == ';' or char == '}' then
            break
        else
            self:advance()
        end
    end

    local prop_value = self.css:sub(value_start, self.pos - 1)
    prop_value = prop_value:match("^%s*(.-)%s*$") -- trim

    return prop_name, prop_value
end

-- Parse inline style attribute: style="color: red; font-size: 14px"
function CSSParser:parseInlineStyle(style_string)
    if not style_string or style_string == "" then
        return {}
    end

    self.css = style_string
    self.pos = 1
    self.length = #style_string

    return self:parseProperties()
end

-- Normalize color value (convert named colors, rgb(), hex)
function CSSParser:normalizeColor(color_value)
    if not color_value then return nil end

    color_value = color_value:lower():gsub("%s", "")

    -- Named color
    if NAMED_COLORS[color_value] then
        return NAMED_COLORS[color_value]
    end

    -- Hex color (#RGB or #RRGGBB)
    if color_value:match("^#%x+$") then
        if #color_value == 4 then
            -- #RGB -> #RRGGBB
            local r = color_value:sub(2, 2)
            local g = color_value:sub(3, 3)
            local b = color_value:sub(4, 4)
            return "#" .. r .. r .. g .. g .. b .. b
        elseif #color_value == 7 then
            return color_value:upper()
        end
    end

    -- rgb(r, g, b)
    local r, g, b = color_value:match("rgb%((%d+),(%d+),(%d+)%)")
    if r and g and b then
        return string.format("#%02X%02X%02X", tonumber(r), tonumber(g), tonumber(b))
    end

    return nil
end

-- Convert color hex string to LÖVE color table {r, g, b}
function CSSParser:hexToRGB(hex)
    if not hex or hex:sub(1, 1) ~= '#' then
        return {0, 0, 0}
    end

    local r = tonumber(hex:sub(2, 3), 16) / 255
    local g = tonumber(hex:sub(4, 5), 16) / 255
    local b = tonumber(hex:sub(6, 7), 16) / 255

    return {r, g, b}
end

-- Parse size value (convert px, pt, em to pixels)
function CSSParser:normalizeSize(size_value)
    if not size_value then return nil end

    size_value = size_value:lower():gsub("%s", "")

    -- Pixels
    local px = size_value:match("^(%d+%.?%d*)px$")
    if px then
        return tonumber(px)
    end

    -- Points (1pt = 1.333px)
    local pt = size_value:match("^(%d+%.?%d*)pt$")
    if pt then
        return tonumber(pt) * 1.333
    end

    -- Em (relative to parent font size, default 16px)
    local em = size_value:match("^(%d+%.?%d*)em$")
    if em then
        return tonumber(em) * 16
    end

    -- Just a number (assume pixels)
    local num = tonumber(size_value)
    if num then
        return num
    end

    return nil
end

-- Parse box model value (margin, padding)
-- Supports: "10px", "10px 20px", "10px 20px 30px 40px"
function CSSParser:parseBoxValue(box_value)
    if not box_value then return {0, 0, 0, 0} end

    local parts = {}
    for part in box_value:gmatch("%S+") do
        local size = self:normalizeSize(part)
        if size then
            table.insert(parts, size)
        end
    end

    if #parts == 1 then
        -- All sides
        return {parts[1], parts[1], parts[1], parts[1]}
    elseif #parts == 2 then
        -- Vertical, horizontal
        return {parts[1], parts[2], parts[1], parts[2]}
    elseif #parts == 4 then
        -- Top, right, bottom, left
        return {parts[1], parts[2], parts[3], parts[4]}
    end

    return {0, 0, 0, 0}
end

-- Apply parsed properties to a style object (resolve values)
function CSSParser:resolveProperties(properties)
    local resolved = {}

    for prop_name, prop_value in pairs(properties) do
        if prop_name == "color" or prop_name == "background-color" then
            local hex = self:normalizeColor(prop_value)
            if hex then
                resolved[prop_name] = self:hexToRGB(hex)
            end
        elseif prop_name == "font-size" then
            local size = self:normalizeSize(prop_value)
            if size then
                resolved[prop_name] = size
            end
        elseif prop_name == "width" or prop_name == "height" then
            local size = self:normalizeSize(prop_value)
            if size then
                resolved[prop_name] = size
            end
        elseif prop_name == "margin" or prop_name == "padding" then
            resolved[prop_name] = self:parseBoxValue(prop_value)
        elseif prop_name == "background-image" then
            -- Parse url(filename.png) format
            local url = prop_value:match("url%s*%(%s*['\"]?(.-)['\"]?%s*%)%s*$")
            if url then
                resolved[prop_name] = url
            end
        else
            -- Keep as-is for other properties
            resolved[prop_name] = prop_value
        end
    end

    return resolved
end

-- Skip whitespace
function CSSParser:skipWhitespace()
    while self.pos <= self.length do
        if self:peek():match("%s") then
            self:advance()
        else
            break
        end
    end
end

-- Skip CSS comments /* ... */
function CSSParser:skipComments()
    while self:peek(2) == '/*' do
        self:advance() -- skip '/'
        self:advance() -- skip '*'

        -- Find '*/'
        while self.pos <= self.length do
            if self:peek(2) == '*/' then
                self:advance() -- skip '*'
                self:advance() -- skip '/'
                break
            else
                self:advance()
            end
        end

        self:skipWhitespace()
    end
end

-- Skip to next rule (after error)
function CSSParser:skipToNext()
    while self.pos <= self.length do
        if self:peek() == '}' then
            self:advance()
            break
        else
            self:advance()
        end
    end
end

-- Peek at next N characters
function CSSParser:peek(n)
    n = n or 1
    if self.pos > self.length then
        return ""
    end
    if self.pos + n - 1 > self.length then
        return self.css:sub(self.pos, self.length)
    end
    return self.css:sub(self.pos, self.pos + n - 1)
end

-- Advance position
function CSSParser:advance(n)
    n = n or 1
    self.pos = self.pos + n
end

return CSSParser
