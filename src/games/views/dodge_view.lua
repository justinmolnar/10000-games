local Object = require('class')
local Config = rawget(_G, 'DI_CONFIG') or {}
local DodgeView = Object:extend('DodgeView')

function DodgeView:init(game_state, variant)
    self.game = game_state
    self.variant = variant -- Store variant data for future use (Phase 1.3)
    self.OBJECT_DRAW_SIZE = game_state.OBJECT_SIZE or 15
    self.di = game_state and game_state.di
    local cfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.dodge and self.di.config.games.dodge.view) or
                 (Config and Config.games and Config.games.dodge and Config.games.dodge.view) or {})
    self.bg_color = cfg.bg_color or {0.08, 0.05, 0.1}

    -- NOTE: In Phase 2, background will be determined by variant.background
    -- e.g., variant.background could be "starfield_blue", "starfield_red", etc.
    self.hud = cfg.hud or { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 70, text_x = 90, row_y = {10, 30, 50, 70} }
    local sf = cfg.starfield or { count = 180, speed_min = 20, speed_max = 100, size_divisor = 60 }
    self.sprite_loader = nil
    self.sprite_manager = nil
    -- Simple starfield background (animated by time)
    self.stars = {}
    for i = 1, (sf.count or 180) do
        table.insert(self.stars, {
            x = math.random(),      -- normalized [0,1]
            y = math.random(),      -- normalized [0,1]
            speed = (sf.speed_min or 20) + math.random() * ((sf.speed_max or 100) - (sf.speed_min or 20)) -- px/sec at 1x height
        })
    end
    self.star_size_divisor = sf.size_divisor or 60
end

function DodgeView:ensureLoaded()
    if not self.sprite_loader then
        self.sprite_loader = (self.di and self.di.spriteLoader) or error("DodgeView: spriteLoader not available in DI")
    end

    if not self.sprite_manager then
        self.sprite_manager = (self.di and self.di.spriteManager) or error("DodgeView: spriteManager not available in DI")
    end
end

