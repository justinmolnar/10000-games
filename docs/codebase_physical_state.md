# 10,000 Games Collection - Physical Codebase State
**Generated: February 9, 2026**
**Purpose: Comprehensive snapshot of what actually exists in code, for external reference**

---

## At A Glance

| Metric | Value |
|--------|-------|
| Total Lua files | 280 |
| Total lines of Lua | ~68,500 |
| Data files (JSON) | 51 |
| Game implementations | 9 minigames |
| Game variants (JSON) | 200+ |
| Reusable components | 23 |
| View files | 37 (~8,500 lines) |
| Model files | 17 (~5,300 lines) |
| Sprite assets | 150+ game sprites, 40+ Win98 UI icons, shared libraries |
| Third-party libs | 7 (class, json, tick, earcut, gifload, rotLove, volk3d) |
| Desktop programs defined | 25 |
| Scripts (Python/Lua) | 11 |

---

## 1. What This Project Is (From The Code)

A LOVE2D application (Lua, framework v11.4) that renders a full Windows 98 desktop environment at 1920x1080. The desktop has a taskbar, start menu, draggable/resizable windows, a file explorer with a virtual filesystem, desktop icons, a recycle bin, wallpaper settings, screensavers, and context menus. All of this is rendered procedurally - the Win98 aesthetic is built from rectangles, 3D bevel effects (white highlight + dark shadow borders), and ~40 real Windows 98 icon PNGs.

Inside this desktop, the player browses a launcher containing 200+ minigame variants, plays them in windowed mode, records demos of their inputs, and feeds tokens into a progression system. There's a CheatEngine tool for modifying game parameters, a VM Manager for automating games via demo playback, and a Neural Core (vertical shooter reframed as a token-processing interface) that serves as the main progression gate.

The entire application runs as a single-window LOVE2D program. "Windows" are rendered regions managed by a WindowController. The state machine has 4 global states (DESKTOP, DEBUG, COMPLETION, SCREENSAVER), with window-specific states spawned within the desktop.

---

## 2. Project Structure (What's Where)

