-- src/models/player_data.lua
local Object = require('class')
local Config = rawget(_G, 'DI_CONFIG') or {}
-- Removed global assumption

local PlayerData = Object:extend('PlayerData')

-- Accept statistics instance and di
function PlayerData:init(statistics_instance, di)
    -- Optional DI for config (fallback to module require)
    if di and di.config then Config = di.config end
    self.statistics = statistics_instance -- Store injected instance
    self.event_bus = di and di.eventBus -- Store injected event bus

    self.tokens = Config.start_tokens or 500
    self.unlocked_games = {}
    self.completed_games = {}
    self.game_performance = {}
    self.space_defender_level = 1
    self.vm_slots = 0  -- Start with 0 VMs, must purchase first one
    self.active_vms = {}

    -- CheatEngine budget (global across all games)
    self.cheat_budget = (Config.cheat_engine and Config.cheat_engine.default_budget) or 999999999

    -- CheatEngine data structure (new system):
    -- {
    --   [game_id] = {
    --     budget_spent = 0,
    --     modifications = {
    --       [param_key] = { original = value, modified = value, cost_spent = number }
    --     }
    --   }
    -- }
    -- Legacy data (old cheat system) also stored here for compatibility
    self.cheat_engine_data = {}

    self.upgrades = { cpu_speed=0, overclock=0, auto_dodge=0 }

    -- Demo system: stores all recorded demos
    -- {
    --   [demo_id] = {
    --     game_id = "dodge_1",
    --     variant_config = { ... },
    --     recording = { inputs = [...], total_frames = N, fixed_dt = 0.016666, recorded_at = "..." },
    --     metadata = { demo_name = "...", description = "...", version = 1 }
    --   }
    -- }
    self.demos = {}
end

function PlayerData:addTokens(amount)
    if type(amount) ~= "number" or amount <= 0 then return self.tokens end -- Only add positive amounts
    local old_tokens = self.tokens
    -- Round to integer for readability
    self.tokens = math.floor(self.tokens + amount)
    local new_tokens = self.tokens
    local delta = math.floor(amount)

    -- Update statistics using self.statistics
    if self.statistics and self.statistics.addTokensEarned then
        self.statistics:addTokensEarned(amount)
        -- print("Debug PlayerData: Called addTokensEarned") -- Optional debug
    else
        -- print("Debug PlayerData: Statistics object not found in addTokens") -- Optional debug
    end

    -- Publish tokens_changed event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'tokens_changed', old_tokens, new_tokens, delta)
    end

    return self.tokens
end

function PlayerData:spendTokens(amount)
    if type(amount) ~= "number" or amount <= 0 then return false end
    if not self:hasTokens(amount) then return false end
    local old_tokens = self.tokens
    self.tokens = self.tokens - amount
    local new_tokens = self.tokens
    local delta = -amount

    -- Publish tokens_changed event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'tokens_changed', old_tokens, new_tokens, delta)
    end

    return true
end

-- ... (rest of the file remains the same) ...

function PlayerData:hasTokens(amount)
    if type(amount) ~= "number" or amount < 0 then return false end
    return self.tokens >= amount
end

function PlayerData:unlockGame(game_id)
    if not self.unlocked_games[game_id] then
        local old_value = self.unlocked_games[game_id] -- will be nil
        self.unlocked_games[game_id] = true
        -- Update statistics using self.statistics
        if self.statistics and self.statistics.incrementGamesUnlocked then
             self.statistics:incrementGamesUnlocked()
             -- print("Debug PlayerData: Called incrementGamesUnlocked") -- Optional debug
        else
            -- print("Debug PlayerData: Statistics object not found in unlockGame") -- Optional debug
        end
        -- NOTE: Could publish player_data_changed here, but relying on save_completed for now
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
             -- NOTE: Could publish player_data_changed here
        end
    else
        if not record.best_score or record.best_score == 0 or (formula_result > record.best_score and record.auto_completed) then
             record.metrics = metrics or {}
             record.best_score = formula_result
             record.auto_completed = true
             is_new_best = true
             self.completed_games[game_id] = true
             -- NOTE: Could publish player_data_changed here
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
        local old_level = self.space_defender_level
        self.space_defender_level = level + 1
        print("Unlocked Space Defender Level: " .. self.space_defender_level)
        -- NOTE: Could publish player_data_changed here
        return true
    end
    return false
end

function PlayerData:purchaseVM()
    print("Warning: PlayerData:purchaseVM() is deprecated. Use VMManager:purchaseVM().")
    return false
end

