# New Games - Variant Modifiers
**Breakout, Coin Flip Streak, RPS Tournament**

This document defines all variant parameters for the three new game types, following the established architecture patterns from Dodge, Snake, Memory Match, and Space Shooter.

---

# BREAKOUT / ARKANOID

All properties can be added to any Breakout variant in `assets/data/variants/breakout_variants.json`.

## Per-Variant Modifiers (Paddle Mechanics)

**movement_type** [default]: Paddle control scheme. Options:
  - "default": Standard left/right WASD/Arrow movement
  - "rail": Fixed high-speed lateral movement (rapid side-to-side, common in arcade Breakout)
  - "asteroids": Rotate and thrust with momentum (unconventional but interesting)
  - "jump": Discrete teleport jumps between positions (hard mode)

Hidden parameter (requires dropdown).

**paddle_width** [80]: Paddle width in pixels. Larger = easier to catch ball. Range: 20-200

**paddle_speed** [300]: Paddle movement speed in pixels/second. Range: 50-800

**paddle_friction** [1.0]: Deceleration when stopping. 1.0 = instant stop, 0.95 = slight drift, 0.85 = ice physics. Range: 0.7-1.0

**paddle_sticky** [false]: If true, ball sticks to paddle on contact. Player releases with spacebar. Creates strategic "aim before release" gameplay.

**paddle_magnet_range** [0]: Ball auto-attracts to paddle within this radius. 0 = disabled, 50 = slight pull, 150 = strong magnet. Creates easier variants. Range: 0-200

**paddle_size_multiplier** [1.0]: Visual and collision size multiplier. 0.5 = tiny paddle, 2.0 = giant paddle. Range: 0.3-3.0

**paddle_can_shoot** [false]: If true, paddle has laser gun. Press spacebar to fire bullets upward. Bullets destroy bricks on contact.

**paddle_shoot_cooldown** [0.5]: Cooldown between paddle shots in seconds (when paddle_can_shoot = true). Range: 0.1-2.0

**paddle_shoot_damage** [1]: How many hits paddle bullets deal to bricks. Range: 1-10

## Per-Variant Modifiers (Ball Physics)

**ball_count** [1]: Number of balls in play simultaneously. 1 = classic, 3 = multi-ball chaos, 5 = bullet hell. Range: 1-20

**ball_speed** [300]: Base ball velocity in pixels/second. Range: 50-800

**ball_speed_increase_per_bounce** [0]: Speed increase per brick hit. 0 = constant speed, 5 = gradual acceleration, 20 = rapid escalation. Range: 0-50

**ball_max_speed** [800]: Maximum ball speed cap. Prevents runaway velocity. Range: 100-1500

**ball_size** [8]: Ball radius in pixels. Smaller = harder to see/predict. Range: 4-20

**ball_gravity** [0]: Downward gravity force on ball in pixels/sec². 0 = no gravity (classic), 200 = slight arc, 500 = strong arc. Creates "gravity breakout" variants. Range: 0-1000

**ball_gravity_direction** [270]: Gravity direction in degrees. 270 = down (standard), 90 = up (reverse), 0 = right, 180 = left. Range: 0-360

**ball_bounce_randomness** [0.0]: Random variation in bounce angle. 0.0 = perfect physics, 0.1 = slight variation, 0.3 = chaotic bounces. Range: 0.0-0.5

**ball_trail_length** [0]: Ball trail length in points. 0 = no trail, 10 = short trail, 30 = long comet tail. Visual flair. Range: 0-50

**ball_spin_enabled** [false]: If true, ball has spin that affects bounce angles. Adds physics complexity.

**ball_phase_through_bricks** [0]: Number of bricks ball can pass through before bouncing. 0 = normal (bounce on first brick), 3 = pierce through 3 bricks. Range: 0-10

**ball_homing** [0.0]: Ball curves toward nearest brick. 0.0 = no homing, 0.5 = moderate curve, 1.0 = strong tracking. Range: 0.0-1.0

**ball_respawn_on_miss** [false]: If true, ball respawns after falling off bottom instead of losing life. Changes game to score-focused instead of survival.

**ball_spawn_angle_variance** [30]: Random variance in ball spawn angle in degrees. 30 = slight variation, 90 = wide variance. Range: 0-90

## Per-Variant Modifiers (Brick System)

**brick_layout** [grid]: Brick arrangement pattern. Options:
  - "grid": Classic rows of bricks (standard Breakout)
  - "pyramid": Triangle/pyramid formation
  - "circle": Circular arrangement
  - "random": Scattered placement
  - "maze": Corridor patterns
  - "checkerboard": Alternating gaps
  - "custom": Load from layout file (future)

Hidden parameter (requires dropdown).

**brick_rows** [8]: Number of brick rows (for grid layout). Range: 1-20

**brick_columns** [14]: Number of brick columns (for grid layout). Range: 4-30

**brick_health** [1]: Hits required to destroy each brick. 1 = one-hit, 3 = armored, 10 = ultra-tank. Range: 1-20

**brick_health_variance** [0.0]: Random health variation. 0.0 = all bricks same health, 0.5 = some bricks have ±50% health, 1.0 = extreme variation. Range: 0.0-1.0

**brick_regeneration_enabled** [false]: If true, destroyed bricks slowly respawn over time. Creates "endless" variants where you can never truly clear the screen.

**brick_regeneration_time** [10.0]: Seconds before destroyed brick respawns (when regeneration enabled). Range: 1.0-60.0