```
10000-games/
├── main.lua                    (454 lines) Entry point, DI container, event loop
├── conf.lua                    (18 lines)  LOVE2D config (1920x1080, display=2)
├── CLAUDE.md                   Project instructions for AI assistants
│
├── src/
│   ├── config.lua              (2,153 lines) Master config - economy, UI, per-game params
│   ├── constants.lua           (66 lines)    Enums (states, space shooter types)
│   ├── paths.lua               (21 lines)    Asset directory constants
│   │
│   ├── controllers/            (7 files)
│   │   ├── state_machine.lua         (87 L)   Global state switching
│   │   ├── window_controller.lua     (250+ L) Window drag/resize/click handling
│   │   ├── scrollbar_controller.lua  (136 L)  Reusable scrollbar state
│   │   ├── text_input_controller.lua (352 L)  Text field with selection
│   │   ├── taskbar_controller.lua    (90 L)   Taskbar interactions
│   │   ├── desktop_icon_controller.lua (100+ L) Icon grid layout/hit testing
│   │   └── minigame_controller.lua   (200+ L) Game lifecycle, scoring, demo integration
│   │
│   ├── models/                 (17 files, ~5,300 lines)
│   │   ├── player_data.lua           (582 L)  Save state: tokens, unlocks, demos, cheats
│   │   ├── game_data.lua             (355 L)  Game registry, formula compilation
│   │   ├── game_registry.lua         (178 L)  Auto-discovers variants from JSON
│   │   ├── vm_manager.lua            (656 L)  VM automation system
│   │   ├── cheat_system.lua          (351 L)  Parameter modification + cost system
│   │   ├── bullet_system.lua         (260 L)  Neural Core bullets/damage
│   │   ├── demo_recorder.lua         (164 L)  Input recording at 60 FPS
│   │   ├── demo_player.lua           (261 L)  Demo playback with speed control
│   │   ├── window_manager.lua        (561 L)  Window lifecycle, z-order, persistence
│   │   ├── program_registry.lua      (557 L)  Desktop program definitions
│   │   ├── file_system.lua           (724 L)  Virtual filesystem (C:\, D:\, etc.)
│   │   ├── desktop_icons.lua         (196 L)  Icon positions and state
│   │   ├── recycle_bin.lua           (146 L)  Deleted file storage/restore
│   │   ├── statistics.lua            (105 L)  Persistent global stats
│   │   ├── progression_manager.lua   (63 L)   Auto-completion of earlier variants
│   │   ├── game_context.lua          (31 L)   Lightweight DI wrapper
│   │   └── game_variant_loader.lua   (106 L)  Legacy wrapper → GameRegistry
│   │
│   ├── states/                 (10+ files)
│   │   ├── desktop_state.lua         (200+ L) Main OS simulation, window management
│   │   ├── launcher_state.lua        (200+ L) Game browser with filtering
│   │   ├── minigame_state.lua        (200+ L) Runtime for playing a minigame
│   │   ├── completion_state.lua      (57 L)   Victory screen
│   │   ├── screensaver_state.lua     (150+ L) 4 screensaver types
│   │   ├── debug_state.lua           (100+ L) F5 overlay (add tokens, unlock all, etc.)
│   │   └── [+ vm_manager_state, cheat_engine_state, settings_state,
│   │         file_explorer_state, start_menu_state, solitaire_state, etc.]
│   │
│   ├── games/                  (10 game files)
│   │   ├── base_game.lua             (1,150 L) Parent class for all minigames
│   │   ├── snake_game.lua            (1,024 L) Grid/smooth movement, AI snakes, arenas
│   │   ├── space_shooter.lua         (1,396 L) Vertical shooter, 4 enemy AI systems
│   │   ├── breakout.lua              (600+ L)  Brick-breaking with layouts
│   │   ├── dodge_game.lua            (600+ L)  Survival dodging, arena morphing
│   │   ├── raycaster.lua             (200+ L)  Wolf3D-style first-person maze
│   │   ├── coin_flip.lua             (200+ L)  Gambling/prediction
│   │   ├── rps.lua                   (449 L)   Rock-paper-scissors, tournaments
│   │   ├── hidden_object.lua         (121 L)   Click-to-find
│   │   └── memory_match.lua          (517 L)   Card matching with gravity/shuffle
│   │
│   ├── games/views/            (9 view files, one per game + game_base_view)
│   │   ├── game_base_view.lua        Common rendering (victory/gameover overlays)
│   │   ├── snake_view.lua            (418 L)
│   │   ├── space_shooter_view.lua    (230 L)
│   │   ├── dodge_view.lua            Starfield + polygon arena
│   │   ├── raycaster_view.lua        (148 L) 3D walls, minimap, Wolf3D HUD
│   │   └── [breakout, coin_flip, rps, hidden_object, memory_match views]
│   │
│   ├── views/                  (37 files, ~8,500 lines)
│   │   ├── base_view.lua             (74 L)   Viewport coordinate transform system
│   │   ├── ui_components.lua         (403 L)  Buttons, dropdowns, scrollbars, panels
│   │   ├── desktop_view.lua          (268 L)  Wallpaper + icon grid
│   │   ├── taskbar_view.lua          (150+ L) Start button, window buttons, clock/tokens
│   │   ├── start_menu_view.lua       (150+ L) Cascading menu with submenus
│   │   ├── window_chrome.lua         (100+ L) Title bars, borders, control buttons
│   │   ├── launcher_view.lua         (825 L)  Game browser cards, detail panel, formulas
│   │   ├── file_explorer_view.lua    (150+ L) Toolbar, address bar, file list
│   │   ├── minigame_view.lua         (137 L)  Post-game completion overlay
│   │   ├── formula_renderer.lua      Icon-based formula visualization
│   │   ├── metric_legend.lua         Metric icons with labels/values
│   │   ├── context_menu_view.lua     (106 L)  Right-click menus
│   │   ├── wallpapers.lua            (150 L)  Wallpaper discovery, scaling modes
│   │   ├── [screensaver views: starfield, pipes, model3d, text3d]
│   │   ├── [control panel views: general, desktop, screensavers]
│   │   ├── [cheat_engine_view, vm views, debug_view, completion_view, etc.]
│   │   └── [web_browser_view (338 L), run_dialog_view, etc.]
│   │
│   └── utils/
│       ├── event_bus.lua             (63 L)   Pub/sub with ID-based unsubscribe
│       ├── save_manager.lua          (132 L)  Save/load with corruption recovery
│       ├── settings_manager.lua      User preferences persistence
│       ├── sprite_loader.lua         Sprite loading and caching
│       ├── sprite_manager.lua        Sprite registry and palette tinting
│       ├── sprite_set_loader.lua     Load sprite sets per game variant
│       ├── palette_manager.lua       Color palette definitions
│       ├── audio_manager.lua         Sound/music playback
│       ├── tts_manager.lua           Text-to-speech system
│       ├── html_renderer.lua         HTML email rendering (in-game browser)
│       ├── html_parser.lua           HTML parsing
│       ├── html_layout.lua           HTML layout engine
│       ├── css_parser.lua            CSS parsing
│       ├── (particle_system.lua moved to game_components/particle_system.lua)
│       ├── (collision.lua removed - use PhysicsUtils.rectCollision)
│       ├── (png_collision.lua moved to game_components/sprite_utils.lua)
│       ├── contour_tracer.lua        Edge detection/polygon extraction
│       ├── mesh_extrusion.lua        3D mesh from 2D shapes
│       ├── triangulation.lua         Polygon triangulation
│       ├── syntax_highlighter.lua    Code syntax highlighting
│       ├── [+ program_launcher, url_resolver, attribution_manager, etc.]
│       │
│       └── game_components/    (23 files, ~8,900 lines)
│           ├── entity_controller.lua      (1,573 L) Spawning, pooling, behaviors
│           ├── physics_utils.lua          (784 L)   Forces, collision, trails, tiles
│           ├── arena_controller.lua       (692 L)   Arena/playfield management
│           ├── movement_controller.lua    (627 L)   Velocity, grid, smooth, jump
│           ├── player_controller.lua      (578 L)   Lives, health, shields, ammo, heat
│           ├── schema_loader.lua          (387 L)   JSON schema → game parameters
│           ├── pattern_movement.lua       (329 L)   Enemy AI movement patterns
│           ├── victory_condition.lua      (324 L)   9 win types, 7 loss types
│           ├── scoring_system.lua         (318 L)   Formula-based token calculation
│           ├── hud_renderer.lua           (311 L)   Score/lives/timer/progress display
│           ├── map_spawn_processor.lua    (297 L)   Map spawn definitions → entities
│           ├── animation_system.lua       (280 L)   Flip, bounce, fade, progress, timer
│           ├── raycast_renderer.lua       (259 L)   DDA raycasting, depth buffer
│           ├── projectile_system.lua      (198 L)   Bullet pooling and movement
│           ├── minimap_renderer.lua       (193 L)   Top-down minimap overlay
│           ├── billboard_renderer.lua     (187 L)   3D sprite rendering with occlusion
│           ├── visual_effects.lua         (160 L)   Camera shake, screen flash
│           ├── fog_of_war.lua             (135 L)   Stencil/alpha visibility
│           ├── static_map_loader.lua      (128 L)   Load tile maps from JSON
│           ├── state_machine.lua          (121 L)   Component-level state machine
│           ├── effect_system.lua          (109 L)   Visual effect timing
│           ├── particle_system.lua        (120 L)   Particle effects (explosions, trails, confetti)
│           └── rotlove_dungeon.lua        (347 L)   Procedural dungeon generation
│
├── assets/
│   ├── data/
│   │   ├── variants/           (9 JSON files, one per game type)
│   │   │   ├── dodge_variants.json          8 variants
│   │   │   ├── snake_variants.json          8 variants
│   │   │   ├── space_shooter_variants.json  8 variants
│   │   │   ├── breakout_variants.json       8+ variants
│   │   │   ├── memory_match_variants.json   8 variants
│   │   │   ├── hidden_object_variants.json  8 variants
│   │   │   ├── rps_variants.json            8 variants
│   │   │   ├── coin_flip_variants.json      8+ variants
│   │   │   └── raycaster_variants.json      12+ variants
│   │   │
│   │   ├── schemas/            (10 JSON files) Parameter definitions with types/ranges
│   │   ├── programs.json       25 desktop program definitions
│   │   ├── strings/ui.json     100+ UI strings
│   │   ├── filesystem.json     Virtual Win98 filesystem tree
│   │   ├── control_panels/     Settings definitions (desktop, screensavers, solitaire)
│   │   ├── maps/               Static map data (pacman, wolf_test)
│   │   ├── models/             3D model data (cube.json)
│   │   ├── sprite_sets.json    Game-to-sprite-set mappings
│   │   ├── sprite_palettes.json  Color palette definitions
│   │   └── attribution.json    Asset credits
│   │
│   └── sprites/
│       ├── win98/              ~40 Windows 98 UI icons (PNG)
│       ├── games/              Per-game sprites organized by variant
│       │   ├── dodge/base_1/   player.png
│       │   ├── snake/classic/  segment.png, seg_head.png, food.png
│       │   ├── space_shooter/  enemy.png, bullet.png
│       │   ├── breakout/base/  paddle.png, brick.png, ball.png
│       │   ├── memory/         250+ country flag cards, icon sets
│       │   ├── rps/base/       rock.png, paper.png, scissors.png
│       │   ├── coin_flip/base/ coin_heads.png, coin_tails.png
│       │   ├── hidden_object/  background.png, highlight.png
│       │   └── raycaster/      Wolf3D-style assets
│       └── shared/             Reusable sprite libraries
│           ├── animals/        12 animal face sprites
│           ├── food/           5 food sprites
│           └── retro_future/   Space vehicles, alien artifacts
│
├── lib/
│   ├── class.lua               OOP system (31 lines)
│   ├── json.lua                JSON encode/decode
│   ├── tick.lua                Timer/animation helpers
│   ├── earcut.lua              Polygon triangulation
│   ├── gifload.lua             GIF loader (possibly unused)
│   ├── rotLove/                Roguelike toolkit (95 files) - map gen, FOV, pathfinding
│   └── volk3d/                 3D rendering (4 files, usage unclear)
│
├── scripts/                    11 Python/Lua scripts
│   ├── pixellab_*.py           AI sprite generation via PixelLab API
│   ├── generate_placeholders.py  Fallback placeholder sprites
│   ├── migrate_*.py            Historical schema migration tools
│   └── test/validate scripts
│
└── docs/                       Architecture audits, tutorials, references
    ├── architecture-audit-2026.md
    ├── codebase_audit.md
    ├── game_components_reference.md
    ├── pixellab_sprite_generation.md
    └── tutorials/              13 offline development tutorials
```

