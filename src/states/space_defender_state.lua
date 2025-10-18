-- space_defender_state.lua: Main bullet hell shooter game

local Object = require('class')
local BulletSystem = require('models.bullet_system')
local Collision = require('utils.collision')
local SpaceDefenderView = require('views.space_defender_view')
local json = require('json') -- Added for loading level data
local SpaceDefenderState = Object:extend('SpaceDefenderState')

function SpaceDefenderState:init(player_data, game_data, state_machine, save_manager)
    self.player_data = player_data
    self.game_data = game_data
    self.state_machine = state_machine
    self.save_manager = save_manager

    self.view = SpaceDefenderView:new(self)

    self.all_level_data = nil -- Will store data for all levels from JSON
    self.current_level_data = nil -- Data for the currently playing level

    self.current_level = 1
    self.player_ship = nil
    self.enemies = {}
    self.bullet_system = nil
    -- self.waves = {} -- Replaced by current_level_data.waves
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
end

function SpaceDefenderState:loadLevelData()
    if self.all_level_data then return true end -- Already loaded

    local file_path = "assets/data/space_defender_levels.json"
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

    -- Store data indexed by level number for easy access
    self.all_level_data = {}
    for _, level_def in ipairs(data) do
        if level_def.level then
            self.all_level_data[level_def.level] = level_def
        else
            print("Warning: Skipping level definition without 'level' field in JSON.")
        end
    end
    
    -- FIX: Get table keys using standard Lua
    local level_keys = {}
    for k in pairs(self.all_level_data) do
        table.insert(level_keys, k)
    end
    table.sort(level_keys) -- Sort keys numerically for cleaner output
    
    print("Loaded Space Defender level data for levels: ", table.concat(level_keys, ", "))
    return true
end


function SpaceDefenderState:enter(level_number)
    self.current_level = level_number or 1

    -- Load level data if not already loaded
    if not self:loadLevelData() then
        -- Handle error - maybe switch back to desktop?
        print("FATAL: Could not load level data. Returning to desktop.")
        self.state_machine:switch('desktop')
        return
    end

    -- Get data for the specific level
    self.current_level_data = self.all_level_data[self.current_level]
    if not self.current_level_data then
         print("ERROR: No data found for level " .. self.current_level .. ". Using level 1 data as fallback.")
         self.current_level_data = self.all_level_data[1]
         if not self.current_level_data then -- Still no data? Major issue.
              print("FATAL: No level 1 data found. Cannot start Space Defender.")
              self.state_machine:switch('desktop')
              return
         end
    end

    self.level_complete = false
    self.game_over = false
    self.score = 0
    self.tokens_earned = 0
    self.paused = false

    -- Initialize player ship (unchanged)
    self.player_ship = {
        x = love.graphics.getWidth() / 2, y = love.graphics.getHeight() - 80,
        width = 30, height = 30, speed = 250,
        hp = 3, max_hp = 3, bombs = 3, max_bombs = 3
    }

    -- Initialize bullet system (unchanged)
    self.bullet_system = BulletSystem:new()
    local fire_rate_mult, damage_mult = self:getLevelBonuses()
    self.bullet_system:setGlobalMultipliers(fire_rate_mult, damage_mult)
    self.bullet_system:loadBulletTypes(self.player_data, self.game_data)

    -- Initialize waves based on loaded level data
    self.current_wave = 1
    self.wave_spawn_timer = 0
    self.wave_enemies_spawned = 0

    self.enemies = {}
    self.boss = nil
    self.boss_active = false

    print("Starting Space Defender Level " .. self.current_level)
end

function SpaceDefenderState:getLevelBonuses()
    -- These could also be moved to the level JSON later if desired
    local fire_rate = 1.0
    local damage = 1.0
    if self.current_level >= 3 then damage = 1.5 end
    if self.current_level >= 5 then damage = 2.0; fire_rate = 2.0 end
    return fire_rate, damage
end

-- createWaves method removed - waves are now loaded from self.current_level_data.waves

