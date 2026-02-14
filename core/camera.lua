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
    returnSmoothing = (CAMERA.LOOK.RETURN_SMOOTHING or 95),
    snapEpsilon     = (CAMERA.LOOK.SNAP_EPSILON or 2.0),

    x               = 0,
    y               = 0,
}

-- Tile framing rules (nullified when hitting edge of map)
camera.tileRules       = {
    -- Horizontal lead
    tilesWide          = 24,
    tilesAhead         = 11, -- In front when moving right
    tilesBehind        = 11, -- Behind when moving left
    vxThreshold        = 25, -- How fast before we committing to "moving left/right" framing

    -- Vertical margins
    tilesAbove         = 3,  -- Keep >= 3 tiles above when player gets too high
    tilesBelowFalling  = 5,  -- Keep >= 5 tiles below when falling and player gets too low
    vyFallingThreshold = 40, -- Consider "falling" if vy > this
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

local function expSmooth(current, target, smoothing, dt)
    local t = 1 - math.exp(-smoothing * dt)
    return current + (target - current) * t
end

-- Update

function camera.update(dt)
    if not camera.target or not camera.viewW or not camera.viewH then
        return
    end

    -- Read controller (right stick + R3 zoom)
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

    camera.scale = expSmooth(camera.scale, camera.zoom.target, camera.zoom.smoothing, dt)

    -- Effective viewport (WORLD units)
    local vw = camera.viewW / camera.scale
    local vh = camera.viewH / camera.scale

    -- Right stick look (bounded + snaps back)
    if camera.look.enabled then
        local desiredLookX = rx * camera.look.maxX
        local desiredLookY = ry * camera.look.maxY

        local stickActive = (rx ~= 0) or (ry ~= 0)
        local s = stickActive and camera.look.smoothing or camera.look.returnSmoothing

        camera.look.x = expSmooth(camera.look.x, desiredLookX, s, dt)
        camera.look.y = expSmooth(camera.look.y, desiredLookY, s, dt)

        camera.look.x = clamp(camera.look.x, -camera.look.maxX, camera.look.maxX)
        camera.look.y = clamp(camera.look.y, -camera.look.maxY, camera.look.maxY)

        if not stickActive then
            if math.abs(camera.look.x) < camera.look.snapEpsilon then camera.look.x = 0 end
            if math.abs(camera.look.y) < camera.look.snapEpsilon then camera.look.y = 0 end
        end
    else
        camera.look.x = 0
        camera.look.y = 0
    end

    -- Player reference point (use center)
    local px             = camera.target.x + (camera.target.width or 0) / 2
    local py             = camera.target.y + (camera.target.height or 0) / 2

    local vx             = camera.target.vx or 0
    local vy             = camera.target.vy or 0

    -- Safe-zone camera (does not recenter when stadning still)
    -- Camera stays put until player violates tile margins.

    local rules          = camera.tileRules

    -- Compute "no-look" camera position (remove current look offset)
    local followX        = camera.x - (camera.look.enabled and camera.look.x or 0)
    local followY        = camera.y - (camera.look.enabled and camera.look.y or 0)

    -- Convert tile margins to world units
    local leftMargin     = (rules.tilesBehind or 0) * TILE_LENGTH
    local rightMargin    = (rules.tilesAhead or 0) * TILE_LENGTH

    local topMargin      = (rules.tilesAbove or 0) * TILE_LENGTH

    -- While falling, require more space below; otherwise keep it calmer
    local bottomTiles    =
        (vy > (rules.vyFallingThreshold or 40))
        and (rules.tilesBelowFalling or rules.tilesAbove or 0)
        or (rules.tilesBelow or rules.tilesAbove or 0)

    local bottomMargin   = bottomTiles * TILE_LENGTH

    -- Start with "stay where you are"
    local desiredFollowX = followX
    local desiredFollowY = followY

    -- Horizontal safe-zone
    -- Player must stay between:
    --   leftBound  = camLeft + leftMargin
    --   rightBound = camLeft + vw - rightMargin
    local leftBound      = desiredFollowX + leftMargin
    local rightBound     = desiredFollowX + vw - rightMargin

    if px < leftBound then
        desiredFollowX = px - leftMargin
    elseif px > rightBound then
        desiredFollowX = px - (vw - rightMargin)
    end

    -- Vertical safe-zone
    -- Player must stay between:
    --   topBound    = camTop + topMargin
    --   bottomBound = camTop + vh - bottomMargin
    local topBound    = desiredFollowY + topMargin
    local bottomBound = desiredFollowY + vh - bottomMargin

    if py < topBound then
        desiredFollowY = py - topMargin
    elseif py > bottomBound then
        desiredFollowY = py - (vh - bottomMargin)
    end

    -- Clamp desired follow to bounds (no-look)
    if camera.bounds then
        local minX = camera.bounds.x
        local minY = camera.bounds.y
        local maxX = camera.bounds.x + camera.bounds.w - vw
        local maxY = camera.bounds.y + camera.bounds.h - vh

        desiredFollowX = clamp(desiredFollowX, minX, maxX)
        desiredFollowY = clamp(desiredFollowY, minY, maxY)
    end

    -- Add look offset after safe-zone (so stick only nudges locally)
    local desiredX = desiredFollowX + (camera.look.enabled and camera.look.x or 0)
    local desiredY = desiredFollowY + (camera.look.enabled and camera.look.y or 0)

    -- Clamp final to bounds too (so look can't push out)
    if camera.bounds then
        local minX = camera.bounds.x
        local minY = camera.bounds.y
        local maxX = camera.bounds.x + camera.bounds.w - vw
        local maxY = camera.bounds.y + camera.bounds.h - vh

        desiredX = clamp(desiredX, minX, maxX)
        desiredY = clamp(desiredY, minY, maxY)
    end

    -- Smooth follow
    camera.x = expSmooth(camera.x, desiredX, camera.smoothing, dt)
    camera.y = expSmooth(camera.y, desiredY, camera.smoothing, dt)
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