---

## 3. The Nine Games (What Actually Exists)

All games extend `BaseGame` (1,150 lines), which provides: fixed-timestep updates for deterministic demo playback, arena/viewport management, component creation from schemas, entity spawning with formations and Bezier entrance paths, collision handling, scoring, cheat application, asset loading, and the virtual keyboard system that enables demo recording/playback.

### Snake (1,024 + 418 lines)
Grid-based or smooth movement. Supports multiple player snakes + AI snakes with behavior trees (aggressive, defensive, food-focused). Arena shapes: circle, hexagon, rectangle, custom polygons. Features: girth system (snake width expands perpendicular to movement), arena shrinking, food spawn patterns (random, cluster, spiral), wall modes (death, bounce, wrap). MVC clean.

### Space Shooter (1,396 + 230 lines)
The most complex game. Four distinct enemy AI systems: continuous random spawning, wave-based batches, Space Invaders synchronized grid, and Galaga-style formations with state machines (entering, in_formation, diving). Player movement modes: rail, rotation, thrust, directional, jump. Fire modes: manual, auto, charge, burst. Bullet patterns: single, double, triple, spread, spiral, wave, ring. Hazards: asteroids, meteors with warning indicators, gravity wells, blackout zones. MVC clean.

### Breakout (600+ lines)
Paddle-and-ball brick breaking. Ball physics: gravity, homing, magnet mode, piercing. Brick layout generators: standard grid, pyramid, circle, random. Supports collision image (pixel-perfect brick layouts from PNG). Perfect clear bonus. MVC clean.

