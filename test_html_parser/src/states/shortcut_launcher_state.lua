-- src/states/shortcut_launcher_state.lua
-- A simple state that launches a file's default action and then immediately closes.

local Object = require('class')
local ShortcutLauncherState = Object:extend('ShortcutLauncherState')

function ShortcutLauncherState:init(file_system, di)
    self.file_system = file_system
    self.event_bus = di and di.eventBus
    self.window_id = nil
end

function ShortcutLauncherState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
end

function ShortcutLauncherState:enter(file_path)
    if not file_path then 
        self:_close()
        return
    end

    -- Use the file system to determine the correct action for this path
    local action = self.file_system:openItem(file_path)

    if action and self.event_bus then
        if action.type == "show_text" then
            -- For text files, publish the show_text event which DesktopState handles
            self.event_bus:publish('show_text', action.title, action.content)
        elseif action.type == "launch_program" then
            -- For other file types, this could launch the actual program
            self.event_bus:publish('launch_program', action.program_id, unpack(action.launch_args or {}))
        end
    end

    -- Immediately close the invisible launcher window
    self:_close()
end

function ShortcutLauncherState:_close()
    if self.window_id and self.event_bus then
        self.event_bus:publish('request_window_close', self.window_id)
    end
end

function ShortcutLauncherState:update(dt)
    -- Do nothing
end

function ShortcutLauncherState:draw()
    -- Draw nothing, it's an invisible launcher
end

return ShortcutLauncherState
