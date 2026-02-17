require("core.constants")

local Object = require("libraries.classic")
local keyboard = require("core.input.keyboard")
local gamepad = require("core.input.gamepad")

local BaseEntity = Object:extend()

-- Debug (shared across all entities)
BaseEntity.debugHitboxes = false

function BaseEntity:new(name, x, y)
    self.name     = name or "default"
    self.x        = x or 0
    self.y        = y or 0

    -- Size / hitbox defaults
    self.width    = self.width or 0
    self.height   = self.height or 0

    -- Physics state
    self.vx       = 0
    self.vy       = 0
    self.onGround = false

    -- Default hitbox size
    self.baseHitW = self.baseHitW or self.width
    self.baseHitH = self.baseHitH or self.height

    -- Facing (1 = right, -1 = left)
    self.facing   = self.facing or 1

    -- Animation holder
    self.anim     = nil
end

function BaseEntity:setSize(w, h)
    self.width  = w
    self.height = h

    -- If hitbox not set yet, default to size
    if not self.baseHitW or self.baseHitW == 0 then self.baseHitW = w end
    if not self.baseHitH or self.baseHitH == 0 then self.baseHitH = h end
end

function BaseEntity:setHitboxSize(w, h)
    self.baseHitW = w
    self.baseHitH = h
end

-- For platformer physics
function BaseEntity:initPlatformer(opts)
    opts          = opts or {}

    self.vx       = opts.vx or self.vx or 0
    self.vy       = opts.vy or self.vy or 0
    self.onGround = opts.onGround or self.onGround or false

    self.gravity  = opts.gravity or self.gravity or 0
end

function BaseEntity:setAnim(anim)
    self.anim = anim
end

-- Default hitbox: bottom-center anchored (Mario-esque)
-- For tight inset hitbox, set:
--   self.tightHitbox = true
--   self.hitboxInset = <number>
function BaseEntity:getHitbox()
    if self.tightHitbox then
        local inset = self.hitboxInset or 1
        local hx = self.x + inset
        local hy = self.y + inset
        local hw = self.width - inset * 2
        local hh = self.height - inset
        return hx, hy, hw, hh
    end

    local hx = self.x + (self.width - self.baseHitW) / 2
    local hy = self.y + (self.height - self.baseHitH)
    return hx, hy, self.baseHitW, self.baseHitH
end

function BaseEntity:update(dt)
    local activate_debug = keyboard.pressed("debug") or gamepad.down("debug")
    if activate_debug then self.debug = not self.debug end
    -- Child classes can override
end

-- Gravity + move + ground resolve in one place.
-- Returns hit table from entityHandler.movePlatformer
function BaseEntity:stepPlatformer(entityHandler, dt)
    if self.gravity and self.gravity ~= 0 then
        self.vy = self.vy + self.gravity * dt
    end

    local hit = entityHandler.movePlatformer(self, self.vx * dt, self.vy * dt)

    self.onGround = hit.ground

    -- Typical “stop falling velocity when grounded”
    if self.onGround and self.vy > 0 then
        self.vy = 0
    end

    return hit
end

function BaseEntity:updateAnim(dt)
    if not self.anim then return end
    self.anim.flipX = (self.facing == -1)
    self.anim:update(dt)
end

function BaseEntity:drawSpriteBottomCenter()
    if not self.anim then return end

    local ox = self.anim.frameW / 2
    local oy = self.anim.frameH - 1

    self.anim:draw(
        self.x + self.width / 2,
        self.y + self.height,
        0, 1, 1,
        ox, oy
    )
end

function BaseEntity:drawDebugHitbox()
    if not BaseEntity.debugHitboxes then return end

    local hx, hy, hw, hh = self:getHitbox()

    local a = (DEBUG.HITBOX_FILL_ALPHA or 0.0)
    if a > 0 then
        love.graphics.setColor(1, 0, 0, a)
        love.graphics.rectangle("fill", hx, hy, hw, hh)
    end

    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("line", hx, hy, hw, hh)
    love.graphics.setColor(1, 1, 1, 1)
end

function BaseEntity:draw()
    self:drawSpriteBottomCenter()
    self:drawDebugHitbox()
end

function BaseEntity:containsPoint(px, py)
    if not self.width or not self.height then
        return false
    end

    return
        px >= self.x and
        px <= self.x + self.width and
        py >= self.y and
        py <= self.y + self.height
end

function BaseEntity:destroy()
    self.dead = true
end

return BaseEntity
