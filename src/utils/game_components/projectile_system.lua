--[[
ProjectileSystem - Phase 12: Generic projectile/bullet system

Handles:
- Projectile type definitions (player bullets, enemy bullets, balls, etc.)
- Firing/spawning projectiles
- Movement patterns (linear, homing, sine wave, bounce)
- Lifetime tracking
- Collision detection with targets
- Object pooling for performance
- Team-based friendly fire logic

Usage:
    local ProjectileSystem = require('src.utils.game_components.projectile_system')

    self.projectile_system = ProjectileSystem:new({
        projectile_types = {
            ["player_bullet"] = {
                speed = 400,
                damage = 1,
                radius = 3,
                lifetime = 5.0,
                team = "player",
                piercing = false,
                on_hit = function(projectile, target) ... end
            }
        },
        pooling = true,
        max_projectiles = 500
    })

    -- Fire projectile:
    self.projectile_system:shoot("player_bullet", x, y, angle)

    -- Update & collision:
    self.projectile_system:update(dt, game_bounds)
    self.projectile_system:checkCollisions(enemies, function(projectile, enemy) ... end)

    -- Render:
    self.projectile_system:draw(function(projectile) ... end)
]]

local Object = require('class')
local ProjectileSystem = Object:extend('ProjectileSystem')

-- Movement types
ProjectileSystem.MOVEMENT_TYPES = {
    LINEAR = "linear",
    HOMING = "homing",
    HOMING_NEAREST = "homing_nearest",
    SINE_WAVE = "sine_wave",
    BOUNCE = "bounce",
    ARC = "arc"
}

function ProjectileSystem:new(config)
    local instance = ProjectileSystem.super.new(self)

    -- Core configuration
    instance.projectile_types = config.projectile_types or {}
    instance.pooling = config.pooling ~= false  -- Default true
    instance.max_projectiles = config.max_projectiles or 500

    -- Active projectiles
    instance.projectiles = {}
    instance.projectile_count = 0

    -- Object pool
    instance.projectile_pool = {}

    -- Ammo system: {enabled, capacity, reload_time}
    instance.ammo = config.ammo
    instance.ammo_current = instance.ammo and instance.ammo.capacity or 0
    instance.reload_timer = 0
    instance.is_reloading = false

    -- Heat system: {enabled, max, cooldown, dissipation}
    instance.heat = config.heat
    instance.heat_current = 0
    instance.overheat_timer = 0
    instance.is_overheated = false

    return instance
end

function ProjectileSystem:canShoot()
    if self.ammo and self.ammo.enabled then
        if self.is_reloading then return false end
        if self.ammo_current <= 0 then
            self.is_reloading = true
            self.reload_timer = self.ammo.reload_time
            return false
        end
    end
    if self.heat and self.heat.enabled and self.is_overheated then
        return false
    end
    return true
end

function ProjectileSystem:onShoot()
    if self.ammo and self.ammo.enabled then
        self.ammo_current = self.ammo_current - 1
    end
    if self.heat and self.heat.enabled then
        self.heat_current = self.heat_current + 1
        if self.heat_current >= self.heat.max then
            self.is_overheated = true
            self.overheat_timer = self.heat.cooldown
            self.heat_current = self.heat.max
        end
    end
end

function ProjectileSystem:updateResources(dt)
    if self.ammo and self.ammo.enabled then
        if self.is_reloading then
            self.reload_timer = self.reload_timer - dt
            if self.reload_timer <= 0 then
                self.is_reloading = false
                self.ammo_current = self.ammo.capacity
            end
        end
    end
    if self.heat and self.heat.enabled then
        if self.is_overheated then
            self.overheat_timer = self.overheat_timer - dt
            if self.overheat_timer <= 0 then
                self.is_overheated = false
                self.heat_current = 0
            end
        elseif self.heat_current > 0 then
            self.heat_current = math.max(0, self.heat_current - dt * (self.heat.dissipation or 1))
        end
    end
