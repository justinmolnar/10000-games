# Offline Tutorial: Raycaster Grid-Based Movement (Variant Support)

## Goal
Add grid-based movement as a **variant option** alongside the existing smooth movement. Different variants can use different movement styles - some play like Doom, others like Eye of the Beholder.

## Difficulty: Medium (2-3 hours)

## Files to Study First
- `src/games/raycaster.lua` - The game logic (227 lines)
- `src/games/views/raycaster_view.lua` - The 3D rendering
- `assets/data/schemas/raycaster_schema.json` - Where you'll add the option
- `assets/data/variants/raycaster_variants.json` - Where variants choose movement type

## Two Movement Systems (Both Supported)

**Smooth movement (existing, default):**
- WASD moves continuously
- Player position is floating point (e.g., 3.7, 5.2)
- Turning is smooth rotation
- Collision detection is continuous

**Grid-based movement (new option):**
- Each key press moves exactly one tile
- Player snaps to tile centers (e.g., 3.5, 5.5)
- Turning is 90-degree increments
- Cooldown prevents rapid-fire movement
- Optional: Smooth animation between tiles

**The variant JSON controls which mode is used:**
```json
{"name": "Doom Clone", "movement_mode": "smooth", ...}
{"name": "Dungeon Crawler", "movement_mode": "grid", ...}
```

---

## Step 1: Add Movement State Variables

Open `src/games/raycaster.lua` and find `setupGameState()` (around line 38).

### Add these new state variables:

```lua
function Raycaster:setupGameState()
    self.rng = love.math.newRandomGenerator(self.seed or os.time())
    self.game_over = false
    self.victory = false
    self.time_elapsed = 0
    self.mazes_completed = 0
    self.goal_reached = 0

    -- Player position (will snap to grid)
    self.player = {x = 1.5, y = 1.5, angle = 0}

    -- NEW: Grid movement state
    self.grid_mode = true  -- Toggle for testing
    self.move_cooldown = 0
    self.turn_cooldown = 0
    self.cooldown_time = 0.25  -- Seconds between moves
    self.turn_cooldown_time = 0.15  -- Seconds between turns

    -- NEW: Animation state (optional smooth transitions)
    self.is_moving = false
    self.move_start = {x = 0, y = 0}
    self.move_end = {x = 0, y = 0}
    self.move_progress = 0
    self.move_duration = 0.2  -- Seconds to animate one tile

    self.is_turning = false
    self.turn_start = 0
    self.turn_end = 0
    self.turn_progress = 0
    self.turn_duration = 0.15

    self.goal = {x = 1, y = 1}
    self.map = {}
    self.map_width = 0
    self.map_height = 0

    self.billboards = {}
    self.bob_timer = 0

    self.metrics = {time_elapsed = 0, mazes_completed = 0}
end
```

---

## Step 2: Create Grid Movement Handler

Replace the existing `handleInput` function (around line 152) with this new version:

```lua
function Raycaster:handleInput(dt)
    if not self.grid_mode then
        -- Keep original smooth movement for comparison
        return self:handleSmoothInput(dt)
    end

    -- Update cooldowns
    self.move_cooldown = math.max(0, self.move_cooldown - dt)
    self.turn_cooldown = math.max(0, self.turn_cooldown - dt)

    -- Update movement animation
    if self.is_moving then
        self.move_progress = self.move_progress + dt / self.move_duration
        if self.move_progress >= 1 then
            -- Snap to destination
            self.player.x = self.move_end.x
            self.player.y = self.move_end.y
            self.is_moving = false
            self.move_progress = 0
        else
            -- Interpolate position
            self.player.x = self:lerp(self.move_start.x, self.move_end.x, self.move_progress)
            self.player.y = self:lerp(self.move_start.y, self.move_end.y, self.move_progress)
        end
        return  -- Don't accept new input while moving
    end

    -- Update turn animation
    if self.is_turning then
        self.turn_progress = self.turn_progress + dt / self.turn_duration
        if self.turn_progress >= 1 then
            self.player.angle = self.turn_end
            self.is_turning = false
            self.turn_progress = 0
        else
            -- Interpolate angle (handle wraparound)
            self.player.angle = self:lerpAngle(self.turn_start, self.turn_end, self.turn_progress)
        end
        return  -- Don't accept new input while turning
    end

    -- Handle turning (90 degree increments)
    if self.turn_cooldown <= 0 then
        if self:isKeyDown('left', 'a') then
            self:startTurn(-math.pi / 2)
        elseif self:isKeyDown('right', 'd') then
            self:startTurn(math.pi / 2)
        end
    end

    -- Handle movement (one tile at a time)
    if self.move_cooldown <= 0 then
        if self:isKeyDown('up', 'w') then
            self:tryGridMove(1)  -- Forward
        elseif self:isKeyDown('down', 's') then
            self:tryGridMove(-1)  -- Backward
        elseif self:isKeyDown('q') then
            self:tryGridStrafe(-1)  -- Strafe left
        elseif self:isKeyDown('e') then
            self:tryGridStrafe(1)  -- Strafe right
        end
    end
end

-- Attempt to move one tile in facing direction
function Raycaster:tryGridMove(direction)
    local dx = math.cos(self.player.angle) * direction
    local dy = math.sin(self.player.angle) * direction

    -- Calculate target tile center
    local current_tile_x = math.floor(self.player.x)
    local current_tile_y = math.floor(self.player.y)

    -- Determine which tile we're moving to
    local target_tile_x = current_tile_x + math.floor(dx + 0.5)
    local target_tile_y = current_tile_y + math.floor(dy + 0.5)

    -- Check if target tile is walkable
    if self:isTileWalkable(target_tile_x, target_tile_y) then
        self:startMove(target_tile_x + 0.5, target_tile_y + 0.5)
    else
        -- Optional: Play bump sound or flash
        print("Blocked!")
    end
end

-- Attempt to strafe one tile
function Raycaster:tryGridStrafe(direction)
    local strafe_angle = self.player.angle + (math.pi / 2) * direction
    local dx = math.cos(strafe_angle)
    local dy = math.sin(strafe_angle)

    local current_tile_x = math.floor(self.player.x)
    local current_tile_y = math.floor(self.player.y)

    local target_tile_x = current_tile_x + math.floor(dx + 0.5)
    local target_tile_y = current_tile_y + math.floor(dy + 0.5)

    if self:isTileWalkable(target_tile_x, target_tile_y) then
        self:startMove(target_tile_x + 0.5, target_tile_y + 0.5)
    end
end

-- Check if a tile is walkable (not a wall)
function Raycaster:isTileWalkable(tile_x, tile_y)
    -- Bounds check
    if tile_x < 1 or tile_x > self.map_width or
       tile_y < 1 or tile_y > self.map_height then
        return false
    end

    -- Check map (0 = floor, 1 = wall)
    local row = self.map[tile_y]
    if not row then return false end

    return row[tile_x] == 0
end

-- Start animated movement to a position
function Raycaster:startMove(target_x, target_y)
    self.is_moving = true
    self.move_start.x = self.player.x
    self.move_start.y = self.player.y
    self.move_end.x = target_x
    self.move_end.y = target_y
    self.move_progress = 0
    self.move_cooldown = self.cooldown_time
end

-- Start animated turn
function Raycaster:startTurn(delta_angle)
    self.is_turning = true
    self.turn_start = self.player.angle
    self.turn_end = self.player.angle + delta_angle
    self.turn_progress = 0
    self.turn_cooldown = self.turn_cooldown_time
end

-- Linear interpolation
function Raycaster:lerp(a, b, t)
    return a + (b - a) * t
end

-- Angle interpolation (handles wraparound)
function Raycaster:lerpAngle(a, b, t)
    -- Simple lerp works for 90-degree turns
    return a + (b - a) * t
end

-- Keep original smooth movement for comparison/fallback
function Raycaster:handleSmoothInput(dt)
    local p = self.params

    -- Rotation
    local left = self:isKeyDown('left', 'a')
    local right = self:isKeyDown('right', 'd')
    local turn_dir = (right and 1 or 0) - (left and 1 or 0)
    self.player.angle = self.player.angle + turn_dir * p.turn_speed * dt

    -- Forward/back movement
    local move_x, move_y = 0, 0
    if self:isKeyDown('up', 'w') then
        move_x = math.cos(self.player.angle) * p.move_speed * dt
        move_y = math.sin(self.player.angle) * p.move_speed * dt
    end
    if self:isKeyDown('down', 's') then
        move_x = move_x - math.cos(self.player.angle) * p.move_speed * dt
        move_y = move_y - math.sin(self.player.angle) * p.move_speed * dt
    end

    -- Strafe
    if self:isKeyDown('q') then
        local strafe_angle = self.player.angle - math.pi / 2
        move_x = move_x + math.cos(strafe_angle) * p.move_speed * dt
        move_y = move_y + math.sin(strafe_angle) * p.move_speed * dt
    end
    if self:isKeyDown('e') then
        local strafe_angle = self.player.angle + math.pi / 2
        move_x = move_x + math.cos(strafe_angle) * p.move_speed * dt
        move_y = move_y + math.sin(strafe_angle) * p.move_speed * dt
    end

    -- Apply movement with tile collision
    self.player.x, self.player.y = PhysicsUtils.moveWithTileCollision(
        self.player.x, self.player.y, move_x, move_y,
        self.map, self.map_width, self.map_height
    )
end
```

---

## Step 3: Snap Starting Position to Grid

In `generateMaze()`, ensure player starts at tile center:

```lua
function Raycaster:generateMaze()
    local result = self.maze_generator:generate(self.rng)

    self.map = result.map
    self.map_width = result.width
    self.map_height = result.height

    -- Snap to tile center
    self.player.x = math.floor(result.start.x) + 0.5
    self.player.y = math.floor(result.start.y) + 0.5

    -- Snap angle to 90-degree increment
    local start_angle = result.start.angle or 0
    self.player.angle = math.floor(start_angle / (math.pi/2) + 0.5) * (math.pi/2)

    -- ... rest of existing code ...
end
```

