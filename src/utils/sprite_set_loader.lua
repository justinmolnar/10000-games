local Object = require('class')
local json = require('json')
local Paths = require('src.paths')

local SpriteSetLoader = Object:extend('SpriteSetLoader')

function SpriteSetLoader:init()
    self.sprite_sets = {}
    self.loaded_sprites = {}  -- Cache
    self:loadSpriteSets()
end

function SpriteSetLoader:loadSpriteSets()
    local file_path = Paths.assets.data .. "sprite_sets.json"
    local read_ok, contents = pcall(love.filesystem.read, file_path)

    if not read_ok or not contents then
        print("[SpriteSetLoader] ERROR: Could not read sprite_sets.json")
        return
    end

    local decode_ok, data = pcall(json.decode, contents)
    if not decode_ok or not data or not data.sprite_sets then
        print("[SpriteSetLoader] ERROR: Could not decode sprite_sets.json")
        return
    end

    -- Index by ID
    for _, sprite_set in ipairs(data.sprite_sets) do
        if sprite_set.id then
            self.sprite_sets[sprite_set.id] = sprite_set
        end
    end

    print(string.format("[SpriteSetLoader] Loaded %d sprite sets", #data.sprite_sets))
end

function SpriteSetLoader:getSprite(sprite_set_id, sprite_key, fallback_set_id)
    -- Create cache key
    local cache_key = sprite_set_id .. ":" .. sprite_key

    -- Return cached if available
    if self.loaded_sprites[cache_key] then
        return self.loaded_sprites[cache_key]
    end

    -- Try loading from sprite set
    local sprite_set = self.sprite_sets[sprite_set_id]
    if sprite_set and sprite_set.sprites[sprite_key] then
        local sprite = self:loadSpriteFromPath(sprite_set.sprites[sprite_key])
        if sprite then
            self.loaded_sprites[cache_key] = sprite
            return sprite
        end
    end

    -- Try fallback sprite set
    if fallback_set_id and fallback_set_id ~= sprite_set_id then
        local fallback_set = self.sprite_sets[fallback_set_id]
        if fallback_set and fallback_set.sprites[sprite_key] then
            local sprite = self:loadSpriteFromPath(fallback_set.sprites[sprite_key])
            if sprite then
                -- Cache under original key
                self.loaded_sprites[cache_key] = sprite
                print(string.format("[SpriteSetLoader] Sprite '%s' not found in '%s', using fallback from '%s'",
                    sprite_key, sprite_set_id, fallback_set_id))
                return sprite
            end
        end
    end

    print(string.format("[SpriteSetLoader] ERROR: Could not load sprite '%s' from set '%s'", sprite_key, sprite_set_id))
    return self:getErrorSprite()
end

function SpriteSetLoader:loadSpriteFromPath(path)
    local success, sprite = pcall(love.graphics.newImage, path)
    if success then
        return sprite
    else
        print("[SpriteSetLoader] ERROR: Could not load sprite from " .. path)
        return nil
    end
end

function SpriteSetLoader:getErrorSprite()
    -- Return a placeholder 1x1 magenta sprite
    if not self.error_sprite then
        local image_data = love.image.newImageData(1, 1)
        image_data:setPixel(0, 0, 1, 0, 1, 1)  -- Magenta
        self.error_sprite = love.graphics.newImage(image_data)
    end
    return self.error_sprite
end

return SpriteSetLoader
