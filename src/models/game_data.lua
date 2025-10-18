local Object = require('class')
local json = require('json')
local Config = require('src.config') -- Moved require to file scope
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

function GameData:init()
    self.games = {}
    self:loadBaseGames()
end

function GameData:loadBaseGames()
    local file_path = "assets/data/base_game_definitions.json"
    local read_ok, contents = pcall(love.filesystem.read, file_path)

    if not read_ok or not contents then
        print("ERROR: Could not read " .. file_path .. " - " .. tostring(contents))
        self.games = {} -- Fallback: no games loaded
        return
    end

    local decode_ok, base_games = pcall(json.decode, contents)

    if not decode_ok then
        print("ERROR: Failed to decode " .. file_path .. " - " .. tostring(base_games))
        self.games = {} -- Fallback: no games loaded
        return
    end

    local multipliers = Config.clone_multipliers

    for _, base_game_data in ipairs(base_games) do
        -- Validate required fields before processing
        if base_game_data.id and base_game_data.game_class and base_game_data.base_formula_string then
           self:registerGame(base_game_data)
           -- Generate clones (still hardcoding 40 clones for MVP scope)
           self:generateClones(base_game_data, 40, multipliers)
        else
            print("Warning: Skipping invalid base game entry in JSON (missing id, game_class, or base_formula_string): ", json.encode(base_game_data))
        end
    end

    -- Count actual games loaded
    local count = 0
    for _ in pairs(self.games) do count = count + 1 end
    print("Loaded " .. count .. " games and variants.")
end


function GameData:createFormulaFunction(formula_string)
    if not formula_string or formula_string == "" then
        print("Warning: Empty or nil formula string provided.")
        return function(metrics) return 0 end
    end

    -- Construct the function string - ensure it returns the value
    local func_body_string = "local metrics = ...; metrics = metrics or {}; local value = (" .. formula_string .. "); return value"
    
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
        
        -- Execute the loaded chunk safely using pcall
        local call_ok, result = pcall(formula_chunk, metrics) 

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

function GameData:generateClones(base_game, count, multipliers)
    for i = 1, count do
        local variant_num = i + 1
        local multiplier = multipliers[math.min(#multipliers, i)] or multipliers[#multipliers]
        local difficulty_level = math.max(1, math.floor(i / Config.clone_difficulty_step) + 1)

        local cost = math.floor(base_game.unlock_cost * math.pow(multiplier, Config.clone_cost_exponent))

        local clone = {}
        for k, v in pairs(base_game) do clone[k] = v end

        clone.id = base_game.id:gsub("_1$", "_" .. variant_num)
        if clone.id == base_game.id then clone.id = base_game.id .. "_" .. variant_num end
        clone.display_name = base_game.display_name:gsub(" 1$", " " .. variant_num)
         if clone.display_name == base_game.display_name then clone.display_name = base_game.display_name .. " " .. variant_num end

        clone.unlock_cost = cost
        clone.variant_of = base_game.id
        clone.variant_multiplier = multiplier
        clone.difficulty_level = difficulty_level
        clone.auto_play_performance = self:scaleAutoPlayPerformance(
            base_game.auto_play_performance,
            difficulty_level
        )
        clone.difficulty_modifiers = nil -- Regenerated by registerGame

        -- Crucially pass the already created base_formula function to the clone
        clone.base_formula = base_game.base_formula 

        self:registerGame(clone)
    end
end


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
    return game.formula_function(metrics)
end

function GameData:calculateTokenRate(game_id, metrics)
    -- Token rate is the same as power
    return self:calculatePower(game_id, metrics)
end

return GameData