local BaseEntity = require("entities.entity")
local entityHandler = require("helpers.entity_handler")
local keyboard = require("helpers.keyboard")

local Player = BaseEntity:extend()

function Player:new(x, y)
    BaseEntity.new(self, "Player", x, y)

    -- Size (no sprite yet)
    self.width    = 16
    self.height   = 16 -- Mario-sized!

    -- Physics state
    self.vx       = 0
    self.vy       = 0
    self.onGround = false

    -- Tuning
    self.accel    = 2200
    self.maxSpeed = 260
    self.friction = 1800
    self.gravity  = 2200
    self.jumpVel  = 720
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
    if keyboard.pressed("left") then move = move - 1 end
    if keyboard.pressed("right") then move = move + 1 end

    -- Horizontal accel / friction
    if move ~= 0 then
        self.vx = self.vx + move * self.accel * dt
        self.vx = math.max(-self.maxSpeed, math.min(self.vx, self.maxSpeed))
    else
        self.vx = approach(self.vx, 0, self.friction * dt)
    end

    -- Gravity
    self.vy = self.vy + self.gravity * dt

    -- Integrate + resolve collisions
    local hit = entityHandler.movePlatformer(
        self,
        self.vx * dt,
        self.vy * dt
    )

    self.onGround = hit.ground
end

function Player:jump()
    if self.onGround then
        self.vy = -self.jumpVel
        self.onGround = false
    end
end

function Player:draw()
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
end

return Player