**brick_fall_enabled** [false]: If true, bricks slowly fall downward over time (like Tetris + Breakout hybrid). Game over if bricks reach bottom.

**brick_fall_speed** [10]: Speed bricks fall in pixels/second (when fall enabled). Range: 1-50

**brick_movement_enabled** [false]: If true, bricks slowly drift left/right. Makes hitting them harder.

**brick_movement_speed** [20]: Drift speed in pixels/second (when movement enabled). Range: 5-100

**brick_size_variance** [0.0]: Random size variation. 0.0 = uniform, 0.5 = some variety, 1.0 = extreme size differences. Range: 0.0-1.0

**brick_score_multiplier** [1.0]: Point value multiplier for destroying bricks. Higher = more score per brick. Range: 0.5-5.0

**brick_powerup_drop_chance** [0.1]: Probability brick drops power-up when destroyed. 0.0 = no drops, 0.5 = 50% drop rate. Range: 0.0-1.0

## Per-Variant Modifiers (Arena & Boundaries)

**arena_width** [400]: Play area width in pixels. Range: 200-800

**arena_height** [500]: Play area height in pixels. Range: 300-800

**wall_bounce_mode** [normal]: Side wall bounce behavior. Options:
  - "normal": Standard elastic bounce
  - "damped": Bounces lose energy (50% velocity retained)
  - "sticky": Ball briefly sticks to walls before releasing
  - "wrap": Asteroids-style screen wrap (ball exits right, appears left)

Hidden parameter (requires dropdown).

**ceiling_enabled** [true]: If false, no ceiling - ball can escape upward. Creates "don't let it escape" challenge.

**bottom_kill_enabled** [true]: If false, ball bounces off bottom instead of falling off. Makes game much easier.

**obstacles_count** [0]: Number of static obstacles in play area. 0 = none, 5 = moderate, 15 = maze-like. Range: 0-30

**obstacles_shape** [rectangle]: Static obstacle shape. Options: "rectangle", "circle", "triangle". Hidden parameter (requires dropdown).

**obstacles_destructible** [false]: If true, obstacles can be destroyed by ball hits. If false, indestructible hazards.

## Per-Variant Modifiers (Power-Ups)

**powerup_enabled** [true]: Master toggle for power-up system.

**powerup_types** [array]: Array of enabled power-up type strings. Available types:
  - "multi_ball": Spawns 2 additional balls
  - "paddle_extend": Increases paddle width by 50% temporarily
  - "paddle_shrink": Decreases paddle width by 50% temporarily (bad power-up!)
  - "slow_motion": Slows ball speed by 50% temporarily
  - "fast_ball": Increases ball speed by 50% temporarily (bad power-up!)
  - "laser": Enables paddle shooting temporarily
  - "sticky_paddle": Enables sticky paddle temporarily
  - "extra_life": Grants +1 life
  - "shield": Spawns protective barrier at bottom (blocks one miss)
  - "penetrating_ball": Ball pierces through 5 bricks
  - "fireball": Ball destroys all bricks in small radius on contact
  - "magnet": Ball attracted to paddle

Hidden parameter (array of strings).

Example:
```json
"powerup_types": ["multi_ball", "paddle_extend", "laser", "extra_life"]
```

**powerup_duration** [10.0]: Duration of temporary power-ups in seconds. Range: 1.0-60.0

**powerup_fall_speed** [100]: How fast power-ups fall in pixels/second. Higher = harder to catch. Range: 20-300

**powerup_spawn_mode** [drop]: How power-ups appear. Options:
  - "drop": Fall from destroyed brick position
  - "spawn_top": Spawn at random top position and fall
  - "spawn_paddle": Spawn directly on paddle (instant collection)

Hidden parameter (requires dropdown).

## Per-Variant Modifiers (Victory Conditions)

**victory_condition** [clear_bricks]: Win condition type. Options:
  - "clear_bricks": Destroy all bricks (classic)
  - "destroy_count": Destroy X bricks (partial clear)
  - "score": Reach X score points
  - "time": Survive X seconds without losing all lives
  - "survival": Endless mode - never complete

Hidden parameter (requires dropdown).

**victory_limit** [0]: Victory threshold based on condition type. For "destroy_count": brick count. For "score": score target. For "time": seconds. 0 = use default. Range: 0-10000

**perfect_clear_bonus** [1000]: Bonus score for destroying all bricks without missing ball. Range: 0-10000

## Per-Variant Modifiers (Lives & Difficulty)

**lives** [3]: Starting lives. Higher = more forgiving. Range: 1-20

**extra_ball_score_threshold** [5000]: Score required to earn extra life. 0 = disabled. Range: 0-50000

**ball_speed_cap_enabled** [true]: If false, ball speed is uncapped (can become impossible).

**difficulty_scaling_enabled** [false]: If true, ball speed gradually increases over time.

**difficulty_scaling_rate** [5]: Ball speed increase per minute (when scaling enabled). Range: 1-50

## Per-Variant Modifiers (Visual Effects)

**fog_of_war_enabled** [false]: If true, limited visibility around paddle/ball.

**fog_of_war_radius** [200]: Visibility radius in pixels (when fog enabled). Range: 50-500

**camera_shake_enabled** [false]: If true, camera shakes on brick destruction.

**camera_shake_intensity** [5.0]: Screen shake strength. Range: 0.0-20.0

**particle_effects_enabled** [true]: If false, disables brick destruction particles (performance mode).

**brick_flash_on_hit** [true]: If true, bricks flash white when hit. Visual feedback.

**score_popup_enabled** [true]: If true, score numbers float up from destroyed bricks.

