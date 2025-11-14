--[[
ScoringSystem - Phase 14: Data-driven scoring/formula component

Handles:
- Formula-based token calculation from metrics
- Multiple curve types (linear, sqrt, log, exponential)
- Weighted metric combination
- Multiplier application
- Breakdown generation for debugging

Usage:
    local ScoringSystem = require('src.utils.game_components.scoring_system')

    self.scoring_system = ScoringSystem:new({
        formula_string = "((metrics.dodges - metrics.deaths * 3) * 10 * scaling_constant)",
        -- Or use declarative config:
        base_value = 100,
        metrics = {
            dodges = {weight = 1.0, curve = "sqrt", scale = 10},
            time = {weight = 2.0, curve = "linear", scale = 5}
        },
        multipliers = {
            difficulty = {easy = 0.8, normal = 1.0, hard = 1.5}
        }
    })

    -- Calculate tokens:
    local tokens = self.scoring_system:calculate(self.metrics, {difficulty = "normal"})

    -- Get detailed breakdown:
    local breakdown = self.scoring_system:getBreakdown(self.metrics, {difficulty = "normal"})
]]

local Object = require('class')
local ScoringSystem = Object:extend('ScoringSystem')

-- Curve type functions
ScoringSystem.CURVE_FUNCTIONS = {
    linear = function(value, scale)
        return value * (scale or 1)
    end,

    sqrt = function(value, scale)
        return math.sqrt(math.abs(value)) * (scale or 1)
    end,

    log = function(value, scale)
        return math.log(math.max(1, math.abs(value))) * (scale or 1)
    end,

    exponential = function(value, scale, base)
        base = base or 2
        return math.pow(base, value) * (scale or 1)
    end,

    binary = function(value, scale)
        -- Boolean value: returns scale if value is truthy, 0 otherwise
        return (value and value ~= 0) and (scale or 1) or 0
    end,

    power = function(value, scale, exponent)
        exponent = exponent or 2
        return math.pow(math.abs(value), exponent) * (scale or 1)
    end
}

--[[
    Create a new scoring system

    @param config table - Configuration:
        - formula_string: Lua formula string (like existing system)
        - OR declarative metrics config:
            - base_value: Starting value
            - metrics: {
                metric_name = {
                    weight: Relative importance
                    curve: "linear", "sqrt", "log", "exponential", "binary", "power"
                    scale: Multiplier
                    exponent: For power curve (optional)
                    base: For exponential curve (optional)
                    min/max: Clamp values (optional)
                }
            }
            - multipliers: {
                multiplier_name = value or table
            }
        - scaling_constant: Global scaling factor (default: 1)
]]
function ScoringSystem:new(config)
    local instance = ScoringSystem.super.new(self)

    instance.config = config or {}
    instance.scaling_constant = config.scaling_constant or 1

    -- If formula_string provided, use legacy formula system
    if config.formula_string then
        instance.mode = "formula"
        instance.formula_function = instance:createFormulaFunction(config.formula_string)
        instance.formula_string = config.formula_string
    else
        -- Use declarative metrics system
        instance.mode = "declarative"
        instance.base_value = config.base_value or 0
        instance.metrics_config = config.metrics or {}
        instance.multipliers_config = config.multipliers or {}
    end

    return instance
end

--[[
    Create a formula function from string (legacy compatibility)

    @param formula_string string - Lua expression using metrics.* variables
    @return function - Compiled formula function
]]
function ScoringSystem:createFormulaFunction(formula_string)
    if not formula_string or formula_string == "" then
        print("[ScoringSystem] Warning: Empty formula string")
        return function(metrics) return 0 end
    end

    local func_body = "local metrics, scaling_constant = ...; metrics = metrics or {}; local value = (" .. formula_string .. "); return value"
    local formula_chunk, load_err = loadstring(func_body, "Formula:" .. formula_string)

    if not formula_chunk then
        print("[ScoringSystem] ERROR loading formula: " .. formula_string)
        print("[ScoringSystem] Error: " .. tostring(load_err))
        return function(metrics) return 0 end
    end

    -- Return wrapped function with error handling
    return function(metrics)
        local call_ok, result = pcall(formula_chunk, metrics, self.scaling_constant)
        if not call_ok then
            print("[ScoringSystem] ERROR executing formula: " .. tostring(result))
            return 0
        end
        return result or 0
    end
end