### Dodge (600+ lines)
Survival game with arena morphing. Arena cycles through shapes (32-sided circle -> 4-sided square -> 6-sided hex). Physics-based movement with friction. Obstacle spawn patterns: boundary, spiral, clusters, pulse-with-arena. Optional holes in arena boundary. Starfield parallax background. MVC clean.

### Raycaster (200+ lines game + 148 view)
Wolf3D-style first-person maze. Uses rotLove for procedural maze generation or loads static maps. DDA raycasting with depth buffer. Billboard sprites for enemies (guards with 8-direction, multi-frame animations: stand, walk, pain, shoot, falling, dead). Collectibles: dots, health, ammo, treasure, keys. **Known issues: has love.graphics calls in game logic file (MVC violation), hardcoded values not in schema, newest and least architecturally clean game.**

### Coin Flip (200+ lines)
Gambling/prediction game. Player guesses heads/tails, AI decides based on bias parameter. Combo multipliers, pattern history tracking. Victory conditions: streak target, total correct, accuracy ratio, time survival. Auto-flip timer option. MVC clean.

### Rock-Paper-Scissors (449 lines)
Turn-based with AI pattern detection. Modes: single hand, double hands (pick 2 of 3), tournament (multiple opponents with elimination). Special round modifiers. Win streak tracking. MVC clean.

### Hidden Object (121 lines)
The simplest game. Click hidden objects within time limit. Deterministic positioning using hash functions (same layout every play). MVC clean.

