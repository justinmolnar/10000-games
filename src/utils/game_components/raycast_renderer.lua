local Object = require('class')

local RaycastRenderer = Object:extend('RaycastRenderer')

function RaycastRenderer:new(config)
    config = config or {}

    self.fov = config.fov or 60
    self.ray_count = config.ray_count or 320
    self.render_distance = config.render_distance or 20
    self.wall_height = config.wall_height or 1.0

    self.ceiling_color = config.ceiling_color or {0.2, 0.2, 0.3}
    self.floor_color = config.floor_color or {0.3, 0.25, 0.2}
    self.wall_color_ns = config.wall_color_ns or {0.7, 0.2, 0.2}
    self.wall_color_ew = config.wall_color_ew or {0.2, 0.2, 0.7}
    self.goal_color = config.goal_color or {0.2, 0.9, 0.3}

    -- Depth buffer for billboard occlusion
    self.depth_buffer = {}

    return self
end

function RaycastRenderer:getDepthBuffer()
    return self.depth_buffer
end

function RaycastRenderer:drawCeilingAndFloor(w, h)
    -- Ceiling
    love.graphics.setColor(self.ceiling_color[1], self.ceiling_color[2], self.ceiling_color[3])
    love.graphics.rectangle('fill', 0, 0, w, h / 2)

    -- Floor
    love.graphics.setColor(self.floor_color[1], self.floor_color[2], self.floor_color[3])
    love.graphics.rectangle('fill', 0, h / 2, w, h / 2)
end

function RaycastRenderer:drawWalls(w, h, player, map, map_w, map_h, goal)
    if not map or #map == 0 then return end

    local fov_rad = math.rad(self.fov)
    local ray_angle_step = fov_rad / self.ray_count
    local half_h = h / 2
    local col_width = w / self.ray_count

    -- Clear and resize depth buffer
    for i = 1, w do
        self.depth_buffer[i] = self.render_distance
    end

    for i = 0, self.ray_count - 1 do
        local ray_angle = player.angle - fov_rad / 2 + i * ray_angle_step

        local dist, side, hit_x, hit_y = self:castRay(
            player.x, player.y, ray_angle,
            self.render_distance, map, map_w, map_h
        )

        if dist > 0 then
            -- Fisheye correction
            local corrected_dist = dist * math.cos(ray_angle - player.angle)

            -- Store in depth buffer (for each pixel column this ray covers)
            local start_col = math.floor(i * col_width) + 1
            local end_col = math.floor((i + 1) * col_width)
            for col = start_col, math.min(end_col, w) do
                self.depth_buffer[col] = corrected_dist
            end

            -- Wall height
            local wall_h = (h / corrected_dist) * self.wall_height
            wall_h = math.min(wall_h, h * 2)

            -- Distance shading
            local shade = 1 - math.min(1, corrected_dist / self.render_distance)
            shade = math.max(0.1, shade)

            -- Check if goal tile
            local tile_x = math.floor(hit_x)
            local tile_y = math.floor(hit_y)
            local is_goal = goal and (tile_x == goal.x and tile_y == goal.y)

            -- Wall color
            local color
            if is_goal then
                color = self.goal_color
            elseif side == 0 then
                color = self.wall_color_ns
            else
                color = self.wall_color_ew
            end

            love.graphics.setColor(color[1] * shade, color[2] * shade, color[3] * shade)

            -- Draw wall slice
            local x = i * col_width
            local y = half_h - wall_h / 2
            love.graphics.rectangle('fill', x, y, col_width + 1, wall_h)
        end
    end
end

-- DDA raycasting algorithm
function RaycastRenderer:castRay(start_x, start_y, angle, max_dist, map, map_w, map_h)
    local dir_x = math.cos(angle)
    local dir_y = math.sin(angle)

    local map_x = math.floor(start_x)
    local map_y = math.floor(start_y)

    local delta_dist_x = math.abs(1 / (dir_x ~= 0 and dir_x or 0.00001))
    local delta_dist_y = math.abs(1 / (dir_y ~= 0 and dir_y or 0.00001))

    local step_x, step_y
    local side_dist_x, side_dist_y

    if dir_x < 0 then
        step_x = -1
        side_dist_x = (start_x - map_x) * delta_dist_x
    else
        step_x = 1
        side_dist_x = (map_x + 1 - start_x) * delta_dist_x
    end

    if dir_y < 0 then
        step_y = -1
        side_dist_y = (start_y - map_y) * delta_dist_y
    else
        step_y = 1
        side_dist_y = (map_y + 1 - start_y) * delta_dist_y
    end

    local hit = false
    local side = 0
    local steps = 0
    local max_steps = math.floor(max_dist * 2)

    while not hit and steps < max_steps do
        if side_dist_x < side_dist_y then
            side_dist_x = side_dist_x + delta_dist_x
            map_x = map_x + step_x
            side = 0
        else
            side_dist_y = side_dist_y + delta_dist_y
            map_y = map_y + step_y
            side = 1
        end

        steps = steps + 1

        if map_x < 1 or map_x > map_w or map_y < 1 or map_y > map_h then
            break
        end

        if map[map_y] and map[map_y][map_x] and map[map_y][map_x] == 1 then
            hit = true
        end
    end

    if hit then
        local dist
        if side == 0 then
            dist = (map_x - start_x + (1 - step_x) / 2) / dir_x
        else
            dist = (map_y - start_y + (1 - step_y) / 2) / dir_y
        end
        return math.abs(dist), side, map_x, map_y
    end

    return -1, 0, 0, 0
end

-- Convenience method to draw everything
function RaycastRenderer:draw(w, h, player, map, map_w, map_h, goal)
    self:drawCeilingAndFloor(w, h)
    self:drawWalls(w, h, player, map, map_w, map_h, goal)
end

return RaycastRenderer
