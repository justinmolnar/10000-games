local Object = require('class')
local VictoryCondition = Object:extend('VictoryCondition')

--[[
    Phase 9: Victory Condition System

    Unified victory/loss condition checking for all games.

    Usage:
        self.victory_condition = VictoryCondition:new({
            victory = {
                type = "threshold",
                metric = "dodges",
                target = 50
            },
            loss = {
                type = "lives_depleted",
                metric = "lives"
            }
        })
        self.victory_condition.game = self

        -- In update loop:
        local result = self.victory_condition:check()
        if result then
            self.victory = (result == "victory")
            self.game_over = (result == "loss")
        end
]]

-- Victory condition types
VictoryCondition.VICTORY_TYPES = {
    threshold = "threshold",           -- Reach target value (kills, dodges, matches, etc)
    time_survival = "time_survival",   -- Survive until time expires
    time_limit = "time_limit",         -- Complete before time expires (auto-loss if exceeded)
    streak = "streak",                 -- Consecutive successes
    ratio = "ratio",                   -- Maintain accuracy percentage
    clear_all = "clear_all",           -- Eliminate all targets (remaining == 0)
    endless = "endless",               -- Never completes (survival mode)
    rounds = "rounds",                 -- Win X rounds (for turn-based games)
    multi = "multi"                    -- Multiple victory conditions (OR logic)
}

-- Loss condition types
VictoryCondition.LOSS_TYPES = {
    lives_depleted = "lives_depleted", -- Lives/health reach 0
    time_expired = "time_expired",     -- Countdown reaches 0
    move_limit = "move_limit",         -- Attempts exhausted
    death_event = "death_event",       -- Instant failure flag
    threshold = "threshold",           -- Enemy/opponent reaches target
    penalty = "penalty",               -- Special failure condition flag
    none = "none"                      -- No loss condition (endless mode)
}

function VictoryCondition:new(config)
    local instance = VictoryCondition.super.new(self)

    -- Victory configuration
    instance.victory = config.victory or {}
    instance.victory.type = instance.victory.type or "threshold"

    -- Loss configuration
    instance.loss = config.loss or {}
    instance.loss.type = instance.loss.type or "lives_depleted"

    -- Check priority (which to check first)
    instance.check_loss_first = config.check_loss_first ~= false  -- Default true

    -- Multi-victory configs (for games with multiple win paths)
    instance.multi_victory = config.multi_victory or nil

    -- Victory bonuses (applied when victory is achieved)
    instance.bonuses = config.bonuses or {}

    -- Game reference (set after creation)
    instance.game = nil

    return instance
end

-- Main check function - returns "victory", "loss", or nil
function VictoryCondition:check()
    if not self.game then
        error("VictoryCondition:check() requires self.game to be set. Call victory_condition.game = self in game init.")
    end

    -- Check in priority order
    if self.check_loss_first then
        local loss = self:checkLoss()
        if loss then return "loss" end

        local victory = self:checkVictory()
        if victory then
            self:applyBonuses()
            return "victory"
        end
    else
        local victory = self:checkVictory()
        if victory then
            self:applyBonuses()
            return "victory"
        end

        local loss = self:checkLoss()
        if loss then return "loss" end
    end

    return nil
end

-- Apply victory bonuses
function VictoryCondition:applyBonuses()
    if not self.bonuses or #self.bonuses == 0 then return end

    for _, bonus in ipairs(self.bonuses) do
        if bonus.condition and bonus.apply then
            if bonus.condition(self.game) then
                bonus.apply(self.game)
            end
        end
    end
end

-- Check victory conditions
function VictoryCondition:checkVictory()
    local config = self.victory
    local game = self.game

    -- Handle multi-victory (OR logic - any condition triggers victory)
    if config.type == "multi" and self.multi_victory then
        for _, sub_config in ipairs(self.multi_victory) do
            if self:checkSingleVictory(sub_config) then
                return true
            end
        end
        return false
    end

    return self:checkSingleVictory(config)
end

