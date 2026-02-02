# Pac-Man Ghost AI Reference

Source: https://github.com/alexjamesmacpherson/pacman (BSD-3-Clause)

This document contains the core logic from a C++ Pac-Man implementation for porting to Lua/LOVE2D.

---

## Type Definitions (types.h)

```cpp
// Tile types
typedef enum { W, G, P, e, o, E, O, b, F } tile;
// W = Wall, G = Gate, P = Portal, e = Empty, o = Pill
// E = Eaten pill spot, O = Big pill, b = Eaten big pill, F = Fruit

// Directions
typedef enum { NONE, UP, RIGHT, DOWN, LEFT } direction;

// Ghost colors (each has unique AI)
typedef enum { RED, PINK, BLUE, YELLOW } colour;

// Ghost movement modes
typedef enum { CHASE, SCATTER, FRIGHTENED, DEAD, LEAVE, SPAWN } movement;

// Game states
typedef enum { READY, PLAY, FRUIT, EAT, PAUSE, DEATH, GAMEOVER } gamemode;
```

---

## Map Structure (map.h)

The classic Pac-Man map is 28x31 tiles:

```cpp
tile map[28][31];  // [x][y] grid

// Key functions
tile getTile(int x, int y) { return map[x][y]; }
void setTile(int x, int y, tile t) { map[x][y] = t; }

bool isImpassible(tile t) {
    return (t == W || t == G);  // Walls and gates block movement
}
```

### Classic Map Layout (simplified representation)
```
WWWWWWWWWWWWWWWWWWWWWWWWWWWW
Wo...........WW...........oW
W.WWWW.WWWWW.WW.WWWWW.WWWW.W
WOWWWW.WWWWW.WW.WWWWW.WWWWO W
W.WWWW.WWWWW.WW.WWWWW.WWWW.W
W..........................W
W.WWWW.WW.WWWWWWWW.WW.WWWW.W
W.WWWW.WW.WWWWWWWW.WW.WWWW.W
W......WW....WW....WW......W
WWWWWW.WWWWW WW WWWWW.WWWWWW
     W.WWWWW WW WWWWW.W
     W.WW          WW.W
     W.WW WGG--GGW WW.W      <- Ghost house with gate
WWWWWW.WW Wnnnnnn W WW.WWWWWW
P     .   Wnnnnnn W   .     P  <- Portals on sides
WWWWWW.WW Wnnnnnn W WW.WWWWWW
     W.WW WWWWWWWW WW.W
     W.WW          WW.W
     W.WW WWWWWWWW WW.W
WWWWWW.WW WWWWWWWW WW.WWWWWW
W............WW............W
W.WWWW.WWWWW.WW.WWWWW.WWWW.W
W.WWWW.WWWWW.WW.WWWWW.WWWW.W
WO..WW................WW..OW  <- Big pills in corners
WWW.WW.WW.WWWWWWWW.WW.WW.WWW
WWW.WW.WW.WWWWWWWW.WW.WW.WWW
W......WW....WW....WW......W
W.WWWWWWWWWW.WW.WWWWWWWWWW.W
W.WWWWWWWWWW.WW.WWWWWWWWWW.W
W..........................W
WWWWWWWWWWWWWWWWWWWWWWWWWWWW
```

---

## Ghost AI (ghosts.h)

### Core Targeting Algorithm

All ghosts use the same decision-making at junctions - they pick the direction that minimizes Euclidean distance to their target tile:

```cpp
float distanceBetween(vector<int> p1, vector<int> p2) {
    float d_x = p1[0] - p2[0];
    float d_y = p1[1] - p2[1];
    return sqrt((d_x * d_x) + (d_y * d_y));
}

direction targetTile(vector<int> target) {
    vector<int> next_pos;
    float distance = 999;
    direction newDir;

    // Check each direction (priority: UP, LEFT, DOWN, RIGHT when tied)
    // Ghosts cannot reverse direction (except on mode change)

    // UP
    if (dir != DOWN && !isImpassible(getNextTile(UP))) {
        next_pos = {getX(), getY() + 1};
        float d = distanceBetween(next_pos, target);
        if (d < distance) {
            distance = d;
            newDir = UP;
        }
    }

    // LEFT
    if (dir != RIGHT && !isImpassible(getNextTile(LEFT))) {
        next_pos = {getX() - 1, getY()};
        float d = distanceBetween(next_pos, target);
        if (d < distance) {
            distance = d;
            newDir = LEFT;
        }
    }

    // DOWN
    if (dir != UP && !isImpassible(getNextTile(DOWN))) {
        next_pos = {getX(), getY() - 1};
        float d = distanceBetween(next_pos, target);
        if (d < distance) {
            distance = d;
            newDir = DOWN;
        }
    }

    // RIGHT
    if (dir != LEFT && !isImpassible(getNextTile(RIGHT))) {
        next_pos = {getX() + 1, getY()};
        float d = distanceBetween(next_pos, target);
        if (d < distance) {
            distance = d;
            newDir = RIGHT;
        }
    }

    return newDir;
}
```

