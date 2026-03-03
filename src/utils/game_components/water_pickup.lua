local Object = require('class')
local WaterPickup = Object:extend('WaterPickup')

function WaterPickup:init(config)
    if not config then error("WaterPickup: config required") end
    if not config.spawn_interval then error("WaterPickup: spawn_interval required") end
    if not config.spawn_chance then error("WaterPickup: spawn_chance required") end
    if not config.value then error("WaterPickup: value required") end
    if not config.collection_radius then error("WaterPickup: collection_radius required") end

    self.spawn_interval = config.spawn_interval
    self.spawn_chance = config.spawn_chance
    self.lifetime = config.lifetime  -- nil = lives forever
    self.value = config.value
    self.collection_radius = config.collection_radius
    self.max_active = config.max_active or 1

    self.on_collect = config.on_collect
    self.on_spawn = config.on_spawn
    self.on_despawn = config.on_despawn

    self.chance_increment = config.chance_increment or 0
    self.base_chance = config.spawn_chance
    self.current_chance = self.base_chance

    self.spawn_timer = 0
    self.bounds = nil

    -- Universal water collect sound
    local ok, src = pcall(love.audio.newSource, "assets/audio/sfx/shared/toilet/eat.mp3", "static")
    self._collect_sound = ok and src or nil
end

function WaterPickup:update(dt, skip_timer)
    local ec = self.game.entity_controller
    local waters = ec:getEntitiesByCategory("water")
    for i = #waters, 1, -1 do
        local entity = waters[i]
        entity.age = (entity.age or 0) + dt

        -- Apply velocity for falling water drops
        if entity.vy and entity.vy ~= 0 then
            entity.y = entity.y + entity.vy * dt
        end
        if entity.vx and entity.vx ~= 0 then
            entity.x = entity.x + entity.vx * dt
        end

        -- Remove if expired or fell out of bounds
        local bounds_h = self.bounds and (self.bounds.y + self.bounds.h) or 9999
        local lifetime = entity.water_lifetime or self.lifetime
        local expired = lifetime and entity.age >= lifetime
        if expired or entity.y > bounds_h then
            if self.on_despawn then self.on_despawn(entity) end
            ec:removeEntity(entity, "expired")
        end
    end

    if not skip_timer then
        self.spawn_timer = self.spawn_timer + dt
        if self.spawn_timer >= self.spawn_interval then
            self.spawn_timer = self.spawn_timer - self.spawn_interval
            self:trySpawn()
        end
    end
end

function WaterPickup:rollChance()
    local roll = self.game.rng:random()
    if roll <= self.current_chance then
        self.current_chance = self.base_chance
        return true
    end
    self.current_chance = math.min(1.0, self.current_chance + self.chance_increment)
    return false
end

function WaterPickup:trySpawn()
    local ec = self.game.entity_controller
    if #ec:getEntitiesByCategory("water") >= self.max_active then return nil end
    if not self.bounds then return nil end

    if not self:rollChance() then return nil end

    local x = self.bounds.x + self.game.rng:random() * self.bounds.w
    local y = self.bounds.y + self.game.rng:random() * self.bounds.h

    local entity = ec:spawn("water", x, y, {
        age = 0,
        water_lifetime = self.lifetime,
        value = self.value,
    })
    if entity then
        if self.on_spawn then self.on_spawn(entity) end
    end
    return entity
end

function WaterPickup:spawnAt(x, y, params)
    local ec = self.game.entity_controller
    if #ec:getEntitiesByCategory("water") >= self.max_active then return nil end

    local entity = ec:spawn("water", x, y, {
        age = 0,
        water_lifetime = self.lifetime,
        value = self.value,
        vx = params and params.vx or 0,
        vy = params and params.vy or 0,
    })
    if entity and self.on_spawn then self.on_spawn(entity) end
    return entity
end

function WaterPickup:playCollectSound()
    if self._collect_sound then
        local clone = self._collect_sound:clone()
        clone:setVolume(0.6)
        clone:play()
    end
end

function WaterPickup:checkClick(x, y)
    local r2 = self.collection_radius * self.collection_radius
    local waters = self.game.entity_controller:getEntitiesByCategory("water")
    for _, entity in ipairs(waters) do
        local dx = entity.x - x
        local dy = entity.y - y
        if dx * dx + dy * dy <= r2 then
            if self.on_collect then self.on_collect(entity) end
            self:playCollectSound()
            self.game.entity_controller:removeEntity(entity, "collected")
            return true
        end
    end
    return false
end

function WaterPickup:setBounds(x, y, w, h)
    self.bounds = { x = x, y = y, w = w, h = h }
end

function WaterPickup:clear()
    local waters = self.game.entity_controller:getEntitiesByCategory("water")
    for i = #waters, 1, -1 do
        self.game.entity_controller:removeEntity(waters[i], "cleared")
    end
    self.spawn_timer = 0
end

function WaterPickup:getActivePickups()
    return self.game.entity_controller:getEntitiesByCategory("water")
end

function WaterPickup:hasActivePickup()
    return #self.game.entity_controller:getEntitiesByCategory("water") > 0
end

return WaterPickup
