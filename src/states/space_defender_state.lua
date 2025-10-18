-- space_defender_state.lua: Main bullet hell shooter game

local Object = require('class')
local SpaceDefenderState = Object:extend('SpaceDefenderState')

function SpaceDefenderState:init()
    self.current_level = 1
    self.player_ship = nil
    self.enemies = {}
    self.bullet_system = nil
    self.waves = {}
    self.current_wave = 0
    self.wave_spawn_timer = 0
    self.wave_enemies_spawned = 0
    self.boss = nil
    self.boss_active = false
    self.paused = false
    self.level_complete = false
    self.game_over = false
    self.score = 0
end

function SpaceDefenderState:enter(level_number)
    self.current_level = level_number or 1
    self.level_complete = false
    self.game_over = false
    self.score = 0
    
    -- Initialize player ship
    self.player_ship = {
        x = love.graphics.getWidth() / 2,
        y = love.graphics.getHeight() - 80,
        width = 30,
        height = 30,
        speed = 250,
        hp = 3,
        max_hp = 3,
        bombs = 3,
        max_bombs = 3
    }
    
    -- Initialize bullet system
    local BulletSystem = require('models.bullet_system')
    self.bullet_system = BulletSystem:new()
    
    -- Apply level bonuses
    local fire_rate_mult, damage_mult = self:getLevelBonuses()
    self.bullet_system:setGlobalMultipliers(fire_rate_mult, damage_mult)
    
    -- Load bullets from completed games
    self.bullet_system:loadBulletTypes(game.player_data, game.game_data)
    
    -- Initialize waves
    self:createWaves()
    self.current_wave = 1
    self.wave_spawn_timer = 0
    self.wave_enemies_spawned = 0
    
    self.enemies = {}
    self.boss = nil
    self.boss_active = false
    
    print("Starting Space Defender Level " .. self.current_level)
end

function SpaceDefenderState:getLevelBonuses()
    local fire_rate = 1.0
    local damage = 1.0
    
    if self.current_level >= 1 then
        -- No bonus at level 1
    end
    if self.current_level >= 3 then
        damage = 1.5
    end
    if self.current_level >= 5 then
        damage = 2.0
        fire_rate = 2.0
    end
    
    return fire_rate, damage
end

function SpaceDefenderState:createWaves()
    self.waves = {}
    
    -- Create just 1 wave for MVP
    local base_hp = 50 * self.current_level
    
    table.insert(self.waves, {
        enemy_count = 15,
        enemy_hp = base_hp,
        spawn_rate = 0.8,
        enemy_speed = 100
    })
end

function SpaceDefenderState:update(dt)
    if self.paused or self.level_complete or self.game_over then
        return
    end
    
    -- Update player
    self:updatePlayer(dt)
    
    -- Update bullet system
    self.bullet_system:update(dt, self.player_ship, self.enemies, self.boss)
    
    -- Update enemies
    self:updateEnemies(dt)
    
    -- Update boss if active
    if self.boss_active and self.boss then
        self:updateBoss(dt)
    end
    
    -- Handle wave spawning
    if not self.boss_active then
        self:updateWaveSpawning(dt)
    end
    
    -- Check for level completion
    if self.boss_active and self.boss and self.boss.hp <= 0 then
        self:onLevelComplete()
    end
    
    -- Check for game over
    if self.player_ship.hp <= 0 then
        self:onLevelFailed()
    end
end

function SpaceDefenderState:updatePlayer(dt)
    local ship = self.player_ship
    
    -- Movement
    if love.keyboard.isDown('left', 'a') then
        ship.x = ship.x - ship.speed * dt
    end
    if love.keyboard.isDown('right', 'd') then
        ship.x = ship.x + ship.speed * dt
    end
    if love.keyboard.isDown('up', 'w') then
        ship.y = ship.y - ship.speed * dt
    end
    if love.keyboard.isDown('down', 's') then
        ship.y = ship.y + ship.speed * dt
    end
    
    -- Clamp to screen
    ship.x = math.max(ship.width/2, math.min(love.graphics.getWidth() - ship.width/2, ship.x))
    ship.y = math.max(ship.height/2, math.min(love.graphics.getHeight() - ship.height/2, ship.y))
end

function SpaceDefenderState:updateEnemies(dt)
    local Collision = require('utils.collision')
    
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        
        -- Move enemy down
        enemy.y = enemy.y + enemy.speed * dt
        
        -- Apply movement pattern
        if enemy.pattern == "zigzag" then
            enemy.x = enemy.x + math.sin(enemy.y / 30) * 100 * dt
        elseif enemy.pattern == "sine" then
            enemy.x = enemy.x + math.cos(enemy.y / 50) * 80 * dt
        end
        
        -- Check collision with player
        if Collision.checkAABB(
            enemy.x, enemy.y, enemy.width, enemy.height,
            self.player_ship.x - self.player_ship.width/2, 
            self.player_ship.y - self.player_ship.height/2,
            self.player_ship.width, self.player_ship.height
        ) then
            self:takeDamage(1)
            table.remove(self.enemies, i)
        elseif enemy.y > love.graphics.getHeight() + 20 then
            -- Remove if off screen
            table.remove(self.enemies, i)
        end
    end
