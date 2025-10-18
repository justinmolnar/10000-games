local Object = require('class')
local BaseGame = Object:extend('BaseGame')

function BaseGame:init(game_data, cheats)
    -- Store game definition
    self.data = game_data
    
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

return BaseGame