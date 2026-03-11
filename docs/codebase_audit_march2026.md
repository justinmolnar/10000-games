# Codebase Audit Report - March 2026

Full audit of the 10,000 Games codebase across all layers: views, games, models, states, utils, infrastructure, and architecture.

---

## CRITICAL ISSUES

*Note: `conf.lua display = 2` is a dev environment preference, not a bug. LÖVE falls back to primary monitor gracefully. Do not flag this.*

### 1. Event Bus Memory Leak - No Unsubscribe on State Destruction

**42 subscribe calls across the codebase vs 1 unsubscribe** (only `launcher_state.lua:42-44` cleans up).

States subscribe to events but never clean up when destroyed. Listeners accumulate and fire on dead objects.

| File | Subscriptions | Has destroy()? |
|------|--------------|----------------|
| desktop_state.lua | 13 | NO |
| start_menu_state.lua | 5 | NO |
| window_manager.lua | 7 | NO |
| system_sounds.lua | 7 | NO |
| desktop_icons.lua | 4 | NO |
| vm_manager_state.lua | 2 | NO |
| control_panel_desktop_state.lua | 1 | NO |
| file_explorer_state.lua | 1 | NO |
| recycle_bin.lua | 1 | NO |
| context_menu_service.lua | 1 | NO |
| program_launcher.lua | 1 | NO |
| **launcher_state.lua** | **1** | **YES - only file with cleanup** |

**Fix:** Add `destroy()` methods to all states/models that subscribe. Store subscription IDs and call `unsubscribe()` in destroy. Consider adding `unsubscribeAll(owner)` to EventBus.

---

### 2. Corrupted Saves Deleted Without Backup

**File:** `save_manager.lua:99`

When a save file fails validation, it's silently deleted via `love.filesystem.remove()`. One corrupted byte = total progress loss.

**Fix:** Move corrupted saves to `.backup` before deleting.

---

### 3. No Save Data Type Validation

**Files:** `player_data.lua`, `main.lua:177-196`

Save data is merged field-by-field with no type checking. If `tokens` becomes a string through corruption, all arithmetic crashes. Fields checked for existence but not type validity.

**Fix:** Add type validation on load - at minimum check numeric fields are numbers.

---

## HIGH SEVERITY

### 5. Raycaster Game - MVC Violations (Only Failing Game)

**File:** `src/games/raycaster.lua` (1,958 lines)

The only game of 9 that violates MVC:
- Line 50: `pcall(love.graphics.newImage, path)` - Image loading in game logic
- Line 57: `pcall(love.graphics.newImage, ...)` - Image loading
- Line 69: `pcall(love.image.newImageData, path)` - Image data in logic
- Line 71: `love.graphics.newImage(imageData)` - Image creation in logic
- Lines 399-424: Hardcoded weapon parameters with `or` fallbacks instead of schema
- Lines 309-324: Entity type definitions inline instead of in schema

Additionally, CoinFlip and RPS have `love.graphics.getDimensions()` / `getWidth()` / `getHeight()` calls for viewport sizing:
- **coin_flip.lua:** Lines 364, 379-380, 390, 405, 450-451
- **rps.lua:** Lines 320-321, 336, 345, 349, 367-368, 476-477

These are fallbacks when `self.viewport_width/height` isn't set. Less severe than raycaster but still MVC violations.

**Fix:** Move sprite loading to RaycasterView. Move weapon/entity params to raycaster_schema.json. Remove love.graphics viewport fallbacks from coin_flip and rps (ensure viewport is always set).

---

### 6. base_game.lua - LOVE Calls in Game Logic

**File:** `src/games/base_game.lua`

- Line 32: `love.math.newRandomGenerator()` - Should use standard Lua `math`
- Line 535: `love.keyboard.isDown()` - Input polling in game logic
- Lines 1243-1298: `love.graphics.newImage()`, `love.filesystem.getDirectoryItems()` - Image/file loading

**Fix:** Move image loading to views. Pass input state from controller. Use `math.random`.

---

### 7. desktop_state.lua - Heavy Rendering in State

**File:** `src/states/desktop_state.lua`

Extensive direct rendering instead of delegating to views:
- Lines 404-432: Full rendering pipeline (`push`, `setScissor`, `translate`, `pop`, `printf`)
- Lines 298, 302, 315-318: Screen dimension queries and mouse position
- Line 779: `love.keyboard.isDown()` in state

**Fix:** Move all rendering to desktop_view.lua. State should only call `view:draw(data)`.

---

### 8. 356+ Hardcoded Colors in Views Need ThemeManager

