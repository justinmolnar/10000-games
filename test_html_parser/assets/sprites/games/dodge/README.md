# Dodge Game Assets

## Overview
This directory contains sprite sets for the Dodge game variants. Each base sprite set supports multiple color palettes to create distinct visual variants.

## Directory Structure

### base_1/
First base sprite set using canonical red + yellow palette.

**Required Assets:**
- `player.png` - Player sprite (16x16 or 32x32)
  - Canonical palette: red body + yellow accents
  - Animated optional (use sprite sheet with quads)
- `obstacle.png` - Standard obstacle sprite
  - Primary red color for palette swapping
- `enemy_chaser.png` - Seeker enemy (homes in on player)
  - Simple red circular/organic shape
- `enemy_shooter.png` - Shooting enemy (fires projectiles)
  - Red with gun/turret visual indicator
- `enemy_bouncer.png` - Bouncing enemy (wall bounce)
  - Angular red shape suggesting bounce physics
- `enemy_zigzag.png` - Zigzag pattern enemy
  - Streamlined red shape
- `enemy_teleporter.png` - Teleporting enemy
  - Particle-like red shape with ethereal quality
- `background.png` - Tileable starfield or solid color background
  - Keep neutral or complementary to allow palette swaps

**Optional Assets:**
- `particle_death.png` - Death particle effect
- `particle_boost.png` - Boost/speed particle effect

### base_2/
Second base sprite set with different art style.

**Assets:** (Same as base_1 but different visual design)
- Different ship/character design
- May include unique enemy types

### base_3/
Third base sprite set (optional).

**Assets:** (Same as base_1 but different visual design)

## Palette System

Base sprites should use **canonical palette** (red + yellow tones):
- Primary red: [255, 0, 0]
- Dark red: [200, 0, 0]
- Darker red: [150, 0, 0]
- Yellow accent: [255, 255, 0]

These colors will be swapped via shaders to create different variants:
- Blue variant: Blue tones
- Purple variant: Purple tones
- Green variant: Green tones
- etc. (see `assets/data/sprite_palettes.json`)

## Asset Specifications

**Format:** PNG with transparency
**Size:** 16x16 or 32x32 recommended (consistent within set)
**Colors:** Use exact RGB values for palette swapping
**Compression:** Standard PNG compression acceptable

## Naming Convention

- Use lowercase with underscores
- Enemy sprites: `enemy_{type}.png`
- Background must be tileable if not fullscreen

## Attribution

All assets must be documented in `assets/data/attribution.json` with:
- Author
- License
- Source URL
- Modifications (if any)
- Date added

## Variants Using These Assets

**Dodge Master** (dodge_1) - base_1, default palette
**Dodge Deluxe** (dodge_2) - base_1, red palette
**Dodge Chaos** (dodge_3) - base_1, purple palette
**Dodge Elite** (dodge_4) - base_2, green palette

See `assets/data/base_game_definitions.json` for full variant configuration.
