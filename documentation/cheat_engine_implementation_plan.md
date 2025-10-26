# CheatEngine Implementation Plan: Dynamic Parameter Modification

## Overview

Implement a CheatEngine system that dynamically exposes ALL JSON parameters from game variants for modification. The system must follow MVC architecture, use dependency injection, and externalize all configuration to `config.lua`.

**Core Principles:**
1. **Dynamic parameter exposure:** If a parameter exists in a variant's JSON (e.g., `dodge_variants.json`), it can be modified in CheatEngine. If it doesn't exist, it's not shown.
2. **Existing unlock system:** CheatEngine uses the same unlock rules as the rest of the game. Only games that are already unlocked (`player_data:isGameUnlocked(game_id)`) appear in the CheatEngine game list.
3. **Testing-friendly defaults:** Initial configuration has near-infinite budget (999,999,999) and very low costs to allow rapid testing and iteration.

---

## System Architecture

### Data Flow
```
1. Player selects game in CheatEngine
2. CheatEngineState reads variant JSON for that game
3. Builds modification options dynamically from JSON keys
4. PlayerData stores modifications per game
5. When game launches, modifications applied to variant data
6. Game uses modified parameters
```

### Key Components

**Model Layer:**
- `CheatSystem` - Manages cheat budget, pricing rules, modification operations
- `PlayerData` - Stores per-game modifications, cheat budget
- `GameData` - Provides variant JSON data

**Controller Layer:**
- `CheatEngineState` - Mediates between models and view, handles modification logic

**View Layer:**
- `CheatEngineView` - Displays game list, parameters, modification UI

---

## Phase 1: Configuration & Data Structure

**Goal:** Set up all configuration in `config.lua` and define data structures

### 1.1 Add CheatEngine Config to `config.lua`

**Location:** `src/config.lua`

Add new section:
```lua
-- CheatEngine Configuration
cheat_engine = {
    -- Starting budget for testing (set VERY high for testing)
    default_budget = 999999999, -- Nearly infinite for testing

    -- Budget upgrades (costs to increase budget cap)
    budget_upgrades = {
        { cost = 2500, new_cap = 1000 },
        { cost = 10000, new_cap = 5000 },
        { cost = 50000, new_cap = 25000 },
        { cost = 250000, new_cap = 100000 },
        { cost = 1000000, new_cap = 500000 }
    },

    -- Parameter modification pricing
    -- Base cost multipliers by parameter type
    parameter_costs = {
        -- Numeric parameters
        numeric = {
            base_cost = 100,
            exponential_scale = 1.5, -- cost = base * (scale ^ modifications_made)
            step_costs = {
                -- Cost per step size
                [1] = 1.0,    -- +/- 1: normal cost
                [5] = 0.9,    -- +/- 5: 10% cheaper per unit
                [10] = 0.8,   -- +/- 10: 20% cheaper per unit
                [100] = 0.6,  -- +/- 100: 40% cheaper per unit
                ["max"] = 2.0 -- Set to max/min: 2x cost
            }
        },

        -- Boolean parameters
        boolean = {
            base_cost = 500,
            exponential_scale = 1.0 -- Flat cost (no scaling)
        },

        -- String/enum parameters (e.g., victory_condition: "time" vs "dodge_count")
        enum = {
            base_cost = 5000,
            exponential_scale = 1.0
        },

        -- Array parameters (enemies, holes)
        array = {
            base_cost = 1000,
            exponential_scale = 1.3
        }
    },

    -- Parameter-specific overrides (optional)
    -- Use this to make specific params more/less expensive
    parameter_overrides = {
        victory_condition = { base_cost = 5000 }, -- Expensive to change
        lives = { base_cost = 100 },
        victory_limit = { base_cost = 150 },
        movement_speed = { base_cost = 200 },
        player_size = { base_cost = 500 },
        -- Add more as needed
    },

    -- Which parameters should be hidden/locked
    -- (Empty for now - expose everything)
    hidden_parameters = {
        -- "clone_index", -- Don't allow editing clone_index
        -- "name", -- Don't allow editing name
    },

    -- Special unlocks (gate certain modifications behind progression)
    -- NOTE: Not implemented initially - using existing game unlock system
    -- Only unlocked games appear in CheatEngine (player_data:isGameUnlocked)
    unlockable_modifications = {}
},
```

### 1.2 Define Modification Data Structure

