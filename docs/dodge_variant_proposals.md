# Dodge Variant Proposals v2

**48 variants. Not 48 reskins.**

These REPLACE the existing test variants (clones 0-63). Clone indices 0-47.

Not every game on a shovelware CD is good. These are tagged:
- **[GEM]** — Genuinely different game. A player who finds this one tells their friends.
- **[GOOD]** — Interesting twist on the formula. Worth replaying.
- **[FILLER]** — Functional, forgettable. The kind of game you play once and move on. That's fine. That's the CD.

---

## New Systems

These are the major additions that make variants feel like different games.

### New Player Actions
| System | What | Example |
|--------|------|---------|
| **Shoot** | Player fires projectiles. Destroy certain enemies or targets. | Circus: shoot balloons while dodging clowns |
| **Collect** | Touch items among hazards. Win = collect N. | Pond: grab 10 flies while dodging frogs |
| **Catch/Throw** | Press action key near a catchable entity, hold, aim, throw. | Recess: catch dodgeballs, throw at targets |
| **Shield** | Hold direction to block from that side. Can't move while shielding. | Siege: block arrows from one direction, dodge the rest |
| **Parry** | Tap at the exact moment of impact. Deflects enemy away. Tight timing. | Samurai filler variant |
| **Attract/Repel** | Hold key to pull or push nearby small entities. | Junkyard magnet |

### New Enemy Patterns
| Pattern | What | Example |
|---------|------|---------|
| **Formation walls** | Line of enemies with a gap. Find and reach the gap. Undertale bones. | MAW: teeth snap in columns, find the gap |
| **Expanding rings** | Ring of entities grows from center. One gap. Position yourself in the gap. | Colony: rings of cells expand |
| **Converging lines** | Two walls approach from opposite sides with offset gaps. Thread the needle. | Construction: walls of bricks from both sides |
| **Sweep beams** | A line rotates around a point like a lighthouse. Time your crossing. | Disco: spotlight sweeps |
| **Choreographed sequences** | 5-8 enemies spawn with timed paths. The dodge IS the choreography. Memorizable. | Ballet/dance variants |
| **Accelerating spirals** | Enemies spawn in a spiral pattern that tightens over time. | Blender: blade spiral |

### New Movement Modes
| Mode | What | Example |
|------|------|---------|
| **Falling mode** | Player at bottom, moves left/right only. Things fall from top. | Detention: dodge falling school supplies |
| **Gravity platformer** | Player has gravity + jump. Side-view. Jump over or duck under. | Sewer: jump over rats, duck pipes |
| **Auto-scroll** | Arena scrolls. Player dodges fixed obstacles. On rails. | Highway: weave through traffic |
| **Fixed-rotate** | Player stays at center. Can only rotate facing. Enemies approach from edges, you must face gap in each ring. | Dream: surreal rotating dodge |

### New Rules
| Rule | What | Example |
|------|------|---------|
| **Color rules** | Blue enemies hurt only when you MOVE. Orange hurt only when you're STILL. Must read each threat. | First Date: read the room |
| **Powerup drops** | Temporary abilities drop among hazards: speed boost, shield, shrink, slow-time, ammo. | Multiple variants |
| **Growing player** | Player hitbox grows each time you dodge something. Victory lap becomes impossible. | Ball Pit: you grow, gaps don't |
| **Safe platforms** | Small zones where you're invulnerable. Limited, sometimes moving. | Pond: lily pads |
| **Phase enemies** | Enemies flicker solid/ghost on a timer. Can't trust what you see. | Ghost Protocol |
| **Growing enemies** | Enemies expand over time. Arena fills up. | Fridge Horror: leftovers spreading |
| **Burst events** | Scripted massive spawn spikes (calm → APOCALYPSE → calm). | Gesundheit: THE SNEEZE |
| **Arena rotation** | Safe zone rotates. Gravity rotates with it. "Down" keeps moving. | Tumble Dry |
| **Leave-and-return** | Player can leave arena for 3 seconds to grab pickups outside. Timer shown. Overstay = death. | Farm: chicken runs outside fence |
| **Escort** | Something at center the player must protect. Enemies target IT, not you. Body-block. | Haunted House: protect the kid |

---

## The Variants

---

### #0 — ZAMBONI PANIC [GOOD]
**Ice rink. You're a skater. Zambonis and hockey players don't care about you.**
- **Sprite:** `ice_rink`
- **Hook:** Ice physics. Extreme low-friction asteroids movement. Every input is a commitment. The zamboni is a lunger that crosses the ENTIRE rink. Pucks are fast bouncers. Hockey players are drunk chasers.
- **Arena:** Square (rink). Large. Static.
- **Win:** Survive 45s.
- **Background prompt:** "Top-down view of an indoor ice hockey rink surface, blue-white ice with painted red and blue lines, scratched and scraped ice texture, harsh overhead fluorescent lighting, pixel art style, 16-bit retro game background. No text, no logos, no people, no watermarks, no scoreboard."

---

### #1 — MAW [GEM]
**Inside a dog's mouth. Teeth snap shut in columns. Find the gap.**
- **Sprite:** `dodge/teeth` + `dodge/slobber`
- **Hook:** **Formation walls.** Teeth are NOT random enemies — they snap from top/bottom in COLUMNS with warning indicators. 1-second warning shows which columns will snap. Player moves left/right to the safe column. Gets faster. More columns snap at once. Late game: only 1 safe column. Pure pattern reading, like Undertale's bone attacks.
- **Movement:** Left/right only (effectively 1D).
- **Arena:** Wide rectangle (mouth). Shrinking (mouth closing).
- **Win:** Survive 30s. Dog opens mouth.
- **Background prompt:** "Inside of a dog's mouth viewed from the front, wet pink gums, ridged palate, glistening saliva, dark throat in the center, fleshy pink and red tones, moist texture, gross and organic, pixel art style, 16-bit retro game background. No teeth, no tongue, no text, no watermarks."

---

### #2 — DETENTION [GEM]
**Classroom. Mr. Henderson left. Things are falling from the ceiling.**
- **Sprite:** `school`
- **Hook:** **Falling mode.** Player at bottom, moves LEFT/RIGHT ONLY. Things fall from the top of the screen. Paper airplanes drift slowly and zigzag. Pencils fall fast in single columns. Textbooks are 3 columns wide and you must GET OUT. Crumpled paper splits. Erasers bounce off the floor and come back up. Rulers fall sideways across the entire width with one gap. The fun is reading the fall patterns.
- **Movement:** Left/right only. Fast.
- **Win:** Survive 40s. Bell rings.
- **Background prompt:** "Top-down view of a school classroom floor, beige linoleum tiles with scuff marks, desk legs visible at edges, scattered chalk dust, dropped pencil shavings, fluorescent lighting, slightly dirty, pixel art style, 16-bit retro game background. No people, no text, no watermarks, no desks in center."
- **Alternate background:** "Scribbled pencil sketch on lined notebook paper, a classroom floor drawn from above by a bored student, messy graphite shading, eraser smudges, blue ruled lines visible underneath the drawing, doodle quality, ballpoint pen ink stains in corners. No people, no text, no watermarks, no desks in center."

---

