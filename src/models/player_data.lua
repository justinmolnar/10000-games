-- src/models/player_data.lua
local Object = require('class')
local Config = require('src.config')
-- Removed global assumption

local PlayerData = Object:extend('PlayerData')

-- Accept statistics instance
function PlayerData:init(statistics_instance)
    self.statistics = statistics_instance -- Store injected instance

    self.tokens = 0
    self.unlocked_games = {}
    self.completed_games = {}
    self.game_performance = {}
    self.space_defender_level = 1
    self.vm_slots = 1
    self.active_vms = {}
    self.cheat_engine_data = {}
    self.upgrades = { cpu_speed=0, overclock=0, auto_dodge=0 }
end

function PlayerData:addTokens(amount)
    if type(amount) ~= "number" or amount < 0 then return self.tokens end
    self.tokens = self.tokens + amount
    -- Update statistics using self.statistics
    if self.statistics and self.statistics.addTokensEarned then
        self.statistics:addTokensEarned(amount)
        -- print("Debug PlayerData: Called addTokensEarned") -- Optional debug
    else
        -- print("Debug PlayerData: Statistics object not found in addTokens") -- Optional debug
    end
    return self.tokens
end

function PlayerData:spendTokens(amount)
    if type(amount) ~= "number" or amount <= 0 then return false end
    if not self:hasTokens(amount) then return false end
    self.tokens = self.tokens - amount
    return true
end

function PlayerData:hasTokens(amount)
    if type(amount) ~= "number" or amount < 0 then return false end
    return self.tokens >= amount
end

function PlayerData:unlockGame(game_id)
    if not self.unlocked_games[game_id] then
        self.unlocked_games[game_id] = true
        -- Update statistics using self.statistics
        if self.statistics and self.statistics.incrementGamesUnlocked then
             self.statistics:incrementGamesUnlocked()
             -- print("Debug PlayerData: Called incrementGamesUnlocked") -- Optional debug
        else
            -- print("Debug PlayerData: Statistics object not found in unlockGame") -- Optional debug
        end
        return true
    end
    return false
end

function PlayerData:isGameUnlocked(game_id)
    return self.unlocked_games[game_id] == true
end

function PlayerData:updateGamePerformance(game_id, metrics, formula_result, is_auto_completion)
    formula_result = tonumber(formula_result) or 0
    is_auto_completion = is_auto_completion or false

    if not self.game_performance[game_id] then
        self.game_performance[game_id] = {
            metrics = {},
            best_score = 0,
            auto_completed = false
        }
    end

    local record = self.game_performance[game_id]
    local is_new_best = false

    if not is_auto_completion then
        if formula_result > record.best_score then
             record.metrics = metrics or {}
             record.best_score = formula_result
             record.auto_completed = false
             is_new_best = true
             self.completed_games[game_id] = true
        end
    else
        if not record.best_score or record.best_score == 0 or (formula_result > record.best_score and record.auto_completed) then
             record.metrics = metrics or {}
             record.best_score = formula_result
             record.auto_completed = true
             is_new_best = true
             self.completed_games[game_id] = true
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
    local highest_unlocked = self.space_defender_level
    if level >= highest_unlocked then
        self.space_defender_level = level + 1
        print("Unlocked Space Defender Level: " .. self.space_defender_level)
        return true
    end
    return false
end

function PlayerData:purchaseVM()
    print("Warning: PlayerData:purchaseVM() is deprecated. Use VMManager:purchaseVM().")
    return false
end

function PlayerData:purchaseUpgrade(type)
    local base_costs = Config.upgrade_costs
    if not base_costs[type] then
        print("Error: Unknown upgrade type '" .. type .. "'")
        return false
    end

    local current_level = self.upgrades[type] or 0
    local cost = base_costs[type] * (current_level + 1)

    if self:spendTokens(cost) then
        self.upgrades[type] = current_level + 1
        print("Purchased upgrade: " .. type .. " level " .. self.upgrades[type] .. " for " .. cost .. " tokens")
        return true
    end
    print("Failed purchase upgrade: " .. type .. ". Needed " .. cost .. ", had " .. self.tokens)
    return false
end

function PlayerData:initCheatData(game_id)
    if not self.cheat_engine_data[game_id] then
        self.cheat_engine_data[game_id] = {
            unlocked = false,
            cheats = {}
        }
    end
end

function PlayerData:unlockCheatEngineForGame(game_id)
    self:initCheatData(game_id)
    if not self.cheat_engine_data[game_id].unlocked then
        self.cheat_engine_data[game_id].unlocked = true
        return true
    end
    return false
end

function PlayerData:isCheatEngineUnlocked(game_id)
    self.cheat_engine_data = self.cheat_engine_data or {}
    if not self.cheat_engine_data[game_id] then
        return false
    end
    return self.cheat_engine_data[game_id].unlocked
end

function PlayerData:purchaseCheatLevel(game_id, cheat_id)
    self:initCheatData(game_id)
    local current_level = self.cheat_engine_data[game_id].cheats[cheat_id] or 0
    self.cheat_engine_data[game_id].cheats[cheat_id] = current_level + 1
    print("Purchased cheat " .. cheat_id .. " level " .. (current_level + 1) .. " for " .. game_id)
end

function PlayerData:getCheatLevel(game_id, cheat_id)
    self.cheat_engine_data = self.cheat_engine_data or {}
    if not self.cheat_engine_data[game_id] or not self.cheat_engine_data[game_id].cheats then
        return 0
    end
    return self.cheat_engine_data[game_id].cheats[cheat_id] or 0
end


function PlayerData:serialize()
    return {
        tokens = self.tokens,
        unlocked_games = self.unlocked_games,
        completed_games = self.completed_games,
        game_performance = self.game_performance,
        space_defender_level = self.space_defender_level,
        vm_slots = self.vm_slots,
        active_vms = self.active_vms,
        cheat_engine_data = self.cheat_engine_data,
        upgrades = self.upgrades
    }
end


return PlayerData