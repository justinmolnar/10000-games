# New Games Implementation Plan
**Breakout, Coin Flip Streak, RPS Tournament - Comprehensive Phased Action Plan**

---

## 🚨 CRITICAL INSTRUCTIONS FOR AI IMPLEMENTERS 🚨

**When working through this plan:**

1. **Mark phases complete** in the `[ ] Status` section after finishing
2. **Document testing** in the `Testing & Validation` section of each phase
3. **Add notes** in the `Implementation Notes` section (gotchas, decisions, workarounds)
4. **Follow viewport coordinate safety** (see rules below)
5. **Update this document** as you go - it's a living document

### Viewport Coordinate Safety Rules (CRITICAL!)

From CLAUDE.md - **NEVER VIOLATE THESE RULES**:

```
CRITICAL: This is a recurring bug when creating new windowed views!

LÖVE2D has two coordinate systems:
- Viewport coordinates: Relative to window content area (0,0 = top-left of window viewport)
- Screen coordinates: Absolute screen position (includes window position offset)

Rules for windowed views (views with drawWindowed() method):

1. NEVER call love.graphics.origin() inside windowed views
   - origin() resets to screen coordinates 0,0
   - This causes content to only render when window is at top-left of screen
   - The window transformation matrix is already set up correctly

2. love.graphics.setScissor() requires SCREEN coordinates, not viewport coordinates
   - Scissor regions must account for window position on desktop
   - Always add viewport.x and viewport.y offsets

Correct pattern for scissor in windowed views:
```lua
function MyView:drawWindowed(viewport_width, viewport_height)
    local viewport = self.controller.viewport
    local screen_x = viewport and viewport.x or 0
    local screen_y = viewport and viewport.y or 0

    local content_y = 30
    local content_height = viewport_height - 30

    love.graphics.setScissor(screen_x, screen_y + content_y, viewport_width, content_height)
    love.graphics.print("Text", 10, content_y)
    love.graphics.setScissor()
end
```
```

### Architecture Patterns to Follow

1. **Dependency Injection**: Pass DI container to all constructors, never use globals (except legacy _G.DI_CONFIG being phased out)
2. **MVC Separation**: Models = data/logic, Views = rendering only, States/Controllers = mediation
3. **Fixed Timestep**: All games MUST support `fixedUpdate(dt)` for deterministic demo recording
4. **Variant Override Pattern**: Three-tier fallback: `(runtimeCfg and runtimeCfg.param) or DEFAULT`
5. **Config Fallbacks**: All tuning values in config.lua, externalize data to JSON
6. **CheatEngine Integration**: Define `available_cheats` in base_game_definitions.json, parameter ranges in config.lua
7. **Metrics Tracking**: Track all formula-relevant metrics in game.metrics table

---

## Executive Summary

**Scope**: Implement 3 new game types with full variant systems, CheatEngine integration, demo recording support, and VM compatibility.

**Games**:
1. **Breakout/Arkanoid** - Complex physics-based brick breaker (most complex)
2. **Coin Flip Streak** - Pure luck game with bias system (simplest, VM-perfect)
3. **RPS Tournament** - AI opponent with pattern system (medium complexity, VM-excellent)

**Implementation Strategy**: Phases can be done **in parallel** (all 3 games at once) or **sequentially** (finish one game fully before starting next). Each phase includes work for all 3 games.

**Estimated Timeline**:
- **Parallel approach**: ~15-25 days (3 games progress simultaneously)
- **Sequential approach**: ~20-35 days (finish Coin Flip → RPS → Breakout)

**Target LOC**:
- Breakout: ~1,800-2,500 lines (complex physics, many variants)
- Coin Flip: ~600-900 lines (simple mechanics, great VM compatibility)
- RPS: ~1,000-1,500 lines (AI patterns, tournament system)
- **Total**: ~3,400-4,900 lines across 6 new files (3 games + 3 views)

---

## Phase 0: Foundation & File Structure

**Goal**: Set up all file structures, base classes, and JSON definitions before implementing game logic.

### Tasks

#### All Games - JSON Definitions
- [ ] Create `assets/data/base_game_definitions.json` entries:
  - [ ] `breakout_1` - Basic Breakout definition with formula, metrics, cheats, bullet properties
  - [ ] `coin_flip_1` - Coin Flip definition with formula, metrics, cheats
  - [ ] `rps_1` - RPS Tournament definition with formula, metrics, cheats
- [ ] Add games to `assets/data/programs.json` with window defaults
- [ ] Create variant JSON files (empty arrays for now):
  - [ ] `assets/data/variants/breakout_variants.json`
  - [ ] `assets/data/variants/coin_flip_variants.json`
  - [ ] `assets/data/variants/rps_variants.json`

#### All Games - Config Definitions
- [ ] Add game configs to `src/config.lua`:
  - [ ] `config.games.breakout` - Paddle size, ball speed, brick dimensions, power-up durations, etc.
  - [ ] `config.games.coin_flip` - Default streak target, flip timing, animation speeds
  - [ ] `config.games.rps` - Round timing, AI defaults, animation speeds
- [ ] Add CheatEngine parameter ranges for each game
- [ ] Add hidden_parameters lists (dropdown enums, visual metadata)

#### All Games - File Creation
- [ ] Create game model files:
  - [ ] `src/games/breakout.lua` - Extends BaseGame
  - [ ] `src/games/coin_flip.lua` - Extends BaseGame
  - [ ] `src/games/rps.lua` - Extends BaseGame
- [ ] Create view files:
  - [ ] `src/games/views/breakout_view.lua` - Rendering only
  - [ ] `src/games/views/coin_flip_view.lua` - Rendering only
  - [ ] `src/games/views/rps_view.lua` - Rendering only

#### File Templates (Copy from existing games)
- [ ] Breakout: Use `space_shooter.lua` as template (similar complexity)
- [ ] Coin Flip: Use `memory_match.lua` as template (simpler mechanics)
- [ ] RPS: Use `dodge_game.lua` as template (state machine driven)

#### Deliverables
- [ ] 3 game entries in base_game_definitions.json with:
  - display_name, game_class, tier, category, unlock_cost, cost_exponent
  - base_formula_string, display_formula_string, metrics_tracked
  - available_cheats array
  - bullet_fire_rate, bullet_sprite, variant_multiplier, difficulty_level
- [ ] 3 empty variant JSON files
- [ ] 3 game config sections in config.lua
- [ ] 6 new .lua files with basic class structure (init, update, draw, etc.)

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here as you implement:
- Which existing game did you use as template for each?
- Any config parameter naming conventions?
- Gotchas discovered?
```

### Testing & Validation
```
After completing Phase 0:
- [ ] Verify all JSON files are valid (no syntax errors)
- [ ] Verify config.lua has no syntax errors (run game to load config)
- [ ] Verify game files load without errors (require them in main.lua test)
- [ ] Check base_game_definitions.json follows existing pattern
```

---

## Phase 1: Core Game Loop - Coin Flip (Simplest First)

**Goal**: Get Coin Flip playable with basic mechanics - coin flips, guess input, streak tracking, victory condition.

**Why Coin Flip first?**: Simplest game, fastest to validate architecture patterns, perfect for testing demo recording.

### Tasks

#### Coin Flip Model (`coin_flip.lua`)
- [ ] Implement `init()`:
  - [ ] Load variant parameters (streak_target, coin_bias, lives)
  - [ ] Three-tier fallback pattern: variant → runtimeCfg → DEFAULT
  - [ ] Initialize game state: current_streak, total_flips, correct_guesses, incorrect_guesses
  - [ ] Initialize RNG with seed for deterministic flips
- [ ] Implement `fixedUpdate(dt)`:
  - [ ] Handle flip timing (if auto_flip_interval > 0)
  - [ ] Update flip animation state
  - [ ] Check victory condition (streak_target reached)
- [ ] Implement `keypressed(key)`:
  - [ ] 'h' key = guess heads
  - [ ] 't' key = guess tails
  - [ ] Trigger flip on guess
- [ ] Implement flip logic:
  - [ ] Generate result based on coin_bias (math.random() < coin_bias → heads)
  - [ ] Compare guess to result
  - [ ] Update streak (increment or reset to 0)
  - [ ] Update lives (if wrong and lives < 999)
  - [ ] Check game over (lives == 0)
- [ ] Implement `checkComplete()`:
  - [ ] Return true if current_streak >= streak_target
  - [ ] Return true if game_over
- [ ] Track metrics:
  - [ ] `streak` - Current consecutive correct
  - [ ] `max_streak` - Highest streak achieved
  - [ ] `correct_total` - Total correct guesses
  - [ ] `incorrect_total` - Total wrong guesses
  - [ ] `flips_total` - Total flips
  - [ ] `accuracy` - correct_total / flips_total

#### Coin Flip View (`coin_flip_view.lua`)
- [ ] Implement `init()`:
  - [ ] Store reference to game state
  - [ ] Load any sprite assets (coin sprite)
  - [ ] Set up default colors
- [ ] Implement `draw()`:
  - [ ] Draw background
  - [ ] Draw coin sprite (or circle placeholder)
  - [ ] Draw current guess prompt ("Press H or T")
  - [ ] Draw current streak counter
  - [ ] Draw lives remaining (if < 999)
  - [ ] Draw flip animation (rotate coin sprite if flipping)
  - [ ] Draw result text ("CORRECT!" or "WRONG!")
- [ ] **VIEWPORT SAFETY**: This is NOT a windowed view, so origin() is OK
- [ ] Add HUD elements:
  - [ ] Streak counter (large text)
  - [ ] Target streak (e.g., "5 / 10")
  - [ ] Lives remaining (if applicable)
  - [ ] Total flips

#### Integration
- [ ] Register game in launcher (if not already in programs.json)
- [ ] Add icon sprite to assets
- [ ] Test launching from desktop

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- How is RNG seeded for determinism?
- Flip animation approach (sprite rotation? image swap?)
- Any performance considerations?
```

### Testing & Validation
```
Manual testing checklist:
- [ ] Launch Coin Flip from desktop
- [ ] Press H or T to make guess
- [ ] Verify flip happens and result shown
- [ ] Verify streak increments on correct guess
- [ ] Verify streak resets on wrong guess
- [ ] Play until winning (reach streak_target)
- [ ] Verify game completion triggers
- [ ] Test with lives = 3 (verify game over on 3 wrong guesses)
- [ ] Test demo recording: play game, save demo
- [ ] Test demo playback: load demo, verify deterministic results
- [ ] Test with different seeds: verify flip results change but demo still works
```

---

## Phase 2: Core Game Loop - RPS Tournament

**Goal**: Get RPS playable with basic mechanics - throw selection, AI opponent, round tracking, victory condition.

**Why RPS next?**: Still simple, introduces AI patterns, tests turn-based structure.

### Tasks

#### RPS Model (`rps.lua`)
- [ ] Implement `init()`:
  - [ ] Load variant parameters (rounds_to_win, ai_pattern, ai_bias, game_mode, hands_mode, opponent_count, multi_opponent_elimination)
  - [ ] Initialize game state: player_wins, ai_wins, ties, rounds_played
  - [ ] Initialize AI state machine (create array of AI opponents if opponent_count > 1)
  - [ ] Load RPS/RPSLS/RPSFB win matrix
  - [ ] Initialize double hands state if hands_mode == "double"
- [ ] Implement `fixedUpdate(dt)`:
  - [ ] Handle round timing (if time_per_round > 0)
  - [ ] Update animation states
  - [ ] Handle round result display timer
- [ ] Implement `keypressed(key)`:
  - [ ] **Single hands mode**:
    - 'r' key = throw rock
    - 'p' key = throw paper
    - 's' key = throw scissors
    - 'l' key = throw lizard (RPSLS mode)
    - 'v' key = throw spock (RPSLS mode)
    - Trigger round on valid input
  - [ ] **Double hands mode (Squid Game style)**:
    - First phase: Select both hands (1-5 keys for left hand, 6-0 keys for right hand)
    - Second phase: Select which hand to remove (left/right or specific key)
    - Handle time_per_round and time_per_removal separately
    - Store both_hands_state before removal for history tracking
