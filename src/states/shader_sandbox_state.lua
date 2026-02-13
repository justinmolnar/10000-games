local Object = require('class')
local Constants = require('src.constants')
local Shaders = require('src.utils.shaders')
local ShaderSandboxState = Object:extend('ShaderSandboxState')

--------------------------------------------------------------------------------
-- Shader GLSL (water ripple sim + render)
--------------------------------------------------------------------------------

local SIM_GLSL = [[
extern vec2 texel_size;
extern float damping;
extern vec2 mouse_pos;
extern float mouse_force;
extern float mouse_radius;

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    float current = Texel(tex, tc).r;
    float previous = Texel(tex, tc).g;

    float l = Texel(tex, tc - vec2(texel_size.x, 0.0)).r;
    float rv = Texel(tex, tc + vec2(texel_size.x, 0.0)).r;
    float u = Texel(tex, tc - vec2(0.0, texel_size.y)).r;
    float d = Texel(tex, tc + vec2(0.0, texel_size.y)).r;

    float next_h = (l + rv + u + d) * 0.5 - previous;
    next_h *= damping;

    if (mouse_force != 0.0) {
        vec2 diff = tc - mouse_pos;
        float dist2 = dot(diff, diff);
        next_h += mouse_force * exp(-dist2 / mouse_radius);
    }

    return vec4(next_h, current, 0.0, 1.0);
}
]]

local RENDER_GLSL = [[
extern vec2 texel_size;
extern vec3 base_color;

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    float h = Texel(tex, tc).r;

    float hl = Texel(tex, tc - vec2(texel_size.x, 0.0)).r;
    float hr = Texel(tex, tc + vec2(texel_size.x, 0.0)).r;
    float hu = Texel(tex, tc - vec2(0.0, texel_size.y)).r;
    float hd = Texel(tex, tc + vec2(0.0, texel_size.y)).r;

    vec3 normal = normalize(vec3((hl - hr) * 8.0, (hu - hd) * 8.0, 1.0));

    vec3 light_dir = normalize(vec3(-0.3, -0.5, 1.0));
    float diffuse = max(dot(normal, light_dir), 0.0);

    vec3 reflect_dir = reflect(-light_dir, normal);
    float spec = pow(max(reflect_dir.z, 0.0), 32.0);

    vec3 col = base_color * (0.7 + 0.3 * diffuse) + vec3(1.0) * spec * 0.3;

    return vec4(col, 1.0);
}
]]

local sim_shader = nil
local render_shader = nil

--------------------------------------------------------------------------------
-- Shader GLSL (ink diffusion sim + render)
--------------------------------------------------------------------------------

local INK_SIM_GLSL = [[
extern vec2 texel_size;
extern float dye_dissipation;
extern float vel_dissipation;
extern float diffusion_rate;
extern vec2 mouse_pos;
extern vec2 mouse_vel;
extern float mouse_active;
extern float inject_radius;
extern float inject_amount;

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    vec4 c  = Texel(tex, tc);
    vec4 cl = Texel(tex, tc - vec2(texel_size.x, 0.0));
    vec4 cr = Texel(tex, tc + vec2(texel_size.x, 0.0));
    vec4 cu = Texel(tex, tc - vec2(0.0, texel_size.y));
    vec4 cd = Texel(tex, tc + vec2(0.0, texel_size.y));

    vec2 vel = c.gb;

    // Semi-Lagrangian advection: trace backwards along velocity
    vec2 src = tc - vel;
    vec4 advected = Texel(tex, src);

    // Diffusion: blend toward neighbor average
    vec4 avg = (cl + cr + cu + cd) * 0.25;
    vec4 result = mix(advected, avg, diffusion_rate);

    // Dissipation
    result.r *= dye_dissipation;
    result.g *= vel_dissipation;
    result.b *= vel_dissipation;

    // Mouse injection
    if (mouse_active > 0.5) {
        vec2 diff = tc - mouse_pos;
        float dist2 = dot(diff, diff);
        float falloff = exp(-dist2 / inject_radius);

        result.r += inject_amount * falloff;
        result.g += mouse_vel.x * falloff;
        result.b += mouse_vel.y * falloff;
    }

    result.r = clamp(result.r, 0.0, 2.0);

    return vec4(result.rgb, 1.0);
}
]]

local INK_RENDER_GLSL = [[
extern vec3 water_color;
extern vec3 dye_color;

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    vec4 data = Texel(tex, tc);
    float dye = clamp(data.r, 0.0, 1.0);
    vec2 vel = data.gb;

    vec3 col = mix(water_color, dye_color, dye);

    // Velocity shimmer — shows flow direction
    float vel_mag = length(vel);
    col += vec3(0.1, 0.12, 0.15) * min(vel_mag * 50.0, 0.4);

    return vec4(col, 1.0);
}
]]

local ink_sim_shader = nil
local ink_render_shader = nil

--------------------------------------------------------------------------------
-- Shader GLSL (ink in flowing water — combined render)
--------------------------------------------------------------------------------

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

    // Flowing noise as the "water" background
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

    // Mix flowing water and ink
    vec3 col = mix(water_col, dye_color, dye);

    // Velocity shimmer
    float vel_mag = length(vel);
    col += vec3(0.08, 0.1, 0.12) * min(vel_mag * 40.0, 0.3);

    return vec4(col, 1.0);
}
]]

local ink_flow_render_shader = nil

--------------------------------------------------------------------------------
-- Shader GLSL (Mystify screensaver)
--------------------------------------------------------------------------------

local MYSTIFY_GLSL = [[
extern float time;
extern float speed;
extern int num_trails;
extern float trail_spacing;
extern float line_glow;
extern int num_shapes;
extern vec3 color1;
extern vec3 color2;
extern vec2 resolution;

float hash11(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

float bounce(float start, float vel, float t) {
    float raw = start + vel * t;
    return abs(mod(raw + 1.0, 2.0) - 1.0);
}

float sdSeg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

vec2 vtx(int shape, int v, float t) {
    float seed = float(shape * 4 + v);
    return vec2(
        bounce(hash11(seed * 1.17 + 0.1), hash11(seed * 2.31 + 0.3) * 0.3 + 0.1, t),
        bounce(hash11(seed * 3.71 + 0.5), hash11(seed * 4.93 + 0.7) * 0.3 + 0.1, t)
    );
}

float shapeDist(vec2 uv, float aspect, int shape, float t) {
    vec2 v0 = vtx(shape, 0, t); v0.x *= aspect;
    vec2 v1 = vtx(shape, 1, t); v1.x *= aspect;
    vec2 v2 = vtx(shape, 2, t); v2.x *= aspect;
    vec2 v3 = vtx(shape, 3, t); v3.x *= aspect;

    float d = sdSeg(uv, v0, v1);
    d = min(d, sdSeg(uv, v1, v2));
    d = min(d, sdSeg(uv, v2, v3));
    d = min(d, sdSeg(uv, v3, v0));
    return d;
}

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    float aspect = resolution.x / resolution.y;
    vec2 uv = vec2(tc.x * aspect, tc.y);

    vec3 col = vec3(0.0);
    float t = time * speed;

    for (int i = 0; i < 16; i++) {
        if (i >= num_trails) break;
        float tt = t - float(i) * trail_spacing;
        float alpha = 1.0 - float(i) / float(num_trails);
        alpha *= alpha;

        float d1 = shapeDist(uv, aspect, 0, tt);
        col += color1 * smoothstep(line_glow, 0.0, d1) * alpha;

        if (num_shapes >= 2) {
            float d2 = shapeDist(uv, aspect, 1, tt);
            col += color2 * smoothstep(line_glow, 0.0, d2) * alpha;
        }
    }

    return vec4(col, 1.0);
}
]]

local mystify_shader = nil

--------------------------------------------------------------------------------
-- Shader GLSL (Bezier curves screensaver)
--------------------------------------------------------------------------------

local BEZIER_GLSL = [[
extern float time;
extern float speed;
extern int num_trails;
extern float trail_spacing;
extern float line_glow;
extern int num_curves;
extern vec3 color1;
extern vec3 color2;
extern vec2 resolution;

float hash11(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

float bounce(float start, float vel, float t) {
    float raw = start + vel * t;
    return abs(mod(raw + 1.0, 2.0) - 1.0);
}

vec2 ctrlPt(int curve, int pt, float t) {
    float seed = float(curve * 4 + pt);
    return vec2(
        bounce(hash11(seed + 0.37), hash11(seed + 8.73) * 0.3 + 0.1, t),
        bounce(hash11(seed + 16.19), hash11(seed + 24.61) * 0.3 + 0.1, t)
    );
}

vec2 cubicBez(vec2 a, vec2 b, vec2 c, vec2 d, float u) {
    float mu = 1.0 - u;
    return mu*mu*mu*a + 3.0*mu*mu*u*b + 3.0*mu*u*u*c + u*u*u*d;
}

float sdSeg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float curveDist(vec2 uv, float aspect, int curve, float t) {
    vec2 p0 = ctrlPt(curve, 0, t); p0.x *= aspect;
    vec2 p1 = ctrlPt(curve, 1, t); p1.x *= aspect;
    vec2 p2 = ctrlPt(curve, 2, t); p2.x *= aspect;
    vec2 p3 = ctrlPt(curve, 3, t); p3.x *= aspect;

    float minD = 1e10;
    vec2 prev = p0;
    for (int i = 1; i <= 24; i++) {
        float u = float(i) / 24.0;
        vec2 curr = cubicBez(p0, p1, p2, p3, u);
        minD = min(minD, sdSeg(uv, prev, curr));
        prev = curr;
    }
    return minD;
}

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    float aspect = resolution.x / resolution.y;
    vec2 uv = vec2(tc.x * aspect, tc.y);

    vec3 col = vec3(0.0);
    float t = time * speed;

    for (int i = 0; i < 16; i++) {
        if (i >= num_trails) break;
        float tt = t - float(i) * trail_spacing;
        float alpha = 1.0 - float(i) / float(num_trails);
        alpha *= alpha;

        float d1 = curveDist(uv, aspect, 0, tt);
        col += color1 * smoothstep(line_glow, 0.0, d1) * alpha;

        if (num_curves >= 2) {
            float d2 = curveDist(uv, aspect, 1, tt);
            col += color2 * smoothstep(line_glow, 0.0, d2) * alpha;
        }
    }

    return vec4(col, 1.0);
}
]]

