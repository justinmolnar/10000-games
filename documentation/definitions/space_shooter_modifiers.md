# Space Shooter - Variant Modifiers

All properties can be added to any Space Shooter variant in `assets/data/variants/space_shooter_variants.json`.

## Per-Variant Modifiers (Player Movement)

**movement_type** [default]: Movement control scheme. Options:
  - "default": Standard left/right movement with WASD
  - "rail": Fixed lateral movement (left/right only, rapid side-to-side)
  - "asteroids": Rotate and thrust with momentum physics
  - "jump": Discrete teleport jumps between positions

Hidden parameter (requires dropdown).

**movement_speed** [200]: Base player movement speed in pixels/second. Higher = faster dodging. Range: 50-500

**rotation_speed** [5.0]: Asteroids mode rotation speed in degrees/frame. Higher = tighter turns. Range: 1-15

**accel_friction** [1.0]: Asteroids mode acceleration responsiveness. 1.0 = instant accel, 0.9 = slower buildup. Range: 0.5-1.0

**decel_friction** [1.0]: Asteroids mode deceleration/drag. 1.0 = no friction, 0.95 = gradual slowdown. Range: 0.8-1.0

**jump_distance** [0.08]: Jump mode dash distance as % of screen width. 0.08 = 8% of screen. Range: 0.05-0.3

**jump_cooldown** [0.5]: Jump mode cooldown between jumps in seconds. Range: 0.1-2.0

**jump_speed** [400]: Jump mode dash speed in pixels/second. Range: 200-1000

## Per-Variant Modifiers (Player Health & Defense)

**lives_count** [5]: Starting lives. Higher = more forgiving. Range: 1-50

**shield** [false]: If true, enables rechargeable energy shield.

**shield_regen_time** [5.0]: Seconds to regenerate shield after breaking. Range: 1-20

**shield_hits** [1]: Number of hits shield can absorb before breaking. Range: 1-10

## Per-Variant Modifiers (Weapon System - Fire Modes)

**fire_mode** [manual]: Shooting mechanism. Options:
  - "manual": Press space to fire with cooldown (classic)
  - "auto": Hold space for continuous fire at fire_rate
  - "charge": Hold to charge, release for powerful shot
  - "burst": Tap space to fire rapid burst of burst_count bullets

Hidden parameter (requires dropdown).

**fire_rate** [1.0]: Shots per second for auto mode. Higher = more dakka. Range: 0.5-10

**burst_count** [3]: Number of bullets per burst in burst mode. Range: 2-10

**burst_delay** [0.1]: Seconds between burst shots. Lower = tighter burst. Range: 0.05-0.5

**charge_time** [1.0]: Seconds to fully charge in charge mode. Range: 0.3-3.0

## Per-Variant Modifiers (Weapon System - Ammo & Overheat)

**ammo_enabled** [false]: If true, enables ammo system with limited ammunition.

**ammo_capacity** [50]: Maximum ammunition capacity. Player starts with this amount. Range: 5-500

**ammo_reload_time** [2.0]: Seconds required to reload ammo. Auto-reloads when empty, or manual reload with 'R' key. Range: 0.5-10.0

**overheat_enabled** [false]: If true, enables overheat system. Weapon heats up with each shot.

**overheat_threshold** [10]: Number of shots before weapon overheats. Range: 3-100

**overheat_cooldown** [3.0]: Seconds required to cool down after overheating. Range: 0.5-10.0

**overheat_heat_dissipation** [2.0]: Heat units dissipated per second when not shooting. Higher = faster passive cooldown. Range: 0.1-10.0

## Per-Variant Modifiers (Weapon System - Bullet Patterns)

**bullet_pattern** [single]: Bullet firing pattern. Options:
  - "single": One bullet straight ahead (classic)
  - "double": Two bullets parallel (shotgun)
  - "triple": Three bullets in slight spread
  - "spread": Fan of bullets across bullet_arc angle
  - "spiral": Rotating pattern (360° coverage)
  - "wave": Three bullets with wave motion

Hidden parameter (requires dropdown).

**bullet_arc** [30]: Degrees of arc for spread-based patterns. Larger = wider spread. Range: 15-90

**bullets_per_shot** [1]: Multiplier for pattern bullet count. Affects spread/spiral density. Range: 1-12

