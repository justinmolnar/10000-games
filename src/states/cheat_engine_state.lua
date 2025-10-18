-- src/states/cheat_engine_state.lua
local Object = require('class')
local CheatEngineView = require('src.views.cheat_engine_view')
local CheatEngineState = Object:extend('CheatEngineState')

function CheatEngineState:init(player_data, game_data, state_machine, save_manager, cheat_system)
    self.player_data = player_data
    self.game_data = game_data
    self.state_machine = state_machine
    self.save_manager = save_manager
    self.cheat_system = cheat_system -- Injected dependency

    self.view = CheatEngineView:new(self)
    
    self.all_games = {} -- Will hold all games, including locked
    self.scroll_offset = 1
    self.selected_game_id = nil
    self.selected_game = nil
    
    -- This now holds the *dynamic cheat data* for the selected game
    -- e.g. { id="speed", name="Speed", current_level=1, max_level=5, cost=1200, value=0.15 }
    self.available_cheats = {} 
end

function CheatEngineState:enter()
    self:updateGameList()
    -- Select the first game by default if list is not empty
    if #self.all_games > 0 then
        self.selected_game_id = self.all_games[1].id
        self.selected_game = self.all_games[1]
        self:buildAvailableCheats()
    else
        self:resetSelection()
    end
end

function CheatEngineState:updateGameList()
    self.all_games = self.game_data:getAllGames()
    -- Sort by id with natural number sorting
    table.sort(self.all_games, function(a, b)
        -- Extract base name and number from id
        local a_base, a_num = a.id:match("^(.-)_(%d+)$")
        local b_base, b_num = b.id:match("^(.-)_(%d+)$")
        
        -- If both have numbers, compare base first, then number
        if a_base and b_base and a_num and b_num then
            if a_base == b_base then
                return tonumber(a_num) < tonumber(b_num)
            else
                return a_base < b_base
            end
        end
        
        -- Fallback to regular string comparison
        return a.id < b.id
    end)
end

function CheatEngineState:resetSelection()
    self.selected_game_id = nil
    self.selected_game = nil
    self.available_cheats = {} -- Clear the available cheats
end

function CheatEngineState:update(dt)
    self.view:update(dt, self.all_games, self.selected_game_id, self.available_cheats)
end

function CheatEngineState:draw()
    self.view:draw(
        self.all_games, 
        self.selected_game_id, 
        self.available_cheats, -- Pass the game-specific cheats
        self.player_data
    )
end

function CheatEngineState:keypressed(key)
    if key == 'escape' then
        self.state_machine:switch('desktop')
        return true
    end
    return false
end

function CheatEngineState:mousepressed(x, y, button)
    local event = self.view:mousepressed(x, y, button, self.all_games, self.selected_game_id, self.available_cheats)
    if not event then return end
    
    if event.name == "select_game" then
        self.selected_game_id = event.id
        self.selected_game = self.game_data:getGame(event.id)
        self:buildAvailableCheats() -- Build the new cheat list
        
    elseif event.name == "unlock_cheat_engine" then
        self:unlockCheatEngine()
        
    elseif event.name == "purchase_cheat" then
        self:purchaseCheat(event.id)

    elseif event.name == "launch_game" then
        self:launchGame()
    end
end

-- Calculates the scaled cost for a base cost and game
function CheatEngineState:getScaledCost(base_cost)
    if not self.selected_game then return 999999 end
    
    local exponent = self.selected_game.cheat_cost_exponent or 1.15
    local diff_level = self.selected_game.difficulty_level or 1
    
    -- Cost = Base * (Exponent ^ (Difficulty - 1))
    -- This makes level 1 cost the base_cost
    return math.floor(base_cost * (exponent ^ (diff_level - 1)))
end

-- Calculates the cost for the *next level* of a cheat
function CheatEngineState:getCheatLevelCost(cheat_def, current_level)
    -- Use exponential scaling for cheat levels: Cost = ScaledBaseCost * (2 ^ CurrentLevel)
    local scaled_base_cost = self:getScaledCost(cheat_def.base_cost)
    -- Cost for level 1 is (base * 2^0), level 2 is (base * 2^1), etc.
    return math.floor(scaled_base_cost * (2 ^ current_level))
end

