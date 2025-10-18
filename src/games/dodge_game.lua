local BaseGame = require('src.games.base_game')
local DodgeGame = BaseGame:extend('DodgeGame')

-- Constants
local PLAYER_SIZE = 20
local PLAYER_SPEED = 300
local OBJECT_SIZE = 15
local BASE_SPAWN_RATE = 1.0
local WARNING_TIME = 0.5

function DodgeGame:init(game_data)
    DodgeGame.super.init(self, game_data)
    
    -- Player setup
    self.player = {
        x = love.graphics.getWidth() / 2,
        y = love.graphics.getHeight() / 2,
        size = PLAYER_SIZE
    }
    
    -- Game objects
    self.objects = {}
    self.warnings = {}
    
    -- Spawn settings based on difficulty
    self.spawn_rate = BASE_SPAWN_RATE / self.difficulty_modifiers.count
    self.spawn_timer = 0
    self.object_speed = 200 * self.difficulty_modifiers.speed
    self.warning_enabled = self.difficulty_modifiers.complexity <= 2
    
    -- Metrics
    self.metrics.objects_dodged = 0
    self.metrics.collisions = 0
    self.metrics.perfect_dodges = 0
end

function DodgeGame:update(dt)
    if self.completed then return end
    DodgeGame.super.update(self, dt)
    
    -- Update player position based on input
    self:updatePlayer(dt)
    
    -- Update spawn timer
    self.spawn_timer = self.spawn_timer - dt
    if self.spawn_timer <= 0 then
        self:spawnObject()
        self.spawn_timer = self.spawn_rate
    end
    
    -- Update existing objects
    self:updateObjects(dt)
    
    -- Update warnings
    self:updateWarnings(dt)
end

function DodgeGame:draw()
    -- Draw player
    love.graphics.setColor(0, 1, 0)
    love.graphics.circle('fill', self.player.x, self.player.y, self.player.size)
    
    -- Draw warnings
    love.graphics.setColor(1, 1, 0, 0.3)
    for _, warning in ipairs(self.warnings) do
        if warning.type == 'horizontal' then
            love.graphics.rectangle('fill', 0, warning.pos - OBJECT_SIZE, 
                love.graphics.getWidth(), OBJECT_SIZE * 2)
        else
            love.graphics.rectangle('fill', warning.pos - OBJECT_SIZE, 0,
                OBJECT_SIZE * 2, love.graphics.getHeight())
        end
    end
    
    -- Draw objects
    love.graphics.setColor(1, 0, 0)
    for _, obj in ipairs(self.objects) do
        love.graphics.circle('fill', obj.x, obj.y, OBJECT_SIZE)
    end
    
    -- Draw HUD
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Dodged: " .. self.metrics.objects_dodged, 10, 10)
    love.graphics.print("Collisions: " .. self.metrics.collisions, 10, 30)
    love.graphics.print("Perfect: " .. self.metrics.perfect_dodges, 10, 50)
end

function DodgeGame:updatePlayer(dt)
    local dx = 0
    local dy = 0
    
    if love.keyboard.isDown('left', 'a') then dx = dx - 1 end
    if love.keyboard.isDown('right', 'd') then dx = dx + 1 end
    if love.keyboard.isDown('up', 'w') then dy = dy - 1 end
    if love.keyboard.isDown('down', 's') then dy = dy + 1 end
    
    -- Normalize diagonal movement
    if dx ~= 0 and dy ~= 0 then
        dx = dx * 0.707
        dy = dy * 0.707
    end
    
    -- Update position
    self.player.x = self.player.x + dx * PLAYER_SPEED * dt
    self.player.y = self.player.y + dy * PLAYER_SPEED * dt
    
    -- Clamp to screen
    self.player.x = math.max(self.player.size, math.min(love.graphics.getWidth() - self.player.size, self.player.x))
    self.player.y = math.max(self.player.size, math.min(love.graphics.getHeight() - self.player.size, self.player.y))
end

