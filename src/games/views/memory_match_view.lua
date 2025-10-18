-- src/games/views/memory_match_view.lua
local Object = require('class')
local MemoryMatchView = Object:extend('MemoryMatchView')

function MemoryMatchView:init(game_state)
    self.game = game_state
    -- Store layout constants from game state
    self.CARD_WIDTH = game_state.CARD_WIDTH or 60
    self.CARD_HEIGHT = game_state.CARD_HEIGHT or 80
    self.CARD_SPACING = game_state.CARD_SPACING or 10
    self.start_x = game_state.start_x
    self.start_y = game_state.start_y
    self.grid_size = game_state.grid_size
end

function MemoryMatchView:draw()
    local game = self.game
    
    for i, card in ipairs(game.cards) do
        local row = math.floor((i-1) / self.grid_size)
        local col = (i-1) % self.grid_size
        
        local x = self.start_x + col * (self.CARD_WIDTH + self.CARD_SPACING)
        local y = self.start_y + row * (self.CARD_HEIGHT + self.CARD_SPACING)
        
        local face_up = game.memorize_phase or             
                       game.matched_pairs[card.value] or   
                       game:isSelected(i) -- Call method on game state                  
        
        if face_up then
            love.graphics.setColor(1, 1, 1) 
            love.graphics.rectangle('fill', x, y, self.CARD_WIDTH, self.CARD_HEIGHT)
            love.graphics.setColor(0, 0, 0) 
            local text_width = love.graphics.getFont():getWidth(card.value)
            love.graphics.print(card.value, x + (self.CARD_WIDTH - text_width)/2, y + (self.CARD_HEIGHT - love.graphics.getFont():getHeight())/2)
        else
            love.graphics.setColor(0.5, 0.5, 1) 
            love.graphics.rectangle('fill', x, y, self.CARD_WIDTH, self.CARD_HEIGHT)
            love.graphics.setColor(0.3, 0.3, 0.8) 
            love.graphics.rectangle('line', x, y, self.CARD_WIDTH, self.CARD_HEIGHT)
        end
    end
    
    -- Draw HUD
    love.graphics.setColor(1, 1, 1)
    if game.memorize_phase then
        love.graphics.print("Memorize! " .. string.format("%.1f", game.memorize_timer), 10, 10)
    else
        love.graphics.print("Matches: " .. game.metrics.matches .. "/" .. game.total_pairs, 10, 10)
        love.graphics.print("Perfect: " .. game.metrics.perfect, 10, 30)
        love.graphics.print("Time: " .. string.format("%.1f", game.metrics.time), 10, 50)
    end
    love.graphics.print("Difficulty: " .. game.difficulty_level, 10, 70)
end

return MemoryMatchView