function PlayerData:purchaseUpgrade(type)
    local base_costs = (Config and Config.upgrade_costs) or {}
    if not base_costs[type] then
        print("Error: Unknown upgrade type '" .. type .. "'")
        return false
    end

    local current_level = self.upgrades[type] or 0
    local cost = base_costs[type] * (current_level + 1)

    -- Temporarily store old value before spending tokens might trigger event
    local old_upgrades = {}
    for k, v in pairs(self.upgrades) do old_upgrades[k] = v end

    if self:spendTokens(cost) then -- This will publish tokens_changed
        self.upgrades[type] = current_level + 1
        print("Purchased upgrade: " .. type .. " level " .. self.upgrades[type] .. " for " .. cost .. " tokens")
        -- NOTE: Could publish player_data_changed here for upgrades
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
        -- NOTE: Could publish player_data_changed here
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
    -- NOTE: Could publish player_data_changed here
end

function PlayerData:getCheatLevel(game_id, cheat_id)
    self.cheat_engine_data = self.cheat_engine_data or {}
    if not self.cheat_engine_data[game_id] or not self.cheat_engine_data[game_id].cheats then
        return 0
    end
    return self.cheat_engine_data[game_id].cheats[cheat_id] or 0
end

-- === Demo Management Functions ===

-- Save a demo (returns demo_id)
function PlayerData:saveDemo(demo)
    if not demo or not demo.game_id or not demo.recording then
        print("Error: Invalid demo data")
        return nil
    end

    -- Generate unique demo ID
    local demo_id = "demo_" .. demo.game_id .. "_" .. os.time()

    -- Store demo
    self.demos = self.demos or {}
    self.demos[demo_id] = demo

    -- Emit event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'demo_saved', demo_id, demo)
    end

    print("Saved demo: " .. demo_id .. " (" .. demo.metadata.demo_name .. ")")
    return demo_id
end

-- Get a specific demo
function PlayerData:getDemo(demo_id)
    self.demos = self.demos or {}
    return self.demos[demo_id]
end

-- Get all demos for a specific game
function PlayerData:getDemosForGame(game_id)
    self.demos = self.demos or {}
    local game_demos = {}

    for demo_id, demo in pairs(self.demos) do
        if demo.game_id == game_id then
            table.insert(game_demos, {
                demo_id = demo_id,
                demo = demo
            })
        end
    end

    -- Sort by recorded_at (most recent first)
    table.sort(game_demos, function(a, b)
        return (a.demo.recording.recorded_at or "") > (b.demo.recording.recorded_at or "")
    end)

    return game_demos
end

-- Get all demos
function PlayerData:getAllDemos()
    self.demos = self.demos or {}
    local all_demos = {}

    for demo_id, demo in pairs(self.demos) do
        table.insert(all_demos, {
            demo_id = demo_id,
            demo = demo
        })
    end

    -- Sort by recorded_at (most recent first)
    table.sort(all_demos, function(a, b)
        return (a.demo.recording.recorded_at or "") > (b.demo.recording.recorded_at or "")
    end)

    return all_demos
end

-- Delete a demo
function PlayerData:deleteDemo(demo_id)
    self.demos = self.demos or {}

    if not self.demos[demo_id] then
        print("Warning: Demo not found: " .. demo_id)
        return false
    end

    local demo = self.demos[demo_id]
    self.demos[demo_id] = nil

    -- Emit event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'demo_deleted', demo_id, demo.game_id)
    end

    print("Deleted demo: " .. demo_id)
    return true
end

-- Rename a demo
function PlayerData:renameDemo(demo_id, new_name)
    self.demos = self.demos or {}

    if not self.demos[demo_id] then
        print("Warning: Demo not found: " .. demo_id)
        return false
    end

    self.demos[demo_id].metadata.demo_name = new_name
    print("Renamed demo " .. demo_id .. " to: " .. new_name)
    return true
end

-- Update demo description
function PlayerData:updateDemoDescription(demo_id, new_description)
    self.demos = self.demos or {}

    if not self.demos[demo_id] then
        print("Warning: Demo not found: " .. demo_id)
        return false
    end

    self.demos[demo_id].metadata.description = new_description
    return true
end

-- Check if demo exists
function PlayerData:hasDemo(demo_id)
    self.demos = self.demos or {}
    return self.demos[demo_id] ~= nil
end

-- ============================================================================
-- NEW: Dynamic Parameter Modification System (CheatEngine)
-- ============================================================================

-- Get the global cheat budget
function PlayerData:getCheatBudget()
    return self.cheat_budget or 999999999
end

-- Set the global cheat budget (used for upgrades)
function PlayerData:setCheatBudget(new_budget)
    self.cheat_budget = new_budget
end

-- Get current CPU speed multiplier (used for page loading, etc.)
function PlayerData:getCPUSpeed()
    local cpu_level = self.upgrades.cpu_speed or 0
    local base_speed = Config.cpu and Config.cpu.starting_speed or 0.3
    local speed_per_level = Config.cpu and Config.cpu.speed_per_upgrade or 0.5
    local max_speed = Config.cpu and Config.cpu.max_speed or 10.0

    local cpu_speed = base_speed + (cpu_level * speed_per_level)
    return math.min(cpu_speed, max_speed)
