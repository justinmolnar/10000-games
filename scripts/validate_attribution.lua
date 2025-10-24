#!/usr/bin/env lua

--[[
Attribution Validation Script

Usage:
  lua scripts/validate_attribution.lua

This script scans the project for asset files and checks if they have
corresponding entries in assets/data/attribution.json.

It will report:
  - Assets missing attribution
  - Total assets scanned
  - Attribution coverage percentage
]]

-- Try to use LÖVE's filesystem if available, otherwise fall back to lfs
local love_available = pcall(require, "love.filesystem")

local function readFile(path)
    if love_available then
        local success, content = pcall(love.filesystem.read, path)
        if success then return content end
        return nil
    else
        local file = io.open(path, "r")
        if not file then return nil end
        local content = file:read("*all")
        file:close()
        return content
    end
end

-- Simple JSON decoder (minimal implementation)
local function decodeJSON(str)
    -- This is a simplified version - you should use the proper json.lua in production
    -- For validation script purposes, we'll just use Lua's load with sanitization
    local json = require("lib.json")
    return json.decode(str)
end

-- Scan directory recursively for asset files
local function scanDirectory(dir, file_list)
    file_list = file_list or {}

    if love_available then
        local items = love.filesystem.getDirectoryItems(dir)
        for _, item in ipairs(items) do
            local path = dir .. "/" .. item
            local info = love.filesystem.getInfo(path)

            if info and info.type == "directory" then
                scanDirectory(path, file_list)
            elseif info and info.type == "file" then
                -- Check if it's an asset file
                if path:match("%.png$") or path:match("%.jpg$") or path:match("%.ogg$") or
                   path:match("%.wav$") or path:match("%.mp3$") or path:match("%.ttf$") or
                   path:match("%.glsl$") then
                    table.insert(file_list, path)
                end
            end
        end
    else
        -- Non-LÖVE implementation using lfs
        local lfs = require("lfs")
        for item in lfs.dir(dir) do
            if item ~= "." and item ~= ".." then
                local path = dir .. "/" .. item
                local attr = lfs.attributes(path)

                if attr.mode == "directory" then
                    scanDirectory(path, file_list)
                elseif attr.mode == "file" then
                    if path:match("%.png$") or path:match("%.jpg$") or path:match("%.ogg$") or
                       path:match("%.wav$") or path:match("%.mp3$") or path:match("%.ttf$") or
                       path:match("%.glsl$") then
                        table.insert(file_list, path)
                    end
                end
            end
        end
    end

    return file_list
end

-- Check if asset path matches any attribution entry (including wildcards)
local function hasAttribution(asset_path, attributions)
    asset_path = asset_path:gsub("\\", "/")

    for _, attr in ipairs(attributions) do
        local attr_path = attr.asset_path:gsub("\\", "/")

        -- Exact match
        if attr_path == asset_path then
            return true
        end

        -- Wildcard match
        if attr_path:find("*", 1, true) then
            local pattern = attr_path:gsub("%*", ".*")
            pattern = "^" .. pattern .. "$"
            if asset_path:match(pattern) then
                return true
            end
        end
    end

    return false
end

-- Main validation function
local function validateAttributions()
    print("=== Asset Attribution Validation ===\n")

    -- Load attribution data
    local attribution_content = readFile("assets/data/attribution.json")
    if not attribution_content then
        print("ERROR: Could not read assets/data/attribution.json")
        return 1
    end

    local success, data = pcall(decodeJSON, attribution_content)
    if not success or not data then
        print("ERROR: Could not parse attribution.json: " .. tostring(data))
        return 1
    end

    local attributions = data.attributions or {}
    print(string.format("Loaded %d attribution entries\n", #attributions))

    -- Scan for asset files
    print("Scanning for asset files...")
    local asset_dirs = {
        "assets/sprites",
        "assets/audio",
        "assets/fonts",
        "assets/shaders"
    }

    local all_assets = {}
    for _, dir in ipairs(asset_dirs) do
        local dir_assets = scanDirectory(dir)
        for _, asset in ipairs(dir_assets) do
            table.insert(all_assets, asset)
        end
    end

    print(string.format("Found %d asset files\n", #all_assets))

    -- Check each asset for attribution
    local missing = {}
    for _, asset in ipairs(all_assets) do
        if not hasAttribution(asset, attributions) then
            table.insert(missing, asset)
        end
    end

    -- Report results
    print("=== Results ===\n")

    if #missing == 0 then
        print("✓ All assets have attribution entries!")
    else
        print(string.format("✗ %d assets missing attribution:\n", #missing))
        for _, asset in ipairs(missing) do
            print("  - " .. asset)
        end
    end

    local coverage = ((#all_assets - #missing) / math.max(1, #all_assets)) * 100
    print(string.format("\nCoverage: %.1f%% (%d/%d assets attributed)\n",
                        coverage, #all_assets - #missing, #all_assets))

    return #missing > 0 and 1 or 0
end

-- Run validation
if love_available then
    -- Running within LÖVE
    print("Note: Run this script from the command line for best results")
    print("Example: lua scripts/validate_attribution.lua\n")
end

local exit_code = validateAttributions()

if not love_available then
    os.exit(exit_code)
end

return exit_code
