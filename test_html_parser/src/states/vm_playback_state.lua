-- src/states/vm_playback_state.lua: State for live VM playback visualization

local Object = require('class')
local VMPlaybackView = require('src.views.vm_playback_view')
local VMPlaybackState = Object:extend('VMPlaybackState')

function VMPlaybackState:init(vm_manager, player_data, game_data, di)
    print("[VMPlaybackState] init() called")
    self.vm_manager = vm_manager
    self.player_data = player_data
    self.game_data = game_data
    self.di = di

    self.view = VMPlaybackView:new(di)
    self.view:setController(self)

    self.viewport = nil
    self.window_id = nil
    self.window_manager = nil

    -- Which VM slot are we watching?
    self.slot_index = nil
    self.vm_slot = nil

    print("[VMPlaybackState] init() completed")
end

function VMPlaybackState:setViewport(x, y, width, height)
    self.viewport = { x = x, y = y, width = width, height = height }
end

function VMPlaybackState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

function VMPlaybackState:enter(slot_index)
    print("[VMPlaybackState] enter() called for VM slot:", slot_index)

    if not slot_index or slot_index < 1 or slot_index > #self.vm_manager.vm_slots then
        print("[VMPlaybackState] ERROR: Invalid slot_index:", slot_index)
        return { type = "close_window" }
    end

    self.slot_index = slot_index
    self.vm_slot = self.vm_manager:getSlot(slot_index)

    if not self.vm_slot then
        print("[VMPlaybackState] ERROR: Slot not found:", slot_index)
        return { type = "close_window" }
    end

    -- Update window title to show which VM we're watching
    if self.window_manager and self.window_id then
        local window = self.window_manager:getWindowById(self.window_id)
        if window then
            local game_name = "Unknown"
            if self.vm_slot.assigned_game_id then
                local game = self.game_data:getGame(self.vm_slot.assigned_game_id)
                if game then
                    game_name = game.display_name
                end
            end
            window.title = "VM " .. slot_index .. " - " .. game_name
        end
    end

    print("[VMPlaybackState] Watching VM slot " .. slot_index)
end

function VMPlaybackState:exit()
    print("[VMPlaybackState] exit() called")
    -- Don't stop the VM - just close the window
    self.vm_slot = nil
    self.slot_index = nil
end

function VMPlaybackState:update(dt)
    -- Refresh VM slot reference (in case it changed)
    if self.slot_index then
        self.vm_slot = self.vm_manager:getSlot(self.slot_index)
    end

    -- If VM slot is idle or removed, close window
    if not self.vm_slot or self.vm_slot.state == "IDLE" then
        print("[VMPlaybackState] VM slot is idle or removed, closing playback window")
        return { type = "close_window" }
    end
end

function VMPlaybackState:draw()
    if not self.viewport then
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("ERROR: No viewport set", 10, 10)
        return
    end

    -- Transform to viewport coordinates (window content area)
    love.graphics.push()
    love.graphics.translate(self.viewport.x, self.viewport.y)

    -- Draw via view
    self.view:drawWindowed(self.viewport.width, self.viewport.height)

    love.graphics.pop()
end

function VMPlaybackState:keypressed(key, scancode, isrepeat)
    -- ESC closes the window
    if key == 'escape' then
        return { type = "close_window" }
    end

    return false
end

function VMPlaybackState:mousepressed(x, y, button, istouch, presses)
    -- No interactive elements in playback window (read-only)
    return false
end

function VMPlaybackState:mousereleased(x, y, button, istouch, presses)
    return false
end

function VMPlaybackState:wheelmoved(x, y)
    return false
end

return VMPlaybackState
