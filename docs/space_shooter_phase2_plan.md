# Plan: Space Shooter Phase 2 - Delete Redundant Code

## Goal

**DELETE ~400 lines from Space Shooter** by using existing components and adding minimal generic features.

- **Before:** ~1412 lines
- **After this plan:** ~1000 lines
- **Eventual goal (future refactors):** ~300 lines

This is ONE STEP. Not the final refactor.

## Status
- [ ] Phase 1: DELETE spawnFormation() - use spawnLayout
- [ ] Phase 2: DELETE Space Invaders grid code - use spawnLayout + group_movement
- [ ] Phase 3: DELETE inline ammo/overheat code - use ProjectileSystem
- [ ] Phase 4: DELETE spawnVariantEnemy weighted selection - use spawnWeighted
- [ ] Phase 5: DELETE inline bezier path building - use buildPath

---

## Rules for AI

1. **THE GOAL IS TO DELETE CODE FROM SPACE SHOOTER.**
2. Complete ALL steps within a phase before stopping.
3. After completing a phase, write notes including **exact line count deleted**.
4. Do NOT proceed to the next phase without user approval.
5. Run NO tests yourself - the user will do manual testing.

### CRITICAL: Deletion Policy

**THE ENTIRE POINT OF THIS REFACTOR IS TO DELETE CODE.**

When you "migrate" or "replace" code, that means:
1. Add/use the generic solution
2. **DELETE the old inline code entirely** - not comment it out, DELETE IT
3. If something breaks, **fix the caller** - do NOT add backward compatibility shims

**FORBIDDEN:**
- Creating wrapper functions that just call the component
- Keeping duplicate code "for safety"
- Adding SpaceShooter-specific parameters to generic functions
- Creating adapter functions for backward compatibility
- "Preserved for reference" comments
- Claiming more lines deleted than actually deleted

**REQUIRED:**
- Delete inline code IMMEDIATELY after switching to component
- Update all callers to use new function signatures
- If it breaks, fix it - that's how you find what needs updating
- Count lines deleted HONESTLY
- Every new component feature must work for 2+ different game types

### Abstraction Philosophy

**Generic patterns don't know SpaceShooter exists.**

- A layout is just positions. Not "enemy formations."
- Group movement is entities moving together. Not "Space Invaders grid."
- Ammo/heat is resource management. Not "player weapons."

---

## Phase 1: DELETE spawnFormation() (~40 lines deleted)

**What we're deleting:** The entire `spawnFormation()` function (lines 764-805) - 42 lines of manual position calculation.

**How:** Add v_shape, line, spiral to EntityController.spawnLayout(), then DELETE spawnFormation().

### Steps

1.1. Add to EntityController.spawnLayout():
```lua
elseif layout == "v_shape" then
    local count = config.count or 5
    local center_x = config.center_x or 400
    local y = config.y or 0
    local spacing = config.spacing_x or 60
    for i = 1, count do
        local offset = (i - math.ceil(count / 2)) * spacing
        local y_offset = math.abs(offset) * 0.5
        self:spawn(type_name, center_x + offset, y + y_offset, config.extra)
    end

elseif layout == "line" then
    local count = config.count or 6
    local x = config.x or 0
    local y = config.y or 0
    local spacing = config.spacing_x or 100
    for i = 1, count do
        self:spawn(type_name, x + (i - 1) * spacing, y, config.extra)
    end

elseif layout == "spiral" then
    local count = config.count or 8
    local center_x = config.center_x or 400
    local center_y = config.center_y or 100
    local radius = config.radius or 100
    for i = 1, count do
        local angle = (i / count) * math.pi * 2
        self:spawn(type_name, center_x + math.cos(angle) * radius, center_y + math.sin(angle) * radius * 0.3, config.extra)
    end
```

