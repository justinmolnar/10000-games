local GameBaseView = require('src.games.views.game_base_view')
local RaycastRenderer = require('src.utils.game_components.raycast_renderer')
local BillboardRenderer = require('src.utils.game_components.billboard_renderer')
local MinimapRenderer = require('src.utils.game_components.minimap_renderer')

local RaycasterView = GameBaseView:extend('RaycasterView')

function RaycasterView:init(game)
    RaycasterView.super.init(self, game, nil)

    local p = game.params

    self.raycast_renderer = RaycastRenderer:new({
        fov = p.fov,
        ray_count = p.ray_count,
        render_distance = p.render_distance,
        wall_height = p.wall_height,
        ceiling_color = p.ceiling_color,
        floor_color = p.floor_color,
        wall_color_ns = p.wall_color_ns,
        wall_color_ew = p.wall_color_ew,
        goal_color = p.goal_color,
        door_color = p.door_color
    })

    self.billboard_renderer = BillboardRenderer:new({
        fov = p.fov,
        render_distance = p.render_distance
    })

    self.minimap_renderer = MinimapRenderer:new({
        size = p.minimap_size,
        goal_color = p.goal_color,
        show_enemies = p.minimap_show_enemies
    })
end

function RaycasterView:drawContent()
    local game = self.game
    local w = game.viewport_width or love.graphics.getWidth()
    local h = game.viewport_height or love.graphics.getHeight()
    local p = game.params

    -- Draw 3D view (walls and doors)
    self.raycast_renderer:draw(w, h, game.player, game.map, game.map_width, game.map_height, game.goal, game.doors)

    -- Draw billboards (sprites in 3D space)
    if game.billboards and #game.billboards > 0 then
        self.billboard_renderer:setDepthBuffer(self.raycast_renderer:getDepthBuffer())
        self.billboard_renderer:draw(w, h, game.player, game.billboards)
    end

    -- Minimap overlay
    if p.show_minimap then
        -- Filter out dead/dying enemies for minimap
        local enemies = {}
        if game.entity_controller then
            for _, e in ipairs(game.entity_controller:getEntities()) do
                if not e.is_corpse and not e.die_progress then
                    table.insert(enemies, e)
                end
            end
        end
        local vc = p.victory_condition
        local goal = (vc == "goal" or vc == nil) and game.goal or nil

        -- Update critical path visualization
        if game.show_critical_path and game.critical_path then
            self.minimap_renderer:setCriticalPath(game.critical_path)
        else
            self.minimap_renderer:setCriticalPath(nil)
        end

        self.minimap_renderer:draw(w, h, game.map, game.map_width, game.map_height, game.player, goal, game.doors, enemies)
    end

    -- Screen flash
    game.visual_effects:drawScreenFlash(w, h)

    -- HUD
    if not game.vm_render_mode then
        game.hud:draw(w, h)

        -- Extra stats below standard HUD
        local hud_y = game.hud:getHeight()

        -- Health display (Wolf3D style)
        if game.player_controller and game.params.enemy_ai_enabled then
            local health = game.player_controller.health or 100
            local max_health = game.player_controller.max_health or 100
            local health_pct = health / max_health
            local health_color = health_pct > 0.5 and {0.2, 1, 0.3} or (health_pct > 0.25 and {1, 1, 0} or {1, 0.2, 0.2})
            hud_y = game.hud:drawStat("HEALTH", health, hud_y, health_color)
        end

        -- Weapon display
        if game.player_controller and game.player_controller.current_weapon then
            local weapon_name = game.player_controller.current_weapon:upper()
            hud_y = game.hud:drawStat("WEAPON", weapon_name, hud_y, {1, 1, 1})
        end

        -- Ammo display (Wolf3D style)
        if game.player_controller and game.params.ammo_enabled then
            local ammo = game.player_controller:getAmmo()
            local ammo_color = ammo > 0 and {1, 1, 0} or {1, 0, 0}
            hud_y = game.hud:drawStat("AMMO", ammo, hud_y, ammo_color)
        end

        -- Kills display
        if game.enemies_killed and game.enemies_killed > 0 then
            hud_y = game.hud:drawStat("KILLS", game.enemies_killed, hud_y, {1, 0.5, 0.5})
        end

        -- Score display
        if game.score and game.score > 0 then
            hud_y = game.hud:drawStat("SCORE", game.score, hud_y, {1, 0.85, 0})
        end

        -- Controls hint
        love.graphics.setColor(1, 1, 1, 0.6)
        local controls = "WASD: Move | Q/E: Strafe | R: New Maze"
        if game.player_controller and game.player_controller.current_weapon then
            controls = controls .. " | 1/2/3: Weapons"
        end
        love.graphics.print(controls, 10, h - 25)
    end
end

function RaycasterView:getVictorySubtitle()
    return string.format("Time: %.1fs", self.game.time_elapsed)
end

function RaycasterView:getGameOverSubtitle()
    return nil
end

return RaycasterView
