-- src/models/file_system.lua
-- Model representing virtual file system structure for browsing

local Object = require('class')
local json = require('json')
local FileSystem = Object:extend('FileSystem')

function FileSystem:init()
    self.current_path = "/"
    self.filesystem = {}
    -- FS Recycle Bin persistence (for filesystem entries)
    self._fs_recycle = { items = {}, next_id = 1 }
    self._FS_RECYCLE_FILE = 'fs_recycle_bin.json'
    -- Runtime FS persistence (entire filesystem map)
    self._FS_RUNTIME_FILE = 'fs_runtime.json'
    
    self:loadFilesystem()
    -- Normalize key views after load so "My Computer" shows refined entries
    self:normalizeMyComputerView()
    -- Load FS recycle bin (persisted)
    self:_loadFsRecycleBin()
    -- Load runtime FS overrides (persisted structural edits)
    self:_loadFsRuntime()
    -- Normalize again in case runtime file lacked some aliases
    self:normalizeMyComputerView()
end

-- Load filesystem structure from JSON
function FileSystem:loadFilesystem()
    local Paths = require('src.paths')
    local file_path = Paths.assets.data .. "filesystem.json"
    local read_ok, contents = pcall(love.filesystem.read, file_path)
    
    if not read_ok or not contents then
        print("No filesystem.json found, creating default structure")
        self:createDefaultFilesystem()
        return
    end
    
    local decode_ok, data = pcall(json.decode, contents)
    if not decode_ok or type(data) ~= 'table' then
        print("Invalid filesystem.json format, using defaults")
        self:createDefaultFilesystem()
        return
    end
    
    self.filesystem = data
    print("Loaded virtual filesystem successfully")
end

-- Create default filesystem structure
function FileSystem:createDefaultFilesystem()
    self.filesystem = {
        ["/"] = {
            type = "folder",
            children = {"My Computer", "Control Panel", "Recycle Bin"}
        },
        ["/My Computer"] = {
            type = "folder",
            children = {"Desktop", "C:", "D:"}
        },
        ["/My Computer/Desktop"] = {
            type = "special",
            special_type = "desktop_view"
        },
        ["/My Computer/C:"] = {
            type = "folder",
            children = {"Windows", "Program Files", "Documents"}
        },
        ["/My Computer/C:/Windows"] = {
            type = "folder",
            children = {"System32", "readme.txt"}
        },
        ["/My Computer/C:/Windows/readme.txt"] = {
            type = "file",
            content = "Welcome to the 10,000 Games Collection!\n\nThis is a simulated Windows 98 environment.\nAll files and folders are virtual.\n\nHave fun exploring!"
        },
        ["/My Computer/C:/Program Files"] = {
            type = "folder",
            children = {"Game Collection", "VM Manager"}
        },
        ["/My Computer/C:/Program Files/Game Collection"] = {
            type = "folder",
            children = {"gamecollection.exe", "readme.txt"}
        },
        ["/My Computer/C:/Program Files/Game Collection/gamecollection.exe"] = {
            type = "executable",
            program_id = "launcher"
        },
        ["/My Computer/C:/Program Files/Game Collection/readme.txt"] = {
            type = "file",
            content = "Game Collection - Browse and play thousands of games!\n\nDouble-click to launch."
        },
        ["/My Computer/C:/Documents"] = {
            type = "folder",
            children = {"notes.txt"}
        },
        ["/My Computer/C:/Documents/notes.txt"] = {
            type = "file",
            content = "My Notes:\n\n- Remember to check VM Manager for automation\n- Try to optimize game performance for better bullets\n- CheatEngine can help with difficult games"
        },
        ["/My Computer/D:"] = {
            type = "folder",
            children = {}
        },
        ["/Recycle Bin"] = {
            type = "special",
            special_type = "recycle_bin"
        },
        -- Control Panel structure
        ["/Control Panel"] = {
            type = "folder",
            children = {"General", "Desktop", "Screensavers"}
        },
        ["/Control Panel/General"] = {
            type = "executable",
            program_id = "control_panel_general"
        },
        ["/Control Panel/Desktop"] = {
            type = "executable",
            program_id = "control_panel_desktop"
        },
        ["/Control Panel/Screensavers"] = {
            type = "executable",
            program_id = "control_panel_screensavers"
        }
    }
    -- Ensure refined My Computer listing in defaults too
    self:normalizeMyComputerView()
