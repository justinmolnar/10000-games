-- src/models/cheat_system.lua
-- Manages cheat definitions and active cheats for the next game
-- NEW: Also handles dynamic parameter modification system
local Object = require('class')
local CheatSystem = Object:extend('CheatSystem')

function CheatSystem:init(config)
    -- Store config for accessing cheat_engine settings
    self.config = config or {}
    self.cheat_config = self.config.cheat_engine or {}

    -- ========================================================================
    -- LEGACY SYSTEM: Preset cheats (old system, kept for compatibility)
    -- ========================================================================

    -- This now just defines the *names* and *descriptions*
    -- The costs and levels are in config.lua game_defaults
    self.cheat_definitions = {
        speed_modifier = {
            id = "speed_modifier",
            name = "Speed Modifier",
            description = "Slows enemies, objects, or timers."
        },
        advantage_modifier = {
            id = "advantage_modifier",
            name = "Advantage",
            description = "Grants extra lives or collisions."
        },
        performance_modifier = {
            id = "performance_modifier",
            name = "Score Multiplier",
            description = "Multiplies your final score/power."
        },
        aim_assist = {
            id = "aim_assist",
            name = "Aim Assist (FAKE)",
            description = "Automatically targets enemies. (Not really)",
            is_fake = true
        },
        god_mode = {
            id = "god_mode",
            name = "God Mode (FAKE)",
            description = "Become invincible! (Or not)",
            is_fake = true
        }
    }

    -- This stores the *final calculated values* to be applied, not just booleans
    -- e.g. { game_id = { speed_modifier = 0.7, advantage_modifier = { deaths = 2 } } }
    self.active_cheats = {}
end

-- ============================================================================
-- LEGACY SYSTEM METHODS (kept for backwards compatibility)
-- ============================================================================

-- Get a list of all cheat definitions
function CheatSystem:getCheatDefinitions()
    return self.cheat_definitions
end

-- Get the *static definition* (name, desc) for a cheat
function CheatSystem:getCheatDefinition(cheat_id)
    return self.cheat_definitions[cheat_id]
end

-- Called by CheatEngineState to set cheats for the next run
-- selected_cheats is now a table of *values*, not booleans
-- e.g. { speed_modifier = 0.7, advantage_modifier = { deaths = 2 } }
function CheatSystem:activateCheats(game_id, selected_cheats)
    self.active_cheats = {} -- Clear previous cheats
    self.active_cheats[game_id] = selected_cheats
    print("Cheats activated for " .. game_id)
end

-- Called by MinigameState to get cheats for the starting game
function CheatSystem:getActiveCheats(game_id)
    return self.active_cheats[game_id]
end

-- Called by MinigameState after applying cheats
function CheatSystem:consumeCheats(game_id)
    self.active_cheats[game_id] = nil
end

-- ============================================================================
-- NEW: DYNAMIC PARAMETER MODIFICATION SYSTEM
-- ============================================================================

-- Get all modifiable parameters from a variant's JSON
-- Returns array of parameter definitions: { key, type, value, original }
function CheatSystem:getModifiableParameters(variant_data)
    if not variant_data then
        return {}
    end

    local params = {}
    local hidden = self.cheat_config.hidden_parameters or {}
    local ranges = self.cheat_config.parameter_ranges or {}

    for key, value in pairs(variant_data) do
        -- Skip hidden parameters
        local is_hidden = false
        for _, hidden_key in ipairs(hidden) do
            if hidden_key == key then
                is_hidden = true
                break
            end
        end

        if not is_hidden then
            local param_type = type(value)
            if param_type == "number" then
                local param_def = {
                    key = key,
                    type = "number",
                    value = value,
                    original = value
                }
                if ranges[key] then
                    param_def.min = ranges[key].min
                    param_def.max = ranges[key].max
                else
                    -- Auto-compute reasonable range when none defined
                    param_def.min = 0
                    param_def.max = math.max(math.abs(value) * 2, 1)
                end
                table.insert(params, param_def)
            elseif param_type == "boolean" then
                table.insert(params, {
                    key = key,
                    type = "boolean",
                    value = value,
                    original = value
                })
            end
            -- Skip string, table, and array types entirely
        end
    end

    -- Sort alphabetically by key
    table.sort(params, function(a, b) return a.key < b.key end)

    return params
end

-- Validate and clamp a parameter value to its defined range
-- Returns: clamped_value, was_clamped
function CheatSystem:clampParameterValue(param_key, value, param_min, param_max)
    if type(value) ~= "number" then
        return value, false
    end

    -- Use explicit param bounds (from getModifiableParameters) if provided,
    -- otherwise fall back to config ranges
    local lo = param_min
    local hi = param_max
    if not lo or not hi then
        local ranges = self.cheat_config.parameter_ranges or {}
        local range = ranges[param_key]
        if range then
            lo = lo or range.min
            hi = hi or range.max
        end
    end

    if not lo and not hi then
        return value, false
    end

    local clamped = value
    local was_clamped = false

    if lo and value < lo then
        clamped = lo
        was_clamped = true
    end

    if hi and value > hi then
        clamped = hi
        was_clamped = true
    end

    return clamped, was_clamped
end

