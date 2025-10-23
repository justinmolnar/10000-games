-- src/states/desktop_state.lua
local Object = require('class')
local DesktopView = require('views.desktop_view')
local StartMenuState = require('src.states.start_menu_state')
local DesktopIconController = require('src.controllers.desktop_icon_controller')
local Constants = require('src.constants')
local Strings = require('src.utils.strings')
local TutorialView = require('src.views.tutorial_view')
local WindowChrome = require('src.views.window_chrome')
local WindowController = require('src.controllers.window_controller')
local Collision = require('src/utils.collision')

-- DEBUG: Check if WindowController loaded
if not WindowController then
    error("CRITICAL: WindowController failed to load!")
end
-- WindowController loaded

local DesktopState = Object:extend('DesktopState')

function DesktopState:init(di)
    -- Begin initialization

    -- Dependency Injection container (required in new API)
    self.di = di or {}

    -- Core references from DI
    self.state_machine = self.di.stateMachine
    self.player_data = self.di.playerData
    self.statistics = self.di.statistics
    self.window_manager = self.di.windowManager
    self.desktop_icons = self.di.desktopIcons -- Injected
    self.file_system = self.di.fileSystem
    self.recycle_bin = self.di.recycleBin -- Injected
    self.program_registry = self.di.programRegistry
    self.vm_manager = self.di.vmManager
    self.cheat_system = self.di.cheatSystem
    self.save_manager = self.di.saveManager
    self.game_data = self.di.gameData
    self.event_bus = self.di.eventBus -- Store event bus

    -- Initialize basic properties first
    self.window_chrome = WindowChrome:new() -- Create chrome view here
    self.window_states = {} -- Initialize the map for WindowController

    -- *** Get WindowController from DI (created in main.lua) ***
    self.window_controller = self.di.window_controller
    if not self.window_controller then
        print("CRITICAL ERROR [DesktopState]: WindowController not found in DI container!")
        -- Optionally create a dummy controller to prevent crashes, though functionality will be broken
        -- self.window_controller = { getCursorType = function() return "arrow" end, mousepressed = function() end, mousemoved = function() end, mousereleased = function() end }
    end

    -- Initialize Views and other properties
    self.view = DesktopView:new(self.program_registry, self.player_data, self.window_manager, self.desktop_icons, self.recycle_bin, self.di)
    -- Pass self as host for legacy fallback compatibility during EventBus rollout
    self.start_menu = StartMenuState:new(self.di, self) -- Host is self for legacy launchProgram fallback
    self.icon_controller = DesktopIconController:new(self.program_registry, self.desktop_icons, self.recycle_bin, self.di)
    self.tutorial_view = TutorialView:new(self)

    local C = (self.di and self.di.config) or {}
    local colors = (C.ui and C.ui.colors) or {}
    local SettingsManager = (self.di and self.di.settingsManager) or require('src.utils.settings_manager')
    -- Desktop wallpaper from settings (fallback to config color)
    self.wallpaper_type = SettingsManager.get('desktop_bg_type') or 'color'
    self.wallpaper_image = SettingsManager.get('desktop_bg_image')
    self.wallpaper_scale_mode = SettingsManager.get('desktop_bg_scale_mode') or 'fill'
    local r = SettingsManager.get('desktop_bg_r'); if r == nil then r = (colors.desktop and colors.desktop.wallpaper and colors.desktop.wallpaper[1]) or 0 end
    local g = SettingsManager.get('desktop_bg_g'); if g == nil then g = (colors.desktop and colors.desktop.wallpaper and colors.desktop.wallpaper[2]) or 0.5 end
    local b = SettingsManager.get('desktop_bg_b'); if b == nil then b = (colors.desktop and colors.desktop.wallpaper and colors.desktop.wallpaper[3]) or 0.5 end
    self.wallpaper_color = { r, g, b }
    if self.wallpaper_type == 'image' then
        local okW, WP = pcall(require, 'src.utils.wallpapers')
        if okW and WP then
            local item = WP.getItemById(self.wallpaper_image)
            if not item then
                local saved_id = SettingsManager.get('desktop_bg_image')
                if not saved_id or saved_id == '' then
                    local def = WP.getDefaultId()
                    if def then
                        self.wallpaper_image = def
                        pcall(SettingsManager.set, 'desktop_bg_image', def)
                    end
                end
            end
            if self.wallpaper_image and WP.getImageCached then pcall(WP.getImageCached, self.wallpaper_image) end
        end
    end
    self.icon_snap = SettingsManager.get('desktop_icon_snap') ~= false
    if self.di and self.di.showTutorialOnStartup ~= nil then
        self.show_tutorial = self.di.showTutorialOnStartup
    else
        self.show_tutorial = not SettingsManager.get("tutorial_shown") or false
    end

    self.start_menu_open = false

    -- Icon interaction state
    self.dragging_icon_id = nil
    self.drag_offset_x = 0
    self.drag_offset_y = 0
    self.last_icon_click_time = 0
    self.last_icon_click_id = nil

    -- Title bar double-click state
    self.last_title_bar_click_time = 0
    self.last_title_bar_click_id = nil

    -- Store cursors
    self.cursors = (self.di and self.di.systemCursors) or {}

    -- Screensaver idle timer
    self.idle_timer = 0
    local desktopCfg = (C.ui and C.ui.desktop) or {}
    self.screensaver_timeout = SettingsManager.get('screensaver_timeout') or (desktopCfg.screensaver and desktopCfg.screensaver.default_timeout) or 10
    self.screensaver_enabled = SettingsManager.get('screensaver_enabled') ~= false

    -- Subscribe to EventBus events
    if self.event_bus then
        self.event_bus:subscribe('window_closed', function(window_id)
            self.window_states[window_id] = nil
        end)
        -- Subscribe to wallpaper changes to update live
        self.event_bus:subscribe('wallpaper_changed', function(new_wallpaper_id)
            self.wallpaper_type = 'image' -- Assume changing image sets type to image
            self.wallpaper_image = new_wallpaper_id
            -- Prewarm cache
            local okW, WP = pcall(require, 'src.utils.wallpapers')
            if okW and WP and WP.getImageCached then pcall(WP.getImageCached, new_wallpaper_id) end
        end)
        -- Subscribe to other relevant setting changes if needed
        self.event_bus:subscribe('setting_changed', function(key, old_value, new_value)
            if key == 'desktop_bg_type' then self.wallpaper_type = new_value
            elseif key == 'desktop_bg_scale_mode' then self.wallpaper_scale_mode = new_value
            elseif key == 'desktop_bg_r' then self.wallpaper_color[1] = new_value
            elseif key == 'desktop_bg_g' then self.wallpaper_color[2] = new_value
            elseif key == 'desktop_bg_b' then self.wallpaper_color[3] = new_value
            elseif key == 'desktop_icon_snap' then self.icon_snap = (new_value ~= false)
            end
        end)

        -- Subscribe to ContextMenuService events
        self.event_bus:subscribe('request_icon_recycle', function(program_id)
            self:deleteDesktopIcon(program_id)
        end)
        self.event_bus:subscribe('ensure_icon_visible', function(program_id)
            self:ensureIconIsVisible(program_id)
        end)
        self.event_bus:subscribe('add_to_start_menu', function(program_id)
            local pr = self.program_registry
            local program = pr and pr:getProgram(program_id)
            if program then
                program.in_start_menu = true
                if pr.setStartMenuOverride then pr:setStartMenuOverride(program_id, true) end
            end
        end)
        self.event_bus:subscribe('remove_from_start_menu', function(program_id)
            local pr = self.program_registry
            local program = pr and pr:getProgram(program_id)
            if program then
                program.in_start_menu = false
                if pr.setStartMenuOverride then pr:setStartMenuOverride(program_id, false) end
                if pr.removeFromStartMenuOrder then pcall(pr.removeFromStartMenuOrder, pr, program_id) end
            end
            if self.start_menu and self.start_menu.view then
                for _, p in ipairs(self.start_menu.view.open_panes or {}) do
                    if p.kind == 'programs' then p.items = self.start_menu.view:buildPaneItems('programs', nil)
                    elseif p.kind == 'fs' and p.parent_path then p.items = self.start_menu.view:buildPaneItems('fs', p.parent_path) end
                end
            end
        end)
        self.event_bus:subscribe('start_menu_new_folder', function(context)
            local Constants = require('src.constants')
            local params = {
                title = Strings.get('menu.new_folder', 'New Folder...'),
                prompt = Strings.get('start.type_prompt', 'Type the name:'),
                ok_label = Strings.get('buttons.create', 'Create'),
                cancel_label = Strings.get('buttons.cancel', 'Cancel'),
                submit_event = 'start_menu_create_folder',
                context = {
                    pane_kind = context.pane_kind or 'programs',
                    parent_path = context.parent_path or Constants.paths.START_MENU_PROGRAMS,
                    after_index = context.index or 0,
                }
            }
            self.event_bus:publish('launch_program', 'run_dialog', params)
        end)
        self.event_bus:subscribe('start_menu_open_path', function(path)
            if self.start_menu and self.start_menu.openPath then
                self.start_menu:openPath(path)
            end
        end)
        self.event_bus:subscribe('start_menu_delete_fs', function(path)
            local fs = self.file_system
            if fs and fs.deleteEntry then
                local ok, err = fs:deleteEntry(path)
                if not ok then
                    print('Delete failed for Start Menu FS item:', path, err)
                end
                if self.start_menu and self.start_menu.view then
                    for _, p in ipairs(self.start_menu.view.open_panes or {}) do
                        if p.kind == 'fs' and p.parent_path then p.items = self.start_menu.view:buildPaneItems('fs', p.parent_path) end
                    end
                end
            end
        end)
        self.event_bus:subscribe('request_window_close', function(window_id)
            self:closeWindowById(window_id)
        end)
        self.event_bus:subscribe('file_explorer_action', function(action_id, context)
            self:handleFileExplorerAction(action_id, context)
        end)
    else
        print("WARNING [DesktopState]: EventBus not found in DI. Some features might not work correctly.")
    end

    -- Initialization finished
