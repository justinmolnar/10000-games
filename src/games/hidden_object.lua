local BaseGame = require('src.games.base_game')
local HUDRenderer = require('src.utils.game_components.hud_renderer')
local VictoryCondition = require('src.utils.game_components.victory_condition')
local EntityController = require('src.utils.game_components.entity_controller')
local SchemaLoader = require('src.utils.game_components.schema_loader')
local HiddenObjectView = require('src.games.views.hidden_object_view')
local HiddenObject = BaseGame:extend('HiddenObject')

function HiddenObject:init(game_data, cheats, di, variant_override)
    HiddenObject.super.init(self, game_data, cheats, di, variant_override)
    self.di = di
    self.cheats = cheats or {}

    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.hidden_object)
    self.params = SchemaLoader.load(self.variant, "hidden_object_schema", runtimeCfg)

    self:applyModifiers()
    self:setupGameState()
    self:setupComponents()

    self.view = HiddenObjectView:new(self, self.variant)
    self:loadAssets()
end

function HiddenObject:applyModifiers()
    self.speed_modifier_value = self.cheats.speed_modifier or 1.0
    self.time_bonus_multiplier = 1.0 + (1.0 - self.speed_modifier_value)
    self.variant_difficulty = self.params.difficulty_modifier
end

function HiddenObject:setupGameState()
    self.game_width = self.params.arena_width
    self.game_height = self.params.arena_height

    self.time_limit = ((self.params.time_limit_base / self.difficulty_modifiers.speed) * self.time_bonus_multiplier) / self.variant_difficulty
    self.total_objects = math.floor(self.params.objects_base * self.difficulty_modifiers.count * self.variant_difficulty)

    self.time_remaining = self.time_limit
    self.objects_found = 0
    self.objects_remaining = self.total_objects

    self.metrics.objects_found = 0
    self.metrics.time_bonus = 0
end

function HiddenObject:setupComponents()
    self.entity_controller = EntityController:new({
        entity_types = {
            ["hidden_object"] = {
                size = self.params.object_base_size,
                radius = self.params.object_base_size / 2,
                found = false,
                on_hit = function(entity)
                    entity.found = true
                    self.objects_found = self.objects_found + 1
                    self.objects_remaining = self.objects_remaining - 1
                    self:playSound("find_object", 1.0)
                end
            }
        },
        spawning = {mode = "manual"},
        pooling = false,
        max_entities = 50
    })

    self:generateObjects()

    self.hud = HUDRenderer:new({
        primary = {label = "Found", key = "objects_found"},
        secondary = {label = "Remaining", key = "objects_remaining"},
        timer = {label = "Time", key = "time_remaining", format = "float"}
    })
    self.hud.game = self

    local victory_config = {
        victory = {type = "threshold", metric = "objects_found", target = self.total_objects},
        loss = {type = "time_expired", metric = "time_remaining"},
        check_loss_first = true
    }
    self.victory_checker = VictoryCondition:new(victory_config)
    self.victory_checker.game = self
end

function HiddenObject:loadAssets()
    self.sprites = {}

    if not self.variant or not self.variant.sprite_set then
        return
    end

    local game_type = "hidden_object"
    local base_path = "assets/sprites/games/" .. game_type .. "/" .. self.variant.sprite_set .. "/"

    local function tryLoad(filename, sprite_key)
        local filepath = base_path .. filename
        local success, result = pcall(function()
            return love.graphics.newImage(filepath)
        end)
        if success then
            self.sprites[sprite_key] = result
        end
    end

    tryLoad("background.png", "background")

    for i = 1, 30 do
        local filename = string.format("object_%02d.png", i)
        tryLoad(filename, "object_" .. i)
    end

    self:loadAudio()
end

function HiddenObject:countLoadedSprites()
    local count = 0
    for _ in pairs(self.sprites) do
        count = count + 1
    end
    return count
end

function HiddenObject:hasSprite(sprite_key)
    return self.sprites and self.sprites[sprite_key] ~= nil
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
    local objects = self.entity_controller:getEntities()
    for i = 1, math.min(#objects, #positions) do
        objects[i].x = positions[i].x
        objects[i].y = positions[i].y
    end
end

function HiddenObject:generateObjects()
    -- Clear any existing objects
    self.entity_controller:clear()

    local positions = self:getDeterministicPositions()
    for i = 1, self.total_objects do
        local pos = positions[i]
        local sprite_variant = math.floor((i - 1) / math.max(1, self.params.sprite_variant_divisor - self.difficulty_modifiers.complexity)) + 1

        -- Spawn via EntityController
        self.entity_controller:spawn("hidden_object", pos.x, pos.y, {
            id = i,
            sprite_variant = sprite_variant
        })
    end
end

function HiddenObject:getDeterministicPositions()
    local positions = {}
    local padding = self.params.object_base_size
    for i = 1, self.total_objects do
        local hash_x = (i * self.params.position_hash_x1) % self.params.position_hash_x2
        local hash_y = (i * self.params.position_hash_y1) % self.params.position_hash_y2
        local x = padding + (hash_x / self.params.position_hash_x2) * (self.game_width - 2 * padding)
        local y = padding + (hash_y / self.params.position_hash_y2) * (self.game_height - 2 * padding)
        positions[i] = {x = x, y = y}
    end
    return positions
end

function HiddenObject:updateGameLogic(dt)
    -- Calculate time bonus when all objects found (before completion triggers)
    if self.objects_found >= self.total_objects and self.metrics.time_bonus == 0 then
        self.metrics.time_bonus = math.floor(math.max(0, self.time_remaining) * self.params.bonus_time_multiplier)
    end
end

function HiddenObject:draw()
    if self.view then
        self.view:draw()
    end
end

function HiddenObject:mousepressed(x, y, button)
    if self.completed or button ~= 1 then return end

    local click_point = {x = x, y = y, radius = 0}
    local collisions = self.entity_controller:checkCollision(click_point, function(entity)
        if not entity.found then
            -- Trigger on_hit callback (which marks found and increments counter)
            local entity_type = self.entity_controller.entity_types[entity.type_name]
            if entity_type and entity_type.on_hit then
                entity_type.on_hit(entity)
            end
        end
    end)

    -- Play wrong click sound if no object was clicked
    if #collisions == 0 then
        self:playSound("wrong_click", 0.5)
    end
end

function HiddenObject:onComplete()
    if self.completed then return end
    self.metrics.objects_found = self.objects_found

    -- Determine if win or loss
    local is_win = self.objects_found >= self.total_objects

    -- Only set time bonus to 0 if not all objects found
    if self.objects_found < self.total_objects then
        self.metrics.time_bonus = 0
    elseif self.metrics.time_bonus == 0 then
        -- If all objects found and time_bonus not set, calculate it
        self.metrics.time_bonus = math.floor(math.max(0, self.time_remaining) * self.params.bonus_time_multiplier)
    end

    if is_win then
        self:playSound("success", 1.0)
    end
    -- Note: No death sound for time running out (just silence)

    -- Stop music
    self:stopMusic()

    HiddenObject.super.onComplete(self)
end

function HiddenObject:checkComplete()
    local result = self.victory_checker:check()
    if result then
        self.victory = (result == "victory")
        self.game_over = (result == "loss")
        return true
    end
    return false
end

function HiddenObject:keypressed(key)
    -- Call parent to handle virtual key tracking for demo playback
    HiddenObject.super.keypressed(self, key)
    return false
end

return HiddenObject