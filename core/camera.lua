-- helpers/camera.lua
local camera     = {}

camera.x         = 0
camera.y         = 0

-- Zoom
camera.scale     = 2
camera.baseScale = 2
camera.minScale  = 0.75
camera.maxScale  = 2.5

camera.zoom      = {
    amount    = 0.35, -- how much R3 zooms in
    smoothing = 14,
    target    = 2
}

-- Follow behavior
camera.target    = nil
camera.smoothing = 12 -- higher = snappier

-- Bounds and viewport
camera.bounds    = nil -- { x, y, w, h }
camera.viewW     = nil
camera.viewH     = nil

-- Look / aim (right stick nudge)
camera.look      = {
    enabled   = true,
    maxX      = 96,
    maxY      = 64,
    deadzone  = 0.25,
    smoothing = 18,
    x         = 0,
    y         = 0
}

-- Setup

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

function camera.setScale(s)
    camera.baseScale = math.max(camera.minScale, math.min(camera.maxScale, s))
    camera.zoom.target = camera.baseScale
end

function camera.zoomBy(amount)
    camera.setScale(camera.baseScale + amount)
end

-- Internals

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function axisWithDeadzone(v, dz)
    dz = dz or 0.25
    if math.abs(v) < dz then return 0 end
    return v
end

-- Update

function camera.update(dt)
    if not camera.target or not camera.viewW or not camera.viewH then
        return
    end

    -- Read controller
    local rx, ry = 0, 0
    local r3Held = false

    local pads = love.joystick.getJoysticks()
    local pad = pads and pads[1] or nil

    if pad then
        rx = axisWithDeadzone(pad:getGamepadAxis("rightx") or 0, camera.look.deadzone)
        ry = axisWithDeadzone(pad:getGamepadAxis("righty") or 0, camera.look.deadzone)
        r3Held = pad:isGamepadDown("rightstick")
    end

    -- Look offset
    local desiredLookX = rx * camera.look.maxX
    local desiredLookY = ry * camera.look.maxY

    local lt = 1 - math.exp(-camera.look.smoothing * dt)
    camera.look.x = camera.look.x + (desiredLookX - camera.look.x) * lt
    camera.look.y = camera.look.y + (desiredLookY - camera.look.y) * lt

    -- Zoom target (R3)
    if r3Held then
        camera.zoom.target = camera.baseScale + camera.zoom.amount
    else
        camera.zoom.target = camera.baseScale
    end

    -- Smooth zoom
    local zt = 1 - math.exp(-camera.zoom.smoothing * dt)
    camera.scale = camera.scale + (camera.zoom.target - camera.scale) * zt

    -- Effective viewport
    local vw = camera.viewW / camera.scale
    local vh = camera.viewH / camera.scale

    -- Base camera position
    local baseX =
        (camera.target.x + (camera.target.width or 0) / 2) - vw / 2
    local baseY =
        (camera.target.y + (camera.target.height or 0) / 2) - vh / 2

    -- Clamp base
    if camera.bounds then
        local minX = camera.bounds.x
        local minY = camera.bounds.y
        local maxX = camera.bounds.x + camera.bounds.w - vw
        local maxY = camera.bounds.y + camera.bounds.h - vh
        baseX = clamp(baseX, minX, maxX)
        baseY = clamp(baseY, minY, maxY)
    end

    -- Apply look
    local desiredX = baseX + camera.look.x
    local desiredY = baseY + camera.look.y

    if camera.bounds then
        local minX = camera.bounds.x
        local minY = camera.bounds.y
        local maxX = camera.bounds.x + camera.bounds.w - vw
        local maxY = camera.bounds.y + camera.bounds.h - vh
        desiredX = clamp(desiredX, minX, maxX)
        desiredY = clamp(desiredY, minY, maxY)
    end

    -- Smooth follow
    local t = 1 - math.exp(-camera.smoothing * dt)
    camera.x = camera.x + (desiredX - camera.x) * t
    camera.y = camera.y + (desiredY - camera.y) * t
end

-- Draw control

function camera.apply()
    love.graphics.push()
    love.graphics.scale(camera.scale, camera.scale)

    -- Snap camera to the pixel grid for the current zoom level
    local step = 1 / camera.scale
    local sx = math.floor(camera.x / step + 0.5) * step
    local sy = math.floor(camera.y / step + 0.5) * step

    love.graphics.translate(-sx, -sy)
end

function camera.clear()
    love.graphics.pop()
end

function camera.reset(x, y)
    camera.x = x or 0
    camera.y = y or 0
    camera.scale = camera.baseScale
    camera.zoom.target = camera.baseScale
    camera.look.x = 0
    camera.look.y = 0
end

-- Utilities

function camera.getDrawOffset()
    return math.floor(camera.x), math.floor(camera.y)
end

function camera.screenToWorld(x, y)
    return
        x / camera.scale + camera.x,
        y / camera.scale + camera.y
end

return camera
