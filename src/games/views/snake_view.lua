local Object = require('class')
local Config = rawget(_G, 'DI_CONFIG') or {}
local SnakeView = Object:extend('SnakeView')

function SnakeView:init(game_state, variant)
    self.game = game_state
    self.variant = variant
    self.GRID_SIZE = game_state.GRID_SIZE or 20
    self.di = game_state and game_state.di
    local cfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.snake and self.di.config.games.snake.view) or
                 (Config and Config.games and Config.games.snake and Config.games.snake.view) or {})
    self.bg_color = cfg.bg_color or {0.05, 0.1, 0.05}
    self.hud = cfg.hud or { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 60, text_x = 80, row_y = {10, 30, 50} }
    self.sprite_loader = nil
    self.sprite_manager = nil
end

function SnakeView:ensureLoaded()
    if not self.sprite_loader then
        self.sprite_loader = (self.di and self.di.spriteLoader) or error("SnakeView: spriteLoader not available in DI")
    end

    if not self.sprite_manager then
        self.sprite_manager = (self.di and self.di.spriteManager) or error("SnakeView: spriteManager not available in DI")
    end
end

function SnakeView:draw()
    self:ensureLoaded()

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
        if game.params.movement_type == "smooth" and game.snake.smooth_x then
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
        if game.params.movement_type == "smooth" and game.snake.smooth_x then
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

    local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
    local snake_sprite_fallback = game.data.icon_sprite or "game_spider-0"
    local paletteManager = self.di and self.di.paletteManager

    -- Get tint for this variant based on config
    local tint = {1, 1, 1}  -- Default: no tint
    local config = (self.di and self.di.config) or Config
    if paletteManager and config and config.games and config.games.snake then
        tint = paletteManager:getTintForVariant(self.variant, "SnakeGame", config.games.snake)
    end

    -- Draw snake (sprite or fallback)
    -- Support for girth (thickness) and invisible_tail
    local girth = game.params.girth or 1
    local segment_size = GRID_SIZE - 1

    -- Check for smooth movement mode (analog turning with trail)
    if game.params.movement_type == "smooth" then
        -- Draw trail
        if #game.snake.smooth_trail > 0 then
            love.graphics.setColor(0.3, 0.8, 0.3)
            love.graphics.setLineWidth(segment_size * girth)

            -- Draw trail as connected line segments
            for i = 1, #game.snake.smooth_trail - 1 do
                local p1 = game.snake.smooth_trail[i]
                local p2 = game.snake.smooth_trail[i + 1]
                love.graphics.line(
                    p1.x * GRID_SIZE,
                    p1.y * GRID_SIZE,
                    p2.x * GRID_SIZE,
                    p2.y * GRID_SIZE
                )
            end

            -- Connect last trail point to head
            if #game.snake.smooth_trail > 0 then
                local last = game.snake.smooth_trail[#game.snake.smooth_trail]
                love.graphics.line(
                    last.x * GRID_SIZE,
                    last.y * GRID_SIZE,
                    game.snake.smooth_x * GRID_SIZE,
                    game.snake.smooth_y * GRID_SIZE
                )
            end

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

        -- Try to get sprite from loaded sprites
        local sprite = nil
        if game.sprites then
            sprite = game.sprites[sprite_name]
            -- For uniform mode, always use segment sprite
            -- For segmented mode, use the specific sprite (seg_head/seg_body/seg_tail)
            if not sprite and sprite_style == "uniform" then
                sprite = game.sprites["segment"]
            end
        end

        -- Draw sprite at each girth cell position
        for _, cell in ipairs(girth_cells) do
            local draw_x = cell.x * GRID_SIZE + segment_size / 2
            local draw_y = cell.y * GRID_SIZE + segment_size / 2

            -- Draw sprite or fallback
            if sprite then
                -- Apply tint and draw with rotation
                love.graphics.setColor(tint[1], tint[2], tint[3])
                local sx = segment_size / sprite:getWidth()
                local sy = segment_size / sprite:getHeight()
                love.graphics.draw(sprite, draw_x, draw_y, rotation, sx, sy, sprite:getWidth()/2, sprite:getHeight()/2)
                love.graphics.setColor(1, 1, 1)  -- Reset color
            else
                -- Fallback to icon system
                self.sprite_loader:drawSprite(
                    snake_sprite_fallback,
                    draw_x - segment_size / 2,
                    draw_y - segment_size / 2,
                    segment_size,
                    segment_size,
                    {1, 1, 1},
                    palette_id
                )
            end
        end

        ::continue::
    end

    ::skip_normal_snake::

    -- Draw additional player snakes (multi-snake control)
    if game.player_snakes and #game.player_snakes > 1 then
        for i = 2, #game.player_snakes do
            local psnake = game.player_snakes[i]
            if psnake.alive then
                if game.params.movement_type == "smooth" and psnake.smooth_x then
                    -- Draw smooth trail
                    if #psnake.smooth_trail > 0 then
                        love.graphics.setColor(0.3, 0.3, 1)  -- Blue tint
                        love.graphics.setLineWidth(segment_size * girth)

                        -- Draw trail
                        for j = 1, #psnake.smooth_trail - 1 do
                            local p1 = psnake.smooth_trail[j]
                            local p2 = psnake.smooth_trail[j + 1]
                            love.graphics.line(
                                p1.x * GRID_SIZE,
                                p1.y * GRID_SIZE,
                                p2.x * GRID_SIZE,
                                p2.y * GRID_SIZE
                            )
                        end

                        -- Connect last trail point to head
                        if #psnake.smooth_trail > 0 then
                            local last = psnake.smooth_trail[#psnake.smooth_trail]
                            love.graphics.line(
                                last.x * GRID_SIZE,
                                last.y * GRID_SIZE,
                                psnake.smooth_x * GRID_SIZE,
                                psnake.smooth_y * GRID_SIZE
                            )
                        end

                        love.graphics.setLineWidth(1)
                    end

                    -- Draw smooth head
                    local head_x = psnake.smooth_x * GRID_SIZE
                    local head_y = psnake.smooth_y * GRID_SIZE
                    local head_size = segment_size * girth

                    love.graphics.push()
                    love.graphics.translate(head_x, head_y)
                    love.graphics.rotate(psnake.smooth_angle)
                    love.graphics.setColor(0.3, 0.3, 1)  -- Blue tint
                    love.graphics.rectangle("fill", -head_size/2, -head_size/2, head_size, head_size)
                    love.graphics.pop()
                else
                    -- Grid-based drawing
                    for _, segment in ipairs(psnake.body) do
                        local draw_x = segment.x * GRID_SIZE
                        local draw_y = segment.y * GRID_SIZE
                        local segment_size = GRID_SIZE - 1

                        -- Draw with blue tint
                        love.graphics.setColor(0.3, 0.3, 1)
                        love.graphics.rectangle("fill", draw_x, draw_y, segment_size, segment_size)
                    end
                end
            end
        end
        love.graphics.setColor(1, 1, 1)
    end

    -- Draw AI snakes
    for _, ai_snake in ipairs(game.ai_snakes or {}) do
        if ai_snake.alive then
            for i, segment in ipairs(ai_snake.body) do
                local draw_x = segment.x * GRID_SIZE
                local draw_y = segment.y * GRID_SIZE
                local segment_size = GRID_SIZE - 1

                -- Draw AI snake with different color (red tint)
                if sprite_key and game.sprites and game.sprites.body_horizontal then
                    local sprite = game.sprites.body_horizontal
                    if paletteManager and palette_id then
                        paletteManager:drawSpriteWithPalette(
                            sprite,
                            draw_x,
                            draw_y,
                            segment_size,
                            segment_size,
                            palette_id,
                            {1, 0.3, 0.3}  -- Red tint for AI
                        )
                    else
                        love.graphics.setColor(1, 0.3, 0.3)
                        love.graphics.draw(sprite, draw_x, draw_y, 0,
                            segment_size / sprite:getWidth(), segment_size / sprite:getHeight())
                    end
                else
                    -- Fallback rectangle
                    love.graphics.setColor(0.8, 0.2, 0.2)
                    love.graphics.rectangle("fill", draw_x, draw_y, segment_size, segment_size)
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1)

    -- Draw foods (multiple foods support with palette-swapped colors)
    for _, food in ipairs(game.foods or {}) do
        -- Determine color based on food type (palette swap)
        local food_color = {1, 1, 1}  -- Normal
        local food_icon = "check-0"
        -- Food visual size is always single tile (collision is single tile)
        local food_size = (GRID_SIZE - 1)

        if food.type == "bad" then
            food_color = {0.8, 0.2, 0.2}  -- Red tint for bad
            food_icon = "msg_warning-0"
        elseif food.type == "golden" then
            food_color = {1, 0.84, 0}  -- Gold tint
            food_icon = "app_favorites-0"
        end

        if game.sprites and game.sprites.food then
            local sprite = game.sprites.food
            -- Draw with color tint for type
            love.graphics.setColor(food_color)
            love.graphics.draw(sprite, food.x * GRID_SIZE, food.y * GRID_SIZE, 0,
                food_size / sprite:getWidth(), food_size / sprite:getHeight())
            love.graphics.setColor(1, 1, 1)
        else
            -- Fallback to icon - DON'T pass palette_id so tint works
            self.sprite_loader:drawSprite(
                food_icon,
                food.x * GRID_SIZE,
                food.y * GRID_SIZE,
                food_size,
                food_size,
                food_color,
                nil  -- No palette override, use tint color instead
            )
        end
    end

    -- Draw obstacles (skip wall-type obstacles for rectangles - they're rendered by drawArenaBoundaries)
    local arena_shape = game.params.arena_shape or "rectangle"
    for _, obstacle in ipairs(game.obstacles) do
        -- Skip wall obstacles for rectangle arenas only - shaped arenas need their walls drawn as obstacles
        if (obstacle.type == "walls" or obstacle.type == "bounce_wall") and arena_shape == "rectangle" then
            goto continue_obstacle
        end

        local sprite = game.sprites and game.sprites.obstacle

        if sprite then
            -- Draw loaded sprite
            local sx = (GRID_SIZE - 1) / sprite:getWidth()
            local sy = (GRID_SIZE - 1) / sprite:getHeight()
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(sprite,
                obstacle.x * GRID_SIZE,
                obstacle.y * GRID_SIZE,
                0, sx, sy)
        else
            -- Fallback to sprite loader system sprites
            self.sprite_loader:drawSprite(
                "msg_error-0",
                obstacle.x * GRID_SIZE,
                obstacle.y * GRID_SIZE,
                GRID_SIZE - 1,
                GRID_SIZE - 1,
                {1, 1, 1},
                palette_id
            )
        end

        ::continue_obstacle::
    end

    -- Shrinking arena wall obstacles are collision-only; visual walls rendered by drawArenaBoundaries

    -- Draw fog of war effect
    self:drawFogOfWar()

    -- Reset camera transformation before drawing HUD
    love.graphics.pop()

    game.hud:draw(viewport_width, viewport_height)
end

function SnakeView:drawBackground()
    local game = self.game

    if game and game.sprites and game.sprites.background then
        local bg = game.sprites.background
        local bg_width = bg:getWidth()
        local bg_height = bg:getHeight()

        -- Apply palette swap
        local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
        local paletteManager = self.di and self.di.paletteManager

        -- Scale or tile background to fit game area
        local scale_x = game.game_width / bg_width
        local scale_y = game.game_height / bg_height

        if paletteManager and palette_id then
            paletteManager:drawSpriteWithPalette(
                bg,
                0,
                0,
                game.game_width,
                game.game_height,
                palette_id,
                {1, 1, 1}
            )
        else
            -- No palette, just draw normally
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(bg, 0, 0, 0, scale_x, scale_y)
        end

        return -- Don't draw solid background if we have a sprite
    end

    -- Fallback: Draw solid color background
    love.graphics.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3])
    love.graphics.rectangle('fill', 0, 0, game.game_width, game.game_height)
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

    -- Shaped arenas (circle/hexagon) show their boundaries via wall blocks only
    -- Rectangle: no special boundary (uses screen edges)
end

function SnakeView:drawFogOfWar()
    local game = self.game
    local fog = game.fog_controller
    if not fog then return end

    local fog_mode = game.params.fog_of_war or "none"
    if fog_mode == "none" then
        return
    end

    fog:clearSources()

    local GRID_SIZE = self.GRID_SIZE
    local fog_radius = 150

    if fog_mode == "player" then
        local head = game.snake.body[1]
        if head then
            local head_x = head.x * GRID_SIZE + GRID_SIZE / 2
            local head_y = head.y * GRID_SIZE + GRID_SIZE / 2
            fog:addVisibilitySource(head_x, head_y, fog_radius)
        end
    elseif fog_mode == "center" then
        fog:addVisibilitySource(game.game_width / 2, game.game_height / 2, fog_radius)
    end

    fog:render(game.game_width, game.game_height)
end

return SnakeView