**Already updated:** taskbar_view, window_chrome, ui_components, start_menu_view, message_box_view, run_dialog_view, shutdown_view, context_menu_view

**Still hardcoding colors:**

| View File | Approx Hardcoded Colors |
|-----------|------------------------|
| cheat_engine_view.lua | 50+ |
| control_panel_screensavers_view.lua | 50+ |
| file_explorer_view.lua | 30+ |
| desktop_view.lua | 15+ |
| vm_manager_view.lua | 15+ |
| control_panel_desktop_view.lua | 12+ |
| credits_view.lua | 12+ |
| control_panel_view.lua | 12+ |
| minigame_view.lua | 10+ |
| control_panel_general_view.lua | 8+ |
| control_panel_sounds_view.lua | 8+ |
| control_panel_themes_view.lua | 8+ |
| solitaire_view.lua | many |
| debug_view.lua | 8+ |
| tutorial_view.lua | 5+ |
| cracktro_effects.lua | 8+ |
| completion_view.lua | 4+ |
| web_browser_view.lua | 1+ |

**Fix:** Migrate each view to use `ThemeManager.getSection()`. Add new theme sections as needed.

---

### 9. Silent Program Launch Failures

**File:** `src/utils/program_launcher.lua:99-119`

When a program's state class fails to load, recovery is attempted. If recovery fails, the function returns silently - no window appears, no error shown. User clicks and nothing happens.

**Fix:** Show a MessageBox error on failed launch.

---

### 10. Debug Code Left in Production

**main.lua:**
- Lines 32-35: `_G.DEBUG_FOG = true` is **enabled by default** - performance impact
- Lines 395-409: Token manipulation via `=` and `-` keys - players can cheat without debug mode

**settings_manager.lua:147-312:**
- 15 `print()` statements from wallpaper picker debugging. Fires every 30s via auto-save.

**raycaster.lua:** 5 debug print statements left in production code (lines 150, 489-491, 615, 727).

**Fix:** Gate debug globals behind F5 debug mode. Remove print statements. Move cheat keys behind debug flag.

---

### 11. Unprotected File I/O Operations

Several files perform filesystem operations without pcall wrapping:

- `static_map_loader.lua:73` - `love.filesystem.read()` unprotected - crashes raycaster on file errors
- `wad_parser.lua:46` - `love.filesystem.read()` unprotected
- `image_resolver.lua:15, 19, 55` - `love.filesystem.getDirectoryItems()` / `getInfo()` unprotected - crashes during boot
- `debug_state.lua:107` - `love.filesystem.remove()` unprotected

**Fix:** Wrap all file I/O in pcall per project conventions.

---

### 12. Demo Determinism Bug - space_shooter.lua

**File:** `src/games/space_shooter.lua:484`

```lua
local spiral_offset = math.rad((love.timer.getTime() * 200) % 360)
```

Uses real-time clock for spiral bullet pattern. `love.timer.getTime()` returns different values on demo playback, breaking determinism.

**Fix:** Replace with `self.time_elapsed` for deterministic patterns.

---

### 13. Require Calls Inside Functions (Should Be at File Top)

- `desktop_icon_controller.lua:207-208` - Requires `Strings` and `MessageBox` inside `mousepressed()`
- `snake_game.lua:839` - Requires `PhysicsUtils` inside function (already required at line 16)
- `progression_manager.lua:41` - Requires `Config` inside `checkAutoCompletion()`

**Fix:** Move all requires to file top per project conventions.

---

### 14. DI Container Fallback to Direct Requires

Some components fall back to `require()` when DI is missing instead of failing explicitly:

- `window_controller.lua:14` - `local Config = (di and di.config) or require('src.config')`
- `demo_player.lua:8` - Same pattern
- `demo_recorder.lua:8` - Same pattern

This silently masks DI wiring bugs. Should fail explicitly if DI is incomplete.

---

## MEDIUM SEVERITY

### 15. Oversized Components (>500 line guideline)

| Component | Lines | Status |
|-----------|-------|--------|
| entity_controller.lua | 1,631 | Should split: EntitySpawner, EntityPool, EntityCollisionDetector |
| arena_controller.lua | 935 | Should split: ShapeManager, ArenaPhysics, ArenaMorphology |
| physics_utils.lua | 784 | Acceptable - cohesive |
| movement_controller.lua | 625 | Could split: VelocityController, SteeringController |
| player_controller.lua | 574 | Acceptable - cohesive |
| background_renderer.lua | 557 | Each renderer type could be its own module |

---

### 16. Renderer Components Mixed with Logic Components

