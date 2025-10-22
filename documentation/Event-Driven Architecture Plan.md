# Event-Driven Architecture: Complete Refactoring Plan

## Executive Summary

This document outlines a comprehensive refactoring plan to transform the codebase into a fully event-driven architecture using the EventBus. The goal is to **separate data from logic** by having components publish events when state changes occur, and having other components subscribe to react to those changes - rather than having tight coupling through direct method calls.

**Core Principle**: "Don't call me, I'll call you" - Components should announce what happened (events), not dictate what should happen next (direct calls).

---

## Current Status

### ✅ Phase 4.1 Complete: Program Launching
- StartMenuState publishes `launch_program` events
- DesktopState subscribes and handles program launching
- Successfully decoupled Start Menu from Desktop

### Problems This Solves
- Start Menu no longer needs to know about DesktopState
- Multiple subscribers can react to program launches (e.g., analytics, logging)
- Easier to test Start Menu in isolation

---

## Architecture Philosophy

### Before: Tight Coupling (Bad)
```lua
-- Component A directly calls Component B
function StartMenuState:onProgramClick(program_id)
    self.host.launchProgram(program_id)  -- Tight coupling to host
end
```

**Problems**:
- Component A must know about Component B's API
- Hard to test Component A without Component B
- Can't add new behaviors without modifying Component A
- Circular dependencies common

### After: Event-Driven (Good)
```lua
-- Component A publishes an event (announces what happened)
function StartMenuState:onProgramClick(program_id)
    self.event_bus:publish('program_requested', program_id)
end

-- Component B subscribes (reacts to what happened)
function DesktopState:init(di)
    di.eventBus:subscribe('program_requested', function(program_id)
        self:launchProgram(program_id)
    end)
end
```

**Benefits**:
- Components are decoupled
- Easy to test with mock EventBus
- Add new behaviors by adding subscribers
- No circular dependencies

---

## Refactoring Roadmap

### Phase 4.2: Window Management Events

**Current Problem**: Direct coupling between window operations and state management

#### Events to Add:
```lua
-- Window lifecycle
'window_opened'          -- (window_id, program_id)
'window_closed'          -- (window_id)
'window_focused'         -- (window_id)
'window_minimized'       -- (window_id)
'window_restored'        -- (window_id)
'window_moved'           -- (window_id, x, y)
'window_resized'         -- (window_id, width, height)

-- Window interactions
'window_drag_started'    -- (window_id)
'window_drag_ended'      -- (window_id)
```

#### Files to Modify:
1. **WindowController** (`src/controllers/window_controller.lua`)
   - Replace direct WindowManager calls with events
   - Publish events when windows are created, closed, focused, etc.

2. **WindowManager** (`src/models/window_manager.lua`)
   - Subscribe to window events
   - Handle actual window state changes
   - Publish events when internal state changes

3. **DesktopState** (`src/states/desktop_state.lua`)
   - Subscribe to window events for UI updates
   - Remove direct WindowController coupling

#### Benefits:
- Can add window event logging without touching window code
- Easy to implement "recently closed windows" feature
- Analytics can track window usage patterns
- Undo/redo system could subscribe to all window events

---

### Phase 4.3: Desktop Icon Events

**Current Problem**: Desktop icons, file system, and recycle bin are tightly coupled

#### Events to Add:
```lua
-- Desktop icon operations
'icon_created'           -- (program_id, x, y)
'icon_moved'             -- (program_id, old_x, old_y, new_x, new_y)
'icon_deleted'           -- (program_id)
'icon_double_clicked'    -- (program_id)
'icon_right_clicked'     -- (program_id, x, y)

-- Icon drag & drop
'icon_drag_started'      -- (program_id)
'icon_drag_ended'        -- (program_id, dropped_on_target)
'icon_dropped_on_icon'   -- (source_program_id, target_program_id)
'icon_dropped_on_desktop' -- (program_id, x, y)
```

#### Files to Modify:
1. **DesktopIconController** (`src/controllers/desktop_icon_controller.lua`)
   - Publish events for all icon operations
   - Remove direct calls to DesktopIcons model

2. **DesktopIcons** (`src/models/desktop_icons.lua`)
   - Subscribe to icon events
   - Handle actual position/state changes
   - Keep as pure data model