**Location:** `src/models/player_data.lua`

Update `cheat_engine_data` structure:
```lua
-- Per-game cheat data structure:
-- {
--   [game_id] = {
--     budget_spent = 0,
--     modifications = {
--       lives = { original = 10, modified = 25, cost_spent = 1500 },
--       victory_limit = { original = 30, modified = 10, cost_spent = 800 },
--       movement_speed = { original = 300, modified = 450, cost_spent = 600 }
--     }
--   }
-- }
```

Add helper methods:
```lua
function PlayerData:getCheatBudget()
    return self.cheat_budget or Config.cheat_engine.default_budget
end

function PlayerData:getGameModifications(game_id)
    if not self.cheat_engine_data[game_id] then
        return {}
    end
    return self.cheat_engine_data[game_id].modifications or {}
end

function PlayerData:getGameBudgetSpent(game_id)
    if not self.cheat_engine_data[game_id] then
        return 0
    end
    return self.cheat_engine_data[game_id].budget_spent or 0
end
```

---

## Phase 2: CheatSystem Model - Core Logic

**Goal:** Implement the business logic for parameter modification, pricing, and budget management

### 2.1 Rewrite `CheatSystem` Model

**Location:** `src/models/cheat_system.lua`

**Dependencies:** `config` (via DI)

**Key Methods:**

```lua
function CheatSystem:init(config)
    self.config = config
    self.cheat_config = config.cheat_engine
end

-- Get all modifiable parameters from a variant's JSON
function CheatSystem:getModifiableParameters(variant_data)
    -- Returns array of parameter definitions
    -- { key = "lives", type = "number", current_value = 10, original_value = 10 }
end

-- Calculate cost for a modification
function CheatSystem:calculateModificationCost(param_key, param_type, current_value, new_value, modifications_count)
    -- Uses config.cheat_engine.parameter_costs
    -- Applies exponential scaling based on modifications_count
    -- Returns cost in credits
end

-- Check if modification is allowed (budget, unlocks)
function CheatSystem:canModify(player_data, game_id, param_key, new_value)
    -- Returns: { allowed = true/false, reason = "string" }
end

-- Apply a modification
function CheatSystem:applyModification(player_data, game_id, param_key, param_type, original_value, new_value)
    -- Calculates cost
    -- Deducts from budget
    -- Stores in player_data.cheat_engine_data
    -- Returns: { success = true/false, cost = number, new_budget = number }
end

-- Reset a single parameter
function CheatSystem:resetParameter(player_data, game_id, param_key)
    -- Refunds cost (partial or full based on config)
    -- Removes modification
end

-- Reset all modifications for a game
function CheatSystem:resetAllModifications(player_data, game_id)
    -- Refunds all costs
    -- Clears modifications
end

-- Get current modified variant data
function CheatSystem:getModifiedVariant(variant_data, modifications)
    -- Deep copies variant_data
    -- Applies all modifications from player_data
    -- Returns modified variant
end
```

**Implementation Details:**

```lua
function CheatSystem:getModifiableParameters(variant_data)
    local params = {}
    local hidden = self.cheat_config.hidden_parameters

    for key, value in pairs(variant_data) do
        -- Skip hidden parameters
        local is_hidden = false
        for _, hidden_key in ipairs(hidden) do
            if hidden_key == key then
                is_hidden = true
                break
            end
        end

        if not is_hidden then
            local param_type = type(value)
            if param_type == "number" then
                table.insert(params, {
                    key = key,
                    type = "number",
                    value = value,
                    original = value
                })
            elseif param_type == "boolean" then
                table.insert(params, {
                    key = key,
                    type = "boolean",
                    value = value,
                    original = value
                })
            elseif param_type == "string" then
                table.insert(params, {
                    key = key,
                    type = "string",
                    value = value,
                    original = value
                })
            elseif param_type == "table" then
                -- Array parameters (enemies, holes)
                table.insert(params, {
                    key = key,
                    type = "array",
                    value = value,
                    original = value
                })
            end
        end
    end

    -- Sort alphabetically
    table.sort(params, function(a, b) return a.key < b.key end)

    return params
end
```

