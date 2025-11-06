local Object = require('class')
local json = require('json')
local Paths = require('src.paths')

local GameRegistry = Object:extend('GameRegistry')

function GameRegistry:init(config)
    self.config = config or {}
    self.games = {}  -- Discovered games
    self.variant_files = {}  -- Loaded variant file data

    self:discoverGames()
end

function GameRegistry:discoverGames()
    local variants_dir = Paths.assets.data .. "variants/"
    local files = love.filesystem.getDirectoryItems(variants_dir)

    for _, filename in ipairs(files) do
        if filename:match("_variants%.json$") then
            local file_path = variants_dir .. filename
            local success, variant_data = self:loadVariantFile(file_path)

            if success and variant_data then
                self:registerGameFromVariantFile(filename, variant_data)
            end
        end
    end

    print(string.format("[GameRegistry] Discovered %d games from %d variant files",
        #self.games, self:countVariantFiles()))
end

function GameRegistry:loadVariantFile(file_path)
    local read_ok, contents = pcall(love.filesystem.read, file_path)
    if not read_ok or not contents then
        print("[GameRegistry] ERROR: Could not read " .. file_path)
        return false, nil
    end

    local decode_ok, data = pcall(json.decode, contents)
    if not decode_ok or not data then
        print("[GameRegistry] ERROR: Could not decode " .. file_path)
        return false, nil
    end

    -- Validate required fields
    if not data.game_class then
        print("[GameRegistry] ERROR: " .. file_path .. " missing 'game_class' field")
        return false, nil
    end

    if not data.variants or #data.variants == 0 then
        print("[GameRegistry] ERROR: " .. file_path .. " missing 'variants' array")
        return false, nil
    end

    return true, data
end

function GameRegistry:registerGameFromVariantFile(filename, variant_data)
    local game_class = variant_data.game_class

    -- Get technical defaults from config (if available)
    local config_defaults = {}
    if self.config and self.config.game_defaults and self.config.game_defaults[game_class] then
        config_defaults = self.config.game_defaults[game_class]
    end

    -- Store variant file data
    self.variant_files[filename] = variant_data

    -- Create game entries for each variant
    for _, variant in ipairs(variant_data.variants) do
        local game_data = self:mergeGameData(config_defaults, variant_data, variant)
        game_data._source_file = filename
        game_data._variant_index = variant.clone_index

        table.insert(self.games, game_data)
    end

    print(string.format("[GameRegistry] ✓ Registered %d variants from %s (game_class: %s)",
        #variant_data.variants, filename, game_class))
end

function GameRegistry:mergeGameData(config_defaults, file_data, variant)
    local merged = {}

    -- Priority: variant > file_data > config_defaults

    -- 1. Start with config defaults (deep copy)
    for k, v in pairs(config_defaults) do
        merged[k] = self:deepCopy(v)
    end

    -- 2. Override with file-level data (SPARSE - only what's declared)
    for k, v in pairs(file_data) do
        if k ~= "variants" then  -- Don't copy variants array
            merged[k] = self:deepCopy(v)
        end
    end

    -- 3. Override with variant-specific data (SPARSE - only what's declared)
    for k, v in pairs(variant) do
        merged[k] = self:deepCopy(v)
    end

    -- 4. Generate game ID
    merged.id = self:generateGameID(merged.game_class, variant.clone_index)

    return merged
end

function GameRegistry:generateGameID(game_class, clone_index)
    -- Map game class to base ID prefix
    local class_to_prefix = {
        DodgeGame = "dodge",
        SnakeGame = "snake",
        MemoryMatch = "memory",
        SpaceShooter = "space_shooter",
        HiddenObject = "hidden_object",
        Breakout = "breakout",
        CoinFlip = "coin_flip",
        RPS = "rps"
    }

    local prefix = class_to_prefix[game_class]
    if not prefix then
        print("[GameRegistry] WARNING: Unknown game class: " .. game_class)
        -- Fallback: convert class name to snake_case
        prefix = game_class:gsub("(%u)", function(c) return "_" .. c:lower() end):match("^_?(.*)")
    end

    -- ID format: prefix_N where N = clone_index + 1
    -- dodge_1 (clone_index 0), dodge_2 (clone_index 1), etc.
    return string.format("%s_%d", prefix, clone_index + 1)
end

function GameRegistry:deepCopy(obj)
    if type(obj) ~= 'table' then return obj end
    local copy = {}
    for k, v in pairs(obj) do
        copy[k] = self:deepCopy(v)
    end
    return copy
end

function GameRegistry:getGameByID(game_id)
    for _, game in ipairs(self.games) do
        if game.id == game_id then
            return game
        end
    end
    return nil
end

function GameRegistry:getAllGames()
    return self.games
end

function GameRegistry:getGamesByCategory(category)
    local filtered = {}
    for _, game in ipairs(self.games) do
        if game.category == category then
            table.insert(filtered, game)
        end
    end
    return filtered
end

function GameRegistry:countVariantFiles()
    local count = 0
    for _ in pairs(self.variant_files) do count = count + 1 end
    return count
end

return GameRegistry
