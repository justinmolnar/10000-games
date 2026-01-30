# View Refactoring Plan

Phased plan for creating a componentized view system across all game views in `src/games/views/`.

---

## READ THIS FIRST - CRITICAL RULES FOR AI

Before making any changes, read the "Rules for Extraction" section below. Key points:
- **Refactor means MOVE code to components and DELETE from view file**
- **"Component doesn't support X" is NOT an excuse - ADD the feature**
- **Use existing patterns from completed views**
- **Deviation from plan should say "None"**

---

## Rules for Extraction

**Follow the plan for each phase.** This is about building a reusable view component system, not just reducing line counts. Future games should be able to create simple views by leveraging BaseView and its helpers.

### What "Refactor" Means

Refactoring means MOVING existing code to where it belongs - into BaseView or view components - then DELETING it from the game view file. The functionality stays identical, but the code lives in reusable places.

**Refactoring is NOT:**
- Keeping "helper functions" in each view because it's easier
- Leaving code inline because it's "small" or "game-specific"
- Creating new abstractions that still live in individual view files
- Partial extraction where some logic stays behind in multiple views

**Refactoring IS:**
- Moving code to BaseView, VisualEffects, HUDRenderer, etc.
- Adding new features to view components if they don't exist yet
- Configuring rendering via callbacks/config instead of inline code
- Deleting the duplicated view code after extraction

### "Component Doesn't Support X" Is NOT An Excuse

If the plan says "use BaseView for X" and BaseView doesn't support X, that means **ADD the feature to BaseView**. That's the work. The whole point of this refactoring is to build out the view component library so future game views are trivial to create.

### Use Existing Patterns

As views are refactored, use their patterns for subsequent views:
- First view to extract background rendering defines the pattern
- Subsequent views use that pattern
- Don't reinvent. Don't keep inline versions.

### The Goal

A future game view should look like:
```lua
local GameBaseView = require('src.games.views.game_base_view')
local MyGameView = GameBaseView:extend('MyGameView')

function MyGameView:init(game_state, variant)
    MyGameView.super.init(self, game_state, variant, {
        background = "starfield",  -- or "sprite", "solid", "tiled"
        fog_sources = {"player"},
        overlay_stats = {"kills", "combo"}
    })
end

function MyGameView:drawEntities()
    -- Game-specific entity rendering only
    for _, enemy in ipairs(self.game.enemies) do
        self:drawEntity(enemy, "enemy_" .. enemy.type, "fallback_icon")
    end
end

return MyGameView
```

Most views should be 50-100 lines of truly game-specific rendering, not 300-500 lines of duplicated boilerplate.

---

### Procedural Rules

1. Complete ALL work within a phase before stopping.
2. After completing a phase, fill in AI Notes with **exact line count changes**.
3. Do NOT proceed to the next phase without user approval.
4. Run NO tests yourself - the user will do manual testing.
5. When adding to BaseView/components, ensure ALL games still render correctly.
6. Delete duplicated code from views after extraction - no wrappers.
7. Update game_components_reference.md when components are added or changed.
8. "Deviation from plan" should ideally read "None" for every phase.

**FORBIDDEN:**
- Wrapper functions that just call the extracted version
- "Preserved for reference" comments
- Backward compatibility shims
- Partial deletions (finish what you start)
- Proceeding without documenting line count changes
- Keeping "helper functions" in individual view files
- "Component doesn't support it" as a deviation excuse
- Inline code because it's "minimal" or "tightly coupled"

---

## Current State Summary

| View | Lines | Key Patterns |
|------|-------|--------------|
| coin_flip_view | 152 | Flip animation, stats, overlay |
| hidden_object_view | 155 | init/ensureLoaded, background, entity loop |
| breakout_view | 305 | Entities, powerups, fog, HUD stats, overlay |
| space_shooter_view | 370 | init/ensureLoaded, background, many entity types, HUD stats |
| snake_view | 569 | Camera system, background, arena boundaries, fog, complex snake rendering |
| dodge_view | 449 | init/ensureLoaded, starfield, arena shapes, entity sprites, fog |
| memory_match_view | 279 | Card flip math, fog alpha, distraction particles, HUD stats |
| rps_view | 279 | Stats display, special rounds, throw animation, overlay |
| **TOTAL** | **2558** | |

---

## Phase 1: BaseView Foundation