-- Check a single victory condition
function VictoryCondition:checkSingleVictory(config)
    local game = self.game
    local v_type = config.type

    if v_type == "threshold" then
        -- Reach target value: dodges >= 50, kills >= 20, etc
        local value = self:getValue(config.metric)
        local target = config.target or 0
        return value >= target

    elseif v_type == "time_survival" then
        -- Survive until time expires
        local elapsed = self:getValue(config.metric or "time_elapsed")
        local target = config.target or 0
        return elapsed >= target

    elseif v_type == "time_limit" then
        -- Must complete before time expires (checked in loss condition)
        -- This victory type just checks if objective completed
        local value = self:getValue(config.metric)
        local target = config.target or 0
        return value >= target

    elseif v_type == "streak" then
        -- Consecutive successes
        local value = self:getValue(config.metric)
        local target = config.target or 0
        return value >= target

    elseif v_type == "ratio" then
        -- Maintain accuracy percentage
        local numerator = self:getValue(config.numerator)
        local denominator = self:getValue(config.denominator)
        if denominator == 0 then return false end

        local ratio = numerator / denominator
        local target = config.target or 0
        return ratio >= target

    elseif v_type == "clear_all" then
        -- Eliminate all targets (remaining == 0)
        local remaining = self:getValue(config.metric)
        return remaining <= 0

    elseif v_type == "rounds" then
        -- Win X rounds (turn-based games)
        local wins = self:getValue(config.metric)
        local target = config.target or 0
        return wins >= target

    elseif v_type == "endless" then
        -- Never completes
        return false
    end

    return false
end

-- Check loss conditions
function VictoryCondition:checkLoss()
    local config = self.loss
    local game = self.game
    local l_type = config.type

    if l_type == "none" then
        return false

    elseif l_type == "lives_depleted" then
        -- Lives/health reach 0
        local lives = self:getValue(config.metric or "lives")
        return lives <= 0

    elseif l_type == "time_expired" then
        -- Countdown reaches 0
        local time_remaining = self:getValue(config.metric or "time_remaining")
        return time_remaining <= 0

    elseif l_type == "move_limit" then
        -- Attempts exhausted
        local moves = self:getValue(config.moves_metric or "moves_made")
        local limit = self:getValue(config.limit_metric or "move_limit")
        return moves >= limit and limit > 0

    elseif l_type == "death_event" then
        -- Instant failure flag (collision, game_over flag, etc)
        local flag = self:getValue(config.flag or "game_over")
        return flag == true

    elseif l_type == "threshold" then
        -- Enemy/opponent reaches target first
        local value = self:getValue(config.metric)
        local target = config.target or 0
        return value >= target

    elseif l_type == "penalty" then
        -- Special failure condition flag
        local flag = self:getValue(config.flag or "is_failed")
        return flag == true
    end

    return false
end

-- Get progress toward victory (0 = just started, 1 = complete)
-- Returns nil if victory type doesn't support progress tracking
function VictoryCondition:getProgress()
    if not self.game then return nil end

    local config = self.victory
    local v_type = config.type

    if v_type == "threshold" then
        local value = self:getValue(config.metric)
        local target = config.target or 1
        if target <= 0 then return 1 end
        return math.min(1, value / target)

    elseif v_type == "time_survival" then
        local elapsed = self:getValue(config.metric or "time_elapsed")
        local target = config.target or 1
        if target <= 0 then return 1 end
        return math.min(1, elapsed / target)

    elseif v_type == "clear_all" then
        -- Need both current and initial to calculate progress
        local remaining = self:getValue(config.metric)
        local initial = self:getValue(config.initial_metric or config.metric .. "_initial")
        if initial <= 0 then return remaining <= 0 and 1 or 0 end
        return math.min(1, 1 - (remaining / initial))

    elseif v_type == "streak" or v_type == "rounds" then
        local value = self:getValue(config.metric)
        local target = config.target or 1
        if target <= 0 then return 1 end
        return math.min(1, value / target)

    elseif v_type == "endless" then
        return 0  -- Never completes
    end

    return nil  -- Unknown type
end

-- Get value from game state (supports nested keys like "metrics.kills")
function VictoryCondition:getValue(key)
    if not key or not self.game then return 0 end

    -- Handle direct values (for constants)
    if type(key) == "number" then
        return key
    end

    -- Split nested keys
    local keys = {}
    for k in string.gmatch(key, "[^%.]+") do
        table.insert(keys, k)
    end

    -- Navigate to value
    local value = self.game
    for _, k in ipairs(keys) do
        if type(value) == "table" then
            value = value[k]
        else
            return 0
        end
    end

    -- Return numeric value or 0
    if type(value) == "number" then
        return value
    elseif type(value) == "boolean" then
        return value and 1 or 0
    else
        return 0
    end
end

return VictoryCondition