function CheatEngineState:buildAvailableCheats()
    self.available_cheats = {}
    if not self.selected_game or not self.selected_game.available_cheats then
        return
    end
    
    local all_defs = self.cheat_system:getCheatDefinitions()
    
    for _, cheat_def in ipairs(self.selected_game.available_cheats) do
        local static_def = all_defs[cheat_def.id]
        if static_def then
            local current_level = self.player_data:getCheatLevel(self.selected_game_id, cheat_def.id)
            local cost_for_next_level = self:getCheatLevelCost(cheat_def, current_level)
            
            table.insert(self.available_cheats, {
                id = cheat_def.id,
                name = static_def.name,
                description = static_def.description,
                is_fake = static_def.is_fake,
                
                current_level = current_level,
                max_level = cheat_def.max_level,
                cost_for_next = cost_for_next_level,
                value_per_level = cheat_def.value_per_level
            })
        else
            print("Warning: Game " .. self.selected_game.id .. " listed unknown cheat_id: " .. cheat_def.id)
        end
    end
end

function CheatEngineState:wheelmoved(x, y)
    -- Handle scrolling in the game list
    local mx, my = love.mouse.getPosition()
    if mx >= self.view.list_x and mx <= self.view.list_x + self.view.list_w and
       my >= self.view.list_y and my <= self.view.list_y + self.view.list_h then
        
        self.scroll_offset = self.view:wheelmoved(x, y, #self.all_games)
    end
end

function CheatEngineState:unlockCheatEngine()
    if not self.selected_game then return end
    
    local cost = self:getScaledCost(self.selected_game.cheat_engine_base_cost)
    
    if self.player_data:spendTokens(cost) then
        self.player_data:unlockCheatEngineForGame(self.selected_game_id)
        self.save_manager.save(self.player_data)
        self:buildAvailableCheats() -- Refresh cheat list
    else
        print("Not enough tokens to unlock CE for " .. self.selected_game_id)
    end
end

function CheatEngineState:purchaseCheat(cheat_id)
    if not self.selected_game then return end
    
    -- Find the cheat def
    local cheat_to_buy
    for _, cheat in ipairs(self.available_cheats) do
        if cheat.id == cheat_id then
            cheat_to_buy = cheat
            break
        end
    end
    
    if not cheat_to_buy then return end
    
    if cheat_to_buy.current_level >= cheat_to_buy.max_level then
        print("Cheat at max level")
        return
    end
    
    local cost = cheat_to_buy.cost_for_next
    
    if self.player_data:spendTokens(cost) then
        self.player_data:purchaseCheatLevel(self.selected_game_id, cheat_id)
        self.save_manager.save(self.player_data)
        self:buildAvailableCheats() -- Refresh list to show new level and cost
    else
        print("Not enough tokens to buy cheat level")
    end
end

function CheatEngineState:launchGame()
    if not self.selected_game_id or not self.player_data:isGameUnlocked(self.selected_game_id) then
        print("Cannot launch a locked game")
        return 
    end
    
    -- Prepare the final cheat values to be activated
    local cheats_to_activate = {}
    for _, cheat in ipairs(self.available_cheats) do
        if cheat.current_level > 0 and not cheat.is_fake then
            local total_value
            if type(cheat.value_per_level) == "number" then
                -- e.g., speed_modifier: 1.0 - (0.15 * 3) = 0.55
                -- e.g., performance_modifier: 1.0 + (0.1 * 5) = 1.5
                if cheat.id == "speed_modifier" then
                    -- Speed modifier should be capped (e.g., at 80% slow)
                    total_value = math.max(0.2, 1.0 - (cheat.value_per_level * cheat.current_level))
                else -- performance_modifier
                    total_value = 1.0 + (cheat.value_per_level * cheat.current_level)
                end
            elseif type(cheat.value_per_level) == "table" then
                -- e.g., { deaths = 1 } * 3 = { deaths = 3 }
                total_value = {}
                for key, val in pairs(cheat.value_per_level) do
                    total_value[key] = val * cheat.current_level
                end
            end
            
            cheats_to_activate[cheat.id] = total_value
        end
    end
    
    -- Activate cheats in the system
    self.cheat_system:activateCheats(self.selected_game_id, cheats_to_activate)
    
    -- Launch the game
    self.state_machine:switch('minigame', self.selected_game)
end

return CheatEngineState