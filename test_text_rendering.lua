
-- Mock Love2D
local love = {
    graphics = {
        newFont = function(size)
            return {
                size = size,
                getWidth = function(self, text) return #text * 10 end,
                getHeight = function(self) return 14 end
            }
        end,
        getFont = function()
            return {
                getWidth = function(self, text) return #text * 10 end,
                getHeight = function(self) return 14 end
            }
        end,
        setFont = function(font) print("Debug: setFont called with font", font) end,
        setColor = function(r, g, b, a) print(string.format("Debug: setColor called with %.2f, %.2f, %.2f", r or 0, g or 0, b or 0)) end,
        print = function(text, x, y) print(string.format("Debug: print called with '%s' at (%s, %s)", text, tostring(x), tostring(y))) end,
        push = function() end,
        pop = function() end,
        translate = function(x, y) print(string.format("Debug: translate called with %s, %s", tostring(x), tostring(y))) end,
        setScissor = function() end,
        circle = function() end,
        rectangle = function() end,
        line = function() end
    },
    filesystem = {
        read = function() return "" end
    }
}
_G.love = love

-- Set package path to find modules
package.path = "./?.lua;./lib/?.lua;" .. package.path

-- Require modules
local HTMLRenderer = require('src.utils.html_renderer')
local HTMLLayout = require('src.utils.html_layout')

-- Test Setup
local renderer = HTMLRenderer:new(love.graphics)
local layout_engine = HTMLLayout:new()

-- Create a fake layout tree (simulating what HTMLLayout produces)
-- Based on: <p>Hello World</p>
local fake_layout = {
    element = { tag = "body", type = "element" },
    x = 0, y = 0, width = 800, height = 600,
    children = {
        {
            element = { tag = "p", type = "element" },
            x = 10, y = 10, width = 780, height = 20,
            children = {
                 {
                    element = { type = "text", content = "Hello World" },
                    x = 10, y = 10, width = 780, height = 20,
                    content_x = 10, content_y = 10, content_width = 780, content_height = 20,
                    lines = { "Hello World" },
                    line_height = 16.8, -- 14 * 1.2
                    styles = {
                        ["font-size"] = 14,
                        color = {0, 0, 0}
                    }
                }
            }
        }
    },
    styles = { ["background-color"] = {1, 1, 1} }
}

print("=== Starting Render Test ===")
renderer:render(fake_layout, 0, 0, 0, 800, 600)
print("=== End Render Test ===")
