-- src/states/file_explorer_state.lua
-- State for browsing the virtual filesystem

local Object = require('class')
local FileExplorerView = require('src.views.file_explorer_view')
local Strings = require('src.utils.strings')

local FileExplorerState = Object:extend('FileExplorerState')

function FileExplorerState:init(file_system, program_registry, desktop_icons, recycle_bin, di)
    self.file_system = file_system
    self.program_registry = program_registry
    self.desktop_icons = desktop_icons
    self.recycle_bin = recycle_bin -- Injected dependency

    -- Capture DI if provided by DesktopState dependency_provider
    self.di = di
    self.view = FileExplorerView:new(self, di)

    -- Navigation state
    self.current_path = "/"
    self.history = {"/"}
    self.history_index = 1

    -- View state
    self.view_mode = "list"
    self.sort_by = "name"
    self.sort_order = "asc"

    -- Selection state
    self.selected_item = nil

    -- Viewport
    self.viewport = nil

    -- Window context
    self.window_id = nil
    self.window_manager = nil

    -- No modal applet state; Control Panel applets are programs
end

-- Method to receive window context from DesktopState
function FileExplorerState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

function FileExplorerState:setViewport(x, y, width, height)
    self.viewport = {x = x, y = y, width = width, height = height}
    if self.view.updateLayout then
        self.view:updateLayout(width, height)
    end
end

function FileExplorerState:enter(initial_path)
    -- Navigate to initial path if provided, otherwise default
    local path_to_set = initial_path or "/"
    self.current_path = path_to_set -- Set path before updating title
    self:_updateTitle() -- Update title on enter
    self:navigateTo(path_to_set, true) -- Pass flag to skip history push

    print("File Explorer opened at: " .. self.current_path)
end

function FileExplorerState:update(dt)
    if not self.viewport then return end

    if self.view.update then
        self.view:update(dt, self.viewport.width, self.viewport.height)
    end
end

function FileExplorerState:draw()
    if not self.viewport then return end
    -- REMOVED push/translate/scissor/pop
    local current_view_items = self:getCurrentViewContents()
    self.view:drawWindowed(
        self.current_path,
        current_view_items,
        self.selected_item,
        self.view_mode,
        self.sort_by,
        self.sort_order,
        self:canGoBack(),
        self:canGoForward(),
        self.current_path == "/Recycle Bin",
        self.viewport.width,
        self.viewport.height
    )
    -- REMOVED setScissor/pop
end

function FileExplorerState:keypressed(key)
    if key == 'escape' then
        return { type = "close_window" }
    elseif key == 'backspace' then
        self:goUp()
        return { type = "content_interaction" }
    elseif key == 'left' and (love.keyboard.isDown('lalt') or love.keyboard.isDown('ralt')) then
        self:goBack()
        return { type = "content_interaction" }
    elseif key == 'right' and (love.keyboard.isDown('lalt') or love.keyboard.isDown('ralt')) then
        self:goForward()
        return { type = "content_interaction" }
    elseif key == 'f5' then
        self:refresh()
        return { type = "content_interaction" }
    elseif key == 'delete' and self.selected_item and self.current_path == "/Recycle Bin" then
         -- Allow deleting from recycle bin view
         self:permanentlyDeleteFromRecycleBin(self.selected_item.program_id)
         return { type = "content_interaction" }
    end

    return false
end

