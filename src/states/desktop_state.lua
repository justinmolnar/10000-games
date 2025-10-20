-- src/states/desktop_state.lua
local Object = require('class')
local DesktopView = require('views.desktop_view')
local DesktopIconController = require('src.controllers.desktop_icon_controller')
local Constants = require('src.constants')
local Strings = require('src.utils.strings')
local TutorialView = require('src.views.tutorial_view')
local WindowChrome = require('src.views.window_chrome')
local WindowController = require('src.controllers.window_controller')
local Collision = require('src/utils.collision')
local DesktopState = Object:extend('DesktopState')
local ContextMenuView = require('src.views.context_menu_view')

-- DEBUG: Check if WindowController loaded
if not WindowController then
    error("CRITICAL: WindowController failed to load!")
end
print("[DesktopState] WindowController class loaded:", WindowController)

function DesktopState:init(di)

    print("[DesktopState:init] Starting initialization...") -- Debug Start

    -- Dependency Injection container (required in new API)
    self.di = di or {}

    -- Core references from DI
    self.state_machine = self.di.stateMachine
    self.player_data = self.di.playerData
    self.statistics = self.di.statistics
    self.window_manager = self.di.windowManager
    self.desktop_icons = self.di.desktopIcons -- Injected
    self.file_system = self.di.fileSystem
    self.recycle_bin = self.di.recycleBin -- Injected
    self.program_registry = self.di.programRegistry
    self.vm_manager = self.di.vmManager
    self.cheat_system = self.di.cheatSystem
    self.save_manager = self.di.saveManager
    self.game_data = self.di.gameData

    -- Initialize basic properties first
    self.window_chrome = WindowChrome:new()
    self.window_states = {} -- Initialize the map *before* passing it

    -- *** Crucial: Instantiate WindowController AFTER its dependencies are ready ***
    if WindowController then -- Check if require succeeded
        -- Ensure dependencies are valid before passing
       if not self.window_manager then print("CRITICAL ERROR: window_manager is nil during DesktopState:init!") end
       if not self.program_registry then print("CRITICAL ERROR: program_registry is nil during DesktopState:init!") end
        if not self.window_states then print("CRITICAL ERROR: self.window_states is nil during DesktopState:init!") end

        -- Only instantiate if dependencies seem okay
       if self.window_manager and self.program_registry and self.window_states then
           self.window_controller = WindowController:new(self.window_manager, self.program_registry, self.window_states)
             print("[DesktopState:init] WindowController instantiated successfully.") -- Debug Success
             if not self.window_controller then print("CRITICAL ERROR: WindowController:new() returned nil!") end -- Check instantiation result
        else
             print("CRITICAL ERROR: Cannot instantiate WindowController due to missing dependencies.")
             self.window_controller = nil
        end
    else
        print("CRITICAL ERROR: Cannot instantiate WindowController because require failed.")
        self.window_controller = nil -- Explicitly set to nil if require failed
    end

    -- Initialize Views and other properties AFTER window_controller
    self.view = DesktopView:new(self.program_registry, self.player_data, self.window_manager, self.desktop_icons, self.recycle_bin, self.di)
    self.icon_controller = DesktopIconController:new(self.program_registry, self.desktop_icons, self.recycle_bin, self.di)
    self.tutorial_view = TutorialView:new(self)
    self.context_menu_view = ContextMenuView:new()

    local C = (self.di and self.di.config) or {}
    local colors = (C.ui and C.ui.colors) or {}
    local SettingsManager = (self.di and self.di.settingsManager) or require('src.utils.settings_manager')
    -- Desktop wallpaper color from settings (fallback to config)
    local r = SettingsManager.get('desktop_bg_r'); if r == nil then r = (colors.desktop and colors.desktop.wallpaper and colors.desktop.wallpaper[1]) or 0 end
    local g = SettingsManager.get('desktop_bg_g'); if g == nil then g = (colors.desktop and colors.desktop.wallpaper and colors.desktop.wallpaper[2]) or 0.5 end
    local b = SettingsManager.get('desktop_bg_b'); if b == nil then b = (colors.desktop and colors.desktop.wallpaper and colors.desktop.wallpaper[3]) or 0.5 end
    self.wallpaper_color = { r, g, b }
    -- Icon snap setting cached
    self.icon_snap = SettingsManager.get('desktop_icon_snap') ~= false
    -- Prefer explicit flag from DI; otherwise compute from settings (not shown means tutorial)
    if self.di and self.di.showTutorialOnStartup ~= nil then
        self.show_tutorial = self.di.showTutorialOnStartup
    else
        self.show_tutorial = not SettingsManager.get("tutorial_shown") or false
    end

    self.start_menu_open = false
    self.run_dialog_open = false
    self.run_text = ""

    -- Icon interaction state
    self.dragging_icon_id = nil
    self.drag_offset_x = 0
    self.drag_offset_y = 0
    self.last_icon_click_time = 0
    self.last_icon_click_id = nil

    -- Title bar double-click state
    self.last_title_bar_click_time = 0
    self.last_title_bar_click_id = nil

    -- Context Menu State
    self.context_menu_open = false
    self.menu_x = 0
    self.menu_y = 0
    self.menu_options = {} -- Will hold { id="action", label="Text", enabled=true/false }
    self.menu_context = nil -- Store data related to what was clicked (e.g., program_id, window_id)

    -- Dependency provider map (used by launchProgram)
    self.dependency_provider = {
        player_data = self.player_data, game_data = self.game_data, state_machine = self.state_machine,
        save_manager = self.save_manager, statistics = self.statistics, window_manager = self.window_manager,
        desktop_icons = self.desktop_icons, file_system = self.file_system, recycle_bin = self.recycle_bin,
        program_registry = self.program_registry, vm_manager = self.vm_manager, cheat_system = self.cheat_system,
        di = self.di,
        window_controller = self.window_controller -- Pass controller itself if needed by states (e.g. Settings)
    }

    -- Store cursors (created in main.lua)
    self.cursors = (self.di and self.di.systemCursors) or {} -- Populated via DI when available; main.lua may also set

    -- Screensaver idle timer
    self.idle_timer = 0
    local SettingsManager = (self.di and self.di.settingsManager) or require('src.utils.settings_manager')
    local C = (self.di and self.di.config) or {}
    local desktopCfg = (C.ui and C.ui.desktop) or {}
    self.screensaver_timeout = SettingsManager.get('screensaver_timeout') or (desktopCfg.screensaver and desktopCfg.screensaver.default_timeout) or 10
    self.screensaver_enabled = SettingsManager.get('screensaver_enabled') ~= false

    print("[DesktopState:init] Initialization finished.") -- Debug End
end

function DesktopState:enter()
    self:updateClock()
    print("Desktop loaded. Tutorial active: " .. tostring(self.show_tutorial))
    self.view:calculateDefaultIconPositionsIfNeeded() -- View uses model data now
end

