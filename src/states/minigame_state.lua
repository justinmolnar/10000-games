-- src/states/minigame_state.lua
local Object = require('class')
local ProgressionManager = require('models.progression_manager')
local MinigameState = Object:extend('MinigameState')

-- Add viewport and window context properties
function MinigameState:init(player_data, game_data_model, state_machine, save_manager, cheat_system)
    self.player_data = player_data
    self.game_data_model = game_data_model -- Store the main game data model
    self.state_machine = state_machine
    self.save_manager = save_manager
    self.cheat_system = cheat_system -- Injected dependency

    self.current_game = nil
    self.game_data = nil -- This will hold the specific game's data
    self.completion_screen_visible = false
    self.previous_best = 0
    self.current_performance = 0 -- Will hold the final calculated performance
    self.base_performance = 0 -- Will hold performance before cheat multiplier
    self.auto_completed_games = {}
    self.auto_complete_power = 0
    self.active_cheats = {} -- Store cheats for this run

    -- Windowing additions
    self.viewport = nil -- Will be set by DesktopState {x,y,width,height} are SCREEN coords + dimensions
    self.window_id = nil
    self.window_manager = nil -- Will be set by DesktopState
    self.gameCanvas = nil -- Canvas for rendering
    self.canvasScale = 1
    self.canvasOffsetX = 0 -- Offset RELATIVE TO VIEWPORT ORIGIN (0,0) after translate
    self.canvasOffsetY = 0 -- Offset RELATIVE TO VIEWPORT ORIGIN (0,0) after translate
    self.nativeGameWidth = 1920 -- Assuming native resolution, adjust if needed
    self.nativeGameHeight = 1080
end

-- Add setViewport method
function MinigameState:setViewport(x, y, width, height)
    -- Store the content area bounds passed by DesktopState (absolute screen coords + dimensions)
    self.viewport = { x = x, y = y, width = width, height = height }
    -- Recalculate scaling and offset whenever viewport changes
    self:calculateCanvasTransform()
    print(string.format("Minigame %s viewport updated: sx=%.1f, sy=%.1f, w=%.1f, h=%.1f -> scale=%.3f, ox=%.1f, oy=%.1f",
        (self.game_data and self.game_data.id or "N/A"), x, y, width, height, self.canvasScale or -1, self.canvasOffsetX or -1, self.canvasOffsetY or -1))
end


-- Add setWindowContext method
function MinigameState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

-- Helper to calculate canvas scaling and offset for letterboxing
function MinigameState:calculateCanvasTransform()
    -- Check if canvas exists and is valid
    if not self.gameCanvas then
        print("Warning: calculateCanvasTransform called before canvas is ready.")
        self.canvasScale = 0
        self.canvasOffsetX = 0
        self.canvasOffsetY = 0
        return
    end
    
    -- Try to check if canvas is released, with error handling
    local canvas_released = false
    local check_ok = pcall(function()
        canvas_released = self.gameCanvas:isReleased()
    end)
    
    if not check_ok or canvas_released then
        print("Warning: Canvas is invalid or released in calculateCanvasTransform.")
        self.canvasScale = 0
        self.canvasOffsetX = 0
        self.canvasOffsetY = 0
        return
    end

    -- Validate viewport dimensions
    if not self.viewport or
       type(self.viewport.width) ~= "number" or self.viewport.width <= 0 or
       type(self.viewport.height) ~= "number" or self.viewport.height <= 0 or
       not self.nativeGameWidth or self.nativeGameWidth <= 0 or
       not self.nativeGameHeight or self.nativeGameHeight <= 0 then

        print("Warning: Invalid dimensions for canvas transform calculation.")
        self.canvasScale = 0
        self.canvasOffsetX = 0
        self.canvasOffsetY = 0
        return
    end

    -- Calculate scale and offset
    local vpWidth = self.viewport.width
    local vpHeight = self.viewport.height
    local canvasWidth = self.nativeGameWidth
    local canvasHeight = self.nativeGameHeight

    local scaleX = vpWidth / canvasWidth
    local scaleY = vpHeight / canvasHeight
    self.canvasScale = math.min(scaleX, scaleY)

    if self.canvasScale <= 0 then self.canvasScale = 0.0001 end

    local scaledWidth = canvasWidth * self.canvasScale
    local scaledHeight = canvasHeight * self.canvasScale

    self.canvasOffsetX = (vpWidth - scaledWidth) / 2
    self.canvasOffsetY = (vpHeight - scaledHeight) / 2
