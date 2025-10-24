local json = require("lib.json")

local AttributionManager = {}
AttributionManager.__index = AttributionManager

function AttributionManager.new(di)
    local self = setmetatable({}, AttributionManager)
    self.di = di
    self.attributions = {}
    self.byType = {}
    self.loaded = false

    self:load()

    return self
end

function AttributionManager:load()
    local success, data = pcall(function()
        local content = love.filesystem.read("assets/data/attribution.json")
        return json.decode(content)
    end)

    if not success or not data then
        print("WARNING: Failed to load attribution.json: " .. tostring(data))
        print("Attribution system will be disabled.")
        self.attributions = {}
        return false
    end

    self.attributions = data.attributions or {}
    self:buildTypeIndex()
    self.loaded = true

    print(string.format("Loaded %d asset attributions", #self.attributions))
    return true
end

function AttributionManager:buildTypeIndex()
    self.byType = {
        sprite = {},
        music = {},
        sfx = {},
        font = {},
        code = {},
        shader = {},
        other = {}
    }

    for _, attr in ipairs(self.attributions) do
        local asset_type = attr.asset_type or "other"
        if not self.byType[asset_type] then
            self.byType[asset_type] = {}
        end
        table.insert(self.byType[asset_type], attr)
    end
end

-- Check if a specific asset path has attribution
function AttributionManager:hasAttribution(asset_path)
    if not self.loaded then return true end -- Don't warn if system failed to load

    -- Normalize path (convert backslashes to forward slashes)
    asset_path = asset_path:gsub("\\", "/")

    -- Check exact matches
    for _, attr in ipairs(self.attributions) do
        local attr_path = attr.asset_path:gsub("\\", "/")
        if attr_path == asset_path then
            return true
        end
    end

    -- Check wildcard matches
    for _, attr in ipairs(self.attributions) do
        local pattern = attr.asset_path:gsub("\\", "/")
        if pattern:find("*", 1, true) then
            -- Convert wildcard pattern to Lua pattern
            local lua_pattern = pattern:gsub("%*", ".*")
            lua_pattern = "^" .. lua_pattern .. "$"

            if asset_path:match(lua_pattern) then
                return true
            end
        end
    end

    return false
end

-- Get attribution for a specific asset
function AttributionManager:getAttribution(asset_path)
    if not self.loaded then return nil end

    asset_path = asset_path:gsub("\\", "/")

    -- Check exact matches first
    for _, attr in ipairs(self.attributions) do
        local attr_path = attr.asset_path:gsub("\\", "/")
        if attr_path == asset_path then
            return attr
        end
    end

    -- Check wildcard matches
    for _, attr in ipairs(self.attributions) do
        local pattern = attr.asset_path:gsub("\\", "/")
        if pattern:find("*", 1, true) then
            local lua_pattern = pattern:gsub("%*", ".*")
            lua_pattern = "^" .. lua_pattern .. "$"

            if asset_path:match(lua_pattern) then
                return attr
            end
        end
    end

    return nil
end

-- Get all attributions of a specific type
function AttributionManager:getByType(asset_type)
    if not self.loaded then return {} end
    return self.byType[asset_type] or {}
end

-- Get all attributions grouped by type
function AttributionManager:getAllGrouped()
    if not self.loaded then return {} end

    local grouped = {}
    for type_name, attrs in pairs(self.byType) do
        if #attrs > 0 then
            grouped[type_name] = attrs
        end
    end

    return grouped
end

-- Get all attributions as flat list
function AttributionManager:getAll()
    if not self.loaded then return {} end
    return self.attributions
end

-- Get unique authors
function AttributionManager:getAuthors()
    if not self.loaded then return {} end

    local authors = {}
    local seen = {}

    for _, attr in ipairs(self.attributions) do
        if attr.author and not seen[attr.author] then
            table.insert(authors, attr.author)
            seen[attr.author] = true
        end
    end

    table.sort(authors)
    return authors
end

-- Get attribution count
function AttributionManager:getCount()
    if not self.loaded then return 0 end
    return #self.attributions
end

-- Check if system is loaded
function AttributionManager:isLoaded()
    return self.loaded
end

-- Validate asset file (used by validation script and debug mode)
function AttributionManager:validateAsset(asset_path, warn_if_missing)
    warn_if_missing = warn_if_missing == nil and true or warn_if_missing

    if not self:hasAttribution(asset_path) then
        if warn_if_missing then
            print(string.format("WARNING: No attribution for asset: %s", asset_path))
        end
        return false
    end

    return true
end

return AttributionManager