### #3 — WILL IT BLEND? [GOOD]
**You're in a blender. Blades orbit the center. Everything spirals inward.**
- **Sprite:** `blender`
- **Hook:** **Accelerating spirals + orbit enemies.** 2-3 blades orbit the center at different radii. Fruit chunks spiral inward (area_gravity pulls toward center). You navigate between the blade orbits while the gravity drags you in. The spiral tightens over time (spawn angle decreases). Blender pulses on/off — gravity surges then drops to zero, creating a breathing rhythm.
- **Arena:** Circle. Pulsing morph (motor pulse). Strong gravity toward center.
- **Win:** Survive 35s.
- **Background prompt:** "Inside of a glass blender jar viewed from above, swirling pale pink and white smoothie liquid, translucent, blurred fruit pulp streaks, circular glass walls catching light, wet and glossy, pixel art style, 16-bit retro game background. No blades, no fruit chunks, no text, no watermarks, no lid."

---

### #4 — NASAL PASSAGE [GOOD]
**Dust mite in a nostril. The breathing cycle IS the game.**
- **Sprite:** `nostril`
- **Hook:** **Breathing wind.** Wind oscillates: inhale (pull inward, 3s), pause (1s), exhale (push outward, 3s), pause. Enemies drift with the wind too. Boogers are slow chasers. Pollen spawns on inhale (sucked in from edges). Nose hairs are static boundary hazards. The FINGER is a lunger from below. Every 20s: a sneeze — 1.5s of max wind + burst spawn.
- **Arena:** Circle. Slight random drift (head movement).
- **Win:** Survive 40s.
- **Background prompt:** "Inside of a human nasal cavity, pink and red fleshy walls, mucous membrane texture, glistening wet surface, tiny blood vessels visible, warm pinkish lighting, organic tunnel, gross and biological, pixel art style, 16-bit retro game background. No hair, no objects, no text, no watermarks."
- **Alternate background:** "Medical textbook cross-section illustration of a human nasal cavity interior, clean precise linework, labeled anatomy diagram style, muted educational color palette, printed on matte off-white paper, clinical and scientific. No hair, no objects, no text labels, no watermarks."

---

### #5 — LEVEL 0 [GOOD]
**The Backrooms. The carpet is damp. Something is here.**
- **Sprite:** `backrooms`
- **Hook:** **Extreme fog** (radius 80). That's it. That's the hook. You can see NOTHING. Entity shadows are slow chasers. Exit signs are teleporters (bait). Ceiling tiles fall from above. The horror is navigating blind. Sound cues matter more than visuals (different entity types make different approach sounds). Damp carpet stains are static hazards you can't see until you're on top of them.
- **Arena:** Square. Large. Static. Dark.
- **Win:** Dodge 30.
- **Background prompt:** "The Backrooms, empty infinite office space, stained yellow-beige wallpaper, damp brown commercial carpet, buzzing fluorescent ceiling lights, liminal space, eerie and abandoned, slightly off perspective, pixel art style, 16-bit retro game background. No people, no doors, no text, no watermarks, no furniture."
- **Alternate background:** "Still frame from a VHS surveillance camera recording of an empty office hallway, heavy scan lines, washed out contrast, greenish-grey color cast, fish-eye lens distortion, grainy low-light noise, timestamp overlay in bottom corner reading 01/14/1999 03:47:22 AM, found footage aesthetic. No people, no doors, no text besides timestamp, no watermarks, no furniture."

---

### #6 — FLUSH [FILLER]
**Rubber duck in a flushing toilet. Stay afloat.**
- **Sprite:** `toilet`
- **Hook:** Strong gravity toward center (the drain). Pulsing arena (flush cycles). Bouncer soap bars. Standard dodge with a vortex gimmick.
- **Arena:** Circle. Pulsing. Gravity 150 toward center.
- **Win:** Survive 30s.
- **Background prompt:** "Inside of a white porcelain toilet bowl viewed from above, swirling blue-tinted water, circular drain in center, clean white ceramic walls, water ripples and bubbles, pixel art style, 16-bit retro game background. No objects, no text, no watermarks, no seat."

---

### #7 — STORM CHASER [GOOD]
**Tornado. Stay in the eye. Everything else is in the air.**
- **Sprite:** `tornado`
- **Hook:** Arena moves FAST and erratically (the eye of the storm). Leaving = instant death. The challenge is tracking a moving safe zone while dodging cows, car doors, and shopping carts. Wind is changing_turbulent at 150. You're chasing safety.
- **Arena:** Circle. Moving at speed 4.0. Leaving = death.
- **Win:** Survive 40s.
- **Background prompt:** "Aerial view of a dark green Kansas cornfield during a violent tornado storm, dark swirling grey-green sky, flattened crops in spiral patterns, dirt and debris in the air, ominous and chaotic, pixel art style, 16-bit retro game background. No tornado funnel, no buildings, no people, no text, no watermarks."
- **Alternate background:** "Low resolution digital photograph of a dark green Kansas cornfield under a storm, taken with an early 2000s digital camera, jpeg compression artifacts, slightly overexposed flash, washed out colors, 640x480 resolution feel, storm chaser amateur photography. No tornado funnel, no buildings, no people, no text, no watermarks."

---

### #8 — 30 SECONDS [FILLER]
**Microwave. Fork is sparking. Don't get zapped.**
- **Sprite:** `microwave`
- **Hook:** Tiny arena. Stationary fork shooter in center. Popcorn kernels teleport-pop. Time survival, exactly 30 seconds. Not creative, but claustrophobic.
- **Arena:** Circle. Small (0.6). Static.
- **Win:** Survive 30s.
- **Background prompt:** "Inside of a microwave oven viewed from above, dirty yellow-stained interior walls, rotating glass plate with food splatter stains, warm orange-yellow glow from the light, grease spots, pixel art style, 16-bit retro game background. No food, no objects, no text, no watermarks, no door."

---

### #9 — LUCID [GOOD]
**A dream. The rules keep changing.**
- **Sprite:** `dream`
- **Hook:** **Phase enemies + shape-shifting arena.** But the REAL hook: the movement mode CHANGES mid-game. Starts as directional. At 15s, switches to asteroids (you're floating). At 25s, switches to jump mode (you're teleporting). Giant eyes are chasers. Shadow figures phase in/out. Melting clocks are slow obstacles. The arena shifts polygon count constantly. You can't get comfortable.
- **Arena:** Circle → triangle → hex → square (shape_shifting). Fog radius 140.
- **Win:** Survive 40s.
- **Background prompt:** "Surreal dreamscape, impossible geometry, melting pastel landscape, soft purple and pink clouds on a dark sky, floating impossible staircases in the distance, warped perspective, Salvador Dali inspired, hazy and ethereal, pixel art style, 16-bit retro game background. No people, no faces, no text, no watermarks, no clocks."
- **Alternate background:** "Soft watercolor painting of a surreal dreamscape, wet-on-wet bleeding pastel washes of purple and pink, impossible geometry dissolving into paper texture, visible watercolor paper grain, pigment pooling at edges, dreamy and formless, fine art aesthetic. No people, no faces, no text, no watermarks, no clocks."

---

### #10 — DUST BUNNY'S LAST STAND [GOOD]
**You're a dust bunny. The vacuum is approaching. Everything pushes you toward it.**
- **Sprite:** `vacuum`
- **Hook:** **Reversed gravity** (pushes AWAY from center toward arena edge). Arena SHRINKS (the vacuum approaches). You fight inward against the suction while the safe zone closes in. Cheerios and legos bounce around as collateral. It's a fight against physics.
- **Arena:** Circle. Shrinking (speed 2.0). Gravity -80 (outward).
- **Win:** Survive 25s.
- **Background prompt:** "Underneath a couch viewed from ground level, dark dusty hardwood floor, dust bunnies in shadows, crumbs and debris scattered, couch fabric above, dim ambient light from edges, dirty and forgotten, pixel art style, 16-bit retro game background. No furniture legs, no objects, no people, no text, no watermarks."

