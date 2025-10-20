-- src/views/formula_renderer.lua
-- Component for rendering formulas as icons instead of text

local Object = require('class')
local FormulaRenderer = Object:extend('FormulaRenderer')

function FormulaRenderer:init()
    self.sprite_loader = nil
    self.sprite_manager = nil
    
    -- Operator sprite mappings (using Win98 icons)
    self.operator_sprites = {
        ["+"] = "nil", -- Draw as text
        ["-"] = "nil",
        ["×"] = "nil",
        ["*"] = "nil",
        ["÷"] = "nil",
        ["/"] = "nil",
        ["("] = "nil",
        [")"] = "nil"
    }
    
    -- Token/result sprite
    self.result_sprite = "check-0"
end

function FormulaRenderer:ensureLoaded()
    if not self.sprite_loader then
        local SpriteLoader = require('src.utils.sprite_loader')
        self.sprite_loader = SpriteLoader.getInstance()
    end
    
    if not self.sprite_manager then
        local SpriteManager = require('src.utils.sprite_manager')
        self.sprite_manager = SpriteManager.getInstance()
    end
end

-- Parse formula string into tokens
function FormulaRenderer:parseFormula(formula_string)
    if not formula_string then return {} end
    
    local tokens = {}
    local current_token = ""
    
    -- Simple tokenizer - splits on operators and parentheses
    for i = 1, #formula_string do
        local char = formula_string:sub(i, i)
        
        if char == "+" or char == "-" or char == "*" or char == "/" or 
           char == "×" or char == "÷" or char == "(" or char == ")" then
            -- Save accumulated token if any
            if current_token ~= "" then
                table.insert(tokens, {type = "text", value = current_token:match("^%s*(.-)%s*$")})
                current_token = ""
            end
            -- Add operator
            table.insert(tokens, {type = "operator", value = char})
        else
            current_token = current_token .. char
        end
    end
    
    -- Add final token
    if current_token ~= "" then
        table.insert(tokens, {type = "text", value = current_token:match("^%s*(.-)%s*$")})
    end
    
    return tokens
end

-- Map token to sprite (returns sprite_name or nil for text-only)
function FormulaRenderer:getTokenSprite(token, game_data)
    if token.type == "operator" then
        return nil -- Draw operators as text
    end
    
    if token.type == "text" then
        local text = token.value
        
        -- Check if it's "metrics.something"
        local metric_name = text:match("^metrics%.(.+)$")
        if metric_name and game_data then
            return self.sprite_manager:getMetricSprite(game_data, metric_name)
        end
        
        -- Check for literal numbers
        if tonumber(text) then
            return nil -- Draw numbers as text
        end
    end
    
    return nil
end

-- Draw formula with icons
function FormulaRenderer:draw(game_data, x, y, max_width, icon_size)
    self:ensureLoaded()
    
    if not game_data or not game_data.base_formula_string then
        return
    end
    
    icon_size = icon_size or 20
    local spacing = 5
    local current_x = x
    local current_y = y
    
    local tokens = self:parseFormula(game_data.base_formula_string)
    
    for _, token in ipairs(tokens) do
        local sprite_name = self:getTokenSprite(token, game_data)
        local item_width = 0
        
        if sprite_name then
            -- Draw as sprite
            local palette_id = self.sprite_manager:getPaletteId(game_data)
            self.sprite_loader:drawSprite(sprite_name, current_x, current_y, icon_size, icon_size, {1, 1, 1}, palette_id)
            item_width = icon_size
        else
            -- Draw as text
            love.graphics.setColor(1, 1, 1)
            local text = token.value
            
            -- Simplify displayed text for metrics
            if text:match("^metrics%.") then
                text = text:gsub("^metrics%.", "")
            end
            
            -- Avoid drawing outside max width in single-line mode
            if max_width and (current_x + (love.graphics.getFont():getWidth(text) * 0.9) > x + max_width) then
                -- Wrap
                current_x = x
                current_y = current_y + icon_size + spacing
            end
            love.graphics.print(text, current_x, current_y + (icon_size / 4), 0, 0.9, 0.9)
            local fw = love.graphics.getFont() and love.graphics.getFont():getWidth(text) or 0
            item_width = fw * 0.9
        end
        
        current_x = current_x + item_width + spacing
        
        -- Wrap if needed
        if max_width and current_x > x + max_width then
            current_x = x
            current_y = current_y + icon_size + spacing
        end
    end
    
    -- Draw equals and result icon
    current_x = current_x + spacing
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("=", current_x, current_y + (icon_size / 4), 0, 0.9, 0.9)
    current_x = current_x + love.graphics.getFont():getWidth("=") * 0.9 + spacing
    
    -- Result icon
    local result_sprite = self.sprite_manager:getFormulaIcon(game_data, "result")
    if result_sprite then
        self.sprite_loader:drawSprite(result_sprite, current_x, current_y, icon_size, icon_size, {1, 1, 0})
    end
    
    return current_y + icon_size -- Return final height
end

-- Calculate layout dimensions without drawing
function FormulaRenderer:calculateSize(game_data, max_width, icon_size)
    if not game_data or not game_data.base_formula_string then
        return 0, 0
    end
    
    icon_size = icon_size or 20
    local spacing = 5
    local current_x = 0
    local current_y = 0
    local max_x = 0
    
    local tokens = self:parseFormula(game_data.base_formula_string)
    
    for _, token in ipairs(tokens) do
        local sprite_name = self:getTokenSprite(token, game_data)
        local item_width = 0
        
        if sprite_name then
            item_width = icon_size
        else
            local text = token.value
            if text:match("^metrics%.") then
                text = text:gsub("^metrics%.", "")
            end
            item_width = love.graphics.getFont():getWidth(text) * 0.9
        end
        
        current_x = current_x + item_width + spacing
        
        if max_width and current_x > max_width then
            current_x = item_width + spacing
            current_y = current_y + icon_size + spacing
        end
        
        max_x = math.max(max_x, current_x)
    end
    
    return max_x, current_y + icon_size
end

return FormulaRenderer