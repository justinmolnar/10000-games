--[[
PowerupSystem - Phase 15: Generic powerup/pickup system

Handles:
- Powerup spawning (timer-based or event-triggered)
- Movement and physics (falling, gravity support)
- Collision detection and collection
- Active effect duration tracking
- Game-specific effect application via hooks
- Rendering data provision

Usage:
    local PowerupSystem = require('src.utils.game_components.powerup_system')

    self.powerup_system = PowerupSystem:new({
        enabled = true,
        spawn_mode = "timer",  -- "timer", "event", "both", "manual"
        spawn_rate = 15.0,
        powerup_size = 20,
        drop_speed = 150,
        reverse_gravity = false,
        default_duration = 10.0,
        powerup_types = {"speed", "shield", "rapid_fire"},
        powerup_configs = {
            speed = {duration = 8.0, multiplier = 1.5}
        },
        color_map = {
            speed = {0, 1, 1}
        },

        -- Game-specific hooks
        on_spawn = function(powerup) end,
        on_collect = function(powerup) end,
        on_apply = function(powerup_type, effect, config) end,
        on_remove = function(powerup_type, effect) end
    })

    -- Manual spawning (e.g., from brick destruction):
    self.powerup_system:spawn(x, y)

    -- Update:
    self.powerup_system:update(dt, collector_entity, game_bounds)

    -- Render:
    for _, powerup in ipairs(self.powerup_system:getPowerupsForRendering()) do
        local color = self.powerup_system:getColorForType(powerup.type)
        -- Draw powerup...
    end
]]

local Object = require('class')
local PowerupSystem = Object:extend('PowerupSystem')

-- Spawn modes
PowerupSystem.SPAWN_MODES = {
    TIMER = "timer",      -- Automatic spawning based on timer
    EVENT = "event",      -- Manual spawning via spawn() calls
    BOTH = "both",        -- Both timer and manual
    MANUAL = "manual"     -- Same as EVENT (alias)
}

--[[
    Create a new powerup system

    @param config table - Configuration:
        - enabled: Enable/disable system (default: false)
        - spawn_mode: "timer", "event", "both", "manual" (default: "timer")
        - spawn_rate: Seconds between auto-spawns (default: 15.0)
        - powerup_size: Width/height of powerup entity (default: 20)
        - drop_speed: Pixels per second fall speed (default: 150)
        - reverse_gravity: Fall upward instead of downward (default: false)
        - default_duration: Default effect duration in seconds (default: 10.0)
        - powerup_types: Array of powerup type names (default: {})
        - powerup_configs: Per-type config {type = {duration, ...}} (default: {})
        - color_map: Type to {r,g,b} color mapping (default: {})
        - spawn_drop_chance: Probability for event spawns (default: 1.0)

        -- Hooks (game-specific callbacks):
        - on_spawn: function(powerup) - Called when powerup spawns
        - on_collect: function(powerup) - Called when collected
        - on_apply: function(powerup_type, effect, config) - Apply effect
        - on_remove: function(powerup_type, effect) - Remove effect
]]
function PowerupSystem:new(config)
    local instance = PowerupSystem.super.new(self)

    config = config or {}

    -- Core settings
    instance.enabled = config.enabled or false

    -- Spawning config
    instance.spawn_mode = config.spawn_mode or PowerupSystem.SPAWN_MODES.TIMER
    instance.spawn_rate = config.spawn_rate or 15.0
    instance.spawn_timer = config.spawn_rate or 15.0
    instance.spawn_drop_chance = config.spawn_drop_chance or 1.0

    -- Entity config
    instance.powerup_size = config.powerup_size or 20
    instance.drop_speed = config.drop_speed or 150
    instance.reverse_gravity = config.reverse_gravity or false

    -- Effect config
    instance.default_duration = config.default_duration or 10.0
    instance.powerup_types = config.powerup_types or {}
    instance.powerup_configs = config.powerup_configs or {}
    instance.color_map = config.color_map or {}

    -- State
    instance.powerups = {}  -- Falling powerup entities
    instance.active_powerups = {}  -- Active effects {type = {duration_remaining, ...}}

    -- Hooks (game-specific callbacks)
    instance.on_spawn = config.on_spawn or function(powerup) end
    instance.on_collect = config.on_collect or function(powerup) end
    instance.on_apply = config.on_apply or function(powerup_type, effect, config) end
    instance.on_remove = config.on_remove or function(powerup_type, effect) end

    return instance
end

