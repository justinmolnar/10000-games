--[[
    Raycaster - First-person maze exploration

    Procedural or static mazes with Wolfenstein-style rendering.
    Generators: rotLove (dungeons/caves), static (predefined maps).
    Supports collectible dots, edge wrapping, billboards.
]]

local BaseGame = require('src.games.base_game')
local RaycasterView = require('src.games.views.raycaster_view')

local Raycaster = BaseGame:extend('Raycaster')

function Raycaster:init(game_data, cheats, di, variant_override)
    Raycaster.super.init(self, game_data, cheats, di, variant_override)

    local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.raycaster)
    self.params = self.di.components.SchemaLoader.load(self.variant, "raycaster_schema", runtimeCfg)

    self:applyCheats({speed_modifier = {"move_speed", "turn_speed"}})
    self:setupComponents()
    self:generateMaze()

    self.view = RaycasterView:new(self)
end

function Raycaster:setupComponents()
    self:createComponentsFromSchema()
    self:createVictoryConditionFromSchema()

    -- Choose maze generator
    local gen = self.params.generator
    if gen == "static" then
        self.maze_generator = self.di.components.StaticMapLoader:new({
            map_name = self.params.map_name
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
end

function Raycaster:generateMaze()
    local result = self.maze_generator:generate(self.rng)

    self.map, self.map_width, self.map_height = result.map, result.width, result.height
    self.player = {x = result.start.x, y = result.start.y, angle = result.start.angle or 0}
    self.goal = {x = result.goal.x, y = result.goal.y}

    if self.movement_controller then
        self.movement_controller:initSmoothState("player", self.player.angle)
    end

    self.goal_reached, self.mazes_completed = 0, self.mazes_completed or 0
    self.bob_timer = 0

    -- Collectibles from static maps
    self.dots, self.power_pills, self.dots_collected, self.total_dots = {}, {}, 0, 0
    for _, pos in ipairs(result.dots or {}) do
        table.insert(self.dots, {x = pos.x, y = pos.y, collected = false})
    end
    for _, pos in ipairs(result.power_pills or {}) do
        table.insert(self.power_pills, {x = pos.x, y = pos.y, collected = false})
    end
    self.total_dots = #self.dots + #self.power_pills

    self.goal_diamond = self.di.components.BillboardRenderer.createDiamond(
        self.goal.x + 0.5, self.goal.y + 0.5,
        {height = 0.5, aspect = 0.6, color = self.params.goal_color or {0.2, 1, 0.4}}
    )
    self.billboards = {self.goal_diamond}

    print(string.format("[Raycaster] %dx%d maze, start=(%.1f,%.1f) goal=(%d,%d) dots=%d",
        self.map_width, self.map_height, self.player.x, self.player.y, self.goal.x, self.goal.y, self.total_dots))
end

function Raycaster:setPlayArea(width, height)
    self.viewport_width, self.viewport_height = width, height
end

function Raycaster:updateGameLogic(dt)
    if self.game_over or self.victory then return end

    self:handleInput(dt)
    self:updateBillboards(dt)
    self:collectDots()
    self:checkGoal()
    self.visual_effects:update(dt)

    self.metrics.time_elapsed = self.time_elapsed
    self.metrics.mazes_completed = self.mazes_completed
    self.metrics.dots_collected = self.dots_collected
end

function Raycaster:handleInput(dt)
    local left, right = self:isKeyDown('left', 'a'), self:isKeyDown('right', 'd')
    self.player.angle = self.player.angle + ((right and 1 or 0) - (left and 1 or 0)) * self.params.turn_speed * dt

    local move_x, move_y = 0, 0
    local speed = self.params.move_speed * dt
    local angle = self.player.angle

    if self:isKeyDown('up', 'w') then
        move_x, move_y = math.cos(angle) * speed, math.sin(angle) * speed
    end
    if self:isKeyDown('down', 's') then
        move_x, move_y = move_x - math.cos(angle) * speed, move_y - math.sin(angle) * speed
    end
    if self:isKeyDown('q') then
        local a = angle - math.pi / 2
        move_x, move_y = move_x + math.cos(a) * speed, move_y + math.sin(a) * speed
    end
    if self:isKeyDown('e') then
        local a = angle + math.pi / 2
        move_x, move_y = move_x + math.cos(a) * speed, move_y + math.sin(a) * speed
    end

    local wrap = self.params.enable_edge_wrap
    self.player.x, self.player.y = self.di.components.PhysicsUtils.moveWithTileCollision(
        self.player.x, self.player.y, move_x, move_y,
        self.map, self.map_width, self.map_height, wrap, wrap
    )
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

function Raycaster:checkGoal()
    local px, py = self.di.components.PhysicsUtils.worldToTile(self.player.x, self.player.y)
    if px == self.goal.x and py == self.goal.y then
        self.goal_reached, self.mazes_completed, self.victory = 1, self.mazes_completed + 1, true
        self.visual_effects:flash({color = {0, 1, 0, 0.5}, duration = 0.5, mode = "fade_out"})
    end
end

function Raycaster:keypressed(key)
    if self.playback_mode then
        Raycaster.super.keypressed(self, key)
        return
    end
    if key == 'r' then
        self.time_elapsed, self.game_over, self.victory = 0, false, false
        self:generateMaze()
    end
end

function Raycaster:draw()
    self.view:draw()
end

return Raycaster
