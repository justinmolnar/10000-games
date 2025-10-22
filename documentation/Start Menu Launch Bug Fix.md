# Start Menu Launch Bug - Root Cause & Fix

**Date**: 2025-10-21
**Status**: ✅ FIXED

---

## Problem

Programs were not launching when clicked in the Start Menu. The Start Menu would close, but nothing would happen - no windows would open.

---

## Root Cause

**Location**: `src/states/desktop_state.lua:113`

The `DesktopState:init()` method had an early `return` statement in the wallpaper image recovery code:

```lua
if raw_img and raw_img ~= '' then
    self.wallpaper_image = raw_img
    -- Prewarm cache
    if WP.getImageCached then pcall(WP.getImageCached, self.wallpaper_image) end
    -- Persist back to ensure consistency
    pcall(SettingsManager.set, 'desktop_bg_image', raw_img)
    return  -- ❌ BUG: Exits init() early!
end
```

**What happened**:
1. When the game loaded, if a wallpaper image existed in `settings.json`
2. The wallpaper recovery code would execute
3. The `return` statement would **exit `init()` completely**
4. The EventBus subscription code at line 184 **never ran**
5. DesktopState never subscribed to the `launch_program` event
6. When StartMenuState published `launch_program` events, no one was listening

---

## The Fix

**Changed line 113** from:
```lua
return
```

**To**:
```lua
goto wallpaper_resolved
```

**And added label at line 132**:
```lua
::wallpaper_resolved::
```

This allows the wallpaper recovery code to skip the default wallpaper logic below it, **while still continuing to the EventBus subscription code**.

---

## Files Modified

### src/states/desktop_state.lua
- Line 113: Changed `return` to `goto wallpaper_resolved`
- Line 132: Added `::wallpaper_resolved::` label
- **Result**: init() now completes fully and subscribes to EventBus events

---

## Why It Worked Before

The bug was **conditional** - it only triggered when:
1. A wallpaper image was saved in settings.json
2. The wallpaper image ID was recovered from the raw settings file

If you had no saved wallpaper, or if the recovery path wasn't triggered, the `return` wouldn't execute and init() would complete normally.

This explains why "it WAS working, for awhile even, no issues" - the bug was dormant until the specific wallpaper recovery condition was met.

---

## Event Flow (Now Working)

```
User clicks program in Start Menu
  → StartMenuView returns {name='launch_program', program_id=...}
    → StartMenuState:mousereleased() receives event
      → StartMenuState publishes 'launch_program' via EventBus
        → DesktopState subscriber receives event (NOW WORKING!)
          → DesktopState:launchProgram() executes
            → Program window opens ✅
```

---

## Additional Fixes

While debugging, we also fixed:

1. **Start Menu Z-Order** (`desktop_state.lua:353`)
   - Moved start menu drawing after windows
   - Start menu now appears on top when open

2. **Executable Type Handler** (`start_menu_view.lua:380-381`)
   - Added check for `type=='executable'` with `program_id`
   - Handles cascading pane items correctly

3. **Txt File Opening** (`desktop_state.lua:510-521`)
   - Added file shortcut detection
   - Txt files now open in text dialog instead of trying to launch as programs

---

## Testing

✅ Programs launch from Start Menu
✅ Run dialog opens
✅ Shutdown dialog opens
✅ Txt files open from Start Menu → Documents
✅ Txt files open from desktop icons
✅ Start menu appears on top of windows

---

## Lesson Learned

**Never use early `return` in initialization methods unless you're certain all critical setup has completed.**

A better pattern would be:
```lua
local should_use_default = true
if raw_img and raw_img ~= '' then
    self.wallpaper_image = raw_img
    -- ... setup code ...
    should_use_default = false
end

if should_use_default then
    -- ... default logic ...
end

-- Critical setup always runs
self:subscribeToEvents()
```

Or use the `goto` pattern as we did here when modifying existing code.

---

**Fixed by**: Claude Code
**Date**: 2025-10-21
