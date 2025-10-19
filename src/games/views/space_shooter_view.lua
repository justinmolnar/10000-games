local Object = require('class')
local SpaceShooterView = Object:extend('SpaceShooterView')

function SpaceShooterView:init(game_state)
    self.game = game_state
    self.sprite_loader = nil
    self.sprite_manager = nil
end

function SpaceShooterView:ensureLoaded()
    if not self.sprite_loader then
        local SpriteLoader = require('src.utils.sprite_loader')
        self.sprite_loader = SpriteLoader.getInstance()
    end
    
    if not self.sprite_manager then
        local SpriteManager = require('src.utils.sprite_manager')
        self.sprite_manager = SpriteManager.getInstance()
    end
end

function SpaceShooterView:draw()
    self:ensureLoaded()
    
    local game = self.game
    local g = love.graphics

    local game_width = game.game_width
    local game_height = game.game_height

    g.setColor(0.05, 0.05, 0.15)
    g.rectangle('fill', 0, 0, game_width, game_height)

    local palette_id = self.sprite_manager:getPaletteId(game.data)
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

    local hud_icon_size = 16
    g.setColor(1, 1, 1)
    g.print("Kills: ", 10, 10, 0, 0.85, 0.85)
    self.sprite_loader:drawSprite(enemy_sprite, 60, 10, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.kills .. "/" .. game.target_kills, 80, 10, 0, 0.85, 0.85)
    
    local death_sprite = self.sprite_manager:getMetricSprite(game.data, "deaths") or "msg_error-0"
    g.print("Deaths: ", 10, 30, 0, 0.85, 0.85)
    self.sprite_loader:drawSprite(death_sprite, 60, 30, hud_icon_size, hud_icon_size, {1, 1, 1}, palette_id)
    g.print(game.metrics.deaths .. "/" .. game.PLAYER_MAX_DEATHS, 80, 30, 0, 0.85, 0.85)
    
    g.print("Difficulty: " .. game.difficulty_level, 10, 50)
end

return SpaceShooterView