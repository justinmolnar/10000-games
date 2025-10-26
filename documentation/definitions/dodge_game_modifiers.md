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

## Per-Variant Modifiers (Player Properties)

**player_size** [1.0]: Multiplier for player sprite size and hitbox radius. 0.5 = tiny, 1.0 = normal, 2.0 = giant. Affects both visual size and collision detection. Range: 0.3-3.0

**max_speed** [600]: Maximum speed cap for player in pixels/second. 0 = no limit. When > 0, velocity is clamped to this value after all forces (input, gravity, wind) are applied. Useful for preventing runaway speed from environmental forces. Range: 0-1200

**lives** [10]: Number of collisions (hits) the player can take before game over. Each obstacle collision consumes 1 life (unless absorbed by shield). Lower = higher difficulty. Range: 1-50

**shield** [0]: Number of shield charges. Each charge absorbs one hit before lives are consumed. Shield recharges over time if shield_recharge_time > 0. Range: 0-10

**shield_recharge_time** [0]: Time in seconds to recharge one shield charge. 0 = shields never recharge. Higher = slower recharge. Shield recharge timer resets after consuming a charge. Range: 0-60

## Per-Variant Modifiers (Obstacle Behavior)

**obstacle_tracking** [0.0]: Homing/tracking strength for obstacles. 0.0 = no tracking (straight line), 0.5 = moderate homing, 1.0 = aggressive homing. Obstacles gradually turn toward player. Range: 0.0-1.0

**obstacle_speed_variance** [0.0]: Random speed variance for spawned obstacles. 0.0 = all obstacles same speed, 0.5 = ±50% variance, 1.0 = ±100% variance. Each obstacle gets a random speed multiplier. Range: 0.0-1.0

**obstacle_spawn_rate** [1.0]: Spawn rate multiplier. 0.5 = half speed, 1.0 = normal, 2.5 = 2.5x spawn rate. Directly multiplies the spawn timer. Range: 0.1-5.0

**obstacle_spawn_pattern** [random]: Spawn pattern behavior. Options:
  - "random": Traditional random spawns from edges
  - "waves": Bursts of 6 objects every 0.15s, then 2.5s pause
  - "clusters": Spawn 3-5 objects at similar angles simultaneously
  - "spiral": Rotating spawn angle creating spiral pattern
  - "pulse_with_arena": Spawn from safe zone boundary outward

**obstacle_size_variance** [0.0]: Random size variance for obstacles. 0.0 = all same size, 0.5 = ±50%, 1.0 = ±100%. Range: 0.0-1.0

**obstacle_trails** [0]: Trail length for obstacles. 0 = no trails, 10 = short trail, 30 = long trail. Trails are solid and damage the player on contact. Range: 0-50

## Per-Variant Modifiers (Environmental Forces)

**area_gravity** [0.0]: Gravity force toward/away from safe zone center. Positive = pull toward center (vortex), negative = push away (repel). Applied as constant acceleration. Range: -500 to 500

**wind_direction** [0]: Wind direction in degrees. 0 = right, 90 = down, 180 = left, 270 = up. Only used when wind_type != "none". Range: 0-360

**wind_strength** [0]: Wind force strength in pixels/second². 0 = no wind. Higher = stronger push. Applied as constant acceleration in wind_direction. Range: 0-500

**wind_type** [none]: Wind behavior type. Options:
  - "none": No wind
  - "steady": Constant wind in wind_direction
  - "turbulent": Steady wind with random fluctuations
  - "changing_steady": Wind changes direction every 3s, smooth transition
  - "changing_turbulent": Wind changes direction every 3s with turbulence

## Per-Variant Modifiers (Visual Effects)

**fog_of_war_origin** [none]: Fog of war center point. Options:
  - "none": No fog (full visibility)
  - "player": Fog centered on player (you can only see nearby)
  - "circle_center": Fog centered on safe zone center
  - "screen_center": Fog centered on screen center

**fog_of_war_radius** [9999]: Visibility radius in pixels. Only visible within this radius from fog origin. 9999 = no fog (effectively disabled). Lower = more claustrophobic. Range: 50-9999

**camera_shake_intensity** [0.0]: Camera shake intensity on collision. 0.0 = no shake, 1.0 = moderate shake, 2.0 = heavy shake. Shield hits use 50% intensity. Shake decays exponentially. Range: 0.0-5.0

**player_trail_length** [0]: Player trail length in points. 0 = no trail, 10 = short trail, 30 = long trail. Trail originates from back of sprite and follows movement. Range: 0-50

**score_multiplier_mode** [none]: Score multiplier system based on player behavior. Multiplier applied to final score on victory. Options:
  - "none": No multiplier (1.0x)
  - "center": Higher multiplier for staying near safe zone center
  - "edge": Higher multiplier for staying near safe zone edge (risky play)
  - "speed": Higher multiplier for maintaining high speed

## Per-Variant Modifiers (Victory Conditions)

**victory_condition** [dodge_count]: Win condition type. Options:
  - "dodge_count": Win by dodging X objects (set by victory_limit)
  - "time": Win by surviving X seconds (set by victory_limit)

**victory_limit** [30]: Victory target value. For "dodge_count": number of objects to dodge. For "time": seconds to survive. Range: 1-300

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

### Fog Runner (Claustrophobic)
```json
{
  "clone_index": 6,
  "name": "Dodge Fog Runner",
  "fog_of_war_origin": "player",
  "fog_of_war_radius": 120,
  "victory_condition": "time",
  "victory_limit": 45,
  "player_trail_length": 20,
  "sprite_set": "base_1",
  "palette": "gray"
}
```
Feel: Tense limited visibility, time-based survival, trail helps track movement

### Shield Tank (Defensive)
```json
{
  "clone_index": 7,
  "name": "Dodge Shield Tank",
  "lives": 3,
  "shield": 2,
  "shield_recharge_time": 12,
  "player_size": 1.5,
  "max_speed": 400,
  "camera_shake_intensity": 1.5,
  "sprite_set": "base_2",
  "palette": "blue"
}
```
Feel: Low lives but rechargeable shields, larger slower target, visual feedback on hits

### Gravity Vortex (Environmental)
```json
{
  "clone_index": 8,
  "name": "Dodge Vortex",
  "area_gravity": 250,
  "obstacle_tracking": 0.6,
  "max_speed": 500,
  "movement_speed": 400,
  "sprite_set": "base_1",
  "palette": "purple"
}
```
Feel: Constant pull toward center, homing obstacles, must fight environment and enemies

### Storm Chaser (Wind + Chaos)
```json
{
  "clone_index": 9,
  "name": "Dodge Storm",
  "wind_type": "changing_turbulent",
  "wind_strength": 200,
  "wind_direction": 0,
  "obstacle_spawn_pattern": "waves",
  "max_speed": 600,
  "lives": 5,
  "sprite_set": "base_1",
  "palette": "yellow"
}
```
Feel: Unpredictable wind forces, burst spawning, must adapt constantly

### Bullet Hell Nano (Extreme)
```json
{
  "clone_index": 10,
  "name": "Dodge Bullet Hell",
  "obstacle_spawn_rate": 2.5,
  "obstacle_trails": 15,
  "lives": 1,
  "player_size": 0.6,
  "max_speed": 700,
  "victory_limit": 50,
  "sprite_set": "base_1",
  "palette": "red"
}
```
Feel: High-intensity bullet hell, one-hit-kill, tiny hitbox, obstacle trails create deadly zones
