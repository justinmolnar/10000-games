local json = require('json')
local SaveManager = {}

local SAVE_VERSION = "1.0"

function SaveManager.save(player_data)
    -- Create save data structure
    local save_data = {
        version = SAVE_VERSION,
        timestamp = os.time(),
        player = {
            tokens = player_data.tokens,
            unlocked_games = player_data.unlocked_games,
            completed_games = player_data.completed_games,
            game_performance = player_data.game_performance,
            space_defender_level = player_data.space_defender_level,
            vm_slots = player_data.vm_slots,
            active_vms = player_data.active_vms,
            upgrades = player_data.upgrades
        }
    }
    
    -- Convert to JSON
    local success, json_str = pcall(json.encode, save_data)
    if not success then
        print("Error encoding save data:", json_str)
        return false, "Failed to encode save data"
    end
    
    -- Save to file (using LÖVE's save directory)
    local success, message = love.filesystem.write("save.json", json_str)
    if success then
        print("Game saved successfully")
    else
        print("Failed to save:", message)
    end
    return success, message
end

function SaveManager.load()
    -- Check if save file exists
    if not love.filesystem.getInfo("save.json") then
        print("No save file found")
        return nil, "No save file found"
    end
    
    -- Read save file
    local contents, size = love.filesystem.read("save.json")
    if not contents then
        print("Could not read save file")
        return nil, "Could not read save file"
    end
    
    -- Parse JSON
    local success, save_data = pcall(json.decode, contents)
    if not success then
        print("Invalid save file format:", save_data)
        return nil, "Invalid save file format"
    end
    
    -- Version check
    if save_data.version ~= SAVE_VERSION then
        print("Incompatible save version:", save_data.version)
        return nil, "Incompatible save version"
    end
    
    print("Save file loaded successfully")
    return save_data.player
end

return SaveManager