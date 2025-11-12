# Phase 7: Variant Loader Utility - Testing Guide

## Overview
Phase 7 created VariantLoader utility to simplify three-tier parameter loading (variant → runtime_config → default). Memory Match was migrated as proof-of-concept.

**Games Affected (Currently)**:
- Memory Match (fully migrated)

**Games Ready for Migration**:
- Breakout, Dodge, Snake, Coin Flip, RPS, Space Shooter, Hidden Object

## Test Memory Match

**Variants to Test**:
1. **Memory Match Classic** - Standard configuration
2. **Memory Match Hard** - Higher difficulty variant
3. **Memory Match Easy** - Lower difficulty variant
4. Any variant with custom parameters (time_limit, move_limit, etc.)

**What to Verify**:
- [ ] Game loads without errors
- [ ] All parameters load correctly from variants
- [ ] Runtime config overrides work correctly
- [ ] Default fallbacks work when no variant/config specified
- [ ] No gameplay changes from before migration
- [ ] All variant-specific features work (auto_shuffle, gravity, fog_of_war, etc.)

## Parameter Loading Tests

**Test Three-Tier Lookup**:

1. **Variant Override** (highest priority):
   - Use a variant with `card_count: 16` set
   - Verify game has exactly 16 cards
   - This proves variant overrides runtime config

2. **Runtime Config** (middle priority):
   - Edit config.lua to change memory_match.time_limit
   - Use a variant WITHOUT time_limit specified
   - Verify game uses config value
   - This proves runtime config works when variant doesn't override

3. **Default Fallback** (lowest priority):
   - Use a variant with NO special parameters
   - Verify game uses sensible defaults
   - This proves fallback system works

## Nested Key Access Tests

**Verify Nested Config Works**:
- Check that `loader:get('cards.spacing', DEFAULT)` loads from `runtimeCfg.cards.spacing`
- Check that `loader:get('timings.flip_speed', DEFAULT)` loads from `runtimeCfg.timings.flip_speed`
- Check that `loader:get('arena.width', DEFAULT)` loads from `runtimeCfg.arena.width`

## Type-Specific Getter Tests

**Boolean Handling**:
- Set variant with `gravity_enabled: false` (explicit false, not nil)
- Verify gravity is disabled (not falling back to default true)
- This tests that false ≠ nil handling works correctly

**Number Handling**:
- Set variant with `time_limit: 0` (explicit zero, not nil)
- Verify time limit is actually 0 (unlimited)
- This tests that 0 ≠ nil handling works correctly

## Files Changed

**New Utility**:
- `src/utils/game_components/variant_loader.lua` (156 lines)

**Migrated Files** (backup created with .backup_phase7 extension):
- `src/games/memory_match.lua`

**Lines Changed in Memory Match**:
- Before: 102 lines of repetitive parameter loading
- After: 63 lines using VariantLoader
- Net savings: 39 lines

## Rollback Instructions

If issues found in Memory Match:
```bash
# Revert Memory Match
cp "src/games/memory_match.lua.backup_phase7" "src/games/memory_match.lua"

# Remove VariantLoader utility
rm "src/utils/game_components/variant_loader.lua"
```

## Benefits of VariantLoader

**Before (7 lines per parameter)**:
```lua
local player_speed = (runtimeCfg and runtimeCfg.player and runtimeCfg.player.speed) or DEFAULT_SPEED
if self.variant and self.variant.player_speed ~= nil then
    player_speed = self.variant.player_speed
end
```

**After (1 line per parameter)**:
```lua
local player_speed = loader:getNumber('player_speed', DEFAULT_SPEED)
```

**Additional Features**:
- Nested key access: `loader:get('player.speed', DEFAULT)`
- Type safety: `getNumber()`, `getBoolean()`, `getString()`, `getTable()`
- Batch loading: `loader:getMultiple({ speed = 300, health = 100 })`
- Utility methods: `has(key)`, `getSource(key)` for debugging

## Expected Results

✅ **Pass Criteria**:
- Memory Match plays identically to before migration
- All variant parameters load correctly
- Runtime config overrides work
- Default fallbacks work
- No errors or warnings in console
- Code is significantly more readable

❌ **Fail Criteria**:
- Parameters loading incorrectly
- Variant overrides not working
- Gameplay differences from before
- Errors or crashes
- Boolean/number type handling issues

## Remaining Games to Migrate

If Memory Match tests pass, the following games are ready for VariantLoader migration:
1. **Breakout** - Estimated ~40-50 lines savings
2. **Dodge** - Estimated ~50-60 lines savings (complex parameter set)
3. **Snake** - Estimated ~30-40 lines savings
4. **Coin Flip** - Estimated ~20-30 lines savings
5. **RPS** - Estimated ~30-40 lines savings
6. **Space Shooter** - Estimated ~40-50 lines savings
7. **Hidden Object** - Estimated ~30-40 lines savings

**Projected Total**: ~280-320 additional lines eliminated

## Recommendation

**Incremental Migration Strategy**:
- Migrate games as they're touched for other work
- New games should use VariantLoader from day 1
- No rush to migrate all at once
- Each migration takes ~15-20 minutes
- Pattern is proven and straightforward

---

**Phase 7 Complete (POC)**: 2025-11-12
**Status**: VariantLoader utility complete and proven effective
**Next Steps**: Migrate remaining games incrementally OR proceed to Phase 8/10+
