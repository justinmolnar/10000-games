local Object = require('class')

local MinimapRenderer = Object:extend('MinimapRenderer')

function MinimapRenderer:new(config)
    config = config or {}

    self.size = config.size or 150
    self.padding = config.padding or 10
    self.position = config.position or "top_right"

    self.wall_color = config.wall_color or {0.5, 0.5, 0.6, 0.8}
    self.floor_color = config.floor_color or {0.15, 0.15, 0.2, 0.8}
    self.door_color = config.door_color or {0.5, 0.35, 0.2, 0.9}
    self.player_color = config.player_color or {1, 0.3, 0.3, 0.9}
    self.goal_color = config.goal_color or {0.2, 0.9, 0.3, 0.9}
    self.direction_color = config.direction_color or {1, 1, 0, 0.9}
    self.background_color = config.background_color or {0, 0, 0, 0.5}
    self.enemy_color = config.enemy_color or {1, 0.2, 0.2, 0.9}
    self.show_enemies = config.show_enemies ~= false

    -- Critical path visualization
    self.critical_path_color = config.critical_path_color or {0.2, 0.5, 0.8, 0.8}  -- blue
    self.off_path_color = config.off_path_color or {0.6, 0.3, 0.1, 0.8}  -- orange/brown
    self.show_critical_path = config.show_critical_path or false

    -- Door lookup for minimap
    self.doors = {}

    -- Critical path lookup
    self.critical_path = {}

    return self
end

function MinimapRenderer:draw(viewport_w, viewport_h, map, map_w, map_h, player, goal, doors, enemies)
    if not map or #map == 0 then return end

    -- Update door lookup
    if doors then
        self:setDoors(doors)
    end

    -- Calculate position
    local minimap_x, minimap_y = self:getPosition(viewport_w, viewport_h)

    -- Calculate tile size
    local tile_size = self.size / math.max(map_w, map_h)

    -- Background
    love.graphics.setColor(self.background_color[1], self.background_color[2],
                           self.background_color[3], self.background_color[4])
    love.graphics.rectangle('fill', minimap_x - 2, minimap_y - 2, self.size + 4, self.size + 4)

    -- Draw tiles
    for y = 1, map_h do
        for x = 1, map_w do
            local tile = map[y][x]
            local px = minimap_x + (x - 1) * tile_size
            local py = minimap_y + (y - 1) * tile_size

            -- Check if this is a door
            local door = self:getDoorAt(x, y)

            if tile == 1 then
                love.graphics.setColor(self.wall_color[1], self.wall_color[2],
                                       self.wall_color[3], self.wall_color[4])
            elseif door and door.progress < 1 then
                -- Draw door (brown) - shows as special until fully open
                love.graphics.setColor(self.door_color[1], self.door_color[2],
                                       self.door_color[3], self.door_color[4])
            elseif self.show_critical_path then
                -- Color based on critical path
                if self:isOnCriticalPath(x, y) then
                    love.graphics.setColor(self.critical_path_color[1], self.critical_path_color[2],
                                           self.critical_path_color[3], self.critical_path_color[4])
                else
                    love.graphics.setColor(self.off_path_color[1], self.off_path_color[2],
                                           self.off_path_color[3], self.off_path_color[4])
                end
            else
                love.graphics.setColor(self.floor_color[1], self.floor_color[2],
                                       self.floor_color[3], self.floor_color[4])
            end
            love.graphics.rectangle('fill', px, py, tile_size, tile_size)
        end
    end

    -- Draw goal
    if goal then
        local goal_px = minimap_x + (goal.x - 1) * tile_size
        local goal_py = minimap_y + (goal.y - 1) * tile_size
        love.graphics.setColor(self.goal_color[1], self.goal_color[2],
                               self.goal_color[3], self.goal_color[4])
        love.graphics.rectangle('fill', goal_px, goal_py, tile_size, tile_size)
    end

    -- Draw enemies
    if self.show_enemies and enemies then
        love.graphics.setColor(self.enemy_color[1], self.enemy_color[2],
                               self.enemy_color[3], self.enemy_color[4])
        local enemy_radius = tile_size * 0.35
        for _, enemy in ipairs(enemies) do
            local ex = minimap_x + (enemy.x - 1) * tile_size
            local ey = minimap_y + (enemy.y - 1) * tile_size
            love.graphics.circle('fill', ex, ey, enemy_radius)
        end
    end

    -- Draw player
    if player then
        local player_px = minimap_x + (player.x - 1) * tile_size
        local player_py = minimap_y + (player.y - 1) * tile_size
        local player_radius = tile_size * 0.4

        love.graphics.setColor(self.player_color[1], self.player_color[2],
                               self.player_color[3], self.player_color[4])
        love.graphics.circle('fill', player_px, player_py, player_radius)

        -- Direction indicator
        if player.angle then
            local dir_len = tile_size * 0.8
            local dir_x = player_px + math.cos(player.angle) * dir_len
            local dir_y = player_py + math.sin(player.angle) * dir_len
            love.graphics.setColor(self.direction_color[1], self.direction_color[2],
                                   self.direction_color[3], self.direction_color[4])
            love.graphics.setLineWidth(2)
            love.graphics.line(player_px, player_py, dir_x, dir_y)
            love.graphics.setLineWidth(1)
        end
    end
end

function MinimapRenderer:getPosition(viewport_w, viewport_h)
    if self.position == "top_right" then
        return viewport_w - self.size - self.padding, self.padding
    elseif self.position == "top_left" then
        return self.padding, self.padding
    elseif self.position == "bottom_right" then
        return viewport_w - self.size - self.padding, viewport_h - self.size - self.padding
    elseif self.position == "bottom_left" then
        return self.padding, viewport_h - self.size - self.padding
    else
        return viewport_w - self.size - self.padding, self.padding
    end
end

function MinimapRenderer:setPosition(position)
    self.position = position
end

function MinimapRenderer:setSize(size)
    self.size = size
end

function MinimapRenderer:setDoors(doors)
    self.doors = {}
    if doors then
        for _, door in ipairs(doors) do
            local key = door.x .. "," .. door.y
            self.doors[key] = door
        end
    end
end

function MinimapRenderer:getDoorAt(x, y)
    local key = x .. "," .. y
    return self.doors[key]
end

function MinimapRenderer:setCriticalPath(path)
    self.critical_path = {}
    if path then
        for _, tile in ipairs(path) do
            local key = math.floor(tile.x) .. "," .. math.floor(tile.y)
            self.critical_path[key] = true
        end
    end
    self.show_critical_path = path and #path > 0
end

function MinimapRenderer:isOnCriticalPath(x, y)
    local key = x .. "," .. y
    return self.critical_path[key] == true
end

return MinimapRenderer
