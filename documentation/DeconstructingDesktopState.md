# Refactoring Plan: Deconstructing `DesktopState`

**Objective:** Refactor the 2000-line `desktop_state.lua` "God Class" into smaller, single-responsibility components. The goal is for `DesktopState` to become a simple container/orchestrator, delegating all complex logic to specialized services and controllers.

**Guiding Principle:** "The desktop is where icons live." `DesktopState` will manage the wallpaper and icons (via `DesktopIconController`), and coordinate other top-level OS Shell components (Taskbar, Windows, Context Menus).

**Prerequisite:** Ensure the Event Bus refactoring (Phases 4.1-4.10) is complete and tested.

---

## Phase 1: Extract `ProgramLauncher` (High Value)

**Goal:** Move the massive `launchProgram` function (and its dependency management) into a dedicated, self-contained utility.

1.  **Create New File:** `src/utils/program_launcher.lua`.
    * Define a `ProgramLauncher` class inheriting from `Object`.
    * Its `init(di)` function should store `self.di = di`.
    * **Move `dependency_provider`:** Cut the *entire* `self.dependency_provider` map definition from `desktop_state.lua:init` and paste it into `program_launcher.lua:init` as `self.dependency_provider`. Update references within the map from `self.*` to `self.di.*` (e.g., `player_data = self.di.playerData`).
    * **Move `launchProgram` & `_ensureDependencyProvider`:** Cut these two functions *entirely* from `desktop_state.lua` and paste them into `program_launcher.lua`.
    * **Update `launchProgram` References:**
        * Change `self.program_registry:getProgram(...)` to `self.di.programRegistry:getProgram(...)`.
        * Change `self.window_manager:isProgramOpen(...)` to `self.di.windowManager:isProgramOpen(...)`.
        * Change `self.window_manager:focusWindow(...)` to `self.di.windowManager:focusWindow(...)`.
        * Change dependency lookups in the loop from `self.dependency_provider[dep_name]` to `self.dependency_provider[dep_name]`.
        * Change `self.window_manager:createWindow(...)` to `self.di.windowManager:createWindow(...)`.
        * **Crucially:** Replace `self.window_states[window_id] = { state = new_state }` with a call back to `DesktopState` (which we'll add to DI): `self.di.desktopState:registerWindowState(window_id, new_state)`.
        * Replace references to `self.window_chrome` for getting content bounds with `self.di.desktopState.window_chrome`. *(Self-correction: Better to pass window_chrome instance via DI if needed, but `window_manager` might handle this better. Let's assume `window_manager` provides necessary bounds info or the service requires `window_chrome` via DI)*. Add `window_chrome` to `di` in `main.lua` and access it via `self.di.windowChrome`.
        * Change `self.window_manager:maximizeWindow(...)` to `self.di.windowManager:maximizeWindow(...)`.
        * Change `self.window_manager:getWindowById(...)` to `self.di.windowManager:getWindowById(...)`.
    * **Add Subscription:** In `program_launcher.lua:init`, add:
        ```lua
        self.di.eventBus:subscribe('launch_program', function(program_id, ...)
            self:launchProgram(program_id, ...)
        end)
        ```

2.  **Modify `main.lua`:**
    * In `love.load`, *after* `desktop` is created:
        ```lua
        -- (After desktop = DesktopState:new(di))
        di.desktopState = desktop -- Add desktop instance to DI
        -- Add window_chrome to DI
        di.windowChrome = desktop.window_chrome -- Or instantiate separately if preferred
        -- Create the launcher service
        local ProgramLauncher = require('src.utils.program_launcher')
        di.programLauncher = ProgramLauncher:new(di)
        ```

3.  **Modify `desktop_state.lua`:**
    * **Delete** the `launchProgram` and `_ensureDependencyProvider` functions.
    * **Delete** the `self.dependency_provider` map from `init`.
    * **Delete** the `launch_program` subscription from `init`.
    * **Add New Function:**
        ```lua
        function DesktopState:registerWindowState(window_id, state)
            self.window_states[window_id] = { state = state }
            -- Important: Re-apply context if needed by state
            if state.setWindowContext then state:setWindowContext(window_id, self.window_manager) end
            if state.setViewport then
                 local window = self.window_manager:getWindowById(window_id)
                 if window then
                     local bounds = self.window_chrome:getContentBounds(window)
                     pcall(state.setViewport, state, bounds.x, bounds.y, bounds.width, bounds.height)
                 end
            end
        end
        ```
    * Find **all** calls to `self:launchProgram(...)` (e.g., in `mousepressed`, `handleStateEvent`, `handleContextMenuAction`) and **replace them** with:
        ```lua
        self.di.eventBus:publish('launch_program', program_id, ...) -- Pass original arguments after program_id
        ```

---

## Phase 2: Extract `ContextMenuService`

**Goal:** Move all context menu logic (generation, display, and handling) into a dedicated service.

1.  **Create `src/utils/context_menu_service.lua`:**
    * Create a `ContextMenuService` class inheriting from `Object`.
    * `init(di)`: Stores `self.di = di`, `self.program_registry = di.programRegistry`, `self.desktop_icons = di.desktopIcons`, `self.file_system = di.fileSystem`, etc. (all dependencies needed for `generateContextMenuOptions` and `handleContextMenuAction`). Instantiate its own `self.view = ContextMenuView:new()`.
    * Add state properties: `self.is_open = false`, `self.options = {}`, `self.context = nil`, `self.x = 0`, `self.y = 0`, `self._suppress_next_mousereleased = false`.
    * **Move Methods:** Cut `generateContextMenuOptions`, `openContextMenu` (rename to `show`), `closeContextMenu`, and `handleContextMenuAction` from `desktop_state.lua` and paste them into `context_menu_service.lua`. Adapt them to use `self.di.*` for dependencies and `self.*` for state (`self.is_open`, `self.options`, etc.).
    * **Modify `handleContextMenuAction`:** Replace calls like `self:launchProgram(...)` or `self:deleteDesktopIcon(...)` with `self.di.eventBus:publish(...)` (e.g., `self.di.eventBus:publish('launch_program', program_id)` or `self.di.eventBus:publish('request_icon_recycle', program_id)`). It no longer *performs* actions, only *requests* them via events after publishing `context_action_invoked`.
    * **Add Core Methods:**
        ```lua
        function ContextMenuService:isOpen() return self.is_open end

        function ContextMenuService:update(dt)
            if not self.is_open then return end
            self.view:update(dt, self.options, self.x, self.y)
        end

        function ContextMenuService:draw()
            if not self.is_open then return end
            self.view:draw()
        end

        function ContextMenuService:mousepressed(x, y, button)
            if not self.is_open then return false end
            if button == 1 then
                local clicked_option_index = self.view:getClickedOptionIndex(x, y)
                if clicked_option_index then -- Clicked inside bounds
                    if clicked_option_index > 0 then -- Clicked on an enabled item
                        local selected_option = self.options[clicked_option_index]
                        self:handleContextMenuAction(selected_option.id, self.context)
                    end
                    self:closeContextMenu()
                    self._suppress_next_mousereleased = true -- Prevent click-through
                    return true -- Consumed click
                else -- Clicked outside
                    self:closeContextMenu()
                    return false -- Did not consume click
                end
            elseif button == 2 then -- Right-click outside closes, doesn't consume
                self:closeContextMenu()
                return false
            end
            return false -- Should not be reached
        end

        function ContextMenuService:shouldSuppressMouseRelease()
             -- Helper for DesktopState
             if self._suppress_next_mousereleased then
                  self._suppress_next_mousereleased = false
                  return true
             end
             return false
        end
        ```

2.  **Modify `main.lua`:**
    * In `love.load`, create `di.contextMenuService = ContextMenuService:new(di)`.

3.  **Modify `desktop_state.lua`:**
    * **Delete** the methods: `openContextMenu`, `closeContextMenu`, `generateContextMenuOptions`, `handleContextMenuAction`.
    * **Delete** the state properties from `init`: `self.context_menu_open`, `self.menu_x`, `self.menu_y`, `self.menu_options`, `self.menu_context`, and `self.context_menu_view`.
    * **Delete** `self._suppress_next_mousereleased` property.
    * In `update(dt)`, add `self.di.contextMenuService:update(dt)`.
    * In `draw()`, add `self.di.contextMenuService:draw()`.
    * In `mousepressed(x, y, button)`:
        * **Replace** the entire "Priority 1" block with:
            ```lua
            -- --- Context Menu Handling (Priority 1) ---
            if self.di.contextMenuService:isOpen() then
                local handled_by_menu = self.di.contextMenuService:mousepressed(x, y, button)
                if handled_by_menu then return end -- Menu consumed click
                -- If right-clicked outside, menu closed but didn't consume, fall through
            end
            ```
        * In the `button == 2` (right-click) logic block, **replace** the call to `self:openContextMenu(...)` with:
            ```lua
            local options = self:generateContextMenuOptions(context_type, context_data) -- Keep generation local for now, easier
            if #options > 0 then
                self.di.contextMenuService:show(x, y, options, { type = context_type, program_id = context_data.program_id, window_id = context_data.window_id })
                -- Still need generateContextMenuOptions locally unless we move ALL context logic
            end
            ```
            *(Self-correction: Let's move `generateContextMenuOptions` in this phase too for completeness)*.
            **Replace** the above right-click block with:
            ```lua
             if context_type ~= "start_button" then
                  -- Service now generates options internally based on context
                  self.di.contextMenuService:show(x, y, context_type, { program_id = context_data.program_id, window_id = context_data.window_id })
             end
            ```
            **(Also requires moving `generateContextMenuOptions` logic to the service and adapting it).**
    * In `mousereleased(x, y, button)`:
        * Add near the top:
            ```lua
            if self.di.contextMenuService:shouldSuppressMouseRelease() then
                return -- Swallow this release
            end
            ```

---

## Phase 3: Extract `TaskbarController`

**Goal:** Move all taskbar logic, state, and drawing into its own controller/view pair.

1.  **Create `src/views/taskbar_view.lua`:**
    * Define a `TaskbarView` class.
    * `init(di)`: Stores `di`, retrieves necessary config values (colors, layout) from `di.config`.
    * Move the drawing functions *and their helper logic* from `desktop_view.lua`: `drawTaskbar`, `drawStartButton`, `drawSystemTray`, `getTaskbarButtonAtPosition`, `isStartButtonHovered`. Adapt them to be standalone methods of `TaskbarView`. They will need `window_manager`, `player_data`, `start_menu_open`, etc., passed via `draw()`.
2.  **Create `src/controllers/taskbar_controller.lua`:**
    * Define a `TaskbarController` class.
    * `init(di)`: Stores `di`, creates `self.view = TaskbarView:new(di)`. Gets needed dependencies like `di.windowManager`, `di.startMenuState` (needs adding to DI in `main.lua`), `di.eventBus`.
    * `update(dt)`: Gets current time, determines hovered button using `self.view:getTaskbarButtonAtPosition` etc. Stores hover state locally. Calls `self.view:update(dt, ...)`.
    * `draw()`: Gathers data (`di.playerData.tokens`, `di.windowManager:getWindowsInCreationOrder()`, `di.startMenuState:isOpen()`, hover state) and calls `self.view:draw(...)`.
    * `mousepressed(x, y, button)`: Implements the click logic previously in `DesktopState:mousepressed` for the Start Button and taskbar window buttons. This controller will now publish events like `self.di.eventBus:publish('request_window_focus', ...)` or call `self.di.startMenuState:onStartButtonPressed()`. Returns `true` if handled.
3.  **Modify `main.lua`:**
    * After creating `start_menu` state, add it to DI: `di.startMenuState = start_menu`.
4.  **Modify `desktop_state.lua`:**
    * **Delete** taskbar-related click logic (Start Button, window buttons) from `mousepressed`.
    * In `init`, create `self.taskbar_controller = TaskbarController:new(self.di)`.
    * In `update(dt)`, call `self.taskbar_controller:update(dt)` and *remove* the clock update logic.
    * In `draw()`, call `self.taskbar_controller:draw()`.
    * In `mousepressed(x, y, button)`, add a priority check:
        ```lua
        -- (After Window checks)
        if self.taskbar_controller:mousepressed(x, y, button) then
            return -- Click handled by taskbar
        end
        ```
5.  **Modify `desktop_view.lua`:**
    * **Delete** the methods moved to `taskbar_view.lua`.
    * Remove taskbar properties (`self.taskbar_height`, etc.) from `init`.
    * `draw()` method no longer calls `self:drawTaskbar()`.
    * `update()` no longer updates clock or taskbar hover states.

---

## Phase 4: Consolidate `DesktopIconController`

**Goal:** Move all icon interaction logic (clicking, dragging, dropping, overlap) from `DesktopState` into `DesktopIconController`.

1.  **Modify `desktop_icon_controller.lua`:**
    * In `init`, add state properties moved from `DesktopState`:
        ```lua
        self.dragging_icon_id = nil
        self.drag_offset_x = 0
        self.drag_offset_y = 0
        self.last_icon_click_time = 0
        self.last_icon_click_id = nil
        self.icon_snap = self.di.settingsManager.get('desktop_icon_snap') ~= false -- Get snap setting
        ```
    * Add placeholder methods: `update(dt)`, `draw()`, `mousepressed(x, y, button)`, `mousemoved(x, y, dx, dy)`, `mousereleased(x, y, button)`.
    * **Move Click/Drag Start Logic:** Cut the icon click/double-click/drag-start logic from `DesktopState:mousepressed` (around line 475-502) and paste it into `DesktopIconController:mousepressed`. Adapt references (`self.di.*` for EventBus, `self.last_icon_click_id`, etc.). This method should publish `icon_double_clicked` or `icon_drag_started` events. It should return `true` if it handles an icon click.
    * **Move Drag Move Logic:** Add logic to `DesktopIconController:mousemoved` to simply update internal state if `self.dragging_icon_id` is set (no publishing needed here).
    * **Move Drop Logic:** Cut the complex icon drop logic (Recycle Bin check, overlap resolution, grid snap) from `DesktopState:mousereleased` (around line 636-778) and paste it into `DesktopIconController:mousereleased`. Adapt references. This method should publish `request_icon_recycle` or `request_icon_move` events and `icon_drag_ended`.
    * **Implement `draw()`:**
        ```lua
        function DesktopIconController:draw()
            local desktop_programs = self.di.programRegistry:getDesktopPrograms()
            local desktop_view = self.di.desktopView -- Assumes desktopView added to DI in main.lua

            -- Draw static icons
            for _, program in ipairs(desktop_programs) do
                if not self.desktop_icons:isDeleted(program.id) then
                    if program.id ~= self.dragging_icon_id then -- Don't draw static if dragging
                        local pos = self.desktop_icons:getPosition(program.id) or self:getDefaultIconPosition(program.id)
                        local is_hovered = (program.id == self.hovered_program_id) -- Need hover state passed or managed here
                        -- Pass desktop_view explicitly for drawing
                        desktop_view:drawIcon(program, is_hovered, pos, false)
                    end
                end
            end

            -- Draw dragged icon
            if self.dragging_icon_id then
                local program = self.di.programRegistry:getProgram(self.dragging_icon_id)
                if program then
                    local mx, my = love.mouse.getPosition()
                    local drag_x = mx - self.drag_offset_x
                    local drag_y = my - self.drag_offset_y
                    local temp_pos = { x = drag_x, y = drag_y }
                    -- Pass desktop_view explicitly for drawing
                    desktop_view:drawIcon(program, true, temp_pos, true) -- Pass dragging flag
                end
            end
        end
        ```
    * **Add Hover Update:** `update(dt)` should get mouse position and call `self:getProgramAtPosition(mx, my)` to update a new `self.hovered_program_id` state for drawing.

2.  **Modify `main.lua`:**
    * After creating `desktop_view`, add it to DI: `di.desktopView = desktop.view`.

3.  **Modify `desktop_state.lua`:**
    * **Delete** icon state properties from `init` (`dragging_icon_id`, `drag_offset_x/y`, `last_icon_click_time/id`, `icon_snap`).
    * **Delete** icon click/double-click/drag-start logic from `mousepressed`.
    * **Delete** icon drop logic from `mousereleased`.
    * In `update(dt)`, call `self.icon_controller:update(dt)`.
    * In `draw()`, **delete** the icon drawing loops (static and dragged). **Replace** with `self.icon_controller:draw()`.
    * In input methods (`mousepressed`, `mousemoved`, `mousereleased`), delegate to the controller:
        ```lua
        -- Example for mousepressed (after Taskbar check)
        if self.icon_controller:mousepressed(x, y, button) then
            return -- Click handled by icon controller
        end
        ```

---

## Phase 5: Final `DesktopState` Cleanup

**Goal:** Review `desktop_state.lua` and remove any remaining logic, state, or helper functions that were moved, ensuring it's just a simple orchestrator.

1.  **Review `desktop_state.lua:init`**: Ensure it only creates controllers/services and stores essential `di` references. Remove unused dependencies.
2.  **Review `desktop_state.lua:update/draw`**: Ensure they are short, primarily calling `update/draw` on child components (Windows, Taskbar, Icons, Context Menu, Start Menu, Tutorial) and handling the screensaver timer.
3.  **Review `desktop_state.lua:mousepressed/moved/released`**: Ensure they follow the priority order and simply delegate to the appropriate controller/service, returning if handled.
4.  **Delete Unused Helpers**: Remove functions like `getProgramAtPosition`, `findNextAvailableGridPosition`, `deleteDesktopIcon`, `showTextFileDialog`, `executeRunCommand` as their logic should now reside within the extracted components or be handled via events. Check `handleStateEvent` for functions that can be removed because the event is now handled elsewhere (e.g., `run_execute` might be handled directly by `ProgramLauncherService` if it subscribes).
5.  **Final Code Read-Through**: Ensure clarity, remove dead code, check for any remaining responsibilities that don't belong in `DesktopState`.

---

This phased plan allows for incremental refactoring and testing, reducing risk compared to attempting the entire refactor at once. Good luck!