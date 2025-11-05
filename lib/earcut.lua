--[[
    Earcut - Fast polygon triangulation with holes
    Lua port adapted for LÖVE2D/standard Lua
    Original: https://github.com/mapbox/earcut
]]

local Earcut = {}

-- Simple 0-indexed array wrapper for standard Lua
local function ZeroArray(tbl)
    return setmetatable({_data = tbl or {}}, {
        __index = function(t, k)
            if k == "push" then
                return function(_, v) table.insert(t._data, v) end
            elseif k == "sort" then
                return function(_, fn) table.sort(t._data, fn) end
            end
            return t._data[k + 1]
        end,
        __newindex = function(t, k, v)
            t._data[k + 1] = v
        end,
        __len = function(t)
            return #t._data
        end
    })
end

local function getArray(zarr)
    return zarr._data
end

-- Node constructor
local function Node(i, x, y)
    return {
        i = i,
        x = x,
        y = y,
        prev = nil,
        next = nil,
        z = nil,
        prevZ = nil,
        nextZ = nil,
        steiner = false
    }
end

-- Signed area of a triangle
local function area(p, q, r)
    return (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
end

-- Check if two points are equal
local function equals(p1, p2)
    return p1.x == p2.x and p1.y == p2.y
end

-- Check if a point lies within a convex triangle
local function pointInTriangle(ax, ay, bx, by, cx, cy, px, py)
    return (cx - px) * (ay - py) - (ax - px) * (cy - py) >= 0 and
           (ax - px) * (by - py) - (bx - px) * (ay - py) >= 0 and
           (bx - px) * (cy - py) - (cx - px) * (by - py) >= 0
end

-- Signed area calculation
local function signedArea(data, start, finish, dim)
    local sum = 0
    local j = finish - dim

    for i = start, finish - 1, dim do
        sum = sum + (data[j] - data[i]) * (data[i + 1] + data[j + 1])
        j = i
    end

    return sum
end

-- Create a circular doubly linked list from polygon points
local function linkedList(data, start, finish, dim, clockwise)
    local last

    if clockwise == (signedArea(data, start, finish, dim) > 0) then
        for i = start, finish - 1, dim do
            -- Use (i - 1) / dim to get 0-based vertex index from 1-based array position
            last = insertNode((i - 1) / dim, data[i], data[i + 1], last)
        end
    else
        for i = finish - dim, start, -dim do
            -- Use (i - 1) / dim to get 0-based vertex index from 1-based array position
            last = insertNode((i - 1) / dim, data[i], data[i + 1], last)
        end
    end

    if last and equals(last, last.next) then
        removeNode(last)
        last = last.next
    end

    return last
end

-- Create node and link it
function insertNode(i, x, y, last)
    local p = Node(i, x, y)

    if not last then
        p.prev = p
        p.next = p
    else
        p.next = last.next
        p.prev = last
        last.next.prev = p
        last.next = p
    end
    return p
end

function removeNode(p)
    p.next.prev = p.prev
    p.prev.next = p.next

    if p.prevZ then p.prevZ.nextZ = p.nextZ end
    if p.nextZ then p.nextZ.prevZ = p.prevZ end
end

-- Eliminate colinear or duplicate points
local function filterPoints(start, finish)
    if not start then return start end
    if not finish then finish = start end

    local p = start
    local again

    repeat
        again = false

        if not p.steiner and (equals(p, p.next) or area(p.prev, p, p.next) == 0) then
            removeNode(p)
            p = p.prev
            finish = p
            if p == p.next then break end
            again = true
        else
            p = p.next
        end
    until not again or p == finish

    return finish
end

-- Z-order calculation using bit operations
local lshift = bit.lshift or bit32.lshift
local bor = bit.bor or bit32.bor
local band = bit.band or bit32.band

local function zOrder(x, y, minX, minY, invSize)
    x = math.floor(32767 * (x - minX) * invSize)
    y = math.floor(32767 * (y - minY) * invSize)

    x = band(bor(x, lshift(x, 8)), 0x00FF00FF)
    x = band(bor(x, lshift(x, 4)), 0x0F0F0F0F)
    x = band(bor(x, lshift(x, 2)), 0x33333333)
    x = band(bor(x, lshift(x, 1)), 0x55555555)

    y = band(bor(y, lshift(y, 8)), 0x00FF00FF)
    y = band(bor(y, lshift(y, 4)), 0x0F0F0F0F)
    y = band(bor(y, lshift(y, 2)), 0x33333333)
    y = band(bor(y, lshift(y, 1)), 0x55555555)

    return bor(x, lshift(y, 1))
end

-- Forward declaration for sortLinked (used by indexCurve)
local sortLinked

-- Interlink polygon nodes in z-order
local function indexCurve(start, minX, minY, invSize)
    local p = start
    repeat
        if p.z == nil then
            p.z = zOrder(p.x, p.y, minX, minY, invSize)
        end
        p.prevZ = p.prev
        p.nextZ = p.next
        p = p.next
    until p == start

    p.prevZ.nextZ = nil
    p.prevZ = nil

    sortLinked(p)
end

-- Linked list merge sort
function sortLinked(list)
    local inSize = 1

    repeat
        local p = list
        list = nil
        local tail = nil
        local numMerges = 0

        while p do
            numMerges = numMerges + 1
            local q = p
            local pSize = 0

            for i = 0, inSize - 1 do
                pSize = pSize + 1
                q = q.nextZ
                if not q then break end
            end

            local qSize = inSize

            while pSize > 0 or (qSize > 0 and q) do
                local e
                if pSize ~= 0 and (qSize == 0 or not q or p.z <= q.z) then
                    e = p
                    p = p.nextZ
                    pSize = pSize - 1
                else
                    e = q
                    q = q.nextZ
                    qSize = qSize - 1
                end

                if tail then
                    tail.nextZ = e
                else
                    list = e
                end

                e.prevZ = tail
                tail = e
            end

            p = q
        end

        tail.nextZ = nil
        inSize = inSize * 2

    until numMerges <= 1

    return list
end

-- Check if ear is valid (no points inside)
local function isEar(ear)
    local a = ear.prev
    local b = ear
    local c = ear.next

    if area(a, b, c) >= 0 then return false end

    local p = ear.next.next

    while p ~= ear.prev do
        if pointInTriangle(a.x, a.y, b.x, b.y, c.x, c.y, p.x, p.y) and area(p.prev, p, p.next) >= 0 then
            return false
        end
        p = p.next
    end

    return true
end

-- Check if ear is valid using z-order hashing
local function isEarHashed(ear, minX, minY, invSize)
    local a = ear.prev
    local b = ear
    local c = ear.next

    if area(a, b, c) >= 0 then return false end

    local minTX = math.min(a.x, b.x, c.x)
    local minTY = math.min(a.y, b.y, c.y)
    local maxTX = math.max(a.x, b.x, c.x)
    local maxTY = math.max(a.y, b.y, c.y)

    local minZ = zOrder(minTX, minTY, minX, minY, invSize)
    local maxZ = zOrder(maxTX, maxTY, minX, minY, invSize)

    local p = ear.prevZ
    local n = ear.nextZ

    while p and p.z >= minZ and n and n.z <= maxZ do
        if p ~= ear.prev and p ~= ear.next and pointInTriangle(a.x, a.y, b.x, b.y, c.x, c.y, p.x, p.y) and area(p.prev, p, p.next) >= 0 then
            return false
        end
        p = p.prevZ

        if n ~= ear.prev and n ~= ear.next and pointInTriangle(a.x, a.y, b.x, b.y, c.x, c.y, n.x, n.y) and area(n.prev, n, n.next) >= 0 then
            return false
        end
        n = n.nextZ
    end

    while p and p.z >= minZ do
        if p ~= ear.prev and p ~= ear.next and pointInTriangle(a.x, a.y, b.x, b.y, c.x, c.y, p.x, p.y) and area(p.prev, p, p.next) >= 0 then
            return false
        end
        p = p.prevZ
    end

    while n and n.z <= maxZ do
        if n ~= ear.prev and n ~= ear.next and pointInTriangle(a.x, a.y, b.x, b.y, c.x, c.y, n.x, n.y) and area(n.prev, n, n.next) >= 0 then
            return false
        end
        n = n.nextZ
    end

    return true
end

-- Main ear slicing loop
local function earcutLinked(ear, triangles, dim, minX, minY, invSize, pass)
    if not ear then return end

    if not pass and invSize then
        indexCurve(ear, minX, minY, invSize)
    end

    local stop = ear

    while ear.prev ~= ear.next do
        local prev = ear.prev
        local next = ear.next

        local test = invSize and isEarHashed(ear, minX, minY, invSize) or isEar(ear)

        if test then
            triangles:push(prev.i)
            triangles:push(ear.i)
            triangles:push(next.i)

            removeNode(ear)

            ear = next.next
            stop = next.next
        else
            ear = next

            if ear == stop then
                if not pass then
                    earcutLinked(filterPoints(ear), triangles, dim, minX, minY, invSize, 1)
                elseif pass == 1 then
                    ear = cureLocalIntersections(filterPoints(ear), triangles, dim)
                    earcutLinked(ear, triangles, dim, minX, minY, invSize, 2)
                elseif pass == 2 then
                    splitEarcut(ear, triangles, dim, minX, minY, invSize)
                end
                break
            end
        end
    end
end

-- Additional helper functions for advanced cases
local function sign(num)
    return num > 0 and 1 or (num < 0 and -1 or 0)
end

local function onSegment(p, q, r)
    return q.x <= math.max(p.x, r.x) and q.x >= math.min(p.x, r.x) and
           q.y <= math.max(p.y, r.y) and q.y >= math.min(p.y, r.y)
end

local function intersects(p1, q1, p2, q2)
    local o1 = sign(area(p1, q1, p2))
    local o2 = sign(area(p1, q1, q2))
    local o3 = sign(area(p2, q2, p1))
    local o4 = sign(area(p2, q2, q1))

    if o1 ~= o2 and o3 ~= o4 then return true end

    if o1 == 0 and onSegment(p1, p2, q1) then return true end
    if o2 == 0 and onSegment(p1, q2, q1) then return true end
    if o3 == 0 and onSegment(p2, p1, q2) then return true end
    if o4 == 0 and onSegment(p2, q1, q2) then return true end

    return false
end

local function locallyInside(a, b)
    if area(a.prev, a, a.next) < 0 then
        return area(a, b, a.next) >= 0 and area(a, a.prev, b) >= 0
    end
    return area(a, b, a.prev) < 0 or area(a, a.next, b) < 0
end

function cureLocalIntersections(start, triangles, dim)
    local p = start
    repeat
        local a = p.prev
        local b = p.next.next

        if not equals(a, b) and intersects(a, p, p.next, b) and locallyInside(a, b) and locallyInside(b, a) then
            triangles:push(a.i)
            triangles:push(p.i)
            triangles:push(b.i)

            removeNode(p)
            removeNode(p.next)

            p = b
            start = b
        end
        p = p.next
    until p == start

    return filterPoints(p)
end

local function intersectsPolygon(a, b)
    local p = a
    repeat
        if p.i ~= a.i and p.next.i ~= a.i and p.i ~= b.i and p.next.i ~= b.i and intersects(p, p.next, a, b) then
            return true
        end
        p = p.next
    until p == a
    return false
end

local function middleInside(a, b)
    local p = a
    local inside = false
    local px = (a.x + b.x) / 2
    local py = (a.y + b.y) / 2

    repeat
        if ((p.y > py) ~= (p.next.y > py)) and p.next.y ~= p.y and
           (px < (p.next.x - p.x) * (py - p.y) / (p.next.y - p.y) + p.x) then
            inside = not inside
        end
        p = p.next
    until p == a

    return inside
end

local function isValidDiagonal(a, b)
    return a.next.i ~= b.i and a.prev.i ~= b.i and not intersectsPolygon(a, b) and
           (locallyInside(a, b) and locallyInside(b, a) and middleInside(a, b) and
           (area(a.prev, a, b.prev) ~= 0 or area(a, b.prev, b) ~= 0) or
           equals(a, b) and area(a.prev, a, a.next) > 0 and area(b.prev, b, b.next) > 0)
end

local function splitPolygon(a, b)
    local a2 = Node(a.i, a.x, a.y)
    local b2 = Node(b.i, b.x, b.y)
    local an = a.next
    local bp = b.prev

    a.next = b
    b.prev = a

    a2.next = an
    an.prev = a2

    b2.next = a2
    a2.prev = b2

    bp.next = b2
    b2.prev = bp

    return b2
end

function splitEarcut(start, triangles, dim, minX, minY, invSize)
    local a = start
    repeat
        local b = a.next.next
        while b ~= a.prev do
            if a.i ~= b.i and isValidDiagonal(a, b) then
                local c = splitPolygon(a, b)

                a = filterPoints(a, a.next)
                c = filterPoints(c, c.next)

                earcutLinked(a, triangles, dim, minX, minY, invSize)
                earcutLinked(c, triangles, dim, minX, minY, invSize)
                return
            end
            b = b.next
        end
        a = a.next
    until a == start
end

-- Hole elimination
local function getLeftmost(start)
    local p = start
    local leftmost = start
    repeat
        if p.x < leftmost.x or (p.x == leftmost.x and p.y < leftmost.y) then
            leftmost = p
        end
        p = p.next
    until p == start
    return leftmost
end

local function compareX(a, b)
    return a.x < b.x
end

local function sectorContainsSector(m, p)
    return area(m.prev, m, p.prev) < 0 and area(p.next, m, m.next) < 0
end

local function findHoleBridge(hole, outerNode)
    local p = outerNode
    local hx = hole.x
    local hy = hole.y
    local qx = -math.huge
    local m

    repeat
        if hy <= p.y and hy >= p.next.y and p.next.y ~= p.y then
            local x = p.x + (hy - p.y) * (p.next.x - p.x) / (p.next.y - p.y)
            if x <= hx and x > qx then
                qx = x
                if x == hx then
                    if hy == p.y then return p end
                    if hy == p.next.y then return p.next end
                end
                m = p.x < p.next.x and p or p.next
            end
        end
        p = p.next
    until p == outerNode

    if not m then return nil end
    if hx == qx then return m end

    local stop = m
    local mx = m.x
    local my = m.y
    local tanMin = math.huge

    p = m

    repeat
        if hx >= p.x and p.x >= mx and hx ~= p.x and
           pointInTriangle(hy < my and hx or qx, hy, mx, my, hy < my and qx or hx, hy, p.x, p.y) then
            local tan = math.abs(hy - p.y) / (hx - p.x)

            if locallyInside(p, hole) and (tan < tanMin or (tan == tanMin and (p.x > m.x or (p.x == m.x and sectorContainsSector(m, p))))) then
                m = p
                tanMin = tan
            end
        end
        p = p.next
    until p == stop

    return m
end

local function eliminateHole(hole, outerNode)
    outerNode = findHoleBridge(hole, outerNode)
    if outerNode then
        local b = splitPolygon(outerNode, hole)
        filterPoints(outerNode, outerNode.next)
        filterPoints(b, b.next)
    end
end

local function eliminateHoles(data, holeIndices, outerNode, dim)
    local queue = {}

    for i = 0, #holeIndices do
        if holeIndices[i] then
            local start = holeIndices[i] * dim + 1  -- Convert to 1-indexed
            local finish = (holeIndices[i + 1] and (holeIndices[i + 1] * dim + 1)) or (#data + 1)
            local list = linkedList(data, start, finish, dim, false)
            if list == list.next then
                list.steiner = true
            end
            table.insert(queue, getLeftmost(list))
        end
    end

    table.sort(queue, compareX)

    for i = 1, #queue do
        eliminateHole(queue[i], outerNode)
        outerNode = filterPoints(outerNode, outerNode.next)
    end

    return outerNode
end

-- Main earcut function
function Earcut.triangulate(data, holeIndices, dim)
    -- Don't use ZeroArray - just work with regular Lua tables and adjust indices
    dim = dim or 2
    holeIndices = holeIndices or {}
    
    local hasHoles = #holeIndices > 0
    
    -- Convert to 0-indexed for algorithm (adjust by -1)
    local outerLen = hasHoles and (holeIndices[1] * dim) or #data
    
    local outerNode = linkedList(data, 1, outerLen, dim, true)
    local triangles = {}

    if not outerNode or outerNode.next == outerNode.prev then
        return {}
    end

    if hasHoles then
        -- Convert hole indices to 0-indexed for the algorithm
        local holeIndices0 = {}
        for i, idx in ipairs(holeIndices) do
            holeIndices0[i - 1] = idx
        end
        outerNode = eliminateHoles(data, holeIndices0, outerNode, dim)
    end

    local minX, minY, maxX, maxY, invSize

    if #data > 80 * dim then
        minX = data[1]
        maxX = data[1]
        minY = data[2]
        maxY = data[2]

        for i = dim + 1, outerLen, dim do
            local x = data[i]
            local y = data[i + 1]
            if x < minX then minX = x end
            if y < minY then minY = y end
            if x > maxX then maxX = x end
            if y > maxY then maxY = y end
        end

        invSize = math.max(maxX - minX, maxY - minY)
        invSize = invSize ~= 0 and 1 / invSize or nil
    end

    local triangles_zarr = ZeroArray({})
    earcutLinked(outerNode, triangles_zarr, dim, minX, minY, invSize)

    return getArray(triangles_zarr)
end

return Earcut