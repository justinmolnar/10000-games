--[[
    GameBaseView - Base class for minigame views

    Provides common functionality:
    - DI container access (sprite_loader, sprite_manager, palette_manager)
    - Lazy loading of sprite systems via ensureLoaded()
    - Palette and tint helpers
    - draw() orchestration

    Game views extend this and override drawContent() for game-specific rendering.
]]

local Object = require('class')
local BackgroundRenderer = require('src.utils.game_components.background_renderer')
local GameBaseView = Object:extend('GameBaseView')

function GameBaseView:init(game_state, variant, config)
    self.game = game_state
    self.variant = variant
    self.config = config or {}

    -- DI container access
    self.di = game_state and game_state.di

    -- Lazy-loaded sprite systems (populated by ensureLoaded)
    self.sprite_loader = nil
    self.sprite_manager = nil
    self.palette_manager = nil
end

function GameBaseView:ensureLoaded()
    if not self.sprite_loader then
        self.sprite_loader = (self.di and self.di.spriteLoader) or error(tostring(self) .. ": spriteLoader not available in DI")
    end

    if not self.sprite_manager then
        self.sprite_manager = (self.di and self.di.spriteManager) or error(tostring(self) .. ": spriteManager not available in DI")
    end

    if not self.palette_manager then
        self.palette_manager = self.di and self.di.paletteManager
    end
end

function GameBaseView:getPaletteId()
    return (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(self.game.data)
end

function GameBaseView:getTint(game_type, game_config)
    if not self.palette_manager or not game_config then
        return {1, 1, 1}
    end
    return self.palette_manager:getTintForVariant(self.variant, game_type, game_config)
end

function GameBaseView:update(dt)
    if self.background and self.background.update then
        self.background:update(dt)
    end
end

function GameBaseView:draw()
    self:ensureLoaded()
    self:drawContent()
    self:drawWater()
    self:drawPopups()
    self:drawOverlay()
end

function GameBaseView:drawContent()
    -- Override in subclasses
end

function GameBaseView:drawWater()
    local game = self.game
    if not game or not game.entity_controller then return end

    local waters = game.entity_controller:getEntitiesByCategory("water")
    if #waters == 0 then return end

    -- Lazy-load water sprite
    if not self._water_sprite then
        local ok, img = pcall(love.graphics.newImage, "assets/sprites/shared/y2k_bunker/water_jug.png")
        self._water_sprite = ok and img or false
    end

    local t = love.timer.getTime()
    for _, entity in ipairs(waters) do
        local pulse = 1 + 0.1 * math.sin(t * 3)
        local alpha = 1
        if entity.water_lifetime then
            alpha = 1 - (entity.age or 0) / entity.water_lifetime
            alpha = math.max(0, math.min(1, alpha))
        end

        if self._water_sprite then
            local sprite = self._water_sprite
            local sw, sh = sprite:getWidth(), sprite:getHeight()
            local scale = pulse * (self._water_draw_size or 24) / math.max(sw, sh)
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.draw(sprite, entity.x, entity.y, 0, scale, scale, sw / 2, sh / 2)
        else
            love.graphics.setColor(0.3, 0.7, 1.0, alpha)
            love.graphics.circle('fill', entity.x, entity.y, 8 * pulse)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function GameBaseView:drawPopups()
    local game = self.game
    if game and game.popup_manager then
        game.popup_manager:draw()
    end
end

function GameBaseView:drawOverlay()
    local game = self.game
    if not game then return end

    local w = game.game_width or game.viewport_width or game.arena_width or love.graphics.getWidth()
    local h = game.game_height or game.viewport_height or game.arena_height or love.graphics.getHeight()

    if game.victory then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, w, h)

        love.graphics.setColor(0, 1, 0)
        love.graphics.printf("VICTORY!", 0, h / 2 - 40, w, 'center', 0, 3, 3)

        love.graphics.setColor(1, 1, 1)
        local subtitle = self:getVictorySubtitle()
        if subtitle then
            love.graphics.printf(subtitle, 0, h / 2 + 20, w, 'center', 0, 1.5, 1.5)
        end
    elseif game.game_over then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, w, h)

        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("GAME OVER", 0, h / 2 - 40, w, 'center', 0, 3, 3)

        love.graphics.setColor(1, 1, 1)
        local subtitle = self:getGameOverSubtitle()
        if subtitle then
            love.graphics.printf(subtitle, 0, h / 2 + 20, w, 'center', 0, 1.5, 1.5)
        end
    end
