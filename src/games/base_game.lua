local Object = require('class')
local BaseGame = Object:extend('BaseGame')

-- Cardinal direction lookup table
BaseGame.CARDINAL_DIRECTIONS = {
    right = {x = 1, y = 0},
    left = {x = -1, y = 0},
    up = {x = 0, y = -1},
    down = {x = 0, y = 1}
}

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

-- Setup arena dimensions from variant and params
-- Sets: is_fixed_arena, game_width, game_height, lock_aspect_ratio
-- Expects params to have: arena_base_width, arena_base_height, camera_zoom, camera_mode
-- Expects variant to optionally have: arena_size
function BaseGame:setupArenaDimensions()
    self.is_fixed_arena = (self.variant and self.variant.arena_size ~= nil)
    local base_w = self.params.arena_base_width or 800
    local base_h = self.params.arena_base_height or 600

    if self.is_fixed_arena then
        self.game_width = math.floor(base_w * self.params.arena_size)
        self.game_height = math.floor(base_h * self.params.arena_size)
    else
        self.game_width, self.game_height = base_w, base_h
    end

    self.camera_zoom = self.is_fixed_arena and 1 or (self.params.camera_zoom or 1)
    self.lock_aspect_ratio = (self.is_fixed_arena and self.params.camera_mode == "fixed")
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

-- Create ProjectileSystem from schema projectile_types
function BaseGame:createProjectileSystemFromSchema(extra_config)
    local C = self.di and self.di.components
    if not C or not self.params or not self.params.projectile_types then return nil end

    local resolved_types = {}
    for name, type_def in pairs(self.params.projectile_types) do
        resolved_types[name] = self:resolveConfig(type_def)
    end

    local config = extra_config or {}
    config.projectile_types = resolved_types

    self.projectile_system = C.ProjectileSystem:new(config)
    return self.projectile_system
end

-- Create EntityController from schema entity_types
-- callbacks = {brick = {on_hit = fn, on_death = fn}, obstacle = {...}}
function BaseGame:createEntityControllerFromSchema(callbacks, extra_config)
    local C = self.di and self.di.components
    if not C or not self.params or not self.params.entity_types then return nil end

    local resolved_types = {}
    for name, type_def in pairs(self.params.entity_types) do
        resolved_types[name] = self:resolveConfig(type_def)
        -- Merge in callbacks for this type
        if callbacks and callbacks[name] then
            for k, v in pairs(callbacks[name]) do
                resolved_types[name][k] = v
            end
        end
    end

    local config = extra_config or {}
    config.entity_types = resolved_types

    self.entity_controller = C.EntityController:new(config)
    return self.entity_controller
end

-- Create PowerupSystem from schema powerup_effect_configs
function BaseGame:createPowerupSystemFromSchema(extra_config)
    local C = self.di and self.di.components
    if not C or not self.params then return nil end

    local p = self.params
    local config = extra_config or {}

    config.enabled = p.powerup_enabled
    config.spawn_mode = config.spawn_mode or "event"
    config.spawn_drop_chance = config.spawn_drop_chance or p.brick_powerup_drop_chance or p.powerup_drop_chance or 1.0
    config.spawn_rate = p.powerup_spawn_rate
    config.powerup_size = p.powerup_size
    config.drop_speed = p.powerup_fall_speed
    config.default_duration = p.powerup_duration
    config.powerup_types = p.powerup_types
    -- Resolve $param references in powerup configs
    config.powerup_configs = p.powerup_effect_configs and self:resolveConfig(p.powerup_effect_configs) or nil

    self.powerup_system = C.PowerupSystem:new(config)
    self.powerup_system.game = self
    return self.powerup_system
end

