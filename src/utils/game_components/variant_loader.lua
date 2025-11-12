-- variant_loader.lua
-- Phase 7: Variant Loader Utility
-- Simplifies three-tier parameter loading (variant → runtime_config → default)

local Class = require('lib.class')
local VariantLoader = Class:extend('VariantLoader')

-- ===================================================================
-- INITIALIZATION
-- ===================================================================

function VariantLoader:init(variant, runtime_config, defaults)
    self.variant = variant or {}
    self.runtime_config = runtime_config or {}
    self.defaults = defaults or {}
end

-- ===================================================================
-- CORE LOOKUP
-- ===================================================================

-- Three-tier lookup: variant → runtime_config → default
-- Supports nested keys like "player.speed" or "arena.width"
function VariantLoader:get(key, fallback)
    -- Try variant first (highest priority)
    if self.variant and self.variant[key] ~= nil then
        return self.variant[key]
    end

    -- Try runtime config (middle priority)
    -- Support nested key access like "player.speed"
    local value = self:_getNestedValue(self.runtime_config, key)
    if value ~= nil then
        return value
    end

    -- Try defaults table (lowest priority)
    if self.defaults[key] ~= nil then
        return self.defaults[key]
    end

    -- Final fallback
    return fallback
end

-- Helper: Navigate nested tables with dot notation
-- Example: _getNestedValue(cfg, "player.speed") → cfg.player.speed
function VariantLoader:_getNestedValue(table, key)
    if not table then return nil end
    if not key then return nil end

    -- If key has no dots, direct access
    if not key:find("%.") then
        return table[key]
    end

    -- Split by dots and traverse
    local current = table
    for part in key:gmatch("[^%.]+") do
        if type(current) ~= "table" then
            return nil
        end
        current = current[part]
        if current == nil then
            return nil
        end
    end
    return current
end

-- ===================================================================
-- TYPE-SPECIFIC GETTERS
-- ===================================================================

-- Get a number value (ensures type)
function VariantLoader:getNumber(key, fallback)
    local value = self:get(key, fallback)
    if type(value) == "number" then
        return value
    end
    return fallback
end

-- Get a boolean value (handles nil vs false correctly)
-- IMPORTANT: In Lua, nil and false are different!
-- - If variant explicitly sets false, we should use false
-- - If variant doesn't define it (nil), we should fall through to next tier
function VariantLoader:getBoolean(key, fallback)
    -- Check variant first (explicit false is valid)
    if self.variant and self.variant[key] ~= nil then
        return not not self.variant[key]  -- Coerce to boolean
    end

    -- Check runtime config
    local value = self:_getNestedValue(self.runtime_config, key)
    if value ~= nil then
        return not not value
    end

    -- Check defaults
    if self.defaults[key] ~= nil then
        return not not self.defaults[key]
    end

    -- Final fallback
    return fallback
end

-- Get a string value (ensures type)
function VariantLoader:getString(key, fallback)
    local value = self:get(key, fallback)
    if type(value) == "string" then
        return value
    end
    return fallback
end

-- Get a table value (ensures type)
function VariantLoader:getTable(key, fallback)
    local value = self:get(key, fallback)
    if type(value) == "table" then
        return value
    end
    return fallback
end

-- ===================================================================
-- BATCH OPERATIONS
-- ===================================================================

-- Get multiple values at once
-- Example: loader:getMultiple({ player_speed = 300, enemy_count = 10 })
-- Returns: { player_speed = <loaded_value>, enemy_count = <loaded_value> }
function VariantLoader:getMultiple(keys_and_defaults)
    local result = {}
    for key, default in pairs(keys_and_defaults) do
        result[key] = self:get(key, default)
    end
    return result
end

-- ===================================================================
-- UTILITY METHODS
-- ===================================================================

-- Check if a key exists in any tier (useful for conditional logic)
function VariantLoader:has(key)
    return self:get(key, nil) ~= nil
end

-- Get the source tier where a value came from (for debugging)
-- Returns: "variant", "runtime_config", "defaults", or nil
function VariantLoader:getSource(key)
    if self.variant and self.variant[key] ~= nil then
        return "variant"
    end

    if self:_getNestedValue(self.runtime_config, key) ~= nil then
        return "runtime_config"
    end

    if self.defaults[key] ~= nil then
        return "defaults"
    end

    return nil
end

return VariantLoader
