# Phase 3: Visual Effects Component - Testing Checklist

**Completed**: 2025-01-12
**Component**: `src/utils/game_components/visual_effects.lua`
**Lines Eliminated**: ~145 lines across 4 games

---

## ✅ Phase 3 Complete Summary

### Migrated Games:
1. **Breakout** - Camera shake (timer mode) + particles
2. **Dodge** - Camera shake (exponential decay mode)
3. **Coin Flip** - Screen flash + confetti particles
4. **RPS** - Screen flash + confetti particles

### Backup Files Created:
All original files backed up with `.backup_phase3` extension in case rollback is needed.

---

## 🧪 Required Testing

Test these specific game variants that have visual effects **ENABLED**:

### 1. Breakout - Camera Shake & Particles

**What to Test**:
- Camera shake triggers on brick destruction
- Shake lasts ~150ms (timer-based, not exponential)
- Particles spawn on brick destruction (colored based on brick health)
- Ball trail particles appear behind moving balls

**Variants to Test**:
```
Any Breakout variant with:
- camera_shake_enabled: true (default)
- camera_shake_intensity: 5.0 (default) or higher
- particle_effects_enabled: true (default)
```

**How to Test**:
1. Launch any standard Breakout game
2. Hit a brick - should see brief screen shake
3. Watch for colored particle burst at brick location
4. Watch ball - should have trailing particles

**Expected Behavior**:
- Shake is brief and sharp (timer mode)
- Particles match brick color
- Ball trails visible during movement
- All effects can be disabled via variant parameters

---

### 2. Dodge - Camera Shake

**What to Test**:
- Camera shake triggers on collision with obstacle
- Shake uses exponential decay (smooth fade-out, not instant)
- Shake intensity varies based on `camera_shake` parameter

**Variants to Test**:
```
Any Dodge variant with:
- camera_shake: > 0 (default varies, typically 5.0-10.0)
```

**How to Test**:
1. Launch any Dodge game
2. Collide with an obstacle
3. Observe camera shake effect

**Expected Behavior**:
- Shake starts strong, smoothly decays to zero
- More intense shakes last longer
- Multiple collisions can stack intensity
- Shake can be disabled by setting camera_shake: 0

---

### 3. Coin Flip - Screen Flash & Confetti

**What to Test**:
- GREEN flash on correct guess
- RED flash on wrong guess
- Confetti particles on streak milestones (every 5 correct)

**Variants to Test**:
```
Any Coin Flip variant with:
- screen_flash_enabled: true (default)
- celebration_on_streak: true (default)
```

**How to Test**:
1. Launch Coin Flip game
2. Make correct guess (heads/tails) - should see green flash
3. Make wrong guess - should see red flash
4. Get 5 correct in a row - should see confetti explosion

**Expected Behavior**:
- Flash covers full screen briefly (~200ms)
- Green = correct, Red = wrong
- Flash fades out smoothly
- Confetti spawns at center on streaks of 5, 10, 15, etc.

---

### 4. RPS - Screen Flash & Confetti

**What to Test**:
- GREEN flash on round win
- RED flash on round loss
- Confetti particles on perfect game victory (no losses)

**Variants to Test**:
```
Any RPS variant with:
- screen_flash_enabled: true (default)
- celebration_on_perfect: true (default)
```

**How to Test**:
1. Launch RPS game
2. Win a round - should see green flash
3. Lose a round - should see red flash
4. Win entire game without losing - should see massive confetti

**Expected Behavior**:
- Flash covers full screen briefly (~200ms)
- Green = win, Red = loss
- Flash fades out smoothly
- Confetti only triggers on perfect victories (30 particles)

---

## 🔧 Variants with Effects DISABLED

Test that disabling effects works correctly:

### Breakout Variants:
- `camera_shake_enabled: false` - No shake on brick destruction
- `particle_effects_enabled: false` - No particles anywhere

### Dodge Variants:
- `camera_shake: 0` - No shake on collision

### Coin Flip Variants:
- `screen_flash_enabled: false` - No flash on correct/wrong
- `celebration_on_streak: false` - No confetti on streaks

### RPS Variants:
- `screen_flash_enabled: false` - No flash on win/loss
- `celebration_on_perfect: false` - No confetti on perfect win

**Expected**: All visual effects completely disabled, gameplay unaffected

---

## ⚠️ CRITICAL: Demo Playback Testing

**MOST IMPORTANT TEST**: Visual effects must NOT affect demo playback determinism.

### Test Process:
1. Record a demo of each game (play normally)
2. Play back the demo via VM
3. Verify demo completes identically every time
4. Test with visual effects enabled AND disabled
5. Ensure token rewards are identical

**Why This Matters**:
Visual effects are purely cosmetic. They use `math.random()` for shake offsets and particle directions, but this randomness MUST NOT affect:
- Game logic
- Player position
- Collision detection
- Score calculation
- RNG seed for gameplay

**If demos desync**: Visual effects are reading from the wrong RNG source or affecting game state (BUG - needs immediate fix)

---

## 🎯 Quick Test Script

To quickly test all visual effects:

1. **Breakout**: Launch game, destroy 3-4 bricks rapidly
   - ✅ Shake + particles visible

2. **Dodge**: Launch game, hit 2-3 obstacles
   - ✅ Shake visible with smooth decay

3. **Coin Flip**: Make 5 correct guesses in a row
   - ✅ Green flash each time + confetti on 5th

4. **RPS**: Win 3 rounds without losing
   - ✅ Green flash on each win + confetti at end

**Total test time**: ~5 minutes for full verification

---

## 📊 Success Criteria

- [x] Phase 3 complete (all 4 games migrated)
- [ ] All visual effects look identical to pre-migration
- [ ] Timing and feel unchanged
- [ ] Effects can be disabled via variants
- [ ] Demo playback still deterministic
- [ ] No performance regression
- [ ] No crashes or errors

---

## 🐛 Known Issues / Edge Cases

*None encountered during migration*

---

## 🔄 Rollback Instructions

If issues are found:

```bash
# Restore original files
cp src/games/breakout.lua.backup_phase3 src/games/breakout.lua
cp src/games/views/breakout_view.lua.backup_phase3 src/games/views/breakout_view.lua
cp src/games/dodge_game.lua.backup_phase3 src/games/dodge_game.lua
cp src/games/views/dodge_view.lua.backup_phase3 src/games/views/dodge_view.lua
cp src/games/coin_flip.lua.backup_phase3 src/games/coin_flip.lua
cp src/games/views/coin_flip_view.lua.backup_phase3 src/games/views/coin_flip_view.lua
cp src/games/rps.lua.backup_phase3 src/games/rps.lua
cp src/games/views/rps_view.lua.backup_phase3 src/games/views/rps_view.lua

# Delete VisualEffects component
rm src/utils/game_components/visual_effects.lua
```

Then commit the rollback and report issues.

---

## ✨ Next Steps

After Phase 3 verification passes:
- Proceed to **Phase 4: Animation System Component** (flip/throw animations)
- Continue with remaining phases 5-9
- Eventually tackle new Phases 10-16 (HUD, Victory Conditions, etc.)

**Current Progress**: 837 lines eliminated across Phases 1-3 ✅
