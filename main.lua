-- main.lua
package.path = "./src/?.lua;" .. "./lib/?.lua;" .. package.path

local Object = require('class')
local json = require('json')

-- Global systems needed by DesktopState launch logic
local player_data = nil
local game_data = nil
local vm_manager = nil
local state_machine = nil
local SaveManager = nil
local cheat_system = nil
local SettingsManager = nil
local statistics = nil
local program_registry = nil
local window_manager = nil
local desktop_icons = nil
local file_system = nil
local recycle_bin = nil

-- Keep track of current state name for debug toggle
local current_state_name = nil

function love.load()
    print("=== Starting love.load() ===")

    -- Require necessary classes/modules FIRST
    local PlayerData = require('models.player_data')
    local GameData = require('models.game_data')
    SaveManager = require('utils.save_manager') -- Assign to global
    local VMManager = require('models.vm_manager')
    local StateMachineBuilder = require('controllers.state_machine')
    local CheatSystem = require('models.cheat_system')
    local Config = require('src.config')
    SettingsManager = require('utils.settings_manager') -- Assign to global
    local Statistics = require('models.statistics')
    local WindowManager = require('models.window_manager')
    local DesktopIcons = require('models.desktop_icons')
    local FileSystem = require('models.file_system')
    local RecycleBin = require('models.recycle_bin')
    local ProgramRegistry = require('models.program_registry')


    -- Load settings FIRST
    SettingsManager.load()

    -- Instantiate Statistics FIRST
    statistics = Statistics:new() -- Assign to global
    statistics:load()

    -- Instantiate other main systems, injecting statistics into PlayerData
    player_data = PlayerData:new(statistics) -- Assign to global
    game_data = GameData:new() -- Assign to global
    vm_manager = VMManager:new() -- Assign to global
    cheat_system = CheatSystem:new() -- Assign to global

    -- Check tutorial flag *once* at startup
    local show_tutorial_on_startup = not SettingsManager.get("tutorial_shown")

    -- Load save data
    local saved_data = SaveManager.load()
    if saved_data then
        print("Loading saved game...")
        -- Basic loading logic (consider a dedicated function in PlayerData?)
        for key, value in pairs(saved_data) do
            if player_data[key] ~= nil then
               player_data[key] = value
            elseif key == 'cheat_engine_data' then -- Handle specific nested tables
                 if type(value) == 'table' then player_data[key] = value
                 else print("Warning: Ignoring invalid cheat_engine_data from save."); player_data[key] = {} end
            else
                print("Warning: Unknown key in save data ignored: " .. key)
            end
        end
        -- Ensure required tables exist after loading potentially old save
        player_data.unlocked_games = player_data.unlocked_games or {}
        player_data.completed_games = player_data.completed_games or {}
        player_data.game_performance = player_data.game_performance or {}
        player_data.active_vms = player_data.active_vms or {}
        player_data.cheat_engine_data = player_data.cheat_engine_data or {}
        player_data.upgrades = player_data.upgrades or { cpu_speed=0, overclock=0, auto_dodge=0 }
    else
        print("No save found, starting new game")
        player_data:addTokens(Config.start_tokens)
        -- Ensure required tables exist for new game
        player_data.unlocked_games = {}
        player_data.completed_games = {}
        player_data.game_performance = {}
        player_data.active_vms = {}
        player_data.cheat_engine_data = {}
        player_data.upgrades = { cpu_speed=0, overclock=0, auto_dodge=0 }
    end

    -- Initialize VM Manager *after* player data is loaded/initialized
    vm_manager:initialize(player_data)

    -- Initialize Windowing/Desktop system models
    window_manager = WindowManager:new() -- Assign to global
    desktop_icons = DesktopIcons:new() -- Assign to global
    file_system = FileSystem:new() -- Assign to global
    recycle_bin = RecycleBin:new(desktop_icons) -- Assign to global, inject dependency
    program_registry = ProgramRegistry:new() -- Assign to global

    print("Initialized windowing system models")

    -- Create and set up state machine
    local StateMachine = StateMachineBuilder(Object)
    state_machine = StateMachine:new() -- Assign to global

    -- Require state classes (just before instantiation)
    local LauncherState = require('states.launcher_state')
    local MinigameState = require('states.minigame_state')
    local SpaceDefenderState = require('states.space_defender_state')
    local VMManagerState = require('states.vm_manager_state')
    local DesktopState = require('states.desktop_state')
    local DebugState = require('states.debug_state')
    local CheatEngineState = require('states.cheat_engine_state')
    local SettingsState = require('states.settings_state') -- Fullscreen version (might not be used)
    local StatisticsState = require('states.statistics_state')
    local CompletionState = require('states.completion_state')
    -- Note: SettingsStateWindowed is required inside DesktopState:launchProgram

    -- Instantiate states, passing necessary dependencies
    -- Minigame state still launches fullscreen for now
    local minigame = MinigameState:new(player_data, game_data, state_machine, SaveManager, cheat_system)
    local completion_state = CompletionState:new(state_machine, statistics) -- Fullscreen for now
    local debug_state = DebugState:new(player_data, game_data, state_machine, SaveManager) -- Overlay state

    -- Desktop state now needs more dependencies for launching programs
    local desktop = DesktopState:new(state_machine, player_data, show_tutorial_on_startup, statistics,
                                     window_manager, desktop_icons, file_system, recycle_bin, program_registry,
                                     vm_manager, cheat_system, SaveManager, game_data) -- Pass globals


    -- Register states that are still switched to globally
    state_machine:register('minigame', minigame) -- For launching from Cheat Engine/Launcher windows
    state_machine:register('completion', completion_state) -- Launched from Space Defender window signal
    state_machine:register('debug', debug_state) -- Launched via F5
    state_machine:register('desktop', desktop) -- Initial state

    -- States launched as windows are instantiated *by* DesktopState, not registered globally here
    -- (Launcher, VMManager, SpaceDefender, CheatEngine, Settings, Statistics)

    print("Starting game - switching to desktop")
    current_state_name = 'desktop'
    state_machine:switch(current_state_name)

    print("=== love.load() completed ===")
