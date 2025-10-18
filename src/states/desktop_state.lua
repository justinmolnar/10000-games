-- src/states/desktop_state.lua: Main desktop environment state

local Object = require('class')
local DesktopView = require('views.desktop_view')
local SettingsManager = require('src.utils.settings_manager') -- Need manager for tutorial flag
local TutorialView = require('src.views.tutorial_view') -- Require tutorial view

local DesktopState = Object:extend('DesktopState')

-- Accept stats model for launchProgram and initial tutorial flag
function DesktopState:init(state_machine, player_data, show_tutorial_on_startup, statistics)
    self.state_machine = state_machine
    self.player_data = player_data
    self.statistics = statistics -- Store statistics model
    self.view = DesktopView:new(self, player_data)
    self.tutorial_view = TutorialView:new(self) -- Instantiate tutorial view
    self.icons = {}
    self.wallpaper_color = {0, 0.5, 0.5}
    self.last_click_time = 0
    self.last_click_icon = nil
    -- Set the flag based on the value passed from love.load
    self.show_tutorial = show_tutorial_on_startup or false
end

function DesktopState:enter()
    -- Create desktop icons (Full list including Statistics)
    self.icons = {
        { name = "Game Collection", x = 20, y = 20, width = 80, height = 100, icon_color = {1, 0.8, 0}, program = "launcher" },
        { name = "VM Manager", x = 120, y = 20, width = 80, height = 100, icon_color = {0.5, 0.5, 1}, program = "vm_manager" },
        { name = "Space Defender", x = 220, y = 20, width = 80, height = 100, icon_color = {1, 0, 0}, program = "space_defender" },
        { name = "CheatEngine", x = 320, y = 20, width = 80, height = 100, icon_color = {0.1, 0.8, 0.1}, program = "cheat_engine" },
        { name = "Settings", x = 420, y = 20, width = 80, height = 100, icon_color = {0.8, 0.8, 0.8}, program = "settings" },
        { name = "Statistics", x = 520, y = 20, width = 80, height = 100, icon_color = {1, 1, 0.5}, program = "statistics" }, -- Added Stats Icon
        { name = "Recycle Bin", x = 20, y = 140, width = 80, height = 100, icon_color = {0.6, 0.6, 0.6}, program = "recycle_bin", disabled = true }
    }

    self:updateClock()

    -- Use the flag set in init (No longer check SettingsManager here)
    print("Desktop loaded. Tutorial active: " .. tostring(self.show_tutorial))
end

function DesktopState:update(dt)
    -- Don't update desktop view if tutorial is showing
    if self.show_tutorial then
        self.tutorial_view:update(dt)
    else
        self.view:update(dt, self.icons)
    end
end

function DesktopState:updateClock()
    self.current_time = os.date("%H:%M")
end

function DesktopState:draw()
    -- Delegate desktop drawing to the view
    self.view:draw(self.icons, self.wallpaper_color, self.player_data.tokens)

    -- Draw tutorial overlay if active
    if self.show_tutorial then
        self.tutorial_view:draw()
    end
end

function DesktopState:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- If tutorial is showing, it handles input
    if self.show_tutorial then
        local event = self.tutorial_view:mousepressed(x, y, button)
        if event and event.name == "dismiss_tutorial" then
            self:dismissTutorial()
        end
        return -- Tutorial consumes input
    end

    -- Otherwise, handle desktop input
    local event = self.view:mousepressed(x, y, button, self.icons)
    if not event then return end

    if event.name == "icon_click" then
        local icon = self.icons[event.icon_index]
        if icon.disabled then
            print(icon.name .. " is not available in MVP")
            return
        end

        local is_double_click = (self.last_click_icon == event.icon_index and
                                love.timer.getTime() - self.last_click_time < 0.5)

        if is_double_click then
            self:launchProgram(icon.program)
        end

        self.last_click_icon = event.icon_index
        self.last_click_time = love.timer.getTime()
    end
end

function DesktopState:keypressed(key)
    -- If tutorial is showing, it handles input
    if self.show_tutorial then
        local event = self.tutorial_view:keypressed(key)
        if event and event.name == "dismiss_tutorial" then
            self:dismissTutorial()
        end
        return true -- Tutorial consumes input
    end

    -- Otherwise, handle desktop input
    if key == 'escape' then
        love.event.quit()
        return true -- Indicate the key was handled
    end
    return false -- Indicate the key was not handled
end

-- Full launchProgram function
function DesktopState:launchProgram(program_name)
    if program_name == "launcher" then self.state_machine:switch('launcher')
    elseif program_name == "vm_manager" then self.state_machine:switch('vm_manager')
    elseif program_name == "space_defender" then self.state_machine:switch('space_defender', 1)
    elseif program_name == "cheat_engine" then self.state_machine:switch('cheat_engine')
    elseif program_name == "settings" then self.state_machine:switch('settings')
    elseif program_name == "statistics" then self.state_machine:switch('statistics', 'desktop') -- Launch stats, return to desktop
    elseif program_name == "recycle_bin" then print("Recycle Bin not implemented")
    else print("Unknown program: " .. program_name) end
end

-- dismissTutorial function
function DesktopState:dismissTutorial()
    -- Only dismiss visually for this session
    self.show_tutorial = false
    -- Set the flag so it doesn't show *next* time love.load runs
    SettingsManager.set("tutorial_shown", true)
    print("Tutorial dismissed.")
end

return DesktopState