-- src/controllers/taskbar_controller.lua
-- Controller for the taskbar

local Object = require('class')
local TaskbarView = require('src.views.taskbar_view')

local TaskbarController = Object:extend('TaskbarController')

function TaskbarController:init(di)
    self.di = di or {}

    -- Dependencies
    self.window_manager = di.windowManager
    self.player_data = di.playerData
    self.start_menu_state = di.startMenuState
    self.event_bus = di.eventBus

    -- View
    self.view = TaskbarView:new(di)

    -- State
    self.start_button_hovered = false
    self.hovered_taskbar_button_id = nil
    self.current_time = "12:00 PM"
end

function TaskbarController:update(dt)
    -- Update clock
    self:updateClock()

    -- Update hover states
    local mx, my = love.mouse.getPosition()
    self.start_button_hovered = self.view:isStartButtonHovered(mx, my)
    self.hovered_taskbar_button_id = self.view:getTaskbarButtonAtPosition(mx, my)

    -- Pass state to view
    self.view:update(dt, mx, my, self.start_button_hovered, self.hovered_taskbar_button_id, self.current_time)
end

function TaskbarController:draw()
    local tokens = self.player_data and self.player_data.tokens or 0
    local windows = self.window_manager:getWindowsInCreationOrder()
    local focused_window_id = self.window_manager:getFocusedWindowId()
    local start_menu_open = self.start_menu_state and self.start_menu_state:isOpen() or false

    self.view:draw(tokens, windows, focused_window_id, start_menu_open)
end

function TaskbarController:mousepressed(x, y, button)
    if button ~= 1 then return false end

    -- Check Start Button
    if self.view:isStartButtonHovered(x, y) then
        if self.start_menu_state then
            self.start_menu_state:onStartButtonPressed()
        end
        return true
    end

    -- Check taskbar window buttons
    local clicked_window_id = self.view:getTaskbarButtonAtPosition(x, y)
    if clicked_window_id then
        local window = self.window_manager:getWindowById(clicked_window_id)
        if window and self.event_bus then
            local focused_id = self.window_manager:getFocusedWindowId()
            if window.is_minimized then
                -- Restore and focus minimized window
                self.event_bus:publish('request_window_restore', clicked_window_id)
                self.event_bus:publish('request_window_focus', clicked_window_id)
            elseif window.id == focused_id then
                -- Minimize already focused window
                self.event_bus:publish('request_window_minimize', clicked_window_id)
            else
                -- Focus unfocused window
                self.event_bus:publish('request_window_focus', clicked_window_id)
            end
        end
        return true
    end

    return false
end

function TaskbarController:updateClock()
    local time_str = os.date("%I:%M %p")
    self.current_time = time_str
end

return TaskbarController
