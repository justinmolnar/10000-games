-- desktop_state.lua: Main desktop environment state

local Object = require('class')
local DesktopState = Object:extend('DesktopState')

function DesktopState:init(context)
    self.context = context
    self.icons = {}
    self.wallpaper_color = {0, 0.5, 0.5}
    self.taskbar_height = 40
    self.clock_update_timer = 0
    self.current_time = ""
    
    -- Double-click tracking
    self.last_click_time = 0
    self.last_click_icon = nil
    self.hovered_icon = nil
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
    -- Update clock every second
    self.clock_update_timer = self.clock_update_timer + dt
    if self.clock_update_timer >= 1.0 then
        self:updateClock()
        self.clock_update_timer = 0
    end
    
    -- Update hovered icon
    local mx, my = love.mouse.getPosition()
    self.hovered_icon = self:getIconAtPosition(mx, my)
end

function DesktopState:updateClock()
    self.current_time = os.date("%H:%M")
end

function DesktopState:draw()
    local DesktopView = require('views.desktop_view')
    
    -- Draw wallpaper
    DesktopView.drawWallpaper(self.wallpaper_color)
    
    -- Draw desktop icons
    for i, icon in ipairs(self.icons) do
        DesktopView.drawIcon(icon, i == self.hovered_icon)
    end
    
    -- Draw taskbar
    DesktopView.drawTaskbar(self.taskbar_height, self.current_time, self.context.player_data.tokens)
end

function DesktopState:mousepressed(x, y, button)
    if button ~= 1 then return end
    
    -- Check if clicking taskbar (ignore for MVP)
    if y >= love.graphics.getHeight() - self.taskbar_height then
        return
    end
    
    -- Check desktop icons
    local clicked_icon = self:getIconAtPosition(x, y)
    if clicked_icon then
        local icon = self.icons[clicked_icon]
        
        -- Check if disabled
        if icon.disabled then
            print(icon.name .. " is not available in MVP")
            return
        end
        
        -- Check for double-click
        local is_double_click = (self.last_click_icon == clicked_icon and 
                                love.timer.getTime() - self.last_click_time < 0.5)
        
        if is_double_click then
            -- Launch program
            self:launchProgram(icon.program)
        end
        
        -- Update double-click tracking
        self.last_click_icon = clicked_icon
        self.last_click_time = love.timer.getTime()
    end
end

function DesktopState:getIconAtPosition(x, y)
    for i, icon in ipairs(self.icons) do
        if x >= icon.x and x <= icon.x + icon.width and
           y >= icon.y and y <= icon.y + icon.height then
            return i
        end
    end
    return nil
end

function DesktopState:launchProgram(program_name)
    if program_name == "launcher" then
        self.context.state_machine:switch('launcher')
    elseif program_name == "vm_manager" then
        self.context.state_machine:switch('vm_manager')
    elseif program_name == "space_defender" then
        self.context.state_machine:switch('space_defender', 1)
    elseif program_name == "recycle_bin" then
        print("Recycle Bin not implemented in MVP")
    else
        print("Unknown program: " .. program_name)
    end
end

function DesktopState:keypressed(key)
    if key == 'escape' then
        love.event.quit()
    end
end

return DesktopState