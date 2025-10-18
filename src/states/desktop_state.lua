local Object = require('class')
local DesktopView = require('views.desktop_view')
local SettingsManager = require('src.utils.settings_manager')
local TutorialView = require('src.views.tutorial_view')
local ProgramRegistry = require('models.program_registry')

local DesktopState = Object:extend('DesktopState')

-- Dependency injection: pass only what's needed
function DesktopState:init(state_machine, player_data, show_tutorial_on_startup, statistics)
    self.state_machine = state_machine
    self.player_data = player_data
    self.statistics = statistics
    
    -- Load program registry (model)
    self.program_registry = ProgramRegistry:new()
    
    -- Create view, inject dependencies
    self.view = DesktopView:new(self.program_registry, player_data)
    self.tutorial_view = TutorialView:new(self)
    
    self.wallpaper_color = {0, 0.5, 0.5}
    self.show_tutorial = show_tutorial_on_startup or false
    
    -- UI state
    self.start_menu_open = false
    self.run_dialog_open = false
    self.run_text = ""
    
    -- Click tracking for double-click detection
    self.last_click_time = 0
    self.last_click_program_id = nil
end

function DesktopState:enter()
    self:updateClock()
    print("Desktop loaded. Tutorial active: " .. tostring(self.show_tutorial))
end

function DesktopState:update(dt)
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
    
    if self.show_tutorial then
        self.tutorial_view:draw()
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
    
    -- Run dialog has priority
    if self.run_dialog_open then
        local event = self.view:mousepressedRunDialog(x, y, button)
        if event then
            if event.name == "run_execute" then
                self:executeRunCommand(self.run_text)
                self.run_dialog_open = false
                self.run_text = ""
            elseif event.name == "run_cancel" then
                self.run_dialog_open = false
                self.run_text = ""
            end
        end
        return
    end
    
    -- Start menu has priority
    if self.start_menu_open then
        local event = self.view:mousepressedStartMenu(x, y, button)
        if event then
            if event.name == "launch_program" then
                self:launchProgram(event.program_id)
                self.start_menu_open = false
            elseif event.name == "open_run" then
                self.run_dialog_open = true
                self.start_menu_open = false
            elseif event.name == "close_start_menu" then
                self.start_menu_open = false
            end
        else
            -- Clicked outside
            self.start_menu_open = false
        end
        return
    end
    
    -- Desktop/taskbar input
    local event = self.view:mousepressed(x, y, button)
    if not event then return end
    
    if event.name == "start_button_click" then
        self.start_menu_open = not self.start_menu_open
        
    elseif event.name == "icon_click" then
        local program = self.program_registry:getProgram(event.program_id)
        if not program then return end
        
        if program.disabled then
            print(program.name .. " is not available in MVP")
            return
        end
        
        -- Double-click detection
        local is_double_click = (self.last_click_program_id == event.program_id and
                                love.timer.getTime() - self.last_click_time < 0.5)
        
        if is_double_click then
            self:launchProgram(event.program_id)
        end
        
        self.last_click_program_id = event.program_id
        self.last_click_time = love.timer.getTime()
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
    
    -- Run dialog text input
    if self.run_dialog_open then
        if key == "escape" then
            self.run_dialog_open = false
            self.run_text = ""
            return true
        elseif key == "return" then
            self:executeRunCommand(self.run_text)
            self.run_dialog_open = false
            self.run_text = ""
            return true
        elseif key == "backspace" then
            self.run_text = self.run_text:sub(1, -2)
            return true
        end
        return true
    end
    
    -- Close start menu
    if self.start_menu_open then
        if key == "escape" then
            self.start_menu_open = false
            return true
        end
        return true
    end
    
    -- Global shortcuts
    if love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
        if key == 'r' then
            self.run_dialog_open = true
            self.start_menu_open = false
            return true
        end
    end
    
    -- Desktop escape = quit
    if key == 'escape' then
        love.event.quit()
        return true
    end
    
    return false
end

function DesktopState:textinput(text)
    if self.run_dialog_open then
        self.run_text = self.run_text .. text
    end
end

function DesktopState:executeRunCommand(command)
    -- Don't strip spaces or change case - require exact match
    command = command:gsub("^%s*(.-)%s*$", "%1") -- Only trim leading/trailing whitespace
    
    if command == "" then
        print("No command entered")
        return
    end
    
    local program = self.program_registry:findByExecutable(command)
    if program then
        if not program.disabled then
            self:launchProgram(program.id)
        else
            -- Show error message box for disabled programs
            love.window.showMessageBox("Error", 
                "Cannot find '" .. command .. "'. Make sure the name is correct and try again.", 
                "error")
        end
    else
        -- Show "file not found" error
        love.window.showMessageBox("Error", 
            "Cannot find '" .. command .. "'. Make sure the name is correct and try again.", 
            "error")
    end
end

function DesktopState:launchProgram(program_id)
    -- Controller logic: map program IDs to state transitions
    if program_id == "launcher" then
        self.state_machine:switch('launcher')
    elseif program_id == "vm_manager" then
        self.state_machine:switch('vm_manager')
    elseif program_id == "space_defender" then
        self.state_machine:switch('space_defender', 1)
    elseif program_id == "cheat_engine" then
        self.state_machine:switch('cheat_engine')
    elseif program_id == "settings" then
        self.state_machine:switch('settings')
    elseif program_id == "statistics" then
        self.state_machine:switch('statistics', 'desktop')
    elseif program_id == "recycle_bin" then
        print("Recycle Bin not implemented")
    elseif program_id == "my_computer" then
        print("My Computer not implemented")
    elseif program_id == "notepad" then
        print("Notepad not implemented")
    elseif program_id == "paint" then
        print("Paint not implemented")
    else
        print("Unknown program: " .. program_id)
    end
end

function DesktopState:dismissTutorial()
    self.show_tutorial = false
    SettingsManager.set("tutorial_shown", true)
    print("Tutorial dismissed.")
end

return DesktopState