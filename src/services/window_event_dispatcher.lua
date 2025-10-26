-- src/services/window_event_dispatcher.lua
-- Centralized handler for window state events

local Object = require('class')
local Constants = require('src.constants')
local Strings = require('src.utils.strings')

local WindowEventDispatcher = Object:extend('WindowEventDispatcher')

function WindowEventDispatcher:init(di)
    self.di = di
    self.event_bus = di.eventBus
    self.state_machine = di.stateMachine
    self.file_system = di.fileSystem
    self.program_registry = di.programRegistry
    self.start_menu = nil -- Will be set by DesktopState
end

function WindowEventDispatcher:setStartMenu(start_menu)
    self.start_menu = start_menu
end

-- Main dispatch method
function WindowEventDispatcher:handle(window_id, event, close_window_callback)
    if not event or not event.name then
        print("WARNING: Invalid event passed to WindowEventDispatcher")
        return
    end

    print("WindowEventDispatcher: Handling event '" .. event.name .. "' from window " .. window_id)

    local handlers = {
        next_level = function() self:handleNextLevel(window_id, event, close_window_callback) end,
        show_completion = function() self:handleShowCompletion(window_id, close_window_callback) end,
        launch_program = function() self:handleLaunchProgram(event) end,
        launch_minigame = function() self:handleLaunchMinigame(event) end,
        show_text = function() self:handleShowText(event) end,
        show_context_menu = function() self:handleShowContextMenu(event) end,
        ensure_icon_visible = function() self:handleEnsureIconVisible(event) end,
        shutdown_now = function() self:handleShutdownNow() end,
        restart_now = function() self:handleRestartNow() end,
        run_execute = function() self:handleRunExecute(window_id, event, close_window_callback) end,
        start_menu_create_folder = function() self:handleStartMenuCreateFolder(window_id, event, close_window_callback) end,
    }

    local handler = handlers[event.name]
    if handler then
        handler()
    else
        print("WARNING: Unhandled event type: " .. tostring(event.name))
    end
end

-- Event handlers

function WindowEventDispatcher:handleNextLevel(window_id, event, close_window_callback)
    if close_window_callback then close_window_callback(window_id) end
    if self.event_bus then
        self.event_bus:publish('launch_program', "space_defender", event.level)
    end
end

function WindowEventDispatcher:handleShowCompletion(window_id, close_window_callback)
    if close_window_callback then close_window_callback(window_id) end
    if self.state_machine then
        self.state_machine:switch(Constants.state.COMPLETION)
    end
end

function WindowEventDispatcher:handleLaunchProgram(event)
    if self.event_bus then
        self.event_bus:publish('launch_program', event.program_id)
    end
end

function WindowEventDispatcher:handleLaunchMinigame(event)
    if event.game_data then
        if self.event_bus then
            -- Pass both game_data and optional variant to launch_program
            self.event_bus:publish('launch_program', "minigame_runner", event.game_data, event.variant)
        end
    else
        print("ERROR: launch_minigame event missing game_data!")
    end
end

function WindowEventDispatcher:handleShowText(event)
    love.window.showMessageBox(event.title, event.content or "[Empty File]", "info")
end

function WindowEventDispatcher:handleShowContextMenu(event)
    local contextMenuService = self.di.contextMenuService
    if contextMenuService then
        contextMenuService:show(event.menu_x, event.menu_y, event.options, event.context)
    end
end

function WindowEventDispatcher:handleEnsureIconVisible(event)
    if self.event_bus then
        self.event_bus:publish('ensure_icon_visible', event.program_id)
    end
end

function WindowEventDispatcher:handleShutdownNow()
    _G.APP_ALLOW_QUIT = true
    love.event.quit()
end

function WindowEventDispatcher:handleRestartNow()
    _G.APP_ALLOW_QUIT = true
    love.event.quit('restart')
end

function WindowEventDispatcher:handleRunExecute(window_id, event, close_window_callback)
    if event.command and event.command ~= '' then
        self:executeRunCommand(event.command)
    end
    if close_window_callback then close_window_callback(window_id) end
end

function WindowEventDispatcher:executeRunCommand(command)
    command = command:gsub("^%s*(.-)%s*$", "%1"):lower()
    if command == "" then
        print("No command entered")
        return
    end

    local program = self.program_registry:findByExecutable(command)
    if program then
        if not program.disabled then
            if self.event_bus then
                self.event_bus:publish('launch_program', program.id)
            end
        else
            love.window.showMessageBox(
                Strings.get('messages.error_title', 'Error'),
                string.format(Strings.get('messages.cannot_find_fmt', "Cannot find '%s'."), command),
                "error"
            )
        end
    else
        love.window.showMessageBox(
            Strings.get('messages.error_title', 'Error'),
            string.format(Strings.get('messages.cannot_find_fmt', "Cannot find '%s'."), command),
            "error"
        )
    end
end

function WindowEventDispatcher:handleStartMenuCreateFolder(window_id, event, close_window_callback)
    local name = (event.text or ''):gsub('^%s*(.-)%s*$', '%1')
    if name == '' then return end

    local ctx = event.context or {}
    local fs = self.file_system
    local pr = self.program_registry
    local Constants = require('src.constants')

    if ctx.pane_kind == 'programs' then
        -- Create a real folder in Start Menu Programs root
        if fs and fs.createFolder then
            local parent_path = Constants.paths.START_MENU_PROGRAMS
            local after_idx = (ctx.after_index or ctx.index or 0) + 1
            local new_path = fs:createFolder(parent_path, name, after_idx)
            if new_path then
                -- Adjust order bookkeeping if used by PR
                if pr and pr.moveInStartMenuFolderOrder then
                    local dst_keys = {}
                    if self.start_menu and self.start_menu.view then
                        for _, p in ipairs(self.start_menu.view.open_panes or {}) do
                            if p.kind == 'fs' and p.parent_path == parent_path then
                                for _, it in ipairs(p.items or {}) do
                                    table.insert(dst_keys, (it.path or it.name))
                                end
                                break
                            end
                        end
                    end
                    pcall(pr.moveInStartMenuFolderOrder, pr, parent_path, new_path, after_idx, dst_keys)
                end
            end
        end
    elseif ctx.pane_kind == 'fs' and ctx.parent_path then
        -- Create a real folder under the given parent path
        if fs and fs.createFolder then
            local after_idx = (ctx.after_index or ctx.index or 0) + 1
            local new_path = fs:createFolder(ctx.parent_path, name, after_idx)
            if new_path and pr and pr.moveInStartMenuFolderOrder then
                local dst_keys = {}
                if self.start_menu and self.start_menu.view then
                    for _, p in ipairs(self.start_menu.view.open_panes or {}) do
                        if p.kind == 'fs' and p.parent_path == ctx.parent_path then
                            for _, it in ipairs(p.items or {}) do
                                table.insert(dst_keys, (it.path or it.name))
                            end
                            break
                        end
                    end
                end
                pcall(pr.moveInStartMenuFolderOrder, pr, ctx.parent_path, new_path, after_idx, dst_keys)
            end
        end
    end

    -- Refresh panes
    if self.start_menu and self.start_menu.view then
        for _, p in ipairs(self.start_menu.view.open_panes or {}) do
            if p.kind == 'programs' then
                p.items = self.start_menu.view:buildPaneItems('programs', nil)
            elseif p.kind == 'fs' and p.parent_path then
                p.items = self.start_menu.view:buildPaneItems('fs', p.parent_path)
            end
        end
    end

    if close_window_callback then close_window_callback(window_id) end
end

return WindowEventDispatcher