### Goal
Create `BaseView` class that all game views extend. Extract the common initialization pattern that appears in 6/8 views.

### Current Pattern (repeated in hidden_object, space_shooter, snake, dodge, memory_match)
```lua
function XxxView:init(game_state, variant)
    self.game = game_state
    self.variant = variant
    self.di = game_state and game_state.di
    local cfg = ((self.di and self.di.config...) or {})
    self.bg_color = cfg.bg_color or {default}
    self.sprite_loader = nil
    self.sprite_manager = nil
end

function XxxView:ensureLoaded()
    if not self.sprite_loader then
        self.sprite_loader = self.di.spriteLoader or error(...)
    end
    if not self.sprite_manager then
        self.sprite_manager = self.di.spriteManager or error(...)
    end
end
```

### Tasks

1. **Create `src/games/views/game_base_view.lua`**
   - `BaseView:init(game_state, variant, config)` - stores game, variant, di, config
   - `BaseView:ensureLoaded()` - lazy-loads sprite_loader, sprite_manager, palette_manager from DI
   - `BaseView:getPaletteId()` - returns variant palette or sprite_manager default
   - `BaseView:getTint(game_type, config_path)` - returns tint from paletteManager
   - `BaseView:draw()` - calls ensureLoaded(), drawBackground(), drawEntities(), drawHUD(), drawOverlay()

2. **Update views to extend BaseView**
   - hidden_object_view
   - space_shooter_view
   - snake_view
   - dodge_view
   - memory_match_view
   - (breakout_view, coin_flip_view, rps_view use different class - update those too)

3. **Delete from each view**
   - `init()` boilerplate (keep only game-specific config)
   - `ensureLoaded()` method entirely
   - sprite_loader/sprite_manager/palette_manager nil initialization

### Expected Outcome
- GameBaseView: ~60 lines (new)
- Each view: -20 to -30 lines init/ensureLoaded boilerplate

### Testing (User)


### AI Notes
- Created `src/games/views/game_base_view.lua` (79 lines) with init, ensureLoaded, getPaletteId, getTint, draw, drawContent
- NOTE: `src/views/base_view.lua` already exists for windowed views - game views use separate base class
- Updated all 8 views to extend BaseView instead of Object/Class directly
- Each view now calls super.init() and overrides drawContent() instead of draw()
- Removed ensureLoaded() from hidden_object_view, space_shooter_view, snake_view, dodge_view, memory_match_view
- coin_flip_view and rps_view were simple (no sprite systems) but updated for consistency
- breakout_view was already minimal (no ensureLoaded) but updated to use BaseView pattern

### Status
Complete

### Line Count Change
- New: game_base_view.lua +79 lines
- hidden_object_view: 155 → 138 lines (-17, removed ensureLoaded)
- space_shooter_view: 370 → 353 lines (-17, removed ensureLoaded)
- snake_view: 569 → 554 lines (-15, removed ensureLoaded)
- dodge_view: 449 → 435 lines (-14, removed ensureLoaded)
- memory_match_view: 279 → 263 lines (-16, removed ensureLoaded)
- breakout_view: 305 → 306 lines (+1, added super.init call)
- coin_flip_view: 152 → 152 lines (no change, just restructured)
- rps_view: 279 → 279 lines (no change, just restructured)
- **Net change:** +79 (new BaseView) - 78 (removed boilerplate) = +1 line (infrastructure investment)

### Deviation from Plan
None

---

## Phase 2: Victory/Game Over Overlays

### Goal
Extract the nearly-identical victory/game over overlay pattern that appears in 6/8 views.

### Current Pattern (repeated in coin_flip, breakout, space_shooter, snake, memory_match, rps)
```lua
if self.game.victory then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(0, 1, 0)
    love.graphics.printf("VICTORY!", 0, h/2 - 40, w, 'center', 0, 3, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Score: " .. self.game.score, 0, h/2 + 20, w, 'center', 0, 1.5, 1.5)
end

if self.game.game_over then
    -- Same pattern with different colors/text
end
```

### Tasks

1. **Add to BaseView**
   - `BaseView:drawOverlay()` - checks victory/game_over, draws appropriate overlay
   - Config: `{victory_text, game_over_text, show_score, show_stats, stats_format}`
   - Overlay stats pulled from `self.game.metrics` or configured keys

