-- src/utils/strings.lua: Loads UI strings from assets/data/strings/ui.json with safe fallbacks

local json = require('json')
local Paths = require('src.paths')

local Strings = {}

local DEFAULTS = {
    menu = {
        open = 'Open',
        delete = 'Delete',
        restore = 'Restore',
        minimize = 'Minimize',
        maximize = 'Maximize',
        restore_size = 'Restore Size',
        close = 'Close',
        refresh = 'Refresh',
        arrange_icons = 'Arrange Icons',
        properties = 'Properties',
        create_shortcut_desktop = 'Create Shortcut (Desktop)'
    },
    start = {
        title = 'Start',
        run = 'Run...'
    },
    messages = {
        not_available = 'Not Available',
        program_not_available_fmt = '%s is not available yet.',
        cannot_find_fmt = "Cannot find '%s'."
    }
}

local data = nil

local function deep_get(tbl, path_parts)
    local cur = tbl
    for _, p in ipairs(path_parts) do
        if type(cur) ~= 'table' then return nil end
        cur = cur[p]
        if cur == nil then return nil end
    end
    return cur
end

function Strings.load()
    if data ~= nil then return true end
    local ok, contents = pcall(love.filesystem.read, Paths.assets.data .. 'strings/ui.json')
    if ok and contents then
        local ok2, parsed = pcall(json.decode, contents)
        if ok2 and parsed then data = parsed; return true end
    end
    data = {}
    return false
end

function Strings.get(path, default)
    if data == nil then Strings.load() end
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do table.insert(parts, part) end
    local val = deep_get(data, parts)
    if val ~= nil then return val end
    -- fallback to defaults
    val = deep_get(DEFAULTS, parts)
    if val ~= nil then return val end
    return default
end

return Strings
