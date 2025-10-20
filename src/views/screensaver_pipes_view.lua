-- src/views/screensaver_pipes_view.lua
-- 3D Pipes screensaver in LÖVE (procedural)
-- Simplified: Generates a set of growing pipe segments in 3D grid with 90-degree turns,
-- projects to 2D with perspective, and draws tubes with basic shading.

local Object = require('class')

local PipesView = Object:extend('PipesView')

function PipesView:init(opts)
    opts = opts or {}
    self.di = opts.di
    self:setViewport(0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    local C = (self.di and self.di.config) or {}
    local d = (C and C.screensavers and C.screensavers.defaults and C.screensavers.defaults.pipes) or {}
    self.fov = opts.fov or d.fov or 420 -- focal length for projection
    self.camera_z = 0   -- camera at z=0, world is in +Z
    self.near = opts.near or d.near or 80
    self.pipe_radius = opts.radius or d.radius or 4.5
    self.grid_step = opts.grid_step or d.grid_step or 24
    self.max_segments = opts.max_segments or d.max_segments or 800
    self.turn_chance = opts.turn_chance or d.turn_chance or 0.45
    self.speed = opts.speed or d.speed or 60 -- growth speed
    self.spawn_min_z = opts.spawn_min_z or d.spawn_min_z or 200
    self.spawn_max_z = opts.spawn_max_z or d.spawn_max_z or 600
    self.avoid_cells = (opts.avoid_cells ~= nil) and opts.avoid_cells or (d.avoid_cells ~= false)
    self.show_grid = (opts.show_grid ~= nil) and opts.show_grid or (d.show_grid == true)
    self.camera_drift = opts.camera_drift or d.camera_drift or 40
    self.camera_roll_amount = opts.camera_roll or d.camera_roll or 0.05
    self.max_pipes = math.max(1, math.floor((opts.pipe_count or d.pipe_count or 5)))
    self.show_hud = (opts.show_hud ~= nil) and opts.show_hud or (d.show_hud ~= false)

    local DV = ((self.di and self.di.config and self.di.config.ui and self.di.config.ui.views and self.di.config.ui.views.screensaver_pipes_draw) or {})
    local PC = (DV.pipes and DV.pipes.colors) or {
        {0.9,0.2,0.2}, {0.2,0.9,0.2}, {0.2,0.6,1.0}, {0.9,0.8,0.2}, {0.9,0.4,0.8}
    }
    self.colors = PC

    self.pipes = {}
    self.occupancy = {} -- grid cell -> true
    self.time = 0
    self.roll = 0 -- slow roll around Z for projection only
    -- Seed a few pipes so it doesn't look empty
    for i=1,self.max_pipes do self:spawnPipe() end
end

function PipesView:setViewport(x, y, w, h)
    self.viewport = {x=x, y=y, width=w, height=h}
end

-- Allow movement along X/Y and positive Z (away from camera). Avoid -Z to prevent crossing near plane.
local dirs = {
    {1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1}
}

local function vec_scale(v, s)
    return {v[1]*s, v[2]*s, v[3]*s}
end

local function vec_add(a, b)
    return {a[1]+b[1], a[2]+b[2], a[3]+b[3]}
end

local function cell_key(p, step)
    return math.floor(p[1]/step+0.5)..":"..math.floor(p[2]/step+0.5)..":"..math.floor(p[3]/step+0.5)
end

function PipesView:spawnPipe()
    -- Spawn within a centered box in front of camera (50% closer than before)
    local w, h = self.viewport.width, self.viewport.height
    local start = { (math.random()-0.5)*w*0.4, (math.random()-0.5)*h*0.4, math.random(self.spawn_min_z, self.spawn_max_z) }
    local dir = dirs[math.random(#dirs)]
    local color = self.colors[math.random(#self.colors)]
    local pipe = {
        color = color,
        nodes = { start },
        dir = dir,
        progress = 0 -- 0..1 progress to next grid cell
    }
    -- Pre-grow a couple of steps so you don't see a single fat end-cap
    for i=1,2 do
        local last = pipe.nodes[#pipe.nodes]
        local step = vec_scale(pipe.dir, self.grid_step)
        local nxt = vec_add(last, step)
        table.insert(pipe.nodes, nxt)
    if self.avoid_cells then self.occupancy[cell_key(nxt, self.grid_step)] = true end
    end
    -- mark start occupancy too
    if self.avoid_cells then self.occupancy[cell_key(start, self.grid_step)] = true end
    table.insert(self.pipes, pipe)
end

function PipesView:update(dt)
    self.time = self.time + dt
    -- subtle camera drift and roll
    self.camera_z = self.camera_drift * math.sin(self.time * 0.1)
    self.roll = self.camera_roll_amount * math.sin(self.time * 0.07)
    -- Occasionally spawn another pipe if under cap
    if #self.pipes < self.max_pipes and math.random() < 0.01 then self:spawnPipe() end

    for _, p in ipairs(self.pipes) do
        -- Advance growth
        p.progress = p.progress + (self.speed * dt) / self.grid_step
        if p.progress >= 1 then
            p.progress = p.progress - 1
            -- Commit new node at next grid position
            local last = p.nodes[#p.nodes]
            local step = vec_scale(p.dir, self.grid_step)
            local nextp = vec_add(last, step)
            -- avoid reusing occupied cells to reduce overlaps
            local key = cell_key(nextp, self.grid_step)
            if self.avoid_cells and self.occupancy[key] then
                -- force a turn if occupied
                for tries=1,6 do
                    local nd = dirs[math.random(#dirs)]
                    if not (nd[1] == -p.dir[1] and nd[2] == -p.dir[2] and (nd[3] or 0) == -(p.dir[3] or 0)) and not (nd[1]==p.dir[1] and nd[2]==p.dir[2] and (nd[3] or 0)==(p.dir[3] or 0)) then
                        p.dir = nd
                        step = vec_scale(p.dir, self.grid_step)
                        nextp = vec_add(last, step)
                        key = cell_key(nextp, self.grid_step)
                        if not (self.avoid_cells and self.occupancy[key]) then break end
                    end
                end
            end
            table.insert(p.nodes, nextp)
            if self.avoid_cells then self.occupancy[key] = true end
            -- Possibly turn (90-degree)
            if math.random() < self.turn_chance then
                -- Choose a new dir different from current and not opposite
                local nd
                repeat
                    nd = dirs[math.random(#dirs)]
                until not (nd[1] == -p.dir[1] and nd[2] == -p.dir[2] and (nd[3] or 0) == -(p.dir[3] or 0)) and not (nd[1]==p.dir[1] and nd[2]==p.dir[2] and (nd[3] or 0)==(p.dir[3] or 0))
                p.dir = nd
            end
            -- Trim if too long overall
            local total_segments = 0
            for _,pp in ipairs(self.pipes) do total_segments = total_segments + math.max(0, #pp.nodes-1) end
            if total_segments > self.max_segments then
                -- remove earliest nodes from oldest pipe
                local q = self.pipes[1]
                if q and #q.nodes > 1 then table.remove(q.nodes, 1) end
                if q and #q.nodes <= 1 then table.remove(self.pipes, 1) end
            end
        end
    end
end

-- Project 3D point to 2D
function PipesView:project(pt)
    local w, h = self.viewport.width, self.viewport.height
    local cx, cy = w/2, h/2
    local x, y, z = pt[1], pt[2], pt[3]
    -- apply a tiny roll for projection (rotate around Z)
    local cr = math.cos(self.roll)
    local sr = math.sin(self.roll)
    local rx = x * cr - y * sr
    local ry = x * sr + y * cr
    x, y = rx, ry
    local zc = z - self.camera_z
    if zc <= self.near then return nil end
    local k = self.fov / zc
    return cx + x * k, cy + y * k, k
end

local function clamp01(x) return math.max(0, math.min(1, x)) end

local function shade_color(color, factor, alpha)
    return color[1]*factor, color[2]*factor, color[3]*factor, alpha or 1
end

function PipesView:drawSegment(a, b, radius, color)
    local ax, ay, ak = self:project(a)
    local bx, by, bk = self:project(b)
    if not ax or not bx then return end
    -- line width with depth
    local depth_scale = math.min(1.1, (ak + bk) * 0.5 * 0.11)
    local rw = math.max(1, radius * depth_scale)

    -- underlay (shadow)
    local DV = ((self.di and self.di.config and self.di.config.ui and self.di.config.ui.views and self.di.config.ui.views.screensaver_pipes_draw) or {})
    local P = DV.pipes or { shadow_factor = 0.35, shadow_alpha = 0.6, main_factor = 0.85, highlight_scale = 1.2, highlight_alpha = 0.85 }
    love.graphics.setLineWidth(rw + 1.5)
    love.graphics.setColor(shade_color(color, P.shadow_factor or 0.35, P.shadow_alpha or 0.6))
    love.graphics.line(ax, ay, bx, by)

    -- main body
    love.graphics.setLineWidth(rw)
    love.graphics.setColor(shade_color(color, P.main_factor or 0.85, 1))
    love.graphics.line(ax, ay, bx, by)

    -- highlight core
    love.graphics.setLineWidth(rw * 0.55)
    love.graphics.setColor( clamp01(color[1]*(P.highlight_scale or 1.2)), clamp01(color[2]*(P.highlight_scale or 1.2)), clamp01(color[3]*(P.highlight_scale or 1.2)), P.highlight_alpha or 0.85)
    love.graphics.line(ax, ay, bx, by)

    -- rounded-ish elbow: draw a small arc at joints later in pass
    -- end caps for smoother look
    love.graphics.setPointSize(rw*1.0)
    love.graphics.points(ax, ay)
    love.graphics.points(bx, by)
end

function PipesView:draw()
    local DV = ((self.di and self.di.config and self.di.config.ui and self.di.config.ui.views and self.di.config.ui.views.screensaver_pipes_draw) or {})
    local bg = DV.bg_color or {0,0.15,0.2}
    love.graphics.clear(bg[1], bg[2], bg[3])
    -- Optional retro grid
    if self.show_grid then
        local grid = (DV.grid or { color = {0.0,0.3,0.35,0.35}, x_extents={-10,10}, y_extents={-8,8}, z1=600,z2=900, step_mul=6 })
        love.graphics.setColor(grid.color)
        local w, h = self.viewport.width, self.viewport.height
        for gx=(grid.x_extents and grid.x_extents[1] or -10),(grid.x_extents and grid.x_extents[2] or 10) do
            local a = {gx*self.grid_step*(grid.step_mul or 6), -h*0.4, grid.z1 or 600}
            local b = {gx*self.grid_step*(grid.step_mul or 6),  h*0.4, grid.z2 or 900}
            local ax, ay = self:project(a)
            local bx, by = self:project(b)
            if ax and bx then love.graphics.line(ax, ay, bx, by) end
        end
        for gy=(grid.y_extents and grid.y_extents[1] or -8),(grid.y_extents and grid.y_extents[2] or 8) do
            local a = {-w*0.4, gy*self.grid_step*(grid.step_mul or 6), grid.z1 or 600}
            local b = { w*0.4, gy*self.grid_step*(grid.step_mul or 6), grid.z2 or 900}
            local ax, ay = self:project(a)
            local bx, by = self:project(b)
            if ax and bx then love.graphics.line(ax, ay, bx, by) end
        end
    end
    -- Basic painter's algorithm: draw from far to near by averaging depth
    local segments = {}
    for _, p in ipairs(self.pipes) do
        for i=2,#p.nodes do
            local a = p.nodes[i-1]
            local b = p.nodes[i]
            local dz = (a[3] + b[3]) * 0.5
            table.insert(segments, {dz=dz, a=a, b=b, color=p.color})
        end
        -- Draw partial current growth between last node and its next
        local last = p.nodes[#p.nodes]
        local step = vec_scale(p.dir, self.grid_step * p.progress)
        local tip = vec_add(last, step)
        local dz = (last[3] + tip[3]) * 0.5
        table.insert(segments, {dz=dz, a=last, b=tip, color=p.color})
    end

    table.sort(segments, function(u,v) return u.dz > v.dz end) -- far first

    for _, s in ipairs(segments) do
        self:drawSegment(s.a, s.b, self.pipe_radius, s.color)
    end

    -- Draw joint disks after segments for smoothing elbows
    local joints = {}
    for _, p in ipairs(self.pipes) do
        for i=2,#p.nodes-1 do
            local j = p.nodes[i]
            local dz = j[3]
            table.insert(joints, {dz=dz, p=j, color=p.color})
        end
    end
    table.sort(joints, function(u,v) return u.dz > v.dz end)
    for _, j in ipairs(joints) do
        local x, y, k = self:project(j.p)
        if x then
            local DV = ((self.di and self.di.config and self.di.config.ui and self.di.config.ui.views and self.di.config.ui.views.screensaver_pipes_draw) or {})
            local joint_scale = (DV.pipes and DV.pipes.joint_radius_scale) or 0.12
            local r = self.pipe_radius * k * joint_scale
            love.graphics.setColor(shade_color(j.color, 0.85, 1))
            love.graphics.circle('fill', x, y, r)
            love.graphics.setColor(shade_color(j.color, 0.2, 0.7))
            love.graphics.setLineWidth(1)
            love.graphics.circle('line', x, y, r)
        end
    end

    -- Optional HUD
    if self.show_hud then
    local DV = ((self.di and self.di.config and self.di.config.ui and self.di.config.ui.views and self.di.config.ui.views.screensaver_pipes_draw) or {})
        local hud = DV.hud or { label = "3D Pipes", color = {0.7,0.9,1,0.5} }
        love.graphics.setColor(hud.color)
        love.graphics.print(hud.label or "3D Pipes", 12, 10, 0, 1.2, 1.2)
    end
end

return PipesView
