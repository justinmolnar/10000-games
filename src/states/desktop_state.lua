local Object = require('class')
local DesktopView = require('views.desktop_view')
local SettingsManager = require('src.utils.settings_manager')
local TutorialView = require('src.views.tutorial_view')
local ProgramRegistry = require('models.program_registry')
local WindowChrome = require('src.views.window_chrome')
local WindowController = require('src.controllers.window_controller')

-- Global references needed by launchProgram (passed in init)
local SaveManager = nil
local vm_manager = nil
local cheat_system = nil
local game_data = nil -- Added missing reference

local DesktopState = Object:extend('DesktopState')

function DesktopState:init(state_machine, player_data, show_tutorial_on_startup, statistics,
                           window_manager, desktop_icons, file_system, recycle_bin, program_registry,
                           vm_manager_dep, cheat_system_dep, save_manager_dep, game_data_dep) -- Use unique names for args

    self.state_machine = state_machine
    self.player_data = player_data
    self.statistics = statistics
    self.window_manager = window_manager
    self.desktop_icons = desktop_icons
    self.file_system = file_system
    self.recycle_bin = recycle_bin
    self.program_registry = program_registry
    self.vm_manager = vm_manager_dep -- Store dependency
    self.cheat_system = cheat_system_dep -- Store dependency
    self.save_manager = save_manager_dep -- Store dependency
    self.game_data = game_data_dep -- Store dependency

    -- Phase 2 components
    self.window_chrome = WindowChrome:new()
    self.window_controller = WindowController:new(window_manager, self.program_registry)

    -- Window state instances (store {state = state_instance})
    self.window_states = {}

    -- Create view, passing necessary models
    self.view = DesktopView:new(self.program_registry, self.player_data, self.window_manager)
    self.tutorial_view = TutorialView:new(self)

    self.wallpaper_color = {0, 0.5, 0.5}
    self.show_tutorial = show_tutorial_on_startup or false

    -- UI state
    self.start_menu_open = false
    self.run_dialog_open = false
    self.run_text = ""

    -- Click tracking
    self.last_icon_click_time = 0
    self.last_icon_click_id = nil
    self.last_title_bar_click_time = 0 -- Added for title bar double-click
    self.last_title_bar_click_id = nil -- Added for title bar double-click
end

function DesktopState:enter()
    self:updateClock()
    print("Desktop loaded. Tutorial active: " .. tostring(self.show_tutorial))
    -- Reload window positions in case they changed while away? Or assume they persist.
    -- Ensure view layout is correct initially
    self.view:calculateIconPositions()
end

function DesktopState:update(dt)
    -- Update window controller (handles drag/resize state)
    self.window_controller:update(dt)

    -- Update all active window states
    for window_id, window_data in pairs(self.window_states) do
        if window_data.state and window_data.state.update then
            window_data.state:update(dt)
        end
    end

    -- Update tutorial or view
    if self.show_tutorial then
        self.tutorial_view:update(dt)
    else
        self.view:update(dt, self.start_menu_open)
    end
end


function DesktopState:updateClock()
    self.current_time = os.date("%H:%M")
end

function DesktopState:draw()
    self.view:draw(
        self.wallpaper_color,
        self.player_data.tokens,
        self.start_menu_open,
        self.run_dialog_open,
        self.run_text
    )

    -- Draw windows (bottom to top in z-order)
    local windows = self.window_manager:getAllWindows()
    for i = 1, #windows do
        local window = windows[i]
        if not window.is_minimized then
            self:drawWindow(window)
        end
    end

    if self.show_tutorial then
        self.tutorial_view:draw()
    end
end

function DesktopState:drawWindow(window)
    local is_focused = self.window_manager:getFocusedWindowId() == window.id

    -- Draw window chrome
    self.window_chrome:draw(window, is_focused)

    -- Draw window content
    local window_data = self.window_states[window.id]
    local window_state = window_data and window_data.state

    if window_state and window_state.draw then
        local content_bounds = self.window_chrome:getContentBounds(window)
        -- Ensure state has viewport set BEFORE drawing
        if window_state.setViewport then
             window_state:setViewport(content_bounds.x, content_bounds.y,
                                      content_bounds.width, content_bounds.height)
        end
        -- Actual drawing happens within state's draw method using push/translate/scissor
        window_state:draw()
    end
