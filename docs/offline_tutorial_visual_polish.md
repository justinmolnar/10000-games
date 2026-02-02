# Offline Tutorial: Visual Polish & Effects

## Goal
Make the games look less like "something made in 20 minutes" and more like something with juice, feel, and personality. No need for good art - just effects, particles, color, and motion.

## Difficulty: Medium (3-5 hours, modular)

## The Problem

Right now the games have:
- Static sprites on dark backgrounds
- Minimal feedback on actions
- No screen effects
- No particle systems (or unused ones)
- Generic colors

Games need "juice" - the feeling that things are alive and responsive.

---

## Files to Study First

- `src/utils/game_components/visual_effects.lua` - Existing effects system
- `src/games/views/*.lua` - Where rendering happens
- Any LÖVE2D shader tutorials you have saved

---

## Part 1: Expand the VisualEffects Component

The existing `VisualEffects` component has basics. Let's expand it.

### 1.1: Add More Particle Presets

Open `src/utils/game_components/visual_effects.lua` and add particle presets:

```lua
-- Particle presets for common effects
VisualEffects.PRESETS = {
    explosion = {
        count = 30,
        lifetime = {0.3, 0.8},
        speed = {100, 300},
        spread = math.pi * 2,
        size = {4, 1},
        colors = {{1, 0.8, 0.2, 1}, {1, 0.3, 0, 0.5}, {0.3, 0.1, 0, 0}},
        gravity = 200
    },

    sparkle = {
        count = 15,
        lifetime = {0.2, 0.5},
        speed = {20, 80},
        spread = math.pi * 2,
        size = {3, 0},
        colors = {{1, 1, 1, 1}, {1, 1, 0.5, 0}},
        gravity = -50  -- Float up
    },

    dust = {
        count = 8,
        lifetime = {0.3, 0.6},
        speed = {30, 60},
        spread = math.pi / 4,
        size = {2, 4},
        colors = {{0.6, 0.5, 0.4, 0.8}, {0.6, 0.5, 0.4, 0}},
        gravity = 100
    },

    blood = {  -- Or "damage" for family-friendly
        count = 12,
        lifetime = {0.2, 0.5},
        speed = {50, 150},
        spread = math.pi / 2,
        size = {3, 1},
        colors = {{1, 0.2, 0.2, 1}, {0.5, 0, 0, 0}},
        gravity = 400
    },

    collect = {
        count = 20,
        lifetime = {0.3, 0.7},
        speed = {50, 150},
        spread = math.pi * 2,
        size = {2, 0},
        colors = {{1, 1, 0, 1}, {1, 0.8, 0, 0}},
        gravity = -100
    },

    trail = {
        count = 1,
        lifetime = {0.1, 0.3},
        speed = {0, 10},
        spread = 0,
        size = {4, 2},
        colors = {{1, 1, 1, 0.5}, {1, 1, 1, 0}},
        gravity = 0
    }
}

-- Emit particles using a preset
function VisualEffects:emitPreset(preset_name, x, y, direction)
    local preset = VisualEffects.PRESETS[preset_name]
    if not preset then
        print("[VisualEffects] Unknown preset:", preset_name)
        return
    end

    if not self.particles then
        self:createParticleSystem()
    end

    -- Configure particle system from preset
    self.particles:setParticleLifetime(preset.lifetime[1], preset.lifetime[2])
    self.particles:setSpeed(preset.speed[1], preset.speed[2])
    self.particles:setSpread(preset.spread)
    self.particles:setSizes(unpack(preset.size))
    self.particles:setColors(unpack(self:flattenColors(preset.colors)))
    self.particles:setLinearAcceleration(0, preset.gravity or 0, 0, preset.gravity or 0)

    if direction then
        self.particles:setDirection(direction)
    end

    self.particles:setPosition(x, y)
    self.particles:emit(preset.count)
end

-- Helper to flatten color table for setColors
function VisualEffects:flattenColors(colors)
    local flat = {}
    for _, c in ipairs(colors) do
        for _, v in ipairs(c) do
            table.insert(flat, v)
        end
    end
    return flat
end
```

