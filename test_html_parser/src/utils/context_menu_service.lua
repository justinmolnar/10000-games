-- src/utils/context_menu_service.lua
-- Service that manages all context menu functionality

local Object = require('class')
local ContextMenuView = require('src.views.context_menu_view')
local Strings = require('src.utils.strings')

local ContextMenuService = Object:extend('ContextMenuService')

function ContextMenuService:init(di)
    self.di = di or {}

    -- Dependencies from DI
    self.program_registry = di.programRegistry
    self.desktop_icons = di.desktopIcons
    self.file_system = di.fileSystem
    self.recycle_bin = di.recycleBin
    self.window_manager = di.windowManager
    self.event_bus = di.eventBus

    -- Own view instance
    self.view = ContextMenuView:new()

    -- State properties
    self.is_open = false
    self.options = {}
    self.context = nil
    self.x = 0
    self.y = 0
    self._suppress_next_mousereleased = false

    -- Subscribe to show_context_menu event from handleStateEvent
    if self.event_bus then
        self.event_bus:subscribe('show_context_menu', function(x, y, options, context)
            self:show(x, y, options, context)
        end)
    end
end

function ContextMenuService:isOpen()
    return self.is_open
end

function ContextMenuService:update(dt)
    if not self.is_open then return end
    self.view:update(dt, self.options, self.x, self.y)
end

function ContextMenuService:draw()
    if not self.is_open then return end
    self.view:draw()
end

function ContextMenuService:mousepressed(x, y, button)
    if not self.is_open then return false end

    if button == 1 then
        local clicked_option_index = self.view:getClickedOptionIndex(x, y)
        if clicked_option_index then -- Clicked inside bounds
            if clicked_option_index > 0 then -- Clicked on an enabled item
                local selected_option = self.options[clicked_option_index]
                self:handleContextMenuAction(selected_option.id, self.context)
            end
            self:close()
            self._suppress_next_mousereleased = true -- Prevent click-through
            return true -- Consumed click
        else -- Clicked outside
            self:close()
            return false -- Did not consume click
        end
    elseif button == 2 then -- Right-click outside closes, doesn't consume
        self:close()
        return false
    end
    return false
end

function ContextMenuService:shouldSuppressMouseRelease()
    if self._suppress_next_mousereleased then
        self._suppress_next_mousereleased = false
        return true
    end
    return false
end

