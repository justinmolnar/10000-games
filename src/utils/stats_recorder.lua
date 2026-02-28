local json = require('json')

local StatsRecorder = {}

local STATS_FILE = "balance_stats.json"

-- Pretty-print JSON with indentation for human-readable stats files
local function prettyEncode(val, indent, current)
    indent = indent or "  "
    current = current or ""
    local t = type(val)

    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return tostring(val)
    elseif t == "number" then
        if val ~= val or val <= -math.huge or val >= math.huge then
            return "null"
        end
        return string.format("%.14g", val)
    elseif t == "string" then
        return json.encode(val)
    elseif t == "table" then
        -- Check if array
        local is_array = #val > 0 or next(val) == nil
        if is_array and #val > 0 then
            -- Check first element type to decide inline vs multiline
            local first_type = type(val[1])
            -- Small arrays of primitives stay inline
            if first_type ~= "table" and #val <= 6 then
                local parts = {}
                for i, v in ipairs(val) do
                    parts[i] = prettyEncode(v)
                end
                return "[" .. table.concat(parts, ", ") .. "]"
            end
            -- Array of objects/large arrays get multiline
            local next_indent = current .. indent
            local parts = {}
            for i, v in ipairs(val) do
                parts[i] = next_indent .. prettyEncode(v, indent, next_indent)
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. current .. "]"
        elseif not is_array then
            -- Object
            local next_indent = current .. indent
            local parts = {}
            -- Sort keys for consistent output
            local keys = {}
            for k in pairs(val) do keys[#keys + 1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local v = val[k]
                parts[#parts + 1] = next_indent .. json.encode(k) .. ": " .. prettyEncode(v, indent, next_indent)
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. current .. "}"
        else
            return "[]"
        end
    end
    return "null"
end

function StatsRecorder.loadStats()
    local content = love.filesystem.read(STATS_FILE)
    if not content then return {} end
    local ok, data = pcall(json.decode, content)
    if not ok or type(data) ~= "table" then return {} end
    return data
end

function StatsRecorder.saveStats(stats)
    local ok, encoded = pcall(prettyEncode, stats)
    if not ok then
        print("[StatsRecorder] Encode error: " .. tostring(encoded))
        return false
    end
    local ok2, err = love.filesystem.write(STATS_FILE, encoded)
    if not ok2 then
        print("[StatsRecorder] Write error: " .. tostring(err))
        return false
    end
    return true
end

function StatsRecorder.record(snapshot, game_data, game_instance)
    if not snapshot or not game_data then
        print("[StatsRecorder] Missing data")
        return false
    end

    local time = (game_instance and game_instance.time_elapsed) or 0
    local tokens = snapshot.current_performance or 0
    local base_tokens = snapshot.base_performance or 0

    -- Rate calculations
    local tps = time > 0 and (tokens / time) or 0
    local tpm = tps * 60
    local tph = tps * 3600

    local base_tps = time > 0 and (base_tokens / time) or 0
    local base_tpm = base_tps * 60
    local base_tph = base_tps * 3600

    -- Victory/loss
    local victory = game_instance and game_instance.victory or false
    local lives_remaining = game_instance and game_instance.lives or nil

    -- Build variant summary (just the interesting params, not functions)
    local variant_params = {}
    local dominated_keys = {
        id=1, game_class=1, display_name=1, name=1, clone_index=1,
        base_formula=1, base_formula_string=1, formula_function=1, formula_string=1,
        difficulty_modifiers=1, variant_multiplier=1, unlock_cost=1, cost_exponent=1,
        metrics_tracked=1, sprites=1, sprite_set=1, palette=1,
        music_track=1, sfx_theme=1, intro_cutscene=1, flavor_text=1
    }
    if game_data then
        for k, v in pairs(game_data) do
            if not dominated_keys[k] and type(v) ~= "function" and type(v) ~= "userdata" then
                variant_params[k] = v
            end
        end
    end

    local entry = {
        -- Identity
        game_id = game_data.id,
        game_class = game_data.game_class,
        variant_name = game_data.display_name or game_data.name or "Unknown",
        clone_index = game_data.clone_index or 0,

        -- Result
        result = victory and "victory" or "loss",
        time_elapsed = math.floor(time * 100) / 100,
        lives_remaining = lives_remaining,

        -- Tokens
        base_tokens = math.floor(base_tokens),
        tokens_earned = math.floor(tokens),
        performance_mult = snapshot.performance_mult or 1.0,
        variant_multiplier = game_data.variant_multiplier or 1,
        fail_gated = snapshot.fail_gate_triggered or false,
        previous_best = snapshot.previous_best or 0,
        is_new_best = (tokens > (snapshot.previous_best or 0)),

        -- Rates (the important stuff)
        tokens_per_second = math.floor(tps * 100) / 100,
        tokens_per_minute = math.floor(tpm * 100) / 100,
        tokens_per_hour = math.floor(tph),
        base_tps = math.floor(base_tps * 100) / 100,
        base_tpm = math.floor(base_tpm * 100) / 100,
        base_tph = math.floor(base_tph),

        -- Game metrics
        metrics = snapshot.metrics or {},

        -- Cheats
        cheats = snapshot.cheats_used or nil,

        -- Variant gameplay params (movement_speed, lives, enemies, etc)
        variant_params = variant_params,

        -- Timestamp
        recorded_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local stats = StatsRecorder.loadStats()
    table.insert(stats, entry)
    local saved = StatsRecorder.saveStats(stats)

    if saved then
        print(string.format("[StatsRecorder] Saved: %s - %s | %.1fs | %d tokens | %.1f tpm",
            entry.variant_name, entry.result, entry.time_elapsed, entry.tokens_earned, entry.tokens_per_minute))
    end

    return saved
end

return StatsRecorder