local bezier_shader = nil

--------------------------------------------------------------------------------
-- Shader GLSL (Matrix rain)
--------------------------------------------------------------------------------

local MATRIX_GLSL = [[
extern float time;
extern float speed;
extern float density;
extern float char_size;
extern vec3 fg_color;
extern float tail_len;
extern float num_drops;
extern float flicker;
extern vec2 resolution;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float charGlyph(vec2 uv, float id) {
    vec2 g = floor(uv * vec2(3.0, 5.0));
    if (g.x < 0.0 || g.x >= 3.0 || g.y < 0.0 || g.y >= 5.0) return 0.0;
    float idx = g.y * 3.0 + g.x;
    float seed = id * 127.37 + idx * 0.73;
    return step(0.35, fract(sin(seed) * 43758.5453));
}

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    float cell_h = char_size;
    float cell_w = cell_h * 0.6;
    vec2 cell = vec2(cell_w, cell_h);
    vec2 grid_pos = floor(tc / cell);
    vec2 cell_uv = fract(tc / cell);

    float col_id = grid_pos.x;
    float row_id = grid_pos.y;
    float total_rows = floor(1.0 / cell_h);

    float col_active = step(1.0 - density, hash21(vec2(col_id, 2.0)));

    // Multiple independent drops per column
    float brightness = 0.0;
    float head_prox = 0.0;
    int drops = int(num_drops + 0.5);

    for (int i = 0; i < 8; i++) {
        if (i >= drops) break;
        float fi = float(i);

        // Each drop: own speed and phase
        float drop_speed = (0.3 + hash21(vec2(col_id, fi * 7.0 + 3.0)) * 0.7) * speed;
        float drop_phase = hash21(vec2(col_id, fi * 7.0 + 17.0));

        // Cycle: rain traversal + tail fade + gap
        float cycle = total_rows * 2.5 + tail_len;
        float head = mod(drop_phase * cycle + time * drop_speed / cell_h, cycle);

        float dist = head - row_id;

        if (dist > 0.0 && dist < tail_len) {
            float t = dist / tail_len;
            brightness += (1.0 - t) * (1.0 - t);
        }

        // Head glow tracking
        if (dist >= -0.5 && dist < 2.0) {
            head_prox = max(head_prox, smoothstep(2.0, 0.0, dist));
        }
    }

    brightness = min(brightness, 1.5) * col_active;

    // Character rendering
    float change_rate = mix(2.0, 12.0, flicker);
    float char_time = floor(time * change_rate + hash21(vec2(col_id, row_id)) * 100.0);
    float char_id = hash21(vec2(col_id * 17.3 + row_id * 31.7, char_time));
    float stable_id = hash21(vec2(col_id * 17.3 + row_id * 31.7, 0.0));
    char_id = mix(stable_id, char_id, head_prox);

    vec2 char_uv = (cell_uv - 0.1) / 0.8;
    float in_cell = step(0.0, char_uv.x) * step(char_uv.x, 1.0) * step(0.0, char_uv.y) * step(char_uv.y, 1.0);
    float pattern = charGlyph(char_uv, char_id) * in_cell;

    vec3 col = fg_color * pattern * brightness;
    col += vec3(0.6, 1.0, 0.6) * pattern * head_prox * head_prox * col_active * 0.6;

    return vec4(col, 1.0);
}
]]

local matrix_shader = nil

--------------------------------------------------------------------------------
-- Shader GLSL (Bouncing warp)
--------------------------------------------------------------------------------

local WARP_GLSL = [[
extern float time;
extern float speed;
extern float warp_radius;
extern float warp_strength;
extern float warp_type;
extern vec3 ball_color;
extern vec3 bg_color1;
extern vec3 bg_color2;
extern float grid_scale;
extern int num_balls;
extern float use_screen;
extern vec2 resolution;

float bounce(float start, float vel, float t) {
    float raw = start + vel * t;
    return abs(mod(raw + 1.0, 2.0) - 1.0);
}

float hash11(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

vec2 ballPos(int idx, float t) {
    float s = float(idx);
    return vec2(
        bounce(hash11(s * 1.3 + 0.1), hash11(s * 2.7 + 0.3) * 0.2 + 0.12, t),
        bounce(hash11(s * 3.1 + 0.5), hash11(s * 4.9 + 0.7) * 0.2 + 0.12, t)
    );
}

vec2 applyWarp(vec2 uv, vec2 center, float dist, float norm_dist, float aspect, int wt, float strength) {
    float factor = 1.0 - norm_dist;
    if (wt == 0) {
        // Lens
        float power = 1.0 - strength * factor * factor;
        return center + (uv - center) * power;
    } else if (wt == 1) {
        // Twist
        float angle = strength * factor * factor * 6.28;
        float c = cos(angle);
        float s = sin(angle);
        vec2 d = uv - center;
        return center + vec2(d.x * c - d.y * s, d.x * s + d.y * c);
    } else {
        // Pinch
        vec2 dir = (uv - center) / (dist + 0.0001);
        float push = dist * (1.0 + strength * factor * factor);
        return center + dir * push;
    }
}

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    float aspect = resolution.x / resolution.y;
    float t = time * speed;
    int wt = int(warp_type + 0.5);

    vec2 warped_uv = tc;

    for (int b = 0; b < 4; b++) {
        if (b >= num_balls) break;
        vec2 center = ballPos(b, t);
        vec2 diff = tc - center;
        diff.x *= aspect;
        float dist = length(diff);

        if (dist < warp_radius) {
            float norm_dist = dist / warp_radius;
            warped_uv = applyWarp(warped_uv, center, dist, norm_dist, aspect, wt, warp_strength);
        }
    }

    // Background: screen capture or checkerboard
    vec3 bg;
    if (use_screen > 0.5) {
        bg = Texel(tex, warped_uv).rgb;
    } else {
        vec2 grid = warped_uv * grid_scale;
        grid.x *= aspect;
        float checker = mod(floor(grid.x) + floor(grid.y), 2.0);
        bg = mix(bg_color1, bg_color2, checker);
    }

    // Ball glow overlay
    vec3 col = bg;
    for (int b = 0; b < 4; b++) {
        if (b >= num_balls) break;
        vec2 center = ballPos(b, t);
        vec2 diff = tc - center;
        diff.x *= aspect;
        float dist = length(diff);

        float edge = smoothstep(warp_radius, warp_radius * 0.8, dist);
        col = mix(col, ball_color, edge * 0.2);
        float core = smoothstep(warp_radius * 0.25, 0.0, dist);
        col += ball_color * core * 0.4;
    }

    return vec4(col, 1.0);
}
]]

local warp_shader = nil

--------------------------------------------------------------------------------
-- Shader GLSL (3D Text screensaver)
--------------------------------------------------------------------------------

local TEXT3D_GLSL = [[
extern float thickness;
extern float extrude;
extern float specular;
extern float surface;
extern float text_size;
extern vec3 color1;
extern vec3 color2;
extern vec2 resolution;
extern float tx, ty;
extern float cos_rx, sin_rx, cos_ry, sin_ry, cos_rz, sin_rz;

float ls(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

float textSDF(vec2 p) {
    float d = 1e10;
    vec2 o;

    // W
    o = vec2(-1.8, 0);
    d=min(d,ls(p-o,vec2(-.35,.45),vec2(-.18,-.45)));
    d=min(d,ls(p-o,vec2(-.18,-.45),vec2(0,.15)));
    d=min(d,ls(p-o,vec2(0,.15),vec2(.18,-.45)));
    d=min(d,ls(p-o,vec2(.18,-.45),vec2(.35,.45)));

    // A
    o = vec2(-0.9, 0);
    d=min(d,ls(p-o,vec2(-.3,-.45),vec2(0,.45)));
    d=min(d,ls(p-o,vec2(0,.45),vec2(.3,-.45)));
    d=min(d,ls(p-o,vec2(-.15,0),vec2(.15,0)));

    // R
    o = vec2(0, 0);
    d=min(d,ls(p-o,vec2(-.3,-.45),vec2(-.3,.45)));
    d=min(d,ls(p-o,vec2(-.3,.45),vec2(.25,.45)));
    d=min(d,ls(p-o,vec2(.25,.45),vec2(.25,.05)));
    d=min(d,ls(p-o,vec2(.25,.05),vec2(-.3,.05)));
    d=min(d,ls(p-o,vec2(-.1,.05),vec2(.3,-.45)));

    // E
    o = vec2(0.9, 0);
    d=min(d,ls(p-o,vec2(-.3,-.45),vec2(-.3,.45)));
    d=min(d,ls(p-o,vec2(-.3,.45),vec2(.3,.45)));
    d=min(d,ls(p-o,vec2(-.3,0),vec2(.2,0)));
    d=min(d,ls(p-o,vec2(-.3,-.45),vec2(.3,-.45)));

    // Z
    o = vec2(1.8, 0);
    d=min(d,ls(p-o,vec2(-.3,.45),vec2(.3,.45)));
    d=min(d,ls(p-o,vec2(.3,.45),vec2(-.3,-.45)));
    d=min(d,ls(p-o,vec2(-.3,-.45),vec2(.3,-.45)));

    return d;
}

float map(vec3 p) {
    // Rotate Z -> Y -> X (precomputed trig from CPU)
    vec3 q = vec3(p.x*cos_rz - p.y*sin_rz, p.x*sin_rz + p.y*cos_rz, p.z);
    q = vec3(q.x*cos_ry + q.z*sin_ry, q.y, -q.x*sin_ry + q.z*cos_ry);
    q = vec3(q.x, q.y*cos_rx - q.z*sin_rx, q.y*sin_rx + q.z*cos_rx);

    float d2d = textSDF(q.xy) - thickness;
    float dz = abs(q.z) - extrude;
    vec2 w = vec2(d2d, dz);
    return min(max(w.x, w.y), 0.0) + length(max(w, 0.0));
}

vec3 calcNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p+e.xyy) - map(p-e.xyy),
        map(p+e.yxy) - map(p-e.yxy),
        map(p+e.yyx) - map(p-e.yyx)
    ));
}

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    float aspect = resolution.x / resolution.y;
    vec2 uv = tc * 2.0 - 1.0;
    uv.x *= aspect;

    // Translate in screen space (shift the view, not the geometry)
    uv.x -= tx;
    uv.y -= ty;

    vec3 ro = vec3(0.0, 0.0, 5.5 / text_size);
    vec3 rd = normalize(vec3(uv, -1.5));

    float t = 0.0;
    float hit = 0.0;
    for (int i = 0; i < 80; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        if (d < 0.002) { hit = 1.0; break; }
        if (t > 15.0) break;
        t += d;
    }

    vec3 col = vec3(0.0);

    if (hit > 0.5) {
        vec3 p = ro + rd * t;
        vec3 n = calcNormal(p);

        vec3 light = normalize(vec3(1.0, 1.0, 0.8));
        float diff = max(dot(n, light), 0.0);
        float spec = pow(max(dot(reflect(-light, n), -rd), 0.0), 32.0);

        if (surface < 0.5) {
            // Solid color
            col = color1 * (0.3 + 0.7 * diff) + vec3(1.0) * spec * specular;
        } else {
            // Chrome reflection
            vec3 ref = reflect(rd, n);
            float env = 0.5 + 0.5 * ref.y;
            vec3 base = mix(color1, color2, env);
            col = base * (0.2 + 0.8 * diff) + vec3(1.0) * spec * specular;
        }
    }

    return vec4(col, 1.0);
}
]]

