local Object = require('class')
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
    self:loadGames()
end

function GameData:loadGames()
    -- Base formulas (without multipliers)
    local base_formulas = {
        space_shooter = {
            string_template = "(Kills - Deaths)",
            func = function(metrics) return metrics.kills - metrics.deaths end
        },
        snake = {
            string_template = "(Length × Survival Time ÷ 10)",
            func = function(metrics) return metrics.snake_length * (metrics.survival_time / 10) end
        },
        memory = {
            string_template = "(Matches × 10 - Time + Perfect × 5)",
            func = function(metrics) return metrics.matches * 10 - metrics.time + metrics.perfect * 5 end
        },
        dodge = {
            string_template = "(Objects Dodged² ÷ (Collisions + 1))",
            func = function(metrics) return (metrics.objects_dodged * metrics.objects_dodged) / (metrics.collisions + 1) end
        },
        hidden = {
            string_template = "(Objects Found × Time Bonus)",
            func = function(metrics) return metrics.objects_found * metrics.time_bonus end
        }
    }
    
    -- Template 1: Space Shooter
    local base_space_shooter = {
        id = "space_shooter_1",
        display_name = "Space Shooter 1",
        game_class = "SpaceShooter",
        tier = self.TIER.TRASH,
        category = self.CATEGORY.ACTION,
        unlock_cost = 100,
        formula_string = base_formulas.space_shooter.string_template .. " × 1",
        base_formula = base_formulas.space_shooter.func,
        metrics_tracked = {"kills", "deaths"},
        bullet_fire_rate = 1,
        bullet_sprite = "bullet_basic",
        variant_of = nil,
        variant_multiplier = 1,
        difficulty_level = 1,
        auto_play_performance = {kills = 20, deaths = 2},
        formula_function = function(metrics) 
            return base_formulas.space_shooter.func(metrics) * 1
        end,
        difficulty_modifiers = {speed = 1, count = 1, complexity = 1, time_limit = 1}
    }
    
    -- Template 2: Snake Game
    local base_snake = {
        id = "snake_1",
        display_name = "Snake Classic 1",
        game_class = "SnakeGame",
        tier = self.TIER.TRASH,
        category = self.CATEGORY.ARCADE,
        unlock_cost = 150,
        formula_string = base_formulas.snake.string_template .. " × 1",
        base_formula = base_formulas.snake.func,
        metrics_tracked = {"snake_length", "survival_time"},
        bullet_fire_rate = 0.8,
        bullet_sprite = "bullet_snake",
        variant_of = nil,
        variant_multiplier = 1,
        difficulty_level = 1,
        auto_play_performance = {snake_length = 10, survival_time = 30},
        formula_function = function(metrics)
            return base_formulas.snake.func(metrics) * 1
        end,
        difficulty_modifiers = {speed = 1, count = 1, complexity = 1, time_limit = 1}
    }
    
    -- Template 3: Memory Match
    local base_memory = {
        id = "memory_1",
        display_name = "Memory Match 1",
        game_class = "MemoryMatch",
        tier = self.TIER.TRASH,
        category = self.CATEGORY.PUZZLE,
        unlock_cost = 200,
        formula_string = base_formulas.memory.string_template .. " × 1",
        base_formula = base_formulas.memory.func,
        metrics_tracked = {"matches", "time", "perfect"},
        bullet_fire_rate = 1.2,
        bullet_sprite = "bullet_card",
        variant_of = nil,
        variant_multiplier = 1,
        difficulty_level = 1,
        auto_play_performance = {matches = 8, time = 40, perfect = 2},
        formula_function = function(metrics)
            return base_formulas.memory.func(metrics) * 1
        end,
        difficulty_modifiers = {speed = 1, count = 1, complexity = 1, time_limit = 1}
    }
    
    -- Template 4: Dodge Game
    local base_dodge = {
        id = "dodge_1",
        display_name = "Dodge Master 1",
        game_class = "DodgeGame",
        tier = self.TIER.TRASH,
        category = self.CATEGORY.ACTION,
        unlock_cost = 175,
        formula_string = base_formulas.dodge.string_template .. " × 1",
        base_formula = base_formulas.dodge.func,
        metrics_tracked = {"objects_dodged", "collisions", "perfect_dodges"},
        bullet_fire_rate = 0.9,
        bullet_sprite = "bullet_dodge",
        variant_of = nil,
        variant_multiplier = 1,
        difficulty_level = 1,
        auto_play_performance = {objects_dodged = 15, collisions = 3, perfect_dodges = 5},
        formula_function = function(metrics)
            return base_formulas.dodge.func(metrics) * 1
        end,
        difficulty_modifiers = {speed = 1, count = 1, complexity = 1, time_limit = 1}
    }
    
    -- Template 5: Hidden Object
    local base_hidden = {
        id = "hidden_1",
        display_name = "Hidden Treasures 1",
        game_class = "HiddenObject",
        tier = self.TIER.TRASH,
        category = self.CATEGORY.PUZZLE,
        unlock_cost = 125,
        formula_string = base_formulas.hidden.string_template .. " × 1",
        base_formula = base_formulas.hidden.func,
        metrics_tracked = {"objects_found", "time_bonus"},
        bullet_fire_rate = 1.1,
        bullet_sprite = "bullet_hidden",
        variant_of = nil,
        variant_multiplier = 1,
        difficulty_level = 1,
        auto_play_performance = {objects_found = 8, time_bonus = 3},
        formula_function = function(metrics)
            return base_formulas.hidden.func(metrics) * 1
        end,
        difficulty_modifiers = {speed = 1, count = 1, complexity = 1, time_limit = 1}
    }
    
    -- Add base games
    self.games[base_space_shooter.id] = base_space_shooter
    self.games[base_snake.id] = base_snake
    self.games[base_memory.id] = base_memory
    self.games[base_dodge.id] = base_dodge
    self.games[base_hidden.id] = base_hidden
    
    -- Generate clones
    local multipliers = {1.2, 1.5, 2, 3, 5, 7, 10, 15, 20, 30}
    self:generateClones(base_space_shooter, 40, multipliers)
    self:generateClones(base_snake, 40, multipliers)
    self:generateClones(base_memory, 40, multipliers)
    self:generateClones(base_dodge, 40, multipliers)
    self:generateClones(base_hidden, 40, multipliers)