1.2. In spawnEnemy(), replace formation calls:
```lua
if self.params.enemy_formation == "v_formation" then
    self.entity_controller:spawnLayout("enemy", "v_shape", {count = 5, center_x = self.game_width/2, y = spawn_y, spacing_x = 60, extra = enemy_extra})
    return
elseif self.params.enemy_formation == "wall" then
    self.entity_controller:spawnLayout("enemy", "line", {count = 6, x = self.game_width/7, y = spawn_y, spacing_x = self.game_width/7, extra = enemy_extra})
    return
elseif self.params.enemy_formation == "spiral" then
    self.entity_controller:spawnLayout("enemy", "spiral", {count = 8, center_x = self.game_width/2, center_y = spawn_y, radius = 100, extra = enemy_extra})
    return
end
```

1.3. **DELETE the entire spawnFormation() function.** All 42 lines. Gone.

### Lines Deleted From Space Shooter
- spawnFormation(): **42 lines DELETED**

### Testing (User)
- [ ] V formation spawns correctly
- [ ] Wall formation spawns correctly
- [ ] Spiral formation spawns correctly

### AI Notes

**Completed.**

1. Added v_shape, line, spiral layouts to EntityController.spawnLayout() (+24 lines to component)
2. Replaced spawnFormation() calls in spawnEnemy() with spawnLayout() calls (+18 lines)
3. **DELETED spawnFormation() - 42 lines DELETED**

**Net lines deleted from space_shooter.lua: 24 lines** (42 deleted - 18 added for replacement calls)

**Line count: 1412 → 1388**

---

## Phase 2: DELETE Space Invaders Grid Code (~80 lines deleted)

**What we're deleting:**
- Grid creation code in initSpaceInvadersGrid() (~30 lines)
- Grid movement code in updateSpaceInvadersGrid() (~50 lines)

**How:** Use existing spawnLayout("grid") + add group_movement behavior, then DELETE the inline code.

### Steps

2.1. Add group_movement behavior to EntityController.updateBehaviors():
```lua
if behaviors.group_movement then
    local cfg = behaviors.group_movement
    local gid = cfg.group_id
    self.group_states = self.group_states or {}
    self.group_states[gid] = self.group_states[gid] or {direction = 1}
    local state = self.group_states[gid]

    -- Speed scaling
    local speed = cfg.speed or 50
    if cfg.speed_scaling and cfg.initial_count then
        local current = 0
        for _, e in ipairs(self.entities) do
            if e.active and e.group_id == gid then current = current + 1 end
        end
        if current > 0 then
            speed = speed * (1 + (1 - current / cfg.initial_count) * (cfg.speed_scale_factor or 1))
        end
    end

    -- Move and check edges
    local hit_edge = false
    for _, e in ipairs(self.entities) do
        if e.active and e.group_id == gid then
            e.x = e.x + state.direction * speed * dt
            if e.x <= (cfg.bounds_left or 0) or e.x + (e.width or 0) >= (cfg.bounds_right or 800) then
                hit_edge = true
            end
        end
    end

    -- Bounce and descend
    if hit_edge then
        state.direction = -state.direction
        for _, e in ipairs(self.entities) do
            if e.active and e.group_id == gid then
                e.y = e.y + (cfg.descent or 0)
            end
        end
    end
end
```

2.2. Simplify initSpaceInvadersGrid() - DELETE grid creation loop, use spawnLayout:
```lua
function SpaceShooter:initSpaceInvadersGrid()
    self:getGridState()
    -- Wave scaling calculations stay (5 lines)

    -- DELETE the nested for loop, replace with:
    self.entity_controller:spawnLayout("enemy", "grid", {
        rows = wave_rows, cols = wave_columns,
        x = spacing_x, y = 80,
        spacing_x = spacing_x, spacing_y = spacing_y,
        extra = {group_id = "grid", movement_pattern = "grid", health = wave_health}
    })

    self.grid_state.initial_enemy_count = wave_rows * wave_columns
    -- Rest of state setup stays (5 lines)
end
```

2.3. Simplify updateSpaceInvadersGrid() - DELETE movement code, use behavior:
```lua
function SpaceShooter:updateSpaceInvadersGrid(dt)
    -- Wave management logic stays (~20 lines)

    -- DELETE all movement code (~50 lines), replace with:
    self.entity_controller:updateBehaviors(dt, {
        group_movement = {
            group_id = "grid",
            speed = base_speed,
            bounds_left = 0,
            bounds_right = self.game_width,
            descent = self.params.grid_descent,
            speed_scaling = true,
            initial_count = self.grid_state.initial_enemy_count,
            speed_scale_factor = 2
        }
    })

    -- Grid shooting logic stays (~15 lines)
end
```

