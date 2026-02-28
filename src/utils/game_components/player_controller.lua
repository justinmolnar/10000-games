local Object = require('class')
local PlayerController = Object:extend('PlayerController')

-- Unified player state management: lives, health, shields, ammo, heat

PlayerController.MODES = {
    LIVES = "lives",
    HEALTH = "health",
    SHIELD = "shield",
    BINARY = "binary",
    NONE = "none"
}

function PlayerController:init(config)
    -- Core configuration
    self.mode = config.mode or PlayerController.MODES.LIVES

    -- Lives mode configuration
    self.starting_lives = config.starting_lives or 3
    self.max_lives = config.max_lives or 10
    self.lives = self.starting_lives

    -- Health mode configuration
    self.max_health = config.max_health or 100
    self.health = self.max_health

    -- Shield mode configuration
    self.shield_enabled = config.shield_enabled or false
    self.shield_max_hits = config.shield_max_hits or 3
    self.shield_regen_time = config.shield_regen_time or 5.0
    self.shield_regen_delay = config.shield_regen_delay or 2.0

    -- Shield state
    self.shield_active = self.shield_enabled
    self.shield_hits_remaining = self.shield_max_hits
    self.shield_regen_timer = 0
    self.shield_damage_timer = 0

    -- Invincibility configuration
    self.invincibility_on_hit = config.invincibility_on_hit or false
    self.invincibility_duration = config.invincibility_duration or 2.0

    -- Invincibility state
    self.invincible = false
    self.invincibility_timer = 0

    -- Death/respawn state
    self.is_dead = false
    self.respawn_enabled = config.respawn_enabled or false
    self.respawn_delay = config.respawn_delay or 1.0
    self.respawn_timer = 0
    self.waiting_to_respawn = false

    -- Extra life awards
    self.extra_life_enabled = config.extra_life_enabled or false
    self.extra_life_threshold = config.extra_life_threshold or 5000
    self.last_extra_life_threshold = 0

    -- Ammo configuration
    self.ammo_enabled = config.ammo_enabled or false
    self.ammo_capacity = config.ammo_capacity or 30
    self.ammo_reload_time = config.ammo_reload_time or 2.0
    self.auto_reload = config.auto_reload ~= false  -- Default true

    -- Ammo state
    self.ammo = self.ammo_capacity
    self.is_reloading = false
    self.reload_timer = 0

    -- Heat/overheat configuration
    self.heat_enabled = config.heat_enabled or false
    self.heat_per_shot = config.heat_per_shot or 1
    self.heat_threshold = config.heat_threshold or 10
    self.heat_cooldown = config.heat_cooldown or 2.0
    self.heat_dissipation = config.heat_dissipation or 1.0

    -- Heat state
    self.heat = 0
    self.is_overheated = false
    self.overheat_timer = 0

    -- Weapon system
    self.weapons = config.weapons or {}  -- {name = {uses_ammo, fire_rate, ...}}
    self.current_weapon = config.default_weapon or nil
    self.weapon_cooldowns = {}  -- Per-weapon cooldowns

    -- Callbacks
    self.on_damage = config.on_damage
    self.on_death = config.on_death
    self.on_respawn = config.on_respawn
    self.on_life_gained = config.on_life_gained
    self.on_shield_break = config.on_shield_break
    self.on_shield_regen = config.on_shield_regen
    self.on_reload_complete = config.on_reload_complete
    self.on_overheat = config.on_overheat
    self.on_overheat_clear = config.on_overheat_clear
end

function PlayerController:update(dt)
    -- Update invincibility timer
    if self.invincible then
        self.invincibility_timer = self.invincibility_timer - dt
        if self.invincibility_timer <= 0 then
            self.invincible = false
            self.invincibility_timer = 0
        end
    end

    -- Update respawn timer
    if self.waiting_to_respawn then
        self.respawn_timer = self.respawn_timer + dt
        if self.respawn_timer >= self.respawn_delay then
            self:respawn()
        end
    end

    -- Update shield regeneration
    if self.mode == PlayerController.MODES.SHIELD and self.shield_enabled then
        self.shield_damage_timer = self.shield_damage_timer + dt

        if self.shield_damage_timer >= self.shield_regen_delay and self.shield_hits_remaining < self.shield_max_hits then
            self.shield_regen_timer = self.shield_regen_timer + dt

            if self.shield_regen_timer >= self.shield_regen_time then
                self.shield_hits_remaining = self.shield_hits_remaining + 1
                self.shield_regen_timer = 0

                if not self.shield_active and self.shield_hits_remaining > 0 then
                    self.shield_active = true
                    if self.on_shield_regen then self.on_shield_regen() end
                end
            end
        end
    end

    -- Update reload timer
    if self.ammo_enabled and self.is_reloading then
        self.reload_timer = self.reload_timer - dt
        if self.reload_timer <= 0 then
            self.is_reloading = false
            self.ammo = self.ammo_capacity
            if self.on_reload_complete then self.on_reload_complete() end
        end
    end

    -- Update heat/overheat
    if self.heat_enabled then
        if self.is_overheated then
            self.overheat_timer = self.overheat_timer - dt
            if self.overheat_timer <= 0 then
                self.is_overheated = false
                self.heat = 0
                if self.on_overheat_clear then self.on_overheat_clear() end
            end
        elseif self.heat > 0 then
            self.heat = math.max(0, self.heat - dt * self.heat_dissipation)
        end
    end