end

function ProjectileSystem:reload()
    if self.ammo and self.ammo.enabled and not self.is_reloading and self.ammo_current < self.ammo.capacity then
        self.is_reloading = true
        self.reload_timer = self.ammo.reload_time
    end
end

--[[
    Shoot/spawn a projectile

    @param type_name string - Key from projectile_types
    @param x number - Spawn X position
    @param y number - Spawn Y position
    @param angle number - Direction in radians
    @param speed_multiplier number (optional) - Override speed
    @param custom_params table (optional) - Override defaults
    @return table - The spawned projectile
]]
function ProjectileSystem:shoot(type_name, x, y, angle, speed_multiplier, custom_params)
    if self.projectile_count >= self.max_projectiles then
        return nil  -- At capacity
    end

    local projectile_type = self.projectile_types[type_name]
    if not projectile_type then
        error("Unknown projectile type: " .. tostring(type_name))
    end

    -- Get projectile from pool or create new
    local projectile = nil
    if self.pooling and #self.projectile_pool > 0 then
        projectile = table.remove(self.projectile_pool)
    else
        projectile = {}
    end

    -- Initialize projectile
    projectile.type_name = type_name
    projectile.x = x
    projectile.y = y
    projectile.angle = angle
    projectile.active = true
    projectile.marked_for_removal = false

    -- Copy type properties
    for k, v in pairs(projectile_type) do
        if type(v) ~= "function" then
            projectile[k] = v
        end
    end

    -- Apply custom overrides
    if custom_params then
        for k, v in pairs(custom_params) do
            projectile[k] = v
        end
    end

    -- Calculate velocity
    local speed = (projectile.speed or 100) * (speed_multiplier or 1.0)
    projectile.vx = math.cos(angle) * speed
    projectile.vy = math.sin(angle) * speed

    -- Initialize lifetime
    projectile.lifetime_remaining = projectile.lifetime or 999

    -- Movement-specific initialization
    projectile.movement_type = projectile.movement_type or ProjectileSystem.MOVEMENT_TYPES.LINEAR

    if projectile.movement_type == ProjectileSystem.MOVEMENT_TYPES.SINE_WAVE then
        projectile.sine_time = 0
        projectile.sine_amplitude = projectile.sine_amplitude or 50
        projectile.sine_frequency = projectile.sine_frequency or 2
    elseif projectile.movement_type == ProjectileSystem.MOVEMENT_TYPES.HOMING then
        projectile.homing_target = nil
        projectile.homing_turn_rate = projectile.homing_turn_rate or 3
    end

    -- Add to active list
    table.insert(self.projectiles, projectile)
    self.projectile_count = self.projectile_count + 1

    return projectile
end