end

-- NEW function added as per plan
function DesktopState:registerWindowState(window_id, state)
    self.window_states[window_id] = { state = state }
    -- Important: Re-apply context if needed by state
    if state.setWindowContext then state:setWindowContext(window_id, self.window_manager) end
    if state.setViewport then
         local window = self.window_manager:getWindowById(window_id)
         if window then
             -- Use the injected windowChrome instance
             local bounds = self.di.windowChrome:getContentBounds(window)
             pcall(state.setViewport, state, bounds.x, bounds.y, bounds.width, bounds.height)
         end
    end
end

-- DELETED launchProgram function

-- DELETED _ensureDependencyProvider function

function DesktopState:enter()
    self:updateClock()
    print("Desktop loaded. Tutorial active: " .. tostring(self.show_tutorial))
    self.view:calculateDefaultIconPositionsIfNeeded() -- View uses model data now
    -- Publish tutorial_shown event if tutorial is active
    if self.show_tutorial and self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'tutorial_shown')
    end
end

function DesktopState:update(dt)
    -- Defensive defaults in case update is called before init completes fully
    if self.idle_timer == nil then self.idle_timer = 0 end
    if not self.wallpaper_color then self.wallpaper_color = {0, 0.5, 0.5} end
    -- Update global systems if they exist
    if self.statistics then self.statistics:addPlaytime(dt) end

    -- VM Manager needs to run even if DesktopState isn't the active *state machine* state
    if self.vm_manager and self.player_data and self.game_data then
        self.vm_manager:update(dt, self.player_data, self.game_data)
    end

    -- Update active window states
    local windows = self.window_manager:getAllWindows()
    for _, window in ipairs(windows) do
        if not window.is_minimized then
            local window_data = self.window_states[window.id]
            if window_data and window_data.state then
                 if type(window_data.state.update) == "function" then
                    local success, err = pcall(window_data.state.update, window_data.state, dt)
                    if not success then
                        print("Error *during* pcall update on state for window " .. window.id .. ": " .. tostring(err))
                    end
                 end
            end
        end
    end

    -- Update context menu service
    if self.di.contextMenuService then
        self.di.contextMenuService:update(dt)
    end

    -- If the OS requested quit (Alt+F4 or window close), open our shutdown dialog instead
    if _G.WANT_SHUTDOWN_DIALOG then
        _G.WANT_SHUTDOWN_DIALOG = nil
        -- Use event bus to launch
        if self.event_bus then self.event_bus:publish('launch_program', 'shutdown_dialog') end
    end

    -- Update main desktop view or tutorial
    if self.show_tutorial then
        self.tutorial_view:update(dt)
    else
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        if self.icon_controller then self.icon_controller:ensureDefaultPositions(sw, sh) end
        -- Only DesktopView (no start menu update here); StartMenuView handles menu state
        self.view:update(dt, false, self.dragging_icon_id)
        if self.start_menu then
            -- Start Menu state owns its open/close; mirror to legacy flag for compatibility
            self.start_menu:update(dt)
            self.start_menu_open = self.start_menu:isOpen()
        end
    end

    -- Update system cursor based on context
    local mx, my = love.mouse.getPosition()
    local cursor_type = self.window_controller:getCursorType(mx, my, self.window_chrome)
    local cursor_obj = self.cursors[cursor_type] or self.cursors["arrow"]
    if cursor_obj then love.mouse.setCursor(cursor_obj) end

    -- Refresh settings live (in-memory from SettingsManager)
    local SettingsManager = (self.di and self.di.settingsManager) or require('src.utils.settings_manager')
    self.screensaver_enabled = SettingsManager.get('screensaver_enabled') ~= false
    self.screensaver_timeout = SettingsManager.get('screensaver_timeout') or 10
    -- Live-update desktop background and snap
    self.wallpaper_type = SettingsManager.get('desktop_bg_type') or self.wallpaper_type or 'color'
    self.wallpaper_image = SettingsManager.get('desktop_bg_image') or self.wallpaper_image
    self.wallpaper_scale_mode = SettingsManager.get('desktop_bg_scale_mode') or self.wallpaper_scale_mode or 'fill'
    if self.wallpaper_type == 'image' and not self.wallpaper_image then
        local okW, WP = pcall(require, 'src.utils.wallpapers')
        if okW and WP then
            local saved_id = SettingsManager.get('desktop_bg_image')
            if not saved_id or saved_id == '' then
                local def = WP.getDefaultId()
                if def then
                    self.wallpaper_image = def
                    pcall(SettingsManager.set, 'desktop_bg_image', def)
                end
            end
        end
    end
    local nr = SettingsManager.get('desktop_bg_r') or 0
    local ng = SettingsManager.get('desktop_bg_g') or 0.5
    local nb = SettingsManager.get('desktop_bg_b') or 0.5
    self.wallpaper_color[1], self.wallpaper_color[2], self.wallpaper_color[3] = nr, ng, nb
    self.icon_snap = SettingsManager.get('desktop_icon_snap') ~= false

    -- Screensaver idle tracking
    if self.screensaver_enabled then
        self.idle_timer = self.idle_timer + dt
        local C = (self.di and self.di.config) or {}
        local default_timeout = (C.ui and C.ui.desktop and C.ui.desktop.screensaver and C.ui.desktop.screensaver.default_timeout) or 10
        if self.idle_timer >= (self.screensaver_timeout or default_timeout) then
            if self.state_machine and self.state_machine.states[Constants.state.SCREENSAVER] then
                self.state_machine:switch(Constants.state.SCREENSAVER)
                self.idle_timer = 0
                return
            end
        end
    else
        self.idle_timer = 0
    end
end

-- updateClock remains the same
function DesktopState:updateClock()
    self.current_time = os.date("%H:%M")
end

-- draw remains the same
function DesktopState:draw()
    -- Pass dragging state for visual feedback
    local wallpaper_arg = (self.wallpaper_type == 'image' and self.wallpaper_image)
        and { type = 'image', id = self.wallpaper_image, color = self.wallpaper_color, scale_mode = self.wallpaper_scale_mode }
        or self.wallpaper_color
        -- Inline run dialog removed; now a proper window
        self.view:draw(
            wallpaper_arg,
            self.player_data.tokens,
            self.start_menu_open,
            self.dragging_icon_id
        )

    -- Draw windows respecting z-order from window manager
    local windows = self.window_manager:getAllWindows()
    for i = 1, #windows do
        local window = windows[i]
        if not window.is_minimized then
            self:drawWindow(window)
        end
    end

     -- Draw the icon being dragged on top of windows
    if self.dragging_icon_id then
        local program = self.program_registry:getProgram(self.dragging_icon_id)
        if program then
            local mx, my = love.mouse.getPosition()
            local drag_x = mx - self.drag_offset_x
            local drag_y = my - self.drag_offset_y
            local temp_pos = { x = drag_x, y = drag_y }
            self.view:drawIcon(program, true, temp_pos, true) -- Pass dragging flag
        end
    end

    -- Draw start menu on top of windows
    if self.start_menu and self.start_menu:isOpen() then self.start_menu:draw() end

    -- Draw context menu on top if open
    if self.di.contextMenuService then
        self.di.contextMenuService:draw()
    end

    -- Draw tutorial overlay last if active
    if self.show_tutorial then
        self.tutorial_view:draw()
    end
