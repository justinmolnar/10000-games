local Object = require('class')

local Text3DView = Object:extend('ScreensaverText3DView')

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
    self.extrude_layers = opts.extrude_layers or d.extrude_layers or 12

    -- Camera/projection
    self.fov = opts.fov or d.fov or 400
    self.distance = opts.distance or d.distance or 10
    -- Unified size (dimensionless scale multiplier)
    self.size = opts.size or d.size or 1.0

    -- Color settings
    self.color_mode = opts.color_mode or d.color_mode or 'solid'
    self.use_hsv = opts.use_hsv or d.use_hsv or false
    self.color = opts.color or { d.color_r or 1.0, d.color_g or 1.0, d.color_b or 1.0 }
    self.color_h = opts.color_h or d.color_h or 0.15
    self.color_s = opts.color_s or d.color_s or 1.0
    self.color_v = opts.color_v or d.color_v or 1.0

    -- Rotation (degrees per second) and current angles
    -- Non-negative spin magnitudes
    self.spin_x = math.max(0, opts.spin_x or d.spin_x or 0.0)
    self.spin_y = math.max(0, opts.spin_y or d.spin_y or 0.8)
    self.spin_z = math.max(0, opts.spin_z or d.spin_z or 0.1)
    self.angle_x, self.angle_y, self.angle_z = 0, 0, 0

    -- Movement settings/state
    self.move_enabled = (opts.move_enabled ~= nil) and opts.move_enabled or (d.move_enabled ~= false)
    self.move_mode = opts.move_mode or d.move_mode or 'bounce'
    self.move_speed = opts.move_speed or d.move_speed or 0.25
    self.move_radius = opts.move_radius or d.move_radius or 120
    self.bounce_speed_x = opts.bounce_speed_x or d.bounce_speed_x or 100
    self.bounce_speed_y = opts.bounce_speed_y or d.bounce_speed_y or 80
    self.move_time = 0
    self.bounce_pos = { x = 0, y = 0 }
    self.bounce_vel = { x = self.bounce_speed_x, y = self.bounce_speed_y }

    -- Pulse/scale animation
    self.pulse_enabled = opts.pulse_enabled or d.pulse_enabled or false
    self.pulse_amp = opts.pulse_amp or d.pulse_amp or 0.25
    self.pulse_speed = opts.pulse_speed or d.pulse_speed or 0.8
    self.pulse_time = 0

    -- Effects
    self.wavy_baseline = opts.wavy_baseline or d.wavy_baseline or false
    self.specular = opts.specular or d.specular or 0.0

    -- Optional background color for consistent preview/full-screen clear
    self.bg_color = opts.bg_color

    -- Create font
    self.font = love.graphics.newFont(self.font_size)

    -- Viewport
    self:setViewport(0, 0, love.graphics.getWidth(), love.graphics.getHeight())
end

function Text3DView:setViewport(x, y, w, h)
    self.viewport = { x = x, y = y, width = w, height = h }
end
function Text3DView:destroy()
    if self.font then
        self.font:release()
        self.font = nil
    end
end

-- HSV to RGB conversion
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

