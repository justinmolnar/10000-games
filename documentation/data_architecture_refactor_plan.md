# Data Architecture Refactor Plan
**Comprehensive Phased Action Plan for Self-Describing Game System**

---

## Executive Summary

This plan refactors the game loading system from hardcoded mappings scattered across 10+ files to a **self-describing, data-driven architecture** where games are discovered automatically from variant JSON files.

**Current Problem**: Adding a game requires updating 7+ hardcoded mapping tables across multiple files. Missing one mapping → bugs like "only 3 games loading instead of 20".

**Solution**: Variant JSON files become self-describing with metadata. Config.lua only contains technical defaults. Sprites/sounds become reusable assets referenced by ID.

**Impact**: Adding a new game = write game code + add variant JSON. No code changes to loading system.

---

## Current State Analysis

### The "3 Games Loading" Bug Root Cause

**What Happened**: Memory Match variants weren't loading because:
1. Variant file is `memory_match_variants.json`
2. Base game ID is `memory_1`
3. Three separate mapping tables tried to map between these
4. One table was missing the mapping → fallback to default 3 variants

**Symptom of Systemic Issue**: No single source of truth for game metadata.

### Duplicate Mapping Tables Found

**1. Game ID to Variant File** (appears 3 times):
- `src/models/game_data.lua:103-112` - `variant_file_to_base_id`
- `src/models/game_data.lua:238-245` - `id_to_variant_file`
- `src/models/game_variant_loader.lua:42-47` - `variant_files` array

**2. Game Class to Sprite Folder** (appears 4 times):
- `src/views/launcher_view.lua:417-424` - in `drawGameCard()`
- `src/views/launcher_view.lua:632-639` - in `drawGameDetailPanel()`
- `src/views/formula_renderer.lua:116-123` - in `getTokenSprite()`
- `src/models/game_variant_loader.lua:197-205` - in `getGameTypeFromClass()`

**3. Sprite Loading Logic** (duplicated 157 lines):
- Same fallback pattern copy-pasted in 3 locations
- Same class→filename mapping logic repeated
- Each location must be updated when sprite system changes

### Current Required Changes to Add a Game

To add "Hidden Object" currently requires:
1. ✅ Write game code (HiddenObject.lua + view)
2. ❌ Add to `variant_file_to_base_id` in game_data.lua
3. ❌ Add to `id_to_variant_file` in game_data.lua
4. ❌ Add to `variant_files` array in game_variant_loader.lua
5. ❌ Add to `class_to_folder` in launcher_view.lua (2 places!)
6. ❌ Add to `class_to_folder` in formula_renderer.lua
7. ❌ Add to `getGameTypeFromClass()` in game_variant_loader.lua
8. ❌ Create entry in base_game_definitions.json

**Miss even one → silent failures or default fallbacks.**

---

## Target Architecture

### Data Hierarchy

```
1. Variant JSON files (variants/*.json) - PRIMARY SOURCE
   ↓ (if field missing)
2. Config defaults (config.lua) - TECHNICAL DEFAULTS
   ↓ (if missing)
3. Hardcoded safe defaults - LAST RESORT
```

### Three-Level Inheritance

**Example for Dodge:**

```
Config Default (config.lua):
{
  game_class: "DodgeGame",
  lives: 3,
  speed: 1.0,
  sprite_set: "base_1",
  required_sprites: ["player.png", "enemy.png"]
}
    ↓
Variant File (dodge_variants.json):
{
  game_class: "DodgeGame",
  sprite_folder: "dodge",
  category: "action",
  lives: 5  // Override config default
}
    ↓
Individual Variant:
{
  clone_index: 1,
  name: "Dodge Hell Mode",
  lives: 1,  // Override file default
  speed: 2.0  // Override config default
}
```

**Result**: Variant gets `lives: 1, speed: 2.0, sprite_folder: "dodge", category: "action"`

### Self-Describing JSON Structure

**New Format**: `variants/dodge_variants.json`
```json
{
  "game_class": "DodgeGame",
  "sprite_folder": "dodge",
  "default_sprite_set": "dodge_base",
  "default_sound_pack": "retro_beeps",
  "category": "action",
  "tier": "trash",

  "variants": [
    {
      "clone_index": 0,
      "name": "Dodge Classic"
      // Inherits all defaults
    },
    {
      "clone_index": 1,
      "name": "Dodge Puzzle",
      "category": "puzzle",  // Override: same mechanics, different category
      "sprite_set": "custom_pack"  // Override: different art
    }
  ]
}
```

