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
    followY = 0.65, -- 0..1
}

camera.lastGroundBaseY = nil

-- Vertical deadzone (camera Y only moves when player leaves a middle band)
camera.vertical        = {
    enabled      = true,
    deadzoneFrac = 0.18,
    biasFrac     = 0.08,
    maxStep      = 2000,
    smoothing    = 24,
}

-- Bounds and viewport
camera.bounds          = nil -- { x, y, w, h }
camera.viewW           = nil
camera.viewH           = nil

-- Look / aim (right stick nudge)
camera.look            = {
    enabled         = true,
    maxX            = CAMERA.LOOK.MAX_X,
    maxY            = CAMERA.LOOK.MAX_Y,
    deadzone        = CAMERA.LOOK.DEADZONE,

    smoothing       = CAMERA.LOOK.SMOOTHING,
    returnSmoothing = (CAMERA.LOOK.RETURN_SMOOTHING or (CAMERA.LOOK.SMOOTHING * 2.5)),
    snapEpsilon     = (CAMERA.LOOK.SNAP_EPSILON or 0.75),

    x               = 0,
    y               = 0
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

    -- Zoom target (R3)
    if r3Held then
        camera.zoom.target = camera.baseScale + camera.zoom.amount
    else
        camera.zoom.target = camera.baseScale
    end

    -- Smooth zoom
    local zt = 1 - math.exp(-camera.zoom.smoothing * dt)
    camera.scale = camera.scale + (camera.zoom.target - camera.scale) * zt

    -- Effective viewport (WORLD units)
    local vw = camera.viewW / camera.scale
    local vh = camera.viewH / camera.scale

    -- Look offset (bounded + snap back)
    if camera.look.enabled then
        local desiredLookX = rx * camera.look.maxX
        local desiredLookY = ry * camera.look.maxY

        local stickActive = (rx ~= 0) or (ry ~= 0)
        local s = stickActive and camera.look.smoothing or camera.look.returnSmoothing
        local lt = 1 - math.exp(-s * dt)

        camera.look.x = camera.look.x + (desiredLookX - camera.look.x) * lt
        camera.look.y = camera.look.y + (desiredLookY - camera.look.y) * lt

        -- Hard clamp ALWAYS
        camera.look.x = clamp(camera.look.x, -camera.look.maxX, camera.look.maxX)
        camera.look.y = clamp(camera.look.y, -camera.look.maxY, camera.look.maxY)

        -- Snap to 0 when released and close enough
        if not stickActive then
            if math.abs(camera.look.x) < camera.look.snapEpsilon then camera.look.x = 0 end
            if math.abs(camera.look.y) < camera.look.snapEpsilon then camera.look.y = 0 end
        end
    else
        camera.look.x = 0
        camera.look.y = 0
    end

    -- Target center
    local px = (camera.target.x + (camera.target.width or 0) / 2)
    local py = (camera.target.y + (camera.target.height or 0) / 2)

    -- Compute "follow camera" (no-look) from a no-look current position
    local followX = camera.x - (camera.look.enabled and camera.look.x or 0)
    local followY = camera.y - (camera.look.enabled and camera.look.y or 0)

    -- Base camera X (center target)
    local baseX = px - vw / 2
    local baseY = py - vh / 2

    -- Vertical deadzone uses followY (NOT camera.y, which includes look)
    if camera.vertical.enabled then
        local deadFrac       = camera.vertical.deadzoneFrac or 0.30
        local biasFrac       = camera.vertical.biasFrac or 0.0
        local maxStep        = camera.vertical.maxStep or 200
        local ySmooth        = camera.vertical.smoothing or camera.smoothing

        local deadH          = vh * deadFrac
        local bandTop        = (vh - deadH) / 2 + (vh * biasFrac)
        local bandBottom     = bandTop + deadH

        local relY           = py - followY

        local desiredFollowY = followY
        if relY < bandTop then
            desiredFollowY = py - bandTop
        elseif relY > bandBottom then
            desiredFollowY = py - bandBottom
        end

        local dy = desiredFollowY - followY
        local maxMove = maxStep * dt
        if dy > maxMove then dy = maxMove end
        if dy < -maxMove then dy = -maxMove end

        local yt = 1 - math.exp(-ySmooth * dt)
        followY = followY + dy * yt

        baseY = followY
    else
        baseY = py - vh / 2
    end

    -- Airborne vertical dampening operates on baseY (still no-look)
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

    -- Clamp base to bounds (no-look)
    if camera.bounds then
        local minX = camera.bounds.x
        local minY = camera.bounds.y
        local maxX = camera.bounds.x + camera.bounds.w - vw
        local maxY = camera.bounds.y + camera.bounds.h - vh
        baseX = clamp(baseX, minX, maxX)
        baseY = clamp(baseY, minY, maxY)
    end

    -- Apply look as a small bounded offset (after deadzone/air/bounds)
    local desiredX = baseX + (camera.look.enabled and camera.look.x or 0)
    local desiredY = baseY + (camera.look.enabled and camera.look.y or 0)

    -- Clamp final desired too
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
