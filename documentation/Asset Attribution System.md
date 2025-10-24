# Asset Attribution System

**Status**: ✅ Implemented (Phase 0 Complete)
**Version**: 1.0
**Last Updated**: 2025-10-23

---

## Overview

The Asset Attribution System ensures all external assets (sprites, music, SFX, fonts, etc.) used in 10,000 Games are properly credited. This system:

- **Tracks** all asset sources, authors, and licenses
- **Validates** that assets have proper attribution
- **Displays** credits to users in-game
- **Prevents** accidental license violations

**CRITICAL**: Add attribution entries BEFORE committing any new assets to the repository.

---

## System Components

### 1. Attribution Data File
**Location**: `assets/data/attribution.json`

Central database of all asset attributions. Each entry contains:
- Asset path (supports wildcards)
- Author/creator
- License
- Source URL
- Modifications (if any)
- Date added
- Optional notes

### 2. Attribution Manager
**Location**: `src/utils/attribution_manager.lua`

Utility class that:
- Loads attribution data
- Queries attributions by path or type
- Validates asset coverage
- Supports wildcard matching

### 3. Credits Screen
**Locations**:
- `src/states/credits_state.lua`
- `src/views/credits_view.lua`

In-game window accessible from Start Menu showing all attributions grouped by type.

### 4. Validation Script
**Location**: `scripts/validate_attribution.lua`

Command-line tool to scan project and report missing attributions.

---

## Quick Start Guide

### Adding Attribution for a New Asset

**Scenario**: You've downloaded a sprite pack from Kenney.nl and placed it in `assets/sprites/games/dodge/base_1/`

**Step 1**: Add entry to `attribution.json`

Open `assets/data/attribution.json` and add to the `attributions` array:

```json
{
  "asset_path": "assets/sprites/games/dodge/base_1/*",
  "asset_type": "sprite",
  "author": "Kenney",
  "license": "CC0",
  "source_url": "https://kenney.nl/assets/space-shooter-redux",
  "modifications": "None",
  "date_added": "2025-10-23",
  "notes": "Base sprite set for Dodge game variants"
}
```

**Step 2**: Validate

Run the validation script to ensure it's recognized:

```bash
lua scripts/validate_attribution.lua
```

**Step 3**: Commit

Commit both the assets and the updated `attribution.json` together.

---

## Detailed Usage

### Attribution Entry Format

```json
{
  "asset_path": "path/to/asset.png",
  "asset_type": "sprite|music|sfx|font|code|shader|other",
  "author": "Creator Name",
  "license": "License Identifier",
  "source_url": "https://source-website.com",
  "modifications": "Description of changes, or 'None'",
  "date_added": "YYYY-MM-DD",
  "notes": "Optional additional context"
}
```

#### Field Descriptions

**`asset_path`** (required)
- Relative path from project root
- Supports wildcards: `assets/sprites/dodge/*` matches all files in that directory
- Use forward slashes (`/`) for cross-platform compatibility

**`asset_type`** (required)
- `sprite` - Images (PNG, JPG)
- `music` - Music tracks (OGG, MP3)
- `sfx` - Sound effects
- `font` - Font files (TTF)
- `code` - Code libraries
- `shader` - Shader files (GLSL)
- `other` - Anything else

**`author`** (required)
- Creator's name or username
- For asset packs, use the pack creator's name

**`license`** (required)
- Short identifier: `CC0`, `CC-BY`, `CC-BY-SA`, `MIT`, etc.
- Must be a license compatible with the project

**`source_url`** (required)
- URL where asset was obtained
- For commissioned assets, use artist's portfolio URL

**`modifications`** (required)
- Describe changes: "Recolored from red to blue"
- If unchanged: "None"

**`date_added`** (required)
- Date asset was added to project
- Format: `YYYY-MM-DD`

**`notes`** (optional)
- Additional context
- Example: "Used for all Dodge game variants"

### Wildcard Patterns

Use wildcards to attribute entire asset packs with one entry.

**Examples**:

```json
{
  "asset_path": "assets/sprites/games/dodge/base_1/*",
  "notes": "Matches all files in base_1 directory"
}
```

```json
{
  "asset_path": "assets/audio/music/*",
  "notes": "Matches all music files"
}
```

```json
{
  "asset_path": "assets/sprites/*/player.png",
  "notes": "Matches player.png in any subdirectory of sprites/"
}
```

**Wildcard Rules**:
- `*` matches any characters within a path segment
- Wildcards work with the AttributionManager's pattern matching
- Specific paths take precedence over wildcards

