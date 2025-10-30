# Memory Match - Variant Modifiers

All properties can be added to any Memory Match variant in `assets/data/variants/memory_match_variants.json`.

## Per-Variant Modifiers (Grid & Layout)

**card_count** [auto]: Total number of cards to spawn (must be even). Auto-calculates as `pairs_per_complexity * complexity * 2`. Overrides automatic calculation when specified. Range: 4-48

**columns** [0]: Number of columns in card grid. 0 = auto-calculate square grid from card_count. Non-zero = use exact column count. Range: 0-8

**match_requirement** [2]: Number of cards that must be matched simultaneously. 2 = classic pairs, 3 = triplets, 4 = quads. Increases difficulty significantly. Range: 2-4

## Per-Variant Modifiers (Timing & Speed)

**flip_speed** [0.3]: Speed of card flip animation in seconds. Lower = faster flips, higher = slower reveal. Range: 0.1-2.0

**reveal_duration** [1.0]: Time cards stay face-up after mismatch before flipping back. Lower = faster pace, higher = more forgiving. Range: 0.2-5.0

**memorize_time** [5]: Seconds to memorize all cards before gameplay starts. 0 = no memorize phase (instant start). Range: 0-30

**auto_shuffle_interval** [0]: Seconds between automatic card position shuffles. 0 = disabled. Uses visual shell-game style animation. Range: 0-60

**auto_shuffle_count** [0]: Number of face-down cards to shuffle each interval. 0 = shuffle all face-down cards, N = shuffle only N randomly selected face-down cards. Must be at least 2 to shuffle (needs swappable pairs). Range: 0-48

## Per-Variant Modifiers (Constraints & Limits)

**time_limit** [0]: Total time limit in seconds to complete the game. 0 = no limit. Countdown timer shown in HUD. Range: 0-300

**move_limit** [0]: Maximum number of card flips allowed. 0 = unlimited. Each card flip consumes 1 move. Range: 0-200

## Per-Variant Modifiers (Scoring & Penalties)

**mismatch_penalty** [0]: Score/time penalty when cards don't match. Can reduce time remaining or score multiplier. Range: 0-50

**combo_multiplier** [0.0]: Score bonus multiplier for consecutive matches. Score multiplied by (1 + combo_multiplier * combo_count). 0 = disabled. Range: 0.0-5.0

**speed_bonus** [0]: Bonus points per second of time remaining when completing game. Only applies if time_limit > 0. Range: 0-100

**perfect_bonus** [0]: Bonus points for each perfect match (found on first try). Rewards memory skill. Range: 0-50

## Per-Variant Modifiers (Visual Effects)

**gravity_enabled** [false]: Cards fall toward bottom of screen with gravity physics. Matched cards disappear and remaining cards fall down.

**card_rotation** [false]: Cards slowly rotate while face-down. Makes tracking harder during auto-shuffle.

**spinning_cards** [false]: Cards continuously spin around their center. Significantly harder to track and select.

**fog_of_war** [0]: Spotlight radius in pixels around mouse cursor. Cards fade based on distance. 0 = disabled. Creates memory challenge with limited visibility. Range: 0-500

**fog_inner_radius** [0.6]: Percentage of fog_of_war radius that's fully visible before gradient starts. 0.0 = instant gradient from center, 1.0 = sharp edge at radius. Range: 0.0-1.0

**fog_darkness** [0.1]: How dark cards become outside spotlight. 0.0 = pitch black (invisible), 0.1 = slightly visible, 1.0 = fully visible (no fog effect). Range: 0.0-1.0

**distraction_elements** [false]: Spawn visual distractions (floating particles, screen shake, color shifts). Reduces focus.

## Per-Variant Modifiers (Challenge Modes)

**chain_requirement** [0]: Forces player to match specific cards in a required sequence. HUD shows which card value to match next. 0 = disabled, N = chain length before random. Range: 0-10

## Per-Variant Modifiers (Audio/Visual Metadata)

