local Object = require('class')
local Config = rawget(_G, 'DI_CONFIG') or {}
local MemoryMatchView = Object:extend('MemoryMatchView')

function MemoryMatchView:init(game_state, variant)
    self.game = game_state
    self.variant = variant -- Store variant data for future use (Phase 1.3)
    -- NOTE: In Phase 2, card icons will be loaded from variant.sprite_set
    -- e.g., "icons_1" (classic), "icons_2" (animals), "icons_3" (gems), "icons_4" (tech)
    self.CARD_WIDTH = game_state.CARD_WIDTH or 60
    self.CARD_HEIGHT = game_state.CARD_HEIGHT or 80
    self.CARD_SPACING = game_state.CARD_SPACING or 10
    self.di = game_state and game_state.di
    local cfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.memory_match and self.di.config.games.memory_match.view) or
                 (Config and Config.games and Config.games.memory_match and Config.games.memory_match.view) or {})
    self.bg_color = cfg.bg_color or {0.05, 0.08, 0.12}
    self.hud = cfg.hud or { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 70, text_x = 90, row_y = {10, 30, 50, 70} }
    self.start_x = game_state.start_x
    self.start_y = game_state.start_y
    self.grid_size = game_state.grid_size
    self.sprite_loader = nil
    self.sprite_manager = nil
end

function MemoryMatchView:ensureLoaded()
    if not self.sprite_loader then
        self.sprite_loader = (self.di and self.di.spriteLoader) or error("MemoryMatchView: spriteLoader not available in DI")
    end

    if not self.sprite_manager then
        self.sprite_manager = (self.di and self.di.spriteManager) or error("MemoryMatchView: spriteManager not available in DI")
    end
end

