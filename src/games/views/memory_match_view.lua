local Object = require('class')
local MemoryMatchView = Object:extend('MemoryMatchView')

function MemoryMatchView:init(game_state)
    self.game = game_state
    self.CARD_WIDTH = game_state.CARD_WIDTH or 60
    self.CARD_HEIGHT = game_state.CARD_HEIGHT or 80
    self.CARD_SPACING = game_state.CARD_SPACING or 10
    self.start_x = game_state.start_x
    self.start_y = game_state.start_y
    self.grid_size = game_state.grid_size
    self.sprite_loader = nil
    self.sprite_manager = nil
end

function MemoryMatchView:ensureLoaded()
    if not self.sprite_loader then
        local SpriteLoader = require('src.utils.sprite_loader')
        self.sprite_loader = SpriteLoader.getInstance()
    end
    
    if not self.sprite_manager then
        local SpriteManager = require('src.utils.sprite_manager')
        self.sprite_manager = SpriteManager.getInstance()
    end
end

function MemoryMatchView:draw()
    self:ensureLoaded()
    
    local game = self.game
    
    love.graphics.setColor(0.05, 0.08, 0.12)
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
            
            local icon_size = math.min(game.CARD_WIDTH, game.CARD_HEIGHT) - 10
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
    
    local hud_icon_size = 16
    love.graphics.setColor(1, 1, 1)
    if game.memorize_phase then
        love.graphics.print("Memorize! " .. string.format("%.1f", game.memorize_timer), 10, 10)
    else
        local matches_sprite = self.sprite_manager:getMetricSprite(game.data, "matches") or card_sprite
        love.graphics.print("Matches: ", 10, 10, 0, 0.85, 0.85)
        self.sprite_loader:drawSprite(matches_sprite, 70, 10, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
        love.graphics.print(game.metrics.matches .. "/" .. game.total_pairs, 90, 10, 0, 0.85, 0.85)
        
        local perfect_sprite = self.sprite_manager:getMetricSprite(game.data, "perfect") or "check-0"
        love.graphics.print("Perfect: ", 10, 30, 0, 0.85, 0.85)
        self.sprite_loader:drawSprite(perfect_sprite, 70, 30, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
        love.graphics.print(game.metrics.perfect, 90, 30, 0, 0.85, 0.85)
        
        local time_sprite = self.sprite_manager:getMetricSprite(game.data, "time") or "clock-0"
        love.graphics.print("Time: ", 10, 50, 0, 0.85, 0.85)
        self.sprite_loader:drawSprite(time_sprite, 70, 50, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
        love.graphics.print(string.format("%.1f", game.metrics.time), 90, 50, 0, 0.85, 0.85)
    end
    love.graphics.print("Difficulty: " .. game.difficulty_level, 10, 70)
end

return MemoryMatchView