**sprite_set** [flags]: Which sprite folder to load card icons from `assets/sprites/games/memory_match/`. The game will scan the folder and randomly pick as many icons as needed. Folder can contain any number of .png files (5, 50, 500, etc). Sprites can be any size/ratio (32x48 flags, 64x64 squares, etc). Examples: "flags" (default), "faces", "icons_1", "animals". Hidden parameter (visual only).

**palette** [blue]: Color palette ID for palette swapping. Examples: "blue", "red", "purple", "green", "gold". Hidden parameter (visual only).

**music_track** [null]: Path to music file. Example: "memory_theme_1", "memory_theme_2". Hidden parameter (audio only).

**sfx_pack** [retro_beeps]: Which SFX pack to use. Options: "retro_beeps", "modern_ui", "8bit_arcade". Hidden parameter (audio only).

**background** [gradient_blue]: Background visual theme. Examples: "gradient_blue", "gradient_purple", "starfield". Hidden parameter (visual only).

## Per-Variant Modifiers (Difficulty & Flavor)

**difficulty_modifier** [1.0]: Overall difficulty multiplier. Scales spawn rate, AI aggression, etc. Higher = harder. Range: 0.5-3.0

**name** [required]: Display name for this variant. Example: "Memory Match Classic". Hidden parameter (metadata).

**flavor_text** [""]: Description shown in launcher. Example: "Classic memory matching! Find all pairs". Hidden parameter (metadata).

**clone_index** [required]: Unique index for this variant (0, 1, 2, ...). Hidden parameter (internal ID).

**intro_cutscene** [null]: Optional cutscene ID before game starts. Hidden parameter (metadata).

## Example Variants

### Classic
```json
{
  "clone_index": 0,
  "name": "Memory Match Classic",
  "card_count": 12,
  "memorize_time": 5,
  "reveal_duration": 1.0,
  "palette": "blue",
  "sprite_set": "icons_1",
  "music_track": "memory_theme_1",
  "sfx_pack": "retro_beeps",
  "background": "gradient_blue",
  "difficulty_modifier": 1.0,
  "flavor_text": "Classic memory matching! Find all pairs"
}
```
Feel: Traditional memory game, 6 pairs, fair memorize time

### Speed Run
```json
{
  "clone_index": 1,
  "name": "Memory Match Speed Run",
  "card_count": 12,
  "memorize_time": 2,
  "flip_speed": 0.1,
  "reveal_duration": 0.3,
  "time_limit": 60,
  "speed_bonus": 50,
  "palette": "red",
  "difficulty_modifier": 1.3,
  "flavor_text": "Fast flips, quick memory, beat the clock!"
}
```
Feel: High-speed memory test, every second counts

### Giant Grid
```json
{
  "clone_index": 2,
  "name": "Memory Match Giant Grid",
  "card_count": 36,
  "columns": 6,
  "memorize_time": 15,
  "reveal_duration": 1.5,
  "palette": "purple",
  "difficulty_modifier": 1.5,
  "flavor_text": "Massive 6x6 grid - can you remember them all?"
}
```
Feel: Brain workout with 18 pairs, longer memorize time

### Shell Game
```json
{
  "clone_index": 3,
  "name": "Memory Match Shell Game",
  "card_count": 12,
  "memorize_time": 5,
  "auto_shuffle_interval": 8,
  "auto_shuffle_count": 2,
  "card_rotation": true,
  "palette": "orange",
  "difficulty_modifier": 1.4,
  "flavor_text": "Cards shuffle positions - track them carefully!"
}
```
Feel: Classic shell game twist with only 2 cards swapping at a time, requires visual tracking

### Fog of War
```json
{
  "clone_index": 4,
  "name": "Memory Match Foggy Memory",
  "card_count": 16,
  "memorize_time": 0,
  "fog_of_war": 150,
  "reveal_duration": 0.8,
  "palette": "gray",
  "difficulty_modifier": 1.6,
  "flavor_text": "Limited visibility - remember what you can't see!"
}
```
Feel: Challenging memory test with restricted view

