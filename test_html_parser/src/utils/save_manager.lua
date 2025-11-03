-- src/utils/save_manager.lua
local json = require('json')
local SaveManager = {}
local event_bus = nil -- Module-level variable for injected EventBus

-- Prefer injected Config; fallback to global DI_CONFIG
local ConfigRef = rawget(_G, 'DI_CONFIG') or {}
local DEFAULT_SAVE_VERSION = '1.0'

function SaveManager.inject(di)
    if di then
        if di.config then ConfigRef = di.config end
        if di.eventBus then event_bus = di.eventBus end -- Store injected event bus
    end
end

function SaveManager.save(player_data)
    -- Publish save_started event
    if event_bus then pcall(event_bus.publish, event_bus, 'save_started') end

    -- Check if player_data is valid before proceeding
    if not player_data or type(player_data.serialize) ~= 'function' then
        print("Error saving: Invalid player_data object.")
        -- Publish save_failed event
        if event_bus then pcall(event_bus.publish, event_bus, 'save_failed', "Invalid player_data object") end
        return false, "Invalid player_data"
    end

    -- Use pcall to safely call serialize
    local serialize_ok, player_save_data = pcall(player_data.serialize, player_data)
    if not serialize_ok then
        print("Error saving: Failed to serialize player_data - " .. tostring(player_save_data))
        -- Publish save_failed event
        if event_bus then pcall(event_bus.publish, event_bus, 'save_failed', "Serialization failed") end
        return false, "Serialization failed"
    end

    local save_data = {
        version = (ConfigRef and ConfigRef.save_version) or DEFAULT_SAVE_VERSION, -- Use config value or fallback
        timestamp = os.time(),
        player = player_save_data
    }

    -- Use pcall for JSON encoding
    local encode_ok, json_str = pcall(json.encode, save_data)
    if not encode_ok then
        print("Error encoding save data:", json_str)
        -- Publish save_failed event
        if event_bus then pcall(event_bus.publish, event_bus, 'save_failed', "Failed to encode save data") end
        return false, "Failed to encode save data"
    end

    local save_file_name = (ConfigRef and ConfigRef.save_file_name) or 'save.json'
    -- Use pcall for file writing
    local write_ok, message = pcall(love.filesystem.write, save_file_name, json_str)
    if write_ok then
        -- print("Game saved successfully") -- Keep console clean
        -- Publish save_completed event
        if event_bus then pcall(event_bus.publish, event_bus, 'save_completed', save_file_name) end
    else
        print("Failed to write save file:", message)
        -- Publish save_failed event
        if event_bus then pcall(event_bus.publish, event_bus, 'save_failed', message) end
        return false, message -- Return the actual error message
    end
    return true, nil -- Success
end

function SaveManager.load()
    -- Publish load_started event
    if event_bus then pcall(event_bus.publish, event_bus, 'load_started') end

    local save_file = (ConfigRef and ConfigRef.save_file_name) or 'save.json'

    -- Use pcall to check file info safely
    local info_ok, info = pcall(love.filesystem.getInfo, save_file)
    if not info_ok or not info then
        print("No save file found or error accessing it.")
        -- Publish load_failed event
        if event_bus then pcall(event_bus.publish, event_bus, 'load_failed', "No save file found") end
        return nil, "No save file found"
    end

    -- Use pcall to read file safely
    local read_ok, contents = pcall(love.filesystem.read, save_file)
    if not read_ok or not contents then
        print("Could not read save file:", tostring(contents)) -- Log error if read failed
        -- Publish load_failed event
        if event_bus then pcall(event_bus.publish, event_bus, 'load_failed', "Could not read save file") end
        return nil, "Could not read save file"
    end

    -- Use pcall to decode JSON safely
    local decode_ok, save_data = pcall(json.decode, contents)
    if not decode_ok then
        print("Invalid save file format:", save_data) -- Log decode error
        -- Optional: Backup corrupted save before deleting?
        -- pcall(love.filesystem.write, save_file .. ".corrupted", contents)
        pcall(love.filesystem.remove, save_file) -- Attempt to remove corrupted save
        -- Publish load_failed event
        if event_bus then pcall(event_bus.publish, event_bus, 'load_failed', "Invalid save file format - Save deleted") end
        return nil, "Invalid save file format - Save deleted"
    end

    -- Validate basic structure
    if type(save_data) ~= 'table' or not save_data.version or not save_data.player then
         print("Invalid save data structure:", json.encode(save_data))
         pcall(love.filesystem.remove, save_file)
         -- Publish load_failed event
         if event_bus then pcall(event_bus.publish, event_bus, 'load_failed', "Invalid save data structure - Save deleted") end
         return nil, "Invalid save data structure - Save deleted"
    end

    -- Version check
    local expected_version = (ConfigRef and ConfigRef.save_version) or DEFAULT_SAVE_VERSION
    if save_data.version ~= expected_version then
        print("Incompatible save version:", save_data.version, " Expected:", expected_version)
        -- Add migration logic here in the future if needed
        -- Publish load_failed event
        if event_bus then pcall(event_bus.publish, event_bus, 'load_failed', "Incompatible save version") end
        return nil, "Incompatible save version"
    end

    print("Save file loaded successfully (Version: " .. save_data.version .. ")")
    -- Publish load_completed event
    if event_bus then pcall(event_bus.publish, event_bus, 'load_completed', save_file, save_data.player) end

    -- Return only the player data part
    return save_data.player
end

return SaveManager