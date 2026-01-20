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
    instance.base_values = {}  -- True original values before ANY powerup modified them

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
        type = powerup_type,
        originals = {}  -- Store original values for reverting
    }

    self.active_powerups[powerup_type] = effect

    -- Apply declarative effects if game reference exists
    if self.game and config.effects then
        self:applyDeclarativeEffects(effect, config)
    end

    -- Call application hook (game-specific logic for non-declarative effects)
    self.on_apply(powerup_type, effect, config)

    -- Call collection hook
    self.on_collect(powerup)
end

--[[
    Apply declarative effects from config

    Supported effect types:
    - multiply_param: Multiply a game param {param = "name", multiplier = 1.5}
    - enable_param: Set param to true {param = "name"}
    - set_param: Set param to value {param = "name", value = X}
    - set_flag: Set a game flag {flag = "name", value = true}
    - add_lives: Add lives {count = 1}
    - multiply_entity_speed: Multiply speed of entities {entities = "balls", multiplier = 0.5}
    - multiply_entity_field: Multiply entity field {entity = "paddle", field = "width", multiplier = 1.5}
    - spawn_projectiles: Spawn extra projectiles {type = "ball", count = 2, angle_spread = 0.5}
]]
function PowerupSystem:applyDeclarativeEffects(effect, config)
    local game = self.game
    if not game then return end

    for _, eff in ipairs(config.effects or {}) do
        if eff.type == "multiply_param" and game.params then
            local key = "param_" .. eff.param
            -- Store TRUE original only if no powerup has modified this param yet
            if self.base_values[key] == nil then
                self.base_values[key] = game.params[eff.param]
            end
            effect.originals[key] = true  -- Mark that this effect modified this param
            game.params[eff.param] = game.params[eff.param] * (eff.multiplier or 1)

        elseif eff.type == "enable_param" and game.params then
            effect.originals[eff.param] = game.params[eff.param]
            game.params[eff.param] = true

        elseif eff.type == "set_param" and game.params then
            effect.originals[eff.param] = game.params[eff.param]
            game.params[eff.param] = eff.value

        elseif eff.type == "set_flag" then
            effect.originals["flag_" .. eff.flag] = game[eff.flag]
            game[eff.flag] = eff.value ~= false

        elseif eff.type == "add_lives" and game.health_system then
            game.health_system:addLife(eff.count or 1)
            if game.lives then game.lives = game.health_system.lives end

        elseif eff.type == "multiply_entity_speed" then
            local entities = game[eff.entities]
            if entities then
                effect.originals["speed_" .. eff.entities] = eff.multiplier
                for _, e in ipairs(entities) do
                    if e.vx then e.vx = e.vx * (eff.multiplier or 1) end
                    if e.vy then e.vy = e.vy * (eff.multiplier or 1) end
                end
            end

        elseif eff.type == "multiply_entity_field" then
            local entity = game[eff.entity]
            if entity and entity[eff.field] then
                local key = "entity_" .. eff.entity .. "_" .. eff.field
                -- Store TRUE original only if no powerup has modified this field yet
                if self.base_values[key] == nil then
                    self.base_values[key] = entity[eff.field]
                end
                effect.originals[key] = true  -- Mark that this effect modified this field
                entity[eff.field] = entity[eff.field] * (eff.multiplier or 1)
            end

        elseif eff.type == "set_entity_field" then
            local entities = game[eff.entities]
            if entities then
                for _, e in ipairs(entities) do
                    if e.active then e[eff.field] = eff.value end
                end
            end

        elseif eff.type == "spawn_projectiles" and game.projectile_system then
            local source_entities = game[eff.source or "balls"]
            if source_entities then
                for _, src in ipairs(source_entities) do
                    if src.active then
                        local speed = math.sqrt((src.vx or 0)^2 + (src.vy or 0)^2)
                        local angle = math.atan2(src.vy or 0, src.vx or 0)
                        for i = 1, (eff.count or 2) do
                            local offset = ((i - 0.5 - (eff.count or 2)/2) / (eff.count or 2)) * (eff.angle_spread or math.pi/6)
                            game.projectile_system:shoot(eff.projectile_type or "ball", src.x, src.y, angle + offset,
                                speed / (game.params.ball_speed or 300), {radius = src.radius, trail = {}})
                        end
                        break  -- Only spawn from first active source
                    end
                end
            end
        end
    end
