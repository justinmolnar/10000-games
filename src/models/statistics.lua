-- src/models/statistics.lua
local Object = require('class')
local json = require('json')

local Statistics = Object:extend('Statistics')
local STATS_FILE = "statistics.json"

function Statistics:init()
    self.data = {
        total_games_unlocked = 0,
        total_bullets_fired = 0,
        total_tokens_earned = 0,
        total_playtime = 0, -- In seconds
        highest_damage_dealt = 0
    }
end

-- Load statistics from file
function Statistics:load()
    local read_ok, contents = pcall(love.filesystem.read, STATS_FILE)
    if read_ok and contents then
        local decode_ok, loaded_data = pcall(json.decode, contents)
        if decode_ok and type(loaded_data) == 'table' then
            -- Merge loaded data, ensuring all keys exist
            for key, default_value in pairs(self.data) do
                self.data[key] = loaded_data[key] or default_value
            end
            print("Statistics loaded successfully.")
            return true
        else
            print("Error decoding statistics file: " .. tostring(loaded_data) .. ". Using defaults.")
        end
    else
        print("No statistics file found or read error. Using defaults.")
    end
    -- Initialize defaults if load failed
    self:init() -- Reset to defaults
    return false
end

-- Save statistics to file
function Statistics:save()
    local encode_ok, json_str = pcall(json.encode, self.data)
    if not encode_ok then
        print("Error encoding statistics data: " .. tostring(json_str))
        return false
    end

    local write_ok, message = pcall(love.filesystem.write, STATS_FILE, json_str)
    if not write_ok then
        print("Failed to write statistics file: " .. tostring(message))
        return false
    end
    -- print("Statistics saved.") -- Optional debug
    return true
end

-- --- Increment/Update Methods ---

function Statistics:addPlaytime(dt)
    self.data.total_playtime = self.data.total_playtime + dt
end

function Statistics:addTokensEarned(amount)
    -- Only count positive amounts as earned
    if type(amount) == "number" and amount > 0 then
        self.data.total_tokens_earned = self.data.total_tokens_earned + amount
        -- Print removed
    end
end

function Statistics:incrementGamesUnlocked()
    self.data.total_games_unlocked = self.data.total_games_unlocked + 1
    -- Print removed
end

function Statistics:addBulletsFired(count)
     if type(count) == "number" and count > 0 then
        self.data.total_bullets_fired = self.data.total_bullets_fired + count
        -- Print removed
     end
end

function Statistics:recordDamageDealt(damage)
    if type(damage) == "number" and damage > self.data.highest_damage_dealt then
        self.data.highest_damage_dealt = damage
        -- Print removed
    end
end

-- --- Getter Methods ---

function Statistics:getStat(key)
    return self.data[key]
end

function Statistics:getAllStats()
    -- Return a copy to prevent external modification
    local copy = {}
    for k, v in pairs(self.data) do
        copy[k] = v
    end
    return copy
end

return Statistics