local text3d_shader = nil

--------------------------------------------------------------------------------
-- Shader GLSL (Demoscene plasma)
--------------------------------------------------------------------------------

local PLASMA_GLSL = [[
extern float time;
extern float palette_speed;
extern float scale;
extern float layers;
extern vec3 color1;
extern vec3 color2;
extern vec3 color3;
extern vec2 resolution;

vec4 effect(vec4 vcolor, Image tex, vec2 tc, vec2 sc) {
    float aspect = resolution.x / resolution.y;
    vec2 uv = tc;
    uv.x *= aspect;

    // Static layered sine pattern
    float v = 0.0;
    v += sin(uv.x * scale);
    v += sin(uv.y * scale * 1.3);
    v += sin((uv.x + uv.y) * scale * 0.7);

    // Circular component
    float cx = uv.x - aspect * 0.5;
    float cy = uv.y - 0.5;
    v += sin(sqrt(cx * cx + cy * cy) * scale * 1.5);

    if (layers > 4.5) {
        v += sin(uv.x * scale * 2.1 + uv.y * scale * 0.9) * 0.5;
        v += sin((uv.x - uv.y) * scale * 1.1) * 0.5;
    }

    // Normalize to 0-1
    float norm = (layers > 4.5) ? 0.2 : 0.25;
    v = v * norm + 0.5;

    // Palette cycling: pattern is static, colors shift
    v = fract(v + time * palette_speed);

    // 3-stop palette
    vec3 col;
    float z = v * 3.0;
    if (z < 1.0)      col = mix(color1, color2, z);
    else if (z < 2.0) col = mix(color2, color3, z - 1.0);
    else               col = mix(color3, color1, z - 2.0);

    return vec4(col, 1.0);
}
]]

local plasma_shader = nil

--------------------------------------------------------------------------------
-- Program definitions
--------------------------------------------------------------------------------