3. **DesktopState**
   - Subscribe to icon events for rendering updates
   - Remove direct icon manipulation

#### Benefits:
- Can implement icon animation system by subscribing to move events
- Desktop layout history/undo
- Auto-organize features (subscribe to icon_created, reposition automatically)
- Accessibility features (announce icon operations)

---

### Phase 4.4: File System Events

**Current Problem**: File operations scattered across multiple components

#### Events to Add:
```lua
-- File/folder operations
'file_created'           -- (path, type, content)
'file_deleted'           -- (path)
'file_moved'             -- (old_path, new_path)
'file_renamed'           -- (old_path, new_path)
'file_opened'            -- (path)
'file_modified'          -- (path, new_content)

-- Folder operations
'folder_created'         -- (path)
'folder_deleted'         -- (path)
'folder_opened'          -- (path)
'folder_navigated'       -- (old_path, new_path)

-- Recycle bin operations
'item_recycled'          -- (path, item_data)
'item_restored'          -- (path)
'recycle_bin_emptied'    -- ()
```

#### Files to Modify:
1. **FileSystem** (`src/models/file_system.lua`)
   - Publish events for all CRUD operations
   - Keep as pure data model
   - Make methods side-effect free (just update data + publish)

2. **RecycleBin** (`src/models/recycle_bin.lua`)
   - Publish events for recycle/restore/empty
   - Subscribe to file_deleted to auto-recycle

3. **FileExplorerState** (`src/states/file_explorer_state.lua`)
   - Subscribe to file system events
   - Update UI when files change
   - Publish navigation events

4. **StartMenuState**
   - Subscribe to file system events for Documents menu
   - Auto-update when files are added/removed

#### Benefits:
- File change notifications (like modern file watchers)
- Sync file system state across multiple FileExplorer windows
- Backup system (subscribe to all file events, log changes)
- Search indexing (subscribe to file_created/modified)

---

### Phase 4.5: Launcher/Shop Events

**Current Problem**: Launcher window directly manipulates player data and game data

#### Events to Add:
```lua
-- Game purchasing
'game_purchased'         -- (game_id, cost)
'purchase_failed'        -- (game_id, reason)
'game_unlocked'          -- (game_id)

-- Game launching from Launcher
'game_launch_requested'  -- (game_id)
'game_launched'          -- (game_id, vm_id)
'game_launch_failed'     -- (game_id, reason)

-- Shop interactions
'shop_opened'            -- ()
'shop_category_changed'  -- (category)
'game_details_viewed'    -- (game_id)
```

#### Files to Modify:
1. **LauncherState** (`src/states/launcher_state.lua`)
   - Publish events instead of directly calling PlayerData/GameData
   - Subscribe to game_unlocked to refresh UI

2. **PlayerData** (`src/models/player_data.lua`)
   - Subscribe to game_purchased events
   - Update tokens/unlocked games
   - Publish game_unlocked event

3. **VMManager** (`src/models/vm_manager.lua`)
   - Subscribe to game_launch_requested
   - Publish game_launched/game_launch_failed

#### Benefits:
- Achievement system (subscribe to game_purchased)
- Tutorial hints (subscribe to shop_opened, show tips)
- Analytics/telemetry
- Purchase history log

---

### Phase 4.6: VM/Minigame Events

**Current Problem**: VM lifecycle and game state changes are opaque

#### Events to Add:
```lua
-- VM lifecycle
'vm_created'             -- (vm_id, game_id)
'vm_started'             -- (vm_id)
'vm_paused'              -- (vm_id)
'vm_resumed'             -- (vm_id)
'vm_stopped'             -- (vm_id)
'vm_destroyed'           -- (vm_id)

-- Game progress
'game_started'           -- (game_id, vm_id)
'game_completed'         -- (game_id, score, performance)
'game_failed'            -- (game_id)
'high_score'             -- (game_id, score)
'achievement_earned'     -- (achievement_id, game_id)

-- Game state
'score_changed'          -- (vm_id, old_score, new_score)
'lives_changed'          -- (vm_id, old_lives, new_lives)
'level_changed'          -- (vm_id, old_level, new_level)
```

#### Files to Modify:
1. **VMManager** (`src/models/vm_manager.lua`)
   - Publish VM lifecycle events
   - Subscribe to game_completed to update player stats

