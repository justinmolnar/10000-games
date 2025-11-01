# Palette Swapping System - Current State & Implementation Plan

## Current Implementation

### What Exists:
1. **PaletteManager** (`src/utils/palette_manager.lua`)
   - Loads palettes from `sprite_palettes.json` (20 predefined palettes)
   - Has shader-based palette swapping (`palette_swap.glsl`)
   - Method: `drawSpriteWithPalette()` - applies palette via shader OR CPU
   - Shader swaps 4 colors: primary, secondary, accent, highlight

2. **Shader System** (`assets/shaders/palette_swap.glsl`)
   - Takes 4 source colors (Win98 defaults)
   - Replaces with 4 target colors from palette
   - Uses tolerance-based color matching

3. **Palette JSON** (`assets/data/sprite_palettes.json`)
   - 20 predefined palettes (blue, red, fire, rainbow, etc.)
   - Each has 4 colors: primary, secondary, accent, highlight

4. **Space Shooter Integration**
   - Variants have `"palette": "blue"` field
   - `SpaceShooterView` loads palette_id from variant
   - Calls `paletteManager:drawSpriteWithPalette()` for all sprites

### Current Problems:

1. **Palette System Is NOT Working for Space Shooter**
   - Space Shooter loads sprites as raw PNG files in `loadAssets()`
   - Sprites are stored in `self.sprites` table
   - When drawing, the view uses `love.graphics.draw()` directly
   - **BYPASSES PaletteManager entirely!**
   - The palette code exists but is never actually invoked for Space Shooter sprites

2. **Launcher Doesn't Apply Palettes**
   - Launcher loads player sprites directly with `love.graphics.newImage()`
   - Draws with `love.graphics.draw()` - no palette applied
   - Formula icons use sprite_loader which DOES support palettes
   - But player sprites bypass it

3. **No Random/Seeded Palette Generation**
   - All palettes are manually specified in JSON
   - No system to generate random tints
   - No seeded palette selection based on variant data

## What You Want:

1. **Random/Seeded Tints**
   - Generate random color palettes OR pick from predefined list
   - Seed based on variant data (clone_index, name hash, etc.)
   - Consistent across sessions - same variant = same tint

2. **Override Capability**
   - Variant can specify explicit palette: `"palette": "blue"`
   - OR use `"palette": "random"` for seeded random
   - OR omit palette field entirely for default random

3. **Apply Everywhere**
   - In-game sprites (player, enemies, bullets, etc.)
   - Launcher list icons
   - Launcher detail view
   - Formula renderer icons

## Recommended Implementation Plan

### Option A: Simple Tint Multiplier (Easiest, Works Now)
Instead of palette swapping (color replacement), use simple color tinting:

**Pros:**
- Works with existing sprite loading
- Simple shader: `pixel.rgb * tint_color`
- No need to match source colors
- Can generate infinite random tints
- Easy to implement in launcher

**Cons:**
- Less control than full palette swap
- Can't dramatically change color schemes
- Tint affects all colors uniformly

**Implementation:**
1. Add `getTintForVariant(variant)` to PaletteManager
   - Generates seeded RGB tint from variant.clone_index
   - Returns vec3 like `{1.2, 0.8, 1.0}` (more red, less green, same blue)
2. Create simple tint shader or use `love.graphics.setColor()`
3. Apply in SpaceShooterView when drawing sprites
4. Apply in launcher when loading player sprites

### Option B: Full Palette Swap (Current System, Needs Fixes)
Fix the existing palette swap system to actually work:

**Pros:**
- More dramatic color changes
- Precise control over 4-color palettes
- System already exists, just needs wiring

**Cons:**
- Requires sprites to use specific source colors
- Harder to generate random palettes (need 4 coherent colors)
- More complex to integrate everywhere

**Implementation:**
1. Fix SpaceShooterView to use `paletteManager:drawSpriteWithPalette()` instead of `love.graphics.draw()`
2. Add random palette generation:
   ```lua
   function PaletteManager:generateSeededPalette(seed)
       -- Use seed to generate 4 coherent colors
       -- Return palette table
   end
   ```
