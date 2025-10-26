local BaseGame = require('src.games.base_game')
local Config = rawget(_G, 'DI_CONFIG') or {}
local Collision = require('src.utils.collision') 
local SpaceShooterView = require('src.games.views.space_shooter_view')
local SpaceShooter = BaseGame:extend('SpaceShooter')

-- Enemy type definitions (Phase 1.4)
-- These define the behaviors that variants can compose from
SpaceShooter.ENEMY_TYPES = {
    basic = {
        name = "basic",
        movement_pattern = "straight",
        speed_multiplier = 1.0,
        shoot_rate_multiplier = 1.0,
        health = 1,
        description = "Standard enemy ship"
    },
    weaver = {
        name = "weaver",
        movement_pattern = "zigzag",
        speed_multiplier = 0.8,
        shoot_rate_multiplier = 1.2,
        health = 1,
        description = "Weaves through space while shooting"
    },
    bomber = {
        name = "bomber",
        movement_pattern = "straight",
        speed_multiplier = 0.6,
        shoot_rate_multiplier = 2.0,
        health = 2,
        description = "Slow but fires rapidly"
    },
    kamikaze = {
        name = "kamikaze",
        movement_pattern = "dive",
        speed_multiplier = 1.5,
        shoot_rate_multiplier = 0.0,
        health = 1,
        description = "Dives directly at player without shooting"
    }
}

-- Config-driven defaults with safe fallbacks
local SCfg = (Config and Config.games and Config.games.space_shooter) or {}
local PLAYER_WIDTH = (SCfg.player and SCfg.player.width) or 30
local PLAYER_HEIGHT = (SCfg.player and SCfg.player.height) or 30
local PLAYER_SPEED = (SCfg.player and SCfg.player.speed) or 200
local PLAYER_START_Y_OFFSET = (SCfg.player and SCfg.player.start_y_offset) or 50
local PLAYER_MAX_DEATHS_BASE = (SCfg.player and SCfg.player.max_deaths_base) or 5

local BULLET_WIDTH = (SCfg.bullet and SCfg.bullet.width) or 4
local BULLET_HEIGHT = (SCfg.bullet and SCfg.bullet.height) or 8
local BULLET_SPEED = (SCfg.bullet and SCfg.bullet.speed) or 400
local FIRE_COOLDOWN = (SCfg.player and SCfg.player.fire_cooldown) or 0.2

local ENEMY_WIDTH = (SCfg.enemy and SCfg.enemy.width) or 30
local ENEMY_HEIGHT = (SCfg.enemy and SCfg.enemy.height) or 30
local ENEMY_BASE_SPEED = (SCfg.enemy and SCfg.enemy.base_speed) or 100
local ENEMY_START_Y_OFFSET = (SCfg.enemy and SCfg.enemy.start_y_offset) or -30
local ENEMY_BASE_SHOOT_RATE_MIN = (SCfg.enemy and SCfg.enemy.base_shoot_rate_min) or 1.0
local ENEMY_BASE_SHOOT_RATE_MAX = (SCfg.enemy and SCfg.enemy.base_shoot_rate_max) or 3.0
local ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR = (SCfg.enemy and SCfg.enemy.shoot_rate_complexity_factor) or 0.5

local SPAWN_BASE_RATE = (SCfg.spawn and SCfg.spawn.base_rate) or 1.0
local BASE_TARGET_KILLS = (SCfg.goals and SCfg.goals.base_target_kills) or 20
local ZIGZAG_FREQUENCY = (SCfg.movement and SCfg.movement.zigzag_frequency) or 2

