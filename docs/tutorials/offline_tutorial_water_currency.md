# Offline Tutorial: Water Currency System

## Goal
Add a rare universal pickup ("Water") that appears across all minigames. It's a secondary currency/resource that feeds into progression - maybe skill tree, maybe permanent upgrades, maybe something weird.

## Difficulty: Medium-Hard (4-5 hours)

## The Design

**What is Water?**
- Rare pickup that can spawn in any minigame
- Separate from tokens (tokens = per-game reward, water = universal rare resource)
- Persists across sessions (saved to player data)
- Feeds into... something (skill tree? upgrades? unlocks? TBD)

**Spawn behavior:**
- Very rare (1-5% chance per game, or time-based)
- Visual: Distinct, animated, noticeable
- Audio: Satisfying collection sound
- Maybe spawns in specific conditions (streaks, near-death, random)

**Collection:**
- Player touches/collects it
- Adds to persistent water count
- Visual/audio feedback
- Maybe shows "+1 💧" popup

---

## Files to Study First

- `src/games/base_game.lua` - Where to hook the system
- `src/models/player_data.lua` - Where water count will be stored
- `src/utils/game_components/powerup_system.lua` - Similar pickup pattern
- `src/utils/game_components/visual_effects.lua` - For spawn effects

---

## Step 1: Add Water to Player Data

Open `src/models/player_data.lua` and add water tracking:

```lua
-- In the default data structure or init:
function PlayerData:getDefaults()
    return {
        -- ... existing fields ...
        water = 0,
        water_lifetime = 0,  -- Total ever collected
        water_last_collected = nil,  -- Timestamp
    }
end

-- Add getter/setter
function PlayerData:getWater()
    return self.data.water or 0
end

function PlayerData:addWater(amount)
    self.data.water = (self.data.water or 0) + amount
    self.data.water_lifetime = (self.data.water_lifetime or 0) + amount
    self.data.water_last_collected = os.time()
    self:markDirty()

    -- Emit event for UI updates
    if self.event_bus then
        self.event_bus:publish('water_collected', amount, self.data.water)
    end

    return self.data.water
end

function PlayerData:spendWater(amount)
    if self.data.water >= amount then
        self.data.water = self.data.water - amount
        self:markDirty()
        return true
    end
    return false
end
```

---

## Step 2: Create the Water Pickup Component

Create `src/utils/game_components/water_pickup.lua`:

```lua
-- src/utils/game_components/water_pickup.lua
-- Universal rare pickup that appears across all games

local Object = require('class')
local WaterPickup = Object:extend('WaterPickup')

function WaterPickup:init(config)
    config = config or {}

    -- Spawn settings
    self.spawn_chance = config.spawn_chance or 0.02  -- 2% base chance
    self.spawn_mode = config.spawn_mode or "random"  -- "random", "timed", "conditional"
    self.spawn_interval = config.spawn_interval or 30  -- For timed mode
    self.max_active = config.max_active or 1

    -- Pickup settings
    self.collection_radius = config.collection_radius or 20
    self.lifetime = config.lifetime or 15  -- Seconds before despawn
    self.value = config.value or 1

    -- Visual settings
    self.size = config.size or 16
    self.color = config.color or {0.3, 0.6, 1.0}  -- Blue
    self.glow_color = config.glow_color or {0.5, 0.8, 1.0, 0.5}

    -- State
    self.active_pickups = {}
    self.spawn_timer = 0
    self.total_spawned = 0
    self.total_collected = 0

    -- Callbacks
    self.on_collect = config.on_collect  -- function(pickup, player_data)
    self.on_spawn = config.on_spawn      -- function(pickup)
    self.on_despawn = config.on_despawn  -- function(pickup, reason)

    -- Dependencies (set externally)
    self.player_data = nil
    self.rng = nil
    self.bounds = {x = 0, y = 0, width = 800, height = 600}
end

-- Set the play area bounds
function WaterPickup:setBounds(x, y, width, height)
    self.bounds = {x = x, y = y, width = width, height = height}
end

-- Set RNG for deterministic spawning (important for demos!)
function WaterPickup:setRNG(rng)
    self.rng = rng
end

-- Set player data for collection
function WaterPickup:setPlayerData(player_data)
    self.player_data = player_data
end

-- Update (call every frame)
function WaterPickup:update(dt)
    -- Update spawn timer
    if self.spawn_mode == "timed" then
        self.spawn_timer = self.spawn_timer + dt
        if self.spawn_timer >= self.spawn_interval then
            self.spawn_timer = 0
            self:trySpawn()
        end
    end

    -- Update active pickups
    for i = #self.active_pickups, 1, -1 do
        local pickup = self.active_pickups[i]

        -- Update lifetime
        pickup.age = pickup.age + dt
        if pickup.age >= self.lifetime then
            self:despawn(i, "timeout")
        else
            -- Update animation
            pickup.bob_offset = math.sin(pickup.age * 4) * 3
            pickup.pulse = 0.8 + math.sin(pickup.age * 6) * 0.2
            pickup.rotation = pickup.rotation + dt * 2
        end
    end
end

-- Try to spawn a water pickup (call on game events)
function WaterPickup:trySpawn(force_x, force_y)
    -- Check max active
    if #self.active_pickups >= self.max_active then
        return false
    end

    -- Roll for spawn (unless forced position)
    local rng = self.rng or love.math
    if not force_x then
        local roll = rng:random()
        if roll > self.spawn_chance then
            return false
        end
    end

    -- Determine position
    local x, y
    if force_x and force_y then
        x, y = force_x, force_y
    else
        -- Random position within bounds (with margin)
        local margin = self.size * 2
        x = self.bounds.x + margin + rng:random() * (self.bounds.width - margin * 2)
        y = self.bounds.y + margin + rng:random() * (self.bounds.height - margin * 2)
    end

    -- Create pickup
    local pickup = {
        x = x,
        y = y,
        age = 0,
        bob_offset = 0,
        pulse = 1,
        rotation = 0,
        value = self.value
    }

    table.insert(self.active_pickups, pickup)
    self.total_spawned = self.total_spawned + 1

    if self.on_spawn then
        self.on_spawn(pickup)
    end

    print(string.format("[WaterPickup] Spawned at %.0f, %.0f", x, y))
    return true
end

-- Check collection against a point (player position)
function WaterPickup:checkCollection(player_x, player_y)
    for i = #self.active_pickups, 1, -1 do
        local pickup = self.active_pickups[i]

        local dx = player_x - pickup.x
        local dy = player_y - (pickup.y + pickup.bob_offset)
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < self.collection_radius then
            self:collect(i)
            return true, pickup.value
        end
    end
    return false, 0
end

-- Collect a pickup
function WaterPickup:collect(index)
    local pickup = self.active_pickups[index]
    if not pickup then return end

    self.total_collected = self.total_collected + 1

    -- Add to player data
    if self.player_data then
        self.player_data:addWater(pickup.value)
    end

    -- Callback
    if self.on_collect then
        self.on_collect(pickup, self.player_data)
    end

    -- Remove
    table.remove(self.active_pickups, index)

    print(string.format("[WaterPickup] Collected! Value: %d", pickup.value))
end

-- Despawn a pickup
function WaterPickup:despawn(index, reason)
    local pickup = self.active_pickups[index]
    if not pickup then return end

    if self.on_despawn then
        self.on_despawn(pickup, reason)
    end

    table.remove(self.active_pickups, index)
end

-- Clear all pickups
function WaterPickup:clear()
    self.active_pickups = {}
    self.spawn_timer = 0
end

-- Get active pickup count
function WaterPickup:getActiveCount()
    return #self.active_pickups
end

-- Draw all active pickups
function WaterPickup:draw()
    for _, pickup in ipairs(self.active_pickups) do
        self:drawPickup(pickup)
    end
end

-- Draw a single pickup
function WaterPickup:drawPickup(pickup)
    local x = pickup.x
    local y = pickup.y + pickup.bob_offset
    local size = self.size * pickup.pulse

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(pickup.rotation)

    -- Glow effect
    love.graphics.setColor(self.glow_color)
    love.graphics.circle("fill", 0, 0, size * 1.5)

    -- Main drop shape (teardrop)
    love.graphics.setColor(self.color)

    -- Simple circle for now (you can make this fancier)
    love.graphics.circle("fill", 0, 0, size * 0.6)

    -- Highlight
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.circle("fill", -size * 0.15, -size * 0.15, size * 0.2)

    love.graphics.pop()

    -- Lifetime indicator (optional - shows when about to despawn)
    local remaining = self.lifetime - pickup.age
    if remaining < 3 then
        local alpha = (math.sin(pickup.age * 10) + 1) / 2
        love.graphics.setColor(1, 1, 1, alpha * 0.5)
        love.graphics.circle("line", x, y + pickup.bob_offset, size * 0.8)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return WaterPickup
```