function FileExplorerState:mousepressed(x, y, button)
    -- x, y are ALREADY LOCAL content coordinates from DesktopState
    if not self.viewport then return false end

    -- Check if click is outside the logical content bounds (0,0 to width, height)
    if x < 0 or x > self.viewport.width or y < 0 or y > self.viewport.height then
        return false
    end

    local current_view_items = self:getCurrentViewContents() -- Use helper


    -- Delegate directly to view with the LOCAL coordinates
    local view_event = self.view:mousepressed(x, y, button, current_view_items, self.viewport.width, self.viewport.height)

    -- If the view didn't detect an interaction on a specific UI element (toolbar button, item)
    if not view_event then
        if button == 1 then
            self.selected_item = nil -- Deselect on empty space left click
        elseif button == 2 then
            -- Right-click on empty space: Generate folder context menu
            local options = {
                { id = "refresh", label = "Refresh", enabled = true },
                { id = "properties", label = "Properties (NYI)", enabled = false }
            }
            -- Calculate SCREEN coordinates for the context menu based on viewport and local click
            local screen_x = self.viewport.x + x
            local screen_y = self.viewport.y + y
            -- Bubble up event to DesktopState
            return {
                type = "event",
                name = "show_context_menu",
                menu_x = screen_x,
                menu_y = screen_y,
                options = options,
                context = { type = "file_explorer_empty", current_path = self.current_path, window_id = self.window_id } -- Include window_id
            }
        end
        -- If no event bubbled up, still signal content interaction (e.g., deselection)
        return { type = "content_interaction" }
    end

    -- If the view *did* return an event, process it via dispatch
    local handlers = {}

    handlers.navigate_up = function()
        self:goUp()
        return { type = 'content_interaction' }
    end

    handlers.navigate_back = function()
        self:goBack()
        return { type = 'content_interaction' }
    end

    handlers.navigate_forward = function()
        self:goForward()
        return { type = 'content_interaction' }
    end

    handlers.navigate_path = function()
        self:navigateTo(view_event.path)
        return { type = 'content_interaction' }
    end

    handlers.item_click = function()
        self:handleItemClick(view_event.item)
        return { type = 'content_interaction' }
    end

    handlers.item_double_click = function()
        return self:handleItemDoubleClick(view_event.item)
    end

    handlers.set_setting = function()
        if not view_event.id then return { type = 'content_interaction' } end
        local SettingsManager = require('src.utils.settings_manager')
        SettingsManager.set(view_event.id, view_event.value)
        return { type = 'content_interaction' }
    end

    handlers.noop = function()
        return { type = 'content_interaction' }
    end

    handlers.item_right_click = function()
        self.selected_item = view_event.item
        local options = {}
        local item = view_event.item
        if self.current_path == "/Recycle Bin" and item.type == "deleted" then
            options = {
                { id = "restore", label = "Restore", enabled = true },
                { id = "separator" },
                { id = "delete_permanently", label = "Delete Permanently", enabled = true },
                { id = "separator" },
                { id = "properties", label = "Properties (NYI)", enabled = false },
            }
        else
            options = { { id = "open", label = "Open", enabled = true }, { id = "separator" } }
            local can_create_shortcut = (item.type == "executable" or item.type == "folder" or item.type == "file")
            if can_create_shortcut then
                local target_program_id = item.program_id
                local is_visible = (item.type == "executable" and target_program_id) and self.desktop_icons:isIconVisible(target_program_id) or false
                table.insert(options, { id = "create_shortcut_desktop", label = "Create Shortcut (Desktop)", enabled = not is_visible })
            end
            table.insert(options, { id = "delete", label = "Delete (NYI)", enabled = true })
            table.insert(options, { id = "separator" })
            table.insert(options, { id = "properties", label = "Properties (NYI)", enabled = false })
        end

        local screen_x = self.viewport.x + x
        local screen_y = self.viewport.y + y
        return {
            type = "event",
            name = "show_context_menu",
            menu_x = screen_x,
            menu_y = screen_y,
            options = options,
            context = { type = "file_explorer_item", item = item, current_path = self.current_path, window_id = self.window_id },
        }
    end

    handlers.empty_recycle_bin = function()
        self:emptyRecycleBin()
        return { type = 'content_interaction' }
    end

    handlers.refresh = function()
        self:refresh()
        return { type = 'content_interaction' }
    end

    local handler = handlers[view_event.name]
    if handler then
        return handler()
    end

    -- Default: some event was returned but we didn't have a handler; treat as interaction
    return { type = 'content_interaction' }
end

function FileExplorerState:wheelmoved(x, y)
    if not self.viewport then return end

    local mx, my = love.mouse.getPosition()
    -- Check if mouse is within this window's viewport before delegating
    if mx >= self.viewport.x and mx <= self.viewport.x + self.viewport.width and
       my >= self.viewport.y and my <= self.viewport.y + self.viewport.height then
        if self.view.wheelmoved then
            self.view:wheelmoved(x, y, self.viewport.width, self.viewport.height)
        end
    end
end

-- No modal-specific mousemoved needed