---

### #11 — SATURDAY NIGHT [GOOD]
**Disco. The spotlight is the real enemy.**
- **Sprite:** `disco`
- **Hook:** **Sweep beam.** A spotlight orbits the arena like a lighthouse. It doesn't damage you — it MARKS you. While spotlit, all chasers triple their turn rate for 3 seconds. You must dodge the beam AND dodge the chasers, and being caught by the beam makes the chasers deadly. Disco ball shards are fast linear bursts. Platform shoes are lungers (stomping).
- **Arena:** Square. Pulsing (the "beat"). Spawns sync to pulse.
- **Win:** Dodge 50.
- **Background prompt:** "Top-down view of a 1970s disco dance floor, colorful illuminated square tiles glowing in red blue green yellow pink, reflective glossy surface, dramatic colored lighting from above, Saturday Night Fever aesthetic, pixel art style, 16-bit retro game background. No people, no disco ball, no text, no watermarks, no furniture."
- **Alternate background:** "1970s vintage disco event poster, flat bold color blocks of hot pink magenta and electric blue, geometric starburst pattern, screen-printed look with slight ink misregistration, groovy retro typography spacing but no actual text, psychedelic color gradients, glossy dance floor tiles. No people, no disco ball, no text, no watermarks, no furniture."

---

### #12 — IMMUNE RESPONSE [GOOD]
**You're a virus. White blood cells are hunting you. The body is clotting.**
- **Sprite:** `bloodstream`
- **Hook:** **Growing enemies.** Platelets are static entities that GROW. They don't move. They just expand, filling the arena with impassable clots. Meanwhile white blood cells (chasers) herd you toward the clots. Red blood cells are huge slow obstacles — not hostile, just in the way. The arena slowly fills up with stuff that wasn't there before.
- **Arena:** Circle. Steady wind (blood flow). Arena drifts cardinal (heartbeat).
- **Win:** Survive 45s.
- **Background prompt:** "Inside a human blood vessel viewed through a microscope, warm red-pink background, translucent flowing plasma, soft red glow, blurred vessel walls at edges, organic and wet, medical illustration style, pixel art style, 16-bit retro game background. No cells, no objects, no text, no watermarks, no labels."
- **Alternate background:** "Scientific biology textbook illustration of a blood vessel cross-section interior, clean precise linework, educational diagram style with muted reds and pinks, printed on cream-colored matte paper, clinical and anatomical, visible halftone printing dots. No cells, no objects, no text labels, no watermarks, no arrows."

---

### #13 — CLEANUP AISLE 7 [FILLER]
**Mop bucket vs shopping carts. Standard dodge with banana peel slip zones.**
- **Sprite:** `supermarket`
- **Hook:** Static banana peel hazard zones (holes). Runaway shopping carts (bouncers). Falling signs (lungers). Nothing special. A filler game that exists to pad the catalog.
- **Arena:** Square. Large. Static.
- **Win:** Dodge 40.
- **Background prompt:** "Top-down view of a supermarket aisle floor, white and grey speckled linoleum tiles, fluorescent lighting glare, wet floor puddle, shelf edges visible at sides, shopping cart wheel marks, sterile and commercial, pixel art style, 16-bit retro game background. No products, no people, no signs, no text, no watermarks."

---

### #14 — YOU'VE GOT SPAM [GOOD]
**1999 inbox. Click to survive.**
- **Sprite:** `spam_inbox`
- **Hook:** **Jump mode (click-to-move cursor).** Short range, fast cooldown. Pop-up ads are teleporters that block space. Chain letters are splitters. But here's the twist: **powerup drops.** An "X" button spawns on each popup. Click it (touch it with jump) to dismiss the popup AND get a brief speed boost. You're closing popups while dodging spam. Nigerian prince is a chaser that gets faster over time.
- **Arena:** Square (the screen). Static.
- **Win:** Dodge 55.
- **Background prompt:** "1999 Windows desktop wallpaper, teal blue-green gradient background, low resolution CRT monitor look, slightly pixelated, scan lines faintly visible, early internet era computer screen aesthetic, pixel art style, 16-bit retro game background. No icons, no taskbar, no windows, no text, no watermarks, no cursor."
- **Alternate background:** "Screenshot of a 1999 Windows 98 desktop, teal blue-green gradient wallpaper, CRT monitor scan lines, 800x600 resolution, jpeg artifacts, slightly curved screen edges, warm phosphor glow, authentic late 90s computer display. No icons, no taskbar, no windows, no text, no watermarks, no cursor."

---

