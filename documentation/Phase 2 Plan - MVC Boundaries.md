# Phase 2: Stricter Model-View-Controller Boundaries - Implementation Plan

## Status: PLANNED (Not Yet Implemented)

## Overview
Phase 2 aims to decouple Views from Controllers/States by passing data explicitly as parameters rather than Views accessing controller/model properties directly.

## Why This Refactoring?

**Current Problem:**
Views currently hold references to controllers and models (`self.controller`, `self.player_data`, `self.vm_manager`, etc.) and access them directly. This creates tight coupling that makes:
- Views harder to test in isolation
- Data flow implicit and hard to trace
- Changes to model structure break views

**Goal:**
Views should be pure presentation components that receive all needed data through method parameters. Controllers/States should explicitly gather and pass data.

## Implementation Strategy

For each View/State pair:
1. **Identify Dependencies**: Find all `self.controller.*`, `self.model.*` accesses in View
2. **Modify View Signatures**: Update `draw()` and `update()` to accept data parameter objects
3. **Update State Calls**: Modify State to gather and pass data explicitly
4. **Refactor View**: Replace property access with parameter access
5. **Test**: Verify functionality remains unchanged

---

## Pair 1: VMManagerView & VMManagerState

### Current Dependencies in VMManagerView:
```lua
-- Accessed properties:
self.controller.viewport
self.vm_manager.vm_slots
self.vm_manager.max_slots
self.vm_manager.total_tokens_per_minute
self.player_data.tokens
self.player_data.upgrades
self.game_data (for game lookups)
```

### Proposed Changes:

**VMManagerView.lua:**
```lua
-- BEFORE:
function VMManagerView:init(controller, vm_manager, player_data, game_data, di)
    self.controller = controller
    self.vm_manager = vm_manager
    self.player_data = player_data
    self.game_data = game_data
    ...
end

function VMManagerView:drawWindowed(filtered_games, viewport_width, viewport_height)
    UIComponents.drawTokenCounter(..., self.player_data.tokens)
    self:drawTokensPerMinute(..., self.vm_manager.total_tokens_per_minute)
    local slots = self.vm_manager.vm_slots
    ...
end

-- AFTER:
function VMManagerView:init(di)
    -- Only store DI, no controller/model refs
    self.di = di
    ...
end

function VMManagerView:drawWindowed(data)
    -- data = {
    --   filtered_games,
    --   viewport_width, viewport_height,
    --   player_tokens,
    --   player_upgrades,
    --   vm_slots,
    --   max_slots,
    --   total_tokens_per_minute,
    --   game_data_lookup  -- function closure
    -- }
    UIComponents.drawTokenCounter(..., data.player_tokens)
    self:drawTokensPerMinute(..., data.total_tokens_per_minute)
    local slots = data.vm_slots
    ...
end
```

**VMManagerState.lua:**
```lua
-- BEFORE:
function VMManagerState:draw()
    self.view:drawWindowed(self.filtered_games, self.viewport.width, self.viewport.height)
end

-- AFTER:
function VMManagerState:draw()
    local data = {
        filtered_games = self.filtered_games,
        viewport_width = self.viewport.width,
        viewport_height = self.viewport.height,
        player_tokens = self.player_data.tokens,
        player_upgrades = self.player_data.upgrades,
        vm_slots = self.vm_manager.vm_slots,
        max_slots = self.vm_manager.max_slots,
        total_tokens_per_minute = self.vm_manager.total_tokens_per_minute,
        game_data_lookup = function(id) return self.game_data:getGame(id) end
    }
    self.view:drawWindowed(data)
end
```

### Files to Modify:
- `src/views/vm_manager_view.lua` (~500 lines)
- `src/states/vm_manager_state.lua` (~250 lines)

### Estimated Complexity: **HIGH**
- Many nested method calls passing context objects
- Complex modal and interaction logic
- ~15-20 methods need signature changes

---

## Pair 2: LauncherView & LauncherState

