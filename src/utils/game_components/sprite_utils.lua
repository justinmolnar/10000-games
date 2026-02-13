-- SpriteUtils: Shared sprite processing and pixel-based collision
-- Load-time: content detection, cropping, rescaling
-- Runtime: pixel-perfect collision via alpha channel
--
-- Usage:
--   local SpriteUtils = require('src.utils.game_components.sprite_utils')
--   local result = SpriteUtils.processSprite(path, {target_size = 64, alignment = "bottom"})
--   local imageData = SpriteUtils.loadImageData(path)
--   local hit = SpriteUtils.checkCircle(imageData, ix, iy, cx, cy, cr)

local SpriteUtils = {}

-- Cache for loaded ImageData objects (pixel collision)
local imagedata_cache = {}

-- ============================================================================
-- IMAGE DATA LOADING
-- ============================================================================

-- Load a PNG as ImageData with caching. Returns ImageData or nil.
function SpriteUtils.loadImageData(file_path)
    if imagedata_cache[file_path] then
        return imagedata_cache[file_path]
    end

    local success, image_data = pcall(love.image.newImageData, file_path)
    if success and image_data then
        imagedata_cache[file_path] = image_data
        return image_data
    end
    return nil
end

-- Clear the ImageData cache
function SpriteUtils.clearCache()
    imagedata_cache = {}
end

-- ============================================================================
-- CONTENT DETECTION & PROCESSING
-- ============================================================================

-- Scan pixels for opaque content bounding box
-- Returns {top, bottom, left, right, content_width, content_height} or nil
function SpriteUtils.getContentBounds(imageData, alpha_threshold)
    alpha_threshold = alpha_threshold or 0.1
    local w = imageData:getWidth()
    local h = imageData:getHeight()

    local top, bottom, left, right = h, -1, w, -1
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = imageData:getPixel(x, y)
            if a > alpha_threshold then
                if y < top then top = y end
                if y > bottom then bottom = y end
                if x < left then left = x end
                if x > right then right = x end
            end
        end
    end

    if bottom < 0 then return nil end

    local content_width = right - left + 1
    local content_height = bottom - top + 1
    return {
        top = top, bottom = bottom, left = left, right = right,
        content_width = content_width, content_height = content_height
    }
end

-- Crop ImageData to bounds from getContentBounds
-- Returns cropped ImageData
function SpriteUtils.cropToContent(imageData, bounds)
    local cropped = love.image.newImageData(bounds.content_width, bounds.content_height)
    cropped:paste(imageData, 0, 0, bounds.left, bounds.top, bounds.content_width, bounds.content_height)
    return cropped
end

-- Scale largest dim to target_size, render on square canvas
-- alignment: "center" (default) or "bottom"
-- Returns LÖVE Image
function SpriteUtils.rescaleToCanvas(imageData, target_size, alignment)
    alignment = alignment or "center"
    local crop_w = imageData:getWidth()
    local crop_h = imageData:getHeight()

    local scale = math.min(target_size / crop_w, target_size / crop_h)
    local scaled_w = math.floor(crop_w * scale)
    local scaled_h = math.floor(crop_h * scale)

    local x_offset = (target_size - scaled_w) / 2
    local y_offset
    if alignment == "bottom" then
        y_offset = target_size - scaled_h
    else
        y_offset = (target_size - scaled_h) / 2
    end

    local canvas = love.graphics.newCanvas(target_size, target_size)
    local temp_image = love.graphics.newImage(imageData)
    local prev_canvas = love.graphics.getCanvas()
    local prev_blend = {love.graphics.getBlendMode()}
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(temp_image, x_offset, y_offset, 0, scale, scale)
    love.graphics.setBlendMode(unpack(prev_blend))
    love.graphics.setCanvas(prev_canvas)

    return love.graphics.newImage(canvas:newImageData())
end

-- Compute collision ratios from bounds
-- Returns {width_ratio, height_ratio} (each 0-1)
function SpriteUtils.getCollisionInfo(bounds)
    local max_dim = math.max(bounds.content_width, bounds.content_height)
    return {
        width_ratio = bounds.content_width / max_dim,
        height_ratio = bounds.content_height / max_dim
    }
end

