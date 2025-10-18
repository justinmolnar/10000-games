-- src/states/statistics_state.lua
local Object = require('class')
local StatisticsView = require('src.views.statistics_view')

local StatisticsState = Object:extend('StatisticsState')

-- Pass previous_state default in init
function StatisticsState:init(state_machine, statistics)
    self.state_machine = state_machine
    self.statistics = statistics -- Injected statistics model
    self.view = StatisticsView:new(self)
    self.previous_state = 'desktop' -- State to return to (default) - Not used in windowed mode
    self.viewport = nil
end

function StatisticsState:setViewport(x, y, width, height)
    self.viewport = {x = x, y = y, width = width, height = height}
    self.view:updateLayout(width, height)
end

function StatisticsState:enter(previous_state)
    print("Entered Statistics Window")
    -- self.previous_state = previous_state or 'desktop' -- Not needed for window close
end

function StatisticsState:update(dt)
     if not self.viewport then return end
    self.view:update(dt)
end

function StatisticsState:draw()
    if not self.viewport then return end

    love.graphics.push()
    love.graphics.translate(self.viewport.x, self.viewport.y)
    love.graphics.setScissor(self.viewport.x, self.viewport.y, self.viewport.width, self.viewport.height)

    self.view:drawWindowed(self.statistics:getAllStats(), self.viewport.width, self.viewport.height)

    love.graphics.setScissor()
    love.graphics.pop()
end

function StatisticsState:keypressed(key)
    if key == 'escape' then
        -- Signal close instead of switching
        return { type = "close_window" }
    end
    return false
end

function StatisticsState:mousepressed(x, y, button)
    if not self.viewport then return false end
    local local_x = x - self.viewport.x
    local local_y = y - self.viewport.y
    if local_x < 0 or local_x > self.viewport.width or local_y < 0 or local_y > self.viewport.height then
        return false -- Click outside content area
    end

    local event = self.view:mousepressed(local_x, local_y, button) -- Pass local coords
    if event and event.name == "back" then
        -- Don't switch state, signal close
        return { type = "close_window" }
    end
    -- Return true if view handled it (even if no specific action taken by state)
    return event and { type = "content_interaction" } or false
end

-- goBack is no longer needed as closing is handled via signal

return StatisticsState