### #15 — LOST IN THE CUSHIONS [FILLER]
**Quarter in the couch. Tiny arena. Dust bunnies.**
- **Sprite:** `couch_cushion`
- **Hook:** Small arena (0.5). Shrinking (someone's sitting down). That's it. Mystery sticky patches are static hazards. Generic dodge in a small space. Intentionally lazy.
- **Arena:** Square. Small. Shrinking.
- **Win:** Survive 30s.
- **Background prompt:** "Close-up texture of couch cushion fabric, brown and beige woven upholstery pattern, loose threads, fabric pills, slight indentation creases, warm dim lighting, macro photography feel, pixel art style, 16-bit retro game background. No objects, no coins, no text, no watermarks, no seams."

---

### #16 — TADPOLE [GEM]
**Spring pond. You're a tadpole. Eat 10 flies to become a frog.**
- **Sprite:** `pond`
- **Hook:** **Collect to win + safe platforms.** Flies (collectibles) spawn among the hazards. Touch a fly = +1 toward victory. BUT frogs are lungers (tongue strike), dragonflies are fast zigzags, and turtles are huge slow obstacles. **Lily pads** are 2-3 small moving safe zones where enemies can't touch you — brief respite to plan your next move. The game is navigating to collectibles through danger, not just surviving.
- **Arena:** Circle (pond). Pulsing (water level). Slow drift.
- **Win:** Collect 10 flies. Not dodge count. Not time.
- **Background prompt:** "Top-down view of a murky green pond surface, dark green water with algae, small ripples, duckweed patches, reflected sky light, mossy edges, natural and organic, peaceful but murky, pixel art style, 16-bit retro game background. No fish, no lily pads, no animals, no text, no watermarks, no reflections of trees."
- **Alternate background:** "Watercolor painting of a murky green pond viewed from above, soft bleeding washes of dark green and olive, wet-on-wet technique with pigment pooling, visible watercolor paper texture, loose brushwork for algae and duckweed, nature illustration from a children's book. No fish, no lily pads, no animals, no text, no watermarks."

---

### #17 — HARD HAT ZONE [GOOD]
**Construction site. Everything falls from above. OSHA is a myth.**
- **Sprite:** `construction`
- **Hook:** **Converging lines.** Walls of bricks fall from top — a LINE of 6-8 bricks with ONE gap. Player must move to the gap. Meanwhile crane hooks swing side to side (wide zigzag sweeps), barrels roll and bounce, and falling beams are lungers that stay on the ground for 2 seconds, creating temporary barriers you must navigate around. Gravity pulls downward (60).
- **Arena:** Square. Static. Gravity 60 (down).
- **Win:** Dodge 45.
- **Background prompt:** "Top-down view of a construction site ground, brown dirt and gravel, tire tracks, puddles of muddy water, scattered pebbles, yellow caution tape fragment at edge, rough industrial terrain, pixel art style, 16-bit retro game background. No equipment, no people, no vehicles, no text, no watermarks, no buildings."

---

### #18 — SHAKE [GOOD]
**Snow globe. A child just picked it up. SHAKE SHAKE SHAKE.**
- **Sprite:** `snow_globe`
- **Hook:** **Arena moves like crazy** (speed 4.0, random). The globe is being shaken by a child. The boundary whips around. You're bouncing off the walls (asteroids mode, high bounce). Fake snow is massive spawn rate of tiny obstacles. The houses and trees are huge bouncers (the scenery is loose). The chaos IS the game — nothing is trying to kill you specifically, you're just inside a violent shaking container.
- **Arena:** Circle. Random movement speed 4.0. Pulsing (3.0).
- **Win:** Survive 30s.
- **Background prompt:** "Inside of a snow globe viewed from above, swirling white water with suspended glitter particles, blurry glass dome edges refracting light, milky translucent liquid, magical and chaotic, pixel art style, 16-bit retro game background. No figurines, no base, no text, no watermarks, no snow flakes."

---

### #19 — PAPER JAM [FILLER]
**Inside a printer. Conveyor pushes you. Fog of toner.**
- **Sprite:** `printer`
- **Hook:** Steady wind pushes right (the paper feed). Fog radius 120 (toner). You resist the feed direction while dodging ink blobs and paper sheets. Generic with wind + fog combo.
- **Arena:** Square. Static.
- **Win:** Survive 35s.
- **Background prompt:** "Inside of an office printer, flat grey metal interior, roller mechanism tracks, faint toner dust on surfaces, paper guides and feed slot visible, industrial grey and black, claustrophobic mechanical space, pixel art style, 16-bit retro game background. No paper, no cartridges, no text, no watermarks, no labels."

---

### #20 — GROOVY [FILLER]
**Lava lamp. Float. Drift. Vibe.**
- **Sprite:** `lava_lamp`
- **Hook:** Maximum drift. Asteroids mode, decel_friction 0.6. Wax blobs are bouncers. You're basically playing billiards as the cue ball. Slow, meditative, easy. The variant people play to relax. Bad on purpose in the way that screensavers are bad — you stare at it.
- **Arena:** Circle. Pulsing (slow). Gravity -40 (upward float).
- **Win:** Dodge 25.
- **Background prompt:** "Inside of a lava lamp, warm orange and red glowing liquid, soft psychedelic color gradients blending between deep red magenta and warm amber, blurred waxy shapes, dreamy and hypnotic, 1970s aesthetic, pixel art style, 16-bit retro game background. No wax blobs, no lamp hardware, no text, no watermarks, no borders."
- **Alternate background:** "1970s psychedelic concert poster background, swirling orange magenta and amber color gradients, Art Nouveau curves, screen-printed with slight ink misregistration, bold flat color fills, groovy and hypnotic, vintage head shop wall art. No wax blobs, no lamp hardware, no text, no watermarks, no borders."

---

### #21 — BIG TOP [GEM]
**Circus. You have a cannon. Shoot balloons. Dodge everything else.**
- **Sprite:** `circus`
- **Hook:** **Player can shoot.** You auto-fire a cannonball forward every 1.5 seconds. Balloons (targets) float around — destroy 15 to win. BUT clowns are chasers, juggling balls are bouncers, cannon balls (enemy) are fast linear, and trapeze bars are wide zigzag sweeps. You must POSITION yourself to aim at balloons while not dying to everything else. Dual objective: dodge AND shoot. Sometimes a balloon is behind a clown. Do you risk it?
- **Arena:** Circle (the ring). Static.
- **Win:** Destroy 15 balloons. (Not dodge count.)
- **Background prompt:** "Top-down view of a circus ring floor, packed reddish-brown sawdust and dirt, circular ring border painted white, dramatic overhead spotlight pools of warm yellow light on dark ground, big top tent atmosphere, pixel art style, 16-bit retro game background. No performers, no audience, no equipment, no text, no watermarks, no animals."
- **Alternate background:** "Vintage circus event poster, bold red and gold color blocks, dramatic starburst pattern radiating from center, slightly faded and worn lithograph print on aged cream paper, Barnum and Bailey era aesthetic, flat bold shapes with thick outlines. No performers, no audience, no equipment, no text, no watermarks, no animals."

---

### #22 — BUNKER [FILLER]
**Y2K bunker. Small. Dark. Countdown to nothing.**
- **Sprite:** `y2k_bunker`
- **Hook:** Small arena (0.5). Fog radius 90. Shrinking. Countdown numbers fall. It's dark, cramped, and getting smaller. Generic but atmospheric. The joke is that you survive 60 seconds and nothing happens. Y2K was nothing.
- **Arena:** Square. Small. Shrinking. Fog. Leaving = death.
- **Win:** Survive 60s.
- **Background prompt:** "Underground concrete bunker floor, cold grey concrete walls and floor, dim yellow emergency light, military surplus crates stacked at edges, bare pipes on ceiling, damp condensation, cold war fallout shelter aesthetic, pixel art style, 16-bit retro game background. No people, no supplies visible, no text, no watermarks, no doors."

---

### #23 — TPS REPORTS [FILLER]
**Office. Monday. Stapler wars.**
- **Sprite:** `office`
- **Hook:** Intentionally boring. Slow player (180). Slow enemies. Waves of memo paper. The game plays itself almost. Exists to be forgettable — a joke about how dull office life is. Players who find this one just move on. That's correct.
- **Arena:** Square. Huge. Static.
- **Win:** Dodge 35.
- **Background prompt:** "Top-down view of a grey office cubicle floor, thin commercial grey carpet with repeating pattern, fluorescent lighting glare, coffee stain ring, mundane and depressing corporate office, pixel art style, 16-bit retro game background. No furniture, no people, no office supplies, no text, no watermarks, no partitions."
- **Alternate background:** "1990s Microsoft Office clip art style office floor, simple vector shapes with gradient fills, limited color palette of grey beige and muted blue, thick black outlines, slightly awkward proportions, WMF clip art aesthetic, corporate and generic. No furniture, no people, no office supplies, no text, no watermarks, no partitions."

---

### #24 — COLONY [GOOD]
**Petri dish. You're a microbe. Everything is dividing.**
- **Sprite:** `petri_dish`
- **Hook:** **Growing enemies + expanding rings.** Colony clusters grow from radius 5 to 50 over time (static, expanding). Dividing amoebas are splitters that split into EQUAL-sized copies (not smaller shards — mitosis). Each daughter can split again. Meanwhile, the colony occasionally pulses out an **expanding ring** of spores with one gap — position yourself in the gap. The arena FILLS UP. Late game is navigating a maze of growths.
- **Arena:** Circle. Fog radius 80 (microscope lens).
- **Win:** Survive 45s.
- **Background prompt:** "Petri dish viewed through a microscope, transparent agar gel surface, faint grid lines, slightly blue-tinted from staining, out-of-focus circular dish edge, clean laboratory aesthetic, scientific and clinical, pixel art style, 16-bit retro game background. No bacteria, no colonies, no organisms, no text, no watermarks, no labels."
- **Alternate background:** "Actual microscopy photograph of a petri dish, low resolution digital lab camera capture, slight blue staining tint, out-of-focus circular dish edge, clinical fluorescent lighting, jpeg compression, authentic laboratory documentation photo from a 2001 biology textbook CD-ROM. No bacteria, no colonies, no organisms, no text, no watermarks, no labels."

---

### #25 — FONDUE NIGHT [FILLER]
**Bread cube in a fondue pot. Don't fall in.**
- **Sprite:** `fondue`
- **Hook:** Small arena, leaving = instant death (you fell in the fondue). Cheese drips from top, skewers are lungers. Jump mode. Standard dodge, cramped. Fine.
- **Arena:** Circle. Small (0.6). Leaving = death. Pulsing (bubbling).
- **Win:** Dodge 35.
- **Background prompt:** "Top-down view of bubbling fondue pot surface, molten golden-yellow cheese with bubbles, glossy and viscous, warm orange glow from below, swirling melted texture, rich and appetizing, pixel art style, 16-bit retro game background. No skewers, no food pieces, no pot rim, no text, no watermarks, no hands."

---

### #26 — RECESS [GEM]
**Dodgeball. Catch. Throw. Win.**
- **Sprite:** `playground`
- **Hook:** **Catch/throw mechanic.** Dodgeballs fly at you (chasers, fast). If you're facing a ball and press ACTION when it's within catch range: you grab it. Now you're holding a ball. Press ACTION again to throw it in your facing direction. Hit a kid (enemy target) = +1 point. Miss = ball is gone. You dodge what you can't catch, catch what you can, and throw to score. Kickballs are bouncers (can't catch these — too big). Jump ropes are wide zigzag sweeps (can't catch). Only dodgeballs are catchable.
- **Arena:** Square (playground). Large. Static.
- **Win:** Hit 10 targets. (Not dodge count, not time.)
- **Background prompt:** "Top-down view of a school playground blacktop, cracked grey asphalt with faded painted lines for four-square and hopscotch, worn and weathered, dandelions growing through cracks, bright sunny daylight, pixel art style, 16-bit retro game background. No children, no equipment, no text, no watermarks, no balls."
- **Alternate background:** "Child's crayon drawing of a school playground viewed from above, thick waxy crayon strokes on white construction paper, bright primary colors, wobbly lines, colors going outside the lines, simplified shapes, a kid drew this during art class. No children, no equipment, no text, no watermarks, no balls."

---

### #27 — SOLE SURVIVOR [FILLER]
**Pebble inside a shoe. The foot is coming. Tiny. Gross.**
- **Sprite:** `inside_shoe`
- **Hook:** The toe is a lunger that takes up HALF the arena. Small arena. Shrinking (foot compresses space). Growing fungus hazards. Generic but gross. The toe is funny.
- **Arena:** Circle. Small (0.5). Shrinking.
- **Win:** Survive 30s.
- **Background prompt:** "Inside of a worn leather shoe viewed from above, dark brown leather interior, worn fabric insole with heel indent, stitching visible along edges, dark and cramped, slightly sweaty and gross, pixel art style, 16-bit retro game background. No foot, no toes, no objects, no text, no watermarks, no laces."

---

### #28 — RED STRING [GOOD]
**Conspiracy wall. Enemies are connected by string. The string hurts.**
- **Sprite:** `conspiracy_wall`
- **Hook:** **Chain tethers.** Thumbtack pairs spawn connected by a red line. Both drift slowly. The LINE between them is a damaging hitbox. 4-5 pairs create a web of lines across the arena. Gaps open and close as pairs drift. You navigate through an evolving cat's cradle of deadly string. Photos are chasers (the truth follows you). Coffee rings are static hazards.
- **Arena:** Square (corkboard). Large. Static.
- **Win:** Dodge 40.
- **Background prompt:** "Cork bulletin board texture, warm brown cork surface with pin holes and small tears, faint grid of tiny holes, slightly uneven surface, warm office lighting, close-up texture fill, pixel art style, 16-bit retro game background. No pins, no papers, no string, no photos, no text, no watermarks."
- **Alternate background:** "Heavily photocopied cork board texture, high contrast black and white xerox, loss of detail in dark areas, toner splotches, slightly skewed scan, punk zine photocopy aesthetic, gritty and lo-fi, visible copy machine artifacts. No pins, no papers, no string, no photos, no text, no watermarks."

---

### #29 — PIPE DREAM [FILLER]
**Sewer rat. Dark. Wet. Roaches.**
- **Sprite:** `sewer`
- **Hook:** Fog radius 100. Wind (sewer current). Cockroaches are fast chasers. Toxic bubbles float up. Generic dark dodge with current.
- **Arena:** Square. Cardinal drift. Fog.
- **Win:** Dodge 35.
- **Background prompt:** "Inside of a dark sewer tunnel viewed from above, grey-green stagnant water, wet stone brick walls, dripping moisture, faint green bioluminescence, slime on walls, dark and oppressive, pixel art style, 16-bit retro game background. No rats, no objects, no grates, no text, no watermarks, no pipes."

---

### #30 — CHICKEN RUN [GOOD]
**You're a chicken. The farm is chaos. There are eggs outside the fence.**
- **Sprite:** `farm`
- **Hook:** **Leave-and-return.** The arena (fenced yard) has tractors, pigs, and pitchforks. But OUTSIDE the arena, eggs spawn (collectibles). You can leave the arena for up to 3 seconds to grab eggs — a visible timer counts down. Overstay outside = fox gets you (instant death). Eggs outside are worth points. Staying inside is safe(r) but you can't win without going outside. Risk/reward on every sortie.
- **Arena:** Square (the yard). Static. Leaving allowed (timed).
- **Win:** Collect 8 eggs from outside the arena.
- **Background prompt:** "Top-down view of a farmyard, brown packed dirt ground, scattered hay and straw, chicken scratch marks, small feathers, wooden fence post shadows, warm afternoon sunlight, rural and rustic, pixel art style, 16-bit retro game background. No animals, no buildings, no fences, no people, no text, no watermarks."
- **Alternate background:** "Watercolor children's book illustration of a farmyard from above, warm earthy brown and golden hay washes, loose friendly brushwork, visible paper texture, storybook quality, gentle afternoon light painted with yellow gouache, Beatrix Potter inspired pastoral charm. No animals, no buildings, no fences, no people, no text, no watermarks."

---

### #31 — AWKWARD [GEM]
**First date. Blue things hurt when you move. Orange things hurt when you're still.**
- **Sprite:** `first_date`
- **Hook:** **Color rules.** Direct Undertale reference. The check (bill) is BLUE — it only damages you if you're moving. Stand still and it passes through you. The spilled drink is ORANGE — it only damages you if you're standing still. You MUST move to avoid it. Phone buzzes are blue (freeze when they appear). Breadsticks are orange (keep moving). Growing awkward silences are orange (you MUST keep moving or the silence kills you). The cognitive load of reading blue vs orange in real time IS the game.
- **Arena:** Small square (the table). Leaving = you left the date = game over.
- **Win:** Survive 45s. You get through the date.
- **Background prompt:** "Top-down view of a small restaurant table, white tablecloth with subtle wrinkles, warm candlelight glow from center, soft romantic dim lighting, slight wine glass ring stain, intimate and awkward, pixel art style, 16-bit retro game background. No plates, no utensils, no candle, no hands, no text, no watermarks, no food."

---

### #32 — DEATH BY POWERPOINT [GOOD]
**Slide 47 of 120. The presentation wants your soul.**
- **Sprite:** `powerpoint`
- **Hook:** **Formation walls (horizontal wipes).** PowerPoint transition effects are full-width walls that sweep across the arena with ONE gap (a "slide transition"). You must reach the gap. Between transitions: bullet points fire from the left like actual bullets (fast linear). Clip art bounces around. Comic Sans text blocks are huge slow obstacles. Word Art is a splitter (explodes into letters). The transitions are the skill check — everything else is noise.
- **Arena:** Square (the slide). Large. Static.
- **Win:** Survive 60s (the presentation ends).
- **Background prompt:** "White PowerPoint slide background with faint blue gradient border, corporate presentation template, very plain, subtle geometric accent shapes in corners, sterile and boring, late 1990s Microsoft Office aesthetic, pixel art style, 16-bit retro game background. No text, no bullet points, no clip art, no logos, no watermarks, no charts."
- **Alternate background:** "Actual 1990s Microsoft PowerPoint 97 slide template, white background with teal and purple geometric border accents, gradient fills, beveled shape decorations in corners, corporate clip art aesthetic, authentic Office 97 design template, vector-sharp edges. No text, no bullet points, no clip art icons, no logos, no watermarks, no charts."

---

### #33 — ERUPTION [GOOD]
**Volcano. Lava rising. Bombardment from above.**
- **Sprite:** `volcano`
- **Hook:** Shrinking arena (lava rises) + gravity 80 (downslope) + fog radius 120 (ash). Lava bombs are large fast obstacles from top. Magma globs are chasers. Fast shrink speed (2.0). The urgency is real — you're losing ground fast. A hard variant with no gimmick, just intensity.
- **Arena:** Circle. Shrinking fast. Gravity. Fog.
- **Win:** Survive 35s.
- **Background prompt:** "Aerial view of a volcanic mountainside, dark charcoal and grey volcanic rock, orange-red glowing lava cracks between rocks, rising heat haze, ash-covered terrain, smoke wisps, hellish and dangerous, pixel art style, 16-bit retro game background. No eruption, no sky, no people, no buildings, no text, no watermarks."
- **Alternate background:** "1990s CGI raytraced render of a volcanic landscape, smooth plastic-looking rock surfaces, exaggerated specular highlights on lava, visible aliasing on edges, Bryce 3D or POV-Ray aesthetic, oversaturated orange glow, primitive global illumination, early 3D graphics demo feel. No eruption, no sky, no people, no buildings, no text, no watermarks."

---

### #34 — WHAT'S DOWN THERE [GOOD]
**Ball pit. You can't see. You grow.**
- **Sprite:** `ballpit`
- **Hook:** **Growing player.** Every time you successfully dodge an enemy, your hitbox grows by 2%. After dodging 20 things, you're 40% bigger. After 30, 60% bigger. The arena doesn't change. The enemies don't change. YOU change. Early game is easy. Late game is impossible because you can't fit through gaps anymore. The bandaids are static hazards (holes). Fog radius 80 (under the balls). The mystery_wet is a growing enemy (expanding wet zone).
- **Arena:** Circle. Static. Fog. Small (0.6).
- **Win:** Dodge 40. (Good luck around dodge 35.)
- **Background prompt:** "Top-down view of a ball pit, densely packed colorful plastic balls in red blue green yellow orange, viewed slightly from above, playful and childish, bright primary colors filling the entire frame, fast food restaurant play area, pixel art style, 16-bit retro game background. No children, no structures, no text, no watermarks, no netting."
- **Alternate background:** "Low resolution digital photograph of a ball pit taken with a disposable camera, slightly blurry, flash overexposing the nearest balls, warm color cast, 1998 birthday party snapshot aesthetic, grainy film quality, slightly tilted framing. No children, no structures, no text, no watermarks, no netting."

---

### #35 — GHOST PROTOCOL [GOOD]
**Haunted house. Protect the kid. The ghosts phase in and out.**
- **Sprite:** `haunted_house`
- **Hook:** **Escort + phase enemies.** A kid stands at the center of the arena. Ghosts (phase enemies that flicker solid/ghost) target THE KID, not you. You must body-block — position yourself between ghosts and the kid. When a ghost is solid and reaches the kid, the kid loses a life (kid has 5 lives). Chandelier lungers target you directly. Bat swarms are clusters you dodge normally. But the ghosts? You're a shield, not a dodger. Different mental model entirely.
- **Arena:** Square. Fog radius 130. Shape-shifting morph.
- **Win:** Kid survives 45s.
- **Background prompt:** "Dark interior of a Victorian haunted mansion, faded ornate wallpaper peeling off walls, dark hardwood floor with dust, cobwebs in corners, dim moonlight through unseen window, eerie green-grey tones, creepy and abandoned, pixel art style, 16-bit retro game background. No ghosts, no furniture, no people, no doors, no text, no watermarks."
- **Alternate background:** "Victorian pen-and-ink illustration of a haunted mansion interior, fine crosshatching for shadows, delicate line work on peeling wallpaper and floorboards, black ink on aged yellowed paper, Edward Gorey inspired, gothic and detailed, etching quality. No ghosts, no furniture, no people, no doors, no text, no watermarks."

---

### #36 — SIEGE [GEM]
**Castle courtyard. Arrows rain. You have a shield. Choose: block or run.**
- **Sprite:** `medieval`
- **Hook:** **Shield mechanic.** Hold UP/DOWN/LEFT/RIGHT to raise your shield in that direction. Shield blocks ALL projectiles from that side. But you CAN'T MOVE while shielding. Arrows rain from all 4 directions in waves. Each wave comes from 1-2 directions. Read which direction, shield, survive. Between waves: scramble to a better position. Flaming arrows are chasers (can't be blocked — must dodge). Catapult rocks are splitters. The choice between blocking and running is the entire game.
- **Arena:** Square (courtyard). Static. Wave-based spawning.
- **Win:** Survive 60s.
- **Background prompt:** "Top-down view of a medieval castle stone courtyard, grey cobblestone floor with moss between cracks, worn and ancient, faint torch light glow from edges, arrow slits in distant walls, grey and cold, pixel art style, 16-bit retro game background. No people, no weapons, no flags, no text, no watermarks, no furniture."
- **Alternate background:** "Medieval illuminated manuscript page depicting a castle courtyard from above, gold leaf accents on cobblestone borders, rich blue and red tempera paint on vellum parchment, ornate decorative border with vine scrollwork, 12th century Romanesque art style, hand-painted by monks. No people, no weapons, no flags, no text, no watermarks, no furniture."

