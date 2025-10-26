# VM Demo Recording & Playback System

## Overview

Virtual Machines don't use formula simulation - they use **demo recording and playback**. You record your strategy, the VM executes it exactly, and generates tokens based on measured success rate.

---

## How Demo Recording Works

**Recording a demo:**
1. Play a game normally
2. Game records: `{ keypresses: [{key: 'w', time: 0.5}, {key: 'a', time: 1.2}, ...], duration: 15.8 }`
3. Demo saved to that game variant
4. Can re-record anytime to improve strategy

**What gets recorded:**
- Exact keypresses and release events
- Timestamp for each input (milliseconds precision)
- Total duration
- Game configuration (which variant, current CheatEngine mods)

**What doesn't need recording:**
- RNG seed (demo works across all seeds)
- Enemy positions (strategy adapts to whatever happens)
- Game state (VM simulates full game)

---

## VM Execution Process

**When you assign a game + demo to a VM:**

1. **Test Phase (runs once, or periodically):**
   - VM executes demo 10-100 times rapidly
   - Each run uses different random seed
   - Records results: completion time, tokens earned, success/fail
   - Calculates averages:
     ```
     Success rate: 87% (87 wins, 13 fails out of 100 runs)
     Avg completion time: 8.2 seconds
     Avg tokens per success: 520
     ```

2. **Generation Phase (continuous):**
   - VM generates tokens at calculated rate:
     ```
     Rate = (avg_tokens × success_rate) / avg_time
     Rate = (520 × 0.87) / 8.2
     Rate = 55.12 tokens/sec
     ```
   - Every second, adds 55.12 tokens to your balance
   - No actual game running continuously - just math

3. **Re-testing (periodic):**
   - Every 5-10 minutes, re-run test phase
   - Updates success rate in case RNG variance exists
   - Smooths out any statistical noise

**Visual representation:**
- UI shows ONE game window running the demo
- Visual feedback for player
- Actual calculation happens in background

---

## Demo Strategy Quality

**Why demo quality matters:**

### Bad Demo (Early Game):
```
Strategy: "Aggressive dodging, lots of movement"
Game: Dodge Master (10 lives, 30 dodges to win)
Results:
- 45% success rate (too risky, often dies)
- 12 sec avg completion
- 320 tokens per success
- Rate: (320 × 0.45) / 12 = 12 tokens/sec
```

**Manual play:** You adapt in real-time, probably 70%+ success
**Verdict:** VMs are worse than you. Manual play is better.

### Mediocre Demo (Mid Game):
```
Strategy: "Conservative movement, use edges"
Game: Dodge Master (20 lives, 20 dodges to win, CheatEngine optimized)
Results:
- 85% success rate (more lives = forgiving)
- 10 sec avg completion
- 1,200 tokens per success
- Rate: (1,200 × 0.85) / 10 = 102 tokens/sec
```

**Manual play:** You might get 90% success, but takes active attention
**Verdict:** VMs competitive. Good for passive income.

### Perfect Demo (Late Game):
```
Strategy: "Barely move, stay in safe zone center"
Game: Dodge Master (50 lives, 5 sec victory, tiny obstacles, CheatEngine perfected)
Results:
- 99.5% success rate (engineered to be impossible to fail)
- 5.2 sec avg completion
- 85,000 tokens per success
- Rate: (85,000 × 0.995) / 5.2 = 16,274 tokens/sec
```

**Manual play:** Might be slightly faster, but requires focus
**Verdict:** VMs superior. Set it and forget it.

---

## The Optimization Loop

**The cycle:**
1. Play game, record basic demo
2. VM tests it: 60% success rate
3. "This sucks, I need to optimize the game"
4. Use CheatEngine: add lives, reduce victory condition
5. Re-record demo with same strategy (or safer strategy)
6. VM tests new demo: 85% success rate
7. "Better! But I can push further..."
8. Max out CheatEngine budget on this game
9. Record ultra-safe demo: "just stand still"
10. VM tests: 99% success rate
11. **Perfect. This game is now an automated money printer.**

