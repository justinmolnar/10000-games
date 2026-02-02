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
        goal_color = p.goal_color
    })

    self.billboard_renderer = BillboardRenderer:new({
        fov = p.fov,
        render_distance = p.render_distance
    })

    self.minimap_renderer = MinimapRenderer:new({
        size = p.minimap_size,
        goal_color = p.goal_color
    })
end

function RaycasterView:drawContent()
    local game = self.game
    local w = game.viewport_width or love.graphics.getWidth()
    local h = game.viewport_height or love.graphics.getHeight()
    local p = game.params

    -- Draw 3D view (walls)
    self.raycast_renderer:draw(w, h, game.player, game.map, game.map_width, game.map_height, game.goal)

    -- Draw billboards (sprites in 3D space)
    if game.billboards and #game.billboards > 0 then
        self.billboard_renderer:setDepthBuffer(self.raycast_renderer:getDepthBuffer())
        self.billboard_renderer:draw(w, h, game.player, game.billboards)
    end

    -- Minimap overlay
    if p.show_minimap then
        self.minimap_renderer:draw(w, h, game.map, game.map_width, game.map_height, game.player, game.goal)
    end

    -- Screen flash
    game.visual_effects:drawScreenFlash(w, h)

    -- HUD
    if not game.vm_render_mode then
        game.hud:draw(w, h)

        -- Controls hint
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.print("WASD: Move | Q/E: Strafe | R: New Maze", 10, h - 25)
    end
end

function RaycasterView:getVictorySubtitle()
    return string.format("Time: %.1fs", self.game.time_elapsed)
end

function RaycasterView:getGameOverSubtitle()
    return nil
end

return RaycasterView
