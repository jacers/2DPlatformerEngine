require("core.constants")

local camera           = {}

camera.x               = 0
camera.y               = 0

-- Zoom
camera.scale           = CAMERA.DEFAULT_ZOOM
camera.baseScale       = CAMERA.DEFAULT_ZOOM
camera.minScale        = CAMERA.MIN_ZOOM
camera.maxScale        = CAMERA.MAX_ZOOM

camera.zoom            = {
    amount    = CAMERA.ZOOM.AMOUNT,
    smoothing = CAMERA.ZOOM.SMOOTHING,
    target    = CAMERA.DEFAULT_ZOOM
}

-- Follow behavior
camera.target          = nil
camera.smoothing       = CAMERA.FOLLOW_SMOOTHING

-- Airborne follow (prevents disorienting jump camera)
camera.air             = {
    enabled = true,
    -- 0 = freeze Y completely while airborne
    -- 1 = follow Y perfectly
    followY = 0.65,
}

camera.lastGroundBaseY = nil

-- Vertical deadzone (camera Y only moves when player leaves a middle band)
camera.vertical        = {
    enabled      = true,

    -- Deadzone height as a fraction of viewport height (world units).
    -- Bigger = steadier camera, smaller = more responsive.
    deadzoneFrac = 0.18,

    -- Positive bias shifts the deadzone band downward so you see more above the player.
    -- 0.08 is a common platformer choice.
    biasFrac     = 0.08,

    -- Cap vertical correction speed (world units per second) to prevent drastic jumps.
    maxStep      = 2000,

    -- Separate smoothing just for Y corrections (lower = looser, higher = snappier).
    smoothing    = 24,
}

-- Bounds and viewport
camera.bounds          = nil -- { x, y, w, h }
camera.viewW           = nil
camera.viewH           = nil

-- Look / aim (right stick nudge)
camera.look            = {
    enabled   = true,
    maxX      = CAMERA.LOOK.MAX_X,
    maxY      = CAMERA.LOOK.MAX_Y,
    deadzone  = CAMERA.LOOK.DEADZONE,
    smoothing = CAMERA.LOOK.SMOOTHING,
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
    camera.lastGroundBaseY = nil
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

    -- Target center
    local px = (camera.target.x + (camera.target.width or 0) / 2)
    local py = (camera.target.y + (camera.target.height or 0) / 2)

    -- Base camera X (center target)
    local baseX = px - vw / 2

    -- Base camera Y:
    -- Start with "center target" but optionally apply vertical deadzone first.
    local baseY = py - vh / 2

    if camera.vertical.enabled then
        local deadFrac    = camera.vertical.deadzoneFrac or 0.30
        local biasFrac    = camera.vertical.biasFrac or 0.0
        local maxStep     = camera.vertical.maxStep or 200
        local ySmooth     = camera.vertical.smoothing or camera.smoothing

        local deadH       = vh * deadFrac
        local bandTop     = (vh - deadH) / 2 + (vh * biasFrac)
        local bandBottom  = bandTop + deadH

        -- Player's screen-space Y within current camera view
        local relY        = py - camera.y

        -- Desired camera.y (top-left) based on leaving the band
        local desiredCamY = camera.y
        if relY < bandTop then
            desiredCamY = py - bandTop
        elseif relY > bandBottom then
            desiredCamY = py - bandBottom
        end

        -- Clamp correction speed so it isn't drastic
        local dy = desiredCamY - camera.y
        local maxMove = maxStep * dt
        if dy > maxMove then dy = maxMove end
        if dy < -maxMove then dy = -maxMove end

        -- Smoothly apply the correction and convert back to baseY
        local yt = 1 - math.exp(-ySmooth * dt)
        local camYAfter = camera.y + dy * yt

        baseY = camYAfter
    else
        -- If vertical deadzone disabled, stick to centered baseY (camera top-left)
        baseY = py - vh / 2
    end

    -- Airborne vertical dampening (prevents camera matching jump perfectly)
    -- This runs AFTER vertical deadzone so jumps are both steadier and less "locked on".
    if camera.air.enabled then
        local onGround = camera.target.onGround == true
        if onGround then
            camera.lastGroundBaseY = baseY
        else
            if camera.lastGroundBaseY == nil then
                camera.lastGroundBaseY = baseY
            end
            local f = camera.air.followY or 0.25
            baseY = camera.lastGroundBaseY + (baseY - camera.lastGroundBaseY) * f
        end
    end

    -- Clamp base
    if camera.bounds then
        local minX = camera.bounds.x
        local minY = camera.bounds.y
        local maxX = camera.bounds.x + camera.bounds.w - vw
        local maxY = camera.bounds.y + camera.bounds.h - vh
        baseX = clamp(baseX, minX, maxX)
        baseY = clamp(baseY, minY, maxY)
    end

    -- Apply look (only if it won't fight bounds)
    local desiredX = baseX
    local desiredY = baseY

    if camera.bounds then
        local minX = camera.bounds.x
        local minY = camera.bounds.y
        local maxX = camera.bounds.x + camera.bounds.w - vw
        local maxY = camera.bounds.y + camera.bounds.h - vh

        -- Allow look only if there's room in that direction
        if camera.look.x < 0 and baseX > minX then
            desiredX = baseX + camera.look.x
        elseif camera.look.x > 0 and baseX < maxX then
            desiredX = baseX + camera.look.x
        end

        if camera.look.y < 0 and baseY > minY then
            desiredY = baseY + camera.look.y
        elseif camera.look.y > 0 and baseY < maxY then
            desiredY = baseY + camera.look.y
        end

        desiredX = clamp(desiredX, minX, maxX)
        desiredY = clamp(desiredY, minY, maxY)
    else
        desiredX = baseX + camera.look.x
        desiredY = baseY + camera.look.y
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
    camera.baseScale = CAMERA.DEFAULT_ZOOM
    camera.scale = CAMERA.DEFAULT_ZOOM
    camera.zoom.target = CAMERA.DEFAULT_ZOOM
    camera.look.x = 0
    camera.look.y = 0
    camera.lastGroundBaseY = nil
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