--[[
    Shoot multiple projectiles in a pattern

    @param type_name string - Key from projectile_types
    @param x number - Spawn X position
    @param y number - Spawn Y position
    @param base_angle number - Base direction in radians
    @param pattern string - Pattern name: "single", "double", "triple", "spread", "spiral", "wave", "ring"
    @param config table (optional) - Pattern config {count, arc, offset, time, speed_multiplier}
    @return table - Array of spawned projectiles
]]
function ProjectileSystem:shootPattern(type_name, x, y, base_angle, pattern, config)
    config = config or {}
    local projectiles = {}
    pattern = pattern or "single"

    if pattern == "single" then
        table.insert(projectiles, self:shoot(type_name, x, y, base_angle, config.speed_multiplier, config.custom))

    elseif pattern == "double" then
        local offset = config.offset or 5
        local perp_x = -math.sin(base_angle) * offset
        local perp_y = math.cos(base_angle) * offset
        table.insert(projectiles, self:shoot(type_name, x - perp_x, y - perp_y, base_angle, config.speed_multiplier, config.custom))
        table.insert(projectiles, self:shoot(type_name, x + perp_x, y + perp_y, base_angle, config.speed_multiplier, config.custom))

    elseif pattern == "triple" then
        local spread = math.rad(config.spread or 15)
        table.insert(projectiles, self:shoot(type_name, x, y, base_angle, config.speed_multiplier, config.custom))
        table.insert(projectiles, self:shoot(type_name, x, y, base_angle - spread, config.speed_multiplier, config.custom))
        table.insert(projectiles, self:shoot(type_name, x, y, base_angle + spread, config.speed_multiplier, config.custom))

    elseif pattern == "spread" then
        local count = config.count or 5
        local arc = math.rad(config.arc or 60)
        local start_angle = base_angle - arc / 2
        local step = count > 1 and (arc / (count - 1)) or 0
        for i = 0, count - 1 do
            table.insert(projectiles, self:shoot(type_name, x, y, start_angle + step * i, config.speed_multiplier, config.custom))
        end

    elseif pattern == "spiral" then
        local count = config.count or 6
        local time = config.time or 0
        local rotation_speed = config.rotation_speed or 200
        local angle_step = (math.pi * 2) / count
        local spiral_offset = math.rad((time * rotation_speed) % 360)
        for i = 0, count - 1 do
            table.insert(projectiles, self:shoot(type_name, x, y, base_angle + (i * angle_step) + spiral_offset, config.speed_multiplier, config.custom))
        end

    elseif pattern == "wave" then
        -- Three bullets with wave movement
        local wave_custom = config.custom or {}
        wave_custom.movement_type = "sine_wave"
        table.insert(projectiles, self:shoot(type_name, x, y, base_angle, config.speed_multiplier, wave_custom))
        local left = {}; for k,v in pairs(wave_custom) do left[k] = v end
        left.sine_phase = -math.pi / 3
        table.insert(projectiles, self:shoot(type_name, x, y, base_angle, config.speed_multiplier, left))
        local right = {}; for k,v in pairs(wave_custom) do right[k] = v end
        right.sine_phase = math.pi / 3
        table.insert(projectiles, self:shoot(type_name, x, y, base_angle, config.speed_multiplier, right))

    elseif pattern == "ring" then
        local count = config.count or 8
        local angle_step = (math.pi * 2) / count
        for i = 0, count - 1 do
            table.insert(projectiles, self:shoot(type_name, x, y, base_angle + (i * angle_step), config.speed_multiplier, config.custom))
        end
    end

    return projectiles
end

