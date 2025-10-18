-- src/states/minigame_state.lua
local Object = require('class')
local ProgressionManager = require('models.progression_manager')
local MinigameState = Object:extend('MinigameState')

function MinigameState:init(player_data, game_data_model, state_machine, save_manager, cheat_system)
    print("[MinigameState] init() called")
    self.player_data = player_data
    self.game_data_model = game_data_model
    self.state_machine = state_machine
    self.save_manager = save_manager
    self.cheat_system = cheat_system

    self.current_game = nil
    self.game_data = nil
    self.completion_screen_visible = false
    self.previous_best = 0
    self.current_performance = 0
    self.base_performance = 0
    self.auto_completed_games = {}
    self.auto_complete_power = 0
    self.active_cheats = {}

    self.viewport = nil
    self.window_id = nil
    self.window_manager = nil
    self.gameCanvas = nil
    self.canvasScale = 1
    self.canvasOffsetX = 0
    self.canvasOffsetY = 0
    self.nativeGameWidth = 1920 -- Game's internal resolution
    self.nativeGameHeight = 1080 -- Game's internal resolution
    print("[MinigameState] init() completed")
end

-- Accepts CONTENT AREA bounds (absolute screen x,y + dimensions)
function MinigameState:setViewport(x, y, width, height)
    print(string.format("[MinigameState] setViewport CALLED with ABSOLUTE screen x=%.1f, y=%.1f | CONTENT dimensions w=%.1f, h=%.1f", x, y, width, height))
    -- Store the full bounds, but calculateCanvasTransform will primarily use width/height
    self.viewport = { x = x, y = y, width = width, height = height }
    if self.gameCanvas then
        print("[MinigameState] Canvas exists, recalculating transform using new dimensions")
        self:calculateCanvasTransform()
    else
        print("[MinigameState] Canvas is nil, skipping transform calculation")
    end
end

function MinigameState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

-- Calculates scale and RELATIVE offset within the content area
function MinigameState:calculateCanvasTransform()
    print("[MinigameState] calculateCanvasTransform() called")

    if not self.gameCanvas then
        print("[MinigameState] No canvas, setting defaults")
        self.canvasScale = 0
        self.canvasOffsetX = 0
        self.canvasOffsetY = 0
        return
    end

    -- Check for valid viewport dimensions
    if not self.viewport or
       type(self.viewport.width) ~= "number" or self.viewport.width <= 0 or
       type(self.viewport.height) ~= "number" or self.viewport.height <= 0 then
        print("[MinigameState] Invalid viewport dimensions received:",
              self.viewport and self.viewport.width, self.viewport and self.viewport.height)
        self.canvasScale = 0
        self.canvasOffsetX = 0
        self.canvasOffsetY = 0
        return
    end

    -- Ensure native dimensions are valid
    if not self.nativeGameWidth or self.nativeGameWidth <= 0 or
       not self.nativeGameHeight or self.nativeGameHeight <= 0 then
       print("[MinigameState] Invalid native game dimensions")
       self.canvasScale = 0
       self.canvasOffsetX = 0
       self.canvasOffsetY = 0
       return
    end

    local vpWidth = self.viewport.width
    local vpHeight = self.viewport.height
    local canvasWidth = self.nativeGameWidth
    local canvasHeight = self.nativeGameHeight

    -- Calculate scale to fit canvas within viewport, maintaining aspect ratio
    local scaleX = vpWidth / canvasWidth
    local scaleY = vpHeight / canvasHeight
    self.canvasScale = math.min(scaleX, scaleY)

    -- Prevent scale from being zero or negative
    if self.canvasScale <= 0 then self.canvasScale = 0.0001 end

    -- Calculate the dimensions of the scaled canvas
    local scaledWidth = canvasWidth * self.canvasScale
    local scaledHeight = canvasHeight * self.canvasScale

    -- Calculate offsets to center RELATIVE to the content area (0,0)
    self.canvasOffsetX = (vpWidth - scaledWidth) / 2
    self.canvasOffsetY = (vpHeight - scaledHeight) / 2

    print(string.format("[MinigameState] Transform calculated - vpW: %.1f, vpH: %.1f, scale: %.4f, RELATIVE offX: %.1f, offY: %.1f",
          vpWidth, vpHeight, self.canvasScale, self.canvasOffsetX, self.canvasOffsetY))
end

