#!/usr/bin/env python3
"""
Reorder phases in refactor plan:
- Keep Phases 0-7 as is
- Move current Phase 10-16 to become Phase 8-14
- Insert new Phase 15 (Powerup System)
- Move current Phase 8-9 to become Phase 16-17 (Documentation and Optimization)
"""

import re

def reorder_phases(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all phase boundaries
    phase_pattern = r'^## Phase (\d+):'
    lines = content.split('\n')

    # Find line numbers for each phase
    phase_lines = {}
    for i, line in enumerate(lines):
        match = re.match(phase_pattern, line)
        if match:
            phase_num = int(match.group(1))
            phase_lines[phase_num] = i

    print(f"Found phases: {sorted(phase_lines.keys())}")

    # Extract sections
    phase_0_7_end = phase_lines.get(8, len(lines))
    phase_8_start = phase_lines.get(8, 0)
    phase_9_end = phase_lines.get(10, phase_8_start)
    phase_10_start = phase_lines.get(10, 0)
    phase_17_end = len(lines)  # End of file

    # Build new content
    new_lines = []

    # Keep Phases 0-7
    new_lines.extend(lines[:phase_0_7_end])

    # Add Phases 10-16 (renumber to 8-14)
    if 10 in phase_lines:
        phase_10_16_lines = lines[phase_10_start:]
        # Renumber 10→8, 11→9, 12→10, 13→11, 14→12, 15→13, 16→14
        for line in phase_10_16_lines:
            line = re.sub(r'^## Phase 10:', '## Phase 8:', line)
            line = re.sub(r'^## Phase 11:', '## Phase 9:', line)
            line = re.sub(r'^## Phase 12:', '## Phase 10:', line)
            line = re.sub(r'^## Phase 13:', '## Phase 11:', line)
            line = re.sub(r'^## Phase 14:', '## Phase 12:', line)
            line = re.sub(r'^## Phase 15:', '## Phase 13:', line)
            line = re.sub(r'^## Phase 16:', '## Phase 14:', line)
            # Also fix references in text
            line = re.sub(r'Phase 10\b', 'Phase 8', line)
            line = re.sub(r'Phase 11\b', 'Phase 9', line)
            line = re.sub(r'Phase 12\b', 'Phase 10', line)
            line = re.sub(r'Phase 13\b', 'Phase 11', line)
            line = re.sub(r'Phase 14\b', 'Phase 12', line)
            line = re.sub(r'Phase 15\b', 'Phase 13', line)
            line = re.sub(r'Phase 16\b', 'Phase 14', line)
            new_lines.append(line)

    # Add new Phase 15 (Powerup System) - will be inserted before doc phases
    powerup_phase = """
---

## Phase 15: Powerup System

**Goal**: Extract powerup spawning, collection, and effect management into reusable component

**Status**: ⬜ Not Started

**Estimated Impact**: ~400-600 lines eliminated across Breakout and Space Shooter, enables powerups in all games

### Current Duplication

Powerup systems are duplicated across games:
- **Breakout**: 91 powerup references - spawning from bricks, falling, collection, 12 powerup types, effect timers
- **Space Shooter**: 58 powerup references - spawning from enemies, collection, temporary effects
- **Other games**: No powerups currently, but could benefit (speed boost in Snake/Dodge, invincibility, etc.)

### Component Design

```lua
local PowerupSystem = {}

function PowerupSystem:new(config)
    -- config: {
    --   powerup_types: {
    --     ["speed_boost"] = {
    --       sprite: sprite_data,
    --       duration: 5.0,
    --       on_collect: function(game, powerup),
    --       on_expire: function(game, powerup),
    --       stack_behavior: "extend" or "replace" or "ignore"
    --     },
    --     ["multi_ball"] = {
    --       sprite: sprite_data,
    --       instant: true,
    --       on_collect: function(game, powerup)
    --     }
    --   },
    --   spawn_config: {
    --     drop_chance: 0.2,
    --     fall_speed: 100,
    --     size: 20
    --   }
    -- }
end

function PowerupSystem:spawn(x, y, powerup_type)
    -- Create falling powerup at position
end

function PowerupSystem:update(dt, player_bounds, game_bounds)
    -- Update falling powerups
    -- Check collection
    -- Update active effect timers
end

function PowerupSystem:draw()
    -- Render falling powerups
    -- Render active effect indicators
end

-- Common powerup types:
-- - multi_ball: Spawn additional balls
-- - paddle_extend/shrink: Change paddle size
-- - slow_motion/fast_ball: Time manipulation
-- - laser: Shoot projectiles
-- - sticky_paddle: Ball sticks on contact
-- - extra_life: Add life
-- - shield: Temporary invincibility
-- - penetrating_ball: Pass through obstacles
-- - fireball: Destroy on contact
-- - magnet: Attract collectibles
-- - speed_boost: Increase movement speed
-- - invincibility: No damage
-- - rapid_fire: Faster shooting
```

### Migration Strategy

Games define powerup config in init():
```lua
self.powerups = PowerupSystem:new({
    powerup_types = {
        speed_boost = {
            sprite = self.sprites.powerup_speed,
            duration = 5.0,
            on_collect = function(game, powerup)
                game.player_speed = game.player_speed * 1.5
            end,
            on_expire = function(game, powerup)
                game.player_speed = game.player_speed / 1.5
            end
        },
        extra_life = {
            sprite = self.sprites.powerup_life,
            instant = true,
            on_collect = function(game, powerup)
                game.lives = game.lives + 1
            end
        }
    },
    spawn_config = {
        drop_chance = 0.2,
        fall_speed = 100
    }
})
```

Spawn powerups when events occur:
```lua
-- When brick destroyed:
if math.random() < drop_chance then
    self.powerups:spawn(brick.x, brick.y, "random")
end
```

Update and draw:
```lua
self.powerups:update(dt, self.player:getBounds(), game_bounds)
self.powerups:draw()
```

### Tasks

#### 15.1: Create PowerupSystem Component
- [ ] Create `src/utils/game_components/powerup_system.lua`
- [ ] Implement powerup spawning/dropping
- [ ] Implement falling physics
- [ ] Implement collection detection
- [ ] Implement effect timer management
- [ ] Add stack/replace/ignore behavior for duplicate powerups

#### 15.2: Define Common Powerup Library
- [ ] Create preset powerups that work across multiple games:
  - speed_boost (universal)
  - invincibility (universal)
  - slow_motion (universal)
  - extra_life (universal)
  - size_change (Breakout/Snake/Dodge)
  - multi_shot (shooters)
  - rapid_fire (shooters)

#### 15.3: Migration - Breakout
- [ ] Extract 12 powerup types into PowerupSystem config
- [ ] Replace manual powerup spawning with system
- [ ] Replace manual powerup update with system
- [ ] Replace manual effect timers with system
- [ ] Test all 12 powerup types work identically

**Estimated lines removed**: ~200-300 lines

#### 15.4: Migration - Space Shooter
- [ ] Extract powerup types into PowerupSystem config
- [ ] Replace manual powerup management
- [ ] Test powerups work identically

**Estimated lines removed**: ~150-200 lines

#### 15.5: Add Powerups to Other Games (Optional)
- [ ] Dodge: speed_boost, invincibility, slow_motion
- [ ] Snake: speed_boost, invincibility, length_boost
- [ ] Enable via variant configuration

**New features enabled**: ~50-100 lines per game

### Testing Checklist
- [ ] Breakout: All 12 powerups spawn and work correctly
- [ ] Space Shooter: All powerups work correctly
- [ ] Powerup timers expire correctly
- [ ] Stacking behavior works (extend/replace/ignore)
- [ ] Collection detection accurate
- [ ] Visual feedback clear
- [ ] No powerup behavior regressions

### Completion Notes
**Completed**: [DATE]
**Lines Eliminated**: [~400-600 estimated]
**Games Migrated**: Breakout, Space Shooter
**New Features**: Optional powerups enabled in all games

"""
    new_lines.append(powerup_phase)

    # Add Phases 8-9 (renumber to 16-17) - Documentation and Optimization
    if 8 in phase_lines and 9 in phase_lines:
        phase_8_9_lines = lines[phase_8_start:phase_9_end]
        # Renumber and update dependencies
        for line in phase_8_9_lines:
            line = re.sub(r'^## Phase 8:', '## Phase 16:', line)
            line = re.sub(r'^## Phase 9:', '## Phase 17:', line)
            line = re.sub(r'Phases 1-6 completed', 'Phases 1-15 completed', line)
            line = re.sub(r'Phases 1-7 completed', 'Phases 1-15 completed', line)
            new_lines.append(line)

    return '\n'.join(new_lines)

if __name__ == '__main__':
    filepath = 'documentation/Refactor_Game_Components_Plan.md'
    result = reorder_phases(filepath)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(result)

    print(f"Reordered phases in {filepath}")
