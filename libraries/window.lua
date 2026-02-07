local window = {}

window.width = 1280
window.height = 720

window.scale   = 1
window.offsetX = 0
window.offsetY = 0
window.canvas  = nil

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

function window.resizeGame(w, h)
    local dpi = love.window.getDPIScale()

    local realW = w * dpi
    local realH = h * dpi

    window.scale = math.min(
        realW / window.width,
        realH / window.height
    )

    window.offsetX = (realW - window.width  * window.scale) / 2
    window.offsetY = (realH - window.height * window.scale) / 2
end

function window.beginDraw()
    love.graphics.setCanvas(window.canvas)
    window.color(28/255, 3/255, 51/255, 0)

end

function window.endDraw()
    love.graphics.setCanvas()
    window.color(28/255, 3/255, 51/255, 0)

    love.graphics.draw(
        window.canvas,
        window.offsetX,
        window.offsetY,
        0,
        window.scale,
        window.scale
    )
end

function window.color(r, g, b, alpha)
    love.graphics.clear(r, g, b, alpha)
end

return window
