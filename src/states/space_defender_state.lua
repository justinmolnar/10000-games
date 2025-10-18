-- src/states/space_defender_state.lua
local Object = require('class')
local BulletSystem = require('models.bullet_system') -- Require BulletSystem
local Collision = require('utils.collision')
local SpaceDefenderView = require('views.space_defender_view')
local json = require('json')
local SpaceDefenderState = Object:extend('SpaceDefenderState')

function SpaceDefenderState:init(player_data, game_data, state_machine, save_manager, statistics, level_number)
    self.player_data = player_data
    self.game_data = game_data
    self.state_machine = state_machine -- Keep reference for now, though signals are used
    self.save_manager = save_manager
    self.statistics = statistics -- Store statistics model
    self.view = SpaceDefenderView:new(self)
    self.all_level_data = nil
    self.current_level_data = nil
    self.current_level = level_number or 1
    self.player_ship = nil
    self.enemies = {}
    self.bullet_system = nil -- Will be created in enter
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
    self.viewport = nil -- Initialize viewport
end

function SpaceDefenderState:setViewport(x, y, width, height)
    self.viewport = {x = x, y = y, width = width, height = height}
    -- Note: Gameplay logic uses love.graphics.getWidth/Height. This won't scale automatically.
    -- For Phase 4, we just clip rendering. A full solution needs scaling/resolution change.
    print("Warning: Space Defender viewport set, but gameplay logic might not scale correctly.")
end


function SpaceDefenderState:loadLevelData()
    if self.all_level_data then return true end

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


function SpaceDefenderState:enter(level_number)
    self.current_level = level_number or 1

    if not self:loadLevelData() then
        print("FATAL: Could not load level data. Cannot start Space Defender.")
        return
    end

    self.current_level_data = self.all_level_data[self.current_level]
    if not self.current_level_data then
        print("ERROR: No data found for level " .. self.current_level .. ". Using level 1 data as fallback.")
        self.current_level_data = self.all_level_data[1]
        if not self.current_level_data then
            print("FATAL: No level 1 data found. Cannot start Space Defender.")
            return
        end
    end

    self.level_complete = false
    self.game_over = false
    self.score = 0
    self.tokens_earned = 0
    self.paused = false

    local game_width = love.graphics.getWidth()
    local game_height = love.graphics.getHeight()

    self.player_ship = {
        x = game_width / 2, y = game_height - 80,
        width = 30, height = 30, speed = 250,
        hp = 3, max_hp = 3, bombs = 3, max_bombs = 3
    }

    -- Initialize bullet system IMMEDIATELY with statistics
    self.bullet_system = BulletSystem:new(self.statistics)
    local fire_rate_mult, damage_mult = self:getLevelBonuses()
    self.bullet_system:setGlobalMultipliers(fire_rate_mult, damage_mult)
    self.bullet_system:loadBulletTypes(self.player_data, self.game_data)

    self.current_wave = 1
    self.wave_spawn_timer = 0
    self.wave_enemies_spawned = 0

    self.enemies = {}
    self.boss = nil
    self.boss_active = false

    print("Starting Space Defender Level " .. self.current_level)
end

function SpaceDefenderState:getLevelBonuses()
    -- These bonuses might come from PlayerData later based on highest level reached
    local fire_rate = 1.0
    local damage = 1.0
    if self.current_level >= 3 then damage = 1.5 end
    if self.current_level >= 5 then damage = 2.0; fire_rate = 1.2 end -- Adjusted fire rate bonus
    -- Example using PlayerData if available
    -- local highest_level = self.player_data and self.player_data.space_defender_level or 1
    -- fire_rate = 1 + (highest_level * 0.1)
    -- damage = 1 + (highest_level * 0.2)
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
    -- Use love.graphics dimensions for boundary checks
    local game_width = love.graphics.getWidth()
    local game_height = love.graphics.getHeight()

    if love.keyboard.isDown('left', 'a') then ship.x = ship.x - ship.speed * dt end
    if love.keyboard.isDown('right', 'd') then ship.x = ship.x + ship.speed * dt end
    if love.keyboard.isDown('up', 'w') then ship.y = ship.y - ship.speed * dt end
    if love.keyboard.isDown('down', 's') then ship.y = ship.y + ship.speed * dt end
    ship.x = math.max(ship.width/2, math.min(game_width - ship.width/2, ship.x))
    ship.y = math.max(ship.height/2, math.min(game_height - ship.height/2, ship.y))
