local Object = require('class')
local BaseGame = Object:extend('BaseGame')

function BaseGame:init(game_data, cheats, di, variant_override)
    -- Store game definition
    self.data = game_data

    -- Store DI container (optional)
    self.di = di

    -- Store active cheats
    self.cheats = cheats or {}

    -- Performance tracking
    self.metrics = {}
    self.completed = false
    self.time_elapsed = 0

    -- Common game state (used by most games)
    self.rng = love.math.newRandomGenerator(os.time())
    self.game_over = false
    self.victory = false
    self.score = 0

    -- Common arena state
    self.arena_width = 800
    self.arena_height = 600
    self.combo = 0
    self.max_combo = 0

    -- Common entity arrays
    self.bullets = {}
    self.powerups = {}
    self.active_powerups = {}

    -- Reset all metrics tracked by this game
    for _, metric in ipairs(self.data.metrics_tracked) do
        self.metrics[metric] = 0
    end

    -- Apply difficulty modifiers
    self.difficulty_modifiers = self.data.difficulty_modifiers or {
        speed = 1,
        count = 1,
        complexity = 1,
        time_limit = 1
    }

    -- Store difficulty level
    self.difficulty_level = self.data.difficulty_level or 1

    -- Fixed timestep support for deterministic demos
    self.fixed_dt = (di and di.config and di.config.vm_demo and di.config.vm_demo.fixed_dt) or (1/60)
    self.accumulator = 0
    self.frame_count = 0

    -- Playback mode (disables human input when true)
    self.playback_mode = false

    -- Virtual keyboard state for demo playback
    self.virtual_keys = {}

    -- VM rendering mode (hides HUD when true)
    self.vm_render_mode = false

    -- Load variant data
    self.variant = nil

    -- Priority 1: Use variant_override if provided (from CheatEngine)
    if variant_override then
        self.variant = variant_override
        print("[BaseGame] Using variant override from CheatEngine")
    -- Priority 2: Load from GameVariantLoader if available
    elseif di and di.gameVariantLoader then
        local variant_data = di.gameVariantLoader:getVariantData(game_data.id)
        if variant_data then
            self.variant = variant_data
        end
    end

    -- If no variant loaded, create a default one to avoid nil checks everywhere
    if not self.variant then
        self.variant = {
            clone_index = 0,
            name = game_data.display_name or "Unknown",
            sprite_set = "default",
            palette = "default",
            music_track = nil,
            sfx_pack = "retro_beeps",
            background = "default",
            difficulty_modifier = 1.0,
            enemies = {},
            flavor_text = "",
            intro_cutscene = nil
        }
    end
end

-- Apply cheats to params using a mapping
-- Example: self:applyCheats({speed_modifier = {"paddle_speed", "ball_speed"}, advantage_modifier = {"paddle_width"}})
function BaseGame:applyCheats(mappings)
    if not self.cheats or not self.params then return end

    if self.cheats.speed_modifier and mappings.speed_modifier then
        for _, param in ipairs(mappings.speed_modifier) do
            if self.params[param] then
                self.params[param] = self.params[param] * self.cheats.speed_modifier
            end
        end
    end

    if self.cheats.advantage_modifier and mappings.advantage_modifier then
        for _, param in ipairs(mappings.advantage_modifier) do
            if self.params[param] then
                self.params[param] = self.params[param] * (1 + self.cheats.advantage_modifier * 0.1)
            end
        end
        -- Also add to lives if present
        if self.params.lives then
            self.params.lives = self.params.lives + math.floor(self.cheats.advantage_modifier)
        end
    end

    if self.cheats.performance_modifier and mappings.performance_modifier then
        for _, param in ipairs(mappings.performance_modifier) do
            if self.params[param] then
                self.params[param] = self.params[param] + math.floor(self.cheats.performance_modifier / 3)
            end
        end
    end
end

-- Create components from schema definitions
-- Schema should have a "components" section with type and config for each component
function BaseGame:createComponentsFromSchema()
    local C = self.di and self.di.components
    if not C or not self.params or not self.params.components then return end

    for name, def in pairs(self.params.components) do
        local config = self:resolveConfig(def.config or {})
        local ComponentClass = C[def.type]
        if ComponentClass then
            self[name] = ComponentClass:new(config)
            if self[name].game == nil then
                self[name].game = self
            end
        end
    end