---

## Step 3: Integrate into BaseGame

Open `src/games/base_game.lua` and add water pickup support.

### Add require at top:
```lua
local WaterPickup = require('src.utils.game_components.water_pickup')
```

### In init, create the water pickup system:
```lua
function BaseGame:init(game_data, cheats, di, variant_override)
    -- ... existing code ...

    -- Universal water pickup system
    self:setupWaterPickup()
end

function BaseGame:setupWaterPickup()
    -- Get spawn chance from config (can be modified by skill tree later)
    local base_chance = 0.02
    if self.di and self.di.config and self.di.config.water then
        base_chance = self.di.config.water.spawn_chance or base_chance
    end

    self.water_pickup = WaterPickup:new({
        spawn_chance = base_chance,
        spawn_mode = "random",  -- Games trigger spawn attempts
        lifetime = 12,
        on_collect = function(pickup, player_data)
            self:onWaterCollected(pickup)
        end,
        on_spawn = function(pickup)
            self:onWaterSpawned(pickup)
        end
    })

    -- Wire up dependencies
    if self.di then
        self.water_pickup:setPlayerData(self.di.playerData)
    end
    if self.rng then
        self.water_pickup:setRNG(self.rng)
    end
end

function BaseGame:onWaterCollected(pickup)
    -- Override in games for custom effects
    -- Default: flash and sound
    if self.visual_effects then
        self.visual_effects:flash({
            color = {0.3, 0.6, 1.0, 0.4},
            duration = 0.3,
            mode = "fade_out"
        })
    end

    if self.di and self.di.audioManager then
        self.di.audioManager:playSound("generic", "water_collect")
    end

    -- Maybe show popup
    if self.popup_manager then
        self.popup_manager:add(pickup.x, pickup.y, "+1 💧", {0.3, 0.6, 1.0})
    end
end

function BaseGame:onWaterSpawned(pickup)
    -- Override in games for custom effects
    -- Default: subtle notification
end
```

### In update, update water pickup:
```lua
function BaseGame:updateGameLogic(dt)
    -- ... existing code ...

    -- Update water pickup
    if self.water_pickup then
        self.water_pickup:update(dt)

        -- Check collection (games should call this with player position)
        -- This is a fallback for games that don't override
    end
end
```

### In draw, draw water pickup:
```lua
function BaseGame:draw()
    -- ... existing draw code ...

    -- Draw water pickups (usually games draw these in their view)
    if self.water_pickup then
        self.water_pickup:draw()
    end
end
```

---

## Step 4: Trigger Water Spawns in Games

Games should trigger spawn attempts at interesting moments. Open a game like `coin_flip.lua`:

```lua
function CoinFlip:onCorrectFlip()
    -- ... existing code ...

    -- Chance for water on streak milestones
    if self.current_streak > 0 and self.current_streak % 5 == 0 then
        if self.water_pickup then
            -- Higher chance on streaks
            local old_chance = self.water_pickup.spawn_chance
            self.water_pickup.spawn_chance = 0.15  -- 15% on streak milestone
            self.water_pickup:trySpawn()
            self.water_pickup.spawn_chance = old_chance
        end
    end
end
```