end

function SpaceDefenderState:updateBoss(dt)
    local boss = self.boss
    
    -- Simple boss movement - side to side
    boss.x = boss.x + boss.vx * dt
    
    if boss.x <= boss.width/2 or boss.x >= love.graphics.getWidth() - boss.width/2 then
        boss.vx = -boss.vx
    end
    
    -- Boss attack timer
    boss.attack_timer = boss.attack_timer - dt
    if boss.attack_timer <= 0 then
        self:bossAttack()
        boss.attack_timer = boss.attack_rate
    end
    
    -- Check collision with player
    local Collision = require('utils.collision')
    if Collision.checkAABB(
        boss.x - boss.width/2, boss.y - boss.height/2, boss.width, boss.height,
        self.player_ship.x - self.player_ship.width/2,
        self.player_ship.y - self.player_ship.height/2,
        self.player_ship.width, self.player_ship.height
    ) then
        self:takeDamage(1)
    end
end

function SpaceDefenderState:bossAttack()
    -- Simple attack: spawn enemies around boss
    for i = 1, 3 do
        local angle = (i / 3) * math.pi * 2
        self:spawnEnemy(
            self.boss.x + math.cos(angle) * 50,
            self.boss.y,
            "straight",
            self.boss.hp / 10,  -- Minion HP based on boss HP
            150
        )
    end
end

function SpaceDefenderState:updateWaveSpawning(dt)
    if self.current_wave > #self.waves then
        -- All waves complete - spawn boss
        if not self.boss_active and #self.enemies == 0 then
            self:spawnBoss()
        end
        return
    end
    
    local wave = self.waves[self.current_wave]
    
    if self.wave_enemies_spawned < wave.enemy_count then
        self.wave_spawn_timer = self.wave_spawn_timer - dt
        
        if self.wave_spawn_timer <= 0 then
            local pattern = ({"straight", "zigzag", "sine"})[math.random(3)]
            self:spawnEnemy(
                math.random(20, love.graphics.getWidth() - 20),
                -20,
                pattern,
                wave.enemy_hp,
                wave.enemy_speed
            )
            
            self.wave_enemies_spawned = self.wave_enemies_spawned + 1
            self.wave_spawn_timer = wave.spawn_rate
        end
    elseif #self.enemies == 0 then
        -- Wave complete, move to next
        self.current_wave = self.current_wave + 1
        self.wave_enemies_spawned = 0
        self.wave_spawn_timer = 0
        print("Wave " .. (self.current_wave - 1) .. " complete!")
    end
end

function SpaceDefenderState:spawnEnemy(x, y, pattern, hp, speed)
    table.insert(self.enemies, {
        x = x,
        y = y,
        width = 30,
        height = 30,
        hp = hp,
        max_hp = hp,
        speed = speed,
        pattern = pattern,
        damaged = false  -- Track if enemy has been hit
    })
end

function SpaceDefenderState:spawnBoss()
    print("BOSS SPAWNED!")
    self.boss_active = true
    
    local boss_hp = 5000 * self.current_level
    
    self.boss = {
        x = love.graphics.getWidth() / 2,
        y = 100,
        width = 80,
        height = 80,
        hp = boss_hp,
        max_hp = boss_hp,
        vx = 100,
        attack_timer = 2.0,
        attack_rate = 2.0
    }
end

function SpaceDefenderState:takeDamage(amount)
    self.player_ship.hp = self.player_ship.hp - amount
    print("Player HP: " .. self.player_ship.hp)
end

function SpaceDefenderState:useBomb()
    if self.player_ship.bombs > 0 then
        self.player_ship.bombs = self.player_ship.bombs - 1
        self.bullet_system:clear()
        self.enemies = {}
        if self.boss then
            self.boss.hp = self.boss.hp - (self.boss.max_hp * 0.1)  -- 10% damage to boss
        end
        print("BOMB! Remaining: " .. self.player_ship.bombs)
    end
end