```lua
function CheatSystem:calculateModificationCost(param_key, param_type, current_value, new_value, modifications_count, step_size)
    local costs = self.cheat_config.parameter_costs
    local overrides = self.cheat_config.parameter_overrides

    -- Get base cost for this parameter type
    local base_cost = costs[param_type].base_cost
    local exp_scale = costs[param_type].exponential_scale

    -- Apply override if exists
    if overrides[param_key] then
        if overrides[param_key].base_cost then
            base_cost = overrides[param_key].base_cost
        end
    end

    -- Apply exponential scaling based on modification count
    local scaled_cost = base_cost * (exp_scale ^ modifications_count)

    -- For numeric types, apply step cost multiplier
    if param_type == "number" and step_size then
        local step_multiplier = costs.numeric.step_costs[step_size] or 1.0
        scaled_cost = scaled_cost * step_multiplier
    end

    return math.floor(scaled_cost)
end
```

### 2.2 Update PlayerData Integration

**Location:** `src/models/player_data.lua`

Add fields:
```lua
function PlayerData:init(statistics_instance, di)
    -- ... existing code ...

    self.cheat_budget = di.config.cheat_engine.default_budget
    self.cheat_engine_data = {}
    -- Structure: [game_id] = { budget_spent = 0, modifications = {} }
end
```

Add methods:
```lua
function PlayerData:initGameCheatData(game_id)
    if not self.cheat_engine_data[game_id] then
        self.cheat_engine_data[game_id] = {
            budget_spent = 0,
            modifications = {}
        }
    end
end

function PlayerData:applyCheatModification(game_id, param_key, original_value, new_value, cost)
    self:initGameCheatData(game_id)

    local game_data = self.cheat_engine_data[game_id]

    -- Store modification
    game_data.modifications[param_key] = {
        original = original_value,
        modified = new_value,
        cost_spent = cost
    }

    -- Update total budget spent for this game
    game_data.budget_spent = game_data.budget_spent + cost

    -- Note: Budget is GLOBAL, not per-game
    -- Budget tracking is informational only
end

function PlayerData:removeCheatModification(game_id, param_key)
    if not self.cheat_engine_data[game_id] then return 0 end

    local game_data = self.cheat_engine_data[game_id]
    local mod = game_data.modifications[param_key]

    if not mod then return 0 end

    local refund = mod.cost_spent
    game_data.modifications[param_key] = nil
    game_data.budget_spent = game_data.budget_spent - refund

    return refund
end

function PlayerData:getAvailableBudget(game_id)
    local spent = self:getGameBudgetSpent(game_id)
    return self.cheat_budget - spent
end
```

---

## Phase 3: CheatEngineState - Controller Logic

**Goal:** Implement the controller that mediates between CheatSystem, PlayerData, and the view

### 3.1 Update CheatEngineState

**Location:** `src/states/cheat_engine_state.lua`

**New State:**
```lua
function CheatEngineState:init(player_data, game_data, state_machine, save_manager, cheat_system, di)
    -- ... existing init ...

    self.selected_game_id = nil
    self.selected_game = nil
    self.selected_variant = nil -- NEW: The actual variant JSON data

    self.modifiable_params = {} -- NEW: Array of parameter definitions
    self.current_modifications = {} -- NEW: Current modifications for selected game

    self.param_scroll_offset = 0
    self.selected_param_index = 1
    self.step_size = 1 -- Default step size for modifications
end
```

**NOTE:** For now, CheatEngine uses existing unlock rules:
- Only show games that are unlocked (`player_data:isGameUnlocked(game_id)`)
- No additional CheatEngine-specific unlocks
- Filter game list to only show unlocked games in `enter()` method

**Key Methods:**

