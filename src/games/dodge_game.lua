local BaseGame = require('src.games.base_game')
local Config = require('src.config')
local Collision = require('src.utils.collision')
local DodgeView = require('src.games.views.dodge_view')
local DodgeGame = BaseGame:extend('DodgeGame')

-- Config-driven tunables with safe fallbacks (preserve previous behavior)
local DodgeCfg = (Config and Config.games and Config.games.dodge) or {}
local PLAYER_SIZE = (DodgeCfg.player and DodgeCfg.player.size) or 20
local PLAYER_RADIUS = PLAYER_SIZE
local PLAYER_SPEED = (DodgeCfg.player and DodgeCfg.player.speed) or 300
local OBJECT_SIZE = (DodgeCfg.objects and DodgeCfg.objects.size) or 15
local OBJECT_RADIUS = OBJECT_SIZE
local BASE_SPAWN_RATE = (DodgeCfg.objects and DodgeCfg.objects.base_spawn_rate) or 1.0
local BASE_OBJECT_SPEED = (DodgeCfg.objects and DodgeCfg.objects.base_speed) or 200
local WARNING_TIME = (DodgeCfg.objects and DodgeCfg.objects.warning_time) or 0.5
local MAX_COLLISIONS = (DodgeCfg.collisions and DodgeCfg.collisions.max) or 10
local BASE_DODGE_TARGET = DodgeCfg.base_target or 30
local MIN_SAFE_RADIUS_FRACTION = (DodgeCfg.arena and DodgeCfg.arena.min_safe_radius_fraction) or 0.35 -- of min(width,height)
local SAFE_ZONE_SHRINK_SEC = (DodgeCfg.arena and DodgeCfg.arena.safe_zone_shrink_sec) or 45 -- time to reach min radius at base difficulty
local INITIAL_SAFE_RADIUS_FRACTION = (DodgeCfg.arena and DodgeCfg.arena.initial_safe_radius_fraction) or 0.48
local TARGET_RING_MIN_SCALE = (DodgeCfg.arena and DodgeCfg.arena.target_ring and DodgeCfg.arena.target_ring.min_scale) or 1.2
local TARGET_RING_MAX_SCALE = (DodgeCfg.arena and DodgeCfg.arena.target_ring and DodgeCfg.arena.target_ring.max_scale) or 1.5

function DodgeGame:init(game_data, cheats)
    DodgeGame.super.init(self, game_data, cheats)

    local speed_modifier = self.cheats.speed_modifier or 1.0
    local advantage_modifier = self.cheats.advantage_modifier or {}
    local extra_collisions = advantage_modifier.collisions or 0

    self.OBJECT_SIZE = OBJECT_SIZE
    self.MAX_COLLISIONS = MAX_COLLISIONS + extra_collisions

    self.game_width = (DodgeCfg.arena and DodgeCfg.arena.width) or 400
    self.game_height = (DodgeCfg.arena and DodgeCfg.arena.height) or 400

    self.player = {
        x = self.game_width / 2,
        y = self.game_height / 2,
        size = PLAYER_SIZE,
        radius = PLAYER_RADIUS
    }

    self.objects = {}
    self.warnings = {}
    self.time_elapsed = 0

    self.spawn_rate = BASE_SPAWN_RATE / self.difficulty_modifiers.count
    self.object_speed = (BASE_OBJECT_SPEED * self.difficulty_modifiers.speed) * speed_modifier
    self.warning_enabled = self.difficulty_modifiers.complexity <= ((DodgeCfg.warnings and DodgeCfg.warnings.complexity_threshold) or 2)
    self.dodge_target = math.floor(BASE_DODGE_TARGET * self.difficulty_modifiers.complexity)

    self.spawn_timer = 0

    self.metrics.objects_dodged = 0
    self.metrics.collisions = 0
    self.metrics.perfect_dodges = 0

    self.view = DodgeView:new(self)
    print("[DodgeGame:init] Initialized with default game dimensions:", self.game_width, self.game_height)

    -- Safe zone (Undertale-like arena)
    local min_dim = math.min(self.game_width, self.game_height)
    local level_scale = 1 + ((DodgeCfg.drift and DodgeCfg.drift.level_scale_add_per_level) or 0.15) * math.max(0, (self.difficulty_level or 1) - 1) -- faster with clone iteration
    local drift_speed = ((DodgeCfg.drift and DodgeCfg.drift.base_speed) or 45) * level_scale -- px/sec base
    local drift_angle = math.random() * math.pi * 2
    local drift_vx = math.cos(drift_angle) * drift_speed
    local drift_vy = math.sin(drift_angle) * drift_speed
    self.safe_zone = {
        x = self.game_width / 2,
        y = self.game_height / 2,
    radius = min_dim * ((DodgeCfg.arena and DodgeCfg.arena.initial_safe_radius_fraction) or 0.48),
        min_radius = min_dim * MIN_SAFE_RADIUS_FRACTION,
    shrink_speed = (min_dim * (((DodgeCfg.arena and DodgeCfg.arena.initial_safe_radius_fraction) or 0.48) - MIN_SAFE_RADIUS_FRACTION)) / (SAFE_ZONE_SHRINK_SEC / self.difficulty_modifiers.complexity),
        vx = drift_vx,
        vy = drift_vy
    }
