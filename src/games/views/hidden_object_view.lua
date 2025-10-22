local Object = require('class')
local Config = rawget(_G, 'DI_CONFIG') or {}
local HiddenObjectView = Object:extend('HiddenObjectView')

function HiddenObjectView:init(game_state)
    self.game = game_state
    self.BACKGROUND_GRID_BASE = game_state.BACKGROUND_GRID_BASE or 10
    self.BACKGROUND_HASH_1 = game_state.BACKGROUND_HASH_1 or 17
    self.BACKGROUND_HASH_2 = game_state.BACKGROUND_HASH_2 or 3
    self.di = game_state and game_state.di
    local cfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.hidden_object and self.di.config.games.hidden_object.view) or
                 (Config and Config.games and Config.games.hidden_object and Config.games.hidden_object.view) or {})
    self.bg_color = cfg.bg_color or {0.12, 0.1, 0.08}
    self.hud = cfg.hud or { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 60, text_x = 80, row_y = {10, 30, 50, 70} }
    self.sprite_loader = nil
    self.sprite_manager = nil
end

function HiddenObjectView:ensureLoaded()
    if not self.sprite_loader then
        self.sprite_loader = (self.di and self.di.spriteLoader) or error("HiddenObjectView: spriteLoader not available in DI")
    end

    if not self.sprite_manager then
        self.sprite_manager = (self.di and self.di.spriteManager) or error("HiddenObjectView: spriteManager not available in DI")
    end
end

function HiddenObjectView:draw()
    self:ensureLoaded()
    
    local game = self.game

    self:drawBackground()

    local palette_id = self.sprite_manager:getPaletteId(game.data)
    local object_sprite = game.data.icon_sprite or "magnifying_glass-0"

    for _, obj in ipairs(game.objects) do
        if not obj.found then
            local angle = (obj.id * 13) % 360
            
            love.graphics.push()
            love.graphics.translate(obj.x, obj.y)
            love.graphics.rotate(math.rad(angle))
            
            self.sprite_loader:drawSprite(
                object_sprite,
                -obj.size/2,
                -obj.size/2,
                obj.size,
                obj.size,
                {1, 1, 1},
                palette_id
            )
            
            love.graphics.pop()
        end
    end

    local hud_icon_size = self.hud.icon_size or 16
    local s = self.hud.text_scale or 0.85
    local lx, ix, tx = self.hud.label_x or 10, self.hud.icon_x or 60, self.hud.text_x or 80
    local ry = self.hud.row_y or {10, 30, 50, 70}
    love.graphics.setColor(1, 1, 1)
    
    local found_sprite = self.sprite_manager:getMetricSprite(game.data, "objects_found") or object_sprite
    love.graphics.print("Found: ", lx, ry[1], 0, s, s)
    self.sprite_loader:drawSprite(found_sprite, ix, ry[1], hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    love.graphics.print(game.objects_found .. "/" .. game.total_objects, tx, ry[1], 0, s, s)
    
    local time_sprite = self.sprite_manager:getMetricSprite(game.data, "time_bonus") or "clock-0"
    love.graphics.print("Time: ", lx, ry[2], 0, s, s)
    self.sprite_loader:drawSprite(time_sprite, ix, ry[2], hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    love.graphics.print(string.format("%.1f", game.time_remaining), tx, ry[2], 0, s, s)
    
    love.graphics.print("Difficulty: " .. game.difficulty_level, lx, ry[3])
    if game.completed and game.metrics.time_bonus > 0 then
        love.graphics.print("Time Bonus: " .. game.metrics.time_bonus, lx, ry[4])
    end
end

function HiddenObjectView:drawBackground()
    local game = self.game
    love.graphics.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3])
    love.graphics.rectangle('fill', 0, 0, game.game_width, game.game_height)

    local complexity = game.difficulty_modifiers.complexity
    local grid_density = math.floor(self.BACKGROUND_GRID_BASE * complexity)
    local cell_w = game.game_width / grid_density
    local cell_h = game.game_height / grid_density

    local complexity_mod = math.max(1, self.BACKGROUND_HASH_2 + complexity)

    for i = 0, grid_density do
        for j = 0, grid_density do
            if ((i + j) * self.BACKGROUND_HASH_1) % complexity_mod == 0 then
                love.graphics.setColor(0.25, 0.22, 0.18)
                love.graphics.rectangle('fill', i * cell_w, j * cell_h, cell_w, cell_h)
            end
        end
    end
end

return HiddenObjectView