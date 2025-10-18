local json = require('json')
local SaveManager = {}

local SAVE_VERSION = "1.0"

function SaveManager.save(player_data)
    local Config = require('src.config') -- Require config at the top of the file
    
    -- Check if player_data is valid before proceeding
    if not player_data or type(player_data.serialize) ~= 'function' then
        print("Error saving: Invalid player_data object.")
        return false, "Invalid player_data"
    end

    -- Use pcall to safely call serialize
    local serialize_ok, player_save_data = pcall(player_data.serialize, player_data)
    if not serialize_ok then
        print("Error saving: Failed to serialize player_data - " .. tostring(player_save_data))
        return false, "Serialization failed"
    end
    
    local save_data = {
        version = Config.save_version, -- Use config value
        timestamp = os.time(),
        player = player_save_data 
    }
    
    -- Use pcall for JSON encoding
    local encode_ok, json_str = pcall(json.encode, save_data)
    if not encode_ok then
        print("Error encoding save data:", json_str)
        return false, "Failed to encode save data"
    end
    
    -- Use pcall for file writing
    local write_ok, message = pcall(love.filesystem.write, Config.save_file_name, json_str)
    if write_ok then
        -- print("Game saved successfully") -- Keep console clean
    else
        print("Failed to write save file:", message)
        return false, message -- Return the actual error message
    end
    return true, nil -- Success
end

function SaveManager.load()
    local Config = require('src.config') -- Require config at the top of the file
    local save_file = Config.save_file_name
    
    -- Use pcall to check file info safely
    local info_ok, info = pcall(love.filesystem.getInfo, save_file)
    if not info_ok or not info then
        print("No save file found or error accessing it.")
        return nil, "No save file found"
    end
    
    -- Use pcall to read file safely
    local read_ok, contents = pcall(love.filesystem.read, save_file)
    if not read_ok or not contents then
        print("Could not read save file:", tostring(contents)) -- Log error if read failed
        return nil, "Could not read save file"
    end
    
    -- Use pcall to decode JSON safely
    local decode_ok, save_data = pcall(json.decode, contents)
    if not decode_ok then
        print("Invalid save file format:", save_data) -- Log decode error
        -- Optional: Backup corrupted save before deleting?
        -- pcall(love.filesystem.write, save_file .. ".corrupted", contents)
        pcall(love.filesystem.remove, save_file) -- Attempt to remove corrupted save
        return nil, "Invalid save file format - Save deleted"
    end
    
    -- Validate basic structure
    if type(save_data) ~= 'table' or not save_data.version or not save_data.player then
         print("Invalid save data structure:", json.encode(save_data))
         pcall(love.filesystem.remove, save_file) 
         return nil, "Invalid save data structure - Save deleted"
    end

    -- Version check
    if save_data.version ~= Config.save_version then
        print("Incompatible save version:", save_data.version, " Expected:", Config.save_version)
        -- Add migration logic here in the future if needed
        return nil, "Incompatible save version"
    end
    
    print("Save file loaded successfully (Version: " .. save_data.version .. ")")
    -- Return only the player data part
    return save_data.player 
end

return SaveManager