end

function DodgeGame:setPlayArea(width, height)
    self.game_width = width
    self.game_height = height
    
    -- Only clamp player if player exists
    if self.player then
        self.player.x = math.max(self.player.radius, math.min(self.game_width - self.player.radius, self.player.x))
        self.player.y = math.max(self.player.radius, math.min(self.game_height - self.player.radius, self.player.y))
        print("[DodgeGame] Play area updated to:", width, height)
    else
        print("[DodgeGame] setPlayArea called before init completed")
    end
end

function DodgeGame:updateGameLogic(dt)
    self.time_elapsed = self.time_elapsed + dt
    self:updateSafeZone(dt)
    self:updatePlayer(dt)

    self.spawn_timer = self.spawn_timer - dt
    if self.spawn_timer <= 0 then
        self:spawnObjectOrWarning()
        self.spawn_timer = self.spawn_rate + self.spawn_timer
    end

    self:updateWarnings(dt)
    self:updateObjects(dt)
end

function DodgeGame:draw()
    if self.view and self.view.draw then
        love.graphics.push()
        self.view:draw()
        love.graphics.pop()
    else
        love.graphics.setColor(1,0,0)
        love.graphics.print("Error: DodgeView not loaded or has no draw function.", 10, 100)
    end
end

function DodgeGame:updatePlayer(dt)
    local dx, dy = 0, 0
    if love.keyboard.isDown('left', 'a') then dx = dx - 1 end
    if love.keyboard.isDown('right', 'd') then dx = dx + 1 end
    if love.keyboard.isDown('up', 'w') then dy = dy - 1 end
    if love.keyboard.isDown('down', 's') then dy = dy + 1 end

    if dx ~= 0 and dy ~= 0 then
        local inv_sqrt2 = 0.70710678118
        dx = dx * inv_sqrt2; dy = dy * inv_sqrt2
    end

    self.player.x = self.player.x + dx * PLAYER_SPEED * dt
    self.player.y = self.player.y + dy * PLAYER_SPEED * dt

    -- Clamp to rectangular bounds first
    self.player.x = math.max(self.player.radius, math.min(self.game_width - self.player.radius, self.player.x))
    self.player.y = math.max(self.player.radius, math.min(self.game_height - self.player.radius, self.player.y))

    -- Clamp to circular safe zone
    local sz = self.safe_zone
    if sz then
        local dxp = self.player.x - sz.x
        local dyp = self.player.y - sz.y
        local dist = math.sqrt(dxp*dxp + dyp*dyp)
        local max_dist = math.max(0, sz.radius - self.player.radius)
        if dist > max_dist and dist > 0 then
            local scale = max_dist / dist
            self.player.x = sz.x + dxp * scale
            self.player.y = sz.y + dyp * scale
        end
    end
end

