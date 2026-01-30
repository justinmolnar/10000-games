-- AnimationSystem: Reusable animation helpers for games
-- Provides common animation patterns: flip, bounce, fade, etc.
-- All animations are timer-based and work independently

local AnimationSystem = {}

-- Create a rotation-based flip animation (for coins, cards, etc.)
function AnimationSystem.createFlipAnimation(config)
    local anim = {
        duration = config.duration or 0.5,
        speed_multiplier = config.speed_multiplier or 1.0,
        on_complete = config.on_complete,

        -- State
        timer = 0,
        rotation = 0,
        active = false
    }

    function anim:start()
        self.timer = 0
        self.rotation = 0
        self.active = true
    end

    function anim:update(dt)
        if not self.active then return end

        self.timer = self.timer + dt
        self.rotation = self.rotation + dt * 20 * self.speed_multiplier

        -- Check if animation complete
        if self.timer >= (self.duration / self.speed_multiplier) then
            self.active = false
            self.timer = 0
            self.rotation = 0

            if self.on_complete then
                self.on_complete()
            end
        end
    end

    function anim:getRotation()
        return self.rotation
    end

    function anim:isActive()
        return self.active
    end

    function anim:reset()
        self.timer = 0
        self.rotation = 0
        self.active = false
    end

    return anim
end

-- Create a bounce/throw animation (sin wave offset for RPS hand throws)
function AnimationSystem.createBounceAnimation(config)
    local anim = {
        duration = config.duration or 0.5,
        height = config.height or 20,
        speed_multiplier = config.speed_multiplier or 1.0,
        on_complete = config.on_complete,

        -- State
        timer = 0,
        offset = 0,
        active = false
    }

    function anim:start()
        self.timer = 0
        self.offset = 0
        self.active = true
    end

    function anim:update(dt)
        if not self.active then return end

        self.timer = self.timer + dt

        -- Calculate bounce offset using sine wave
        local progress = self.timer / (self.duration / self.speed_multiplier)
        if progress <= 1.0 then
            -- Sin wave: goes up then down
            self.offset = math.sin(progress * math.pi) * self.height
        end

        -- Check if animation complete
        if self.timer >= (self.duration / self.speed_multiplier) then
            self.active = false
            self.timer = 0
            self.offset = 0

            if self.on_complete then
                self.on_complete()
            end
        end
    end

    function anim:getOffset()
        return self.offset
    end

    function anim:isActive()
        return self.active
    end

    function anim:reset()
        self.timer = 0
        self.offset = 0
        self.active = false
    end

    return anim
end

-- Create a fade animation (alpha lerp for cards, UI elements)
function AnimationSystem.createFadeAnimation(config)
    local anim = {
        duration = config.duration or 0.3,
        from_alpha = config.from or 0,
        to_alpha = config.to or 1,
        on_complete = config.on_complete,

        -- State
        timer = 0,
        alpha = config.from or 0,
        active = false
    }

    function anim:start()
        self.timer = 0
        self.alpha = self.from_alpha
        self.active = true
    end

    function anim:update(dt)
        if not self.active then return end

        self.timer = self.timer + dt

        -- Linear interpolation
        local progress = math.min(self.timer / self.duration, 1.0)
        self.alpha = self.from_alpha + (self.to_alpha - self.from_alpha) * progress

        -- Check if animation complete
        if self.timer >= self.duration then
            self.active = false
            self.timer = 0
            self.alpha = self.to_alpha

            if self.on_complete then
                self.on_complete()
            end
        end
    end

    function anim:getAlpha()
        return self.alpha
    end

    function anim:isActive()
        return self.active
    end

    function anim:reset()
        self.timer = 0
        self.alpha = self.from_alpha
        self.active = false
    end

    return anim
end

-- Create a bidirectional progress animation (for card flips: 0→1 face up, 1→0 face down)
function AnimationSystem.createProgressAnimation(config)
    local anim = {
        duration = config.duration or 0.5,
        direction = config.direction or 1,  -- 1 = forward (0→1), -1 = backward (1→0)
        on_complete = config.on_complete,

        -- State
        progress = config.initial or 0,
        active = false
    }

    function anim:start(dir)
        if dir then self.direction = dir end
        self.active = true
    end

    function anim:update(dt)
        if not self.active then return end

        self.progress = self.progress + (dt / self.duration) * self.direction

        if self.direction > 0 and self.progress >= 1 then
            self.progress = 1
            self.active = false
            if self.on_complete then self.on_complete(self.direction) end
        elseif self.direction < 0 and self.progress <= 0 then
            self.progress = 0
            self.active = false
            if self.on_complete then self.on_complete(self.direction) end
        end
    end

    function anim:getProgress()
        return self.progress
    end

    function anim:isActive()
        return self.active
    end

    function anim:reset(initial_progress)
        self.progress = initial_progress or 0
        self.active = false
    end

    return anim
end

-- Helper: Create a simple timer (for auto-flip, delays, etc.)
function AnimationSystem.createTimer(duration, on_complete)
    local timer = {
        duration = duration,
        on_complete = on_complete,

        -- State
        elapsed = 0,
        active = false
    }

    function timer:start()
        self.elapsed = 0
        self.active = true
    end

    function timer:update(dt)
        if not self.active then return end

        self.elapsed = self.elapsed + dt

        if self.elapsed >= self.duration then
            self.active = false
            self.elapsed = 0

            if self.on_complete then
                self.on_complete()
            end
        end
    end

    function timer:getRemaining()
        return math.max(0, self.duration - self.elapsed)
    end

    function timer:getProgress()
        return math.min(self.elapsed / self.duration, 1.0)
    end

    function timer:isActive()
        return self.active
    end

    function timer:reset()
        self.elapsed = 0
        self.active = false
    end

    return timer
end

return AnimationSystem