-- All-in-one: load, scan, crop, rescale
-- config: {target_size, alignment, alpha_threshold}
-- target_size defaults to image's max dimension
-- Returns {image, collision_info} or nil
function SpriteUtils.processSprite(path, config)
    config = config or {}
    local success, imageData = pcall(love.image.newImageData, path)
    if not success then return nil end

    local bounds = SpriteUtils.getContentBounds(imageData, config.alpha_threshold)
    if not bounds then return nil end

    local target_size = config.target_size or math.max(imageData:getWidth(), imageData:getHeight())
    local cropped = SpriteUtils.cropToContent(imageData, bounds)
    local image = SpriteUtils.rescaleToCanvas(cropped, target_size, config.alignment)
    local collision_info = SpriteUtils.getCollisionInfo(bounds)

    return {image = image, collision_info = collision_info}
end

-- ============================================================================
-- PIXEL COLLISION
-- ============================================================================

-- Check if a point hits a non-transparent pixel
-- image_x, image_y: top-left of image in world space
-- point_x, point_y: point to check in world space
function SpriteUtils.checkPoint(image_data, image_x, image_y, point_x, point_y, alpha_threshold)
    if not image_data then return false end
    alpha_threshold = alpha_threshold or 0.5

    local local_x = math.floor(point_x - image_x)
    local local_y = math.floor(point_y - image_y)

    local width = image_data:getWidth()
    local height = image_data:getHeight()
    if local_x < 0 or local_x >= width or local_y < 0 or local_y >= height then
        return false
    end

    local _, _, _, a = image_data:getPixel(local_x, local_y)
    return a >= alpha_threshold
end

-- Check circle-to-image collision by sampling 8 perimeter points + center
-- image_x, image_y: top-left of image in world space
-- cx, cy, radius: circle in world space
function SpriteUtils.checkCircle(image_data, image_x, image_y, cx, cy, radius, alpha_threshold)
    if not image_data then return false end
    alpha_threshold = alpha_threshold or 0.5

    -- AABB early rejection
    local width = image_data:getWidth()
    local height = image_data:getHeight()
    if cx + radius < image_x or cx - radius > image_x + width or
       cy + radius < image_y or cy - radius > image_y + height then
        return false
    end

    -- Sample 8 points around perimeter
    local sample_angles = {0, math.pi/4, math.pi/2, 3*math.pi/4, math.pi, 5*math.pi/4, 3*math.pi/2, 7*math.pi/4}
    for _, angle in ipairs(sample_angles) do
        local sx = cx + math.cos(angle) * radius
        local sy = cy + math.sin(angle) * radius
        if SpriteUtils.checkPoint(image_data, image_x, image_y, sx, sy, alpha_threshold) then
            return true
        end
    end

    -- Check center for small circles
    return SpriteUtils.checkPoint(image_data, image_x, image_y, cx, cy, alpha_threshold)
end

-- Estimate surface normal at a collision point
-- Samples around the circle to find inside/outside directions
-- Returns normalized nx, ny (fallback: 0, -1)
function SpriteUtils.estimateNormal(image_data, image_x, image_y, cx, cy, radius, alpha_threshold)
    if not image_data then return 0, -1 end
    alpha_threshold = alpha_threshold or 0.5

    local sample_angles = {0, math.pi/4, math.pi/2, 3*math.pi/4, math.pi, 5*math.pi/4, 3*math.pi/2, 7*math.pi/4}
    local outside_dirs = {}

    for _, angle in ipairs(sample_angles) do
        local sx = cx + math.cos(angle) * radius
        local sy = cy + math.sin(angle) * radius
        if not SpriteUtils.checkPoint(image_data, image_x, image_y, sx, sy, alpha_threshold) then
            table.insert(outside_dirs, {math.cos(angle), math.sin(angle)})
        end
    end

    -- Normal points from inside toward outside
    if #outside_dirs > 0 then
        local sum_x, sum_y = 0, 0
        for _, dir in ipairs(outside_dirs) do
            sum_x = sum_x + dir[1]
            sum_y = sum_y + dir[2]
        end
        local length = math.sqrt(sum_x * sum_x + sum_y * sum_y)
        if length > 0.1 then
            return sum_x / length, sum_y / length
        end
    end

    -- Fallback: gradient sampling at center
    local sample_dist = 3
    local gx, gy = 0, 0
    for i = -1, 1 do
        for j = -1, 1 do
            if i ~= 0 or j ~= 0 then
                if not SpriteUtils.checkPoint(image_data, image_x, image_y, cx + i * sample_dist, cy + j * sample_dist, alpha_threshold) then
                    gx = gx + i
                    gy = gy + j
                end
            end
        end
    end

    local gl = math.sqrt(gx * gx + gy * gy)
    if gl > 0.1 then return gx / gl, gy / gl end

    return 0, -1
end

return SpriteUtils