### Memory Match (517 lines)
Card grid with match_requirement (pairs, triplets, quads). Memorize phase shows cards face-up briefly. Optional gravity (cards fall with physics), auto-shuffle (periodic randomization), chain mode (must match specific sequences in order). Progress-based flip animation. MVC clean.

### Summary Table

| Game | Game Lines | View Lines | MVC Clean | love.* in Logic | Complexity |
|------|-----------|-----------|-----------|-----------------|-----------|
| Snake | 1,024 | 418 | Yes | No | HIGH |
| Space Shooter | 1,396 | 230 | Yes | No | VERY HIGH |
| Breakout | 600+ | ~200 | Yes | No | HIGH |
| Dodge | 600+ | ~200 | Yes | No | MEDIUM |
| Raycaster | 200+ | 148 | **No** | **Yes** | MEDIUM |
| Coin Flip | 200+ | ~150 | Yes | No | LOW |
| RPS | 449 | ~150 | Yes | No | MEDIUM |
| Hidden Object | 121 | ~100 | Yes | No | LOW |
| Memory Match | 517 | ~200 | Yes | No | MEDIUM |

---

## 4. Variant System (How 9 Games Become 200+)

Each game type has a `*_variants.json` file containing 8-12 variant definitions. Each variant overrides base parameters to create a distinct gameplay experience.

**Three-tier priority**: Variant-specific JSON > File-level JSON defaults > config.lua defaults

**Example - Dodge variants span from**:
- "Dodge Master" (clone_index 0): Basic, no enemies, learn mechanics
- "Dodge Ice Rink" (clone 2): Low friction (0.98 accel, 0.96 decel), bounce physics
- "Dodge Temporal Void" (clone 5): +30% difficulty, extreme mechanics
- "Dodge Elysium" (clone 7): -30% difficulty, easiest variant

**Each variant controls parameters like**: movement_speed, rotation_speed, friction, bounce_damping, enemy types and spawn patterns, arena shape/size/morphing behavior, fog of war, gravity, wind, lives, shields, victory conditions, visual identity (sprite set, palette).

**Schema files** (one per game, 10 total) define all valid parameters with types, ranges, defaults, and descriptions. SchemaLoader validates and coerces values at load time.

**Unlock costs scale exponentially** by clone_index: `base_cost * ((clone_index + 1) ^ cost_exponent)`

---

## 5. Core Systems (How They Connect)

### Dependency Injection Container (main.lua)
Created during `love.load()` with 60+ services. Passed to everything. Contains: config, settings, save manager, event bus, all 23 game components as classes, player data, game data, VM manager, cheat system, window manager, desktop icons, file system, recycle bin, program registry, sprite systems, audio, TTS, demo recorder/player, and the state machine itself.

### State Machine
4 global states registered: DESKTOP, DEBUG, COMPLETION, SCREENSAVER. Desktop state manages windowed sub-states internally. State machine delegates all LOVE callbacks (update, draw, keypressed, mousepressed, etc.) to the current state.

### Event Bus (63 lines)
Pub/sub with ID-based subscriptions. 20+ event types: window lifecycle (focus, minimize, close, maximize, restore), desktop events (icon recycle, ensure visible), settings (wallpaper changed), economy (tokens_changed), shop events, game lifecycle (started, completed, failed), demo events, VM events. Safe iteration (copies listener list). Error handling with pcall. **Known issue: subscriptions can accumulate since cleanup is manual.**

### Window System
WindowController handles mouse interactions (drag with 4px deadzone, resize with 8px edge detection, title bar buttons). WindowManager tracks z-order, minimized state, positions. WindowChrome renders the Win98 borders and title bars. Windows store/restore positions via window_positions.json. Programs defined in programs.json with window_defaults (size, min size, resizable flag, single_instance flag).

### Token Economy Flow
```
Game completion
  -> MinigameController calculates performance via formula
  -> Checks completion ratio against threshold (fail gate: <75% = 0 tokens)
  -> Applies cheat multipliers
  -> PlayerData.addTokens() -> publishes tokens_changed event
  -> Statistics records cumulative earnings
  -> BulletSystem reloads (new bullet type or updated damage)
  -> Neural Core gains power
```

### Demo Recording/Playback
DemoRecorder captures key presses/releases with frame numbers at fixed 60 FPS. Minimum 60 frames, maximum 18,000 (5 min). DemoPlayer replays inputs frame-by-frame with speed multiplier support. Multi-step mode caps at 4 steps per real frame to prevent lag spirals. Headless mode runs to completion instantly. Demos loop if playback exceeds total frames.