-- Create VictoryCondition from schema victory_conditions mapping
-- bonuses = optional array of bonus configs
function BaseGame:createVictoryConditionFromSchema(bonuses)
    local C = self.di and self.di.components
    if not C or not self.params then return nil end

    local vc_map = self.params.victory_conditions
    local vc_key = self.params.victory_condition or "clear_bricks"

    local vc_config = {}
    if vc_map and vc_map[vc_key] then
        vc_config = self:resolveConfig(vc_map[vc_key])
    end

    -- Default loss condition
    vc_config.loss = vc_config.loss or {type = "lives_depleted", metric = "lives"}
    vc_config.check_loss_first = true
    vc_config.bonuses = bonuses

    self.victory_checker = C.VictoryCondition:new(vc_config)
    self.victory_checker.game = self
    return self.victory_checker
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
    if self.view then
        self.view:draw()
    end
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
    -- If victory_checker exists, use it to check and set flags
    if self.victory_checker then
        local result = self.victory_checker:check()
        if result then
            self.victory = (result == "victory")
            self.game_over = (result == "loss")
            return true
        end
        return false
    end
    -- Default: check victory/game_over flags directly
    return self.victory or self.game_over
end

function BaseGame:onComplete()
    -- Play win/lose sound
    if self.victory then
        self:playSound(self.params and self.params.win_sound or "success", 1.0)
    else
        self:playSound(self.params and self.params.lose_sound or "death", 1.0)
    end

    -- Stop music
    self:stopMusic()

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

-- Sync metrics from game state fields
-- mapping = {metric_name = "field_name", ...}
function BaseGame:syncMetrics(mapping)
    for metric, field in pairs(mapping) do
        self.metrics[metric] = self[field]
    end
end

-- Handle entity depletion (no balls, no lives, etc.)
-- config: {loss_counter, damage, combo_reset, on_respawn, on_game_over}
-- Returns true if game over, false if respawned
function BaseGame:handleEntityDepleted(count_func, config)
    config = config or {}
    local count = type(count_func) == "function" and count_func() or count_func

    if count > 0 then return false end

    -- Increment loss counter if specified
    if config.loss_counter then
        self[config.loss_counter] = (self[config.loss_counter] or 0) + 1
    end

    -- Reset combo if requested
    if config.combo_reset then
        self.combo = 0
    end

    -- Take damage
    local damage = config.damage or 1
    self.health_system:takeDamage(damage, config.damage_reason or "entity_lost")
    self.lives = self.health_system.lives

    -- Check death
    if not self.health_system:isAlive() then
        self.game_over = true
        if config.on_game_over then config.on_game_over(self) end
        return true
    else
        -- Respawn
        if config.on_respawn then config.on_respawn(self) end
        return false
    end
end

-- Handle entity destroyed (brick, enemy, etc.) with scoring, effects, powerups
-- config: {
--   destroyed_counter = "field_name",  -- field to increment
--   remaining_counter = "field_name",  -- field to decrement
--   spawn_powerup = true,              -- spawn powerup at entity center
--   effects = {particles = true, shake = 0.15},  -- visual effects
--   scoring = {base = "param_name", combo_mult = "param_name"},  -- combo scoring
--   popup = {enabled = "param_name", milestone_combos = {5, 10, 15}},
--   color_func = function(entity) return {r,g,b} end,  -- optional particle color
--   extra_life_check = true
-- }
function BaseGame:handleEntityDestroyed(entity, config)
    config = config or {}
    local cx = entity.x + (entity.width or 0) / 2
    local cy = entity.y + (entity.height or 0) / 2

    -- Update counters
    if config.destroyed_counter then
        self[config.destroyed_counter] = (self[config.destroyed_counter] or 0) + 1
    end
    if config.remaining_counter then
        self[config.remaining_counter] = (self[config.remaining_counter] or 0) - 1
    end

    -- Spawn powerup
    if config.spawn_powerup and self.powerup_system then
        self.powerup_system:spawn(cx, cy)
    end

    -- Visual effects
    if config.effects and self.visual_effects then
        if config.effects.particles then
            local color = config.color_func and config.color_func(entity) or {1, 0.5, 0}
            self.visual_effects:emitBrickDestruction(cx, cy, color)
        end
        if config.effects.shake then
            local intensity = self.params.camera_shake_intensity or 5
            self.visual_effects:shake(config.effects.shake, intensity, "timer")
        end
    end

    -- Combo scoring
    if config.scoring then
        self.combo = (self.combo or 0) + 1
        self.max_combo = math.max(self.max_combo or 0, self.combo)

        local base = self.params[config.scoring.base] or 10
        local combo_mult = self.params[config.scoring.combo_mult] or 0
        local points = base * (1 + self.combo * combo_mult)
        self.score = (self.score or 0) + points

        -- Score popup
        if config.popup and self.params[config.popup.enabled] and self.popup_manager then
            local milestones = config.popup.milestone_combos or {}
            local is_milestone = false
            for _, m in ipairs(milestones) do
                if self.combo == m then is_milestone = true; break end
            end
            local color = is_milestone and {1, 1, 0} or {1, 1, 1}
            self.popup_manager:add(cx, entity.y, "+" .. math.floor(points), color)
        end
    end

    -- Extra life check
    if config.extra_life_check and self.health_system then
        if self.health_system:checkExtraLifeAward(self.score) then
            self.lives = self.health_system.lives
            if config.popup and self.params[config.popup.enabled] and self.popup_manager then
                self.popup_manager:add(self.arena_width / 2, self.arena_height / 2, "EXTRA LIFE!", {0, 1, 0})
            end
        end
    end
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