In `src/utils/game_components/`:
- `arena_controller.lua` has `drawBoundary()` rendering method (lines 803-825) - logic+rendering mixed
- `fog_of_war.lua` has rendering mixed with visibility logic (lines 57-73)
- `entity_controller.lua:107` has `pcall(love.graphics.newImage)` - image loading in logic

Note: `background_renderer.lua`, `billboard_renderer.lua`, `hud_renderer.lua`, `minimap_renderer.lua`, `raycast_renderer.lua` are intentionally rendering components (correctly named), but their location alongside pure-logic components is potentially confusing.

---

### 17. Views Calling love.mouse.getPosition() Directly

Views should receive mouse coords from their state, not query directly:

- `completion_view.lua:19`
- `debug_view.lua:24`
- `desktop_view.lua:85`
- `file_explorer_view.lua:53`
- `credits_view.lua:28`
- `vm_manager_view.lua:93`
- `web_browser_view.lua:32`
- `tutorial_view.lua:42`
- `context_menu_view.lua:25`

---

### 18. Window Manager Coordinate Duplication

**File:** `src/models/window_manager.lua`

Screen dimensions retrieved in 4+ places with identical fallback chains (lines 88-112, 113-138, 140-142, 329-330). Window state duplicated: `window.is_minimized` AND `minimized_windows[id]` track the same thing.

---

### 19. config.lua is Monolithic (2,478 lines)

Contains systems that could be external JSON:
- Lines 29-353: Water skill tree (24 nodes)
- Lines 356-362: Water upgrades
- Lines 424-471: CheatEngine configuration
- Lines 478-615: 150+ parameter range definitions

---

### 20. Improper Scissor Usage

**File:** `control_panel_screensavers_view.lua:306` uses `love.graphics.setScissor()` directly instead of `self:setScissor()` (BaseView method for viewport coordinate conversion).

---

## LOW SEVERITY

### 21. Minigame State Rendering in State Layer

**File:** `src/states/minigame_state.lua`
- Line 110: `love.graphics.getWidth/Height()`
- Lines 164-181: Direct rendering calls (`setColor`, `printf`)

### 22. Magic Numbers in Layout Code

Hardcoded pixel values throughout views (padding, margins, item heights). Works fine but makes layout changes fragile. Examples: `cheat_engine_view.lua:27-45`, `file_explorer_view.lua:22-28`, `launcher_view.lua:32-40`.

### 23. Auto-Save Not Batched

**File:** `main.lua:332` - Three systems (player_data, statistics, desktop_icons) independently write to disk every 30s with no coordination.

### 24. Duplicate Diagonal Normalization

**File:** `movement_controller.lua:60` and `:72` - `inv_sqrt2 = 0.70710678118` calculated twice. Should be module-level constant.

---

## WHAT'S GOOD

- **8 of 9 games** pass full architecture review (MVC, SchemaLoader, fixedUpdate, component usage)
- **All models** are clean - no love.* rendering calls in src/models/
- **SaveManager** has excellent pcall wrapping, error messages, version checking
- **13 game components** eliminate significant code duplication with strong reuse
- **Theme system** works well - 7 themes, ThemeManager, control panel, settings persistence
- **Demo system** is deterministic - all games use fixedUpdate at 60 FPS
- **ScrollbarController** used consistently - no custom scroll implementations found
- **Entity pooling** properly managed with removal callbacks
- **EventBus** now has unsubscribe() capability (just needs to be used)

---

## PRIORITY FIX ORDER

| # | Fix | Effort | Impact |
|---|-----|--------|--------|
| 1 | `DEBUG_FOG = true` -> false | 1 min | Performance in production |
| 2 | Remove debug print() calls (settings_manager + raycaster) | 5 min | Console spam |
| 3 | Gate token cheat keys behind debug | 5 min | Unintended player cheating |
| 4 | Fix space_shooter spiral determinism (`love.timer` -> `self.time_elapsed`) | 5 min | Demo playback broken |
| 5 | Wrap unprotected file I/O in pcall (6 locations) | 15 min | Crash on file errors |
| 6 | Move requires from inside functions to file top (3 locations) | 10 min | Convention violation |
| 7 | Save backup before delete | 15 min | Prevent progress loss |
| 8 | Show error on failed program launch | 15 min | Silent failures |
| 9 | EventBus cleanup / destroy() methods | 1-2 hrs | Memory leaks |
| 10 | Raycaster MVC cleanup | 2-3 hrs | Architecture violation |
| 11 | Remove love.graphics fallbacks from coin_flip + rps | 30 min | MVC violation |
| 12 | ThemeManager migration (remaining views) | 4-6 hrs | Theme consistency |
| 13 | desktop_state rendering -> view | 2-3 hrs | MVC violation |
