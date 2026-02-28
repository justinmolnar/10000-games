# ElevenLabs Audio Generation

One script for generating audio via ElevenLabs API. Supports three modes.

## Script

| Mode | Purpose | Output |
|------|---------|--------|
| `tts` | Voice lines, narration, UI callouts | 1 MP3 per clip (requires `voice_id`) |
| `sfx` | Sound effects, ambient loops, UI sounds | 1 MP3 per clip (text prompt describes sound) |
| `music` | Full tracks, jingles, themed albums | 1 MP3 per clip (prompt or composition plan) |

---

## Command

```
python scripts/elevenlabs_batch_generator.py <config.json>
python scripts/elevenlabs_batch_generator.py --list-voices
python scripts/elevenlabs_batch_generator.py --list-models
```

---

## 1. Sound Effects (sfx)

For game sounds, UI clicks, ambient loops - anything described by a text prompt.

### JSON Structure
```json
{
  "session_name": "my_sounds",
  "description": "Optional description",
  "safety_delay": 3,
  "audio_groups": [
    {
      "name": "group_name",
      "type": "sfx",
      "output_folder": "assets/audio/sfx",
      "default_params": {
        "output_format": "mp3_44100_128",
        "prompt_influence": 0.4
      },
      "clips": [
        {"id": "clip_id", "text": "description of the sound", "params": {"duration_seconds": 1.0}},
        {"id": "loop_clip", "text": "description", "params": {"duration_seconds": 5.0, "loop": true}}
      ]
    }
  ]
}
```

### SFX Parameters

| Parameter | Options | Notes |
|-----------|---------|-------|
| `duration_seconds` | 0.5-30.0 | **Minimum 0.5s.** Anything shorter will fail |
| `loop` | `true`/`false` | Creates seamless looping audio |
| `prompt_influence` | 0.0-1.0 | Higher = more literal to prompt, lower = more creative |
| `output_format` | see Output Formats | Default `mp3_44100_128` |

### Example: Game SFX
```json
{
  "session_name": "game_sfx",
  "audio_groups": [
    {
      "name": "pickups",
      "type": "sfx",
      "output_folder": "assets/audio/sfx",
      "default_params": {
        "output_format": "mp3_44100_128",
        "prompt_influence": 0.4
      },
      "clips": [
        {"id": "coin", "text": "Short retro 8-bit coin pickup chime, bright and satisfying", "params": {"duration_seconds": 0.5}},
        {"id": "powerup", "text": "Ascending sparkle chime, magical, retro game style", "params": {"duration_seconds": 1.0}},
        {"id": "explosion", "text": "Small retro explosion with crackle, 8-bit style", "params": {"duration_seconds": 1.0}}
      ]
    }
  ]
}
```

---

## 2. Text-to-Speech (tts)

For voice lines, narration, character dialogue. Requires a `voice_id`.

### JSON Structure
```json
{
  "session_name": "my_voices",
  "audio_groups": [
    {
      "name": "group_name",
      "type": "tts",
      "output_folder": "assets/audio/voices",
      "voice_id": "JBFqnCBsd6RMkjVDRZzb",
      "default_params": {
        "model_id": "eleven_flash_v2_5",
        "output_format": "mp3_44100_128",
        "stability": 0.7,
        "similarity_boost": 0.8,
        "speed": 1.0
      },
      "clips": [
        {"id": "clip_id", "text": "Words to speak"},
        {"id": "another_clip", "text": "More words", "params": {"speed": 1.2}}
      ]
    }
  ]
}
```

### TTS Parameters

| Parameter | Options | Notes |
|-----------|---------|-------|
| `voice_id` | string | Required. Use `--list-voices` to find IDs |
| `model_id` | string | `eleven_flash_v2_5` (fast/cheap), `eleven_multilingual_v2` (quality), `eleven_v3` (expressive) |
| `stability` | 0.0-1.0 | Higher = more consistent delivery |
| `similarity_boost` | 0.0-1.0 | Higher = closer to original voice |
| `style` | 0.0-1.0 | Style exaggeration |
| `speed` | number | Speech rate (1.0 = normal) |
| `language_code` | string | e.g. `"en"` (for multilingual models) |

---

## 3. Music Generation (music)

For full music tracks, jingles, game soundtracks. Supports simple prompts or detailed composition plans with per-section control.

### JSON Structure (Simple Prompt)
```json
{
  "session_name": "my_soundtrack",
  "audio_groups": [
    {
      "name": "album_tracks",
      "type": "music",
      "output_folder": "assets/audio/music",
      "default_params": {
        "output_format": "mp3_44100_128",
        "music_length_ms": 60000,
        "force_instrumental": true,
        "seed": 42
      },
      "clips": [
        {"id": "track_01", "text": "Upbeat chiptune arcade music, energetic 8-bit game soundtrack"},
        {"id": "track_02", "text": "Calm lo-fi chiptune, relaxed menu screen music", "params": {"music_length_ms": 30000}}
      ]
    }
  ]
}
```

