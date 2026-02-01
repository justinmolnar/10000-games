-- VisualEffects: Unified visual effects system (camera shake, screen flash, particles)
-- All effects are visual-only and do not affect game logic or demo playback

local Object = require('lib.class')
local ParticleSystem = require('src.utils.particle_system')
local VisualEffects = Object:extend('VisualEffects')

function VisualEffects:new(config)
    if not config then error("VisualEffects: config required") end

    -- Feature flags (required)
    if config.camera_shake_enabled == nil then error("VisualEffects: camera_shake_enabled required") end
    if config.screen_flash_enabled == nil then error("VisualEffects: screen_flash_enabled required") end
    if config.particle_effects_enabled == nil then error("VisualEffects: particle_effects_enabled required") end

    self.camera_shake_enabled = config.camera_shake_enabled
    self.screen_flash_enabled = config.screen_flash_enabled
    self.particle_effects_enabled = config.particle_effects_enabled

    -- Camera shake state
    self.shake_intensity = 0
    self.shake_timer = 0
    self.shake_decay = 0
    self.shake_mode = nil
    self.shake_offset_x = 0
    self.shake_offset_y = 0

    -- Screen flash state
    self.flash_color = nil
    self.flash_timer = 0
    self.flash_duration = 0
    self.flash_mode = nil
    self.flash_initial_alpha = 0

    -- Particle system (games call self.particles:emit() directly)
    self.particles = self.particle_effects_enabled and ParticleSystem:new() or nil

    return self
end

-- Camera Shake: Trigger camera shake effect
-- config: {intensity, duration (for timer mode), decay (for exponential mode), mode}
function VisualEffects:shake(config)
    if not self.camera_shake_enabled then return end
    if not config then error("VisualEffects:shake: config required") end
    if not config.intensity then error("VisualEffects:shake: intensity required") end
    if not config.mode then error("VisualEffects:shake: mode required ('exponential' or 'timer')") end

    if config.mode == "exponential" then
        if not config.decay then error("VisualEffects:shake: decay required for exponential mode") end
        self.shake_intensity = math.max(self.shake_intensity, config.intensity)
        self.shake_decay = config.decay
        self.shake_mode = "exponential"
    elseif config.mode == "timer" then
        if not config.duration then error("VisualEffects:shake: duration required for timer mode") end
        self.shake_timer = config.duration
        self.shake_intensity = config.intensity
        self.shake_mode = "timer"
    else
        error("VisualEffects:shake: unknown mode '" .. tostring(config.mode) .. "'")
    end
end

-- Camera Shake: Get current shake offset
function VisualEffects:getShakeOffset()
    return {x = self.shake_offset_x, y = self.shake_offset_y}
end

-- Camera Shake: Apply shake transform (call before drawing game content)
function VisualEffects:applyCameraShake()
    if self.shake_offset_x ~= 0 or self.shake_offset_y ~= 0 then
        love.graphics.translate(self.shake_offset_x, self.shake_offset_y)
    end
end

-- Screen Flash: Trigger screen flash effect
-- config: {color, duration, mode}
function VisualEffects:flash(config)
    if not self.screen_flash_enabled then return end
    if not config then error("VisualEffects:flash: config required") end
    if not config.color then error("VisualEffects:flash: color required") end
    if not config.duration then error("VisualEffects:flash: duration required") end
    if not config.mode then error("VisualEffects:flash: mode required ('fade_out', 'pulse', or 'instant')") end

    self.flash_color = {config.color[1], config.color[2], config.color[3], config.color[4] or 1}
    self.flash_duration = config.duration
    self.flash_timer = config.duration
    self.flash_mode = config.mode
    self.flash_initial_alpha = self.flash_color[4]
end

-- Screen Flash: Draw flash overlay (call after drawing game content)
function VisualEffects:drawScreenFlash(width, height)
    if self.flash_color and self.flash_timer > 0 then
        love.graphics.setColor(self.flash_color)
        love.graphics.rectangle('fill', 0, 0, width, height)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Particles: Draw all particles
function VisualEffects:drawParticles()
    if self.particles then
        self.particles:draw()
    end
end

-- Update all effects
function VisualEffects:update(dt)
    -- Update camera shake
    if self.shake_mode == "exponential" and self.shake_intensity > 0 then
        self.shake_intensity = self.shake_intensity * self.shake_decay
        if self.shake_intensity < 0.1 then
            self.shake_intensity = 0
            self.shake_offset_x = 0
            self.shake_offset_y = 0
        else
            self.shake_offset_x = (math.random() - 0.5) * 2 * self.shake_intensity
            self.shake_offset_y = (math.random() - 0.5) * 2 * self.shake_intensity
        end
    elseif self.shake_mode == "timer" and self.shake_timer > 0 then
        self.shake_timer = self.shake_timer - dt
        if self.shake_timer <= 0 then
            self.shake_offset_x = 0
            self.shake_offset_y = 0
        else
            local shake_strength = self.shake_timer * self.shake_intensity
            self.shake_offset_x = (math.random() - 0.5) * shake_strength
            self.shake_offset_y = (math.random() - 0.5) * shake_strength
        end
    end

    -- Update screen flash
    if self.flash_timer > 0 then
        self.flash_timer = self.flash_timer - dt
        if self.flash_timer <= 0 then
            self.flash_color = nil
        else
            local progress = self.flash_timer / self.flash_duration
            if self.flash_mode == "fade_out" then
                self.flash_color[4] = self.flash_initial_alpha * progress
            elseif self.flash_mode == "pulse" then
                if progress > 0.5 then
                    self.flash_color[4] = self.flash_initial_alpha * (1 - (progress - 0.5) * 2)
                else
                    self.flash_color[4] = self.flash_initial_alpha * (progress * 2)
                end
            elseif self.flash_mode == "instant" then
                self.flash_color[4] = self.flash_initial_alpha
            end
        end
    end

    -- Update particles
    if self.particles then
        self.particles:update(dt)
    end
end

return VisualEffects
