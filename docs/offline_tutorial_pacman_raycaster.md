# Offline Tutorial: Pac-Man Raycaster Variants

Create first-person Pac-Man variants using the raycaster engine with ghost AI.

**Prerequisites:** Completed raycaster game, rotLove integration, billboard renderer
**Estimated Complexity:** Medium-High
**Files to Create/Modify:**
- `src/utils/game_components/ghost_ai.lua` (new)
- `src/games/raycaster.lua` (modify)
- `src/games/views/raycaster_view.lua` (modify)
- `assets/data/schemas/raycaster_schema.json` (modify)
- `assets/data/variants/raycaster_variants.json` (add variants)

---

## Part 1: Understanding the Goal

We're creating Pac-Man-style variants where:
- Player navigates a maze in first-person
- Ghosts chase with classic AI behaviors (Blinky, Pinky, Inky, Clyde)
- Collectible pills scattered throughout
- Power pills let you "eat" ghosts temporarily
- Win by collecting all pills OR reaching the exit

This combines:
- Existing raycaster movement/rendering
- Existing maze generators (rotLove works great here)
- New ghost AI component
- New pill/collectible system

---

## Part 2: Ghost AI Component

Create `src/utils/game_components/ghost_ai.lua`:

```lua
local Object = require('class')

local GhostAI = Object:extend('GhostAI')

-- Ghost behavior modes
GhostAI.MODES = {
    CHASE = "chase",
    SCATTER = "scatter",
    FRIGHTENED = "frightened",
    DEAD = "dead"
}

-- Ghost personalities
GhostAI.TYPES = {
    BLINKY = "blinky",  -- Red: direct chase
    PINKY = "pinky",    -- Pink: ambush (4 ahead)
    INKY = "inky",      -- Blue: uses Blinky's position
    CLYDE = "clyde"     -- Yellow: shy (flees when close)
}

function GhostAI:new(config)
    config = config or {}

    self.ghost_type = config.ghost_type or GhostAI.TYPES.BLINKY
    self.mode = GhostAI.MODES.SCATTER
    self.speed = config.speed or 2.0
    self.frightened_speed = config.frightened_speed or 1.0

    -- Position (world coordinates, like player)
    self.x = config.x or 1.5
    self.y = config.y or 1.5
    self.target_x = self.x
    self.target_y = self.y

    -- Current movement direction
    self.dir_x = 0
    self.dir_y = 0

    -- Scatter corner targets (in tile coords)
    self.scatter_targets = {
        blinky = {x = 26, y = 1},   -- Top-right
        pinky = {x = 1, y = 1},     -- Top-left
        inky = {x = 26, y = 26},    -- Bottom-right
        clyde = {x = 1, y = 26}     -- Bottom-left
    }

    -- Frightened timer
    self.frightened_timer = 0
    self.frightened_duration = config.frightened_duration or 6.0

    -- Wave system (scatter/chase alternation)
    self.wave_timer = 0
    self.wave_index = 1
    self.wave_pattern = config.wave_pattern or {
        {mode = "scatter", duration = 7},
        {mode = "chase", duration = 20},
        {mode = "scatter", duration = 7},
        {mode = "chase", duration = 20},
        {mode = "scatter", duration = 5},
        {mode = "chase", duration = 20},
        {mode = "scatter", duration = 5},
        {mode = "chase", duration = 999}  -- Permanent chase
    }

    -- Visual
    self.color = config.color or {1, 0, 0}
    self.frightened_color = {0, 0, 1}

    return self
end

function GhostAI:update(dt, player, map, map_width, map_height, blinky_ref)
    -- Update wave timer (scatter/chase cycles)
    if self.mode ~= GhostAI.MODES.FRIGHTENED and self.mode ~= GhostAI.MODES.DEAD then
        self:updateWave(dt)
    end

    -- Update frightened timer
    if self.mode == GhostAI.MODES.FRIGHTENED then
        self.frightened_timer = self.frightened_timer - dt
        if self.frightened_timer <= 0 then
            self.mode = GhostAI.MODES.CHASE
        end
    end

    -- Calculate target based on mode and ghost type
    local target = self:calculateTarget(player, blinky_ref)

    -- Move toward target
    self:moveToward(target, dt, map, map_width, map_height)
end

function GhostAI:calculateTarget(player, blinky_ref)
    if self.mode == GhostAI.MODES.SCATTER then
        return self.scatter_targets[self.ghost_type]

    elseif self.mode == GhostAI.MODES.FRIGHTENED then
        -- Random target (will pick random direction at junctions)
        return {x = math.random(1, 28), y = math.random(1, 31)}

    elseif self.mode == GhostAI.MODES.DEAD then
        -- Return to ghost house (center of map)
        return {x = 14, y = 14}

    elseif self.mode == GhostAI.MODES.CHASE then
        return self:calculateChaseTarget(player, blinky_ref)
    end

    return {x = player.x, y = player.y}
end

function GhostAI:calculateChaseTarget(player, blinky_ref)
    local target = {x = player.x, y = player.y}

    if self.ghost_type == GhostAI.TYPES.BLINKY then
        -- Direct chase: target player position
        -- (already set)

    elseif self.ghost_type == GhostAI.TYPES.PINKY then
        -- Ambush: target 4 tiles ahead of player
        local ahead = 4
        target.x = player.x + math.cos(player.angle) * ahead
        target.y = player.y + math.sin(player.angle) * ahead

    elseif self.ghost_type == GhostAI.TYPES.INKY then
        -- Complex: use Blinky's position
        -- 1. Get 2 tiles ahead of player
        -- 2. Double vector from Blinky to that point
        if blinky_ref then
            local ahead_x = player.x + math.cos(player.angle) * 2
            local ahead_y = player.y + math.sin(player.angle) * 2
            local dx = ahead_x - blinky_ref.x
            local dy = ahead_y - blinky_ref.y
            target.x = blinky_ref.x + dx * 2
            target.y = blinky_ref.y + dy * 2
        end

    elseif self.ghost_type == GhostAI.TYPES.CLYDE then
        -- Shy: chase until within 8 tiles, then scatter
        local dist = math.sqrt((self.x - player.x)^2 + (self.y - player.y)^2)
        if dist < 8 then
            target = self.scatter_targets[self.ghost_type]
        end
    end

    return target
end

function GhostAI:moveToward(target, dt, map, map_width, map_height)
    local speed = self.mode == GhostAI.MODES.FRIGHTENED
        and self.frightened_speed
        or self.speed

    -- Get current tile
    local tile_x = math.floor(self.x)
    local tile_y = math.floor(self.y)

    -- Check if at tile center (decision point)
    local cx = tile_x + 0.5
    local cy = tile_y + 0.5
    local dist_to_center = math.sqrt((self.x - cx)^2 + (self.y - cy)^2)

    if dist_to_center < 0.1 then
        -- At junction: choose best direction toward target
        local best_dir = self:chooseBestDirection(target, map, map_width, map_height)
        self.dir_x = best_dir.x
        self.dir_y = best_dir.y
    end

    -- Move in current direction
    local new_x = self.x + self.dir_x * speed * dt
    local new_y = self.y + self.dir_y * speed * dt

    -- Check collision
    if not self:isWall(new_x, new_y, map, map_width, map_height) then
        self.x = new_x
        self.y = new_y
    else
        -- Hit wall, snap to center and recalculate
        self.x = cx
        self.y = cy
    end
end

function GhostAI:chooseBestDirection(target, map, map_width, map_height)
    local directions = {
        {x = 0, y = -1, name = "up"},
        {x = -1, y = 0, name = "left"},
        {x = 0, y = 1, name = "down"},
        {x = 1, y = 0, name = "right"}
    }

    local best_dist = math.huge
    local best_dir = {x = 0, y = 0}
    local current_tile_x = math.floor(self.x)
    local current_tile_y = math.floor(self.y)

    -- Ghosts can't reverse direction (except on mode change)
    local reverse_x = -self.dir_x
    local reverse_y = -self.dir_y

    for _, dir in ipairs(directions) do
        -- Skip reverse direction
        if not (dir.x == reverse_x and dir.y == reverse_y) then
            local check_x = current_tile_x + dir.x + 0.5
            local check_y = current_tile_y + dir.y + 0.5

            if not self:isWall(check_x, check_y, map, map_width, map_height) then
                -- Calculate distance to target
                local dist = math.sqrt(
                    (check_x - target.x)^2 +
                    (check_y - target.y)^2
                )

                if self.mode == GhostAI.MODES.FRIGHTENED then
                    -- Frightened: pick randomly from valid directions
                    if math.random() < 0.25 then
                        return dir
                    end
                elseif dist < best_dist then
                    best_dist = dist
                    best_dir = dir
                end
            end
        end
    end

    return best_dir
end

function GhostAI:isWall(x, y, map, map_width, map_height)
    local tile_x = math.floor(x)
    local tile_y = math.floor(y)

    if tile_x < 1 or tile_x > map_width or tile_y < 1 or tile_y > map_height then
        return true
    end

    return map[tile_y] and map[tile_y][tile_x] == 1
end

function GhostAI:updateWave(dt)
    self.wave_timer = self.wave_timer + dt

    local current_wave = self.wave_pattern[self.wave_index]
    if current_wave and self.wave_timer >= current_wave.duration then
        self.wave_timer = 0
        self.wave_index = math.min(self.wave_index + 1, #self.wave_pattern)

        local new_wave = self.wave_pattern[self.wave_index]
        if new_wave then
            if new_wave.mode == "scatter" then
                self.mode = GhostAI.MODES.SCATTER
            else
                self.mode = GhostAI.MODES.CHASE
            end
            -- Reverse direction on mode change (classic behavior)
            self.dir_x = -self.dir_x
            self.dir_y = -self.dir_y
        end
    end
end

function GhostAI:frighten()
    if self.mode ~= GhostAI.MODES.DEAD then
        self.mode = GhostAI.MODES.FRIGHTENED
        self.frightened_timer = self.frightened_duration
        -- Reverse direction
        self.dir_x = -self.dir_x
        self.dir_y = -self.dir_y
    end
end

function GhostAI:kill()
    self.mode = GhostAI.MODES.DEAD
end

function GhostAI:revive(x, y)
    self.x = x
    self.y = y
    self.mode = GhostAI.MODES.SCATTER
    self.wave_index = 1
    self.wave_timer = 0
end

function GhostAI:getColor()
    if self.mode == GhostAI.MODES.FRIGHTENED then
        -- Flash white near end
        if self.frightened_timer < 2 and math.floor(self.frightened_timer * 4) % 2 == 0 then
            return {1, 1, 1}
        end
        return self.frightened_color
    elseif self.mode == GhostAI.MODES.DEAD then
        return {0.3, 0.3, 0.3, 0.5}
    end
    return self.color
end

function GhostAI:isEdible()
    return self.mode == GhostAI.MODES.FRIGHTENED
end

function GhostAI:isDead()
    return self.mode == GhostAI.MODES.DEAD
end

return GhostAI
```

