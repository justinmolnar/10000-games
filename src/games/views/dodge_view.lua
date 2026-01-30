local GameBaseView = require('src.games.views.game_base_view')
local DodgeView = GameBaseView:extend('DodgeView')

function DodgeView:init(game_state, variant)
    DodgeView.super.init(self, game_state, variant, {
        background_tiled = true,
        background_starfield = true
    })

    -- Game-specific view config
    self.OBJECT_DRAW_SIZE = game_state.OBJECT_SIZE or 15
    local cfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.dodge and self.di.config.games.dodge.view) or {})
    self.bg_color = cfg.bg_color or {0.08, 0.05, 0.1}

    -- Starfield background config
    local sf = cfg.starfield or { count = 180, speed_min = 20, speed_max = 100, size_divisor = 60 }
    self.stars = {}
    for i = 1, (sf.count or 180) do
        table.insert(self.stars, {
            x = math.random(),
            y = math.random(),
            speed = (sf.speed_min or 20) + math.random() * ((sf.speed_max or 100) - (sf.speed_min or 20))
        })
    end
    self.star_size_divisor = sf.size_divisor or 60
end

function DodgeView:drawContent()

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

    -- Render holes (from EC entity list)
    if game.entity_controller then
        for _, hole in ipairs(game.entity_controller:getEntitiesByType("hole")) do
            if hole.boundary_angle then
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

    local player_size = game.player.radius * 2
    local player_rotation = game.player.rotation or 0
    local player_fallback = game.data.icon_sprite or "game_solitaire-0"
    self:drawEntityCentered(game.player.x, game.player.y, player_size, player_size, "player", player_fallback, {
        rotation = player_rotation,
        tint = tint,
        use_palette = true,
        palette_id = palette_id
    })

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

    -- Draw objects/enemies (skip types rendered separately)
    for _, obj in ipairs(game.objects) do
        if obj.type_name == 'hole' or obj.type_name == 'warning' then goto continue_obj end

        -- Draw obstacle trail first (behind object)
        if obj.trail_positions and #obj.trail_positions > 1 then
            g.setColor(1, 0.4, 0.2, 0.4)
            g.setLineWidth(2)
            local points = {}
            for _, pos in ipairs(obj.trail_positions) do
                table.insert(points, pos.x)
                table.insert(points, pos.y)
            end
            if #points >= 4 then
                g.line(points)
            end
            g.setLineWidth(1)
        end

        -- Calculate rotation angle based on sprite direction mode
        local rotation = 0
        if obj.sprite_direction_mode == "movement_based" or not obj.sprite_direction_mode then
            if obj.vx or obj.vy then
                rotation = math.atan2(obj.vy or 0, obj.vx or 0) + math.pi/2
            else
                rotation = obj.angle or 0
            end
        else
            rotation = math.rad(obj.sprite_direction_mode)
        end
        if obj.sprite_rotation_angle then
            rotation = rotation + math.rad(obj.sprite_rotation_angle)
        end

        -- Determine sprite key and fallback icon/tint
        local sprite_key = obj.enemy_type and ("enemy_" .. obj.enemy_type) or nil
        local fallback_icon = "msg_error-0"
        local fallback_tint = {1, 1, 1}
        if obj.type == 'seeker' then fallback_tint = {1, 0.3, 0.3}; fallback_icon = "world_lock-0"
        elseif obj.type == 'zigzag' then fallback_tint = {1, 1, 0.3}; fallback_icon = "world_star-1"
        elseif obj.type == 'sine' then fallback_tint = {0.6, 1, 0.6}; fallback_icon = "world_star-0"
        elseif obj.type == 'splitter' then fallback_tint = {0.8, 0.6, 1.0}; fallback_icon = "xml_gear-1" end

        local size = obj.radius * 2
        self:drawEntityCentered(obj.x, obj.y, size, size, sprite_key, fallback_icon, {
            rotation = rotation,
            use_palette = true,
            palette_id = palette_id,
            fallback_tint = fallback_tint
        })

    ::continue_obj::
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

return DodgeView