function SpaceShooter:init(game_data, cheats, di, variant_override)
    SpaceShooter.super.init(self, game_data, cheats, di, variant_override)
    self.di = di
    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.space_shooter) or SCfg

    -- Apply variant difficulty modifier (from Phase 1.1-1.2)
    local variant_difficulty = self.variant and self.variant.difficulty_modifier or 1.0

    -- Override file-scope constants with DI values when present
    PLAYER_WIDTH = (runtimeCfg.player and runtimeCfg.player.width) or PLAYER_WIDTH
    PLAYER_HEIGHT = (runtimeCfg.player and runtimeCfg.player.height) or PLAYER_HEIGHT
    PLAYER_SPEED = (runtimeCfg.player and runtimeCfg.player.speed) or PLAYER_SPEED
    PLAYER_START_Y_OFFSET = (runtimeCfg.player and runtimeCfg.player.start_y_offset) or PLAYER_START_Y_OFFSET
    PLAYER_MAX_DEATHS_BASE = (runtimeCfg.player and runtimeCfg.player.max_deaths_base) or PLAYER_MAX_DEATHS_BASE

    BULLET_WIDTH = (runtimeCfg.bullet and runtimeCfg.bullet.width) or BULLET_WIDTH
    BULLET_HEIGHT = (runtimeCfg.bullet and runtimeCfg.bullet.height) or BULLET_HEIGHT
    BULLET_SPEED = (runtimeCfg.bullet and runtimeCfg.bullet.speed) or BULLET_SPEED
    FIRE_COOLDOWN = (runtimeCfg.player and runtimeCfg.player.fire_cooldown) or FIRE_COOLDOWN

    ENEMY_WIDTH = (runtimeCfg.enemy and runtimeCfg.enemy.width) or ENEMY_WIDTH
    ENEMY_HEIGHT = (runtimeCfg.enemy and runtimeCfg.enemy.height) or ENEMY_HEIGHT
    ENEMY_BASE_SPEED = (runtimeCfg.enemy and runtimeCfg.enemy.base_speed) or ENEMY_BASE_SPEED
    ENEMY_START_Y_OFFSET = (runtimeCfg.enemy and runtimeCfg.enemy.start_y_offset) or ENEMY_START_Y_OFFSET
    ENEMY_BASE_SHOOT_RATE_MIN = (runtimeCfg.enemy and runtimeCfg.enemy.base_shoot_rate_min) or ENEMY_BASE_SHOOT_RATE_MIN
    ENEMY_BASE_SHOOT_RATE_MAX = (runtimeCfg.enemy and runtimeCfg.enemy.base_shoot_rate_max) or ENEMY_BASE_SHOOT_RATE_MAX
    ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR = (runtimeCfg.enemy and runtimeCfg.enemy.shoot_rate_complexity_factor) or ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR

    SPAWN_BASE_RATE = (runtimeCfg.spawn and runtimeCfg.spawn.base_rate) or SPAWN_BASE_RATE
    BASE_TARGET_KILLS = (runtimeCfg.goals and runtimeCfg.goals.base_target_kills) or BASE_TARGET_KILLS
    ZIGZAG_FREQUENCY = (runtimeCfg.movement and runtimeCfg.movement.zigzag_frequency) or ZIGZAG_FREQUENCY
    
    local speed_modifier = self.cheats.speed_modifier or 1.0 
    local advantage_modifier = self.cheats.advantage_modifier or {}
    local extra_deaths = advantage_modifier.deaths or 0
    
    self.PLAYER_MAX_DEATHS = PLAYER_MAX_DEATHS_BASE + extra_deaths 

    self.game_width = (SCfg.arena and SCfg.arena.width) or 800
    self.game_height = (SCfg.arena and SCfg.arena.height) or 600

    self.player = {
        x = self.game_width / 2,
        y = self.game_height - PLAYER_START_Y_OFFSET,
        width = PLAYER_WIDTH,
        height = PLAYER_HEIGHT,
        fire_cooldown = 0
    }

    self.enemies = {}
    self.player_bullets = {}
    self.enemy_bullets = {}

    self.metrics.kills = 0
    self.metrics.deaths = 0

    self.enemy_speed = ((ENEMY_BASE_SPEED * self.difficulty_modifiers.speed) * speed_modifier) * variant_difficulty
    self.spawn_rate = (SPAWN_BASE_RATE / self.difficulty_modifiers.count) / variant_difficulty
    self.spawn_timer = 0
    self.can_shoot_back = self.difficulty_modifiers.complexity > 2

    self.target_kills = math.floor(BASE_TARGET_KILLS * self.difficulty_modifiers.complexity * variant_difficulty)

    -- Enemy composition from variant (Phase 1.3)
    -- NOTE: Enemy spawning will be implemented when assets are ready (Phase 2+)
    self.enemy_composition = {}
    if self.variant and self.variant.enemies then
        for _, enemy_def in ipairs(self.variant.enemies) do
            self.enemy_composition[enemy_def.type] = enemy_def.multiplier
        end
    end

    -- Audio/visual variant data (Phase 1.3)
    -- NOTE: Asset loading will be implemented in Phase 2-3
    -- Ship sprites will be loaded from variant.sprite_set
    -- e.g., "fighter_1" (blue squadron), "fighter_2" (gold squadron)

    self.view = SpaceShooterView:new(self, self.variant)
    print("[SpaceShooter:init] Initialized with default game dimensions:", self.game_width, self.game_height)
    print("[SpaceShooter:init] Variant:", self.variant and self.variant.name or "Default")

    -- Phase 2.3: Load sprite assets with graceful fallback
    self:loadAssets()