end

function PlayerController:takeDamage(amount, source)
    amount = amount or 1
    source = source or "unknown"

    if self.invincible or self.is_dead then
        return false
    end

    if self.mode == PlayerController.MODES.BINARY then
        self:die()
        return true
    end

    if self.mode == PlayerController.MODES.NONE then
        return false
    end

    -- Shield absorbs damage
    if self.mode == PlayerController.MODES.SHIELD and self.shield_enabled and self.shield_active then
        self.shield_hits_remaining = self.shield_hits_remaining - amount
        self.shield_damage_timer = 0
        self.shield_regen_timer = 0

        if self.shield_hits_remaining <= 0 then
            self.shield_hits_remaining = 0
            self.shield_active = false
            if self.on_shield_break then self.on_shield_break() end
        end

        if self.on_damage then self.on_damage(amount, source) end
        return true
    end

    -- Health mode
    if self.mode == PlayerController.MODES.HEALTH then
        self.health = self.health - amount

        if self.on_damage then self.on_damage(amount, source) end

        if self.health <= 0 then
            self.health = 0
            self:die()
            return true  -- Player died
        else
            if self.invincibility_on_hit then
                self.invincible = true
                self.invincibility_timer = self.invincibility_duration
            end
        end

        return false  -- Player took damage but didn't die
    end

    -- Lives mode or shield down
    if self.mode == PlayerController.MODES.LIVES or self.mode == PlayerController.MODES.SHIELD then
        self.lives = self.lives - amount

        if self.on_damage then self.on_damage(amount, source) end

        if self.lives <= 0 then
            self.lives = 0
            self:die()
        else
            if self.invincibility_on_hit then
                self.invincible = true
                self.invincibility_timer = self.invincibility_duration
            end
        end

        return true
    end

    return false
end

function PlayerController:die()
    if self.is_dead then return end

    self.is_dead = true

    if self.on_death then self.on_death() end

    if self.respawn_enabled and self.lives > 0 then
        self.waiting_to_respawn = true
        self.respawn_timer = 0
    end
end

function PlayerController:respawn()
    if not self.waiting_to_respawn then return end

    self.is_dead = false
    self.waiting_to_respawn = false
    self.respawn_timer = 0

    if self.invincibility_on_hit then
        self.invincible = true
        self.invincibility_timer = self.invincibility_duration
    end

    if self.on_respawn then self.on_respawn() end
end

function PlayerController:addLife(count)
    count = count or 1

    if self.mode == PlayerController.MODES.LIVES then
        local old_lives = self.lives
        self.lives = math.min(self.lives + count, self.max_lives)

        if self.lives > old_lives then
            if self.on_life_gained then self.on_life_gained(count) end
            return true
        end
    end

    return false
end

function PlayerController:checkExtraLifeAward(score)
    if not self.extra_life_enabled or self.mode ~= PlayerController.MODES.LIVES then
        return false
    end

    local current_threshold = math.floor(score / self.extra_life_threshold) * self.extra_life_threshold

    if current_threshold > self.last_extra_life_threshold then
        self.last_extra_life_threshold = current_threshold
        self:addLife(1)
        return true
    end

    return false
end

function PlayerController:heal(amount)
    if self.mode == PlayerController.MODES.SHIELD and self.shield_enabled then
        local old_hits = self.shield_hits_remaining
        self.shield_hits_remaining = math.min(self.shield_hits_remaining + amount, self.shield_max_hits)

        if not self.shield_active and self.shield_hits_remaining > 0 then
            self.shield_active = true
            if self.on_shield_regen then self.on_shield_regen() end
        end

        return self.shield_hits_remaining > old_hits
    end

    return false
end

-- Ammo methods

function PlayerController:canFire()
    if self.ammo_enabled then
        if self.is_reloading then return false end
        if self.ammo <= 0 then
            if self.auto_reload then self:reload() end
            return false
        end
    end
    if self.heat_enabled and self.is_overheated then return false end
    return true
end

function PlayerController:consumeAmmo(amount)
    amount = amount or 1
    if self.ammo_enabled then
        self.ammo = math.max(0, self.ammo - amount)
        if self.ammo <= 0 and self.auto_reload then
            self:reload()
        end
    end
end

function PlayerController:addHeat(amount)
    amount = amount or self.heat_per_shot
    if self.heat_enabled then
        self.heat = self.heat + amount
        if self.heat >= self.heat_threshold then
            self.is_overheated = true
            self.overheat_timer = self.heat_cooldown
            self.heat = self.heat_threshold
            if self.on_overheat then self.on_overheat() end
        end
    end
end

function PlayerController:onShoot(ammo_cost, heat_amount)
    self:consumeAmmo(ammo_cost or 1)
    self:addHeat(heat_amount or self.heat_per_shot)
end

