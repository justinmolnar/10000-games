-- fog_of_war.lua
-- Reusable fog of war component for games
-- Supports two modes:
--   1. Stencil mode: Dark overlay with circular visibility cutouts (Breakout, Snake, Dodge)
--   2. Alpha mode: Per-entity alpha calculation with gradient (Memory Match)

local Object = require('class')
local FogOfWar = Object:extend('FogOfWar')

function FogOfWar:new(params)
    local instance = setmetatable({}, {__index = FogOfWar})
    params = params or {}

    if params.enabled ~= nil then
        instance.enabled = params.enabled
    else
        instance.enabled = false  -- Default to disabled
    end
    instance.mode = params.mode or "stencil"  -- "stencil" or "alpha"
    instance.opacity = params.opacity or 0.8  -- Darkness level (0.0 = transparent, 1.0 = opaque)

    -- Alpha mode parameters (Memory Match)
    instance.inner_radius_multiplier = params.inner_radius_multiplier or 0.4  -- Fully visible inside this
    instance.outer_radius = params.outer_radius or 9999  -- Full darkness outside this

    -- Stencil mode: visibility sources (cleared each frame, then rebuilt)
    instance.visibility_sources = {}  -- Array of {x, y, radius}

    if _G.DEBUG_FOG then
        print(string.format("[FogOfWar] new() called: enabled=%s, mode=%s, opacity=%s",
            tostring(instance.enabled), tostring(instance.mode), tostring(instance.opacity)))
    end

    return instance
end

-- Stencil Mode API
-- ================

function FogOfWar:clearSources()
    -- Clear visibility points (call each frame before adding new ones)
    self.visibility_sources = {}
end

function FogOfWar:addVisibilitySource(x, y, radius)
    -- Add a visibility circle (player, ball, snake segment, etc.)
    table.insert(self.visibility_sources, {x = x, y = y, radius = radius})
end

function FogOfWar:render(arena_width, arena_height)
    -- Render fog overlay using stencil cutouts
    -- Call this AFTER drawing game content but BEFORE HUD

    if not self.enabled then
        if _G.DEBUG_FOG then print("[FogOfWar] render() called but enabled=false") end
        return
    end

    if self.mode ~= "stencil" then
        if _G.DEBUG_FOG then print("[FogOfWar] render() called but mode=" .. tostring(self.mode)) end
        return
    end

    if _G.DEBUG_FOG then
        print(string.format("[FogOfWar] Rendering fog: %d sources, arena=%dx%d",
            #self.visibility_sources, arena_width, arena_height))
    end

    if #self.visibility_sources == 0 then
        -- No visibility sources, render full fog
        if _G.DEBUG_FOG then print("[FogOfWar] No visibility sources, rendering full fog") end
        love.graphics.setColor(0, 0, 0, self.opacity)
        love.graphics.rectangle("fill", 0, 0, arena_width, arena_height)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- Use stencil buffer to create visibility cutouts
    love.graphics.stencil(function()
        -- Draw visibility circles into stencil buffer
        for _, source in ipairs(self.visibility_sources) do
            love.graphics.circle("fill", source.x, source.y, source.radius)
        end
    end, "replace", 1)

    -- Draw fog overlay where stencil == 0 (outside visibility circles)
    love.graphics.setStencilTest("equal", 0)
    love.graphics.setColor(0, 0, 0, self.opacity)
    love.graphics.rectangle("fill", 0, 0, arena_width, arena_height)

    -- Reset state
    love.graphics.setStencilTest()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Alpha Mode API
-- ==============

function FogOfWar:calculateAlpha(entity_x, entity_y, fog_center_x, fog_center_y)
    -- Calculate alpha value for an entity based on distance from fog center
    -- Returns: alpha multiplier (1.0 = fully visible, opacity = fully dark)
    -- Used for Memory Match card rendering

    if not self.enabled or self.mode ~= "alpha" then
        return 1.0  -- Fully visible if fog disabled or wrong mode
    end

    if self.outer_radius >= 9999 then
        return 1.0  -- Fog disabled (infinite radius)
    end

    local dx = entity_x - fog_center_x
    local dy = entity_y - fog_center_y
    local dist = math.sqrt(dx * dx + dy * dy)

    local inner_radius = self.outer_radius * self.inner_radius_multiplier

    if dist < inner_radius then
        return 1.0  -- Fully visible inside inner radius
    elseif dist > self.outer_radius then
        return self.opacity  -- Fully dark outside outer radius
    else
        -- Smooth gradient from 1.0 (visible) to opacity (dark)
        local t = (dist - inner_radius) / (self.outer_radius - inner_radius)
        return 1.0 - (t * (1.0 - self.opacity))
    end
end

-- Update function (for future expansion, e.g. animated fog)
function FogOfWar:update(dt)
    -- Currently unused, but included for consistency with other components
end

return FogOfWar
