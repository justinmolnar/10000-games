-- src/views/metric_legend.lua
-- Component for showing metric → icon mappings

local Object = require('class')
local MetricLegend = Object:extend('MetricLegend')

function MetricLegend:init(di)
    self.di = di
    self.sprite_loader = (di and di.spriteLoader) or nil
    self.sprite_manager = (di and di.spriteManager) or nil
end

function MetricLegend:ensureLoaded()
    if not self.sprite_loader then
        self.sprite_loader = (self.di and self.di.spriteLoader) or error("MetricLegend: spriteLoader not available in DI")
    end

    if not self.sprite_manager then
        self.sprite_manager = (self.di and self.di.spriteManager) or error("MetricLegend: spriteManager not available in DI")
    end
end

-- Draw compact metric legend
function MetricLegend:draw(game_data, metrics_data, x, y, width, show_values)
    self:ensureLoaded()
    
    if not game_data or not game_data.metrics_tracked then
        return y
    end
    
    local icon_size = 16
    local spacing = 5
    local line_height = icon_size + spacing
    local current_y = y
    
    love.graphics.setColor(1, 1, 1)
    
    for _, metric_name in ipairs(game_data.metrics_tracked) do
        -- Draw icon
        local sprite_name = self.sprite_manager:getMetricSprite(game_data, metric_name)
        if sprite_name then
            local palette_id = self.sprite_manager:getPaletteId(game_data)
            self.sprite_loader:drawSprite(sprite_name, x, current_y, icon_size, icon_size, {1, 1, 1}, palette_id)
        end
        
        -- Draw metric name
        love.graphics.setColor(0.9, 0.9, 0.9)
        local text_x = x + icon_size + spacing
        love.graphics.print(metric_name, text_x, current_y + 2, 0, 0.85, 0.85)
        
        -- Draw value if available
        if show_values and metrics_data and metrics_data[metric_name] ~= nil then
            local value = metrics_data[metric_name]
            if type(value) == "number" then
                value = string.format("%.1f", value)
            end
            
            love.graphics.setColor(1, 1, 0)
            local value_text = ": " .. tostring(value)
            local name_width = love.graphics.getFont():getWidth(metric_name) * 0.85
            love.graphics.print(value_text, text_x + name_width, current_y + 2, 0, 0.85, 0.85)
        end
        
        current_y = current_y + line_height
    end
    
    return current_y
end

-- Draw horizontal compact version
function MetricLegend:drawCompact(game_data, metrics_data, x, y, max_width)
    self:ensureLoaded()
    
    if not game_data or not game_data.metrics_tracked then
        return
    end
    
    local icon_size = 14
    local spacing = 8
    local current_x = x
    
    for _, metric_name in ipairs(game_data.metrics_tracked) do
        -- Check if we need to wrap
        local item_width = icon_size + spacing
        if metrics_data and metrics_data[metric_name] then
            local value_text = tostring(metrics_data[metric_name])
            item_width = item_width + love.graphics.getFont():getWidth(value_text) * 0.8 + spacing
        end
        
        if max_width and current_x + item_width > x + max_width then
            break -- Stop if no room
        end
        
        -- Draw icon
        local sprite_name = self.sprite_manager:getMetricSprite(game_data, metric_name)
        if sprite_name then
            local palette_id = self.sprite_manager:getPaletteId(game_data)
            self.sprite_loader:drawSprite(sprite_name, current_x, y, icon_size, icon_size, {1, 1, 1}, palette_id)
        end
        
        current_x = current_x + icon_size + 2
        
        -- Draw value
        if metrics_data and metrics_data[metric_name] ~= nil then
            love.graphics.setColor(1, 1, 1)
            local value = metrics_data[metric_name]
            if type(value) == "number" then
                value = string.format("%.0f", value)
            end
            love.graphics.print(tostring(value), current_x, y + 1, 0, 0.8, 0.8)
            current_x = current_x + love.graphics.getFont():getWidth(tostring(value)) * 0.8
        end
        
        current_x = current_x + spacing * 2
    end
end

return MetricLegend