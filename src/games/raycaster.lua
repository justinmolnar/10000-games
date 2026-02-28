--[[
    Raycaster - First-person maze exploration

    Procedural or static mazes with Wolfenstein-style rendering.
    Generators: rotLove (dungeons/caves), static (predefined maps).
    Supports collectible dots, edge wrapping, billboards.
]]

local BaseGame = require('src.games.base_game')
local RaycasterView = require('src.games.views.raycaster_view')
local SpriteUtils = require('src.utils.game_components.sprite_utils')

local Raycaster = BaseGame:extend('Raycaster')

function Raycaster:init(game_data, cheats, di, variant_override, original_variant)
    Raycaster.super.init(self, game_data, cheats, di, variant_override, original_variant)

    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.raycaster)
    self.params = self.di.components.SchemaLoader.load(self.variant, "raycaster_schema", runtimeCfg)

    self:applyCheats({speed_modifier = {"move_speed", "turn_speed"}})
    self:loadSprites()
    self:setupComponents()
    self:generateMaze()

    -- Initialize score
    self.score = 0

    self.view = RaycasterView:new(self)
end

function Raycaster:loadSprites()
    self.sprites = {}
    local sprite_base = "assets/sprites/games/raycaster/pickups/"

    local sprite_files = {
        -- Health
        "health_food", "health_medkit", "health_dogfood", "health_blood",
        -- Ammo
        "ammo_box", "ammo_clip",
        -- Treasure
        "treasure_gold_bar", "treasure_chalice", "treasure_crown", "treasure_chest", "treasure_cross",
        -- Keys
        "key_gold", "key_silver"
    }

    for _, name in ipairs(sprite_files) do
        local path = sprite_base .. name .. ".png"
        local success, sprite = pcall(love.graphics.newImage, path)
        if success then
            self.sprites[name] = sprite
        end
    end

    -- Load guard sprites
    self:loadGuardSprites()
end

-- Load sprite, crop to content bounds, scale so largest dim = 64, bottom-align on 64x64 canvas
-- Returns {image=Image, y_offset=number} or nil
function Raycaster:loadSpriteWithBounds(path)
    local result = SpriteUtils.processSprite(path, {target_size = 64, alignment = "bottom"})
    if not result then
        local success, imageData = pcall(love.image.newImageData, path)
        if success then
            return {image = love.graphics.newImage(imageData), y_offset = 0}
        end
        return nil
    end
    return {image = result.image, y_offset = 0}
end

function Raycaster:loadGuardSprites()
    self.guard_sprites = {}
    local base = "assets/sprites/games/raycaster/guards/guard/"

    local directions = {"south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"}

    -- Load standing rotations
    self.guard_sprites.stand = {}
    for _, dir in ipairs(directions) do
        local data = self:loadSpriteWithBounds(base .. "rotations/" .. dir .. ".png")
        if data then
            self.guard_sprites.stand[dir] = data
        end
    end

    -- Load walk animations (6 frames per direction)
    self.guard_sprites.walk = {}
    for _, dir in ipairs(directions) do
        self.guard_sprites.walk[dir] = {}
        for i = 0, 5 do
            local data = self:loadSpriteWithBounds(base .. "animations/walk/" .. dir .. "/frame_00" .. i .. ".png")
            if data then
                table.insert(self.guard_sprites.walk[dir], data)
            end
        end
    end

    -- Load pain animations (4 frames per direction)
    self.guard_sprites.pain = {}
    for _, dir in ipairs(directions) do
        self.guard_sprites.pain[dir] = {}
        for i = 0, 3 do
            local data = self:loadSpriteWithBounds(base .. "animations/pain/" .. dir .. "/frame_00" .. i .. ".png")
            if data then
                table.insert(self.guard_sprites.pain[dir], data)
            end
        end
    end

    -- Load shoot animation (south only, 4 frames)
    self.guard_sprites.shoot = {}
    for i = 0, 3 do
        local data = self:loadSpriteWithBounds(base .. "animations/shoot/south/frame_00" .. i .. ".png")
        if data then
            table.insert(self.guard_sprites.shoot, data)
        end
    end

    -- Load falling/death animation (7 frames per direction)
    self.guard_sprites.fall = {}
    for _, dir in ipairs(directions) do
        self.guard_sprites.fall[dir] = {}
        for i = 0, 6 do
            local data = self:loadSpriteWithBounds(base .. "animations/falling/" .. dir .. "/frame_00" .. i .. ".png")
            if data then
                table.insert(self.guard_sprites.fall[dir], data)
            end
        end
    end

    -- Load dead/corpse animation (4 frames per direction)
    self.guard_sprites.dead = {}
    for _, dir in ipairs(directions) do
        self.guard_sprites.dead[dir] = {}
        for i = 0, 3 do
            local data = self:loadSpriteWithBounds(base .. "animations/dead/dying on ground/" .. dir .. "/frame_00" .. i .. ".png")
            if data then
                table.insert(self.guard_sprites.dead[dir], data)
            end
        end
    end

    print(string.format("[Raycaster] Loaded guard sprites: stand=%d, walk=%d dirs, pain=%d dirs, shoot=%d, fall=%d dirs, dead=%d dirs",
        self:countTable(self.guard_sprites.stand),
        self:countTable(self.guard_sprites.walk),
        self:countTable(self.guard_sprites.pain),
        #self.guard_sprites.shoot,
        self:countTable(self.guard_sprites.fall),
        self:countTable(self.guard_sprites.dead)))
end

