# Game Improvement Plan

**Focus Shift**: Moving from OS infrastructure to game content and polish
**Goal**: Transform placeholder minigames into unique, polished experiences with distinct visual/audio identities

---

## Overview

The OS foundation is solid. It's time to make the games actually feel like games. Right now, clones are mechanically identical with no distinguishing features, and everything uses Win98 placeholder icons. This plan tackles:

1. **Clone differentiation** - Each clone should feel unique (sprites, audio, difficulty curves, enemies)
2. **Graphics overhaul** - Replace placeholder art with actual game assets
3. **Audio implementation** - Music, SFX, themeable sound packs
4. **Attribution tracking** - Legal/ethical asset management from day one

**Priority Order**: Minigames → Standalones (Space Defender, Solitaire) → OS elements

---

## Phase 0: Asset Attribution System ⚠️ DO THIS FIRST

**Duration**: 2-3 days
**Why First**: Must have attribution tracking BEFORE adding any assets

### Deliverables

1. **Attribution Data File** (`assets/data/attribution.json`)
   - Track every asset: sprite sheets, music, SFX, fonts
   - Fields: `asset_path`, `author`, `license`, `source_url`, `modifications`, `date_added`
   - Support batch entries (e.g., entire sprite packs)

2. **Attribution Manager** (`src/utils/attribution_manager.lua`)
   - Load/validate attribution data
   - Query system: get credits for specific asset or all assets
   - Validation: warn if assets exist without attribution

3. **Credits Screen** (in-game)
   - Accessible from Settings or main menu
   - Auto-generated from `attribution.json`
   - Categorized: Graphics, Audio, Fonts, Libraries
   - Scrollable list with license info

4. **Developer Tools**
   - `scripts/validate_attribution.lua` - Check for missing attributions
   - Run as pre-commit hook or manual check
   - Flag any asset file without corresponding entry

### Technical Notes

- Attribution data injected via DI to relevant systems
- SpriteLoader, AudioManager query attribution on load (debug mode only)
- Empty `attribution.json` initially - populate as assets are added

---

## Phase 1: Clone Customization System

**Duration**: 5-7 days
**Goal**: Architecture to support clone variations without code duplication

### 1.1: Clone Variant Data Schema

**Update**: `assets/data/base_game_definitions.json`

Add `clone_variants` array to each base game definition:

```json
{
  "id": "dodge_base",
  "clone_variants": [
    {
      "clone_index": 0,
      "name": "Dodge Master",
      "sprite_set": "dodge_base_1",
      "palette": "blue",
      "music_track": "dodge_theme_1",
      "sfx_pack": "retro_beeps",
      "background": "starfield_blue",
      "difficulty_modifier": 1.0,
      "enemies": [],
      "flavor_text": "Classic obstacle avoidance!",
      "intro_cutscene": null
    },
    {
      "clone_index": 1,
      "name": "Dodge Deluxe",
      "sprite_set": "dodge_base_1",
      "palette": "red",
      "music_track": "dodge_theme_2",
      "sfx_pack": "retro_beeps",
      "background": "starfield_red",
      "difficulty_modifier": 1.2,
      "enemies": [
        { "type": "chaser", "multiplier": 1.0 },
        { "type": "shooter", "multiplier": 0.5 }
      ],
      "flavor_text": "Now with aggressive enemies!",
      "intro_cutscene": "dodge_deluxe_intro"
    },
    {
      "clone_index": 2,
      "name": "Dodge Chaos",
      "sprite_set": "dodge_base_1",
      "palette": "purple",
      "music_track": "dodge_theme_3",
      "sfx_pack": "retro_beeps",
      "background": "starfield_purple",
      "difficulty_modifier": 1.5,
      "enemies": [
        { "type": "chaser", "multiplier": 3.0 },
        { "type": "shooter", "multiplier": 1.0 },
        { "type": "bouncer", "multiplier": 2.0 },
        { "type": "zigzag", "multiplier": 1.5 }
      ],
      "flavor_text": "Absolute mayhem!",
      "intro_cutscene": null
    },
    {
      "clone_index": 3,
      "name": "Dodge Elite",
      "sprite_set": "dodge_base_2",
      "palette": "green",
      "music_track": "dodge_theme_1",
      "sfx_pack": "8bit_arcade",
      "background": "starfield_green",
      "difficulty_modifier": 1.8,
      "enemies": [
        { "type": "teleporter", "multiplier": 2.0 }
      ],
      "flavor_text": "They teleport now?!",
      "intro_cutscene": null
    }
  ]
}
```

**Fields**:
- `sprite_set`: References base sprite pack in `assets/sprites/games/{game_type}/{sprite_set}/`
  - Multiple variants can share the same sprite_set and use different palettes
  - Example: `dodge_base_1` used by variants 0, 1, 2 with different palettes
- `palette`: Palette ID for color swapping (see Section 1.6: Palette Swapping System)
  - References palette definition in `assets/data/palettes.json`
  - Allows 10+ visual variants from just 1-4 base sprite sets
- `music_track`: References audio file in `assets/audio/music/`
- `sfx_pack`: References SFX collection in `assets/data/sfx_packs.json`
- `background`: Background sprite/shader identifier
- `difficulty_modifier`: Multiplier on base difficulty formula
- `enemies`: Array of enemy compositions. Each entry specifies:
  - `type`: Enemy class identifier (chaser, shooter, bouncer, zigzag, etc.)
  - `multiplier`: Spawn rate/count multiplier (1.0 = base, 3.0 = 3x as many)
  - Empty array `[]` = no enemies in this variant
- `flavor_text`: Shown in launcher description
- `intro_cutscene`: Optional cutscene ID before game starts

**Enemy System Benefits**:
- **Mix and Match**: Variant A has chasers+shooters, Variant B has bouncers+zigzags
- **Quantity Control**: 3x chasers makes a swarm, 0.5x shooters makes them rare
- **Combinatorial Variety**: With 5 enemy types and varying multipliers, create dozens of unique compositions
- **Progressive Difficulty**: Early clones have simple enemy sets, later clones combine multiple types with high multipliers
- **Empty Array Support**: Variants with `"enemies": []` have no enemies at all (pure obstacle avoidance)

