# Start Menu Debug Guide

## Issues to Debug

1. ✅ **FIXED**: Start Menu z-order (now draws on top of windows)
2. ✅ **FIXED**: Start Menu program launching not working

## Expected Console Output

When you start the game, you should immediately see:
```
DesktopState: Subscribing to launch_program event
```

When you click a program in the Start Menu, you should see:
```
DesktopState: Start menu is open, forwarding mousereleased
StartMenuState:mousereleased called, button= 1 open= true
StartMenu: Publishing launch_program event for <program_id>
DesktopState: Start menu consumed = true
DesktopState: Received launch_program event for <program_id>
Attempting to launch program: <program_id>
```

## Debug Scenarios

### Scenario 1: No output at all
**Symptom**: Console is completely empty
**Cause**: Console output not visible or game not running
**Solution**:
- Check if game window opened
- Check console/terminal where you ran `love .`
- Try running from command line: `cd "C:\Users\1just\Documents\10000 games" && love .`

### Scenario 2: See subscription but nothing when clicking
**Output**:
```
DesktopState: Subscribing to launch_program event
(then nothing when clicking)
```
**Cause**: MouseReleased not being called or returning early
**Check**:
- Is Start Menu actually opening?
- Try clicking different items
- Check if clicking ANYWHERE in the menu shows prints

### Scenario 3: See mousereleased but no event
**Output**:
```
StartMenuState:mousereleased called, button= 1 open= true
(but no "Publishing" or "Received")
```
**Cause**: Event handler not being called or returning early
**Check Line**: Check if view returns event properly

### Scenario 4: Event published but not received
**Output**:
```
StartMenu: Publishing launch_program event for launcher
(but no "Received launch_program event")
```
**Cause**: EventBus subscription not working
**Solution**: EventBus implementation bug

### Scenario 5: "No event_bus and no host!"
**Output**:
```
StartMenu: ERROR - No event_bus and no host!
```
**Cause**: DI container not providing eventBus
**Solution**: Check main.lua DI setup

## Quick Fixes to Try

### If EventBus isn't working
The fallback host method should work. The host is provided in DesktopState:
```lua
self.start_menu = StartMenuState:new(self.di, {
    launchProgram = function(program_id) self:launchProgram(program_id) end,
    showTextFileDialog = function(path, content) self:showTextFileDialog(path, content) end
})
```

So even if EventBus fails, it should fall back to host.launchProgram.

### Emergency Bypass
If nothing works, you can bypass the event system entirely by changing StartMenuState line 132:
```lua
-- EMERGENCY BYPASS
if true then  -- Change from: if self.event_bus then
    print("BYPASS: Calling host.launchProgram directly")
    self.host.launchProgram(ev.program_id)
end
```

## Files with Debug Prints

1. `src/states/start_menu_state.lua:118` - mousereleased entry
2. `src/states/start_menu_state.lua:133` - event publish
3. `src/states/desktop_state.lua:182` - subscription setup
4. `src/states/desktop_state.lua:184` - event received
5. `src/states/desktop_state.lua:775` - mousereleased forwarding

## RESOLUTION

### Issue 1: Z-Order - FIXED ✅
**Fix**: Moved start menu drawing from line 330 to 353 in `desktop_state.lua` (after windows draw)
**Result**: Start menu now always appears on top of windows when open

### Issue 2: Program Launching - FIXED ✅
**Root Cause**: Items in cascading panes had `type='executable'` but handler only checked for `type='program'`
**Fix**: Added handler for `type=='executable'` with `program_id` in `start_menu_view.lua:380-381`
**Result**: Programs now launch correctly from Start Menu

### Debug Prints Cleaned Up ✅
All temporary debug prints have been removed. Code is production-ready.

---

**Status**: Both issues resolved. Phase 4.2 & 4.3 complete!
