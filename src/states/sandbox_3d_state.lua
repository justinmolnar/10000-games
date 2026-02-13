local Object = require('class')
local Constants = require('src.constants')

-- Load g3d library
local g3d = require('lib.g3d')
-- g3d sets depth mode globally on load; reset for normal 2D rendering
love.graphics.setDepthMode()

local Sandbox3DState = Object:extend('Sandbox3DState')

-- Create 1x1 white texture for vertex-colored models
local white_pixel = love.image.newImageData(1, 1)
white_pixel:setPixel(0, 0, 1, 1, 1, 1)
local white_texture = love.graphics.newImage(white_pixel)

-- Layout constants (matching shader sandbox)
local PANEL_W = 250
local SLIDER_H = 18
local SLIDER_PAD = 4
local ROW_H = SLIDER_H + SLIDER_PAD
local LABEL_W = 85
local VALUE_W = 50
local HEADER_H = 36

--------------------------------------------------------------------------------
-- Geometry generators
--------------------------------------------------------------------------------

-- Baked directional light for vertex colors
local LIGHT = {0.577, 0.577, 0.577}
local function shade(r, g, b, nx, ny, nz)
    local dot = nx * LIGHT[1] + ny * LIGHT[2] + nz * LIGHT[3]
    local s = 0.35 + 0.65 * math.max(0, dot)
    return r * s, g * s, b * s
end

