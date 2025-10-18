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
    self.nativeGameWidth = 1920
    self.nativeGameHeight = 1080
    print("[MinigameState] init() completed")
end

function MinigameState:setViewport(x, y, width, height)
    print("[MinigameState] setViewport() called - canvas exists:", self.gameCanvas ~= nil)
    self.viewport = { x = x, y = y, width = width, height = height }
    if self.gameCanvas then
        print("[MinigameState] Canvas exists, calculating transform")
        self:calculateCanvasTransform()
    else
        print("[MinigameState] Canvas is nil, skipping transform calculation")
    end
end

function MinigameState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

function MinigameState:calculateCanvasTransform()
    print("[MinigameState] calculateCanvasTransform() called")

    if not self.gameCanvas then
        print("[MinigameState] No canvas, setting defaults")
        self.canvasScale = 0
        self.canvasOffsetX = 0
        self.canvasOffsetY = 0
        return
    end

    -- Check for valid viewport dimensions *before* using them
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


    -- *** Use viewport dimensions ***
    local vpWidth = self.viewport.width
    local vpHeight = self.viewport.height
    local canvasWidth = self.nativeGameWidth
    local canvasHeight = self.nativeGameHeight

    -- Calculate scale based on viewport, maintaining aspect ratio
    local scaleX = vpWidth / canvasWidth
    local scaleY = vpHeight / canvasHeight
    self.canvasScale = math.min(scaleX, scaleY)

    -- Prevent division by zero or negative scale if dimensions are bad
    if self.canvasScale <= 0 then self.canvasScale = 0.0001 end

    -- Calculate the dimensions of the scaled canvas
    local scaledWidth = canvasWidth * self.canvasScale
    local scaledHeight = canvasHeight * self.canvasScale

    -- Calculate offsets to center the canvas *within the viewport*
    self.canvasOffsetX = (vpWidth - scaledWidth) / 2
    self.canvasOffsetY = (vpHeight - scaledHeight) / 2

    print(string.format("[MinigameState] Transform calculated - vpW: %d, vpH: %d, scale: %.4f, offX: %.1f, offY: %.1f",
          vpWidth, vpHeight, self.canvasScale, self.canvasOffsetX, self.canvasOffsetY))
end

function MinigameState:enter(game_data)
    print("[MinigameState] enter() called for game:", game_data and game_data.id or "UNKNOWN")
    
    self.game_data = game_data
    self.gameCanvas = love.graphics.newCanvas(self.nativeGameWidth, self.nativeGameHeight)
    print("[MinigameState] Canvas created:", self.gameCanvas ~= nil)
    
    self:calculateCanvasTransform()
    
    self.active_cheats = self.cheat_system:getActiveCheats(game_data.id) or {}
    local class_name = game_data.game_class
    local logic_file_name = class_name:gsub("(%u)", function(c) return "_" .. c:lower() end):sub(2)
    local require_ok, GameClass = pcall(require, 'src.games.' .. logic_file_name)
    if not require_ok or not GameClass then
        print("[MinigameState] ERROR: Failed to load game class")
        self.current_game = nil
        return
    end
    
    self.current_game = GameClass:new(game_data, self.active_cheats)
    self.cheat_system:consumeCheats(game_data.id)
    local perf = self.player_data:getGamePerformance(game_data.id)
    self.previous_best = perf and perf.best_score or 0
    self.completion_screen_visible = false
    self.current_performance = 0
    self.base_performance = 0
    self.auto_completed_games = {}
    self.auto_complete_power = 0
    print("[MinigameState] enter() completed")
end

function MinigameState:update(dt)
    if self.current_game and not self.completion_screen_visible then
        if self.current_game:checkComplete() and not self.current_game.completed then
            self:onGameComplete()
        end
        if not self.current_game.completed then
            self.current_game:updateBase(dt)
            if not self.current_game.completed then
                self.current_game:updateGameLogic(dt)
            end
            if self.current_game:checkComplete() and not self.current_game.completed then
                self:onGameComplete()
            end
        end
    end
end