---

### #37 — SCORCHED [FILLER]
**Desert. Scorpions. Tumbleweeds. Heat.**
- **Sprite:** `desert`
- **Hook:** Tumbleweeds are bouncers with 8+ bounces (they NEVER STOP). They accumulate. By 30 seconds there are 15 tumbleweeds bouncing around forever plus new enemies spawning. The arena fills with permanent hazards. Otherwise standard.
- **Arena:** Circle. Changing_turbulent wind.
- **Win:** Dodge 40.
- **Background prompt:** "Top-down view of flat arid desert sand, pale yellow-orange fine sand texture, wind ripple patterns, faint heat shimmer distortion, cracked dry earth patches, harsh midday sun bleaching everything, empty and desolate, pixel art style, 16-bit retro game background. No cacti, no rocks, no animals, no dunes, no text, no watermarks."

---

### #38 — TEMPLE [GOOD]
**Jungle temple. Trap darts. The walls are closing.**
- **Sprite:** `jungle`
- **Hook:** Darts are VERY fast, VERY small obstacles. The skill check is pure reaction. Shrinking arena (walls closing). Fog (dark temple). Snakes are chasers. Monkeys are shooters (throw coconuts). The game is just FAST — high speed enemies in a closing space with limited visibility. Not mechanically novel, but the speed and urgency make it feel different. An action movie.
- **Arena:** Square. Shrinking (1.5). Fog radius 140.
- **Win:** Dodge 45.
- **Background prompt:** "Top-down view of ancient stone temple floor, dark grey carved stone blocks with Aztec or Mayan geometric patterns, moss growing in crevices, torchlight flickering from edges, mysterious and dangerous, Indiana Jones aesthetic, pixel art style, 16-bit retro game background. No people, no traps, no idols, no text, no watermarks, no doorways."