### 1.2: Variant Loading System

**New**: `src/models/game_variant_loader.lua`

```lua
function GameVariantLoader:getVariantData(game_id)
    -- Parse game_id to extract base type and clone index
    -- Load corresponding variant from base_game_definitions.json
    -- Return variant config or fallback to default
end
```

**Update**: `BaseGame:init(di, game_id, variant_data)`
- Accept `variant_data` parameter
- Store variant config: `self.variant = variant_data`
- Subclasses read `self.variant.sprite_set`, `self.variant.music_track`, etc.

### 1.3: Game Class Refactor

**Update**: Each game class (`dodge_game.lua`, `hidden_object_game.lua`, etc.)

- Remove hardcoded sprites/audio references
- Read from `self.variant.sprite_set`, `self.variant.music_track`
- Parse `self.variant.enemies` array to spawn enemy compositions
- Use multipliers to control spawn rates/counts per enemy type

**Pattern**:
```lua
function DodgeGame:loadAssets()
    local sprite_path = string.format("assets/sprites/games/dodge/%s/", self.variant.sprite_set)
    self.playerSprite = SpriteLoader:load(sprite_path .. "player.png")
    self.obstacleSprite = SpriteLoader:load(sprite_path .. "obstacle.png")

    -- Load enemy sprites based on variant composition
    self.enemySprites = {}
    for _, enemy_def in ipairs(self.variant.enemies) do
        local enemy_sprite = SpriteLoader:load(sprite_path .. "enemy_" .. enemy_def.type .. ".png")
        self.enemySprites[enemy_def.type] = enemy_sprite
    end

    if self.variant.music_track then
        self.music = AudioManager:loadMusic(self.variant.music_track)
    end
end

function DodgeGame:spawnEnemyWave()
    -- Spawn enemies based on variant composition
    for _, enemy_def in ipairs(self.variant.enemies) do
        local base_count = self:calculateBaseEnemyCount(enemy_def.type)
        local actual_count = math.floor(base_count * enemy_def.multiplier)

        for i = 1, actual_count do
            self:spawnEnemy(enemy_def.type)
        end
    end
end
```

### 1.4: Enemy Type Definitions

**New/Update**: Define enemy behaviors in each game class

Each game should implement a variety of enemy types that variants can compose from. These are NOT tied to specific variants - variants just reference them.

**Example Enemy Types for Dodge Game**:
- `chaser` - Homes in on player position
- `shooter` - Fires projectiles at player
- `bouncer` - Bounces off walls in predictable patterns
- `zigzag` - Moves in zigzag pattern across screen
- `teleporter` - Disappears and reappears near player

**Example Enemy Types for Space Shooter**:
- `basic` - Simple downward movement
- `weaver` - Sine wave pattern
- `bomber` - Drops bombs periodically
- `kamikaze` - Dives directly at player
- `spawner` - Releases smaller enemies

**Implementation Pattern**:
```lua
-- In dodge_game.lua or similar
DodgeGame.ENEMY_TYPES = {
    chaser = {
        speed = 100,
        health = 1,
        behavior = "seek_player",
        sprite_name = "enemy_chaser.png"
    },
    shooter = {
        speed = 50,
        health = 2,
        behavior = "shoot_at_player",
        shoot_interval = 2.0,
        sprite_name = "enemy_shooter.png"
    },
    -- etc...
}

function DodgeGame:spawnEnemy(enemy_type)
    local enemy_def = self.ENEMY_TYPES[enemy_type]
    -- Create enemy instance with these properties
    -- Use sprite from variant sprite_set folder
end
```

**Why Separate Definitions from Variants?**:
- Variants compose from a shared pool of enemy types
- Adding new enemy types benefits all variants
- Easy to extend without modifying existing variant data
- Games can share enemy behavior patterns

### 1.5: Launcher Integration

**Update**: `launcher_view.lua`
- Display `variant.flavor_text` in game description
- Show variant name (`variant.name`) instead of generic "Dodge Clone 3"

**Update**: `game_data.lua`
- When cloning, assign next available variant from definitions
- Fallback: if more clones than variants, cycle through or use procedural variation

### 1.6: Palette Swapping System

**Duration**: 2-3 days (part of Phase 1)
**Goal**: Multiply visual variety without creating dozens of sprite sets

**Key Benefit**: Create 40 variants with just 4 base sprite sets × 10 palettes, or 100 variants with 10 sprite sets × 10 palettes!

#### Palette Definition File

**New**: `assets/data/palettes.json`

```json
{
  "blue": {
    "name": "Blue Classic",
    "swaps": [
      { "from": [255, 0, 0], "to": [0, 100, 255] },
      { "from": [200, 0, 0], "to": [0, 70, 200] },
      { "from": [150, 0, 0], "to": [0, 50, 150] },
      { "from": [255, 255, 0], "to": [150, 200, 255] }
    ]
  },
  "red": {
    "name": "Red Danger",
    "swaps": [
      { "from": [255, 0, 0], "to": [255, 50, 50] },
      { "from": [200, 0, 0], "to": [200, 30, 30] },
      { "from": [150, 0, 0], "to": [150, 20, 20] },
      { "from": [255, 255, 0], "to": [255, 150, 0] }
    ]
  },
  "purple": {
    "name": "Purple Chaos",
    "swaps": [
      { "from": [255, 0, 0], "to": [200, 0, 255] },
      { "from": [200, 0, 0], "to": [150, 0, 200] },
      { "from": [150, 0, 0], "to": [100, 0, 150] },
      { "from": [255, 255, 0], "to": [255, 100, 255] }
    ]
  },
  "green": {
    "name": "Green Elite",
    "swaps": [
      { "from": [255, 0, 0], "to": [0, 255, 50] },
      { "from": [200, 0, 0], "to": [0, 200, 30] },
      { "from": [150, 0, 0], "to": [0, 150, 20] },
      { "from": [255, 255, 0], "to": [150, 255, 0] }
    ]
  }
}
```

**How It Works**:
- Base sprites use a "canonical" palette (e.g., red tones + yellow accents)
- Palette definitions map those canonical colors to new colors
- All variants using the same base sprites just need different palette IDs

