-- src/utils/wallpapers.lua
local Paths = require('src.paths')

local Wallpapers = {}

-- Cache discovered wallpapers
local _items = nil

local function isImageFile(name)
    local lower = string.lower(name)
    return lower:match('%.png$') or lower:match('%.jpg$') or lower:match('%.jpeg$')
end

local function listDir(path)
    local ok, files = pcall(love.filesystem.getDirectoryItems, path)
    if not ok or not files then return {} end
    table.sort(files)
    return files
end

local function makeId(base)
    return base:gsub("[^%w_%-]+", "_")
end

local function stripExt(name)
    return name:gsub('%.[^%.]+$', '')
end

local function normalizeId(id)
    local s = tostring(id or ''):lower()
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    s = s:gsub('%.png$', ''):gsub('%.jpg$', ''):gsub('%.jpeg$', '')
    s = s:gsub('[^%w_%-]+','_')
    return s
end

function Wallpapers.list()
    if _items then return _items end
    local base = Paths.assets.wallpaper or 'assets/wallpaper/'
    local out = {}
    local files = listDir(base)
    for _,f in ipairs(files) do
        local full = base .. f
        local info_ok, info = pcall(love.filesystem.getInfo, full)
        if info_ok and info and info.type == 'file' and isImageFile(f) then
            local id_base = makeId(stripExt(f))
            local nid = normalizeId(f)
            table.insert(out, { id = id_base, _nid = nid, name = f, path = full })
        end
        -- Folders could be future animated wallpapers; skip for now
    end
    _items = out
    return out
end

local _image_cache = {}
local _warned_lookup = {}

local function _debugDumpItems()
    local items = Wallpapers.list()
    --
    for i, it in ipairs(items) do
        print(string.format('  [%d] id=%s _nid=%s name=%s path=%s', i, tostring(it.id), tostring(it._nid), tostring(it.name), tostring(it.path)))
    end
end

local function getImage(item)
    if not item then return nil end
    if _image_cache[item.path] then return _image_cache[item.path] end
    local ok, img = pcall(love.graphics.newImage, item.path)
    if ok and img then
        _image_cache[item.path] = img
        return img
    end
    return nil
end

-- Draw a scaled preview that preserves aspect and fills/letterboxes within w x h
function Wallpapers.drawPreview(id_or_item, x, y, w, h)
    local item = id_or_item
    if type(id_or_item) ~= 'table' then
        item = Wallpapers.getItemById(id_or_item)
    end
    local img = item and getImage(item)
    if not img then return false end
    local iw, ih = img:getWidth(), img:getHeight()
    local sx = w / iw
    local sy = h / ih
    local s = math.min(sx, sy)
    local dw, dh = iw * s, ih * s
    local dx = x + (w - dw) / 2
    local dy = y + (h - dh) / 2
    love.graphics.setColor(1,1,1)
    love.graphics.draw(img, dx, dy, 0, s, s)
    return true
end

function Wallpapers.getDefaultId()
    local list = Wallpapers.list()
    return list[1] and list[1].id or nil
end

-- Public helpers
function Wallpapers.getItemById(id)
    if not id then return nil end
    local nid = normalizeId(id)
    for _,it in ipairs(Wallpapers.list()) do
        if it.id == id or it._nid == nid then return it end
        -- Extra tolerance: if saved value was a path or prefixed string, accept suffix match on normalized id
        if nid and it._nid and #nid >= #it._nid then
            if nid:sub(#nid - #it._nid + 1) == it._nid then return it end
        end
    end
    -- One-time debug output for missing lookups
    if not _warned_lookup[nid or tostring(id)] then
        _warned_lookup[nid or tostring(id)] = true
    -- lookup diagnostics removed
    end
    return nil
end

function Wallpapers.getImageCached(id_or_item)
    local item = id_or_item
    if type(id_or_item) ~= 'table' then item = Wallpapers.getItemById(id_or_item) end
    return getImage(item)
end

-- Draw scaled to cover area (like desktop wallpaper)
function Wallpapers.drawCover(id_or_item, x, y, w, h)
    local item = id_or_item
    if type(id_or_item) ~= 'table' then
        item = Wallpapers.getItemById(id_or_item)
    end
    local img = item and getImage(item)
    if not img then return false end
    local iw, ih = img:getWidth(), img:getHeight()
    local s = math.max(w / iw, h / ih)
    local src_w = w / s
    local src_h = h / s
    local src_x = (iw - src_w) / 2
    local src_y = (ih - src_h) / 2
    if src_x < 0 then src_x = 0 end
    if src_y < 0 then src_y = 0 end
    if src_x + src_w > iw then src_w = iw - src_x end
    if src_y + src_h > ih then src_h = ih - src_y end
    local quad = love.graphics.newQuad(src_x, src_y, src_w, src_h, iw, ih)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(img, quad, x, y, 0, s, s)
    return true
end

-- Fit (contain), Center, Stretch, Tile
function Wallpapers.drawFit(id_or_item, x, y, w, h)
    local item = id_or_item
    if type(id_or_item) ~= 'table' then item = Wallpapers.getItemById(id_or_item) end
    local img = item and getImage(item)
    if not img then return false end
    local iw, ih = img:getWidth(), img:getHeight()
    local s = math.min(w / iw, h / ih)
    local dw, dh = iw * s, ih * s
    local dx = x + (w - dw) / 2
    local dy = y + (h - dh) / 2
    love.graphics.setColor(1,1,1)
    love.graphics.draw(img, dx, dy, 0, s, s)
    return true
end

function Wallpapers.drawStretch(id_or_item, x, y, w, h)
    local item = id_or_item
    if type(id_or_item) ~= 'table' then item = Wallpapers.getItemById(id_or_item) end
    local img = item and getImage(item)
    if not img then return false end
    local iw, ih = img:getWidth(), img:getHeight()
    local sx, sy = w/iw, h/ih
    love.graphics.setColor(1,1,1)
    love.graphics.draw(img, x, y, 0, sx, sy)
    return true
end

function Wallpapers.drawCenter(id_or_item, x, y, w, h)
    local item = id_or_item
    if type(id_or_item) ~= 'table' then item = Wallpapers.getItemById(id_or_item) end
    local img = item and getImage(item)
    if not img then return false end
    local iw, ih = img:getWidth(), img:getHeight()
    -- If image is larger than box, scale down to fit but never upscale
    local s = math.min(1, math.min(w / iw, h / ih))
    local dw, dh = iw * s, ih * s
    local dx = x + (w - dw)/2
    local dy = y + (h - dh)/2
    love.graphics.setColor(1,1,1)
    love.graphics.draw(img, dx, dy, 0, s, s)
    return true
end

function Wallpapers.drawTile(id_or_item, x, y, w, h)
    local item = id_or_item
    if type(id_or_item) ~= 'table' then item = Wallpapers.getItemById(id_or_item) end
    local img = item and getImage(item)
    if not img then return false end
    local iw, ih = img:getWidth(), img:getHeight()
    love.graphics.setColor(1,1,1)
    local cols = math.ceil(w / iw)
    local rows = math.ceil(h / ih)
    for r=0,rows-1 do
        for c=0,cols-1 do
            love.graphics.draw(img, x + c*iw, y + r*ih)
        end
    end
    return true
end

return Wallpapers