### Individual Ghost Behaviors

```cpp
// Helper: get tile N spaces ahead of Pac-Man
vector<int> targetPacmanOffsetBy(int offset) {
    vector<int> target = {pacman.getX(), pacman.getY()};
    switch(pacman.getDirection()) {
        case UP:    target[1] += offset; break;
        case DOWN:  target[1] -= offset; break;
        case LEFT:  target[0] -= offset; break;
        case RIGHT: target[0] += offset; break;
    }
    return target;
}

void aiChase(Ghost redGhost) {
    // Default target: Pac-Man's current position
    vector<int> target = {pacman.getX(), pacman.getY()};
    vector<int> current_pos = {getX(), getY()};
    int d_x, d_y;

    switch(colour) {
        case RED:
            // RED (Blinky): Direct chase - target Pac-Man directly
            // target already set to pacman position
            break;

        case PINK:
            // PINK (Pinky): Ambush - target 4 tiles AHEAD of Pac-Man
            target = targetPacmanOffsetBy(4);
            break;

        case BLUE:
            // BLUE (Inky): Unpredictable - uses RED's position
            // 1. Get position 2 tiles ahead of Pac-Man
            // 2. Draw vector from RED to that point
            // 3. Double the vector for final target
            target = targetPacmanOffsetBy(2);
            d_x = target[0] - redGhost.getX();
            d_y = target[1] - redGhost.getY();
            target = {redGhost.getX() + 2*d_x, redGhost.getY() + 2*d_y};
            break;

        case YELLOW:
            // YELLOW (Clyde): Shy - chases until close, then flees
            // If within 8 tiles of Pac-Man, target corner instead
            if (distanceBetween(current_pos, target) <= 8) {
                target = {0, -2};  // Bottom-left corner
            }
            break;
    }

    dir = targetTile(target);
    setSpeed(100);
}
```

### Scatter Mode (Ghosts target corners)

```cpp
void aiScatter() {
    vector<int> target;

    switch(colour) {
        case RED:    target = {25, 32}; break;  // Top-right
        case PINK:   target = {2, 32};  break;  // Top-left
        case BLUE:   target = {27, -2}; break;  // Bottom-right
        case YELLOW: target = {0, -2};  break;  // Bottom-left
    }

    dir = targetTile(target);
    setSpeed(100);
}
```

### Frightened Mode (Random movement)

```cpp
void aiFrightened() {
    // Pick random valid direction (can't reverse)
    vector<direction> validDirs;

    if (dir != DOWN && !isImpassible(getNextTile(UP)))
        validDirs.push_back(UP);
    if (dir != RIGHT && !isImpassible(getNextTile(LEFT)))
        validDirs.push_back(LEFT);
    if (dir != UP && !isImpassible(getNextTile(DOWN)))
        validDirs.push_back(DOWN);
    if (dir != LEFT && !isImpassible(getNextTile(RIGHT)))
        validDirs.push_back(RIGHT);

    if (!validDirs.empty()) {
        dir = validDirs[rand() % validDirs.size()];
    }

    setSpeed(50);  // Half speed when frightened
}
```

### Wave System (Alternating SCATTER/CHASE)

```cpp
void aiWave() {
    // Level-based timing for scatter/chase waves
    // Early levels: more scatter, less chase
    // Later levels: mostly chase

    int wave_times[8];  // Timing thresholds

    if (level == 1) {
        wave_times = {420, 1620, 2040, 3240, 3660, 4860, 5280, 5281};
    } else if (level < 5) {
        wave_times = {420, 1620, 2040, 3240, 3660, 4860, 5280, 5281};
    } else {
        wave_times = {300, 1500, 1920, 3120, 3540, 3542, 3543, 3544};
    }

    // Determine current wave based on ticks
    for (int i = 0; i < 8; i++) {
        if (ticks < wave_times[i]) {
            if (i % 2 == 0) {
                mov = SCATTER;
            } else {
                mov = CHASE;
            }
            break;
        }
    }
}
```

