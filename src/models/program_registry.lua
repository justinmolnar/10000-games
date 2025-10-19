local Object = require('class')
local json = require('json')
local Paths = require('src.paths')
local ProgramRegistry = Object:extend('ProgramRegistry')

function ProgramRegistry:init()
    self.programs = {}
    self:loadPrograms()
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
    local start_menu = {}
    for _, program in ipairs(self.programs) do
        if program.in_start_menu then
            table.insert(start_menu, program)
        end
    end
    return start_menu
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

return ProgramRegistry