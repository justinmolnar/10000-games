local Object = require('class')
local Strings = require('src.utils.strings')
local MinigameController = require('src.controllers.minigame_controller')
local MinigameView = require('src.views.minigame_view')
local MinigameState = Object:extend('MinigameState')

function MinigameState:init(player_data, game_data_model, state_machine, save_manager, cheat_system, di)
    print("[MinigameState] init() called")
    self.player_data = player_data
    self.game_data_model = game_data_model
    self.state_machine = state_machine
    self.save_manager = save_manager
    self.cheat_system = cheat_system
    self.di = di -- optional dependency container

    self.current_game = nil
    self.game_data = nil
    self.controller = MinigameController:new(player_data, game_data_model, save_manager, cheat_system, di)
    self.view = MinigameView:new(di)

    self.viewport = nil
    self.window_id = nil
    self.window_manager = nil
    
    print("[MinigameState] init() completed")
end

function MinigameState:setViewport(x, y, width, height)
    print(string.format("[MinigameState] setViewport CALLED with x=%.1f, y=%.1f, w=%.1f, h=%.1f", x, y, width, height))
    self.viewport = { x = x, y = y, width = width, height = height }

    if self.current_game and self.current_game.setPlayArea then
        self.current_game:setPlayArea(width, height)
    end
end

function MinigameState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

function MinigameState:enter(game_data, variant_override)
    print("[MinigameState] enter() called for game:", game_data and game_data.id or "UNKNOWN")
    if variant_override then
        print("[MinigameState] Using modified variant from CheatEngine")
    end

    if not game_data then
        print("[MinigameState] ERROR: No game_data provided to enter()")
        self.current_game = nil
        return { type = "close_window" }
    end

    self.game_data = game_data
    self.variant_override = variant_override -- Store for restart functionality
    
    local class_name = game_data.game_class
    local logic_file_name = class_name:gsub("(%u)", function(c) return "_" .. c:lower() end):match("^_?(.*)")
    local require_path = 'src.games.' .. logic_file_name
    print("[MinigameState] Attempting to require game class:", require_path)

    local require_ok, GameClass = pcall(require, require_path)
    if not require_ok or not GameClass then
        print("[MinigameState] ERROR: Failed to load game class '".. require_path .."': " .. tostring(GameClass))
        self.current_game = nil
        local S = (self.di and self.di.strings) or Strings
        love.window.showMessageBox(S.get('messages.error_title', 'Error'), "Failed to load game logic for: " .. (game_data.display_name or class_name), "error")
        return { type = "close_window" }
    end

    -- Get active cheats from CheatSystem
    local active_cheats = self.cheat_system:getActiveCheats(game_data.id) or {}

    -- Pass DI (if present) and variant override into the game constructor
    local instance_ok, game_instance = pcall(GameClass.new, GameClass, game_data, active_cheats, self.di, variant_override)
    if not instance_ok or not game_instance then
        print("[MinigameState] ERROR: Failed to instantiate game class '".. class_name .."': " .. tostring(game_instance))
        self.current_game = nil
        local S = (self.di and self.di.strings) or Strings
        love.window.showMessageBox(S.get('messages.error_title', 'Error'), "Failed to initialize game: " .. (game_data.display_name or class_name), "error")
        return { type = "close_window" }
    end
    self.current_game = game_instance

    -- Correct aspect ratio if needed BEFORE setting play area
    if self.current_game.lock_aspect_ratio and self.current_game.game_width and self.current_game.game_height and self.window_manager and self.window_id then
        local window = self.window_manager:getWindowById(self.window_id)
        if window then
            local Config = self.di and self.di.config
            local title_bar_height = (Config and Config.ui and Config.ui.window and Config.ui.window.chrome and Config.ui.window.chrome.title_bar_height) or 25
            local border_width = (Config and Config.ui and Config.ui.window and Config.ui.window.chrome and Config.ui.window.chrome.border_width) or 2
            local target_aspect = self.current_game.game_width / self.current_game.game_height

            -- Get screen bounds
            local screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()
            local taskbar_h = (Config and Config.ui and Config.ui.taskbar and Config.ui.taskbar.height) or 40
            local max_window_h = screen_h - taskbar_h - window.y
            local max_window_w = screen_w - window.x

            -- Calculate what height would be needed for current width
            local viewport_width = math.floor(window.width - (border_width * 2))
            local viewport_height = math.floor(viewport_width / target_aspect)
            local corrected_window_height = viewport_height + title_bar_height + (border_width * 2)

            -- Check if height exceeds screen bounds
            if corrected_window_height > max_window_h then
                -- Height too tall - reduce width to fit max height
                local max_viewport_h = max_window_h - title_bar_height - (border_width * 2)
                viewport_width = math.floor(max_viewport_h * target_aspect)
                viewport_height = math.floor(max_viewport_h)
                local corrected_window_width = viewport_width + (border_width * 2)

                print("[MinigameState] CORRECTING ASPECT RATIO (height constrained) - width:", window.width, "->", corrected_window_width, "height:", window.height, "->", max_window_h)
                self.window_manager:updateWindowBounds(self.window_id, nil, nil, corrected_window_width, max_window_h)
            else
                -- Height fits - just adjust height
                print("[MinigameState] CORRECTING ASPECT RATIO - window height:", window.height, "->", corrected_window_height)
                self.window_manager:updateWindowBounds(self.window_id, nil, nil, nil, corrected_window_height)
            end

            -- Update viewport with corrected dimensions
            if self.viewport then
                self.viewport.width = viewport_width
                self.viewport.height = viewport_height
            end
        end
    end

    if self.viewport and self.current_game.setPlayArea then
        print("[MinigameState] Setting initial play area from existing viewport:", self.viewport.width, self.viewport.height)
        self.current_game:setPlayArea(self.viewport.width, self.viewport.height)
    end

    -- Begin a new session in the controller
    self.controller:begin(self.current_game, game_data)
    print("[MinigameState] enter() completed successfully for", game_data.id)
