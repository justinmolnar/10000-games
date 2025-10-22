-- src/utils/program_launcher.lua
local Object = require('lib.class')
local Strings = require('src.utils.strings') -- Required for error messages
local ProgramLauncher = Object:extend('ProgramLauncher')

function ProgramLauncher:init(di)
    self.di = di

    -- Dependency provider map (moved from DesktopState)
    self.dependency_provider = {
        player_data = self.di.playerData,
        game_data = self.di.gameData,
        state_machine = self.di.stateMachine,
        save_manager = self.di.saveManager,
        statistics = self.di.statistics,
        window_manager = self.di.windowManager,
        desktop_icons = self.di.desktopIcons,
        file_system = self.di.fileSystem,
        recycle_bin = self.di.recycleBin,
        program_registry = self.di.programRegistry,
        vm_manager = self.di.vmManager,
        cheat_system = self.di.cheatSystem,
        di = self.di, -- Pass the whole DI container
        window_controller = self.di.window_controller -- Pass controller itself if needed
    }

    -- Subscribe to the launch_program event
    if self.di.eventBus then
        self.di.eventBus:subscribe('launch_program', function(program_id, ...)
            self:launchProgram(program_id, ...)
        end)
    else
        print("ERROR [ProgramLauncher]: EventBus not found in DI container.")
    end
end

-- Defensive: ensure dependency_provider exists before launching programs (moved from DesktopState)
function ProgramLauncher:_ensureDependencyProvider()
    if self.dependency_provider then return end
    print('[ProgramLauncher] Rebuilding dependency_provider map (was nil)')
    -- Rebuild using self.di
    self.dependency_provider = {
        player_data = self.di.playerData,
        game_data = self.di.gameData,
        state_machine = self.di.stateMachine,
        save_manager = self.di.saveManager,
        statistics = self.di.statistics,
        window_manager = self.di.windowManager,
        desktop_icons = self.di.desktopIcons,
        file_system = self.di.fileSystem,
        recycle_bin = self.di.recycleBin,
        program_registry = self.di.programRegistry,
        vm_manager = self.di.vmManager,
        cheat_system = self.di.cheatSystem,
        di = self.di,
        window_controller = self.di.window_controller,
    }
end

