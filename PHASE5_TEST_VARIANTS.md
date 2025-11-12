# Phase 5: Physics Utilities Component - Testing Variants

## Overview
Phase 5 migrated trail systems, screen wrap, and bounce physics to PhysicsUtils component.

**Games Affected**:
- Dodge (trail + wall bounce)
- Space Shooter (screen wrap)

## Test Variants

### Dodge Game - Trail System Tests

**Variants to Test** (from assets/data/base_game_definitions.json):
1. **Dodge Classic** - Basic dodge with standard trail
2. **Dodge Plus** - Enhanced dodge with longer trail
3. Any variant with `player_trail_length > 0` parameter

**What to Verify**:
- [ ] Player trail renders correctly behind the ship
- [ ] Trail follows player rotation (extends from back of ship)
- [ ] Trail fades properly with opacity gradient
- [ ] Trail length matches variant configuration
- [ ] No visual glitches or jittering
- [ ] Performance is smooth with trail rendering

### Dodge Game - Wall Bounce Tests

**Variants to Test** (bouncer enemy type):
1. Look for variants with `enemy_types` array containing "bouncer"
2. Any variant with `max_bounces` parameter

**What to Verify**:
- [ ] Bouncer enemies bounce off walls correctly
- [ ] Bounce count increments properly
- [ ] Bouncers disappear after max_bounces reached
- [ ] Bounce physics feel identical to before migration
- [ ] No enemies getting stuck in walls
- [ ] Velocity reflects correctly on collision

### Space Shooter - Screen Wrap Tests

**Variants to Test**:
1. **Space Shooter Classic** - Should have screen wrap enabled
2. Any variant with `screen_wrap: true` parameter
3. Any variant with `screen_wrap_bullets: true` or `screen_wrap_enemies: true`

**What to Verify**:
- [ ] Player ship wraps to opposite side when leaving screen
- [ ] Asteroids wrap correctly (if asteroids mode enabled)
- [ ] Bullets wrap correctly (if screen_wrap_bullets enabled)
- [ ] Enemies wrap correctly (if screen_wrap_enemies enabled)
- [ ] Wrap count tracking works (bullets destroyed after max_wraps)
- [ ] No entities getting stuck at edges
- [ ] Wrapping is smooth and instant

## CRITICAL: Demo Recording Tests

**After testing variants above, VERIFY DEMO DETERMINISM**:

1. **Record Demo**:
   - Play a Dodge variant with trail enabled
   - Complete the game successfully
   - Save the demo when prompted

2. **Playback Demo**:
   - Assign demo to VM slot
   - Watch playback at 1x speed
   - Verify trail renders identically during playback
   - Check that physics behavior is deterministic

3. **Fast Playback**:
   - Set VM to 10x or 100x speed
   - Verify no desync errors
   - Check that trails don't cause performance issues at high speeds

## Performance Tests

**High Trail Density**:
- [ ] Test Dodge variant with `player_trail_length: 50` (or create temporary test variant)
- [ ] Verify no frame drops
- [ ] Check that trail culling works correctly

**Screen Wrap with Many Objects**:
- [ ] Test Space Shooter with many enemies + bullets + screen wrap enabled
- [ ] Verify wrapping logic doesn't cause performance issues
- [ ] Check for any edge case bugs with multiple objects wrapping simultaneously

## Files Changed

**Migrated Files** (backups created with .backup_phase5 extension):
- `src/games/dodge_game.lua`
- `src/games/views/dodge_view.lua`
- `src/games/space_shooter.lua`

**New Component**:
- `src/utils/game_components/physics_utils.lua` (188 lines)

**Lines Eliminated**: 44 lines total
- dodge_game.lua: 16 lines
- dodge_view.lua: 13 lines
- space_shooter.lua: 15 lines

## Rollback Instructions

If issues found:
```bash
# Revert Dodge game
cp "src/games/dodge_game.lua.backup_phase5" "src/games/dodge_game.lua"
cp "src/games/views/dodge_view.lua.backup_phase5" "src/games/views/dodge_view.lua"

# Revert Space Shooter
cp "src/games/space_shooter.lua.backup_phase5" "src/games/space_shooter.lua"

# Remove PhysicsUtils component
rm "src/utils/game_components/physics_utils.lua"
```

## Notes for User

- Trail system now uses PhysicsUtils.createTrailSystem() factory
- Wall bounce physics now uses PhysicsUtils.bounceOffWalls()
- Screen wrap now uses PhysicsUtils.wrapPosition()
- All physics utilities are deterministic and safe for demo playback
- Component includes additional utilities (collision, clamp) for future use

## Expected Results

✅ **Pass Criteria**:
- All variants play identically to before migration
- Trail rendering looks the same
- Wall bounce feels identical
- Screen wrap behavior unchanged
- Demo playback is deterministic
- No performance regressions

❌ **Fail Criteria**:
- Visual differences in trail rendering
- Physics behavior changed
- Demo desync or playback errors
- Performance issues
- Entities getting stuck or glitching

---

**Phase 5 Complete**: 2025-11-12
**Next Phase**: Phase 6 (Popup Manager Component)