local function addQuad(verts, v1, v2, v3, v4, nx, ny, nz, r, g, b)
    local sr, sg, sb = shade(r, g, b, nx, ny, nz)
    verts[#verts+1] = {v1[1],v1[2],v1[3], 0,0, nx,ny,nz, sr,sg,sb,1}
    verts[#verts+1] = {v2[1],v2[2],v2[3], 1,0, nx,ny,nz, sr,sg,sb,1}
    verts[#verts+1] = {v3[1],v3[2],v3[3], 1,1, nx,ny,nz, sr,sg,sb,1}
    verts[#verts+1] = {v1[1],v1[2],v1[3], 0,0, nx,ny,nz, sr,sg,sb,1}
    verts[#verts+1] = {v3[1],v3[2],v3[3], 1,1, nx,ny,nz, sr,sg,sb,1}
    verts[#verts+1] = {v4[1],v4[2],v4[3], 0,1, nx,ny,nz, sr,sg,sb,1}
end

local function addTri(verts, v1, v2, v3, nx, ny, nz, r, g, b)
    local sr, sg, sb = shade(r, g, b, nx, ny, nz)
    verts[#verts+1] = {v1[1],v1[2],v1[3], 0,0, nx,ny,nz, sr,sg,sb,1}
    verts[#verts+1] = {v2[1],v2[2],v2[3], 1,0, nx,ny,nz, sr,sg,sb,1}
    verts[#verts+1] = {v3[1],v3[2],v3[3], 0.5,1, nx,ny,nz, sr,sg,sb,1}
end

local function faceNormal(v1, v2, v3)
    local e1x, e1y, e1z = v2[1]-v1[1], v2[2]-v1[2], v2[3]-v1[3]
    local e2x, e2y, e2z = v3[1]-v1[1], v3[2]-v1[2], v3[3]-v1[3]
    local nx = e1y*e2z - e1z*e2y
    local ny = e1z*e2x - e1x*e2z
    local nz = e1x*e2y - e1y*e2x
    local nl = math.sqrt(nx*nx + ny*ny + nz*nz)
    if nl > 0 then return nx/nl, ny/nl, nz/nl end
    return 0, 0, 1
end

local function generateCube(r, g, b)
    r, g, b = r or 0.8, g or 0.3, b or 0.3
    local s = 0.5
    local verts = {}
    local faces = {
        {{-s,-s,-s}, {s,-s,-s}, {s,s,-s}, {-s,s,-s}, {0,0,-1}},
        {{s,-s,s}, {-s,-s,s}, {-s,s,s}, {s,s,s}, {0,0,1}},
        {{-s,-s,s}, {-s,-s,-s}, {-s,s,-s}, {-s,s,s}, {-1,0,0}},
        {{s,-s,-s}, {s,-s,s}, {s,s,s}, {s,s,-s}, {1,0,0}},
        {{-s,-s,s}, {s,-s,s}, {s,-s,-s}, {-s,-s,-s}, {0,-1,0}},
        {{-s,s,-s}, {s,s,-s}, {s,s,s}, {-s,s,s}, {0,1,0}},
    }
    for _, f in ipairs(faces) do
        addQuad(verts, f[1], f[2], f[3], f[4], f[5][1], f[5][2], f[5][3], r, g, b)
    end
    return verts
end

local function generateCubeAt(cx, cy, cz, size, r, g, b)
    local s = size / 2
    local verts = {}
    local faces = {
        {{-s+cx,-s+cy,-s+cz}, {s+cx,-s+cy,-s+cz}, {s+cx,s+cy,-s+cz}, {-s+cx,s+cy,-s+cz}, {0,0,-1}},
        {{s+cx,-s+cy,s+cz}, {-s+cx,-s+cy,s+cz}, {-s+cx,s+cy,s+cz}, {s+cx,s+cy,s+cz}, {0,0,1}},
        {{-s+cx,-s+cy,s+cz}, {-s+cx,-s+cy,-s+cz}, {-s+cx,s+cy,-s+cz}, {-s+cx,s+cy,s+cz}, {-1,0,0}},
        {{s+cx,-s+cy,-s+cz}, {s+cx,-s+cy,s+cz}, {s+cx,s+cy,s+cz}, {s+cx,s+cy,-s+cz}, {1,0,0}},
        {{-s+cx,-s+cy,s+cz}, {s+cx,-s+cy,s+cz}, {s+cx,-s+cy,-s+cz}, {-s+cx,-s+cy,-s+cz}, {0,-1,0}},
        {{-s+cx,s+cy,-s+cz}, {s+cx,s+cy,-s+cz}, {s+cx,s+cy,s+cz}, {-s+cx,s+cy,s+cz}, {0,1,0}},
    }
    for _, f in ipairs(faces) do
        addQuad(verts, f[1], f[2], f[3], f[4], f[5][1], f[5][2], f[5][3], r, g, b)
    end
    return verts
end

local function generateSphere(radius, stacks, slices, r, g, b)
    radius, stacks, slices = radius or 0.5, stacks or 12, slices or 16
    r, g, b = r or 1, g or 1, b or 1
    local verts = {}
    local pi = math.pi
    for i = 0, stacks - 1 do
        local lat0 = pi * (i / stacks - 0.5)
        local lat1 = pi * ((i+1) / stacks - 0.5)
        local z0 = math.sin(lat0) * radius
        local z1 = math.sin(lat1) * radius
        local cos0 = math.cos(lat0) * radius
        local cos1 = math.cos(lat1) * radius
        for j = 0, slices - 1 do
            local lon0 = 2 * pi * j / slices
            local lon1 = 2 * pi * (j+1) / slices
            local x00, y00 = math.cos(lon0)*cos0, math.sin(lon0)*cos0
            local x10, y10 = math.cos(lon1)*cos0, math.sin(lon1)*cos0
            local x01, y01 = math.cos(lon0)*cos1, math.sin(lon0)*cos1
            local x11, y11 = math.cos(lon1)*cos1, math.sin(lon1)*cos1
            local function norm(vx, vy, vz)
                local len = math.sqrt(vx*vx + vy*vy + vz*vz)
                if len > 0 then return vx/len, vy/len, vz/len end
                return 0, 0, 1
            end
            local nx00,ny00,nz00 = norm(x00,y00,z0)
            local nx10,ny10,nz10 = norm(x10,y10,z0)
            local nx01,ny01,nz01 = norm(x01,y01,z1)
            local nx11,ny11,nz11 = norm(x11,y11,z1)
            local u0, u1 = j/slices, (j+1)/slices
            local v0, v1 = i/stacks, (i+1)/stacks
            local sr,sg,sb
            sr,sg,sb = shade(r,g,b, nx00,ny00,nz00)
            verts[#verts+1] = {x00,y00,z0, u0,v0, nx00,ny00,nz00, sr,sg,sb,1}
            sr,sg,sb = shade(r,g,b, nx10,ny10,nz10)
            verts[#verts+1] = {x10,y10,z0, u1,v0, nx10,ny10,nz10, sr,sg,sb,1}
            sr,sg,sb = shade(r,g,b, nx11,ny11,nz11)
            verts[#verts+1] = {x11,y11,z1, u1,v1, nx11,ny11,nz11, sr,sg,sb,1}
            sr,sg,sb = shade(r,g,b, nx00,ny00,nz00)
            verts[#verts+1] = {x00,y00,z0, u0,v0, nx00,ny00,nz00, sr,sg,sb,1}
            sr,sg,sb = shade(r,g,b, nx11,ny11,nz11)
            verts[#verts+1] = {x11,y11,z1, u1,v1, nx11,ny11,nz11, sr,sg,sb,1}
            sr,sg,sb = shade(r,g,b, nx01,ny01,nz01)
            verts[#verts+1] = {x01,y01,z1, u0,v1, nx01,ny01,nz01, sr,sg,sb,1}
        end
    end
    return verts
end

local function generateGrid(size, divs)
    local verts = {}
    local half = size / 2
    local step = size / divs
    for i = 0, divs - 1 do
        for j = 0, divs - 1 do
            local x0 = -half + i * step
            local y0 = -half + j * step
            local x1 = x0 + step
            local y1 = y0 + step
            local u0, v0 = i/divs, j/divs
            local u1, v1 = (i+1)/divs, (j+1)/divs
            verts[#verts+1] = {x0,y0,0, u0,v0, 0,0,1, 0.3,0.6,0.2,1}
            verts[#verts+1] = {x1,y0,0, u1,v0, 0,0,1, 0.3,0.6,0.2,1}
            verts[#verts+1] = {x1,y1,0, u1,v1, 0,0,1, 0.3,0.6,0.2,1}
            verts[#verts+1] = {x0,y0,0, u0,v0, 0,0,1, 0.3,0.6,0.2,1}
            verts[#verts+1] = {x1,y1,0, u1,v1, 0,0,1, 0.3,0.6,0.2,1}
            verts[#verts+1] = {x0,y1,0, u0,v1, 0,0,1, 0.3,0.6,0.2,1}
        end
    end
    return verts
end

local function generatePyramid(size, height, r, g, b)
    local s = size / 2
    local apex = {0, 0, height}
    local base = {{-s,-s,0}, {s,-s,0}, {s,s,0}, {-s,s,0}}
    local verts = {}
    for i = 1, 4 do
        local j = i % 4 + 1
        local v1, v2, v3 = base[i], base[j], apex
        local nx, ny, nz = faceNormal(v1, v2, v3)
        addTri(verts, v1, v2, v3, nx, ny, nz, r, g, b)
    end
    addQuad(verts, base[1], base[4], base[3], base[2], 0, 0, -1, r*0.5, g*0.5, b*0.5)
    return verts
end

local function generateOctahedron(size, r, g, b)
    local pts = {{size,0,0},{-size,0,0},{0,size,0},{0,-size,0},{0,0,size},{0,0,-size}}
    local faces = {
        {1,3,5},{3,2,5},{2,4,5},{4,1,5},
        {3,1,6},{2,3,6},{4,2,6},{1,4,6},
    }
    local verts = {}
    for _, f in ipairs(faces) do
        local v1, v2, v3 = pts[f[1]], pts[f[2]], pts[f[3]]
        local nx, ny, nz = faceNormal(v1, v2, v3)
        addTri(verts, v1, v2, v3, nx, ny, nz, r, g, b)
    end
    return verts
end

local function generateCubeCloud(count, spread, cube_size)
    local all_verts = {}
    for _ = 1, count do
        local theta = math.random() * math.pi * 2
        local phi = math.acos(2 * math.random() - 1)
        local dist = spread * (math.random() ^ (1/3))
        local cx = dist * math.sin(phi) * math.cos(theta)
        local cy = dist * math.sin(phi) * math.sin(theta)
        local cz = dist * math.cos(phi)
        local cr = math.random() * 0.5 + 0.5
        local cg = math.random() * 0.5 + 0.5
        local cb = math.random() * 0.5 + 0.5
        local cs = cube_size * (0.5 + math.random())
        local cube = generateCubeAt(cx, cy, cz, cs, cr, cg, cb)
        for _, v in ipairs(cube) do
            all_verts[#all_verts+1] = v
        end
    end
    return all_verts
end

--------------------------------------------------------------------------------
-- 3D Text shader and extruded geometry
--------------------------------------------------------------------------------

local TEXT_FRAG_GLSL = [[
extern mat4 modelMatrix;
extern vec3 uViewPos;
extern float uSpecular;
extern float uSurface;
extern vec3 uColor1;
extern vec3 uColor2;

varying vec4 worldPosition;
varying vec3 vertexNormal;

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    vec3 N = normalize(mat3(modelMatrix) * vertexNormal);

    vec3 L = normalize(vec3(1.0, 1.0, 0.8));
    vec3 V = normalize(uViewPos - worldPosition.xyz);
    vec3 R = reflect(-L, N);

    float diff = max(dot(N, L), 0.0);
    float spec = pow(max(dot(R, V), 0.0), 32.0) * uSpecular;

    vec3 col;
    if (uSurface < 0.5) {
        col = uColor1 * (0.3 + 0.7 * diff) + vec3(1.0) * spec;
    } else {
        vec3 ref = reflect(-V, N);
        float env = 0.5 + 0.5 * ref.y;
        vec3 base = mix(uColor1, uColor2, env);
        col = base * (0.2 + 0.8 * diff) + vec3(1.0) * spec;
    }

    return vec4(col, 1.0);
}
]]

local text_frag_shader = nil

-- Build opacity grid from rendered font text (cached, only done once)
local function buildTextGrid(text, font_size)
    local font = love.graphics.newFont(font_size)
    local tw = font:getWidth(text)
    local th = font:getHeight()

    local canvas = love.graphics.newCanvas(tw, th)
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font)
    love.graphics.print(text, 0, 0)
    love.graphics.pop()

    local imgdata = canvas:newImageData()
    local w, h = imgdata:getDimensions()

    local grid = {}
    for y = 0, h - 1 do
        grid[y] = {}
        for x = 0, w - 1 do
            local _, _, _, a = imgdata:getPixel(x, y)
            grid[y][x] = a > 0.3
        end
    end

    canvas:release()
    imgdata:release()
    font:release()
    return grid, w, h
end

-- Generate extruded 3D mesh from text opacity grid with greedy quad merging
local function generateTextMesh(grid, grid_w, grid_h, extrude)
    local world_w = 4.3
    local sc = world_w / grid_w
    local world_h = grid_h * sc
    local ox = grid_w / 2
    local oy = grid_h / 2
    local ez = extrude
    local verts = {}

    local function isOpaque(gx, gy)
        if gy < 0 or gy >= grid_h or gx < 0 or gx >= grid_w then return false end
        return grid[gy][gx]
    end

    -- Front (+Z) and Back (-Z): merge horizontal runs per row
    for y = 0, grid_h - 1 do
        local wy = (oy - y) * sc
        local wy1 = (oy - (y + 1)) * sc
        local x = 0
        while x < grid_w do
            if grid[y][x] then
                local x_end = x + 1
                while x_end < grid_w and grid[y][x_end] do x_end = x_end + 1 end
                local wx = (x - ox) * sc
                local wx1 = (x_end - ox) * sc
                addQuad(verts, {wx,wy,ez},{wx,wy1,ez},{wx1,wy1,ez},{wx1,wy,ez}, 0,0,1, 1,1,1)
                addQuad(verts, {wx,wy,-ez},{wx1,wy,-ez},{wx1,wy1,-ez},{wx,wy1,-ez}, 0,0,-1, 1,1,1)
                x = x_end
            else
                x = x + 1
            end
        end
    end

    -- Right (+X): merge vertical runs per column
    for x = 0, grid_w - 1 do
        local wx1 = (x + 1 - ox) * sc
        local y = 0
        while y < grid_h do
            if grid[y][x] and not isOpaque(x + 1, y) then
                local y_end = y + 1
                while y_end < grid_h and grid[y_end][x] and not isOpaque(x + 1, y_end) do y_end = y_end + 1 end
                local wy = (oy - y) * sc
                local wy1 = (oy - y_end) * sc
                addQuad(verts, {wx1,wy,ez},{wx1,wy1,ez},{wx1,wy1,-ez},{wx1,wy,-ez}, 1,0,0, 1,1,1)
                y = y_end
            else
                y = y + 1
            end
        end
    end

    -- Left (-X): merge vertical runs per column
    for x = 0, grid_w - 1 do
        local wx = (x - ox) * sc
        local y = 0
        while y < grid_h do
            if grid[y][x] and not isOpaque(x - 1, y) then
                local y_end = y + 1
                while y_end < grid_h and grid[y_end][x] and not isOpaque(x - 1, y_end) do y_end = y_end + 1 end
                local wy = (oy - y) * sc
                local wy1 = (oy - y_end) * sc
                addQuad(verts, {wx,wy,-ez},{wx,wy1,-ez},{wx,wy1,ez},{wx,wy,ez}, -1,0,0, 1,1,1)
                y = y_end
            else
                y = y + 1
            end
        end
    end

    -- Top (+Y): merge horizontal runs per row
    for y = 0, grid_h - 1 do
        local wy = (oy - y) * sc
        local x = 0
        while x < grid_w do
            if grid[y][x] and not isOpaque(x, y - 1) then
                local x_end = x + 1
                while x_end < grid_w and grid[y][x_end] and not isOpaque(x_end, y - 1) do x_end = x_end + 1 end
                local wx = (x - ox) * sc
                local wx1 = (x_end - ox) * sc
                addQuad(verts, {wx,wy,ez},{wx1,wy,ez},{wx1,wy,-ez},{wx,wy,-ez}, 0,1,0, 1,1,1)
                x = x_end
            else
                x = x + 1
            end
        end
    end

    -- Bottom (-Y): merge horizontal runs per row
    for y = 0, grid_h - 1 do
        local wy1 = (oy - (y + 1)) * sc
        local x = 0
        while x < grid_w do
            if grid[y][x] and not isOpaque(x, y + 1) then
                local x_end = x + 1
                while x_end < grid_w and grid[y][x_end] and not isOpaque(x_end, y + 1) do x_end = x_end + 1 end
                local wx = (x - ox) * sc
                local wx1 = (x_end - ox) * sc
                addQuad(verts, {wx,wy1,ez},{wx,wy1,-ez},{wx1,wy1,-ez},{wx1,wy1,ez}, 0,-1,0, 1,1,1)
                x = x_end
            else
                x = x + 1
            end
        end
    end

    return verts, world_w / 2, world_h / 2
end

--------------------------------------------------------------------------------
-- Program definitions
--------------------------------------------------------------------------------

local function buildPrograms()
    local programs = {}

    -- 1. Spinning Cube
    programs[#programs+1] = {
        name = "Spinning Cube",
        params = {
            {key="speed_x", label="Speed X", min=0, max=5, default=1.0, step=0.1},
            {key="speed_y", label="Speed Y", min=0, max=5, default=0.7, step=0.1},
            {key="speed_z", label="Speed Z", min=0, max=5, default=0.3, step=0.1},
            {key="scale", label="Scale", min=0.3, max=3, default=1.0, step=0.1},
            {key="cam_dist", label="Cam Dist", min=1, max=8, default=3.0, step=0.1},
        },
        values = {}, data = {},
        init = function(prog, w, h)
            prog.data.model = g3d.newModel(generateCube(0.9, 0.3, 0.3), white_texture)
            prog.data.time = 0
        end,
        update = function(prog, dt)
            prog.data.time = prog.data.time + dt
            local v = prog.values
            local t = prog.data.time
            prog.data.model:setTransform(
                {0, 0, 0},
                {t * v.speed_x, t * v.speed_y, t * v.speed_z},
                {v.scale, v.scale, v.scale}
            )
        end,
        draw = function(prog, w, h)
            local v = prog.values
            local d = v.cam_dist
            g3d.camera.aspectRatio = w / h
            g3d.camera.fov = math.pi / 2
            g3d.camera.updateProjectionMatrix()
            g3d.camera.lookAt(d, d, d * 0.7, 0, 0, 0)
            prog.data.model:draw()
        end,
    }

    -- 2. Solar System
    programs[#programs+1] = {
        name = "Solar System",
        params = {
            {key="orbit_speed", label="Orbit Spd", min=0.1, max=5, default=1.0, step=0.1},
            {key="planet_count", label="Planets", min=1, max=6, default=4, step=1},
            {key="cam_dist", label="Cam Dist", min=3, max=15, default=8, step=0.5},
            {key="cam_height", label="Cam Height", min=1, max=10, default=5, step=0.5},
            {key="fov", label="FOV", min=0.5, max=2.5, default=1.57, step=0.05},
        },
        values = {}, data = {},
        init = function(prog, w, h)
            prog.data.sun = g3d.newModel(generateSphere(0.5, 10, 16, 1.0, 0.9, 0.2), white_texture)
            local colors = {
                {0.3,0.5,1.0}, {0.8,0.3,0.2}, {0.2,0.8,0.3},
                {0.7,0.7,0.2}, {0.6,0.3,0.7}, {0.3,0.8,0.8},
            }
            prog.data.planets = {}
            for i = 1, 6 do
                local c = colors[i]
                prog.data.planets[i] = g3d.newModel(
                    generateSphere(0.12 + i * 0.02, 8, 12, c[1], c[2], c[3]), white_texture
                )
            end
            prog.data.time = 0
        end,
        update = function(prog, dt)
            prog.data.time = prog.data.time + dt
            local v = prog.values
            local t = prog.data.time * v.orbit_speed
            local count = math.floor(v.planet_count + 0.5)
            for i = 1, count do
                local orbit_r = 1.0 + i * 0.7
                local speed = 1.0 / (i * 0.4 + 0.3)
                local angle = t * speed + i * 1.047
                prog.data.planets[i]:setTranslation(
                    math.cos(angle) * orbit_r,
                    math.sin(angle) * orbit_r,
                    math.sin(angle * 0.5 + i) * 0.3
                )
            end
            prog.data.sun:setRotation(0, 0, prog.data.time * 0.3)
        end,
        draw = function(prog, w, h)
            local v = prog.values
            g3d.camera.aspectRatio = w / h
            g3d.camera.fov = v.fov
            g3d.camera.updateProjectionMatrix()
            g3d.camera.lookAt(v.cam_dist, 0, v.cam_height, 0, 0, 0)
            prog.data.sun:draw()
            local count = math.floor(v.planet_count + 0.5)
            for i = 1, count do
                prog.data.planets[i]:draw()
            end
        end,
    }

    -- 3. Terrain
    programs[#programs+1] = {
        name = "Terrain",
        params = {
            {key="amplitude", label="Amplitude", min=0.1, max=3.0, default=1.0, step=0.1},
            {key="frequency", label="Frequency", min=0.5, max=5.0, default=2.0, step=0.1},
            {key="wave_speed", label="Speed", min=0, max=3.0, default=0.5, step=0.1},
            {key="cam_height", label="Cam Height", min=2, max=12, default=6.0, step=0.5},
            {key="cam_dist", label="Cam Dist", min=3, max=15, default=8.0, step=0.5},
        },
        values = {}, data = {},
        init = function(prog, w, h)
            prog.data.verts = generateGrid(10, 30)
            prog.data.model = g3d.newModel(prog.data.verts, white_texture)
            prog.data.time = 0
        end,
        update = function(prog, dt)
            prog.data.time = prog.data.time + dt
            local v = prog.values
            local t = prog.data.time * v.wave_speed
            local verts = prog.data.verts
            for i = 1, #verts do
                local x, y = verts[i][1], verts[i][2]
                local h = math.sin(x * v.frequency + t) * math.cos(y * v.frequency * 0.7 + t * 0.8) * v.amplitude
                h = h + math.sin((x + y) * v.frequency * 0.5 + t * 1.3) * v.amplitude * 0.3
                verts[i][3] = h
                local hn = math.max(0, math.min(1, (h / (v.amplitude * 1.3) + 1) * 0.5))
                verts[i][9] = 0.15 + hn * 0.4
                verts[i][10] = 0.3 + hn * 0.4
                verts[i][11] = 0.1 + (1 - hn) * 0.3
            end
            prog.data.model.mesh:setVertices(verts)
        end,
        draw = function(prog, w, h)
            local v = prog.values
            g3d.camera.aspectRatio = w / h
            g3d.camera.fov = math.pi / 2
            g3d.camera.updateProjectionMatrix()
            g3d.camera.lookAt(v.cam_dist, v.cam_dist * 0.3, v.cam_height, 0, 0, 0)
            prog.data.model:draw()
        end,
    }

    -- 4. Cube Storm
    programs[#programs+1] = {
        name = "Cube Storm",
        params = {
            {key="rot_x", label="Rot X", min=0, max=3, default=0.5, step=0.1},
            {key="rot_y", label="Rot Y", min=0, max=3, default=0.3, step=0.1},
            {key="rot_z", label="Rot Z", min=0, max=3, default=0.2, step=0.1},
            {key="cam_dist", label="Cam Dist", min=2, max=10, default=5.0, step=0.1},
            {key="cam_height", label="Cam Height", min=-3, max=5, default=2.0, step=0.1},
        },
        values = {}, data = {},
        init = function(prog, w, h)
            math.randomseed(42)
            prog.data.model = g3d.newModel(generateCubeCloud(80, 2.5, 0.12), white_texture)
            prog.data.time = 0
        end,
        update = function(prog, dt)
            prog.data.time = prog.data.time + dt
            local v = prog.values
            local t = prog.data.time
            prog.data.model:setRotation(t * v.rot_x, t * v.rot_y, t * v.rot_z)
        end,
        draw = function(prog, w, h)
            local v = prog.values
            g3d.camera.aspectRatio = w / h
            g3d.camera.fov = math.pi / 2
            g3d.camera.updateProjectionMatrix()
            g3d.camera.lookAt(v.cam_dist, 0, v.cam_height, 0, 0, 0)
            prog.data.model:draw()
        end,
    }

    -- 5. Shape Gallery
    programs[#programs+1] = {
        name = "Shape Gallery",
        params = {
            {key="spin_speed", label="Spin", min=0, max=5, default=1.0, step=0.1},
            {key="orbit_speed", label="Cam Orbit", min=0, max=2, default=0.3, step=0.05},
            {key="cam_dist", label="Cam Dist", min=3, max=12, default=6.0, step=0.5},
            {key="cam_height", label="Cam Height", min=0, max=6, default=3.0, step=0.5},
        },
        values = {}, data = {},
        init = function(prog, w, h)
            prog.data.shapes = {
                g3d.newModel(generateCube(0.9, 0.3, 0.3), white_texture),
                g3d.newModel(generatePyramid(0.8, 1.0, 0.3, 0.9, 0.3), white_texture),
                g3d.newModel(generateOctahedron(0.5, 0.3, 0.3, 0.9), white_texture),
                g3d.newModel(generateSphere(0.4, 10, 16, 0.9, 0.7, 0.2), white_texture),
            }
            local n = #prog.data.shapes
            for i, shape in ipairs(prog.data.shapes) do
                local angle = (i - 1) / n * math.pi * 2
                shape:setTranslation(math.cos(angle) * 2, math.sin(angle) * 2, 0)
            end
            prog.data.time = 0
        end,
        update = function(prog, dt)
            prog.data.time = prog.data.time + dt
            local v = prog.values
            local t = prog.data.time
            local n = #prog.data.shapes
            for i, shape in ipairs(prog.data.shapes) do
                local angle = (i - 1) / n * math.pi * 2
                shape:setTransform(
                    {math.cos(angle) * 2, math.sin(angle) * 2, 0},
                    {t * v.spin_speed + i, t * v.spin_speed * 0.7 + i * 2, 0}
                )
            end
        end,
        draw = function(prog, w, h)
            local v = prog.values
            local t = prog.data.time
            local cam_angle = t * v.orbit_speed
            g3d.camera.aspectRatio = w / h
            g3d.camera.fov = math.pi / 2
            g3d.camera.updateProjectionMatrix()
            g3d.camera.lookAt(
                math.cos(cam_angle) * v.cam_dist,
                math.sin(cam_angle) * v.cam_dist,
                v.cam_height,
                0, 0, 0
            )
            for _, shape in ipairs(prog.data.shapes) do
                shape:draw()
            end
        end,
    }

    -- 6. 3D Text (font-based extruded voxel mesh, matching shader sandbox's movement controls)
    programs[#programs+1] = {
        name = "3D Text",
        params = {
            {key="drift_x", label="Drift X", min=0.0, max=2.0, default=0.5, step=0.05},
            {key="drift_y", label="Drift Y", min=0.0, max=2.0, default=0.3, step=0.05},
            {key="spin_x", label="Spin X", min=-2.0, max=2.0, default=0.0, step=0.05},
            {key="spin_y", label="Spin Y", min=-2.0, max=2.0, default=0.5, step=0.05},
            {key="spin_z", label="Spin Z", min=-2.0, max=2.0, default=0.0, step=0.05},
            {key="sway_x", label="Sway X", min=0.0, max=1.5, default=0.0, step=0.05},
            {key="sway_y", label="Sway Y", min=0.0, max=1.5, default=0.0, step=0.05},
            {key="sway_z", label="Sway Z", min=0.0, max=1.5, default=0.0, step=0.05},
            {key="text_size", label="Size", min=0.3, max=2.0, default=1.0, step=0.05},
            {key="surface", label="Srf 0/1", min=0.0, max=1.0, default=1.0, step=1.0},
            {key="extrude", label="Depth", min=0.02, max=0.5, default=0.15, step=0.01},
            {key="specular", label="Specular", min=0.0, max=1.5, default=0.8, step=0.05},
            {key="color1_r", label="Col1 R", min=0.0, max=1.0, default=0.6, step=0.01},
            {key="color1_g", label="Col1 G", min=0.0, max=1.0, default=0.4, step=0.01},
            {key="color1_b", label="Col1 B", min=0.0, max=1.0, default=0.1, step=0.01},
            {key="color2_r", label="Col2 R", min=0.0, max=1.0, default=1.0, step=0.01},
            {key="color2_g", label="Col2 G", min=0.0, max=1.0, default=0.85, step=0.01},
            {key="color2_b", label="Col2 B", min=0.0, max=1.0, default=0.5, step=0.01},
        },
        values = {}, data = {},
        init = function(prog, w, h)
            prog.data.time = 0
            prog.data.wx = 0
            prog.data.wy = 0
            prog.data.vx = 1
            prog.data.vy = 1
            prog.data.last_extrude = nil

            if not text_frag_shader then
                local ok, s = pcall(love.graphics.newShader, g3d.shaderpath, TEXT_FRAG_GLSL)
                if ok then text_frag_shader = s
                else print("3D Text shader error: " .. tostring(s)) end
            end

            local grid, gw, gh = buildTextGrid("WAREZ", 128)
            prog.data.grid = grid
            prog.data.grid_w = gw
            prog.data.grid_h = gh

            local val = prog.values
            local ext = val.extrude or 0.15
            local verts, hw, hh = generateTextMesh(grid, gw, gh, ext)
            prog.data.model = g3d.newModel(verts, white_texture)
            prog.data.text_hw = hw
            prog.data.text_hh = hh
            prog.data.last_extrude = ext

            -- Debug: visible red walls at screen edges
            local bar = generateCubeAt(0, 0, 0, 1, 1, 0.15, 0.15)
            prog.data.wall_r = g3d.newModel(bar, white_texture)
            prog.data.wall_l = g3d.newModel(bar, white_texture)
            prog.data.wall_t = g3d.newModel(bar, white_texture)
            prog.data.wall_b = g3d.newModel(bar, white_texture)
        end,
        update = function(prog, dt)
            prog.data.time = prog.data.time + dt
            local t = prog.data.time
            local v = prog.values
            local d = prog.data

            -- Rebuild mesh if extrude changed (grid is cached)
            if v.extrude ~= d.last_extrude then
                local verts, hw, hh = generateTextMesh(d.grid, d.grid_w, d.grid_h, v.extrude)
                d.model = g3d.newModel(verts, white_texture)
                d.text_hw = hw
                d.text_hh = hh
                d.last_extrude = v.extrude
            end

            -- Rotation (matching shader: spin + sway oscillation)
            local rot_x = v.spin_x * t + v.sway_x * math.sin(t * 1.0)
            local rot_y = v.spin_y * t + v.sway_y * math.sin(t * 1.3)
            local rot_z = v.spin_z * t + v.sway_z * math.sin(t * 0.7)

            local cam_z = 5.5 / v.text_size
            local tan_hfov = 1 / 1.5
            local aspect = love.graphics.getWidth() / love.graphics.getHeight()

            -- Drift
            local speed_scale = cam_z * 0.15
            d.wx = d.wx + d.vx * v.drift_x * speed_scale * dt
            d.wy = d.wy + d.vy * v.drift_y * speed_scale * dt

            -- Bounce: project the 8 bounding box corners and check screen edges
            local hw, hh, hz = d.text_hw, d.text_hh, v.extrude
            local ca, sa = math.cos(rot_z), math.sin(rot_z)
            local cb, sb = math.cos(rot_y), math.sin(rot_y)
            local cc, sn = math.cos(rot_x), math.sin(rot_x)
            local r11, r12, r13 = ca*cb, ca*sb*sn - sa*cc, ca*sb*cc + sa*sn
            local r21, r22, r23 = sa*cb, sa*sb*sn + ca*cc, sa*sb*cc - ca*sn
            local r31, r32, r33 = -sb, cb*sn, cb*cc

            local off_r, off_l, off_t, off_b = false, false, false, false
            for i = 1, 8 do
                local bx = (i <= 4) and -hw or hw
                local by = (i % 4 <= 1) and -hh or hh
                local bz = (i % 2 == 1) and -hz or hz
                local rpx = r11*bx + r12*by + r13*bz
                local rpy = r21*bx + r22*by + r23*bz
                local rpz = r31*bx + r32*by + r33*bz
                local wpx = d.wx + rpx
                local wpy = d.wy + rpy
                local depth = cam_z - rpz
                if depth > 0.01 then
                    local cx = wpx / (depth * tan_hfov * aspect)
                    local cy = wpy / (depth * tan_hfov)
                    if cx > 1 then off_r = true end
                    if cx < -1 then off_l = true end
                    if cy > 1 then off_t = true end
                    if cy < -1 then off_b = true end
                end
            end

            if off_r and d.vx > 0 then d.vx = -1 end
            if off_l and d.vx < 0 then d.vx = 1 end
            if off_t and d.vy > 0 then d.vy = -1 end
            if off_b and d.vy < 0 then d.vy = 1 end

            d.model:setTransform({d.wx, d.wy, 0}, {rot_x, rot_y, rot_z})
        end,
        draw = function(prog, w, h)
            if not text_frag_shader then return end
            local v = prog.values
            local d = prog.data
            local cam_z = 5.5 / v.text_size
            local fov = 2 * math.atan(1 / 1.5)

            g3d.camera.up[1], g3d.camera.up[2], g3d.camera.up[3] = 0, 1, 0
            g3d.camera.aspectRatio = w / h
            g3d.camera.fov = fov
            g3d.camera.updateProjectionMatrix()
            g3d.camera.lookAt(0, 0, cam_z, 0, 0, 0)

            text_frag_shader:send("uViewPos", {0, 0, cam_z})
            text_frag_shader:send("uSpecular", v.specular)
            text_frag_shader:send("uSurface", v.surface)
            text_frag_shader:send("uColor1", {v.color1_r, v.color1_g, v.color1_b})
            text_frag_shader:send("uColor2", {v.color2_r, v.color2_g, v.color2_b})

            d.model:draw(text_frag_shader)

            -- Debug: draw visible walls at screen edges
            d.wall_r:draw()
            d.wall_l:draw()
            d.wall_t:draw()
            d.wall_b:draw()
        end,
    }

    return programs
end

--------------------------------------------------------------------------------
-- State methods
--------------------------------------------------------------------------------

function Sandbox3DState:init(di)
    self.state_machine = di.stateMachine
    self.previous_state = nil
    self.programs = nil
    self.active_idx = 1
    self.dragging_slider = nil
    self.scroll_y = 0
    self.copy_flash = 0
    self.canvas3d = nil
end

function Sandbox3DState:enter(previous_state_name)
    self.previous_state = previous_state_name or Constants.state.DESKTOP
    self.programs = buildPrograms()
    self.active_idx = 1
    self.dragging_slider = nil
    self.scroll_y = 0

    for _, prog in ipairs(self.programs) do
        for _, p in ipairs(prog.params) do
            prog.values[p.key] = p.default
        end
    end

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local prog = self.programs[self.active_idx]
    if prog.init then prog.init(prog, w, h) end
end

function Sandbox3DState:switchProgram(dir)
    local old = self.active_idx
    self.active_idx = self.active_idx + dir
    if self.active_idx < 1 then self.active_idx = #self.programs end
    if self.active_idx > #self.programs then self.active_idx = 1 end
    if self.active_idx ~= old then
        self.scroll_y = 0
        self.dragging_slider = nil
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
        local prog = self.programs[self.active_idx]
        if prog.init then prog.init(prog, w, h) end
    end
end

function Sandbox3DState:update(dt)
    local mx, my = love.mouse.getPosition()

    -- Handle slider dragging
    if self.dragging_slider then
        local prog = self.programs[self.dragging_slider.prog_idx]
        local p = prog.params[self.dragging_slider.param_idx]
        local slider_x = SLIDER_PAD + LABEL_W
        local slider_w = PANEL_W - LABEL_W - VALUE_W - SLIDER_PAD * 2
        local t = (mx - slider_x) / slider_w
        t = math.max(0, math.min(1, t))
        local raw = p.min + t * (p.max - p.min)
        raw = math.floor(raw / p.step + 0.5) * p.step
        raw = math.max(p.min, math.min(p.max, raw))
        prog.values[p.key] = raw
    end

    if self.copy_flash > 0 then
        self.copy_flash = self.copy_flash - dt * 2
    end

    local prog = self.programs[self.active_idx]
    if prog.update then prog.update(prog, dt) end
end

function Sandbox3DState:copyValues()
    local prog = self.programs[self.active_idx]
    local lines = {prog.name .. " params:"}
    for _, p in ipairs(prog.params) do
        local val = prog.values[p.key]
        local fmt = p.step < 0.01 and "%.4f" or p.step < 0.1 and "%.3f" or p.step < 1 and "%.2f" or "%.0f"
        lines[#lines + 1] = string.format("  %s = " .. fmt, p.key, val)
    end
    love.system.setClipboardText(table.concat(lines, "\n"))
    self.copy_flash = 1.0
end

function Sandbox3DState:draw()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local prog = self.programs[self.active_idx]

    -- Ensure canvas matches screen size
    if not self.canvas3d or self.canvas3d:getWidth() ~= sw or self.canvas3d:getHeight() ~= sh then
        self.canvas3d = love.graphics.newCanvas(sw, sh)
    end

    -- Render 3D scene to canvas with depth buffer
    love.graphics.setCanvas({self.canvas3d, depthstencil = true})
    love.graphics.clear(0.06, 0.06, 0.1, 1)
    love.graphics.setDepthMode("lequal", true)
    love.graphics.setColor(1, 1, 1, 1)

    -- Reset camera up to Z-up default (3D Text overrides to Y-up)
    g3d.camera.up[1], g3d.camera.up[2], g3d.camera.up[3] = 0, 0, 1

    if prog.draw then prog.draw(prog, sw, sh) end

    love.graphics.setDepthMode()
    love.graphics.setShader()
    love.graphics.setCanvas()

    -- Draw 3D canvas to screen
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas3d, 0, 0)

    -- Draw panel background
    love.graphics.setColor(0.05, 0.05, 0.08, 0.85)
    love.graphics.rectangle('fill', 0, 0, PANEL_W, sh)
    love.graphics.setColor(0.3, 0.3, 0.4, 1)
    love.graphics.rectangle('line', PANEL_W, 0, 1, sh)

    -- Header: < ProgramName >
    local arrow_w = 24
    love.graphics.setColor(0.7, 0.7, 0.8, 1)
    love.graphics.printf("<", 4, 10, arrow_w, 'center')
    love.graphics.printf(">", PANEL_W - arrow_w - 4, 10, arrow_w, 'center')
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(prog.name, arrow_w + 4, 10, PANEL_W - arrow_w * 2 - 8, 'center')

    -- Param sliders
    love.graphics.setScissor(0, HEADER_H, PANEL_W, sh - HEADER_H)
    local y = HEADER_H - self.scroll_y
    local slider_x = SLIDER_PAD + LABEL_W
    local slider_w = PANEL_W - LABEL_W - VALUE_W - SLIDER_PAD * 2

    for _, p in ipairs(prog.params) do
        local val = prog.values[p.key]
        local t = (val - p.min) / (p.max - p.min)

        love.graphics.setColor(0.7, 0.7, 0.8, 1)
        love.graphics.printf(p.label, SLIDER_PAD, y + 1, LABEL_W - 4, 'right')

        love.graphics.setColor(0.2, 0.2, 0.25, 1)
        love.graphics.rectangle('fill', slider_x, y + 2, slider_w, SLIDER_H - 4, 3, 3)

        love.graphics.setColor(0.35, 0.5, 0.8, 1)
        local fill_w = math.max(0, t * slider_w)
        if fill_w > 0 then
            love.graphics.rectangle('fill', slider_x, y + 2, fill_w, SLIDER_H - 4, 3, 3)
        end

        local handle_x = slider_x + t * slider_w
        love.graphics.setColor(0.9, 0.9, 1.0, 1)
        love.graphics.circle('fill', handle_x, y + SLIDER_H / 2, 5)

        local fmt = p.step < 0.01 and "%.4f" or p.step < 0.1 and "%.3f" or p.step < 1 and "%.2f" or "%.0f"
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        love.graphics.printf(string.format(fmt, val), PANEL_W - VALUE_W - SLIDER_PAD, y + 1, VALUE_W, 'left')

        y = y + ROW_H
    end
    love.graphics.setScissor()

    -- Copy button
    local btn_w, btn_h = 50, 20
    local btn_x = (PANEL_W - btn_w) / 2
    local btn_y = sh - 44
    local bmx, bmy = love.mouse.getPosition()
    local hover = bmx >= btn_x and bmx <= btn_x + btn_w and bmy >= btn_y and bmy <= btn_y + btn_h
    love.graphics.setColor(hover and {0.35, 0.5, 0.8, 1} or {0.2, 0.25, 0.35, 1})
    love.graphics.rectangle('fill', btn_x, btn_y, btn_w, btn_h, 3, 3)
    love.graphics.setColor(0.9, 0.9, 1.0, 1)
    love.graphics.printf("Copy", btn_x, btn_y + 3, btn_w, 'center')

    if self.copy_flash and self.copy_flash > 0 then
        love.graphics.setColor(0.4, 0.8, 0.4, self.copy_flash)
        love.graphics.printf("Copied!", 0, btn_y - 16, PANEL_W, 'center')
    end

    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.printf("Left/Right: switch   Ctrl+C: copy   F8/ESC: close", 0, sh - 20, PANEL_W, 'center')
end

function Sandbox3DState:getSliderAtPos(mx, my)
    local prog = self.programs[self.active_idx]
    local slider_x = SLIDER_PAD + LABEL_W
    local slider_w = PANEL_W - LABEL_W - VALUE_W - SLIDER_PAD * 2

    for i, _ in ipairs(prog.params) do
        local y = HEADER_H - self.scroll_y + (i - 1) * ROW_H
        if mx >= slider_x - 6 and mx <= slider_x + slider_w + 6 and
           my >= y and my <= y + SLIDER_H then
            return i
        end
    end
    return nil
end

function Sandbox3DState:mousepressed(x, y, button)
    if button ~= 1 then return end

    local h = love.graphics.getHeight()
    local btn_w, btn_h = 50, 20
    local btn_x = (PANEL_W - btn_w) / 2
    local btn_y = h - 44
    if x >= btn_x and x <= btn_x + btn_w and y >= btn_y and y <= btn_y + btn_h then
        self:copyValues()
        return true
    end

    if y < HEADER_H then
        local arrow_w = 24
        if x < arrow_w + 4 then
            self:switchProgram(-1)
            return true
        elseif x > PANEL_W - arrow_w - 4 and x < PANEL_W then
            self:switchProgram(1)
            return true
        end
    end

    if x < PANEL_W then
        local idx = self:getSliderAtPos(x, y)
        if idx then
            self.dragging_slider = {prog_idx = self.active_idx, param_idx = idx}
            local prog = self.programs[self.active_idx]
            local p = prog.params[idx]
            local slider_x = SLIDER_PAD + LABEL_W
            local slider_w = PANEL_W - LABEL_W - VALUE_W - SLIDER_PAD * 2
            local t = (x - slider_x) / slider_w
            t = math.max(0, math.min(1, t))
            local raw = p.min + t * (p.max - p.min)
            raw = math.floor(raw / p.step + 0.5) * p.step
            raw = math.max(p.min, math.min(p.max, raw))
            prog.values[p.key] = raw
            return true
        end
    end
end

function Sandbox3DState:mousereleased(x, y, button)
    if button == 1 then
        self.dragging_slider = nil
    end
end

function Sandbox3DState:wheelmoved(x, y)
    local mx = love.mouse.getX()
    if mx < PANEL_W then
        local prog = self.programs[self.active_idx]
        local content_h = #prog.params * ROW_H
        local visible_h = love.graphics.getHeight() - HEADER_H
        local max_scroll = math.max(0, content_h - visible_h)
        self.scroll_y = math.max(0, math.min(max_scroll, self.scroll_y - y * 30))
        return true
    end
end

function Sandbox3DState:keypressed(key)
    if key == 'f8' or key == 'escape' then
        self.state_machine:switch(self.previous_state)
        return true
    end
    if key == 'left' then
        self:switchProgram(-1)
        return true
    end
    if key == 'right' then
        self:switchProgram(1)
        return true
    end
    if key == 'c' and love.keyboard.isDown('lctrl', 'rctrl') then
        self:copyValues()
        return true
    end
end

return Sandbox3DState