end

function DesktopState:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Tutorial consumes all input
    if self.show_tutorial then
        local event = self.tutorial_view:mousepressed(x, y, button)
        if event and event.name == "dismiss_tutorial" then
            self:dismissTutorial()
        end
        return
    end

    -- Check windows first (using WindowController)
    local window_event = self.window_controller:mousepressed(x, y, button, self.window_chrome)
    if window_event then
        -- Handle window chrome events or forward content events
        self:handleWindowEvent(window_event, x, y, button)
        self.start_menu_open = false -- Close start menu if clicking on a window
        return
    end

    -- Check Taskbar Buttons
    local taskbar_button_id = self.view:getTaskbarButtonAtPosition(x, y)
    if taskbar_button_id then
        local window = self.window_manager:getWindowById(taskbar_button_id)
        if window then
            local focused_id = self.window_manager:getFocusedWindowId()
            if window.is_minimized then
                self.window_manager:restoreWindow(taskbar_button_id)
                self.window_manager:focusWindow(taskbar_button_id) -- Focus after restoring
            elseif window.id == focused_id then
                self.window_manager:minimizeWindow(taskbar_button_id)
            else
                self.window_manager:focusWindow(taskbar_button_id)
            end
        end
        self.start_menu_open = false -- Close start menu if clicking taskbar
        return -- Input handled
    end

    -- Check Start Button
    if self.view:isStartButtonHovered(x, y) then
         self.start_menu_open = not self.start_menu_open
         -- No return here, click might be outside start menu to close it below
    else
        -- Check Start Menu Content (only if menu is open)
        if self.start_menu_open then
            local start_menu_event = self.view:mousepressedStartMenu(x, y, button)
            if start_menu_event then
                if start_menu_event.name == "launch_program" then
                    self:launchProgram(start_menu_event.program_id)
                    self.start_menu_open = false
                elseif start_menu_event.name == "open_run" then
                    self.run_dialog_open = true
                    self.start_menu_open = false
                elseif start_menu_event.name == "close_start_menu" then
                    self.start_menu_open = false
                end
                return -- Handled by start menu
            else
                 -- Clicked outside the start menu while it was open, so close it
                 self.start_menu_open = false
                 -- Don't return yet, might be an icon click
            end
        end

         -- Check Run Dialog (only if open)
        if self.run_dialog_open then
            local run_event = self.view:mousepressedRunDialog(x, y, button)
            if run_event then
                if run_event.name == "run_execute" then
                    self:executeRunCommand(self.run_text)
                    self.run_dialog_open = false
                    self.run_text = ""
                elseif run_event.name == "run_cancel" then
                    self.run_dialog_open = false
                    self.run_text = ""
                end
            end
             -- Clicks outside the run dialog don't close it, only Cancel/OK/Escape
            return -- Input assumed handled (or ignored) by run dialog area
        end

        -- Check Desktop Icons (only if nothing else handled the click)
        local icon_event = self.view:mousepressed(x, y, button) -- Re-check view specifically
        if icon_event and icon_event.name == "icon_click" then
            local program = self.program_registry:getProgram(icon_event.program_id)
            if program and not program.disabled then
                local is_double_click = (self.last_click_program_id == icon_event.program_id and
                                        love.timer.getTime() - self.last_click_time < 0.5)
                if is_double_click then
                    self:launchProgram(icon_event.program_id)
                    self.last_click_program_id = nil -- Reset double click track after launch
                    self.last_click_time = 0
                else
                    self.last_click_program_id = icon_event.program_id
                    self.last_click_time = love.timer.getTime()
                end

            elseif program and program.disabled then
                 print(program.name .. " is not available in MVP")
                 love.window.showMessageBox("Not Available", program.name .. " is planned for a future update!", "info")
                 self.last_click_program_id = nil -- Reset double click
                 self.last_click_time = 0
            end
            return -- Handled by icon click
        end
    end

     -- If click was anywhere else, ensure start menu is closed
    if not self.view:isStartButtonHovered(x, y) then
         self.start_menu_open = false
    end
    -- Reset double click tracking if background clicked
    self.last_click_program_id = nil
    self.last_click_time = 0
end


