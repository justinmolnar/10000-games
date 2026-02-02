local Object = require('class')

local BillboardRenderer = Object:extend('BillboardRenderer')

function BillboardRenderer:new(config)
    config = config or {}

    self.fov = config.fov or 60
    self.render_distance = config.render_distance or 20

    -- Depth buffer (populated by RaycastRenderer, used for occlusion)
    self.depth_buffer = {}

    return self
end

-- Must be called after raycasting to enable proper occlusion
function BillboardRenderer:setDepthBuffer(depth_buffer)
    self.depth_buffer = depth_buffer
end

-- Draw all billboards with proper depth sorting and occlusion
function BillboardRenderer:draw(w, h, player, billboards)
    if not billboards or #billboards == 0 then return end

    local fov_rad = math.rad(self.fov)
    local half_fov = fov_rad / 2
    local half_h = h / 2

    -- Sort billboards by distance (far to near for painter's algorithm)
    local sorted = {}
    for i, billboard in ipairs(billboards) do
        local dx = billboard.x - player.x
        local dy = billboard.y - player.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < self.render_distance and dist > 0.1 then
            sorted[#sorted + 1] = {
                billboard = billboard,
                dist = dist,
                dx = dx,
                dy = dy
            }
        end
    end

    table.sort(sorted, function(a, b) return a.dist > b.dist end)

    -- Draw each billboard
    for _, entry in ipairs(sorted) do
        self:drawBillboard(w, h, player, entry, half_fov, half_h)
    end
end

function BillboardRenderer:drawBillboard(w, h, player, entry, half_fov, half_h)
    local billboard = entry.billboard
    local dist = entry.dist
    local dx = entry.dx
    local dy = entry.dy

    -- Calculate angle to billboard relative to player facing
    local angle_to_billboard = math.atan2(dy, dx)
    local relative_angle = angle_to_billboard - player.angle

    -- Normalize angle to -pi to pi
    while relative_angle > math.pi do relative_angle = relative_angle - 2 * math.pi end
    while relative_angle < -math.pi do relative_angle = relative_angle + 2 * math.pi end

    -- Check if within FOV
    if math.abs(relative_angle) > half_fov then return end

    -- Calculate screen X position
    local screen_x = (0.5 + relative_angle / (2 * half_fov)) * w

    -- Fisheye correction
    local corrected_dist = dist * math.cos(relative_angle)

    -- Calculate sprite size based on distance
    local sprite_height = (h / corrected_dist) * (billboard.height or 0.5)
    local sprite_width = sprite_height * (billboard.aspect or 1.0)

    -- Vertical offset (for floating effect)
    local y_offset = billboard.y_offset or 0
    local screen_y = half_h - sprite_height / 2 - (y_offset * h / corrected_dist)

    -- Distance shading
    local shade = 1 - math.min(1, corrected_dist / self.render_distance)
    shade = math.max(0.2, shade)

    -- Column-by-column rendering with depth testing
    local start_col = math.floor(screen_x - sprite_width / 2)
    local end_col = math.floor(screen_x + sprite_width / 2)

    for col = math.max(0, start_col), math.min(w - 1, end_col) do
        local depth_index = col + 1
        local wall_dist = self.depth_buffer[depth_index] or 9999

        -- Only draw if billboard is closer than wall
        if corrected_dist < wall_dist then
            local col_ratio = (col - start_col) / sprite_width
            self:drawBillboardColumn(col, screen_y, sprite_height, col_ratio, billboard, shade)
        end
    end
end

function BillboardRenderer:drawBillboardColumn(col, screen_y, height, col_ratio, billboard, shade)
    -- Use custom draw function if provided
    if billboard.draw_column then
        billboard.draw_column(col, screen_y, height, col_ratio, shade)
        return
    end

    -- Default: draw simple colored rectangle slice
    local color = billboard.color or {1, 1, 0}
    love.graphics.setColor(color[1] * shade, color[2] * shade, color[3] * shade)
    love.graphics.rectangle('fill', col, screen_y, 1, height)
end

-- Convenience: create a diamond billboard
function BillboardRenderer.createDiamond(x, y, config)
    config = config or {}
    return {
        x = x,
        y = y,
        height = config.height or 0.6,
        aspect = config.aspect or 0.6,
        y_offset = config.y_offset or 0,
        color = config.color or {0.2, 1, 0.4},
        draw_column = function(col, screen_y, height, col_ratio, shade)
            -- Diamond shape: width varies by column position
            local center_ratio = math.abs(col_ratio - 0.5) * 2  -- 0 at center, 1 at edges
            local diamond_height = height * (1 - center_ratio)
            local diamond_y = screen_y + (height - diamond_height) / 2

            local color = config.color or {0.2, 1, 0.4}
            love.graphics.setColor(color[1] * shade, color[2] * shade, color[3] * shade)
            love.graphics.rectangle('fill', col, diamond_y, 1, diamond_height)
        end
    }
end

-- Convenience: create a sprite billboard (for future use with images)
function BillboardRenderer.createSprite(x, y, config)
    config = config or {}
    return {
        x = x,
        y = y,
        height = config.height or 1.0,
        aspect = config.aspect or 1.0,
        y_offset = config.y_offset or 0,
        sprite = config.sprite,
        quad = config.quad,
        color = config.color or {1, 1, 1},
        draw_column = config.sprite and function(col, screen_y, height, col_ratio, shade)
            -- Future: sample sprite column
            -- For now, fallback to color
            local color = config.color or {1, 1, 1}
            love.graphics.setColor(color[1] * shade, color[2] * shade, color[3] * shade)
            love.graphics.rectangle('fill', col, screen_y, 1, height)
        end or nil
    }
end

-- Convenience: create an enemy billboard (for future use)
function BillboardRenderer.createEnemy(x, y, config)
    config = config or {}
    return {
        x = x,
        y = y,
        height = config.height or 1.0,
        aspect = config.aspect or 0.8,
        y_offset = config.y_offset or 0,
        color = config.color or {1, 0.2, 0.2},
        enemy_type = config.enemy_type,
        health = config.health or 100,
        state = config.state or "idle"
    }
end

return BillboardRenderer
