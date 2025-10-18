-- ui_components.lua: Reusable UI drawing components

local UIComponents = {}

function UIComponents.drawButton(x, y, w, h, text, enabled, hovered)
    -- Background
    if not enabled then
        love.graphics.setColor(0.3, 0.3, 0.3)
    elseif hovered then
        love.graphics.setColor(0.35, 0.6, 0.35)
    else
        love.graphics.setColor(0, 0.5, 0)
    end
    love.graphics.rectangle('fill', x, y, w, h)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
    
    -- Text
    if enabled then
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
    end
    
    local font = love.graphics.getFont()
    local text_width = font:getWidth(text)
    local text_height = font:getHeight()
    love.graphics.print(text, x + (w - text_width) / 2, y + (h - text_height) / 2)
end

function UIComponents.drawTokenCounter(x, y, tokens)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Tokens: ", x, y, 0, 1.5, 1.5)
    
    local token_color = {0, 1, 0} -- Default Green
    if tokens < 100 then
        token_color = {1, 0, 0} -- Red
    elseif tokens < 500 then
        token_color = {1, 1, 0} -- Yellow
    end
    
    love.graphics.setColor(token_color)
    -- Calculate width of "Tokens: " to position the number correctly
    local font = love.graphics.getFont()
    local text_width = font:getWidth("Tokens: ") * 1.5 -- Match scale
    love.graphics.print(tokens, x + text_width, y, 0, 1.5, 1.5)
end

function UIComponents.drawWindow(x, y, w, h, title)
    -- Window background
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.rectangle('fill', x, y, w, h)
    
    -- Title bar
    love.graphics.setColor(0, 0, 0.5)
    love.graphics.rectangle('fill', x, y, w, 30)
    
    -- Title text
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(title, x + 10, y + 8, 0, 1.2, 1.2)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
end

function UIComponents.drawProgressBar(x, y, w, h, progress, bg_color, fill_color)
    bg_color = bg_color or {0.3, 0.3, 0.3}
    fill_color = fill_color or {0, 1, 0}
    
    -- Background
    love.graphics.setColor(bg_color)
    love.graphics.rectangle('fill', x, y, w, h)
    
    -- Fill
    love.graphics.setColor(fill_color)
    love.graphics.rectangle('fill', x, y, w * math.max(0, math.min(1, progress)), h)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
end

function UIComponents.drawPanel(x, y, w, h, bg_color)
    bg_color = bg_color or {0.2, 0.2, 0.2}
    
    -- Background
    love.graphics.setColor(bg_color)
    love.graphics.rectangle('fill', x, y, w, h)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)
end

function UIComponents.drawBadge(x, y, size, text, bg_color, text_color)
    bg_color = bg_color or {1, 0, 0}
    text_color = text_color or {1, 1, 1}
    
    -- Background
    love.graphics.setColor(bg_color)
    love.graphics.rectangle('fill', x, y, size, size)
    
    -- Text
    love.graphics.setColor(text_color)
    local font = love.graphics.getFont()
    local text_width = font:getWidth(text) * 0.8
    love.graphics.print(text, x + (size - text_width) / 2, y + 2, 0, 0.8, 0.8)
end

return UIComponents