---

## Part 3: Pill System

Add a simple pill manager to the raycaster. In `raycaster.lua`, add:

```lua
function Raycaster:setupPills()
    self.pills = {}
    self.power_pills = {}
    self.pills_collected = 0
    self.total_pills = 0

    -- Place pills on floor tiles
    local floor_tiles = self.maze_generator:getFloorTiles()

    for i, tile in ipairs(floor_tiles) do
        -- Skip start and goal positions
        local is_start = (tile.x == math.floor(self.player.x) and
                         tile.y == math.floor(self.player.y))
        local is_goal = (tile.x == self.goal.x and tile.y == self.goal.y)

        if not is_start and not is_goal then
            -- 5% chance of power pill, otherwise regular pill
            if self.rng:random() < 0.05 then
                table.insert(self.power_pills, {
                    x = tile.x + 0.5,
                    y = tile.y + 0.5,
                    collected = false
                })
            else
                table.insert(self.pills, {
                    x = tile.x + 0.5,
                    y = tile.y + 0.5,
                    collected = false
                })
            end
            self.total_pills = self.total_pills + 1
        end
    end
end

function Raycaster:updatePills()
    local px, py = self.player.x, self.player.y
    local collect_radius = 0.5

    -- Check regular pills
    for _, pill in ipairs(self.pills) do
        if not pill.collected then
            local dist = math.sqrt((px - pill.x)^2 + (py - pill.y)^2)
            if dist < collect_radius then
                pill.collected = true
                self.pills_collected = self.pills_collected + 1
                self.score = (self.score or 0) + 10
            end
        end
    end

    -- Check power pills
    for _, pill in ipairs(self.power_pills) do
        if not pill.collected then
            local dist = math.sqrt((px - pill.x)^2 + (py - pill.y)^2)
            if dist < collect_radius then
                pill.collected = true
                self.pills_collected = self.pills_collected + 1
                self.score = (self.score or 0) + 50
                -- Frighten all ghosts!
                self:frightenGhosts()
            end
        end
    end
end

function Raycaster:frightenGhosts()
    for _, ghost in ipairs(self.ghosts) do
        ghost:frighten()
    end
    self.ghosts_eaten_combo = 0  -- Reset combo
end
```