end


function MinigameState:enter(game_data)
    self.game_data = game_data
    self.gameCanvas = love.graphics.newCanvas(self.nativeGameWidth, self.nativeGameHeight)
    self:calculateCanvasTransform()
    self.active_cheats = self.cheat_system:getActiveCheats(game_data.id) or {}
    local class_name = game_data.game_class
    local logic_file_name = class_name:gsub("(%u)", function(c) return "_" .. c:lower() end):sub(2)
    local require_ok, GameClass = pcall(require, 'src.games.' .. logic_file_name)
    if not require_ok or not GameClass then
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
end

function MinigameState:calculateCanvasTransform()
    if not self.gameCanvas or not self.viewport then
        self.canvasScale = 0
        self.canvasOffsetX = 0
        self.canvasOffsetY = 0
        return
    end

    local vpWidth = self.viewport.width
    local vpHeight = self.viewport.height

    local scaleX = vpWidth / self.nativeGameWidth
    local scaleY = vpHeight / self.nativeGameHeight
    self.canvasScale = math.min(scaleX, scaleY)

    local scaledWidth = self.nativeGameWidth * self.canvasScale
    local scaledHeight = self.nativeGameHeight * self.canvasScale

    self.canvasOffsetX = (vpWidth - scaledWidth) / 2
    self.canvasOffsetY = (vpHeight - scaledHeight) / 2
end

function MinigameState:draw()
    if not self.viewport or not self.gameCanvas then
        return
    end

    love.graphics.setCanvas(self.gameCanvas)
    love.graphics.clear(0, 0, 0, 1)
    
    if self.current_game and self.current_game.draw then
        pcall(self.current_game.draw, self.current_game)
    end
    
    love.graphics.setCanvas()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.gameCanvas, self.canvasOffsetX, self.canvasOffsetY, 0, self.canvasScale, self.canvasScale)

    if self.completion_screen_visible then
        self:drawCompletionScreenWindowed(self.viewport.width, self.viewport.height)
    end
end

function MinigameState:calculateCanvasTransform()
    if not self.gameCanvas or not self.viewport then
        self.canvasScale = 0
        self.canvasOffsetX = 0
        self.canvasOffsetY = 0
        return
    end
    local scaleX = self.viewport.width / self.nativeGameWidth
    local scaleY = self.viewport.height / self.nativeGameHeight
    self.canvasScale = math.min(scaleX, scaleY)
    local scaledWidth = self.nativeGameWidth * self.canvasScale
    local scaledHeight = self.nativeGameHeight * self.canvasScale
    self.canvasOffsetX = (self.viewport.width - scaledWidth) / 2
    self.canvasOffsetY = (self.viewport.height - scaledHeight) / 2
end

function MinigameState:draw()
    if not self.viewport or not self.gameCanvas then
        return
    end
    love.graphics.setCanvas(self.gameCanvas)
    love.graphics.clear(0, 0, 0, 1)
    if self.current_game and self.current_game.draw then
        pcall(self.current_game.draw, self.current_game)
    end
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.gameCanvas, self.canvasOffsetX, self.canvasOffsetY, 0, self.canvasScale, self.canvasScale)
    if self.completion_screen_visible then
        self:drawCompletionScreenWindowed(self.viewport.width, self.viewport.height)
    end
end

function MinigameState:update(dt)
    -- *** Update runs regardless of focus ***
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