**Key Fields**:
- `game_class`: What code to instantiate (links to config.game_defaults)
- `sprite_folder`: Where game sprites live (no more class→folder mapping!)
- `category`, `tier`: Metadata (can be overridden per variant)
- `variants`: Array of clones with overrides

### Sprite Set System

**New File**: `assets/data/sprite_sets.json`
```json
{
  "sprite_sets": [
    {
      "id": "dodge_base",
      "sprites": {
        "player": "assets/sprites/games/dodge/base_1/player.png",
        "enemy": "assets/sprites/games/dodge/base_1/enemy.png",
        "background": "assets/sprites/games/dodge/base_1/background.png"
      }
    },
    {
      "id": "shared_retro_red",
      "sprites": {
        "player": "assets/sprites/shared/characters/player_red.png",
        "enemy": "assets/sprites/shared/enemies/generic.png"
      }
    },
    {
      "id": "dodge_custom",
      "sprites": {
        "player": "assets/sprites/games/dodge/custom/player.png"
        // Missing enemy.png, will fall back to dodge_base
      }
    }
  ]
}
```

**Benefits**:
- Sprites can live anywhere (not locked to game folders)
- Sprite sets are reusable across games
- Partial sprite sets gracefully fall back per-sprite

### Config.lua = Technical Defaults Only

```lua
config.game_defaults = {
    DodgeGame = {
        -- Required sprite keys (validation)
        required_sprites = {"player", "enemy", "background"},

        -- Gameplay defaults
        lives = 3,
        speed = 1.0,
        spawn_rate = 2.0,

        -- Formula defaults
        base_formula = "objects_dodged - collisions × combo",
        metrics = {"objects_dodged", "collisions", "combo"},

        -- NO metadata (category, tier, sprite_folder)
        -- NO file references (variant_file, sprite_set_id)
    }
}
```

**What's NOT in config**:
- Game metadata (category, tier, display names)
- Sprite/sound file paths
- Variant file names
- Any mapping tables

---

## Phase Breakdown

### Phase 1: Create New Data Structures (Days 1-2)
**Goal**: Define new JSON formats, no code changes yet

#### 1.1: Create sprite_sets.json

**File**: `assets/data/sprite_sets.json`

```json
{
  "sprite_sets": [
    {
      "id": "dodge_base",
      "sprites": {
        "player": "assets/sprites/games/dodge/base_1/player.png",
        "enemy": "assets/sprites/games/dodge/base_1/enemy.png",
        "background": "assets/sprites/games/dodge/base_1/background.png"
      }
    },
    {
      "id": "dodge_base_2",
      "sprites": {
        "background": "assets/sprites/games/dodge/base_2/background.png"
        // Only overrides background, rest fall back to dodge_base
      }
    },
    {
      "id": "snake_classic",
      "sprites": {
        "segment": "assets/sprites/games/snake/classic/snake/segment.png",
        "food": "assets/sprites/games/snake/classic/snake/food.png"
      }
    },
    {
      "id": "snake_segmented",
      "sprites": {
        "seg_head": "assets/sprites/games/snake/classic/snake/seg_head.png",
        "food": "assets/sprites/games/snake/classic/snake/food.png"
      }
    },
    {
      "id": "memory_icons_1",
      "sprites": {
        "card_back": "assets/sprites/games/memory/icons_1/card_back.png",
        "card_front": "assets/sprites/games/memory/icons_1/card_front.png"
      }
    },
    {
      "id": "space_fighter_1",
      "sprites": {
        "player": "assets/sprites/games/space_shooter/fighter_1/player.png",
        "enemy": "assets/sprites/games/space_shooter/fighter_1/enemy.png"
      }
    }
  ]
}
```

**Testing**: Load and parse JSON, verify no syntax errors.

---

#### 1.2: Update Variant JSON Format

**Example**: Migrate `assets/data/variants/dodge_variants.json` to new format

**Before** (old format):
```json
[
  {
    "clone_index": 0,
    "name": "Dodge Classic",
    "sprite_set": "base_1",
    "palette": "blue"
  }
]
```

