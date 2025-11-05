# New Game Variable Ideas - Breakout, Coin Flip, RPS

This document contains brainstormed variable ideas for creating diverse variants for the three new game types.

---

## Breakout/Arkanoid Variables

### Paddle Mechanics
- `movement_type` - "default" (WASD), "rail" (rapid side-to-side), "asteroids" (rotate + thrust), "jump" (teleport dash)
- `paddle_width` - Paddle size (small = hard, large = easy)
- `paddle_speed` - Movement speed
- `paddle_friction` - Stop instantly vs drift (ice physics)
- `paddle_sticky` - Ball sticks to paddle, release with spacebar (aim shots)
- `paddle_magnet_range` - Ball auto-attracts to paddle within radius
- `paddle_can_shoot` - Paddle fires laser bullets upward
- `paddle_shoot_cooldown` - Time between shots
- `paddle_shoot_damage` - How many hits paddle bullets deal

### Ball Physics
- `ball_count` - Multiple balls simultaneously (1 = classic, 5 = chaos)
- `ball_speed` - Velocity
- `ball_speed_increase_per_bounce` - Accelerates over time vs constant speed
- `ball_max_speed` - Speed cap
- `ball_size` - Radius (smaller = harder to see)
- `ball_gravity` - Downward pull (arc physics)
- `ball_gravity_direction` - Gravity direction (down/up/left/right)
- `ball_bounce_randomness` - Perfect physics vs chaotic bounces
- `ball_trail_length` - Visual comet trail
- `ball_spin_enabled` - Spin affects bounce angles
- `ball_phase_through_bricks` - Pierce through X bricks before bouncing
- `ball_homing` - Curves toward nearest brick
- `ball_respawn_on_miss` - Ball respawns instead of losing life (score-focused mode)
- `ball_spawn_angle_variance` - Random vs consistent spawn angle

### Brick System
- `brick_layout` - "grid", "pyramid", "circle", "random", "maze", "checkerboard"
- `brick_rows` - Number of rows
- `brick_columns` - Number of columns
- `brick_health` - Hits to destroy (1 = standard, 5 = armored)
- `brick_health_variance` - Random health variation per brick
- `brick_regeneration_enabled` - Destroyed bricks respawn over time
- `brick_regeneration_time` - Seconds before respawn
- `brick_fall_enabled` - Bricks slowly fall toward paddle (Tetris hybrid)
- `brick_fall_speed` - Fall rate
- `brick_movement_enabled` - Bricks drift horizontally
- `brick_movement_speed` - Drift speed
- `brick_size_variance` - Mix of small/large bricks
- `brick_score_multiplier` - Point value scaling
- `brick_powerup_drop_chance` - Probability of dropping power-up

