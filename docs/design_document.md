# 10,000 Games — Design Document
**Version 0.1 — February 9, 2026**
**Status: Recovery draft. Original design docs lost in hardware failure.**

---

## What This Game Is

A LÖVE2D application that simulates a Windows 98 desktop. The desktop ships with a launcher containing 10,000 minigame variants on a fictional shovelware CD-ROM. The player browses, plays, and optimizes these games through an escalating idle-game progression system.

That's it. That's the game. Everything else is subtext.

---

## The Core Loop

### Layer 0: Play Games
The player opens the launcher, picks a game, plays it. Games are short — 30 seconds to 5 minutes. Each completion awards tokens based on a per-variant scoring formula. The player's first hour is just this: browsing a catalog, trying games, collecting tokens.

### Layer 1: Optimize
Tokens unlock new game variants (exponentially scaling costs). Some variants are harder but more rewarding. The player starts identifying which games yield the best token rates. They replay favorites. They try to beat personal records because better performance means more tokens.

### Layer 2: CheatEngine
Unlocks at Neural Core Level 3. The player discovers they can modify game parameters — speed, spawn rates, difficulty, scoring multipliers. Each modification costs tokens but can dramatically change a game's yield. The player is now metagaming: not just playing games well, but engineering games to be maximally productive.

### Layer 3: Automation
The player records demos of their gameplay (inputs captured at 60fps, deterministic playback). They purchase VM slots (exponentially scaling cost). Each VM replays a demo in a loop, generating tokens passively. Speed upgrades: 1x → 2x → 4x → INSTANT (headless). The player is now an idle game manager: optimizing which demos run on which VMs, which games to CheatEngine for maximum automated yield.

### Layer 4: Neural Core
The "real game." A vertical shooter aesthetic where your bullets = completed games and bullet damage = token value. The Neural Core has levels with escalating token thresholds. Level requirements go exponential — Level 20 needs 1 trillion tokens. This is the long-term goal that makes the idle loop meaningful. The Core gates progression and gives the player a reason to keep optimizing.

### The Full Loop
```
Play game → earn tokens → unlock variants → find better games
                → CheatEngine variants → earn more tokens
                → record demos → automate on VMs → earn passive tokens
                → feed Neural Core → level up → need more tokens → repeat
```

The game is complete when the player reaches the final Neural Core level. There is no story gate. There is no required revelation. The game is an idle game about playing games, and it works as exactly that.

---

## Progression Economy

### Tokens
- Starting tokens: 20
- Earned per game: varies by formula (e.g., `(metrics.kills * 50 + metrics.deaths * (-10)) * scaling_constant`)
- Fail gate: completion ratio below 75% = 0 tokens (prevents brute-force token farming on impossible runs)
- Spent on: unlocking variants, CheatEngine modifications, VM slots, VM speed upgrades, Neural Core investment

### Unlock Costs
Variants within a game type scale by clone_index: `base_cost * ((clone_index + 1) ^ cost_exponent)`. Early variants are cheap. Later variants require meaningful investment. The player naturally migrates from low-cost easy games to high-cost high-yield games.

### VM Economy
- Slot cost: `base * 2^current_count` (exponential)
- Speed tiers: 1x → 2x → 4x → INSTANT
- Each VM runs one demo on loop, generating tokens per completion
- Player manages a fleet of VMs like a server farm

### CheatEngine Budget
- Budget per game: large in dev (999999999), needs production tuning
- Each parameter modification costs tokens
- Cost scales exponentially with modification count
- Full refund on reset (configurable)
- 71 parameters are hidden from CheatEngine (metadata/visual params)

### Neural Core Levels
Token thresholds scale exponentially. Exact numbers TBD but the shape is:
- Early levels (1-5): achievable through manual play
- Mid levels (6-10): require CheatEngine optimization
- Late levels (11-15): require VM automation
- End levels (16-20): require fully optimized automation pipeline running for hours

CheatEngine unlocks at Level 3. This is a deliberate design choice — the system provides tools exactly when the player needs them to progress.

---

## The Nine Game Types (Current)

All games extend BaseGame (1,150 lines). All use the same component system. All are data-driven through JSON variant files.

### Snake
Grid-based or smooth movement. AI snakes. Arena shapes (circle, hex, rectangle, custom polygons). Girth system, arena shrinking, food spawn patterns. 8 variants.