local function buildPrograms()
    local programs = {}

    -- 1. Water Ripples
    programs[#programs + 1] = {
        name = "Water Ripples",
        params = {
            {key = "damping",      label = "Damping",   min = 0.9,  max = 1.0,  default = 0.995, step = 0.001},
            {key = "force_scale",  label = "Force",     min = 0.5,  max = 5.0,  default = 3.0,   step = 0.1},
            {key = "mouse_radius", label = "Radius",    min = 0.0002, max = 0.01, default = 0.001, step = 0.0002},
            {key = "sim_steps",    label = "Sim Steps", min = 1,    max = 8,    default = 4,     step = 1},
            {key = "base_r",       label = "Red",       min = 0.0,  max = 1.0,  default = 0.08,  step = 0.01},
            {key = "base_g",       label = "Green",     min = 0.0,  max = 1.0,  default = 0.08,  step = 0.01},
            {key = "base_b",       label = "Blue",      min = 0.0,  max = 1.0,  default = 0.12,  step = 0.01},
        },
        values = {},
        data = {},

        init = function(prog, w, h)
            local sim_w = math.floor(w / 4)
            local sim_h = math.floor(h / 4)

            local function makeCanvas(cw, ch)
                local ok, c = pcall(love.graphics.newCanvas, cw, ch, {format = 'rgba16f'})
                if not ok then c = love.graphics.newCanvas(cw, ch) end
                c:setFilter('linear', 'linear')
                return c
            end

            prog.data.sim_w = sim_w
            prog.data.sim_h = sim_h
            prog.data.canvases = {makeCanvas(sim_w, sim_h), makeCanvas(sim_w, sim_h)}
            prog.data.sim_idx = 1

            for i = 1, 2 do
                love.graphics.setCanvas(prog.data.canvases[i])
                love.graphics.clear(0, 0, 0, 1)
                love.graphics.setCanvas()
            end

            if not sim_shader then
                local ok, s = pcall(love.graphics.newShader, SIM_GLSL)
                if ok then sim_shader = s
                else print("Water sim shader error: " .. tostring(s)) end
            end
            if not render_shader then
                local ok, s = pcall(love.graphics.newShader, RENDER_GLSL)
                if ok then render_shader = s
                else print("Water render shader error: " .. tostring(s)) end
            end
        end,

        update = function(prog, dt, mouse)
            if not sim_shader then return end
            local d = prog.data
            local v = prog.values

            local force = mouse.speed > 1 and math.min(mouse.speed * 0.001 * v.force_scale, 0.15) or 0
            local steps = math.floor(v.sim_steps + 0.5)

            for step = 1, steps do
                local read = d.canvases[d.sim_idx]
                local write_idx = 3 - d.sim_idx
                local write = d.canvases[write_idx]

                love.graphics.setCanvas(write)
                love.graphics.setShader(sim_shader)

                if sim_shader:hasUniform('texel_size') then
                    sim_shader:send('texel_size', {1 / d.sim_w, 1 / d.sim_h})
                end
                if sim_shader:hasUniform('damping') then
                    sim_shader:send('damping', v.damping)
                end
                if sim_shader:hasUniform('mouse_pos') then
                    sim_shader:send('mouse_pos', {mouse.uv_x, mouse.uv_y})
                end
                if sim_shader:hasUniform('mouse_force') then
                    sim_shader:send('mouse_force', step == 1 and force or 0)
                end
                if sim_shader:hasUniform('mouse_radius') then
                    sim_shader:send('mouse_radius', v.mouse_radius)
                end

                love.graphics.draw(read, 0, 0)
                love.graphics.setShader()
                love.graphics.setCanvas()

                d.sim_idx = write_idx
            end
        end,

        draw = function(prog, w, h)
            local d = prog.data
            local v = prog.values
            if render_shader then
                love.graphics.setShader(render_shader)
                if render_shader:hasUniform('texel_size') then
                    render_shader:send('texel_size', {1 / d.sim_w, 1 / d.sim_h})
                end
                if render_shader:hasUniform('base_color') then
                    render_shader:send('base_color', {v.base_r, v.base_g, v.base_b})
                end
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(d.canvases[d.sim_idx], 0, 0, 0, w / d.sim_w, h / d.sim_h)
                love.graphics.setShader()
            else
                love.graphics.setColor(v.base_r, v.base_g, v.base_b)
                love.graphics.rectangle('fill', 0, 0, w, h)
            end
        end,
    }

    -- 2. Flowing Noise
    programs[#programs + 1] = {
        name = "Flowing Noise",
        params = {
            {key = "speed",          label = "Speed",      min = 0.05, max = 3.0,  default = 0.4,  step = 0.05},
            {key = "scale",          label = "Scale",      min = 0.2,  max = 10.0, default = 1.5,  step = 0.1},
            {key = "warp",           label = "Warp",       min = 0.0,  max = 3.0,  default = 1.0,  step = 0.05},
            {key = "contrast",       label = "Contrast",   min = 0.2,  max = 3.0,  default = 1.2,  step = 0.05},
            {key = "point_strength", label = "Pt Strength", min = 0.0, max = 5.0,  default = 1.5,  step = 0.1},
            {key = "point_radius",   label = "Pt Radius",  min = 0.001, max = 0.1, default = 0.008, step = 0.001},
            {key = "color1_r",       label = "Col1 R",     min = 0.0,  max = 1.0,  default = 0.8,  step = 0.01},
            {key = "color1_g",       label = "Col1 G",     min = 0.0,  max = 1.0,  default = 0.1,  step = 0.01},
            {key = "color1_b",       label = "Col1 B",     min = 0.0,  max = 1.0,  default = 0.3,  step = 0.01},
            {key = "color2_r",       label = "Col2 R",     min = 0.0,  max = 1.0,  default = 0.2,  step = 0.01},
            {key = "color2_g",       label = "Col2 G",     min = 0.0,  max = 1.0,  default = 0.1,  step = 0.01},
            {key = "color2_b",       label = "Col2 B",     min = 0.0,  max = 1.0,  default = 0.6,  step = 0.01},
            {key = "color3_r",       label = "Col3 R",     min = 0.0,  max = 1.0,  default = 0.1,  step = 0.01},
            {key = "color3_g",       label = "Col3 G",     min = 0.0,  max = 1.0,  default = 0.6,  step = 0.01},
            {key = "color3_b",       label = "Col3 B",     min = 0.0,  max = 1.0,  default = 0.3,  step = 0.01},
        },
        values = {},
        data = {},

        init = function(prog, w, h)
            prog.data.mouse_point = {0.5, 0.5, 0, 0}
        end,

        update = function(prog, dt, mouse)
            local w = love.graphics.getWidth()
            local h = love.graphics.getHeight()
            prog.data.mouse_point = {mouse.uv_x, mouse.uv_y, mouse.dx / w, mouse.dy / h}
        end,

        draw = function(prog, w, h)
            local v = prog.values
            local params = {
                speed = v.speed,
                scale = v.scale,
                warp = v.warp,
                contrast = v.contrast,
                point_strength = v.point_strength,
                point_radius = v.point_radius,
                colors = {
                    {v.color1_r, v.color1_g, v.color1_b},
                    {v.color2_r, v.color2_g, v.color2_b},
                    {v.color3_r, v.color3_g, v.color3_b},
                },
                points = {prog.data.mouse_point},
            }
            Shaders.drawFlowing(0, 0, w, h, params)
        end,
    }

    -- 3. Ink Diffusion
    programs[#programs + 1] = {
        name = "Ink Diffusion",
        params = {
            {key = "dye_dissipation", label = "Dye Fade",    min = 0.95, max = 1.0,   default = 0.997, step = 0.001},
            {key = "vel_dissipation", label = "Vel Fade",    min = 0.9,  max = 1.0,   default = 0.98,  step = 0.005},
            {key = "diffusion_rate",  label = "Diffusion",   min = 0.0,  max = 0.3,   default = 0.05,  step = 0.01},
            {key = "inject_amount",   label = "Ink Amount",  min = 0.05, max = 2.0,   default = 0.6,   step = 0.05},
            {key = "inject_radius",   label = "Ink Radius",  min = 0.0005, max = 0.02, default = 0.003, step = 0.0005},
            {key = "vel_strength",    label = "Vel Push",    min = 0.1,  max = 5.0,   default = 1.0,   step = 0.1},
            {key = "sim_steps",       label = "Sim Steps",   min = 1,    max = 6,     default = 3,     step = 1},
            {key = "dye_r",           label = "Ink R",       min = 0.0,  max = 1.0,   default = 0.1,   step = 0.01},
            {key = "dye_g",           label = "Ink G",       min = 0.0,  max = 1.0,   default = 0.04,  step = 0.01},
            {key = "dye_b",           label = "Ink B",       min = 0.0,  max = 1.0,   default = 0.25,  step = 0.01},
            {key = "water_r",         label = "Water R",     min = 0.0,  max = 1.0,   default = 0.9,   step = 0.01},
            {key = "water_g",         label = "Water G",     min = 0.0,  max = 1.0,   default = 0.93,  step = 0.01},
            {key = "water_b",         label = "Water B",     min = 0.0,  max = 1.0,   default = 0.97,  step = 0.01},
        },
        values = {},
        data = {},

        init = function(prog, w, h)
            local sim_w = math.floor(w / 4)
            local sim_h = math.floor(h / 4)

            local function makeCanvas(cw, ch)
                local ok, c = pcall(love.graphics.newCanvas, cw, ch, {format = 'rgba16f'})
                if not ok then c = love.graphics.newCanvas(cw, ch) end
                c:setFilter('linear', 'linear')
                return c
            end

            prog.data.sim_w = sim_w
            prog.data.sim_h = sim_h
            prog.data.canvases = {makeCanvas(sim_w, sim_h), makeCanvas(sim_w, sim_h)}
            prog.data.sim_idx = 1

            for i = 1, 2 do
                love.graphics.setCanvas(prog.data.canvases[i])
                love.graphics.clear(0, 0, 0, 1)
                love.graphics.setCanvas()
            end

            if not ink_sim_shader then
                local ok, s = pcall(love.graphics.newShader, INK_SIM_GLSL)
                if ok then ink_sim_shader = s
                else print("Ink sim shader error: " .. tostring(s)) end
            end
            if not ink_render_shader then
                local ok, s = pcall(love.graphics.newShader, INK_RENDER_GLSL)
                if ok then ink_render_shader = s
                else print("Ink render shader error: " .. tostring(s)) end
            end
        end,

        update = function(prog, dt, mouse)
            if not ink_sim_shader then return end
            local d = prog.data
            local v = prog.values

            local w = love.graphics.getWidth()
            local h = love.graphics.getHeight()
            local vel_x = (mouse.dx / w) * v.vel_strength
            local vel_y = (mouse.dy / h) * v.vel_strength
            local active = mouse.speed > 1 and 1.0 or 0.0

            local steps = math.floor(v.sim_steps + 0.5)

            for step = 1, steps do
                local read = d.canvases[d.sim_idx]
                local write_idx = 3 - d.sim_idx
                local write = d.canvases[write_idx]

                love.graphics.setCanvas(write)
                love.graphics.setShader(ink_sim_shader)

                if ink_sim_shader:hasUniform('texel_size') then
                    ink_sim_shader:send('texel_size', {1 / d.sim_w, 1 / d.sim_h})
                end
                if ink_sim_shader:hasUniform('dye_dissipation') then
                    ink_sim_shader:send('dye_dissipation', v.dye_dissipation)
                end
                if ink_sim_shader:hasUniform('vel_dissipation') then
                    ink_sim_shader:send('vel_dissipation', v.vel_dissipation)
                end
                if ink_sim_shader:hasUniform('diffusion_rate') then
                    ink_sim_shader:send('diffusion_rate', v.diffusion_rate)
                end
                if ink_sim_shader:hasUniform('mouse_pos') then
                    ink_sim_shader:send('mouse_pos', {mouse.uv_x, mouse.uv_y})
                end
                if ink_sim_shader:hasUniform('mouse_vel') then
                    ink_sim_shader:send('mouse_vel', {vel_x, vel_y})
                end
                if ink_sim_shader:hasUniform('mouse_active') then
                    ink_sim_shader:send('mouse_active', step == 1 and active or 0)
                end
                if ink_sim_shader:hasUniform('inject_radius') then
                    ink_sim_shader:send('inject_radius', v.inject_radius)
                end
                if ink_sim_shader:hasUniform('inject_amount') then
                    ink_sim_shader:send('inject_amount', v.inject_amount)
                end

                love.graphics.draw(read, 0, 0)
                love.graphics.setShader()
                love.graphics.setCanvas()

                d.sim_idx = write_idx
            end
        end,

        draw = function(prog, w, h)
            local d = prog.data
            local v = prog.values
            if ink_render_shader then
                love.graphics.setShader(ink_render_shader)
                if ink_render_shader:hasUniform('water_color') then
                    ink_render_shader:send('water_color', {v.water_r, v.water_g, v.water_b})
                end
                if ink_render_shader:hasUniform('dye_color') then
                    ink_render_shader:send('dye_color', {v.dye_r, v.dye_g, v.dye_b})
                end
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(d.canvases[d.sim_idx], 0, 0, 0, w / d.sim_w, h / d.sim_h)
                love.graphics.setShader()
            end
        end,
    }

    -- 4. Ink in Flow
    programs[#programs + 1] = {
        name = "Ink in Flow",
        params = {
            -- Ink sim
            {key = "dye_dissipation", label = "Dye Fade",    min = 0.95, max = 1.0,   default = 0.997, step = 0.001},
            {key = "vel_dissipation", label = "Vel Fade",    min = 0.9,  max = 1.0,   default = 0.98,  step = 0.005},
            {key = "diffusion_rate",  label = "Diffusion",   min = 0.0,  max = 0.3,   default = 0.05,  step = 0.01},
            {key = "inject_amount",   label = "Ink Amount",  min = 0.05, max = 2.0,   default = 0.6,   step = 0.05},
            {key = "inject_radius",   label = "Ink Radius",  min = 0.0005, max = 0.02, default = 0.003, step = 0.0005},
            {key = "vel_strength",    label = "Vel Push",    min = 0.1,  max = 5.0,   default = 1.0,   step = 0.1},
            {key = "sim_steps",       label = "Sim Steps",   min = 1,    max = 6,     default = 3,     step = 1},
            -- Displacement
            {key = "displace",        label = "Displace",    min = 0.0,  max = 40.0,  default = 15.0,  step = 1.0},
            -- Flowing background
            {key = "flow_speed",      label = "Flow Spd",    min = 0.05, max = 2.0,   default = 0.3,   step = 0.05},
            {key = "flow_scale",      label = "Flow Scale",  min = 0.2,  max = 8.0,   default = 1.5,   step = 0.1},
            {key = "flow_warp",       label = "Flow Warp",   min = 0.0,  max = 3.0,   default = 1.0,   step = 0.05},
            {key = "flow_contrast",   label = "Flow Ctrst",  min = 0.2,  max = 3.0,   default = 1.2,   step = 0.05},
            -- Colors
            {key = "dye_r",           label = "Ink R",       min = 0.0,  max = 1.0,   default = 0.05,  step = 0.01},
            {key = "dye_g",           label = "Ink G",       min = 0.0,  max = 1.0,   default = 0.02,  step = 0.01},
            {key = "dye_b",           label = "Ink B",       min = 0.0,  max = 1.0,   default = 0.1,   step = 0.01},
            {key = "color1_r",        label = "Wtr1 R",      min = 0.0,  max = 1.0,   default = 0.02,  step = 0.01},
            {key = "color1_g",        label = "Wtr1 G",      min = 0.0,  max = 1.0,   default = 0.15,  step = 0.01},
            {key = "color1_b",        label = "Wtr1 B",      min = 0.0,  max = 1.0,   default = 0.3,   step = 0.01},
            {key = "color2_r",        label = "Wtr2 R",      min = 0.0,  max = 1.0,   default = 0.05,  step = 0.01},
            {key = "color2_g",        label = "Wtr2 G",      min = 0.0,  max = 1.0,   default = 0.35,  step = 0.01},
            {key = "color2_b",        label = "Wtr2 B",      min = 0.0,  max = 1.0,   default = 0.45,  step = 0.01},
            {key = "color3_r",        label = "Wtr3 R",      min = 0.0,  max = 1.0,   default = 0.1,   step = 0.01},
            {key = "color3_g",        label = "Wtr3 G",      min = 0.0,  max = 1.0,   default = 0.5,   step = 0.01},
            {key = "color3_b",        label = "Wtr3 B",      min = 0.0,  max = 1.0,   default = 0.35,  step = 0.01},
        },
        values = {},
        data = {},

        init = function(prog, w, h)
            local sim_w = math.floor(w / 4)
            local sim_h = math.floor(h / 4)

            local function makeCanvas(cw, ch)
                local ok, c = pcall(love.graphics.newCanvas, cw, ch, {format = 'rgba16f'})
                if not ok then c = love.graphics.newCanvas(cw, ch) end
                c:setFilter('linear', 'linear')
                return c
            end

            prog.data.sim_w = sim_w
            prog.data.sim_h = sim_h
            prog.data.canvases = {makeCanvas(sim_w, sim_h), makeCanvas(sim_w, sim_h)}
            prog.data.sim_idx = 1
            prog.data.time = 0

            for i = 1, 2 do
                love.graphics.setCanvas(prog.data.canvases[i])
                love.graphics.clear(0, 0, 0, 1)
                love.graphics.setCanvas()
            end

            if not ink_sim_shader then
                local ok, s = pcall(love.graphics.newShader, INK_SIM_GLSL)
                if ok then ink_sim_shader = s
                else print("Ink sim shader error: " .. tostring(s)) end
            end
            if not ink_flow_render_shader then
                local ok, s = pcall(love.graphics.newShader, INK_FLOW_RENDER_GLSL)
                if ok then ink_flow_render_shader = s
                else print("Ink-flow render shader error: " .. tostring(s)) end
            end
        end,

        update = function(prog, dt, mouse)
            if not ink_sim_shader then return end
            local d = prog.data
            local v = prog.values

            d.time = d.time + dt

            local w = love.graphics.getWidth()
            local h = love.graphics.getHeight()
            local vel_x = (mouse.dx / w) * v.vel_strength
            local vel_y = (mouse.dy / h) * v.vel_strength
            local active = mouse.speed > 1 and 1.0 or 0.0

            local steps = math.floor(v.sim_steps + 0.5)

            for step = 1, steps do
                local read = d.canvases[d.sim_idx]
                local write_idx = 3 - d.sim_idx
                local write = d.canvases[write_idx]

                love.graphics.setCanvas(write)
                love.graphics.setShader(ink_sim_shader)

                if ink_sim_shader:hasUniform('texel_size') then
                    ink_sim_shader:send('texel_size', {1 / d.sim_w, 1 / d.sim_h})
                end
                if ink_sim_shader:hasUniform('dye_dissipation') then
                    ink_sim_shader:send('dye_dissipation', v.dye_dissipation)
                end
                if ink_sim_shader:hasUniform('vel_dissipation') then
                    ink_sim_shader:send('vel_dissipation', v.vel_dissipation)
                end
                if ink_sim_shader:hasUniform('diffusion_rate') then
                    ink_sim_shader:send('diffusion_rate', v.diffusion_rate)
                end
                if ink_sim_shader:hasUniform('mouse_pos') then
                    ink_sim_shader:send('mouse_pos', {mouse.uv_x, mouse.uv_y})
                end
                if ink_sim_shader:hasUniform('mouse_vel') then
                    ink_sim_shader:send('mouse_vel', {vel_x, vel_y})
                end
                if ink_sim_shader:hasUniform('mouse_active') then
                    ink_sim_shader:send('mouse_active', step == 1 and active or 0)
                end
                if ink_sim_shader:hasUniform('inject_radius') then
                    ink_sim_shader:send('inject_radius', v.inject_radius)
                end
                if ink_sim_shader:hasUniform('inject_amount') then
                    ink_sim_shader:send('inject_amount', v.inject_amount)
                end

                love.graphics.draw(read, 0, 0)
                love.graphics.setShader()
                love.graphics.setCanvas()

                d.sim_idx = write_idx
            end
        end,

        draw = function(prog, w, h)
            local d = prog.data
            local v = prog.values
            if not ink_flow_render_shader then return end

            love.graphics.setShader(ink_flow_render_shader)
            if ink_flow_render_shader:hasUniform('time') then
                ink_flow_render_shader:send('time', d.time)
            end
            if ink_flow_render_shader:hasUniform('resolution') then
                ink_flow_render_shader:send('resolution', {w, h})
            end
            if ink_flow_render_shader:hasUniform('displace') then
                ink_flow_render_shader:send('displace', v.displace)
            end
            if ink_flow_render_shader:hasUniform('flow_speed') then
                ink_flow_render_shader:send('flow_speed', v.flow_speed)
            end
            if ink_flow_render_shader:hasUniform('flow_scale') then
                ink_flow_render_shader:send('flow_scale', v.flow_scale)
            end
            if ink_flow_render_shader:hasUniform('flow_warp') then
                ink_flow_render_shader:send('flow_warp', v.flow_warp)
            end
            if ink_flow_render_shader:hasUniform('flow_contrast') then
                ink_flow_render_shader:send('flow_contrast', v.flow_contrast)
            end
            if ink_flow_render_shader:hasUniform('dye_color') then
                ink_flow_render_shader:send('dye_color', {v.dye_r, v.dye_g, v.dye_b})
            end
            if ink_flow_render_shader:hasUniform('color1') then
                ink_flow_render_shader:send('color1', {v.color1_r, v.color1_g, v.color1_b})
            end
            if ink_flow_render_shader:hasUniform('color2') then
                ink_flow_render_shader:send('color2', {v.color2_r, v.color2_g, v.color2_b})
            end
            if ink_flow_render_shader:hasUniform('color3') then
                ink_flow_render_shader:send('color3', {v.color3_r, v.color3_g, v.color3_b})
            end
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(d.canvases[d.sim_idx], 0, 0, 0, w / d.sim_w, h / d.sim_h)
            love.graphics.setShader()
        end,
    }

    -- 5. Mystify
    programs[#programs + 1] = {
        name = "Mystify",
        params = {
            {key = "speed",         label = "Speed",      min = 0.1,  max = 3.0,  default = 0.8,   step = 0.05},
            {key = "num_trails",    label = "Trails",     min = 2,    max = 16,   default = 10,    step = 1},
            {key = "trail_spacing", label = "Trail Gap",  min = 0.01, max = 0.3,  default = 0.08,  step = 0.01},
            {key = "line_glow",     label = "Glow Width", min = 0.001, max = 0.02, default = 0.005, step = 0.001},
            {key = "num_shapes",    label = "Shapes",     min = 1,    max = 2,    default = 2,     step = 1},
            {key = "color1_r",      label = "Col1 R",     min = 0.0,  max = 1.0,  default = 0.2,   step = 0.01},
            {key = "color1_g",      label = "Col1 G",     min = 0.0,  max = 1.0,  default = 0.6,   step = 0.01},
            {key = "color1_b",      label = "Col1 B",     min = 0.0,  max = 1.0,  default = 1.0,   step = 0.01},
            {key = "color2_r",      label = "Col2 R",     min = 0.0,  max = 1.0,  default = 1.0,   step = 0.01},
            {key = "color2_g",      label = "Col2 G",     min = 0.0,  max = 1.0,  default = 0.3,   step = 0.01},
            {key = "color2_b",      label = "Col2 B",     min = 0.0,  max = 1.0,  default = 0.6,   step = 0.01},
        },
        values = {},
        data = {},

        init = function(prog, w, h)
            prog.data.time = 0
            prog.data.mesh = love.graphics.newMesh({
                {0, 0, 0, 0, 1, 1, 1, 1},
                {1, 0, 1, 0, 1, 1, 1, 1},
                {1, 1, 1, 1, 1, 1, 1, 1},
                {0, 1, 0, 1, 1, 1, 1, 1},
            }, 'fan')

            if not mystify_shader then
                local ok, s = pcall(love.graphics.newShader, MYSTIFY_GLSL)
                if ok then mystify_shader = s
                else print("Mystify shader error: " .. tostring(s)) end
            end
        end,

        update = function(prog, dt, mouse)
            prog.data.time = prog.data.time + dt
        end,

        draw = function(prog, w, h)
            if not mystify_shader then return end
            local v = prog.values
            love.graphics.setShader(mystify_shader)
            if mystify_shader:hasUniform('time') then
                mystify_shader:send('time', prog.data.time)
            end
            if mystify_shader:hasUniform('speed') then
                mystify_shader:send('speed', v.speed)
            end
            if mystify_shader:hasUniform('num_trails') then
                mystify_shader:send('num_trails', math.floor(v.num_trails + 0.5))
            end
            if mystify_shader:hasUniform('trail_spacing') then
                mystify_shader:send('trail_spacing', v.trail_spacing)
            end
            if mystify_shader:hasUniform('line_glow') then
                mystify_shader:send('line_glow', v.line_glow)
            end
            if mystify_shader:hasUniform('num_shapes') then
                mystify_shader:send('num_shapes', math.floor(v.num_shapes + 0.5))
            end
            if mystify_shader:hasUniform('color1') then
                mystify_shader:send('color1', {v.color1_r, v.color1_g, v.color1_b})
            end
            if mystify_shader:hasUniform('color2') then
                mystify_shader:send('color2', {v.color2_r, v.color2_g, v.color2_b})
            end
            if mystify_shader:hasUniform('resolution') then
                mystify_shader:send('resolution', {w, h})
            end
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(prog.data.mesh, 0, 0, 0, w, h)
            love.graphics.setShader()
        end,
    }

    -- 6. Bezier Curves
    programs[#programs + 1] = {
        name = "Bezier Curves",
        params = {
            {key = "speed",         label = "Speed",      min = 0.1,  max = 3.0,  default = 0.6,   step = 0.05},
            {key = "num_trails",    label = "Trails",     min = 2,    max = 16,   default = 8,     step = 1},
            {key = "trail_spacing", label = "Trail Gap",  min = 0.01, max = 0.3,  default = 0.1,   step = 0.01},
            {key = "line_glow",     label = "Glow Width", min = 0.001, max = 0.02, default = 0.006, step = 0.001},
            {key = "num_curves",    label = "Curves",     min = 1,    max = 2,    default = 2,     step = 1},
            {key = "color1_r",      label = "Col1 R",     min = 0.0,  max = 1.0,  default = 1.0,   step = 0.01},
            {key = "color1_g",      label = "Col1 G",     min = 0.0,  max = 1.0,  default = 0.4,   step = 0.01},
            {key = "color1_b",      label = "Col1 B",     min = 0.0,  max = 1.0,  default = 0.1,   step = 0.01},
            {key = "color2_r",      label = "Col2 R",     min = 0.0,  max = 1.0,  default = 0.1,   step = 0.01},
            {key = "color2_g",      label = "Col2 G",     min = 0.0,  max = 1.0,  default = 0.8,   step = 0.01},
            {key = "color2_b",      label = "Col2 B",     min = 0.0,  max = 1.0,  default = 1.0,   step = 0.01},
        },
        values = {},
        data = {},

        init = function(prog, w, h)
            prog.data.time = 0
            prog.data.mesh = love.graphics.newMesh({
                {0, 0, 0, 0, 1, 1, 1, 1},
                {1, 0, 1, 0, 1, 1, 1, 1},
                {1, 1, 1, 1, 1, 1, 1, 1},
                {0, 1, 0, 1, 1, 1, 1, 1},
            }, 'fan')

            local ok, s = pcall(love.graphics.newShader, BEZIER_GLSL)
            if ok then bezier_shader = s
            else print("Bezier shader error: " .. tostring(s)) end
        end,

        update = function(prog, dt, mouse)
            prog.data.time = prog.data.time + dt
        end,

        draw = function(prog, w, h)
            if not bezier_shader then return end
            local v = prog.values
            love.graphics.setShader(bezier_shader)
            if bezier_shader:hasUniform('time') then bezier_shader:send('time', prog.data.time) end
            if bezier_shader:hasUniform('speed') then bezier_shader:send('speed', v.speed) end
            if bezier_shader:hasUniform('num_trails') then bezier_shader:send('num_trails', math.floor(v.num_trails + 0.5)) end
            if bezier_shader:hasUniform('trail_spacing') then bezier_shader:send('trail_spacing', v.trail_spacing) end
            if bezier_shader:hasUniform('line_glow') then bezier_shader:send('line_glow', v.line_glow) end
            if bezier_shader:hasUniform('num_curves') then bezier_shader:send('num_curves', math.floor(v.num_curves + 0.5)) end
            if bezier_shader:hasUniform('color1') then bezier_shader:send('color1', {v.color1_r, v.color1_g, v.color1_b}) end
            if bezier_shader:hasUniform('color2') then bezier_shader:send('color2', {v.color2_r, v.color2_g, v.color2_b}) end
            if bezier_shader:hasUniform('resolution') then bezier_shader:send('resolution', {w, h}) end
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(prog.data.mesh, 0, 0, 0, w, h)
            love.graphics.setShader()
        end,
    }

    -- 7. Matrix Rain
    programs[#programs + 1] = {
        name = "Matrix Rain",
        params = {
            {key = "speed",       label = "Speed",       min = 0.5,  max = 8.0,  default = 2.0,   step = 0.1},
            {key = "density",     label = "Density",     min = 0.1,  max = 1.0,  default = 0.75,  step = 0.05},
            {key = "char_size",   label = "Char Size",   min = 0.01, max = 0.06, default = 0.025, step = 0.002},
            {key = "tail_len",    label = "Tail Len",    min = 3.0,  max = 30.0, default = 12.0,  step = 1.0},
            {key = "num_drops",   label = "Drops/Col",   min = 1.0,  max = 8.0,  default = 3.0,   step = 1.0},
            {key = "flicker",     label = "Flicker",     min = 0.0,  max = 1.0,  default = 0.5,   step = 0.05},
            {key = "fg_r",        label = "Color R",     min = 0.0,  max = 1.0,  default = 0.1,   step = 0.01},
            {key = "fg_g",        label = "Color G",     min = 0.0,  max = 1.0,  default = 0.9,   step = 0.01},
            {key = "fg_b",        label = "Color B",     min = 0.0,  max = 1.0,  default = 0.2,   step = 0.01},
        },
        values = {},
        data = {},

        init = function(prog, w, h)
            prog.data.time = 0
            prog.data.mesh = love.graphics.newMesh({
                {0, 0, 0, 0, 1, 1, 1, 1},
                {1, 0, 1, 0, 1, 1, 1, 1},
                {1, 1, 1, 1, 1, 1, 1, 1},
                {0, 1, 0, 1, 1, 1, 1, 1},
            }, 'fan')

            local ok, s = pcall(love.graphics.newShader, MATRIX_GLSL)
            if ok then matrix_shader = s
            else print("Matrix shader error: " .. tostring(s)) end
        end,

        update = function(prog, dt, mouse)
            prog.data.time = prog.data.time + dt
        end,

        draw = function(prog, w, h)
            if not matrix_shader then return end
            local v = prog.values
            love.graphics.setShader(matrix_shader)
            if matrix_shader:hasUniform('time') then matrix_shader:send('time', prog.data.time) end
            if matrix_shader:hasUniform('speed') then matrix_shader:send('speed', v.speed) end
            if matrix_shader:hasUniform('density') then matrix_shader:send('density', v.density) end
            if matrix_shader:hasUniform('char_size') then matrix_shader:send('char_size', v.char_size) end
            if matrix_shader:hasUniform('tail_len') then matrix_shader:send('tail_len', v.tail_len) end
            if matrix_shader:hasUniform('num_drops') then matrix_shader:send('num_drops', v.num_drops) end
            if matrix_shader:hasUniform('flicker') then matrix_shader:send('flicker', v.flicker) end
            if matrix_shader:hasUniform('fg_color') then matrix_shader:send('fg_color', {v.fg_r, v.fg_g, v.fg_b}) end
            if matrix_shader:hasUniform('resolution') then matrix_shader:send('resolution', {w, h}) end
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(prog.data.mesh, 0, 0, 0, w, h)
            love.graphics.setShader()
        end,
    }

    -- 8. Bounce Warp
    programs[#programs + 1] = {
        name = "Bounce Warp",
        params = {
            {key = "speed",         label = "Speed",      min = 0.1,  max = 3.0,  default = 0.8,   step = 0.05},
            {key = "warp_radius",   label = "Radius",     min = 0.02, max = 0.3,  default = 0.12,  step = 0.01},
            {key = "warp_strength", label = "Strength",   min = 0.0,  max = 2.0,  default = 0.6,   step = 0.05},
            {key = "warp_type",     label = "Type 0/1/2", min = 0.0,  max = 2.0,  default = 0.0,   step = 1.0},
            {key = "num_balls",     label = "Balls",      min = 1,    max = 4,    default = 2,     step = 1},
            {key = "use_screen",    label = "Screen",     min = 0.0,  max = 1.0,  default = 0.0,   step = 1.0},
            {key = "grid_scale",    label = "Grid Scale",  min = 4.0,  max = 40.0, default = 16.0,  step = 1.0},
            {key = "ball_r",        label = "Ball R",     min = 0.0,  max = 1.0,  default = 0.4,   step = 0.01},
            {key = "ball_g",        label = "Ball G",     min = 0.0,  max = 1.0,  default = 0.7,   step = 0.01},
            {key = "ball_b",        label = "Ball B",     min = 0.0,  max = 1.0,  default = 1.0,   step = 0.01},
            {key = "bg1_r",         label = "BG1 R",      min = 0.0,  max = 1.0,  default = 0.08,  step = 0.01},
            {key = "bg1_g",         label = "BG1 G",      min = 0.0,  max = 1.0,  default = 0.08,  step = 0.01},
            {key = "bg1_b",         label = "BG1 B",      min = 0.0,  max = 1.0,  default = 0.12,  step = 0.01},
            {key = "bg2_r",         label = "BG2 R",      min = 0.0,  max = 1.0,  default = 0.15,  step = 0.01},
            {key = "bg2_g",         label = "BG2 G",      min = 0.0,  max = 1.0,  default = 0.15,  step = 0.01},
            {key = "bg2_b",         label = "BG2 B",      min = 0.0,  max = 1.0,  default = 0.22,  step = 0.01},
        },
        values = {},
        data = {},

        init = function(prog, w, h)
            prog.data.time = 0
            prog.data.mesh = love.graphics.newMesh({
                {0, 0, 0, 0, 1, 1, 1, 1},
                {1, 0, 1, 0, 1, 1, 1, 1},
                {1, 1, 1, 1, 1, 1, 1, 1},
                {0, 1, 0, 1, 1, 1, 1, 1},
            }, 'fan')

            if not warp_shader then
                local ok, s = pcall(love.graphics.newShader, WARP_GLSL)
                if ok then warp_shader = s
                else print("Warp shader error: " .. tostring(s)) end
            end
        end,

        update = function(prog, dt, mouse)
            prog.data.time = prog.data.time + dt
        end,

        draw = function(prog, w, h)
            if not warp_shader then return end
            local v = prog.values
            local screen_on = (v.use_screen or 0) > 0.5
            love.graphics.setShader(warp_shader)
            if warp_shader:hasUniform('time') then warp_shader:send('time', prog.data.time) end
            if warp_shader:hasUniform('speed') then warp_shader:send('speed', v.speed) end
            if warp_shader:hasUniform('warp_radius') then warp_shader:send('warp_radius', v.warp_radius) end
            if warp_shader:hasUniform('warp_strength') then warp_shader:send('warp_strength', v.warp_strength) end
            if warp_shader:hasUniform('warp_type') then warp_shader:send('warp_type', v.warp_type) end
            if warp_shader:hasUniform('num_balls') then warp_shader:send('num_balls', math.floor(v.num_balls + 0.5)) end
            if warp_shader:hasUniform('use_screen') then warp_shader:send('use_screen', screen_on and 1.0 or 0.0) end
            if warp_shader:hasUniform('grid_scale') then warp_shader:send('grid_scale', v.grid_scale) end
            if warp_shader:hasUniform('ball_color') then warp_shader:send('ball_color', {v.ball_r, v.ball_g, v.ball_b}) end
            if warp_shader:hasUniform('bg_color1') then warp_shader:send('bg_color1', {v.bg1_r, v.bg1_g, v.bg1_b}) end
            if warp_shader:hasUniform('bg_color2') then warp_shader:send('bg_color2', {v.bg2_r, v.bg2_g, v.bg2_b}) end
            if warp_shader:hasUniform('resolution') then warp_shader:send('resolution', {w, h}) end
            love.graphics.setColor(1, 1, 1)
            if screen_on and prog.data.screen_texture then
                local tex = prog.data.screen_texture
                love.graphics.draw(tex, 0, 0, 0, w / tex:getWidth(), h / tex:getHeight())
            else
                love.graphics.draw(prog.data.mesh, 0, 0, 0, w, h)
            end
            love.graphics.setShader()
        end,
    }

    -- 9. Plasma
    programs[#programs + 1] = {
        name = "Plasma",
        params = {
            {key = "palette_speed", label = "Pal Speed",  min = 0.01, max = 1.0,  default = 0.15,  step = 0.01},
            {key = "scale",         label = "Scale",      min = 2.0,  max = 30.0, default = 10.0,  step = 0.5},
            {key = "layers",        label = "Layers 4/6", min = 4.0,  max = 6.0,  default = 4.0,   step = 2.0},
            {key = "color1_r",      label = "Col1 R",     min = 0.0,  max = 1.0,  default = 0.15,  step = 0.01},
            {key = "color1_g",      label = "Col1 G",     min = 0.0,  max = 1.0,  default = 0.0,   step = 0.01},
            {key = "color1_b",      label = "Col1 B",     min = 0.0,  max = 1.0,  default = 0.35,  step = 0.01},
            {key = "color2_r",      label = "Col2 R",     min = 0.0,  max = 1.0,  default = 0.0,   step = 0.01},
            {key = "color2_g",      label = "Col2 G",     min = 0.0,  max = 1.0,  default = 0.8,   step = 0.01},
            {key = "color2_b",      label = "Col2 B",     min = 0.0,  max = 1.0,  default = 0.9,   step = 0.01},
            {key = "color3_r",      label = "Col3 R",     min = 0.0,  max = 1.0,  default = 0.9,   step = 0.01},
            {key = "color3_g",      label = "Col3 G",     min = 0.0,  max = 1.0,  default = 0.1,   step = 0.01},
            {key = "color3_b",      label = "Col3 B",     min = 0.0,  max = 1.0,  default = 0.6,   step = 0.01},
        },
        values = {},
        data = {},

        init = function(prog, w, h)
            prog.data.time = 0
            prog.data.mesh = love.graphics.newMesh({
                {0, 0, 0, 0, 1, 1, 1, 1},
                {1, 0, 1, 0, 1, 1, 1, 1},
                {1, 1, 1, 1, 1, 1, 1, 1},
                {0, 1, 0, 1, 1, 1, 1, 1},
            }, 'fan')

            local ok, s = pcall(love.graphics.newShader, PLASMA_GLSL)
            if ok then plasma_shader = s
            else print("Plasma shader error: " .. tostring(s)) end
        end,

        update = function(prog, dt, mouse)
            prog.data.time = prog.data.time + dt
        end,

        draw = function(prog, w, h)
            if not plasma_shader then return end
            local v = prog.values
            love.graphics.setShader(plasma_shader)
            if plasma_shader:hasUniform('time') then plasma_shader:send('time', prog.data.time) end
            if plasma_shader:hasUniform('palette_speed') then plasma_shader:send('palette_speed', v.palette_speed) end
            if plasma_shader:hasUniform('scale') then plasma_shader:send('scale', v.scale) end
            if plasma_shader:hasUniform('layers') then plasma_shader:send('layers', v.layers) end
            if plasma_shader:hasUniform('color1') then plasma_shader:send('color1', {v.color1_r, v.color1_g, v.color1_b}) end
            if plasma_shader:hasUniform('color2') then plasma_shader:send('color2', {v.color2_r, v.color2_g, v.color2_b}) end
            if plasma_shader:hasUniform('color3') then plasma_shader:send('color3', {v.color3_r, v.color3_g, v.color3_b}) end
            if plasma_shader:hasUniform('resolution') then plasma_shader:send('resolution', {w, h}) end
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(prog.data.mesh, 0, 0, 0, w, h)
            love.graphics.setShader()
        end,
    }

    -- 10. 3D Text — all motion axes independent and composable
    programs[#programs + 1] = {
        name = "3D Text",
        params = {
            -- Drift: linear bounce off walls
            {key = "drift_x",    label = "Drift X",    min = 0.0,  max = 2.0,  default = 0.5,  step = 0.05},
            {key = "drift_y",    label = "Drift Y",    min = 0.0,  max = 2.0,  default = 0.3,  step = 0.05},
            -- Spin: continuous rotation per axis
            {key = "spin_x",     label = "Spin X",     min = -2.0, max = 2.0,  default = 0.0,  step = 0.05},
            {key = "spin_y",     label = "Spin Y",     min = -2.0, max = 2.0,  default = 0.5,  step = 0.05},
            {key = "spin_z",     label = "Spin Z",     min = -2.0, max = 2.0,  default = 0.0,  step = 0.05},
            -- Sway: oscillating rotation per axis
            {key = "sway_x",     label = "Sway X",     min = 0.0,  max = 1.5,  default = 0.0,  step = 0.05},
            {key = "sway_y",     label = "Sway Y",     min = 0.0,  max = 1.5,  default = 0.0,  step = 0.05},
            {key = "sway_z",     label = "Sway Z",     min = 0.0,  max = 1.5,  default = 0.0,  step = 0.05},
            -- Appearance
            {key = "text_size",  label = "Size",        min = 0.3,  max = 2.0,  default = 1.0,  step = 0.05},
            {key = "surface",    label = "Srf 0/1",     min = 0.0,  max = 1.0,  default = 1.0,  step = 1.0},
            {key = "thickness",  label = "Thickness",   min = 0.02, max = 0.15, default = 0.07, step = 0.005},
            {key = "extrude",    label = "Depth",       min = 0.02, max = 0.5,  default = 0.15, step = 0.01},
            {key = "specular",   label = "Specular",    min = 0.0,  max = 1.5,  default = 0.8,  step = 0.05},
            {key = "color1_r",   label = "Col1 R",      min = 0.0,  max = 1.0,  default = 0.6,  step = 0.01},
            {key = "color1_g",   label = "Col1 G",      min = 0.0,  max = 1.0,  default = 0.4,  step = 0.01},
            {key = "color1_b",   label = "Col1 B",      min = 0.0,  max = 1.0,  default = 0.1,  step = 0.01},
            {key = "color2_r",   label = "Col2 R",      min = 0.0,  max = 1.0,  default = 1.0,  step = 0.01},
            {key = "color2_g",   label = "Col2 G",      min = 0.0,  max = 1.0,  default = 0.85, step = 0.01},
            {key = "color2_b",   label = "Col2 B",      min = 0.0,  max = 1.0,  default = 0.5,  step = 0.01},
        },
        values = {},
        data = {},

        init = function(prog, w, h)
            prog.data.time = 0
            prog.data.tx = 0
            prog.data.ty = 0
            prog.data.vx = 1
            prog.data.vy = 1
            prog.data.cos_rx = 1; prog.data.sin_rx = 0
            prog.data.cos_ry = 1; prog.data.sin_ry = 0
            prog.data.cos_rz = 1; prog.data.sin_rz = 0
            prog.data.mesh = love.graphics.newMesh({
                {0, 0, 0, 0, 1, 1, 1, 1},
                {1, 0, 1, 0, 1, 1, 1, 1},
                {1, 1, 1, 1, 1, 1, 1, 1},
                {0, 1, 0, 1, 1, 1, 1, 1},
            }, 'fan')

            local ok, s = pcall(love.graphics.newShader, TEXT3D_GLSL)
            if ok then text3d_shader = s
            else print("3D Text shader error: " .. tostring(s)) end
        end,

        update = function(prog, dt, mouse)
            prog.data.time = prog.data.time + dt
            local t = prog.data.time
            local v = prog.values
            local d = prog.data

            -- Rotation
            local rx = v.spin_x * t + v.sway_x * math.sin(t * 1.0)
            local ry = v.spin_y * t + v.sway_y * math.sin(t * 1.3)
            local rz = v.spin_z * t + v.sway_z * math.sin(t * 0.7)
            d.cos_rx = math.cos(rx); d.sin_rx = math.sin(rx)
            d.cos_ry = math.cos(ry); d.sin_ry = math.sin(ry)
            d.cos_rz = math.cos(rz); d.sin_rz = math.sin(rz)

            -- tx/ty are now in UV space: x = -aspect..+aspect, y = -1..+1
            local aspect = love.graphics.getWidth() / love.graphics.getHeight()
            local proj = 1.5 * v.text_size / 5.5
            local text_screen_hx = (2.15 + v.thickness) * proj
            local text_screen_hy = (0.45 + v.thickness) * proj
            local limit_x = math.max(0.01, aspect - text_screen_hx)
            local limit_y = math.max(0.01, 1.0 - text_screen_hy)

            -- Move and bounce in UV space
            d.tx = d.tx + d.vx * v.drift_x * 0.3 * dt
            d.ty = d.ty + d.vy * v.drift_y * 0.25 * dt

            if d.tx > limit_x then d.tx = limit_x; d.vx = -1 end
            if d.tx < -limit_x then d.tx = -limit_x; d.vx = 1 end
            if d.ty > limit_y then d.ty = limit_y; d.vy = -1 end
            if d.ty < -limit_y then d.ty = -limit_y; d.vy = 1 end
        end,

        draw = function(prog, w, h)
            if not text3d_shader then return end
            local v = prog.values
            local d = prog.data
            love.graphics.setShader(text3d_shader)
            if text3d_shader:hasUniform('thickness') then text3d_shader:send('thickness', v.thickness) end
            if text3d_shader:hasUniform('extrude') then text3d_shader:send('extrude', v.extrude) end
            if text3d_shader:hasUniform('specular') then text3d_shader:send('specular', v.specular) end
            if text3d_shader:hasUniform('surface') then text3d_shader:send('surface', v.surface) end
            if text3d_shader:hasUniform('text_size') then text3d_shader:send('text_size', v.text_size) end
            if text3d_shader:hasUniform('color1') then text3d_shader:send('color1', {v.color1_r, v.color1_g, v.color1_b}) end
            if text3d_shader:hasUniform('color2') then text3d_shader:send('color2', {v.color2_r, v.color2_g, v.color2_b}) end
            if text3d_shader:hasUniform('resolution') then text3d_shader:send('resolution', {w, h}) end
            if text3d_shader:hasUniform('tx') then text3d_shader:send('tx', d.tx) end
            if text3d_shader:hasUniform('ty') then text3d_shader:send('ty', d.ty) end
            if text3d_shader:hasUniform('cos_ry') then text3d_shader:send('cos_ry', d.cos_ry) end
            if text3d_shader:hasUniform('sin_ry') then text3d_shader:send('sin_ry', d.sin_ry) end
            if text3d_shader:hasUniform('cos_rx') then text3d_shader:send('cos_rx', d.cos_rx) end
            if text3d_shader:hasUniform('sin_rx') then text3d_shader:send('sin_rx', d.sin_rx) end
            if text3d_shader:hasUniform('cos_rz') then text3d_shader:send('cos_rz', d.cos_rz) end
            if text3d_shader:hasUniform('sin_rz') then text3d_shader:send('sin_rz', d.sin_rz) end
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(d.mesh, 0, 0, 0, w, h)
            love.graphics.setShader()
        end,
    }

    return programs
