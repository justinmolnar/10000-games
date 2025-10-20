-- src/models/file_system.lua
-- Model representing virtual file system structure for browsing

local Object = require('class')
local json = require('json')
local FileSystem = Object:extend('FileSystem')

function FileSystem:init()
    self.current_path = "/"
    self.filesystem = {}
    
    self:loadFilesystem()
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
    for _, child_name in ipairs(item.children or {}) do
        local child_path = path == "/" and ("/" .. child_name) or (path .. "/" .. child_name)
        local child_item = self.filesystem[child_path]
        
        if child_item then
            table.insert(contents, {
                name = child_name,
                path = child_path,
                type = child_item.type,
                special_type = child_item.special_type,
                program_id = child_item.program_id
            })
        end
    end
    
    return contents
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

return FileSystem