end

function GameBaseView:getVictorySubtitle()
    -- Override in subclasses for custom victory message
    -- Default: show final score if available
    if self.game.score then
        return "Final Score: " .. math.floor(self.game.score)
    end
    return nil
end

function GameBaseView:getGameOverSubtitle()
    -- Override in subclasses for custom game over message
    -- Default: show final score if available
    if self.game.score then
        return "Final Score: " .. math.floor(self.game.score)
    end
    return nil
end

--------------------------------------------------------------------------------
-- BACKGROUND RENDERING
--------------------------------------------------------------------------------

-- Create a BackgroundRenderer from variant.background string + game params.
-- Call from subclass init when you want the variant's background field to drive rendering.
-- Then use self.background:draw(w, h) instead of the manual drawBackground* methods.
function GameBaseView:initBackground(variant, params)
    local bg_type = (variant and variant.background) or "solid"
    local config = { type = bg_type }

    if params then
        config.color       = params.bg_color
        config.star_color  = params.bg_star_color
        config.star_count  = params.bg_star_count
        config.colors      = params.bg_colors
        config.speed       = params.bg_speed
        config.scale       = params.bg_scale
        config.warp        = params.bg_warp
        config.contrast    = params.bg_contrast
        config.point_strength = params.bg_point_strength
        config.point_radius  = params.bg_point_radius
        config.point_tail    = params.bg_point_tail
        config.ink_dye_dissipation = params.bg_ink_dye_dissipation
        config.ink_vel_dissipation = params.bg_ink_vel_dissipation
        config.ink_diffusion       = params.bg_ink_diffusion
        config.ink_amount          = params.bg_ink_amount
        config.ink_radius          = params.bg_ink_radius
        config.ink_vel_strength    = params.bg_ink_vel_strength
        config.ink_sim_steps       = params.bg_ink_sim_steps
        config.ink_displace        = params.bg_ink_displace
        config.ink_dye_color       = params.bg_ink_dye_color
        config.plasma_layers       = params.bg_plasma_layers
        config.image_path          = params.bg_image
    end

    self.background = BackgroundRenderer:new(config)
end

function GameBaseView:drawBackground(width, height)
    local game = self.game
    width = width or game.game_width or game.arena_width or love.graphics.getWidth()
    height = height or game.game_height or game.arena_height or love.graphics.getHeight()

    -- Sprite background if available, else solid color
    if game and game.sprites and game.sprites.background then
        self:drawBackgroundSprite(width, height)
    else
        self:drawBackgroundSolid(width, height)
    end
end

function GameBaseView:drawBackgroundSprite(width, height)
    local game = self.game
    local bg = game.sprites.background
    local bg_width = bg:getWidth()
    local bg_height = bg:getHeight()

    local palette_id = self:getPaletteId()
    local scale_x = width / bg_width
    local scale_y = height / bg_height

    if self.palette_manager and palette_id then
        self.palette_manager:drawSpriteWithPalette(bg, 0, 0, width, height, palette_id, {1, 1, 1})
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(bg, 0, 0, 0, scale_x, scale_y)
    end
end

