-- src/utils/settings_manager.lua
local json = require('json')
-- Prefer injected config, fallback to global DI_CONFIG
local ConfigRef = rawget(_G, 'DI_CONFIG') or {}

local SettingsManager = {}
local SETTINGS_FILE = "settings.json"

-- Default settings
local Paths = require('src.paths')
local defaults = {
    master_volume = 0.8,
    music_volume = 0.6,
    sfx_volume = 0.7,
    tutorial_shown = false,
    fullscreen = true,
    -- Solitaire
    solitaire_draw_count = 1,           -- 1 or 3
    solitaire_redeal_limit = "infinite", -- 'infinite' | 3 | 1
    solitaire_empty_any = false,        -- false: Kings-only, true: Any
    solitaire_card_back = nil,          -- id of selected back from assets/sprites/solitare/backs/
    -- Screensaver
    screensaver_enabled = true,
    screensaver_timeout = 10,   -- seconds
    screensaver_type = "starfield",
    -- Pipes screensaver options
    screensaver_pipes_spawn_min_z = 200,
    screensaver_pipes_spawn_max_z = 600,
    screensaver_pipes_radius = 4.5,
    screensaver_pipes_speed = 60,
    screensaver_pipes_turn_chance = 0.45,
    screensaver_pipes_avoid_cells = true,
    screensaver_pipes_show_grid = false,
    screensaver_pipes_camera_roll = 0.05,
    screensaver_pipes_camera_drift = 40,
    screensaver_pipes_pipe_count = 5,
    screensaver_pipes_near = 80,
    -- Additional Pipes options
    screensaver_pipes_fov = 420,
    screensaver_pipes_grid_step = 24,
    screensaver_pipes_max_segments = 800,
    screensaver_pipes_show_hud = true,
    -- Model screensaver options
    screensaver_model_path = (require('src.paths').data.models .. "cube.json"),
    screensaver_model_scale = 1.0,
    screensaver_model_fov = 350,
    screensaver_model_rot_speed_x = 0.4,
    screensaver_model_rot_speed_y = 0.6,
    screensaver_model_rot_speed_z = 0.0,
    screensaver_model_grid_lat = 24,
    screensaver_model_grid_lon = 48,
    screensaver_model_morph_speed = 0.3,
    screensaver_model_two_sided = false,
    -- New model3d morph settings
    screensaver_model_shape1 = "cube",
    screensaver_model_shape2 = "sphere",
    screensaver_model_shape3 = "none",
    screensaver_model_hold_time = 0.0,
    screensaver_model_tint_r = 1.0,
    screensaver_model_tint_g = 1.0,
    screensaver_model_tint_b = 1.0,
    -- Starfield screensaver options
    screensaver_starfield_count = 500,
    screensaver_starfield_speed = 120,
    screensaver_starfield_fov = 300,
    screensaver_starfield_tail = 12
    ,
    -- 3D Text screensaver options
    screensaver_text3d_text = "good?",
    screensaver_text3d_use_time = false,
    -- Unified size control replaces font_size/fov/distance in UI; keep old keys for compatibility
    screensaver_text3d_size = 1.0,
    screensaver_text3d_font_size = 96,
    screensaver_text3d_extrude_layers = 12,
    screensaver_text3d_fov = 350,
    screensaver_text3d_distance = 18,
    screensaver_text3d_color_mode = "solid",
    screensaver_text3d_use_hsv = false,
    screensaver_text3d_color_r = 1.0,
    screensaver_text3d_color_g = 1.0,
    screensaver_text3d_color_b = 0.2,
    screensaver_text3d_color_h = 0.15,
    screensaver_text3d_color_s = 1.0,
    screensaver_text3d_color_v = 1.0,
    screensaver_text3d_spin_x = 0.0,
    screensaver_text3d_spin_y = 0.8,
    screensaver_text3d_spin_z = 0.1,
    screensaver_text3d_move_enabled = true,
    screensaver_text3d_move_mode = "orbit",
    screensaver_text3d_move_radius = 120,
    screensaver_text3d_move_speed = 0.25,
    screensaver_text3d_bounce_speed_x = 100,
    screensaver_text3d_bounce_speed_y = 80,
    screensaver_text3d_pulse_enabled = false,
    screensaver_text3d_pulse_amp = 0.25,
    screensaver_text3d_pulse_speed = 0.8,
    screensaver_text3d_wavy_baseline = false,
    screensaver_text3d_specular = 0.0
    ,
    -- Desktop options
    desktop_bg_type = "color", -- 'color' | 'image'
    desktop_bg_image = nil,     -- wallpaper id
    desktop_bg_scale_mode = "fill", -- 'fill'|'fit'|'stretch'|'center'|'tile'
    desktop_bg_r = 0.0,
    desktop_bg_g = 0.5,
    desktop_bg_b = 0.5,
    desktop_icon_snap = true
}

local current_settings = {}

-- Optional DI injection (call early at startup)
function SettingsManager.inject(di)
    if di and di.config then
        ConfigRef = di.config
    end
end

-- Load settings from file or use defaults
function SettingsManager.load()
    local save_dir = ''
    local ok_dir, dir = pcall(love.filesystem.getSaveDirectory)
    if ok_dir and dir then save_dir = dir end
    --
    local read_ok, contents = pcall(love.filesystem.read, SETTINGS_FILE)
    if read_ok and contents then
    --
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
            -- Debug: show desktop wallpaper-related keys
            --
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
        -- Fullscreen mode - use Config.window.fullscreen if available
        local wf = (ConfigRef and ConfigRef.window and ConfigRef.window.fullscreen) or {}
        local width = wf.width or 1920
        local height = wf.height or 1080
        local fullscreentype = wf.type or "desktop"
        local resizable = (wf.resizable ~= nil) and wf.resizable or false
        love.window.setMode(width, height, {
            fullscreen = true,
            fullscreentype = fullscreentype,
            resizable = resizable
        })
        print(string.format("Applied fullscreen: true (%dx%d)", width, height))
    else
        -- Windowed mode - use Config.window.windowed if available
        local ww = (ConfigRef and ConfigRef.window and ConfigRef.window.windowed) or {}
        local width = ww.width or 1280
        local height = ww.height or 720
        local resizable = (ww.resizable ~= nil) and ww.resizable or false
        love.window.setMode(width, height, {
            fullscreen = false,
            resizable = resizable
        })
        print(string.format("Applied fullscreen: false (%dx%d windowed)", width, height))
    end
end

-- Save current settings to file
function SettingsManager.save()
    local save_dir = ''
    local ok_dir, dir = pcall(love.filesystem.getSaveDirectory)
    if ok_dir and dir then save_dir = dir end
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
    -- Debug: confirm save and key values
    --
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