function SpaceDefenderState:update(dt)
    if self.view and self.view.update then self.view:update(dt) end
    if self.paused or self.level_complete or self.game_over then return end

    self:updatePlayer(dt)
    self.bullet_system:update(dt, self.player_ship, self.enemies, self.boss)
    self:updateEnemies(dt)
    if self.boss_active and self.boss then self:updateBoss(dt) end
    if not self.boss_active then self:updateWaveSpawning(dt) end

    -- Check completion conditions
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
    ship.x = math.max(ship.width/2, math.min(love.graphics.getWidth() - ship.width/2, ship.x))
    ship.y = math.max(ship.height/2, math.min(love.graphics.getHeight() - ship.height/2, ship.y))
end

function SpaceDefenderState:updateEnemies(dt)
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        enemy.y = enemy.y + enemy.speed * dt
        if enemy.pattern == "zigzag" then enemy.x = enemy.x + math.sin(enemy.y / 30) * 100 * dt
        elseif enemy.pattern == "sine" then enemy.x = enemy.x + math.cos(enemy.y / 50) * 80 * dt end

        local p_x1 = self.player_ship.x - self.player_ship.width/2
        local p_y1 = self.player_ship.y - self.player_ship.height/2
        if Collision.checkAABB(
            enemy.x - enemy.width/2, enemy.y - enemy.height/2, enemy.width, enemy.height,
            p_x1, p_y1, self.player_ship.width, self.player_ship.height
        ) then
            self:takeDamage(1)
            table.remove(self.enemies, i)
        elseif enemy.y > love.graphics.getHeight() + 20 then
            table.remove(self.enemies, i)
        end
    end
end

function SpaceDefenderState:updateBoss(dt)
    local boss = self.boss
    if not boss then return end
    boss.x = boss.x + boss.vx * dt
    if boss.x <= boss.width/2 or boss.x >= love.graphics.getWidth() - boss.width/2 then boss.vx = -boss.vx end
    boss.attack_timer = boss.attack_timer - dt
    if boss.attack_timer <= 0 then
        self:bossAttack()
        boss.attack_timer = boss.attack_rate
    end
    local p_x1 = self.player_ship.x - self.player_ship.width/2
    local p_y1 = self.player_ship.y - self.player_ship.height/2
    if Collision.checkAABB(
        boss.x - boss.width/2, boss.y - boss.height/2, boss.width, boss.height,
        p_x1, p_y1, self.player_ship.width, self.player_ship.height
    ) then self:takeDamage(1) end
end

function SpaceDefenderState:bossAttack()
    if not self.boss or not self.current_level_data or not self.current_level_data.boss then return end
    -- Use attack_power from loaded boss data to scale spawned enemy HP
    local enemy_hp = self.current_level_data.boss.attack_power or 50
    -- Simple attack: spawn enemies around boss
    for i = 1, 3 do
        local angle = (i / 3) * math.pi * 2
        self:spawnEnemy(
            self.boss.x + math.cos(angle) * 50, self.boss.y,
            "straight", enemy_hp, 150 -- Fixed speed for now
        )
    end
end

