local Object = require('class')
local BaseGame = Object:extend('BaseGame')

function BaseGame:init(game_data, cheats, di)
    -- Store game definition
    self.data = game_data

    -- Store DI container (optional)
    self.di = di

    -- Store active cheats
    self.cheats = cheats or {}

    -- Performance tracking
    self.metrics = {}
    self.completed = false
    self.time_elapsed = 0

    -- Reset all metrics tracked by this game
    for _, metric in ipairs(self.data.metrics_tracked) do
        self.metrics[metric] = 0
    end

    -- Apply difficulty modifiers
    self.difficulty_modifiers = self.data.difficulty_modifiers or {
        speed = 1,
        count = 1,
        complexity = 1,
        time_limit = 1
    }

    -- Store difficulty level
    self.difficulty_level = self.data.difficulty_level or 1

    -- Load variant data if GameVariantLoader is available
    self.variant = nil
    if di and di.gameVariantLoader then
        local variant_data = di.gameVariantLoader:getVariantData(game_data.id)
        if variant_data then
            self.variant = variant_data
        end
    end

    -- If no variant loaded, create a default one to avoid nil checks everywhere
    if not self.variant then
        self.variant = {
            clone_index = 0,
            name = game_data.display_name or "Unknown",
            sprite_set = "default",
            palette = "default",
            music_track = nil,
            sfx_pack = "retro_beeps",
            background = "default",
            difficulty_modifier = 1.0,
            enemies = {},
            flavor_text = "",
            intro_cutscene = nil
        }
    end
end

function BaseGame:updateBase(dt)
    if not self.completed then
        self.time_elapsed = self.time_elapsed + dt
        
        -- Update time_remaining if the game uses it (like HiddenObject)
        if self.time_limit and self.time_remaining then
             self.time_remaining = math.max(0, self.time_limit - self.time_elapsed)
        end

        if self:checkComplete() then
            self:onComplete()
        end
    end
end

function BaseGame:updateGameLogic(dt)
    -- Override in subclasses to implement game-specific update logic
    -- No need to call super.update from subclasses anymore
end

function BaseGame:draw()
    -- Override in subclasses
end

function BaseGame:keypressed(key)
    -- Override in subclasses
end

function BaseGame:mousepressed(x, y, button)
    -- Override in subclasses
end

function BaseGame:checkComplete()
    -- Override in subclasses
    return false
end

function BaseGame:onComplete()
    self.completed = true
end

function BaseGame:getMetrics()
    return self.metrics
end

function BaseGame:calculatePerformance()
    if not self.completed then return 0 end
    -- Note: This returns the *base* performance. 
    -- The MinigameState is responsible for applying performance-modifying cheats.
    return self.data.formula_function(self.metrics)
end

-- Completion ratio: override in games to report progress toward their core goal (0..1)
function BaseGame:getCompletionRatio()
    return 1.0
end

return BaseGame