--[[
    Update all projectiles (movement, lifetime, homing)
]]
function ProjectileSystem:update(dt, game_bounds)
    -- Normalize bounds format: accept {x,y,width,height} or {x_min,x_max,y_min,y_max}
    local b_x_min, b_x_max, b_y_min, b_y_max
    if game_bounds then
        b_x_min = game_bounds.x_min or game_bounds.x or 0
        b_x_max = game_bounds.x_max or (game_bounds.x or 0) + (game_bounds.width or 800)
        b_y_min = game_bounds.y_min or game_bounds.y or 0
        b_y_max = game_bounds.y_max or (game_bounds.y or 0) + (game_bounds.height or 600)
    end

    for i = #self.projectiles, 1, -1 do
        local proj = self.projectiles[i]

        if proj.active and not proj.marked_for_removal then
            -- Update lifetime
            proj.lifetime_remaining = proj.lifetime_remaining - dt
            if proj.lifetime_remaining <= 0 then
                self:removeProjectile(proj)
                goto continue
            end

            -- Movement patterns
            if proj.movement_type == ProjectileSystem.MOVEMENT_TYPES.LINEAR then
                proj.x = proj.x + proj.vx * dt
                proj.y = proj.y + proj.vy * dt

            elseif proj.movement_type == ProjectileSystem.MOVEMENT_TYPES.HOMING then
                -- Homing behavior (fixed target)
                if proj.homing_target and proj.homing_target.active then
                    local dx = proj.homing_target.x - proj.x
                    local dy = proj.homing_target.y - proj.y
                    local target_angle = math.atan2(dy, dx)
                    local angle_diff = target_angle - proj.angle
                    while angle_diff > math.pi do angle_diff = angle_diff - 2 * math.pi end
                    while angle_diff < -math.pi do angle_diff = angle_diff + 2 * math.pi end
                    proj.angle = proj.angle + angle_diff * proj.homing_turn_rate * dt
                    local speed = math.sqrt(proj.vx * proj.vx + proj.vy * proj.vy)
                    proj.vx = math.cos(proj.angle) * speed
                    proj.vy = math.sin(proj.angle) * speed
                end
                proj.x = proj.x + proj.vx * dt
                proj.y = proj.y + proj.vy * dt

            elseif proj.movement_type == ProjectileSystem.MOVEMENT_TYPES.HOMING_NEAREST then
                -- Homing behavior (find nearest from target list each frame)
                local targets = proj.homing_targets or self.homing_targets or {}
                local closest, closest_dist = nil, math.huge
                for _, t in ipairs(targets) do
                    if t.active ~= false then
                        local dx, dy = t.x - proj.x, t.y - proj.y
                        local dist = dx * dx + dy * dy
                        if dist < closest_dist then closest, closest_dist = t, dist end
                    end
                end
                if closest then
                    local dx, dy = closest.x - proj.x, closest.y - proj.y
                    local target_angle = math.atan2(dy, dx)
                    local current_angle = proj.angle or math.atan2(proj.vy or 0, proj.vx or 0)
                    local angle_diff = target_angle - current_angle
                    while angle_diff > math.pi do angle_diff = angle_diff - 2 * math.pi end
                    while angle_diff < -math.pi do angle_diff = angle_diff + 2 * math.pi end
                    proj.angle = current_angle + angle_diff * (proj.homing_turn_rate or 3) * dt
                    local speed = math.sqrt((proj.vx or 0) * (proj.vx or 0) + (proj.vy or 0) * (proj.vy or 0))
                    proj.vx = math.cos(proj.angle) * speed
                    proj.vy = math.sin(proj.angle) * speed
                end
                proj.x = proj.x + proj.vx * dt
                proj.y = proj.y + proj.vy * dt

            elseif proj.movement_type == ProjectileSystem.MOVEMENT_TYPES.SINE_WAVE then
                -- Sine wave movement
                proj.sine_time = proj.sine_time + dt

                -- Forward movement
                local forward_x = math.cos(proj.angle)
                local forward_y = math.sin(proj.angle)

                -- Perpendicular offset
                local perp_x = -forward_y
                local perp_y = forward_x

                local offset = math.sin(proj.sine_time * proj.sine_frequency) * proj.sine_amplitude

                proj.x = proj.x + (forward_x * proj.vx + perp_x * offset) * dt
                proj.y = proj.y + (forward_y * proj.vy + perp_y * offset) * dt

            elseif proj.movement_type == ProjectileSystem.MOVEMENT_TYPES.BOUNCE then
                -- Bounce off walls (like Breakout ball)
                -- Safety check for velocity
                if not proj.vx or not proj.vy then
                    goto continue
                end

                local next_x = proj.x + proj.vx * dt
                local next_y = proj.y + proj.vy * dt

                if game_bounds then
                    local radius = proj.radius or 5

                    -- Bounce off left/right walls (unless bounce_left/bounce_right is false)
                    if proj.bounce_left ~= false and next_x - radius < b_x_min then
                        proj.vx = -proj.vx
                        proj.angle = math.atan2(proj.vy, proj.vx)
                    end
                    if proj.bounce_right ~= false and next_x + radius > b_x_max then
                        proj.vx = -proj.vx
                        proj.angle = math.atan2(proj.vy, proj.vx)
                    end

                    -- Bounce off top/bottom walls (unless bounce_top/bounce_bottom is false)
                    if proj.bounce_top ~= false and next_y - radius < b_y_min then
                        proj.vy = -proj.vy
                        proj.angle = math.atan2(proj.vy, proj.vx)
                    end
                    if proj.bounce_bottom ~= false and next_y + radius > b_y_max then
                        proj.vy = -proj.vy
                        proj.angle = math.atan2(proj.vy, proj.vx)
                    end
                end

                proj.x = proj.x + proj.vx * dt
                proj.y = proj.y + proj.vy * dt

            elseif proj.movement_type == ProjectileSystem.MOVEMENT_TYPES.ARC then
                -- Arc/gravity movement
                local gravity = proj.gravity or 500
                proj.vy = proj.vy + gravity * dt
                proj.x = proj.x + proj.vx * dt
                proj.y = proj.y + proj.vy * dt
            end

            -- Out of bounds check
            if game_bounds then
                if proj.x < b_x_min - 100 or proj.x > b_x_max + 100 or
                   proj.y < b_y_min - 100 or proj.y > b_y_max + 100 then
                    self:removeProjectile(proj)
                end
            end
        end

        -- Remove marked projectiles
        if proj.marked_for_removal then
            self:removeProjectile(proj)
        end

        ::continue::
    end
