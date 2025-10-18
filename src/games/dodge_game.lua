local BaseGame = require('src.games.base_game')
local Collision = require('src.utils.collision')
local DodgeView = require('src.games.views.dodge_view')
local DodgeGame = BaseGame:extend('DodgeGame')

-- Constants
local PLAYER_SIZE = 20
local PLAYER_RADIUS = PLAYER_SIZE
local PLAYER_SPEED = 300
local OBJECT_SIZE = 15 -- Base size
local OBJECT_RADIUS = OBJECT_SIZE -- Base radius
local BASE_SPAWN_RATE = 1.0
local BASE_OBJECT_SPEED = 200
local WARNING_TIME = 0.5
local MAX_COLLISIONS = 10
local BASE_DODGE_TARGET = 30
-- Define native dimensions clearly
local NATIVE_WIDTH = 1920
local NATIVE_HEIGHT = 1080

function DodgeGame:init(game_data, cheats)
    DodgeGame.super.init(self, game_data, cheats)

    -- Apply Cheats
    local speed_modifier = self.cheats.speed_modifier or 1.0
    local advantage_modifier = self.cheats.advantage_modifier or {}
    local extra_collisions = advantage_modifier.collisions or 0

    -- Use defined native dimensions
    self.canvas_width = NATIVE_WIDTH
    self.canvas_height = NATIVE_HEIGHT
    self.OBJECT_SIZE = OBJECT_SIZE -- Pass base size to view if needed
    self.MAX_COLLISIONS = MAX_COLLISIONS + extra_collisions

    -- Initialize player at CENTER of native canvas
    self.player = {
        x = self.canvas_width / 2,
        y = self.canvas_height / 2,
        size = PLAYER_SIZE,
        radius = PLAYER_RADIUS
    }

    self.objects = {}
    self.warnings = {}

    self.spawn_rate = BASE_SPAWN_RATE / self.difficulty_modifiers.count
    self.object_speed = (BASE_OBJECT_SPEED * self.difficulty_modifiers.speed) * speed_modifier
    self.warning_enabled = self.difficulty_modifiers.complexity <= 2
    self.dodge_target = math.floor(BASE_DODGE_TARGET * self.difficulty_modifiers.complexity)

    self.spawn_timer = 0

    self.metrics.objects_dodged = 0
    self.metrics.collisions = 0
    self.metrics.perfect_dodges = 0

    -- Pass self (game instance) to the view
    self.view = DodgeView:new(self)
    print("[DodgeGame:init] Initialized with canvas dimensions:", self.canvas_width, self.canvas_height)
end

function DodgeGame:updateGameLogic(dt)
    self:updatePlayer(dt)

    self.spawn_timer = self.spawn_timer - dt
    if self.spawn_timer <= 0 then
        self:spawnObjectOrWarning()
        -- Reset timer based on spawn rate, prevent negative accumulation
        self.spawn_timer = self.spawn_rate + self.spawn_timer
    end

    self:updateWarnings(dt)
    self:updateObjects(dt)
end

-- Draw delegates entirely to the view
function DodgeGame:draw()
    if self.view and self.view.draw then
        -- Add push/pop specifically around the view's draw call for extra safety
        love.graphics.push()
        self.view:draw()
        love.graphics.pop()
    else
        love.graphics.setColor(1,0,0)
        love.graphics.print("Error: DodgeView not loaded or has no draw function.", 10, 100)
    end
end

function DodgeGame:updatePlayer(dt)
    local dx, dy = 0, 0
    if love.keyboard.isDown('left', 'a') then dx = dx - 1 end
    if love.keyboard.isDown('right', 'd') then dx = dx + 1 end
    if love.keyboard.isDown('up', 'w') then dy = dy - 1 end
    if love.keyboard.isDown('down', 's') then dy = dy + 1 end

    -- Normalize diagonal movement
    if dx ~= 0 and dy ~= 0 then
        local inv_sqrt2 = 0.70710678118
        dx = dx * inv_sqrt2; dy = dy * inv_sqrt2
    end

    self.player.x = self.player.x + dx * PLAYER_SPEED * dt
    self.player.y = self.player.y + dy * PLAYER_SPEED * dt

    -- Clamp to native canvas bounds
    self.player.x = math.max(self.player.radius, math.min(self.canvas_width - self.player.radius, self.player.x))
    self.player.y = math.max(self.player.radius, math.min(self.canvas_height - self.player.radius, self.player.y))
