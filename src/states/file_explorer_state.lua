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
    -- Clipboard for copy/cut/paste
    self.clipboard = nil -- { mode = 'copy'|'cut', src_path = '', name = '' }
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
    -- Disable copy/cut/paste shortcuts for now
    elseif key == 'delete' and self.selected_item and self.current_path == "/Recycle Bin" then
         -- Allow deleting from recycle bin view (desktop or FS items)
         if self.selected_item.type == 'deleted' then
             self:permanentlyDeleteFromRecycleBin(self.selected_item.program_id)
         elseif self.selected_item.type == 'fs_deleted' then
             self:permanentlyDeleteFsDeleted(self.selected_item.recycle_id)
         end
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
            -- Right-click on empty space: Generate folder context menu (no paste for now)
            local options = {}
            table.insert(options, { id = "refresh", label = "Refresh", enabled = true })
            table.insert(options, { id = "properties", label = "Properties (NYI)", enabled = false })
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
        if self.current_path == "/Recycle Bin" and (item.type == "deleted" or item.type == 'fs_deleted') then
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
                table.insert(options, { id = "create_shortcut_desktop", label = "Create Shortcut (Desktop)", enabled = (item.type ~= 'executable') or not is_visible })
                -- Start Menu shortcut option
                -- Always allow creating a Start Menu shortcut (creates a real FS entry in Programs)
                table.insert(options, { id = "create_shortcut_start_menu", label = "Create Shortcut (Start Menu)", enabled = true })
                if item.type == 'executable' and item.program_id and item.program_id:match('^shortcut_') then
                    table.insert(options, { id = "remove_shortcut", label = "Remove Shortcut", enabled = true })
                end
            end
            -- Disable Copy/Cut for now; keep Delete if allowed by FS rules
            local deletable = item and item.path and self.file_system.isDeletable and self.file_system:isDeletable(item.path)
            table.insert(options, { id = "delete", label = "Delete", enabled = deletable == true })
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
    if item and item.type == 'special' and (item.special_type == 'control_panel_general' or item.special_type == 'control_panel_desktop' or item.special_type == 'control_panel_screensavers') then
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
    -- Always forward to the view for generic interactions (e.g., scrollbar drags)
    if self.view and self.view.mousemoved then
        pcall(self.view.mousemoved, self.view, x, y, dx, dy, self.viewport.width, self.viewport.height, false)
    end
end

function FileExplorerState:mousereleased(x, y, button)
    if not self.viewport then return end
    if self.view and self.view.mousereleased then
        pcall(self.view.mousereleased, self.view, x, y, button)
        return { type = 'content_interaction' }
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
    local old_path = self.current_path or "/"
    -- Compute parent path directly (breadcrumb-style)
    local parent = old_path:match("(.+)/[^/]+$") or "/"
    if parent == "" then parent = "/" end
    -- Redirect the top-level to modern My Computer; hide legacy root from navigation
    if parent == "/" then parent = "/My Computer" end
    self:navigateTo(parent)
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
        return { type = "content_interaction" }
    elseif item.type == 'fs_deleted' then
        print("Double-click on FS-deleted item - attempting restore.")
        self:restoreFsDeleted(item.recycle_id)
        return { type = 'content_interaction' }
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
           elseif action.special_type == "my_documents" then self:navigateTo("/My Computer/C:/Documents"); return { type = "content_interaction" }
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
        -- Create a desktop folder shortcut via ProgramRegistry
        local name = item.name or "Folder"
        local program = self.program_registry:addFolderShortcut(name, item.path, { on_desktop = true, shortcut_type = 'folder', icon_sprite = 'directory_open_file_mydocs_small-0' })
        if program then
            love.window.showMessageBox(Strings.get('messages.info_title', 'Information'), "Shortcut created on Desktop.", "info")
            return { type = "event", name = "ensure_icon_visible", program_id = program.id }
        end
    elseif item.type == "file" then
        -- Optional: create shortcut to parent folder
        local name = item.name or "File"
        local icon = 'document-0'
        if name:match('%.txt$') then icon = 'notepad_file-0' elseif name:match('%.json$') then icon = 'file_lines-0' elseif name:match('%.exe$') then icon = 'executable-0' end
        local program = self.program_registry:addFolderShortcut(name, item.path, { on_desktop = true, shortcut_type = 'file', icon_sprite = icon })
        if program then
            love.window.showMessageBox(Strings.get('messages.info_title', 'Information'), "Shortcut to parent folder created on Desktop.", "info")
            return { type = "event", name = "ensure_icon_visible", program_id = program.id }
        end
    end
    return nil -- No action bubbled up yet