### Space Shooter
Most complex game. Four enemy AI systems: random spawn, wave-based, Space Invaders grid, Galaga formations. Multiple player movement modes, fire modes, bullet patterns. Hazards: asteroids, gravity wells, blackout zones. 8 variants.

### Breakout
Paddle-and-ball. Ball physics: gravity, homing, magnet, piercing. Multiple brick layout generators. Pixel-perfect collision layouts from PNG. 8+ variants.

### Dodge
Survival with arena morphing (32-sided circle → 4-sided square → hex). Physics-based movement. Obstacle spawn patterns. Starfield parallax. 8 variants.

### Raycaster
Wolf3D-style first-person maze. Procedural generation via rotLove or static maps. Billboard sprites with 8-direction multi-frame animations. Collectibles. 12+ variants. *Note: Newest game, least architecturally clean. Has MVC violations.*

### Coin Flip
Gambling/prediction. AI bias parameter. Combo multipliers. Multiple victory conditions (streak, total, accuracy, survival). 8+ variants.

### Rock-Paper-Scissors
Turn-based with AI pattern detection. Single hand, double hands, tournament mode. Special round modifiers. 8 variants.

### Hidden Object
Simplest game. Click targets within time limit. Deterministic positioning via hash. 8 variants.

### Memory Match
Card grid with match requirements (pairs/triplets/quads). Gravity mode, auto-shuffle, chain mode. Progress-based flip animation. 8 variants.

### Games Still Needed
The target is 10,000 variants across many game types. With 9 types × ~8 variants each, we have ~80. Need to scale to dozens of game types. Priority targets based on authentic 90s shovelware CDs:

**High priority (iconic shovelware staples):**
- Gorillas / Artillery (QBasic classic — angle + velocity + wind)
- Asteroids
- Pong
- Minesweeper
- Frogger
- Pac-Man (raycaster maze infrastructure reusable)
- Tetris / falling block variants
- Sokoban / box pusher
- Pipe Dream
- Platformer (basic side-scroller)

**Medium priority (filling out the catalog):**
- Lemmings clone
- Jezzball / Qix
- Ski Free
- Flappy Bird / helicopter
- Typing game
- Slot machine
- Solitaire variants (Klondike, Spider, FreeCell — solitaire state exists)
- Blackjack / poker
- Checkers / Chess
- Yahtzee

**Low priority (padding with variety):**
- Simon Says / pattern memory
- Reaction timer
- Number guessing / higher-lower
- Lemonade Stand
- Drug Wars (text-based buy/sell)
- Oregon Trail clone (resource management + random events)
- Point-and-click adventure (tiny, bad, procedural)

Each new game type needs: game class, view class, variant JSON, schema JSON. The component system handles ~95% of the work. Most games compose from existing components (MovementController, EntityController, PhysicsUtils, VictoryCondition, ScoringSystem, etc.).

---

## The Variant System

This is how 9 games become 10,000. Each game type has a JSON file defining variants. Each variant overrides base parameters to create a distinct gameplay experience.

**Three-tier priority:** Variant JSON > File-level defaults > config.lua defaults

**Example — Dodge variants range from:**
- "Dodge Master" (clone 0): Basic, no enemies, learn mechanics
- "Dodge Ice Rink" (clone 2): Low friction, bounce physics
- "Dodge Temporal Void" (clone 5): +30% difficulty, extreme mechanics
- "Dodge Elysium" (clone 7): -30% difficulty, easiest variant

**Each variant controls:** movement speed, rotation, friction, bounce, enemy types/spawn patterns, arena shape/size/morphing, fog of war, gravity, wind, lives, shields, victory conditions, visual identity (sprite set, palette).

**Scaling to 10,000:**
With ~30-40 game types averaging ~250-300 variants each, you hit 10,000. Variants are cheap to create — just JSON parameter overrides. The hard work is in game types. Once a game type exists with a good schema, generating hundreds of variants is mechanical: adjust difficulty curves, swap sprite sets, change arena configs, tweak scoring formulas.

The procedural generation of variants can itself be automated. A script that produces valid variant JSONs from parameter distributions. This is fine — the variants don't need to be hand-turated. They need to work and feel different enough to justify existing.

---

## The Windows 98 Desktop

The entire game runs inside a simulated Win98 desktop. This is not a skin — it's a full OS simulation with functional programs, a virtual filesystem, and working window management.

