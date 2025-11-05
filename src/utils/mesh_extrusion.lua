--[[
    3D Mesh Extrusion (Proper Hole Support)

    Extrudes 2D meshes into 3D with correct hole handling:
    - Front/back faces use all triangles (outer + holes with proper winding)
    - Side walls on BOTH outer perimeter AND hole perimeters
    - Holes appear as actual empty space due to opposite winding

    Input: {
        vertices = {{x, y}, ...},
        triangles = {{v1, v2, v3}, ...},
        outer_edges = {{v1, v2}, ...},    -- Outer perimeter
        hole_edges = {{v1, v2}, ...}      -- Hole perimeters
    }

    Output: {
        vertices = {{x, y, z}, ...},
        faces = {{v1, v2, v3, normal = {nx, ny, nz}}, ...}
    }
]]

local MeshExtrusion = {}

local Math3D = require('src.utils.math3d')

-- ============================================================================
-- Utility Functions
-- ============================================================================

--- Order edges into continuous loops
local function orderEdgesIntoLoops(edges)
    if #edges == 0 then
        return {}
    end

    local remaining = {}
    for _, edge in ipairs(edges) do
        table.insert(remaining, {edge[1], edge[2]})
    end

    local loops = {}

    while #remaining > 0 do
        local loop = {table.remove(remaining, 1)}
        local extended = true

        while extended and #remaining > 0 do
            extended = false
            local last_vertex = loop[#loop][2]

            for i = #remaining, 1, -1 do
                local edge = remaining[i]
                if edge[1] == last_vertex then
                    table.insert(loop, edge)
                    table.remove(remaining, i)
                    extended = true
                    break
                elseif edge[2] == last_vertex then
                    table.insert(loop, {edge[2], edge[1]})
                    table.remove(remaining, i)
                    extended = true
                    break
                end
            end
        end

        table.insert(loops, loop)
    end

    return loops
end

-- ============================================================================
-- Extrusion Algorithm
-- ============================================================================

function MeshExtrusion.extrude(mesh2d, depth, smooth_normals)
    if not mesh2d or not mesh2d.vertices or #mesh2d.vertices < 3 then
        return {vertices = {}, faces = {}}
    end

    depth = depth or 1.0
    local vertices_2d = mesh2d.vertices
    local triangles_2d = mesh2d.triangles
    local perimeter_edges = mesh2d.perimeter_edges or {}

    local vertices_3d = {}
    local faces_3d = {}

    print(string.format("  [MeshExtrusion] Input: %d vertices, %d triangles, %d perimeter edges",
        #vertices_2d, #triangles_2d, #perimeter_edges))

    -- ========================================================================
    -- Step 1: Create 3D vertices (front and back)
    -- ========================================================================

    -- Front vertices (z = 0)
    for i, v2d in ipairs(vertices_2d) do
        table.insert(vertices_3d, {v2d[1], v2d[2], 0})
    end

    local front_vertex_count = #vertices_3d

    -- Back vertices (z = depth)
    for i, v2d in ipairs(vertices_2d) do
        table.insert(vertices_3d, {v2d[1], v2d[2], depth})
    end

    -- ========================================================================
    -- Step 2: Create front face triangles
    -- All triangles (outer + holes) - holes have opposite winding so they cut through
    -- ========================================================================

    for _, tri in ipairs(triangles_2d) do
        local normal = {0, 0, -1}  -- Pointing toward viewer
        table.insert(faces_3d, {tri[1], tri[2], tri[3], normal = normal})
    end

    -- ========================================================================
    -- Step 3: Create back face triangles
    -- ========================================================================

    for _, tri in ipairs(triangles_2d) do
        local v1 = tri[1] + front_vertex_count
        local v2 = tri[2] + front_vertex_count
        local v3 = tri[3] + front_vertex_count

        local normal = {0, 0, 1}  -- Pointing away from viewer
        table.insert(faces_3d, {v1, v3, v2, normal = normal})  -- Reversed winding
    end

    -- ========================================================================
    -- Step 4: Create side walls for perimeter edges
    -- ========================================================================

    if #perimeter_edges > 0 then
        local edge_loops = orderEdgesIntoLoops(perimeter_edges)
        print(string.format("  [MeshExtrusion] Creating side walls: %d loops", #edge_loops))

        for loop_idx, loop in ipairs(edge_loops) do
            print(string.format("  [MeshExtrusion] Loop %d: %d edges", loop_idx, #loop))
            
            for _, edge in ipairs(loop) do
                local v1_front = edge[1]
                local v2_front = edge[2]
                local v1_back = edge[1] + front_vertex_count
                local v2_back = edge[2] + front_vertex_count

                local front_v1 = vertices_3d[v1_front]
                local front_v2 = vertices_3d[v2_front]

                -- Calculate outward normal
                local edge_dx = front_v2[1] - front_v1[1]
                local edge_dy = front_v2[2] - front_v1[2]
                local normal_x = -edge_dy
                local normal_y = edge_dx
                local normal_len = math.sqrt(normal_x * normal_x + normal_y * normal_y)

                if normal_len > 0.0001 then
                    normal_x = normal_x / normal_len
                    normal_y = normal_y / normal_len
                end

                local normal = {normal_x, normal_y, 0}

                -- Two triangles form the side wall quad
                table.insert(faces_3d, {v1_front, v2_front, v2_back, normal = normal})
                table.insert(faces_3d, {v1_front, v2_back, v1_back, normal = normal})
            end
        end
    end

    -- ========================================================================
    -- Step 5: Optional smooth normals
    -- ========================================================================

    if smooth_normals then
        local vertex_normals = {}
        for i = 1, #vertices_3d do
            vertex_normals[i] = {0, 0, 0}
        end

        for _, face in ipairs(faces_3d) do
            for _, v_idx in ipairs({face[1], face[2], face[3]}) do
                vertex_normals[v_idx][1] = vertex_normals[v_idx][1] + face.normal[1]
                vertex_normals[v_idx][2] = vertex_normals[v_idx][2] + face.normal[2]
                vertex_normals[v_idx][3] = vertex_normals[v_idx][3] + face.normal[3]
            end
        end

        for i = 1, #vertex_normals do
            vertex_normals[i] = Math3D.vecNormalize(vertex_normals[i])
        end

        return {
            vertices = vertices_3d,
            faces = faces_3d,
            vertex_normals = vertex_normals
        }
    end

    print(string.format("  [MeshExtrusion] Output: %d vertices, %d faces", #vertices_3d, #faces_3d))

    return {
        vertices = vertices_3d,
        faces = faces_3d
    }
end

--- Calculate bounding box
function MeshExtrusion.getBoundingBox(mesh3d)
    if not mesh3d or not mesh3d.vertices or #mesh3d.vertices == 0 then
        return 0, 0, 0, 0, 0, 0
    end

    local min_x, min_y, min_z = math.huge, math.huge, math.huge
    local max_x, max_y, max_z = -math.huge, -math.huge, -math.huge

    for _, v in ipairs(mesh3d.vertices) do
        min_x = math.min(min_x, v[1])
        min_y = math.min(min_y, v[2])
        min_z = math.min(min_z, v[3])
        max_x = math.max(max_x, v[1])
        max_y = math.max(max_y, v[2])
        max_z = math.max(max_z, v[3])
    end

    return min_x, min_y, min_z, max_x, max_y, max_z
end

--- Get mesh statistics
function MeshExtrusion.stats(mesh3d)
    if not mesh3d then
        return {vertex_count = 0, face_count = 0, front_faces = 0, back_faces = 0, side_faces = 0}
    end

    local front_faces = 0
    local back_faces = 0
    local side_faces = 0

    for _, face in ipairs(mesh3d.faces or {}) do
        local normal = face.normal
        if normal then
            if math.abs(normal[3] + 1) < 0.01 then
                front_faces = front_faces + 1
            elseif math.abs(normal[3] - 1) < 0.01 then
                back_faces = back_faces + 1
            else
                side_faces = side_faces + 1
            end
        end
    end

    return {
        vertex_count = #(mesh3d.vertices or {}),
        face_count = #(mesh3d.faces or {}),
        front_faces = front_faces,
        back_faces = back_faces,
        side_faces = side_faces
    }
end

return MeshExtrusion