end

function FileExplorerState:createShortcutInStartMenu(item)
    print("Attempting to create start menu shortcut for:", item.name, "Type:", item.type)
    local okC, Constants = pcall(require, 'src.constants')
    local start_root = okC and Constants.paths and Constants.paths.START_MENU_PROGRAMS or nil
    if not (self.file_system and self.file_system.createExecutable and start_root) then return nil end

    if item.type == "executable" and item.program_id then
        -- Create an FS executable entry in Start Menu Programs pointing to this program
        local name = item.name or (self.program_registry:getProgram(item.program_id) and self.program_registry:getProgram(item.program_id).name) or "Program"
        local path = self.file_system:createExecutable(start_root, name, item.program_id)
        if path then love.window.showMessageBox(Strings.get('messages.info_title', 'Information'), "Shortcut created in Start Menu.", "info") end
        return { type = "content_interaction" }
    elseif item.type == "folder" then
        -- Create a real FS folder link under Start Menu Programs so it cascades and mirrors target
        local name = item.name or "Folder"
        local link_path = self.file_system.createFolderLink and self.file_system:createFolderLink(start_root, name, item.path)
        if link_path then
            love.window.showMessageBox(Strings.get('messages.info_title', 'Information'), "Shortcut created in Start Menu.", "info")
            return { type = "content_interaction" }
        end
    elseif item.type == "file" then
        -- For now, create an executable program launcher for files (could add file link later)
        local name = item.name or "File"
        local icon = 'document-0'
        if name:match('%.txt$') then icon = 'notepad_file-0' elseif name:match('%.json$') then icon = 'file_lines-0' elseif name:match('%.exe$') then icon = 'executable-0' end
        local program = self.program_registry:addFolderShortcut(name, item.path, { in_start_menu = false, shortcut_type = 'file', icon_sprite = icon })
        if program and program.id then
            local path = self.file_system:createExecutable(start_root, name, program.id)
            if path then love.window.showMessageBox(Strings.get('messages.info_title', 'Information'), "Shortcut created in Start Menu.", "info") end
            return { type = "content_interaction" }
        end
    end
    return nil
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
    -- Desktop icon deletions
    local deleted_items = self.recycle_bin:getItems()
    for _, item in ipairs(deleted_items) do
        local program = self.program_registry:getProgram(item.program_id)
        if program then
            table.insert(contents, {
                name = program.name,
                path = "/Recycle Bin/" .. program.name,
                type = "deleted",
                program_id = item.program_id,
                deleted_at = item.deleted_at,
                icon = program.icon_color,
                icon_sprite = program.icon_sprite,
                original_position = item.original_position
            })
        end
    end
    -- Filesystem deletions
    local fs_items = self.file_system.getFsRecycleBinItems and self.file_system:getFsRecycleBinItems() or {}
    for _, it in ipairs(fs_items) do
        local node = it.node or {}
        local display_name = it.name or (it.original_path or 'Item')
        local icon_sprite = nil
        if node.type == 'executable' and node.program_id then
            local program = self.program_registry:getProgram(node.program_id)
            icon_sprite = program and program.icon_sprite or nil
        end
        table.insert(contents, {
            name = display_name,
            path = "/Recycle Bin/" .. display_name,
            type = 'fs_deleted',
            recycle_id = it.id,
            original_path = it.original_path,
            deleted_at = it.deleted_at,
            icon_sprite = icon_sprite,
        })
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
        local count_desktop = self.recycle_bin:empty()
        local count_fs = self.file_system.emptyFsRecycleBin and self.file_system:emptyFsRecycleBin() or 0
        print("Emptied Recycle Bin (desktop=" .. tostring(count_desktop) .. ", fs=" .. tostring(count_fs) .. ")")
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

