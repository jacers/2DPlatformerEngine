require("core.constants")
local P             = PLAYER
local PlayerSkins   = require("systems.player_skins")

local BaseEntity    = require("entities.entity")
local entityHandler = require("systems.entity_handler")
local Animation     = require("systems.animation")
local keyboard      = require("core.input.keyboard")
local gamepad       = require("core.input.gamepad")

local Player        = BaseEntity:extend()

function Player:new(x, y)
    BaseEntity.new(self, "Player", x, y)

    -- Size + hitbox
    self:setSize(P.WIDTH, P.HEIGHT)
    self:setHitboxSize(P.WIDTH, P.HEIGHT)

    -- Physics state + gravity
    self:initPlatformer({ gravity = BASE_GRAVITY })

    -- Movement
    self.walkSpeed     = P.WALK_SPEED
    self.runSpeed      = P.RUN_SPEED
    self.accelGround   = P.ACCEL_GROUND
    self.accelAir      = P.ACCEL_AIR
    self.friction      = P.FRICTION

    -- Gravity / Jump
    self.gravity       = BASE_GRAVITY
    self.jumpVel       = P.JUMP_VEL
    self.fallMult      = P.FALL_MULT
    self.lowJumpMult   = P.LOW_JUMP_MULT

    -- Polish
    self.coyoteTimeMax = P.COYOTE_TIME
    self.jumpBufferMax = P.JUMP_BUFFER
    self.coyoteTime    = 0
    self.jumpBuffer    = 0

    -- Facing
    self.facing        = 1 -- 1 = right, -1 = left

    -- Skin (build animation ONCE)
    local skin         = PlayerSkins.current()
    self.skinId        = skin.id

    local img          = PlayerSkins.currentImage()
    local anim         = self:_buildAnim(img)
    self:setAnim(anim)

    self.anim:play("stand", true)
end

-- Build an Animation from a spritesheet path
function Player:_buildAnim(imageOrPath)
    local anim = Animation.new(imageOrPath, {
        frameW  = 23,
        frameH  = 23,
        border  = 1,
        spacing = 1,
        count   = 12,
        trimTop = 6,
    })

    anim:addClip("stand", { 1 }, 1, false)
    anim:addClip("crouch", { 2 }, 1, false)
    anim:addClip("walk", { 3, 4, 5 }, 10, true)
    anim:addClip("run", { 6, 7, 8 }, 14, true)
    anim:addClip("turn", { 9 }, 1, false)
    anim:addClip("jump_up", { 10 }, 1, false)
    anim:addClip("jump_down", { 11 }, 1, false)
    anim:addClip("look_up", { 12 }, 1, false)

    return anim
end

function Player:setSkinByIndex(i)
    local prevFlip = self.anim and self.anim.flipX or false
    local prevClip = self.anim and self.anim.currentClipName or "stand"

    local skin     = PlayerSkins.setIndex(i)
    self.skinId    = skin.id

    local img      = PlayerSkins.currentImage()

    if not self.anim then
        self:setAnim(self:_buildAnim(img))
    else
        self.anim:setImage(img)
    end

    self.anim.flipX = prevFlip
    self.anim:play(prevClip, true)
end

function Player:cycleSkin(dir)
    local skin = PlayerSkins.cycle(dir or 1)
    self:setSkinByIndex(PlayerSkins.index)
    return skin
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
    local move     = 0

    -- Vertical intent (Mario behavior)
    local upHeld   = keyboard.actionDown("up") or gamepad.down("up")
    local downHeld = keyboard.actionDown("down") or gamepad.down("down")

    -- Raw horizontal intent (used for facing, even if movement is locked)
    local rawX     = 0

    -- Prefer analog stick if present
    local axisX    = gamepad.moveX()
    if math.abs(axisX) > 0 then
        rawX = axisX
    else
        -- Keyboard fallback
        if keyboard.pressed("left") then rawX = rawX - 1 end
        if keyboard.pressed("right") then rawX = rawX + 1 end

        -- Gamepad D-pad fallback
        if gamepad.down("left") then rawX = rawX - 1 end
        if gamepad.down("right") then rawX = rawX + 1 end
    end

    -- Movement locks:
    --  - Holding UP locks movement AND facing (look up)
    --  - Holding DOWN locks movement ONLY (crouch-turn is allowed)
    local lockMove   = self.onGround and (upHeld or downHeld)
    local lockFacing = self.onGround and upHeld

    -- Apply movement only if not locked
    if not lockMove then
        move = rawX
    else
        move = 0
    end

    local runHeld     = keyboard.pressed("run") or gamepad.down("run")
    local holdingJump = keyboard.pressed("jump") or gamepad.down("jump")

    local targetMax   = runHeld and self.runSpeed or self.walkSpeed
    local accel       = self.onGround and self.accelGround or self.accelAir

    -- Turnaround / skid check (compute early so we can affect physics)
    local turning     = false
    if self.onGround and runHeld and not lockMove then
        if (move < -0.2 and self.vx > 60) or (move > 0.2 and self.vx < -60) then
            turning = true
        end
    end

    -- Horizontal accel / friction
    if move ~= 0 and not turning and not lockMove then
        self.vx = self.vx + move * accel * dt
        self.vx = math.max(-targetMax, math.min(self.vx, targetMax))
    else
        if self.onGround then
            local friction = self.friction

            -- Less = more slide when holding up/down
            if lockMove then
                friction = friction * 0.25
            end

            -- Less = more sliding when turning
            if turning then
                friction = friction * 0.3
            end

            self.vx = approach(self.vx, 0, friction * dt)
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

    -- Animation selection (Mario-esque)

    -- Facing (stable; avoids flip jitter/teleport)
    if not lockFacing then
        local intentDead = 0.35 -- helps prevent tiny stick noise pops

        -- Prefer input intent for crouch-turn + immediate direction changes
        if rawX < -intentDead then
            self.facing = -1
        elseif rawX > intentDead then
            self.facing = 1
        else
            -- If no strong intent, fall back to velocity when actually moving
            if self.vx < -20 then
                self.facing = -1
            elseif self.vx > 20 then
                self.facing = 1
            end
        end
    end

    self.anim.flipX = (self.facing == -1)

    -- State priority
    if not self.onGround then
        if self.vy < 0 then
            self.anim:play("jump_up")
        else
            self.anim:play("jump_down")
        end
    elseif downHeld then
        self.anim:play("crouch")
    elseif upHeld then
        self.anim:play("look_up")
    elseif turning then
        self.anim:play("turn")
    else
        local speed = math.abs(self.vx)
        if speed < 5 then
            self.anim:play("stand")
        elseif runHeld then
            self.anim:play("run")
        else
            self.anim:play("walk")
        end
    end

    -- Flip + advance animation timer
    self:updateAnim(dt)
end

-- Call this from love.keypressed (or when jump is pressed once)
function Player:queueJump()
    self.jumpBuffer = self.jumpBufferMax
end

return Player