### JSON Structure (Composition Plan)

For granular control over song structure, styles, and lyrics:
```json
{
  "session_name": "my_soundtrack",
  "audio_groups": [
    {
      "name": "structured_tracks",
      "type": "music",
      "output_folder": "assets/audio/music",
      "default_params": {
        "output_format": "mp3_44100_128",
        "seed": 42
      },
      "clips": [
        {
          "id": "track_01",
          "composition_plan": {
            "positive_global_styles": ["lo-fi chiptune", "90s MIDI", "nostalgic"],
            "negative_global_styles": ["modern production", "orchestral"],
            "sections": [
              {
                "section_name": "Intro",
                "duration_ms": 10000,
                "positive_local_styles": ["gentle", "building"],
                "negative_local_styles": [],
                "lines": []
              },
              {
                "section_name": "Main",
                "duration_ms": 40000,
                "positive_local_styles": ["energetic", "catchy melody"],
                "negative_local_styles": [],
                "lines": []
              },
              {
                "section_name": "Outro",
                "duration_ms": 10000,
                "positive_local_styles": ["fading", "winding down"],
                "negative_local_styles": [],
                "lines": []
              }
            ]
          }
        }
      ]
    }
  ]
}
```

### Music Parameters

| Parameter | Options | Notes |
|-----------|---------|-------|
| `music_length_ms` | 3000-600000 | Duration in ms (3s to 10min). Only used with prompt mode |
| `seed` | integer | Same seed + same params = more consistent style across tracks |
| `force_instrumental` | `true`/`false` | No vocals. Only used with prompt mode |
| `model_id` | string | `music_v1` (currently the only option) |
| `output_format` | see Output Formats | Default `mp3_44100_128` |

### Composition Plan Fields

| Field | Description |
|-------|-------------|
| `positive_global_styles` | Style tags for entire song (e.g. `["chiptune", "retro"]`) |
| `negative_global_styles` | Styles to exclude (e.g. `["modern", "orchestral"]`) |
| `sections[].section_name` | Section label: "Intro", "Verse", "Chorus", "Outro", etc. |
| `sections[].duration_ms` | 3000-120000ms per section |
| `sections[].positive_local_styles` | Section-specific style directions |
| `sections[].negative_local_styles` | Section-specific exclusions |
| `sections[].lines` | Lyrics (array of strings, max 200 chars each). Empty = instrumental |

### Consistency Across Tracks

To generate an album with consistent feel:
1. Use the same `seed` across all clips in `default_params`
2. Use `composition_plan` with identical `positive_global_styles` / `negative_global_styles`
3. Vary only the `sections` (structure, local styles, lyrics) per track
4. Exact reproducibility is not guaranteed, but same seed + same styles = similar feel

---

## Output Formats

| Format | Description |
|--------|-------------|
| `mp3_44100_128` | MP3 128kbps — default, good for games |
| `mp3_44100_64` | MP3 64kbps — smaller files |
| `mp3_44100_192` | MP3 192kbps — Creator+ plan |
| `wav_44100` | WAV uncompressed — Pro+ plan |
| `pcm_44100` | Raw PCM — Pro+ plan |

---

## Tips

### SFX Prompts
- Be descriptive: "Short retro 8-bit coin pickup chime, bright and satisfying"
- Use audio terminology: whoosh, chime, thud, crackle, hum, buzz, blip, ding
- Specify style: "retro", "8-bit", "digital", "organic", "metallic"
- Sequence complex sounds: "Glass shattering followed by debris settling"

### Durations
- **SFX minimum 0.5 seconds** — anything shorter fails silently
- **Music minimum 3 seconds** — max 10 minutes (600,000ms)
- UI clicks/blips: 0.5s
- Short SFX (hits, pickups): 0.5-1.0s
- Medium SFX (explosions, jingles): 1.0-2.0s
- Startup/shutdown jingles: 3.0-5.0s
- Ambient loops: 3.0-10.0s (use `"loop": true`)
- Music tracks: 30,000-180,000ms (30s-3min typical)

### Processing Time
- **SFX/TTS**: ~3-5 seconds per clip
- **Music**: longer for longer tracks, timeout set to 10 minutes

### Costs
- **SFX**: 40 credits per second of generated audio
- **Music**: billed per generation (paid plans only)
- **TTS standard**: 1 credit per character
- **TTS flash/turbo**: 1 credit per 2 characters (50% cheaper)
- **Free tier**: ~10,000 credits/month, 2 concurrent requests

### Rate Limiting
Script includes configurable `safety_delay` (default 3s) between requests.

---

## Config File Location

Store configs in:
```
assets/data/audio_generation_sessions/
```

## Session Metadata

After completion, script saves metadata to project root:
```
session_{session_name}_metadata.json
```

Contains: generation times, file paths, file sizes, success/failure status.
