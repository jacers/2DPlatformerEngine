require("core.constants")
local BaseEntity    = require("entities.entity")
local entityHandler = require("systems.entity_handler")
local Animation     = require("systems.animation")

local Sheep         = BaseEntity:extend()

function Sheep:new(x, y)
    BaseEntity.new(self, "Sheep", x, y)

    -- Size
    self.width    = 16
    self.height   = 12

    -- Physics state
    self.vx            = 0
    self.vy            = 0
    self.onGround      = false

    -- Default hitbox size
    self.baseHitW = self.width
    self.baseHitH = self.height

    -- Physics state
    self.vx       = 0
    self.vy       = 0
    self.onGround = false

    -- Gravity
    self.gravity = BASE_GRAVITY

    -- Movement
    self.speed    = 80

    -- Animation
    local imgPath = "assets/images/sheep.png"
    self.anim     = self:_buildAnim(imgPath)
    self.anim:play("walk", true)

    -- Facing
    self.facing = 1 -- 1 = right, -1 = left
end

-- Build an Animation from a spritesheet path
function Sheep:_buildAnim(imageOrPath)
    local anim = Animation.new(imageOrPath, {
        frameW  = 16,
        frameH  = 13,
        border  = 1,
        spacing = 1,
        count   = 3,
        trimTop = 0,
    })

    anim:addClip("walk", { 1, 2, 3 }, 5, true)

    return anim
end

-- Returns the collision hitbox AABB:
--  - if PLAYER.TIGHT_SPRITE_HITBOX is true:
--      left/right/top inset by HITBOX_INSET, bottom unchanged
--  - else: uses PLAYER.WIDTH/HEIGHT centered at sprite bottom
function Sheep:getHitbox()
    -- Mario-esc hitbox anchored to sprite bottom-center
    local hx = self.x + (self.width - self.baseHitW) / 2
    local hy = self.y + (self.height - self.baseHitH)
    return hx, hy, self.baseHitW, self.baseHitH
end

function Sheep:update(dt)
    -- Stay still horizontally
    self.vx = 0

    -- Gravity (fall)
    self.vy = self.vy + self.gravity * dt

    -- Move and collide
    local hit = entityHandler.movePlatformer(self, self.vx * dt, self.vy * dt)

    -- Raw horizontal intent (used for facing, even if movement is locked)
    local rawX     = 0


    -- Grounding
    self.onGround = hit.ground
    if self.onGround and self.vy > 0 then
        self.vy = 0
    end

    -- Animation selection (Mario-esque)
    self.anim.flipX = (self.facing == -1)

    -- Always play walking animation
    self.anim:play("walk")
    self.anim:update(dt)
end

function Sheep:draw()
    local ox = self.anim.frameW / 2
    local oy = self.anim.frameH - 1 -- bottom of sprite frame

    -- Draw at bottom-center of hitbox
    self.anim:draw(
        self.x + self.width / 2,
        self.y + self.height,
        0, 1, 1,
        ox, oy
    )

    -- Debug hitbox overlay (red, drawn last/on top)
    if DEBUG and DEBUG.DRAW_ENTITY_HITBOX then
        local hx, hy, hw, hh = self:getHitbox()

        -- Filled
        local a = (DEBUG.HITBOX_FILL_ALPHA or 0.0)
        if a > 0 then
            love.graphics.setColor(1, 0, 0, a)
            love.graphics.rectangle("fill", hx, hy, hw, hh)
        end

        -- Outline
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.rectangle("line", hx, hy, hw, hh)

        love.graphics.setColor(1, 1, 1, 1)
    end
end

return Sheep
