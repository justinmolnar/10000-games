-- src/utils/sprite_loader.lua
-- Centralized sprite loading and management system

local Object = require('class')
local SpriteLoader = Object:extend('SpriteLoader')

function SpriteLoader:init()
    self.sprites = {}
    self.sprite_dir = "assets/sprites/win98/"
    self.loaded = false
end

function SpriteLoader:loadAll()
    if self.loaded then return end
    
    print("[SpriteLoader] Starting sprite load from: " .. self.sprite_dir)
    
    -- Get list of files from the sprite list
    local sprite_list_path = self.sprite_dir .. "win98.txt"
    local success, contents = pcall(love.filesystem.read, sprite_list_path)
    
    if not success or not contents then
        print("[SpriteLoader] WARNING: Could not read sprite list file: " .. sprite_list_path)
        self.loaded = true
        return
    end
    
    -- Parse sprite names from the list
    local sprite_count = 0
    for line in contents:gmatch("[^\r\n]+") do
        local sprite_name = line:match("^(.+)%.png$")
        if sprite_name and sprite_name ~= "" then
            self:loadSprite(sprite_name)
            sprite_count = sprite_count + 1
        end
    end
    
    print("[SpriteLoader] Loaded " .. sprite_count .. " sprites")
    self.loaded = true
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
    return self.sprites[sprite_name]
end

function SpriteLoader:hasSprite(sprite_name)
    if not self.loaded then
        self:loadAll()
    end
    return self.sprites[sprite_name] ~= nil
end

function SpriteLoader:drawSprite(sprite_name, x, y, width, height, tint)
    local sprite = self:getSprite(sprite_name)
    
    if not sprite then
        -- Fallback: draw white rectangle with border
        love.graphics.setColor(tint or {1, 1, 1})
        love.graphics.rectangle('fill', x, y, width, height)
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle('line', x, y, width, height)
        return false
    end
    
    -- Apply tint if provided, otherwise white
    if tint then
        love.graphics.setColor(tint)
    else
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Calculate scale to fit the sprite into the target dimensions
    local sprite_w = sprite:getWidth()
    local sprite_h = sprite:getHeight()
    local scale_x = width / sprite_w
    local scale_y = height / sprite_h
    
    -- Draw the sprite scaled to fit
    love.graphics.draw(sprite, x, y, 0, scale_x, scale_y)
    
    return true
end

-- Singleton instance
local instance = nil

local SpriteLoaderModule = {}

function SpriteLoaderModule.getInstance()
    if not instance then
        instance = SpriteLoader:new()
    end
    return instance
end

return SpriteLoaderModule