end

--------------------------------------------------------------------------------
-- UI constants
--------------------------------------------------------------------------------

local PANEL_W = 250
local SLIDER_H = 18
local SLIDER_PAD = 4
local ROW_H = SLIDER_H + SLIDER_PAD
local LABEL_W = 85
local VALUE_W = 50
local HEADER_H = 36

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

function ShaderSandboxState:init(di)
    self.state_machine = di.stateMachine
    self.previous_state = nil
    self.programs = nil
    self.active_idx = 1
    self.prev_mx = 0
    self.prev_my = 0
    self.dragging_slider = nil -- {prog_idx, param_idx}
    self.scroll_y = 0
    self.copy_flash = 0
end

function ShaderSandboxState:enter(previous_state_name)
    self.previous_state = previous_state_name or Constants.state.DESKTOP

    self.programs = buildPrograms()
    self.active_idx = 1
    self.dragging_slider = nil
    self.scroll_y = 0

    -- Populate default values
    for _, prog in ipairs(self.programs) do
        for _, p in ipairs(prog.params) do
            prog.values[p.key] = p.default
        end
    end

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()
    self.prev_mx = mx
    self.prev_my = my

    -- Store screen capture on Bounce Warp program if available
    if self.screen_capture then
        for _, p in ipairs(self.programs) do
            if p.name == "Bounce Warp" then
                p.data.screen_texture = self.screen_capture
                break
            end
        end
    end

    -- Init active program
    local prog = self.programs[self.active_idx]
    if prog.init then prog.init(prog, w, h) end