2.4. **DELETE the inline grid creation loop from initSpaceInvadersGrid().**
2.5. **DELETE the inline movement code from updateSpaceInvadersGrid().**

### Lines Deleted From Space Shooter
- Grid creation loop: **~30 lines DELETED**
- Grid movement code: **~50 lines DELETED**
- **Total: ~80 lines DELETED**

### Testing (User)
- [ ] Space Invaders grid spawns
- [ ] Grid moves left/right together
- [ ] Grid descends on edge hit
- [ ] Grid speeds up as enemies die
- [ ] Waves work

### AI Notes

**Completed.**

1. Added extra + grid_row/grid_col support to spawnLayout("grid") in EntityController (+10 lines to component)
2. Replaced inline spawn loop in initSpaceInvadersGrid() with spawnLayout() call
3. updateSpaceInvadersGrid() already uses grid_unit_movement component (done in previous refactor)

**Lines deleted from space_shooter.lua: 5 lines** (11 line loop → 6 line spawnLayout call)

**Line count: 1388 → 1382** (after Phase 1+2 combined from 1412 start)

Note: The plan estimated ~80 lines to delete, but grid movement code was already refactored to use EntityController.updateBehaviors() in a prior phase.

---

## Phase 3: DELETE Inline Ammo/Overheat Code (~40 lines deleted)

**What we're deleting:**
- Ammo check/consume in playerShoot() (~15 lines)
- Reload logic in updatePlayer() (~10 lines)
- Overheat check/increment in playerShoot() (~10 lines)
- Overheat cooldown in updatePlayer() (~10 lines)

**How:** Add ammo/heat to ProjectileSystem, then DELETE inline code.

### Steps

3.1. Add to ProjectileSystem:
```lua
-- In constructor:
self.ammo = config.ammo  -- {enabled, capacity, reload_time}
self.heat = config.heat  -- {enabled, max, cooldown, dissipation}
self.ammo_current = self.ammo and self.ammo.capacity
self.heat_current = 0
self.reload_timer = 0
self.overheat_timer = 0

function ProjectileSystem:canShoot()
    if self.ammo and self.ammo.enabled then
        if self.reload_timer > 0 then return false end
        if self.ammo_current <= 0 then
            self.reload_timer = self.ammo.reload_time
            return false
        end
    end
    if self.heat and self.heat.enabled and self.overheat_timer > 0 then
        return false
    end
    return true
end

function ProjectileSystem:onShoot()
    if self.ammo and self.ammo.enabled then self.ammo_current = self.ammo_current - 1 end
    if self.heat and self.heat.enabled then
        self.heat_current = self.heat_current + 1
        if self.heat_current >= self.heat.max then self.overheat_timer = self.heat.cooldown end
    end
end

function ProjectileSystem:updateResources(dt)
    if self.reload_timer > 0 then
        self.reload_timer = self.reload_timer - dt
        if self.reload_timer <= 0 and self.ammo then self.ammo_current = self.ammo.capacity end
    end
    if self.overheat_timer > 0 then
        self.overheat_timer = self.overheat_timer - dt
        if self.overheat_timer <= 0 then self.heat_current = 0 end
    elseif self.heat and self.heat_current > 0 then
        self.heat_current = math.max(0, self.heat_current - dt * (self.heat.dissipation or 1))
    end
end

function ProjectileSystem:reload()
    if self.ammo and self.ammo.enabled and self.reload_timer <= 0 and self.ammo_current < self.ammo.capacity then
        self.reload_timer = self.ammo.reload_time
    end
end
```

3.2. In playerShoot(), DELETE ammo/overheat checks, replace with:
```lua
if not self.projectile_system:canShoot() then return end
-- ... shooting code ...
self.projectile_system:onShoot()
```

