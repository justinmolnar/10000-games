-- src/utils/html_parser.lua
-- Parse HTML 3.2-era markup into DOM tree structure

local Object = require('lib.class')
local HTMLParser = Object:extend('HTMLParser')

-- Self-closing tags (no closing tag needed)
local VOID_ELEMENTS = {
    br = true,
    hr = true,
    img = true,
    input = true,
    meta = true,
    link = true,
    area = true,
    base = true,
    col = true,
    param = true
}

function HTMLParser:init()
    self.html = ""
    self.pos = 1
    self.length = 0
end

-- Main parse function
function HTMLParser:parse(html_string)
    if not html_string or html_string == "" then
        return { tag = "html", attributes = {}, children = {} }
    end

    self.html = html_string
    self.pos = 1
    self.length = #html_string

    local root = { tag = "html", attributes = {}, children = {} }

    -- Find <html> tag or start parsing from beginning
    local html_start = string.find(html_string, "<html", 1, true)
    if html_start then
        self.pos = html_start
        root = self:parseElement()
    else
        -- No <html> tag, treat entire document as body content
        root.children = self:parseChildren(nil)
    end

    return root
end

-- Parse a single element (opening tag + children + closing tag)
function HTMLParser:parseElement()
    local start_pos = self.pos

    -- Expect '<'
    if self:peek() ~= '<' then
        return nil
    end

    self:advance() -- skip '<'

    -- Check for comment
    if self:peek(3) == '!--' then
        return self:parseComment()
    end

    -- Parse tag name and attributes
    local tag_name, attributes, self_closing = self:parseOpeningTag()

    if not tag_name then
        return nil
    end

    local element = {
        tag = tag_name,
        attributes = attributes,
        children = {}
    }

    -- Void elements or self-closing tags have no children
    if VOID_ELEMENTS[tag_name] or self_closing then
        return element
    end

    -- Special handling for <script> and <style> - capture raw content
    if tag_name == "script" or tag_name == "style" then
        local content = self:parseRawContent(tag_name)
        if content then
            table.insert(element.children, { type = "text", content = content })
        end
        return element
    end

    -- Parse children until closing tag
    element.children = self:parseChildren(tag_name)

    return element
end

-- Parse opening tag: <tagname attr="value">
function HTMLParser:parseOpeningTag()
    local start_pos = self.pos

    -- Parse tag name
    local tag_name = self:parseTagName()
    if not tag_name then
        return nil
    end

    tag_name = tag_name:lower()

    -- Parse attributes
    local attributes = {}
    local self_closing = false

    while true do
        self:skipWhitespace()

        local char = self:peek()

        if char == '>' then
            self:advance()
            break
        elseif char == '/' and self:peek(2) == '/>' then
            self:advance() -- skip '/'
            self:advance() -- skip '>'
            self_closing = true
            break
        elseif char == '' then
            -- End of string without closing '>'
            break
        else
            -- Parse attribute
            local attr_name, attr_value = self:parseAttribute()
            if attr_name then
                attributes[attr_name] = attr_value
            else
                -- Skip invalid character
                self:advance()
            end
        end
    end

    return tag_name, attributes, self_closing
end

-- Parse tag name (alphanumeric + hyphen)
function HTMLParser:parseTagName()
    local start_pos = self.pos

    while self.pos <= self.length do
        local char = self:peek()
        if char:match("[%w%-]") then
            self:advance()
        else
            break
        end
    end

    if self.pos == start_pos then
        return nil
    end

    return self.html:sub(start_pos, self.pos - 1)
end

-- Parse attribute: name="value" or name='value' or name or name=value
function HTMLParser:parseAttribute()
    self:skipWhitespace()

    -- Parse attribute name
    local name_start = self.pos
    while self.pos <= self.length do
        local char = self:peek()
        if char:match("[%w%-_:]") then
            self:advance()
        else
            break
        end
    end

    if self.pos == name_start then
        return nil
    end

    local attr_name = self.html:sub(name_start, self.pos - 1):lower()

    self:skipWhitespace()

    -- Check for '='
    if self:peek() ~= '=' then
        -- Boolean attribute (e.g., <input disabled>)
        return attr_name, true
    end

    self:advance() -- skip '='
    self:skipWhitespace()

    -- Parse attribute value
    local quote = self:peek()
    local attr_value = ""

    if quote == '"' or quote == "'" then
        -- Quoted value
        self:advance() -- skip opening quote
        local value_start = self.pos

        while self.pos <= self.length do
            if self:peek() == quote then
                attr_value = self.html:sub(value_start, self.pos - 1)
                self:advance() -- skip closing quote
                break
            else
                self:advance()
            end
        end
    else
        -- Unquoted value (stop at whitespace or >)
        local value_start = self.pos
        while self.pos <= self.length do
            local char = self:peek()
            if char:match("%s") or char == '>' then
                break
            else
                self:advance()
            end
        end
        attr_value = self.html:sub(value_start, self.pos - 1)
    end

    return attr_name, attr_value
