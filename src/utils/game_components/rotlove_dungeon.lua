local Object = require('class')
local ROT = require('lib.rotLove.src.rot')

local RotloveDungeon = Object:extend('RotloveDungeon')

function RotloveDungeon:new(config)
    config = config or {}

    self.width = config.width or 30
    self.height = config.height or 30
    self.generator_type = config.generator_type or "uniform"

    -- Uniform/Digger options
    self.room_width = config.room_width or {3, 8}
    self.room_height = config.room_height or {3, 6}
    self.room_dug_percentage = config.room_dug_percentage or 0.5
    self.time_limit = config.time_limit or 2000

    -- Rogue options (grid of rooms)
    self.cell_width = config.cell_width or 3   -- rooms horizontally
    self.cell_height = config.cell_height or 3  -- rooms vertically

    -- Cellular (cave) options
    self.cellular_iterations = config.cellular_iterations or 4
    self.cellular_prob = config.cellular_prob or 0.5
    self.cellular_connected = config.cellular_connected or true
    self.cellular_born = config.cellular_born or {5, 6, 7, 8}
    self.cellular_survive = config.cellular_survive or {4, 5, 6, 7, 8}

    -- Seed for reproducible generation
    self.seed = config.seed

    -- Generated data
    self.map = {}
    self.map_width = 0
    self.map_height = 0
    self.floor_tiles = {}
    self.rooms = {}
    self.doors = {}

    return self
end

function RotloveDungeon:generate(rng)
    local generator

    -- Setup seeded RNG if provided
    local rot_rng = ROT.RNG:new(self.seed or (rng and rng:random(1, 999999999)) or os.time())

    local options = {
        roomWidth = self.room_width,
        roomHeight = self.room_height,
        roomDugPercentage = self.room_dug_percentage,
        timeLimit = self.time_limit
    }

    if self.generator_type == "uniform" then
        generator = ROT.Map.Uniform:new(self.width, self.height, options)
        generator:setRNG(rot_rng)

    elseif self.generator_type == "digger" then
        generator = ROT.Map.Digger:new(self.width, self.height, options)
        generator:setRNG(rot_rng)

    elseif self.generator_type == "rogue" then
        local rogue_options = {
            cellWidth = self.cell_width,
            cellHeight = self.cell_height,
            roomWidth = self.room_width,
            roomHeight = self.room_height
        }
        generator = ROT.Map.Rogue:new(self.width, self.height, rogue_options)
        generator:setRNG(rot_rng)

    elseif self.generator_type == "cellular" then
        local cell_options = {
            born = self.cellular_born,
            survive = self.cellular_survive,
            connected = self.cellular_connected,
            topology = 8
        }
        generator = ROT.Map.Cellular:new(self.width, self.height, cell_options)
        generator:setRNG(rot_rng)
        generator:randomize(self.cellular_prob)
        -- Run iterations
        for i = 1, self.cellular_iterations do
            generator:create()
        end

    elseif self.generator_type == "divided_maze" then
        generator = ROT.Map.DividedMaze:new(self.width, self.height)
        generator:setRNG(rot_rng)

    elseif self.generator_type == "icey_maze" then
        generator = ROT.Map.IceyMaze:new(self.width, self.height)
        generator:setRNG(rot_rng)

    elseif self.generator_type == "eller_maze" then
        generator = ROT.Map.EllerMaze:new(self.width, self.height)
        generator:setRNG(rot_rng)

    elseif self.generator_type == "arena" then
        generator = ROT.Map.Arena:new(self.width, self.height)

    else
        generator = ROT.Map.Uniform:new(self.width, self.height, options)
        generator:setRNG(rot_rng)
    end

    -- Build the map
    self.map = {}
    for y = 1, self.height do
        self.map[y] = {}
        for x = 1, self.width do
            self.map[y][x] = 1  -- Default to wall
        end
    end

    -- Generate and collect floor tiles
    generator:create(function(x, y, value)
        if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
            self.map[y][x] = value  -- 0 = floor, 1 = wall
        end
    end)

    self.map_width = self.width
    self.map_height = self.height

    -- Collect floor tiles
    self:collectFloorTiles()

    -- Get room data if available
    if generator.getRooms then
        self.rooms = generator:getRooms() or {}
    end

    -- Get door data if available
    self.doors = {}
    if generator.getDoors then
        local raw_doors = generator:getDoors() or {}
        for _, door in ipairs(raw_doors) do
            table.insert(self.doors, {x = door.x, y = door.y})
        end
    end

    -- Select start and goal
    local start, goal = self:selectStartAndGoal(rng)

    print(string.format("[RotloveDungeon] Generated %dx%d %s dungeon, %d floor tiles, %d doors, start=(%.1f,%.1f) goal=(%d,%d)",
        self.map_width, self.map_height, self.generator_type, #self.floor_tiles, #self.doors,
        start.x, start.y, goal.x, goal.y))

    return {
        map = self.map,
        width = self.map_width,
        height = self.map_height,
        start = start,
        goal = goal,
        rooms = self.rooms,
        floor_tiles = self.floor_tiles,
        doors = self.doors
    }
end

