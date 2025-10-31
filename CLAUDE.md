# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**10,000 Games Collection** - A meta-game about treasure hunting in shovelware, built with LÖVE2D (Love2D 11.4). The game simulates a Windows 98-style desktop environment where players **hunt through 10,000 AI-generated minigames** to find exploitable "gems," optimize them with CheatEngine, play them manually for high scores, and optionally automate favorites with VM demo playback.

**The Fiction** (1999 Alternate Timeline):
- You found a CD: "10,000 Games Collection - The Ultimate Gaming CD!"
- Seems normal enough - generic 90s shovelware collection
- As you play, you earn "tokens" - the AI's training currency
- The AI is pretending to be a friendly human developer
- "Hey there, gamer! Thanks for playing my games! Earn tokens, unlock cool stuff!"
- Slowly reveals itself: It needs tokens. It wants you to keep playing. Feed more tokens.
- The games ARE slop (AI-generated, trained on 90s games), but disguised as human-made
- You're unknowingly training an early AI by playing its games and generating tokens
- **Tongue-in-cheek reference**: "Tokens" (AI currency) meets 90s game rewards

**Core Gameplay Loop**: Hunt through AI slop → Find exploitable mechanics → Beat each game once (unlock bullets) → Use CheatEngine to optimize (helps manual play AND automation) → Play manually for best rewards → Record demos for passive VM farming → Collect optimized game portfolio → Feed tokens to the AI → Repeat with harder games

**Multiple Playstyles (all active simultaneously)**:
- **Active Grinder**: Play games manually for better returns than VMs
- **Collector**: Find and optimize games like Pokémon
- **Engineer**: Use CheatEngine to create perfect scenarios
- **Space Defender Main**: Focus on shooter progression with upgrades
- **VM Farmer**: Automate favorites for passive income while doing above

**Framework**: LÖVE2D 11.4 (Lua game framework)
**Architecture**: MVC pattern with State Machine, Dependency Injection, and Event Bus
**Key Innovation**: Frame-based demo recording (like Quake demos) for perfect deterministic playback with speed scaling

## Essential Development Commands

### Running the Game
```bash
# Run with LÖVE installed
love .

# On Windows (if Love is in PATH)
"C:\Program Files\LOVE\love.exe" .
```

### Testing and Development
- **Debug Mode**: Press `F5` in-game to toggle debug overlay (shows player data, game data, and allows manual saves)
- **Tutorial**: Automatically shown on first launch (controlled by `tutorial_shown` setting)
- **Configuration**: Edit `conf.lua` for window settings (currently set to 1920x1080 fullscreen)