end

-- Parse children until closing tag
function HTMLParser:parseChildren(parent_tag)
    local children = {}

    while self.pos <= self.length do
        self:skipWhitespace()

        if self.pos > self.length then
            break
        end

        local char = self:peek()

        if char == '<' then
            -- Check for closing tag
            if self:peek(2):sub(2, 2) == '/' then
                -- Found closing tag
                local closing_tag = self:parseClosingTag()
                if closing_tag == parent_tag then
                    break
                else
                    -- Mismatched closing tag, ignore and continue
                    -- (Browsers are forgiving, so we are too)
                end
            else
                -- Opening tag or comment
                local element = self:parseElement()
                if element then
                    table.insert(children, element)
                else
                    -- Failed to parse element, skip '<'
                    self:advance()
                end
            end
        else
            -- Text content
            local text = self:parseText()
            if text and text ~= "" then
                table.insert(children, { type = "text", content = text })
            end
        end
    end

    return children
end

-- Parse closing tag: </tagname>
function HTMLParser:parseClosingTag()
    if self:peek(2) ~= '</' then
        return nil
    end

    self:advance() -- skip '<'
    self:advance() -- skip '/'

    local tag_name = self:parseTagName()

    -- Skip to '>'
    while self.pos <= self.length do
        if self:peek() == '>' then
            self:advance()
            break
        else
            self:advance()
        end
    end

    return tag_name and tag_name:lower() or nil
end

-- Parse text node (stop at '<')
function HTMLParser:parseText()
    local start_pos = self.pos

    while self.pos <= self.length do
        if self:peek() == '<' then
            break
        else
            self:advance()
        end
    end

    if self.pos == start_pos then
        return ""
    end

    local text = self.html:sub(start_pos, self.pos - 1)

    -- Decode HTML entities
    text = self:decodeEntities(text)

    return text
end

-- Parse HTML comment: <!-- comment -->
function HTMLParser:parseComment()
    -- Already verified we're at '<!--'
    self:advance() -- skip '!'
    self:advance() -- skip '-'
    self:advance() -- skip '-'

    local start_pos = self.pos

    -- Find '-->'
    while self.pos <= self.length do
        if self:peek(3) == '-->' then
            local content = self.html:sub(start_pos, self.pos - 1)
            self:advance() -- skip '-'
            self:advance() -- skip '-'
            self:advance() -- skip '>'
            return { type = "comment", content = content }
        else
            self:advance()
        end
    end

    -- Unclosed comment
    return { type = "comment", content = self.html:sub(start_pos, self.length) }
end

-- Parse raw content for <script> and <style> tags
function HTMLParser:parseRawContent(tag_name)
    local start_pos = self.pos
    local closing_tag = "</" .. tag_name

    -- Find closing tag
    local close_pos = string.find(self.html, closing_tag, self.pos, true)

    if close_pos then
        local content = self.html:sub(start_pos, close_pos - 1)
        self.pos = close_pos
        self:parseClosingTag() -- consume closing tag
        return content
    else
        -- No closing tag, take rest of document
        local content = self.html:sub(start_pos, self.length)
        self.pos = self.length + 1
        return content
    end
end

-- Decode common HTML entities
function HTMLParser:decodeEntities(text)
    if not text then return "" end

    local entities = {
        ["&lt;"] = "<",
        ["&gt;"] = ">",
        ["&amp;"] = "&",
        ["&quot;"] = '"',
        ["&apos;"] = "'",
        ["&nbsp;"] = " ",
        ["&#39;"] = "'",
        ["&#34;"] = '"',
        ["&copy;"] = "©"
    }

    for entity, char in pairs(entities) do
        text = text:gsub(entity, char)
    end

    return text
end

-- Peek at next N characters without advancing
function HTMLParser:peek(n)
    n = n or 1
    if self.pos > self.length then
        return ""
    end
    if self.pos + n - 1 > self.length then
        return self.html:sub(self.pos, self.length)
    end
    return self.html:sub(self.pos, self.pos + n - 1)
end

-- Advance position by N characters
function HTMLParser:advance(n)
    n = n or 1
    self.pos = self.pos + n
end

-- Skip whitespace characters
function HTMLParser:skipWhitespace()
    while self.pos <= self.length do
        if self:peek():match("%s") then
            self:advance()
        else
            break
        end
    end
end

return HTMLParser