**spread_angle** [30]: Degrees for spread pattern (legacy, use bullet_arc instead). Range: 15-90

## Per-Variant Modifiers (Weapon System - Bullet Behavior)

**bullet_speed** [400]: Bullet velocity in pixels/second. Range: 100-1000

**bullet_gravity** [0]: Downward gravity on bullets in pixels/sec². 0 = straight, 500 = strong arc. Range: 0-1000

**bullet_homing** [false]: If true, bullets curve toward nearest enemy.

**homing_strength** [0.0]: Homing aggressiveness. 0.0 = none, 1.0 = strong tracking. Range: 0-2.0

**bullet_piercing** [false]: If true, bullets pass through enemies instead of disappearing.

## Per-Variant Modifiers (Enemy Systems - Phase 5)

**enemy_behavior** [default]: Overall enemy behavior pattern. Options:
  - "default": Standard spawning and movement (uses spawn_pattern below)
  - "space_invaders": Grid formation that moves side-to-side and descends
  - "galaga": Formation parking with dive attacks and entrance swoops

Hidden parameter (requires dropdown).

**enemy_spawn_pattern** [continuous]: Enemy spawn behavior (only used with default behavior). Options:
  - "continuous": Steady spawn rate (default)
  - "waves": Groups of enemies with pauses between
  - "clusters": Spawn 3-5 enemies at once with longer delays

Hidden parameter (requires dropdown).

**enemy_spawn_rate_multiplier** [1.0]: Multiplier on enemy spawn frequency. Higher = more enemies. Range: 0.1-10.0

**enemy_speed_multiplier** [1.0]: Multiplier on all enemy speeds. Higher = faster enemies. Range: 0.1-5.0

**enemy_health** [1]: Hits required to destroy each enemy. Higher = tankier enemies. Range: 1-10

**waves_enabled** [false]: Enable wave system for space_invaders/galaga behaviors. When enabled, enemies respawn in waves after all are destroyed.

**wave_difficulty_increase** [0.1]: Difficulty increase per wave (0.1 = 10% harder each wave). Affects enemy count, speed, health, and dive frequency. Range: 0.0-1.0

**wave_random_variance** [0.0]: Random variance in wave parameters (0-1). 0 = consistent waves, 0.5 = ±50% random variation per wave. Adds unpredictability. Range: 0.0-1.0

**enemy_density** [1.0]: Spacing multiplier for enemy formations. 0.5 = tight formation, 2.0 = loose/spread out. Range: 0.3-3.0

### Space Invaders Parameters (only used when enemy_behavior = "space_invaders")

**grid_rows** [4]: Number of rows in the grid formation. Range: 1-10

**grid_columns** [8]: Number of columns in the grid formation. Range: 2-16

**grid_speed** [50]: Base movement speed of the grid in pixels/second. Speed increases as enemies die. Range: 10-200

**grid_descent** [20]: Pixels to drop when grid reverses direction at screen edge. Range: 5-50

### Galaga Parameters (only used when enemy_behavior = "galaga")

**formation_size** [24]: Total number of formation slots (enemies per wave). Automatically wraps to screen width. Range: 8-48

**initial_spawn_count** [8]: Number of enemies that spawn immediately when wave starts. Remaining enemies spawn gradually. Range: 1-24

**spawn_interval** [0.5]: Seconds between gradual enemy spawns after initial batch. Lower = faster formation filling. Range: 0.1-2.0

**dive_frequency** [3.0]: Seconds between dive attacks. Lower = more frequent dives. Range: 0.5-10.0

**max_diving_enemies** [1]: Maximum number of enemies diving simultaneously. Range: 1-5

**entrance_pattern** [swoop]: Entrance swoop pattern for enemies joining formation. Options:
  - "swoop": Swoop down then up to formation position
  - "loop": Loop around to formation
  - "arc": Simple arc to formation

Hidden parameter (requires dropdown).

**enemy_formation** [scattered]: Formation pattern for enemy spawning. Options:
  - "scattered": Random positioning (default)
  - "v_formation": 5 enemies in V shape
  - "wall": 6 enemies in horizontal line
  - "spiral": 8 enemies in circular pattern

Hidden parameter (requires dropdown).

**enemy_bullets_enabled** [false]: If true, enables enemies to shoot bullets at player.