**After** (new format):
```json
{
  "game_class": "DodgeGame",
  "sprite_folder": "dodge",
  "default_sprite_set": "dodge_base",
  "category": "action",
  "tier": "trash",

  "variants": [
    {
      "clone_index": 0,
      "name": "Dodge Classic",
      "sprite_set": "dodge_base",
      "palette": "blue"
    }
  ]
}
```

**Migrate all variant files**:
- `dodge_variants.json` → Add game metadata
- `snake_variants.json` → Add game metadata
- `memory_match_variants.json` → Add game metadata
- `space_shooter_variants.json` → Add game metadata
- `hidden_object_variants.json` → Add game metadata (if exists)

**Testing**: Validate all variant JSONs parse correctly.

---

#### 1.3: Update config.lua Game Defaults

**File**: `src/config.lua`

**Remove**: All game metadata, mapping tables

**Keep**: Only technical defaults

```lua
config.game_defaults = {
    DodgeGame = {
        -- Sprite validation
        required_sprites = {"player", "enemy", "background"},

        -- Gameplay
        lives = 3,
        speed = 1.0,
        spawn_rate = 2.0,
        safe_zone_radius = 100,

        -- Formulas
        base_formula = "objects_dodged - collisions × combo",
        display_formula = "dodges - hits × combo",
        metrics = {"objects_dodged", "collisions", "combo"},

        -- CheatEngine
        available_cheats = {
            -- ... cheat definitions
        }
    },

    SnakeGame = {
        required_sprites = {"segment", "food"},  -- or "seg_head" for segmented

        grow_rate = 1,
        initial_length = 3,
        speed = 5,
        walls_enabled = true,

        base_formula = "snake_length² / survival_time",
        metrics = {"snake_length", "survival_time"},

        available_cheats = { /* ... */ }
    },

    MemoryMatch = {
        required_sprites = {"card_back", "card_front"},

        card_count = 12,
        memorize_time = 5,
        flip_speed = 0.2,

        base_formula = "matches × combo / time",
        metrics = {"matches", "time", "combo"},

        available_cheats = { /* ... */ }
    },

    SpaceShooter = {
        required_sprites = {"player", "enemy", "bullet"},

        lives = 5,
        movement_speed = 200,
        fire_cooldown = 0.2,

        base_formula = "kills² × 10 - deaths² × 5",
        metrics = {"kills", "deaths", "accuracy"},

        available_cheats = { /* ... */ }
    },

    HiddenObject = {
        required_sprites = {"background", "object_highlight"},

        object_count = 10,
        time_limit = 60,
        hint_cooldown = 10,

        base_formula = "objects_found × combo / time",
        metrics = {"objects_found", "time", "combo"},

        available_cheats = { /* ... */ }
    }
}
```

**Status After Phase 1**:
- ✅ New data structures defined
- ✅ Variant JSONs migrated to self-describing format
- ✅ Config.lua cleaned of metadata
- ❌ Code still using old system (will update in Phase 2)

---

### Phase 2: Implement Discovery System (Days 3-5)
**Goal**: Create new loading system, doesn't touch old code yet

#### 2.1: Create GameRegistry

**New File**: `src/models/game_registry.lua`

