local Object = require('class')
local DesktopView = require('views.desktop_view')
local SettingsManager = require('src.utils.settings_manager')
local TutorialView = require('src.views.tutorial_view')
local WindowChrome = require('src.views.window_chrome')
local WindowController = require('src.controllers.window_controller')

local DesktopState = Object:extend('DesktopState')

function DesktopState:init(state_machine, player_data, show_tutorial_on_startup, statistics,
                           window_manager, desktop_icons, file_system, recycle_bin, program_registry,
                           vm_manager_dep, cheat_system_dep, save_manager_dep, game_data_dep)

    self.state_machine = state_machine
    self.player_data = player_data
    self.statistics = statistics
    self.window_manager = window_manager
    self.desktop_icons = desktop_icons
    self.file_system = file_system
    self.recycle_bin = recycle_bin
    self.program_registry = program_registry
    self.vm_manager = vm_manager_dep
    self.cheat_system = cheat_system_dep
    self.save_manager = save_manager_dep
    self.game_data = game_data_dep

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
    self.last_title_bar_click_time = 0
    self.last_title_bar_click_id = nil
    self.last_click_program_id = nil
    self.last_click_time = 0
end

function DesktopState:enter()
    self:updateClock()
    print("Desktop loaded. Tutorial active: " .. tostring(self.show_tutorial))
    self.view:calculateIconPositions()
end

function DesktopState:update(dt)
    self.window_controller:update(dt)

    for window_id, window_data in pairs(self.window_states) do
        if window_data.state and window_data.state.update then
            window_data.state:update(dt)
        end
    end

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

    self.window_chrome:draw(window, is_focused)

    local window_data = self.window_states[window.id]
    local window_state = window_data and window_data.state

    if window_state and window_state.draw then
        local content_bounds = self.window_chrome:getContentBounds(window)
        if window_state.setViewport then
             window_state:setViewport(content_bounds.x, content_bounds.y,
                                      content_bounds.width, content_bounds.height)
        end
        window_state:draw()
    end
end