**Creating Base Sprites**:
1. Design sprites using a clear, distinct base palette
2. Use colors that are easy to identify for swapping (e.g., pure red [255,0,0], pure yellow [255,255,0])
3. Include multiple shades (dark red, medium red, bright red) for depth
4. Save as PNG with exact RGB values

#### Palette Swapping Implementation

**Option 1: Shader-Based (Recommended)**

**New/Update**: `assets/shaders/palette_swap.glsl`

```glsl
// Vertex shader
#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    return transform_projection * vertex_position;
}
#endif

// Fragment shader
#ifdef PIXEL
uniform vec3 colorFrom[8];  // Max 8 color swaps
uniform vec3 colorTo[8];
uniform int swapCount;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords);

    // Skip fully transparent pixels
    if (pixel.a == 0.0) {
        return pixel;
    }

    // Check each color swap
    for (int i = 0; i < swapCount; i++) {
        vec3 pixelRGB = pixel.rgb * 255.0;
        vec3 fromRGB = colorFrom[i];

        // Check if colors match (with small tolerance for compression artifacts)
        float diff = length(pixelRGB - fromRGB);
        if (diff < 5.0) {
            pixel.rgb = colorTo[i] / 255.0;
            break;
        }
    }

    return pixel * color;
}
#endif
```

**Update/Create**: `src/utils/palette_manager.lua` (you mentioned having a basic one)

```lua
local PaletteManager = {}

function PaletteManager:init(di)
    self.di = di
    self.palettes = self:loadPalettes()
    self.shader = love.graphics.newShader("assets/shaders/palette_swap.glsl")
end

function PaletteManager:loadPalettes()
    local success, data = pcall(function()
        local content = love.filesystem.read("assets/data/palettes.json")
        return json.decode(content)
    end)

    if not success or not data then
        print("Failed to load palettes.json: " .. tostring(data))
        return {}
    end

    return data
end

function PaletteManager:applyPalette(palette_id)
    local palette = self.palettes[palette_id]
    if not palette then
        print("Palette not found: " .. tostring(palette_id))
        return
    end

    local swaps = palette.swaps
    local colorFrom = {}
    local colorTo = {}

    for i, swap in ipairs(swaps) do
        colorFrom[i] = swap.from
        colorTo[i] = swap.to
    end

    self.shader:send("swapCount", #swaps)
    self.shader:send("colorFrom", unpack(colorFrom))
    self.shader:send("colorTo", unpack(colorTo))

    love.graphics.setShader(self.shader)
end

function PaletteManager:clearPalette()
    love.graphics.setShader()
end

return PaletteManager
```

**Usage in Game Classes**:

```lua
function DodgeGame:draw()
    -- Apply palette for all sprites in this variant
    self.di.paletteManager:applyPalette(self.variant.palette)

    -- Draw all game sprites (they'll be palette-swapped automatically)
    love.graphics.draw(self.playerSprite, self.player.x, self.player.y)

    for _, obstacle in ipairs(self.obstacles) do
        love.graphics.draw(self.obstacleSprite, obstacle.x, obstacle.y)
    end

    for _, enemy in ipairs(self.enemies) do
        love.graphics.draw(self.enemySprites[enemy.type], enemy.x, enemy.y)
    end

    -- Clear palette after drawing this game's sprites
    self.di.paletteManager:clearPalette()

    -- Draw UI elements without palette swap
    self:drawUI()
end
```

#### Asset Requirements with Palette Swapping

**Before Palette Swapping**:
- 40 variants = 40 unique sprite sets
- Massive art workload

**After Palette Swapping**:
- 40 variants = 4-10 base sprite sets × 4-10 palettes
- **90% reduction in unique art needed!**

**Example Distribution**:
- **Dodge Game**: 3 base sprite sets, 8 palettes = 24 possible variants
- **Hidden Object**: 5 scene backgrounds, 6 palettes = 30 possible variants
- **Memory Match**: 4 card designs, 10 palettes = 40 possible variants
- **Snake**: 2 sprite sets, 10 palettes = 20 possible variants
- **Space Shooter**: 3 ship designs, 8 palettes = 24 possible variants

#### Creating Effective Palettes

**Best Practices**:

1. **Use Distinct Base Colors**:
   - Primary color (e.g., red for player)
   - Secondary color (e.g., yellow for accents)
   - 2-3 shades of each for depth

2. **Design Complementary Swaps**:
   - Blue variant: Cool tones
   - Red variant: Warm tones
   - Purple variant: Royal tones
   - Green variant: Natural tones

3. **Maintain Contrast**:
   - If base has dark red + bright yellow, swaps should have similar contrast
   - Don't swap dark red → dark blue + bright yellow → dark green (loses contrast)

4. **Test on All Sprites**:
   - Palette should work on player, enemies, obstacles, effects
   - Some colors might need adjustment if they don't swap well

5. **Use Exact RGB Values**:
   - Save palettes with specific colors: [255,0,0], not [254,1,0]
   - Use color picker to ensure consistency
   - Avoid gradients in base sprites (hard to swap cleanly)

#### Alternative: Pre-Generated Palette Swaps

If shader approach has performance issues or you need per-sprite palettes:

**Option 2: Generate Swapped Images at Load Time**

```lua
function PaletteManager:createSwappedImage(original_image, palette_id)
    local palette = self.palettes[palette_id]
    if not palette then return original_image end

    local imageData = original_image:getData()
    local width, height = imageData:getDimensions()

    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local r, g, b, a = imageData:getPixel(x, y)

            if a > 0 then
                local pixelColor = {r * 255, g * 255, b * 255}

                for _, swap in ipairs(palette.swaps) do
                    if self:colorsMatch(pixelColor, swap.from) then
                        imageData:setPixel(x, y,
                            swap.to[1] / 255,
                            swap.to[2] / 255,
                            swap.to[3] / 255,
                            a
                        )
                        break
                    end
                end
            end
        end
    end

    return love.graphics.newImage(imageData)
end

function PaletteManager:colorsMatch(c1, c2, tolerance)
    tolerance = tolerance or 5
    local dr = math.abs(c1[1] - c2[1])
    local dg = math.abs(c1[2] - c2[2])
    local db = math.abs(c1[3] - c2[3])
    return dr < tolerance and dg < tolerance and db < tolerance
end
```

