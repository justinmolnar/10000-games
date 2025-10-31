-- src/models/demo_recorder.lua: Records gameplay inputs with frame numbers for demo playback

local Object = require('class')
local DemoRecorder = Object:extend('DemoRecorder')

function DemoRecorder:init(di)
    self.event_bus = di and di.eventBus
    self.config = di and di.config or require('src.config')

    -- Recording state
    self.is_recording = false
    self.frame_count = 0
    self.inputs = {}
    self.game_id = nil
    self.variant_config = nil
    self.start_time = nil
end

-- Start recording a new demo
function DemoRecorder:startRecording(game_id, variant_config)
    if self.is_recording then
        print("Warning: Already recording a demo. Call stopRecording() first.")
        return false
    end

    self.is_recording = true
    self.frame_count = 0
    self.inputs = {}
    self.game_id = game_id
    self.variant_config = variant_config or {}
    self.start_time = os.date("!%Y-%m-%dT%H:%M:%SZ")

    -- Emit event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'demo_recording_started', game_id)
    end

    return true
end

-- Stop recording and return demo data
function DemoRecorder:stopRecording(demo_name, description)
    if not self.is_recording then
        print("Warning: Not currently recording a demo.")
        return nil
    end

    -- Validate recording
    if self.frame_count < (self.config.vm_demo and self.config.vm_demo.min_demo_frames or 60) then
        print("Warning: Demo too short (" .. self.frame_count .. " frames). Minimum: " .. (self.config.vm_demo and self.config.vm_demo.min_demo_frames or 60))
        self:cancelRecording()
        return nil
    end

    -- Allow demos with no inputs (for testing idle behavior, etc.)
    if #self.inputs == 0 then
        print("Info: Demo has no inputs recorded (idle demo)")
    end

    -- Build demo data structure
    local demo = {
        game_id = self.game_id,
        variant_config = self.variant_config,
        recording = {
            inputs = self.inputs,
            total_frames = self.frame_count,
            fixed_dt = self.config.vm_demo and self.config.vm_demo.fixed_dt or (1/60),
            recorded_at = self.start_time
        },
        metadata = {
            demo_name = demo_name or (self.game_id .. " Demo"),
            description = description or "",
            version = 1
        }
    }

    -- Reset state
    self.is_recording = false
    self.frame_count = 0
    self.inputs = {}

    -- Emit event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'demo_recording_completed', self.game_id, demo)
    end

    return demo
end

-- Cancel recording without saving
function DemoRecorder:cancelRecording()
    if not self.is_recording then
        return
    end

    local game_id = self.game_id

    self.is_recording = false
    self.frame_count = 0
    self.inputs = {}
    self.game_id = nil
    self.variant_config = nil

    -- Emit event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'demo_recording_cancelled', game_id)
    end
end

-- Called every fixed timestep update
function DemoRecorder:fixedUpdate()
    if not self.is_recording then
        return
    end

    self.frame_count = self.frame_count + 1

    -- Check max frames limit
    local max_frames = self.config.vm_demo and self.config.vm_demo.max_demo_frames or 18000
    if self.frame_count >= max_frames then
        return self:stopRecording("Auto-saved Demo", "Recording stopped at frame limit")
    end
end

-- Record a key press
function DemoRecorder:recordKeyPressed(key)
    if not self.is_recording then
        return
    end

    table.insert(self.inputs, {
        key = key,
        state = "pressed",
        frame = self.frame_count
    })
end

-- Record a key release
function DemoRecorder:recordKeyReleased(key)
    if not self.is_recording then
        return
    end

    table.insert(self.inputs, {
        key = key,
        state = "released",
        frame = self.frame_count
    })
end

-- Getters
function DemoRecorder:isRecording()
    return self.is_recording
end

function DemoRecorder:getCurrentFrame()
    return self.frame_count
end

function DemoRecorder:getInputCount()
    return #self.inputs
end

return DemoRecorder
