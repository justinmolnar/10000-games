-- src/views/cracktro_effects.lua
-- Cracktro visual effects for CheatEngine UI
local Object = require('class')
local BackgroundRenderer = require('src.utils.game_components.background_renderer')
local CracktroEffects = Object:extend('CracktroEffects')

local LOGO_TEXT = "- C H E A T  E N G I N E -"

local SCROLLER_TEXT = "GREETZ TO ALL CREWZ ... CHEATENGINE v3.1 CRACKED BY [TFG] 1999 ... "
    .. "GREETZ: RAZOR1911 * FAIRLIGHT * PARADOX * HYBRID * DEVIANCE ... "
    .. "ANOTHER FINE RELEASE FROM THE FORGOTTEN GUILD ... "
    .. "CALL OUR BBS: +1-555-WARE ... SYSOP: THE MAGICIAN ... "
    .. "REMEMBER: SHARING IS CARING ... SPREAD THE WORD ... "
    .. "    ****    "

local RASTER_COLORS = {
    {0.0, 0.8, 1.0},   -- cyan
    {1.0, 0.2, 0.8},   -- magenta
    {1.0, 0.6, 0.1},   -- orange
    {0.2, 1.0, 0.4},   -- green
}

function CracktroEffects:init()
    self.time = 0
    self.scroller_offset = 0

    self.plasma = BackgroundRenderer:new({
        type = "plasma",
        colors = {{0.0, 0.08, 0.2}, {0.0, 0.3, 0.4}, {0.08, 0.0, 0.25}},
        speed = 0.06,
        scale = 8.0,
        plasma_layers = 6,
    })

    self.starfield = BackgroundRenderer:new({
        type = "starfield",
        color = {0, 0, 0, 0},
        star_color = {0.3, 0.6, 1.0},
        star_count = 80,
        star_speed_min = 15,
        star_speed_max = 50,
        star_size_divisor = 80,
    })

    self.small_font = love.graphics.newFont(10)
    self.logo_font = love.graphics.newFont(16)
end

function CracktroEffects:update(dt)
    self.time = self.time + dt
    self.plasma:update(dt)
    self.scroller_offset = self.scroller_offset + dt * 80
end

function CracktroEffects:draw(w, h)
    -- Plasma at reduced opacity
    love.graphics.setColor(1, 1, 1, 0.25)
    self.plasma:draw(w, h)

    -- Starfield with additive blend
    local prev_mode = {love.graphics.getBlendMode()}
    love.graphics.setBlendMode('add')
    love.graphics.setColor(1, 1, 1, 0.6)
    self.starfield:draw(w, h)

    -- Raster bars
    self:drawRasterBars(w, h)

    love.graphics.setBlendMode(prev_mode[1], prev_mode[2])
end

function CracktroEffects:drawRasterBars(w, h)
    local bar_h = 8
    local sub_strips = 3
    local strip_h = bar_h / sub_strips

    for i, color in ipairs(RASTER_COLORS) do
        local freq = 0.4 + i * 0.15
        local phase = i * 1.5
        local center_y = h * 0.3 + math.sin(self.time * freq + phase) * (h * 0.35)

        for s = 0, sub_strips - 1 do
            local dist = math.abs(s - (sub_strips - 1) / 2) / ((sub_strips - 1) / 2)
            local brightness = (1.0 - dist) * 0.20
            love.graphics.setColor(color[1], color[2], color[3], brightness)
            love.graphics.rectangle('fill', 0, center_y - bar_h / 2 + s * strip_h, w, strip_h)
        end
    end
end

function CracktroEffects:drawLogo(w)
    local prev_font = love.graphics.getFont()
    love.graphics.setFont(self.logo_font)

    local y = 16

    -- Shadow/glow layers
    love.graphics.setColor(0.0, 0.2, 0.5, 0.3)
    love.graphics.printf(LOGO_TEXT, -1, y - 1, w, "center")
    love.graphics.printf(LOGO_TEXT, 1, y + 1, w, "center")

    -- Main text
    local pulse = (math.sin(self.time * 1.5) + 1) * 0.5
    love.graphics.setColor(0.0, 0.6 + pulse * 0.15, 0.9 + pulse * 0.1)
    love.graphics.printf(LOGO_TEXT, 0, y, w, "center")

    -- Subtitle
    love.graphics.setColor(0.0, 0.35, 0.6)
    love.graphics.printf("v3.1 - The Forgotten Guild", 0, y + 18, w, "center")

    love.graphics.setFont(prev_font)
end

function CracktroEffects:drawScroller(w, h)
    local prev_font = love.graphics.getFont()
    love.graphics.setFont(self.small_font)

    local char_w = self.small_font:getWidth("A")
    local text = SCROLLER_TEXT
    local text_pixel_w = #text * char_w
    local y_base = h - 18

    local offset = self.scroller_offset % text_pixel_w

    for ci = 1, #text do
        local ch = text:sub(ci, ci)
        local x = (ci - 1) * char_w - offset
        -- Wrap around
        if x < -char_w then
            x = x + text_pixel_w
        end
        if x >= -char_w and x <= w then
            local wave = math.sin(ci * 0.3 + self.time * 3) * 8
            local color_t = (math.sin(ci * 0.15 + self.time * 2) + 1) * 0.5
            local r = 0.0
            local g = 0.5 + color_t * 0.5
            local b = 0.8 + color_t * 0.2
            love.graphics.setColor(r, g, b)
            love.graphics.print(ch, x, y_base + wave)
        end
    end

    love.graphics.setFont(prev_font)
end

return CracktroEffects
