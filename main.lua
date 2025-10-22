-- main.lua
package.path = "./src/?.lua;" .. "./lib/?.lua;" .. package.path

local Object = require('class')
local Constants = require('src.constants')
local json = require('json')

-- Global systems needed by DesktopState launch logic and love callbacks
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

-- Global storage for cursors
local system_cursors = {}

-- Removed per-state-name tracking; state changes are handled by the StateMachine

function love.load()
    print("=== Starting love.load() ===")

    -- Create standard system cursors
    local cursor_types = {"arrow", "ibeam", "wait", "crosshair", "waitarrow", "sizenwse", "sizenesw", "sizewe", "sizens", "sizeall", "no", "hand"}
    for _, type in ipairs(cursor_types) do
        local success, cursor = pcall(love.mouse.getSystemCursor, type)
        if success and cursor then
            system_cursors[type] = cursor
        else
            print("Warning: Could not get system cursor for type:", type)
            if not system_cursors["arrow"] then
                 local success_arrow, arrow_cursor = pcall(love.mouse.getSystemCursor, "arrow")
                 if success_arrow then system_cursors["arrow"] = arrow_cursor end
            end
            system_cursors[type] = system_cursors["arrow"] -- Fallback
        end
    end
    if system_cursors["arrow"] then love.mouse.setCursor(system_cursors["arrow"]) end

    -- Enable key repeat
    if love.keyboard and love.keyboard.setKeyRepeat then love.keyboard.setKeyRepeat(true) end

    -- == 1. Require Modules ==
    local PlayerData = require('models.player_data')
    local GameData = require('models.game_data')
    SaveManager = require('utils.save_manager')
    local VMManager = require('models.vm_manager')
    local StateMachineBuilder = require('controllers.state_machine')
    local CheatSystem = require('models.cheat_system')
    local Config = require('src.config')
    SettingsManager = require('src.utils.settings_manager')
    local Statistics = require('models.statistics')
    local WindowManager = require('models.window_manager')
    local DesktopIcons = require('models.desktop_icons')
    local FileSystem = require('models.file_system')
    local RecycleBin = require('models.recycle_bin')
    local ProgramRegistry = require('models.program_registry')
    SpriteLoader = require('src.utils.sprite_loader')
    local PaletteManager = require('src.utils.palette_manager')
    local SpriteManager = require('src.utils.sprite_manager')
    local EventBus = require('src.utils.event_bus')

    -- == 2. Initialize Core Systems & DI Container ==
    SettingsManager.inject({ config = Config }) -- Inject config into SettingsManager early
    SettingsManager.load() -- Load settings after config injection

    statistics = Statistics:new()
    statistics:load()

    local event_bus = EventBus:new()
    local di = {
        config = Config,
        settingsManager = SettingsManager,
        saveManager = SaveManager,
        statistics = statistics,
        eventBus = event_bus,
        systemCursors = system_cursors,
        -- screen size can be added here if needed initially
    }

    -- == 3. Instantiate Models with DI ==
    player_data = PlayerData:new(statistics, di) -- Pass full di container
    di.playerData = player_data
    game_data = GameData:new(di)
    di.gameData = game_data
    vm_manager = VMManager:new(di)
    di.vmManager = vm_manager
    cheat_system = CheatSystem:new()
    di.cheatSystem = cheat_system

    window_manager = WindowManager:new(di)
    di.windowManager = window_manager
    desktop_icons = DesktopIcons:new(di)
    di.desktopIcons = desktop_icons
    file_system = FileSystem:new(di)
    di.fileSystem = file_system
    recycle_bin = RecycleBin:new(desktop_icons, di)
    di.recycleBin = recycle_bin
    program_registry = ProgramRegistry:new()
    di.programRegistry = program_registry

    -- == 4. Load Save Data ==
    -- Inject DI into SaveManager before loading (Phase 4.9/4.10 change)
    if SaveManager and SaveManager.inject then SaveManager.inject(di) end
    -- Load function now publishes events internally
    local saved_player_data = SaveManager.load()
    if saved_player_data then
        print("Loading saved game...")
        -- Update player_data instance with loaded data
        player_data:init(statistics, di) -- Re-init to clear defaults before loading
        for key, value in pairs(saved_player_data) do
            if player_data[key] ~= nil then
               player_data[key] = value
            elseif key == 'cheat_engine_data' then
                 if type(value) == 'table' then player_data[key] = value
                 else print("Warning: Ignoring invalid cheat_engine_data from save."); player_data[key] = {} end
            else print("Warning: Unknown key in save data ignored: " .. key) end
        end
        -- Ensure tables exist after loading potentially minimal save data
        player_data.unlocked_games = player_data.unlocked_games or {}
        player_data.completed_games = player_data.completed_games or {}
        player_data.game_performance = player_data.game_performance or {}
        player_data.active_vms = player_data.active_vms or {}
        player_data.cheat_engine_data = player_data.cheat_engine_data or {}
        player_data.upgrades = player_data.upgrades or { cpu_speed=0, overclock=0, auto_dodge=0 }
    else
        print("No save found or load failed, starting new game")
        player_data:init(statistics, di) -- Ensure fresh init
        player_data:addTokens(Config.start_tokens) -- This will publish tokens_changed
    end

    vm_manager:initialize(player_data) -- Initialize VMs based on loaded/new player data


    -- == 5. Initialize Sprite Utilities ==
    local palette_manager = PaletteManager:new()
    local sprite_loader = SpriteLoader:new(palette_manager)
    sprite_loader:loadAll()
    local sprite_manager = SpriteManager:new(sprite_loader, palette_manager)
    di.paletteManager = palette_manager
    di.spriteLoader = sprite_loader
    di.spriteManager = sprite_manager

    -- == 6. Initialize State Machine and States ==
    -- Inject DI into SaveManager if it supports it (it does)
    -- Inject DI into SettingsManager (Phase 4.9 change)
    if SettingsManager and SettingsManager.inject then SettingsManager.inject(di) end

    local StateMachine = StateMachineBuilder(Object)
    state_machine = StateMachine:new(di)
    di.stateMachine = state_machine

    local CompletionState = require('states.completion_state')
    local DebugState = require('states.debug_state')
    local DesktopState = require('states.desktop_state')
    local ScreensaverState = require('states.screensaver_state')

    local completion_state = CompletionState:new(state_machine, statistics)
    local debug_state = DebugState:new(di) -- Pass DI to DebugState
    local screensaver_state = ScreensaverState:new(state_machine)
    local desktop = DesktopState:new(di)
    desktop.cursors = system_cursors -- Pass cursors directly for now

    state_machine:register(Constants.state.COMPLETION, completion_state)
    state_machine:register(Constants.state.DEBUG, debug_state)
    state_machine:register(Constants.state.DESKTOP, desktop)
    state_machine:register(Constants.state.SCREENSAVER, screensaver_state)

    -- == 7. Start Game ==
    print("Starting game - switching to desktop")
    state_machine:switch(Constants.state.DESKTOP)

    print("=== love.load() completed ===")