end

-- drawWindow remains the same
function DesktopState:drawWindow(window)
    local is_focused = self.window_manager:getFocusedWindowId() == window.id

    -- Draw window chrome (border, title bar, buttons)
    local sprite_loader = self.di and self.di.spriteLoader
    self.window_chrome:draw(window, is_focused, sprite_loader)

    -- Draw window content state
    local window_data = self.window_states[window.id]
    local window_state = window_data and window_data.state

    if window_state and window_state.draw then
        local content_bounds = self.window_chrome:getContentBounds(window)

        love.graphics.push() -- Save current graphics state
        -- Set scissor BEFORE translating
        love.graphics.setScissor(content_bounds.x, content_bounds.y, content_bounds.width, content_bounds.height)
        -- Translate origin to content area's top-left AFTER setting scissor
        love.graphics.translate(content_bounds.x, content_bounds.y)

        -- The state's draw function draws relative to (0,0) within the clipped area
        local draw_ok, err = pcall(window_state.draw, window_state)

        love.graphics.pop() -- Restore previous graphics state (removes translation and scissor setting from the push)

        -- *** ADD EXPLICIT SCISSOR RESET ***
        -- Reset scissor to full screen just in case pop didn't fully restore it
        love.graphics.setScissor()
        -- *** END ADDED LINE ***

        if not draw_ok then
            print("Error during window state draw for ID " .. window.id .. ": " .. tostring(err))
            -- Draw error message (this part seems okay, uses push/pop locally)
            local C = (self.di and self.di.config) or {}
            local E = (C.ui and C.ui.window and C.ui.window.error) or {}
            love.graphics.push()
            love.graphics.setScissor(content_bounds.x, content_bounds.y, content_bounds.width, content_bounds.height)
            love.graphics.setColor((E.text_color or {1,0,0}))
            local pad = E.text_pad or {x=5,y=5}
            local wpad = E.width_pad or 10
            love.graphics.printf("Error drawing window content:\n" .. tostring(err), content_bounds.x + pad.x, content_bounds.y + pad.y, content_bounds.width - wpad)
            love.graphics.setScissor()
            love.graphics.pop()
        end
    end
end

-- mousepressed: Replace self:launchProgram with event publish
function DesktopState:mousepressed(x, y, button)
    self.idle_timer = 0
    -- If tutorial is showing, it consumes all input
    if self.show_tutorial then
        local event = self.tutorial_view:mousepressed(x, y, button)
        if event and event.name == "dismiss_tutorial" then self:dismissTutorial() end
        return -- Tutorial handled it
    end

    local click_handled = false -- General flag if click was processed

    -- --- Context Menu Handling (Priority 1) ---
    if self.di.contextMenuService and self.di.contextMenuService:isOpen() then
        local handled_by_menu = self.di.contextMenuService:mousepressed(x, y, button)
        if handled_by_menu then return end -- Menu consumed click
        -- If right-clicked outside, menu closed but didn't consume, fall through
    end

    -- --- Window Interaction Handling (Priority 2) ---
    -- Check topmost window first for efficiency
    local handled_by_window = false
    local top_window_id = self.window_manager:getFocusedWindowId() -- Get focused first
    local top_window = top_window_id and self.window_manager:getWindowById(top_window_id)

    if top_window and not top_window.is_minimized and x >= top_window.x and x <= top_window.x + top_window.width and y >= top_window.y and y <= top_window.y + top_window.height then
        -- Click is potentially on the top window
        handled_by_window = self:_handleWindowClick(top_window, x, y, button)
        click_handled = handled_by_window -- If top window handled it, mark as handled
    end

    -- If not handled by top window, check other windows from top down
    if not handled_by_window then
        local windows = self.window_manager:getAllWindows()
        for i = #windows, 1, -1 do
            local window = windows[i]
            -- Skip if it's the already-checked top window or minimized
            if window.id ~= top_window_id and not window.is_minimized then
                 if x >= window.x and x <= window.x + window.width and y >= window.y and y <= window.y + window.height then
                     -- Click is on this non-top window
                     handled_by_window = self:_handleWindowClick(window, x, y, button)
                     click_handled = handled_by_window -- If any window handled it, mark as handled
                     if handled_by_window then break end -- Stop checking lower windows
                 end
            end
        end
    end

    -- If any window interaction occurred (even just focusing), close desktop menus
    if click_handled then
        if self.start_menu then self.start_menu:setOpen(false); self.start_menu_open = false end
        self.last_icon_click_id = nil
        if handled_by_window then return end -- Return if window fully handled it (e.g., content interaction, button press)
    end


    -- --- Desktop UI / Empty Space Click Handling (Priority 3 - Only if not handled by window) ---
    if button == 1 then
        local clicked_specific_desktop_ui = false
        -- Check Start button
       if self.view:isStartButtonHovered(x, y) then
           clicked_specific_desktop_ui = true
           if self.start_menu then self.start_menu:onStartButtonPressed(); self.start_menu_open = self.start_menu:isOpen() end
        -- Check Start menu items
        elseif self.start_menu and self.start_menu:isOpen() then
            local consumed = self.start_menu:mousepressed(x, y, button)
            if consumed then clicked_specific_desktop_ui = true end
        -- Check desktop icons
        else
            local icon_program_id = self.view:getProgramAtPosition(x, y)
            if icon_program_id then
                clicked_specific_desktop_ui = true
                local program = self.program_registry:getProgram(icon_program_id)
                if program and not program.disabled then
                    local C = (self.di and self.di.config) or {}
                    local dbl = (C and C.ui and C.ui.double_click_time) or 0.5
                    local is_double_click = (self.last_icon_click_id == icon_program_id and love.timer.getTime() - self.last_icon_click_time < dbl)
                    if is_double_click then
                        if self.di.eventBus then self.di.eventBus:publish('icon_double_clicked', icon_program_id) end

                        -- Check if this is a file shortcut (txt file)
                        if program.shortcut_type == 'file' and program.shortcut_target then
                            local file_path = program.shortcut_target
                            local fs = self.file_system
                            if fs then
                                local item = fs:getItem(file_path)
                                if item and item.type == 'file' then
                                    self:showTextFileDialog(item.name or file_path, item.content)
                                end
                            end
                        else
                            -- Publish launch event instead of calling directly
                            if self.di.eventBus then self.di.eventBus:publish('launch_program', icon_program_id) end
                        end

                        self.last_icon_click_id = nil;
                        self.last_icon_click_time = 0;
                        self.dragging_icon_id = nil
                    else
                        if self.di.eventBus then self.di.eventBus:publish('icon_drag_started', icon_program_id) end
                        self.last_icon_click_id = icon_program_id;
                        self.last_icon_click_time = love.timer.getTime();
                        self.dragging_icon_id = icon_program_id;
                        local icon_pos = self.desktop_icons:getPosition(icon_program_id) or self.icon_controller:getDefaultIconPosition(icon_program_id);
                        self.drag_offset_x = x - icon_pos.x;
                        self.drag_offset_y = y - icon_pos.y
                    end
                elseif program and program.disabled then love.window.showMessageBox(Strings.get('messages.not_available','Not Available'), program.name .. " is planned.", "info"); self.last_icon_click_id = nil; self.last_icon_click_time = 0 end
            end
            -- Check taskbar buttons if icon wasn't clicked
            if not icon_program_id then
                local taskbar_button_id = self.view:getTaskbarButtonAtPosition(x, y)
                if taskbar_button_id then
                    clicked_specific_desktop_ui = true
                    local window = self.window_manager:getWindowById(taskbar_button_id)
                    if window then
                        local focused_id = self.window_manager:getFocusedWindowId()
                        if window.is_minimized then
                            if self.di.eventBus then
                                self.di.eventBus:publish('request_window_restore', taskbar_button_id)
                                self.di.eventBus:publish('request_window_focus', taskbar_button_id)
                            end
                        elseif window.id == focused_id then
                            if self.di.eventBus then self.di.eventBus:publish('request_window_minimize', taskbar_button_id) end
                        else
                            if self.di.eventBus then self.di.eventBus:publish('request_window_focus', taskbar_button_id) end
                        end
                    end
                end
            end
        end
        -- If click wasn't on specific desktop UI or window chrome/content
       if not clicked_specific_desktop_ui and not click_handled then
           if self.start_menu then self.start_menu:setOpen(false); self.start_menu_open = false end
           self.last_icon_click_id = nil
        end

    elseif button == 2 then -- Right click
        -- If Start Menu is open and the click is inside it (no menu currently open), show Start Menu context and consume
        if (not self.di.contextMenuService or not self.di.contextMenuService:isOpen()) and self.start_menu and self.start_menu:isOpen() then
            local inside_any = self.start_menu:isPointInStartMenuOrSubmenu(x, y)
                if inside_any then
                local hit = self.start_menu.view and self.start_menu.view.hitTestStartMenuContext and self.start_menu.view:hitTestStartMenuContext(x, y, self.start_menu)
                local options = {}
                local ctx = { type = 'start_menu' }
                if hit then
                    if hit.area == 'pane' and hit.item then
                        if hit.kind == 'programs' and hit.item.type == 'program' then
                            ctx = { type='start_menu_item', program_id=hit.item.program_id, pane_kind='programs', parent_path=nil, index=hit.index, pane_index=hit.pane_index }
                            if self.di.contextMenuService then
                                options = self.di.contextMenuService:generateContextMenuOptions('start_menu_item', ctx)
                            end
                            table.insert(options, 3, { id='new_folder', label=Strings.get('menu.new_folder','New Folder...'), enabled=true })
                        elseif hit.kind == 'fs' then
                            ctx = { type='start_menu_fs', path = hit.item and (hit.item.path or hit.item.name), parent_path=hit.parent_path, is_folder = (hit.item and hit.item.type == 'folder'), index=hit.index, pane_index=hit.pane_index }
                            options = {
                                { id='open', label=Strings.get('menu.open','Open'), enabled=true },
                                { id='separator' },
                                { id='new_folder', label=Strings.get('menu.new_folder','New Folder...'), enabled=true },
                                { id='separator' },
                                { id='delete_from_menu', label=Strings.get('menu.delete','Delete from Start Menu'), enabled=true }
                            }
                        elseif hit.kind == 'programs' and hit.item.type == 'folder' and hit.item.program_id then
                            -- Top-level folder shortcut shown by Programs list: treat as program for deletion; still allow new folder below
                            ctx = { type='start_menu_item', program_id = hit.item.program_id, pane_kind='programs', parent_path=nil, index=hit.index, pane_index=hit.pane_index }
                            if self.di.contextMenuService then
                                options = self.di.contextMenuService:generateContextMenuOptions('start_menu_item', ctx)
                            end
                            table.insert(options, 3, { id='new_folder', label=Strings.get('menu.new_folder','New Folder...'), enabled=true })
                        end
                    elseif hit.area == 'submenu' and hit.id and self.start_menu.view.submenu_open_id == 'programs' then
                        ctx = { type='start_menu_item', program_id=hit.id, pane_kind='programs', parent_path=nil, index=hit.index, pane_index=hit.pane_index }
                        if self.di.contextMenuService then
                            options = self.di.contextMenuService:generateContextMenuOptions('start_menu_item', ctx)
                        end
                        table.insert(options, 3, { id='new_folder', label=Strings.get('menu.new_folder','New Folder...'), enabled=true })
                    end
                end
                if #options > 0 and self.di.contextMenuService then
                    self.di.contextMenuService:show(x, y, options, ctx)
                    return
                end
                return -- Consume right click in Start Menu even if no options
            end
        end
        -- Generate desktop/icon/taskbar context menu
        local context_type = "desktop"; local context_data = {}
        -- Use controller for hit-test so we get accurate icon detection
        local icon_program_id = self.icon_controller and self.icon_controller:getProgramAtPosition(x, y) or self.view:getProgramAtPosition(x, y)
        local taskbar_button_id = self.view:getTaskbarButtonAtPosition(x, y)
        local on_start_button = self.view:isStartButtonHovered(x, y)
        local start_menu_program_id = nil
        if self.start_menu and self.start_menu:isOpen() and self.start_menu.isPointInStartMenu and self.start_menu:isPointInStartMenu(x, y) then
            start_menu_program_id = self.start_menu:getStartMenuProgramAtPosition(x, y)
        end

        if start_menu_program_id and start_menu_program_id ~= "run" then context_type = "start_menu_item"; context_data = { program_id = start_menu_program_id }
        elseif icon_program_id then
            context_type = "icon";
            context_data = { program_id = icon_program_id }
            if self.di.eventBus then self.di.eventBus:publish('icon_right_clicked', icon_program_id, x, y) end
        elseif taskbar_button_id then context_type = "taskbar"; context_data = { window_id = taskbar_button_id }
        elseif on_start_button then context_type = "start_button" -- NYI
        end

        if context_type ~= "start_button" and self.di.contextMenuService then
            self.di.contextMenuService:show(x, y, context_type, { type = context_type, program_id = context_data.program_id, window_id = context_data.window_id })
        end
    end