- [ ] Implement round logic:
  - [ ] **Single opponent mode**:
    - [ ] Generate AI throw based on ai_pattern:
      - "random" - pure RNG
      - "repeat_last" - throw same as last round
      - "counter_player" - throw what beats player's last choice
      - "biased" - favor ai_bias choice with ai_bias_strength probability
      - "pattern_cycle" - cycle through options in order
      - "mimic_player" - copy player's last choice
    - [ ] If hands_mode == "double", AI also chooses two hands then removes one
    - [ ] Determine winner using win matrix
    - [ ] Update win counters (player_wins, ai_wins, ties)
    - [ ] Update history arrays (player_history, ai_history)
  - [ ] **Multiple opponent mode (battle royale)**:
    - [ ] Generate throws for all AI opponents
    - [ ] Determine matchup structure:
      - If opponent_count == 2: Direct player vs both AIs (separate rounds)
      - If opponent_count > 2: Round-robin or elimination bracket
    - [ ] Process eliminations based on multi_opponent_elimination mode:
      - "single_winner": Last one standing wins entire game
      - "points": Accumulate points, highest score wins after rounds
      - "survival": Avoid being last place (lowest score gets eliminated)
    - [ ] Track elimination_order array for display
    - [ ] Update per-opponent win counters
- [ ] Implement `checkComplete()`:
  - [ ] **Single opponent**: Return true if player_wins >= rounds_to_win OR ai_wins >= rounds_to_win
  - [ ] **Multiple opponents**:
    - Return true if player eliminated (check elimination_order)
    - Return true if only player remains (all AIs eliminated)
    - Handle point-based victory (highest score after total_rounds_limit)
  - [ ] Handle total_rounds_limit if set
- [ ] Track metrics:
  - [ ] `rounds_won` - Player rounds won
  - [ ] `rounds_lost` - AI rounds won
  - [ ] `rounds_tied` - Tie rounds
  - [ ] `rounds_total` - Total rounds played
  - [ ] `win_streak` - Current consecutive wins
  - [ ] `max_win_streak` - Highest consecutive wins
  - [ ] `accuracy` - rounds_won / (rounds_won + rounds_lost)

#### RPS View (`rps_view.lua`)
- [ ] Implement `init()`:
  - [ ] Store reference to game state
  - [ ] Load throw sprites (rock, paper, scissors hand images or icons)
  - [ ] Set up colors and fonts
- [ ] Implement `draw()`:
  - [ ] Draw background
  - [ ] **Single hands mode**:
    - [ ] Draw throw prompt ("Press R, P, or S")
    - [ ] Draw player's last throw (sprite or text)
    - [ ] Draw AI's last throw (sprite or text)
  - [ ] **Double hands mode**:
    - [ ] Draw both hands selection UI (show both hands during reveal phase)
    - [ ] Draw removal prompt ("Press L or R to remove hand")
    - [ ] Show final throws after removal
    - [ ] Display both_hands_history if enabled (what both hands were)
  - [ ] **Single opponent**:
    - [ ] Draw round result ("YOU WIN" / "AI WINS" / "TIE")
    - [ ] Draw score (player wins vs AI wins)
  - [ ] **Multiple opponents**:
    - [ ] Draw all opponents (camera_focus_mode determines layout)
    - [ ] Show elimination status for each opponent
    - [ ] Display points/scores for all players
    - [ ] Highlight eliminated opponents
  - [ ] Draw history (last 10 rounds) if show_player_history/show_ai_history enabled
- [ ] **VIEWPORT SAFETY**: This is NOT a windowed view, so origin() is OK
- [ ] Add HUD elements:
  - [ ] Score display (e.g., "Player: 3 | AI: 2" or "P: 5 | AI1: 3 | AI2: 4 | AI3: 2")
  - [ ] Rounds remaining (e.g., "First to 5 wins")
  - [ ] Current round number
  - [ ] Elimination order (if multi-opponent mode)
  - [ ] History display (optional, based on variant)

#### AI Pattern Implementation
- [ ] Create AI decision function with switch on ai_pattern
- [ ] Store AI state (last throw, pattern position for cycle mode)
- [ ] Implement pattern_delay (random AI for first N rounds, then activate pattern)
- [ ] **Multiple opponents**: Each AI can have different pattern/bias (create AI array with individual configs)
- [ ] **Double hands mode**: AI also selects two hands then removes one (can use pattern for both selection and removal)

#### Integration
- [ ] Register game in launcher
- [ ] Add icon sprite
- [ ] Test launching from desktop

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- How is win matrix structured?
- AI state management approach?
- How to handle RPSLS mode (different keys)?
```

### Testing & Validation
```
Manual testing checklist:
- [ ] Launch RPS from desktop
- [ ] **Single hands mode**:
  - [ ] Press R/P/S to make throws
  - [ ] Verify AI responds with throw
  - [ ] Verify winner determined correctly
  - [ ] Verify score updates (player wins, AI wins, ties)
- [ ] **Double hands mode (Squid Game style)**:
  - [ ] Select both hands (two different throws)
  - [ ] Select which hand to remove
  - [ ] Verify AI also does two hands + removal
  - [ ] Verify final throws determine winner
  - [ ] Check that both_hands_history displays correctly
- [ ] **Single opponent**:
  - [ ] Play until winning (reach rounds_to_win)
  - [ ] Verify game completion triggers
- [ ] **Multiple opponents (2-5 AIs)**:
  - [ ] Verify all opponents display correctly
  - [ ] Test elimination modes (single_winner, points, survival)
  - [ ] Verify elimination order tracking
  - [ ] Check that eliminated opponents stop playing
  - [ ] Verify correct winner determination
- [ ] Test different AI patterns (random, repeat_last, counter_player, biased)
- [ ] Test RPSLS mode (5 options instead of 3)
- [ ] Verify ai_bias works (AI favors rock 60% of time)
- [ ] Test demo recording: play tournament, save demo
- [ ] Test demo playback: load demo, verify deterministic rounds
- [ ] Test with different seeds: verify AI choices change but demo still works
- [ ] **Edge cases**:
  - [ ] Double hands + multiple opponents + RPSLS (complex combo)
  - [ ] Timeout behavior in double hands mode (time_per_round AND time_per_removal)
```

---

## Phase 3: Core Game Loop - Breakout

**Goal**: Get Breakout playable with basic mechanics - paddle movement, ball physics, brick destruction, victory condition.

**Why Breakout last?**: Most complex, requires physics, collision detection, multiple entity types.

### Tasks

#### Breakout Model (`breakout.lua`)
- [ ] Implement `init()`:
  - [ ] Load variant parameters (paddle_width, ball_speed, brick_rows, brick_columns, lives, movement_type)
  - [ ] Initialize paddle state (x, y, velocity, width)
  - [ ] Initialize ball state (x, y, vx, vy, radius)
  - [ ] Initialize bricks array:
    - [ ] Generate brick positions based on brick_layout ("grid", "pyramid", etc.)
    - [ ] Each brick: {x, y, width, height, health, alive}
  - [ ] Initialize lives counter
- [ ] Implement `fixedUpdate(dt)`:
  - [ ] Update paddle (handle movement based on movement_type)
  - [ ] Update ball position (apply velocity)
  - [ ] Check ball collisions:
    - [ ] Paddle collision (bounce ball, update velocity)
    - [ ] Wall collisions (left, right, top)
    - [ ] Brick collisions (destroy brick, bounce ball)
    - [ ] Bottom boundary (lose life if ball falls off)
  - [ ] Check victory condition (all bricks destroyed or other victory_condition)
  - [ ] Handle ball respawn after miss
- [ ] Implement paddle movement:
  - [ ] "default" mode: WASD/Arrow keys, direct velocity control
  - [ ] Apply paddle_friction (deceleration)
  - [ ] Clamp paddle to arena bounds
- [ ] Implement ball physics:
  - [ ] Apply ball_gravity (if enabled)
  - [ ] Apply ball_speed_increase_per_bounce
  - [ ] Clamp to ball_max_speed
  - [ ] Handle ball_bounce_randomness (slight angle variation)
- [ ] Implement brick collision:
  - [ ] Detect ball-brick overlap (AABB or circle-rect collision)
  - [ ] Reduce brick health
  - [ ] If health == 0, mark brick as destroyed
  - [ ] Bounce ball off brick (reflect velocity)
- [ ] Implement `keypressed(key)`:
  - [ ] WASD/Arrow keys for paddle movement
  - [ ] Space for paddle shooting (if paddle_can_shoot enabled)
- [ ] Implement `checkComplete()`:
  - [ ] Return true if all bricks destroyed (victory_condition = "clear_bricks")
  - [ ] Return true if lives == 0 (game over)
  - [ ] Handle other victory_condition types (score, time, etc.)
- [ ] Track metrics:
  - [ ] `bricks_destroyed` - Total bricks destroyed
  - [ ] `balls_lost` - Times ball fell off bottom
  - [ ] `combo` - Consecutive bricks without paddle touch
  - [ ] `max_combo` - Highest combo achieved
  - [ ] `score` - Total score

#### Breakout View (`breakout_view.lua`)
- [ ] Implement `init()`:
  - [ ] Store reference to game state
  - [ ] Load brick sprite (or use rectangles)
  - [ ] Load paddle sprite
  - [ ] Load ball sprite
  - [ ] Set up colors
- [ ] Implement `draw()`:
  - [ ] Draw background
  - [ ] Draw bricks (loop through bricks array, skip destroyed)
  - [ ] Draw paddle (sprite or rectangle)
  - [ ] Draw ball (circle or sprite)
  - [ ] Draw HUD:
    - [ ] Lives remaining
    - [ ] Score
    - [ ] Bricks remaining
- [ ] **VIEWPORT SAFETY**: This is NOT a windowed view, so origin() is OK
- [ ] Visual polish:
  - [ ] Brick flash on hit (if brick_flash_on_hit enabled)
  - [ ] Ball trail (if ball_trail_length > 0)
  - [ ] Particle effects on brick destruction (if particle_effects_enabled)

#### Collision Detection
- [ ] Implement ball-paddle collision:
  - [ ] AABB or circle-rect overlap test
  - [ ] Calculate bounce angle based on hit position (center = straight up, edges = angled)
  - [ ] Apply paddle_sticky behavior if enabled
- [ ] Implement ball-brick collision:
  - [ ] Loop through all alive bricks
  - [ ] Check circle-rect overlap
  - [ ] Determine collision normal (top, bottom, left, right of brick)
  - [ ] Reflect ball velocity based on normal
  - [ ] Reduce brick health or destroy
- [ ] Implement ball-wall collision:
  - [ ] Left/right walls: reflect vx
  - [ ] Top wall: reflect vy (if ceiling_enabled)
  - [ ] Bottom: lose life, respawn ball

#### Integration
- [ ] Register game in launcher
- [ ] Add icon sprite
- [ ] Test launching from desktop

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- Collision detection approach (AABB? SAT? Circle-rect?)
- Brick layout generation strategy?
- How to handle ball stuck in infinite bounce?
- Performance considerations with many bricks?
```

### Testing & Validation
```
Manual testing checklist:
- [ ] Launch Breakout from desktop
- [ ] Use arrow keys/WASD to move paddle
- [ ] Verify ball bounces off paddle correctly
- [ ] Verify ball bounces off walls correctly
- [ ] Verify ball destroys bricks on collision
- [ ] Verify brick health system (multi-hit bricks)
- [ ] Verify ball bounces off bricks correctly
- [ ] Verify ball falls off bottom (lose life)
- [ ] Verify lives counter decrements
- [ ] Verify game over when lives == 0
- [ ] Verify victory when all bricks destroyed
- [ ] Test paddle movement types (default, rail, asteroids, jump if implemented)
- [ ] Test ball gravity (if enabled in variant)
- [ ] Test demo recording: play game, save demo
- [ ] Test demo playback: load demo, verify deterministic physics
- [ ] Test with different seeds: verify ball spawn angle varies but paddle movement still works
```

---

## Phase 4: Variant Parameter Loading (All Games)

**Goal**: Implement full three-tier fallback system for all variant parameters, integrate with CheatEngine, support variant JSON loading.

**This phase applies to ALL 3 GAMES.**

### Tasks