3. Add palette selection logic:
   ```lua
   function PaletteManager:getPaletteForVariant(variant)
       if variant.palette == "random" then
           local seed = variant.clone_index or hashString(variant.name)
           return self:generateSeededPalette(seed)
       elseif variant.palette then
           return self:getPalette(variant.palette)
       else
           -- Default: seeded random
           return self:generateSeededPalette(variant.clone_index)
       end
   end
   ```
4. Update launcher to use PaletteManager for player sprites

### Option C: Hybrid Approach (Recommended)
Use tinting for random variants, palette swap for explicit ones:

**Pros:**
- Best of both worlds
- Random tints are easy and look good
- Explicit palettes give precise control for special variants
- Backwards compatible with existing palette field

**Cons:**
- Two systems to maintain
- Slightly more complex

**Implementation:**
1. Add tint generation to PaletteManager
2. Modify `getPaletteForVariant()`:
   - If `palette` is explicit ID → use full palette swap
   - If `palette` is "random" or missing → generate seeded tint
3. Update drawing code to handle both modes
4. Apply in game views and launcher

## My Recommendation

**Go with Option A (Simple Tint) for now, migrate to Option C later:**

### Phase 1: Implement Tinting (Do This Now)
1. Add tint generation to PaletteManager:
   ```lua
   function PaletteManager:getTintForVariant(variant)
       local seed = variant.clone_index or 0
       math.randomseed(seed)
       local r = 0.7 + math.random() * 0.6  -- 0.7 to 1.3
       local g = 0.7 + math.random() * 0.6
       local b = 0.7 + math.random() * 0.6
       return {r, g, b}
   end
   ```

2. Modify SpaceShooterView to apply tint when drawing sprites:
   ```lua
   local tint = self.paletteManager:getTintForVariant(self.variant)
   love.graphics.setColor(tint)
   love.graphics.draw(sprite, x, y)
   love.graphics.setColor(1, 1, 1)  -- Reset
   ```

3. Update launcher to apply same tint to icons

4. Test with Space Shooter variants

### Phase 2: Full Palette Swap (After JSON Refactor)
1. Wait for JSON refactor (self-describing variants)
2. Implement full palette swap properly
3. Add random palette generation
4. Migrate from tinting to palette swap where appropriate

## Per-Game Tinting Control

Not all games should use tinting - some sprites don't make sense to tint:
- **Memory Match**: Flags are specific colors, tinting breaks gameplay
- **Hidden Object**: Objects have specific appearances
- **Space Shooter**: Player/enemy ships - YES, tint them
- **Dodge Game**: Player sprite - YES
- **Snake**: Segments - YES

### Solution: Tint Whitelist/Blacklist

Add to variant JSON or base game definitions:
```json
{
  "tint_enabled": true,  // Global toggle
  "tint_sprites": ["player", "enemy_*", "segment", "seg_head"],  // Whitelist
  "no_tint_sprites": ["flag_*", "object_*"]  // Blacklist
}
```

Or simpler: add to game config defaults:
```lua
Config.games.space_shooter.tinting = {
    enabled = true,
    sprites = "all"  -- or specific list
}

Config.games.memory_match.tinting = {
    enabled = false  -- Don't tint memory match at all
}

Config.games.hidden_object.tinting = {
    enabled = true,
    sprites = {"player"}  -- Only tint player, not objects
}
```

## Immediate Steps (Phase 1)

Would you like me to:
1. Implement simple tinting for **all games** (with per-game enable/disable)
2. Add seeded random tint generation based on clone_index
3. Add config toggles for which games/sprites use tinting
4. Still respect explicit `"palette"` field for future use
5. Apply tints in-game and launcher (list + detail view)

**Recommended Tinting Defaults:**
- Space Shooter: Enable, tint all sprites
- Dodge Game: Enable, tint player only
- Snake Game: Enable, tint all segments
- Memory Match: **Disable** (flags need specific colors)
- Hidden Object: **Disable** or player-only (objects shouldn't tint)

This gets you visible color variation NOW across all appropriate games, and we can enhance it with full palette swapping after the JSON refactor.
