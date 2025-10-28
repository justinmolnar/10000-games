# Complete Asset Requirements - Master Checklist

**Date**: 2025-10-25
**Status**: Architecture Complete ✅ | Assets Needed ⚠️

This document outlines **every visual and audio asset** required for the complete 10,000 Games experience. The code architecture is fully implemented with graceful fallback - missing assets will use simple geometric shapes and silence (no crashes).

---

## Quick Reference: What You Need

### Minigames (Priority 1)
- **5 game types** × **2-5 base sprite sets** = 15-20 sprite sets
- **8-10 color palettes** (multiply visual variety 10x)
- **15 music tracks** (3 per game type)
- **54 sound effects** (18 sounds × 3 packs)

### Standalone Games (Priority 2)
- **Space Defender**: Ship sprites, enemies, bosses, bullets, backgrounds
- **Solitaire**: Card sprites, backs, table backgrounds

### OS/Desktop (Priority 3)
- **Window chrome**: Title bars, buttons, borders
- **Desktop icons**: Programs, folders, files
- **Cursors**: Default, pointer, resize, etc.
- **OS sounds**: Window open/close, clicks, errors

### Total Files Needed (Bare Minimum for MVP)
- **~150-200 sprite files** (with palette swapping)
- **~70 audio files** (music + SFX)
- **~30 UI/OS assets** (icons, chrome, cursors)

**Total: ~250-300 asset files**

---

## Technical Specifications

### Sprite Requirements

| Asset Type | Format | Dimensions | Notes |
|------------|--------|------------|-------|
| Game sprites | PNG with transparency | 16×16 to 64×64 pixels | Power-of-2 sizes preferred |
| Backgrounds | PNG/JPG | 800×600 or larger | Tileable if repeating |
| Icons (desktop) | PNG with transparency | 32×32 pixels | Clear at small size |
| Icons (menu) | PNG with transparency | 16×16 pixels | Simplified version |
| Cursor sprites | PNG with transparency | 32×32 pixels | Hotspot usually top-left |
| Sprite sheets | PNG with transparency | Any (must define quads) | Document frame layout |

**Color Requirements**:
- Use **exact RGB values** for palette swapping (e.g., [255,0,0] not [254,1,0])
- Design with **2-4 distinct base colors** for swapping
- Include **2-3 shades per color** for depth
- Avoid gradients (hard to palette-swap cleanly)

### Audio Requirements

| Asset Type | Format | Quality | Duration | Notes |
|------------|--------|---------|----------|-------|
| Music (looping) | OGG Vorbis | ~128kbps | 30-60 seconds | Must loop seamlessly |
| Music (non-looping) | OGG Vorbis | ~128kbps | Any | Jingles, stingers |
| Sound effects | OGG Vorbis | ~96-128kbps | 0.1-1.5 seconds | Short, punchy |

**Audio Best Practices**:
- Normalize volume (prevent clipping)
- Mono for SFX (smaller files)
- Stereo for music (richer sound)
- Test loops for clicks/pops at restart point

---

## Minigame Asset Requirements

### Overview: Base Sprite Sets + Palette Swapping

Each minigame needs **2-5 base sprite sets**. Each base set can be palette-swapped into **8-10 color variants**, giving you **16-50 visual variants per game type** from just 2-5 sprite sets!

**Example**: 3 dodge sprite sets × 10 palettes = 30 unique-looking Dodge variants

---

## 1. Dodge Game Assets

### Sprites Required (per base sprite set)

**Base Sprite Sets Needed**: 3 minimum (1 MVP, 3 ideal)

#### Base Set 1: "Classic" (`dodge/base_1/`)

| File | Dimensions | Description | Palette Colors |
|------|------------|-------------|----------------|
| `player.png` | 32×32 | Player ship/character | Red body + yellow accents |
| `obstacle.png` | 32×32 | Standard obstacle | Red primary |
| `enemy_chaser.png` | 32×32 | Homes in on player | Red with distinct shape |
| `enemy_shooter.png` | 32×32 | Fires at player | Red with gun/turret |
| `enemy_bouncer.png` | 32×32 | Bounces off walls | Angular red shape |
| `enemy_zigzag.png` | 32×32 | Zigzag movement | Streamlined red shape |
| `enemy_teleporter.png` | 32×32 | Teleports near player | Particle-like red |
| `background.png` | 800×600+ | Starfield/space | Neutral (black/dark blue) |

**Total per base set**: 8 files
**Total for 3 base sets**: 24 files

#### Optional: Animated Sprites
- `player_sheet.png` - Sprite sheet with thrust animation (4 frames)
- `explosion_sheet.png` - Explosion effect (6-8 frames)

### Audio Required

**Music** (shared across all Dodge variants):
- `assets/audio/music/minigames/dodge_theme_1.ogg` - Upbeat electronic, tense
- `assets/audio/music/minigames/dodge_theme_2.ogg` - Aggressive, faster
- `assets/audio/music/minigames/dodge_theme_3.ogg` - Chaotic, intense