function DesktopState:update(dt)
    -- Update global systems if they exist
    if self.statistics then self.statistics:addPlaytime(dt) end

    -- VM Manager needs to run even if DesktopState isn't the active *state machine* state
    if self.vm_manager and self.player_data and self.game_data then
        self.vm_manager:update(dt, self.player_data, self.game_data)
    end

    -- *** REMOVED: WindowController doesn't have an update method ***
    -- It only handles input events (mousepressed, mousemoved, mousereleased)

    -- Update active window states
    local windows = self.window_manager:getAllWindows()
    for _, window in ipairs(windows) do
        if not window.is_minimized then
            local window_data = self.window_states[window.id]
            if window_data and window_data.state then
                 if type(window_data.state.update) == "function" then
                    local success, err = pcall(window_data.state.update, window_data.state, dt)
                    if not success then
                        print("Error *during* pcall update on state for window " .. window.id .. ": " .. tostring(err))
                    end
                 end
            end
        end
    end

    -- Update context menu view if open
    if self.context_menu_open then
        self.context_menu_view:update(dt, self.menu_options, self.menu_x, self.menu_y)
    end

    -- Update main desktop view or tutorial
    if self.show_tutorial then
        self.tutorial_view:update(dt)
    else
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    if self.icon_controller then self.icon_controller:ensureDefaultPositions(sw, sh) end
    self.view:update(dt, self.start_menu_open, self.dragging_icon_id)
    end

    -- Update system cursor based on context
    local mx, my = love.mouse.getPosition()
    local cursor_type = self.window_controller:getCursorType(mx, my, self.window_chrome)
    local cursor_obj = self.cursors[cursor_type] or self.cursors["arrow"]
    if cursor_obj then love.mouse.setCursor(cursor_obj) end

    -- Refresh settings live (in-memory from SettingsManager)
    local SettingsManager = (self.di and self.di.settingsManager) or require('src.utils.settings_manager')
    self.screensaver_enabled = SettingsManager.get('screensaver_enabled') ~= false
    self.screensaver_timeout = SettingsManager.get('screensaver_timeout') or 10
    -- Live-update desktop color and snap
    local nr = SettingsManager.get('desktop_bg_r') or 0
    local ng = SettingsManager.get('desktop_bg_g') or 0.5
    local nb = SettingsManager.get('desktop_bg_b') or 0.5
    self.wallpaper_color[1], self.wallpaper_color[2], self.wallpaper_color[3] = nr, ng, nb
    self.icon_snap = SettingsManager.get('desktop_icon_snap') ~= false

    -- Screensaver idle tracking
    if self.screensaver_enabled then
        self.idle_timer = self.idle_timer + dt
        local C = (self.di and self.di.config) or {}
        local default_timeout = (C.ui and C.ui.desktop and C.ui.desktop.screensaver and C.ui.desktop.screensaver.default_timeout) or 10
        if self.idle_timer >= (self.screensaver_timeout or default_timeout) then
            if self.state_machine and self.state_machine.states[Constants.state.SCREENSAVER] then
                self.state_machine:switch(Constants.state.SCREENSAVER)
                self.idle_timer = 0
                return
            end
        end
    else
        self.idle_timer = 0
    end
end

function DesktopState:updateClock()
    self.current_time = os.date("%H:%M")
end

function DesktopState:draw()
    -- Pass dragging state for visual feedback
    self.view:draw(
        self.wallpaper_color,
        self.player_data.tokens,
        self.start_menu_open,
        self.run_dialog_open,
        self.run_text,
        self.dragging_icon_id
    )

    -- Draw windows respecting z-order from window manager
    local windows = self.window_manager:getAllWindows()
    for i = 1, #windows do
        local window = windows[i]
        if not window.is_minimized then
            self:drawWindow(window)
        end
    end

     -- Draw the icon being dragged on top of windows
    if self.dragging_icon_id then
        local program = self.program_registry:getProgram(self.dragging_icon_id)
        if program then
            local mx, my = love.mouse.getPosition()
            local drag_x = mx - self.drag_offset_x
            local drag_y = my - self.drag_offset_y
            local temp_pos = { x = drag_x, y = drag_y }
            self.view:drawIcon(program, true, temp_pos, true) -- Pass dragging flag
        end
    end

    -- Draw context menu on top if open
    if self.context_menu_open then
        self.context_menu_view:draw()
    end

    -- Draw tutorial overlay last if active
    if self.show_tutorial then
        self.tutorial_view:draw()
    end
end


function DesktopState:drawWindow(window)
    local is_focused = self.window_manager:getFocusedWindowId() == window.id

    -- Draw window chrome (border, title bar, buttons)
    self.window_chrome:draw(window, is_focused)

    -- Draw window content state
    local window_data = self.window_states[window.id]
    local window_state = window_data and window_data.state

    if window_state and window_state.draw then
        local content_bounds = self.window_chrome:getContentBounds(window)

        love.graphics.push() -- Save current graphics state
        -- Set scissor BEFORE translating
        love.graphics.setScissor(content_bounds.x, content_bounds.y, content_bounds.width, content_bounds.height)
        -- Translate origin to content area's top-left AFTER setting scissor
        love.graphics.translate(content_bounds.x, content_bounds.y)

        -- The state's draw function draws relative to (0,0) within the clipped area
        local draw_ok, err = pcall(window_state.draw, window_state)

        love.graphics.pop() -- Restore previous graphics state (removes translation and scissor setting from the push)

        -- *** ADD EXPLICIT SCISSOR RESET ***
        -- Reset scissor to full screen just in case pop didn't fully restore it
        love.graphics.setScissor()
        -- *** END ADDED LINE ***

        if not draw_ok then
            print("Error during window state draw for ID " .. window.id .. ": " .. tostring(err))
            -- Draw error message (this part seems okay, uses push/pop locally)
            local C = (self.di and self.di.config) or {}
            local E = (C.ui and C.ui.window and C.ui.window.error) or {}
            love.graphics.push()
            love.graphics.setScissor(content_bounds.x, content_bounds.y, content_bounds.width, content_bounds.height)
            love.graphics.setColor((E.text_color or {1,0,0}))
            local pad = E.text_pad or {x=5,y=5}
            local wpad = E.width_pad or 10
            love.graphics.printf("Error drawing window content:\n" .. tostring(err), content_bounds.x + pad.x, content_bounds.y + pad.y, content_bounds.width - wpad)
            love.graphics.setScissor()
            love.graphics.pop()
        end
    end
end

