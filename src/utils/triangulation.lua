--[[
    2D Polygon Triangulation using Earcut
    
    Uses the battle-tested Earcut library for proper hole handling.
]]

local Triangulation = {}
local Earcut = require('lib.earcut')

--- Triangulate polygon with holes using Earcut
-- @param outline table {outer = {{x,y}, ...}, holes = {{{x,y}, ...}, ...}}
-- @return table {vertices = {{x,y}, ...}, triangles = {{v1,v2,v3}, ...}, perimeter_edges = {{v1,v2}, ...}}
function Triangulation.triangulate(outline)
    if not outline or not outline.outer or #outline.outer < 3 then
        print("  [Triangulation] Invalid outline: no outer contour")
        return {vertices = {}, triangles = {}, perimeter_edges = {}}
    end

    local additional_count = outline.additional_outers and #outline.additional_outers or 0
    print(string.format("  [Triangulation] Input: outer=%d points, holes=%d, additional=%d",
        #outline.outer, #(outline.holes or {}), additional_count))

    -- Convert our format to Earcut format
    -- Earcut expects: flat array [x1,y1, x2,y2, ...] and hole indices
    local all_vertices = {}
    local vertex_list = {}  -- Flat array for Earcut
    local hole_indices = {}
    local perimeter_edges = {}

    -- Add outer contour
    for i, v in ipairs(outline.outer) do
        table.insert(all_vertices, v)
        table.insert(vertex_list, v[1])
        table.insert(vertex_list, v[2])
    end

    -- Create outer perimeter edges
    for i = 1, #outline.outer do
        local next_i = (i % #outline.outer) + 1
        table.insert(perimeter_edges, {i, next_i})
    end

    -- Add holes
    if outline.holes and #outline.holes > 0 then
        for _, hole in ipairs(outline.holes) do
            if #hole >= 3 then
                -- Mark where this hole starts in the vertex list
                table.insert(hole_indices, #all_vertices)

                local hole_start = #all_vertices + 1
                
                -- Add hole vertices
                for i, v in ipairs(hole) do
                    table.insert(all_vertices, v)
                    table.insert(vertex_list, v[1])
                    table.insert(vertex_list, v[2])
                end

                -- Add hole perimeter edges (these will get side walls too)
                for i = 1, #hole do
                    local next_i = (i % #hole) + 1
                    table.insert(perimeter_edges, {hole_start + i - 1, hole_start + next_i - 1})
                end
            end
        end
    end

    -- Debug: show what we're sending to Earcut
    print(string.format("  [Triangulation] Earcut input: %d coords, %d hole indices", #vertex_list, #hole_indices))
    if #hole_indices > 0 then
        print(string.format("  [Triangulation] Hole indices: %s", table.concat(hole_indices, ", ")))
    end
    print(string.format("  [Triangulation] First 10 coords: %s", table.concat({unpack(vertex_list, 1, math.min(10, #vertex_list))}, ", ")))
    
    -- Triangulate using Earcut
    local success, triangle_indices = pcall(Earcut.triangulate, vertex_list, hole_indices, 2)
    
    if not success then
        print(string.format("  [Triangulation] ERROR: Earcut failed: %s", tostring(triangle_indices)))
        return {vertices = all_vertices, triangles = {}, perimeter_edges = perimeter_edges}
    end
    
    print(string.format("  [Triangulation] Earcut returned %d indices (%d triangles)",
        #triangle_indices, #triangle_indices / 3))

    -- DEBUG: Show first few triangles and check for bridge triangles
    if #triangle_indices >= 9 then
        print(string.format("  [Triangulation] First 3 triangles: [%d,%d,%d] [%d,%d,%d] [%d,%d,%d]",
            triangle_indices[1], triangle_indices[2], triangle_indices[3],
            triangle_indices[4], triangle_indices[5], triangle_indices[6],
            triangle_indices[7], triangle_indices[8], triangle_indices[9]))

        -- Check if we have bridge triangles (triangles that use both outer and hole vertices)
        if #hole_indices > 0 then
            local hole_start = hole_indices[1]
            local bridge_count = 0
            for i = 1, math.min(30, #triangle_indices), 3 do
                local v1, v2, v3 = triangle_indices[i], triangle_indices[i+1], triangle_indices[i+2]
                local outer_count = 0
                local hole_count = 0
                if v1 < hole_start then outer_count = outer_count + 1 else hole_count = hole_count + 1 end
                if v2 < hole_start then outer_count = outer_count + 1 else hole_count = hole_count + 1 end
                if v3 < hole_start then outer_count = outer_count + 1 else hole_count = hole_count + 1 end
                if outer_count > 0 and hole_count > 0 then
                    bridge_count = bridge_count + 1
                end
            end
            print(string.format("  [Triangulation] Bridge triangles in first 10: %d", bridge_count))
        end
    end

    -- Convert flat triangle indices to our format (groups of 3)
    local triangles = {}
    for i = 1, #triangle_indices, 3 do
        table.insert(triangles, {
            triangle_indices[i] + 1,      -- Earcut returns 0-indexed, convert to 1-indexed
            triangle_indices[i + 1] + 1,
            triangle_indices[i + 2] + 1
        })
    end

    -- Handle additional outer components (like dots on '?' or 'i')
    if outline.additional_outers and #outline.additional_outers > 0 then
        for _, additional in ipairs(outline.additional_outers) do
            if #additional >= 3 then
                local add_vertex_offset = #all_vertices

                -- Convert to flat array
                local add_vertex_list = {}
                for i, v in ipairs(additional) do
                    table.insert(all_vertices, v)
                    table.insert(add_vertex_list, v[1])
                    table.insert(add_vertex_list, v[2])
                end

                -- Triangulate this component separately
                local add_triangle_indices = Earcut.triangulate(add_vertex_list, {}, 2)

                -- Add triangles with offset
                for i = 1, #add_triangle_indices, 3 do
                    table.insert(triangles, {
                        add_triangle_indices[i] + 1 + add_vertex_offset,
                        add_triangle_indices[i + 1] + 1 + add_vertex_offset,
                        add_triangle_indices[i + 2] + 1 + add_vertex_offset
                    })
                end

                -- Add perimeter edges
                for i = 1, #additional do
                    local next_i = (i % #additional) + 1
                    table.insert(perimeter_edges, {i + add_vertex_offset, next_i + add_vertex_offset})
                end
            end
        end
    end

    print(string.format("  [Triangulation] Output: %d vertices, %d triangles, %d perimeter edges",
        #all_vertices, #triangles, #perimeter_edges))

    return {
        vertices = all_vertices,
        triangles = triangles,
        perimeter_edges = perimeter_edges
    }
end

return Triangulation