local BaseGame = require('src.games.base_game')
local Collision = require('src.utils.collision') 
local DodgeView = require('src.games.views.dodge_view') -- Added view require
local DodgeGame = BaseGame:extend('DodgeGame')

-- Constants
local PLAYER_SIZE = 20
local PLAYER_RADIUS = PLAYER_SIZE -- Radius derived from size
local PLAYER_SPEED = 300
local OBJECT_SIZE = 15
local OBJECT_RADIUS = OBJECT_SIZE -- Radius derived from size
local BASE_SPAWN_RATE = 1.0     
local BASE_OBJECT_SPEED = 200   
local WARNING_TIME = 0.5        
local MAX_COLLISIONS = 10       
local BASE_DODGE_TARGET = 30    

function DodgeGame:init(game_data, cheats)
    DodgeGame.super.init(self, game_data, cheats) -- Pass cheats to base
    
    -- Apply Cheats
    local speed_modifier = self.cheats.speed_modifier or 1.0
    local advantage_modifier = self.cheats.advantage_modifier or {}
    local extra_collisions = advantage_modifier.collisions or 0

    -- Make constants accessible to view via self
    self.OBJECT_SIZE = OBJECT_SIZE 
    self.MAX_COLLISIONS = MAX_COLLISIONS + extra_collisions -- Apply cheat

    self.player = {
        x = love.graphics.getWidth() / 2, y = love.graphics.getHeight() / 2,
        size = PLAYER_SIZE, radius = PLAYER_RADIUS 
    }

    self.objects = {} 
    self.warnings = {} 

    self.spawn_rate = BASE_SPAWN_RATE / self.difficulty_modifiers.count 
    self.object_speed = (BASE_OBJECT_SPEED * self.difficulty_modifiers.speed) * speed_modifier -- Apply cheat
    self.warning_enabled = self.difficulty_modifiers.complexity <= 2 
    self.dodge_target = math.floor(BASE_DODGE_TARGET * self.difficulty_modifiers.complexity) 

    self.spawn_timer = 0
    
    self.metrics.objects_dodged = 0
    self.metrics.collisions = 0
    self.metrics.perfect_dodges = 0 
    
    -- Create the view instance
    self.view = DodgeView:new(self)
end

function DodgeGame:updateGameLogic(dt)
    self:updatePlayer(dt)

    self.spawn_timer = self.spawn_timer - dt
    if self.spawn_timer <= 0 then
        self:spawnObjectOrWarning()
        self.spawn_timer = self.spawn_rate
    end

    self:updateWarnings(dt)
    self:updateObjects(dt)
end

-- Draw method now delegates to the view
function DodgeGame:draw()
    if self.view then
        self.view:draw()
    end
end


function DodgeGame:updatePlayer(dt)
    local dx, dy = 0, 0
    if love.keyboard.isDown('left', 'a') then dx = dx - 1 end
    if love.keyboard.isDown('right', 'd') then dx = dx + 1 end
    if love.keyboard.isDown('up', 'w') then dy = dy - 1 end
    if love.keyboard.isDown('down', 's') then dy = dy + 1 end

    if dx ~= 0 and dy ~= 0 then
        local inv_sqrt2 = 0.70710678118 
        dx = dx * inv_sqrt2; dy = dy * inv_sqrt2
    end

    self.player.x = self.player.x + dx * PLAYER_SPEED * dt
    self.player.y = self.player.y + dy * PLAYER_SPEED * dt

    self.player.x = math.max(self.player.radius, math.min(love.graphics.getWidth() - self.player.radius, self.player.x))
    self.player.y = math.max(self.player.radius, math.min(love.graphics.getHeight() - self.player.radius, self.player.y))
end

