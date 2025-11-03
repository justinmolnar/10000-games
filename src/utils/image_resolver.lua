-- src/utils/image_resolver.lua
-- Resolve image paths from anywhere in assets/ directory

local ImageResolver = {}

-- Cache of image paths (filename -> full path)
ImageResolver.image_cache = {}

-- Scan assets directory and build image path cache
function ImageResolver.scanAssets()
    ImageResolver.image_cache = {}

    -- Recursively scan directory
    local function scanDirectory(dir)
        local items = love.filesystem.getDirectoryItems(dir)

        for _, item in ipairs(items) do
            local path = dir .. "/" .. item
            local info = love.filesystem.getInfo(path)

            if info then
                if info.type == "directory" then
                    -- Recurse into subdirectories
                    scanDirectory(path)
                elseif info.type == "file" then
                    -- Check if it's an image file
                    local ext = item:match("%.([^%.]+)$")
                    if ext and (ext:lower() == "png" or ext:lower() == "jpg" or ext:lower() == "jpeg" or ext:lower() == "gif" or ext:lower() == "bmp") then
                        -- Store filename -> full path mapping
                        ImageResolver.image_cache[item:lower()] = path
                    end
                end
            end
        end
    end

    -- Scan assets directory
    scanDirectory("assets")
end

-- Initialize on load
ImageResolver.scanAssets()

-- Resolve image filename to full path
-- Supports:
--   "Canada.png" -> finds anywhere in assets/
--   "assets/sprites/games/memory_match/flags/Canada.png" -> direct path
--   "Canada" -> adds .png extension and searches
function ImageResolver.resolve(image_ref)
    if not image_ref or image_ref == "" then
        return nil
    end

    -- Check if it's already a full path
    local info = love.filesystem.getInfo(image_ref)
    if info and info.type == "file" then
        return image_ref
    end

    -- Extract just the filename
    local filename = image_ref:match("([^/\\]+)$") or image_ref

    -- Don't add extension if file already has one
    if not filename:match("%.%w+$") then
        filename = filename .. ".png"
    end

    -- Look up in cache
    local cached_path = ImageResolver.image_cache[filename:lower()]
    if cached_path then
        return cached_path
    end

    -- Not found
    print("Image not found: " .. image_ref)
    return nil
end

-- Load image and return LÖVE Image object
-- For GIFs: Returns gif_data table with frames
-- For static images: Returns image, width, height
function ImageResolver.loadImage(image_ref)
    local path = ImageResolver.resolve(image_ref)
    if not path then
        return nil
    end

    -- Check if it's a GIF (animated)
    if path:lower():match("%.gif$") then
        return ImageResolver.loadGIF(path)
    end

    -- Load static image
    local success, image = pcall(love.graphics.newImage, path)
    if not success then
        print("Failed to load image: " .. path .. " - " .. tostring(image))
        return nil
    end

    return image, image:getWidth(), image:getHeight()
end

-- Load animated GIF
-- Returns: gif_data table with {frames, width, height, is_gif=true}
function ImageResolver.loadGIF(path)
    local success, file_data = pcall(love.filesystem.read, path)
    if not success or not file_data then
        print("Failed to read GIF file: " .. path)
        return nil
    end

    -- Load gifload library
    local ok, gifload = pcall(require, 'lib.gifload')
    if not ok then
        print("gifload library not found, falling back to static image")
        -- Try to load as static image (will only show first frame)
        local img_success, image = pcall(love.graphics.newImage, path)
        if img_success then
            return image, image:getWidth(), image:getHeight()
        end
        return nil
    end

    -- Decode GIF
    local gif_success, gif = pcall(gifload)
    if not gif_success then
        print("Failed to create gifload instance")
        return nil
    end

    local update_success, update_err = pcall(function()
        gif:update(file_data)
        gif:done()
    end)

    if not update_success then
        print("Failed to decode GIF: " .. tostring(update_err))
        return nil
    end

    if gif.nimages == 0 then
        print("GIF has no frames: " .. path)
        return nil
    end

    -- Extract all frames
    local frames = {}
    for i = 1, gif.nimages do
        local frame_success, image_data, x_offset, y_offset, delay, disposal = pcall(gif.frame, gif, i)

        if frame_success then
            -- Convert ImageData to Image
            local img_success, frame_image = pcall(love.graphics.newImage, image_data)
            if img_success then
                -- gifload returns delay already in seconds, not centiseconds!
                local frame_delay = delay or 0.1  -- Default to 0.1s if not specified

                -- Enforce minimum delay for very fast GIFs
                if frame_delay == 0 or frame_delay < 0.02 then
                    frame_delay = 0.02  -- Minimum 0.02s (50fps)
                end

                table.insert(frames, {
                    image = frame_image,
                    x_offset = x_offset or 0,
                    y_offset = y_offset or 0,
                    delay = frame_delay,  -- Already in seconds from gifload
                    disposal = disposal or 0
                })
            end
        end
    end

    if #frames == 0 then
        print("Failed to load any GIF frames: " .. path)
        return nil
    end

    -- Return GIF data structure
    return {
        is_gif = true,
        frames = frames,
        width = gif.width or frames[1].image:getWidth(),
        height = gif.height or frames[1].image:getHeight(),
        loop = gif.loop or true,
        current_frame = 1,
        time_accumulated = 0
    }
end

return ImageResolver
