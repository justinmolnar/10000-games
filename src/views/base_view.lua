-- base_view.lua: Base class for all windowed game views
-- Handles viewport coordinate transformation and safe scissor operations
-- Eliminates recurring bugs with viewport vs screen coordinates

local Class = require('lib.class')
local BaseView = Class:extend('BaseView')

function BaseView:init(controller)
    self.controller = controller
end

-- ABSTRACT METHOD: Override this in child classes
-- Operates in local viewport coordinates (0,0 = top-left of window content area)
-- DO NOT call love.graphics.origin() in your implementation
function BaseView:drawContent(viewport_width, viewport_height)
    error("BaseView:drawContent() must be implemented by child class: " .. self.__name)
end

-- FINAL METHOD: Do not override - handles coordinate system automatically
-- Call this from state's draw() method
function BaseView:drawWindowed(viewport_width, viewport_height)
    -- DO NOT call love.graphics.origin() here
    -- The window transformation matrix is already set up correctly by WindowController

    -- Call child implementation (operates in local viewport coordinates)
    self:drawContent(viewport_width, viewport_height)
end

-- HELPER: Set scissor region in viewport coordinates
-- Automatically converts to screen coordinates for love.graphics.setScissor
function BaseView:setScissor(viewport_x, viewport_y, width, height)
    local viewport = self.controller.viewport
    if not viewport then
        -- Fallback if no viewport (shouldn't happen in windowed mode)
        love.graphics.setScissor(viewport_x, viewport_y, width, height)
        return
    end

    -- Convert viewport coordinates to screen coordinates
    local screen_x = viewport.x + viewport_x
    local screen_y = viewport.y + viewport_y

    love.graphics.setScissor(screen_x, screen_y, width, height)
end

-- HELPER: Clear scissor region safely
function BaseView:clearScissor()
    love.graphics.setScissor()
end

-- HELPER: Get viewport position (for debugging or special cases)
function BaseView:getViewportPosition()
    local viewport = self.controller.viewport
    if viewport then
        return viewport.x, viewport.y
    end
    return 0, 0
end

-- HELPER: Check if point is inside viewport (useful for mouse events)
function BaseView:isPointInViewport(screen_x, screen_y, viewport_width, viewport_height)
    local viewport = self.controller.viewport
    if not viewport then
        return true -- No viewport, assume inside
    end

    return screen_x >= viewport.x and
           screen_x < viewport.x + viewport_width and
           screen_y >= viewport.y and
           screen_y < viewport.y + viewport_height
end

return BaseView
