local Class = require('lib.class')
local BreakoutView = Class:extend('BreakoutView')

function BreakoutView:init(game)
    self.game = game
end

function BreakoutView:draw()
    love.graphics.push()

    -- Apply camera shake (Phase 11)
    if self.game.camera_shake_enabled then
        love.graphics.translate(self.game.camera_shake_x, self.game.camera_shake_y)
    end

    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle('fill', 0, 0, self.game.arena_width, self.game.arena_height)

    -- Draw bricks
    for _, brick in ipairs(self.game.bricks) do
        if brick.alive then
            love.graphics.push()

            -- Check if brick is flashing (Phase 11)
            local is_flashing = self.game.brick_flash_map[brick] and self.game.brick_flash_map[brick] > 0

            -- Color based on health
            local health_percent = brick.health / brick.max_health
            if is_flashing then
                love.graphics.setColor(1, 1, 1)  -- White flash
            elseif health_percent > 0.66 then
                love.graphics.setColor(0.3, 0.8, 0.3)
            elseif health_percent > 0.33 then
                love.graphics.setColor(0.9, 0.9, 0.3)
            else
                love.graphics.setColor(0.9, 0.3, 0.3)
            end

            -- Draw brick shape (rectangle, circle, or PNG)
            if brick.display_image then
                -- PNG brick - draw the actual image
                love.graphics.setColor(1, 1, 1)  -- Reset color for image drawing

                -- Health tinting for damaged PNG bricks
                if health_percent <= 0.66 and health_percent > 0.33 then
                    love.graphics.setColor(1, 1, 0.5)  -- Yellow tint
                elseif health_percent <= 0.33 then
                    love.graphics.setColor(1, 0.5, 0.5)  -- Red tint
                end

                love.graphics.draw(brick.display_image, brick.x, brick.y)
            elseif brick.shape == "circle" then
                -- Circle brick - x,y is top-left, so center is x + radius, y + radius
                local center_x = brick.x + (brick.radius or brick.width / 2)
                local center_y = brick.y + (brick.radius or brick.height / 2)
                love.graphics.circle('fill', center_x, center_y, brick.radius or brick.width / 2)

                -- Outline
                love.graphics.setColor(0.2, 0.2, 0.2)
                love.graphics.circle('line', center_x, center_y, brick.radius or brick.width / 2)
            else
                -- Rectangle brick (default)
                love.graphics.rectangle('fill', brick.x, brick.y, brick.width, brick.height)

                -- Outline
                love.graphics.setColor(0.2, 0.2, 0.2)
                love.graphics.rectangle('line', brick.x, brick.y, brick.width, brick.height)
            end

            love.graphics.pop()
        end
    end

    -- Draw paddle
    love.graphics.push()
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle('fill',
        self.game.paddle.x - self.game.paddle.width / 2,
        self.game.paddle.y - self.game.paddle.height / 2,
        self.game.paddle.width,
        self.game.paddle.height)
    love.graphics.pop()

    -- Draw ball(s)
    for _, ball in ipairs(self.game.balls) do
        if ball.active then
            -- Draw trail first (behind ball)
            if ball.trail and #ball.trail > 1 then
                for i = 2, #ball.trail do
                    local alpha = 1 - (i / #ball.trail)  -- Fade out older positions
                    local radius = ball.radius * (1 - i / #ball.trail * 0.5)  -- Shrink older positions
                    love.graphics.setColor(1, 1, 1, alpha * 0.6)
                    love.graphics.circle('fill', ball.trail[i].x, ball.trail[i].y, radius)
                end
            end

            -- Draw ball
            love.graphics.push()
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle('fill', ball.x, ball.y, ball.radius)
            love.graphics.pop()
        end
    end

    -- Draw bullets (Phase 9)
    for _, bullet in ipairs(self.game.bullets) do
        love.graphics.push()
        love.graphics.setColor(1, 1, 0.3)
        love.graphics.rectangle('fill',
            bullet.x - bullet.width / 2,
            bullet.y - bullet.height / 2,
            bullet.width,
            bullet.height)
        love.graphics.pop()
    end

    -- Draw obstacles (Phase 9)
    for _, obstacle in ipairs(self.game.obstacles) do
        if obstacle.alive then
            love.graphics.push()

            -- Color based on health if destructible (clear gradient from green to red)
            if self.game.obstacles_destructible then
                local health_percent = obstacle.health / obstacle.max_health
                if health_percent > 0.66 then
                    love.graphics.setColor(0.2, 0.8, 0.2)  -- Green (healthy)
                elseif health_percent > 0.33 then
                    love.graphics.setColor(0.9, 0.9, 0.2)  -- Yellow (damaged)
                else
                    love.graphics.setColor(0.9, 0.2, 0.2)  -- Red (critical)
                end
            else
                love.graphics.setColor(0.6, 0.6, 0.6)  -- Gray (indestructible)
            end

            if obstacle.shape == "circle" then
                love.graphics.circle('fill', obstacle.x + obstacle.size / 2, obstacle.y + obstacle.size / 2, obstacle.size / 2)
            else
                love.graphics.rectangle('fill', obstacle.x, obstacle.y, obstacle.size, obstacle.size)
            end

            -- Add outline for visibility
            love.graphics.setColor(0.2, 0.2, 0.2)
            if obstacle.shape == "circle" then
                love.graphics.circle('line', obstacle.x + obstacle.size / 2, obstacle.y + obstacle.size / 2, obstacle.size / 2)
            else
                love.graphics.rectangle('line', obstacle.x, obstacle.y, obstacle.size, obstacle.size)
            end

            love.graphics.pop()
        end
    end

    -- Draw power-ups (Phase 13)
    for _, powerup in ipairs(self.game.powerups) do
        love.graphics.push()

        -- Color coding for power-up types
        local color = {1, 1, 1}  -- White default
        if powerup.type == "multi_ball" then
            color = {0.3, 0.5, 1}  -- Blue
        elseif powerup.type == "paddle_extend" then
            color = {0.3, 1, 0.3}  -- Green (good)
        elseif powerup.type == "paddle_shrink" then
            color = {1, 0.3, 0.3}  -- Red (bad)
        elseif powerup.type == "slow_motion" then
            color = {0.5, 0.8, 1}  -- Light blue (good)
        elseif powerup.type == "fast_ball" then
            color = {1, 0.5, 0}  -- Orange (bad)
        elseif powerup.type == "laser" then
            color = {1, 1, 0}  -- Yellow
        elseif powerup.type == "sticky_paddle" then
            color = {1, 0.5, 1}  -- Pink
        elseif powerup.type == "extra_life" then
            color = {0, 1, 0}  -- Bright green
        elseif powerup.type == "shield" then
            color = {0, 1, 1}  -- Cyan
        elseif powerup.type == "penetrating_ball" then
            color = {0.8, 0.3, 1}  -- Purple
        elseif powerup.type == "fireball" then
            color = {1, 0.3, 0}  -- Red-orange
        elseif powerup.type == "magnet" then
            color = {0.7, 0.7, 0.7}  -- Gray
        end

        love.graphics.setColor(color)
        love.graphics.rectangle('fill', powerup.x, powerup.y, powerup.width, powerup.height)

        -- Border
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle('line', powerup.x, powerup.y, powerup.width, powerup.height)

        love.graphics.pop()
    end

    -- Draw score popups
    for _, popup in ipairs(self.game.score_popups) do
        popup:draw()
    end

    -- Draw particles (Phase 11)
    if self.game.particle_effects_enabled then
        self.game.particle_system:draw()
    end

    -- Draw fog of war (Phase 11) - uses stencil, not canvases
    if _G.DEBUG_FOG then
        print(string.format("[BreakoutView] fog_of_war_enabled=%s, fog_controller=%s",
            tostring(self.game.fog_of_war_enabled), tostring(self.game.fog_controller ~= nil)))
    end
    if self.game.fog_of_war_enabled then
        self:drawFogOfWar()
    end

    love.graphics.pop()  -- End camera shake transform

    -- Draw HUD (Phase 10: Score prominently in yellow) - NOT affected by camera shake or fog
    love.graphics.push()

    -- Lives (white)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Lives: " .. self.game.lives, 10, 10)

    -- Score (prominent yellow)
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("Score: " .. math.floor(self.game.score), 10, 30)

    -- Combo (white)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Combo: " .. self.game.combo, 10, 50)

    -- Active power-ups (Phase 13)
    local y_offset = 70
    if self.game.shield_active then
        love.graphics.setColor(0, 1, 1)  -- Cyan
        love.graphics.print("SHIELD ACTIVE", 10, y_offset)
        y_offset = y_offset + 20
    end
    for powerup_type, effect in pairs(self.game.active_powerups) do
        local time_left = math.ceil(effect.duration_remaining)
        love.graphics.setColor(1, 1, 0)  -- Yellow
        love.graphics.print(powerup_type:upper():gsub("_", " ") .. ": " .. time_left .. "s", 10, y_offset)
        y_offset = y_offset + 20
    end

    -- Bricks destroyed (white, top right)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Bricks: " .. self.game.bricks_destroyed, self.game.arena_width - 120, 10)

    love.graphics.pop()

    -- Victory/Game Over overlay
    if self.game.victory then
        love.graphics.push()
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, self.game.arena_width, self.game.arena_height)

        love.graphics.setColor(0.3, 1, 0.3)
        local text = "VICTORY!"
        local font = love.graphics.getFont()
        local text_width = font:getWidth(text)
        love.graphics.print(text, (self.game.arena_width - text_width) / 2, self.game.arena_height / 2 - 40)

        love.graphics.setColor(1, 1, 1)
        local score_text = "Final Score: " .. math.floor(self.game.score)
        local score_width = font:getWidth(score_text)
        love.graphics.print(score_text, (self.game.arena_width - score_width) / 2, self.game.arena_height / 2)
        love.graphics.pop()
    elseif self.game.game_over then
        love.graphics.push()
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, self.game.arena_width, self.game.arena_height)

        love.graphics.setColor(1, 0.3, 0.3)
        local text = "GAME OVER"
        local font = love.graphics.getFont()
        local text_width = font:getWidth(text)
        love.graphics.print(text, (self.game.arena_width - text_width) / 2, self.game.arena_height / 2 - 40)

        love.graphics.setColor(1, 1, 1)
        local score_text = "Final Score: " .. math.floor(self.game.score)
        local score_width = font:getWidth(score_text)
        love.graphics.print(score_text, (self.game.arena_width - score_width) / 2, self.game.arena_height / 2)
        love.graphics.pop()
    end
end

function BreakoutView:drawFogOfWar()
    -- Use FogOfWar component (stencil mode)
    local fog = self.game.fog_controller
    if _G.DEBUG_FOG then
        print(string.format("[BreakoutView] drawFogOfWar() called, fog_controller=%s", tostring(fog ~= nil)))
        if fog then
            print(string.format("[BreakoutView] fog.enabled=%s, fog.mode=%s", tostring(fog.enabled), tostring(fog.mode)))
        end
    end

    if not fog then return end

    fog:clearSources()

    -- Add visibility around each ball
    for _, ball in ipairs(self.game.balls) do
        if ball.active then
            fog:addVisibilitySource(ball.x, ball.y, self.game.fog_of_war_radius)
        end
    end

    -- Add visibility around paddle
    fog:addVisibilitySource(self.game.paddle.x, self.game.paddle.y, self.game.fog_of_war_radius)

    if _G.DEBUG_FOG then
        print(string.format("[BreakoutView] About to call fog:render() with %d sources", #fog.visibility_sources))
    end

    -- Render fog
    fog:render(self.game.arena_width, self.game.arena_height)
end

return BreakoutView