### Acceptable Licenses

**Preferred** (easiest to comply with):
- **CC0** - Public domain, no attribution required (but we credit anyway)
- **MIT** - Simple, permissive
- **CC-BY** - Attribution required

**Acceptable**:
- **CC-BY-SA** - Attribution + share-alike (our project is open source)
- **Apache 2.0** - Patent grant + attribution

**Avoid**:
- **CC-BY-NC** - Non-commercial restriction (may conflict with future plans)
- **CC-BY-ND** - No derivatives (can't modify assets)
- **GPL** - Viral licensing (complicated for game assets)

**When in doubt**: Stick to CC0, CC-BY, or MIT.

---

## Using the Attribution Manager in Code

### Basic Usage

```lua
local attributionManager = di.attributionManager

-- Check if an asset has attribution
if attributionManager:hasAttribution("assets/sprites/player.png") then
    print("Asset is properly attributed")
end

-- Get attribution details
local attr = attributionManager:getAttribution("assets/sprites/player.png")
if attr then
    print("Author: " .. attr.author)
    print("License: " .. attr.license)
end

-- Get all sprites
local sprites = attributionManager:getByType("sprite")
for _, attr in ipairs(sprites) do
    print(attr.asset_path)
end
```

### Validation During Development

Add validation checks to asset loading (optional, for debug mode):

```lua
function SpriteLoader:load(path)
    local sprite = love.graphics.newImage(path)

    -- Optional: Warn if asset lacks attribution (only in debug builds)
    if self.di.config.debug_mode then
        if not self.di.attributionManager:hasAttribution(path) then
            print("WARNING: No attribution for " .. path)
        end
    end

    return sprite
end
```

### Querying Attribution Data

```lua
-- Get count
local count = attributionManager:getCount()
print("Total attributions: " .. count)

-- Get all authors
local authors = attributionManager:getAuthors()
for _, author in ipairs(authors) do
    print("Contributor: " .. author)
end

-- Get grouped by type
local grouped = attributionManager:getAllGrouped()
for type_name, attrs in pairs(grouped) do
    print(type_name .. ": " .. #attrs .. " assets")
end
```

---

## Validation Workflow

### Running the Validation Script

**Option 1: From Command Line** (Recommended)

```bash
# From project root
lua scripts/validate_attribution.lua
```

**Option 2: Within LÖVE**

The script can run within LÖVE but command-line usage is preferred.

### Script Output

**All assets attributed**:
```
=== Asset Attribution Validation ===

Loaded 15 attribution entries

Scanning for asset files...
Found 87 asset files

=== Results ===

✓ All assets have attribution entries!

Coverage: 100.0% (87/87 assets attributed)
```

**Missing attributions**:
```
=== Asset Attribution Validation ===

Loaded 12 attribution entries

Scanning for asset files...
Found 94 asset files

=== Results ===

✗ 7 assets missing attribution:

  - assets/sprites/games/dodge/base_2/player.png
  - assets/sprites/games/dodge/base_2/obstacle.png
  - assets/audio/music/new_track.ogg
  ...

Coverage: 92.6% (87/94 assets attributed)
```

### Pre-Commit Validation

**Recommended**: Run validation before each commit with new assets.

**Manual**:
```bash
lua scripts/validate_attribution.lua && git commit
```

**Git Hook** (Optional):

Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash
echo "Validating asset attributions..."
lua scripts/validate_attribution.lua
if [ $? -ne 0 ]; then
    echo "Attribution validation failed. Add missing attributions to assets/data/attribution.json"
    exit 1
fi
```

Make executable: `chmod +x .git/hooks/pre-commit`

---

## Accessing Credits In-Game

### For Users

1. Open **Start Menu** (click Windows logo or press Windows key)
2. Find **Credits** in the programs list
3. Click to open Credits window
4. Scroll through attributions grouped by type (Code, Graphics, Music, etc.)
5. Click **Close** when done

### For Developers

Credits are automatically generated from `attribution.json`. No manual credits file needed!

When you add entries to `attribution.json`, they appear immediately in the Credits screen.

---

## Common Workflows

### Workflow 1: Adding a Single Asset

1. Download asset from source (e.g., OpenGameArt)
2. Place in appropriate directory (`assets/sprites/`, `assets/audio/`, etc.)
3. Open `attribution.json`
4. Add entry with full details
5. Run validation: `lua scripts/validate_attribution.lua`
6. Commit both files: `git add assets/ && git add assets/data/attribution.json && git commit`

### Workflow 2: Adding an Asset Pack

1. Download entire pack (e.g., Kenney Space Shooter pack)
2. Extract to directory: `assets/sprites/games/space_shooter/kenney_pack/`
3. Open `attribution.json`
4. Add ONE entry with wildcard: `"asset_path": "assets/sprites/games/space_shooter/kenney_pack/*"`
5. Validate and commit

### Workflow 3: Commissioning Custom Assets

1. Commission artist for custom sprites
2. Receive assets and place in project
3. Add attribution entry:
   ```json
   {
     "asset_path": "assets/sprites/custom/player_ship.png",
     "asset_type": "sprite",
     "author": "Jane Doe",
     "license": "CC-BY",
     "source_url": "https://janedoe.art",
     "modifications": "None",
     "date_added": "2025-10-23",
     "notes": "Commissioned specifically for 10,000 Games"
   }
   ```
4. Validate and commit

### Workflow 4: Using Asset with Modifications

1. Download base asset (CC-BY or CC-BY-SA licensed)
2. Modify in image editor (recolor, crop, etc.)
3. Save modified version
4. Add attribution with modifications noted:
   ```json
   {
     "asset_path": "assets/sprites/enemies/modified_alien.png",
     "asset_type": "sprite",
     "author": "Original Author",
     "license": "CC-BY",
     "source_url": "https://source.com/original",
     "modifications": "Recolored from green to purple, resized from 64x64 to 32x32",
     "date_added": "2025-10-23"
   }
   ```
5. Validate and commit

---

## Best Practices

### DO:
- ✅ Add attribution BEFORE committing assets
- ✅ Use wildcards for asset packs
- ✅ Include source URLs
- ✅ Describe modifications accurately
- ✅ Run validation regularly
- ✅ Prefer CC0 and CC-BY licenses
- ✅ Keep `date_added` accurate

### DON'T:
- ❌ Commit assets without attribution
- ❌ Use "unknown" for author (if you don't know, don't use the asset)
- ❌ Forget to list modifications
- ❌ Use assets with NC (non-commercial) restrictions without careful consideration
- ❌ Mix incompatible licenses
- ❌ Assume "free" means "no attribution needed"

---

## Troubleshooting

### "Failed to load attribution.json"

**Cause**: JSON syntax error

**Fix**:
1. Open `attribution.json` in a JSON validator
2. Look for missing commas, brackets, or quotes
3. Fix syntax errors
4. Test again

**Tip**: Most code editors have built-in JSON validation.

### "Asset has no attribution but shouldn't"

**Cause**: Path mismatch or wildcard not matching

**Fix**:
1. Check exact path: `assets/sprites/file.png` vs `assets/sprite/file.png`
2. Ensure forward slashes: `assets/sprites/` not `assets\sprites\`
3. Test wildcard: If `assets/sprites/*` isn't matching `assets/sprites/subdir/file.png`, use `assets/sprites/**/*` or be more specific

### "Validation script says 0 assets found"

**Cause**: Script not finding asset directories

**Fix**:
1. Run from project root: `lua scripts/validate_attribution.lua`
2. Ensure `assets/` directory exists
3. Check script is scanning correct directories (modify `asset_dirs` in script if needed)

### "Credits screen is empty"

**Cause**: No attributions in JSON or loading failed

**Fix**:
1. Check `attribution.json` has entries in `attributions` array
2. Check console for loading errors
3. Verify JSON syntax is correct
4. Ensure `attributionManager` is in DI container

---

## Examples

### Example 1: Single Sprite

```json
{
  "asset_path": "assets/sprites/icons/game_icon.png",
  "asset_type": "sprite",
  "author": "Kenney",
  "license": "CC0",
  "source_url": "https://kenney.nl/assets/game-icons",
  "modifications": "None",
  "date_added": "2025-10-23",
  "notes": "32x32 game controller icon"
}
```

### Example 2: Music Track

```json
{
  "asset_path": "assets/audio/music/space_theme.ogg",
  "asset_type": "music",
  "author": "Kevin MacLeod",
  "license": "CC-BY",
  "source_url": "https://incompetech.com/music/royalty-free/music.html",
  "modifications": "Trimmed to 2:30 loop",
  "date_added": "2025-10-23",
  "notes": "Used for Space Defender level 1-5"
}
```

### Example 3: Sound Effect Pack (Wildcard)

```json
{
  "asset_path": "assets/audio/sfx/retro_beeps/*",
  "asset_type": "sfx",
  "author": "SubspaceAudio",
  "license": "CC0",
  "source_url": "https://freesound.org/people/SubspaceAudio/packs/1234/",
  "modifications": "None",
  "date_added": "2025-10-23",
  "notes": "8-bit style SFX pack, 12 sounds"
}
```

### Example 4: Font

```json
{
  "asset_path": "assets/fonts/pixel_font.ttf",
  "asset_type": "font",
  "author": "Style-7",
  "license": "CC-BY-SA",
  "source_url": "https://fontlibrary.org/en/font/pixel-font",
  "modifications": "None",
  "date_added": "2025-10-23",
  "notes": "Used for retro-style UI text"
}
```

### Example 5: Code Library

```json
{
  "asset_path": "lib/class.lua",
  "asset_type": "code",
  "author": "rxi",
  "license": "MIT",
  "source_url": "https://github.com/rxi/classic",
  "modifications": "None",
  "date_added": "2025-10-23",
  "notes": "Lightweight OOP class implementation for Lua"
}
```

### Example 6: Shader

```json
{
  "asset_path": "assets/shaders/palette_swap.glsl",
  "asset_type": "shader",
  "author": "John Doe",
  "license": "MIT",
  "source_url": "https://github.com/johndoe/love2d-shaders",
  "modifications": "Added tolerance parameter for compression artifacts",
  "date_added": "2025-10-23",
  "notes": "Used for runtime palette swapping of sprites"
}
```

---

## Integration with Game Improvement Plan

The Asset Attribution System is **Phase 0** of the Game Improvement Plan. It must be completed BEFORE adding assets in Phases 1-3.

**Timeline**:
- ✅ Phase 0 (Complete): Attribution system implemented
- Phase 1: Clone customization (will add sprite/audio attributions)
- Phase 2: Minigame graphics (will add many sprite attributions)
- Phase 3: Audio overhaul (will add music/SFX attributions)

**Key Integration Points**:

1. **During asset sourcing** (Phases 2-3): As you download assets, immediately add attributions
2. **Validation checkpoints**: Run validation after completing each phase
3. **Credits screen**: Automatically displays all added attributions

---

## Future Enhancements

Potential improvements (not currently planned):

- **Asset manager integration**: Automatically query attribution on asset load
- **License compatibility checker**: Warn about incompatible license combinations
- **Export to text file**: Generate CREDITS.txt for distribution
- **Web scraping**: Auto-fetch license info from known sources (OpenGameArt, Freesound)
- **Duplicate detection**: Warn if same asset is attributed multiple times

---

## Reference

### Supported Asset Types

| Type | Extensions | Example Path |
|------|-----------|--------------|
| `sprite` | .png, .jpg | `assets/sprites/player.png` |
| `music` | .ogg, .mp3, .wav | `assets/audio/music/theme.ogg` |
| `sfx` | .ogg, .wav | `assets/audio/sfx/jump.ogg` |
| `font` | .ttf, .otf | `assets/fonts/game_font.ttf` |
| `shader` | .glsl | `assets/shaders/blur.glsl` |
| `code` | .lua | `lib/library.lua` |
| `other` | * | Any other asset |

### Common License Summary

| License | Attribution Required | Share-Alike | Commercial Use | Modifications |
|---------|---------------------|-------------|----------------|---------------|
| CC0 | No* | No | Yes | Yes |
| CC-BY | Yes | No | Yes | Yes |
| CC-BY-SA | Yes | Yes | Yes | Yes |
| MIT | Yes** | No | Yes | Yes |
| Apache 2.0 | Yes** | No | Yes | Yes |

*We attribute anyway for transparency
**Attribution via LICENSE file, not per-asset

### Useful Asset Sources

- **OpenGameArt.org** - Game sprites, music, SFX (various CC licenses)
- **Kenney.nl** - Massive asset packs (CC0)
- **Itch.io** - Game assets (various licenses)
- **Freesound.org** - Sound effects (various CC licenses)
- **Incompetech** - Music by Kevin MacLeod (CC-BY)
- **FontLibrary.org** - Open fonts (various licenses)

---

## Support

**Questions?** See:
- `documentation/Game Improvement Plan.md` (Phase 0 section)
- `assets/data/attribution.json` (examples in file)
- `src/utils/attribution_manager.lua` (API reference)

**Issues?** Report in project issue tracker or consult `documentation/todo.txt`

---

**Last Updated**: 2025-10-23
**System Version**: 1.0
**Status**: Production Ready ✅