function Raycaster:countTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Get direction name based on angle from player's view to enemy
function Raycaster:getDirectionFromAngle(enemy, player)
    -- Calculate angle from player to enemy
    local dx = enemy.x - player.x
    local dy = enemy.y - player.y
    local angle_to_enemy = math.atan2(dy, dx)

    -- Calculate relative angle (enemy facing relative to player's view)
    local enemy_facing = enemy.angle or 0
    local relative = enemy_facing - angle_to_enemy + math.pi

    -- Normalize to 0-2pi
    while relative < 0 do relative = relative + 2 * math.pi end
    while relative >= 2 * math.pi do relative = relative - 2 * math.pi end

    -- Map to 8 directions (each 45 degrees)
    local sector = math.floor((relative + math.pi / 8) / (math.pi / 4)) % 8
    local directions = {"south", "south-west", "west", "north-west", "north", "north-east", "east", "south-east"}
    return directions[sector + 1]
end

-- Get current sprite for enemy based on state and animation
function Raycaster:getEnemySprite(entity, direction)
    if not self.guard_sprites then return nil end

    local state = entity.state_machine and entity.state_machine.state or "stand"
    local anim_frame = entity.anim_frame or 0

    -- Lock direction the moment dying begins
    if state == "die" or state == "dead" or entity.is_corpse then
        if not entity.death_direction then
            entity.death_direction = direction
        end
        local dir = entity.death_direction

        -- Already finished: show frozen last frame
        if entity.death_sprite then
            return entity.death_sprite
        end

        -- Dying: play fall animation with locked direction
        if state == "die" then
            local fall = self.guard_sprites.fall[dir]
            if fall and #fall > 0 then
                local frame = math.min(math.floor(anim_frame) + 1, #fall)
                return fall[frame]
            end
        end

        -- Dead/corpse: lock the last frame of dead anim forever
        local dead = self.guard_sprites.dead[dir]
        if dead and #dead > 0 then
            entity.death_sprite = dead[#dead]
            return entity.death_sprite
        end
    end

    -- Pain
    if state == "pain" then
        local pain = self.guard_sprites.pain[direction]
        if pain and #pain > 0 then
            local frame = math.floor(anim_frame) + 1
            frame = math.min(frame, #pain)
            return pain[frame]
        end
    end

    -- Attack/shoot
    if state == "attack" then
        local shoot = self.guard_sprites.shoot
        if shoot and #shoot > 0 then
            local frame = math.floor(anim_frame) + 1
            frame = math.min(frame, #shoot)
            return shoot[frame]
        end
    end

    -- Chase/walking
    if state == "chase" then
        local walk = self.guard_sprites.walk[direction]
        if walk and #walk > 0 then
            local frame = (math.floor(anim_frame) % #walk) + 1
            return walk[frame]
        end
    end

    -- Standing (default)
    local stand = self.guard_sprites.stand[direction]
    if stand then
        return stand
    end

    return nil
end

function Raycaster:setupComponents()
    self:createComponentsFromSchema()
    self:createVictoryConditionFromSchema()

    -- Choose maze generator
    local gen = self.params.generator
    if gen == "static" then
        self.maze_generator = self.di.components.StaticMapLoader:new({
            map_name = self.params.map_name,
        })
    else
        -- All other generators use RotloveDungeon
        self.maze_generator = self.di.components.RotloveDungeon:new({
            width = self.params.maze_width,
            height = self.params.maze_height,
            generator_type = gen,
            room_width = {self.params.room_min_size or 3, self.params.room_max_size or 8},
            room_height = {self.params.room_min_size or 3, self.params.room_max_size or 6},
            room_dug_percentage = self.params.room_dug_percentage,
            time_limit = 3000,
            cell_width = self.params.cell_width,
            cell_height = self.params.cell_height,
            cellular_iterations = self.params.cellular_iterations,
            cellular_prob = self.params.cellular_prob,
            cellular_connected = self.params.cellular_connected ~= false,
            seed = self.params.map_seed
        })
    end

    -- Setup entity controller for spawned entities (enemies, pickups, etc.)
    local entity_types = {}
    for type_name, type_def in pairs(self.params.entity_types or {}) do
        entity_types[type_name] = {
            color = type_def.color or {1, 0, 0},
            height = type_def.height or 0.4,
            aspect = type_def.aspect or 1.0,
            y_offset = type_def.y_offset or 0,
            shape = type_def.shape or "diamond",
            radius = 0.3,
            health = type_def.health,
            sprite = type_def.sprite and self.sprites[type_def.sprite] or nil,
            pickup_type = type_def.pickup_type,
            pickup_value = type_def.pickup_value
        }
    end

    -- Add built-in pickup types with sprites
    local builtin_pickups = {
        -- Treasure (points)
        treasure_gold_bar = {height = 0.3, pickup_type = "treasure", pickup_value = 100, sprite = "treasure_gold_bar", color = {1, 0.85, 0}},
        treasure_chalice = {height = 0.35, pickup_type = "treasure", pickup_value = 500, sprite = "treasure_chalice", color = {1, 0.85, 0}},
        treasure_crown = {height = 0.35, pickup_type = "treasure", pickup_value = 1000, sprite = "treasure_crown", color = {1, 0.85, 0}},
        treasure_chest = {height = 0.4, pickup_type = "treasure", pickup_value = 2500, sprite = "treasure_chest", color = {0.6, 0.4, 0.2}},
        treasure_cross = {height = 0.4, pickup_type = "treasure", pickup_value = 5000, sprite = "treasure_cross", color = {1, 0.85, 0}},
        -- Health
        health_dogfood = {height = 0.25, pickup_type = "health", pickup_value = 4, sprite = "health_dogfood", color = {0.6, 0.4, 0.3}},
        health_food = {height = 0.3, pickup_type = "health", pickup_value = 10, sprite = "health_food", color = {0.8, 0.6, 0.4}},
        health_medkit = {height = 0.35, pickup_type = "health", pickup_value = 25, sprite = "health_medkit", color = {1, 1, 1}},
        health_blood = {height = 0.3, pickup_type = "health", pickup_value = 50, sprite = "health_blood", color = {0.8, 0, 0}},
        -- Ammo
        ammo_clip = {height = 0.25, pickup_type = "ammo", pickup_value = 4, sprite = "ammo_clip", color = {0.6, 0.6, 0.2}},
        ammo_box = {height = 0.3, pickup_type = "ammo", pickup_value = 10, sprite = "ammo_box", color = {0.5, 0.4, 0.2}},
        -- Keys
        key_gold = {height = 0.3, pickup_type = "key", pickup_value = 1, key_color = "gold", sprite = "key_gold", color = {1, 0.85, 0}},
        key_silver = {height = 0.3, pickup_type = "key", pickup_value = 1, key_color = "silver", sprite = "key_silver", color = {0.75, 0.75, 0.8}}
    }

    for type_name, def in pairs(builtin_pickups) do
        if not entity_types[type_name] then
            entity_types[type_name] = {
                color = def.color,
                height = def.height,
                aspect = 1.0,
                y_offset = 0,
                radius = 0.3,
                sprite = self.sprites[def.sprite],
                pickup_type = def.pickup_type,
                pickup_value = def.pickup_value,
                key_color = def.key_color
            }
        end
    end

    -- Water entity type for billboard rendering (placed before EC creation so generateMaze can spawn it)
    entity_types["water"] = {
        category = "water",
        color = {0.3, 0.7, 1.0},
        height = 0.3,
        aspect = 1.0,
        y_offset = 0,
        radius = 0.3,
        pickup_type = "water",
        movement_type = "static",
    }

    if next(entity_types) then
        self.entity_controller = self.di.components.EntityController:new({
            entity_types = entity_types,
            spawning = {mode = "manual"},
            max_entities = 200
        })
    end

    self.water_timer_spawning = false

    -- Projectile system for shooting
    if self.params.shooting_enabled then
        self:createProjectileSystemFromSchema({
            pooling = true,
            max_projectiles = 100,
            out_of_bounds_margin = 1
        })

        -- Player controller for weapons, ammo, and health
        local PlayerController = self.di.components.PlayerController
        local health_enabled = self.params.enemy_ai_enabled or false
        self.player_controller = PlayerController:new({
            mode = health_enabled and "health" or "none",
            max_health = self.params.player_health or 100,
            ammo_enabled = self.params.ammo_enabled or false,
            ammo_capacity = self.params.ammo_capacity or 99,
            auto_reload = false
        })

        -- Set starting ammo
        if self.params.ammo_enabled then
            self.player_controller.ammo = self.params.starting_ammo or 10
        end

        -- Set starting health
        if health_enabled then
            self.player_controller.health = self.params.player_health or 100
        end

        -- Add weapons: 1=knife, 2=pistol, 3=machine gun
        if self.params.knife_enabled ~= false then
            self.player_controller:addWeapon("knife", {
                uses_ammo = false,
                fire_rate = self.params.knife_fire_rate or 2,
                bullet_speed = self.params.knife_speed or 15,
                bullet_lifetime = self.params.knife_lifetime or 0.035,
                bullet_color = self.params.knife_color or {0.8, 0.8, 0.8},
                bullet_radius = 0.15
            })
        end

        self.player_controller:addWeapon("pistol", {
            uses_ammo = self.params.ammo_enabled or false,
            ammo_cost = 1,
            fire_rate = self.params.pistol_fire_rate or 1.5,
            bullet_speed = self.params.bullet_speed or 8,
            bullet_lifetime = self.params.bullet_lifetime or 3,
            bullet_color = self.params.bullet_color or {1, 1, 0},
            bullet_radius = 0.1
        })

        self.player_controller:addWeapon("machinegun", {
            uses_ammo = self.params.ammo_enabled or false,
            ammo_cost = 1,
            fire_rate = self.params.machinegun_fire_rate or 8,
            bullet_speed = self.params.machinegun_bullet_speed or 10,
            bullet_lifetime = self.params.bullet_lifetime or 3,
            bullet_color = self.params.machinegun_bullet_color or {1, 0.5, 0},
            bullet_radius = 0.08
        })

        -- Start with knife
        self.player_controller:switchWeapon("knife")
    end
end

function Raycaster:setupWaterPickup()
    if not self.water_pickup or self._water_setup_done then return end
    -- Water type already registered in setupComponents with billboard properties.
    -- Just wire up collision handlers and bounds.
    self.entity_controller.universal_handlers = self.entity_controller.universal_handlers or {}
    self.entity_controller.universal_handlers.collect_water = function(entity)
        self:onWaterCollected(entity)
        self.entity_controller:removeEntity(entity, "collected")
    end
    self.water_pickup:setBounds(0, 0, self.params.maze_width or 20, self.params.maze_height or 20)
    self._water_setup_done = true
end

function Raycaster:generateMaze()
    -- Retry generation on rotLove failures (some seeds crash uniform generator)
    local result
    for attempt = 1, 5 do
        local ok, res = pcall(self.maze_generator.generate, self.maze_generator, self.rng)
        if ok then
            result = res
            break
        else
            print(string.format("[Raycaster] Generation failed (attempt %d/5): %s", attempt, tostring(res)))
        end
    end
    if not result then
        error("[Raycaster] Map generation failed after 5 attempts")
    end

    self.map, self.map_width, self.map_height = result.map, result.width, result.height
    self.goal = {x = result.goal.x, y = result.goal.y}

    -- Always start at tile center facing cardinal direction
    local start_x = math.floor(result.start.x) + 0.5
    local start_y = math.floor(result.start.y) + 0.5
    local start_angle = math.floor((result.start.angle or 0) / (math.pi/2) + 0.5) * (math.pi/2)
    self.player = {x = start_x, y = start_y, angle = start_angle}

    if self.movement_controller then
        self.movement_controller:initSmoothState("player", self.player.angle)
    end

    -- Grid movement animation state
    self.grid_move = {active = false, start_x = 0, start_y = 0, end_x = 0, end_y = 0, progress = 0}
    self.grid_turn = {active = false, start_angle = 0, end_angle = 0, progress = 0}
    self.grid_just_pressed = {}  -- Keys pressed this frame (cleared after consumed)
    self.grid_keys_held = {}     -- Keys currently held (to filter OS key repeat)

    self.goal_reached, self.mazes_completed = 0, self.mazes_completed or 0
    self.bob_timer = 0

    -- Process markers from static maps (game decides what each character means)
    self.dots, self.power_pills, self.dots_collected, self.total_dots = {}, {}, 0, 0
    local marker_types = self.params.marker_types or {}
    local marker_doors = {}
    local marker_entities = {}

    print("[Raycaster] markers from map:", result.markers and "yes" or "no")
    for char, positions in pairs(result.markers or {}) do
        print("[Raycaster] marker char:", char, "count:", #positions, "type:", marker_types[char])
    end

    for char, positions in pairs(result.markers or {}) do
        local marker_type = marker_types[char]
        if marker_type == "dot" then
            for _, pos in ipairs(positions) do
                table.insert(self.dots, {x = pos.x, y = pos.y, collected = false})
            end
        elseif marker_type == "power" then
            for _, pos in ipairs(positions) do
                table.insert(self.power_pills, {x = pos.x, y = pos.y, collected = false})
            end
        elseif marker_type == "door" then
            for _, pos in ipairs(positions) do
                table.insert(marker_doors, {x = math.floor(pos.x), y = math.floor(pos.y)})
            end
        elseif marker_type then
            -- Treat as entity type name (e.g., "enemy", "guard", "health")
            for _, pos in ipairs(positions) do
                table.insert(marker_entities, {type = marker_type, x = pos.x, y = pos.y})
            end
        end
    end
    self.total_dots = #self.dots + #self.power_pills

    self.billboards = {}
    if self.params.victory_condition == "goal" or self.params.victory_condition == nil then
        self.goal_diamond = self.di.components.BillboardRenderer.createDiamond(
            self.goal.x + 0.5, self.goal.y + 0.5,
            {height = 0.5, aspect = 0.6, color = self.params.goal_color or {0.2, 1, 0.4}}
        )
        table.insert(self.billboards, self.goal_diamond)
    end

    -- Initialize doors from generator + map markers
    self.doors = {}
    local all_doors = {}
    for _, d in ipairs(result.doors or {}) do table.insert(all_doors, d) end
    for _, d in ipairs(marker_doors) do table.insert(all_doors, d) end

    for _, door_pos in ipairs(all_doors) do
        local slide_dir = self:getDoorSlideDirection(door_pos.x, door_pos.y)
        table.insert(self.doors, {
            x = door_pos.x,
            y = door_pos.y,
            state = "closed",
            progress = 0,
            slide_dir = slide_dir
        })
        if self.map[door_pos.y] then
            self.map[door_pos.y][door_pos.x] = 0
        end
    end

    -- Compute critical path BEFORE spawns so path_filter works
    self.critical_path = nil
    local critical_rooms = {}
    local critical_path_lookup = {}
    if self.maze_generator.computeCriticalPath then
        self.critical_path = self.maze_generator:computeCriticalPath(self.player, self.goal)
        critical_rooms = self.maze_generator.critical_rooms or {}
        if self.critical_path then
            for _, tile in ipairs(self.critical_path) do
                critical_path_lookup[math.floor(tile.x) .. "," .. math.floor(tile.y)] = true
            end
        end
    end

    -- Initialize key inventory
    self.keys = {gold = 0, silver = 0}

    -- Process procedural spawns: MapSpawnProcessor calculates positions, EntityController spawns
    if self.entity_controller then
        self.entity_controller:clear()
        local spawn_positions = self.di.components.MapSpawnProcessor.process({
            rooms = result.rooms or {},
            floor_tiles = result.floor_tiles or {},
            room_spawns = self.params.room_spawns,
            corridor_spawns = self.params.corridor_spawns,
            floor_spawns = self.params.floor_spawns,
            critical_rooms = critical_rooms,
            critical_path = critical_path_lookup,
            rng = self.rng
        })
        local water_chance = self.di and self.di.config and self.di.config.water and self.di.config.water.raycaster_replace_chance or 0.05
        for _, pos in ipairs(spawn_positions) do
            -- Resolve weighted spawn types if configured
            local spawn_type = pos.type
            local weighted = self.params.weighted_spawns and self.params.weighted_spawns[pos.type]
            if weighted then
                spawn_type = self.entity_controller:pickWeightedType(weighted)
            end
            -- Non-key pickups have a chance to become water
            local type_def = self.entity_controller.entity_types[spawn_type]
            if type_def and type_def.pickup_type and type_def.pickup_type ~= "key" and self.rng:random() < water_chance then
                spawn_type = "water"
            end
            local entity = self.entity_controller:spawn(spawn_type, pos.x, pos.y)
            self:initializeEnemy(entity)
        end
        -- Spawn entities from map markers
        for _, ent in ipairs(marker_entities) do
            local spawn_type = ent.type
            local type_def = self.entity_controller.entity_types[spawn_type]
            if type_def and type_def.pickup_type and type_def.pickup_type ~= "key" and self.rng:random() < water_chance then
                spawn_type = "water"
            end
            local entity = self.entity_controller:spawn(spawn_type, ent.x, ent.y)
            self:initializeEnemy(entity)
        end
    end

    -- Place locked doors, keys, and secret walls AFTER entity spawns
    self:placeLockedDoorsAndSecrets(critical_path_lookup)

    local entity_count = self.entity_controller and self.entity_controller:getActiveCount() or 0
    local door_count = #self.doors
    local locked_count = 0
    local secret_count = 0
    for _, door in ipairs(self.doors) do
        if door.locked then locked_count = locked_count + 1 end
        if door.secret then secret_count = secret_count + 1 end
    end
    print(string.format("[Raycaster] %dx%d maze, start=(%.1f,%.1f) goal=(%d,%d) dots=%d entities=%d doors=%d locked=%d secrets=%d",
        self.map_width, self.map_height, self.player.x, self.player.y, self.goal.x, self.goal.y, self.total_dots, entity_count, door_count, locked_count, secret_count))
end

function Raycaster:placeLockedDoorsAndSecrets(critical_path_lookup)
    local locked_count = self.params.locked_door_count or 0
    local secret_count = self.params.secret_wall_count or 0
    local key_types = self.params.locked_door_types or {"gold"}

    if (locked_count == 0 and secret_count == 0) or not self.doors or #self.doors == 0 then return end
    if not next(critical_path_lookup) then return end

    -- Build door lookup for flood fill
    local door_lookup = {}
    for _, door in ipairs(self.doors) do
        door_lookup[door.x .. "," .. door.y] = door
    end

    -- Classify doors: critical path doors vs non-critical doors
    local critical_doors = {}
    local noncritical_doors = {}
    for _, door in ipairs(self.doors) do
        local neighbors = {{0,1},{0,-1},{1,0},{-1,0}}
        local has_critical = false
        local has_noncritical = false
        for _, n in ipairs(neighbors) do
            local nx, ny = door.x + n[1], door.y + n[2]
            if self.map[ny] and self.map[ny][nx] == 0 then
                local nkey = nx .. "," .. ny
                if critical_path_lookup[nkey] then
                    has_critical = true
                else
                    has_noncritical = true
                end
            end
        end
        if has_critical and not has_noncritical then
            table.insert(critical_doors, door)
        elseif has_critical and has_noncritical then
            table.insert(noncritical_doors, door)
        elseif not has_critical then
            table.insert(noncritical_doors, door)
        end
    end

    -- Shuffle candidates
    for i = #critical_doors, 2, -1 do
        local j = math.floor(self.rng:random() * i) + 1
        critical_doors[i], critical_doors[j] = critical_doors[j], critical_doors[i]
    end
    for i = #noncritical_doors, 2, -1 do
        local j = math.floor(self.rng:random() * i) + 1
        noncritical_doors[i], noncritical_doors[j] = noncritical_doors[j], noncritical_doors[i]
    end

    -- Lock doors one at a time, verifying key is reachable each time
    local actual_locked = 0
    for i = 1, math.min(locked_count, #critical_doors) do
        local door = critical_doors[i]
        local key_type = key_types[((actual_locked) % #key_types) + 1]

        -- Tentatively lock
        door.locked = key_type

        -- Flood fill from player start, stopping at locked doors
        local reachable = self:floodFillReachable(door_lookup)

        -- Find reachable non-critical tiles for key placement
        local key_candidates = {}
        for tile_key, _ in pairs(reachable) do
            if not critical_path_lookup[tile_key] then
                local tx, ty = tile_key:match("(%d+),(%d+)")
                tx, ty = tonumber(tx), tonumber(ty)
                local dx = tx + 0.5 - self.player.x
                local dy = ty + 0.5 - self.player.y
                if dx * dx + dy * dy > 9 then
                    table.insert(key_candidates, {x = tx, y = ty})
                end
            end
        end

        if #key_candidates > 0 and self.entity_controller then
            -- Shuffle and pick one
            local idx = math.floor(self.rng:random() * #key_candidates) + 1
            local tile = key_candidates[idx]
            self.entity_controller:spawn("key_" .. key_type, tile.x + 0.5, tile.y + 0.5)
            actual_locked = actual_locked + 1
        else
            -- Can't place key reachably — unlock this door
            door.locked = nil
        end
    end

    -- Convert non-critical doors to secret walls
    local actual_secrets = 0
    for i = 1, math.min(secret_count, #noncritical_doors) do
        local door = noncritical_doors[i]
        door.secret = true
        door.state = "closed"
        door.progress = 0
        self.map[door.y][door.x] = 1
        actual_secrets = actual_secrets + 1
    end

    print(string.format("[Raycaster] Placed %d locked doors, %d keys, %d secret walls",
        actual_locked, actual_locked, actual_secrets))
end

-- Flood fill from player start, returns set of reachable "x,y" keys
-- Stops at walls and locked doors (unlocked doors are passable)
function Raycaster:floodFillReachable(door_lookup)
    local start_x = math.floor(self.player.x)
    local start_y = math.floor(self.player.y)
    local visited = {}
    local queue = {{x = start_x, y = start_y}}
    visited[start_x .. "," .. start_y] = true

    local head = 1
    while head <= #queue do
        local cur = queue[head]
        head = head + 1

        local neighbors = {{0,1},{0,-1},{1,0},{-1,0}}
        for _, n in ipairs(neighbors) do
            local nx, ny = cur.x + n[1], cur.y + n[2]
            local key = nx .. "," .. ny
            if not visited[key] and ny >= 1 and ny <= self.map_height and nx >= 1 and nx <= self.map_width then
                -- Check wall
                if self.map[ny] and self.map[ny][nx] == 0 then
                    -- Check if locked door blocks passage
                    local door = door_lookup[key]
                    if door and door.locked then
                        -- Locked door blocks flood fill
                    else
                        visited[key] = true
                        table.insert(queue, {x = nx, y = ny})
                    end
                end
            end
        end
    end

    return visited
end

-- Initialize enemy entity with state machine (any entity with health is an enemy)
function Raycaster:initializeEnemy(entity)
    if not entity or not entity.health then return end

    -- Face away from player start
    local dx = entity.x - self.player.x
    local dy = entity.y - self.player.y
    entity.angle = math.atan2(dy, dx)

    -- Animation state
    entity.anim_frame = 0
    entity.anim_speed = 8  -- frames per second
    entity.use_guard_sprites = true  -- flag to use guard sprite system

    -- Attach state machine for AI
    entity.state_machine = self.di.components.StateMachine:new({
        states = {
            stand = {duration = 0},
            chase = {duration = 0},
            attack = {duration = 30, next = "chase", interruptible = false},
            pain = {duration = 15, next = "chase", interruptible = false},
            die = {duration = 45, next = "dead", interruptible = false},
            dead = {duration = 0}
        },
        initial = "stand"
    })
end

function Raycaster:setPlayArea(width, height)
    self.viewport_width, self.viewport_height = width, height
end

function Raycaster:updateGameLogic(dt)
    if self.game_over or self.victory then return end

    self:handleInput(dt)
    self:handleShooting(dt)
    self:updateEnemyAI(dt)
    self:updateProjectiles(dt)
    self:updateDoors(dt)
    self:updateBillboards(dt)
    self:collectDots()
    self:collectPickups()
    self:checkGoal()
    self.visual_effects:update(dt)

    self.metrics.time_elapsed = self.time_elapsed
    self.metrics.mazes_completed = self.mazes_completed
    self.metrics.dots_collected = self.dots_collected
    self.metrics.enemies_killed = self.enemies_killed or 0
    self.metrics.ammo = self.player_controller and self.player_controller:getAmmo() or nil
    self.metrics.score = self.score or 0
end

function Raycaster:handleShooting(dt)
    if not self.projectile_system or not self.player_controller then return end

    -- Update weapon cooldowns
    self.player_controller:updateWeaponCooldowns(dt)

    -- Fire on space
    if self:isKeyDown('space') and self.player_controller:canFireWeapon() then
        local weapon = self.player_controller:fireWeapon()
        if weapon then
            local weapon_name = weapon.name or "pistol"
            if weapon_name == "machinegun" then
                self:playSound("machinegun_burst", 0.7)
            elseif weapon_name == "knife" then
                self:playSound("knife_slash", 0.7)
            else
                self:playSound("pistol_fire", 0.7)
            end
            local angle = self.player.angle
            local speed = weapon.bullet_speed or 8
            self.projectile_system:spawn({
                x = self.player.x,
                y = self.player.y,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed,
                team = "player",
                lifetime = weapon.bullet_lifetime or 3,
                radius = weapon.bullet_radius or 0.1,
                color = weapon.bullet_color or {1, 1, 0},
                -- Store origin for distance-based damage
                origin_x = self.player.x,
                origin_y = self.player.y
            })
            -- Alert enemies via sound
            self.player_fired = true
        end
    end
end

-- Calculate bullet damage (Wolf3D style: distance-based with ∞-norm)
function Raycaster:calculateBulletDamage(bullet, target_x, target_y, is_sneak)
    local mode = self.params.player_damage_mode or "origin"

    -- Fixed damage mode
    if mode == "fixed" then
        local damage = self.params.player_bullet_damage or 15
        return is_sneak and damage * 2 or damage
    end

    -- Calculate distance based on mode
    local from_x, from_y
    if mode == "origin" and bullet.origin_x then
        from_x, from_y = bullet.origin_x, bullet.origin_y
    else
        -- "player" mode or fallback
        from_x, from_y = self.player.x, self.player.y
    end

    -- Wolf3D uses ∞-norm (max of x/y tile distance)
    local dx = math.abs(target_x - from_x)
    local dy = math.abs(target_y - from_y)
    local dist = math.max(dx, dy)

    local random = self.rng:random(0, 255)
    local damage

    if dist < 2 then
        damage = math.floor(random / 4)   -- 0-63
    elseif dist < 4 then
        damage = math.floor(random / 6)   -- 0-42
    else
        -- Chance to miss at long range
        if math.floor(random / 12) < dist then
            damage = 0  -- Miss
        else
            damage = math.floor(random / 6)  -- 0-42
        end
    end

    -- Sneak attack: 2x damage if enemy hasn't seen player yet
    if is_sneak then
        damage = damage * 2
    end

    return damage
end

-- Enemy AI: check line of sight and shoot at player
function Raycaster:updateEnemyAI(dt)
    if not self.entity_controller then return end

    local enemy_sight_range = self.params.enemy_sight_range or 15
    local enemy_move_speed = self.params.enemy_move_speed or 1
    local enemy_fire_rate = self.params.enemy_fire_rate or 0.5

    -- Calculate sound reachable tiles once per frame (only when player fired)
    local sound_tiles = nil
    if self.player_fired then
        sound_tiles = self:getSoundReachableTiles()
    end

    for _, entity in ipairs(self.entity_controller:getEntities()) do
        -- Any entity with a state machine is an AI enemy
        if entity.state_machine then

            -- Update state machine timing (convert dt to tics at 60fps)
            entity.state_machine:update(dt * 60)

            -- Update animation frames
            local state = entity.state_machine.state
            local anim_speed = entity.anim_speed or 8

            if state == "pain" then
                -- Pain: play through 4 frames during pain duration
                entity.anim_frame = (entity.anim_frame or 0) + dt * anim_speed
                if entity.anim_frame > 3 then entity.anim_frame = 3 end
            elseif state == "die" then
                -- Die/fall: play through 7 frames
                entity.anim_frame = (entity.anim_frame or 0) + dt * anim_speed
                if entity.anim_frame > 6 then entity.anim_frame = 6 end
            elseif state == "attack" then
                -- Attack: play through 4 frames
                entity.anim_frame = (entity.anim_frame or 0) + dt * anim_speed
                if entity.anim_frame > 3 then entity.anim_frame = 3 end
            elseif state == "chase" then
                -- Walk: loop through 6 frames
                entity.anim_frame = (entity.anim_frame or 0) + dt * anim_speed
            elseif state == "dead" then
                -- Dead: stay on last frame
                entity.anim_frame = 6
            else
                -- Stand: no animation
                entity.anim_frame = 0
            end

            local dx = self.player.x - entity.x
            local dy = self.player.y - entity.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local can_see = self:hasLineOfSight(entity.x, entity.y, self.player.x, self.player.y)

            -- Attack state: stop moving, wait for animation to finish
            if state == "attack" then
                -- Face player while attacking
                entity.angle = math.atan2(dy, dx)
                goto continue
            end

            -- Pain state: stagger, can't move or attack, auto-returns to chase
            if state == "pain" then
                -- Clear movement target so they re-evaluate after pain
                entity.target_x = nil
                entity.target_y = nil
                goto continue
            end

            -- Die state: falling animation
            if state == "die" then
                entity.die_progress = (entity.die_progress or 0) + dt * 2
                if entity.die_progress > 1 then entity.die_progress = 1 end
                goto continue
            end

            -- Dead state: corpse on ground, do nothing
            if state == "dead" then
                entity.is_corpse = true
                goto continue
            end

            -- Chase movement (when already in chase)
            if entity.state_machine.state == "chase" then
                self:updateGuardChase(entity, dt, enemy_move_speed, can_see, enemy_fire_rate)
                goto continue
            end

            -- Below here: detecting player to ENTER chase
            local angle_to_player = math.atan2(dy, dx)

            -- Sound alert: player fired and sound can reach enemy (propagates through open doors)
            if self.player_fired and sound_tiles then
                local enemy_tile = math.floor(entity.x) .. "," .. math.floor(entity.y)
                if sound_tiles[enemy_tile] then
                    self:enterChase(entity)
                    goto continue
                end
            end

            -- Bump alert: player walks into enemy
            if dist < 1 then
                self:enterChase(entity)
                goto continue
            end

            -- Sight check: distance, direction facing, line of sight
            if dist < enemy_sight_range then
                local facing = true
                if entity.angle then
                    local angle_diff = math.abs(angle_to_player - entity.angle)
                    if angle_diff > math.pi then angle_diff = 2 * math.pi - angle_diff end
                    facing = angle_diff < math.pi / 2
                end

                if facing and can_see then
                    self:enterChase(entity)
                end
            end

            ::continue::
        end
    end

    -- Clear player_fired flag at end of frame
    self.player_fired = false
end

-- Check if player and enemies are in connected areas (any open door = connected)
-- Enter chase state with speed boost
function Raycaster:enterChase(entity)
    if entity.state_machine.state == "chase" then return end
    entity.state_machine:setState("chase")
    self:playSound("enemy_alert", 0.6)
    -- Speed boost on first sight (Wolf3D does 2-5x depending on enemy type)
    entity.chase_speed_mult = 2 + self.rng:random() * 1.5  -- 2x to 3.5x
end

-- Enter attack state: stop, fire projectile, then return to chase
function Raycaster:enterAttack(entity)
    if entity.state_machine.state == "attack" then return end
    entity.state_machine:setState("attack")
    entity.anim_frame = 0  -- Reset animation

    -- Fire projectile at player
    if self.projectile_system then
        local dx = self.player.x - entity.x
        local dy = self.player.y - entity.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist > 0.1 then
            -- Normalize direction
            local dir_x = dx / dist
            local dir_y = dy / dist

            -- Apply accuracy spread
            local accuracy = self.params.enemy_accuracy or 0.7
            local spread = (1 - accuracy) * math.pi / 4  -- Max 45 degree spread at 0 accuracy
            local angle = math.atan2(dir_y, dir_x) + (self.rng:random() * 2 - 1) * spread

            local bullet_speed = self.params.enemy_bullet_speed or 5
            self.projectile_system:spawn({
                x = entity.x,
                y = entity.y,
                vx = math.cos(angle) * bullet_speed,
                vy = math.sin(angle) * bullet_speed,
                team = "enemy",
                lifetime = 5,
                radius = 0.1,
                color = self.params.enemy_bullet_color or {1, 0.3, 0.3}
            })
        end
    end
end

-- Flood fill to find all tiles reachable by sound from player position
-- Sound propagates through floor tiles and open doors, blocked by walls and closed doors
function Raycaster:getSoundReachableTiles()
    local reachable = {}
    local queue = {}
    local start_x, start_y = math.floor(self.player.x), math.floor(self.player.y)

    table.insert(queue, {x = start_x, y = start_y})
    reachable[start_x .. "," .. start_y] = true

    while #queue > 0 do
        local current = table.remove(queue, 1)
        local cx, cy = current.x, current.y

        -- Check 4 neighbors
        local neighbors = {{cx-1, cy}, {cx+1, cy}, {cx, cy-1}, {cx, cy+1}}
        for _, n in ipairs(neighbors) do
            local nx, ny = n[1], n[2]
            local key = nx .. "," .. ny

            if not reachable[key] then
                -- Check bounds
                if nx >= 1 and nx <= self.map_width and ny >= 1 and ny <= self.map_height then
                    local is_wall = self.map[ny] and self.map[ny][nx] == 1

                    -- Check if door blocks sound
                    local door_blocks = false
                    if self.doors then
                        for _, door in ipairs(self.doors) do
                            if door.x == nx and door.y == ny then
                                -- Closed doors block sound
                                door_blocks = door.progress < 0.5
                                break
                            end
                        end
                    end

                    if not is_wall and not door_blocks then
                        reachable[key] = true
                        table.insert(queue, {x = nx, y = ny})
                    end
                end
            end
        end
    end

    return reachable
end

-- Guard chase movement: tile-based pathfinding toward player
function Raycaster:updateGuardChase(entity, dt, move_speed, can_see, fire_rate)
    -- Decay speed boost over time back to 1.0
    if entity.chase_speed_mult and entity.chase_speed_mult > 1 then
        entity.chase_speed_mult = entity.chase_speed_mult - dt * 0.5
        if entity.chase_speed_mult < 1 then entity.chase_speed_mult = 1 end
    end

    -- Attack when can see player (with fire rate cooldown)
    if can_see and self.params.enemy_ai_enabled then
        entity.fire_cooldown = (entity.fire_cooldown or 0) - dt
        if entity.fire_cooldown <= 0 then
            self:enterAttack(entity)
            entity.fire_cooldown = 1 / fire_rate
            return  -- Don't move this frame, we're attacking
        end
    end

    -- Apply speed boost multiplier
    local speed = move_speed * (entity.chase_speed_mult or 1)

    -- Check if we need a new target tile
    local need_new_target = false
    if not entity.target_x or not entity.target_y then
        need_new_target = true
    else
        -- Check if reached target
        local dist_to_target = math.abs(entity.x - entity.target_x) + math.abs(entity.y - entity.target_y)
        if dist_to_target < 0.1 then
            need_new_target = true
        end
    end

    -- Pick new target tile
    if need_new_target then
        local dx = self.player.x - entity.x
        local dy = self.player.y - entity.y

        -- Determine direction toward player
        local dir_x = 0
        local dir_y = 0
        if math.abs(dx) > 0.3 then dir_x = dx > 0 and 1 or -1 end
        if math.abs(dy) > 0.3 then dir_y = dy > 0 and 1 or -1 end

        -- Zigzag when can see player (dodge behavior)
        if can_see and self.rng:random() < 0.3 then
            -- Randomly pick just horizontal or vertical movement
            if self.rng:random() < 0.5 then
                dir_x = 0
            else
                dir_y = 0
            end
        end

        -- Calculate target tile center
        local current_tile_x = math.floor(entity.x)
        local current_tile_y = math.floor(entity.y)
        local target_tile_x = current_tile_x + dir_x
        local target_tile_y = current_tile_y + dir_y

        -- Try to open door if one is blocking the way
        self:tryOpenDoorAt(target_tile_x, target_tile_y)

        -- Check if target tile is walkable (doors might be opening now)
        if self:isTileWalkable(target_tile_x, target_tile_y) then
            entity.target_x = target_tile_x + 0.5
            entity.target_y = target_tile_y + 0.5
        else
            -- Try horizontal only
            self:tryOpenDoorAt(current_tile_x + dir_x, current_tile_y)
            if dir_x ~= 0 and self:isTileWalkable(current_tile_x + dir_x, current_tile_y) then
                entity.target_x = current_tile_x + dir_x + 0.5
                entity.target_y = current_tile_y + 0.5
            else
                -- Try vertical only
                self:tryOpenDoorAt(current_tile_x, current_tile_y + dir_y)
                if dir_y ~= 0 and self:isTileWalkable(current_tile_x, current_tile_y + dir_y) then
                    entity.target_x = current_tile_x + 0.5
                    entity.target_y = current_tile_y + dir_y + 0.5
                else
                    -- Stuck, stay in place
                    entity.target_x = entity.x
                    entity.target_y = entity.y
                end
            end
        end
    end

    -- Move toward target
    local dx = entity.target_x - entity.x
    local dy = entity.target_y - entity.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 0.05 then
        local move_dist = speed * dt
        if move_dist > dist then move_dist = dist end
        entity.x = entity.x + (dx / dist) * move_dist
        entity.y = entity.y + (dy / dist) * move_dist
        -- Update facing angle
        entity.angle = math.atan2(dy, dx)
    end
end

-- Try to open a door at the given tile
function Raycaster:tryOpenDoorAt(tile_x, tile_y)
    if not self.doors then return end
    for _, door in ipairs(self.doors) do
        if door.x == tile_x and door.y == tile_y and door.state == "closed"
           and not door.locked and not door.secret then
            door.state = "opening"
        end
    end
end

function Raycaster:tryOpenSecretWall(tile_x, tile_y)
    if not self.doors then return end
    for _, door in ipairs(self.doors) do
        if door.x == tile_x and door.y == tile_y and door.secret and door.state == "closed" then
            door.state = "opening"
            self.visual_effects:flash({color = {0.5, 0.5, 0.5, 0.3}, duration = 0.3, mode = "fade_out"})
        end
    end
end

-- Check if a tile is walkable (not a wall, not blocked by closed door)
function Raycaster:isTileWalkable(tile_x, tile_y)
    -- Check bounds
    if tile_x < 1 or tile_y < 1 or tile_x > self.map_width or tile_y > self.map_height then
        return false
    end
    -- Check wall
    if self.map[tile_y] and self.map[tile_y][tile_x] == 1 then
        return false
    end
    -- Check closed door
    if self:isDoorBlocking(tile_x + 0.5, tile_y + 0.5) then
        return false
    end
    return true
end

-- Check if there's clear line of sight between two points
function Raycaster:hasLineOfSight(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 0.1 then return true end

    -- Step along the line and check for walls/doors
    local steps = math.ceil(dist * 4)  -- 4 checks per tile
    local step_x = dx / steps
    local step_y = dy / steps

    for i = 1, steps - 1 do
        local check_x = x1 + step_x * i
        local check_y = y1 + step_y * i
        local tile_x = math.floor(check_x)
        local tile_y = math.floor(check_y)

        -- Check wall
        if self.map[tile_y] and self.map[tile_y][tile_x] == 1 then
            return false
        end

        -- Check door
        if self:isDoorBlocking(check_x, check_y) then
            return false
        end
    end

    return true
end

function Raycaster:updateProjectiles(dt)
    if not self.projectile_system then return end

    local PhysicsUtils = self.di.components.PhysicsUtils

    -- Let ProjectileSystem handle movement, lifetime, bounds
    self.projectile_system:update(dt, {
        x_min = 0, x_max = self.map_width,
        y_min = 0, y_max = self.map_height
    })

    -- Check wall and door collisions (remove bullets that hit obstacles)
    for _, bullet in ipairs(self.projectile_system:getAll()) do
        local tile_x, tile_y = math.floor(bullet.x), math.floor(bullet.y)
        local hit_wall = not PhysicsUtils.isTileWalkable(self.map, tile_x, tile_y, self.map_width, self.map_height)
        local hit_door = self:isDoorBlocking(bullet.x, bullet.y)
        if hit_wall or hit_door then
            self.projectile_system:remove(bullet)
        end
    end

    -- Check entity collisions (player bullets hitting enemies only)
    if self.entity_controller then
        for _, bullet in ipairs(self.projectile_system:getByTeam("player")) do
            for _, entity in ipairs(self.entity_controller:getEntities()) do
                -- Any entity with health is damageable (not pickups), skip dead/dying
                local is_enemy = entity.health ~= nil or entity.state_machine ~= nil
                local is_alive = not entity.is_corpse and not entity.die_progress
                if is_enemy and is_alive then
                    local dx = bullet.x - entity.x
                    local dy = bullet.y - entity.y
                    local dist2 = dx * dx + dy * dy
                    local hit_radius = (bullet.radius or 0.1) + (entity.radius or 0.3)

                    if dist2 < hit_radius * hit_radius then
                        self.projectile_system:remove(bullet)

                        -- Calculate damage (sneak attack if enemy in "stand" state)
                        local is_sneak = entity.state_machine and entity.state_machine.state == "stand"
                        local damage = self:calculateBulletDamage(bullet, entity.x, entity.y, is_sneak)

                        if damage > 0 then
                            -- Apply damage manually (don't use hitEntity since we handle death differently)
                            entity.health = (entity.health or 25) - damage

                            if entity.health <= 0 then
                                -- Enter die state instead of removing
                                if entity.state_machine then
                                    entity.state_machine:forceState("die")
                                    entity.die_progress = 0  -- For fall animation
                                    entity.anim_frame = 0    -- Reset animation
                                end
                                self.enemies_killed = (self.enemies_killed or 0) + 1
                                self:playSound("enemy_death", 0.8)
                                self.visual_effects:flash({color = {1, 0.5, 0, 0.3}, duration = 0.1, mode = "fade_out"})
                            else
                                -- Enter pain state (interrupts current action)
                                if entity.state_machine then
                                    entity.state_machine:forceState("pain")
                                    entity.anim_frame = 0  -- Reset animation
                                end
                                self:playSound("enemy_hit", 0.6)
                                self.visual_effects:flash({color = {1, 0.8, 0, 0.2}, duration = 0.05, mode = "fade_out"})
                            end
                        end
                        break
                    end
                end
            end
        end
    end

    -- Check player collision (enemy bullets hitting player)
    if self.player_controller then
        local player_radius = 0.3
        for _, bullet in ipairs(self.projectile_system:getByTeam("enemy")) do
            local dx = bullet.x - self.player.x
            local dy = bullet.y - self.player.y
            local dist2 = dx * dx + dy * dy
            local hit_radius = (bullet.radius or 0.1) + player_radius

            if dist2 < hit_radius * hit_radius then
                self.projectile_system:remove(bullet)

                -- Damage player (random range)
                local min_dmg = self.params.enemy_bullet_damage_min or 5
                local max_dmg = self.params.enemy_bullet_damage_max or 10
                local damage = self.rng:random(min_dmg, max_dmg)
                self.player_controller:takeDamage(damage)
                self:playSound("hit", 0.8)

                -- Visual feedback
                self.visual_effects:flash({color = {1, 0, 0, 0.4}, duration = 0.15, mode = "fade_out"})

                -- Check if player died
                if self.player_controller.is_dead then
                    self.game_over = true
                end
            end
        end
    end
end

function Raycaster:handleInput(dt)
    if self.params.movement_mode == "grid" then
        self:handleGridInput(dt)
    else
        self:handleSmoothInput(dt)
    end
end

function Raycaster:handleSmoothInput(dt)
    -- Ensure smooth state exists (might be missing if movement_controller was recreated)
    if not self.movement_controller:getSmoothState("player") then
        self.movement_controller:initSmoothState("player", self.player.angle)
    end

    -- Set turn flags
    local left, right = self:isKeyDown('left', 'a'), self:isKeyDown('right', 'd')
    self.movement_controller:setSmoothTurn("player", left, right)

    -- Set movement flags
    local forward = self:isKeyDown('up', 'w')
    local backward = self:isKeyDown('down', 's')
    local strafe_left = self:isKeyDown('q')
    local strafe_right = self:isKeyDown('e')
    self.movement_controller:setSmoothMovement("player", forward, backward, strafe_left, strafe_right)

    -- Get movement delta from MovementController
    local dx, dy = self.movement_controller:updateSmooth(dt, "player", self.params.move_speed, self.params.turn_speed)
    self.player.angle = self.movement_controller:getSmoothAngle("player")

    -- Apply with tile collision
    local wrap = self.params.enable_edge_wrap
    local new_x, new_y = self.di.components.PhysicsUtils.moveWithTileCollision(
        self.player.x, self.player.y, dx, dy,
        self.map, self.map_width, self.map_height, wrap, wrap
    )

    -- Check for secret wall bumps (player walking into a wall)
    if dx ~= 0 or dy ~= 0 then
        local ahead_x = math.floor(self.player.x + math.cos(self.player.angle) * 1.2)
        local ahead_y = math.floor(self.player.y + math.sin(self.player.angle) * 1.2)
        self:tryOpenSecretWall(ahead_x, ahead_y)
    end

    -- Additional door collision check
    if not self:isDoorBlocking(new_x, new_y) then
        self.player.x, self.player.y = new_x, new_y
    else
        -- Try sliding along walls (check x and y separately)
        local test_x, _ = self.di.components.PhysicsUtils.moveWithTileCollision(
            self.player.x, self.player.y, dx, 0,
            self.map, self.map_width, self.map_height, wrap, wrap
        )
        local _, test_y = self.di.components.PhysicsUtils.moveWithTileCollision(
            self.player.x, self.player.y, 0, dy,
            self.map, self.map_width, self.map_height, wrap, wrap
        )
        if not self:isDoorBlocking(test_x, self.player.y) then
            self.player.x = test_x
        end
        if not self:isDoorBlocking(self.player.x, test_y) then
            self.player.y = test_y
        end
    end
end

function Raycaster:handleGridInput(dt)
    local PhysicsUtils = self.di.components.PhysicsUtils

    -- Update move animation
    if self.grid_move.active then
        self.grid_move.progress = self.grid_move.progress + dt / self.params.grid_move_time
        if self.grid_move.progress >= 1 then
            self.player.x = self.grid_move.end_x
            self.player.y = self.grid_move.end_y
            self.grid_move.active = false
        else
            local t = self.grid_move.progress
            self.player.x = self.grid_move.start_x + (self.grid_move.end_x - self.grid_move.start_x) * t
            self.player.y = self.grid_move.start_y + (self.grid_move.end_y - self.grid_move.start_y) * t
        end
        return  -- No input while moving
    end

    -- Update turn animation
    if self.grid_turn.active then
        self.grid_turn.progress = self.grid_turn.progress + dt / self.params.grid_turn_time
        if self.grid_turn.progress >= 1 then
            self.player.angle = self.grid_turn.end_angle
            self.grid_turn.active = false
        else
            local t = self.grid_turn.progress
            self.player.angle = self.grid_turn.start_angle + (self.grid_turn.end_angle - self.grid_turn.start_angle) * t
        end
        return  -- No input while turning
    end

    -- Helper to check input (just pressed or held depending on mode)
    local function checkInput(...)
        local keys = {...}
        if self.params.grid_hold_to_move then
            return self:isKeyDown(...)
        else
            for _, key in ipairs(keys) do
                if self.grid_just_pressed[key] then
                    return true
                end
            end
            return false
        end
    end

    -- Handle turn input (90-degree increments)
    if checkInput('left', 'a') then
        self.grid_turn.active = true
        self.grid_turn.start_angle = self.player.angle
        self.grid_turn.end_angle = self.player.angle - math.pi / 2
        self.grid_turn.progress = 0
        self.grid_just_pressed = {}
        return
    elseif checkInput('right', 'd') then
        self.grid_turn.active = true
        self.grid_turn.start_angle = self.player.angle
        self.grid_turn.end_angle = self.player.angle + math.pi / 2
        self.grid_turn.progress = 0
        self.grid_just_pressed = {}
        return
    end

    -- Handle move input (one tile at a time)
    local dx, dy = 0, 0
    if checkInput('up', 'w') then
        dx, dy = math.cos(self.player.angle), math.sin(self.player.angle)
    elseif checkInput('down', 's') then
        dx, dy = -math.cos(self.player.angle), -math.sin(self.player.angle)
    elseif checkInput('q') then
        local a = self.player.angle - math.pi / 2
        dx, dy = math.cos(a), math.sin(a)
    elseif checkInput('e') then
        local a = self.player.angle + math.pi / 2
        dx, dy = math.cos(a), math.sin(a)
    end

    if dx ~= 0 or dy ~= 0 then
        -- Calculate target tile center
        local target_x = self.player.x + (dx > 0.5 and 1 or (dx < -0.5 and -1 or 0))
        local target_y = self.player.y + (dy > 0.5 and 1 or (dy < -0.5 and -1 or 0))
        local tile_x, tile_y = math.floor(target_x), math.floor(target_y)

        -- Check if walkable (map tile AND door not blocking)
        local walkable = PhysicsUtils.isTileWalkable(self.map, tile_x, tile_y, self.map_width, self.map_height)
        local door_blocked = self:isDoorBlocking(tile_x + 0.5, tile_y + 0.5)

        if walkable and not door_blocked then
            self.grid_move.active = true
            self.grid_move.start_x = self.player.x
            self.grid_move.start_y = self.player.y
            self.grid_move.end_x = tile_x + 0.5
            self.grid_move.end_y = tile_y + 0.5
            self.grid_move.progress = 0
        end
    end

    -- Clear just_pressed flags after processing
    self.grid_just_pressed = {}
end

function Raycaster:updateBillboards(dt)
    self.bob_timer = self.bob_timer + dt * 3
    if self.goal_diamond then
        self.goal_diamond.y_offset = math.sin(self.bob_timer) * 0.15
    end

    self.billboards = {}
    if self.goal_diamond then table.insert(self.billboards, self.goal_diamond) end

    for _, dot in ipairs(self.dots) do
        if not dot.collected then
            table.insert(self.billboards, {x = dot.x, y = dot.y, height = 0.15, aspect = 1.0, y_offset = 0, color = {1, 1, 0.6}})
        end
    end

    local pulse = 0.8 + math.sin(self.bob_timer * 2) * 0.2
    for _, pill in ipairs(self.power_pills) do
        if not pill.collected then
            table.insert(self.billboards, {x = pill.x, y = pill.y, height = 0.3 * pulse, aspect = 1.0, y_offset = 0, color = {1, 0.9, 0.3}})
        end
    end

    -- Add spawned entities to billboards (from EntityController)
    -- EntityController copies type properties directly to entities
    if self.entity_controller then
        local BillboardRenderer = self.di.components.BillboardRenderer
        for _, entity in ipairs(self.entity_controller:getEntities()) do
            local is_pickup = entity.pickup_type ~= nil
            local is_enemy = entity.health ~= nil or entity.state_machine ~= nil

            -- Pickups: no bobbing, sit on floor
            local bob = 0

            local height = entity.height or 0.4
            local aspect = entity.aspect or 1.0
            local y_offset = entity.y_offset or 0
            local color = entity.color or {1, 0, 0}
            local sprite = entity.sprite

            -- Pickups sit on floor
            if is_pickup then
                y_offset = -0.5 + height / 2
            end

            -- Guard sprite system for enemies
            if entity.use_guard_sprites and self.guard_sprites then
                local direction = self:getDirectionFromAngle(entity, self.player)
                local guard_data = self:getEnemySprite(entity, direction)

                if guard_data then
                    local state = entity.state_machine and entity.state_machine.state or "stand"

                    local guard_color = {1, 1, 1}
                    if state == "dead" or entity.is_corpse then
                        guard_color = {0.6, 0.6, 0.6}
                    end

                    -- Per-sprite y_offset computed from content bounds at load time
                    local billboard = BillboardRenderer.createSprite(entity.x, entity.y, {
                        sprite = guard_data.image,
                        height = 1.0,
                        aspect = 1.0,
                        y_offset = guard_data.y_offset,
                        color = guard_color
                    })
                    billboard.entity_ref = entity
                    table.insert(self.billboards, billboard)
                    goto next_entity
                end
            end

            -- Non-guard enemies: bob up and down
            if is_enemy and not is_pickup then
                local bob_phase = entity.bob_offset or (entity.x * 7 + entity.y * 13)
                bob = math.sin(self.bob_timer + bob_phase) * 0.1
                y_offset = y_offset + bob
            end

            -- Dying: fall over animation (for non-sprite enemies)
            if entity.die_progress then
                local progress = entity.die_progress
                height = height * (1 - progress * 0.8)
                aspect = aspect * (1 + progress * 2)
                y_offset = -0.4 * progress
            end

            -- Dead: flat on ground (for non-sprite enemies)
            if entity.is_corpse then
                height = (entity.height or 0.4) * 0.15
                aspect = (entity.aspect or 1.0) * 3
                y_offset = -0.45
                color = {color[1] * 0.5, color[2] * 0.5, color[3] * 0.5}
            end

            -- Use sprite billboard if sprite available, otherwise color
            if sprite and BillboardRenderer then
                local billboard = BillboardRenderer.createSprite(entity.x, entity.y, {
                    sprite = sprite,
                    height = height,
                    aspect = aspect,
                    y_offset = y_offset,
                    color = color
                })
                billboard.entity_ref = entity
                table.insert(self.billboards, billboard)
            else
                table.insert(self.billboards, {
                    x = entity.x,
                    y = entity.y,
                    height = height,
                    aspect = aspect,
                    y_offset = y_offset,
                    color = color,
                    entity_ref = entity
                })
            end

            ::next_entity::
        end
    end

    -- Add projectiles to billboards
    if self.projectile_system then
        for _, bullet in ipairs(self.projectile_system:getAll()) do
            table.insert(self.billboards, {
                x = bullet.x,
                y = bullet.y,
                height = 0.1,
                aspect = 1.0,
                y_offset = 0,
                color = bullet.color or {1, 1, 0}
            })
        end
    end
end

function Raycaster:collectDots()
    local px, py, r2 = self.player.x, self.player.y, 0.16

    for _, dot in ipairs(self.dots) do
        if not dot.collected and (px - dot.x)^2 + (py - dot.y)^2 < r2 then
            dot.collected, self.dots_collected = true, self.dots_collected + 1
        end
    end

    for _, pill in ipairs(self.power_pills) do
        if not pill.collected and (px - pill.x)^2 + (py - pill.y)^2 < r2 then
            pill.collected, self.dots_collected = true, self.dots_collected + 1
        end
    end
end

function Raycaster:collectPickups()
    if not self.entity_controller then return end

    local px, py = self.player.x, self.player.y
    local pickup_radius = 0.5

    for _, entity in ipairs(self.entity_controller:getEntities()) do
        -- Skip enemies (anything with health or state machine)
        if entity.health or entity.state_machine then
            goto continue
        end

        local dx, dy = px - entity.x, py - entity.y
        local dist2 = dx * dx + dy * dy

        if dist2 < pickup_radius * pickup_radius then
            local pickup_type = entity.pickup_type
            local pickup_value = entity.pickup_value or 0

            if pickup_type == "treasure" then
                -- Treasure gives points
                self.score = (self.score or 0) + pickup_value
                self.entity_controller:removeEntity(entity)
                self:playSound("treasure_collect", 0.8)
                self.visual_effects:flash({color = {1, 0.85, 0, 0.3}, duration = 0.1, mode = "fade_out"})

            elseif pickup_type == "health" and self.player_controller then
                -- Health pickup
                local current = self.player_controller.health or 100
                local max = self.player_controller.max_health or 100
                if current < max then
                    self.player_controller.health = math.min(max, current + pickup_value)
                    self.entity_controller:removeEntity(entity)
                    self:playSound("health_collect", 0.7)
                    self.visual_effects:flash({color = {0.2, 1, 0.3, 0.3}, duration = 0.15, mode = "fade_out"})
                end

            elseif pickup_type == "ammo" and self.player_controller then
                -- Ammo pickup
                self.player_controller:addAmmo(pickup_value)
                self.entity_controller:removeEntity(entity)
                self:playSound("ammo_collect", 0.7)
                self.visual_effects:flash({color = {0.5, 0.5, 1, 0.3}, duration = 0.15, mode = "fade_out"})

            elseif pickup_type == "key" then
                -- Key pickup
                local key_type = entity.key_color or "gold"
                self.keys[key_type] = (self.keys[key_type] or 0) + 1
                self.entity_controller:removeEntity(entity)
                self:playSound("key_collect", 0.8)
                local flash_color = key_type == "gold" and {1, 0.85, 0, 0.4} or {0.75, 0.75, 0.8, 0.4}
                self.visual_effects:flash({color = flash_color, duration = 0.2, mode = "fade_out"})

            elseif entity.category == "water" then
                self:onWaterCollected(entity)
                self.entity_controller:removeEntity(entity, "collected")
            end
        end

        ::continue::
    end
end

function Raycaster:checkGoal()
    local vc = self.params.victory_condition
    if vc ~= "goal" and vc ~= nil then return end
    local px, py = self.di.components.PhysicsUtils.worldToTile(self.player.x, self.player.y)
    if px == self.goal.x and py == self.goal.y then
        self.goal_reached, self.mazes_completed, self.victory = 1, self.mazes_completed + 1, true
        self.visual_effects:flash({color = {0, 1, 0, 0.5}, duration = 0.5, mode = "fade_out"})
    end
end

-- Door system

function Raycaster:getDoorSlideDirection(x, y)
    -- Determine which direction the door should slide based on adjacent walls
    -- Check if walls are N/S or E/W to determine slide direction
    local north_wall = self.map[y-1] and self.map[y-1][x] == 1
    local south_wall = self.map[y+1] and self.map[y+1][x] == 1
    local east_wall = self.map[y] and self.map[y][x+1] == 1
    local west_wall = self.map[y] and self.map[y][x-1] == 1

    -- If walls are N/S, door slides E/W (horizontal door)
    -- If walls are E/W, door slides N/S (vertical door)
    if north_wall or south_wall then
        return "horizontal"  -- Door slides east
    else
        return "vertical"    -- Door slides south
    end
end

function Raycaster:updateDoors(dt)
    if not self.doors then return end

    local px, py = self.player.x, self.player.y
    local open_distance = self.params.door_open_distance or 1.5
    local open_speed = self.params.door_open_speed or 3.0

    for _, door in ipairs(self.doors) do
        local dx = px - (door.x + 0.5)
        local dy = py - (door.y + 0.5)
        local dist = math.sqrt(dx * dx + dy * dy)

        -- Secret walls: only open when player bumps into them (handled by collision)
        if door.secret then goto next_door end

        -- Check if player is close enough to open
        if dist < open_distance and door.state == "closed" then
            if door.locked then
                -- Need matching key
                if self.keys[door.locked] and self.keys[door.locked] > 0 then
                    self.keys[door.locked] = self.keys[door.locked] - 1
                    door.locked = nil
                    door.state = "opening"
                    self:playSound("door_open", 0.7)
                    self.visual_effects:flash({color = {1, 0.85, 0, 0.4}, duration = 0.2, mode = "fade_out"})
                else
                    self:playSound("door_locked", 0.6)
                end
            else
                door.state = "opening"
                self:playSound("door_open", 0.6)
            end
        end

        ::next_door::

        -- Animate door (including secret walls once triggered)
        if door.state == "opening" then
            door.progress = door.progress + dt * open_speed
            if door.progress >= 1 then
                door.progress = 1
                door.state = "open"
                -- Secret walls become walkable when fully open
                if door.secret then
                    self.map[door.y][door.x] = 0
                end
            end
        end
    end
end

-- Check if a door blocks movement at this position
function Raycaster:isDoorBlocking(x, y)
    if not self.doors then return false end
    local tile_x, tile_y = math.floor(x), math.floor(y)
    for _, door in ipairs(self.doors) do
        if door.x == tile_x and door.y == tile_y then
            -- Door blocks if not fully open
            return door.progress < 0.9
        end
    end
    return false
end

function Raycaster:getDoorAt(x, y)
    if not self.doors then return nil end
    for _, door in ipairs(self.doors) do
        if door.x == x and door.y == y then
            return door
        end
    end
    return nil
end

function Raycaster:keypressed(key)
    if self.playback_mode then
        Raycaster.super.keypressed(self, key)
        return
    end
    if key == 'r' then
        self.time_elapsed, self.game_over, self.victory = 0, false, false
        self:generateMaze()
        return
    end

    -- Weapon switching: 1=knife, 2=pistol, 3=machinegun
    if self.player_controller then
        if key == '1' then
            self.player_controller:switchWeapon("knife")
        elseif key == '2' then
            self.player_controller:switchWeapon("pistol")
        elseif key == '3' then
            self.player_controller:switchWeapon("machinegun")
        elseif key == 'tab' then
            self.player_controller:nextWeapon()
        end
    end

    -- Toggle critical path debug visualization
    if key == 'p' then
        self.show_critical_path = not self.show_critical_path
        print("[Raycaster] Critical path visualization:", self.show_critical_path and "ON" or "OFF")
    end

    -- Track key press for grid mode (ignore OS key repeat)
    if self.params.movement_mode == "grid" and not self.params.grid_hold_to_move then
        if not self.grid_keys_held[key] then
            self.grid_just_pressed[key] = true
            self.grid_keys_held[key] = true
        end
    end
end

function Raycaster:keyreleased(key)
    if self.grid_keys_held then
        self.grid_keys_held[key] = nil
    end
end

function Raycaster:draw()
    self.view:draw()
end

return Raycaster
