local GameBaseView = require('src.games.views.game_base_view')
local DodgeView = GameBaseView:extend('DodgeView')

function DodgeView:init(game_state, variant)
    DodgeView.super.init(self, game_state, variant)

    self.OBJECT_DRAW_SIZE = game_state.OBJECT_SIZE or 15
    self:initBackground(variant, game_state.params)
end

function DodgeView:drawContent()

    local game = self.game
    local g = love.graphics

    local game_width = game.game_width
    local game_height = game.game_height

    -- Apply camera shake (Phase 3 - VisualEffects component)
    g.push()
    game.visual_effects:applyCameraShake()

    local interact_r = game.params.bg_interact_radius or 0
    if interact_r > 0 then
        local pts = {}
        for _, obj in ipairs(game.objects) do
            if obj.type ~= 'warning' then
                local ovx = obj.vx or 0
                local ovy = obj.vy or 0
                if ovx == 0 and ovy == 0 and obj.speed and obj.speed ~= 0 then
                    local a = obj.angle or obj.direction or 0
                    ovx = math.cos(a) * obj.speed
                    ovy = math.sin(a) * obj.speed
                end
                pts[#pts + 1] = {
                    obj.x / game_width,
                    obj.y / game_height,
                    ovx / game_width,
                    ovy / game_height,
                }
            end
        end
        if #pts > 0 then
            self.background:setPoints(pts)
        end
    end
    self.background:draw(game_width, game_height)

    -- Safe zone ring (generic polygon or image arena)
    if game.arena_controller and not game.params.hide_arena then
        local ac = game.arena_controller

        if ac.image_mode and ac.image then
            -- Image-based arena: draw the image as the playable area
            local ox, oy = ac:getImageOffset()
            local alpha = 0.8
            if game.game_over then
                local flash = (math.sin(love.timer.getTime() * 10) + 1) / 2
                g.setColor(1.0, 0.5 + flash * 0.3, 0.5 + flash * 0.3, alpha)
            else
                g.setColor(1, 1, 1, alpha)
            end
            g.draw(ac.image, ox, oy, 0, ac.image_scale_x, ac.image_scale_y)
        else
            local vertices = ac:getScaledVertices()

            -- Game over flash effect
            local flash_alpha = 0.2
            if game.game_over then
                local flash = (math.sin(love.timer.getTime() * 10) + 1) / 2
                flash_alpha = 0.2 + flash * 0.3
                g.setColor(1.0, 0.2, 0.2, flash_alpha)
            else
                g.setColor(0.2, 0.8, 1.0, flash_alpha)
            end

            g.polygon('fill', vertices)
            if game.game_over then
                g.setColor(1.0, 0.2, 0.2)
            else
                g.setColor(0.2, 0.8, 1.0)
            end
            g.setLineWidth(2)
            g.polygon('line', vertices)

            -- Draw deformation effect for "deformation" morph type
            if ac.morph_type == "deformation" then
                g.setColor(0.2, 0.8, 1.0, 0.1)
                local wobble = math.sin((ac.morph_timer or 0) * 3) * 5
                local r = ac:getEffectiveRadius()
                -- Draw wobbled version of the polygon
                local wobbled = {}
                for i = 1, #vertices, 2 do
                    table.insert(wobbled, vertices[i] + wobble)
                    table.insert(wobbled, vertices[i+1] + wobble)
                end
                g.polygon('line', wobbled)
            end

            g.setLineWidth(1)
        end
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

    -- Draw player
    local game_config = self.di and self.di.config and self.di.config.games and self.di.config.games.dodge
    local tint = self:getTint("DodgeGame", game_config)

    local player_size = game.player.radius * 2
    local player_rotation = game.player.rotation or 0
    local player_fallback = game.data.icon_sprite or "game_solitaire-0"
    self:drawEntityCentered(game.player.x, game.player.y, player_size, player_size, "player", player_fallback, {
        rotation = player_rotation,
        tint = tint,
        scale_x = game.player.facing_x
    })

    -- Draw shield visual
    if game.params.shield > 0 and game.health_system:isShieldActive() then
        self:drawShieldIndicator(game.player.x, game.player.y, game.player.radius + 5)
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
    for i, obj in ipairs(game.objects) do
        if obj.type_name == 'hole' or obj.type_name == 'warning' or obj.type_name == 'water' then goto continue_obj end

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

        local sprite_key = obj.enemy_type and ("enemy_" .. obj.enemy_type) or nil
        local size = obj.radius * 2
        local carrier_tint = obj.water_carrier and {0.6, 0.85, 1.0} or nil
        if obj.water_carrier then
            local t = love.timer.getTime()
            self:drawWaterCarrierEffects(obj.x, obj.y, obj.radius * 1.2, t)
        end
        self:drawEntityCentered(obj.x, obj.y, size, size, sprite_key, "msg_error-0", {
            rotation = rotation,
            tint = carrier_tint,
            fallback_tint = carrier_tint or self:getIndexedColor(i)
        })

    ::continue_obj::
    end

    -- Fog of war overlay (after all game elements, before closing transform)
    local fog_origin = game.params.fog_of_war_origin
    local fog_radius = game.params.fog_of_war_radius
    if fog_origin and fog_origin ~= "none" and fog_radius and fog_radius < 9999 then
        local sources = {}
        if fog_origin == "player" then
            table.insert(sources, game.player)
        elseif fog_origin == "circle_center" or fog_origin == "center" then
            table.insert(sources, game.arena_controller or {x = game_width/2, y = game_height/2})
        end
        self:renderFog(game_width, game_height, sources, fog_radius)
    end

    GameBaseView.drawWater(self)
    GameBaseView.drawPopups(self)

    -- Draw particles (within camera transform)
    game.visual_effects:drawParticles()

    -- Close camera shake transform
    g.pop()

    -- Standard HUD - NOT affected by camera shake
    game.hud:draw(game_width, game_height)

    -- Screen flash (over everything)
    game.visual_effects:drawScreenFlash(game_width, game_height)

    -- Extra stats
    local y = 90
    y = game.hud:drawStat("Dodged", math.floor(game.metrics.objects_dodged) .. "/" .. math.floor(game.dodge_target), y)
    if game.metrics.combo > 0 then
        y = game.hud:drawStat("Combo", game.metrics.combo, y, {0.2, 1, 0.2})
    end
    if game.params.shield and game.params.shield > 0 then
        local shield_color = game.health_system:isShieldActive() and {0.5, 0.5, 1} or {0.5, 0.5, 0.5}
        y = game.hud:drawStat("Shield", game.health_system:getShieldHitsRemaining() .. "/" .. game.params.shield, y, shield_color)
    end
    y = game.hud:drawStat("Difficulty", game.difficulty_level, y)
end

-- Drawn inside drawContent (within camera transform) instead
function DodgeView:drawWater() end
function DodgeView:drawPopups() end

return DodgeView