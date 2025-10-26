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
    -- The costs and levels are in base_game_definitions.json
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
                table.insert(params, {
                    key = key,
                    type = "number",
                    value = value,
                    original = value
                })
            elseif param_type == "boolean" then
                table.insert(params, {
                    key = key,
                    type = "boolean",
                    value = value,
                    original = value
                })
            elseif param_type == "string" then
                table.insert(params, {
                    key = key,
                    type = "string",
                    value = value,
                    original = value
                })
            elseif param_type == "table" then
                -- Array parameters (enemies, holes)
                table.insert(params, {
                    key = key,
                    type = "array",
                    value = value,
                    original = value
                })
            end
        end
    end

    -- Sort alphabetically by key
    table.sort(params, function(a, b) return a.key < b.key end)

    return params
end

-- Calculate cost for a modification
-- Returns: cost in credits (number)
function CheatSystem:calculateModificationCost(param_key, param_type, current_value, new_value, modifications_count, step_size)
    local costs = self.cheat_config.parameter_costs or {}
    local overrides = self.cheat_config.parameter_overrides or {}

    -- Get base cost for this parameter type
    local type_costs = costs[param_type]
    if not type_costs then
        -- Fallback if type not found
        return 100
    end

    local base_cost = type_costs.base_cost or 100
    local exp_scale = type_costs.exponential_scale or 1.0

    -- Apply override if exists for this specific parameter
    if overrides[param_key] then
        if overrides[param_key].base_cost then
            base_cost = overrides[param_key].base_cost
        end
        if overrides[param_key].exponential_scale then
            exp_scale = overrides[param_key].exponential_scale
        end
    end

    -- Apply exponential scaling based on modification count
    local scaled_cost = base_cost * (exp_scale ^ (modifications_count or 0))

    -- For numeric types, apply step cost multiplier
    if param_type == "number" and step_size and type_costs.step_costs then
        local step_multiplier = type_costs.step_costs[step_size]
        if step_multiplier then
            scaled_cost = scaled_cost * step_multiplier
        end
    end

    return math.floor(scaled_cost)
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
function CheatSystem:applyModification(player_data, game_id, param_key, param_type, original_value, new_value)
    if not player_data or not game_id or not param_key then
        return { success = false, error = "Missing required parameters" }
    end

    -- Check if allowed
    local can_modify = self:canModify(player_data, game_id, param_key, new_value)
    if not can_modify.allowed then
        return { success = false, error = can_modify.reason }
    end

    -- Calculate cost
    local modifications_count = player_data:getGameModificationCount(game_id)
    local step_size = 1 -- Default step size (will be passed from UI later)
    local cost = self:calculateModificationCost(
        param_key,
        param_type,
        original_value,
        new_value,
        modifications_count,
        step_size
    )

    -- Check budget
    local available = player_data:getAvailableBudget(game_id)
    if cost > available then
        return {
            success = false,
            error = "Insufficient budget. Need: " .. cost .. ", Have: " .. available
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
