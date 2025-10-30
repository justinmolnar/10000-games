local Object = require('class')
local BulletSystem = require('models.bullet_system')
local Collision = require('src.utils.collision')
local SpaceDefenderView = require('src.views.space_defender_view')
local json = require('json')
local Paths = require('src.paths')
local SpaceDefenderState = Object:extend('SpaceDefenderState')

function SpaceDefenderState:init(player_data, game_data, state_machine, save_manager, statistics, di)
    self.player_data = player_data
    self.game_data = game_data
    self.state_machine = state_machine
    self.save_manager = save_manager
    self.statistics = statistics
    self.di = di
    self.view = SpaceDefenderView:new(self)
    
    -- Game dimensions (default)
    local SDCFG = (self.di and self.di.config and self.di.config.games and self.di.config.games.space_defender) or {}
    self._cfg = SDCFG
    self.game_width = (SDCFG and SDCFG.arena and SDCFG.arena.width) or 1024
    self.game_height = (SDCFG and SDCFG.arena and SDCFG.arena.height) or 768
    
    self.all_level_data = nil
    self.current_level_data = nil
    self.current_level = 1
    self.player_ship = nil
    self.enemies = {}
    self.bullet_system = nil
    self.current_wave = 0
    self.wave_spawn_timer = 0
    self.wave_enemies_spawned = 0
    self.boss = nil
    self.boss_active = false
    self.paused = false
    self.level_complete = false
    self.game_over = false
    self.score = 0
    self.tokens_earned = 0
    self.viewport = nil
    
    self.window_id = nil
    self.window_manager = nil
end

function SpaceDefenderState:setViewport(x, y, width, height)
    self.viewport = {x = x, y = y, width = width, height = height}
    self.game_width = width
    self.game_height = height
    
    -- Reposition player if exists
    if self.player_ship then
        self.player_ship.x = math.max(self.player_ship.width/2, math.min(self.game_width - self.player_ship.width/2, self.player_ship.x))
    local y_off = (self._cfg and self._cfg.player and self._cfg.player.start_y_offset) or 80
    self.player_ship.y = self.game_height - y_off
    end
    
    print("[SpaceDefender] Play area updated to:", width, height)
end

function SpaceDefenderState:setWindowContext(window_id, window_manager)
    self.window_id = window_id
    self.window_manager = window_manager
end

function SpaceDefenderState:loadLevelData()
    if self.all_level_data then return true end

    local file_path = Paths.assets.data .. "space_defender_levels.json"
    local read_ok, contents = pcall(love.filesystem.read, file_path)
    if not read_ok or not contents then
        print("ERROR: Could not read level data: " .. file_path .. " - " .. tostring(contents))
        return false
    end

    local decode_ok, data = pcall(json.decode, contents)
    if not decode_ok then
        print("ERROR: Failed to decode level data: " .. file_path .. " - " .. tostring(data))
        return false
    end

    self.all_level_data = {}
    for _, level_def in ipairs(data) do
        if level_def.level then
            self.all_level_data[level_def.level] = level_def
        else
            print("Warning: Skipping level definition without 'level' field in JSON.")
        end
    end

    local level_keys = {}
    for k in pairs(self.all_level_data) do table.insert(level_keys, k) end
    table.sort(level_keys)

    print("Loaded Space Defender level data for levels: ", table.concat(level_keys, ", "))
    return true
end

function SpaceDefenderState:generateWavesForLevel()
    local scaling = (self._cfg and self._cfg.scaling) or {}
    local wave_count = math.floor((scaling.wave_count_base or 2) + (self.current_level * (scaling.wave_count_per_level or 3)))

    local waves = {}
    for i = 1, wave_count do
        local enemy_count = math.floor((scaling.enemy_count_base or 10) * (self.current_level ^ (scaling.enemy_count_exponent or 1.3)))
        local spawn_rate = math.max(
            scaling.spawn_rate_min or 0.1,
            (scaling.spawn_rate_base or 1.0) - (self.current_level * (scaling.spawn_rate_level_reduction or 0.05))
        )

        table.insert(waves, {
            enemy_count = enemy_count,
            spawn_rate = spawn_rate,
            patterns = {"straight", "zigzag", "sine"}
        })
    end

    return waves
