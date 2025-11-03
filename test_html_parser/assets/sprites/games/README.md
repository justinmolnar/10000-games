# Game Assets Overview

This directory contains all sprite assets for the 10,000 Games Collection minigames, organized by game type and variant.

## Phase 2.1: Asset Organization - COMPLETE

**Status:** ✅ Directory structure created and documented
**Date:** 2025-10-24
**Phase:** Game Improvement Plan - Phase 2.1

## Directory Structure

```
assets/sprites/games/
├── dodge/                    # Dodge game variants
│   ├── base_1/              # First sprite set (3 variants via palettes)
│   ├── base_2/              # Second sprite set
│   ├── base_3/              # Third sprite set
│   └── README.md
├── hidden_object/           # Hidden Object game variants
│   ├── forest/              # Forest scene (variant 1)
│   ├── mansion/             # Mansion scene (variant 2)
│   ├── beach/               # Beach scene (variant 3)
│   ├── space_station/       # Space station scene (variant 4)
│   ├── library/             # Library scene (variant 5)
│   └── README.md
├── memory_match/            # Memory Match game variants
│   ├── icons_1/             # Classic icons set
│   ├── icons_2/             # Animal icons set
│   ├── icons_3/             # Gem icons set
│   ├── icons_4/             # Tech icons set
│   └── README.md
├── snake/                   # Snake game variants
│   ├── classic/             # Retro snake design
│   ├── modern/              # Modern snake design
│   └── README.md
└── space_shooter/           # Space Shooter minigame variants
    ├── fighter_1/           # Blue squadron
    ├── fighter_2/           # Red squadron
    ├── fighter_3/           # Gold squadron
    └── README.md
```

## Palette Swapping Strategy

**Key Innovation:** Maximize variant count while minimizing unique art assets.

Instead of creating unique sprites for each of 19+ variants, we use:
- **2-5 base sprite sets** per game type
- **8-10 color palettes** defined in `assets/data/sprite_palettes.json`
- **Shader-based palette swapping** at runtime

**Example:** 3 sprite sets × 10 palettes = 30 unique-looking variants with only 3 base asset sets!

### Canonical Palettes

Each base sprite set uses a **canonical palette** (default color scheme):
- Dodge: Red body [255, 0, 0] + Yellow accents [255, 255, 0]
- Snake: Neon green [0, 255, 50]
- Space Shooter: Blue [0, 100, 255]

These colors are swapped via shaders to create variants (red→blue, red→purple, etc.).

See individual game README files for canonical palette specifications.

## Asset Requirements Summary

**Note:** All sprite sets should include a `launcher_icon.png` (64x64 recommended) for Phase 2.4.

### Dodge Game (per base set)
- **launcher_icon.png** (64x64) - Icon shown in launcher and VM manager
- Player sprite (16x16 or 32x32)
- Obstacle sprites (3-5 variations)
- 5 enemy types (chaser, shooter, bouncer, zigzag, teleporter)
- Background (tileable starfield)
- Optional: Particle effects

### Hidden Object (per scene)
- **launcher_icon.png** (64x64) - Icon shown in launcher and VM manager
- Scene background (640x480+)
- 20-30 object sprites
- Shared UI elements

### Memory Match (per icon set)
- **launcher_icon.png** (64x64) - Icon shown in launcher and VM manager
- Card back design (64x64 or 128x128)
- 12-24 unique icon sprites
- Shared match/mismatch feedback

### Snake (per base set)
- **launcher_icon.png** (64x64) - Icon shown in launcher and VM manager
- Snake head (4 directions)
- Snake body segment
- Snake tail (4 directions)
- Food/apple sprite
- Optional: Grid background

### Space Shooter (per fighter set)
- **launcher_icon.png** (64x64) - Icon shown in launcher and VM manager
- Player ship sprite
- 4 enemy ship types
- Player + enemy bullets
- 3 power-up sprites
- Explosion animation (4-8 frames)
- Scrolling background

## Asset Specifications

**Format:** PNG with transparency (except backgrounds)
**Naming:** Lowercase with underscores
**Palette Colors:** Exact RGB values for clean swapping
**Size:** Consistent within each sprite set
**Compression:** Standard PNG compression acceptable

## Attribution Requirements

**CRITICAL:** All assets MUST be documented in `assets/data/attribution.json` before use.

Required fields:
- `asset_path` - Path to asset file
- `author` - Creator name
- `license` - License type (CC0, CC-BY, CC-BY-SA)
- `source_url` - Where asset was obtained
- `modifications` - Any changes made
- `date_added` - When asset was added

See **Game Improvement Plan - Phase 0** for attribution system details.

## Asset Sourcing

**Recommended Sources:**
- **OpenGameArt.org** - Sprites, music, SFX (CC0, CC-BY, CC-BY-SA)
- **Itch.io Asset Packs** - Many free game asset bundles
- **Kenny.nl** - Huge library of CC0 game assets
- **Freesound.org** - Sound effects (various CC licenses)

**License Priorities:**
1. CC0 (public domain) - Preferred
2. CC-BY (attribution required) - Acceptable
3. CC-BY-SA (attribution + share-alike) - Compatible with open source

**Avoid:** NC (non-commercial) or ND (no-derivatives) licenses

## Completed Phases

1. ✅ **Phase 2.1:** Asset organization structure (directories created)
2. ✅ **Phase 2.3:** In-game sprite loading integration with graceful fallback
3. ✅ **Phase 2.4:** Launcher icon loading with graceful fallback

## Next Steps (Phase 2.2+)

Once asset organization is complete:

1. **Phase 2.2:** Create/source actual sprite assets (including launcher icons)
2. Assets will be automatically loaded and displayed when added to appropriate directories

See `documentation/Game Improvement Plan.md` for full roadmap.

## Variant Catalog

### Current Variants (from Phase 1)

**19 total variants** across 5 base games, each with:
- Unique name (e.g., "Dodge Deluxe", "Beach Bonanza")
- Flavor text description
- Difficulty modifier (1.0x to 1.8x)
- Enemy composition (for applicable games)
- Palette ID

See `assets/data/base_game_definitions.json` for complete variant definitions.

## Integration with Code

**Variant Loading System:**
- `GameVariantLoader` (src/models/game_variant_loader.lua) loads variant data
- Each game class receives `variant_data` via dependency injection
- Views use `variant.palette` for shader-based color swapping
- Asset paths constructed from `variant.sprite_set`

**Asset Loading Pattern:**
```lua
local base_path = "assets/sprites/games/" .. game_type .. "/" .. variant.sprite_set .. "/"
local player_sprite = spriteLoader:load(base_path .. "player.png")
```

## Testing

**Manual Testing Checklist:**
- [ ] All directories exist and are accessible
- [ ] README files are comprehensive and accurate
- [ ] Asset requirements match variant definitions in JSON
- [ ] Palette specifications are clear and actionable
- [ ] Attribution workflow is documented

**Automated Validation:**
- Run `scripts/validate_attribution.lua` (to be created in Phase 0)
- Check for missing attribution entries before committing assets

## Notes

- **Phase 2.1 is organizational only** - No actual assets created yet
- Assets will be added progressively in Phase 2.2+
- Directory structure designed for easy expansion
- Each game's README provides detailed specifications
- Palette system enables 90% reduction in unique art needed

---

**Phase 2.1 Complete:** Asset organization structure ready for population.
**Next Phase:** Phase 2.2 - Sprite Requirements per Base Sprite Set (asset creation/sourcing)
