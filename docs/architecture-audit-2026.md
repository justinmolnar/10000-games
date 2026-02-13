# 10000-Games Architecture Audit

**Date:** February 6, 2026
**Overall Grade: B+** - Strong architecture with a few real issues and some housekeeping

---

## The Good (What's Working)

- All 9 games properly extend BaseGame
- All games use SchemaLoader - no hardcoded game parameters
- All game views extend GameBaseView consistently
- 22 game_components are well-utilized with minimal duplication
- Only 3 TODO comments in entire codebase
- No commented-out code blocks (block comments are all documentation)
- Clean feature module separation (models/views/states/controllers/services)
- DI container pattern mostly consistent

---

## Critical Issues

### 1. Event Bus Has No Unsubscribe (Memory Leak)

**File:** `src/utils/event_bus.lua`

The event bus only has `subscribe()` and `publish()`. There is no `unsubscribe()` / `off()` / `removeListener()` method. Once a listener is registered, it stays forever.

**Impact:** Every state that subscribes to events leaks those listeners:

- **DesktopState** subscribes to 11+ events in init(), never cleans up
- **StartMenuState** subscribes to 4+ events, never cleans up
- **FileExplorerState** subscribes per-window, never cleans up

Only **VMPlaybackState** implements `exit()` with cleanup (nulling refs, but can't unsub from events since the method doesn't exist).

**Fix:** Add `unsubscribe(event, callback)` to event_bus.lua, then implement `exit()` in every state that subscribes.

### 2. Solitaire View Contains Full Game Logic

**File:** `src/views/solitaire_view.lua`

This is the biggest MVC violation. The solitaire "view" contains:
- Complete game state (deck, stock, waste, foundations, tableau)
- Card shuffling logic
- Game reset logic
- Save/load serialization
- Settings sync and persistence
- Mode management (`self.mode = 'play'`)

This should be a model + view, not a view doing everything. The view is acting as both model and view.

### 3. Launcher View Handles Input and Mutates State

**File:** `src/views/launcher_view.lua`

- `update()` polls mouse position and tracks hover state
- `mousepressed()` handles category filtering, double-click detection, game selection
- `wheelmoved()` mutates scroll offset
- `drawGameList()` mutates `self.scroll_offset` during a draw call (state mutation in render!)

These should all be in the state or controller, with the view purely receiving data to render.

### 4. Global Variable Backdoors Bypass DI

Multiple files use `rawget(_G, 'DI_CONFIG')` as a fallback instead of receiving config through DI:

| File | Lines |
|---|---|
| `src/models/window_manager.lua` | 6, 15 |
| `src/models/player_data.lua` | 3 |
| `src/views/solitaire_view.lua` | 2 |
| `src/views/window_chrome.lua` | 9 |
| `src/states/debug_state.lua` | Multiple (`rawget(_G, 'player_data')`, `rawget(_G, 'game_data')`, `rawget(_G, 'state_machine')`) |

Plus global signal flags: `_G.APP_ALLOW_QUIT`, `_G.WANT_SHUTDOWN_DIALOG`

This creates a dual-path dependency system that weakens the DI pattern.

---

## Medium Issues

### 5. Models Call love.graphics (MVC Violation)

- `src/models/window_manager.lua:329-330` - calls `love.graphics.getWidth()` / `getHeight()` directly. Should receive screen dimensions as parameters.
- `src/models/game_variant_loader.lua:75` - calls `love.graphics.newImage()`. Should return the path and let the view load the image.

### 6. Most States Don't Implement exit()

Only VMPlaybackState has a proper `exit()` method. All other states that subscribe to events or hold references have no cleanup path. This compounds the event bus leak issue.

### 7. Bloated States

| State | Lines | Issue |
|---|---|---|
| `web_browser_state.lua` | 997 | Browser logic, URL parsing, navigation, rendering |
| `desktop_state.lua` | 976 | Windows, cursors, idle timers, screensaver, icons, tutorial, start menu, taskbar, context menu, wallpaper |
| `cheat_engine_state.lua` | 692 | Parameter modification, variant loading, JSON parsing, game selection, scrolling |

DesktopState especially is doing the work of 4-5 smaller states/controllers.

### 8. Inconsistent Error Handling

| Component | Pattern |
|---|---|
| MinigameController | Heavy pcall (good) |
| EventBus:publish | Always pcall (good) |
| DesktopState | Selective pcall (mixed) |
| WindowController | Some pcall, some direct (mixed) |
| FileExplorerState | Mostly direct calls (poor) |