--[[
    Calculate token value from metrics

    @param metrics table - Metric values (e.g., {dodges = 10, time = 30})
    @param multipliers table (optional) - Active multipliers (e.g., {difficulty = "hard"})
    @return number - Final token value
]]
function ScoringSystem:calculate(metrics, multipliers)
    metrics = metrics or {}
    multipliers = multipliers or {}

    if self.mode == "formula" then
        -- Legacy formula string mode
        return self.formula_function(metrics)
    else
        -- Declarative metrics mode
        local base = self.base_value
        local metric_sum = 0

        -- Calculate weighted metric values
        for metric_name, metric_config in pairs(self.metrics_config) do
            local value = metrics[metric_name] or 0

            -- Clamp if min/max specified
            if metric_config.min then value = math.max(metric_config.min, value) end
            if metric_config.max then value = math.min(metric_config.max, value) end

            -- Apply curve
            local curve_func = ScoringSystem.CURVE_FUNCTIONS[metric_config.curve or "linear"]
            if not curve_func then
                print("[ScoringSystem] Warning: Unknown curve type '" .. tostring(metric_config.curve) .. "', using linear")
                curve_func = ScoringSystem.CURVE_FUNCTIONS.linear
            end

            local transformed = curve_func(
                value,
                metric_config.scale or 1,
                metric_config.exponent or metric_config.base
            )

            -- Apply weight
            metric_sum = metric_sum + (transformed * (metric_config.weight or 1))
        end

        -- Calculate total before multipliers
        local subtotal = base + metric_sum

        -- Apply multipliers
        local total = subtotal
        for mult_name, mult_config in pairs(self.multipliers_config) do
            local mult_value = multipliers[mult_name]

            if type(mult_config) == "table" then
                -- Lookup table (e.g., difficulty = {easy = 0.8, normal = 1.0})
                local mult = mult_config[mult_value] or 1.0
                total = total * mult
            elseif type(mult_config) == "function" then
                -- Function multiplier (e.g., speed_bonus = function(time) return ... end)
                local mult = mult_config(mult_value) or 1.0
                total = total * mult
            else
                -- Direct multiplier value
                if mult_value then
                    total = total * (mult_config or 1.0)
                end
            end
        end

        return math.max(0, total)
    end
end

--[[
    Get detailed breakdown of score calculation (for debugging/UI)

    @param metrics table - Metric values
    @param multipliers table (optional) - Active multipliers
    @return table - Breakdown: {base, metrics = {}, multipliers = {}, subtotal, total}
]]
function ScoringSystem:getBreakdown(metrics, multipliers)
    metrics = metrics or {}
    multipliers = multipliers or {}

    if self.mode == "formula" then
        -- Formula mode: can't provide detailed breakdown
        return {
            mode = "formula",
            formula = self.formula_string,
            total = self.formula_function(metrics)
        }
    else
        -- Declarative mode: full breakdown
        local breakdown = {
            base = self.base_value,
            metrics = {},
            multipliers = {},
            subtotal = 0,
            total = 0
        }

        local metric_sum = 0

        -- Calculate each metric contribution
        for metric_name, metric_config in pairs(self.metrics_config) do
            local value = metrics[metric_name] or 0
            local original_value = value

            -- Clamp
            if metric_config.min then value = math.max(metric_config.min, value) end
            if metric_config.max then value = math.min(metric_config.max, value) end

            -- Apply curve
            local curve_func = ScoringSystem.CURVE_FUNCTIONS[metric_config.curve or "linear"]
            local transformed = curve_func(
                value,
                metric_config.scale or 1,
                metric_config.exponent or metric_config.base
            )

            -- Apply weight
            local contribution = transformed * (metric_config.weight or 1)
            metric_sum = metric_sum + contribution

            breakdown.metrics[metric_name] = {
                original = original_value,
                clamped = value,
                curve = metric_config.curve or "linear",
                transformed = transformed,
                weight = metric_config.weight or 1,
                contribution = contribution
            }
        end

        breakdown.subtotal = breakdown.base + metric_sum
        breakdown.total = breakdown.subtotal

        -- Apply multipliers
        for mult_name, mult_config in pairs(self.multipliers_config) do
            local mult_value = multipliers[mult_name]
            local mult = 1.0

            if type(mult_config) == "table" then
                mult = mult_config[mult_value] or 1.0
            elseif type(mult_config) == "function" then
                mult = mult_config(mult_value) or 1.0
            else
                if mult_value then
                    mult = mult_config or 1.0
                end
            end

            breakdown.multipliers[mult_name] = {
                value = mult_value,
                multiplier = mult
            }
            breakdown.total = breakdown.total * mult
        end

        breakdown.total = math.max(0, breakdown.total)

        return breakdown
    end
end

--[[
    Get formula string (for UI display)
]]
function ScoringSystem:getFormulaString()
    if self.mode == "formula" then
        return self.formula_string
    else
        return "Declarative metrics config (use getBreakdown() for details)"
    end
end

return ScoringSystem
