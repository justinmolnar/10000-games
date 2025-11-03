-- Temporary test file to run parser tests in LÖVE

-- Setup require path for lib/class.lua
local Object = require('lib.class')

local HTMLParser = require('src.utils.html_parser')

local test_results = {}
local current_test = ""

-- Helper function to capture print output
local function printDOM(node, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    local output = ""

    if node.type == "text" then
        local text = node.content:gsub("^%s+", ""):gsub("%s+$", "")
        if text ~= "" then
            output = prefix .. "[TEXT] " .. text:sub(1, 60) .. (text:len() > 60 and "..." or "")
        end
    elseif node.type == "comment" then
        local comment = node.content:gsub("^%s+", ""):gsub("%s+$", "")
        output = prefix .. "[COMMENT] " .. comment:sub(1, 60) .. (comment:len() > 60 and "..." or "")
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

        output = prefix .. "<" .. node.tag .. ">" .. attr_str
        table.insert(test_results, output)

        if node.children then
            for _, child in ipairs(node.children) do
                printDOM(child, indent + 1)
            end
        end

        output = prefix .. "</" .. node.tag .. ">"
    end

    if output ~= "" then
        table.insert(test_results, output)
    end
end

function love.load()
    print("\n╔═══════════════════════════════════════════════════════════════════╗")
    print("║              HTML Parser Test Suite - Phase 1                    ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")

    local test_files = {
        "assets/data/web/test_basic.html",
        "assets/data/web/test_nested.html",
        "assets/data/web/test_comments.html"
    }

    for _, filename in ipairs(test_files) do
        print("\n" .. string.rep("=", 70))
        print("Testing: " .. filename)
        print(string.rep("=", 70))

        local success, html = pcall(love.filesystem.read, filename)
        if not success or not html then
            print("ERROR: Could not read file " .. filename)
        else
            local parser = HTMLParser:new()
            local parse_success, dom = pcall(parser.parse, parser, html)

            if not parse_success then
                print("ERROR: Parse failed - " .. tostring(dom))
            else
                test_results = {}
                printDOM(dom)

                -- Print results
                for _, line in ipairs(test_results) do
                    print(line)
                end

                print("\n✓ Parse completed successfully")
            end
        end
    end

    print("\n" .. string.rep("=", 70))
    print("All tests completed! Press Escape to exit.")
    print(string.rep("=", 70))
end

function love.draw()
    love.graphics.print("HTML Parser tests complete. Check console output.", 10, 10)
    love.graphics.print("Press Escape to exit", 10, 30)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
