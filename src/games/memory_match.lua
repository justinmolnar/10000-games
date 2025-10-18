local BaseGame = require('src.games.base_game')
local MemoryMatch = BaseGame:extend('MemoryMatch')

-- Constants
local CARD_WIDTH = 60
local CARD_HEIGHT = 80
local CARD_SPACING = 10
local MEMORIZE_TIME = 5  -- Time to view cards at start

function MemoryMatch:init(game_data)
    MemoryMatch.super.init(self, game_data)
    
    -- Calculate grid size based on difficulty
    local pairs_count = math.floor(6 * self.difficulty_modifiers.complexity)
    self.grid_size = math.ceil(math.sqrt(pairs_count * 2))
    
    -- Initialize cards
    self.cards = {}
    self:createCards(pairs_count)
    
    -- Game state
    self.selected_cards = {}
    self.matched_pairs = {}
    self.memorize_phase = true
    self.memorize_timer = MEMORIZE_TIME / self.difficulty_modifiers.time_limit
    
    -- Metrics
    self.metrics.matches = 0
    self.metrics.perfect = 0
    self.metrics.time = 0
    
    -- Layout
    self.start_x = (love.graphics.getWidth() - (CARD_WIDTH + CARD_SPACING) * self.grid_size) / 2
    self.start_y = (love.graphics.getHeight() - (CARD_HEIGHT + CARD_SPACING) * self.grid_size) / 2
end

function MemoryMatch:update(dt)
    if self.completed then return end
    MemoryMatch.super.update(self, dt)
    
    if self.memorize_phase then
        self.memorize_timer = self.memorize_timer - dt
        if self.memorize_timer <= 0 then
            self.memorize_phase = false
            -- Shuffle cards if complexity > 1
            if self.difficulty_modifiers.complexity > 1 then
                self:shuffleCards()
            end
        end
    else
        -- Update metrics
        self.metrics.time = self.time_elapsed
        
        -- Check selected cards
        if #self.selected_cards == 2 then
            local card1 = self.cards[self.selected_cards[1]]
            local card2 = self.cards[self.selected_cards[2]]
            
            if card1.value == card2.value then
                -- Match found
                self.matched_pairs[card1.value] = true
                self.metrics.matches = self.metrics.matches + 1
                if #card1.attempts == 1 then
                    self.metrics.perfect = self.metrics.perfect + 1
                end
            end
            
            -- Clear selection after delay
            if self.time_elapsed - card2.flip_time > 1 then
                self.selected_cards = {}
            end
        end
    end
end

function MemoryMatch:draw()
    -- Draw cards
    for i, card in ipairs(self.cards) do
        local row = math.floor((i-1) / self.grid_size)
        local col = (i-1) % self.grid_size
        
        local x = self.start_x + col * (CARD_WIDTH + CARD_SPACING)
        local y = self.start_y + row * (CARD_HEIGHT + CARD_SPACING)
        
        -- Determine if card should be face up
        local face_up = self.memorize_phase or
                       self.matched_pairs[card.value] or
                       self:isSelected(i)
        
        -- Draw card
        if face_up then
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle('fill', x, y, CARD_WIDTH, CARD_HEIGHT)
            love.graphics.setColor(0, 0, 0)
            love.graphics.print(card.value, x + CARD_WIDTH/3, y + CARD_HEIGHT/3)
        else
            love.graphics.setColor(0.5, 0.5, 1)
            love.graphics.rectangle('fill', x, y, CARD_WIDTH, CARD_HEIGHT)
        end
    end
    
    -- Draw HUD
    love.graphics.setColor(1, 1, 1)
    if self.memorize_phase then
        love.graphics.print("Memorize! " .. string.format("%.1f", self.memorize_timer), 10, 10)
    else
        love.graphics.print("Matches: " .. self.metrics.matches, 10, 10)
        love.graphics.print("Perfect: " .. self.metrics.perfect, 10, 30)
        love.graphics.print("Time: " .. string.format("%.1f", self.metrics.time), 10, 50)
    end
end

function MemoryMatch:mousepressed(x, y, button)
    if self.memorize_phase or #self.selected_cards >= 2 then return end
    
    -- Check each card
    for i, card in ipairs(self.cards) do
        local row = math.floor((i-1) / self.grid_size)
        local col = (i-1) % self.grid_size
        
        local card_x = self.start_x + col * (CARD_WIDTH + CARD_SPACING)
        local card_y = self.start_y + row * (CARD_HEIGHT + CARD_SPACING)
        
        -- Check if card was clicked and isn't already matched/selected
        if x >= card_x and x <= card_x + CARD_WIDTH and
           y >= card_y and y <= card_y + CARD_HEIGHT and
           not self.matched_pairs[card.value] and
           not self:isSelected(i) then
            
            -- Add card to attempts
            table.insert(card.attempts, self.time_elapsed)
            
            -- Select card
            card.flip_time = self.time_elapsed
            table.insert(self.selected_cards, i)
            break
        end
    end
end

function MemoryMatch:createCards(pairs_count)
    -- Create pairs of cards
    for i = 1, pairs_count do
        for j = 1, 2 do
            table.insert(self.cards, {
                value = i,
                attempts = {},
                flip_time = 0
            })
        end
    end
    
    -- Initial shuffle
    self:shuffleCards()
end

function MemoryMatch:shuffleCards()
    for i = #self.cards, 2, -1 do
        local j = math.random(i)
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end
end

function MemoryMatch:isSelected(index)
    for _, selected in ipairs(self.selected_cards) do
        if selected == index then
            return true
        end
    end
    return false
end

function MemoryMatch:checkComplete()
    if self.memorize_phase then return false end
    
    -- Count matched pairs
    local total_pairs = #self.cards / 2
    local matched_count = 0
    for _ in pairs(self.matched_pairs) do
        matched_count = matched_count + 1
    end
    
    return matched_count >= total_pairs
end

return MemoryMatch