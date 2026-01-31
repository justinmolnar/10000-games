--[[
EffectSystem - Tracks active timed effects

A minimal, truly generic component that only manages effect durations.
Games handle what effects actually DO via on_expire callback.

Usage:
    self.effect_system = EffectSystem:new({
        on_expire = function(effect_type, data)
            -- revert the effect using stored data
        end
    })

    -- When collecting a powerup:
    local orig = self.player.speed
    self.player.speed = self.player.speed * 2
    self.effect_system:activate("speed_boost", 10.0, {orig_speed = orig})

    -- In update:
    self.effect_system:update(dt)
]]

local Object = require('class')
local EffectSystem = Object:extend('EffectSystem')

function EffectSystem:new(config)
    if not config then error("EffectSystem: config required") end
    if not config.on_expire then error("EffectSystem: on_expire callback required") end

    local instance = EffectSystem.super.new(self)
    instance.on_expire = config.on_expire
    instance.active_effects = {}  -- {type = {duration_remaining, data}}
    return instance
end

-- Start a timed effect
-- type: string identifier
-- duration: seconds until expiration
-- data: arbitrary data stored for on_expire callback (e.g., original values to restore)
function EffectSystem:activate(effect_type, duration, data)
    if not effect_type then error("EffectSystem:activate: effect_type required") end
    if not duration then error("EffectSystem:activate: duration required") end

    -- If effect already active, call on_expire first to clean up
    if self.active_effects[effect_type] then
        self.on_expire(effect_type, self.active_effects[effect_type].data)
    end

    self.active_effects[effect_type] = {
        duration_remaining = duration,
        data = data or {}
    }
end

-- Manually end an effect early
function EffectSystem:deactivate(effect_type)
    local effect = self.active_effects[effect_type]
    if effect then
        self.on_expire(effect_type, effect.data)
        self.active_effects[effect_type] = nil
    end
end

-- Tick durations, call on_expire for expired effects
function EffectSystem:update(dt)
    for effect_type, effect in pairs(self.active_effects) do
        effect.duration_remaining = effect.duration_remaining - dt
        if effect.duration_remaining <= 0 then
            self.on_expire(effect_type, effect.data)
            self.active_effects[effect_type] = nil
        end
    end
end

-- Check if effect is active
function EffectSystem:isActive(effect_type)
    return self.active_effects[effect_type] ~= nil
end

-- Get remaining duration (0 if not active)
function EffectSystem:getTimeRemaining(effect_type)
    local effect = self.active_effects[effect_type]
    return effect and effect.duration_remaining or 0
end

-- Get all active effects for HUD rendering
-- Returns {type = {duration_remaining, data}}
function EffectSystem:getActiveEffects()
    return self.active_effects
end

-- Clear all active effects (calls on_expire for each)
function EffectSystem:clear()
    for effect_type, effect in pairs(self.active_effects) do
        self.on_expire(effect_type, effect.data)
    end
    self.active_effects = {}
end

-- Get count of active effects
function EffectSystem:getActiveCount()
    local count = 0
    for _ in pairs(self.active_effects) do
        count = count + 1
    end
    return count
end

return EffectSystem