function PlayerController:reload()
    if not self.ammo_enabled then return end
    if self.is_reloading then return end
    if self.ammo >= self.ammo_capacity then return end

    self.is_reloading = true
    self.reload_timer = self.ammo_reload_time
end

function PlayerController:addAmmo(amount)
    if self.ammo_enabled then
        self.ammo = math.min(self.ammo + amount, self.ammo_capacity)
    end
end

-- Weapon methods

function PlayerController:addWeapon(name, config)
    self.weapons[name] = config
    self.weapon_cooldowns[name] = 0
    if not self.current_weapon then
        self.current_weapon = name
    end
end

function PlayerController:switchWeapon(name)
    if self.weapons[name] then
        self.current_weapon = name
        return true
    end
    return false
end

function PlayerController:nextWeapon()
    local names = {}
    for name, _ in pairs(self.weapons) do
        table.insert(names, name)
    end
    table.sort(names)

    if #names == 0 then return end

    local current_idx = 1
    for i, name in ipairs(names) do
        if name == self.current_weapon then
            current_idx = i
            break
        end
    end

    self.current_weapon = names[(current_idx % #names) + 1]
end

function PlayerController:getWeapon(name)
    return self.weapons[name or self.current_weapon]
end

function PlayerController:getCurrentWeapon()
    return self.current_weapon, self.weapons[self.current_weapon]
end

function PlayerController:hasWeapon(name)
    return self.weapons[name] ~= nil
end

function PlayerController:canFireWeapon(name)
    name = name or self.current_weapon
    local weapon = self.weapons[name]
    if not weapon then return false end

    -- Check cooldown
    if (self.weapon_cooldowns[name] or 0) > 0 then return false end

    -- Check ammo if weapon uses it
    if weapon.uses_ammo then
        if self.ammo_enabled then
            if self.is_reloading then return false end
            if self.ammo < (weapon.ammo_cost or 1) then return false end
        end
    end

    -- Check heat
    if self.heat_enabled and self.is_overheated then return false end

    return true
end

function PlayerController:fireWeapon(name)
    name = name or self.current_weapon
    local weapon = self.weapons[name]
    if not weapon then return nil end

    -- Set cooldown
    local fire_rate = weapon.fire_rate or 3
    self.weapon_cooldowns[name] = 1 / fire_rate

    -- Consume ammo if needed
    if weapon.uses_ammo and self.ammo_enabled then
        self:consumeAmmo(weapon.ammo_cost or 1)
    end

    -- Add heat if enabled
    if self.heat_enabled then
        self:addHeat(weapon.heat_per_shot or self.heat_per_shot)
    end

    return weapon
end

function PlayerController:updateWeaponCooldowns(dt)
    for name, cooldown in pairs(self.weapon_cooldowns) do
        if cooldown > 0 then
            self.weapon_cooldowns[name] = cooldown - dt
        end
    end
end

-- Getters

function PlayerController:isAlive()
    return not self.is_dead
end

function PlayerController:isInvincible()
    return self.invincible
end

function PlayerController:getShieldStrength()
    if self.mode == PlayerController.MODES.SHIELD and self.shield_enabled then
        return self.shield_hits_remaining / self.shield_max_hits
    end
    return 0
end

function PlayerController:getShieldHitsRemaining()
    if self.mode == PlayerController.MODES.SHIELD and self.shield_enabled then
        return self.shield_hits_remaining
    end
    return 0
end

function PlayerController:isShieldActive()
    return self.shield_enabled and self.shield_active
end

function PlayerController:getLives()
    return self.lives
end

function PlayerController:setLives(count)
    self.lives = math.max(0, math.min(count, self.max_lives))
end

function PlayerController:getAmmo()
    return self.ammo
end

function PlayerController:getAmmoCapacity()
    return self.ammo_capacity
end

function PlayerController:isReloading()
    return self.is_reloading
end

function PlayerController:getReloadProgress()
    if not self.is_reloading then return 1 end
    return 1 - (self.reload_timer / self.ammo_reload_time)
end

function PlayerController:getHeat()
    return self.heat
end

function PlayerController:getHeatPercent()
    if not self.heat_enabled then return 0 end
    return self.heat / self.heat_threshold
end

function PlayerController:isOverheated()
    return self.is_overheated
end

function PlayerController:getOverheatProgress()
    if not self.is_overheated then return 1 end
    return 1 - (self.overheat_timer / self.heat_cooldown)
end

function PlayerController:reset()
    self.lives = self.starting_lives
    self.is_dead = false
    self.invincible = false
    self.invincibility_timer = 0
    self.waiting_to_respawn = false
    self.respawn_timer = 0
    self.last_extra_life_threshold = 0

    -- Reset shield
    if self.shield_enabled then
        self.shield_active = true
        self.shield_hits_remaining = self.shield_max_hits
        self.shield_regen_timer = 0
        self.shield_damage_timer = 0
    end

    -- Reset ammo
    if self.ammo_enabled then
        self.ammo = self.ammo_capacity
        self.is_reloading = false
        self.reload_timer = 0
    end

    -- Reset heat
    if self.heat_enabled then
        self.heat = 0
        self.is_overheated = false
        self.overheat_timer = 0
    end
end

return PlayerController