function DesktopState:mousepressed(x, y, button)
    self.idle_timer = 0
    -- If tutorial is showing, it consumes all input
    if self.show_tutorial then
        local event = self.tutorial_view:mousepressed(x, y, button)
        if event and event.name == "dismiss_tutorial" then self:dismissTutorial() end
        return -- Tutorial handled it
    end

    local click_handled = false -- General flag if click was processed

    -- --- Context Menu Handling (Priority 1: Left-click on open menu OR Right-click anywhere) ---
    if self.context_menu_open then
        if button == 1 then -- Left click
            local clicked_option_index = self.context_menu_view:getClickedOptionIndex(x, y)
            if clicked_option_index then -- Clicked inside the menu bounds
                if clicked_option_index > 0 then -- Clicked on an item
                    local selected_option = self.menu_options[clicked_option_index]
                    if selected_option and selected_option.enabled ~= false and not selected_option.is_separator then
                         self:handleContextMenuAction(selected_option.id, self.menu_context)
                    end
                end
                -- Click was inside menu (item or padding), close it and consume click
                self:closeContextMenu()
                return
            else
                -- Click was outside the menu, close it and let click fall through
                self:closeContextMenu()
            end
        elseif button == 2 then -- Right click anywhere closes the current menu
            self:closeContextMenu()
            -- Let the right-click fall through to potentially open a new menu below
        end
    end

    -- --- Window Interaction Handling (Priority 2) ---
    -- Check topmost window first for efficiency
    local handled_by_window = false
    local top_window_id = self.window_manager:getFocusedWindowId() -- Get focused first
    local top_window = top_window_id and self.window_manager:getWindowById(top_window_id)

    if top_window and not top_window.is_minimized and x >= top_window.x and x <= top_window.x + top_window.width and y >= top_window.y and y <= top_window.y + top_window.height then
        -- Click is potentially on the top window
        handled_by_window = self:_handleWindowClick(top_window, x, y, button)
        click_handled = handled_by_window -- If top window handled it, mark as handled
    end

    -- If not handled by top window, check other windows from top down
    if not handled_by_window then
        local windows = self.window_manager:getAllWindows()
        for i = #windows, 1, -1 do
            local window = windows[i]
            -- Skip if it's the already-checked top window or minimized
            if window.id ~= top_window_id and not window.is_minimized then
                 if x >= window.x and x <= window.x + window.width and y >= window.y and y <= window.y + window.height then
                     -- Click is on this non-top window
                     handled_by_window = self:_handleWindowClick(window, x, y, button)
                     click_handled = handled_by_window -- If any window handled it, mark as handled
                     if handled_by_window then break end -- Stop checking lower windows
                 end
            end
        end
    end

    -- If any window interaction occurred (even just focusing), close desktop menus
    if click_handled then
        self.start_menu_open = false
        self.run_dialog_open = false
        self.last_icon_click_id = nil
        if handled_by_window then return end -- Return if window fully handled it (e.g., content interaction, button press)
    end


    -- --- Desktop UI / Empty Space Click Handling (Priority 3 - Only if not handled by window) ---
    if button == 1 then
        local clicked_specific_desktop_ui = false
        -- Check Start button
        if self.view:isStartButtonHovered(x, y) then
             clicked_specific_desktop_ui = true; self.start_menu_open = not self.start_menu_open; self.run_dialog_open = false
        -- Check Start menu items
        elseif self.start_menu_open then
            local start_menu_event = self.view:mousepressedStartMenu(x, y, button)
            if start_menu_event then
                clicked_specific_desktop_ui = true
                if start_menu_event.name == "launch_program" then
                    local program = self.program_registry:getProgram(start_menu_event.program_id)
                    if program and not program.disabled then self:launchProgram(start_menu_event.program_id)
                    else love.window.showMessageBox(Strings.get('messages.not_available','Not Available'), (program and program.name or "Program") .. " is not available yet.", "info") end
                    self.start_menu_open = false
                elseif start_menu_event.name == "open_run" then self.run_dialog_open = true; self.start_menu_open = false
                elseif start_menu_event.name == "close_start_menu" then self.start_menu_open = false end
            else self.start_menu_open = false end -- Clicked outside menu
        -- Check Run dialog
        elseif self.run_dialog_open then
            local run_event = self.view:mousepressedRunDialog(x, y, button)
            if run_event then
                clicked_specific_desktop_ui = true
                if run_event.name == "run_execute" then self:executeRunCommand(self.run_text); self.run_dialog_open = false; self.run_text = ""
                elseif run_event.name == "run_cancel" then self.run_dialog_open = false; self.run_text = "" end
            else self.run_dialog_open = false; self.run_text = "" end -- Clicked outside dialog
        -- Check desktop icons
        else
            local icon_program_id = self.view:getProgramAtPosition(x, y)
            if icon_program_id then
                clicked_specific_desktop_ui = true
                local program = self.program_registry:getProgram(icon_program_id)
                if program and not program.disabled then
                    local C = (self.di and self.di.config) or {}
                    local dbl = (C and C.ui and C.ui.double_click_time) or 0.5
                    local is_double_click = (self.last_icon_click_id == icon_program_id and love.timer.getTime() - self.last_icon_click_time < dbl)
                    if is_double_click then self:launchProgram(icon_program_id); self.last_icon_click_id = nil; self.last_icon_click_time = 0; self.dragging_icon_id = nil
                    else self.last_icon_click_id = icon_program_id; self.last_icon_click_time = love.timer.getTime(); self.dragging_icon_id = icon_program_id; local icon_pos = self.desktop_icons:getPosition(icon_program_id) or self.icon_controller:getDefaultIconPosition(icon_program_id); self.drag_offset_x = x - icon_pos.x; self.drag_offset_y = y - icon_pos.y end
                elseif program and program.disabled then love.window.showMessageBox(Strings.get('messages.not_available','Not Available'), program.name .. " is planned.", "info"); self.last_icon_click_id = nil; self.last_icon_click_time = 0 end
            end
            -- Check taskbar buttons if icon wasn't clicked
            if not icon_program_id then
                local taskbar_button_id = self.view:getTaskbarButtonAtPosition(x, y)
                if taskbar_button_id then
                    clicked_specific_desktop_ui = true
                    local window = self.window_manager:getWindowById(taskbar_button_id)
                    if window then local focused_id = self.window_manager:getFocusedWindowId(); if window.is_minimized then self.window_manager:restoreWindow(taskbar_button_id); self.window_manager:focusWindow(taskbar_button_id); elseif window.id == focused_id then self.window_manager:minimizeWindow(taskbar_button_id); else self.window_manager:focusWindow(taskbar_button_id); end end
                end
            end
        end
        -- If click wasn't on specific desktop UI or window chrome/content
        if not clicked_specific_desktop_ui and not click_handled then
             self.start_menu_open = false; self.run_dialog_open = false; self.last_icon_click_id = nil
        end

    elseif button == 2 then -- Right click on empty space / non-window element
        -- Generate desktop/icon/taskbar context menu
        local context_type = "desktop"; local context_data = {}
        local icon_program_id = self.view:getProgramAtPosition(x, y)
        local taskbar_button_id = self.view:getTaskbarButtonAtPosition(x, y)
        local on_start_button = self.view:isStartButtonHovered(x, y)
        local start_menu_program_id = nil
        if self.start_menu_open and self.view:isPointInStartMenu(x,y) then start_menu_program_id = self.view:getStartMenuProgramAtPosition(x, y) end

        if start_menu_program_id and start_menu_program_id ~= "run" then context_type = "start_menu_item"; context_data = { program_id = start_menu_program_id }
        elseif icon_program_id then context_type = "icon"; context_data = { program_id = icon_program_id }
        elseif taskbar_button_id then context_type = "taskbar"; context_data = { window_id = taskbar_button_id }
        elseif on_start_button then context_type = "start_button" -- NYI
        end

        if context_type ~= "start_button" then
            local options = self:generateContextMenuOptions(context_type, context_data)
            if #options > 0 then self:openContextMenu(x, y, options, { type = context_type, program_id = context_data.program_id, window_id = context_data.window_id }) end
        end
    end
end

function DesktopState:_handleWindowClick(window, x, y, button)
    local handled = false

    if self.window_manager:getFocusedWindowId() ~= window.id then
        self.window_manager:focusWindow(window.id)
        handled = true
    end

    local window_event = self.window_controller:checkWindowClick(window, x, y, self.window_chrome)

    if window_event then
        if window_event.type == "window_content_click" then
            local window_data = self.window_states[window.id]
            local window_state = window_data and window_data.state
            if window_state and window_state.mousepressed then
                 local local_x = window_event.content_x
                 local local_y = window_event.content_y
                 local success, state_result = pcall(window_state.mousepressed, window_state, local_x, local_y, button)

                 if success then
                     if type(state_result) == 'table' then
                         if state_result.type == "close_window" then
                             self:closeWindowById(window.id)
                             handled = true
                         elseif state_result.type == "event" then
                             self:handleStateEvent(window.id, state_result)
                             handled = true
                         elseif state_result.type == "content_interaction" then
                             handled = true
                         else
                             handled = true
                         end
                     elseif state_result == true then
                         handled = true
                     end
                 else
                      print("Error calling mousepressed on state for window " .. window.id .. ": " .. tostring(state_result))
                      handled = true
                 end
            end
            handled = true
            self.last_title_bar_click_id = nil; self.last_title_bar_click_time = 0

        elseif window_event.type == "window_drag_start" then
            local current_time = love.timer.getTime()
            local C = (self.di and self.di.config) or {}
            local dbl = (C and C.ui and C.ui.double_click_time) or 0.5
            if window.id == self.last_title_bar_click_id and current_time - self.last_title_bar_click_time < dbl then
                -- Respect resizable flag for double-click maximize/restore
                local program = self.program_registry:getProgram(window.program_type)
                local defaults = program and program.window_defaults or {}
                local C = (self.di and self.di.config) or {}
                local wd = (C and C.window and C.window.defaults) or {}
                local fallback_resizable = (wd.resizable ~= nil) and wd.resizable or true
                local computed_resizable = (defaults.resizable ~= nil) and defaults.resizable or fallback_resizable
                local is_resizable = (window.is_resizable ~= nil) and window.is_resizable or computed_resizable
                if is_resizable then
                    if window.is_maximized then
                        self.window_manager:restoreWindow(window.id)
                    else
                        self.window_manager:maximizeWindow(window.id, love.graphics.getWidth(), love.graphics.getHeight())
                    end
                    
                    -- ADD: Call setViewport after double-click maximize/restore
                    local updated_window = self.window_manager:getWindowById(window.id)
                    if updated_window then
                        local window_data = self.window_states[window.id]
                        local window_state = window_data and window_data.state
                        if window_state and window_state.setViewport then
                            local content_bounds = self.window_chrome:getContentBounds(updated_window)
                            pcall(window_state.setViewport, window_state,
                                  content_bounds.x, content_bounds.y,
                                  content_bounds.width, content_bounds.height)
                        end
                    end
                end
                self.last_title_bar_click_id = nil; self.last_title_bar_click_time = 0
                self.window_controller.dragging_window_id = nil
            else
                self.last_title_bar_click_id = window.id; self.last_title_bar_click_time = current_time
            end
            handled = true

        elseif window_event.type == "window_resize_start" or
               window_event.type == "window_close" or
               window_event.type == "window_minimize" or
               window_event.type == "window_maximize" or
               window_event.type == "window_restore" or
               window_event.type == "window_chrome_click" then
            local action_result = self:handleWindowEvent(window_event, x, y, button)
            handled = true
            self.last_title_bar_click_id = nil; self.last_title_bar_click_time = 0
        end
    end

    return handled
