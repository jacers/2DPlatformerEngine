local Object = require("libraries.classic")

local BaseEntity = Object:extend()

function BaseEntity:new(name, x, y)
    self.name = name or "default"
    self.x    = x or 0
    self.y    = y or 0
end

function BaseEntity:update(dt)
    -- Child classes can override, but can also call BaseEntity.update(self, dt) if needed
end

function BaseEntity:draw()
    -- Child classes override this
end

function BaseEntity:setImage(img)
    self.img    = img
    self.width  = img:getWidth()
    self.height = img:getHeight()
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