function SpaceDefenderState:draw()
    -- Draw player ship
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle('fill', 
        self.player_ship.x - self.player_ship.width/2,
        self.player_ship.y - self.player_ship.height/2,
        self.player_ship.width, self.player_ship.height)
    
    -- Draw enemies
    for _, enemy in ipairs(self.enemies) do
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle('fill', enemy.x - enemy.width/2, enemy.y - enemy.height/2,
            enemy.width, enemy.height)
        
        -- Draw HP bar above enemy if damaged
        if enemy.damaged then
            local bar_width = enemy.width
            local bar_height = 4
            local bar_x = enemy.x - bar_width/2
            local bar_y = enemy.y - enemy.height/2 - bar_height - 2
            
            -- Background (red)
            love.graphics.setColor(0.3, 0, 0)
            love.graphics.rectangle('fill', bar_x, bar_y, bar_width, bar_height)
            
            -- HP (green)
            love.graphics.setColor(0, 1, 0)
            local hp_percent = enemy.hp / enemy.max_hp
            love.graphics.rectangle('fill', bar_x, bar_y, bar_width * hp_percent, bar_height)
        end
    end
    
    -- Draw boss
    if self.boss_active and self.boss then
        love.graphics.setColor(0.5, 0, 0.5)
        love.graphics.rectangle('fill',
            self.boss.x - self.boss.width/2, self.boss.y - self.boss.height/2,
            self.boss.width, self.boss.height)
        
        -- Boss HP bar at top of screen
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle('fill', 50, 50, 700, 20)
        love.graphics.setColor(0, 1, 0)
        local hp_percent = self.boss.hp / self.boss.max_hp
        love.graphics.rectangle('fill', 50, 50, 700 * hp_percent, 20)
    end
    
    -- Draw bullets
    self.bullet_system:draw()
    
    -- Draw HUD
    self:drawHUD()
    
    -- Draw overlays
    if self.level_complete then
        self:drawVictoryScreen()
    elseif self.game_over then
        self:drawGameOverScreen()
    elseif self.paused then
        self:drawPauseScreen()
    end
end

function SpaceDefenderState:drawHUD()
    love.graphics.setColor(1, 1, 1)
    
    -- HP
    love.graphics.print("HP: " .. self.player_ship.hp .. "/" .. self.player_ship.max_hp, 10, 10)
    
    -- Bombs
    love.graphics.print("Bombs: " .. self.player_ship.bombs, 10, 30)
    
    -- Wave/Boss
    if self.boss_active then
        love.graphics.print("BOSS FIGHT", love.graphics.getWidth()/2 - 40, 10)
    else
        love.graphics.print("Wave: " .. self.current_wave .. "/" .. #self.waves, 
            love.graphics.getWidth()/2 - 40, 10)
    end
    
    -- Bullets active
    love.graphics.print("Bullets: " .. self.bullet_system:getBulletCount(), 
        love.graphics.getWidth() - 150, 10)
    
    -- Level
    love.graphics.print("Level: " .. self.current_level, love.graphics.getWidth() - 150, 30)
end

function SpaceDefenderState:drawVictoryScreen()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(0, 1, 0)
    love.graphics.print("LEVEL COMPLETE!", love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2 - 60, 0, 2, 2)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Tokens Earned: " .. self.tokens_earned, love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2)
    love.graphics.print("Press ENTER to continue", love.graphics.getWidth()/2 - 100, love.graphics.getHeight()/2 + 40)
end

function SpaceDefenderState:drawGameOverScreen()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(1, 0, 0)
    love.graphics.print("GAME OVER", love.graphics.getWidth()/2 - 60, love.graphics.getHeight()/2 - 60, 0, 2, 2)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Press ENTER to return to launcher", love.graphics.getWidth()/2 - 140, love.graphics.getHeight()/2 + 40)
end

function SpaceDefenderState:drawPauseScreen()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("PAUSED", love.graphics.getWidth()/2 - 40, love.graphics.getHeight()/2, 0, 2, 2)
    love.graphics.print("Press P to resume", love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2 + 40)
end

function SpaceDefenderState:keypressed(key)
    if key == 'escape' then
        game.state_machine:switch('launcher')
    elseif key == 'p' then
        self.paused = not self.paused
    elseif key == 'x' or key == 'space' then
        self:useBomb()
    elseif key == 'return' then
        if self.level_complete then
            game.state_machine:switch('launcher')
        elseif self.game_over then
            game.state_machine:switch('launcher')
        end
    end
end

function SpaceDefenderState:onLevelComplete()
    self.level_complete = true
    
    -- Calculate token reward
    local base_reward = 500
    local level_multiplier = self.current_level * 2
    self.tokens_earned = base_reward * level_multiplier
    
    -- Award tokens
    game.player_data:addTokens(self.tokens_earned)
    
    -- Unlock next level
    game.player_data:unlockLevel(self.current_level + 1)
    
    -- Save
    game.save_manager.save(game.player_data)
    
    print("Level " .. self.current_level .. " complete! Earned " .. self.tokens_earned .. " tokens")
end

function SpaceDefenderState:onLevelFailed()
    self.game_over = true
    print("Game Over!")
end

return SpaceDefenderState