end

function ShaderSandboxState:switchProgram(dir)
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

function ShaderSandboxState:update(dt)
    local mx, my = love.mouse.getPosition()
    local dx = mx - self.prev_mx
    local dy = my - self.prev_my
    local speed = math.sqrt(dx * dx + dy * dy)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    local mouse = {
        x = mx, y = my,
        dx = dx, dy = dy,
        speed = speed,
        uv_x = mx / w,
        uv_y = my / h,
    }

    -- Handle slider dragging
    if self.dragging_slider then
        local prog = self.programs[self.dragging_slider.prog_idx]
        local p = prog.params[self.dragging_slider.param_idx]
        local slider_x = SLIDER_PAD + LABEL_W
        local slider_w = PANEL_W - LABEL_W - VALUE_W - SLIDER_PAD * 2
        local t = (mx - slider_x) / slider_w
        t = math.max(0, math.min(1, t))
        local raw = p.min + t * (p.max - p.min)
        -- Snap to step
        raw = math.floor(raw / p.step + 0.5) * p.step
        raw = math.max(p.min, math.min(p.max, raw))
        prog.values[p.key] = raw
    end

    if self.copy_flash > 0 then
        self.copy_flash = self.copy_flash - dt * 2
    end

    local prog = self.programs[self.active_idx]
    if prog.update then prog.update(prog, dt, mouse) end

    self.prev_mx = mx
    self.prev_my = my
