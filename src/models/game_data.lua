local Object = require('class')
local json = require('json')
local Paths = require('src.paths')
local Config = rawget(_G, 'DI_CONFIG') or {}
local GameRegistry = require('src.models.game_registry')
local GameData = Object:extend('GameData')

-- Constants for game categories and tiers
GameData.CATEGORY = {
    ACTION = "action",
    PUZZLE = "puzzle",
    SPORTS = "sports",
    ARCADE = "arcade"
}

GameData.TIER = {
    TRASH = "trash",
    MID = "mid",
    PREMIUM = "premium"
}

function GameData:init(di)
    -- Optional DI for config
    if di and di.config then Config = di.config end
    self.games = {}
    self.game_registry = GameRegistry:new(Config)
    self:loadBaseGames()
end

function GameData:loadBaseGames()
    -- Get all games from GameRegistry (auto-discovered from variant files)
    -- GameRegistry already merges config.game_defaults → file_data → variant
    local discovered_games = self.game_registry:getAllGames()

    -- Register each discovered game (already fully merged by GameRegistry)
    for _, discovered_game in ipairs(discovered_games) do
        -- Calculate variant multiplier from clone_index
        -- clone_index 0 & 1 = multiplier 1, clone_index 2 = multiplier 2, etc.
        -- (matches old system where base and first clone both had multiplier 1)
        discovered_game.variant_multiplier = math.max(1, discovered_game.clone_index or 0)

        -- Map variant "name" to "display_name" for UI compatibility
        -- Variant name always overrides base display_name
        if discovered_game.name then
            discovered_game.display_name = discovered_game.name
        end

        -- Register the game (creates formula functions, difficulty modifiers, etc.)
        self:registerGame(discovered_game)
    end

    -- Count actual games loaded
    local count = 0
    for _ in pairs(self.games) do count = count + 1 end
    print("[GameData] Loaded " .. count .. " games and variants using GameRegistry.")
end

-- loadStandaloneVariantCounts() - DELETED (Phase 3: replaced by GameRegistry)

function GameData:createFormulaFunction(formula_string)
    if not formula_string or formula_string == "" then
        print("Warning: Empty or nil formula string provided.")
        return function(metrics) return 0 end
    end

    -- Inject scaling_constant into the formula environment
    local scaling_constant = Config.scaling_constant or 1
    local func_body_string = "local metrics, scaling_constant = ...; metrics = metrics or {}; local value = (" .. formula_string .. "); return value"
    
    -- 1. Load the string into a reusable chunk. 
    -- Provide a name for better error messages.
    local formula_chunk, load_err = loadstring(func_body_string, "Formula:" .. formula_string)

    if not formula_chunk then
        print("ERROR loading formula string: '" .. formula_string .. "' - " .. tostring(load_err))
        return function(metrics)
            print("Error: Invalid formula definition (load failed): " .. formula_string)
            return 0
        end
    end

    -- 2. Return a wrapper that safely executes the chunk with provided metrics
    return function(metrics)
        metrics = metrics or {} -- Ensure metrics table exists

        -- Explicitly default expected metrics to 0 *if nil* before calling the chunk
        -- This prevents errors if auto_metrics or runtime metrics are incomplete.
        -- Add ALL possible metrics used across your formulas here.
        metrics.kills = metrics.kills or 0
        metrics.deaths = metrics.deaths or 0
        metrics.snake_length = metrics.snake_length or 0
        metrics.survival_time = metrics.survival_time or 0
        metrics.matches = metrics.matches or 0
        metrics.time = metrics.time or 0
        metrics.perfect = metrics.perfect or 0
        metrics.objects_dodged = metrics.objects_dodged or 0
        metrics.collisions = metrics.collisions or 0
        metrics.perfect_dodges = metrics.perfect_dodges or 0
        metrics.objects_found = metrics.objects_found or 0
        metrics.time_bonus = metrics.time_bonus or 0
        metrics.combo = metrics.combo or 0

        -- Get current scaling_constant from config
        local scaling_constant = Config.scaling_constant or 1

        -- Execute the loaded chunk safely using pcall, passing both metrics and scaling_constant
        local call_ok, result = pcall(formula_chunk, metrics, scaling_constant) 

        if not call_ok then
            -- Error during execution (e.g., division by zero if not handled in formula string)
            print("ERROR executing formula '" .. formula_string .. "' with metrics " .. json.encode(metrics) .. ": " .. tostring(result))
            return 0 
        end

        -- Validate result is a usable number
        if type(result) == 'number' and result == result and result >= -math.huge and result <= math.huge then
             return result
        else
             -- Formula executed but returned nil, NaN, inf, etc.
             -- print("Warning: Formula '" .. formula_string .. "' resulted in non-numeric or invalid value: " .. tostring(result))
             return 0 -- Default to 0
        end
    end
