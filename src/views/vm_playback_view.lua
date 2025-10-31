-- src/views/vm_playback_view.lua: View for live VM playback visualization

local Object = require('class')
local Strings = require('src.utils.strings')
local VMPlaybackView = Object:extend('VMPlaybackView')

function VMPlaybackView:init(di)
    self.di = di
    self.controller = nil -- Set by state
end

function VMPlaybackView:setController(controller)
    self.controller = controller
end

function VMPlaybackView:drawWindowed(viewport_width, viewport_height)
    local Config = (self.di and self.di.config) or require('src.config')

    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)

    if not self.controller then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("Error: No controller", 0, viewport_height / 2, viewport_width, "center")
        return
    end

    local vm_slot = self.controller.vm_slot
    if not vm_slot then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("No VM slot selected", 0, viewport_height / 2, viewport_width, "center")
        return
    end

    -- Check if VM is running and has a game instance
    if vm_slot.state == "IDLE" then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("VM is idle", 0, viewport_height / 2 - 20, viewport_width, "center")
        love.graphics.printf("Assign a demo to start playback", 0, viewport_height / 2 + 10, viewport_width, "center", 0, 0.8, 0.8)
        return
    end

    if vm_slot.headless_mode then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("VM is running in HEADLESS mode", 0, viewport_height / 2 - 20, viewport_width, "center")
        love.graphics.printf("No visual output available", 0, viewport_height / 2 + 10, viewport_width, "center", 0, 0.8, 0.8)
        return
    end

    if not vm_slot.game_instance then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("VM is restarting...", 0, viewport_height / 2, viewport_width, "center")
        return
    end

    -- HUD overlay dimensions
    local hud_height = 60
    local game_area_height = viewport_height - hud_height

    -- Get viewport for scissor (screen coordinates)
    local viewport = self.controller.viewport
    local screen_x = viewport and viewport.x or 0
    local screen_y = viewport and viewport.y or 0

    -- Scissor to game area (use screen coordinates)
    love.graphics.setScissor(screen_x, screen_y, viewport_width, game_area_height)

    -- Draw game content
    local game = vm_slot.game_instance
    if game and game.draw then
        -- Save graphics state
        love.graphics.push()

        -- Set up game rendering area
        if game.setPlayArea then
            game:setPlayArea(viewport_width, game_area_height)
        end

        -- Draw the game at 1x speed (visual feedback regardless of VM speed)
        local success, err = pcall(function()
            game:draw(viewport_width, game_area_height)
        end)

        if not success then
            love.graphics.pop()
            love.graphics.setScissor()
            love.graphics.setColor(1, 0, 0)
            love.graphics.printf("Game render error: " .. tostring(err), 0, game_area_height / 2, viewport_width, "center", 0, 0.7, 0.7)
            return
        end

        love.graphics.pop()
    end

    -- Clear scissor
    love.graphics.setScissor()

    -- Draw HUD overlay
    self:drawHUD(0, game_area_height, viewport_width, hud_height, vm_slot)
end

function VMPlaybackView:drawHUD(x, y, w, h, vm_slot)
    local Config = (self.di and self.di.config) or require('src.config')

    -- HUD background
    love.graphics.setColor(0.15, 0.15, 0.15, 0.95)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle('line', x, y, w, h)

    local padding = 10
    local text_y = y + padding

    -- VM info
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("VM " .. vm_slot.slot_index, x + padding, text_y, 0, 1.0, 1.0)

    -- State
    love.graphics.setColor(0, 1, 1)
    love.graphics.print("State: " .. vm_slot.state, x + padding + 60, text_y, 0, 0.9, 0.9)

    -- Speed indicator
    local speed_text = ""
    if vm_slot.headless_mode then
        speed_text = Config.vm_demo and Config.vm_demo.headless_speed_label or "INSTANT"
    elseif vm_slot.speed_multiplier and vm_slot.speed_multiplier > 1 then
        speed_text = vm_slot.speed_multiplier .. "x"
    else
        speed_text = "1x"
    end
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("VM Speed: " .. speed_text .. " | Display: 1x", x + padding + 200, text_y, 0, 0.9, 0.9)

    -- Run stats (second row)
    text_y = text_y + 20
    local stats = vm_slot.stats or {}
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print(string.format("Run #%d", (stats.total_runs or 0) + 1), x + padding, text_y, 0, 0.85, 0.85)

    -- Current run tokens (if available)
    if vm_slot.demo_player and vm_slot.game_instance then
        local current_frame = vm_slot.demo_player:getCurrentFrame and vm_slot.demo_player:getCurrentFrame() or 0
        local total_frames = vm_slot.demo_player:getTotalFrames and vm_slot.demo_player:getTotalFrames() or 0

        love.graphics.setColor(0.7, 1, 0.7)
        love.graphics.print(string.format("Frame: %d / %d", current_frame, total_frames), x + padding + 100, text_y, 0, 0.85, 0.85)

        -- Show progress percentage
        if total_frames > 0 then
            local progress = (current_frame / total_frames) * 100
            love.graphics.print(string.format("(%.1f%%)", progress), x + padding + 250, text_y, 0, 0.85, 0.85)
        end
    end

    -- Last run result (right side)
    if stats.total_runs and stats.total_runs > 0 then
        local last_result = stats.last_run_success and "VICTORY" or "DEFEAT"
        local result_color = stats.last_run_success and {0, 1, 0} or {1, 0.3, 0.3}
        love.graphics.setColor(result_color)
        love.graphics.printf("Last: " .. last_result .. " (+" .. (stats.last_run_tokens or 0) .. " tk)",
            x + padding, text_y, w - 2 * padding, "right", 0, 0.85, 0.85)
    end

    -- Instructions (bottom)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("Watching live VM execution - Close window to stop watching", x + padding, y + h - 18, 0, 0.75, 0.75)
end

return VMPlaybackView
