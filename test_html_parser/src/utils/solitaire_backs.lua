-- src/utils/solitaire_backs.lua
-- Discovers and draws Solitaire card backs from assets/sprites/solitare/backs/

local Paths = require('src.paths')

local Backs = {}
local DIR = Paths.assets.sprites .. 'solitare/backs/'

-- Cached metadata and resources
local cached_list = nil           -- simple list of {id,name}
local defs = {}                   -- id -> { type='static'|'frames', file?, dir?, fps?, frames?, image? }

local function title_case(id)
    -- Convert id like "classic_blue" or "classic-blue" to "Classic Blue"
    local s = tostring(id or ''):gsub('[_%-]+',' ')
    return (s:gsub("%f[%a].", string.upper))
end

local function read_json(path)
    local ok, contents = pcall(love.filesystem.read, path)
    if not ok or not contents then return nil end
    local ok2, data = pcall(require('json').decode, contents)
    if ok2 and type(data) == 'table' then return data end
    return nil
end

local function info(path)
    local ok, inf = pcall(love.filesystem.getInfo, path)
    if ok then return inf end
    return nil
end

local function ensure_list()
    if cached_list then return end
    local ok, items = pcall(love.filesystem.getDirectoryItems, DIR)
    if not ok or not items then cached_list = {}; return end
    local list = {}
    local seen = {}
    -- Include subdirectories as animated backs (frames)
    for _, name in ipairs(items) do
        local inf = info(DIR .. name)
        if inf and inf.type == 'directory' then
            local id = name
            seen[id] = true
            defs[id] = { type='frames', dir = DIR .. id .. '/', fps = 6 }
            -- Optional sidecar json for metadata (fps)
            local meta = read_json(DIR .. id .. '.json')
            if meta and meta.fps then defs[id].fps = tonumber(meta.fps) or defs[id].fps end
            table.insert(list, { id = id, name = title_case(id) })
        end
    end
    -- Include files (.png only)
    for _, name in ipairs(items) do
        local base = name:match('^(.+)%.png$') or name:match('^(.+)%.PNG$')
        if base and not seen[base] then
            seen[base] = true
            defs[base] = { type='static', file = DIR .. name }
            table.insert(list, { id = base, name = title_case(base) })
        end
    end
    table.sort(list, function(a,b) return a.name:lower() < b.name:lower() end)
    cached_list = list
end

function Backs.list()
    ensure_list()
    return cached_list
end

function Backs.getDefaultId()
    ensure_list()
    return (cached_list[1] and cached_list[1].id) or nil
end

local function load_frames_for(id, def)
    if def.frames ~= nil or def.type ~= 'frames' then return end
    def.frames = {}
    -- Load png frames from the directory, sorted
    local ok, files = pcall(love.filesystem.getDirectoryItems, def.dir)
    if ok and files then
        table.sort(files)
        for _, fname in ipairs(files) do
            if fname:match('%.png$') or fname:match('%.PNG$') then
                local ok2, img = pcall(love.graphics.newImage, def.dir .. fname)
                if ok2 and img then table.insert(def.frames, img) end
            end
        end
    end
end

local function load_image_for(id, def)
    if def.image ~= nil or def.type ~= 'static' then return end
    local ok, img = pcall(love.graphics.newImage, def.file)
    if ok and img then def.image = img else def.image = false end
end

-- Returns true if drawn
local function draw_image(img, x, y, w, h)
    if not img then return false end
    love.graphics.setColor(1,1,1)
    local iw, ih = img:getWidth(), img:getHeight()
    local sx, sy = w/iw, h/ih
    love.graphics.draw(img, x, y, 0, sx, sy)
    return true
end

function Backs.drawBack(id, x, y, w, h)
    if not id or id == '' then return false end
    ensure_list()
    local def = defs[id]
    if not def then return false end
    if def.type == 'frames' then
        load_frames_for(id, def)
        if def.frames and #def.frames > 0 then
            local fps = def.fps or 6
            local t = love.timer.getTime()
            local idx = (math.floor(t * fps) % #def.frames) + 1
            return draw_image(def.frames[idx], x, y, w, h)
        end
        return false
    else
        load_image_for(id, def)
        -- Note: if def.file was a .gif, LÖVE may not load it; image=false covers that.
        if def.image and def.image ~= false then
            return draw_image(def.image, x, y, w, h)
        end
        return false
    end
end

return Backs
