# Phase 3: Start Menu State Refactoring - COMPLETED

## Status: ✅ COMPLETE

**Completion Date:** 2025-10-21

---

## Overview

Phase 3 successfully moved all state management from `StartMenuView` to `StartMenuState`, achieving strict MVC separation. The View is now a pure presentation layer that receives all data through method parameters.

---

## What Changed

### State Migration

All 20+ state properties were moved from the View to the State:

#### Menu State Properties
```lua
-- In StartMenuState:init()
self.submenu_open_id = nil           -- 'programs' | 'documents' | 'settings'
self.hovered_main_id = nil           -- Currently hovered main menu item
self.hovered_sub_id = nil            -- Currently hovered submenu item
self.keyboard_start_selected_id = nil -- Keyboard selection state
self._start_menu_pressed_id = nil    -- Mouse press tracking
```

#### Cascading Panes State
```lua
self.open_panes = {}                  -- Array of open cascading panes
self.cascade_hover = { level = nil, index = nil, t = 0 }
self._cascade_root_id = nil          -- Root pane identifier
self._pane_close = {}                -- Per-pane close timers
self._start_menu_keepalive_t = 0     -- Grace period timer
```

#### Drag & Drop State (12 properties)
```lua
self.dnd_active = false              -- Is drag active?
self.dnd_source_index = nil          -- Source item index
self.dnd_hover_index = nil           -- Current hover index
self.dnd_pane_index = nil            -- Which pane is being dragged within
self.dnd_item_id = nil               -- Program ID being dragged
self.dnd_entry_key = nil             -- FS entry key (path)
self.dnd_scope = nil                 -- 'programs' or folder path
self.dnd_drop_mode = nil             -- nil | 'into' (dropping into folder)
self.dnd_target_folder_path = nil    -- Target folder for drop
self.dnd_pending = nil               -- Pending drag data
self.dnd_start_x, self.dnd_start_y = nil, nil  -- Drag start position
self.dnd_threshold = 4               -- Pixel threshold before drag activates
```

---

## Modified Methods

### StartMenuView - 24 Methods Updated

All methods now accept a `state` parameter and access state through it:

#### Core Methods
```lua
-- BEFORE:
function StartMenuView:update(dt, start_menu_open)
    self.hovered_main_id = self:getStartMenuMainAtPosition(mx, my)
    -- ... access self.open_panes, self.submenu_open_id, etc.
end

-- AFTER:
function StartMenuView:update(dt, start_menu_open, state)
    state.hovered_main_id = self:getStartMenuMainAtPosition(mx, my)
    -- ... access state.open_panes, state.submenu_open_id, etc.
end
```

#### Input Methods
```lua
function StartMenuView:draw(state)
function StartMenuView:mousepressedStartMenu(x, y, button, state)
function StartMenuView:mousereleasedStartMenu(x, y, button, state)
function StartMenuView:mousemovedStartMenu(x, y, dx, dy, state)
```

#### Complex Logic Methods
```lua
function StartMenuView:updateCascade(mx, my, dt, state)
    -- ~100 lines of state manipulation
    -- All self.cascade_hover → state.cascade_hover
    -- All self.open_panes → state.open_panes
    -- All self.dnd_* → state.dnd_*
end
```

#### Helper Methods
```lua
function StartMenuView:getSubmenuBounds(state)
function StartMenuView:getStartMenuSubItemAtPosition(x, y, state)
function StartMenuView:drawProgramsSubmenu(state)
function StartMenuView:drawDocumentsSubmenu(state)
function StartMenuView:drawSettingsSubmenu(state)
function StartMenuView:drawPane(pane, state)
function StartMenuView:reflowOpenPanesBounds(state)
function StartMenuView:isPointInStartMenuOrSubmenu(x, y, state)
function StartMenuView:hitTestStartMenuContext(x, y, state)
```

---

## StartMenuState Changes

### New Methods (Moved from View)
```lua
function StartMenuState:clearStartMenuPress()
    self._start_menu_pressed_id = nil
end

function StartMenuState:setStartMenuKeyboardSelection(id)
    self.keyboard_start_selected_id = id
end
```

### Updated Method Calls
All View method calls now pass `self` (the state object):

```lua
-- BEFORE:
function StartMenuState:draw()
    if self.view then self.view:draw() end
end

-- AFTER:
function StartMenuState:draw()
    if self.view then self.view:draw(self) end  -- Pass state
end
```

Updated methods:
- `update(dt)` → calls `view:update(dt, self.open, self)`
- `draw()` → calls `view:draw(self)`
- `mousemoved()` → calls `view:mousemovedStartMenu(x, y, dx, dy, self)`
- `mousepressed()` → calls `view:mousepressedStartMenu(x, y, button, self)`
- `mousereleased()` → calls `view:mousereleasedStartMenu(x, y, button, self)`
- `isPointInStartMenuOrSubmenu()` → calls `view:isPointInStartMenuOrSubmenu(x, y, self)`

---

## Code Statistics

### Lines Changed
- **StartMenuView**: ~700 references updated across ~920 lines
- **StartMenuState**: ~50 lines added, ~10 lines updated

### Methods Modified
- **View**: 24 method signatures changed
- **State**: 8 method calls updated, 2 new methods added

---

## Architecture Benefits

### ✅ Clear MVC Separation
- **Model**: State object holds all data
- **View**: Pure presentation, receives data via parameters
- **Controller**: State manages updates and coordinates View