function MemoryMatchView:draw()
    self:ensureLoaded()

    local game = self.game

    love.graphics.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3])
    love.graphics.rectangle('fill', 0, 0, game.game_width, game.game_height)

    -- Distraction elements (if enabled)
    if game.distraction_elements then
        self:drawDistractionParticles()
    end

    -- Phase 1.6 & 2.3: Use variant palette if available
    local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
    local card_sprite_fallback = game.data.icon_sprite or "game_freecell-0"
    local paletteManager = self.di and self.di.paletteManager

    -- Get mouse position for fog of war (use tracked position from game, not screen position)
    local mouse_x, mouse_y = game.mouse_x, game.mouse_y

    -- Phase 2.3: Draw cards (sprite or fallback)
    for i, card in ipairs(game.cards) do
        -- Skip matched cards in gravity mode (they disappear)
        if game.gravity_enabled and game.matched_pairs[card.value] then
            goto continue
        end

        -- Use physics position if gravity enabled, grid position otherwise
        local x, y
        if game.gravity_enabled then
            x = card.x
            y = card.y
        else
            local row = math.floor((i-1) / game.grid_cols)
            local col = (i-1) % game.grid_cols
            x = game.start_x + col * (game.CARD_WIDTH + game.CARD_SPACING)
            y = game.start_y + row * (game.CARD_HEIGHT + game.CARD_SPACING)
        end

        -- Card rotation effect (separate from flip animation)
        local rotation = 0
        if game.card_rotation and not game.memorize_phase then
            rotation = (love.timer.getTime() + i * 0.3) * 0.5
        end
        if game.spinning_cards and not game.memorize_phase then
            rotation = love.timer.getTime() * 3 + i * 0.5
        end

        -- Shuffle animation (only in non-gravity mode)
        local draw_x, draw_y = x, y
        if not game.gravity_enabled and game.is_shuffling and game.shuffle_start_positions and game.shuffle_start_positions[i] then
            local progress = math.min(1, game.shuffle_animation_timer / game.shuffle_animation_duration)
            local start_x = game.shuffle_start_positions[i].x
            local start_y = game.shuffle_start_positions[i].y
            -- Smooth interpolation with easing
            local eased_progress = progress * progress * (3 - 2 * progress)  -- Smoothstep
            draw_x = start_x + (x - start_x) * eased_progress
            draw_y = start_y + (y - start_y) * eased_progress
        end

        -- Determine face up/down based on flip state
        local face_up = false
        if game.memorize_phase or game.matched_pairs[card.value] or game:isSelected(i) then
            face_up = true
        end

        -- Override with flip animation state
        if card.flip_state == "face_up" or card.flip_state == "flipping_up" then
            face_up = true
        elseif card.flip_state == "face_down" or card.flip_state == "flipping_down" then
            face_up = false
        end

        -- Fog of war: Calculate alpha for ALL cards based on distance from spotlight
        local fog_alpha = 1.0
        if game.fog_of_war > 0 and not game.memorize_phase then
            local card_center_x = draw_x + game.CARD_WIDTH / 2
            local card_center_y = draw_y + game.CARD_HEIGHT / 2
            local dist = math.sqrt((mouse_x - card_center_x)^2 + (mouse_y - card_center_y)^2)

            -- Use variant-configurable inner radius and darkness
            local inner_radius = game.fog_of_war * game.fog_inner_radius
            local outer_radius = game.fog_of_war

            if dist < inner_radius then
                fog_alpha = 1.0  -- Fully visible
            elseif dist > outer_radius then
                fog_alpha = game.fog_darkness  -- Configurable darkness (0.0 = pitch black, 1.0 = fully visible)
            else
                -- Smooth gradient from 1.0 to fog_darkness
                local t = (dist - inner_radius) / (outer_radius - inner_radius)
                fog_alpha = 1.0 - (t * (1.0 - game.fog_darkness))
            end
        end

        love.graphics.push()
        love.graphics.translate(draw_x + game.CARD_WIDTH/2, draw_y + game.CARD_HEIGHT/2)

        -- Apply Z-rotation (spinning/rotation effects)
        love.graphics.rotate(rotation)

        -- Apply Y-axis flip rotation based on flip_progress
        -- Scale X by cos(progress * PI) to simulate 3D flip
        local flip_scale = 1
        if card.flip_state == "flipping_up" then
            local flip_angle = card.flip_progress * math.pi
            flip_scale = math.abs(math.cos(flip_angle))
            -- Flipping UP: progress 0→1, angle 0→π
            -- Show back (face_up=false) until π/2, then show face (face_up=true)
            face_up = (flip_angle >= math.pi / 2)
        elseif card.flip_state == "flipping_down" then
            local flip_angle = card.flip_progress * math.pi
            flip_scale = math.abs(math.cos(flip_angle))
            -- Flipping DOWN: progress 1→0, angle π→0
            -- Show face (face_up=true) until π/2, then show back (face_up=false)
            face_up = (flip_angle > math.pi / 2)
        end

        love.graphics.scale(flip_scale, 1)
        love.graphics.translate(-game.CARD_WIDTH/2, -game.CARD_HEIGHT/2)

        if face_up then
            -- Card face (showing icon) - apply fog alpha
            -- Try to use loaded card face sprite
            local icon_key = "icon_" .. card.icon_id
            if game.sprites and game.sprites[icon_key] then
                -- Draw sprite at full card size (cards ARE the sprites now)
                local sprite = game.sprites[icon_key]
                love.graphics.setColor(1, 1, 1, fog_alpha)
                love.graphics.draw(sprite, 0, 0, 0,
                    game.CARD_WIDTH / sprite:getWidth(),
                    game.CARD_HEIGHT / sprite:getHeight())
            else
                -- Fallback: draw card background and icon system sprite
                love.graphics.setColor(0.9 * fog_alpha, 0.9 * fog_alpha, 0.85 * fog_alpha, fog_alpha)
                love.graphics.rectangle('fill', 0, 0, game.CARD_WIDTH, game.CARD_HEIGHT)

                local icon_padding = game.CARD_ICON_PADDING or 10
                local icon_size = math.min(game.CARD_WIDTH, game.CARD_HEIGHT) - icon_padding
                local icon_x = (game.CARD_WIDTH - icon_size) / 2
                local icon_y = (game.CARD_HEIGHT - icon_size) / 2

                self.sprite_loader:drawSprite(
                    card_sprite_fallback,
                    icon_x,
                    icon_y,
                    icon_size,
                    icon_size,
                    {fog_alpha, fog_alpha, fog_alpha},
                    palette_id
                )
            end
        else
            -- Card back (apply fog alpha)
            if game.sprites and game.sprites.card_back then
                -- Draw card back sprite at full card size with fog alpha
                local sprite = game.sprites.card_back
                love.graphics.setColor(1, 1, 1, fog_alpha)
                love.graphics.draw(sprite, 0, 0, 0,
                    game.CARD_WIDTH / sprite:getWidth(),
                    game.CARD_HEIGHT / sprite:getHeight())
            else
                -- Fallback to colored rectangle with fog alpha
                love.graphics.setColor(0.4 * fog_alpha, 0.5 * fog_alpha, 0.9 * fog_alpha, fog_alpha)
                love.graphics.rectangle('fill', 0, 0, game.CARD_WIDTH, game.CARD_HEIGHT)
                love.graphics.setColor(0.25 * fog_alpha, 0.35 * fog_alpha, 0.7 * fog_alpha, fog_alpha)
                love.graphics.rectangle('line', 0, 0, game.CARD_WIDTH, game.CARD_HEIGHT)
            end
        end

        love.graphics.pop()

        ::continue::
    end
    
    -- HUD with all new parameters
    local hud_icon_size = self.hud.icon_size or 16
    local s = self.hud.text_scale or 0.85
    local lx = 10
    local hud_y = 10
    love.graphics.setColor(1, 1, 1)

    if game.memorize_phase then
        love.graphics.print("Memorize! " .. string.format("%.1f", game.memorize_timer), lx, hud_y, 0, s, s)
        hud_y = hud_y + 20
    else
        -- Score (if any scoring modifiers are enabled)
        if game.perfect_bonus > 0 or game.combo_multiplier > 0 or game.speed_bonus > 0 then
            love.graphics.setColor(1, 1, 0.3)
            love.graphics.print("Score: " .. game.metrics.score, lx, hud_y, 0, s, s)
            love.graphics.setColor(1, 1, 1)
            hud_y = hud_y + 20
        end

        -- Matches
        love.graphics.print("Matches: " .. game.metrics.matches .. "/" .. game.total_pairs, lx, hud_y, 0, s, s)
        hud_y = hud_y + 20

        -- Perfect matches
        if game.perfect_bonus > 0 then
            love.graphics.print("Perfect: " .. game.metrics.perfect, lx, hud_y, 0, s, s)
            hud_y = hud_y + 20
        end

        -- Time
        love.graphics.print("Time: " .. string.format("%.1f", game.metrics.time), lx, hud_y, 0, s, s)
        hud_y = hud_y + 20

        -- Time limit (countdown)
        if game.time_limit > 0 then
            love.graphics.setColor(game.time_remaining < 10 and {1, 0.3, 0.3} or {1, 1, 0.5})
            love.graphics.print("Time Left: " .. string.format("%.1f", game.time_remaining), lx, hud_y, 0, s, s)
            hud_y = hud_y + 20
            love.graphics.setColor(1, 1, 1)
        end

        -- Move limit
        if game.move_limit > 0 then
            local moves_left = game.move_limit - game.moves_made
            love.graphics.setColor(moves_left < 5 and {1, 0.3, 0.3} or {1, 1, 1})
            love.graphics.print("Moves: " .. game.moves_made .. "/" .. game.move_limit, lx, hud_y, 0, s, s)
            hud_y = hud_y + 20
            love.graphics.setColor(1, 1, 1)
        end

        -- Combo counter
        if game.combo_multiplier > 0 and game.current_combo > 0 then
            love.graphics.setColor(0.2, 1, 0.2)
            love.graphics.print("Combo: x" .. game.current_combo, lx, hud_y, 0, s, s)
            hud_y = hud_y + 20
            love.graphics.setColor(1, 1, 1)
        end

        -- Chain requirement
        if game.chain_requirement > 0 and game.chain_target then
            love.graphics.setColor(1, 1, 0.2)
            love.graphics.print("Find: " .. game.chain_target, lx, hud_y, 0, s, s)
            love.graphics.print("Chain: " .. game.chain_progress .. "/" .. game.chain_requirement, lx, hud_y + 15, 0, s * 0.8, s * 0.8)
            hud_y = hud_y + 35
            love.graphics.setColor(1, 1, 1)
        end
    end


    -- Match announcement (large text at bottom)
    if game.match_announcement then
        local font = love.graphics.getFont()
        local scale = 3.0  -- Large text
        local text = game.match_announcement
        local text_width = font:getWidth(text) * scale
        local text_height = font:getHeight() * scale
        local text_x = (game.game_width - text_width) / 2
        local text_y = game.game_height - text_height - 20

        -- Draw shadow for readability
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.print(text, text_x + 2, text_y + 2, 0, scale, scale)

        -- Draw text with pulsing effect
        local pulse = 0.9 + math.sin(love.timer.getTime() * 10) * 0.1
        love.graphics.setColor(1, 1, 0, pulse)  -- Yellow with pulse
        love.graphics.print(text, text_x, text_y, 0, scale, scale)

        love.graphics.setColor(1, 1, 1)  -- Reset color
    end
end

-- Draw distraction particles
function MemoryMatchView:drawDistractionParticles()
    -- Simple floating particle effect
    local time = love.timer.getTime()
    for i = 1, 20 do
        local x = (math.sin(time * 0.5 + i) * 0.5 + 0.5) * self.game.game_width
        local y = (math.cos(time * 0.7 + i * 0.5) * 0.5 + 0.5) * self.game.game_height
        local size = 3 + math.sin(time * 2 + i) * 2
        local alpha = 0.3 + math.sin(time * 3 + i) * 0.2
        love.graphics.setColor(1, 0.5, 0.2, alpha)
        love.graphics.circle('fill', x, y, size)
    end
end

return MemoryMatchView