end

local auto_save_timer = 0
local AUTO_SAVE_INTERVAL = 30

function love.update(dt)
    -- Update global systems if they exist
    if statistics then statistics:addPlaytime(dt) end

    -- VM Manager needs to run even if DesktopState isn't the active *state machine* state
    if vm_manager and player_data and game_data then
        vm_manager:update(dt, player_data, game_data)
    end

    -- Update the core state machine (handles Desktop, Completion, Debug)
    if state_machine then
        state_machine:update(dt)
        -- Cursor setting is now handled within DesktopState:update
    end

    -- Auto-save logic
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
        -- Window positions are saved on window close and game quit now
        -- if window_manager then window_manager:saveWindowPositions() end
    end
end

function love.draw()
    -- Explicitly clear the entire screen with a background color FIRST
    love.graphics.clear(0, 0.5, 0.5, 1) -- Use the desktop wallpaper color or a neutral one

    -- The active state machine state draws. If it's DesktopState, it handles drawing windows.
    if state_machine then
        state_machine:draw()
    else
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("ERROR: No state machine loaded", 10, 10)
    end
end

-- All state switching is now handled within states; no global helper required

function love.keypressed(key, scancode, isrepeat)
    if not state_machine then return end
    -- Intercept Windows keys to toggle our Start Menu and prevent OS Start Menu from opening
    if key == 'lgui' or key == 'rgui' then
        -- Ask DesktopState to toggle the Start Menu
        local active = state_machine.current_state
        if active and active.toggleStartMenu then active:toggleStartMenu() end
        return -- Consume; prevents default behavior while game window has focus
    end
    -- Delegate to the active state via the StateMachine
    state_machine:keypressed(key)
end

function love.keyreleased(key)
    -- Consume Windows keys on release as well (prevents stray OS actions while focused)
    if key == 'lgui' or key == 'rgui' then return end
end

function love.mousepressed(x, y, button, istouch, presses)
    if state_machine then state_machine:mousepressed(x, y, button) end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if state_machine then state_machine:mousemoved(x, y, dx, dy) end
    -- Cursor setting happens in DesktopState:update based on WindowController state
end

function love.textinput(text)
    if state_machine then state_machine:textinput(text) end
end

function love.mousereleased(x, y, button, istouch, presses)
    if state_machine then state_machine:mousereleased(x, y, button) end
end

function love.wheelmoved(x, y)
    if state_machine then state_machine:wheelmoved(x, y) end
end

function love.quit()
    -- If quit wasn't explicitly allowed by the app, cancel it and show our shutdown dialog
    if not _G.APP_ALLOW_QUIT then
        -- Signal DesktopState to open shutdown dialog next frame
        _G.WANT_SHUTDOWN_DIALOG = true
        -- Cancel the default OS quit (e.g., Alt+F4 or window close button)
        return true
    end

    print("Saving game state on quit...")
    -- Ensure all necessary saves happen
    if SaveManager and player_data then SaveManager.save(player_data) end
    if statistics then statistics:save() end
    if desktop_icons then desktop_icons:save() end
    if window_manager then window_manager:saveWindowPositions() end -- Save window positions on quit

    print("Exiting game.")
    return false -- Allow LÖVE to close cleanly
end

function love.errorhandler(msg)
    print("ERROR:", msg)
    print(debug.traceback())
    -- Attempt a final save, wrapped in pcall in case saving is the problem
    pcall(love.quit)

    return function()
        -- Basic error screen drawing
        love.graphics.origin()
        love.graphics.setBackgroundColor(0.2, 0, 0)
        love.graphics.clear()
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("FATAL ERROR:\n" .. tostring(msg) .. "\n\n" .. debug.traceback(),
            10, 10, love.graphics.getWidth() - 20, "left")
    end
end