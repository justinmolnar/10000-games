local Object = require('class')
local json = require('json')
local Paths = require('src.paths')
local GameRegistry = require('src.models.game_registry')
local GameVariantLoader = Object:extend('GameVariantLoader')

function GameVariantLoader:init()
    self.launcher_icons = {}  -- Cache for loaded launcher icons
    -- Use GameRegistry for auto-discovery (Phase 3 refactor)
    self.game_registry = GameRegistry:new()
end

-- DELETED: loadBaseGameDefinitions() - replaced by GameRegistry (Phase 3)
-- DELETED: loadStandaloneVariants() - replaced by GameRegistry (Phase 3)
-- DELETED: variant_files mapping table - replaced by auto-discovery (Phase 3)

function GameVariantLoader:getVariantData(game_id)
    if not game_id then
        return self:getDefaultVariant()
    end

    -- Use GameRegistry to get game data (Phase 3 refactor)
    local game_data = self.game_registry:getGameByID(game_id)

    if game_data then
        -- Return the variant data (already merged by GameRegistry)
        return game_data
    else
        print("GameVariantLoader: No game found for ID: " .. tostring(game_id))
        return self:getDefaultVariant()
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

-- Phase 2.4: Launcher Icon Loading
function GameVariantLoader:getLauncherIcon(game_id, game_class)
    -- Return cached icon if already loaded
    if self.launcher_icons[game_id] then
        return self.launcher_icons[game_id]
    end

    -- Try to load launcher icon for this variant
    local variant = self:getVariantData(game_id)
    if not variant or not variant.sprite_set or not game_class then
        return nil  -- No icon loaded, will fall back to icon_sprite
    end

    -- Determine game_type from game_class
    local game_type = self:getGameTypeFromClass(game_class)
    if not game_type then
        return nil
    end

    -- Construct path: assets/sprites/games/{game_type}/{sprite_set}/launcher_icon.png
    local icon_path = string.format("assets/sprites/games/%s/%s/launcher_icon.png", game_type, variant.sprite_set)

    -- Try to load the icon
    local success, image = pcall(function()
        return love.graphics.newImage(icon_path)
    end)

    if success and image then
        self.launcher_icons[game_id] = image
        return image
    else
        -- Cache nil to avoid repeated load attempts
        self.launcher_icons[game_id] = false
        return nil
    end
end

function GameVariantLoader:getGameTypeFromClass(game_class)
    -- Use sprite_folder from variant data instead of hardcoded mapping (Phase 3)
    -- Fallback: convert CamelCase to snake_case
    if not game_class then return nil end

    -- Try to get sprite_folder from GameRegistry
    local all_games = self.game_registry:getAllGames()
    for _, game in ipairs(all_games) do
        if game.game_class == game_class and game.sprite_folder then
            return game.sprite_folder
        end
    end

    -- Fallback: Auto-convert CamelCase to snake_case
    local folder = game_class:gsub("(%u)", function(c) return "_" .. c:lower() end):match("^_?(.*)")
    return folder
end

return GameVariantLoader
