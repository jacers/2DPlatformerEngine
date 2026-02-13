local Rectangle = require("entities.rectangle")
local Player    = require("entities.player")

local level01 = {}

function level01.spawn(entityHandler)
    -- Define level bounds (world space)
    local bounds = { x = 0, y = 0, w = 2400, h = 720 } -- wider than screen

    -- Ground + platforms
    entityHandler.spawn(Rectangle(0, 680, bounds.w, 40))
    entityHandler.spawn(Rectangle(220, 520, 220, 32))
    entityHandler.spawn(Rectangle(520, 440, 220, 32))
    entityHandler.spawn(Rectangle(820, 360, 220, 32))
    entityHandler.spawn(Rectangle(1200, 520, 260, 32))
    entityHandler.spawn(Rectangle(1600, 480, 220, 32))

    local player = Player(80, 200)
    entityHandler.spawn(player)

    return {
        player = player,
        bounds = bounds,
        name = "Level 01",
    }
end

return level01