#### Coin Flip - Variant Parameters
- [ ] Implement parameter loading in `init()`:
  - [ ] `streak_target` - Load from variant → runtimeCfg → default
  - [ ] `coin_bias` - Load with fallback
  - [ ] `lives` - Load with fallback
  - [ ] `show_bias_hint` - Load with fallback
  - [ ] `time_per_flip` - Load with fallback
  - [ ] `auto_flip_interval` - Load with fallback
  - [ ] `pattern_mode` - Load with fallback
  - [ ] All other parameters from new_games_modifiers.md
- [ ] Apply difficulty_modifier from variant
- [ ] Apply CheatEngine modifications (speed_modifier, advantage_modifier, etc.)

#### RPS - Variant Parameters
- [ ] Implement parameter loading in `init()`:
  - [ ] `game_mode` - Load from variant → runtimeCfg → default
  - [ ] `rounds_to_win` - Load with fallback
  - [ ] `ai_pattern` - Load with fallback
  - [ ] `ai_bias` - Load with fallback
  - [ ] `ai_bias_strength` - Load with fallback
  - [ ] `time_per_round` - Load with fallback
  - [ ] `show_player_history` - Load with fallback
  - [ ] All other parameters from new_games_modifiers.md
- [ ] Apply difficulty_modifier from variant
- [ ] Apply CheatEngine modifications

#### Breakout - Variant Parameters
- [ ] Implement parameter loading in `init()`:
  - [ ] `movement_type` - Load from variant → runtimeCfg → default
  - [ ] `paddle_width` - Load with fallback
  - [ ] `paddle_speed` - Load with fallback
  - [ ] `ball_count` - Load with fallback
  - [ ] `ball_speed` - Load with fallback
  - [ ] `ball_gravity` - Load with fallback
  - [ ] `brick_rows` - Load with fallback
  - [ ] `brick_columns` - Load with fallback
  - [ ] `brick_layout` - Load with fallback
  - [ ] `brick_health` - Load with fallback
  - [ ] `lives` - Load with fallback
  - [ ] `victory_condition` - Load with fallback
  - [ ] All other parameters from new_games_modifiers.md
- [ ] Apply difficulty_modifier from variant
- [ ] Apply CheatEngine modifications

#### Pattern Implementation (All Games)
```lua
-- Standard three-tier fallback pattern:
local runtimeCfg = (self.di and self.di.config and self.di.config.games and self.di.config.games.game_name) or {}

-- Load parameter with fallback
local parameter_name = (runtimeCfg and runtimeCfg.parameter_name) or DEFAULT_VALUE
if self.variant and self.variant.parameter_name ~= nil then
    parameter_name = self.variant.parameter_name
end

-- Apply difficulty modifier
parameter_name = parameter_name * (self.variant and self.variant.difficulty_modifier or 1.0)

-- Apply CheatEngine modifications
if self.cheats.speed_modifier then
    parameter_name = parameter_name * self.cheats.speed_modifier
end
```

#### CheatEngine Integration (All Games)
- [ ] Define available_cheats in base_game_definitions.json:
  - [ ] Coin Flip: speed_modifier (flip speed), advantage_modifier (extra lives), performance_modifier (bias adjustment)
  - [ ] RPS: speed_modifier (round timing), advantage_modifier (extra wins needed for AI), performance_modifier (AI pattern hints)
  - [ ] Breakout: speed_modifier (ball/paddle speed), advantage_modifier (extra lives), performance_modifier (damage multiplier)
- [ ] Add parameter ranges to config.lua for each game
- [ ] Add hidden_parameters list (dropdown enums, visual metadata)

#### Variant JSON Creation
- [ ] Create 3-5 test variants for each game in variant JSON files
- [ ] Coin Flip variants:
  - [ ] Classic (fair coin, streak 5)
  - [ ] Weighted (60% heads, streak 5)
  - [ ] Marathon (fair coin, streak 10)
- [ ] RPS variants:
  - [ ] Classic (random AI, best of 5)
  - [ ] Pattern (repeat_last AI, best of 5)
  - [ ] Marathon (random AI, best of 21)
- [ ] Breakout variants:
  - [ ] Classic (grid layout, 1 ball, 3 lives)
  - [ ] Gravity (ball_gravity enabled)
  - [ ] Multi-ball (3 balls simultaneously)

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- Any parameters that need special handling?
- CheatEngine modification formula approach?
- Performance impact of many variant parameters?
```

### Testing & Validation
```
Testing checklist:
- [ ] Test default parameters (no variant, no cheats)
- [ ] Test variant override (create test variant with different parameters)
- [ ] Test CheatEngine (modify parameters via CheatEngine, verify they apply)
- [ ] Test three-tier fallback (runtimeCfg → variant → default)
- [ ] Verify difficulty_modifier scales parameters correctly
- [ ] Test all 3 games with 3 variants each (9 total configurations)
- [ ] Verify variant JSON loading works (no crashes)
- [ ] Test extreme parameter values (very high/low) to catch edge cases
```

---

## Phase 5: Advanced Mechanics - Coin Flip

**Goal**: Add pattern modes, victory conditions, visual enhancements, history display.

### Tasks

#### Pattern Modes
- [ ] Implement pattern_mode switch in flip generation:
  - [ ] "random" - Use coin_bias for each flip (already done)
  - [ ] "alternating" - Force H-T-H-T-H-T pattern (ignore coin_bias after first flip)
  - [ ] "clusters" - Generate runs of same result (HHHTTTHHH), use cluster_length parameter
  - [ ] "biased_random" - Weighted RNG with streak likelihood adjustment
- [ ] Store pattern state (for alternating/cluster modes)
- [ ] Ensure determinism across demo playback

#### Victory Conditions
- [ ] Implement victory_condition switch in `checkComplete()`:
  - [ ] "streak" - Reach streak_target consecutive (already done)
  - [ ] "total" - Reach total_correct_target total correct guesses
  - [ ] "ratio" - Maintain ratio_target accuracy over ratio_flip_count flips
  - [ ] "time" - Get highest streak within time_limit seconds
- [ ] Add victory_limit, total_correct_target, ratio_target, ratio_flip_count, time_limit parameters
- [ ] Track additional state for each victory condition

#### History Display
- [ ] Implement show_pattern_history in view:
  - [ ] Store last N flip results in array (H, T, H, T, H)
  - [ ] Display as string in HUD (e.g., "History: HTHHT")
  - [ ] Use pattern_history_length parameter for array size
- [ ] Add visual indicator for current streak (highlight consecutive correct guesses)

#### Visual Enhancements
- [ ] Implement flip animation:
  - [ ] Rotate coin sprite during flip (or use sprite frames)
  - [ ] Use flip_animation_speed parameter for duration
- [ ] Implement celebration_on_streak:
  - [ ] Particle effects or screen flash on milestone (every 5 correct)
  - [ ] Use streak_milestone parameter
- [ ] Add result_announce_mode:
  - [ ] "text" - Show "CORRECT!" or "WRONG!" text
  - [ ] "voice" - TTS announcement (if TTS system available)
  - [ ] "both" - Text + voice
  - [ ] "none" - Silent (player must watch coin)

#### Auto-Flip Mode
- [ ] Implement auto_flip_interval:
  - [ ] If > 0, coin automatically flips every X seconds
  - [ ] Player must guess BEFORE flip completes (time pressure)
  - [ ] If no guess, use default (heads or random)
- [ ] Add time_per_flip countdown timer display

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- Pattern mode determinism approach?
- How to store pattern state for demo playback?
- Flip animation technique (rotation? sprite swap?)
```

### Testing & Validation
```
Testing checklist:
- [ ] Test "alternating" pattern mode (verify H-T-H-T pattern)
- [ ] Test "clusters" pattern mode (verify runs of same result)
- [ ] Test "total" victory condition (reach X correct without streak requirement)
- [ ] Test "ratio" victory condition (maintain 70% accuracy over 30 flips)
- [ ] Test "time" victory condition (best streak in 60 seconds)
- [ ] Test history display (verify last N results shown)
- [ ] Test auto-flip mode (coin flips automatically every X seconds)
- [ ] Test time_per_flip countdown (time pressure)
- [ ] Test celebration effects on streak milestones
- [ ] Verify all modes work with demo recording/playback
```

---

## Phase 6: Advanced Mechanics - RPS

**Goal**: Add extended game modes (RPSLS), advanced AI patterns, lives system, special rounds, history tracking.

### Tasks

#### Extended Game Modes
- [ ] Implement game_mode switch:
  - [ ] "rps" - Rock/Paper/Scissors (3 options) - already done
  - [ ] "rpsls" - Rock/Paper/Scissors/Lizard/Spock (5 options from Big Bang Theory)
  - [ ] "rpsfb" - Rock/Paper/Scissors/Fire/Water (5 options, elemental theme)
- [ ] Create win matrices for RPSLS and RPSFB:
  - [ ] RPSLS: Rock crushes Scissors/Lizard, Paper covers Rock/Spock, Scissors cuts Paper/Lizard, Lizard eats Paper/poisons Spock, Spock vaporizes Rock/smashes Scissors
  - [ ] RPSFB: Rock crushes Scissors, Paper covers Rock, Scissors cuts Paper, Fire burns Paper, Water extinguishes Fire
- [ ] Add key bindings for extended modes:
  - [ ] 'l' = lizard (RPSLS)
  - [ ] 'v' = spock (RPSLS)
  - [ ] 'f' = fire (RPSFB)
  - [ ] 'w' = water (RPSFB)

#### Double Hands Mode (Squid Game Style)
- [ ] Implement hands_mode switch:
  - [ ] "single" - Classic one hand (already done in Phase 2)
  - [ ] "double" - Both hands mode (show two, remove one)
- [ ] **Double hands flow**:
  - [ ] Phase 1: Both players select TWO throws simultaneously
    - Player uses number keys: 1-5 for left hand, 6-0 for right hand (or similar)
    - AI selects two throws (based on pattern, can be same or different)
  - [ ] Phase 2: Both players simultaneously remove ONE hand
    - Player presses key to remove left or right hand
    - AI decides which hand to remove (can use pattern/strategy)
    - Use time_per_removal timer
  - [ ] Phase 3: Remaining hands determine winner
  - [ ] Store both_hands_state before removal for history tracking (if show_both_hands_history enabled)
- [ ] **Demo recording compatibility**:
  - [ ] Record both hand selections + removal choice
  - [ ] Ensure deterministic AI decisions for both phases
- [ ] **Visual feedback**:
  - [ ] Show both hands during reveal phase
  - [ ] Highlight which hand is being removed
  - [ ] Animate removal (fade out or slide away)
  - [ ] Show final matchup clearly

#### Multiple Opponents Mode (Battle Royale)
- [ ] Implement opponent_count parameter (1-5+ AI opponents):
  - [ ] opponent_count == 1: Classic 1v1 (already done in Phase 2)
  - [ ] opponent_count == 2-5: Battle royale / tournament mode
- [ ] **Matchup structures**:
  - [ ] 2 opponents: Player vs AI1, Player vs AI2 (sequential or simultaneous)
  - [ ] 3+ opponents: Round-robin OR elimination bracket
  - [ ] Each AI has own pattern/bias (create array of AI configs)
- [ ] Implement multi_opponent_elimination modes:
  - [ ] "single_winner" - Last one standing wins (elimination tournament)
    - Each round, losers get eliminated
    - Winner advances to next round
    - Continue until only 1 remains
  - [ ] "points" - Accumulate points over total_rounds_limit rounds
    - Win = +1 point, Tie = 0, Loss = 0
    - Highest score after all rounds wins
  - [ ] "survival" - Avoid last place (weakest link style)
    - After X rounds, player with lowest score eliminated
    - Repeat until 2 remain, final showdown
- [ ] **Elimination tracking**:
  - [ ] Track elimination_order array (who got eliminated when)
  - [ ] Display elimination status in UI
  - [ ] Eliminated AIs stop playing but remain visible (grayed out)
  - [ ] Show "Player Eliminated - Game Over" or "Victory - All Opponents Eliminated"
- [ ] **Camera/Display modes** (camera_focus_mode):
  - [ ] "all" - Show all opponents on screen (grid layout)
  - [ ] "1v1" - Cycle through individual matchups
  - [ ] "player_only" - Show only player vs current opponent