**Key insight:** You're not optimizing the game for YOU to play, you're optimizing it for a DUMB BOT to execute a pre-recorded strategy flawlessly.

---

## Seed Manipulation (Advanced System)

### Basic Seed Viewing
**Unlock: "Seed Viewer" (available mid-game)**
- After completing a game, see the RNG seed used
- "Dodge Master - 98% performance - Seed: 847291"
- "Wow, that seed had perfect obstacle patterns!"

### Seed Locking
**Unlock: "Seed Lock" (available late-game)**
- Force a specific seed when playing/recording
- Set seed 847291, replay multiple times to learn it
- Record perfect demo on that seed
- "This demo gets 99% on seed 847291 every time"

### Demo + Seed Synergy
**Without seed lock:**
- Demo works across random seeds
- Success rate: 60-90% (depends on RNG)
- General strategy must handle variance

**With seed lock:**
- Demo works on ONE perfect seed
- Success rate: 95-100% (deterministic)
- Hyper-optimized strategy for that exact pattern

**The progression:**
1. Record demo, VM runs it: 87% success (works on most seeds)
2. Notice seed 482910 gets 99% with your demo
3. Lock that seed, now demo is 99% consistent
4. **Massive jump in VM efficiency**

**Balance:**
- Seed lock costs tokens or requires specific unlock
- Encourages exploration: "Find the god-seed for my demo"
- Late-game optimization: perfect demo + perfect seed = 100% automation

---

## Scaling to Thousands/Millions

**The problem:**
"I want to run 10,000 games at once, but can't simulate 10,000 full games"

**The solution:**
Don't actually run 10,000 games. Run 10-100, extrapolate.

### Approach 1: Test-Based Generation
- VM assigned 10,000 instances of same game
- Runs 100 test executions
- Calculates rate: 55 tokens/sec per instance
- Generates: `55 × 10,000 = 550,000 tokens/sec`
- Only 100 actual executions, rest is math

### Approach 2: Sampling with Variance
- Run 10 actual executions continuously
- Add slight variance to each result (±5%)
- Aggregate: "Based on 10 running instances, generating X tokens/sec"
- Simulates the "feel" of thousands without overhead

### Approach 3: Cached Averages
- Run demo 1,000 times once (takes 2-3 minutes)
- Cache the average success rate
- Use cached value for all future calculations
- Re-test every hour or on demand

**Recommendation:** Approach 1 or 3
- Simple, clean, mathematically sound
- No need to pretend about simulation
- UI shows: "100 VMs active, generating 8.47e11 tokens/min"

---

## UI/UX Considerations

**VM Window Display:**
```
[VM-1: ACTIVE]
Game: Dodge Master (Clone 0)
Demo: "Safe Strategy v3" (recorded 2024-10-26)
Status: Running test phase... (47/100 runs complete)

Current Results:
- Success Rate: 89% (42 wins, 5 fails so far)
- Avg Completion: 7.8 sec
- Avg Tokens: 1,250

Estimated Rate: 142.6 tokens/sec
```

**After test phase completes:**
```
[VM-1: GENERATING]
Game: Dodge Master (Clone 0)
Demo: "Safe Strategy v3"
Success Rate: 87% (87/100 runs)
Generation Rate: 138.4 tokens/sec

Total Earned: 1,247,892 tokens
Uptime: 2h 30m

[Re-Record Demo] [Change Game] [View Last Run]
```

**Multiple VMs:**
```
VM List (12 active):
1. Dodge Master - 138.4 t/s - 87% success
2. Ice Rink - 92.1 t/s - 91% success
3. Tiny Arena - 203.7 t/s - 95% success
4. Speed Trial - 1,847.2 t/s - 99% success ⭐
5. ...

Total Generation: 8,472 tokens/sec
```

---

## Implementation Notes

