--[[
    3D Math Utility Library

    Provides vector operations, 3x3 matrix operations, and rotation matrices
    for 3D rendering. Extracted from screensaver_model_view.lua and enhanced
    for use across 3D systems.

    Coordinate System: Right-handed, Y-up (LÖVE default)
    Matrix Storage: Row-major, 9-element arrays {m11,m12,m13, m21,m22,m23, m31,m32,m33}
    Rotation Order: Z * Y * X (standard Euler angles)
]]

local Math3D = {}

-- ============================================================================
-- Vector Operations (3D vectors stored as {x, y, z} tables)
-- ============================================================================

--- Add two 3D vectors
-- @param a {x, y, z}
-- @param b {x, y, z}
-- @return {x, y, z}
function Math3D.vecAdd(a, b)
    return {a[1] + b[1], a[2] + b[2], a[3] + b[3]}
end

--- Subtract two 3D vectors (a - b)
-- @param a {x, y, z}
-- @param b {x, y, z}
-- @return {x, y, z}
function Math3D.vecSub(a, b)
    return {a[1] - b[1], a[2] - b[2], a[3] - b[3]}
end

--- Scale a 3D vector by scalar
-- @param v {x, y, z}
-- @param s scalar multiplier
-- @return {x, y, z}
function Math3D.vecScale(v, s)
    return {v[1] * s, v[2] * s, v[3] * s}
end

--- Dot product of two 3D vectors
-- @param a {x, y, z}
-- @param b {x, y, z}
-- @return scalar (a·b)
function Math3D.vecDot(a, b)
    return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

--- Cross product of two 3D vectors (a × b)
-- Returns vector perpendicular to both a and b, following right-hand rule
-- @param a {x, y, z}
-- @param b {x, y, z}
-- @return {x, y, z}
function Math3D.vecCross(a, b)
    return {
        a[2] * b[3] - a[3] * b[2],
        a[3] * b[1] - a[1] * b[3],
        a[1] * b[2] - a[2] * b[1]
    }
end

--- Length (magnitude) of a 3D vector
-- @param v {x, y, z}
-- @return scalar length
function Math3D.vecLen(v)
    return math.sqrt(Math3D.vecDot(v, v))
end

--- Normalize a 3D vector (make length = 1)
-- @param v {x, y, z}
-- @return {x, y, z} normalized, or {0,0,0} if input was zero-length
function Math3D.vecNormalize(v)
    local len = Math3D.vecLen(v)
    if len < 1e-9 then
        return {0, 0, 0}
    end
    return Math3D.vecScale(v, 1.0 / len)
end

-- ============================================================================
-- Matrix Operations (3x3 matrices stored as 9-element arrays, row-major)
-- ============================================================================

--- Multiply two 3x3 matrices (a * b)
-- @param a 9-element array {m11,m12,m13, m21,m22,m23, m31,m32,m33}
-- @param b 9-element array
-- @return 9-element array (result of a * b)
function Math3D.matMul(a, b)
    local r = {}
    r[1] = a[1]*b[1] + a[2]*b[4] + a[3]*b[7]
    r[2] = a[1]*b[2] + a[2]*b[5] + a[3]*b[8]
    r[3] = a[1]*b[3] + a[2]*b[6] + a[3]*b[9]
    r[4] = a[4]*b[1] + a[5]*b[4] + a[6]*b[7]
    r[5] = a[4]*b[2] + a[5]*b[5] + a[6]*b[8]
    r[6] = a[4]*b[3] + a[5]*b[6] + a[6]*b[9]
    r[7] = a[7]*b[1] + a[8]*b[4] + a[9]*b[7]
    r[8] = a[7]*b[2] + a[8]*b[5] + a[9]*b[8]
    r[9] = a[7]*b[3] + a[8]*b[6] + a[9]*b[9]
    return r
end

--- Apply 3x3 matrix to 3D vector
-- @param m 9-element array (3x3 matrix)
-- @param v {x, y, z}
-- @return {x, y, z} transformed vector
function Math3D.matMulVec(m, v)
    return {
        m[1]*v[1] + m[2]*v[2] + m[3]*v[3],
        m[4]*v[1] + m[5]*v[2] + m[6]*v[3],
        m[7]*v[1] + m[8]*v[2] + m[9]*v[3],
    }
end

-- ============================================================================
-- Rotation Matrices (3x3, right-handed coordinate system)
-- ============================================================================