**Sound Effects** (part of SFX packs, see Phase 3.5):
- `hit` - Player collision
- `death` - Player dies
- `success` - Level complete
- `dodge` - Successful dodge (subtle)

**Status**: ⚠️ 0 / 24 sprite files | 0 / 3 music tracks

---

## 2. Hidden Object Game Assets

### Sprites Required (per base scene)

**Base Scenes Needed**: 5 minimum (3 MVP, 5+ ideal)

**Note**: Hidden Object backgrounds are harder to palette-swap effectively. Recommend **unique scenes** rather than palette variants (or use stylized/flat art for swapping).

#### Scene 1: "Forest" (`hidden_object/forest/`)

| File | Dimensions | Description |
|------|------------|-------------|
| `background.png` | 800×600+ | Forest scene background |
| `object_01.png` through `object_30.png` | 32×32 to 64×64 | Hidden objects (magnifying glass, key, book, etc.) |

**Total per scene**: 31 files (1 background + 30 objects)
**Total for 5 scenes**: 155 files

#### Scene Ideas
1. **Forest** - Trees, foliage, natural hidden spots
2. **Mansion** - Victorian interior, cluttered rooms
3. **Beach** - Sandy shore, shells, beach items
4. **Space Station** - Futuristic, tech panels, consoles
5. **Library** - Books, scrolls, dusty shelves

### Audio Required

**Music** (ambient, atmospheric):
- `assets/audio/music/minigames/hidden_object_ambient_forest.ogg`
- `assets/audio/music/minigames/hidden_object_ambient_mansion.ogg`
- `assets/audio/music/minigames/hidden_object_ambient_beach.ogg`

**Sound Effects** (part of SFX packs):
- `find_object` - Object found
- `wrong_click` - Clicked wrong area
- `success` - All objects found

**Status**: ⚠️ 0 / 155 sprite files | 0 / 3 music tracks

---

## 3. Memory Match Game Assets

### Sprites Required (per base card design)

**Base Card Sets Needed**: 4 minimum (2 MVP, 4+ ideal)

#### Card Set 1: "Classic Icons" (`memory_match/icons_1/`)

| File | Dimensions | Description | Palette Colors |
|------|------------|-------------|----------------|
| `card_back.png` | 60×80 | Card back design | Primary + accent color |
| `icon_01.png` through `icon_24.png` | 40×60 | Card face icons | Bold, simple colors |

**Total per card set**: 25 files (1 back + 24 icons)
**Total for 4 card sets**: 100 files

#### Icon Ideas per Set
- **Set 1**: Animals (dog, cat, bird, fish, etc.)
- **Set 2**: Shapes/Symbols (star, heart, diamond, circle, etc.)
- **Set 3**: Gems/Treasures (ruby, sapphire, emerald, gold coin, etc.)
- **Set 4**: Tech/Retro (computer, phone, gamepad, floppy disk, etc.)

**Design Tips**:
- Icons should be **bold, simple, recognizable**
- Use **2-3 main colors** for palette swapping
- Maintain high contrast for visibility

### Audio Required

**Music** (calm, non-intrusive):
- `assets/audio/music/minigames/memory_match_calm_1.ogg`
- `assets/audio/music/minigames/memory_match_calm_2.ogg`
- `assets/audio/music/minigames/memory_match_calm_3.ogg`

**Sound Effects** (part of SFX packs):
- `flip_card` - Card flipped
- `match` - Cards matched
- `mismatch` - Cards don't match
- `success` - All pairs found

**Status**: ⚠️ 0 / 100 sprite files | 0 / 3 music tracks

---

## 4. Snake Game Assets

### Sprites Required (per base sprite set)

**Base Sprite Sets Needed**: 2 minimum (1 MVP, 2 ideal)

**IMPORTANT**: Snake sprites use **rotation**, not directional variants. Design sprites facing **RIGHT** (0°) - the engine rotates them automatically.

**All sprites go in the same folder per sprite set** - both uniform and segmented styles coexist.

#### Sprites Required Per Set

| File | Description | Notes |
|------|-------------|-------|
| `segment.png` | Single segment (uniform style) | Design facing RIGHT → |
| `seg_head.png` | Snake head (segmented style) | Design facing RIGHT → |
| `seg_body.png` | Body segment (segmented style) | Design facing RIGHT → |
| `seg_tail.png` | Tail segment (segmented style) | Design facing RIGHT → |
| `food.png` | Food (palette swapped for bad/golden) | |
| `obstacle.png` | Obstacle (all types) | |

**Total sprites per set**: 6 files
**Note**: Sprites auto-scale to grid size - any square dimensions work

**Design Guidelines**:
- All snake sprites MUST face **right** (→) in the base image
- Engine rotates sprites automatically based on movement direction
- Sprites should be **symmetrical vertically** for clean 90° rotation
- Use simple shapes for best rotation results
- Any square dimensions work - sprites auto-scale to grid

