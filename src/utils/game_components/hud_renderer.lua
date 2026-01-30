--[[
HUDRenderer - Standardized HUD rendering component
Enforces consistent layout across all games:
  - Top-Left: Primary metric (score/progress)
  - Top-Right: Lives/Health
  - Top-Center: Timer (optional)
  - Bottom: Progress bar (optional)

Handles VM mode: Full HUD hidden, metrics exposed via game.metrics table

Usage:
    self.hud = HUDRenderer:new({
        primary = {label = "Score", key = "score"},
        secondary = {label = "Dodged", key = "metrics.objects_dodged"},  -- optional
        lives = {key = "lives", max = 10, style = "hearts"},  -- or "number"
        timer = {key = "time_elapsed", mode = "elapsed"},  -- optional
        progress = {label = "Wave", current_key = "wave", total_key = "max_waves"}  -- optional
    })

    -- In view draw():
    self.game.hud:draw(viewport_width, viewport_height)
]]

local Object = require('class')
local HUDRenderer = Object:extend('HUDRenderer')

-- Standard positions
local POSITIONS = {
    primary = {x = 10, y = 10},
    secondary = {x = 10, y = 30},
    lives = {x = nil, y = 10},  -- x calculated from right edge
    timer = {x = nil, y = 10},  -- x calculated from center
    progress = {x = nil, y = nil}  -- calculated from center/bottom
}

function HUDRenderer:new(config)
    local instance = HUDRenderer.super.new(self)

    -- Store configuration
    instance.primary = config.primary  -- Required: {label, key, format}
    instance.secondary = config.secondary  -- Optional: {label, key, format}
    instance.lives = config.lives  -- Optional: {key, max, style = "hearts" or "number"}
    instance.timer = config.timer  -- Optional: {key, mode = "elapsed" or "countdown"}
    instance.progress = config.progress  -- Optional: {label, current_key, total_key, show_bar}

    -- Styling
    instance.font_size = config.font_size or 16
    instance.text_color = config.text_color or {1, 1, 1}
    instance.label_color = config.label_color or {0.8, 0.8, 0.8}
    instance.primary_color = config.primary_color or {1, 1, 0}  -- Yellow for primary metric

    return instance
end

-- Main draw function
function HUDRenderer:draw(viewport_width, viewport_height)
    -- Get game reference (passed implicitly via self.game)
    local game = self.game
    if not game then
        error("HUDRenderer:draw() requires self.game to be set. Call hud.game = self in game init.")
    end

    -- Skip HUD entirely in VM render mode
    if game.vm_render_mode then
        return
    end

    -- Draw primary metric (top-left)
    if self.primary then
        self:drawPrimary(viewport_width, viewport_height)
    end

    -- Draw secondary metric (top-left, below primary)
    if self.secondary then
        self:drawSecondary(viewport_width, viewport_height)
    end

    -- Draw lives/health (top-right)
    if self.lives then
        self:drawLives(viewport_width, viewport_height)
    end

    -- Draw timer (top-center)
    if self.timer then
        self:drawTimer(viewport_width, viewport_height)
    end

    -- Draw progress (bottom-center or custom position)
    if self.progress then
        self:drawProgress(viewport_width, viewport_height)
    end
end

-- Draw primary metric (top-left, prominent)
function HUDRenderer:drawPrimary(viewport_width, viewport_height)
    local value = self:getValue(self.primary.key)
    local label = self.primary.label or ""
    local format = self.primary.format or "number"
    local x, y = POSITIONS.primary.x, POSITIONS.primary.y

    -- Draw label
    love.graphics.setColor(self.label_color)
    love.graphics.print(label .. ": ", x, y)

    -- Draw value (prominent color)
    local value_x = x + love.graphics.getFont():getWidth(label .. ": ")
    love.graphics.setColor(self.primary_color)
    love.graphics.print(self:formatValue(value, format), value_x, y)
end

-- Draw secondary metric (top-left, below primary)
function HUDRenderer:drawSecondary(viewport_width, viewport_height)
    local value = self:getValue(self.secondary.key)
    local label = self.secondary.label or ""
    local format = self.secondary.format or "number"
    local x, y = POSITIONS.secondary.x, POSITIONS.secondary.y

    -- Draw label
    love.graphics.setColor(self.label_color)
    love.graphics.print(label .. ": ", x, y)

    -- Draw value
    local value_x = x + love.graphics.getFont():getWidth(label .. ": ")
    love.graphics.setColor(self.text_color)
    love.graphics.print(self:formatValue(value, format), value_x, y)
end

