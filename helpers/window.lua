require("helpers.constants")
local S = SCREEN

local window   = {}

-- Virtual resolution
window.width   = S.WIDTH
window.height  = S.HEIGHT

-- Runtime values
window.scale   = 1
window.offsetX = 0
window.offsetY = 0
window.canvas  = nil

-- Initialization
function window.load()
    window.canvas = love.graphics.newCanvas(
        window.width,
        window.height
    )

    window.resizeGame(
        love.graphics.getWidth(),
        love.graphics.getHeight()
    )
end

-- Resize / scale logic
function window.resizeGame(w, h)
    window.scale = math.min(
        w / window.width,
        h / window.height
    )

    -- Prevent scale from collapsing to zero
    window.scale = math.max(window.scale, 0.01)

    window.offsetX = (w - window.width * window.scale) / 2
    window.offsetY = (h - window.height * window.scale) / 2
end

-- Drawing
function window.beginDraw()
    love.graphics.setCanvas(window.canvas)
    love.graphics.clear(unpack(S.COLOR))
end

function window.endDraw()
    love.graphics.setCanvas()
    love.graphics.clear(28 / 255, 3 / 255, 51 / 255, 1)

    love.graphics.draw(
        window.canvas,
        window.offsetX,
        window.offsetY,
        0,
        window.scale,
        window.scale
    )
end

-- Coordinate conversion
function window.screenToWorld(sx, sy)
    local wx = (sx - window.offsetX) / window.scale
    local wy = (sy - window.offsetY) / window.scale
    return wx, wy
end

function window.worldToScreen(wx, wy)
    local sx = window.offsetX + wx * window.scale
    local sy = window.offsetY + wy * window.scale
    return sx, sy
end

-- Ignores clicks outside of the window
function window.isInsideViewport(sx, sy)
    return sx >= window.offsetX and sx <= window.offsetX + window.width * window.scale
        and sy >= window.offsetY and sy <= window.offsetY + window.height * window.scale
end

return window
