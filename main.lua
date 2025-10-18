-- main.lua: Main entry point for the game

-- Set up package paths to find our modules
package.path = "./src/?.lua;" .. "./lib/?.lua;" .. package.path

-- Required core modules
local Object = require('class')
local json = require('json')

-- Global game state
_G.game = {
    state_machine = nil,
    player_data = nil,
    game_data = nil,
    save_manager = nil,
    vm_manager = nil,
    Object = Object,
    JSON = json
}

-- Love2D callback: Initialize game
function love.load()
    print("=== Starting love.load() ===")
    
    -- Load models
    local PlayerData = require('models.player_data')
    local GameData = require('models.game_data')
    local SaveManager = require('utils.save_manager')
    local VMManager = require('models.vm_manager')
    
    -- Initialize game data
    game.player_data = PlayerData:new()
    game.game_data = GameData:new()
    game.save_manager = SaveManager
    game.vm_manager = VMManager:new()
    
    -- Try to load saved game
    local saved_data = SaveManager.load()
    if saved_data then
        print("Loading saved game...")
        -- Restore player data from save
        for key, value in pairs(saved_data) do
            game.player_data[key] = value
        end
    else
        print("No save found, starting new game")
        -- Give starting tokens
        game.player_data:addTokens(500)
    end
    
    -- Initialize VM Manager with player data
    game.vm_manager:initialize(game.player_data)
    
    -- Load state machine
    local StateMachine = require('controllers.state_machine')(Object)
    game.state_machine = StateMachine:new()
    
    -- Create and initialize states
    local LauncherState = require('states.launcher_state')
    local MinigameState = require('states.minigame_state')
    local SpaceDefenderState = require('states.space_defender_state')
    local VMManagerState = require('states.vm_manager_state')
    
    local launcher = LauncherState:new()
    local minigame = MinigameState:new()
    local space_defender = SpaceDefenderState:new()
    local vm_manager_state = VMManagerState:new()
    
    -- Register states
    game.state_machine:register('launcher', launcher)
    game.state_machine:register('minigame', minigame)
    game.state_machine:register('space_defender', space_defender)
    game.state_machine:register('vm_manager', vm_manager_state)
    
    -- Start with launcher
    print("Starting game - switching to launcher")
    game.state_machine:switch('launcher')
    
    print("=== love.load() completed ===")
end

-- Love2D callback: Game logic updates
function love.update(dt)
    -- Always update VM manager (background token generation)
    if game.vm_manager and game.player_data and game.game_data then
        game.vm_manager:update(dt, game.player_data, game.game_data)
    end
    
    -- Update current state
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

-- Love2D callback: Mouse wheel
function love.wheelmoved(x, y)
    if game.state_machine and game.state_machine.current_state and game.state_machine.current_state.wheelmoved then
        game.state_machine.current_state:wheelmoved(x, y)
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