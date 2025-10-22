-- src/utils/sprite_manager.lua
-- Centralized sprite management with palette support

local Object = require('class')
local SpriteManager = Object:extend('SpriteManager')

function SpriteManager:init(sprite_loader, palette_manager)
    self.sprite_loader = sprite_loader
    self.palette_manager = palette_manager
    self.cached_sprites = {} -- {game_id = {metric_name = sprite_name}}
end

function SpriteManager:ensureLoaded()
    -- Dependencies now injected via init, no lazy loading needed
    if not self.sprite_loader or not self.palette_manager then
        error("SpriteManager: sprite_loader and palette_manager must be injected via init")
    end
end

-- Get sprite name for a specific metric of a game
function SpriteManager:getMetricSprite(game_data, metric_name)
    if not game_data then return nil end
    
    -- Check visual identity first
    if game_data.visual_identity and 
       game_data.visual_identity.metric_sprite_mappings and
       game_data.visual_identity.metric_sprite_mappings[metric_name] then
        return game_data.visual_identity.metric_sprite_mappings[metric_name]
    end
    
    -- Fallback to icon sprite
    return game_data.icon_sprite
end

-- Get sprite name for formula display
function SpriteManager:getFormulaIcon(game_data, icon_key)
    if not game_data then return nil end
    
    -- Check visual identity first
    if game_data.visual_identity and 
       game_data.visual_identity.formula_icon_mapping and
       game_data.visual_identity.formula_icon_mapping[icon_key] then
        return game_data.visual_identity.formula_icon_mapping[icon_key]
    end
    
    -- Fallback
    if icon_key == "result" then
        return "certificate-0"
    end
    
    return game_data.icon_sprite
end

-- Draw a metric sprite for a game
function SpriteManager:drawMetricSprite(game_data, metric_name, x, y, size, tint)
    self:ensureLoaded()
    
    local sprite_name = self:getMetricSprite(game_data, metric_name)
    if not sprite_name then return false end
    
    local palette_id = game_data.visual_identity and 
                       game_data.visual_identity.palette_id or "default"
    
    return self.sprite_loader:drawSprite(sprite_name, x, y, size, size, tint, palette_id)
end

-- Draw a formula icon for a game
function SpriteManager:drawFormulaIcon(game_data, icon_key, x, y, size, tint)
    self:ensureLoaded()
    
    local sprite_name = self:getFormulaIcon(game_data, icon_key)
    if not sprite_name then return false end
    
    local palette_id = game_data.visual_identity and 
                       game_data.visual_identity.palette_id or "default"
    
    return self.sprite_loader:drawSprite(sprite_name, x, y, size, size, tint, palette_id)
end

-- Get the palette ID for a game
function SpriteManager:getPaletteId(game_data)
    if game_data and game_data.visual_identity then
        return game_data.visual_identity.palette_id or "default"
    end
    return "default"
end

-- Get all metric sprites for a game (for display purposes)
function SpriteManager:getMetricSprites(game_data)
    local sprites = {}
    
    if not game_data or not game_data.metrics_tracked then
        return sprites
    end
    
    for _, metric_name in ipairs(game_data.metrics_tracked) do
        sprites[metric_name] = self:getMetricSprite(game_data, metric_name)
    end
    
    return sprites
end

return SpriteManager