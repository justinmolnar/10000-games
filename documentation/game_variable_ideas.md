# Game Variable Ideas - Variant System Expansion

This document contains brainstormed variable ideas for creating diverse and interesting variants across all 5 minigames. The goal is to create clones that feel genuinely different, not just harder copies.

---

## Dodge Game Variables

### Player Physics (Already Implemented)
- `movement_type` - "default", "asteroids", "jump"
- `movement_speed` - Base movement speed
- `rotation_speed` - How fast player rotates
- `accel_friction` - Resistance when starting to move
- `decel_friction` - Resistance when stopping (drift)
- `bounce_damping` - Wall bounce strength
- `jump_distance` - Distance per jump (jump mode)
- `jump_cooldown` - Time between jumps (jump mode)
- `jump_speed` - Speed of dash movement (jump mode)
- `reverse_mode` - "none", "brake", "thrust" (asteroids mode)

### Player Physics (New Ideas)
- `player_size` - Scale player hitbox (0.5 = tiny dodger, 2.0 = big target)
- `player_mass` - How much obstacles push you around when they pass near
- `drag_coefficient` - Air resistance that slows you over time
- `max_speed_cap` - Hard velocity limit (prevents runaway speed in asteroids mode)
- `invincibility_frames` - Brief invincibility after close call (0.2 seconds?)
- `lives_count` - Multiple hits before game over (3 lives mode)
- `shield_recharge_time` - Regenerating shield system (10 seconds between hits)

### Obstacle Behavior (New Ideas)
- `obstacle_tracking` - Homing behavior (0.0 = random, 0.5 = slight tracking, 1.0 = aggressive homing)
- `obstacle_speed_variance` - Random speed variation (0.0 = uniform, 1.0 = chaotic mix)
- `obstacle_spawn_rate` - Multiplier on spawn frequency (0.5 = sparse, 2.0 = bullet hell)
- `obstacle_spawn_pattern` - "random", "waves", "clusters", "spiral", "pulse_with_arena"
- `obstacle_size_variance` - Mix of tiny/medium/huge obstacles
- `obstacle_split_on_bounce` - Asteroids-style: big obstacles split into smaller ones
- `obstacle_lifetime` - Despawn after X seconds (vs infinite)
- `obstacle_trails` - Obstacles leave damaging trails
- `obstacle_phase_mode` - Obstacles can pass through safe zone boundary

### Safe Zone Advanced (Already Implemented)
- `area_size` - Multiplier on safe zone radius
- `area_shape` - "circle", "square", "hex"
- `area_morph_type` - "shrink", "pulsing", "shape_shifting", "deformation", "none"
- `area_morph_speed` - Speed of morphing effects
- `area_movement_type` - "random", "cardinal", "none"
- `area_movement_speed` - How fast zone drifts
- `area_friction` - How smoothly zone changes direction
- `leaving_area_ends_game` - Instant death outside zone
- `holes_type` - "circle", "background", "none"
- `holes_count` - Number of hazard holes

### Safe Zone Advanced (New Ideas)
- `area_gravity` - Pulls player toward/away from center (positive = pull in, negative = push out)
- `area_rotation` - Safe zone slowly rotates (degrees/second)
- `area_wobble_intensity` - Boundary vibrates/wobbles
- `area_portal_mode` - Edges wrap around (Pac-Man style teleportation)
- `area_inversion` - Safe zone OUTSIDE, danger zone INSIDE
- `area_split_count` - Multiple separate safe zones (must navigate between them)
- `area_conveyor_belt` - Zone boundary slowly drags you clockwise/counter-clockwise

### Environmental Effects (New Ideas)
- `wind_strength` - Constant push in a direction (changes over time)
- `turbulence` - Random wind gusts
- `gravity_direction` - Constant pull (up/down/left/right/rotating)
- `magnetism` - Obstacles attracted to or repelled from player
- `vortex_pull` - Spinning pull toward center (like a black hole)
- `friction_zones` - Parts of arena have ice/mud physics
- `time_dilation_zones` - Slow-mo or fast-forward zones