- [ ] **Per-opponent metrics**:
  - [ ] Track rounds won/lost against each opponent
  - [ ] Display individual scores in HUD
  - [ ] Metrics for formula include total rounds won across all opponents

#### Advanced AI Patterns
- [ ] Implement remaining ai_pattern types:
  - [ ] "pattern_cycle" - AI cycles through options in order (R → P → S → repeat)
  - [ ] "mimic_player" - AI copies player's previous choice
  - [ ] "anti_player" - AI throws what player threw 2 rounds ago
- [ ] Implement ai_pattern_delay:
  - [ ] AI uses "random" pattern for first N rounds
  - [ ] After N rounds, activate the configured pattern
  - [ ] Prevents immediate pattern exploitation
- [ ] Add show_ai_pattern_hint:
  - [ ] If enabled, UI displays hint about AI behavior
  - [ ] "AI tends to repeat" / "AI counters you" / "AI has a pattern"

#### Victory Conditions
- [ ] Implement victory_condition switch:
  - [ ] "rounds" - Best of X (already done)
  - [ ] "first_to" - First to reach X wins (no "best of" requirement)
  - [ ] "streak" - Achieve X consecutive round wins
  - [ ] "total" - Win X total rounds (across unlimited total rounds)
  - [ ] "time" - Get highest round win count within X seconds
- [ ] Add first_to_target, streak_target, total_wins_target, time_limit parameters

#### Lives System
- [ ] Implement lives_system_enabled:
  - [ ] Player starts with lives_count lives
  - [ ] Losing a round costs 1 life
  - [ ] 0 lives = game over (even if not reached rounds_to_win)
- [ ] Display lives remaining in HUD
- [ ] Add visual feedback on life loss (screen flash, sound effect)

#### Special Rounds
- [ ] Implement double_or_nothing_rounds:
  - [ ] After X rounds, trigger special round
  - [ ] Winner gets 2 round wins, loser loses 1 round win
  - [ ] Display "DOUBLE OR NOTHING!" banner
- [ ] Implement sudden_death_enabled:
  - [ ] If total_rounds_limit reached without winner, next round is sudden death
  - [ ] Winner of next round wins entire match
- [ ] Implement reverse_mode:
  - [ ] Invert win matrix (losing throw wins)
  - [ ] Mind-bending variant
- [ ] Implement mirror_mode:
  - [ ] Ties count as wins for player
  - [ ] Makes game easier

#### History Tracking
- [ ] Implement show_player_history:
  - [ ] Store last N player throws in array
  - [ ] Display as string in HUD (e.g., "You: RPSPR")
  - [ ] Use history_length parameter
- [ ] Implement show_ai_history:
  - [ ] Store last N AI throws in array
  - [ ] Display as string in HUD (e.g., "AI: SRRPS")
- [ ] Add show_statistics:
  - [ ] Display win/loss/tie percentages
  - [ ] Update after each round

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- RPSLS/RPSFB win matrix structure?
- How to handle AI pattern state for complex patterns?
- Special rounds triggering logic?
```

### Testing & Validation
```
Testing checklist:
- [ ] Test RPSLS mode (5 options, verify win matrix correct)
- [ ] Test RPSFB mode (5 options, verify win matrix correct)
- [ ] **Double hands mode**:
  - [ ] Test single hands mode still works (backward compatibility)
  - [ ] Test double hands selection phase (player selects two throws)
  - [ ] Test removal phase (player removes one hand)
  - [ ] Test AI does double hands correctly
  - [ ] Test both_hands_history display
  - [ ] Test time_per_removal timer
  - [ ] Test demo recording captures both phases
  - [ ] Test demo playback with double hands
- [ ] **Multiple opponents**:
  - [ ] Test 2 opponents (player vs two AIs)
  - [ ] Test 3-5 opponents (battle royale)
  - [ ] Test "single_winner" elimination mode
  - [ ] Test "points" accumulation mode
  - [ ] Test "survival" weakest-link mode
  - [ ] Test elimination_order tracking
  - [ ] Test camera_focus_mode ("all", "1v1", "player_only")
  - [ ] Verify all opponents display correctly
  - [ ] Test eliminated opponents stop playing
  - [ ] Test per-opponent score tracking
- [ ] **Combinations**:
  - [ ] Test double hands + multiple opponents (complex!)
  - [ ] Test double hands + RPSLS + 3 opponents (maximum complexity)
  - [ ] Test different AI patterns per opponent
