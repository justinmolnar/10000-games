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
                centered = true,
                found = false
            }
        },
        spawning = {mode = "manual"},
        pooling = false,
        max_entities = 50
    })

    self:spawnObjects()
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
    self.on_resize = function()
        self.entity_controller:clear()
        self:spawnObjects()
    end
end

function HiddenObject:spawnObjects()
    local p = self.params
    local divisor = math.max(1, p.sprite_variant_divisor - self.difficulty_modifiers.complexity)
    local entity_type = self.entity_controller.entity_types["hidden_object"]
    local size = entity_type and (entity_type.size or entity_type.width or 20) or 20
    local padding = size

    local hash_x1 = p.position_hash_x1 or 17
    local hash_x2 = p.position_hash_x2 or 47
    local hash_y1 = p.position_hash_y1 or 23
    local hash_y2 = p.position_hash_y2 or 53

    for i = 1, self.total_objects do
        local hx = (i * hash_x1) % hash_x2
        local hy = (i * hash_y1) % hash_y2
        local x = padding + (hx / hash_x2) * (self.game_width - 2 * padding)
        local y = padding + (hy / hash_y2) * (self.game_height - 2 * padding)
        self.entity_controller:spawn("hidden_object", x, y, {
            id = i, sprite_variant = math.floor((i - 1) / divisor) + 1
        })
    end
end

function HiddenObject:mousepressed(x, y, button)
    if self.completed or button ~= 1 then return end

    local entity = self.entity_controller:getEntityAtPoint(x, y, "hidden_object")
    if entity and not entity.found then
        entity.found = true
        self.objects_found = self.objects_found + 1
        self.objects_remaining = self.objects_remaining - 1
        self:playSound("find_object", 1.0)
    elseif not entity then
        self:playSound("wrong_click", 0.5)
    end
end

function HiddenObject:onComplete()
    self.metrics.objects_found = self.objects_found
    self.metrics.time_bonus = self.victory and math.floor(math.max(0, self.time_remaining) * self.params.bonus_time_multiplier) or 0
    HiddenObject.super.onComplete(self)
end

return HiddenObject