function GameBaseView:drawBackgroundTiled(width, height)
    local game = self.game
    local bg = game.sprites.background
    local bg_width = bg:getWidth()
    local bg_height = bg:getHeight()

    local palette_id = self:getPaletteId()

    for y = 0, math.ceil(height / bg_height) do
        for x = 0, math.ceil(width / bg_width) do
            if self.palette_manager and palette_id then
                self.palette_manager:drawSpriteWithPalette(
                    bg, x * bg_width, y * bg_height, bg_width, bg_height, palette_id, {1, 1, 1}
                )
            else
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(bg, x * bg_width, y * bg_height)
            end
        end
    end
end

function GameBaseView:drawBackgroundSolid(width, height)
    if self.bg_color then
        love.graphics.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3])
    else
        love.graphics.setColor(0.1, 0.1, 0.15)
    end
    love.graphics.rectangle('fill', 0, 0, width, height)
end

function GameBaseView:drawBackgroundStarfield(width, height)
    local t = love.timer.getTime()
    love.graphics.setColor(1, 1, 1)
    for _, star in ipairs(self.stars) do
        local y = (star.y + (star.speed * t) / height) % 1
        local px = star.x * width
        local py = y * height
        local size = math.max(1, star.speed / (self.star_size_divisor or 60))
        love.graphics.rectangle('fill', px, py, size, size)
    end
end

function GameBaseView:drawBackgroundProcedural(width, height)
    local game = self.game

    -- Draw base color first
    self:drawBackgroundSolid(width, height)

    -- Draw grid pattern
    local complexity = (game.difficulty_modifiers and game.difficulty_modifiers.complexity) or 1
    local grid_base = (game.params and game.params.background_grid_base) or 10
    local hash_1 = (game.params and game.params.background_hash_1) or 7
    local hash_2 = (game.params and game.params.background_hash_2) or 3

    local grid_density = math.floor(grid_base * complexity)
    local cell_w = width / grid_density
    local cell_h = height / grid_density
    local complexity_mod = math.max(1, hash_2 + complexity)

    local alt_color = self.config.procedural_alt_color or {0.25, 0.22, 0.18}
    love.graphics.setColor(alt_color[1], alt_color[2], alt_color[3])

    for i = 0, grid_density do
        for j = 0, grid_density do
            if ((i + j) * hash_1) % complexity_mod == 0 then
                love.graphics.rectangle('fill', i * cell_w, j * cell_h, cell_w, cell_h)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- DRAWING HELPERS
--------------------------------------------------------------------------------

local INDEXED_COLORS = {
    {0, 1, 1},
    {1, 1, 0},
    {1, 0, 1},
    {0, 1, 0},
    {1, 0.5, 0},
    {0.5, 0.5, 1},
    {1, 0.5, 1},
    {0.5, 1, 0.5},
}