### Current Dependencies in LauncherView:
```lua
self.controller (for events)
self.player_data.unlocked_games
self.player_data.game_performance
self.game_data (for game lookups)
```

### Proposed Pattern:
Similar to VMManagerView - pass all data through `draw()` and `update()` parameters.

### Files to Modify:
- `src/views/launcher_view.lua` (~600 lines)
- `src/states/launcher_state.lua` (~150 lines)

### Estimated Complexity: **MEDIUM-HIGH**
- Simpler than VMManager
- Heavy filtering/sorting logic

---

## Pair 3: CheatEngineView & CheatEngineState

### Current Dependencies:
```lua
self.controller.selected_game
self.controller.cheat_system
self.player_data.tokens
self.game_data (lookups)
```

### Files to Modify:
- `src/views/cheat_engine_view.lua` (~400 lines)
- `src/states/cheat_engine_state.lua` (~200 lines)

### Estimated Complexity: **MEDIUM**

---

## Pair 4: StatisticsView & StatisticsState

### Current Dependencies:
```lua
self.controller.statistics
```

### Files to Modify:
- `src/views/statistics_view.lua`
- `src/states/statistics_state.lua`

### Estimated Complexity: **LOW**
- Simplest refactoring
- Mostly read-only data display

---

## Pair 5: FileExplorerView & FileExplorerState

### Current Dependencies:
```lua
self.controller (navigation, file ops)
self.controller.file_system
self.controller.recycle_bin
self.controller.program_registry
```

### Files to Modify:
- `src/views/file_explorer_view.lua` (~400 lines)
- `src/states/file_explorer_state.lua` (~300 lines)

### Estimated Complexity: **HIGH**
- Complex interaction patterns
- Many file operations
- Context menu integration

---

## Implementation Priority (Recommended Order)

1. **StatisticsView** (Easiest, good learning)
2. **LauncherView** (Moderate complexity, high value)
3. **CheatEngineView** (Medium complexity)
4. **VMManagerView** (Complex but important)
5. **FileExplorerView** (Most complex, do last)

## Risks & Considerations

### Risks:
1. **Breaking Changes**: Any mistake breaks the entire view
2. **Testing Burden**: Need to manually test all interactions after each refactoring
3. **Time Investment**: Each pair = 2-4 hours of work
4. **Regression Risk**: Complex views like VMManager have many edge cases

### Mitigation:
- Do one pair at a time
- Test thoroughly after each
- Consider git commits between each pair
- Keep Phase 1 working state as fallback

## Benefits of Completion

✅ **Testability**: Views can be tested with mock data
✅ **Clarity**: Data flow is explicit and traceable
✅ **Flexibility**: Can reuse views with different data sources
✅ **Maintainability**: Changes to models don't cascade to views
✅ **Architecture**: Clear MVC separation

## Alternative Approach: Incremental

Instead of doing all 5 pairs at once, consider:
1. Do StatisticsView first (proof of concept)
2. Evaluate if the pattern works well
3. Decide whether to continue with others
4. Could leave some views coupled if they're stable and not changing

## Decision Point

**Question**: Is this refactoring worth the investment right now?

**Consider:**
- ✅ Phase 1 is complete and working
- ✅ Current architecture is functional
- ⚠️ Phase 2 is large and risky
- ⚠️ Benefits are architectural, not functional
- ⚠️ No user-facing improvements

**Recommendation**:
- Mark Phase 2 as **PLANNED**
- Defer until there's a concrete need (e.g., adding tests, major view changes)
- Focus on Phase 3+ or new features instead
- Revisit Phase 2 when refactoring individual views for other reasons

---

## Conclusion

Phase 2 is a valuable architectural improvement but represents significant work with limited immediate benefit. The current codebase works well after Phase 1.

**Status**: Documented and planned, ready to implement when needed.

**Next Steps**: Proceed to Phase 3 (Simplify State Logic) or Phase 4 (Event Bus) which may provide more immediate value.
