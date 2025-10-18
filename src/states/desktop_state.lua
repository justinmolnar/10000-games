-- src/states/desktop_state.lua: Main desktop environment state

local Object = require('class')
local DesktopView = require('views.desktop_view')
local DesktopState = Object:extend('DesktopState')

function DesktopState:init(state_machine, player_data)
    self.state_machine = state_machine
    self.player_data = player_data
    
    -- Create the view instance
    self.view = DesktopView:new(self, player_data)
    
    self.icons = {}
    self.wallpaper_color = {0, 0.5, 0.5}
    
    -- Double-click tracking
    self.last_click_time = 0
    self.last_click_icon = nil
end

function DesktopState:enter()
    -- Create desktop icons
    self.icons = {
        {
            name = "Game Collection",
            x = 20,
            y = 20,
            width = 80,
            height = 100,
            icon_color = {1, 0.8, 0},
            program = "launcher"
        },
        {
            name = "VM Manager",
            x = 120,
            y = 20,
            width = 80,
            height = 100,
            icon_color = {0.5, 0.5, 1},
            program = "vm_manager"
        },
        {
            name = "Space Defender",
            x = 220,
            y = 20,
            width = 80,
            height = 100,
            icon_color = {1, 0, 0},
            program = "space_defender"
        },
        {
            name = "CheatEngine",
            x = 320,
            y = 20,
            width = 80,
            height = 100,
            icon_color = {0.1, 0.8, 0.1},
            program = "cheat_engine"
        },
        {
            name = "Recycle Bin",
            x = 20,
            y = 140,
            width = 80,
            height = 100,
            icon_color = {0.6, 0.6, 0.6},
            program = "recycle_bin",
            disabled = true
        }
    }
    
    -- Update clock
    self:updateClock()
    
    print("Desktop loaded")
end

function DesktopState:update(dt)
    -- Delegate clock updates and hover checks to the view
    self.view:update(dt, self.icons)
end

function DesktopState:updateClock()
    self.current_time = os.date("%H:%M")
end

function DesktopState:draw()
    -- Delegate all drawing to the view
    self.view:draw(self.icons, self.wallpaper_color, self.player_data.tokens)
end

function DesktopState:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Get click event from the view
    local event = self.view:mousepressed(x, y, button, self.icons)
    
    if not event then return end

    if event.name == "icon_click" then
        local icon = self.icons[event.icon_index]
        
        if icon.disabled then
            print(icon.name .. " is not available in MVP")
            return
        end
        
        -- Check for double-click
        local is_double_click = (self.last_click_icon == event.icon_index and 
                                love.timer.getTime() - self.last_click_time < 0.5)
        
        if is_double_click then
            self:launchProgram(icon.program)
        end
        
        self.last_click_icon = event.icon_index
        self.last_click_time = love.timer.getTime()
    end
end

function DesktopState:launchProgram(program_name)
    if program_name == "launcher" then
        self.state_machine:switch('launcher')
    elseif program_name == "vm_manager" then
        self.state_machine:switch('vm_manager')
    elseif program_name == "space_defender" then
        self.state_machine:switch('space_defender', 1)
    elseif program_name == "cheat_engine" then
        self.state_machine:switch('cheat_engine')
    elseif program_name == "recycle_bin" then
        print("Recycle Bin not implemented in MVP")
    else
        print("Unknown program: " .. program_name)
    end
end

function DesktopState:keypressed(key)
    if key == 'escape' then
        love.event.quit()
        return true -- Indicate the key was handled
    end
    return false -- Indicate the key was not handled
end

return DesktopState