### Visual/Difficulty Modifiers (New Ideas)
- `fog_of_war_radius` - Limited visibility around player (0 = blind, 999 = full vision)
- `camera_shake_intensity` - Screen shake on close calls
- `camera_zoom` - Zoomed in (claustrophobic) or out (tiny player, hard to see)
- `player_trail_length` - Visual trail behind player (could be hazardous if trail = hitbox)
- `flash_on_close_call` - Screen flash feedback
- `reverse_controls_duration` - Controls reverse for X seconds after getting hit
- `invisible_obstacles_chance` - % of obstacles that are invisible until close
- `mirror_mode` - Controls/visuals mirrored horizontally

### Score/Progression (New Ideas)
- `score_multiplier_mode` - "center" (bonus for middle), "edge" (bonus for risky play), "speed" (bonus for fast movement)
- `combo_system` - Chaining close calls builds multiplier
- `time_limit` - Survive X seconds to win (vs endless survival)
- `checkpoint_system` - Every 30 seconds = checkpoint (can fail and retry from checkpoint)

### Power-ups/Pickups (New Ideas)
- `powerup_spawn_enabled` - Enable pickups
- `powerup_spawn_rate` - How often they appear
- `powerup_types` - Available pickups: "speed_boost", "shield", "shrink", "slow_time", "clear_obstacles"

### Enemies (Already Implemented)
- `enemies` - Array of enemy types with multipliers
  - Types: "chaser", "shooter", "bouncer", "zigzag", "teleporter"

---

## Snake Game Variables

### Snake Physics (New Ideas)
- `movement_type` - "grid" (classic), "smooth" (continuous), "physics" (momentum-based)
- `turn_mode` - "instant" (classic), "gradual" (wide arcs), "drift" (ice physics)
- `snake_speed` - Base movement speed
- `speed_increase_per_food` - How much faster after eating (0 = constant speed)
- `max_speed_cap` - Upper limit on speed
- `segment_spacing` - Distance between body segments (tight vs loose)
- `tail_drag` - Tail follows with slight delay (creates snake wave motion)

### Growth & Body Mechanics (New Ideas)
- `growth_per_food` - Segments added per food (1 = classic, 3 = rapid growth)
- `shrink_over_time` - Slowly lose tail segments (must keep eating)
- `segment_detach_on_turn` - Sharp turns shed tail segments
- `phase_through_tail` - Can pass through own body (enables 3+ snake mode)
- `tail_becomes_food` - Detached segments turn into food
- `max_length_cap` - Snake can't grow beyond X segments

### Arena & Boundaries (New Ideas)
- `wall_mode` - "death" (classic), "wrap" (Pac-Man), "bounce" (ricochet), "phase" (slow pass-through)
- `arena_size` - Multiplier on play area
- `arena_shape` - "rectangle", "circle", "hexagon", "maze"
- `arena_rotation` - Arena slowly rotates
- `shrinking_arena` - Walls close in over time
- `moving_walls` - Walls shift positions periodically

### Food Mechanics (New Ideas)
- `food_count` - Number of simultaneous food items (1 = classic, 5 = buffet mode)
- `food_spawn_pattern` - "random", "cluster", "line", "spiral"
- `food_lifetime` - Food disappears after X seconds
- `food_movement` - "static", "drift", "flee_from_snake", "chase_snake"
- `food_size_variance` - Small food = 1 segment, big food = 5 segments
- `bad_food_chance` - % of food that shrinks you instead
- `golden_food_spawn_rate` - Rare food that gives bonus (speed boost, invincibility, etc.)

### Obstacles (New Ideas)
- `obstacle_count` - Static obstacles in arena
- `obstacle_type` - "walls", "moving_blocks", "rotating_blades", "teleport_pairs"
- `obstacle_spawn_over_time` - New obstacles appear as game progresses
- `destructible_obstacles` - Can eat through obstacles at cost of segments

