local TableUtils = {}

-- Decrements timers in a table and removes expired entries
-- Used for: flash effects, cooldowns, etc.
function TableUtils.updateTimerMap(map, dt)
    for key, timer in pairs(map) do
        map[key] = timer - dt
        if map[key] <= 0 then map[key] = nil end
    end
end

-- Counts entities matching a filter in an array
-- Used by: Checking active balls, alive enemies, etc.
function TableUtils.countActive(entities, filter)
    local count = 0
    filter = filter or function(e) return e.active end
    for _, e in ipairs(entities) do
        if filter(e) then count = count + 1 end
    end
    return count
end

return TableUtils
