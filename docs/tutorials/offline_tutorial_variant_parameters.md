# Offline Tutorial: Adding Variant Parameters

## Goal
Learn the variant/schema system by adding a new parameter to an existing game. This is the foundation for creating diverse game clones.

## Difficulty: Easy (1 hour)

## Files to Study First
- `assets/data/schemas/snake_schema.json` - Example schema with many parameters
- `assets/data/variants/snake_variants.json` - Example variants using those parameters
- `src/utils/game_components/schema_loader.lua` - How parameters are loaded
- `src/games/raycaster.lua` - Where we'll add the parameter

## How the System Works

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│ Schema JSON     │     │ Variant JSON     │     │ Game Code   │
│ (defines types, │ ──► │ (specific values │ ──► │ (uses       │
│  defaults, etc) │     │  for this clone) │     │  self.params)│
└─────────────────┘     └──────────────────┘     └─────────────┘
```

**Priority:** Variant value > Runtime config > Schema default

So if you define a default in the schema, variants can override it, and runtime config (cheats) can override that.

---

## Example: Add "Fog Distance" to Raycaster

We'll add a parameter that controls how far you can see before walls fade to black.

### Step 1: Define in Schema

Open `assets/data/schemas/raycaster_schema.json` and add:

```json
{
  "fog_distance": {
    "type": "number",
    "default": 15,
    "min": 3,
    "max": 50,
    "description": "Distance in tiles before walls fade to darkness"
  },
  "fog_color": {
    "type": "array",
    "default": [0, 0, 0],
    "description": "RGB color of the fog (usually black)"
  },
  "fog_enabled": {
    "type": "boolean",
    "default": false,
    "description": "Whether distance fog is enabled"
  }
}
```

**Schema field types:**
- `number` - Float or integer
- `integer` - Whole numbers only
- `boolean` - true/false
- `string` - Text
- `array` - List of values (like RGB colors)
- `enum` - One of predefined values

**Optional fields:**
- `min`, `max` - For numbers
- `enum` - List of allowed values for strings
- `group` - Organize related params together

### Step 2: Create Variants Using the Parameter

Open `assets/data/variants/raycaster_variants.json` and add new variants:

```json
{
  "clone_index": 20,
  "name": "Foggy Depths",
  "flavor_text": "Limited visibility in the darkness",
  "fog_enabled": true,
  "fog_distance": 5,
  "fog_color": [0.1, 0.1, 0.15],
  "maze_width": 20,
  "maze_height": 20
},
{
  "clone_index": 21,
  "name": "Clear Day",
  "flavor_text": "Perfect visibility",
  "fog_enabled": false,
  "maze_width": 30,
  "maze_height": 30
},
{
  "clone_index": 22,
  "name": "Blood Mist",
  "flavor_text": "A red fog obscures the passages",
  "fog_enabled": true,
  "fog_distance": 8,
  "fog_color": [0.3, 0, 0],
  "maze_width": 15,
  "maze_height": 15
}
```

### Step 3: Use Parameters in Game Code

Open `src/games/raycaster.lua`. The parameters are already loaded in init:

```lua
self.params = SchemaLoader.load(self.variant, "raycaster_schema", runtimeCfg)
```

You can access them as:
```lua
local p = self.params
if p.fog_enabled then
    local fog_dist = p.fog_distance
    local fog_color = p.fog_color
    -- Use these values...
end
```

### Step 4: Implement the Feature

For fog, you'd modify the view. Open `src/games/views/raycaster_view.lua`.

In the wall rendering section, fade walls based on distance:

```lua
-- Calculate fog factor (1 = full visibility, 0 = fully fogged)
local fog_factor = 1
if self.game.params.fog_enabled then
    local fog_dist = self.game.params.fog_distance
    local fog_color = self.game.params.fog_color or {0, 0, 0}

    if distance > fog_dist then
        fog_factor = 0
    elseif distance > fog_dist * 0.5 then
        -- Gradual fade in the outer half
        fog_factor = 1 - ((distance - fog_dist * 0.5) / (fog_dist * 0.5))
    end

    -- Blend wall color with fog color
    local r = wall_color[1] * fog_factor + fog_color[1] * (1 - fog_factor)
    local g = wall_color[2] * fog_factor + fog_color[2] * (1 - fog_factor)
    local b = wall_color[3] * fog_factor + fog_color[3] * (1 - fog_factor)

    love.graphics.setColor(r, g, b)
