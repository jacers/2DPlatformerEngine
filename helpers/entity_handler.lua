local entityHandler = {}
local entities = {}

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

-- Birthing and living
function entityHandler.spawn(entity)
    table.insert(entities, entity)
end

function entityHandler.update(dt)
    for i = #entities, 1, -1 do
        local entity = entities[i]
        entity:update(dt)

        if entity.dead then
            table.remove(entities, i)
        end
    end
end

function entityHandler.draw()
    for _, entity in ipairs(entities) do
        entity:draw()
    end
end

-- Picking
function entityHandler.pick(x, y)
    for i = #entities, 1, -1 do
        local e = entities[i]
        if e.containsPoint and e:containsPoint(x, y) then
            return e
        end
    end
    return nil
end

-- Collision helpers
function entityHandler.canPlace(testEntity)
    if not testEntity.width or not testEntity.height then
        return false
    end

    for _, e in ipairs(entities) do
        if not e.dead and e.width and e.height then
            if aabb(testEntity, e) then
                return false
            end
        end
    end

    return true
end

function entityHandler.tryMove(entity, dx, dy)
    if not entity.width or not entity.height then
        return false
    end

    local oldX, oldY = entity.x, entity.y
    entity.x = entity.x + dx
    entity.y = entity.y + dy

    for _, other in ipairs(entities) do
        if other ~= entity and not other.dead and other.width and other.height then
            if aabb(entity, other) then
                -- Revert movement
                entity.x = oldX
                entity.y = oldY
                return false
            end
        end
    end

    return true
end

-- Movement
function entityHandler.moveAllByName(name, dx, dy)
    for _, e in ipairs(entities) do
        if e.name == name then
            entityHandler.tryMove(e, dx, dy)
        end
    end
end

function entityHandler.movePlatformer(body, dx, dy)
    if not body.width or not body.height then return { x = false, y = false, ground = false, ceiling = false, wall = false } end

    local hit = { x = false, y = false, ground = false, ceiling = false, wall = false }

    -- Move X then resolve
    body.x = body.x + dx
    for _, other in ipairs(entities) do
        if other ~= body and isSolid(other) and aabb(body, other) then
            hit.x = true
            hit.wall = true
            if dx > 0 then
                body.x = other.x - body.width
            elseif dx < 0 then
                body.x = other.x + other.width
            end
            body.vx = 0
        end
    end

    -- Move Y then resolve
    body.y = body.y + dy
    for _, other in ipairs(entities) do
        if other ~= body and isSolid(other) and aabb(body, other) then
            hit.y = true
            if dy > 0 then
                -- falling onto ground
                body.y = other.y - body.height
                hit.ground = true
            elseif dy < 0 then
                -- hitting ceiling
                body.y = other.y + other.height
                hit.ceiling = true
            end
            body.vy = 0
        end
    end

    return hit
end

-- Getter so we can iterate etiries from outside
function entityHandler.getAll()
    return entities
end

-- Kills all entities
function entityHandler.clear()
    for i = #entities, 1, -1 do
        entities[i] = nil
    end
end

return entityHandler
