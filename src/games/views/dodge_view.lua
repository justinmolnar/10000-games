local Object = require('class')
local DodgeView = Object:extend('DodgeView')

function DodgeView:init(game_state)
    self.game = game_state
    self.OBJECT_DRAW_SIZE = game_state.OBJECT_SIZE or 15
    self.sprite_loader = nil
    self.sprite_manager = nil
    -- Simple starfield background (animated by time)
    self.stars = {}
    for i = 1, 180 do
        table.insert(self.stars, {
            x = math.random(),      -- normalized [0,1]
            y = math.random(),      -- normalized [0,1]
            speed = 20 + math.random() * 80 -- px/sec at 1x height
        })
    end
end

function DodgeView:ensureLoaded()
    if not self.sprite_loader then
        local SpriteLoader = require('src.utils.sprite_loader')
        self.sprite_loader = SpriteLoader.getInstance()
    end
    
    if not self.sprite_manager then
        local SpriteManager = require('src.utils.sprite_manager')
        self.sprite_manager = SpriteManager.getInstance()
    end
end

function DodgeView:draw()
    self:ensureLoaded()
    
    local game = self.game
    local g = love.graphics

    local game_width = game.game_width
    local game_height = game.game_height

    g.setColor(0.08, 0.05, 0.1)
    g.rectangle('fill', 0, 0, game_width, game_height)
    self:drawBackground(game_width, game_height)

    -- Safe zone ring
    if game.safe_zone then
        g.setColor(0.2, 0.8, 1.0, 0.2)
        g.circle('fill', game.safe_zone.x, game.safe_zone.y, game.safe_zone.radius)
        g.setColor(0.2, 0.8, 1.0)
        g.setLineWidth(2)
        g.circle('line', game.safe_zone.x, game.safe_zone.y, game.safe_zone.radius)
        g.setLineWidth(1)
    end

    local palette_id = self.sprite_manager:getPaletteId(game.data)
    local player_sprite = game.data.icon_sprite or "game_solitaire-0"
    
    self.sprite_loader:drawSprite(
        player_sprite,
        game.player.x - game.player.radius,
        game.player.y - game.player.radius,
        game.player.radius * 2,
        game.player.radius * 2,
        {1, 1, 1},
        palette_id
    )

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

    for _, obj in ipairs(game.objects) do
        local tint = {1,1,1}
        local sprite = "msg_error-0"
        if obj.type == 'seeker' then tint = {1, 0.3, 0.3}; sprite = "world_lock-0"
        elseif obj.type == 'zigzag' then tint = {1, 1, 0.3}; sprite = "world_star-1"
        elseif obj.type == 'sine' then tint = {0.6, 1, 0.6}; sprite = "world_star-0"
        elseif obj.type == 'splitter' then tint = {0.8, 0.6, 1.0}; sprite = "xml_gear-1" end

        self.sprite_loader:drawSprite(
            sprite,
            obj.x - obj.radius,
            obj.y - obj.radius,
            obj.radius * 2,
            obj.radius * 2,
            tint,
            palette_id
        )
    end

    local hud_icon_size = 16
    g.setColor(1, 1, 1)
    
    local dodged_sprite = self.sprite_manager:getMetricSprite(game.data, "objects_dodged") or player_sprite
    g.print("Dodged: ", 10, 10, 0, 0.85, 0.85)
    self.sprite_loader:drawSprite(dodged_sprite, 70, 10, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.objects_dodged .. "/" .. game.dodge_target, 90, 10, 0, 0.85, 0.85)
    
    local collision_sprite = self.sprite_manager:getMetricSprite(game.data, "collisions") or "msg_error-0"
    g.print("Hits: ", 10, 30, 0, 0.85, 0.85)
    self.sprite_loader:drawSprite(collision_sprite, 70, 30, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.collisions .. "/" .. game.MAX_COLLISIONS, 90, 30, 0, 0.85, 0.85)
    
    local perfect_sprite = self.sprite_manager:getMetricSprite(game.data, "perfect_dodges") or "check-0"
    g.print("Perfect: ", 10, 50, 0, 0.85, 0.85)
    self.sprite_loader:drawSprite(perfect_sprite, 70, 50, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.perfect_dodges, 90, 50, 0, 0.85, 0.85)
    
    g.print("Difficulty: " .. game.difficulty_level, 10, 70)
end

function DodgeView:drawBackground(width, height)
    local g = love.graphics
    local t = love.timer.getTime()
    g.setColor(1, 1, 1)
    for _, star in ipairs(self.stars) do
        -- animate downward based on speed; wrap with modulo 1.0
        local y = (star.y + (star.speed * t) / height) % 1
        local x = star.x
        local px = x * width
        local py = y * height
        local size = math.max(1, star.speed / 60)
        g.rectangle('fill', px, py, size, size)
    end
end

return DodgeView