---

## Part 4: Ghost Spawning and Updates

Add ghost management to `raycaster.lua`:

```lua
local GhostAI = require('src.utils.game_components.ghost_ai')

function Raycaster:setupGhosts()
    if not self.params.enable_ghosts then
        self.ghosts = {}
        return
    end

    local ghost_count = self.params.ghost_count or 4
    local ghost_configs = {
        {type = GhostAI.TYPES.BLINKY, color = {1, 0, 0}},      -- Red
        {type = GhostAI.TYPES.PINKY, color = {1, 0.7, 0.7}},   -- Pink
        {type = GhostAI.TYPES.INKY, color = {0, 1, 1}},        -- Cyan
        {type = GhostAI.TYPES.CLYDE, color = {1, 0.6, 0}}      -- Orange
    }

    self.ghosts = {}
    self.ghosts_eaten_combo = 0

    -- Spawn ghosts near center of map
    local center_x = self.map_width / 2
    local center_y = self.map_height / 2

    for i = 1, math.min(ghost_count, 4) do
        local cfg = ghost_configs[i]
        local ghost = GhostAI:new({
            ghost_type = cfg.type,
            color = cfg.color,
            x = center_x + (i - 2.5) * 0.5,
            y = center_y,
            speed = self.params.ghost_speed or 2.0,
            frightened_speed = self.params.ghost_frightened_speed or 1.0,
            frightened_duration = self.params.frightened_duration or 6.0
        })
        table.insert(self.ghosts, ghost)
    end
end

function Raycaster:updateGhosts(dt)
    if not self.ghosts then return end

    local blinky = self.ghosts[1]  -- First ghost is always Blinky

    for _, ghost in ipairs(self.ghosts) do
        ghost:update(dt, self.player, self.map, self.map_width, self.map_height, blinky)
    end

    -- Check collisions with player
    self:checkGhostCollisions()
end

function Raycaster:checkGhostCollisions()
    local px, py = self.player.x, self.player.y
    local collision_radius = 0.4

    for _, ghost in ipairs(self.ghosts) do
        local dist = math.sqrt((px - ghost.x)^2 + (py - ghost.y)^2)

        if dist < collision_radius then
            if ghost:isEdible() then
                -- Eat the ghost!
                ghost:kill()
                self.ghosts_eaten_combo = self.ghosts_eaten_combo + 1
                local points = 200 * math.pow(2, self.ghosts_eaten_combo - 1)
                self.score = (self.score or 0) + points
                self.visual_effects:flash({
                    color = {0, 0, 1, 0.5},
                    duration = 0.3,
                    mode = "fade_out"
                })
            elseif not ghost:isDead() then
                -- Player dies!
                self.lives = (self.lives or 3) - 1
                if self.lives <= 0 then
                    self.game_over = true
                else
                    -- Reset positions
                    self:resetPositions()
                end
                self.visual_effects:flash({
                    color = {1, 0, 0, 0.7},
                    duration = 0.5,
                    mode = "fade_out"
                })
            end
        end
    end
end

function Raycaster:resetPositions()
    -- Reset player to start
    local result = self.maze_generator:generate(self.rng)
    self.player.x = result.start.x
    self.player.y = result.start.y
    self.player.angle = result.start.angle or 0

    -- Reset ghosts to center
    local center_x = self.map_width / 2
    local center_y = self.map_height / 2
    for i, ghost in ipairs(self.ghosts) do
        ghost:revive(center_x + (i - 2.5) * 0.5, center_y)
    end
end
```