function GameBaseView:getIndexedColor(index)
    return INDEXED_COLORS[((index - 1) % #INDEXED_COLORS) + 1]
end

-- Health-based color: green (healthy) → yellow (damaged) → red (critical)
function GameBaseView:getHealthColor(health_percent)
    if health_percent > 0.66 then
        return {0.3, 0.8, 0.3}
    elseif health_percent > 0.33 then
        return {0.9, 0.9, 0.3}
    else
        return {0.9, 0.3, 0.3}
    end
end

-- Draw pulsing shield indicator circle
function GameBaseView:drawShieldIndicator(x, y, radius)
    local alpha = 0.3 + 0.2 * math.sin(love.timer.getTime() * 5)
    love.graphics.setColor(0.3, 0.7, 1.0, alpha)
    love.graphics.setLineWidth(3)
    love.graphics.circle('line', x, y, radius)
    love.graphics.setLineWidth(1)
end

-- Draw fading trail of circles (for balls, projectiles, etc)
function GameBaseView:drawTrail(trail, base_radius, color)
    if not trail or #trail < 2 then return end
    color = color or {1, 1, 1}
    for i = 2, #trail do
        local alpha = 1 - (i / #trail)
        local radius = base_radius * (1 - i / #trail * 0.5)
        love.graphics.setColor(color[1], color[2], color[3], alpha * 0.6)
        love.graphics.circle('fill', trail[i].x, trail[i].y, radius)
    end
end

--------------------------------------------------------------------------------
-- FOG OF WAR
--------------------------------------------------------------------------------

function GameBaseView:renderFog(width, height, sources, radius)
    local fog = self.game.fog_controller
    if not fog or not sources or #sources == 0 then return end
    fog:clearSources()
    for _, src in ipairs(sources) do
        fog:addVisibilitySource(src.x, src.y, radius)
    end
    fog:render(width, height)
end

--------------------------------------------------------------------------------
-- ENTITY DRAWING HELPERS
--------------------------------------------------------------------------------

function GameBaseView:drawEntityAt(x, y, w, h, sprite_key, fallback_icon, options)
    options = options or {}
    local game = self.game
    local sprite = game.sprites and game.sprites[sprite_key]
    local tint = options.tint or {1, 1, 1}
    local rotation = options.rotation or 0
    local palette_id = self:getPaletteId()

    if sprite then
        if self.palette_manager then
            if rotation ~= 0 then
                love.graphics.push()
                love.graphics.translate(x + w/2, y + h/2)
                love.graphics.rotate(rotation)
                self.palette_manager:drawSpriteWithPalette(sprite, -w/2, -h/2, w, h, palette_id, tint)
                love.graphics.pop()
            else
                self.palette_manager:drawSpriteWithPalette(sprite, x, y, w, h, palette_id, tint)
            end
        else
            local scale_x, scale_y = w / sprite:getWidth(), h / sprite:getHeight()
            love.graphics.setColor(tint[1], tint[2], tint[3])
            if rotation ~= 0 then
                local ox, oy = sprite:getWidth() / 2, sprite:getHeight() / 2
                love.graphics.draw(sprite, x + w/2, y + h/2, rotation, scale_x, scale_y, ox, oy)
            else
                love.graphics.draw(sprite, x, y, 0, scale_x, scale_y)
            end
            love.graphics.setColor(1, 1, 1)
        end
        return true
    else
        local fallback_tint = options.fallback_tint or tint
        if rotation ~= 0 then
            love.graphics.push()
            love.graphics.translate(x + w/2, y + h/2)
            love.graphics.rotate(rotation)
            self.sprite_loader:drawSprite(fallback_icon, -w/2, -h/2, w, h, fallback_tint, palette_id)
            love.graphics.pop()
        else
            self.sprite_loader:drawSprite(fallback_icon, x, y, w, h, fallback_tint, palette_id)
        end
        return false
    end
end

function GameBaseView:drawEntityCentered(cx, cy, w, h, sprite_key, fallback_icon, options)
    options = options or {}
    local game = self.game
    local sprite = game.sprites and game.sprites[sprite_key]
    local tint = options.tint or {1, 1, 1}
    local rotation = options.rotation or 0
    local palette_id = self:getPaletteId()

    local flip = options.scale_x or 1

    if sprite then
        if self.palette_manager then
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.rotate(rotation)
            love.graphics.scale(flip, 1)
            self.palette_manager:drawSpriteWithPalette(sprite, -w/2, -h/2, w, h, palette_id, tint)
            love.graphics.pop()
        else
            local scale_x, scale_y = (w / sprite:getWidth()) * flip, h / sprite:getHeight()
            local ox, oy = sprite:getWidth() / 2, sprite:getHeight() / 2
            love.graphics.setColor(tint[1], tint[2], tint[3])
            love.graphics.draw(sprite, cx, cy, rotation, scale_x, scale_y, ox, oy)
            love.graphics.setColor(1, 1, 1)
        end
        return true
    else
        local fallback_tint = options.fallback_tint or tint
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(rotation)
        self.sprite_loader:drawSprite(fallback_icon, -w/2, -h/2, w, h, fallback_tint, palette_id)
        love.graphics.pop()
        return false
    end
end

return GameBaseView