end

function SpaceDefenderState:enter(level_number)
    self.current_level = level_number or 1

    self.generated_waves = self:generateWavesForLevel()
    self.total_waves = #self.generated_waves

    self.level_complete = false
    self.game_over = false
    self.score = 0
    self.tokens_earned = 0
    self.paused = false

    local pcfg = self._cfg and self._cfg.player or {}
    self.player_ship = {
        x = self.game_width / 2,
        y = self.game_height - (pcfg.start_y_offset or 80),
        width = pcfg.width or 30,
        height = pcfg.height or 30,
        speed = pcfg.speed or 250,
        hp = pcfg.hp or 3,
        max_hp = pcfg.hp or 3,
        bombs = pcfg.bombs or 3,
        max_bombs = pcfg.bombs or 3
    }

    local sprite_manager = self.di and self.di.spriteManager
    self.bullet_system = BulletSystem:new(self.statistics, sprite_manager)
    if self.di and self.di.config and self.bullet_system.injectConfig then
        self.bullet_system:injectConfig(self.di.config)
    end
    local fire_rate_mult, damage_mult = self:getLevelBonuses()
    self.bullet_system:setGlobalMultipliers(fire_rate_mult, damage_mult)
    self.bullet_system:loadBulletTypes(self.player_data, self.game_data)

    self.current_wave = 1
    self.wave_spawn_timer = 0
    self.wave_enemies_spawned = 0

    self.enemies = {}
    self.boss = nil
    self.boss_active = false

    print("Starting Space Defender Level " .. self.current_level .. " with " .. self.total_waves .. " waves")
end

function SpaceDefenderState:getLevelBonuses()
    local fire_rate = 1.0
    local damage = 1.0
    local bonuses = self._cfg and self._cfg.level_bonuses and self._cfg.level_bonuses.thresholds or {}
    for _, t in ipairs(bonuses) do
        if self.current_level >= (t.level or 0) then
            if t.damage then damage = t.damage end
            if t.fire_rate then fire_rate = t.fire_rate end
        end
    end
    return fire_rate, damage
end

function SpaceDefenderState:update(dt)
    if self.view and self.view.update then self.view:update(dt) end
    if self.paused or self.level_complete or self.game_over then return end

    self:updatePlayer(dt)
    if self.bullet_system then
        self.bullet_system:update(dt, self.player_ship, self.enemies, self.boss)
    end
    self:updateEnemies(dt)
    if self.boss_active and self.boss then self:updateBoss(dt) end
    if not self.boss_active then self:updateWaveSpawning(dt) end

    if self.boss_active and self.boss and self.boss.hp <= 0 then self:onLevelComplete() end
    if self.player_ship and self.player_ship.hp <= 0 then self:onLevelFailed() end
end

function SpaceDefenderState:updatePlayer(dt)
    local ship = self.player_ship
    if not ship then return end

    if love.keyboard.isDown('left', 'a') then ship.x = ship.x - ship.speed * dt end
    if love.keyboard.isDown('right', 'd') then ship.x = ship.x + ship.speed * dt end
    if love.keyboard.isDown('up', 'w') then ship.y = ship.y - ship.speed * dt end
    if love.keyboard.isDown('down', 's') then ship.y = ship.y + ship.speed * dt end
    
    ship.x = math.max(ship.width/2, math.min(self.game_width - ship.width/2, ship.x))
    ship.y = math.max(ship.height/2, math.min(self.game_height - ship.height/2, ship.y))
end