end

function DesktopState:mousemoved(x, y, dx, dy)
    self.idle_timer = 0
    -- Forward to window controller first (handles window drag/resize)
    -- Pass self.window_chrome instance
    self.window_controller:mousemoved(x, y, dx, dy, self.window_chrome)

    -- If an icon drag is active, update visual position (drawing handles this)
    -- No model update needed here, only on release

    -- Forward mouse move to focused window's state with content-relative coords (for in-window drags)
    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window = self.window_manager:getWindowById(focused_id)
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window and window_state and window_state.mousemoved then
            local content_bounds = self.window_chrome:getContentBounds(window)
            local local_x = x - content_bounds.x
            local local_y = y - content_bounds.y
            -- Call without guarding for bounds so drags outside still get updates
            pcall(window_state.mousemoved, window_state, local_x, local_y, dx, dy)
        end
    end
end

function DesktopState:mousereleased(x, y, button)
    self.idle_timer = 0
    -- Forward to window controller first
    self.window_controller:mousereleased(x, y, button)

    -- Handle icon drop
    if button == 1 and self.dragging_icon_id then
        local dropped_icon_id = self.dragging_icon_id
        self.dragging_icon_id = nil -- Stop drag state

        local initial_drop_x = x - self.drag_offset_x
        local initial_drop_y = y - self.drag_offset_y
        local screen_w, screen_h = love.graphics.getDimensions()
        local icon_w, icon_h = self.desktop_icons:getIconDimensions()
        local padding = 5 -- Buffer

        -- 1. Check Recycle Bin drop first
    local recycle_bin_pos = self.icon_controller:getRecycleBinPosition()
        if recycle_bin_pos and dropped_icon_id ~= "recycle_bin" then
            local drop_center_x = initial_drop_x + icon_w / 2
            local drop_center_y = initial_drop_y + icon_h / 2
            if drop_center_x >= recycle_bin_pos.x and drop_center_x <= recycle_bin_pos.x + recycle_bin_pos.w and
               drop_center_y >= recycle_bin_pos.y and drop_center_y <= recycle_bin_pos.y + recycle_bin_pos.h then
                print("Deleting icon:", dropped_icon_id)
                local original_pos = self.desktop_icons:getPosition(dropped_icon_id)
                self.recycle_bin:addItem(dropped_icon_id, original_pos); self.desktop_icons:save()
                return -- Deleted
            end
        end

        -- 2. Start overlap resolution with initial drop position
    local final_x, final_y = initial_drop_x, initial_drop_y
        local overlap_resolved = false
        local attempts = 0
        local max_attempts = 15

        while not overlap_resolved and attempts < max_attempts do
            attempts = attempts + 1
            overlap_resolved = true -- Assume resolved

            -- A. Validate the current position first
            local current_valid_x, current_valid_y = self.desktop_icons:validatePosition(final_x, final_y, screen_w, screen_h)
            final_x, final_y = current_valid_x, current_valid_y -- Update to validated position

            local overlapping_icon_data = nil
            local desktop_programs = self.program_registry:getDesktopPrograms()

            -- B. Check overlap at the validated position
            for _, program in ipairs(desktop_programs) do
                if program.id ~= dropped_icon_id and not self.desktop_icons:isDeleted(program.id) then
                    local other_pos = self.desktop_icons:getPosition(program.id) or self.icon_controller:getDefaultIconPosition(program.id)
                    if Collision.checkAABB(final_x, final_y, icon_w, icon_h, other_pos.x, other_pos.y, icon_w, icon_h) then
                        overlapping_icon_data = { program_id = program.id, pos = other_pos }
                        overlap_resolved = false
                        print("Overlap detected with", program.id, "at attempt", attempts)
                        break
                    end
                end
            end

            -- C. If overlap found, try to nudge
            if not overlap_resolved and overlapping_icon_data then
                local other_pos = overlapping_icon_data.pos
                local dx = (final_x + icon_w / 2) - (other_pos.x + icon_w / 2)
                local dy = (final_y + icon_h / 2) - (other_pos.y + icon_h / 2)
                local overlap_x = (icon_w) - math.abs(dx)
                local overlap_y = (icon_h) - math.abs(dy)

                -- Potential nudge positions based on primary overlap axis
                local potential_nudges = {}
                if overlap_x < overlap_y then -- Horizontal primary
                    if dx > 0 then table.insert(potential_nudges, {x = other_pos.x + icon_w + padding, y = final_y}) else table.insert(potential_nudges, {x = other_pos.x - icon_w - padding, y = final_y}) end
                    if dy > 0 then table.insert(potential_nudges, {x = final_x, y = other_pos.y + icon_h + padding}) else table.insert(potential_nudges, {x = final_x, y = other_pos.y - icon_h - padding}) end
                else -- Vertical primary
                    if dy > 0 then table.insert(potential_nudges, {x = final_x, y = other_pos.y + icon_h + padding}) else table.insert(potential_nudges, {x = final_x, y = other_pos.y - icon_h - padding}) end
                    if dx > 0 then table.insert(potential_nudges, {x = other_pos.x + icon_w + padding, y = final_y}) else table.insert(potential_nudges, {x = other_pos.x - icon_w - padding, y = final_y}) end
                end

                local found_nudge = false
                for _, nudge in ipairs(potential_nudges) do
                    -- Validate the *potential* nudge position first
                    local valid_nudge_x, valid_nudge_y = self.desktop_icons:validatePosition(nudge.x, nudge.y, screen_w, screen_h)

                    -- Check if this *validated* nudge position is free
                    local nudge_overlaps = false
                    for _, program_check in ipairs(desktop_programs) do
                        if program_check.id ~= dropped_icon_id and not self.desktop_icons:isDeleted(program_check.id) then
                             local check_pos = self.desktop_icons:getPosition(program_check.id) or self.icon_controller:getDefaultIconPosition(program_check.id)
                             if Collision.checkAABB(valid_nudge_x, valid_nudge_y, icon_w, icon_h, check_pos.x, check_pos.y, icon_w, icon_h) then
                                  nudge_overlaps = true; break
                             end
                        end
                    end

                    -- If nudge is valid AND doesn't overlap, update final position and restart loop
                    if not nudge_overlaps then
                        -- Check if the nudge actually changed the position significantly
                        if math.abs(valid_nudge_x - final_x) > 1 or math.abs(valid_nudge_y - final_y) > 1 then
                            final_x, final_y = valid_nudge_x, valid_nudge_y
                            found_nudge = true
                            overlap_resolved = false -- Crucial: Restart loop to re-validate the new position against all icons
                            print("Nudged to", final_x, final_y)
                            break -- Exit inner nudge loop, restart outer while loop
                        else
                             -- Nudge resulted in same position (likely due to clamping), try next nudge
                             print("Nudge resulted in same position, trying next.")
                        end
                    end
                end -- End trying potential nudges

                -- If no successful nudge was found after trying all directions
                if not found_nudge then
                    print("Could not resolve overlap after trying nudges. Accepting last valid position.")
                    -- final_x, final_y remain the last successfully validated position (current_valid_x/y)
                    overlap_resolved = true -- Force exit the while loop
                end
            -- else: No overlap found at the current validated position, loop will exit
            end -- end if overlap found
        end -- end while loop

        if attempts >= max_attempts then
             print("Warning: Hit attempt limit trying to resolve icon overlap for", dropped_icon_id)
        end

        -- 4. Snap to grid if enabled
        if self.icon_snap and self.icon_controller and self.icon_controller.snapToGrid then
            final_x, final_y = self.icon_controller:snapToGrid(final_x, final_y)
            -- re-validate after snap
            final_x, final_y = self.desktop_icons:validatePosition(final_x, final_y, screen_w, screen_h)
        end
        -- Update position in the model
        self.desktop_icons:setPosition(dropped_icon_id, final_x, final_y, screen_w, screen_h)
        self.desktop_icons:save()
        print("Dropped icon", dropped_icon_id, "at final position", final_x, final_y)
    end

    -- Forward mouse release to focused window's state (content-relative)
    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window = self.window_manager:getWindowById(focused_id)
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window and window_state and window_state.mousereleased then
            local content_bounds = self.window_chrome:getContentBounds(window)
            local local_x = x - content_bounds.x
            local local_y = y - content_bounds.y
            pcall(window_state.mousereleased, window_state, local_x, local_y, button)
        end
    end
