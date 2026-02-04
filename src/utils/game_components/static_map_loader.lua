local Object = require('class')
local json = require('lib.json')

local StaticMapLoader = Object:extend('StaticMapLoader')

function StaticMapLoader:new(config)
    config = config or {}
    self.map_name = config.map_name or "pacman"
    self.maps_path = "assets/data/maps/"
    return self
end

function StaticMapLoader:generate(rng)
    local map_data = self:loadMap(self.map_name)

    if not map_data then
        return {
            map = {{1,1,1,1,1}, {1,0,0,0,1}, {1,0,0,0,1}, {1,0,0,0,1}, {1,1,1,1,1}},
            width = 5, height = 5,
            start = {x = 2.5, y = 2.5, angle = 0},
            goal = {x = 3, y = 3},
            markers = {}
        }
    end

    local map = {}
    local floor_tiles = {}
    local markers = {}  -- {char = {{x, y}, ...}, ...} - game decides what each char means
    local height = #map_data.rows
    local width = #map_data.rows[1]

    for y, row in ipairs(map_data.rows) do
        map[y] = {}
        for x = 1, #row do
            local char = row:sub(x, x)
            if char == "#" then
                map[y][x] = 1  -- Wall
            else
                map[y][x] = 0  -- Floor
                table.insert(floor_tiles, {x = x, y = y})
                -- Track non-floor markers (anything that's not space or dot)
                if char ~= " " and char ~= "." then
                    markers[char] = markers[char] or {}
                    table.insert(markers[char], {x = x + 0.5, y = y + 0.5})
                end
            end
        end
    end

    local start = map_data.start or self:pickStart(floor_tiles, rng)
    local goal = map_data.goal or self:pickGoal(floor_tiles, start, rng)

    self.floor_tiles = floor_tiles
    self.markers = markers

    print("[StaticMapLoader] Found markers:")
    for char, positions in pairs(markers) do
        print("  char:", char, "count:", #positions)
    end

    return {
        map = map,
        width = width,
        height = height,
        start = start,
        goal = goal,
        floor_tiles = floor_tiles,
        markers = markers
    }
end

function StaticMapLoader:loadMap(name)
    local path = self.maps_path .. name .. ".json"
    local content = love.filesystem.read(path)

    if not content then
        print("[StaticMapLoader] Could not load map: " .. path)
        return nil
    end

    local success, data = pcall(json.decode, content)
    if not success then
        print("[StaticMapLoader] JSON parse error: " .. path)
        return nil
    end

    return data
end

function StaticMapLoader:pickStart(floor_tiles, rng)
    if #floor_tiles == 0 then
        return {x = 1.5, y = 1.5, angle = 0}
    end

    local idx = rng and rng:random(1, #floor_tiles) or 1
    local tile = floor_tiles[idx]
    return {
        x = tile.x + 0.5,
        y = tile.y + 0.5,
        angle = rng and (rng:random() * math.pi * 2) or 0
    }
end

function StaticMapLoader:pickGoal(floor_tiles, start, rng)
    if #floor_tiles < 2 then
        return {x = 1, y = 1}
    end

    -- Pick tile furthest from start
    local best_dist = 0
    local best_tile = floor_tiles[1]

    for _, tile in ipairs(floor_tiles) do
        local dist = math.abs(tile.x - start.x) + math.abs(tile.y - start.y)
        if dist > best_dist then
            best_dist = dist
            best_tile = tile
        end
    end

    return {x = best_tile.x, y = best_tile.y}
end

function StaticMapLoader:getFloorTiles()
    return self.floor_tiles or {}
end

return StaticMapLoader
