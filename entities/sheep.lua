require("core.constants")

local BaseEntity    = require("entities.entity")
local entityHandler = require("systems.entity_handler")
local Animation     = require("systems.animation")

local Sheep = BaseEntity:extend()

function Sheep:new(x, y)
    BaseEntity.new(self, "Sheep", x, y)

    -- Size + hitbox
    self:setSize(16, 12)
    self:setHitboxSize(self.width, self.height)

    -- Physics + gravity
    self:initPlatformer({ gravity = BASE_GRAVITY })

    -- Movement (unused right now, but leaving since you had it)
    self.speed = 80

    -- Animation
    local imgPath = "assets/images/sheep.png"
    local anim    = self:_buildAnim(imgPath)
    self:setAnim(anim)
    self.anim:play("walk", true)

    -- Facing
    self.facing = 1
end

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

function Sheep:update(dt)
    -- Stay still horizontally
    self.vx = 0

    -- Gravity + collide + grounding + vy reset-on-ground
    self:stepPlatformer(entityHandler, dt)

    -- Always play walking animation
    self.anim:play("walk")

    -- Flip + advance animation timer
    self:updateAnim(dt)
end

return Sheep
