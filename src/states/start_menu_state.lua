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
            if self.event_bus then
                self.event_bus:publish('launch_program', ev.program_id)
            elseif self.host and self.host.launchProgram then
                self.host.launchProgram(ev.program_id)
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
            if self.event_bus then
                self.event_bus:publish('launch_program', 'run_dialog', params)
            elseif self.host and self.host.launchProgram then
                self.host.launchProgram('run_dialog', params)
            end
            self:setOpen(false); self._opened_by_mousepress = nil; return true
        elseif ev.name == 'open_shutdown' then
            if self.event_bus then
                self.event_bus:publish('launch_program', 'shutdown_dialog')
            elseif self.host and self.host.launchProgram then
                self.host.launchProgram('shutdown_dialog')
            end
            self:setOpen(false); self._opened_by_mousepress = nil; return true
        elseif ev.name == 'close_start_menu' then
            self:setOpen(false); self._opened_by_mousepress = nil; return true
        end
    else
        self._opened_by_mousepress = nil
    end
    return false
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
            if self.event_bus then
                self.event_bus:publish('launch_program', 'run_dialog', params)
            elseif self.host and self.host.launchProgram then
                self.host.launchProgram('run_dialog', params)
            end
        elseif sel == 'shutdown' then
            if self.event_bus then
                self.event_bus:publish('launch_program', 'shutdown_dialog')
            elseif self.host and self.host.launchProgram then
                self.host.launchProgram('shutdown_dialog')
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
                if self.event_bus then
                    self.event_bus:publish('launch_program', program.id)
                elseif self.host and self.host.launchProgram then
                    self.host.launchProgram(program.id)
                end
            end
        end
    elseif item.type == 'executable' and item.program_id then
        if self.event_bus then
            self.event_bus:publish('launch_program', item.program_id)
        elseif self.host and self.host.launchProgram then
            self.host.launchProgram(item.program_id)
        end
    elseif item.type == 'file' then
        if self.host and self.host.showTextFileDialog then self.host.showTextFileDialog(path, item.content) end
    elseif item.type == 'special' then
        if item.special_type == 'recycle_bin' then
            if self.event_bus then
                self.event_bus:publish('launch_program', 'recycle_bin')
            elseif self.host and self.host.launchProgram then
                self.host.launchProgram('recycle_bin')
            end
        elseif item.special_type == 'desktop_view' then
            local pr = self.program_registry
            if pr and pr.addFolderShortcut then
                local program = pr:addFolderShortcut('Desktop', '/My Computer/Desktop', { in_start_menu = false })
                if program and program.id then
                    if self.event_bus then
                        self.event_bus:publish('launch_program', program.id)
                    elseif self.host and self.host.launchProgram then
                        self.host.launchProgram(program.id)
                    end
                end
            end
        end
    end
end

return StartMenuState