### VM Automation
Players purchase VM slots (exponential cost: `base * 2^current_count`). Assign a demo to a slot. State machine: IDLE -> RESTARTING (0.1s delay) -> RUNNING -> RESTARTING (loop). Each run generates tokens scaled by CPU speed upgrade and overclock multiplier. Speed upgrades: 1x -> 2x -> 4x -> INSTANT (headless). VM data persists in player save.

### CheatEngine
Unlocked after Neural Core Level 3. Discovers modifiable parameters from variant JSON (71 metadata/visual params are hidden). Cost calculation: base_cost * exponential_scale^modification_count, with parameter-specific overrides. Budget tracked per game. Refund on reset (configurable percentage, default 100% in dev). Creates modified variant copy that's passed to game constructor.

### Formula System
Scoring formulas defined as strings in JSON: `"(metrics.kills * 50 + metrics.deaths * (-10)) * scaling_constant"`. Compiled at runtime via `loadstring()` with pcall safety wrapping. All metrics default to 0. Result multiplied by variant_multiplier. Used for: token calculation, theoretical max estimation, auto-play performance scaling.

---

## 6. The Windows 98 Desktop (Visual Layer)

### Aesthetic
Built entirely from LOVE2D drawing primitives plus ~40 authentic Win98 icon PNGs. Core palette: gray `{0.75, 0.75, 0.75}` for all UI surfaces, dark blue `{0, 0, 0.5}` for focused title bars, white + dark borders for 3D bevel effect. Teal `{0, 0.5, 0.5}` default wallpaper. All colors configurable in config.lua (~400 lines of color definitions).

### BaseView Pattern (Critical Architecture)
All windowed views extend BaseView (74 lines). Views operate in local viewport coordinates (0,0 = top-left of window content). `setScissor()` auto-converts viewport to screen coordinates. This eliminates coordinate confusion bugs across 37 view files. Rule: never call `love.graphics.origin()` inside windowed views.

### Desktop Elements
- **Desktop**: Wallpaper (image or solid color, 5 scale modes), icon grid (48x48 sprites, column-first layout, drag/drop)
- **Taskbar**: Start button with 3D bevel, dynamic window buttons (focused=sunken, unfocused=raised), system tray with clock and token counter (color-coded: red <100, yellow <500, green 500+)
- **Start Menu**: Cascading submenus (0.2s hover delay), Programs/Documents/Settings/Help/Run/Shutdown, hover highlight in dark blue
- **Window Chrome**: 25px title bar, 2px borders, 16x14px control buttons (minimize/maximize/close), resize edges (8px), focused=blue unfocused=gray
- **Context Menus**: Right-click menus on desktop/icons
- **File Explorer**: Toolbar (back/forward/up/home), address bar, scrollable file list with icons, status bar
- **Screensavers**: Starfield, 3D pipes, 3D model rotation, 3D text

### Launcher View (825 lines - the biggest view)
11 filter categories. Scrollable game card list (80px per card with 64x64 icon, title, difficulty stars, formula visualization, stats). Detail panel (right side, ~400px) with: preview, flavor text, difficulty, tier, power formula as icons, personal best stats, auto-play estimate, play/unlock button. ScrollbarController integration.

### Game Views
Each game has a dedicated view file. Games render within their window's viewport. GameBaseView provides victory/gameover overlay (semi-transparent black + large colored text). Completion overlay shows: tokens earned, formula breakdown, cheat bonuses, new record comparison, demo save/discard prompt.

---

## 7. The 23 Game Components

Reusable building blocks in `src/utils/game_components/`. Games compose by instantiating the ones they need. ~95% code reuse across 9 games.

### Movement & Physics (3 components, ~2,090 lines)
- **MovementController** (627 L): Velocity, rotation, bounds, jump/dash, grid movement, smooth (3D-style) movement. Per-entity state storage. Deterministic for demos.
- **PhysicsUtils** (784 L): Gravity, homing, magnet, gravity wells. Circle/rect/line collision detection and response (bounce, stop, overlap, attach). Tile-based movement. Trail system with self-collision. Launch helpers.
- **EntityController** (1,573 L): The largest component. Spawning modes (continuous, wave, grid, burst, manual). Object pooling. Grid shuffle animation. 20+ entity behaviors in a single `updateBehaviors()` method (333 lines - known issue). Weighted type selection.

