-- src/views/formula_renderer.lua
-- Component for rendering formulas as icons instead of text

local Object = require('class')
local FormulaRenderer = Object:extend('FormulaRenderer')

function FormulaRenderer:init(di)
    self.di = di
    self.sprite_loader = (di and di.spriteLoader) or nil
    self.sprite_manager = (di and di.spriteManager) or nil

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
        self.sprite_loader = (self.di and self.di.spriteLoader) or error("FormulaRenderer: spriteLoader not available in DI")
    end

    if not self.sprite_manager then
        self.sprite_manager = (self.di and self.di.spriteManager) or error("FormulaRenderer: spriteManager not available in DI")
    end
end

-- Parse formula string into tokens (handles UTF-8 properly)
function FormulaRenderer:parseFormula(formula_string)
    if not formula_string then return {} end

    local tokens = {}
    local current_token = ""

    -- UTF-8 aware iteration using pattern matching
    for char in formula_string:gmatch("([%z\1-\127\194-\244][\128-\191]*)") do
        if char == "+" or char == "-" or char == "*" or char == "/" or
           char == "×" or char == "÷" or char == "(" or char == ")" or
           char == "²" or char == "³" then
            -- Save accumulated token if any
            if current_token ~= "" then
                local trimmed = current_token:match("^%s*(.-)%s*$")
                if trimmed ~= "" then  -- Only add non-empty tokens
                    table.insert(tokens, {type = "text", value = trimmed})
                end
                current_token = ""
            end
            -- Add operator/superscript as token
            table.insert(tokens, {type = (char == "²" or char == "³") and "superscript" or "operator", value = char})
        else
            current_token = current_token .. char
        end
    end

    -- Add final token
    if current_token ~= "" then
        local trimmed = current_token:match("^%s*(.-)%s*$")
        if trimmed ~= "" then  -- Only add non-empty tokens
            table.insert(tokens, {type = "text", value = trimmed})
        end
    end

    return tokens
end

-- Map token to sprite (returns sprite_name or actual sprite object)
function FormulaRenderer:getTokenSprite(token, game_data, game_instance)
    if token.type == "operator" or token.type == "superscript" then
        return nil -- Draw operators and superscripts as text
    end

    if token.type == "text" then
        local text = token.value

        -- Check for literal numbers FIRST - draw as text
        if tonumber(text) then
            return nil
        end

        -- Strip "metrics." prefix if present
        local metric_name = text:match("^metrics%.(.+)$") or text

        -- Map metric names to sprite file names
        local metric_to_sprite = {
            kills = "enemy",
            deaths = "player",
            snake_length = "segment",
            objects_dodged = "enemy",  -- Dodge: enemies dodged
            collisions = "player",     -- Dodge: player took damage (lives)
            objects_found = "object",
            matches = "card"
        }

        local sprite_key = metric_to_sprite[metric_name]

        -- If game_instance exists, use its loaded sprites
        if game_instance and game_instance.sprites and game_instance.sprites[sprite_key] then
            return {type = "game_sprite", sprite = game_instance.sprites[sprite_key]}
        end

        -- If no game_instance, load sprite from disk based on game_data
        if sprite_key and game_data and game_data.visual_identity and game_data.visual_identity.sprite_set_id then
            local sprite_set = game_data.visual_identity.sprite_set_id

            -- Map game_class to sprite folder name
            local class_to_folder = {
                DodgeGame = "dodge",
                SnakeGame = "snake",
                SpaceShooter = "space_shooter",
                MemoryMatch = "memory",
                HiddenObject = "hidden_object",
                Breakout = "breakout",
                CoinFlip = "coin_flip",
                RPS = "rps"
            }
            local game_folder = class_to_folder[game_data.game_class]

            if game_folder then
                -- Special handling for Snake: check sprite_style to determine which sprite to load
                if game_data.game_class == "SnakeGame" and metric_name == "snake_length" then
                    local sprite_style = game_data.sprite_style or "uniform"
                    if sprite_style == "segmented" then
                        sprite_key = "seg_head"  -- Use head sprite for segmented snakes
                    end
                end

                local sprite_path = string.format("assets/sprites/games/%s/%s/%s.png", game_folder, sprite_set, sprite_key)
                local success, sprite = pcall(love.graphics.newImage, sprite_path)
                if success then
                    return {type = "game_sprite", sprite = sprite}
                end
            end
        end

        -- Fallback: Use generic icon from metric sprite mapping
        if game_data then
            local icon_name = self.sprite_manager:getMetricSprite(game_data, metric_name)
            return {type = "icon", name = icon_name}
        end
    end

    return nil
end

-- Draw formula with icons
function FormulaRenderer:draw(game_data, x, y, max_width, icon_size, game_instance)
    self:ensureLoaded()

    if not game_data or not game_data.base_formula_string then
        return
    end

    icon_size = icon_size or 20
    local spacing = 5
    local current_x = x
    local current_y = y

    -- Use simplified display formula if available, otherwise fall back to base formula
    local formula_to_display = game_data.display_formula_string or game_data.base_formula_string
    local tokens = self:parseFormula(formula_to_display)

    for _, token in ipairs(tokens) do
        local sprite_info = self:getTokenSprite(token, game_data, game_instance)
        local item_width = 0

        if sprite_info then
            if sprite_info.type == "game_sprite" then
                -- Draw actual game sprite (variant-specific)
                local sprite = sprite_info.sprite
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(sprite, current_x, current_y, 0,
                    icon_size / sprite:getWidth(), icon_size / sprite:getHeight())
                item_width = icon_size
            elseif sprite_info.type == "icon" then
                -- Draw generic icon sprite
                local palette_id = self.sprite_manager:getPaletteId(game_data)
                self.sprite_loader:drawSprite(sprite_info.name, current_x, current_y, icon_size, icon_size, {1, 1, 1}, palette_id)
                item_width = icon_size
            end
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