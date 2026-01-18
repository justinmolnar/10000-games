-- schema_loader.lua
-- Phase 17: Schema Loader Utility
-- Auto-populates game parameters from a JSON schema, eliminating repetitive loader:get() calls
-- Priority order: variant → runtime_config → schema default

local Class = require('lib.class')
local json = require('lib.json')
local SchemaLoader = Class:extend('SchemaLoader')

-- ===================================================================
-- STATIC METHODS (Use these directly without instantiating)
-- ===================================================================

-- Load all parameters from a schema file
-- @param variant: table - Variant data (highest priority)
-- @param schema_name: string - Schema filename (without path, e.g., "snake_schema")
-- @param runtime_config: table (optional) - Runtime config overrides (middle priority)
-- @return table - All parameters with values populated
function SchemaLoader.load(variant, schema_name, runtime_config)
    local schema = SchemaLoader._loadSchema(schema_name)
    if not schema then
        print("[SchemaLoader] Warning: Could not load schema '" .. tostring(schema_name) .. "', returning empty params")
        return {}
    end

    return SchemaLoader._populateParams(schema, variant or {}, runtime_config or {})
end

-- Load schema from Lua table directly (for testing or inline schemas)
-- @param variant: table - Variant data
-- @param schema: table - Schema definition table
-- @param runtime_config: table (optional) - Runtime config overrides
-- @return table - All parameters with values populated
function SchemaLoader.loadFromTable(variant, schema, runtime_config)
    if not schema or not schema.parameters then
        print("[SchemaLoader] Warning: Invalid schema table, returning empty params")
        return {}
    end

    return SchemaLoader._populateParams(schema, variant or {}, runtime_config or {})
end

-- ===================================================================
-- INTERNAL METHODS
-- ===================================================================

-- Load and parse a schema JSON file
function SchemaLoader._loadSchema(schema_name)
    local path = "assets/data/schemas/" .. schema_name .. ".json"

    local success, contents = pcall(love.filesystem.read, path)
    if not success or not contents then
        print("[SchemaLoader] Could not read schema file: " .. path)
        return nil
    end

    local parse_success, schema = pcall(json.decode, contents)
    if not parse_success or not schema then
        print("[SchemaLoader] Could not parse schema JSON: " .. path)
        return nil
    end

    return schema
end

-- Populate parameters from schema with variant/config overrides
function SchemaLoader._populateParams(schema, variant, runtime_config)
    local params = {}

    if not schema.parameters then
        return params
    end

    for key, def in pairs(schema.parameters) do
        params[key] = SchemaLoader._resolveValue(key, def, variant, runtime_config)
    end

    -- Handle nested parameter groups if defined
    if schema.groups then
        for group_name, group_def in pairs(schema.groups) do
            params[group_name] = {}
            for key, def in pairs(group_def) do
                local full_key = group_name .. "." .. key
                -- Check variant for both nested and flat keys
                local variant_value = variant[full_key] or (variant[group_name] and variant[group_name][key])
                local config_value = SchemaLoader._getNestedValue(runtime_config, full_key)

                params[group_name][key] = SchemaLoader._resolveValueDirect(
                    def,
                    variant_value,
                    config_value
                )
            end
        end
    end

    return params
end

-- Resolve a single parameter value with priority: variant → config → default
function SchemaLoader._resolveValue(key, def, variant, runtime_config)
    local variant_value = variant[key]
    local config_value = SchemaLoader._getNestedValue(runtime_config, key)

    return SchemaLoader._resolveValueDirect(def, variant_value, config_value)
end

-- Resolve value given definition and override values
function SchemaLoader._resolveValueDirect(def, variant_value, config_value)
    local value

    -- Priority: variant → config → default
    if variant_value ~= nil then
        value = variant_value
    elseif config_value ~= nil then
        value = config_value
    else
        value = def.default
    end

    -- Type coercion and validation
    value = SchemaLoader._coerceType(value, def.type)
    value = SchemaLoader._validateConstraints(value, def)

    return value
end

-- Coerce value to expected type
function SchemaLoader._coerceType(value, expected_type)
    if value == nil then
        return nil
    end

    if expected_type == "number" then
        if type(value) == "number" then
            return value
        elseif type(value) == "string" then
            return tonumber(value) or 0
        end
        return 0

    elseif expected_type == "integer" then
        if type(value) == "number" then
            return math.floor(value)
        elseif type(value) == "string" then
            return math.floor(tonumber(value) or 0)
        end
        return 0

    elseif expected_type == "boolean" then
        if type(value) == "boolean" then
            return value
        elseif type(value) == "string" then
            return value == "true" or value == "1"
        elseif type(value) == "number" then
            return value ~= 0
        end
        return false

    elseif expected_type == "string" then
        if type(value) == "string" then
            return value
        end
        return tostring(value)

    elseif expected_type == "enum" then
        -- Enum values are strings, validated separately
        return value

    elseif expected_type == "table" or expected_type == "array" then
        if type(value) == "table" then
            return value
        end
        return {}
    end

    -- Unknown type, return as-is
    return value
end

-- Validate value against constraints (min, max, enum values)
function SchemaLoader._validateConstraints(value, def)
    if value == nil then
        return def.default
    end

    -- Min/max for numbers
    if def.type == "number" or def.type == "integer" then
        if def.min ~= nil and value < def.min then
            value = def.min
        end
        if def.max ~= nil and value > def.max then
            value = def.max
        end
    end

    -- Enum validation
    if def.type == "enum" and def.values then
        local valid = false
        for _, v in ipairs(def.values) do
            if v == value then
                valid = true
                break
            end
        end
        if not valid then
            value = def.default
        end
    end

    return value
end

-- Helper: Navigate nested tables with dot notation
function SchemaLoader._getNestedValue(tbl, key)
    if not tbl then return nil end
    if not key then return nil end

    -- If key has no dots, direct access
    if not key:find("%.") then
        return tbl[key]
    end

    -- Split by dots and traverse
    local current = tbl
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
-- UTILITY METHODS
-- ===================================================================

-- Get schema metadata (for debugging/tooling)
function SchemaLoader.getSchemaInfo(schema_name)
    local schema = SchemaLoader._loadSchema(schema_name)
    if not schema then
        return nil
    end

    local info = {
        name = schema.name or schema_name,
        description = schema.description or "",
        parameter_count = 0,
        parameters = {}
    }

    if schema.parameters then
        for key, def in pairs(schema.parameters) do
            info.parameter_count = info.parameter_count + 1
            info.parameters[key] = {
                type = def.type,
                default = def.default,
                description = def.description
            }
        end
    end

    return info
end

-- Validate a variant against a schema (returns list of warnings)
function SchemaLoader.validateVariant(variant, schema_name)
    local schema = SchemaLoader._loadSchema(schema_name)
    if not schema then
        return { "Could not load schema: " .. tostring(schema_name) }
    end

    local warnings = {}

    -- Check for unknown keys in variant
    for key, value in pairs(variant) do
        if schema.parameters and not schema.parameters[key] then
            -- Check if it's a known non-parameter field
            local known_fields = { "name", "clone_index", "id", "display_name", "sprite_set" }
            local is_known = false
            for _, field in ipairs(known_fields) do
                if key == field then
                    is_known = true
                    break
                end
            end
            if not is_known then
                table.insert(warnings, "Unknown parameter in variant: " .. key)
            end
        end
    end

    return warnings
end

return SchemaLoader
