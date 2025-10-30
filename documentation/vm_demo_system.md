# VM Demo Recording & Playback System (Revised)

## Overview

Virtual Machines run **demo recordings** - exact replays of your keypresses. Each VM continuously executes your recorded inputs with random seeds, accumulating tokens based on actual performance per run.

**Core Principle:** VMs don't adapt or use AI. They blindly execute your recorded strategy and hope for the best. Success depends on your demo quality and CheatEngine optimization.

---

## How It Actually Works

### Recording a Demo
1. Play a minigame normally
2. System records: `{ inputs: [{key: 'w', state: 'pressed', frame: 31}, ...], total_frames: 948 }`
3. Demo saved to player data, associated with that game variant
4. Can re-record anytime to improve strategy

**What gets recorded:**
- Exact keypresses and releases
- Frame number for each event (fixed timestep)
- Total frame count
- Game variant ID and CheatEngine configuration snapshot

**What doesn't get recorded:**
- RNG seed (each run uses random seed)
- Enemy positions (demo is blind to game state)
- Player position (demo just injects inputs)

**Frame-Based Recording (Not Time-Based):**
- Demos use fixed timestep recording (e.g., 60 FPS = 1 frame per 1/60 second)
- Frame numbers ensure perfect determinism
- Playback is frame-perfect regardless of visual framerate
- Inspired by Quake's tick-based demo system
- Prevents floating-point accumulation errors
- Demo recorded at 144 FPS produces identical results as 30 FPS recording

---

### VM Execution Loop (The Real System)

**When you assign a demo to a VM slot:**

1. **Start Run:**
   - Initialize game with random seed
   - Begin demo playback from frame 0

2. **Playback:**
   - Inject recorded inputs at exact frame numbers
   - Game simulates with fixed timestep (e.g., 1/60 second per frame)
   - VM does NOT react to game state - it's blind playback

3. **Run Completes:**
   - Game ends (victory or death)
   - Record result: tokens earned, completion status, frames survived

4. **Add Tokens:**
   - `player_data:addTokens(run_result.tokens)`
   - Update VM statistics (total runs, successes, failures)

5. **Restart Immediately:**
   - New random seed
   - Demo playback starts from frame 0
   - Repeat forever until VM stopped

**Key Insight:** Each run is independent. Sometimes your demo wins, sometimes it dies early. Token generation varies per run based on RNG luck and demo quality.

**Visual Behavior:**
- Open VM window → see game playing with your inputs
- Watch it die (or win)
- See it immediately restart and try again
- Different outcome each time (different seed)

**VM Speed System:**
VMs can be upgraded to run faster, processing more frames per visual update:
- **Normal Speed (1x):** One fixed update per frame (visual feedback at normal speed)
- **Multi-Step Mode (2x-100x):** Multiple fixed updates per visual frame (visible speedup, maintains rendering)
- **Headless Mode (Instant):** No rendering, runs demo to completion as fast as CPU allows (milliseconds)

Speed upgrade progression creates satisfying scaling:
- Early game: Watch VMs run at 2-4x speed (faster but still visible)
- Mid game: 10-50x speed (blur of activity, very efficient)
- Late game: Instant mode (completes full run in milliseconds, pure efficiency)

**Implementation Details:**
- Visible VMs in VM Manager use multi-step rendering (capped at reasonable visual speed)
- Background VMs can use headless mode for maximum performance
- Playback windows always render at 1x for clear visual feedback (regardless of actual VM speed)
- Speed is per-VM upgrade, allowing mix of slow/fast VMs

---

### Why Demos Succeed or Fail

**Bad Demo (Early Game):**
```
Strategy: "Aggressive movement, risky dodges"
Game: Dodge Master (10 lives, 30 dodges to win)

Results over 100 runs:
- 38 victories (38% success rate)
- 62 deaths (avg 12 dodges before death)
- Avg tokens per victory: 520
- Avg tokens per death: 180

Token generation highly variable:
- Good run: 520 tokens in 15 sec
- Bad run: 180 tokens in 6 sec
- Average: ~280 tokens per run
```

**Manual play is better** - you adapt in real-time. VM is worse than you.

**Mediocre Demo (Mid Game):**
```
Strategy: "Conservative movement, use safe zones"
Game: Dodge Master Optimized (30 lives, 20 dodges to win, CheatEngine tuned)

Results over 100 runs:
- 82 victories (82% success rate)
- 18 deaths (avg 16 dodges before death)
- Avg tokens per victory: 1,450
- Avg tokens per death: 950

Token generation more consistent:
- Good run: 1,450 tokens in 12 sec
- Bad run: 950 tokens in 10 sec
- Average: ~1,280 tokens per run
```

**VM competitive with manual play** - good for passive income while doing other things.

**Perfect Demo (Late Game):**
```
Strategy: "Minimal movement, stay in center"
Game: Dodge Master Engineered (100 lives, 5 sec victory, obstacles nerfed, CheatEngine maxed)

Results over 100 runs:
- 99 victories (99% success rate)
- 1 death (fluke bad seed)
- Avg tokens per victory: 92,000
- Avg tokens per death: 85,000 (died near completion)

Token generation extremely consistent:
- Almost always: 92,000 tokens in 5.2 sec
- Rate: ~17,700 tokens/sec
```

**VM superior to manual play** - perfectly engineered for automation. Set and forget.

---

## The Optimization Loop

**The progression cycle:**

1. **Initial Demo (Naive Strategy):**
   - Play game normally, record inputs
   - Assign to VM
   - Success rate: 40-60%
   - "This is unreliable, I'm losing half my runs"

2. **CheatEngine Tuning (Make Game Safer):**
   - Add more lives (10 → 30)
   - Reduce victory condition (30 dodges → 20 dodges)
   - Increase player size (harder to hit)
   - Cost: 5,000 tokens in CheatEngine budget

3. **Re-record Demo (Same or Safer Strategy):**
   - Use tuned game parameters
   - Record conservative strategy
   - Success rate: 75-85%
   - "Much better! More consistent income"

4. **Max Optimization (Engineer Triviality):**
   - Max lives (100)
   - Minimal victory condition (5 seconds survival)
   - Tiny obstacles, massive player hitbox
   - Cost: 50,000 tokens in CheatEngine budget

5. **Final Demo (Trivial Strategy):**
   - "Just stand still" or "barely move"
   - Success rate: 95-99%
   - **This game is now a money printer**

**Key Insight:** You're not optimizing the game for YOU, you're optimizing it for a DUMB BOT executing pre-recorded inputs.

---

## Scaling to Millions (Future Optimization)

**NOTE: This is NOT part of the initial demo system. This is a future performance optimization.**

**The Problem:**
- Late game, player has millions of VM instances
- Can't simulate millions of full game runs every second
- Performance would collapse

**The Solution (Future Phase):**
- Run small sample of VMs (10-100 actual executions)
- Calculate statistical baseline (avg tokens/run, success rate)
- Extrapolate to millions: `baseline_rate × instance_count`
- Add minor variance (±5%) for realism
- Re-sample periodically (every 5-10 minutes)

**Example:**
```
Player has 1,000,000 VMs running "Dodge Master Perfect"
System runs 100 actual simulations
Results: 99% success, 5.2 sec avg, 92,000 tokens avg
Calculates: 17,700 tokens/sec per VM
Generates: 17,700 × 1,000,000 = 17.7 billion tokens/sec
Only 100 actual game loops running
```

