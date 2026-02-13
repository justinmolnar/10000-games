local Object = require('class')
local Shaders = require('src.utils.shaders')
local BackgroundRenderer = Object:extend('BackgroundRenderer')

local renderers = {}

function BackgroundRenderer:init(config)
    if not config then error("BackgroundRenderer: config required") end
    if not config.type then error("BackgroundRenderer: type required") end

    self.type = config.type
    self.config = config
    self.points = nil

    local renderer = renderers[self.type]
    if not renderer then error("BackgroundRenderer: unknown type '" .. tostring(self.type) .. "'") end
    renderer.setup(self, config)
end

-- Set interaction points. Each point is {x, y, vx, vy} in 0-1 normalized coords.
-- vx/vy are velocity in UV/second. Call each frame before draw().
function BackgroundRenderer:setPoints(points)
    self.points = points
end

function BackgroundRenderer:update(dt)
    local updater = renderers[self.type] and renderers[self.type].update
    if updater then
        updater(self, dt)
    end
end

function BackgroundRenderer:draw(width, height)
    renderers[self.type].draw(self, width, height)
end

--------------------------------------------------------------------------------
-- solid
--------------------------------------------------------------------------------
renderers.solid = {}

function renderers.solid.setup(self, config)
    self.color = config.color or {0.1, 0.1, 0.15}
end

function renderers.solid.draw(self, width, height)
    love.graphics.setColor(self.color)
    love.graphics.rectangle('fill', 0, 0, width, height)
end

--------------------------------------------------------------------------------
-- starfield
--------------------------------------------------------------------------------
renderers.starfield = {}

function renderers.starfield.setup(self, config)
    self.color = config.color or {0.08, 0.05, 0.1}
    self.star_color = config.star_color or {1, 1, 1}
    self.star_size_divisor = config.star_size_divisor or 60
    local count = config.star_count or 180
    local speed_min = config.star_speed_min or 20
    local speed_max = config.star_speed_max or 100

    self.stars = {}
    for _ = 1, count do
        self.stars[#self.stars + 1] = {
            x = math.random(),
            y = math.random(),
            speed = speed_min + math.random() * (speed_max - speed_min),
        }
    end
end

function renderers.starfield.draw(self, width, height)
    love.graphics.setColor(self.color)
    love.graphics.rectangle('fill', 0, 0, width, height)

    local t = love.timer.getTime()
    love.graphics.setColor(self.star_color)
    for _, star in ipairs(self.stars) do
        local y = (star.y + (star.speed * t) / height) % 1
        local size = math.max(1, star.speed / self.star_size_divisor)
        love.graphics.rectangle('fill', star.x * width, y * height, size, size)
    end
end

--------------------------------------------------------------------------------
-- flowing (domain-warped noise with obstacle displacement)
--------------------------------------------------------------------------------
renderers.flowing = {}

function renderers.flowing.setup(self, config)
    self.colors = config.colors or {{0.6, 0.05, 0.2}, {0.15, 0.05, 0.4}, {0.05, 0.1, 0.3}}
    self.speed = config.speed or 0.4
    self.scale = config.scale or 1.5
    self.warp = config.warp or 1.0
    self.contrast = config.contrast or 1.2
    self.point_strength = config.point_strength or 5.0
    self.point_radius = config.point_radius or 0.008
    self.point_tail = config.point_tail or 5.0
end

function renderers.flowing.draw(self, width, height)
    Shaders.drawFlowing(0, 0, width, height, {
        time     = love.timer.getTime(),
        colors   = self.colors,
        speed    = self.speed,
        scale    = self.scale,
        warp     = self.warp,
        contrast = self.contrast,
        points = self.points,
        point_radius = self.point_radius,
        point_tail = self.point_tail,
        point_strength = self.points and self.point_strength or 0,
    })
end

--------------------------------------------------------------------------------
-- ink_flow (advection-diffusion ink sim over flowing noise)
--
-- Points inject dye + velocity. The flowing noise pattern is displaced
-- by the accumulated velocity field. Dye dissipates over time.
--------------------------------------------------------------------------------