2. **MinigameRunner** (window state for games)
   - Publish game progress events
   - Subscribe to vm_stopped to close window

3. **Statistics** (`src/models/statistics.lua`)
   - Subscribe to all game events
   - Track playtime, completion, scores

4. **PlayerData**
   - Subscribe to game_completed
   - Update completed_games, game_performance

#### Benefits:
- Real-time stats dashboard
- Live game state visualization
- Replay/recording system
- Cheat detection (unusual score_changed patterns)

---

### Phase 4.7: Cheat Engine Events

**Current Problem**: Cheat engine directly manipulates VM memory

#### Events to Add:
```lua
-- Cheat operations
'cheat_activated'        -- (cheat_id, vm_id)
'cheat_deactivated'      -- (cheat_id, vm_id)
'memory_scan_started'    -- (vm_id, scan_type)
'memory_scan_completed'  -- (vm_id, results_count)
'memory_modified'        -- (vm_id, address, old_value, new_value)

-- Cheat management
'cheat_created'          -- (cheat_data)
'cheat_deleted'          -- (cheat_id)
'cheat_saved'            -- (cheat_id)
```

#### Files to Modify:
1. **CheatEngineState** (`src/states/cheat_engine_state.lua`)
   - Publish cheat operation events
   - Don't directly call VM memory methods

2. **CheatSystem** (`src/models/cheat_system.lua`)
   - Subscribe to memory_modified
   - Track cheat usage

3. **VMManager**
   - Subscribe to cheat_activated
   - Apply memory changes
   - Publish memory_modified events

#### Benefits:
- Cheat usage statistics
- Anti-cheat detection
- Achievement disabling when cheats active
- Cheat history/logging

---

### Phase 4.8: UI/Input Events

**Current Problem**: Input handling scattered across many components

#### Events to Add:
```lua
-- Menu events
'menu_opened'            -- (menu_type)
'menu_closed'            -- (menu_type)
'menu_item_hovered'      -- (menu_type, item_id)
'menu_item_selected'     -- (menu_type, item_id)

-- Context menu
'context_menu_opened'    -- (x, y, context_type, context_data)
'context_menu_closed'    -- ()
'context_action_invoked' -- (action_id, context_data)

-- Dialogs
'dialog_opened'          -- (dialog_type, dialog_data)
'dialog_closed'          -- (dialog_type, result)
'dialog_confirmed'       -- (dialog_type, input_data)
'dialog_cancelled'       -- (dialog_type)

-- Tutorial
'tutorial_shown'         -- ()
'tutorial_dismissed'     -- ()
'tutorial_step_completed' -- (step_id)
```

#### Files to Modify:
1. **StartMenuState**
   - Publish menu events instead of directly toggling UI

2. **DesktopState**
   - Subscribe to dialog events
   - Publish context_menu events

3. **TutorialView**
   - Publish tutorial events
   - Other systems can react (e.g., disable auto-save during tutorial)

#### Benefits:
- Tutorial progress tracking
- User behavior analytics
- Accessibility (screen reader announces menu_item_hovered)
- UI testing (verify correct events published)

---

### Phase 4.9: Settings/Configuration Events

**Current Problem**: Settings changes don't propagate automatically

#### Events to Add:
```lua
-- Settings changes
'setting_changed'        -- (key, old_value, new_value)
'settings_saved'         -- ()
'settings_loaded'        -- ()
'settings_reset'         -- ()

-- Specific settings (more granular)
'resolution_changed'     -- (old_w, old_h, new_w, new_h)
'fullscreen_toggled'     -- (is_fullscreen)
'volume_changed'         -- (old_volume, new_volume)
'screensaver_enabled'    -- (enabled)
'wallpaper_changed'      -- (wallpaper_id)
```

#### Files to Modify:
1. **SettingsManager** (`src/utils/settings_manager.lua`)
   - Publish setting_changed for every setting update
   - Publish specific events for important settings

2. **DesktopState**
   - Subscribe to wallpaper_changed
   - Auto-refresh wallpaper without manual refresh

3. **All windows/states**
   - Subscribe to relevant settings
   - Auto-update when settings change

#### Benefits:
- Live settings preview (change wallpaper, see immediately)
- Settings sync across components
- Settings change history/undo
- Validate settings changes (subscriber can cancel if invalid)