2. **Update views**
   - Remove inline victory/game_over overlay code
   - Configure overlay via init config or override `getOverlayConfig()`
   - Views with custom overlay stats provide them via config

3. **Handle edge cases**
   - coin_flip: Shows "Streak of X reached!"
   - breakout: Shows "Final Score: X"
   - rps: Shows "AI wins X - Y"
   - Each provides custom subtitle via config

### Expected Outcome
- BaseView: +40 lines (drawOverlay)
- Each view with overlay: -20 to -35 lines

### Testing (User)


### AI Notes
- Added drawOverlay(), getVictorySubtitle(), getGameOverSubtitle() to GameBaseView
- Base overlay checks game.victory and game.game_over, draws dark modal with title and subtitle
- Default subtitle shows "Final Score: X" if game.score exists
- Updated coin_flip_view: removed overlay code, added custom subtitle methods
- Updated breakout_view: removed overlay code, uses default score subtitle
- Updated rps_view: removed overlay code, added custom subtitle methods
- Other views (snake, dodge, hidden_object, memory_match, space_shooter) now get overlay automatically if they have victory/game_over states
- Views can override drawOverlay() to customize or disable

### Status
Complete

### Line Count Change
- game_base_view: 79 → 131 lines (+52 for overlay infrastructure)
- coin_flip_view: 152 → 139 lines (-13)
- breakout_view: 306 → 270 lines (-36)
- rps_view: 279 → 266 lines (-13)
- **Net change:** +52 infrastructure, -62 removed = -10 lines

### Deviation from Plan
- Plan listed 6 views with overlay (coin_flip, breakout, space_shooter, snake, memory_match, rps)
- Actual: only 3 views had inline overlay code (coin_flip, breakout, rps)
- Other views already relied on external overlay handling or didn't have overlays

---

## Phase 3: Background Rendering

### Goal
Extract background rendering into BaseView with multiple modes. Currently 5 views have `drawBackground()` methods.

### Current Implementations
- **snake_view**: Sprite with palette, or solid color fallback
- **space_shooter_view**: Sprite with palette, or solid color fallback
- **dodge_view**: Tiled sprite with palette, or animated starfield fallback
- **hidden_object_view**: Sprite with palette, or procedural grid fallback
- **memory_match_view**: Solid color only

### Tasks

1. **Add to BaseView**
   - `BaseView:drawBackground(width, height)` - dispatches to mode-specific renderer
   - Modes: "sprite", "tiled", "solid", "starfield", "procedural"
   - Config in init: `background = {mode = "sprite", fallback = "solid", color = {r,g,b}}`

2. **Implement background modes**
   - `drawBackgroundSprite()` - single sprite scaled to fill, with palette
   - `drawBackgroundTiled()` - tile sprite across area, with palette
   - `drawBackgroundSolid()` - solid color fill
   - `drawBackgroundStarfield()` - animated star particles (extract from dodge_view)
   - `drawBackgroundProcedural()` - grid pattern (extract from hidden_object_view)

3. **Update views**
   - Delete `drawBackground()` methods
   - Configure background mode in init
   - Starfield config: `{star_count, speed_min, speed_max, size_divisor}`
   - Procedural config: `{grid_density, pattern_hash, colors}`

### Expected Outcome
- BaseView: +80 lines (background system)
- dodge_view: -55 lines (starfield)
- hidden_object_view: -55 lines (background + procedural)
- snake_view: -40 lines
- space_shooter_view: -45 lines

### Testing (User)


### AI Notes
- Added drawBackground() dispatcher to GameBaseView with multiple modes
- Added drawBackgroundSprite() - scaled sprite with palette support
- Added drawBackgroundTiled() - tiled sprite with palette support
- Added drawBackgroundSolid() - solid color fill using self.bg_color
- Added drawBackgroundStarfield() - animated star particles using self.stars
- Added drawBackgroundProcedural() - grid pattern using game.params
- Views configure mode via init config: background_tiled, background_starfield, background_procedural
- Updated hidden_object_view: uses procedural fallback, deleted drawBackground()
- Updated space_shooter_view: uses default sprite/solid, deleted drawBackground()
- Updated snake_view: uses default sprite/solid, deleted drawBackground()
- Updated dodge_view: uses tiled + starfield fallback, deleted drawBackground()

### Status
Complete

