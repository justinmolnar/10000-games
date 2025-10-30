-- src/models/vm_manager.lua: Manages virtual machines for automated demo playback

local Object = require('class')
local Config = {} -- Will be set from DI in init
local VMManager = Object:extend('VMManager')

function VMManager:init(di)
    -- Store DI container
    self.di = di

    -- Optional DI for config
    if di and di.config then Config = di.config end
    self.event_bus = di and di.eventBus
    self.game_data = di and di.gameData
    self.player_data = di and di.playerData

    self.vm_slots = {}
    self.total_tokens_per_minute = 0
    self.max_slots = Config.vm_max_slots or 10

    -- Restart delay between runs
    self.restart_delay = (Config.vm_demo and Config.vm_demo.restart_delay) or 0.1
end

function VMManager:initialize(player_data)
    self.vm_slots = {}
    self.player_data = player_data -- Store reference

    -- Create slots based on player's purchased VM count
    for i = 1, player_data.vm_slots do
        table.insert(self.vm_slots, self:createEmptySlot(i))

        -- Publish vm_created event for initial slots
        if self.event_bus then
            pcall(self.event_bus.publish, self.event_bus, 'vm_created', i)
        end
    end

    if not player_data.active_vms then player_data.active_vms = {} end

    -- Restore active VM assignments
    for slot_index_str, vm_data in pairs(player_data.active_vms) do
        local slot_index = tonumber(slot_index_str)
        if slot_index and self.vm_slots[slot_index] and vm_data.game_id and vm_data.demo_id then
            local success = self:restoreVMSlot(slot_index, vm_data, player_data)
            if not success then
                print("Warning: Could not restore VM slot " .. slot_index)
                player_data.active_vms[slot_index_str] = nil
            end
        elseif slot_index then
            print("Warning: Invalid VM save data for slot " .. slot_index)
            player_data.active_vms[slot_index_str] = nil
        end
    end

    print("VM Manager initialized with " .. #self.vm_slots .. " slots")
end

-- Create an empty VM slot structure
function VMManager:createEmptySlot(slot_index)
    return {
        slot_index = slot_index,
        state = "IDLE", -- IDLE, RUNNING, RESTARTING, STOPPED
        assigned_game_id = nil,
        assigned_demo_id = nil,
        demo_player = nil,
        game_instance = nil,

        speed_upgrade_level = 0,
        speed_multiplier = 1,
        headless_mode = false,

        stats = {
            total_runs = 0,
            successes = 0,
            failures = 0,
            total_tokens = 0,
            uptime = 0,
            tokens_per_minute = 0,
            last_run_tokens = 0,
            last_run_success = false,
        },

        current_run = {
            start_frame = 0,
            current_frame = 0,
            seed = 0,
            start_time = 0,
        },

        restart_timer = 0,
    }
end

-- Restore a VM slot from save data
function VMManager:restoreVMSlot(slot_index, vm_data, player_data)
    local slot = self.vm_slots[slot_index]
    if not slot then return false end

    -- Verify demo exists
    local demo = player_data:getDemo(vm_data.demo_id)
    if not demo then
        print("Warning: Demo not found: " .. vm_data.demo_id)
        return false
    end

    -- Restore slot data
    slot.assigned_game_id = vm_data.game_id
    slot.assigned_demo_id = vm_data.demo_id
    slot.speed_upgrade_level = vm_data.speed_upgrade_level or 0
    slot.speed_multiplier = vm_data.speed_multiplier or 1
    slot.headless_mode = vm_data.headless_mode or false

    -- Restore stats
    if vm_data.stats then
        slot.stats.total_runs = vm_data.stats.total_runs or 0
        slot.stats.successes = vm_data.stats.successes or 0
        slot.stats.failures = vm_data.stats.failures or 0
        slot.stats.total_tokens = vm_data.stats.total_tokens or 0
        slot.stats.uptime = vm_data.stats.uptime or 0
    end

    -- Start the VM (will create game instance and demo player)
    slot.state = "RESTARTING" -- Will transition to RUNNING on next update
    slot.restart_timer = 0


    -- Publish vm_started event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'vm_started', slot.slot_index, slot.assigned_game_id)
    end

    return true
