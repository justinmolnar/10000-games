# Codebase Architecture Audit

**Date:** February 6, 2026
**Scope:** Full codebase - MVC adherence, component architecture, config/data, cross-cutting concerns

---

## Executive Summary

The codebase has a **strong architectural foundation** - DI container, BaseGame/BaseView patterns, component system, fixed timestep - but **architectural discipline has eroded over time**. The 8 original games follow the patterns well. The raycaster, the infrastructure layer (states, models, views), and some components have significant issues: MVC violations, god objects forming, massive files with mixed responsibilities, debug code everywhere, and hardcoded values that should be parameterized.

**Overall Rating: 5.5/10** - Good bones, real rot setting in. The framework is right but the code filling it out often breaks its own rules.

---

## Critical Issues

### 1. Raycaster: Full Rendering Pipeline in Game Logic
**File:** `src/games/raycaster.lua:60-115`
**Severity:** CRITICAL - Massive MVC violation

`loadSpriteWithBounds()` runs a complete love.graphics rendering pipeline inside game logic: `newCanvas()`, `setCanvas()`, `clear()`, `setBlendMode()`, `draw()`, `getCanvas()`, `newImageData()`. This is 55 lines of rendering code that belongs in a sprite processing utility or the view layer.

Additionally, `loadSprites()` at line 48 calls `love.graphics.newImage()` directly, and `loadGuardSprites()` calls `loadSpriteWithBounds()` dozens of times during init.

The other 8 games have **zero** love.graphics calls. The raycaster has ~20.

---

### 2. Raycaster: Hardcoded Values Everywhere
**File:** `src/games/raycaster.lua` (throughout)
**Severity:** HIGH - Breaks the parameterization pattern every other game follows

While every other game loads all values from SchemaLoader, the raycaster has inline defaults scattered throughout:
- Line 94: `target = 64` (sprite canvas size)
- Line 318: `time_limit = 3000` (generation timeout)
- Line 337: `radius = 0.3` (entity collision)
- Line 386: `max_entities = 200`
- Line 394: `max_projectiles = 100`
- Line 771: `anim_speed = 8` (animation FPS)
- Line 1332: `entity.health or 25` (default health)
- Line 1361: `player_radius = 0.3`
- Line 1711: `pickup_radius = 0.5`
- Lines 346-364: Entire pickup definitions hardcoded (treasure_gold_bar = 100 points, health_medkit = 25 HP, etc.) instead of in variant JSON

Plus ~30 inline `or` fallbacks like `self.params.enemy_sight_range or 15` that should be schema defaults.

---

### 3. BillboardRenderer: Quad Created Per Column Per Frame
**File:** `src/utils/game_components/billboard_renderer.lua:165`
**Severity:** HIGH - Performance

```lua
local quad = love.graphics.newQuad(src_x, 0, 1, sprite_height, sprite_width, sprite_height)
```

This creates a new Quad object for **every pixel column of every sprite billboard every frame**. With a 320-wide viewport and 5 visible sprites, that's ~1600 Quad allocations per frame. Quads should be cached or pre-created.

---

### 4. EntityController.removeByTypes() Bug
**File:** `src/utils/game_components/entity_controller.lua:1020`
**Severity:** HIGH - Silent logic bug

Checks `entity.type` but entities store their type as `entity.type_name` (set at line 152). Function silently does nothing.

---

### 5. EventBus Has No Unsubscribe - Memory Leak
**File:** `src/utils/event_bus.lua`
**Severity:** HIGH - Grows over session

No `unsubscribe()` method exists. 5+ states create subscriptions in `init()` that are never cleaned up when states exit/re-enter. Listeners accumulate indefinitely.

---

### 6. conf.lua Hardcoded to Secondary Monitor
**File:** `conf.lua:9`
**Severity:** HIGH - Breaks on single-monitor systems

`t.window.display = 2` with no fallback. Also tripled in `src/config.lua` lines 407 and 414.

---

## Major Issues

### 7. Desktop State is a 977-Line God Object
**File:** `src/states/desktop_state.lua`

This file manages: window lifecycle, all mouse/keyboard input routing, desktop icon operations, tutorial overlay, start menu, screensaver idle timer, wallpaper system, context menus, and file operations.

- Lines 421-937: **~500 lines** of mouse input handling in one flow
- Business logic bleeding into state: `calculateDefaultIconPositionsIfNeeded()`, `deleteDesktopIcon()`, `ensureIconIsVisible()`
- Global state communication: `_G.WANT_SHUTDOWN_DIALOG`
- Debug prints: lines 67-70, 173, 201-202, 250, 288, 923, 928, 932
- Defensive nil-checks that mask initialization bugs instead of fixing them