-- Restore FS-deleted item
function FileExplorerState:restoreFsDeleted(recycle_id)
    local ok, dst = self.file_system:restoreDeletedEntry(recycle_id)
    if ok then
        self:refresh()
    else
        love.window.showMessageBox(Strings.get('messages.error_title','Error'), "Failed to restore item", 'error')
    end
end

function FileExplorerState:permanentlyDeleteFsDeleted(recycle_id)
    local buttons = {"Yes, Delete", "Cancel"}
    local pressed = love.window.showMessageBox(
        Strings.get('messages.info_title','Information'),
        "Are you sure you want to permanently delete this item?",
        buttons,
        "warning"
    )
    if pressed == 1 then
        local ok = self.file_system:permanentlyDeleteEntry(recycle_id)
        if ok then self:refresh() end
    end
end

-- Delete a normal item (moves to FS recycle bin if allowed)
function FileExplorerState:deleteItem(item)
    if not item or not item.path then return end
    if not (self.file_system.isDeletable and self.file_system:isDeletable(item.path)) then
        love.window.showMessageBox(Strings.get('messages.error_title','Error'), "This item cannot be deleted.", 'error')
        return
    end
    local buttons = {"Yes, Delete", "Cancel"}
    local pressed = love.window.showMessageBox(Strings.get('messages.info_title','Information'), "Delete '".. (item.name or 'Item') .."' and move it to Recycle Bin?", buttons, 'warning')
    if pressed == 1 then
        local ok, err = self.file_system:deleteEntry(item.path)
        if not ok then
            love.window.showMessageBox(Strings.get('messages.error_title','Error'), "Delete failed: ".. tostring(err), 'error')
        else
            self:refresh()
        end
    end
end

-- Clipboard operations
function FileExplorerState:copyItem(item)
    if not item or not item.path then return end
    self.clipboard = { mode = 'copy', src_path = item.path, name = item.name or (item.path:match('([^/]+)$') or 'Item') }
end

function FileExplorerState:cutItem(item)
    if not item or not item.path then return end
    if not (self.file_system.isPathInDynamicRoot and self.file_system:isPathInDynamicRoot(item.path)) then return end
    self.clipboard = { mode = 'cut', src_path = item.path, name = item.name or (item.path:match('([^/]+)$') or 'Item') }
end

function FileExplorerState:pasteIntoCurrent()
    if not self.clipboard or not self.file_system then return end
    local dst_parent = self.current_path
    local dst_node = self.file_system:getItem(dst_parent)
    if not dst_node or dst_node.type ~= 'folder' then return end
    if not (self.file_system.canMoveOrCopy and self.file_system:canMoveOrCopy(self.clipboard.src_path, dst_parent)) then return end
    if self.clipboard.mode == 'copy' then
        local ok, _ = self.file_system:copyEntry(self.clipboard.src_path, dst_parent)
        if ok then self:refresh() end
    elseif self.clipboard.mode == 'cut' then
        local ok, _ = self.file_system:moveEntry(self.clipboard.src_path, dst_parent)
        if ok then self:refresh(); self.clipboard = nil end
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
                local empty = (self.recycle_bin:isEmpty() and (self.file_system.isFsRecycleBinEmpty and self.file_system:isFsRecycleBinEmpty()))
                title = "Recycle Bin" .. (empty and " (Empty)" or "")
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