# Offline Tutorial: Balancing Stats Recorder

## Goal
Create a system that records game completion stats (time, tokens, result) to a JSON file for later analysis. This helps balance token rewards across variants.

## Difficulty: Easy-Medium (2-3 hours)

## Files to Study First
- `src/games/base_game.lua` - Where games end and results are calculated
- `src/models/save_manager.lua` - Pattern for JSON file I/O
- `src/games/coin_flip.lua` - Example of `metrics` structure

## What You'll Build

A utility that automatically records every game completion:
```json
[
  {
    "game_id": "coin_flip",
    "variant_name": "Lucky Streak",
    "variant_index": 42,
    "time_elapsed": 45.2,
    "tokens_earned": 1250,
    "result": "victory",
    "metrics": {"max_streak": 7, "accuracy": 0.85},
    "recorded_at": "2024-01-15T10:30:00Z"
  }
]
```

---

## Step 1: Create the Stats Recorder Module

Create `src/utils/stats_recorder.lua`:

```lua
-- src/utils/stats_recorder.lua
-- Records game completion stats for balancing analysis

local json = require('json')

local StatsRecorder = {}

-- File path for stats (in LÖVE save directory)
local STATS_FILE = "balance_stats.json"

-- Load existing stats from file
function StatsRecorder.loadStats()
    local content = love.filesystem.read(STATS_FILE)
    if not content then
        return {}
    end

    local success, data = pcall(json.decode, content)
    if not success or type(data) ~= "table" then
        print("[StatsRecorder] Warning: Could not parse existing stats, starting fresh")
        return {}
    end

    return data
end

-- Save stats to file
function StatsRecorder.saveStats(stats)
    local success, encoded = pcall(json.encode, stats)
    if not success then
        print("[StatsRecorder] Error encoding stats: " .. tostring(encoded))
        return false
    end

    local write_success, err = love.filesystem.write(STATS_FILE, encoded)
    if not write_success then
        print("[StatsRecorder] Error writing stats: " .. tostring(err))
        return false
    end

    return true
end

-- Record a single game completion
-- @param game_id: string - The game type (e.g., "coin_flip", "snake")
-- @param variant: table - The variant config (has name, clone_index, etc.)
-- @param results: table - Game results (tokens, metrics, victory, time_elapsed)
function StatsRecorder.record(game_id, variant, results)
    if not game_id or not results then
        print("[StatsRecorder] Missing required parameters")
        return false
    end

    -- Build the stat entry
    local entry = {
        game_id = game_id,
        variant_name = variant and variant.name or "Unknown",
        variant_index = variant and variant.clone_index or 0,
        time_elapsed = results.time_elapsed or 0,
        tokens_earned = results.tokens or 0,
        result = results.victory and "victory" or "loss",
        metrics = results.metrics or {},
        recorded_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    -- Load existing stats
    local stats = StatsRecorder.loadStats()

    -- Append new entry
    table.insert(stats, entry)

    -- Save back to file
    local saved = StatsRecorder.saveStats(stats)

    if saved then
        print(string.format("[StatsRecorder] Recorded: %s/%s - %s (%.1fs, %d tokens)",
            game_id,
            entry.variant_name,
            entry.result,
            entry.time_elapsed,
            entry.tokens_earned
        ))
    end

    return saved
end

-- Get summary statistics for a specific game
function StatsRecorder.getSummary(game_id)
    local stats = StatsRecorder.loadStats()

    local game_stats = {}
    for _, entry in ipairs(stats) do
        if entry.game_id == game_id then
            table.insert(game_stats, entry)
        end
    end

    if #game_stats == 0 then
        return nil
    end

    -- Calculate averages
    local total_time = 0
    local total_tokens = 0
    local wins = 0

    for _, entry in ipairs(game_stats) do
        total_time = total_time + (entry.time_elapsed or 0)
        total_tokens = total_tokens + (entry.tokens_earned or 0)
        if entry.result == "victory" then
            wins = wins + 1
        end
    end

    return {
        game_id = game_id,
        total_plays = #game_stats,
        wins = wins,
        losses = #game_stats - wins,
        win_rate = wins / #game_stats,
        avg_time = total_time / #game_stats,
        avg_tokens = total_tokens / #game_stats,
        total_tokens = total_tokens
    }
end

-- Get summary for a specific variant
function StatsRecorder.getVariantSummary(game_id, variant_index)
    local stats = StatsRecorder.loadStats()

    local variant_stats = {}
    for _, entry in ipairs(stats) do
        if entry.game_id == game_id and entry.variant_index == variant_index then
            table.insert(variant_stats, entry)
        end
    end

    if #variant_stats == 0 then
        return nil
    end

    local total_time = 0
    local total_tokens = 0
    local wins = 0

    for _, entry in ipairs(variant_stats) do
        total_time = total_time + (entry.time_elapsed or 0)
        total_tokens = total_tokens + (entry.tokens_earned or 0)
        if entry.result == "victory" then
            wins = wins + 1
        end
    end

    return {
        game_id = game_id,
        variant_index = variant_index,
        variant_name = variant_stats[1].variant_name,
        total_plays = #variant_stats,
        wins = wins,
        win_rate = wins / #variant_stats,
        avg_time = total_time / #variant_stats,
        avg_tokens = total_tokens / #variant_stats
    }
end

-- Clear all stats (for testing)
function StatsRecorder.clear()
    love.filesystem.write(STATS_FILE, "[]")
    print("[StatsRecorder] Cleared all stats")
end

return StatsRecorder
```

