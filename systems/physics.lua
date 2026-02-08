local physics            = {}

-- Tunables (keep small / sane defaults)
physics.EPS              = 0.001
physics.ONEWAY_EPS       = 2 -- tolerance for landing on one-way
physics.SLOPE_EPS        = 2 -- tolerance for landing on slopes
physics.SLOPE_STEP       = 6 -- "step height" to walk up slopes
physics.RIDER_EPS        = 2 -- rider detection tolerance
physics.TRIGGER_COOLDOWN = 0 -- (optional) if you want debounce later

-- Helpers

local function aabb(a, b)
    return
        a.x < b.x + b.width and
        a.x + a.width > b.x and
        a.y < b.y + b.height and
        a.y + a.height > b.y
end

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function sign(v)
    if v < 0 then return -1 end
    if v > 0 then return 1 end
    return 0
end

local function isBody(e)
    -- Treat anything with velocity as a "body" by default (player, enemies, etc.)
    return (not e.dead) and e.width and e.height and (e.vx ~= nil or e.vy ~= nil or e.isBody == true)
end

local function isTrigger(e)
    return (not e.dead) and e.trigger == true and e.width and e.height
end

local function isSolid(e)
    return (not e.dead) and e.solid == true and e.width and e.height
end

local function isOneWay(e)
    -- One-way platform: set `oneWay = true` on entity (and usually `solid = true` too)
    return isSolid(e) and e.oneWay == true
end

local function isSlope(e)
    -- Slope: entity.solid=true AND entity.slope is a table describing segment
    -- e.slope = { x1=..., y1=..., x2=..., y2=... } (world coords)
    return isSolid(e) and type(e.slope) == "table"
end

local function isMovingPlatform(e)
    -- Moving platform: e.moving = true and provides velocity or path function
    -- Minimal: e.vx / e.vy (platform velocities)
    return isSolid(e) and e.moving == true
end

local function slopeBounds(s)
    local minX = math.min(s.x1, s.x2)
    local maxX = math.max(s.x1, s.x2)
    local minY = math.min(s.y1, s.y2)
    local maxY = math.max(s.y1, s.y2)
    return minX, minY, maxX - minX, maxY - minY
end

local function yOnSlopeAtX(s, x)
    -- linear interpolation along segment
    local dx = (s.x2 - s.x1)
    if math.abs(dx) < 0.0001 then
        return s.y1
    end
    local t = (x - s.x1) / dx
    return s.y1 + (s.y2 - s.y1) * t
end

local function slopeInRange(s, x)
    local minX = math.min(s.x1, s.x2)
    local maxX = math.max(s.x1, s.x2)
    return x >= minX - physics.SLOPE_EPS and x <= maxX + physics.SLOPE_EPS
end

-- Semi-solid logic

local function canCollideOneWay(body, plat, dy, oldY)
    -- Only collide when moving downward (or not moving) and the body was above the top surface
    if dy <= 0 then return false end

    -- Drop-through support:
    -- If the body sets `body.dropTimer > 0` we ignore one-way collisions while it counts down
    if body.dropTimer and body.dropTimer > 0 then
        return false
    end

    local oldBottom = oldY + body.height
    local newBottom = body.y + body.height
    local top = plat.y

    -- Must cross the top surface from above (with tolerance)
    if oldBottom <= top + physics.ONEWAY_EPS and newBottom >= top - physics.ONEWAY_EPS then
        -- must overlap in X
        local overlapX = (body.x < plat.x + plat.width) and (body.x + body.width > plat.x)
        return overlapX
    end

    return false
end

-- Slope resolve (ground only)

local function resolveSlopes(world, body, hit, oldY)
    -- Idea:
    -- After movement, if body is falling or near ground, snap its feet to the slope surface
    -- using the body center as the "probe" X.
    local bx = body.x + body.width * 0.5
    if not hit then return end

    for _, e in ipairs(world) do
        if e ~= body and isSlope(e) then
            local s = e.slope

            -- quick bounds reject using slope bbox
            local sx, sy, sw, sh = slopeBounds(s)
            local slopeBox = { x = sx, y = sy, width = sw, height = sh }
            if not aabb(body, slopeBox) then
                -- allow a small proximity check when walking up slopes
                -- (body might be just above bbox due to step)
            end

            if slopeInRange(s, bx) then
                local ySurf = yOnSlopeAtX(s, bx)

                -- We want the body to sit ON the slope: body.y = ySurf - body.height
                local desiredY = ySurf - body.height

                -- Only snap if we're close enough and moving down OR stepping
                local bottom = body.y + body.height
                local oldBottom = oldY + body.height

                local falling = (body.vy ~= nil and body.vy >= 0) or true

                -- Allow snapping if:
                -- 1) falling and bottom is at/under surface with tolerance
                -- 2) OR stepping: body bottom is above but within SLOPE_STEP
                local closeFall = falling and bottom >= ySurf - physics.SLOPE_EPS and
                oldBottom <= ySurf + physics.SLOPE_EPS
                local closeStep = (ySurf - bottom) >= -physics.SLOPE_EPS and (ySurf - bottom) <= physics.SLOPE_STEP

                if closeFall or closeStep then
                    body.y = desiredY
                    if body.vy then body.vy = 0 end
                    hit.y = true
                    hit.ground = true
                    hit.groundEntity = e
                end
            end
        end
    end
end

-- Core platformer move