function SpaceDefenderState:updateWaveSpawning(dt)
    if not self.current_level_data or not self.current_level_data.waves then return end -- Safety check

    local waves = self.current_level_data.waves
    if self.current_wave > #waves then
        if not self.boss_active and #self.enemies == 0 then self:spawnBoss() end
        return
    end

    local wave = waves[self.current_wave]
    if not wave then return end -- Safety check

    if self.wave_enemies_spawned < wave.enemy_count then
        self.wave_spawn_timer = self.wave_spawn_timer - dt
        if self.wave_spawn_timer <= 0 then
            -- Choose a pattern randomly from the allowed patterns for this wave
            local pattern = wave.patterns[math.random(#wave.patterns)] or "straight"
            self:spawnEnemy(
                math.random(20, love.graphics.getWidth() - 20), -20,
                pattern, wave.enemy_hp, wave.enemy_speed
            )
            self.wave_enemies_spawned = self.wave_enemies_spawned + 1
            self.wave_spawn_timer = wave.spawn_rate
        end
    elseif #self.enemies == 0 then
        -- Wave complete, move to next
        local old_wave = self.current_wave
        self.current_wave = self.current_wave + 1
        self.wave_enemies_spawned = 0
        self.wave_spawn_timer = 0
        if self.current_wave <= #waves then
           print("Wave " .. old_wave .. " complete!")
        end
    end
end


function SpaceDefenderState:spawnEnemy(x, y, pattern, hp, speed)
    table.insert(self.enemies, {
        x = x, y = y,
        width = 30, height = 30, -- Could also be defined per wave/enemy type in JSON
        hp = hp, max_hp = hp,
        speed = speed,
        pattern = pattern,
        damaged = false
    })
end

function SpaceDefenderState:spawnBoss()
    if not self.current_level_data or not self.current_level_data.boss then
        print("ERROR: Cannot spawn boss, data missing for level " .. self.current_level)
        -- Potentially mark level as complete without boss? Or error out?
        self:onLevelComplete() -- For MVP, let's just complete the level.
        return
    end

    print("BOSS SPAWNED!")
    self.boss_active = true
    local boss_data = self.current_level_data.boss

    -- Create boss using data from JSON
    self.boss = {
        x = love.graphics.getWidth() / 2, y = 100,
        width = boss_data.width or 80,
        height = boss_data.height or 80,
        hp = boss_data.hp or 5000,
        max_hp = boss_data.hp or 5000,
        vx = boss_data.vx or 100,
        attack_timer = boss_data.attack_rate or 2.0, -- Start attack timer
        attack_rate = boss_data.attack_rate or 2.0
        -- Add other boss properties from JSON as needed (e.g., attack types)
    }
end


function SpaceDefenderState:takeDamage(amount)
    if self.player_ship then
        self.player_ship.hp = self.player_ship.hp - amount
        print("Player HP: " .. self.player_ship.hp)
    end
end

function SpaceDefenderState:useBomb()
    if self.player_ship and self.player_ship.bombs > 0 then
        self.player_ship.bombs = self.player_ship.bombs - 1
        self.bullet_system:clear()

        for i = #self.enemies, 1, -1 do
            self.enemies[i].hp = self.enemies[i].hp - (self.enemies[i].max_hp * 0.5)
            if self.enemies[i].hp <= 0 then table.remove(self.enemies, i) end
        end
        if self.boss then self.boss.hp = self.boss.hp - (self.boss.max_hp * 0.1) end

        print("BOMB! Remaining: " .. self.player_ship.bombs)
    end
end

function SpaceDefenderState:draw()
    self.view:draw(
        self.player_ship, self.enemies, self.boss, self.boss_active,
        self.bullet_system, self.current_wave,
        -- Pass total waves count from loaded data
        (self.current_level_data and #self.current_level_data.waves or 0),
        self.current_level, self.tokens_earned,
        self.level_complete, self.game_over, self.paused
    )
end

function SpaceDefenderState:keypressed(key)
    local handled = true
    if self.level_complete or self.game_over then
        if key == 'return' then self.state_machine:switch('desktop')
        else handled = false end
        return handled
    end

    if key == 'escape' then self.state_machine:switch('desktop')
    elseif key == 'p' then self.paused = not self.paused
    elseif key == 'x' or key == 'space' then self:useBomb()
    else handled = false end
    return handled
end

function SpaceDefenderState:onLevelComplete()
    if self.level_complete then return end
    self.level_complete = true
    self.paused = true

    -- Use config for reward calculation? For now, keep simple scaling.
    local base_reward = 500
    local level_multiplier = self.current_level * 2
    self.tokens_earned = math.floor(base_reward * level_multiplier)

    self.player_data:addTokens(self.tokens_earned)
    self.player_data:unlockLevel(self.current_level) -- Pass level beaten
    self.save_manager.save(self.player_data)

    print("Level " .. self.current_level .. " complete! Earned " .. self.tokens_earned .. " tokens")
end

function SpaceDefenderState:onLevelFailed()
     if self.game_over then return end
    self.game_over = true
    self.paused = true
    print("Game Over!")
end

return SpaceDefenderState