```lua
function CheatEngineState:selectGame(game_id)
    self.selected_game_id = game_id
    self.selected_game = self.game_data:getGame(game_id)

    -- Load variant data
    self.selected_variant = self:loadVariantData(game_id)

    -- Get current modifications from player_data
    self.current_modifications = self.player_data:getGameModifications(game_id)

    -- Build modifiable parameters list
    self.modifiable_params = self.cheat_system:getModifiableParameters(self.selected_variant)

    -- Apply current modifications to displayed values
    for _, param in ipairs(self.modifiable_params) do
        if self.current_modifications[param.key] then
            param.value = self.current_modifications[param.key].modified
        end
    end

    self.selected_param_index = 1
    self.param_scroll_offset = 0
end

function CheatEngineState:loadVariantData(game_id)
    -- Determine which variant file to load based on game_id
    -- e.g., "dodge_1" -> "dodge_variants.json", clone_index 0
    -- e.g., "dodge_42" -> "dodge_variants.json", clone_index 41

    local base_name, clone_number = game_id:match("^(.-)_(%d+)$")
    if not base_name or not clone_number then
        print("Error: Invalid game_id format: " .. game_id)
        return {}
    end

    local clone_index = tonumber(clone_number) - 1 -- Convert to 0-indexed
    local variant_file = "variants/" .. base_name .. "_variants.json"
    local file_path = Paths.assets.data .. variant_file

    local read_ok, contents = pcall(love.filesystem.read, file_path)
    if not read_ok or not contents then
        print("Error: Could not read " .. file_path)
        return {}
    end

    local decode_ok, variants = pcall(json.decode, contents)
    if not decode_ok or not variants then
        print("Error: Could not decode " .. file_path)
        return {}
    end

    -- Find variant with matching clone_index
    for _, variant in ipairs(variants) do
        if variant.clone_index == clone_index then
            return variant
        end
    end

    print("Error: Could not find variant with clone_index " .. clone_index .. " in " .. file_path)
    return {}
end

function CheatEngineState:modifyParameter(param_key, new_value, step_size)
    if not self.selected_game_id then return end

    local param = nil
    for _, p in ipairs(self.modifiable_params) do
        if p.key == param_key then
            param = p
            break
        end
    end

    if not param then return end

    -- Check if allowed
    local can_modify = self.cheat_system:canModify(
        self.player_data,
        self.selected_game_id,
        param_key,
        new_value
    )

    if not can_modify.allowed then
        print("Cannot modify: " .. can_modify.reason)
        return
    end

    -- Calculate cost
    local modifications_count = 0
    for _ in pairs(self.current_modifications) do
        modifications_count = modifications_count + 1
    end

    local cost = self.cheat_system:calculateModificationCost(
        param_key,
        param.type,
        param.value,
        new_value,
        modifications_count,
        step_size
    )

    -- Check budget
    local available = self.player_data:getAvailableBudget(self.selected_game_id)
    if cost > available then
        print("Insufficient budget. Need: " .. cost .. ", Have: " .. available)
        return
    end

    -- Apply modification
    local result = self.cheat_system:applyModification(
        self.player_data,
        self.selected_game_id,
        param_key,
        param.type,
        param.original,
        new_value
    )

    if result.success then
        -- Update local state
        param.value = new_value
        self.current_modifications = self.player_data:getGameModifications(self.selected_game_id)

        -- Save
        self.save_manager:savePlayerData(self.player_data)

        print("Modified " .. param_key .. " to " .. tostring(new_value) .. " for " .. cost .. " credits")
    end
end

function CheatEngineState:resetParameter(param_key)
    if not self.selected_game_id then return end

    local refund = self.player_data:removeCheatModification(self.selected_game_id, param_key)

    -- Update local state
    for _, param in ipairs(self.modifiable_params) do
        if param.key == param_key then
            param.value = param.original
            break
        end
    end

    self.current_modifications = self.player_data:getGameModifications(self.selected_game_id)
    self.save_manager:savePlayerData(self.player_data)

    print("Reset " .. param_key .. ", refunded " .. refund .. " credits")
end

function CheatEngineState:launchGame()
    if not self.selected_game_id then return nil end

    -- Get modified variant
    local modified_variant = self.cheat_system:getModifiedVariant(
        self.selected_variant,
        self.current_modifications
    )

    -- Launch minigame with modified variant
    return {
        type = "launch_program",
        program_id = "minigame_runner",
        args = {
            game_id = self.selected_game_id,
            variant = modified_variant -- Pass modified variant
        }
    }
end
```

### 3.2 Handle Input for Modifications