### Multi-Snake Modes (New Ideas)
- `ai_snake_count` - Compete against AI snakes
- `ai_behavior` - "aggressive" (targets you), "defensive" (avoids you), "food_focused"
- `snake_collision_mode` - "both_die", "big_eats_small", "phase_through"

### Special Mechanics (New Ideas)
- `reverse_mode` - Occasionally snake reverses direction
- `segment_shuffle` - Body segments randomly rearrange
- `ghost_mode_duration` - Brief invincibility after close call
- `boost_ability_cooldown` - Temporary speed burst (cooldown-based)
- `split_mode` - Eating certain food splits you into 2 snakes (control both)
- `time_limit` - Reach X length in Y seconds

### Visual/Difficulty (New Ideas)
- `fog_of_war` - Limited visibility
- `invisible_tail` - Can't see own body (memory game)
- `camera_follows` - "head" (classic), "center_of_mass" (zoomed out), "fixed"
- `grid_visibility` - "visible", "faint", "invisible"

---

## Space Shooter Variables

### Player Movement (New Ideas)
- `movement_type` - "default" (WASD), "asteroids" (rotate + thrust), "jump" (dash), "rail" (fixed vertical, slide horizontally)
- `movement_speed` - Player movement speed
- `rotation_speed` - How fast ship rotates
- `accel_friction` / `decel_friction` - Momentum/drift
- `strafe_enabled` - Can move sideways without rotating
- `dodge_roll_cooldown` - Quick dodge ability
- `lives_count` - Multiple lives before game over
- `shield_hits` - Number of hits shield can take

### Weapon Systems (New Ideas)
- `fire_mode` - "manual", "auto", "charge_shot", "burst"
- `fire_rate` - Shots per second
- `bullet_speed` - How fast bullets travel
- `bullet_pattern` - "single", "double", "triple", "spread", "spiral", "wave"
- `bullet_homing` - Bullets track enemies
- `bullet_piercing` - Bullets pass through multiple enemies
- `bullet_ricochet` - Bullets bounce off edges
- `bullet_lifetime` - Despawn after X seconds
- `bullet_gravity` - Bullets arc downward
- `weapon_overheat` - Must cool down after sustained fire
- `ammo_system` - Limited ammo, reload required

### Enemy Behavior (New Ideas)
- `enemy_spawn_rate` - Multiplier on spawn frequency
- `enemy_speed_multiplier` - How fast enemies move
- `enemy_pattern` - "waves", "continuous", "boss_rush", "swarm"
- `enemy_types_enabled` - Array of enemy types (basic, fast, tank, shooter, kamikaze, shielded)
- `enemy_formation` - "scattered", "v_formation", "wall", "spiral"
- `enemy_bullet_enabled` - Enemies shoot back
- `enemy_bullet_speed` - How fast enemy projectiles move
- `miniboss_frequency` - Miniboss every X enemies
- `boss_health_multiplier` - Boss difficulty scaling

### Power-ups (New Ideas)
- `powerup_spawn_rate` - How often power-ups drop
- `powerup_types` - Available: "weapon_upgrade", "shield", "bomb", "speed", "multi_shot", "laser"
- `powerup_duration` - How long temporary upgrades last
- `powerup_stacking` - Can stack multiple weapon upgrades

### Arena/Environment (New Ideas)
- `scroll_speed` - How fast background/enemies scroll
- `arena_width` - Narrower = harder to dodge
- `wall_collision` - "death", "bounce", "wrap"
- `asteroid_field_density` - Environmental hazards
- `meteor_shower_frequency` - Random meteor waves
- `gravity_wells` - Areas that pull player/bullets
- `wormholes` - Teleport pairs

### Difficulty Scaling (New Ideas)
- `difficulty_curve` - "linear", "exponential", "wave" (hard/easy cycles)
- `time_limit` - Survive X seconds
- `kill_quota` - Destroy X enemies to win
- `no_damage_requirement` - Perfect run required

