# Snake Game - Variant Modifiers

All properties can be added to any Snake variant in `assets/data/variants/snake_variants.json`.

## Per-Variant Modifiers (Movement)

**movement_type** [grid]: Movement control scheme. Options: "grid" (classic discrete), "smooth" (continuous), "physics" (momentum-based). Hidden parameter (requires dropdown).

**snake_speed** [8]: Base movement speed in moves per second. Higher = faster snake. Range: 1-20

**speed_increase_per_food** [0]: Speed increase per food eaten. 0 = constant speed, 0.5 = moderate acceleration, 1.0+ = rapid acceleration. Range: 0-5

**max_speed_cap** [20]: Maximum speed limit. Prevents runaway speed from speed_increase_per_food. 0 = no limit. Range: 0-50

## Per-Variant Modifiers (Growth & Body)

**growth_per_food** [1]: Number of segments added per food eaten. 1 = classic, 2-3 = rapid growth. Range: 0-10

**shrink_over_time** [0]: Segments lost per second. 0 = no shrinking, 0.5 = slow decay, 1.0+ = must keep eating. Range: 0-5

**phase_through_tail** [false]: If true, snake can pass through its own body. Enables multi-snake variants and removes self-collision.

**max_length_cap** [9999]: Maximum snake length. Snake stops growing after reaching this length. Range: 1-9999

**girth** [1]: Initial snake thickness. 1 = normal (1 cell wide), 2+ = thicker snake, wider hitbox. Range: 1-10

**girth_growth** [0]: Segments needed to add 1 to girth. 0 = no girth growth, 3 = every 3 segments increases thickness by 1. Range: 0-50

## Per-Variant Modifiers (Arena)

**wall_mode** [wrap]: Wall collision behavior. Options:
  - "death": Hit wall = game over (classic hardcore)
  - "wrap": Pac-Man style teleportation to opposite side
  - "bounce": Ricochet off walls
  - "phase": Slow pass-through walls (ghosting)

Hidden parameter (requires dropdown).

**arena_size** [1.0]: Multiplier on arena dimensions. 0.5 = tiny arena, 1.0 = normal, 2.0 = huge arena. Range: 0.3-3.0

**arena_shape** [rectangle]: Shape of play area. Options: "rectangle", "circle", "hexagon". Hidden parameter (requires dropdown).

**shrinking_arena** [false]: If true, walls gradually close in over time (battle royale style).

**moving_walls** [false]: If true, walls shift positions periodically.

## Per-Variant Modifiers (Food)

**food_count** [1]: Number of simultaneous food items. 1 = classic, 3-5 = buffet mode. Range: 1-20

**food_spawn_pattern** [random]: Food spawn behavior. Options: "random", "cluster" (groups), "line", "spiral". Hidden parameter (requires dropdown).

**food_lifetime** [0]: Food despawns after X seconds. 0 = never despawns, 5-10 = chase it fast. Range: 0-60

**food_movement** [static]: Food movement type. Options:
  - "static": Classic stationary food
  - "drift": Slow random wandering
  - "flee_from_snake": Runs away from player
  - "chase_snake": Moves toward player

Hidden parameter (requires dropdown).

**food_size_variance** [0]: Random size variation. 0 = uniform, 0.5 = some variety, 1.0 = extreme size differences (1-5 segments). Range: 0-1.0

**bad_food_chance** [0]: Probability of bad food spawning (shrinks snake). 0.0 = none, 0.3 = 30% chance, 1.0 = always bad. Range: 0-1.0

**golden_food_spawn_rate** [0]: Chance of golden food spawning (bonus effects). 0.0 = none, 0.1 = 10% chance, 0.5 = 50% chance. Range: 0-1.0

## Per-Variant Modifiers (Obstacles)

**obstacle_count** [5]: Number of static obstacles in arena at start. 0 = none, 15+ = maze-like. Range: 0-50

**obstacle_type** [walls]: Type of obstacles. Options: "walls" (static blocks), "moving_blocks", "rotating_blades", "teleport_pairs". Hidden parameter (requires dropdown).

**obstacle_spawn_over_time** [0]: New obstacles spawned per second. 0 = static obstacles only, 1.0+ = arena fills over time. Range: 0-5

## Per-Variant Modifiers (AI & Multiplayer)

**ai_snake_count** [0]: Number of AI-controlled snakes. 0 = solo, 1-3 = competition. Range: 0-10