---

### Phase 4.10: Save/Load Events

**Current Problem**: Save system is opaque, components don't know when save happens

#### Events to Add:
```lua
-- Save operations
'save_started'           -- ()
'save_completed'         -- (save_path)
'save_failed'            -- (error_message)
'autosave_triggered'     -- ()

-- Load operations
'load_started'           -- ()
'load_completed'         -- (save_path)
'load_failed'            -- (error_message)

-- State changes
'player_data_changed'    -- (field, old_value, new_value)
'tokens_changed'         -- (old_amount, new_amount, delta)
```

#### Files to Modify:
1. **SaveManager** (`src/utils/save_manager.lua`)
   - Publish save/load events
   - Make save process observable

2. **PlayerData**
   - Publish player_data_changed for every field change
   - Publish tokens_changed when tokens change

3. **UI Components**
   - Subscribe to tokens_changed
   - Update token displays automatically

#### Benefits:
- Save notification UI ("Saving..." indicator)
- Cloud save sync (listen for save_completed)
- Save corruption detection
- Token change animations (subscribe to tokens_changed)

---

## Event Naming Conventions

### Past Tense vs. Present Tense

**Use PAST TENSE** for events that announce something that already happened:
```lua
'window_opened'    -- Window is already open
'file_deleted'     -- File is already gone
'game_completed'   -- Game already finished
```

**Use PRESENT TENSE** for events that request an action:
```lua
'launch_program'   -- Request to launch a program
'close_window'     -- Request to close a window
```

**General Rule**: Most events should be PAST TENSE (announcing facts), not commands.

### Event Naming Pattern
```
<subject>_<verb_past_tense>
```

Examples:
- `window_closed` not `close_window`
- `icon_moved` not `move_icon`
- `game_started` not `start_game`

**Exception**: Request events can use present/imperative, but prefix with "request_":
- `request_program_launch`
- `request_window_close`

---

## Implementation Strategy

### Phase-by-Phase Approach

1. **Start Small**: One subsystem at a time (we already did program launching)
2. **Maintain Fallbacks**: Keep old direct calls as fallback during transition
3. **Test Thoroughly**: Each phase should be fully tested before moving on
4. **Document Events**: Keep event catalog updated

### Gradual Migration Pattern

```lua
-- Step 1: Add event alongside old code
function Component:doSomething()
    -- Old way (keep for now)
    self.dependency:directMethod()

    -- New way
    if self.event_bus then
        self.event_bus:publish('something_happened')
    end
end

-- Step 2: Make dependency subscribe to event
function Dependency:init(di)
    if di.eventBus then
        di.eventBus:subscribe('something_happened', function()
            self:directMethod()
        end)
    end
end

-- Step 3: Remove old direct call after testing
function Component:doSomething()
    -- New way only
    self.event_bus:publish('something_happened')
end
```

---

## Testing Strategy

### Event-Driven Testing

**Before (Hard to Test)**:
```lua
-- Must mock entire DesktopState
function test_start_menu_launches_program()
    local fake_desktop = {
        launchProgram = function(id)
            assert(id == 'test_program')
        end
    }
    local menu = StartMenuState:new(di, fake_desktop)
    menu:onProgramClick('test_program')
end
```

**After (Easy to Test)**:
```lua
-- Just verify event was published
function test_start_menu_publishes_launch_event()
    local events_published = {}
    local fake_bus = {
        publish = function(name, ...)
            table.insert(events_published, {name=name, args={...}})
        end
    }

    local di = {eventBus = fake_bus}
    local menu = StartMenuState:new(di, {})
    menu:onProgramClick('test_program')

    assert(#events_published == 1)
    assert(events_published[1].name == 'launch_program')
    assert(events_published[1].args[1] == 'test_program')
end
```

### Integration Testing
```lua
-- Test that events flow correctly
function test_program_launch_integration()
    local event_bus = EventBus:new()
    local launched = false

    -- Set up subscriber
    event_bus:subscribe('launch_program', function(program_id)
        launched = true
    end)

    -- Set up publisher
    local di = {eventBus = event_bus}
    local menu = StartMenuState:new(di, {})

    -- Trigger
    menu:onProgramClick('test_program')

    -- Verify
    assert(launched)
end
```

---