function DesktopState:mousemoved(x, y, dx, dy)
    self.window_controller:mousemoved(x, y, dx, dy)
end

function DesktopState:mousereleased(x, y, button)
    self.window_controller:mousereleased(x, y, button)
end

function DesktopState:handleWindowEvent(event, x, y, button)
    if event.type == "window_close" then
        local window = self.window_manager:getWindowById(event.window_id)
        if window then self.window_manager:rememberWindowPosition(window) end
        self.window_manager:closeWindow(event.window_id)
        self.window_states[event.window_id] = nil

    elseif event.type == "window_minimize" then
        self.window_manager:minimizeWindow(event.window_id)

    elseif event.type == "window_maximize" then
        self.window_manager:maximizeWindow(event.window_id, love.graphics.getWidth(), love.graphics.getHeight())

    elseif event.type == "window_restore" then
        self.window_manager:restoreWindow(event.window_id)

    elseif event.type == "window_drag_start" then
         -- Check for double-click on title bar
         local current_time = love.timer.getTime()
         if event.window_id == self.last_title_bar_click_id and current_time - self.last_title_bar_click_time < 0.5 then
             -- Double click detected! Maximize or Restore
             local window = self.window_manager:getWindowById(event.window_id)
             if window then
                 if window.is_maximized then
                     self.window_manager:restoreWindow(event.window_id)
                 else
                     -- Check if resizable before maximizing
                      local program = self.program_registry:getProgram(window.program_type)
                      local defaults = program and program.window_defaults or {}
                      if defaults.resizable ~= false then -- Maximize if resizable or not defined
                         self.window_manager:maximizeWindow(event.window_id, love.graphics.getWidth(), love.graphics.getHeight())
                      end
                 end
             end
             -- Reset double-click tracking
             self.last_title_bar_click_id = nil
             self.last_title_bar_click_time = 0
             -- Prevent drag from starting on double-click by clearing drag state in controller
             self.window_controller.dragging_window_id = nil
         else
             -- Single click, update tracking for potential double click
             self.last_title_bar_click_id = event.window_id
             self.last_title_bar_click_time = current_time
         end
         -- Drag start logic is otherwise handled by WindowController

    -- Handle events originating *from* window content (clicks, key signals)
    elseif event.type == "window_content_click" or event.type == "content_interaction" then
        local window_data = self.window_states[event.window_id]
        local window_state = window_data and window_data.state
        if window_state then
             local result = nil
             if event.type == "window_content_click" and window_state.mousepressed then
                 -- Pass local coordinates relative to content area
                 local window = self.window_manager:getWindowById(event.window_id)
                 if window then
                     local content_bounds = self.window_chrome:getContentBounds(window)
                     local local_x = x - content_bounds.x
                     local local_y = y - content_bounds.y
                     -- Only call if click is within content bounds
                     if local_x >= 0 and local_x <= content_bounds.width and local_y >= 0 and local_y <= content_bounds.height then
                         result = window_state:mousepressed(local_x, local_y, button)
                     end
                 end
             end

             if type(result) == 'table' then
                 if result.type == "close_window" then
                     local window = self.window_manager:getWindowById(event.window_id)
                     if window then self.window_manager:rememberWindowPosition(window) end
                     self.window_manager:closeWindow(event.window_id)
                     self.window_states[event.window_id] = nil
                 elseif result.type == "set_setting" then
                     if window_state.setSetting then
                         window_state:setSetting(result.id, result.value)
                     end
                 elseif result.type == "event" then
                     self:handleStateEvent(event.window_id, result)
                 end
             end
        end
        -- Reset title bar double click if content is clicked
        self.last_title_bar_click_id = nil
        self.last_title_bar_click_time = 0
    end
end


