local Object = require('class')

-- Simple 3D Text screensaver using a textured quad with perspective
local Text3DView = Object:extend('ScreensaverText3DView')

function Text3DView:init(opts)
    opts = opts or {}
    self.di = opts.di
    self:setViewport(0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    -- Options
    self.fov = opts.fov or 350
    self.distance = opts.distance or 10 -- camera distance to text plane
    self.color = opts.color or {1,1,1}
    self.color_mode = opts.color_mode or 'solid' -- 'solid' | 'rainbow'
    self.use_hsv = opts.use_hsv or false
    self.hsv = { h = opts.color_h or 0, s = opts.color_s or 0, v = opts.color_v or 1 }
    self.font_size = opts.font_size or 96
    self.extrude_layers = math.floor(opts.extrude_layers or 12)
    self.spin = {
        x = opts.spin_x or 0.0,
        y = opts.spin_y or 0.8,
        z = opts.spin_z or 0.1,
    }
    self.move_enabled = opts.move_enabled ~= false and (opts.move_enabled or true)
    self.move_mode = opts.move_mode or 'orbit' -- 'orbit' | 'bounce'
    self.move_speed = opts.move_speed or 0.25
    self.move_radius = opts.move_radius or 120
    self._pos = { x = (self.viewport and self.viewport.width or 800)/2, y = (self.viewport and self.viewport.height or 600)/2 }
    self._vel = { x = (opts.bounce_speed_x or 100), y = (opts.bounce_speed_y or 80) }
    self.pulse_enabled = opts.pulse_enabled or false
    self.pulse_speed = opts.pulse_speed or 0.8
    self.pulse_amp = opts.pulse_amp or 0.25
    self.wavy_baseline = opts.wavy_baseline or false -- faux bouncy kerning warp
    self.specular = opts.specular or 0.0 -- 0..1 overlay strength
    self.use_time = opts.use_time or false
    self.text = opts.text or "Hello"

    self.angle = {x=0, y=0, z=0}
    self.t = 0

    self._font = love.graphics.newFont(self.font_size)
    self._canvas, self._mesh = nil, nil
    self._text_for_canvas = nil
    self.fit_width_frac = opts.fit_width_frac or 0.6 -- target on-screen width fraction
    self:_ensureCanvas()
end

function Text3DView:destroy()
    if self._canvas then self._canvas:release(); self._canvas = nil end
    if self._mesh then self._mesh:release(); self._mesh = nil end
end

function Text3DView:setViewport(x, y, w, h)
    self.viewport = {x=x, y=y, width=w, height=h}
end

local function rotX(a)
    local c, s = math.cos(a), math.sin(a)
    return {1,0,0, 0,c,-s, 0,s,c}
end
local function rotY(a)
    local c, s = math.cos(a), math.sin(a)
    return {c,0,s, 0,1,0, -s,0,c}
end
local function rotZ(a)
    local c, s = math.cos(a), math.sin(a)
    return {c,-s,0, s,c,0, 0,0,1}
end
local function matMul(a, b)
    local r = {}
    r[1] = a[1]*b[1] + a[2]*b[4] + a[3]*b[7]
    r[2] = a[1]*b[2] + a[2]*b[5] + a[3]*b[8]
    r[3] = a[1]*b[3] + a[2]*b[6] + a[3]*b[9]
    r[4] = a[4]*b[1] + a[5]*b[4] + a[6]*b[7]
    r[5] = a[4]*b[2] + a[5]*b[5] + a[6]*b[8]
    r[6] = a[4]*b[3] + a[5]*b[6] + a[6]*b[9]
    r[7] = a[7]*b[1] + a[8]*b[4] + a[9]*b[7]
    r[8] = a[7]*b[2] + a[8]*b[5] + a[9]*b[8]
    r[9] = a[7]*b[3] + a[8]*b[6] + a[9]*b[9]
    return r
end
local function matMulVec(m, v)
    return {
        m[1]*v[1] + m[2]*v[2] + m[3]*v[3],
        m[4]*v[1] + m[5]*v[2] + m[6]*v[3],
        m[7]*v[1] + m[8]*v[2] + m[9]*v[3],
    }
end

function Text3DView:_ensureCanvas()
    local phrase = self.use_time and os.date("%H:%M:%S") or (self.text or "")
    if phrase == "" then phrase = " " end
    if self._text_for_canvas == phrase and self._canvas then return end
    -- Create/refresh canvas
    self._text_for_canvas = phrase
    local old_font = love.graphics.getFont()
    love.graphics.setFont(self._font)
    local w = math.max(1, self._font:getWidth(phrase))
    local h = math.max(1, self._font:getHeight())
    if self._canvas then self._canvas:release() end
    self._canvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(self._canvas)
    love.graphics.clear(0,0,0,0)
    love.graphics.setColor(1,1,1,1)
    love.graphics.print(phrase, 0, 0)
    love.graphics.setCanvas()
    love.graphics.setFont(old_font)
    -- Build mesh once; positions will be updated per-frame
    local vertices = {
        {0,0, 0,0, 1,1,1,1},
        {w,0, 1,0, 1,1,1,1},
        {w,h, 1,1, 1,1,1,1},
        {0,h, 0,1, 1,1,1,1},
    }
    -- format: x,y, u,v, r,g,b,a (default Mesh format)
    if self._mesh then self._mesh:release() end
    self._mesh = love.graphics.newMesh(vertices, 'fan', 'dynamic')
    self._mesh:setTexture(self._canvas)
    -- Store half-sizes in model space
    self._half_w = w * 0.5
    self._half_h = h * 0.5
end

function Text3DView:update(dt)
    self.t = self.t + dt
    self.angle.x = self.angle.x + (self.spin.x or 0) * dt
    self.angle.y = self.angle.y + (self.spin.y or 0) * dt
    self.angle.z = self.angle.z + (self.spin.z or 0) * dt
    if self.use_time then
        -- Refresh canvas if the displayed time changed
        self:_ensureCanvas()
    end
    -- Bounce mode position update (screen space)
    if self.move_enabled and self.move_mode == 'bounce' and self.viewport then
        local w, h = self.viewport.width, self.viewport.height
        self._pos.x = self._pos.x + self._vel.x * dt
        self._pos.y = self._pos.y + self._vel.y * dt
        -- Basic bounds with margin
        local margin = 40
        if self._pos.x < margin then self._pos.x = margin; self._vel.x = math.abs(self._vel.x) end
        if self._pos.x > w - margin then self._pos.x = w - margin; self._vel.x = -math.abs(self._vel.x) end
        if self._pos.y < margin then self._pos.y = margin; self._vel.y = math.abs(self._vel.y) end
        if self._pos.y > h - margin then self._pos.y = h - margin; self._vel.y = -math.abs(self._vel.y) end
    end
end

function Text3DView:draw()
    if not self._mesh or not self._canvas then return end
    local w, h = self.viewport.width, self.viewport.height
    local cx, cy = w/2, h/2
    local fov = self.fov
    -- Clear background
    love.graphics.clear(0,0,0,1)
    -- Movement and pulse
    local move_dx, move_dy = 0, 0
    if self.move_enabled then
        if self.move_mode == 'orbit' then
            move_dx = math.cos(self.t * self.move_speed * 2*math.pi) * self.move_radius
            move_dy = math.sin(self.t * self.move_speed * 2*math.pi) * self.move_radius
        else -- bounce: center around current pos
            cx, cy = self._pos.x, self._pos.y
        end
    end
    local pulse = 1.0
    if self.pulse_enabled then
        pulse = 1.0 + self.pulse_amp * (0.5 + 0.5 * math.sin(self.t * self.pulse_speed * 2*math.pi))
    end

    -- Rotation matrix
    local R = matMul(rotZ(self.angle.z), matMul(rotY(self.angle.y), rotX(self.angle.x)))

    -- Model quad corners centered at origin then scaled to canvas size with auto-fit
    local half_px_w = math.max(1, (self._half_w or 64))
    local half_px_h = math.max(1, (self._half_h or 32))
    local z = (self.distance or 10)
    local k = fov / z
    local target_half_screen = (w * (self.fit_width_frac or 0.6)) * 0.5
    local half_world = target_half_screen / math.max(0.001, k)
    local px_to_world = half_world / half_px_w
    local hw = half_px_w * px_to_world * pulse
    local hh = half_px_h * px_to_world * pulse
    local pts = {
        {-hw,-hh,0}, { hw,-hh,0}, { hw, hh,0}, { -hw, hh,0}
    }
    -- Transform to camera space and project
    local function project(p)
        local tp = matMulVec(R, p)
        -- Push forward to be in front of camera
        tp[3] = tp[3] + math.max(0.1, (self.distance or 10))
        if tp[3] < 0.1 then tp[3] = 0.1 end
        local k = fov / tp[3]
        if k > 200 then k = 200 end -- clamp extreme zoom
        return cx + (tp[1] * k) + move_dx, cy + (tp[2] * k) + move_dy
    end

    -- Compute projected points once
    local x1,y1 = project(pts[1])
    local x2,y2 = project(pts[2])
    local x3,y3 = project(pts[3])
    local x4,y4 = project(pts[4])

    -- Optional wavy baseline (shear) to mimic bouncy kerning
    if self.wavy_baseline then
        local wphase = self.t * 4.0
        local ax = math.sin(wphase) * 6
        local bx = math.sin(wphase + 1.7) * 6
        x1 = x1 + ax; x4 = x4 + ax
        x2 = x2 + bx; x3 = x3 + bx
    end

    -- Draw extrusion as multiple shadowed layers offset along screen-space normal
    local nx = ((x2 - x1) + (x3 - x4)) * 0.5
    local ny = ((y2 - y1) + (y3 - y4)) * 0.5
    local nn = math.sqrt(nx*nx + ny*ny) + 1e-6
    nx, ny = nx/nn, ny/nn
    local exdx, exdy = nx * 1.5, ny * 1.5
    -- Color selection
    local function hsv2rgb(h, s, v)
        local i = math.floor(h*6)
        local f = h*6 - i
        local p = v*(1-s)
        local q = v*(1-f*s)
        local t = v*(1-(1-f)*s)
        local m = i % 6
        if m==0 then return v,t,p elseif m==1 then return q,v,p elseif m==2 then return p,v,t elseif m==3 then return p,q,v elseif m==4 then return t,p,v else return v,p,q end
    end
    local base_color
    if self.color_mode == 'rainbow' then
        local r,g,b = hsv2rgb((self.t*0.15)%1.0, 1.0, 1.0)
        base_color = { r,g,b, 1 }
    elseif self.use_hsv then
        local r,g,b = hsv2rgb((self.hsv.h or 0)%1.0, math.max(0, math.min(1, self.hsv.s or 0)), math.max(0, math.min(1, self.hsv.v or 1)))
        base_color = { r,g,b, 1 }
    else
        base_color = { self.color[1] or 1, self.color[2] or 1, self.color[3] or 1, 1 }
    end
    -- Back layers
    for i= self.extrude_layers,1,-1 do
        local ox, oy = exdx*i, exdy*i
        self._mesh:setVertex(1, x1+ox, y1+oy, 0,0, 0.2,0.2,0.2, 1)
        self._mesh:setVertex(2, x2+ox, y2+oy, 1,0, 0.2,0.2,0.2, 1)
        self._mesh:setVertex(3, x3+ox, y3+oy, 1,1, 0.2,0.2,0.2, 1)
        self._mesh:setVertex(4, x4+ox, y4+oy, 0,1, 0.2,0.2,0.2, 1)
        love.graphics.draw(self._mesh)
    end

    -- Front face
    self._mesh:setVertex(1, x1, y1, 0,0, base_color[1], base_color[2], base_color[3], 1)
    self._mesh:setVertex(2, x2, y2, 1,0, base_color[1], base_color[2], base_color[3], 1)
    self._mesh:setVertex(3, x3, y3, 1,1, base_color[1], base_color[2], base_color[3], 1)
    self._mesh:setVertex(4, x4, y4, 0,1, base_color[1], base_color[2], base_color[3], 1)
    love.graphics.draw(self._mesh)

    -- Specular highlight overlay based on plane normal vs light dir
    if (self.specular or 0) > 0 then
        -- Transform forward normal (0,0,1)
        local R = matMul(rotZ(self.angle.z), matMul(rotY(self.angle.y), rotX(self.angle.x)))
        local n = { R[3], R[6], R[9] }
        local nl = math.sqrt(n[1]*n[1]+n[2]*n[2]+n[3]*n[3]) + 1e-6
        n[1], n[2], n[3] = n[1]/nl, n[2]/nl, n[3]/nl
        local L = {0.2, 0.3, 1.0}
        local ll = math.sqrt(L[1]*L[1]+L[2]*L[2]+L[3]*L[3])
        L = {L[1]/ll, L[2]/ll, L[3]/ll}
        local d = math.max(0, n[1]*L[1] + n[2]*L[2] + n[3]*L[3])
        local shininess = 16
        local s = (d^shininess) * (self.specular or 0)
        local ar, ag, ab, aa = s, s, s, s
    self._mesh:setVertex(1, x1, y1, 0,0, ar, ag, ab, aa)
    self._mesh:setVertex(2, x2, y2, 1,0, ar, ag, ab, aa)
    self._mesh:setVertex(3, x3, y3, 1,1, ar, ag, ab, aa)
    self._mesh:setVertex(4, x4, y4, 0,1, ar, ag, ab, aa)
        love.graphics.setBlendMode('add')
        love.graphics.draw(self._mesh)
        love.graphics.setBlendMode('alpha')
    end
end

return Text3DView