**This is NOT the demo recording system.** This is a scaling trick for when VMs become absurdly numerous.

---

## Data Structures

### Demo File Format (JSON)
```json
{
  "game_id": "dodge_1",
  "variant_config": {
    "clone_index": 0,
    "cheat_mods": {
      "lives": 30,
      "victory_limit": 20,
      "player_size": 1.5
    }
  },
  "recording": {
    "inputs": [
      { "key": "w", "state": "pressed", "frame": 31 },
      { "key": "w", "state": "released", "frame": 66 },
      { "key": "a", "state": "pressed", "frame": 87 },
      { "key": "a", "state": "released", "frame": 131 },
      { "key": "d", "state": "pressed", "frame": 233 }
    ],
    "total_frames": 948,
    "fixed_dt": 0.016666667,
    "recorded_at": "2025-10-30T15:32:10Z"
  },
  "metadata": {
    "demo_name": "Conservative Strategy v3",
    "description": "Stay near center, avoid edges",
    "version": 1
  }
}
```

### VM State (Player Data)
```json
{
  "vm_slots": 3,
  "active_vms": {
    "1": {
      "game_id": "dodge_1",
      "demo_id": "demo_dodge_1_v3",
      "stats": {
        "total_runs": 1247,
        "successes": 1089,
        "failures": 158,
        "total_tokens": 1402850,
        "uptime_seconds": 18420,
        "last_run_tokens": 1450,
        "last_run_success": true
      },
      "current_run_progress": 0.67
    }
  },
  "demos": {
    "demo_dodge_1_v3": { ... demo JSON ... }
  }
}
```

---

## Phased Implementation Plan

### Phase 1: Demo Recording Infrastructure

**Goal:** Allow players to record their gameplay inputs.

**Components to Create:**
- **Model: `DemoRecorder`** (`src/models/demo_recorder.lua`)
  - Initialize recording (start frame counter)
  - Capture key press/release events with frame numbers
  - Track fixed timestep updates (frame counter increments)
  - Finalize recording (total frame count)
  - Generate demo data structure
  - Validate recording (minimum frames, has inputs)

- **Data Storage:**
  - Extend `PlayerData` model to include `demos` table
  - Demos indexed by ID: `demo_{game_id}_{version}`
  - SaveManager integration for demo persistence

- **Integration Points:**
  - MinigameController receives DI reference to DemoRecorder
  - Add recording mode flag to controller state
  - Hook keypressed/keyreleased to recorder when active
  - Stop recording on game complete or explicit cancel

**Architectural Considerations:**
- DemoRecorder is a model - no rendering, pure data capture
- Use DI to inject into MinigameController
- Recording happens during fixed timestep updates (not variable dt updates)
- Frame counter must be consistent with game's fixed update loop
- Emit event bus events: `demo_recording_started`, `demo_recording_completed`
- Store demos in player_data for persistence via SaveManager
- Handle edge cases: recording cancelled, zero inputs, duplicate recordings

**Fixed Timestep Integration:**
- Games must use fixed timestep for determinism
- Recording tracks frame number during fixed updates
- Example: 60 FPS fixed timestep = 1 frame per 0.01666... seconds
- Variable visual framerate doesn't affect recording (only fixed updates matter)

**File Changes:**
- New: `src/models/demo_recorder.lua`
- Modified: `src/models/player_data.lua` (add demos table)
- Modified: `src/controllers/minigame_controller.lua` (add recording mode)
- Modified: `src/utils/save_manager.lua` (persist demos)

---

### Phase 1 Completion Notes

**What Has Been Implemented:**
- **Created `src/models/demo_recorder.lua`**: Full demo recording model with frame-based input capture
  - `startRecording()`, `stopRecording()`, `cancelRecording()` methods
  - `recordKeyPressed()`, `recordKeyReleased()` methods
  - `fixedUpdate()` to track frame count
  - Validation for minimum/maximum frame limits
  - Event bus integration (`demo_recording_started`, `demo_recording_completed`, `demo_recording_cancelled`)

- **Extended `src/models/player_data.lua`**: Added demo storage and management
  - Added `demos` table to player data structure
  - Implemented `saveDemo()`, `getDemo()`, `getDemosForGame()`, `getAllDemos()` methods
  - Implemented `deleteDemo()`, `renameDemo()`, `updateDemoDescription()`, `hasDemo()` methods
  - Added demos to `serialize()` for save persistence

- **Added `config.lua` vm_demo section**: Configuration for demo system
  - `fixed_dt = 1/60` (60 FPS fixed timestep)
  - `max_demo_frames = 18000` (~5 minutes)
  - `min_demo_frames = 60` (~1 second)
  - Speed upgrade configuration placeholders

- **Added fixed timestep to `src/games/base_game.lua`**: Deterministic game updates
  - Added `fixed_dt`, `accumulator`, `frame_count` to base game initialization
  - Created `updateWithFixedTimestep(dt)` method (accumulator pattern)
  - Created `fixedUpdate(dt)` method (deterministic update)
  - Refactored `updateGameLogic(dt)` to be called from both variable and fixed updates

- **Updated `main.lua`**: Integrated DemoRecorder into DI container
  - Required `DemoRecorder` module
  - Instantiated `demo_recorder` with DI
  - Added `di.demoRecorder` for dependency injection