function SpaceDefenderState:updateEnemies(dt)
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        if not enemy then goto continue_enemy_loop end

        enemy.y = enemy.y + enemy.speed * dt
        local ecfg = self._cfg and self._cfg.enemy or {}
        if enemy.pattern == "zigzag" then
            local z = ecfg.zigzag or { den = 30, amp = 100 }
            enemy.x = enemy.x + math.sin(enemy.y / (z.den or 30)) * (z.amp or 100) * dt
        elseif enemy.pattern == "sine" then
            local s = ecfg.sine or { den = 50, amp = 80 }
            enemy.x = enemy.x + math.cos(enemy.y / (s.den or 50)) * (s.amp or 80) * dt
        end

        if self.player_ship then
            local p_x1 = self.player_ship.x - self.player_ship.width/2
            local p_y1 = self.player_ship.y - self.player_ship.height/2
            if Collision.checkAABB(
                enemy.x - enemy.width/2, enemy.y - enemy.height/2, enemy.width, enemy.height,
                p_x1, p_y1, self.player_ship.width, self.player_ship.height
            ) then
                self:takeDamage(1)
                table.remove(self.enemies, i)
                goto continue_enemy_loop
            end
        end

        -- Enemy reached bottom - take a life and remove enemy
        if enemy.y > self.game_height then
            self:takeDamage(1)
            table.remove(self.enemies, i)
            print("Enemy reached bottom! Player HP: " .. (self.player_ship and self.player_ship.hp or 0))
        end
        ::continue_enemy_loop::
    end
end

function SpaceDefenderState:updateBoss(dt)
    local boss = self.boss
    if not boss then return end

    local bmove = self._cfg and self._cfg.boss_movement or {}

    -- Move horizontally
    boss.x = boss.x + (bmove.side_speed or 100) * boss.vx_dir * dt
    if boss.x <= boss.width/2 or boss.x >= self.game_width - boss.width/2 then
        boss.vx_dir = -boss.vx_dir
    end

    -- Move downward toward player
    boss.y = boss.y + (bmove.move_down_speed or 15) * dt

    -- Check if boss reached bottom threshold - instant game over
    local death_threshold = (bmove.death_y_threshold or 0.85) * self.game_height
    if boss.y >= death_threshold then
        self.player_ship.hp = 0
        print("Boss reached bottom! Game Over!")
    end

    boss.attack_timer = boss.attack_timer - dt
    if boss.attack_timer <= 0 then
        self:bossAttack()
        boss.attack_timer = boss.attack_rate
    end

    if self.player_ship then
        local p_x1 = self.player_ship.x - self.player_ship.width/2
        local p_y1 = self.player_ship.y - self.player_ship.height/2
        if Collision.checkAABB(
            boss.x - boss.width/2, boss.y - boss.height/2, boss.width, boss.height,
            p_x1, p_y1, self.player_ship.width, self.player_ship.height
        ) then self:takeDamage(1) end
    end
end

function SpaceDefenderState:calculateBossAttackHP()
    local scaling = (self._cfg and self._cfg.scaling) or {}
    local base = scaling.attack_hp_base or 50
    local exponent = scaling.attack_hp_exponent or 1.5
    return math.floor(base * (self.current_level ^ exponent))
end

function SpaceDefenderState:bossAttack()
    if not self.boss then return end
    local orbit = (self._cfg and self._cfg.boss and self._cfg.boss.orbit) or {}
    local count = orbit.count or 3
    local radius_x = orbit.radius_x or 70
    local radius_y = orbit.radius_y or 30
    local rotate_per_level = orbit.rotate_per_level or 0.1
    local speed_base = orbit.spawn_speed_base or 150
    local speed_per_lvl = orbit.spawn_speed_per_level or 5
    local enemy_hp = self:calculateBossAttackHP()

    for i = 1, count do
        local angle = (i / count) * math.pi * 2 + (self.current_level * rotate_per_level)
        self:spawnEnemy(
            self.boss.x + math.cos(angle) * radius_x,
            self.boss.y + math.sin(angle) * radius_y,
            "straight", enemy_hp, speed_base + self.current_level * speed_per_lvl
        )
    end
end

function SpaceDefenderState:calculateEnemyHP()
    local scaling = (self._cfg and self._cfg.scaling) or {}
    local base = scaling.enemy_hp_base or 500
    local exponent = scaling.enemy_hp_exponent or 1.8
    return math.floor(base * (self.current_level ^ exponent))