end

-- _handleWindowClick remains the same
function DesktopState:_handleWindowClick(window, x, y, button)
    local handled = false

    if self.window_manager:getFocusedWindowId() ~= window.id then
        if self.di.eventBus then self.di.eventBus:publish('request_window_focus', window.id) end
        handled = true
    end

    local window_event = self.window_controller:checkWindowClick(window, x, y, self.window_chrome)

    if window_event then
        if window_event.type == "window_content_click" then
            local window_data = self.window_states[window.id]
            local window_state = window_data and window_data.state
            if window_state and window_state.mousepressed then
                 local local_x = window_event.content_x
                 local local_y = window_event.content_y
                 local success, state_result = pcall(window_state.mousepressed, window_state, local_x, local_y, button)

                 if success then
                     if type(state_result) == 'table' then
                         if state_result.type == "close_window" then
                             self:closeWindowById(window.id)
                             handled = true
                         elseif state_result.type == "event" then
                             self:handleStateEvent(window.id, state_result)
                             handled = true
                         elseif state_result.type == "content_interaction" then
                             handled = true
                         else
                             handled = true
                         end
                     elseif state_result == true then
                         handled = true
                     end
                 else
                      print("Error calling mousepressed on state for window " .. window.id .. ": " .. tostring(state_result))
                      handled = true
                 end
            end
            handled = true
            self.last_title_bar_click_id = nil; self.last_title_bar_click_time = 0

        elseif window_event.type == "window_drag_start" then
            local current_time = love.timer.getTime()
            local C = (self.di and self.di.config) or {}
            local dbl = (C and C.ui and C.ui.double_click_time) or 0.5
            if window.id == self.last_title_bar_click_id and current_time - self.last_title_bar_click_time < dbl then
                -- Respect resizable flag for double-click maximize/restore
                local program = self.program_registry:getProgram(window.program_type)
                local defaults = program and program.window_defaults or {}
                local C = (self.di and self.di.config) or {}
                local wd = (C and C.window and C.window.defaults) or {}
                local fallback_resizable = (wd.resizable ~= nil) and wd.resizable or true
                local computed_resizable = (defaults.resizable ~= nil) and defaults.resizable or fallback_resizable
                local is_resizable = (window.is_resizable ~= nil) and window.is_resizable or computed_resizable
                if is_resizable then
                    if window.is_maximized then
                        if self.di.eventBus then self.di.eventBus:publish('request_window_restore', window.id) end
                    else
                        if self.di.eventBus then self.di.eventBus:publish('request_window_maximize', window.id, love.graphics.getWidth(), love.graphics.getHeight()) end
                    end

                    -- ADD: Call setViewport after double-click maximize/restore
                    local updated_window = self.window_manager:getWindowById(window.id)
                    if updated_window then
                        local window_data = self.window_states[window.id]
                        local window_state = window_data and window_data.state
                        if window_state and window_state.setViewport then
                            local content_bounds = self.window_chrome:getContentBounds(updated_window)
                            pcall(window_state.setViewport, window_state,
                                  content_bounds.x, content_bounds.y,
                                  content_bounds.width, content_bounds.height)
                        end
                    end
                end
                self.last_title_bar_click_id = nil; self.last_title_bar_click_time = 0
                self.window_controller.dragging_window_id = nil
            else
                self.last_title_bar_click_id = window.id; self.last_title_bar_click_time = current_time
            end
            handled = true

        elseif window_event.type == "window_resize_start" or
               window_event.type == "window_close" or
               window_event.type == "window_minimize" or
               window_event.type == "window_maximize" or
               window_event.type == "window_restore" or
               window_event.type == "window_chrome_click" then
            local action_result = self:handleWindowEvent(window_event, x, y, button)
            handled = true
            self.last_title_bar_click_id = nil; self.last_title_bar_click_time = 0
        end
    end

    return handled
