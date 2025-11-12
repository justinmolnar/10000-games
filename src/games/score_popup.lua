-- score_popup.lua
-- Simple score popup system for visual feedback
-- Phase 6: Popup Manager Component

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

-- ===================================================================
-- POPUP MANAGER (Phase 6)
-- ===================================================================
-- Manages a collection of score popups
-- Simplifies popup lifecycle management across games

local PopupManager = Class:extend('PopupManager')

function PopupManager:init()
    self.popups = {}
end

-- Add a new popup to the manager
function PopupManager:add(x, y, text, color, duration)
    local popup = ScorePopup:new(x, y, text, color, duration)
    table.insert(self.popups, popup)
    return popup
end

-- Update all popups, removing dead ones
function PopupManager:update(dt)
    for i = #self.popups, 1, -1 do
        local popup = self.popups[i]
        popup:update(dt)
        if not popup.alive then
            table.remove(self.popups, i)
        end
    end
end

-- Draw all active popups
function PopupManager:draw()
    for _, popup in ipairs(self.popups) do
        popup:draw()
    end
end

-- Clear all popups (useful for game reset)
function PopupManager:clear()
    self.popups = {}
end

-- Get count of active popups
function PopupManager:count()
    return #self.popups
end

-- Export both ScorePopup (for backward compatibility) and PopupManager
return {
    ScorePopup = ScorePopup,
    PopupManager = PopupManager
}
