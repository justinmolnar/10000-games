local Object = require('class')
local json = require('json')

-- Simple 3D model screensaver view: loads a JSON mesh and spins it
local ModelView = Object:extend('ScreensaverModelView')

function ModelView:init(opts)
    opts = opts or {}
    self.di = opts.di
    self:setViewport(0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    local C = (self.di and self.di.config) or {}
    local d = (C and C.screensavers and C.screensavers.defaults and C.screensavers.defaults.model3d) or {}
    self.fov = opts.fov or d.fov or 350
    self.scale = opts.scale or 1.0
    self.mode = opts.mode -- optional explicit mode
    -- global tint color for fill (multiplied by shade)
    self.tint = opts.tint or {1,1,1}
    -- default mode selection: if shapes are provided, use new shape_morph
    local C = (self.di and self.di.config) or {}
    local d = (C and C.screensavers and C.screensavers.defaults and C.screensavers.defaults.model3d) or {}
    self.mode = self.mode or ((opts.shapes or (d and d.shapes)) and 'shape_morph' or 'cube_sphere') -- 'mesh', 'square_circle', 'cube_sphere', 'shape_morph'
    self.two_sided = opts.two_sided or d.two_sided or false -- if true, skip backface culling
    self.rot_speed = {
        x = opts.rot_speed_x or 0.4,
        y = opts.rot_speed_y or 0.6,
        z = opts.rot_speed_z or 0.0,
    }
    self.angle = {x=0, y=0, z=0}
    -- shape list for shape_morph (1..3 entries recommended)
    self.shapes = opts.shapes or d.shapes or { 'cube', 'sphere' }
    if #self.shapes < 1 then self.shapes = { 'cube' } end
    if #self.shapes > 3 then
        -- keep first three to honor requirement
        local kept = {}
        for i=1,3 do kept[i] = self.shapes[i] end
        self.shapes = kept
    end
    self.shape_index = 1
    self.next_index = (#self.shapes >= 2) and 2 or 1
    self.hold_time = opts.hold_time or d.hold_time or 0.0 -- pause at each target
    self.hold_timer = 0

    if self.mode == 'mesh' then
        self.model = self:_loadModel(opts.path)
    elseif self.mode == 'square_circle' then
        -- Precompute topology for square<->circle morph (thin prism)
        self.N = opts.segments or 64
        self.thickness = opts.thickness or 0.4
        self.morph_t = 0 -- 0..1 oscillates
        self.morph_speed = opts.morph_speed or 0.5 -- cycles per second
        -- Build faces indices once
        -- Vertex order: bottom ring [1..N], top ring [N+1..2N], bottom center [2N+1], top center [2N+2]
        self.shape_faces = {}
        -- Sides (two triangles per segment)
        for i=1,self.N do
            local j = (i % self.N) + 1
            local bi, bj = i, j
            local ti, tj = self.N + i, self.N + j
            table.insert(self.shape_faces, {bi, bj, tj})
            table.insert(self.shape_faces, {bi, tj, ti})
        end
        -- Centers
        self.bottom_center = 2*self.N + 1
        self.top_center = 2*self.N + 2
        -- Bottom/top fans
        for i=1,self.N do
            local j = (i % self.N) + 1
            table.insert(self.shape_faces, { self.bottom_center, j, i })
            table.insert(self.shape_faces, { self.top_center, self.N + i, self.N + j })
        end
    elseif self.mode == 'cube_sphere' or self.mode == 'shape_morph' then
        self.grid_lat = opts.grid_lat or d.grid_lat or 24 -- latitude segments
        self.grid_lon = opts.grid_lon or d.grid_lon or 48 -- longitude segments
        self.morph_t = 0
        self.morph_speed = opts.morph_speed or d.morph_speed or 0.3
        self.two_sided = opts.two_sided or d.two_sided or false
        -- Precompute faces for a (grid_lat+1) x grid_lon vertex grid
        -- Vertex index: idx(i,j) with i in [0..grid_lat], j in [0..grid_lon-1]
        local function vid(i, j)
            return i * self.grid_lon + j + 1
        end
        self.grid_vertex_count = (self.grid_lat + 1) * self.grid_lon
        self.grid_faces = {}
        for i=0, self.grid_lat - 1 do
            for j=0, self.grid_lon - 1 do
                local j1 = (j + 1) % self.grid_lon
                local a = vid(i, j)
                local b = vid(i + 1, j)
                local c = vid(i + 1, j1)
                local d = vid(i, j1)
                -- Two triangles with outward winding so that front faces produce n.z > 0 after rotation typically
                table.insert(self.grid_faces, {a, b, c})
                table.insert(self.grid_faces, {a, c, d})
            end
        end
    else
        -- default back to cube_sphere grid if unknown mode
        self.mode = 'cube_sphere'
        return self:init(opts)
    end
end

function ModelView:setViewport(x, y, w, h)
    self.viewport = { x=x, y=y, width=w, height=h }
end

function ModelView:_defaultCube()
    -- Unit cube centered at origin
    local v = {
        {-1,-1,-1},{ 1,-1,-1},{ 1, 1,-1},{-1, 1,-1},
        {-1,-1, 1},{ 1,-1, 1},{ 1, 1, 1},{-1, 1, 1},
    }
    local f = {
        {1,2,3,4}, -- back
        {5,6,7,8}, -- front
        {1,5,8,4}, -- left
        {2,6,7,3}, -- right
        {4,3,7,8}, -- top
        {1,2,6,5}, -- bottom
    }
    return { vertices = v, faces = f }
end

function ModelView:_loadModel(path)
    if not path then return self:_defaultCube() end
    local ok, contents = pcall(love.filesystem.read, path)
    if not ok or not contents then return self:_defaultCube() end
    local ok2, data = pcall(json.decode, contents)
    if not ok2 or not data or not data.vertices or not data.faces then
        return self:_defaultCube()
    end
    return data
end

local function matMulVec(m, v)
    return {
        m[1]*v[1] + m[2]*v[2] + m[3]*v[3],
        m[4]*v[1] + m[5]*v[2] + m[6]*v[3],
        m[7]*v[1] + m[8]*v[2] + m[9]*v[3],
    }
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

local function vecSub(a,b) return {a[1]-b[1], a[2]-b[2], a[3]-b[3]} end
local function vecCross(a,b) return { a[2]*b[3]-a[3]*b[2], a[3]*b[1]-a[1]*b[3], a[1]*b[2]-a[2]*b[1] } end
local function vecDot(a,b) return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function vecLen(a) return math.sqrt(vecDot(a,a)) end

function ModelView:update(dt)
    self.angle.x = self.angle.x + self.rot_speed.x * dt
    self.angle.y = self.angle.y + self.rot_speed.y * dt
    self.angle.z = self.angle.z + self.rot_speed.z * dt
    if self.mode ~= 'mesh' then
        if self.mode == 'shape_morph' then
            if self.hold_timer > 0 then
                self.hold_timer = math.max(0, self.hold_timer - dt)
            else
                self.morph_t = self.morph_t + self.morph_speed * dt
                if self.morph_t >= 1.0 then
                    self.morph_t = 0.0
                    self.shape_index = self.next_index
                    self.next_index = (self.shape_index % #self.shapes) + 1
                    self.hold_timer = self.hold_time
                end
            end
        else
            self.morph_t = (self.morph_t + self.morph_speed * dt) % 1.0
        end
    end
end

function ModelView:draw()
    local w, h = self.viewport.width, self.viewport.height
    local cx, cy = w/2, h/2
    local scale = self.scale

    -- Build rotation matrix R = Rz * Ry * Rx
    local R = matMul(rotZ(self.angle.z), matMul(rotY(self.angle.y), rotX(self.angle.x)))

    -- Build/transform vertices to camera space
    local verts = {}
    local faces_src
    local function pushForwardClamp(p)
    local DV = ((self.di and self.di.config and self.di.config.ui and self.di.config.ui.views and self.di.config.ui.views.screensaver_model_draw) or {})
        p[3] = p[3] + (DV.z_push or 6)
        if p[3] < (DV.near_min or 0.1) then p[3] = (DV.near_min or 0.1) end
        return p
    end
    if self.mode == 'mesh' then
        for i, v in ipairs(self.model.vertices) do
            local p = {v[1]*scale, v[2]*scale, v[3]*scale}
            p = matMulVec(R, p)
            verts[i] = pushForwardClamp(p)
        end
        faces_src = self.model.faces
    elseif self.mode == 'square_circle' then
        -- Morph a superellipse between square (p~16) and circle (p~2)
        local function sgn(a) return a < 0 and -1 or 1 end
        local function superellipse(theta, p)
            local ct, st = math.cos(theta), math.sin(theta)
            local x = sgn(ct) * (math.abs(ct))^(2/p)
            local y = sgn(st) * (math.abs(st))^(2/p)
            return x, y
        end
        local p_square, p_circle = 16, 2
        local t = 0.5 - 0.5 * math.cos(2*math.pi * self.morph_t)
        local p_exp = p_square + (p_circle - p_square) * t
        local r = 1.0 * scale
        local half = (self.thickness or 0.4) * 0.5
        for i=1,self.N do
            local theta = (i-1) * 2*math.pi / self.N
            local x, y = superellipse(theta, p_exp)
            local pb = matMulVec(R, { r*x, r*y, -half })
            local pt = matMulVec(R, { r*x, r*y,  half })
            verts[i] = pushForwardClamp(pb)
            verts[self.N + i] = pushForwardClamp(pt)
        end
        local cbot = pushForwardClamp(matMulVec(R, {0,0,-half}))
        local ctop = pushForwardClamp(matMulVec(R, {0,0, half}))
        verts[self.bottom_center] = cbot
        verts[self.top_center] = ctop
        faces_src = self.shape_faces
    else -- cube_sphere or shape_morph using grid
        -- helpers
        local function sgn(a) return a < 0 and -1 or 1 end
        local function supercos(t, e) return sgn(math.cos(t)) * (math.abs(math.cos(t))^(2/e)) end
        local function supersin(t, e) return sgn(math.sin(t)) * (math.abs(math.sin(t))^(2/e)) end
        local r = 1.0 * scale

        local function sample_shape(shape, i, j)
            local u = (i / self.grid_lat) -- 0..1
            local v = (j / self.grid_lon) -- 0..1 (wrap)
            local theta = -math.pi + (2*math.pi * v)
            local phi = -math.pi/2 + (math.pi * u)
            if shape == 'sphere' then
                local e = 2
                local cu = supercos(phi, e)
                local su = supersin(phi, e)
                local cv = supercos(theta, e)
                local sv = supersin(theta, e)
                return r * cu * cv, r * cu * sv, r * su
            elseif shape == 'cube' then
                local e = 16
                local cu = supercos(phi, e)
                local su = supersin(phi, e)
                local cv = supercos(theta, e)
                local sv = supersin(theta, e)
                return r * cu * cv, r * cu * sv, r * su
            elseif shape == 'cylinder' then
                local h = (u * 2) - 1 -- -1..1
                local x = math.cos(theta) * r
                local y = math.sin(theta) * r
                local z = h * r * 0.7
                return x, y, z
            elseif shape == 'plane' then
                local x = (v * 2 - 1) * r
                local y = (u * 2 - 1) * r
                local z = 0
                return x, y, z
            elseif shape == 'egg' then
                local e = 2
                local cu = supercos(phi, e)
                local su = supersin(phi, e)
                local cv = supercos(theta, e)
                local sv = supersin(theta, e)
                local k = (su > 0) and 1.2 or 0.8 -- stretch top, squash bottom
                return r * cu * cv, r * cu * sv, r * su * k
            elseif shape == 'hat' then
                -- sombrero-like: plane with radial bump
                local x = (v * 2 - 1)
                local y = (u * 2 - 1)
                local rr = math.sqrt(x*x + y*y)
                local bump = math.exp(- (rr*2)^2) * 0.6 -- central bump
                local brim = (rr > 0.7) and 0.02 or 0.0
                return r * x, r * y, r * (bump + brim - 0.2)
            elseif shape == 'torus' or shape == 'donut' then
                -- approximate torus mapped on our grid; poles will degenerate on our capped topology (acceptable)
                local U = 2*math.pi * u
                local V = 2*math.pi * v
                local Rmaj = r * 1.0
                local Rmin = r * 0.35
                local cx = (Rmaj + Rmin * math.cos(U)) * math.cos(V)
                local cy = (Rmaj + Rmin * math.cos(U)) * math.sin(V)
                local cz = Rmin * math.sin(U)
                -- normalize scale back into similar bounds
                return cx * 0.6, cy * 0.6, cz * 0.6
            else
                -- default to sphere
                local e = 2
                local cu = supercos(phi, e)
                local su = supersin(phi, e)
                local cv = supercos(theta, e)
                local sv = supersin(theta, e)
                return r * cu * cv, r * cu * sv, r * su
            end
        end

        local function build_vertices_for(shape)
            local out = {}
            local idx = 1
            for i=0, self.grid_lat do
                for j=0, self.grid_lon - 1 do
                    local x,y,z = sample_shape(shape, i, j)
                    local p = matMulVec(R, {x, y, z})
                    out[idx] = pushForwardClamp(p)
                    idx = idx + 1
                end
            end
            return out
        end

        if self.mode == 'cube_sphere' then
            -- backwards compatible morph using superquadric exponent blending
            local e_cube, e_sphere = 16, 2
            local t = 0.5 - 0.5 * math.cos(2*math.pi * self.morph_t)
            local e = e_cube + (e_sphere - e_cube) * t
            local idx = 1
            for i=0, self.grid_lat do
                local u = -math.pi/2 + (math.pi * i / self.grid_lat)
                local cu = supercos(u, e)
                local su = supersin(u, e)
                for j=0, self.grid_lon - 1 do
                    local v = -math.pi + (2*math.pi * j / self.grid_lon)
                    local cv = supercos(v, e)
                    local sv = supersin(v, e)
                    local vx = r * cu * cv
                    local vy = r * cu * sv
                    local vz = r * su
                    local p = matMulVec(R, {vx, vy, vz})
                    verts[idx] = pushForwardClamp(p)
                    idx = idx + 1
                end
            end
        else -- shape_morph
            local a = self.shapes[self.shape_index]
            local b = self.shapes[self.next_index]
            local VA = build_vertices_for(a)
            local VB = build_vertices_for(b)
            local t = self.morph_t
            -- ease in/out for pleasant morph
            local te = 0.5 - 0.5 * math.cos(math.pi * t)
            for i=1, self.grid_vertex_count do
                local pa, pb = VA[i], VB[i]
                local x = pa[1] + (pb[1] - pa[1]) * te
                local y = pa[2] + (pb[2] - pa[2]) * te
                local z = pa[3] + (pb[3] - pa[3]) * te
                verts[i] = {x,y,z}
            end
        end
        faces_src = self.grid_faces
    end

    -- Prepare faces with depth and shading
    local faces = {}
    for _, f in ipairs(faces_src) do
        local i1, i2, i3 = f[1], f[2], f[3]
        local a, b, c = verts[i1], verts[i2], verts[i3]
        if a and b and c then
            local ab = vecSub(b,a)
            local ac = vecSub(c,a)
            local n = vecCross(ab, ac)
            if self.two_sided or n[3] > 0 then
                local avgz = (a[3] + b[3] + c[3]) / 3
                local nl = n[3] / (vecLen(n) + 1e-6)
                local shade = 0.3 + 0.7 * math.max(0, nl)
                table.insert(faces, { idx=f, depth=avgz, shade=shade })
            end
        end
    end
    table.sort(faces, function(u,v) return u.depth > v.depth end) -- far to near

    -- Draw
    local DV = ((self.di and self.di.config and self.di.config.ui and self.di.config.ui.views and self.di.config.ui.views.screensaver_model_draw) or {})
    local bg = DV.bg_color or {0,0,0}
    love.graphics.clear(bg[1], bg[2], bg[3])
    for _,face in ipairs(faces) do
        local pts = {}
        for _, idx in ipairs(face.idx) do
            local p = verts[idx]
            local k = self.fov / p[3]
            local x = cx + p[1] * k
            local y = cy + p[2] * k
            table.insert(pts, x)
            table.insert(pts, y)
        end
        local amb = (DV.ambient or { min = 0.3, max = 1.0 })
        local shade = math.max(amb.min or 0.3, math.min(amb.max or 1.0, face.shade))
        love.graphics.setColor(shade * self.tint[1], shade * self.tint[2], shade * self.tint[3])
        love.graphics.polygon('fill', pts)
        local edge = DV.edge_color or {0,0,0}
        love.graphics.setColor(edge)
        love.graphics.polygon('line', pts)
    end
end

return ModelView
