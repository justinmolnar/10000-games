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

    -- Apply camera shake (Phase 3 - VisualEffects component)
    g.push()
    game.visual_effects:applyCameraShake()

    g.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3])
    g.rectangle('fill', 0, 0, game_width, game_height)
    self:drawBackground(game_width, game_height)

    -- Safe zone ring (shape-aware)
    if game.arena_controller then
        local ac = game.arena_controller
        local shape = ac.shape or "circle"

        -- Game over flash effect
        local flash_alpha = 0.2
        if game.game_over then
            local flash = (math.sin(love.timer.getTime() * 10) + 1) / 2
            flash_alpha = 0.2 + flash * 0.3
            g.setColor(1.0, 0.2, 0.2, flash_alpha)
        else
            g.setColor(0.2, 0.8, 1.0, flash_alpha)
        end

        local r = ac:getEffectiveRadius()
        if shape == "circle" then
            g.circle('fill', ac.x, ac.y, r)
            if game.game_over then
                g.setColor(1.0, 0.2, 0.2)
            else
                g.setColor(0.2, 0.8, 1.0)
            end
            g.setLineWidth(2)
            g.circle('line', ac.x, ac.y, r)

        elseif shape == "square" then
            g.rectangle('fill', ac.x - r, ac.y - r, r * 2, r * 2)
            if game.game_over then
                g.setColor(1.0, 0.2, 0.2)
            else
                g.setColor(0.2, 0.8, 1.0)
            end
            g.setLineWidth(2)
            g.rectangle('line', ac.x - r, ac.y - r, r * 2, r * 2)

        elseif shape == "hex" then
            -- Draw hexagon (6 vertices)
            local vertices = {}
            for i = 0, 5 do
                local angle = (i / 6) * math.pi * 2 - math.pi / 2  -- Start at top
                table.insert(vertices, ac.x + math.cos(angle) * r)
                table.insert(vertices, ac.y + math.sin(angle) * r)
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
        if ac.morph_type == "deformation" then
            -- Simple wobble visualization: draw additional circles at perturbed positions
            g.setColor(0.2, 0.8, 1.0, 0.1)
            local wobble = math.sin((ac.morph_timer or 0) * 3) * 5
            g.circle('line', ac.x + wobble, ac.y, r + wobble)
            g.circle('line', ac.x, ac.y + wobble, r + wobble)
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

    -- Draw player trail
    if game.player_trail and (game.params.player_trail_length or 0) > 0 then
        game.player_trail:draw()
    end

    -- Draw player (sprite or fallback to icon)
    local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
    local paletteManager = self.di and self.di.paletteManager

    -- Get tint for this variant based on config
    local tint = {1, 1, 1}  -- Default: no tint
    local config = (self.di and self.di.config) or Config
    if paletteManager and config and config.games and config.games.dodge then
        tint = paletteManager:getTintForVariant(self.variant, "DodgeGame", config.games.dodge)
    end

    if game.sprites and game.sprites.player then
        -- Use loaded player sprite with tinting and rotation
        local sprite = game.sprites.player
        local size = game.player.radius * 2
        local rotation = game.player.rotation or 0

        -- Apply tint and draw with rotation
        g.push()
        g.translate(game.player.x, game.player.y)
        g.rotate(rotation)
        g.setColor(tint[1], tint[2], tint[3])
        g.draw(sprite,
            -game.player.radius,
            -game.player.radius,
            0,
            size / sprite:getWidth(),
            size / sprite:getHeight())
        g.setColor(1, 1, 1)  -- Reset color
        g.pop()
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

    -- Draw shield visual
    if game.params.shield > 0 and game.health_system:isShieldActive() then
        local shield_alpha = 0.3 + 0.2 * math.sin(love.timer.getTime() * 5)
        g.setColor(0.3, 0.7, 1.0, shield_alpha)
        g.setLineWidth(3)
        g.circle('line', game.player.x, game.player.y, game.player.radius + 5)
        g.setLineWidth(1)
    end

    g.setColor(0.9, 0.9, 0.3, 0.45)
    local warning_draw_thickness = self.OBJECT_DRAW_SIZE * 1.5
    -- Draw warning entities (type = 'warning' with warning_type = 'radial')
    for _, obj in ipairs(game.objects) do
        if obj.type == 'warning' then
            if obj.warning_type == 'radial' then
                local len = 5000
                local x2 = obj.x + math.cos(obj.spawn_angle or 0) * len
                local y2 = obj.y + math.sin(obj.spawn_angle or 0) * len
                g.setLineWidth(3)
                g.line(obj.x, obj.y, x2, y2)
                g.setLineWidth(1)
                g.circle('fill', obj.x, obj.y, 4)
            end
        end
    end

    -- Draw objects/enemies
    for i, obj in ipairs(game.objects) do
        -- Draw obstacle trail first (behind object)
        if obj.trail_positions and #obj.trail_positions > 1 then
            g.setColor(1, 0.4, 0.2, 0.4)
            g.setLineWidth(2)
            local points = {}
            for i, pos in ipairs(obj.trail_positions) do
                table.insert(points, pos.x)
                table.insert(points, pos.y)
            end
            if #points >= 4 then
                g.line(points)
            end
            g.setLineWidth(1)
        end

        local sprite_img = nil
        local sprite_key = nil

        -- Determine which sprite to use - all enemies use "enemy_TYPE" pattern
        if obj.enemy_type then
            sprite_key = "enemy_" .. obj.enemy_type
            sprite_img = game.sprites and game.sprites[sprite_key]
        end

        if sprite_img then
            -- Use loaded sprite with palette swapping
            local size = obj.radius * 2

            -- DEBUG: Print what we're actually drawing (first object only)
            if i == 1 and not self._draw_debug_printed then
                print(string.format("[DodgeView] Drawing first object: enemy_type=%s, sprite_key=%s, sprite=%s, paletteManager=%s, palette_id=%s",
                    tostring(obj.enemy_type), sprite_key, tostring(sprite_img), tostring(paletteManager ~= nil), tostring(palette_id)))
                self._draw_debug_printed = true
            end

            -- Calculate rotation angle based on sprite direction mode
            local rotation = 0

            if obj.sprite_direction_mode == "movement_based" or not obj.sprite_direction_mode then
                -- Default: rotate sprite to face movement direction
                if obj.vx or obj.vy then
                    rotation = math.atan2(obj.vy or 0, obj.vx or 0) + math.pi/2  -- +90° because sprites point up
                else
                    rotation = obj.angle or 0
                end
            else
                -- Locked direction: use specified angle in degrees
                rotation = math.rad(obj.sprite_direction_mode)
            end

            -- Add accumulated rotation from sprite_rotation_speed
            if obj.sprite_rotation_angle then
                rotation = rotation + math.rad(obj.sprite_rotation_angle)
            end

            if paletteManager and palette_id then
                -- Palette drawing with rotation (need to transform manually)
                g.push()
                g.translate(obj.x, obj.y)
                g.rotate(rotation)
                paletteManager:drawSpriteWithPalette(
                    sprite_img,
                    -obj.radius,
                    -obj.radius,
                    size,
                    size,
                    palette_id,
                    {1, 1, 1}
                )
                g.pop()
            else
                -- No palette, just draw normally with rotation
                g.setColor(1, 1, 1)
                g.draw(sprite_img,
                    obj.x,
                    obj.y,
                    rotation,
                    size / sprite_img:getWidth(),
                    size / sprite_img:getHeight(),
                    sprite_img:getWidth() / 2,
                    sprite_img:getHeight() / 2)
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

    -- Fog of war overlay (after all game elements, before closing transform)
    if game.fog_controller then
        local fog = game.fog_controller
        fog:clearSources()

        local fog_origin = game.params.fog_of_war_origin
        local fog_radius = game.params.fog_of_war_radius
        if fog_origin and fog_origin ~= "none" and fog_radius < 9999 then
            local fog_x, fog_y
            if fog_origin == "player" then
                fog_x, fog_y = game.player.x, game.player.y
            elseif (fog_origin == "circle_center" or fog_origin == "center") and game.arena_controller then
                fog_x, fog_y = game.arena_controller.x, game.arena_controller.y
            else
                fog_x, fog_y = game_width / 2, game_height / 2
            end

            fog:addVisibilitySource(fog_x, fog_y, fog_radius)
            fog:render(game_width, game_height)
        end
    end

    -- Close camera shake transform
    g.pop()

    -- Standard HUD (Phase 8) - NOT affected by camera shake
    game.hud:draw(game_width, game_height)

    -- Additional game-specific stats (below standard HUD)
    if not game.vm_render_mode then
        local s = 0.85
        local lx = 10
        local hud_y = 90  -- Start below standard HUD

        g.setColor(1, 1, 1)

        -- Dodged progress
        g.print("Dodged: " .. game.metrics.objects_dodged .. "/" .. game.dodge_target, lx, hud_y, 0, s, s)
        hud_y = hud_y + 18

        -- Combo
        if game.metrics.combo > 0 then
            g.setColor(0.2, 1, 0.2)
            g.print("Combo: " .. game.metrics.combo, lx, hud_y, 0, s, s)
            hud_y = hud_y + 18
            g.setColor(1, 1, 1)
        end

        -- Shield charges (if enabled)
        if game.params.shield and game.params.shield > 0 then
            local shield_color = game.health_system:isShieldActive() and {0.5, 0.5, 1} or {0.5, 0.5, 0.5}
            g.setColor(shield_color)
            g.print("Shield: " .. game.health_system:getShieldHitsRemaining() .. "/" .. game.params.shield, lx, hud_y, 0, s, s)
            hud_y = hud_y + 18
            g.setColor(1, 1, 1)
        end

        -- Difficulty
        g.print("Difficulty: " .. game.difficulty_level, lx, hud_y, 0, s, s)
    end
end

function DodgeView:drawBackground(width, height)
    local g = love.graphics
    local game = self.game

    -- Use loaded background sprite if available
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