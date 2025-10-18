-- src/states/statistics_state.lua
local Object = require('class')
local StatisticsView = require('src.views.statistics_view')

local StatisticsState = Object:extend('StatisticsState')

-- Pass previous_state default in init
function StatisticsState:init(state_machine, statistics)
    self.state_machine = state_machine
    self.statistics = statistics -- Injected statistics model
    self.view = StatisticsView:new(self)
    self.previous_state = 'desktop' -- State to return to (default)
end

function StatisticsState:enter(previous_state)
    print("Entered Statistics Screen")
    self.previous_state = previous_state or 'desktop' -- Update return state if provided
    print("Will return to: " .. self.previous_state)
end

function StatisticsState:update(dt)
    self.view:update(dt)
end

function StatisticsState:draw()
    -- Optional: Draw previous state underneath? For MVP, just show stats.
    self.view:draw(self.statistics:getAllStats())
end

function StatisticsState:keypressed(key)
    if key == 'escape' then
        self:goBack()
        return true
    end
    return false
end

function StatisticsState:mousepressed(x, y, button)
    local event = self.view:mousepressed(x, y, button)
    if event and event.name == "back" then
        self:goBack()
        return true
    end
    return false
end

function StatisticsState:goBack()
    -- Switch back to the stored previous state
    print("Returning from Statistics to: " .. self.previous_state)
    self.state_machine:switch(self.previous_state)
end

return StatisticsState