For action games like Snake or Space Shooter:

```lua
function SpaceShooter:onEnemyKilled(enemy)
    -- ... existing code ...

    -- Small chance to spawn water at enemy death location
    if self.water_pickup then
        self.water_pickup:trySpawn(enemy.x, enemy.y)
    end
end
```

---

## Step 5: Check Collection in Games

Each game needs to check water collection based on its player position:

### For games with player entity:
```lua
function Snake:updateGameLogic(dt)
    -- ... existing code ...

    -- Check water collection
    if self.water_pickup and self.snake_head then
        self.water_pickup:checkCollection(self.snake_head.x, self.snake_head.y)
    end
end
```

### For games without direct player (like Coin Flip):
```lua
-- Water spawns in the play area, player "collects" by clicking near it
-- Or water auto-collects after a delay
function CoinFlip:updateGameLogic(dt)
    -- ... existing code ...

    -- Auto-collect water after 2 seconds (for non-movement games)
    if self.water_pickup then
        for _, pickup in ipairs(self.water_pickup.active_pickups) do
            if pickup.age > 2 then
                -- Auto-collect
                local w, h = love.graphics.getDimensions()
                self.water_pickup:checkCollection(pickup.x, pickup.y)
            end
        end
    end
end
```

---

## Step 6: Set Bounds When Play Area is Set

```lua
function BaseGame:setPlayArea(width, height)
    self.viewport_width = width
    self.viewport_height = height

    -- Update water pickup bounds
    if self.water_pickup then
        self.water_pickup:setBounds(0, 0, width, height)
    end
end
```

---

## Step 7: Add Config Options

In `src/config.lua`:

```lua
water = {
    spawn_chance = 0.02,      -- Base 2% chance when triggered
    lifetime = 12,            -- Seconds before despawn
    value = 1,                -- Water per pickup

    -- Skill tree could modify these
    spawn_chance_bonus = 0,   -- Added to base chance
    value_multiplier = 1,     -- Multiply value
    magnet_radius = 0,        -- Auto-collect radius (0 = disabled)
}
```

---

## Step 8: Display Water Count in UI

Somewhere in your desktop/HUD, show the water count:

```lua
-- In a UI component
local water = self.di.playerData:getWater()
love.graphics.setColor(0.3, 0.6, 1.0)
love.graphics.print("💧 " .. water, x, y)
```

---

## What Water Does (Ideas for Later)

The tutorial stops here for the plane - but here are ideas for what water could do:

### Option A: Skill Tree Currency
- Spend water to unlock permanent upgrades
- "Water Magnet" - auto-collect radius
- "Refreshing" - water heals 1 HP
- "Abundance" - +50% water spawn chance

### Option B: Multiplier Boost
- Each water gives temporary token multiplier
- Stacks up to 5x
- Decays over time or games

### Option C: Neural Core Fuel
- Water is alternate way to feed Neural Core
- More efficient than tokens but rarer
- Needed for certain upgrades

### Option D: Meta Currency
- Buy cosmetics
- Unlock new variant types
- Reveal hidden games

### Option E: The Weird Option (Fits your fiction)
- Water is "coolant" for the system
- Collecting it prevents... something
- Ties into the AI fiction layer

---

## Testing Checklist

- [ ] Water spawns (check console for "[WaterPickup] Spawned")
- [ ] Water animates (bobbing, pulsing, glowing)
- [ ] Water can be collected
- [ ] Collection adds to player data
- [ ] Collection shows visual feedback
- [ ] Water despawns after timeout
- [ ] Water persists across sessions (save/load)
- [ ] Different games trigger spawns appropriately

---

## Key Patterns Learned

- **Universal systems:** Components that work across all games
- **Event-driven design:** Spawn triggers, collection callbacks
- **Persistent resources:** Saved to player data, not game state
- **Config-driven:** Spawn rates etc. in config for easy tuning
- **Deterministic spawning:** Using game RNG for demo compatibility
