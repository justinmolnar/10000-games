# Audio Assets Overview

This directory contains all audio assets for the 10,000 Games Collection, organized by category and purpose.

## Phase 3.1: Audio Asset Organization - COMPLETE

**Status:** ✅ Directory structure created and documented
**Date:** 2025-10-25
**Phase:** Game Improvement Plan - Phase 3.1

## Directory Structure

```
assets/audio/
├── music/
│   ├── minigames/           # Music for minigames
│   │   ├── dodge_theme_1.ogg
│   │   ├── dodge_theme_2.ogg
│   │   ├── dodge_theme_3.ogg
│   │   ├── hidden_object_ambient_forest.ogg
│   │   ├── hidden_object_ambient_mansion.ogg
│   │   ├── hidden_object_ambient_beach.ogg
│   │   ├── hidden_object_ambient_scifi.ogg
│   │   ├── hidden_object_ambient_library.ogg
│   │   ├── memory_theme_calm.ogg
│   │   ├── memory_theme_playful.ogg
│   │   ├── memory_theme_sparkle.ogg
│   │   ├── memory_theme_electronic.ogg
│   │   ├── snake_theme_retro.ogg
│   │   ├── snake_theme_electronic.ogg
│   │   ├── snake_theme_techno.ogg
│   │   ├── space_shooter_theme_1.ogg
│   │   ├── space_shooter_theme_2.ogg
│   │   └── space_shooter_theme_3.ogg
│   ├── standalones/         # Music for standalone games
│   │   ├── space_defender_tier_1.ogg
│   │   ├── space_defender_tier_2.ogg
│   │   ├── space_defender_tier_3.ogg
│   │   ├── space_defender_tier_4.ogg
│   │   ├── space_defender_tier_5.ogg
│   │   ├── space_defender_boss_battle.ogg
│   │   ├── space_defender_victory.ogg
│   │   └── solitaire_calm.ogg
│   └── os/                  # OS/Desktop music
│       ├── desktop_theme_default.ogg
│       └── startup.ogg
├── sfx/
│   ├── packs/               # SFX packs for games
│   │   ├── retro_beeps/     # Classic 8-bit style
│   │   │   ├── jump.ogg
│   │   │   ├── hit.ogg
│   │   │   ├── collect.ogg
│   │   │   ├── death.ogg
│   │   │   ├── success.ogg
│   │   │   ├── dodge.ogg
│   │   │   ├── boost.ogg
│   │   │   ├── find_object.ogg
│   │   │   ├── wrong_click.ogg
│   │   │   ├── flip_card.ogg
│   │   │   ├── match.ogg
│   │   │   ├── mismatch.ogg
│   │   │   ├── eat.ogg
│   │   │   ├── grow.ogg
│   │   │   ├── turn.ogg
│   │   │   ├── shoot.ogg
│   │   │   ├── enemy_explode.ogg
│   │   │   └── select.ogg
│   │   ├── modern_ui/       # Clean, polished sounds
│   │   │   └── (same files as retro_beeps)
│   │   └── 8bit_arcade/     # Energetic arcade sounds
│   │       └── (same files as retro_beeps)
│   └── os/                  # OS/Desktop sound effects
│       ├── window_open.ogg
│       ├── window_close.ogg
│       ├── window_minimize.ogg
│       ├── window_maximize.ogg
│       ├── button_click.ogg
│       ├── dropdown_open.ogg
│       ├── error.ogg
│       ├── notification.ogg
│       ├── start_menu_open.ogg
│       ├── start_menu_close.ogg
│       ├── icon_click.ogg
│       ├── file_copy.ogg
│       ├── file_delete.ogg
│       ├── file_move.ogg
│       └── recycle_bin_empty.ogg
└── data/
    └── sfx_packs.json       # SFX pack definitions
```

## Audio Format Specifications

**Format:** OGG Vorbis
**Why OGG:** Open format, excellent compression, widely supported by LÖVE2D

**Music Specifications:**
- **Bitrate:** 128 kbps (good balance of quality/size)
- **Sample Rate:** 44.1 kHz
- **Channels:** Stereo (2.0)
- **Loop:** Must loop seamlessly (no pops/clicks)
- **Duration:** 30-120 seconds per loop

