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
    self.games = {}  -- Will store all game data
    self:loadGames()  -- Load initial games
end

function GameData:loadGames()
    -- Initialize all base game templates for MVP
    
    -- Template 1: Space Shooter
    local base_space_shooter = {
        id = "space_shooter_1",
        display_name = "Space Shooter",
        game_class = "space_shooter",
        tier = self.TIER.TRASH,
        category = self.CATEGORY.ACTION,
        unlock_cost = 100,
        formula_string = "(Kills - Deaths) × 1",
        metrics_tracked = {"kills", "deaths"},
        bullet_fire_rate = 1,
        bullet_sprite = "bullet_basic",
        variant_of = nil,
        variant_multiplier = 1,
        auto_play_performance = {
            kills = 20,
            deaths = 2
        },
        formula_function = function(metrics)
            return (metrics.kills - metrics.deaths) * 1
        end
    }
    
    -- Template 2: Snake Game
    local base_snake = {
        id = "snake_1",
        display_name = "Snake Classic",
        game_class = "snake",
        tier = self.TIER.TRASH,
        category = self.CATEGORY.ARCADE,
        unlock_cost = 150,
        formula_string = "(Length × Survival Time ÷ 10) × 1",
        metrics_tracked = {"snake_length", "survival_time"},
        bullet_fire_rate = 0.8,
        bullet_sprite = "bullet_snake",
        variant_of = nil,
        variant_multiplier = 1,
        auto_play_performance = {
            snake_length = 10,
            survival_time = 30
        },
        formula_function = function(metrics)
            return (metrics.snake_length * (metrics.survival_time / 10)) * 1
        end
    }
    
    -- Template 3: Memory Match
    local base_memory = {
        id = "memory_1",
        display_name = "Memory Match",
        game_class = "memory",
        tier = self.TIER.TRASH,
        category = self.CATEGORY.PUZZLE,
        unlock_cost = 200,
        formula_string = "(Matches × 10 - Time + Perfect × 5) × 1",
        metrics_tracked = {"matches", "time", "perfect"},
        bullet_fire_rate = 1.2,
        bullet_sprite = "bullet_card",
        variant_of = nil,
        variant_multiplier = 1,
        auto_play_performance = {
            matches = 8,
            time = 40,
            perfect = 2
        },
        formula_function = function(metrics)
            return (metrics.matches * 10 - metrics.time + metrics.perfect * 5) * 1
        end
    }
    
    -- Template 4: Dodge Game
    local base_dodge = {
        id = "dodge_1",
        display_name = "Dodge Master",
        game_class = "dodge",
        tier = self.TIER.TRASH,
        category = self.CATEGORY.ACTION,
        unlock_cost = 175,
        formula_string = "(Objects Dodged² ÷ (Collisions + 1)) × 1",
        metrics_tracked = {"objects_dodged", "collisions"},
        bullet_fire_rate = 0.9,
        bullet_sprite = "bullet_dodge",
        variant_of = nil,
        variant_multiplier = 1,
        auto_play_performance = {
            objects_dodged = 15,
            collisions = 3
        },
        formula_function = function(metrics)
            return ((metrics.objects_dodged * metrics.objects_dodged) / (metrics.collisions + 1)) * 1
        end
    }
    
    -- Template 5: Hidden Object
    local base_hidden = {
        id = "hidden_1",
        display_name = "Hidden Treasures",
        game_class = "hidden",
        tier = self.TIER.TRASH,
        category = self.CATEGORY.PUZZLE,
        unlock_cost = 125,
        formula_string = "(Objects Found × Time Bonus) × 1",
        metrics_tracked = {"objects_found", "time_bonus"},
        bullet_fire_rate = 1.1,
        bullet_sprite = "bullet_hidden",
        variant_of = nil,
        variant_multiplier = 1,
        auto_play_performance = {
            objects_found = 8,
            time_bonus = 3
        },
        formula_function = function(metrics)
            return (metrics.objects_found * metrics.time_bonus) * 1
        end
    }
    
    -- Add all base games
    self.games[base_space_shooter.id] = base_space_shooter
    self.games[base_snake.id] = base_snake
    self.games[base_memory.id] = base_memory
    self.games[base_dodge.id] = base_dodge
    self.games[base_hidden.id] = base_hidden
    
    -- Generate clones for each base game
    local multipliers = {1, 1.2, 2, 5, 10, 20, 40}
    self:generateClones(base_space_shooter.id, 10, multipliers)
    self:generateClones(base_snake.id, 10, multipliers)
    self:generateClones(base_memory.id, 10, multipliers)
    self:generateClones(base_dodge.id, 10, multipliers)
    self:generateClones(base_hidden.id, 10, multipliers)
end

function GameData:scaleAutoPlayPerformance(base_performance, difficulty_level)
    local scaled = {}
    for metric, value in pairs(base_performance) do
        -- Different scaling based on metric type
        if metric == "kills" or metric == "objects_dodged" or metric == "snake_length" then
            -- These get harder to achieve at higher difficulties
            scaled[metric] = math.floor(value * (1 - (difficulty_level * 0.1)))
        elseif metric == "deaths" or metric == "collisions" then
            -- These increase with difficulty
            scaled[metric] = math.ceil(value * (1 + (difficulty_level * 0.2)))
        elseif metric == "time" or metric == "survival_time" then
            -- Time-based metrics get slightly worse
            scaled[metric] = value * (1 + (difficulty_level * 0.15))
        else
            -- Default scaling (slight reduction)
            scaled[metric] = value * (1 - (difficulty_level * 0.05))
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

function GameData:generateClones(base_game_id, count, multipliers)
    local base_game = self:getGame(base_game_id)
    if not base_game then return end

    for i = 1, count do
        local multiplier = multipliers[math.min(#multipliers, i)] or multipliers[#multipliers]
        local difficulty_level = math.floor(i / 3) + 1  -- Every 3 variants increase difficulty
        
        local clone = {
            id = base_game.id:gsub("_1", "_" .. (i + 1)),
            display_name = base_game.display_name .. " " .. (i + 1),
            game_class = base_game.game_class,
            tier = base_game.tier,
            category = base_game.category,
            unlock_cost = base_game.unlock_cost * multiplier,
            formula_string = ("(%s) × %.1f"):format(
                base_game.formula_string:match("%((.+)%) × %d+"),
                multiplier),
            metrics_tracked = base_game.metrics_tracked,
            bullet_fire_rate = base_game.bullet_fire_rate,
            bullet_sprite = base_game.bullet_sprite,
            variant_of = base_game.id,
            variant_multiplier = multiplier,
            difficulty_level = difficulty_level,
            
            -- Scale auto-play performance based on difficulty
            auto_play_performance = self:scaleAutoPlayPerformance(base_game.auto_play_performance, difficulty_level),
            
            -- Create formula function with proper multiplier
            formula_function = function(metrics)
                return base_game.formula_function(metrics) * multiplier
            end,
            
            -- Difficulty modifiers based on level
            difficulty_modifiers = {
                speed = 1 + (difficulty_level * 0.2),  -- 20% faster per level
                count = 1 + (difficulty_level * 0.3),  -- 30% more objects per level
                complexity = difficulty_level,          -- Direct difficulty scaling
                time_limit = math.max(0.5, 1 - (difficulty_level * 0.1))  -- 10% less time per level, min 50%
            }
        }
        self.games[clone.id] = clone
    end
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