### Arena & Boundaries
- `arena_width` - Play area width
- `arena_height` - Play area height
- `wall_bounce_mode` - "normal", "damped" (energy loss), "sticky" (brief stick), "wrap" (screen wrap)
- `ceiling_enabled` - If false, ball can escape upward (don't let it escape mode)
- `bottom_kill_enabled` - If false, ball bounces off bottom (easy mode)
- `obstacles_count` - Static hazards in play area
- `obstacles_shape` - "rectangle", "circle", "triangle"
- `obstacles_destructible` - Can be destroyed by ball

### Power-Ups
- `powerup_enabled` - Master toggle
- `powerup_types` - Array: "multi_ball", "paddle_extend", "paddle_shrink", "slow_motion", "fast_ball", "laser", "sticky_paddle", "extra_life", "shield", "penetrating_ball", "fireball", "magnet"
- `powerup_duration` - How long temporary effects last
- `powerup_fall_speed` - Drop speed
- `powerup_spawn_mode` - "drop" (from brick), "spawn_top" (random), "spawn_paddle" (instant)

### Victory Conditions
- `victory_condition` - "clear_bricks" (destroy all), "destroy_count" (destroy X), "score" (reach X points), "time" (survive X seconds), "survival" (endless)
- `victory_limit` - Target value for condition
- `perfect_clear_bonus` - Bonus for clearing without missing

### Lives & Difficulty
- `lives` - Starting lives
- `extra_ball_score_threshold` - Score needed for extra life
- `ball_speed_cap_enabled` - Prevent impossible speeds
- `difficulty_scaling_enabled` - Ball speed increases over time
- `difficulty_scaling_rate` - Increase per minute

### Visual Effects
- `fog_of_war_enabled` - Limited visibility
- `fog_of_war_radius` - Visibility range
- `camera_shake_enabled` - Screen shake on brick break
- `camera_shake_intensity` - Shake strength
- `particle_effects_enabled` - Brick explosion particles
- `brick_flash_on_hit` - Visual feedback
- `score_popup_enabled` - Floating score numbers

---

## Coin Flip Streak Variables

### Core Mechanics
- `streak_target` - Consecutive correct guesses to win
- `coin_bias` - Probability of heads (0.5 = fair, 0.6 = 60% heads, 0.3 = 30% heads)
- `lives` - Failed guesses allowed (999 = unlimited, 3 = three strikes)
- `show_bias_hint` - Display bias percentage to player
- `auto_reveal_bias` - After X flips, show calculated actual bias
- `auto_reveal_flip_count` - Flips before auto-reveal

### Timing & Speed
- `time_per_flip` - Seconds to guess (0 = unlimited)
- `auto_flip_interval` - Automatic flips every X seconds (0 = manual)
- `flip_animation_speed` - Duration of flip animation

### Pattern & Strategy
- `show_pattern_history` - Display last N results (HTHHT)
- `pattern_history_length` - Results shown in history
- `pattern_mode` - "random", "alternating" (HTHTH), "clusters" (HHHTTTHHH), "biased_random"
- `cluster_length` - Average run length for cluster mode
- `allow_guess_change` - Can change guess before flip completes

### Victory & Scoring
- `victory_condition` - "streak" (X consecutive), "total" (X total correct), "ratio" (X% accuracy over Y flips), "time" (best streak in X seconds)
- `total_correct_target` - Target for total victory
- `ratio_target` - Minimum accuracy required
- `ratio_flip_count` - Flips to evaluate ratio over
- `time_limit` - Time limit in seconds
- `score_per_correct` - Points per correct guess
- `streak_multiplier` - Score multiplier that grows with streak
- `perfect_streak_bonus` - Bonus for reaching target without mistakes

### Visual & Audio
- `coin_sprite` - Which coin visual to use
- `flip_sound_enabled` - Audio toggle
- `result_announce_mode` - "text", "voice", "both", "none"
- `celebration_on_streak` - Visual effects on milestones
- `streak_milestone` - Correct guesses between celebrations

---

## RPS Tournament Variables

### Core Mechanics
- `game_mode` - "rps" (Rock/Paper/Scissors), "rpsls" (+ Lizard/Spock), "rpsfb" (+ Fire/Water)
- `rounds_to_win` - Rounds to win (best of X)
- `total_rounds_limit` - Hard cap on total rounds (prevent infinite ties)
- `hands_mode` - "single" (classic one hand), "double" (both hands, then remove one - Squid Game style)
- `opponent_count` - Number of AI opponents (1 = classic, 3 = battle royale, 5 = chaos)
- `multi_opponent_elimination` - "single_winner" (last one standing), "points" (highest score wins), "survival" (avoid last place)

### AI Behavior
- `ai_pattern` - "random", "repeat_last", "counter_player", "biased", "pattern_cycle", "mimic_player", "anti_player"
- `ai_bias` - Which option AI favors: "none", "rock", "paper", "scissors", "lizard", "spock", "fire", "water"
- `ai_bias_strength` - How strongly AI favors biased option (0.4 = weak, 0.8 = strong)
- `ai_pattern_delay` - Rounds before AI pattern activates (prevents early exploitation)
- `show_ai_pattern_hint` - UI displays AI behavior hints

### Timing & Speed
- `time_per_round` - Seconds to make choice (0 = unlimited)
- `time_per_removal` - Seconds to choose which hand to remove (double hands mode only)
- `auto_timeout_choice` - What happens on timeout: "random", "rock", "lose"
- `round_result_display_time` - Seconds to show result before next round
- `animation_speed` - Throw animation speed multiplier
- `simultaneous_reveal` - Both hands revealed at once vs sequential (double hands mode)

### Strategy & Display
- `show_player_history` - Display player's last N choices
- `show_ai_history` - Display AI's last N choices
- `history_length` - Rounds shown in history
- `allow_choice_change` - Can change choice after selecting
- `show_statistics` - Display win/loss/tie percentages
- `show_pattern_hint` - Game analyzes and hints at patterns
- `show_both_hands_history` - Show what both hands were before removal (double hands mode)
- `show_opponent_elimination_order` - Display who got eliminated when (multi-opponent mode)
- `camera_focus_mode` - "all" (show all opponents), "1v1" (cycle through matchups), "player_only" (just your matchup)

### Victory & Scoring
- `victory_condition` - "rounds" (best of X), "first_to" (first to X wins), "streak" (X consecutive wins), "total" (X total wins), "time" (most wins in X seconds)
- `first_to_target` - Target for first_to mode
- `streak_target` - Consecutive wins needed
- `total_wins_target` - Total wins needed
- `time_limit` - Time limit for time mode
- `score_per_round_win` - Points per round won
- `streak_bonus` - Bonus for consecutive wins
- `perfect_game_bonus` - Bonus for winning without losing any rounds

### Variants & Twists
- `double_or_nothing_rounds` - Special rounds with doubled stakes
- `reverse_mode` - Losing throw wins (mind-bending)
- `mirror_mode` - Ties count as wins for player
- `sudden_death_enabled` - After round limit, next round winner takes all
- `lives_system_enabled` - Player has X lives, losing costs 1 life
- `lives_count` - Starting lives

### Visual & Audio
- `throw_animation_style` - "hands", "icons", "text", "emojis"
- `result_announce_mode` - "text", "voice", "both", "none"
- `celebration_mode` - "none", "subtle", "moderate", "extreme"
- `color_scheme` - "classic", "neon", "retro", "minimal"

---

## Cross-Game Concepts

Ideas that could work across multiple games:
- **Time Attack Mode** - Complete in X seconds
- **Survival Mode** - How long can you last?
- **Perfect Run** - One mistake = game over
- **Zen Mode** - No failure, just score chasing
- **Speed Bonus** - Faster = more points
- **Combo System** - Chain successes for multipliers
- **Progressive Difficulty** - Gets harder over time
- **Lives System** - Multiple chances before game over
- **Power-Up Integration** - Pickups that help
- **Fog of War** - Limited visibility
- **Time Limit** - Race against clock
- **Score Target** - Reach X points to win

---

## VM Demo Compatibility Notes

**Breakout**: EXCELLENT
- Paddle movement transfers well across seeds
- Ball physics deterministic per seed
- CheatEngine can make it very VM-friendly (bigger paddle, slower ball)

**Coin Flip**: PERFECT
- Demo records consistent guess pattern
- 50% base win rate with fair coin, higher with bias
- Seed changes results but not player choice
- Ideal "set and forget" VM game

**RPS**: EXCELLENT
- Demo records repeated choice pattern
- 33% base win rate (RPS), 20% base win rate (RPSLS)
- Law of large numbers = consistent wins with enough rounds
- AI patterns can be exploited

---

## Implementation Priority

**Must-Have (MVP)**:
- Breakout: Basic paddle/ball/brick mechanics, simple power-ups
- Coin Flip: Basic streak mechanics, bias system
- RPS: Basic round system, AI patterns

**High Priority** (Big variety, easy wins):
- Breakout: Power-ups, victory conditions, ball gravity
- Coin Flip: Pattern modes, victory conditions
- RPS: AI behaviors, extended game modes (RPSLS)

**Medium Priority** (Unique but more complex):
- Breakout: Falling bricks, regenerating bricks, obstacles
- Coin Flip: Auto-flip mode, pattern hints
- RPS: Lives system, special rounds

**Low Priority** (Polish & edge cases):
- Visual effects (fog of war, camera shake, particles)
- Advanced AI for RPS
- Complex brick layouts for Breakout