end

--[[
    Check collisions between projectiles and targets

    @param targets table - Array of entities to check against
    @param callback function(projectile, target) - Called on collision
    @param team_filter string (optional) - Only check projectiles of this team
]]
function ProjectileSystem:checkCollisions(targets, callback, team_filter)
    for _, proj in ipairs(self.projectiles) do
        if proj.active and not proj.marked_for_removal then
            -- Team filter check
            if team_filter and proj.team ~= team_filter then
                goto continue_proj
            end

            for _, target in ipairs(targets) do
                if target.active or target.alive then
                    local collided = false

                    -- Determine projectile bounds (prefer width/height over radius)
                    local proj_has_rect = proj.width and proj.height
                    local target_has_rect = target.width and target.height

                    if proj_has_rect and target_has_rect then
                        -- Rect-rect collision (projectile centered on x,y)
                        local px = proj.x - proj.width / 2
                        local py = proj.y - proj.height / 2
                        collided = px < target.x + target.width and px + proj.width > target.x and
                                   py < target.y + target.height and py + proj.height > target.y

                    elseif proj.radius and target_has_rect then
                        -- Circle-rect collision
                        local closest_x = math.max(target.x, math.min(proj.x, target.x + target.width))
                        local closest_y = math.max(target.y, math.min(proj.y, target.y + target.height))
                        local dx = proj.x - closest_x
                        local dy = proj.y - closest_y
                        collided = (dx * dx + dy * dy) < (proj.radius * proj.radius)

                    elseif proj.radius and target.radius then
                        -- Circle-circle collision
                        local dx = proj.x - target.x
                        local dy = proj.y - target.y
                        local dist_sq = dx * dx + dy * dy
                        local radius_sum = proj.radius + target.radius
                        collided = dist_sq < radius_sum * radius_sum
                    end

                    if collided then
                        if callback then
                            callback(proj, target)
                        end

                        -- Trigger on_hit callback
                        local proj_type = self.projectile_types[proj.type_name]
                        if proj_type and proj_type.on_hit then
                            proj_type.on_hit(proj, target)
                        end

                        -- Remove projectile if not piercing
                        if not proj.piercing then
                            self:removeProjectile(proj)
                            goto continue_proj
                        end
                    end
                end
            end

            ::continue_proj::
        end
    end
end

--[[
    Remove projectile from active list
]]
function ProjectileSystem:removeProjectile(projectile)
    for i, proj in ipairs(self.projectiles) do
        if proj == projectile then
            table.remove(self.projectiles, i)
            self.projectile_count = self.projectile_count - 1

            -- Return to pool
            if self.pooling then
                projectile.active = false
                projectile.marked_for_removal = false
                table.insert(self.projectile_pool, projectile)
            end

            break
        end
    end
