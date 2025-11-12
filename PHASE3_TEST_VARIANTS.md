# Phase 3: Specific Variants to Test

## 🎯 EXACT VARIANTS TO TEST (By Name)

Based on the variant JSON files, here are the **exact game names** to test for Phase 3 visual effects:

---

## 1. BREAKOUT - Camera Shake & Particles

### ✅ Test These Variants (Visual Effects ENABLED):

#### **"Breakout Classic"** (Default - ALL effects enabled)
- Camera shake: DEFAULT (enabled, intensity 5.0)
- Particles: DEFAULT (enabled)
- **What to test**: Hit bricks, watch for shake + particles

#### **"Breakout Particle Party"**
- Camera shake: ✅ ENABLED (intensity 8.0 - STRONGER than default)
- Particles: ✅ ENABLED
- **What to test**: More intense shake on brick destruction, lots of particles

#### **"Breakout Extreme Shake"**
- Camera shake: ✅ ENABLED (intensity 20.0 - VERY STRONG)
- Particles: ✅ ENABLED
- **What to test**: Massive screen shake, should be very noticeable

#### **"Breakout Visual Madness"**
- Camera shake: ✅ ENABLED
- Particles: ✅ ENABLED
- **What to test**: All visual effects working together

### ❌ Test These Variants (Visual Effects DISABLED):

#### **"Breakout Minimal"**
- Camera shake: ❌ DISABLED
- Particles: ❌ DISABLED
- **What to test**: NO shake, NO particles - completely silent visually

---

## 2. DODGE - Camera Shake (Exponential Decay)

### ✅ Test These Variants (Camera Shake ENABLED):

#### **"Dodge Master"** (Default - Camera shake enabled)
- Camera shake: DEFAULT (enabled, uses exponential decay)
- **What to test**: Collide with obstacles, smooth shake that fades out

#### **"Dodge Deluxe"**
- Camera shake: DEFAULT (enabled)
- Has chasers/shooters for more collision opportunities
- **What to test**: Shake on collisions with various enemy types

#### **"Dodge Chaos"**
- Camera shake: DEFAULT (enabled)
- High difficulty, more obstacles = more shakes
- **What to test**: Frequent shake triggers, smooth decay between collisions

#### **"Dodge One Strike"**
- Camera shake: DEFAULT (enabled)
- Only 1 life - test shake on first collision before game over
- **What to test**: Single collision shake before defeat

### ❌ Test Variant with NO Camera Shake:
**Note**: I don't see any Dodge variants with `camera_shake: 0` explicitly set. All Dodge games inherit the default camera_shake value from runtimeCfg, which is typically > 0. To test disabled shake, you'd need to manually edit a variant or test with `camera_shake: 0` in config.

**Alternative**: Just test the enabled variants to verify shake works correctly.

---

## 3. COIN FLIP - Screen Flash & Confetti

### ✅ Test These Variants (Visual Effects ENABLED):

#### **"Coin Flip Classic"** (Default - ALL effects enabled)
- Screen flash: DEFAULT (enabled)
- Celebration: DEFAULT (enabled)
- **What to test**:
  - Correct guess → GREEN flash
  - Wrong guess → RED flash
  - 5 correct streak → Confetti

#### **"Coin Flip Party Mode"**
- Screen flash: ✅ ENABLED
- Celebration: ✅ ENABLED
- **What to test**: Same as classic, verify all effects work

#### **"Coin Flip Celebration"**
- Screen flash: ✅ ENABLED
- Celebration: ✅ ENABLED (explicitly marked for celebration focus)
- **What to test**: Focus on confetti at streak milestones (5, 10, 15...)

#### **"Coin Flip Voice Announcer"**
- Screen flash: ✅ ENABLED
- Has voice announcements + visual effects
- **What to test**: Flash + voice work together

### ❌ Test This Variant (Visual Effects DISABLED):

#### **"Coin Flip Minimal"**
- Screen flash: ❌ DISABLED
- **What to test**: NO flash on correct/wrong, gameplay only

---

## 4. RPS - Screen Flash & Confetti

### ✅ Test These Variants (Visual Effects ENABLED):

#### **"RPS Classic"** (Default - ALL effects enabled)
- Screen flash: DEFAULT (enabled)
- Celebration: DEFAULT (enabled)
- **What to test**:
  - Win round → GREEN flash
  - Lose round → RED flash
  - Perfect victory → Confetti (30 particles)

#### **"RPS Party Mode"**
- Screen flash: ✅ ENABLED
- **What to test**: All flash effects, confetti on perfect wins

#### **"RPS Slow Mo"**
- Screen flash: ✅ ENABLED
- Slow animation speed
- **What to test**: Flash effects work with slower animation timing

### ❌ Test This Variant (Visual Effects DISABLED):

#### **"RPS Minimal"**
- Screen flash: ❌ DISABLED
- **What to test**: NO flash on win/loss, no confetti

---

## 📋 QUICK TEST CHECKLIST

Copy this checklist and mark off as you test:

### Breakout (4 tests):
- [ ] **Breakout Classic** - Default shake + particles work
- [ ] **Breakout Particle Party** - Stronger shake (8.0)
- [ ] **Breakout Extreme Shake** - Very strong shake (20.0)
- [ ] **Breakout Minimal** - NO effects (verify disabled)

### Dodge (3 tests):
- [ ] **Dodge Master** - Default exponential shake
- [ ] **Dodge Deluxe** - Shake with multiple enemy types
- [ ] **Dodge Chaos** - Frequent shakes, smooth decay

### Coin Flip (4 tests):
- [ ] **Coin Flip Classic** - Green/red flash + confetti
- [ ] **Coin Flip Party Mode** - All effects
- [ ] **Coin Flip Celebration** - Focus on confetti
- [ ] **Coin Flip Minimal** - NO effects (verify disabled)

### RPS (3 tests):
- [ ] **RPS Classic** - Green/red flash + confetti
- [ ] **RPS Party Mode** - All effects
- [ ] **RPS Minimal** - NO effects (verify disabled)

---

## ⏱️ ESTIMATED TEST TIME

- **Breakout**: 2 minutes per variant = 8 minutes
- **Dodge**: 1 minute per variant = 3 minutes
- **Coin Flip**: 1 minute per variant = 4 minutes
- **RPS**: 1 minute per variant = 3 minutes

**Total**: ~18 minutes for complete visual verification

---

## ✅ PASS CRITERIA

For each variant:
- ✅ Visual effects trigger correctly (shake/flash/particles)
- ✅ Effects look identical to pre-Phase 3 migration
- ✅ Timing feels unchanged
- ✅ Disabled variants show NO effects
- ✅ No crashes or errors
- ✅ Demo playback still works (record + replay each game)

---

## 🐛 IF YOU FIND BUGS

1. Note the exact variant name
2. Describe what's wrong (missing effect, wrong timing, crash, etc.)
3. Check if demo playback is affected
4. Report back for fix

Backup files available at `*.backup_phase3` for rollback if needed.