end

function VMManager:update(dt, player_data, game_data)
    local tokens_generated = 0

    for _, slot in ipairs(self.vm_slots) do
        if slot.state == "IDLE" then
            -- Do nothing

        elseif slot.state == "RUNNING" then
            tokens_generated = tokens_generated + self:updateRunningSlot(slot, dt, player_data, game_data)

        elseif slot.state == "RESTARTING" then
            self:updateRestartingSlot(slot, dt, player_data, game_data)

        elseif slot.state == "STOPPED" then
            -- Do nothing (manually paused)
        end
    end

    if tokens_generated > 0 then
        player_data:addTokens(tokens_generated)
    end

    self:calculateTokensPerMinute()
end

-- Update a running VM slot
function VMManager:updateRunningSlot(slot, dt, player_data, game_data)
    local tokens = 0

    -- Update uptime
    slot.stats.uptime = slot.stats.uptime + dt

    -- Debug: Track update frequency
    if not slot.debug_frame_count then
        slot.debug_frame_count = 0
        slot.debug_start_time = love.timer.getTime()
        slot.last_step_time = love.timer.getTime()
    end
    slot.debug_frame_count = slot.debug_frame_count + 1


    if slot.headless_mode then
        -- Headless: run to completion instantly
        if slot.demo_player and slot.demo_player:isPlaying() then
            local result = slot.demo_player:runHeadless()
            if result then
                tokens = self:processRunResult(slot, result, player_data)
                self:transitionToRestarting(slot)
            end
        end
    else
        -- Multi-step rendering mode
        if slot.demo_player and slot.demo_player:isPlaying() then
            slot.demo_player:update(dt)

            -- Check if run completed
            if slot.demo_player:isComplete() then
                local result = slot.demo_player:stopPlayback()
                if result then
                    tokens = self:processRunResult(slot, result, player_data)
                    self:transitionToRestarting(slot)
                end
            end
        end
    end

    return tokens
end

-- Update a restarting VM slot
function VMManager:updateRestartingSlot(slot, dt, player_data, game_data)
    slot.restart_timer = slot.restart_timer + dt

    if slot.restart_timer >= self.restart_delay then
        -- Create new game instance and start playback
        local success = self:startNewRun(slot, player_data, game_data)
        if success then
            slot.state = "RUNNING"
            slot.restart_timer = 0
        else
            -- Failed to start, go idle
            print("Warning: Failed to start VM run for slot " .. slot.slot_index)
            slot.state = "IDLE"
        end
    end
end

