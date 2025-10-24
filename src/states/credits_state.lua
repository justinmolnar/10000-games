-- src/states/credits_state.lua
local Object = require('class')
local CreditsView = require('src.views.credits_view')

local CreditsState = Object:extend('CreditsState')

function CreditsState:init(state_machine, di)
    self.state_machine = state_machine
    self.di = di
    self.attributionManager = di.attributionManager
    self.view = CreditsView:new(self)
    self.previous_state = 'desktop'
    self.viewport = nil
end

function CreditsState:setViewport(x, y, width, height)
    self.viewport = {x = x, y = y, width = width, height = height}
    self.view:updateLayout(width, height)
end

function CreditsState:enter(previous_state)
    print("Entered Credits Window")
end

function CreditsState:update(dt)
    if not self.viewport then return end
    self.view:update(dt)
end

function CreditsState:draw()
    if not self.viewport then return end
    self.view:drawWindowed(self.viewport.width, self.viewport.height)
end

function CreditsState:keypressed(key)
    if key == 'escape' then
        return { type = "close_window" }
    end
    return false
end

function CreditsState:mousepressed(x, y, button)
    if not self.viewport then return false end

    if x < 0 or x > self.viewport.width or y < 0 or y > self.viewport.height then
        return false
    end

    local event = self.view:mousepressed(x, y, button)
    if event and event.name == "close" then
        return { type = "close_window" }
    end

    return event and { type = "content_interaction" } or false
end

function CreditsState:wheelmoved(x, y)
    if not self.viewport then return false end

    local mx, my = love.mouse.getPosition()
    local view_x = self.viewport.x
    local view_y = self.viewport.y
    local local_mx = mx - view_x
    local local_my = my - view_y

    -- Only scroll if mouse is inside viewport
    if local_mx >= 0 and local_mx <= self.viewport.width and
       local_my >= 0 and local_my <= self.viewport.height then
        self.view:wheelmoved(x, y)
        return { type = "content_interaction" }
    end

    return false
end

return CreditsState