end

function ShaderSandboxState:copyValues()
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

function ShaderSandboxState:draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local prog = self.programs[self.active_idx]

    -- Draw shader output (full screen, panel will overlay)
    if prog.draw then prog.draw(prog, w, h) end

    -- Draw panel background
    love.graphics.setColor(0.05, 0.05, 0.08, 0.85)
    love.graphics.rectangle('fill', 0, 0, PANEL_W, h)
    love.graphics.setColor(0.3, 0.3, 0.4, 1)
    love.graphics.rectangle('line', PANEL_W, 0, 1, h)

    -- Header: < ShaderName >
    local arrow_w = 24
    love.graphics.setColor(0.7, 0.7, 0.8, 1)
    love.graphics.printf("<", 4, 10, arrow_w, 'center')
    love.graphics.printf(">", PANEL_W - arrow_w - 4, 10, arrow_w, 'center')
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(prog.name, arrow_w + 4, 10, PANEL_W - arrow_w * 2 - 8, 'center')

    -- Param sliders
    love.graphics.setScissor(0, HEADER_H, PANEL_W, h - HEADER_H)
    local y = HEADER_H - self.scroll_y
    local slider_x = SLIDER_PAD + LABEL_W
    local slider_w = PANEL_W - LABEL_W - VALUE_W - SLIDER_PAD * 2

    for i, p in ipairs(prog.params) do
        local val = prog.values[p.key]
        local t = (val - p.min) / (p.max - p.min)

        -- Label
        love.graphics.setColor(0.7, 0.7, 0.8, 1)
        love.graphics.printf(p.label, SLIDER_PAD, y + 1, LABEL_W - 4, 'right')

        -- Slider track
        love.graphics.setColor(0.2, 0.2, 0.25, 1)
        love.graphics.rectangle('fill', slider_x, y + 2, slider_w, SLIDER_H - 4, 3, 3)

        -- Slider fill
        love.graphics.setColor(0.35, 0.5, 0.8, 1)
        local fill_w = math.max(0, t * slider_w)
        if fill_w > 0 then
            love.graphics.rectangle('fill', slider_x, y + 2, fill_w, SLIDER_H - 4, 3, 3)
        end

        -- Slider handle
        local handle_x = slider_x + t * slider_w
        love.graphics.setColor(0.9, 0.9, 1.0, 1)
        love.graphics.circle('fill', handle_x, y + SLIDER_H / 2, 5)

        -- Value text
        local fmt = p.step < 0.01 and "%.4f" or p.step < 0.1 and "%.3f" or p.step < 1 and "%.2f" or "%.0f"
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        love.graphics.printf(string.format(fmt, val), PANEL_W - VALUE_W - SLIDER_PAD, y + 1, VALUE_W, 'left')

        y = y + ROW_H
    end
    love.graphics.setScissor()

    -- Copy button
    local btn_w, btn_h = 50, 20
    local btn_x = (PANEL_W - btn_w) / 2
    local btn_y = h - 44
    local bmx, bmy = love.mouse.getPosition()
    local hover = bmx >= btn_x and bmx <= btn_x + btn_w and bmy >= btn_y and bmy <= btn_y + btn_h
    love.graphics.setColor(hover and {0.35, 0.5, 0.8, 1} or {0.2, 0.25, 0.35, 1})
    love.graphics.rectangle('fill', btn_x, btn_y, btn_w, btn_h, 3, 3)
    love.graphics.setColor(0.9, 0.9, 1.0, 1)
    love.graphics.printf("Copy", btn_x, btn_y + 3, btn_w, 'center')

    -- Flash feedback
    if self.copy_flash and self.copy_flash > 0 then
        love.graphics.setColor(0.4, 0.8, 0.4, self.copy_flash)
        love.graphics.printf("Copied!", 0, btn_y - 16, PANEL_W, 'center')
    end

    -- Help text at bottom
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.printf("Left/Right: switch   Ctrl+C: copy   F9/ESC: close", 0, h - 20, PANEL_W, 'center')
end