-- Start a new demo run
function VMManager:startNewRun(slot, player_data, game_data)
    if not slot.assigned_demo_id or not slot.assigned_game_id then
        return false
    end

    -- Get demo
    local demo = player_data:getDemo(slot.assigned_demo_id)
    if not demo then
        print("Error: Demo not found: " .. slot.assigned_demo_id)
        return false
    end

    -- Debug: Check demo data
    print("[VMManager] Starting demo playback:")
    print("  Demo ID: " .. slot.assigned_demo_id)
    print("  Demo name: " .. (demo.metadata and demo.metadata.demo_name or "unknown"))
    print("  Total frames: " .. (demo.recording and demo.recording.total_frames or 0))
    print("  Input count: " .. (demo.recording and demo.recording.inputs and #demo.recording.inputs or 0))

    -- Create game instance
    local game_instance = self:createGameInstance(slot.assigned_game_id, demo, game_data, player_data, slot.slot_index)
    if not game_instance then
        print("Error: Failed to create game instance for " .. slot.assigned_game_id)
        return false
    end

    -- Create demo player if needed
    if not slot.demo_player then
        local DemoPlayer = require('src.models.demo_player')
        slot.demo_player = DemoPlayer:new(self.di)
    end

    -- Start playback
    local success = slot.demo_player:startPlayback(demo, game_instance, slot.speed_multiplier, slot.headless_mode)
    if not success then
        print("Error: Failed to start demo playback")
        return false
    end

    slot.game_instance = game_instance
    slot.current_run.start_frame = 0
    slot.current_run.current_frame = 0
    slot.current_run.seed = game_instance.seed or 0
    slot.current_run.start_time = os.time()

    print(string.format("  Speed multiplier: %dx, Headless: %s, Game completed: %s",
        slot.speed_multiplier, tostring(slot.headless_mode), tostring(game_instance.completed)))

    return true
end

-- Create a game instance for demo playback
function VMManager:createGameInstance(game_id, demo, game_data, player_data, slot_index)
    local game_def = game_data:getGame(game_id)
    if not game_def then
        return nil
    end

    -- Dynamically load the game class (same pattern as MinigameState)
    local class_name = game_def.game_class
    local logic_file_name = class_name:gsub("([a-z])([A-Z])", "%1_%2"):lower()
    local require_path = 'src.games.' .. logic_file_name

    local require_ok, GameClass = pcall(require, require_path)
    if not require_ok or not GameClass then
        print("[VMManager] ERROR: Failed to load game class '" .. require_path .. "': " .. tostring(GameClass))
        return nil
    end

    -- Get active cheats for this game
    local active_cheats = {}
    if player_data and player_data.cheat_engine_data and player_data.cheat_engine_data[game_id] then
        active_cheats = player_data.cheat_engine_data[game_id].cheats or {}
    end

    -- Create game instance with variant config from demo
    local game_instance = GameClass:new(game_def, active_cheats, self.di, demo.variant_config)

    -- Enable playback mode (blocks human input)
    if game_instance.setPlaybackMode then
        game_instance:setPlaybackMode(true)
    end

    -- Set random seed for this run (use slot_index if provided)
    math.randomseed(os.time() + (slot_index or 0))

    return game_instance
end

-- Process run result and update stats
function VMManager:processRunResult(slot, result, player_data)
    slot.stats.total_runs = slot.stats.total_runs + 1

    local tokens = result.tokens or 0
    local success = result.completed or false

    local elapsed_time = love.timer.getTime() - (slot.debug_start_time or 0)
    local game_fps = (result.frames_played or 0) / elapsed_time
    local expected_time = (result.frames_played or 0) / 60
    print(string.format("[VMManager] Run completed - Tokens: %d, Frames: %d | %.1fs real vs %.1fs expected @ 60fps (%.1f actual FPS)",
        tokens, result.frames_played or 0, elapsed_time, expected_time, game_fps))

    -- Reset debug counters
    slot.debug_frame_count = nil
    slot.debug_start_time = nil

    if success then
        slot.stats.successes = slot.stats.successes + 1
    else
        slot.stats.failures = slot.stats.failures + 1
    end

    slot.stats.total_tokens = slot.stats.total_tokens + tokens
    slot.stats.last_run_tokens = tokens
    slot.stats.last_run_success = success

    -- Update tokens per minute
    if slot.stats.total_runs > 0 and slot.stats.uptime > 0 then
        slot.stats.tokens_per_minute = (slot.stats.total_tokens / slot.stats.uptime) * 60
    end

    -- Save VM state
    self:saveSlotState(slot, player_data)

    -- Emit event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'vm_run_completed',
            slot.slot_index, slot.assigned_game_id, tokens, success)
    end

    return tokens
end

-- Transition slot to RESTARTING state
function VMManager:transitionToRestarting(slot)
    slot.state = "RESTARTING"
    slot.restart_timer = 0
    slot.game_instance = nil -- Clean up game instance
end

-- Save VM slot state to player data
function VMManager:saveSlotState(slot, player_data)
    if not player_data.active_vms then
        player_data.active_vms = {}
    end

    if slot.state == "IDLE" then
        -- Remove from save
        player_data.active_vms[tostring(slot.slot_index)] = nil
    else
        -- Save current state
        player_data.active_vms[tostring(slot.slot_index)] = {
            game_id = slot.assigned_game_id,
            demo_id = slot.assigned_demo_id,
            speed_upgrade_level = slot.speed_upgrade_level,
            speed_multiplier = slot.speed_multiplier,
            headless_mode = slot.headless_mode,
            stats = {
                total_runs = slot.stats.total_runs,
                successes = slot.stats.successes,
                failures = slot.stats.failures,
                total_tokens = slot.stats.total_tokens,
                uptime = slot.stats.uptime,
            }
        }
    end
end

-- Assign a demo to a VM slot
function VMManager:assignDemo(slot_index, game_id, demo_id, game_data, player_data)
    if slot_index < 1 or slot_index > #self.vm_slots then
        return false, "Invalid slot index"
    end

    local slot = self.vm_slots[slot_index]

    -- Verify game exists
    local game = game_data:getGame(game_id)
    if not game then
        return false, "Game not found"
    end

    -- Verify demo exists
    local demo = player_data:getDemo(demo_id)
    if not demo then
        return false, "Demo not found"
    end

    -- Verify demo is for this game
    if demo.game_id ~= game_id then
        return false, "Demo does not match game"
    end

    -- Stop current run if active
    if slot.state ~= "IDLE" then
        self:removeDemo(slot_index, player_data)
    end

    -- Assign demo
    slot.assigned_game_id = game_id
    slot.assigned_demo_id = demo_id
    slot.state = "RESTARTING"
    slot.restart_timer = 0

    -- Reset stats
    slot.stats.total_runs = 0
    slot.stats.successes = 0
    slot.stats.failures = 0
    slot.stats.total_tokens = 0
    slot.stats.uptime = 0
    slot.stats.tokens_per_minute = 0

    print(string.format("Assigned demo '%s' to VM slot %d for game %s",
        demo.metadata.demo_name, slot_index, game.display_name))

    -- Save state
    self:saveSlotState(slot, player_data)

    -- Publish vm_started event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'vm_started', slot.slot_index, slot.assigned_game_id)
    end

    return true
