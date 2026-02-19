-- FormationSpawner: Stateless functions for timed zone-based attack patterns.
-- Games create a state table, call update each frame, respond to events.
--
-- Usage:
--   local FS = require('src.utils.game_components.formation_spawner')
--   local zones = FS.createColumns(7, 500, 350)
--   local state = FS.newState({zones = zones, interval = 2.5, warn_duration = 1.0})
--   -- In update:
--   local event = FS.update(state, dt)
--   if event and event.type == "warning" then ... end
--   if event and event.type == "attack" then ... end

local FormationSpawner = {}

-- ============================================================================
-- ZONE CREATION
-- ============================================================================

function FormationSpawner.createColumns(count, width, height)
    local zones = {}
    local col_w = width / count
    for i = 1, count do
        zones[i] = {x = (i - 1) * col_w, y = 0, w = col_w, h = height, index = i}
    end
    return zones
end

function FormationSpawner.createRows(count, width, height)
    local zones = {}
    local row_h = height / count
    for i = 1, count do
        zones[i] = {x = 0, y = (i - 1) * row_h, w = width, h = row_h, index = i}
    end
    return zones
end

function FormationSpawner.createGrid(cols, rows, width, height)
    local zones = {}
    local cell_w = width / cols
    local cell_h = height / rows
    local idx = 1
    for r = 1, rows do
        for c = 1, cols do
            zones[idx] = {x = (c - 1) * cell_w, y = (r - 1) * cell_h, w = cell_w, h = cell_h, index = idx}
            idx = idx + 1
        end
    end
    return zones
end

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

function FormationSpawner.newState(config)
    local zone_count = #config.zones
    return {
        zones = config.zones,
        interval = config.interval or 2.5,
        warn_duration = config.warn_duration or 1.0,
        min_safe = config.min_safe or 1,
        escalation_time = config.escalation_time or 30,
        selection_pattern = config.selection_pattern or "random",
        phase = "idle",
        timer = (config.initial_delay ~= nil) and config.initial_delay or (config.interval or 2.5) * 0.5,
        elapsed = 0,
        active_zones = {},
        seq_offset = 0,
        attack_pct_min = config.attack_pct_min or 0.5,
        attack_pct_max = config.attack_pct_max or 0.9,
    }
end

function FormationSpawner.reset(state)
    state.phase = "idle"
    state.timer = state.interval * 0.5
    state.elapsed = 0
    state.active_zones = {}
    state.seq_offset = 0
end

-- ============================================================================
-- ESCALATION
-- ============================================================================

function FormationSpawner.getProgress(state)
    if state.escalation_time <= 0 then return 1 end
    return math.min(1, state.elapsed / state.escalation_time)
end

function FormationSpawner.getScaledInterval(state)
    local p = FormationSpawner.getProgress(state)
    return state.interval * (1 - p * 0.5)
end

function FormationSpawner.getAttackCount(state)
    local p = FormationSpawner.getProgress(state)
    local n = #state.zones
    local pct = state.attack_pct_min + (state.attack_pct_max - state.attack_pct_min) * p
    return math.max(1, math.min(n - 1, math.floor(n * pct + 0.5)))
end

-- ============================================================================
-- ZONE SELECTION
-- ============================================================================

local function selectRandom(state, count)
    local indices = {}
    for i = 1, #state.zones do indices[i] = i end
    for i = #indices, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    local selected = {}
    for i = 1, math.min(count, #indices) do
        selected[i] = state.zones[indices[i]]
    end
    return selected
end

local function selectSequential(state, count)
    local n = #state.zones
    local selected = {}
    for i = 1, math.min(count, n) do
        local idx = ((state.seq_offset + i - 1) % n) + 1
        selected[i] = state.zones[idx]
    end
    state.seq_offset = (state.seq_offset + count) % n
    return selected
end

local function selectSweep(state, count)
    local n = #state.zones
    local selected = {}
    local start = (state.seq_offset % n) + 1
    for i = 0, math.min(count, n) - 1 do
        local idx = ((start - 1 + i) % n) + 1
        selected[i + 1] = state.zones[idx]
    end
    state.seq_offset = state.seq_offset + 1
    return selected
end

function FormationSpawner.selectZones(state, count)
    local pattern = state.selection_pattern or "random"
    if pattern == "sequential" then
        return selectSequential(state, count)
    elseif pattern == "sweep" then
        return selectSweep(state, count)
    else
        return selectRandom(state, count)
    end
end

-- ============================================================================
-- UPDATE (returns event or nil)
-- ============================================================================

function FormationSpawner.update(state, dt)
    state.elapsed = state.elapsed + dt
    state.timer = state.timer - dt

    if state.phase == "idle" then
        if state.timer <= 0 then
            local count = FormationSpawner.getAttackCount(state)
            state.active_zones = FormationSpawner.selectZones(state, count)
            state.phase = "warning"
            state.timer = state.warn_duration
            return {type = "warning", zones = state.active_zones}
        end

    elseif state.phase == "warning" then
        if state.timer <= 0 then
            local zones = state.active_zones
            state.phase = "idle"
            state.timer = FormationSpawner.getScaledInterval(state)
            return {type = "attack", zones = zones}
        end
    end

    return nil
end

return FormationSpawner
