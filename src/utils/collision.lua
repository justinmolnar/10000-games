-- collision.lua: Simple AABB collision detection utilities

local Collision = {}

-- Check if two axis-aligned bounding boxes overlap
function Collision.checkAABB(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
           x2 < x1 + w1 and
           y1 < y2 + h2 and
           y2 < y1 + h1
end

-- Check collision between two objects with x, y, width, height properties
function Collision.checkObjects(obj1, obj2)
    return Collision.checkAABB(
        obj1.x, obj1.y, obj1.width, obj1.height,
        obj2.x, obj2.y, obj2.width, obj2.height
    )
end

-- Check point-in-rectangle collision
function Collision.pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and
           py >= ry and py <= ry + rh
end

-- Check circle collision (useful for bullets)
function Collision.checkCircles(x1, y1, r1, x2, y2, r2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)
    return distance < (r1 + r2)
end

return Collision