**ai_behavior** [food_focused]: AI snake behavior. Options:
  - "aggressive": Actively hunts player
  - "defensive": Avoids player
  - "food_focused": Prioritizes eating (classic AI)

Hidden parameter (requires dropdown).

**ai_speed** [snake_speed]: Movement speed of AI snakes. Defaults to same as player snake_speed. Can be slower or faster for difficulty tuning. Range: 1-20

**snake_collision_mode** [both_die]: Collision behavior between snakes. Options:
  - "both_die": Both snakes die on collision
  - "big_eats_small": Longer snake absorbs shorter
  - "phase_through": Snakes pass through each other

Hidden parameter (requires dropdown).

**snake_count** [1]: Number of snakes player controls simultaneously (same controls for all). 1 = classic, 2+ = multi-snake challenge. Range: 1-5

## Per-Variant Modifiers (Victory Conditions)

**victory_condition** [length]: Win condition type. Options:
  - "length": Reach target length (classic)
  - "time": Survive X seconds

Hidden parameter (requires dropdown).

**victory_limit** [20]: Victory target value. For "length": target snake length. For "time": seconds to survive. Range: 1-200

## Per-Variant Modifiers (Visual Effects)

**fog_of_war** [none]: Visibility limitation. Options:
  - "none": Full visibility
  - "player": Limited visibility around snake head
  - "center": Fog centered on arena center

Hidden parameter (requires dropdown).

**invisible_tail** [false]: If true, cannot see own snake body (memory challenge).

**camera_mode** [follow_head]: Camera behavior. Options:
  - "follow_head": Camera follows snake head
  - "center_of_mass": Camera centers on snake's midpoint
  - "fixed": Static camera

Hidden parameter (requires dropdown).

**camera_zoom** [1.0]: Camera zoom level. 0.8 = zoomed out, 1.0 = normal, 1.5 = zoomed in (claustrophobic). Range: 0.5-2.0

## Per-Variant Modifiers (Audio/Visual Metadata)

**sprite_set** [classic/snake]: Which sprite folder to load from `assets/sprites/games/snake/`. Hidden parameter (visual only).

**sprite_style** [uniform]: Sprite mode. Options:
  - "uniform": Uses same sprite (segment.png) for all segments (simplest)
  - "segmented": Uses seg_head.png, seg_body.png, seg_tail.png for visual variety

Hidden parameter (visual only, requires dropdown).

**palette** [green]: Color palette ID for palette swapping. Examples: "green", "red", "blue", "purple". Hidden parameter (visual only).

**music_track** [null]: Path to music file. Example: "snake_theme_1", "snake_theme_2". Hidden parameter (audio only).

**sfx_pack** [retro_beeps]: Which SFX pack to use. Options: "retro_beeps", "modern_ui", "8bit_arcade". Hidden parameter (audio only).

**background** [grid_green]: Background visual theme. Examples: "grid_green", "grid_blue", "grid_red". Hidden parameter (visual only).

## Per-Variant Modifiers (Difficulty & Flavor)

**difficulty_modifier** [1.0]: Overall difficulty multiplier. Scales spawn rate, AI aggression, etc. Higher = harder. Range: 0.5-3.0

**name** [required]: Display name for this variant. Example: "Snake Classic". Hidden parameter (metadata).

**flavor_text** [""]: Description shown in launcher. Example: "Classic snake! Eat, grow, don't crash". Hidden parameter (metadata).

**clone_index** [required]: Unique index for this variant (0, 1, 2, ...). Hidden parameter (internal ID).

## Example Variants

### Classic Snake
```json
{
  "clone_index": 0,
  "name": "Snake Classic",
  "movement_type": "grid",
  "snake_speed": 8,
  "growth_per_food": 1,
  "wall_mode": "wrap",
  "food_count": 1,
  "victory_condition": "length",
  "victory_limit": 20
}
```
Feel: Traditional Snake gameplay, wrapping walls, grow to 20 segments

### Speed Demon
```json
{
  "clone_index": 1,
  "name": "Snake Speed Demon",
  "snake_speed": 12,
  "speed_increase_per_food": 0.5,
  "max_speed_cap": 25,
  "wall_mode": "death",
  "obstacle_count": 5,
  "victory_limit": 30
}
```
Feel: Faster with each food, obstacles add danger, hard walls