---

### #39 — TOY CHEST [FILLER]
**Marble in a toy box. Bouncy everything.**
- **Sprite:** `toy_box`
- **Hook:** Asteroids mode. Bounce damping 0.95 (almost perfect bounce). Player AND enemies bounce constantly. Lego bricks are static holes (stepping on lego = damage). It's pinball chaos. Fun but not deep.
- **Arena:** Square. Static.
- **Win:** Dodge 35.
- **Background prompt:** "Inside of a wooden toy chest viewed from above, light pine wood bottom with scratches and crayon marks, colorful paint smudges, warm playful atmosphere, child's bedroom lighting, pixel art style, 16-bit retro game background. No toys, no objects, no lid, no text, no watermarks, no stickers."

---

### #40 — GESUNDHEIT [GEM]
**A sneeze is building. You have 35 seconds. The sneeze takes 2 of them.**
- **Sprite:** `sneeze`
- **Hook:** **Burst events (scripted phases).**
  - **Phase 1 — The Tickle (0-15s):** Almost nothing. Tiny pollen drifts. A dust mite ambles toward you. You could put down the controller. Something is building.
  - **Phase 2 — The Build (15-28s):** Spawn rate increases. Germs appear (chasers). Mucus globs (large slow). Wind starts picking up. Screen starts shaking slightly. You're still fine. You're nervous.
  - **Phase 3 — THE SNEEZE (28-30s):** **Everything.** Spawn rate x20. 40+ droplets fire from one direction. Wind spikes to 200, turbulent. Screen shake 5.0. Arena whips around (head movement). 2 seconds of absolute devastation. The worst 2 seconds in any variant.
  - **Phase 4 — Aftermath (30-35s):** Silence. Almost nothing. You survived.
