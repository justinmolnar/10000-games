-- src/states/completion_state.lua
local Object = require('class')
local CompletionView = require('src.views.completion_view')

local CompletionState = Object:extend('CompletionState')

function CompletionState:init(state_machine, statistics)
    self.state_machine = state_machine
    self.statistics = statistics -- Injected statistics model
    self.view = CompletionView:new(self)
end

function CompletionState:enter()
    print("Entered MVP Completion Screen")
    -- Maybe play a victory sound?
end

function CompletionState:update(dt)
    self.view:update(dt)
end

function CompletionState:draw()
    -- Draw the underlying state (e.g., Space Defender) dimly? For now, just overlay.
    -- Or grab a screenshot and draw that blurred? Simple overlay is fine for MVP.
    self.view:draw(self.statistics:getAllStats())
end

function CompletionState:keypressed(key)
    -- Allow ESC to quit? Or force button press? Let's force buttons.
    return false -- Don't handle keys here, use mouse
end

function CompletionState:mousepressed(x, y, button)
    local event = self.view:mousepressed(x, y, button)
    if not event then return false end

    if event.name == "button_click" then
        if event.id == "stats" then
            -- Go to stats screen, make sure it knows to return here
            self.state_machine:switch('statistics', 'completion') -- Pass 'completion' as previous_state
        elseif event.id == "continue" then
            -- Go back to desktop
            self.state_machine:switch('desktop')
        elseif event.id == "quit" then
            love.event.quit()
        end
        return true -- Handled
    end
    return false
end

-- Need to add a way for StatisticsState to return here if launched from completion
-- Let's modify StatisticsState:goBack to handle this (Done in StatisticsState modification above)

return CompletionState