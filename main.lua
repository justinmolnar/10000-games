package.path = "./src/?.lua;" .. "./lib/?.lua;" .. package.path

local Object = require('class')
local json = require('json')

local game_context = nil

function love.load()
    print("=== Starting love.load() ===")
    
    local GameContext = require('models.game_context')
    local PlayerData = require('models.player_data')
    local GameData = require('models.game_data')
    local SaveManager = require('utils.save_manager')
    local VMManager = require('models.vm_manager')
    
    game_context = GameContext:new()
    
    local player_data = PlayerData:new()
    local game_data = GameData:new()
    local vm_manager = VMManager:new()
    
    game_context:setPlayerData(player_data)
    game_context:setGameData(game_data)
    game_context:setSaveManager(SaveManager)
    game_context:setVMManager(vm_manager)
    
    local saved_data = SaveManager.load()
    if saved_data then
        print("Loading saved game...")
        for key, value in pairs(saved_data) do
            player_data[key] = value
        end
    else
        print("No save found, starting new game")
        player_data:addTokens(500)
    end
    
    vm_manager:initialize(player_data)
    
    local StateMachine = require('controllers.state_machine')(Object)
    local state_machine = StateMachine:new()
    game_context:setStateMachine(state_machine)
    
    local LauncherState = require('states.launcher_state')
    local MinigameState = require('states.minigame_state')
    local SpaceDefenderState = require('states.space_defender_state')
    local VMManagerState = require('states.vm_manager_state')
    local DesktopState = require('states.desktop_state')
    
    local launcher = LauncherState:new(game_context)
    local minigame = MinigameState:new(game_context)
    local space_defender = SpaceDefenderState:new(game_context)
    local vm_manager_state = VMManagerState:new(game_context)
    local desktop = DesktopState:new(game_context)
    
    state_machine:register('launcher', launcher)
    state_machine:register('minigame', minigame)
    state_machine:register('space_defender', space_defender)
    state_machine:register('vm_manager', vm_manager_state)
    state_machine:register('desktop', desktop)
    
    print("Starting game - switching to desktop")
    state_machine:switch('desktop')
    
    print("=== love.load() completed ===")
end

function love.update(dt)
    if game_context and game_context.vm_manager and game_context.player_data and game_context.game_data then
        game_context.vm_manager:update(dt, game_context.player_data, game_context.game_data)
    end
    
    if game_context and game_context.state_machine then
        game_context.state_machine:update(dt)
    end
end

function love.draw()
    love.graphics.clear(0.2, 0.2, 0.2)
    
    if game_context and game_context.state_machine then
        game_context.state_machine:draw()
    else
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("ERROR: No state machine", 10, 10)
    end
end

function love.keypressed(key, scancode, isrepeat)
    if not game_context or not game_context.state_machine then return end
    
    if key == 'escape' then
        if game_context.state_machine.current_state then
            game_context.state_machine.current_state:keypressed(key)
        else
            love.event.quit()
        end
    elseif key == 'f1' then
        local current = game_context.state_machine.current_state
        if current and current.__name ~= 'MinigameState' and current.__name ~= 'SpaceDefenderState' then
            game_context.state_machine:switch('launcher')
        end
    elseif key == 'f2' then
        local current = game_context.state_machine.current_state
        if current and current.__name ~= 'MinigameState' and current.__name ~= 'SpaceDefenderState' then
            game_context.state_machine:switch('vm_manager')
        end
    elseif key == 'f3' then
        local current = game_context.state_machine.current_state
        if current and current.__name ~= 'MinigameState' and current.__name ~= 'SpaceDefenderState' then
            game_context.state_machine:switch('space_defender', 1)
        end
    else
        game_context.state_machine:keypressed(key)
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if game_context and game_context.state_machine then
        game_context.state_machine:mousepressed(x, y, button)
    end
end

function love.wheelmoved(x, y)
    if game_context and game_context.state_machine and game_context.state_machine.current_state and game_context.state_machine.current_state.wheelmoved then
        game_context.state_machine.current_state:wheelmoved(x, y)
    end
end

function love.errorhandler(msg)
    print("ERROR:", msg)
    print(debug.traceback())
    
    return function()
        love.graphics.setBackgroundColor(0.2, 0.2, 0.2)
        love.graphics.clear()
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("ERROR:\n" .. tostring(msg) .. "\n\n" .. debug.traceback(),
            10, 10, love.graphics.getWidth() - 20)
    end
end