- **Win:** Survive 35s.
- **Background prompt:** "Extreme close-up of human skin surface, pinkish flesh tone with visible pores, faint peach fuzz hair follicles, slightly shiny from mucus, warm soft lighting, biological and intimate, micro-scale perspective, pixel art style, 16-bit retro game background. No eyes, no features, no face, no text, no watermarks, no moles."
- **Alternate background:** "Medical dermatology textbook photograph of human skin surface at macro scale, clinical lighting, visible pores and follicles, educational reference image printed on matte paper, slight halftone printing pattern, scientific and detached, 1990s medical reference CD-ROM quality. No eyes, no features, no face, no text labels, no watermarks, no moles."

---

### #41 — TUMBLE DRY [GEM]
**Dryer. Gravity rotates. "Down" keeps moving. You're laundry.**
- **Sprite:** `dryer`
- **Hook:** **Arena rotation.** The circular arena slowly rotates (0.5 rad/s). Gravity is STRONG (120) and always points "down" in screen space — but the arena is spinning. So the floor of the drum keeps rotating beneath you. You tumble. Socks and lint bounce around. Static sparks are fast linear. Buttons and coins are small bouncers. Everything tumbles together. Disorienting by design.
- **Arena:** Circle (drum). Rotating. Gravity 120.
- **Win:** Survive 40s.
- **Background prompt:** "Inside of a clothes dryer drum, circular stainless steel interior with small holes punched in metal, warm from heat, slight lint haze, rotating tumble motion blur on edges, industrial and metallic, pixel art style, 16-bit retro game background. No clothes, no lint, no door, no text, no watermarks, no buttons."
- **Alternate background:** "Low resolution digital photograph of the inside of a clothes dryer drum, stainless steel with punched holes, taken with a cheap digital camera, slight motion blur, warm tungsten lighting, laundromat documentation photo, jpeg artifacts, amateur photography. No clothes, no lint, no door, no text, no watermarks, no buttons."

---

### #42 — PEST CONTROL [FILLER]
**Garden gnome. Bees. Lawnmower.**
- **Sprite:** `garden`
- **Hook:** Bees are fast zigzags. The lawnmower is a single wide-sweep obstacle that crosses the ENTIRE arena (full-width, rare, must dodge or die). Thorns are static holes. Otherwise standard. The lawnmower is the only interesting thing — a periodic arena-spanning threat.
- **Arena:** Square. Static.
- **Win:** Dodge 35.
- **Background prompt:** "Top-down view of a garden lawn, bright green grass with slightly uneven patches, small clover and dandelion leaves, morning dew drops, warm sunlight, fresh and suburban, well-maintained yard, pixel art style, 16-bit retro game background. No flowers, no tools, no gnomes, no fences, no text, no watermarks, no paths."

---

### #43 — PIN DOWN [FILLER]
**You're a bowling pin. Balls roll at you from one side.**
- **Sprite:** `bowling`
- **Hook:** Bowling balls are HUGE, fast, linear, from one edge only (bottom). Steady wind pushes you toward the balls (the approach pull). Narrow arena concept. Simple — dodge the balls. Some games on the CD are just this bad.
- **Arena:** Square. Wind steady toward balls.
- **Win:** Dodge 25.
- **Background prompt:** "Top-down view of a bowling alley lane, polished light maple wood surface with oil sheen, faint lane arrows and dots painted on wood, glossy and reflective, overhead fluorescent lighting, long and narrow perspective, pixel art style, 16-bit retro game background. No pins, no balls, no gutters visible, no text, no watermarks, no people."

---

### #44 — RIPTIDE [GOOD]
**Shell on a beach. Waves come in patterns. Read the tide.**
- **Sprite:** `beach`
- **Hook:** **Choreographed sequences.** Waves aren't random — they come in PATTERNS. Wave 1: full width from right with a gap in the middle. Wave 2: two waves from right with two gaps. Wave 3: wave from right AND left simultaneously, offset gaps. The ocean has a rhythm. Between waves: seagull lungers (dive bombs), crab chasers, and beach ball bouncers. But the waves are the game — reading the pattern, finding the gap.
- **Arena:** Square (the beach). Cardinal drift (tide).
- **Win:** Survive 45s.
- **Background prompt:** "Top-down view of a sandy beach shoreline, wet sand with wave wash patterns, foam lines from receded waves, small shell fragments, warm golden afternoon sunlight, water-darkened sand at edges transitioning to dry pale sand, pixel art style, 16-bit retro game background. No umbrellas, no towels, no people, no text, no watermarks, no footprints."
- **Alternate background:** "Watercolor painting of a beach shoreline from above, warm golden sand washes bleeding into wet blue-grey tidal edges, loose brushwork, visible paper grain, soft foam textures painted with white gouache highlights, postcard illustration quality. No umbrellas, no towels, no people, no text, no watermarks, no footprints."