```lua
function CheatEngineState:keypressed(key)
    -- ... existing navigation code ...

    if key == 'left' or key == 'a' then
        -- Decrease parameter by current step
        self:decrementParameter()
    elseif key == 'right' or key == 'd' then
        -- Increase parameter by current step
        self:incrementParameter()
    elseif key == '1' then
        self.step_size = 1
    elseif key == '2' then
        self.step_size = 5
    elseif key == '3' then
        self.step_size = 10
    elseif key == '4' then
        self.step_size = 100
    elseif key == 'm' then
        self.step_size = "max"
    elseif key == 'r' then
        -- Reset selected parameter
        local param = self.modifiable_params[self.selected_param_index]
        if param then
            self:resetParameter(param.key)
        end
    elseif key == 'x' then
        -- Reset all parameters
        for _, param in ipairs(self.modifiable_params) do
            self:resetParameter(param.key)
        end
    end
end

function CheatEngineState:incrementParameter()
    if not self.modifiable_params[self.selected_param_index] then return end

    local param = self.modifiable_params[self.selected_param_index]

    if param.type == "number" then
        local step = self.step_size == "max" and 9999 or self.step_size
        local new_value = param.value + step
        self:modifyParameter(param.key, new_value, self.step_size)
    elseif param.type == "boolean" then
        self:modifyParameter(param.key, not param.value, nil)
    end
    -- TODO: Handle string/enum and array types
end

function CheatEngineState:decrementParameter()
    if not self.modifiable_params[self.selected_param_index] then return end

    local param = self.modifiable_params[self.selected_param_index]

    if param.type == "number" then
        local step = self.step_size == "max" and 9999 or self.step_size
        local new_value = param.value - step
        self:modifyParameter(param.key, new_value, self.step_size)
    elseif param.type == "boolean" then
        self:modifyParameter(param.key, not param.value, nil)
    end
end
```

---

## Phase 4: CheatEngineView - UI Implementation

**Goal:** Display the modifiable parameters and modification controls

### 4.1 Update CheatEngineView

**Location:** `src/views/cheat_engine_view.lua`

**Layout:**
```
┌─────────────────────────────────────────────────────┐
│ CheatEngine                              [_][□][X] │
├──────────────┬──────────────────────────────────────┤
│ Game List    │  Parameter Modifications             │
│ (scrollable) │                                      │
│              │  Budget: 999,999,500 / 999,999,999   │
│ Dodge Master │                                      │
│ Dodge Deluxe │  Step Size: [1] [5] [10] [100] [Max]│
│ > Ice Rink   │                                      │
│ ...          │  ┌────────────────────────────────┐  │
│              │  │ Parameter      | Value  | Cost │  │
│              │  ├────────────────────────────────┤  │
│              │  │ lives          | 25     | 150  │  │
│              │  │ movement_speed | 450    | 200  │  │
│              │  │ victory_limit  | 10     | 300  │  │
│              │  │ ...            | ...    | ...  │  │
│              │  └────────────────────────────────┘  │
│              │                                      │
│              │  [←/→] Modify  [R] Reset  [X] Reset All │
│              │  [Enter] Launch Game                │
└──────────────┴──────────────────────────────────────┘
```

**Key Display Elements:**

```lua
function CheatEngineView:drawWindowed(all_games, selected_game_id, modifiable_params, player_data, viewport_width, viewport_height, game_scroll_offset, param_scroll_offset)
    -- Left panel: Game list (reuse existing)
    -- Right panel: Parameter editor

    local split_x = 250

    -- Draw game list
    self:drawGameList(all_games, selected_game_id, game_scroll_offset, split_x, viewport_height)

    -- Draw parameter editor
    self:drawParameterEditor(modifiable_params, player_data, selected_game_id, split_x, viewport_width, viewport_height, param_scroll_offset)
end

function CheatEngineView:drawParameterEditor(params, player_data, game_id, x_offset, viewport_width, viewport_height)
    if not game_id then
        love.graphics.print("Select a game to modify", x_offset + 20, 50)
        return
    end

    -- Budget display
    local budget_total = player_data:getCheatBudget()
    local budget_spent = player_data:getGameBudgetSpent(game_id)
    local budget_available = budget_total - budget_spent

    love.graphics.print("Budget: " .. budget_available .. " / " .. budget_total, x_offset + 20, 30)

    -- Step size selector
    love.graphics.print("Step Size:", x_offset + 20, 60)
    -- Draw step size buttons [1] [5] [10] [100] [Max]

    -- Parameter table
    local table_y = 100
    local row_height = 25
    local visible_rows = math.floor((viewport_height - table_y - 50) / row_height)

    -- Headers
    love.graphics.print("Parameter", x_offset + 20, table_y)
    love.graphics.print("Original", x_offset + 200, table_y)
    love.graphics.print("Modified", x_offset + 280, table_y)
    love.graphics.print("Cost", x_offset + 360, table_y)

    -- Parameter rows
    for i = param_scroll_offset + 1, math.min(#params, param_scroll_offset + visible_rows) do
        local param = params[i]
        local y = table_y + 25 + (i - param_scroll_offset - 1) * row_height

        -- Highlight selected row
        if i == selected_param_index then
            love.graphics.setColor(0.3, 0.3, 0.5)
            love.graphics.rectangle('fill', x_offset + 10, y - 2, viewport_width - x_offset - 20, row_height - 2)
            love.graphics.setColor(1, 1, 1)
        end

        -- Parameter name
        love.graphics.print(param.key, x_offset + 20, y)

        -- Original value
        love.graphics.print(tostring(param.original), x_offset + 200, y)

        -- Modified value (highlight if changed)
        if param.value ~= param.original then
            love.graphics.setColor(0.2, 1.0, 0.2)
        end
        love.graphics.print(tostring(param.value), x_offset + 280, y)
        love.graphics.setColor(1, 1, 1)

        -- Cost (if modified)
        if param.value ~= param.original then
            local mod = current_modifications[param.key]
            if mod then
                love.graphics.print(tostring(mod.cost_spent), x_offset + 360, y)
            end
        end
    end

    -- Controls hint
    love.graphics.print("[←/→] Modify  [R] Reset  [X] Reset All  [Enter] Launch", x_offset + 20, viewport_height - 30)
end
```