**enemy_bullet_speed** [200]: Speed of enemy bullets in pixels/second. Range: 50-800

**enemy_fire_rate** [2.0]: Enemy shots per second. Higher = more bullets. Range: 0.5-10.0

**enemy_bullet_pattern** [single]: Enemy bullet firing pattern. Options:
  - "single": One bullet straight down (default)
  - "spread": Multiple bullets in arc pattern
  - "spray": Many bullets randomly spread (true bullet hell)
  - "ring": Bullets in all directions (360° spray)

Hidden parameter (requires dropdown).

**enemy_bullets_per_shot** [1]: Number of bullets per enemy shot. Used with spread/spray/ring patterns. Range: 1-20

**enemy_bullet_spread_angle** [30]: Degrees of arc for spread-based patterns. Larger = wider spread. Range: 10-180

**wave_enemies_per_wave** [5]: Number of enemies spawned per wave (when using wave spawn pattern). Range: 1-20

**wave_pause_duration** [3.0]: Seconds of pause between waves. Range: 0.5-10.0

**difficulty_curve** [linear]: How difficulty scales over time. Options:
  - "linear": Steady increase
  - "exponential": Rapid ramp-up
  - "wave": Alternating hard/easy periods

Hidden parameter (requires dropdown).

**difficulty_scaling_rate** [0.1]: Rate of difficulty increase. Higher = faster scaling. Range: 0.0-1.0

## Per-Variant Modifiers (Power-Up System - Phase 6)

**powerup_enabled** [false]: If true, enables power-up spawning system.

**powerup_spawn_rate** [15.0]: Seconds between power-up spawns. Lower = more frequent. Range: 1.0-60.0

**powerup_duration** [8.0]: Duration of power-up effects in seconds. Range: 1.0-30.0

**powerup_types** [array]: Array of power-up type strings. Available types:
  - "speed": Movement speed boost (configurable multiplier)
  - "rapid_fire": Fire rate boost (configurable cooldown multiplier)
  - "pierce": Bullets pierce through enemies
  - "shield": Instant shield refresh
  - "triple_shot": Temporary triple shot pattern
  - "spread_shot": Temporary spread shot pattern

Hidden parameter (array of strings).

Example:
```json
"powerup_types": ["speed", "rapid_fire", "pierce"]
```

**powerup_drop_speed** [150]: How fast power-ups fall in pixels/second. Higher = harder to catch. Range: 10-400

**powerup_size** [20]: Hitbox size of power-ups in pixels. Larger = easier to collect. Range: 10-50

**powerup_speed_multiplier** [1.5]: Multiplier for speed boost power-up. Higher = faster movement. Range: 1.1-3.0

**powerup_rapid_fire_multiplier** [0.5]: Cooldown multiplier for rapid fire power-up. Lower = faster shooting. Range: 0.1-0.9

## Per-Variant Modifiers (Environmental Hazards - Phase 7)

**asteroid_density** [0]: Asteroids spawned per second. 0 = disabled, 5 = moderate, 10 = dense field. Range: 0-10

**asteroid_speed** [100]: How fast asteroids fall in pixels/second. Range: 20-400

**asteroid_size_min** [20]: Minimum asteroid size in pixels. Range: 10-40

**asteroid_size_max** [50]: Maximum asteroid size in pixels. Range: 30-100

**asteroids_can_be_destroyed** [true]: If true, player bullets can destroy asteroids. If false, asteroids are indestructible.

**meteor_frequency** [0]: Meteor waves per minute. 0 = disabled, higher = more frequent waves. Range: 0-10

**meteor_speed** [400]: How fast meteors fall in pixels/second. Faster than asteroids. Range: 100-800

**meteor_warning_time** [1.0]: Seconds of warning indicator before meteor appears. Range: 0.1-3.0

**gravity_wells_count** [0]: Number of gravity wells spawned. 0 = disabled. Range: 0-10

Hidden parameter (would show as "gravity_wells" in CheatEngine).

**gravity_well_strength** [400]: Pull strength of gravity wells in pixels/second. Higher = stronger pull. Range: 50-500

**gravity_well_radius** [150]: Effect radius of gravity wells in pixels. Larger = wider area of influence. Range: 50-300

