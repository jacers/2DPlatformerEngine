require("core.constants")

local pause = {}

pause.isPaused = false

function pause.toggle()
    pause.isPaused = not pause.isPaused
end

function pause.set(v)
    pause.isPaused = (v == true)
end

function pause.drawOverlay()
    if not pause.isPaused then return end

    -- gray tint over everything (drawn on the virtual canvas)
    love.graphics.setColor(0.5, 0.5, 0.5, 0.20)
    love.graphics.rectangle("fill", 0, 0, SCREEN.WIDTH, SCREEN.HEIGHT)

    -- centered PAUSED text
    love.graphics.setColor(1, 1, 1, 1)
    local text = "PAUSED"
    local font = love.graphics.getFont()
    local tw = font:getWidth(text)
    local th = font:getHeight(text)
    love.graphics.print(text, (SCREEN.WIDTH - tw) / 2, (SCREEN.HEIGHT - th) / 2)

    love.graphics.setColor(1, 1, 1, 1)
end

return pause
