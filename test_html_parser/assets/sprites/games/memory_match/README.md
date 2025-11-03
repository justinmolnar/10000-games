# Memory Match Game Assets

## Overview
This directory contains card designs for Memory Match game variants. **The game automatically scans folders and randomly picks icons**, so you can have any number of sprites (5, 50, 500, etc) with any filenames. **Sprites can be any size or aspect ratio** (32x48 flags, 64x64 squares, 128x128 icons, etc) - the game preserves aspect ratios automatically.

## How It Works

1. Game loads the variant's `sprite_set` parameter (defaults to "flags" if not specified)
2. Scans `assets/sprites/games/memory_match/{sprite_set}/` for all .png files
3. Randomly shuffles them
4. Picks however many are needed for the current game (6 pairs = 6 icons, 24 pairs = 24 icons)
5. Scales each sprite to fit within the card while preserving aspect ratio
6. Different sprites every playthrough!

## Creating a New Sprite Set

**Example: Creating a "flags" set with 200 country flags:**

```
memory_match/
└── flags/
    ├── card_back.png       (Optional - card back design)
    ├── usa.png
    ├── canada.png
    ├── japan.png
    ├── ... (197 more flags with any names)
```

**That's it!** The game will:
- Randomly pick 6 flags for a 6-pair game
- Randomly pick 24 flags for a 24-pair game
- Use different flags each time you play

## Directory Structure Examples

### flags/ (200 sprites)
Country flags - any number, any names.
- `card_back.png` (optional)
- `usa.png`, `canada.png`, `france.png`, etc.

### faces/ (50 sprites)
Emoji faces - however many you want.
- `card_back.png` (optional)
- `happy.png`, `sad.png`, `laughing.png`, etc.

### icons_1/ (24 sprites)
Classic shapes - original set.
- `card_back.png`
- Any 24 .png files

### objects/ (5 sprites)
Minimal set - only 5 items.
- `card_back.png`
- 5 .png files with any names

## Required Files Per Set

### card_back.png (Optional)
- The back of the card when face-down
- Recommended size: 64x64, 128x128, or 256x256
- If missing, game uses blue rectangle fallback

### Icon Images (Any number, any names)
- **Minimum recommended**: At least as many as your largest variant needs
  - 6-pair game = 6 icons minimum
  - 24-pair game = 24 icons minimum
  - 48-pair game = 48 icons minimum
- **File names don't matter**: `usa.png`, `flag_001.png`, `country_usa.png` - all work!
- **No maximum**: 5 icons or 5000 icons - game handles both
- Recommended size: 64x64, 128x128, or 256x256
- Format: PNG with transparency preferred
- Style: Clear, recognizable at small sizes

## Excluded Files

These filenames are automatically skipped:
- `card_back.png` - Reserved for card back
- `launcher_icon.png` - Reserved for launcher thumbnail
- `README.md` - Documentation files

## Asset Specifications

**Format:** PNG (transparency supported)
**Recommended Sizes:** 64x64, 128x128, or 256x256 pixels
**Colors:** Any colors work - palette swapping is optional
**Style:** Simple, recognizable shapes work best
**Naming:** Anything except reserved names above

## Using in Variants

Add your sprite set to a variant in `assets/data/variants/memory_match_variants.json`:

```json
{
  "clone_index": 5,
  "name": "Memory Match World Flags",
  "sprite_set": "flags",
  "palette": "vibrant",
  "music_track": "memory_theme_1",
  "sfx_pack": "retro_beeps",
  "background": "gradient_blue",
  "difficulty_modifier": 1.0,
  "flavor_text": "Match flags from around the world!",
  "intro_cutscene": null,
  "card_count": 12
}
```

The game will automatically:
1. Load `assets/sprites/games/memory_match/flags/`
2. Scan for all .png files (excluding card_back.png and launcher_icon.png)
3. Randomly pick 6 icons for a 6-pair game (12 cards)
4. Each playthrough uses different random flags!

## Quick Start

**To use your 200 flags (default):**
1. Create folder: `assets/sprites/games/memory_match/flags/`
2. Drop in 200 flag PNGs with any names (any size/ratio works: 32x48, 64x64, etc)
3. Optional: Add `card_back.png` for custom card back
4. Done! All variants default to "flags" automatically
5. To use a different set, add `"sprite_set": "other_folder"` to variant JSON

## Fallback Behavior

If sprites are missing or not enough:
- **No sprite_set**: Uses icon system fallback (game_freecell-0 sprite)
- **No card_back.png**: Uses blue rectangle with border
- **Not enough icons**: Uses what's available, may repeat or show debug numbers

## Attribution

All assets should be documented in `assets/data/attribution.json` with:
- Author
- License
- Source URL
- Modifications (if any)
- Date added