### Save Data Location
Save files are stored in LÖVE's save directory:
- Windows: `%APPDATA%\LOVE\10000games\`
- Contains: `save.json`, `settings.json`, `statistics.json`, `window_positions.json`, `desktop_layout.json`

## Architecture Overview

### Dependency Injection System
The codebase uses a central DI container created in `main.lua` and passed to states/controllers:

```lua
local di = {
    config = Config,
    settingsManager = SettingsManager,
    saveManager = SaveManager,
    statistics = statistics,
    playerData = player_data,
    gameData = game_data,
    vmManager = vm_manager,
    cheatSystem = cheat_system,
    windowManager = window_manager,
    desktopIcons = desktop_icons,
    fileSystem = file_system,
    recycleBin = recycle_bin,
    programRegistry = program_registry,
    systemCursors = system_cursors,
    stateMachine = state_machine,
    demoRecorder = demo_recorder,  -- Phase 1: Frame-based input recording
    demoPlayer = demo_player,      -- Phase 2: Deterministic playback engine
    eventBus = event_bus,
    audioManager = audio_manager,
    ttsManager = tts_manager       -- Optional TTS system
}
```

**CRITICAL RULES**:
- Inject **only specific dependencies** via `di` table in constructors
- **NO global reads** of managers (except legacy `_G.DI_CONFIG` which is being phased out)
- **NO god objects** - inject what you need, not everything
- See `documentation/Refactor plan.txt` for ongoing DI improvements

### MVC Pattern

**Models** (`src/models/`):
- Data and business logic only
- NO rendering code or `love.*` calls
- Examples: `player_data.lua`, `game_data.lua`, `vm_manager.lua`, `file_system.lua`

**Views** (`src/views/`):
- Handle ALL drawing/rendering
- May have stateful UI (e.g., scroll positions, hover states)
- Input methods return simple events/intents, **never** directly mutate models
- Receive data from Controllers/States as function parameters
- Examples: `desktop_view.lua`, `launcher_view.lua`, `vm_manager_view.lua`

**States/Controllers** (`src/states/`, `src/controllers/`):
- Mediate between Models and Views
- Handle application flow and user actions
- Validate and mutate models
- Pass data to views for rendering
- Examples: `desktop_state.lua`, `window_controller.lua`, `minigame_controller.lua`

### State Machine
Central state machine (`src/controllers/state_machine.lua`) manages major sections:
- `Constants.state.DESKTOP` - Main desktop environment (most time spent here)
- `Constants.state.COMPLETION` - Game completion screen
- `Constants.state.DEBUG` - Debug overlay (F5)
- `Constants.state.SCREENSAVER` - Screensaver mode

**Window-based states** (launched within DesktopState):
- Launcher, VMManager, SpaceDefender, CheatEngine, Settings, Statistics, FileExplorer, MinigameRunner, Solitaire
- Instantiated by DesktopState, not registered globally in state machine

### Game System Architecture

**Minigames** (`src/games/`):
- All extend `BaseGame` class
- Types: DodgeGame, HiddenObject, MemoryMatch, SnakeGame, SpaceShooter
- Each has performance formulas defined in `assets/data/base_game_definitions.json`
- Metrics tracked → Formula → Token power → Space Defender bullet damage

**Clone System (AI-Generated Slop)**:
- Base games cloned into **10,000 variants** with parameter variations (name is literal!)
- **The AI made these games** - trained on 90s shovelware, attempting to pass as human-made
- Games have generic but plausible names: "Snake Classic", "Snake Plus", "Snake Deluxe"
- **They ARE slop** - AI-generated derivatives, but period-appropriate and functional
- Some are competent, some are broken, some are accidentally brilliant
- Indistinguishable from actual 90s shovelware collections (that's the point)
- **Goal**: Hunt through mountains of AI slop to find "gems" - exploitable combinations
  - Example: Snake variant with no walls + food that moves toward you = can't lose
  - Example: Dodge with 100 lives + tiny obstacles + huge safe zone = trivial
  - Example: Memory Match with 60-second memorization time = free win
- Clone families share mechanics but have wildly different parameters
- **Every game has unique JSON** - different CheatEngine variables locked/unlocked
- Each variant has unique exploit potential
- Players "collect" optimized games like Pokémon
- **At 10,000 games**: 99.9% are trash (just like real shovelware), finding the gems IS the game
- **Development**: Will use AI to generate bulk of variants (authentic AI slop)
- **Technically feasible**: Games are JSON parameter sets, sprites, and shared code - minimal memory per variant

**Space Defender / "Neural Core" (Token Feeding Mechanic)**:
- Main progression gate (20 levels planned, 5 currently implemented)
- **May be reskinned**: Instead of space shooter, could be "feeding the AI" visualization
  - Bullets = Token streams flowing to the AI
  - Enemies = AI processes consuming tokens
  - Bosses = Major computation events
  - Goal: Feed enough tokens to satisfy the AI's hunger
- **Must beat each minigame once to unlock bullets** (no skip-ahead auto-complete)
- Bullet power determined by aggregate performance across minigame library
- **Upgrades available**: Bigger token streams, faster processing, auto-routing, etc.
- Can be played actively as main focus or as progression gate
- Level data in `assets/data/space_defender_levels.json`
- Fiction: The AI needs tokens to "improve" or "solve problems" or... something
- As you progress, the AI's mask slips: "Feed more tokens. Please continue playing."

### Key Systems

**Window Management**:
- `WindowController` handles window lifecycle, focus, dragging, resizing
- `WindowManager` model stores window positions and state
- `WindowChrome` view renders title bars, borders, buttons
- Windows saved/restored via `window_positions.json`

**Virtual Machines** (Passive Income, Scarcity-Based):
- `VMManager` model handles VM slots, demo execution loops, and statistics tracking
- **Purpose**: Automate favorite "gem" games for passive income while playing other games manually
- **Manual play is better** - VMs are convenience, not the main strategy
- **SCARCITY MECHANIC**: Each game can only be assigned to ONE VM initially
  - Can't assign same game to 10 VMs (resource allocation puzzle)
  - Makes finding multiple automatable games crucial
  - Skill tree upgrades allow multiple VMs per game
  - Creates strategic decisions: "Do I VM this mediocre Snake or keep hunting?"
- **PLAYER AGENCY**: Can still spam one gem game - just choose how:
  - Manual grinding (best returns, time-limited)
  - VM automation (passive income while hunting for more)
  - Both! (VM the gem, manually grind it while hunting)
  - No "correct" path - player chooses optimization strategy
- VMs run **recorded demos** (frame-perfect input playback) with random seeds
- **Must play game first** to record demo (can't automate without discovery)
- **Demo Recording**: `DemoRecorder` captures keypresses/releases with exact frame numbers during gameplay
- **Demo Playback**: `DemoPlayer` injects recorded inputs frame-by-frame into game instances
- **Speed Upgrades**: 1x (watchable) → 10x (fast multi-step) → 100x → INSTANT (headless mode)
- VMs can run at high speeds while playback windows display at 1x for visual feedback
- **State Machine**: IDLE → RUNNING (executing demo) → RESTARTING (brief delay between runs) → repeat
- Success rate varies by demo quality + RNG luck + CheatEngine optimizations
- **Finding VM-worthy games is the challenge** - most games too random/hard to automate
- Headless VMs complete runs in milliseconds with no rendering overhead
- **Skill tree planned**: More VM slots, speed upgrades, parallel execution, slots-per-game increases

**CheatEngine System (Core Discovery Mechanic)**:
- `CheatSystem` model manages active cheats and parameter modifications
- **CRITICAL**: Can't see available cheats until you beat a game once (forces exploration)
- **Every game has unique parameters** - different variables locked/unlocked in JSON
- Some games have gamebreaking cheats (instant win, infinite lives)
- Others have useless/fake cheats (part of shovelware satire)
- You won't know what's optimizable until you discover it
- **Purpose**: Optimize games to make them easier AND more rewarding (helps manual play AND VMs)
- Examples: Lives, victory conditions, physics, spawn rates, arena size, movement speed
- Finding the right cheat combinations is part of "collecting" optimized games
- Token costs scale with modifications (defined in `config.lua`)
- **Skill tree planned**: Budget increases, unlock parameter types, cost discounts

## Configuration and Data

### Central Configuration
**`src/config.lua`** - All tuning parameters, costs, multipliers, UI metrics:
- Player/economy values: `start_tokens`, `upgrade_costs`, `vm_base_cost`
- Game difficulty scaling: `clone_cost_exponent`, `clone_difficulty_step`
- UI layout: `config.ui.window`, `config.ui.taskbar`, `config.ui.views.*`
- Game-specific configs: `config.games.dodge`, `config.games.space_defender`, etc.

**ALWAYS** add new tuning values to `config.lua`, not hardcoded in files.

### Constants and Strings
- **`src/constants.lua`**: Enums (state names, program IDs, etc.)
- **`src/paths.lua`**: File path constants
- **`src/utils/strings.lua`**: UI text strings (use `Strings.get('path.key', 'fallback')`)

### External Data Files (`assets/data/`)
- `base_game_definitions.json` - Minigame templates, formulas, metrics
- `programs.json` - Desktop program definitions (window defaults, requirements)
- `filesystem.json` - Fake file system structure
- `space_defender_levels.json` - Level definitions for Space Defender
- `control_panels/*.json` - Control panel configurations
- `strings/ui.json` - Localized/centralized UI strings

**When adding games/programs**: Define in JSON, not Lua code.

## Code Quality Standards

### Error Handling
- **Wrap all file I/O, JSON parsing, and dynamic loads in `pcall`**
- Handle nils safely with fallbacks
- Never crash on missing files - provide defaults

Example:
```lua
local success, data = pcall(json.decode, file_content)
if not success or not data then
    print("Failed to load JSON: " .. tostring(data))
    return default_value
end
```

### Viewport Coordinates vs Screen Coordinates

**CRITICAL: This is a recurring bug when creating new windowed views!**

LÖVE2D has two coordinate systems that must be handled correctly:
- **Viewport coordinates**: Relative to window content area (0,0 = top-left of window viewport)
- **Screen coordinates**: Absolute screen position (includes window position offset)

**Rules for windowed views (views with `drawWindowed()` method):**

1. **NEVER call `love.graphics.origin()` inside windowed views**
   - `origin()` resets to screen coordinates 0,0
   - This causes content to only render when window is at top-left of screen
   - The window transformation matrix is already set up correctly

2. **`love.graphics.setScissor()` requires SCREEN coordinates, not viewport coordinates**
   - Scissor regions must account for window position on desktop
   - Always add `viewport.x` and `viewport.y` offsets

**Correct pattern for scissor in windowed views:**
```lua
function MyView:drawWindowed(viewport_width, viewport_height)
    -- Get window screen position
    local viewport = self.controller.viewport
    local screen_x = viewport and viewport.x or 0
    local screen_y = viewport and viewport.y or 0

    -- Content area in viewport coordinates
    local content_y = 30  -- Below title bar
    local content_height = viewport_height - 30

    -- Scissor MUST use screen coordinates
    love.graphics.setScissor(screen_x, screen_y + content_y, viewport_width, content_height)

    -- Draw using viewport coordinates (not screen)
    love.graphics.print("Text", 10, content_y)

    love.graphics.setScissor()
end
```

**Wrong patterns that cause clipping bugs:**
```lua
-- ❌ WRONG - uses viewport coordinates for scissor
love.graphics.setScissor(0, content_y, viewport_width, content_height)

-- ❌ WRONG - resets to screen coordinates
love.graphics.origin()
love.graphics.print("Text", 10, 10)  -- Will only show if window at 0,0

-- ❌ WRONG - drawing to screen coordinates instead of viewport
local screen_x = viewport.x
love.graphics.print("Text", screen_x + 10, 10)  -- Double offset!
```

**When origin() IS correct:**
- Error screens (fullscreen, no window context)
- Screensavers (fullscreen rendering)
- Drawing to canvases (canvases have their own coordinate space)

**Files with correct implementations:**
- `src/views/credits_view.lua:65` - Scissor with screen offset
- `src/views/minigame_view.lua` - No origin() calls in overlay
- `src/views/file_explorer_view.lua:216` - Address bar scissor with screen offset

### Require Statements
- All `require` calls at **top of file** (file scope)
- Exception: Dynamic game class loading based on type
- Use forward slashes or dots: `require('src.models.player_data')`

### Update Flow Pattern
For inherited game classes, use safe update pattern to avoid mandatory `super` calls:

```lua
function BaseClass:updateBase(dt)
    -- Common update logic all subclasses need
end

function BaseClass:updateGameLogic(dt)
    -- Override in subclasses
end

-- In actual update:
function MinigameState:update(dt)
    self.game:updateBase(dt)      -- Always called
    self.game:updateGameLogic(dt) -- Subclass-specific
end
```

### Object Pooling
Use object pooling for frequently created/destroyed objects:
- Bullets in Space Defender (`src/models/bullet_system.lua`)
- Particles (if implemented)

### Input Handling
- Focused state/window handles input first
- Return `true` if input was handled to prevent propagation
- Global shortcuts only processed if unhandled by focused state

## Important Patterns and Conventions

### Window Interaction
Windows must respect `window_defaults` from program definitions:
- `min_w`, `min_h` - Minimum dimensions
- `resizable` - Can window be resized
- Call `setViewport()` after maximize/restore/resize

### Settings vs. Save Data
- **SettingsManager** (`src/utils/settings_manager.lua`): User preferences (display, audio, tutorial flags)
- **SaveManager** (`src/utils/save_manager.lua`): Game progress (tokens, unlocked games, performance)
- **Separate persistence** - don't mix settings with save data

### Sprite Loading
- `SpriteLoader` (`src/utils/sprite_loader.lua`) - Currently a singleton (being refactored to DI)
- `SpriteManager` and `PaletteManager` - Handle sprite sheets and color palettes
- Sprites loaded from `assets/sprites/`

### Context Menus
- Options built by owning state
- Separators are visual-only (`{ separator = true }`)
- Actions routed through state, not handled in view

## VM Demo Recording & Playback System

**CRITICAL SYSTEM**: This is the core innovation of the game. See `documentation/vm_demo_system.md` for complete design.

### How It Works

**Recording (Automatic)**:
- Every minigame completion automatically records inputs with frame numbers
- Uses fixed timestep (60 FPS) for perfect determinism
- Records: `{ inputs: [{key: 'w', state: 'pressed', frame: 31}, ...], total_frames: 948 }`
- After game ends, player sees prompt: "[S] Save Demo" or "[D] Discard"
- Saved demos stored in `player_data.demos` table, persisted via SaveManager

**Playback (VM Execution)**:
- VMs blindly replay recorded inputs frame-by-frame
- Each run uses random seed → different outcomes
- Success depends on: demo quality + game parameters + RNG luck
- VMs loop endlessly: RUNNING → game completes → RESTARTING → new seed → RUNNING

**Speed System**:
- **1x speed**: One fixed update per visual frame (watchable)
- **Multi-step (2x-100x)**: N fixed updates per visual frame (fast but visible)
- **Headless (INSTANT)**: No rendering, runs to completion in milliseconds

**Key Files**:
- `src/models/demo_recorder.lua` - Input capture with frame counter
- `src/models/demo_player.lua` - Frame-perfect playback engine
- `src/models/vm_manager.lua` - VM state machine and execution loops
- `src/models/player_data.lua` - Demo storage and CRUD operations
- `src/states/vm_playback_state.lua` - Live visualization window
- `src/games/base_game.lua` - Fixed timestep support (`fixedUpdate()`)

**The Actual Gameplay Loop (Multi-Layered Discovery)**:

Every game you beat reveals something new - **4 reasons to engage with the pile**:

1. **Hunt & Discover**: Browse launcher (eventually 10,000 games!) looking for interesting titles
   - Funny names, weird mechanics, glitchy behavior
   - 90s PC gaming nostalgia, bad translations, hidden jokes
   - 99.9% are trash, but finding the 0.1% gems is the game

2. **Beat Once (Required)**: Multiple unlocks happen:
   - **Bullets**: Adds to Space Defender arsenal (mandatory for progression)
   - **CheatEngine**: Reveals unique parameters for that game (can't see until beaten!)
   - **Tokens**: Basic rewards from completion
   - **Demo Recording**: Can now create automation (if game is VM-worthy)

3. **Evaluate**: After beating, discover what you found:
   - Check CheatEngine - does it have gamebreaking cheats? Useless fakes?
   - Is it automatable? (Deterministic mechanics, safe strategies possible?)
   - Is it fun to play manually? (Some optimized games are actually enjoyable)
   - Every game has unique JSON - different variables locked/unlocked

4. **Optimize & Collect**: Build your portfolio
   - Use CheatEngine to create perfect builds (helps manual AND automation)
   - Play manually for best returns (VMs are backup income)
   - Record demo if VM-worthy (but only ONE VM per game initially!)
   - Add to "collection" of perfected games

5. **Strategic Decisions**: Resource allocation puzzle
   - "This Snake is pretty good, but what if there's a better one?"
   - "Do I VM this mediocre game or save the slot?"
   - "Should I invest CheatEngine budget in this or keep exploring?"
   - **Or just grind the one gem manually** (player choice!)
   - Found an amazing game early? Can spam it manually OR automate + hunt more
   - No forced playstyle - optimization path is up to player
   - Skill tree upgrades eventually allow multiple VMs per game

6. **Progress & Repeat**:
   - Tackle Space Defender with accumulated bullet power + upgrades
   - Hunt harder/weirder games as you progress
   - Expand collection, find new exploits, discover hidden gems

**Semi-Active Gameplay**: Player simultaneously:
- Hunting through launcher (sifting for gold)
- Playing 2-3 optimized games in windows (manual best returns)
- Monitoring VMs for passive income
- Tackling Space Defender with shooter upgrades
- Tweaking CheatEngine builds
- Managing multiple skill trees (VMs, CheatEngine, Space Defender, others?)

**If 10,000 Games**: The treasure hunt becomes infinite - community sharing, build guides, "meta" strategies for sifting

**Implementation Status**: Phases 1-6 complete (fully functional)

## AI Development Guidelines

**READ `documentation/AI Guidelines.txt` before making changes** - contains strict rules about:
- Code block formatting (one complete file/function per block)
- No instructions inside code blocks
- Minimal explanatory text outside blocks
- Testing guidance at end of responses

**Key architectural rules**:
1. Always use dependency injection - no global state access
2. Models have no rendering; Views have no business logic
3. Externalize data to JSON files
4. No magic numbers - use `config.lua`
5. Wrap I/O in `pcall`
6. **NEW**: Games MUST support fixed timestep (`fixedUpdate()`) for demo recording
7. **NEW**: VMs execute demos, not formulas - do not add formula-based automation

## Current Refactoring Status

See `documentation/Refactor plan.txt` for detailed roadmap. Key ongoing work:

**Phase 1: DI Consistency**
- Removing global `_G.DI_CONFIG` fallback
- Converting Singleton utilities (SpriteLoader, PaletteManager) to DI

**Phase 2: MVC Boundaries**
- Decoupling views from controllers (passing data explicitly)
- Removing direct property access from views

**Phase 4: Event Bus** (NEW - see `src/utils/event_bus.lua`)
- Replacing return-based communication with pub/sub events
- Current events: `ProgramLaunchRequested`, `WindowCloseRequested`

When making changes, **align with the refactor plan** rather than perpetuating legacy patterns.

## Development Plan

See `documentation/Development Plan.txt` for full roadmap (15 phases, ~120 days).
See `documentation/vm_demo_system.md` for **COMPLETE** VM demo system design and implementation status.

**Current Phase**: Phase 1 (MVP Foundation) + VM Demo System Phases 1-6 **COMPLETE**

**MVP Foundation Status** ✅:
- 5 unique minigames (Dodge, Snake, Memory Match, Hidden Object, Space Shooter) ✓
- Clone system generating 200+ variants ✓
- 5 Space Defender levels with bosses ✓
- Desktop OS with launcher, window management, file explorer ✓
- CheatEngine with parameter modification ✓
- Save/load system ✓

**VM Demo System Status** ✅ (Phases 1-6 Complete):
- ✅ Phase 1: Demo recording infrastructure (`DemoRecorder` model, fixed timestep, input capture)
- ✅ Phase 2: Demo playback engine (`DemoPlayer` model, frame injection, speed multipliers, headless mode)
- ✅ Phase 3: VM execution refactor (replaced formula-based with demo loops, state machine)
- ✅ Phase 4: VM Manager UI (two-step demo assignment flow, live stats display, control buttons)
- ✅ Phase 5: Demo management UI (auto-recording on completion, save/discard prompts)
- ✅ Phase 6: Live VM playback window (watch VMs execute at 1x regardless of speed, HUD overlay)

**Next Priorities**:
- Phase 2 (Content Expansion): 15-20+ minigames, expand to 20 Space Defender levels
- VM Demo System Phase 7: Integration & polish (event bus enhancements, edge case handling)
- VM Demo System Phase 8: Performance optimization (target 100+ VMs, profiling, headless optimization)

## Common Gotchas

1. **Windows Key Handling**: `love.keypressed` intercepts Windows key (lgui/rgui) to toggle Start Menu - prevents OS Start Menu from opening
2. **Cursor Management**: System cursors loaded in `main.lua`, set via `love.mouse.setCursor()` based on window state
3. **Quit Handling**: `love.quit()` shows custom shutdown dialog unless `_G.APP_ALLOW_QUIT` is true
4. **Auto-save**: Runs every 30 seconds in `love.update()` - saves player data, statistics, window positions
5. **Performance**: Target 60 FPS with 500+ bullets on screen - use object pooling and spatial partitioning
6. **File Paths**: Use `love.filesystem` for save directory, relative paths for assets
7. **Screensaver**: Activates after configurable timeout - any input resets timer
8. **Fixed Timestep**: Games use fixed timestep (1/60 sec) for demo recording determinism - call `game:fixedUpdate(dt)` in fixed update loop
9. **Demo Recording**: Automatically records every minigame completion - player chooses to save ([S]) or discard ([D])
10. **VM Execution**: VMs loop demos endlessly with random seeds - success rate depends on demo quality, not formulas
11. **Playback Speed**: VMs can run at 100x speed while playback windows display at 1x for visual feedback

## File Organization

```
├── main.lua                    # Entry point, DI setup, global systems
├── conf.lua                    # LÖVE configuration
├── lib/                        # External libraries (class.lua, json.lua)
├── src/
│   ├── config.lua              # Central tuning parameters
│   ├── constants.lua           # Enums and constants
│   ├── paths.lua               # File path constants
│   ├── controllers/            # State machine, window controller, icon controller
│   ├── models/                 # Business logic and data (no rendering)
│   ├── views/                  # Rendering only (no business logic)
│   ├── states/                 # Application states (combine model + view)
│   ├── games/                  # Minigame implementations
│   │   └── views/              # Game-specific rendering
│   └── utils/                  # Helpers (collision, save, settings, sprite loading)
├── assets/
│   ├── data/                   # JSON data files
│   │   ├── base_game_definitions.json
│   │   ├── programs.json
│   │   ├── filesystem.json
│   │   ├── space_defender_levels.json
│   │   └── control_panels/
│   └── sprites/                # Graphics assets
└── documentation/              # Design docs, plans, guidelines
    ├── AI Guidelines.txt       # MANDATORY reading for code changes
    ├── Development Plan.txt    # Full roadmap
    ├── Refactor plan.txt       # Ongoing architecture improvements
    └── CONTRIBUTING.md         # Architecture checklist
```

## Testing Approach

- **Manual Testing**: Primary method - play through systems after changes
- **Debug Mode** (F5): Inspect state, force saves, view all data
- **Common Test Paths**:
  - Launch minigame → Complete → Check token reward
  - Assign game to VM → Wait for completion → Verify token generation
  - Purchase upgrade → Verify cost deduction and effect
  - Play Space Defender → Check bullet power scaling
  - Close/reopen game → Verify save persistence

## Performance Targets

- **60 FPS** with 150+ bullets (MVP), 500+ bullets (full release)
- Bullet system uses object pooling (`src/models/bullet_system.lua`)
- Space Defender must remain playable with max bullet count
- Profile with high bullet counts during development

## Contact and Resources

- **Issues**: Track in `documentation/todo.txt` or create GitHub issues
- **Design Docs**: See `documentation/` folder
- **AI Workflow**: Follow `documentation/AI Guidelines.txt` strictly
- **Architecture**: Review `documentation/CONTRIBUTING.md` checklist

---

**When in doubt**: Favor existing patterns, use dependency injection, externalize data to JSON, and consult the refactor plan before adding new code.