Needs to be split into focused sub-controllers (InputRouter, IconManager, etc.).

---

### 8. Launcher View Contains Business Logic (825 Lines)
**File:** `src/views/launcher_view.lua`

Multiple MVC violations:
- Lines 60-62: `getVisibleGameCount()` - pagination logic in view
- Lines 120-134: Double-click detection and unlock decision logic
- Lines 357-386 and 569-616: Palette/tint calculation logic **copy-pasted** in two draw methods
- Lines 779-822: `drawDebugBalanceInfo()` - full debug balance display left in production
- Lines 29-31: Hardcoded pixel values (`button_height = 80`, `detail_panel_width = 400`) that should be in config

---

### 9. Player Data: God Object Trajectory (583 Lines, 9 Domains)
**File:** `src/models/player_data.lua`

One file manages: tokens, game unlocks, game performance, VM slots, active VMs, CheatEngine budgets, CheatEngine modifications, upgrades, and demos. That's 9 unrelated domains.

- Lines 110, 142, 151, 173, 201, 221, 240: Commented-out event publishing - half-finished architecture
- Lines 208-215 and 404-419: Duplicate initialization patterns (`initCheatData` vs `initGameCheatData`)
- Lines 488-494 and 523-529: Duplicate refund calculation logic
- Demo IDs generated with `os.time()` - not unique if two save in same second

---

### 10. Raycaster: updateBillboards() Mixes Logic and View Concerns (130+ Lines)
**File:** `src/games/raycaster.lua:1555-1688`

This function decides entity visual state (is it dying? is it a corpse? should it bob?), computes animation parameters, resolves guard sprites by direction, handles death animation squishing - then assembles billboard data. It's game logic, rendering data construction, and animation state management in one 130-line function.

The raycaster view also does logic: `raycaster_view.lua:56-63` filters dead/dying enemies for the minimap, which is game logic in a view.

---

### 11. Entity Controller is 1573 Lines
**File:** `src/utils/game_components/entity_controller.lua`

Should be split into EntityController (spawning/lifecycle), EntityBehaviors (AI/movement), and EntityCollision (hit detection).

- Lines 1239-1570: `updateBehaviors()` is a **330-line function**
- Uses `goto continue` statements (code smell)
- Type confusion: `entity.movement` vs `self.entity_types[entity.type_name].movement` - which wins?
- Hardcoded defaults: grid cols/rows default to 4 (line 364), bouncing bounds default to 800x600 (line 1394)

---

### 12. Debug Print Statements Everywhere

Every major file has print() calls left in:

| File | Approximate Count | Example Lines |
|------|-------------------|---------------|
| raycaster.lua | ~10 | 189, 465, 500-503, 615, 719, 888 |
| desktop_state.lua | ~10 | 45, 67-70, 173, 201, 250, 288, 923 |
| minigame_state.lua | ~15 | 8, 25, 43, 74, 78, 91, 144, 150, 181-200 |
| vm_manager.lua | ~12 | 46, 56, 102, 217, 232-241, 274, 340, 453 |
| movement_controller.lua | ~5 | 538-542, 550, 565-579 |
| window_controller.lua | ~3 | 198, 482, 499 |

---

## Medium Issues

### 13. love.graphics.newImage() in Model
**File:** `src/models/game_variant_loader.lua:73-85` - Models shouldn't create rendering resources.

### 14. MinigameState Has Direct Rendering
**File:** `src/states/minigame_state.lua:160-169` - love.graphics calls in state draw().

### 15. Require Path Inconsistency
Two styles: `require('class')` vs `require('lib.class')`, and `require('models.x')` vs `require('src.models.x')`. Works via package.path manipulation but fragile and confusing.

### 16. Window Manager Off-Screen Save Vulnerability
**File:** `src/models/window_manager.lua:500-509` - Saves window positions without bounds checking. If screen resolution changes, windows appear off-screen.

### 17. Launcher State Has Model Operations
**File:** `src/states/launcher_state.lua:126-161` - `updateFilter()` is filtering/business logic that belongs in a model.

### 18. VM Manager: Weak State Machine
**File:** `src/models/vm_manager.lua` - State transitions (IDLE/RUNNING/RESTARTING) have no validation. "Pause" is implemented by setting state to IDLE (line 485), not a real pause state.