---

## Phase 5: Integration & Game Launch

**Goal:** Apply modifications when launching a game

### 5.1 Update MinigameState to Accept Modified Variant

**Location:** `src/states/minigame_state.lua`

```lua
function MinigameState:init(player_data, game_data, state_machine, save_manager, cheat_system, di, args)
    -- ... existing init ...

    -- NEW: Accept variant from args
    if args and args.variant then
        self.variant_override = args.variant
    end
end

function MinigameState:enter(args)
    -- ... existing code ...

    -- Use variant_override if provided, otherwise load default
    local variant = self.variant_override or self:loadDefaultVariant(game_id)

    -- Create game instance with variant
    self.game = self:createGameInstance(game_data, variant)
end
```

### 5.2 Test Modification Flow

**Test Steps:**
1. Launch CheatEngine
2. Select "Dodge Master" (dodge_1)
3. Modify `lives` from 10 to 50 (cost: ~100 credits)
4. Modify `victory_limit` from 30 to 10 (cost: ~150 credits)
5. View budget: 999,999,750 / 999,999,999
6. Launch game
7. Verify game has 50 lives and completes at 10 dodges

---

## Phase 6: Advanced Features (Post-MVP)

### 6.1 Special Parameter Types

**String/Enum Parameters:**
- Detect possible values (e.g., `victory_condition`: "time", "dodge_count")
- Show dropdown or cycle through options
- Higher base cost (5,000 credits)

**Array Parameters:**
- `enemies`: Add/remove enemy types
- `holes_count`: Modify count
- Show expandable list UI

### 6.2 Multiplier Unlocks

**Example:** Dodge Count Multiplier for "boss games"

```lua
-- In config.lua
cheat_engine = {
    special_unlocks = {
        dodge_count_multiplier = {
            cost = 50000,
            applies_to = { "dodge" }, -- game types
            effect = { param = "dodge_count_multiplier", values = { 1, 10, 100, 1000 } }
        }
    }
}
```

When unlocked, adds virtual parameter `dodge_count_multiplier` to dodge games.

### 6.3 Presets & Templates

Allow saving modification sets:
- "Speed Run Setup" (low victory_limit, high movement_speed)
- "Invincible Tank" (high lives, shields, low obstacles)
- Load preset with one click

---

## Implementation Checklist

### Phase 1: Configuration ✓
- [ ] Add `cheat_engine` config section to `config.lua`
- [ ] Add pricing rules (numeric, boolean, enum, array)
- [ ] Add budget configuration (default: 999,999,999 for testing)
- [ ] Add parameter overrides table
- [ ] Update PlayerData to include cheat_budget and cheat_engine_data

### Phase 2: CheatSystem Model ✓
- [ ] Implement `getModifiableParameters(variant_data)`
- [ ] Implement `calculateModificationCost(param_key, param_type, ...)`
- [ ] Implement `canModify(player_data, game_id, param_key, new_value)`
- [ ] Implement `applyModification(player_data, game_id, ...)`
- [ ] Implement `resetParameter(player_data, game_id, param_key)`
- [ ] Implement `resetAllModifications(player_data, game_id)`
- [ ] Implement `getModifiedVariant(variant_data, modifications)`

