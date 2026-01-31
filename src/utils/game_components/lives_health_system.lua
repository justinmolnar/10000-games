local Object = require('class')
local LivesHealthSystem = Object:extend('LivesHealthSystem')

-- Unified lives/health/shield management component
-- Handles life loss, death, respawning, shields, and invincibility

LivesHealthSystem.MODES = {
    LIVES = "lives",           -- Standard lives counter
    SHIELD = "shield",         -- Regenerating shield hits
    BINARY = "binary",         -- Instant death on failure
    NONE = "none"              -- No health system
}

function LivesHealthSystem:new(config)
    local instance = LivesHealthSystem.super.new(self)

    -- Core configuration
    instance.mode = config.mode or LivesHealthSystem.MODES.LIVES

    -- Lives mode configuration
    instance.starting_lives = config.starting_lives or 3
    instance.max_lives = config.max_lives or 10
    instance.lives = instance.starting_lives

    -- Shield mode configuration
    instance.shield_enabled = config.shield_enabled or false
    instance.shield_max_hits = config.shield_max_hits or 3
    instance.shield_regen_time = config.shield_regen_time or 5.0
    instance.shield_regen_delay = config.shield_regen_delay or 2.0

    -- Shield state
    instance.shield_active = instance.shield_enabled
    instance.shield_hits_remaining = instance.shield_max_hits
    instance.shield_regen_timer = 0
    instance.shield_damage_timer = 0  -- Time since last damage

    -- Invincibility configuration
    instance.invincibility_on_hit = config.invincibility_on_hit or false
    instance.invincibility_duration = config.invincibility_duration or 2.0

    -- Invincibility state
    instance.invincible = false
    instance.invincibility_timer = 0

    -- Death/respawn state
    instance.is_dead = false
    instance.respawn_enabled = config.respawn_enabled or false
    instance.respawn_delay = config.respawn_delay or 1.0
    instance.respawn_timer = 0
    instance.waiting_to_respawn = false

    -- Extra life awards
    instance.extra_life_enabled = config.extra_life_enabled or false
    instance.extra_life_threshold = config.extra_life_threshold or 5000
    instance.last_extra_life_threshold = 0

    -- Callbacks
    instance.on_damage = config.on_damage or nil
    instance.on_death = config.on_death or nil
    instance.on_respawn = config.on_respawn or nil
    instance.on_life_gained = config.on_life_gained or nil
    instance.on_shield_break = config.on_shield_break or nil
    instance.on_shield_regen = config.on_shield_regen or nil

    return instance
end

function LivesHealthSystem:update(dt)
    -- Update invincibility timer
    if self.invincible then
        self.invincibility_timer = self.invincibility_timer - dt
        if self.invincibility_timer <= 0 then
            self.invincible = false
            self.invincibility_timer = 0
        end
    end

    -- Update respawn timer
    if self.waiting_to_respawn then
        self.respawn_timer = self.respawn_timer + dt
        if self.respawn_timer >= self.respawn_delay then
            self:respawn()
        end
    end

    -- Update shield regeneration (shield mode)
    if self.mode == LivesHealthSystem.MODES.SHIELD and self.shield_enabled then
        -- Track time since last damage
        self.shield_damage_timer = self.shield_damage_timer + dt

        -- Start regenerating if delay has passed and shield not full
        if self.shield_damage_timer >= self.shield_regen_delay and self.shield_hits_remaining < self.shield_max_hits then
            self.shield_regen_timer = self.shield_regen_timer + dt

            if self.shield_regen_timer >= self.shield_regen_time then
                self.shield_hits_remaining = self.shield_hits_remaining + 1
                self.shield_regen_timer = 0

                -- Reactivate shield if it was broken
                if not self.shield_active and self.shield_hits_remaining > 0 then
                    self.shield_active = true
                    if self.on_shield_regen then
                        self.on_shield_regen()
                    end
                end
            end
        end
    end
end