### Rendering (5 components, ~1,000 lines)
- **HUDRenderer** (311 L): Score/lives/timer/progress. Dot-notation key lookup. Heart or number lives display. VM render mode skip.
- **RaycastRenderer** (259 L): DDA raycasting. Per-column depth buffer. Wall color by orientation. Door/goal detection. Distance fog.
- **BillboardRenderer** (187 L): Painter's algorithm sprite rendering. Frustum culling. Per-column depth test against wall buffer. Distance shading.
- **MinimapRenderer** (193 L): Top-down map overlay. Player arrow, goal square, enemy dots, critical path line. Configurable position/size.
- **FogOfWar** (135 L): Stencil-based (circular cutouts) or alpha-based (distance fading). Configurable opacity and radius.

### Game Logic (4 components, ~1,270 lines)
- **VictoryCondition** (324 L): 9 victory types (threshold, time_survival, time_limit, streak, ratio, clear_all, endless, rounds, multi). 7 loss types. Dot-notation metric lookup. Bonus system.
- **ScoringSystem** (318 L): Formula string mode (backward compat) or declarative metrics mode. 6 curve functions (linear, sqrt, log, exponential, binary, power). Detailed breakdown output.
- **PlayerController** (578 L): 5 damage modes (lives, health, shield, binary, none). Shield regeneration. Ammo system with reload. Heat/overheat. Multi-weapon system. Comprehensive callback system.
- **SchemaLoader** (387 L): Loads JSON schemas, applies variant overrides with priority. Type coercion, constraint validation (min/max, enum). Mode lookup tables. Component config merging.

### Animation & Effects (2 components, ~440 lines)
- **AnimationSystem** (280 L): Factory methods: flip, bounce, fade, progress, timer. Pure data (no love.graphics). Start/update/reset lifecycle.
- **VisualEffects** (160 L): Camera shake (exponential or timer decay), screen flash (fade_out, pulse, instant), particles. Visual only - doesn't affect game state or demos.

### Specialized (8 components, ~1,300 lines)
- **PatternMovement** (329 L): 6 enemy AI patterns: sine, circle, spiral, homing, evasion, figure-8.
- **ArenaController** (692 L): Arena/playfield management, grid coordinates, wave tracking, collision zones. Large but sparsely documented.
- **ProjectileSystem** (198 L): Bullet pooling, lifetime, linear movement. Minimal and focused.
- **StateMachine** (121 L): Component-level state machine with enter/exit callbacks.
- **EffectSystem** (109 L): Visual effect timing/sequencing.
- **StaticMapLoader** (128 L): Load tile maps from JSON.
- **MapSpawnProcessor** (297 L): Convert spawn definitions to entity configurations.
- **RotLoveDungeon** (347 L): Procedural dungeon generation (for raycaster).

---

## 8. Data Files and Configuration

### config.lua (2,153 lines - the monolith)
Contains everything in one file:
- **Economy**: start_tokens=20, upgrade costs, CPU speed scaling
- **CheatEngine**: budget=999999999 (dev mode), parameter costs by type, 71 hidden parameters, refund policy (100% in dev)
- **UI Metrics**: taskbar (40px height), window chrome (25px title bar, 2px borders), scrollbar (10px), desktop grid (20px padding), start menu (200px width), icon sizes
- **Colors**: ~400 lines of RGB values for every UI element
- **Screensaver configs**: Starfield (500 stars), Pipes 3D, Model 3D, Text 3D
- **Per-game configs**: All 9 games with unlock_cost, formula_string, metrics_tracked, auto_play_performance, bullet settings, visual identity, upgrades

### Variant JSONs (9 files, 200+ variants total)
Each file: `{ game_class, sprite_folder, category, tier, variants: [...] }`. Each variant: clone_index, name, difficulty_modifier, flavor_text, + 20-80 game-specific parameters.

### Schema JSONs (10 files)
Parameter definitions with type, default, min, max, description. Component configurations (HUD, health, fog, effects). Enemy/obstacle type definitions. Movement mode presets. Victory condition definitions with `$param_name` references resolved at runtime.

### programs.json (25 programs)
Each program: id, name, executable, state_class_path, icon, window_defaults (size, min size, resizable, single_instance), desktop/start_menu visibility. 8+ programs marked disabled (paint, notepad - planned but not active).

### Save Files (9 files in %APPDATA%\LOVE\10000games\)
save.json (player data), settings.json, statistics.json, window_positions.json, desktop_layout.json, shortcuts.json, start_menu_order.json, start_menu_overrides.json, start_menu_moves.json. Auto-saved every 30 seconds.

---

## 9. Third-Party Libraries

