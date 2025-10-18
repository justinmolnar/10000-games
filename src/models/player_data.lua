-- src/models/player_data.lua
local Object = require('class')
local Config = require('src.config') -- Moved require to file scope
local PlayerData = Object:extend('PlayerData')

function PlayerData:init()
    -- Basic properties
    self.tokens = 0
    self.unlocked_games = {}
    self.completed_games = {} -- Might be redundant if game_performance stores all completions? Keep for now.
    self.game_performance = {} -- { game_id = { metrics={}, best_score=0, auto_completed=false } }
    self.space_defender_level = 1 -- Highest level unlocked/beaten
    self.vm_slots = 1 -- Number of VM slots owned (starts at 1)
    self.active_vms = {} -- { slot_index_str = { game_id=..., time_remaining=... } }
    
    -- New: Tracks Cheat Engine unlocks and cheat levels per game
    -- { game_id = { unlocked = true, cheats = { speed_modifier = 1, advantage_modifier = 3 } } }
    self.cheat_engine_data = {} 

    self.upgrades = {
        cpu_speed = 0,
        overclock = 0,
        auto_dodge = 0
    }
end

function PlayerData:addTokens(amount)
    -- Ensure amount is a non-negative number
    if type(amount) ~= "number" or amount < 0 then return self.tokens end
    self.tokens = self.tokens + amount
    return self.tokens
end

function PlayerData:spendTokens(amount)
    -- Ensure amount is a positive number
    if type(amount) ~= "number" or amount <= 0 then return false end
    if not self:hasTokens(amount) then
        return false
    end
    self.tokens = self.tokens - amount
    return true
end

function PlayerData:hasTokens(amount)
     -- Ensure amount is a non-negative number
    if type(amount) ~= "number" or amount < 0 then return false end
    return self.tokens >= amount
end

function PlayerData:unlockGame(game_id)
    if not self.unlocked_games[game_id] then
        self.unlocked_games[game_id] = true
        return true
    end
    return false -- Already unlocked
end

function PlayerData:isGameUnlocked(game_id)
    return self.unlocked_games[game_id] == true
end

function PlayerData:updateGamePerformance(game_id, metrics, formula_result, is_auto_completion)
    -- Ensure formula_result is a number
    formula_result = tonumber(formula_result) or 0
    is_auto_completion = is_auto_completion or false -- Default to false if not provided

    -- Initialize record if needed
    if not self.game_performance[game_id] then
        self.game_performance[game_id] = {
            metrics = {},
            best_score = 0,
            auto_completed = false
        }
    end

    local record = self.game_performance[game_id]
    local is_new_best = false

    -- Only update if it's a manual completion OR an auto-completion that hasn't been manually beaten
    if not is_auto_completion then
        -- Manual completion: always update if it's a better score
        if formula_result > record.best_score then
             record.metrics = metrics or {} -- Store provided metrics
             record.best_score = formula_result
             record.auto_completed = false -- Manual play overrides auto
             is_new_best = true
             self.completed_games[game_id] = true -- Mark as completed (might be redundant)
        end
    else -- is_auto_completion is true
        -- Auto-completion: only update if no manual score exists yet OR if auto score is somehow better (shouldn't happen)
        if not record.best_score or record.best_score == 0 or (formula_result > record.best_score and record.auto_completed) then
             record.metrics = metrics or {} -- Store auto-metrics
             record.best_score = formula_result
             record.auto_completed = true
             is_new_best = true -- Considered 'new' if it's the first score or improves previous auto
             self.completed_games[game_id] = true -- Mark as completed
        end
    end


    return is_new_best
end


function PlayerData:getGamePerformance(game_id)
    return self.game_performance[game_id]
end

function PlayerData:getGamePower(game_id)
    local perf = self:getGamePerformance(game_id)
    return perf and perf.best_score or 0
end

function PlayerData:unlockLevel(level)
    -- Assuming level is the level *beaten*, so unlocks level + 1
    local highest_unlocked = self.space_defender_level
    if level >= highest_unlocked then -- If they beat the highest known level
        self.space_defender_level = level + 1 -- Unlock the next one
        print("Unlocked Space Defender Level: " .. self.space_defender_level)
        return true
    end
    return false -- Level already unlocked or lower
end

function PlayerData:purchaseVM()
    -- This method is now handled by VMManager to keep logic together
    -- Kept here for compatibility if anything still calls it? Should be removed.
    print("Warning: PlayerData:purchaseVM() is deprecated. Use VMManager:purchaseVM().")
    return false 
end

function PlayerData:purchaseUpgrade(type)
    local base_costs = Config.upgrade_costs
    if not base_costs[type] then
        print("Error: Unknown upgrade type '" .. type .. "'")
        return false -- Unknown upgrade type
    end

    local current_level = self.upgrades[type] or 0
    local cost = base_costs[type] * (current_level + 1) -- Cost increases linearly per level

    if self:spendTokens(cost) then
        self.upgrades[type] = current_level + 1
        print("Purchased upgrade: " .. type .. " level " .. self.upgrades[type] .. " for " .. cost .. " tokens")
        return true
    end
    print("Failed purchase upgrade: " .. type .. ". Needed " .. cost .. ", had " .. self.tokens)
    return false
end

-- --- NEW CHEAT ENGINE METHODS ---

-- Ensure the game entry exists in cheat_engine_data
function PlayerData:initCheatData(game_id)
    if not self.cheat_engine_data[game_id] then
        self.cheat_engine_data[game_id] = {
            unlocked = false,
            cheats = {} -- Stores current level of each cheat, e.g. { advantage_modifier = 2 }
        }
    end
end

-- Unlock the CheatEngine for a specific game
function PlayerData:unlockCheatEngineForGame(game_id)
    self:initCheatData(game_id)
    if not self.cheat_engine_data[game_id].unlocked then
        self.cheat_engine_data[game_id].unlocked = true
        return true
    end
    return false
end

-- Check if CheatEngine is unlocked for a specific game
function PlayerData:isCheatEngineUnlocked(game_id)
    self.cheat_engine_data = self.cheat_engine_data or {} -- Safety check for older saves
    if not self.cheat_engine_data[game_id] then
        return false
    end
    return self.cheat_engine_data[game_id].unlocked
end

-- Purchase the next level of a specific cheat
function PlayerData:purchaseCheatLevel(game_id, cheat_id)
    self:initCheatData(game_id)
    local current_level = self.cheat_engine_data[game_id].cheats[cheat_id] or 0
    self.cheat_engine_data[game_id].cheats[cheat_id] = current_level + 1
    print("Purchased cheat " .. cheat_id .. " level " .. (current_level + 1) .. " for " .. game_id)
end

-- Get the current purchased level of a cheat
function PlayerData:getCheatLevel(game_id, cheat_id)
    self.cheat_engine_data = self.cheat_engine_data or {} -- Safety check
    if not self.cheat_engine_data[game_id] or not self.cheat_engine_data[game_id].cheats then
        return 0
    end
    return self.cheat_engine_data[game_id].cheats[cheat_id] or 0
end


-- Add the serialize method
function PlayerData:serialize()
    return {
        tokens = self.tokens,
        unlocked_games = self.unlocked_games,
        completed_games = self.completed_games,
        game_performance = self.game_performance,
        space_defender_level = self.space_defender_level,
        vm_slots = self.vm_slots,
        active_vms = self.active_vms,
        cheat_engine_data = self.cheat_engine_data, -- Added
        upgrades = self.upgrades
    }
end


return PlayerData