function DesktopState:mousepressed(x, y, button)
    if button ~= 1 then return end

    if self.show_tutorial then
        local event = self.tutorial_view:mousepressed(x, y, button)
        if event and event.name == "dismiss_tutorial" then
            self:dismissTutorial()
        end
        return
    end

    local window_event = self.window_controller:mousepressed(x, y, button, self.window_chrome)
    if window_event then
        self:handleWindowEvent(window_event, x, y, button)
        self.start_menu_open = false
        return
    end

    local taskbar_button_id = self.view:getTaskbarButtonAtPosition(x, y)
    if taskbar_button_id then
        local window = self.window_manager:getWindowById(taskbar_button_id)
        if window then
            local focused_id = self.window_manager:getFocusedWindowId()
            if window.is_minimized then
                self.window_manager:restoreWindow(taskbar_button_id)
                self.window_manager:focusWindow(taskbar_button_id)
            elseif window.id == focused_id then
                self.window_manager:minimizeWindow(taskbar_button_id)
            else
                self.window_manager:focusWindow(taskbar_button_id)
            end
        end
        self.start_menu_open = false
        return
    end

    if self.view:isStartButtonHovered(x, y) then
         self.start_menu_open = not self.start_menu_open
    else
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
                return
            else
                 self.start_menu_open = false
            end
        end

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
            return
        end

        local icon_event = self.view:mousepressed(x, y, button)
        if icon_event and icon_event.name == "icon_click" then
            local program = self.program_registry:getProgram(icon_event.program_id)
            if program and not program.disabled then
                local is_double_click = (self.last_click_program_id == icon_event.program_id and
                                        love.timer.getTime() - self.last_click_time < 0.5)
                if is_double_click then
                    self:launchProgram(icon_event.program_id)
                    self.last_click_program_id = nil
                    self.last_click_time = 0
                else
                    self.last_click_program_id = icon_event.program_id
                    self.last_click_time = love.timer.getTime()
                end

            elseif program and program.disabled then
                 print(program.name .. " is not available in MVP")
                 love.window.showMessageBox("Not Available", program.name .. " is planned for a future update!", "info")
                 self.last_click_program_id = nil
                 self.last_click_time = 0
            end
            return
        end
    end

    if not self.view:isStartButtonHovered(x, y) then
         self.start_menu_open = false
    end
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
         local current_time = love.timer.getTime()
         if event.window_id == self.last_title_bar_click_id and current_time - self.last_title_bar_click_time < 0.5 then
             local window = self.window_manager:getWindowById(event.window_id)
             if window then
                 if window.is_maximized then
                     self.window_manager:restoreWindow(event.window_id)
                 else
                      local program = self.program_registry:getProgram(window.program_type)
                      local defaults = program and program.window_defaults or {}
                      if defaults.resizable ~= false then
                         self.window_manager:maximizeWindow(event.window_id, love.graphics.getWidth(), love.graphics.getHeight())
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

    elseif event.type == "window_content_click" or event.type == "content_interaction" then
        local window_data = self.window_states[event.window_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.mousepressed then
             local result = nil
             local window = self.window_manager:getWindowById(event.window_id)
             if window then
                 local content_bounds = self.window_chrome:getContentBounds(window)
                 local local_x = x - content_bounds.x
                 local local_y = y - content_bounds.y
                 
                 if local_x >= 0 and local_x <= content_bounds.width and 
                    local_y >= 0 and local_y <= content_bounds.height then
                     result = window_state:mousepressed(local_x, local_y, button)
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
        return true
    end

    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.keypressed then
            local result = window_state:keypressed(key)
            if type(result) == 'table' then
                 if result.type == "close_window" then
                     local window = self.window_manager:getWindowById(focused_id)
                     if window then self.window_manager:rememberWindowPosition(window) end
                     self.window_manager:closeWindow(focused_id)
                     self.window_states[focused_id] = nil
                     return true
                 elseif result.type == "event" then
                     self:handleStateEvent(focused_id, result)
                     return true
                 elseif result.type == "content_interaction" then
                      return true
                 end
            elseif result == true then
                return true
            end
        end
    end

    if self.run_dialog_open then
        if key == "escape" then
            self.run_dialog_open = false; self.run_text = ""; return true
        elseif key == "return" then
            self:executeRunCommand(self.run_text); self.run_dialog_open = false; self.run_text = ""; return true
        elseif key == "backspace" then
            self.run_text = self.run_text:sub(1, -2); return true
        end
         return true
    end

    if self.start_menu_open then
        if key == "escape" then self.start_menu_open = false; return true end
        return true
    end

    if (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) and key == 'r' then
        self.run_dialog_open = true; self.start_menu_open = false; return true
    end
    
    if key == 'f5' and self.state_machine then
        self.state_machine:switch('debug', 'desktop')
        return true
    end
    
    if key == 'f1' then
        self:launchProgram('launcher')
        return true
    elseif key == 'f2' then
        self:launchProgram('vm_manager')
        return true
    elseif key == 'f3' then
        self:launchProgram('space_defender')
        return true
    elseif key == 'f4' then
        self:launchProgram('cheat_engine')
        return true
    end

    if key == 'escape' and #self.window_manager:getAllWindows() == 0 then
        love.event.quit()
        return true
    elseif key == 'escape' then
         return true
    end

    return false
end

function DesktopState:textinput(text)
     local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.textinput then
             if window_state:textinput(text) then
                 return
             end
        end
    end

    if self.run_dialog_open then
        self.run_text = self.run_text .. text
    end
end

function DesktopState:wheelmoved(x, y)
    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.wheelmoved then
            if window_state:wheelmoved(x, y) then
                return
            end
        end
    end
end

function DesktopState:handleStateEvent(window_id, event)
     print("Received event from window " .. window_id .. ": " .. event.name)
     if event.name == "next_level" then
         local window = self.window_manager:getWindowById(window_id)
         if window then self.window_manager:rememberWindowPosition(window) end
         self.window_manager:closeWindow(window_id)
         self.window_states[window_id] = nil
         self:launchProgram("space_defender", event.level)

     elseif event.name == "show_completion" then
         local window = self.window_manager:getWindowById(window_id)
         if window then self.window_manager:rememberWindowPosition(window) end
         self.window_manager:closeWindow(window_id)
         self.window_states[window_id] = nil
         self.state_machine:switch('completion')
     end
end

function DesktopState:executeRunCommand(command)
    command = command:gsub("^%s*(.-)%s*$", "%1"):lower()

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

function DesktopState:launchProgram(program_id, ...)
    local launch_args = {...}
    print("Attempting to launch program: " .. program_id)
    local program = self.program_registry:getProgram(program_id)
    if not program or program.disabled then
        print("Program not found or disabled: " .. program_id)
        return
    end

    local defaults = program.window_defaults or {}
    local single_instance = defaults.single_instance

    if single_instance then
        local existing_id = self.window_manager:isProgramOpen(program_id)
        if existing_id then
            print(program.name .. " is already running. Focusing existing window.")
            self.window_manager:focusWindow(existing_id)
            return
        end
    end

    local StateClass = nil
    local state_args = {}

    local require_ok, loaded_class
    if program_id == "launcher" then
        require_ok, loaded_class = pcall(require, 'states.launcher_state')
        state_args = {self.player_data, self.game_data, self.state_machine, self.save_manager}
    elseif program_id == "vm_manager" then
        require_ok, loaded_class = pcall(require, 'states.vm_manager_state')
        state_args = {self.vm_manager, self.player_data, self.game_data, self.state_machine, self.save_manager}
    elseif program_id == "space_defender" then
        require_ok, loaded_class = pcall(require, 'states.space_defender_state')
        local level = launch_args[1] or 1
        state_args = {self.player_data, self.game_data, self.state_machine, self.save_manager, self.statistics, level}
    elseif program_id == "cheat_engine" then
        require_ok, loaded_class = pcall(require, 'states.cheat_engine_state')
        state_args = {self.player_data, self.game_data, self.state_machine, self.save_manager, self.cheat_system}
    elseif program_id == "settings" then
        require_ok, loaded_class = pcall(require, 'states.settings_state')
        state_args = {self.window_controller}
    elseif program_id == "statistics" then
        require_ok, loaded_class = pcall(require, 'states.statistics_state')
        state_args = {self.state_machine, self.statistics}
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

    local instance_ok, new_state = pcall(StateClass.new, StateClass, unpack(state_args))
    if not instance_ok or not new_state then
         print("ERROR instantiating state for " .. program_id .. ": " .. tostring(new_state))
         love.window.showMessageBox("Error", "Failed to initialize program " .. program_id, "error")
         return
    end

    local screen_w, screen_h = love.graphics.getDimensions()
    local w = defaults.w or 600
    local h = defaults.h or 400
    local x = math.max(20, (screen_w - w) / 2 + math.random(-50, 50))
    local y = math.max(20, (screen_h - h - (self.view and self.view.taskbar_height or 40)) / 2 + math.random(-50, 50))

    local window_id = self.window_manager:createWindow(
        program_id,
        program.name,
        new_state,
        x, y, w, h
    )

    self.window_states[window_id] = { state = new_state }

    if new_state.enter then
        if program_id == "space_defender" then
            new_state:enter(launch_args[1] or 1)
        elseif program_id == "launcher" or program_id == "cheat_engine" or program_id == "vm_manager" then
            new_state:enter()
        elseif program_id == "settings" or program_id == "statistics" then
            new_state:enter()
        end
    end

    if defaults.prefer_maximized then
         self.window_manager:maximizeWindow(window_id, screen_w, screen_h)
    end

    print("Opened window for " .. program.name .. " with ID: " .. window_id)
    self.window_manager:focusWindow(window_id)
end

function DesktopState:dismissTutorial()
    self.show_tutorial = false
    SettingsManager.set("tutorial_shown", true)
    print("Tutorial dismissed.")
end

return DesktopState