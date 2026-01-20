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

    return instance
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
                -- Homing behavior
                if proj.homing_target and proj.homing_target.active then
                    local dx = proj.homing_target.x - proj.x
                    local dy = proj.homing_target.y - proj.y
                    local target_angle = math.atan2(dy, dx)

                    -- Turn towards target
                    local angle_diff = target_angle - proj.angle
                    -- Normalize to [-pi, pi]
                    while angle_diff > math.pi do angle_diff = angle_diff - 2 * math.pi end
                    while angle_diff < -math.pi do angle_diff = angle_diff + 2 * math.pi end

                    proj.angle = proj.angle + angle_diff * proj.homing_turn_rate * dt

                    -- Update velocity
                    local speed = math.sqrt(proj.vx * proj.vx + proj.vy * proj.vy)
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

return ProjectileSystem
