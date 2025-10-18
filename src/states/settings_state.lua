-- src/states/settings_state.lua
local Object = require('class')
local SettingsView = require('src.views.settings_view')
local SettingsManager = require('src.utils.settings_manager') -- Require the manager

local SettingsState = Object:extend('SettingsState')

function SettingsState:init(state_machine)
    self.state_machine = state_machine
    self.view = SettingsView:new(self)
    self.current_settings = {}
end

function SettingsState:enter()
    print("Entered Settings Menu")
    self.current_settings = SettingsManager.getAll()
end

function SettingsState:update(dt)
    self.view:update(dt, self.current_settings)
end

function SettingsState:draw()
    -- Draw desktop underneath? Or just the settings UI? Just UI for MVP.
    self.view:draw(self.current_settings)
end

function SettingsState:keypressed(key)
    if key == 'escape' then
        self:goBack()
        return true
    end
    return false
end

function SettingsState:mousepressed(x, y, button)
    local event = self.view:mousepressed(x, y, button)
    if not event then return end

    if event.name == "set_setting" then
        self:setSetting(event.id, event.value)
    elseif event.name == "button_click" then
        if event.id == "back" then
            self:goBack()
        end
    end
    return true -- Handled input
end

function SettingsState:mousereleased(x, y, button)
    -- Forward to view to handle stopping slider drag
    if self.view.mousereleased then
        self.view:mousereleased(x, y, button)
    end
end

-- Method for view to call to update a setting
function SettingsState:setSetting(key, value)
    SettingsManager.set(key, value)
    self.current_settings = SettingsManager.getAll() -- Refresh local copy
end

-- Method for view to get a setting (used for toggle)
function SettingsState:getSetting(key)
    return SettingsManager.get(key)
end


function SettingsState:goBack()
    -- SettingsManager.save() -- Saving happens automatically on set
    self.state_machine:switch('desktop') -- Assume we always come from desktop for MVP
end

return SettingsState