function ShaderSandboxState:getSliderAtPos(mx, my)
    local prog = self.programs[self.active_idx]
    local slider_x = SLIDER_PAD + LABEL_W
    local slider_w = PANEL_W - LABEL_W - VALUE_W - SLIDER_PAD * 2

    for i, p in ipairs(prog.params) do
        local y = HEADER_H - self.scroll_y + (i - 1) * ROW_H
        if mx >= slider_x - 6 and mx <= slider_x + slider_w + 6 and
           my >= y and my <= y + SLIDER_H then
            return i
        end
    end
    return nil
end

function ShaderSandboxState:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Check copy button
    local h = love.graphics.getHeight()
    local btn_w, btn_h = 50, 20
    local btn_x = (PANEL_W - btn_w) / 2
    local btn_y = h - 44
    if x >= btn_x and x <= btn_x + btn_w and y >= btn_y and y <= btn_y + btn_h then
        self:copyValues()
        return true
    end

    -- Check header arrows
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

    -- Check sliders
    if x < PANEL_W then
        local idx = self:getSliderAtPos(x, y)
        if idx then
            self.dragging_slider = {prog_idx = self.active_idx, param_idx = idx}
            -- Immediately set value to click position
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

function ShaderSandboxState:mousereleased(x, y, button)
    if button == 1 then
        self.dragging_slider = nil
    end
end

function ShaderSandboxState:wheelmoved(x, y)
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

function ShaderSandboxState:keypressed(key)
    if key == 'f9' or key == 'escape' then
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

return ShaderSandboxState