- [ ] Test "pattern_cycle" AI (verify R → P → S → R pattern)
- [ ] Test "mimic_player" AI (verify AI copies player's last throw)
- [ ] Test "anti_player" AI (verify AI throws player's 2-ago throw)
- [ ] Test ai_pattern_delay (random for N rounds, then pattern activates)
- [ ] Test "first_to" victory (first to 10 wins immediately)
- [ ] Test "streak" victory (3 consecutive wins = victory)
- [ ] Test "total" victory (win 15 total rounds across unlimited match)
- [ ] Test "time" victory (most wins in 60 seconds)
- [ ] Test lives system (3 lives, game over after 3 losses)
- [ ] Test double_or_nothing rounds (doubled stakes)
- [ ] Test sudden_death (after round limit, sudden death)
- [ ] Test reverse_mode (losing throw wins)
- [ ] Test mirror_mode (ties count as player wins)
- [ ] Test player/AI history display
- [ ] Test statistics display (win/loss/tie percentages)
- [ ] Verify all modes work with demo recording/playback
```

---

## Phase 7: Advanced Mechanics - Breakout (Part 1: Movement & Ball Physics)

**Goal**: Add movement type variations, ball gravity, multi-ball, ball homing, ball physics modifiers.

### Tasks

#### Movement Types
- [ ] Implement movement_type switch:
  - [ ] "default" - WASD/Arrow direct velocity (already done)
  - [ ] "rail" - Fixed high-speed lateral movement (rapid side-to-side, common in arcade Breakout)
  - [ ] "asteroids" - Rotate and thrust with momentum (like Dodge game asteroids mode)
  - [ ] "jump" - Discrete teleport jumps between positions (like Dodge game jump mode)
- [ ] For "rail" mode:
  - [ ] Paddle moves at constant high speed left/right
  - [ ] Left key = move left, right key = move right, no key = stop
  - [ ] Very responsive, arcade-like feel
- [ ] For "asteroids" mode:
  - [ ] Up key = thrust in facing direction
  - [ ] Left/right keys = rotate paddle
  - [ ] Paddle has velocity and momentum (apply friction)
  - [ ] Use rotation_speed, accel_friction, decel_friction parameters
- [ ] For "jump" mode:
  - [ ] WASD keys trigger instant teleport jumps
  - [ ] Use jump_distance parameter
  - [ ] Apply jump_cooldown (can't jump again for X seconds)

#### Ball Gravity
- [ ] Implement ball_gravity:
  - [ ] Apply constant downward acceleration to ball (if > 0)
  - [ ] Ball follows arc trajectory instead of straight line
  - [ ] Makes physics more complex and interesting
- [ ] Implement ball_gravity_direction:
  - [ ] 270 = down (standard gravity)
  - [ ] 90 = up (reverse gravity)
  - [ ] 0 = right (side gravity)
  - [ ] 180 = left (side gravity)
  - [ ] Apply force in specified direction

#### Multi-Ball System
- [ ] Implement ball_count:
  - [ ] Spawn N balls simultaneously at game start
  - [ ] Each ball has independent position, velocity
  - [ ] Track all balls in array: `self.balls = {}`
  - [ ] Update/draw all balls in loops
  - [ ] Lose life when ALL balls fall off (not per ball)
- [ ] Ball spawning:
  - [ ] Spawn balls at paddle position with variance in angle
  - [ ] Use ball_spawn_angle_variance parameter
- [ ] Handle ball respawn after miss:
  - [ ] Respawn single ball (or all balls, depending on variant)

#### Ball Physics Modifiers
- [ ] Implement ball_speed_increase_per_bounce:
  - [ ] After each brick collision, increase ball speed by X
  - [ ] Clamp to ball_max_speed
  - [ ] Creates escalating difficulty
- [ ] Implement ball_bounce_randomness:
  - [ ] Add slight random variation to bounce angle (0.0 = perfect, 0.3 = chaotic)
  - [ ] Makes game less predictable
- [ ] Implement ball_homing:
  - [ ] Ball gradually curves toward nearest brick
  - [ ] Use homing_strength parameter (0.0 = none, 1.0 = strong)
  - [ ] Calculate direction to nearest brick, apply small force
- [ ] Implement ball_phase_through_bricks:
  - [ ] Ball can pass through X bricks before bouncing
  - [ ] Track pierce_count per ball
  - [ ] Decrement on brick collision, bounce when 0

#### Ball Visuals
- [ ] Implement ball_trail_length:
  - [ ] Store last N ball positions in array per ball
  - [ ] Draw trail as fading circles or line
  - [ ] Use trail_length parameter
- [ ] Implement ball_spin_enabled:
  - [ ] Track ball spin state (rotation angle)
  - [ ] Spin affects bounce angle (top-spin = downward angle, back-spin = upward angle)
  - [ ] Update spin on paddle collision based on paddle movement direction

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- Multi-ball array structure?
- Ball-ball collision (should they collide with each other)?
- Homing calculation approach (vector math)?
- Performance with many balls + many bricks?
```

### Testing & Validation
```
Testing checklist:
- [ ] Test "rail" movement (rapid side-to-side)
- [ ] Test "asteroids" movement (rotate + thrust, momentum)
- [ ] Test "jump" movement (teleport jumps with cooldown)
- [ ] Test ball_gravity (ball arcs downward)
- [ ] Test ball_gravity_direction (up, left, right gravity)
- [ ] Test multi-ball (3 balls simultaneously)
- [ ] Test ball_spawn_angle_variance (balls spawn at different angles)
- [ ] Test ball_speed_increase_per_bounce (ball accelerates)
- [ ] Test ball_max_speed (speed capped)
- [ ] Test ball_bounce_randomness (chaotic bounces)
- [ ] Test ball_homing (ball curves toward bricks)
- [ ] Test ball_phase_through_bricks (pierce 3 bricks before bouncing)
- [ ] Test ball_trail (visual comet trail)
- [ ] Test ball_spin (affects bounce angles)
- [ ] Verify all modes work with demo recording/playback
```

---

## Phase 8: Advanced Mechanics - Breakout (Part 2: Brick System & Power-Ups)

**Goal**: Add brick layouts, brick behaviors (falling, regenerating, moving), power-up system.

### Tasks

#### Brick Layouts
- [ ] Implement brick_layout generation:
  - [ ] "grid" - Standard rows/columns (already done)
  - [ ] "pyramid" - Triangle formation (more bricks at bottom, fewer at top)
  - [ ] "circle" - Circular arrangement around center
  - [ ] "random" - Scattered placement
  - [ ] "maze" - Corridor patterns with gaps
  - [ ] "checkerboard" - Alternating gaps (chess board pattern)
- [ ] Create layout generation functions:
  - [ ] `generateGridLayout(rows, columns)` - Standard grid
  - [ ] `generatePyramidLayout()` - Triangle
  - [ ] `generateCircleLayout(radius, ring_count)` - Concentric circles
  - [ ] `generateRandomLayout(brick_count)` - Random positions
  - [ ] `generateMazeLayout()` - Corridor pattern

#### Brick Health System
- [ ] Implement multi-hit bricks:
  - [ ] Each brick has `health` property
  - [ ] On collision, reduce health by 1 (or by ball damage)
  - [ ] If health == 0, mark brick as destroyed
  - [ ] Visual feedback: change brick color/sprite based on remaining health
- [ ] Implement brick_health_variance:
  - [ ] Each brick gets random health: `base_health ± variance`
  - [ ] Creates mix of weak/strong bricks

#### Brick Behaviors
- [ ] Implement brick_fall_enabled:
  - [ ] All bricks slowly fall downward at brick_fall_speed
  - [ ] Update brick y positions each frame
  - [ ] Game over if bricks reach paddle (Tetris hybrid)
- [ ] Implement brick_movement_enabled:
  - [ ] Bricks drift left/right at brick_movement_speed
  - [ ] Bounce off walls (reverse direction)
  - [ ] Makes hitting them harder
- [ ] Implement brick_regeneration_enabled:
  - [ ] When brick destroyed, start regeneration timer (brick_regeneration_time seconds)
  - [ ] After timer expires, brick respawns at same position
  - [ ] Creates "endless" variants where you can never fully clear screen
- [ ] Implement brick_size_variance:
  - [ ] Each brick gets random size: `base_size ± variance`
  - [ ] Affects collision area

#### Power-Up System
- [ ] Create power-up entity type: `{x, y, type, vx, vy, active}`
- [ ] Implement powerup_spawn:
  - [ ] On brick destruction, roll random chance (brick_powerup_drop_chance)
  - [ ] If success, spawn power-up at brick position
  - [ ] Choose random type from powerup_types array
- [ ] Implement power-up physics:
  - [ ] Power-ups fall at powerup_fall_speed
  - [ ] Detect collision with paddle (collect power-up)
  - [ ] Apply power-up effect
- [ ] Implement power-up types:
  - [ ] "multi_ball" - Spawn 2 additional balls
  - [ ] "paddle_extend" - Increase paddle width by 50% for powerup_duration seconds
  - [ ] "paddle_shrink" - Decrease paddle width by 50% (bad power-up!)
  - [ ] "slow_motion" - Reduce ball speed by 50% for powerup_duration
  - [ ] "fast_ball" - Increase ball speed by 50% (bad power-up!)
  - [ ] "laser" - Enable paddle_can_shoot for powerup_duration
  - [ ] "sticky_paddle" - Enable paddle_sticky for powerup_duration
  - [ ] "extra_life" - Grant +1 life immediately
  - [ ] "shield" - Spawn barrier at bottom (blocks one miss)
  - [ ] "penetrating_ball" - Set ball_phase_through_bricks = 5 for powerup_duration
  - [ ] "fireball" - Ball destroys bricks in radius on contact for powerup_duration
  - [ ] "magnet" - Set paddle_magnet_range = 150 for powerup_duration
- [ ] Track active power-ups:
  - [ ] Array of active power-ups with timers
  - [ ] Update timers each frame
  - [ ] Remove expired power-ups, restore default values
- [ ] Display active power-ups in HUD with countdown timers

#### Power-Up Visuals
- [ ] Create power-up sprites (or colored circles with icons)
- [ ] Different colors per type (multi_ball = blue, paddle_extend = green, etc.)
- [ ] Animate power-ups (pulse, rotate, glow)
- [ ] Show power-up name on collection ("MULTI-BALL!")

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- Brick layout generation algorithm details?
- Power-up effect stacking (can you have multiple power-ups active)?
- Brick regeneration timer management?
- Performance with falling/moving bricks?
```

### Testing & Validation
```
Testing checklist:
- [ ] Test "pyramid" layout (triangle formation)
- [ ] Test "circle" layout (concentric rings)
- [ ] Test "random" layout (scattered bricks)
- [ ] Test "maze" layout (corridor pattern)
- [ ] Test multi-hit bricks (brick requires 3 hits to destroy)
- [ ] Test brick_health_variance (mix of weak/strong bricks)
- [ ] Test brick_fall (bricks slowly descend, game over if reach paddle)
- [ ] Test brick_movement (bricks drift horizontally)
- [ ] Test brick_regeneration (destroyed bricks respawn after X seconds)
- [ ] Test power-up spawning (drop from destroyed bricks)
- [ ] Test all power-up types:
  - [ ] multi_ball (spawns 2 extra balls)
  - [ ] paddle_extend (paddle grows)
  - [ ] paddle_shrink (paddle shrinks - bad!)
  - [ ] slow_motion (ball slows down)
  - [ ] fast_ball (ball speeds up - bad!)
  - [ ] laser (paddle can shoot)
  - [ ] sticky_paddle (ball sticks to paddle)
  - [ ] extra_life (+1 life)
  - [ ] shield (barrier at bottom)
  - [ ] penetrating_ball (pierce through bricks)
  - [ ] fireball (destroy radius on contact)
  - [ ] magnet (ball attracted to paddle)
- [ ] Test power-up duration (effects expire after X seconds)
- [ ] Test power-up stacking (multiple power-ups active)
- [ ] Verify all modes work with demo recording/playback
```

---

## Phase 9: Paddle Mechanics & Special Features (Breakout)

**Goal**: Add paddle shooting, sticky paddle, magnet paddle, paddle friction, obstacles.

### Tasks

#### Paddle Shooting
- [ ] Implement paddle_can_shoot:
  - [ ] When enabled, spacebar fires bullets upward from paddle
  - [ ] Create bullet entity type: `{x, y, vy, damage}`
  - [ ] Bullets move at constant upward velocity
  - [ ] Apply paddle_shoot_cooldown (can't shoot again for X seconds)
- [ ] Bullet-brick collision:
  - [ ] Detect overlap between bullet and brick
  - [ ] Reduce brick health by paddle_shoot_damage
  - [ ] Destroy bullet on collision
- [ ] Display shoot cooldown in HUD (bar or timer)

#### Sticky Paddle
- [ ] Implement paddle_sticky:
  - [ ] When ball collides with paddle, set ball.stuck = true
  - [ ] Ball moves with paddle (maintains offset from paddle center)
  - [ ] Spacebar releases ball (fire ball in aimed direction)
  - [ ] Allow aiming: left/right keys adjust launch angle while stuck
- [ ] Visual feedback: draw line from paddle to ball showing launch trajectory

#### Magnet Paddle
- [ ] Implement paddle_magnet_range:
  - [ ] If ball is within range of paddle, apply attractive force
  - [ ] Force strength increases as ball gets closer
  - [ ] Ball gradually curves toward paddle
  - [ ] Helps catch balls that would otherwise miss

#### Paddle Friction
- [ ] Implement paddle_friction:
  - [ ] When no input, apply deceleration to paddle velocity
  - [ ] paddle_friction = 1.0: instant stop
  - [ ] paddle_friction = 0.95: gradual drift to stop (ice physics)
  - [ ] Affects "default" and "asteroids" movement types

#### Arena Obstacles
- [ ] Implement obstacles_count:
  - [ ] Spawn N static obstacles in play area at init
  - [ ] Obstacles are hazards (block ball, don't destroy)
- [ ] Implement obstacles_shape:
  - [ ] "rectangle" - Rectangular obstacles
  - [ ] "circle" - Circular obstacles
  - [ ] "triangle" - Triangular obstacles
- [ ] Implement obstacles_destructible:
  - [ ] If true, ball can destroy obstacle after X hits
  - [ ] If false, obstacle is permanent hazard
- [ ] Ball-obstacle collision:
  - [ ] Detect overlap
  - [ ] Bounce ball off obstacle
  - [ ] If destructible, reduce obstacle health

#### Arena Boundaries
- [ ] Implement ceiling_enabled:
  - [ ] If false, ball can escape upward
  - [ ] Creates "don't let it escape" challenge
  - [ ] Game over if ball leaves top boundary
- [ ] Implement bottom_kill_enabled:
  - [ ] If false, ball bounces off bottom instead of falling off
  - [ ] Makes game much easier (no life loss)
- [ ] Implement wall_bounce_mode:
  - [ ] "normal" - Standard elastic bounce (already done)
  - [ ] "damped" - Bounce loses energy (ball velocity reduced by 50%)
  - [ ] "sticky" - Ball briefly sticks to wall before releasing
  - [ ] "wrap" - Asteroids-style screen wrap (ball exits right, appears left)

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- Paddle shooting: separate bullet array? Or add to entities list?
- Sticky paddle: how to handle ball velocity on release?
- Magnet force calculation?
- Obstacle collision optimization?
```

### Testing & Validation
```
Testing checklist:
- [ ] Test paddle_can_shoot (spacebar fires bullets upward)
- [ ] Test paddle_shoot_cooldown (can't spam shoot)
- [ ] Test paddle_shoot_damage (bullets destroy/damage bricks)
- [ ] Test paddle_sticky (ball sticks to paddle on contact)
- [ ] Test sticky paddle aiming (left/right adjust angle while stuck)
- [ ] Test sticky paddle release (spacebar launches ball)
- [ ] Test paddle_magnet_range (ball attracted to paddle)
- [ ] Test paddle_friction (paddle drifts to stop vs instant stop)
- [ ] Test obstacles (static hazards in play area)
- [ ] Test obstacles_shape (rectangle, circle, triangle)
- [ ] Test obstacles_destructible (destroy after X hits vs permanent)
- [ ] Test ceiling_enabled = false (ball escapes upward)
- [ ] Test bottom_kill_enabled = false (ball bounces off bottom)
- [ ] Test wall_bounce_mode "damped" (energy loss on bounce)
- [ ] Test wall_bounce_mode "sticky" (ball sticks briefly)
- [ ] Test wall_bounce_mode "wrap" (screen wrap)
- [ ] Verify all modes work with demo recording/playback
```

---

## Phase 10: Victory Conditions & Scoring (All Games)

**Goal**: Implement all victory condition types, scoring systems, perfect bonuses, combo systems.

**This phase applies to ALL 3 GAMES.**

### Tasks

#### Coin Flip - Victory & Scoring
- [ ] Implement all victory_condition types (already done in Phase 5):
  - [ ] Verify "streak", "total", "ratio", "time" all work correctly
- [ ] Implement scoring system:
  - [ ] Award score_per_correct points per correct guess
  - [ ] Apply streak_multiplier (score × (1 + streak * multiplier))
  - [ ] Award perfect_streak_bonus if reached target without mistakes
- [ ] Add score display to HUD
- [ ] Add final score to game completion screen

#### RPS - Victory & Scoring
- [ ] Implement all victory_condition types (already done in Phase 6):
  - [ ] Verify "rounds", "first_to", "streak", "total", "time" all work correctly
- [ ] Implement scoring system:
  - [ ] Award score_per_round_win points per round won
  - [ ] Award streak_bonus for consecutive wins (bonus × streak_length)
  - [ ] Award perfect_game_bonus if won without losing any rounds
- [ ] Add score display to HUD
- [ ] Add final score to game completion screen

#### Breakout - Victory & Scoring
- [ ] Implement all victory_condition types:
  - [ ] "clear_bricks" - Destroy all bricks (already done)
  - [ ] "destroy_count" - Destroy X bricks (partial clear)
  - [ ] "score" - Reach X score points
  - [ ] "time" - Survive X seconds without losing all lives
  - [ ] "survival" - Endless mode (never complete, just high score)
- [ ] Implement scoring system:
  - [ ] Award points per brick destroyed (base × brick_score_multiplier)
  - [ ] Track combo (consecutive brick hits without paddle touch)
  - [ ] Award combo bonus (points × combo_multiplier)
  - [ ] Award perfect_clear_bonus if cleared without losing any balls
- [ ] Implement extra_ball_score_threshold:
  - [ ] Award +1 life when score crosses threshold
  - [ ] Track last_threshold to prevent duplicate awards
- [ ] Add score display to HUD
- [ ] Add final score to game completion screen

#### Score Popups (All Games)
- [ ] Implement score popups for visual feedback:
  - [ ] When scoring event happens, spawn floating text
  - [ ] Text rises and fades over 1-2 seconds
  - [ ] Different colors for different event types (brick = white, combo = yellow, bonus = green)
- [ ] Toggle with score_popup_enabled parameter

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- Score formula approach (how to calculate combo multipliers)?
- Score popup rendering (separate array? Entity system?)
- Victory condition state tracking?
```

### Testing & Validation
```
Testing checklist:
Coin Flip:
- [ ] Test all victory conditions work correctly
- [ ] Test scoring (score_per_correct, streak_multiplier)
- [ ] Test perfect_streak_bonus (reach target without mistakes)
- [ ] Verify score displayed in HUD

RPS:
- [ ] Test all victory conditions work correctly
- [ ] Test scoring (score_per_round_win, streak_bonus)
- [ ] Test perfect_game_bonus (win without losing rounds)
- [ ] Verify score displayed in HUD

Breakout:
- [ ] Test "clear_bricks" victory (destroy all)
- [ ] Test "destroy_count" victory (destroy 50 bricks)
- [ ] Test "score" victory (reach 10,000 points)
- [ ] Test "time" victory (survive 60 seconds)
- [ ] Test "survival" mode (endless, never completes)
- [ ] Test combo system (consecutive brick hits)
- [ ] Test perfect_clear_bonus (clear without losing balls)
- [ ] Test extra_ball_score_threshold (earn extra life at score)
- [ ] Test score popups (floating numbers on brick destruction)
- [ ] Verify score displayed in HUD

All Games:
- [ ] Verify metrics tracked correctly for formulas
- [ ] Test with CheatEngine (modify scoring parameters)
- [ ] Test with different variants (different victory conditions)
```

---

## Phase 11: Visual Effects & Polish (All Games)

**Goal**: Add particle effects, camera shake, fog of war, animations, screen flash, visual feedback.

**This phase applies to ALL 3 GAMES.**

### Tasks

#### Breakout - Visual Effects
- [ ] Implement particle effects:
  - [ ] Brick destruction particles (explosion of colored squares)
  - [ ] Power-up collection particles (sparkles)
  - [ ] Ball trail particles (comet tail)
  - [ ] Toggle with particle_effects_enabled
- [ ] Implement camera shake:
  - [ ] On brick destruction, apply screen shake
  - [ ] Use camera_shake_intensity parameter
  - [ ] Shake decays exponentially
  - [ ] Apply shake offset in draw() via love.graphics.translate()
  - [ ] Toggle with camera_shake_enabled
- [ ] Implement brick_flash_on_hit:
  - [ ] When brick hit (but not destroyed), flash brick white for 1 frame
  - [ ] Visual feedback for multi-hit bricks
- [ ] Implement fog_of_war:
  - [ ] Limited visibility around ball/paddle
  - [ ] Use fog_of_war_radius parameter
  - [ ] Render scene to canvas, apply radial gradient mask
  - [ ] Toggle with fog_of_war_enabled

#### Coin Flip - Visual Effects
- [ ] Implement flip animation:
  - [ ] Smooth coin rotation during flip
  - [ ] Use flip_animation_speed parameter
  - [ ] Sprite rotation or frame-based animation
- [ ] Implement result announcement:
  - [ ] "CORRECT!" / "WRONG!" text with animation (scale up, fade out)
  - [ ] Screen flash on correct guess (green) or wrong guess (red)
  - [ ] Particle effects on milestone streaks (every 5 correct)
- [ ] Implement celebration effects:
  - [ ] Confetti particles on streak milestone
  - [ ] Screen flash
  - [ ] Toggle with celebration_on_streak

#### RPS - Visual Effects
- [ ] Implement throw animation:
  - [ ] Hand sprites animate from neutral to throw position
  - [ ] Use animation_speed parameter for timing
  - [ ] Different sprites for rock/paper/scissors/lizard/spock
- [ ] Implement result announcement:
  - [ ] "YOU WIN!" / "AI WINS!" / "TIE!" text with animation
  - [ ] Screen flash on win (green) or loss (red)
  - [ ] Particle effects on perfect game (won without losing any rounds)
- [ ] Implement throw_animation_style:
  - [ ] "hands" - Hand sprites
  - [ ] "icons" - Rock/paper/scissors icons
  - [ ] "text" - Text only ("ROCK" / "PAPER" / "SCISSORS")
  - [ ] "emojis" - Emoji symbols (✊/✋/✌️)

#### All Games - HUD Polish
- [ ] Add icons to HUD elements (lives icon, score icon, etc.)
- [ ] Add background panels to HUD (semi-transparent boxes)
- [ ] Add font variations (bold for labels, normal for values)
- [ ] Add color coding (green = good, red = bad, yellow = warning)

#### All Games - Transitions
- [ ] Game start transition (fade in, "READY?" countdown)
- [ ] Game over transition (fade to black, "GAME OVER" text)
- [ ] Victory transition (confetti, "VICTORY!" text)
- [ ] Level/round transition (fade between rounds for RPS)

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- Particle system approach (custom? Library?)
- Camera shake implementation (transform matrix?)
- Fog of war rendering technique (canvas + mask?)
- Animation timing (frame-based? Time-based?)
```

### Testing & Validation
```
Testing checklist:
Breakout:
- [ ] Test brick destruction particles
- [ ] Test power-up collection particles
- [ ] Test ball trail particles
- [ ] Test camera shake on brick destruction
- [ ] Test brick flash on hit
- [ ] Test fog of war (limited visibility)
- [ ] Verify particles don't cause lag with many bricks
- [ ] Test with particle_effects_enabled = false (no particles)

Coin Flip:
- [ ] Test flip animation (smooth rotation)
- [ ] Test result announcement ("CORRECT!" / "WRONG!")
- [ ] Test screen flash on guess result
- [ ] Test celebration effects on milestone (every 5 correct)
- [ ] Test with celebration_on_streak = false (no effects)

RPS:
- [ ] Test throw animation (hand sprites animate)
- [ ] Test result announcement ("YOU WIN!" / "AI WINS!" / "TIE!")
- [ ] Test screen flash on round result
- [ ] Test throw_animation_style variations (hands, icons, text, emojis)
- [ ] Test perfect game celebration (confetti on winning without losing)

All Games:
- [ ] Test HUD polish (icons, backgrounds, colors)
- [ ] Test game start transition (fade in, countdown)
- [ ] Test game over transition (fade out, game over text)
- [ ] Test victory transition (confetti, victory text)
- [ ] Verify visual effects work at different screen resolutions
- [ ] Test visual effects with demo playback (verify deterministic)
```

---

## Phase 12: Formula Integration & Metrics (All Games)

**Goal**: Finalize formula calculations, ensure all metrics tracked correctly, integrate with token generation, verify scaling_constant usage.

**This phase applies to ALL 3 GAMES.**

### Tasks

#### Coin Flip - Formula
- [ ] Verify metrics tracking:
  - [ ] `streak` - Current consecutive correct
  - [ ] `max_streak` - Highest streak achieved
  - [ ] `correct_total` - Total correct guesses
  - [ ] `incorrect_total` - Total wrong guesses
  - [ ] `flips_total` - Total flips
  - [ ] `accuracy` - correct_total / flips_total
- [ ] Define formula in base_game_definitions.json:
  - [ ] `base_formula_string`: `"(max_streak^2 * (1 + correct_total/10) * scaling_constant)"`
  - [ ] `display_formula_string`: `"max_streak × correct_total"`
- [ ] Update metrics each flip (correct, incorrect, streak, etc.)
- [ ] Verify metrics available in `self.metrics` table on game completion

#### RPS - Formula
- [ ] Verify metrics tracking:
  - [ ] `rounds_won` - Player rounds won
  - [ ] `rounds_lost` - AI rounds won
  - [ ] `rounds_tied` - Tie rounds
  - [ ] `rounds_total` - Total rounds played
  - [ ] `win_streak` - Current consecutive wins
  - [ ] `max_win_streak` - Highest consecutive wins
  - [ ] `accuracy` - rounds_won / (rounds_won + rounds_lost)
- [ ] Define formula in base_game_definitions.json:
  - [ ] `base_formula_string`: `"((rounds_won - rounds_lost)^2 * (1 + max_win_streak/5) * scaling_constant)"`
  - [ ] `display_formula_string`: `"(rounds_won - rounds_lost) × win_streak"`
- [ ] Update metrics each round (wins, losses, streak, etc.)
- [ ] Verify metrics available in `self.metrics` table on game completion

#### Breakout - Formula
- [ ] Verify metrics tracking:
  - [ ] `bricks_destroyed` - Total bricks destroyed
  - [ ] `bricks_remaining` - Bricks left on screen
  - [ ] `balls_lost` - Times ball fell off bottom
  - [ ] `combo` - Consecutive brick hits without paddle touch
  - [ ] `max_combo` - Highest combo achieved
  - [ ] `powerups_collected` - Power-ups caught
  - [ ] `score` - Total score accumulated
  - [ ] `time_elapsed` - Seconds played
  - [ ] `perfect_clear` - Boolean (1 if cleared without losing ball)
- [ ] Define formula in base_game_definitions.json:
  - [ ] `base_formula_string`: `"(bricks_destroyed^2 * (1 + max_combo/10) * scaling_constant) / (1 + balls_lost)"`
  - [ ] `display_formula_string`: `"bricks_destroyed × combo / balls_lost"`
- [ ] Update metrics each frame/event (brick destroyed, ball lost, combo, etc.)
- [ ] Verify metrics available in `self.metrics` table on game completion

#### Token Generation Integration
- [ ] All games inherit from BaseGame (already done)
- [ ] BaseGame.metrics table populated during gameplay
- [ ] On game completion, formula evaluated using metrics + scaling_constant
- [ ] Token value = formula result
- [ ] Verify tokens awarded correctly after game completion
- [ ] Test with different scaling_constant values (from config or Neural Core progression)

#### Auto-Play Performance (VM Demos)
- [ ] Define auto_play_performance in base_game_definitions.json for each game:
  - [ ] Coin Flip: `{"max_streak": 3, "correct_total": 10, "accuracy": 0.5}` (50% win rate)
  - [ ] RPS: `{"rounds_won": 5, "rounds_lost": 10, "max_win_streak": 2}` (33% win rate)
  - [ ] Breakout: `{"bricks_destroyed": 50, "balls_lost": 2, "max_combo": 5}` (decent paddle movement)
- [ ] VMs use auto_play_performance instead of best performance
- [ ] VM formula result = auto_play_performance plugged into formula
- [ ] Test VM token generation (should be lower than manual play)

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- Formula complexity (exponents? Square roots? Logarithms?)
- Metrics tracking frequency (every frame? Every event?)
- Auto-play performance estimation approach?
```

### Testing & Validation
```
Testing checklist:
Coin Flip:
- [ ] Play game, verify all metrics tracked (streak, correct, incorrect, etc.)
- [ ] Complete game, verify formula evaluated correctly
- [ ] Verify token award matches formula result
- [ ] Test with different scaling_constant values
- [ ] Verify auto_play_performance used by VMs

RPS:
- [ ] Play game, verify all metrics tracked (wins, losses, streak, etc.)
- [ ] Complete game, verify formula evaluated correctly
- [ ] Verify token award matches formula result
- [ ] Test with different scaling_constant values
- [ ] Verify auto_play_performance used by VMs

Breakout:
- [ ] Play game, verify all metrics tracked (bricks, balls lost, combo, etc.)
- [ ] Complete game, verify formula evaluated correctly
- [ ] Verify token award matches formula result
- [ ] Test with different scaling_constant values
- [ ] Verify auto_play_performance used by VMs

All Games:
- [ ] Verify metrics.time_elapsed tracks correctly
- [ ] Test formula with extreme values (very high/low metrics)
- [ ] Verify scaling_constant applied correctly
- [ ] Test with CheatEngine modifications (verify formula adjusts)
- [ ] Test VM demos (verify auto_play_performance used instead of best)
```

---

## Phase 13: Demo Recording & Playback (All Games)

**Goal**: Ensure all games support fixed timestep, demo recording, demo playback, VM compatibility, seed variation.

**This phase applies to ALL 3 GAMES - CRITICAL FOR VM SYSTEM.**

### Tasks

#### Fixed Timestep Implementation
- [ ] All games must implement `fixedUpdate(dt)`:
  - [ ] Coin Flip: Move flip timing, streak checks to fixedUpdate
  - [ ] RPS: Move round timing, AI decisions to fixedUpdate
  - [ ] Breakout: Move paddle, ball, brick updates to fixedUpdate
- [ ] Verify `self.fixed_dt` used (1/60 second default)
- [ ] Verify `self.accumulator` and `self.frame_count` managed correctly
- [ ] Call `updateWithFixedTimestep(dt)` from main game loop
- [ ] Do NOT call love.graphics functions in fixedUpdate (logic only)

#### Input Handling for Demo Recording
- [ ] All games capture input in `keypressed(key)` and `keyreleased(key)`:
  - [ ] Coin Flip: 'h', 't' keys for guess
  - [ ] RPS: 'r', 'p', 's', 'l', 'v' keys for throw
  - [ ] Breakout: WASD/Arrow keys for movement, spacebar for shoot/release
- [ ] Verify input events stored in DemoRecorder with frame numbers
- [ ] Test demo recording: press [S] at game completion to save demo

#### Playback Mode (Virtual Keyboard)
- [ ] All games respect `self.playback_mode` flag:
  - [ ] When true, ignore real keyboard input (love.keyboard.isDown)
  - [ ] Use `self.virtual_keys` table instead
- [ ] DemoPlayer injects inputs into `self.virtual_keys` at correct frames
- [ ] Verify deterministic behavior: same demo + same seed = same result

#### Seed Management
- [ ] All games use seeded RNG for randomness:
  - [ ] Coin Flip: RNG for flip result (based on coin_bias)
  - [ ] RPS: RNG for AI decisions (based on ai_pattern)
  - [ ] Breakout: RNG for brick spawning, power-up drops, ball spawn angle
- [ ] Initialize RNG in `init()` with `self.seed` (from game_data or variant)
- [ ] Verify same seed = same random sequence
- [ ] Test with different seeds: results vary but demo still playable

#### VM Compatibility Testing
- [ ] Record demo of each game (play manually, save demo)
- [ ] Assign demo to VM (via VM Manager)
- [ ] Test VM playback at 1x speed (watchable)
- [ ] Test VM playback at 10x speed (fast multi-step)
- [ ] Test VM playback at 100x speed
- [ ] Test VM playback at INSTANT speed (headless, no rendering)
- [ ] Verify VM generates tokens based on auto_play_performance
- [ ] Test with different seeds: VM succeeds some runs, fails others (expected)

#### Determinism Verification
- [ ] Record demo at seed 12345
- [ ] Replay demo 10 times at same seed
- [ ] Verify identical results every time (exact metrics, same outcome)
- [ ] Change seed to 67890
- [ ] Replay same demo at new seed
- [ ] Verify results differ (different RNG) but demo still playable

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- Any non-deterministic behavior found?
- RNG seeding approach (love.math.random? Custom RNG?)
- Playback mode input handling (any edge cases?)
- VM compatibility issues?
```

### Testing & Validation
```
Testing checklist:
All Games (Critical!):
- [ ] Verify fixedUpdate(dt) implemented correctly
- [ ] Verify self.fixed_dt = 1/60 used
- [ ] Verify input captured in keypressed/keyreleased
- [ ] Test demo recording (press [S] at completion)
- [ ] Test demo playback (load demo, replay game)
- [ ] Verify playback_mode flag respected (virtual keyboard used)
- [ ] Test determinism: replay demo 10 times at same seed, verify identical results
- [ ] Test seed variation: replay demo at different seed, verify different results
- [ ] Assign demo to VM, test VM playback at 1x/10x/100x/INSTANT speeds
- [ ] Verify VM generates tokens based on auto_play_performance
- [ ] Test VM with different seeds (some runs succeed, some fail - expected)

Coin Flip Specific:
- [ ] Test demo records H/T guesses correctly
- [ ] Verify flip results change with different seeds but demo still works
- [ ] Test VM: coin bias affects success rate (60% bias = more VM wins)

RPS Specific:
- [ ] Test demo records R/P/S/L/V throws correctly
- [ ] Verify AI choices change with different seeds but demo still works
- [ ] Test VM: AI patterns affect success rate (biased AI = exploitable)

Breakout Specific:
- [ ] Test demo records paddle movement + spacebar correctly
- [ ] Verify ball spawn angle changes with different seeds but demo still works
- [ ] Test VM: paddle movement transfers well, ball physics deterministic per seed
- [ ] Verify power-up drops vary by seed (RNG) but paddle still catches some
```

---

## Phase 14: CheatEngine Integration & Parameter Ranges (All Games)

**Goal**: Define all CheatEngine parameters, ranges, costs, hidden parameters, test CheatEngine modifications.

**This phase applies to ALL 3 GAMES.**

### Tasks

#### Config.lua - Parameter Ranges
- [ ] Add parameter ranges for Coin Flip to `config.cheat_engine.parameter_ranges`:
  - [ ] `streak_target`: {min = 1, max = 50}
  - [ ] `coin_bias`: {min = 0.0, max = 1.0}
  - [ ] `lives`: {min = 1, max = 999}
  - [ ] `time_per_flip`: {min = 0, max = 30}
  - [ ] `auto_flip_interval`: {min = 0, max = 5}
  - [ ] `flip_animation_speed`: {min = 0.1, max = 3}
  - [ ] `pattern_history_length`: {min = 3, max = 50}
  - [ ] `cluster_length`: {min = 2, max = 10}
  - [ ] `total_correct_target`: {min = 5, max = 200}
  - [ ] `ratio_target`: {min = 0.5, max = 1.0}
  - [ ] `ratio_flip_count`: {min = 10, max = 100}
  - [ ] `time_limit`: {min = 0, max = 300}
  - [ ] `score_per_correct`: {min = 0, max = 1000}
  - [ ] `streak_multiplier`: {min = 1.0, max = 3.0}
  - [ ] (All boolean parameters auto-detected)
- [ ] Add parameter ranges for RPS to `config.cheat_engine.parameter_ranges`:
  - [ ] `rounds_to_win`: {min = 1, max = 21}
  - [ ] `total_rounds_limit`: {min = 0, max = 51}
  - [ ] `ai_bias_strength`: {min = 0.4, max = 0.9}
  - [ ] `ai_pattern_delay`: {min = 0, max = 10}
  - [ ] `time_per_round`: {min = 0, max = 30}
  - [ ] `round_result_display_time`: {min = 0.5, max = 5}
  - [ ] `animation_speed`: {min = 0.3, max = 3}
  - [ ] `history_length`: {min = 3, max = 30}
  - [ ] `first_to_target`: {min = 1, max = 21}
  - [ ] `streak_target`: {min = 2, max = 20}
  - [ ] `total_wins_target`: {min = 5, max = 50}
  - [ ] `time_limit`: {min = 30, max = 300}
  - [ ] `score_per_round_win`: {min = 0, max = 1000}
  - [ ] `streak_bonus`: {min = 0, max = 500}
  - [ ] `perfect_game_bonus`: {min = 0, max = 5000}
  - [ ] `double_or_nothing_rounds`: {min = 0, max = 5}
  - [ ] `lives_count`: {min = 1, max = 10}
  - [ ] (All boolean parameters auto-detected)
- [ ] Add parameter ranges for Breakout to `config.cheat_engine.parameter_ranges`:
  - [ ] `paddle_width`: {min = 20, max = 200}
  - [ ] `paddle_speed`: {min = 50, max = 800}
  - [ ] `paddle_friction`: {min = 0.7, max = 1.0}
  - [ ] `paddle_magnet_range`: {min = 0, max = 200}
  - [ ] `paddle_shoot_cooldown`: {min = 0.1, max = 2}
  - [ ] `paddle_shoot_damage`: {min = 1, max = 10}
  - [ ] `ball_count`: {min = 1, max = 20}
  - [ ] `ball_speed`: {min = 50, max = 800}
  - [ ] `ball_speed_increase_per_bounce`: {min = 0, max = 50}
  - [ ] `ball_max_speed`: {min = 100, max = 1500}
  - [ ] `ball_size`: {min = 4, max = 20}
  - [ ] `ball_gravity`: {min = 0, max = 1000}
  - [ ] `ball_gravity_direction`: {min = 0, max = 360}
  - [ ] `ball_bounce_randomness`: {min = 0, max = 0.5}
  - [ ] `ball_trail_length`: {min = 0, max = 50}
  - [ ] `ball_phase_through_bricks`: {min = 0, max = 10}
  - [ ] `ball_homing`: {min = 0, max = 1}
  - [ ] `ball_spawn_angle_variance`: {min = 0, max = 90}
  - [ ] `brick_rows`: {min = 1, max = 20}
  - [ ] `brick_columns`: {min = 4, max = 30}
  - [ ] `brick_health`: {min = 1, max = 20}
  - [ ] `brick_health_variance`: {min = 0, max = 1}
  - [ ] `brick_regeneration_time`: {min = 1, max = 60}
  - [ ] `brick_fall_speed`: {min = 1, max = 50}
  - [ ] `brick_movement_speed`: {min = 5, max = 100}
  - [ ] `brick_size_variance`: {min = 0, max = 1}
  - [ ] `brick_score_multiplier`: {min = 0.5, max = 5}
  - [ ] `brick_powerup_drop_chance`: {min = 0, max = 1}
  - [ ] `arena_width`: {min = 200, max = 800}
  - [ ] `arena_height`: {min = 300, max = 800}
  - [ ] `obstacles_count`: {min = 0, max = 30}
  - [ ] `powerup_duration`: {min = 1, max = 60}
  - [ ] `powerup_fall_speed`: {min = 20, max = 300}
  - [ ] `lives`: {min = 1, max = 20}
  - [ ] `extra_ball_score_threshold`: {min = 0, max = 50000}
  - [ ] `difficulty_scaling_rate`: {min = 1, max = 50}
  - [ ] `fog_of_war_radius`: {min = 50, max = 500}
  - [ ] `camera_shake_intensity`: {min = 0, max = 20}
  - [ ] `victory_limit`: {min = 0, max = 10000}
  - [ ] `perfect_clear_bonus`: {min = 0, max = 10000}
  - [ ] (All boolean parameters auto-detected)

#### Config.lua - Hidden Parameters
- [ ] Add hidden_parameters for Coin Flip (not editable in CheatEngine):
  - [ ] Metadata: `clone_index`, `name`, `flavor_text`
  - [ ] Visual: `coin_sprite`
  - [ ] Enums: `pattern_mode`, `victory_condition`, `result_announce_mode`
- [ ] Add hidden_parameters for RPS (not editable in CheatEngine):
  - [ ] Metadata: `clone_index`, `name`, `flavor_text`
  - [ ] Visual: `throw_animation_style`, `celebration_mode`, `color_scheme`
  - [ ] Enums: `game_mode`, `ai_pattern`, `ai_bias`, `auto_timeout_choice`, `victory_condition`, `result_announce_mode`
- [ ] Add hidden_parameters for Breakout (not editable in CheatEngine):
  - [ ] Metadata: `clone_index`, `name`, `flavor_text`, `intro_cutscene`
  - [ ] Visual: `sprite_set`, `palette`, `music_track`, `sfx_pack`, `background`
  - [ ] Enums: `movement_type`, `brick_layout`, `wall_bounce_mode`, `obstacles_shape`, `powerup_spawn_mode`, `victory_condition`
  - [ ] Arrays: `powerup_types`

#### Base Game Definitions - Available Cheats
- [ ] Define available_cheats for Coin Flip in base_game_definitions.json:
  - [ ] `speed_modifier` - Affects flip_animation_speed, time_per_flip
  - [ ] `advantage_modifier` - Affects lives (extra lives)
  - [ ] `performance_modifier` - Affects coin_bias (adjust odds)
- [ ] Define available_cheats for RPS in base_game_definitions.json:
  - [ ] `speed_modifier` - Affects round_result_display_time, animation_speed
  - [ ] `advantage_modifier` - Affects rounds_to_win (AI needs more wins)
  - [ ] `performance_modifier` - Affects show_ai_pattern_hint (hints enabled)
- [ ] Define available_cheats for Breakout in base_game_definitions.json:
  - [ ] `speed_modifier` - Affects ball_speed, paddle_speed
  - [ ] `advantage_modifier` - Affects lives (extra lives)
  - [ ] `performance_modifier` - Affects paddle_shoot_damage, ball_phase_through_bricks

#### Testing CheatEngine
- [ ] Open CheatEngine for each game
- [ ] Verify all editable parameters appear with sliders/toggles
- [ ] Verify hidden parameters do NOT appear
- [ ] Modify parameters, verify they apply in-game
- [ ] Test extreme values (min/max)
- [ ] Verify CheatEngine costs scale correctly
- [ ] Test with multiple cheats active simultaneously

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- Any parameters that need special handling in CheatEngine?
- Parameter range tuning (are min/max values appropriate)?
- Cheat cost balancing?
```

### Testing & Validation
```
Testing checklist:
Coin Flip:
- [ ] Open CheatEngine, verify all numeric/boolean parameters appear
- [ ] Verify hidden parameters (pattern_mode, victory_condition, etc.) do NOT appear
- [ ] Modify streak_target, verify game uses new value
- [ ] Modify coin_bias, verify flip results affected
- [ ] Modify lives, verify game uses new value
- [ ] Test extreme values (streak_target = 1 vs 50)
- [ ] Test cheat costs (verify token deduction)

RPS:
- [ ] Open CheatEngine, verify all numeric/boolean parameters appear
- [ ] Verify hidden parameters (game_mode, ai_pattern, etc.) do NOT appear
- [ ] Modify rounds_to_win, verify game uses new value
- [ ] Modify ai_bias_strength, verify AI behavior affected
- [ ] Modify time_per_round, verify time pressure applied
- [ ] Test extreme values (rounds_to_win = 1 vs 21)
- [ ] Test cheat costs (verify token deduction)

Breakout:
- [ ] Open CheatEngine, verify all numeric/boolean parameters appear
- [ ] Verify hidden parameters (movement_type, brick_layout, powerup_types, etc.) do NOT appear
- [ ] Modify paddle_width, verify paddle size changes
- [ ] Modify ball_speed, verify ball velocity affected
- [ ] Modify ball_gravity, verify ball arcs
- [ ] Modify brick_rows/columns, verify brick layout changes
- [ ] Modify lives, verify game uses new value
- [ ] Test extreme values (paddle_width = 20 vs 200)
- [ ] Test cheat costs (verify token deduction)

All Games:
- [ ] Verify parameter ranges correct (no values outside min/max)
- [ ] Test with multiple cheats active (verify interactions)
- [ ] Test cheat_engine_base_cost and cheat_cost_exponent
- [ ] Verify difficulty_modifier scales parameters
```

---

## Phase 15: Variant Creation & Final Testing (All Games)

**Goal**: Create 10-15 variants per game with diverse parameter combinations, test all variants, ensure 50+ variants possible.

**This phase applies to ALL 3 GAMES.**

### Tasks

#### Coin Flip - Create Variants
- [ ] Create 10 variants in `coin_flip_variants.json`:
  - [ ] Classic (fair coin, streak 5, unlimited lives)
  - [ ] Marathon (fair coin, streak 10, unlimited lives)
  - [ ] Weighted Easy (65% heads bias, streak 5, show_bias_hint = true)
  - [ ] Speed Flip (streak 3, time_per_flip = 2 seconds)
  - [ ] Three Strikes (streak 1, total_correct = 10, lives = 3)
  - [ ] Alternating Pattern (pattern_mode = "alternating", streak 8, show_pattern_history = true)
  - [ ] Cluster Chaos (pattern_mode = "clusters", cluster_length = 4, streak 6)
  - [ ] Auto Flip (auto_flip_interval = 1.5, time_per_flip = 1.2, streak 5)
  - [ ] Ratio Challenge (victory_condition = "ratio", ratio_target = 0.7, ratio_flip_count = 30)
  - [ ] Hell Mode (streak 15, coin_bias = 0.45, lives = 1, time_per_flip = 3)
- [ ] Test each variant (launch, play, verify parameters applied)
- [ ] Verify variant diversity (each feels different)

#### RPS - Create Variants
- [ ] Create 10 variants in `rps_variants.json`:
  - [ ] Classic (RPS, random AI, best of 5)
  - [ ] Marathon (RPS, random AI, best of 21, show_player_history + show_ai_history)
  - [ ] Pattern Master (repeat_last AI, best of 5, show_ai_history + show_pattern_hint)
  - [ ] Counter Strike (counter_player AI, best of 5, show_player_history + show_pattern_hint)
  - [ ] Rock Biased (biased AI favoring rock 65%, best of 7, show_ai_pattern_hint)
  - [ ] RPSLS Classic (game_mode = "rpsls", random AI, best of 5)
  - [ ] Speed Blitz (RPS, random AI, best of 3, time_per_round = 2, animation_speed = 2)
  - [ ] Streak Master (victory_condition = "streak", streak_target = 5, random AI)
  - [ ] Three Lives (first_to = 10, lives_system_enabled, lives_count = 3, random AI)
  - [ ] Hell Mode (RPSLS, counter_player AI, ai_pattern_delay = 3, time_per_round = 3, lives = 2, rounds_to_win = 15)
- [ ] Test each variant (launch, play, verify parameters applied)
- [ ] Verify variant diversity (each feels different)

#### Breakout - Create Variants
- [ ] Create 15 variants in `breakout_variants.json`:
  - [ ] Classic (grid layout, 1 ball, 3 lives, paddle default movement)
  - [ ] Gravity Breaker (ball_gravity = 300, ball_speed = 350, paddle_width = 100, lives = 5)
  - [ ] Multi-Ball Madness (ball_count = 5, ball_speed = 250, paddle_width = 120, lives = 3)
  - [ ] Laser Assault (paddle_can_shoot = true, paddle_shoot_cooldown = 0.3, brick_health = 3, lives = 5)
  - [ ] Falling Sky (brick_fall_enabled, brick_fall_speed = 15, victory_condition = "time", victory_limit = 60)
  - [ ] Tiny Paddle (paddle_width = 40, paddle_speed = 350, lives = 5, powerup_types = ["paddle_extend"])
  - [ ] Sticky Strategy (paddle_sticky = true, brick_layout = "pyramid", lives = 3)
  - [ ] Fog Breaker (fog_of_war_enabled, fog_of_war_radius = 150, ball_trail_length = 20, lives = 5)
  - [ ] Endless Regeneration (brick_regeneration_enabled, brick_regeneration_time = 15, victory_condition = "score", victory_limit = 10000)
  - [ ] Homing Ball (ball_homing = 0.7, ball_speed = 320, brick_health = 2, lives = 3)
  - [ ] Rail Paddle (movement_type = "rail", paddle_speed = 500, ball_speed = 300, lives = 3)
  - [ ] Asteroids Paddle (movement_type = "asteroids", rotation_speed = 5, paddle_friction = 0.95, lives = 5)
  - [ ] Jump Paddle (movement_type = "jump", jump_distance = 80, jump_cooldown = 0.5, lives = 4)
  - [ ] Power-Up Heaven (powerup_types = ["multi_ball", "paddle_extend", "laser", "slow_motion", "extra_life", "fireball"], powerup_duration = 15, brick_powerup_drop_chance = 0.3)
  - [ ] Kitchen Sink (ball_count = 3, ball_gravity = 200, paddle_can_shoot, brick_fall_enabled, brick_regeneration_enabled, obstacles_count = 5, lives = 5, fog_of_war_enabled, victory_condition = "score", victory_limit = 20000)
- [ ] Test each variant (launch, play, verify parameters applied)
- [ ] Verify variant diversity (each feels different)

#### Final Testing - All Variants
- [ ] Launch each variant from launcher
- [ ] Play for 1-2 minutes to verify mechanics work
- [ ] Verify variant name, flavor_text display correctly
- [ ] Test demo recording/playback for each variant
- [ ] Test CheatEngine modifications for each variant
- [ ] Verify all 35+ variants work (10 Coin Flip + 10 RPS + 15 Breakout)

#### Performance Testing
- [ ] Test with many bricks (Breakout: 20 rows × 30 columns = 600 bricks)
- [ ] Test with many balls (Breakout: 20 balls simultaneously)
- [ ] Test with many particles (brick destructions with effects)
- [ ] Verify 60 FPS maintained in worst case scenarios
- [ ] Profile if needed (love.graphics.getStats(), love.timer.getFPS())

#### Regression Testing
- [ ] Test all 3 games with default parameters (no variant)
- [ ] Test all 3 games with CheatEngine modifications
- [ ] Test all 3 games with demo recording/playback
- [ ] Test all 3 games with VM assignment (assign demos to VMs)
- [ ] Verify no crashes, no game-breaking bugs
- [ ] Verify metrics tracking correct for all games
- [ ] Verify formula evaluation correct for all games
- [ ] Verify token generation correct for all games

### [ ] Status: Not Started

### Implementation Notes
```
Add notes here:
- Any variants that exposed bugs?
- Performance bottlenecks discovered?
- Variant parameter combinations that don't work well together?
```

### Testing & Validation
```
Testing checklist:
Coin Flip Variants:
- [ ] Test all 10 variants (launch, play, verify parameters)
- [ ] Verify each variant feels unique
- [ ] Test demo recording/playback for each
- [ ] Test CheatEngine for each

RPS Variants:
- [ ] Test all 10 variants (launch, play, verify parameters)
- [ ] Verify each variant feels unique
- [ ] Test demo recording/playback for each
- [ ] Test CheatEngine for each

Breakout Variants:
- [ ] Test all 15 variants (launch, play, verify parameters)
- [ ] Verify each variant feels unique
- [ ] Test demo recording/playback for each
- [ ] Test CheatEngine for each

Performance:
- [ ] Test worst case: 600 bricks + 20 balls + particles
- [ ] Verify 60 FPS maintained
- [ ] Profile if performance issues found

Regression:
- [ ] Re-test core mechanics for all 3 games
- [ ] Re-test demo recording/playback
- [ ] Re-test VM assignment
- [ ] Re-test CheatEngine
- [ ] Verify no crashes or game-breaking bugs
- [ ] Verify metrics, formulas, token generation correct

Final Sign-Off:
- [ ] All 35+ variants playable and unique
- [ ] All 3 games fully functional
- [ ] Demo recording/playback works for all games
- [ ] VM compatibility confirmed for all games
- [ ] CheatEngine integration complete for all games
- [ ] No critical bugs or crashes
- [ ] Ready for production!
```

---

## Appendix: File Structure

```
src/
  games/
    breakout.lua                  # Breakout game model (1,800-2,500 lines)
    coin_flip.lua                 # Coin Flip game model (600-900 lines)
    rps.lua                       # RPS Tournament game model (1,000-1,500 lines)
    views/
      breakout_view.lua           # Breakout rendering (400-600 lines)
      coin_flip_view.lua          # Coin Flip rendering (200-300 lines)
      rps_view.lua                # RPS rendering (300-400 lines)

assets/
  data/
    base_game_definitions.json    # Add 3 new game entries
    programs.json                 # Add 3 new program entries
    variants/
      breakout_variants.json      # 15+ variants
      coin_flip_variants.json     # 10+ variants
      rps_variants.json           # 10+ variants

  sprites/
    games/
      breakout/                   # Paddle, ball, brick sprites
      coin_flip/                  # Coin sprites
      rps/                        # Hand/icon sprites

src/
  config.lua                      # Add 3 game configs, CheatEngine ranges
```

---

## Appendix: Estimated Timeline

### Parallel Approach (All 3 Games Simultaneously)
- Phase 0: Foundation (1-2 days)
- Phase 1: Coin Flip Core (1-2 days)
- Phase 2: RPS Core (1-2 days)
- Phase 3: Breakout Core (2-3 days)
- Phase 4: Variant Parameters (1-2 days)
- Phase 5: Coin Flip Advanced (1-2 days)
- Phase 6: RPS Advanced (2-3 days)
- Phase 7: Breakout Advanced Part 1 (2-3 days)
- Phase 8: Breakout Advanced Part 2 (2-3 days)
- Phase 9: Breakout Special Features (1-2 days)
- Phase 10: Victory & Scoring (1-2 days)
- Phase 11: Visual Effects (2-3 days)
- Phase 12: Formula Integration (1 day)
- Phase 13: Demo Recording (2-3 days)
- Phase 14: CheatEngine (1-2 days)
- Phase 15: Variant Creation & Testing (3-4 days)

**Total: 15-25 days**

### Sequential Approach (One Game at a Time)
- Coin Flip (Phases 0,1,4,5,10,11,12,13,14,15): 5-7 days
- RPS (Phases 2,4,6,10,11,12,13,14,15): 7-10 days
- Breakout (Phases 3,4,7,8,9,10,11,12,13,14,15): 10-15 days

**Total: 22-32 days**

---

## End of Implementation Plan

**Remember**:
- Mark phases complete as you finish them
- Document testing results
- Add implementation notes (gotchas, decisions, workarounds)
- Follow viewport coordinate safety rules
- Test with demo recording/playback at every phase
- Test with different seeds to ensure variety
- Profile performance if issues arise
- Ask for help if stuck!

Good luck implementing the new games! 🎮