function Text3DView:update(dt)
    -- Update rotation angles - but keep them constrained
    self.angle_x = self.angle_x + self.spin_x * dt
    self.angle_y = self.angle_y + self.spin_y * dt
    self.angle_z = self.angle_z + self.spin_z * dt

    -- Constrain pitch to prevent upside-down text (±60 degrees max)
    local max_pitch = math.pi / 3
    if self.angle_x > max_pitch then self.angle_x = max_pitch end
    if self.angle_x < -max_pitch then self.angle_x = -max_pitch end

    -- Constrain yaw to prevent text from showing backwards (±70 degrees max)
    local max_yaw = math.pi * 0.388
    if self.angle_y > max_yaw then self.angle_y = max_yaw end
    if self.angle_y < -max_yaw then self.angle_y = -max_yaw end

    -- Roll can wrap around
    self.angle_z = self.angle_z % (2 * math.pi)

    -- Update movement with accurate bounds and unified speed
    if self.move_enabled then
        self.move_time = self.move_time + dt * self.move_speed

        local w, h = self.viewport.width, self.viewport.height
        local display_text = self.use_time and os.date('%H:%M:%S') or self.text
        local text_width = self.font and self.font:getWidth(display_text) or 0
        local text_height = self.font and self.font:getHeight() or 0

        local viewport_scale = math.min(w, h) / 600
        local base_scale = viewport_scale * (self.size or 1.0)
        if self.pulse_enabled then
            base_scale = base_scale * (1.0 + math.sin(self.pulse_time * math.pi * 2) * self.pulse_amp)
        end
        local depth = self.distance
        if depth < 0.01 then depth = 0.01 end
        local perspective_scale = (self.fov or 400) / (depth * 100)
        local final_scale = base_scale * perspective_scale

        -- Compute precise AABB over all layers with rotation + shear
        local layers_to_draw = math.max(3, math.floor(self.extrude_layers * viewport_scale))
        local roll = math.sin(self.angle_z) * 0.05
        local cr, sr = math.abs(math.cos(roll)), math.abs(math.sin(roll))
        local half_w, half_h = 0, 0
        for layer = 0, layers_to_draw do
            local z_offset = -layer * 2
            local layer_depth = self.distance - z_offset / 50
            local layer_scale = (self.fov or 400) / (layer_depth * 100)
            local layer_final = base_scale * layer_scale
            local lw = (text_width * layer_final)
            local lh = (text_height * layer_final)
            local rot_w = lw * cr + lh * sr
            local rot_h = lh * cr + lw * sr
            local shear_x = math.abs(math.sin(self.angle_y) * z_offset * 0.5 * viewport_scale)
            local shear_y = math.abs(math.sin(self.angle_x) * z_offset * 0.5 * viewport_scale)
            local cand_w = shear_x + rot_w * 0.5
            local cand_h = shear_y + rot_h * 0.5
            if cand_w > half_w then half_w = cand_w end
            if cand_h > half_h then half_h = cand_h end
        end
        local wave_h = (self.wavy_baseline and (10 * base_scale)) or 0
        half_h = half_h + wave_h
        local min_x = -w * 0.5 + half_w
        local max_x =  w * 0.5 - half_w
        local min_y = -h * 0.5 + half_h
        local max_y =  h * 0.5 - half_h

    local speed_scale = math.max(0, self.move_speed or 0)
    -- Scale speed with viewport so time-to-edge is consistent across preview vs full-screen
    local dim_scale = math.max(0.01, math.min(w, h) / 600)
    local base_vx = (self.bounce_speed_x or 100) * speed_scale * dim_scale
    local base_vy = (self.bounce_speed_y or 80) * speed_scale * dim_scale
        local dir_x = (self.bounce_vel.x or 1) >= 0 and 1 or -1
        local dir_y = (self.bounce_vel.y or 1) >= 0 and 1 or -1
        local eff_vx = dir_x * base_vx
        local eff_vy = dir_y * base_vy

        self.bounce_pos.x = self.bounce_pos.x + eff_vx * dt
        self.bounce_pos.y = self.bounce_pos.y + eff_vy * dt

        if self.bounce_pos.x > max_x then
            self.bounce_pos.x = max_x
            self.bounce_vel.x = -math.abs(self.bounce_vel.x or 1)
        elseif self.bounce_pos.x < min_x then
            self.bounce_pos.x = min_x
            self.bounce_vel.x = math.abs(self.bounce_vel.x or 1)
        end

        if self.bounce_pos.y > max_y then
            self.bounce_pos.y = max_y
            self.bounce_vel.y = -math.abs(self.bounce_vel.y or 1)
        elseif self.bounce_pos.y < min_y then
            self.bounce_pos.y = min_y
            self.bounce_vel.y = math.abs(self.bounce_vel.y or 1)
        end
    end

    if self.pulse_enabled then
        self.pulse_time = self.pulse_time + dt * self.pulse_speed
    end
end