function DesktopState:keypressed(key)
    if self.show_tutorial then
        local event = self.tutorial_view:keypressed(key)
        if event and event.name == "dismiss_tutorial" then
            self:dismissTutorial()
        end
        return true -- Tutorial consumes keypresses
    end

    -- Forward keypress to focused window first
    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.keypressed then
            local result = window_state:keypressed(key)
            if type(result) == 'table' then
                 -- Handle signals from keypress (like close window on ESC)
                 if result.type == "close_window" then
                     local window = self.window_manager:getWindowById(focused_id)
                     if window then self.window_manager:rememberWindowPosition(window) end
                     self.window_manager:closeWindow(focused_id)
                     self.window_states[focused_id] = nil
                     return true -- Handled
                 elseif result.type == "event" then
                     -- Handle events signalled by states
                     self:handleStateEvent(focused_id, result)
                     return true -- Assumed handled
                 elseif result.type == "content_interaction" then
                      return true -- Key was handled by content logic
                 end
            elseif result == true then
                 -- Legacy boolean handling (treat as content interaction)
                return true -- Key was handled by the window state
            end
             -- If result was false or nil, key wasn't handled by window state, continue...
        end
    end

    -- If not handled by window, check desktop state shortcuts / modals
    if self.run_dialog_open then
        if key == "escape" then
            self.run_dialog_open = false; self.run_text = ""; return true
        elseif key == "return" then
            self:executeRunCommand(self.run_text); self.run_dialog_open = false; self.run_text = ""; return true
        elseif key == "backspace" then
            self.run_text = self.run_text:sub(1, -2); return true
        end
         -- Let textinput handle character entry
         return true -- Consume other keys while dialog open
    end

    if self.start_menu_open then
        if key == "escape" then self.start_menu_open = false; return true end
        -- Add arrow key navigation for start menu later if desired
        return true -- Consume keys while menu open
    end

    -- Global Desktop Shortcuts
    if (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) and key == 'r' then
        self.run_dialog_open = true; self.start_menu_open = false; return true
    end
    if key == 'f5' and self.state_machine then -- Debug key
        self.state_machine:switch('debug', 'desktop')
        return true
    end

    -- Remove global ESC to quit if any window is open
    if key == 'escape' and #self.window_manager:getAllWindows() == 0 then
        love.event.quit()
        return true
    elseif key == 'escape' then
         -- Do nothing if windows are open (handled by focused window or ignored)
         return true -- Consume ESC if windows are open but none handled it
    end


    return false -- Not handled by desktop or focused window
end

function DesktopState:textinput(text)
     -- Forward text input to focused window first
    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.textinput then
             if window_state:textinput(text) then
                 return -- Handled by window state
             end
        end
    end

    -- If not handled, check run dialog
    if self.run_dialog_open then
        self.run_text = self.run_text .. text
    end
end


function DesktopState:wheelmoved(x, y)
    -- Forward wheelmoved to focused window first
    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.wheelmoved then
             -- State's wheelmoved should check if mouse is within its bounds
            if window_state:wheelmoved(x, y) then
                return -- Handled by focused window
            end
        end
    end
    -- Could add logic for scrolling desktop background/icons if needed later
end

function DesktopState:handleStateEvent(window_id, event)
     -- Handle events signalled by states
     print("Received event from window " .. window_id .. ": " .. event.name)
     if event.name == "next_level" then
         -- Close current SD window
         local window = self.window_manager:getWindowById(window_id)
         if window then self.window_manager:rememberWindowPosition(window) end
         self.window_manager:closeWindow(window_id)
         self.window_states[window_id] = nil
         -- Launch SD again at the next level
         self:launchProgram("space_defender", event.level) -- Need to modify launchProgram to accept level arg

     elseif event.name == "show_completion" then
         -- Close the SD window
         local window = self.window_manager:getWindowById(window_id)
         if window then self.window_manager:rememberWindowPosition(window) end
         self.window_manager:closeWindow(window_id)
         self.window_states[window_id] = nil
         -- Switch to fullscreen completion state
         self.state_machine:switch('completion')
     end
     -- Add handlers for other events as needed
end


function DesktopState:executeRunCommand(command)
    command = command:gsub("^%s*(.-)%s*$", "%1"):lower() -- Trim and lower

    if command == "" then print("No command entered"); return end

    local program = self.program_registry:findByExecutable(command)
    if program then
        if not program.disabled then
            self:launchProgram(program.id)
        else
            love.window.showMessageBox("Error",
                "Cannot find '" .. command .. "'. Make sure the name is correct and try again.",
                "error")
        end
    else
        love.window.showMessageBox("Error",
            "Cannot find '" .. command .. "'. Make sure the name is correct and try again.",
            "error")
    end
end

