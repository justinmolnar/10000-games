-- Simple particle system for visual effects
-- Generic emit() for explosions, trails, sparkles; emitConfetti() for celebrations

local ParticleSystem = {}
ParticleSystem.__index = ParticleSystem

function ParticleSystem:new()
    local ps = {
        particles = {}
    }
    setmetatable(ps, ParticleSystem)
    return ps
end

-- Emit particles (generic)
-- types: "explosion", "sparkle", "confetti", "trail"
function ParticleSystem:emit(x, y, count, particle_type, options)
    options = options or {}
    local color = options.color or {1, 1, 1}
    local speed = options.speed or 100
    local lifetime = options.lifetime or 1.0
    local size = options.size or 4
    local spread = options.spread or math.pi * 2  -- Full 360° by default
    local direction = options.direction or 0  -- 0 = right, pi/2 = down, -pi/2 = up

    for i = 1, count do
        local angle = direction + (math.random() - 0.5) * spread
        local particle_speed = speed * (0.5 + math.random() * 0.5)  -- Vary speed ±50%

        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle) * particle_speed,
            vy = math.sin(angle) * particle_speed,
            lifetime = lifetime,
            max_lifetime = lifetime,
            size = size,
            color = {color[1], color[2], color[3], color[4] or 1},
            type = particle_type or "explosion",
            alive = true,
            gravity = options.gravity or 0,
            friction = options.friction or 1.0
        }

        table.insert(self.particles, particle)
    end
end

-- Emit confetti particles (celebration)
function ParticleSystem:emitConfetti(x, y, count)
    count = count or 20
    self:emit(x, y, count, "confetti", {
        color = {1, 1, 1, 1},  -- Will randomize per particle
        speed = 200,
        lifetime = 2.0,
        size = 6,
        spread = math.pi * 2,
        gravity = 150
    })

    -- Randomize confetti colors
    for i = #self.particles - count + 1, #self.particles do
        local p = self.particles[i]
        if p then
            p.color = {math.random(), math.random(), math.random(), 1}
            p.rotation = math.random() * math.pi * 2
            p.rotation_speed = (math.random() - 0.5) * 10
        end
    end
end

function ParticleSystem:update(dt)
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]

        -- Update position
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt

        -- Apply gravity
        if p.gravity then
            p.vy = p.vy + p.gravity * dt
        end

        -- Apply friction
        if p.friction and p.friction < 1.0 then
            local f = p.friction ^ (dt * 60)
            p.vx = p.vx * f
            p.vy = p.vy * f
        end

        -- Update rotation (for confetti)
        if p.rotation_speed then
            p.rotation = (p.rotation or 0) + p.rotation_speed * dt
        end

        -- Update lifetime
        p.lifetime = p.lifetime - dt

        -- Fade out alpha
        p.color[4] = math.max(0, p.lifetime / p.max_lifetime)

        -- Remove dead particles
        if p.lifetime <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function ParticleSystem:draw()
    for _, p in ipairs(self.particles) do
        love.graphics.push()
        love.graphics.translate(p.x, p.y)

        if p.rotation then
            love.graphics.rotate(p.rotation)
        end

        love.graphics.setColor(p.color)

        local draw_size = p.size * (p.lifetime / p.max_lifetime)
        if p.type == "confetti" then
            love.graphics.rectangle('fill', -draw_size / 2, -draw_size / 2, draw_size, draw_size * 1.5)
        else
            love.graphics.rectangle('fill', -draw_size / 2, -draw_size / 2, draw_size, draw_size)
        end

        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, 1)  -- Reset color
end

function ParticleSystem:clear()
    self.particles = {}
end

return ParticleSystem