end

local auto_save_timer = 0
local AUTO_SAVE_INTERVAL = 30

function love.update(dt)
    -- Update global systems if they exist
    if statistics then statistics:addPlaytime(dt) end

    -- VM Manager needs to run even if DesktopState isn't the active *state machine* state
    -- (e.g., if a fullscreen minigame is running)
    if vm_manager and player_data and game_data then
        vm_manager:update(dt, player_data, game_data)
    end

    -- Update the core state machine (handles Desktop, Minigame, Completion, Debug)
    if state_machine then
        state_machine:update(dt)
    end

    -- Auto-save logic remains the same
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
        -- Save window/desktop state periodically too
        if desktop_icons then desktop_icons:save() end
        if window_manager then window_manager:saveWindowPositions() end
    end
end

function love.draw()
    -- Base background color (might be overridden by desktop wallpaper)
    love.graphics.clear(0.2, 0.2, 0.2)

    -- The active state machine state draws. If it's DesktopState, it handles drawing windows.
    if state_machine then
        state_machine:draw()
    else
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("ERROR: No state machine loaded", 10, 10)
    end
end

-- Helper function remains for switching fullscreen states (Minigame, Completion, Debug)
local function switchState(new_state, ...)
    if state_machine and state_machine.states[new_state] then
        print("Switching state to: " .. new_state)
        current_state_name = new_state
        state_machine:switch(new_state, ...)
    else
        print("Error: Attempted to switch to unknown state: " .. tostring(new_state))
    end
end

function love.keypressed(key, scancode, isrepeat)
    if not state_machine or not player_data then return end

    -- Debug toggle key (F5) - Switches between 'desktop' and 'debug' states
    if key == 'f5' then
        if current_state_name == 'debug' then
             -- If in debug, tell it to close (which switches back)
             if state_machine.current_state and state_machine.current_state.keypressed then
                 state_machine.current_state:keypressed(key) -- Debug state handles F5 to close
             end
        elseif current_state_name == 'desktop' then -- Only allow opening from desktop
            switchState('debug', current_state_name)
        end
        return -- Consume F5
    end

    -- Global debug keys (only if not in debug state already)
    if current_state_name ~= 'debug' then
        if key == '-' then
            if player_data:spendTokens(5000) then print("Debug: Removed 5000 tokens.") else print("Debug: Not enough tokens.") end
            return -- Consume key
        elseif key == '=' then
            player_data:addTokens(5000); print("Debug: Added 5000 tokens.")
            return -- Consume key
        end
    end

    -- Forward keypress to the current *state machine* state
    -- If the current state is DesktopState, it will handle forwarding to the focused *window* state
    if state_machine.current_state and state_machine.current_state.keypressed then
       local handled = state_machine.current_state:keypressed(key)
       -- If state returns true or an event table, it handled it.
       if handled then return end
    end

    -- If not handled by active state (or window within DesktopState), check global fallbacks
    -- (Removed old F1-F6 shortcuts as programs are launched via desktop now)
    -- (Removed global ESC quit, DesktopState handles it contextually)
end

function love.mousepressed(x, y, button, istouch, presses)
    -- Forward mouse press to the current state machine state
    if state_machine and state_machine.current_state and state_machine.current_state.mousepressed then
        state_machine.current_state:mousepressed(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    -- Forward mouse move to the current state machine state
    if state_machine and state_machine.current_state and state_machine.current_state.mousemoved then
        state_machine.current_state:mousemoved(x, y, dx, dy)
    end
end

function love.textinput(text)
    -- Forward text input to the current state machine state
    if state_machine and state_machine.current_state and state_machine.current_state.textinput then
        state_machine.current_state:textinput(text)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
     -- Forward mouse release to the current state machine state
    if state_machine and state_machine.current_state and state_machine.current_state.mousereleased then
        state_machine.current_state:mousereleased(x, y, button)
    end
end

function love.wheelmoved(x, y)
     -- Forward wheel move to the current state machine state
    if state_machine and state_machine.current_state and state_machine.current_state.wheelmoved then
        state_machine.current_state:wheelmoved(x, y)
    end
end

function love.quit()
    print("Saving game state on quit...")
    -- Ensure all necessary saves happen
    if SaveManager and player_data then SaveManager.save(player_data) end
    if statistics then statistics:save() end
    if desktop_icons then desktop_icons:save() end
    if window_manager then window_manager:saveWindowPositions() end

    print("Exiting game.")
end

function love.errorhandler(msg)
    print("ERROR:", msg)
    print(debug.traceback())
    -- Try to save before showing error screen? Risky if error is in saving...
    -- love.quit() -- Call save logic

    return function()
        -- Basic error screen drawing
        love.graphics.origin()
        love.graphics.setBackgroundColor(0.2, 0, 0) -- Reddish background
        love.graphics.clear()
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("FATAL ERROR:\n" .. tostring(msg) .. "\n\n" .. debug.traceback(),
            10, 10, love.graphics.getWidth() - 20, "left")
    end
end