end

function SpaceDefenderState:updateWaveSpawning(dt)
    if not self.generated_waves then return end

    -- All waves complete - spawn boss
    if self.current_wave > self.total_waves then
        if not self.boss_active and #self.enemies == 0 then self:spawnBoss() end
        return
    end

    local wave = self.generated_waves[self.current_wave]
    if not wave then return end

    -- Spawn enemies for current wave
    if self.wave_enemies_spawned < wave.enemy_count then
        self.wave_spawn_timer = self.wave_spawn_timer - dt
        if self.wave_spawn_timer <= 0 then
            local pattern = wave.patterns[math.random(#wave.patterns)] or "straight"
            local enemy_hp = self:calculateEnemyHP()
            local enemy_speed = 100 + (self.current_level * 10)  -- Speed increases with level

            self:spawnEnemy(
                math.random((self._cfg and self._cfg.spawn and self._cfg.spawn.x_inset) or 20, self.game_width - ((self._cfg and self._cfg.spawn and self._cfg.spawn.x_inset) or 20)),
                (self._cfg and self._cfg.spawn and self._cfg.spawn.y_start) or -20,
                pattern, enemy_hp, enemy_speed
            )
            self.wave_enemies_spawned = self.wave_enemies_spawned + 1
            self.wave_spawn_timer = wave.spawn_rate
        end
    -- Wave complete - immediately start next wave (allows blasting through with high power)
    elseif #self.enemies == 0 then
        local old_wave = self.current_wave
        self.current_wave = self.current_wave + 1
        self.wave_enemies_spawned = 0
        self.wave_spawn_timer = 0  -- Start spawning immediately
        if self.current_wave <= self.total_waves then
           print("Wave " .. old_wave .. " complete! Starting wave " .. self.current_wave)
        else
           print("All waves complete! Boss incoming...")
        end
    end
end

function SpaceDefenderState:spawnEnemy(x, y, pattern, hp, speed)
    local ecfg = self._cfg and self._cfg.enemy or {}
    table.insert(self.enemies, {
        x = x, y = y,
        width = ecfg.width or 30, height = ecfg.height or 30,
        hp = hp, max_hp = hp,
        speed = speed,
        pattern = pattern,
        damaged = false
    })
end

function SpaceDefenderState:calculateBossHP()
    local scaling = (self._cfg and self._cfg.scaling) or {}
    local base = scaling.boss_hp_base or 5000
    local exponent = scaling.boss_hp_exponent or 2.0
    return math.floor(base * (self.current_level ^ exponent))
end

function SpaceDefenderState:spawnBoss()
    print("BOSS SPAWNED!")
    self.boss_active = true

    local boss_hp = self:calculateBossHP()
    local bcfg = self._cfg and self._cfg.boss or {}
    local bmove = self._cfg and self._cfg.boss_movement or {}

    self.boss = {
        x = self.game_width / 2,
        y = bmove.min_y or 50,
        width = bcfg.width or 80,
        height = bcfg.height or 80,
        hp = boss_hp,
        max_hp = boss_hp,
        vx_dir = 1,  -- Horizontal movement direction
        attack_timer = bcfg.attack_rate or 2.0,
        attack_rate = bcfg.attack_rate or 2.0
    }
end

function SpaceDefenderState:takeDamage(amount)
    if self.player_ship then
        self.player_ship.hp = self.player_ship.hp - amount
        print("Player HP: " .. self.player_ship.hp)
    end
end

function SpaceDefenderState:useBomb()
    if self.player_ship and self.player_ship.bombs > 0 and self.bullet_system then
        self.player_ship.bombs = self.player_ship.bombs - 1
        self.bullet_system:clear()

        for i = #self.enemies, 1, -1 do
            local enemy = self.enemies[i]
            if enemy then
                local bcfg = self._cfg and self._cfg.bomb or { enemy_frac = 0.5, enemy_bonus = 50 }
                local damage = (enemy.max_hp * (bcfg.enemy_frac or 0.5)) + (bcfg.enemy_bonus or 50)
                enemy.hp = enemy.hp - damage
                if enemy.hp <= 0 then table.remove(self.enemies, i) end
            end
        end
        
        if self.boss then
             local bcfg = self._cfg and self._cfg.bomb or { boss_frac = 0.1, boss_bonus = 500 }
             local boss_damage = (self.boss.max_hp * (bcfg.boss_frac or 0.1)) + (bcfg.boss_bonus or 500)
             self.boss.hp = self.boss.hp - boss_damage
        end

        print("BOMB! Remaining: " .. self.player_ship.bombs)
    end
end

function SpaceDefenderState:draw()
    if not self.viewport then return end
    
    local bg = (self._cfg and self._cfg.view and self._cfg.view.bg_color) or {0,0,0.1}
    love.graphics.setColor(bg[1], bg[2], bg[3])
    love.graphics.rectangle('fill', 0, 0, self.viewport.width, self.viewport.height)

    if self.bullet_system then
    local FINAL_MVP_LEVEL = (self._cfg and self._cfg.final_level) or 5
        local draw_args = {
            player = self.player_ship,
            enemies = self.enemies,
            boss = self.boss,
            boss_active = self.boss_active,
            bullet_system = self.bullet_system,
            current_wave = self.current_wave,
            total_waves = self.total_waves or 0,
            current_level = self.current_level,
            tokens_earned = self.tokens_earned,
            level_complete = self.level_complete and self.current_level ~= FINAL_MVP_LEVEL,
            game_over = self.game_over,
            paused = self.paused,
            width = self.viewport.width,
            height = self.viewport.height,
            game_data = self.game_data
        }
        self.view:draw(draw_args)
    else
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("Error: BulletSystem not loaded!", 10, 10)
    end
end

function SpaceDefenderState:keypressed(key)
    local FINAL_MVP_LEVEL = (self._cfg and self._cfg.final_level) or 5

    if self.level_complete and self.current_level ~= FINAL_MVP_LEVEL then
        if key == 'return' then
            return { type = "event", name = "next_level", level = self.current_level + 1 }
        elseif key == 'escape' then
             return { type = "close_window" }
        end
        return { type = "content_interaction" }
    end

    if self.game_over then
        if key == 'return' or key == 'escape' then
             return { type = "close_window" }
        end
        return { type = "content_interaction" }
    end

    if self.level_complete and self.current_level == FINAL_MVP_LEVEL then
         return { type = "event", name = "show_completion" }
    end

    if key == 'escape' then
        return { type = "close_window" }
    elseif key == 'p' then
        self.paused = not self.paused
        return { type = "content_interaction" }
    elseif key == 'x' or key == 'space' then
        self:useBomb()
        return { type = "content_interaction" }
    end

    return false
end

function SpaceDefenderState:onLevelComplete()
    if self.level_complete then return end
    self.level_complete = true
    self.paused = true

    local rewards = (self._cfg and self._cfg.rewards) or { base = 500, per_level_multiplier = 0.5 }
    local base_reward = rewards.base or 500
    local level_multiplier = 1 + (self.current_level * (rewards.per_level_multiplier or 0.5))
    self.tokens_earned = math.floor(base_reward * level_multiplier)

    self.player_data:addTokens(self.tokens_earned)
    self.player_data:unlockLevel(self.current_level)
    self.save_manager.save(self.player_data)
    if self.statistics then self.statistics:save() end

    print("Level " .. self.current_level .. " complete! Earned " .. self.tokens_earned .. " tokens")
    print("Unlocked level progress up to: " .. self.player_data.space_defender_level)
end

function SpaceDefenderState:onLevelFailed()
     if self.game_over then return end
    self.game_over = true
    self.paused = true
    print("Game Over!")
end

function SpaceDefenderState:mousepressed(x, y, button)
    if not self.viewport then return false end

    if x < 0 or x > self.viewport.width or y < 0 or y > self.viewport.height then
        return false
    end

    return false
end

return SpaceDefenderState