function MinigameState:draw()
    -- Check for valid viewport and canvas early
    if not self.gameCanvas then
        love.graphics.setColor(1, 0, 0)
        -- Still draw relative to the current origin set by DesktopState
        love.graphics.printf("Loading...", 5, 5, 200)
        return
    end

    if not self.viewport or self.canvasScale == nil or self.canvasScale <= 0 then
        love.graphics.setColor(1, 0, 0)
        -- Still draw relative to the current origin set by DesktopState
        love.graphics.printf("Initializing viewport...", 5, 5, 200)
        return
    end

    local g = love.graphics

    -- 1. Render game onto its internal canvas (Keep this part the same as the last fix)
    g.setCanvas(self.gameCanvas)
    g.push()
    g.clear(0, 0, 0, 1) -- Clear the canvas

    if self.current_game then
        local draw_ok, err = pcall(self.current_game.draw, self.current_game)
        if not draw_ok then
             print("ERROR drawing game:", tostring(err))
             g.setColor(1, 0, 0)
             g.printf("Error drawing game", 10, 10, self.nativeGameWidth - 20)
        end
    else
        g.setColor(1, 0, 0)
        g.printf("Error: Game not loaded", 0, self.nativeGameHeight/2 - 10, self.nativeGameWidth, "center")
    end
    g.pop()
    g.setCanvas() -- Switch back to drawing to the screen

    -- 2. Draw the prepared canvas onto the screen
    -- *** CHANGE: Draw canvas relative to the CURRENT ORIGIN (content area top-left) ***
    -- DesktopState has already translated the origin to the content area's top-left.
    -- self.canvasOffsetX/Y are calculated offsets *within* that content area.
    -- So, drawing at (self.canvasOffsetX, self.canvasOffsetY) should be correct now.
    g.setColor(1, 1, 1, 1)
    g.draw(self.gameCanvas, self.canvasOffsetX, self.canvasOffsetY, 0, self.canvasScale, self.canvasScale)
    -- The scissor set by DesktopState will clip this draw call correctly.

    -- 3. Draw completion screen overlay if needed
    -- This is drawn *after* the canvas, still relative to the content area top-left (0,0)
    if self.completion_screen_visible then
        -- Make sure this draws relative to 0,0 (which is the content area top-left)
        self:drawCompletionScreenWindowed(self.viewport.width, self.viewport.height)
    end
end

function MinigameState:drawCompletionScreenWindowed(vpWidth, vpHeight)
    love.graphics.push()
    love.graphics.origin()

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, vpWidth, vpHeight)

    love.graphics.setColor(1, 1, 1)
    local metrics = self.current_game and self.current_game:getMetrics() or {}

    local x = vpWidth * 0.15
    local y = vpHeight * 0.1
    local line_height = math.max(18, vpHeight * 0.04)
    local title_scale = math.max(1, vpWidth / 600)
    local text_scale = math.max(0.8, vpWidth / 800)

    love.graphics.print("GAME COMPLETE!", x, y, 0, title_scale, title_scale)
    y = y + line_height * 2

    local tokens_earned = math.floor(self.current_performance)
    local performance_mult = (self.active_cheats and self.active_cheats.performance_modifier) or 1.0

    love.graphics.setColor(1, 1, 0)
    love.graphics.print("Tokens Earned: +" .. tokens_earned, x, y, 0, text_scale * 1.2, text_scale * 1.2)
    y = y + line_height * 1.5

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Your Performance:", x, y, 0, text_scale, text_scale)
    y = y + line_height

    if self.game_data and self.game_data.metrics_tracked then
        for _, metric_name in ipairs(self.game_data.metrics_tracked) do
            local value = metrics[metric_name]
            if value ~= nil then
                if type(value) == "number" then value = string.format("%.1f", value) end
                love.graphics.print("  " .. metric_name .. ": " .. value, x + 20, y, 0, text_scale, text_scale)
                y = y + line_height
            end
        end
    end

    y = y + line_height
    love.graphics.print("Formula Calculation:", x, y, 0, text_scale, text_scale)
    y = y + line_height
    if self.game_data and self.game_data.formula_string then
        love.graphics.print(self.game_data.formula_string, x + 20, y, 0, text_scale * 0.9, text_scale * 0.9)
        y = y + line_height
    end

    if performance_mult ~= 1.0 then
        love.graphics.print("Base Result: " .. math.floor(self.base_performance), x + 20, y, 0, text_scale, text_scale)
        y = y + line_height
        love.graphics.setColor(0, 1, 1)
        love.graphics.print("Cheat Bonus: x" .. string.format("%.1f", performance_mult), x + 20, y, 0, text_scale, text_scale)
        y = y + line_height
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Final Result: " .. math.floor(self.current_performance), x + 20, y, 0, text_scale * 1.2, text_scale * 1.2)

    y = y + line_height * 2
    if self.current_performance > self.previous_best then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("NEW RECORD!", x, y, 0, text_scale * 1.3, text_scale * 1.3)
        y = y + line_height
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Previous best: " .. math.floor(self.previous_best), x, y, 0, text_scale, text_scale)
        love.graphics.print("Improvement: +" .. math.floor(self.current_performance - self.previous_best), x, y + line_height, 0, text_scale, text_scale)

        if #self.auto_completed_games > 0 then
            y = y + line_height * 2
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("AUTO-COMPLETION!", x, y, 0, text_scale * 1.2, text_scale * 1.2)
            y = y + line_height
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Completed " .. #self.auto_completed_games .. " variants!", x, y, 0, text_scale, text_scale)
            y = y + line_height
            love.graphics.print("Power gained: +" .. math.floor(self.auto_complete_power), x, y, 0, text_scale, text_scale)
        end
    else
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Best: " .. math.floor(self.previous_best), x, y, 0, text_scale, text_scale)
        y = y + line_height
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Try again to beat your record!", x, y, 0, text_scale, text_scale)
    end

    love.graphics.setColor(1, 1, 1)
    y = vpHeight * 0.85
    love.graphics.printf("Press ENTER to play again", 0, y, vpWidth, "center", 0, text_scale, text_scale)
    love.graphics.printf("Press ESC to close window", 0, y + line_height, vpWidth, "center", 0, text_scale, text_scale)

    love.graphics.pop()
