local Object = require('class')
local json = require('json')
local Paths = require('src.paths')
local ProgramRegistry = Object:extend('ProgramRegistry')

function ProgramRegistry:init()
    self.programs = {}
    self.dynamic_programs = {}
    self.SHORTCUTS_FILE = 'shortcuts.json'
    self.start_menu_overrides = {}
    self.START_MENU_OVERRIDES_FILE = 'start_menu_overrides.json'
    self.START_MENU_ORDER_FILE = 'start_menu_order.json'
    self.START_MENU_MOVES_FILE = 'start_menu_moves.json'
    -- New structured order data: { programs = {id->idx}, folders = { [path] = { [entryKey]->idx } } }
    self.start_menu_order_data = { programs = {}, folders = {} }
    -- Back-compat shortcut: plain table mapping id->idx (root Programs order)
    self.start_menu_order = self.start_menu_order_data.programs
    self:loadPrograms()
end

-- Certain root locations should never be relocation targets in the Start Menu
function ProgramRegistry:isRestrictedStartMenuPath(path)
    return path == '/My Computer/C:/Documents' or path == '/Control Panel'
end

-- Clean up any persisted Start Menu state that tries to move entries into restricted roots,
-- and purge ordering maps for those restricted paths.
function ProgramRegistry:sanitizeStartMenuState()
    local changed = false
    self.start_menu_moves = self.start_menu_moves or {}
    for key, dst in pairs(self.start_menu_moves) do
        if self:isRestrictedStartMenuPath(dst) then
            self.start_menu_moves[key] = nil
            changed = true
        end
    end
    if changed then self:saveStartMenuMoves() end

    self.start_menu_order_data = self.start_menu_order_data or { programs = {}, folders = {} }
    local folders = self.start_menu_order_data.folders or {}
    local order_changed = false
    for path, _ in pairs(folders) do
        if self:isRestrictedStartMenuPath(path) then
            folders[path] = {}
            order_changed = true
        end
    end
    if order_changed then
        self.start_menu_order_data.folders = folders
        self:saveStartMenuOrder()
    end
end

