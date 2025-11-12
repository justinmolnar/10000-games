-- score_popup.lua
-- Simple score popup system for visual feedback
-- Phase 10: Victory Conditions & Scoring

local Class = require('lib.class')
local ScorePopup = Class:extend('ScorePopup')

function ScorePopup:init(x, y, text, color, duration)
    self.x = x
    self.y = y
    self.start_y = y
    self.text = text
    self.color = color or {1, 1, 1}  -- Default white
    self.duration = duration or 1.5  -- Default 1.5 seconds
    self.time_elapsed = 0
    self.alive = true

    -- Movement
    self.rise_speed = 50  -- Pixels per second
end

function ScorePopup:update(dt)
    self.time_elapsed = self.time_elapsed + dt

    -- Rise upward
    self.y = self.y - self.rise_speed * dt

    -- Mark as dead when duration expires
    if self.time_elapsed >= self.duration then
        self.alive = false
    end
end

function ScorePopup:draw()
    if not self.alive then
        return
    end

    -- Calculate alpha based on time (fade out)
    local alpha = 1.0 - (self.time_elapsed / self.duration)

    love.graphics.push()
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
    love.graphics.print(self.text, self.x, self.y)
    love.graphics.pop()
end

return ScorePopup
