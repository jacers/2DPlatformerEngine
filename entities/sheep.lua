local BaseEntity = require("entities.entity")

local Sheep = BaseEntity:extend()

function Sheep:new(x, y)
    BaseEntity.new(self, "Sheep", x, y)
    self:setImage(love.graphics.newImage("images/sheep.png"))
end

function Sheep:update(dt)
    -- Custom sheep logic
end

function Sheep:draw()
    love.graphics.draw(self.img, self.x, self.y)
end

return Sheep