end

-- Stop a running VM (keeps assignment, can restart)
function VMManager:stopVM(slot_index, player_data)
    if slot_index < 1 or slot_index > #self.vm_slots then
        return false
    end

    local slot = self.vm_slots[slot_index]

    if slot.state ~= "RUNNING" and slot.state ~= "RESTARTING" then
        return false -- Already stopped
    end

    -- Stop playback
    if slot.demo_player and slot.demo_player:isPlaying() then
        slot.demo_player:stopPlayback()
    end

    -- Transition to IDLE but keep assignment
    slot.state = "IDLE"
    slot.game_instance = nil

    -- Save state
    self:saveSlotState(slot, player_data)

    print("Stopped VM slot " .. slot_index)

    -- Publish vm_stopped event
    if self.event_bus and slot.assigned_game_id then
        pcall(self.event_bus.publish, self.event_bus, 'vm_stopped',
            slot.slot_index, slot.assigned_game_id, 'user_stopped')
    end

    self:calculateTokensPerMinute()
    return true
end

-- Remove demo from VM slot
function VMManager:removeDemo(slot_index, player_data)
    if slot_index < 1 or slot_index > #self.vm_slots then
        return false
    end

    local slot = self.vm_slots[slot_index]
    local old_game_id = slot.assigned_game_id

    -- Stop playback
    if slot.demo_player and slot.demo_player:isPlaying() then
        slot.demo_player:stopPlayback()
    end

    -- Reset slot
    slot.state = "IDLE"
    slot.assigned_game_id = nil
    slot.assigned_demo_id = nil
    slot.demo_player = nil
    slot.game_instance = nil

    -- Save state (will remove from active_vms)
    self:saveSlotState(slot, player_data)

    print("Removed demo from VM slot " .. slot_index)

    -- Publish vm_stopped event
    if self.event_bus and old_game_id then
        pcall(self.event_bus.publish, self.event_bus, 'vm_stopped',
            slot.slot_index, old_game_id, 'user_removed')
    end

    self:calculateTokensPerMinute()
    return true
