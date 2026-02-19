-- src/utils/wad_parser.lua: Parse Doom WAD files and convert to g3d vertex geometry

local WadParser = {}

--------------------------------------------------------------------------------
-- Binary reading helpers (0-based offsets, little-endian)
--------------------------------------------------------------------------------

local function u8(d, o) return string.byte(d, o + 1) end

local function u16(d, o)
    local a, b = string.byte(d, o + 1, o + 2)
    return a + b * 256
end

local function i16(d, o)
    local v = u16(d, o)
    return v < 32768 and v or v - 65536
end

local function u32(d, o)
    local a, b, c, e = string.byte(d, o + 1, o + 4)
    return a + b * 256 + c * 65536 + e * 16777216
end

local function str(d, o, n)
    return string.sub(d, o + 1, o + n):match("^[^%z]*") or ""
end

--------------------------------------------------------------------------------
-- WAD parsing
--------------------------------------------------------------------------------

function WadParser.findWadFiles()
    local wads = {}
    local items = love.filesystem.getDirectoryItems("assets/wads")
    for _, item in ipairs(items or {}) do
        if item:lower():match("%.wad$") then
            wads[#wads + 1] = "assets/wads/" .. item
        end
    end
    return wads
end

function WadParser.parse(file_path)
    local data, err = love.filesystem.read(file_path)
    if not data then return nil, err end
    return WadParser.parseFromData(data)
end

function WadParser.parseFromData(data)
    if #data < 12 then return nil, "WAD too small" end

    local wad = {}
    wad.id = str(data, 0, 4)
    if wad.id ~= "IWAD" and wad.id ~= "PWAD" then
        return nil, "Not a WAD file: " .. wad.id
    end

    wad.num_lumps = u32(data, 4)
    wad.dir_offset = u32(data, 8)

    -- Read directory
    wad.lumps = {}
    for i = 0, wad.num_lumps - 1 do
        local off = wad.dir_offset + i * 16
        wad.lumps[i + 1] = {
            offset = u32(data, off),
            size = u32(data, off + 4),
            name = str(data, off + 8, 8),
        }
    end

    -- Find map markers
    wad.maps = {}
    wad.map_order = {}
    for i, lump in ipairs(wad.lumps) do
        if lump.name:match("^E%dM%d$") or lump.name:match("^MAP%d%d$") then
            local map = {name = lump.name, lumps = {}}
            for j = i + 1, math.min(i + 12, #wad.lumps) do
                local l = wad.lumps[j]
                if l.name:match("^E%dM%d$") or l.name:match("^MAP%d%d$") then break end
                map.lumps[l.name] = l
            end
            wad.maps[lump.name] = map
            wad.map_order[#wad.map_order + 1] = lump.name
        end
    end

    wad.data = data
    return wad
end

function WadParser.getMapNames(wad)
    return wad.map_order or {}
end

function WadParser.loadMap(wad, map_name)
    local map = wad.maps[map_name]
    if not map then return nil end
    local data = wad.data
    local result = {}

    -- VERTEXES (4 bytes each)
    local vl = map.lumps["VERTEXES"]
    result.vertices = {}
    if vl and vl.size > 0 then
        for i = 0, vl.size / 4 - 1 do
            local off = vl.offset + i * 4
            result.vertices[i] = {x = i16(data, off), y = i16(data, off + 2)}
        end
    end

    -- SECTORS (26 bytes each)
    local sl = map.lumps["SECTORS"]
    result.sectors = {}
    if sl and sl.size > 0 then
        for i = 0, sl.size / 26 - 1 do
            local off = sl.offset + i * 26
            result.sectors[i] = {
                floor_height = i16(data, off),
                ceiling_height = i16(data, off + 2),
                floor_tex = str(data, off + 4, 8),
                ceiling_tex = str(data, off + 12, 8),
                light_level = i16(data, off + 20),
                special = i16(data, off + 22),
                tag = i16(data, off + 24),
            }
        end
    end

    -- SIDEDEFS (30 bytes each)
    local sdl = map.lumps["SIDEDEFS"]
    result.sidedefs = {}
    if sdl and sdl.size > 0 then
        for i = 0, sdl.size / 30 - 1 do
            local off = sdl.offset + i * 30
            result.sidedefs[i] = {
                x_offset = i16(data, off),
                y_offset = i16(data, off + 2),
                upper_tex = str(data, off + 4, 8),
                lower_tex = str(data, off + 12, 8),
                middle_tex = str(data, off + 20, 8),
                sector = u16(data, off + 28),
            }
        end
    end

    -- LINEDEFS (14 bytes each)
    local ll = map.lumps["LINEDEFS"]
    result.linedefs = {}
    if ll and ll.size > 0 then
        for i = 0, ll.size / 14 - 1 do
            local off = ll.offset + i * 14
            result.linedefs[i] = {
                v1 = u16(data, off),
                v2 = u16(data, off + 2),
                flags = u16(data, off + 4),
                special = u16(data, off + 6),
                tag = u16(data, off + 8),
                right_side = u16(data, off + 10),
                left_side = u16(data, off + 12),
            }
        end
    end

    -- THINGS (10 bytes each)
    local tl = map.lumps["THINGS"]
    result.things = {}
    if tl and tl.size > 0 then
        for i = 0, tl.size / 10 - 1 do
            local off = tl.offset + i * 10
            result.things[#result.things + 1] = {
                x = i16(data, off),
                y = i16(data, off + 2),
                angle = u16(data, off + 4),
                type = u16(data, off + 6),
                flags = u16(data, off + 8),
            }
        end
    end

    return result
end

--------------------------------------------------------------------------------
-- Sector polygon construction (boundary tracing from linedefs)
--------------------------------------------------------------------------------

local function buildSectorEdges(map_data, sector_idx)
    local edges = {}
    for _, line in pairs(map_data.linedefs) do
        if line.right_side < 65535 then
            local sd = map_data.sidedefs[line.right_side]
            if sd and sd.sector == sector_idx then
                edges[#edges + 1] = {from = line.v1, to = line.v2, used = false}
            end
        end
        if line.left_side < 65535 then
            local sd = map_data.sidedefs[line.left_side]
            if sd and sd.sector == sector_idx then
                edges[#edges + 1] = {from = line.v2, to = line.v1, used = false}
            end
        end
    end
    return edges
end

local function traceLoops(edges, vertices)
    local starts_at = {}
    for i, e in ipairs(edges) do
        if not starts_at[e.from] then starts_at[e.from] = {} end
        starts_at[e.from][#starts_at[e.from] + 1] = i
    end

    local loops = {}
    for i, e in ipairs(edges) do
        if not e.used then
            local loop = {}
            local start_v = e.from
            local current = e
            local safety = 0
            repeat
                current.used = true
                local v = vertices[current.from]
                if v then
                    loop[#loop + 1] = {x = v.x, y = v.y}
                end
                local next_list = starts_at[current.to]
                local found = false
                if next_list then
                    for _, ni in ipairs(next_list) do
                        if not edges[ni].used then
                            current = edges[ni]
                            found = true
                            break
                        end
                    end
                end
                safety = safety + 1
                if not found or safety > 10000 then break end
            until current.from == start_v

            if #loop >= 3 then
                loops[#loops + 1] = loop
            end
        end
    end
    return loops
end

--------------------------------------------------------------------------------
-- Ear clipping triangulation
--------------------------------------------------------------------------------

local function cross2D(ox, oy, ax, ay, bx, by)
    return (ax - ox) * (by - oy) - (ay - oy) * (bx - ox)
end

local function pointInTri(px, py, ax, ay, bx, by, cx, cy)
    local d1 = cross2D(px, py, ax, ay, bx, by)
    local d2 = cross2D(px, py, bx, by, cx, cy)
    local d3 = cross2D(px, py, cx, cy, ax, ay)
    return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))
end

local function earClip(polygon)
    if #polygon < 3 then return {} end
    if #polygon == 3 then
        return {{polygon[1], polygon[2], polygon[3]}}
    end

    local pts = {}
    for i, p in ipairs(polygon) do
        pts[i] = {x = p.x, y = p.y}
    end

    -- Compute signed area to determine winding
    local area = 0
    for i = 1, #pts do
        local j = i % #pts + 1
        area = area + pts[i].x * pts[j].y - pts[j].x * pts[i].y
    end
    if area < 0 then
        local rev = {}
        for i = #pts, 1, -1 do rev[#rev + 1] = pts[i] end
        pts = rev
    end

    local indices = {}
    for i = 1, #pts do indices[i] = i end

    local triangles = {}
    local attempts = 0
    local i = 1
    while #indices > 2 and attempts < #indices * 3 do
        local ni = #indices
        local pi = ((i - 2) % ni) + 1
        local ci = i
        local nxi = (i % ni) + 1

        local prev = pts[indices[pi]]
        local curr = pts[indices[ci]]
        local next_ = pts[indices[nxi]]

        local cx = cross2D(prev.x, prev.y, curr.x, curr.y, next_.x, next_.y)
        if cx > 0 then
            local is_ear = true
            for j = 1, ni do
                if j ~= pi and j ~= ci and j ~= nxi then
                    local p = pts[indices[j]]
                    if pointInTri(p.x, p.y, prev.x, prev.y, curr.x, curr.y, next_.x, next_.y) then
                        is_ear = false
                        break
                    end
                end
            end
            if is_ear then
                triangles[#triangles + 1] = {
                    {x = prev.x, y = prev.y},
                    {x = curr.x, y = curr.y},
                    {x = next_.x, y = next_.y},
                }
                table.remove(indices, ci)
                attempts = 0
                if i > #indices then i = 1 end
            else
                i = (i % #indices) + 1
                attempts = attempts + 1
            end
        else
            i = (i % #indices) + 1
            attempts = attempts + 1
        end
    end
    return triangles
end

--------------------------------------------------------------------------------
-- Thing classification
--------------------------------------------------------------------------------

local THING_CATEGORY = {}
-- Player starts
for _, t in ipairs({1, 2, 3, 4, 11}) do THING_CATEGORY[t] = "player" end
-- Monsters
for _, t in ipairs({3004, 9, 65, 3001, 3002, 3003, 68, 71, 66, 67, 64, 7, 16, 69, 3006, 3005, 58, 84}) do
    THING_CATEGORY[t] = "monster"
end
-- Weapons
for _, t in ipairs({2001, 2002, 2003, 2004, 2005, 2006}) do THING_CATEGORY[t] = "weapon" end
-- Health/armor
for _, t in ipairs({2011, 2012, 2013, 2014, 2015, 2018, 2019}) do THING_CATEGORY[t] = "health" end
-- Keys
THING_CATEGORY[13] = "key_red"
THING_CATEGORY[5] = "key_blue"
THING_CATEGORY[6] = "key_yellow"
THING_CATEGORY[38] = "key_red"    -- skull keys
THING_CATEGORY[39] = "key_blue"
THING_CATEGORY[40] = "key_yellow"

local THING_COLORS = {
    player     = {0.2, 0.9, 0.3},
    monster    = {0.9, 0.2, 0.2},
    weapon     = {0.9, 0.6, 0.1},
    health     = {0.2, 0.5, 0.9},
    key_red    = {1.0, 0.2, 0.2},
    key_blue   = {0.2, 0.2, 1.0},
    key_yellow = {1.0, 1.0, 0.2},
    other      = {0.5, 0.5, 0.5},
}

local THING_SIZES = {
    player  = 0.5,
    monster = 0.6,
    weapon  = 0.35,
    health  = 0.25,
    other   = 0.2,
}

--------------------------------------------------------------------------------
-- Geometry building: convert parsed map data to g3d vertex arrays
--------------------------------------------------------------------------------

local function addWallQuad(verts, x1, y1, x2, y2, bottom, top, nx, ny, r, g, b)
    if top <= bottom then return end
    verts[#verts + 1] = {x1, y1, bottom, 0, 1, nx, ny, 0, r, g, b, 1}
    verts[#verts + 1] = {x2, y2, bottom, 1, 1, nx, ny, 0, r, g, b, 1}
    verts[#verts + 1] = {x2, y2, top,    1, 0, nx, ny, 0, r, g, b, 1}
    verts[#verts + 1] = {x1, y1, bottom, 0, 1, nx, ny, 0, r, g, b, 1}
    verts[#verts + 1] = {x2, y2, top,    1, 0, nx, ny, 0, r, g, b, 1}
    verts[#verts + 1] = {x1, y1, top,    0, 0, nx, ny, 0, r, g, b, 1}
end

function WadParser.buildGeometry(map_data, scale)
    scale = scale or (1 / 32)
    local verts = map_data.vertices
    local lines = map_data.linedefs
    local sides = map_data.sidedefs
    local sectors = map_data.sectors

    local wall_verts = {}
    local floor_verts = {}
    local ceil_verts = {}
    local thing_list = {}
    local collision_lines = {}
    local sector_regions = {}

    local max_step = 24 * scale     -- max step-up height
    local min_gap = 56 * scale      -- min ceiling gap for player

    -- Build collision lines from linedefs
    for _, line in pairs(lines) do
        local v1 = verts[line.v1]
        local v2 = verts[line.v2]
        if v1 and v2 then
            local x1, y1 = v1.x * scale, v1.y * scale
            local x2, y2 = v2.x * scale, v2.y * scale
            local blocking = false

            if line.left_side >= 65535 then
                blocking = true  -- one-sided = solid
            else
                local impassable = (line.flags % 2) == 1
                if impassable then
                    blocking = true
                else
                    local rsd = line.right_side < 65535 and sides[line.right_side]
                    local lsd = sides[line.left_side]
                    if rsd and lsd then
                        local rsec = sectors[rsd.sector]
                        local lsec = sectors[lsd.sector]
                        if rsec and lsec then
                            local step = math.abs(rsec.floor_height - lsec.floor_height) * scale
                            if step > max_step then blocking = true end
                            local gap_ceil = math.min(rsec.ceiling_height, lsec.ceiling_height) * scale
                            local gap_floor = math.max(rsec.floor_height, lsec.floor_height) * scale
                            if gap_ceil - gap_floor < min_gap then blocking = true end
                        end
                    end
                end
            end

            if blocking then
                collision_lines[#collision_lines + 1] = {x1 = x1, y1 = y1, x2 = x2, y2 = y2}
            end
        end
    end

    -- Build walls from linedefs (visual)
    for _, line in pairs(lines) do
        local v1 = verts[line.v1]
        local v2 = verts[line.v2]
        if not v1 or not v2 then goto skip_line end

        local x1, y1 = v1.x * scale, v1.y * scale
        local x2, y2 = v2.x * scale, v2.y * scale

        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 0.001 then goto skip_line end
        local nx, ny = dy / len, -dx / len  -- right-facing normal

        -- Right sidedef
        if line.right_side < 65535 then
            local sd = sides[line.right_side]
            if sd then
                local sec = sectors[sd.sector]
                if sec then
                    local fh = sec.floor_height * scale
                    local ch = sec.ceiling_height * scale
                    local light = math.max(0.15, sec.light_level / 255)
                    local wr, wg, wb = light * 0.7, light * 0.65, light * 0.6

                    if line.left_side >= 65535 then
                        -- One-sided: full wall
                        addWallQuad(wall_verts, x1, y1, x2, y2, fh, ch, nx, ny, wr, wg, wb)
                    else
                        local lsd = sides[line.left_side]
                        if lsd then
                            local bsec = sectors[lsd.sector]
                            if bsec then
                                local bfh = bsec.floor_height * scale
                                local bch = bsec.ceiling_height * scale
                                -- Upper wall
                                if ch > bch then
                                    addWallQuad(wall_verts, x1, y1, x2, y2, bch, ch, nx, ny, wr * 0.9, wg * 0.9, wb * 0.9)
                                end
                                -- Lower wall
                                if fh < bfh then
                                    addWallQuad(wall_verts, x1, y1, x2, y2, fh, bfh, nx, ny, wr * 0.85, wg * 0.85, wb * 0.85)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Left sidedef
        if line.left_side < 65535 then
            local sd = sides[line.left_side]
            if sd then
                local sec = sectors[sd.sector]
                if sec then
                    local fh = sec.floor_height * scale
                    local ch = sec.ceiling_height * scale
                    local light = math.max(0.15, sec.light_level / 255)
                    local wr, wg, wb = light * 0.7, light * 0.65, light * 0.6
                    local rnx, rny = -nx, -ny

                    if line.right_side >= 65535 then
                        addWallQuad(wall_verts, x2, y2, x1, y1, fh, ch, rnx, rny, wr, wg, wb)
                    else
                        local rsd = sides[line.right_side]
                        if rsd then
                            local bsec = sectors[rsd.sector]
                            if bsec then
                                local bfh = bsec.floor_height * scale
                                local bch = bsec.ceiling_height * scale
                                if ch > bch then
                                    addWallQuad(wall_verts, x2, y2, x1, y1, bch, ch, rnx, rny, wr * 0.9, wg * 0.9, wb * 0.9)
                                end
                                if fh < bfh then
                                    addWallQuad(wall_verts, x2, y2, x1, y1, fh, bfh, rnx, rny, wr * 0.85, wg * 0.85, wb * 0.85)
                                end
                            end
                        end
                    end
                end
            end
        end

        ::skip_line::
    end

    -- Build floors and ceilings from sector polygons
    for sec_idx, sector in pairs(sectors) do
        local edges = buildSectorEdges(map_data, sec_idx)
        if #edges == 0 then goto skip_sector end

        local loops = traceLoops(edges, verts)
        local fh = sector.floor_height * scale
        local ch = sector.ceiling_height * scale
        local light = math.max(0.15, sector.light_level / 255)

        for _, loop in ipairs(loops) do
            local scaled = {}
            for _, p in ipairs(loop) do
                scaled[#scaled + 1] = {x = p.x * scale, y = p.y * scale}
            end

            -- Save sector region for collision (floor detection)
            sector_regions[#sector_regions + 1] = {
                polygon = scaled,
                floor_h = fh,
                ceiling_h = ch,
            }

            local ok, triangles = pcall(earClip, scaled)
            if not ok then goto skip_sector end

            for _, tri in ipairs(triangles) do
                -- Floor (normal up)
                local fr, fg, fb = light * 0.45, light * 0.45, light * 0.4
                for _, p in ipairs(tri) do
                    floor_verts[#floor_verts + 1] = {p.x, p.y, fh, p.x / 2, p.y / 2, 0, 0, 1, fr, fg, fb, 1}
                end
                -- Ceiling (normal down, reverse winding)
                local cr, cg, cb = light * 0.35, light * 0.35, light * 0.38
                for j = 3, 1, -1 do
                    local p = tri[j]
                    ceil_verts[#ceil_verts + 1] = {p.x, p.y, ch, p.x / 2, p.y / 2, 0, 0, -1, cr, cg, cb, 1}
                end
            end
        end

        ::skip_sector::
    end

    -- Collect things with category info
    for _, thing in ipairs(map_data.things) do
        local cat = THING_CATEGORY[thing.type] or "other"
        local color = THING_COLORS[cat] or THING_COLORS.other
        local sz = THING_SIZES[cat] or THING_SIZES.other
        thing_list[#thing_list + 1] = {
            x = thing.x * scale,
            y = thing.y * scale,
            type = thing.type,
            angle = thing.angle,
            category = cat,
            color = color,
            size = sz,
        }
    end

    -- Find player 1 start
    local player_start = nil
    for _, t in ipairs(thing_list) do
        if t.type == 1 then
            player_start = t
            break
        end
    end

    return {
        wall_verts = wall_verts,
        floor_verts = floor_verts,
        ceil_verts = ceil_verts,
        things = thing_list,
        player_start = player_start,
        collision_lines = collision_lines,
        sector_regions = sector_regions,
    }
end

return WadParser