end

-- Resolve "$param_name" references in config to actual param values
function BaseGame:resolveConfig(config)
    local resolved = {}
    for k, v in pairs(config) do
        if type(v) == "string" and v:sub(1, 1) == "$" then
            resolved[k] = self.params[v:sub(2)]
        elseif type(v) == "table" then
            resolved[k] = self:resolveConfig(v)
        else
            resolved[k] = v
        end
    end
    return resolved
end

-- Variable timestep update (for normal gameplay)
function BaseGame:updateBase(dt)
    if not self.completed then
        self.time_elapsed = self.time_elapsed + dt

        -- Update time_remaining if the game uses it (like HiddenObject)
        if self.time_limit and self.time_remaining then
             self.time_remaining = math.max(0, self.time_limit - self.time_elapsed)
        end

        if self:checkComplete() then
            self:onComplete()
        end
    end
end

-- Fixed timestep update (for deterministic demo recording/playback)
function BaseGame:updateWithFixedTimestep(dt)
    if self.completed then
        return
    end

    -- Accumulate time
    self.accumulator = self.accumulator + dt

    -- Run fixed updates
    while self.accumulator >= self.fixed_dt do
        self:fixedUpdate(self.fixed_dt)
        self.accumulator = self.accumulator - self.fixed_dt
        self.frame_count = self.frame_count + 1
    end
end

-- Fixed timestep update (deterministic)
function BaseGame:fixedUpdate(dt)
    if not self.completed then
        self.time_elapsed = self.time_elapsed + dt

        -- Update time_remaining if the game uses it (like HiddenObject)
        if self.time_limit and self.time_remaining then
             self.time_remaining = math.max(0, self.time_limit - self.time_elapsed)
        end

        -- Call game-specific logic
        self:updateGameLogic(dt)

        if self:checkComplete() then
            self:onComplete()
        end
    end
end

function BaseGame:updateGameLogic(dt)
    -- Override in subclasses to implement game-specific update logic
    -- This is called from both updateBase (variable dt) and fixedUpdate (fixed dt)
end

-- Resize play area and reposition entities
function BaseGame:setPlayArea(width, height)
    local old_width = self.arena_width
    local offset_x = (width - old_width) / 2

    self.arena_width = width
    self.arena_height = height

    -- Reposition entities if they exist
    if self.entity_controller then
        for _, entity in ipairs(self.entity_controller:getEntities()) do
            entity.x = entity.x + offset_x
        end
    end

    -- Reposition paddle if exists
    if self.paddle then
        self.paddle.y = height - 50
        self.paddle.x = math.max(self.paddle.width / 2, math.min(self.paddle.x, width - self.paddle.width / 2))
    end

    -- Reposition balls if they exist
    if self.balls then
        for _, ball in ipairs(self.balls) do
            ball.x = math.max(ball.radius, math.min(width - ball.radius, ball.x + offset_x))
            ball.y = math.max(ball.radius, math.min(height - ball.radius, ball.y))
        end
    end

    -- Reposition obstacles if they exist
    if self.obstacles then
        for _, obstacle in ipairs(self.obstacles) do
            obstacle.x = obstacle.x + offset_x
        end
    end
end

function BaseGame:draw()
    -- Override in subclasses
end

function BaseGame:keypressed(key)
    -- Track virtual key state for demo playback
    if self.playback_mode then
        self.virtual_keys[key] = true
        -- Debug output
        if not self.debug_vkey_count then self.debug_vkey_count = 0 end
        if self.debug_vkey_count < 10 then
            print(string.format("[BaseGame] Virtual key pressed: %s (now tracking: %d keys)", key, self:countActiveKeys()))
            self.debug_vkey_count = self.debug_vkey_count + 1
        end
        return
    end
    -- Override in subclasses
end

function BaseGame:keyreleased(key)
    -- Track virtual key state for demo playback
    if self.playback_mode then
        self.virtual_keys[key] = false
        return
    end
    -- Override in subclasses
end

