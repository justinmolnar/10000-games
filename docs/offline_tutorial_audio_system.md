# Offline Tutorial: Audio System Activation

## Goal
The audio system is fully coded but inactive. Your job is to create the JSON definitions and wire up sound playback in games.

## Difficulty: Easy (1-2 hours)

## Files to Study First
Read these before starting:
- `src/utils/audio_manager.lua` - The complete audio system (already written)
- `src/games/coin_flip.lua` - A simple game to add sounds to
- `src/config.lua` - Where volume defaults live

## How the Audio System Works

The `AudioManager` loads sound definitions from a JSON file, then games call:
```lua
self.di.audioManager:playSound("pack_name", "action_name")
```

Volume is calculated as: `master_volume * sfx_volume * override`

SFX are loaded as "static" (fully in memory, can overlap).
Music is loaded as "stream" (lower memory, one at a time).

---

## Step 1: Create the Directory Structure

Create these folders if they don't exist:
```
assets/
  audio/
    data/
    sfx/
    music/
```

## Step 2: Create SFX Pack Definitions

Create `assets/audio/data/sfx_packs.json`:

```json
{
  "ui": {
    "sounds": {
      "click": "assets/audio/sfx/click.ogg",
      "hover": "assets/audio/sfx/hover.ogg",
      "error": "assets/audio/sfx/error.ogg"
    }
  },
  "coin_flip": {
    "sounds": {
      "flip": "assets/audio/sfx/coin_flip.ogg",
      "correct": "assets/audio/sfx/correct.ogg",
      "wrong": "assets/audio/sfx/wrong.ogg",
      "victory": "assets/audio/sfx/victory.ogg"
    }
  },
  "generic_game": {
    "sounds": {
      "hit": "assets/audio/sfx/hit.ogg",
      "death": "assets/audio/sfx/death.ogg",
      "pickup": "assets/audio/sfx/pickup.ogg",
      "victory": "assets/audio/sfx/victory.ogg",
      "defeat": "assets/audio/sfx/defeat.ogg"
    }
  },
  "raycaster": {
    "sounds": {
      "footstep": "assets/audio/sfx/footstep.ogg",
      "goal": "assets/audio/sfx/goal.ogg"
    }
  }
}
```

## Step 3: Get Sound Files (Before Your Flight!)

You need `.ogg` or `.wav` files. Free sources:
- https://freesound.org
- https://opengameart.org
- https://kenney.nl/assets (has UI sounds)

Download a few simple sounds:
- Click/beep for UI
- Coin flip sound
- Win jingle
- Lose buzzer
- Footstep

Save them to `assets/audio/sfx/` with matching names from your JSON.

**Tip:** If you don't have sounds, the system will silently fail (no crashes).

## Step 4: Wire Up AudioManager in DI

Check `main.lua` to see if AudioManager is already in the DI container. Look for something like:

```lua
local AudioManager = require('src.utils.audio_manager')
-- ...
di.audioManager = AudioManager:new(di)
```

If it's not there, add it.

## Step 5: Add Sounds to Coin Flip

Open `src/games/coin_flip.lua` and find these locations:

### In `onCorrectFlip()` (around line 343):
```lua
function CoinFlip:onCorrectFlip()
    -- Add at the start of this function:
    if self.di and self.di.audioManager then
        self.di.audioManager:playSound("coin_flip", "correct")
    end

    -- ...rest of existing code...
end
```

### In `onIncorrectFlip()` (around line 390):
```lua
function CoinFlip:onIncorrectFlip()
    -- Add at the start:
    if self.di and self.di.audioManager then
        self.di.audioManager:playSound("coin_flip", "wrong")
    end

    -- ...rest of existing code...
end
```

### In `makeGuess()` or `flipCoin()` for the flip sound:
```lua
function CoinFlip:flipCoin()
    if self.di and self.di.audioManager then
        self.di.audioManager:playSound("coin_flip", "flip")
    end

    -- ...rest of existing code...
end
```

## Step 6: Test It

1. Run the game: `love .`
2. Open the launcher, find a Coin Flip variant
3. Play it - you should hear sounds on flip/win/lose

**Debug tip:** Check the console for `[AudioManager]` messages. It logs when packs load or fail.

---

## Step 7: Add Sounds to Raycaster (Optional)

Open `src/games/raycaster.lua`:

### Footsteps in `handleInput()`:
```lua
function Raycaster:handleInput(dt)
    -- At the end, after movement is applied:
    if move_x ~= 0 or move_y ~= 0 then
        -- Throttle footstep sounds
        self.footstep_timer = (self.footstep_timer or 0) - dt
        if self.footstep_timer <= 0 then
            if self.di and self.di.audioManager then
                self.di.audioManager:playSound("raycaster", "footstep", 0.5)
            end
            self.footstep_timer = 0.4  -- Play every 0.4 seconds
        end
    end
end
```

### Goal reached in `checkGoal()`:
```lua
function Raycaster:checkGoal()
    local px, py = PhysicsUtils.worldToTile(self.player.x, self.player.y)
    if px == self.goal.x and py == self.goal.y then
        if self.di and self.di.audioManager then
            self.di.audioManager:playSound("raycaster", "goal")
        end
        -- ...rest of existing code...
    end
end
```

---

## Stretch Goals

1. **Add music:** Use `audioManager:playMusic("assets/audio/music/menu.ogg")` in desktop state
2. **Volume settings UI:** The settings already have volume keys, just need UI sliders
3. **Per-variant sounds:** Add `sfx_pack` to variant JSON, load different sounds per game clone

## Common Issues

| Problem | Solution |
|---------|----------|
| No sound, no errors | Check file paths in JSON match actual files |
| "Could not read sfx_packs.json" | Check the path is exactly `assets/audio/data/sfx_packs.json` |
| Sound plays but no audio | Check system volume, check `master_volume` in settings |
| Sound only plays once | That's correct - cloning handles overlaps, but rapid fire needs throttling |

## Key Patterns Learned

- **Graceful degradation:** AudioManager silently fails if sounds missing
- **DI pattern:** Games access shared services via `self.di.audioManager`
- **JSON-driven config:** Sound definitions in data files, not code