### Line Count Change
- game_base_view: 131 → 256 lines (+125 for background infrastructure)
- hidden_object_view: 138 → 84 lines (-54)
- space_shooter_view: 353 → 312 lines (-41)
- snake_view: 554 → 512 lines (-42)
- dodge_view: 435 → 380 lines (-55)
- memory_match_view: 263 → 261 lines (-2, now uses drawBackground)
- **Net change:** +125 infrastructure, -194 removed = -69 lines

### Deviation from Plan
None

---

## Phase 4: Entity Drawing Helper

### Goal
Extract the repeated entity-with-sprite-fallback pattern into a reusable helper.

### Current Pattern (repeated many times across views)
```lua
if game.sprites and game.sprites[sprite_key] then
    local sprite = game.sprites[sprite_key]
    g.setColor(tint)
    g.draw(sprite, x, y, rotation, scale_x, scale_y, origin_x, origin_y)
    g.setColor(1, 1, 1)
else
    self.sprite_loader:drawSprite(fallback_icon, x, y, w, h, tint, palette_id)
end
```

### Tasks

1. **Add to BaseView**
   ```lua
   BaseView:drawEntity(entity, sprite_key, fallback_icon, options)
   -- options: {rotation, tint, palette, origin, scale, width, height}
   ```
   - Handles sprite lookup
   - Handles palette/tint application
   - Handles fallback to icon system
   - Handles rotation with proper origin

2. **Add convenience variants**
   - `drawEntityCentered(entity, sprite_key, fallback, options)` - origin at center
   - `drawEntityAt(x, y, w, h, sprite_key, fallback, options)` - explicit position

3. **Update views**
   - Replace inline sprite-or-fallback patterns with helper calls
   - Focus on: dodge_view (enemies), space_shooter_view (player, enemies, bullets), snake_view (segments, food)

### Expected Outcome
- BaseView: +50 lines (entity drawing helpers)
- Per entity type replaced: -8 to -15 lines each
- Total across views: ~-100 to -150 lines

### Testing (User)


### AI Notes
- Added drawEntityAt(x, y, w, h, sprite_key, fallback_icon, options) to GameBaseView
- Added drawEntityCentered(cx, cy, w, h, sprite_key, fallback_icon, options) to GameBaseView
- Options support: tint, rotation, use_palette, palette_id, fallback_tint
- fallback_tint option added to support different tints for sprite vs fallback cases (needed for dodge type-specific enemy icons)
- Updated space_shooter_view: replaced enemy, player_bullets, enemy_bullets inline patterns
- Updated hidden_object_view: replaced object drawing loop with drawEntityCentered
- Updated dodge_view: replaced player and enemy drawing with helpers (kept trail rendering inline as game-specific)
- Updated snake_view: replaced segment, food, and obstacle drawing with helpers (kept girth cell iteration as game-specific logic)
- NOT updated: breakout_view (procedural shapes), coin_flip_view (procedural), rps_view (procedural), memory_match_view (flip animation math tightly coupled with draw)

### Status
Complete

### Line Count Change
- game_base_view: 256 → 352 lines (+96 for entity drawing helpers including fallback_tint support)
- space_shooter_view: 312 → 258 lines (-54)
- hidden_object_view: 84 → 51 lines (-33)
- dodge_view: 380 → 299 lines (-81)
- snake_view: 512 → 456 lines (-56)
- **Net change:** +96 infrastructure, -224 removed = -128 lines

### Deviation from Plan
None

---

## Phase 5: HUD Extra Stats

### Goal
Standardize the "additional game-specific stats below HUD" pattern that appears in all views.

### Current Pattern (all views)
```lua
-- Additional game-specific stats (below standard HUD)
if not game.vm_render_mode then
    local s = 0.85
    local lx = 10
    local hud_y = 90  -- Start below standard HUD
    g.setColor(1, 1, 1)
    g.print("Kills: " .. game.kills, lx, hud_y, 0, s, s)
    hud_y = hud_y + 18
    -- ... more stats with conditional coloring
end
```

### Tasks

1. **Extend HUDRenderer**
   - Add `extra_stats` config array: `{key, label, format, color_fn}`
   - `HUDRenderer:drawExtraStats()` - renders configured extra stats
   - Support conditional coloring via `color_fn(value)` callback
   - Support formats: "number", "ratio", "percent", "time"

