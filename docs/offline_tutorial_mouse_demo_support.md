# Offline Tutorial: Mouse Support for Demo Recorder

## Goal
Extend the demo recording/playback system to capture and replay mouse inputs. Currently it only handles keyboard.

## Difficulty: Medium (3-4 hours)

## Files to Study First
- `src/models/demo_recorder.lua` - Records inputs (164 lines, simple)
- `src/models/demo_player.lua` - Plays back inputs (262 lines)
- `src/games/base_game.lua` - Where recording hooks into games

## Current Limitation

The demo system records:
```lua
{key = "space", state = "pressed", frame = 42}
```

But games like Hidden Object or Memory Match need mouse clicks, which aren't recorded.

---

## Step 1: Understand the Current Flow

### Recording:
1. Game calls `demoRecorder:startRecording(game_id, variant)`
2. Every frame, `demoRecorder:fixedUpdate()` increments frame counter
3. On key press, `demoRecorder:recordKeyPressed(key)` stores `{key, state, frame}`
4. On completion, `demoRecorder:stopRecording()` returns the demo data

### Playback:
1. `demoPlayer:startPlayback(demo, game_instance)` begins
2. Every frame, `demoPlayer:stepFrame()` checks if any inputs match current frame
3. Matching inputs call `game_instance:keypressed(key)` or `keyreleased(key)`
4. Game runs deterministically with injected inputs

---

## Step 2: Extend DemoRecorder

Open `src/models/demo_recorder.lua` and add mouse recording methods:

### Add after `recordKeyReleased` (around line 148):

```lua
-- Record a mouse press
-- @param x: number - X position (should be relative to game viewport)
-- @param y: number - Y position (should be relative to game viewport)
-- @param button: number - Mouse button (1 = left, 2 = right, 3 = middle)
function DemoRecorder:recordMousePressed(x, y, button)
    if not self.is_recording then
        return
    end

    table.insert(self.inputs, {
        type = "mouse",
        x = x,
        y = y,
        button = button,
        state = "pressed",
        frame = self.frame_count
    })
end

-- Record a mouse release
function DemoRecorder:recordMouseReleased(x, y, button)
    if not self.is_recording then
        return
    end

    table.insert(self.inputs, {
        type = "mouse",
        x = x,
        y = y,
        button = button,
        state = "released",
        frame = self.frame_count
    })
end

-- Record mouse movement (use sparingly - generates lots of data)
-- Only record if position changed significantly
function DemoRecorder:recordMouseMoved(x, y)
    if not self.is_recording then
        return
    end

    -- Check if we should record this movement
    local last_move = self.last_mouse_pos
    if last_move then
        local dx = math.abs(x - last_move.x)
        local dy = math.abs(y - last_move.y)
        -- Only record if moved more than 5 pixels
        if dx < 5 and dy < 5 then
            return
        end
    end

    self.last_mouse_pos = {x = x, y = y}

    table.insert(self.inputs, {
        type = "mouse_move",
        x = x,
        y = y,
        frame = self.frame_count
    })
end
```

### Update the init function to track mouse position:

```lua
function DemoRecorder:init(di)
    -- ... existing code ...
    self.last_mouse_pos = nil  -- Add this line
end
```

### Update `cancelRecording` and `stopRecording` to reset mouse state:

```lua
function DemoRecorder:cancelRecording()
    -- ... existing code ...
    self.last_mouse_pos = nil  -- Add this line
end
```

---

## Step 3: Extend DemoPlayer

Open `src/models/demo_player.lua` and modify the `injectInput` function (around line 183):

### Replace the entire `injectInput` function:

```lua
-- Inject an input into the game instance
function DemoPlayer:injectInput(input)
    if not self.game_instance then
        return
    end

    -- Handle mouse inputs
    if input.type == "mouse" then
        if input.state == "pressed" then
            if self.game_instance.mousepressed then
                local success, err = pcall(
                    self.game_instance.mousepressed,
                    self.game_instance,
                    input.x,
                    input.y,
                    input.button
                )
                if not success then
                    print("[DemoPlayer] ERROR calling mousepressed: " .. tostring(err))
                end
            end
        elseif input.state == "released" then
            if self.game_instance.mousereleased then
                local success, err = pcall(
                    self.game_instance.mousereleased,
                    self.game_instance,
                    input.x,
                    input.y,
                    input.button
                )
                if not success then
                    print("[DemoPlayer] ERROR calling mousereleased: " .. tostring(err))
                end
            end
        end
        return
    end

    -- Handle mouse movement
    if input.type == "mouse_move" then
        if self.game_instance.mousemoved then
            local success, err = pcall(
                self.game_instance.mousemoved,
                self.game_instance,
                input.x,
                input.y,
                0, 0  -- dx, dy not tracked
            )
            if not success then
                print("[DemoPlayer] ERROR calling mousemoved: " .. tostring(err))
            end
        end
        -- Also update love.mouse position for games that poll it
        -- Note: This won't work perfectly since love.mouse.setPosition
        -- affects the actual cursor. Games should use injected values.
        return
    end

    -- Handle keyboard inputs (existing code)
    if input.state == "pressed" then
        if self.game_instance.keypressed then
            local success, err = pcall(self.game_instance.keypressed, self.game_instance, input.key)
            if not success then
                print("[DemoPlayer] ERROR calling keypressed: " .. tostring(err))
            end
        else
            print("[DemoPlayer] WARNING: game_instance has no keypressed method!")
        end
    elseif input.state == "released" then
        if self.game_instance.keyreleased then
            local success, err = pcall(self.game_instance.keyreleased, self.game_instance, input.key)
            if not success then
                print("[DemoPlayer] ERROR calling keyreleased: " .. tostring(err))
            end
        else
            print("[DemoPlayer] WARNING: game_instance has no keyreleased method!")
        end
    end
end
```

