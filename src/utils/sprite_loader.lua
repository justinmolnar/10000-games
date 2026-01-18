-- src/utils/sprite_loader.lua
-- Centralized sprite loading and management system

local Object = require('class')
local SpriteLoader = Object:extend('SpriteLoader')
local Paths = require('src.paths')

function SpriteLoader:init(palette_manager)
    self.sprites = {}
    self.sprite_dir = Paths.assets.sprites .. "win98/"
    self.loaded = false
    self.aliases = nil
    self.palette_manager = palette_manager -- Injected dependency
    self._warned_missing = {} -- Track already warned missing sprites to avoid spam
end

function SpriteLoader:loadAll()
    if self.loaded then return end

    print("[SpriteLoader] Starting sprite load from: " .. self.sprite_dir)

    -- Scan directory for PNG files
    local files = love.filesystem.getDirectoryItems(self.sprite_dir)
    local sprite_count = 0

    for _, filename in ipairs(files) do
        local sprite_name = filename:match("^(.+)%.png$")
        if sprite_name and sprite_name ~= "" then
            self:loadSprite(sprite_name)
            sprite_count = sprite_count + 1
        end
    end

    -- Load aliases JSON (optional)
    self:loadAliases()

    print("[SpriteLoader] Loaded " .. sprite_count .. " sprites" .. (self.aliases and ", with aliases" or ""))
    self.loaded = true
end

function SpriteLoader:loadAliases()
    local alias_path = Paths.assets.data .. "sprite_aliases.json"
    local ok, contents = pcall(love.filesystem.read, alias_path)
    if not ok or not contents then
        return -- Optional
    end
    local ok2, data = pcall(require('json').decode, contents)
    if ok2 and data and data.aliases then
        self.aliases = data.aliases
        print("[SpriteLoader] Sprite aliases loaded: " .. tostring((function(t)local c=0 for _ in pairs(t) do c=c+1 end return c end)(self.aliases)))
    end
end

function SpriteLoader:loadSprite(sprite_name)
    if self.sprites[sprite_name] then return end
    
    local file_path = self.sprite_dir .. sprite_name .. ".png"
    local success, image = pcall(love.graphics.newImage, file_path)
    
    if success and image then
        self.sprites[sprite_name] = image
    else
        -- Don't print warning for every missing sprite, just note it failed
        self.sprites[sprite_name] = nil
    end
end

function SpriteLoader:getSprite(sprite_name)
    if not self.loaded then
        self:loadAll()
    end
    local key = sprite_name
    if self.aliases and self.aliases[key] then
        key = self.aliases[key]
    end
    return self.sprites[key]
end

function SpriteLoader:hasSprite(sprite_name)
    if not self.loaded then
        self:loadAll()
    end
    local key = sprite_name
    if self.aliases and self.aliases[key] then
        key = self.aliases[key]
    end
    return self.sprites[key] ~= nil
end

function SpriteLoader:drawSprite(sprite_name, x, y, width, height, tint, palette_id)
    local sprite = self:getSprite(sprite_name)
    
    if not sprite then
        -- One-time warn about missing sprite key to help debug white boxes
        if not self._warned_missing then self._warned_missing = {} end
        if not self._warned_missing[sprite_name] then
            print(string.format('[SpriteLoader] MISSING sprite "%s". Check %s folder.', tostring(sprite_name), self.sprite_dir))
            self._warned_missing[sprite_name] = true
        end
        -- Fallback: draw white rectangle with border
        love.graphics.setColor(tint or {1, 1, 1})
        love.graphics.rectangle('fill', x, y, width, height)
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle('line', x, y, width, height)
        return false
    end
    
    -- If palette requested, use PaletteManager
    if palette_id and palette_id ~= "default" and self.palette_manager then
        return self.palette_manager:drawSpriteWithPalette(sprite, x, y, width, height, palette_id, tint)
    end
    
    -- No palette, draw normally
    if tint then
        love.graphics.setColor(tint)
    else
        love.graphics.setColor(1, 1, 1)
    end
    
    local sprite_w = sprite:getWidth()
    local sprite_h = sprite:getHeight()
    local scale_x = width / sprite_w
    local scale_y = height / sprite_h
    
    love.graphics.draw(sprite, x, y, 0, scale_x, scale_y)
    
    return true
end

return SpriteLoader