end

-- Phase 2.3: Asset loading with fallback
function SpaceShooter:loadAssets()
    self.sprites = {}

    if not self.variant or not self.variant.sprite_set then
        print("[SpaceShooter:loadAssets] No variant sprite_set, using fallback rendering")
        return
    end

    local game_type = "space_shooter"
    local base_path = "assets/sprites/games/" .. game_type .. "/" .. self.variant.sprite_set .. "/"

    local function tryLoad(filename, sprite_key)
        local filepath = base_path .. filename
        local success, result = pcall(function()
            return love.graphics.newImage(filepath)
        end)

        if success then
            self.sprites[sprite_key] = result
            print("[SpaceShooter:loadAssets] Loaded: " .. filepath)
        else
            print("[SpaceShooter:loadAssets] Missing: " .. filepath .. " (using fallback)")
        end
    end

    -- Load player ship sprite
    tryLoad("player.png", "player")

    -- Load enemy type sprites
    for enemy_type, _ in pairs(SpaceShooter.ENEMY_TYPES) do
        local filename = "enemy_" .. enemy_type .. ".png"
        local sprite_key = "enemy_" .. enemy_type
        tryLoad(filename, sprite_key)
    end

    -- Load bullet sprites
    tryLoad("bullet_player.png", "bullet_player")
    tryLoad("bullet_enemy.png", "bullet_enemy")

    -- Load power-up sprite
    tryLoad("power_up.png", "power_up")

    -- Load background
    tryLoad("background.png", "background")

    print(string.format("[SpaceShooter:loadAssets] Loaded %d sprites for variant: %s",
        self:countLoadedSprites(), self.variant.name or "Unknown"))

    -- Phase 3.3: Load audio - using BaseGame helper
    self:loadAudio()
end

function SpaceShooter:countLoadedSprites()
    local count = 0
    for _ in pairs(self.sprites) do
        count = count + 1
    end
    return count
end

function SpaceShooter:hasSprite(sprite_key)
    return self.sprites and self.sprites[sprite_key] ~= nil
end

function SpaceShooter:setPlayArea(width, height)
    self.game_width = width
    self.game_height = height
    
    -- Only update player position if player exists
    if self.player then
        self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
        self.player.y = self.game_height - PLAYER_START_Y_OFFSET
        print("[SpaceShooter] Play area updated to:", width, height)
    else
        print("[SpaceShooter] setPlayArea called before init completed")
    end
end

function SpaceShooter:updateGameLogic(dt)
    self:updatePlayer(dt)
    self.spawn_timer = self.spawn_timer - dt
    if self.spawn_timer <= 0 then
        self:spawnEnemy()
        self.spawn_timer = self.spawn_rate
    end
    self:updateEnemies(dt)
    self:updateBullets(dt)
end

function SpaceShooter:updatePlayer(dt)
    if love.keyboard.isDown('left', 'a') then self.player.x = self.player.x - PLAYER_SPEED * dt end
    if love.keyboard.isDown('right', 'd') then self.player.x = self.player.x + PLAYER_SPEED * dt end
    self.player.x = math.max(0, math.min(self.game_width - self.player.width, self.player.x))
    if self.player.fire_cooldown > 0 then self.player.fire_cooldown = self.player.fire_cooldown - dt end
    if love.keyboard.isDown('space') and self.player.fire_cooldown <= 0 then self:playerShoot() end
end