function FileExplorerState:mousemoved(x, y, dx, dy)
    -- delegate to view/app-specific if in Control Panel applet
    if not self.viewport then return end
    local item = self.file_system:getItem(self.current_path)
    if item and item.type == 'special' and (item.special_type == 'control_panel_general' or item.special_type == 'control_panel_screensavers') then
        local content_y = self.view.toolbar_height + self.view.address_bar_height
        local content_h = self.viewport.height - content_y - self.view.status_bar_height
        if y >= content_y and y <= content_y + content_h then
            -- Adjust local Y for content area
            local local_y = y - content_y
            if self.view.control_panel_view and self.view.control_panel_view.mousemoved then
                local ev = self.view.control_panel_view:mousemoved(x, local_y, dx, dy, item.special_type)
                if ev and ev.name == 'set_setting' then
                    local SettingsManager = require('src.utils.settings_manager')
                    SettingsManager.set(ev.id, ev.value)
                end
            end
        end
    end
end

-- Helper function to get the correct content list based on path
function FileExplorerState:getCurrentViewContents()
    local contents, err = self.file_system:getContents(self.current_path)

    if err then
        print("Error getting filesystem contents:", err)
        return {} -- Return empty list on error
    end

    if contents and contents.type == "special" then
        if contents.special_type == "desktop_view" then
            return self:getDesktopContents()
        elseif contents.special_type == "recycle_bin" then
            return self:getRecycleBinContents()
        else
             return {} -- Unknown special type
        end
    elseif type(contents) ~= "table" then
         return {} -- Not a folder or known special type
    end

    return contents -- Return the list of files/folders
end


-- Navigation methods modification
function FileExplorerState:navigateTo(path, skip_history)
    local success, err = self.file_system:navigate(path)

    if success then
        self.current_path = path
        self.selected_item = nil
        self:_updateTitle() -- **Update title**

        if not skip_history then
            -- Clear forward history
            while #self.history > self.history_index do
                table.remove(self.history)
            end
            -- Add to history if it's a new path
            if self.history[self.history_index] ~= path then
                table.insert(self.history, path)
                self.history_index = #self.history
            end
        end

        print("Navigated to: " .. path)
        self:refresh() -- Refresh view after navigation
    else
        print("Failed to navigate to " .. path .. ": " .. tostring(err))
    end
end

function FileExplorerState:goUp()
    local old_path = self.current_path
    -- Handle special cases: Desktop goes to My Computer, C: goes to My Computer
    if old_path == "/My Computer/Desktop" or old_path:match("^/My Computer/C:") or old_path:match("^/My Computer/D:") then
         self:navigateTo("/My Computer")
         return
    elseif old_path == "/My Computer" or old_path == "/Recycle Bin" then
         self:navigateTo("/")
         return
    end

    -- Standard filesystem up navigation
    local success, err = self.file_system:goUp()

    if success then
        local new_path = self.file_system:getCurrentPath()
        self.current_path = new_path
        self.selected_item = nil
        self:_updateTitle() -- **Update title**

        while #self.history > self.history_index do
            table.remove(self.history)
        end
        if self.history[self.history_index] ~= new_path then
            table.insert(self.history, new_path)
            self.history_index = #self.history
        end
        self:refresh() -- Refresh view
    end
end

function FileExplorerState:goBack()
    if self.history_index > 1 then
        self.history_index = self.history_index - 1
        local path = self.history[self.history_index]
        self.file_system:navigate(path) -- FileSystem internal state updated
        self.current_path = path       -- State's path updated
        self.selected_item = nil
        self:_updateTitle() -- **Update title**
        self:refresh() -- Refresh view
    end
end

function FileExplorerState:goForward()
    if self.history_index < #self.history then
        self.history_index = self.history_index + 1
        local path = self.history[self.history_index]
        self.file_system:navigate(path) -- FileSystem internal state updated
        self.current_path = path       -- State's path updated
        self.selected_item = nil
        self:_updateTitle() -- **Update title**
        self:refresh() -- Refresh view
    end
end

function FileExplorerState:canGoBack()
    return self.history_index > 1
end

function FileExplorerState:canGoForward()
    return self.history_index < #self.history
end