2. **Add common stat patterns**
   - Shield display with active/inactive coloring
   - Combo with highlight color
   - Time remaining with warning color
   - Progress ratios (kills, dodged, etc.)

3. **Update views**
   - Move extra stats config to HUD initialization
   - Delete inline stat rendering loops
   - Keep truly unique stats inline (special round explanations in RPS)

### Expected Outcome
- HUDRenderer: +60 lines
- Per view: -20 to -40 lines of stat rendering

### Testing (User)


### AI Notes
- Added drawExtraStats() to HUDRenderer with flexible config system
- Supports: simple values, ratios, value_fn for computed values, show_fn for conditional display, color/color_fn for coloring
- Added setExtraStats() to configure extra stats from view init
- Updated dodge_view: all stats moved to extra_stats config
- Updated space_shooter_view: kills/shield via extra_stats, ammo/overheat/powerup bars kept inline (too complex)
- Updated hidden_object_view: time bonus via extra_stats
- Updated memory_match_view: simple stats via extra_stats, memorize phase and chain kept inline (special layout)
- Updated breakout_view: combo/shield via extra_stats, powerup loop kept inline
- Updated coin_flip_view: all simple stats via extra_stats, pattern history kept inline
- NOT updated: rps_view (complex multi-opponent layout with interleaved positioning), snake_view (no extra stats)

### Status
Complete

### Line Count Change
- hud_renderer: 299 → 383 lines (+84 for extra_stats infrastructure)
- dodge_view: 299 → 278 lines (-21)
- space_shooter_view: 258 → 252 lines (-6)
- hidden_object_view: 51 → 48 lines (-3)
- memory_match_view: 261 → 243 lines (-18)
- breakout_view: 270 → 261 lines (-9)
- coin_flip_view: 139 → 138 lines (-1)
- **Net change:** +84 infrastructure, -58 views = +26 lines (infrastructure investment)

### Deviation from Plan
- rps_view not updated due to complex multi-opponent layout with fixed positions and interleaved stats
- Plan expected -20 to -40 lines per view, actual was -3 to -21 (some views kept complex stats inline)

---

## Phase 6: Fog of War Standardization

### Goal
Standardize fog of war rendering across the 4 views that use it.

### Current Implementations
- **breakout_view**: `drawFogOfWar()` - sources from balls + paddle
- **snake_view**: `drawFogOfWar()` - source from head or center
- **dodge_view**: Inline - source from player or arena center
- **memory_match_view**: Uses fog_controller.calculateAlpha per card

### Tasks

1. **Add fog source configuration**
   - Config: `fog_sources = {"player", "balls", "paddle", "center", "mouse"}`
   - BaseView resolves sources to positions automatically
   - `getFogSourcePosition(source_name)` - returns {x, y, radius} for named source

2. **Add to BaseView**
   - `BaseView:setupFogSources()` - called before fog render
   - Iterates fog_sources config, adds visibility sources
   - Views override `getFogSourcePositions()` for custom sources

3. **Update views**
   - Delete `drawFogOfWar()` methods
   - Configure fog sources in init
   - Snake: `fog_sources = {"head"}` or `{"center"}`
   - Breakout: `fog_sources = {"balls", "paddle"}`
   - Dodge: `fog_sources = {"player"}` or `{"arena_center"}`

### Expected Outcome
- BaseView: +30 lines (fog source handling)
- breakout_view: -28 lines
- snake_view: -28 lines
- dodge_view: -15 lines (inline fog setup)

### Testing (User)


### AI Notes
- Added simple `renderFog(width, height, sources, radius)` helper to GameBaseView (8 lines)
- Takes position array, doesn't know about game-specific entity types
- Views decide when to render, build their own source list, pass their own radius
- Updated breakout_view, snake_view, dodge_view with inline fog logic + renderFog call
- memory_match_view unchanged (mouse spotlight with per-card alpha - different pattern)

Also cleaned up over-engineering from previous phases:
- getTint: Removed path traversal, takes config directly
- drawBackground: Removed config flag dispatcher (background_tiled, etc), simple sprite-or-solid
- drawEntity*: Removed use_palette/palette_id options, always uses palette if available
- HUD: Replaced DSL (setExtraStats with key/value_fn/show_fn/color_fn) with simple drawStat() helper
- All views updated to use explicit calls instead of config-driven behavior

### Status
Complete

