-- main.lua
package.path = "./src/?.lua;" .. "./lib/?.lua;" .. package.path

local Object = require('class')
local json = require('json')

-- Local systems
local player_data = nil
local game_data = nil
local vm_manager = nil
local state_machine = nil
local SaveManager = nil
local cheat_system = nil
local SettingsManager = nil
local statistics = nil -- Keep local instance
local current_state_name = nil

function love.load()
    print("=== Starting love.load() ===")

    -- Require necessary classes/modules
    local PlayerData = require('models.player_data')
    local GameData = require('models.game_data')
    SaveManager = require('utils.save_manager')
    local VMManager = require('models.vm_manager')
    local StateMachineBuilder = require('controllers.state_machine')
    local CheatSystem = require('models.cheat_system')
    local Config = require('src.config')
    SettingsManager = require('utils.settings_manager')
    local Statistics = require('models.statistics')

    -- Load settings FIRST
    SettingsManager.load()

    -- Instantiate Statistics FIRST
    statistics = Statistics:new()
    statistics:load() -- Load existing stats

    -- Instantiate other main systems, injecting statistics into PlayerData
    player_data = PlayerData:new(statistics) -- Inject statistics
    game_data = GameData:new()
    vm_manager = VMManager:new()
    cheat_system = CheatSystem:new()

    -- Check tutorial flag *once* at startup
    local show_tutorial_on_startup = not SettingsManager.get("tutorial_shown")

    -- Load save data
    local saved_data = SaveManager.load()
    if saved_data then
        print("Loading saved game...")
        for key, value in pairs(saved_data) do
            if player_data[key] ~= nil then
               player_data[key] = value
            elseif key == 'cheat_engine_data' then
                 if type(value) == 'table' then
                     player_data[key] = value
                 else
                     print("Warning: Ignoring invalid cheat_engine_data from save.")
                     player_data[key] = {}
                 end
            else
                print("Warning: Unknown key in save data ignored: " .. key)
            end
        end
        player_data.unlocked_games = player_data.unlocked_games or {}
        player_data.completed_games = player_data.completed_games or {}
        player_data.game_performance = player_data.game_performance or {}
        player_data.active_vms = player_data.active_vms or {}
        player_data.cheat_engine_data = player_data.cheat_engine_data or {}
        player_data.upgrades = player_data.upgrades or { cpu_speed=0, overclock=0, auto_dodge=0 }
    else
        print("No save found, starting new game")
        player_data:addTokens(Config.start_tokens)
    end

    vm_manager:initialize(player_data)

    -- Create and set up state machine
    local StateMachine = StateMachineBuilder(Object)
    state_machine = StateMachine:new()

    -- Require state classes
    local LauncherState = require('states.launcher_state')
    local MinigameState = require('states.minigame_state')
    local SpaceDefenderState = require('states.space_defender_state')
    local VMManagerState = require('states.vm_manager_state')
    local DesktopState = require('states.desktop_state')
    local DebugState = require('states.debug_state')
    local CheatEngineState = require('states.cheat_engine_state')
    local SettingsState = require('states.settings_state')
    local StatisticsState = require('states.statistics_state')
    local CompletionState = require('states.completion_state')

    -- Instantiate states (Inject statistics where needed)
    local launcher = LauncherState:new(player_data, game_data, state_machine, SaveManager)
    local minigame = MinigameState:new(player_data, game_data, state_machine, SaveManager, cheat_system)
    -- Inject statistics into SpaceDefenderState (it will pass it to BulletSystem)
    local space_defender = SpaceDefenderState:new(player_data, game_data, state_machine, SaveManager, statistics) -- Use lowercase 's'
    local vm_manager_state = VMManagerState:new(vm_manager, player_data, game_data, state_machine, SaveManager)
    -- Inject statistics into DesktopState
    local desktop = DesktopState:new(state_machine, player_data, show_tutorial_on_startup, statistics)
    local debug_state = DebugState:new(player_data, game_data, state_machine, SaveManager)
    local cheat_engine = CheatEngineState:new(player_data, game_data, state_machine, SaveManager, cheat_system)
    local settings = SettingsState:new(state_machine)
    -- Inject statistics into StatisticsState
    local statistics_state = StatisticsState:new(state_machine, statistics)
    -- Inject statistics into CompletionState
    local completion_state = CompletionState:new(state_machine, statistics)


    -- Register states
    state_machine:register('launcher', launcher)
    state_machine:register('minigame', minigame)
    -- Corrected registration: Use the actual variable name 'space_defender' (lowercase s)
    state_machine:register('space_defender', space_defender)
    state_machine:register('vm_manager', vm_manager_state)
    state_machine:register('desktop', desktop)
    state_machine:register('debug', debug_state)
    state_machine:register('cheat_engine', cheat_engine)
    state_machine:register('settings', settings)
    state_machine:register('statistics', statistics_state)
    state_machine:register('completion', completion_state)

    print("Starting game - switching to desktop")
    current_state_name = 'desktop'
    state_machine:switch(current_state_name)

    print("=== love.load() completed ===")
