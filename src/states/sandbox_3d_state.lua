local Object = require('class')
local Constants = require('src.constants')
local WadParser = require('src.utils.wad_parser')

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
    -- Find tight bounds of actual opaque pixels
    local min_gx, max_gx = grid_w, 0
    local min_gy, max_gy = grid_h, 0
    for gy = 0, grid_h - 1 do
        for gx = 0, grid_w - 1 do
            if grid[gy][gx] then
                if gx < min_gx then min_gx = gx end
                if gx > max_gx then max_gx = gx end
                if gy < min_gy then min_gy = gy end
                if gy > max_gy then max_gy = gy end
            end
        end
    end

    local world_w = 4.3
    local sc = world_w / grid_w

    -- Center on the actual opaque region, not the full grid
    local ox = (min_gx + max_gx + 1) / 2
    local oy = (min_gy + max_gy + 1) / 2
    local ez = extrude

    -- Tight half-extents matching visible content
    local tight_hw = (max_gx - min_gx + 1) * sc / 2
    local tight_hh = (max_gy - min_gy + 1) * sc / 2

    print(string.format("TEXT BOUNDS: grid=%dx%d opaque=[%d..%d, %d..%d] center=(%.1f,%.1f) tight_hw=%.3f tight_hh=%.3f old_hw=%.3f old_hh=%.3f",
        grid_w, grid_h, min_gx, max_gx, min_gy, max_gy, ox, oy, tight_hw, tight_hh, world_w/2, grid_h*sc/2))
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

    return verts, tight_hw, tight_hh
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
            prog.data.rot_x = 0
            prog.data.rot_y = 0
            prog.data.rot_z = 0
            prog.data.last_extrude = nil
            prog.data.bounce_dbg = false

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
            d.rot_x = v.spin_x * t + v.sway_x * math.sin(t * 1.0)
            d.rot_y = v.spin_y * t + v.sway_y * math.sin(t * 1.3)
            d.rot_z = v.spin_z * t + v.sway_z * math.sin(t * 0.7)

            -- Drift (bounce happens in draw where actual matrices are available)
            local cam_z = 5.5 / v.text_size
            local speed_scale = cam_z * 0.15
            d.wx = d.wx + d.vx * v.drift_x * speed_scale * dt
            d.wy = d.wy + d.vy * v.drift_y * speed_scale * dt
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

            -- Set model transform before bounce check
            d.model:setTransform({d.wx, d.wy, 0}, {d.rot_x, d.rot_y, d.rot_z})

            -- Bounce using the ACTUAL g3d matrices from the rendering pipeline
            local M = d.model.matrix
            local P = g3d.camera.projectionMatrix

            local hw, hh, hz = d.text_hw, d.text_hh, v.extrude
            local max_nx, max_nx_rpx, max_nx_rpz = -math.huge, 0, 0
            local min_nx, min_nx_rpx, min_nx_rpz =  math.huge, 0, 0
            local max_ny, max_ny_rpy, max_ny_rpz = -math.huge, 0, 0
            local min_ny, min_ny_rpy, min_ny_rpz =  math.huge, 0, 0

            for i = 1, 8 do
                local lx = (i <= 4) and -hw or hw
                local ly = (i % 4 <= 1) and -hh or hh
                local lz = (i % 2 == 1) and -hz or hz

                -- Rotated position from the actual model matrix (excludes translation)
                local rpx = M[1]*lx + M[2]*ly + M[3]*lz
                local rpy = M[5]*lx + M[6]*ly + M[7]*lz
                local rpz = M[9]*lx + M[10]*ly + M[11]*lz

                local depth = cam_z - rpz
                if depth > 0.01 then
                    -- NDC using actual projection matrix values
                    local nx = P[1] * (d.wx + rpx) / depth
                    local ny = P[6] * (d.wy + rpy) / depth

                    if nx > max_nx then max_nx = nx; max_nx_rpx = rpx; max_nx_rpz = rpz end
                    if nx < min_nx then min_nx = nx; min_nx_rpx = rpx; min_nx_rpz = rpz end
                    if ny > max_ny then max_ny = ny; max_ny_rpy = rpy; max_ny_rpz = rpz end
                    if ny < min_ny then min_ny = ny; min_ny_rpy = rpy; min_ny_rpz = rpz end
                end
            end

            local bounced = false
            local bounce_side = ""

            if max_nx > 1 and d.vx > 0 then
                d.vx = -1
                local dep = cam_z - max_nx_rpz
                d.wx = dep / P[1] - max_nx_rpx
                bounced = true
                bounce_side = bounce_side .. "R "
            end
            if min_nx < -1 and d.vx < 0 then
                d.vx = 1
                local dep = cam_z - min_nx_rpz
                d.wx = -dep / P[1] - min_nx_rpx
                bounced = true
                bounce_side = bounce_side .. "L "
            end
            if max_ny > 1 and d.vy > 0 then
                d.vy = -1
                local dep = cam_z - max_ny_rpz
                d.wy = dep / P[6] - max_ny_rpy
                bounced = true
                bounce_side = bounce_side .. "B "
            end
            if min_ny < -1 and d.vy < 0 then
                d.vy = 1
                local dep = cam_z - min_ny_rpz
                d.wy = -dep / P[6] - min_ny_rpy
                bounced = true
                bounce_side = bounce_side .. "T "
            end

            if bounced then
                d.model:setTransform({d.wx, d.wy, 0}, {d.rot_x, d.rot_y, d.rot_z})
                if not d.bounce_dbg then
                    d.bounce_dbg = true
                    print(string.format("BOUNCE[%s]: P[1]=%.6f P[6]=%.6f cam_z=%.3f hw=%.3f hh=%.3f hz=%.3f w=%d h=%d",
                        bounce_side, P[1], P[6], cam_z, hw, hh, hz, w, h))
                end
            end

            text_frag_shader:send("uViewPos", {0, 0, cam_z})
            text_frag_shader:send("uSpecular", v.specular)
            text_frag_shader:send("uSurface", v.surface)
            text_frag_shader:send("uColor1", {v.color1_r, v.color1_g, v.color1_b})
            text_frag_shader:send("uColor2", {v.color2_r, v.color2_g, v.color2_b})

            d.model:draw(text_frag_shader)

            -- Store edge marker flag for 2D overlay
            d.show_edges = true
        end,
    }

    -- 7. FPS Demo (WASD + mouse look, simple map)
    programs[#programs+1] = {
        name = "FPS Demo",
        params = {
            {key="move_speed", label="Speed", min=1, max=20, default=8, step=0.5},
            {key="sensitivity", label="Sens", min=0.1, max=3.0, default=1.0, step=0.05},
            {key="jump_force", label="Jump", min=1, max=15, default=6, step=0.5},
            {key="gravity", label="Gravity", min=5, max=30, default=15, step=0.5},
            {key="fov_deg", label="FOV", min=45, max=120, default=90, step=1},
        },
        values = {}, data = {},
        init = function(prog, w, h)
            local d = prog.data
            d.px, d.py, d.pz = 0, -22, 1.7
            d.vz = 0
            d.on_ground = true
            d.dir = math.pi / 2
            d.pitch = 0
            d.mouse_captured = false
            d.mouse_dx, d.mouse_dy = 0, 0
            d.fps_hud = true
            d.models = {}
            d.colliders = {}

            local WT, WH = 0.3, 4

            local function solid(c, cx,cy,cz, sx,sy,sz)
                local m = g3d.newModel(generateCube(c[1],c[2],c[3]), white_texture)
                m:setTransform({cx,cy,cz}, {0,0,0}, {sx,sy,sz})
                d.models[#d.models+1] = m
                d.colliders[#d.colliders+1] = {x=cx, y=cy, hx=sx/2, hy=sy/2}
            end
            local function vis(c, cx,cy,cz, sx,sy,sz)
                local m = g3d.newModel(generateCube(c[1],c[2],c[3]), white_texture)
                m:setTransform({cx,cy,cz}, {0,0,0}, {sx,sy,sz})
                d.models[#d.models+1] = m
            end
            local function wall(c, x1,y1, x2,y2)
                local dx, dy = math.abs(x2-x1), math.abs(y2-y1)
                solid(c, (x1+x2)/2,(y1+y2)/2,WH/2, dx<0.01 and WT or dx, dy<0.01 and WT or dy, WH)
            end
            local function flr(c, x1,y1, x2,y2)
                vis(c, (x1+x2)/2,(y1+y2)/2,-0.05, math.abs(x2-x1),math.abs(y2-y1),0.1)
            end
            local function clg(c, x1,y1, x2,y2)
                vis(c, (x1+x2)/2,(y1+y2)/2,WH+0.05, math.abs(x2-x1),math.abs(y2-y1),0.1)
            end
            local function pil(c, x,y, s)
                s = s or 0.8
                solid(c, x,y,WH/2, s,s,WH)
            end
            local function orb(r,g,b, x,y,z, rad)
                local s = g3d.newModel(generateSphere(rad or 0.4, 10, 14, r,g,b), white_texture)
                s:setTransform({x,y,z}, {0,0,0})
                d.models[#d.models+1] = s
            end

            -- Wall colors
            local stn = {0.50,0.48,0.44}
            local drk = {0.38,0.35,0.33}
            local rst = {0.58,0.32,0.28}
            local tek = {0.32,0.38,0.55}
            local grn = {0.32,0.50,0.30}
            local arn = {0.55,0.48,0.38}
            local plr = {0.60,0.55,0.50}
            local crt = {0.50,0.38,0.25}
            local mtl = {0.45,0.45,0.48}
            local bld = {0.65,0.20,0.18}
            local tro = {0.45,0.30,0.30}
            -- Floor colors
            local fstn = {0.30,0.28,0.26}
            local fdrk = {0.22,0.20,0.19}
            local frst = {0.35,0.22,0.20}
            local ftek = {0.20,0.25,0.35}
            local fgrn = {0.18,0.28,0.18}
            local farn = {0.35,0.30,0.24}
            local ftro = {0.28,0.20,0.20}
            local cl = {0.25,0.24,0.23}

            -- ===== SPAWN ROOM (-4,-24) to (4,-20) =====
            flr(fstn, -4,-24, 4,-20)
            clg(cl, -4,-24, 4,-20)
            wall(stn, -4,-24, 4,-24)
            wall(stn, -4,-24, -4,-20)
            wall(stn, 4,-24, 4,-20)
            wall(stn, -4,-20, -1.5,-20)
            wall(stn, 1.5,-20, 4,-20)

            -- ===== SOUTH CORRIDOR (-1.5,-20) to (1.5,-14) =====
            flr(fdrk, -1.5,-20, 1.5,-14)
            clg(cl, -1.5,-20, 1.5,-14)
            wall(drk, -1.5,-20, -1.5,-14)
            wall(drk, 1.5,-20, 1.5,-14)

            -- ===== ENTRY HALL (-8,-14) to (8,-4) =====
            flr(fstn, -8,-14, 8,-4)
            clg(cl, -8,-14, 8,-4)
            wall(stn, -8,-14, -1.5,-14)
            wall(stn, 1.5,-14, 8,-14)
            wall(stn, -8,-4, -1.5,-4)
            wall(stn, 1.5,-4, 8,-4)
            wall(stn, -8,-14, -8,-11)
            wall(stn, -8,-7, -8,-4)
            wall(stn, 8,-14, 8,-11)
            wall(stn, 8,-7, 8,-4)
            pil(plr, -5,-9)
            pil(plr, 5,-9)
            -- Light columns
            solid(stn, -3,-13,1.5, 0.4,0.4,3)
            solid(stn, 3,-13,1.5, 0.4,0.4,3)

            -- ===== WEST CORRIDOR (-14,-11) to (-8,-7) =====
            flr(fdrk, -14,-11, -8,-7)
            clg(cl, -14,-11, -8,-7)
            wall(drk, -14,-11, -8,-11)
            wall(drk, -14,-7, -8,-7)

            -- ===== ARMORY (-24,-14) to (-14,-4) =====
            flr(frst, -24,-14, -14,-4)
            clg(cl, -24,-14, -14,-4)
            wall(rst, -24,-14, -14,-14)
            wall(rst, -24,-4, -14,-4)
            wall(rst, -24,-14, -24,-4)
            wall(rst, -14,-14, -14,-11)
            wall(rst, -14,-7, -14,-4)
            -- Weapon racks along west wall
            solid(mtl, -23,-13,1.5, 0.3,1.5,3)
            solid(mtl, -23,-5.5,1.5, 0.3,1.5,3)
            -- Crate stacks
            solid(crt, -18,-12.5,0.5, 1.2,1.2,1)
            solid(crt, -16.5,-12.5,0.5, 1,1,1)
            solid(crt, -18,-12.5,1.5, 0.8,0.8,0.8)
            solid(crt, -20,-6,0.5, 1,1,1)
            solid(crt, -20,-6,1.5, 0.7,0.7,0.7)
            pil(rst, -19,-9)
            -- Ammo shelf
            solid(mtl, -15.5,-13,1, 0.4,2,2)

            -- ===== EAST CORRIDOR (8,-11) to (14,-7) =====
            flr(fdrk, 8,-11, 14,-7)
            clg(cl, 8,-11, 14,-7)
            wall(drk, 8,-11, 14,-11)
            wall(drk, 8,-7, 14,-7)

            -- ===== TECH LAB (14,-14) to (24,-4) =====
            flr(ftek, 14,-14, 24,-4)
            clg(cl, 14,-14, 24,-4)
            wall(tek, 14,-14, 24,-14)
            wall(tek, 14,-4, 24,-4)
            wall(tek, 24,-14, 24,-4)
            wall(tek, 14,-14, 14,-11)
            wall(tek, 14,-7, 14,-4)
            -- Computer banks along east wall
            solid(tek, 23,-13,1, 1.5,0.4,2)
            solid(tek, 23,-5.5,1, 1.5,0.4,2)
            -- Central console
            solid(mtl, 19,-9,0.6, 2,0.5,1.2)
            -- Power core
            orb(0.3,0.7,0.9, 19,-9,1.6, 0.4)
            -- Server rack
            solid(tek, 15.5,-5.5,1.5, 0.5,2,3)

            -- ===== MAIN CORRIDOR (-1.5,-4) to (1.5,10) =====
            flr(fdrk, -1.5,-4, 1.5,10)
            clg(cl, -1.5,-4, 1.5,10)
            wall(drk, -1.5,-4, -1.5,10)
            wall(drk, 1.5,-4, 1.5,10)

            -- ===== GREAT HALL (-12,10) to (12,26) =====
            flr(fstn, -12,10, 12,26)
            clg(cl, -12,10, 12,26)
            wall(stn, -12,10, -1.5,10)
            wall(stn, 1.5,10, 12,10)
            wall(stn, -12,26, -1.5,26)
            wall(stn, 1.5,26, 12,26)
            -- West wall: door to crypt at y[14,20]
            wall(stn, -12,10, -12,14)
            wall(stn, -12,20, -12,26)
            -- East wall: door to gallery at y[17,21]
            wall(stn, 12,10, 12,17)
            wall(stn, 12,21, 12,26)
            -- Four grand pillars
            pil(plr, -6,14, 1.0)
            pil(plr, 6,14, 1.0)
            pil(plr, -6,22, 1.0)
            pil(plr, 6,22, 1.0)
            -- Raised dais with artifact
            vis({0.40,0.38,0.35}, 0,18,0.15, 4,4,0.3)
            orb(0.85,0.82,0.75, 0,18,0.65, 0.35)
            -- Wall sconces (decorative pillars)
            solid(stn, -11,18,1.5, 0.35,0.35,3)
            solid(stn, 11,18,1.5, 0.35,0.35,3)

            -- ===== GALLERY (12,16) to (20,22) =====
            flr(fstn, 12,16, 20,22)
            clg(cl, 12,16, 20,22)
            wall(stn, 12,16, 20,16)
            wall(stn, 12,22, 20,22)
            wall(stn, 20,16, 20,22)
            -- Display pedestals with colored orbs
            solid(plr, 16,17.5,0.4, 0.6,0.6,0.8)
            orb(0.9,0.15,0.15, 16,17.5,1.2, 0.3)
            solid(plr, 16,20.5,0.4, 0.6,0.6,0.8)
            orb(0.15,0.15,0.9, 16,20.5,1.2, 0.3)
            solid(plr, 19,19,0.4, 0.6,0.6,0.8)
            orb(0.15,0.9,0.15, 19,19,1.2, 0.3)

            -- ===== CRYPT (-24,12) to (-12,22) =====
            flr(fgrn, -24,12, -12,22)
            clg(cl, -24,12, -12,22)
            wall(grn, -24,12, -12,12)
            wall(grn, -24,22, -12,22)
            wall(grn, -24,12, -24,22)
            -- East wall covered by Great Hall west wall segments
            -- Sarcophagi
            solid(grn, -20,17,0.5, 1.5,3,1)
            solid(grn, -16,17,0.5, 1.5,3,1)
            pil(grn, -22.5,14, 0.6)
            pil(grn, -22.5,20, 0.6)
            -- Toxic pool (glowing floor decor)
            vis({0.2,0.7,0.2}, -18,14,0.02, 2.5,2.5,0.04)
            -- Bone pile
            vis({0.75,0.72,0.65}, -14,17,0.2, 1,1,0.4)

            -- ===== NORTH CORRIDOR (-1.5,26) to (1.5,34) =====
            flr(fdrk, -1.5,26, 1.5,34)
            clg(cl, -1.5,26, 1.5,34)
            wall(drk, -1.5,26, -1.5,34)
            wall(drk, 1.5,26, 1.5,34)

            -- ===== ARENA (-12,34) to (12,48) =====
            flr(farn, -12,34, 12,48)
            clg(cl, -12,34, 12,48)
            wall(arn, -12,34, -1.5,34)
            wall(arn, 1.5,34, 12,34)
            wall(arn, -12,48, 12,48)
            -- West wall: door to trophy room at y[40,44]
            wall(arn, -12,34, -12,40)
            wall(arn, -12,44, -12,48)
            wall(arn, 12,34, 12,48)
            -- Pillars
            pil(plr, -8,38)
            pil(plr, 8,38)
            pil(plr, -8,44)
            pil(plr, 8,44)
            pil(plr, -4,46.5)
            pil(plr, 4,46.5)
            -- Center platform with trophy
            vis(arn, 0,41,0.2, 3,3,0.4)
            orb(0.9,0.8,0.1, 0,41,0.9, 0.5)
            -- Blood stains
            vis(bld, -3,39,0.02, 1.8,1,0.04)
            vis(bld, 4,43,0.02, 1.2,1.5,0.04)
            vis(bld, -1,45,0.02, 0.8,0.6,0.04)
            -- Barricade
            solid(crt, 5,37,0.5, 2,0.4,1)
            solid(crt, -5,37,0.5, 2,0.4,1)

            -- ===== TROPHY ROOM (-20,38) to (-12,46) =====
            flr(ftro, -20,38, -12,46)
            clg(cl, -20,38, -12,46)
            wall(tro, -20,38, -12,38)
            wall(tro, -20,46, -12,46)
            wall(tro, -20,38, -20,46)
            -- East wall covered by Arena west wall segments
            -- Trophy pedestals
            solid(tro, -18,40,0.4, 0.6,0.6,0.8)
            orb(0.8,0.2,0.8, -18,40,1.2, 0.3)
            solid(tro, -18,44,0.4, 0.6,0.6,0.8)
            orb(0.2,0.8,0.8, -18,44,1.2, 0.3)
            solid(tro, -15,42,0.4, 0.6,0.6,0.8)
            orb(0.8,0.8,0.2, -15,42,1.2, 0.3)
            -- Display shelf
            solid(mtl, -17,42,1.2, 4,0.3,2.4)
        end,
        update = function(prog, dt)
            local v = prog.values
            local d = prog.data

            -- Mouse look (only when captured)
            if d.mouse_captured then
                local sens = v.sensitivity / 300
                d.dir = d.dir - d.mouse_dx * sens
                d.pitch = math.max(-math.pi/2 + 0.01, math.min(math.pi/2 - 0.01, d.pitch - d.mouse_dy * sens))
            end
            d.mouse_dx, d.mouse_dy = 0, 0

            -- Movement
            local speed = v.move_speed
            if d.mouse_captured then
                -- FPS mode: WASD = forward/back/strafe
                local mx, my = 0, 0
                if love.keyboard.isDown('w') then mx = mx + 1 end
                if love.keyboard.isDown('s') then mx = mx - 1 end
                if love.keyboard.isDown('a') then my = my + 1 end
                if love.keyboard.isDown('d') then my = my - 1 end

                if mx ~= 0 or my ~= 0 then
                    local angle = math.atan2(my, mx)
                    local dx = math.cos(d.dir + angle) * speed * dt
                    local dy = math.sin(d.dir + angle) * speed * dt

                    local r = 0.25
                    local new_px = d.px + dx
                    local blocked_x = false
                    for _, c in ipairs(d.colliders) do
                        if new_px + r > c.x - c.hx and new_px - r < c.x + c.hx and
                           d.py + r > c.y - c.hy and d.py - r < c.y + c.hy then
                            blocked_x = true; break
                        end
                    end
                    if not blocked_x then d.px = new_px end

                    local new_py = d.py + dy
                    local blocked_y = false
                    for _, c in ipairs(d.colliders) do
                        if d.px + r > c.x - c.hx and d.px - r < c.x + c.hx and
                           new_py + r > c.y - c.hy and new_py - r < c.y + c.hy then
                            blocked_y = true; break
                        end
                    end
                    if not blocked_y then d.py = new_py end
                end

                -- Jump (FPS mode only)
                if love.keyboard.isDown('space') and d.on_ground then
                    d.vz = v.jump_force
                    d.on_ground = false
                end
            else
                -- Doom mode: A/D turn, W/S forward/back, no strafe, no jump
                local turn_speed = 3.0
                if love.keyboard.isDown('a') then d.dir = d.dir + turn_speed * dt end
                if love.keyboard.isDown('d') then d.dir = d.dir - turn_speed * dt end

                local mx = 0
                if love.keyboard.isDown('w') then mx = mx + 1 end
                if love.keyboard.isDown('s') then mx = mx - 1 end

                if mx ~= 0 then
                    local dx = math.cos(d.dir) * speed * mx * dt
                    local dy = math.sin(d.dir) * speed * mx * dt

                    local r = 0.25
                    local new_px = d.px + dx
                    local blocked_x = false
                    for _, c in ipairs(d.colliders) do
                        if new_px + r > c.x - c.hx and new_px - r < c.x + c.hx and
                           d.py + r > c.y - c.hy and d.py - r < c.y + c.hy then
                            blocked_x = true; break
                        end
                    end
                    if not blocked_x then d.px = new_px end

                    local new_py = d.py + dy
                    local blocked_y = false
                    for _, c in ipairs(d.colliders) do
                        if d.px + r > c.x - c.hx and d.px - r < c.x + c.hx and
                           new_py + r > c.y - c.hy and new_py - r < c.y + c.hy then
                            blocked_y = true; break
                        end
                    end
                    if not blocked_y then d.py = new_py end
                end
            end

            d.vz = d.vz - v.gravity * dt
            d.pz = d.pz + d.vz * dt

            local eye_h = 1.7
            if d.pz <= eye_h then
                d.pz = eye_h
                d.vz = 0
                d.on_ground = true
            end
        end,
        draw = function(prog, w, h)
            local v = prog.values
            local d = prog.data

            g3d.camera.fov = math.rad(v.fov_deg)
            g3d.camera.aspectRatio = w / h
            g3d.camera.updateProjectionMatrix()

            -- Build target from direction + pitch
            local cosPitch = math.cos(d.pitch)
            local tx = d.px + math.cos(d.dir) * cosPitch
            local ty = d.py + math.sin(d.dir) * cosPitch
            local tz = d.pz + math.sin(d.pitch)

            g3d.camera.lookAt(d.px, d.py, d.pz, tx, ty, tz)

            for _, model in ipairs(d.models) do
                model:draw()
            end

            -- Flag for HUD overlay
            d.fps_hud = true
        end,
        mousemoved = function(prog, dx, dy)
            if prog.data.mouse_captured then
                prog.data.mouse_dx = prog.data.mouse_dx + dx
                prog.data.mouse_dy = prog.data.mouse_dy + dy
            end
        end,
    }

    -- 8. WAD Viewer (load and display Doom WAD levels)
    programs[#programs+1] = {
        name = "WAD Viewer",
        params = {
            {key="map_index", label="Map #", min=1, max=32, default=1, step=1},
            {key="move_speed", label="Speed", min=1, max=40, default=12, step=0.5},
            {key="sensitivity", label="Sens", min=0.1, max=3.0, default=1.0, step=0.05},
            {key="fov_deg", label="FOV", min=45, max=120, default=90, step=1},
        },
        values = {}, data = {},
        init = function(prog, w, h)
            local d = prog.data
            d.px, d.py, d.pz = 0, 0, 2
            d.dir = 0
            d.pitch = 0
            d.vz = 0  -- vertical velocity for gravity
            d.mouse_captured = false
            d.mouse_dx, d.mouse_dy = 0, 0
            d.fps_hud = true
            d.noclip = true
            d.on_ground = false
            d.models = {}
            d.collision_lines = {}
            d.sector_regions = {}
            d.wad = nil
            d.map_names = {}
            d.current_map = 0
            d.error_msg = nil

            -- Find and parse WAD
            local wad_files = WadParser.findWadFiles()
            if #wad_files == 0 then
                d.error_msg = "No .wad files found in assets/wads/"
                return
            end

            local wad, err = WadParser.parse(wad_files[1])
            if not wad then
                d.error_msg = "WAD parse error: " .. (err or "unknown")
                return
            end

            d.wad = wad
            d.wad_name = wad_files[1]
            d.map_names = WadParser.getMapNames(wad)
            if #d.map_names == 0 then
                d.error_msg = "No maps found in WAD"
                return
            end

            -- Attach loadMap method
            d.loadMap = function(self, map_idx)
                map_idx = math.max(1, math.min(map_idx, #self.map_names))
                self.current_map = map_idx
                self.models = {}

                local map_name = self.map_names[map_idx]
                if not map_name then return end

                local map_data = WadParser.loadMap(self.wad, map_name)
                if not map_data then
                    self.error_msg = "Failed to load " .. map_name
                    return
                end

                local scale = 1 / 32
                local geom = WadParser.buildGeometry(map_data, scale)

                if #geom.wall_verts >= 3 then
                    local m = g3d.newModel(geom.wall_verts, white_texture)
                    m:setTransform({0,0,0}, {0,0,0}, {1,1,1})
                    self.models[#self.models + 1] = m
                end
                if #geom.floor_verts >= 3 then
                    local m = g3d.newModel(geom.floor_verts, white_texture)
                    m:setTransform({0,0,0}, {0,0,0}, {1,1,1})
                    self.models[#self.models + 1] = m
                end
                if #geom.ceil_verts >= 3 then
                    local m = g3d.newModel(geom.ceil_verts, white_texture)
                    m:setTransform({0,0,0}, {0,0,0}, {1,1,1})
                    self.models[#self.models + 1] = m
                end

                for _, thing in ipairs(geom.things) do
                    local c = thing.color
                    local sz = thing.size
                    local m = g3d.newModel(generateCube(c[1], c[2], c[3]), white_texture)
                    m:setTransform({thing.x, thing.y, sz/2}, {0,0,0}, {sz, sz, sz})
                    self.models[#self.models + 1] = m
                end

                self.collision_lines = geom.collision_lines or {}
                self.sector_regions = geom.sector_regions or {}

                if geom.player_start then
                    self.px = geom.player_start.x
                    self.py = geom.player_start.y
                    self.pz = 1.7
                    self.vz = 0
                    self.on_ground = false
                    self.dir = math.rad(geom.player_start.angle)
                end
                self.error_msg = nil
            end

            -- Load first map
            d.current_map = 1
            d:loadMap(1)
        end,
        update = function(prog, dt)
            local v = prog.values
            local d = prog.data
            if d.error_msg then return end

            -- Check for map switch
            local mi = math.floor(v.map_index + 0.5)
            mi = math.max(1, math.min(mi, #d.map_names))
            if mi ~= d.current_map and #d.map_names > 0 then
                d:loadMap(mi)
            end

            -- Mouse look (only when captured)
            if d.mouse_captured then
                local sens = v.sensitivity / 300
                d.dir = d.dir - d.mouse_dx * sens
                d.pitch = math.max(-math.pi/2 + 0.01, math.min(math.pi/2 - 0.01, d.pitch - d.mouse_dy * sens))
            end
            d.mouse_dx, d.mouse_dy = 0, 0

            local speed = v.move_speed

            -- Compute desired movement delta
            local move_dx, move_dy = 0, 0
            if d.mouse_captured then
                -- FPS mode: WASD strafe
                local mx, my = 0, 0
                if love.keyboard.isDown('w') then mx = mx + 1 end
                if love.keyboard.isDown('s') then mx = mx - 1 end
                if love.keyboard.isDown('a') then my = my + 1 end
                if love.keyboard.isDown('d') then my = my - 1 end
                if mx ~= 0 or my ~= 0 then
                    local angle = math.atan2(my, mx)
                    move_dx = math.cos(d.dir + angle) * speed * dt
                    move_dy = math.sin(d.dir + angle) * speed * dt
                end
            else
                -- Doom mode: A/D turn, W/S forward/back
                local turn_speed = 3.0
                if love.keyboard.isDown('a') then d.dir = d.dir + turn_speed * dt end
                if love.keyboard.isDown('d') then d.dir = d.dir - turn_speed * dt end
                local mx = 0
                if love.keyboard.isDown('w') then mx = mx + 1 end
                if love.keyboard.isDown('s') then mx = mx - 1 end
                if mx ~= 0 then
                    move_dx = math.cos(d.dir) * speed * mx * dt
                    move_dy = math.sin(d.dir) * speed * mx * dt
                end
            end

            if d.noclip then
                -- Noclip: free fly, no collision
                d.px = d.px + move_dx
                d.py = d.py + move_dy
                if love.keyboard.isDown('space') then d.pz = d.pz + speed * dt end
                if love.keyboard.isDown('lshift') then d.pz = d.pz - speed * dt end
            else
                -- Clip mode: wall collision + gravity

                -- Find current floor height via point-in-polygon
                local function getFloorHeight(px, py)
                    local best_floor = nil
                    for _, reg in ipairs(d.sector_regions) do
                        local poly = reg.polygon
                        local inside = false
                        local n = #poly
                        local j = n
                        for i = 1, n do
                            local xi, yi = poly[i].x, poly[i].y
                            local xj, yj = poly[j].x, poly[j].y
                            if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
                                inside = not inside
                            end
                            j = i
                        end
                        if inside then
                            if not best_floor or reg.floor_h > best_floor then
                                best_floor = reg.floor_h
                            end
                        end
                    end
                    return best_floor
                end

                -- Circle-vs-line-segment collision
                local PLAYER_RADIUS = 0.5
                local EYE_HEIGHT = 1.28
                local new_x = d.px + move_dx
                local new_y = d.py + move_dy

                -- Iterative push-out (3 passes for corners)
                for _ = 1, 3 do
                    for _, cl in ipairs(d.collision_lines) do
                        local lx, ly = cl.x2 - cl.x1, cl.y2 - cl.y1
                        local len_sq = lx * lx + ly * ly
                        if len_sq > 0.0001 then
                            local t = ((new_x - cl.x1) * lx + (new_y - cl.y1) * ly) / len_sq
                            t = math.max(0, math.min(1, t))
                            local closest_x = cl.x1 + t * lx
                            local closest_y = cl.y1 + t * ly
                            local dx = new_x - closest_x
                            local dy = new_y - closest_y
                            local dist = math.sqrt(dx * dx + dy * dy)
                            if dist < PLAYER_RADIUS and dist > 0.0001 then
                                local push = (PLAYER_RADIUS - dist)
                                new_x = new_x + (dx / dist) * push
                                new_y = new_y + (dy / dist) * push
                            end
                        end
                    end
                end

                d.px = new_x
                d.py = new_y

                -- Gravity and floor tracking
                local GRAVITY = 20
                local floor_h = getFloorHeight(d.px, d.py)
                local target_z = (floor_h or 0) + EYE_HEIGHT

                if floor_h then
                    d.vz = d.vz - GRAVITY * dt
                    d.pz = d.pz + d.vz * dt

                    if d.pz <= target_z then
                        d.pz = target_z
                        d.vz = 0
                        d.on_ground = true
                    else
                        d.on_ground = false
                    end

                    -- Jump
                    if love.keyboard.isDown('space') and d.on_ground then
                        d.vz = 7
                        d.on_ground = false
                    end
                else
                    -- No sector found - gentle fall
                    d.vz = d.vz - GRAVITY * dt
                    d.pz = d.pz + d.vz * dt
                    d.on_ground = false
                end
            end
        end,
        draw = function(prog, w, h)
            local d = prog.data
            if d.error_msg then
                love.graphics.setColor(1, 0.3, 0.3, 1)
                love.graphics.printf(d.error_msg, 0, h / 2 - 10, w, 'center')
                return
            end

            local v = prog.values
            g3d.camera.fov = math.rad(v.fov_deg)
            g3d.camera.aspectRatio = w / h
            g3d.camera.updateProjectionMatrix()

            local cosPitch = math.cos(d.pitch)
            local tx = d.px + math.cos(d.dir) * cosPitch
            local ty = d.py + math.sin(d.dir) * cosPitch
            local tz = d.pz + math.sin(d.pitch)
            g3d.camera.lookAt(d.px, d.py, d.pz, tx, ty, tz)

            for _, model in ipairs(d.models) do
                model:draw()
            end

            d.fps_hud = true
        end,
        mousemoved = function(prog, dx, dy)
            if prog.data.mouse_captured then
                prog.data.mouse_dx = prog.data.mouse_dx + dx
                prog.data.mouse_dy = prog.data.mouse_dy + dy
            end
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
    -- Release mouse capture when switching away from any program
    love.mouse.setRelativeMode(false)
    local old_prog = self.programs[self.active_idx]
    if old_prog and old_prog.data and old_prog.data.mouse_captured ~= nil then
        old_prog.data.mouse_captured = false
    end

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

    -- Draw screen-edge reference lines for 3D Text bounce debugging
    if prog.data and prog.data.show_edges then
        love.graphics.setColor(0, 1, 0, 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.line(0, 0, 0, sh)          -- left screen edge
        love.graphics.line(sw - 1, 0, sw - 1, sh) -- right screen edge
        love.graphics.line(0, 0, sw, 0)           -- top screen edge
        love.graphics.line(0, sh - 1, sw, sh - 1) -- bottom screen edge
        love.graphics.setLineWidth(1)
    end

    -- FPS HUD: crosshair + capture prompt
    if prog.data and prog.data.fps_hud then
        local cx = (PANEL_W + sw) / 2
        local cy = sh / 2
        if prog.data.mouse_captured then
            -- Crosshair
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.setLineWidth(1)
            love.graphics.line(cx - 10, cy, cx - 3, cy)
            love.graphics.line(cx + 3, cy, cx + 10, cy)
            love.graphics.line(cx, cy - 10, cx, cy - 3)
            love.graphics.line(cx, cy + 3, cx, cy + 10)
            -- Mode indicator
            if prog.data.noclip ~= nil then
                local mode_str = prog.data.noclip and "NOCLIP" or "CLIP"
                love.graphics.setColor(1, 1, 0.5, 0.6)
                love.graphics.printf(mode_str .. "  [N]", PANEL_W, sh - 30, sw - PANEL_W, 'center')
            end
        else
            love.graphics.setColor(1, 1, 1, 0.8)
            local noclip_str = (prog.data.noclip == false) and "CLIP" or "NOCLIP"
            local mode_help
            if prog.data.noclip ~= false then
                mode_help = "DOOM MODE [" .. noclip_str .. "]: W/S move  |  A/D turn  |  TAB mouselook\nSpace up  |  LShift down  |  N toggle clip"
            else
                mode_help = "DOOM MODE [" .. noclip_str .. "]: W/S move  |  A/D turn  |  TAB mouselook\nSpace jump  |  N toggle noclip"
            end
            love.graphics.printf(mode_help, PANEL_W, sh / 2 - 20, sw - PANEL_W, 'center')
        end
        -- WAD viewer: show current map name
        if prog.data.map_names and prog.data.current_map > 0 then
            love.graphics.setColor(1, 1, 0.5, 0.9)
            local map_str = (prog.data.map_names[prog.data.current_map] or "?") .. " (" .. prog.data.current_map .. "/" .. #prog.data.map_names .. ")"
            love.graphics.printf(map_str, PANEL_W, 8, sw - PANEL_W, 'center')
        end
    end

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
    local help_text = "Left/Right: switch   Ctrl+C: copy   F8/ESC: close"
    if prog.data and prog.data.mouse_captured ~= nil then
        help_text = "Tab: capture mouse   F8/ESC: close"
    end
    love.graphics.printf(help_text, 0, sh - 20, PANEL_W, 'center')
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

    -- Click in 3D viewport to capture mouse (FPS programs)
    if x >= PANEL_W then
        local prog = self.programs[self.active_idx]
        if prog.data and prog.data.mouse_captured ~= nil and not prog.data.mouse_captured then
            prog.data.mouse_captured = true
            love.mouse.setRelativeMode(true)
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

function Sandbox3DState:mousemoved(x, y, dx, dy)
    local prog = self.programs and self.programs[self.active_idx]
    if prog and prog.mousemoved then
        prog.mousemoved(prog, dx, dy)
    end
end

function Sandbox3DState:keypressed(key)
    if key == 'f8' or key == 'escape' then
        love.mouse.setRelativeMode(false)
        self.state_machine:switch(self.previous_state)
        return true
    end

    -- Tab toggles mouse capture for FPS-style programs
    if key == 'tab' then
        local prog = self.programs[self.active_idx]
        if prog.data and prog.data.mouse_captured ~= nil then
            prog.data.mouse_captured = not prog.data.mouse_captured
            love.mouse.setRelativeMode(prog.data.mouse_captured)
            return true
        end
    end

    -- N toggles noclip for WAD viewer / FPS programs
    if key == 'n' then
        local prog = self.programs[self.active_idx]
        if prog.data and prog.data.noclip ~= nil then
            prog.data.noclip = not prog.data.noclip
            if not prog.data.noclip then
                prog.data.vz = 0
                prog.data.on_ground = false
            end
            return true
        end
    end

    -- Don't switch programs with arrow keys when mouse is captured (WASD mode)
    local prog = self.programs[self.active_idx]
    local captured = prog.data and prog.data.mouse_captured

    if key == 'left' and not captured then
        self:switchProgram(-1)
        return true
    end
    if key == 'right' and not captured then
        self:switchProgram(1)
        return true
    end
    if key == 'c' and love.keyboard.isDown('lctrl', 'rctrl') then
        self:copyValues()
        return true
    end
end

return Sandbox3DState
