# CLAUDE.md

## Project Overview

**10,000 Games Collection** - A LÖVE2D game (Lua) simulating a Windows 98 desktop where players hunt through procedurally-generated minigame variants to find exploitable "gems", optimize them with CheatEngine, and automate favorites with VM demo playback.

**Framework:** LÖVE2D 11.4
**Architecture:** MVC + State Machine + Dependency Injection + Event Bus

---

## The Fiction (1999 Alternate Timeline)

**Surface:** You found a 90s shovelware CD with 10,000 games - standard bargain bin fare.

**Discovery Layer (Optional):**
- No story presented in gameplay - just a game collection with convenient features
- As you play: Earn tokens, get helpful emails/updates, unlock tools
- First impression: Forgettable quirks (can't reply to emails, TTS voices, generic text)
- If you explore filesystem: Find generation tools, templates, logs with 1999 timestamps
- The reveal: Cross-reference files and realize there is no developer - everything is automated/generated
- Hidden layer: Encrypted files reveal "training data collection" via gameplay

**Meta-Layer (4th Wall):**
- Steam page has mundane disclosure: "Built with AI" - seems like standard AI tool usage
- Hours later: Finding in-game generation tools makes you think about real development choices
- Eventually: Going back to Steam page, seeing the disclosure again: "...oh. OH."
- The realization is earned through discovery, never told or explained

**Critical:** This is 100% optional environmental storytelling. Players can complete the entire game without engaging with any fiction.

---

## Core Gameplay Loop

**Hunt → Beat → Discover → Optimize → Automate → Progress**

### 1. Hunt & Discover
Browse launcher looking for interesting titles among 10,000 games. 99.9% are trash - finding the 0.1% gems IS the game.

### 2. Beat Once (Required)
Beating a game unlocks:
- **Bullets** for Neural Core (mandatory progression)
- **CheatEngine** parameters for that game (can't see until beaten)
- **Tokens** from completion
- **Demo Recording** ability (if game is VM-worthy)

### 3. Evaluate
After beating, discover what you found:
- Does CheatEngine have gamebreaking cheats? Useless fakes?
- Is it automatable? (Deterministic mechanics, safe strategies?)
- Is it fun to play manually?

### 4. Optimize & Collect
- Use CheatEngine to create perfect builds
- Play manually for best returns (VMs are backup income)
- Record demo if VM-worthy (but only ONE VM per game initially)
- Add to "collection" of perfected games

### 5. Strategic Decisions
- "This Snake is good, but what if there's a better one?"
- "Do I VM this mediocre game or save the slot?"
- Skill tree upgrades eventually allow multiple VMs per game

### 6. Progress & Repeat
- Tackle Neural Core with accumulated bullet power
- Hunt harder/weirder games as you progress

**Semi-Active Gameplay:** Player simultaneously hunts games, plays optimized games manually, monitors VMs, tackles Neural Core, and tweaks CheatEngine builds.

---

## Running the Game

```bash
love .
# or
"C:\Program Files\LOVE\love.exe" .
```

### DO NOT AUTO-RUN THE GAME

Never execute the game via Bash unless the user explicitly says "run the game". The user is actively playing/testing - auto-running interrupts their session.

---

## Project Structure

```
src/
├── config.lua          # All tuning parameters
├── constants.lua       # Enums and constants
├── paths.lua           # File path constants
├── controllers/        # State machine, window control
├── models/             # Business logic (NO rendering)
├── views/              # Rendering only (NO logic)
├── states/             # Application states
├── games/              # 9 minigames + BaseGame
│   └── views/          # Game-specific rendering
└── utils/
    └── game_components/  # 13 reusable game components

assets/
├── data/
│   ├── variants/       # Game variant JSONs (8 types)
│   ├── programs.json   # Desktop program definitions
│   └── strings/        # UI text
└── sprites/

docs/                   # Design documentation
```

---

## Architecture

### MVC Pattern
- **Models** (`src/models/`): Data and business logic only. NO `love.*` calls.
- **Views** (`src/views/`): Rendering only. Receive data as parameters.
- **States** (`src/states/`): Mediate between models and views.

### Dependency Injection
Central DI container created in `main.lua`, passed to all components:
```lua
local di = {
    config = Config,
    saveManager = SaveManager,
    playerData = player_data,
    gameData = game_data,
    vmManager = vm_manager,
    -- ... etc
}
```
**Rules:** Inject only what you need. NO global reads. NO god objects.

### State Machine
- Global states: DESKTOP, DEBUG, COMPLETION, SCREENSAVER
- Window-based states launched within DesktopState (not registered globally)

### Event Bus
Pub/sub system (`src/utils/event_bus.lua`) for decoupled communication.

---

## Key Systems

### Neural Core (Main Progression)
- Vertical scrolling shooter aesthetic reframed as token feeding interface
- **Bullets:** Every completed game = 1 bullet. Bullet damage = token value from performance
- All bullets fire simultaneously = entire game library feeding tokens at once
- Level requirements = token thresholds (Level 20 needs 1 trillion tokens)
- System generates tools after level completions (CheatEngine at L3)
- UI reframes everything: "PROCESSING REQUEST", "Tokens Required", "PROCESSING COMPLETE"

### VM Manager (Automation)
- Automate favorite games via demo playback for passive income
- **Scarcity:** Each game assignable to ONE VM initially (skill tree upgrades add more)
- Speed upgrades: 1x → 10x → 100x → INSTANT (headless)
- VMs loop endlessly: RUNNING → game completes → RESTARTING → new seed → repeat
- Manual play always gives better returns - VMs are convenience

### Demo Recording & Playback
- **Recording:** Automatic on every minigame completion, captures inputs with frame numbers
- **Playback:** DemoPlayer injects recorded inputs frame-by-frame
- Fixed timestep (60 FPS) ensures deterministic behavior
- Player saves ([S]) or discards ([D]) demo after completion
- Success rate depends on demo quality + game parameters + RNG luck

### CheatEngine
- Unlocked after Neural Core Level 3
- Reveals unique parameters per game (can't see until beaten)
- Modify: lives, physics, spawn rates, arena size, movement speed
- Some games have gamebreaking cheats, others have useless fakes
- **Thematic:** The AI WANTS you to cheat - it's an efficiency tool for token generation

### Window Management
- WindowController handles lifecycle, dragging, resizing, focus
- Windows saved/restored via window_positions.json
- Windows respect `window_defaults` from programs.json

---

## Game Components (`src/utils/game_components/`)

13 reusable components eliminate ~5,000-7,500 lines of duplicated code:

| Component | Purpose |
|-----------|---------|
| MovementController | Player movement, collision, dash, screen wrapping |
| PhysicsUtils | Velocity, acceleration, drag, collision helpers |
| AnimationSystem | Frame-based sprite animation |
| VisualEffects | Particles, screen shake, death animations |
| HUDRenderer | Configurable score/lives/timer display |
| FogOfWar | Grid-based visibility system |
| VictoryCondition | Win/loss state management |
| LivesHealthSystem | Lives, health, invincibility, shields |
| ScoringSystem | Score, combos, multipliers, token calculation |
| EntityController | Enemy spawning, pooling, wave management |
| ProjectileSystem | Bullet firing, collision, pooling |
| PowerupSystem | Powerup spawning, collection, effects |
| VariantLoader | Load game parameters from JSON |

**Always use VariantLoader for parameters - no hardcoded values in games.**

---

## Configuration

**`src/config.lua`** - All tuning parameters:
- Economy: token costs, upgrade prices
- VM settings: costs, speed multipliers
- CheatEngine: budgets, parameter costs
- UI layout metrics

**`assets/data/variants/*.json`** - Game variant definitions with parameters.

**`assets/data/programs.json`** - Desktop program definitions.

---

## Critical Patterns

### BaseView Pattern
All windowed views extend `BaseView`:
```lua
function MyView:drawContent(viewport_width, viewport_height)
    -- Render using viewport coordinates (0,0 = top-left of window)
    self:setScissor(x, y, w, h)  -- NOT love.graphics.setScissor()
    -- ... render ...
    self:clearScissor()
end
```
**Never** call `love.graphics.origin()` inside windowed views.

### ScrollbarController
Always use `ScrollbarController` - never create custom scrollbars:
```lua
self.scrollbar = ScrollbarController:new({ unit_size = 30 })
-- State handles mousepressed/mousemoved/mousereleased
-- View calls scrollbar:compute() and UIComponents.drawScrollbar()
```

### Fixed Timestep for Demos
Games use `game:fixedUpdate(dt)` at 60 FPS for deterministic demo playback.

### Error Handling
Wrap file I/O and JSON in pcall:
```lua
local success, data = pcall(json.decode, content)
if not success then return default end
```

---

## PixelLab MCP Integration

AI-powered pixel art generation via MCP (Model Context Protocol).

### Available Tools

| Tool | Purpose | Processing Time |
|------|---------|-----------------|
| `create_character` | 4 or 8 directional character sprites | 2-5 min |
| `animate_character` | Add animations (walk, run, attack, idle) | 2-4 min |
| `create_isometric_tile` | Single isometric tiles | 10-20 sec |
| `create_topdown_tileset` | Wang tileset (16/23 tiles) for autotiling | ~100 sec |
| `create_sidescroller_tileset` | Platform tiles for 2D platformers | ~100 sec |
| `create_map_object` | Transparent background objects | 15-30 sec |

### Usage Pattern
1. Call `create_character` (returns immediately with character_id)
2. Wait for processing
3. Call `get_character` to retrieve PNG images
4. Optionally call `animate_character` to add animations
5. Download and save to `assets/sprites/`

### Integration
- Generate minigame sprite variants
- Create placeholder art during development
- Generate diverse enemy/obstacle sprites for game clones
- Could integrate into in-game "generation tools" for meta-fiction

**Documentation:** https://api.pixellab.ai/mcp/docs

---

## Common Gotchas

1. **Viewport vs Screen coords**: Scissor needs screen coords, rendering uses viewport coords
2. **Auto-save**: Runs every 30 seconds - player_data, settings, window positions
3. **Windows key**: Intercepted to toggle Start Menu
4. **Demo recording**: Automatic on game completion - player saves/discards
5. **Fixed timestep**: Required for demo determinism
6. **Performance**: Target 60 FPS with 500+ bullets - use object pooling

---

## Code Standards

- All `require` calls at file top
- Use forward slashes: `require('src.models.player_data')`
- No magic numbers - use `config.lua`
- Avoid over-engineering - minimal changes for the task
- Don't add unnecessary comments, docstrings, or type annotations
- Wrap I/O in pcall

---

## Save Data Location

Windows: `%APPDATA%\LOVE\10000games\`
- save.json, settings.json, statistics.json, window_positions.json

---

## Debug Mode

Press **F5** in-game to toggle debug overlay (inspect state, force saves).

---

## Current Status

- 9 minigames with 8 variant types (200+ total variants)
- Desktop OS with launcher, window management, file explorer
- VM system with demo recording/playback complete (Phases 1-6)
- Neural Core progression system
- CheatEngine parameter modification
- 13 reusable game components
- PixelLab MCP integration for sprite generation
