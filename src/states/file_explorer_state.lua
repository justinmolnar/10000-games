-- src/states/file_explorer_state.lua
-- State for browsing the virtual filesystem

local Object = require('class')
local FileExplorerView = require('src.views.file_explorer_view')

local FileExplorerState = Object:extend('FileExplorerState')

function FileExplorerState:init(file_system, program_registry, desktop_icons, recycle_bin)
    self.file_system = file_system
    self.program_registry = program_registry
    self.desktop_icons = desktop_icons
    self.recycle_bin = recycle_bin -- Injected dependency

    self.view = FileExplorerView:new(self)

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

    love.graphics.push()
    love.graphics.translate(self.viewport.x, self.viewport.y)
    love.graphics.setScissor(self.viewport.x, self.viewport.y, self.viewport.width, self.viewport.height)

    local current_view_items = self:getCurrentViewContents() -- Use helper

    self.view:drawWindowed(
        self.current_path,
        current_view_items, -- Pass processed items
        self.selected_item,
        self.view_mode,
        self.sort_by,
        self.sort_order,
        self:canGoBack(),
        self:canGoForward(),
        self.current_path == "/Recycle Bin", -- Pass flag if recycle bin
        self.viewport.width,
        self.viewport.height
    )

    love.graphics.setScissor()
    love.graphics.pop()
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
    if not self.viewport then return false end

    -- Check viewport bounds first
    if x < 0 or x > self.viewport.width or y < 0 or y > self.viewport.height then
        return false -- Click outside the window's content area
    end

    local current_view_items = self:getCurrentViewContents() -- Use helper

    -- Let the view determine if a specific element *within the view's layout* was clicked
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
            local screen_x = (self.viewport and self.viewport.x or 0) + x
            local screen_y = (self.viewport and self.viewport.y or 0) + y
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
        return { type = "content_interaction" } -- Window processed the click (focus, deselect)
    end

    -- If the view *did* return an event, process it
    local result_action = nil -- This will hold events TO BE SENT UP to DesktopState

    if view_event.name == "navigate_up" then self:goUp()
    elseif view_event.name == "navigate_back" then self:goBack()
    elseif view_event.name == "navigate_forward" then self:goForward()
    elseif view_event.name == "navigate_path" then self:navigateTo(view_event.path)
    elseif view_event.name == "item_click" then self:handleItemClick(view_event.item) -- Left-click select
    elseif view_event.name == "item_double_click" then result_action = self:handleItemDoubleClick(view_event.item) -- Left-double-click open/restore

    elseif view_event.name == "item_right_click" then -- Right-click context generated by the view
        self.selected_item = view_event.item -- Select the item right-clicked

        -- Generate context menu options based on current path and item type
        local options = {}
        local item = view_event.item -- For clarity

        if self.current_path == "/Recycle Bin" and item.type == "deleted" then
            options = {
                { id = "restore", label = "Restore", enabled = true },
                { id = "separator" },
                { id = "delete_permanently", label = "Delete Permanently", enabled = true },
                { id = "separator" },
                { id = "properties", label = "Properties (NYI)", enabled = false }
            }
        else -- Normal file/folder/program
            options = {
                { id = "open", label = "Open", enabled = true },
                { id = "separator" },
            }
            -- Add "Create Shortcut" for executables, folders, and files
            local can_create_shortcut = (item.type == "executable" or item.type == "folder" or item.type == "file")
            if can_create_shortcut then
                 local target_program_id = item.program_id -- For executables
                 -- Determine if icon already exists for executables
                 local is_visible = (item.type == "executable" and target_program_id) and self.desktop_icons:isIconVisible(target_program_id) or false
                 table.insert(options, {
                     id = "create_shortcut_desktop",
                     label = "Create Shortcut (Desktop)",
                     enabled = not is_visible -- Enable only if not currently visible (or always for files/folders for now)
                 })
            end
            table.insert(options, { id = "delete", label = "Delete (NYI)", enabled = true }) -- Placeholder
            table.insert(options, { id = "separator" })
            table.insert(options, { id = "properties", label = "Properties (NYI)", enabled = false })
        end

        -- Calculate screen coordinates for the menu
        local screen_x = (self.viewport and self.viewport.x or 0) + x
        local screen_y = (self.viewport and self.viewport.y or 0) + y

        -- Bubble up an event telling DesktopState to show the menu
        result_action = {
            type = "event",
            name = "show_context_menu",
            menu_x = screen_x,
            menu_y = screen_y,
            options = options,
            -- Ensure context includes enough info for DesktopState to route back action
            context = { type = "file_explorer_item", item = item, current_path = self.current_path, window_id = self.window_id }
        }

    elseif view_event.name == "empty_recycle_bin" then self:emptyRecycleBin()
    elseif view_event.name == "refresh" then self:refresh()
    end

    -- If a specific action needs to be returned to DesktopState, return that.
    -- Otherwise, return the standard content interaction signal if any view event was handled.
    return result_action or { type = "content_interaction" }
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
             elseif action.special_type == "recycle_bin" then self:navigateTo("/Recycle Bin"); return { type = "content_interaction" } end
        end
    elseif action and action.type == "error" then
        print("Error opening item: " .. action.message)
        love.window.showMessageBox("Error", "Cannot open item: " .. action.message, "error")
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
        love.window.showMessageBox("Not Implemented", "Creating shortcuts for folders is not yet implemented.", "info")
    elseif item.type == "file" then
        -- TODO: Implement file shortcut logic (needs new icon type/data)
        love.window.showMessageBox("Not Implemented", "Creating shortcuts for files is not yet implemented.", "info")
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
    local success = self.recycle_bin:restoreItem(program_id)

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
        "Confirm Empty Recycle Bin",
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
        "Confirm Delete",
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
    local success = self.recycle_bin:restoreItem(program_id)
    if success then
        print("Restored " .. program_id .. " from Recycle Bin")
        self.desktop_icons:save() -- Persist the restoration
        self:refresh() -- Refresh the current view
    else
        print("Failed to restore " .. program_id)
        love.window.showMessageBox("Error", "Failed to restore " .. program_id, "error")
    end
end

-- Permanently delete a single item (called by DesktopState via handleContextMenuAction)
function FileExplorerState:permanentlyDeleteFromRecycleBin(program_id)
     local program = self.program_registry:getProgram(program_id)
     local name = program and program.name or program_id

     local buttons = {"Yes, Delete", "Cancel"}
     local pressed = love.window.showMessageBox(
        "Confirm Delete",
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
             love.window.showMessageBox("Error", "Failed to delete " .. program_id, "error")
         end
     end
end

return FileExplorerState