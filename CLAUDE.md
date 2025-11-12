CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Project Overview

10,000 Games Collection - A meta-game about treasure hunting in shovelware, built with LÖVE2D (Love2D 11.4). The game simulates a Windows 98-style desktop environment where players hunt through 10,000 AI-generated minigames to find exploitable "gems," optimize them with CheatEngine, play them manually for high scores, and optionally automate favorites with VM demo playback.

The Fiction (1999 Alternate Timeline - Discoverable, Not Presented):
- Surface: You found a 90s shovelware CD with 10,000 games - standard bargain bin fare
- No story presented in gameplay - just a game collection with convenient features
- As you play: Earn tokens, get helpful emails/updates, unlock tools
- First impression: Forgettable quirks (can't reply to emails, TTS voices, generic text, bare-bones website)
- If you explore filesystem: Find generation tools, templates, logs with 1999 timestamps
- The reveal: Cross-reference files (shop webpage uses background22.png, same file in C:\SYSTEM\WEB\, email text matches template_congratulations.txt, voices match voices.cfg)
- The realization: There is no developer. Everything is automated/generated. The games, emails, website, voices - all created by systems.
- Hidden layer: Encrypted files reveal "training data collection" via gameplay, tokens as computational currency
- CRITICAL: This is 100% optional environmental storytelling discoverable through filesystem exploration. You can play and complete the entire game without ever noticing or engaging with any fiction.

The Meta-Layer (4th Wall - Extremely Subtle):
- Steam page has mundane disclosure: "Built with AI" (or similar wording)
- Seems like standard AI tool usage disclaimer - immediately forgettable
- Players won't think about it after buying
- Hours later: Finding in-game generation tools makes you think about real development choices
- Much later: Cross-referencing files, noticing patterns, realizing the parallel between in-game automation (1999) and real development (2024)
- Eventually: Going back to Steam page to link a friend, seeing the disclosure again: "...oh. OH. That's what they meant."
- The realization is earned through discovery and connection, never told or explained
- Works as: Self-aware commentary that never breaks immersion or announces itself
- NOT: Marketing angle, winking joke, or meta-narrative device - just an honest disclosure that recontextualizes

Core Gameplay Loop: Hunt through AI slop → Find exploitable mechanics → Beat each game once (unlock bullets) → Use CheatEngine to optimize (helps manual play AND automation) → Play manually for best rewards → Record demos for passive VM farming → Collect optimized game portfolio → Earn tokens → Feed tokens to Neural Core → Repeat with harder games

Multiple Playstyles (all active simultaneously):
- Active Grinder: Play games manually for better returns than VMs
- Collector: Find and optimize games like Pokémon
- Engineer: Use CheatEngine to create perfect scenarios
- Neural Core Main: Focus on token feeding progression with upgrades
- VM Farmer: Automate favorites for passive income while doing above

Framework: LÖVE2D 11.4 (Lua game framework)
Architecture: MVC pattern with State Machine, Dependency Injection, and Event Bus
Key Innovation: Frame-based demo recording (like Quake demos) for perfect deterministic playback with speed scaling

Essential Development Commands

Running the Game
```bash
love .
"C:\Program Files\LOVE\love.exe" .
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚫 CRITICAL - DO NOT AUTO-RUN THE GAME 🚫
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

NEVER execute the game via Bash commands unless the user EXPLICITLY types "run the game" or similar.

WHY:
- The user is actively playing and testing the game themselves
- Auto-running interrupts their current game session
- The user will close your background process and get frustrated
- Testing happens manually by the user after you finish code changes

WHAT TO DO INSTEAD:
- Make your code changes
- Explain what you changed
- Let the user test it themselves

ONLY run the game if:
- User explicitly says "run the game" or "launch the game" or "test this"
- User asks you to verify something requires seeing the game running

This applies to ALL Bash commands that launch the LÖVE executable.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Testing and Development
- Debug Mode: Press F5 in-game to toggle debug overlay (shows player data, game data, and allows manual saves)
- Tutorial: Automatically shown on first launch (controlled by tutorial_shown setting)
- Configuration: Edit conf.lua for window settings (currently set to 1920x1080 fullscreen)

Save Data Location
Save files are stored in LÖVE's save directory:
- Windows: %APPDATA%\LOVE\10000games\
- Contains: save.json, settings.json, statistics.json, window_positions.json, desktop_layout.json

Architecture Overview

Dependency Injection System
The codebase uses a central DI container created in main.lua and passed to states/controllers:
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
    demoRecorder = demo_recorder,
    demoPlayer = demo_player,
    eventBus = event_bus,
    audioManager = audio_manager,
    ttsManager = tts_manager
}
```

CRITICAL RULES:
- Inject only specific dependencies via di table in constructors
- NO global reads of managers (except legacy _G.DI_CONFIG which is being phased out)
- NO god objects - inject what you need, not everything
- See documentation/Refactor plan.txt for ongoing DI improvements

MVC Pattern

Models (src/models/):
- Data and business logic only
- NO rendering code or love.* calls
- Examples: player_data.lua, game_data.lua, vm_manager.lua, file_system.lua

Views (src/views/):
- Handle ALL drawing/rendering
- May have stateful UI (e.g., scroll positions, hover states)
- Input methods return simple events/intents, never directly mutate models
- Receive data from Controllers/States as function parameters
- Examples: desktop_view.lua, launcher_view.lua, vm_manager_view.lua

States/Controllers (src/states/, src/controllers/):
- Mediate between Models and Views
- Handle application flow and user actions
- Validate and mutate models
- Pass data to views for rendering
- Examples: desktop_state.lua, window_controller.lua, minigame_controller.lua

State Machine
Central state machine (src/controllers/state_machine.lua) manages major sections:
- Constants.state.DESKTOP - Main desktop environment (most time spent here)
- Constants.state.COMPLETION - Game completion screen
- Constants.state.DEBUG - Debug overlay (F5)
- Constants.state.SCREENSAVER - Screensaver mode

Window-based states (launched within DesktopState):
- Launcher, VMManager, NeuralCore, CheatEngine, Settings, Statistics, FileExplorer, MinigameRunner, Solitaire
- Instantiated by DesktopState, not registered globally in state machine

Game System Architecture

Minigames (src/games/):
- All extend BaseGame class
- Types: DodgeGame, HiddenObject, MemoryMatch, SnakeGame, SpaceShooter
- Each has performance formulas defined in assets/data/base_game_definitions.json
- Metrics tracked → Formula → Token power → Neural Core bullet damage

Clone System (AI-Generated Slop):
- Base games cloned into 10,000 variants with parameter variations (name is literal!)
- Games have generic but plausible names: "Snake Classic", "Snake Plus", "Snake Deluxe"
- They ARE AI-generated - procedurally generated derivatives with varying parameters
- Some are competent, some are broken, some are accidentally brilliant
- Indistinguishable from actual 90s shovelware collections (that's the aesthetic)
- Goal: Hunt through mountains of procedural variants to find "gems" - exploitable combinations
  - Example: Snake variant with no walls + food that moves toward you = can't lose
  - Example: Dodge with 100 lives + tiny obstacles + huge safe zone = trivial
  - Example: Memory Match with 60-second memorization time = free win
- Clone families share mechanics but have wildly different parameters
- Every game has unique JSON - different CheatEngine variables locked/unlocked
- Each variant has unique exploit potential
- Players "collect" optimized games like Pokémon
- At 10,000 games: 99.9% are trash (just like real shovelware), finding the gems IS the game
- Development: Will use AI to generate bulk of variants (authentic procedural slop)
- Technically feasible: Games are JSON parameter sets, sprites, and shared code - minimal memory per variant

Neural Core (Main Progression Gate - Replaces "Space Defender"):
- Vertical scrolling shooter aesthetic BUT reframed as token feeding interface
- Main progression gate that gives purpose to token collection
- The Bullet System: Every completed game = 1 bullet in Neural Core
  - Bullet damage = exact token value from that game's performance
  - When bullets fire, they're literally feeding that game's tokens to the system
  - All bullets fire simultaneously = entire game library feeding tokens at once
  - Example: Snake Classic (1,200 tokens) = 1 bullet doing 1,200 damage = feeding 1,200 tokens/shot
- Level Requirements = Token Thresholds:
  - Level 1: 50,000 tokens needed
  - Level 3: 500,000 tokens → System generates CHEAT_ENGINE.EXE
  - Level 5: 2,000,000 tokens → System generates more tools
  - Level 20: 1,000,000,000,000 tokens (1 trillion) → System objective complete
- The Ambiguity: Are you beating levels, or is the AI using you to reach its token goal?
- Visual: Token streams flowing upward, processing nodes consuming tokens, not traditional "enemies"
- UI reframes everything: "PROCESSING REQUEST", "Tokens Required", "Tokens Supplied", "PROCESSING COMPLETE"
- After level completion: System generates tools using consumed tokens (VM_MANAGER, CheatEngine, etc.)
- Must beat each minigame once to unlock bullets (no skip-ahead auto-complete)
- Upgrades available: Fire rate, damage multipliers, auto-dodge, etc.
- Can be played actively as main focus or as progression gate
- Level data in assets/data/neural_core_levels.json (will need to be created/renamed from space_defender_levels.json)

Key Systems

Window Management:
- WindowController handles window lifecycle, focus, dragging, resizing
- WindowManager model stores window positions and state
- WindowChrome view renders title bars, borders, buttons
- Windows saved/restored via window_positions.json

Virtual Machines (Passive Income, Scarcity-Based):
- VMManager model handles VM slots, demo execution loops, and statistics tracking
- Purpose: Automate favorite "gem" games for passive income while playing other games manually
- Manual play is better - VMs are convenience, not the main strategy
- SCARCITY MECHANIC: Each game can only be assigned to ONE VM initially
  - Can't assign same game to 10 VMs (resource allocation puzzle)
  - Makes finding multiple automatable games crucial
  - Skill tree upgrades allow multiple VMs per game
  - Creates strategic decisions: "Do I VM this mediocre Snake or keep hunting?"
- PLAYER AGENCY: Can still spam one gem game - just choose how:
  - Manual grinding (best returns, time-limited)
  - VM automation (passive income while hunting for more)
  - Both! (VM the gem, manually grind it while hunting)
  - No "correct" path - player chooses optimization strategy
- VMs run recorded demos (frame-perfect input playback) with random seeds
- Must play game first to record demo (can't automate without discovery)
- Demo Recording: DemoRecorder captures keypresses/releases with exact frame numbers during gameplay
- Demo Playback: DemoPlayer injects recorded inputs frame-by-frame into game instances
- Speed Upgrades: 1x (watchable) → 10x (fast multi-step) → 100x → INSTANT (headless mode)
- VMs can run at high speeds while playback windows display at 1x for visual feedback
- State Machine: IDLE → RUNNING (executing demo) → RESTARTING (brief delay between runs) → repeat
- Success rate varies by demo quality + RNG luck + CheatEngine optimizations
- Finding VM-worthy games is the challenge - most games too random/hard to automate
- Headless VMs complete runs in milliseconds with no rendering overhead
- Skill tree planned: More VM slots, speed upgrades, parallel execution, slots-per-game increases
- FUTURE CONSIDERATION: VM Learning System (not yet implemented)
  - VMs could potentially improve beyond demo quality over time
  - After N iterations, start recognizing patterns and optimizing
  - Eventually achieve near-perfect play, surpassing player performance
  - Would add meta-layer: Player trains AI models through demonstration
  - Would create progression: Demo playback → Pattern learning → Autonomous mastery
  - If implemented: Add UI for learning progress, emergent behaviors, transfer learning
  - Thematic fit: "You're training your replacement" commentary on automation

CheatEngine System (Core Discovery Mechanic):
- CheatSystem model manages active cheats and parameter modifications
- CRITICAL: Can't see available cheats until you beat a game once (forces exploration)
- Every game has unique parameters - different variables locked/unlocked in JSON
- Some games have gamebreaking cheats (instant win, infinite lives)
- Others have useless/fake cheats (part of shovelware satire)
- You won't know what's optimizable until you discover it
- Purpose: Optimize games to make them easier AND more rewarding (helps manual play AND VMs)
- Examples: Lives, victory conditions, physics, spawn rates, arena size, movement speed
- Finding the right cheat combinations is part of "collecting" optimized games
- Token costs scale with modifications (defined in config.lua)
- THEMATIC: The AI WANTS you to cheat
  - CheatEngine is delivered by the system after Level 3
  - Not a "fun bonus" - it's an efficiency tool
  - System RECOMMENDS modifications with projected gains
  - Goal: Maximize token generation per game
  - The AI doesn't care about "fair play" - only optimization
  - Finding exploits is encouraged, not punished
  - Delivered as: "This tool will improve token generation efficiency"
- Skill tree planned: Budget increases, unlock parameter types, cost discounts

Configuration and Data

Central Configuration
src/config.lua - All tuning parameters, costs, multipliers, UI metrics:
- Player/economy values: start_tokens, upgrade_costs, vm_base_cost
- Game difficulty scaling: clone_cost_exponent, clone_difficulty_step
- UI layout: config.ui.window, config.ui.taskbar, config.ui.views.*
- Game-specific configs: config.games.dodge, config.games.neural_core, etc.

ALWAYS add new tuning values to config.lua, not hardcoded in files.

Constants and Strings
- src/constants.lua: Enums (state names, program IDs, etc.)
- src/paths.lua: File path constants
- src/utils/strings.lua: UI text strings (use Strings.get('path.key', 'fallback'))

External Data Files (assets/data/)
- base_game_definitions.json - Minigame templates, formulas, metrics
- programs.json - Desktop program definitions (window defaults, requirements)
- filesystem.json - Fake file system structure
- neural_core_levels.json - Level definitions for Neural Core (rename from space_defender_levels.json)
- control_panels/*.json - Control panel configurations
- strings/ui.json - Localized/centralized UI strings

When adding games/programs: Define in JSON, not Lua code.

Code Quality Standards

Error Handling
- Wrap all file I/O, JSON parsing, and dynamic loads in pcall
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

Viewport Coordinates vs Screen Coordinates

CRITICAL: This is a recurring bug when creating new windowed views!

LÖVE2D has two coordinate systems that must be handled correctly:
- Viewport coordinates: Relative to window content area (0,0 = top-left of window viewport)
- Screen coordinates: Absolute screen position (includes window position offset)

Rules for windowed views (views with drawWindowed() method):

1. NEVER call love.graphics.origin() inside windowed views
   - origin() resets to screen coordinates 0,0
   - This causes content to only render when window is at top-left of screen
   - The window transformation matrix is already set up correctly

2. love.graphics.setScissor() requires SCREEN coordinates, not viewport coordinates
   - Scissor regions must account for window position on desktop
   - Always add viewport.x and viewport.y offsets

Correct pattern for scissor in windowed views:
```lua
function MyView:drawWindowed(viewport_width, viewport_height)
    local viewport = self.controller.viewport
    local screen_x = viewport and viewport.x or 0
    local screen_y = viewport and viewport.y or 0
    
    local content_y = 30
    local content_height = viewport_height - 30
    
    love.graphics.setScissor(screen_x, screen_y + content_y, viewport_width, content_height)
    love.graphics.print("Text", 10, content_y)
    love.graphics.setScissor()
end
```

When origin() IS correct:
- Error screens (fullscreen, no window context)
- Screensavers (fullscreen rendering)
- Drawing to canvases (canvases have their own coordinate space)

Scrollbar System (ScrollbarController)

CRITICAL: ALWAYS use ScrollbarController - NEVER create custom scrollbars!

The game has a ScrollbarController (src/controllers/scrollbar_controller.lua) that encapsulates:
- Scrollbar state (dragging, position, geometry)
- All interaction logic (mousepressed, mousemoved, mousereleased)
- Integration with UIComponents for rendering

Rules for scrollbars in windowed views:

1. NEVER create a custom scrollbar - use ScrollbarController
2. State creates and owns ScrollbarController instance(s)
3. View calls compute() and draws using UIComponents.drawScrollbar()
4. State handles all mouse events through controller methods

Pattern for scrollbar in states:

```lua
-- In State:init()
local ScrollbarController = require('src.controllers.scrollbar_controller')

-- Create scrollbar controller
self.scrollbar = ScrollbarController:new({
    unit_size = 30,     -- Size of one scrollable unit (item height or 1 for pixels)
    step_units = 1      -- How many units to scroll per arrow click
})

-- In State:mousepressed(x, y, button)
-- Handle scrollbar FIRST before other interactions
local scroll_event = self.scrollbar:mousepressed(x, y, button, self.scroll_offset)
if scroll_event then
    if scroll_event.scrolled then
        -- Update scroll offset with clamping
        local max_offset = math.max(0, total_items - visible_items)
        self.scroll_offset = math.max(0, math.min(scroll_event.new_offset, max_offset))
    end
    return true  -- Consumed the click
end

-- In State:mousemoved(x, y, dx, dy)
-- Handle scrollbar dragging
local scroll_event = self.scrollbar:mousemoved(x, y, dx, dy)
if scroll_event then
    if scroll_event.scrolled then
        local max_offset = math.max(0, total_items - visible_items)
        self.scroll_offset = math.max(0, math.min(scroll_event.new_offset, max_offset))
    end
    return true
end

-- In State:mousereleased(x, y, button)
-- End scrollbar dragging
if self.scrollbar:mousereleased(x, y, button) then
    return true
end
```

Pattern for scrollbar in views:

```lua
-- In View:drawWindowed()
if max_scroll > 0 then
    local scrollbar = self.controller.scrollbar

    -- Set scrollbar position (where it's drawn on screen)
    scrollbar:setPosition(0, content_y)

    -- Compute geometry (returns nil if scrollbar not needed)
    local geom = scrollbar:compute(
        viewport_width,    -- Viewport width
        content_height,    -- Visible area height
        total_height,      -- Total content height
        scroll_offset,     -- Current scroll position
        max_scroll         -- Maximum scroll value
    )

    if geom then
        -- Draw scrollbar (already positioned via setPosition)
        love.graphics.push()
        love.graphics.translate(0, content_y)
        UIComponents.drawScrollbar(geom)
        love.graphics.pop()
    end
end
```

Multiple Scrollbars (e.g., VM Manager):

```lua
-- In State:init() - Create multiple controllers for different contexts
self.modal_scrollbar = ScrollbarController:new({unit_size = 35, step_units = 1})  -- For modals
self.grid_scrollbar = ScrollbarController:new({unit_size = 1, step_units = 100})  -- For main grid

-- In State:mousepressed() - Use correct controller based on context
if self.view.modal_open then
    local scroll_event = self.modal_scrollbar:mousepressed(x, y, button, self.modal_scroll)
    -- Handle modal scrolling
else
    local scroll_event = self.grid_scrollbar:mousepressed(x, y, button, self.grid_scroll)
    -- Handle grid scrolling
end
```

Key points:
- ScrollbarController encapsulates ALL state and interaction logic
- States own controller instances (one or more depending on UI needs)
- Views only call compute() and draw - NO interaction handling in views
- Mouse coordinates in state handlers are LOCAL to window (not screen coords)
- unit_size = 1 for pixel-based scrolling, item height for item-based scrolling
- Always handle mousepressed, mousemoved, and mousereleased for full functionality
- For integer item scrolling, use math.floor() on new_offset

Examples: See web_browser_state.lua, cheat_engine_state.lua, launcher_state.lua, vm_manager_state.lua

Require Statements
- All require calls at top of file (file scope)
- Exception: Dynamic game class loading based on type
- Use forward slashes or dots: require('src.models.player_data')

Update Flow Pattern
For inherited game classes, use safe update pattern to avoid mandatory super calls:
```lua
function BaseClass:updateBase(dt)
    -- Common update logic all subclasses need
end

function BaseClass:updateGameLogic(dt)
    -- Override in subclasses
end

function MinigameState:update(dt)
    self.game:updateBase(dt)
    self.game:updateGameLogic(dt)
end
```

Object Pooling
Use object pooling for frequently created/destroyed objects:
- Bullets in Neural Core (src/models/bullet_system.lua)
- Particles (if implemented)

Input Handling
- Focused state/window handles input first
- Return true if input was handled to prevent propagation
- Global shortcuts only processed if unhandled by focused state

Important Patterns and Conventions

Window Interaction
Windows must respect window_defaults from program definitions:
- min_w, min_h - Minimum dimensions
- resizable - Can window be resized
- Call setViewport() after maximize/restore/resize

Settings vs. Save Data
- SettingsManager (src/utils/settings_manager.lua): User preferences (display, audio, tutorial flags)
- SaveManager (src/utils/save_manager.lua): Game progress (tokens, unlocked games, performance)
- Separate persistence - don't mix settings with save data

Sprite Loading
- SpriteLoader (src/utils/sprite_loader.lua) - Currently a singleton (being refactored to DI)
- SpriteManager and PaletteManager - Handle sprite sheets and color palettes
- Sprites loaded from assets/sprites/
- PixelLab AI Sprite Generation: Available via MCP integration
  - API Documentation: https://api.pixellab.ai/mcp/docs
  - Capabilities: Characters (4/8 directions), animations, isometric tiles, top-down tilesets, sidescroller tilesets, map objects
  - See "PixelLab MCP Integration" section below for usage details

Context Menus
- Options built by owning state
- Separators are visual-only ({ separator = true })
- Actions routed through state, not handled in view

VM Demo Recording & Playback System

CRITICAL SYSTEM: This is the core innovation of the game. See documentation/vm_demo_system.md for complete design.

How It Works

Recording (Automatic):
- Every minigame completion automatically records inputs with frame numbers
- Uses fixed timestep (60 FPS) for perfect determinism
- Records: { inputs: [{key: 'w', state: 'pressed', frame: 31}, ...], total_frames: 948 }
- After game ends, player sees prompt: "[S] Save Demo" or "[D] Discard"
- Saved demos stored in player_data.demos table, persisted via SaveManager

Playback (VM Execution):
- VMs blindly replay recorded inputs frame-by-frame
- Each run uses random seed → different outcomes
- Success depends on: demo quality + game parameters + RNG luck
- VMs loop endlessly: RUNNING → game completes → RESTARTING → new seed → RUNNING

Speed System:
- 1x speed: One fixed update per visual frame (watchable)
- Multi-step (2x-100x): N fixed updates per visual frame (fast but visible)
- Headless (INSTANT): No rendering, runs to completion in milliseconds

Key Files:
- src/models/demo_recorder.lua - Input capture with frame counter
- src/models/demo_player.lua - Frame-perfect playback engine
- src/models/vm_manager.lua - VM state machine and execution loops
- src/models/player_data.lua - Demo storage and CRUD operations
- src/states/vm_playback_state.lua - Live visualization window
- src/games/base_game.lua - Fixed timestep support (fixedUpdate())

The Actual Gameplay Loop (Multi-Layered Discovery):

Every game you beat reveals something new - 4 reasons to engage with the pile:

1. Hunt & Discover: Browse launcher (eventually 10,000 games!) looking for interesting titles
   - Funny names, weird mechanics, glitchy behavior
   - 90s PC gaming nostalgia, bad translations, hidden jokes
   - 99.9% are trash, but finding the 0.1% gems is the game

2. Beat Once (Required): Multiple unlocks happen:
   - Bullets: Adds to Neural Core arsenal (mandatory for progression)
   - CheatEngine: Reveals unique parameters for that game (can't see until beaten!)
   - Tokens: Basic rewards from completion
   - Demo Recording: Can now create automation (if game is VM-worthy)

3. Evaluate: After beating, discover what you found:
   - Check CheatEngine - does it have gamebreaking cheats? Useless fakes?
   - Is it automatable? (Deterministic mechanics, safe strategies possible?)
   - Is it fun to play manually? (Some optimized games are actually enjoyable)
   - Every game has unique JSON - different variables locked/unlocked

4. Optimize & Collect: Build your portfolio
   - Use CheatEngine to create perfect builds (helps manual AND automation)
   - Play manually for best returns (VMs are backup income)
   - Record demo if VM-worthy (but only ONE VM per game initially!)
   - Add to "collection" of perfected games

5. Strategic Decisions: Resource allocation puzzle
   - "This Snake is pretty good, but what if there's a better one?"
   - "Do I VM this mediocre game or save the slot?"
   - "Should I invest CheatEngine budget in this or keep exploring?"
   - Or just grind the one gem manually (player choice!)
   - Found an amazing game early? Can spam it manually OR automate + hunt more
   - No forced playstyle - optimization path is up to player
   - Skill tree upgrades eventually allow multiple VMs per game

6. Progress & Repeat:
   - Tackle Neural Core with accumulated bullet power + upgrades
   - Hunt harder/weirder games as you progress
   - Expand collection, find new exploits, discover hidden gems

Semi-Active Gameplay: Player simultaneously:
- Hunting through launcher (sifting for gold)
- Playing 2-3 optimized games in windows (manual best returns)
- Monitoring VMs for passive income
- Tackling Neural Core with shooter upgrades
- Tweaking CheatEngine builds
- Managing multiple skill trees (VMs, CheatEngine, Neural Core, others?)

If 10,000 Games: The treasure hunt becomes infinite - community sharing, build guides, "meta" strategies for sifting

Implementation Status: Phases 1-6 complete (fully functional)

AI Development Guidelines

READ documentation/AI Guidelines.txt before making changes - contains strict rules about:
- Code block formatting (one complete file/function per block)
- No instructions inside code blocks
- Minimal explanatory text outside blocks
- Testing guidance at end of responses

Key architectural rules:
1. Always use dependency injection - no global state access
2. Models have no rendering; Views have no business logic
3. Externalize data to JSON files
4. No magic numbers - use config.lua
5. Wrap I/O in pcall
6. NEW: Games MUST support fixed timestep (fixedUpdate()) for demo recording
7. NEW: VMs execute demos, not formulas - do not add formula-based automation

Current Refactoring Status

See documentation/Refactor plan.txt for detailed roadmap. Key ongoing work:

Phase 1: DI Consistency
- Removing global _G.DI_CONFIG fallback
- Converting Singleton utilities (SpriteLoader, PaletteManager) to DI

Phase 2: MVC Boundaries
- Decoupling views from controllers (passing data explicitly)
- Removing direct property access from views

Phase 4: Event Bus (NEW - see src/utils/event_bus.lua)
- Replacing return-based communication with pub/sub events
- Current events: ProgramLaunchRequested, WindowCloseRequested

When making changes, align with the refactor plan rather than perpetuating legacy patterns.

Development Plan

See documentation/Development Plan.txt for full roadmap (15 phases, ~120 days).
See documentation/vm_demo_system.md for COMPLETE VM demo system design and implementation status.

Current Phase: Phase 1 (MVP Foundation) + VM Demo System Phases 1-6 COMPLETE

MVP Foundation Status ✅:
- 5 unique minigames (Dodge, Snake, Memory Match, Hidden Object, Space Shooter) ✓
- Clone system generating 200+ variants ✓
- 5 Neural Core levels with bosses ✓
- Desktop OS with launcher, window management, file explorer ✓
- CheatEngine with parameter modification ✓
- Save/load system ✓

VM Demo System Status ✅ (Phases 1-6 Complete):
- ✅ Phase 1: Demo recording infrastructure (DemoRecorder model, fixed timestep, input capture)
- ✅ Phase 2: Demo playback engine (DemoPlayer model, frame injection, speed multipliers, headless mode)
- ✅ Phase 3: VM execution refactor (replaced formula-based with demo loops, state machine)
- ✅ Phase 4: VM Manager UI (two-step demo assignment flow, live stats display, control buttons)
- ✅ Phase 5: Demo management UI (auto-recording on completion, save/discard prompts)
- ✅ Phase 6: Live VM playback window (watch VMs execute at 1x regardless of speed, HUD overlay)

Next Priorities:
- Phase 2 (Content Expansion): 15-20+ minigames, expand to 20 Neural Core levels
- Rename Space Defender → Neural Core throughout codebase
- Update UI/text to reflect token feeding fiction (not space combat)
- VM Demo System Phase 7: Integration & polish (event bus enhancements, edge case handling)
- VM Demo System Phase 8: Performance optimization (target 100+ VMs, profiling, headless optimization)
- FUTURE CONSIDERATION: VM Learning System (research/prototype phase)

Common Gotchas

1. Windows Key Handling: love.keypressed intercepts Windows key (lgui/rgui) to toggle Start Menu - prevents OS Start Menu from opening
2. Cursor Management: System cursors loaded in main.lua, set via love.mouse.setCursor() based on window state
3. Quit Handling: love.quit() shows custom shutdown dialog unless _G.APP_ALLOW_QUIT is true
4. Auto-save: Runs every 30 seconds in love.update() - saves player data, statistics, window positions
5. Performance: Target 60 FPS with 500+ bullets on screen - use object pooling and spatial partitioning
6. File Paths: Use love.filesystem for save directory, relative paths for assets
7. Screensaver: Activates after configurable timeout - any input resets timer
8. Fixed Timestep: Games use fixed timestep (1/60 sec) for demo recording determinism - call game:fixedUpdate(dt) in fixed update loop
9. Demo Recording: Automatically records every minigame completion - player chooses to save ([S]) or discard ([D])
10. VM Execution: VMs loop demos endlessly with random seeds - success rate depends on demo quality, not formulas
11. Playback Speed: VMs can run at 100x speed while playback windows display at 1x for visual feedback
12. Neural Core Bullets: Each completed game = 1 bullet, bullet damage = exact token value from performance

File Organization
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
│   │   ├── neural_core_levels.json
│   │   └── control_panels/
│   └── sprites/                # Graphics assets
└── documentation/              # Design docs, plans, guidelines
    ├── AI Guidelines.txt       # MANDATORY reading for code changes
    ├── Development Plan.txt    # Full roadmap
    ├── Refactor plan.txt       # Ongoing architecture improvements
    └── CONTRIBUTING.md         # Architecture checklist
```

Testing Approach

- Manual Testing: Primary method - play through systems after changes
- Debug Mode (F5): Inspect state, force saves, view all data
- Common Test Paths:
  - Launch minigame → Complete → Check token reward
  - Assign game to VM → Wait for completion → Verify token generation
  - Purchase upgrade → Verify cost deduction and effect
  - Play Neural Core → Check bullet power scaling
  - Close/reopen game → Verify save persistence

Performance Targets

- 60 FPS with 150+ bullets (MVP), 500+ bullets (full release)
- Bullet system uses object pooling (src/models/bullet_system.lua)
- Neural Core must remain playable with max bullet count
- Profile with high bullet counts during development

PixelLab MCP Integration

The project has access to PixelLab's AI-powered pixel art generation via MCP (Model Context Protocol) integration.

Available Tools:

1. Character Generation (mcp__pixellab__create_character):
   - Generates characters with 4 or 8 directional views
   - Options: size (16-128px), detail level, shading, outline style, view angle, proportions
   - Returns job ID immediately, check status with get_character
   - Processing time: 2-3 min (4 directions), 3-5 min (8 directions)

2. Character Animation (mcp__pixellab__animate_character):
   - Add animations to existing characters
   - Templates: walking, running, jumping, attacking, idle, etc.
   - Automatically generates for all character directions
   - Processing time: 2-4 minutes

3. Isometric Tiles (mcp__pixellab__create_isometric_tile):
   - Single isometric tiles for game assets
   - Tile shapes: thin tile, thick tile, block
   - Size: 16-64px (recommend 24px+ for quality)
   - Processing time: ~10-20 seconds

4. Top-Down Tilesets (mcp__pixellab__create_topdown_tileset):
   - Wang tileset (16 or 23 tiles) for corner-based autotiling
   - Define lower/upper terrains with transition layer
   - Can create connected tilesets using base tile IDs
   - Processing time: ~100 seconds

5. Sidescroller Tilesets (mcp__pixellab__create_sidescroller_tileset):
   - Platform tiles for 2D platformers
   - Side-view perspective, transparent background
   - Processing time: ~100 seconds

6. Map Objects (mcp__pixellab__create_map_object):
   - Transparent background objects for game maps
   - Two modes: basic (standalone) or style matching (with background image)
   - Size: 32-400px, supports non-square dimensions
   - Processing time: ~15-30 seconds

Usage Pattern:
```lua
-- Example: Create a character
1. Call create_character (returns immediately with character_id)
2. Wait for processing (2-5 minutes)
3. Call get_character to retrieve PNG images and download URLs
4. Optionally call animate_character to add animations
5. Download sprites and integrate into assets/sprites/
```

Key Considerations:
- All operations are asynchronous (non-blocking)
- Use list_* functions to view previously generated assets
- Downloaded sprites should be saved to assets/sprites/
- Style parameters (shading, outline, detail) guide the AI but aren't strict
- Base tile IDs allow creating visually consistent connected tilesets

Integration with Project:
- Use for generating minigame sprite variants
- Create placeholder art during development
- Generate diverse enemy/obstacle sprites for game clones
- Could be integrated into in-game "generation tools" for meta-fiction layer

Documentation: https://api.pixellab.ai/mcp/docs

Contact and Resources

- Issues: Track in documentation/todo.txt or create GitHub issues
- Design Docs: See documentation/ folder
- AI Workflow: Follow documentation/AI Guidelines.txt strictly
- Architecture: Review documentation/CONTRIBUTING.md checklist

When in doubt: Favor existing patterns, use dependency injection, externalize data to JSON, and consult the refactor plan before adding new code.