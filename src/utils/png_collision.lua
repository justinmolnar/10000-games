-- png_collision.lua: Pixel-perfect collision detection using PNG alpha channel
-- Non-transparent pixels (alpha > threshold) are considered collision areas

local PNGCollision = {}

-- Cache for loaded ImageData objects to avoid redundant loads
local image_cache = {}

-- Load a PNG file as ImageData for collision detection
-- Returns ImageData object or nil if load fails
function PNGCollision.loadCollisionImage(file_path)
    if image_cache[file_path] then
        return image_cache[file_path]
    end

    local success, image_data = pcall(love.image.newImageData, file_path)
    if success and image_data then
        image_cache[file_path] = image_data
        return image_data
    else
        print("[PNGCollision] Failed to load collision image:", file_path)
        return nil
    end
end

-- Check if a point is inside a non-transparent pixel of an image
-- image_data: ImageData object
-- image_x, image_y: Top-left position of the image in world space
-- point_x, point_y: Point to check in world space
-- alpha_threshold: Minimum alpha value to consider solid (0-1, default 0.5)
function PNGCollision.checkPoint(image_data, image_x, image_y, point_x, point_y, alpha_threshold)
    if not image_data then
        return false
    end

    alpha_threshold = alpha_threshold or 0.5

    -- Convert world coordinates to image-local coordinates
    local local_x = math.floor(point_x - image_x)
    local local_y = math.floor(point_y - image_y)

    -- Check bounds
    local width = image_data:getWidth()
    local height = image_data:getHeight()
    if local_x < 0 or local_x >= width or local_y < 0 or local_y >= height then
        return false
    end

    -- Get pixel alpha channel (4th component: r, g, b, a)
    local r, g, b, a = image_data:getPixel(local_x, local_y)

    -- Consider solid if alpha exceeds threshold
    return a >= alpha_threshold
end

-- Check ball-to-PNG collision using sampled edge points
-- Ball is sampled at 8 cardinal/diagonal directions around its perimeter
-- Returns true if any sample point hits a non-transparent pixel
function PNGCollision.checkBall(image_data, image_x, image_y, ball_x, ball_y, ball_radius, alpha_threshold)
    if not image_data then
        return false
    end

    alpha_threshold = alpha_threshold or 0.5

    -- First check AABB for early rejection (optimization)
    local width = image_data:getWidth()
    local height = image_data:getHeight()

    if ball_x + ball_radius < image_x or
       ball_x - ball_radius > image_x + width or
       ball_y + ball_radius < image_y or
       ball_y - ball_radius > image_y + height then
        return false
    end

    -- Sample 8 points around ball perimeter (cardinal + diagonal directions)
    local sample_angles = {0, math.pi/4, math.pi/2, 3*math.pi/4, math.pi, 5*math.pi/4, 3*math.pi/2, 7*math.pi/4}

    for _, angle in ipairs(sample_angles) do
        local sample_x = ball_x + math.cos(angle) * ball_radius
        local sample_y = ball_y + math.sin(angle) * ball_radius

        if PNGCollision.checkPoint(image_data, image_x, image_y, sample_x, sample_y, alpha_threshold) then
            return true
        end
    end

    -- Also check ball center for small balls
    if PNGCollision.checkPoint(image_data, image_x, image_y, ball_x, ball_y, alpha_threshold) then
        return true
    end

    return false
end

-- Estimate surface normal at collision point for PNG collision
-- Samples pixels around the collision point to determine direction
-- Returns normalized nx, ny (or 0, -1 if can't determine)
function PNGCollision.estimateNormal(image_data, image_x, image_y, ball_x, ball_y, ball_radius, alpha_threshold)
    if not image_data then
        return 0, -1  -- Default: upward normal
    end

    alpha_threshold = alpha_threshold or 0.5

    -- Sample multiple points around the ball's perimeter to find edge
    local sample_angles = {0, math.pi/4, math.pi/2, 3*math.pi/4, math.pi, 5*math.pi/4, 3*math.pi/2, 7*math.pi/4}

    -- Find which directions are inside vs outside the shape
    local inside_dirs = {}
    local outside_dirs = {}

    for _, angle in ipairs(sample_angles) do
        local sample_x = ball_x + math.cos(angle) * ball_radius
        local sample_y = ball_y + math.sin(angle) * ball_radius

        local is_inside = PNGCollision.checkPoint(image_data, image_x, image_y, sample_x, sample_y, alpha_threshold)

        if is_inside then
            table.insert(inside_dirs, {math.cos(angle), math.sin(angle)})
        else
            table.insert(outside_dirs, {math.cos(angle), math.sin(angle)})
        end
    end

    -- Normal points from inside toward outside
    if #outside_dirs > 0 then
        local sum_x = 0
        local sum_y = 0

        for _, dir in ipairs(outside_dirs) do
            sum_x = sum_x + dir[1]
            sum_y = sum_y + dir[2]
        end

        local length = math.sqrt(sum_x * sum_x + sum_y * sum_y)
        if length > 0.1 then
            return sum_x / length, sum_y / length
        end
    end

    -- Fallback: Try gradient-based method at ball center
    local sample_dist = 3
    local gradient_x = 0
    local gradient_y = 0

    -- Sample in a cross pattern
    for i = -1, 1 do
        for j = -1, 1 do
            if i ~= 0 or j ~= 0 then
                local sample_x = ball_x + i * sample_dist
                local sample_y = ball_y + j * sample_dist
                local is_solid = PNGCollision.checkPoint(image_data, image_x, image_y, sample_x, sample_y, alpha_threshold)

                if not is_solid then
                    -- This direction is "out"
                    gradient_x = gradient_x + i
                    gradient_y = gradient_y + j
                end
            end
        end
    end

    local grad_length = math.sqrt(gradient_x * gradient_x + gradient_y * gradient_y)
    if grad_length > 0.1 then
        return gradient_x / grad_length, gradient_y / grad_length
    end

    -- Ultimate fallback: upward normal
    return 0, -1
end

-- Clear the image cache (call when resources need to be freed)
function PNGCollision.clearCache()
    image_cache = {}
end

return PNGCollision
