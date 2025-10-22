local Object = require('class')
local SpaceDefenderView = Object:extend('SpaceDefenderView')

function SpaceDefenderView:init(controller)
    self.controller = controller
    local di = controller and controller.di
    self.sprite_manager = (di and di.spriteManager) or nil
    local cfg_root = (di and di.config and di.config.games and di.config.games.space_defender) or {}
    self._cfg = (cfg_root and cfg_root.view) or {}
    self.stars = {}
    local star_count = (self._cfg.starfield and self._cfg.starfield.count) or 200
    local base_size = (self._cfg.starfield and self._cfg.starfield.base_size) or { w = 1024, h = 768 }
    local smin = (self._cfg.starfield and self._cfg.starfield.speed_min) or 20
    local smax = (self._cfg.starfield and self._cfg.starfield.speed_max) or 100
    for i = 1, star_count do
        table.insert(self.stars, {
            x = math.random(0, base_size.w),
            y = math.random(0, base_size.h),
            speed = math.random(smin, smax)
        })
    end
end

function SpaceDefenderView:update(dt)
    local base_size = (self._cfg.starfield and self._cfg.starfield.base_size) or { w = 1024, h = 768 }
    for _, star in ipairs(self.stars) do
        star.y = star.y + star.speed * dt
        if star.y > base_size.h then
            star.y = 0
            star.x = math.random(0, base_size.w)
        end
    end
end

function SpaceDefenderView:draw(args)
    -- Draw background elements (stars, etc.)
    self:drawBackground(args.width, args.height)

    -- Draw game entities
    if args.bullet_system then self:drawBullets(args.bullet_system, args.game_data) end
    self:drawEnemies(args.enemies)
    if args.boss_active and args.boss then self:drawBoss(args.boss) end
    if args.player then self:drawPlayer(args.player) end

    -- Draw HUD
    self:drawHUD(args)

    -- Draw overlays
    if args.level_complete then
        self:drawLevelComplete(args.tokens_earned, args.width, args.height)
    elseif args.game_over then
        self:drawGameOver(args.width, args.height)
    elseif args.paused then
        self:drawPaused(args.width, args.height)
    end
end

function SpaceDefenderView:drawBackground(width, height)
    love.graphics.setColor(1, 1, 1)
    local base_size = (self._cfg.starfield and self._cfg.starfield.base_size) or { w = 1024, h = 768 }
    for _, star in ipairs(self.stars) do
        local scaled_x = star.x / base_size.w * width
        local scaled_y = star.y / base_size.h * height
        local size = star.speed / 50
        love.graphics.rectangle('fill', scaled_x, scaled_y, size, size)
    end
end

function SpaceDefenderView:drawPlayer(player)
    if not player then return end
    local sprite_manager = self.sprite_manager or (self.di and self.di.spriteManager)
    sprite_manager:ensureLoaded()
    sprite_manager.sprite_loader:drawSprite("joystick_alt-0", player.x - player.width/2, player.y - player.height/2, player.width, player.height)
end

function SpaceDefenderView:drawEnemies(enemies)
    if not enemies then return end
    local sprite_manager = self.sprite_manager or (self.di and self.di.spriteManager)
    sprite_manager:ensureLoaded()

    for _, enemy in ipairs(enemies) do
        local sprite_name = "computer_explorer-0" -- Default
        if enemy.pattern == "zigzag" then
            sprite_name = "computer_explorer-1"
        elseif enemy.pattern == "sine" then
            sprite_name = "computer_explorer-2"
        end

        if enemy.damaged then
            love.graphics.setColor(1, 1, 1, 0.5) -- Tint white and slightly transparent
            enemy.damaged = false
        else
            love.graphics.setColor(1, 1, 1)
        end
        sprite_manager.sprite_loader:drawSprite(sprite_name, enemy.x - enemy.width/2, enemy.y - enemy.height/2, enemy.width, enemy.height)
    end
end

function SpaceDefenderView:drawBullets(bullet_system, game_data)
    if not bullet_system then return end
    local bullets = bullet_system.getActiveBullets and bullet_system:getActiveBullets() or {}
    local sprite_manager = self.sprite_manager or (self.di and self.di.spriteManager)
    sprite_manager:ensureLoaded()

    for _, bullet in ipairs(bullets) do
        if bullet.sprite and bullet.sprite ~= "bullet_basic" then
            local game = game_data and game_data.getGame and game_data:getGame(bullet.id)
            local palette_id = "default"
            if game then palette_id = sprite_manager:getPaletteId(game) end
            local cfg = (self._cfg and self._cfg.bullets) or {}
            local s = (cfg.sprite_scale) or (((self._cfg and self._cfg.systems and self._cfg.systems.bullets) and self._cfg.systems.bullets.sprite_scale) or 2.0)
            sprite_manager.sprite_loader:drawSprite(
                bullet.sprite,
                bullet.x - bullet.width/2,
                bullet.y - bullet.height/2,
                bullet.width * s,
                bullet.height * s,
                nil,
                palette_id
            )
        else
            love.graphics.setColor(bullet.color or {1,1,1})
            love.graphics.rectangle('fill', bullet.x - bullet.width/2, bullet.y - bullet.height/2, bullet.width, bullet.height)
        end
    end
