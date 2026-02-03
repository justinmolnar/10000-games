--[[
MapSpawnProcessor - Processes spawn configurations for procedurally generated maps

Handles room-based, corridor-based, and floor-based spawn placement.
Returns spawn positions - does NOT spawn entities (that's EntityController's job).

Usage:
    local MapSpawnProcessor = require('src.utils.game_components.map_spawn_processor')

    local positions = MapSpawnProcessor.process({
        rooms = result.rooms,
        floor_tiles = result.floor_tiles,
        room_spawns = {
            {type = "enemy", count = 2, room_chance = 1.0, position = "random"},
            {type = "chest", count = 1, room_chance = 0.25, position = "center"}
        },
        corridor_spawns = {
            {type = "health", tile_chance = 0.1, max_count = 5}
        },
        floor_spawns = {
            {type = "gem", density = 20, min_count = 3}
        },
        rng = self.rng
    })

    -- positions is array of {type = "enemy", x = 5.5, y = 3.5}, ...
    for _, pos in ipairs(positions) do
        entity_controller:spawn(pos.type, pos.x, pos.y)
    end
]]

local MapSpawnProcessor = {}

--[[
    Process all spawn configurations and return spawn positions.

    @param config Table with:
        - rooms: Array of room objects (rotLove) with getLeft/getRight/getTop/getBottom/getCenter
        - floor_tiles: Array of {x, y} walkable tiles
        - room_spawns: Array of room spawn configs
        - corridor_spawns: Array of corridor spawn configs
        - floor_spawns: Array of floor spawn configs
        - rng: Random number generator with random() method
    @return Array of {type, x, y} spawn positions
]]
function MapSpawnProcessor.process(config)
    local rooms = config.rooms or {}
    local floor_tiles = config.floor_tiles or {}
    local rng = config.rng or {random = function() return math.random() end}
    local positions = {}

    -- Build set of room tiles for corridor detection
    local room_tiles = {}
    for _, room in ipairs(rooms) do
        if room.getLeft and room.getRight and room.getTop and room.getBottom then
            for x = room:getLeft(), room:getRight() do
                for y = room:getTop(), room:getBottom() do
                    room_tiles[x .. "," .. y] = true
                end
            end
        end
    end

    -- Identify corridor tiles (floor tiles not in rooms)
    local corridor_tiles = {}
    for _, tile in ipairs(floor_tiles) do
        if not room_tiles[tile.x .. "," .. tile.y] then
            table.insert(corridor_tiles, tile)
        end
    end

    -- Process room spawns
    for _, cfg in ipairs(config.room_spawns or {}) do
        local results = MapSpawnProcessor._processRoomConfig(rooms, cfg, rng)
        for _, pos in ipairs(results) do table.insert(positions, pos) end
    end

    -- Process corridor spawns
    for _, cfg in ipairs(config.corridor_spawns or {}) do
        local results = MapSpawnProcessor._processCorridorConfig(corridor_tiles, cfg, rng)
        for _, pos in ipairs(results) do table.insert(positions, pos) end
    end

    -- Process floor spawns
    for _, cfg in ipairs(config.floor_spawns or {}) do
        local results = MapSpawnProcessor._processFloorConfig(floor_tiles, cfg, rng)
        for _, pos in ipairs(results) do table.insert(positions, pos) end
    end

    return positions
end