### 19. Magic Numbers Outside Config
- `main.lua:303` - AUTO_SAVE_INTERVAL = 30
- `main.lua:33-35` - Debug flags hardcoded
- Window manager: cascade offsets (25,25), min sizes (200,150), taskbar height (40)

### 20. Legacy Cheat System Still in Config
**File:** `src/config.lua:63-70` - Old `cheat_costs` table alongside new CheatEngine system. Likely dead code.

### 21. CheatEngine Costs at Testing Values
**File:** `src/config.lua:76-120` - All costs = 10 "for testing", scaling = 1.0 (disabled), refund = 100%.

### 22. Inconsistent DI Patterns
Three patterns coexist: constructor injection, init-time injection, and post-creation `.game = self` binding. The post-creation pattern is fragile.

### 23. Overlapping Boundary Systems
Both `arena_controller.lua` and `movement_controller.lua` implement boundary handling independently.

---

## Low Issues

### 24. WindowController.mousereleased() Indentation
Lines 450-492: 20+ space overindent in snap logic. Functionally correct but unmaintainable.

### 25. Enum Duplication
Space Shooter enums in both `constants.lua` and `config.lua` with no cross-validation.

### 26. paths.lua Incomplete
Missing variant directory, save file, and log file path entries.

### 27. StateMachine Builder Pattern
Uses function builder unlike every other component. Works but inconsistent.

### 28. CoinFlip Uses Direct Requires vs DI
Imports components via `require()` while other games use `self.di.components`.

### 29. Inconsistent Config Validation
Some components error on bad config, others silently default. No consistent convention.

---

## What's Actually Working Well

### BaseGame + 8 Original Games (A)
Snake, Space Shooter, Breakout, Dodge, RPS, Coin Flip, Hidden Object, Memory Match all follow the architecture properly: SchemaLoader for params, components for logic, views for rendering, fixedUpdate for determinism.

### Component System (B+)
The 13 game components are well-designed individually. Clean APIs, proper pooling, focused responsibilities. Entity Controller just needs to be split up.

### DI Container (B+)
Well-organized creation in main.lua. Models receive what they need. Components pre-bundled.

### Fixed Timestep + Demo System (A)
Solid implementation. All games properly use fixedUpdate, buildInput/isKeyDown for demo compatibility.

### Config System (B)
config.lua is comprehensive at 2154 lines with clear subsections. Would be A if not for the testing values and dead legacy section.

### Error Handling (B)
Consistent pcall on I/O and JSON. Structured error responses in CheatSystem. Crash log on fatal errors. Loses points for print-to-console error "handling" and defensive nil-checks that mask bugs.

---

## File Size Red Flags

Files over 500 lines often indicate mixed responsibilities:

| File | Lines | Concern |
|------|-------|---------|
| entity_controller.lua | 1573 | Should split into 3 files |
| raycaster.lua | 1911 | Largest game, doing sprite loading + rendering + game logic |
| base_game.lua | ~1150 | Large but justified - shared base for 9 games |
| desktop_state.lua | 977 | Doing 8+ unrelated things |
| launcher_view.lua | 825 | Contains business logic |
| breakout.lua | 698 | Acceptable |
| vm_manager.lua | 656 | Acceptable but debug-heavy |
| player_data.lua | 583 | 9 domains in one file |
| window_manager.lua | 562 | Duplicate calculations, hardcoded values |

---

## Recommended Fix Priority

### Tier 1: Bugs and Performance
1. Fix `EntityController.removeByTypes()` - `entity.type` -> `entity.type_name`
2. Cache Quads in `BillboardRenderer.createSprite()` instead of per-column-per-frame allocation
3. Fix `conf.lua` display = 2 crash on single monitors
4. Add `EventBus:unsubscribe()` + state cleanup methods

### Tier 2: Raycaster Cleanup
5. Extract `loadSpriteWithBounds()` into a sprite processing utility
6. Move all love.graphics/love.image calls out of raycaster.lua
7. Move hardcoded pickup definitions to variant JSON
8. Replace inline `or` defaults with schema defaults
9. Split `updateBillboards()` into data assembly (game) and visual state (view)

### Tier 3: Structural
10. Split desktop_state.lua - extract InputRouter, IconManager
11. Move business logic out of launcher_view.lua
12. Start splitting player_data.lua into sub-systems (tokens, demos, cheats)
13. Split entity_controller.lua into 3 focused files
14. Remove all debug print statements (or route through a debug flag)

### Tier 4: Cleanup
15. Standardize require paths
16. Standardize DI patterns
17. Remove legacy cheat_costs config
18. Set production CheatEngine values
19. Add window position bounds checking on load
20. Fix WindowController indentation
