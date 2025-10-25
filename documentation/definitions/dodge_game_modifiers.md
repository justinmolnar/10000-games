# Dodge Game - Variant Modifiers

All properties can be added to any Dodge variant in `assets/data/variants/dodge_variants.json`.

## Per-Variant Modifiers (Gameplay Feel)

**movement_type** [default]: Movement control scheme. Options: "default" (WASD direct movement), "asteroids" (turn + thrust), "jump" (discrete jumps with cooldown)

**rotation_speed** [2.0]: How fast the player sprite rotates. Lower = sluggish tank-like turning, Higher = twitchy responsive turning. (2.0 ≈ 115°/s, 8.0 ≈ 458°/s). Range: 0.5-20

**movement_speed** [300]: Player movement speed. In default mode: direct velocity. In asteroids mode: thrust acceleration power. In jump mode: not used (use jump_distance instead). Range: 50-600

**jump_distance** [80]: Distance each jump travels (jump mode only). Higher = longer jumps, farther you rocket in each direction. Range: 20-200

**jump_cooldown** [0.5]: Time between jumps in seconds (jump mode only). Higher = slower strategic movement, lower = rapid successive jumps. Range: 0.1-2.0

**jump_speed** [800]: Speed of the jump/dash movement in pixels/second (jump mode only). Lower = see the dash movement, higher = faster dash. 9999+ = instant teleport. Range: 200-9999

**accel_friction** [1.0]: Friction when accelerating (starting up). 1.0 = instant acceleration. <1.0 = resistance when starting to move. Lower = slower ramp-up. Applies to default and asteroids modes only (not jump mode). Range: 0.0-1.0

**decel_friction** [1.0]: Friction when decelerating (stopping). 1.0 = instant stop. 0.98 = very slippery ice, 0.95 = moderate drift, 0.90 = heavy drag. Lower = more drift/momentum after releasing keys. In jump mode: when < 1.0, enables drift after jumps (slide in jump direction). Range: 0.0-1.0

**bounce_damping** [0.5]: Wall bounce strength. 0.0 = no bounce (stick to walls), 0.5 = medium bounce (50% velocity retained), 1.0 = perfect elastic bounce. Applies to screen edges and safe zone boundary. In jump mode: only works when decel_friction < 1.0 (momentum enabled). Range: 0.0-1.0

**reverse_mode** [none]: Down key behavior (asteroids mode only). Options: "none" (down does nothing), "brake" (active braking, faster deceleration), "thrust" (reverse thrust, accelerate backwards)

## Per-Variant Modifiers (Safe Zone Customization)

**area_size** [1.0]: Multiplier on safe zone radius. 2.0 = double size, 0.5 = half size. Affects both initial and minimum radius. Range: 0.3-3.0

**area_shape** [circle]: Shape of the safe zone boundary. Options: "circle" (smooth), "square" (sharp corners), "hex" (hexagonal)

**area_morph_type** [shrink]: How the safe zone changes over time. Options: "shrink" (gradually shrinks to min), "pulsing" (oscillates in size), "shape_shifting" (cycles through shapes), "deformation" (wobbles/warps), "none" (static)

**area_morph_speed** [1.0]: Speed multiplier for morphing effects. 0 = disabled, higher = faster morphing. Range: 0.0-5.0

**area_movement_type** [random]: How the safe zone moves. Options: "random" (smooth random drift), "cardinal" (switches between N/S/E/W), "none" (stationary)

**area_movement_speed** [1.0]: Safe zone movement speed multiplier. 0 = static, 1.0 = default drift speed, 2.0 = twice as fast. Range: 0.0-3.0

**area_friction** [1.0]: How quickly safe zone changes direction. 1.0 = instant direction changes, <1.0 = smooth momentum-based transitions. Lower = more drift when changing direction. Range: 0.8-1.0

## Per-Variant Modifiers (Game Over System)

**leaving_area_ends_game** [false]: If true, player leaving the safe zone = instant game over. Creates high-tension variants where staying inside is critical

**holes_type** [none]: Type of hazard holes. Options: "circle" (holes on safe zone boundary, move with it), "background" (static holes in arena), "none" (no holes)

**holes_count** [0]: Number of hazard holes to spawn. Touching a hole = instant game over. Range: 0-15