end

function SpaceDefenderState:updateEnemies(dt)
    local game_height = love.graphics.getHeight()
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        if not enemy then goto continue_enemy_loop end

        enemy.y = enemy.y + enemy.speed * dt
        if enemy.pattern == "zigzag" then enemy.x = enemy.x + math.sin(enemy.y / 30) * 100 * dt
        elseif enemy.pattern == "sine" then enemy.x = enemy.x + math.cos(enemy.y / 50) * 80 * dt end

        if self.player_ship then
            local p_x1 = self.player_ship.x - self.player_ship.width/2
            local p_y1 = self.player_ship.y - self.player_ship.height/2
            if Collision.checkAABB(
                enemy.x - enemy.width/2, enemy.y - enemy.height/2, enemy.width, enemy.height,
                p_x1, p_y1, self.player_ship.width, self.player_ship.height
            ) then
                self:takeDamage(1)
                table.remove(self.enemies, i)
                goto continue_enemy_loop -- Skip offscreen check if removed
            end
        end

        if enemy.y > game_height + 20 then
            table.remove(self.enemies, i)
        end
        ::continue_enemy_loop::
    end
end

function SpaceDefenderState:updateBoss(dt)
    local boss = self.boss
    if not boss then return end
    local game_width = love.graphics.getWidth()
    boss.x = boss.x + boss.vx * dt
    if boss.x <= boss.width/2 or boss.x >= game_width - boss.width/2 then boss.vx = -boss.vx end
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

function SpaceDefenderState:bossAttack()
    if not self.boss or not self.current_level_data or not self.current_level_data.boss then return end
    local enemy_hp = self.current_level_data.boss.attack_power or 50
    -- Example attack: Spawn enemies around boss
    for i = 1, 3 do
        local angle = (i / 3) * math.pi * 2 + (self.current_level * 0.1) -- Add variation
        self:spawnEnemy(
            self.boss.x + math.cos(angle) * 70, self.boss.y + math.sin(angle) * 30,
            "straight", enemy_hp, 150 + self.current_level * 5 -- Scale speed slightly
        )
    end
end

function SpaceDefenderState:updateWaveSpawning(dt)
    if not self.current_level_data or not self.current_level_data.waves then return end
    local game_width = love.graphics.getWidth()

    local waves = self.current_level_data.waves
    if self.current_wave > #waves then
        if not self.boss_active and #self.enemies == 0 then self:spawnBoss() end
        return
    end

    local wave = waves[self.current_wave]
    if not wave then return end

    if self.wave_enemies_spawned < wave.enemy_count then
        self.wave_spawn_timer = self.wave_spawn_timer - dt
        if self.wave_spawn_timer <= 0 then
            local pattern = wave.patterns[math.random(#wave.patterns)] or "straight"
            self:spawnEnemy(
                math.random(20, game_width - 20), -20,
                pattern, wave.enemy_hp, wave.enemy_speed
            )
            self.wave_enemies_spawned = self.wave_enemies_spawned + 1
            self.wave_spawn_timer = wave.spawn_rate
        end
    elseif #self.enemies == 0 then
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
        width = 30, height = 30,
        hp = hp, max_hp = hp,
        speed = speed,
        pattern = pattern,
        damaged = false
    })
end

