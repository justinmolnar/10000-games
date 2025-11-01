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

⏳ **Phase 5 Pending** - Enemy Systems

⏳ **Phase 5 Pending** - Environmental Hazards

⏳ **Phase 6 Pending** - Victory Conditions & Time Limits

⏳ **Phase 7 Pending** - Arena Modifiers

⏳ **Phase 8 Pending** - Polish & Edge Cases

## Notes

- All boolean parameters default to `false` unless specified
- All numeric parameters have config defaults that can be overridden per-variant
- Movement types are mutually exclusive (only one can be active)
- Fire modes are mutually exclusive (only one can be active)
- Bullet patterns work with all fire modes
- Enemy composition is additive (all specified types spawn with given multipliers)
- Tinting is automatically applied based on `clone_index` seed unless overridden with `tint` or `tint_enabled`