end

function DesktopState:handleWindowEvent(event, x, y, button)
    local final_result = nil

    if event.type == "window_close" then
        local window = self.window_manager:getWindowById(event.window_id)
        if window then self.window_manager:rememberWindowPosition(window) end
        self.window_manager:closeWindow(event.window_id)
        self.window_states[event.window_id] = nil
        final_result = { type = "window_action" }

    elseif event.type == "window_minimize" then
        self.window_manager:minimizeWindow(event.window_id)
        final_result = { type = "window_action" }

    elseif event.type == "window_maximize" then
        self.window_manager:maximizeWindow(event.window_id, love.graphics.getWidth(), love.graphics.getHeight())
        
        -- Call setViewport on the state after maximizing
        local window = self.window_manager:getWindowById(event.window_id)
        if window then
            local window_data = self.window_states[event.window_id]
            local window_state = window_data and window_data.state
            if window_state and window_state.setViewport then
                local content_bounds = self.window_chrome:getContentBounds(window)
                pcall(window_state.setViewport, window_state,
                      content_bounds.x, content_bounds.y,
                      content_bounds.width, content_bounds.height)
            end
        end
        
        final_result = { type = "window_action" }

    elseif event.type == "window_restore" then
        self.window_manager:restoreWindow(event.window_id)
        
        -- Call setViewport on the state after restoring
        local window = self.window_manager:getWindowById(event.window_id)
        if window then
            local window_data = self.window_states[event.window_id]
            local window_state = window_data and window_data.state
            if window_state and window_state.setViewport then
                local content_bounds = self.window_chrome:getContentBounds(window)
                pcall(window_state.setViewport, window_state,
                      content_bounds.x, content_bounds.y,
                      content_bounds.width, content_bounds.height)
            end
        end
        
        final_result = { type = "window_action" }

    elseif event.type == "window_drag_start" then
        local current_time = love.timer.getTime()
        local C = (self.di and self.di.config) or {}
        local dbl = (C and C.ui and C.ui.double_click_time) or 0.5
         if event.window_id == self.last_title_bar_click_id and current_time - self.last_title_bar_click_time < dbl then
             local window = self.window_manager:getWindowById(event.window_id)
             if window then
                 local program = self.program_registry:getProgram(window.program_type)
                 local defaults = program and program.window_defaults or {}
                 local is_resizable = (defaults.resizable ~= false)

                 if is_resizable then
                     if window.is_maximized then
                         self.window_manager:restoreWindow(event.window_id)
                     else
                         self.window_manager:maximizeWindow(event.window_id, love.graphics.getWidth(), love.graphics.getHeight())
                     end
                     
                     -- Call setViewport after toggle
                     local updated_window = self.window_manager:getWindowById(event.window_id)
                     if updated_window then
                         local window_data = self.window_states[event.window_id]
                         local window_state = window_data and window_data.state
                         if window_state and window_state.setViewport then
                             local content_bounds = self.window_chrome:getContentBounds(updated_window)
                             pcall(window_state.setViewport, window_state,
                                   content_bounds.x, content_bounds.y,
                                   content_bounds.width, content_bounds.height)
                         end
                     end
                 end
             end
             self.last_title_bar_click_id = nil
             self.last_title_bar_click_time = 0
             self.window_controller.dragging_window_id = nil
         else
             self.last_title_bar_click_id = event.window_id
             self.last_title_bar_click_time = current_time
         end
         final_result = { type = "window_action" }

    elseif event.type == "window_content_click" then
        local window_data = self.window_states[event.window_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.mousepressed then
             local result = nil
             local local_x = event.content_x
             local local_y = event.content_y
             local success, state_result = pcall(window_state.mousepressed, window_state, local_x, local_y, button)

             if success then
                 result = state_result
                 if type(result) == 'table' then
                     if result.type == "close_window" then
                         local window = self.window_manager:getWindowById(event.window_id)
                         if window then self.window_manager:rememberWindowPosition(window) end
                         self.window_manager:closeWindow(event.window_id)
                         self.window_states[event.window_id] = nil
                         final_result = { type = "window_closed" }
                     elseif result.type == "set_setting" then
                         if window_state.setSetting then
                             window_state:setSetting(result.id, result.value)
                         end
                         final_result = { type = "content_interaction" }
                     elseif result.type == "event" then
                         self:handleStateEvent(event.window_id, result)
                         final_result = { type = "content_interaction" }
                     elseif result.type == "content_interaction" then
                         final_result = { type = "content_interaction" }
                     else
                         final_result = result
                     end
                 elseif result == true then
                     final_result = { type = "content_interaction" }
                 end
             else
                  print("Error calling mousepressed on state for window " .. event.window_id .. ": " .. tostring(state_result))
             end
        end
        self.last_title_bar_click_id = nil
        self.last_title_bar_click_time = 0
    elseif event.type == "window_chrome_click" then
        final_result = { type = "window_action" }
        self.last_title_bar_click_id = nil
        self.last_title_bar_click_time = 0
    end

    return final_result
end

function DesktopState:keypressed(key)
    self.idle_timer = 0
    if self.show_tutorial then
        local event = self.tutorial_view:keypressed(key)
        if event and event.name == "dismiss_tutorial" then self:dismissTutorial() end
        return true
    end

    -- Focused window gets priority for most keys
    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state

        -- Alt+F4 handling (give window state a chance to intercept if needed?)
        -- For now, handle it globally here if window doesn't consume 'f4' with 'alt'
        local alt_down = love.keyboard.isDown('lalt') or love.keyboard.isDown('ralt')
        if key == 'f4' and alt_down then
            local should_close_globally = true
            -- Optional: Check if state wants to handle Alt+F4 differently
            -- if window_state and window_state.handleAltF4 then should_close_globally = not window_state:handleAltF4() end

            if should_close_globally then
                 print("Alt+F4 pressed, closing window:", focused_id)
                 self:closeWindowById(focused_id) -- Use helper
                 return true
            end
        end

        -- Pass other keypresses to focused window state
        if window_state and window_state.keypressed then
             local success, result = pcall(window_state.keypressed, window_state, key)
             if success then
                if type(result) == 'table' then
                     if result.type == "close_window" then self:closeWindowById(focused_id); return true -- Use helper
                     elseif result.type == "event" then self:handleStateEvent(focused_id, result); return true
                     elseif result.type == "content_interaction" then return true end
                elseif result == true then return true -- Handled by window state
                end
             else print("Error calling keypressed on state for window " .. focused_id .. ": " .. tostring(result)) end
            -- If state returned false or error, let global shortcuts check
        end
    end

    -- Global shortcuts if not handled by window OR no window focused
    if self.run_dialog_open then
        if key == "escape" then self.run_dialog_open = false; self.run_text = ""; return true
        elseif key == "return" then self:executeRunCommand(self.run_text); self.run_dialog_open = false; self.run_text = ""; return true
        elseif key == "backspace" then self.run_text = self.run_text:sub(1, -2); return true end
         -- Let textinput handle other keys
         return true -- Consume keys while run dialog is open
    end

    if self.start_menu_open then
        if key == "escape" then self.start_menu_open = false; return true end
        return true -- Consume keys while start menu is open
    end

    -- Ctrl+R for Run dialog
    if (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) and key == 'r' then
        self.run_dialog_open = true; self.start_menu_open = false; self.run_text = ""; return true
    end

    -- Debug menu toggle (F5)
    if key == 'f5' and self.state_machine then
        if self.state_machine.states[Constants.state.DEBUG] then
            local current_fullscreen_state_name = Constants.state.DESKTOP
            if self.state_machine.current_state == self.state_machine.states[Constants.state.DEBUG] then self.state_machine:switch(current_fullscreen_state_name)
            else self.state_machine:switch(Constants.state.DEBUG, current_fullscreen_state_name) end
             return true
        end
    end

    -- ESC closes focused window (if any) or quits if none are open
    if key == 'escape' then
         if focused_id then
             print("ESC pressed, closing window:", focused_id)
             self:closeWindowById(focused_id) -- Use helper
             return true
         elseif #self.window_manager:getAllWindows() == 0 then
             -- Quit game if ESC pressed on empty desktop
             love.event.quit()
             return true
         end
    end

    return false -- Key not handled
end

function DesktopState:textinput(text)
    self.idle_timer = 0
     local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.textinput then
             local success, handled = pcall(window_state.textinput, window_state, text)
             if success and handled then
                 return -- Handled by window state
             elseif not success then
                  print("Error calling textinput on state for window " .. focused_id .. ": " .. tostring(handled))
             end
        end
    end

    -- If not handled by window, check if run dialog is open
    if self.run_dialog_open then
        self.run_text = self.run_text .. text
    end
end

function DesktopState:wheelmoved(x, y)
    self.idle_timer = 0
    -- Send to focused window first
    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.wheelmoved then
             -- Check if mouse is over the window content area before sending scroll
             local mx, my = love.mouse.getPosition()
             local window = self.window_manager:getWindowById(focused_id)
             if window then
                 local content_bounds = self.window_chrome:getContentBounds(window)
                 if mx >= content_bounds.x and mx <= content_bounds.x + content_bounds.width and
                    my >= content_bounds.y and my <= content_bounds.y + content_bounds.height then
                     local success, handled = pcall(window_state.wheelmoved, window_state, x, y)
                     if success and handled then
                         return -- Handled by window state
                     elseif not success then
                         print("Error calling wheelmoved on state for window " .. focused_id .. ": " .. tostring(handled))
                     end
                 end
             end
        end
    end
    -- Could add desktop background scroll handling here later if needed
end

function DesktopState:handleStateEvent(window_id, event)
    print("Received event from window " .. window_id .. ": " .. tostring(event.name))

    local handlers = {
        next_level = function()
            self:closeWindowById(window_id)
            self:launchProgram("space_defender", event.level)
        end,
        show_completion = function()
            self:closeWindowById(window_id)
            self.state_machine:switch(Constants.state.COMPLETION)
        end,
        launch_program = function()
            self:launchProgram(event.program_id)
        end,
        launch_minigame = function()
            if event.game_data then
                self:launchProgram("minigame_runner", event.game_data)
            else
                print("ERROR: launch_minigame event missing game_data!")
            end
        end,
        show_text = function()
            self:showTextFileDialog(event.title, event.content)
        end,
        show_context_menu = function()
            self:openContextMenu(event.menu_x, event.menu_y, event.options, event.context)
        end,
        ensure_icon_visible = function()
            self:ensureIconIsVisible(event.program_id)
        end,
    }

    local handler = handlers[event.name]
    if handler then handler() end
end

function DesktopState:executeRunCommand(command)
    command = command:gsub("^%s*(.-)%s*$", "%1"):lower() -- Trim whitespace and lower

    if command == "" then print("No command entered"); return end

    local program = self.program_registry:findByExecutable(command)
    if program then
        if not program.disabled then
            self:launchProgram(program.id)
        else
            love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), string.format(Strings.get('messages.cannot_find_fmt', "Cannot find '%s'."), command), "error")
        end
    else
    love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), string.format(Strings.get('messages.cannot_find_fmt', "Cannot find '%s'."), command), "error")
    end
