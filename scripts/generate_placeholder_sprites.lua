-- Placeholder Sprite Generator
-- Generates simple placeholder sprites for testing Phase 2.3 integration
-- Run with: love . scripts/generate_placeholder_sprites.lua

local function createImageData(width, height)
    return love.image.newImageData(width, height)
end

local function setPixel(imageData, x, y, r, g, b, a)
    a = a or 255
    imageData:setPixel(x, y, r/255, g/255, b/255, a/255)
end

local function fillRect(imageData, x1, y1, x2, y2, r, g, b, a)
    for y = y1, y2 do
        for x = x1, x2 do
            setPixel(imageData, x, y, r, g, b, a)
        end
    end
end

local function fillCircle(imageData, cx, cy, radius, r, g, b, a)
    local width, height = imageData:getDimensions()
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local dx = x - cx
            local dy = y - cy
            if dx * dx + dy * dy <= radius * radius then
                setPixel(imageData, x, y, r, g, b, a)
            end
        end
    end
end

local function fillDiamond(imageData, cx, cy, size, r, g, b, a)
    local width, height = imageData:getDimensions()
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local dx = math.abs(x - cx)
            local dy = math.abs(y - cy)
            if dx + dy <= size then
                setPixel(imageData, x, y, r, g, b, a)
            end
        end
    end
end

local function fillTriangle(imageData, cx, cy, size, r, g, b, a)
    local width, height = imageData:getDimensions()
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            -- Upward pointing triangle
            local dx = math.abs(x - cx)
            local dy = cy - y
            if dy >= 0 and dx <= dy and dy <= size then
                setPixel(imageData, x, y, r, g, b, a)
            end
        end
    end
end

local function fillCross(imageData, cx, cy, size, thickness, r, g, b, a)
    local width, height = imageData:getDimensions()
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local dx = math.abs(x - cx)
            local dy = math.abs(y - cy)
            if (dx <= thickness and dy <= size) or (dy <= thickness and dx <= size) then
                setPixel(imageData, x, y, r, g, b, a)
            end
        end
    end
end

local function saveImage(imageData, path)
    local success, err = pcall(function()
        imageData:encode("png", path)
    end)
    if success then
        print("Created: " .. path)
    else
        print("Failed to create " .. path .. ": " .. tostring(err))
    end
end

-- Generate Dodge Game Placeholders
local function generateDodgePlaceholders()
    local basePath = "assets/sprites/games/dodge/base_1/"
    local size = 16

    -- Canonical colors: Red [255,0,0], Dark Red [200,0,0], Darker Red [150,0,0], Yellow [255,255,0]

    -- Player: Red circle with yellow center
    local player = createImageData(size, size)
    fillCircle(player, size/2, size/2, 6, 255, 0, 0, 255)
    fillCircle(player, size/2, size/2, 3, 255, 255, 0, 255)
    saveImage(player, basePath .. "player.png")

    -- Obstacle: Red square
    local obstacle = createImageData(size, size)
    fillRect(obstacle, 2, 2, size-3, size-3, 200, 0, 0, 255)
    saveImage(obstacle, basePath .. "obstacle.png")

    -- Enemy Chaser: Solid red circle
    local chaser = createImageData(size, size)
    fillCircle(chaser, size/2, size/2, 6, 255, 0, 0, 255)
    saveImage(chaser, basePath .. "enemy_chaser.png")

    -- Enemy Shooter: Red square with yellow dot (gun)
    local shooter = createImageData(size, size)
    fillRect(shooter, 3, 3, size-4, size-4, 200, 0, 0, 255)
    fillRect(shooter, size-5, size/2-1, size-3, size/2+1, 255, 255, 0, 255)
    saveImage(shooter, basePath .. "enemy_shooter.png")

    -- Enemy Bouncer: Red diamond
    local bouncer = createImageData(size, size)
    fillDiamond(bouncer, size/2, size/2, 6, 255, 0, 0, 255)
    saveImage(bouncer, basePath .. "enemy_bouncer.png")

    -- Enemy Zigzag: Red triangle
    local zigzag = createImageData(size, size)
    fillTriangle(zigzag, size/2, size/2, 6, 255, 0, 0, 255)
    saveImage(zigzag, basePath .. "enemy_zigzag.png")

    -- Enemy Teleporter: Red cross/plus
    local teleporter = createImageData(size, size)
    fillCross(teleporter, size/2, size/2, 6, 2, 255, 0, 0, 255)
    saveImage(teleporter, basePath .. "enemy_teleporter.png")

    -- Background: Dark blue starfield (32x32 tileable)
    local bg = createImageData(32, 32)
    -- Fill with dark blue
    fillRect(bg, 0, 0, 31, 31, 10, 10, 30, 255)
    -- Add some white stars
    local stars = {
        {2, 5}, {8, 12}, {15, 3}, {22, 18}, {28, 9},
        {5, 25}, {18, 28}, {11, 8}, {25, 22}, {7, 15}
    }
    for _, star in ipairs(stars) do
        setPixel(bg, star[1], star[2], 255, 255, 255, 255)
    end
    saveImage(bg, basePath .. "background.png")

    print("\nDodge base_1 placeholders generated successfully!")
end

-- Main execution
local function main()
    print("=== Placeholder Sprite Generator ===")
    print("Generating sprites for dodge/base_1...")
    print("")

    generateDodgePlaceholders()

    print("")
    print("All placeholders generated!")
    print("Sprites use canonical red+yellow palette for palette swapping.")
    print("Next: Run the game to test Phase 2.3 integration.")
end

-- If running as standalone script
if arg and arg[0] and arg[0]:match("generate_placeholder_sprites") then
    main()
    love.event.quit()
end

return {
    generate = main
}