---

## Step 4: Add Schema Parameters (The Important Part!)

This is how variants control which movement mode is used. Add to `assets/data/schemas/raycaster_schema.json`:

```json
{
  "movement_mode": {
    "type": "string",
    "default": "smooth",
    "enum": ["smooth", "grid"],
    "description": "Movement style: smooth FPS or grid-based dungeon crawler"
  },
  "grid_move_time": {
    "type": "number",
    "default": 0.2,
    "min": 0.05,
    "max": 0.5,
    "description": "Time to animate one tile movement (grid mode only)"
  },
  "grid_turn_time": {
    "type": "number",
    "default": 0.15,
    "min": 0.05,
    "max": 0.3,
    "description": "Time to animate 90-degree turn (grid mode only)"
  },
  "grid_cooldown": {
    "type": "number",
    "default": 0.25,
    "min": 0.1,
    "max": 1.0,
    "description": "Minimum time between moves (grid mode only)"
  }
}
```

Then in `setupGameState()`, read from params instead of hardcoding:

```lua
self.grid_mode = self.params.movement_mode == "grid"
self.move_duration = self.params.grid_move_time or 0.2
self.turn_duration = self.params.grid_turn_time or 0.15
self.cooldown_time = self.params.grid_cooldown or 0.25
```

---

## Step 5: Create Variants That Use Each Mode

Add to `assets/data/variants/raycaster_variants.json`:

```json
{
  "clone_index": 11,
  "name": "Dungeon Crawler",
  "flavor_text": "Old school grid-based exploration",
  "movement_mode": "grid",
  "grid_move_time": 0.15,
  "grid_turn_time": 0.1,
  "maze_width": 15,
  "maze_height": 15
},
{
  "clone_index": 12,
  "name": "Slow Crawler",
  "flavor_text": "Deliberate, methodical movement",
  "movement_mode": "grid",
  "grid_move_time": 0.4,
  "grid_turn_time": 0.3,
  "grid_cooldown": 0.5,
  "maze_width": 10,
  "maze_height": 10
},
{
  "clone_index": 13,
  "name": "Speed Demon",
  "flavor_text": "Fast and smooth",
  "movement_mode": "smooth",
  "move_speed": 8,
  "turn_speed": 5,
  "maze_width": 25,
  "maze_height": 25
}
```

---

## Step 6: (Optional) Add Debug Toggle for Testing

While developing, you might want a key to switch modes for quick testing. This is temporary:

```lua
function Raycaster:keypressed(key)
    -- ... existing code ...

    -- DEBUG: Toggle movement mode (remove before release)
    if key == 'g' then
        self.grid_mode = not self.grid_mode
        print("Grid mode: " .. (self.grid_mode and "ON" or "OFF"))
    end
end
```

---

## Step 7: Test It

1. Run the game: `love .`
2. Launch the "Dungeon Crawler" variant you created
3. Try WASD - should move one tile per press
4. Launch a smooth movement variant - should move continuously
5. Verify you can't walk through walls in either mode

### Expected grid mode behavior:
- W: Move forward one tile, smooth animation
- S: Move backward one tile
- A/D: Turn 90 degrees
- Q/E: Strafe one tile sideways

### Expected smooth mode behavior:
- Same as before (continuous movement)

---

## Stretch Goals

1. **Head bob:** Add slight vertical bob during movement animation
2. **Step sounds:** Play footstep on each tile transition
3. **Smooth angle normalization:** Keep angle in 0-2π range
4. **Keyboard repeat:** Allow holding key to queue next move
5. **Minimap update:** Show player as directional arrow snapped to grid

## Common Issues

| Problem | Solution |
|---------|----------|
| Player stuck in wall | Starting position not snapped to valid tile |
| Moving diagonally | Angle not snapped to 90° increments |
| Can move through walls | `isTileWalkable` has wrong coordinate order (check y,x vs x,y) |
| Animation jerky | `lerp` not being called in update loop |
| Can't turn and move | Remove the `return` statements to allow simultaneous input |

## Debugging Tips

Add this to `draw()` or create a debug overlay:
```lua
-- Show player tile position
local tile_x = math.floor(self.player.x)
local tile_y = math.floor(self.player.y)
local angle_deg = math.deg(self.player.angle) % 360
print(string.format("Tile: %d,%d  Angle: %.0f°", tile_x, tile_y, angle_deg))
```

## Key Patterns Learned

- **Variant-driven features:** Schema defines options, variants choose values
- **Multiple implementations coexist:** Both smooth and grid, selected by param
- **State machine for animation:** `is_moving` flag controls input acceptance
- **Lerp for smooth transitions:** Interpolate between start and end values
- **Grid snapping:** Always use `tile + 0.5` for tile centers