end


function GameData:registerGame(game_data)
    -- Ensure essential fields exist
    if not game_data.id or not game_data.game_class or not game_data.base_formula_string or not game_data.variant_multiplier then
        print("ERROR: Cannot register game, missing essential data: ", json.encode(game_data))
        return
    end

    -- 1. Create base formula func (if not already done - e.g., for base game)
    if not game_data.base_formula then
        game_data.base_formula = self:createFormulaFunction(game_data.base_formula_string)
    end

    -- 2. Create final formula string
    game_data.formula_string = game_data.base_formula_string .. " × " .. game_data.variant_multiplier

    -- 3. Create final formula function
    game_data.formula_function = function(metrics)
        local call_ok, base_result = pcall(game_data.base_formula, metrics)
        if not call_ok then
            -- Error already printed by createFormulaFunction's wrapper
            return 0
        end
        return base_result * game_data.variant_multiplier
    end

    -- 4. Calculate difficulty modifiers if not explicitly set (e.g., for clones)
    if not game_data.difficulty_modifiers then
        local dl = game_data.difficulty_level or 1
        game_data.difficulty_modifiers = {
            speed = 1 + (dl * 0.15),
            count = 1 + (dl * 0.25),
            complexity = dl,
            time_limit = math.max(0.5, 1 - (dl * 0.08))
        }
    end

    -- 5. Add/overwrite in the main games table
    self.games[game_data.id] = game_data
end

-- generateClones() - DELETED (Phase 3: replaced by GameRegistry auto-discovery)

function GameData:scaleAutoPlayPerformance(base_performance, difficulty_level)
    local scaling = Config.auto_play_scaling
    local scaled = {}

    for metric, value in pairs(base_performance) do
        local scaled_value = value -- Default to base value
        if metric == "kills" or metric == "objects_dodged" or metric == "snake_length" or metric == "objects_found" or metric == "matches" then
            scaled_value = math.max(1, math.floor(value * (1 - (difficulty_level * scaling.performance_reduction_factor))))
        elseif metric == "deaths" or metric == "collisions" then
            scaled_value = math.max(0, math.ceil(value * (1 + (difficulty_level * scaling.penalty_increase_factor)))) -- Allow 0 deaths/collisions
        elseif metric == "time" or metric == "survival_time" then
            scaled_value = math.max(1, value * (1 - (difficulty_level * scaling.time_penalty_factor)))
        elseif metric == "perfect_dodges" or metric == "perfect" then
             scaled_value = math.max(0, math.floor(value * (1 - (difficulty_level * scaling.bonus_reduction_factor))))
        elseif metric == "time_bonus" then
            scaled_value = math.max(0, math.floor(value * (1 - (difficulty_level * scaling.bonus_reduction_factor)))) -- Apply bonus reduction here too
        else
            scaled_value = value * (1 - (difficulty_level * 0.05))
        end
         -- Ensure non-negative values where appropriate, except maybe time bonus if formulas allow negatives?
         if type(scaled_value) == 'number' and scaled_value < 0 and metric ~= "time_bonus" then
             scaled_value = 0
         end
         scaled[metric] = scaled_value
    end
    return scaled
end


function GameData:getGame(game_id)
    return self.games[game_id]
end

function GameData:getAllGames()
    local all_games = {}
    for _, game in pairs(self.games) do
        table.insert(all_games, game)
    end
    -- Sort here? Or rely on initial load order + clones appended? Let's sort for consistency.
    table.sort(all_games, function(a,b) return a.id < b.id end)
    return all_games
end

function GameData:getGamesByCategory(category)
    local filtered = {}
    for _, game in pairs(self.games) do
        if game.category == category then
            table.insert(filtered, game)
        end
    end
     table.sort(filtered, function(a,b) return a.id < b.id end)
    return filtered
end

function GameData:getGamesByTier(tier)
    local filtered = {}
    for _, game in pairs(self.games) do
        if game.tier == tier then
            table.insert(filtered, game)
        end
    end
     table.sort(filtered, function(a,b) return a.id < b.id end)
    return filtered
end

