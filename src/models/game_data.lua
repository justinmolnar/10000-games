local Object = require('class')
local json = require('json')
local Paths = require('src.paths')
local Config = rawget(_G, 'DI_CONFIG') or {}
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
    self:loadBaseGames()
end

function GameData:loadBaseGames()
    local file_path = Paths.assets.data .. "base_game_definitions.json"
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

    -- Load standalone variant counts (e.g., dodge_variants.json)
    local standalone_variant_counts = self:loadStandaloneVariantCounts()

    for _, base_game_data in ipairs(base_games) do
        -- Validate required fields before processing
        if base_game_data.id and base_game_data.game_class and base_game_data.base_formula_string then
           self:registerGame(base_game_data)

           -- Determine number of clones to generate
           -- Use standalone variant count if available, otherwise default to 2
           local clone_count = standalone_variant_counts[base_game_data.id] or 2

           self:generateClones(base_game_data, clone_count, multipliers)
        else
            print("Warning: Skipping invalid base game entry in JSON (missing id, game_class, or base_formula_string): ", json.encode(base_game_data))
        end
    end

    -- Count actual games loaded
    local count = 0
    for _ in pairs(self.games) do count = count + 1 end
    print("Loaded " .. count .. " games and variants.")
end

function GameData:loadStandaloneVariantCounts()
    -- Scan the variants directory and count variants for each game
    -- Returns a table mapping base_game_id to variant count
    -- e.g., { ["dodge_1"] = 52, ["snake_1"] = 30 }

    local variant_counts = {}
    local variants_dir = Paths.assets.data .. "variants/"

    -- Get list of files in variants directory
    local files = love.filesystem.getDirectoryItems(variants_dir)

    for _, filename in ipairs(files) do
        -- Check if it's a JSON file matching the pattern *_variants.json
        if filename:match("^(.+)_variants%.json$") then
            local game_name = filename:match("^(.+)_variants%.json$")
            local file_path = variants_dir .. filename

            -- Try to read and parse the file
            local read_ok, contents = pcall(love.filesystem.read, file_path)
            if read_ok and contents then
                local decode_ok, variant_data = pcall(json.decode, contents)
                if decode_ok and variant_data and type(variant_data) == "table" then
                    -- Count the variants (array length)
                    -- Subtract 1 because the count includes the base game (clone_index 0)
                    -- but generateClones expects the number of clones to generate
                    local count = #variant_data
                    if count > 1 then  -- Must have at least base + 1 clone
                        local clone_count = count - 1

                        -- Extract first word before underscore for base game ID
                        -- e.g., "memory_match" -> "memory", "dodge" -> "dodge"
                        local base_type = game_name:match("^([^_]+)")
                        local base_game_id = base_type .. "_1"

                        variant_counts[base_game_id] = clone_count
                        print("Found " .. count .. " total variants (" .. clone_count .. " clones) for " .. base_game_id .. " in " .. filename)
                    end
                else
                    print("Warning: Could not decode variant file: " .. filename)
                end
            else
                print("Warning: Could not read variant file: " .. filename)
            end
        end
    end

    return variant_counts
end

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

