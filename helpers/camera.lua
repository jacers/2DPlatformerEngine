local camera = {}

camera.x = 0
camera.y = 0

camera.target = nil
camera.smoothing = 12 -- higher = snappier

camera.bounds = nil -- { x, y, w, h }
camera.viewW = nil
camera.viewH = nil

function camera.setViewportSize(w, h)
    camera.viewW = w
    camera.viewH = h
end

function camera.setTarget(entity)
    camera.target = entity
end

function camera.setBounds(x, y, w, h)
    camera.bounds = { x = x, y = y, w = w, h = h }
end

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

function camera.update(dt)
    if not camera.target or not camera.viewW or not camera.viewH then
        return
    end

    -- Center on target
    local desiredX = (camera.target.x + (camera.target.width or 0) / 2) - camera.viewW / 2
    local desiredY = (camera.target.y + (camera.target.height or 0) / 2) - camera.viewH / 2

    -- Smooth follow
    local t = 1 - math.exp(-camera.smoothing * dt)
    camera.x = camera.x + (desiredX - camera.x) * t
    camera.y = camera.y + (desiredY - camera.y) * t

    -- Clamp to bounds
    if camera.bounds then
        local minX = camera.bounds.x
        local minY = camera.bounds.y
        local maxX = camera.bounds.x + camera.bounds.w - camera.viewW
        local maxY = camera.bounds.y + camera.bounds.h - camera.viewH
        camera.x = clamp(camera.x, minX, maxX)
        camera.y = clamp(camera.y, minY, maxY)
    end
end

function camera.apply()
    love.graphics.push()
    love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))
end

function camera.clear()
    love.graphics.pop()
end

function camera.reset(x, y)
    camera.x = x or 0
    camera.y = y or 0
end

return camera
