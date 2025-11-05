--[[
    Boundary Following Algorithm

    Traces the actual perimeter of filled regions by following connected pixels.
    This creates proper ordered contours instead of scattered boundary points.
]]

local ContourTracer = {}

--- Check if pixel is filled
local function isPixelFilled(imageData, x, y)
    local w, h = imageData:getWidth(), imageData:getHeight()
    if x < 0 or y < 0 or x >= w or y >= h then
        return false
    end
    local r, g, b, a = imageData:getPixel(x, y)
    return a > 0.5
end

--- 8-neighbor directions (clockwise from right)
local DIRS = {
    {1, 0},   -- E
    {1, 1},   -- SE
    {0, 1},   -- S
    {-1, 1},  -- SW
    {-1, 0},  -- W
    {-1, -1}, -- NW
    {0, -1},  -- N
    {1, -1}   -- NE
}

--- Follow the boundary of a filled region starting from a seed point
-- Uses Moore-Neighbor tracing algorithm
local function traceBoundary(imageData, start_x, start_y, visited)
    local contour = {}
    local x, y = start_x, start_y
    local w = imageData:getWidth()

    -- Find initial direction (where the background is)
    -- Look for first unfilled neighbor going clockwise from west
    local start_dir = 4  -- Start looking from west (left)
    for i = 0, 7 do
        local check_dir = (start_dir + i) % 8
        local dx, dy = DIRS[check_dir + 1][1], DIRS[check_dir + 1][2]
        if not isPixelFilled(imageData, x + dx, y + dy) then
            start_dir = check_dir
            break
        end
    end

    local dir = start_dir
    local first_move = true
    local max_steps = 50000  -- Increased limit for complex shapes
    local steps = 0

    repeat
        -- Add current boundary pixel to contour
        table.insert(contour, {x, y})

        -- Mark as visited
        local key = y * w + x
        visited[key] = true

        -- Moore-Neighbor: search for next boundary pixel
        -- Start from the pixel that was behind us (backtrack direction)
        local search_start = (dir + 5) % 8  -- Start 135° back from current direction
        local found = false

        for i = 0, 7 do
            local check_dir = (search_start + i) % 8
            local dx, dy = DIRS[check_dir + 1][1], DIRS[check_dir + 1][2]
            local nx, ny = x + dx, y + dy

            if isPixelFilled(imageData, nx, ny) then
                -- Found next boundary pixel
                x, y = nx, ny
                dir = check_dir
                found = true
                break
            end
        end

        if not found then
            break  -- Dead end (isolated pixel)
        end

        steps = steps + 1
        if steps > max_steps then
            print("  [ContourTracer] WARNING: Max steps reached, stopping trace")
            break
        end

        -- Check if we've returned to start
        if not first_move and x == start_x and y == start_y then
            break
        end
        first_move = false

    until false

    return contour
end

--- Find contours by scanning for boundary pixels and tracing them
function ContourTracer.findContours(imageData)
    local w, h = imageData:getWidth(), imageData:getHeight()
    local visited = {}
    local contours = {}

    print(string.format("  [ContourTracer] Scanning %dx%d image for boundaries", w, h))

    -- Scan for boundary starting points
    for y = 1, h - 2 do
        for x = 1, w - 2 do
            local key = y * w + x

            if not visited[key] and isPixelFilled(imageData, x, y) then
                -- Check if this is a boundary pixel
                local is_boundary = false
                for _, d in ipairs(DIRS) do
                    if not isPixelFilled(imageData, x + d[1], y + d[2]) then
                        is_boundary = true
                        break
                    end
                end

                if is_boundary then
                    -- Trace the boundary from this point
                    local contour = traceBoundary(imageData, x, y, visited)

                    if #contour >= 10 then
                        print(string.format("  [ContourTracer] Traced contour: %d points", #contour))

                        -- Don't decimate here - let text_outline_extractor do it with Douglas-Peucker
                        -- Simple decimation creates jagged diamonds on curves
                        table.insert(contours, contour)
                    end
                end
            end
        end
    end

    print(string.format("  [ContourTracer] Found %d contours", #contours))
    return contours
end

return ContourTracer
