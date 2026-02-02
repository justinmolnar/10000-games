# Offline Tutorial: Raycaster Collectibles (Pac-Man Style)

## Goal
Add collectible items scattered throughout the maze. Collect them all to win (like Pac-Man dots).

## Difficulty: Medium (3-4 hours)

## Files to Study First
- `src/games/raycaster.lua` - Game logic
- `src/games/views/raycaster_view.lua` - Rendering
- `src/utils/game_components/billboard_renderer.lua` - 3D sprites
- `src/utils/game_components/victory_condition.lua` - Win/lose checking

## What You'll Build

- Collectible items placed on empty floor tiles
- 3D billboard rendering (floating gems/coins)
- Collection detection when player walks over them
- Victory when all collected
- HUD showing progress (5/20 collected)

---

## Step 1: Add Collectible State

Open `src/games/raycaster.lua` and modify `setupGameState()`:

```lua
function Raycaster:setupGameState()
    -- ... existing code ...

    -- NEW: Collectibles
    self.collectibles = {}
    self.collected_count = 0
    self.total_collectibles = 0

    -- Collection settings
    self.collection_radius = 0.5  -- How close to collect
    self.collectible_spawn_chance = 0.25  -- 25% of floor tiles

    -- ... rest of existing code ...
end
```

---

## Step 2: Create Collectible Placement Function

Add this new function after `generateMaze()`:

```lua
-- Place collectibles on random floor tiles
function Raycaster:placeCollectibles()
    self.collectibles = {}
    self.collected_count = 0

    local p = self.params
    local spawn_chance = p.collectible_spawn_chance or self.collectible_spawn_chance

    for y = 1, self.map_height do
        for x = 1, self.map_width do
            -- Only place on floor tiles (0 = floor)
            if self.map[y] and self.map[y][x] == 0 then
                -- Don't place on start or goal tiles
                local is_start = (x == math.floor(self.player.x) and y == math.floor(self.player.y))
                local is_goal = (x == self.goal.x and y == self.goal.y)

                if not is_start and not is_goal then
                    if self.rng:random() < spawn_chance then
                        table.insert(self.collectibles, {
                            x = x + 0.5,  -- Center of tile
                            y = y + 0.5,
                            collected = false,
                            bob_offset = self.rng:random() * math.pi * 2  -- Random start phase
                        })
                    end
                end
            end
        end
    end

    self.total_collectibles = #self.collectibles

    print(string.format("[Raycaster] Placed %d collectibles", self.total_collectibles))
end
```

---

## Step 3: Call Placement in generateMaze()

Modify `generateMaze()` to call the placement function:

```lua
function Raycaster:generateMaze()
    local result = self.maze_generator:generate(self.rng)

    self.map = result.map
    self.map_width = result.width
    self.map_height = result.height
    self.player.x = result.start.x
    self.player.y = result.start.y
    self.player.angle = result.start.angle or 0
    self.goal.x = result.goal.x
    self.goal.y = result.goal.y
    self.goal_reached = 0

    self.movement:setSmoothAngle("player", self.player.angle)

    -- Create goal billboard
    local p = self.params
    self.goal_diamond = BillboardRenderer.createDiamond(
        self.goal.x + 0.5,
        self.goal.y + 0.5,
        {
            height = 0.5,
            aspect = 0.6,
            color = p.goal_color or {0.2, 1, 0.4}
        }
    )
    self.billboards = {self.goal_diamond}

    -- NEW: Place collectibles
    self:placeCollectibles()

    -- NEW: Create collectible billboards
    self:createCollectibleBillboards()

    print(string.format("[Raycaster] Generated %dx%d maze, start=(%.1f,%.1f) goal=(%d,%d)",
        self.map_width, self.map_height, self.player.x, self.player.y, self.goal.x, self.goal.y))
end
```

---

## Step 4: Create Billboard Visuals for Collectibles

Add this function to create 3D sprites for each collectible:

```lua
-- Create billboard sprites for collectibles
function Raycaster:createCollectibleBillboards()
    local p = self.params
    local collectible_color = p.collectible_color or {1, 0.8, 0}  -- Gold

    for i, collectible in ipairs(self.collectibles) do
        collectible.billboard = BillboardRenderer.createDiamond(
            collectible.x,
            collectible.y,
            {
                height = 0.3,  -- Smaller than goal
                aspect = 0.5,
                color = collectible_color
            }
        )
        -- Add to billboards list for rendering
        table.insert(self.billboards, collectible.billboard)
    end
end
```

---

## Step 5: Add Collection Detection

Modify `updateGameLogic()` to check for collections:

```lua
function Raycaster:updateGameLogic(dt)
    if self.game_over or self.victory then return end

    self:handleInput(dt)
    self:updateBillboards(dt)
    self:updateCollectibles(dt)  -- NEW
    self:checkCollections()       -- NEW
    self:checkGoal()
    self:updateMetrics()
    self.visual_effects:update(dt)
end
```

Add these new functions:

```lua
-- Animate collectibles (bobbing motion)
function Raycaster:updateCollectibles(dt)
    self.bob_timer = self.bob_timer + dt * 3

    for i, collectible in ipairs(self.collectibles) do
        if not collectible.collected and collectible.billboard then
            -- Bob up and down
            local bob = math.sin(self.bob_timer + collectible.bob_offset) * 0.1
            collectible.billboard.y_offset = bob
        end
    end
end

-- Check if player collected any items
function Raycaster:checkCollections()
    for i, collectible in ipairs(self.collectibles) do
        if not collectible.collected then
            -- Calculate distance to player
            local dx = self.player.x - collectible.x
            local dy = self.player.y - collectible.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < self.collection_radius then
                self:collectItem(collectible)
            end
        end
    end
end

-- Handle collecting a single item
function Raycaster:collectItem(collectible)
    collectible.collected = true
    self.collected_count = self.collected_count + 1

    -- Hide the billboard
    if collectible.billboard then
        collectible.billboard.visible = false
        -- Or remove from billboards list:
        -- for i, bb in ipairs(self.billboards) do
        --     if bb == collectible.billboard then
        --         table.remove(self.billboards, i)
        --         break
        --     end
        -- end
    end

    -- Visual feedback
    self.visual_effects:flash({
        color = {1, 1, 0, 0.3},
        duration = 0.15,
        mode = "fade_out"
    })

    -- Check if all collected
    if self.collected_count >= self.total_collectibles then
        print("[Raycaster] All collectibles gathered!")
        -- Optional: Auto-win, or still require reaching goal
    end

    print(string.format("[Raycaster] Collected %d/%d",
        self.collected_count, self.total_collectibles))
end
```

---

## Step 6: Update Victory Condition

Modify the victory checker setup in `setupComponents()`:

```lua
function Raycaster:setupComponents()
    -- ... existing code ...

    -- NEW: Victory requires collecting all items AND reaching goal
    self.victory_checker = VictoryCondition:new({
        victory = {
            type = "compound",
            conditions = {
                {type = "threshold", metric = "collected_count", target = "total_collectibles"},
                {type = "threshold", metric = "goal_reached", target = 1}
            },
            mode = "all"  -- Must meet ALL conditions
        },
        loss = {type = "none"}
    })
    self.victory_checker.game = self
end
```

**Or simpler approach** - modify `checkGoal()`:

```lua
function Raycaster:checkGoal()
    local px, py = PhysicsUtils.worldToTile(self.player.x, self.player.y)
    if px == self.goal.x and py == self.goal.y then
        -- Only win if all collectibles gathered
        if self.collected_count >= self.total_collectibles then
            self.goal_reached = 1
            self.mazes_completed = self.mazes_completed + 1
            self.victory = true
            self.visual_effects:flash({color = {0, 1, 0, 0.5}, duration = 0.5, mode = "fade_out"})
        else
            -- At goal but not done collecting
            -- Optional: Show message "Collect all gems first!"
        end
    end
end
```