---

## Pac-Man Movement (pacman.h)

```cpp
void move() {
    // Check if requested direction is valid
    if (atTileCenter()) {
        tile nextTile = getNextTile(requestedDir);
        if (!isImpassible(nextTile)) {
            dir = requestedDir;
        }
    }

    // Move in current direction
    switch(dir) {
        case UP:    y += speed; break;
        case DOWN:  y -= speed; break;
        case LEFT:  x -= speed; break;
        case RIGHT: x += speed; break;
    }

    // Portal wrapping
    if (x < 0) x = 27;
    if (x > 27) x = 0;
}

void eat() {
    tile current = getTile(getX(), getY());

    if (current == o) {  // Regular pill
        setTile(getX(), getY(), E);
        score += 10;
        pillsLeft--;
    }
    else if (current == O) {  // Power pill
        setTile(getX(), getY(), b);
        score += 50;
        pillsLeft--;
        // Trigger FRIGHTENED mode for all ghosts
        for (int i = 0; i < 4; i++) {
            ghosts[i].frighten();
        }
    }
    else if (current == F) {  // Fruit
        setTile(getX(), getY(), E);
        score += fruitScore[level];
    }
}
```

---

## Scoring Constants (globals.h)

```cpp
// Pills
const int PILL_SCORE = 10;
const int POWER_PILL_SCORE = 50;

// Ghost eating (doubles each ghost in sequence)
// 200 -> 400 -> 800 -> 1600
int ghostScore = 200 * pow(2, ghostsEaten);  // max ghostsEaten = 3

// Fruit (by level)
int fruitScore[] = {
    100,   // Cherry (level 1)
    300,   // Strawberry (level 2)
    500,   // Orange (level 3-4)
    700,   // Apple (level 5-6)
    1000,  // Melon (level 7-8)
    2000,  // Galaxian (level 9-10)
    3000,  // Bell (level 11-12)
    5000   // Key (level 13+)
};

// Extra life at 10,000 points
const int EXTRA_LIFE_THRESHOLD = 10000;

// Total pills in standard map
const int TOTAL_PILLS = 244;
```

---

## Collision Detection (globals.h)

```cpp
void checkCollisions() {
    for (int i = 0; i < 4; i++) {
        Ghost& ghost = ghosts[i];

        // Check if Pac-Man and ghost occupy same tile
        if (pacman.getX() == ghost.getX() &&
            pacman.getY() == ghost.getY()) {

            if (ghost.getMovement() == FRIGHTENED) {
                // Eat the ghost
                ghost.kill();  // Sets to DEAD mode
                score += 200 * pow(2, ghostsEaten);
                ghostsEaten++;
                mode = EAT;  // Brief pause to show score
            }
            else if (ghost.getMovement() != DEAD) {
                // Pac-Man dies
                lives--;
                mode = DEATH;
            }
        }
    }
}
```

---

## Speed Values

```cpp
// Base speeds (pixels per frame at 30fps)
const float PACMAN_SPEED = 0.11;      // ~80% of tile per second
const float GHOST_NORMAL_SPEED = 0.1;  // Slightly slower
const float GHOST_FRIGHTENED_SPEED = 0.05;  // Half speed
const float GHOST_DEAD_SPEED = 0.2;   // Double speed returning home

// Tunnel slow-down zones
const float TUNNEL_SPEED = 0.05;      // Ghosts slow in tunnels
```

---

## Summary: What Makes Each Ghost Unique

| Ghost | Name | Chase Behavior | Scatter Corner | Personality |
|-------|------|----------------|----------------|-------------|
| RED | Blinky | Direct pursuit of Pac-Man | Top-right | Aggressive |
| PINK | Pinky | 4 tiles ahead of Pac-Man | Top-left | Ambusher |
| BLUE | Inky | Vector from Red, doubled | Bottom-right | Unpredictable |
| YELLOW | Clyde | Chase until <8 tiles, then flee | Bottom-left | Shy/Random |

The combination creates emergent behavior:
- Blinky pushes from behind
- Pinky cuts off escape routes
- Inky flanks unpredictably
- Clyde adds chaos but gives breathing room
