local altimeter = {}

altimeter.enabled = true
altimeter.pxPerMeter = 16 -- 16px = 1m (tile height)
altimeter.smoothing = 18  -- higher = steadier number

altimeter._baseY = nil
altimeter._meters = 0
altimeter._bestMeters = 0

function altimeter.reset(player)
    if not player then
        altimeter._baseY = nil
        altimeter._meters = 0
        altimeter._bestMeters = 0
        return
    end
    altimeter._baseY = player.y
    altimeter._meters = 0
    altimeter._bestMeters = 0
end

function altimeter.update(dt, player)
    if not altimeter.enabled or not player or not altimeter._baseY then return end

    -- base - current = how far up you moved
    local raw = (altimeter._baseY - player.y) / altimeter.pxPerMeter
    if raw < 0 then raw = 0 end

    local t = 1 - math.exp(-altimeter.smoothing * dt)
    altimeter._meters = altimeter._meters + (raw - altimeter._meters) * t

    if raw > altimeter._bestMeters then
        altimeter._bestMeters = raw
    end
end

function altimeter.draw(pad)
    if not altimeter.enabled then return end
    pad          = pad or 12

    local cur    = math.floor(altimeter._meters + 0.5)
    local best   = math.floor(altimeter._bestMeters + 0.5)

    local line1  = ("Height: %dm"):format(cur)
    local line2  = ("Best:   %dm"):format(best)

    -- Measure text to right-align
    local font   = love.graphics.getFont()
    local w1     = font:getWidth(line1)
    local w2     = font:getWidth(line2)
    local boxW   = math.max(w1, w2) + 18
    local boxH   = 44

    -- Use current render target size (Canvas if window.beginDraw() set one)
    local target = love.graphics.getCanvas()
    local gw, gh
    if target then
        gw, gh = target:getWidth(), target:getHeight()
    else
        gw, gh = love.graphics.getWidth(), love.graphics.getHeight()
    end

    local x = gw - pad - boxW
    local y = pad

    love.graphics.push("all")
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x, y, boxW, boxH, 6, 6)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(line1, x + 9, y + 6)
    love.graphics.print(line2, x + 9, y + 24)
    love.graphics.pop()
end

return altimeter