end

function MinigameState:onGameComplete()
    if not self.current_game then return end
    if self.completion_screen_visible then return end

    self.completion_screen_visible = true
    self.base_performance = self.current_game:calculatePerformance()
    local performance_mult = (self.active_cheats and self.active_cheats.performance_modifier) or 1.0
    self.current_performance = self.base_performance * performance_mult
    local tokens_earned = math.floor(self.current_performance)
    self.player_data:addTokens(tokens_earned)
    
    local is_new_best = self.player_data:updateGamePerformance(
        self.game_data.id,
        self.current_game:getMetrics(),
        self.current_performance
    )
    
    if is_new_best then
        local progression = ProgressionManager:new()
        self.auto_completed_games, self.auto_complete_power =
            progression:checkAutoCompletion(
                self.game_data.id,
                self.game_data,
                self.game_data_model,
                self.player_data
            )
    end
    
    self.save_manager.save(self.player_data)
end

function MinigameState:keypressed(key)
    if not self.window_manager or self.window_id ~= self.window_manager:getFocusedWindowId() then
        return false
    end

    if self.completion_screen_visible then
        if key == 'return' then
            if self.game_data then self:enter(self.game_data) end
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
                    print("Error in game keypressed:", tostring(result))
                end
            end
        end
    end
    
    return false
end

function MinigameState:mousepressed(x, y, button)
    -- x, y are ALREADY LOCAL content coordinates from DesktopState
    -- Check focus (already done in previous version, keep it)
    if not self.window_manager or self.window_id ~= self.window_manager:getFocusedWindowId() then
        return false
    end

    if not self.completion_screen_visible then
        if self.current_game and self.current_game.mousepressed then
            -- Ensure canvas transform calculation is valid before translating coords
            if not self.viewport or self.canvasScale == nil or self.canvasScale <= 0 then
                print("[MinigameState:mousepressed] Warning: Invalid canvas transform, cannot process click.")
                return false -- Cannot translate coords if transform is invalid
            end

            -- Translate LOCAL viewport coords (x,y) to LOCAL canvas coords
            local canvas_x = (x - self.canvasOffsetX) / self.canvasScale
            local canvas_y = (y - self.canvasOffsetY) / self.canvasScale

            -- Check if the translated coords are within the canvas bounds
            if canvas_x >= 0 and canvas_x <= self.nativeGameWidth and
               canvas_y >= 0 and canvas_y <= self.nativeGameHeight then
                -- Pass the translated CANVAS coordinates to the game logic
                local success, result = pcall(self.current_game.mousepressed, self.current_game, canvas_x, canvas_y, button)
                if not success then
                     print("Error in game mousepressed:", tostring(result))
                end
                -- Regardless of game handling, clicking inside is an interaction
                return { type = "content_interaction" }
            else
                -- Click was inside viewport but outside the scaled canvas (e.g., letterbox area)
                return false -- Don't pass to game, let DesktopState handle focus if needed
            end
        end
    end

    -- If completion screen is visible or game doesn't handle mouse,
    -- return false to let DesktopState handle focus etc.
    return false
end

function MinigameState:leave()
    if self.gameCanvas then
        self.gameCanvas:release()
        self.gameCanvas = nil
    end
    print("MinigameState leaving, canvas released")
end

return MinigameState