function ProgramRegistry:loadPrograms()
    local file_path = Paths.data.programs
    local read_ok, contents = pcall(love.filesystem.read, file_path)
    
    if not read_ok or not contents then
        print("ERROR: Could not read " .. file_path)
        return
    end
    
    local decode_ok, data = pcall(json.decode, contents)
    
    if not decode_ok then
        print("ERROR: Failed to decode " .. file_path)
        return
    end
    
    self.programs = data
    -- Load dynamic shortcut programs and append
    self:loadDynamicPrograms()
    -- Load start menu overrides
    self:loadStartMenuOverrides()
    -- Load custom start menu order
    self:loadStartMenuOrder()
    -- Load cross-folder relocations
    self:loadStartMenuMoves()
    -- Sanitize any invalid persisted state (e.g., moves into restricted roots)
    self:sanitizeStartMenuState()
    print("Loaded " .. #self.programs .. " programs")
end

function ProgramRegistry:getAllPrograms()
    return self.programs
end

function ProgramRegistry:getDesktopPrograms()
    local desktop = {}
    for _, program in ipairs(self.programs) do
        if program.on_desktop then
            table.insert(desktop, program)
        end
    end
    return desktop
end

function ProgramRegistry:getStartMenuPrograms()
    local pool = {}
    for _, program in ipairs(self.programs) do
        local overridden = self:hasStartMenuOverride(program.id)
        if program.in_start_menu or overridden then table.insert(pool, program) end
    end
    -- Apply saved ordering for Programs list (top-level Programs only)
    local order = (self.start_menu_order_data and self.start_menu_order_data.programs) or {}
    if order and next(order) ~= nil then
        table.sort(pool, function(a, b)
            local ia = order[a.id] or math.huge
            local ib = order[b.id] or math.huge
            if ia == ib then return (a.name or a.id) < (b.name or b.id) end
            return ia < ib
        end)
    end
    return pool
end

function ProgramRegistry:findByExecutable(executable_name)
    executable_name = executable_name:lower()
    
    -- Must be exact match with full extension (no partial matching)
    for _, program in ipairs(self.programs) do
        if program.executable:lower() == executable_name then
            return program
        end
    end
    
    return nil
end

function ProgramRegistry:getProgram(program_id)
    for _, program in ipairs(self.programs) do
        if program.id == program_id then
            return program
        end
    end
    return nil
end

-- Load dynamic folder shortcuts from save file and merge into registry
function ProgramRegistry:loadDynamicPrograms()
    local read_ok, contents = pcall(love.filesystem.read, self.SHORTCUTS_FILE)
    if not read_ok or not contents or contents == '' then
        self.dynamic_programs = {}
        return
    end

    local decode_ok, data = pcall(json.decode, contents)
    if not decode_ok or type(data) ~= 'table' then
        print("ERROR: Failed to decode shortcuts file, ignoring")
        self.dynamic_programs = {}
        return
    end

    self.dynamic_programs = data
    -- Merge into programs list (static first, then dynamic)
    for _, p in ipairs(self.dynamic_programs) do
        table.insert(self.programs, p)
    end
end

-- Persist dynamic programs to save file
function ProgramRegistry:saveDynamicPrograms()
    local encode_ok, json_str = pcall(json.encode, self.dynamic_programs or {})
    if not encode_ok then
        print("ERROR: Failed to encode shortcuts: " .. tostring(json_str))
        return false
    end
    local write_ok, err = pcall(love.filesystem.write, self.SHORTCUTS_FILE, json_str)
    if not write_ok then
        print("ERROR: Failed to write shortcuts: " .. tostring(err))
        return false
    end
    return true
end

-- Start menu order (Programs pane) persistence
function ProgramRegistry:loadStartMenuOrder()
    local ok, contents = pcall(love.filesystem.read, self.START_MENU_ORDER_FILE)
    if not ok or not contents or contents == '' then self.start_menu_order_data = { programs = {}, folders = {} }; self.start_menu_order = self.start_menu_order_data.programs; return false end
    local dec_ok, data = pcall(json.decode, contents)
    if not dec_ok or type(data) ~= 'table' then self.start_menu_order_data = { programs = {}, folders = {} }; self.start_menu_order = self.start_menu_order_data.programs; return false end
    -- Back-compat: if it's a flat map, treat it as programs-only order
    if data.programs or data.folders then
        self.start_menu_order_data = { programs = data.programs or {}, folders = data.folders or {} }
    else
        self.start_menu_order_data = { programs = data or {}, folders = {} }
    end
    self.start_menu_order = self.start_menu_order_data.programs
    return true
end

function ProgramRegistry:saveStartMenuOrder()
    local enc_ok, out = pcall(json.encode, self.start_menu_order_data or { programs = {}, folders = {} })
    if not enc_ok then return false end
    local ok, err = pcall(love.filesystem.write, self.START_MENU_ORDER_FILE, out)
    if not ok then print('ERROR writing start_menu_order: '..tostring(err)); return false end
    return true
end

-- Relocation map: entry_key(path) -> destination folder path
function ProgramRegistry:loadStartMenuMoves()
    local ok, contents = pcall(love.filesystem.read, self.START_MENU_MOVES_FILE)
    if not ok or not contents or contents == '' then self.start_menu_moves = {}; return false end
    local dec_ok, data = pcall(json.decode, contents)
    if not dec_ok or type(data) ~= 'table' then self.start_menu_moves = {}; return false end
    self.start_menu_moves = data
    return true
end

function ProgramRegistry:saveStartMenuMoves()
    local enc_ok, out = pcall(json.encode, self.start_menu_moves or {})
    if not enc_ok then return false end
    local ok, err = pcall(love.filesystem.write, self.START_MENU_MOVES_FILE, out)
    if not ok then print('ERROR writing start_menu_moves: '..tostring(err)); return false end
    return true
end

function ProgramRegistry:getStartMenuMoves()
    return self.start_menu_moves or {}
end

-- Relocate a program (by id) into a folder path or back to Programs root
function ProgramRegistry:relocateProgram(program_id, dst_path)
    if not program_id then return false end
    self.start_menu_moves = self.start_menu_moves or {}
    local key = 'program:' .. tostring(program_id)
    if dst_path == nil or dst_path == 'PROGRAMS_ROOT' then
        self.start_menu_moves[key] = 'PROGRAMS_ROOT'
    else
        self.start_menu_moves[key] = dst_path
    end
    return self:saveStartMenuMoves()
end

-- Move program within root Programs list ordering
function ProgramRegistry:moveInStartMenuProgramsOrder(program_id, new_index)
    if not program_id or not new_index then return false end
    -- Build current ordered list of ids
    local current = {}
    local pool = self:getStartMenuPrograms() or {}
    for _, p in ipairs(pool) do table.insert(current, p.id) end
    -- Find the current position of id
    local from_idx = nil
    for i, id in ipairs(current) do if id == program_id then from_idx = i; break end end
    if not from_idx then return false end
    -- Clamp new index
    if new_index < 1 then new_index = 1 end
    if new_index > #current then new_index = #current end
    -- Reorder array
    table.remove(current, from_idx)
    table.insert(current, new_index, program_id)
    -- Rebuild index map
    local order = {}
    for i, id in ipairs(current) do order[id] = i end
    if not self.start_menu_order_data then self.start_menu_order_data = { programs = {}, folders = {} } end
    self.start_menu_order_data.programs = order
    self.start_menu_order = self.start_menu_order_data.programs
    return self:saveStartMenuOrder()
end

-- Back-compat alias
function ProgramRegistry:moveInStartMenuOrder(program_id, new_index)
    return self:moveInStartMenuProgramsOrder(program_id, new_index)
end

-- Apply saved order to a folder path entries table; entries is array of { name, path, type, program_id? }
function ProgramRegistry:orderFsEntries(path, entries)
    if not path or type(entries) ~= 'table' then return entries end
    local folders = (self.start_menu_order_data and self.start_menu_order_data.folders) or {}
    local order = folders[path]
    if not order or next(order) == nil then return entries end
    table.sort(entries, function(a, b)
        local ka = a.path or a.name or ''
        local kb = b.path or b.name or ''
        local ia = order[ka] or math.huge
        local ib = order[kb] or math.huge
        if ia == ib then return (a.name or ka) < (b.name or kb) end
        return ia < ib
    end)
    return entries
end

-- Reorder an entry within a folder path. current_keys is optional array of keys (paths) to define scope/order.
function ProgramRegistry:moveInStartMenuFolderOrder(path, entry_key, new_index, current_keys)
    if not path or not entry_key or not new_index then return false end
    if not self.start_menu_order_data then self.start_menu_order_data = { programs = {}, folders = {} } end
    local folders = self.start_menu_order_data.folders
    folders[path] = folders[path] or {}
    -- Build current keys list
    local current = {}
    if type(current_keys) == 'table' and #current_keys > 0 then
        for _, k in ipairs(current_keys) do table.insert(current, k) end
    else
        -- Fallback: use existing order keys only
        for k, _ in pairs(folders[path]) do table.insert(current, k) end
        -- Ensure the moving key is present
        local exists = false; for _, k in ipairs(current) do if k == entry_key then exists = true; break end end
        if not exists then table.insert(current, entry_key) end
    end
    -- Ensure uniqueness
    local seen = {}
    local compact = {}
    for _, k in ipairs(current) do if not seen[k] then table.insert(compact, k); seen[k]=true end end
    current = compact
    -- Find current index
    local from_idx = nil
    for i, k in ipairs(current) do if k == entry_key then from_idx = i; break end end
    if not from_idx then return false end
    -- Clamp
    if new_index < 1 then new_index = 1 end
    if new_index > #current then new_index = #current end
    -- Move
    table.remove(current, from_idx)
    table.insert(current, new_index, entry_key)
    -- Rebuild order map
    local map = {}
    for i, k in ipairs(current) do map[k] = i end
    folders[path] = map
    self.start_menu_order_data.folders = folders
    return self:saveStartMenuOrder()
end

-- Relocate an entry from one folder path to another (Start Menu view only), and place at target index
-- current_keys_dst/src are arrays of keys representing current visible order for those panes
function ProgramRegistry:relocateStartMenuEntry(entry_key, src_path, dst_path, new_index, current_keys_dst, current_keys_src)
    if not entry_key or not src_path or not dst_path or not new_index then return false end
    if not self.start_menu_order_data then self.start_menu_order_data = { programs = {}, folders = {} } end
    self.start_menu_moves = self.start_menu_moves or {}
    -- Apply mapping
    self.start_menu_moves[entry_key] = dst_path
    -- Update destination order map
    local folders = self.start_menu_order_data.folders
    folders[dst_path] = folders[dst_path] or {}
    local dst_list = {}
    if type(current_keys_dst) == 'table' and #current_keys_dst > 0 then
        for _, k in ipairs(current_keys_dst) do table.insert(dst_list, k) end
    else
        for k, _ in pairs(folders[dst_path]) do table.insert(dst_list, k) end
    end
    local present = false; for _, k in ipairs(dst_list) do if k == entry_key then present = true; break end end
    if not present then table.insert(dst_list, entry_key) end
    -- ensure uniqueness
    local seen = {}; local compact = {}
    for _, k in ipairs(dst_list) do if not seen[k] then table.insert(compact, k); seen[k] = true end end
    dst_list = compact
    if new_index < 1 then new_index = 1 end
    if new_index > #dst_list then new_index = #dst_list end
    -- Move to new_index
    local from_idx=nil; for i,k in ipairs(dst_list) do if k==entry_key then from_idx=i; break end end
    if from_idx then table.remove(dst_list, from_idx); table.insert(dst_list, new_index, entry_key) end
    local dst_map = {}; for i,k in ipairs(dst_list) do dst_map[k] = i end
    folders[dst_path] = dst_map
    -- Update source order map (remove key)
    if src_path and src_path ~= dst_path then
        folders[src_path] = folders[src_path] or {}
        local src_list = {}
        if type(current_keys_src) == 'table' and #current_keys_src > 0 then
            for _, k in ipairs(current_keys_src) do if k ~= entry_key then table.insert(src_list, k) end end
        else
            for k, _ in pairs(folders[src_path]) do if k ~= entry_key then table.insert(src_list, k) end end
        end
        local src_map = {}; for i,k in ipairs(src_list) do src_map[k] = i end
        folders[src_path] = src_map
    end
    self.start_menu_order_data.folders = folders
    local ok1 = self:saveStartMenuOrder()
    local ok2 = self:saveStartMenuMoves()
    return ok1 and ok2
end

-- Helper to find existing folder shortcut by target path
function ProgramRegistry:findFolderShortcutByPath(path)
    for _, p in ipairs(self.dynamic_programs or {}) do
        if p.shortcut_target == path then
            return p
        end
    end
    return nil
end

-- General find shortcut (file or folder) by target path
function ProgramRegistry:findShortcutByPath(path)
    return self:findFolderShortcutByPath(path)
end

-- Create or update a folder shortcut program entry
-- opts = { on_desktop = bool, in_start_menu = bool }
function ProgramRegistry:addFolderShortcut(name, path, opts)
    opts = opts or {}
    -- If one exists for this path, update flags and return
    local existing = self:findShortcutByPath(path)
    if existing then
        existing.on_desktop = existing.on_desktop or (opts.on_desktop == true)
        existing.in_start_menu = existing.in_start_menu or (opts.in_start_menu == true)
        -- Also update display name if provided
        if name and name ~= '' then existing.name = name end
        self:saveDynamicPrograms()
        return existing
    end

    -- Generate a unique id
    local function sanitize(s)
        s = tostring(s or '')
        s = s:gsub('[^%w]+', '_')
        return s:lower()
    end
    local base_id = 'shortcut_' .. sanitize(name ~= '' and name or path)
    local id = base_id
    local idx = 1
    while self:getProgram(id) do
        idx = idx + 1
        id = base_id .. '_' .. tostring(idx)
    end

    -- Default window settings similar to other file explorer entries
    local window_defaults = { w = 600, h = 400, resizable = true, single_instance = false }

    local program = {
        id = id,
        name = name or path,
        executable = 'folder_shortcut.lnk',
        state_class_path = 'states.file_explorer_state',
        dependencies = { 'file_system', 'program_registry', 'desktop_icons', 'recycle_bin', 'di' },
        icon_sprite = opts.icon_sprite or 'directory_open_file_mydocs_small-0',
        icon_color = { 0.9, 0.9, 0.9 },
        on_desktop = opts.on_desktop == true,
        in_start_menu = opts.in_start_menu == true,
        disabled = false,
        window_defaults = window_defaults,
        enter_args = { type = 'static', value = (opts.shortcut_type == 'file' and (path:match('(.+)/[^/]+$') or path)) or path },
        shortcut_target = path,
        shortcut_type = opts.shortcut_type or 'folder'
    }

    table.insert(self.dynamic_programs, program)
    table.insert(self.programs, program)
    self:saveDynamicPrograms()
    return program
end

-- Remove a dynamic shortcut program by id
function ProgramRegistry:removeDynamicProgram(program_id)
    local idx_remove = nil
    for i, p in ipairs(self.dynamic_programs or {}) do
        if p.id == program_id then idx_remove = i; break end
    end
    if idx_remove then table.remove(self.dynamic_programs, idx_remove) end
    -- Also remove from combined list
    local idx2 = nil
    for i, p in ipairs(self.programs or {}) do
        if p.id == program_id then idx2 = i; break end
    end
    if idx2 then table.remove(self.programs, idx2) end
    self:saveDynamicPrograms()
    return idx_remove ~= nil
end

-- Start menu overrides load/save
function ProgramRegistry:loadStartMenuOverrides()
    local ok, contents = pcall(love.filesystem.read, self.START_MENU_OVERRIDES_FILE)
    if not ok or not contents or contents == '' then
        self.start_menu_overrides = {}
        return false
    end
    local dec_ok, data = pcall(json.decode, contents)
    if not dec_ok or type(data) ~= 'table' then
        self.start_menu_overrides = {}
        return false
    end
    self.start_menu_overrides = data
    return true
end

function ProgramRegistry:saveStartMenuOverrides()
    local enc_ok, out = pcall(json.encode, self.start_menu_overrides or {})
    if not enc_ok then return false end
    local ok, err = pcall(love.filesystem.write, self.START_MENU_OVERRIDES_FILE, out)
    if not ok then print('ERROR writing start_menu_overrides: '..tostring(err)); return false end
    return true
end

function ProgramRegistry:setStartMenuOverride(program_id, enabled)
    if not program_id then return false end
    if enabled then self.start_menu_overrides[program_id] = true else self.start_menu_overrides[program_id] = nil end
    return self:saveStartMenuOverrides()
end

function ProgramRegistry:hasStartMenuOverride(program_id)
    return self.start_menu_overrides and self.start_menu_overrides[program_id] == true
end

return ProgramRegistry