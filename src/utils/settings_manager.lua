-- src/utils/settings_manager.lua
local json = require('json')

local SettingsManager = {}
local SETTINGS_FILE = "settings.json"

-- Default settings
local defaults = {
    master_volume = 0.8,
    music_volume = 0.6,
    sfx_volume = 0.7,
    tutorial_shown = false,
    fullscreen = true
}

local current_settings = {}

-- Load settings from file or use defaults
function SettingsManager.load()
    local read_ok, contents = pcall(love.filesystem.read, SETTINGS_FILE)
    if read_ok and contents then
        local decode_ok, data = pcall(json.decode, contents)
        if decode_ok then
            -- Merge loaded data with defaults to ensure all keys exist
            for key, default_value in pairs(defaults) do
                current_settings[key] = data[key]
                if current_settings[key] == nil then -- Use default if key missing in save
                    current_settings[key] = default_value
                end
            end
            print("Settings loaded successfully from " .. SETTINGS_FILE)
            SettingsManager.applyAudioSettings() -- Apply volume on load
            SettingsManager.applyFullscreen() -- Apply fullscreen on load
            return true
        else
            print("Error decoding settings file: " .. tostring(data) .. ". Using defaults.")
        end
    else
        print("No settings file found or read error: " .. tostring(contents) .. ". Using defaults.")
    end

    -- Use defaults if loading failed
    current_settings = {}
    for key, value in pairs(defaults) do
        current_settings[key] = value
    end
    SettingsManager.applyAudioSettings() -- Apply default volume
    SettingsManager.applyFullscreen() -- Apply default fullscreen
    return false
end

-- Apply fullscreen setting
function SettingsManager.applyFullscreen()
    local fullscreen = current_settings.fullscreen
    if fullscreen == nil then fullscreen = defaults.fullscreen end
    
    if fullscreen then
        -- Fullscreen mode - use desktop resolution
        love.window.setMode(1920, 1080, {
            fullscreen = true,
            fullscreentype = "desktop",
            resizable = false
        })
        print("Applied fullscreen: true (1920x1080)")
    else
        -- Windowed mode - use smaller window size
        love.window.setMode(1280, 720, {
            fullscreen = false,
            resizable = false
        })
        print("Applied fullscreen: false (1280x720 windowed)")
    end
end

-- Save current settings to file
function SettingsManager.save()
    local encode_ok, json_str = pcall(json.encode, current_settings)
    if not encode_ok then
        print("Error encoding settings data: " .. tostring(json_str))
        return false
    end

    local write_ok, message = pcall(love.filesystem.write, SETTINGS_FILE, json_str)
    if not write_ok then
        print("Failed to write settings file: " .. tostring(message))
        return false
    end
    -- print("Settings saved successfully.") -- Optional debug message
    return true
end

-- Get a specific setting value
function SettingsManager.get(key)
    return current_settings[key]
end

-- Set a specific setting value
function SettingsManager.set(key, value)
    if current_settings[key] ~= value then
        current_settings[key] = value
        -- Apply immediately if it's an audio or fullscreen setting
        if key == "master_volume" or key == "music_volume" or key == "sfx_volume" then
            SettingsManager.applyAudioSettings()
        elseif key == "fullscreen" then
            SettingsManager.applyFullscreen()
        end
        SettingsManager.save() -- Auto-save on change
    end
end

-- Apply volume settings to love.audio
function SettingsManager.applyAudioSettings()
    local master = current_settings.master_volume or defaults.master_volume
    -- Note: LÖVE doesn't have separate music/SFX channels globally.
    -- We are setting the master volume based on the master setting.
    -- To implement separate Music/SFX volumes, individual sound sources
    -- would need their volume adjusted when played, likely using these settings
    -- as multipliers. For MVP, we just set the global volume.
    love.audio.setVolume(master)
    print("Applied master volume: " .. master)
end

-- Get all current settings (for UI)
function SettingsManager.getAll()
    return current_settings
end

return SettingsManager