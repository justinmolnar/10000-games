local BaseGame = require('src.games.base_game')
local HiddenObject = BaseGame:extend('HiddenObject')

-- Constants
local TIME_LIMIT_BASE = 60 -- seconds for easy difficulty
local OBJECTS_BASE = 5 -- objects for easy difficulty
local BONUS_TIME_MULTIPLIER = 5 -- bonus points per second remaining

function HiddenObject:init(game_data)
    HiddenObject.super.init(self, game_data)
    
    -- Game state
    self.time_remaining = TIME_LIMIT_BASE / self.difficulty_modifiers.speed
    self.objects_found = 0
    self.time_bonus = 0
    
    -- Objects to find
    self.total_objects = math.floor(OBJECTS_BASE * self.difficulty_modifiers.count)
    self.objects = self:generateObjects()
    self.found_objects = {}
    
    -- Metrics
    self.metrics.objects_found = 0
    self.metrics.time_bonus = 0
end

function HiddenObject:generateObjects()
    local objects = {}
    local positions = self:getDeterministicPositions()
    
    for i = 1, self.total_objects do
        -- Use deterministic positions but vary appearance based on difficulty
        local pos = positions[i]
        objects[i] = {
            x = pos.x,
            y = pos.y,
            size = 20,
            found = false,
            -- More similar-looking objects at higher difficulties
            sprite_variant = math.floor((i - 1) / self.difficulty_modifiers.complexity) + 1
        }
    end
    
    return objects
end

function HiddenObject:getDeterministicPositions()
    -- Generate fixed positions that are the same every time
    -- but spread out across the screen
    local positions = {}
    local grid_size = math.ceil(math.sqrt(self.total_objects))
    local cell_width = love.graphics.getWidth() / grid_size
    local cell_height = love.graphics.getHeight() / grid_size
    
    for i = 1, self.total_objects do
        local row = math.floor((i-1) / grid_size)
        local col = (i-1) % grid_size
        
        -- Add some deterministic variation within the cell
        local x = col * cell_width + (((i * 17) % 47) / 47) * cell_width
        local y = row * cell_height + (((i * 23) % 53) / 53) * cell_height
        
        positions[i] = {x = x, y = y}
    end
    
    return positions
end

function HiddenObject:update(dt)
    if self.completed then return end
    HiddenObject.super.update(self, dt)
    
    -- Update timer
    if not self.completed then
        self.time_remaining = self.time_remaining - dt
        if self.time_remaining <= 0 then
            self.time_remaining = 0
            self:onComplete()
        end
    end
end

function HiddenObject:draw()
    -- Draw background grid (gets more complex at higher difficulties)
    self:drawBackground()
    
    -- Draw objects
    for i, obj in ipairs(self.objects) do
        if not obj.found then
            -- Draw object (more similar at higher difficulties)
            self:drawObject(obj)
        end
    end
    
    -- Draw HUD
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Objects Found: " .. self.objects_found .. "/" .. self.total_objects, 10, 10)
    love.graphics.print("Time: " .. math.ceil(self.time_remaining), 10, 30)
    if self.time_bonus > 0 then
        love.graphics.print("Time Bonus: " .. self.time_bonus, 10, 50)
    end
end

function HiddenObject:drawBackground()
    -- Create a deterministic but complex background pattern
    -- More complex at higher difficulties
    love.graphics.setColor(0.2, 0.2, 0.2)
    
    local complexity = self.difficulty_modifiers.complexity
    local grid = 10 * complexity
    
    for i = 0, grid do
        for j = 0, grid do
            if ((i + j) * 17) % (3 + complexity) == 0 then
                love.graphics.rectangle('fill',
                    i * love.graphics.getWidth() / grid,
                    j * love.graphics.getHeight() / grid,
                    love.graphics.getWidth() / grid,
                    love.graphics.getHeight() / grid)
            end
        end
    end
end

function HiddenObject:drawObject(obj)
    -- Draw object with deterministic but complex appearance
    -- Objects look more similar at higher difficulties
    love.graphics.setColor(0.8, 0.8, 0.8)
    
    local variant = obj.sprite_variant
    local angle = variant * math.pi / 4
    
    -- Create slightly different shapes based on variant
    love.graphics.push()
    love.graphics.translate(obj.x, obj.y)
    love.graphics.rotate(angle)
    
    if variant % 3 == 0 then
        -- Triangle
        love.graphics.polygon('fill', -obj.size/2, obj.size/2,
                                    obj.size/2, obj.size/2,
                                    0, -obj.size/2)
    elseif variant % 3 == 1 then
        -- Square
        love.graphics.rectangle('fill', -obj.size/2, -obj.size/2,
                                      obj.size, obj.size)
    else
        -- Circle
        love.graphics.circle('fill', 0, 0, obj.size/2)
    end
    
    love.graphics.pop()
end

function HiddenObject:mousepressed(x, y, button)
    if self.completed then return end
    
    -- Check for object clicks
    for i, obj in ipairs(self.objects) do
        if not obj.found and self:checkObjectClick(obj, x, y) then
            obj.found = true
            self.objects_found = self.objects_found + 1
            
            -- Check if game complete
            if self.objects_found >= self.total_objects then
                -- Calculate time bonus
                self.time_bonus = math.floor(self.time_remaining * BONUS_TIME_MULTIPLIER)
                self:onComplete()
            end
            
            -- Only one object per click
            break
        end
    end
end

function HiddenObject:checkObjectClick(obj, x, y)
    -- Simple distance check for click detection
    local dx = x - obj.x
    local dy = y - obj.y
    return (dx * dx + dy * dy) <= (obj.size * obj.size)
end

function HiddenObject:onComplete()
    if self.completed then return end
    
    -- Update metrics
    self.metrics.objects_found = self.objects_found
    self.metrics.time_bonus = self.time_bonus
    
    HiddenObject.super.onComplete(self)
end

function HiddenObject:checkComplete()
    return self.objects_found >= self.total_objects or self.time_remaining <= 0
end

return HiddenObject