end

function DesktopState:showTextFileDialog(title, content)
    love.window.showMessageBox(title, content or "[Empty File]", "info")
end

function DesktopState:launchProgram(program_id, ...)
    local launch_args = {...}
    print("Attempting to launch program: " .. program_id)

    local program = self.program_registry:getProgram(program_id)
    if not program then print("Program definition not found: " .. program_id); return end
    if program.disabled then print("Program disabled: " .. program_id); love.window.showMessageBox(Strings.get('messages.not_available','Not Available'), program.name .. " is not available yet.", "info"); return end
    if not program.state_class_path then print("Program missing state_class_path: " .. program_id); return end

    local defaults = program.window_defaults or {}
    if defaults.single_instance then
        local existing_id = self.window_manager:isProgramOpen(program_id)
        if existing_id then
            print(program.name .. " already running.")
            self.window_manager:focusWindow(existing_id)
            return
        end
    end

    local module_name_slash = program.state_class_path:gsub("%.", "/")
    local require_ok, StateClass = pcall(require, module_name_slash)
    if not require_ok or not StateClass then
        local err = tostring(StateClass)
        print("ERROR loading state class '" .. program.state_class_path .. "': " .. err)
        -- If we hit Lua's 'loop or previous error' cache, clear and retry once to surface the real cause
        if err:find("previous error loading module", 1, true) or err:find("loop or previous error", 1, true) then
            -- Try to extract the exact failing module from the error text and purge it as well
            local offending = err:match("module '([^']+)'%s-") or err:match("no field package%.preload%['([^']+)'%]")
            if offending then
                package.loaded[offending] = nil
                package.loaded[offending:gsub('%.','/')] = nil
            end
            package.loaded[program.state_class_path] = nil
            package.loaded[module_name_slash] = nil
            local retry_ok, RetryClass = pcall(require, module_name_slash)
            if not retry_ok or not RetryClass then
                print("Retry require failed for '" .. program.state_class_path .. "': " .. tostring(RetryClass))
                return
            else
                StateClass = RetryClass
            end
        else
            return
        end
    end

    local state_args = {}
    local missing_deps = {}
    for _, dep_name in ipairs(program.dependencies or {}) do
        local dependency = self.dependency_provider[dep_name]
        if dependency then table.insert(state_args, dependency)
        else print("ERROR: Missing dependency '" .. dep_name .. "'"); table.insert(missing_deps, dep_name) end
    end
    if #missing_deps > 0 then love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), "Missing dependencies: " .. table.concat(missing_deps, ", "), "error"); return end

    local instance_ok, new_state = pcall(StateClass.new, StateClass, unpack(state_args))
    if not instance_ok or not new_state then print("ERROR instantiating state: " .. tostring(new_state)); return end

    local screen_w, screen_h = love.graphics.getDimensions()
    local C = (self.di and self.di.config) or {}
    local wd = (C and C.window and C.window.defaults) or {}
    local default_w = defaults.w or wd.width or 800
    local default_h = defaults.h or wd.height or 600

    local title_prefix = wd.title_prefix or ""
    local initial_title = (title_prefix ~= "" and (title_prefix .. program.name)) or program.name
    local game_data_arg = nil
    local program_for_window = program
    
    if program_id == "minigame_runner" then
        game_data_arg = launch_args[1]
        if game_data_arg and game_data_arg.display_name then 
            initial_title = (title_prefix ~= "" and (title_prefix .. game_data_arg.display_name)) or game_data_arg.display_name 
            -- Create a modified program definition with the game's icon
            program_for_window = {
                id = program.id,
                name = game_data_arg.display_name,
                icon_sprite = game_data_arg.icon_sprite,
                window_defaults = program.window_defaults
            }
        else 
            initial_title = (title_prefix ~= "" and (title_prefix .. "Minigame")) or "Minigame" 
        end
    end

    local window_id = self.window_manager:createWindow( program_for_window, initial_title, new_state, default_w, default_h )    
    if not window_id then print("ERROR: WindowManager failed to create window for " .. program_id); return end

    self.window_states[window_id] = { state = new_state }
    if new_state.setWindowContext then new_state:setWindowContext(window_id, self.window_manager) end

    -- REMOVED: Early setViewport call before enter()

    local enter_args = {}
    local enter_args_config = program.enter_args
    if program_id == "minigame_runner" then
        if game_data_arg then enter_args = { game_data_arg } end
    elseif enter_args_config then
        if enter_args_config.type == "first_launch_arg" then enter_args = {launch_args[1] or enter_args_config.default}
        elseif enter_args_config.type == "static" then enter_args = {enter_args_config.value} end
    end

    if new_state.enter then
        local enter_ok, enter_err = pcall(new_state.enter, new_state, unpack(enter_args))
        if type(enter_err) == 'table' and enter_err.type == "close_window" then
            print("State signaled close during enter for " .. program_id); self.window_manager:closeWindow(window_id); self.window_states[window_id] = nil; return
        elseif not enter_ok then
            print("ERROR calling enter on state for " .. program_id .. ": " .. tostring(enter_err)); self.window_manager:closeWindow(window_id); self.window_states[window_id] = nil; return
        end
    end

    -- MOVED: Call setViewport AFTER enter() completes successfully
    local created_window = self.window_manager:getWindowById(window_id)
    if created_window and new_state.setViewport then
        local initial_content_bounds = self.window_chrome:getContentBounds(created_window)
        local viewport_ok, viewport_err = pcall(new_state.setViewport, new_state,
              initial_content_bounds.x, initial_content_bounds.y,
              initial_content_bounds.width, initial_content_bounds.height)
        if not viewport_ok then
            print("ERROR calling setViewport after enter for " .. program_id .. ": " .. tostring(viewport_err))
        end
    end

    if defaults.prefer_maximized and defaults.resizable ~= false then
        self.window_manager:maximizeWindow(window_id, screen_w, screen_h)
         local maximized_window = self.window_manager:getWindowById(window_id)
         if maximized_window and new_state.setViewport then
             local maximized_content_bounds = self.window_chrome:getContentBounds(maximized_window)
             pcall(new_state.setViewport, new_state,
                   maximized_content_bounds.x, maximized_content_bounds.y,
                   maximized_content_bounds.width, maximized_content_bounds.height)
         end
    end

    print("Opened window for " .. initial_title .. " ID: " .. window_id)