---

## Part 5: Rendering Ghosts as Billboards

In `raycaster_view.lua`, render ghosts as billboards:

```lua
function RaycasterView:collectBillboards()
    local billboards = {}

    -- Add goal billboard
    if self.game.goal_diamond then
        table.insert(billboards, self.game.goal_diamond)
    end

    -- Add ghost billboards
    if self.game.ghosts then
        for _, ghost in ipairs(self.game.ghosts) do
            local color = ghost:getColor()
            table.insert(billboards, {
                x = ghost.x,
                y = ghost.y,
                y_offset = 0,
                height = 0.8,
                width = 0.6,
                color = color,
                shape = "diamond"  -- Or create ghost shape
            })
        end
    end

    -- Add pill billboards (small dots)
    if self.game.pills then
        for _, pill in ipairs(self.game.pills) do
            if not pill.collected then
                table.insert(billboards, {
                    x = pill.x,
                    y = pill.y,
                    y_offset = -0.2,
                    height = 0.15,
                    width = 0.15,
                    color = {1, 1, 0.8},
                    shape = "circle"
                })
            end
        end
    end

    -- Add power pill billboards (larger, pulsing)
    if self.game.power_pills then
        local pulse = 0.8 + math.sin(self.game.time_elapsed * 5) * 0.2
        for _, pill in ipairs(self.game.power_pills) do
            if not pill.collected then
                table.insert(billboards, {
                    x = pill.x,
                    y = pill.y,
                    y_offset = -0.1,
                    height = 0.3 * pulse,
                    width = 0.3 * pulse,
                    color = {1, 0.8, 0.2},
                    shape = "circle"
                })
            end
        end
    end

    return billboards
end
```