--[[
    Spawn a powerup at a specific position

    @param x number - X position (center)
    @param y number - Y position (center)
    @param powerup_type string (optional) - Specific type, or random if nil
    @return table - The spawned powerup entity, or nil if disabled/failed drop chance
]]
function PowerupSystem:spawn(x, y, powerup_type)
    if not self.enabled then return nil end

    -- Drop chance check (for event-based spawning)
    if math.random() > self.spawn_drop_chance then
        return nil
    end

    -- Select random type if not specified
    if not powerup_type and #self.powerup_types > 0 then
        powerup_type = self.powerup_types[math.random(1, #self.powerup_types)]
    end

    if not powerup_type then
        print("[PowerupSystem] Warning: No powerup type provided and no types configured")
        return nil
    end

    -- Create powerup entity
    local powerup = {
        x = x - self.powerup_size / 2,
        y = y - self.powerup_size / 2,
        width = self.powerup_size,
        height = self.powerup_size,
        type = powerup_type,
        vy = self.drop_speed * (self.reverse_gravity and -1 or 1)
    }

    table.insert(self.powerups, powerup)

    -- Call spawn hook
    self.on_spawn(powerup)

    return powerup
end

--[[
    Update powerup system (movement, collision, timers)

    @param dt number - Delta time
    @param collector_entity table - Entity that collects powerups (must have x, y, width, height)
    @param game_bounds table - {width, height} for off-screen checking
]]
function PowerupSystem:update(dt, collector_entity, game_bounds)
    if not self.enabled then return end

    -- Timer-based automatic spawning
    if self.spawn_mode == PowerupSystem.SPAWN_MODES.TIMER or self.spawn_mode == PowerupSystem.SPAWN_MODES.BOTH then
        self.spawn_timer = self.spawn_timer - dt
        if self.spawn_timer <= 0 then
            -- Spawn at random X position, top/bottom of screen
            local spawn_x = math.random(0, (game_bounds.width or 800) - self.powerup_size)
            local spawn_y = self.reverse_gravity and (game_bounds.height or 600) or 0
            self:spawn(spawn_x, spawn_y)
            self.spawn_timer = self.spawn_rate
        end
    end

    -- Update falling powerups
    for i = #self.powerups, 1, -1 do
        local powerup = self.powerups[i]

        -- Update position
        powerup.y = powerup.y + powerup.vy * dt

        -- Check collection
        if collector_entity and self:checkCollision(powerup, collector_entity) then
            self:collect(powerup)
            table.remove(self.powerups, i)
        -- Remove if off-screen
        elseif self:isOffScreen(powerup, game_bounds) then
            table.remove(self.powerups, i)
        end
    end

    -- Update active effect durations
    for powerup_type, effect in pairs(self.active_powerups) do
        effect.duration_remaining = effect.duration_remaining - dt
        if effect.duration_remaining <= 0 then
            self:removeEffect(powerup_type)
        end
    end
end

--[[
    Collect a powerup (trigger effect)

    @param powerup table - The powerup entity being collected
]]
function PowerupSystem:collect(powerup)
    local powerup_type = powerup.type

    -- Refresh existing effect (remove and reapply)
    if self.active_powerups[powerup_type] then
        self:removeEffect(powerup_type)
    end

    -- Get config for this type
    local config = self.powerup_configs[powerup_type] or {}
    local duration = config.duration or self.default_duration

    -- Create effect entry
    local effect = {
        duration_remaining = duration,
        config = config,
        type = powerup_type
    }

    self.active_powerups[powerup_type] = effect

    -- Call application hook (game-specific logic)
    self.on_apply(powerup_type, effect, config)

    -- Call collection hook
    self.on_collect(powerup)
end

--[[
    Remove an active powerup effect

    @param powerup_type string - Type of powerup to remove
]]
function PowerupSystem:removeEffect(powerup_type)
    local effect = self.active_powerups[powerup_type]
    if not effect then return end

    -- Call removal hook (game-specific cleanup)
    self.on_remove(powerup_type, effect)

    self.active_powerups[powerup_type] = nil
end

--[[
    Check collision between powerup and entity (AABB)

    @param powerup table - Powerup with x, y, width, height
    @param entity table - Entity with x, y, width, height
    @return boolean - True if colliding
]]
function PowerupSystem:checkCollision(powerup, entity)
    return powerup.x + powerup.width > entity.x and
           powerup.x < entity.x + entity.width and
           powerup.y + powerup.height > entity.y and
           powerup.y < entity.y + entity.height
end

--[[
    Check if powerup is off-screen

    @param powerup table - Powerup with y, height
    @param bounds table - {width, height}
    @return boolean - True if off-screen
]]
function PowerupSystem:isOffScreen(powerup, bounds)
    if self.reverse_gravity then
        return powerup.y + powerup.height < 0
    else
        return powerup.y > (bounds.height or 600)
    end
end

--[[
    Clear all powerups and active effects

    @param clear_active boolean (optional) - Also clear active effects (default: true)
]]
function PowerupSystem:clear(clear_active)
    self.powerups = {}

    if clear_active ~= false then
        -- Remove all active effects
        for powerup_type, effect in pairs(self.active_powerups) do
            self:removeEffect(powerup_type)
        end
    end
end

--[[
    Get powerups for rendering

    @return table - Array of powerup entities
]]
function PowerupSystem:getPowerupsForRendering()
    return self.powerups
end

--[[
    Get active powerups for HUD rendering

    @return table - Active powerups {type = {duration_remaining, ...}}
]]
function PowerupSystem:getActivePowerupsForHUD()
    return self.active_powerups
end

--[[
    Get color for a powerup type

    @param powerup_type string - Type name
    @return table - {r, g, b} color (default: {1, 1, 1})
]]
function PowerupSystem:getColorForType(powerup_type)
    return self.color_map[powerup_type] or {1, 1, 1}
end

--[[
    Get count of active falling powerups
]]
function PowerupSystem:getPowerupCount()
    return #self.powerups
end

--[[
    Get count of active effects
]]
function PowerupSystem:getActiveEffectCount()
    local count = 0
    for _ in pairs(self.active_powerups) do
        count = count + 1
    end
    return count
end

--[[
    Check if a specific effect is active

    @param powerup_type string - Type to check
    @return boolean - True if active
]]
function PowerupSystem:hasActiveEffect(powerup_type)
    return self.active_powerups[powerup_type] ~= nil
end

--[[
    Get time remaining for an active effect

    @param powerup_type string - Type to check
    @return number - Seconds remaining, or 0 if not active
]]
function PowerupSystem:getTimeRemaining(powerup_type)
    local effect = self.active_powerups[powerup_type]
    return effect and effect.duration_remaining or 0
end

return PowerupSystem