### 9. 468 print() Statements

Not all debug - many are legitimate initialization/diagnostic output. But there's no log level system, so debug prints and real diagnostics are mixed together.

Top offenders with DEBUG-prefixed prints:
- `src/states/start_menu_state.lua`
- `src/states/desktop_state.lua`
- `src/utils/game_components/movement_controller.lua` (`[MC DEBUG]` prefix)
- `src/states/file_explorer_state.lua` (`[DEBUG FE State]` prefix)

**Fix:** Create `src/utils/logger.lua` with log levels (DEBUG/INFO/WARN/ERROR), make configurable.

---

## Minor Issues

### 10. One Unused Game Component

`src/utils/game_components/rotlove_dungeon.lua` is never imported by any game. Either remove it or document it as planned for future use.

### 11. scoring_system.lua Usage Unclear

The component exists but no game directly imports it. BaseGame.calculatePerformance() calls `self.data.formula_function()` instead. Verify if this is intentional separation or an orphaned component.

### 12. Root Directory Clutter

| Files | Count | Action |
|---|---|---|
| `session_*_metadata.json` | 13 files (~583KB) | Move to `docs/sprite_generation_sessions/` |
| `PHASE*_TEST_VARIANTS.md` | 5 files | Archive to `docs/archived_phases/` |
| `phase11_summary.md` | 1 file | Archive |
| `bash.exe.stackdump` | 1 file | Delete (Windows crash dump) |
| `mcp_retry_object_ids.json` | 1 file | Move to dev artifacts |
| `test_parser_main.lua` | 1 file | Move to `tests/` |
| `test_text_rendering.lua` | 1 file | Move to `tests/` |
| `DEBUG_START_MENU.md` | 1 file | Delete (issues marked FIXED) |

### 13. Verify rotLove Library Usage

`lib/rotLove/` contains 95 Lua files. Need to confirm raycaster or other games actually use it. If unused, that's significant bloat.

### 14. Duplicate Test File

`scripts/test_html_parser.lua` duplicates `test_parser_main.lua` in root. Consolidate.

---

## Comparison to Lattice INX

For context, since this audit was done alongside the work project:

| Aspect | 10000-games | Lattice INX |
|---|---|---|
| Architecture pattern | MVC + State Machine + DI + Event Bus | None (ad-hoc) |
| Base class/shared components | BaseGame + 22 game_components | None (copy-paste) |
| Config approach | SchemaLoader + variant JSONs (no hardcodes) | 5 theme systems, 1,492 hardcoded colors |
| Code duplication | Minimal | ~6,700 lines dead/duplicated |
| Dependency injection | Centralized DI container | None (prop drilling + globals) |
| Event system | EventBus (pub/sub, needs unsub) | NoticeEmitter (same issue) |
| State management | Zustand-like stores (in driverGoogle only) | useState soup everywhere else |
| Largest file | ~997 lines (web_browser_state) | 2,454 lines (search/index.js) |
| Dead code | ~20 root files to organize | 13 files to delete, 862 console.logs |
| TODO comments | 3 | Not systematically tracked |
| Test infrastructure | 2 test files (unorganized) | 1 broken default test |

---

## Priority Fix Order

| # | Issue | Effort | Impact |
|---|---|---|---|
| 1 | Add unsubscribe() to EventBus + implement exit() in states | 2-3 hours | Fixes memory leaks |
| 2 | Extract solitaire game logic from view into model | 3-4 hours | Fixes biggest MVC violation |
| 3 | Move launcher input handling from view to state/controller | 2-3 hours | Fixes MVC violation |
| 4 | Remove rawget(_G, ...) calls, pass through DI only | 1-2 hours | Cleans up DI pattern |
| 5 | Remove love.graphics calls from models | 30 min | Clean MVC |
| 6 | Create logger.lua, replace DEBUG prints | 2-3 hours | Clean diagnostics |
| 7 | Clean root directory (move/delete artifacts) | 30 min | Housekeeping |
| 8 | Break up DesktopState (~976 lines) | 4-6 hours | Maintainability |
| 9 | Verify rotLove usage, remove if unused | 30 min | Remove potential 95-file bloat |
| 10 | Remove/document unused components (rotlove_dungeon, scoring_system) | 15 min | Clarity |