---

## Step 4: Hook Mouse Events in Games

Games need to forward mouse events to the recorder. This happens in the state that hosts the game, not in BaseGame itself.

Find where games handle mouse input (likely in a minigame state). Look for `mousepressed` callbacks.

### Example integration pattern:

```lua
-- In the state that runs minigames (e.g., minigame_state.lua)

function MinigameState:mousepressed(x, y, button)
    -- Convert screen coords to game viewport coords
    local game_x = x - self.viewport_x
    local game_y = y - self.viewport_y

    -- Record for demo
    if self.demo_recorder and self.demo_recorder:isRecording() then
        self.demo_recorder:recordMousePressed(game_x, game_y, button)
    end

    -- Forward to game
    if self.game and self.game.mousepressed then
        self.game:mousepressed(game_x, game_y, button)
    end
end

function MinigameState:mousereleased(x, y, button)
    local game_x = x - self.viewport_x
    local game_y = y - self.viewport_y

    if self.demo_recorder and self.demo_recorder:isRecording() then
        self.demo_recorder:recordMouseReleased(game_x, game_y, button)
    end

    if self.game and self.game.mousereleased then
        self.game:mousereleased(game_x, game_y, button)
    end
end
```

**Important:** Record viewport-relative coordinates, not screen coordinates! Otherwise playback will click in wrong positions if window moves.

---

## Step 5: Handle Games That Poll Mouse Position

Some games might use `love.mouse.getPosition()` directly instead of callbacks. This is problematic for playback.

### Option A: Modify games to use callbacks (recommended)
Convert any `love.mouse.getPosition()` calls to use stored state that gets updated via `mousemoved`.

### Option B: Add mouse position to game instance during playback
In `DemoPlayer:injectInput` for mouse_move:
```lua
if input.type == "mouse_move" then
    -- Store position on game instance for polling
    self.game_instance._demo_mouse_x = input.x
    self.game_instance._demo_mouse_y = input.y
    -- ... rest of code
end
```

Then games check:
```lua
function MyGame:getMousePosition()
    if self._demo_mouse_x then
        return self._demo_mouse_x, self._demo_mouse_y
    end
    return love.mouse.getPosition()
end
```

---

## Step 6: Test It

1. Find a game that uses mouse (Memory Match, Hidden Object)
2. Play it manually - watch console for recording messages
3. Complete the game and save the demo
4. Assign demo to a VM
5. Watch VM playback - mouse clicks should replay

### Debug tips:
- Add print statements in `recordMousePressed` to verify recording
- Add print statements in `injectInput` to verify playback
- Check that coordinates are reasonable (within viewport bounds)

---

## Coordinate Systems Warning

This is the trickiest part. Mouse coordinates must be consistent between recording and playback:

| Scenario | Coordinates |
|----------|-------------|
| Recording | Relative to game viewport (not screen) |
| Playback | Same relative coordinates |
| Game receives | Always viewport-relative |

If you record screen coordinates but play back into a moved window, clicks will miss.

---

## Step 7: Update Demo Format (Optional)

For backwards compatibility, you might want to version the demo format:

```lua
-- In stopRecording():
local demo = {
    version = 2,  -- Bump version for mouse support
    game_id = self.game_id,
    -- ...
}
```

```lua
-- In startPlayback():
if demo.version and demo.version < 2 then
    print("[DemoPlayer] Warning: Old demo format, mouse inputs not supported")
end
```

---

## Stretch Goals

1. **Mouse wheel support:** Record `wheelmoved(x, y)` events
2. **Drag tracking:** Detect press-move-release sequences
3. **Input visualization:** Show mouse cursor position during playback
4. **Coordinate interpolation:** Smooth mouse movement between recorded positions

## Common Issues

| Problem | Solution |
|---------|----------|
| Clicks in wrong position | Coordinate system mismatch - ensure viewport-relative |
| No mouse events recorded | Check if state forwards to recorder |
| Playback clicks don't register | Game may not have `mousepressed` method |
| Too much data recorded | Increase threshold in `recordMouseMoved` or disable it |

## Key Patterns Learned

- **Input abstraction:** Games receive inputs the same way whether live or playback
- **Coordinate normalization:** Always convert to game-local coordinates
- **Backwards compatibility:** Version your data formats
- **Defensive coding:** Check if methods exist before calling