### Shrinking Terror
```json
{
  "clone_index": 2,
  "name": "Snake Shrinking Terror",
  "growth_per_food": 3,
  "shrink_over_time": 0.5,
  "victory_limit": 15
}
```
Feel: Grow 3 segments but slowly shrink - must keep eating

### Phase Ghost
```json
{
  "clone_index": 3,
  "name": "Snake Phase Ghost",
  "phase_through_tail": true,
  "wall_mode": "phase",
  "arena_size": 0.8,
  "obstacle_count": 8
}
```
Feel: Pass through your tail AND walls! Only obstacles hurt

### Buffet Mode
```json
{
  "clone_index": 4,
  "name": "Snake Buffet Mode",
  "food_count": 5,
  "food_spawn_pattern": "cluster",
  "arena_size": 1.3
}
```
Feel: 5 foods at once in a larger arena - feast away

### THICCC Snake
```json
{
  "clone_index": 5,
  "name": "Snake THICCC",
  "girth": 2,
  "girth_growth": 3,
  "arena_size": 1.5,
  "snake_speed": 6
}
```
Feel: Start thick (2 cells), get thicker every 3 segments - slow but imposing

### Time Trial
```json
{
  "clone_index": 6,
  "name": "Snake Time Trial",
  "victory_condition": "time",
  "victory_limit": 60,
  "snake_speed": 10
}
```
Feel: Just survive 60 seconds! Fast-paced survival

### AI Competition
```json
{
  "clone_index": 7,
  "name": "Snake AI Competition",
  "ai_snake_count": 2,
  "ai_behavior": "aggressive",
  "snake_collision_mode": "big_eats_small",
  "food_count": 3,
  "arena_size": 1.5
}
```
Feel: 2 AI snakes compete with you, bigger snake eats smaller

### Fog Runner
```json
{
  "clone_index": 8,
  "name": "Snake Fog of War",
  "fog_of_war": "player",
  "camera_zoom": 1.2,
  "obstacle_count": 5,
  "victory_limit": 20
}
```
Feel: Limited visibility, navigate by memory

### Roulette
```json
{
  "clone_index": 9,
  "name": "Snake Roulette",
  "food_count": 3,
  "food_size_variance": 1,
  "bad_food_chance": 0.3,
  "golden_food_spawn_rate": 0.1,
  "growth_per_food": 2
}
```
Feel: Varied food sizes, 30% bad food, 10% golden - gamble!

### Chaos Mode
```json
{
  "clone_index": 10,
  "name": "Snake Chaos Mode",
  "snake_speed": 11,
  "speed_increase_per_food": 0.3,
  "growth_per_food": 2,
  "shrink_over_time": 0.2,
  "girth_growth": 2,
  "wall_mode": "bounce",
  "arena_shape": "hexagon",
  "shrinking_arena": true,
  "food_count": 4,
  "food_lifetime": 5,
  "food_movement": "drift",
  "bad_food_chance": 0.2,
  "golden_food_spawn_rate": 0.15,
  "obstacle_count": 10,
  "obstacle_spawn_over_time": 0.5,
  "ai_snake_count": 1,
  "fog_of_war": "player"
}
```
Feel: EVERYTHING AT ONCE! For experts only - pure mayhem

## CheatEngine Integration

When you open CheatEngine and select a Snake variant, the following parameters will be **editable** (numeric/boolean sliders):

**Editable Parameters:**
- snake_speed, speed_increase_per_food, max_speed_cap
- growth_per_food, shrink_over_time, max_length_cap, girth, girth_growth
- phase_through_tail (toggle)
- arena_size
- shrinking_arena, moving_walls (toggles)
- food_count, food_lifetime, food_size_variance, bad_food_chance, golden_food_spawn_rate
- obstacle_count, obstacle_spawn_over_time
- ai_snake_count, snake_count
- victory_limit
- invisible_tail (toggle)
- camera_zoom
- difficulty_modifier

**Hidden Parameters** (not editable):
- Metadata: clone_index, name, flavor_text, sprite_set, palette, music_track, sfx_pack, background
- String enums: movement_type, wall_mode, arena_shape, food_spawn_pattern, food_movement, obstacle_type, ai_behavior, snake_collision_mode, victory_condition, camera_mode, fog_of_war

All numeric and boolean parameters are automatically adjustable in CheatEngine!
