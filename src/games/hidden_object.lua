local BaseGame = require('src.games.base_game')
local HiddenObjectView = require('src.games.views.hidden_object_view')
local HiddenObject = BaseGame:extend('HiddenObject')

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function HiddenObject:init(game_data, cheats, di, variant_override)
    HiddenObject.super.init(self, game_data, cheats, di, variant_override)

    local SchemaLoader = self.di.components.SchemaLoader
    local runtimeCfg = self.di.config and self.di.config.games and self.di.config.games.hidden_object
    self.params = SchemaLoader.load(self.variant, "hidden_object_schema", runtimeCfg)

    self:setupGameState()
    self:setupComponents()

    self.view = HiddenObjectView:new(self, self.variant)
    self:loadAssets()  -- Inherits from BaseGame
end

function HiddenObject:setupGameState()
    local p = self.params

    self.game_width = p.arena_width
    self.game_height = p.arena_height

    local speed_mod = self.cheats and self.cheats.speed_modifier or 1.0
    local time_bonus_mult = 1.0 + (1.0 - speed_mod)
    self.time_limit = ((p.time_limit_base / self.difficulty_modifiers.speed) * time_bonus_mult) / p.difficulty_modifier
    self.total_objects = math.floor(p.objects_base * self.difficulty_modifiers.count * p.difficulty_modifier)

    self.time_remaining = self.time_limit
    self.objects_found = 0
    self.objects_remaining = self.total_objects

    self.metrics = {objects_found = 0, time_bonus = 0}
end

function HiddenObject:setupComponents()
    local p = self.params
    local EntityController = self.di.components.EntityController

    self.entity_controller = EntityController:new({
        entity_types = {
            ["hidden_object"] = {
                size = p.object_base_size,
                radius = p.object_base_size / 2,
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
    self:createComponentsFromSchema()

    -- Create victory condition manually since target is runtime-calculated
    local VictoryCondition = self.di.components.VictoryCondition
    self.victory_checker = VictoryCondition:new({
        victory = {type = "threshold", metric = "objects_found", target = self.total_objects},
        loss = {type = "time_expired", metric = "time_remaining"},
        check_loss_first = true
    })
    self.victory_checker.game = self

    -- Resize callback to regenerate deterministic positions
    self.on_resize = function() self:generateObjects() end
end


--------------------------------------------------------------------------------
-- OBJECT MANAGEMENT
--------------------------------------------------------------------------------

function HiddenObject:generateObjects()
    self.entity_controller:clear()

    local positions = self:getDeterministicPositions()
    for i = 1, self.total_objects do
        local pos = positions[i]
        local sprite_variant = math.floor((i - 1) / math.max(1, self.params.sprite_variant_divisor - self.difficulty_modifiers.complexity)) + 1

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

--------------------------------------------------------------------------------
-- MAIN GAME LOOP
--------------------------------------------------------------------------------

function HiddenObject:updateGameLogic(dt)
    if self.objects_found >= self.total_objects and self.metrics.time_bonus == 0 then
        self.metrics.time_bonus = math.floor(math.max(0, self.time_remaining) * self.params.bonus_time_multiplier)
    end
end

function HiddenObject:draw()
    if self.view then
        self.view:draw()
    end
end

--------------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------------

function HiddenObject:keypressed(key)
    HiddenObject.super.keypressed(self, key)
    return false
end

function HiddenObject:mousepressed(x, y, button)
    if self.completed or button ~= 1 then return end

    local click_point = {x = x, y = y, radius = 0}
    local collisions = self.entity_controller:checkCollision(click_point, function(entity)
        if not entity.found then
            local entity_type = self.entity_controller.entity_types[entity.type_name]
            if entity_type and entity_type.on_hit then
                entity_type.on_hit(entity)
            end
        end
    end)

    if #collisions == 0 then
        self:playSound("wrong_click", 0.5)
    end
end

--------------------------------------------------------------------------------
-- GAME STATE / VICTORY
--------------------------------------------------------------------------------

function HiddenObject:checkComplete()
    local result = self.victory_checker:check()
    if result then
        self.victory = (result == "victory")
        self.game_over = (result == "loss")
        return true
    end
    return false
end

function HiddenObject:onComplete()
    if self.completed then return end
    self.metrics.objects_found = self.objects_found

    local is_win = self.objects_found >= self.total_objects

    if self.objects_found < self.total_objects then
        self.metrics.time_bonus = 0
    elseif self.metrics.time_bonus == 0 then
        self.metrics.time_bonus = math.floor(math.max(0, self.time_remaining) * self.params.bonus_time_multiplier)
    end

    if is_win then
        self:playSound("success", 1.0)
    end

    self:stopMusic()

    HiddenObject.super.onComplete(self)
end

return HiddenObject
