local Object = require('class')
local PlayerData = Object:extend('PlayerData')

function PlayerData:init()
    -- Basic properties
    self.tokens = 0
    self.unlocked_games = {}
    self.completed_games = {}
    self.game_performance = {}
    self.space_defender_level = 1
    self.vm_slots = 1  -- Start with 1 VM slot
    self.active_vms = {}
    self.upgrades = {
        cpu_speed = 0,
        overclock = 0,
        auto_dodge = 0
    }
end

function PlayerData:addTokens(amount)
    self.tokens = self.tokens + amount
    return self.tokens
end

function PlayerData:spendTokens(amount)
    if not self:hasTokens(amount) then
        return false
    end
    self.tokens = self.tokens - amount
    return true
end

function PlayerData:hasTokens(amount)
    return self.tokens >= amount
end

function PlayerData:unlockGame(game_id)
    if not self.unlocked_games[game_id] then
        self.unlocked_games[game_id] = true
        return true
    end
    return false
end

function PlayerData:isGameUnlocked(game_id)
    return self.unlocked_games[game_id] == true
end

function PlayerData:updateGamePerformance(game_id, metrics, formula_result)
    -- Initialize game performance record if it doesn't exist
    if not self.game_performance[game_id] then
        self.game_performance[game_id] = {
            metrics = {},
            best_score = 0
        }
    end

    local record = self.game_performance[game_id]
    local is_new_best = formula_result > record.best_score

    -- Update metrics and best score if this is a new best
    if is_new_best then
        record.metrics = metrics
        record.best_score = formula_result
        self.completed_games[game_id] = true
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
    if level > self.space_defender_level then
        self.space_defender_level = level
        return true
    end
    return false
end

function PlayerData:purchaseVM()
    local base_cost = 1000
    local current_slots = self.vm_slots
    local cost = base_cost * (current_slots * 2)  -- Each slot costs double the previous
    
    if self:spendTokens(cost) then
        self.vm_slots = self.vm_slots + 1
        return true
    end
    return false
end

function PlayerData:purchaseUpgrade(type)
    local costs = {
        cpu_speed = 500,
        overclock = 1000,
        auto_dodge = 2000
    }
    
    local current_level = self.upgrades[type] or 0
    local cost = costs[type] * (current_level + 1)
    
    if self:spendTokens(cost) then
        self.upgrades[type] = current_level + 1
        return true
    end
    return false
end

return PlayerData