```lua
local Object = require('class')
local json = require('json')
local Paths = require('src.paths')
local Config = require('src.config')

local GameRegistry = Object:extend('GameRegistry')

function GameRegistry:init()
    self.games = {}  -- Discovered games
    self.variant_files = {}  -- Loaded variant file data

    self:discoverGames()
end

function GameRegistry:discoverGames()
    local variants_dir = Paths.assets.data .. "variants/"
    local files = love.filesystem.getDirectoryItems(variants_dir)

    for _, filename in ipairs(files) do
        if filename:match("_variants%.json$") then
            local file_path = variants_dir .. filename
            local success, variant_data = self:loadVariantFile(file_path)

            if success and variant_data then
                self:registerGameFromVariantFile(filename, variant_data)
            end
        end
    end

    print(string.format("GameRegistry: Discovered %d games from %d variant files",
        #self.games, self:countVariantFiles()))
end

function GameRegistry:loadVariantFile(file_path)
    local read_ok, contents = pcall(love.filesystem.read, file_path)
    if not read_ok or not contents then
        print("ERROR: Could not read " .. file_path)
        return false, nil
    end

    local decode_ok, data = pcall(json.decode, contents)
    if not decode_ok or not data then
        print("ERROR: Could not decode " .. file_path)
        return false, nil
    end

    -- Validate required fields
    if not data.game_class then
        print("ERROR: " .. file_path .. " missing 'game_class' field")
        return false, nil
    end

    if not data.variants or #data.variants == 0 then
        print("ERROR: " .. file_path .. " missing 'variants' array")
        return false, nil
    end

    return true, data
end

function GameRegistry:registerGameFromVariantFile(filename, variant_data)
    local game_class = variant_data.game_class

    -- Get technical defaults from config
    local config_defaults = Config.game_defaults[game_class]
    if not config_defaults then
        print("ERROR: No config.game_defaults for " .. game_class)
        return
    end

    -- Store variant file data
    self.variant_files[filename] = variant_data

    -- Create game entries for each variant
    for _, variant in ipairs(variant_data.variants) do
        local game_data = self:mergeGameData(config_defaults, variant_data, variant)
        game_data._source_file = filename
        game_data._variant_index = variant.clone_index

        table.insert(self.games, game_data)
    end

    print(string.format("✓ Registered %d variants from %s (game_class: %s)",
        #variant_data.variants, filename, game_class))
end

function GameRegistry:mergeGameData(config_defaults, file_data, variant)
    local merged = {}

    -- Priority: variant > file_data > config_defaults

    -- 1. Start with config defaults
    for k, v in pairs(config_defaults) do
        merged[k] = self:deepCopy(v)
    end

    -- 2. Override with file-level data
    for k, v in pairs(file_data) do
        if k ~= "variants" then  -- Don't copy variants array
            merged[k] = self:deepCopy(v)
        end
    end

    -- 3. Override with variant-specific data
    for k, v in pairs(variant) do
        merged[k] = self:deepCopy(v)
    end

    -- 4. Generate game ID
    merged.id = self:generateGameID(merged.game_class, variant.clone_index)

    return merged
end

function GameRegistry:generateGameID(game_class, clone_index)
    -- Map game class to base ID prefix
    local class_to_prefix = {
        DodgeGame = "dodge",
        SnakeGame = "snake",
        MemoryMatch = "memory",
        SpaceShooter = "space_shooter",
        HiddenObject = "hidden_object"
    }

    local prefix = class_to_prefix[game_class]
    if not prefix then
        print("WARNING: Unknown game class: " .. game_class)
        prefix = game_class:lower()
    end

    -- ID format: prefix_N where N = clone_index + 1
    -- dodge_1 (clone_index 0), dodge_2 (clone_index 1), etc.
    return string.format("%s_%d", prefix, clone_index + 1)
end

function GameRegistry:deepCopy(obj)
    if type(obj) ~= 'table' then return obj end
    local copy = {}
    for k, v in pairs(obj) do
        copy[k] = self:deepCopy(v)
    end
    return copy
end

function GameRegistry:getGameByID(game_id)
    for _, game in ipairs(self.games) do
        if game.id == game_id then
            return game
        end
    end
    return nil
end

function GameRegistry:getAllGames()
    return self.games
end

function GameRegistry:getGamesByCategory(category)
    local filtered = {}
    for _, game in ipairs(self.games) do
        if game.category == category then
            table.insert(filtered, game)
        end
    end
    return filtered
end

function GameRegistry:countVariantFiles()
    local count = 0
    for _ in pairs(self.variant_files) do count = count + 1 end
    return count
end

return GameRegistry
```

**Testing**:
1. Instantiate GameRegistry
2. Verify all variant files discovered
3. Check game count matches expected
4. Verify game IDs generated correctly

---

#### 2.2: Create SpriteSetLoader

**New File**: `src/utils/sprite_set_loader.lua`

