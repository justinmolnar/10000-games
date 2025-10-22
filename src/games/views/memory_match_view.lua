local Object = require('class')
local Config = rawget(_G, 'DI_CONFIG') or {}
local MemoryMatchView = Object:extend('MemoryMatchView')

function MemoryMatchView:init(game_state)
    self.game = game_state
    self.CARD_WIDTH = game_state.CARD_WIDTH or 60
    self.CARD_HEIGHT = game_state.CARD_HEIGHT or 80
    self.CARD_SPACING = game_state.CARD_SPACING or 10
    self.di = game_state and game_state.di
    local cfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.memory_match and self.di.config.games.memory_match.view) or
                 (Config and Config.games and Config.games.memory_match and Config.games.memory_match.view) or {})
    self.bg_color = cfg.bg_color or {0.05, 0.08, 0.12}
    self.hud = cfg.hud or { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 70, text_x = 90, row_y = {10, 30, 50, 70} }
    self.start_x = game_state.start_x
    self.start_y = game_state.start_y
    self.grid_size = game_state.grid_size
    self.sprite_loader = nil
    self.sprite_manager = nil
end

function MemoryMatchView:ensureLoaded()
    if not self.sprite_loader then
        self.sprite_loader = (self.di and self.di.spriteLoader) or error("MemoryMatchView: spriteLoader not available in DI")
    end

    if not self.sprite_manager then
        self.sprite_manager = (self.di and self.di.spriteManager) or error("MemoryMatchView: spriteManager not available in DI")
    end
end

function MemoryMatchView:draw()
    self:ensureLoaded()
    
    local game = self.game
    
    love.graphics.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3])
    love.graphics.rectangle('fill', 0, 0, game.game_width, game.game_height)
    
    local palette_id = self.sprite_manager:getPaletteId(game.data)
    local card_sprite = game.data.icon_sprite or "game_freecell-0"
    
    for i, card in ipairs(game.cards) do
        local row = math.floor((i-1) / game.grid_size)
        local col = (i-1) % game.grid_size
        
        local x = game.start_x + col * (game.CARD_WIDTH + game.CARD_SPACING)
        local y = game.start_y + row * (game.CARD_HEIGHT + game.CARD_SPACING)
        
        local face_up = game.memorize_phase or             
                       game.matched_pairs[card.value] or   
                       game:isSelected(i)                  
        
        if face_up then
            love.graphics.setColor(0.9, 0.9, 0.85)
            love.graphics.rectangle('fill', x, y, game.CARD_WIDTH, game.CARD_HEIGHT)
            
            local icon_padding = game.CARD_ICON_PADDING or 10
            local icon_size = math.min(game.CARD_WIDTH, game.CARD_HEIGHT) - icon_padding
            local icon_x = x + (game.CARD_WIDTH - icon_size) / 2
            local icon_y = y + (game.CARD_HEIGHT - icon_size) / 2
            self.sprite_loader:drawSprite(
                card_sprite,
                icon_x,
                icon_y,
                icon_size,
                icon_size,
                {1, 1, 1},
                palette_id
            )
            
            love.graphics.setColor(0.1, 0.1, 0.1)
            local text_width = love.graphics.getFont():getWidth(tostring(card.value))
            love.graphics.print(tostring(card.value), x + (game.CARD_WIDTH - text_width)/2, y + 5)
        else
            love.graphics.setColor(0.4, 0.5, 0.9)
            love.graphics.rectangle('fill', x, y, game.CARD_WIDTH, game.CARD_HEIGHT)
            love.graphics.setColor(0.25, 0.35, 0.7)
            love.graphics.rectangle('line', x, y, game.CARD_WIDTH, game.CARD_HEIGHT)
        end
    end
    
    local hud_icon_size = self.hud.icon_size or 16
    local s = self.hud.text_scale or 0.85
    local lx, ix, tx = self.hud.label_x or 10, self.hud.icon_x or 70, self.hud.text_x or 90
    local ry = self.hud.row_y or {10, 30, 50, 70}
    love.graphics.setColor(1, 1, 1)
    if game.memorize_phase then
        love.graphics.print("Memorize! " .. string.format("%.1f", game.memorize_timer), lx, ry[1])
    else
        local matches_sprite = self.sprite_manager:getMetricSprite(game.data, "matches") or card_sprite
        love.graphics.print("Matches: ", lx, ry[1], 0, s, s)
        self.sprite_loader:drawSprite(matches_sprite, ix, ry[1], hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
        love.graphics.print(game.metrics.matches .. "/" .. game.total_pairs, tx, ry[1], 0, s, s)
        
        local perfect_sprite = self.sprite_manager:getMetricSprite(game.data, "perfect") or "check-0"
        love.graphics.print("Perfect: ", lx, ry[2], 0, s, s)
        self.sprite_loader:drawSprite(perfect_sprite, ix, ry[2], hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
        love.graphics.print(game.metrics.perfect, tx, ry[2], 0, s, s)
        
        local time_sprite = self.sprite_manager:getMetricSprite(game.data, "time") or "clock-0"
        love.graphics.print("Time: ", lx, ry[3], 0, s, s)
        self.sprite_loader:drawSprite(time_sprite, ix, ry[3], hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
        love.graphics.print(string.format("%.1f", game.metrics.time), tx, ry[3], 0, s, s)
    end
    love.graphics.print("Difficulty: " .. game.difficulty_level, lx, ry[4])
end

return MemoryMatchView