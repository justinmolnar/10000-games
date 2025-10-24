local Object = require('class')
local Config = rawget(_G, 'DI_CONFIG') or {}
local SpaceShooterView = Object:extend('SpaceShooterView')

function SpaceShooterView:init(game_state, variant)
    self.game = game_state
    self.variant = variant -- Store variant data for future use (Phase 1.3)
    -- NOTE: In Phase 2, ship sprites will be loaded from variant.sprite_set
    -- Background will use variant.background (e.g., "stars_blue", "stars_red", "stars_purple")
    self.sprite_loader = nil
    self.sprite_manager = nil
    -- capture DI if passed via game_state
    self.di = game_state and game_state.di
end

function SpaceShooterView:ensureLoaded()
    if not self.sprite_loader then
        self.sprite_loader = (self.di and self.di.spriteLoader) or error("SpaceShooterView: spriteLoader not available in DI")
    end

    if not self.sprite_manager then
        self.sprite_manager = (self.di and self.di.spriteManager) or error("SpaceShooterView: spriteManager not available in DI")
    end
end

function SpaceShooterView:draw()
    self:ensureLoaded()

    local game = self.game
    local g = love.graphics

    local game_width = game.game_width
    local game_height = game.game_height

    local viewcfg = ((self.di and self.di.config and self.di.config.games and self.di.config.games.space_shooter and self.di.config.games.space_shooter.view) or
                     (Config and Config.games and Config.games.space_shooter and Config.games.space_shooter.view) or {})
    local bg = viewcfg.bg_color or {0.05, 0.05, 0.15}
    local hud = viewcfg.hud or { icon_size = 16, text_scale = 0.85, label_x = 10, icon_x = 60, text_x = 80, row_y = {10, 30, 50} }
    g.setColor(bg[1], bg[2], bg[3])
    g.rectangle('fill', 0, 0, game_width, game_height)

    -- Phase 1.6: Use variant palette if available
    local palette_id = (self.variant and self.variant.palette) or self.sprite_manager:getPaletteId(game.data)
    local player_sprite = game.data.icon_sprite or "game_mine_1-0"
    
    if game.player then
        self.sprite_loader:drawSprite(
            player_sprite,
            game.player.x - game.player.width/2,
            game.player.y - game.player.height/2,
            game.player.width,
            game.player.height,
            {1, 1, 1},
            palette_id
        )
    end

    local enemy_sprite = self.sprite_manager:getMetricSprite(game.data, "kills") or "game_mine_2-0"
    for _, enemy in ipairs(game.enemies) do
        self.sprite_loader:drawSprite(
            enemy_sprite,
            enemy.x - enemy.width/2,
            enemy.y - enemy.height/2,
            enemy.width,
            enemy.height,
            {1, 1, 1},
            palette_id
        )
    end

    local bullet_sprite = "msg_information-0"
    for _, bullet in ipairs(game.player_bullets) do
        self.sprite_loader:drawSprite(
            bullet_sprite,
            bullet.x - bullet.width/2,
            bullet.y - bullet.height/2,
            bullet.width,
            bullet.height,
            {1, 1, 1},
            palette_id
        )
    end

    local enemy_bullet_sprite = "msg_error-0"
    for _, bullet in ipairs(game.enemy_bullets) do
        self.sprite_loader:drawSprite(
            enemy_bullet_sprite,
            bullet.x - bullet.width/2,
            bullet.y - bullet.height/2,
            bullet.width,
            bullet.height,
            {1, 1, 1},
            palette_id
        )
    end

    local hud_icon_size = hud.icon_size or 16
    local s = hud.text_scale or 0.85
    local lx, ix, tx = hud.label_x or 10, hud.icon_x or 60, hud.text_x or 80
    local ry = hud.row_y or {10, 30, 50}
    g.setColor(1, 1, 1)
    g.print("Kills: ", lx, ry[1], 0, s, s)
    self.sprite_loader:drawSprite(enemy_sprite, ix, ry[1], hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.kills .. "/" .. game.target_kills, tx, ry[1], 0, s, s)
    
    local death_sprite = self.sprite_manager:getMetricSprite(game.data, "deaths") or "msg_error-0"
    g.print("Deaths: ", lx, ry[2], 0, s, s)
    self.sprite_loader:drawSprite(death_sprite, ix, ry[2], hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.deaths .. "/" .. game.PLAYER_MAX_DEATHS, tx, ry[2], 0, s, s)
    
    g.print("Difficulty: " .. game.difficulty_level, lx, ry[3])
end

return SpaceShooterView