```lua
local Object = require('class')
local json = require('json')
local Paths = require('src.paths')

local SpriteSetLoader = Object:extend('SpriteSetLoader')

function SpriteSetLoader:init()
    self.sprite_sets = {}
    self.loaded_sprites = {}  -- Cache
    self:loadSpriteSets()
end

function SpriteSetLoader:loadSpriteSets()
    local file_path = Paths.assets.data .. "sprite_sets.json"
    local read_ok, contents = pcall(love.filesystem.read, file_path)

    if not read_ok or not contents then
        print("ERROR: Could not read sprite_sets.json")
        return
    end

    local decode_ok, data = pcall(json.decode, contents)
    if not decode_ok or not data or not data.sprite_sets then
        print("ERROR: Could not decode sprite_sets.json")
        return
    end

    -- Index by ID
    for _, sprite_set in ipairs(data.sprite_sets) do
        if sprite_set.id then
            self.sprite_sets[sprite_set.id] = sprite_set
        end
    end

    print(string.format("SpriteSetLoader: Loaded %d sprite sets", #data.sprite_sets))
end

function SpriteSetLoader:getSprite(sprite_set_id, sprite_key, fallback_set_id)
    -- Create cache key
    local cache_key = sprite_set_id .. ":" .. sprite_key

    -- Return cached if available
    if self.loaded_sprites[cache_key] then
        return self.loaded_sprites[cache_key]
    end

    -- Try loading from sprite set
    local sprite_set = self.sprite_sets[sprite_set_id]
    if sprite_set and sprite_set.sprites[sprite_key] then
        local sprite = self:loadSpriteFromPath(sprite_set.sprites[sprite_key])
        if sprite then
            self.loaded_sprites[cache_key] = sprite
            return sprite
        end
    end

    -- Try fallback sprite set
    if fallback_set_id and fallback_set_id ~= sprite_set_id then
        local fallback_set = self.sprite_sets[fallback_set_id]
        if fallback_set and fallback_set.sprites[sprite_key] then
            local sprite = self:loadSpriteFromPath(fallback_set.sprites[sprite_key])
            if sprite then
                -- Cache under original key
                self.loaded_sprites[cache_key] = sprite
                print(string.format("Sprite '%s' not found in '%s', using fallback from '%s'",
                    sprite_key, sprite_set_id, fallback_set_id))
                return sprite
            end
        end
    end

    print(string.format("ERROR: Could not load sprite '%s' from set '%s'", sprite_key, sprite_set_id))
    return self:getErrorSprite()
end

function SpriteSetLoader:loadSpriteFromPath(path)
    local success, sprite = pcall(love.graphics.newImage, path)
    if success then
        return sprite
    else
        print("ERROR: Could not load sprite from " .. path)
        return nil
    end
end

function SpriteSetLoader:getErrorSprite()
    -- Return a placeholder 1x1 white sprite
    if not self.error_sprite then
        local image_data = love.image.newImageData(1, 1)
        image_data:setPixel(0, 0, 1, 0, 1, 1)  -- Magenta
        self.error_sprite = love.graphics.newImage(image_data)
    end
    return self.error_sprite
end

return SpriteSetLoader
```

**Testing**:
1. Load sprite_sets.json
2. Request sprites from different sets
3. Verify fallback works (partial sprite sets)
4. Verify caching works (no duplicate loads)

---

**Status After Phase 2**:
- ✅ GameRegistry discovers games from variant JSONs
- ✅ SpriteSetLoader handles sprite loading with fallback
- ✅ New system fully functional
- ❌ Old system still in use (parallel systems)

---

### Phase 3: Integrate New System (Days 6-8)
**Goal**: Replace old loading in GameData/GameVariantLoader

#### 3.1: Refactor GameData to Use GameRegistry

**File**: `src/models/game_data.lua`

**Remove**:
- `loadStandaloneVariantCounts()` - replaced by GameRegistry
- `generateClones()` - replaced by GameRegistry
- All mapping tables

**Update**:
- `loadBaseGameDefinitions()` → `loadGamesFromRegistry()`

```lua
function GameData:loadGamesFromRegistry(game_registry)
    self.games = {}

    local all_games = game_registry:getAllGames()

    for _, game_data in ipairs(all_games) do
        -- Validate required fields
        if game_data.id and game_data.game_class then
            self:registerGame(game_data)
        else
            print("WARNING: Skipping invalid game from registry")
        end
    end

    print(string.format("GameData: Loaded %d games from registry", self:getGameCount()))
end

function GameData:registerGame(game_data)
    self.games[game_data.id] = game_data
end

function GameData:getGameCount()
    local count = 0
    for _ in pairs(self.games) do count = count + 1 end
    return count
end
```

**Testing**:
1. Load games via GameRegistry
2. Verify all games present
3. Check game IDs correct
4. Verify formulas/metrics loaded

---

#### 3.2: Simplify GameVariantLoader

**File**: `src/models/game_variant_loader.lua`

**Remove**:
- `loadStandaloneVariants()` - replaced by GameRegistry
- All mapping tables
- Most of `getVariantData()` logic

**Keep**: Only as thin wrapper around GameRegistry (for backwards compat)