### Visual/Special Mechanics (New Ideas)
- `bullet_hell_mode` - Massive bullet count, tiny hitbox
- `screen_wrap` - Edges wrap (Asteroids-style)
- `twin_stick_mode` - Separate movement/aiming controls
- `reverse_gravity` - Ship at top, enemies at bottom
- `blackout_zones` - Areas with no visibility
- `time_dilation_on_kill` - Slow-mo after destroying enemy

---

## Memory Match Variables

### Grid & Layout (New Ideas)
- `grid_size` - "4x4", "6x6", "8x8"
- `card_count` - Total cards (always even for pairs)
- `match_requirement` - Cards needed to match (2 = pairs, 3 = triplets, 4 = quads)
- `card_layout` - "grid", "circle", "spiral", "scattered"
- `card_spacing` - Tight grid vs loose spread

### Card Behavior (New Ideas)
- `flip_speed` - Animation speed
- `reveal_duration` - How long cards stay visible before flipping back
- `reveal_count_limit` - Max cards flipped simultaneously (2 = classic, 3+ = hard mode)
- `auto_shuffle_interval` - Cards shuffle positions every X seconds
- `gravity_enabled` - Cards fall when matched (top cards drop down)
- `card_movement` - "static", "drift", "orbit", "swap_random"
- `card_rotation` - Cards slowly rotate (harder to see)

### Memory Mechanics (New Ideas)
- `fade_mode` - Matched cards fade out vs flip face-down and stay
- `ghost_cards` - Matched cards leave ghost outlines (hints)
- `progressive_reveal` - Start with all cards briefly visible, then flip
- `memory_decay` - Unmatched cards slowly fade from memory (visual hint fades)
- `false_matches` - Similar-looking cards that aren't matches
- `wildcard_count` - Cards that match anything

### Difficulty Modifiers (New Ideas)
- `time_limit` - Total time to complete
- `move_limit` - Maximum flip attempts allowed
- `flip_cost` - Each flip costs points (risk/reward)
- `mismatch_penalty` - Wrong matches flip all cards back face-down temporarily
- `hint_cooldown` - Timed ability to reveal 2 matching cards
- `lives_system` - X mismatches = game over

### Visual/Chaos Modifiers (New Ideas)
- `card_back_variance` - All different card backs (vs uniform)
- `spinning_cards` - Cards constantly spin
- `color_shift` - Card colors slowly change
- `mirror_mode` - Grid is mirrored/duplicated
- `fog_of_war` - Only see cards near cursor
- `distraction_elements` - Moving background elements

### Scoring & Progression (New Ideas)
- `combo_multiplier` - Consecutive matches build score multiplier
- `speed_bonus` - Faster matches = more points
- `perfect_bonus` - No mismatches = huge bonus
- `chain_requirement` - Must match specific sequences (all reds, then all blues, etc.)
- `survival_mode` - Keep matching before timer runs out (extends on match)

### Special Cards (New Ideas)
- `bomb_cards` - Matching reveals surrounding cards
- `shuffle_cards` - Matching shuffles all cards
- `freeze_cards` - Matching pauses timer
- `multiplier_cards` - Matching doubles points for next match

---

## Hidden Object Variables

### Scene & Layout (New Ideas)
- `scene_type` - "room", "forest", "city", "underwater", "space_station", "abstract"
- `scene_complexity` - Object count and density
- `scene_size` - Small focused area vs huge scrolling scene
- `zoom_level` - Zoomed in (easier to see details) vs zoomed out (hard to spot objects)
- `parallax_layers` - Multi-layer depth (objects in foreground/background)
- `scene_rotation_enabled` - Scene slowly rotates

### Object Mechanics (New Ideas)
- `object_count` - Number of objects to find
- `object_size_variance` - Mix of tiny/medium/large objects
- `object_transparency` - Some objects semi-transparent
- `object_camouflage` - Objects blend with background
- `object_animation` - Objects pulse, glow, or wiggle
- `object_movement` - "static", "drift", "orbit", "hide_and_seek" (objects move between hiding spots)
- `object_visibility_mode` - "always_visible", "appear_disappear", "only_visible_in_zone"

