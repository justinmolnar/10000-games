local GameBaseView = require('src.games.views.game_base_view')
local BreakoutView = GameBaseView:extend('BreakoutView')

function BreakoutView:init(game)
    BreakoutView.super.init(self, game, nil)
end

function BreakoutView:drawContent()
    love.graphics.push()

    -- Apply camera shake
    self.game.visual_effects:applyCameraShake()

    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle('fill', 0, 0, self.game.arena_width, self.game.arena_height)

    -- Draw bricks
    for _, brick in ipairs(self.game.bricks) do
        if brick.alive then
            local health_percent = brick.health / brick.max_health
            local is_flashing = self.game:isFlashing(brick)
            local color = is_flashing and {1, 1, 1} or self:getHealthColor(health_percent)

            if brick.display_image then
                -- PNG brick with health tinting
                if health_percent <= 0.33 then
                    love.graphics.setColor(1, 0.5, 0.5)
                elseif health_percent <= 0.66 then
                    love.graphics.setColor(1, 1, 0.5)
                else
                    love.graphics.setColor(1, 1, 1)
                end
                love.graphics.draw(brick.display_image, brick.x, brick.y)
            elseif brick.shape == "circle" then
                local cx = brick.x + (brick.radius or brick.width / 2)
                local cy = brick.y + (brick.radius or brick.height / 2)
                love.graphics.setColor(color)
                love.graphics.circle('fill', cx, cy, brick.radius or brick.width / 2)
                love.graphics.setColor(0.2, 0.2, 0.2)
                love.graphics.circle('line', cx, cy, brick.radius or brick.width / 2)
            else
                love.graphics.setColor(color)
                love.graphics.rectangle('fill', brick.x, brick.y, brick.width, brick.height)
                love.graphics.setColor(0.2, 0.2, 0.2)
                love.graphics.rectangle('line', brick.x, brick.y, brick.width, brick.height)
            end
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
            self:drawTrail(ball.trail, ball.radius, {1, 1, 1})
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle('fill', ball.x, ball.y, ball.radius)
        end
    end

    -- Draw paddle bullets
    for _, bullet in ipairs(self.game.projectile_system:getByTeam("paddle_bullet")) do
        love.graphics.push()
        love.graphics.setColor(1, 1, 0.3)
        love.graphics.rectangle('fill',
            bullet.x - bullet.width / 2,
            bullet.y - bullet.height / 2,
            bullet.width,
            bullet.height)
        love.graphics.pop()
    end

    -- Draw obstacles
    for _, obstacle in ipairs(self.game.obstacles) do
        if obstacle.alive then
            local color = self.game.obstacles_destructible
                and self:getHealthColor(obstacle.health / obstacle.max_health)
                or {0.6, 0.6, 0.6}

            love.graphics.setColor(color)
            if obstacle.shape == "circle" then
                love.graphics.circle('fill', obstacle.x + obstacle.size / 2, obstacle.y + obstacle.size / 2, obstacle.size / 2)
                love.graphics.setColor(0.2, 0.2, 0.2)
                love.graphics.circle('line', obstacle.x + obstacle.size / 2, obstacle.y + obstacle.size / 2, obstacle.size / 2)
            else
                love.graphics.rectangle('fill', obstacle.x, obstacle.y, obstacle.size, obstacle.size)
                love.graphics.setColor(0.2, 0.2, 0.2)
                love.graphics.rectangle('line', obstacle.x, obstacle.y, obstacle.size, obstacle.size)
            end
        end
    end

    -- Draw power-ups
    for _, powerup in ipairs(self.game.powerups) do
        love.graphics.setColor(powerup.color or {1, 1, 1})
        love.graphics.rectangle('fill', powerup.x, powerup.y, powerup.width, powerup.height)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle('line', powerup.x, powerup.y, powerup.width, powerup.height)
    end

    -- Draw score popups
    self.game.popup_manager:draw()

    -- Draw particles
    self.game.visual_effects:drawParticles()

    -- Draw fog of war
    if self.game.params.fog_of_war_enabled then
        local sources = {self.game.paddle}
        for _, ball in ipairs(self.game.balls) do
            if ball.active then table.insert(sources, ball) end
        end
        self:renderFog(self.game.arena_width, self.game.arena_height, sources, self.game.params.fog_of_war_radius)
    end

    love.graphics.pop()  -- End camera shake transform

    -- Standard HUD - NOT affected by camera shake or fog
    self.game.hud:draw(self.game.arena_width, self.game.arena_height)

    -- Extra stats
    local y = 90
    if self.game.combo > 0 then
        y = self.game.hud:drawStat("Combo", self.game.combo, y, {0.2, 1, 0.2})
    end
    if self.game.shield_active then
        y = self.game.hud:drawStat("SHIELD ACTIVE", "", y, {0, 1, 1})
    end

    -- Active power-ups
    for powerup_type, effect in pairs(self.game.active_powerups) do
        local time_left = math.ceil(effect.duration_remaining)
        y = self.game.hud:drawStat(powerup_type:upper():gsub("_", " "), time_left .. "s", y, {1, 1, 0})
    end
end

return BreakoutView
