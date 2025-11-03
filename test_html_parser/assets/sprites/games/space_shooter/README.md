# Space Shooter Game Assets

## Overview
This directory contains sprite sets for Space Shooter minigame variants (not Space Defender standalone). Each base set includes player ship, enemy ships, bullets, power-ups, and effects with palette swapping support.

## Directory Structure

### fighter_1/
First fighter ship design set.

**Required Assets:**

**Player:**
- `player_ship.png` - Player ship sprite (16x16 or 32x32)
  - Canonical blue/red palette
  - Forward-facing (vertical shooter)

**Enemies:**
- `enemy_basic.png` - Basic enemy (simple downward movement)
- `enemy_weaver.png` - Weaving enemy (zigzag pattern)
- `enemy_bomber.png` - Bomber enemy (slow, heavy, 2 HP)
- `enemy_kamikaze.png` - Kamikaze enemy (dives at player)

**Projectiles:**
- `bullet_player.png` - Player bullet (small, fast)
- `bullet_enemy.png` - Enemy bullet (contrasting color to player)

**Power-ups:**
- `powerup_speed.png` - Speed boost power-up
- `powerup_weapon.png` - Weapon upgrade power-up
- `powerup_shield.png` - Shield power-up

**Effects:**
- `explosion_sheet.png` - Explosion animation (sprite sheet, 4-8 frames)
  - Yellow/orange/red gradient (swaps to other color schemes)
  - Small (16x16), Medium (32x32), Large (64x64) frames

**Background:**
- `background.png` - Scrolling space background
  - Starfield or nebula
  - Neutral or complementary colors

**Canonical Palette:**
- Player: Blue squadron [0, 100, 255]
- Enemies: Red tones [255, 50, 50]
- Bullets: Bright colors for visibility

### fighter_2/
Second fighter ship design set.

**Required Assets:** (Same list as fighter_1/)
- Different ship design aesthetic
- Red squadron canonical palette

### fighter_3/
Third fighter ship design set.

**Required Assets:** (Same list as fighter_1/)
- Different ship design aesthetic
- Gold squadron canonical palette

## Palette System

Each variant uses different squadron palette:
- Blue squadron (fighter_1)
- Red squadron (fighter_2)
- Gold squadron (fighter_3)

These palettes affect:
- Player ship colors
- Bullet colors (for player)
- Power-up colors
- UI accent colors

Enemy ships maintain contrasting colors for clarity.

## Asset Specifications

**Format:** PNG with transparency
**Player/Enemy Size:** 16x16 to 32x32 recommended
**Bullet Size:** 4x4 to 8x8 (small, fast-moving)
**Power-up Size:** 16x16 to 24x24
**Explosion Frames:** 4-8 frames in horizontal sprite sheet
**Background:** Tileable vertically for scrolling effect

## Enemy Type Behaviors

**Basic:** Standard enemy, moves straight down, shoots occasionally
**Weaver:** Zigzags left/right, increased fire rate
**Bomber:** Slow movement, shoots rapidly, takes 2 hits to destroy
**Kamikaze:** Dives directly at player position, doesn't shoot

See `src/games/space_shooter.lua` for ENEMY_TYPES definitions.

## Animation Support

**Explosion Animation:**
- Sprite sheet format: horizontal strip
- Frame count: 4-8 frames
- Frame size: 16x16 (small), 32x32 (medium), 64x64 (large)
- Play once, then destroy

**Optional:**
- Player thrust animation (sprite sheet)
- Power-up rotation animation
- Enemy idle animations

## Gameplay Considerations

- Player ship must be clearly visible
- Enemy ships must be distinguishable by type (silhouette recognition)
- Bullets must contrast with background for visibility
- Power-ups should stand out (bright colors, pulsing optional)

## Background Scrolling

Background should:
- Be tileable vertically (seamless loop)
- Scroll slowly (parallax optional)
- Not distract from gameplay
- Provide depth without obscuring sprites

## Attribution

All assets must be documented in `assets/data/attribution.json` with:
- Author
- License
- Source URL
- Modifications (if any)
- Date added

## Variants Using These Assets

**Space Shooter Alpha** (space_shooter_1) - fighter_1, blue_squadron palette
**Space Shooter Beta** (space_shooter_2) - fighter_2, red_squadron palette
**Space Shooter Omega** (space_shooter_3) - fighter_3, gold_squadron palette

See `assets/data/base_game_definitions.json` for full variant configuration.

## Notes

- This is the **minigame** Space Shooter, not the standalone Space Defender
- Simpler than Space Defender (fewer levels, basic progression)
- Focus on quick, arcade-style gameplay
- All three fighter sets should feel distinct but balanced
