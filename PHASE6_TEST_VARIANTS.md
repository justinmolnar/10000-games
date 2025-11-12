# Phase 6: Popup Manager Component - Testing Variants

## Overview
Phase 6 extracted score popup management into PopupManager component to eliminate duplicated lifecycle code.

**Games Affected**:
- Breakout (score popups on brick destruction)
- Coin Flip (score popups on flip results)
- RPS (score popups on round results)

## Test Variants

### Breakout - Score Popup Tests

**Variants to Test**:
1. **Breakout Classic** - Standard brick destruction popups
2. **Breakout Plus** - Enhanced scoring with combo multipliers
3. Any variant with `score_popup_enabled: true` parameter

**What to Verify**:
- [ ] Score popups appear when bricks are destroyed
- [ ] Popup text shows correct score values ("+" prefix)
- [ ] Popups rise upward and fade out smoothly
- [ ] Multiple popups can be active simultaneously
- [ ] Combo popups use yellow color for milestones (5/10/15 combo)
- [ ] "EXTRA LIFE!" popup appears in green when extra ball threshold reached
- [ ] "PERFECT CLEAR!" popup appears in green when all bricks cleared without losing balls
- [ ] Popup timing feels identical to before migration

### Coin Flip - Score Popup Tests

**Variants to Test**:
1. **Coin Flip Classic** - Basic guess mode with popups
2. **Coin Flip Auto** - Auto-flip mode with popups
3. Any variant with score popups enabled

**What to Verify**:
- [ ] Score popups appear after each flip result
- [ ] Popup color matches result (green = correct/heads, red = wrong/tails, yellow = streak milestone)
- [ ] Popup text shows correct point values
- [ ] "PERFECT! +[bonus]" popup appears in green when perfect streak achieved
- [ ] Popups centered horizontally on screen
- [ ] Multiple popups can stack if flipping quickly

### RPS - Score Popup Tests

**Variants to Test**:
1. **RPS Classic** - Standard rock-paper-scissors
2. **RPS Tournament** - Multiple opponents mode
3. Any variant with special rounds enabled

**What to Verify**:
- [ ] Score popups appear after each round result
- [ ] Popup color matches result (green = win, red = lose, yellow = tie/special)
- [ ] Win streak bonuses show correct multipliers
- [ ] "PERFECT GAME! +[bonus]" popup appears in green when perfect game achieved
- [ ] Special round bonuses display correctly
- [ ] Popups centered horizontally on screen

## General Popup Behavior Tests

**All Games Should Exhibit**:
- [ ] Popups rise at 50 pixels/second
- [ ] Popups fade from alpha 1.0 → 0.0 over their duration (default 1.5s)
- [ ] Popups automatically removed when duration expires
- [ ] No memory leaks (popups properly garbage collected)
- [ ] No visual glitches or jittering
- [ ] Popup rendering performance is smooth

## Code Verification

**Check Migration Was Successful**:
- [ ] All games use `self.popup_manager = PopupManager:new()` in init
- [ ] All games use `self.popup_manager:update(dt)` instead of manual loop
- [ ] All games use `self.popup_manager:add()` instead of `table.insert(self.score_popups, ScorePopup:new())`
- [ ] All views use `self.game.popup_manager:draw()` instead of manual loop
- [ ] No references to `self.score_popups` array remain in migrated games

## Files Changed

**Migrated Files** (backups created with .backup_phase6 extension):
- `src/games/breakout.lua`
- `src/games/views/breakout_view.lua`
- `src/games/coin_flip.lua`
- `src/games/views/coin_flip_view.lua`
- `src/games/rps.lua`
- `src/games/views/rps_view.lua`

**Extended Component**:
- `src/games/score_popup.lua` (53 lines added for PopupManager)

**Lines Eliminated**: 51 lines total
- breakout: 19 lines (15 + 4)
- coin_flip: 17 lines (13 + 4)
- rps: 15 lines (11 + 4)

## Rollback Instructions

If issues found:
```bash
# Revert Breakout
cp "src/games/breakout.lua.backup_phase6" "src/games/breakout.lua"
cp "src/games/views/breakout_view.lua.backup_phase6" "src/games/views/breakout_view.lua"

# Revert Coin Flip
cp "src/games/coin_flip.lua.backup_phase6" "src/games/coin_flip.lua"
cp "src/games/views/coin_flip_view.lua.backup_phase6" "src/games/views/coin_flip_view.lua"

# Revert RPS
cp "src/games/rps.lua.backup_phase6" "src/games/rps.lua"
cp "src/games/views/rps_view.lua.backup_phase6" "src/games/views/rps_view.lua"

# Revert PopupManager
cp "src/games/score_popup.lua.backup_phase6" "src/games/score_popup.lua"
```

## Notes for User

- PopupManager centralizes popup lifecycle (add, update, remove)
- Same ScorePopup class used internally - rendering unchanged
- Simplified game code: 7 lines of update loop → 1 line
- Simplified view code: 3-4 lines of draw loop → 1 line
- Backward compatible: ScorePopup can still be used directly if needed
- Future games can use PopupManager from the start

## Expected Results

✅ **Pass Criteria**:
- All popups appear at correct times
- Popup text and colors match expected values
- Popup animations (rise + fade) look identical to before
- No visual differences in popup behavior
- No performance regressions
- Code is cleaner and more maintainable

❌ **Fail Criteria**:
- Popups not appearing when expected
- Wrong colors or text values
- Popup lifecycle issues (not removing dead popups)
- Visual glitches or animation differences
- Performance degradation

---

**Phase 6 Complete**: 2025-11-12
**Next Phase**: Phase 7 (Variant Loader Utility - Optional)