--- Create rotation matrix around X axis (pitch)
-- Positive angle rotates Y toward Z (right-hand rule: thumb along +X, fingers curl Y→Z)
-- @param angle_radians rotation angle in radians
-- @return 9-element array (3x3 rotation matrix)
function Math3D.rotX(angle_radians)
    local c, s = math.cos(angle_radians), math.sin(angle_radians)
    return {
        1, 0, 0,
        0, c, -s,
        0, s, c
    }
end

--- Create rotation matrix around Y axis (yaw)
-- Positive angle rotates Z toward X (right-hand rule: thumb along +Y, fingers curl Z→X)
-- @param angle_radians rotation angle in radians
-- @return 9-element array (3x3 rotation matrix)
function Math3D.rotY(angle_radians)
    local c, s = math.cos(angle_radians), math.sin(angle_radians)
    return {
        c, 0, s,
        0, 1, 0,
        -s, 0, c
    }
end

--- Create rotation matrix around Z axis (roll)
-- Positive angle rotates X toward Y (right-hand rule: thumb along +Z, fingers curl X→Y)
-- @param angle_radians rotation angle in radians
-- @return 9-element array (3x3 rotation matrix)
function Math3D.rotZ(angle_radians)
    local c, s = math.cos(angle_radians), math.sin(angle_radians)
    return {
        c, -s, 0,
        s, c, 0,
        0, 0, 1
    }
end

-- ============================================================================
-- Convenience Functions
-- ============================================================================

--- Build combined rotation matrix from Euler angles
-- Rotation order: Z * Y * X (standard for pitch/yaw/roll)
-- @param rx pitch (rotation around X axis) in radians
-- @param ry yaw (rotation around Y axis) in radians
-- @param rz roll (rotation around Z axis) in radians
-- @return 9-element array (combined 3x3 rotation matrix)
function Math3D.buildRotationMatrix(rx, ry, rz)
    local Rx = Math3D.rotX(rx)
    local Ry = Math3D.rotY(ry)
    local Rz = Math3D.rotZ(rz)
    return Math3D.matMul(Rz, Math3D.matMul(Ry, Rx))
end

--- Apply rotation to a single vertex (convenience wrapper)
-- @param vertex {x, y, z}
-- @param rx pitch in radians
-- @param ry yaw in radians
-- @param rz roll in radians
-- @return {x, y, z} rotated vertex
function Math3D.rotateVertex(vertex, rx, ry, rz)
    local R = Math3D.buildRotationMatrix(rx, ry, rz)
    return Math3D.matMulVec(R, vertex)
end

--- Calculate face normal from three vertices (triangle)
-- Uses right-hand rule: normal points toward (v2-v1) × (v3-v1)
-- @param v1 {x, y, z} first vertex
-- @param v2 {x, y, z} second vertex
-- @param v3 {x, y, z} third vertex
-- @return {x, y, z} unnormalized face normal (call vecNormalize if needed)
function Math3D.calculateFaceNormal(v1, v2, v3)
    local edge1 = Math3D.vecSub(v2, v1)
    local edge2 = Math3D.vecSub(v3, v1)
    return Math3D.vecCross(edge1, edge2)
end

--- Calculate normalized face normal from three vertices
-- @param v1 {x, y, z} first vertex
-- @param v2 {x, y, z} second vertex
-- @param v3 {x, y, z} third vertex
-- @return {x, y, z} normalized face normal
function Math3D.calculateFaceNormalNormalized(v1, v2, v3)
    local normal = Math3D.calculateFaceNormal(v1, v2, v3)
    return Math3D.vecNormalize(normal)
end

--- Perspective projection (3D point → 2D screen space)
-- @param point {x, y, z} 3D point in camera space
-- @param fov field of view factor (larger = wider FOV)
-- @param cx center X (screen space)
-- @param cy center Y (screen space)
-- @return screen_x, screen_y, depth (or nil if behind camera)
function Math3D.project(point, fov, cx, cy)
    local z = point[3]
    if z <= 0.01 then
        return nil, nil, nil  -- Behind camera or too close
    end
    local k = fov / z
    local screen_x = cx + point[1] * k
    local screen_y = cy + point[2] * k
    return screen_x, screen_y, z
end

--- Convert degrees to radians
-- @param degrees angle in degrees
-- @return angle in radians
function Math3D.degToRad(degrees)
    return degrees * (math.pi / 180)
end

--- Convert radians to degrees
-- @param radians angle in radians
-- @return angle in degrees
function Math3D.radToDeg(radians)
    return radians * (180 / math.pi)
end

return Math3D
