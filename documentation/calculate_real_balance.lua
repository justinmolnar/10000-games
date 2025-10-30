-- Calculate ACTUAL balance based on variant JSON data
-- Run this with: lua documentation/calculate_real_balance.lua

local json = require('json')

-- Read variant files
local function read_variants(filename)
    local file = io.open(filename, "r")
    if not file then return {} end
    local content = file:read("*all")
    file:close()
    return json.decode(content)
end

-- Formulas
local formulas = {
    dodge = function(dodges, collisions)
        return (dodges * dodges) / (collisions + 1)
    end,
    snake = function(length, survival_time)
        return length * (survival_time / 10)
    end,
    memory = function(matches, time, perfect)
        return (matches * 10) - time + (perfect * 5)
    end
}

-- Base values
local BASE_DODGE_TARGET = 30
local BASE_SNAKE_TARGET = 20
local BASE_SNAKE_TIME = 60 -- assumption

-- Calculate for dodge variants
print("=== DODGE GAME ===")
print("Base formula: (dodges² / (collisions + 1))")
print("Base dodge target: " .. BASE_DODGE_TARGET)
print("")

local dodge_variants = read_variants("assets/data/variants/dodge_variants.json")
for i, variant in ipairs(dodge_variants) do
    local clone_index = variant.clone_index
    local multiplier = clone_index == 0 and 1 or clone_index
    local victory_limit = variant.victory_limit or BASE_DODGE_TARGET
    local diff_mod = variant.difficulty_modifier or 1.0

    -- Perfect game: victory_limit dodges, 0 collisions
    local base_power = formulas.dodge(victory_limit, 0)
    local final_power = base_power * multiplier

    print(string.format("[%d] %s", clone_index, variant.name))
    print(string.format("  Victory: %d dodges | Multiplier: %d | Difficulty: %.1f",
        victory_limit, multiplier, diff_mod))
    print(string.format("  Perfect power: %d² = %d * %d = %d",
        victory_limit, base_power, multiplier, final_power))
    print("")

    if clone_index >= 10 then break end -- Just first 10 for now
end