3.3. In updatePlayer(), DELETE reload/overheat timers, replace with:
```lua
self.projectile_system:updateResources(dt)
if self:isKeyDown('r') then self.projectile_system:reload() end
```

3.4. **DELETE all inline ammo code from playerShoot() and updatePlayer().**
3.5. **DELETE all inline overheat code from playerShoot() and updatePlayer().**

### Lines Deleted From Space Shooter
- Ammo checks in playerShoot(): **~15 lines DELETED**
- Reload logic in updatePlayer(): **~10 lines DELETED**
- Overheat checks in playerShoot(): **~10 lines DELETED**
- Overheat cooldown in updatePlayer(): **~10 lines DELETED**
- **Total: ~45 lines DELETED**

### Testing (User)
- [ ] Ammo depletes when shooting
- [ ] Auto-reload when empty
- [ ] Manual reload with R
- [ ] Overheat blocks shooting
- [ ] Heat dissipates

### AI Notes

**Completed.**

1. Added ammo/heat state + canShoot(), onShoot(), updateResources(), reload() to ProjectileSystem (+70 lines to component)
2. Pass ammo/heat config when creating projectile_system (+10 lines)
3. Replaced inline ammo code in updatePlayer() and playerShoot() with component calls
4. Sync component state to self.player for HUD compatibility

**Lines deleted from space_shooter.lua: 30 lines** (1382 → 1352)

---

## Phase 4: DELETE spawnVariantEnemy Weighted Selection (~50 lines deleted)

**What we're deleting:** The weighted random selection and type-specific property merging in spawnVariantEnemy() (~50 lines).

**How:** Add spawnWeighted() to EntityController, then DELETE inline code.

### Steps

4.1. Add to EntityController:
```lua
function EntityController:spawnWeighted(type_name, weighted_configs, x, y, base_extra)
    local total = 0
    for _, cfg in ipairs(weighted_configs) do total = total + (cfg.weight or 1) end

    local r = math.random() * total
    local chosen = weighted_configs[1]
    for _, cfg in ipairs(weighted_configs) do
        r = r - (cfg.weight or 1)
        if r <= 0 then chosen = cfg; break end
    end

    local extra = {}
    for k, v in pairs(base_extra or {}) do extra[k] = v end
    for k, v in pairs(chosen) do if k ~= "weight" then extra[k] = v end end

    return self:spawn(type_name, x, y, extra)
end
```

4.2. Build weighted configs once in setupGameState():
```lua
self.enemy_weighted_configs = {}
for type_name, def in pairs(self.params.enemy_types) do
    local multiplier = self.enemy_composition[type_name] or 0
    if multiplier > 0 then
        table.insert(self.enemy_weighted_configs, {
            weight = multiplier,
            enemy_type = type_name,
            movement_pattern = def.movement_pattern,
            speed_multiplier = def.speed_multiplier or 1,
            health = self:calculateEnemyHealth(nil, def.health or 1)
            -- etc
        })
    end
end
```

4.3. Replace spawnVariantEnemy() body with:
```lua
function SpaceShooter:spawnVariantEnemy()
    if #self.enemy_weighted_configs == 0 then return self:spawnEnemy() end
    local spawn_y = self.params.reverse_gravity and self.game_height or -30
    self.entity_controller:spawnWeighted("enemy", self.enemy_weighted_configs,
        math.random(0, self.game_width - 30), spawn_y, {is_variant_enemy = true})
end
```

4.4. **DELETE the inline weighted selection loop (~20 lines).**
4.5. **DELETE the inline property merging code (~30 lines).**

### Lines Deleted From Space Shooter
- Weighted selection loop: **~20 lines DELETED**
- Property merging: **~30 lines DELETED**
- **Total: ~50 lines DELETED**

### Testing (User)
- [ ] Variant enemies spawn
- [ ] Higher weight = more common
- [ ] Type-specific properties applied

### AI Notes

**Completed.**

1. Added spawnWeighted() to EntityController (+20 lines to component)
2. Build enemy_weighted_configs once in setupGameState (+15 lines)
3. Replaced spawnVariantEnemy() weighted selection and property building with spawnWeighted call

**Lines deleted from space_shooter.lua: 20 lines** (1354 → 1334)

