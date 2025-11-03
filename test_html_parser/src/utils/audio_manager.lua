local Object = require('class')
local json = require('json')
local AudioManager = Object:extend('AudioManager')

function AudioManager:init(di)
    self.di = di
    self.settings = di and di.settingsManager

    -- Cache for loaded music tracks
    self.music = {}

    -- Cache for loaded SFX packs
    self.sfx_packs = {}

    -- Currently playing music
    self.current_music = nil
    self.current_music_source = nil

    -- Load SFX pack definitions
    self:loadSFXPackDefinitions()

    print("[AudioManager] Initialized")
end

-- Phase 3.2: Load SFX pack definitions from JSON
function AudioManager:loadSFXPackDefinitions()
    local file_path = "assets/audio/data/sfx_packs.json"

    local success, contents = pcall(love.filesystem.read, file_path)
    if not success or not contents then
        print("[AudioManager] Could not read " .. file_path .. " (file may not exist yet)")
        self.sfx_pack_definitions = {}
        return
    end

    local decode_success, data = pcall(json.decode, contents)
    if not decode_success or not data then
        print("[AudioManager] Failed to decode " .. file_path)
        self.sfx_pack_definitions = {}
        return
    end

    self.sfx_pack_definitions = data
    print("[AudioManager] Loaded " .. self:countKeys(data) .. " SFX pack definitions")
end

function AudioManager:countKeys(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

-- Phase 3.2: Load an entire SFX pack into memory
function AudioManager:loadSFXPack(pack_name)
    if not pack_name then
        print("[AudioManager] loadSFXPack called with nil pack_name")
        return nil
    end

    -- Return cached pack if already loaded
    if self.sfx_packs[pack_name] then
        return self.sfx_packs[pack_name]
    end

    local pack_def = self.sfx_pack_definitions[pack_name]
    if not pack_def then
        print("[AudioManager] SFX pack not found: " .. pack_name .. " (using silent fallback)")
        self.sfx_packs[pack_name] = {} -- Cache empty pack to avoid repeated warnings
        return self.sfx_packs[pack_name]
    end

    local pack = {}
    local sounds_loaded = 0
    local sounds_missing = 0

    for action, file_path in pairs(pack_def.sounds or {}) do
        local success, source = pcall(function()
            return love.audio.newSource(file_path, "static")
        end)

        if success and source then
            pack[action] = source
            sounds_loaded = sounds_loaded + 1
        else
            -- Graceful fallback: missing sound = nil (silent)
            pack[action] = nil
            sounds_missing = sounds_missing + 1
        end
    end

    if sounds_loaded > 0 then
        print(string.format("[AudioManager] Loaded SFX pack '%s': %d sounds (%d missing)",
            pack_name, sounds_loaded, sounds_missing))
    elseif sounds_missing > 0 then
        print(string.format("[AudioManager] SFX pack '%s' has no sounds loaded (%d missing, using silent fallback)",
            pack_name, sounds_missing))
    end

    self.sfx_packs[pack_name] = pack
    return pack
end

-- Phase 3.3: Play a sound from an SFX pack
function AudioManager:playSound(pack_name, action, volume_override)
    if not pack_name or not action then
        return -- Silent fail for invalid params
    end

    -- Load pack if not already loaded
    local pack = self.sfx_packs[pack_name]
    if not pack then
        pack = self:loadSFXPack(pack_name)
    end

    if not pack then
        return -- Pack doesn't exist, silent fail
    end

    local source = pack[action]
    if not source then
        -- Sound doesn't exist in pack, silent fail
        return
    end

    -- Calculate volume: master * sfx * override
    local master_volume = (self.settings and self.settings:get('master_volume')) or 0.8
    local sfx_volume = (self.settings and self.settings:get('sfx_volume')) or 0.7
    local final_volume = master_volume * sfx_volume * (volume_override or 1.0)

    -- Clone source and play (allows overlapping sounds)
    local success, err = pcall(function()
        local clone = source:clone()
        clone:setVolume(final_volume)
        clone:play()
    end)

    if not success then
        print("[AudioManager] Failed to play sound: " .. tostring(err))
    end
end

-- Phase 3.3: Load music track
function AudioManager:loadMusic(file_path)
    if not file_path then
        print("[AudioManager] loadMusic called with nil file_path")
        return nil
    end

    -- Return cached music if already loaded
    if self.music[file_path] then
        return self.music[file_path]
    end

    local success, source = pcall(function()
        return love.audio.newSource(file_path, "stream") -- Stream for music (lower memory)
    end)

    if success and source then
        source:setLooping(true)
        self.music[file_path] = source
        print("[AudioManager] Loaded music: " .. file_path)
        return source
    else
        print("[AudioManager] Failed to load music: " .. file_path .. " (using silent fallback)")
        self.music[file_path] = nil -- Cache nil to avoid repeated load attempts
        return nil
    end
end

-- Phase 3.3: Play music track
function AudioManager:playMusic(file_path, fade_duration)
    if not file_path then
        return -- Silent fail
    end

    -- Load music if not already loaded
    local source = self.music[file_path]
    if not source then
        source = self:loadMusic(file_path)
    end

    if not source then
        return -- Music doesn't exist, silent fail
    end

    -- Stop current music if playing
    if self.current_music_source and self.current_music_source:isPlaying() then
        self.current_music_source:stop()
    end

    -- Calculate volume: master * music
    local master_volume = (self.settings and self.settings:get('master_volume')) or 0.8
    local music_volume = (self.settings and self.settings:get('music_volume')) or 0.6
    local final_volume = master_volume * music_volume

    -- Play new music
    source:setVolume(final_volume)

    local success, err = pcall(function()
        source:play()
    end)

    if success then
        self.current_music = file_path
        self.current_music_source = source
        print("[AudioManager] Playing music: " .. file_path)
    else
        print("[AudioManager] Failed to play music: " .. tostring(err))
    end
end

-- Stop current music
function AudioManager:stopMusic()
    if self.current_music_source and self.current_music_source:isPlaying() then
        self.current_music_source:stop()
        print("[AudioManager] Stopped music: " .. (self.current_music or "unknown"))
    end
    self.current_music = nil
    self.current_music_source = nil
end

-- Update volume for currently playing music (called when settings change)
function AudioManager:updateMusicVolume()
    if self.current_music_source then
        local master_volume = (self.settings and self.settings:get('master_volume')) or 0.8
        local music_volume = (self.settings and self.settings:get('music_volume')) or 0.6
        local final_volume = master_volume * music_volume
        self.current_music_source:setVolume(final_volume)
    end
end

-- Cleanup
function AudioManager:cleanup()
    self:stopMusic()

    -- Stop all SFX (they auto-cleanup, but we can clear cache)
    self.sfx_packs = {}
    self.music = {}

    print("[AudioManager] Cleaned up")
end

return AudioManager