end

function SpaceDefenderView:drawBoss(boss)
    if not boss then return end
    local sprite_manager = self.sprite_manager or (self.di and self.di.spriteManager)
    sprite_manager:ensureLoaded()

    -- Resolve a valid boss sprite once and cache it
    if not self._boss_sprite_name then
        local candidates = {
            "taskman-0", -- preferred if present
            "computer_explorer-5", -- bold variant
            "world_star-0",
            "windows_update_large-0",
            "windows_movie-0"
        }
        for _, name in ipairs(candidates) do
            if sprite_manager.sprite_loader:hasSprite(name) then
                self._boss_sprite_name = name
                break
            end
        end
        self._boss_sprite_name = self._boss_sprite_name or candidates[#candidates]
    end

    love.graphics.setColor(1, 1, 1)
    sprite_manager.sprite_loader:drawSprite(self._boss_sprite_name, boss.x - boss.width/2, boss.y - boss.height/2, boss.width, boss.height)
    
    -- Health bar
    local bb = (self._cfg.boss_bar) or { width = 200, height = 15, offset_y = 20 }
    local bar_w = bb.width
    local bar_h = bb.height
    local bar_x = boss.x - bar_w/2
    local bar_y = boss.y - boss.height/2 - (bb.offset_y or 20)
    love.graphics.setColor(0.3, 0, 0)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_w, bar_h)
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle('fill', bar_x, bar_y, bar_w * (boss.hp / boss.max_hp), bar_h)
end

function SpaceDefenderView:drawHUD(args)
    local player = args.player
    local width = args.width
    if not player or not width then return end

    love.graphics.setColor(1, 1, 1)
    local hud = self._cfg.hud or { left_x = 10, right_margin_offset = 150, row_y = {10, 30} }
    love.graphics.print("HP: " .. player.hp, hud.left_x or 10, (hud.row_y and hud.row_y[1]) or 10)
    love.graphics.print("Bombs: " .. player.bombs, hud.left_x or 10, (hud.row_y and hud.row_y[2]) or 30)
    love.graphics.print("Wave: " .. args.current_wave .. "/" .. args.total_waves, width - ((hud.right_margin_offset or 150)), (hud.row_y and hud.row_y[1]) or 10)
    love.graphics.print("Level: " .. args.current_level, width - ((hud.right_margin_offset or 150)), (hud.row_y and hud.row_y[2]) or 30)
end

function SpaceDefenderView:drawLevelComplete(tokens_earned, viewport_width, viewport_height)
    local ov = self._cfg.overlays or { complete_alpha = 0.7 }
    love.graphics.setColor(0, 0, 0, ov.complete_alpha or 0.7)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("LEVEL COMPLETE", 0, viewport_height/2 - 50, viewport_width, "center")
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Earned " .. tokens_earned .. " tokens", 0, viewport_height/2 - 20, viewport_width, "center")
    love.graphics.printf("Press ENTER for next level or ESC to exit", 0, viewport_height/2 + 20, viewport_width, "center")
end

function SpaceDefenderView:drawGameOver(viewport_width, viewport_height)
    local ov = self._cfg.overlays or { game_over_alpha = 0.7 }
    love.graphics.setColor(0, 0, 0, ov.game_over_alpha or 0.7)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)
    love.graphics.setColor(1, 0, 0)
    love.graphics.printf("GAME OVER", 0, viewport_height/2 - 20, viewport_width, "center")
    love.graphics.printf("Press ENTER or ESC to exit", 0, viewport_height/2 + 10, viewport_width, "center")
end

function SpaceDefenderView:drawPaused(viewport_width, viewport_height)
    local ov = self._cfg.overlays or { paused_alpha = 0.5 }
    love.graphics.setColor(0, 0, 0, ov.paused_alpha or 0.5)
    love.graphics.rectangle('fill', 0, 0, viewport_width, viewport_height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("PAUSED", 0, viewport_height/2 - 10, viewport_width, "center")
end

return SpaceDefenderView