### Audio Required

**Music** (retro chiptune):
- `assets/audio/music/minigames/snake_retro_1.ogg`
- `assets/audio/music/minigames/snake_retro_2.ogg`
- `assets/audio/music/minigames/snake_retro_3.ogg`

**Sound Effects** (part of SFX packs):
- `eat` - Ate food
- `death` - Hit obstacle/self
- `success` - Reached target length

**Status**: ⚠️ 0 / 6 sprite files | 0 / 3 music tracks

---

## 5. Space Shooter Game Assets (Minigame)

### Sprites Required (per base sprite set)

**Base Sprite Sets Needed**: 3 minimum (1 MVP, 3 ideal)

**Note**: This is the **minigame** Space Shooter (clone system), NOT Space Defender (the standalone progression game).

#### Base Set 1: "Fighter Squadron" (`space_shooter/fighter_1/`)

| File | Dimensions | Description | Palette Colors |
|------|------------|-------------|----------------|
| `player.png` | 32×32 | Player ship | Blue/red primary |
| `enemy_basic.png` | 32×32 | Basic enemy ship | Single primary color |
| `enemy_weaver.png` | 32×32 | Weaving enemy | Single primary color |
| `enemy_bomber.png` | 32×32 | Bomber enemy (2 HP) | Single primary color |
| `enemy_kamikaze.png` | 32×32 | Diving kamikaze | Single primary color |
| `bullet_player.png` | 8×16 | Player bullet | Bright color |
| `bullet_enemy.png` | 8×16 | Enemy bullet | Different bright color |
| `power_up.png` | 24×24 | Power-up icon | Yellow/gold |
| `background.png` | 800×600+ | Scrolling space bg | Neutral stars |

**Total per base set**: 9 files
**Total for 3 base sets**: 27 files

#### Optional: Explosion Animation
- `explosion_sheet.png` - 6-8 frames of explosion (palette-swappable)

### Audio Required

**Music** (fast-paced action):
- `assets/audio/music/minigames/space_shooter_action_1.ogg`
- `assets/audio/music/minigames/space_shooter_action_2.ogg`
- `assets/audio/music/minigames/space_shooter_action_3.ogg`

**Sound Effects** (part of SFX packs):
- `shoot` - Player fires
- `hit` - Player hit by bullet
- `enemy_explode` - Enemy destroyed
- `death` - Player dies (max deaths reached)
- `success` - Reached target kills

**Status**: ⚠️ 0 / 27 sprite files | 0 / 3 music tracks

---

## 6. Palette System Assets

### Palette Definitions Required

**File**: `assets/data/palettes.json`

**Palettes Needed**: 8-10 color schemes

Each palette swaps the canonical colors (e.g., red + yellow) to new colors:

| Palette ID | Name | Primary Color | Accent Color | Description |
|------------|------|---------------|--------------|-------------|
| `default` | Default | Red | Yellow | Canonical base palette |
| `blue` | Blue Classic | Blue | Light blue | Cool tones |
| `red` | Red Danger | Bright red | Orange | Warm, aggressive |
| `purple` | Purple Chaos | Purple | Pink | Royal, mysterious |
| `green` | Green Elite | Green | Lime | Natural, fresh |
| `orange` | Orange Blaze | Orange | Yellow | Fiery, energetic |
| `cyan` | Cyan Frost | Cyan | White | Cool, icy |
| `pink` | Pink Neon | Hot pink | Purple | Vibrant, modern |
| `yellow` | Yellow Thunder | Yellow | Orange | Bright, electric |
| `gray` | Grayscale | Gray | White | Monochrome, sleek |

### Palette JSON Structure

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
  }
}
```

**What You Need to Do**:
1. Create base sprites using canonical red + yellow colors
2. Define 8-10 palette swap definitions in JSON
3. Test each palette on all base sprites to ensure good contrast

**Status**: ⚠️ 0 / 1 JSON file (with 8-10 palette definitions)

---

## 7. Sound Effects Pack Assets

### SFX Packs Required

**3 packs needed**: retro_beeps, modern_ui, 8bit_arcade

Each pack contains **18 sound effects** with identical filenames but different audio styles.

### File Structure

```
assets/audio/sfx/packs/
├── retro_beeps/           # Pack 1: 8-bit style
│   ├── hit.ogg
│   ├── death.ogg
│   ├── success.ogg
│   ├── collect.ogg
│   ├── dodge.ogg
│   ├── boost.ogg
│   ├── find_object.ogg
│   ├── wrong_click.ogg
│   ├── flip_card.ogg
│   ├── match.ogg
│   ├── mismatch.ogg
│   ├── eat.ogg
│   ├── grow.ogg
│   ├── turn.ogg
│   ├── shoot.ogg
│   ├── enemy_explode.ogg
│   ├── select.ogg
│   └── powerup.ogg
├── modern_ui/             # Pack 2: Clean, polished
│   └── (same 18 files)
└── 8bit_arcade/           # Pack 3: Energetic, punchy
    └── (same 18 files)
