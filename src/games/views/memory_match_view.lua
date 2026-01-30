local GameBaseView = require('src.games.views.game_base_view')
local MemoryMatchView = GameBaseView:extend('MemoryMatchView')

function MemoryMatchView:init(game_state, variant)
    MemoryMatchView.super.init(self, game_state, variant)

    -- Game-specific view config
    self.CARD_WIDTH = game_state.CARD_WIDTH or 60
    self.CARD_HEIGHT = game_state.CARD_HEIGHT or 80
    self.CARD_SPACING = (game_state.params and game_state.params.card_spacing) or 10
    local cfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.memory_match and self.di.config.games.memory_match.view) or {})
    self.bg_color = cfg.bg_color or {0.05, 0.08, 0.12}
    self.start_x = game_state.start_x
    self.start_y = game_state.start_y
    self.grid_size = game_state.grid_size
end

function MemoryMatchView:drawContent()

    local game = self.game

    love.graphics.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3])
    love.graphics.rectangle('fill', 0, 0, game.game_width, game.game_height)

    -- Distraction elements (if enabled)
    if game.params.distraction_elements then
        self:drawDistractionParticles()
    end

    -- Use variant palette if available
    local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
    local card_sprite_fallback = game.data.icon_sprite or "game_freecell-0"
    local paletteManager = self.di and self.di.paletteManager

    -- Get mouse position for fog of war (tracked by fog_controller)
    local mouse_x, mouse_y = 0, 0
    if game.fog_controller then
        mouse_x, mouse_y = game.fog_controller:getMousePosition()
    end

    -- Draw cards
    local cards = game.entity_controller:getEntitiesByType("card")
    for i, card in ipairs(cards) do
        -- Skip matched cards in gravity mode (they disappear)
        if game.params.gravity_enabled and game.matched_pairs[card.value] then
            goto continue
        end

        -- Use physics position if gravity enabled, grid position otherwise
        local x, y
        if game.params.gravity_enabled then
            x = card.x
            y = card.y
        else
            local row = math.floor(card.grid_index / game.grid_cols)
            local col = card.grid_index % game.grid_cols
            x = game.start_x + col * (game.CARD_WIDTH + game.params.card_spacing)
            y = game.start_y + row * (game.CARD_HEIGHT + game.params.card_spacing)
        end

        -- Card rotation effect (separate from flip animation)
        local rotation = 0
        if game.params.card_rotation and not game.memorize_phase then
            rotation = (love.timer.getTime() + card.grid_index * 0.3) * 0.5
        end
        if game.params.spinning_cards and not game.memorize_phase then
            rotation = love.timer.getTime() * 3 + card.grid_index * 0.5
        end

        -- Shuffle animation (only in non-gravity mode)
        local draw_x, draw_y = x, y
        local ec = game.entity_controller
        local start_pos = ec:getShuffleStartPosition(card)
        if not game.params.gravity_enabled and start_pos then
            local progress = ec:getShuffleProgress()
            local eased_progress = progress * progress * (3 - 2 * progress)  -- Smoothstep
            draw_x = start_pos.x + (x - start_pos.x) * eased_progress
            draw_y = start_pos.y + (y - start_pos.y) * eased_progress
        end

        -- Determine face up/down based on flip animation progress
        local flip_progress = card.flip_anim:getProgress()
        local face_up = flip_progress >= 0.5

        -- Fog of war: Calculate alpha for ALL cards based on distance from spotlight
        -- Calculate fog alpha using FogOfWar component
        local fog_alpha = 1.0
        if not game.memorize_phase and game.fog_controller then
            local card_center_x = draw_x + game.CARD_WIDTH / 2
            local card_center_y = draw_y + game.CARD_HEIGHT / 2
            fog_alpha = game.fog_controller:calculateAlpha(card_center_x, card_center_y, mouse_x, mouse_y)
        end

        love.graphics.push()
        love.graphics.translate(draw_x + game.CARD_WIDTH/2, draw_y + game.CARD_HEIGHT/2)

        -- Apply Z-rotation (spinning/rotation effects)
        love.graphics.rotate(rotation)

        -- Apply Y-axis flip rotation based on flip_progress
        -- Scale X by cos(progress * PI) to simulate 3D flip
        local flip_angle = flip_progress * math.pi
        local flip_scale = math.abs(math.cos(flip_angle))
        -- Show face (face_up=true) when angle >= π/2 (progress >= 0.5)
        face_up = (flip_angle >= math.pi / 2)

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

                local icon_padding = game.params.card_icon_padding or 10
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
    
    game.hud:draw(game.game_width, game.game_height)

    -- Additional game-specific stats (below standard HUD)
    if not game.vm_render_mode then
        local s = 0.85
        local lx = 10
        local hud_y = 90  -- Start below standard HUD

        love.graphics.setColor(1, 1, 1)

        -- Memorize phase indicator
        if game.memorize_phase then
            love.graphics.setColor(1, 1, 0)
            love.graphics.print("MEMORIZING: " .. string.format("%.1f", game.memorize_timer:getRemaining()) .. "s", lx, hud_y, 0, 1.2, 1.2)
            hud_y = hud_y + 25
            love.graphics.setColor(1, 1, 1)
        end

        -- Perfect matches (if enabled)
        if game.params.perfect_bonus > 0 and game.metrics.perfect > 0 then
            love.graphics.setColor(0.5, 1, 0.5)
            love.graphics.print("Perfect: " .. game.metrics.perfect, lx, hud_y, 0, s, s)
            hud_y = hud_y + 18
            love.graphics.setColor(1, 1, 1)
        end

        -- Time remaining (if time limit)
        if game.params.time_limit > 0 then
            love.graphics.setColor(game.time_remaining < 10 and {1, 0.3, 0.3} or {1, 1, 0.5})
            love.graphics.print("Time Left: " .. string.format("%.1f", game.time_remaining), lx, hud_y, 0, s, s)
            hud_y = hud_y + 18
            love.graphics.setColor(1, 1, 1)
        end

        -- Move limit
        if game.params.move_limit > 0 then
            local moves_left = game.params.move_limit - game.moves_made
            love.graphics.setColor(moves_left < 5 and {1, 0.3, 0.3} or {1, 1, 1})
            love.graphics.print("Moves Left: " .. moves_left, lx, hud_y, 0, s, s)
            hud_y = hud_y + 18
            love.graphics.setColor(1, 1, 1)
        end

        -- Combo counter
        if game.params.combo_multiplier > 0 and game.current_combo > 0 then
            love.graphics.setColor(0.2, 1, 0.2)
            love.graphics.print("Combo: x" .. game.current_combo, lx, hud_y, 0, s, s)
            hud_y = hud_y + 18
            love.graphics.setColor(1, 1, 1)
        end

        -- Chain requirement
        if game.params.chain_requirement > 0 and game.chain_target then
            love.graphics.setColor(1, 1, 0.2)
            love.graphics.print("Find: " .. game.chain_target, lx, hud_y, 0, s, s)
            love.graphics.print("Chain: " .. game.chain_progress .. "/" .. game.params.chain_requirement, lx, hud_y + 15, 0, s * 0.8, s * 0.8)
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