local INK_FLOW_SIM_GLSL = [[
extern vec2 texel_size;
extern float dye_dissipation;
extern float vel_dissipation;
extern float diffusion_rate;
extern float inject_radius;
extern float inject_amount;
extern float vel_strength;
extern vec4 points[32];
extern int num_points;

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    vec4 c  = Texel(tex, tc);
    vec4 cl = Texel(tex, tc - vec2(texel_size.x, 0.0));
    vec4 cr = Texel(tex, tc + vec2(texel_size.x, 0.0));
    vec4 cu = Texel(tex, tc - vec2(0.0, texel_size.y));
    vec4 cd = Texel(tex, tc + vec2(0.0, texel_size.y));

    vec2 vel = c.gb;

    // Semi-Lagrangian advection
    vec2 src = tc - vel;
    vec4 advected = Texel(tex, src);

    // Diffusion
    vec4 avg = (cl + cr + cu + cd) * 0.25;
    vec4 result = mix(advected, avg, diffusion_rate);

    // Dissipation
    result.r *= dye_dissipation;
    result.g *= vel_dissipation;
    result.b *= vel_dissipation;

    // Multi-point injection
    for (int i = 0; i < 32; i++) {
        if (i >= num_points) break;
        vec2 diff = tc - points[i].xy;
        float dist2 = dot(diff, diff);
        float falloff = exp(-dist2 / inject_radius);
        float vel_mag = length(points[i].zw);

        result.r += inject_amount * falloff * min(vel_mag * vel_strength, 1.0);
        result.g += points[i].z * vel_strength * falloff;
        result.b += points[i].w * vel_strength * falloff;
    }

    result.r = clamp(result.r, 0.0, 2.0);

    // Clamp velocity magnitude to prevent runaway advection when trails overlap
    vec2 final_vel = result.gb;
    float vel_len = length(final_vel);
    float max_vel = texel_size.x * 3.0;
    if (vel_len > max_vel) {
        final_vel *= max_vel / vel_len;
    }
    result.g = final_vel.x;
    result.b = final_vel.y;

    return vec4(result.rgb, 1.0);
}
]]

