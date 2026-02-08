SCREEN            = {
    WIDTH = 1280,
    HEIGHT = 720,
    COLOR = { 28 / 255, 3 / 255, 51 / 255, 1 }
}

MAX_FRAME_DT      = 0.1
PHYSICS_STEP      = 1 / 120

EDITOR_MOVE_SPEED = 200

PLAYER            = {
    WIDTH               = 16,
    HEIGHT              = 16,
    WALK_SPEED          = 90,
    RUN_SPEED           = 180,
    ACCEL_GROUND        = 3000,
    ACCEL_AIR           = 1000,
    FRICTION            = 1500,
    GRAVITY             = 3000,
    JUMP_VEL            = 760,
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

DEBUG             = {
    -- Draw player's hitbox in red on top for clarity
    DRAW_PLAYER_HITBOX = false,
    HITBOX_FILL_ALPHA  = 0.15, -- How easy it is to see
}

return true
