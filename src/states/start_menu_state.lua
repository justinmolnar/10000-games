-- src/states/start_menu_state.lua
local Object = require('class')
local StartMenuView = require('src.views.start_menu_view')
local Strings = require('src.utils.strings')

local StartMenuState = Object:extend('StartMenuState')

function StartMenuState:init(di, host)
    self.di = di or {}
    self.program_registry = self.di.programRegistry
    self.file_system = self.di.fileSystem
    self.config = (self.di and self.di.config) or {}
    self.event_bus = (self.di and self.di.eventBus) or nil
    -- host should provide launchProgram(program_id) and showTextFileDialog(path, content)
    -- TODO: Remove host once all events migrated to EventBus
    self.host = host or {}

    self.view = StartMenuView:new(self.program_registry, self.file_system, self.di)
    self.open = false
    self._opened_by_mousepress = nil

    -- Menu state properties (moved from View)
    self.submenu_open_id = nil
    self.hovered_main_id = nil
    self.hovered_sub_id = nil
    self.keyboard_start_selected_id = nil
    self._start_menu_pressed_id = nil

    -- Cascading panes state
    self.open_panes = {}
    self.cascade_hover = { level = nil, index = nil, t = 0 }
    self._cascade_root_id = nil
    self._pane_close = {}
    self._start_menu_keepalive_t = 0

    -- Drag and drop state
    self.dnd_active = false
    self.dnd_source_index = nil
    self.dnd_hover_index = nil
    self.dnd_pane_index = nil
    self.dnd_item_id = nil
    self.dnd_entry_key = nil
    self.dnd_scope = nil
    self.dnd_drop_mode = nil
    self.dnd_target_folder_path = nil
    self.dnd_pending = nil
    self.dnd_start_x, self.dnd_start_y = nil, nil
    self.dnd_threshold = 4

    -- Subscribe to Start Menu events
    if self.event_bus then
        self.event_bus:subscribe('add_to_start_menu', function(program_id)
            self:addProgramToStartMenu(program_id)
        end)
        self.event_bus:subscribe('remove_from_start_menu', function(program_id)
            self:removeProgramFromStartMenu(program_id)
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
            self:openPath(path)
        end)
        self.event_bus:subscribe('start_menu_delete_fs', function(path)
            print('DEBUG: start_menu_delete_fs event received for path:', path)
            local fs = self.file_system
            if fs and fs.deleteEntry then
                local ok, err = fs:deleteEntry(path)
                if not ok then
                    print('Delete failed for Start Menu FS item:', path, err)
                else
                    print('Successfully deleted Start Menu FS item:', path)
                end
                -- Refresh all open panes after delete (open_panes is on STATE, not VIEW)
                if self.view and self.open_panes then
                    print('DEBUG: Refreshing', #(self.open_panes or {}), 'panes')
                    for i, p in ipairs(self.open_panes or {}) do
                        print('  Pane', i, 'kind:', p.kind, 'parent_path:', p.parent_path)
                        if p.kind == 'programs' then
                            p.items = self.view:buildPaneItems('programs', nil)
                            print('    -> Rebuilt programs pane, now has', #(p.items or {}), 'items')
                        elseif p.kind == 'fs' and p.parent_path then
                            p.items = self.view:buildPaneItems('fs', p.parent_path)
                            print('    -> Rebuilt fs pane for', p.parent_path, ', now has', #(p.items or {}), 'items')
                        end
                    end
                else
                    print('DEBUG: No view or open_panes found!', self.view ~= nil, self.open_panes ~= nil)
                end
            else
                print('DEBUG: No file system or deleteEntry method!')
            end
        end)
    end
end

function StartMenuState:addProgramToStartMenu(program_id)
    local pr = self.program_registry
    local program = pr and pr:getProgram(program_id)
    if program then
        program.in_start_menu = true
        if pr.setStartMenuOverride then pr:setStartMenuOverride(program_id, true) end
    end
end

function StartMenuState:removeProgramFromStartMenu(program_id)
    local pr = self.program_registry
    local program = pr and pr:getProgram(program_id)
    if program then
        program.in_start_menu = false
        if pr.setStartMenuOverride then pr:setStartMenuOverride(program_id, false) end
        if pr.removeFromStartMenuOrder then pcall(pr.removeFromStartMenuOrder, pr, program_id) end
    end
    if self.view then
        for _, p in ipairs(self.view.open_panes or {}) do
            if p.kind == 'programs' then p.items = self.view:buildPaneItems('programs', nil)
            elseif p.kind == 'fs' and p.parent_path then p.items = self.view:buildPaneItems('fs', p.parent_path) end
        end
    end
end

function StartMenuState:clearStartMenuPress()
    self._start_menu_pressed_id = nil
end

function StartMenuState:setStartMenuKeyboardSelection(id)
    self.keyboard_start_selected_id = id
end

function StartMenuState:setOpen(flag)
    local new_state = flag and true or false
    if self.open == new_state then return end -- No change

    self.open = new_state
    if not self.open then
        self:setStartMenuKeyboardSelection(nil)
        -- Publish start_menu_closed event
        if self.event_bus then
            pcall(self.event_bus.publish, self.event_bus, 'start_menu_closed')
        end
    else
        self:clearStartMenuPress()
        -- Publish start_menu_opened event
        if self.event_bus then
            pcall(self.event_bus.publish, self.event_bus, 'start_menu_opened')
        end
    end
end

function StartMenuState:toggle()
    self:setOpen(not self.open)
end

function StartMenuState:isOpen()
    return self.open
end

function StartMenuState:update(dt)
    if self.view then self.view:update(dt, self.open, self) end
end

function StartMenuState:draw()
    if not self.open then return end
    if self.view then self.view:draw(self) end
end

function StartMenuState:mousemoved(x, y, dx, dy)
    if not self.open then return end
    if self.view and self.view.mousemovedStartMenu then
        self.view:mousemovedStartMenu(x, y, dx, dy, self)
    end
end

-- Input routing
function StartMenuState:mousepressed(x, y, button)
    if button ~= 1 then return false end
    -- If Start menu is open, forward to view and possibly consume
    if self.open and self.view and self.view.mousepressedStartMenu then
        local ev = self.view:mousepressedStartMenu(x, y, button, self)
        if ev then
            if ev.name == 'start_menu_pressed' then return true
            elseif ev.name == 'close_start_menu' then self:setOpen(false); return true end
        end
        return true -- clicked inside menu padding
    end
    return false
end

function StartMenuState:onStartButtonPressed()
    local was_open = self.open
    self:toggle()
    if (not was_open) and self.open then
        self._opened_by_mousepress = true
        self:clearStartMenuPress()
    end
end

function StartMenuState:mousereleased(x, y, button)
    if button ~= 1 then return false end
    if not self.open then return false end
    -- If menu was opened by this mouse press on the Start button, only process release if inside menu bounds.
    if self._opened_by_mousepress then
        local inside = (self.view and ((self.view.isPointInStartMenuOrSubmenu and self.view:isPointInStartMenuOrSubmenu(x, y, self))
                        or (self.view.isPointInStartMenu and self.view:isPointInStartMenu(x, y))))
        if not inside then
            self._opened_by_mousepress = nil
            return true -- consume release, keep menu open
        end
    end
    local ev = self.view and self.view:mousereleasedStartMenu(x, y, button, self)
    if ev then
        if ev.name == 'launch_program' and ev.program_id then
            -- Publish launch event instead of calling directly
            if self.event_bus then
                self.event_bus:publish('launch_program', ev.program_id)
            elseif self.host and self.host.launchProgram then
                 print("WARNING [StartMenuState]: Using legacy host.launchProgram fallback.")
                self.host.launchProgram(ev.program_id) -- Legacy fallback
            else
                 print("ERROR [StartMenuState]: No event_bus and no host! Cannot launch program.")
            end
            self:setOpen(false); self._opened_by_mousepress = nil; return true
        elseif ev.name == 'open_path' and ev.path then
            self:openPath(ev.path); self:setOpen(false); self._opened_by_mousepress = nil; return true
        elseif ev.name == 'open_run' then
            local params = {
                title = Strings.get('start.run', 'Run'),
                prompt = Strings.get('start.type_prompt','Type the name of a program:'),
                ok_label = Strings.get('buttons.ok','OK'),
                cancel_label = Strings.get('buttons.cancel','Cancel'),
                submit_event = 'run_execute',
            }
            -- Publish launch event instead of calling directly
            if self.event_bus then
                self.event_bus:publish('launch_program', 'run_dialog', params)
            elseif self.host and self.host.launchProgram then
                 print("WARNING [StartMenuState]: Using legacy host.launchProgram fallback for Run dialog.")
                self.host.launchProgram('run_dialog', params) -- Legacy fallback
            end
            self:setOpen(false); self._opened_by_mousepress = nil; return true
        elseif ev.name == 'open_shutdown' then
            -- Publish launch event instead of calling directly
            if self.event_bus then
                self.event_bus:publish('launch_program', 'shutdown_dialog')
            elseif self.host and self.host.launchProgram then
                 print("WARNING [StartMenuState]: Using legacy host.launchProgram fallback for Shutdown dialog.")
                self.host.launchProgram('shutdown_dialog') -- Legacy fallback
            end
            self:setOpen(false); self._opened_by_mousepress = nil; return true
        elseif ev.name == 'close_start_menu' then
            self:setOpen(false); self._opened_by_mousepress = nil; return true
        elseif ev.name == 'start_menu_pressed' then
            -- Event was handled within the start menu (e.g., drag operations, clicking on folders)
            self._opened_by_mousepress = nil
            return true
        else
            -- Unknown event name - consume to prevent fallthrough
            print("WARNING [StartMenuState]: Unknown event name from view: " .. tostring(ev.name))
            self._opened_by_mousepress = nil
            return true
        end
    else
        -- No event returned from view - consume to prevent fallthrough
        self._opened_by_mousepress = nil
        return true
    end
end

function StartMenuState:keypressed(key)
    -- Ctrl+Esc handled by caller (toggle), but we handle navigation/esc here
    if not self.open then return false end
    -- Minimal keyboard nav: Run and Shutdown, like before
    self.kb_items = self.kb_items or { 'run', 'shutdown' }
    if key == 'down' then
        self.kb_index = ((self.kb_index or 1) % #self.kb_items) + 1
        self:_applyKbSelection(); return true
    elseif key == 'up' then
        self.kb_index = ((self.kb_index or 1) - 2) % #self.kb_items + 1
        self:_applyKbSelection(); return true
    elseif key == 'escape' then
        self:setOpen(false); return true
    elseif key == 'return' or key == 'kpenter' then
        local sel = self.kb_items[self.kb_index or 1]
        self:setOpen(false)
        if sel == 'run' then
            local params = {
                title = Strings.get('start.run', 'Run'),
                prompt = Strings.get('start.type_prompt','Type the name of a program:'),
                ok_label = Strings.get('buttons.ok','OK'),
                cancel_label = Strings.get('buttons.cancel','Cancel'),
                submit_event = 'run_execute',
            }
            -- Publish launch event instead of calling directly
            if self.event_bus then
                self.event_bus:publish('launch_program', 'run_dialog', params)
            elseif self.host and self.host.launchProgram then
                 print("WARNING [StartMenuState]: Using legacy host.launchProgram fallback for Run dialog (keypressed).")
                self.host.launchProgram('run_dialog', params) -- Legacy fallback
            end
        elseif sel == 'shutdown' then
            -- Publish launch event instead of calling directly
            if self.event_bus then
                self.event_bus:publish('launch_program', 'shutdown_dialog')
            elseif self.host and self.host.launchProgram then
                 print("WARNING [StartMenuState]: Using legacy host.launchProgram fallback for Shutdown dialog (keypressed).")
                self.host.launchProgram('shutdown_dialog') -- Legacy fallback
            end
        end
        return true
    end
    return false
end

function StartMenuState:_applyKbSelection()
    local sel = self.kb_items[self.kb_index or 1]
    self:setStartMenuKeyboardSelection(sel)
end

-- Context menu helpers (proxies to view)
function StartMenuState:isPointInStartMenu(x, y)
    return self.open and self.view and self.view.isPointInStartMenu and self.view:isPointInStartMenu(x, y) or false
end

function StartMenuState:isPointInStartMenuOrSubmenu(x, y)
    return self.open and self.view and self.view.isPointInStartMenuOrSubmenu and self.view:isPointInStartMenuOrSubmenu(x, y, self) or false
end

function StartMenuState:getStartMenuProgramAtPosition(x, y)
    if not self.open then return nil end
    if self.view and self.view.getStartMenuProgramAtPosition then return self.view:getStartMenuProgramAtPosition(x, y) end
    return nil
end

function StartMenuState:handleRightClick(x, y, context_menu_service)
    if not self:isPointInStartMenuOrSubmenu(x, y) then return false end

    local hit = self.view and self.view.hitTestStartMenuContext and self.view:hitTestStartMenuContext(x, y, self)
    local options = {}
    local ctx = { type = 'start_menu' }

    if hit then
        if hit.area == 'pane' and hit.item then
            if hit.kind == 'programs' and hit.item.type == 'program' then
                ctx = { type='start_menu_item', program_id=hit.item.program_id, pane_kind='programs', parent_path=nil, index=hit.index, pane_index=hit.pane_index }
                if context_menu_service then
                    options = context_menu_service:generateContextMenuOptions('start_menu_item', ctx)
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
                ctx = { type='start_menu_item', program_id = hit.item.program_id, pane_kind='programs', parent_path=nil, index=hit.index, pane_index=hit.pane_index }
                if context_menu_service then
                    options = context_menu_service:generateContextMenuOptions('start_menu_item', ctx)
                end
                table.insert(options, 3, { id='new_folder', label=Strings.get('menu.new_folder','New Folder...'), enabled=true })
            end
        elseif hit.area == 'submenu' and hit.id and self.view.submenu_open_id == 'programs' then
            ctx = { type='start_menu_item', program_id=hit.id, pane_kind='programs', parent_path=nil, index=hit.index, pane_index=hit.pane_index }
            if context_menu_service then
                options = context_menu_service:generateContextMenuOptions('start_menu_item', ctx)
            end
            table.insert(options, 3, { id='new_folder', label=Strings.get('menu.new_folder','New Folder...'), enabled=true })
        end
    end

    if #options > 0 and context_menu_service then
        context_menu_service:show(x, y, options, ctx)
    end

    return true -- Consumed the right-click
end

-- Internal: open filesystem path via FileSystem + ProgramRegistry
function StartMenuState:openPath(path)
    local fs = self.file_system; if not fs then return end
    local item = fs:getItem(path)
    if not item then return end
    if item.type == 'folder' then
        local pr = self.program_registry
        if pr and pr.addFolderShortcut then
            local program = pr:addFolderShortcut(item.name or path, path, { in_start_menu = false })
            if program and program.id then
                -- Publish launch event instead of calling directly
                if self.event_bus then
                    self.event_bus:publish('launch_program', program.id)
                elseif self.host and self.host.launchProgram then
                    print("WARNING [StartMenuState]: Using legacy host.launchProgram fallback for folder shortcut.")
                    self.host.launchProgram(program.id) -- Legacy fallback
                end
            end
        end
    elseif item.type == 'executable' and item.program_id then
        -- Publish launch event instead of calling directly
        if self.event_bus then
            self.event_bus:publish('launch_program', item.program_id)
        elseif self.host and self.host.launchProgram then
            print("WARNING [StartMenuState]: Using legacy host.launchProgram fallback for executable.")
            self.host.launchProgram(item.program_id) -- Legacy fallback
        end
    elseif item.type == 'file' then
        if self.host and self.host.showTextFileDialog then self.host.showTextFileDialog(path, item.content) end
    elseif item.type == 'special' then
        if item.special_type == 'recycle_bin' then
            -- Publish launch event instead of calling directly
            if self.event_bus then
                self.event_bus:publish('launch_program', 'recycle_bin')
            elseif self.host and self.host.launchProgram then
                 print("WARNING [StartMenuState]: Using legacy host.launchProgram fallback for Recycle Bin.")
                self.host.launchProgram('recycle_bin') -- Legacy fallback
            end
        elseif item.special_type == 'desktop_view' then
            local pr = self.program_registry
            if pr and pr.addFolderShortcut then
                local program = pr:addFolderShortcut('Desktop', '/My Computer/Desktop', { in_start_menu = false })
                if program and program.id then
                    -- Publish launch event instead of calling directly
                    if self.event_bus then
                        self.event_bus:publish('launch_program', program.id)
                    elseif self.host and self.host.launchProgram then
                         print("WARNING [StartMenuState]: Using legacy host.launchProgram fallback for Desktop view.")
                        self.host.launchProgram(program.id) -- Legacy fallback
                    end
                end
            end
        end
    end
end

return StartMenuState