function DodgeGame:updateObjects(dt)
    for i = #self.objects, 1, -1 do
        local obj = self.objects[i]
        if not obj then goto continue_obj_loop end

        -- Behavior by type (all use persistent heading/velocity)
        obj.angle = obj.angle or 0
        obj.vx = obj.vx or math.cos(obj.angle) * obj.speed
        obj.vy = obj.vy or math.sin(obj.angle) * obj.speed

        if obj.type == 'seeker' then
            -- Subtle steering toward player: small max turn rate so they still fly past
            local tx, ty = self.player.x, self.player.y
            local desired = math.atan2(ty - obj.y, tx - obj.x)
            local function angdiff(a,b)
                local d = (a - b + math.pi) % (2*math.pi) - math.pi
                return d
            end
            local diff = angdiff(desired, obj.angle)
            local base_turn = math.rad(((DodgeCfg.seeker and DodgeCfg.seeker.base_turn_deg) or 6)) -- degrees/sec at baseline
            local te = self.time_elapsed or 0
            local difficulty_scaler = 1 + math.min(((DodgeCfg.seeker and DodgeCfg.seeker.difficulty and DodgeCfg.seeker.difficulty.max) or 2.0), te / ((DodgeCfg.seeker and DodgeCfg.seeker.difficulty and DodgeCfg.seeker.difficulty.time) or 90))
            local max_turn = base_turn * difficulty_scaler * dt
            if diff > max_turn then diff = max_turn elseif diff < -max_turn then diff = -max_turn end
            obj.angle = obj.angle + diff
            obj.vx = math.cos(obj.angle) * obj.speed
            obj.vy = math.sin(obj.angle) * obj.speed
        elseif obj.type == 'zigzag' or obj.type == 'sine' then
            -- Base velocity along heading with a perpendicular wobble
            local perp_x = -math.sin(obj.angle)
            local perp_y =  math.cos(obj.angle)
            local t = love.timer.getTime() * obj.wave_speed
            local wobble = math.sin(t + obj.wave_phase) * obj.wave_amp
            -- wobble is positional; convert to velocity by differentiating approx -> reduce magnitude
            local wobble_v = wobble * (((DodgeCfg.objects and DodgeCfg.objects.zigzag and DodgeCfg.objects.zigzag.wave_velocity_factor) or 2.0))
            local vx = obj.vx + perp_x * wobble_v
            local vy = obj.vy + perp_y * wobble_v
            obj.x = obj.x + vx * dt
            obj.y = obj.y + vy * dt
            goto post_move
        else
            obj.x = obj.x + obj.vx * dt
            obj.y = obj.y + obj.vy * dt
            goto post_move
        end

        -- Common position update for seeker after velocity update
        obj.x = obj.x + obj.vx * dt
        obj.y = obj.y + obj.vy * dt
        ::post_move::

        -- Mark when an object has actually entered the playable rectangle
        if not obj.entered_play then
            if obj.x > 0 and obj.x < self.game_width and obj.y > 0 and obj.y < self.game_height then
                obj.entered_play = true
            end
        end

        -- Splitter: split when entering safe zone circle (not only on hit)
        if obj.type == 'splitter' and self.safe_zone then
            local dxs = obj.x - self.safe_zone.x
            local dys = obj.y - self.safe_zone.y
            local inside = (dxs*dxs + dys*dys) <= (self.safe_zone.radius + obj.radius)^2
            if inside and not obj.was_inside then
                local shards = (DodgeCfg.objects and DodgeCfg.objects.splitter and DodgeCfg.objects.splitter.shards_count) or 3
                self:spawnShards(obj, shards)
                obj.did_split = true
                table.remove(self.objects, i)
                goto continue_obj_loop
            end
            obj.was_inside = inside
        end

        if Collision.checkCircles(self.player.x, self.player.y, self.player.radius, obj.x, obj.y, obj.radius) then
            -- Count hit, remove (splitter no longer splits here)
            table.remove(self.objects, i)
            self.metrics.collisions = self.metrics.collisions + 1
            if self.metrics.collisions >= self.MAX_COLLISIONS then self:onComplete(); return end
        elseif self:isObjectOffscreen(obj) then
            table.remove(self.objects, i)
            if obj.entered_play then
                self.metrics.objects_dodged = self.metrics.objects_dodged + 1
            end
            if obj.warned then self.metrics.perfect_dodges = self.metrics.perfect_dodges + 1 end
        end
        ::continue_obj_loop::
    end
end

function DodgeGame:updateWarnings(dt)
    for i = #self.warnings, 1, -1 do
        local warning = self.warnings[i]
        if not warning then goto continue_warn_loop end
        warning.time = warning.time - dt
        if warning.time <= 0 then
            self:createObjectFromWarning(warning)
            table.remove(self.warnings, i)
        end
         ::continue_warn_loop::
    end
end

function DodgeGame:spawnObjectOrWarning()
    -- Dynamic spawn rate scaling
    local accel = 1 + math.min(((DodgeCfg.spawn and DodgeCfg.spawn.accel and DodgeCfg.spawn.accel.max) or 2.0), self.time_elapsed / ((DodgeCfg.spawn and DodgeCfg.spawn.accel and DodgeCfg.spawn.accel.time) or 60))
    self.spawn_rate = (BASE_SPAWN_RATE / self.difficulty_modifiers.count) / accel

    if self.warning_enabled and math.random() < ((DodgeCfg.spawn and DodgeCfg.spawn.warning_chance) or 0.7) then
        table.insert(self.warnings, self:createWarning())
    else
        -- createRandomObject already inserts into self.objects
        self:createRandomObject(false)
    end