**Pros**: More control, can cache swapped images, no shader complexity
**Cons**: Higher memory usage, longer load times

#### Integration with Variant System

**Update**: Game asset loading

```lua
function DodgeGame:loadAssets()
    local sprite_path = string.format("assets/sprites/games/dodge/%s/", self.variant.sprite_set)

    -- Load base sprites
    self.playerSprite = SpriteLoader:load(sprite_path .. "player.png")
    self.obstacleSprite = SpriteLoader:load(sprite_path .. "obstacle.png")

    -- Load enemy sprites
    self.enemySprites = {}
    for _, enemy_def in ipairs(self.variant.enemies) do
        local enemy_sprite = SpriteLoader:load(sprite_path .. "enemy_" .. enemy_def.type .. ".png")
        self.enemySprites[enemy_def.type] = enemy_sprite
    end

    -- Store palette ID for use in draw()
    self.paletteId = self.variant.palette

    if self.variant.music_track then
        self.music = AudioManager:loadMusic(self.variant.music_track)
    end
end

function DodgeGame:draw()
    -- Apply palette and draw everything
    if self.paletteId then
        self.di.paletteManager:applyPalette(self.paletteId)
    end

    -- ... drawing code ...

    if self.paletteId then
        self.di.paletteManager:clearPalette()
    end
end
```

#### Debugging Palette Swaps

**Add Debug Visualization** (F5 debug mode):

```lua
function DebugState:drawPaletteInfo()
    if not self.currentGame then return end

    local palette_id = self.currentGame.paletteId
    local palette = PaletteManager.palettes[palette_id]

    if palette then
        love.graphics.print("Palette: " .. palette.name, 10, 100)

        -- Draw color swaps
        for i, swap in ipairs(palette.swaps) do
            local y = 120 + (i - 1) * 20

            -- Draw "from" color
            love.graphics.setColor(swap.from[1]/255, swap.from[2]/255, swap.from[3]/255)
            love.graphics.rectangle("fill", 10, y, 30, 15)

            love.graphics.setColor(1, 1, 1)
            love.graphics.print("→", 45, y)

            -- Draw "to" color
            love.graphics.setColor(swap.to[1]/255, swap.to[2]/255, swap.to[3]/255)
            love.graphics.rectangle("fill", 65, y, 30, 15)

            love.graphics.setColor(1, 1, 1)
        end
    end
end
```

#### Migration Path

Since you have an existing basic palette system:

1. **Evaluate existing system**: Does it use shaders or image manipulation?
2. **Test with current codebase**: Check if it still works with current LÖVE version
3. **Decide on approach**: Shader (fast, low memory) vs ImageData (flexible, higher memory)
4. **Refactor into DI**: Convert to injectable PaletteManager
5. **Integrate with variant system**: Add palette field to variant definitions
6. **Create palette definitions**: Build `palettes.json` with initial color schemes

---

## Phase 2: Minigame Graphics Overhaul

**Duration**: 10-14 days
**Goal**: Replace all placeholder graphics with actual game assets

**IMPORTANT**: With palette swapping, we only need 2-5 base sprite sets per game type, not one per variant!

### 2.1: Asset Organization

**New Directories**:
```
assets/sprites/games/
├── dodge/
│   ├── base_1/              # First sprite set (can support 10+ variants via palettes)
│   │   ├── player.png
│   │   ├── obstacle.png
│   │   ├── enemy_chaser.png
│   │   ├── enemy_shooter.png
│   │   ├── enemy_bouncer.png
│   │   └── background.png
│   ├── base_2/              # Second sprite set (different art style)
│   │   ├── player.png
│   │   ├── obstacle.png
│   │   ├── enemy_teleporter.png
│   │   └── background.png
│   └── base_3/              # Third sprite set (optional)
├── hidden_object/
│   ├── forest/              # Base scene 1
│   ├── mansion/             # Base scene 2
│   ├── beach/               # Base scene 3
│   └── ...
├── memory_match/
│   ├── icons_1/             # First card design set
│   ├── icons_2/             # Second card design set
│   └── ...
├── snake/
│   ├── classic/             # Traditional snake look
│   └── modern/              # Modern snake look
└── space_shooter/
    ├── fighter_1/
    ├── fighter_2/
    └── ...
```

**Naming Convention**: `{game_type}/{base_sprite_set}/{asset_name}.png`

**Palette Swapping Strategy**:
- Each base sprite set designed with canonical palette (e.g., red + yellow)
- 8-10 palette definitions in `palettes.json`
- Variants reference: sprite set + palette ID
- Example: 3 sprite sets × 10 palettes = 30 unique-looking variants!

### 2.2: Sprite Requirements per Base Sprite Set

**Note**: These are requirements PER BASE SPRITE SET. Each game needs 2-5 base sets total, not one per variant.

**Dodge Game** (per base set):
- Player sprite (16x16 or 32x32, animated optional)
  - Use canonical palette: red body + yellow accents
- Obstacle sprites (3-5 variations)
  - Primary color for easy palette swapping
- Enemy sprites (all types this sprite set supports)
  - `enemy_chaser.png` - Simple red circle/shape
  - `enemy_shooter.png` - Red with gun/turret
  - `enemy_bouncer.png` - Angular red shape
  - `enemy_zigzag.png` - Streamlined red shape
  - `enemy_teleporter.png` - Particle-like red shape
- Background (tileable starfield or solid color)
  - Keep neutral or complementary to allow palette swaps to shine
- Particle effects (optional, death/boost)

**Hidden Object** (per base scene):
- Scene background (640x480 or larger)
  - NOTE: These are harder to palette-swap effectively
  - Consider having 5+ unique scenes without palettes, OR
  - Design scenes with limited colors for swapping (stylized/flat)
- Object sprites (20-30 small items)
  - Simple shapes with 2-3 main colors for swapping
- UI elements can be shared across scenes

**Memory Match** (per base card design):
- Card back design (1 design, palette-swappable)
- Card face icons (12-24 unique icons)
  - Icons should use simple, bold colors for palette swapping
  - Examples: animals, shapes, symbols