| Library | Purpose | Status |
|---------|---------|--------|
| **class.lua** (31 L) | OOP (new/extend/super) | Essential, used everywhere |
| **json.lua** | JSON encode/decode | Essential, used for all data I/O |
| **tick.lua** | Timer/animation helpers | Active |
| **earcut.lua** | Polygon triangulation | Active (arena rendering) |
| **rotLove/** (95 files) | Roguelike toolkit: map gen, FOV, pathfinding, dice, color utils | Used by raycaster for maze generation. Flagged as potential bloat - most features unused |
| **volk3d/** (4 files) | 3D rendering | Status unclear, may be unused |
| **gifload.lua** | GIF loading | Possibly unused |

---

## 10. Known Issues and Technical Debt

### Critical
- **EventBus memory leak**: Subscriptions never auto-unsubscribe on state destroy. Manual cleanup required.
- **Raycaster MVC violation**: ~55 lines of love.graphics calls in raycaster.lua game logic. ~30 hardcoded values not in schema.
- **conf.lua display=2**: Hardcoded for dev's second monitor. Crashes on single-monitor systems.

### Major
- **EntityController.updateBehaviors()**: 333-line god method handling 20+ behaviors. Untestable, hard to modify.
- **config.lua**: 2,153-line monolith. All CheatEngine costs set for dev/testing, not production.
- **desktop_state.lua**: Manages too many concerns (windows, input, icons, screensaver, menus).
- **PhysicsUtils**: 784 lines mixing 8 unrelated concerns (forces, collisions, trails, tiles).
- **BillboardRenderer**: Creates 1,600 quads per frame instead of caching.
- **468 print() statements**: No log level system. Debug output mixed with diagnostics.

### Medium
- **launcher_view.lua** (825 lines): Contains some business logic that should be in state/model.
- **player_data.lua** (582 lines): 9 unrelated domains in one file.
- **MovementController debug spam**: Console pollution from angle change logging in raycaster.
- **SchemaLoader mode lookup**: Silent failure if variant key spelling doesn't match schema definition.
- **No test suite**: Zero automated tests.

---

## 11. Architecture Patterns (What Works Well)

- **MVC discipline**: 8 of 9 games cleanly separate logic from rendering. Models have zero love.* calls. Views receive data as parameters.
- **Dependency injection**: Central DI container created in main.lua, passed to all components. No globals. Explicit dependencies.
- **Component composition**: Games select which of 22 components to instantiate. ~95% code reuse. Adding a new game = JSON variant file + game class + view class.
- **Configuration-driven**: All game parameters in JSON. Formulas as strings compiled at runtime. UI colors/dimensions in config.lua. No magic numbers in game code (except raycaster).
- **Fixed timestep determinism**: 60 FPS game logic with seeded RNG. Demo recording captures inputs with frame numbers. Playback is pixel-perfect. Headless mode runs instantly.
- **BaseView coordinate system**: Solves viewport vs screen coordinate confusion across 37 view files.
- **Object pooling**: EntityController and ProjectileSystem reuse objects to reduce GC pressure.
- **Auto-discovery**: GameRegistry scans variant JSON files at startup. Adding games requires no code registration.
- **Safe I/O**: All file operations wrapped in pcall. JSON parsing has corruption recovery. Save system timestamps and version-checks.

---

## 12. What's Not Built Yet

Based on programs.json disabled entries, documentation references, and code stubs:

- **Paint program**: Defined in programs.json, disabled
- **Notepad**: Defined, disabled
- **Settings app**: Defined, disabled
- **Email/messaging system**: Web browser view exists (338 lines), HTML renderer exists, but the "email" fiction layer isn't implemented
- **Neural Core gameplay**: BulletSystem model exists, space_defender_levels.json exists, but the actual playable Neural Core may be incomplete
- **Audio system**: AudioManager exists but tutorials suggest it's not fully activated for all games
- **Statistics dashboard**: Statistics model tracks data, view exists, but may be minimal
- **Solitaire**: Has dedicated state, views, save system, card definitions - appears mostly complete

---

## 13. File Counts by Directory

```
src/views/               37 files
src/utils/               35 files (13 outside game_components)
src/states/              26 files
src/utils/game_components/ 23 files
src/models/              17 files
src/games/               11 files (10 game files)
src/games/views/         10 files
src/controllers/          7 files
lib/                      5 files (+ rotLove's 95)
scripts/                 11 files
docs/                    16 files
assets/data/             51+ JSON files
```

---

*This document describes the codebase as it physically exists on February 9, 2026. It does not describe design intent, artistic vision, or planned features beyond what's evidenced in existing code and data files.*