function MapSpawnProcessor._processRoomConfig(rooms, cfg, rng)
    local positions = {}
    local spawn_type = cfg.type
    local count = cfg.count or 1
    local room_chance = cfg.room_chance or 1.0
    local position_mode = cfg.position or "random"
    local min_rooms = cfg.min_rooms or 0
    local max_rooms = cfg.max_rooms or #rooms

    if #rooms == 0 then return positions end

    -- Select rooms based on chance
    local selected = {}
    for _, room in ipairs(rooms) do
        if rng:random() < room_chance then
            table.insert(selected, room)
        end
    end

    -- Enforce min rooms
    while #selected < min_rooms and #selected < #rooms do
        for _, room in ipairs(rooms) do
            local found = false
            for _, sel in ipairs(selected) do
                if sel == room then found = true; break end
            end
            if not found then
                table.insert(selected, room)
                break
            end
        end
    end

    -- Enforce max rooms
    while #selected > max_rooms do
        table.remove(selected, math.floor(rng:random() * #selected) + 1)
    end

    -- Get spawn positions in each selected room
    for _, room in ipairs(selected) do
        local room_positions = MapSpawnProcessor._getRoomPositions(room, position_mode, count, rng)
        for _, pos in ipairs(room_positions) do
            table.insert(positions, {type = spawn_type, x = pos.x, y = pos.y})
        end
    end

    return positions
end

function MapSpawnProcessor._getRoomPositions(room, position_mode, count, rng)
    local positions = {}

    -- Get room bounds - handle both rotLove method-based and table-based rooms
    local left = room.getLeft and room:getLeft() or room.left or room.x or 0
    local right = room.getRight and room:getRight() or room.right or (left + (room.width or 1))
    local top = room.getTop and room:getTop() or room.top or room.y or 0
    local bottom = room.getBottom and room:getBottom() or room.bottom or (top + (room.height or 1))

    -- Get center - rotLove returns table {[1]=x, [2]=y}
    local cx, cy
    if room.getCenter then
        local center = room:getCenter()
        if type(center) == "table" then
            cx, cy = center[1], center[2]
        else
            cx, cy = center, 0
        end
    else
        cx = (left + right) / 2
        cy = (top + bottom) / 2
    end

    if position_mode == "center" then
        table.insert(positions, {x = cx + 0.5, y = cy + 0.5})
    elseif position_mode == "corners" then
        table.insert(positions, {x = left + 0.5, y = top + 0.5})
        table.insert(positions, {x = right + 0.5, y = top + 0.5})
        table.insert(positions, {x = left + 0.5, y = bottom + 0.5})
        table.insert(positions, {x = right + 0.5, y = bottom + 0.5})
    elseif position_mode == "random" then
        for _ = 1, count do
            local x = left + rng:random() * (right - left)
            local y = top + rng:random() * (bottom - top)
            table.insert(positions, {x = x + 0.5, y = y + 0.5})
        end
    end

    -- Limit to requested count
    while #positions > count do
        table.remove(positions, math.floor(rng:random() * #positions) + 1)
    end

    return positions
end

function MapSpawnProcessor._processCorridorConfig(corridor_tiles, cfg, rng)
    local positions = {}
    local spawn_type = cfg.type
    local count = cfg.count or 1
    local tile_chance = cfg.tile_chance or 0.1
    local min_count = cfg.min_count or 0
    local max_count = cfg.max_count or 999

    if #corridor_tiles == 0 then return positions end

    -- Select tiles based on chance
    local selected = {}
    for _, tile in ipairs(corridor_tiles) do
        if rng:random() < tile_chance then
            table.insert(selected, tile)
        end
    end

    -- Enforce min
    while #selected < min_count and #corridor_tiles > #selected do
        local tile = corridor_tiles[math.floor(rng:random() * #corridor_tiles) + 1]
        local found = false
        for _, sel in ipairs(selected) do
            if sel.x == tile.x and sel.y == tile.y then found = true; break end
        end
        if not found then table.insert(selected, tile) end
    end

    -- Enforce max
    while #selected > max_count do
        table.remove(selected, math.floor(rng:random() * #selected) + 1)
    end

    -- Create positions
    for _, tile in ipairs(selected) do
        for _ = 1, count do
            table.insert(positions, {type = spawn_type, x = tile.x + 0.5, y = tile.y + 0.5})
        end
    end

    return positions
end

function MapSpawnProcessor._processFloorConfig(floor_tiles, cfg, rng)
    local positions = {}
    local spawn_type = cfg.type
    local density = cfg.density or 10  -- 1 spawn per N tiles
    local min_count = cfg.min_count or 0
    local max_count = cfg.max_count or 999

    if #floor_tiles == 0 then return positions end

    local target_count = math.floor(#floor_tiles / density)
    target_count = math.max(min_count, math.min(max_count, target_count))

    -- Shuffle floor tiles
    local shuffled = {}
    for _, tile in ipairs(floor_tiles) do
        table.insert(shuffled, tile)
    end
    for i = #shuffled, 2, -1 do
        local j = math.floor(rng:random() * i) + 1
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    -- Create positions
    for i = 1, math.min(target_count, #shuffled) do
        local tile = shuffled[i]
        table.insert(positions, {type = spawn_type, x = tile.x + 0.5, y = tile.y + 0.5})
    end

    return positions
end

return MapSpawnProcessor
