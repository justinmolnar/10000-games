--[[
    3D Text Geometry Generator

    High-level API for generating complete 3D text meshes from strings.
    Combines all geometry systems: outline extraction, triangulation, and extrusion.

    This is the main entry point for creating 3D text. Given a string, font, and
    extrusion depth, it produces a complete 3D mesh ready for rendering.

    Input: "Hello", font, depth
    Output: {
        vertices = {{x, y, z}, ...},
        faces = {{v1, v2, v3, normal}, ...}
    }
]]

local Text3DGeometry = {}

-- Required modules
local TextOutlineExtractor = require('src.utils.text_outline_extractor')
local Triangulation = require('src.utils.triangulation')
local MeshExtrusion = require('src.utils.mesh_extrusion')

-- ============================================================================
-- Configuration
-- ============================================================================

-- Character spacing as fraction of average character width
local DEFAULT_SPACING_FACTOR = 0.1

-- Minimum extrusion depth
local MIN_EXTRUSION_DEPTH = 0.01

-- ============================================================================
-- Character Mesh Cache
-- ============================================================================

-- Cache generated character meshes to avoid regeneration
-- Key: font_pointer .. "_" .. character .. "_" .. depth
local character_cache = {}

--- Generate or retrieve cached 3D mesh for a single character
local function getCharacterMesh(char, font, depth)
    -- Create cache key
    local font_ptr = tostring(font)
    local cache_key = font_ptr .. "_" .. char .. "_" .. tostring(depth)

    -- Check cache
    if character_cache[cache_key] then
        return character_cache[cache_key]
    end

    -- Generate mesh
    local outline = TextOutlineExtractor.getCharacterOutline(char, font)

    if not outline then
        -- Character has no outline (e.g., space)
        return nil
    end

    local mesh2d = Triangulation.triangulate(outline)
    local mesh3d = MeshExtrusion.extrude(mesh2d, depth)

    -- Attach metrics to mesh for proper spacing
    mesh3d.metrics = outline.metrics

    -- Cache and return
    character_cache[cache_key] = mesh3d
    return mesh3d
end

--- Clear character mesh cache (call when memory is tight)
function Text3DGeometry.clearCache()
    character_cache = {}
end

-- ============================================================================
-- Mesh Combination
-- ============================================================================

--- Combine multiple 3D meshes into a single mesh
-- @param meshes array of {mesh, offset_x, offset_y}
-- @return combined mesh {vertices, faces}
local function combineMeshes(meshes)
    local combined_vertices = {}
    local combined_faces = {}
    local vertex_offset = 0

    for _, mesh_data in ipairs(meshes) do
        local mesh = mesh_data.mesh
        local offset_x = mesh_data.offset_x or 0
        local offset_y = mesh_data.offset_y or 0

        if mesh and mesh.vertices and mesh.faces then
            -- Add vertices with offset (no scaling - vertices are already normalized)
            for _, v in ipairs(mesh.vertices) do
                table.insert(combined_vertices, {
                    v[1] + offset_x,
                    v[2] + offset_y,
                    v[3]
                })
            end

            -- Add faces with reindexed vertices
            for _, face in ipairs(mesh.faces) do
                table.insert(combined_faces, {
                    face[1] + vertex_offset,
                    face[2] + vertex_offset,
                    face[3] + vertex_offset,
                    normal = face.normal
                })
            end

            vertex_offset = vertex_offset + #mesh.vertices
        end
    end

    return {
        vertices = combined_vertices,
        faces = combined_faces
    }
end

-- ============================================================================
-- Main API
-- ============================================================================