```lua
function GameVariantLoader:init(game_registry)
    self.game_registry = game_registry
    self.launcher_icons = {}  -- Icon cache still needed
end

function GameVariantLoader:getVariantData(game_id)
    local game = self.game_registry:getGameByID(game_id)

    if not game then
        print("GameVariantLoader: No game found for ID: " .. game_id)
        return self:getDefaultVariant()
    end

    return game
end

-- Rest of class can be simplified or removed
```

---

**Status After Phase 3**:
- ✅ GameData uses GameRegistry
- ✅ GameVariantLoader simplified
- ✅ Mapping tables removed
- ❌ Views still have duplicate sprite loading

---

### Phase 4: Consolidate Sprite Loading (Days 9-10)
**Goal**: Replace duplicate sprite code in views

#### 4.1: Create GameSpriteHelper

**New File**: `src/utils/game_sprite_helper.lua`

```lua
local GameSpriteHelper = {}

function GameSpriteHelper:loadPlayerSprite(game_data, sprite_set_loader, size)
    local sprite_set_id = game_data.sprite_set or game_data.default_sprite_set
    local fallback_set_id = game_data.default_sprite_set

    -- Determine sprite key based on game class
    local sprite_key = self:getPlayerSpriteKey(game_data)

    -- Load with fallback
    local sprite = sprite_set_loader:getSprite(sprite_set_id, sprite_key, fallback_set_id)

    return sprite
end

function GameSpriteHelper:getPlayerSpriteKey(game_data)
    if game_data.game_class == "SnakeGame" then
        local sprite_style = game_data.sprite_style or "uniform"
        return (sprite_style == "segmented") and "seg_head" or "segment"
    else
        return "player"  -- Dodge, Space Shooter, etc.
    end
end

return GameSpriteHelper
```

---

#### 4.2: Refactor LauncherView to Use Helper

**File**: `src/views/launcher_view.lua`

**Replace**: Both duplicated sprite loading blocks with:

```lua
local GameSpriteHelper = require('src.utils.game_sprite_helper')

-- In drawGameCard():
if game_data.icon_sprite == "player" then
    local sprite = GameSpriteHelper:loadPlayerSprite(game_data, self.sprite_set_loader, icon_size)
    if sprite then
        love.graphics.draw(sprite, icon_x, icon_y, 0,
            icon_size / sprite:getWidth(), icon_size / sprite:getHeight())
        player_sprite_drawn = true
    end
end

-- In drawGameDetailPanel() - same code
```

**Result**: 157 lines reduced to ~10 lines + shared helper.

---

**Status After Phase 4**:
- ✅ Sprite loading centralized
- ✅ Duplicate code eliminated
- ✅ Fallback logic unified
- ❌ base_game_definitions.json still exists

---

### Phase 5: Delete base_game_definitions.json (Day 11)
**Goal**: Remove obsolete file, migrate any remaining data

#### 5.1: Audit What's Still in base_game_definitions.json

Check for:
- Icon sprites (move to sprite_sets.json or variant JSONs)
- Formulas (should be in config.game_defaults)
- CheatEngine definitions (should be in config.game_defaults)
- Any other data not yet migrated

#### 5.2: Migrate Remaining Data

Move any unique data to appropriate locations:
- Formulas → config.game_defaults
- Icon mappings → sprite_sets.json
- CheatEngine → config.game_defaults

#### 5.3: Delete File

```bash
rm assets/data/base_game_definitions.json
```

#### 5.4: Remove All References

Search codebase for `base_game_definitions` and remove:
- Require statements
- Loading code
- Comments referencing it

**Testing**: Verify game still loads without base_game_definitions.json.

---

**Status After Phase 5**:
- ✅ base_game_definitions.json deleted
- ✅ All data migrated to appropriate locations
- ✅ System fully data-driven

---

### Phase 6: Testing & Validation (Days 12-13)
**Goal**: Comprehensive testing of new system

#### 6.1: Functional Tests

**Test 1: Game Discovery**
- Add new variant JSON
- Verify auto-discovered without code changes
- Check game appears in launcher

**Test 2: Sprite Fallback**
- Create sprite set with partial sprites
- Verify missing sprites load from fallback
- Check no white boxes

**Test 3: Category Override**
- Create variant that overrides category
- Verify appears in correct launcher category
- Check doesn't appear in old category

**Test 4: Formula Inheritance**
- Verify formulas come from config.game_defaults
- Check scaling_constant works
- Verify variant can't override formula (security)