-- Move a body with platformer-style collision resolution.
-- world:  array of entities (solids + triggers + bodies)
-- body:   entity with x,y,width,height and (optionally) vx,vy
-- dx,dy:  intended movement in world units
function physics.movePlatformer(world, body, dx, dy)
    if not body.width or not body.height then
        return { x = false, y = false, ground = false, ceiling = false, wall = false }
    end

    local hit = { x = false, y = false, ground = false, ceiling = false, wall = false, groundEntity = nil }

    local oldX, oldY = body.x, body.y

    -- Move X then resolve against solids
    body.x = body.x + dx
    for _, other in ipairs(world) do
        if other ~= body and isSolid(other) and not isSlope(other) then
            if aabb(body, other) then
                -- one-way platforms should NOT block on the sides by default
                if not isOneWay(other) then
                    hit.x = true
                    hit.wall = true
                    if dx > 0 then
                        body.x = other.x - body.width
                    elseif dx < 0 then
                        body.x = other.x + other.width
                    end
                    if body.vx then body.vx = 0 end
                end
            end
        end
    end

    -- Move Y then resolve against solids and semi-solids
    body.y = body.y + dy

    for _, other in ipairs(world) do
        if other ~= body and isSolid(other) and not isSlope(other) then
            if aabb(body, other) then
                if isOneWay(other) then
                    -- Only collide if we are landing on top (not jumping up into it)
                    if canCollideOneWay(body, other, dy, oldY) then
                        hit.y = true
                        hit.ground = true
                        hit.groundEntity = other
                        body.y = other.y - body.height
                        if body.vy then body.vy = 0 end
                    end
                else
                    hit.y = true
                    if dy > 0 then
                        body.y = other.y - body.height
                        hit.ground = true
                        hit.groundEntity = other
                    elseif dy < 0 then
                        body.y = other.y + other.height
                        hit.ceiling = true
                    end
                    if body.vy then body.vy = 0 end
                end
            end
        end
    end

    -- Snap to the ground on slopes!
    resolveSlopes(world, body, hit, oldY)

    return hit
end

-- Moving platforms

local function isRiding(body, plat)
    -- body bottom near platform top AND overlapping in X
    local bodyBottom = body.y + body.height
    local platTop = plat.y
    if math.abs(bodyBottom - platTop) > physics.RIDER_EPS then
        return false
    end

    local overlapX = (body.x < plat.x + plat.width) and (body.x + body.width > plat.x)
    return overlapX
end

-- Move platforms and carry riders.
-- Call once per frame (or per substep) from your main loop.
function physics.updatePlatforms(world, dt)
    -- Collect moving platforms first
    for _, plat in ipairs(world) do
        if isMovingPlatform(plat) then
            local pvx = plat.vx or 0
            local pvy = plat.vy or 0

            -- Optional path function:
            -- plat.path(t, plat) -> dx, dy  (delta this frame)
            if type(plat.path) == "function" then
                plat._t = (plat._t or 0) + dt
                local dx, dy = plat.path(plat._t, plat)
                pvx = (dx or 0) / dt
                pvy = (dy or 0) / dt
            end

            local dx = pvx * dt
            local dy = pvy * dt

            if dx == 0 and dy == 0 then
                goto continue_platform
            end

            -- Identify riders before moving platform
            local riders = {}
            for _, b in ipairs(world) do
                if b ~= plat and isBody(b) then
                    if isRiding(b, plat) then
                        riders[#riders + 1] = b
                    end
                end
            end

            -- Move platform (no collision handling here; you can add later)
            plat.x = plat.x + dx
            plat.y = plat.y + dy

            -- Carry riders: move them by the same delta, then resolve against world
            for _, b in ipairs(riders) do
                b.x = b.x + dx
                b.y = b.y + dy

                -- If carried into something, resolve (best effort)
                physics.movePlatformer(world, b, 0, 0)
            end
        end

        ::continue_platform::
    end
end

-- Triggers (like New Super and Wonder)

local function ensureTriggerState(body)
    if not body._triggers then
        body._triggers = {}
    end
end

local function triggerKey(t)
    -- Prefer explicit id for stable tracking
    if t.id then return tostring(t.id) end
    -- fallback to table address string
    return tostring(t)
end

-- Update triggers for ALL bodies.
-- Trigger entities should define:
--   trigger = true
--   onEnter = function(body, trigger) ... end
--   onExit  = function(body, trigger) ... end
function physics.updateTriggers(world)
    -- Gather triggers once
    local triggers = {}
    for _, e in ipairs(world) do
        if isTrigger(e) then
            triggers[#triggers + 1] = e
        end
    end
    if #triggers == 0 then return end

    for _, body in ipairs(world) do
        if isBody(body) then
            ensureTriggerState(body)

            local currently = body._triggers
            local seenNow = {}

            for _, t in ipairs(triggers) do
                if t ~= body and aabb(body, t) then
                    local k = triggerKey(t)
                    seenNow[k] = true

                    if not currently[k] then
                        currently[k] = true
                        if type(t.onEnter) == "function" then
                            t.onEnter(body, t)
                        end
                    end
                end
            end

            -- exits
            for k, _ in pairs(currently) do
                if not seenNow[k] then
                    -- find trigger object for callback (best effort)
                    currently[k] = nil

                    -- We need the actual trigger table for onExit; search by key
                    for _, t in ipairs(triggers) do
                        if triggerKey(t) == k then
                            if type(t.onExit) == "function" then
                                t.onExit(body, t)
                            end
                            break
                        end
                    end
                end
            end
        end
    end
end

-- Jump through semi-solids just like Kirby

-- Call this when player presses DOWN + JUMP, etc.
-- Example: body.dropTimer = physics.dropTime(0.18)
function physics.dropTime(seconds)
    return seconds or 0.18
end

function physics.updateBodyTimers(body, dt)
    if body.dropTimer and body.dropTimer > 0 then
        body.dropTimer = math.max(0, body.dropTimer - dt)
    end
end

function physics.updateBodyTimersWorld(world, dt)
    for _, b in ipairs(world) do
        if isBody(b) then
            physics.updateBodyTimers(b, dt)
        end
    end
end

return physics