-- Re-corrected draw function
function MinigameState:draw()
    -- Ensure viewport and canvas are valid AND transform values are calculated
    if not self.viewport or not self.gameCanvas or self.gameCanvas:isReleased() or self.canvasScale == nil or self.canvasScale <= 0 then
        -- Draw error message relative to the translated origin (0,0) established by DesktopState
        love.graphics.setColor(1,0,0)
        love.graphics.printf("Error: Minigame state draw prerequisites not met.", 5, 5, (self.viewport and self.viewport.width or 100) - 10)
        return
    end

    -- *** DesktopState has already applied love.graphics.translate to the content area's origin ***
    -- *** DesktopState has already applied love.graphics.setScissor to the content area ***
    -- *** This function draws relative to (0,0) which IS the top-left of the content area ***

    local g = love.graphics -- Alias

    -- 1. Render game onto the canvas (off-screen)
    g.setCanvas(self.gameCanvas)
    g.push("all") -- Save graphics state for canvas rendering
    g.origin()    -- Work in canvas's local coordinates (0,0 top-left)
    g.clear(0, 0, 0, 1) -- Black background for canvas
    if self.current_game then
        local draw_ok, err = pcall(self.current_game.draw, self.current_game)
        if not draw_ok then
             print("ERROR drawing game " .. (self.game_data and self.game_data.id or "unknown") .. ": " .. tostring(err))
             g.setColor(1,0,0)
             g.printf("Error during game draw:\n" .. tostring(err), 10, 10, self.nativeGameWidth - 20)
        end
    else
        g.setColor(1,0,0)
        g.printf("Error: Game instance not loaded.", 0, self.nativeGameHeight/2 - 10, self.nativeGameWidth, "center")
    end
    g.pop() -- Restore graphics state before switching canvas
    g.setCanvas() -- Back to the main screen target (which is already translated and scissored)

    -- 2. Draw the scaled canvas *onto the already translated viewport*
    g.setColor(1, 1, 1, 1)
    -- Draw the canvas at the calculated offset (self.canvasOffsetX, self.canvasOffsetY)
    -- These offsets are relative to the viewport's top-left corner (which is currently 0,0 due to translate)
    g.draw(self.gameCanvas, self.canvasOffsetX, self.canvasOffsetY, 0, self.canvasScale, self.canvasScale)

    -- 3. Draw completion screen overlay if visible
    if self.completion_screen_visible then
        -- Draw overlay relative to the viewport's top-left corner (0,0)
        self:drawCompletionScreenWindowed(self.viewport.width, self.viewport.height)
        -- No extra push/pop/origin needed here as drawCompletionScreenWindowed draws relative to 0,0
    end
end