```

### Sound Characteristics by Pack

| Pack | Style | Tools | Example Use Case |
|------|-------|-------|------------------|
| **retro_beeps** | Chiptune, synthesized beeps | Bfxr, ChipTone | Classic arcade feel |
| **modern_ui** | Clean, professional | Freesound.org, Audacity | Polished, refined |
| **8bit_arcade** | Punchy, energetic | Bfxr (aggressive settings) | High-energy gameplay |

**Status**: ⚠️ 0 / 54 sound files (18 × 3 packs)

---

## Standalone Game Assets

---

## 8. Space Defender (Standalone Progression Game)

**Note**: This is the main progression game, NOT the minigame Space Shooter clones.

### Sprites Required

#### Player Ship
| File | Dimensions | Description |
|------|------------|-------------|
| `player/ship_base.png` | 48×48 | Base player ship |
| `player/ship_upgraded_1.png` | 48×48 | Visual upgrade tier 1 (optional) |
| `player/ship_upgraded_2.png` | 48×48 | Visual upgrade tier 2 (optional) |

#### Enemies (Per Level Tier)
| File | Dimensions | Description |
|------|------------|-------------|
| `enemies/tier_1_basic.png` | 32×32 | Levels 1-5 basic enemy |
| `enemies/tier_1_fast.png` | 32×32 | Levels 1-5 fast variant |
| `enemies/tier_2_basic.png` | 40×40 | Levels 6-10 enemy |
| `enemies/tier_2_shooter.png` | 40×40 | Levels 6-10 shooting enemy |
| `enemies/tier_3_basic.png` | 48×48 | Levels 11-15 enemy |
| `enemies/tier_3_armored.png` | 48×48 | Levels 11-15 armored (more HP) |
| *(Continue pattern for tiers 4-5)* | | |

#### Bosses (5 Unique Bosses)
| File | Dimensions | Description |
|------|------------|-------------|
| `bosses/boss_level_5.png` | 128×128 | Boss for level 5 |
| `bosses/boss_level_10.png` | 128×128 | Boss for level 10 |
| `bosses/boss_level_15.png` | 128×128 | Boss for level 15 |
| `bosses/boss_level_20.png` | 128×128 | Boss for level 20 |
| `bosses/boss_level_25.png` | 128×128 | Final boss (if 25 levels) |

#### Bullets & Effects
| File | Dimensions | Description |
|------|------------|-------------|
| `bullets/player_bullet.png` | 8×16 | Standard player bullet |
| `bullets/enemy_bullet.png` | 8×16 | Enemy bullet |
| `bullets/boss_bullet.png` | 12×24 | Larger boss bullet |
| `explosions/explosion_small_sheet.png` | 32×32 (×6 frames) | Small explosion |
| `explosions/explosion_large_sheet.png` | 64×64 (×8 frames) | Large explosion (bosses) |

#### Backgrounds (Per Level Tier)
| File | Dimensions | Description |
|------|------------|-------------|
| `backgrounds/level_1_bg.png` | 800×600+ | Levels 1-5 background |
| `backgrounds/level_6_bg.png` | 800×600+ | Levels 6-10 background |
| `backgrounds/level_11_bg.png` | 800×600+ | Levels 11-15 background |
| `backgrounds/level_16_bg.png` | 800×600+ | Levels 16-20 background |
| `backgrounds/level_21_bg.png` | 800×600+ | Levels 21-25 background |

#### Power-Ups
| File | Dimensions | Description |
|------|------------|-------------|
| `powerups/shield.png` | 24×24 | Shield power-up |
| `powerups/rapid_fire.png` | 24×24 | Rapid fire power-up |
| `powerups/spread_shot.png` | 24×24 | Spread shot power-up |

**Total Space Defender Sprites**: ~40-50 files

### Audio Required

#### Music (Per Level Tier)
- `assets/audio/music/space_defender/tier_1_theme.ogg` - Levels 1-5
- `assets/audio/music/space_defender/tier_2_theme.ogg` - Levels 6-10
- `assets/audio/music/space_defender/tier_3_theme.ogg` - Levels 11-15
- `assets/audio/music/space_defender/tier_4_theme.ogg` - Levels 16-20
- `assets/audio/music/space_defender/tier_5_theme.ogg` - Levels 21-25 (if applicable)
- `assets/audio/music/space_defender/boss_battle.ogg` - Boss encounters
- `assets/audio/music/space_defender/victory.ogg` - Victory jingle

#### Sound Effects
- `assets/audio/sfx/space_defender/player_shoot.ogg`
- `assets/audio/sfx/space_defender/enemy_shoot.ogg`
- `assets/audio/sfx/space_defender/enemy_explode.ogg`
- `assets/audio/sfx/space_defender/boss_hurt.ogg`
- `assets/audio/sfx/space_defender/boss_explode.ogg`
- `assets/audio/sfx/space_defender/player_hit.ogg`
- `assets/audio/sfx/space_defender/shield_activate.ogg`
- `assets/audio/sfx/space_defender/powerup_collect.ogg`
- `assets/audio/sfx/space_defender/level_complete.ogg`

**Total Space Defender Audio**: 7 music tracks + 9 SFX = 16 files

**Status**: ⚠️ 0 / 50 sprite files | 0 / 16 audio files

---

## 9. Solitaire Assets

### Sprites Required

#### Card Sprites
| File | Dimensions | Description |
|------|------------|-------------|
| `cards/card_sheet.png` | Varies | All 52 cards in sprite sheet (13 ranks × 4 suits) |
| `cards/back_classic.png` | 60×80 | Classic card back design |
| `cards/back_modern.png` | 60×80 | Modern card back (optional) |
| `cards/back_retro.png` | 60×80 | Retro card back (optional) |

**Card Sheet Layout**: 13 columns × 4 rows (Ace-King, Spades/Hearts/Diamonds/Clubs)

#### Backgrounds
| File | Dimensions | Description |
|------|------------|-------------|
| `backgrounds/felt_green.png` | 800×600+ | Classic green felt |
| `backgrounds/felt_blue.png` | 800×600+ | Blue felt variant |
| `backgrounds/wood_table.png` | 800×600+ | Wood table texture |

#### UI Elements
| File | Dimensions | Description |
|------|------------|-------------|
| `ui/hint_icon.png` | 32×32 | Hint button icon |
| `ui/new_game_icon.png` | 32×32 | New game button icon |
| `ui/undo_icon.png` | 32×32 | Undo button icon |

**Total Solitaire Sprites**: ~10 files (1 card sheet + 3 backs + 3 backgrounds + 3 UI)

### Audio Required

#### Music (Calm, Ambient)
- `assets/audio/music/solitaire/calm_ambient_1.ogg`
- `assets/audio/music/solitaire/calm_ambient_2.ogg`
- `assets/audio/music/solitaire/calm_ambient_3.ogg`

#### Sound Effects
- `assets/audio/sfx/solitaire/card_flip.ogg`
- `assets/audio/sfx/solitaire/card_place.ogg` - Valid move
- `assets/audio/sfx/solitaire/card_snap.ogg` - Invalid move
- `assets/audio/sfx/solitaire/deal_cards.ogg`
- `assets/audio/sfx/solitaire/win_jingle.ogg`
- `assets/audio/sfx/solitaire/hint_chime.ogg`

**Total Solitaire Audio**: 3 music tracks + 6 SFX = 9 files

**Status**: ⚠️ 0 / 10 sprite files | 0 / 9 audio files

---

## OS/Desktop Assets

---

## 10. Window Chrome & UI Assets

### Window Chrome Sprites

**Path**: `assets/sprites/os/window_chrome/`

| File | Dimensions | Description |
|------|------------|-------------|
| `title_bar.png` | 1×24 (tileable) | Window title bar background |
| `title_bar_active.png` | 1×24 (tileable) | Active window title bar |
| `title_bar_inactive.png` | 1×24 (tileable) | Inactive window title bar |
| `close_button.png` | 16×16 | Close button |
| `close_button_hover.png` | 16×16 | Close button hover state |
| `minimize_button.png` | 16×16 | Minimize button |
| `minimize_button_hover.png` | 16×16 | Minimize hover |
| `maximize_button.png` | 16×16 | Maximize button |
| `maximize_button_hover.png` | 16×16 | Maximize hover |
| `border_corner.png` | 8×8 | Window border corner |
| `border_vertical.png` | 8×1 (tileable) | Vertical border |
| `border_horizontal.png` | 1×8 (tileable) | Horizontal border |
| `resize_handle.png` | 16×16 | Bottom-right resize grip |

**Total Window Chrome**: 13 files

### Taskbar & Start Menu

**Path**: `assets/sprites/os/taskbar/`

| File | Dimensions | Description |
|------|------------|-------------|
| `taskbar_bg.png` | 1×40 (tileable) | Taskbar background |
| `start_button.png` | 80×32 | Start menu button |
| `start_button_hover.png` | 80×32 | Start button hover |
| `start_button_pressed.png` | 80×32 | Start button pressed |
| `task_button.png` | 160×32 | Active task button background |
| `task_button_active.png` | 160×32 | Selected task highlight |
| `clock_bg.png` | 60×32 | System tray clock background |

**Total Taskbar**: 7 files

### Desktop Assets

**Path**: `assets/sprites/os/desktop/`

| File | Dimensions | Description |
|------|------------|-------------|
| `wallpaper_default.png` | 1920×1080 | Default desktop wallpaper |
| `wallpaper_space.png` | 1920×1080 | Space-themed wallpaper |
| `wallpaper_abstract.png` | 1920×1080 | Abstract pattern |
| `wallpaper_minimal.png` | 1920×1080 | Minimalist wallpaper |

**Total Desktop**: 4 wallpapers

**Status**: ⚠️ 0 / 24 OS UI sprite files

---

## 11. Desktop Icons

### System Icons

**Path**: `assets/sprites/os/icons/`

| File | Dimensions | Description |
|------|------------|-------------|
| `folder.png` | 32×32 | Generic folder |
| `folder_open.png` | 32×32 | Open folder |
| `file_generic.png` | 32×32 | Generic file |
| `file_text.png` | 32×32 | Text document |
| `file_image.png` | 32×32 | Image file |
| `recycle_bin.png` | 32×32 | Recycle bin (empty) |
| `recycle_bin_full.png` | 32×32 | Recycle bin (with items) |
| `computer.png` | 32×32 | My Computer icon |
| `disk_drive.png` | 32×32 | Disk drive icon |

### Program Icons

**Path**: `assets/sprites/os/icons/programs/`

| File | Dimensions | Description |
|------|------------|-------------|
| `launcher.png` | 32×32 | Game Launcher icon |
| `launcher_16.png` | 16×16 | Launcher menu icon |
| `vm_manager.png` | 32×32 | VM Manager icon |
| `vm_manager_16.png` | 16×16 | VM Manager menu icon |
| `cheat_engine.png` | 32×32 | CheatEngine icon |
| `cheat_engine_16.png` | 16×16 | CheatEngine menu icon |
| `space_defender.png` | 32×32 | Space Defender icon |
| `space_defender_16.png` | 16×16 | Space Defender menu icon |
| `solitaire.png` | 32×32 | Solitaire icon |
| `solitaire_16.png` | 16×16 | Solitaire menu icon |
| `file_explorer.png` | 32×32 | File Explorer icon |
| `file_explorer_16.png` | 16×16 | File Explorer menu icon |
| `settings.png` | 32×32 | Settings icon |
| `settings_16.png` | 16×16 | Settings menu icon |
| `statistics.png` | 32×32 | Statistics icon |
| `statistics_16.png` | 16×16 | Statistics menu icon |
| `control_panel.png` | 32×32 | Control Panel icon |
| `control_panel_16.png` | 16×16 | Control Panel menu icon |

### Game Icons (Minigames)

**Path**: `assets/sprites/icons/games/`

These are used in the launcher. One icon per **base game type**, not per variant.

| File | Dimensions | Description |
|------|------------|-------------|
| `dodge_base.png` | 32×32 | Dodge game icon |
| `hidden_object_base.png` | 32×32 | Hidden Object icon |
| `memory_match_base.png` | 32×32 | Memory Match icon |
| `snake_base.png` | 32×32 | Snake icon |
| `space_shooter_base.png` | 32×32 | Space Shooter icon |

**Total Icon Files**: 9 system + 18 program + 5 game = 32 files

**Status**: ⚠️ 0 / 32 icon files

---

## 12. Cursor Sprites

**Path**: `assets/sprites/os/cursors/`

| File | Dimensions | Description | Hotspot |
|------|------------|-------------|---------|
| `default.png` | 32×32 | Default arrow cursor | (0, 0) |
| `pointer.png` | 32×32 | Pointing hand (links/buttons) | (10, 0) |
| `text.png` | 32×32 | Text I-beam cursor | (16, 16) |
| `resize_horizontal.png` | 32×32 | Horizontal resize | (16, 16) |
| `resize_vertical.png` | 32×32 | Vertical resize | (16, 16) |
| `resize_diagonal_1.png` | 32×32 | Diagonal resize (↖↘) | (16, 16) |
| `resize_diagonal_2.png` | 32×32 | Diagonal resize (↗↙) | (16, 16) |
| `busy.png` | 32×32 | Busy/loading cursor | (16, 16) |
| `drag.png` | 32×32 | Drag/move cursor | (16, 16) |

**Total Cursors**: 9 files

**Status**: ⚠️ 0 / 9 cursor files

---

## 13. OS Audio Assets

### OS Music

**Path**: `assets/audio/os/music/`

| File | Description | Loop | Duration |
|------|-------------|------|----------|
| `desktop_ambient.ogg` | Desktop background music | Yes | 60-120s |
| `startup.ogg` | Startup jingle | No | 3-5s |
| `shutdown.ogg` | Shutdown jingle | No | 2-3s |

### OS Sound Effects

**Path**: `assets/audio/os/sfx/`

| File | Description | Duration |
|------|-------------|----------|
| `window_open.ogg` | Window opened | 0.2-0.5s |
| `window_close.ogg` | Window closed | 0.2-0.5s |
| `window_minimize.ogg` | Window minimized | 0.2s |
| `window_maximize.ogg` | Window maximized | 0.2s |
| `button_click.ogg` | Button clicked | 0.1s |
| `dropdown_open.ogg` | Dropdown menu opened | 0.2s |
| `error.ogg` | Error beep | 0.5s |
| `notification.ogg` | Notification chime | 0.5s |
| `start_menu_open.ogg` | Start menu opened | 0.3s |
| `start_menu_close.ogg` | Start menu closed | 0.2s |
| `icon_click.ogg` | Desktop icon clicked | 0.1s |
| `file_copy.ogg` | File copied | 0.3s |
| `file_delete.ogg` | File deleted | 0.4s |
| `recycle_bin_empty.ogg` | Recycle bin emptied | 0.5s |

**Total OS Audio**: 3 music + 14 SFX = 17 files

**Status**: ⚠️ 0 / 17 OS audio files

---

## Complete Asset Count Summary

### Sprites

| Category | Files Needed | Status |
|----------|--------------|--------|
| **Minigames** | | |
| - Dodge (3 base sets) | 24 | ⚠️ 0 / 24 |
| - Hidden Object (5 scenes) | 155 | ⚠️ 0 / 155 |
| - Memory Match (4 card sets) | 100 | ⚠️ 0 / 100 |
| - Snake (2 base sets) | 6 | ⚠️ 0 / 6 |
| - Space Shooter (3 base sets) | 27 | ⚠️ 0 / 27 |
| **Standalone Games** | | |
| - Space Defender | 50 | ⚠️ 0 / 50 |
| - Solitaire | 10 | ⚠️ 0 / 10 |
| **OS/Desktop** | | |
| - Window Chrome & UI | 24 | ⚠️ 0 / 24 |
| - Icons | 32 | ⚠️ 0 / 32 |
| - Cursors | 9 | ⚠️ 0 / 9 |
| **TOTAL SPRITES** | **437** | **⚠️ 0 / 437** |

### Audio

| Category | Files Needed | Status |
|----------|--------------|--------|
| **Minigame Music** | 15 | ⚠️ 0 / 15 |
| **Minigame SFX Packs** | 54 (18 × 3 packs) | ⚠️ 0 / 54 |
| **Space Defender Audio** | 16 | ⚠️ 0 / 16 |
| **Solitaire Audio** | 9 | ⚠️ 0 / 9 |
| **OS Audio** | 17 | ⚠️ 0 / 17 |
| **TOTAL AUDIO** | **111** | **⚠️ 0 / 111** |

### Data Files

| Category | Files Needed | Status |
|----------|--------------|--------|
| **Palette Definitions** | 1 (palettes.json with 8-10 palettes) | ⚠️ 0 / 1 |
| **SFX Pack Definitions** | 1 (sfx_packs.json) | ✅ 1 / 1 (exists but empty) |
| **Attribution** | 1 (attribution.json) | ⚠️ 0 / 1 |

---

## GRAND TOTAL: 552 Files Needed

- **439 sprite files** (reduced from 455 - snake now uses rotation)
- **111 audio files**
- **2 data files** (palettes.json, attribution.json)

**Current Status**: Architecture 100% complete ✅ | Assets 0% complete ⚠️

---

## Recommended Sourcing Priority

### Phase 1: Get ONE Minigame Fully Working (Week 1)

**Focus**: Dodge game with retro_beeps SFX pack

1. **Create 1 Dodge base sprite set** (8 files)
   - Use simple geometric shapes initially (circles, triangles)
   - Design with red + yellow canonical palette
2. **Generate retro_beeps SFX pack** (18 files)
   - Use Bfxr (15-30 minutes)
3. **Source 1 Dodge music track** (1 file)
   - OpenGameArt.org or create with Bosca Ceoil
4. **Create 1 palette definition** (JSON entry)
   - Define blue palette swap
5. **Test complete flow**:
   - Launch Dodge → Music plays → Sounds trigger → Palette swaps work

**Result**: 27 files → ONE fully functional game with audio/visual identity

---

### Phase 2: Expand to All Minigames (Week 2-3)

1. **Complete remaining minigame sprite sets**:
   - Snake: 6 files per set - EASIEST (simple rotated sprites, palette-swapped food, auto-scaling)
   - Memory Match: 25 files (1 card set) - EASY (simple icons)
   - Space Shooter: 9 files (1 base set) - MEDIUM
   - Hidden Object: 31 files (1 scene) - HARDEST (complex background)

2. **Source remaining minigame music** (12 tracks)
3. **Complete all 3 SFX packs** (36 more files)
4. **Create 8-10 palette definitions** (JSON)

**Result**: All 5 minigames playable with audio, multiple color variants

---

### Phase 3: OS Polish (Week 4)

1. **Window chrome** (13 files) - Makes UI look polished
2. **Icons** (32 files) - Replace Win98 placeholders
3. **Cursors** (9 files) - Custom cursor pack
4. **OS sounds** (17 files) - Window interactions feel alive

**Result**: Desktop environment feels cohesive and polished

---

### Phase 4: Standalone Games (Week 5-6)

1. **Space Defender** (50 sprites + 16 audio)
2. **Solitaire** (10 sprites + 9 audio)

**Result**: Full game experience complete

---

## Asset Sourcing Resources

### Free Graphics

- **Kenney.nl** - CC0 game assets (sprites, UI, icons)
- **OpenGameArt.org** - Huge library of game assets
- **Itch.io** - Free asset packs (filter by CC licenses)
- **Game-icons.net** - SVG icons (convert to PNG)

### Free Audio

- **Freesound.org** - Sound effects (CC licenses)
- **OpenGameArt.org** - Music and SFX
- **Incompetech** - Royalty-free music by Kevin MacLeod
- **Bfxr.net** - Generate retro SFX (browser tool)
- **ChipTone** - 8-bit sound generator

### Creation Tools

**Sprites**:
- **Aseprite** ($) - Professional pixel art editor
- **Piskel** (Free) - Browser-based pixel art
- **GIMP** (Free) - General image editing

**Music**:
- **Bosca Ceoil** (Free) - Chiptune music maker
- **LMMS** (Free) - Full DAW for music production
- **BeepBox** (Free) - Browser-based chiptune

**SFX**:
- **Bfxr** (Free) - Retro sound effect generator
- **ChipTone** (Free) - Another 8-bit SFX tool
- **Audacity** (Free) - Audio editing (convert WAV→OGG)

---

## Testing Checklist: "Complete" Game Definition

A minigame is **complete** when:

### Visual
- [ ] Base sprite set exists (all required files present)
- [ ] Sprites use canonical palette (exact RGB values)
- [ ] At least 3 palette definitions work with sprites
- [ ] Game icon exists (32×32)
- [ ] No geometric fallback shapes visible (unless intended aesthetic)

### Audio
- [ ] At least 1 music track plays and loops seamlessly
- [ ] All game-specific SFX trigger on correct events
- [ ] Universal sounds work (hit, death, success)
- [ ] Volume is normalized (not clipping or too quiet)

### Attribution
- [ ] All assets have entries in `attribution.json`
- [ ] License info is accurate
- [ ] Source URLs are valid

### Gameplay
- [ ] Game launches without errors
- [ ] Sprites render correctly (no missing textures)
- [ ] Palette swapping works (can switch colors)
- [ ] Music starts when game begins
- [ ] Music stops when game ends
- [ ] SFX play at correct times
- [ ] Performance is smooth (60 FPS)

---

## Quick Start: Your First Complete Game (30 minutes)

### Goal: Get Dodge game fully working

1. **Create base sprites** (10 min):
   - Open Piskel or Aseprite
   - Draw simple 32×32 red circle (player)
   - Draw simple 32×32 red square (obstacle)
   - Draw 32×32 red triangle (enemy_chaser)
   - Export as PNG

2. **Generate SFX** (10 min):
   - Visit Bfxr.net
   - Generate: hit, death, success, dodge
   - Export as WAV, convert to OGG with Audacity

3. **Source music** (5 min):
   - Visit OpenGameArt.org
   - Search "electronic tense loop"
   - Download CC0 or CC-BY track
   - Rename to `dodge_theme_1.ogg`

4. **Create palette** (5 min):
   - Edit `assets/data/palettes.json`
   - Add blue palette definition (swap red→blue, yellow→cyan)

5. **Test** (5 min):
   - Place files in correct folders
   - Launch game
   - Play Dodge variant
   - Verify music, sounds, visuals all work

**Congratulations!** You now have a fully functional game with unique identity. Repeat this process for the other 4 minigames.

---

## Final Notes

### What "Complete" Means

**MVP Complete**:
- 1 base sprite set per game type (5 sets)
- 1 music track per game type (5 tracks)
- 1 SFX pack (18 sounds)
- 3-5 palettes
- Basic OS icons/chrome

**Polished Complete**:
- 2-3 base sprite sets per game (10-15 sets)
- 3 music tracks per game (15 tracks)
- 3 SFX packs (54 sounds)
- 8-10 palettes
- Full OS assets (chrome, cursors, icons, sounds)
- Space Defender & Solitaire assets

**Shipping Complete**:
- All of the above
- 5+ scenes for Hidden Object
- 4+ card sets for Memory Match
- Animated sprites (explosions, particle effects)
- Multiple themes for OS

### Graceful Degradation

The system is designed to work at ANY asset completion level:
- **0% assets**: Geometric shapes + silence
- **10% assets**: Few games have graphics/audio, rest use fallback
- **50% assets**: Most games playable, some variants share assets
- **100% assets**: Full visual/audio diversity, every variant unique

You can ship at ANY percentage and add assets progressively!

---

## Questions?

If you're unsure about:
- **File formats**: Use PNG for sprites, OGG for audio
- **Dimensions**: Follow the tables above (or close approximations)
- **Palette colors**: Start with exact RGB [255,0,0] and [255,255,0]
- **Where to place files**: Check file paths in each section

**The architecture is ready. Just add files and they'll work!** 🎨🎵