function LivesHealthSystem:takeDamage(amount, source)
    amount = amount or 1
    source = source or "unknown"

    -- Skip damage if invincible or dead
    if self.invincible or self.is_dead then
        return false
    end

    -- Binary mode: instant death
    if self.mode == LivesHealthSystem.MODES.BINARY then
        self:die()
        return true
    end

    -- None mode: no health system
    if self.mode == LivesHealthSystem.MODES.NONE then
        return false
    end

    -- Shield mode: absorb damage with shield if active
    if self.mode == LivesHealthSystem.MODES.SHIELD and self.shield_enabled and self.shield_active then
        self.shield_hits_remaining = self.shield_hits_remaining - amount
        self.shield_damage_timer = 0  -- Reset regen delay
        self.shield_regen_timer = 0   -- Reset regen progress

        if self.shield_hits_remaining <= 0 then
            self.shield_hits_remaining = 0
            self.shield_active = false
            if self.on_shield_break then
                self.on_shield_break()
            end
        end

        if self.on_damage then
            self.on_damage(amount, source)
        end

        return true  -- Shield absorbed
    end

    -- Lives mode OR shield mode with shield down: lose lives
    if self.mode == LivesHealthSystem.MODES.LIVES or self.mode == LivesHealthSystem.MODES.SHIELD then
        self.lives = self.lives - amount

        -- Trigger damage callback
        if self.on_damage then
            self.on_damage(amount, source)
        end

        -- Check for death
        if self.lives <= 0 then
            self.lives = 0
            self:die()
        else
            -- Grant invincibility if configured
            if self.invincibility_on_hit then
                self.invincible = true
                self.invincibility_timer = self.invincibility_duration
            end
        end

        return true
    end

    return false
end

function LivesHealthSystem:die()
    if self.is_dead then return end

    self.is_dead = true

    -- Trigger death callback
    if self.on_death then
        self.on_death()
    end

    -- Start respawn timer if enabled
    if self.respawn_enabled and self.lives > 0 then
        self.waiting_to_respawn = true
        self.respawn_timer = 0
    end
end

function LivesHealthSystem:respawn()
    if not self.waiting_to_respawn then return end

    self.is_dead = false
    self.waiting_to_respawn = false
    self.respawn_timer = 0

    -- Grant brief invincibility on respawn
    if self.invincibility_on_hit then
        self.invincible = true
        self.invincibility_timer = self.invincibility_duration
    end

    -- Trigger respawn callback
    if self.on_respawn then
        self.on_respawn()
    end
end

function LivesHealthSystem:addLife(count)
    count = count or 1

    if self.mode == LivesHealthSystem.MODES.LIVES then
        local old_lives = self.lives
        self.lives = math.min(self.lives + count, self.max_lives)

        if self.lives > old_lives then
            -- Trigger life gained callback
            if self.on_life_gained then
                self.on_life_gained(count)
            end
            return true
        end
    end

    return false
end

function LivesHealthSystem:checkExtraLifeAward(score)
    if not self.extra_life_enabled or self.mode ~= LivesHealthSystem.MODES.LIVES then
        return false
    end

    local current_threshold = math.floor(score / self.extra_life_threshold) * self.extra_life_threshold

    if current_threshold > self.last_extra_life_threshold then
        self.last_extra_life_threshold = current_threshold
        self:addLife(1)
        return true
    end

    return false
end

function LivesHealthSystem:heal(amount)
    -- Shield mode: restore shield hits
    if self.mode == LivesHealthSystem.MODES.SHIELD and self.shield_enabled then
        local old_hits = self.shield_hits_remaining
        self.shield_hits_remaining = math.min(self.shield_hits_remaining + amount, self.shield_max_hits)

        -- Reactivate shield if it was broken
        if not self.shield_active and self.shield_hits_remaining > 0 then
            self.shield_active = true
            if self.on_shield_regen then
                self.on_shield_regen()
            end
        end

        return self.shield_hits_remaining > old_hits
    end

    return false
end

function LivesHealthSystem:isAlive()
    return not self.is_dead
end

function LivesHealthSystem:isInvincible()
    return self.invincible
end

function LivesHealthSystem:getShieldStrength()
    if self.mode == LivesHealthSystem.MODES.SHIELD and self.shield_enabled then
        return self.shield_hits_remaining / self.shield_max_hits
    end
    return 0
end

function LivesHealthSystem:getShieldHitsRemaining()
    if self.mode == LivesHealthSystem.MODES.SHIELD and self.shield_enabled then
        return self.shield_hits_remaining
    end
    return 0
end

function LivesHealthSystem:isShieldActive()
    return self.shield_enabled and self.shield_active
end

function LivesHealthSystem:getLives()
    return self.lives
end

function LivesHealthSystem:setLives(count)
    self.lives = math.max(0, math.min(count, self.max_lives))
end

function LivesHealthSystem:reset()
    self.lives = self.starting_lives
    self.is_dead = false
    self.invincible = false
    self.invincibility_timer = 0
    self.waiting_to_respawn = false
    self.respawn_timer = 0
    self.last_extra_life_threshold = 0

    -- Reset shield
    if self.shield_enabled then
        self.shield_active = true
        self.shield_hits_remaining = self.shield_max_hits
        self.shield_regen_timer = 0
        self.shield_damage_timer = 0
    end
end

return LivesHealthSystem