**SFX Specifications:**
- **Bitrate:** 96-128 kbps (SFX less sensitive to compression)
- **Sample Rate:** 44.1 kHz
- **Channels:** Mono or Stereo
- **Duration:** 0.1-3 seconds (short and punchy)

## SFX Pack System

**Purpose:** Games can use different SFX packs for variety without changing code

**How It Works:**
1. Each SFX pack has the same action names (`hit`, `collect`, `death`, etc.)
2. Games reference actions by name: `audioManager:playSound(sfx_pack, "hit")`
3. Variants specify which SFX pack to use: `"sfx_pack": "retro_beeps"`
4. AudioManager loads the appropriate sound from the pack

**Benefits:**
- Easy to swap entire sound theme per variant
- Consistent API across all games
- Can add new packs without modifying game code

**Pack Definitions:**
See `assets/audio/data/sfx_packs.json` for the mapping of action names to file paths.

## Music Requirements by Game Type

### Minigames

**Dodge Game** (3 tracks):
- `dodge_theme_1.ogg` - Upbeat, tense electronic
- `dodge_theme_2.ogg` - Fast-paced, aggressive
- `dodge_theme_3.ogg` - Chaotic, intense

**Hidden Object** (5 tracks):
- `hidden_object_ambient_forest.ogg` - Calm nature ambience
- `hidden_object_ambient_mansion.ogg` - Mysterious, gothic
- `hidden_object_ambient_beach.ogg` - Relaxing ocean sounds
- `hidden_object_ambient_scifi.ogg` - Futuristic, spacey
- `hidden_object_ambient_library.ogg` - Quiet, scholarly

**Memory Match** (4 tracks):
- `memory_theme_calm.ogg` - Gentle, focused
- `memory_theme_playful.ogg` - Light, fun
- `memory_theme_sparkle.ogg` - Magical, whimsical
- `memory_theme_electronic.ogg` - Modern, digital

**Snake** (3 tracks):
- `snake_theme_retro.ogg` - Classic chiptune
- `snake_theme_electronic.ogg` - Neon vibes
- `snake_theme_techno.ogg` - Modern, driving beat

**Space Shooter** (3 tracks):
- `space_shooter_theme_1.ogg` - Action-packed
- `space_shooter_theme_2.ogg` - Intense combat
- `space_shooter_theme_3.ogg` - Epic battle

### Standalones

**Space Defender** (7+ tracks):
- `space_defender_tier_1.ogg` - Levels 1-5
- `space_defender_tier_2.ogg` - Levels 6-10
- `space_defender_tier_3.ogg` - Levels 11-15
- `space_defender_tier_4.ogg` - Levels 16-20
- `space_defender_tier_5.ogg` - Levels 21-25
- `space_defender_boss_battle.ogg` - Boss encounters
- `space_defender_victory.ogg` - Victory jingle (short)

**Solitaire** (1-2 tracks):
- `solitaire_calm.ogg` - Relaxing background music

### OS/Desktop

**Desktop** (2 tracks):
- `desktop_theme_default.ogg` - Subtle ambient loop
- `startup.ogg` - Boot-up jingle (3-5 seconds)

## SFX Requirements

### Universal Game Sounds

**Common Actions** (needed by most games):
- `hit` - Player takes damage or collision
- `death` - Player loses/dies
- `success` - Level complete or win
- `collect` - Pick up item/token
- `select` - Menu/UI selection

### Game-Specific Sounds

**Dodge Game:**
- `dodge` - Successfully avoid obstacle (optional)
- `boost` - Speed boost or power-up

**Hidden Object:**
- `find_object` - Correctly click object
- `wrong_click` - Click empty space or wrong object

**Memory Match:**
- `flip_card` - Card flips over
- `match` - Cards match (positive)
- `mismatch` - Cards don't match (negative)

**Snake:**
- `eat` - Eat food
- `grow` - Snake grows (may be same as eat)
- `turn` - Change direction (optional)

**Space Shooter:**
- `shoot` - Fire bullet
- `enemy_explode` - Enemy destroyed

### OS/Desktop Sounds

**Window Operations:**
- `window_open.ogg`
- `window_close.ogg`
- `window_minimize.ogg`
- `window_maximize.ogg`

**UI Interactions:**
- `button_click.ogg`
- `dropdown_open.ogg`
- `error.ogg`
- `notification.ogg`

**Desktop:**
- `start_menu_open.ogg`
- `start_menu_close.ogg`
- `icon_click.ogg`

