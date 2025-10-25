# Phase 3.4 & 3.5: Audio Asset Checklist

**Status**: Architecture complete ✅ | Assets needed ⚠️

The audio system is fully implemented and ready to use. All code integration is done with graceful fallback - missing audio files will simply be silent (no crashes). You can add audio files progressively as you create/source them.

---

## Phase 3.4: Music Requirements

### What You Need to Do

Create or source **2-3 looping background music tracks per game type** (10-15 tracks total for minigames).

### Technical Specifications

- **Format**: `.ogg` (Vorbis codec)
- **Quality**: ~128kbps (balance between quality and file size)
- **Loop Length**: 30-60 seconds
- **Looping**: Must loop seamlessly (no clicks/pops when restarting)
- **Volume**: Normalized to prevent clipping, moderate volume (not too loud)

### Where to Place Files

All music goes in: `assets/audio/music/minigames/`

### Required Tracks by Game Type

#### **Dodge Game** (3 tracks needed)
- `dodge_theme_1.ogg` - Upbeat electronic, tense
- `dodge_theme_2.ogg` - More aggressive, faster tempo
- `dodge_theme_3.ogg` - Chaotic, intense

**Mood**: Tense, electronic, fast-paced

#### **Hidden Object** (3 tracks needed)
- `hidden_object_ambient_forest.ogg` - Ambient, mysterious
- `hidden_object_ambient_mansion.ogg` - Suspenseful, eerie
- `hidden_object_ambient_beach.ogg` - Calm, searching

**Mood**: Ambient, mysterious, atmospheric

#### **Memory Match** (3 tracks needed)
- `memory_match_calm_1.ogg` - Calm, focused
- `memory_match_calm_2.ogg` - Gentle, contemplative
- `memory_match_calm_3.ogg` - Soothing, meditative

**Mood**: Calm, focused, non-intrusive

#### **Snake** (3 tracks needed)
- `snake_retro_1.ogg` - Retro chiptune
- `snake_retro_2.ogg` - Classic 8-bit style
- `snake_retro_3.ogg` - Fast chiptune

**Mood**: Retro chiptune, 8-bit nostalgia

#### **Space Shooter** (3 tracks needed)
- `space_shooter_action_1.ogg` - Fast-paced action
- `space_shooter_action_2.ogg` - Intense combat
- `space_shooter_action_3.ogg` - High energy

**Mood**: Fast-paced action, combat energy

### Where to Source Music

#### Free/CC-Licensed Sources
- **OpenGameArt.org** - Many looping game tracks (CC0, CC-BY)
- **Incompetech** by Kevin MacLeod - Royalty-free music
- **FreeMusicArchive.org** - Various Creative Commons music
- **Itch.io** - Many free music packs for games

#### Create Your Own
- **Bosca Ceoil** - Free chiptune music creator (perfect for Snake)
- **LMMS** - Free DAW for creating fuller tracks
- **BeepBox** - Browser-based chiptune creator

#### License Requirements
- ✅ **CC0** (public domain) - Best option, no attribution required
- ✅ **CC-BY** (attribution) - Fine, we have attribution.json
- ✅ **CC-BY-SA** (share-alike) - Compatible with open source
- ❌ **Avoid NC/ND** - Non-commercial or no-derivatives restrictions

### Testing Your Music Tracks

1. Place the `.ogg` file in `assets/audio/music/minigames/`
2. Launch the game
3. Open the Launcher, select a game
4. Music should start automatically when the game begins
5. Check:
   - Does it loop seamlessly?
   - Is the volume appropriate?
   - Does it match the game's mood?

### Current Status

**Files Added**: 0 / 15 tracks
**Next Step**: Source or create first track (recommend starting with Snake - easiest to make chiptune)

---

## Phase 3.5: SFX Requirements

### What You Need to Do

Create or source **18 sound effects** organized into **3 SFX packs** (retro, modern, arcade).

### Technical Specifications

- **Format**: `.ogg` (Vorbis codec)
- **Quality**: ~96-128kbps
- **Duration**: 0.1 - 1.5 seconds (short, punchy)
- **Volume**: Normalized, not clipping
- **Mono vs Stereo**: Mono preferred (smaller file size)

### Where to Place Files

Each SFX pack has its own folder:
```
assets/audio/sfx/packs/
├── retro_beeps/
├── modern_ui/
└── 8bit_arcade/
```

