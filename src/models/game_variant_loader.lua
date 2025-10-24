local Object = require('class')
local json = require('json')
local Paths = require('src.paths')
local GameVariantLoader = Object:extend('GameVariantLoader')

function GameVariantLoader:init()
    self.base_game_definitions = {}
    self:loadBaseGameDefinitions()
end

function GameVariantLoader:loadBaseGameDefinitions()
    local file_path = Paths.assets.data .. "base_game_definitions.json"
    local read_ok, contents = pcall(love.filesystem.read, file_path)

    if not read_ok or not contents then
        print("ERROR: GameVariantLoader could not read " .. file_path .. " - " .. tostring(contents))
        return
    end

    local decode_ok, base_games = pcall(json.decode, contents)

    if not decode_ok then
        print("ERROR: GameVariantLoader failed to decode " .. file_path .. " - " .. tostring(base_games))
        return
    end

    -- Index base game definitions by their base ID for quick lookup
    for _, base_game in ipairs(base_games) do
        if base_game.id and base_game.clone_variants then
            self.base_game_definitions[base_game.id] = base_game
        end
    end

    print("GameVariantLoader: Loaded " .. #base_games .. " base game definitions")
end

function GameVariantLoader:getVariantData(game_id)
    if not game_id then
        return self:getDefaultVariant()
    end

    -- Parse game_id to extract base type and clone index
    -- Format: "dodge_1" (base), "dodge_2" (clone 1), "dodge_3" (clone 2), etc.
    local base_id, variant_num = game_id:match("^(.+)_(%d+)$")

    if not base_id or not variant_num then
        print("GameVariantLoader: Could not parse game_id: " .. game_id)
        return self:getDefaultVariant()
    end

    -- Reconstruct the base game ID (always ends with _1)
    local base_game_id = base_id .. "_1"
    local base_game = self.base_game_definitions[base_game_id]

    if not base_game then
        print("GameVariantLoader: No base game found for: " .. base_game_id)
        return self:getDefaultVariant()
    end

    if not base_game.clone_variants or #base_game.clone_variants == 0 then
        print("GameVariantLoader: No clone_variants defined for: " .. base_game_id)
        return self:getDefaultVariant()
    end

    -- Convert variant_num to clone_index (0-based)
    -- dodge_1 = clone_index 0, dodge_2 = clone_index 1, etc.
    local clone_index = tonumber(variant_num) - 1

    -- Find the variant with matching clone_index
    local variant = nil
    for _, v in ipairs(base_game.clone_variants) do
        if v.clone_index == clone_index then
            variant = v
            break
        end
    end

    if variant then
        return variant
    else
        -- If no exact match, cycle through available variants
        local variant_index = (clone_index % #base_game.clone_variants) + 1
        print("GameVariantLoader: No variant for clone_index " .. clone_index .. ", using cycled variant " .. variant_index)
        return base_game.clone_variants[variant_index]
    end
end

function GameVariantLoader:getDefaultVariant()
    -- Return a safe default variant structure
    return {
        clone_index = 0,
        name = "Default",
        sprite_set = "default",
        palette = "default",
        music_track = nil,
        sfx_pack = "retro_beeps",
        background = "default",
        difficulty_modifier = 1.0,
        enemies = {},
        flavor_text = "",
        intro_cutscene = nil
    }
end

return GameVariantLoader