-- Draw lives/health (top-right)
function HUDRenderer:drawLives(viewport_width, viewport_height)
    local current = self:getValue(self.lives.key) or 0
    local max = self.lives.max or 10
    local style = self.lives.style or "number"
    local label = self.lives.label or "Lives"
    local y = POSITIONS.lives.y

    if style == "hearts" then
        -- Calculate x from right edge
        local heart_spacing = 20
        local hearts_width = max * heart_spacing
        local label_width = love.graphics.getFont():getWidth(label .. ": ")
        local total_width = label_width + hearts_width
        local x = viewport_width - total_width - 10

        -- Draw label
        love.graphics.setColor(self.label_color)
        love.graphics.print(label .. ": ", x, y)

        -- Draw hearts
        local heart_x = x + label_width
        for i = 1, max do
            if i <= current then
                love.graphics.setColor(1, 0, 0)
                love.graphics.print("♥", heart_x + (i-1) * heart_spacing, y)
            else
                love.graphics.setColor(0.3, 0.3, 0.3)
                love.graphics.print("♡", heart_x + (i-1) * heart_spacing, y)
            end
        end
    else
        -- Number style
        local text = label .. ": " .. tostring(math.floor(current))
        local text_width = love.graphics.getFont():getWidth(text)
        local x = viewport_width - text_width - 10

        love.graphics.setColor(self.text_color)
        love.graphics.print(text, x, y)
    end
end

-- Draw timer (top-center)
function HUDRenderer:drawTimer(viewport_width, viewport_height)
    local value = self:getValue(self.timer.key) or 0
    local mode = self.timer.mode or "elapsed"
    local label = self.timer.label or "Time"
    local y = POSITIONS.timer.y

    -- Format time
    local minutes = math.floor(value / 60)
    local seconds = math.floor(value % 60)
    local time_str = string.format("%02d:%02d", minutes, seconds)
    local text = label .. ": " .. time_str

    -- Calculate center position
    local text_width = love.graphics.getFont():getWidth(text)
    local x = (viewport_width / 2) - (text_width / 2)

    love.graphics.setColor(self.text_color)
    love.graphics.print(text, x, y)
end

-- Draw progress (bottom-center or custom position)
function HUDRenderer:drawProgress(viewport_width, viewport_height)
    local current = self:getValue(self.progress.current_key) or 0
    local total = self:getValue(self.progress.total_key) or 0
    local label = self.progress.label or "Progress"
    local show_bar = self.progress.show_bar ~= false  -- default true

    -- Position at bottom-center
    local y = viewport_height - 40

    -- Text: "Label: X/Y"
    local text = label .. ": " .. current .. "/" .. total
    local text_width = love.graphics.getFont():getWidth(text)
    local text_x = (viewport_width / 2) - (text_width / 2)

    love.graphics.setColor(self.text_color)
    love.graphics.print(text, text_x, y)

    -- Progress bar below text
    if show_bar and total > 0 then
        local bar_width = self.progress.bar_width or 200
        local bar_height = self.progress.bar_height or 10
        local bar_x = (viewport_width / 2) - (bar_width / 2)
        local bar_y = y + 20

        -- Background
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", bar_x, bar_y, bar_width, bar_height)

        -- Fill
        local fill = (current / total) * bar_width
        love.graphics.setColor(self.progress.bar_color or {0, 1, 0})
        love.graphics.rectangle("fill", bar_x, bar_y, fill, bar_height)

        -- Border
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", bar_x, bar_y, bar_width, bar_height)
    end
end

-- Helper: Get value from game state using key path (supports nested keys like "metrics.score")
function HUDRenderer:getValue(key)
    if not key or not self.game then return nil end

    -- Handle nested keys (e.g., "metrics.score")
    local keys = {}
    for k in string.gmatch(key, "[^%.]+") do
        table.insert(keys, k)
    end

    local value = self.game
    for _, k in ipairs(keys) do
        if type(value) == "table" then
            value = value[k]
        else
            return nil
        end
    end

    return value
end

-- Calculate total HUD height based on configured elements
-- Returns the vertical space consumed by HUD elements at the top
function HUDRenderer:getHeight()
    local height = 0
    local row_height = 20  -- Standard row height

    -- Primary metric row
    if self.primary then
        height = height + row_height
    end

    -- Secondary metric row
    if self.secondary then
        height = height + row_height
    end

    -- Timer takes same row as primary/lives, so no extra height

    -- Add top margin and bottom padding
    height = height + 20  -- Top margin (10) + bottom padding (10)

    return height
end

-- Helper: Format value based on format type
function HUDRenderer:formatValue(value, format)
    if value == nil then return "N/A" end

    if format == "number" then
        return tostring(math.floor(value))
    elseif format == "float" then
        return string.format("%.2f", value)
    elseif format == "percent" then
        return string.format("%d%%", math.floor(value * 100))
    elseif format == "time" then
        local minutes = math.floor(value / 60)
        local seconds = math.floor(value % 60)
        return string.format("%02d:%02d", minutes, seconds)
    elseif format == "ratio" then
        -- For "X/Y" format (e.g., "15/20")
        return tostring(value)  -- Assumes value is already formatted
    else
        return tostring(value)
    end
end

return HUDRenderer