function MinigameState:enter(game_data)
    print("[MinigameState] enter() called for game:", game_data and game_data.id or "UNKNOWN")
    if not game_data then
        print("[MinigameState] ERROR: No game_data provided to enter()")
        -- Handle error appropriately, maybe close window?
        -- For now, just prevent further execution
        self.current_game = nil
        return { type = "close_window" } -- Signal DesktopState to close
    end

    self.game_data = game_data
    -- Create canvas ONLY IF IT DOESN'T EXIST (prevents issues if enter is called multiple times?)
    if not self.gameCanvas then
        self.gameCanvas = love.graphics.newCanvas(self.nativeGameWidth, self.nativeGameHeight)
        print("[MinigameState] Canvas created:", self.gameCanvas ~= nil)
    else
        print("[MinigameState] Canvas already exists.")
    end

    -- Recalculate transform based on viewport potentially set before enter
    if self.viewport then
       self:calculateCanvasTransform()
    else
       print("[MinigameState] Viewport not set yet in enter(), transform might be default.")
    end

    self.active_cheats = self.cheat_system:getActiveCheats(game_data.id) or {}
    local class_name = game_data.game_class
    -- Robust require path generation
    local logic_file_name = class_name:gsub("(%u)", function(c) return "_" .. c:lower() end):match("^_?(.*)") -- Handles leading caps
    local require_path = 'src.games.' .. logic_file_name
    print("[MinigameState] Attempting to require game class:", require_path)

    local require_ok, GameClass = pcall(require, require_path)
    if not require_ok or not GameClass then
        print("[MinigameState] ERROR: Failed to load game class '".. require_path .."': " .. tostring(GameClass))
        -- Attempt to clean up and signal error
        if self.gameCanvas then self.gameCanvas:release(); self.gameCanvas = nil; end
        self.current_game = nil
        -- Show message box AND signal close
        love.window.showMessageBox("Error", "Failed to load game logic for: " .. (game_data.display_name or class_name), "error")
        return { type = "close_window" }
    end

    -- Instantiate game safely
    local instance_ok, game_instance = pcall(GameClass.new, GameClass, game_data, self.active_cheats)
    if not instance_ok or not game_instance then
        print("[MinigameState] ERROR: Failed to instantiate game class '".. class_name .."': " .. tostring(game_instance))
        if self.gameCanvas then self.gameCanvas:release(); self.gameCanvas = nil; end
        self.current_game = nil
        love.window.showMessageBox("Error", "Failed to initialize game: " .. (game_data.display_name or class_name), "error")
        return { type = "close_window" }
    end
    self.current_game = game_instance

    -- Consume cheats only after successful instantiation
    self.cheat_system:consumeCheats(game_data.id)

    local perf = self.player_data:getGamePerformance(game_data.id)
    self.previous_best = perf and perf.best_score or 0
    self.completion_screen_visible = false
    self.current_performance = 0
    self.base_performance = 0
    self.auto_completed_games = {}
    self.auto_complete_power = 0
    print("[MinigameState] enter() completed successfully for", game_data.id)
end


function MinigameState:update(dt)
    -- Check if game instance exists
    if not self.current_game then return end

    -- Check completion state before updating game logic
    if not self.completion_screen_visible then
        local was_completed = self.current_game.completed -- Check before update
        local needs_completion_check = true

        -- Update base game state (timers, etc.)
        local update_base_ok, base_err = pcall(self.current_game.updateBase, self.current_game, dt)
        if not update_base_ok then
            print("Error during game updateBase:", base_err)
            -- Potentially handle error, maybe stop game updates
            return
        end

        -- If updateBase didn't already complete it, update game logic
        if not self.current_game.completed then
            local update_logic_ok, logic_err = pcall(self.current_game.updateGameLogic, self.current_game, dt)
            if not update_logic_ok then
                print("Error during game updateGameLogic:", logic_err)
                return
            end
        else
            -- updateBase completed the game, no need to check again
            needs_completion_check = false
        end

        -- Check for completion *after* all updates for the frame, if needed
        if needs_completion_check then
            local check_ok, should_complete = pcall(self.current_game.checkComplete, self.current_game)
            if check_ok and should_complete and not was_completed then
                -- Safely call onGameComplete
                local complete_ok, complete_err = pcall(self.onGameComplete, self)
                if not complete_ok then
                    print("Error during onGameComplete:", complete_err)
                end
            elseif not check_ok then
                 print("Error during game checkComplete:", should_complete)
            end
        end
    end
end