--- Generate 3D mesh for a text string
-- @param text string to render
-- @param font love.graphics.Font object
-- @param extrude_depth extrusion depth (default 0.2)
-- @param spacing_factor character spacing as fraction of avg width (default 0.1)
-- @return mesh {vertices, faces} or nil if text is empty/invalid
function Text3DGeometry.generate(text, font, extrude_depth, spacing_factor)
    if not text or #text == 0 then
        return nil
    end

    if not font then
        font = love.graphics.getFont()
    end

    extrude_depth = math.max(MIN_EXTRUSION_DEPTH, extrude_depth or 0.2)
    spacing_factor = spacing_factor or DEFAULT_SPACING_FACTOR

    -- Array of character meshes with positions
    local character_meshes = {}
    local cursor_x = 0

    -- Process each character
    for i = 1, #text do
        local char = text:sub(i, i)

        -- Get character width from font
        local char_width = font:getWidth(char)

        -- Skip spaces (advance cursor but don't render)
        if char == ' ' then
            -- Advance by approximate normalized width (average character is ~0.5 wide)
            cursor_x = cursor_x + 0.3 * (1.0 + spacing_factor)
        else
            -- Generate character mesh
            local char_mesh = getCharacterMesh(char, font, extrude_depth)

            if char_mesh then
                -- Use character's actual width from metrics (preserves font spacing)
                local char_width_normalized = char_mesh.metrics and char_mesh.metrics.width or 0.5

                print(string.format("[Text3DGeometry] Char '%s': %d verts, width=%.3f, cursor=%.3f",
                    char, #char_mesh.vertices, char_width_normalized, cursor_x))

                -- Store mesh with position offset (keep in normalized space)
                table.insert(character_meshes, {
                    mesh = char_mesh,
                    offset_x = cursor_x,  -- Normalized space offset
                    offset_y = 0
                })

                -- Advance cursor using actual character width plus spacing
                cursor_x = cursor_x + char_width_normalized * (1.0 + spacing_factor)
            else
                print(string.format("[Text3DGeometry] Char '%s': NO MESH (space or failed)", char))
                -- Advance cursor using font width estimate
                cursor_x = cursor_x + 0.5 * (1.0 + spacing_factor)
            end
        end
    end

    if #character_meshes == 0 then
        return nil
    end

    -- Combine all character meshes
    local combined = combineMeshes(character_meshes)

    print(string.format("[Text3DGeometry] Generated text '%s': %d vertices, %d faces",
        text, #combined.vertices, #combined.faces))

    -- Center the text at origin
    local min_x, min_y, min_z, max_x, max_y, max_z = MeshExtrusion.getBoundingBox(combined)
    local center_x = (min_x + max_x) / 2
    local center_y = (min_y + max_y) / 2

    print(string.format("[Text3DGeometry] Bounds before center: x[%.3f, %.3f] y[%.3f, %.3f]",
        min_x, max_x, min_y, max_y))

    -- Translate all vertices to center (characters are already in normalized space)
    for _, v in ipairs(combined.vertices) do
        v[1] = v[1] - center_x
        v[2] = v[2] - center_y
    end

    -- Store metadata
    combined.text = text
    combined.extrude_depth = extrude_depth
    combined.bounds = {
        width = max_x - min_x,
        height = max_y - min_y,
        depth = extrude_depth
    }

    return combined
end

--- Generate 3D mesh with custom per-character scaling
-- Useful for creating varied text effects
-- @param text string to render
-- @param font love.graphics.Font object
-- @param extrude_depth extrusion depth
-- @param char_scales array of scale factors per character (optional)
-- @return mesh {vertices, faces}
function Text3DGeometry.generateWithScaling(text, font, extrude_depth, char_scales)
    -- TODO: Implement if needed for advanced effects
    -- For now, just use standard generation
    return Text3DGeometry.generate(text, font, extrude_depth)
end

--- Get estimated triangle count for text
-- Useful for performance budgeting
-- @param text string to check
-- @param font love.graphics.Font object
-- @return estimated triangle count
function Text3DGeometry.estimateTriangleCount(text, font)
    if not text or #text == 0 then
        return 0
    end

    -- Rough estimate: average 50 triangles per character
    -- Simple characters (I, L) ~30, complex (B, 8) ~70
    local char_count = 0
    for i = 1, #text do
        if text:sub(i, i) ~= ' ' then
            char_count = char_count + 1
        end
    end

    return char_count * 50
end

--- Get mesh statistics
-- @param mesh generated mesh
-- @return table {vertex_count, face_count, character_count, bounds}
function Text3DGeometry.stats(mesh)
    if not mesh then
        return {
            vertex_count = 0,
            face_count = 0,
            character_count = 0,
            bounds = {width = 0, height = 0, depth = 0}
        }
    end

    local char_count = 0
    if mesh.text then
        for i = 1, #mesh.text do
            if mesh.text:sub(i, i) ~= ' ' then
                char_count = char_count + 1
            end
        end
    end

    return {
        vertex_count = #(mesh.vertices or {}),
        face_count = #(mesh.faces or {}),
        character_count = char_count,
        bounds = mesh.bounds or {width = 0, height = 0, depth = 0}
    }
end

--- Calculate tight bounding box for mesh
-- @param mesh generated mesh
-- @return min_x, min_y, min_z, max_x, max_y, max_z
function Text3DGeometry.getBoundingBox(mesh)
    return MeshExtrusion.getBoundingBox(mesh)
end

--- Regenerate mesh with different extrusion depth
-- More efficient than full regeneration if only depth changed
-- @param original_mesh existing mesh
-- @param new_depth new extrusion depth
-- @return new mesh
function Text3DGeometry.regenerateWithDepth(original_mesh, new_depth)
    -- For now, this requires full regeneration
    -- Could be optimized by caching 2D triangulation and only re-extruding
    if not original_mesh or not original_mesh.text then
        return nil
    end

    -- Extract original parameters and regenerate
    -- This is a simplified version - in production we'd want to cache more
    return nil  -- Caller should use generate() instead for now
end

return Text3DGeometry