end
```

---

## Schema Types Reference

### Number
```json
"speed": {
  "type": "number",
  "default": 100,
  "min": 10,
  "max": 500
}
```

### Integer
```json
"lives": {
  "type": "integer",
  "default": 3,
  "min": 1,
  "max": 99
}
```

### Boolean
```json
"walls_wrap": {
  "type": "boolean",
  "default": false
}
```

### String
```json
"difficulty": {
  "type": "string",
  "default": "normal",
  "enum": ["easy", "normal", "hard", "nightmare"]
}
```

### Array (for colors, lists)
```json
"player_color": {
  "type": "array",
  "default": [0, 1, 0],
  "description": "RGB color 0-1 range"
}
```

### Grouped Parameters
```json
"movement": {
  "type": "group",
  "properties": {
    "speed": {"type": "number", "default": 100},
    "acceleration": {"type": "number", "default": 50}
  }
}
```
Access as: `p.movement.speed`

---

## Practical Example: Add Difficulty Modifier

### Schema (`raycaster_schema.json`):
```json
"difficulty_modifier": {
  "type": "number",
  "default": 1.0,
  "min": 0.5,
  "max": 3.0,
  "description": "Multiplier affecting maze complexity"
}
```

### Variant (`raycaster_variants.json`):
```json
{
  "clone_index": 25,
  "name": "Nightmare Maze",
  "difficulty_modifier": 2.5,
  "maze_width": 30,
  "maze_height": 30
}
```

### Game code (`raycaster.lua`):
```lua
function Raycaster:applyModifiers()
    local p = self.params

    -- Apply difficulty modifier
    if p.difficulty_modifier and p.difficulty_modifier ~= 1.0 then
        -- Make maze larger
        p.maze_width = math.floor(p.maze_width * p.difficulty_modifier)
        p.maze_height = math.floor(p.maze_height * p.difficulty_modifier)
        -- Could also affect: time limit, enemy count, etc.
    end

    -- ... existing cheat modifiers ...
end
```

---

## Testing Your Changes

1. **Check schema syntax:** JSON must be valid (no trailing commas!)
2. **Run the game:** `love .`
3. **Find your variant:** Open launcher, search for the new variant name
4. **Verify parameters:** Add debug print in game init:
   ```lua
   print("fog_enabled:", self.params.fog_enabled)
   print("fog_distance:", self.params.fog_distance)
   ```

---

## Common Schema Patterns

### Token/scoring parameters
```json
"base_score": {"type": "integer", "default": 100},
"score_multiplier": {"type": "number", "default": 1.0},
"time_bonus_enabled": {"type": "boolean", "default": true}
```

### Difficulty scaling
```json
"enemy_count": {"type": "integer", "default": 5, "min": 1, "max": 50},
"enemy_speed": {"type": "number", "default": 100},
"spawn_rate": {"type": "number", "default": 2.0, "description": "Enemies per second"}
```

### Visual customization
```json
"background_color": {"type": "array", "default": [0.1, 0.1, 0.2]},
"wall_texture": {"type": "string", "default": "brick", "enum": ["brick", "stone", "metal"]},
"particle_effects": {"type": "boolean", "default": true}
```

### Game modes
```json
"game_mode": {
  "type": "string",
  "default": "standard",
  "enum": ["standard", "timed", "endless", "survival"]
},
"time_limit": {"type": "number", "default": 60, "description": "Only used in timed mode"}
```

---

## Debugging

### Parameter not loading?
```lua
-- In game init, dump all params:
for k, v in pairs(self.params) do
    print(k, "=", type(v) == "table" and "table" or v)
end
```

### Wrong default value?
Check the priority: Variant > Config > Schema default

### JSON syntax error?
- No trailing commas: `{"a": 1, "b": 2}` not `{"a": 1, "b": 2,}`
- Strings need quotes: `"default": "text"` not `"default": text`
- Booleans are lowercase: `true` not `True`

---

## Stretch Goals

1. **Add 5 new parameters** to raycaster schema
2. **Create 3 variants** that use different combinations
3. **Add a "game_mode" enum** that changes victory conditions
4. **Group related parameters** using the group type

## Key Patterns Learned

- **Data-driven design:** Game behavior defined in JSON, not code
- **Schema validation:** Types and ranges catch errors early
- **Default cascading:** Schema → Config → Variant
- **Variant diversity:** Same code, wildly different gameplay