### Search Mechanics (New Ideas)
- `search_mode` - "list" (shown list of objects), "silhouette" (shown shapes), "description" (text clues), "memory" (shown once, then hidden)
- `false_objects_count` - Distractor objects (clicking them = penalty)
- `red_herring_ratio` - Similar-but-wrong objects
- `hint_system_cooldown` - Timed ability to highlight one object
- `hint_cost` - Using hints costs points
- `magnifying_glass_mode` - Can zoom in on areas

### Difficulty Modifiers (New Ideas)
- `time_limit` - Total time to find all objects
- `time_per_object` - Each object found adds time
- `click_limit` - Maximum clicks allowed
- `misclick_penalty` - Wrong clicks subtract time/points
- `lives_system` - X wrong clicks = game over
- `progressive_difficulty` - Found objects respawn elsewhere (infinite mode)

### Visual Effects (New Ideas)
- `fog_of_war` - Limited visibility, must explore with cursor
- `spotlight_mode` - Only small circle around cursor is lit
- `night_vision_mode` - Scene in grayscale/green
- `blur_effect` - Scene is blurred, clears when hovering
- `motion_blur` - Scene constantly moving
- `distortion_effect` - Fisheye or wave distortion
- `color_filter` - Sepia, inverted, monochrome

### Environmental Hazards (New Ideas)
- `moving_obstacles` - Things that block view (clouds, characters walking)
- `flickering_lights` - Scene periodically goes dark
- `weather_effects` - Rain/snow obscures objects
- `crowded_scene` - Many moving characters/elements
- `layered_hiding` - Objects behind semi-transparent layers

### Scoring & Modes (New Ideas)
- `speed_bonus` - Faster finds = more points
- `combo_multiplier` - Find objects quickly in sequence
- `perfect_bonus` - No misclicks = bonus
- `find_order_matters` - Must find in specific sequence
- `category_mode` - Find all red objects, then all round objects, etc.
- `survival_mode` - Objects disappear over time, must find before they vanish
- `collection_mode` - Find multiples of same object type (find all 10 coins)

### Special Mechanics (New Ideas)
- `x_ray_vision_cooldown` - Timed ability to see all objects briefly
- `object_morphing` - Objects slowly change appearance
- `interactive_scene` - Clicking areas reveals hidden compartments
- `puzzle_objects` - Some objects require solving mini-puzzle to access
- `decoy_objects` - Objects that look right but aren't (slight variations)

---

## Cross-Game Concepts

These ideas could potentially work across multiple games:

- **Mutation Mode** - Game gradually changes rules/physics over time
- **Reverse Mode** - Unusual goal inversions (Snake: stay small, Hidden Object: avoid finding things)
- **Glitch Mode** - Intentional visual/physics glitches for chaotic feel
- **Zen Mode** - No failure state, just score chasing
- **Nightmare Mode** - Everything that can go wrong does
- **Assist Mode** - Lots of helpers and forgiveness
- **Speedrun Mode** - Optimized for fast completion
- **Endurance Mode** - How long can you survive?
- **Perfect Run** - One mistake = restart
- **Random Mutation** - Random modifiers applied each run

---

## Implementation Priority

**High Priority** (Easy wins, big variety):
- Dodge: obstacle behavior, environmental effects
- Snake: food mechanics, wall modes, growth modifiers
- Space Shooter: weapon patterns, enemy types
- Memory Match: grid sizes, match requirements
- Hidden Object: search modes, visual effects

**Medium Priority** (More complex but very unique):
- All games: movement type variations
- Dodge: multi-zone, gravity wells
- Snake: multi-snake AI
- Space Shooter: boss rush modes
- Memory Match: special cards, shuffle mechanics
- Hidden Object: moving objects, interactive scenes

**Low Priority** (Cool but niche):
- Time manipulation effects
- Meta-modifiers (glitch mode, mutation mode)
- Extremely complex physics interactions