-- Calculate cost for a modification
-- Returns: cost in credits (number)
function CheatSystem:calculateModificationCost(param_key, param_type, original_value, new_value, modifications_count, step_size, water_level, skill_reduction)
    local costs = self.cheat_config.parameter_costs or {}
    local overrides = self.cheat_config.parameter_overrides or {}
    local global_mult = self.cheat_config.cheat_cost_multiplier or 1.0
    local exponent = self.cheat_config.cheat_cost_exponent or 1.5

    -- Get base cost for this parameter type
    -- Map internal types to config keys (config uses "numeric", code uses "number")
    local type_key = param_type
    if param_type == "number" then type_key = "numeric" end
    local type_costs = costs[type_key]
    if not type_costs then
        return 100
    end

    local base_cost = type_costs.base_cost or 100

    -- Apply override if exists for this specific parameter
    if overrides[param_key] then
        if overrides[param_key].base_cost then
            base_cost = overrides[param_key].base_cost
        end
        if overrides[param_key].exponent then
            exponent = overrides[param_key].exponent
        end
    end

    -- Water discount: each level reduces costs by cost_reduction_per_level, floor at 75%
    local water_config = self.config.water_upgrades or {}
    local reduction_per_level = water_config.cost_reduction_per_level or 0.05
    local water_discount = math.max(0.75, 1 - (water_level or 0) * reduction_per_level)

    -- Skill tree global cost reduction (stacks with water discount, combined floor at 50%)
    local skill_discount = math.max(0.50, 1 - (skill_reduction or 0))
    water_discount = math.max(0.50, water_discount * skill_discount)

    -- If value is back at original, cost is 0 (full refund)
    if new_value == original_value then
        return 0
    end

    -- For numeric params: cost scales with distance from original value
    -- The further you push a param, the more each step costs
    if param_type == "number" and type(original_value) == "number" and type(new_value) == "number" then
        local ranges = self.cheat_config.parameter_ranges or {}
        local range = ranges[param_key]
        local lo = range and range.min or 0
        local hi = range and range.max or math.max(math.abs(original_value) * 2, 1)
        local span = hi - lo
        if span <= 0 then span = 1 end

        -- Distance from original as fraction of total range (0.0 to 1.0+)
        local distance_pct = math.abs(new_value - original_value) / span
        -- Exponential: small tweaks are cheap, big pushes get expensive fast
        local cost = base_cost * global_mult * water_discount * (distance_pct ^ exponent)
        return math.max(1, math.floor(cost + 0.5))
    end

    -- Non-numeric types: flat base cost
    return math.max(1, math.floor(base_cost * global_mult * water_discount + 0.5))
end

-- Check if modification is allowed
-- Returns: { allowed = true/false, reason = "string" }
function CheatSystem:canModify(player_data, game_id, param_key, new_value)
    if not player_data or not game_id or not param_key then
        return { allowed = false, reason = "Missing required parameters" }
    end

    -- Check if parameter is hidden
    local hidden = self.cheat_config.hidden_parameters or {}
    for _, hidden_key in ipairs(hidden) do
        if hidden_key == param_key then
            return { allowed = false, reason = "Parameter is locked" }
        end
    end

    -- Check unlockable modifications (future feature)
    -- For now, everything is allowed if not hidden

    return { allowed = true, reason = "" }
end

-- Apply a modification to a game parameter
-- Returns: { success = true/false, cost = number, new_budget = number, error = "string" }
function CheatSystem:applyModification(player_data, game_id, param_key, param_type, original_value, new_value, water_level, skill_reduction)
    if not player_data or not game_id or not param_key then
        return { success = false, error = "Missing required parameters" }
    end

    -- Check if allowed
    local can_modify = self:canModify(player_data, game_id, param_key, new_value)
    if not can_modify.allowed then
        return { success = false, error = can_modify.reason }
    end

    -- If moving back to original, just reset the parameter entirely
    if new_value == original_value then
        local refund = player_data:removeCheatModification(game_id, param_key)
        return {
            success = true,
            cost = 0,
            new_budget = player_data:getAvailableBudget(game_id)
        }
    end

    -- Calculate cost based on distance from original
    local cost = self:calculateModificationCost(
        param_key,
        param_type,
        original_value,
        new_value,
        nil,
        nil,
        water_level,
        skill_reduction
    )

    -- Check budget: account for old cost being freed when adjusting existing modification
    local available = player_data:getAvailableBudget(game_id)
    local old_cost = 0
    local modifications = player_data:getGameModifications(game_id)
    if modifications[param_key] then
        old_cost = modifications[param_key].cost_spent or 0
    end
    local net_cost = cost - old_cost
    if net_cost > available then
        return {
            success = false,
            error = "Insufficient budget. Need: " .. net_cost .. ", Have: " .. available
        }
    end

    -- Apply modification via PlayerData
    player_data:applyCheatModification(game_id, param_key, original_value, new_value, cost)

    return {
        success = true,
        cost = cost,
        new_budget = player_data:getAvailableBudget(game_id)
    }
end

-- Reset a single parameter
-- Returns: { success = true/false, refund = number }
function CheatSystem:resetParameter(player_data, game_id, param_key)
    if not player_data or not game_id or not param_key then
        return { success = false, refund = 0 }
    end

    local refund = player_data:removeCheatModification(game_id, param_key)

    return { success = true, refund = refund }
end

-- Reset all modifications for a game
-- Returns: { success = true/false, refund = number }
function CheatSystem:resetAllModifications(player_data, game_id)
    if not player_data or not game_id then
        return { success = false, refund = 0 }
    end

    local total_refund = player_data:resetAllGameModifications(game_id)

    return { success = true, refund = total_refund }
end

-- Deep copy a table (helper function)
local function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
        setmetatable(copy, deepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Get modified variant data with all modifications applied
-- Returns: modified variant table (deep copy with modifications)
function CheatSystem:getModifiedVariant(variant_data, modifications)
    if not variant_data then
        return {}
    end

    -- Deep copy variant data
    local modified_variant = deepCopy(variant_data)

    -- Apply all modifications
    if modifications then
        for param_key, mod in pairs(modifications) do
            if modified_variant[param_key] ~= nil then
                modified_variant[param_key] = mod.modified
            end
        end
    end

    return modified_variant
end

return CheatSystem
