-- src/utils/url_resolver.lua
-- URL resolver for web browser - maps virtual URLs to filesystem paths

local URLResolver = {}

-- Base web directory
URLResolver.web_base = "assets/data/web"

-- Domain map cache (automatically populated)
URLResolver.domain_map = {}

-- Default domain if none specified
URLResolver.default_domain = "www.home.com"

-- Scan web directory and build domain map automatically
function URLResolver.scanWebDirectory()
    URLResolver.domain_map = {}

    local web_dir = URLResolver.web_base
    local items = love.filesystem.getDirectoryItems(web_dir)

    for _, item in ipairs(items) do
        local path = web_dir .. "/" .. item
        local info = love.filesystem.getInfo(path)

        if info and info.type == "directory" then
            -- Folder name IS the domain
            -- ONLY www.foldername.com works - nothing else
            URLResolver.domain_map["www." .. item .. ".com"] = path
        end
    end

    -- Special case: file:// for direct access
    URLResolver.domain_map["file://"] = web_dir
end

-- Initialize on load
URLResolver.scanWebDirectory()

-- Parse URL into components
-- Supports:
--   www.cybergames.com/about
--   cybergames.com/products.html
--   /about (relative to current domain)
--   about.html (relative to current path)
--   assets/data/web/test.html (direct filesystem path)
function URLResolver.parseURL(url)
    if not url or url == "" then
        return nil
    end

    -- Strip protocol if present (http://, https://, file://)
    local stripped_url = url:gsub("^https?://", ""):gsub("^file://", "")

    -- Check if it's a direct filesystem path (starts with assets/)
    if stripped_url:match("^assets/") then
        return {
            type = "filesystem",
            path = stripped_url
        }
    end

    -- ONLY accept www.X.com format - nothing else
    local domain, path = stripped_url:match("^(www%.[^/]+%.com)(/.*)$")
    if not domain then
        -- No slash found - check if it's just domain
        if stripped_url:match("^www%.[^/]+%.com$") then
            -- Just domain, no path
            domain = stripped_url
            path = "/"
        else
            -- Not www.X.com format - treat as relative path
            return {
                type = "relative",
                path = stripped_url
            }
        end
    end

    -- Normalize domain
    domain = domain:lower()

    return {
        type = "domain",
        domain = domain,
        path = path or "/"
    }
end

-- Resolve URL to filesystem path
-- current_url: The current page's URL (for relative resolution)
-- href: The URL to resolve (from link href)
function URLResolver.resolve(href, current_url)
    if not href or href == "" then
        return nil
    end

    -- Parse the href
    local parsed = URLResolver.parseURL(href)
    if not parsed then
        return nil
    end

    -- Handle different URL types
    if parsed.type == "filesystem" then
        -- Direct filesystem path - use as-is
        return parsed.path

    elseif parsed.type == "domain" then
        -- Domain-based URL - map to filesystem
        local base_path = URLResolver.domain_map[parsed.domain]
        if not base_path then
            -- Unknown domain - use default
            base_path = URLResolver.domain_map[URLResolver.default_domain]
        end

        -- Normalize path
        local file_path = parsed.path
        if file_path == "/" or file_path == "" then
            file_path = "/index.html"
        elseif file_path == "/.html" or file_path == "/.htm" then
            -- Invalid: just domain with .html extension - use index
            file_path = "/index.html"
        elseif not file_path:match("%.html$") and not file_path:match("%.htm$") then
            -- No extension - add .html
            file_path = file_path .. ".html"
        end

        -- Remove leading slash
        file_path = file_path:gsub("^/", "")

        return base_path .. "/" .. file_path

    elseif parsed.type == "relative" then
        -- Relative path - resolve against current URL
        return URLResolver.resolveRelative(parsed.path, current_url)
    end

    return nil
end

-- Resolve relative path against current URL
function URLResolver.resolveRelative(relative_path, current_url)
    if not current_url then
        -- No current URL - treat as domain-less path
        return URLResolver.resolve(URLResolver.default_domain .. "/" .. relative_path, nil)
    end

    -- Parse current URL to get its domain and directory
    local current_parsed = URLResolver.parseURL(current_url)

    if current_parsed and current_parsed.type == "filesystem" then
        -- Current URL is filesystem path - use directory resolution
        local base_dir = current_parsed.path:match("(.*/)")
        if base_dir then
            return base_dir .. relative_path
        else
            return "assets/data/web/" .. relative_path
        end
    elseif current_parsed and current_parsed.type == "domain" then
        -- Current URL has domain - preserve domain, resolve path
        local current_dir = current_parsed.path:match("(.*/)")
        if current_dir then
            return URLResolver.resolve(current_parsed.domain .. current_dir .. relative_path, nil)
        else
            return URLResolver.resolve(current_parsed.domain .. "/" .. relative_path, nil)
        end
    end

    -- Fallback - try to extract directory from current_url string
    local base_dir = current_url:match("(.*/)")
    if base_dir then
        return base_dir .. relative_path
    end

    return "assets/data/web/" .. relative_path
end

-- Get display URL for filesystem path (reverse mapping)
-- Converts assets/data/web/cybergames/about.html -> www.cybergames.com/about
function URLResolver.getDisplayURL(filesystem_path)
    if not filesystem_path then
        return ""
    end

    -- Try to match against domain mappings
    for domain, base_path in pairs(URLResolver.domain_map) do
        if filesystem_path:match("^" .. base_path:gsub("([%.%-])", "%%%1")) then
            -- Extract the path after base
            local path = filesystem_path:sub(#base_path + 1)

            -- Clean up path
            path = path:gsub("^/", "") -- Remove leading slash
            path = path:gsub("index%.html$", "") -- Remove index.html
            path = path:gsub("%.html$", "") -- Remove .html extension

            if path == "" then
                return domain
            else
                return domain .. "/" .. path
            end
        end
    end

    -- No match - return filesystem path as-is
    return filesystem_path
end

return URLResolver