### 1.2: Add Screen Shake Improvements

```lua
-- Directional shake (for impacts)
function VisualEffects:shakeDirectional(intensity, direction, duration)
    self.shake_intensity = intensity
    self.shake_direction = direction  -- Angle in radians
    self.shake_duration = duration or 0.2
    self.shake_timer = self.shake_duration
    self.shake_mode = "directional"
end

-- Punch effect (quick snap and return)
function VisualEffects:punch(dx, dy, duration)
    self.punch_offset_x = dx
    self.punch_offset_y = dy
    self.punch_timer = duration or 0.1
    self.punch_duration = duration or 0.1
end

-- Update shake (modified)
function VisualEffects:updateShake(dt)
    -- Regular shake
    if self.shake_timer and self.shake_timer > 0 then
        self.shake_timer = self.shake_timer - dt
        local progress = self.shake_timer / self.shake_duration
        local current_intensity = self.shake_intensity * progress

        if self.shake_mode == "directional" then
            local noise = (math.random() - 0.5) * 2
            self.shake_offset_x = math.cos(self.shake_direction) * current_intensity * noise
            self.shake_offset_y = math.sin(self.shake_direction) * current_intensity * noise
        else
            self.shake_offset_x = (math.random() - 0.5) * 2 * current_intensity
            self.shake_offset_y = (math.random() - 0.5) * 2 * current_intensity
        end
    else
        self.shake_offset_x = 0
        self.shake_offset_y = 0
    end

    -- Punch effect
    if self.punch_timer and self.punch_timer > 0 then
        self.punch_timer = self.punch_timer - dt
        local progress = self.punch_timer / self.punch_duration
        -- Ease out
        progress = progress * progress
        self.punch_current_x = self.punch_offset_x * progress
        self.punch_current_y = self.punch_offset_y * progress
    else
        self.punch_current_x = 0
        self.punch_current_y = 0
    end
end

-- Get total offset (shake + punch)
function VisualEffects:getOffset()
    return
        (self.shake_offset_x or 0) + (self.punch_current_x or 0),
        (self.shake_offset_y or 0) + (self.punch_current_y or 0)
end
```

### 1.3: Add Hitstop/Freeze Frame

```lua
-- Freeze the game for impact
function VisualEffects:hitstop(duration)
    self.hitstop_timer = duration or 0.05
end

function VisualEffects:isHitstopped()
    return self.hitstop_timer and self.hitstop_timer > 0
end

function VisualEffects:updateHitstop(dt)
    if self.hitstop_timer and self.hitstop_timer > 0 then
        self.hitstop_timer = self.hitstop_timer - dt
        return true  -- Signal to skip game update
    end
    return false
end
```

Usage in game:
```lua
function MyGame:updateGameLogic(dt)
    -- Skip update during hitstop
    if self.visual_effects:isHitstopped() then
        self.visual_effects:updateHitstop(dt)
        return
    end
    -- ... normal update ...
end

function MyGame:onEnemyKilled(enemy)
    self.visual_effects:hitstop(0.03)  -- 30ms freeze
    self.visual_effects:emitPreset("explosion", enemy.x, enemy.y)
    self.visual_effects:shakeDirectional(8, math.atan2(enemy.y - self.player.y, enemy.x - self.player.x), 0.15)
end
```

---

## Part 2: Seeded Random Colors

Create color generation that's deterministic per variant.

### 2.1: Create Color Generator

Create `src/utils/color_generator.lua`:

```lua
-- src/utils/color_generator.lua
-- Generate consistent colors from seeds

local ColorGenerator = {}

-- Generate a color from a seed
function ColorGenerator.fromSeed(seed, saturation, lightness)
    saturation = saturation or 0.7
    lightness = lightness or 0.5

    -- Use seed to generate hue
    local rng = love.math.newRandomGenerator(seed)
    local hue = rng:random()

    return ColorGenerator.hslToRgb(hue, saturation, lightness)
end

-- Generate a palette from a seed
function ColorGenerator.paletteFromSeed(seed, count, harmony)
    harmony = harmony or "analogous"
    count = count or 5

    local rng = love.math.newRandomGenerator(seed)
    local base_hue = rng:random()
    local saturation = 0.6 + rng:random() * 0.3
    local lightness = 0.4 + rng:random() * 0.2

    local colors = {}

    if harmony == "analogous" then
        -- Colors close together
        for i = 1, count do
            local hue = (base_hue + (i - 1) * 0.08) % 1
            table.insert(colors, ColorGenerator.hslToRgb(hue, saturation, lightness))
        end

    elseif harmony == "complementary" then
        -- Opposite colors
        table.insert(colors, ColorGenerator.hslToRgb(base_hue, saturation, lightness))
        table.insert(colors, ColorGenerator.hslToRgb((base_hue + 0.5) % 1, saturation, lightness))
        for i = 3, count do
            local offset = (i - 2) * 0.1
            table.insert(colors, ColorGenerator.hslToRgb((base_hue + offset) % 1, saturation * 0.8, lightness))
        end

    elseif harmony == "triadic" then
        -- Three equally spaced
        for i = 1, count do
            local hue = (base_hue + (i - 1) / 3) % 1
            table.insert(colors, ColorGenerator.hslToRgb(hue, saturation, lightness))
        end

    elseif harmony == "monochromatic" then
        -- Same hue, different lightness
        for i = 1, count do
            local l = 0.2 + (i / count) * 0.6
            table.insert(colors, ColorGenerator.hslToRgb(base_hue, saturation, l))
        end

    elseif harmony == "neon" then
        -- Bright, saturated
        for i = 1, count do
            local hue = (base_hue + (i - 1) * 0.15) % 1
            table.insert(colors, ColorGenerator.hslToRgb(hue, 1.0, 0.6))
        end

    elseif harmony == "pastel" then
        -- Soft, desaturated
        for i = 1, count do
            local hue = (base_hue + (i - 1) * 0.1) % 1
            table.insert(colors, ColorGenerator.hslToRgb(hue, 0.4, 0.75))
        end

    elseif harmony == "dark" then
        -- Dark and moody
        for i = 1, count do
            local hue = (base_hue + (i - 1) * 0.05) % 1
            table.insert(colors, ColorGenerator.hslToRgb(hue, 0.5, 0.25))
        end
    end

    return colors
end

-- HSL to RGB conversion
function ColorGenerator.hslToRgb(h, s, l)
    if s == 0 then
        return {l, l, l}
    end

    local function hue2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
        return p
    end

    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q

    return {
        hue2rgb(p, q, h + 1/3),
        hue2rgb(p, q, h),
        hue2rgb(p, q, h - 1/3)
    }
end

-- Lighten a color
function ColorGenerator.lighten(color, amount)
    return {
        math.min(1, color[1] + amount),
        math.min(1, color[2] + amount),
        math.min(1, color[3] + amount),
        color[4] or 1
    }
end

-- Darken a color
function ColorGenerator.darken(color, amount)
    return {
        math.max(0, color[1] - amount),
        math.max(0, color[2] - amount),
        math.max(0, color[3] - amount),
        color[4] or 1
    }
end

-- Add alpha to color
function ColorGenerator.withAlpha(color, alpha)
    return {color[1], color[2], color[3], alpha}
end

return ColorGenerator
```

### 2.2: Use in Games

```lua
local ColorGenerator = require('src.utils.color_generator')

function MyGame:init(...)
    -- ... existing init ...

    -- Generate colors from variant seed
    local color_seed = self.variant.clone_index or self.seed or 12345
    self.palette = ColorGenerator.paletteFromSeed(color_seed, 5, "analogous")

    -- Assign to game elements
    self.player_color = self.palette[1]
    self.enemy_color = self.palette[3]
    self.background_color = ColorGenerator.darken(self.palette[5], 0.3)
    self.accent_color = self.palette[2]
end
```

---

## Part 3: Simple Shaders

LÖVE2D supports GLSL shaders. Here are some useful ones.

### 3.1: Create Shader Utilities

Create `src/utils/shaders.lua`:

```lua
-- src/utils/shaders.lua
-- Reusable shader effects

local Shaders = {}

-- CRT/Scanline effect
Shaders.crt = love.graphics.newShader([[
    extern number time;
    extern vec2 screen_size;

    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 pixel = Texel(tex, tc);

        // Scanlines
        float scanline = sin(tc.y * screen_size.y * 3.14159) * 0.04;
        pixel.rgb -= scanline;

        // Vignette
        vec2 center = tc - 0.5;
        float vignette = 1.0 - dot(center, center) * 0.5;
        pixel.rgb *= vignette;

        return pixel * color;
    }
]])

-- Chromatic aberration
Shaders.chromatic = love.graphics.newShader([[
    extern number amount;

    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec2 offset = vec2(amount, 0.0);

        float r = Texel(tex, tc + offset).r;
        float g = Texel(tex, tc).g;
        float b = Texel(tex, tc - offset).b;
        float a = Texel(tex, tc).a;

        return vec4(r, g, b, a) * color;
    }
]])

-- Pixelate
Shaders.pixelate = love.graphics.newShader([[
    extern number pixel_size;
    extern vec2 screen_size;

    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec2 size = screen_size / pixel_size;
        vec2 pixelated = floor(tc * size) / size;
        return Texel(tex, pixelated) * color;
    }
]])

-- Glow/Bloom (simple)
Shaders.glow = love.graphics.newShader([[
    extern number intensity;
    extern vec2 direction;

    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 sum = vec4(0.0);
        vec2 blur = direction / love_ScreenSize.xy;

        sum += Texel(tex, tc - 4.0 * blur) * 0.05;
        sum += Texel(tex, tc - 3.0 * blur) * 0.09;
        sum += Texel(tex, tc - 2.0 * blur) * 0.12;
        sum += Texel(tex, tc - 1.0 * blur) * 0.15;
        sum += Texel(tex, tc) * 0.18;
        sum += Texel(tex, tc + 1.0 * blur) * 0.15;
        sum += Texel(tex, tc + 2.0 * blur) * 0.12;
        sum += Texel(tex, tc + 3.0 * blur) * 0.09;
        sum += Texel(tex, tc + 4.0 * blur) * 0.05;

        return mix(Texel(tex, tc), sum, intensity) * color;
    }
]])

-- Wave/Distortion
Shaders.wave = love.graphics.newShader([[
    extern number time;
    extern number amplitude;
    extern number frequency;

    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec2 distorted = tc;
        distorted.x += sin(tc.y * frequency + time) * amplitude;
        distorted.y += cos(tc.x * frequency + time) * amplitude * 0.5;
        return Texel(tex, distorted) * color;
    }
]])

-- Flash/Damage effect
Shaders.flash = love.graphics.newShader([[
    extern vec4 flash_color;
    extern number flash_amount;

    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 pixel = Texel(tex, tc);
        return mix(pixel, flash_color, flash_amount) * color;
    }
]])

-- Desaturate
Shaders.desaturate = love.graphics.newShader([[
    extern number amount;

    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 pixel = Texel(tex, tc);
        float gray = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
        return vec4(mix(pixel.rgb, vec3(gray), amount), pixel.a) * color;
    }
]])

return Shaders
```

### 3.2: Use Shaders in Games

```lua
local Shaders = require('src.utils.shaders')

function MyGame:init(...)
    -- ... existing init ...

    -- Create canvas for post-processing
    self.canvas = love.graphics.newCanvas()

    -- Shader settings
    self.use_crt = self.params.crt_effect or false
    self.damage_flash = 0
end

function MyGame:draw()
    -- Draw to canvas
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear()

    -- Normal drawing
    self.view:draw()

    love.graphics.setCanvas()

    -- Apply post-processing
    if self.damage_flash > 0 then
        Shaders.flash:send("flash_color", {1, 0, 0, 1})
        Shaders.flash:send("flash_amount", self.damage_flash)
        love.graphics.setShader(Shaders.flash)
    elseif self.use_crt then
        Shaders.crt:send("time", love.timer.getTime())
        Shaders.crt:send("screen_size", {love.graphics.getDimensions()})
        love.graphics.setShader(Shaders.crt)
    end

    love.graphics.draw(self.canvas)
    love.graphics.setShader()
end

function MyGame:onDamage()
    self.damage_flash = 0.5  -- Start flash
end

function MyGame:updateGameLogic(dt)
    -- ... existing update ...

    -- Decay damage flash
    if self.damage_flash > 0 then
        self.damage_flash = self.damage_flash - dt * 3
    end
end
```

