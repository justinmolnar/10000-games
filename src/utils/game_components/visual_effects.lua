-- VisualEffects: Unified visual effects system (camera shake, screen flash, particles)
-- Combines camera shake, screen flash, and particle effects into single component
-- All effects are visual-only and do not affect game logic or demo playback

local Object = require('lib.class')
local ParticleSystem = require('src.utils.particle_system')
local VisualEffects = Object:extend('VisualEffects')

function VisualEffects:new(params)
    params = params or {}

    -- Feature flags
    self.camera_shake_enabled = params.camera_shake_enabled ~= false  -- Default true
    self.screen_flash_enabled = params.screen_flash_enabled ~= false  -- Default true
    self.particle_effects_enabled = params.particle_effects_enabled ~= false  -- Default true

    -- Camera shake state
    self.shake_mode = params.shake_mode or "exponential"  -- "exponential" or "timer"
    self.shake_intensity = 0  -- Current shake intensity
    self.shake_timer = 0  -- For timer mode
    self.shake_decay = params.shake_decay or 0.9  -- Decay rate per frame (exponential mode)
    self.shake_offset_x = 0
    self.shake_offset_y = 0

    -- Screen flash state
    self.flash_color = nil  -- {r, g, b, a}
    self.flash_timer = 0
    self.flash_duration = 0
    self.flash_mode = "fade_out"  -- Current flash mode
    self.flash_initial_alpha = 0

    -- Particle system
    self.particle_system = self.particle_effects_enabled and ParticleSystem:new() or nil

    return self
end

-- Camera Shake: Trigger camera shake effect
-- mode: "exponential" (smooth decay) or "timer" (linear fade)
function VisualEffects:shake(duration, intensity, mode)
    if not self.camera_shake_enabled then return end

    mode = mode or self.shake_mode
    intensity = intensity or 5.0

    if mode == "exponential" then
        -- Exponential decay mode: intensity decays smoothly
        self.shake_intensity = math.max(self.shake_intensity, intensity)
        self.shake_mode = "exponential"
    elseif mode == "timer" then
        -- Timer mode: shake for fixed duration with linear fade
        self.shake_timer = duration or 0.15
        self.shake_intensity = intensity
        self.shake_mode = "timer"
    end
end

-- Camera Shake: Get current shake offset
function VisualEffects:getShakeOffset()
    return {x = self.shake_offset_x, y = self.shake_offset_y}
end

-- Camera Shake: Apply shake offset (call before drawing game)
function VisualEffects:applyCameraShake()
    if self.shake_offset_x ~= 0 or self.shake_offset_y ~= 0 then
        love.graphics.translate(self.shake_offset_x, self.shake_offset_y)
    end
end

-- Screen Flash: Trigger screen flash effect
-- color: {r, g, b, a} (0-1 range)
-- duration: seconds
-- mode: "fade_out" (fade alpha to 0), "pulse" (fade in then out), "instant" (hold then disappear)
function VisualEffects:flash(color, duration, mode)
    if not self.screen_flash_enabled then return end

    self.flash_color = color or {1, 1, 1, 0.5}
    self.flash_duration = duration or 0.2
    self.flash_timer = self.flash_duration
    self.flash_mode = mode or "fade_out"
    self.flash_initial_alpha = self.flash_color[4]
end

-- Screen Flash: Draw flash overlay (call after drawing game)
function VisualEffects:drawScreenFlash(width, height)
    if self.flash_color and self.flash_timer > 0 then
        love.graphics.setColor(self.flash_color)
        love.graphics.rectangle('fill', 0, 0, width, height)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Particles: Emit ball trail (Breakout)
function VisualEffects:emitBallTrail(x, y, vx, vy)
    if self.particle_system then
        self.particle_system:emitBallTrail(x, y, vx, vy)
    end
end

-- Particles: Emit confetti (Coin Flip, RPS)
function VisualEffects:emitConfetti(x, y, count)
    if self.particle_system then
        self.particle_system:emitConfetti(x, y, count)
    end
end

-- Particles: Emit brick destruction (Breakout)
function VisualEffects:emitBrickDestruction(x, y, color)
    if self.particle_system then
        self.particle_system:emitBrickDestruction(x, y, color)
    end
end

-- Particles: Draw all particles (call at end of draw)
function VisualEffects:drawParticles()
    if self.particle_system then
        self.particle_system:draw()
    end
end

-- Update: Update all effects
function VisualEffects:update(dt)
    -- Update camera shake
    if self.shake_mode == "exponential" then
        -- Exponential decay mode
        if self.shake_intensity > 0 then
            self.shake_intensity = self.shake_intensity * self.shake_decay

            -- Clear shake when intensity drops below threshold
            if self.shake_intensity < 0.1 then
                self.shake_intensity = 0
                self.shake_offset_x = 0
                self.shake_offset_y = 0
            else
                -- Generate random shake offset
                self.shake_offset_x = (math.random() - 0.5) * 2 * self.shake_intensity
                self.shake_offset_y = (math.random() - 0.5) * 2 * self.shake_intensity
            end
        end
    elseif self.shake_mode == "timer" then
        -- Timer mode
        if self.shake_timer > 0 then
            self.shake_timer = self.shake_timer - dt

            if self.shake_timer <= 0 then
                self.shake_offset_x = 0
                self.shake_offset_y = 0
            else
                -- Shake strength proportional to remaining time
                local shake_strength = self.shake_timer * self.shake_intensity
                self.shake_offset_x = (math.random() - 0.5) * shake_strength
                self.shake_offset_y = (math.random() - 0.5) * shake_strength
            end
        end
    end

    -- Update screen flash
    if self.flash_timer > 0 then
        self.flash_timer = self.flash_timer - dt

        if self.flash_timer <= 0 then
            self.flash_color = nil
        else
            -- Update alpha based on mode
            if self.flash_mode == "fade_out" then
                -- Fade alpha from initial to 0
                local progress = self.flash_timer / self.flash_duration
                self.flash_color[4] = self.flash_initial_alpha * progress
            elseif self.flash_mode == "pulse" then
                -- Pulse: fade in first half, fade out second half
                local progress = self.flash_timer / self.flash_duration
                if progress > 0.5 then
                    -- Fade in (first half)
                    self.flash_color[4] = self.flash_initial_alpha * (1 - (progress - 0.5) * 2)
                else
                    -- Fade out (second half)
                    self.flash_color[4] = self.flash_initial_alpha * (progress * 2)
                end
            elseif self.flash_mode == "instant" then
                -- Hold full alpha, then disappear
                self.flash_color[4] = self.flash_initial_alpha
            end
        end
    end

    -- Update particle system
    if self.particle_system then
        self.particle_system:update(dt)
    end
end

return VisualEffects