function Text3DView:draw()
    -- Save graphics state that we might alter
    local old_canvas = love.graphics.getCanvas()
    local old_scissor = { love.graphics.getScissor() }
    local old_font = love.graphics.getFont()
    local old_shader = love.graphics.getShader()
    local old_blend_mode, old_alpha_mode = love.graphics.getBlendMode()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    love.graphics.push()
    love.graphics.origin()
    local w, h = self.viewport.width, self.viewport.height
    local cx, cy = w / 2, h / 2
    
    -- Get current text
    local display_text = self.text
    if self.use_time then
        display_text = os.date('%H:%M:%S')
    end
    
    -- Scale everything based on viewport size (for preview compatibility)
    local viewport_scale = math.min(w, h) / 600
    
    -- Calculate base scale with pulse
    local base_scale = viewport_scale * (self.size or 1.0)
    if self.pulse_enabled then
        base_scale = base_scale * (1.0 + math.sin(self.pulse_time * math.pi * 2) * self.pulse_amp)
    end
    
    -- Calculate position offset (scaled to viewport)
    local offset_x, offset_y = 0, 0
    if self.move_enabled then
        -- Always use bounce-style motion for clarity and to match DVD-style behavior
        offset_x = self.bounce_pos.x
        offset_y = self.bounce_pos.y
    end
    
    -- Clear to configured background (desktop color) for both preview and full-screen
    do
        local r,g,b = 0,0,0
        if self.bg_color and self.bg_color[1] then
            r,g,b = self.bg_color[1], self.bg_color[2], self.bg_color[3]
        else
            local br,bg,bb = love.graphics.getBackgroundColor()
            r,g,b = br or 0, bg or 0, bb or 0
        end
        love.graphics.clear(r, g, b, 1)
    end
    
    -- Set font
    if self.font then love.graphics.setFont(self.font) end
    
    -- Get text dimensions
    local text_width = self.font:getWidth(display_text)
    local text_height = self.font:getHeight()
    
    -- Calculate number of layers to draw based on viewport size
    local layers_to_draw = math.max(3, math.floor(self.extrude_layers * viewport_scale))
    
    -- Draw extruded layers (back to front)
    for layer = layers_to_draw, 0, -1 do
        -- Calculate 3D position for this layer
        local z_offset = -layer * 2  -- depth per layer
        
        -- Calculate perspective scale based on distance (adjusted for viewport)
        local depth = self.distance - z_offset / 50
    local perspective_scale = (self.fov or 400) / (depth * 100)
        
        -- Apply rotations to create 3D effect on the offset
        -- But keep the text itself always readable
        local rx = math.cos(self.angle_x)
        local ry = math.cos(self.angle_y)
        local rz = math.cos(self.angle_z)
        
        -- Calculate shear/offset based on rotation to simulate 3D
        local shear_x = math.sin(self.angle_y) * z_offset * 0.5 * viewport_scale
        local shear_y = math.sin(self.angle_x) * z_offset * 0.5 * viewport_scale
        
        -- Position on screen
        local screen_x = cx + offset_x + shear_x
        local screen_y = cy + offset_y + shear_y
        
        -- Calculate shade (darker for back layers)
        local depth_factor = layer / math.max(1, layers_to_draw)
        local base_brightness = 1.0 - depth_factor * 0.7
        
        -- Add specular highlight to front layers
        if layer <= 2 and self.specular > 0 then
            base_brightness = base_brightness + self.specular * (1 - depth_factor)
        end
        
        -- Get color for this layer
        local r, g, b
        if self.color_mode == 'rainbow' then
            local hue = (layer / math.max(1, layers_to_draw) + (self.move_time or 0) * 0.1) % 1.0
            r, g, b = hsv_to_rgb(hue, 0.8, 1.0)
        elseif self.use_hsv then
            r, g, b = hsv_to_rgb(self.color_h, self.color_s, self.color_v)
        else
            r, g, b = self.color[1], self.color[2], self.color[3]
        end
        
        -- Apply shading
        r = r * base_brightness
        g = g * base_brightness
        b = b * base_brightness
        
        love.graphics.setColor(r or 1, g or 1, b or 1, 1)
        
        -- Calculate final scale
        local final_scale = base_scale * perspective_scale
        
        -- Draw each character separately if wavy baseline is enabled
        if self.wavy_baseline and layer == 0 then
            local x_pos = screen_x - (text_width * final_scale) / 2
            for i = 1, #display_text do
                local char = display_text:sub(i, i)
                local char_width = self.font:getWidth(char)
                local wave_offset = math.sin(self.move_time * 3 + i * 0.5) * 10 * final_scale
                
                love.graphics.print(
                    char,
                    x_pos,
                    screen_y + wave_offset - (text_height * final_scale) / 2,
                    math.sin(self.angle_z) * 0.05,  -- slight roll effect (reduced)
                    final_scale,
                    final_scale
                )
                x_pos = x_pos + char_width * final_scale
            end
        else
            -- Draw the whole text (make sure it stays within bounds)
            if final_scale > 0 and final_scale < 10 then  -- sanity check
                love.graphics.print(
                    display_text,
                    screen_x,
                    screen_y,
                    math.sin(self.angle_z) * 0.05,  -- slight roll effect (reduced)
                    final_scale,
                    final_scale,
                    text_width / 2,
                    text_height / 2
                )
            end
        end
    end
    -- Restore graphics state (balance our push and revert any changes)
    love.graphics.pop()
    -- We didn't change canvas here, but reset scissor/shader/blend/color/font to be safe
    if old_scissor[1] then love.graphics.setScissor(old_scissor[1], old_scissor[2], old_scissor[3], old_scissor[4]) else love.graphics.setScissor() end
    if old_shader ~= love.graphics.getShader() then love.graphics.setShader(old_shader) end
    love.graphics.setBlendMode(old_blend_mode, old_alpha_mode)
    if old_font then love.graphics.setFont(old_font) end
    if old_r and old_g and old_b and old_a then love.graphics.setColor(old_r, old_g, old_b, old_a) end
end

return Text3DView