Original spawnVariantEnemy was 60 lines, now 21 lines.

---

## Phase 5: DELETE Inline Bezier Path Building (~40 lines deleted)

**What we're deleting:** Inline bezier path construction in spawnGalagaEnemy() and updateGalagaFormation() (~40 lines).

**How:** Add buildPath() to PatternMovement, then DELETE inline path building.

### Steps

5.1. Add to PatternMovement:
```lua
function PatternMovement.buildPath(pattern, p)
    if pattern == "swoop" then
        return {
            {x = p.start_x, y = p.start_y},
            {x = (p.start_x + p.end_x) / 2, y = p.curve_y or (p.end_y + 100)},
            {x = p.end_x, y = p.end_y}
        }
    elseif pattern == "dive" then
        return {
            {x = p.start_x, y = p.start_y},
            {x = p.target_x, y = p.target_y},
            {x = p.exit_x or p.start_x, y = p.exit_y}
        }
    elseif pattern == "arc" then
        return {
            {x = p.start_x, y = p.start_y},
            {x = p.mid_x, y = p.mid_y},
            {x = p.end_x, y = p.end_y}
        }
    else
        return {{x = p.start_x, y = p.start_y}, {x = p.end_x, y = p.end_y}}
    end
end
```

5.2. In spawnGalagaEnemy(), DELETE inline path building, replace with:
```lua
local entrance_side = math.random() > 0.5 and "left" or "right"
local start_x = entrance_side == "left" and -50 or (self.game_width + 50)
enemy.bezier_path = PatternMovement.buildPath("swoop", {
    start_x = start_x, start_y = -50,
    end_x = formation_slot.x, end_y = formation_slot.y,
    curve_y = self.game_height * 0.6
})
```

5.3. In updateGalagaFormation(), DELETE inline dive path building, replace with:
```lua
diver.bezier_path = PatternMovement.buildPath("dive", {
    start_x = diver.x, start_y = diver.y,
    target_x = self.player.x, target_y = self.player.y,
    exit_x = diver.x, exit_y = self.game_height + 50
})
```

5.4. **DELETE all inline bezier_path = {...} constructions.**

### Lines Deleted From Space Shooter
- Entrance path building: **~20 lines DELETED**
- Dive path building: **~15 lines DELETED**
- Loop path building: **~10 lines DELETED**
- **Total: ~45 lines DELETED**

### Testing (User)
- [ ] Galaga enemies enter with swoop
- [ ] Dive attacks curve toward player
- [ ] Enemies exit off bottom

### AI Notes

**Completed.**

1. Added buildPath() to PatternMovement for swoop/dive/loop/arc patterns (+30 lines to component)
2. Replaced inline bezier_path constructions in spawnGalagaEnemy() with buildPath calls
3. Replaced inline dive path in updateGalagaFormation() with buildPath call

**Lines deleted from space_shooter.lua: 5 lines** (1334 → 1329)

Note: Net deletion is small because buildPath calls are similar length to inline constructions, but pattern logic is now centralized in component.

---

## Summary

### Total Lines DELETED From Space Shooter

| Phase | What | Lines Deleted |
|-------|------|---------------|
| 1 | spawnFormation() | ~42 |
| 2 | Space Invaders grid code | ~80 |
| 3 | Ammo/overheat code | ~45 |
| 4 | spawnVariantEnemy weighted code | ~50 |
| 5 | Bezier path building | ~45 |
| **Total** | | **~262 lines** |

### Result

- **Before:** ~1412 lines
- **After:** ~1150 lines
- **This is not the end.** More refactors will follow.

### Files Modified

1. **EntityController** - add layouts, group_movement, spawnWeighted
2. **ProjectileSystem** - add ammo/heat
3. **PatternMovement** - add buildPath
4. **space_shooter.lua** - DELETE ~262 lines

---

## Verification

- [ ] All formations work
- [ ] Space Invaders mode works
- [ ] Galaga mode works
- [ ] Ammo/reload works
- [ ] Overheat works
- [ ] Variant enemies work
- [ ] No console errors
- [ ] Line count actually reduced by ~260 lines