end

function DesktopState:dismissTutorial()
    self.show_tutorial = false
    local SettingsManager = (self.di and self.di.settingsManager) or require('src.utils.settings_manager')
    SettingsManager.set("tutorial_shown", true)
    print("Tutorial dismissed.")
end

-- Helper function to generate context menu options based on context
function DesktopState:generateContextMenuOptions(context_type, context_data)
    local options = {}
    context_data = context_data or {} -- Ensure context_data exists

    if context_type == "icon" then
        local program_id = context_data.program_id
        local program = self.program_registry:getProgram(program_id)
        if program then
          table.insert(options, { id = "open", label = Strings.get('menu.open', 'Open'), enabled = not program.disabled })
          table.insert(options, { id = "separator" })
            if program_id ~= "recycle_bin" and program_id ~= "my_computer" then
              table.insert(options, { id = "delete", label = Strings.get('menu.delete', 'Delete'), enabled = true })
            end
          table.insert(options, { id = "separator" })
          table.insert(options, { id = "properties", label = Strings.get('menu.properties', 'Properties') .. " (NYI)", enabled = false })
        end

    elseif context_type == "taskbar" then
        local window_id = context_data.window_id
        local window = self.window_manager:getWindowById(window_id)
        if window then
            table.insert(options, { id = "restore", label = Strings.get('menu.restore', 'Restore'), enabled = window.is_minimized })
            table.insert(options, { id = "minimize", label = Strings.get('menu.minimize', 'Minimize'), enabled = not window.is_minimized })
            local can_maximize = true -- Add check for program.window_defaults.resizable later
            if window.is_maximized then
                table.insert(options, { id = "restore_size", label = Strings.get('menu.restore_size', 'Restore Size'), enabled = can_maximize })
            else
                table.insert(options, { id = "maximize", label = Strings.get('menu.maximize', 'Maximize'), enabled = can_maximize and not window.is_minimized })
            end
            table.insert(options, { id = "separator" })
            table.insert(options, { id = "close_window", label = Strings.get('menu.close', 'Close'), enabled = true })
        end

    elseif context_type == "desktop" then
    table.insert(options, { id = "arrange_icons", label = Strings.get('menu.arrange_icons', 'Arrange Icons') .. " (NYI)", enabled = false })
    table.insert(options, { id = "separator" })
    table.insert(options, { id = "refresh", label = Strings.get('menu.refresh', 'Refresh'), enabled = true })
    table.insert(options, { id = "separator" })
    table.insert(options, { id = "properties", label = Strings.get('menu.properties', 'Properties') .. " (NYI)", enabled = false })

    elseif context_type == "start_menu_item" then
        local program_id = context_data.program_id
        local program = self.program_registry:getProgram(program_id)
        if program then
            table.insert(options, { id = "open", label = Strings.get('menu.open', 'Open'), enabled = not program.disabled })
            table.insert(options, { id = "separator" })
            local is_visible = self.desktop_icons:isIconVisible(program_id)
            table.insert(options, {
                id = "create_shortcut_desktop",
                label = Strings.get('menu.create_shortcut_desktop', 'Create Shortcut (Desktop)'),
                enabled = not is_visible and not program.disabled
            })
            table.insert(options, { id = "separator" })
            table.insert(options, { id = "properties", label = Strings.get('menu.properties', 'Properties') .. " (NYI)", enabled = false })
        end

    elseif context_type == "file_explorer_item" or context_type == "file_explorer_empty" then
        -- Options are generated by FileExplorerState and passed in context_data.options
        -- Just return them directly
        print("[Debug generateContextMenuOptions] Passing through FE options")
        -- The context_data.options ALREADY includes separators handled by FileExplorerState logic if needed
        -- Or rather, the options passed *to* openContextMenu are already processed there.
        -- So, we retrieve the raw options from the context provided by FE.
        -- Let's assume the FE state passes the raw options it generated.
        options = context_data.options or {} -- Get the options generated by FE
        -- We still need to process them for separators here for consistent rendering
        local final_options = {}
        for _, opt in ipairs(options or {}) do
            if opt.id == "separator" then
                 table.insert(final_options, { id = "_sep_" .. #final_options, label = "---", enabled = false, is_separator = true })
            else
                 table.insert(final_options, opt)
            end
        end
        return final_options -- Return the processed FE options

    end

    -- Add separator rendering support (visual only) - Apply only if not returning FE options directly
    if context_type ~= "file_explorer_item" and context_type ~= "file_explorer_empty" then
        local final_options = {}
        for _, opt in ipairs(options or {}) do
            if opt.id == "separator" then
                 table.insert(final_options, { id = "_sep_" .. #final_options, label = "---", enabled = false, is_separator = true })
            else
                 table.insert(final_options, opt)
            end
        end
        return final_options
    else
         -- This path should technically not be reached due to the return inside the elseif block
        return options
    end
end

-- Helper function to open the context menu. Called with generated options and context.
function DesktopState:openContextMenu(x, y, options, context)
    -- Add separator rendering support (visual only)
    local final_options = {}
    for _, opt in ipairs(options or {}) do -- Add nil check for options
        if opt.id == "separator" then
             table.insert(final_options, { id = "_sep_" .. #final_options, label = "---", enabled = false, is_separator = true })
        else
             table.insert(final_options, opt)
        end
    end
    self.menu_options = final_options

    self.menu_context = context or {} -- Ensure context is a table
    self.menu_x = x
    self.menu_y = y

    -- Adjust position slightly if menu goes off screen
    local screen_w, screen_h = love.graphics.getDimensions()
    local menu_w = self.context_menu_view.menu_w -- Use view's width
    local menu_h = #self.menu_options * self.context_menu_view.item_height + self.context_menu_view.padding * 2
    if self.menu_x + menu_w > screen_w then self.menu_x = screen_w - menu_w end
    if self.menu_y + menu_h > screen_h then self.menu_y = screen_h - menu_h end
    self.menu_x = math.max(0, self.menu_x)
    self.menu_y = math.max(0, self.menu_y)

    self.context_menu_open = true
    print("Opened context menu at", self.menu_x, self.menu_y, "with context type:", self.menu_context.type, "#Options:", #self.menu_options)
end


-- Helper function to close the context menu
function DesktopState:closeContextMenu()
    self.context_menu_open = false
    self.menu_options = {}
    self.menu_context = nil
end

-- Function to handle actions selected from the context menu
function DesktopState:handleContextMenuAction(action_id, context)
    print("[Action Handler] Action:", action_id, "Context Type:", context.type)
    local program_id = context.program_id -- Used by multiple contexts
    local window_id = context.window_id   -- Used by taskbar and potentially FE

    if context.type == "icon" then
        if not program_id then print("ERROR: program_id missing for icon context!"); return end
        if action_id == "open" then self:launchProgram(program_id)
        elseif action_id == "delete" then self:deleteDesktopIcon(program_id)
        elseif action_id == "properties" then print("Action 'Properties' NYI")
        end

    elseif context.type == "taskbar" then
        if not window_id then print("ERROR: window_id missing for taskbar context!"); return end
        if action_id == "restore" then self.window_manager:restoreWindow(window_id); self.window_manager:focusWindow(window_id)
        elseif action_id == "restore_size" then self.window_manager:restoreWindow(window_id)
        elseif action_id == "minimize" then self.window_manager:minimizeWindow(window_id)
        elseif action_id == "maximize" then self.window_manager:maximizeWindow(window_id, love.graphics.getWidth(), love.graphics.getHeight())
        elseif action_id == "close_window" then self:closeWindowById(window_id)
        end

    elseif context.type == "desktop" then
        if action_id == "refresh" then print("Action 'Refresh' called."); self.view:calculateDefaultIconPositionsIfNeeded()
        elseif action_id == "arrange_icons" then print("Action 'Arrange Icons' NYI")
        elseif action_id == "properties" then print("Action 'Properties' NYI")
        end

    elseif context.type == "start_menu_item" then
        if not program_id then print("ERROR: program_id missing for start_menu_item context!"); return end
        if action_id == "open" then self:launchProgram(program_id)
        elseif action_id == "create_shortcut_desktop" then self:ensureIconIsVisible(program_id)
        elseif action_id == "properties" then print("Action 'Properties' NYI")
        end

    elseif context.type == "file_explorer_item" or context.type == "file_explorer_empty" then
        -- Find the correct File Explorer state instance using the window_id from the context
        local fe_window_id = context.window_id
        local fe_state_data = fe_window_id and self.window_states[fe_window_id]
        local fe_state = fe_state_data and fe_state_data.state

        -- Check if it's actually a FileExplorerState instance
        if fe_state and fe_state.handleItemDoubleClick then
            local item = context.item -- Might be nil for empty space clicks

            if action_id == "restore" and item then fe_state:restoreFromRecycleBin(item.program_id)
            elseif action_id == "delete_permanently" and item then fe_state:permanentlyDeleteFromRecycleBin(item.program_id)
            elseif action_id == "open" and item then
                 local result = fe_state:handleItemDoubleClick(item)
                 -- If double click resulted in an event (like launch), handle it
                 if type(result) == 'table' and result.type == "event" then self:handleStateEvent(fe_window_id, result) end
            elseif action_id == "create_shortcut_desktop" and item then
                 -- Call the FE state method, which might return an event for DesktopState
                 local result = fe_state:createShortcutOnDesktop(item)
                 if type(result) == 'table' and result.type == "event" then
                     -- Handle events returned by createShortcut (like ensure_icon_visible)
                     self:handleStateEvent(fe_window_id, result) -- Pass event up
                 end
            elseif action_id == "delete" then print("Delete from file explorer NYI") -- Placeholder
            elseif action_id == "properties" then print("File properties NYI") -- Placeholder
            elseif action_id == "refresh" then fe_state:refresh() -- Handle refresh for empty space context
            else print("Warning: Unhandled file explorer action:", action_id)
            end
        else
            print("Error: Could not find relevant File Explorer state instance for window ID:", fe_window_id)
        end
    else
         print("Warning: Unhandled context menu context type:", context.type)
    end
end

-- Helper to ensure a program's icon is visible on the desktop
function DesktopState:ensureIconIsVisible(program_id)
    if not program_id then return end

    print("Ensuring icon is visible for:", program_id)
    -- 1. Un-delete the icon (safe to call even if not deleted)
    self.desktop_icons:restoreIcon(program_id)

    -- 2. Check if it already has a position
    local current_pos = self.desktop_icons:getPosition(program_id)
    if current_pos then
         print("Icon already has a position, leaving it there.")
         -- Optionally bring window to front if program is open?
    else
        print("Icon needs position, placing in default grid.")
        -- 3. Find next available default grid spot
        local default_pos = self:findNextAvailableGridPosition(program_id)
        local screen_w, screen_h = love.graphics.getDimensions()
        self.desktop_icons:setPosition(program_id, default_pos.x, default_pos.y, screen_w, screen_h)
    end

    -- 4. Save changes
    self.desktop_icons:save()
    -- Optional: Maybe briefly highlight the icon?
end

-- Helper to find the next free spot in the default grid layout
function DesktopState:findNextAvailableGridPosition(program_id_to_place)
    self.view:calculateDefaultIconPositionsIfNeeded() -- Ensure defaults are calculated

    local occupied_positions = {} -- Store positions currently in use
    local desktop_programs = self.program_registry:getDesktopPrograms()
    local icon_w, icon_h = self.desktop_icons:getIconDimensions()

    for _, program in ipairs(desktop_programs) do
        -- Consider a spot occupied if the icon is visible and is NOT the one we are currently placing
        if program.id ~= program_id_to_place and self.desktop_icons:isIconVisible(program.id) then
             local pos = self.desktop_icons:getPosition(program.id) or self.icon_controller:getDefaultIconPosition(program.id)
             -- Use a simple representation for occupied check (e.g., top-left corner)
             occupied_positions[string.format("%.0f,%.0f", pos.x, pos.y)] = true
        end
    end

    -- Iterate through default positions in order
    local available_height = love.graphics.getHeight() - self.view.taskbar_height - self.view.icon_start_y
    local icons_per_column = math.max(1, math.floor(available_height / (icon_h + self.view.icon_padding)))
    local col = 0
    local row = 0

    while true do -- Loop until a spot is found (should always find one eventually)
         local potential_x = self.view.icon_start_x + col * (icon_w + self.view.icon_padding)
         local potential_y = self.view.icon_start_y + row * (icon_h + self.view.icon_padding)
         local pos_key = string.format("%.0f,%.0f", potential_x, potential_y)

         -- Check if this default grid position is occupied
         if not occupied_positions[pos_key] then
             print("Found available grid position:", potential_x, potential_y)
             return { x = potential_x, y = potential_y }
         end

         -- Move to next grid position
         row = row + 1
         if row >= icons_per_column then
             row = 0
             col = col + 1
             -- Add safety break if columns get too high?
             if col > 20 then
                  print("Warning: Could not find free grid slot easily, returning default.")
                  return self.icon_controller:getDefaultIconPosition(program_id_to_place) or { x=20, y=20 }
             end
         end
    end
end

-- Helper to find a specific File Explorer instance (basic)
function DesktopState:findFileExplorerStateInstance(target_path)
     for win_id, win_data in pairs(self.window_states) do
         if win_data.state and win_data.state.__cname == "FileExplorerState" then
              -- If target_path is provided, match it. Otherwise, return first found.
              if not target_path or win_data.state.current_path == target_path then
                  return win_data.state
              end
         end
     end
     return nil -- Not found
end

-- Helper to close window and clean up state map
function DesktopState:closeWindowById(window_id)
      local window = self.window_manager:getWindowById(window_id)
      if window then self.window_manager:rememberWindowPosition(window) end
      self.window_manager:closeWindow(window_id)
      self.window_states[window_id] = nil
end

-- Helper for deleting icons via context menu
function DesktopState:deleteDesktopIcon(program_id)
     if program_id ~= "recycle_bin" and program_id ~= "my_computer" then
         print("Deleting icon via context menu:", program_id)
         local original_pos = self.desktop_icons:getPosition(program_id)
         self.recycle_bin:addItem(program_id, original_pos)
         self.desktop_icons:save()
     else
         print("Cannot delete core icon:", program_id)
     end
end

return DesktopState