-- Flash system for temporary visual feedback on entities
function BaseGame:flashEntity(entity, duration)
    self.flash_map = self.flash_map or {}
    self.flash_map[entity] = duration or 0.1
end

function BaseGame:updateFlashMap(dt)
    if not self.flash_map then return end
    local TableUtils = self.di and self.di.components and self.di.components.TableUtils
    if TableUtils then
        TableUtils.updateTimerMap(self.flash_map, dt)
    else
        for entity, timer in pairs(self.flash_map) do
            self.flash_map[entity] = timer - dt
            if self.flash_map[entity] <= 0 then
                self.flash_map[entity] = nil
            end
        end
    end
end

function BaseGame:isFlashing(entity)
    return self.flash_map and self.flash_map[entity] and self.flash_map[entity] > 0
end

-- Create player entity from params
function BaseGame:createPlayer(config)
    config = config or {}
    local p = self.params or {}
    local entity_name = config.entity_name or "player"
    local width = config.width or p.player_width or p.paddle_width or 100
    local height = config.height or p.player_height or p.paddle_height or 20

    local player = {
        x = config.x or self.arena_width / 2,
        y = config.y or self.arena_height - 50,
        width = width,
        height = height,
        radius = config.radius or math.max(width, height) / 2,
        centered = true,
        active = true,
        alive = true,
        vx = 0, vy = 0, angle = 0,
        jump_cooldown_timer = 0,
        shoot_cooldown_timer = 0,
        sticky_aim_angle = -math.pi / 2
    }
    if config.extra then
        for k, v in pairs(config.extra) do
            player[k] = v
        end
    end
    self[entity_name] = player
    return player
end

-- Alias for paddle-based games
function BaseGame:createPaddle(extra_fields)
    return self:createPlayer({entity_name = "paddle", extra = extra_fields})
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