- Match/mismatch feedback (shared across all sets)

**Snake** (per base set):
- Snake head (4 directions) - Use canonical green
- Snake body segment - Green
- Snake tail (4 directions) - Green
- Food/apple sprites - Use red (will palette-swap to different fruit colors)
- Grid background or border tiles - Neutral colors

**Space Shooter** (per base set, minigame not Space Defender):
- Player ship (16x16 or 32x32) - Canonical blue/red
- Enemy ships (3-5 types) - Distinct shapes, single primary color each
- Bullet sprites (player and enemy) - Simple shapes with primary color
- Power-up icons - Bold colors for swapping
- Explosion sprite sheet - Yellow/orange/red gradient (swaps to other color schemes)
- Scrolling space background - Neutral or complementary

**Target Numbers**:
- **Dodge**: 3 base sprite sets (bare minimum: 1)
- **Hidden Object**: 5 unique scenes (harder to palette-swap)
- **Memory Match**: 4 card design sets
- **Snake**: 2 base sets (classic, modern)
- **Space Shooter**: 3 base sets (different ship designs)

### 2.3: Sprite Loading Integration

**Update**: `SpriteLoader` or create `GameAssetLoader`
- Load sprite sets based on `variant.sprite_set`
- Integrate with PaletteManager for palette-swapped rendering
- Support sprite sheets with quad definitions
- Handle missing sprites gracefully (fallback to default)

**Update**: Each game's `loadAssets()` method
- Load base sprite set from `variant.sprite_set`
- Store `variant.palette` for use during rendering
- Load all required sprites from base set
- Set up animations if needed

**Pattern**:
```lua
function DodgeGame:loadAssets()
    local base_path = "assets/sprites/games/dodge/" .. self.variant.sprite_set .. "/"

    -- Load base sprites (will be palette-swapped at render time)
    self.playerSprite = self.di.spriteLoader:load(base_path .. "player.png")
    self.obstacleSprite = self.di.spriteLoader:load(base_path .. "obstacle.png")

    -- Load enemy sprites based on enemy composition
    self.enemySprites = {}
    for _, enemy_def in ipairs(self.variant.enemies) do
        self.enemySprites[enemy_def.type] =
            self.di.spriteLoader:load(base_path .. "enemy_" .. enemy_def.type .. ".png")
    end

    -- Store palette ID for rendering
    self.paletteId = self.variant.palette
end
```

### 2.4: Icon Overhaul

**Replace**: Win98 placeholder icons in `assets/sprites/icons/games/`
- Create unique 32x32 icons for each BASE game (not every clone)
- Clones can share base icon or use variant-specific icon
- Add to attribution.json as created

---

## Phase 3: Minigame Audio Overhaul

**Duration**: 7-10 days
**Goal**: Music, SFX, and themeable audio system

### 3.1: Audio Asset Organization

**New Directories**:
```
assets/audio/
├── music/
│   ├── minigames/
│   │   ├── dodge_theme_1.ogg
│   │   ├── dodge_theme_2.ogg
│   │   ├── hidden_object_ambient_forest.ogg
│   │   └── ...
│   ├── standalones/
│   │   ├── space_defender_level_1.ogg
│   │   └── solitaire_calm.ogg
│   └── os/
│       ├── desktop_theme_default.ogg
│       └── startup.ogg
├── sfx/
│   ├── packs/
│   │   ├── retro_beeps/      # SFX pack 1
│   │   │   ├── jump.ogg
│   │   │   ├── hit.ogg
│   │   │   └── collect.ogg
│   │   ├── modern_ui/        # SFX pack 2
│   │   └── 8bit_arcade/      # SFX pack 3
│   └── os/
│       ├── window_open.ogg
│       ├── error.ogg
│       └── ...
└── data/
    └── sfx_packs.json        # Defines SFX pack mappings
```

### 3.2: SFX Pack System

**New**: `assets/data/sfx_packs.json`

```json
{
  "retro_beeps": {
    "name": "Retro Beeps",
    "description": "Classic 8-bit style sound effects",
    "sounds": {
      "jump": "assets/audio/sfx/packs/retro_beeps/jump.ogg",
      "hit": "assets/audio/sfx/packs/retro_beeps/hit.ogg",
      "collect": "assets/audio/sfx/packs/retro_beeps/collect.ogg",
      "death": "assets/audio/sfx/packs/retro_beeps/death.ogg",
      "success": "assets/audio/sfx/packs/retro_beeps/success.ogg"
    }
  },
  "modern_ui": {
    "name": "Modern UI",
    "sounds": { ... }
  }
}
```

**New**: `src/utils/audio_manager.lua` (or extend existing)

```lua
function AudioManager:loadSFXPack(pack_name)
    -- Load all sounds from specified pack
    -- Return table of Sound objects keyed by action name
end

function AudioManager:playSound(pack_name, sound_key, volume)
    -- Play specific sound from pack
end
```

### 3.3: Game Audio Integration

**Update**: Each game class
- Load music track from `self.variant.music_track`
- Load SFX pack from `self.variant.sfx_pack`
- Play appropriate sounds on game events:
  - Player jump/move
  - Collision/damage
  - Collect item
  - Win/lose
  - Special events (power-up, enemy spawn, etc.)

**Pattern**:
```lua
function DodgeGame:init(di, game_id, variant_data)
    self.music = di.audioManager:loadMusic(variant_data.music_track)
    self.sfx = di.audioManager:loadSFXPack(variant_data.sfx_pack)
end

function DodgeGame:onCollision()
    di.audioManager:playSound(self.variant.sfx_pack, "hit", 0.7)
end
```

### 3.4: Music Requirements

**Per Game Type**:
- 2-3 looping background tracks per base game
- Variants use different tracks to differentiate
- 30-60 seconds loop length
- OGG format, ~128kbps

**Genres**:
- Dodge: Upbeat electronic, tense
- Hidden Object: Ambient, mysterious
- Memory Match: Calm, focused
- Snake: Retro chiptune
- Space Shooter: Fast-paced action

### 3.5: SFX Requirements

