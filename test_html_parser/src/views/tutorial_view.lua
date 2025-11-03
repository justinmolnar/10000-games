-- src/views/tutorial_view.lua
local Object = require('class')
local UIComponents = require('src.views.ui_components')
local TutorialView = Object:extend('TutorialView')

function TutorialView:init(controller)
    self.controller = controller -- DesktopState

    self.steps = {
        "Welcome to 10,000 Games!",
        "",
        "1. Double-click [Game Collection] to find games.",
        "2. Unlock games using Tokens.",
        "3. Play games well! Your performance determines the",
        "   power of bullets you unlock for [Space Defender].",
        "   (Check formulas in the Collection!)",
        "",
        "4. Use [VM Manager] to automate completed games",
        "   and generate Tokens passively.",
        "",
        "5. Play [Space Defender] to progress through levels",
        "   using your unlocked bullets.",
        "",
        "Tip: Use [CheatEngine] to spend Tokens and make",
        "     difficult games easier (cost scales!).",
        "",
        "Good luck!"
    }

    self.box_x = 100
    self.box_y = 100
    self.box_w = love.graphics.getWidth() - 200
    self.box_h = love.graphics.getHeight() - 200
    self.button_w = 150
    self.button_h = 40
    self.button_x = self.box_x + (self.box_w - self.button_w) / 2
    self.button_y = self.box_y + self.box_h - self.button_h - 20
    self.hovered = false
end

function TutorialView:update(dt)
    local mx, my = love.mouse.getPosition()
    self.hovered = mx >= self.button_x and mx <= self.button_x + self.button_w and
                   my >= self.button_y and my <= self.button_y + self.button_h
end

function TutorialView:draw()
    -- Semi-transparent background overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Tutorial Panel
    UIComponents.drawPanel(self.box_x, self.box_y, self.box_w, self.box_h, {0.1, 0.1, 0.3})

    -- Title
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("Quick Start Guide", self.box_x, self.box_y + 20, self.box_w, "center")

    -- Text Steps
    love.graphics.setColor(1, 1, 1)
    local line_y = self.box_y + 60
    local line_height = 18
    for i, line in ipairs(self.steps) do
        love.graphics.print(line, self.box_x + 20, line_y)
        line_y = line_y + line_height
    end

    -- Dismiss Button
    UIComponents.drawButton(self.button_x, self.button_y, self.button_w, self.button_h, "Got it!", true, self.hovered)
end

function TutorialView:mousepressed(x, y, button)
    if button ~= 1 then return nil end
    if x >= self.button_x and x <= self.button_x + self.button_w and
       y >= self.button_y and y <= self.button_y + self.button_h then
        return { name = "dismiss_tutorial" }
    end
    return nil
end

function TutorialView:keypressed(key)
    if key == 'return' or key == 'escape' or key == 'space' then
        return { name = "dismiss_tutorial" }
    end
    return nil
end

return TutorialView