end

--[[
    Clear all projectiles
]]
function ProjectileSystem:clear()
    if self.pooling then
        for _, proj in ipairs(self.projectiles) do
            proj.active = false
            proj.marked_for_removal = false
            table.insert(self.projectile_pool, proj)
        end
    end

    self.projectiles = {}
    self.projectile_count = 0
end

--[[
    Draw all projectiles using custom render callback

    @param render_callback function(projectile)
]]
function ProjectileSystem:draw(render_callback)
    for _, proj in ipairs(self.projectiles) do
        if proj.active and not proj.marked_for_removal then
            render_callback(proj)
        end
    end
end

--[[
    Get count of active projectiles
]]
function ProjectileSystem:getCount()
    return self.projectile_count
end

--[[
    Get all active projectiles
]]
function ProjectileSystem:getProjectiles()
    local active = {}
    for _, proj in ipairs(self.projectiles) do
        if proj.active and not proj.marked_for_removal then
            table.insert(active, proj)
        end
    end
    return active
end

--[[
    Set targets list for HOMING_NEAREST projectiles
]]
function ProjectileSystem:setHomingTargets(targets)
    self.homing_targets = targets
end

--[[
    Get projectiles by team
]]
function ProjectileSystem:getProjectilesByTeam(team)
    local result = {}
    for _, proj in ipairs(self.projectiles) do
        if proj.active and proj.team == team and not proj.marked_for_removal then
            table.insert(result, proj)
        end
    end
    return result
end

--[[
    Update fire mode state and trigger shooting
    Handles: manual, auto, charge, burst modes

    @param dt number - Delta time
    @param entity table - Entity with fire state (fire_cooldown, auto_fire_timer, etc.)
    @param mode string - "manual", "auto", "charge", "burst"
    @param config table - {cooldown, fire_rate, charge_time, burst_count, burst_delay}
    @param is_fire_pressed boolean - Is fire key held
    @param on_fire function(charge_multiplier) - Called when should fire
]]
function ProjectileSystem:updateFireMode(dt, entity, mode, config, is_fire_pressed, on_fire)
    config = config or {}

    if mode == "manual" then
        entity.fire_cooldown = (entity.fire_cooldown or 0) - dt
        if is_fire_pressed and entity.fire_cooldown <= 0 then
            on_fire(1.0)
            entity.fire_cooldown = config.cooldown or 0.2
        end

    elseif mode == "auto" then
        entity.auto_fire_timer = (entity.auto_fire_timer or 0) - dt
        if is_fire_pressed and entity.auto_fire_timer <= 0 then
            on_fire(1.0)
            entity.auto_fire_timer = 1.0 / (config.fire_rate or 5)
        end

    elseif mode == "charge" then
        if is_fire_pressed then
            if not entity.is_charging then
                entity.is_charging = true
                entity.charge_progress = 0
            end
            entity.charge_progress = math.min((entity.charge_progress or 0) + dt, config.charge_time or 1)
        else
            if entity.is_charging then
                local charge_mult = entity.charge_progress / (config.charge_time or 1)
                on_fire(charge_mult)
                entity.is_charging = false
                entity.charge_progress = 0
            end
        end

    elseif mode == "burst" then
        if (entity.burst_remaining or 0) > 0 then
            entity.burst_timer = (entity.burst_timer or 0) + dt
            if entity.burst_timer >= (config.burst_delay or 0.05) then
                on_fire(1.0)
                entity.burst_remaining = entity.burst_remaining - 1
                entity.burst_timer = 0
            end
        else
            entity.fire_cooldown = (entity.fire_cooldown or 0) - dt
            if is_fire_pressed and entity.fire_cooldown <= 0 then
                entity.burst_remaining = config.burst_count or 3
                entity.burst_timer = 0
                entity.fire_cooldown = config.cooldown or 0.5
            end
        end
    end
end

return ProjectileSystem
