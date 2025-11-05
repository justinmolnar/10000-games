--[[
    Text Outline Extractor

    Converts font characters to 2D vector outlines for use in 3D text generation.

    Approach: Since LÖVE2D does not expose vector font outlines directly, we use
    bitmap edge tracing with the marching squares algorithm. Characters are rendered
    to high-resolution ImageData, then edges are traced and simplified.

    Output: {
        outer = {{x, y}, {x, y}, ...},  -- Outer contour (clockwise)
        holes = {                        -- Array of hole contours (counter-clockwise)
            {{x, y}, {x, y}, ...},
            ...
        }
    }
]]

local TextOutlineExtractor = {}

-- ============================================================================
-- Configuration
-- ============================================================================

-- Resolution for bitmap rendering (higher = more accurate, but slower)
local DEFAULT_RESOLUTION = 256

-- Douglas-Peucker simplification tolerance (pixels)
-- CRITICAL: Higher tolerance = LESS simplification = MORE points preserved
-- We need to preserve enough points to represent character curves
local DEFAULT_TOLERANCE = 10.0  -- High tolerance to preserve character detail

-- Minimum contour size (points) - discard smaller contours
-- Lowered temporarily to debug edge connection issues
local MIN_CONTOUR_SIZE = 4  -- Minimum valid polygon

-- ============================================================================
-- Marching Squares Implementation
-- ============================================================================

--[[
    Marching Squares: Trace edges in a binary bitmap

    For each 2x2 cell in the bitmap, there are 16 possible configurations
    of filled/empty pixels. Each configuration maps to edge segments.

    We trace these edges to extract the outline of the character.
]]

-- Marching squares lookup table
-- Each entry: {x1,y1, x2,y2} for line segment (or nil if no edge)
local MARCHING_SQUARES = {
    [0]  = nil,           -- 0000: no edge
    [1]  = {0,1, 1,0},    -- 0001: bottom-left corner
    [2]  = {1,0, 2,1},    -- 0010: bottom-right corner
    [3]  = {0,1, 2,1},    -- 0011: bottom edge
    [4]  = {1,2, 2,1},    -- 0100: top-right corner
    [5]  = {0,1, 1,0, 1,2, 2,1},  -- 0101: ambiguous (two edges)
    [6]  = {1,0, 1,2},    -- 0110: right edge
    [7]  = {0,1, 1,2},    -- 0111: bottom-left to top-right
    [8]  = {0,1, 1,2},    -- 1000: top-left corner
    [9]  = {1,0, 1,2},    -- 1001: left edge
    [10] = {0,1, 1,0, 1,2, 2,1},  -- 1010: ambiguous (two edges)
    [11] = {1,2, 2,1},    -- 1011: top-right corner
    [12] = {0,1, 2,1},    -- 1100: top edge
    [13] = {1,0, 2,1},    -- 1101: bottom-right corner
    [14] = {0,1, 1,0},    -- 1110: bottom-left corner
    [15] = nil,           -- 1111: no edge (fully filled)
}

--- Check if a pixel is filled (alpha > threshold)
local function isPixelFilled(imageData, x, y, threshold)
    threshold = threshold or 127
    if x < 0 or y < 0 or x >= imageData:getWidth() or y >= imageData:getHeight() then
        return false
    end
    local r, g, b, a = imageData:getPixel(x, y)
    return a > threshold / 255
end

--- Get marching squares cell configuration
-- Returns 4-bit value based on filled corners: bottom-left, bottom-right, top-right, top-left
local function getCellConfig(imageData, x, y)
    local bl = isPixelFilled(imageData, x, y + 1) and 1 or 0
    local br = isPixelFilled(imageData, x + 1, y + 1) and 2 or 0
    local tr = isPixelFilled(imageData, x + 1, y) and 4 or 0
    local tl = isPixelFilled(imageData, x, y) and 8 or 0
    return bl + br + tr + tl
end