end

-- Ensure My Computer lists C:, D:, Desktop, Recycle Bin, My Documents, and that alias nodes exist
function FileSystem:normalizeMyComputerView()
    local fs = self.filesystem or {}
    local mc = fs["/My Computer"]
    if not mc then
        fs["/My Computer"] = { type = "folder", children = {"C:", "D:", "Desktop", "Recycle Bin", "My Documents"} }
        mc = fs["/My Computer"]
    end
    -- Force desired ordering/contents
    mc.children = {"C:", "D:", "Desktop", "Recycle Bin", "My Documents"}
    -- Ensure alias entries exist
    if not fs["/My Computer/Recycle Bin"] then
        fs["/My Computer/Recycle Bin"] = { type = "special", special_type = "recycle_bin" }
    end
    if not fs["/My Computer/My Documents"] then
        fs["/My Computer/My Documents"] = { type = "special", special_type = "my_documents" }
    end
    -- Ensure Desktop node exists
    if not fs["/My Computer/Desktop"] then
        fs["/My Computer/Desktop"] = { type = "special", special_type = "desktop_view" }
    end
    -- Leave C:, D: as-is (created in JSON/defaults)
end

-- Get contents of current directory
function FileSystem:getContents(path)
    path = path or self.current_path
    
    local item = self.filesystem[path]
    if not item then
        return nil, "Path not found"
    end
    
    if item.type == "special" then
        return {type = "special", special_type = item.special_type}
    end
    
    if item.type ~= "folder" then
        return nil, "Not a folder"
    end
    
    local contents = {}
    -- Resolve alias folders: if this folder points at another path, read that instead
    if item.alias_target and self.filesystem[item.alias_target] and self.filesystem[item.alias_target].type == 'folder' then
        local target_path = item.alias_target
        local target = self.filesystem[target_path]
        for _, child_name in ipairs(target.children or {}) do
            local child_path = target_path == "/" and ("/" .. child_name) or (target_path .. "/" .. child_name)
            local child_item = self.filesystem[child_path]
            if child_item then
                table.insert(contents, {
                    name = child_name,
                    path = child_path, -- expose real target child path so downstream panes operate on real nodes
                    type = child_item.type,
                    special_type = child_item.special_type,
                    program_id = child_item.program_id
                })
            end
        end
        return contents
    end
    for _, child_name in ipairs(item.children or {}) do
        local child_path = path == "/" and ("/" .. child_name) or (path .. "/" .. child_name)
        local child_item = self.filesystem[child_path]
        if child_item then
            table.insert(contents, { name=child_name, path=child_path, type=child_item.type, special_type=child_item.special_type, program_id=child_item.program_id })
        end
    end
    
    return contents
end