-- launchProgram function (moved from DesktopState and adapted)
function ProgramLauncher:launchProgram(program_id, ...)
    local launch_args = {...}
    print("Attempting to launch program: " .. program_id)

    -- Ensure dependency provider is present
    self:_ensureDependencyProvider()

    local program = self.di.programRegistry:getProgram(program_id)
    if not program then print("Program definition not found: " .. program_id); return end
    if program.disabled then print("Program disabled: " .. program_id); love.window.showMessageBox(Strings.get('messages.not_available','Not Available'), program.name .. " is not available yet.", "info"); return end
    if not program.state_class_path then print("Program missing state_class_path: " .. program_id); return end

    local defaults = program.window_defaults or {}
    if defaults.single_instance then
        local existing_id = self.di.windowManager:isProgramOpen(program_id)
        if existing_id then
            print(program.name .. " already running.")
            -- Use event bus to request focus
            if self.di.eventBus then
                self.di.eventBus:publish('request_window_focus', existing_id)
            else
                self.di.windowManager:focusWindow(existing_id) -- Fallback
            end
            return
        end
    end

    local module_name_slash = program.state_class_path:gsub("%.", "/")
    local require_ok, StateClass = pcall(require, module_name_slash)
    if not require_ok or not StateClass then
        local err = tostring(StateClass)
        print("ERROR loading state class '" .. program.state_class_path .. "': " .. err)
        if err:find("previous error loading module", 1, true) or err:find("loop or previous error", 1, true) then
            local offending = err:match("module '([^']+)'%s-") or err:match("no field package%.preload%['([^']+)'%]")
            if offending then
                package.loaded[offending] = nil
                package.loaded[offending:gsub('%.','/')] = nil
            end
            package.loaded[program.state_class_path] = nil
            package.loaded[module_name_slash] = nil
            local retry_ok, RetryClass = pcall(require, module_name_slash)
            if not retry_ok or not RetryClass then
                print("Retry require failed for '" .. program.state_class_path .. "': " .. tostring(RetryClass))
                return
            else
                StateClass = RetryClass
            end
        else
            return
        end
    end

    local state_args = {}
    local missing_deps = {}
    for _, dep_name in ipairs(program.dependencies or {}) do
        local dp = self.dependency_provider or {}
        local dependency = dp[dep_name]
        if dependency then table.insert(state_args, dependency)
        else print("ERROR: Missing dependency '" .. dep_name .. "' for program '" .. program_id .. "'"); table.insert(missing_deps, dep_name) end
    end
    if #missing_deps > 0 then love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), "Missing dependencies: " .. table.concat(missing_deps, ", "), "error"); return end

    local instance_ok, new_state = pcall(StateClass.new, StateClass, unpack(state_args))
    if not instance_ok or not new_state then print("ERROR instantiating state '" .. program.state_class_path .. "': " .. tostring(new_state)); return end

    local screen_w, screen_h = love.graphics.getDimensions()
    local C = (self.di and self.di.config) or {}
    local wd = (C and C.window and C.window.defaults) or {}
    local default_w = defaults.w or wd.width or 800
    local default_h = defaults.h or wd.height or 600

    local title_prefix = wd.title_prefix or ""
    local initial_title = (title_prefix ~= "" and (title_prefix .. program.name)) or program.name
    local game_data_arg = nil
    local program_for_window = program

    if program_id == "minigame_runner" then
        game_data_arg = launch_args[1]
        if game_data_arg and game_data_arg.display_name then
            initial_title = (title_prefix ~= "" and (title_prefix .. game_data_arg.display_name)) or game_data_arg.display_name
            program_for_window = {
                id = program.id,
                name = game_data_arg.display_name,
                icon_sprite = game_data_arg.icon_sprite,
                window_defaults = program.window_defaults
            }
        else
            initial_title = (title_prefix ~= "" and (title_prefix .. "Minigame")) or "Minigame"
        end
    end

    -- Create window via WindowManager (it publishes window_opened)
    local window_id = self.di.windowManager:createWindow( program_for_window, initial_title, new_state, default_w, default_h )
    if not window_id then print("ERROR: WindowManager failed to create window for " .. program_id); return end

    -- Register the state instance with DesktopState
    self.di.desktopState:registerWindowState(window_id, new_state)
    -- setWindowContext and setViewport are now handled within registerWindowState

    local enter_args = {}
    local enter_args_config = program.enter_args
    if program_id == "minigame_runner" then
        if game_data_arg then enter_args = { game_data_arg } end
    elseif enter_args_config then
        if enter_args_config.type == "first_launch_arg" then enter_args = {launch_args[1] or enter_args_config.default}
        elseif enter_args_config.type == "static" then enter_args = {enter_args_config.value} end
    else
        if #launch_args > 0 then enter_args = launch_args end
    end

    if new_state.enter then
        local enter_ok, enter_err = pcall(new_state.enter, new_state, unpack(enter_args))
        if type(enter_err) == 'table' and enter_err.type == "close_window" then
            print("State signaled close during enter for " .. program_id);
            -- Request close via event bus
            if self.di.eventBus then self.di.eventBus:publish('request_window_close', window_id) end
            return
        elseif not enter_ok then
            print("ERROR calling enter on state for " .. program_id .. ": " .. tostring(enter_err));
            -- Request close via event bus
            if self.di.eventBus then self.di.eventBus:publish('request_window_close', window_id) end
            return
        end
    end

    -- Set viewport after enter is now handled by registerWindowState

    if defaults.prefer_maximized and defaults.resizable ~= false then
        -- Request maximize via event bus
        if self.di.eventBus then
            self.di.eventBus:publish('request_window_maximize', window_id, screen_w, screen_h)
        else
            self.di.windowManager:maximizeWindow(window_id, screen_w, screen_h) -- Fallback
        end
        -- setViewport after maximize is handled by WindowManager reacting to event/call
    end

    print("Opened window for " .. initial_title .. " ID: " .. window_id)

    -- Publish dialog_opened event (remains the same)
    local dialog_types = {run_dialog=true, shutdown_dialog=true, solitaire_back_picker=true, wallpaper_picker=true, solitaire_settings=true}
    if dialog_types[program_id] and self.di.eventBus then
        pcall(self.di.eventBus.publish, self.di.eventBus, 'dialog_opened', program_id, window_id)
    end
end

return ProgramLauncher