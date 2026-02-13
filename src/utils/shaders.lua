local Shaders = {}

local compiled = {}

local function getOrCompile(name, glsl)
    if not compiled[name] then
        local ok, shader = pcall(love.graphics.newShader, glsl)
        if not ok then
            print("Shader compile error (" .. name .. "): " .. tostring(shader))
            return nil
        end
        compiled[name] = shader
    end
    return compiled[name]
end

function Shaders.clearCache()
    compiled = {}
end

-- Safe send: silently skip uniforms the GLSL compiler stripped as unused
local function safeSend(shader, name, ...)
    if shader:hasUniform(name) then
        shader:send(name, ...)
    end
end

--------------------------------------------------------------------------------
-- FLOWING
--
-- Domain-warped fractal noise with optional point-based displacement.
-- Points are generic {x, y, vx, vy} — the shader has no game knowledge.
--
-- Usage:
--   Shaders.drawFlowing(0, 0, w, h, params)
--------------------------------------------------------------------------------

local FLOWING_GLSL = [[
extern float time;
extern vec3 color1;
extern vec3 color2;
extern vec3 color3;
extern vec3 color4;
extern int num_colors;
extern float speed;
extern float scale;
extern float warp;
extern float contrast;
extern vec2 resolution;

extern vec4 points[32];
extern int num_points;
extern float point_radius;
extern float point_strength;


vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)),
             dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(dot(hash(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    vec2 uv = tc;
    float aspect = resolution.x / resolution.y;
    uv.x *= aspect;

    float t = time * speed;

    vec2 q = vec2(fbm(uv * scale + t * 0.1),
                  fbm(uv * scale + vec2(5.2, 1.3) + t * 0.12));

    vec2 r = vec2(fbm(uv * scale + q * warp * 4.0 + vec2(1.7, 9.2) + t * 0.15),
                  fbm(uv * scale + q * warp * 4.0 + vec2(8.3, 2.8) + t * 0.13));

    float f = fbm(uv * scale + r * warp * 4.0);

    // Accumulate point influence
    float point_influence = 0.0;
    if (num_points > 0 && point_strength > 0.0) {
        for (int i = 0; i < 32; i++) {
            if (i >= num_points) break;
            vec2 diff = tc - points[i].xy;
            diff.x *= aspect;
            float dist2 = dot(diff, diff);
            float influence = exp(-dist2 / point_radius);
            float vel = length(points[i].zw);
            point_influence += vel * influence * point_strength;
        }
    }

    float blend = clamp((f + 0.6) * 0.5 + point_influence, 0.0, 1.0);
    blend = pow(blend, contrast);

    vec3 col;
    if (num_colors <= 2) {
        col = mix(color1, color2, blend);
    } else if (num_colors == 3) {
        float z = blend * 2.0;
        if (z < 1.0) { col = mix(color1, color2, z); }
        else         { col = mix(color2, color3, z - 1.0); }
    } else {
        float z = blend * 3.0;
        if (z < 1.0)      { col = mix(color1, color2, z); }
        else if (z < 2.0) { col = mix(color2, color3, z - 1.0); }
        else               { col = mix(color3, color4, z - 2.0); }
    }

    col *= 0.85 + 0.15 * (f * f + f);

    return vec4(col, 1.0) * vcolor;
}
]]

function Shaders.getFlowing()
    return getOrCompile('flowing', FLOWING_GLSL)
end

function Shaders.sendFlowing(shader, params)
    params = params or {}
    local colors = params.colors or {{0.8, 0.1, 0.3}, {0.2, 0.1, 0.6}}
    safeSend(shader, 'time', params.time or love.timer.getTime())
    safeSend(shader, 'speed', params.speed or 0.4)
    safeSend(shader, 'scale', params.scale or 1.5)
    safeSend(shader, 'warp', params.warp or 1.0)
    safeSend(shader, 'contrast', params.contrast or 1.2)
    safeSend(shader, 'resolution', params.resolution or {love.graphics.getWidth(), love.graphics.getHeight()})
    safeSend(shader, 'num_colors', math.min(#colors, 4))
    safeSend(shader, 'color1', colors[1] or {0.8, 0.1, 0.3})
    safeSend(shader, 'color2', colors[2] or {0.2, 0.1, 0.6})
    safeSend(shader, 'color3', colors[3] or colors[1])
    safeSend(shader, 'color4', colors[4] or colors[2])

    local pts = params.points
    safeSend(shader, 'point_strength', params.point_strength or 0)
    safeSend(shader, 'point_radius', params.point_radius or 0.008)

    if pts and #pts > 0 then
        local n = math.min(#pts, 16)
        safeSend(shader, 'num_points', n)
        local d = {}
        for i = 1, n do
            local p = pts[i]
            d[i] = {p[1], p[2], p[3] or 0, p[4] or 0}
        end
        safeSend(shader, 'points', unpack(d, 1, n))
    else
        safeSend(shader, 'num_points', 0)
    end
end

-- Unit quad mesh with proper 0-1 UVs so tc works in shaders
local quad_mesh = nil
local function getQuadMesh()
    if not quad_mesh then
        quad_mesh = love.graphics.newMesh({
            {0, 0, 0, 0, 1, 1, 1, 1},
            {1, 0, 1, 0, 1, 1, 1, 1},
            {1, 1, 1, 1, 1, 1, 1, 1},
            {0, 1, 0, 1, 1, 1, 1, 1},
        }, 'fan')
    end
    return quad_mesh
end

function Shaders.drawFlowing(x, y, w, h, params)
    local shader = Shaders.getFlowing()
    if not shader then return end
    params = params or {}
    params.resolution = {w, h}
    Shaders.sendFlowing(shader, params)
    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(getQuadMesh(), x, y, 0, w, h)
    love.graphics.setShader()
end

return Shaders