end

-- mousemoved remains the same
function DesktopState:mousemoved(x, y, dx, dy)
    self.idle_timer = 0
    -- Forward to window controller first (handles window drag/resize)
    -- Pass self.window_chrome instance
    self.window_controller:mousemoved(x, y, dx, dy, self.window_chrome)

    -- If an icon drag is active, update visual position (drawing handles this)
    -- No model update needed here, only on release

    -- Forward to Start Menu for drag hover updates
    if self.start_menu and self.start_menu:isOpen() and self.start_menu.mousemoved then
        self.start_menu:mousemoved(x, y, dx, dy)
    end

    -- Forward mouse move to focused window's state with content-relative coords (for in-window drags)
    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window = self.window_manager:getWindowById(focused_id)
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window and window_state and window_state.mousemoved then
            local content_bounds = self.window_chrome:getContentBounds(window)
            local local_x = x - content_bounds.x
            local local_y = y - content_bounds.y
            -- Call without guarding for bounds so drags outside still get updates
            pcall(window_state.mousemoved, window_state, local_x, local_y, dx, dy)
        end
    end
end

function DesktopState:mousereleased(x, y, button)
    self.idle_timer = 0
    -- If a context menu click was just handled, swallow this release to avoid click-through
    if self.di.contextMenuService and self.di.contextMenuService:shouldSuppressMouseRelease() then
        return
    end
    -- Forward to window controller first
    self.window_controller:mousereleased(x, y, button)
    -- Handle Start Menu activation on release
    if self.start_menu and self.start_menu:isOpen() then
        local consumed = self.start_menu:mousereleased(x, y, button)
        if consumed then return end
    end


    -- Handle icon drop
    if button == 1 and self.dragging_icon_id then
        local dropped_icon_id = self.dragging_icon_id
        self.dragging_icon_id = nil -- Stop drag state

        local initial_drop_x = x - self.drag_offset_x
        local initial_drop_y = y - self.drag_offset_y
        local screen_w, screen_h = love.graphics.getDimensions()
        local icon_w, icon_h = self.desktop_icons:getIconDimensions()
        local padding = 5 -- Buffer

        -- 1. Check Recycle Bin drop first
    local recycle_bin_pos = self.icon_controller:getRecycleBinPosition()
        if recycle_bin_pos and dropped_icon_id ~= "recycle_bin" then
            local drop_center_x = initial_drop_x + icon_w / 2
            local drop_center_y = initial_drop_y + icon_h / 2
            if drop_center_x >= recycle_bin_pos.x and drop_center_x <= recycle_bin_pos.x + recycle_bin_pos.w and
               drop_center_y >= recycle_bin_pos.y and drop_center_y <= recycle_bin_pos.y + recycle_bin_pos.h then
                print("Deleting icon:", dropped_icon_id)
                if self.di.eventBus then
                    self.di.eventBus:publish('request_icon_recycle', dropped_icon_id)
                    self.di.eventBus:publish('icon_drag_ended', dropped_icon_id, 'recycle_bin')
                else
                    local original_pos = self.desktop_icons:getPosition(dropped_icon_id)
                    self.recycle_bin:addItem(dropped_icon_id, original_pos); self.desktop_icons:save()
                end
                return -- Deleted
            end
        end

        -- 2. Start overlap resolution with initial drop position
    local final_x, final_y = initial_drop_x, initial_drop_y
        local overlap_resolved = false
        local attempts = 0
        local max_attempts = 15

        while not overlap_resolved and attempts < max_attempts do
            attempts = attempts + 1
            overlap_resolved = true -- Assume resolved

            -- A. Validate the current position first
            local current_valid_x, current_valid_y = self.desktop_icons:validatePosition(final_x, final_y, screen_w, screen_h)
            final_x, final_y = current_valid_x, current_valid_y -- Update to validated position

            local overlapping_icon_data = nil
            local desktop_programs = self.program_registry:getDesktopPrograms()

            -- B. Check overlap at the validated position
            for _, program in ipairs(desktop_programs) do
                if program.id ~= dropped_icon_id and not self.desktop_icons:isDeleted(program.id) then
                    local other_pos = self.desktop_icons:getPosition(program.id) or self.icon_controller:getDefaultIconPosition(program.id)
                    if Collision.checkAABB(final_x, final_y, icon_w, icon_h, other_pos.x, other_pos.y, icon_w, icon_h) then
                        overlapping_icon_data = { program_id = program.id, pos = other_pos }
                        overlap_resolved = false
                        print("Overlap detected with", program.id, "at attempt", attempts)
                        break
                    end
                end
            end

            -- C. If overlap found, try to nudge
            if not overlap_resolved and overlapping_icon_data then
                local other_pos = overlapping_icon_data.pos
                local dx = (final_x + icon_w / 2) - (other_pos.x + icon_w / 2)
                local dy = (final_y + icon_h / 2) - (other_pos.y + icon_h / 2)
                local overlap_x = (icon_w) - math.abs(dx)
                local overlap_y = (icon_h) - math.abs(dy)

                -- Potential nudge positions based on primary overlap axis
                local potential_nudges = {}
                if overlap_x < overlap_y then -- Horizontal primary
                    if dx > 0 then table.insert(potential_nudges, {x = other_pos.x + icon_w + padding, y = final_y}) else table.insert(potential_nudges, {x = other_pos.x - icon_w - padding, y = final_y}) end
                    if dy > 0 then table.insert(potential_nudges, {x = final_x, y = other_pos.y + icon_h + padding}) else table.insert(potential_nudges, {x = final_x, y = other_pos.y - icon_h - padding}) end
                else -- Vertical primary
                    if dy > 0 then table.insert(potential_nudges, {x = final_x, y = other_pos.y + icon_h + padding}) else table.insert(potential_nudges, {x = final_x, y = other_pos.y - icon_h - padding}) end
                    if dx > 0 then table.insert(potential_nudges, {x = other_pos.x + icon_w + padding, y = final_y}) else table.insert(potential_nudges, {x = other_pos.x - icon_w - padding, y = final_y}) end
                end

                local found_nudge = false
                for _, nudge in ipairs(potential_nudges) do
                    -- Validate the *potential* nudge position first
                    local valid_nudge_x, valid_nudge_y = self.desktop_icons:validatePosition(nudge.x, nudge.y, screen_w, screen_h)

                    -- Check if this *validated* nudge position is free
                    local nudge_overlaps = false
                    for _, program_check in ipairs(desktop_programs) do
                        if program_check.id ~= dropped_icon_id and not self.desktop_icons:isDeleted(program_check.id) then
                             local check_pos = self.desktop_icons:getPosition(program_check.id) or self.icon_controller:getDefaultIconPosition(program_check.id)
                             if Collision.checkAABB(valid_nudge_x, valid_nudge_y, icon_w, icon_h, check_pos.x, check_pos.y, icon_w, icon_h) then
                                  nudge_overlaps = true; break
                             end
                        end
                    end

                    -- If nudge is valid AND doesn't overlap, update final position and restart loop
                    if not nudge_overlaps then
                        -- Check if the nudge actually changed the position significantly
                        if math.abs(valid_nudge_x - final_x) > 1 or math.abs(valid_nudge_y - final_y) > 1 then
                            final_x, final_y = valid_nudge_x, valid_nudge_y
                            found_nudge = true
                            overlap_resolved = false -- Crucial: Restart loop to re-validate the new position against all icons
                            print("Nudged to", final_x, final_y)
                            break -- Exit inner nudge loop, restart outer while loop
                        else
                             -- Nudge resulted in same position (likely due to clamping), try next nudge
                             print("Nudge resulted in same position, trying next.")
                        end
                    end
                end -- End trying potential nudges

                -- If no successful nudge was found after trying all directions
                if not found_nudge then
                    print("Could not resolve overlap after trying nudges. Accepting last valid position.")
                    -- final_x, final_y remain the last successfully validated position (current_valid_x/y)
                    overlap_resolved = true -- Force exit the while loop
                end
            -- else: No overlap found at the current validated position, loop will exit
            end -- end if overlap found
        end -- end while loop

        if attempts >= max_attempts then
             print("Warning: Hit attempt limit trying to resolve icon overlap for", dropped_icon_id)
        end

        -- 4. Snap to grid if enabled
        if self.icon_snap and self.icon_controller and self.icon_controller.snapToGrid then
            final_x, final_y = self.icon_controller:snapToGrid(final_x, final_y)
            -- re-validate after snap
            final_x, final_y = self.desktop_icons:validatePosition(final_x, final_y, screen_w, screen_h)
        end
        -- Update position in the model
        if self.di.eventBus then
            self.di.eventBus:publish('request_icon_move', dropped_icon_id, final_x, final_y, screen_w, screen_h)
            self.di.eventBus:publish('icon_drag_ended', dropped_icon_id, 'desktop')
        end
        self.desktop_icons:save()
        print("Dropped icon", dropped_icon_id, "at final position", final_x, final_y)
    end

    -- Forward mouse release to focused window's state (content-relative)
    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window = self.window_manager:getWindowById(focused_id)
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window and window_state and window_state.mousereleased then
            local content_bounds = self.window_chrome:getContentBounds(window)
            local local_x = x - content_bounds.x
            local local_y = y - content_bounds.y
            pcall(window_state.mousereleased, window_state, local_x, local_y, button)
        end
    end
