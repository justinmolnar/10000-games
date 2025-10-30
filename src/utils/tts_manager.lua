local Object = require('class')
local TTSManager = Object:extend('TTSManager')

function TTSManager:init(config)
    self.config = config or {}
    self.enabled = self.config.enabled ~= false  -- Default to enabled
    self.rate = self.config.rate or 0  -- Speech rate: -10 to 10 (0 = normal, negative = slower, positive = faster)
    self.volume = self.config.volume or 100  -- Volume: 0-100
    self.use_audio_effects = self.config.use_audio_effects ~= false  -- Generate to WAV for effects
    self.voice_name = self.config.voice_name or nil  -- Specific SAPI voice name (nil = default)

    -- Detect OS
    self.os_type = self:detectOS()

    -- Queue for TTS requests (to avoid overlapping speech)
    self.queue = {}
    self.is_speaking = false

    -- Audio effects cache
    self.audio_cache = {}  -- Cache generated audio sources
    self.current_source = nil  -- Currently playing source

    print("[TTSManager] Initialized for OS: " .. self.os_type)
    if self.use_audio_effects then
        print("[TTSManager] Audio effects mode enabled - TTS will be generated to WAV files")
    end
end

function TTSManager:detectOS()
    local handle = io.popen("uname -s 2>/dev/null || echo Windows")
    local result = handle:read("*a")
    handle:close()

    if result:match("Darwin") then
        return "macos"
    elseif result:match("Linux") then
        return "linux"
    else
        return "windows"
    end
end

function TTSManager:speak(text, options)
    if not self.enabled or not text or text == "" then
        print("[TTSManager] TTS disabled or empty text")
        return
    end

    options = options or {}
    local rate = options.rate or self.rate
    local volume = options.volume or self.volume
    local pitch = options.pitch or 1.0  -- Pitch multiplier for audio effects (0.5-2.0)
    local voice = options.voice or self.voice_name

    -- Clean the text (remove file extensions, underscores, etc)
    local clean_text = text
    clean_text = clean_text:gsub("%.png$", "")
    clean_text = clean_text:gsub("%.jpg$", "")
    clean_text = clean_text:gsub("_", " ")
    clean_text = clean_text:gsub("-", " ")

    print(string.format("[TTSManager] Speaking: '%s' (rate=%d, volume=%d, pitch=%.2f)", clean_text, rate, volume, pitch))

    if self.use_audio_effects then
        -- Generate to WAV and play with effects
        self:speakWithEffects(clean_text, rate, volume, pitch, voice)
    else
        -- Direct speech (legacy mode)
        local command = self:buildCommand(clean_text, rate, volume, voice)
        if command then
            print("[TTSManager] Command: " .. command)
            self:executeAsync(command)
        else
            print("[TTSManager] Failed to build command")
        end
    end
end

function TTSManager:speakWithEffects(text, rate, volume, pitch, voice)
    -- Generate TTS to WAV file, then play through LÖVE audio with effects
    local wav_file = self:generateToWav(text, rate, voice)

    if not wav_file then
        print("[TTSManager] Failed to generate WAV file")
        return
    end

    -- Stop any currently playing TTS
    if self.current_source then
        self.current_source:stop()
        self.current_source = nil
    end

    -- Load WAV as audio source
    local success, source = pcall(love.audio.newSource, wav_file, "static")
    if not success or not source then
        print("[TTSManager] Failed to load WAV as audio source: " .. tostring(source))
        return
    end

    -- Apply pitch shift (via setPitch in LÖVE)
    source:setPitch(pitch)

    -- Apply volume
    source:setVolume(volume / 100)

    -- Play
    source:play()
    self.current_source = source

    print(string.format("[TTSManager] Playing TTS with pitch=%.2f, volume=%.2f", pitch, volume / 100))
end

function TTSManager:generateToWav(text, rate, voice)
    -- Generate TTS to a WAV file and return the path
    text = text:gsub('"', '""')  -- VBScript uses double-double quotes

    if self.os_type == "windows" then
        local temp_dir = os.getenv("TEMP")
        local wav_file = temp_dir .. "\\tts_output.wav"
        local vbs_file = temp_dir .. "\\tts_gen.vbs"

        -- Build VBScript to generate WAV
        local voice_line = voice and string.format('speech.Voice = speech.GetVoices("Name=%s").Item(0)', voice) or ""
        local vbs_script = string.format(
            [[Set speech = CreateObject("SAPI.SpVoice")
Set stream = CreateObject("SAPI.SpFileStream")
%s
speech.Rate = %d
stream.Open "%s", 3
Set speech.AudioOutputStream = stream
speech.Speak "%s"
stream.Close]],
            voice_line, rate, wav_file, text
        )

        -- Write and execute VBS
        local file, err = io.open(vbs_file, "w")
        if not file then
            print("[TTSManager] Failed to write VBS file: " .. tostring(err))
            return nil
        end

        file:write(vbs_script)
        file:close()

        -- Execute synchronously (wait for completion)
        local result = os.execute(string.format('wscript //Nologo "%s"', vbs_file))

        -- Check if WAV was created
        local wav_check = io.open(wav_file, "r")
        if wav_check then
            wav_check:close()
            return wav_file
        else
            print("[TTSManager] WAV file was not created")
            return nil
        end
    end

    return nil