**Universal Game Sounds** (needed by most games):
- `hit` - Player takes damage
- `death` - Player loses
- `success` - Level complete
- `collect` - Pick up item
- `select` - Menu/UI interaction

**Game-Specific**:
- Dodge: `dodge`, `boost`
- Hidden Object: `find_object`, `wrong_click`
- Memory Match: `flip_card`, `match`, `mismatch`
- Snake: `eat`, `grow`, `turn`
- Space Shooter: `shoot`, `enemy_explode`

**Create 3 SFX packs initially**:
1. Retro Beeps (8-bit style)
2. Modern UI (clean, polished)
3. Arcade (energetic, punchy)

---

## Phase 4: Standalone Game Polish

**Duration**: 8-10 days
**Goal**: Apply graphics/audio overhaul to Space Defender and Solitaire

### 4.1: Space Defender Graphics

**Assets Needed**:
- Player ship sprite (upgradable appearance?)
- Enemy ships per level tier (5+ types)
- Boss sprites (5 unique bosses for levels 5, 10, 15, 20, 25)
- Bullet sprites (player, enemy, boss patterns)
- Power-up icons
- Explosion animations (small, medium, large)
- Background parallax layers (stars, nebula, planets)
- Level-specific backgrounds (color shifts per level)

**Asset Organization**:
```
assets/sprites/space_defender/
├── player/
│   ├── ship_base.png
│   ├── ship_upgraded_1.png
│   └── ...
├── enemies/
│   ├── tier_1_basic.png
│   ├── tier_2_fast.png
│   └── ...
├── bosses/
│   ├── boss_level_5.png
│   └── ...
├── bullets/
├── powerups/
├── explosions/
│   └── explosion_sheet.png
└── backgrounds/
    ├── level_1_bg.png
    └── ...
```

**Update**: `space_defender_game.lua`, `space_defender_view.lua`
- Replace placeholder shapes with sprites
- Add background layers with parallax scrolling
- Integrate explosion animations
- Add visual feedback for bullet power scaling

### 4.2: Space Defender Audio

**Music**:
- 5 music tracks (one per level tier: 1-5, 6-10, 11-15, 16-20, 21-25)
- Boss battle intensifies music or uses separate boss theme
- Victory jingle
- Defeat sound

**SFX**:
- Player shoot (varies by bullet power tier?)
- Enemy shoot
- Explosion (small, medium, large)
- Boss hurt
- Boss explode
- Power-up collect
- Player hit
- Shield activate
- Level complete

**Asset Organization**:
```
assets/audio/music/space_defender/
├── tier_1_theme.ogg
├── tier_2_theme.ogg
├── boss_battle.ogg
└── victory.ogg

assets/audio/sfx/space_defender/
├── player_shoot.ogg
├── enemy_explode.ogg
└── ...
```

### 4.3: Solitaire Graphics

**Assets Needed**:
- Card sprites (52 cards + back design)
- Multiple card back designs (unlockable/themeable)
- Table felt background (customizable colors)
- UI elements (new game button, hint button, etc.)
- Win animation (cards bouncing, confetti, etc.)

**Asset Organization**:
```
assets/sprites/solitaire/
├── cards/
│   ├── card_sheet.png          # All 52 cards in one sheet
│   ├── back_classic.png
│   ├── back_modern.png
│   └── ...
├── backgrounds/
│   ├── felt_green.png
│   ├── felt_blue.png
│   └── ...
└── ui/
    ├── hint_icon.png
    └── new_game_icon.png
```

**Update**: `solitaire_game.lua`, `solitaire_view.lua`
- Load card sprite sheet with quads
- Support switchable card backs (future theme system)
- Add win animation

### 4.4: Solitaire Audio

**Music**:
- 2-3 calm, ambient background tracks
- Randomize or let player choose

**SFX**:
- Card flip
- Card place (valid move)
- Card snap (invalid move)
- Deal cards
- Win jingle
- Hint chime

---

## Phase 5: OS Visual/Audio Overhaul

**Duration**: 10-12 days
**Goal**: Replace Win98 placeholders throughout OS interface

### 5.1: Desktop/Window Manager Graphics

**Assets Needed**:
- Window chrome elements (title bar, borders, buttons, resize handles)
- Taskbar background and buttons
- Start menu background and icons
- Desktop background (default + 3-5 additional wallpapers)
- Desktop icons (folders, programs, system icons)
- Cursor sprites (default, pointer, text, resize, busy, etc.)

**Asset Organization**:
```
assets/sprites/os/
├── window_chrome/
│   ├── title_bar.png
│   ├── close_button.png
│   ├── minimize_button.png
│   └── ...
├── desktop/
│   ├── wallpaper_default.png
│   ├── wallpaper_space.png
│   └── ...
├── taskbar/
│   ├── taskbar_bg.png
│   └── start_button.png
├── icons/
│   ├── folder.png
│   ├── file.png
│   ├── recycle_bin.png
│   └── programs/
│       ├── launcher.png
│       ├── vm_manager.png
│       └── ...
└── cursors/
    ├── default.png
    ├── pointer.png
    └── ...
```

**Update**:
- `window_chrome.lua` - Use new window graphics
- `desktop_view.lua` - Load wallpapers, icons
- `taskbar_view.lua` - New taskbar sprites
- `system_cursors.lua` - Load cursor pack

### 5.2: Program-Specific Graphics

**Per Program** (Launcher, VM Manager, File Explorer, Settings, etc.):
- Custom icons (32x32 for desktop, 16x16 for menus)
- Program-specific UI elements where needed
- Background/panel textures if thematic

**Examples**:
- **VM Manager**: Server rack or computer lab background
- **CheatEngine**: Hacker aesthetic (green terminal text, matrix vibes?)
- **File Explorer**: Folder icons, file type icons
- **Statistics**: Graph/chart icons

### 5.3: OS Audio

**Music**:
- Desktop ambient theme (subtle, non-intrusive, loopable)
- Startup jingle
- Shutdown jingle

**SFX**:
- Window open
- Window close
- Window minimize
- Window maximize
- Button click
- Dropdown open
- Error beep
- Notification chime
- Start menu open/close
- Desktop icon click
- File/folder operations (copy, delete, move)
- Recycle bin empty

