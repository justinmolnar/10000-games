# Snake Game Assets

## Overview
This directory contains sprite sets for Snake game variants. Each base set includes snake body parts, food, and background elements with palette swapping support.

## Directory Structure

### classic/
Traditional retro snake look.

**Required Assets:**
- `snake_head_up.png` - Snake head facing up (16x16 or 32x32)
- `snake_head_down.png` - Snake head facing down
- `snake_head_left.png` - Snake head facing left
- `snake_head_right.png` - Snake head facing right
- `snake_body.png` - Snake body segment
- `snake_tail_up.png` - Snake tail facing up
- `snake_tail_down.png` - Snake tail facing down
- `snake_tail_left.png` - Snake tail facing left
- `snake_tail_right.png` - Snake tail facing right
- `food_apple.png` - Food sprite (apple or generic food)
- `background.png` - Grid background or border tiles (optional)

**Canonical Palette:**
- Snake: Neon green [0, 255, 50]
- Food: Red [255, 0, 0]
- Background: Dark grey/black (neutral)

### modern/
Sleek, modern snake design.

**Required Assets:** (Same list as classic/)
- More polished, gradient-friendly design
- Rounded edges, modern aesthetic
- Cyber blue canonical palette

**Canonical Palette:**
- Snake: Cyber blue [0, 100, 255]
- Food: Bright cyan [0, 255, 255]
- Background: Dark blue/black (neutral)

## Palette System

Snake sprites use canonical green (classic) or blue (modern) which will be swapped to:
- Neon pink variant
- Purple variant
- Orange variant
- etc. (see `assets/data/sprite_palettes.json`)

Food sprites swap to different fruit colors (banana=yellow, grape=purple, etc.).

## Asset Specifications

**Format:** PNG with transparency
**Size:** 16x16 or 32x32 (consistent with grid size)
**Grid-Based:** Snake moves on a grid, sprites must align perfectly
**Directional Sprites:** 4 directions for head and tail required
**Body Segment:** Single sprite, rotated/tiled as needed

## Animation Support

**Optional:**
- `snake_eat_animation.png` - Sprite sheet for eating animation
- `food_spawn_animation.png` - Food appearing effect
- `death_animation.png` - Snake death effect

## Gameplay Considerations

- Snake body must clearly show direction of travel
- Head and tail must be distinguishable
- Food must be clearly visible against background
- Grid size should match sprite size (16x16 or 32x32)

## Background Options

**Option 1:** Solid color (simplest, fully palette-swappable)
**Option 2:** Grid lines (subtle, helps player track movement)
**Option 3:** Tileable pattern (more visual interest)

## Attribution

All assets must be documented in `assets/data/attribution.json` with:
- Author
- License
- Source URL
- Modifications (if any)
- Date added

## Variants Using These Assets

**Snake Classic** (snake_1) - classic set, neon_green palette
**Snake Neon** (snake_2) - classic set, neon_pink palette
**Snake Modern** (snake_3) - modern set, cyber_blue palette

See `assets/data/base_game_definitions.json` for full variant configuration.

## Notes

- Classic snake uses chunky, pixelated retro aesthetic
- Modern snake uses smoother, more polished look
- Both sets support full palette swapping for maximum variant count