function SpaceShooter:updateEnemies(dt)
     for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        if not enemy then goto continue_enemy_loop end

        -- Phase 1.4: Apply speed multiplier for variant enemies
        local speed = self.enemy_speed
        if enemy.is_variant_enemy and enemy.speed_multiplier then
            speed = speed * enemy.speed_multiplier
        end

        if enemy.movement_pattern == 'zigzag' then
            enemy.y = enemy.y + speed * dt
            enemy.x = enemy.x + math.sin(self.time_elapsed * ZIGZAG_FREQUENCY) * speed * dt
        elseif enemy.movement_pattern == 'dive' then
            -- Phase 1.4: Kamikaze dive toward target
            local dx = enemy.target_x - enemy.x
            local dy = enemy.target_y - enemy.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist > 0 then
                enemy.x = enemy.x + (dx / dist) * speed * dt
                enemy.y = enemy.y + (dy / dist) * speed * dt
            else
                -- Reached target, continue downward
                enemy.y = enemy.y + speed * dt
            end
        else
            enemy.y = enemy.y + speed * dt
        end

        if self.can_shoot_back then
            -- Phase 1.4: Don't shoot if shoot_rate_multiplier is 0 (kamikaze)
            local shoot_multiplier = enemy.shoot_rate_multiplier or 1.0
            if shoot_multiplier > 0 then
                enemy.shoot_timer = enemy.shoot_timer - dt
                if enemy.shoot_timer <= 0 then
                    self:enemyShoot(enemy)
                    enemy.shoot_timer = enemy.shoot_rate
                end
            end
        end

        if enemy.y > self.game_height + 20 then
            table.remove(self.enemies, i)
        end
        ::continue_enemy_loop::
    end
end

function SpaceShooter:updateBullets(dt)
    for i = #self.player_bullets, 1, -1 do
        local bullet = self.player_bullets[i]
        if not bullet then goto next_player_bullet end
        bullet.y = bullet.y - BULLET_SPEED * dt

        for j = #self.enemies, 1, -1 do
            local enemy = self.enemies[j]
            if enemy and self:checkCollision(bullet, enemy) then
                table.remove(self.player_bullets, i)
                -- Phase 1.4: Handle health for variant enemies
                if enemy.is_variant_enemy and enemy.health then
                    enemy.health = enemy.health - 1
                    if enemy.health <= 0 then
                        table.remove(self.enemies, j)
                        self.metrics.kills = self.metrics.kills + 1

                        -- Phase 3.3: Play enemy explode sound
                        self:playSound("enemy_explode", 1.0)
                    end
                else
                    table.remove(self.enemies, j)
                    self.metrics.kills = self.metrics.kills + 1

                    -- Phase 3.3: Play enemy explode sound
                    self:playSound("enemy_explode", 1.0)
                end
                goto next_player_bullet
            end
        end

        if bullet.y < -BULLET_HEIGHT then table.remove(self.player_bullets, i) end
        ::next_player_bullet::
    end

    for i = #self.enemy_bullets, 1, -1 do
        local bullet = self.enemy_bullets[i]
        if not bullet then goto next_enemy_bullet end
        bullet.y = bullet.y + BULLET_SPEED * dt

        if self:checkCollision(bullet, self.player) then
            table.remove(self.enemy_bullets, i)
            self.metrics.deaths = self.metrics.deaths + 1

            -- Phase 3.3: Play hit sound
            self:playSound("hit", 1.0)
            -- Let checkComplete handle game over
        end

        if bullet.y > self.game_height + BULLET_HEIGHT then table.remove(self.enemy_bullets, i) end
        ::next_enemy_bullet::
    end
end

function SpaceShooter:draw()
    if self.view then
        self.view:draw()
    else
         love.graphics.print("Error: View not loaded!", 10, 100)
    end
end

function SpaceShooter:playerShoot()
    table.insert(self.player_bullets, {
        x = self.player.x + self.player.width/2 - BULLET_WIDTH/2,
        y = self.player.y,
        width = BULLET_WIDTH, height = BULLET_HEIGHT
    })
    self.player.fire_cooldown = FIRE_COOLDOWN

    -- Phase 3.3: Play shoot sound
    self:playSound("shoot", 0.6)
end

function SpaceShooter:enemyShoot(enemy)
    table.insert(self.enemy_bullets, {
        x = enemy.x + enemy.width/2 - BULLET_WIDTH/2,
        y = enemy.y + enemy.height,
        width = BULLET_WIDTH, height = BULLET_HEIGHT
    })
end

