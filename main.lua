-- main.lua: Main entry point for the game

-- Set up package paths to find our modules
package.path = "./src/?.lua;" .. "./lib/?.lua;" .. package.path

-- Required core modules
local Object = require('class')
local StateMachine = require('controllers.state_machine')(Object)
local MinigameState = require('states.minigame_state')
local LauncherState = require('states.launcher_state')

-- Global game state
_G.game = {
    state_machine = nil,
    player_data = nil,
    game_data = nil,
    Object = nil,      -- Will store the class system
    JSON = nil         -- Will store the JSON library
}

-- Love2D callback: Initialize game
function love.load()
    print("=== Starting love.load() ===")
    
    -- Load core libraries from lib/
    game.Object = Object  -- Already loaded above
    game.JSON = require('json')
    
    -- Create state machine
    game.state_machine = StateMachine:new()
    
    -- Create and initialize states
    local launcher = LauncherState:new()
    launcher.state_machine = game.state_machine
    
    local minigame = MinigameState:new()
    minigame.state_machine = game.state_machine
    
    -- Register states
    game.state_machine:register('launcher', launcher)
    game.state_machine:register('minigame', minigame)
    
    -- Start with launcher
    print("Starting game - switching to launcher")
    game.state_machine:switch('launcher')
    
    print("=== love.load() completed ===")
end

-- Love2D callback: Game logic updates
function love.update(dt)
    if game.state_machine then
        game.state_machine:update(dt)
    end
end

-- Love2D callback: Rendering
function love.draw()
    -- Clear background to dark gray
    love.graphics.clear(0.2, 0.2, 0.2)
    
    if game.state_machine then
        game.state_machine:draw()
    else
        -- If no state machine, draw error text
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("ERROR: No state machine", 10, 10)
    end
end

-- Love2D callback: Keyboard input
function love.keypressed(key, scancode, isrepeat)
    if key == 'escape' then
        if game.state_machine and game.state_machine.current_state then
            game.state_machine.current_state:keypressed(key)
        else
            love.event.quit()
        end
    elseif game.state_machine then
        game.state_machine:keypressed(key)
    end
end

-- Love2D callback: Mouse input
function love.mousepressed(x, y, button, istouch, presses)
    if game.state_machine then
        game.state_machine:mousepressed(x, y, button)
    end
end

-- Love2D callback: Error handling
function love.errorhandler(msg)
    -- Print to console first
    print("ERROR:", msg)
    print(debug.traceback())
    
    -- Return a function that draws the error screen
    return function()
        love.graphics.setBackgroundColor(0.2, 0.2, 0.2)
        love.graphics.clear()
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("ERROR:\n" .. tostring(msg) .. "\n\n" .. debug.traceback(),
            10, 10, love.graphics.getWidth() - 20)
    end
end