end

-- Choose a spawn point just outside the play bounds on a random edge
function DodgeGame:pickSpawnPoint()
    -- Spawn just inside the offscreen threshold so first update doesn't cull them
    local inset = ((DodgeCfg.arena and DodgeCfg.arena.spawn_inset) or 2)
    local r = OBJECT_RADIUS
    local edge = math.random(4) -- 1=left,2=right,3=top,4=bottom
    if edge == 1 then return -r + inset, math.random(0, self.game_height)
    elseif edge == 2 then return self.game_width + r - inset, math.random(0, self.game_height)
    elseif edge == 3 then return math.random(0, self.game_width), -r + inset
    else return math.random(0, self.game_width), self.game_height + r - inset end
end

-- Pick a point on a larger target ring around the safe zone
function DodgeGame:pickTargetPointOnRing()
    local sz = self.safe_zone
    local scale = TARGET_RING_MIN_SCALE + math.random() * (TARGET_RING_MAX_SCALE - TARGET_RING_MIN_SCALE)
    local r = (sz and sz.radius or math.min(self.game_width, self.game_height) * 0.4) * scale
    local a = math.random() * math.pi * 2
    local cx = sz and sz.x or self.game_width/2
    local cy = sz and sz.y or self.game_height/2
    return cx + math.cos(a) * r, cy + math.sin(a) * r
end

-- Ensure the initial heading points into the play area from the chosen edge
function DodgeGame:ensureInboundAngle(sx, sy, angle)
    local vx, vy = math.cos(angle), math.sin(angle)
    if sx <= 0 then -- left edge
        if vx <= 0 then angle = math.atan2(vy, math.abs(vx)) end
    elseif sx >= self.game_width then -- right edge
        if vx >= 0 then angle = math.atan2(vy, -math.abs(vx)) end
    elseif sy <= 0 then -- top edge
        if vy <= 0 then angle = math.atan2(math.abs(vy), vx) end
    elseif sy >= self.game_height then -- bottom edge
        if vy >= 0 then angle = math.atan2(-math.abs(vy), vx) end
    end
    return angle
end

function DodgeGame:createWarning()
    local sx, sy = self:pickSpawnPoint()
    local tx, ty = self:pickTargetPointOnRing()
    local angle = math.atan2(ty - sy, tx - sx)
    angle = self:ensureInboundAngle(sx, sy, angle)
    local warning_duration = WARNING_TIME / self.difficulty_modifiers.speed
    return { type = 'radial', sx = sx, sy = sy, angle = angle, time = warning_duration }
end

function DodgeGame:createObjectFromWarning(warning)
    self:createObject(warning.sx, warning.sy, warning.angle, true)
end

function DodgeGame:createRandomObject(warned_status)
    local sx, sy = self:pickSpawnPoint()
    local tx, ty = self:pickTargetPointOnRing()
    local angle = math.atan2(ty - sy, tx - sx)
    angle = self:ensureInboundAngle(sx, sy, angle)
    -- Choose type by weighted randomness scaling with time (Config-driven)
    local t = self.time_elapsed
    local weights = (DodgeCfg.objects and DodgeCfg.objects.weights) or {
        linear  = { base = 50, growth = 0.0 },
        zigzag  = { base = 22, growth = 0.30 },
        sine    = { base = 18, growth = 0.22 },
        seeker  = { base = 4,  growth = 0.08 },
        splitter= { base = 7,  growth = 0.18 }
    }
    local function pick(weights_cfg)
        local sum = 0
        for _, cfg in pairs(weights_cfg) do
            sum = sum + ((cfg.base or 0) + t * (cfg.growth or 0))
        end
        local r = math.random() * sum
        for k, cfg in pairs(weights_cfg) do
            r = r - ((cfg.base or 0) + t * (cfg.growth or 0))
            if r <= 0 then return k end
        end
        return 'linear'
    end
    local kind = pick(weights)
    self:createObject(sx, sy, angle, warned_status, kind)
end

