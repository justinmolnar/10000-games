--[[
    3D Text Screensaver View (Real 3D Rendering)

    Renders true 3D extruded text using CPU-based 3D rendering pipeline.
    Follows the pattern from screensaver_model_view.lua.
]]

local Object = require('class')
local Math3D = require('src.utils.math3d')
local Text3DGeometry = require('src.utils.text3d_geometry')

local Text3DView = Object:extend('ScreensaverText3DView')

-- ============================================================================
-- Initialization
-- ============================================================================

function Text3DView:init(opts)
    opts = opts or {}
    self.di = opts.di

    -- Get defaults from config
    local C = (self.di and self.di.config) or {}
    local d = (C and C.screensavers and C.screensavers.defaults and C.screensavers.defaults.text3d) or {}

    -- Text settings
    self.text = opts.text or d.text or 'good?'
    self.use_time = opts.use_time or d.use_time or false
    self.font_size = opts.font_size or d.font_size or 96
    self.extrude_depth = (opts.extrude_layers or d.extrude_layers or 12) / 100.0  -- Convert layers to depth

    -- Camera/projection
    self.fov = opts.fov or d.fov or 400
    self.size = opts.size or d.size or 1.0

    -- Color settings
    self.color_mode = opts.color_mode or d.color_mode or 'solid'
    self.use_hsv = opts.use_hsv or d.use_hsv or false
    self.color = opts.color or { d.color_r or 1.0, d.color_g or 1.0, d.color_b or 1.0 }
    self.color_h = opts.color_h or d.color_h or 0.15
    self.color_s = opts.color_s or d.color_s or 1.0
    self.color_v = opts.color_v or d.color_v or 1.0

    -- Rotation speed (degrees per second converted to radians)
    self.spin_x = math.max(0, opts.spin_x or d.spin_x or 0.0) * (math.pi / 180)
    self.spin_y = math.max(0, opts.spin_y or d.spin_y or 0.8) * (math.pi / 180)
    self.spin_z = math.max(0, opts.spin_z or d.spin_z or 0.1) * (math.pi / 180)
    self.rotation = { x = 0, y = 0, z = 0 }  -- Current angles in radians

    -- Rotation modes ('continuous' or 'oscillate')
    self.rotation_mode_x = opts.rotation_mode_x or d.rotation_mode_x or 'continuous'
    self.rotation_mode_y = opts.rotation_mode_y or d.rotation_mode_y or 'continuous'
    self.rotation_mode_z = opts.rotation_mode_z or d.rotation_mode_z or 'continuous'

    -- Rotation ranges for oscillate mode (degrees converted to radians)
    self.rotation_range_x = (opts.rotation_range_x or d.rotation_range_x or 45) * (math.pi / 180)
    self.rotation_range_y = (opts.rotation_range_y or d.rotation_range_y or 45) * (math.pi / 180)
    self.rotation_range_z = (opts.rotation_range_z or d.rotation_range_z or 45) * (math.pi / 180)

    -- Rotation direction (for oscillate mode)
    self.rotation_dir = { x = 1, y = 1, z = 1 }

    -- Movement settings (DVD-style bouncing)
    self.move_enabled = (opts.move_enabled ~= nil) and opts.move_enabled or (d.move_enabled ~= false)
    self.move_speed = opts.move_speed or d.move_speed or 1.0
    self.bounce_speed_x = opts.bounce_speed_x or d.bounce_speed_x or 100
    self.bounce_speed_y = opts.bounce_speed_y or d.bounce_speed_y or 80
    self.position = { x = 0, y = 0 }  -- Screen-space position
    self.velocity = {
        x = self.bounce_speed_x,
        y = self.bounce_speed_y
    }

    -- Depth (Z distance from camera)
    self.depth_base = opts.distance or d.distance or 10
    if self.depth_base < 1 then self.depth_base = 10 end
    self.depth = self.depth_base  -- Current depth (may oscillate)

    -- Z-axis oscillation settings
    self.depth_oscillate = opts.depth_oscillate or d.depth_oscillate or false
    self.depth_speed = opts.depth_speed or d.depth_speed or 0.5
    self.depth_min = opts.depth_min or d.depth_min or 5
    self.depth_max = opts.depth_max or d.depth_max or 15
    self.depth_time = 0  -- Oscillation phase

    -- Pulse animation (optional, kept from original)
    self.pulse_enabled = opts.pulse_enabled or d.pulse_enabled or false
    self.pulse_amp = opts.pulse_amp or d.pulse_amp or 0.25
    self.pulse_speed = opts.pulse_speed or d.pulse_speed or 0.8
    self.pulse_time = 0

    -- Lighting
    self.lighting_ambient = 0.3
    self.lighting_diffuse = 0.7

    -- Background color
    self.bg_color = opts.bg_color

    -- Create font
    self.font = love.graphics.newFont(self.font_size)

    -- Viewport
    self:setViewport(0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Clear geometry cache to ensure fresh generation
    Text3DGeometry.clearCache()

    -- Generate initial 3D mesh
    self.mesh_cache_text = nil
    self.mesh = nil
    self:regenerateMesh()
end

function Text3DView:setViewport(x, y, w, h)
    self.viewport = { x = x, y = y, width = w, height = h }
end

function Text3DView:destroy()
    if self.font then
        self.font:release()
        self.font = nil
    end
    -- Clear geometry cache
    Text3DGeometry.clearCache()
end

-- ============================================================================
-- Mesh Generation
-- ============================================================================

function Text3DView:regenerateMesh()
    local display_text = self.use_time and os.date('%H:%M:%S') or self.text

    -- Only regenerate if text changed
    if self.mesh_cache_text == display_text then
        return
    end

    self.mesh_cache_text = display_text
    self.mesh = Text3DGeometry.generate(display_text, self.font, self.extrude_depth)
end

-- ============================================================================
-- Update
-- ============================================================================

function Text3DView:update(dt)
    -- Regenerate mesh if using time (text changes every second)
    if self.use_time then
        self:regenerateMesh()
    end

    -- Update rotation angles with mode support
    self:updateRotation('x', dt)
    self:updateRotation('y', dt)
    self:updateRotation('z', dt)

    -- Update depth oscillation
    if self.depth_oscillate then
        self.depth_time = self.depth_time + dt * self.depth_speed
        -- Sine wave oscillation between min and max
        local t = math.sin(self.depth_time * math.pi * 2) * 0.5 + 0.5  -- 0 to 1
        self.depth = self.depth_min + (self.depth_max - self.depth_min) * t
    else
        self.depth = self.depth_base
    end

    -- Update pulse animation
    if self.pulse_enabled then
        self.pulse_time = self.pulse_time + dt * self.pulse_speed
    end

    -- Update movement (DVD-style bouncing)
    if self.move_enabled then
        -- Apply movement speed multiplier
        local vx = self.velocity.x * self.move_speed
        local vy = self.velocity.y * self.move_speed

        self.position.x = self.position.x + vx * dt
        self.position.y = self.position.y + vy * dt

        -- Bounce collision will be calculated in draw() after we know projected bounds
    end
end

-- Helper function to update rotation for a single axis
function Text3DView:updateRotation(axis, dt)
    local mode = self['rotation_mode_' .. axis]
    local speed = self['spin_' .. axis]
    local range = self['rotation_range_' .. axis]

    if mode == 'continuous' then
        -- Unrestricted continuous rotation
        self.rotation[axis] = self.rotation[axis] + speed * dt
        -- Wrap to prevent overflow
        self.rotation[axis] = self.rotation[axis] % (2 * math.pi)
    elseif mode == 'oscillate' then
        -- Oscillate within range
        self.rotation[axis] = self.rotation[axis] + speed * self.rotation_dir[axis] * dt

        -- Clamp and reverse direction at boundaries
        if self.rotation[axis] > range then
            self.rotation[axis] = range
            self.rotation_dir[axis] = -1
        elseif self.rotation[axis] < -range then
            self.rotation[axis] = -range
            self.rotation_dir[axis] = 1
        end
    end
end

-- ============================================================================
-- Rendering
-- ============================================================================

-- HSV to RGB conversion (kept from original)
local function hsv_to_rgb(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    return r, g, b
end

function Text3DView:draw()
    if not self.mesh or not self.mesh.vertices or #self.mesh.vertices == 0 then
        return
    end

    -- Save graphics state
    love.graphics.push()
    love.graphics.origin()  -- Correct for fullscreen screensaver

    local w, h = self.viewport.width, self.viewport.height
    local cx, cy = w / 2, h / 2

    -- Clear background
    if self.bg_color then
        love.graphics.clear(self.bg_color[1], self.bg_color[2], self.bg_color[3], 1)
    else
        local br, bg, bb = love.graphics.getBackgroundColor()
        love.graphics.clear(br or 0, bg or 0, bb or 0, 1)
    end

    -- Calculate viewport scale
    local viewport_scale = math.min(w, h) / 600

    -- Calculate size with pulse
    -- Note: Mesh vertices are normalized to unit space, scale up for rendering
    local base_scale = viewport_scale * self.size * 100
    if self.pulse_enabled then
        base_scale = base_scale * (1.0 + math.sin(self.pulse_time * math.pi * 2) * self.pulse_amp)
    end

    -- Build rotation matrix
    local R = Math3D.buildRotationMatrix(self.rotation.x, self.rotation.y, self.rotation.z)

    -- Transform and project vertices
    local transformed = {}
    local projected = {}

    for i, v in ipairs(self.mesh.vertices) do
        -- Apply rotation
        local rotated = Math3D.matMulVec(R, {v[1] * base_scale, v[2] * base_scale, v[3] * base_scale})

        -- Apply translation (position offset)
        local world_x = rotated[1] + self.position.x
        local world_y = rotated[2] + self.position.y
        local world_z = rotated[3] + self.depth * 100  -- Push into positive Z

        transformed[i] = {world_x, world_y, world_z}

        -- Perspective projection
        local depth_z = world_z
        if depth_z < 0.1 then depth_z = 0.1 end  -- Clamp near plane

        local k = self.fov / depth_z
        local screen_x = cx + world_x * k
        local screen_y = cy + world_y * k

        projected[i] = {screen_x, screen_y, depth = world_z}
    end

    -- Calculate projected bounds for bounce collision
    if self.move_enabled then
        local min_x, max_x = math.huge, -math.huge
        local min_y, max_y = math.huge, -math.huge

        for _, p in ipairs(projected) do
            min_x = math.min(min_x, p[1])
            max_x = math.max(max_x, p[1])
            min_y = math.min(min_y, p[2])
            max_y = math.max(max_y, p[2])
        end

        local half_width = (max_x - min_x) / 2
        local half_height = (max_y - min_y) / 2

        -- Bounce off screen edges
        if self.position.x - half_width < -cx then
            self.position.x = -cx + half_width
            self.velocity.x = math.abs(self.velocity.x)
        elseif self.position.x + half_width > cx then
            self.position.x = cx - half_width
            self.velocity.x = -math.abs(self.velocity.x)
        end

        if self.position.y - half_height < -cy then
            self.position.y = -cy + half_height
            self.velocity.y = math.abs(self.velocity.y)
        elseif self.position.y + half_height > cy then
            self.position.y = cy - half_height
            self.velocity.y = -math.abs(self.velocity.y)
        end
    end

    -- Process faces with depth and lighting
    local faces_to_draw = {}

    -- DEBUG: Count faces that pass culling
    local total_faces = #self.mesh.faces
    local culled_faces = 0

    for _, face in ipairs(self.mesh.faces) do
        local v1 = transformed[face[1]]
        local v2 = transformed[face[2]]
        local v3 = transformed[face[3]]

        if v1 and v2 and v3 then
            -- Calculate face normal in world space
            local normal = Math3D.calculateFaceNormal(v1, v2, v3)
            local normal_len = Math3D.vecLen(normal)

            if normal_len > 0.0001 then
                normal = Math3D.vecNormalize(normal)

                -- Backface culling: Calculate view direction from face to camera
                -- Camera is at origin (0,0,0), face center is at average of vertices
                local face_center = {
                    (v1[1] + v2[1] + v3[1]) / 3,
                    (v1[2] + v2[2] + v3[2]) / 3,
                    (v1[3] + v2[3] + v3[3]) / 3
                }
                -- View direction points from face toward camera (negative of face position)
                local view_dir = {-face_center[1], -face_center[2], -face_center[3]}
                local view_dot = Math3D.vecDot(normal, view_dir)

                -- Only draw if normal points toward viewer (positive dot product)
                if view_dot > 0 then
                    -- Calculate average depth for sorting
                    local avg_depth = (v1[3] + v2[3] + v3[3]) / 3

                    -- Calculate lighting (simple directional light from camera)
                    local light_dir = {0, 0, 1}  -- Light coming from viewer
                    local n_dot_l = Math3D.vecDot(normal, light_dir)
                    local shade = self.lighting_ambient + self.lighting_diffuse * math.max(0, n_dot_l)

                    table.insert(faces_to_draw, {
                        indices = face,
                        depth = avg_depth,
                        shade = shade
                    })
                else
                    culled_faces = culled_faces + 1
                end
            end
        end
    end

    -- DEBUG: Print culling stats once every 60 frames
    if not self.debug_frame_count then self.debug_frame_count = 0 end
    self.debug_frame_count = self.debug_frame_count + 1
    if self.debug_frame_count >= 60 then
        print(string.format("[3DText] Total faces: %d, Culled: %d, Rendered: %d",
            total_faces, culled_faces, #faces_to_draw))
        self.debug_frame_count = 0
    end

    -- Sort faces back-to-front (painter's algorithm)
    table.sort(faces_to_draw, function(a, b) return a.depth > b.depth end)

    -- Draw faces
    for _, face_data in ipairs(faces_to_draw) do
        local face = face_data.indices
        local shade = face_data.shade

        -- Get projected vertices
        local p1 = projected[face[1]]
        local p2 = projected[face[2]]
        local p3 = projected[face[3]]

        if p1 and p2 and p3 then
            -- Get color
            local r, g, b
            if self.color_mode == 'rainbow' then
                local hue = (face_data.depth / 1000 + self.pulse_time * 0.1) % 1.0
                r, g, b = hsv_to_rgb(hue, 0.8, 1.0)
            elseif self.use_hsv then
                r, g, b = hsv_to_rgb(self.color_h, self.color_s, self.color_v)
            else
                r, g, b = self.color[1], self.color[2], self.color[3]
            end

            -- Apply shading
            r = r * shade
            g = g * shade
            b = b * shade

            love.graphics.setColor(r, g, b, 1)
            love.graphics.polygon('fill',
                p1[1], p1[2],
                p2[1], p2[2],
                p3[1], p3[2]
            )
        end
    end

    -- Restore graphics state
    love.graphics.pop()
end

return Text3DView