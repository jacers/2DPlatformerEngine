require("helpers.constants")
local P = PLAYER

local BaseEntity    = require("entities.entity")
local entityHandler = require("helpers.entity_handler")
local keyboard      = require("helpers.controls.keyboard")
local gamepad       = require("helpers.controls.gamepad")

local Player = BaseEntity:extend()

function Player:new(x, y)
    BaseEntity.new(self, "Player", x, y)

    -- Size (no sprite yet)
    self.width         = P.WIDTH
    self.height        = P.HEIGHT -- Mario-sized!

    -- Physics state
    self.vx            = 0
    self.vy            = 0
    self.onGround      = false

    -- Movement
    self.walkSpeed     = P.WALK_SPEED
    self.runSpeed      = P.RUN_SPEED
    self.accelGround   = P.ACCEL_GROUND
    self.accelAir      = P.ACCEL_AIR
    self.friction      = P.FRICTION

    -- Gravity / Jump
    self.gravity       = P.GRAVITY
    self.jumpVel       = P.JUMP_VEL
    self.fallMult      = P.FALL_MULT     -- Faster fall than rise
    self.lowJumpMult   = P.LOW_JUMP_MULT -- Short hop when you release jump early

    -- Polish
    self.coyoteTimeMax = P.COYOTE_TIME
    self.jumpBufferMax = P.JUMP_BUFFER
    self.coyoteTime    = 0
    self.jumpBuffer    = 0
end

local function approach(v, target, amount)
    if v < target then
        return math.min(v + amount, target)
    elseif v > target then
        return math.max(v - amount, target)
    end
    return v
end

function Player:update(dt)
    -- Input
    local move = 0

    -- Prefer analog stick if present
    local axisX = gamepad.moveX()
    if math.abs(axisX) > 0 then
        move = axisX
    else
        if keyboard.pressed("left")  then move = move - 1 end
        if keyboard.pressed("right") then move = move + 1 end
    end

    local runHeld     = keyboard.pressed("run")  or gamepad.down("run")
    local holdingJump = keyboard.pressed("jump") or gamepad.down("jump")

    local targetMax = runHeld and self.runSpeed or self.walkSpeed
    local accel     = self.onGround and self.accelGround or self.accelAir

    -- Horizontal accel / friction (reduced air braking)
    if move ~= 0 then
        self.vx = self.vx + move * accel * dt
        self.vx = math.max(-targetMax, math.min(self.vx, targetMax))
    else
        if self.onGround then
            self.vx = approach(self.vx, 0, self.friction * dt)
        end
    end

    -- Variable jump gravity (Mario-like)
    local g = self.gravity
    if self.vy > 0 then
        g = g * self.fallMult
    elseif self.vy < 0 and not holdingJump then
        g = g * self.lowJumpMult
    end
    self.vy = self.vy + g * dt

    -- Integrate + resolve collisions
    local hit = entityHandler.movePlatformer(self, self.vx * dt, self.vy * dt)

    -- Grounding + coyote timer
    self.onGround = hit.ground
    if self.onGround then
        self.coyoteTime = self.coyoteTimeMax
    else
        self.coyoteTime = math.max(0, self.coyoteTime - dt)
    end

    -- Jump buffer countdown
    self.jumpBuffer = math.max(0, self.jumpBuffer - dt)

    -- Execute buffered jump if allowed (buffer + coyote)
    if self.jumpBuffer > 0 and self.coyoteTime > 0 then
        self.vy = -self.jumpVel
        self.onGround = false
        self.jumpBuffer = 0
        self.coyoteTime = 0
    end
end

-- Call this from love.keypressed (or when jump is pressed once)
function Player:queueJump()
    self.jumpBuffer = self.jumpBufferMax
end

function Player:draw()
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
end

return Player