**What Will Be Noticed In-Game:**
- **NOTHING YET** - Phase 1 is infrastructure only
- No UI changes
- No gameplay changes
- Demo recording is not yet hooked up to any user-facing functionality
- SaveManager will persist demos table (but it's empty until Phase 2-5)

**Testing Steps:**
- [ ] Game launches without errors
- [ ] Verify DemoRecorder is in DI container (check main.lua initialization)
- [ ] Verify PlayerData.demos table exists in save file after save
- [ ] Verify config.vm_demo values are accessible
- [ ] BaseGame has frame_count and fixed_dt properties (no visual test)

**Known Issues / Future Work:**
- Demo recording is not yet integrated into MinigameController (deferred to Phase 2)
- No UI for recording demos yet
- SaveManager doesn't need explicit changes (demos auto-persist via PlayerData.serialize)
- Fixed timestep updates are not yet called anywhere (games still use variable dt)
- Phase 2 will connect recording to actual gameplay

**Architectural Notes:**
- Demo storage uses timestamp-based IDs: `demo_{game_id}_{timestamp}`
- Demos stored directly in player save data (not separate files)
- Fixed timestep is opt-in via `updateWithFixedTimestep()` method
- Games continue to work normally with variable timestep (`updateBase()`)
- DemoRecorder is stateless between recordings (can be reused)

---

### Phase 2: Demo Playback Engine

**Goal:** Play back recorded demos in game instances.

**Components to Create:**
- **Model: `DemoPlayer`** (`src/models/demo_player.lua`)
  - Load demo data
  - Track playback frame counter
  - Inject inputs at precise frame numbers
  - Handle input queue (upcoming events)
  - Detect playback completion (frame count exceeded or game complete)
  - Return result (tokens, success, frames survived)

- **Integration Points:**
  - Game instances accept playback mode flag
  - Disable human input during playback
  - DemoPlayer calls game.keypressed/keyreleased at timestamps
  - Game runs normally, unaware it's being automated

**Architectural Considerations:**
- DemoPlayer is a model - contains playback logic only
- Game instances remain unchanged (just receive different input source)
- Uses frame counter (not time-based)
- Handle input timing edge cases (simultaneous presses, rapid sequences)
- Emit events: `demo_playback_started`, `demo_playback_completed`

**Playback Algorithm (Frame-Based):**
```
playback_frame = 0
input_index = 1

each fixed update:
    -- Inject all inputs for this frame
    while input_index <= #demo.inputs:
        if demo.inputs[input_index].frame == playback_frame:
            inject_input(demo.inputs[input_index].key, demo.inputs[input_index].state)
            input_index += 1
        else:
            break

    -- Always use fixed timestep
    game:fixedUpdate(FIXED_DT)
    playback_frame += 1

    if game:isComplete() or playback_frame > demo.total_frames:
        return game:getResults()
```

**Speed Multiplier Support:**
```
-- Multi-step mode: run N fixed updates per visual frame
for step = 1, speed_multiplier do
    -- Inject inputs for current frame
    inject_inputs_for_frame(playback_frame)

    -- Run one fixed update
    game:fixedUpdate(FIXED_DT)
    playback_frame += 1

    if game:isComplete() then break end
end

-- Headless mode: run to completion without rendering
function runHeadless(game, demo)
    while not game:isComplete() and playback_frame <= demo.total_frames do
        inject_inputs_for_frame(playback_frame)
        game:fixedUpdate(FIXED_DT)  -- No rendering!
        playback_frame += 1
    end
    return game:getResults()
end
```

**File Changes:**
- New: `src/models/demo_player.lua`
- Modified: Game classes (add playback mode flag, support speed multipliers, headless mode)
- Modified: `src/controllers/minigame_controller.lua` (support playback mode)
- Modified: Base game classes (add fixed timestep support if not already present)

---

### Phase 2 Completion Notes

**What Has Been Implemented:**
- **Created `src/models/demo_player.lua`**: Full demo playback engine with frame-perfect execution
  - `startPlayback()`, `stopPlayback()` methods
  - `update(dt)` for multi-step rendering mode (runs N fixed updates per visual frame)
  - `stepFrame()` for single frame execution (injects inputs + updates game)
  - `runHeadless()` for instant completion mode (no rendering)
  - `injectInput()` to inject recorded keypresses/releases into game
  - `isComplete()` checks game completion or frame count exceeded
  - Speed multiplier support (1x to 100x)
  - Headless mode support (instant execution)
  - Event bus integration (`demo_playback_started`, `demo_playback_completed`)

- **Added playback mode to `src/games/base_game.lua`**: Prevents human input during playback
  - Added `playback_mode` flag to game state
  - Modified `keypressed()`, `keyreleased()`, `mousepressed()` to block input when `playback_mode = true`
  - Added `setPlaybackMode(enabled)` and `isInPlaybackMode()` methods

- **Updated `main.lua`**: Integrated DemoPlayer into DI container
  - Required `DemoPlayer` module
  - Instantiated `demo_player` with DI
  - Added `di.demoPlayer` for dependency injection

**What Will Be Noticed In-Game:**
- **STILL NOTHING** - Phase 2 is playback infrastructure only
- No UI changes
- No gameplay changes
- Demo playback is not yet hooked up to any user-facing functionality
- Games can now block human input during playback (but no playback is triggered yet)

**Testing Steps:**
- [ ] Game launches without errors
- [ ] Verify DemoPlayer is in DI container (check main.lua initialization)
- [ ] Verify BaseGame has `playback_mode` flag and input blocking methods
- [ ] No functional testing possible yet (no way to trigger playback)

**Known Issues / Future Work:**
- Demo playback is not yet integrated into any controller or state (deferred to Phase 3)
- No way for user to trigger demo playback yet
- MinigameController integration deferred (not needed until Phase 3+ when VMs actually play demos)
- Speed multiplier and headless mode implemented but not yet tested
- Phase 3 will use DemoPlayer in VM execution loops

**Architectural Notes:**
- DemoPlayer maintains single playback instance (one demo at a time)
- Can be reused for multiple demos (reset on each `startPlayback()`)
- Speed multiplier: 1 = normal speed, 10 = 10 fixed updates per visual frame, etc.
- Headless mode bypasses all rendering and runs to completion immediately
- Game instances must use `fixedUpdate()` for deterministic playback
- Playback mode blocks human input at BaseGame level (not in individual game implementations)

**How Playback Works:**
1. Call `startPlayback(demo, game_instance, speed, headless)`
2. Each frame: inject inputs scheduled for current frame → run `game:fixedUpdate()` → increment frame
3. Repeat until game completes or frame count exceeds demo length
4. Call `stopPlayback()` to get results (tokens, completion status, frames played)

---

### Phase 3: VM Execution System Refactor

**Goal:** Replace formula-based VMs with demo playback loops.

**Components to Refactor:**
- **Model: `VMManager`** (heavy refactor of existing file)
  - Remove formula-based power calculation
  - Add demo assignment (instead of game ID only)
  - Track VM run statistics (runs, successes, failures, tokens)
  - Implement run loop state machine:
    - IDLE: No demo assigned
    - RUNNING: Demo executing
    - RESTARTING: Brief pause between runs
    - STOPPED: Manually stopped
  - Calculate tokens per run (not per cycle)
  - Update statistics after each run
  - Save/restore VM state with demo references

- **VM Slot Data Structure:**
```lua
{
    slot_index = 1,
    state = "RUNNING", -- IDLE, RUNNING, RESTARTING, STOPPED
    assigned_game_id = "dodge_1",
    assigned_demo_id = "demo_dodge_1_v3",
    demo_player = DemoPlayer instance,
    game_instance = Game instance,

    speed_upgrade_level = 0, -- 0 = 1x, 1 = 2x, 2 = 4x, etc., max = instant/headless
    speed_multiplier = 1, -- Actual multiplier (how many fixed updates per visual frame)
    headless_mode = false, -- If true, no rendering (instant completion)

    stats = {
        total_runs = 1247,
        successes = 1089,
        failures = 158,
        total_tokens = 1402850,
        uptime = 18420, -- seconds
        tokens_per_minute = 4567, -- calculated average
    },

    current_run = {
        start_frame = 0,
        current_frame = 234,
        seed = 847291
    }
}
```

**Execution Loop Logic:**
```
VM State Machine:

IDLE:
    - No demo assigned
    - Wait for assignment

RUNNING:
    - if headless_mode:
        - run demo to completion instantly (no rendering)
        - capture result (tokens, success, frames)
        - transition to RESTARTING immediately
    - else (multi-step rendering mode):
        - for i = 1 to speed_multiplier:
            - demo_player:fixedUpdate()
            - game_instance:fixedUpdate(FIXED_DT)
            - if game complete: break
        - if demo complete or game complete:
            - capture result (tokens, success, frames)
            - update stats
            - player_data:addTokens(result.tokens)
            - emit event: vm_run_completed
            - transition to RESTARTING

RESTARTING:
    - brief pause (0.1 seconds) for visual feedback
    - create new game instance with random seed
    - reset demo_player
    - transition to RUNNING

STOPPED:
    - Demo assigned but manually paused
    - Don't execute, just wait
```

**Architectural Considerations:**
- VMManager uses DI to access GameData, PlayerData, EventBus
- Each VM slot contains its own DemoPlayer and game instance
- Game instances are lightweight (can run many simultaneously)
- Use event bus for: `vm_run_completed`, `vm_stats_updated`, `vm_speed_upgraded`
- Save VM state frequently (after each run completion)
- Handle edge cases: demo deleted while assigned, game unlocked status changes
- Speed upgrades modify `speed_multiplier` and `headless_mode` flags
- Headless VMs complete runs in milliseconds but provide no visual feedback
- Mixed speeds allowed: some VMs at 1x for watching, others at instant for efficiency

**File Changes:**
- Modified: `src/models/vm_manager.lua` (major refactor)
- Modified: `src/models/player_data.lua` (update active_vms structure)
- Modified: `src/utils/save_manager.lua` (persist new VM state format)

---

### Phase 3 Completion Notes

**What Has Been Implemented:**
- **Completely refactored `src/models/vm_manager.lua`**: Replaced formula-based system with demo playback
  - **New VM slot structure**: Includes state machine, demo references, stats, speed settings
    - States: IDLE, RUNNING, RESTARTING, STOPPED
    - Stores `demo_player`, `game_instance`, `assigned_demo_id`
    - Tracks `total_runs`, `successes`, `failures`, `total_tokens`, `uptime`, `tokens_per_minute`
    - Supports `speed_multiplier` and `headless_mode`

  - **State machine implementation** in `update()`:
    - IDLE: Does nothing, waiting for demo assignment
    - RUNNING: Executes demo playback (headless or multi-step mode)
    - RESTARTING: Brief delay, then creates new game instance and starts next run
    - STOPPED: Manually paused (not yet exposed in UI)

  - **New methods**:
    - `createEmptySlot()`: Creates slot with new structure
    - `restoreVMSlot()`: Restores from save data, verifies demo exists
    - `updateRunningSlot()`: Handles demo playback, checks completion
    - `updateRestartingSlot()`: Manages restart delay, creates new game instance
    - `startNewRun()`: Creates game instance, initializes DemoPlayer, starts playback
    - `createGameInstance()`: Instantiates game with variant config from demo
    - `processRunResult()`: Updates stats, emits events, saves state
    - `transitionToRestarting()`: Cleans up game instance, resets timer
    - `saveSlotState()`: Persists VM state to player_data.active_vms
    - `assignDemo()`: Assigns demo to slot (replaces old `assignGame`)
    - `removeDemo()`: Stops playback, resets slot (replaces old `removeGame`)
    - `upgradeSpeed()`: Changes speed settings for a VM
    - `isDemoAssigned()`: Checks if demo is in use

  - **Removed old formula-based code**:
    - No more `auto_play_power`, `tokens_per_cycle`, `cycle_time`, `time_remaining`
    - No more performance formula calculations
    - No more upgrade bonus calculations (now handled by game instances)

  - **Event bus integration**:
    - Emits `vm_run_completed` after each demo run (includes tokens, success status)
    - Emits `vm_speed_upgraded` when speed changes
    - Maintains existing `vm_started`, `vm_stopped`, `vm_created` events

- **Updated active_vms save format**: Now stores demo_id and stats
  - Old format: `{game_id, time_remaining}`
  - New format: `{game_id, demo_id, speed_upgrade_level, speed_multiplier, headless_mode, stats:{...}}`
  - Backward compatibility: VMs with old format won't restore (intentional breaking change)

**What Will Be Noticed In-Game:**
- **STILL NOTHING USER-FACING** - VMs are now functional but no way to assign demos yet
- Existing VM system will break (old saves won't load VMs)
- No UI changes yet
- VMs won't appear active because there's no way to record/assign demos via UI
- **However, if a demo were manually assigned via code**, the VM would:
  - Execute the demo repeatedly with random seeds
  - Accumulate tokens based on actual run results
  - Track success/failure statistics
  - Support speed multipliers and headless mode

**Testing Steps:**
- [ ] Game launches without errors
- [ ] Existing VMs appear idle (old save data incompatible)
- [ ] Check console for "VM Manager initialized" message
- [ ] Verify vm_manager uses new slot structure (check createEmptySlot)
- [ ] No functional testing possible yet (no UI to assign demos)

**Known Issues / Future Work:**
- **BREAKING CHANGE**: Old VM save data is incompatible (VMs won't restore)
  - Players will see empty VM slots after update
  - This is acceptable for Phase 3 (no user-facing demo system yet anyway)
- No UI to assign demos to VMs (Phase 4-5)
- No UI to record demos (Phase 5)
- No UI to view VM stats (Phase 4)
- Speed upgrade system implemented but no UI to purchase upgrades
- STOPPED state exists but no pause/resume UI
- Phase 4 will add VM Manager UI to make this functional

**Architectural Notes:**
- Each VM slot contains its own DemoPlayer and game instance
- Game instances are created fresh for each run (prevents state leakage)
- Random seed changes per run: `math.randomseed(os.time() + slot.slot_index)`
- Tokens awarded immediately upon run completion (not batched)
- Stats calculate tokens_per_minute based on actual performance over time
- Headless mode runs to completion instantly (no frame delay)
- Multi-step mode processes N fixed updates per visual frame
- Restart delay (0.1s) provides visual feedback between runs

**How VM Execution Works Now:**
1. Demo assigned → state = RESTARTING
2. After restart_delay → create game instance, create DemoPlayer, start playback → state = RUNNING
3. Each frame: DemoPlayer injects inputs, game updates with fixedUpdate()
4. Run completes → process result (tokens, stats) → state = RESTARTING
5. Loop back to step 2 with new random seed

**Legacy Compatibility:**
- `isGameAssigned()` still works (checks if any demo for that game is assigned)
- `purchaseVM()`, `getVMCost()`, `getSlotCount()`, `getActiveSlotCount()` unchanged
- Old `assignGame()` and `removeGame()` methods removed (replaced by `assignDemo()`, `removeDemo()`)

---

### Phase 4: VM Window & Visualization

**Goal:** Create UI for viewing and managing VMs.

**Components to Create:**
- **Program Definition:** Add VM Manager to `programs.json`
  - Window defaults (800x600, resizable)
  - Requirements (none - always available)
  - Icon and display name

- **View: `VMManagerView`** (`src/views/vm_manager_view.lua`)
  - Grid of VM slots (similar to current design)
  - Per-slot display:
    - Slot number and status (IDLE/RUNNING/STOPPED)
    - Assigned game name
    - Demo name and version
    - Speed indicator (1x, 4x, 10x, INSTANT)
    - Live stats: runs, success rate, tokens/min
    - Progress indicator (current run % or "INSTANT" for headless)
  - Selected slot detail panel:
    - Full statistics
    - Assign/Remove/Stop controls
    - Speed upgrade controls
    - Re-record button
  - **Live Playback Window (separate or embedded):**
    - Shows current run executing
    - Mini game view with demo playing
    - Real-time feedback

- **Controller: `VMManagerController`** (extend existing or create new)
  - Handle slot selection
  - Process assign demo request
  - Process remove/stop requests
  - Process speed upgrade purchases
  - Provide data to view (slot states, stats, speed levels)
  - Route to demo recording when requested

**View Architecture:**
- View is presentational only
- Returns events: `{action: "assign_demo", slot: 1, game_id: "dodge_1", demo_id: "..."}`
- Controller validates and calls VMManager model methods
- Use viewport coordinates (windowed view)
- No direct model access from view

**Live Playback Options:**
1. **Embedded in VM Manager window:** Small preview per slot
2. **Separate window:** "VM Playback" program showing one selected VM
3. **Modal overlay:** Click slot to watch live in popup

**Recommended:** Option 2 - separate "VM Playback" window
- Less visual clutter in VM Manager
- Can resize/position playback window
- Follows desktop paradigm (multiple windows)
- **Important:** Playback windows ALWAYS render at 1x speed for visual clarity, regardless of VM's actual speed setting

**File Changes:**
- New: `src/views/vm_manager_view.lua` (refactor existing or create new)
- New: `src/controllers/vm_manager_controller.lua`
- New: `src/views/vm_playback_view.lua` (live game view)
- Modified: `assets/data/programs.json` (add VM programs)

### Phase 4 Completion Notes

**What Has Been Implemented:**
- **Updated `src/states/vm_manager_state.lua`**: Controller now supports demo-based workflow
  - **New state properties**: `filtered_demos` list for demo selection modal
  - **Updated `enter()`**: Calls both `updateGameList()` and `updateDemoList()`
  - **Modified `updateGameList()`**: Only shows games with at least one recorded demo (not just completed games)
  - **New `updateDemoList()`**: Fetches demos for selected slot's assigned game
  - **Updated `keypressed()`**: Handles ESC to navigate back from demo selection → game selection → close
  - **Modified `purchaseUpgrade()`**: Removed old cycle time recalculation (no longer needed with demo playback)
  - **New event handlers**:
    - `assign_demo`: Assigns selected demo to VM slot
    - `stop_vm`: Stops running VM
    - `start_vm`: Starts stopped VM
    - `upgrade_speed`: Upgrades VM speed multiplier
  - **Two-step assignment flow**: Select game → select demo → assign
  - **New action methods**:
    - `assignDemoToSlot()`: Validates demo, calls `vm_manager:assignDemo()`, closes modals
    - `stopVM()`: Calls `vm_manager:stopVM()`, saves state
    - `startVM()`: Calls `vm_manager:startVM()`, saves state
    - `upgradeVMSpeed()`: Calls `vm_manager:upgradeSpeed()`, saves state

- **Completely refactored `src/views/vm_manager_view.lua`**: New demo-based UI
  - **New view state**: `demo_selection_open`, `selected_game_id`, `hovered_speed_upgrade`

  - **Updated `drawVMSlot()`**: Shows demo-based VM information
    - Displays VM state (IDLE/RUNNING/RESTARTING/STOPPED) instead of cycle timers
    - Shows assigned demo name below game name
    - Displays speed indicator (1x, 4x, 10x, INSTANT) in top-right corner
    - Shows live stats: runs, success rate, tokens/min
    - Progress bar shows current frame / total frames instead of time remaining
    - Control buttons: STOP/START button and [SPEED+] button
    - Game icon resized to 32x32 (was 48x48) to fit more info

  - **New `drawDemoSelectionModal()`**: Second-step modal for choosing demo
    - Lists all demos for selected game
    - Shows demo name and metadata (frame count, duration)
    - "No demos available" message if game has no demos
    - Scrollbar support for long demo lists
    - Footer instructions

  - **Updated `drawWindowed()`**: Renders both modals
    - Game selection modal → Demo selection modal flow
    - Updated instructions text

  - **Completely rewritten `mousepressed()`**: Handles new interaction flow
    - **Demo selection modal handling**: Scrollbar, demo clicks, outside clicks go back to game selection
    - **Game selection modal handling**: Scrollbar, game clicks show demo selection (don't close modal yet)
    - **VM slot control buttons**: Click regions for STOP/START and SPEED+ buttons
    - **Empty slot clicks**: Open game selection modal
    - **Assigned slot clicks**: Remove game (for now - context menu possible later)
    - Upgrade buttons and purchase VM button unchanged

  - **New `getDemoAtPosition()`**: Helper to detect demo clicks in modal

  - **Updated `wheelmoved()`**: Handles scrolling in both modals

- **No changes to `assets/data/programs.json`**: Existing window defaults (700x500) sufficient for new UI

**What Will Be Noticed In-Game:**
- **FIRST USER-FACING DEMO SYSTEM FUNCTIONALITY!**
- **VM Manager window now works** with demo-based system:
  - Empty VM slots say "Click to assign"
  - Clicking empty slot opens game selection → demo selection flow
  - VM slots show:
    - Game name and demo name
    - State indicator (RUNNING, RESTARTING, etc.)
    - Speed indicator (1x, 10x, INSTANT, etc.)
    - Live statistics (runs, success rate, tokens/min)
    - Progress bar with frame count
  - Control buttons visible:
    - STOP/START button (left side)
    - [SPEED+] button (right side)
- **However**: No way to record demos yet (Phase 5), so players can't actually use VMs
- Players will see "No demos available" message when trying to assign to VM slots

**Testing Steps:**
- [ ] Launch game, open VM Manager window
- [ ] Click empty VM slot → game selection modal appears
- [ ] Only games with recorded demos should appear (if any exist)
- [ ] Click game → demo selection modal appears
- [ ] "No demos available" message shows (since no recording UI yet)
- [ ] ESC navigates back: demo selection → game selection → close window
- [ ] Existing global upgrades (CPU Speed, Overclock) still appear at bottom
- [ ] Purchase VM button still works
- [ ] Window is resizable

**Known Issues / Future Work:**
- **No demo recording UI yet** - Phase 5 will add MinigameController integration to record demos during gameplay
- **Can't actually test full VM workflow yet** - need to record a demo first
- Demo removal UI missing (context menu or confirmation dialog)
- Speed upgrade button doesn't show cost or max level indication
- No visual feedback for button clicks (could add hover/press states)
- No live playback window (deferred to Phase 6)
- STOPPED state exists but no clear pause/resume distinction in UI
- Remove game functionality triggers on any assigned slot click (should be dedicated button or context menu)
- No confirmation dialog when removing assigned demo
- Stats display could be prettier (currently just text)
- Progress bar doesn't animate smoothly at high speeds (expected - showing frame count)

**Architectural Notes:**
- Two-step assignment: game selection → demo selection → assign
  - Prevents accidental assignments
  - Allows choosing specific demo if multiple exist
  - ESC can navigate back through the flow
- View now checks `slot.state != "IDLE"` instead of `slot.active`
- Controller fetches filtered demos on-demand via `updateDemoList()`
- Modal scroll offset resets when opening game selection
- Control buttons use click regions within slot bounds
- Speed indicator uses `Config.vm_demo.headless_speed_label` for instant mode
- View accesses `controller.filtered_demos` directly for demo modal
- Stats calculate live: success rate = successes / total_runs

**UI Layout Details:**
- **VM Slot** (180x120px):
  - Header: "VM N" (top-left), Speed indicator (top-right)
  - Icon: 32x32px game icon (left side, row 2)
  - Game name: 0.7 scale (right of icon)
  - Demo name: 0.6 scale, cyan color (below game name)
  - State: 0.6 scale, cyan color (below demo name)
  - Stats: 3 lines of 0.6 scale text
    - Runs: N
    - Success: N%
    - N.N tk/min
  - Progress bar: 12px height, game's palette color
  - Control strip: 15px height button bar
    - STOP/START (left, 5-50px)
    - [SPEED+] (right, width-55 to width-5px)

- **Demo Selection Modal**:
  - Header: "Select Demo to Assign"
  - List area: demo items with name + frame info
  - Footer: Instructions
  - Scrollbar if needed

**Integration Points:**
- Phase 5 will add demo recording in MinigameController → enables full VM workflow
- Phase 6 could add live playback window (embedded view of game running)
- Phase 7 could add context menus for additional VM actions
- Phase 8 will add demo management (rename, delete, export demos)

---

### Phase 5: Demo Management UI

**Goal:** Allow players to view, select, and manage demos.

**Components to Create:**
- **Modal/Window: Demo Selection**
  - Lists all demos for a given game
  - Shows: demo name, success rate (if stats exist), date recorded
  - Actions: Select, Delete, Re-record, Rename
  - Filter by game type

- **Integration with Launcher:**
  - After completing a game, prompt: "Record Demo for VM?"
  - Button in completion screen to record/re-record
  - Associate demos with game variants

- **Demo Recording Flow:**
  1. Complete minigame
  2. Prompt: "Record this run as a demo?"
  3. If yes: save recording with auto-generated name
  4. Allow immediate assignment to VM or save for later

**Architectural Considerations:**
- Demo list view is presentational (emits selection events)
- Demo management logic in PlayerData model
- Use event bus: `demo_selected`, `demo_deleted`, `demo_recorded`
- Demo names default to: `"{game_name} Strategy v{N}"`
- Allow player to rename demos (metadata field)

**File Changes:**
- New: `src/views/demo_selection_view.lua`
- Modified: `src/states/completion_state.lua` (add demo recording prompt)
- Modified: `src/models/player_data.lua` (demo CRUD operations)

### Phase 5 Completion Notes

**What Has Been Implemented:**
- **Updated `src/controllers/minigame_controller.lua`**: Integrated demo recording into gameplay
  - **New dependencies**: `demo_recorder` from DI container
  - **New state properties**: `is_recording`, `recorded_demo`, `show_save_demo_prompt`
  - **Modified `begin()`**: Starts demo recording when game begins
    - Calls `demoRecorder:startRecording(game_id, variant_config)`
    - Sets `is_recording = true`
  - **Modified `update()`**: Calls `demoRecorder:fixedUpdate()` every frame to track frame count
  - **Modified `processCompletion()`**: Stops recording and creates demo data
    - Calls `demoRecorder:stopRecording(auto_name, description)`
    - Stores recorded demo in `self.recorded_demo`
    - Sets `show_save_demo_prompt = true` to trigger UI
  - **Modified `getSnapshot()`**: Includes `show_save_demo_prompt` and `recorded_demo` for view
  - **New `saveDemo()`**: Saves recorded demo to player_data, clears prompt
  - **New `discardDemo()`**: Discards recorded demo, clears prompt

- **Updated `src/states/minigame_state.lua`**: Routes input events to demo recorder
  - **Modified `keypressed()`**:
    - Records keypresses during active gameplay via `demoRecorder:recordKeyPressed(key)`
    - Handles [S] key in overlay to save demo
    - Handles [D] key in overlay to discard demo
    - Discards unsaved demo when restarting (ENTER) or closing (ESC)
  - **Modified `keyreleased()`**: Records key releases via `demoRecorder:recordKeyReleased(key)`

- **Updated `src/views/minigame_view.lua`**: Shows "Save Demo?" prompt on completion overlay
  - **Modified `drawOverlay()`**: Renders demo save prompt if `snapshot.show_save_demo_prompt`
    - Displays "Demo recorded! Save it for VM use?"
    - Shows "[S] Save Demo" and "[D] Discard" options
    - Cyan highlight for prompt visibility

**What Will Be Noticed In-Game:**
- **FULL DEMO SYSTEM NOW FUNCTIONAL!**
- After completing ANY minigame:
  - Overlay shows "Demo recorded! Save it for VM use?"
  - Press [S] to save the demo (auto-named "{Game Name} Demo")
  - Press [D] to discard the demo
  - Demos automatically discard if you press ENTER (restart) or ESC (close) without saving
- **Saved demos immediately available** in VM Manager:
  - Open VM Manager
  - Click empty slot → game selection appears
  - Only games with saved demos show up
  - Select game → demo selection shows your saved demos
  - Assign demo to VM → VM starts running!
- **VMs now actually work** - complete gameplay loop functional!

**Testing Steps:**
- [ ] Launch game, play any minigame to completion
- [ ] Overlay shows "Demo recorded! Save it for VM use?"
- [ ] Press [S] → demo saved, message in console
- [ ] Open VM Manager → game appears in selection
- [ ] Assign demo to VM slot → VM shows RUNNING state
- [ ] VM stats update (runs, success rate, tokens/min)
- [ ] Tokens accumulate from VM runs
- [ ] Play same game again → Press [D] to discard demo
- [ ] Restart with ENTER without saving → demo discarded
- [ ] Close with ESC without saving → demo discarded

**Known Issues / Future Work:**
- **No way to rename demos yet** - all use auto-generated names ("{Game} Demo")
- **No demo management UI** - can't view/delete/rename existing demos (Phase 8)
- **No visual recording indicator** during gameplay - players don't know recording is happening
- **Demo names not unique** - multiple recordings of same game have identical names
  - PlayerData generates unique IDs but UI shows generic name
  - Future: Add timestamp or counter to auto-names, or prompt for custom name
- **No live playback window** - can't watch VMs executing (Phase 6)
- **No demo validation** - corrupt/invalid demos might crash VMs
- **No demo metadata editor** - can't add notes/descriptions after recording
- **Recording continues even if game crashes** - might create invalid demos
- **No "record indicator" in UI** - players might not realize they're being recorded

**Architectural Notes:**
- Recording happens automatically for ALL minigame completions (no opt-in/opt-out)
- Demo recording uses fixed timestep (60 FPS) via `demoRecorder:fixedUpdate()`
- Input recording happens at MinigameState level (before passing to game)
- Controller owns save/discard logic, view only displays prompt
- Demos auto-named with "{Game Display Name} Demo" format
- PlayerData:saveDemo() generates unique ID: `"demo_{game_id}_{timestamp}"`
- Unsaved demos automatically discarded on restart/close (prevents accidental loss of saves)
- Recording starts in `begin()`, stops in `processCompletion()` (always captures full run)
- Works with all game types (DodgeGame, SnakeGame, MemoryMatch, HiddenObject)

**Integration Points:**
- Phase 6 will add live VM playback window (watch demos executing)
- Phase 7 could add recording indicators during gameplay
- Phase 8 will add demo management UI (rename, delete, view all demos)
- Phase 9 could add demo export/import/sharing

**Demo Recording Workflow:**
1. Game starts → Controller calls `demoRecorder:startRecording()`
2. Player plays → MinigameState routes inputs to `demoRecorder:recordKeyPressed/Released()`
3. Every frame → Controller calls `demoRecorder:fixedUpdate()` to track frame count
4. Game completes → Controller calls `demoRecorder:stopRecording()`, gets demo data
5. Overlay shows → Player presses [S] to save or [D]/ENTER/ESC to discard
6. If saved → Demo added to `player_data.demos`, available in VM Manager

---

### Phase 6: Live VM Playback Window

**Goal:** Visualize a single VM running in real-time.

**Components to Create:**
- **Program: "VM Playback"**
  - Window showing live game execution
  - HUD overlay with current run stats
  - Same rendering as normal minigame
  - Read-only (no input accepted)

- **View: `VMPlaybackView`** (`src/views/vm_playback_view.lua`)
  - Render game state from VM's game_instance
  - Draw HUD: run number, tokens this run, frames elapsed
  - Show demo input visualization (which keys pressed)
  - Show VM speed indicator (e.g., "VM Running at 10x, Display at 1x")
  - Victory/Death overlay with brief result display

- **State: `VMPlaybackState`** (`src/states/vm_playback_state.lua`)
  - References a specific VM slot
  - Updates game instance visualization
  - Handles window close (doesn't stop VM)

**Architectural Considerations:**
- VMPlaybackState receives VM slot reference via DI or parameters
- Reads game state from VMManager (doesn't own the game)
- Pure visualization - doesn't affect VM execution
- Closing window doesn't stop VM
- Can open multiple playback windows for different slots
- **Critical:** Playback renders at 1x speed even if VM runs at 10x or instant
  - Shows "slow motion" replay of what VM is actually doing
  - Allows watching fast VMs in detail
  - Headless VMs can't be watched (no game state to render)

**User Flow:**
1. Open VM Manager
2. Select a running VM slot
3. Click "Watch" button
4. VM Playback window opens
5. See game playing with demo inputs
6. Window updates in real-time as VM loops

**File Changes:**
- New: `src/states/vm_playback_state.lua`
- New: `src/views/vm_playback_view.lua`
- Modified: `assets/data/programs.json` (add VM Playback program)
- Modified: `src/controllers/vm_manager_controller.lua` (launch playback window)

---

### Phase 7: Integration & Polish

**Goal:** Connect all systems and handle edge cases.

**Tasks:**
- **Event Bus Integration:**
  - `demo_recording_started` → Show recording indicator in game
  - `demo_recording_completed` → Prompt for demo assignment
  - `vm_run_completed` → Update UI stats if VM window open
  - `demo_deleted` → Remove from assigned VMs, show warning
  - `game_unlocked` → Enable demo recording for that game

- **Save/Load Robustness:**
  - Handle missing demos (reference but file gone)
  - Handle corrupted demo data (validate on load)
  - Versioning for demo format changes
  - Migration path if demo structure changes

- **UI Polish:**
  - Demo recording indicator (red dot in corner)
  - VM status icons (running/idle/error)
  - Tooltips explaining success rates
  - Confirmation dialogs for destructive actions
  - Help text explaining demo system to new players

- **Edge Cases:**
  - Demo recorded but game variant changed (CheatEngine mods)
  - VM running when player closes game (save state, restore)
  - VM assigned to deleted/locked game
  - Demo playback desyncs (rare, but handle gracefully)
  - Zero token runs (game died instantly)

- **Tutorial/Onboarding:**
  - First time completing a game: tutorial popup
  - Explain demo recording concept
  - Guide to first VM assignment
  - Tips for improving demo quality

**File Changes:**
- Modified: All integration points (many files)
- New: `documentation/vm_system_tutorial.md` (player-facing guide)
- Modified: `src/utils/save_manager.lua` (save format versioning)

---

### Phase 8: Performance & Optimization

**Goal:** Ensure system performs well with many VMs.

**Tasks:**
- **Simulation Performance:**
  - Profile game loop performance (target: 100+ VMs at 60 FPS)
  - Optimize game instances for headless execution (no rendering overhead)
  - VMs not being watched can use higher speed multipliers
  - Batch statistics updates (not every frame)
  - Fixed timestep ensures consistent performance regardless of visual framerate

- **Memory Management:**
  - Limit total simultaneous game instances
  - Prioritize visible VMs (full simulation)
  - Background VMs use reduced simulation
  - Garbage collection tuning

- **Save Performance:**
  - Don't save VM state every frame
  - Batch saves (every 10 runs or 30 seconds)
  - Incremental saves (only changed data)

- **UI Responsiveness:**
  - Update VM Manager view at lower frequency (10 FPS)
  - Use dirty flags for stat updates
  - Throttle event bus emissions from high-frequency events

**Benchmarking Targets:**
- 10 VMs at 1x speed: No noticeable performance impact
- 10 VMs at 10x speed: Slight CPU load, smooth visual framerate
- 10 VMs at instant/headless: Minimal impact (no rendering)
- 50 VMs mixed speeds: Acceptable performance on mid-range hardware
- 100+ VMs (mostly headless): CPU-bound, visual VMs may need speed caps
- 1000+ VMs: Future optimization phase (statistical sampling)

**File Changes:**
- Modified: `src/models/vm_manager.lua` (performance tuning, speed management)
- Modified: All game classes (headless mode flags, fixed timestep if missing)
- Modified: `src/models/demo_player.lua` (optimize for speed multipliers)

---

### Phase 9: Future Expansion (Statistical Sampling)

**Goal:** Support millions of VMs via statistical extrapolation.

**NOT PART OF INITIAL IMPLEMENTATION. Future phase when player can purchase millions of VMs.**

**Concept:**
- Player has 1,000,000+ VM instances
- Can't actually simulate all of them
- System runs 10-100 actual VMs
- Calculates statistical baseline (avg tokens/sec)
- Multiplies by instance count
- Adds minor variance for realism

**Implementation:**
- Add VM "pools" (groupings of identical VMs)
- Pool runs small sample, extrapolates
- UI shows: "1,000,000 VMs (100 active samples)"
- Periodically re-sample to update baseline

**Defer until late-game balance requires it.**

---

## Summary of Architecture

**Models (Business Logic):**
- `DemoRecorder` - Captures input events with timestamps
- `DemoPlayer` - Plays back demos into game instances
- `VMManager` - Manages VM slots, execution loops, statistics
- `PlayerData` - Stores demos and VM state

**Views (Presentation):**
- `VMManagerView` - Grid of VM slots with stats
- `VMPlaybackView` - Live game visualization
- `DemoSelectionView` - List and manage demos

**Controllers/States:**
- `VMManagerController` - Mediates VM management
- `VMPlaybackState` - Owns playback window state
- `MinigameController` - Extended to support recording mode

**Data Files:**
- Demos stored in player save data (JSON)
- VM state persisted in save file
- Demo format versioned for migrations

**Event Bus Events:**
- `demo_recording_started`, `demo_recording_completed`
- `demo_playback_started`, `demo_playback_completed`
- `vm_run_completed`, `vm_stats_updated`
- `demo_deleted`, `demo_selected`

**Config Values (add to `config.lua`):**
```lua
vm_demo = {
    fixed_dt = 1/60, -- Fixed timestep for recording/playback (60 FPS)
    restart_delay = 0.1, -- Seconds between runs (visual feedback)
    max_demo_frames = 18000, -- Max frames (~5 minutes at 60 FPS)
    min_demo_frames = 60, -- Min frames (~1 second at 60 FPS)
    stats_update_interval = 1.0, -- Update UI stats every second
    save_frequency = 30, -- Save VM state every 30 seconds

    -- Speed upgrade system (levels defined in balance, not here)
    max_visual_speed_multiplier = 100, -- Cap for rendered VMs
    headless_speed_label = "INSTANT", -- UI label for headless mode
}
```

---

## Testing Strategy

**Manual Testing Checklist:**

**Phase 1-2 (Recording & Playback):**
- [ ] Record demo of dodge game
- [ ] Verify inputs captured with correct frame numbers
- [ ] Play back demo at 1x speed, confirm identical movement
- [ ] Test playback with different random seeds
- [ ] Verify different outcomes per seed
- [ ] Test fixed timestep determinism (record at various FPS, playback identical)
- [ ] Test multi-step playback (2x, 4x, 10x speed multipliers)
- [ ] Test headless mode (instant completion, no rendering)

**Phase 3-4 (VM Execution):**
- [ ] Assign demo to VM slot at 1x speed
- [ ] Verify continuous run loop (watch 10+ runs)
- [ ] Confirm tokens accumulate correctly
- [ ] Check statistics accuracy (success rate)
- [ ] Test speed upgrades (2x, 4x, 10x, instant)
- [ ] Verify headless mode completes runs in milliseconds
- [ ] Test mixed speed VMs (some 1x, some instant)
- [ ] Test VM save/restore with different speed settings

**Phase 5-6 (UI & Management):**
- [ ] Open VM Manager window
- [ ] Assign different demos to multiple slots
- [ ] Purchase speed upgrades for specific VMs
- [ ] Watch live playback window (renders at 1x regardless of VM speed)
- [ ] Verify speed indicators display correctly
- [ ] Verify stats display correctly (tokens/min scales with speed)
- [ ] Test demo deletion while assigned to VM
- [ ] Verify playback window shows "slow motion" of fast VM

**Phase 7 (Integration):**
- [ ] Complete game → record demo → assign to VM flow
- [ ] Edge case: delete demo while VM running
- [ ] Edge case: unlock new game during recording
- [ ] Save/load with active VMs

**Performance Testing:**
- [ ] Run 10 VMs at 1x speed, check FPS (should be 60)
- [ ] Run 10 VMs at 10x speed, check FPS (should remain 60)
- [ ] Run 10 VMs at instant/headless, check completion time (should be milliseconds)
- [ ] Run 50 VMs mixed speeds, confirm acceptable performance
- [ ] Profile memory usage over 1 hour of VM operation
- [ ] Test frame timing accuracy (fixed timestep maintains determinism)

---

## Success Criteria

**Minimum Viable Demo System:**
1. Player can record demos from completed games (frame-based)
2. Demos can be assigned to VM slots
3. VMs execute demos in continuous loop with random seeds
4. Fixed timestep ensures deterministic playback
5. Tokens accumulate based on actual run results
6. VM speed upgrades work (1x → multi-step → instant)
7. VM Manager window shows live stats and speed indicators
8. VM Playback window visualizes execution at 1x (regardless of VM speed)
9. System saves/restores VMs across sessions with speed settings

**Good Demo System:**
- Demo quality clearly affects VM success rate
- Players naturally optimize games for VM automation
- CheatEngine integration creates optimization loop
- Speed upgrades feel impactful (watching it go faster is satisfying)
- UI clearly communicates VM performance and speed
- Multiple VMs running at different speeds feels responsive
- Instant mode provides late-game efficiency satisfaction

**Great Demo System:**
- Recording/playback is bug-free and perfectly deterministic (frame-based)
- VMs provide meaningful progression path (early: unreliable, late: perfect)
- Speed progression feels good (1x → 10x → instant)
- Visual feedback is satisfying (watching VMs loop at any speed)
- Demo management is intuitive
- System scales to 100+ VMs without performance issues (mix of speeds)
- Playback window lets you watch fast VMs in slow motion

---

## Known Challenges & Mitigations

**Challenge:** Demo desync (inputs don't produce expected results)
**Mitigation:** Frame-based recording with fixed timestep ensures perfect determinism. Games must use fixed timestep for all simulation. Test thoroughly with seed reproduction across different visual framerates.

**Challenge:** Performance with many VMs
**Mitigation:** Phased approach - start with 10-50 VMs, optimize, then scale. Speed upgrade system naturally guides players: early VMs at 1x (watchable), late VMs at instant (headless). Mix of speeds distributes CPU load. Headless mode eliminates rendering overhead entirely.

**Challenge:** Demo quality is hard to understand for players
**Mitigation:** Clear UI showing success rate. Tutorial explaining concept. In-game feedback during recording.

**Challenge:** Players may not understand why demos fail
**Mitigation:** Playback window shows what went wrong. Stats clearly display failure reasons (if capturable).

**Challenge:** Save file size with many demos
**Mitigation:** Demos are small (just inputs + timestamps). Compress if needed. Limit max demos per game.

---

## Open Questions for Implementation

1. **Demo Versioning:** How to handle demos when game balance changes?
   - Option A: Invalidate old demos (force re-record)
   - Option B: Version demos with game config snapshot
   - **Recommended:** Option B - demos store variant config

2. **VM Slot Limits:** How many VMs can player purchase?
   - Use existing `vm_max_slots` from config (currently 10)
   - Scale cost exponentially
   - Consider UI layout constraints

3. **Demo Storage Location:**
   - Option A: Store in player_data (save file)
   - Option B: Separate demo files (assets/demos/)
   - **Recommended:** Option A - simpler, atomic saves

4. **Fixed Timestep Implementation:** How to ensure games use fixed timestep?
   - Option A: Refactor all games to use accumulator pattern
   - Option B: Add fixed timestep wrapper to base game class
   - **Recommended:** Option B - less invasive, centralized implementation

5. **Speed Upgrade Balancing:** How to price/gate speed upgrades?
   - Defer to balance team (not architectural decision)
   - System supports arbitrary speed levels and costs
   - UI must display speed clearly regardless of specific values

6. **Recording Trigger:** How to initiate demo recording?
   - Option A: Button in minigame HUD (always available)
   - Option B: Prompt after completing game
   - Option C: Toggle in VM Manager before launching game
   - **Recommended:** Combination of A + B

7. **Playback Window Speed Display:** How to show VM is running fast but display is 1x?
   - Option A: HUD text: "VM: 10x, Display: 1x"
   - Option B: Visual indicator (speed icon + slowdown icon)
   - Option C: Tooltip on hover
   - **Recommended:** Option A - clear and always visible

---

## Documentation Rules for AI Assistants

**CRITICAL: After completing each phase, update the phase section with completion notes following this format:**

```markdown
---

### Phase X Completion Notes

**What Has Been Implemented:**
- List of all files created/modified
- List of all features added
- Any architectural decisions made during implementation
- Any deviations from the original plan (with justification)

**What Will Be Noticed In-Game:**
- Player-visible changes
- New UI elements or behaviors
- Any changes to existing gameplay

**Testing Steps:**
- [ ] Specific test case 1
- [ ] Specific test case 2
- [ ] Edge case tests
- [ ] Integration tests with existing systems

**Known Issues / Future Work:**
- Any bugs or limitations discovered
- Items deferred to later phases
- Performance considerations

---
```

**This format MUST be added to every phase after completion. Do not skip this step.**

---

## Conclusion

The VM Demo System transforms VMs from passive formula calculators into active automation tools that require player skill and optimization. By recording and playing back exact keypresses with frame-perfect determinism, players create their own automated strategies and iteratively improve them through CheatEngine optimization.

**Core Loop:**
Play → Record → Assign to VM → Watch it fail → Optimize game → Re-record → Watch it succeed → Upgrade speed → Profit faster

**Key Technical Decisions:**
- **Frame-based recording** (not time-based) ensures perfect determinism
- **Fixed timestep simulation** prevents desync across different framerates
- **Speed upgrade system** creates natural progression (1x → multi-step → instant)
- **Hybrid rendering** allows watching fast VMs in slow motion
- **Headless mode** provides late-game efficiency without visual overhead

This system creates satisfying progression, meaningful player agency, natural integration with CheatEngine, and scalable performance. The phased approach ensures each component can be built, tested, and validated independently before integration.
