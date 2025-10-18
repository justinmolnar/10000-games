-- src/games/views/hidden_object_view.lua
local Object = require('class')
local HiddenObjectView = Object:extend('HiddenObjectView')

function HiddenObjectView:init(game_state)
    self.game = game_state
    -- Store constants needed for drawing
    self.BACKGROUND_GRID_BASE = game_state.BACKGROUND_GRID_BASE or 10
    self.BACKGROUND_HASH_1 = game_state.BACKGROUND_HASH_1 or 17
    self.BACKGROUND_HASH_2 = game_state.BACKGROUND_HASH_2 or 3
end

function HiddenObjectView:draw()
    local game = self.game

    self:drawBackground()

    -- Draw objects that haven't been found
    for _, obj in ipairs(game.objects) do
        if not obj.found then
            self:drawObject(obj)
        end
    end

    -- Draw HUD
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Objects Found: " .. game.objects_found .. "/" .. game.total_objects, 10, 10)
    love.graphics.print("Time Remaining: " .. string.format("%.1f", game.time_remaining), 10, 30)
    love.graphics.print("Difficulty: " .. game.difficulty_level, 10, 50)
    if game.completed and game.metrics.time_bonus > 0 then
        love.graphics.print("Time Bonus: " .. game.metrics.time_bonus, 10, 70)
    end
end

function HiddenObjectView:drawBackground()
    local game = self.game -- Need game state for complexity modifier
    love.graphics.setColor(0.2, 0.2, 0.2) 

    local complexity = game.difficulty_modifiers.complexity
    local grid_density = math.floor(self.BACKGROUND_GRID_BASE * complexity) 
    local cell_w = love.graphics.getWidth() / grid_density
    local cell_h = love.graphics.getHeight() / grid_density
    
    local complexity_mod = math.max(1, self.BACKGROUND_HASH_2 + complexity)
    
    for i = 0, grid_density do
        for j = 0, grid_density do
            if ((i + j) * self.BACKGROUND_HASH_1) % complexity_mod == 0 then
                love.graphics.setColor(0.3, 0.3, 0.3) 
                love.graphics.rectangle('fill', i * cell_w, j * cell_h, cell_w, cell_h)
            end
        end
    end
end

function HiddenObjectView:drawObject(obj)
    love.graphics.setColor(0.8, 0.8, 0.8) 
    
    local variant = obj.sprite_variant
    local angle = (obj.id * 13) % 360 
    
    love.graphics.push()
    love.graphics.translate(obj.x, obj.y)
    love.graphics.rotate(math.rad(angle))
    
    if variant % 3 == 0 then
        love.graphics.polygon('fill', -obj.size/2, obj.size/2, obj.size/2, obj.size/2, 0, -obj.size/2)
    elseif variant % 3 == 1 then
        love.graphics.rectangle('fill', -obj.size/2, -obj.size/2, obj.size, obj.size)
    else
        love.graphics.circle('fill', 0, 0, obj.radius) 
    end
    
    love.graphics.pop()
end


return HiddenObjectView