end

function TTSManager:buildCommand(text, rate, volume, voice)
    -- Escape quotes in text
    text = text:gsub('"', '""')  -- VBScript uses double-double quotes

    if self.os_type == "windows" then
        -- Windows VBScript TTS (much faster startup than PowerShell)
        -- Rate: -10 to 10 (default 0)
        -- Volume: 0 to 100 (default 100)
        -- Create a temporary VBS file for instant speech
        local temp_file = os.getenv("TEMP") .. "\\tts_temp.vbs"
        local voice_line = voice and string.format('speech.Voice = speech.GetVoices("Name=%s").Item(0)', voice) or ""
        local vbs_script = string.format(
            [[Set speech = CreateObject("SAPI.SpVoice")
%s
speech.Rate = %d
speech.Volume = %d
speech.Speak "%s"]],
            voice_line, rate, volume, text
        )

        -- Write VBS file and execute
        local file, err = io.open(temp_file, "w")
        if file then
            file:write(vbs_script)
            file:close()
            -- Use synchronous speech (no flag = 0) so wscript waits for completion
            return string.format('start /B wscript //Nologo "%s"', temp_file)
        else
            print("[TTSManager] Failed to write VBS file: " .. tostring(err))
        end
        return nil

    elseif self.os_type == "macos" then
        -- macOS 'say' command
        -- Rate: words per minute (default 175, range 90-720)
        local wpm = 175 + (rate * 20)  -- Map -10..10 to ~75..375 wpm
        return string.format('say -r %d "%s" &', wpm, text)

    elseif self.os_type == "linux" then
        -- Linux espeak (if available)
        -- Rate: 80-450 words per minute (default 175)
        -- Pitch: 0-99 (default 50)
        local wpm = 175 + (rate * 20)
        return string.format('espeak -s %d -v en "%s" 2>/dev/null &', wpm, text)
    end

    return nil
end

function TTSManager:executeAsync(command)
    -- Execute command in background without blocking
    local success, err = pcall(function()
        os.execute(command)
    end)

    if not success then
        print("[TTSManager] Failed to execute TTS command: " .. tostring(err))
    else
        print("[TTSManager] Command executed successfully")
    end
end

-- Weird/distorted voice presets
function TTSManager:speakWeird(text, weirdness)
    weirdness = weirdness or 1  -- 0 = normal, 1-5 = various weird effects

    local options = {}

    if self.use_audio_effects then
        -- With audio effects: use pitch shifting
        if weirdness == 0 then
            options.rate = 0
            options.pitch = 1.0
        elseif weirdness == 1 then
            options.rate = 3
            options.pitch = 1.3
        elseif weirdness == 2 then
            options.rate = 7
            options.pitch = 1.6
        elseif weirdness == 3 then
            options.rate = -5
            options.pitch = 0.7
        elseif weirdness == 4 then
            options.rate = 0
            options.pitch = 0.5
        elseif weirdness == 5 then
            options.rate = -8
            options.pitch = 0.4
        end
    else
        -- Without audio effects: only use rate (speed)
        if weirdness == 0 then
            options.rate = 0
        elseif weirdness == 1 then
            options.rate = 5
        elseif weirdness == 2 then
            options.rate = 8
        elseif weirdness == 3 then
            options.rate = -5
        elseif weirdness == 4 then
            options.rate = 2
        elseif weirdness == 5 then
            options.rate = -8
        end
    end

    self:speak(text, options)
end

-- List available SAPI voices (Windows only)
function TTSManager:listVoices()
    if self.os_type ~= "windows" then
        print("[TTSManager] Voice listing only supported on Windows")
        return {}
    end

    local temp_file = os.getenv("TEMP") .. "\\tts_list_voices.vbs"
    local output_file = os.getenv("TEMP") .. "\\tts_voices.txt"

    local vbs_script = [[Set speech = CreateObject("SAPI.SpVoice")
Set voices = speech.GetVoices()
Set fso = CreateObject("Scripting.FileSystemObject")
Set file = fso.CreateTextFile("]] .. output_file .. [[", True)
For Each voice in voices
    file.WriteLine voice.GetDescription()
Next
file.Close]]

    local file = io.open(temp_file, "w")
    if file then
        file:write(vbs_script)
        file:close()
        os.execute(string.format('wscript //Nologo "%s"', temp_file))

        -- Read voices
        local voices = {}
        local voice_file = io.open(output_file, "r")
        if voice_file then
            for line in voice_file:lines() do
                table.insert(voices, line)
            end
            voice_file:close()
        end

        print("[TTSManager] Available voices:")
        for i, voice in ipairs(voices) do
            print(string.format("  %d. %s", i, voice))
        end

        return voices
    end

    return {}
end

function TTSManager:enable()
    self.enabled = true
    print("[TTSManager] TTS enabled")
end

function TTSManager:disable()
    self.enabled = false
    print("[TTSManager] TTS disabled")
end

function TTSManager:isEnabled()
    return self.enabled
end

return TTSManager