**Asset Organization**:
```
assets/audio/os/
├── music/
│   ├── desktop_ambient.ogg
│   ├── startup.ogg
│   └── shutdown.ogg
└── sfx/
    ├── window_open.ogg
    ├── button_click.ogg
    ├── error.ogg
    └── ...
```

**Integration**:
- Use EventBus to trigger SFX on UI events
- Example: `EventBus:publish('WindowOpened')` → AudioManager plays `window_open.ogg`

---

## Phase 6: Theme System Implementation

**Duration**: 5-7 days
**Goal**: User-customizable audio/visual themes

### 6.1: Theme Data Structure

**New**: `assets/data/themes.json`

```json
{
  "default": {
    "name": "Classic",
    "description": "The original 10,000 Games look and feel",
    "os_sounds": {
      "window_open": "assets/audio/os/sfx/window_open.ogg",
      "button_click": "assets/audio/os/sfx/button_click.ogg",
      ...
    },
    "os_music": "assets/audio/os/music/desktop_ambient.ogg",
    "desktop_wallpaper": "assets/sprites/os/desktop/wallpaper_default.png",
    "window_chrome": "default",
    "cursor_pack": "default"
  },
  "dark_mode": {
    "name": "Dark Mode",
    "description": "Easy on the eyes",
    "os_sounds": { ... },
    ...
  },
  "retro": {
    "name": "Retro Arcade",
    "description": "8-bit nostalgia",
    ...
  }
}
```

### 6.2: Theme Manager

**New**: `src/utils/theme_manager.lua`

```lua
function ThemeManager:init(di)
    self.di = di
    self.themes = self:loadThemes()
    self.activeTheme = di.settingsManager:get('theme', 'default')
end

function ThemeManager:setTheme(theme_name)
    -- Load theme config
    -- Apply OS sounds, wallpaper, cursor pack
    -- Publish ThemeChanged event via EventBus
    -- Save to settings
end

function ThemeManager:getSound(sound_key)
    return self.themes[self.activeTheme].os_sounds[sound_key]
end
```

### 6.3: Integration

**Settings UI**:
- Add "Theme" dropdown in Settings program
- Preview theme before applying
- Show theme description

**EventBus Integration**:
- Subscribe to UI events: `WindowOpened`, `ButtonClicked`, etc.
- ThemeManager plays appropriate sound from active theme

**Update**: Audio system
- Check active theme when playing OS sounds
- Game sounds are per-variant, NOT themed (games keep their identity)

### 6.4: Future Expansion

**Unlockable Themes**:
- Earn themes by completing Space Defender levels
- Purchase with tokens
- Hidden themes (cheat codes, Easter eggs)

**Custom Themes**:
- Allow user-defined theme JSON files
- Load from user data directory
- Community theme sharing (future web integration?)

---

## Phase 7: Cutscenes and Narrative Elements (Optional)

**Duration**: 7-10 days
**Goal**: Add intro cutscenes, flavor text, and story beats

### 7.1: Cutscene System

**New**: `src/controllers/cutscene_controller.lua`

- Display dialogue boxes with character sprites
- Advance text with key presses or auto-advance
- Support branching (minimal - this is not a VN)
- Skippable cutscenes

**Data**: `assets/data/cutscenes.json`

```json
{
  "dodge_deluxe_intro": {
    "frames": [
      {
        "text": "The obstacles are getting smarter...",
        "character": "narrator",
        "duration": 3000
      },
      {
        "text": "Can you dodge them all?",
        "character": "narrator",
        "duration": 2000
      }
    ]
  }
}
```

### 7.2: Integration with Variants

- Game variants reference `intro_cutscene` or `outro_cutscene` by ID
- Cutscene plays before game starts or after win
- Add "Skip" button (bottom right)

### 7.3: Narrator System

**Optional Flavor**:
- Meta-commentary about shovelware
- Self-aware humor ("This is clone #47 of Dodge...")
- Breaks fourth wall occasionally

**Implementation**:
- Random narrator quips on game launch
- Stored in `strings/narrator.json`
- Pull random line based on context (game type, clone index, player performance)

---

## Phase 8: Procedural Variation (Stretch Goal)

**Duration**: 5-7 days (if time allows)
**Goal**: Generate infinite clones with procedural tweaks

### 8.1: Procedural Palette Swaps

When variants run out, procedurally generate:
- Hue-shifted sprites
- Randomized background colors
- Procedural enemy patterns

### 8.2: Difficulty Modifiers

- Randomize obstacle speed multipliers
- Randomize spawn rates
- Randomize player speed/size

### 8.3: Procedural Naming

- Generate clone names: "Mega Dodge Turbo Edition", "Dodge Mania X"
- Pull from word banks: adjectives (Mega, Ultra, Super) + game name + suffixes (Deluxe, Pro, X)

---

## Timeline Summary

| Phase | Focus | Duration | Dependencies |
|-------|-------|----------|--------------|
| **Phase 0** | Asset Attribution System | 2-3 days | None |
| **Phase 1** | Clone Customization System | 5-7 days | Phase 0 |
| **Phase 2** | Minigame Graphics Overhaul | 10-14 days | Phase 1 |
| **Phase 3** | Minigame Audio Overhaul | 7-10 days | Phase 1 |
| **Phase 4** | Standalone Game Polish | 8-10 days | Phases 2-3 |
| **Phase 5** | OS Visual/Audio Overhaul | 10-12 days | Phases 2-3 |
| **Phase 6** | Theme System Implementation | 5-7 days | Phase 5 |
| **Phase 7** | Cutscenes (Optional) | 7-10 days | Phase 1 |
| **Phase 8** | Procedural Variation (Stretch) | 5-7 days | Phase 2 |

**Total Estimated Duration**: 47-63 days (core phases), up to 80 days with optional phases

**Parallel Opportunities**:
- Phases 2 and 3 can partially overlap (different people or alternating days)
- Phase 4 and 5 can partially overlap (standalones vs OS work)

---

## Asset Sourcing Strategy

### Free/CC-Licensed Assets

