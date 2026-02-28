# Water Currency System
Phased plan for adding a rare universal pickup ("Water") that spawns across all minigames and feeds into CheatEngine upgrades.

## Design Overview

**What is Water?**
- Rare universal pickup that can appear in any minigame during manual play
- Secondary currency separate from tokens (tokens = game output, water = rare resource)
- Spent on two things: per-game CheatEngine upgrades and a universal CheatEngine skill tree
- Thematically: player is pouring water into the AI to make it cheat harder

**Why Water Matters**
- Tokens are predictable and farmable (especially via VMs). Water is rare and lucky — two different dopamine systems
- VMs produce tokens passively. Water requires manual play, keeping the player's hands on the keyboard even deep into automation phase
- Creates meaningful allocation decisions: dump water into one golden goose variant, or spread across many?
- The AI can farm tokens on its own through VMs. But water — the real physical resource — requires a human to go get it

**Spending: Two Layers**
1. **Per-game CheatEngine levels** (5 levels per game): Boost a specific variant's CE capabilities (more budget, lower costs, higher param caps)
2. **Universal CheatEngine skill tree**: Broad upgrades like token multipliers by game category, CE budget increases, water spawn rate bonuses, param cost reductions

**Spawn Behavior**
- Random timer-based spawning — just appears while playing, like a golden cookie
- Not tied to game events (kills, streaks, etc.) — purely random
- Manual play only — VMs get zero or heavily penalized rates
- Spawns as a collectible entity at a random position within the play area
- Despawns after a timeout if not collected
- Visual: Distinct animated blue droplet with glow, bobbing, pulsing
- Audio: Satisfying collection sound + popup

**Collection Per Game Type**
- Movement games (dodge, snake, space_shooter, breakout, raycaster): Player moves to it and touches it
- Non-movement games (coin_flip, rps, memory_match, hidden_object): Auto-collects after short delay

---

## Phase 1: Player Data + Config
**Goal**: Water exists as a tracked, saved resource. No spawning or spending yet.

### Tasks
1. **Add water fields to PlayerData**
   - `self.water = 0` (current spendable balance)
   - `self.water_lifetime = 0` (total ever collected, for stats)
   - Add `getWater()`, `addWater(amount)`, `spendWater(amount)` methods
   - Include in `serialize()` / `deserialize()` for save/load

2. **Add water config to `src/config.lua`**
   ```
   water = {
       spawn_chance = 0.02,        -- Base 2% per trigger event
       spawn_interval = 30,        -- For timed spawn mode (seconds)
       lifetime = 12,              -- Seconds before despawn
       value = 1,                  -- Water per pickup
       vm_drop_rate = 0,           -- Multiplier for VM play (0 = disabled)
       collection_radius = 20,     -- Pickup radius in pixels
   }
   ```

3. **Add per-game CE upgrade config**
   ```
   water_upgrades = {
       max_level = 5,
       costs = {10, 25, 50, 100, 200},  -- Water cost per level
       budget_bonus_per_level = 50,       -- Extra CE budget per level
       cost_reduction_per_level = 0.05,   -- 5% cheaper params per level
   }
   ```

### Expected Outcome
- Water count saved/loaded across sessions
- Config values ready for all subsequent phases
- No visible gameplay change yet

### Testing (User)
### AI Notes
### Status
Not started

---

## Phase 2: WaterPickup Component
**Goal**: Create the universal pickup component that handles spawning, animation, collection, and despawning.

### Tasks
1. **Create `src/utils/game_components/water_pickup.lua`**
   - `WaterPickup:init(config)` — spawn_chance, lifetime, value, collection_radius, callbacks
   - `WaterPickup:update(dt)` — age pickups, bob/pulse animation, despawn on timeout
   - `WaterPickup:trySpawn(x, y)` — roll for spawn, create pickup at position (or random within bounds)
   - `WaterPickup:checkCollection(player_x, player_y)` — distance check, trigger collection
   - `WaterPickup:autoCollect()` — for non-movement games, collect oldest active pickup
   - `WaterPickup:setBounds(x, y, w, h)` — play area for random positioning
   - `WaterPickup:setRNG(rng)` — use game's RNG for demo determinism
   - `WaterPickup:clear()` — remove all active pickups
   - `WaterPickup:getActivePickups()` — for rendering by views
   - Max 1 active pickup at a time (configurable)
   - Callbacks: `on_collect(pickup)`, `on_spawn(pickup)`, `on_despawn(pickup)`