end

-- handleWindowEvent remains the same
function DesktopState:handleWindowEvent(event, x, y, button)
    local final_result = nil
    local event_bus = self.di and self.di.eventBus

    if event.type == "window_close" then
        local window = self.window_manager:getWindowById(event.window_id)
        if window then self.window_manager:rememberWindowPosition(window) end
        if event_bus then
            event_bus:publish('request_window_close', event.window_id)
        else
            self.window_manager:closeWindow(event.window_id)
        end
        final_result = { type = "window_action" }

    elseif event.type == "window_minimize" then
        if event_bus then
            event_bus:publish('request_window_minimize', event.window_id)
        else
            self.window_manager:minimizeWindow(event.window_id)
        end
        final_result = { type = "window_action" }

    elseif event.type == "window_maximize" then
        if event_bus then
            event_bus:publish('request_window_maximize', event.window_id, love.graphics.getWidth(), love.graphics.getHeight())
        else
            self.window_manager:maximizeWindow(event.window_id, love.graphics.getWidth(), love.graphics.getHeight())
        end

        -- Call setViewport on the state after maximizing
        local window = self.window_manager:getWindowById(event.window_id)
        if window then
            local window_data = self.window_states[event.window_id]
            local window_state = window_data and window_data.state
            if window_state and window_state.setViewport then
                local content_bounds = self.window_chrome:getContentBounds(window)
                pcall(window_state.setViewport, window_state,
                      content_bounds.x, content_bounds.y,
                      content_bounds.width, content_bounds.height)
            end
        end

        final_result = { type = "window_action" }

    elseif event.type == "window_restore" then
        if event_bus then
            event_bus:publish('request_window_restore', event.window_id)
        else
            self.window_manager:restoreWindow(event.window_id)
        end

        -- Call setViewport on the state after restoring
        local window = self.window_manager:getWindowById(event.window_id)
        if window then
            local window_data = self.window_states[event.window_id]
            local window_state = window_data and window_data.state
            if window_state and window_state.setViewport then
                local content_bounds = self.window_chrome:getContentBounds(window)
                pcall(window_state.setViewport, window_state,
                      content_bounds.x, content_bounds.y,
                      content_bounds.width, content_bounds.height)
            end
        end

        final_result = { type = "window_action" }

    elseif event.type == "window_drag_start" then
        local current_time = love.timer.getTime()
        local C = (self.di and self.di.config) or {}
        local dbl = (C and C.ui and C.ui.double_click_time) or 0.5
         if event.window_id == self.last_title_bar_click_id and current_time - self.last_title_bar_click_time < dbl then
             local window = self.window_manager:getWindowById(event.window_id)
             if window then
                 local program = self.program_registry:getProgram(window.program_type)
                 local defaults = program and program.window_defaults or {}
                 local is_resizable = (defaults.resizable ~= false)

                 if is_resizable then
                     if window.is_maximized then
                        if event_bus then event_bus:publish('request_window_restore', event.window_id) end
                     else
                        if event_bus then event_bus:publish('request_window_maximize', event.window_id, love.graphics.getWidth(), love.graphics.getHeight()) end
                     end

                     -- Call setViewport after toggle
                     local updated_window = self.window_manager:getWindowById(event.window_id)
                     if updated_window then
                         local window_data = self.window_states[event.window_id]
                         local window_state = window_data and window_data.state
                         if window_state and window_state.setViewport then
                             local content_bounds = self.window_chrome:getContentBounds(updated_window)
                             pcall(window_state.setViewport, window_state,
                                   content_bounds.x, content_bounds.y,
                                   content_bounds.width, content_bounds.height)
                         end
                     end
                 end
             end
             self.last_title_bar_click_id = nil
             self.last_title_bar_click_time = 0
             self.window_controller.dragging_window_id = nil
         else
             self.last_title_bar_click_id = event.window_id
             self.last_title_bar_click_time = current_time
         end
         final_result = { type = "window_action" }

    elseif event.type == "window_content_click" then
        local window_data = self.window_states[event.window_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.mousepressed then
             local result = nil
             local local_x = event.content_x
             local local_y = event.content_y
             local success, state_result = pcall(window_state.mousepressed, window_state, local_x, local_y, button)

             if success then
                 result = state_result
                 if type(result) == 'table' then
                     if result.type == "close_window" then
                         local window = self.window_manager:getWindowById(event.window_id)
                         if window then self.window_manager:rememberWindowPosition(window) end
                         -- Publish close request
                         if event_bus then event_bus:publish('request_window_close', event.window_id) end
                         final_result = { type = "window_closed_request" } -- Signal that we requested close
                     elseif result.type == "set_setting" then
                         if window_state.setSetting then
                             window_state:setSetting(result.id, result.value)
                         end
                         final_result = { type = "content_interaction" }
                     elseif result.type == "event" then
                         self:handleStateEvent(event.window_id, result)
                         final_result = { type = "content_interaction" }
                     elseif result.type == "content_interaction" then
                         final_result = { type = "content_interaction" }
                     else
                         final_result = result
                     end
                 elseif result == true then
                     final_result = { type = "content_interaction" }
                 end
             else
                  print("Error calling mousepressed on state for window " .. event.window_id .. ": " .. tostring(state_result))
             end
        end
        self.last_title_bar_click_id = nil
        self.last_title_bar_click_time = 0
    elseif event.type == "window_chrome_click" then
        final_result = { type = "window_action" }
        self.last_title_bar_click_id = nil
        self.last_title_bar_click_time = 0
    end

    return final_result
end

-- keypressed remains the same
function DesktopState:keypressed(key)
    self.idle_timer = 0
    if self.show_tutorial then
        local event = self.tutorial_view:keypressed(key)
        if event and event.name == "dismiss_tutorial" then self:dismissTutorial() end
        return true
    end

    -- Global: Alt+F4 should open Shutdown dialog (do not close the current window)
    local alt_down_global = love.keyboard.isDown('lalt') or love.keyboard.isDown('ralt')
    if alt_down_global and key == 'f4' then
        -- Use event bus to launch
        if self.event_bus then self.event_bus:publish('launch_program', 'shutdown_dialog') end
        return true
    end

    -- Global: Use Ctrl+Esc (Windows-style alternative) to toggle Start Menu; avoid Windows keys to prevent OS Start menu
    if (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) and key == 'escape' then
        if self.start_menu then self.start_menu:toggle(); self.start_menu_open = self.start_menu:isOpen() end
        return true
    end

    -- Focused window gets priority for most keys
    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state

        -- Pass other keypresses to focused window state
        if window_state and window_state.keypressed then
             local success, result = pcall(window_state.keypressed, window_state, key)
             if success then
                if type(result) == 'table' then
                     if result.type == "close_window" then self:closeWindowById(focused_id); return true -- Use helper
                     elseif result.type == "event" then self:handleStateEvent(focused_id, result); return true
                     elseif result.type == "content_interaction" then return true end
                elseif result == true then return true -- Handled by window state
                end
             else print("Error calling keypressed on state for window " .. focused_id .. ": " .. tostring(result)) end
            -- If state returned false or error, let global shortcuts check
        end
    end

    -- Start menu keyboard navigation: delegate to StartMenuState when open
    if self.start_menu and self.start_menu:isOpen() then
        local handled = self.start_menu:keypressed(key)
        if handled then return true end
    end

    -- Ctrl+R for Run dialog (now launches parametric input window with Run params)
    if (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')) and key == 'r' then
        if self.start_menu then self.start_menu:setOpen(false); self.start_menu_open = false end
        local params = {
            title = Strings.get('start.run', 'Run'),
            prompt = Strings.get('start.type_prompt','Type the name of a program:'),
            ok_label = Strings.get('buttons.ok','OK'),
            cancel_label = Strings.get('buttons.cancel','Cancel'),
            submit_event = 'run_execute',
        }
        -- Use event bus to launch
        if self.event_bus then self.event_bus:publish('launch_program', 'run_dialog', params) end
        return true
    end

    -- Debug menu toggle (F5)
    if key == 'f5' and self.state_machine then
        if self.state_machine.states[Constants.state.DEBUG] then
            local current_fullscreen_state_name = Constants.state.DESKTOP
            if self.state_machine.current_state == self.state_machine.states[Constants.state.DEBUG] then self.state_machine:switch(current_fullscreen_state_name)
            else self.state_machine:switch(Constants.state.DEBUG, current_fullscreen_state_name) end
             return true
        end
    end

    -- ESC: close Start Menu if open; else close focused window; else quit app (for fast debug)
     if key == 'escape' then
            if self.start_menu and self.start_menu:isOpen() then
                self.start_menu:setOpen(false)
                self.start_menu_open = false
                return true
            elseif focused_id then
             print("ESC pressed, closing window:", focused_id)
             self:closeWindowById(focused_id)
             return true
         else
             -- No focused windows: allow immediate quit (debug convenience)
             _G.APP_ALLOW_QUIT = true
             love.event.quit()
             return true
         end
    end

    return false -- Key not handled
end

-- toggleStartMenu remains the same
function DesktopState:toggleStartMenu()
    if self.start_menu then self.start_menu:toggle(); self.start_menu_open = self.start_menu:isOpen() end
end

-- textinput remains the same
function DesktopState:textinput(text)
    self.idle_timer = 0
     local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.textinput then
             local success, handled = pcall(window_state.textinput, window_state, text)
             if success and handled then
                 return -- Handled by window state
             elseif not success then
                  print("Error calling textinput on state for window " .. focused_id .. ": " .. tostring(handled))
             end
        end
    end

    -- If not handled by window, do nothing (Run is now its own window)
end

-- wheelmoved remains the same
function DesktopState:wheelmoved(x, y)
    self.idle_timer = 0
    -- Send to focused window first
    local focused_id = self.window_manager:getFocusedWindowId()
    if focused_id then
        local window_data = self.window_states[focused_id]
        local window_state = window_data and window_data.state
        if window_state and window_state.wheelmoved then
             -- Check if mouse is over the window content area before sending scroll
             local mx, my = love.mouse.getPosition()
             local window = self.window_manager:getWindowById(focused_id)
             if window then
                 local content_bounds = self.window_chrome:getContentBounds(window)
                 if mx >= content_bounds.x and mx <= content_bounds.x + content_bounds.width and
                    my >= content_bounds.y and my <= content_bounds.y + content_bounds.height then
                     local success, handled = pcall(window_state.wheelmoved, window_state, x, y)
                     if success and handled then
                         return -- Handled by window state
                     elseif not success then
                         print("Error calling wheelmoved on state for window " .. focused_id .. ": " .. tostring(handled))
                     end
                 end
             end
        end
    end
    -- Could add desktop background scroll handling here later if needed
end

-- handleStateEvent: Replace self:launchProgram with event publish
function DesktopState:handleStateEvent(window_id, event)
    print("Received event from window " .. window_id .. ": " .. tostring(event.name))

    local handlers = {
        next_level = function()
            self:closeWindowById(window_id)
            -- Publish launch event instead of calling directly
            if self.event_bus then self.event_bus:publish('launch_program', "space_defender", event.level) end
        end,
        show_completion = function()
            self:closeWindowById(window_id)
            self.state_machine:switch(Constants.state.COMPLETION)
        end,
        launch_program = function()
            -- Publish launch event instead of calling directly
            if self.event_bus then self.event_bus:publish('launch_program', event.program_id) end
        end,
        launch_minigame = function()
            if event.game_data then
                -- Publish launch event instead of calling directly
                if self.event_bus then self.event_bus:publish('launch_program', "minigame_runner", event.game_data) end
            else
                print("ERROR: launch_minigame event missing game_data!")
            end
        end,
        show_text = function()
            self:showTextFileDialog(event.title, event.content)
        end,
        show_context_menu = function()
            if self.di.contextMenuService then
                self.di.contextMenuService:show(event.menu_x, event.menu_y, event.options, event.context)
            end
        end,
        ensure_icon_visible = function()
            self:ensureIconIsVisible(event.program_id)
        end,
        shutdown_now = function()
            -- Allow quit and then quit
            _G.APP_ALLOW_QUIT = true
            love.event.quit()
        end,
        restart_now = function()
            _G.APP_ALLOW_QUIT = true
            love.event.quit('restart')
        end,
        run_execute = function()
            if event.command and event.command ~= '' then
                self:executeRunCommand(event.command)
            end
            -- Close the Run dialog window after executing
            self:closeWindowById(window_id)
        end,
        start_menu_create_folder = function()
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
                        -- Optionally adjust order bookkeeping if used by PR
                        if pr and pr.moveInStartMenuFolderOrder then
                            local dst_keys = {}
                            if self.start_menu and self.start_menu.view then
                                for _, p in ipairs(self.start_menu.view.open_panes or {}) do
                                    if p.kind == 'fs' and p.parent_path == parent_path then
                                        for _, it in ipairs(p.items or {}) do table.insert(dst_keys, (it.path or it.name)) end
                                        break
                                    end
                                end
                            end
                            pcall(pr.moveInStartMenuFolderOrder, pr, parent_path, new_path, after_idx, dst_keys)
                        end
                    end
                end
            elseif ctx.pane_kind == 'fs' and ctx.parent_path then
                -- Create a real folder under the given parent path and insert below index
                if fs and fs.createFolder then
                    local after_idx = (ctx.after_index or ctx.index or 0) + 1
                    local new_path = fs:createFolder(ctx.parent_path, name, after_idx)
                    if new_path and pr and pr.moveInStartMenuFolderOrder then
                        -- Update ordering to reflect the requested position
                        local dst_keys = {}
                        if self.start_menu and self.start_menu.view then
                            for _, p in ipairs(self.start_menu.view.open_panes or {}) do
                                if p.kind == 'fs' and p.parent_path == ctx.parent_path then
                                    for _, it in ipairs(p.items or {}) do table.insert(dst_keys, (it.path or it.name)) end
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
                    if p.kind == 'programs' then p.items = self.start_menu.view:buildPaneItems('programs', nil)
                    elseif p.kind == 'fs' and p.parent_path then p.items = self.start_menu.view:buildPaneItems('fs', p.parent_path) end
                end
            end
            -- Close the dialog window
            self:closeWindowById(window_id)
        end,
    }

    local handler = handlers[event.name]
    if handler then handler() end
end

-- executeRunCommand: Replace self:launchProgram with event publish
function DesktopState:executeRunCommand(command)
    command = command:gsub("^%s*(.-)%s*$", "%1"):lower() -- Trim whitespace and lower

    if command == "" then print("No command entered"); return end

    local program = self.program_registry:findByExecutable(command)
    if program then
        if not program.disabled then
            -- Publish launch event instead of calling directly
            if self.event_bus then self.event_bus:publish('launch_program', program.id) end
        else
            love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), string.format(Strings.get('messages.cannot_find_fmt', "Cannot find '%s'."), command), "error")
        end
    else
    love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), string.format(Strings.get('messages.cannot_find_fmt', "Cannot find '%s'."), command), "error")
    end
