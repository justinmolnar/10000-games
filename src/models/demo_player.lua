-- src/models/demo_player.lua: Plays back recorded demos with frame-perfect precision

local Object = require('class')
local DemoPlayer = Object:extend('DemoPlayer')

function DemoPlayer:init(di)
    self.event_bus = di and di.eventBus
    self.config = di and di.config or require('src.config')

    -- Playback state
    self.is_playing = false
    self.demo = nil
    self.playback_frame = 0
    self.input_index = 1
    self.game_instance = nil
    self.speed_multiplier = 1
    self.headless_mode = false

    -- Wall clock timer for 60 FPS
    self.last_step_time = 0
end

-- Start playing a demo
function DemoPlayer:startPlayback(demo, game_instance, speed_multiplier, headless_mode)
    if not demo or not demo.recording or not demo.recording.inputs then
        print("Error: Invalid demo data for playback")
        return false
    end

    if not game_instance then
        print("Error: No game instance provided for demo playback")
        return false
    end

    self.is_playing = true
    self.demo = demo
    self.playback_frame = 0
    self.input_index = 1
    self.game_instance = game_instance
    self.speed_multiplier = speed_multiplier or 1
    self.headless_mode = headless_mode or false

    -- Reset wall clock timer
    self.last_step_time = love.timer.getTime()
    self.total_steps = 0
    self.start_time = love.timer.getTime()

    -- Emit event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'demo_playback_started', demo.game_id, demo.metadata.demo_name)
    end

    return true
end

-- Stop playback and return results
function DemoPlayer:stopPlayback()
    if not self.is_playing then
        return nil
    end

    local result = {
        completed = self.game_instance and self.game_instance.completed or false,
        frames_played = self.playback_frame,
        demo_name = self.demo.metadata.demo_name,
        game_id = self.demo.game_id
    }

    -- Get game results if available
    if self.game_instance and self.game_instance.getResults then
        local game_results = self.game_instance:getResults()
        if game_results then
            result.tokens = game_results.tokens or 0
            result.metrics = game_results.metrics or {}
        end
    end

    -- Emit event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'demo_playback_completed', self.demo.game_id, result)
    end

    self.is_playing = false
    self.demo = nil
    self.playback_frame = 0
    self.input_index = 1
    self.game_instance = nil
    self.last_step_time = 0

    return result
end

-- Update playback (multi-step mode with rendering)
-- FIXED: This now properly handles variable frame rates by accumulating time
-- and taking multiple steps per frame if needed to maintain 60 FPS playback
function DemoPlayer:update(dt)
    if not self.is_playing or not self.game_instance then
        return
    end

    -- Headless mode: run to completion immediately
    if self.headless_mode then
        return self:runHeadless()
    end

    -- Accumulate real time and step at fixed 60 FPS intervals
    local current_time = love.timer.getTime()
    local time_since_last = current_time - self.last_step_time
    
    -- Calculate how many 60 FPS frames have elapsed
    local steps_to_take = math.floor(time_since_last / (1/60))
    
    if steps_to_take > 0 then
        -- Take the calculated number of steps
        for i = 1, steps_to_take do
            if not self:isComplete() then
                self:stepFrame()
                self.total_steps = self.total_steps + 1
            else
                break
            end
        end
        
        -- Update the last step time by the actual time consumed
        -- This prevents time drift over long playback sessions
        self.last_step_time = self.last_step_time + (steps_to_take * (1/60))
    end
end

-- Single frame step (injects inputs and updates game)
function DemoPlayer:stepFrame()
    if not self.is_playing or not self.game_instance or self:isComplete() then
        return
    end

    -- Inject all inputs scheduled for this frame
    while self.input_index <= #self.demo.recording.inputs do
        local input = self.demo.recording.inputs[self.input_index]

        if input.frame == self.playback_frame then
            self:injectInput(input)
            self.input_index = self.input_index + 1
        else
            break
        end
    end

    -- Run one fixed update on the game
    if self.game_instance.fixedUpdate then
        self.game_instance:fixedUpdate(self.demo.recording.fixed_dt or (1/60))
    end

    self.playback_frame = self.playback_frame + 1
end

-- Headless mode: run demo to completion as fast as possible
function DemoPlayer:runHeadless()
    if not self.is_playing or not self.game_instance then
        return nil
    end

    while not self:isComplete() do
        self:stepFrame()
    end

    return self:stopPlayback()
end

-- Inject an input into the game instance
function DemoPlayer:injectInput(input)
    if not self.game_instance then
        return
    end

    if input.state == "pressed" then
        if self.game_instance.keypressed then
            self.game_instance:keypressed(input.key)
        end
    elseif input.state == "released" then
        if self.game_instance.keyreleased then
            self.game_instance:keyreleased(input.key)
        end
    end
end

-- Check if playback is complete
function DemoPlayer:isComplete()
    if not self.is_playing or not self.game_instance then
        return true
    end

    -- Game completed
    if self.game_instance.completed then
        if self.total_steps then
            local elapsed = love.timer.getTime() - self.start_time
            local actual_fps = self.total_steps / elapsed
            print(string.format("[DemoPlayer] Game completed at frame %d: %d steps in %.2fs = %.1f FPS",
                self.playback_frame, self.total_steps, elapsed, actual_fps))
        end
        return true
    end

    -- Exceeded demo frame count
    if self.playback_frame >= self.demo.recording.total_frames then
        if self.total_steps then
            local elapsed = love.timer.getTime() - self.start_time
            local actual_fps = self.total_steps / elapsed
            print(string.format("[DemoPlayer] Reached end at frame %d: %d steps in %.2fs = %.1f FPS",
                self.playback_frame, self.total_steps, elapsed, actual_fps))
        end
        return true
    end

    return false
end

-- Getters
function DemoPlayer:isPlaying()
    return self.is_playing
end

function DemoPlayer:getCurrentFrame()
    return self.playback_frame
end

function DemoPlayer:getTotalFrames()
    return self.demo and self.demo.recording.total_frames or 0
end

function DemoPlayer:getProgress()
    local total = self:getTotalFrames()
    if total == 0 then
        return 0
    end
    return self.playback_frame / total
end

return DemoPlayer