### Demo File Format (JSON)
```json
{
  "game_id": "dodge_0",
  "variant": { ... full variant JSON ... },
  "cheat_mods": { "lives": 20, "victory_limit": 15 },
  "recording": {
    "inputs": [
      { "key": "w", "state": "pressed", "time": 0.523 },
      { "key": "w", "state": "released", "time": 1.104 },
      { "key": "a", "state": "pressed", "time": 1.450 },
      ...
    ],
    "duration": 15.847,
    "recorded_at": "2024-10-26T15:32:10Z"
  },
  "test_results": {
    "runs": 100,
    "successes": 87,
    "avg_time": 8.234,
    "avg_tokens": 1250,
    "last_tested": "2024-10-26T15:35:42Z"
  }
}
```

### Demo Playback Logic
```lua
function VM:executeDemo(demo, game_instance)
    local time_elapsed = 0
    local input_index = 1

    while not game_instance:isComplete() do
        time_elapsed = time_elapsed + dt

        -- Process any inputs that should happen now
        while input_index <= #demo.inputs do
            local input = demo.inputs[input_index]
            if input.time <= time_elapsed then
                if input.state == "pressed" then
                    game_instance:keyPressed(input.key)
                else
                    game_instance:keyReleased(input.key)
                end
                input_index = input_index + 1
            else
                break
            end
        end

        game_instance:update(dt)
    end

    return game_instance:getResults()
end
```

### Testing Multiple Runs
```lua
function VM:testDemo(demo, num_runs)
    local results = {
        successes = 0,
        total_time = 0,
        total_tokens = 0
    }

    for i = 1, num_runs do
        local game = createGameInstance(demo.game_id, demo.variant, demo.cheat_mods)
        game:setSeed(math.random(1, 999999)) -- Random seed each run

        local result = self:executeDemo(demo, game)

        if result.completed then
            results.successes = results.successes + 1
            results.total_time = results.total_time + result.time
            results.total_tokens = results.total_tokens + result.tokens
        end
    end

    return {
        success_rate = results.successes / num_runs,
        avg_time = results.total_time / results.successes,
        avg_tokens = results.total_tokens / results.successes
    }
end
```

---

## Why This System Works

**Solves the automation problem elegantly:**
- VMs feel earned (you recorded the strategy)
- Skill expression (better demos = better automation)
- Natural progression (unreliable → reliable as you optimize)
- Respects player agency (your strategy, automated)

**Creates meaningful choices:**
- Which games to optimize for VMs?
- What demo strategy to use? (risky vs safe)
- When to re-record demos after CheatEngine upgrades?
- Which seeds to lock for perfect consistency?

**Fits the idle game progression:**
- Early: Active play rewarded (VMs suck)
- Mid: Mixed approach (VMs for passive, manual for active)
- Late: Full automation (perfectly engineered VM farm)

**Scope-friendly:**
- Demo recording: Simple input tracking
- Playback: Just inject inputs at timestamps
- Testing: Run game loop N times, record results
- No AI, no complex simulation, just deterministic playback

---

## Advanced: Boss Games & Demo Engineering

**Boss Game Example:**
```json
{
  "name": "Dodge Apocalypse",
  "victory_condition": "dodge_count",
  "victory_limit": 10000,
  "lives": 1,
  "obstacle_spawn_rate": 5.0,
  "obstacle_speed_variance": 0.9
}
```

**Problem:** Literally impossible to complete manually (10,000 dodges, 1 life, insane spawn rate)

**CheatEngine Solution (100,000 credit budget):**
1. Unlock "Dodge Count Multiplier" (50,000 credits) → set to 1000×
2. Now only need 10 actual dodges to win
3. Lives: 1 → 50 (10,000 credits)
4. Obstacle spawn rate: 5.0 → 0.3 (25,000 credits)
5. Player size: 1.0 → 0.3 (15,000 credits)

**Result:** 8-second trivial game

**Demo Strategy:**
- "Move randomly for 8 seconds, stay near center"
- Success rate: 99.8% (impossible to fail with 50 lives and tiny obstacles)
- **This boss game is now your best idle farm**

**Why this is brilliant:**
- Forces CheatEngine progression (need high budget to unlock multipliers)
- Creates "taming the beast" satisfaction
- Boss games become best endgame farms (highest payouts once optimized)
- Natural gate: "I can't progress until I can afford these unlocks"