### Required Sounds per Pack (18 sounds × 3 packs = 54 files total)

Each pack needs these sounds:

#### **Universal Sounds** (used by multiple games)
1. `hit.ogg` - Player takes damage (impact sound)
2. `death.ogg` - Player loses/dies (dramatic failure sound)
3. `success.ogg` - Level complete (victory jingle)
4. `collect.ogg` - Pick up item (positive chime)

#### **Dodge Game Sounds**
5. `dodge.ogg` - Successfully avoided obstacle (subtle whoosh)
6. `boost.ogg` - Speed boost activated (not yet implemented)

#### **Hidden Object Sounds**
7. `find_object.ogg` - Found hidden object (positive ding)
8. `wrong_click.ogg` - Clicked wrong area (negative beep)

#### **Memory Match Sounds**
9. `flip_card.ogg` - Card flipped (card whoosh)
10. `match.ogg` - Cards matched (positive chime)
11. `mismatch.ogg` - Cards don't match (negative buzz)

#### **Snake Sounds**
12. `eat.ogg` - Ate food (crunch/munch)
13. `grow.ogg` - Snake grew (not yet implemented)
14. `turn.ogg` - Snake turned (not yet implemented)

#### **Space Shooter Sounds**
15. `shoot.ogg` - Player fires weapon (laser/bullet sound)
16. `enemy_explode.ogg` - Enemy destroyed (explosion)

#### **Bonus/Future Sounds**
17. `select.ogg` - Menu/UI interaction (not yet implemented)
18. `powerup.ogg` - Power-up collected (not yet implemented)

### Sound Characteristics by Pack

#### **retro_beeps** (8-bit style)
- Sound style: Chiptune, synthesized beeps
- Aesthetic: Retro arcade, Atari/NES era
- Tools: Bfxr, ChipTone
- Volume: Moderate, crisp

#### **modern_ui** (clean, polished)
- Sound style: Clean, professional UI sounds
- Aesthetic: Modern, smooth, refined
- Tools: Freesound.org, Audacity editing
- Volume: Moderate, balanced

#### **8bit_arcade** (energetic, punchy)
- Sound style: Punchy arcade sounds
- Aesthetic: Energetic, satisfying feedback
- Tools: Bfxr with aggressive settings
- Volume: Slightly louder, impactful

### Where to Source SFX

#### Free Tools to Create Sounds
- **Bfxr** - Browser-based retro SFX generator (perfect for retro_beeps and 8bit_arcade)
  - Visit: https://www.bfxr.net/
  - Generate → Export as `.wav` → Convert to `.ogg`
- **ChipTone** - Another excellent 8-bit sound generator
- **Audacity** - Free audio editor for converting/editing

#### Free SFX Sources
- **Freesound.org** - Huge library of CC-licensed sounds
- **OpenGameArt.org** - Game-specific SFX collections
- **Kenney.nl** - CC0 game assets including SFX
- **Itch.io** - Free SFX packs

### File Naming & Organization

Example for **retro_beeps** pack:
```
assets/audio/sfx/packs/retro_beeps/
├── hit.ogg
├── death.ogg
├── success.ogg
├── collect.ogg
├── dodge.ogg
├── boost.ogg
├── find_object.ogg
├── wrong_click.ogg
├── flip_card.ogg
├── match.ogg
├── mismatch.ogg
├── eat.ogg
├── grow.ogg
├── turn.ogg
├── shoot.ogg
├── enemy_explode.ogg
├── select.ogg
└── powerup.ogg
```

**IMPORTANT**: File names must match exactly - the code looks for these specific names.

### Testing Your SFX

1. Place `.ogg` files in the appropriate pack folder (e.g., `retro_beeps/`)
2. Launch the game
3. Play any minigame (they all use `sfx_pack: "retro_beeps"` by default)
4. Trigger events:
   - **Dodge**: Hit an obstacle → `hit.ogg`
   - **Snake**: Eat food → `eat.ogg`
   - **Memory Match**: Flip card → `flip_card.ogg`
   - **Hidden Object**: Click object → `find_object.ogg`
   - **Space Shooter**: Fire weapon → `shoot.ogg`
5. Complete a game → `success.ogg`

### Converting WAV to OGG

If you generate `.wav` files, convert to `.ogg`:

**Using Audacity**:
1. File → Open → Select `.wav` file
2. File → Export → Export as OGG Vorbis
3. Quality: 5-6 (roughly 128kbps)
4. Save with correct filename