function DodgeView:draw()
    self:ensureLoaded()

    local game = self.game
    local g = love.graphics

    local game_width = game.game_width
    local game_height = game.game_height

    g.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3])
    g.rectangle('fill', 0, 0, game_width, game_height)
    self:drawBackground(game_width, game_height)

    -- Safe zone ring (shape-aware)
    if game.safe_zone then
        local sz = game.safe_zone
        local shape = sz.area_shape or "circle"

        -- Game over flash effect
        local flash_alpha = 0.2
        if game.game_over then
            local flash = (math.sin(love.timer.getTime() * 10) + 1) / 2
            flash_alpha = 0.2 + flash * 0.3
            g.setColor(1.0, 0.2, 0.2, flash_alpha)
        else
            g.setColor(0.2, 0.8, 1.0, flash_alpha)
        end

        if shape == "circle" then
            g.circle('fill', sz.x, sz.y, sz.radius)
            if game.game_over then
                g.setColor(1.0, 0.2, 0.2)
            else
                g.setColor(0.2, 0.8, 1.0)
            end
            g.setLineWidth(2)
            g.circle('line', sz.x, sz.y, sz.radius)

        elseif shape == "square" then
            local half = sz.radius
            g.rectangle('fill', sz.x - half, sz.y - half, half * 2, half * 2)
            if game.game_over then
                g.setColor(1.0, 0.2, 0.2)
            else
                g.setColor(0.2, 0.8, 1.0)
            end
            g.setLineWidth(2)
            g.rectangle('line', sz.x - half, sz.y - half, half * 2, half * 2)

        elseif shape == "hex" then
            -- Draw hexagon (6 vertices)
            local vertices = {}
            for i = 0, 5 do
                local angle = (i / 6) * math.pi * 2 - math.pi / 2  -- Start at top
                table.insert(vertices, sz.x + math.cos(angle) * sz.radius)
                table.insert(vertices, sz.y + math.sin(angle) * sz.radius)
            end
            g.polygon('fill', vertices)
            if game.game_over then
                g.setColor(1.0, 0.2, 0.2)
            else
                g.setColor(0.2, 0.8, 1.0)
            end
            g.setLineWidth(2)
            g.polygon('line', vertices)
        end

        -- Draw deformation effect for "deformation" morph type
        if sz.area_morph_type == "deformation" then
            -- Simple wobble visualization: draw additional circles at perturbed positions
            g.setColor(0.2, 0.8, 1.0, 0.1)
            local wobble = math.sin(sz.morph_time * 3) * 5
            g.circle('line', sz.x + wobble, sz.y, sz.radius + wobble)
            g.circle('line', sz.x, sz.y + wobble, sz.radius + wobble)
        end

        g.setLineWidth(1)
    end

    -- Render holes
    if game.holes then
        for _, hole in ipairs(game.holes) do
            if hole.on_boundary then
                -- Holes on boundary (red with warning effect)
                g.setColor(1.0, 0.2, 0.2, 0.6)
                g.circle('fill', hole.x, hole.y, hole.radius)
                g.setColor(1.0, 0.0, 0.0)
                g.setLineWidth(2)
                g.circle('line', hole.x, hole.y, hole.radius)
                g.setLineWidth(1)
            else
                -- Background holes (darker, static)
                g.setColor(0.3, 0.0, 0.0, 0.8)
                g.circle('fill', hole.x, hole.y, hole.radius)
                g.setColor(0.6, 0.0, 0.0)
                g.setLineWidth(1)
                g.circle('line', hole.x, hole.y, hole.radius)
            end
        end
    end

    -- Phase 2.3: Draw player (sprite or fallback to icon)
    local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
    local paletteManager = self.di and self.di.paletteManager

    if game.sprites and game.sprites.player then
        -- Use loaded player sprite with palette swapping and rotation
        local sprite = game.sprites.player
        local size = game.player.radius * 2

        if paletteManager and palette_id then
            paletteManager:drawSpriteWithPalette(
                sprite,
                game.player.x,  -- Draw from center for rotation
                game.player.y,
                size,
                size,
                palette_id,
                {1, 1, 1},
                game.player.rotation or 0  -- Rotation angle
            )
        else
            -- No palette, just draw normally with rotation
            g.push()
            g.translate(game.player.x, game.player.y)
            g.rotate(game.player.rotation or 0)
            g.setColor(1, 1, 1)
            g.draw(sprite,
                -game.player.radius,
                -game.player.radius,
                0,
                size / sprite:getWidth(),
                size / sprite:getHeight())
            g.pop()
        end
    else
        -- Fallback to icon system with rotation
        local player_sprite = game.data.icon_sprite or "game_solitaire-0"

        g.push()
        g.translate(game.player.x, game.player.y)
        g.rotate(game.player.rotation or 0)
        self.sprite_loader:drawSprite(
            player_sprite,
            -game.player.radius,
            -game.player.radius,
            game.player.radius * 2,
            game.player.radius * 2,
            {1, 1, 1},
            palette_id
        )
        g.pop()
    end

    g.setColor(0.9, 0.9, 0.3, 0.45)
    local warning_draw_thickness = self.OBJECT_DRAW_SIZE * 1.5
    for _, warning in ipairs(game.warnings) do
        if warning.type == 'radial' then
            -- Draw a short wedge/arrow along the initial angle from the spawn point
            local len = 28
            local x2 = warning.sx + math.cos(warning.angle) * len
            local y2 = warning.sy + math.sin(warning.angle) * len
            g.setLineWidth(3)
            g.line(warning.sx, warning.sy, x2, y2)
            g.setLineWidth(1)
            g.circle('fill', warning.sx, warning.sy, 4)
        else
            -- Legacy fallback
            g.rectangle('fill', 0, 0, 0, 0)
        end
    end

    -- Phase 2.3: Draw objects/enemies (sprites or fallback to icons)
    for _, obj in ipairs(game.objects) do
        local sprite_img = nil
        local sprite_key = nil

        -- Determine which sprite to use
        if obj.is_enemy and obj.enemy_type then
            -- Variant enemy - try to load enemy sprite
            sprite_key = "enemy_" .. obj.enemy_type
            sprite_img = game.sprites and game.sprites[sprite_key]
        elseif not obj.is_enemy then
            -- Regular obstacle
            sprite_key = "obstacle"
            sprite_img = game.sprites and game.sprites[sprite_key]
        end

        if sprite_img then
            -- Use loaded sprite with palette swapping
            local size = obj.radius * 2

            if paletteManager and palette_id then
                paletteManager:drawSpriteWithPalette(
                    sprite_img,
                    obj.x - obj.radius,
                    obj.y - obj.radius,
                    size,
                    size,
                    palette_id,
                    {1, 1, 1}
                )
            else
                -- No palette, just draw normally
                g.setColor(1, 1, 1)
                g.draw(sprite_img,
                    obj.x - obj.radius,
                    obj.y - obj.radius,
                    0,
                    size / sprite_img:getWidth(),
                    size / sprite_img:getHeight())
            end
        else
            -- Fallback to icon system
            local tint = {1,1,1}
            local icon_sprite = "msg_error-0"
            if obj.type == 'seeker' then tint = {1, 0.3, 0.3}; icon_sprite = "world_lock-0"
            elseif obj.type == 'zigzag' then tint = {1, 1, 0.3}; icon_sprite = "world_star-1"
            elseif obj.type == 'sine' then tint = {0.6, 1, 0.6}; icon_sprite = "world_star-0"
            elseif obj.type == 'splitter' then tint = {0.8, 0.6, 1.0}; icon_sprite = "xml_gear-1" end

            self.sprite_loader:drawSprite(
                icon_sprite,
                obj.x - obj.radius,
                obj.y - obj.radius,
                obj.radius * 2,
                obj.radius * 2,
                tint,
                palette_id
            )
        end
    end

    local hud_icon_size = self.hud.icon_size or 16
    local s = self.hud.text_scale or 0.85
    local lx, ix, tx = self.hud.label_x or 10, self.hud.icon_x or 70, self.hud.text_x or 90
    local ry = self.hud.row_y or {10, 30, 50, 70}
    g.setColor(1, 1, 1)

    local dodged_sprite = self.sprite_manager:getMetricSprite(game.data, "objects_dodged") or player_sprite
    g.print("Dodged: ", lx, ry[1], 0, s, s)
    self.sprite_loader:drawSprite(dodged_sprite, ix, ry[1], hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.objects_dodged .. "/" .. game.dodge_target, tx, ry[1], 0, s, s)
    
    local collision_sprite = self.sprite_manager:getMetricSprite(game.data, "collisions") or "msg_error-0"
    g.print("Hits: ", lx, ry[2], 0, s, s)
    self.sprite_loader:drawSprite(collision_sprite, ix, ry[2], hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.collisions .. "/" .. game.MAX_COLLISIONS, tx, ry[2], 0, s, s)
    
    local perfect_sprite = self.sprite_manager:getMetricSprite(game.data, "perfect_dodges") or "check-0"
    g.print("Perfect: ", lx, ry[3], 0, s, s)
    self.sprite_loader:drawSprite(perfect_sprite, ix, ry[3], hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.perfect_dodges, tx, ry[3], 0, s, s)

    g.print("Difficulty: " .. game.difficulty_level, lx, ry[4])