### Phase 3: CheatEngineState Controller ✓
- [ ] Filter game list to only show unlocked games (`player_data:isGameUnlocked()`)
- [ ] Add `selectGame(game_id)` method
- [ ] Implement `loadVariantData(game_id)` to read variant JSON
- [ ] Build `modifiable_params` list from variant
- [ ] Implement `modifyParameter(param_key, new_value, step_size)`
- [ ] Implement `resetParameter(param_key)`
- [ ] Add keyboard input handlers (left/right, 1-4, m, r, x)
- [ ] Add `step_size` state variable (default: 1)
- [ ] Update `launchGame()` to pass modified variant

### Phase 4: CheatEngineView UI ✓
- [ ] Design split-panel layout (game list | parameter editor)
- [ ] Display budget (available / total)
- [ ] Display step size selector
- [ ] Display parameter table (name, original, modified, cost)
- [ ] Highlight selected parameter
- [ ] Show modified values in different color
- [ ] Display control hints at bottom

### Phase 5: Integration ✓
- [ ] Update MinigameState to accept variant from args
- [ ] Test full flow: CheatEngine → Modify → Launch → Verify
- [ ] Ensure modifications persist in PlayerData
- [ ] Ensure save/load works correctly

### Phase 6: Testing ✓
- [ ] Test with dodge_variants.json (52 variants, many parameters)
- [ ] Test numeric modifications (+1, +5, +100, max)
- [ ] Test boolean toggles
- [ ] Test budget enforcement (lower budget temporarily)
- [ ] Test parameter reset (single and all)
- [ ] Test game launch with modifications

---

## File Locations Summary

**New/Modified Files:**

```
src/config.lua                          - Add cheat_engine config section
src/models/cheat_system.lua            - Rewrite with new logic
src/models/player_data.lua              - Add cheat budget, modification storage
src/states/cheat_engine_state.lua       - Add parameter modification logic
src/views/cheat_engine_view.lua         - Update UI for parameter editor
src/states/minigame_state.lua           - Accept modified variant from args
documentation/cheat_engine_implementation_plan.md - This file
```

**No New JSON Files Needed:**
- Uses existing variant JSON files (e.g., `dodge_variants.json`)
- Configuration lives in `config.lua` (Lua, not JSON)

---

## Testing Configuration

For initial testing, use these values in `config.lua`:

```lua
cheat_engine = {
    default_budget = 999999999, -- Nearly infinite

    parameter_costs = {
        numeric = {
            base_cost = 10,  -- Very cheap for testing
            exponential_scale = 1.0, -- No scaling
            step_costs = {
                [1] = 1.0,
                [5] = 1.0,
                [10] = 1.0,
                [100] = 1.0,
                ["max"] = 1.0
            }
        },
        boolean = { base_cost = 10, exponential_scale = 1.0 },
        enum = { base_cost = 10, exponential_scale = 1.0 },
        array = { base_cost = 10, exponential_scale = 1.0 }
    },

    parameter_overrides = {}, -- No overrides
    hidden_parameters = {}, -- Show everything
    unlockable_modifications = {} -- Everything unlocked
}
```

This makes all modifications essentially free, allowing rapid testing.

---

## Future Enhancements

1. **Visual Parameter Editor:**
   - Sliders for numeric values
   - Dropdowns for enums
   - Checkboxes for booleans

2. **Undo/Redo:**
   - History stack for modifications
   - Quick undo with Ctrl+Z

3. **Comparison View:**
   - Side-by-side original vs modified
   - Highlight all changed parameters

4. **Search/Filter:**
   - Search parameters by name
   - Filter by type (numeric, boolean, etc.)
   - Show only modified parameters

5. **Export/Import:**
   - Save modification sets to file
   - Share configurations with others
   - Load community presets

6. **Analytics:**
   - Track most-modified parameters
   - Show which games are most heavily modified
   - Display total credits spent across all games

---

## Notes

- **MVC Compliance:** Models handle data/logic, Views handle rendering, State/Controller mediates
- **DI Usage:** All dependencies injected via `di` table
- **Config Externalization:** All tuning values in `config.lua`, not hardcoded
- **Error Handling:** Wrap file I/O and JSON parsing in `pcall`
- **Save Compatibility:** Modifications stored in PlayerData, persisted via SaveManager
- **Performance:** Modification list rebuilt only when game selection changes
- **Extensibility:** New parameter types can be added to `parameter_costs` config