## Per-Variant Modifiers (Audio/Visual Metadata)

**sprite_set** [classic]: Which sprite folder to load from `assets/sprites/games/breakout/`. Examples: "classic", "neon", "retro". Hidden parameter (visual only).

**palette** [blue]: Color palette ID for palette swapping. Examples: "blue", "red", "purple", "green", "rainbow". Hidden parameter (visual only).

**music_track** [null]: Path to music file. Example: "breakout_theme_1", "breakout_theme_2". Hidden parameter (audio only).

**sfx_pack** [retro_beeps]: Which SFX pack to use. Options: "retro_beeps", "modern_ui", "8bit_arcade". Hidden parameter (audio only).

**background** [starfield_blue]: Background visual theme. Examples: "starfield_blue", "gradient_purple", "brick_wall". Hidden parameter (visual only).

## Per-Variant Modifiers (Difficulty & Flavor)

**difficulty_modifier** [1.0]: Overall difficulty multiplier. Scales ball speed, brick health, etc. Higher = harder. Range: 0.5-3.0

**name** [required]: Display name for this variant. Example: "Breakout Classic". Hidden parameter (metadata).

**flavor_text** [""]: Description shown in launcher. Example: "Classic brick-breaking action!". Hidden parameter (metadata).

**clone_index** [required]: Unique index for this variant (0, 1, 2, ...). Hidden parameter (internal ID).

**intro_cutscene** [null]: Optional cutscene ID before game starts. Hidden parameter (metadata).

## Metrics Tracked

For formula calculations and token generation:

- **bricks_destroyed**: Total bricks destroyed
- **bricks_remaining**: Bricks left on screen
- **balls_lost**: Number of times ball fell off bottom
- **combo**: Consecutive bricks destroyed without ball touching paddle
- **max_combo**: Highest combo achieved during game
- **powerups_collected**: Power-ups caught
- **score**: Total score accumulated
- **time_elapsed**: Seconds played
- **perfect_clear**: Boolean (1 if all bricks destroyed without losing ball)

## Example Variants

### Classic Breakout
```json
{
  "clone_index": 0,
  "name": "Breakout Classic",
  "movement_type": "default",
  "paddle_width": 80,
  "paddle_speed": 300,
  "ball_count": 1,
  "ball_speed": 300,
  "brick_layout": "grid",
  "brick_rows": 8,
  "brick_columns": 14,
  "brick_health": 1,
  "lives": 3,
  "victory_condition": "clear_bricks",
  "powerup_enabled": true,
  "powerup_types": ["multi_ball", "paddle_extend", "extra_life"],
  "palette": "blue",
  "flavor_text": "Classic brick-breaking action!"
}
```

### Gravity Breaker
```json
{
  "clone_index": 1,
  "name": "Breakout Gravity",
  "ball_gravity": 300,
  "ball_speed": 350,
  "paddle_width": 100,
  "brick_rows": 6,
  "lives": 5,
  "flavor_text": "Ball affected by gravity - new physics challenge!"
}
```

### Multi-Ball Chaos
```json
{
  "clone_index": 2,
  "name": "Breakout Multi-Ball Madness",
  "ball_count": 5,
  "ball_speed": 250,
  "paddle_width": 120,
  "brick_health": 2,
  "lives": 3,
  "powerup_enabled": false,
  "flavor_text": "Five balls at once - pure chaos!"
}
```

### Laser Paddle
```json
{
  "clone_index": 3,
  "name": "Breakout Laser Assault",
  "paddle_can_shoot": true,
  "paddle_shoot_cooldown": 0.3,
  "paddle_shoot_damage": 2,
  "ball_speed": 280,
  "brick_health": 3,
  "brick_rows": 10,
  "lives": 5,
  "flavor_text": "Shoot bricks with your laser paddle!"
}
```

### Falling Bricks
```json
{
  "clone_index": 4,
  "name": "Breakout Falling Sky",
  "brick_fall_enabled": true,
  "brick_fall_speed": 15,
  "brick_rows": 5,
  "ball_speed": 350,
  "paddle_speed": 400,
  "lives": 3,
  "victory_condition": "time",
  "victory_limit": 60,
  "flavor_text": "Bricks fall toward you - survive 60 seconds!"
}
```

### Tiny Paddle Challenge
```json
{
  "clone_index": 5,
  "name": "Breakout Tiny Paddle",
  "paddle_width": 40,
  "paddle_speed": 350,
  "ball_speed": 280,
  "lives": 5,
  "powerup_types": ["paddle_extend"],
  "flavor_text": "Half-size paddle - precision required!"
}
```

### Sticky Strategy
```json
{
  "clone_index": 6,
  "name": "Breakout Sticky Paddle",
  "paddle_sticky": true,
  "ball_speed": 320,
  "brick_layout": "pyramid",
  "brick_rows": 10,
  "lives": 3,
  "flavor_text": "Ball sticks to paddle - aim your shots!"
}
```

### Fog of War
```json
{
  "clone_index": 7,
  "name": "Breakout Fog",
  "fog_of_war_enabled": true,
  "fog_of_war_radius": 150,
  "ball_trail_length": 20,
  "lives": 5,
  "flavor_text": "Limited visibility - track the ball!"
}
```

### Endless Regeneration
```json
{
  "clone_index": 8,
  "name": "Breakout Endless",
  "brick_regeneration_enabled": true,
  "brick_regeneration_time": 15,
  "victory_condition": "score",
  "victory_limit": 10000,
  "lives": 3,
  "flavor_text": "Bricks respawn - race to 10,000 points!"
}
```