function FileExplorerState:refresh()
    self.selected_item = nil
    -- Force view scroll reset
    if self.view.resetScroll then self.view:resetScroll() end
    -- Update title in case it changed due to content (e.g., Recycle Bin empty state)
    self:_updateTitle()
end

function FileExplorerState:handleItemClick(item)
    self.selected_item = item
end

function FileExplorerState:handleItemDoubleClick(item)
    -- Check if it's a deleted item from Recycle Bin view
    if item.type == "deleted" then
        print("Double-click on deleted item - attempting restore.")
        self:restoreFromRecycleBin(item.program_id)
        -- Return content_interaction as an action occurred
        return { type = "content_interaction" }
    end

    -- Original logic for non-deleted items:
    local action = self.file_system:openItem(item.path)

    if action and action.type ~= "error" then
        if action.type == "navigate" then
            self:navigateTo(action.path)
            return { type = "content_interaction" }
        elseif action.type == "launch_program" then
            return { type = "event", name = "launch_program", program_id = action.program_id }
        elseif action.type == "show_text" then
            return { type = "event", name = "show_text", title = action.title, content = action.content }
        elseif action.type == "special" then
             if action.special_type == "desktop_view" then self:navigateTo("/My Computer/Desktop"); return { type = "content_interaction" }
             elseif action.special_type == "recycle_bin" then self:navigateTo("/Recycle Bin"); return { type = "content_interaction" }
             end
        end
    elseif action and action.type == "error" then
        print("Error opening item: " .. action.message)
    love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), "Cannot open item: " .. action.message, "error")
    end
    return action and { type = "content_interaction" } or nil
end

function FileExplorerState:createShortcutOnDesktop(item)
    print("Attempting to create shortcut for:", item.name, "Type:", item.type)
    if item.type == "executable" and item.program_id then
        -- For executables, ensure the original icon is visible
        -- DesktopState.ensureIconIsVisible handles this logic
        return { type = "event", name = "ensure_icon_visible", program_id = item.program_id }
    elseif item.type == "folder" then
        -- TODO: Implement folder shortcut logic (needs new icon type/data)
    love.window.showMessageBox(Strings.get('messages.info_title', 'Information'), "Creating shortcuts for folders is not yet implemented.", "info")
    elseif item.type == "file" then
        -- TODO: Implement file shortcut logic (needs new icon type/data)
    love.window.showMessageBox(Strings.get('messages.info_title', 'Information'), "Creating shortcuts for files is not yet implemented.", "info")
    end
    return nil -- No action bubbled up yet
end

function FileExplorerState:getDesktopContents()
    local contents = {}
    local desktop_programs = self.program_registry:getDesktopPrograms()

    for _, program in ipairs(desktop_programs) do
        -- Only include if *not* deleted according to DesktopIcons model
        if not self.desktop_icons:isDeleted(program.id) then
            table.insert(contents, {
                name = program.name,
                path = "/My Computer/Desktop/" .. program.name, -- Use name for display path
                type = "executable", -- Treat desktop icons as executables for opening
                program_id = program.id,
                icon = program.icon_color -- Pass color for custom icon
            })
        end
    end

    return contents
end

-- Fetch items directly from the RecycleBin model
function FileExplorerState:getRecycleBinContents()
    local contents = {}
    local deleted_items = self.recycle_bin:getItems() -- Get items from the model

    for _, item in ipairs(deleted_items) do
        local program = self.program_registry:getProgram(item.program_id)
        if program then
            table.insert(contents, {
                name = program.name,
                path = "/Recycle Bin/" .. program.name, -- Fake path for display consistency
                type = "deleted", -- Special type for view rendering
                program_id = item.program_id,
                deleted_at = item.deleted_at,
                icon = program.icon_color, -- Use program's icon color
                original_position = item.original_position -- Pass original pos if needed
            })
        end
    end

    return contents
end

-- Restore item using the RecycleBin model
function FileExplorerState:restoreFromRecycleBin(program_id)
    print("[DEBUG] restoreFromRecycleBin called for:", program_id) -- DEBUG
    local sw, sh = love.graphics.getDimensions()
    local success = self.recycle_bin:restoreItem(program_id, sw, sh)

    if success then
        print("Restored " .. program_id .. " from Recycle Bin")
        self.desktop_icons:save() -- Persist the restoration
        self:refresh() -- Refresh the current view to show changes
    else
        print("Failed to restore " .. program_id)
        -- Optionally show an error message to the user
        -- love.window.showMessageBox("Error", "Failed to restore " .. program_id, "error")
    end