function GameData:generateClones(base_game, count)
    -- Load variant data from JSON if available
    local game_type = base_game.id:match("^([^_]+)")
    local variant_file = Paths.assets.data .. "variants/" .. game_type .. "_variants.json"
    local variants_data = {}

    local read_ok, contents = pcall(love.filesystem.read, variant_file)
    if read_ok and contents then
        local decode_ok, variants = pcall(json.decode, contents)
        if decode_ok and variants then
            for _, v in ipairs(variants) do
                variants_data[v.clone_index] = v
            end
            print("Loaded variant data for " .. game_type .. " from " .. variant_file)
        end
    end

    -- Available palettes for variants (cycling through them)
    local available_palettes = {
        "default", "neon_blue", "neon_pink", "neon_green",
        "retro_amber", "retro_green", "pastel_pink", "pastel_blue",
        "pastel_yellow", "military_green", "military_gray", "fire", "ice"
    }

    -- Available sprite variations per sprite set
    local sprite_variations = {
        space_set_1 = {"game_mine_1-0", "game_mine_1-1", "game_mine_2-0", "game_mine_2-1"},
        snake_set_1 = {"game_spider-0", "game_spider-1", "game_spider-2", "game_spider-3"},
        memory_set_1 = {"game_freecell-0", "game_freecell-1", "game_freecell-2", "game_solitaire-0"},
        dodge_set_1 = {"game_solitaire-0", "game_solitaire-1", "game_hearts"},
        hidden_set_1 = {"magnifying_glass-0", "magnifying_glass-1", "magnifying_glass_3", "magnifying_glass_4-0"}
    }

    for i = 1, count do
        local variant_num = i + 1
        local multiplier = i -- Use the clone index as the base for the multiplier
        local difficulty_level = math.max(1, math.floor(i / Config.clone_difficulty_step) + 1)

        local cost_exponent = base_game.cost_exponent or Config.clone_cost_exponent
        -- Cost scaling starts immediately at variant 2 (i=1): use (i+1) for cost calculation
        local cost = math.floor(base_game.unlock_cost * math.pow(i + 1, cost_exponent))

        local clone = {}
        for k, v in pairs(base_game) do clone[k] = v end

        clone.id = base_game.id:gsub("_1$", "_" .. variant_num)
        if clone.id == base_game.id then clone.id = base_game.id .. "_" .. variant_num end

        -- Try to get variant-specific data
        local variant_data = variants_data[i]  -- clone_index = i

        -- Use variant name if available, otherwise fallback
        if variant_data and variant_data.name then
            clone.display_name = variant_data.name
        else
            clone.display_name = base_game.display_name:gsub(" 1$", " " .. variant_num)
            if clone.display_name == base_game.display_name then clone.display_name = base_game.display_name .. " " .. variant_num end
        end

        -- Apply other variant-specific properties
        if variant_data then
            -- Copy all variant properties to the clone
            for k, v in pairs(variant_data) do
                if k ~= "clone_index" and k ~= "name" then
                    clone[k] = v
                end
            end
        end

        clone.unlock_cost = cost
        clone.variant_of = base_game.id
        clone.variant_multiplier = multiplier
        clone.difficulty_level = difficulty_level
        clone.auto_play_performance = self:scaleAutoPlayPerformance(
            base_game.auto_play_performance,
            difficulty_level
        )
        clone.difficulty_modifiers = nil

        -- Deep copy visual_identity if it exists
        if base_game.visual_identity then
            clone.visual_identity = {}
            for k, v in pairs(base_game.visual_identity) do
                if type(v) == "table" then
                    clone.visual_identity[k] = {}
                    for k2, v2 in pairs(v) do
                        clone.visual_identity[k][k2] = v2
                    end
                else
                    clone.visual_identity[k] = v
                end
            end
            
            -- Assign visual variation based on variant number
            if variant_num % 3 == 0 then
                -- Every 3rd variant: change sprite set
                local sprite_set_id = clone.visual_identity.sprite_set_id or "space_set_1"
                local variations = sprite_variations[sprite_set_id] or {"game_mine_1-0"}
                local sprite_index = ((variant_num - 1) % #variations) + 1
                clone.icon_sprite = variations[sprite_index]
                
                -- Update metric mappings
                if clone.visual_identity.metric_sprite_mappings then
                    for metric_name, _ in pairs(clone.visual_identity.metric_sprite_mappings) do
                        if metric_name == "kills" or metric_name == "objects_dodged" or 
                           metric_name == "snake_length" or metric_name == "matches" or 
                           metric_name == "objects_found" then
                            clone.visual_identity.metric_sprite_mappings[metric_name] = variations[sprite_index]
                        end
                    end
                end
                
                -- Update formula icon mappings
                if clone.visual_identity.formula_icon_mapping then
                    for key, _ in pairs(clone.visual_identity.formula_icon_mapping) do
                        if key == "kills" or key == "objects_dodged" or 
                           key == "snake_length" or key == "matches" or 
                           key == "objects_found" then
                            clone.visual_identity.formula_icon_mapping[key] = variations[sprite_index]
                        end
                    end
                end
            else
                -- Other variants: change palette only
                local palette_index = ((variant_num - 1) % #available_palettes) + 1
                clone.visual_identity.palette_id = available_palettes[palette_index]
            end
        end

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
        local game_type = base_id:match("^([^_]+)")
        local variant_file = Paths.assets.data .. "variants/" .. game_type .. "_variants.json"
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

    -- Space Shooter: estimate based on level
    elseif game.metrics_tracked and game.metrics_tracked[1] == "kills" then
        max_metrics.kills = 50 -- Estimate for a good run
        max_metrics.deaths = 0

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
    return game.formula_function(max_metrics)
end

return GameData