---

## Step 7: Update HUD

Modify the HUD setup in `setupComponents()` to show collection progress:

```lua
self.hud = HUDRenderer:new({
    primary = {label = "Time", key = "time_elapsed", format = "time"},
    secondary = {label = "Gems", key = "collection_progress", format = "fraction"}
})
self.hud.game = self
```

Add a helper property for the HUD:

```lua
function Raycaster:updateMetrics()
    self.metrics.time_elapsed = self.time_elapsed
    self.metrics.mazes_completed = self.mazes_completed

    -- NEW: For HUD display
    self.collection_progress = string.format("%d/%d",
        self.collected_count, self.total_collectibles)
end
```

**Or** modify HUDRenderer call to use custom format - check how other games handle this.

---

## Step 8: Update the View (If Needed)

Open `src/games/views/raycaster_view.lua` and check if billboards with `visible = false` are filtered out.

If not, add filtering in the draw loop:

```lua
-- In the billboard rendering section
for _, billboard in ipairs(self.game.billboards) do
    if billboard.visible ~= false then  -- Skip hidden billboards
        -- ... render billboard ...
    end
end
```

---

## Step 9: Add Schema Parameters

Update `assets/data/schemas/raycaster_schema.json`:

```json
{
  "collectible_spawn_chance": {
    "type": "number",
    "default": 0.25,
    "min": 0.05,
    "max": 1.0,
    "description": "Chance of placing a collectible on each floor tile"
  },
  "collectible_color": {
    "type": "array",
    "default": [1, 0.8, 0],
    "description": "RGB color for collectibles"
  },
  "require_all_collectibles": {
    "type": "boolean",
    "default": true,
    "description": "Must collect all items before reaching goal"
  }
}
```

---

## Step 10: Create a Collectible Variant

Add to `assets/data/variants/raycaster_variants.json`:

```json
{
  "clone_index": 12,
  "name": "Gem Hunter",
  "flavor_text": "Collect all gems before reaching the exit",
  "collectible_spawn_chance": 0.3,
  "collectible_color": [0, 1, 1],
  "maze_width": 12,
  "maze_height": 12,
  "require_all_collectibles": true
}
```

---

## Step 11: Test It

1. Run the game: `love .`
2. Launch the Raycaster (or your new "Gem Hunter" variant)
3. Walk around - you should see floating gems
4. Walk over them - they should disappear
5. Try reaching goal without all gems (should not win)
6. Collect all gems, reach goal (should win)

---

## Stretch Goals

1. **Different collectible types:** Some worth more points, different colors
2. **Sound effects:** Play sound on collection
3. **Score system:** Points per collectible, bonus for speed
4. **Minimap icons:** Show collectible locations on minimap
5. **Collectible counter UI:** Floating text showing "+1" on pickup
6. **Power pellets:** Special collectibles that grant temporary abilities

## Pac-Man Mode (Advanced)

To make it more Pac-Man-like:
- Place collectible on EVERY floor tile (spawn_chance = 1.0)
- Add enemies that patrol the maze
- Add "power pellets" that let you defeat enemies temporarily
- Add lives system

---

## Common Issues

| Problem | Solution |
|---------|----------|
| Collectibles don't appear | Check `placeCollectibles` is called, check billboard rendering |
| Can't collect items | Check `collection_radius`, print distances to debug |
| All items same height | Check `bob_offset` is being used |
| Game ends without collecting all | Check victory condition logic |
| Billboards render after collection | Check `visible = false` filtering |

## Key Patterns Learned

- **Entity lists:** Store game objects in arrays, iterate to update/check
- **Billboard sprites:** 3D representation of 2D sprites in raycaster
- **Distance-based detection:** Simple radius check for collection
- **Compound victory conditions:** Multiple requirements for winning
- **Visual feedback:** Screen flash, sound, animation on game events