function MinigameState:draw()
    -- Check for valid viewport and canvas early
    if not self.gameCanvas then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("Loading...", 5, 5, 200)
        return
    end

    if not self.viewport or self.canvasScale == nil or self.canvasScale <= 0 then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("Initializing viewport...", 5, 5, 200)
        return
    end

    local g = love.graphics

    -- 1. Render game onto its internal canvas at native resolution
    g.setCanvas(self.gameCanvas)
    g.push()
    -- *** CRITICAL REINFORCEMENT: Ensure origin reset BEFORE clearing and drawing game ***
    g.origin() -- Reset transform *specifically for drawing onto the canvas*
    g.clear(0, 0, 0.1, 1) -- Use a slightly different clear color (dark blue) for debugging canvas vs screen (teal)

    if self.current_game and self.current_game.draw then
        -- We removed pcall previously for debugging, keep it removed for now
        -- Any errors inside the game's draw should now be visible in console
        self.current_game:draw()
    else
        -- Draw "Game not loaded" error ON THE CANVAS
        g.setColor(1, 0, 0)
        g.printf("Error: Game instance not loaded", 0, self.nativeGameHeight/2 - 10, self.nativeGameWidth, "center")
    end

    g.pop()
    g.setCanvas() -- Switch back to screen rendering IMPORTANT


    -- 2. Draw the canvas to the screen content area
    -- DesktopState has already translated the origin TO the content area's top-left.
    -- We draw the canvas relative to THIS new origin.

    g.setColor(1, 1, 1, 1)
    local drawX = tonumber(self.canvasOffsetX) or 0
    local drawY = tonumber(self.canvasOffsetY) or 0
    local drawScale = tonumber(self.canvasScale) or 0.0001
    if drawScale <= 0 then drawScale = 0.0001 end

    -- Draw the canvas onto the (already translated by DesktopState) screen buffer
    -- at the calculated RELATIVE offset and scale
    g.draw(self.gameCanvas, drawX, drawY, 0, drawScale, drawScale)

    -- 3. Draw completion screen overlay if needed (relative to content area 0,0)
    if self.completion_screen_visible then
        self:drawCompletionScreenWindowed(self.viewport.width, self.viewport.height)
    end
end

-- Draws completion screen relative to viewport dimensions
function MinigameState:drawCompletionScreenWindowed(vpWidth, vpHeight)
    -- Save current graphics state (like color, font)
    love.graphics.push()
    love.graphics.origin() -- Ensure drawing relative to content area (0,0)

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, vpWidth, vpHeight)

    -- Text content
    love.graphics.setColor(1, 1, 1)
    local metrics = (self.current_game and pcall(self.current_game.getMetrics, self.current_game)) and self.current_game:getMetrics() or {}

    -- Layout calculations based on viewport size
    local x = vpWidth * 0.1
    local y = vpHeight * 0.1
    local line_height = math.max(16, vpHeight * 0.04) -- Adjust line height based on viewport
    local title_scale = math.max(0.8, vpWidth / 700) -- Scale font based on width
    local text_scale = math.max(0.7, vpWidth / 800)

    love.graphics.printf("GAME COMPLETE!", x, y, vpWidth * 0.8, "center", 0, title_scale, title_scale)
    y = y + line_height * 2.5 -- More space after title

    local tokens_earned = math.floor(self.current_performance)
    local performance_mult = (self.active_cheats and self.active_cheats.performance_modifier) or 1.0

    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("Tokens Earned: +" .. tokens_earned, x, y, vpWidth * 0.8, "center", 0, text_scale * 1.2, text_scale * 1.2)
    y = y + line_height * 1.5

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Your Performance:", x, y, 0, text_scale, text_scale)
    y = y + line_height

    -- Display metrics
    if self.game_data and self.game_data.metrics_tracked then
        for _, metric_name in ipairs(self.game_data.metrics_tracked) do
            local value = metrics[metric_name]
            if value ~= nil then
                if type(value) == "number" then value = string.format("%.1f", value) end
                love.graphics.print("  " .. metric_name .. ": " .. value, x + 20, y, 0, text_scale * 0.9, text_scale * 0.9)
                y = y + line_height
            end
        end
    else
        love.graphics.print("  (Metrics unavailable)", x + 20, y, 0, text_scale * 0.9, text_scale * 0.9)
        y = y + line_height
    end

    y = y + line_height * 0.5
    love.graphics.print("Formula Calculation:", x, y, 0, text_scale, text_scale)
    y = y + line_height
    if self.game_data and self.game_data.formula_string then
        love.graphics.printf(self.game_data.formula_string, x + 20, y, vpWidth * 0.7, "left", 0, text_scale * 0.8, text_scale * 0.8)
        y = y + line_height
    end

    -- Show cheat bonus if applied
    if performance_mult ~= 1.0 then
        love.graphics.print("Base Result: " .. math.floor(self.base_performance), x + 20, y, 0, text_scale, text_scale)
        y = y + line_height
        love.graphics.setColor(0, 1, 1)
        love.graphics.print("Cheat Bonus: x" .. string.format("%.1f", performance_mult), x + 20, y, 0, text_scale, text_scale)
        y = y + line_height
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Final Result: " .. math.floor(self.current_performance), x + 20, y, 0, text_scale * 1.2, text_scale * 1.2)
    y = y + line_height * 1.5

    -- Show record / auto-completion info
    if self.current_performance > self.previous_best then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("NEW RECORD!", x, y, 0, text_scale * 1.3, text_scale * 1.3)
        y = y + line_height
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Previous: " .. math.floor(self.previous_best), x, y, 0, text_scale, text_scale)
        love.graphics.print("Improvement: +" .. math.floor(self.current_performance - self.previous_best), x, y + line_height, 0, text_scale, text_scale)
        y = y + line_height

        if #self.auto_completed_games > 0 then
            y = y + line_height
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("AUTO-COMPLETION TRIGGERED!", x, y, 0, text_scale * 1.1, text_scale * 1.1)
            y = y + line_height
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Completed " .. #self.auto_completed_games .. " easier variants!", x, y, 0, text_scale, text_scale)
            y = y + line_height
            love.graphics.print("Total power gained: +" .. math.floor(self.auto_complete_power), x, y, 0, text_scale, text_scale)
        end
    else
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Best: " .. math.floor(self.previous_best), x, y, 0, text_scale, text_scale)
        y = y + line_height
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Try again to improve your score!", x, y, 0, text_scale, text_scale)
    end

    -- Instructions at bottom
    love.graphics.setColor(1, 1, 1)
    local instruction_y = vpHeight - line_height * 2.5 -- Position from bottom
    love.graphics.printf("Press ENTER to play again", 0, instruction_y, vpWidth, "center", 0, text_scale, text_scale)
    love.graphics.printf("Press ESC to close window", 0, instruction_y + line_height, vpWidth, "center", 0, text_scale, text_scale)

    -- Restore previous graphics state
    love.graphics.pop()