local INK_FLOW_RENDER_GLSL = [[
extern vec3 dye_color;
extern vec2 resolution;
extern float time;
extern float flow_speed;
extern float flow_scale;
extern float flow_warp;
extern float flow_contrast;
extern vec3 color1;
extern vec3 color2;
extern vec3 color3;
extern float displace;

vec2 ihash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)),
             dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float inoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(dot(ihash(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(ihash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(ihash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(ihash(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

float ifbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * inoise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    vec4 data = Texel(tex, tc);
    float dye = clamp(data.r, 0.0, 1.0);
    vec2 vel = data.gb;

    float aspect = resolution.x / resolution.y;
    vec2 uv = tc;
    uv.x *= aspect;

    // Ink velocity displaces the flowing noise
    uv += vel * displace;

    float t = time * flow_speed;

    vec2 q = vec2(ifbm(uv * flow_scale + t * 0.1),
                  ifbm(uv * flow_scale + vec2(5.2, 1.3) + t * 0.12));

    vec2 r = vec2(ifbm(uv * flow_scale + q * flow_warp * 4.0 + vec2(1.7, 9.2) + t * 0.15),
                  ifbm(uv * flow_scale + q * flow_warp * 4.0 + vec2(8.3, 2.8) + t * 0.13));

    float f = ifbm(uv * flow_scale + r * flow_warp * 4.0);

    float blend = clamp((f + 0.6) * 0.5, 0.0, 1.0);
    blend = pow(blend, flow_contrast);

    vec3 water_col;
    float z = blend * 2.0;
    if (z < 1.0) { water_col = mix(color1, color2, z); }
    else          { water_col = mix(color2, color3, z - 1.0); }

    water_col *= 0.85 + 0.15 * (f * f + f);

    vec3 col = mix(water_col, dye_color, dye);

    float vel_mag = length(vel);
    col += vec3(0.08, 0.1, 0.12) * min(vel_mag * 40.0, 0.3);

    return vec4(col, 1.0);
}
]]

local ink_flow_sim_shader = nil
local ink_flow_render_shader = nil

renderers.ink_flow = {}

function renderers.ink_flow.setup(self, config)
    -- Flow params (shared with flowing renderer)
    self.colors = config.colors or {{0.02, 0.15, 0.3}, {0.05, 0.35, 0.45}, {0.1, 0.5, 0.35}}
    self.speed = config.speed or 0.3
    self.scale = config.scale or 1.5
    self.warp = config.warp or 1.0
    self.contrast = config.contrast or 1.2

    -- Ink sim params
    self.ink_dye_dissipation = config.ink_dye_dissipation or 0.997
    self.ink_vel_dissipation = config.ink_vel_dissipation or 0.985
    self.ink_diffusion       = config.ink_diffusion or 0.05
    self.ink_amount          = config.ink_amount or 0.4
    self.ink_radius          = config.ink_radius or 0.0005
    self.ink_vel_strength    = config.ink_vel_strength or 3.3
    self.ink_sim_steps       = config.ink_sim_steps or 1
    self.ink_displace        = config.ink_displace or 15.0
    self.ink_dye_color       = config.ink_dye_color or {0.05, 0.02, 0.09}

    -- Deferred: canvases created on first draw
    self.ink_canvases = nil
    self.ink_sim_idx = 1
    self.ink_sim_w = 0
    self.ink_sim_h = 0
end

function renderers.ink_flow.update(self, dt)
    -- Skip if canvases not yet created (first draw hasn't happened)
    if not self.ink_canvases then return end

    -- Lazy init sim shader
    if not ink_flow_sim_shader then
        local ok, s = pcall(love.graphics.newShader, INK_FLOW_SIM_GLSL)
        if ok then ink_flow_sim_shader = s
        else print("ink_flow sim shader error: " .. tostring(s)) end
    end
    if not ink_flow_sim_shader then return end

    -- Build points array (velocity converted from UV/second to UV/frame)
    local pts = self.points
    local n = 0
    local pt_data = {}
    if pts then
        n = math.min(#pts, 16)
        local frame_dt = dt or (1/60)
        for i = 1, n do
            local p = pts[i]
            pt_data[i] = {p[1], p[2], -(p[3] or 0) * frame_dt, -(p[4] or 0) * frame_dt}
        end
    end

    -- Run sim steps on own canvases (safe: no window canvas active during update phase)
    local steps = math.floor(self.ink_sim_steps + 0.5)
    for step = 1, steps do
        local read = self.ink_canvases[self.ink_sim_idx]
        local write_idx = 3 - self.ink_sim_idx
        local write = self.ink_canvases[write_idx]

        love.graphics.setCanvas(write)
        love.graphics.setShader(ink_flow_sim_shader)

        if ink_flow_sim_shader:hasUniform('texel_size') then
            ink_flow_sim_shader:send('texel_size', {1 / self.ink_sim_w, 1 / self.ink_sim_h})
        end
        if ink_flow_sim_shader:hasUniform('dye_dissipation') then
            ink_flow_sim_shader:send('dye_dissipation', self.ink_dye_dissipation)
        end
        if ink_flow_sim_shader:hasUniform('vel_dissipation') then
            ink_flow_sim_shader:send('vel_dissipation', self.ink_vel_dissipation)
        end
        if ink_flow_sim_shader:hasUniform('diffusion_rate') then
            ink_flow_sim_shader:send('diffusion_rate', self.ink_diffusion)
        end
        if ink_flow_sim_shader:hasUniform('inject_radius') then
            ink_flow_sim_shader:send('inject_radius', self.ink_radius)
        end
        if ink_flow_sim_shader:hasUniform('inject_amount') then
            ink_flow_sim_shader:send('inject_amount', self.ink_amount)
        end
        if ink_flow_sim_shader:hasUniform('vel_strength') then
            ink_flow_sim_shader:send('vel_strength', self.ink_vel_strength)
        end
        if ink_flow_sim_shader:hasUniform('num_points') then
            ink_flow_sim_shader:send('num_points', step == 1 and n or 0)
        end
        if n > 0 and step == 1 and ink_flow_sim_shader:hasUniform('points') then
            ink_flow_sim_shader:send('points', unpack(pt_data, 1, n))
        end

        love.graphics.draw(read, 0, 0)
        love.graphics.setShader()

        self.ink_sim_idx = write_idx
    end

    love.graphics.setCanvas()
end

function renderers.ink_flow.draw(self, width, height)
    -- Lazy init canvases
    local sim_w = math.floor(width / 4)
    local sim_h = math.floor(height / 4)
    if sim_w < 1 then sim_w = 1 end
    if sim_h < 1 then sim_h = 1 end

    if not self.ink_canvases or self.ink_sim_w ~= sim_w or self.ink_sim_h ~= sim_h then
        local function makeCanvas(cw, ch)
            local ok, c = pcall(love.graphics.newCanvas, cw, ch, {format = 'rgba16f'})
            if not ok then c = love.graphics.newCanvas(cw, ch) end
            c:setFilter('linear', 'linear')
            return c
        end
        self.ink_sim_w = sim_w
        self.ink_sim_h = sim_h
        self.ink_canvases = {makeCanvas(sim_w, sim_h), makeCanvas(sim_w, sim_h)}
        self.ink_sim_idx = 1
    end

    -- Lazy init render shader
    if not ink_flow_render_shader then
        local ok, s = pcall(love.graphics.newShader, INK_FLOW_RENDER_GLSL)
        if ok then ink_flow_render_shader = s
        else print("ink_flow render shader error: " .. tostring(s)) end
    end

    -- Render combined flowing + ink (no canvas switching - sim ran during update)
    if ink_flow_render_shader then
        love.graphics.setShader(ink_flow_render_shader)
        if ink_flow_render_shader:hasUniform('time') then
            ink_flow_render_shader:send('time', love.timer.getTime())
        end
        if ink_flow_render_shader:hasUniform('resolution') then
            ink_flow_render_shader:send('resolution', {width, height})
        end
        if ink_flow_render_shader:hasUniform('displace') then
            ink_flow_render_shader:send('displace', self.ink_displace)
        end
        if ink_flow_render_shader:hasUniform('flow_speed') then
            ink_flow_render_shader:send('flow_speed', self.speed)
        end
        if ink_flow_render_shader:hasUniform('flow_scale') then
            ink_flow_render_shader:send('flow_scale', self.scale)
        end
        if ink_flow_render_shader:hasUniform('flow_warp') then
            ink_flow_render_shader:send('flow_warp', self.warp)
        end
        if ink_flow_render_shader:hasUniform('flow_contrast') then
            ink_flow_render_shader:send('flow_contrast', self.contrast)
        end
        if ink_flow_render_shader:hasUniform('dye_color') then
            ink_flow_render_shader:send('dye_color', self.ink_dye_color)
        end
        local c = self.colors
        if ink_flow_render_shader:hasUniform('color1') then
            ink_flow_render_shader:send('color1', c[1] or {0.02, 0.15, 0.3})
        end
        if ink_flow_render_shader:hasUniform('color2') then
            ink_flow_render_shader:send('color2', c[2] or {0.05, 0.35, 0.45})
        end
        if ink_flow_render_shader:hasUniform('color3') then
            ink_flow_render_shader:send('color3', c[3] or c[1] or {0.02, 0.15, 0.3})
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.ink_canvases[self.ink_sim_idx], 0, 0, 0,
            width / self.ink_sim_w, height / self.ink_sim_h)
        love.graphics.setShader()
    end
end

return BackgroundRenderer