### Homing Ball
```json
{
  "clone_index": 9,
  "name": "Breakout Homing",
  "ball_homing": 0.7,
  "ball_speed": 320,
  "brick_health": 2,
  "paddle_width": 60,
  "lives": 3,
  "flavor_text": "Ball curves toward bricks automatically!"
}
```

### The Kitchen Sink
```json
{
  "clone_index": 10,
  "name": "Breakout Chaos Mode",
  "ball_count": 3,
  "ball_speed": 300,
  "ball_gravity": 200,
  "paddle_can_shoot": true,
  "paddle_sticky": true,
  "paddle_width": 70,
  "brick_fall_enabled": true,
  "brick_fall_speed": 10,
  "brick_regeneration_enabled": true,
  "brick_regeneration_time": 30,
  "brick_movement_enabled": true,
  "obstacles_count": 5,
  "lives": 5,
  "powerup_types": ["multi_ball", "paddle_extend", "laser", "slow_motion", "extra_life", "fireball"],
  "fog_of_war_enabled": true,
  "fog_of_war_radius": 200,
  "camera_shake_enabled": true,
  "victory_condition": "score",
  "victory_limit": 20000,
  "flavor_text": "EVERYTHING AT ONCE! Expert mode!"
}
```

## CheatEngine Integration

When you open CheatEngine and select a Breakout variant, the following parameters will be **editable** (numeric/boolean sliders):

**Editable Parameters:**
- paddle_width, paddle_speed, paddle_friction, paddle_sticky, paddle_magnet_range, paddle_size_multiplier
- paddle_can_shoot, paddle_shoot_cooldown, paddle_shoot_damage
- ball_count, ball_speed, ball_speed_increase_per_bounce, ball_max_speed, ball_size, ball_gravity
- ball_gravity_direction, ball_bounce_randomness, ball_trail_length, ball_spin_enabled, ball_phase_through_bricks
- ball_homing, ball_respawn_on_miss, ball_spawn_angle_variance
- brick_rows, brick_columns, brick_health, brick_health_variance
- brick_regeneration_enabled, brick_regeneration_time
- brick_fall_enabled, brick_fall_speed
- brick_movement_enabled, brick_movement_speed
- brick_size_variance, brick_score_multiplier, brick_powerup_drop_chance
- arena_width, arena_height, ceiling_enabled, bottom_kill_enabled
- obstacles_count, obstacles_destructible
- powerup_enabled, powerup_duration, powerup_fall_speed
- lives, extra_ball_score_threshold, ball_speed_cap_enabled
- difficulty_scaling_enabled, difficulty_scaling_rate
- fog_of_war_enabled, fog_of_war_radius
- camera_shake_enabled, camera_shake_intensity
- particle_effects_enabled, brick_flash_on_hit, score_popup_enabled
- victory_limit, perfect_clear_bonus
- difficulty_modifier

**Hidden Parameters** (not editable):
- Metadata: clone_index, name, flavor_text, intro_cutscene
- Visual: sprite_set, palette, music_track, sfx_pack, background
- String enums: movement_type, brick_layout, wall_bounce_mode, obstacles_shape, powerup_spawn_mode, victory_condition
- Arrays: powerup_types

All numeric and boolean parameters are automatically adjustable in CheatEngine!

---

# COIN FLIP STREAK

All properties can be added to any Coin Flip variant in `assets/data/variants/coin_flip_variants.json`.

## Per-Variant Modifiers (Core Mechanics)

**streak_target** [5]: Number of consecutive correct guesses required to win. Range: 1-50

**coin_bias** [0.5]: Probability of heads appearing. 0.5 = fair coin (50/50), 0.6 = 60% heads bias, 0.3 = 30% heads bias. Creates exploitable weighted coins. Range: 0.0-1.0

**lives** [999]: Number of failed guesses allowed before game over. 999 = unlimited attempts (retry forever), 3 = three-strikes mode. Range: 1-999

**show_bias_hint** [false]: If true, UI displays the coin bias percentage (e.g., "60% Heads"). Makes weighted coins obvious for easier gameplay.

**auto_reveal_bias** [false]: If true, after X flips, the actual bias is calculated and shown to player. Helps discover hidden bias.

**auto_reveal_flip_count** [20]: Number of flips before bias auto-reveals (when auto_reveal_bias = true). Range: 5-100

## Per-Variant Modifiers (Timing & Speed)

**time_per_flip** [0]: Seconds allowed to make guess. 0 = unlimited, 5 = time pressure. Range: 0-30

**auto_flip_interval** [0]: Seconds between automatic coin flips. 0 = manual (player presses space to flip), 1.0 = flips every second automatically. Creates "reaction time" mode. Range: 0-5.0

**flip_animation_speed** [0.5]: Duration of coin flip animation in seconds. Lower = faster flips, higher = dramatic slow reveal. Range: 0.1-3.0

## Per-Variant Modifiers (Pattern & Strategy)

**show_pattern_history** [false]: If true, displays last N flip results (e.g., "HTHHT"). Helps player spot patterns.

**pattern_history_length** [10]: Number of recent flips shown in history (when enabled). Range: 3-50

**pattern_mode** [random]: Flip sequence generation. Options:
  - "random": True RNG based on coin_bias
  - "alternating": Forces H-T-H-T-H-T pattern (easy mode with bias)
  - "clusters": Generates runs of same result (HHHTTTHHH)
  - "biased_random": Weighted RNG with streaks more/less likely

Hidden parameter (requires dropdown).

