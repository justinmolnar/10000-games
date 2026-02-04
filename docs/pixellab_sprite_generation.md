# PixelLab Sprite Generation

Two scripts for generating pixel art sprites via PixelLab API.

## Scripts

| Script | Purpose | Output |
|--------|---------|--------|
| `pixellab_batch_generator_pixflux.py` | Single sprites (objects, icons, items) | 1 PNG per sprite |
| `pixellab_character_generator.py` | Multi-directional characters (enemies, NPCs) | 8 PNGs per character |

---

## 1. Single Sprites (pixflux)

For items, collectibles, objects, icons - anything that doesn't need multiple facings.

### Command
```
python scripts/pixellab_batch_generator_pixflux.py <config.json>
```

### JSON Structure
```json
{
  "session_name": "my_sprites",
  "description": "Optional description",
  "sprite_type": "pixflux",
  "sprite_groups": [
    {
      "name": "group_name",
      "output_folder": "assets/sprites/destination/folder",
      "default_params": {
        "width": 64,
        "height": 64,
        "view": "high top-down",
        "detail": "medium detail",
        "shading": "basic shading",
        "outline": "single color outline"
      },
      "sprites": [
        {"id": "sprite_id", "prompt": "description of sprite"},
        {"id": "another_sprite", "prompt": "description", "params": {"width": 32, "height": 32}}
      ]
    }
  ]
}
```

### Parameters

| Parameter | Options | Notes |
|-----------|---------|-------|
| `width` | 16-128 | Pixel width |
| `height` | 16-128 | Pixel height |
| `view` | `"side"`, `"low top-down"`, `"high top-down"` | Camera angle |
| `detail` | `"low detail"`, `"medium detail"`, `"highly detailed"` | Complexity |
| `shading` | `"flat shading"`, `"basic shading"`, `"medium shading"`, `"detailed shading"`, `"highly detailed shading"` | Lighting |
| `outline` | `"lineless"`, `"single color outline"`, `"single color black outline"`, `"selective outline"` | Edge style |

### Example: Collectibles
```json
{
  "session_name": "collectibles",
  "sprite_type": "pixflux",
  "sprite_groups": [
    {
      "name": "food_items",
      "output_folder": "assets/sprites/shared/collectibles",
      "default_params": {
        "width": 32,
        "height": 32,
        "view": "high top-down",
        "detail": "medium detail",
        "shading": "basic shading",
        "outline": "single color outline"
      },
      "sprites": [
        {"id": "apple", "prompt": "red apple, shiny, fresh fruit"},
        {"id": "coin", "prompt": "gold coin, shiny metallic"},
        {"id": "heart", "prompt": "red heart, health pickup"}
      ]
    }
  ]
}
```

---

## 2. Multi-Directional Characters

For enemies, NPCs, players - anything that needs to face different directions.

### Command
```
python scripts/pixellab_character_generator.py <config.json>
```

### JSON Structure
```json
{
  "session_name": "my_characters",
  "sprite_groups": [
    {
      "name": "group_name",
      "output_folder": "assets/sprites/destination/folder",
      "default_params": {
        "width": 64,
        "height": 64,
        "detail": "medium detail",
        "shading": "basic shading",
        "outline": "single color outline"
      },
      "characters": [
        {"id": "char_id", "prompt": "description of character"},
        {"id": "another_char", "prompt": "description", "params": {"width": 128, "height": 128}}
      ]
    }
  ]
}
```

### Output Files

Each character generates 8 PNG files:
```
{char_id}_front.png
{char_id}_front_left.png
{char_id}_left.png
{char_id}_back_left.png
{char_id}_back.png
{char_id}_back_right.png
{char_id}_right.png
{char_id}_front_right.png
```

### Example: Wolf3D Guards
```json
{
  "session_name": "wolf3d_enemies",
  "sprite_groups": [
    {
      "name": "guards",
      "output_folder": "assets/sprites/games/raycaster/enemies",
      "default_params": {
        "width": 64,
        "height": 64,
        "detail": "low detail",
        "shading": "basic shading",
        "outline": "single color outline"
      },
      "characters": [
        {"id": "guard_brown", "prompt": "enemy soldier brown uniform"},
        {"id": "guard_blue", "prompt": "military guard blue uniform"},
        {"id": "mutant", "prompt": "mutant soldier greenish skin tattered uniform"},
        {"id": "officer", "prompt": "military officer white shirt"}
      ]
    }
  ]
}
```

---

## Tips

### Prompts
- Keep prompts concise but descriptive
- Avoid trademarked names (no "nazi", "wolfenstein", etc.)
- Describe colors, clothing, pose

### Sizes
- 32x32: Small items, icons
- 64x64: Standard game sprites (Wolf3D size)
- 128x128: Detailed characters

### Processing Time
- Single sprites: ~5-10 seconds each
- 8-direction characters: ~2-5 minutes each (async processing)

### Rate Limiting
Scripts include 3-second delays between requests to avoid rate limits.

---

## Config File Location

Store configs in:
```
assets/data/sprite_generation_sessions/
```

## Session Metadata

After completion, scripts save metadata to:
```
session_{session_name}_metadata.json
```

Contains: generation times, file paths, success/failure status.