function DodgeGame:updateObjects(dt)
    for i = #self.objects, 1, -1 do
        local obj = self.objects[i]
        if not obj then goto continue_obj_loop end -- Safety check

        if obj.direction == 'right' then obj.x = obj.x + self.object_speed * dt
        elseif obj.direction == 'left' then obj.x = obj.x - self.object_speed * dt
        elseif obj.direction == 'down' then obj.y = obj.y + self.object_speed * dt
        elseif obj.direction == 'up' then obj.y = obj.y - self.object_speed * dt
        end

        if Collision.checkCircles(self.player.x, self.player.y, self.player.radius, obj.x, obj.y, obj.radius) then
            table.remove(self.objects, i)
            self.metrics.collisions = self.metrics.collisions + 1
            if self.metrics.collisions >= self.MAX_COLLISIONS then self:onComplete(); return end
        elseif self:isObjectOffscreen(obj) then
            table.remove(self.objects, i)
            self.metrics.objects_dodged = self.metrics.objects_dodged + 1
            if obj.warned then self.metrics.perfect_dodges = self.metrics.perfect_dodges + 1 end
        end
        ::continue_obj_loop::
    end
end

function DodgeGame:updateWarnings(dt)
    for i = #self.warnings, 1, -1 do
        local warning = self.warnings[i]
        if not warning then goto continue_warn_loop end
        warning.time = warning.time - dt
        if warning.time <= 0 then
            self:createObjectFromWarning(warning)
            table.remove(self.warnings, i)
        end
         ::continue_warn_loop::
    end
end

function DodgeGame:spawnObjectOrWarning()
    if self.warning_enabled then table.insert(self.warnings, self:createWarning())
    else table.insert(self.objects, self:createRandomObject()) end
end

function DodgeGame:createWarning()
    local is_horizontal = math.random() > 0.5
    local pos, direction
    if is_horizontal then
        pos = math.random(OBJECT_RADIUS, love.graphics.getHeight() - OBJECT_RADIUS)
        direction = math.random() > 0.5 and 'right' or 'left'
    else
        pos = math.random(OBJECT_RADIUS, love.graphics.getWidth() - OBJECT_RADIUS)
        direction = math.random() > 0.5 and 'down' or 'up'
    end
    return { type = is_horizontal and 'horizontal' or 'vertical', pos = pos, direction = direction, time = WARNING_TIME / self.difficulty_modifiers.speed }
end

function DodgeGame:createObjectFromWarning(warning)
    local obj = { direction = warning.direction, warned = true, radius = OBJECT_RADIUS }
    if warning.type == 'horizontal' then
        obj.y = warning.pos
        obj.x = (warning.direction == 'right') and -OBJECT_RADIUS or (love.graphics.getWidth() + OBJECT_RADIUS)
    else
        obj.x = warning.pos
        obj.y = (warning.direction == 'down') and -OBJECT_RADIUS or (love.graphics.getHeight() + OBJECT_RADIUS)
    end
    table.insert(self.objects, obj)
end

function DodgeGame:createRandomObject()
    local is_horizontal = math.random() > 0.5
    local direction = is_horizontal and (math.random() > 0.5 and 'right' or 'left') or (math.random() > 0.5 and 'down' or 'up')
    local obj = { direction = direction, warned = false, radius = OBJECT_RADIUS }
    if is_horizontal then
        obj.y = math.random(OBJECT_RADIUS, love.graphics.getHeight() - OBJECT_RADIUS)
        obj.x = (direction == 'right') and -OBJECT_RADIUS or (love.graphics.getWidth() + OBJECT_RADIUS)
    else
        obj.x = math.random(OBJECT_RADIUS, love.graphics.getWidth() - OBJECT_RADIUS)
        obj.y = (direction == 'down') and -OBJECT_RADIUS or (love.graphics.getHeight() + OBJECT_RADIUS)
    end
    return obj
end

function DodgeGame:isObjectOffscreen(obj)
    if not obj then return true end -- Treat nil as offscreen
    return obj.x < -obj.radius or obj.x > love.graphics.getWidth() + obj.radius or
           obj.y < -obj.radius or obj.y > love.graphics.getHeight() + obj.radius
end

function DodgeGame:checkComplete()
    return self.metrics.collisions >= self.MAX_COLLISIONS or self.metrics.objects_dodged >= self.dodge_target
end

function DodgeGame:keypressed(key)
    return false
end

return DodgeGame