end

function DodgeGame:updateObjects(dt)
    for i = #self.objects, 1, -1 do
        local obj = self.objects[i]
        if not obj then goto continue_obj_loop end

        -- Update position based on direction
        if obj.direction == 'right' then obj.x = obj.x + self.object_speed * dt
        elseif obj.direction == 'left' then obj.x = obj.x - self.object_speed * dt
        elseif obj.direction == 'down' then obj.y = obj.y + self.object_speed * dt
        elseif obj.direction == 'up' then obj.y = obj.y - self.object_speed * dt
        end

        -- Check collision with player
        if Collision.checkCircles(self.player.x, self.player.y, self.player.radius, obj.x, obj.y, obj.radius) then
            table.remove(self.objects, i)
            self.metrics.collisions = self.metrics.collisions + 1
            if self.metrics.collisions >= self.MAX_COLLISIONS then self:onComplete(); return end -- Game over
        -- Check if offscreen (using native dimensions)
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
    else table.insert(self.objects, self:createRandomObject(false)) end -- Pass warned=false
end

function DodgeGame:createWarning()
    local is_horizontal = math.random() > 0.5
    local pos, direction
    local current_object_radius = OBJECT_RADIUS -- Use base radius for warning positioning
    if is_horizontal then
        pos = math.random(current_object_radius, self.canvas_height - current_object_radius)
        direction = math.random() > 0.5 and 'right' or 'left'
    else
        pos = math.random(current_object_radius, self.canvas_width - current_object_radius)
        direction = math.random() > 0.5 and 'down' or 'up'
    end
    -- Adjust warning time based on difficulty speed modifier
    local warning_duration = WARNING_TIME / self.difficulty_modifiers.speed
    return { type = is_horizontal and 'horizontal' or 'vertical', pos = pos, direction = direction, time = warning_duration }
end

function DodgeGame:createObjectFromWarning(warning)
    self:createObject(warning.pos, warning.direction, warning.type == 'horizontal', true) -- Pass warned=true
end

function DodgeGame:createRandomObject(warned_status)
    local is_horizontal = math.random() > 0.5
    local direction = is_horizontal and (math.random() > 0.5 and 'right' or 'left') or (math.random() > 0.5 and 'down' or 'up')
    local pos
    local current_object_radius = OBJECT_RADIUS -- Use base radius
    if is_horizontal then
        pos = math.random(current_object_radius, self.canvas_height - current_object_radius)
    else
        pos = math.random(current_object_radius, self.canvas_width - current_object_radius)
    end
    self:createObject(pos, direction, is_horizontal, warned_status)
end

-- Unified object creation function
function DodgeGame:createObject(position, direction, is_horizontal, was_warned)
    local obj = {
        direction = direction,
        warned = was_warned,
        radius = OBJECT_RADIUS -- Use consistent radius
    }
    if is_horizontal then
        obj.y = position
        obj.x = (direction == 'right') and -obj.radius or (self.canvas_width + obj.radius)
    else
        obj.x = position
        obj.y = (direction == 'down') and -obj.radius or (self.canvas_height + obj.radius)
    end
    table.insert(self.objects, obj)
end


function DodgeGame:isObjectOffscreen(obj)
    if not obj then return true end
    -- Check against native canvas dimensions
    return obj.x < -obj.radius or obj.x > self.canvas_width + obj.radius or
           obj.y < -obj.radius or obj.y > self.canvas_height + obj.radius
end

function DodgeGame:checkComplete()
    -- Check game completion conditions
    return self.metrics.collisions >= self.MAX_COLLISIONS or self.metrics.objects_dodged >= self.dodge_target
end

function DodgeGame:keypressed(key)
    -- Dodge game doesn't use specific key presses other than movement handled in update
    return false
end

return DodgeGame