# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**10,000 Games Collection** - A meta-game about shovelware game collections, built with LÖVE2D (Love2D 11.4). The game simulates a Windows 98-style desktop environment where players interact with a collection of auto-generated minigames, manage virtual machines to farm tokens, and progress through a Space Defender shooter with performance-based bullet power scaling.

**Framework**: LÖVE2D 11.4 (Lua game framework)
**Architecture**: MVC pattern with State Machine and Dependency Injection

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
    stateMachine = state_machine
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

**Clone System**:
- Base games cloned into variants with scaled difficulty/cost
- Clone families share mechanics but have different multipliers
- Progressive difficulty scaling controlled by `config.lua` parameters

**Space Defender**:
- Main progression gate (20 levels planned, 5 currently implemented)
- Bullet power determined by aggregate performance across minigame library
- Level data in `assets/data/space_defender_levels.json`

### Key Systems

**Window Management**:
- `WindowController` handles window lifecycle, focus, dragging, resizing
- `WindowManager` model stores window positions and state
- `WindowChrome` view renders title bars, borders, buttons
- Windows saved/restored via `window_positions.json`

**Virtual Machines**:
- `VMManager` model handles VM slots, assignments, and token generation
- VMs auto-complete assigned games using formula-based performance
- Upgrades: CPU speed, overclock, auto-dodge affect VM efficiency

**Cheat System**:
- `CheatSystem` model manages active cheats
- Cheats modify game performance, speed, or provide (fake) advantages
- Token costs defined in `config.lua`

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

**Current Phase**: Phase 1 (MVP Foundation)
- 5 unique minigames ✓
- Clone system ✓
- 5 Space Defender levels ✓
- VM automation ✓
- CheatEngine ✓
- Desktop OS with launcher ✓
- Save/load system ✓

**Next Priorities**: Phase 2 (Content Expansion) - 15+ minigames, 20 Space Defender levels

## Common Gotchas

1. **Windows Key Handling**: `love.keypressed` intercepts Windows key (lgui/rgui) to toggle Start Menu - prevents OS Start Menu from opening
2. **Cursor Management**: System cursors loaded in `main.lua`, set via `love.mouse.setCursor()` based on window state
3. **Quit Handling**: `love.quit()` shows custom shutdown dialog unless `_G.APP_ALLOW_QUIT` is true
4. **Auto-save**: Runs every 30 seconds in `love.update()` - saves player data, statistics, window positions
5. **Performance**: Target 60 FPS with 500+ bullets on screen - use object pooling and spatial partitioning
6. **File Paths**: Use `love.filesystem` for save directory, relative paths for assets
7. **Screensaver**: Activates after configurable timeout - any input resets timer

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