---

## Part 6: Schema Parameters

Add to `raycaster_schema.json`:

```json
"enable_ghosts": {
    "type": "boolean",
    "default": false,
    "description": "Enable Pac-Man style ghost enemies"
},
"ghost_count": {
    "type": "integer",
    "default": 4,
    "min": 1,
    "max": 4,
    "description": "Number of ghosts (1=Blinky only, 4=all four)"
},
"ghost_speed": {
    "type": "number",
    "default": 2.0,
    "min": 0.5,
    "max": 5.0,
    "description": "Ghost movement speed"
},
"ghost_frightened_speed": {
    "type": "number",
    "default": 1.0,
    "min": 0.5,
    "max": 3.0,
    "description": "Ghost speed when frightened"
},
"frightened_duration": {
    "type": "number",
    "default": 6.0,
    "min": 2.0,
    "max": 15.0,
    "description": "How long ghosts stay frightened"
},
"enable_pills": {
    "type": "boolean",
    "default": false,
    "description": "Enable collectible pills"
},
"win_condition": {
    "type": "string",
    "default": "goal",
    "enum": ["goal", "pills", "both"],
    "description": "Win by reaching goal, collecting all pills, or both"
},
"player_lives": {
    "type": "integer",
    "default": 3,
    "min": 1,
    "max": 9,
    "description": "Starting lives (for ghost mode)"
}
```

---

## Part 7: Example Variants

Add to `raycaster_variants.json`:

```json
{
    "clone_index": 100,
    "name": "Pac-Maze 3D",
    "generator": "rogue",
    "maze_width": 40,
    "maze_height": 30,
    "cell_width": 4,
    "cell_height": 3,
    "enable_ghosts": true,
    "ghost_count": 4,
    "ghost_speed": 2.0,
    "enable_pills": true,
    "win_condition": "pills",
    "player_lives": 3,
    "wall_color_ns": [0.1, 0.1, 0.4],
    "wall_color_ew": [0.15, 0.15, 0.5],
    "floor_color": [0.05, 0.05, 0.1],
    "ceiling_color": [0, 0, 0],
    "flavor_text": "Classic Pac-Man in first-person. Eat all pills, avoid ghosts!"
},
{
    "clone_index": 101,
    "name": "Ghost Hunter",
    "generator": "uniform",
    "maze_width": 35,
    "maze_height": 35,
    "enable_ghosts": true,
    "ghost_count": 4,
    "ghost_speed": 1.5,
    "enable_pills": true,
    "win_condition": "goal",
    "frightened_duration": 10.0,
    "player_lives": 5,
    "flavor_text": "Reach the exit. Ghosts are slow but relentless."
},
{
    "clone_index": 102,
    "name": "Blinky's Maze",
    "generator": "divided_maze",
    "maze_width": 31,
    "maze_height": 31,
    "enable_ghosts": true,
    "ghost_count": 1,
    "ghost_speed": 2.5,
    "enable_pills": false,
    "win_condition": "goal",
    "player_lives": 1,
    "show_minimap": false,
    "wall_color_ns": [0.6, 0.1, 0.1],
    "wall_color_ew": [0.5, 0.05, 0.05],
    "flavor_text": "Just you and Blinky. One life. No map. Run."
},
{
    "clone_index": 103,
    "name": "Cave Escape",
    "generator": "cellular",
    "maze_width": 45,
    "maze_height": 45,
    "cellular_iterations": 4,
    "cellular_prob": 0.48,
    "enable_ghosts": true,
    "ghost_count": 3,
    "ghost_speed": 1.8,
    "enable_pills": true,
    "win_condition": "both",
    "flavor_text": "Organic caves. Collect pills AND reach the exit. Ghosts in pursuit."
},
{
    "clone_index": 104,
    "name": "Power Pill Frenzy",
    "generator": "rogue",
    "maze_width": 50,
    "maze_height": 50,
    "cell_width": 5,
    "cell_height": 5,
    "enable_ghosts": true,
    "ghost_count": 4,
    "ghost_speed": 2.2,
    "frightened_duration": 4.0,
    "enable_pills": true,
    "win_condition": "pills",
    "player_lives": 3,
    "flavor_text": "Lots of pills, fast ghosts. Hunt or be hunted."
}
```