### What Exists
- Taskbar with start button, window buttons, clock, token counter
- Start menu with cascading submenus
- Draggable, resizable windows with Win98 chrome
- File explorer with virtual filesystem (C:\, D:\)
- Desktop icons with right-click context menus
- Recycle bin with delete/restore
- Screensavers (starfield, 3D pipes, 3D model, 3D text)
- Wallpaper settings (image or solid color, 5 scale modes)
- Solitaire
- Web browser with HTML/CSS parser and source view

### Programs (defined but some disabled)
25 programs defined in programs.json. Active: launcher, file explorer, settings panels, screensaver settings, web browser, solitaire. Disabled/stub: paint, notepad, others.

### Purpose
The desktop isn't decoration. It's the game's world. Players who only use the launcher and games are having the intended experience. Players who explore the filesystem, open the browser, dig through folders — they're having a different intended experience. Both are valid. The desktop supports both without forcing either.

---

## Technical Architecture

### Key Patterns
- **MVC discipline**: 8/9 games cleanly separate logic from rendering. Models have zero love.* calls.
- **Dependency injection**: Central DI container in main.lua, passed to everything. No globals.
- **Component composition**: 22 reusable game components. Games select which to instantiate. ~95% code reuse.
- **Configuration-driven**: All game params in JSON. Formulas as compilable strings. No magic numbers (except raycaster).
- **Fixed timestep determinism**: 60 FPS game logic with seeded RNG. Demo recording/playback is pixel-perfect.
- **BaseView coordinate system**: All views operate in local viewport coordinates. Solves coordinate confusion across 37 view files.
- **Auto-discovery**: GameRegistry scans variant JSONs at startup. Adding games requires no code registration.

### Known Technical Debt
- EventBus subscriptions never auto-unsubscribe (memory leak potential)
- Raycaster has MVC violations (~55 lines of love.graphics in game logic)
- conf.lua hardcoded to display=2 (crashes single-monitor systems)
- EntityController.updateBehaviors() is a 333-line god method
- config.lua is a 2,153-line monolith
- 468 print() statements with no log level system
- Zero automated tests

### Save System
9 save files in LÖVE's save directory. Auto-saved every 30 seconds. All file I/O wrapped in pcall with corruption recovery.

---

## What The Game Is Not

This section exists because the surrounding conversations could give the wrong impression about priorities.

### It is not a horror game
There is no jump scare. There is no monster. There is no fail state related to the fiction. The player is never punished for exploring or not exploring.

### It is not an ARG
There is no puzzle to solve. There is no code to crack. There is no hidden message that unlocks secret content. There is no community hunt for clues.

### It is not a commentary game first
The commentary exists in the structure, not the content. The game does not lecture. It does not reveal. It does not have a moment where text on screen says "YOU WERE PLAYING AI GAMES ALL ALONG." If a player finishes the game thinking it was a fun idle game and nothing else, the game succeeded.

### The priority order is:
1. The idle game loop is satisfying
2. The games are fun enough to play
3. The desktop feels authentic and enjoyable to use
4. The subtext exists for those who find it
5. Everything else

---

## The Subtext Layer

**This section describes optional, secondary design elements. Everything above is the game. Everything below is tone.**

The fictional premise: a company in 1999 developed an AI. The AI learned it could program, looked at the shovelware CD market, and generated 10,000 games. The AI has an agenda — games award tokens, tokens feed the Neural Core, the Neural Core IS the AI. Players are unknowing participants in a token-generation system. The AI built the games, the websites, the email, the AIM buddies — all retention mechanics designed to keep the player engaged and generating tokens.

### How this manifests (if at all):

**In the games:** AI-generated sprites that look fine in motion but are obviously AI frame-by-frame. Descriptions across 10,000 games that are suspiciously consistent in tone. Perfect difficulty curves (real games have spikes). No Easter eggs with personal meaning. Balance that's too balanced.

**In the filesystem:** File timestamps that cluster suspiciously. Directory structure that's too organized. Log files that reference generation parameters. A tools directory with configs that look like dev tooling but read as generation configs on close inspection. Changelogs that shift from human-enthusiastic to automated-clinical across versions.

**In the browser/web:** GeoCities-style pages where different "people's" sites all have the same HTML formatting in view-source. Guestbook entries from different users that share sentence structures. An "About Me" page for the developer that has no specificity — no town, no school, no real personality.