**cluster_length** [3]: When pattern_mode = "clusters", average length of same-result runs. Range: 2-10

**allow_guess_change** [false]: If true, player can change guess before flip completes. If false, guess is locked in.

## Per-Variant Modifiers (Victory & Scoring)

**victory_condition** [streak]: Win condition type. Options:
  - "streak": Achieve X consecutive correct guesses (classic)
  - "total": Achieve X total correct guesses (doesn't need to be consecutive)
  - "ratio": Maintain X% correct ratio over Y flips
  - "time": Get highest streak within X seconds

Hidden parameter (requires dropdown).

**total_correct_target** [20]: Target for "total" victory condition. Range: 5-200

**ratio_target** [0.7]: Minimum correct ratio for "ratio" victory condition (0.7 = 70%). Range: 0.5-1.0

**ratio_flip_count** [30]: Number of flips to evaluate ratio over (for "ratio" victory condition). Range: 10-100

**time_limit** [60]: Total time limit in seconds (for "time" victory condition or as hard limit). 0 = unlimited. Range: 0-300

**score_per_correct** [100]: Points awarded per correct guess. Range: 0-1000

**streak_multiplier** [1.5]: Score multiplier that increases with streak. Each correct guess multiplies score by this value. 1.0 = no multiplier, 2.0 = double with each correct. Range: 1.0-3.0

## Per-Variant Modifiers (Visual & Audio)

**coin_sprite** [default]: Which coin sprite to use. Options: "default", "gold", "silver", "pixel", "custom". Hidden parameter (visual only).

**flip_sound_enabled** [true]: If false, silent coin flips.

**result_announce_mode** [text]: How result is announced. Options:
  - "text": Text display ("HEADS!" / "TAILS!")
  - "voice": TTS voice announcement
  - "both": Text + voice
  - "none": Silent (player must watch coin)

Hidden parameter (requires dropdown).

**celebration_on_streak** [true]: If true, visual celebration (particles, screen flash) on streak milestones (every 5 correct).

**streak_milestone** [5]: Correct guesses between celebrations (when enabled). Range: 2-20

## Per-Variant Modifiers (Difficulty & Flavor)

**difficulty_modifier** [1.0]: Overall difficulty multiplier. Affects time pressure, bias obfuscation, etc. Range: 0.5-3.0

**name** [required]: Display name for this variant. Example: "Coin Flip Classic". Hidden parameter (metadata).

**flavor_text** [""]: Description shown in launcher. Example: "Call heads or tails - how lucky are you?". Hidden parameter (metadata).

**clone_index** [required]: Unique index for this variant (0, 1, 2, ...). Hidden parameter (internal ID).

## Metrics Tracked

For formula calculations and token generation:

- **streak**: Current consecutive correct guesses (resets on wrong guess)
- **max_streak**: Highest streak achieved during session
- **correct_total**: Total correct guesses (all time)
- **incorrect_total**: Total wrong guesses (all time)
- **flips_total**: Total flips (correct + incorrect)
- **accuracy**: Correct / Total (0.0 to 1.0)
- **time_elapsed**: Seconds played

## Example Variants

### Classic Coin Flip
```json
{
  "clone_index": 0,
  "name": "Coin Flip Classic",
  "streak_target": 5,
  "coin_bias": 0.5,
  "lives": 999,
  "show_bias_hint": false,
  "pattern_mode": "random",
  "victory_condition": "streak",
  "flavor_text": "Call 5 in a row - 50/50 odds!"
}
```

### Coin Flip Marathon
```json
{
  "clone_index": 1,
  "name": "Coin Flip Marathon",
  "streak_target": 10,
  "coin_bias": 0.5,
  "lives": 999,
  "show_pattern_history": true,
  "pattern_history_length": 15,
  "flavor_text": "10 consecutive correct - can you do it?"
}
```

### Weighted Coin Easy
```json
{
  "clone_index": 2,
  "name": "Coin Flip Weighted",
  "streak_target": 5,
  "coin_bias": 0.65,
  "lives": 999,
  "show_bias_hint": true,
  "flavor_text": "65% heads - use the bias!"
}
```

### Speed Flip
```json
{
  "clone_index": 3,
  "name": "Coin Flip Speed",
  "streak_target": 3,
  "coin_bias": 0.5,
  "lives": 999,
  "time_per_flip": 2,
  "flip_animation_speed": 0.2,
  "flavor_text": "2 seconds per flip - think fast!"
}
```

### Three Strikes
```json
{
  "clone_index": 4,
  "name": "Coin Flip Survival",
  "streak_target": 1,
  "coin_bias": 0.5,
  "lives": 3,
  "victory_condition": "total",
  "total_correct_target": 10,
  "flavor_text": "Get 10 correct with only 3 mistakes!"
}
```

### Pattern Master
```json
{
  "clone_index": 5,
  "name": "Coin Flip Patterns",
  "streak_target": 8,
  "coin_bias": 0.5,
  "lives": 999,
  "pattern_mode": "alternating",
  "show_pattern_history": true,
  "pattern_history_length": 20,
  "flavor_text": "Spot the pattern and exploit it!"
}
```

### Cluster Chaos
```json
{
  "clone_index": 6,
  "name": "Coin Flip Clusters",
  "streak_target": 6,
  "coin_bias": 0.5,
  "lives": 999,
  "pattern_mode": "clusters",
  "cluster_length": 4,
  "show_pattern_history": true,
  "flavor_text": "Results come in clusters - ride the wave!"
}
```

### Auto Flip Challenge
```json
{
  "clone_index": 7,
  "name": "Coin Flip Auto",
  "streak_target": 5,
  "coin_bias": 0.5,
  "lives": 999,
  "auto_flip_interval": 1.5,
  "time_per_flip": 1.2,
  "flavor_text": "Coin flips automatically - keep up!"
}
```

### Ratio Challenge
```json
{
  "clone_index": 8,
  "name": "Coin Flip 70% Accuracy",
  "coin_bias": 0.5,
  "lives": 999,
  "victory_condition": "ratio",
  "ratio_target": 0.7,
  "ratio_flip_count": 30,
  "show_pattern_history": true,
  "flavor_text": "Maintain 70% accuracy over 30 flips!"
}
```

### Hell Mode
```json
{
  "clone_index": 9,
  "name": "Coin Flip Hell",
  "streak_target": 15,
  "coin_bias": 0.45,
  "lives": 1,
  "time_per_flip": 3,
  "show_pattern_history": false,
  "show_bias_hint": false,
  "flavor_text": "15 streak, biased against you, one mistake = death!"
}
```

## CheatEngine Integration

**Editable Parameters:**
- streak_target, coin_bias, lives
- show_bias_hint, auto_reveal_bias, auto_reveal_flip_count
- time_per_flip, auto_flip_interval, flip_animation_speed
- show_pattern_history, pattern_history_length, cluster_length, allow_guess_change
- total_correct_target, ratio_target, ratio_flip_count, time_limit
- score_per_correct, streak_multiplier
- flip_sound_enabled, celebration_on_streak, streak_milestone
- difficulty_modifier

**Hidden Parameters:**
- Metadata: clone_index, name, flavor_text
- Visual: coin_sprite
- String enums: pattern_mode, victory_condition, result_announce_mode

---

# RPS TOURNAMENT

All properties can be added to any RPS variant in `assets/data/variants/rps_variants.json`.

## Per-Variant Modifiers (Core Mechanics)

**game_mode** [rps]: Which RPS variant to play. Options:
  - "rps": Classic Rock/Paper/Scissors (3 options)
  - "rpsls": Extended Rock/Paper/Scissors/Lizard/Spock (5 options, from Big Bang Theory)
  - "rpsfb": Rock/Paper/Scissors/Fire/Water (5 options, elemental)

Hidden parameter (requires dropdown).

**rounds_to_win** [3]: Rounds player must win to complete game (best of X). Best of 5 = 3 rounds to win, best of 21 = 11 rounds to win. Range: 1-21

**total_rounds_limit** [0]: Maximum total rounds before forced end. 0 = unlimited, 11 = best-of-21 hard cap. Used to prevent infinite tie scenarios. Range: 0-51

## Per-Variant Modifiers (AI Behavior)

**ai_pattern** [random]: AI decision-making pattern. Options:
  - "random": True RNG choices (33% each for RPS, 20% each for RPSLS)
  - "repeat_last": AI throws same choice as previous round (exploitable)
  - "counter_player": AI throws what beats player's last choice (counter-exploitable by double-bluffing)
  - "biased": AI favors one option based on ai_bias (e.g., throws Rock 60% of time)
  - "pattern_cycle": AI cycles through options in order (Rock → Paper → Scissors → repeat)
  - "mimic_player": AI copies player's previous choice (exploitable)
  - "anti_player": AI throws what player threw 2 rounds ago (complex counter)

Hidden parameter (requires dropdown).

**ai_bias** [none]: Which option AI favors when ai_pattern = "biased". Options:
  - "none": No bias (overrides pattern to random)
  - "rock", "paper", "scissors": Favors that option (60% frequency for RPS)
  - "lizard", "spock": For RPSLS mode
  - "fire", "water": For RPSFB mode

Hidden parameter (requires dropdown).

**ai_bias_strength** [0.6]: How strongly AI favors biased option. 0.6 = 60% biased option, 0.8 = 80% biased option, 0.4 = weak bias. Range: 0.4-0.9

**ai_pattern_delay** [0]: Rounds before AI pattern becomes active. 0 = pattern from start, 5 = random for first 5 rounds then pattern activates. Prevents early exploitation. Range: 0-10

**show_ai_pattern_hint** [false]: If true, UI hints at AI behavior ("AI favors Rock" or "AI counters your last choice"). Makes patterns obvious.

## Per-Variant Modifiers (Timing & Speed)

**time_per_round** [0]: Seconds to make choice each round. 0 = unlimited, 5 = time pressure. Range: 0-30

**auto_timeout_choice** [random]: What happens if player times out. Options: "random" (picks random option), "rock" (always defaults to rock), "lose" (forfeits round). Hidden parameter (requires dropdown).

**round_result_display_time** [2.0]: Seconds to show result before next round starts. Lower = faster pace. Range: 0.5-5.0

**animation_speed** [1.0]: Speed multiplier for throw animations. 0.5 = slow-mo, 2.0 = fast. Range: 0.3-3.0

## Per-Variant Modifiers (Strategy & Display)

**show_player_history** [false]: If true, displays player's last N choices (e.g., "You: RPSPR"). Helps player spot own patterns.

**show_ai_history** [false]: If true, displays AI's last N choices (e.g., "AI: SRRPS"). Helps player spot AI patterns.

**history_length** [10]: Number of rounds shown in history (when enabled). Range: 3-30

**allow_choice_change** [false]: If true, player can change choice after selecting but before "commit" button. If false, first click locks in choice.

**show_statistics** [true]: If true, displays win/loss/tie percentages during game.

**show_pattern_hint** [false]: If true, game analyzes patterns and shows hint ("AI often counters you"). Helps newer players.

## Per-Variant Modifiers (Victory & Scoring)

**victory_condition** [rounds]: Win condition type. Options:
  - "rounds": Win X rounds (best of X)
  - "first_to": First player to win X rounds wins immediately (doesn't require best-of)
  - "streak": Achieve X consecutive round wins
  - "total": Win X total rounds (across unlimited total rounds)
  - "time": Get highest round win count within X seconds

Hidden parameter (requires dropdown).

**first_to_target** [5]: Rounds to win for "first_to" victory condition. Range: 1-21

**streak_target** [5]: Consecutive round wins required for "streak" victory condition. Range: 2-20

**total_wins_target** [15]: Total round wins for "total" victory condition. Range: 5-50

**time_limit** [120]: Time limit in seconds for "time" victory condition. Range: 30-300

**score_per_round_win** [100]: Points awarded per round won. Range: 0-1000

**streak_bonus** [50]: Bonus points for consecutive round wins. Multiplies by streak length (3 wins in row = 150 bonus). Range: 0-500

**perfect_game_bonus** [1000]: Bonus for winning without losing any rounds. Range: 0-5000

## Per-Variant Modifiers (Variants & Twists)

**double_or_nothing_rounds** [0]: Number of special rounds where both players double stakes (winner gets 2 round wins, loser loses 1). 0 = disabled. Range: 0-5

**reverse_mode** [false]: If true, losing throw wins (Rock beats Scissors becomes Scissors beats Rock). Mind-bending variant.

**mirror_mode** [false]: If true, ties count as wins for player. Makes game easier.

**sudden_death_enabled** [false]: If true, after total_rounds_limit reached, next round is sudden death (winner takes all).

**lives_system_enabled** [false]: If true, player has X lives. Losing a round costs 1 life. 0 lives = game over.

**lives_count** [3]: Starting lives (when lives_system_enabled = true). Range: 1-10

## Per-Variant Modifiers (Visual & Audio)

**throw_animation_style** [hands]: Visual style for throws. Options: "hands", "icons", "text", "emojis". Hidden parameter (visual only).

**result_announce_mode** [text]: How round result is announced. Options: "text", "voice", "both", "none". Hidden parameter (requires dropdown).

**celebration_mode** [moderate]: Victory celebration intensity. Options: "none", "subtle", "moderate", "extreme". Hidden parameter (visual only).

**color_scheme** [classic]: Color theme for UI. Options: "classic", "neon", "retro", "minimal". Hidden parameter (visual only).

## Per-Variant Modifiers (Difficulty & Flavor)

**difficulty_modifier** [1.0]: Overall difficulty multiplier. Affects AI cleverness, time pressure, etc. Range: 0.5-3.0

**name** [required]: Display name for this variant. Example: "RPS Classic". Hidden parameter (metadata).

**flavor_text** [""]: Description shown in launcher. Example: "Best of 5 - rock beats scissors!". Hidden parameter (metadata).

**clone_index** [required]: Unique index for this variant (0, 1, 2, ...). Hidden parameter (internal ID).

## Metrics Tracked

For formula calculations and token generation:

- **rounds_won**: Player rounds won
- **rounds_lost**: AI rounds won
- **rounds_tied**: Tie rounds
- **rounds_total**: Total rounds played
- **win_streak**: Current consecutive round wins
- **max_win_streak**: Highest consecutive round wins achieved
- **accuracy**: Rounds won / (rounds won + rounds lost) - excludes ties
- **time_elapsed**: Seconds played
- **perfect_game**: Boolean (1 if won without losing any rounds)

## Example Variants

### RPS Classic
```json
{
  "clone_index": 0,
  "name": "RPS Classic",
  "game_mode": "rps",
  "rounds_to_win": 3,
  "ai_pattern": "random",
  "victory_condition": "rounds",
  "show_statistics": true,
  "flavor_text": "Best of 5 - pure skill and luck!"
}
```

### RPS Marathon
```json
{
  "clone_index": 1,
  "name": "RPS Marathon",
  "game_mode": "rps",
  "rounds_to_win": 11,
  "total_rounds_limit": 21,
  "ai_pattern": "random",
  "show_player_history": true,
  "show_ai_history": true,
  "history_length": 15,
  "flavor_text": "Best of 21 - law of large numbers!"
}
```

### RPS Pattern AI
```json
{
  "clone_index": 2,
  "name": "RPS Pattern Master",
  "game_mode": "rps",
  "rounds_to_win": 5,
  "ai_pattern": "repeat_last",
  "show_ai_history": true,
  "show_pattern_hint": true,
  "flavor_text": "AI repeats its last throw - exploit it!"
}
```

### RPS Counter AI
```json
{
  "clone_index": 3,
  "name": "RPS Counter Strike",
  "game_mode": "rps",
  "rounds_to_win": 5,
  "ai_pattern": "counter_player",
  "show_player_history": true,
  "show_pattern_hint": true,
  "flavor_text": "AI counters your last choice - double-bluff!"
}
```

### RPS Rock Lover
```json
{
  "clone_index": 4,
  "name": "RPS Rock Biased",
  "game_mode": "rps",
  "rounds_to_win": 7,
  "ai_pattern": "biased",
  "ai_bias": "rock",
  "ai_bias_strength": 0.65,
  "show_ai_pattern_hint": true,
  "show_ai_history": true,
  "flavor_text": "AI throws rock 65% of the time!"
}
```

### RPSLS Extended
```json
{
  "clone_index": 5,
  "name": "RPSLS Classic",
  "game_mode": "rpsls",
  "rounds_to_win": 5,
  "ai_pattern": "random",
  "show_statistics": true,
  "flavor_text": "Rock/Paper/Scissors/Lizard/Spock!"
}
```

### RPS Speed Blitz
```json
{
  "clone_index": 6,
  "name": "RPS Blitz",
  "game_mode": "rps",
  "rounds_to_win": 3,
  "ai_pattern": "random",
  "time_per_round": 2,
  "round_result_display_time": 0.8,
  "animation_speed": 2.0,
  "flavor_text": "2 seconds per round - think fast!"
}
```

### RPS Streak Challenge
```json
{
  "clone_index": 7,
  "name": "RPS Streak Master",
  "game_mode": "rps",
  "victory_condition": "streak",
  "streak_target": 5,
  "ai_pattern": "random",
  "show_player_history": true,
  "flavor_text": "Win 5 rounds in a row!"
}
```

### RPS Mimic
```json
{
  "clone_index": 8,
  "name": "RPS Copycat",
  "game_mode": "rps",
  "rounds_to_win": 5,
  "ai_pattern": "mimic_player",
  "show_ai_history": true,
  "show_pattern_hint": true,
  "flavor_text": "AI copies your last choice!"
}
```

### RPS Three Lives
```json
{
  "clone_index": 9,
  "name": "RPS Survival",
  "game_mode": "rps",
  "victory_condition": "first_to",
  "first_to_target": 10,
  "lives_system_enabled": true,
  "lives_count": 3,
  "ai_pattern": "random",
  "flavor_text": "First to 10, but you only have 3 lives!"
}
```

### RPS Hell Mode
```json
{
  "clone_index": 10,
  "name": "RPS Hell",
  "game_mode": "rpsls",
  "rounds_to_win": 15,
  "ai_pattern": "counter_player",
  "ai_pattern_delay": 3,
  "time_per_round": 3,
  "lives_system_enabled": true,
  "lives_count": 2,
  "show_player_history": false,
  "show_ai_history": false,
  "show_pattern_hint": false,
  "flavor_text": "RPSLS, AI counters you, 2 lives, 15 wins needed!"
}
```

## CheatEngine Integration

**Editable Parameters:**
- rounds_to_win, total_rounds_limit
- ai_bias_strength, ai_pattern_delay, show_ai_pattern_hint
- time_per_round, round_result_display_time, animation_speed
- show_player_history, show_ai_history, history_length, allow_choice_change
- show_statistics, show_pattern_hint
- first_to_target, streak_target, total_wins_target, time_limit
- score_per_round_win, streak_bonus, perfect_game_bonus
- double_or_nothing_rounds, reverse_mode, mirror_mode, sudden_death_enabled
- lives_system_enabled, lives_count
- difficulty_modifier

**Hidden Parameters:**
- Metadata: clone_index, name, flavor_text
- Visual: throw_animation_style, celebration_mode, color_scheme
- String enums: game_mode, ai_pattern, ai_bias, auto_timeout_choice, victory_condition, result_announce_mode

---

## Implementation Notes (All Three Games)

### VM Demo Compatibility

**Breakout**: EXCELLENT
- Paddle movement transfers well across seeds
- Ball physics deterministic (same input = same bounces per seed)
- Random spawns = ball spawn angle varies, but paddle movement still catches ball
- CheatEngine can increase paddle size + slow ball = very VM-friendly

**Coin Flip**: EXCELLENT
- 100% demo-friendly if demo records "always guess heads" or "always guess tails"
- Across seeds: coin flip results change, but guess choice is consistent
- 50% base win rate with fair coin, higher with bias
- Perfect for "set and forget" VMs

**RPS**: EXCELLENT
- 100% demo-friendly if demo records repeated choice pattern
- Across seeds: AI choices change, but player choice is consistent
- 33% base win rate (RPS), 20% base win rate (RPSLS)
- With enough rounds (best of 21), law of large numbers = some wins
- AI patterns can be exploited if player discovers them

### Formula Examples

**Breakout**:
```lua
base_formula = "(bricks_destroyed^2 * (1 + max_combo/10) * scaling_constant) / (1 + balls_lost)"
display_formula = "bricks_destroyed × combo / balls_lost"
```

**Coin Flip**:
```lua
base_formula = "max_streak^2 * (1 + correct_total/10) * scaling_constant"
display_formula = "max_streak × correct_total"
```

**RPS**:
```lua
base_formula = "(rounds_won - rounds_lost)^2 * (1 + max_win_streak/5) * scaling_constant"
display_formula = "(rounds_won - rounds_lost) × win_streak"
```

### Asset Requirements

**Breakout**:
- Paddle sprite (simple rectangle, recolorable)
- Ball sprite (circle, trail effect)
- Brick sprite (rectangle, multiple health states)
- Power-up sprites (icons for each type)
- Background variations (starfield, gradient, etc.)
- SFX: ball bounce, brick break, power-up collect, paddle hit

**Coin Flip**:
- Coin sprite (heads side, tails side)
- Flip animation frames (or rotate sprite)
- Result display (text or sprite)
- Background (simple gradient or pattern)
- SFX: coin flip, correct guess, wrong guess

**RPS**:
- Hand sprites (rock, paper, scissors, lizard, spock)
- Throw animation frames
- Result display (winner indicator)
- History display icons
- Background (simple themed)
- SFX: throw sound, win/lose/tie sounds

---

## End of Document