end

-- Initialize cheat data for a game (new system structure)
function PlayerData:initGameCheatData(game_id)
    if not self.cheat_engine_data[game_id] then
        self.cheat_engine_data[game_id] = {
            budget_spent = 0,
            modifications = {}
        }
    end
    -- Ensure modifications table exists
    if not self.cheat_engine_data[game_id].modifications then
        self.cheat_engine_data[game_id].modifications = {}
    end
    -- Ensure budget_spent exists
    if not self.cheat_engine_data[game_id].budget_spent then
        self.cheat_engine_data[game_id].budget_spent = 0
    end
end

-- Get all modifications for a specific game
-- Returns: { [param_key] = { original = value, modified = value, cost_spent = number }, ... }
function PlayerData:getGameModifications(game_id)
    if not self.cheat_engine_data[game_id] then
        return {}
    end
    return self.cheat_engine_data[game_id].modifications or {}
end

-- Get total budget spent on a specific game
function PlayerData:getGameBudgetSpent(game_id)
    if not self.cheat_engine_data[game_id] then
        return 0
    end
    return self.cheat_engine_data[game_id].budget_spent or 0
end

-- Get available budget for a specific game
-- (This is global budget minus budget spent on THIS game)
function PlayerData:getAvailableBudget(game_id)
    local spent = self:getGameBudgetSpent(game_id)
    return self.cheat_budget - spent
end

-- Apply a modification to a game parameter
-- Returns: true if successful, false otherwise
function PlayerData:applyCheatModification(game_id, param_key, original_value, new_value, cost)
    self:initGameCheatData(game_id)

    local game_data = self.cheat_engine_data[game_id]

    -- Check if we're updating an existing modification
    local old_cost = 0
    if game_data.modifications[param_key] then
        old_cost = game_data.modifications[param_key].cost_spent or 0
    end

    -- Store modification
    game_data.modifications[param_key] = {
        original = original_value,
        modified = new_value,
        cost_spent = cost
    }

    -- Update total budget spent for this game
    -- Remove old cost, add new cost
    game_data.budget_spent = (game_data.budget_spent or 0) - old_cost + cost

    return true
end

-- Remove a modification from a game parameter
-- Returns: refund amount
function PlayerData:removeCheatModification(game_id, param_key)
    if not self.cheat_engine_data[game_id] then
        return 0
    end

    local game_data = self.cheat_engine_data[game_id]
    local mod = game_data.modifications[param_key]

    if not mod then
        return 0
    end

    local refund = mod.cost_spent or 0

    -- Apply refund percentage from config
    local refund_config = Config.cheat_engine and Config.cheat_engine.refund
    if refund_config then
        local percentage = refund_config.percentage or 100
        local min_refund = refund_config.min_refund or 0
        refund = math.max(min_refund, math.floor(refund * (percentage / 100)))
    end

    -- Remove modification
    game_data.modifications[param_key] = nil

    -- Update budget spent
    game_data.budget_spent = (game_data.budget_spent or 0) - refund
    if game_data.budget_spent < 0 then
        game_data.budget_spent = 0
    end

    return refund
end

-- Reset all modifications for a game
-- Returns: total refund amount
function PlayerData:resetAllGameModifications(game_id)
    if not self.cheat_engine_data[game_id] then
        return 0
    end

    local game_data = self.cheat_engine_data[game_id]
    local total_refund = 0

    -- Calculate total refund
    for param_key, mod in pairs(game_data.modifications or {}) do
        total_refund = total_refund + (mod.cost_spent or 0)
    end

    -- Apply refund percentage from config
    local refund_config = Config.cheat_engine and Config.cheat_engine.refund
    if refund_config then
        local percentage = refund_config.percentage or 100
        local min_refund = refund_config.min_refund or 0
        total_refund = math.max(min_refund, math.floor(total_refund * (percentage / 100)))
    end

    -- Clear all modifications
    game_data.modifications = {}
    game_data.budget_spent = 0

    return total_refund
end

-- Check if a game has any modifications
function PlayerData:hasGameModifications(game_id)
    if not self.cheat_engine_data[game_id] then
        return false
    end

    local mods = self.cheat_engine_data[game_id].modifications or {}
    for _ in pairs(mods) do
        return true  -- Has at least one modification
    end
    return false
end

-- Get count of modifications for a game
function PlayerData:getGameModificationCount(game_id)
    if not self.cheat_engine_data[game_id] then
        return 0
    end

    local count = 0
    local mods = self.cheat_engine_data[game_id].modifications or {}
    for _ in pairs(mods) do
        count = count + 1
    end
    return count
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
        cheat_budget = self.cheat_budget,  -- NEW: Save cheat budget
        cheat_engine_data = self.cheat_engine_data,  -- Contains both old and new cheat data
        upgrades = self.upgrades,
        demos = self.demos or {}  -- Demo recordings
    }
end


return PlayerData