end

-- Empty recycle bin using the RecycleBin model
function FileExplorerState:emptyRecycleBin()
     -- Confirmation dialog
    local buttons = {"Yes, Empty", "Cancel"}
    local pressed = love.window.showMessageBox(
        Strings.get('messages.info_title', 'Information'),
        "Are you sure you want to permanently delete all items in the Recycle Bin?",
        buttons, "warning"
    )

    if pressed == 1 then -- "Yes, Empty"
        local count = self.recycle_bin:empty()
        print("Emptied Recycle Bin (" .. count .. " items).")
        self:refresh() -- Refresh the view
    end
end

-- Permanently delete a single item from recycle bin
function FileExplorerState:permanentlyDeleteFromRecycleBin(program_id)
     local program = self.program_registry:getProgram(program_id)
     local name = program and program.name or program_id

     local buttons = {"Yes, Delete", "Cancel"}
      local pressed = love.window.showMessageBox(
          Strings.get('messages.info_title', 'Information'),
        "Are you sure you want to permanently delete '".. name .."'?",
        buttons, "warning"
     )

     if pressed == 1 then
         local success = self.recycle_bin:permanentlyDelete(program_id)
         if success then
             print("Permanently deleted " .. program_id)
             self:refresh()
         else
             print("Failed to permanently delete " .. program_id)
         end
     end
end


-- Helper function to update the window title
function FileExplorerState:_updateTitle()
    if not self.window_manager or not self.window_id then return end -- Guard

    local title = "File Explorer" -- Default
    local item = self.file_system:getItem(self.current_path)

    if item then
        if item.type == "special" then
            if item.special_type == "desktop_view" then
                title = "Desktop"
            elseif item.special_type == "recycle_bin" then
                title = "Recycle Bin" .. (self.recycle_bin:isEmpty() and " (Empty)" or "") -- Add empty status
            elseif item.special_type == 'control_panel_general' or item.special_type == 'control_panel_screensavers' then
                title = "Control Panel"
            end
        elseif self.current_path == "/" then
             title = "My Computer" -- Special case for root
        elseif self.current_path == "/My Computer" then
             title = "My Computer"
        else
            -- Extract last part of the path
            local _, _, last_part = self.current_path:find(".*/(.*)")
            if last_part then
                title = last_part
            end
        end
    end

    self.window_manager:updateWindowTitle(self.window_id, title)
end

-- Restore item using the RecycleBin model (called by DesktopState via handleContextMenuAction)
function FileExplorerState:restoreFromRecycleBin(program_id)
    print("[DEBUG FE State] restoreFromRecycleBin called for:", program_id)
    local sw, sh = love.graphics.getDimensions()
    local success = self.recycle_bin:restoreItem(program_id, sw, sh)
    if success then
        print("Restored " .. program_id .. " from Recycle Bin")
        self.desktop_icons:save() -- Persist the restoration
        self:refresh() -- Refresh the current view
    else
        print("Failed to restore " .. program_id)
    love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), "Failed to restore " .. program_id, "error")
    end
end

-- Permanently delete a single item (called by DesktopState via handleContextMenuAction)
function FileExplorerState:permanentlyDeleteFromRecycleBin(program_id)
     local program = self.program_registry:getProgram(program_id)
     local name = program and program.name or program_id

     local buttons = {"Yes, Delete", "Cancel"}
      local pressed = love.window.showMessageBox(
          Strings.get('messages.info_title', 'Information'),
        "Are you sure you want to permanently delete '".. name .."'?",
        buttons, "warning"
     )
     if pressed == 1 then
         local success = self.recycle_bin:permanentlyDelete(program_id)
         if success then
             print("Permanently deleted " .. program_id)
             self:refresh()
         else
             print("Failed to permanently delete " .. program_id)
             love.window.showMessageBox(Strings.get('messages.error_title', 'Error'), "Failed to delete " .. program_id, "error")
         end
     end
end

return FileExplorerState