function GameData:calculatePower(game_id, metrics)
    local game = self:getGame(game_id)
    if not game or not game.formula_function then
        print("Warning: calculatePower called for unknown game_id or game has no formula: " .. tostring(game_id))
        return 0
    end
    -- The formula_function now includes pcall and type checking
    return game.formula_function(metrics, Config.scaling_constant or 1)
end

function GameData:calculateTokenRate(game_id, metrics)
    -- Token rate is the same as power
    return self:calculatePower(game_id, metrics)
end

-- DEBUG HELPER: Calculate theoretical maximum formula output for balance testing
-- This uses ACTUAL game victory conditions from variant data, not arbitrary assumptions
function GameData:calculateTheoreticalMax(game_id)
    local game = self:getGame(game_id)
    if not game or not game.formula_function then
        return 0
    end

    -- Parse game_id to get base type and variant number
    local base_id, variant_num = game_id:match("^(.+)_(%d+)$")
    local clone_index = variant_num and (tonumber(variant_num) - 1) or 0

    -- Try to load variant-specific data from JSON
    local variant = nil
    if base_id then
        -- Use full base_id (e.g., "space_shooter") not just first word
        local variant_file = Paths.assets.data .. "variants/" .. base_id .. "_variants.json"
        local read_ok, contents = pcall(love.filesystem.read, variant_file)
        if read_ok and contents then
            local decode_ok, variants = pcall(json.decode, contents)
            if decode_ok and variants then
                for _, v in ipairs(variants) do
                    if v.clone_index == clone_index then
                        variant = v
                        break
                    end
                end
            end
        end
    end

    -- Define theoretical max values based on actual game parameters
    local max_metrics = {}

    -- Dodge games: use victory_limit (default 30 dodges), perfect = 0 collisions, max combo
    if game.metrics_tracked and game.metrics_tracked[1] == "objects_dodged" then
        local victory_limit = (variant and variant.victory_limit) or 30
        max_metrics.objects_dodged = victory_limit
        max_metrics.collisions = 0
        max_metrics.combo = victory_limit -- Perfect combo = all dodges in a row

    -- Snake games: use victory_limit for length, estimate survival time
    elseif game.metrics_tracked and game.metrics_tracked[1] == "snake_length" then
        local victory_limit = (variant and variant.victory_limit) or 20
        -- Estimate survival time: ~2.5 seconds per food eaten (based on real play data)
        local estimated_time = victory_limit * 2.5
        max_metrics.snake_length = victory_limit
        max_metrics.survival_time = estimated_time

    -- Memory Match: pairs = card_count/2, estimate optimal completion time
    elseif game.metrics_tracked and game.metrics_tracked[1] == "matches" then
        local card_count = (variant and variant.card_count) or 12
        local pairs = card_count / 2
        -- Estimate time: ~2.5 seconds per pair (based on real perfect play data)
        local estimated_time = pairs * 2.5
        max_metrics.matches = pairs
        max_metrics.time = estimated_time
        max_metrics.combo = pairs -- Maximum combo = all pairs matched in a row

    -- Hidden Object: assume finding all objects
    elseif game.metrics_tracked and game.metrics_tracked[1] == "objects_found" then
        max_metrics.objects_found = 20 -- Typical object count
        max_metrics.time = 60 -- 1 minute for perfect play
        max_metrics.perfect = 1

    -- Space Shooter: estimate based on victory_limit
    elseif game.metrics_tracked and game.metrics_tracked[1] == "kills" then
        local victory_limit = (variant and variant.victory_limit) or 20
        max_metrics.kills = victory_limit
        max_metrics.deaths = 0
        max_metrics.combo = victory_limit -- Perfect combo = all kills without death

    -- Fallback for unknown games
    else
        if game.metrics_tracked then
            for _, metric in ipairs(game.metrics_tracked) do
                -- Bad metrics (minimize)
                if metric == "collisions" or metric == "deaths" or metric == "mistakes" then
                    max_metrics[metric] = 0
                -- Time metric (tricky - depends on formula)
                elseif metric == "time" then
                    max_metrics[metric] = 30
                -- Perfect flag
                elseif metric == "perfect" then
                    max_metrics[metric] = 1
                -- Good metrics (maximize with conservative estimates)
                else
                    max_metrics[metric] = 50
                end
            end
        end
    end

    -- Calculate formula output with realistic max metrics
    return game.formula_function(max_metrics, Config.scaling_constant or 1)
end

return GameData