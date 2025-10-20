local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local MemoryMatchView = require('src.games.views.memory_match_view')
local MemoryMatch = BaseGame:extend('MemoryMatch')

-- Config-driven defaults with safe fallbacks
local MMCfg = (Config and Config.games and Config.games.memory_match) or {}
local CARD_WIDTH = (MMCfg.cards and MMCfg.cards.width) or 60
local CARD_HEIGHT = (MMCfg.cards and MMCfg.cards.height) or 80
local CARD_SPACING = (MMCfg.cards and MMCfg.cards.spacing) or 10
local CARD_ICON_PADDING = (MMCfg.cards and MMCfg.cards.icon_padding) or 10
local MEMORIZE_TIME_BASE = (MMCfg.timings and MMCfg.timings.memorize_time_base) or 5
local MATCH_VIEW_TIME = (MMCfg.timings and MMCfg.timings.match_view_time) or 1

function MemoryMatch:init(game_data, cheats, di)
    MemoryMatch.super.init(self, game_data, cheats)
    self.di = di
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.memory_match) or MMCfg
    
    local speed_modifier_value = self.cheats.speed_modifier or 1.0
    local time_bonus_multiplier = 1.0 + (1.0 - speed_modifier_value)
    
    self.CARD_WIDTH = (runtimeCfg and runtimeCfg.cards and runtimeCfg.cards.width) or CARD_WIDTH
    self.CARD_HEIGHT = (runtimeCfg and runtimeCfg.cards and runtimeCfg.cards.height) or CARD_HEIGHT
    self.CARD_SPACING = (runtimeCfg and runtimeCfg.cards and runtimeCfg.cards.spacing) or CARD_SPACING
    self.CARD_ICON_PADDING = (runtimeCfg and runtimeCfg.cards and runtimeCfg.cards.icon_padding) or CARD_ICON_PADDING
    
    self.game_width = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.width) or (MMCfg.arena and MMCfg.arena.width) or 800
    self.game_height = (runtimeCfg and runtimeCfg.arena and runtimeCfg.arena.height) or (MMCfg.arena and MMCfg.arena.height) or 600
    
    local per_complexity = (MMCfg.pairs and MMCfg.pairs.per_complexity) or 6
    local pairs_count = math.floor(per_complexity * self.difficulty_modifiers.complexity) 
    self.grid_size = math.ceil(math.sqrt(pairs_count * 2)) 
    local total_cards = self.grid_size * self.grid_size
    if total_cards % 2 ~= 0 then total_cards = total_cards -1 end
    pairs_count = total_cards / 2 
    self.total_pairs = pairs_count
    
    self.cards = {}
    self:createCards(pairs_count)
    
    self.selected_indices = {} 
    self.matched_pairs = {}    
    self.memorize_phase = true
    self.memorize_timer = (MEMORIZE_TIME_BASE / self.difficulty_modifiers.time_limit) * time_bonus_multiplier
    self.match_check_timer = 0 
    
    self.metrics.matches = 0
    self.metrics.perfect = 0 
    self.metrics.time = 0    
    
    -- Calculate initial grid position now that all constants are set
    self:calculateGridPosition()
    
    self.view = MemoryMatchView:new(self)
    print("[MemoryMatch:init] Initialized with default game dimensions:", self.game_width, self.game_height)
end

function MemoryMatch:setPlayArea(width, height)
    self.game_width = width
    self.game_height = height
    
    -- Only recalculate if we have the required constants
    if self.CARD_WIDTH and self.CARD_HEIGHT and self.CARD_SPACING and self.grid_size then
        self:calculateGridPosition()
        print("[MemoryMatch] Play area updated to:", width, height)
    else
        print("[MemoryMatch] setPlayArea called before init completed, dimensions stored for later")
    end
end

function MemoryMatch:calculateGridPosition()
    local total_grid_width = (self.CARD_WIDTH + self.CARD_SPACING) * self.grid_size - self.CARD_SPACING
    local total_grid_height = (self.CARD_HEIGHT + self.CARD_SPACING) * self.grid_size - self.CARD_SPACING
    self.start_x = (self.game_width - total_grid_width) / 2
    self.start_y = (self.game_height - total_grid_height) / 2
end

function MemoryMatch:updateGameLogic(dt)
    if self.memorize_phase then
        self.memorize_timer = self.memorize_timer - dt
        if self.memorize_timer <= 0 then
            self.memorize_phase = false
            self.time_elapsed = 0 
            if self.difficulty_modifiers.complexity > 1 then self:shuffleCards() end
        end
    else
        self.metrics.time = self.time_elapsed 
        
        if self.match_check_timer > 0 then
            self.match_check_timer = self.match_check_timer - dt
            if self.match_check_timer <= 0 then
                local idx1 = self.selected_indices[1]
                local idx2 = self.selected_indices[2]
                if idx1 and idx2 and self.cards[idx1] and self.cards[idx2] then 
                    if self.cards[idx1].value == self.cards[idx2].value then
                        self.matched_pairs[self.cards[idx1].value] = true
                        self.metrics.matches = self.metrics.matches + 1
                        if #self.cards[idx1].attempts == 1 and #self.cards[idx2].attempts == 1 then
                             self.metrics.perfect = self.metrics.perfect + 1
                        end
                    end
                end
                 self.selected_indices = {}
            end
        end
    end
end

function MemoryMatch:draw()
    if self.view then
        self.view:draw()
    end
end

function MemoryMatch:mousepressed(x, y, button)
    if self.memorize_phase or self.match_check_timer > 0 or #self.selected_indices >= 2 then return end
    
    for i, card in ipairs(self.cards) do
        local row = math.floor((i-1) / self.grid_size)
        local col = (i-1) % self.grid_size
        local card_x = self.start_x + col * (self.CARD_WIDTH + self.CARD_SPACING)
        local card_y = self.start_y + row * (self.CARD_HEIGHT + self.CARD_SPACING)
        
        if x >= card_x and x <= card_x + self.CARD_WIDTH and y >= card_y and y <= card_y + self.CARD_HEIGHT then
            if not self.matched_pairs[card.value] and not self:isSelected(i) then
                table.insert(card.attempts, self.time_elapsed) 
                table.insert(self.selected_indices, i)
                if #self.selected_indices == 2 then self.match_check_timer = MATCH_VIEW_TIME end
                break 
            end
        end
    end
end

function MemoryMatch:createCards(pairs_count)
    for i = 1, pairs_count do
        for j = 1, 2 do 
            table.insert(self.cards, { value = i, attempts = {} })
        end
    end
    self:shuffleCards()
end

function MemoryMatch:shuffleCards()
    for i = #self.cards, 2, -1 do
        local j = math.random(i)
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end
end

function MemoryMatch:isSelected(index)
    for _, selected_index in ipairs(self.selected_indices) do
        if selected_index == index then return true end
    end
    return false
end

function MemoryMatch:checkComplete()
    if self.memorize_phase then return false end
    local matched_count = 0
    for _ in pairs(self.matched_pairs) do matched_count = matched_count + 1 end
    return matched_count >= self.total_pairs
end

function MemoryMatch:keypressed(key)
    return false
end

return MemoryMatch