-- Returns cardinal direction (-1, 0, or 1) from point A to point B
-- Works with grid or pixel coordinates
function BaseGame:getCardinalDirection(from_x, from_y, to_x, to_y)
    local dx, dy = to_x - from_x, to_y - from_y
    if dx == 0 and dy == 0 then
        local dirs = {{1,0}, {-1,0}, {0,1}, {0,-1}}
        local d = dirs[math.random(#dirs)]
        return d[1], d[2]
    end
    if math.abs(dx) > math.abs(dy) then
        return dx > 0 and 1 or -1, 0
    else
        return 0, dy > 0 and 1 or -1
    end
end

-- Returns nearest cardinal direction {x, y} from angle in radians
function BaseGame:getCardinalFromAngle(angle)
    -- Normalize angle to 0-2π
    angle = angle % (2 * math.pi)
    if angle < 0 then angle = angle + 2 * math.pi end

    -- Map angle to cardinal: right=0, down=π/2, left=π, up=3π/2
    if angle < math.pi / 4 or angle >= 7 * math.pi / 4 then
        return BaseGame.CARDINAL_DIRECTIONS.right
    elseif angle < 3 * math.pi / 4 then
        return BaseGame.CARDINAL_DIRECTIONS.down
    elseif angle < 5 * math.pi / 4 then
        return BaseGame.CARDINAL_DIRECTIONS.left
    else
        return BaseGame.CARDINAL_DIRECTIONS.up
    end
end

-- Wrap position within bounds (for grid or pixel coordinates)
-- Returns wrapped x, y. For grid: 0 to width-1. For pixels: 0 to width.
function BaseGame:wrapPosition(x, y, width, height)
    return (x + width) % width, (y + height) % height
end

-- Find safe position using random search
-- Auto-detects grid (integer bounds) vs continuous (float bounds)
function BaseGame:findSafePosition(min_x, max_x, min_y, max_y, is_safe_fn, max_attempts)
    max_attempts = max_attempts or 500
    local is_grid = (min_x % 1 == 0) and (max_x % 1 == 0) and (min_y % 1 == 0) and (max_y % 1 == 0)

    for _ = 1, max_attempts do
        local x = is_grid and math.random(min_x, max_x) or (min_x + math.random() * (max_x - min_x))
        local y = is_grid and math.random(min_y, max_y) or (min_y + math.random() * (max_y - min_y))
        if is_safe_fn(x, y) then
            return x, y, true
        end
    end
    local cx, cy = (min_x + max_x) / 2, (min_y + max_y) / 2
    if is_grid then cx, cy = math.floor(cx), math.floor(cy) end
    return cx, cy, false
end

-- Scale a value with multipliers, variance, range, and bounds
-- config: {multipliers = {}, variance = 0, range = {min, max}, bounds = {min, max}}
function BaseGame:getScaledValue(base, config)
    config = config or {}
    local value = base

    -- Apply multipliers
    if config.multipliers then
        for _, mult in ipairs(config.multipliers) do
            value = value * mult
        end
    end

    -- Apply range (use random in range instead of base)
    if config.range then
        value = config.range.min + math.random() * (config.range.max - config.range.min)
        -- Reapply multipliers to the random value
        if config.multipliers then
            for _, mult in ipairs(config.multipliers) do
                value = value * mult
            end
        end
    -- Apply variance (random +/- percentage)
    elseif config.variance and config.variance > 0 then
        local variance_factor = 1 + (math.random() - 0.5) * 2 * config.variance
        value = value * variance_factor
    end

    -- Apply bounds
    if config.bounds then
        if config.bounds.min then value = math.max(config.bounds.min, value) end
        if config.bounds.max then value = math.min(config.bounds.max, value) end
    end

    return value
end

-- Update difficulty scaling based on params.difficulty_curve
function BaseGame:updateDifficulty(dt)
    if not self.params then return end

    local rate = self.params.difficulty_scaling_rate or 0.01
    local curve = self.params.difficulty_curve or "linear"
    local max_scale = self.params.difficulty_max or 5.0

    self.difficulty_scale = self.difficulty_scale or 1.0

    if curve == "linear" then
        self.difficulty_scale = self.difficulty_scale + rate * dt
    elseif curve == "exponential" then
        self.difficulty_scale = self.difficulty_scale * (1 + rate * dt)
    elseif curve == "wave" then
        local time_factor = self.time_elapsed * 0.5
        self.difficulty_scale = 1.0 + math.sin(time_factor) * 0.5
    end

    self.difficulty_scale = math.min(self.difficulty_scale, max_scale)
end

-- Update scrolling background offset
function BaseGame:updateScrolling(dt)
    if not self.params or not self.params.scroll_speed or self.params.scroll_speed <= 0 then return end
    self.scroll_offset = (self.scroll_offset or 0) + self.params.scroll_speed * dt
end

-- Generic wave state management
-- state: {active, pause_timer, wave_number, ...}
-- config: {count_func, on_depleted, on_start, pause_duration}
-- Returns: "active" if wave running, "paused" if between waves, "started" if new wave just began
function BaseGame:updateWaveState(state, config, dt)
    local pause_duration = config.pause_duration or (self.params and self.params.wave_pause_duration) or 2.0

    if state.active then
        -- Check if wave is depleted
        local count = config.count_func and config.count_func() or 0
        if count <= 0 then
            state.active = false
            state.pause_timer = pause_duration
            if config.on_depleted then config.on_depleted() end
            return "paused"
        end
        return "active"
    else
        -- Wave paused, count down
        state.pause_timer = (state.pause_timer or 0) - dt
        if state.pause_timer <= 0 then
            state.active = true
            state.wave_number = (state.wave_number or 0) + 1
            if config.on_start then config.on_start(state.wave_number) end
            return "started"
        end
        return "paused"
    end
end

-- Player shooting with spawn position and angle calculation
-- Handles asteroids mode (rotational) and normal mode (up/down based on reverse_gravity)
function BaseGame:playerShoot(charge_multiplier)
    charge_multiplier = charge_multiplier or 1.0
    if not self.projectile_system or not self.projectile_system:canShoot() then return end

    local p = self.params
    local player = self.player

    -- Calculate spawn position and angle based on movement type
    local center_x = player.x + player.width / 2
    local center_y = player.y + player.height / 2
    local spawn_x, spawn_y, angle

    if p.movement_type == "asteroids" then
        -- Asteroids mode: shoot from front of ship in facing direction
        -- Note: player.angle is already in radians from movement_controller
        local rad = player.angle or 0
        local offset_distance = player.height / 2
        spawn_x = center_x + math.sin(rad) * offset_distance
        spawn_y = center_y - math.cos(rad) * offset_distance
        -- Convert to standard angle (atan2 format)
        local direction_multiplier = p.reverse_gravity and 1 or -1
        angle = math.atan2(math.cos(rad) * direction_multiplier, math.sin(rad))
    else
        -- Normal mode: shoot from top (or bottom if reverse_gravity)
        spawn_x = center_x
        spawn_y = p.reverse_gravity and (player.y + player.height) or player.y
        angle = p.reverse_gravity and (math.pi / 2) or (-math.pi / 2)
    end

    -- Build pattern config from params
    local pattern = p.bullet_pattern or "single"
    local config = {
        speed_multiplier = charge_multiplier,
        count = p.bullets_per_shot,
        arc = p.bullet_arc,
        spread = 15,
        offset = 5,
        time = love.timer.getTime(),
        custom = {
            width = p.bullet_width,
            height = p.bullet_height,
            piercing = p.bullet_piercing,
            movement_type = (p.bullet_homing and p.homing_strength and p.homing_strength > 0) and "homing_nearest" or nil,
            homing_turn_rate = p.homing_strength,
            wrap_enabled = p.screen_wrap_bullets,
            max_wraps = p.bullet_max_wraps
        }
    }

    self.projectile_system:shootPattern("player_bullet", spawn_x, spawn_y, angle, pattern, config)
    self.projectile_system:onShoot()
    self:playSound("shoot", 0.6)
end

-- Entity shooting (enemies, turrets, etc.)
-- Shoots from entity center, angle based on reverse_gravity
function BaseGame:entityShoot(entity, bullet_type)
    if not self.projectile_system then return end

    bullet_type = bullet_type or "enemy_bullet"
    local p = self.params

    local center_x = entity.x + (entity.width or 0) / 2
    local center_y = entity.y + (entity.height or 0)
    local angle = p.reverse_gravity and (-math.pi / 2) or (math.pi / 2)

    local pattern = p.enemy_bullet_pattern or "single"
    local config = {
        count = p.enemy_bullets_per_shot,
        arc = p.enemy_bullet_spread_angle,
        custom = {
            width = p.enemy_bullet_size or 8,
            height = p.enemy_bullet_size or 8,
            speed = p.enemy_bullet_speed
        }
    }

    self.projectile_system:shootPattern(bullet_type, center_x, center_y, angle, pattern, config)
end

-- Take damage with sound and state updates
-- amount: damage amount (default 1)
-- sound: sound to play (default "hit")
function BaseGame:takeDamage(amount, sound)
    if not self.health_system then return end

    amount = amount or 1
    sound = sound or "hit"

    local absorbed = self.health_system:takeDamage(amount)
    self:playSound(sound, 1.0)

    if not absorbed then
        self.deaths = (self.deaths or 0) + 1
        self.lives = self.health_system.lives
        self.combo = 0
    end

    return absorbed
end

-- Spawn entity with optional weighted configs and entrance animation
-- type_name: entity type (e.g. "enemy")
-- config: {x, y, weighted_configs, entrance, extra}
--   entrance: {pattern, start, target, duration} for bezier entrance animation
function BaseGame:spawnEntity(type_name, config)
    if not self.entity_controller then return nil end

    config = config or {}
    local x = config.x or 0
    local y = config.y or 0
    local extra = config.extra or {}

    -- Handle formation slot (mark occupied, store reference)
    if config.formation_slot then
        config.formation_slot.occupied = true
        extra.formation_slot = config.formation_slot
    end

    -- Handle entrance animation (named presets: "swoop_left", "swoop_right", "loop_left", etc.)
    if config.entrance then
        local PatternMovement = self.di and self.di.components and self.di.components.PatternMovement
        if PatternMovement then
            local ent = type(config.entrance) == "string" and {pattern = config.entrance} or config.entrance
            local pattern = ent.pattern or "swoop_left"

            -- Parse named presets (pattern_side)
            local base_pattern, side = pattern:match("^(%w+)_(%w+)$")
            if not base_pattern then base_pattern, side = pattern, "left" end

            local start_x = ent.start and ent.start.x or (side == "left" and -50 or (self.game_width + 50))
            local start_y = ent.start and ent.start.y or -50
            local target_x, target_y = x, y

            local bezier_path
            if base_pattern == "loop" then
                local mid_x = side == "left" and self.game_width * 0.3 or self.game_width * 0.7
                bezier_path = PatternMovement.buildPath("loop", {
                    start_x = start_x, start_y = start_y,
                    mid_x = mid_x, mid_y = self.game_height * 0.5,
                    end_x = target_x, end_y = target_y
                })
            elseif base_pattern == "dive" then
                bezier_path = PatternMovement.buildPath("dive", {
                    start_x = start_x, start_y = start_y,
                    target_x = target_x, target_y = target_y,
                    exit_x = start_x, exit_y = self.game_height + 50
                })
            else -- swoop
                bezier_path = PatternMovement.buildPath("swoop", {
                    start_x = start_x, start_y = start_y,
                    end_x = target_x, end_y = target_y,
                    curve_y = self.game_height * 0.5
                })
            end

            extra.movement_pattern = 'bezier'
            extra.bezier_path = bezier_path
            extra.bezier_t = 0
            extra.bezier_duration = ent.duration or 2.0
            extra.bezier_complete = false
            extra.home_x = target_x
            extra.home_y = target_y
            x, y = start_x, start_y
        end
    end

    -- Spawn with weighted configs or regular spawn
    if config.weighted_configs and #config.weighted_configs > 0 then
        return self.entity_controller:spawnWeighted(type_name, config.weighted_configs, x, y, extra)
    else
        return self.entity_controller:spawn(type_name, x, y, extra)
    end
end

-- Load sprites from variant sprite_set (override default_sprite_set in subclass if needed)
function BaseGame:loadAssets()
    self.sprites = self.sprites or {}
    local sprite_set = (self.variant and self.variant.sprite_set) or self.default_sprite_set
    local fallback = self.default_sprite_set or sprite_set
    local loader = self.di and self.di.spriteSetLoader

    if loader and sprite_set then
        -- Load player sprite
        self.sprites.player = loader:getSprite(sprite_set, "player", fallback)

        -- Load entity type sprites if params.enemy_types exists
        if self.params and self.params.enemy_types then
            for enemy_type in pairs(self.params.enemy_types) do
                local key = "enemy_" .. enemy_type
                self.sprites[key] = loader:getSprite(sprite_set, key, fallback)
            end
        end
    end

    -- Load audio after sprites
    self:loadAudio()
end

-- Audio helpers (graceful fallback if no audio assets)
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