end

local auto_save_timer = 0
local AUTO_SAVE_INTERVAL = 30

function love.update(dt)
    -- Increment playtime stat
    if statistics then
        statistics:addPlaytime(dt)
    end

    if vm_manager and player_data and game_data then
        vm_manager:update(dt, player_data, game_data)
    end
    if state_machine then
        state_machine:update(dt)
    end

    -- Auto-save logic (Save player data and stats)
    auto_save_timer = auto_save_timer + dt
    if auto_save_timer >= AUTO_SAVE_INTERVAL then
        auto_save_timer = auto_save_timer - AUTO_SAVE_INTERVAL
        if SaveManager and player_data then
            local success, err = SaveManager.save(player_data)
            if not success then print("Auto-save failed (Player Data): " .. tostring(err)) end
        end
        if statistics then
             local success_stats, err_stats = statistics:save()
             if not success_stats then print("Auto-save failed (Statistics): " .. tostring(err_stats)) end
        end
    end
end

function love.draw()
    love.graphics.clear(0.2, 0.2, 0.2)
    if state_machine then
        state_machine:draw()
    else
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("ERROR: No state machine loaded", 10, 10)
    end
end

local function switchState(new_state, ...)
    if state_machine and state_machine.states[new_state] then
        print("Switching state to: " .. new_state)
        current_state_name = new_state
        state_machine:switch(new_state, ...)
    else
        -- Print the actual error here for clarity
        print("Error: Attempted to switch to unknown state: " .. tostring(new_state))
    end
end

function love.keypressed(key, scancode, isrepeat)
    if not state_machine or not player_data then return end

    if key == 'f5' then
        if current_state_name == 'debug' then
             if state_machine.current_state and state_machine.current_state.keypressed then
                 state_machine.current_state:keypressed(key)
             end
        else
            switchState('debug', current_state_name)
        end
        return
    end

    if current_state_name ~= 'debug' then
        if key == '-' then
            local amount_to_remove = 5000
            if player_data:spendTokens(amount_to_remove) then
                print("Debug: Removed " .. amount_to_remove .. " tokens. Total: " .. player_data.tokens)
            else
                print("Debug: Tried to remove tokens, but not enough. Total: " .. player_data.tokens)
            end
            return true
        elseif key == '=' then
            player_data:addTokens(5000)
            print("Debug: Added 5000 tokens. Total: " .. player_data.tokens)
            return true
        end
    end

    local handled = false
    if state_machine.current_state and state_machine.current_state.keypressed then
       handled = state_machine.current_state:keypressed(key)
    end

    if not handled and current_state_name ~= 'debug' then
        if key == 'escape' then
             if current_state_name ~= 'completion' then
                 love.event.quit()
             end
        elseif current_state_name ~= 'minigame' and current_state_name ~= 'space_defender' then
            if key == 'f1' then
                switchState('launcher')
                handled = true
            elseif key == 'f2' then
                switchState('vm_manager')
                handled = true
            elseif key == 'f3' then
                 switchState('space_defender', 1)
                 handled = true
            elseif key == 'f4' then
                 switchState('cheat_engine')
                 handled = true
            elseif key == 'f6' then
                 local return_state = current_state_name
                 if return_state == 'statistics' then return_state = 'desktop' end
                 switchState('statistics', return_state)
                 handled = true
            end
        end
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if state_machine then
        state_machine:mousepressed(x, y, button)
    end
end

function love.textinput(text)
    if state_machine and state_machine.current_state and state_machine.current_state.textinput then
        state_machine.current_state:textinput(text)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if state_machine and state_machine.current_state and state_machine.current_state.mousereleased then
        state_machine.current_state:mousereleased(x, y, button)
    end
end

function love.wheelmoved(x, y)
    if state_machine and state_machine.current_state and state_machine.current_state.wheelmoved then
        state_machine.current_state:wheelmoved(x, y)
    end
end

function love.quit()
    print("Saving statistics on quit...")
    if statistics then
        local success, err = statistics:save()
        if not success then print("Error saving stats on quit: " .. tostring(err)) end
    end
    print("Exiting game.")
end

function love.errorhandler(msg)
    print("ERROR:", msg)
    print(debug.traceback())
    return function()
        love.graphics.origin()
        love.graphics.setBackgroundColor(0.2, 0.2, 0.2)
        love.graphics.clear()
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("ERROR:\n" .. tostring(msg) .. "\n\n" .. debug.traceback(),
            10, 10, love.graphics.getWidth() - 20, "left")
    end
end