-- Debug helper
function BaseGame:countActiveKeys()
    local count = 0
    for k, v in pairs(self.virtual_keys) do
        if v then count = count + 1 end
    end
    return count
end

function BaseGame:mousepressed(x, y, button)
    -- Block human input during demo playback
    if self.playback_mode then
        return
    end
    -- Override in subclasses
end

-- Enable/disable playback mode
function BaseGame:setPlaybackMode(enabled)
    self.playback_mode = enabled
    -- Clear virtual keys when entering/exiting playback mode
    if enabled then
        self.virtual_keys = {}
    end
end

function BaseGame:isInPlaybackMode()
    return self.playback_mode
end

-- Check if key is down (virtual during playback, real otherwise)
function BaseGame:isKeyDown(...)
    if self.playback_mode then
        -- Check multiple keys (any key pressed returns true)
        for i = 1, select('#', ...) do
            local key = select(i, ...)
            if self.virtual_keys[key] then
                return true
            end
        end
        return false
    else
        -- Use real keyboard state
        return love.keyboard.isDown(...)
    end
end

-- Enable/disable VM render mode (hides HUD)
function BaseGame:setVMRenderMode(enabled)
    self.vm_render_mode = enabled
end

function BaseGame:isVMRenderMode()
    return self.vm_render_mode
end

function BaseGame:checkComplete()
    -- Default implementation - most games use victory/game_over flags
    return self.victory or self.game_over
end

function BaseGame:onComplete()
    self.completed = true
end

function BaseGame:getMetrics()
    return self.metrics
end

function BaseGame:calculatePerformance()
    if not self.completed then return 0 end
    -- Note: This returns the *base* performance.
    -- The MinigameState is responsible for applying performance-modifying cheats.
    return self.data.formula_function(self.metrics)
end

-- Get results for demo playback (used by VMManager)
function BaseGame:getResults()
    return {
        tokens = self:calculatePerformance(),
        metrics = self:getMetrics(),
        completed = self.completed
    }
end

-- Completion ratio: override in games to report progress toward their core goal (0..1)
function BaseGame:getCompletionRatio()
    return 1.0
end

-- Generic powerup effect helpers
-- Usage: effect.original = self:multiplyParam("paddle_width", 1.5)
function BaseGame:multiplyParam(param_name, multiplier)
    local original = self.params[param_name]
    self.params[param_name] = original * multiplier
    return original
end

function BaseGame:restoreParam(param_name, original_value)
    self.params[param_name] = original_value
end

function BaseGame:enableParam(param_name)
    local original = self.params[param_name]
    self.params[param_name] = true
    return original
end

function BaseGame:setParam(param_name, value)
    local original = self.params[param_name]
    self.params[param_name] = value
    return original
end

-- Multiply velocity of all entities in an array
function BaseGame:multiplyEntitySpeed(entities, multiplier)
    for _, e in ipairs(entities) do
        if e.active and e.vx and e.vy then
            e.vx = e.vx * multiplier
            e.vy = e.vy * multiplier
        end
    end
end

-- Phase 3.3: Audio helpers (graceful fallback if no audio assets)
function BaseGame:loadAudio()
    local audioManager = self.di and self.di.audioManager

    if not audioManager then
        -- No audio system available (silent mode)
        return
    end

    if not self.variant then
        -- No variant data (silent mode)
        return
    end

    -- Load music track
    if self.variant.music_track then
        self.music = audioManager:loadMusic(self.variant.music_track)
    end

    -- Load SFX pack
    if self.variant.sfx_pack then
        audioManager:loadSFXPack(self.variant.sfx_pack)
        self.sfx_pack = self.variant.sfx_pack
    end
end

function BaseGame:playMusic()
    local audioManager = self.di and self.di.audioManager
    if audioManager and self.variant and self.variant.music_track then
        audioManager:playMusic(self.variant.music_track)
    end
end

function BaseGame:stopMusic()
    local audioManager = self.di and self.di.audioManager
    if audioManager then
        audioManager:stopMusic()
    end
end

function BaseGame:playSound(action, volume)
    local audioManager = self.di and self.di.audioManager
    if audioManager and self.sfx_pack and action then
        audioManager:playSound(self.sfx_pack, action, volume or 1.0)
    end
end

return BaseGame