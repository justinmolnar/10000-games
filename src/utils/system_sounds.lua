local Object = require('class')
local json = require('json')
local SystemSounds = Object:extend('SystemSounds')

local SCHEMES_DIR = "assets/audio/data/sound_schemes"

function SystemSounds:init(di)
    self.di = di
    self.settings = di and di.settingsManager
    self.event_bus = di and di.eventBus

    self.schemes = {}
    self.active_scheme = nil
    self.sounds = {}

    self.shutting_down = false
    self.shutdown_source = nil

    self:scanSchemes()

    local scheme_name = (self.settings and self.settings.get('sound_scheme')) or 'default'
    self:setScheme(scheme_name)

    self:subscribeEvents()

    print("[SystemSounds] Initialized with scheme: " .. scheme_name)
end

function SystemSounds:scanSchemes()
    self.schemes = {}
    local ok, items = pcall(love.filesystem.getDirectoryItems, SCHEMES_DIR)
    if not ok or not items then
        print("[SystemSounds] Could not read schemes directory: " .. SCHEMES_DIR)
        return
    end

    for _, filename in ipairs(items) do
        local id = filename:match("^(.+)%.json$")
        if id then
            local file_path = SCHEMES_DIR .. "/" .. filename
            local read_ok, contents = pcall(love.filesystem.read, file_path)
            if read_ok and contents then
                local decode_ok, data = pcall(json.decode, contents)
                if decode_ok and data and data.sounds then
                    self.schemes[id] = data
                end
            end
        end
    end

    local count = 0
    for _ in pairs(self.schemes) do count = count + 1 end
    print("[SystemSounds] Found " .. count .. " sound schemes")
end

function SystemSounds:getAvailableSchemes()
    local list = {}
    for id, scheme in pairs(self.schemes) do
        table.insert(list, { id = id, name = scheme.name or id })
    end
    table.sort(list, function(a, b)
        if a.id == 'default' then return true end
        if b.id == 'default' then return false end
        return a.name < b.name
    end)
    return list
end

function SystemSounds:setScheme(scheme_name)
    local scheme = self.schemes[scheme_name]
    if not scheme then
        print("[SystemSounds] Scheme not found: " .. tostring(scheme_name))
        self.sounds = {}
        self.active_scheme = nil
        return
    end

    self.active_scheme = scheme_name
    self.sounds = {}

    local loaded, missing = 0, 0
    for key, file_path in pairs(scheme.sounds or {}) do
        local ok, source = pcall(function()
            return love.audio.newSource(file_path, "static")
        end)
        if ok and source then
            self.sounds[key] = source
            loaded = loaded + 1
        else
            self.sounds[key] = nil
            missing = missing + 1
        end
    end

    print(string.format("[SystemSounds] Loaded scheme '%s': %d sounds (%d missing)", scheme_name, loaded, missing))
end

function SystemSounds:getVolume()
    local master = (self.settings and self.settings.get('master_volume')) or 0.8
    local sfx = (self.settings and self.settings.get('sfx_volume')) or 0.7
    return master * sfx
end

function SystemSounds:playSystemSound(sound_name)
    if self.shutting_down then return nil end

    local source = self.sounds[sound_name]
    if not source then return nil end

    local ok, clone = pcall(source.clone, source)
    if not ok or not clone then return nil end

    clone:setVolume(self:getVolume())
    local play_ok = pcall(clone.play, clone)
    if play_ok then
        return clone
    end
    return nil
end

function SystemSounds:beginShutdown()
    if self.shutting_down then return true end

    local source = self.sounds['shutdown']
    if not source then
        return false
    end

    local ok, clone = pcall(source.clone, source)
    if not ok or not clone then
        return false
    end

    clone:setVolume(self:getVolume())
    local play_ok = pcall(clone.play, clone)
    if not play_ok then
        return false
    end

    self.shutting_down = true
    self.shutdown_source = clone
    return true
end

function SystemSounds:update(dt)
    if not self.shutting_down then return end
    if not self.shutdown_source then
        _G.APP_ALLOW_QUIT = true
        love.event.quit()
        return
    end

    local ok, playing = pcall(self.shutdown_source.isPlaying, self.shutdown_source)
    if not ok or not playing then
        _G.APP_ALLOW_QUIT = true
        love.event.quit()
    end
end

function SystemSounds:subscribeEvents()
    if not self.event_bus then return end

    self.event_bus:subscribe('window_opened', function()
        self:playSystemSound('window_open')
    end)

    self.event_bus:subscribe('window_closed', function()
        self:playSystemSound('window_close')
    end)

    self.event_bus:subscribe('window_maximized', function()
        self:playSystemSound('window_maximize')
    end)

    self.event_bus:subscribe('window_minimized', function()
        self:playSystemSound('window_minimize')
    end)

    self.event_bus:subscribe('window_restored', function()
        self:playSystemSound('window_restore')
    end)

    self.event_bus:subscribe('start_menu_opened', function()
        self:playSystemSound('menu_open')
    end)

    self.event_bus:subscribe('start_menu_closed', function()
        self:playSystemSound('menu_command')
    end)
end

return SystemSounds
