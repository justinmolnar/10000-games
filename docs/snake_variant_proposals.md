# Snake Variant Proposals

**20 reskinned variants.** Each one re-themes snake into something that feels like a different game on a shovelware CD. The snake mechanic (growing line that can't touch itself) maps to surprisingly many things.

These are tagged:
- **[GEM]** — You'd show this to someone. The fiction makes the mechanic click differently.
- **[GOOD]** — Strong theme. Changes how you think about what you're doing.
- **[FILLER]** — Functional reskin. Different coat of paint, still obviously snake.

For each: the **skin concept**, what the snake/food/obstacles/arena map to thematically, **background prompts** (primary + alt) for PixelLab or AI art, and which existing mechanical profile it maps closest to (so you can clone parameters and just change visuals).

---

## #0 — ROADKILL [GEM]
**You're a car. Pedestrians are food. The blood trail lengthens behind you.**
- **Snake = car** (top-down, smooth trail mode). **Trail = blood smear** (red, continuous). **Food = pedestrians** (small sprites). **Obstacles = lamp posts, fire hydrants.** **Arena = city streets** (grid pattern background).
- **Mechanical hook:** `phase_through_tail = true`. The blood trail is cosmetic — you can drive back through it. This removes the self-collision pressure entirely, making it a pure collection game with obstacle avoidance. Feels different because the core snake constraint is gone.
- **Movement:** Smooth trail mode. Medium speed, tight turning.
- **Win:** Run over 20 pedestrians.
- **Why it works:** The fiction recontextualizes growth as horror. You're not "getting longer" — you're leaving evidence. The phase-through-tail means the growing trail is purely visual dread, not mechanical.
- **Background prompt:** "Grainy still frame from a dashboard-mounted VHS camcorder, dark city intersection at night, wet asphalt reflecting amber streetlight, painted crosswalk barely visible through rain, fisheye lens distortion, scan lines and tracking artifacts, timestamp overlay reading 11/23/1998 02:14 AM, found footage aesthetic. No cars, no people, no blood, no text besides timestamp, no watermarks."
- **Alt background:** "Grand Theft Auto 1 style flat vector city grid viewed from above, simplified dark grey road blocks with bright yellow lane markings, flat color fills with no gradients, stark overhead perspective, 1997 DMA Design aesthetic, aliased pixel edges. No cars, no people, no blood, no text, no watermarks."
- **Alt 2 background:** "Top-down view of dark wet asphalt, simple flat surface with faded white crosswalk stripes and a yellow center line, sodium vapor amber light washing everything orange, rain-slick sheen, tileable road texture, flat and stark. No cars, no people, no blood, no text, no watermarks."
- **Maps to:** Figure Eight (#7) parameters (smooth, phase_through_tail) but slower speed, more obstacles.

---

## #1 — ANT FARM [GOOD]
**Ants carrying sugar back to the colony. Each sugar crystal adds an ant to the line.**
- **Snake = ant column** (segmented body, each segment is an ant). **Food = sugar crystals** (white sparkly dots). **Obstacles = water droplets** (blue, instant death — ants drown). **Arena = wooden ant farm** (brown background, tunnel-like).
- **Movement:** Grid mode. Moderate speed. Wrap walls (tunnels connect).
- **Win:** Grow colony to 25 ants.
- **Why it works:** Ants walking in a line IS snake. The fiction is 1:1. Sugar → growth. Water → death. It's obvious but satisfying.
- **Background prompt:** "Macro photograph of dirt between two glass panes, sandy brown earth with tiny pebble fragments and root cross-sections, warm ambient light diffusing through glass, shallow depth of field, nature documentary extreme close-up, shot on 35mm film with slight grain. No ants, no insects, no text, no watermarks."
- **Alt background:** "Page from a 1970s children's encyclopedia about ant colonies, matte cream paper with visible halftone dot printing, cross-section diagram of soil layers in muted browns and tans, educational illustration with flat earth-tone gouache, textbook binding crease visible at edge. No ants, no insects, no text labels, no watermarks."
- **Alt 2 background:** "Flat sandy brown dirt surface viewed from above, uniform fine-grain earth with tiny pebbles scattered sparsely, simple tileable soil texture, warm sepia tone like a terrarium floor, matte and dry. No ants, no insects, no text, no watermarks."
- **Maps to:** Sunday Stroll (#0) parameters (grid, wrap, simple) but slightly faster.

---

## #2 — CONGA LINE [GOOD]
**Dance floor. You're leading a conga line. Grab dancers. Don't hit the furniture.**
- **Snake = conga dancers** (segmented, each segment a person). **Food = wallflowers** (people standing alone, waiting to join). **Obstacles = tables, chairs, the DJ booth.** **Arena = house party** (square room, death walls — you crash into the wall).
- **Movement:** Smooth trail. Medium-fast. Good turning.
- **Win:** 20-person conga line.
- **Why it works:** A conga line is LITERALLY a human snake. The theme is so natural it barely feels like a reskin.
- **Background prompt:** "Low resolution photograph from a disposable camera at a 1997 house party, warm flash overexposing the hardwood floor, red solo cups casting shadows, streamers and confetti scattered, slightly blurry and tilted framing, 4x6 print scanned at low DPI with dust specks on scanner glass. No people, no furniture in center, no text, no watermarks."
- **Alt background:** "1990s Microsoft Publisher party invitation clip art background, tiled confetti and streamer pattern, oversaturated primary colors, thick black outlines on geometric party shapes, WordArt gradient fills, printed on inkjet with visible banding artifacts. No people, no furniture in center, no text, no watermarks."
- **Alt 2 background:** "Top-down view of a disco dance floor, illuminated square tiles glowing in alternating red blue green yellow, colorful flat light panels in a checkerboard grid, Saturday Night Fever aesthetic, simple repeating tile pattern. No people, no furniture in center, no text, no watermarks."
- **Maps to:** Anaconda (#13) parameters (smooth, high growth, death walls) but smaller arena.

---

## #3 — TRAIN SET [FILLER]
**Model train on a track. Pick up cargo cars. Don't derail.**
- **Snake = train** (locomotive head + cargo cars as segments). **Food = cargo crates** at sidings. **Obstacles = broken track sections.** **Arena = table with train set** (rectangular, death walls = edge of table).
- **Movement:** Grid mode. Slow-medium. Death walls.
- **Win:** 20 cars.
- **Why it works:** Train + cars = snake. Simple, clean, grandpa-friendly.
- **Background prompt:** "Product photograph from a 1998 hobby shop catalog, green felt table surface lit by overhead fluorescents, warm but flat lighting, slightly overexposed, printed on glossy paper with visible CMYK dot pattern, Lionel or Bachmann catalog page aesthetic. No trains, no track, no buildings, no text, no watermarks."
- **Alt background:** "Watercolor painting of a miniature landscape tabletop, loose washes of green grass and brown earth, visible paper grain and pigment pooling at edges, hobby magazine illustration quality, warm golden afternoon light painted with yellow ochre, gentle and nostalgic. No trains, no track, no buildings, no text, no watermarks."
- **Alt 2 background:** "Flat green baize felt surface viewed straight down, uniform billiard-table texture with subtle fiber direction, slightly worn in the center, simple and clean, warm hobbyist lighting. No trains, no track, no buildings, no text, no watermarks."
- **Maps to:** Sardine Can (#4) parameters (grid, death walls, no obstacles) but larger arena.

---

## #4 — CENTIPEDE [GOOD]
**You ARE the centipede. Eat bugs. Grow legs. Garden is full of rocks.**
- **Snake = centipede** (segmented, each segment has tiny legs). **Food = bugs** (beetles, flies). **Obstacles = garden rocks, flower pots.** **Arena = garden** (green, top-down, lots of obstacles). **Golden food = butterflies** (triple growth).
- **Movement:** Grid mode. Fast. Dense obstacles.
- **Win:** 25 segments.
- **Why it works:** Centipede growth is viscerally satisfying — each segment adds legs. The garden is naturally cluttered, justifying high obstacle count.
- **Background prompt:** "Extreme macro photograph of garden soil, shot with a ring flash creating harsh even lighting, dark brown earth with individual sand grains visible, tiny wood chip mulch fragments, shallow depth of field blurring edges, entomology field documentation style, shot on Kodachrome with warm color shift. No insects, no plants in center, no text, no watermarks."
- **Alt background:** "Atari 2600 Centipede arcade cabinet screenshot aesthetic, flat black background with simple colored grid of mushroom shapes, stark primary colors on pure black, heavy aliasing, 160x192 resolution upscaled with nearest-neighbor, 1980 arcade game nostalgia. No insects, no plants in center, no text, no watermarks."
- **Alt 2 background:** "Top-down view of dark garden soil, rich brown earth with scattered pale wood chips and tiny stones, flat uniform texture, slightly damp from morning watering, kitchen garden bed surface. No insects, no plants in center, no text, no watermarks."
- **Maps to:** Siege (#12) parameters (obstacles, death walls) but no shrinking, more initial obstacles.

---

## #5 — BLACK ICE [GEM]
**Highway pileup. Your car slides on ice. Wrecks are permanent obstacles.**
- **Snake = sliding car** (smooth mode, low turn speed = ice physics). **Food = highway exits** (reach the exit = progress). **Obstacles = wrecked cars** that spawn over time. **Arena = highway** (rectangular, death walls = guardrails). **Shrinking = lane closures.**
- **Mechanical hook:** `obstacle_spawn_over_time` + smooth mode with LOW turn speed (60°/s). Every food you eat spawns more wrecks. The highway fills up with wreckage. Combined with ice-physics turning, late game is threading through a junkyard at speed.
- **Movement:** Smooth trail. Slow turning (ice). Medium speed.
- **Win:** Reach 15 exits.
- **Why it works:** Ice physics (low turn_speed) recontextualized as actual ice. The permanent obstacle growth creates escalating tension. Looks nothing like snake.
- **Background prompt:** "Still from a helicopter news camera, overhead shot of a dark highway at night during a snowstorm, interlaced video fields visible, NTSC color bleeding, chyron-shaped blank area at bottom of frame, bright sodium vapor lights creating orange pools on wet black asphalt, breaking news broadcast quality. No cars, no vehicles, no text besides chyron area, no watermarks."
- **Alt background:** "1990s CGI raytraced render of a highway surface, Bryce 3D aesthetic, smooth plastic-looking asphalt with exaggerated specular highlight from a single point light, visible aliasing on lane markings, primitive bump mapping on road texture, early 3D graphics demo reel feel, rendered at 640x480. No cars, no vehicles, no text, no watermarks."
- **Alt 2 background:** "Top-down view of flat dark asphalt with a dusting of white snow, dashed yellow center line and white shoulder markings, ice patches with faint blue-white sheen, simple highway surface texture, cold and bleak. No cars, no vehicles, no text, no watermarks."
- **Maps to:** Glacier (#9) parameters (slow turning, obstacles) but with obstacle_spawn_over_time, larger arena.

---

## #6 — TAPEWORM [GOOD]
**Inside a stomach. You're the parasite. Absorb nutrients. Avoid acid.**
- **Snake = tapeworm** (smooth trail, fleshy pink). **Food = nutrient blobs** (floating, drifting). **Bad food = stomach acid pools** (green, shrinks you). **Obstacles = stomach wall contractions** (moving blocks). **Arena = stomach** (circle, organic).
- **Movement:** Smooth trail. Medium speed. Circle arena, bounce walls.
- **Win:** 18 segments.
- **Why it works:** A tapeworm IS a snake inside a body. The gross factor makes it memorable. Drifting food + moving obstacles = chaotic organic feel.
- **Background prompt:** "Medical textbook photograph of a stomach interior taken via endoscope camera, pink-red mucosal folds glistening with gastric fluid, circular fisheye lens distortion, clinical white light with slight green tint, printed on matte paper in a 1994 gastroenterology reference, visible halftone screening. No organs, no food, no text labels, no watermarks."
- **Alt background:** "Anatomical illustration from a Victorian-era medical atlas, hand-tinted lithograph of stomach interior in muted pinks and reds, fine crosshatching for depth on mucosal walls, printed on aged cream vellum paper, Henry Gray's Anatomy style, delicate and scientific. No organs, no food, no text labels, no watermarks."
- **Alt 2 background:** "Flat pink-red fleshy surface viewed from above, glistening wet mucous membrane texture, uniform warm organic tone with subtle fold ridges, simple biological surface, slimy and gross. No organs, no food, no text, no watermarks."
- **Maps to:** Drunk Driver (#1) parameters (smooth, bounce, obstacles) + food_movement: drift, circle arena.

---

## #7 — POWER STRIP [FILLER]
**Extension cord. Plug into outlets. Don't trip over yourself.**
- **Snake = extension cord** (orange, segmented). **Food = wall outlets** (collect = plug in). **Obstacles = furniture legs.** **Arena = room** (rectangle, death walls).
- **Movement:** Grid mode. Standard speed.
- **Win:** 20 outlets.
- **Why it works:** Extension cord getting tangled = snake body collision. Everyone's done this.
- **Background prompt:** "Low angle photograph of beige office carpet, shot by someone on their hands and knees with a 1999 Kodak digital camera, 640x480 resolution, warm fluorescent lighting creating a yellow cast, baseboard and outlet plate at edge of frame, mundane corporate interior, slight motion blur from shaky hands, jpeg compression. No cords, no furniture, no text, no watermarks."
- **Alt background:** "Flatbed scan of beige commercial carpet sample, direct contact with scanner glass, perfect even lighting, visible weave texture at 150 DPI, interior design catalog material swatch, clinical and boring, slight moire pattern from the scanner. No cords, no furniture, no text, no watermarks."
- **Alt 2 background:** "Top-down view of plain beige-grey linoleum office floor, flat uniform surface with faint speckle pattern, scuff marks near edges, warm overhead fluorescent cast, mundane and featureless, tileable. No cords, no furniture, no text, no watermarks."
- **Maps to:** Sunday Stroll (#0) but with death walls and a few obstacles.

---

## #8 — SPERM RACE [GEM]
**Reproductive biology. You're the winning sperm. Absorb slower ones. Reach the egg.**
- **Snake = sperm** (smooth trail, white, wiggly). **Food = other sperm** (absorb = grow tail). **Obstacles = immune cells** (white blood cells trying to kill you). **Arena = fallopian tube** (long narrow rectangle, or slight curve). **Food movement = drift** (all swimming same direction).
- **Mechanical hook:** Narrow arena (arena_size 0.5 width) + food that all drifts in one direction. You're swimming upstream through a crowd, grabbing stragglers. The narrow tube makes every turn matter.
- **Movement:** Smooth trail. Fast. High turn speed (wiggle).
- **Win:** Absorb 15.
- **Why it works:** Edgy for a shovelware CD (the kind of game a 12-year-old shows their friend). Mechanically the narrow arena + drifting food creates a unique flow.
- **Background prompt:** "Electron microscope photograph of a biological tube interior, greyscale with false-color pink tint applied in Photoshop, smooth tissue walls, high magnification grain and noise, scientific journal figure quality, scale bar overlay in corner, SEM imaging artifacts. No cells, no sperm, no egg, no text besides scale bar, no watermarks."
- **Alt background:** "Overhead projector transparency from a 1990s high school biology class, hand-drawn diagram of a fallopian tube cross-section in red and blue dry-erase marker on acetate, slightly smudged, warm yellow projector light bleeding through, classroom educational material. No cells, no sperm, no egg, no text labels, no watermarks."
- **Alt 2 background:** "Flat uniform translucent pink fluid surface viewed from above, soft warm organic glow, smooth and featureless like looking into tinted water, faint lighter pink at edges suggesting tubular walls, simple biological interior. No cells, no sperm, no egg, no text, no watermarks."
- **Maps to:** Warp Speed (#19) parameters (smooth, fast, fleeing food) but narrow arena, drifting food instead of fleeing.

---

## #9 — PAPER ROUTE [FILLER]
**Bike delivering newspapers. Route gets longer. Don't crash into anything.**
- **Snake = paper trail** (dotted line showing your delivery route, smooth trail). **Food = houses** (deliver paper = add to route). **Obstacles = dogs, parked cars, garbage cans.** **Arena = neighborhood** (grid streets, wrap walls = looping block).
- **Movement:** Smooth trail. Medium-fast. Wrap walls.
- **Win:** 20 deliveries.
- **Background prompt:** "Google Maps satellite view circa 2001, low resolution aerial photograph of a suburban street grid, pixelated green lawns and grey rooftops, slight color banding from early digital aerial imaging, MapQuest printout quality with inkjet color shifts. No houses in detail, no cars, no people, no text, no watermarks."
- **Alt background:** "Child's crayon drawing of a neighborhood from above, thick waxy strokes on white construction paper, bright green lawns and grey roads drawn with a ruler, houses as simple squares at edges, a six-year-old's birds-eye-view art project, colors going outside the lines. No cars, no people, no text, no watermarks."
- **Alt 2 background:** "Top-down view of a flat suburban street, light grey asphalt with white painted sidewalk edges, bright green grass strips on both sides, simple clean neighborhood road surface, morning sunlight, tileable. No houses, no cars, no people, no text, no watermarks."
- **Maps to:** Conveyor Belt (#14) parameters (wrap, moving obstacles, drifting food) but simplified.

---

## #10 — CRACK [GEM]
**Windshield crack spreading from impact point. Each pebble hit spreads the crack further.**
- **Snake = crack line** (smooth trail, white/light blue on dark glass). **Food = stress points** (tiny impacts on glass). **Phase_through_tail = true** (cracks overlap and branch). **Arena = windshield** (rectangle, death walls = edge of glass = shatter).
- **Mechanical hook:** `phase_through_tail = true` + `girth_growth` so the crack gets WIDER as it spreads. The windshield fills with an increasingly thick web of cracks. Purely visual escalation with the girth mechanic.
- **Movement:** Smooth trail. Medium speed. Medium turning.
- **Win:** 20 stress points.
- **Why it works:** The spreading crack pattern looks exactly like a snake trail with phase-through. The girth widening = crack spreading wider. The visual IS the mechanic.
- **Background prompt:** "Photograph through a car windshield at night, dark tinted glass with rain droplets, blurred oncoming headlights creating bokeh circles, dashboard reflection faintly visible at bottom, shot from the passenger seat with a disposable camera, warm amber streetlight glow diffused through wet glass. No cracks, no damage, no text, no watermarks, no people."
- **Alt background:** "POV-Ray raytraced render of a transparent glass plane, 1997 CGI aesthetic, exaggerated refraction and specular highlights, single light source creating a bright hotspot, smooth unrealistic glass material, visible render artifacts at edges, 3D hobbyist forum showcase quality. No cracks, no damage, no text, no watermarks, no people."
- **Alt 2 background:** "Flat dark tinted glass surface viewed straight on, deep blue-grey transparent plane with faint rain droplet distortion, blurred warm amber light sources visible through the glass, simple uniform windshield interior. No cracks, no damage, no text, no watermarks, no people."
- **Maps to:** Figure Eight (#7) but with girth growth, death walls, more deliberate speed.

---

## #11 — FUSE [GOOD]
**Lit fuse burning toward a bomb. Eat gunpowder piles to keep burning. Hit water and you're out.**
- **Snake = burning fuse line** (smooth trail, orange-red glow, sparks at head). **Food = gunpowder piles** (extend the fuse). **Bad food = water puddles** (shrink/extinguish). **Obstacles = rocks.** **Arena = mine shaft** (dark, narrow, fog of war). **Shrink_over_time = fuse burning down.**
- **Mechanical hook:** `shrink_over_time` means you're always losing length. Must keep eating to stay alive. Combined with fog_of_war for the dark mine shaft.
- **Movement:** Grid or smooth. Medium speed.
- **Win:** Reach length 20 (you never actually explode — the game ends).
- **Why it works:** A fuse IS a growing/shrinking line. The shrink-over-time creates urgency that normal snake doesn't have.
- **Background prompt:** "Still from a 1990s History Channel documentary about mining, interlaced NTSC video frame of a dark mine tunnel interior, warm orange lantern light on rough stone walls, heavy film grain, VHS color bleeding, dark crushed blacks, educational television production values. No equipment, no tracks, no text, no watermarks."
- **Alt background:** "Charcoal drawing on rough brown paper, heavy black strokes depicting a dark mine shaft tunnel, smudged charcoal for shadow depth, raw paper showing through as highlight, white chalk for lantern light pools, fine art student's portfolio piece, dramatic chiaroscuro. No equipment, no tracks, no text, no watermarks."
- **Alt 2 background:** "Top-down view of dark grey-brown rough stone floor, uneven rock surface with scattered coal dust and small gravel, warm orange lantern light pooling in center fading to black at edges, simple mine shaft ground texture. No equipment, no tracks, no text, no watermarks."
- **Maps to:** Quicksand (#18) parameters (shrink_over_time, timed food) + fog_of_war.

---

## #12 — HAIRBALL [FILLER]
**Cat chasing yarn. The yarn ball unravels behind you. Don't get tangled.**
- **Snake = yarn trail** (smooth, red/blue yarn color). **Food = yarn balls** (each one adds more yarn). **Obstacles = furniture.** **Arena = living room floor** (rectangle).
- **Movement:** Smooth trail. Fast. Good turning.
- **Win:** 15 yarn balls.
- **Background prompt:** "Photograph of a living room hardwood floor shot by a cat-cam (camera strapped to a cat), extreme low angle, fisheye lens distortion, motion blur from the cat moving, warm afternoon sun streaking across honey-colored planks, chaotic and blurry, accidental photography aesthetic. No furniture, no pets, no yarn, no text, no watermarks."
- **Alt background:** "Needlepoint cross-stitch pattern on Aida cloth, grid of tiny X stitches in warm brown and honey tones forming a simple hardwood floor texture, visible fabric weave underneath, grandmother's craft project, zoomed in so individual stitches are visible. No furniture, no pets, no yarn, no text, no watermarks."
- **Alt 2 background:** "Top-down view of warm honey-colored hardwood floor planks, simple parallel wood grain pattern, afternoon sunlight casting a single window shadow across the boards, cozy domestic surface, tileable. No furniture, no pets, no yarn, no text, no watermarks."
- **Maps to:** Anaconda (#13) but faster, smaller arena.

---

## #13 — ROOTS [GOOD]
**Tree root growing underground. Find water pockets. Avoid rocks. Dirt everywhere.**
- **Snake = root** (brown, branching feel, smooth trail, slow). **Food = water pockets** (blue dots). **Obstacles = rocks** (dense, lots of them). **Arena = underground cross-section** (brown, large, death walls = bedrock).
- **Mechanical hook:** Slow speed + dense obstacles + large arena. The slow, deliberate navigation through packed earth feels meditative. Each food is precious because getting to it is work.
- **Movement:** Smooth trail. Very slow. Medium turning. Death walls.
- **Win:** 15 water pockets.
- **Why it works:** Roots growing through soil = snake through obstacles. The slowness isn't a gimmick — roots ARE slow. It reframes patience as thematic.
- **Background prompt:** "Geological cross-section from a 1980s earth science textbook, printed diagram showing soil strata layers in muted browns and tans, simplified rock fragments in cross-hatched pen illustration style, visible offset printing dot pattern on matte paper, educational and dry, copyright 1984 Prentice Hall. No roots, no worms, no text labels, no watermarks."
- **Alt background:** "Oil painting of earth and soil, thick impasto brushstrokes in raw umber and burnt sienna, visible palette knife texture for rocks, rich earth tones with occasional ochre highlights, small canvas study quality, warm gallery lighting. No roots, no worms, no text, no watermarks."
- **Alt 2 background:** "Top-down view of dark brown underground soil cross-section, layers of rich topsoil with lighter sandy subsoil visible in horizontal bands, small embedded pebbles and clay fragments, flat geological texture, earthy and uniform. No roots, no worms, no text, no watermarks."
- **Maps to:** Glacier (#9) parameters (very slow, dense obstacles, death walls) but larger arena.

---

## #14 — SNAKE CHARMER [GOOD]
**Bazaar. You're charming a cobra out of a basket. It sways, grows, eats mice.**
- **Snake = cobra** (smooth trail, scales pattern, rising from center). **Food = mice** (scurrying, food_movement = flee). **Obstacles = market stalls, pots.** **Arena = circular bazaar** (circle arena). **AI snake = rival cobra** from another charmer.
- **Movement:** Smooth trail. Medium speed. Circle arena. Fleeing food.
- **Win:** 20 mice.
- **Why it works:** A cobra IS a snake. The fleeing mice create a hunting dynamic. The rival cobra adds tension.
- **Background prompt:** "Travel photograph from a 1990s Lonely Planet guidebook, overhead shot of Moroccan bazaar stone tiles, warm afternoon light, oversaturated Fujifilm Velvia color shift, slight vignetting from a cheap zoom lens, sandy beige tiles with scattered red-orange spice dust, backpacker tourism photography. No people, no baskets, no snakes, no text, no watermarks."
- **Alt background:** "Persian miniature painting style, ornate geometric tile pattern in turquoise and gold leaf, intricate Islamic tessellation, rich lapis lazuli blue and warm saffron, Mughal manuscript border aesthetic, hand-painted on aged parchment. No people, no baskets, no snakes, no text, no watermarks."
- **Alt 2 background:** "Top-down view of sandy beige stone tiles with warm terracotta grout lines, scattered pinches of red-orange spice dust in crevices, flat sun-baked marketplace ground, simple North African bazaar floor texture. No people, no baskets, no snakes, no text, no watermarks."
- **Maps to:** Matador (#3) parameters (smooth, circle, AI opponent, fleeing food) but lower aggression.

---

## #15 — FREEWAY [GEM]
**Rush hour. You're merging into increasingly dense traffic. Your car trail = lane changes.**
- **Snake = car weaving through traffic** (smooth trail, gridlocked highway). **Food = open lane merges** (each merge = longer commitment on road). **Obstacles = other cars** (moving blocks, all going same direction but different speeds). **Arena = highway** (long rectangle, wrap top/bottom = lanes loop).
- **Mechanical hook:** `obstacle_type: moving_blocks` all moving in one direction at varying speeds. You're weaving through a stream. Wrap walls mean you loop lanes. Food spawns in gaps between cars. The "snake" is your path through traffic — phase_through_tail because you're just driving.
- **Movement:** Smooth trail. Fast. Wrap walls.
- **Win:** 15 merges.
- **Why it works:** Weaving through traffic IS snake movement. Everyone's done this driving. The moving-obstacle field with phase-through creates something that feels like Frogger's evolved cousin.
- **Background prompt:** "Dashboard camera footage still frame, wide-angle forward view of a multi-lane highway, flat grey asphalt stretching ahead, white dashed lane lines in perspective, harsh midday sun washing out the sky, low resolution CMOS sensor artifacts, 2001 insurance dashcam quality, timestamp in corner. No cars, no vehicles, no text besides timestamp, no watermarks."
- **Alt background:** "1970s Atari 2600 box art style, airbrush illustration of a highway from above at dramatic angle, oversaturated sunset oranges and purples bleeding into asphalt, Boris Vallejo-adjacent dramatic lighting, painted on board with visible brushwork, the kind of art that makes a bad game look incredible on the shelf. No cars, no vehicles, no text, no watermarks."
- **Alt 2 background:** "Top-down view of multi-lane highway asphalt, flat dark grey surface with white dashed lane markings in parallel rows, simple repeating road texture, harsh flat overhead light, tileable interstate surface. No cars, no vehicles, no text, no watermarks."
- **Maps to:** Bullet Hell (#11) + phase_through_tail, moving obstacles all in one direction.

---

## #16 — RINGWORM [FILLER]
**Skin infection spreading. Absorb skin cells. The ring grows. Gross.**
- **Snake = ringworm circle** (smooth trail, red-pink on skin-colored background). **Food = skin cells.** **Phase_through_tail = true** (the ring overlaps itself as it spreads). **Arena = patch of skin** (circle).
- **Movement:** Smooth trail. Slow. Circle arena.
- **Win:** 15 cells.
- **Why it works:** It's gross. That's the whole pitch. The ring-shaped spreading pattern naturally maps to phase-through snake.
- **Background prompt:** "Dermatology textbook clinical photograph of healthy human skin at macro scale, pinkish-beige with visible pores and fine vellus hair, shot with a medical macro lens under clinical ring light, printed on glossy paper in a 1996 Mosby medical reference, high detail but slightly desaturated from print aging. No rashes, no marks, no text labels, no watermarks."
- **Alt background:** "Electron microscope image of skin surface, greyscale SEM photograph at 500x magnification, dramatic topographic shadows revealing pore structures and epidermal ridges, scientific journal figure with scale bar, false-color tint applied in warm pink. No rashes, no marks, no text besides scale bar, no watermarks."
- **Alt 2 background:** "Flat pinkish-beige skin surface viewed from above, uniform smooth flesh tone with faint pore texture, simple tileable skin-colored background, warm clinical lighting, unsettling in its plainness. No rashes, no marks, no text, no watermarks."
- **Maps to:** Figure Eight (#7) but slow, circle arena.

---

## #17 — DOMINOS [GOOD]
**Setting up a domino chain. Place each one carefully. Knock one over and they all fall.**
- **Snake = domino chain** (grid mode, each segment = a placed domino). **Food = domino box** (grab next piece to place). **Obstacles = already-fallen dominos** (spawning over time, static). **Arena = table** (rectangle, death walls). **Speed increases per food** (you get into a rhythm, then panic).
- **Mechanical hook:** `speed_increase_per_food` + `obstacle_spawn_over_time`. You're placing faster and faster while the table fills with knocked-over pieces. The acceleration turns careful placement into a frantic race.
- **Movement:** Grid mode. Starting slow, accelerating.
- **Win:** 25 dominos placed.
- **Why it works:** Dominos in a line = snake body. The speed escalation matches the "getting into the flow" feeling of real domino setup.
- **Background prompt:** "Close-up photograph of a dark mahogany table surface, overhead tungsten bulb creating a warm central pool of light fading to shadow at edges, visible wood grain and a few ring stains from mugs, shallow depth of field, poker night atmosphere, shot on 35mm Portra 400 with warm tones. No dominos, no objects, no text, no watermarks."
- **Alt background:** "Dutch Golden Age still life painting style, dark vanitas background of rich brown-black oil paint, Rembrandt-esque chiaroscuro lighting illuminating a bare wooden table surface, thick varnish crackling with age, museum reproduction quality. No dominos, no objects, no text, no watermarks."
- **Alt 2 background:** "Top-down view of a dark wooden table surface, rich mahogany wood grain running in parallel lines, warm overhead light creating a bright center fading to dark edges, simple flat tabletop texture, game night atmosphere. No dominos, no objects, no text, no watermarks."
- **Maps to:** Flash Sale (#10) parameters (speed_increase, many food) but grid mode, death walls, obstacle spawn.

---

## #18 — INTESTINE [GOOD]
**Food moving through the digestive tract. Absorb nutrients. Avoid bacteria.**
- **Snake = bolus/food mass** (smooth trail, moving through tube). **Food = nutrients** (vitamins, minerals — colored dots). **Bad food = bacteria** (green, shrinks you). **Obstacles = intestinal valves** (periodic constrictions). **Arena = intestinal tube** (very long, narrow rectangle).
- **Mechanical hook:** Extremely narrow arena. The tube shape means you're always going mostly forward with slight adjustments. Obstacles are periodic chokepoints. Bad food is common.
- **Movement:** Smooth trail. Medium speed. Death walls (don't touch the intestinal lining — acid).
- **Win:** Absorb 18 nutrients.
- **Why it works:** The digestive tract IS a tube with stuff moving through it. The narrow arena creates a unique gameplay feel — like a rail shooter meets snake.
- **Background prompt:** "Frame from a medical endoscopy video recording, circular camera view of pink intestinal walls with villous texture, slight fisheye distortion, harsh white LED illumination, interlaced video artifacts, medical procedure documentation quality, slightly out of focus, VHS recording of a hospital monitor. No food, no bacteria, no text, no watermarks."
- **Alt background:** "Page from Netter's Atlas of Human Anatomy, detailed medical illustration of intestinal cross-section interior, precise watercolor-and-ink rendering in clinical pinks and reds, printed on heavy matte paper, Frank Netter's distinctive hand-painted style, educational and beautiful, copyright notice cropped out. No food, no bacteria, no text labels, no watermarks."
- **Alt 2 background:** "Flat pink-red tubular interior surface viewed from inside, soft villi texture covering the walls like tiny fingers, warm organic glow, uniform biological tube interior, simple intestinal lining surface. No food, no bacteria, no text, no watermarks."
- **Maps to:** Custom narrow variant: arena_size 0.4 height, 1.5 width, smooth, death walls, bad_food_chance 0.4.

---

## #19 — CONSPIRACY [GEM]
**Red string on a corkboard. Connect the clues. The web grows. Don't cross your own lines... unless you're onto something.**
- **Snake = red string** (smooth trail, red on cork-colored background). **Food = photos/clippings** (evidence pinned to board). **Phase_through_tail = false** (you CAN'T cross your own string — that's "contradicting your theory"). **Obstacles = thumbtacks** (static). **Fog_of_war = center** (the "spotlight of focus").
- **Mechanical hook:** The string-on-corkboard visual makes the self-collision rule THEMATIC. In every other snake, self-collision is an arbitrary game rule. Here, crossing your own string means your conspiracy theory contradicts itself. Game over — you've lost the thread.
- **Movement:** Smooth trail. Slow-medium. Death walls (edge of corkboard).
- **Win:** Connect 15 pieces of evidence.
- **Why it works:** This reframes the CORE snake mechanic (self-collision) as narrative. It's not "you ate yourself" — it's "your theory fell apart." Same rule, completely different emotional register.
- **Background prompt:** "Heavily photocopied cork board texture, high contrast black-and-white xerox on cheap office paper, loss of detail in dark areas, toner splotches and streaks, punk zine aesthetic, gritty and paranoid, the kind of photocopy someone slides under your door at 3 AM. No string, no photos, no papers, no text, no watermarks, no pins."
- **Alt background:** "Close-up photograph of a cork bulletin board, warm brown cork texture with dozens of tiny pinholes from removed pushpins, harsh single desk lamp lighting from the left casting deep shadows, noir detective office atmosphere, shot on Tri-X black and white film pushed two stops for grain, printed on fiber-based paper. No string, no photos, no papers, no text, no watermarks, no pins."
- **Alt 2 background:** "Flat warm brown cork surface viewed straight on, uniform cork board texture with scattered tiny pinholes, simple tileable bulletin board background, even office lighting. No string, no photos, no papers, no text, no watermarks, no pins."
- **Maps to:** Panopticon (#6) parameters (fog, death walls, obstacles) but smooth trail, slower.

---

## Summary Table

| # | Name | Theme | Mode | Key Mechanic | Tag |
|---|------|-------|------|-------------|-----|
| 0 | Roadkill | Car + blood trail | Smooth | phase_through_tail | GEM |
| 1 | Ant Farm | Ants carrying sugar | Grid | wrap, simple | GOOD |
| 2 | Conga Line | Dance floor party | Smooth | high growth | GOOD |
| 3 | Train Set | Model train + cargo | Grid | slow, simple | FILLER |
| 4 | Centipede | Bug eating bugs | Grid | dense obstacles | GOOD |
| 5 | Black Ice | Highway pileup on ice | Smooth | low turn, obstacle spawn | GEM |
| 6 | Tapeworm | Parasite in stomach | Smooth | bounce, circle, drift food | GOOD |
| 7 | Power Strip | Extension cord | Grid | death walls | FILLER |
| 8 | Sperm Race | Reproductive biology | Smooth | narrow arena, drift food | GEM |
| 9 | Paper Route | Bike newspaper delivery | Smooth | wrap, moving obstacles | FILLER |
| 10 | Crack | Windshield crack | Smooth | phase_through, girth_growth | GEM |
| 11 | Fuse | Burning fuse in mine | Grid/Smooth | shrink_over_time, fog | GOOD |
| 12 | Hairball | Cat chasing yarn | Smooth | fast, small arena | FILLER |
| 13 | Roots | Tree root underground | Smooth | very slow, dense obstacles | GOOD |
| 14 | Snake Charmer | Cobra eating mice | Smooth | circle, fleeing food, AI | GOOD |
| 15 | Freeway | Rush hour lane weaving | Smooth | moving obstacles, phase | GEM |
| 16 | Ringworm | Skin infection spreading | Smooth | slow, phase_through | FILLER |
| 17 | Dominos | Placing domino chain | Grid | speed_increase, obstacle spawn | GOOD |
| 18 | Intestine | Digestive tract | Smooth | narrow arena, bad food | GOOD |
| 19 | Conspiracy | Red string corkboard | Smooth | fog, self-collision = narrative | GEM |

## Background Art Styles Used

| # | Primary | Alt 1 | Alt 2 (flat surface) |
|---|---------|-------|---------------------|
| 0 | VHS dashcam found footage | GTA1 flat vector top-down | Wet asphalt with lane markings |
| 1 | 35mm macro nature photography | 1970s children's encyclopedia | Sandy brown dirt surface |
| 2 | Disposable camera party snapshot | Microsoft Publisher clip art | Disco floor light tiles |
| 3 | Hobby catalog product photograph | Watercolor miniature landscape | Green baize felt surface |
| 4 | Kodachrome macro ring flash | Atari 2600 screenshot aesthetic | Dark garden soil with wood chips |
| 5 | Helicopter news broadcast still | Bryce 3D CGI raytraced render | Snowy asphalt with ice patches |
| 6 | Medical endoscope textbook photo | Victorian anatomical lithograph | Pink fleshy mucous membrane |
| 7 | 1999 Kodak digital camera snapshot | Flatbed scanner carpet swatch | Beige-grey linoleum floor |
| 8 | Electron microscope SEM false-color | Overhead projector transparency | Translucent pink fluid surface |
| 9 | Early 2000s MapQuest satellite view | Child's crayon drawing | Grey asphalt with sidewalk edges |
| 10 | Disposable camera night driving | POV-Ray glass render | Dark tinted glass with rain drops |
| 11 | History Channel VHS documentary still | Charcoal drawing on brown paper | Dark stone floor with coal dust |
| 12 | Cat-cam fisheye accidental photo | Needlepoint cross-stitch pattern | Honey hardwood floor planks |
| 13 | Earth science textbook offset print | Oil painting impasto study | Brown soil cross-section layers |
| 14 | Lonely Planet travel photography | Persian miniature gold leaf | Sandy stone tiles with spice dust |
| 15 | Insurance dashcam footage | Atari 2600 box art airbrush | Multi-lane highway asphalt |
| 16 | Medical dermatology textbook photo | SEM electron microscope greyscale | Flat pinkish-beige skin surface |
| 17 | 35mm Portra warm tungsten photo | Dutch Golden Age oil painting | Dark mahogany wood grain |
| 18 | Medical endoscopy VHS recording | Netter's anatomical illustration | Pink villi-textured tube interior |
| 19 | High-contrast punk zine photocopy | Noir Tri-X black & white film | Flat cork board with pinholes |