## Per-Variant Modifiers (Audio/Visual)

**sprite_set** [base_1]: Which sprite folder to load from `assets/sprites/games/dodge/`. Examples: "base_1", "base_2", "neon"

**palette** [blue]: Color palette ID for palette swapping. Examples: "blue", "red", "purple", "green", "gold"

**music_track** [null]: Path to music file. Example: "dodge_theme_1", "dodge_theme_2"

**sfx_pack** [retro_beeps]: Which SFX pack to use. Options: "retro_beeps", "modern_ui", "8bit_arcade"

**background** [starfield_blue]: Background visual theme. Examples: "starfield_blue", "starfield_red", "starfield_purple"

## Per-Variant Modifiers (Difficulty)

**difficulty_modifier** [1.0]: Overall difficulty multiplier. Scales spawn rate, object speed, etc. Higher = harder. Range: 0.5-3.0

**enemies** [[]]: Array of enemy type definitions. Example: `[{"type": "chaser", "multiplier": 1.0}, {"type": "shooter", "multiplier": 0.5}]`
  - Enemy types: "chaser", "shooter", "bouncer", "zigzag", "teleporter"

## Per-Variant Modifiers (Flavor)

**name** [required]: Display name for this variant. Example: "Dodge Master"

**flavor_text** [""]: Description shown in launcher. Example: "Classic obstacle avoidance!"

**intro_cutscene** [null]: Path to cutscene file (future feature)

**clone_index** [required]: Unique index for this variant (0, 1, 2, ...)

## Example Variants

### Classic Dodge
```json
{
  "clone_index": 0,
  "name": "Dodge Classic",
  "movement_type": "default",
  "rotation_speed": 8.0,
  "movement_speed": 300,
  "accel_friction": 1.0,
  "decel_friction": 1.0,
  "bounce_damping": 0.0,
  "sprite_set": "base_1",
  "palette": "blue"
}
```
Feel: Precise, responsive, no momentum or bounce

### Ice Rink
```json
{
  "clone_index": 1,
  "name": "Dodge Ice Rink",
  "movement_type": "default",
  "rotation_speed": 6.0,
  "movement_speed": 350,
  "accel_friction": 0.98,
  "decel_friction": 0.96,
  "bounce_damping": 0.4,
  "sprite_set": "base_1",
  "palette": "cyan"
}
```
Feel: Slippery! Slow to start, long drift, soft bounces

### Pinball
```json
{
  "clone_index": 2,
  "name": "Dodge Pinball",
  "movement_type": "default",
  "rotation_speed": 10.0,
  "movement_speed": 400,
  "accel_friction": 1.0,
  "decel_friction": 0.99,
  "bounce_damping": 0.9,
  "sprite_set": "base_1",
  "palette": "purple"
}
```
Feel: Chaotic bouncing, hard to control, instant start but long drift

### Space Fighter
```json
{
  "clone_index": 3,
  "name": "Dodge Fighter",
  "movement_type": "asteroids",
  "rotation_speed": 4.0,
  "movement_speed": 600,
  "accel_friction": 1.0,
  "decel_friction": 0.98,
  "bounce_damping": 0.5,
  "reverse_mode": "thrust",
  "sprite_set": "base_2",
  "palette": "red"
}
```
Feel: Classic space flight with reverse thrusters

### Heavy Tank
```json
{
  "clone_index": 4,
  "name": "Dodge Tank",
  "movement_type": "asteroids",
  "rotation_speed": 1.5,
  "movement_speed": 400,
  "accel_friction": 0.95,
  "decel_friction": 0.93,
  "bounce_damping": 0.2,
  "reverse_mode": "brake",
  "sprite_set": "base_2",
  "palette": "gray"
}
```
Feel: Slow turning, slow to start, heavy momentum, soft impacts

### Nimble Scout
```json
{
  "clone_index": 5,
  "name": "Dodge Scout",
  "movement_type": "asteroids",
  "rotation_speed": 12.0,
  "movement_speed": 700,
  "accel_friction": 1.0,
  "decel_friction": 0.95,
  "bounce_damping": 0.6,
  "reverse_mode": "thrust",
  "sprite_set": "base_1",
  "palette": "green"
}
```
Feel: Fast, agile, instant acceleration, moderate drift - high skill ceiling
