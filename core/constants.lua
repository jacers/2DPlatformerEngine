TILE_LENGTH  = 16 -- Length of a square tile in pixels

SCREEN       = {
    WIDTH = 1280,
    HEIGHT = 720,
    COLOR = { 28 / 255, 3 / 255, 51 / 255, 1 }
}

MAX_FRAME_DT = 0.1
PHYSICS_STEP = 1 / 120

BASE_GRAVITY = 3100

PLAYER       = {
    WIDTH               = 16,
    HEIGHT              = 16,
    WALK_SPEED          = 90,
    RUN_SPEED           = 180,
    ACCEL_GROUND        = 3000,
    ACCEL_AIR           = 1000,
    FRICTION            = 1500,
    JUMP_VEL            = 800,
    FALL_MULT           = 1.35,
    LOW_JUMP_MULT       = 1.8,
    COYOTE_TIME         = 0.10,
    JUMP_BUFFER         = 0.10,

    -- Hitbox knobs:
    -- If true, collisions use a hitbox based on the sprite frame,
    -- inset by HITBOX_INSET on left/right/top only (bottom unchanged).
    TIGHT_SPRITE_HITBOX = true,
    HITBOX_INSET        = 1,
}

CAMERA       = {
    DEFAULT_ZOOM     = SCREEN.WIDTH / (24 * TILE_LENGTH), -- Constant = tiles wide
    MIN_ZOOM         = 0.75,
    MAX_ZOOM         = 6.0,

    FOLLOW_SMOOTHING = 30,

    LOOK             = {
        MAX_X = 96,
        MAX_Y = 64,
        DEADZONE = 0.25,
        SMOOTHING = 40,
        REUTRN_SMOOTHING = 95,
        SNAP_EPSILON = 2.0,
    },

    ZOOM             = {
        AMOUNT = 0.35,
        SMOOTHING = 14,
    },

    VERTICAL         = {
        DEADZONE_FRAC = 0.3,  -- size of deadzone as fraction of viewport height (0.25 = 25%)
        BIAS_FRAC     = 0.05, -- shifts deadzone slightly downward so you see more above (optional)
        MAX_STEP      = 220,  -- max pixels/sec camera can correct vertically (prevents drastic jumps)
        SMOOTHING     = 8,    -- vertical follow smoothing (lower = looser)
    }
}

DEBUG        = {
    -- Draw entity's hitbox in red on top for clarity
    HITBOX_FILL_ALPHA  = 0.15, -- How easy it is to see
}

return true