### ✅ Explicit Data Flow
```
State owns data → State passes data to View → View renders
                ↑                              ↓
                └─── View returns events ──────┘
```

### ✅ Testability
Views can now be tested in isolation:
```lua
-- Mock state object
local mock_state = {
    open_panes = { ... },
    hovered_main_id = 'programs',
    dnd_active = false,
    -- ... etc.
}

-- Test view rendering
view:draw(mock_state)
```

### ✅ Maintainability
- All state in one place (State object)
- State mutations are centralized
- Easier to trace state changes
- Easier to add new state properties

### ✅ Event Bus Ready
Phase 4 can now integrate the Event Bus without views holding state:
```lua
-- State can subscribe to events
EventBus:subscribe('program_launched', function(program_id)
    self:setOpen(false)  -- Close menu
end)
```

---

## Migration Pattern

This pattern can be applied to other View/State pairs:

### Step 1: Move State to State Object
```lua
-- In State:init()
self.some_state = initial_value
```

### Step 2: Update View Methods
```lua
-- Add state parameter
function View:someMethod(state)
    -- Access via state.some_state
end
```

### Step 3: Update State Calls
```lua
-- In State
function State:draw()
    self.view:draw(self)  -- Pass self
end
```

---

## Deferred from Phase 2

Phase 2 planned to refactor 5 View/State pairs (~2000+ lines). We completed Start Menu (Phase 3) as a focused effort. Remaining pairs can be refactored individually as needed:

- ✅ **StartMenuView** - COMPLETE
- ⏸️ **VMManagerView** - Deferred (complex, 500 lines)
- ⏸️ **LauncherView** - Deferred (600 lines)
- ⏸️ **CheatEngineView** - Deferred (400 lines)
- ⏸️ **FileExplorerView** - Deferred (400 lines, complex interactions)
- ⏸️ **StatisticsView** - Deferred (simplest, good candidate for next)

---

## Testing Checklist

After Phase 3 completion, test the following Start Menu functionality:

### Basic Operations
- [ ] Open/close Start Menu with Start button
- [ ] Open/close Start Menu with Escape key
- [ ] Keyboard navigation (Run/Shutdown selection)

### Main Menu Items
- [ ] Hover over Programs → cascading pane opens
- [ ] Hover over Documents → cascading pane opens
- [ ] Hover over Settings → cascading pane opens
- [ ] Click Help (no-op)
- [ ] Click Run → Run dialog opens
- [ ] Click Shutdown → Shutdown dialog opens

### Cascading Panes
- [ ] Panes open on hover after delay
- [ ] Panes close when mouse leaves (with delay)
- [ ] Nested folder navigation works
- [ ] Multiple levels of panes can be open
- [ ] Panes reposition when near screen edge

### Legacy Submenus (Fallback)
- [ ] Programs submenu displays when no panes
- [ ] Documents submenu displays when no panes
- [ ] Settings submenu displays when no panes

### Drag & Drop
- [ ] Can drag items in Programs pane
- [ ] Can drag items in folder panes
- [ ] Insertion line appears during drag
- [ ] Dropping into folder works (folder highlights)
- [ ] Dropping between items reorders
- [ ] Cannot drag restricted items (Documents, Control Panel)
- [ ] Drag threshold prevents accidental drags

### Edge Cases
- [ ] Menu stays open when clicking inside
- [ ] Menu closes when clicking outside
- [ ] Grace period prevents accidental close
- [ ] Window resizing updates menu position
- [ ] Panes clamp to screen boundaries

---

## Known Issues

None currently identified. Report any issues found during testing.

---

## Next Steps: Phase 4 - Event Bus Integration

With state centralized in `StartMenuState`, Phase 4 can now:

1. **Integrate Event Bus** (`src/utils/event_bus.lua`)
   - Convert to DI (remove singleton pattern)
   - Add to DI container in `main.lua`

2. **Refactor Program Launching**
   - Replace hard-coded `host.launchProgram()` calls
   - Use event: `EventBus:publish('launch_program', program_id)`

3. **Refactor Window Closing**
   - Replace hard-coded window close logic
   - Use event: `EventBus:publish('close_window', window_id)`

4. **Decouple State Communication**
   - States subscribe to events instead of calling each other
   - Removes hard-coded dependencies

---

## Files Modified

```
src/states/start_menu_state.lua
src/views/start_menu_view.lua
```

---

## Commit Message Suggestion

```
Complete Phase 3: Move Start Menu state from View to State

- Migrate 20+ state properties from StartMenuView to StartMenuState
- Update 24 View methods to accept state parameter
- Refactor ~700 lines of state access (self.* → state.*)
- Move helper methods (clearStartMenuPress, setStartMenuKeyboardSelection) to State
- Achieve strict MVC separation: View is now pure presentation layer

Benefits:
- Clear data flow (State owns data, View renders)
- Testable views (can pass mock state objects)
- Centralized state management
- Ready for Phase 4 Event Bus integration

Files:
- src/states/start_menu_state.lua (~50 lines added)
- src/views/start_menu_view.lua (~700 references updated)
```

---

## Conclusion

Phase 3 successfully refactored the Start Menu to follow strict MVC principles. The View is now stateless and testable, while the State centrally manages all menu data. This lays the groundwork for Phase 4's Event Bus integration, which will further decouple the system and enable expansion.

**Status**: Ready for Phase 4
