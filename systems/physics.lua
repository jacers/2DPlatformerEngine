local physics = {}

-- Axis-Aligned Bounding Box
local function aabb(a, b)
    return
        a.x < b.x + b.width and
        a.x + a.width > b.x and
        a.y < b.y + b.height and
        a.y + a.height > b.y
end

local function isSolid(e)
    return not e.dead and e.solid and e.width and e.height
end

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

-- Move a body with platformer-style collision resolution.
-- solids: array of entities (usually entityHandler.getAll())
-- body:   entity with x,y,width,height and (optionally) vx,vy
-- dx,dy:  intended movement in world units
function physics.movePlatformer(solids, body, dx, dy)
    if not body.width or not body.height then
        return { x = false, y = false, ground = false, ceiling = false, wall = false }
    end

    local hit = { x = false, y = false, ground = false, ceiling = false, wall = false }

    -- Move X then resolve
    body.x = body.x + dx
    for _, other in ipairs(solids) do
        if other ~= body and isSolid(other) and aabb(body, other) then
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

    -- Move Y then resolve
    body.y = body.y + dy
    for _, other in ipairs(solids) do
        if other ~= body and isSolid(other) and aabb(body, other) then
            hit.y = true
            if dy > 0 then
                body.y = other.y - body.height
                hit.ground = true
            elseif dy < 0 then
                body.y = other.y + other.height
                hit.ceiling = true
            end
            if body.vy then body.vy = 0 end
        end
    end

    return hit
end

return physics