-- Create a new folder under a parent path; optionally insert at index (1-based).
-- Returns the new folder's path or nil on failure.
function FileSystem:createFolder(parent_path, name, insert_index)
    local parent = self.filesystem[parent_path]
    -- Resolve alias folder targets
    if parent and parent.type == 'folder' and parent.alias_target then
        parent_path = parent.alias_target
        parent = self.filesystem[parent_path]
    end
    if not parent or parent.type ~= 'folder' then return nil end
    -- Sanitize/ensure unique child name within parent
    local function childExists(n)
        for _, c in ipairs(parent.children or {}) do if c == n then return true end end
        return false
    end
    local base = tostring(name or 'New Folder')
    local final = base
    local i = 2
    while childExists(final) do final = base .. ' ('..i..')'; i = i + 1 end
    name = final
    -- Create node
    local child_path = parent_path == '/' and ('/'..name) or (parent_path .. '/' .. name)
    if self.filesystem[child_path] then return nil end
    self.filesystem[child_path] = { type = 'folder', children = {} }
    parent.children = parent.children or {}
    local idx = tonumber(insert_index) or (#parent.children + 1)
    if idx < 1 then idx = 1 end
    if idx > #parent.children + 1 then idx = #parent.children + 1 end
    table.insert(parent.children, idx, name)
    self:_saveFsRuntime()
    return child_path
end

-- Move an entry within the virtual filesystem
function FileSystem:moveEntry(src_path, dst_parent_path, new_name)
    local node = self.filesystem[src_path]
    local dst_parent = self.filesystem[dst_parent_path]
    -- Resolve alias destination
    if dst_parent and dst_parent.type == 'folder' and dst_parent.alias_target then
        dst_parent_path = dst_parent.alias_target
        dst_parent = self.filesystem[dst_parent_path]
    end
    if not node or not dst_parent or dst_parent.type ~= 'folder' then return false, 'Invalid source or destination' end
    -- Prevent moving root or parent into itself
    if src_path == '/' or dst_parent_path:sub(1, #src_path) == src_path then return false, 'Invalid move' end
    -- Remove from old parent
    local old_parent_path = src_path:match('(.+)/[^/]+$') or '/'
    local old_name = src_path:match('([^/]+)$') or src_path
    local old_parent = self.filesystem[old_parent_path]
    if old_parent and old_parent.children then
        for i, n in ipairs(old_parent.children) do if n == old_name then table.remove(old_parent.children, i); break end end
    end
    -- Prepare new name
    local name = new_name or old_name
    local function childExists(n)
        for _, c in ipairs(dst_parent.children or {}) do if c == n then return true end end
        return false
    end
    local base = name; local final = base; local i = 2
    while childExists(final) do final = base .. ' ('..i..')'; i=i+1 end
    name = final
    -- New path
    local dst_path = (dst_parent_path == '/' and ('/'..name)) or (dst_parent_path .. '/' .. name)
    -- Reindex table: move key; handle descendants for folders
    if node.type == 'folder' then
        local prefix = src_path .. '/'
        local remap = {}
        for path, _ in pairs(self.filesystem) do
            if path == src_path or path:sub(1, #prefix) == prefix then
                local suffix = (path == src_path) and '' or path:sub(#prefix)
                local new_path = dst_path .. (suffix == '' and '' or '/' .. suffix)
                remap[path] = new_path
            end
        end
        -- Apply remap in order from shortest to longest to avoid collisions
        local keys = {}
        for k, _ in pairs(remap) do table.insert(keys, k) end
        table.sort(keys, function(a,b) return #a < #b end)
        local moved = {}
        for _, old in ipairs(keys) do
            local newp = remap[old]
            self.filesystem[newp] = self.filesystem[old]
            moved[old] = true
        end
        -- Clear old keys
        for old, _ in pairs(moved) do self.filesystem[old] = nil end
    else
        self.filesystem[dst_path] = node
        self.filesystem[src_path] = nil
    end
    dst_parent.children = dst_parent.children or {}; table.insert(dst_parent.children, name)
    self:_saveFsRuntime()
    return true, dst_path
end

-- Copy an entry (shallow for folders: recreates structure references); returns new path
function FileSystem:copyEntry(src_path, dst_parent_path, new_name)
    local node = self.filesystem[src_path]
    local dst_parent = self.filesystem[dst_parent_path]
    if dst_parent and dst_parent.type == 'folder' and dst_parent.alias_target then
        dst_parent_path = dst_parent.alias_target
        dst_parent = self.filesystem[dst_parent_path]
    end
    if not node or not dst_parent or dst_parent.type ~= 'folder' then return false, 'Invalid source or destination' end
    -- Disallow copying root
    if src_path == '/' then return false, 'Invalid copy' end
    local name = new_name or (src_path:match('([^/]+)$') or 'Copy')
    local function childExists(n)
        for _, c in ipairs(dst_parent.children or {}) do if c == n then return true end end
        return false
    end
    local base = name; local final = base; local i = 2
    while childExists(final) do final = base .. ' ('..i..')'; i=i+1 end
    name = final
    local dst_path = (dst_parent_path == '/' and ('/'..name)) or (dst_parent_path .. '/' .. name)
    local function clone(tbl)
        if type(tbl) ~= 'table' then return tbl end
        local out = {}
        for k, v in pairs(tbl) do
            if k == 'children' and type(v) == 'table' then
                out[k] = { table.unpack(v) }
            else
                out[k] = clone(v)
            end
        end
        return out
    end
    if node.type == 'folder' then
        -- Copy root folder
        self.filesystem[dst_path] = clone(node)
        -- Recursively copy descendants
        local prefix = src_path .. '/'
        for path, n in pairs(self.filesystem) do
            if path:sub(1, #prefix) == prefix then
                local suffix = path:sub(#prefix)
                local newp = dst_path .. '/' .. suffix
                self.filesystem[newp] = clone(n)
            end
        end
    else
        self.filesystem[dst_path] = clone(node)
    end
    dst_parent.children = dst_parent.children or {}; table.insert(dst_parent.children, name)
    self:_saveFsRuntime()
    return true, dst_path
end

-- Create a folder link (alias) node that mirrors another folder's contents
function FileSystem:createFolderLink(parent_path, name, target_path, insert_index)
    local parent = self.filesystem[parent_path]
    -- Resolve alias parent
    if parent and parent.type == 'folder' and parent.alias_target then
        parent_path = parent.alias_target
        parent = self.filesystem[parent_path]
    end
    if not parent or parent.type ~= 'folder' then return nil end
    if not (self.filesystem[target_path] and self.filesystem[target_path].type == 'folder') then return nil end
    -- Unique name under parent
    local function childExists(n) for _, c in ipairs(parent.children or {}) do if c == n then return true end end return false end
    local base = tostring(name or (target_path:match('([^/]+)$') or 'Folder'))
    local final = base; local i = 2
    while childExists(final) do final = base .. ' ('..i..')'; i = i + 1 end
    local child_name = final
    local child_path = parent_path == '/' and ('/'..child_name) or (parent_path .. '/' .. child_name)
    if self.filesystem[child_path] then return nil end
    self.filesystem[child_path] = { type = 'folder', children = {}, alias_target = target_path }
    parent.children = parent.children or {}
    local idx = tonumber(insert_index) or (#parent.children + 1)
    if idx < 1 then idx = 1 end
    if idx > #parent.children + 1 then idx = #parent.children + 1 end
    table.insert(parent.children, idx, child_name)
    self:_saveFsRuntime()
    return child_path
end

-- Dynamic deletion rules
function FileSystem:_getDynamicRoots()
    local ok, Constants = pcall(require, 'src.constants')
    local roots = {}
    if ok and Constants and Constants.paths then
        if type(Constants.paths.DYNAMIC_ROOTS) == 'table' then
            for _, r in ipairs(Constants.paths.DYNAMIC_ROOTS) do table.insert(roots, r) end
        elseif Constants.paths.START_MENU_PROGRAMS then
            table.insert(roots, Constants.paths.START_MENU_PROGRAMS)
            table.insert(roots, '/My Computer/C:/Documents')
        end
    end
    return roots
end

function FileSystem:isDeletable(path)
    local node = self.filesystem[path]
    if not node then return false end
    -- Disallow deleting dynamic roots themselves
    for _, r in ipairs(self:_getDynamicRoots()) do if path == r then return false end end
    -- Allow only when under a dynamic root
    for _, r in ipairs(self:_getDynamicRoots()) do
        if path:sub(1, #r) == r and (path:len() > #r) and path:sub(#r+1, #r+1) == '/' then
            return true
        end
    end
    return false
end

function FileSystem:isPathInDynamicRoot(path)
    for _, r in ipairs(self:_getDynamicRoots()) do
        if path == r then return true end
        if path:sub(1, #r) == r and (path == r or path:sub(#r+1, #r+1) == '/') then return true end
    end
    return false
end

function FileSystem:canMoveOrCopy(src_path, dst_parent_path)
    -- Allow only when both source and destination are inside a dynamic root
    return self:isPathInDynamicRoot(src_path) and self:isPathInDynamicRoot(dst_parent_path)
end

-- Delete entry: move to FS recycle bin (persisted) if allowed by rules
function FileSystem:deleteEntry(path)
    if not self:isDeletable(path) then return false, 'Write-protected' end
    local node = self.filesystem[path]
    if not node then return false, 'Not found' end
    local parent_path = path:match('(.+)/[^/]+$') or '/'
    local name = path:match('([^/]+)$') or path
    local parent = self.filesystem[parent_path]
    if not parent or parent.type ~= 'folder' then return false, 'Invalid parent' end
    -- Remove child link
    for i, n in ipairs(parent.children or {}) do if n == name then table.remove(parent.children, i); break end end
    -- Record into recycle bin
    local id = self._fs_recycle.next_id or 1
    table.insert(self._fs_recycle.items, {
        id = id,
        name = name,
        original_parent = parent_path,
        original_index = nil, -- not tracked precisely for now
        original_path = path,
        node = node,
        deleted_at = os.time()
    })
    self._fs_recycle.next_id = id + 1
    -- Remove from filesystem map
    self.filesystem[path] = nil
    -- Persist recycle bin
    self:_saveFsRecycleBin()
    self:_saveFsRuntime()
    return true
end

function FileSystem:getFsRecycleBinItems()
    -- Return a shallow copy
    local out = {}
    for _, it in ipairs(self._fs_recycle.items or {}) do table.insert(out, it) end
    return out
end

function FileSystem:isFsRecycleBinEmpty()
    return not (self._fs_recycle.items and #self._fs_recycle.items > 0)
end

function FileSystem:restoreDeletedEntry(recycle_id)
    local items = self._fs_recycle.items or {}
    local idx = nil
    for i, it in ipairs(items) do if it.id == recycle_id then idx = i; break end end
    if not idx then return false, 'Not found' end
    local it = table.remove(items, idx)
    local parent = self.filesystem[it.original_parent]
    if not parent or parent.type ~= 'folder' then return false, 'Missing parent' end
    -- Resolve name conflicts
    local name = it.name
    local function childExists(n)
        for _, c in ipairs(parent.children or {}) do if c == n then return true end end
        return false
    end
    local base = name; local final = base; local i = 2
    while childExists(final) do final = base .. ' ('..i..')'; i=i+1 end
    name = final
    local dst_path = (it.original_parent == '/' and ('/'..name)) or (it.original_parent .. '/' .. name)
    self.filesystem[dst_path] = it.node
    parent.children = parent.children or {}; table.insert(parent.children, name)
    self:_saveFsRecycleBin()
    self:_saveFsRuntime()
    return true, dst_path
end

function FileSystem:permanentlyDeleteEntry(recycle_id)
    local items = self._fs_recycle.items or {}
    for i, it in ipairs(items) do if it.id == recycle_id then table.remove(items, i); self:_saveFsRecycleBin(); return true end end
    return false
end

function FileSystem:emptyFsRecycleBin()
    local count = #(self._fs_recycle.items or {})
    self._fs_recycle.items = {}
    self._fs_recycle.next_id = 1
    self:_saveFsRecycleBin()
    return count
end

-- Persistence for FS recycle bin
function FileSystem:_loadFsRecycleBin()
    local ok, contents = pcall(love.filesystem.read, self._FS_RECYCLE_FILE)
    if not ok or not contents or contents == '' then self._fs_recycle = { items = {}, next_id = 1 }; return end
    local dec_ok, data = pcall(json.decode, contents)
    if not dec_ok or type(data) ~= 'table' then self._fs_recycle = { items = {}, next_id = 1 }; return end
    self._fs_recycle = data
    if not self._fs_recycle.next_id then self._fs_recycle.next_id = (#(self._fs_recycle.items or {}) + 1) end
end

function FileSystem:_saveFsRecycleBin()
    local enc_ok, out = pcall(json.encode, self._fs_recycle or { items = {}, next_id = 1 })
    if not enc_ok then return false end
    local ok, err = pcall(love.filesystem.write, self._FS_RECYCLE_FILE, out)
    if not ok then print('ERROR writing fs_recycle_bin: '..tostring(err)); return false end
    return true
end

-- Runtime FS: load/save full filesystem map (distinct from assets/data/filesystem.json)
function FileSystem:_loadFsRuntime()
    local ok, contents = pcall(love.filesystem.read, self._FS_RUNTIME_FILE)
    if not ok or not contents or contents == '' then return end
    local dec_ok, data = pcall(json.decode, contents)
    if not dec_ok or type(data) ~= 'table' then return end
    if data.filesystem and type(data.filesystem) == 'table' then
        self.filesystem = data.filesystem
        print('Loaded runtime FS state')
    end
end

function FileSystem:_saveFsRuntime()
    local payload = { filesystem = self.filesystem }
    local enc_ok, out = pcall(json.encode, payload)
    if not enc_ok then return false end
    local ok, err = pcall(love.filesystem.write, self._FS_RUNTIME_FILE, out)
    if not ok then print('ERROR writing fs_runtime.json: '..tostring(err)); return false end
    return true
end

-- Navigate to a path
function FileSystem:navigate(path)
    if not self.filesystem[path] then
        return false, "Path not found"
    end
    
    self.current_path = path
    return true
end

-- Navigate up one level
function FileSystem:goUp()
    if self.current_path == "/" then
        return false, "Already at root"
    end
    
    -- Find parent path
    local parent = self.current_path:match("(.*/)")
    if not parent then
        parent = "/"
    else
        parent = parent:sub(1, -2) -- Remove trailing slash
        if parent == "" then parent = "/" end
    end
    
    return self:navigate(parent)
end

-- Get current path
function FileSystem:getCurrentPath()
    return self.current_path
end

-- Open an item (returns action to perform)
function FileSystem:openItem(item_path)
    local item = self.filesystem[item_path]
    if not item then
        return {type = "error", message = "Item not found"}
    end
    
    if item.type == "folder" then
        return {type = "navigate", path = item_path}
    end

    if item.type == "executable" then
        return {type = "launch_program", program_id = item.program_id}
    end

    if item.type == "file" then
        return {type = "show_text", content = item.content, title = item_path}
    end

    if item.type == "special" then
        return {type = "special", special_type = item.special_type}
    end
    
    return {type = "error", message = "Unknown item type"}
end

-- Get icon type for an item
function FileSystem:getItemIcon(item)
    if item.type == "folder" then
        return "folder"
    elseif item.type == "executable" then
        return "exe"
    elseif item.type == "file" then
        if item.name and item.name:match("%.txt$") then
            return "text"
        end
        return "file"
    elseif item.type == "special" then
        if item.special_type == "recycle_bin" then
            return "recycle_bin"
        elseif item.special_type == "desktop_view" then
            return "desktop"
        end
        return "special"
    end
    
    return "unknown"
end

-- Check if path exists
function FileSystem:pathExists(path)
    return self.filesystem[path] ~= nil
end

-- Get item at path
function FileSystem:getItem(path)
    return self.filesystem[path]
end

-- Extensions: Start Menu Programs mirroring
function FileSystem:ensureStartMenuProgramsFolder(program_registry)
    local ok, Constants = pcall(require, 'src.constants')
    if not ok or not Constants or not Constants.paths then return end
    local root_path = Constants.paths.START_MENU_PROGRAMS
    local base_parent = '/My Computer/C:/Windows/System32'
    local fs = self.filesystem
    -- Ensure base parent exists and is a folder
    if not fs[base_parent] or fs[base_parent].type ~= 'folder' then return end
    -- Create Start Menu Programs folder if missing
    if not fs[root_path] then
        fs[root_path] = { type = 'folder', children = {} }
        local parent = fs[base_parent]
        parent.children = parent.children or {}
        -- Insert near end if not present
        local exists = false
        for _, c in ipairs(parent.children) do if c == 'Start Menu Programs' then exists = true; break end end
        if not exists then table.insert(parent.children, 'Start Menu Programs') end
    end
    -- Seed with executables for Start Menu programs if empty
    local root = fs[root_path]
    root.children = root.children or {}
    if #root.children == 0 and program_registry and program_registry.getAllPrograms then
        local programs = program_registry:getAllPrograms() or {}
        for _, p in ipairs(programs) do
            local in_menu = (p.in_start_menu == true) or (program_registry.hasStartMenuOverride and program_registry:hasStartMenuOverride(p.id))
            if in_menu and not p.disabled then
                self:createExecutable(root_path, p.name or p.id, p.id)
            end
        end
    end
end

-- Create an executable entry node under parent_path with a given program_id
function FileSystem:createExecutable(parent_path, name, program_id, insert_index)
    local parent = self.filesystem[parent_path]
    if not parent or parent.type ~= 'folder' then return nil end
    -- Sanitize/unique child name
    local function childExists(n)
        for _, c in ipairs(parent.children or {}) do if c == n then return true end end
        return false
    end
    local base = tostring(name or (program_id or 'Program'))
    local final = base
    local i = 2
    while childExists(final) do final = base .. ' ('..i..')'; i = i + 1 end
    local child_name = final
    local child_path = parent_path == '/' and ('/'..child_name) or (parent_path .. '/' .. child_name)
    if self.filesystem[child_path] then return nil end
    self.filesystem[child_path] = { type = 'executable', program_id = program_id }
    parent.children = parent.children or {}
    local idx = tonumber(insert_index) or (#parent.children + 1)
    if idx < 1 then idx = 1 end
    if idx > #parent.children + 1 then idx = #parent.children + 1 end
    table.insert(parent.children, idx, child_name)
    self:_saveFsRuntime()
    return child_path
end

return FileSystem