function DesktopState:launchProgram(program_id, ...) -- Add varargs for level etc.
    local launch_args = {...}
    print("Attempting to launch program: " .. program_id)
    local program = self.program_registry:getProgram(program_id)
    if not program or program.disabled then
        print("Program not found or disabled: " .. program_id)
        return
    end

    local defaults = program.window_defaults or {}
    local single_instance = defaults.single_instance

    -- Check if single-instance program is already open
    if single_instance then
        local existing_id = self.window_manager:isProgramOpen(program_id)
        if existing_id then
            print(program.name .. " is already running. Focusing existing window.")
            self.window_manager:focusWindow(existing_id)
            return
        end
    end

    local StateClass = nil
    local state_args = {} -- Arguments for the state's init

    -- Determine which state class to load based on program_id
    -- Use pcall for safer requires
    local require_ok, loaded_class
    if program_id == "launcher" then
        require_ok, loaded_class = pcall(require, 'states.launcher_state')
        state_args = {self.player_data, self.game_data, self.state_machine, self.save_manager}
    elseif program_id == "vm_manager" then
        require_ok, loaded_class = pcall(require, 'states.vm_manager_state')
        state_args = {self.vm_manager, self.player_data, self.game_data, self.state_machine, self.save_manager}
    elseif program_id == "space_defender" then
        require_ok, loaded_class = pcall(require, 'states.space_defender_state')
        local level = launch_args[1] or 1 -- Get level from launch args or default to 1
        state_args = {self.player_data, self.game_data, self.state_machine, self.save_manager, self.statistics, level} -- Use self.statistics
    elseif program_id == "cheat_engine" then
        require_ok, loaded_class = pcall(require, 'states.cheat_engine_state')
        state_args = {self.player_data, self.game_data, self.state_machine, self.save_manager, self.cheat_system}
    elseif program_id == "settings" then
        require_ok, loaded_class = pcall(require, 'states.settings_state_windowed')
        state_args = {self.window_controller}
    elseif program_id == "statistics" then
        require_ok, loaded_class = pcall(require, 'states.statistics_state')
        state_args = {self.state_machine, self.statistics} -- Use self.statistics
    else
        print("No windowed state defined for program: " .. program_id)
        if program_id == 'debug' then self.state_machine:switch('debug', 'desktop'); return end
        if program_id == 'minigame' then print("Minigame launch should happen via Launcher window"); return end
        love.window.showMessageBox("Error", "Could not load program state for " .. program_id, "error")
        return
    end

     if not require_ok or not loaded_class then
          print("ERROR loading state class for " .. program_id .. ": " .. tostring(loaded_class))
          love.window.showMessageBox("Error", "Failed to load program components for " .. program_id, "error")
          return
     end
     StateClass = loaded_class

    -- Instantiate the state safely
    local instance_ok, new_state = pcall(StateClass.new, StateClass, unpack(state_args))
    if not instance_ok or not new_state then
         print("ERROR instantiating state for " .. program_id .. ": " .. tostring(new_state))
         love.window.showMessageBox("Error", "Failed to initialize program " .. program_id, "error")
         return
    end

    -- Create the window
    local screen_w, screen_h = love.graphics.getDimensions()
    local w = defaults.w or 600
    local h = defaults.h or 400
    -- Simple centering placement + slight random offset
    local x = math.max(20, (screen_w - w) / 2 + math.random(-50, 50))
    local y = math.max(20, (screen_h - h - (self.view and self.view.taskbar_height or 40)) / 2 + math.random(-50, 50)) -- Use view's taskbar height


    local window_id = self.window_manager:createWindow(
        program_id,
        program.name,
        new_state, -- Pass state instance itself
        x, y, w, h
    )

    -- Store the state instance associated with the window ID
    self.window_states[window_id] = { state = new_state } -- Store state under a key

     -- Maximize if preferred
    if defaults.prefer_maximized then
         self.window_manager:maximizeWindow(window_id, screen_w, screen_h)
    end

    print("Opened window for " .. program.name .. " with ID: " .. window_id)
    -- Ensure the new window gets focus immediately
    self.window_manager:focusWindow(window_id)
end


function DesktopState:dismissTutorial()
    self.show_tutorial = false
    SettingsManager.set("tutorial_shown", true)
    print("Tutorial dismissed.")
end

return DesktopState