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
end

function MemoryMatchView:draw()
    local game = self.game
    
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle('fill', 0, 0, game.game_width, game.game_height)
    
    for i, card in ipairs(game.cards) do
        local row = math.floor((i-1) / game.grid_size)
        local col = (i-1) % game.grid_size
        
        -- Read directly from game state, not cached values
        local x = game.start_x + col * (game.CARD_WIDTH + game.CARD_SPACING)
        local y = game.start_y + row * (game.CARD_HEIGHT + game.CARD_SPACING)
        
        local face_up = game.memorize_phase or             
                       game.matched_pairs[card.value] or   
                       game:isSelected(i)                  
        
        if face_up then
            love.graphics.setColor(1, 1, 1) 
            love.graphics.rectangle('fill', x, y, game.CARD_WIDTH, game.CARD_HEIGHT)
            love.graphics.setColor(0, 0, 0) 
            local text_width = love.graphics.getFont():getWidth(tostring(card.value))
            love.graphics.print(tostring(card.value), x + (game.CARD_WIDTH - text_width)/2, y + (game.CARD_HEIGHT - love.graphics.getFont():getHeight())/2)
        else
            love.graphics.setColor(0.5, 0.5, 1) 
            love.graphics.rectangle('fill', x, y, game.CARD_WIDTH, game.CARD_HEIGHT)
            love.graphics.setColor(0.3, 0.3, 0.8) 
            love.graphics.rectangle('line', x, y, game.CARD_WIDTH, game.CARD_HEIGHT)
        end
    end
    
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