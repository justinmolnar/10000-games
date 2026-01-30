local GameBaseView = require('src.games.views.game_base_view')
local SpaceShooterView = GameBaseView:extend('SpaceShooterView')

function SpaceShooterView:init(game_state, variant)
    SpaceShooterView.super.init(self, game_state, variant)

    -- Game-specific view config
    local viewcfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.space_shooter and self.di.config.games.space_shooter.view) or {})
    self.bg_color = viewcfg.bg_color or {0.05, 0.05, 0.15}
end

function SpaceShooterView:drawContent()

    local game = self.game
    local g = love.graphics

    local game_width = game.game_width
    local game_height = game.game_height

    -- Draw background
    self:drawBackground()

    local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
    local player_sprite_fallback = game.data.icon_sprite or "game_mine_1-0"
    local paletteManager = self.di and self.di.paletteManager

    -- Get tint for this variant based on config
    local tint = {1, 1, 1}  -- Default: no tint
    local config = (self.di and self.di.config) or Config
    if paletteManager and config and config.games and config.games.space_shooter then
        tint = paletteManager:getTintForVariant(self.variant, "SpaceShooter", config.games.space_shooter)
    end

    -- Draw player (sprite or fallback)
    if game.player then
        -- Note: player.angle is already in radians from movement_controller
        local rotation = game.params.movement_type == "asteroids" and (game.player.angle or 0) or 0
        -- Rotate 180 degrees in reverse gravity mode so player faces downward
        if game.params.reverse_gravity then
            rotation = rotation + math.pi
        end
        -- Player uses corner-based coords, calculate center for drawing
        local center_x = game.player.x + game.player.width / 2
        local center_y = game.player.y + game.player.height / 2

        -- Draw shield visual indicator (like Dodge)
        if game.params.shield and game.health_system:isShieldActive() then
            local shield_alpha = 0.3 + 0.2 * math.sin(love.timer.getTime() * 5)
            g.setColor(0.3, 0.7, 1.0, shield_alpha)
            local shield_radius = math.max(game.player.width, game.player.height) / 2 + 5
            g.circle("line", center_x, center_y, shield_radius, 32)
            g.setColor(1, 1, 1)  -- Reset color after shield
        end

        if game.sprites and game.sprites.player then
            local sprite = game.sprites.player
            local scale_x = game.player.width / sprite:getWidth()
            local scale_y = game.player.height / sprite:getHeight()
            local origin_x = sprite:getWidth() / 2
            local origin_y = sprite:getHeight() / 2

            -- Apply tint when drawing sprite
            g.setColor(tint[1], tint[2], tint[3])
            g.draw(sprite, center_x, center_y, rotation,
                scale_x, scale_y, origin_x, origin_y)
            g.setColor(1, 1, 1)  -- Reset color
        else
            -- Fallback to icon (rotation support for sprite_loader drawing would need to be added)
            g.push()
            g.translate(center_x, center_y)
            g.rotate(rotation)
            self.sprite_loader:drawSprite(
                player_sprite_fallback,
                -game.player.width/2,
                -game.player.height/2,
                game.player.width,
                game.player.height,
                {1, 1, 1},
                palette_id
            )
            g.pop()
        end
    end

    -- Draw enemies (sprite or fallback) - enemies use corner-based coords
    local enemy_sprite_fallback = self.sprite_manager:getMetricSprite(game.data, "kills") or "game_mine_2-0"
    for _, enemy in ipairs(game.enemies) do
        local sprite_key = enemy.type and ("enemy_" .. enemy.type) or nil
        if sprite_key and game.sprites and game.sprites[sprite_key] then
            local sprite = game.sprites[sprite_key]
            -- Apply tint when drawing sprite
            g.setColor(tint[1], tint[2], tint[3])
            g.draw(sprite, enemy.x, enemy.y, 0,
                enemy.width / sprite:getWidth(), enemy.height / sprite:getHeight())
            g.setColor(1, 1, 1)  -- Reset color
        else
            -- Fallback to icon
            self.sprite_loader:drawSprite(
                enemy_sprite_fallback,
                enemy.x,
                enemy.y,
                enemy.width,
                enemy.height,
                {1, 1, 1},
                palette_id
            )
        end
    end

    -- Draw player bullets (sprite or fallback)
    local bullet_sprite_fallback = "msg_information-0"
    for _, bullet in ipairs(game.player_bullets) do
        if game.sprites and game.sprites.bullet_player then
            local sprite = game.sprites.bullet_player
            -- Apply tint when drawing sprite
            g.setColor(tint[1], tint[2], tint[3])
            g.draw(sprite, bullet.x - bullet.width/2, bullet.y - bullet.height/2, 0,
                bullet.width / sprite:getWidth(), bullet.height / sprite:getHeight())
            g.setColor(1, 1, 1)  -- Reset color
        else
            -- Fallback to icon
            self.sprite_loader:drawSprite(
                bullet_sprite_fallback,
                bullet.x - bullet.width/2,
                bullet.y - bullet.height/2,
                bullet.width,
                bullet.height,
                {1, 1, 1},
                palette_id
            )
        end
    end

    -- Draw enemy bullets (sprite or fallback)
    local enemy_bullet_sprite_fallback = "msg_error-0"
    for _, bullet in ipairs(game.enemy_bullets) do
        if game.sprites and game.sprites.bullet_enemy then
            local sprite = game.sprites.bullet_enemy
            -- Apply tint when drawing sprite
            g.setColor(tint[1], tint[2], tint[3])
            g.draw(sprite, bullet.x - bullet.width/2, bullet.y - bullet.height/2, 0,
                bullet.width / sprite:getWidth(), bullet.height / sprite:getHeight())
            g.setColor(1, 1, 1)  -- Reset color
        else
            -- Fallback to icon
            self.sprite_loader:drawSprite(
                enemy_bullet_sprite_fallback,
                bullet.x - bullet.width/2,
                bullet.y - bullet.height/2,
                bullet.width,
                bullet.height,
                {1, 1, 1},
                palette_id
            )
        end
    end

    -- Draw power-ups
    for _, powerup in ipairs(game.powerups) do
        -- Draw power-up based on type (different colors)
        local color = {1, 1, 1}
        if powerup.type == "speed" then
            color = {0, 1, 1}  -- Cyan
        elseif powerup.type == "rapid_fire" then
            color = {1, 1, 0}  -- Yellow
        elseif powerup.type == "pierce" then
            color = {1, 0, 1}  -- Magenta
        elseif powerup.type == "shield" then
            color = {0, 0.5, 1}  -- Blue
        elseif powerup.type == "triple_shot" then
            color = {1, 0.5, 0}  -- Orange
        elseif powerup.type == "spread_shot" then
            color = {0.5, 1, 0}  -- Green
        end

        g.setColor(color)
        g.circle("fill", powerup.x + powerup.width/2, powerup.y + powerup.height/2, powerup.width/2)
        g.setColor(1, 1, 1)
        g.circle("line", powerup.x + powerup.width/2, powerup.y + powerup.height/2, powerup.width/2)
    end

    -- Draw asteroids
    g.setColor(0.5, 0.5, 0.5)
    for _, asteroid in ipairs(game.asteroids) do
        g.push()
        g.translate(asteroid.x + asteroid.width/2, asteroid.y + asteroid.height/2)
        g.rotate(asteroid.rotation)
        g.polygon("fill", {
            -asteroid.width/2, -asteroid.height/2,
            asteroid.width/2, -asteroid.height/3,
            asteroid.width/3, asteroid.height/2,
            -asteroid.width/3, asteroid.height/3
        })
        g.pop()
    end

    -- Draw meteor warnings
    g.setColor(1, 0, 0, 0.5)
    for _, warning in ipairs(game.meteor_warnings) do
        g.circle("fill", warning.x + 15, 30, 20)
        g.setColor(1, 1, 0)
        g.print("!", warning.x + 10, 20, 0, 2, 2)
        g.setColor(1, 0, 0, 0.5)
    end

    -- Draw meteors
    g.setColor(1, 0.3, 0)
    for _, meteor in ipairs(game.meteors) do
        g.circle("fill", meteor.x + meteor.width/2, meteor.y + meteor.height/2, meteor.width/2)
        g.setColor(1, 1, 0)
        g.circle("line", meteor.x + meteor.width/2, meteor.y + meteor.height/2, meteor.width/2 - 3)
        g.setColor(1, 0.3, 0)
    end

    -- Draw gravity wells
    g.setColor(0.5, 0, 1, 0.3)
    for _, well in ipairs(game.gravity_wells) do
        g.circle("fill", well.x, well.y, well.radius)
        g.setColor(0.7, 0.3, 1)
        g.circle("line", well.x, well.y, well.radius)
        g.circle("fill", well.x, well.y, 10)
        g.setColor(0.5, 0, 1, 0.3)
    end

    -- Draw blackout zones
    for _, zone in ipairs(game.blackout_zones) do
        g.setColor(0, 0, 0, 0.8)  -- Dark opaque circles
        g.circle("fill", zone.x, zone.y, zone.radius)
        g.setColor(0.2, 0.2, 0.2, 0.9)  -- Darker outline
        g.circle("line", zone.x, zone.y, zone.radius)
    end

    game.hud:draw(game.game_width, game.game_height)

    -- Additional game-specific stats (below standard HUD)
    if not game.vm_render_mode then
        local s = 0.85
        local lx = 10
        local hud_y = 90  -- Start below standard HUD

        g.setColor(1, 1, 1)

        -- Kills progress
        g.print("Kills: " .. (game.kills or 0) .. "/" .. game.params.victory_limit, lx, hud_y, 0, s, s)
        hud_y = hud_y + 18

        -- Shield (if enabled)
        if game.params.shield then
            local shield_color = game.health_system:isShieldActive() and {0.3, 0.7, 1.0} or {0.5, 0.5, 0.5}
            g.setColor(shield_color)
            g.print("Shield: " .. game.health_system:getShieldHitsRemaining() .. "/" .. game.params.shield_hits, lx, hud_y, 0, s, s)
            hud_y = hud_y + 18
            g.setColor(1, 1, 1)
        end

        -- Ammo display (read from projectile_system directly)
        local ps = game.projectile_system
        if game.params.ammo_enabled and ps then
            if ps.is_reloading then
                local reload_progress = 1 - (ps.reload_timer / game.params.ammo_reload_time)
                g.setColor(1, 1, 0)
                g.print("Reloading...", lx, hud_y, 0, s, s)
                local bar_width, bar_x = 60, lx + 80
                g.rectangle("line", bar_x, hud_y + 2, bar_width, 10)
                g.rectangle("fill", bar_x, hud_y + 2, bar_width * reload_progress, 10)
            else
                local ammo_color = ps.ammo_current < game.params.ammo_capacity * 0.25 and {1, 0.5, 0} or {1, 1, 1}
                g.setColor(ammo_color)
                g.print("Ammo: " .. ps.ammo_current .. "/" .. game.params.ammo_capacity, lx, hud_y, 0, s, s)
            end
            hud_y = hud_y + 18
            g.setColor(1, 1, 1)
        end

        -- Overheat display (read from projectile_system directly)
        if game.params.overheat_enabled and ps then
            local heat_percent = ps.heat_current / game.params.overheat_threshold
            if ps.is_overheated then
                g.setColor(1, 0, 0)
                local cooldown_progress = ps.overheat_timer / game.params.overheat_cooldown
                g.print("OVERHEAT!", lx, hud_y, 0, s, s)
                local bar_width, bar_x = 60, lx + 80
                g.rectangle("line", bar_x, hud_y + 2, bar_width, 10)
                g.rectangle("fill", bar_x, hud_y + 2, bar_width * cooldown_progress, 10)
            else
                g.print("Heat:", lx, hud_y, 0, s, s)
                -- Draw heat bar
                local bar_width = 60
                local bar_x = lx + 50
                local bar_color = heat_percent > 0.75 and {1, 0, 0} or (heat_percent > 0.5 and {1, 1, 0} or {0, 1, 0})
                g.setColor(bar_color)
                g.rectangle("line", bar_x, hud_y + 2, bar_width, 10)
                g.rectangle("fill", bar_x, hud_y + 2, bar_width * heat_percent, 10)
            end
            hud_y = hud_y + 18
            g.setColor(1, 1, 1)
        end

        -- Active power-ups display
        if next(game.active_powerups) then
            for powerup_type, effect in pairs(game.active_powerups) do
                local name = powerup_type:gsub("_", " "):upper()
                local time_left = math.ceil(effect.duration_remaining)
                g.setColor(0, 1, 0)  -- Green for active powerup
                g.print(name .. ": " .. time_left .. "s", lx, hud_y, 0, s * 0.8, s * 0.8)
                hud_y = hud_y + 18
            end
            g.setColor(1, 1, 1)
        end
    end
end

return SpaceShooterView