2. **Component does NOT render** — views handle drawing (MVC pattern)

### Expected Outcome
- Standalone component with no dependencies on specific games
- Uses game RNG for deterministic demo compatibility
- Ready to be wired into BaseGame

### Testing (User)
### AI Notes
### Status
Not started

---

## Phase 3: BaseGame Integration
**Goal**: Wire WaterPickup into BaseGame so all 9 games get water support automatically.

### Tasks
1. **Add to BaseGame:init()**
   - Create WaterPickup instance from config
   - Wire `player_data`, `rng`, bounds
   - Set `on_collect` callback to call `self:onWaterCollected(pickup)`

2. **Add BaseGame:onWaterCollected(pickup)**
   - Call `self.di.playerData:addWater(pickup.value)`
   - Flash effect via visual_effects (blue flash)
   - Popup "+1 Water" via popup_manager
   - Play collection sound

3. **Add to BaseGame:setPlayArea()**
   - Update water_pickup bounds when play area changes

4. **Add to BaseGame update path**
   - `self.water_pickup:update(dt)` in base update
   - Games with player entities call `checkCollection(px, py)` in their updateGameLogic
   - Games without direct movement use `autoCollect()` on correct actions

5. **Disable for VM playback**
   - Check `self.is_demo_playback` or similar flag
   - If VM, multiply spawn_chance by `config.water.vm_drop_rate` (default 0)

### Expected Outcome
- Water pickups can spawn and be collected in any game
- Collection persists to player data
- VMs don't generate water (or barely any)

### Testing (User)
### AI Notes
### Status
Not started

---

## Phase 4: Random Spawn Logic
**Goal**: Water spawns randomly on a timer during manual play. No event triggers — it just appears like a golden cookie.

### Tasks
1. **Timer-based spawning in BaseGame update**
   - Tick a spawn timer every frame during active gameplay
   - Every N seconds (configurable interval), roll against spawn_chance
   - On success, call `water_pickup:trySpawn()` at a random position within play area
   - No per-game hooks needed — it's entirely in BaseGame