## Event Catalog

### Current Events (Implemented)
| Event Name | Parameters | Publisher | Subscribers |
|------------|-----------|-----------|-------------|
| `launch_program` | `program_id, ...params` | StartMenuState | DesktopState |

### Proposed Events (By Phase)

**Phase 4.2: Window Management** (8 events)
**Phase 4.3: Desktop Icons** (8 events)
**Phase 4.4: File System** (10 events)
**Phase 4.5: Launcher** (8 events)
**Phase 4.6: VM/Minigame** (12 events)
**Phase 4.7: Cheat Engine** (7 events)
**Phase 4.8: UI/Input** (11 events)
**Phase 4.9: Settings** (8 events)
**Phase 4.10: Save/Load** (8 events)

**Total Proposed**: ~80 events across all phases

---

## Benefits Summary

### Code Quality
- ✅ **Decoupling**: Components don't know about each other
- ✅ **Single Responsibility**: Each component does one thing
- ✅ **Open/Closed**: Add features without modifying existing code
- ✅ **Testability**: Mock EventBus instead of entire systems

### Features
- ✅ **Undo/Redo**: Subscribe to all state-changing events
- ✅ **Analytics**: One subscriber tracks everything
- ✅ **Logging**: Debug by logging all events
- ✅ **Replay**: Record events, replay later
- ✅ **Networking**: Sync events across network (future multiplayer?)

### Maintenance
- ✅ **Easier Debugging**: See all events in one place
- ✅ **Clear Data Flow**: Events show what happened when
- ✅ **Less Coupling**: Changing one component doesn't break others
- ✅ **Documentation**: Event catalog documents system behavior

---

## Risks and Mitigations

### Risk 1: Performance
**Concern**: Publishing many events might slow down the game

**Mitigation**:
- Events are very fast (just function calls)
- Only publish significant events, not every frame update
- Batch events if needed (`publish_batch(['event1', 'event2'])`)

### Risk 2: Debugging Complexity
**Concern**: Hard to trace event flow

**Mitigation**:
- Add EventBus debug mode that logs all events
- Use descriptive event names
- Maintain event catalog documentation
- Dev tools to visualize event flow

### Risk 3: Event Order Dependencies
**Concern**: Subscribers might depend on event order

**Mitigation**:
- Document that event order is not guaranteed
- Use explicit sequencing if needed (`event_bus:publish_ordered()`)
- Avoid inter-subscriber dependencies

### Risk 4: Migration Effort
**Concern**: Too much work to refactor everything

**Mitigation**:
- Gradual migration (keep old code as fallback)
- One phase at a time
- Prioritize high-value refactorings first
- Skip low-value areas

---

## Priority Recommendations

### High Priority (Do First)
1. ✅ **Phase 4.1: Program Launching** - DONE
2. **Phase 4.2: Window Management** - High coupling, used everywhere
3. **Phase 4.4: File System** - Central to many features
4. **Phase 4.10: Save/Load** - Enables many quality-of-life features

### Medium Priority (Do Second)
5. **Phase 4.3: Desktop Icons** - Nice UI improvements
6. **Phase 4.6: VM/Minigame** - Enables cool features like replay
7. **Phase 4.9: Settings** - Quality of life

### Lower Priority (Do If Time)
8. **Phase 4.5: Launcher** - Already fairly isolated
9. **Phase 4.7: Cheat Engine** - Niche feature
10. **Phase 4.8: UI/Input** - More polish than structure

---

## Conclusion

Event-driven architecture is a powerful pattern that will make this codebase more maintainable, testable, and extensible. By gradually migrating to events, we can:

1. **Separate concerns**: Data models don't know about UI, UI doesn't know about business logic
2. **Enable features**: Undo/redo, analytics, replays become trivial
3. **Improve testing**: Mock EventBus instead of entire dependency trees
4. **Reduce coupling**: Add features without modifying existing code

The migration can be done gradually, one phase at a time, with fallbacks to ensure nothing breaks.

**Next Steps**:
1. Fix the program launching bug (variadic args)
2. Start Phase 4.2 (Window Management)
3. Update this document as patterns emerge
4. Maintain event catalog

---

**Document Version**: 1.0
**Date**: 2025-10-21
**Status**: Phase 4.1 Complete, Planning 4.2+