end

function GameData:generateClones(base_game, count, multipliers)
    for i = 1, count do
        local variant_num = i + 1
        local multiplier = multipliers[math.min(#multipliers, i)] or multipliers[#multipliers]
        local difficulty_level = math.max(1, math.floor(i / 5) + 1)
        
        -- Calculate cost with exponential scaling
        local cost = math.floor(base_game.unlock_cost * math.pow(multiplier, 0.8))
        
        local clone = {
            id = base_game.id:gsub("_1$", "_" .. variant_num),
            display_name = base_game.display_name:gsub(" 1$", " " .. variant_num),
            game_class = base_game.game_class,
            tier = base_game.tier,
            category = base_game.category,
            unlock_cost = cost,
            formula_string = base_game.base_formula and 
                (base_game.formula_string:gsub(" × %d+", "") .. " × " .. multiplier) or
                base_game.formula_string,
            base_formula = base_game.base_formula,
            metrics_tracked = base_game.metrics_tracked,
            bullet_fire_rate = base_game.bullet_fire_rate,
            bullet_sprite = base_game.bullet_sprite,
            variant_of = base_game.id,
            variant_multiplier = multiplier,
            difficulty_level = difficulty_level,
            auto_play_performance = self:scaleAutoPlayPerformance(
                base_game.auto_play_performance, 
                difficulty_level
            ),
            formula_function = function(metrics)
                return base_game.base_formula(metrics) * multiplier
            end,
            difficulty_modifiers = {
                speed = 1 + (difficulty_level * 0.15),
                count = 1 + (difficulty_level * 0.25),
                complexity = difficulty_level,
                time_limit = math.max(0.5, 1 - (difficulty_level * 0.08))
            }
        }
        
        self.games[clone.id] = clone
    end
end

function GameData:scaleAutoPlayPerformance(base_performance, difficulty_level)
    local scaled = {}
    
    for metric, value in pairs(base_performance) do
        if metric == "kills" or metric == "objects_dodged" or metric == "snake_length" or metric == "objects_found" then
            -- Performance-based metrics get harder at higher difficulties
            scaled[metric] = math.max(1, math.floor(value * (1 - (difficulty_level * 0.08))))
        elseif metric == "deaths" or metric == "collisions" then
            -- Negative metrics increase with difficulty
            scaled[metric] = math.max(1, math.ceil(value * (1 + (difficulty_level * 0.15))))
        elseif metric == "time" or metric == "survival_time" then
            -- Time-based metrics worsen
            scaled[metric] = value * (1 - (difficulty_level * 0.05))
        elseif metric == "perfect_dodges" or metric == "perfect" or metric == "matches" then
            -- Bonus metrics decrease
            scaled[metric] = math.max(0, math.floor(value * (1 - (difficulty_level * 0.1))))
        else
            -- Default: slight reduction
            scaled[metric] = value * 0.9
        end
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
    return all_games
end

function GameData:getGamesByCategory(category)
    local filtered = {}
    for _, game in pairs(self.games) do
        if game.category == category then
            table.insert(filtered, game)
        end
    end
    return filtered
end

function GameData:getGamesByTier(tier)
    local filtered = {}
    for _, game in pairs(self.games) do
        if game.tier == tier then
            table.insert(filtered, game)
        end
    end
    return filtered
end

function GameData:calculatePower(game_id, metrics)
    local game = self:getGame(game_id)
    if not game or not game.formula_function then
        return 0
    end
    return game.formula_function(metrics)
end

function GameData:calculateTokenRate(game_id, metrics)
    -- Token rate is the same as power for MVP
    return self:calculatePower(game_id, metrics)
end

return GameData