---

## Part 8: Integration Checklist

### In `raycaster.lua`:

1. Add requires:
```lua
local GhostAI = require('src.utils.game_components.ghost_ai')
```

2. In `setupGameState()`:
```lua
self.score = 0
self.lives = self.params.player_lives or 3
self.ghosts_eaten_combo = 0
```

3. In `generateMaze()` (after maze generation):
```lua
if self.params.enable_pills then
    self:setupPills()
end
if self.params.enable_ghosts then
    self:setupGhosts()
end
```

4. In `updateGameLogic(dt)`:
```lua
if self.params.enable_pills then
    self:updatePills()
end
if self.params.enable_ghosts then
    self:updateGhosts(dt)
end
```

5. Modify `checkGoal()` for win conditions:
```lua
function Raycaster:checkGoal()
    local win_condition = self.params.win_condition or "goal"
    local at_goal = false
    local pills_done = false

    -- Check goal position
    local px, py = PhysicsUtils.worldToTile(self.player.x, self.player.y)
    if px == self.goal.x and py == self.goal.y then
        at_goal = true
    end

    -- Check pills collected
    if self.params.enable_pills then
        pills_done = (self.pills_collected >= self.total_pills)
    else
        pills_done = true
    end

    -- Check win
    local won = false
    if win_condition == "goal" then
        won = at_goal
    elseif win_condition == "pills" then
        won = pills_done
    elseif win_condition == "both" then
        won = at_goal and pills_done
    end

    if won then
        self.goal_reached = 1
        self.mazes_completed = self.mazes_completed + 1
        self.victory = true
        self.visual_effects:flash({color = {0, 1, 0, 0.5}, duration = 0.5})
    end
end
```

---

## Part 9: Testing

1. Start with `enable_ghosts = true, ghost_count = 1` to test Blinky alone
2. Verify ghost follows player (CHASE mode)
3. Test SCATTER mode by waiting 7 seconds
4. Add pills and test collection
5. Test power pills trigger FRIGHTENED mode
6. Add remaining ghosts and verify unique behaviors
7. Test death and life system

### Debug Tips

Add to HUD for debugging:
```lua
-- In HUDRenderer or view
love.graphics.print(string.format("Ghosts: %d  Pills: %d/%d  Lives: %d",
    #self.game.ghosts,
    self.game.pills_collected,
    self.game.total_pills,
    self.game.lives
), 10, 10)
```

---

## Summary

This tutorial adds:
- **GhostAI component** with 4 distinct personalities
- **Pill system** with regular and power pills
- **Win conditions** (goal, pills, or both)
- **Lives system** with ghost collision
- **5 example variants** ranging from classic to unique twists

The ghost AI faithfully recreates the original Pac-Man behaviors:
- Blinky directly chases
- Pinky ambushes 4 tiles ahead
- Inky uses Blinky's position for unpredictable targeting
- Clyde is shy and retreats when close

Combined with the existing raycaster and maze generators, this creates a compelling first-person Pac-Man experience.