---

## Part 4: Motion and Trails

### 4.1: Add Trail Renderer

```lua
-- In visual_effects.lua or new file

function VisualEffects:initTrail(max_points)
    self.trail = {
        points = {},
        max_points = max_points or 20,
        color = {1, 1, 1, 0.5},
        width = 4
    }
end

function VisualEffects:updateTrail(x, y)
    if not self.trail then return end

    table.insert(self.trail.points, 1, {x = x, y = y})

    while #self.trail.points > self.trail.max_points do
        table.remove(self.trail.points)
    end
end

function VisualEffects:drawTrail()
    if not self.trail or #self.trail.points < 2 then return end

    for i = 1, #self.trail.points - 1 do
        local p1 = self.trail.points[i]
        local p2 = self.trail.points[i + 1]

        local alpha = 1 - (i / #self.trail.points)
        local width = self.trail.width * (1 - i / #self.trail.points)

        love.graphics.setColor(
            self.trail.color[1],
            self.trail.color[2],
            self.trail.color[3],
            self.trail.color[4] * alpha
        )
        love.graphics.setLineWidth(width)
        love.graphics.line(p1.x, p1.y, p2.x, p2.y)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function VisualEffects:clearTrail()
    if self.trail then
        self.trail.points = {}
    end
end
```

---

## Part 5: Quick Wins for Existing Games

Here are specific improvements for each game type:

### Snake
- Trail behind snake head
- Particles when eating food
- Screen shake on death
- Pulsing food item
- Color gradient along snake body

### Space Shooter
- Bullet trails
- Explosion particles on enemy death
- Engine exhaust particles
- Screen shake on damage
- Flash white when hit

### Breakout
- Ball trail
- Brick break particles
- Screen shake on brick break
- Paddle hit "punch" effect

### Coin Flip
- Coin spin blur effect
- Confetti on streak milestones
- Screen flash on win/lose
- Floating score numbers

### Raycaster
- Head bob while moving
- Damage vignette effect
- Goal item glow/pulse
- Fog/distance fade

---

## Schema Parameters for Effects

Add to game schemas:

```json
{
  "effects": {
    "type": "group",
    "properties": {
      "particles_enabled": {"type": "boolean", "default": true},
      "screen_shake_enabled": {"type": "boolean", "default": true},
      "screen_shake_intensity": {"type": "number", "default": 1.0},
      "trails_enabled": {"type": "boolean", "default": false},
      "crt_effect": {"type": "boolean", "default": false},
      "color_palette": {"type": "string", "default": "analogous",
        "enum": ["analogous", "complementary", "triadic", "neon", "pastel", "dark"]}
    }
  }
}
```

---

## Testing Checklist

- [ ] Particles emit and animate correctly
- [ ] Screen shake feels impactful, not annoying
- [ ] Hitstop adds impact to hits
- [ ] Colors generate consistently from seed
- [ ] Shaders don't break on different GPUs (test without them)
- [ ] Effects can be disabled in settings
- [ ] Frame rate stays stable with effects

---

## Common Issues

| Problem | Solution |
|---------|----------|
| Particles don't appear | Check particle system created, check emit called |
| Shader error | Check GLSL syntax, send all extern variables |
| Colors look wrong | Check HSL conversion, check color range 0-1 |
| Effects too intense | Add config options, reduce values |
| FPS drops | Reduce particle count, simplify shaders |

---

## Key Patterns Learned

- **Juice layers:** Particles + shake + flash + sound = impact
- **Seeded generation:** Deterministic from variant for consistency
- **Post-processing:** Canvas + shader for full-screen effects
- **Modular effects:** Enable/disable per variant
- **Performance awareness:** Effects should be optional