---

## Step 2: Integrate into BaseGame

Open `src/games/base_game.lua` and find the `getResults` function or wherever game completion is handled.

Add the require at the top:
```lua
local StatsRecorder = require('src.utils.stats_recorder')
```

Find where results are returned (likely in `getResults` or similar). Add the recording call:

```lua
function BaseGame:getResults()
    -- ... existing code that builds results ...

    local results = {
        tokens = self.final_tokens or 0,
        victory = self.victory or false,
        time_elapsed = self.time_elapsed or 0,
        metrics = self.metrics or {}
    }

    -- Record stats for balancing
    StatsRecorder.record(self.game_id, self.variant, results)

    return results
end
```

**Alternative location:** If `getResults` isn't the right place, look for where the game transitions to the completion screen. Search for `self.completed = true` or similar.

---

## Step 3: Test It

1. Run the game: `love .`
2. Play any minigame to completion (win or lose)
3. Check the save directory for `balance_stats.json`

**Save directory location:**
- Windows: `%APPDATA%\LOVE\10000games\balance_stats.json`
- Mac: `~/Library/Application Support/LOVE/10000games/`
- Linux: `~/.local/share/love/10000games/`

---

## Step 4: Add Debug Commands (Optional)

Add a way to view stats in-game. In your debug overlay or console:

```lua
-- Print summary for a game
local summary = StatsRecorder.getSummary("coin_flip")
if summary then
    print(string.format("Coin Flip: %d plays, %.0f%% win rate, avg %.0f tokens",
        summary.total_plays,
        summary.win_rate * 100,
        summary.avg_tokens
    ))
end
```

---

## Step 5: Create an Analysis Script (Optional)

Create `tools/analyze_stats.lua` (run outside LÖVE with standard Lua):

```lua
-- Run with: lua tools/analyze_stats.lua
-- Reads balance_stats.json and prints analysis

local json = require('json')  -- You'll need a json library

local file = io.open("path/to/balance_stats.json", "r")
if not file then
    print("No stats file found")
    return
end

local content = file:read("*all")
file:close()

local stats = json.decode(content)

-- Group by game
local by_game = {}
for _, entry in ipairs(stats) do
    local gid = entry.game_id
    by_game[gid] = by_game[gid] or {entries = {}, total_tokens = 0, total_time = 0, wins = 0}
    table.insert(by_game[gid].entries, entry)
    by_game[gid].total_tokens = by_game[gid].total_tokens + entry.tokens_earned
    by_game[gid].total_time = by_game[gid].total_time + entry.time_elapsed
    if entry.result == "victory" then
        by_game[gid].wins = by_game[gid].wins + 1
    end
end

-- Print report
print("=== BALANCE REPORT ===\n")
for game_id, data in pairs(by_game) do
    local n = #data.entries
    print(string.format("%s:", game_id))
    print(string.format("  Plays: %d (W: %d, L: %d)", n, data.wins, n - data.wins))
    print(string.format("  Win Rate: %.1f%%", (data.wins / n) * 100))
    print(string.format("  Avg Time: %.1fs", data.total_time / n))
    print(string.format("  Avg Tokens: %.0f", data.total_tokens / n))
    print(string.format("  Tokens/Min: %.0f", (data.total_tokens / n) / (data.total_time / n / 60)))
    print()
end
```

---

## Data Structure Reference

Each recorded entry has:

| Field | Type | Description |
|-------|------|-------------|
| `game_id` | string | Game type ("coin_flip", "snake", etc.) |
| `variant_name` | string | Human-readable variant name |
| `variant_index` | number | Clone index from variants JSON |
| `time_elapsed` | number | Seconds played |
| `tokens_earned` | number | Tokens awarded |
| `result` | string | "victory" or "loss" |
| `metrics` | table | Game-specific metrics (streak, accuracy, etc.) |
| `recorded_at` | string | ISO 8601 timestamp |

---

## Stretch Goals

1. **Add difficulty tracking:** Include cheat modifiers in the entry
2. **Track demo vs manual:** Add a `played_by` field ("player" or "vm")
3. **Session grouping:** Add a session ID to group plays together
4. **Export to CSV:** Write a function to export for spreadsheet analysis

## Common Issues

| Problem | Solution |
|---------|----------|
| File not created | Check LÖVE save directory exists and is writable |
| Stats not recording | Verify `getResults` is being called (add print statement) |
| JSON decode error | Stats file may be corrupted; delete it and start fresh |
| `self.variant` is nil | Make sure variant is passed through from game init |

## Key Patterns Learned

- **pcall for safety:** Always wrap JSON encode/decode in pcall
- **LÖVE filesystem:** Uses sandboxed save directory, not project folder
- **Append pattern:** Load existing, add new entry, save entire array
- **ISO timestamps:** Use `os.date("!%Y-%m-%dT%H:%M:%SZ")` for consistent format