function SpaceDefenderState:spawnBoss()
    if not self.current_level_data or not self.current_level_data.boss then
        print("ERROR: Cannot spawn boss, data missing for level " .. self.current_level)
        self:onLevelComplete() -- Auto-complete if no boss data? Risky.
        return
    end

    print("BOSS SPAWNED!")
    self.boss_active = true
    local boss_data = self.current_level_data.boss
    local game_width = love.graphics.getWidth()

    self.boss = {
        x = game_width / 2, y = 100,
        width = boss_data.width or 80,
        height = boss_data.height or 80,
        hp = boss_data.hp or 5000,
        max_hp = boss_data.hp or 5000,
        vx = boss_data.vx or 100,
        attack_timer = boss_data.attack_rate or 2.0,
        attack_rate = boss_data.attack_rate or 2.0
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
        self.bullet_system:clear() -- Clear player bullets

        -- Damage enemies
        for i = #self.enemies, 1, -1 do
            local enemy = self.enemies[i]
            if enemy then
                local damage = (enemy.max_hp * 0.5) + 50 -- Ensure some flat damage
                enemy.hp = enemy.hp - damage
                if enemy.hp <= 0 then table.remove(self.enemies, i) end
            end
        end
        -- Damage boss
        if self.boss then
             local boss_damage = (self.boss.max_hp * 0.1) + 500
             self.boss.hp = self.boss.hp - boss_damage
        end

        print("BOMB! Remaining: " .. self.player_ship.bombs)
    end
end

function SpaceDefenderState:draw()
    if not self.viewport then return end -- Don't draw if no viewport

    love.graphics.push()
    love.graphics.translate(self.viewport.x, self.viewport.y)
    love.graphics.setScissor(self.viewport.x, self.viewport.y, self.viewport.width, self.viewport.height)

    -- Draw background specific to the viewport
    love.graphics.setColor(0,0,0.1) -- Dark space background
    love.graphics.rectangle('fill', 0, 0, self.viewport.width, self.viewport.height)

    -- View drawing needs to be aware of viewport dimensions
    if self.bullet_system then
        local FINAL_MVP_LEVEL = 5 -- Define or get from config
        self.view:drawWindowed(
            self.player_ship, self.enemies, self.boss, self.boss_active,
            self.bullet_system, self.current_wave,
            (self.current_level_data and #self.current_level_data.waves or 0),
            self.current_level, self.tokens_earned,
            self.level_complete and self.current_level ~= FINAL_MVP_LEVEL,
            self.game_over, self.paused,
            self.viewport.width, self.viewport.height -- Pass dimensions
        )
    else
        love.graphics.setColor(1,0,0)
        love.graphics.print("Error: BulletSystem not loaded!", 10, 10)
    end

    love.graphics.setScissor()
    love.graphics.pop()
end


function SpaceDefenderState:keypressed(key)
    local handled = true
    local FINAL_MVP_LEVEL = 5 -- Use constant

    if self.level_complete and self.current_level ~= FINAL_MVP_LEVEL then
        if key == 'return' then
            return { type = "event", name = "next_level", level = self.current_level + 1 }
        elseif key == 'escape' then
             return { type = "close_window" }
        else
            handled = false
        end
        return handled and { type = "content_interaction" } or false -- Return event object or false
    end

    if self.game_over then
        if key == 'return' then
             return { type = "close_window" }
        else
            handled = false
        end
        return handled and { type = "content_interaction" } or false
    end

    if self.level_complete and self.current_level == FINAL_MVP_LEVEL then
         -- Needs to signal completion state launch
         return { type = "event", name = "show_completion" }
    end

    -- Normal gameplay controls
    if key == 'escape' then
        return { type = "close_window" }
    elseif key == 'p' then
        self.paused = not self.paused
    elseif key == 'x' or key == 'space' then
        self:useBomb()
    else
        handled = false
    end

    -- If handled by gameplay, return true, otherwise false or event object
    return handled and { type = "content_interaction" } or false
end

function SpaceDefenderState:onLevelComplete()
    if self.level_complete then return end
    self.level_complete = true
    self.paused = true

    local base_reward = 500
    local level_multiplier = 1 + (self.current_level * 0.5) -- Adjusted multiplier
    self.tokens_earned = math.floor(base_reward * level_multiplier)

    self.player_data:addTokens(self.tokens_earned)
    self.player_data:unlockLevel(self.current_level)
    self.save_manager.save(self.player_data)
    if self.statistics then self.statistics:save() end

    print("Level " .. self.current_level .. " complete! Earned " .. self.tokens_earned .. " tokens")
    print("Unlocked level progress up to: " .. self.player_data.space_defender_level)

    -- Don't switch state here, rely on keypressed returning event
end

function SpaceDefenderState:onLevelFailed()
     if self.game_over then return end
    self.game_over = true
    self.paused = true
    print("Game Over!")
    -- Don't switch state here, rely on keypressed returning event
end

function SpaceDefenderState:mousepressed(x, y, button)
    -- Translate coordinates if mouse interaction is added later
    if not self.viewport then return false end
    local local_x = x - self.viewport.x
    local local_y = y - self.viewport.y
    if local_x < 0 or local_x > self.viewport.width or local_y < 0 or local_y > self.viewport.height then
        return false -- Click outside viewport
    end
    -- No mouse actions currently
    return false
end


return SpaceDefenderState