function DodgeGame:updateObjects(dt)
    for i = #self.objects, 1, -1 do
        local obj = self.objects[i]
        
        -- Move object
        if obj.direction == 'right' then
            obj.x = obj.x + self.object_speed * dt
        elseif obj.direction == 'left' then
            obj.x = obj.x - self.object_speed * dt
        elseif obj.direction == 'down' then
            obj.y = obj.y + self.object_speed * dt
        elseif obj.direction == 'up' then
            obj.y = obj.y - self.object_speed * dt
        end
        
        -- Check collision with player
        local dx = obj.x - self.player.x
        local dy = obj.y - self.player.y
        local distance = math.sqrt(dx*dx + dy*dy)
        
        if distance < self.player.size + OBJECT_SIZE then
            -- Collision occurred
            table.remove(self.objects, i)
            self.metrics.collisions = self.metrics.collisions + 1
            if self.metrics.collisions >= 10 then
                self:onComplete()
            end
        elseif self:isObjectOffscreen(obj) then
            -- Object missed player
            table.remove(self.objects, i)
            self.metrics.objects_dodged = self.metrics.objects_dodged + 1
            if obj.warned then
                self.metrics.perfect_dodges = self.metrics.perfect_dodges + 1
            end
        end
    end
end

function DodgeGame:updateWarnings(dt)
    for i = #self.warnings, 1, -1 do
        local warning = self.warnings[i]
        warning.time = warning.time - dt
        if warning.time <= 0 then
            -- Create actual object
            self:createObjectFromWarning(warning)
            table.remove(self.warnings, i)
        end
    end
end

function DodgeGame:spawnObject()
    if self.warning_enabled then
        -- Create warning first
        local warning = self:createWarning()
        table.insert(self.warnings, warning)
    else
        -- Create object directly
        local obj = self:createRandomObject()
        table.insert(self.objects, obj)
    end
end

function DodgeGame:createWarning()
    local is_horizontal = math.random() > 0.5
    local pos, direction
    
    if is_horizontal then
        pos = math.random(OBJECT_SIZE, love.graphics.getHeight() - OBJECT_SIZE)
        direction = math.random() > 0.5 and 'right' or 'left'
    else
        pos = math.random(OBJECT_SIZE, love.graphics.getWidth() - OBJECT_SIZE)
        direction = math.random() > 0.5 and 'down' or 'up'
    end
    
    return {
        type = is_horizontal and 'horizontal' or 'vertical',
        pos = pos,
        direction = direction,
        time = WARNING_TIME / self.difficulty_modifiers.speed
    }
end

function DodgeGame:createObjectFromWarning(warning)
    local obj = {
        direction = warning.direction,
        warned = true
    }
    
    if warning.type == 'horizontal' then
        obj.y = warning.pos
        obj.x = warning.direction == 'right' and -OBJECT_SIZE or love.graphics.getWidth() + OBJECT_SIZE
    else
        obj.x = warning.pos
        obj.y = warning.direction == 'down' and -OBJECT_SIZE or love.graphics.getHeight() + OBJECT_SIZE
    end
    
    table.insert(self.objects, obj)
end

function DodgeGame:createRandomObject()
    local is_horizontal = math.random() > 0.5
    local obj = {
        direction = is_horizontal and (math.random() > 0.5 and 'right' or 'left')
                                or (math.random() > 0.5 and 'down' or 'up'),
        warned = false
    }
    
    if is_horizontal then
        obj.y = math.random(OBJECT_SIZE, love.graphics.getHeight() - OBJECT_SIZE)
        obj.x = obj.direction == 'right' and -OBJECT_SIZE or love.graphics.getWidth() + OBJECT_SIZE
    else
        obj.x = math.random(OBJECT_SIZE, love.graphics.getWidth() - OBJECT_SIZE)
        obj.y = obj.direction == 'down' and -OBJECT_SIZE or love.graphics.getHeight() + OBJECT_SIZE
    end
    
    return obj
end

function DodgeGame:isObjectOffscreen(obj)
    return obj.x < -OBJECT_SIZE or
           obj.x > love.graphics.getWidth() + OBJECT_SIZE or
           obj.y < -OBJECT_SIZE or
           obj.y > love.graphics.getHeight() + OBJECT_SIZE
end

function DodgeGame:checkComplete()
    -- Complete if too many collisions or enough successful dodges
    return self.metrics.collisions >= 10 or
           self.metrics.objects_dodged >= 30 * self.difficulty_modifiers.complexity
end

return DodgeGame