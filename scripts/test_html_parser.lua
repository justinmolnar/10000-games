-- scripts/test_html_parser.lua
-- Test script for HTML parser

-- Add project root to package path
package.path = package.path .. ";./?.lua"

local HTMLParser = require('src.utils.html_parser')

-- Helper function to print DOM tree
local function printDOM(node, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)

    if node.type == "text" then
        -- Trim whitespace for display
        local text = node.content:gsub("^%s+", ""):gsub("%s+$", "")
        if text ~= "" then
            print(prefix .. "[TEXT] " .. text:sub(1, 60) .. (text:len() > 60 and "..." or ""))
        end
    elseif node.type == "comment" then
        local comment = node.content:gsub("^%s+", ""):gsub("%s+$", "")
        print(prefix .. "[COMMENT] " .. comment:sub(1, 60) .. (comment:len() > 60 and "..." or ""))
    elseif node.tag then
        local attr_str = ""
        if node.attributes and next(node.attributes) then
            local attrs = {}
            for k, v in pairs(node.attributes) do
                if v == true then
                    table.insert(attrs, k)
                else
                    table.insert(attrs, k .. '="' .. tostring(v) .. '"')
                end
            end
            attr_str = " [" .. table.concat(attrs, ", ") .. "]"
        end

        print(prefix .. "<" .. node.tag .. ">" .. attr_str)

        if node.children then
            for _, child in ipairs(node.children) do
                printDOM(child, indent + 1)
            end
        end

        print(prefix .. "</" .. node.tag .. ">")
    end
end

-- Test function
local function testFile(filename)
    print("\n" .. string.rep("=", 70))
    print("Testing: " .. filename)
    print(string.rep("=", 70))

    -- Read file
    local file = io.open(filename, "r")
    if not file then
        print("ERROR: Could not open file " .. filename)
        return
    end

    local html = file:read("*all")
    file:close()

    -- Parse HTML
    local parser = HTMLParser:new()
    local dom = parser:parse(html)

    -- Print DOM tree
    printDOM(dom)

    print("\n✓ Parse completed successfully\n")
end

-- Run tests
print("\n╔═══════════════════════════════════════════════════════════════════╗")
print("║              HTML Parser Test Suite - Phase 1                    ║")
print("╚═══════════════════════════════════════════════════════════════════╝")

testFile("assets/data/web/test_basic.html")
testFile("assets/data/web/test_nested.html")
testFile("assets/data/web/test_comments.html")

print("\n" .. string.rep("=", 70))
print("All tests completed!")
print(string.rep("=", 70))