2. **Collection per game type**
   - Movement games (dodge, snake, space_shooter, breakout, raycaster): Player must move to it and touch it
   - Non-movement games (coin_flip, rps, memory_match, hidden_object): Auto-collect after a short delay (player can't move to it)

3. **Spawn tuning config**
   - `spawn_interval` — how often to roll (e.g. every 30 seconds)
   - `spawn_chance` — probability per roll (e.g. 0.5 = 50% chance each interval)
   - Combined: roughly one water per minute at default settings (tuning TBD)
   - No per-game or per-event multipliers for now

### Expected Outcome
- Water just appears randomly while playing any game
- Player doesn't need to do anything special to trigger it
- Movement games reward awareness (go grab it before it despawns)
- Non-movement games don't penalize the player for not having a character to move

### Testing (User)
### AI Notes
### Status
Not started

---

## Phase 5: Water Rendering
**Goal**: Water pickups are visible and animated in all game views.

### Tasks
1. **Add water drawing to GameBaseView or each game view**
   - Get active pickups from `game.water_pickup:getActivePickups()`
   - Draw each: blue teardrop/circle with glow, bobbing animation, pulsing size
   - Blink/flash when about to despawn (last 3 seconds)
   - Draw on top of game entities but below HUD/overlay

2. **Collection visual feedback**
   - Blue screen flash (already handled by BaseGame callback)
   - Particle burst at collection point
   - "+1 Water" popup (already handled by BaseGame callback)

3. **HUD water display** (optional, small)
   - Show current water count somewhere in game HUD or desktop taskbar
   - Blue droplet icon + count

### Expected Outcome
- Water pickups are visually distinct and satisfying to see/collect
- Player never misses that water spawned (glow + animation draws eye)

### Testing (User)
### AI Notes
### Status
Not started

---

## Phase 6: Per-Game CheatEngine Upgrades
**Goal**: Spend water to upgrade a specific game's CheatEngine capabilities (5 levels).

### Tasks
1. **Add to PlayerData**
   - `self.water_upgrades = {}` — `{[game_id] = level}` table
   - `getWaterUpgradeLevel(game_id)` — returns 0-5
   - `upgradeGameWithWater(game_id)` — spend water, increment level

2. **Add upgrade UI to CheatEngine**
   - Show current water upgrade level for selected game (e.g. "CE Level: 2/5")
   - Show upgrade cost and button if affordable
   - Show what the upgrade gives (e.g. "+50 budget, -5% param costs")

3. **Apply upgrade effects in CheatSystem**
   - When calculating budget: `base_budget + (level * budget_bonus_per_level)`
   - When calculating costs: `cost * (1 - level * cost_reduction_per_level)`
   - Maybe: unlock hidden params at higher levels, expand param ranges

4. **Save/load water upgrade levels**

### Expected Outcome
- Players can pour water into specific games to boost their CheatEngine
- Creates "golden goose" strategy — find a good variant, invest water, cheat harder, automate
- Two players at the same Neural Core level have different CE power per game

### Testing (User)
### AI Notes
### Status
Not started

---

## Phase 7: Universal CheatEngine Skill Tree
**Goal**: Spend water on broad upgrades that affect all games.

### Tasks
1. **Design skill tree nodes** (examples, TBD with playtesting)
   - Token multiplier by category (e.g. "1.1x tokens from dodge games")
   - Global CE budget increase
   - Water spawn rate bonus
   - Param cost reduction (global)
   - Unlock new param ranges (extend caps)

2. **Add skill tree data structure to PlayerData**
   - `self.water_skill_tree = {}` — `{[node_id] = level}` table
   - Getter/setter methods

3. **Create skill tree UI**
   - Accessible from CheatEngine window (tab or sub-panel)
   - Show nodes, costs, current levels, effects
   - Spend water to level up nodes

4. **Apply skill tree effects**
   - Hook into CheatSystem cost calculations, budget calculations
   - Hook into token reward calculations for category multipliers
   - Hook into water spawn config for spawn rate bonuses

### Expected Outcome
- Long-term water sink that's always useful
- Strategic depth: invest in per-game or universal upgrades?
- Category multipliers encourage playing diverse game types

### Testing (User)
### AI Notes
### Status
Not started

---

## File Summary

### New Files
| File | Phase | Purpose |
|------|-------|---------|
| `src/utils/game_components/water_pickup.lua` | 2 | Universal pickup component |

### Modified Files
| File | Phases | Changes |
|------|--------|---------|
| `src/models/player_data.lua` | 1, 6, 7 | Water balance, upgrade levels, skill tree |
| `src/config.lua` | 1 | Water config, upgrade costs |
| `src/games/base_game.lua` | 3 | Water pickup creation, collection, update |
| `src/games/*.lua` (select) | 4 | Collection method (auto-collect for non-movement games) |
| `src/games/views/game_base_view.lua` | 5 | Water rendering |
| `src/models/cheat_system.lua` | 6, 7 | Apply upgrade effects to budget/costs |
| `src/states/cheat_engine_state.lua` | 6, 7 | Upgrade UI, skill tree UI |
| `src/views/cheat_engine_view.lua` | 6, 7 | Render upgrade UI, skill tree |

---

## Phase Order Rationale
1. **Player Data + Config** — Foundation, everything reads from here
2. **WaterPickup Component** — Standalone, no game dependencies
3. **BaseGame Integration** — Wire component into all games at once
4. **Random Spawn Logic** — Timer-based spawning + collection method per game type
5. **Water Rendering** — Make it visible and satisfying
6. **Per-Game CE Upgrades** — First spending mechanism (core loop)
7. **Universal Skill Tree** — Second spending mechanism (long-term sink)

Phases 1-5 are the "earn" side. Phases 6-7 are the "spend" side. The game is playable and water is collectible after phase 5 even without spending mechanics.