end

-- Purchase a new VM slot
function VMManager:purchaseVM(player_data)
    if #self.vm_slots >= self.max_slots then
        return false, "Maximum VM slots reached"
    end

    local cost = self:getVMCost(#self.vm_slots)

    if not player_data:hasTokens(cost) then
        return false, "Not enough tokens (" .. cost .. " needed)"
    end

    if player_data:spendTokens(cost) then
        player_data.vm_slots = player_data.vm_slots + 1
        local new_slot_index = player_data.vm_slots

        table.insert(self.vm_slots, self:createEmptySlot(new_slot_index))

        print("Purchased VM slot " .. new_slot_index .. " for " .. cost .. " tokens")

        -- Publish vm_created event
        if self.event_bus then
            pcall(self.event_bus.publish, self.event_bus, 'vm_created', new_slot_index)
        end

        return true
    end

    return false, "Purchase failed (unknown reason)"
end

-- Get VM purchase cost
function VMManager:getVMCost(current_count)
    local effective_count = math.max(0, current_count - 1)
    return math.floor((Config.vm_base_cost or 1000) * math.pow((Config.vm_cost_exponent or 2), effective_count))
end

-- Calculate total tokens per minute across all VMs
function VMManager:calculateTokensPerMinute()
    local total = 0
    for _, slot in ipairs(self.vm_slots) do
        if slot.state ~= "IDLE" then
            total = total + (slot.stats.tokens_per_minute or 0)
        end
    end
    self.total_tokens_per_minute = total
    return total
end

-- Upgrade VM speed
function VMManager:upgradeSpeed(slot_index, new_level, new_multiplier, new_headless)
    if slot_index < 1 or slot_index > #self.vm_slots then
        return false
    end

    local slot = self.vm_slots[slot_index]
    slot.speed_upgrade_level = new_level
    slot.speed_multiplier = new_multiplier
    slot.headless_mode = new_headless

    -- Update demo player if running
    if slot.demo_player then
        slot.demo_player.speed_multiplier = new_multiplier
        slot.demo_player.headless_mode = new_headless
    end

    print(string.format("VM slot %d upgraded to level %d (speed: %dx, headless: %s)",
        slot_index, new_level, new_multiplier, tostring(new_headless)))

    -- Emit event
    if self.event_bus then
        pcall(self.event_bus.publish, self.event_bus, 'vm_speed_upgraded',
            slot_index, new_level, new_multiplier, new_headless)
    end

    return true
end

-- Get VM slot data
function VMManager:getSlot(slot_index)
    return self.vm_slots[slot_index]
end

-- Check if a demo is assigned to any VM
function VMManager:isDemoAssigned(demo_id)
    for _, slot in ipairs(self.vm_slots) do
        if slot.assigned_demo_id == demo_id then
            return true, slot.slot_index
        end
    end
    return false, nil
end

-- Legacy compatibility: check if game is assigned (now checks demo for that game)
function VMManager:isGameAssigned(game_id)
    for _, slot in ipairs(self.vm_slots) do
        if slot.assigned_game_id == game_id then
            return true
        end
    end
    return false
end

function VMManager:getSlotCount()
    return #self.vm_slots
end

function VMManager:getActiveSlotCount()
    local count = 0
    for _, slot in ipairs(self.vm_slots) do
        if slot.state ~= "IDLE" then
            count = count + 1
        end
    end
    return count
end

return VMManager