end

function MinigameState:update(dt)
    if not self.current_game then return end
    self.controller:update(dt)
end

function MinigameState:draw()
    if not self.viewport then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("Viewport not set", 5, 5, 200)
        return
    end

    if self.current_game and self.current_game.draw then
        self.current_game:draw()
    else
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("Error: Game instance not loaded", 0, self.viewport.height/2 - 10, self.viewport.width, "center")
    end

    if self.controller:isOverlayVisible() then
        self.view:drawOverlay(self.viewport, self.controller:getSnapshot())
    end
end

-- onGameComplete removed; controller owns completion logic

function MinigameState:keypressed(key)
    if not self.window_manager or self.window_id ~= self.window_manager:getFocusedWindowId() then
        return false
    end

    if self.controller:isOverlayVisible() then
        if key == 'return' then
            if self.game_data then
                -- Pass variant_override through on restart
                local restart_event = self:enter(self.game_data, self.variant_override)
                if type(restart_event) == 'table' and restart_event.type == "close_window" then
                     return restart_event
                end
            end
            return { type = "content_interaction" }
        elseif key == 'escape' then
            return { type = "close_window" }
        end
    else
        if key == 'escape' then
            return { type = "close_window" }
        else
            if self.current_game and self.current_game.keypressed then
                local success, result = pcall(self.current_game.keypressed, self.current_game, key)
                if success then
                    return result and { type = "content_interaction" } or false
                else
                    print("Error in game keypressed handler:", tostring(result))
                    return false
                end
            end
        end
    end

    return false
end

function MinigameState:keyreleased(key)
    if not self.window_manager or self.window_id ~= self.window_manager:getFocusedWindowId() then
        return false
    end

    -- Only forward key releases during active gameplay (not when overlay is visible)
    if not self.controller:isOverlayVisible() then
        if self.current_game and self.current_game.keyreleased then
            local success, result = pcall(self.current_game.keyreleased, self.current_game, key)
            if not success then
                print("Error in game keyreleased handler:", tostring(result))
            end
        end
    end

    return false
end

function MinigameState:mousepressed(x, y, button)
    if not self.window_manager or self.window_id ~= self.window_manager:getFocusedWindowId() then
        return false
    end

    if self.controller:isOverlayVisible() then
        return false
    end

    if self.current_game and self.current_game.mousepressed then
        local success, result = pcall(self.current_game.mousepressed, self.current_game, x, y, button)
        if not success then
             print("Error in game mousepressed handler:", tostring(result))
             return { type = "content_interaction" }
        end
        return { type = "content_interaction" }
    end

    return { type = "content_interaction" }
end

function MinigameState:leave()
    print("[MinigameState] leave() called for window ID:", self.window_id)
    self.current_game = nil
    print("MinigameState left, resources cleaned up.")
end

return MinigameState