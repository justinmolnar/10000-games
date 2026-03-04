local Object = require('class')
local AudioManager = Object:extend('AudioManager')

local SFX_BASE = "assets/audio/sfx"

function AudioManager:init(di)
    self.di = di
    self.settings = di and di.settingsManager

    -- Cache for loaded music tracks
    self.music = {}

    -- Cache for loaded SFX sets (keyed by "game_type:theme")
    self.sfx_sets = {}

    -- Currently playing music
    self.current_music = nil
    self.current_music_source = nil

    print("[AudioManager] Initialized")
end

function AudioManager:countKeys(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

-- Scan a folder for audio files and load them into pack table
-- Later layers overwrite earlier ones (game-specific > theme > default)
function AudioManager:_loadSoundsFromFolder(folder, pack)
    local items = love.filesystem.getDirectoryItems(folder)
    local loaded = 0
    for _, filename in ipairs(items) do
        local action = filename:match("^(.+)%.mp3$") or filename:match("^(.+)%.ogg$") or filename:match("^(.+)%.wav$")
        if action then
            local path = folder .. "/" .. filename
            local ok, source = pcall(love.audio.newSource, path, "static")
            if ok and source then
                pack[action] = source
                loaded = loaded + 1
            end
        end
    end
    return loaded
end

-- Load a layered SFX set: shared/default -> shared/{theme} -> games/{game_type}
-- Returns the set key for use with playSound
function AudioManager:loadSFXSet(game_type, theme)
    theme = theme or "default"
    local set_key = (game_type or "none") .. ":" .. theme

    if self.sfx_sets[set_key] then
        return set_key
    end

    local pack = {}
    local total = 0

    -- Layer 1: shared/default (base sounds every game gets)
    total = total + self:_loadSoundsFromFolder(SFX_BASE .. "/shared/default", pack)

    -- Layer 2: shared/{theme} (themed overrides, e.g. circus/hit replaces default/hit)
    if theme ~= "default" then
        total = total + self:_loadSoundsFromFolder(SFX_BASE .. "/shared/" .. theme, pack)
    end

    -- Layer 3: games/{game_type} (game-specific sounds, highest priority)
    if game_type then
        total = total + self:_loadSoundsFromFolder(SFX_BASE .. "/games/" .. game_type, pack)
    end

    self.sfx_sets[set_key] = pack
    if total > 0 then
        print(string.format("[AudioManager] Loaded SFX set '%s': %d sounds", set_key, total))
    end

    return set_key
end

-- Play a sound from a loaded SFX set
function AudioManager:playSound(set_key, action, volume_override)
    if not set_key or not action then return end

    local pack = self.sfx_sets[set_key]
    if not pack then return end

    local source = pack[action]
    if not source then return end

    local master_volume = (self.settings and self.settings:get('master_volume')) or 0.8
    local sfx_volume = (self.settings and self.settings:get('sfx_volume')) or 0.7
    local final_volume = master_volume * sfx_volume * (volume_override or 1.0)

    local ok, err = pcall(function()
        local clone = source:clone()
        clone:setVolume(final_volume)
        clone:setPitch(0.95 + math.random() * 0.1)
        clone:play()
    end)

    if not ok then
        print("[AudioManager] Failed to play sound: " .. tostring(err))
    end
end

-- Load music track
function AudioManager:loadMusic(file_path)
    if not file_path then return nil end

    if self.music[file_path] then
        return self.music[file_path]
    end

    local ok, source = pcall(function()
        return love.audio.newSource(file_path, "stream")
    end)

    if ok and source then
        source:setLooping(true)
        self.music[file_path] = source
        print("[AudioManager] Loaded music: " .. file_path)
        return source
    else
        self.music[file_path] = nil
        return nil
    end
end

-- Play music track
function AudioManager:playMusic(file_path, fade_duration)
    if not file_path then return end

    local source = self.music[file_path] or self:loadMusic(file_path)
    if not source then return end

    if self.current_music_source and self.current_music_source:isPlaying() then
        self.current_music_source:stop()
    end

    local master_volume = (self.settings and self.settings:get('master_volume')) or 0.8
    local music_volume = (self.settings and self.settings:get('music_volume')) or 0.6
    source:setVolume(master_volume * music_volume)

    local ok, err = pcall(function() source:play() end)
    if ok then
        self.current_music = file_path
        self.current_music_source = source
    end
end

-- Stop current music
function AudioManager:stopMusic()
    if self.current_music_source and self.current_music_source:isPlaying() then
        self.current_music_source:stop()
    end
    self.current_music = nil
    self.current_music_source = nil
end

-- Update volume for currently playing music (called when settings change)
function AudioManager:updateMusicVolume()
    if self.current_music_source then
        local master_volume = (self.settings and self.settings:get('master_volume')) or 0.8
        local music_volume = (self.settings and self.settings:get('music_volume')) or 0.6
        self.current_music_source:setVolume(master_volume * music_volume)
    end
end

-- Cleanup
function AudioManager:cleanup()
    self:stopMusic()
    self.sfx_sets = {}
    self.music = {}
end

return AudioManager
