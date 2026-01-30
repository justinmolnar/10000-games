local GameBaseView = require('src.games.views.game_base_view')
local SnakeView = GameBaseView:extend('SnakeView')

function SnakeView:init(game_state, variant)
    SnakeView.super.init(self, game_state, variant)

    -- Game-specific view config
    self.GRID_SIZE = game_state.GRID_SIZE or 20
    local cfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.snake and self.di.config.games.snake.view) or {})
    self.bg_color = cfg.bg_color or {0.05, 0.1, 0.05}
end

function SnakeView:drawContent()

    local game = self.game
    local GRID_SIZE = self.GRID_SIZE

    -- Get viewport dimensions
    local viewport_width = game.viewport_width or game.game_width
    local viewport_height = game.viewport_height or game.game_height

    -- Calculate zoom based on arena mode and camera mode
    local zoom
    local camera_mode = game.params.camera_mode or "follow_head"

    if game.is_fixed_arena then
        -- Fixed arena: zoom behavior depends on camera mode
        local arena_pixel_width = game.grid_width * GRID_SIZE
        local arena_pixel_height = game.grid_height * GRID_SIZE

        local zoom_x = viewport_width / arena_pixel_width
        local zoom_y = viewport_height / arena_pixel_height

        if camera_mode == "fixed" then
            -- Fixed camera MUST show entire arena - use MIN zoom (fit both dimensions)
            -- Ignore variant's camera_zoom - always show entire arena
            zoom = math.min(zoom_x, zoom_y)
        else
            -- Following cameras (follow_head, center_of_mass) - use MAX zoom to fill window
            -- Respect variant's camera_zoom as minimum
            local min_zoom = math.max(zoom_x, zoom_y)
            local requested_zoom = game.params.camera_zoom or 1.0
            zoom = math.max(min_zoom, requested_zoom)
        end
    else
        -- Dynamic arena: Grid already adjusted for zoom, so use 1.0 for rendering
        zoom = 1.0
    end

    love.graphics.push()

    -- Calculate camera focus point based on camera mode
    local focus_x, focus_y = game.game_width / 2, game.game_height / 2

    if camera_mode == "follow_head" and #game.snake.body > 0 then
        -- Follow snake head
        if game.params.use_trail and game.snake.smooth_x then
            -- Use smooth float position for smooth camera following
            focus_x = game.snake.smooth_x * GRID_SIZE
            focus_y = game.snake.smooth_y * GRID_SIZE
        else
            -- Use grid position for classic mode
            local head = game.snake.body[1]
            focus_x = head.x * GRID_SIZE + GRID_SIZE / 2
            focus_y = head.y * GRID_SIZE + GRID_SIZE / 2
        end

    elseif camera_mode == "center_of_mass" and #game.snake.body > 0 then
        -- Center on snake's center of mass
        if game.params.use_trail and game.snake.smooth_x then
            -- For smooth mode, just use head position (trail doesn't have discrete segments)
            focus_x = game.snake.smooth_x * GRID_SIZE
            focus_y = game.snake.smooth_y * GRID_SIZE
        else
            -- Classic mode: average all segment positions
            local sum_x, sum_y = 0, 0
            for _, segment in ipairs(game.snake.body) do
                sum_x = sum_x + segment.x
                sum_y = sum_y + segment.y
            end
            focus_x = (sum_x / #game.snake.body) * GRID_SIZE + GRID_SIZE / 2
            focus_y = (sum_y / #game.snake.body) * GRID_SIZE + GRID_SIZE / 2
        end

    end
    -- "fixed" mode: focus stays at arena center (default focus_x/y)

    -- Clamp camera focus to prevent showing out of bounds
    local viewport_center_x = viewport_width / 2
    local viewport_center_y = viewport_height / 2

    -- Calculate visible area at current zoom (in arena space)
    local visible_width = viewport_width / zoom
    local visible_height = viewport_height / zoom

    -- Clamp focus to keep view within bounds
    local min_focus_x = visible_width / 2
    local max_focus_x = game.game_width - visible_width / 2
    local min_focus_y = visible_height / 2
    local max_focus_y = game.game_height - visible_height / 2

    focus_x = math.max(min_focus_x, math.min(max_focus_x, focus_x))
    focus_y = math.max(min_focus_y, math.min(max_focus_y, focus_y))

    love.graphics.translate(viewport_center_x, viewport_center_y)
    love.graphics.scale(zoom, zoom)
    love.graphics.translate(-focus_x, -focus_y)

    -- Draw background
    self:drawBackground()

    -- Draw arena shape boundaries
    self:drawArenaBoundaries()

    local snake_sprite_fallback = game.data.icon_sprite or "game_spider-0"
    local game_config = self.di and self.di.config and self.di.config.games and self.di.config.games.snake
    local tint = self:getTint("SnakeGame", game_config)

    -- Draw snake (sprite or fallback)
    -- Support for girth (thickness) and invisible_tail
    local girth = game.params.girth or 1
    local segment_size = GRID_SIZE - 1

    -- Check for smooth movement mode (analog turning with trail)
    if game.params.use_trail then
        -- Draw trail
        local trail_points = game.snake.smooth_trail:getPoints()
        if #trail_points > 0 then
            love.graphics.setColor(0.3, 0.8, 0.3)
            love.graphics.setLineWidth(segment_size * girth)

            -- Draw trail as connected line segments
            for i = 1, #trail_points - 1 do
                local p1, p2 = trail_points[i], trail_points[i + 1]
                love.graphics.line(p1.x * GRID_SIZE, p1.y * GRID_SIZE, p2.x * GRID_SIZE, p2.y * GRID_SIZE)
            end

            -- Connect last trail point to head
            local last = trail_points[#trail_points]
            love.graphics.line(last.x * GRID_SIZE, last.y * GRID_SIZE,
                game.snake.smooth_x * GRID_SIZE, game.snake.smooth_y * GRID_SIZE)

            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1)
        end

        -- Draw head at smooth position with rotation
        local head_x = game.snake.smooth_x * GRID_SIZE
        local head_y = game.snake.smooth_y * GRID_SIZE

        -- Scale head size by girth
        local head_size = segment_size * girth

        -- Try to get head sprite
        local sprite = nil
        local sprite_style = game.sprite_style or "uniform"
        if game.sprites then
            if sprite_style == "segmented" then
                sprite = game.sprites["seg_head"]
            else
                sprite = game.sprites["segment"]
            end
        end

        if sprite then
            love.graphics.setColor(1, 1, 1)
            local sx = head_size / sprite:getWidth()
            local sy = head_size / sprite:getHeight()
            love.graphics.draw(sprite, head_x, head_y, game.snake.smooth_angle, sx, sy, sprite:getWidth()/2, sprite:getHeight()/2)
        else
            -- Fallback rectangle
            love.graphics.push()
            love.graphics.translate(head_x, head_y)
            love.graphics.rotate(game.snake.smooth_angle)
            love.graphics.setColor(0.2, 1, 0.2)
            love.graphics.rectangle("fill", -head_size/2, -head_size/2, head_size, head_size)
            love.graphics.pop()
            love.graphics.setColor(1, 1, 1)
        end

        -- Skip normal snake rendering
        goto skip_normal_snake
    end

    for i, segment in ipairs(game.snake.body) do
        -- Skip drawing tail segments if invisible_tail is enabled (except head)
        if game.params.invisible_tail and i > 1 then
            goto continue
        end

        -- Determine sprite type and rotation
        local sprite_name = "body"  -- default
        local rotation = 0
        local sprite_style = game.sprite_style or "uniform"

        -- Determine direction for this segment
        local dir
        if sprite_style == "segmented" then
            -- Use different sprites for head/body/tail
            if i == 1 then
                -- Head
                sprite_name = "seg_head"
                dir = game.snake.direction
                rotation = math.atan2(dir.y, dir.x)  -- Right=0, Down=π/2, Left=π, Up=-π/2
            elseif i == #game.snake.body then
                -- Tail - point away from previous segment
                local prev = game.snake.body[i-1]
                local dx = segment.x - prev.x
                local dy = segment.y - prev.y
                dir = {x = dx, y = dy}
                sprite_name = "seg_tail"
                rotation = math.atan2(dy, dx)
            else
                -- Body - point toward next segment
                local next_seg = game.snake.body[i+1]
                local dx = next_seg.x - segment.x
                local dy = next_seg.y - segment.y
                dir = {x = dx, y = dy}
                sprite_name = "seg_body"
                rotation = math.atan2(dy, dx)
            end
        else
            -- Uniform: use segment sprite for all parts
            sprite_name = "segment"
            if i == 1 then
                -- Head points in direction snake is moving
                dir = game.snake.direction
                rotation = math.atan2(dir.y, dir.x)
            elseif i == #game.snake.body then
                -- Tail points away from previous segment
                local prev = game.snake.body[i-1]
                local dx = segment.x - prev.x
                local dy = segment.y - prev.y
                dir = {x = dx, y = dy}
                rotation = math.atan2(dy, dx)
            else
                -- Body points toward next segment
                local next_seg = game.snake.body[i+1]
                local dx = next_seg.x - segment.x
                local dy = next_seg.y - segment.y
                dir = {x = dx, y = dy}
                rotation = math.atan2(dy, dx)
            end
        end

        -- Get all cells this segment occupies based on girth
        local girth_cells = game:getGirthCells(segment, girth, dir)

        -- Determine effective sprite key (specific sprite or fallback to "segment")
        local sprite_key = sprite_name
        if game.sprites and not game.sprites[sprite_key] and sprite_style == "uniform" then
            sprite_key = "segment"
        end

        -- Draw sprite at each girth cell position
        for _, cell in ipairs(girth_cells) do
            local draw_x = cell.x * GRID_SIZE + segment_size / 2
            local draw_y = cell.y * GRID_SIZE + segment_size / 2

            self:drawEntityCentered(draw_x, draw_y, segment_size, segment_size, sprite_key, snake_sprite_fallback, {
                rotation = rotation,
                tint = tint
            })
        end

        ::continue::
    end

    ::skip_normal_snake::

    -- Draw additional player snakes and AI snakes (all in game.snakes, index 2+)
    for i = 2, #(game.snakes or {}) do
        local psnake = game.snakes[i]
        if psnake.alive then
            local is_ai = psnake.behavior ~= nil
            local tint = is_ai and {1, 0.3, 0.3} or {0.3, 0.3, 1}  -- Red for AI, Blue for player

            if game.params.use_trail and psnake.smooth_x and not is_ai then
                -- Draw smooth trail
                local trail_points = psnake.smooth_trail and psnake.smooth_trail:getPoints() or {}
                if #trail_points > 0 then
                    love.graphics.setColor(tint)
                    love.graphics.setLineWidth(segment_size * girth)

                    for j = 1, #trail_points - 1 do
                        local p1, p2 = trail_points[j], trail_points[j + 1]
                        love.graphics.line(p1.x * GRID_SIZE, p1.y * GRID_SIZE, p2.x * GRID_SIZE, p2.y * GRID_SIZE)
                    end

                    local last = trail_points[#trail_points]
                    love.graphics.line(last.x * GRID_SIZE, last.y * GRID_SIZE,
                        psnake.smooth_x * GRID_SIZE, psnake.smooth_y * GRID_SIZE)

                    love.graphics.setLineWidth(1)
                end

                -- Draw smooth head
                local head_x = psnake.smooth_x * GRID_SIZE
                local head_y = psnake.smooth_y * GRID_SIZE
                local head_size = segment_size * girth

                love.graphics.push()
                love.graphics.translate(head_x, head_y)
                love.graphics.rotate(psnake.smooth_angle or 0)
                love.graphics.setColor(tint)
                love.graphics.rectangle("fill", -head_size/2, -head_size/2, head_size, head_size)
                love.graphics.pop()
            else
                -- Grid-based drawing
                for _, segment in ipairs(psnake.body) do
                    local draw_x = segment.x * GRID_SIZE
                    local draw_y = segment.y * GRID_SIZE
                    local seg_size = GRID_SIZE - 1

                    love.graphics.setColor(tint)
                    love.graphics.rectangle("fill", draw_x, draw_y, seg_size, seg_size)
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1)

    -- Draw foods
    local food_size = GRID_SIZE - 1
    for i, food in ipairs(game:getFoods()) do
        self:drawEntityAt(food.x * GRID_SIZE, food.y * GRID_SIZE, food_size, food_size, "food", "check-0", {
            tint = self:getIndexedColor(i)
        })
    end

    -- Draw obstacles (skip wall-type obstacles for rectangles - they're rendered by drawArenaBoundaries)
    local arena_shape = game.params.arena_shape or "rectangle"
    local obstacle_size = GRID_SIZE - 1
    for _, obstacle in ipairs(game:getObstacles()) do
        if (obstacle.type == "walls" or obstacle.type == "bounce_wall") and arena_shape == "rectangle" then
            goto continue_obstacle
        end

        self:drawEntityAt(obstacle.x * GRID_SIZE, obstacle.y * GRID_SIZE, obstacle_size, obstacle_size, "obstacle", "msg_error-0")

        ::continue_obstacle::
    end

    -- Shrinking arena wall obstacles are collision-only; visual walls rendered by drawArenaBoundaries

    -- Draw fog of war effect
    local fog_mode = game.params.fog_of_war
    if fog_mode and fog_mode ~= "none" then
        local sources = {}
        if fog_mode == "player" and game.snake.body[1] then
            local head = game.snake.body[1]
            table.insert(sources, {x = head.x * GRID_SIZE + GRID_SIZE/2, y = head.y * GRID_SIZE + GRID_SIZE/2})
        elseif fog_mode == "center" then
            table.insert(sources, {x = game.game_width/2, y = game.game_height/2})
        end
        self:renderFog(game.game_width, game.game_height, sources, 150)
    end

    -- Reset camera transformation before drawing HUD
    love.graphics.pop()

    game.hud:draw(viewport_width, viewport_height)
end

function SnakeView:drawArenaBoundaries()
    local game = self.game
    local GRID_SIZE = self.GRID_SIZE
    local arena_shape = game.params.arena_shape or "rectangle"

    -- Get moving walls offset
    local offset_x = (game.params.moving_walls and game.arena_controller.wall_offset_x) or 0
    local offset_y = (game.params.moving_walls and game.arena_controller.wall_offset_y) or 0

    -- For arenas with wall_mode death/bounce, draw edge walls (accounting for moving walls)
    if (game.params.wall_mode == "death" or game.params.wall_mode == "bounce") and arena_shape == "rectangle" then
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        local wall_thickness = GRID_SIZE - 1

        -- Calculate wall positions (shifted by offsets)
        local left_wall_x = math.max(0, offset_x)
        local right_wall_x = game.grid_width - 1 + math.min(0, offset_x)
        local top_wall_y = math.max(0, offset_y)
        local bottom_wall_y = game.grid_height - 1 + math.min(0, offset_y)

        -- Top wall
        for x = 0, game.grid_width - 1 do
            love.graphics.rectangle("fill", x * GRID_SIZE, top_wall_y * GRID_SIZE, wall_thickness, wall_thickness)
        end

        -- Bottom wall
        for x = 0, game.grid_width - 1 do
            love.graphics.rectangle("fill", x * GRID_SIZE, bottom_wall_y * GRID_SIZE, wall_thickness, wall_thickness)
        end

        -- Left wall
        for y = 0, game.grid_height - 1 do
            love.graphics.rectangle("fill", left_wall_x * GRID_SIZE, y * GRID_SIZE, wall_thickness, wall_thickness)
        end

        -- Right wall
        for y = 0, game.grid_height - 1 do
            love.graphics.rectangle("fill", right_wall_x * GRID_SIZE, y * GRID_SIZE, wall_thickness, wall_thickness)
        end

        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Shaped arenas (circle/hexagon) - draw boundary via ArenaController
    if arena_shape ~= "rectangle" and game.arena_controller then
        game.arena_controller:drawBoundary(GRID_SIZE)
    end
end

return SnakeView