**scroll_speed** [0]: Vertical scrolling speed in pixels/second. Creates vertical shooter feel. 0 = disabled. Range: 0-500

## Per-Variant Modifiers (Special Mechanics - Phase 8)

**screen_wrap** [false]: Enable Asteroids-style screen wrapping for player. Reaching edge wraps to opposite side.

**screen_wrap_bullets** [false]: Enable screen wrapping for player bullets.

**bullet_max_wraps** [2]: Maximum times a bullet can wrap before being destroyed. Prevents infinite bullets. Range: 1-10

**screen_wrap_enemies** [false]: Enable screen wrapping for enemies.

**reverse_gravity** [false]: Completely flip the play space upside down. Player spawns at top instead of bottom, enemies spawn at bottom and move upward, bullets travel downward instead of upward.

**blackout_zones_count** [0]: Number of dark circular zones with reduced visibility. 0 = disabled. Range: 0-5

Hidden parameter (would show as "blackout_zones" in CheatEngine).

**blackout_zone_radius** [100]: Radius of blackout zones in pixels. Range: 50-200

**blackout_zones_move** [false]: If true, blackout zones drift around the arena bouncing off walls.

## Per-Variant Modifiers (Victory Conditions - Phase 8)

**victory_condition** [kills]: Type of victory condition. Options:
  - "kills": Destroy X enemies (default)
  - "time": Survive for X seconds
  - "survival": Endless mode - never complete
  - "score": Reach X score points

Hidden parameter (requires dropdown).

**victory_limit** [20]: Victory threshold based on condition type. For kills: enemy count. For time: seconds. For score: points. Range: 1-1000

## Per-Variant Modifiers (Enemy Composition)

**enemies** [array]: Array of enemy type objects with multipliers. Each object has:
  - `type`: Enemy type name ("basic", "weaver", "bomber", "kamikaze")
  - `multiplier`: Spawn rate multiplier (1.0 = normal, 2.0 = 2x more frequent)

Example:
```json
"enemies": [
  { "type": "basic", "multiplier": 1.5 },
  { "type": "weaver", "multiplier": 0.5 }
]
```

If not specified, uses default balanced mix.

## Per-Variant Modifiers (Audio/Visual Metadata)

**sprite_set** [fighter_1]: Which sprite folder to load from `assets/sprites/games/space_shooter/`. Examples: "fighter_1", "fighter_2". Hidden parameter (visual only).

**palette** [blue]: Color palette ID for palette swapping. Examples: "blue", "red", "green", "purple", "cyan", "yellow", "rainbow". Hidden parameter (visual only).

**music_track** [space_theme_1]: Path to music file. Examples: "space_theme_1", "space_theme_2", "space_theme_intense", "space_theme_ambient". Hidden parameter (audio only).

**sfx_pack** [retro_beeps]: Which SFX pack to use. Options: "retro_beeps", "modern_ui", "8bit_arcade". Hidden parameter (audio only).

**background** [stars_blue]: Background visual theme. Examples: "stars_blue", "stars_red", "stars_green", "stars_purple", "stars_yellow". Hidden parameter (visual only).

## Per-Variant Modifiers (Difficulty & Flavor)

**difficulty_modifier** [1.0]: Overall difficulty multiplier. Scales enemy spawn rate, bullet speed, etc. Higher = harder. Range: 0.5-3.0

**flavor_text** [null]: Short description shown in launcher (optional).

**intro_cutscene** [null]: Intro cutscene ID (optional, not yet implemented).

## Implementation Status

✅ **Phase 1 Complete** - Movement Systems
- Default, rail, asteroids, and jump movement modes
- All movement parameters (speed, rotation, friction, jump)
- Lives and shield system

✅ **Phase 2 Complete** - Advanced Movement & Defense
- Shield regeneration mechanics
- Bullet gravity system
- Enemy composition variants

✅ **Phase 3 Complete** - Weapon Systems
- Fire modes: manual, auto, charge, burst
- Bullet patterns: single, double, triple, spread, spiral, wave
- Bullet behaviors: homing, piercing, wave motion
- Bullet arc and bullets_per_shot parameters

