-- src/utils/palette_manager.lua
-- Manages color palettes and applies palette swaps to sprites

local Object = require('class')
local json = require('json')
local Paths = require('src.paths')
local PaletteManager = Object:extend('PaletteManager')

function PaletteManager:init()
    self.palettes = {}
    self.shader = nil
    self.cached_swaps = {} -- {sprite_name..palette_id = ImageData}
    self.use_shader = true -- Set to false to pre-process instead
    
    self:loadPalettes()
    self:loadShader()
end

function PaletteManager:loadPalettes()
    local file_path = Paths.assets.data .. "sprite_palettes.json"
    local read_ok, contents = pcall(love.filesystem.read, file_path)
    
    if not read_ok or not contents then
        print("ERROR: Could not read palette definitions")
        self.palettes = {}
        return
    end
    
    local decode_ok, data = pcall(json.decode, contents)
    if not decode_ok then
        print("ERROR: Failed to decode palette JSON")
        self.palettes = {}
        return
    end
    
    self.palettes = data.palettes or {}
    print("Loaded " .. self:countPalettes() .. " color palettes")
end

function PaletteManager:countPalettes()
    local count = 0
    for _ in pairs(self.palettes) do count = count + 1 end
    return count
end

function PaletteManager:loadShader()
    local shader_path = Paths.assets.shaders .. "palette_swap.glsl"
    local success, result = pcall(love.graphics.newShader, shader_path)
    
    if success then
        self.shader = result
        print("Palette swap shader loaded successfully")
    else
        print("WARNING: Could not load palette shader, using pre-processing fallback")
        print("Error: " .. tostring(result))
        self.use_shader = false
    end
end

function PaletteManager:getPalette(palette_id)
    return self.palettes[palette_id]
end

function PaletteManager:getDefaultSourceColors()
    -- Define the source colors we want to replace in Win98 sprites
    -- These are common Win98 icon colors
    return {
        {0.0, 0.0, 0.5},   -- Dark blue (primary)
        {0.5, 0.5, 0.5},   -- Gray (secondary)
        {1.0, 1.0, 0.0},   -- Yellow (accent)
        {1.0, 1.0, 1.0}    -- White (highlight)
    }
end

function PaletteManager:applyPaletteToSprite(original_image, palette_id)
    if not original_image then return nil end
    
    local palette = self:getPalette(palette_id)
    if not palette then return original_image end
    
    -- Check cache first
    local cache_key = tostring(original_image) .. "_" .. palette_id
    if self.cached_swaps[cache_key] then
        return self.cached_swaps[cache_key]
    end
    
    -- Use shader method if available
    if self.use_shader and self.shader then
        return self:applyPaletteShader(original_image, palette)
    else
        return self:applyPaletteCPU(original_image, palette)
    end
end

function PaletteManager:applyPaletteShader(original_image, palette)
    -- This creates a render target and draws the sprite with the shader
    -- For real-time use during rendering
    return original_image -- Shader applied during draw call
end

function PaletteManager:applyPaletteCPU(original_image, palette)
    -- CPU-based pixel manipulation (slower but compatible)
    local image_data = original_image:getData()
    local width, height = image_data:getDimensions()
    
    local source_colors = self:getDefaultSourceColors()
    local target_colors = {
        palette.colors.primary,
        palette.colors.secondary,
        palette.colors.accent,
        palette.colors.highlight
    }
    
    local tolerance = 0.3 -- Color matching tolerance
    
    -- Process each pixel
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local r, g, b, a = image_data:getPixel(x, y)
            
            if a > 0.1 then -- Not transparent
                -- Check against each source color
                for i = 1, 4 do
                    local sr, sg, sb = source_colors[i][1], source_colors[i][2], source_colors[i][3]
                    local distance = math.abs(r - sr) + math.abs(g - sg) + math.abs(b - sb)
                    
                    if distance < tolerance then
                        -- Replace with target color
                        local tr, tg, tb = target_colors[i][1], target_colors[i][2], target_colors[i][3]
                        image_data:setPixel(x, y, tr, tg, tb, a)
                        break
                    end
                end
            end
        end
    end
    
    -- Create new image from modified data
    local new_image = love.graphics.newImage(image_data)
    return new_image
end

function PaletteManager:drawSpriteWithPalette(sprite_image, x, y, width, height, palette_id, tint, rotation)
    if not sprite_image then return false end

    -- Default rotation to 0 if not provided
    rotation = rotation or 0

    -- Calculate scale factors
    local scale_x = width / sprite_image:getWidth()
    local scale_y = height / sprite_image:getHeight()

    -- Origin offset in sprite-space coordinates
    -- When rotating: use center of sprite so it rotates around its center
    -- When not rotating: use (0,0) so top-left is at x,y
    local origin_x_sprite = 0
    local origin_y_sprite = 0

    if rotation ~= 0 then
        -- Use center of sprite in sprite-space coordinates
        origin_x_sprite = sprite_image:getWidth() / 2
        origin_y_sprite = sprite_image:getHeight() / 2
    end

    local palette = self:getPalette(palette_id)
    if not palette or palette_id == "default" then
        -- Draw without palette swap
        if tint then love.graphics.setColor(tint) else love.graphics.setColor(1, 1, 1) end
        love.graphics.draw(sprite_image, x, y, rotation, scale_x, scale_y, origin_x_sprite, origin_y_sprite)
        return true
    end

    -- Apply shader if available
    if self.use_shader and self.shader then
        local source_colors = self:getDefaultSourceColors()
        local target_colors = {
            palette.colors.primary,
            palette.colors.secondary,
            palette.colors.accent,
            palette.colors.highlight
        }

        self.shader:send("source_colors", unpack(source_colors))
        self.shader:send("target_colors", unpack(target_colors))
        self.shader:send("tolerance", 0.3)

        love.graphics.setShader(self.shader)
        if tint then love.graphics.setColor(tint) else love.graphics.setColor(1, 1, 1) end

        love.graphics.draw(sprite_image, x, y, rotation, scale_x, scale_y, origin_x_sprite, origin_y_sprite)

        love.graphics.setShader()
        return true
    else
        -- Use pre-processed image
        local swapped = self:applyPaletteCPU(sprite_image, palette)
        if tint then love.graphics.setColor(tint) else love.graphics.setColor(1, 1, 1) end
        local scale_x_swapped = width / swapped:getWidth()
        local scale_y_swapped = height / swapped:getHeight()
        local origin_x_swapped = rotation ~= 0 and (swapped:getWidth() / 2) or 0
        local origin_y_swapped = rotation ~= 0 and (swapped:getHeight() / 2) or 0
        love.graphics.draw(swapped, x, y, rotation, scale_x_swapped, scale_y_swapped, origin_x_swapped, origin_y_swapped)
        return true
    end
end

return PaletteManager