end

-- showTextFileDialog remains the same
function DesktopState:showTextFileDialog(title, content)
    love.window.showMessageBox(title, content or "[Empty File]", "info")
end

-- Handle file explorer actions from ContextMenuService
function DesktopState:handleFileExplorerAction(action_id, context)
    -- File Explorer actions - DesktopState still handles these directly until FE is refactored
    local window_id = context.window_id
    if not window_id then
        print("ERROR: window_id missing for file_explorer context!")
        return
    end

    if context.type == "file_explorer_item" or context.type == "file_explorer_empty" then
        -- File explorer actions remain the same (delegated to FE state)
        local fe_window_id = context.window_id
        local fe_state_data = fe_window_id and self.window_states[fe_window_id]
        local fe_state = fe_state_data and fe_state_data.state

        if fe_state and fe_state.handleItemDoubleClick then
            local item = context.item -- Might be nil for empty space clicks

            if action_id == "restore" and item then
                if item.type == 'deleted' then
                    fe_state:restoreFromRecycleBin(item.program_id)
                elseif item.type == 'fs_deleted' then
                    fe_state:restoreFsDeleted(item.recycle_id)
                end
            elseif action_id == "delete_permanently" and item then
                if item.type == 'deleted' then
                    fe_state:permanentlyDeleteFromRecycleBin(item.program_id)
                elseif item.type == 'fs_deleted' then
                    fe_state:permanentlyDeleteFsDeleted(item.recycle_id)
                end
            elseif action_id == "open" and item then
                 local result = fe_state:handleItemDoubleClick(item)
                 if type(result) == 'table' and result.type == "event" then self:handleStateEvent(fe_window_id, result) end
            elseif action_id == "create_shortcut_desktop" and item then
                 local result = fe_state:createShortcutOnDesktop(item)
                 if type(result) == 'table' and result.type == "event" then
                     self:handleStateEvent(fe_window_id, result) -- Pass event up
                 end
            elseif action_id == "create_shortcut_start_menu" and item then
                 local result = fe_state:createShortcutInStartMenu(item)
                 if type(result) == 'table' and result.type == "event" then
                     self:handleStateEvent(fe_window_id, result)
                 end
            elseif action_id == "remove_shortcut" and item then
                 if item.program_id and item.program_id:match('^shortcut_') then
                     local ok = self.program_registry:removeDynamicProgram(item.program_id)
                     if ok then
                         self.desktop_icons:permanentlyDelete(item.program_id)
                         self.desktop_icons:save()
                     end
                 end
          elseif action_id == "copy" and item then
              fe_state:copyItem(item)
          elseif action_id == "cut" and item then
              fe_state:cutItem(item)
          elseif action_id == "paste" then
              fe_state:pasteIntoCurrent()
          elseif action_id == "delete" and item then
                 fe_state:deleteItem(item)
            elseif action_id == "properties" then print("File properties NYI") -- Placeholder
            elseif action_id == "refresh" then fe_state:refresh() -- Handle refresh for empty space context
            else print("Warning: Unhandled file explorer action:", action_id)
            end
        else
            print("Error: Could not find relevant File Explorer state instance for window ID:", fe_window_id)
        end
    end
