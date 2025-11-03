-- src/constants.lua: Central constants used across the app

local Constants = {}

Constants.state = {
    DESKTOP = 'desktop',
    DEBUG = 'debug',
    COMPLETION = 'completion',
    SCREENSAVER = 'screensaver',
    STATISTICS = 'statistics',
}

-- Virtual filesystem well-known paths
Constants.paths = {
    START_MENU_PROGRAMS = '/My Computer/C:/Windows/System32/Start Menu Programs',
    -- Dynamic roots: folders where runtime edits (delete/move/copy/paste) are allowed
    -- You can customize this list; items can be exact paths (roots) in the VFS
    DYNAMIC_ROOTS = {
        '/My Computer/C:/Windows/System32/Start Menu Programs',
        '/My Computer/C:/Documents',
        -- '/My Computer/Desktop', -- enable when Desktop FS is implemented
    }
}

-- Space Shooter enums (for reference, actual values stored as strings in variants)
Constants.spaceShooter = {
    movementType = {
        DEFAULT = 'default',
        JUMP = 'jump',
        RAIL = 'rail',
        ASTEROIDS = 'asteroids',
    },
    fireMode = {
        MANUAL = 'manual',
        AUTO = 'auto',
        CHARGE = 'charge',
        BURST = 'burst',
    },
    bulletPattern = {
        SINGLE = 'single',
        DOUBLE = 'double',
        TRIPLE = 'triple',
        SPREAD = 'spread',
        SPIRAL = 'spiral',
        WAVE = 'wave',
    },
    enemyFormation = {
        SCATTERED = 'scattered',
        V_FORMATION = 'v_formation',
        WALL = 'wall',
        SPIRAL = 'spiral',
    },
    victoryCondition = {
        KILLS = 'kills',
        TIME = 'time',
        SURVIVAL = 'survival',
        BOSS = 'boss',
    },
    difficultyCurve = {
        LINEAR = 'linear',
        EXPONENTIAL = 'exponential',
        WAVE = 'wave',
    },
}

return Constants