end

function DodgeView:drawBackground(width, height)
    local g = love.graphics
    local game = self.game

    -- Phase 2.3: Use loaded background sprite if available
    if game and game.sprites and game.sprites.background then
        -- Tile the background to fill the play area
        local bg = game.sprites.background
        local bg_width = bg:getWidth()
        local bg_height = bg:getHeight()

        -- Apply palette swap
        local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
        local paletteManager = self.di and self.di.paletteManager

        -- Tile the background with palette swapping
        for y = 0, math.ceil(height / bg_height) do
            for x = 0, math.ceil(width / bg_width) do
                if paletteManager and palette_id then
                    paletteManager:drawSpriteWithPalette(
                        bg,
                        x * bg_width,
                        y * bg_height,
                        bg_width,
                        bg_height,
                        palette_id,
                        {1, 1, 1}
                    )
                else
                    -- No palette, just draw normally
                    g.setColor(1, 1, 1)
                    g.draw(bg, x * bg_width, y * bg_height)
                end
            end
        end

        return -- Don't draw starfield if we have a background sprite
    end

    -- Fallback: Draw animated starfield
    local t = love.timer.getTime()
    g.setColor(1, 1, 1)
    for _, star in ipairs(self.stars) do
        -- animate downward based on speed; wrap with modulo 1.0
        local y = (star.y + (star.speed * t) / height) % 1
        local x = star.x
        local px = x * width
        local py = y * height
        local size = math.max(1, star.speed / (self.star_size_divisor or 60))
        g.rectangle('fill', px, py, size, size)
    end
end

return DodgeView