---

### #45 — JUNKYARD DOG [GOOD]
**The dog is loose. The magnet is on. Everything is pulled.**
- **Sprite:** `junkyard`
- **Hook:** **Multiple gravity sources.** The junkyard magnet is a special entity that drifts through the arena. It pulls the PLAYER toward it (localized gravity). The junkyard dog is a fast chaser. Car doors are huge obstacles. The magnet doesn't kill you — it pulls you INTO things. 2 magnets at once = competing pull. You're dodging the dog while being yanked around by magnets. Tires and hubcaps are bouncers caught in the pull too.
- **Arena:** Square. Large.
- **Win:** Dodge 40.
- **Background prompt:** "Top-down view of a junkyard ground, rusty brown dirt with oil stains, scattered metal shavings and rust flakes, crushed gravel, tire tracks, industrial wasteland, overcast grey lighting, gritty and rough, pixel art style, 16-bit retro game background. No cars, no objects, no fences, no dogs, no text, no watermarks."
- **Alternate background:** "Black and white newspaper photograph of a junkyard ground, visible halftone dot printing pattern, high contrast, slight ink bleed on cheap newsprint, grainy photojournalism quality, overcast flat lighting, gritty documentary aesthetic. No cars, no objects, no fences, no dogs, no text, no watermarks."

---

### #46 — KITCHEN NIGHTMARE [GOOD]
**Mouse in a kitchen. The chef is throwing everything. Collect 8 cheese wedges.**
- **Sprite:** `kitchen`
- **Hook:** **Collect to win + dense spawning.** Cheese wedges (collectibles) spawn among the hazards. Knives are very fast linear. Flying pans are lungers (SLAM). Tomatoes and eggs are splitters. Rolling pins bounce. But you're not trying to survive — you're trying to grab cheese. The cheese spawns in dangerous spots. The fastest player speed in any variant (450) because you're a mouse. Quick in, grab cheese, quick out.
- **Arena:** Square. Static. High spawn rate (1.8).
- **Win:** Collect 8 cheese wedges.
- **Background prompt:** "Top-down view of a kitchen countertop, white marble or granite surface with grey veining, flour dust scattered, faint knife scratch marks, warm kitchen lighting, clean but used, culinary workspace, pixel art style, 16-bit retro game background. No utensils, no food, no appliances, no hands, no text, no watermarks."
- **Alternate background:** "Low resolution photograph of a kitchen countertop from a 1990s recipe website, white marble surface with flour dust, warm overhead kitchen lighting, slightly overexposed, early digital camera quality, jpeg compression artifacts, geocities cooking page aesthetic. No utensils, no food, no appliances, no hands, no text, no watermarks."

---

### #47 — FRIDGE HORROR [GOOD]
**Fresh apple in a closed fridge. The leftovers are expanding. Slowly.**
- **Sprite:** `fridge`
- **Hook:** **Growing enemies + slow pace.** Everything is slow. Player slow (180), enemies slow, spawn rate low (0.6). But leftover blobs are growing enemies — static, expanding at 3px/s, capping at radius 50. They never stop. They spawn every 8 seconds. By 30 seconds, the fridge is filling with blobs. Moldy cheese is a chaser (the mold reaches for you). Expired milk is a splitter. The game is a slow-motion horror as available space shrinks to nothing. Not from arena morph — from growing obstacles.
- **Arena:** Square. Small (0.5). Static. No morph (the growing enemies ARE the morph).
- **Win:** Survive 40s.
- **Background prompt:** "Inside of a refrigerator, cold blue-white lighting, white plastic interior walls with condensation droplets, wire shelf grid pattern casting shadows, frost crystals at edges, sterile and cold, slightly ominous, pixel art style, 16-bit retro game background. No food, no containers, no shelves in foreground, no text, no watermarks, no door."
- **Alternate background:** "Still frame from a VHS camcorder recording of the inside of a refrigerator, cold blue-white light, scan lines and tracking distortion, slightly washed out contrast, amateur home video aesthetic, the kind of pointless footage someone records at 2 AM, timestamp overlay. No food, no containers, no shelves in foreground, no text besides timestamp, no watermarks, no door."

---

## Summary

### By Type
**GEMS (8):** MAW (#1), Detention (#2), Tadpole (#16), Big Top (#21), Recess (#26), Awkward (#31), Siege (#36), Gesundheit (#40), Tumble Dry (#41)

**GOOD (18):** Zamboni (#0), Blender (#3), Nasal Passage (#4), Level 0 (#5), Storm Chaser (#7), Lucid (#9), Dust Bunny (#10), Saturday Night (#11), Immune Response (#12), Colony (#24), Recess (#26), Red String (#28), Chicken Run (#30), Death by PowerPoint (#32), Eruption (#33), What's Down There (#34), Ghost Protocol (#35), Temple (#38), Riptide (#44), Junkyard Dog (#45), Kitchen Nightmare (#46), Fridge Horror (#47)

**FILLER (13):** Flush (#6), 30 Seconds (#8), Cleanup Aisle 7 (#13), Lost in Cushions (#15), Paper Jam (#19), Groovy (#20), Bunker (#22), TPS Reports (#23), Fondue (#25), Sole Survivor (#27), Scorched (#37), Toy Chest (#39), Pest Control (#42), Pin Down (#43), Pipe Dream (#29)

### New Systems by Priority

**Must build (multiple gems depend on these):**
1. **Formation walls / patterned spawns** — MAW, Detention, Hard Hat, PowerPoint, Riptide. Enemies spawning in coordinated lines/patterns with readable gaps. This single system enables 5+ variants to feel totally different.
2. **Collect-to-win** — Tadpole, Kitchen Nightmare, Chicken Run. Alternative victory condition: touch N collectible items.
3. **Player shoot** — Big Top. Player fires projectiles to destroy targets.
4. **Catch/throw** — Recess. Grab incoming entities, throw them back.
5. **Color rules (blue/orange)** — Awkward. Two enemy classes with opposite rules: one hurts when moving, one when still.
6. **Shield/block** — Siege. Directional invulnerability, immobile while active.
7. **Burst events** — Gesundheit. Scripted phase-based spawn rate spikes.
8. **Arena rotation** — Tumble Dry. Rotating polygon + gravity interaction.

**Nice to have (enhance good variants):**
9. **Growing enemies** — Immune Response, Colony, Fridge Horror, Ball Pit. Radius increases per frame.
10. **Phase enemies** — Ghost Protocol, Lucid. Solid/ghost toggle.
11. **Leave-and-return** — Chicken Run. Timed excursions outside arena.
12. **Escort/protect** — Ghost Protocol. NPC at center, enemies target it.
13. **Growing player** — Ball Pit. Player hitbox grows per dodge.
14. **Orbit enemies** — Blender, Saturday Night. Circular motion.
15. **Chain tethers** — Red String. Paired entities with damaging line.
16. **Sweep beams** — Saturday Night. Orbiting reveal/damage line.
17. **Safe platforms** — Tadpole (lily pads). Invulnerable zones.

### What About the Other ~200 Variants?

These 48 are the handcrafted ones — the variants with mechanical identity. The remaining slots (up to 10,000) can be generated: take any theme, use standard dodge mechanics, randomize parameters. "Dodge Space #147" with slightly different spawn rates and arena size. That's the filler the AI would generate. These 48 are the ones players discover and remember.