function MinigameState:drawCompletionScreenWindowed(vpWidth, vpHeight)
    -- Use a temporary push/pop to ensure overlay draws correctly without affecting canvas draw state later
    love.graphics.push()
    love.graphics.origin() -- Draw relative to viewport 0,0

    -- Semi-transparent background within viewport
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, vpWidth, vpHeight)

    love.graphics.setColor(1, 1, 1)
    local metrics = self.current_game and self.current_game:getMetrics() or {}

    -- Adjust layout based on viewport size
    local x = vpWidth * 0.15
    local y = vpHeight * 0.1
    local line_height = math.max(18, vpHeight * 0.04) -- Scale line height
    local title_scale = math.max(1, vpWidth / 600)
    local text_scale = math.max(0.8, vpWidth / 800)

    -- Title
    love.graphics.print("GAME COMPLETE!", x, y, 0, title_scale, title_scale); y = y + line_height * 2

    local tokens_earned = math.floor(self.current_performance)
    local performance_mult = (self.active_cheats and self.active_cheats.performance_modifier) or 1.0

    -- Tokens earned
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("Tokens Earned: +" .. tokens_earned, x, y, 0, text_scale * 1.2, text_scale * 1.2); y = y + line_height * 1.5

    -- Metrics
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Your Performance:", x, y, 0, text_scale, text_scale); y = y + line_height

    if self.game_data and self.game_data.metrics_tracked then
        for _, metric_name in ipairs(self.game_data.metrics_tracked) do
            local value = metrics[metric_name]
            if value ~= nil then
                if type(value) == "number" then value = string.format("%.1f", value) end
                love.graphics.print("  " .. metric_name .. ": " .. value, x + 20, y, 0, text_scale, text_scale); y = y + line_height
            end
        end
    end

    -- Formula calculation
    y = y + line_height
    love.graphics.print("Formula Calculation:", x, y, 0, text_scale, text_scale); y = y + line_height
    if self.game_data and self.game_data.formula_string then
        love.graphics.print(self.game_data.formula_string, x + 20, y, 0, text_scale * 0.9, text_scale * 0.9); y = y + line_height
    end

    if performance_mult ~= 1.0 then
        love.graphics.print("Base Result: " .. math.floor(self.base_performance), x + 20, y, 0, text_scale, text_scale); y = y + line_height
        love.graphics.setColor(0, 1, 1)
        love.graphics.print("Cheat Bonus: x" .. string.format("%.1f", performance_mult), x + 20, y, 0, text_scale, text_scale); y = y + line_height
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Final Result: " .. math.floor(self.current_performance), x + 20, y, 0, text_scale * 1.2, text_scale * 1.2)

    -- Compare with previous best
    y = y + line_height * 2
    if self.current_performance > self.previous_best then
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("NEW RECORD!", x, y, 0, text_scale * 1.3, text_scale * 1.3); y = y + line_height
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Previous best: " .. math.floor(self.previous_best), x, y, 0, text_scale, text_scale)
        love.graphics.print("Improvement: +" .. math.floor(self.current_performance - self.previous_best), x, y + line_height, 0, text_scale, text_scale)

        if #self.auto_completed_games > 0 then
            y = y + line_height * 2
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("AUTO-COMPLETION!", x, y, 0, text_scale * 1.2, text_scale * 1.2); y = y + line_height
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Completed " .. #self.auto_completed_games .. " variants!", x, y, 0, text_scale, text_scale); y = y + line_height
            love.graphics.print("Power gained: +" .. math.floor(self.auto_complete_power), x, y, 0, text_scale, text_scale)
        end
    else
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("Best: " .. math.floor(self.previous_best), x, y, 0, text_scale, text_scale); y = y + line_height
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Try again to beat your record!", x, y, 0, text_scale, text_scale)
    end

    -- Instructions
    love.graphics.setColor(1, 1, 1)
    y = vpHeight * 0.85
    love.graphics.printf("Press ENTER to play again", 0, y, vpWidth, "center", 0, text_scale, text_scale)
    love.graphics.printf("Press ESC to close window", 0, y + line_height, vpWidth, "center", 0, text_scale, text_scale)

    love.graphics.pop() -- Restore graphics state after drawing overlay
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
    print("Awarded " .. tokens_earned .. " tokens for completing " .. (self.game_data and self.game_data.display_name or "Unknown Game"))
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
        if self.current_game then
            if key == 'escape' then
                return { type = "close_window" }
            else
                if self.current_game.keypressed then
                    local game_handled = false
                    local success, result = pcall(self.current_game.keypressed, self.current_game, key)
                    if success then game_handled = result
                    else print("Error in game keypressed for " .. (self.game_data and self.game_data.id or "unknown") .. ": " .. tostring(result)) end
                    return game_handled and { type = "content_interaction" } or false
                end
            end
        else
             if key == 'escape' then return { type = "close_window" } end
        end
    end
    return false
end

function MinigameState:mousepressed(x, y, button)
    if not self.window_manager or self.window_id ~= self.window_manager:getFocusedWindowId() then
        return false
    end

    if not self.completion_screen_visible then
        if self.current_game and self.current_game.mousepressed then
            -- Transform coordinates ONLY if scale is valid
            if not self.viewport or self.canvasScale == nil or self.canvasScale <= 0 then return false end

            local canvas_x = (x - self.canvasOffsetX) / self.canvasScale
            local canvas_y = (y - self.canvasOffsetY) / self.canvasScale

            -- Check if click is within the rendered canvas bounds before passing
            if canvas_x >= 0 and canvas_x <= self.nativeGameWidth and
               canvas_y >= 0 and canvas_y <= self.nativeGameHeight then
                local success, result = pcall(self.current_game.mousepressed, self.current_game, canvas_x, canvas_y, button)
                if not success then
                     print("Error in game mousepressed for " .. (self.game_data and self.game_data.id or "unknown") .. ": " .. tostring(result))
                end
                return { type = "content_interaction" }
            end
        end
    end
    return false
end


function MinigameState:leave()
    if self.gameCanvas and not self.gameCanvas:isReleased() then
        self.gameCanvas:release()
        self.gameCanvas = nil
    end
    print("MinigameState leaving for window ID: " .. tostring(self.window_id) .. ", Canvas released.")
end

return MinigameState