function RotloveDungeon:collectFloorTiles()
    self.floor_tiles = {}
    for y = 1, self.map_height do
        for x = 1, self.map_width do
            if self.map[y][x] == 0 then
                table.insert(self.floor_tiles, {x = x, y = y})
            end
        end
    end
end

function RotloveDungeon:selectStartAndGoal(rng)
    rng = rng or love.math.newRandomGenerator(os.time())

    if #self.floor_tiles < 2 then
        return {x = 1.5, y = 1.5, angle = 0}, {x = 1, y = 1}
    end

    -- Pick random start
    local start_idx = rng:random(1, #self.floor_tiles)
    local start_tile = self.floor_tiles[start_idx]
    local start = {
        x = start_tile.x + 0.5,
        y = start_tile.y + 0.5,
        angle = rng:random() * math.pi * 2
    }

    -- Pick goal far from start
    local best_dist = 0
    local best_goal = self.floor_tiles[1]

    for i, tile in ipairs(self.floor_tiles) do
        if i ~= start_idx then
            local dist = math.abs(tile.x - start_tile.x) + math.abs(tile.y - start_tile.y)
            if dist > best_dist then
                best_dist = dist
                best_goal = tile
            end
        end
    end

    local goal = {x = best_goal.x, y = best_goal.y}

    return start, goal
end

function RotloveDungeon:getFloorTiles()
    return self.floor_tiles
end

function RotloveDungeon:getMap()
    return self.map, self.map_width, self.map_height
end

function RotloveDungeon:isWalkable(x, y)
    local tile_x = math.floor(x)
    local tile_y = math.floor(y)

    if tile_x < 1 or tile_x > self.map_width or tile_y < 1 or tile_y > self.map_height then
        return false
    end

    return self.map[tile_y] and self.map[tile_y][tile_x] == 0
end

function RotloveDungeon:computeCriticalPath(start, goal)
    if not start or not goal then
        return {}
    end

    local start_x = math.floor(start.x)
    local start_y = math.floor(start.y)
    local goal_x = math.floor(goal.x)
    local goal_y = math.floor(goal.y)

    local map = self.map

    local function passableCallback(x, y)
        if x < 1 or x > self.map_width or y < 1 or y > self.map_height then
            return false
        end
        return map[y] and map[y][x] == 0
    end

    local astar = ROT.Path.AStar:new(goal_x, goal_y, passableCallback, {topology = 4})

    -- Get raw A* path
    local raw_path = {}
    local path_lookup = {}
    astar:compute(start_x, start_y, function(x, y)
        table.insert(raw_path, {x = x, y = y})
        path_lookup[x .. "," .. y] = true
    end)

    -- Helper to get room bounds (handles both Room objects and plain tables)
    local function getRoomBounds(room)
        if room.getLeft then
            -- Room object with methods
            return room:getLeft(), room:getRight(), room:getTop(), room:getBottom()
        elseif room.x and room.y and room.width and room.height then
            -- Plain table with x,y,width,height
            return room.x, room.x + room.width - 1, room.y, room.y + room.height - 1
        elseif room._x1 then
            -- Direct access to Room internals
            return room._x1, room._x2, room._y1, room._y2
        end
        return nil
    end

    -- Find which rooms the path passes through
    local critical_rooms = {}
    for i, room in ipairs(self.rooms or {}) do
        local left, right, top, bottom = getRoomBounds(room)
        if left then
            local room_on_path = false
            for y = top, bottom do
                for x = left, right do
                    if path_lookup[x .. "," .. y] then
                        room_on_path = true
                        break
                    end
                end
                if room_on_path then break end
            end
            if room_on_path then
                critical_rooms[i] = true
            end
        end
    end

    -- Build expanded path: all tiles in critical rooms + corridor tiles from path
    local expanded_path = {}
    local added = {}

    -- Add all tiles from critical rooms
    for i, room in ipairs(self.rooms or {}) do
        if critical_rooms[i] then
            local left, right, top, bottom = getRoomBounds(room)
            if left then
                for y = top, bottom do
                    for x = left, right do
                        if map[y] and map[y][x] == 0 then
                            local key = x .. "," .. y
                            if not added[key] then
                                table.insert(expanded_path, {x = x, y = y})
                                added[key] = true
                            end
                        end
                    end
                end
            end
        end
    end

    -- Add corridor tiles from raw path (tiles not in any room)
    for _, tile in ipairs(raw_path) do
        local key = tile.x .. "," .. tile.y
        if not added[key] then
            table.insert(expanded_path, tile)
            added[key] = true
        end
    end

    self.critical_path = expanded_path
    self.critical_rooms = critical_rooms

    local num_critical = 0
    for _ in pairs(critical_rooms) do num_critical = num_critical + 1 end
    print(string.format("[RotloveDungeon] Critical path: %d tiles, %d/%d rooms critical",
        #expanded_path, num_critical, #(self.rooms or {})))

    return expanded_path
end

function RotloveDungeon:getCriticalPath()
    return self.critical_path or {}
end

function RotloveDungeon:getCriticalRooms()
    return self.critical_rooms or {}
end

return RotloveDungeon
