local BaseGame = require('src.games.base_game')
local Config = require('src.config')
local Collision = require('src.utils.collision') 
local HiddenObjectView = require('src.games.views.hidden_object_view')
local HiddenObject = BaseGame:extend('HiddenObject')

-- Config-driven defaults with safe fallbacks
local HOCfg = (Config and Config.games and Config.games.hidden_object) or {}
local TIME_LIMIT_BASE = (HOCfg.time and HOCfg.time.base_limit) or 60
local OBJECTS_BASE = (HOCfg.objects and HOCfg.objects.base_count) or 5
local BONUS_TIME_MULTIPLIER = (HOCfg.time and HOCfg.time.bonus_multiplier) or 5
local OBJECT_BASE_SIZE = (HOCfg.objects and HOCfg.objects.base_size) or 20
local BACKGROUND_GRID_BASE = (HOCfg.background and HOCfg.background.grid_base) or 10
local POSITION_HASH_X1 = (HOCfg.background and HOCfg.background.position_hash and HOCfg.background.position_hash.x1) or 17
local POSITION_HASH_X2 = (HOCfg.background and HOCfg.background.position_hash and HOCfg.background.position_hash.x2) or 47
local POSITION_HASH_Y1 = (HOCfg.background and HOCfg.background.position_hash and HOCfg.background.position_hash.y1) or 23
local POSITION_HASH_Y2 = (HOCfg.background and HOCfg.background.position_hash and HOCfg.background.position_hash.y2) or 53
local BACKGROUND_HASH_1 = (HOCfg.background and HOCfg.background.background_hash and HOCfg.background.background_hash.h1) or 17
local BACKGROUND_HASH_2 = (HOCfg.background and HOCfg.background.background_hash and HOCfg.background.background_hash.h2) or 3

function HiddenObject:init(game_data, cheats)
    HiddenObject.super.init(self, game_data, cheats)
    
    local speed_modifier_value = self.cheats.speed_modifier or 1.0
    local time_bonus_multiplier = 1.0 + (1.0 - speed_modifier_value)

    self.BACKGROUND_GRID_BASE = BACKGROUND_GRID_BASE
    self.BACKGROUND_HASH_1 = BACKGROUND_HASH_1
    self.BACKGROUND_HASH_2 = BACKGROUND_HASH_2

    self.game_width = (HOCfg.arena and HOCfg.arena.width) or 800
    self.game_height = (HOCfg.arena and HOCfg.arena.height) or 600

    self.time_limit = (TIME_LIMIT_BASE / self.difficulty_modifiers.speed) * time_bonus_multiplier
    self.total_objects = math.floor(OBJECTS_BASE * self.difficulty_modifiers.count) 
    
    self.time_remaining = self.time_limit
    self.objects_found = 0
    self.objects = self:generateObjects() 
    
    self.metrics.objects_found = 0
    self.metrics.time_bonus = 0
    
    self.view = HiddenObjectView:new(self)
    print("[HiddenObject:init] Initialized with default game dimensions:", self.game_width, self.game_height)
end

function HiddenObject:setPlayArea(width, height)
    self.game_width = width
    self.game_height = height
    
    -- Only regenerate if objects exist
    if self.objects and #self.objects > 0 then
        self:regenerateObjects()
        print("[HiddenObject] Play area updated to:", width, height)
    else
        print("[HiddenObject] setPlayArea called before init completed")
    end
end

function HiddenObject:regenerateObjects()
    local positions = self:getDeterministicPositions()
    for i = 1, math.min(self.total_objects, #positions) do
        if self.objects[i] then
            self.objects[i].x = positions[i].x
            self.objects[i].y = positions[i].y
        end
    end
end

function HiddenObject:generateObjects()
    local objects = {}
    local positions = self:getDeterministicPositions()
    for i = 1, self.total_objects do
        local pos = positions[i]
        objects[i] = {
            id = i, x = pos.x, y = pos.y,
            size = OBJECT_BASE_SIZE, radius = OBJECT_BASE_SIZE / 2, 
            found = false,
            sprite_variant = math.floor((i - 1) / math.max(1, ((HOCfg.objects and HOCfg.objects.sprite_variant_divisor_base) or 5) - self.difficulty_modifiers.complexity)) + 1 
        }
    end
    return objects
end

function HiddenObject:getDeterministicPositions()
    local positions = {}
    local padding = OBJECT_BASE_SIZE 
    for i = 1, self.total_objects do
        local hash_x = (i * POSITION_HASH_X1) % POSITION_HASH_X2
        local hash_y = (i * POSITION_HASH_Y1) % POSITION_HASH_Y2
        local x = padding + (hash_x / POSITION_HASH_X2) * (self.game_width - 2 * padding)
        local y = padding + (hash_y / POSITION_HASH_Y2) * (self.game_height - 2 * padding)
        positions[i] = {x = x, y = y}
    end
    return positions
end

function HiddenObject:updateGameLogic(dt)
    -- Calculate time bonus when all objects found (before completion triggers)
    if self.objects_found >= self.total_objects and self.metrics.time_bonus == 0 then
        self.metrics.time_bonus = math.floor(math.max(0, self.time_remaining) * BONUS_TIME_MULTIPLIER)
    end
end

function HiddenObject:draw()
    if self.view then
        self.view:draw()
    end
end

function HiddenObject:mousepressed(x, y, button)
    if self.completed or button ~= 1 then return end 

    for i = #self.objects, 1, -1 do
        local obj = self.objects[i]
        if not obj.found and self:checkObjectClick(obj, x, y) then
            obj.found = true
            self.objects_found = self.objects_found + 1
            return
        end
    end
end

function HiddenObject:checkObjectClick(obj, x, y)
    return Collision.checkCircles(obj.x, obj.y, obj.radius, x, y, 0)
end

function HiddenObject:onComplete()
    if self.completed then return end
    self.metrics.objects_found = self.objects_found
    -- Only set time bonus to 0 if not all objects found
    if self.objects_found < self.total_objects then
        self.metrics.time_bonus = 0
    elseif self.metrics.time_bonus == 0 then
        -- If all objects found and time_bonus not set, calculate it
        self.metrics.time_bonus = math.floor(math.max(0, self.time_remaining) * BONUS_TIME_MULTIPLIER)
    end
    HiddenObject.super.onComplete(self)
end

function HiddenObject:checkComplete()
    return self.objects_found >= self.total_objects or self.time_remaining <= 0
end

function HiddenObject:keypressed(key)
    return false
end

return HiddenObject