end

--[[
    Remove declarative effects (restore original values)
]]
function PowerupSystem:removeDeclarativeEffects(effect, config)
    local game = self.game
    if not game then return end

    for _, eff in ipairs(config.effects or {}) do
        if eff.type == "multiply_param" and game.params then
            local key = "param_" .. eff.param
            if effect.originals[key] and self.base_values[key] ~= nil then
                -- Restore to base value first
                game.params[eff.param] = self.base_values[key]
                -- Re-apply multipliers from ALL other active powerups that modify this param
                local any_other_using = false
                for other_type, other_effect in pairs(self.active_powerups) do
                    if other_type ~= effect.type and other_effect.originals and other_effect.originals[key] then
                        any_other_using = true
                        local other_config = self.powerup_configs[other_type] or {}
                        for _, other_eff in ipairs(other_config.effects or {}) do
                            if other_eff.type == "multiply_param" and other_eff.param == eff.param then
                                game.params[eff.param] = game.params[eff.param] * (other_eff.multiplier or 1)
                            end
                        end
                    end
                end
                -- Clear base if no other powerup is using this param
                if not any_other_using then
                    self.base_values[key] = nil
                end
            end

        elseif eff.type == "enable_param" or eff.type == "set_param" then
            if game.params and effect.originals[eff.param] ~= nil then
                game.params[eff.param] = effect.originals[eff.param]
            end

        elseif eff.type == "set_flag" then
            local key = "flag_" .. eff.flag
            if effect.originals[key] ~= nil then
                game[eff.flag] = effect.originals[key]
            end

        elseif eff.type == "multiply_entity_speed" then
            local entities = game[eff.entities]
            local orig_mult = effect.originals["speed_" .. eff.entities]
            if entities and orig_mult then
                local reverse = 1 / orig_mult
                for _, e in ipairs(entities) do
                    if e.vx then e.vx = e.vx * reverse end
                    if e.vy then e.vy = e.vy * reverse end
                end
            end

        elseif eff.type == "multiply_entity_field" then
            local entity = game[eff.entity]
            local key = "entity_" .. eff.entity .. "_" .. eff.field
            if entity and effect.originals[key] and self.base_values[key] ~= nil then
                -- Restore to base value first
                entity[eff.field] = self.base_values[key]
                -- Re-apply multipliers from ALL other active powerups that modify this field
                local any_other_using = false
                for other_type, other_effect in pairs(self.active_powerups) do
                    if other_type ~= effect.type and other_effect.originals and other_effect.originals[key] then
                        any_other_using = true
                        local other_config = self.powerup_configs[other_type] or {}
                        for _, other_eff in ipairs(other_config.effects or {}) do
                            if other_eff.type == "multiply_entity_field" and
                               other_eff.entity == eff.entity and other_eff.field == eff.field then
                                entity[eff.field] = entity[eff.field] * (other_eff.multiplier or 1)
                            end
                        end
                    end
                end
                -- Clear base if no other powerup is using this field
                if not any_other_using then
                    self.base_values[key] = nil
                end
            end
        end
        -- Note: add_lives, spawn_projectiles, set_entity_field are not reverted
    end
end

--[[
    Remove an active powerup effect

    @param powerup_type string - Type of powerup to remove
]]
function PowerupSystem:removeEffect(powerup_type)
    local effect = self.active_powerups[powerup_type]
    if not effect then return end

    -- Remove declarative effects first
    local config = self.powerup_configs[powerup_type] or {}
    if self.game and config.effects then
        self:removeDeclarativeEffects(effect, config)
    end

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
    -- Handle center-based entities (like paddles where x,y is center)
    local ex, ey = entity.x, entity.y
    if entity.centered then
        ex = entity.x - (entity.width or 0) / 2
        ey = entity.y - (entity.height or 0) / 2
    end

    return powerup.x + powerup.width > ex and
           powerup.x < ex + (entity.width or 0) and
           powerup.y + powerup.height > ey and
           powerup.y < ey + (entity.height or 0)
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
        -- Clear base values tracking
        self.base_values = {}
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
