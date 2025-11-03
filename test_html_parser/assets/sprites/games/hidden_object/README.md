# Hidden Object Game Assets

## Overview
This directory contains scene backgrounds and object sprites for Hidden Object game variants. Each scene folder represents a unique base sprite set.

## Directory Structure

### forest/
Forest/nature themed scene.

**Required Assets:**
- `background.png` - Scene background (640x480 or larger)
  - Dense forest scene with hiding spots
  - Natural green/brown color palette
  - Consider palette swapping for season variants (spring, autumn, winter)
- Object sprites (20-30 small items):
  - `object_01.png` through `object_30.png`
  - Examples: acorn, mushroom, butterfly, bird, flower, rock, etc.
  - Simple shapes with 2-3 main colors for palette swapping
  - 16x16 to 32x32 size

### mansion/
Gothic mansion interior scene.

**Required Assets:**
- `background.png` - Gothic mansion interior (640x480 or larger)
  - Dark, atmospheric Victorian setting
  - Gothic purple/grey palette
- Object sprites (20-30 items):
  - Mansion-themed: candelabra, portrait, key, goblet, clock, etc.

### beach/
Sandy beach scene.

**Required Assets:**
- `background.png` - Beach scene (640x480 or larger)
  - Sandy shores, ocean, palm trees
  - Sunny yellow/blue palette
- Object sprites (20-30 items):
  - Beach-themed: shell, starfish, crab, bottle, sunglasses, etc.

### space_station/
Sci-fi space station interior.

**Required Assets:**
- `background.png` - Space station (640x480 or larger)
  - Futuristic tech environment
  - Tech blue/cyan palette
- Object sprites (20-30 items):
  - Sci-fi themed: tablet, wrench, helmet, cable, panel, etc.

### library/
Haunted/dusty library scene.

**Required Assets:**
- `background.png` - Library interior (640x480 or larger)
  - Old books, dusty atmosphere
  - Dusty brown/sepia palette
- Object sprites (20-30 items):
  - Library-themed: book, quill, glasses, scroll, candle, etc.

## Palette System

**Note:** Hidden Object scenes are harder to palette-swap effectively due to complex backgrounds.

**Options:**
1. Create 5+ unique scenes without palettes (higher art workload)
2. Design scenes with limited colors for swapping (stylized/flat art style)
3. Swap objects only, keep background static

**If using palette swapping:**
- Use simple, bold colors for objects
- Background should have complementary neutral tones

## Asset Specifications

**Format:** PNG with transparency (for objects), PNG or JPG for backgrounds
**Background Size:** 640x480 minimum, 1920x1080 preferred
**Object Size:** 16x16 to 64x64 depending on detail
**Style:** Consistent style within each scene

## Object Placement

Objects should be:
- Not too large (defeats "hidden" purpose)
- Partially obscured by background elements
- Varied in size and orientation
- Clearly identifiable when found

## UI Elements (Shared)

UI elements can be shared across all scenes:
- Timer display
- Score display
- Object checklist
- Found/not found indicators

Store shared UI in `assets/sprites/games/hidden_object/ui/` (to be created if needed).

## Attribution

All assets must be documented in `assets/data/attribution.json` with:
- Author
- License
- Source URL
- Modifications (if any)
- Date added

## Variants Using These Assets

**Hidden Treasures** (hidden_object_1) - forest scene
**Mansion Mysteries** (hidden_object_2) - mansion scene
**Beach Bonanza** (hidden_object_3) - beach scene
**Space Station Seek** (hidden_object_4) - space_station scene
**Haunted Library** (hidden_object_5) - library scene

See `assets/data/base_game_definitions.json` for full variant configuration.