**Where to Find**:
- **OpenGameArt.org** - Sprites, music, SFX (CC0, CC-BY, CC-BY-SA)
- **Itch.io Asset Packs** - Many free game asset bundles
- **Freesound.org** - Sound effects (various CC licenses)
- **Incompetech** - Royalty-free music by Kevin MacLeod
- **Kenny.nl** - Huge library of CC0 game assets

**License Priorities**:
1. **CC0** (public domain) - No attribution required, but we'll still credit
2. **CC-BY** - Attribution required, easy to comply with
3. **CC-BY-SA** - Attribution + share-alike (our game is open source, so compatible)

**Avoid**: Assets with NC (non-commercial) or ND (no-derivatives) restrictions

### Custom Assets

**If Budget Allows**:
- Commission unique assets for base games
- Focus on iconic elements (player character, main theme music)
- Use free assets for variants to save cost

**DIY Assets**:
- Pixel art sprites (tools: Aseprite, Piskel)
- Simple SFX (tools: Bfxr, ChipTone)
- Music (tools: Bosca Ceoil for chiptune, LMMS for fuller tracks)

---

## Attribution Workflow

### Adding New Assets

1. **Download/create asset**
2. **Place in appropriate directory**
3. **Immediately add to `attribution.json`**:
   ```json
   {
     "asset_path": "assets/sprites/games/dodge/blue_classic/player.png",
     "author": "Kenney",
     "license": "CC0",
     "source_url": "https://kenney.nl/assets/space-shooter-redux",
     "modifications": "Recolored from original",
     "date_added": "2025-10-23"
   }
   ```
4. **Run `scripts/validate_attribution.lua` before committing**

### Bulk Attribution

For asset packs:
```json
{
  "asset_path": "assets/sprites/games/dodge/blue_classic/*",
  "author": "Kenney",
  "license": "CC0",
  "source_url": "https://kenney.nl/assets/space-shooter-redux",
  "modifications": "None",
  "date_added": "2025-10-23"
}
```

---

## Technical Debt and Refactoring

### Align with Existing Refactor Plans

**From `Refactor plan.txt`**:
- EventBus already in progress - use for audio events
- DI for AudioManager, ThemeManager, AssetLoader
- No global state access for asset loading

### New Systems Required

**AudioManager** (if not exists):
- Load/play music
- Load/play SFX
- Volume controls (master, music, SFX)
- SFX pack management

**AssetLoader/SpriteLoader** (extend existing):
- Variant-aware sprite loading
- Fallback to default assets if variant missing
- Preload vs on-demand loading

**ThemeManager**:
- Theme config loading
- Active theme state
- Theme switching

**CutsceneController** (optional, Phase 7):
- Dialogue rendering
- Input handling
- Skippable cutscenes

---

## Testing Plan

### Manual Testing Checklist

**Per Game Type**:
- [ ] Each variant has unique visuals
- [ ] Each variant has unique audio
- [ ] Music loops seamlessly
- [ ] SFX play on correct events
- [ ] No missing sprites (fallback working if asset missing)
- [ ] Performance acceptable (60 FPS with assets loaded)

**Attribution**:
- [ ] All assets have attribution entries
- [ ] Validation script passes
- [ ] Credits screen displays all assets correctly

**Theme System**:
- [ ] Can switch themes from Settings
- [ ] OS sounds update immediately
- [ ] Wallpaper updates on theme change
- [ ] Active theme persists across restarts

### Performance Targets

- **Asset Loading**: < 3 seconds for all minigame assets
- **Memory Usage**: < 500MB with all assets loaded
- **FPS**: Maintain 60 FPS with animations, music, and SFX

---

## Success Metrics

### Qualitative Goals

- Clones feel distinct (different visuals/audio)
- No more Win98 placeholders in games
- Polished, cohesive art style per game type
- Audio adds to experience (not grating after 100 plays)

### Quantitative Goals

- **5 unique variants per base game** (25 total for 5 minigames)
- **3 SFX packs** (retro, modern, arcade)
- **10+ music tracks** for minigames
- **5+ music tracks** for Space Defender
- **3 OS themes** (default, dark, retro)
- **100% asset attribution** coverage

---

## Known Challenges

### Challenge: Asset Consistency

**Problem**: Mixing assets from different sources can look jarring
**Solution**:
- Define art style guide (pixel art resolution, color palette)
- Edit assets to match style (recolor, rescale)
- Accept some inconsistency for MVP, refine in polish pass

### Challenge: Audio Licensing

**Problem**: Easy to accidentally use copyrighted music
**Solution**:
- ONLY download from vetted sources (OpenGameArt, Freesound, Incompetech)
- Always check license before downloading
- When in doubt, don't use it

### Challenge: Variant Fatigue

**Problem**: Creating 5+ variants per game is content-heavy
**Solution**:
- Start with 2-3 variants per game
- Use procedural variation for clones beyond defined variants
- Palette swaps are valid variants (low effort, high value)

### Challenge: Performance with Many Assets

**Problem**: Loading hundreds of sprites/sounds could impact performance
**Solution**:
- Lazy load assets (only load active game's assets)
- Unload assets when game window closes
- Use sprite atlases to reduce draw calls
- Profile and optimize hotspots

---

## Next Steps After Completion

Once this plan is complete, potential follow-ups:

1. **More Minigames** (from Development Plan Phase 2)
   - Implement 10+ additional game types
   - Each with 3-5 variants

2. **Level Editor** (long-term)
   - Let players create custom levels
   - Share levels with community

3. **Mod Support**
   - Custom themes
   - Custom games
   - Custom assets via modding API

4. **Achievements**
   - Visual badges for completing games
   - Unlockable content (themes, wallpapers)

---

## Conclusion

**Primary Objective**: Make the games feel like games, not prototypes.

**Priority**: Graphics and audio for minigames first, then standalones, then OS.

**Foundation**: Attribution system BEFORE adding any assets.

**End Result**: A collection that feels like 10,000 distinct (shovelware) games, each with personality, even if mechanically similar.

---

**When ready to start, begin with Phase 0 (Attribution System)**. Do not skip this step, even though it's not the fun part. Future you will thank present you when the credits screen auto-generates and you're not scrambling to remember where that one sprite came from.
