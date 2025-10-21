-- src/utils/solitaire_fronts.lua
-- Discovers and draws Solitaire card fronts from assets/sprites/solitare/fronts/

local Paths = require('src.paths')

local Fronts = {}
local BASE = Paths.assets.sprites .. 'solitare/fronts/'

-- Cache: map key like "H-A", "D-10" to love Image
local cache = {}
local indexed = false
local files = {} -- key -> file path

local function set_file(key, path, opts)
    if not files[key] then
        files[key] = path
        return
    end
    if opts and opts.prefer then
        files[key] = path
    end
end

local function normalize_suit_from_dir(dirname)
    local d = dirname:lower()
    if d == 'hearts' or d == 'redhearts' then return 'H' end
    if d == 'spades' or d == 'blackhearts' then return 'S' end
    if d == 'clubs' then return 'C' end
    if d == 'diamonds' or d == 'diamon' or d == 'diamons' then return 'D' end
    return nil
end

local function to_upper_rank(r)
    local rr = tostring(r)
    if rr == 'a' then return 'A' end
    if rr == 'j' then return 'J' end
    if rr == 'q' then return 'Q' end
    if rr == 'k' then return 'K' end
    return rr -- numbers as-is (2..10)
end

local function crawl(dir, suit_hint)
    local ok, items = pcall(love.filesystem.getDirectoryItems, dir)
    if not ok or not items then return end
    for _, name in ipairs(items) do
        local path = dir .. name
        local ok2, inf = pcall(love.filesystem.getInfo, path)
        if ok2 and inf then
            if inf.type == 'directory' then
                -- Derive a suit hint from folder name if present
                local suit_from_dir = normalize_suit_from_dir(name) or suit_hint
                crawl(path .. '/', suit_from_dir)
            else
                local lower = name:lower()
                if lower:match('%.png$') then
                    -- Try new scheme: within suit folder, filenames like a.png, k.png, q.png, j.png, or 2.png..10.png
                    local r1 = lower:match('^([ajqk])%.png$') or lower:match('^([2-9])%.png$') or lower:match('^(10)%.png$')
                    if r1 and suit_hint then
                        local rank = to_upper_rank(r1)
                        local key = suit_hint .. '-' .. rank
                        set_file(key, path, { prefer = true })
                    else
                        -- Fallback to old pattern: H10.png, SA.png, etc.
                        local suit, rank = name:match('^([HDCS])(10|[2-9]|[AJQK])%.png$')
                        if suit and rank then
                            local key = suit .. '-' .. rank
                            -- If this came from a blackHearts path and suit is H, also map to spades as fallback
                            if lower:find('blackhearts', 1, true) and suit == 'H' then
                                local sp_key = 'S-' .. rank
                                if not files[sp_key] then files[sp_key] = path end
                            end
                            set_file(key, path)
                        end
                    end
                end
            end
        end
    end
end

local function ensure_indexed()
    if indexed then return end
    indexed = true
    crawl(BASE, nil)
end

local function rank_to_code(rank)
    if rank == 1 then return 'A' end
    if rank >= 2 and rank <= 10 then return tostring(rank) end
    if rank == 11 then return 'J' end
    if rank == 12 then return 'Q' end
    if rank == 13 then return 'K' end
    return tostring(rank)
end

local function suit_to_letter(suit_index)
    -- Assuming: 1=Spades(black), 2=Hearts(red), 3=Clubs(black), 4=Diamonds(red)
    if suit_index == 1 then return 'S' end
    if suit_index == 2 then return 'H' end
    if suit_index == 3 then return 'C' end
    if suit_index == 4 then return 'D' end
    return 'S'
end

local function get_image(suit_index, rank)
    ensure_indexed()
    local letter = suit_to_letter(suit_index)
    local code = rank_to_code(rank)
    local key = letter .. '-' .. code
    if cache[key] ~= nil then return cache[key] end
    local file = files[key]
    if not file then cache[key] = false; return nil end
    local ok, img = pcall(love.graphics.newImage, file)
    if ok and img then cache[key] = img; return img end
    cache[key] = false
    return nil
end

function Fronts.drawFront(suit_index, rank, x, y, w, h)
    local img = get_image(suit_index, rank)
    if not img then return false end
    love.graphics.setColor(1,1,1)
    local iw, ih = img:getWidth(), img:getHeight()
    local sx, sy = w/iw, h/ih
    love.graphics.draw(img, x, y, 0, sx, sy)
    return true
end

return Fronts