#### 6.2: Regression Tests

**Test All Existing Games**:
- Dodge (all variants)
- Snake (all variants)
- Memory Match (all 20 variants!)
- Space Shooter (all variants)
- Hidden Object (if exists)

**Verify**:
- All games load
- Sprites display correctly
- Formulas calculate correctly
- CheatEngine works
- Demo recording works

#### 6.3: Performance Tests

- Load time with 100+ games
- Memory usage
- Sprite caching effectiveness

---

**Status After Phase 6**:
- ✅ All tests passing
- ✅ No regressions
- ✅ Performance acceptable

---

### Phase 7: Documentation (Day 14)
**Goal**: Document new architecture

#### 7.1: Update CLAUDE.md

Add section:
```markdown
## Game Loading Architecture

Games are discovered automatically from variant JSON files.

### Adding a New Game

1. **Write game code**: Create game class (e.g., `MyGame.lua`) and view
2. **Add config defaults**: Add entry to `config.game_defaults.MyGame`
3. **Create variant JSON**: Add `my_game_variants.json` to `assets/data/variants/`
4. **Optional: Create sprite sets**: Add reusable sprite sets to `sprite_sets.json`

That's it! No code changes to loading system needed.

### Variant JSON Format

```json
{
  "game_class": "MyGame",
  "sprite_folder": "my_game",
  "default_sprite_set": "my_game_base",
  "category": "action",

  "variants": [
    {
      "clone_index": 0,
      "name": "My Game Classic",
      "lives": 5
    }
  ]
}
```

### Data Hierarchy

Config → Variant File → Individual Variant

Variants override file defaults, file defaults override config.
```

#### 7.2: Create Migration Guide

**New File**: `documentation/data_architecture_migration.md`

Explain:
- Why we refactored
- What changed
- How to migrate old variant files
- Common pitfalls

---

## Success Criteria

### Code Quality
- [ ] Zero duplicate mapping tables
- [ ] Single source of truth for game metadata
- [ ] No hardcoded file paths
- [ ] Sprite loading centralized

### Functionality
- [ ] All games load correctly
- [ ] All 20 Memory Match variants load
- [ ] Sprite fallback works per-sprite
- [ ] Auto-discovery works

### Developer Experience
- [ ] Adding game = write code + JSON only
- [ ] No mapping tables to update
- [ ] Clear error messages when JSON invalid
- [ ] Self-documenting variant format

### Performance
- [ ] No performance regression
- [ ] Sprite caching effective
- [ ] Load time acceptable (< 2 seconds)

---

## Risk Mitigation

### Risk: Breaking Existing Games
**Mitigation**: Parallel systems during Phase 2-3, comprehensive testing in Phase 6.

### Risk: JSON Format Errors
**Mitigation**: Validation in GameRegistry, clear error messages, JSON schema (optional).

### Risk: Sprite Path Confusion
**Mitigation**: sprite_sets.json centralizes all paths, SpriteSetLoader validates.

### Risk: Performance Regression
**Mitigation**: Sprite caching, profiling in Phase 6, optimization if needed.

---

## Estimated Timeline

| Phase | Focus | Days | Running Total |
|-------|-------|------|---------------|
| 1 | Create New Data Structures | 2 | 2 |
| 2 | Implement Discovery System | 3 | 5 |
| 3 | Integrate New System | 3 | 8 |
| 4 | Consolidate Sprite Loading | 2 | 10 |
| 5 | Delete base_game_definitions.json | 1 | 11 |
| 6 | Testing & Validation | 2 | 13 |
| 7 | Documentation | 1 | 14 |

**Total: 14 days (2 weeks)**

---

## Phase Completion Protocol

After completing each phase, update this document with completion notes:

```markdown
---
**PHASE X COMPLETION NOTES** (Date: YYYY-MM-DD)

**Completed:**
- Feature 1
- Feature 2

**Testing:**
1. Test step 1
2. Test step 2

**Status:** ✅ COMPLETE / ⚠️ NEEDS WORK
---
```

---

## Next Steps

1. **Review this plan** - Confirm approach makes sense
2. **Phase 1 Kickoff** - Start with sprite_sets.json and variant migrations
3. **Daily Check-ins** - Review each phase completion before proceeding
4. **Test Frequently** - Don't accumulate tech debt

---

**END OF PLAN**

Ready to begin Phase 1?