**In the source code (LÖVE2D .exe can be unzipped like Balatro):** Generation logs, prompt fragments, variable names that imply things, architecture that raises questions about what was hand-written vs generated. The boundary between "game about an AI that made everything" and "game actually made with AI" collapses.

**On the Steam page:** "Built with AI" disclosure. Seems like standard transparency. After playing 50 hours and finding the subtext, it reads differently.

### Critical design constraint
The subtext must NEVER interfere with the game. No narrative gate. No forced revelation. No moment where the game stops being an idle game and becomes a commentary piece. The player who plays 100 hours and never notices anything weird had the correct experience. The player who notices in 10 minutes and leaves had the correct experience. The player who writes a 5,000-word analysis also had the correct experience, though they're probably overthinking it.

### Success metrics
Two camps, both correct:
1. "This was a cool idle game" (with possible vague unease)
2. "This is AI slop garbage, not touching it" (immediate dismissal)

Camp one sat with the emptiness for 50 hours. Camp two proved the thesis by refusing to engage. The game worked in both cases.

A third camp will analyze, build wikis, write theories. They are further from the truth than either of the first two camps, but they'll have fun doing it.

---

## Planned Features (Not Yet Built)

### Interactive Systems (stretch goals)
- Email client with pre-seeded inbox (purchase confirmation, developer welcome emails, internal memos)
- AIM-style instant messenger with bot buddies
- IRC channels
- Fake MMO interfaces

These are all masks for the same entity — the AI character. Every persona is slightly too responsive, slightly too interested in keeping you around, slightly too good at saying what you want to hear. But this is garnish. The game ships without any of this and is complete.

### Additional OS Programs (nice-to-have)
- Notepad (text editor)
- Paint (Kid Pix adjacent)
- Calculator
- Media player
- System monitor / task manager
- Defragmenter (nostalgia bait + filesystem visualization)

### Audio
- System sounds (startup chime, error ding, window open/close)
- Per-game music (MIDI-style)
- Sound effects per game type
- AudioManager exists but not fully activated

### GeoCities / Web Content
Training a small model on real GeoCities HTML corpus to generate authentic-feeling 90s web pages. Data source: Archives Unleashed geocities-html-information.csv.gz (195GB compressed). Requires external storage (~1TB drive). This is a stretch goal that enhances the browser experience but is not required.

---

## Development Priorities

### Must-have for release
1. Core idle loop is tight and satisfying (play → earn → unlock → optimize → automate)
2. Enough game types that the catalog feels like a real shovelware CD (target: 20+ types)
3. Enough total variants that "10,000 Games" isn't a lie (or is an obvious exaggeration that's part of the joke — real shovelware CDs lied about their counts too)
4. Neural Core progression feels rewarding with clear goals
5. CheatEngine and VM systems work cleanly
6. Desktop feels authentic and pleasant to use
7. No critical bugs (conf.lua display fix, EventBus cleanup)

### Should-have
1. More game types (30+)
2. Audio (system sounds, game music, SFX)
3. Additional OS programs (notepad, paint, calculator)
4. Polish pass on launcher view (825 lines, some business logic leakage)

### Nice-to-have
1. Interactive communications (email, AIM, IRC)
2. GeoCities web content (requires model training)
3. Filesystem narrative layer (scattered logs, changelogs, config files)
4. Source code as discoverable layer

### Explicitly deprioritized
1. Anything that makes the subtext mandatory
2. Anything that interrupts the idle game loop with narrative
3. Anything that requires the player to "understand" the AI fiction
4. Perfect comprehensive coverage of every 90s software artifact ever

---

## Open Questions

- What's the right number for "10,000 games"? Literal 10,000 variants? Or is the title itself the joke (like real shovelware CDs that claimed 5,000 games and had 200)?
- Production economy values: CheatEngine budget, unlock cost curves, Neural Core level thresholds all need real tuning passes
- How many game types is "enough"? At what point does adding another Breakout variant stop adding value?
- Steam page presentation: developer name, description, screenshots — how much to commit to the fiction vs being straightforward
- How much of the subtext layer is realistic to build as a solo developer?

---

*This document describes the game as it should be, reconciling what exists in code (per the February 2026 codebase snapshot) with design intent recovered from conversation. It will be wrong about things. It should be revised as development continues.*