-- Generate context menu options based on context type
function ContextMenuService:generateContextMenuOptions(context_type, context_data)
    local options = {}
    context_data = context_data or {}

    if context_type == "icon" then
        local program_id = context_data.program_id
        local program = self.program_registry:getProgram(program_id)
        if program then
            table.insert(options, { id = "open", label = Strings.get('menu.open', 'Open'), enabled = not program.disabled })
            table.insert(options, { id = "separator" })
            if program_id ~= "recycle_bin" and program_id ~= "my_computer" then
                table.insert(options, { id = "delete", label = Strings.get('menu.delete', 'Delete'), enabled = true })
            end
            table.insert(options, { id = "separator" })
            table.insert(options, { id = "properties", label = Strings.get('menu.properties', 'Properties') .. " (NYI)", enabled = false })
        end

    elseif context_type == "taskbar" then
        local window_id = context_data.window_id
        local window = self.window_manager:getWindowById(window_id)
        if window then
            table.insert(options, { id = "restore", label = Strings.get('menu.restore', 'Restore'), enabled = window.is_minimized })
            table.insert(options, { id = "minimize", label = Strings.get('menu.minimize', 'Minimize'), enabled = not window.is_minimized })
            local can_maximize = true
            if window.is_maximized then
                table.insert(options, { id = "restore_size", label = Strings.get('menu.restore_size', 'Restore Size'), enabled = can_maximize })
            else
                table.insert(options, { id = "maximize", label = Strings.get('menu.maximize', 'Maximize'), enabled = can_maximize and not window.is_minimized })
            end
            table.insert(options, { id = "separator" })
            table.insert(options, { id = "close_window", label = Strings.get('menu.close', 'Close'), enabled = true })
        end

    elseif context_type == "desktop" then
        table.insert(options, { id = "desktop_properties", label = Strings.get('menu.desktop_properties', 'Desktop Properties...'), enabled = true })
        table.insert(options, { id = "separator" })
        table.insert(options, { id = "arrange_icons", label = Strings.get('menu.arrange_icons', 'Arrange Icons') .. " (NYI)", enabled = false })
        table.insert(options, { id = "separator" })
        table.insert(options, { id = "refresh", label = Strings.get('menu.refresh', 'Refresh'), enabled = true })
        table.insert(options, { id = "separator" })
        table.insert(options, { id = "properties", label = Strings.get('menu.properties', 'Properties') .. " (NYI)", enabled = false })

    elseif context_type == "start_menu_item" then
        local program_id = context_data.program_id
        local program = self.program_registry:getProgram(program_id)
        if program then
            table.insert(options, { id = "open", label = Strings.get('menu.open', 'Open'), enabled = not program.disabled })
            table.insert(options, { id = "separator" })
            local is_visible = self.desktop_icons:isIconVisible(program_id)
            table.insert(options, {
                id = "create_shortcut_desktop",
                label = Strings.get('menu.create_shortcut_desktop', 'Create Shortcut (Desktop)'),
                enabled = not is_visible and not program.disabled
            })
            table.insert(options, { id = "separator" })
            table.insert(options, { id = "delete_from_menu", label = Strings.get('menu.delete', 'Delete from Start Menu'), enabled = true })
            table.insert(options, { id = "separator" })
            table.insert(options, { id = "properties", label = Strings.get('menu.properties', 'Properties') .. " (NYI)", enabled = false })
        end

    elseif context_type == "file_explorer_item" or context_type == "file_explorer_empty" then
        options = context_data.options or {}
        local final_options = {}
        for _, opt in ipairs(options or {}) do
            if opt.id == "separator" then
                table.insert(final_options, { id = "_sep_" .. #final_options, label = "---", enabled = false, is_separator = true })
            else
                table.insert(final_options, opt)
            end
        end
        return final_options

    elseif context_type == "start_menu_fs" then
        -- Return options from context_data as-is (generated by StartMenuState)
        options = context_data.options or {}
        local final_options = {}
        for _, opt in ipairs(options or {}) do
            if opt.id == "separator" then
                table.insert(final_options, { id = "_sep_" .. #final_options, label = "---", enabled = false, is_separator = true })
            else
                table.insert(final_options, opt)
            end
        end
        return final_options
    end

    -- Process separators for non-file-explorer contexts
    if context_type ~= "file_explorer_item" and context_type ~= "file_explorer_empty" and context_type ~= "start_menu_fs" then
        local final_options = {}
        for _, opt in ipairs(options or {}) do
            if opt.id == "separator" then
                table.insert(final_options, { id = "_sep_" .. #final_options, label = "---", enabled = false, is_separator = true })
            else
                table.insert(final_options, opt)
            end
        end
        return final_options
    else
        return options
    end
end

-- Show the context menu at given position
function ContextMenuService:show(x, y, options_or_type, context)
    -- Support two calling conventions:
    -- 1. show(x, y, options_table, context) - direct options
    -- 2. show(x, y, context_type_string, context) - generate options
    local options
    if type(options_or_type) == "table" then
        -- Direct options - need to process separators
        local final_options = {}
        for _, opt in ipairs(options_or_type) do
            if opt.id == "separator" then
                table.insert(final_options, { id = "_sep_" .. #final_options, label = "---", enabled = false, is_separator = true })
            else
                table.insert(final_options, opt)
            end
        end
        options = final_options
    elseif type(options_or_type) == "string" then
        -- Context type - generate options (already processes separators)
        options = self:generateContextMenuOptions(options_or_type, context)
    else
        print("ERROR: Invalid options_or_type in ContextMenuService:show")
        return
    end

    if not options or #options == 0 then
        return -- Don't show empty menu
    end

    self.options = options
    self.context = context or {}
    self.x = x
    self.y = y

    -- Adjust position if menu goes off screen
    local screen_w, screen_h = love.graphics.getDimensions()
    local menu_w = self.view.menu_w
    local menu_h = #self.options * self.view.item_height + self.view.padding * 2
    if self.x + menu_w > screen_w then self.x = screen_w - menu_w end
    if self.y + menu_h > screen_h then self.y = screen_h - menu_h end
    self.x = math.max(0, self.x)
    self.y = math.max(0, self.y)

    self.is_open = true
    print("Opened context menu at", self.x, self.y, "with context type:", self.context.type, "#Options:", #self.options)

    -- Publish context_menu_opened event
    if self.event_bus then
        local context_type = self.context.type or "unknown"
        pcall(self.event_bus.publish, self.event_bus, 'context_menu_opened', self.x, self.y, context_type, self.context)
    end
end

-- Close the context menu
function ContextMenuService:close()
    if not self.is_open then return end

    self.is_open = false
    local old_context = self.context
    self.options = {}
    self.context = nil

    -- Publish context_menu_closed event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'context_menu_closed', old_context)
    end
end

-- Handle context menu action - publishes events instead of performing actions directly
function ContextMenuService:handleContextMenuAction(action_id, context)
    print("[ContextMenuService] Action:", action_id, "Context Type:", context.type)
    local program_id = context.program_id
    local window_id = context.window_id

    -- Publish context_action_invoked event BEFORE handling the action
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'context_action_invoked', action_id, context)
    end

    if context.type == "icon" then
        if not program_id then print("ERROR: program_id missing for icon context!"); return end
        if action_id == "open" then
            if self.event_bus then self.event_bus:publish('launch_program', program_id) end
        elseif action_id == "delete" then
            if self.event_bus then self.event_bus:publish('request_icon_recycle', program_id) end
        elseif action_id == "properties" then
            print("Action 'Properties' NYI")
        end

    elseif context.type == "taskbar" then
        if not window_id then print("ERROR: window_id missing for taskbar context!"); return end
        if action_id == "restore" then
            if self.event_bus then
                self.event_bus:publish('request_window_restore', window_id)
                self.event_bus:publish('request_window_focus', window_id)
            end
        elseif action_id == "restore_size" then
            if self.event_bus then self.event_bus:publish('request_window_restore', window_id) end
        elseif action_id == "minimize" then
            if self.event_bus then self.event_bus:publish('request_window_minimize', window_id) end
        elseif action_id == "maximize" then
            if self.event_bus then
                local screen_w, screen_h = love.graphics.getDimensions()
                self.event_bus:publish('request_window_maximize', window_id, screen_w, screen_h)
            end
        elseif action_id == "close_window" then
            if self.event_bus then self.event_bus:publish('request_window_close', window_id) end
        end

    elseif context.type == "desktop" then
        if action_id == "desktop_properties" then
            if self.event_bus then self.event_bus:publish('launch_program', 'control_panel_desktop') end
        elseif action_id == "arrange_icons" then
            print("Action 'Arrange Icons' NYI")
        elseif action_id == "refresh" then
            print("Action 'Refresh' NYI")
        elseif action_id == "properties" then
            print("Action 'Properties' NYI")
        end

    elseif context.type == "start_menu_item" then
        if not program_id then print("ERROR: program_id missing for start_menu_item context!"); return end
        if action_id == "open" then
            if self.event_bus then self.event_bus:publish('launch_program', program_id) end
        elseif action_id == "create_shortcut_desktop" then
            if self.event_bus then self.event_bus:publish('ensure_icon_visible', program_id) end
        elseif action_id == 'create_shortcut_start_menu' then
            if self.event_bus then self.event_bus:publish('add_to_start_menu', program_id) end
        elseif action_id == 'new_folder' then
            if self.event_bus then self.event_bus:publish('start_menu_new_folder', context) end
        elseif action_id == 'delete_from_menu' then
            if self.event_bus then self.event_bus:publish('remove_from_start_menu', program_id) end
        elseif action_id == "properties" then
            print("Action 'Properties' NYI")
        end

    elseif context.type == "start_menu_fs" then
        local path = context.path
        if not path then return end
        if action_id == 'open' then
            if self.event_bus then self.event_bus:publish('start_menu_open_path', path) end
        elseif action_id == 'new_folder' then
            if self.event_bus then self.event_bus:publish('start_menu_new_folder', context) end
        elseif action_id == 'delete_from_menu' then
            if self.event_bus then self.event_bus:publish('start_menu_delete_fs', path) end
        end

    elseif context.type == "file_explorer_item" or context.type == "file_explorer_empty" then
        -- File Explorer actions - publish generic event with full context
        if self.event_bus then
            self.event_bus:publish('file_explorer_action', action_id, context)
        end
    end
end

return ContextMenuService
