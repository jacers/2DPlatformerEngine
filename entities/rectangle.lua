local BaseEntity = require("entities.entity")

local Rectangle = BaseEntity:extend()

function Rectangle:new(x, y, width, height, speed)
    BaseEntity.new(self, "Rectangle", x, y)

    self.width  = width or 200
    self.height = height or 150
    self.solid  = true --- Make this geometry!
end

function Rectangle:update(dt)
    -- Rectangle-specific logic
end

function Rectangle:draw()
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
end

return Rectangle
