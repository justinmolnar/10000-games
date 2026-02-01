--[[
ProjectileSystem - Minimal projectile management

Handles:
- Spawning projectiles with object pooling
- Lifetime tracking
- Basic linear movement (x += vx*dt, y += vy*dt)
- Out-of-bounds removal
- Team-based filtering

Games handle:
- Fire modes, patterns, cooldowns (game logic)
- Homing/complex movement (use pattern_movement)
- Collision detection (use physics_utils)
- Resource systems like ammo/heat
]]

local Object = require('class')
local ProjectileSystem = Object:extend('ProjectileSystem')

function ProjectileSystem:new(config)
    if not config then error("ProjectileSystem: config required") end
    if not config.max_projectiles then error("ProjectileSystem: max_projectiles required") end
    if not config.out_of_bounds_margin then error("ProjectileSystem: out_of_bounds_margin required") end

    local instance = ProjectileSystem.super.new(self)

    instance.max_projectiles = config.max_projectiles
    instance.out_of_bounds_margin = config.out_of_bounds_margin
    instance.pooling = config.pooling ~= false  -- Default true

    instance.projectiles = {}
    instance.count = 0
    instance.pool = {}

    return instance
end

--[[
Spawn a projectile

@param config table - {x, y, vx, vy, lifetime, team, radius, width, height, ...}
    Required: x, y, vx, vy, lifetime
    Optional: team, radius, width, height, any custom data
@return table - The spawned projectile, or nil if at capacity
]]
function ProjectileSystem:spawn(config)
    if not config then error("ProjectileSystem:spawn: config required") end
    if not config.x then error("ProjectileSystem:spawn: x required") end
    if not config.y then error("ProjectileSystem:spawn: y required") end
    if config.vx == nil then error("ProjectileSystem:spawn: vx required") end
    if config.vy == nil then error("ProjectileSystem:spawn: vy required") end
    if not config.lifetime then error("ProjectileSystem:spawn: lifetime required") end

    if self.count >= self.max_projectiles then
        return nil  -- At capacity
    end

    -- Get from pool or create new
    local projectile
    if self.pooling and #self.pool > 0 then
        projectile = table.remove(self.pool)
        -- Clear old data
        for k in pairs(projectile) do
            projectile[k] = nil
        end
    else
        projectile = {}
    end

    -- Copy all config properties
    for k, v in pairs(config) do
        projectile[k] = v
    end

    projectile.lifetime_remaining = config.lifetime
    projectile.active = true

    table.insert(self.projectiles, projectile)
    self.count = self.count + 1

    return projectile
end

--[[
Remove a projectile

@param projectile table - The projectile to remove
@return boolean - true if removed, false if not found
]]
function ProjectileSystem:remove(projectile)
    for i, p in ipairs(self.projectiles) do
        if p == projectile then
            table.remove(self.projectiles, i)
            self.count = self.count - 1

            if self.pooling then
                projectile.active = false
                table.insert(self.pool, projectile)
            end

            return true
        end
    end
    return false
end

--[[
Update all projectiles: linear movement, lifetime, bounds check

@param dt number - Delta time
@param bounds table - {x, y, width, height} or {x_min, x_max, y_min, y_max}
]]
function ProjectileSystem:update(dt, bounds)
    if not bounds then error("ProjectileSystem:update: bounds required") end

    -- Normalize bounds
    local x_min = bounds.x_min or bounds.x or 0
    local x_max = bounds.x_max or (x_min + (bounds.width or 0))
    local y_min = bounds.y_min or bounds.y or 0
    local y_max = bounds.y_max or (y_min + (bounds.height or 0))

    local margin = self.out_of_bounds_margin

    for i = #self.projectiles, 1, -1 do
        local p = self.projectiles[i]

        if p.active then
            -- Lifetime
            p.lifetime_remaining = p.lifetime_remaining - dt
            if p.lifetime_remaining <= 0 then
                self:remove(p)
                goto continue
            end

            -- Linear movement
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt

            -- Bounds check
            if p.x < x_min - margin or p.x > x_max + margin or
               p.y < y_min - margin or p.y > y_max + margin then
                self:remove(p)
            end
        end

        ::continue::
    end
end

--[[
Get all active projectiles
]]
function ProjectileSystem:getAll()
    local active = {}
    for _, p in ipairs(self.projectiles) do
        if p.active then
            table.insert(active, p)
        end
    end
    return active
end

--[[
Get projectiles by team
]]
function ProjectileSystem:getByTeam(team)
    local result = {}
    for _, p in ipairs(self.projectiles) do
        if p.active and p.team == team then
            table.insert(result, p)
        end
    end
    return result
end

--[[
Clear all projectiles
]]
function ProjectileSystem:clear()
    if self.pooling then
        for _, p in ipairs(self.projectiles) do
            p.active = false
            table.insert(self.pool, p)
        end
    end
    self.projectiles = {}
    self.count = 0
end

--[[
Get count of active projectiles
]]
function ProjectileSystem:getCount()
    return self.count
end

return ProjectileSystem