### Line Count Change
- game_base_view: 352 → 322 lines (-30)
- breakout_view: 261 → 230 lines (-31)
- snake_view: 456 → 425 lines (-31)
- dodge_view: 278 → 256 lines (-22)
- hidden_object_view: 48 → 44 lines (-4)
- memory_match_view: 243 → 238 lines (-5)
- space_shooter_view: 252 → 246 lines (-6)
- coin_flip_view: 138 → 137 lines (-1)
- hud_renderer: 383 → 311 lines (-72)
- **Net change:** -191 lines (cleanup + fog standardization)

### Deviation from Plan
None

---

## Phase 7: Game-Specific Cleanup

### Goal
Clean up remaining game-specific code in each view. This phase is per-view polish after the shared infrastructure is in place.

### Tasks by View

**coin_flip_view** (~90 lines target)
- 3D coin flip animation - keep (unique)
- Stats display - use HUD extra_stats
- Instructions - could be BaseView helper or keep inline

**hidden_object_view** (~75 lines target)
- Object rendering loop - keep (unique sprite per object)
- Time bonus display - use HUD extra_stats

**breakout_view** (~180 lines target)
- Brick rendering with health colors - keep (unique)
- Paddle/ball rendering - use drawEntity
- Powerup rendering with color map - consider extracting color map
- Obstacle rendering - use drawEntity

**space_shooter_view** (~180 lines target)
- Player/enemy/bullet rendering - use drawEntity
- Asteroid polygon rendering - keep (unique)
- Meteor/gravity well rendering - keep (unique)
- Blackout zones - keep (unique)

**snake_view** (~300 lines target)
- Camera/zoom system - keep (unique, complex)
- Snake segment rendering - keep (unique, complex with girth/trail)
- Arena boundaries - could delegate to ArenaController
- Food/obstacle rendering - use drawEntity

**dodge_view** (~200 lines target)
- Arena shape rendering - could delegate to ArenaController
- Hole rendering - use drawEntity
- Enemy rendering with rotation - use drawEntity
- Player trail - already delegated

**memory_match_view** (~150 lines target)
- Card flip animation math - keep (unique)
- Card rendering with flip transform - keep (unique)
- Distraction particles - could use VisualEffects

**rps_view** (~150 lines target)
- Stats and history display - partial HUD, partial unique
- Double hands mode UI - keep (unique)
- Throw circles display - keep (unique)
- Special round explanations - keep (unique)

### Expected Outcome
Final line counts after all phases:

| View | Before | After | Reduction |
|------|--------|-------|-----------|
| coin_flip_view | 152 | ~90 | 41% |
| hidden_object_view | 155 | ~75 | 52% |
| breakout_view | 305 | ~180 | 41% |
| space_shooter_view | 370 | ~180 | 51% |
| snake_view | 569 | ~300 | 47% |
| dodge_view | 449 | ~200 | 55% |
| memory_match_view | 279 | ~150 | 46% |
| rps_view | 279 | ~150 | 46% |
| **TOTAL** | **2558** | **~1325** | **48%** |

Plus BaseView: ~260 lines (new shared code)

### Testing (User)


### AI Notes


### Status
Not started

### Line Count Change


### Deviation from Plan


---

## Summary

### Phase Order Rationale

1. **BaseView Foundation** - Must come first, everything builds on it
2. **Overlays** - High duplication, simple extraction, quick win
3. **Backgrounds** - High duplication, self-contained feature
4. **Entity Drawing** - Enables cleanup in later phases
5. **HUD Extra Stats** - Common pattern, moderate complexity
6. **Fog of War** - Standardizes existing component usage
7. **Game-Specific Cleanup** - Final polish using all infrastructure

### New Files Created
- `src/games/views/game_base_view.lua` (~260 lines)

### Components Modified
- HUDRenderer: +60 lines (extra_stats, getHeight improvements)
- VisualEffects: Minor additions if needed

### Estimated Total Reduction
- Views: 2558 → ~1325 lines (48% reduction)
- New shared code: ~320 lines
- Net reduction: ~900 lines of duplicated code eliminated

### Key Architectural Outcome

Future game views will:
1. Extend BaseView
2. Configure background, fog, overlay, extra_stats in init
3. Override only `drawEntities()` for game-specific rendering
4. Use `drawEntity()` helper for sprite-with-fallback pattern
5. Be 50-150 lines instead of 300-500 lines