end


function MinigameState:onGameComplete()
    -- Guard against multiple calls or missing game instance
    if self.completion_screen_visible or not self.current_game then return end

    print("[MinigameState] onGameComplete triggered for:", self.game_data and self.game_data.id)
    self.completion_screen_visible = true

    -- Safely calculate performance
    local base_perf_ok, base_perf_result = pcall(self.current_game.calculatePerformance, self.current_game)
    if base_perf_ok then
        self.base_performance = base_perf_result
    else
        print("Error calculating base performance:", base_perf_result)
        self.base_performance = 0
    end

    local performance_mult = (self.active_cheats and self.active_cheats.performance_modifier) or 1.0
    self.current_performance = self.base_performance * performance_mult
    local tokens_earned = math.floor(self.current_performance)

    -- Safely add tokens and update performance
    pcall(self.player_data.addTokens, self.player_data, tokens_earned)
    local metrics_ok, metrics_data = pcall(self.current_game.getMetrics, self.current_game)
    local metrics_to_save = metrics_ok and metrics_data or {}

    local is_new_best = false
    local update_ok, update_result = pcall(self.player_data.updateGamePerformance, self.player_data,
                                            self.game_data.id,
                                            metrics_to_save,
                                            self.current_performance)
    if update_ok then
        is_new_best = update_result
    else
        print("Error updating player performance:", update_result)
    end

    -- Check auto-completion only if it's a new best score
    if is_new_best then
        local progression = ProgressionManager:new() -- Assuming ProgressionManager is stateless or okay to recreate
        local check_ok, ac_result = pcall(progression.checkAutoCompletion, progression,
                                            self.game_data.id,
                                            self.game_data,
                                            self.game_data_model,
                                            self.player_data)
        if check_ok and type(ac_result) == 'table' then
            -- ProgressionManager returns {auto_completed_games, auto_complete_power}
            -- unpack the table safely
            self.auto_completed_games = ac_result[1] or {}
            self.auto_complete_power = ac_result[2] or 0
        elseif not check_ok then
             print("Error checking auto-completion:", ac_result)
             self.auto_completed_games = {}
             self.auto_complete_power = 0
        end
    else
        self.auto_completed_games = {}
        self.auto_complete_power = 0
    end

    -- Save game data
    pcall(self.save_manager.save, self.save_manager, self.player_data)
    print("[MinigameState] Game complete processing finished. New best:", is_new_best, "Auto-completed:", #self.auto_completed_games)
end


function MinigameState:keypressed(key)
    -- Check focus first
    if not self.window_manager or self.window_id ~= self.window_manager:getFocusedWindowId() then
        return false -- Not focused, don't handle input
    end

    if self.completion_screen_visible then
        if key == 'return' then
            -- Attempt to restart the game
            if self.game_data then
                local restart_event = self:enter(self.game_data) -- Call enter again
                -- Check if enter signaled an error (like failing to load)
                if type(restart_event) == 'table' and restart_event.type == "close_window" then
                     return restart_event -- Bubble up the close signal
                end
            end
            return { type = "content_interaction" } -- Signal interaction handled
        elseif key == 'escape' then
            return { type = "close_window" } -- Signal to close
        end
    else
        -- Game is active
        if key == 'escape' then
            -- Maybe add a pause confirmation later? For now, just close.
            return { type = "close_window" }
        else
            -- Forward keypress to the game logic, safely
            if self.current_game and self.current_game.keypressed then
                local success, result = pcall(self.current_game.keypressed, self.current_game, key)
                if success then
                    -- If game returns true, signal interaction handled
                    return result and { type = "content_interaction" } or false
                else
                    print("Error in game keypressed handler:", tostring(result))
                    return false -- Error occurred, don't block other handlers
                end
            end
        end
    end

    return false -- Key not handled by this state
end


function MinigameState:mousepressed(x, y, button)
    -- x, y are ALREADY LOCAL content coordinates relative to DesktopState's translation

    -- Check focus
    if not self.window_manager or self.window_id ~= self.window_manager:getFocusedWindowId() then
        return false -- Not focused
    end

    -- If completion screen is visible, it doesn't handle clicks, just ENTER/ESC
    if self.completion_screen_visible then
        return false -- Let DesktopState handle focus, don't pass click
    end

    -- Game is active, translate coordinates and pass to game logic
    if self.current_game and self.current_game.mousepressed then
        -- Ensure canvas transform is valid before translating coords
        if not self.viewport or self.canvasScale == nil or self.canvasScale <= 0 then
            print("[MinigameState:mousepressed] Warning: Invalid canvas transform, cannot process click.")
            return false -- Cannot translate coords if transform is invalid
        end

        -- Translate LOCAL viewport coords (x,y relative to content area 0,0)
        -- to LOCAL canvas coords (relative to canvas 0,0)
        local canvas_x = (x - self.canvasOffsetX) / self.canvasScale
        local canvas_y = (y - self.canvasOffsetY) / self.canvasScale

        -- Check if the translated coords are within the canvas logical bounds
        if canvas_x >= 0 and canvas_x <= self.nativeGameWidth and
           canvas_y >= 0 and canvas_y <= self.nativeGameHeight then
            -- Pass the translated CANVAS coordinates to the game logic safely
            local success, result = pcall(self.current_game.mousepressed, self.current_game, canvas_x, canvas_y, button)
            if not success then
                 print("Error in game mousepressed handler:", tostring(result))
                 -- Still return interaction handled even on error to prevent fall-through?
                 return { type = "content_interaction" }
            end
            -- Signal that interaction occurred if game processed it (even if game returned false)
            return { type = "content_interaction" }
        else
            -- Click was inside window content area BUT outside the scaled canvas (e.g., letterbox area)
            -- Treat this as an interaction within the window, but don't pass to game
            print("[MinigameState:mousepressed] Click in letterbox area.")
            return { type = "content_interaction" }
        end
    end

    -- If no game instance or game doesn't handle mouse, treat as interaction but don't pass
    return { type = "content_interaction" }
end

-- Cleanup when the state is left (window closed)
function MinigameState:leave()
    print("[MinigameState] leave() called for window ID:", self.window_id)
    if self.gameCanvas then
        -- Safely release the canvas
        local release_ok, err = pcall(self.gameCanvas.release, self.gameCanvas)
        if release_ok then
            print("Minigame canvas released successfully.")
        else
            print("Error releasing minigame canvas:", tostring(err))
        end
        self.gameCanvas = nil
    end
    -- Reset game instance to allow garbage collection
    self.current_game = nil
    print("MinigameState left, resources cleaned up.")
end


return MinigameState