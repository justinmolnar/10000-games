-- src/utils/theme_manager.lua
-- Singleton that holds the active theme's color table.
-- Views read colors via ThemeManager.get("key.path") instead of config hardcodes.

local json = require('json')

local ThemeManager = {}

local THEMES_DIR = "assets/data/themes"
local active_theme = nil
local active_theme_name = "default"
local themes_cache = {} -- name -> parsed theme data
local _event_bus = nil
local _settings_manager = nil
local _system_sounds = nil

-- Flatten a nested table into dot-separated keys for fast lookup
local flat_cache = {}

local function flatten(tbl, prefix, out)
    for k, v in pairs(tbl) do
        local key = prefix and (prefix .. "." .. k) or k
        if type(v) == 'table' and #v == 0 and next(v) then
            -- It's a dict-like table, recurse
            flatten(v, key, out)
        else
            out[key] = v
        end
    end
end

local function rebuildFlatCache()
    flat_cache = {}
    if active_theme and active_theme.colors then
        flatten(active_theme.colors, nil, flat_cache)
    end
end

function ThemeManager.inject(di)
    if di then
        _event_bus = di.eventBus
        _settings_manager = di.settingsManager
        _system_sounds = di.systemSounds
    end
end

function ThemeManager.scanThemes()
    themes_cache = {}
    local ok, items = pcall(love.filesystem.getDirectoryItems, THEMES_DIR)
    if not ok or not items then
        print("[ThemeManager] Could not read themes directory: " .. THEMES_DIR)
        return
    end

    for _, filename in ipairs(items) do
        local id = filename:match("^(.+)%.json$")
        if id then
            local file_path = THEMES_DIR .. "/" .. filename
            local read_ok, contents = pcall(love.filesystem.read, file_path)
            if read_ok and contents then
                local decode_ok, data = pcall(json.decode, contents)
                if decode_ok and data and data.colors then
                    themes_cache[id] = data
                end
            end
        end
    end

    local count = 0
    for _ in pairs(themes_cache) do count = count + 1 end
    print("[ThemeManager] Found " .. count .. " themes")
end

function ThemeManager.getAvailableThemes()
    local list = {}
    for id, theme in pairs(themes_cache) do
        table.insert(list, { id = id, name = theme.name or id })
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function ThemeManager.setTheme(name)
    local theme = themes_cache[name]
    if not theme then
        print("[ThemeManager] Theme not found: " .. tostring(name) .. ", falling back to default")
        theme = themes_cache["default"]
        name = "default"
    end
    if not theme then
        print("[ThemeManager] No default theme available!")
        return
    end

    active_theme = theme
    active_theme_name = name
    rebuildFlatCache()

    -- Switch sound scheme if theme specifies one
    if theme.sound_scheme and _system_sounds then
        _system_sounds:setScheme(theme.sound_scheme)
    end

    -- Persist
    if _settings_manager then
        _settings_manager.set('theme', name)
        -- Also update sound_scheme setting to match
        if theme.sound_scheme then
            _settings_manager.set('sound_scheme', theme.sound_scheme)
        end
    end

    -- Notify listeners
    if _event_bus then
        pcall(_event_bus.publish, _event_bus, 'theme_changed', name, theme)
    end

    print("[ThemeManager] Switched to theme: " .. name)
end

function ThemeManager.get(path)
    return flat_cache[path]
end

function ThemeManager.getActiveThemeName()
    return active_theme_name
end

function ThemeManager.getActiveTheme()
    return active_theme
end

-- Get raw color table for a section (e.g. "window" returns the window subtable)
function ThemeManager.getSection(section)
    if active_theme and active_theme.colors then
        return active_theme.colors[section]
    end
    return nil
end

return ThemeManager
