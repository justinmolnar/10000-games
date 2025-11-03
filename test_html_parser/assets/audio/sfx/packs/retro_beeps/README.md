# Retro Beeps SFX Pack

**Theme:** Classic 8-bit style sound effects
**Style:** NES/Game Boy era chiptune sounds
**Mood:** Nostalgic, retro, arcade

## Required Sounds

All sounds should be in OGG Vorbis format, 96-128 kbps, short duration (0.1-3 seconds).

### Universal Game Sounds

- **jump.ogg** - 8-bit jump/hop sound (classic boing)
- **hit.ogg** - Player collision/damage (harsh beep)
- **collect.ogg** - Pick up item/token (ascending chime)
- **death.ogg** - Player loses/dies (descending sad beep)
- **success.ogg** - Level complete (victory fanfare, 2-3 seconds)
- **select.ogg** - Menu/UI selection (short blip)

### Dodge Game Specific

- **dodge.ogg** - Successfully avoid obstacle (quick whoosh)
- **boost.ogg** - Speed boost activated (power-up sound)

### Hidden Object Specific

- **find_object.ogg** - Correctly click object (positive ding)
- **wrong_click.ogg** - Click empty space (negative buzz)

### Memory Match Specific

- **flip_card.ogg** - Card flips over (soft flip sound)
- **match.ogg** - Cards match (happy chime)
- **mismatch.ogg** - Cards don't match (disappointed buzz)

### Snake Specific

- **eat.ogg** - Eat food (chomp/gulp)
- **grow.ogg** - Snake grows (can be same as eat)
- **turn.ogg** - Change direction (optional, subtle)

### Space Shooter Specific

- **shoot.ogg** - Fire bullet (classic pew-pew)
- **enemy_explode.ogg** - Enemy destroyed (explosion)

## Sound Design Guidelines

**Frequency Range:** Focus on mid-high frequencies (classic NES range)
**Waveforms:** Square waves, triangle waves, noise channel
**Effects:** Minimal reverb/delay (authentic 8-bit feel)
**Volume:** Consistent across pack, normalized

## Creation Tools

- **Bfxr** - Classic retro SFX generator
- **ChipTone** - Advanced chiptune SFX
- **SFXR** - Original 8-bit sound maker
- **FamiStudio** - NES-style sound effects

## Reference Examples

Listen to classic NES/Game Boy games:
- Super Mario Bros. (jump, collect, death)
- Mega Man (shoot, hit, explode)
- Tetris (select, success)
- Pac-Man (eat, death)

## Attribution

When adding sounds to this pack, add to `assets/data/attribution.json`:

```json
{
  "asset_path": "assets/audio/sfx/packs/retro_beeps/jump.ogg",
  "author": "Artist Name or Source",
  "license": "CC0 or CC-BY",
  "source_url": "https://...",
  "modifications": "None or describe changes",
  "date_added": "2025-10-25"
}
```

## Status

**Created:** 2025-10-25
**Sounds Added:** 0/18
**Pack Complete:** ❌

Add sounds to this directory and update this README when complete.