### Time Attack
```json
{
  "clone_index": 5,
  "name": "Memory Match Time Attack",
  "card_count": 20,
  "memorize_time": 3,
  "time_limit": 90,
  "speed_bonus": 100,
  "mismatch_penalty": 5,
  "palette": "red",
  "difficulty_modifier": 1.5,
  "flavor_text": "90 seconds - find all pairs before time runs out!"
}
```
Feel: Intense time pressure, penalties for mistakes

### Perfect Challenge
```json
{
  "clone_index": 6,
  "name": "Memory Match Perfectionist",
  "card_count": 16,
  "memorize_time": 8,
  "perfect_bonus": 50,
  "mismatch_penalty": 999,
  "move_limit": 16,
  "palette": "gold",
  "difficulty_modifier": 1.8,
  "flavor_text": "One mistake and you're done - perfect memory only!"
}
```
Feel: Unforgiving challenge for memory masters

### Gravity Falls
```json
{
  "clone_index": 7,
  "name": "Memory Match Gravity Falls",
  "card_count": 20,
  "memorize_time": 5,
  "gravity_enabled": true,
  "card_rotation": true,
  "reveal_duration": 1.2,
  "palette": "green",
  "difficulty_modifier": 1.6,
  "flavor_text": "Cards fall with gravity - physics memory puzzle!"
}
```
Feel: Dynamic physics-based memory challenge

### Chain Lightning
```json
{
  "clone_index": 8,
  "name": "Memory Match Chain Lightning",
  "card_count": 16,
  "memorize_time": 5,
  "chain_requirement": 3,
  "combo_multiplier": 2.0,
  "reveal_duration": 0.8,
  "palette": "electric_blue",
  "difficulty_modifier": 1.7,
  "flavor_text": "Match in sequence for combo multipliers!"
}
```
Feel: Strategic play rewarded with massive score multipliers

### Triple Trouble
```json
{
  "clone_index": 9,
  "name": "Memory Match Triple Trouble",
  "card_count": 18,
  "match_requirement": 3,
  "memorize_time": 8,
  "reveal_duration": 2.0,
  "palette": "orange",
  "difficulty_modifier": 2.0,
  "flavor_text": "Match 3 cards at once - triple the challenge!"
}
```
Feel: Significantly harder with triplet matching

### Chaos Mode
```json
{
  "clone_index": 10,
  "name": "Memory Match Chaos",
  "card_count": 24,
  "memorize_time": 3,
  "auto_shuffle_interval": 10,
  "auto_shuffle_count": 6,
  "spinning_cards": true,
  "distraction_elements": true,
  "time_limit": 120,
  "fog_of_war": 200,
  "combo_multiplier": 1.5,
  "palette": "rainbow",
  "difficulty_modifier": 2.5,
  "flavor_text": "Everything at once - pure madness!"
}
```
Feel: Overwhelming sensory challenge with partial shuffles, for experts only

## CheatEngine Integration

When you open CheatEngine and select a Memory Match variant, the following parameters will be **editable** (numeric/boolean sliders):

**Editable Parameters:**
- card_count, columns, match_requirement
- flip_speed, reveal_duration, memorize_time, auto_shuffle_interval, auto_shuffle_count
- time_limit, move_limit
- mismatch_penalty, combo_multiplier, speed_bonus, perfect_bonus
- gravity_enabled, card_rotation, spinning_cards (toggles)
- fog_of_war, fog_inner_radius, fog_darkness, chain_requirement
- distraction_elements (toggle)
- difficulty_modifier

**Hidden Parameters** (not editable):
- Metadata: clone_index, name, flavor_text, intro_cutscene
- Visual: sprite_set, palette, music_track, sfx_pack, background

All numeric and boolean parameters are automatically adjustable in CheatEngine!