end

-- ensureIconIsVisible remains the same
function DesktopState:ensureIconIsVisible(program_id)
    if not program_id then return end

    print("Ensuring icon is visible for:", program_id)

    if self.di.eventBus then
        local default_pos = self:findNextAvailableGridPosition(program_id)
        local screen_w, screen_h = love.graphics.getDimensions()
        self.di.eventBus:publish('request_icon_create', program_id, default_pos.x, default_pos.y, screen_w, screen_h)
    end

    -- Save changes
    self.desktop_icons:save()
    -- Optional: Maybe briefly highlight the icon?
end

-- findNextAvailableGridPosition remains the same
function DesktopState:findNextAvailableGridPosition(program_id_to_place)
    self.view:calculateDefaultIconPositionsIfNeeded() -- Ensure defaults are calculated

    local occupied_positions = {} -- Store positions currently in use
    local desktop_programs = self.program_registry:getDesktopPrograms()
    local icon_w, icon_h = self.desktop_icons:getIconDimensions()

    for _, program in ipairs(desktop_programs) do
        -- Consider a spot occupied if the icon is visible and is NOT the one we are currently placing
        if program.id ~= program_id_to_place and self.desktop_icons:isIconVisible(program.id) then
             local pos = self.desktop_icons:getPosition(program.id) or self.icon_controller:getDefaultIconPosition(program.id)
             -- Use a simple representation for occupied check (e.g., top-left corner)
             occupied_positions[string.format("%.0f,%.0f", pos.x, pos.y)] = true
        end
    end

    -- Iterate through default positions in order
    local available_height = love.graphics.getHeight() - self.view.taskbar_height - self.view.icon_start_y
    local icons_per_column = math.max(1, math.floor(available_height / (icon_h + self.view.icon_padding)))
    local col = 0
    local row = 0

    while true do -- Loop until a spot is found (should always find one eventually)
         local potential_x = self.view.icon_start_x + col * (icon_w + self.view.icon_padding)
         local potential_y = self.view.icon_start_y + row * (icon_h + self.view.icon_padding)
         local pos_key = string.format("%.0f,%.0f", potential_x, potential_y)

         -- Check if this default grid position is occupied
         if not occupied_positions[pos_key] then
             print("Found available grid position:", potential_x, potential_y)
             return { x = potential_x, y = potential_y }
         end

         -- Move to next grid position
         row = row + 1
         if row >= icons_per_column then
             row = 0
             col = col + 1
             -- Add safety break if columns get too high?
             if col > 20 then
                  print("Warning: Could not find free grid slot easily, returning default.")
                  return self.icon_controller:getDefaultIconPosition(program_id_to_place) or { x=20, y=20 }
             end
         end
    end
end

-- findFileExplorerStateInstance remains the same
function DesktopState:findFileExplorerStateInstance(target_path)
     for win_id, win_data in pairs(self.window_states) do
         if win_data.state and win_data.state.__cname == "FileExplorerState" then
              -- If target_path is provided, match it. Otherwise, return first found.
              if not target_path or win_data.state.current_path == target_path then
                  return win_data.state
              end
         end
     end
     return nil -- Not found
end

-- closeWindowById remains the same
function DesktopState:closeWindowById(window_id)
      local window = self.window_manager:getWindowById(window_id)
      if window then self.window_manager:rememberWindowPosition(window) end

      -- Store program_id before closing for event
      local program_id = window and window.program_type or "unknown"

      local closed_successfully = false
      if self.di.eventBus then
          -- Publish request first
          self.di.eventBus:publish('request_window_close', window_id)
          -- Check if window was actually closed (WindowManager handles this on subscribe)
          if not self.window_manager:getWindowById(window_id) then
             closed_successfully = true
          end
      else
          -- Fallback direct call
          closed_successfully = self.window_manager:closeWindow(window_id)
      end

      -- Publish dialog_closed if it was a dialog and closed successfully
      if closed_successfully then
          local dialog_types = {run_dialog=true, shutdown_dialog=true, solitaire_back_picker=true, wallpaper_picker=true, solitaire_settings=true}
          if dialog_types[program_id] and self.event_bus then
              -- Assuming 'cancel' as default result for simple close; specific states might publish 'dialog_confirmed' before closing.
              pcall(self.event_bus.publish, self.event_bus, 'dialog_closed', program_id, window_id, 'cancel')
          end
      end
end

-- deleteDesktopIcon remains the same
function DesktopState:deleteDesktopIcon(program_id)
     if program_id ~= "recycle_bin" and program_id ~= "my_computer" then
         print("Deleting icon via context menu:", program_id)
         if self.di.eventBus then
             self.di.eventBus:publish('request_icon_recycle', program_id)
         else
             local original_pos = self.desktop_icons:getPosition(program_id)
             self.recycle_bin:addItem(program_id, original_pos)
             self.desktop_icons:save()
         end
     else
         print("Cannot delete core icon:", program_id)
     end
end

return DesktopState