--- Trace outline using marching squares
-- Returns array of contours: {{{x,y}, {x,y}, ...}, {{x,y}, ...}, ...}
local function traceOutlines(imageData)
    local w, h = imageData:getWidth(), imageData:getHeight()
    local contours = {}
    local visited = {}

    -- Build edge map
    local edges = {}
    local filled_pixels = 0
    for y = 0, h - 2 do
        for x = 0, w - 2 do
            local config = getCellConfig(imageData, x, y)
            if config > 0 then filled_pixels = filled_pixels + 1 end
            local lookup = MARCHING_SQUARES[config]
            if lookup then
                -- Store edges for this cell
                for i = 1, #lookup, 4 do
                    local x1, y1 = x + lookup[i], y + lookup[i+1]
                    local x2, y2 = x + lookup[i+2], y + lookup[i+3]
                    table.insert(edges, {x1, y1, x2, y2})
                end
            end
        end
    end

    print(string.format("  [Marching Squares] Image %dx%d, filled cells: %d, edges: %d", w, h, filled_pixels, #edges))

    -- Connect edges into contours
    -- CRITICAL: Edges can appear in any order, must search all edges for connections
    local discarded_count = 0
    while #edges > 0 do
        local contour = {}
        local current_edge = table.remove(edges, 1)
        table.insert(contour, {current_edge[1], current_edge[2]})
        table.insert(contour, {current_edge[3], current_edge[4]})

        -- Try to extend contour in both directions
        local extended = true
        while extended and #edges > 0 do
            extended = false
            local first = contour[1]
            local last = contour[#contour]

            -- Search ALL remaining edges for connections
            for i = #edges, 1, -1 do
                local edge = edges[i]

                -- Check if edge connects to END of contour (forward extension)
                if math.abs(edge[1] - last[1]) < 0.1 and math.abs(edge[2] - last[2]) < 0.1 then
                    table.insert(contour, {edge[3], edge[4]})
                    table.remove(edges, i)
                    extended = true
                    break
                -- Check if edge connects to START of contour (backward extension)
                elseif math.abs(edge[3] - first[1]) < 0.1 and math.abs(edge[4] - first[2]) < 0.1 then
                    table.insert(contour, 1, {edge[1], edge[2]})
                    table.remove(edges, i)
                    extended = true
                    break
                -- Check if edge is reversed and connects to END
                elseif math.abs(edge[3] - last[1]) < 0.1 and math.abs(edge[4] - last[2]) < 0.1 then
                    table.insert(contour, {edge[1], edge[2]})
                    table.remove(edges, i)
                    extended = true
                    break
                -- Check if edge is reversed and connects to START
                elseif math.abs(edge[1] - first[1]) < 0.1 and math.abs(edge[2] - first[2]) < 0.1 then
                    table.insert(contour, 1, {edge[3], edge[4]})
                    table.remove(edges, i)
                    extended = true
                    break
                end
            end
        end

        -- Only keep contours with minimum size
        if #contour >= MIN_CONTOUR_SIZE then
            print(string.format("  [Marching Squares] Contour: %d points (before simplification)", #contour))
            table.insert(contours, contour)
        else
            discarded_count = discarded_count + 1
        end
    end

    if discarded_count > 0 then
        print(string.format("  [Marching Squares] DISCARDED %d tiny contours (< %d points)", discarded_count, MIN_CONTOUR_SIZE))
    end

    print(string.format("  [Marching Squares] Total contours: %d", #contours))
    return contours
end

-- ============================================================================
-- Douglas-Peucker Simplification
-- ============================================================================

--[[
    Douglas-Peucker Algorithm: Simplify polyline by removing redundant points

    Recursively finds the point furthest from a line segment. If distance
    exceeds tolerance, split and recurse. Otherwise, discard intermediate points.
]]

--- Calculate perpendicular distance from point to line segment
local function perpendicularDistance(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local len_sq = dx * dx + dy * dy

    if len_sq < 0.0001 then
        -- Degenerate segment
        return math.sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1))
    end

    -- Project point onto line
    local t = ((px - x1) * dx + (py - y1) * dy) / len_sq
    t = math.max(0, math.min(1, t))

    local proj_x = x1 + t * dx
    local proj_y = y1 + t * dy

    return math.sqrt((px - proj_x) * (px - proj_x) + (py - proj_y) * (py - proj_y))
end

--- Simplify polyline using Douglas-Peucker algorithm
local function simplifyDouglasPeucker(points, tolerance)
    if #points < 3 then
        return points
    end

    tolerance = tolerance or DEFAULT_TOLERANCE

    -- Find point with maximum distance from line
    local max_dist = 0
    local max_index = 0
    local first = points[1]
    local last = points[#points]

    for i = 2, #points - 1 do
        local pt = points[i]
        local dist = perpendicularDistance(pt[1], pt[2], first[1], first[2], last[1], last[2])
        if dist > max_dist then
            max_dist = dist
            max_index = i
        end
    end

    -- If max distance exceeds tolerance, recursively simplify
    if max_dist > tolerance then
        -- Split and recurse
        local left_points = {}
        for i = 1, max_index do
            table.insert(left_points, points[i])
        end

        local right_points = {}
        for i = max_index, #points do
            table.insert(right_points, points[i])
        end

        local left_result = simplifyDouglasPeucker(left_points, tolerance)
        local right_result = simplifyDouglasPeucker(right_points, tolerance)

        -- Combine results (remove duplicate middle point)
        local result = {}
        for i = 1, #left_result do
            table.insert(result, left_result[i])
        end
        for i = 2, #right_result do
            table.insert(result, right_result[i])
        end
        return result
    else
        -- All points between first and last can be removed
        return {first, last}
    end
end

-- ============================================================================
-- Contour Classification (Outer vs Holes)
-- ============================================================================

--- Calculate signed area of polygon (positive = counter-clockwise, negative = clockwise)
local function calculateSignedArea(points)
    local area = 0
    for i = 1, #points do
        local j = (i % #points) + 1
        area = area + (points[i][1] * points[j][2] - points[j][1] * points[i][2])
    end
    return area / 2
end

--- Check if point is inside polygon (ray casting algorithm)
local function pointInPolygon(px, py, polygon)
    local inside = false
    local n = #polygon
    local j = n

    for i = 1, n do
        local xi, yi = polygon[i][1], polygon[i][2]
        local xj, yj = polygon[j][1], polygon[j][2]

        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end

    return inside
end

--- Classify contours into outer and holes
local function classifyContours(contours)
    if #contours == 0 then
        return nil
    end

    -- Find largest contour (assumed to be primary outer)
    local largest_idx = 1
    local largest_area = 0

    for i, contour in ipairs(contours) do
        local area = math.abs(calculateSignedArea(contour))
        if area > largest_area then
            largest_area = area
            largest_idx = i
        end
    end

    local outer = contours[largest_idx]
    local holes = {}
    local additional_outers = {}  -- For multi-component characters like '?' or 'i'

    -- Ensure outer has correct winding (counter-clockwise = positive area)
    local outer_area = calculateSignedArea(outer)
    print(string.format("  [Classification] Outer area (raw pixels): %.1f", outer_area))
    if outer_area < 0 then
        -- Reverse to make counter-clockwise
        local reversed = {}
        for i = #outer, 1, -1 do
            table.insert(reversed, outer[i])
        end
        outer = reversed
        outer_area = -outer_area
        print("  [Classification] Outer reversed to CCW")
    end

    -- Classify other contours: holes if inside outer, separate components if outside
    for i, contour in ipairs(contours) do
        if i ~= largest_idx then
            -- Check if this contour is inside outer
            local first_point = contour[1]
            if pointInPolygon(first_point[1], first_point[2], outer) then
                -- CRITICAL: Holes must have OPPOSITE winding from outer
                -- Outer is CCW (positive area), so holes must be CW (negative area)
                local hole_area = calculateSignedArea(contour)
                print(string.format("  [Classification] Hole area (before): %.1f", hole_area))
                if hole_area > 0 then
                    -- Reverse to make clockwise
                    local reversed = {}
                    for j = #contour, 1, -1 do
                        table.insert(reversed, contour[j])
                    end
                    table.insert(holes, reversed)
                    print("  [Classification] Hole reversed to CW")
                else
                    table.insert(holes, contour)
                    print("  [Classification] Hole already CW")
                end
            else
                -- Not inside = separate component (like the dot on '?' or 'i')
                table.insert(additional_outers, contour)
            end
        end
    end

    return {
        outer = outer,
        holes = holes,
        additional_outers = additional_outers
    }
end

-- ============================================================================
-- Main API
-- ============================================================================

--- Extract outline from a single character
-- @param char string (single character)
-- @param font love.graphics.Font object
-- @param resolution optional, bitmap resolution (default 256)
-- @param tolerance optional, simplification tolerance (default 2.0)
-- @return table {outer = {{x,y}, ...}, holes = {{{x,y}, ...}, ...}} or nil if empty
function TextOutlineExtractor.getCharacterOutline(char, font, resolution, tolerance)
    resolution = resolution or DEFAULT_RESOLUTION
    tolerance = tolerance or DEFAULT_TOLERANCE

    print(string.format("[TextOutlineExtractor] Extracting '%s' at resolution %d, tolerance %.2f", char, resolution, tolerance))

    -- Create high-res canvas for rendering
    local canvas = love.graphics.newCanvas(resolution, resolution)
    local old_canvas = love.graphics.getCanvas()
    local old_font = love.graphics.getFont()
    local old_color = {love.graphics.getColor()}

    -- Render character to canvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)

    -- Center character in canvas
    local text_width = font:getWidth(char)
    local text_height = font:getHeight()
    local scale = math.min(resolution * 0.8 / text_width, resolution * 0.8 / text_height)
    local x = (resolution - text_width * scale) / 2
    local y = (resolution - text_height * scale) / 2

    print(string.format("  [Render] Font metrics: w=%.1f h=%.1f, scale=%.2f, pos=(%.1f, %.1f)", text_width, text_height, scale, x, y))

    love.graphics.print(char, x, y, 0, scale, scale)
    love.graphics.setCanvas(old_canvas)

    -- Extract image data
    local imageData = canvas:newImageData()
    canvas:release()

    -- Restore graphics state
    love.graphics.setFont(old_font)
    love.graphics.setColor(old_color)

    -- Trace outlines using reliable contour tracing instead of broken marching squares
    local ContourTracer = require('src.utils.contour_tracer')
    local contours = ContourTracer.findContours(imageData)

    if #contours == 0 then
        return nil
    end

    -- Simplify contours using Douglas-Peucker to smooth out jaggy pixel-level traces
    -- Use size-aware tolerance: smaller contours (holes) need less simplification
    for i, contour in ipairs(contours) do
        local before_count = #contour

        -- Adaptive tolerance based on contour size
        -- Lower tolerance = less simplification = more points preserved = smoother
        local area = math.abs(calculateSignedArea(contour))
        local adaptive_tolerance
        if area < 5000 then  -- Small contour (likely a hole)
            adaptive_tolerance = 0.5  -- Holes can be simpler to help Earcut
        else
            adaptive_tolerance = 0.15  -- Keep outer very detailed
        end

        contours[i] = simplifyDouglasPeucker(contour, adaptive_tolerance)
        print(string.format("  [Simplification] Contour %d: %d points -> %d points (tol=%.1f, area=%.0f)",
            i, before_count, #contours[i], adaptive_tolerance, area))
    end

    -- Classify into outer and holes
    local result = classifyContours(contours)
    if result then
        print(string.format("  [Classification] Outer: %d points, Holes: %d, Additional: %d",
            #result.outer, #result.holes, #result.additional_outers))
    else
        print("  [Classification] No result (no contours)")
    end

    if not result then
        return nil
    end

    -- Find actual bounds of the extracted outline (in pixel coordinates)
    -- Include all components (main outer + additional outers like dots)
    local min_x, max_x = math.huge, -math.huge
    local min_y, max_y = math.huge, -math.huge

    for _, pt in ipairs(result.outer) do
        min_x = math.min(min_x, pt[1])
        max_x = math.max(max_x, pt[1])
        min_y = math.min(min_y, pt[2])
        max_y = math.max(max_y, pt[2])
    end

    -- Include additional outer components in bounds calculation
    for _, additional in ipairs(result.additional_outers) do
        for _, pt in ipairs(additional) do
            min_x = math.min(min_x, pt[1])
            max_x = math.max(max_x, pt[1])
            min_y = math.min(min_y, pt[2])
            max_y = math.max(max_y, pt[2])
        end
    end

    -- Use font metrics for consistent normalization
    -- This preserves ascenders, descenders, and relative character sizes
    local font_height = font:getHeight()
    local font_baseline = font:getBaseline()
    local font_ascent = font:getAscent()
    local font_descent = font:getDescent()

    -- Canvas rendering position (from earlier in the function)
    local text_width = font:getWidth(char)
    local text_height = font:getHeight()
    local scale = math.min(resolution * 0.8 / text_width, resolution * 0.8 / text_height)
    local render_x = (resolution - text_width * scale) / 2
    local render_y = (resolution - text_height * scale) / 2

    -- Normalize based on font em-square, not individual character bounds
    -- This preserves character positioning, ascenders, descenders, etc.
    local function normalize(points)
        local normalized = {}
        for _, pt in ipairs(points) do
            -- Convert from canvas pixel coordinates to normalized font-space
            -- Subtract the render position and scale to get back to font coordinates
            -- Then divide by font height for consistent scaling
            local font_x = (pt[1] - render_x) / scale
            local font_y = (pt[2] - render_y) / scale
            table.insert(normalized, {
                font_x / font_height,
                font_y / font_height
            })
        end
        return normalized
    end

    result.outer = normalize(result.outer)
    for i, hole in ipairs(result.holes) do
        result.holes[i] = normalize(hole)
    end

    -- Normalize additional outer components
    for i, additional in ipairs(result.additional_outers) do
        result.additional_outers[i] = normalize(additional)
    end

    -- DEBUG: Check if normalization preserved winding and hole containment
    local normalized_outer_area = calculateSignedArea(result.outer)
    print(string.format("  [Classification] Outer area (after normalize): %.6f (should be positive)", normalized_outer_area))
    if #result.holes > 0 then
        local normalized_hole_area = calculateSignedArea(result.holes[1])
        print(string.format("  [Classification] Hole area (after normalize): %.6f (should be negative)", normalized_hole_area))

        -- Check if hole is still inside outer after normalization
        local hole_first = result.holes[1][1]
        local still_inside = pointInPolygon(hole_first[1], hole_first[2], result.outer)
        print(string.format("  [Classification] Hole still inside outer after normalize: %s", tostring(still_inside)))
    end

    -- Store character metrics for proper spacing
    result.metrics = {
        width = font:getWidth(char) / font_height,  -- Normalized width
        height = 1.0,  -- Always 1.0 in normalized space
        ascent = font_ascent / font_height,
        descent = font_descent / font_height
    }

    return result
end

--- Get bounding box of outline
-- @param outline table {outer, holes}
-- @return min_x, min_y, max_x, max_y
function TextOutlineExtractor.getBoundingBox(outline)
    if not outline or not outline.outer then
        return 0, 0, 0, 0
    end

    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge

    for _, pt in ipairs(outline.outer) do
        min_x = math.min(min_x, pt[1])
        min_y = math.min(min_y, pt[2])
        max_x = math.max(max_x, pt[1])
        max_y = math.max(max_y, pt[2])
    end

    return min_x, min_y, max_x, max_y
end

return TextOutlineExtractor
