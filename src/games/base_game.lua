local Object = require('class')
local BaseGame = Object:extend('BaseGame')

function BaseGame:init(game_data)
    -- Store game definition
    self.data = game_data
    
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
end

function BaseGame:update(dt)
    if not self.completed then
        self.time_elapsed = self.time_elapsed + dt
        
        if self:checkComplete() then
            self:onComplete()
        end
    end
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
    return self.data.formula_function(self.metrics)
end

return BaseGame