**Using ffmpeg** (command line):
```bash
ffmpeg -i input.wav -c:a libvorbis -q:a 5 output.ogg
```

### Current Status

**Files Added**: 0 / 54 sounds
**Packs Completed**: 0 / 3

### Recommended Priority Order

1. **Start with retro_beeps** (easiest to generate with Bfxr)
2. Focus on universal sounds first (hit, death, success) - used by all games
3. Add game-specific sounds one game at a time
4. Test each sound as you add it
5. Once retro_beeps is complete, copy structure for modern_ui and 8bit_arcade

---

## Quick Start Guide

### Fastest Way to Get Started (15 minutes)

1. **Open Bfxr** (https://www.bfxr.net/)
2. **Generate these 4 sounds**:
   - Click "Pickup/Coin" → Tweak → Export as `success.wav`
   - Click "Hit/Hurt" → Tweak → Export as `hit.wav`
   - Click "Explosion" → Tweak → Export as `death.wav`
   - Click "Laser/Shoot" → Tweak → Export as `shoot.wav`
3. **Convert to OGG** (using Audacity or ffmpeg)
4. **Place in** `assets/audio/sfx/packs/retro_beeps/`
5. **Launch game and test**!

You'll immediately hear sounds in Space Shooter (shoot), Dodge (hit, death), and any completed game (success).

---

## Attribution Requirements

**IMPORTANT**: For every audio file you add, update `assets/data/attribution.json`:

```json
{
  "asset_path": "assets/audio/music/minigames/dodge_theme_1.ogg",
  "author": "Kevin MacLeod",
  "license": "CC-BY",
  "source_url": "https://incompetech.com/music/",
  "modifications": "Looped and normalized volume",
  "date_added": "2025-10-25"
}
```

Or for bulk SFX packs generated with Bfxr:
```json
{
  "asset_path": "assets/audio/sfx/packs/retro_beeps/*",
  "author": "Generated with Bfxr (public domain tool)",
  "license": "CC0",
  "source_url": "https://www.bfxr.net/",
  "modifications": "Generated and exported as OGG",
  "date_added": "2025-10-25"
}
```

---

## Progress Tracking

### Phase 3.4: Music Tracks
- [ ] Dodge Theme 1
- [ ] Dodge Theme 2
- [ ] Dodge Theme 3
- [ ] Hidden Object Ambient 1
- [ ] Hidden Object Ambient 2
- [ ] Hidden Object Ambient 3
- [ ] Memory Match Calm 1
- [ ] Memory Match Calm 2
- [ ] Memory Match Calm 3
- [ ] Snake Retro 1
- [ ] Snake Retro 2
- [ ] Snake Retro 3
- [ ] Space Shooter Action 1
- [ ] Space Shooter Action 2
- [ ] Space Shooter Action 3

### Phase 3.5: SFX Packs

**retro_beeps pack**:
- [ ] hit.ogg
- [ ] death.ogg
- [ ] success.ogg
- [ ] collect.ogg
- [ ] dodge.ogg
- [ ] boost.ogg
- [ ] find_object.ogg
- [ ] wrong_click.ogg
- [ ] flip_card.ogg
- [ ] match.ogg
- [ ] mismatch.ogg
- [ ] eat.ogg
- [ ] grow.ogg
- [ ] turn.ogg
- [ ] shoot.ogg
- [ ] enemy_explode.ogg
- [ ] select.ogg
- [ ] powerup.ogg

**modern_ui pack**:
- [ ] (same 18 sounds, different style)

**8bit_arcade pack**:
- [ ] (same 18 sounds, different style)

---

## Summary

✅ **Code Complete**: All audio integration is done
✅ **Architecture Ready**: AudioManager, BaseGame helpers, game integration
✅ **Graceful Fallback**: Missing files = silent (no crashes)

⚠️ **Your Action Required**: Source or create audio files and place them in the correct folders

**Estimated Time**:
- Phase 3.4 (Music): 3-6 hours (sourcing) or 10-20 hours (creating custom)
- Phase 3.5 (SFX): 2-4 hours (generating with Bfxr) or 5-10 hours (custom/sourcing)

**Recommended Approach**: Start with Bfxr-generated retro_beeps pack (fastest), then add music tracks from free sources (OpenGameArt, Incompetech).
