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
local WindowEventDispatcher = require('src.services.window_event_dispatcher')

-- DEBUG: Check if WindowController loaded
if not WindowController then
    error("CRITICAL: WindowController failed to load!")
end
-- WindowController loaded

local DesktopState = Object:extend('DesktopState')

function DesktopState:init(di)
    -- Dependency Injection container
    self.di = di or {}

    -- Core dependencies from DI
    self.state_machine = self.di.stateMachine
    self.player_data = self.di.playerData
    self.statistics = self.di.statistics
    self.window_manager = self.di.windowManager
    self.desktop_icons = self.di.desktopIcons
    self.file_system = self.di.fileSystem
    self.recycle_bin = self.di.recycleBin
    self.program_registry = self.di.programRegistry
    self.vm_manager = self.di.vmManager
    self.cheat_system = self.di.cheatSystem
    self.save_manager = self.di.saveManager
    self.game_data = self.di.gameData
    self.event_bus = self.di.eventBus

    -- Controllers and views
    self.window_chrome = WindowChrome:new()
    self.window_states = {}
    self.window_controller = self.di.window_controller
    if not self.window_controller then
        print("CRITICAL ERROR [DesktopState]: WindowController not found in DI container!")
    end

    self.view = DesktopView:new(self.program_registry, self.player_data, self.window_manager, self.desktop_icons, self.recycle_bin, self.di)
    self.start_menu = StartMenuState:new(self.di, self)
    self.icon_controller = DesktopIconController:new(self.program_registry, self.desktop_icons, self.recycle_bin, self.di)
    self.tutorial_view = TutorialView:new(self)
    self.taskbar_controller = nil -- Created in main.lua
    self.event_dispatcher = WindowEventDispatcher:new(self.di)
    self.event_dispatcher:setStartMenu(self.start_menu)

    -- Settings and configuration
    local Config = self.di.config or {}
    local SettingsManager = self.di.settingsManager or require('src.utils.settings_manager')
    local colors = (Config.ui and Config.ui.colors) or {}
    local desktopCfg = (Config.ui and Config.ui.desktop) or {}

    -- Wallpaper settings
    self.wallpaper_type = SettingsManager.get('desktop_bg_type') or 'color'
    self.wallpaper_image = SettingsManager.get('desktop_bg_image')
    self.wallpaper_scale_mode = SettingsManager.get('desktop_bg_scale_mode') or 'fill'

    print("[DesktopState:init] Loaded wallpaper settings:")
    print("  type=" .. tostring(self.wallpaper_type))
    print("  image=" .. tostring(self.wallpaper_image))
    print("  scale_mode=" .. tostring(self.wallpaper_scale_mode))
    local default_color = (colors.desktop and colors.desktop.wallpaper) or {0, 0.5, 0.5}
    self.wallpaper_color = {
        SettingsManager.get('desktop_bg_r') or default_color[1],
        SettingsManager.get('desktop_bg_g') or default_color[2],
        SettingsManager.get('desktop_bg_b') or default_color[3]
    }

    -- Pre-load wallpaper image if set
    if self.wallpaper_type == 'image' and self.wallpaper_image then
        local ok, Wallpapers = pcall(require, 'src.utils.wallpapers')
        if ok and Wallpapers then
            -- Only validate and preload if we have a wallpaper set
            if not Wallpapers.getItemById(self.wallpaper_image) then
                print("[DesktopState] WARNING: Saved wallpaper not found: " .. tostring(self.wallpaper_image))
                -- Don't auto-select or save - just use fallback color
                self.wallpaper_image = nil
            else
                -- Preload the valid wallpaper
                pcall(Wallpapers.getImageCached, self.wallpaper_image)
            end
        end
    end

    -- Other desktop settings
    self.icon_snap = SettingsManager.get('desktop_icon_snap') ~= false
    self.show_tutorial = (self.di.showTutorialOnStartup ~= nil) and self.di.showTutorialOnStartup or not SettingsManager.get("tutorial_shown")
    self.start_menu_open = false
    self.last_title_bar_click_time = 0
    self.last_title_bar_click_id = nil
    self.cursors = self.di.systemCursors or {}

    -- Screensaver settings
    self.idle_timer = 0
    self.screensaver_timeout = SettingsManager.get('screensaver_timeout') or (desktopCfg.screensaver and desktopCfg.screensaver.default_timeout) or 10
    self.screensaver_enabled = SettingsManager.get('screensaver_enabled') ~= false

    -- Subscribe to EventBus events
    if self.event_bus then
        self.event_bus:subscribe('window_closed', function(window_id)
            self.window_states[window_id] = nil
        end)
        -- Subscribe to wallpaper changes to update live
        self.event_bus:subscribe('wallpaper_changed', function(new_wallpaper_id)
            print("[DesktopState] Received wallpaper_changed event: " .. tostring(new_wallpaper_id))
            self.wallpaper_type = 'image' -- Assume changing image sets type to image
            self.wallpaper_image = new_wallpaper_id
            print("[DesktopState] Set wallpaper_image to: " .. tostring(self.wallpaper_image))
            -- Prewarm cache
            local okW, WP = pcall(require, 'src.utils.wallpapers')
            if okW and WP and WP.getImageCached then pcall(WP.getImageCached, new_wallpaper_id) end
        end)
        -- Subscribe to other relevant setting changes if needed
        self.event_bus:subscribe('setting_changed', function(key, old_value, new_value)
            if key == 'desktop_bg_type' then
                self.wallpaper_type = new_value
            elseif key == 'desktop_bg_image' then
                self.wallpaper_image = new_value
            elseif key == 'desktop_bg_scale_mode' then
                self.wallpaper_scale_mode = new_value
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
        self.event_bus:subscribe('request_window_close', function(window_id)
            self:closeWindowById(window_id)
        end)
        self.event_bus:subscribe('window_state_event', function(window_id, event)
            self.event_dispatcher:handle(window_id, event, function(wid) self:closeWindowById(wid) end)
        end)

        -- Subscribe to icon events from DesktopIconController
        self.event_bus:subscribe('icon_double_clicked', function(program_id)
            local program = self.program_registry:getProgram(program_id)
            if not program then return end

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
                -- Launch the program
                self.event_bus:publish('launch_program', program_id)
            end
        end)

        self.event_bus:subscribe('icon_dropped_on_recycle_bin', function(program_id)
            -- Add to recycle bin with original position for restoration
            local original_pos = self.desktop_icons:getPosition(program_id)
            self.recycle_bin:addItem(program_id, original_pos)
            self.desktop_icons:save()
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

    -- Update taskbar controller
    if self.taskbar_controller then
        self.taskbar_controller:update(dt)
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
        if self.icon_controller then
            self.icon_controller:ensureDefaultPositions(sw, sh)
            -- Update icon controller with mouse position
            local mx, my = love.mouse.getPosition()
            self.icon_controller:update(dt, mx, my)
        end
        -- Only DesktopView (no start menu update here); StartMenuView handles menu state
        self.view:update(dt, false, self.icon_controller and self.icon_controller.dragging_icon_id)
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

    -- Screensaver idle tracking
    if self.screensaver_enabled then
        self.idle_timer = self.idle_timer + dt
        if self.idle_timer >= self.screensaver_timeout then
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
            self.icon_controller and self.icon_controller.dragging_icon_id
        )

    -- Draw windows respecting z-order from window manager
    local windows = self.window_manager:getAllWindows()
    for i = 1, #windows do
        local window = windows[i]
        if not window.is_minimized then
            self:drawWindow(window)
        end
    end

    -- Draw dragged icon on top of windows (delegated to icon controller)
    if self.icon_controller then
        self.icon_controller:drawDraggedIcon(self.view)
    end

    -- Draw taskbar
    if self.taskbar_controller then
        self.taskbar_controller:draw()
    end

    -- Draw start menu on top of windows and taskbar
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

    -- --- Start Menu Handling (Priority 2 - BEFORE windows) ---
    if self.start_menu and self.start_menu:isOpen() then
        if button == 1 then
            local consumed = self.start_menu:mousepressed(x, y, button)
            if consumed then return end -- Start menu consumed left-click
        elseif button == 2 then
            -- Right-click on start menu
            if self.start_menu:handleRightClick(x, y, self.di.contextMenuService) then
                return -- Start menu consumed right-click
            end
        end
    end

    -- --- Window Interaction Handling (Priority 3) ---
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
        if self.icon_controller then self.icon_controller:cancelDrag() end
        if handled_by_window then return end -- Return if window fully handled it (e.g., content interaction, button press)
    end


    -- --- Desktop UI / Empty Space Click Handling (Priority 4 - Only if not handled by window or start menu) ---
    if button == 1 then
        local clicked_specific_desktop_ui = false
        -- Start button handled by TaskbarController
        -- Start menu was already checked earlier (priority 2)
        -- Check desktop icons (delegated to DesktopIconController)
        local icon_result = self.icon_controller and self.icon_controller:mousepressed(x, y, button)
        if icon_result then
            clicked_specific_desktop_ui = true
            -- Icon controller handles drag/double-click internally and publishes events
        end
        -- Check taskbar (delegated to TaskbarController)
        if not icon_result and self.taskbar_controller then
            if self.taskbar_controller:mousepressed(x, y, button) then
                clicked_specific_desktop_ui = true
            end
        end
        -- If click wasn't on specific desktop UI or window chrome/content
       if not clicked_specific_desktop_ui and not click_handled then
           if self.start_menu then self.start_menu:setOpen(false); self.start_menu_open = false end
           if self.icon_controller then self.icon_controller:cancelDrag() end
        end

    elseif button == 2 then -- Right click
        -- Start Menu right-clicks already handled earlier (priority 2)
        -- Generate desktop/icon context menu
        local context_type = "desktop"; local context_data = {}
        -- Use controller for hit-test so we get accurate icon detection
        local icon_program_id = self.icon_controller and self.icon_controller:getProgramAtPosition(x, y) or self.view:getProgramAtPosition(x, y)
        local taskbar_button_id = self.taskbar_controller and self.taskbar_controller.view:getTaskbarButtonAtPosition(x, y)
        local start_menu_program_id = nil
        if self.start_menu and self.start_menu:isOpen() and self.start_menu.isPointInStartMenu and self.start_menu:isPointInStartMenu(x, y) then
            start_menu_program_id = self.start_menu:getStartMenuProgramAtPosition(x, y)
        end

        if start_menu_program_id and start_menu_program_id ~= "run" then context_type = "start_menu_item"; context_data = { program_id = start_menu_program_id }
        elseif icon_program_id then
            context_type = "icon";
            context_data = { program_id = icon_program_id }
            if self.di.eventBus then self.di.eventBus:publish('icon_right_clicked', icon_program_id, x, y) end
        elseif taskbar_button_id then
            context_type = "taskbar"
            context_data = { window_id = taskbar_button_id }
        end

        if self.di.contextMenuService then
            self.di.contextMenuService:show(x, y, context_type, { type = context_type, program_id = context_data.program_id, window_id = context_data.window_id })
        end
    end
end

-- Helper: Apply viewport to window state after resize/maximize/restore
function DesktopState:_applyViewportToWindow(window_id)
    local window = self.window_manager:getWindowById(window_id)
    if not window then return end

    local window_data = self.window_states[window_id]
    local window_state = window_data and window_data.state
    if window_state and window_state.setViewport then
        local content_bounds = self.window_chrome:getContentBounds(window)
        pcall(window_state.setViewport, window_state,
              content_bounds.x, content_bounds.y,
              content_bounds.width, content_bounds.height)
    end
end

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
                             self.event_dispatcher:handle(window.id, state_result, function(wid) self:closeWindowById(wid) end)
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

                    -- Call setViewport after double-click maximize/restore
                    self:_applyViewportToWindow(window.id)
                end
                self.last_title_bar_click_id = nil; self.last_title_bar_click_time = 0
                self.window_controller.dragging_window_id = nil
            else
                self.last_title_bar_click_id = window.id; self.last_title_bar_click_time = current_time
            end
            handled = true

        elseif window_event.type == "window_close" then
            if self.event_bus then
                self.event_bus:publish('request_window_close', window_event.window_id)
            else
                local win = self.window_manager:getWindowById(window_event.window_id)
                if win then self.window_manager:rememberWindowPosition(win) end
                self.window_manager:closeWindow(window_event.window_id)
            end
            handled = true
            self.last_title_bar_click_id = nil; self.last_title_bar_click_time = 0

        elseif window_event.type == "window_minimize" then
            if self.event_bus then
                self.event_bus:publish('request_window_minimize', window_event.window_id)
            else
                self.window_manager:minimizeWindow(window_event.window_id)
            end
            handled = true
            self.last_title_bar_click_id = nil; self.last_title_bar_click_time = 0

        elseif window_event.type == "window_maximize" then
            if self.event_bus then
                self.event_bus:publish('request_window_maximize', window_event.window_id, love.graphics.getWidth(), love.graphics.getHeight())
            else
                self.window_manager:maximizeWindow(window_event.window_id, love.graphics.getWidth(), love.graphics.getHeight())
            end
            self:_applyViewportToWindow(window_event.window_id)
            handled = true
            self.last_title_bar_click_id = nil; self.last_title_bar_click_time = 0

        elseif window_event.type == "window_restore" then
            if self.event_bus then
                self.event_bus:publish('request_window_restore', window_event.window_id)
            else
                self.window_manager:restoreWindow(window_event.window_id)
            end
            self:_applyViewportToWindow(window_event.window_id)
            handled = true
            self.last_title_bar_click_id = nil; self.last_title_bar_click_time = 0

        elseif window_event.type == "window_resize_start" or window_event.type == "window_chrome_click" then
            handled = true
            self.last_title_bar_click_id = nil; self.last_title_bar_click_time = 0
        end
    end

    return handled
end


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
    -- Handle Start Menu activation on release BEFORE forwarding to windows
    if self.start_menu and self.start_menu:isOpen() then
        local consumed = self.start_menu:mousereleased(x, y, button)
        if consumed then return end
    end
    -- Forward to window controller
    self.window_controller:mousereleased(x, y, button)


    -- Handle icon drop (delegated to DesktopIconController)
    if button == 1 and self.icon_controller then
        local drop_result = self.icon_controller:mousereleased(x, y, button)
        if drop_result then
            return -- Icon controller handled it
        end
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
                     elseif result.type == "event" then self.event_dispatcher:handle(focused_id, result, function(wid) self:closeWindowById(wid) end); return true
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

function DesktopState:toggleStartMenu()
    if self.start_menu then self.start_menu:toggle(); self.start_menu_open = self.start_menu:isOpen() end
end

function DesktopState:dismissTutorial()
    self.show_tutorial = false
    local SettingsManager = self.di.settingsManager or require('src.utils.settings_manager')
    SettingsManager.set("tutorial_shown", true)
end
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



function DesktopState:showTextFileDialog(title, content)
    love.window.showMessageBox(title, content or "[Empty File]", "info")
end



function DesktopState:ensureIconIsVisible(program_id)
    if not program_id then return end

    print("Ensuring icon is visible for:", program_id)

    -- Ensure view has calculated default positions
    if self.view then
        self.view:calculateDefaultIconPositionsIfNeeded()
    end

    if self.di.eventBus then
        local default_pos = self.icon_controller:findNextAvailablePosition(program_id, self.view)
        print("DEBUG: ensureIconIsVisible got position:", default_pos.x, default_pos.y)
        local screen_w, screen_h = love.graphics.getDimensions()
        self.di.eventBus:publish('request_icon_create', program_id, default_pos.x, default_pos.y, screen_w, screen_h)
    end

    -- Save changes
    self.desktop_icons:save()
    -- Optional: Maybe briefly highlight the icon?
end


function DesktopState:closeWindowById(window_id)
      local window = self.window_manager:getWindowById(window_id)
      if window then self.window_manager:rememberWindowPosition(window) end

      -- Store program_id before closing for event
      local program_id = window and window.program_type or "unknown"

      -- IMPORTANT: Don't publish 'request_window_close' here - this function IS the handler for that event!
      -- Publishing it again would create infinite recursion (stack overflow)
      -- Just call the window manager directly
      local closed_successfully = self.window_manager:closeWindow(window_id)

      -- Publish dialog_closed if it was a dialog and closed successfully
      if closed_successfully then
          local dialog_types = {run_dialog=true, shutdown_dialog=true, solitaire_back_picker=true, wallpaper_picker=true, solitaire_settings=true}
          if dialog_types[program_id] and self.event_bus then
              -- Assuming 'cancel' as default result for simple close; specific states might publish 'dialog_confirmed' before closing.
              pcall(self.event_bus.publish, self.event_bus, 'dialog_closed', program_id, window_id, 'cancel')
          end
      end
end


function DesktopState:deleteDesktopIcon(program_id)
     if program_id ~= "recycle_bin" and program_id ~= "my_computer" then
         -- This function is called by the event subscriber, so DON'T publish the event again
         local original_pos = self.desktop_icons:getPosition(program_id)
         self.recycle_bin:addItem(program_id, original_pos)
         self.desktop_icons:save()
     else
         print("Cannot delete core icon:", program_id)
     end
end

return DesktopState