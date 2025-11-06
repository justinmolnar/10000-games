-- src/utils/game_sprite_helper.lua
-- Phase 4: Centralized game sprite loading utility
-- Eliminates duplicate sprite loading code across views

local GameSpriteHelper = {}

-- Load player/main sprite for a game
-- @param game_data: Game data from GameRegistry (has sprite_set, default_sprite_set, game_class, etc.)
-- @param sprite_set_loader: SpriteSetLoader instance
-- @param size: Optional requested size (for scaling, not used by loader)
-- @return sprite or nil
function GameSpriteHelper.loadPlayerSprite(game_data, sprite_set_loader, size)
    if not game_data or not sprite_set_loader then
        return nil
    end

    -- Determine sprite set to use (variant-specific or default)
    local sprite_set_id = game_data.sprite_set or game_data.default_sprite_set
    local fallback_set_id = game_data.default_sprite_set

    -- Determine sprite key based on game class
    local sprite_key = GameSpriteHelper.getPlayerSpriteKey(game_data)

    -- Load with fallback support
    local sprite = sprite_set_loader:getSprite(sprite_set_id, sprite_key, fallback_set_id)

    return sprite
end

-- Determine which sprite key to use for player/main sprite based on game class
-- @param game_data: Game data with game_class and optional sprite_style
-- @return string: sprite key name
function GameSpriteHelper.getPlayerSpriteKey(game_data)
    if not game_data or not game_data.game_class then
        return "player"  -- Default fallback
    end

    -- Special case: Snake has different sprite keys based on style
    if game_data.game_class == "SnakeGame" then
        local sprite_style = game_data.sprite_style or "uniform"
        if sprite_style == "segmented" then
            return "seg_head"  -- Segmented snakes use head sprite
        else
            return "segment"   -- Uniform snakes use segment sprite
        end
    end

    -- Default for most games: player sprite
    return "player"
end

return GameSpriteHelper
