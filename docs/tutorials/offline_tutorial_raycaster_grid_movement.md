# Tutorial: Raycaster Grid-Based Movement

## Goal
Add grid-based movement as a variant option. Some variants play like Doom (smooth), others like Eye of the Beholder (grid/tile-based).

## Concept

**Smooth movement (existing):**
- WASD moves continuously
- Player position is floating point (3.7, 5.2)
- Free rotation

**Grid-based movement (new):**
- Each key press = one tile
- Player snaps to tile centers (3.5, 5.5)
- 90-degree turn increments
- Smooth animation between tiles

---

## Step 1: Add Schema Parameters

Add to `assets/data/schemas/raycaster_schema.json` in the `parameters` section:

```json
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
    "description": "Animation time for one tile movement (grid mode)"
},
"grid_turn_time": {
    "type": "number",
    "default": 0.15,
    "min": 0.05,
    "max": 0.3,
    "description": "Animation time for 90-degree turn (grid mode)"
}
```

---

## Step 2: Add Grid State in generateMaze()

In `raycaster.lua`, add grid movement state after existing setup in `generateMaze()`:

```lua
function Raycaster:generateMaze()
    -- ... existing maze generation code ...

    -- Grid movement state
    self.grid_move = {
        active = false,
        start_x = 0, start_y = 0,
        end_x = 0, end_y = 0,
        progress = 0
    }
    self.grid_turn = {
        active = false,
        start_angle = 0,
        end_angle = 0,
        progress = 0
    }

    -- Snap to grid if in grid mode
    if self.params.movement_mode == "grid" then
        self.player.x = math.floor(self.player.x) + 0.5
        self.player.y = math.floor(self.player.y) + 0.5
        self.player.angle = math.floor(self.player.angle / (math.pi/2) + 0.5) * (math.pi/2)
    end
end
```

---

## Step 3: Replace handleInput()

Replace the `handleInput` function to support both modes:

```lua
function Raycaster:handleInput(dt)
    if self.params.movement_mode == "grid" then
        self:handleGridInput(dt)
    else
        self:handleSmoothInput(dt)
    end
end

function Raycaster:handleSmoothInput(dt)
    -- Existing smooth movement code (already in raycaster.lua)
    local left, right = self:isKeyDown('left', 'a'), self:isKeyDown('right', 'd')
    self.player.angle = self.player.angle + ((right and 1 or 0) - (left and 1 or 0)) * self.params.turn_speed * dt

    local move_x, move_y = 0, 0
    local speed = self.params.move_speed * dt
    local angle = self.player.angle

    if self:isKeyDown('up', 'w') then
        move_x, move_y = math.cos(angle) * speed, math.sin(angle) * speed
    end
    if self:isKeyDown('down', 's') then
        move_x, move_y = move_x - math.cos(angle) * speed, move_y - math.sin(angle) * speed
    end
    if self:isKeyDown('q') then
        local a = angle - math.pi / 2
        move_x, move_y = move_x + math.cos(a) * speed, move_y + math.sin(a) * speed
    end
    if self:isKeyDown('e') then
        local a = angle + math.pi / 2
        move_x, move_y = move_x + math.cos(a) * speed, move_y + math.sin(a) * speed
    end

    local wrap = self.params.enable_edge_wrap
    self.player.x, self.player.y = self.di.components.PhysicsUtils.moveWithTileCollision(
        self.player.x, self.player.y, move_x, move_y,
        self.map, self.map_width, self.map_height, wrap, wrap
    )
end

function Raycaster:handleGridInput(dt)
    local dominated_key = nil  -- Track which key to process (first pressed wins)
    local PhysicsUtils = self.di.components.PhysicsUtils

    -- Update movement animation
    if self.grid_move.active then
        self.grid_move.progress = self.grid_move.progress + dt / self.params.grid_move_time
        if self.grid_move.progress >= 1 then
            self.player.x = self.grid_move.end_x
            self.player.y = self.grid_move.end_y
            self.grid_move.active = false
        else
            local t = self.grid_move.progress
            self.player.x = self.grid_move.start_x + (self.grid_move.end_x - self.grid_move.start_x) * t
            self.player.y = self.grid_move.start_y + (self.grid_move.end_y - self.grid_move.start_y) * t
        end
        return  -- No new input while moving
    end

    -- Update turn animation
    if self.grid_turn.active then
        self.grid_turn.progress = self.grid_turn.progress + dt / self.params.grid_turn_time
        if self.grid_turn.progress >= 1 then
            self.player.angle = self.grid_turn.end_angle
            self.grid_turn.active = false
        else
            local t = self.grid_turn.progress
            self.player.angle = self.grid_turn.start_angle + (self.grid_turn.end_angle - self.grid_turn.start_angle) * t
        end
        return  -- No new input while turning
    end

    -- Handle turning (90-degree increments)
    if self:isKeyDown('left', 'a') then
        self:startGridTurn(-math.pi / 2)
        return
    elseif self:isKeyDown('right', 'd') then
        self:startGridTurn(math.pi / 2)
        return
    end

    -- Handle movement
    local dx, dy = 0, 0
    if self:isKeyDown('up', 'w') then
        dx, dy = math.cos(self.player.angle), math.sin(self.player.angle)
    elseif self:isKeyDown('down', 's') then
        dx, dy = -math.cos(self.player.angle), -math.sin(self.player.angle)
    elseif self:isKeyDown('q') then
        local a = self.player.angle - math.pi / 2
        dx, dy = math.cos(a), math.sin(a)
    elseif self:isKeyDown('e') then
        local a = self.player.angle + math.pi / 2
        dx, dy = math.cos(a), math.sin(a)
    end

    if dx ~= 0 or dy ~= 0 then
        local target_x = math.floor(self.player.x + dx + 0.5) + 0.5
        local target_y = math.floor(self.player.y + dy + 0.5) + 0.5
        local tile_x, tile_y = math.floor(target_x), math.floor(target_y)

        if PhysicsUtils.isTileWalkable(self.map, tile_x, tile_y, self.map_width, self.map_height) then
            self:startGridMove(target_x, target_y)
        end
    end
end

function Raycaster:startGridMove(target_x, target_y)
    self.grid_move.active = true
    self.grid_move.start_x = self.player.x
    self.grid_move.start_y = self.player.y
    self.grid_move.end_x = target_x
    self.grid_move.end_y = target_y
    self.grid_move.progress = 0
end

function Raycaster:startGridTurn(delta)
    self.grid_turn.active = true
    self.grid_turn.start_angle = self.player.angle
    self.grid_turn.end_angle = self.player.angle + delta
    self.grid_turn.progress = 0
end
```

---

## Step 4: Create Grid Movement Variants

Add to `assets/data/variants/raycaster_variants.json`:

```json
{
    "clone_index": 11,
    "name": "Dungeon Crawler",
    "flavor_text": "Old school grid-based exploration",
    "movement_mode": "grid",
    "grid_move_time": 0.15,
    "grid_turn_time": 0.1,
    "generator": "divided_maze",
    "maze_width": 12,
    "maze_height": 12
},
{
    "clone_index": 12,
    "name": "Careful Explorer",
    "flavor_text": "Slow, deliberate movement",
    "movement_mode": "grid",
    "grid_move_time": 0.35,
    "grid_turn_time": 0.25,
    "generator": "cellular",
    "maze_width": 20,
    "maze_height": 20
}
```

---

## Step 5: Test

1. Run `love .`
2. Open launcher, find "Dungeon Crawler" variant
3. WASD should move one tile at a time with smooth animation
4. A/D should turn 90 degrees
5. Compare with a smooth movement variant

---

## Key Patterns

- **Schema-driven:** `movement_mode` param controls behavior
- **Uses existing components:** `PhysicsUtils.isTileWalkable` for collision
- **Animation state:** `grid_move.active` blocks input during animation
- **Lerp for smoothness:** Interpolate position/angle over time
- **Tile centers:** Always snap to `tile + 0.5`