function SpaceShooter:spawnEnemy()
    -- Phase 1.4: Check if variant has enemy composition
    if self:hasVariantEnemies() and math.random() < 0.5 then
        -- 50% chance to spawn variant-specific enemy
        return self:spawnVariantEnemy()
    end

    -- Default enemy spawning (for base game)
    local movement = 'straight'
    if self.difficulty_modifiers.complexity >= 2 then
        movement = math.random() > 0.5 and 'zigzag' or 'straight'
    end
    local enemy = {
        x = math.random(0, self.game_width - ENEMY_WIDTH),
        y = ENEMY_START_Y_OFFSET,
        width = ENEMY_WIDTH, height = ENEMY_HEIGHT,
        movement_pattern = movement,
        shoot_timer = math.random() * (ENEMY_BASE_SHOOT_RATE_MAX - ENEMY_BASE_SHOOT_RATE_MIN) + ENEMY_BASE_SHOOT_RATE_MIN,
        shoot_rate = math.max(0.5, (ENEMY_BASE_SHOOT_RATE_MAX - self.difficulty_modifiers.complexity * ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR)),
        health = 1
    }
    table.insert(self.enemies, enemy)
end

-- Phase 1.4: Check if variant has enemies defined
function SpaceShooter:hasVariantEnemies()
    return self.enemy_composition and next(self.enemy_composition) ~= nil
end

-- Phase 1.4: Spawn an enemy from variant composition
function SpaceShooter:spawnVariantEnemy()
    if not self:hasVariantEnemies() then
        return self:spawnEnemy()
    end

    -- Pick a random enemy type from composition
    local enemy_types = {}
    local total_weight = 0
    for enemy_type, multiplier in pairs(self.enemy_composition) do
        table.insert(enemy_types, {type = enemy_type, weight = multiplier})
        total_weight = total_weight + multiplier
    end

    local r = math.random() * total_weight
    local chosen_type = enemy_types[1].type -- fallback
    for _, entry in ipairs(enemy_types) do
        r = r - entry.weight
        if r <= 0 then
            chosen_type = entry.type
            break
        end
    end

    local enemy_def = self.ENEMY_TYPES[chosen_type]
    if not enemy_def then
        -- Fallback to default spawning
        return self:spawnEnemy()
    end

    -- Create enemy based on definition
    local enemy = {
        x = math.random(0, self.game_width - ENEMY_WIDTH),
        y = ENEMY_START_Y_OFFSET,
        width = ENEMY_WIDTH,
        height = ENEMY_HEIGHT,
        movement_pattern = enemy_def.movement_pattern,
        enemy_type = enemy_def.name,
        is_variant_enemy = true,
        health = enemy_def.health or 1,
        max_health = enemy_def.health or 1,
        speed_multiplier = enemy_def.speed_multiplier or 1.0,
        shoot_rate_multiplier = enemy_def.shoot_rate_multiplier or 1.0
    }

    -- Set shoot timer and rate
    local base_rate = math.random() * (ENEMY_BASE_SHOOT_RATE_MAX - ENEMY_BASE_SHOOT_RATE_MIN) + ENEMY_BASE_SHOOT_RATE_MIN
    enemy.shoot_timer = base_rate
    enemy.shoot_rate = (math.max(0.5, (ENEMY_BASE_SHOOT_RATE_MAX - self.difficulty_modifiers.complexity * ENEMY_SHOOT_RATE_COMPLEXITY_FACTOR))) / enemy.shoot_rate_multiplier

    -- Special initialization for dive pattern (kamikaze)
    if enemy.movement_pattern == 'dive' then
        enemy.target_x = self.player.x
        enemy.target_y = self.player.y
    end

    table.insert(self.enemies, enemy)
end

function SpaceShooter:checkCollision(a, b)
    if not a or not b then return false end
    return Collision.checkAABB(a.x, a.y, a.width or 0, a.height or 0, b.x, b.y, b.width or 0, b.height or 0)
end

function SpaceShooter:checkComplete()
    return self.metrics.deaths >= self.PLAYER_MAX_DEATHS or self.metrics.kills >= self.target_kills
end

-- Phase 3.3: Override onComplete to play success sound and stop music
function SpaceShooter:onComplete()
    -- Determine if win (reached target kills) or loss (max deaths)
    local is_win = self.metrics.kills >= self.target_kills

    if is_win then
        self:playSound("success", 1.0)
    else
        -- Lost due to too many deaths
        self:playSound("death", 1.0)
    end

    -- Stop music
    self:stopMusic()

    -- Call parent onComplete
    SpaceShooter.super.onComplete(self)
end

function SpaceShooter:keypressed(key)
    return false
end

return SpaceShooter