function DodgeGame:createObject(spawn_x, spawn_y, angle, was_warned, kind)
    local obj = {
        warned = was_warned,
        radius = OBJECT_RADIUS,
        type = kind or 'linear',
        speed = self.object_speed * (((DodgeCfg.objects and DodgeCfg.objects.type_speed_multipliers and DodgeCfg.objects.type_speed_multipliers[kind or 'linear']) or (kind == 'seeker' and 0.9 or kind == 'splitter' and 0.8 or kind == 'zigzag' and 1.1 or kind == 'sine' and 1.0 or 1.0)))
    }
    obj.x = spawn_x
    obj.y = spawn_y
    -- Heading toward chosen target angle
    obj.angle = angle or 0
    obj.vx = math.cos(obj.angle) * obj.speed
    obj.vy = math.sin(obj.angle) * obj.speed

    if obj.type == 'zigzag' or obj.type == 'sine' then
        local zig = (DodgeCfg.objects and DodgeCfg.objects.zigzag) or { wave_speed_min = 6, wave_speed_range = 4, wave_amp = 30 }
        obj.wave_speed = (zig.wave_speed_min or 6) + math.random() * (zig.wave_speed_range or 4)
        obj.wave_amp = zig.wave_amp or 30
        obj.wave_phase = math.random()*math.pi*2
    end
    table.insert(self.objects, obj)
    return obj
end

function DodgeGame:spawnShards(parent, count)
    local n = count or (((DodgeCfg.objects and DodgeCfg.objects.splitter and DodgeCfg.objects.splitter.shards_count) or 2))
    for i=1,n do
        -- Emit shards around parent's current heading with some spread
        local spread = math.rad(((DodgeCfg.objects and DodgeCfg.objects.splitter and DodgeCfg.objects.splitter.spread_deg) or 35))
        local a = parent.angle + (math.random()*2 - 1) * spread
        local shard = {
            x = parent.x,
            y = parent.y,
            radius = math.max(((DodgeCfg.objects and DodgeCfg.objects.splitter and DodgeCfg.objects.splitter.shard_radius_min) or 6), math.floor(parent.radius * (((DodgeCfg.objects and DodgeCfg.objects.splitter and DodgeCfg.objects.splitter.shard_radius_factor) or 0.6)))) ,
            type = 'linear',
            -- about 70% slower than previous 1.2x => ~0.36x base speed
            speed = self.object_speed * (((DodgeCfg.objects and DodgeCfg.objects.splitter and DodgeCfg.objects.splitter.shard_speed_factor) or 0.36)),
            warned = false
        }
        shard.angle = a
        shard.vx = math.cos(shard.angle) * shard.speed
        shard.vy = math.sin(shard.angle) * shard.speed
        table.insert(self.objects, shard)
    end
end

function DodgeGame:isObjectOffscreen(obj)
    if not obj then return true end
    return obj.x < -obj.radius or obj.x > self.game_width + obj.radius or
           obj.y < -obj.radius or obj.y > self.game_height + obj.radius
end

function DodgeGame:updateSafeZone(dt)
    local sz = self.safe_zone
    if not sz then return end
    -- Shrink toward min radius
    if sz.radius > sz.min_radius then
        sz.radius = math.max(sz.min_radius, sz.radius - sz.shrink_speed * dt)
    end
    -- Drift and bounce (slight acceleration over time)
    local accel = 1 + math.min(((DodgeCfg.drift and DodgeCfg.drift.accel and DodgeCfg.drift.accel.max) or 1.0), (self.time_elapsed or 0) / ((DodgeCfg.drift and DodgeCfg.drift.accel and DodgeCfg.drift.accel.time) or 90))
    sz.x = sz.x + sz.vx * accel * dt
    sz.y = sz.y + sz.vy * accel * dt
    local margin = sz.radius
    if sz.x - sz.radius < 0 or sz.x + sz.radius > self.game_width then sz.vx = -sz.vx; sz.x = math.max(sz.radius, math.min(self.game_width - sz.radius, sz.x)) end
    if sz.y - sz.radius < 0 or sz.y + sz.radius > self.game_height then sz.vy = -sz.vy; sz.y = math.max(sz.radius, math.min(self.game_height - sz.radius, sz.y)) end
end

function DodgeGame:checkComplete()
    return self.metrics.collisions >= self.MAX_COLLISIONS or self.metrics.objects_dodged >= self.dodge_target
end

-- Report progress toward goal for token gating (0..1)
function DodgeGame:getCompletionRatio()
    if self.dodge_target and self.dodge_target > 0 then
        return math.min(1.0, (self.metrics.objects_dodged or 0) / self.dodge_target)
    end
    return 1.0
end

function DodgeGame:keypressed(key)
    return false
end

return DodgeGame