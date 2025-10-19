local Object = require('class')

local ScreensaverView = Object:extend('ScreensaverView')

function ScreensaverView:init(opts)
    opts = opts or {}
    self.stars = {}
    self:setViewport(0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    self.fov = opts.fov or 300 -- focal length for projection
    self.speed = opts.speed or 120 -- forward speed through starfield
    self.max_count = opts.count or 500
    self.tail = opts.tail or 12
    self:seedStars()
end

function ScreensaverView:setViewport(x, y, w, h)
    self.viewport = { x=x, y=y, width=w, height=h }
end

function ScreensaverView:seedStars()
    self.stars = {}
    local count = self.max_count or 500
    local w, h = self.viewport.width, self.viewport.height
    for i=1,count do
        -- Centered distribution around (0,0) in world space
        local sx = (math.random() - 0.5) * w
        local sy = (math.random() - 0.5) * h
        local sz = math.random(50, 1000)
        table.insert(self.stars, { x = sx, y = sy, z = sz })
    end
end

function ScreensaverView:update(dt)
    -- Move forward: decrease z, reset when passing camera
    for _, s in ipairs(self.stars) do
        s.z = s.z - self.speed * dt
        if s.z < 1 then
            -- re-spawn further away with random x,y
            local w, h = self.viewport.width, self.viewport.height
            s.x = (math.random() - 0.5) * w
            s.y = (math.random() - 0.5) * h
            s.z = math.random(600, 1200)
        end
    end
end

function ScreensaverView:draw()
    local w, h = self.viewport.width, self.viewport.height
    local cx, cy = w/2, h/2
    love.graphics.clear(0, 0, 0)
    -- Draw as projected points with speed streaks
    for _, s in ipairs(self.stars) do
        local z = s.z
        local k = self.fov / z
        local px = cx + s.x * k
        local py = cy + s.y * k
        if px >= 0 and px <= w and py >= 0 and py <= h then
            local size = math.max(1, 2.5 - (z / 600))
            local tail = (self.tail or 12) * (1 - math.min(1, z / 800))
            love.graphics.setColor(1,1,1)
            -- draw a small line towards center to simulate streak motion
            love.graphics.setLineWidth(1)
            love.graphics.line(px, py, px - (s.x * k - s.x * (self.fov / (z + 40))), py - (s.y * k - s.y * (self.fov / (z + 40))))
            love.graphics.rectangle('fill', px, py, size, size)
        end
    end
    -- minimal clock overlay
    love.graphics.setColor(0.8, 0.8, 1, 0.5)
    local t = os.date("%H:%M:%S")
    love.graphics.print(t, 12, 10, 0, 1.5, 1.5)
end

return ScreensaverView