✅ **Phase 4 Complete** - Ammo & Overheat Systems
- Ammo system: Limited ammunition with manual/auto reload
- Overheat system: Heat buildup with cooldown period
- HUD displays: Ammo counter, reload progress bar, heat bar, overheat warning
- Test variants: Ammo Limited, Overheat Challenge, Resource Management, Unlimited Power

✅ **Phase 5 Complete** - Enemy Systems
- Spawn patterns: continuous, waves, clusters
- Formations: scattered, v_formation, wall, spiral
- Enemy bullets: configurable speed and fire rate
- Difficulty scaling: linear, exponential, wave curves
- Speed multipliers: spawn rate and enemy speed
- Test variants: Wave Assault, Bullet Hell, V-Formation, Exponential Chaos

✅ **Phase 6 Complete** - Power-Up System
- Power-up spawning with configurable rate and duration
- Six power-up types: speed, rapid_fire, pierce, shield, triple_shot, spread_shot
- Active power-up HUD display with countdown timers
- Visual indicators: colored orbs drift downward
- Configurable drop speed, size, and effect multipliers
- Test variants: Power-Up Heaven, Speed Demon, Weapon Festival

✅ **Phase 7 Complete** - Environmental Hazards
- Asteroid field system: density, speed, size range, destructibility
- Meteor shower system: frequency, speed, warning indicators
- Gravity wells: count, strength, radius, affects player and bullets
- Vertical scrolling speed for scrolling shooter feel
- Test variants: Asteroid Belt, Meteor Storm, Gravity Chaos, Speed Scroller

✅ **Phase 8 Complete** - Special Mechanics & Victory Conditions
- Screen wrap: player, bullets, enemies (Asteroids-style)
- Reverse gravity: flips play space upside down (player at top, enemies from bottom)
- Blackout zones: dark areas with reduced visibility, optional movement
- Victory conditions: kills, time, survival (endless), score
- Test variants: Wraparound, Upside Down, Fog of War, Speed Run

✅ **Phase 9 Complete** - CheatEngine Integration & Polish
- Added all missing parameter ranges to config.lua (bullet_arc, bullets_per_shot, etc.)
- Updated hidden_parameters list with all enum/dropdown parameters
- Verified movement_type, fire_mode, bullet_pattern, enemy_spawn_pattern, enemy_formation, enemy_bullet_pattern, difficulty_curve, powerup_types are properly hidden
- All 50+ Space Shooter parameters now exposed in CheatEngine with proper ranges
- Fixed reverse gravity player sprite rotation (180° flip)
- Fixed reverse gravity for all systems: enemies, bullets, powerups, asteroids, meteors

✅ **Phase 10 Complete** - Variant Creation & Final Polish
- Created 43 unique variants with creative parameter combinations
- Each variant explores different synergies across all 8 phases of mechanics
- Variants include: Homing Burst Assassin, Gravity Arc Weaver, Rail Minigun, Teleport Sniper, Spiral Madness, Spread Shotgun Tank, Ammo Scavenger, Wave Assault Commander, Bullet Hell Dancer, V-Formation Hunter, Exponential Survivor, Power-Up Junkie, Asteroid Miner, Meteor Dodge Master, Gravity Well Navigator, Speed Scroller Extreme, Wraparound Asteroids, Upside Down World, Fog of War Tactics, 30 Second Sprint, Endless Survival, Score Attack Pro, Charge Cannon Behemoth, Overheat Management, Ammo Crisis, Double Jeopardy, Cluster Swarm, Bullet Storm Chaos, Wave Rhythm Master, Asteroid + Meteor Hell, Gravity Scroller, Wraparound Bullets Only, Complete Wraparound, Reverse Gravity Scroller, Blackout Meteor Storm, Jump Teleport Frenzy, Homing Spiral Galaxy, Power-Up Speed Demon, The Kitchen Sink, Precision Sniper, Piercing Wave Cascade, Triple Threat Burst
- All major parameter combinations tested
- Space Shooter fully featured and ready for expansion

## Notes

- All boolean parameters default to `false` unless specified
- All numeric parameters have config defaults that can be overridden per-variant
- Movement types are mutually exclusive (only one can be active)
- Fire modes are mutually exclusive (only one can be active)
- Bullet patterns work with all fire modes
- Enemy composition is additive (all specified types spawn with given multipliers)
- Tinting is automatically applied based on `clone_index` seed unless overridden with `tint` or `tint_enabled`