**File Operations:**
- `file_copy.ogg`
- `file_delete.ogg`
- `file_move.ogg`
- `recycle_bin_empty.ogg`

## Asset Sourcing

**Recommended Sources:**
- **OpenGameArt.org** - Music and SFX (CC0, CC-BY)
- **Freesound.org** - SFX library (various CC licenses)
- **Incompetech** - Royalty-free music by Kevin MacLeod
- **ccMixter** - Remix-friendly music tracks
- **Zapsplat** - Free SFX (requires attribution)

**License Priorities:**
1. **CC0** (public domain) - Preferred
2. **CC-BY** (attribution required) - Acceptable
3. **CC-BY-SA** (attribution + share-alike) - Compatible

**Avoid:** NC (non-commercial) or ND (no-derivatives) licenses

## Creating Your Own Audio

**Music:**
- **LMMS** (free DAW) - Full music production
- **Bosca Ceoil** (free) - Simple chiptune creation
- **BeepBox** - Browser-based chiptune maker
- **FamiStudio** - NES-style music tracker

**SFX:**
- **Bfxr** - Classic 8-bit SFX generator
- **ChipTone** - Advanced chiptune SFX
- **Audacity** (free) - Record/edit/mix sounds
- **SFXR** - Original retro SFX generator

## Attribution Requirements

**CRITICAL:** All audio assets MUST be documented in `assets/data/attribution.json` before use.

Required fields:
- `asset_path` - Path to audio file
- `author` - Creator/artist name
- `license` - License type (CC0, CC-BY, CC-BY-SA)
- `source_url` - Where asset was obtained
- `modifications` - Any changes made (tempo, pitch, trimming, etc.)
- `date_added` - When asset was added

See **Game Improvement Plan - Phase 0** for attribution system details.

## Integration with Code

**Variant System Integration:**
Each game variant specifies:
- `music_track` - Music file to play (e.g., "dodge_theme_1")
- `sfx_pack` - SFX pack name (e.g., "retro_beeps")

**Example from base_game_definitions.json:**
```json
{
  "clone_index": 0,
  "name": "Dodge Master",
  "music_track": "assets/audio/music/minigames/dodge_theme_1.ogg",
  "sfx_pack": "retro_beeps"
}
```

**AudioManager Usage:**
```lua
-- Load music from variant
self.music = audioManager:loadMusic(variant.music_track)

-- Load SFX pack from variant
self.sfx = audioManager:loadSFXPack(variant.sfx_pack)

-- Play sound from pack
audioManager:playSound(variant.sfx_pack, "hit", 0.7)
```

## Testing Checklist

**Per Music Track:**
- [ ] Loops seamlessly (no gap or pop at loop point)
- [ ] Appropriate mood for game/scene
- [ ] Volume balanced (not too loud/quiet)
- [ ] File size reasonable (< 5MB for looping tracks)

**Per SFX:**
- [ ] Clear and punchy
- [ ] Not jarring or annoying after repeated plays
- [ ] Appropriate duration (short for instant feedback)
- [ ] Matches pack theme (retro vs modern vs arcade)

**System Integration:**
- [ ] All SFX packs have consistent action names
- [ ] Games correctly load variant music tracks
- [ ] SFX plays on correct events
- [ ] Volume controls work (master, music, SFX)
- [ ] No audio glitches or crackling

## Next Steps (Phase 3.2+)

Once audio organization is complete:

1. **Phase 3.2:** Implement SFX Pack System
   - Create AudioManager with SFX pack loading
   - Load and parse sfx_packs.json
   - Support playSound(pack, action) API

2. **Phase 3.3:** Game Audio Integration
   - Update game classes to load music and SFX
   - Play sounds on game events
   - Volume mixing and controls

3. **Phase 3.4+:** Source/create actual audio assets
   - Find or create music tracks
   - Find or create SFX packs
   - Add to attribution.json

See `documentation/Game Improvement Plan.md` for full roadmap.

## Notes

- **Phase 3.1 is organizational only** - No actual audio files created yet
- Audio will be added progressively in Phase 3.2+
- Directory structure designed for easy expansion
- SFX pack system enables flexible variant audio without code changes

---

**Phase 3.1 Complete:** Audio asset organization structure ready for population.
**Next Phase:** Phase 3.2 - SFX Pack System Implementation
