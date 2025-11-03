# Minigame Music Tracks

Music tracks for the 5 core minigames, organized by game type and variant.

## Format Specifications

**Format:** OGG Vorbis
**Bitrate:** 128 kbps
**Sample Rate:** 44.1 kHz
**Channels:** Stereo
**Loop:** Must loop seamlessly
**Duration:** 30-120 seconds per loop

## Required Tracks

### Dodge Game (3 tracks)

- **dodge_theme_1.ogg** - Upbeat, tense electronic
  - Tempo: 130-150 BPM
  - Mood: Focused, energetic
  - Style: Electronic, techno
  - Used by: Dodge Master variant

- **dodge_theme_2.ogg** - Fast-paced, aggressive
  - Tempo: 140-160 BPM
  - Mood: Intense, exciting
  - Style: Drum & bass, breakbeat
  - Used by: Dodge Deluxe variant

- **dodge_theme_3.ogg** - Chaotic, intense
  - Tempo: 150+ BPM
  - Mood: Frantic, overwhelming
  - Style: Hardcore, gabber
  - Used by: Dodge Chaos variant

### Hidden Object (5 tracks)

- **hidden_object_ambient_forest.ogg** - Calm nature ambience
  - Tempo: Ambient (no strong beat)
  - Mood: Peaceful, mysterious
  - Elements: Birds, wind, gentle melody
  - Used by: Hidden Treasures (forest) variant

- **hidden_object_ambient_mansion.ogg** - Mysterious, gothic
  - Tempo: 60-80 BPM
  - Mood: Eerie, suspenseful
  - Elements: Strings, pipe organ, creaking
  - Used by: Mansion Mysteries variant

- **hidden_object_ambient_beach.ogg** - Relaxing ocean sounds
  - Tempo: Ambient
  - Mood: Chill, tropical
  - Elements: Waves, seagulls, steel drums
  - Used by: Beach Bonanza variant

- **hidden_object_ambient_scifi.ogg** - Futuristic, spacey
  - Tempo: 90-110 BPM
  - Mood: Wonder, exploration
  - Elements: Synths, ambient pads, sci-fi effects
  - Used by: Space Station Seek variant

- **hidden_object_ambient_library.ogg** - Quiet, scholarly
  - Tempo: 70-85 BPM
  - Mood: Contemplative, studious
  - Elements: Classical strings, soft piano
  - Used by: Haunted Library variant

### Memory Match (4 tracks)

- **memory_theme_calm.ogg** - Gentle, focused
  - Tempo: 80-100 BPM
  - Mood: Serene, meditative
  - Style: Ambient, new age
  - Used by: Memory Match Classic variant

- **memory_theme_playful.ogg** - Light, fun
  - Tempo: 110-120 BPM
  - Mood: Cheerful, bouncy
  - Style: Casual game music
  - Used by: Memory Match Animals variant

- **memory_theme_sparkle.ogg** - Magical, whimsical
  - Tempo: 100-115 BPM
  - Mood: Enchanting, fairy-tale
  - Elements: Bells, chimes, light synths
  - Used by: Memory Match Gems variant

- **memory_theme_electronic.ogg** - Modern, digital
  - Tempo: 120-130 BPM
  - Mood: Sleek, technological
  - Style: Electro, synthwave
  - Used by: Memory Match Tech variant

### Snake (3 tracks)

- **snake_theme_retro.ogg** - Classic chiptune
  - Tempo: 120-140 BPM
  - Mood: Nostalgic, arcade
  - Style: NES/Game Boy chiptune
  - Used by: Snake Classic variant

- **snake_theme_electronic.ogg** - Neon vibes
  - Tempo: 125-140 BPM
  - Mood: Cool, stylish
  - Style: Synthwave, retrowave
  - Used by: Snake Neon variant

- **snake_theme_techno.ogg** - Modern, driving beat
  - Tempo: 130-145 BPM
  - Mood: Energetic, futuristic
  - Style: Techno, trance
  - Used by: Snake Modern variant

### Space Shooter (3 tracks)

- **space_shooter_theme_1.ogg** - Action-packed
  - Tempo: 135-150 BPM
  - Mood: Heroic, exciting
  - Style: Orchestral rock, power metal
  - Used by: Space Shooter Alpha variant

- **space_shooter_theme_2.ogg** - Intense combat
  - Tempo: 140-160 BPM
  - Mood: Aggressive, urgent
  - Style: Metal, industrial
  - Used by: Space Shooter Beta variant

- **space_shooter_theme_3.ogg** - Epic battle
  - Tempo: 145-165 BPM
  - Mood: Triumphant, grand
  - Style: Orchestral epic, cinematic
  - Used by: Space Shooter Omega variant

## Music Creation Tips

**Loop Points:**
- Ensure smooth transition from end to beginning
- Use audio editor (Audacity) to trim and fade
- Test loop 3-4 times to confirm no pops/clicks

**Mixing:**
- Leave headroom for SFX (-6dB peak max)
- Avoid overly loud or fatiguing frequencies
- Balance elements for looping (no single dominant melody)

**Inspiration Sources:**
- OpenGameArt.org - Free game music
- Incompetech - Royalty-free by Kevin MacLeod
- ccMixter - Remix-friendly tracks
- Newgrounds Audio Portal - Creative Commons music

## Attribution

When adding tracks, add to `assets/data/attribution.json`:

```json
{
  "asset_path": "assets/audio/music/minigames/dodge_theme_1.ogg",
  "author": "Artist Name",
  "license": "CC0 or CC-BY or CC-BY-SA",
  "source_url": "https://...",
  "modifications": "Trimmed loop, adjusted tempo, etc.",
  "date_added": "2025-10-25"
}
```

## Status

**Created:** 2025-10-25
**Tracks Added:** 0/18
**Complete:** ❌

Add music tracks to this directory and update this README when complete.
